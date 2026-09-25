## DEV-AUDIT-089 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Дивиденд и купон считаются на **штуки**: `amount_per_share × лоты × lot_size`; вычет НКД в купоне — тоже на штуку: `(amount − nkd_entry) × units`.
- Одна точка получения множителя — новый приватный `CorporateActionService._position_units(trade, ticker)`; выбран вариант «как tax»: `RiskMonitor.derive_lot_size(trade, 0)` из `volume_rub` входа (авторитетно на момент сделки, без сети), при 0 — fallback `MarketDataService.ensure_lot_size(ticker)` (кэш инструментов, не бросает). После S8R-AUDIT-025 источник меняется в этом одном методе.
- `filled_lots` 0/None у open-сделки → `volume_lots` (fallback сохранён).
- Квантование денег — общий `_MONEY_QUANT`; `process_split` и UniqueConstraint не тронуты.
- Импорт `RiskMonitor` — inline (как в tax), чтобы не завести циклический импорт.

### 2. Файлы
- Изменён: `backend/app/corporate_actions/service.py` (+45/−12).
- Новый: `backend/tests/unit/test_corporate_actions/test_audit_s8r_lot_size.py` (4 теста). Отклонение от рецепта: путь `tests/test_corporate_actions/` не существует, все тесты модуля лежат в `tests/unit/test_corporate_actions/`.

### 3. Тесты
RED: `AssertionError: assert Decimal('100.00') == Decimal('1000.00')` (дивиденд, ровно ×10 меньше); купон `assert Decimal('137.50') == Decimal('875.00')`. → GREEN: `test_dividend_uses_units_not_lots`, `test_coupon_uses_units_not_lots`, `test_dividend_open_trade_without_filled_lots_falls_back_to_volume_lots`, `test_dividend_without_volume_rub_uses_instrument_cache` — 4 passed; модуль целиком 37 passed.
Мутация `return Decimal(str(lots))` (множитель убран) → `assert Decimal('100.00') == Decimal('1000.00')`, `assert Decimal('87.50') == Decimal('875.00')`; откачена, 4 passed.
Гейты: pytest **2722 passed / 21 xfailed / 0 failed** (441 с); ruff 0; mypy Success (178); bandit M0/H0; typecheck 0; lint 0; build ok; vitest полный прогон **918 passed / 8 failed / 2 expected fail** — все 8 «Test timed out in 5000ms» при load average 18.8 (соседний worktree `wt-s8r-fixes` гонял vitest на 9 воркерах); фронт не менялся (`git status` — только backend). Перепрогон упавших файлов с `--testTimeout=30000`: 26/27, остаток — известный флейк **S8R-FIX-005** (`StrategyEditPageDelete «при частичном отказе»`). Маркеров `S8R-AUDIT-089` в дереве нет.

### 4. Integration points
✅ `_position_units` вызывается в `app/corporate_actions/service.py` (`process_dividend`, `process_coupon`); они — из `process_pending`, который дёргает `app/scheduler/service.py` (job `check_corporate_actions`). Новых эндпоинтов/событий нет.

### 5. Контракты
API/схемы/миграции не менялись.

### 6. Проблемы / предложения / новые находки
- **Семантика `nkd_entry` расходится между модулями.** В `app/` колонку никто не пишет (движок не заполняет; `ТЗ §5.12` ссылается на `BondService.calculate_nkd` — на одну облигацию). Рецепт 089 задал вычет «на штуку», tax `_build_fifo_queue` считает `nkd_exit − nkd_entry` как сумму по позиции без `× qty`. Предлагаю зафиксировать в ТЗ §4.x (модель `live_trades`): «`nkd_entry`/`nkd_exit` — НКД на одну облигацию, ₽» и привести tax к `× quantity_units` отдельной карточкой (не в 089: другой модуль). Пока писателя нет — денежного эффекта нет.
- ФТ §6.4 предлагаю уточнить: «**Дивиденды:** … начисление = ставка на акцию × количество акций в позиции (лоты × размер лота)»; «**Купоны:** … купон и уплаченный при покупке НКД считаются на одну облигацию и умножаются на количество бумаг».
- Вне карточки: `process_dividend`/`process_coupon` — DailyStat правится только при наличии строки за сегодня (без upsert) — уже отражено в 090.

### 7. Применённые Stack Gotchas
27/28 (Decimal через `str`, без Mock без spec), 57 (штуки = лоты × derive_lot_size), 50 (все команды из worktree), 60 (`tsc -b`).

### 8. Новые Stack Gotchas
Нет; наблюдение по флейкам vitest под нагрузкой совпадает с S8R-FIX-005.

### 9. Использование плагинов
pyright-lsp недоступен в worktree → `py_compile` OK + реальный прогон; `pnpm typecheck` (tsc -b) 0; context7 не требовался (сторонние API не использованы); TDD — скилл `mattpocock-skills:tdd`: тест → RED → правка → GREEN → мутация.
