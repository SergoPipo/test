## DEV-FIX-027 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Из модели `CircuitBreakerConfig` убрана колонка `block_shorts` (и неиспользуемый импорт `Boolean`).
- Поле убрано из схем `CircuitBreakerConfigRequest`, `CircuitBreakerConfigResponse` и `CheckStatusResponse`.
- `service.upsert_config` и `get_status` больше не читают и не пишут это поле.
- Из `engine.py` удалены метод `_check_short_block` и его вызов в `check_before_order`: проверок стало 8, событие `short_block` больше не возникает. Комментарии в `engine.py` и `runtime.py` поправлены.
- Логика `process_signal` и `entry_direction` не менялась.
- API: если старый клиент пришлёт `block_shorts`, поле **игнорируется** (200, а не 422). Причина: ни одна схема CB, да и приложения в целом, не ставит `extra=forbid`.
- Миграция `bbb9a0908e89`.
- Обновлены тесты и фикстуры со старым полем, из e2e-мока статуса убрано `block_shorts: false`. Скрипт `scripts/load_signal_to_order.py` иначе падал бы на `TypeError`.

### 2. Файлы
Новые: `alembic/versions/bbb9a0908e89_drop_cb_block_shorts.py`, `tests/test_circuit_breaker/test_block_shorts_removed.py`.
Изменённые: `app/circuit_breaker/{models,schemas,service,engine}.py`, `app/trading/runtime.py` (только комментарий), `scripts/load_signal_to_order.py`, `tests/test_circuit_breaker/{conftest,test_config,test_engine,test_integration,test_router,test_trading_hours_holiday,test_trading_hours_validation}.py`, `tests/test_routers/test_circuit_breaker_router.py`, `tests/test_trading/test_paper_short_blocked_or_accounted.py`, `tests/unit/test_migration.py`, `frontend/e2e/fixtures/api_mocks.ts`.
Удалённые тесты старого поведения: `TestShortBlock` (2), `test_order_blocked_by_short_block`, `test_cb_short_block_*` (2).

### 3. Тесты
- RED: `AssertionError: CheckResult(blocked=True, reason='Short-ордера заблокированы (фаза 1)', event_type='short_block', …)`; `assert 'block_shorts' not in {'block_shorts', 'cooldown_seconds', …}` (миграция); `assert 'block_shorts' not in {… 'block_shorts': True …}` (PUT/status). Всего 7 failed.
- GREEN: 204 passed (`test_circuit_breaker/`, `test_migration.py`, роутер CB, short-файл).
- Мутация «вернуть `_check_short_block` и его вызов» → `AssertionError: CheckResult(blocked=True, … event_type='short_block' …)` и `assert ['app/circuit...ngine.py:989'] == []`. Откат из бэкапа, md5 сошёлся.
- Гейты: pytest 4386 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (193); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 1005 passed (фронт изменён только в e2e-моке).

### 4. Integration points
Новых функций, эндпоинтов и `event_type` нет. `short_block` не было ни в `EVENT_MAP`, ни в `EVENT_TYPE_LABELS`, во `frontend/src` поле не встречается. NOT CONNECTED — нет.

### 5. Контракты
- Из ответов `GET/PUT /circuit-breaker/config` и `/status` пропало `block_shorts`; во входящем теле оно игнорируется.
- Миграция `bbb9a0908e89` (down_revision `6f3a063d1c2e`): `batch_alter_table` снимает колонку; `downgrade` возвращает `BOOLEAN NOT NULL DEFAULT '1'`.
- Round-trip на чистой временной БД прошёл: upgrade → downgrade -1 → upgrade. `alembic heads` — один. Pytest-тест проверяет, что строки и индекс `idx_cb_config_user` сохраняются.

### 6. Проблемы и предлагаемые правки документов
- **ФТ §12.4:** «`CircuitBreakerEngine` (9 проверок)» → «(8 проверок)». Пункт «Запрет разнонаправленной…», фразу «Short, не заданный стратегией, блокируется» заменить на: «Short, не заданный стратегией, не открывается: SELL long-стратегии без позиции — HOLD до Circuit Breaker (S8R-AUDIT-032); отдельного флага CB «запрет шорта» нет (удалён, S8R-FIX-027).»
- **ТЗ §5.8:** убрать строку `self._check_short_block(signal),` из листинга `check_before_order`. В историю 3.0 добавить: «`S8R-FIX-027`: флаг CB `block_shorts` и проверка `_check_short_block`/событие `short_block` удалены, миграция `bbb9a0908e89`; поле в теле запроса игнорируется (§5.8).» В записи S8R-AUDIT-032 пометить фразу про `block_shorts` как снятую.
- **Гайд §7:** `alembic current # ожидается: bbb9a0908e89 (head)` (строки 125 и 356), плюс абзац: «> **ℹ️ Обновление с версии старше `bbb9a0908e89` (S8R-FIX-027, 2026-09-30).** Снимает колонку `circuit_breaker_configs.block_shorts` (флаг запрета шорта; после S8R-AUDIT-032 штатно не действовал). Строки конфигов сохраняются; `downgrade` возвращает колонку со значением `1`.»
- Новая находка: `test_stream_figi_from_ensure_figi.py::test_silent_source_one_network_wait_per_session_start` — тайминговый флейк под нагрузкой (`assert 0.406 < 2*0.2`). Изолированно проходит 3/3, повторный полный прогон зелёный.
- Самопроверка: 1 — новых путей записи нет; 2 — один источник паузы и уведомления ушёл, новых нет; 3 — тест идёт через настоящий `check_before_order`; 4 — н/п; 5 — вызывающий `check_before_order` не менялся; 6 — лишнее поле отбрасывается.

### 7. Применённые Stack Gotchas
12, 53 (случайный id, дублей нет), 79 (FK OFF в `env.py` сверен).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile по всем правленым `.py`; `pnpm typecheck` (tsc -b); tdd-скилл загружен; context7 не понадобился — новых API сторонних библиотек нет.
