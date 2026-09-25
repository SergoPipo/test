## DEV-AUDIT-080 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (vitest: 1 известный флейк S8R-FIX-005, см. доработки)

### 1. Что реализовано
- Новый `app/strategy/risk_params.py`: pydantic-схема `RiskParams` (SL (0,50] %, TP (0,100] % — см. доработки, размер (0,100] % или ≥1 лот, пункты >0) + `normalize_strategy_params` (только числа; числовая строка превращается в число, чтобы в код попадал литерал `3`, а не `'3'`).
- Схему вызывают `VersionFromParamsCreate` (`mode="before"` → 422), `params.replace_params_in_blocks`, `params_sync.apply_params_to_strategy`, `strategy_params.replace_strategy_params`, `grid.validate_grid_request` (ловушка п.5).
- `calc_sl_tp_prices`: `ValueError` при `pct <= 0`; формулы не тронуты.
- Решение по /code-review карточки 001: `extract_risk_params(blocks_json)` берёт SL/TP только из `parse_blocks` (IR). `generated_code` и `text_description` больше не источники. Возвращает `(RiskParams, problems)`: поле с ошибкой отбрасывается.
- `_attach_sl_tp`: при `problems` пишет warning и публикует `order.error` (событие уже есть, новый event_type не заводил); текст и дедуп — см. доработки п.3.

### 2. Файлы
Новые: `app/strategy/risk_params.py`, `tests/test_trading/test_calc_sl_tp_bounds.py`, `tests/unit/test_strategy/test_risk_params_validation.py`.
Изменённые: `strategy/{schemas,params,params_sync}.py`, `backtest/{grid,strategy_params}.py`, `trading/{risk_monitor,engine}.py`; тесты `test_audit_s8r_risk_params_bounds.py` (xfail сняты), `test_risk_monitor.py` и `test_order_manager.py` (фикстуры переведены на IR).

### 3. Тесты
RED: `assert 201 == 422`, `Failed: DID NOT RAISE <class 'ValueError'>`, `AssertionError: Decimal('105.00000000')`; в live `assert Decimal('50.00000000') == Decimal('98.00000000')` (стоп взят из generated_code).
GREEN: 34/34 по трём файлам карточки.
Мутация: сняла `gt=0` у `stop_loss_pct` → красные, в том числе `assert 201 == 422` и `DID NOT RAISE GridValidationError`. Откат через cp, md5 совпал.
Гейты: pytest 2979 passed / 12 xfailed / 0 failed; ruff 0; mypy Success (180); bandit M0/H0; typecheck 0; lint 0; build ok. vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `schemas.py:136`, `params.py:523`, `params_sync.py:460`, `strategy_params.py:139`, `grid.py:178`, `risk_monitor.py:102`, `engine.py:3017`.

### 5. Контракты
Путь `/versions/from-params` теперь отвечает 422 на нечисловое значение и на риск-параметр вне диапазона; POST `/grid` отвечает 422 на такие же значения в `ranges`. Фронт (`getApiErrorMessage`) показывает оба ответа без правок. Миграции нет.

### 6. Проблемы / правки ФТ / находки
- ФТ §3.4, добавить пункт: «Допустимые значения: стоп-лосс 0–50 %, тейк-профит 0–100 %, размер позиции 0–100 % или от 1 лота. Значение вне диапазона отклоняется при сохранении блоков, при "Применить к стратегии", в Grid Search, перед бэктестом и при запуске сессии. В live уровни берутся только из блоков стратегии. Если значение недопустимо, уровень не выставляется и приходит уведомление (S8R-AUDIT-080).»
- ~~Находка: сохранение из редактора проверяло только тип, но не диапазон~~ — закрыто в доработке п.1.
- SL/TP в пунктах live не поддерживает, как и до фикса.
- `sizing.py` (float, I1-05 low) не трогал: его нет в п.2 рецепта.

### 7. Применённые Stack Gotchas
01 (Decimal в модели, в JSON не отдаётся), 03 и 35 (IR — единый источник), 48 (файл-БД в `tmp_path`), 71.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile/pyright — через реальные прогоны; typecheck `tsc -b`; context7 — pydantic `field_validator`/Field constraints; tdd — `mattpocock-skills:tdd`.

### Доработки по /code-review
1. **[medium] Паритет SL/TP.** `validate_block_fields` проверяет диапазон risk-полей по схеме `RiskParams` (`risk_problem_for_block`, выбор поля по TYPE/MODE). Так проверка работает и на входе API (POST/PUT версии → 422 с блоком и полем), и в `parse_executable_blocks` (старые версии не проходят бэктест/старт). Действуют одни пределы: схема = редактор. **SL ≤ 50 %**: стоп дальше половины цены защитой не является. **TP ≤ 100 % вместо 500 % из рецепта**: при бо́льшем значении уровень TP для short уходит в ноль или ниже; кроме того, это прежний предел редактора, так что ни одна стратегия из редактора не отклоняется. **Размер ≤ 100 %.** На фронте: `export RISK_LIMITS` в `BlockDefinitions.ts`; SL в процентах ограничен 50 через `onchange`, в пунктах остаётся 100. Ограничение не ставится в `init` и не в валидаторе дропдауна: в сохранённом JSON VALUE загружается раньше TYPE, и SL 80 п. обрезался бы. Sync-тест backend — `test_editor_limits_match_schema`.
2. **[low] `"1e309"`.** Конечность проверяется после приведения к float; `"1e309"` и `Decimal("1e309")` → отказ.
3. **[low] Уведомление.** Текст «Сделка открыта без SL/TP: …»; отправляется один раз на сессию (`_SLTP_REJECTED_NOTIFIED`, сброс в `_stop_session_locked`). Event_type прежний, поэтому заголовок остаётся «Ошибка выставления ордера» — точный заголовок требует нового event_type.

Побочное: для старой версии с недопустимым SL `parse_blocks` падает целиком, и в live не ставится ни SL, ни TP (раньше TP сохранялся). Такая версия всё равно не стартует.

**Файлы (добавлены):** `strategy/block_allowlist.py`, `frontend/.../BlockDefinitions.ts`, `frontend/.../__tests__/riskLimits.test.ts`.
**RED:** `DID NOT RAISE ValidationError` (×8), `assert 201 == 422` (POST /versions, SL 60), `RISK_LIMITS не найден`, `DID NOT RAISE ValueError` (1e309), `startswith('Сделка открыта без SL/TP:')` → False, `assert 3 == 1` (дедуп); vitest `expected undefined to deeply equal {…}`, `expected 80 to be 50`.
**GREEN:** 53 backend + 4 vitest.
**Мутация:** в `validate_block_fields` вызов проверки диапазона заменён на `problem = None` → 9 failed (`DID NOT RAISE`, `201 == 422`). Откат через cp, md5 совпал.
**Гейт:** pytest 2998 passed / 12 xfailed / 0 failed; ruff 0; mypy Success (180); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 940 passed / 1 failed. Упал `StrategyEditPageDelete` «Удалить все при частичном отказе» по таймауту 5000 мс, дважды в полном прогоне. Это известный флейк S8R-FIX-005: отдельно файл проходит 2/2, а StrategyEditPage мои правки не затрагивают.
**ФТ §3.4 (поправка к п.6):** «тейк-профит 0–100 %»; в редакторе стоп-лосс в процентах — не более 50.
**Находка:** у `management_position_size` та же ловушка порядка загрузки: при MODE=fixed с лотами > 100 значение обрезается до 100 до того, как загрузится MODE. Код до фикса, не правил.
