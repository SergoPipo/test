---
sprint: 7
agent: DEV-1 (BACK1)
wave: 1
date: 2026-04-25
status: completed
---

# DEV-1 BACK1 W1 — отчёт

## 1. Что реализовано

- **7.13** — 5 event_type подключены к runtime/broker через `EVENT_MAP` и
  publish-сайты в production: `trade.opened` (engine.py paper-fill + real
  on_order_filled), `order.partial_fill` (PositionTracker.on_order_filled
  при `filled_lots < volume_lots`), `order.error` (helper
  `_publish_order_error`, вызов из process_signal try/except),
  `connection.lost` / `connection.restored` (multiplexer reconnect-loop с
  анти-спам флагом `_connection_event_published`).
- **7.13 фан-аут broker:** новый канал `broker:status` + listener
  `NotificationService.listen_broker_status()` подключён в `lifespan`.
  Развозит `connection.*` по всем известным `user_id` через
  `_session_user_map` (строится в `listen_session_events`).
- **7.15-be** — WS endpoint `/ws/trading-sessions/{user_id}` (контракт C1):
  auth-first (gotcha-16), snapshot активных сессий через JOIN
  strategy.user_id, динамическая подписка через `system:{user_id}` для
  новых сессий, маппинг trading-событий на client-events
  (position_update / trade_filled / pnl_update / session_state).
- **7.17-be** — фоновый бэктест: модель `BacktestJob` + alembic-миграция
  `a7b2c83d4e51_add_backtest_jobs` (rollback проверен), singleton
  `BacktestJobManager` в `app.state` (per-user cap=3, asyncio.Lock,
  `asyncio.shield` на cleanup при cancel), WS endpoint
  `/ws/backtest/{job_id}` с auth/ownership/snapshot/grace=30s, REST
  endpoints: POST run-async / GET jobs / GET jobs/{id} / POST cancel.

## 2. Файлы

**Новые:**
- `app/trading/ws_sessions.py`
- `app/backtest/jobs.py`
- `app/backtest/ws_backtest.py`
- `alembic/versions/a7b2c83d4e51_add_backtest_jobs.py`
- `tests/test_notification/test_runtime_events.py`
- `tests/test_trading/test_ws_sessions.py`
- `tests/unit/test_backtest/test_jobs.py`
- `tests/unit/test_backtest/test_ws_backtest.py`

**Изменённые:**
- `app/notification/service.py` (5 EVENT_MAP записей; `listen_broker_status` /
  `stop_broker_listener` / `_broker_status_loop`; `_session_user_map`).
- `app/broker/tinvest/multiplexer.py` (publish connection.*; helper
  `_publish_connection_event`; флаг анти-спама).
- `app/trading/engine.py` (publish `trade.opened` paper+real, `order.partial_fill`
  при partial fill, helper `_publish_order_error` + try/except в process_signal).
- `app/backtest/models.py` (модель `BacktestJob` + индекс `idx_bj_user_active`).
- `app/backtest/router.py` (4 новых endpoint).
- `app/main.py` (registration двух WS-роутеров; в lifespan —
  `listen_broker_status` + `BacktestJobManager` singleton; reverse shutdown).

## 3. Тесты

`pytest tests/ -q` → **770 passed, 1 failed**. Failed —
`tests/test_trading/test_order_manager.py::TestOrderManagerProcessSignal::test_process_buy_signal`,
**pre-existing** (был до моих изменений: тест ожидает `trade.status=='pending'`,
но paper-mode код мгновенно ставит `'filled'` ещё с baseline; не связан с
моими задачами). Baseline до W1 = 729 passed → теперь 770 = **+41 нового
теста, все зелёные**:

- `test_runtime_events.py` — 16 (payload-contract на 5 event_type, listener
  trades/system, multiplexer publish).
- `test_ws_sessions.py` — 3 (auth fail / user mismatch / snapshot+delta).
- `test_jobs.py` — 7 (submit-run-done, runner-exception → error,
  per-user cap, cancel in-flight, cancel wrong user, list filter,
  shutdown).
- `test_ws_backtest.py` — 3 (auth fail / wrong user / snapshot+progress).

Линтер: `ruff check ...` → 0 issues. Compile: `py_compile` все изменённые
.py — 0 ошибок. Alembic: `upgrade head` + `downgrade -1` + `upgrade head` —
работает.

## 4. Integration points

- `grep -rn` подтверждает publish-сайты 7.13 в production:
  `app/trading/engine.py:846/885/1171/1201`, `app/broker/tinvest/multiplexer.py:221/244`.
  EVENT_MAP — `app/notification/service.py:76-104`.
