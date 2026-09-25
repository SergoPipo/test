## DEV-AUDIT-074 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. Что уже закрыли 024/030 (проверено тестом): `client_order_id` пишется до отправки; recovery ищет ордер по ключу, `pending` без `broker_order_id` не помечается `failed` вслепую; каждый вызов брокера ограничен 10 с. Что **ещё воспроизводилось** (RED): отмена listener'а посреди `place_order` теряла ответ брокера — сделка оставалась `pending` без `broker_order_id`; `shutdown` не прогонял recovery и отменял periodic-задачу первой.
2. `engine.run_shielded_from_cancel(coro, trade_id, what)` — участок под `asyncio.shield`; отменённый вызывающий **дожидается** защищённой части (до `ORDER_CANCEL_GRACE_SEC`), затем пробрасывает `CancelledError`. Выбран вариант «дождаться», а не «фоновая задача со своей сессией»: тело пишет в `self.db` вызывающего и держит `close_trade`-лок, оба живут до выхода вызывающего (gotcha-38). Истечение grace — аварийный путь: задача отменяется, сделку доводит recovery по ключу.
3. Вход: под shield — `_place_entry_and_commit_id` (`place_order` + немедленный commit `broker_order_id`); учёт ответа (`_apply_entry_response`) — после, отменяем.
4. Выход (RiskMonitor из того же listener'а): под shield — `_place_exit_and_commit_id` (`place_order` + commit `exit_broker_order_id`); разбор потерянного ответа — вне.
5. `_SessionListener.accepting`/`idle`: «снять с новых свечей» без отмены задачи; `stop()` ставит флаг перед `cancel()`.
6. `shutdown()`: флаг + `_quiesce_listeners` → suspended (не тронуто) → параллельный stop → recovery без порога возраста → `_wait_pending_orders` → отмена periodic → уведомление (не тронуто); всё под `SHUTDOWN_TOTAL_TIMEOUT_SEC`. Порядок локов не менялся.

### 2. Файлы
Новые: `backend/tests/test_trading/test_stop_during_order.py` (5 тестов). Изменённые: `backend/app/trading/engine.py`, `backend/app/trading/runtime.py`.

### 3. Тесты
RED: `assert None == 'sb-stop-1'` (status=pending, broker_order_id=None); `recovery не прогнан при shutdown … assert []`. GREEN: оба. Мутация `await asyncio.shield(inner)` → `await inner` → `assert None == 'sb-stop-1'`, откачена. Гейты (финал): pytest 2885 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `run_shielded_from_cancel` ×3, `_place_entry_and_commit_id` ×2, `_send_entry_order`, `_send_exit_and_record`, `_place_exit_and_commit_id` — `engine.py`; `_quiesce_listeners`, `_run_shutdown_recovery`, `_await_with_deadline` ×2, `_recover_orphan_pending_trades(include_fresh=True)` — `runtime.py`. Эндпоинтов/событий/схем нет.

### 5. Контракты
API/схемы/миграции не менялись.

### 6. Проблемы / предлагаемые правки
- ТЗ §8.6, шаги: «3. Снять listener'ы с новых свечей и дождаться текущего цикла (timeout 30 с); отправка ордера и запись его id защищены от отмены. 4. status → 'suspended', остановить listener'ы параллельно. 5. Прогнать recovery без порога возраста (разрешаются только найденные у брокера ордера), дождаться pending orders (timeout 30 с). Весь shutdown — не дольше 45 с.»
- ФТ («Стоп/Пауза»): в момент отправки ордера дожидаются записи его id (до 45 с); учёт исполнения доводит recovery.
- Гайд/`docker-compose.yml`: `stop_grace_period` **не задан** → Docker убьёт процесс через 10 с, раньше даже дедлайна отправки. Предлагаю `stop_grace_period: 60s` для `backend` (45 с shutdown рантайма + запас на backtest-менеджер, планировщик, стримы в lifespan) — в гайд §3.3.
- Находка вне карточки: `_wait_pending_orders` ждёт по любой `pending`-строке, включая «исход неизвестен» младше 120 с — каждый такой shutdown длится 30 с.

### 7. Применённые Stack Gotchas
38, 59, 71, 27.

### 8. Новые Stack Gotchas
Кандидат: «`asyncio.shield` защищает тело, не сессию/лок вызывающего — отменённый вызывающий обязан дождаться shield-задачи; под shield держать только send + commit id, иначе grace не покрывает участок» (`engine.py::run_shielded_from_cancel`); номер — оркестратору.

### 9. Плагины
py_compile; `pnpm typecheck` (`tsc -b`); context7 не требовался; TDD — `mattpocock-skills:tdd`.

### 10. Доработки по /code-review
1. [high] Shield сужен до `place_order` + немедленный commit `broker_order_id` (`_place_entry_and_commit_id`, обе отправки); чтение состояния/опрос PLACED — после, отменяемы. Статус остаётся `pending` намеренно: `filled` без цены/SL-TP recovery не доучёл бы. Худший случай под shield = 10 с (дедлайн 030) + 30 с (`busy_timeout` SQLite) = 40 с → `ORDER_CANCEL_GRACE_SEC = 45`, читается при вызове; комментарий переписан. Выход: `_place_exit_and_commit_id` — то же. Тест `test_shield_commits_broker_order_id_before_status_polling`: RED `broker_order_id=None, 10.01s` → GREEN; мутация «убрать commit после отправки» → 2 теста красные (`broker_order_id=None`), откачена.
2. [medium] `_recover_orphan_pending_trades(include_fresh=True)` для shutdown: без порога 300 с, разрешает только найденные у брокера (существующая `resolve_entry_order`, «нет» — по правилу 120 с), свежие без ключа не трогает; докстринг shutdown исправлен (фоновая задача выходит по флагу без прохода). Тест `test_shutdown_recovery_resolves_fresh_pending_found_at_broker`: RED `не доведён при shutdown: pending` → GREEN.
3. [medium] `stop()` всех сессий — параллельно (`_await_with_deadline`: `asyncio.wait` + отмена отставших, ошибки одной не роняют остальные); общий дедлайн `SHUTDOWN_TOTAL_TIMEOUT_SEC = 45` (обоснование в п.1: меньше нельзя, ужать до Docker-10 с — обрывать одиночный `place_order`); `stop_grace_period` в compose отсутствует — предложение выше. Тест `test_shutdown_stops_sessions_in_parallel_under_total_deadline` (6 сессий): RED `занял 3.24s` → GREEN (< 2 с).
Полный backend-гейт после доработок: 2885 passed / 16 xfailed / 0 failed; ruff 0; mypy Success; bandit M0/H0.