- `BacktestJobManager(AsyncSessionLocal)` — `app/main.py:85` (production-инстанциация).
- WS routes (видно через `app.routes`): `/ws`, `/ws/trading-sessions/{user_id}`,
  `/ws/backtest/{job_id}` (`app.include_router(...)` в main.py:188 и 190).
- `NotificationService.listen_broker_status()` вызывается в lifespan
  (`app/main.py:71`), `stop_broker_listener()` — в reverse shutdown.

Помеченных `⚠️ NOT CONNECTED` нет.

## 5. Контракты

- **C1 (поставщик):** WS `/ws/trading-sessions/{user_id}` опубликован первым
  (по требованию execution_order §4). Совместим с FRONT1 клиентом
  `useTradingSessionsWS` (DEV-3 уже написал по схеме arch §4.3).
- **C2 (поставщик):** WS `/ws/backtest/{job_id}` опубликован. Совместим с
  FRONT1 `useBacktestJobWS` — те же события (queued/started/progress/done/
  error/cancelled) и поля (progress, result, message).
- **C5 (W2, не в W1):** Grid Search backend — отложено.
- **C7 (потребитель):** на момент работы DEV-2 (BACK2) уже опубликовал
  `app.state.notification_service` через DI helper. Я подключил
  `listen_broker_status()` в lifespan + читаю NS из app.state в backtest_router.
  **Контракт соблюдён.** `grep -rn "NotificationService()" app/` = 0 вне
  `main.py`.
- **C9 (W2, не в W1):** balance/history endpoint — отложено.

## 6. Проблемы / TODO

- Pre-existing fail `test_process_buy_signal` (paper-fill ставит status=
  'filled' мгновенно, тест ожидает 'pending') — карточка для S7 Review,
  не моя зона.
- Метаданные `BacktestJob.params_json` сериализуются через
  `json.dumps(..., default=str)` — для `Decimal` это даст строку, что
  нормально для read/render, но при rerun нужно явно парсить обратно
  (отложено на 7.2-be Grid Search W2).
- Grace period 30 сек на WS закрытие реализован (`asyncio.sleep`). В
  тестах не покрывается — потенциальный кандидат на e2e в QA W1.

## 7. Применённые Stack Gotchas

- **#04 (T-Invest streaming):** `_publish_connection_event` обёрнут в
  try/except — не ломает reconnect-loop. Backoff не изменён.
- **#08 (AsyncSession.get_bind):** в тестах `BacktestJobManager` — отдельный
  `create_async_engine` + `StaticPool`. Фикстура `jobs_manager` гарантирует
  shutdown manager до `engine.dispose()` — фоновые tasks не пишут в
  закрытый engine.
- **#11 (alembic drift):** новая миграция содержит **только**
  create_table backtest_jobs + create_index. Drift не подтянут.
- **#12 (sqlite batch_alter):** в миграции — server_default'ы
  `sa.text("'queued'")`/`sa.text("0")`/`sa.text("CURRENT_TIMESTAMP")`,
  не `func.now()`.
- **#16 (relogin race):** WS-эндпоинты — auth первым сообщением (не
  query-param). JWT не утекает в access-логи.
- **gotcha-18 аналог:** анти-спам флаг для connection.lost (один publish
  на disconnect-цикл).

## 8. Новые Stack Gotchas + плагины

Новых ловушек не создано — все встретившиеся симптомы покрыты
существующими записями.

**Плагины:**
- pyright fallback `python -m py_compile` — после **каждого** Edit/Write,
  0 ошибок.
- `ruff check` — 0 issues по всем затронутым файлам.
- context7 не вызывался: API FastAPI WebSocket / SQLAlchemy
  async / alembic / asyncio.Lock / asyncio.shield — стабильные паттерны
  из прошлых спринтов и LSP-описаний.
- TDD (superpowers TDD) — итеративные red→green циклы для
  `BacktestJobManager.cancel()` / `_run_job` / `_enforce_cap`. Нашёл
  race с asyncio cleanup при cancel — добавил `asyncio.shield` вокруг
  финального `_update_status('cancelled')`. Также race в тесте
  `test_cap_blocks_extra_submissions` — добавил явные barrier'ы между
  `submit` (gotcha-08-like при StaticPool + параллельных commit'ах).
- Migrations: `alembic upgrade head` + `alembic downgrade -1` + `alembic
  upgrade head` — отработали без ошибок.
