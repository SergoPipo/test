# Sprint 7 — Changelog

> Лог изменений по дням. Обновляется **немедленно** после каждого блока изменений
> (правило памяти `feedback_changelog_immediate.md`).
>
> Формат записи: `## YYYY-MM-DD — короткое название`. Внутри — bullet'ы:
> - **Что:** краткое описание изменения
> - **Файлы:** перечень
> - **Результат:** что работает / что сломалось / тесты

---

## 2026-04-25 — Планирование Sprint 7

- **Что:** Утверждён spec `sprint_design.md` (5 секций + 4 приложения, 17 задач + 7.R).
- **Что:** Создан `sprint_implementation_plan.md` (21 задача) для разворачивания файлов спринта.
- **Что:** Развёрнуты файлы спринта inline-исполнением плана: README, sprint_state, preflight, changelog, execution_order, e2e_test_plan, 9 промптов, 6 UX-плейсхолдеров, reports/.gitkeep.
- **Файлы:** `Sprint_7/*` (~22 файла), указатели в `docs/superpowers/{specs,plans}/`.
- **Решения:**
  - AI слэш-команды включены в S7 как 7.18/7.19 (требуют обновления ФТ/ТЗ/плана на 7.R).
  - Блок A — все 7 Should-задач (7.1–7.9 без 7.4/7.5, закрытых в S6).
  - 6 переносов из S6 закрываем все (7.12–7.17), debt first.
  - Подход 2 — параллельные треки с pre-sprint W0.
  - RACI-корректировка: 7.1 → BACK2 (Strategy Engine), 7.12 → BACK2 (Notification Service).
- **Ветка:** `docs/sprint-7-plan` (имя подтверждено заказчиком, базовая `main`).
- **Результат:** 17 задач, ~14 рабочих дней, гибкое продление при необходимости. Файлы спринта готовы к запуску W0.

## 2026-04-25 — QA W0 (E2E план + preflight)

- **Что:** заполнен `e2e_test_plan_s7.md` — 47 сценариев на 17 задач (TBD устранены), карта регрессии 16 групп ui-checks, performance-таблица, кандидаты на skip-тикеты.
- **Что:** pre-flight окружения (W0 часть) пройден: Python 3.11.15, Node v20.20.1, pnpm 9.15.9, playwright 1.59.1, venv/node_modules/playwright.config — на месте; sergopipo (id=1) подтверждён в `Develop/backend/data/terminal.db`.
- **Что:** длительные пункты (uvicorn/pnpm dev, baseline pytest/vitest, baseline E2E 119/0/3) помечены `⏸️ deferred to W1`.
- **Файлы:** `Sprint_7/e2e_test_plan_s7.md`, `Sprint_7/reports/QA_W0_test_plan.md`.
- **Замечание:** текущая ветка `main` (план: `docs/sprint-7-plan`) — оркестратор согласует перед коммитом DEV W1. UX-макеты в `ux/` пока плейсхолдеры — `data-testid` в плане ожидаемые, точечно правятся после публикации UX W0.
- **Результат:** QA-часть гейта W0 → W1 готова. Блокеров на старт DEV нет.

## 2026-04-25 — ARCH W0 (design ревью + brainstorm 6 задач)

- **Что:** создан `arch_design_s7.md` — 10 секций, дословные цитаты ТЗ/ФТ для каждой подзадачи, brainstorm-итерации (вопрос → варианты → решение → обоснование) для 7.1, 7.2, 7.13, 7.15, 7.17, 7.18.
- **Что:** §1 Версионирование: расширение существующей `strategy_versions` (`+created_by`, `+comment`), политика «авто-снимок на Save с idempotency 5 мин» + явная именованная версия + history-preserving restore. DDL подготовлен для DEV-2 W2.
- **Что:** §2 Grid Search: `multiprocessing.Pool` (workers = cpu-1), hard cap 1000 комбинаций ≤ 5 параметров, переиспользуем `/ws/backtest/{job_id}` с `result.matrix`, overfitting-предупреждение по разбросу sharpe.
- **Что:** §3 5 event_type → runtime: добавлены EVENT_MAP записи (`trade.opened`, `order.partial_fill`, `order.error`, `connection.lost`, `connection.restored`); указаны file:line publish-сайтов (engine.py on_order_filled, OrderManager.process_signal helper, multiplexer.py:207/213). Анти-спам флаг для connection_lost.
- **Что:** §4 WS `/ws/trading-sessions/{user_id}`: auth через первое сообщение (паттерн ТЗ §4.12), snapshot+delta, подписка на `system:{user_id}` для динамики, удаление polling 10s одним PR.
- **Что:** §5 фоновые бэктесты: новая таблица `backtest_jobs` (DDL готов), per-user cap 3, кастомный executor (asyncio.create_task + BacktestJobManager в app.state, не FastAPI BackgroundTasks), WS-канал закрывается через 30 сек после терминала.
- **Что:** §6 AI context: `ChatRequest.context: list[ContextItem]` с типами {chart, backtest, strategy, session, portfolio}; защита — Pydantic + ownership-check + sanitization + `[CONTEXT]...[/CONTEXT]` prefix + rate-limit 10/min. Frontend парсит slash-команды локально.
- **Что:** §7 Stack Gotchas pre-read: 7 ключевых ловушек выписаны (#04, #08, #11, #12, #15, #16, #17) с привязкой к задачам S7.
- **Что:** §8 UX-стыки: 6 макетов проверены, найдена 1 delta — нужен новый легковесный endpoint `GET /api/v1/account/balance/history?days=30` для sparkline в виджете баланса (контракт C9 NEW).
- **Что:** §9 Cross-DEV контракты — добавлен C9 (balance/history); C1-C8 синхронизированы со sprint_design.
- **Файлы:** `Sprint_7/arch_design_s7.md`, `Sprint_7/reports/ARCH_W0_design.md`.
- **Плагины:** WebSearch — JWT WS auth и multiprocessing.Pool best practices; superpowers:brainstorming — итерации внутри секций; context7 не вызывался (паттерны стабильные, проверены в коде).
- **Результат:** ARCH-часть гейта W0 → W1 готова. Блокеры для старта W1 — нет. Alembic-миграции отложены на W2 (по DDL §1.3 и §5.3).

## 2026-04-25 — UX W0 (6 макетов)

- **Что:** заполнены все 6 макетов в `Sprint_7/ux/*.md` по `prompt_UX.md` секция «Задачи W0». Плейсхолдеры заменены полным содержимым: ASCII-mockup, состояния (loading/empty/error/success), поведение, контракт с backend, a11y, тестовые сценарии для QA с `data-testid`, Stack Gotchas замечания.
- **Что:** проведено согласование с `arch_design_s7.md` §8 — внесены ARCH-delta:
  - `drawing_tools.md` — persist в БД (`chart_drawings` по ТЗ §3.14), не в localStorage.
  - `dashboard_widgets.md` — sparkline через новый endpoint C9 `GET /api/v1/account/balance/history?days=30`.
  - `background_backtest_badge.md` — per-user cap = 3 (а не 5–10), bootstrap через `GET /api/v1/backtest/jobs?status=running`, отмена через `DELETE /api/v1/backtest/jobs/{id}`, WS-канал закрывается через 30s после терминала.
- **Файлы:**
  - `Спринты/Sprint_7/ux/dashboard_widgets.md` (7.7)
  - `Спринты/Sprint_7/ux/wizard_5steps.md` (7.8)
  - `Спринты/Sprint_7/ux/drawing_tools.md` (7.6)
  - `Спринты/Sprint_7/ux/backtest_overview_analytics.md` (7.16)
  - `Спринты/Sprint_7/ux/background_backtest_badge.md` (7.17)
  - `Спринты/Sprint_7/ux/ai_commands_dropdown.md` (7.18/7.19)
  - `Спринты/Sprint_7/reports/UX_W0_design.md` (новый)
- **Кандидаты в Stack Gotchas:** localStorage quota для drawings; bucket-edge inclusivity для гистограммы P&L; WS reconnect storm на reload; 403 vs 404 ownership leak в AI-context. ARCH регистрирует на 7.R.
- **Результат:** UX-часть гейта W0 → W1 готова. Блокеров нет.

## 2026-04-25 — DEV-2 W1 (BACK2): 7.12 NS singleton DI + 7.14 Telegram callbacks

- **Задача 7.12 (контракт C7 — поставщик):**
  - **Что:** опубликован FastAPI Depends-helper `get_notification_service` для singleton'а NotificationService. Все потребители вне `main.py` берут сервис только через `app.state.notification_service` либо `Depends(get_notification_service)`. Ранее `app/market_data/router.py:84` создавал `PriceAlertMonitor(db_factory=None)` без NS — уведомления о ценовых алертах вне in-app канала молча терялись. Теперь `PriceAlertMonitor` создаётся один раз в lifespan вместе с NS singleton'ом и кладётся в `app.state.price_alert_monitor`.
  - **Файлы:** `app/notification/dependencies.py` (новый), `app/notification/__init__.py` (экспорт helper'а), `app/main.py` (PriceAlertMonitor singleton в lifespan), `app/market_data/router.py` (read singleton из `app.state`, добавлен `request: Request`).
  - **Контрактная проверка C7:** `grep -rn "NotificationService()" app/` → 0 совпадений вне `main.py`. Потребители DI: `app/backtest/router.py:314,485` (через `app.state.notification_service`), все `app/trading/`, `app/scheduler/`, `app/market_data/price_alert_monitor.py` (через ctor injection из main).
- **Задача 7.14 (контракт C8 — поставщик):**
  - **Что:** доработан `_handle_callback` в `TelegramWebhookHandler` — по `open_session:{id}` теперь идёт ownership-check (`Strategy.user_id == user.id` через JOIN на `StrategyVersion → TradingSession`); по `open_chart:{ticker}` — валидация тикера (alnum + `_`, ≤ 20 симв) и deep link через новый `settings.FRONTEND_URL`. Раньше `open_chart:` принимал id и не строил deep link на фронтенд.
  - **Что:** `TelegramNotifier.send` принимает `ticker` отдельным аргументом — `_build_keyboard` теперь корректно собирает `open_chart:{ticker}` для price_alert/trade-уведомлений (раньше использовался id алерта/трейда). `NotificationService.dispatch_external` резолвит ticker по `related_entity_type` (`instrument` → `PriceAlert.ticker`, `trade` → `LiveTrade.session.ticker`).
  - **Файлы:** `app/notification/telegram_webhook.py`, `app/notification/telegram.py`, `app/notification/service.py`, `app/config.py` (новый `FRONTEND_URL`).
  - **Deep link формат:** `{FRONTEND_URL}/trading?session={id}` для сессий, `{FRONTEND_URL}/chart/{TICKER}` для тикеров.
- **Тесты:**
  - `tests/test_notification/test_singleton_di.py` (5 тестов: helper-singleton, dual-call same id, RuntimeError при пустом state, override через state, и контрактный grep на отсутствие `NotificationService()` вне main.py).
  - `tests/test_notification/test_telegram_callbacks.py` (7 тестов: deep link, uppercase ticker, отказ на мусорный ticker, owned session → deep link, foreign session → 404, unlinked chat → отказ, invalid id).
  - Запуск: `pytest tests/test_notification/ tests/unit/test_notification/ -q` — **61 passed, 0 failed**.
  - Полный subset (без trading/market_data/circuit_breaker — параллельная работа BACK1) — **604 passed**. В `test_trading/test_order_manager.py::test_process_buy_signal` фиксируется failure, но это территория BACK1 (изменён OrderManager, BUY-сигнал теперь сразу `filled` вместо `pending`) — не связано с 7.12/7.14.
- **Stack Gotchas:** прочитаны #11 (alembic drift — миграций в W1 нет), #12 (sqlite batch_alter — миграций нет), #17 (telegram bot frozen attrs — в новых тестах используются stub-объекты, патч `Bot.send_message` не нужен). Новых ловушек не найдено.
- **Плагины:** pyright fallback `python -m py_compile` после каждого Edit — 0 ошибок. context7/WebSearch не вызывались (FastAPI Request, python-telegram-bot 20+ уже использовались в S6).
- **Cross-DEV координация:** BACK1 параллельно расширил `EVENT_MAP` (5 новых event_type для 7.13) и добавил `listen_broker_status()` — конфликтов в `service.py` нет, изменения дополняют друг друга.
- **Результат:** W1 BACK2 ✅. Контракты C7, C8 опубликованы первыми (как требуется в `execution_order.md` «Контрактные точки W1»). Готов к ARCH midsprint checkpoint после завершения BACK1/FRONT1.

## 2026-04-25 — W0 завершён, гейт W0 → W1 закрыт

- **Что:** оркестратор свёл отчёты ARCH/UX/QA, проверил гейт W0 → W1.
- **Гейт W0 → W1 (по `execution_order.md` §3 «Гейт W0 → W1»):**
  - ✅ ARCH `arch_design_s7.md` опубликован (618 строк, 10 секций, 6 design-точек).
  - ✅ UX 6 макетов в `ux/` опубликованы без TBD.
  - ✅ QA `e2e_test_plan_s7.md` заполнен (47 сценариев на 17 задач, без TBD).
  - 🟡 `preflight_checklist.md` — облегчённый прогон W0 (11 ✅ / 2 ⚠️ / 17 ⏸️ deferred to W1). Длительные пункты (полный pytest, baseline E2E 119/0/3, uvicorn/pnpm dev) корректно отложены на старт W1 — это первый шаг QA на W1.
- **Синхронизация контракта C9:** `GET /api/v1/account/balance/history?days=30` (BACK1 → FRONT2 для виджета «Баланс», 7.7) добавлен в `execution_order.md` (таблица контрактов + W2 BACK1 + контрактные точки). 7.7-be передан BACK1 в W2.
- **Файлы:** `Спринты/Sprint_7/execution_order.md` (C9, W2 BACK1, contract sync), `Спринты/Sprint_7/sprint_state.md` (W0 завершён, C9 добавлен в риски).
- **Открытые вопросы для заказчика перед W1:**
  - Ветка корневого Test для коммита W0-артефактов (сейчас работа на `main`; preflight ожидает `docs/sprint-7-plan` или согласованную).
  - Ветка Develop/ для DEV-агентов W1 (сейчас `s6r/code-fixes`).
- **Результат:** W0 ✅. Готовы к старту W1 — параллельный запуск BACK1 + BACK2 + FRONT1 (6 debt-переносов). Ожидание команды заказчика.

## 2026-04-25 — DEV-1 W1 (BACK1): 7.13 event_type + 7.15-be WS sessions + 7.17-be фоновый бэктест

- **Задача 7.13 (debt из S6, MR.5):** к runtime подключены 5 новых event_type через `EVENT_MAP` + publish-сайты в production-коде.
  - **EVENT_MAP** (`app/notification/service.py`): добавлены `trade.opened`, `order.partial_fill`, `order.error`, `connection.lost`, `connection.restored` с `severity` и шаблонами (полный набор плейсхолдеров покрыт unit-тестом контракта payload ↔ template, защита от регрессии gotcha-19).
  - **engine.py:** в `OrderManager.process_signal` критическая секция (insert LiveTrade + commit) обёрнута в try/except → `order.error`. После paper-fill публикуется `trade.opened`. В `PositionTracker.on_order_filled`: при `filled_lots < volume_lots` → `order.partial_fill` (вместо `trade.filled`); иначе — `trade.filled` + `trade.opened` (real-mode параллельный publish).
  - **multiplexer.py:** в `_run_stream` reconnect-loop вызывается `_publish_connection_event` на канал `broker:status`. Анти-спам флаг `_connection_event_published` — событие `connection.lost` публикуется один раз при первом disconnect, сбрасывается после первого успешного response (тогда же публикуется `connection.restored`). Это аналог gotcha-18 (CB-уведомления спамили на каждой свече).
  - **NotificationService.listen_broker_status / stop_broker_listener:** глобальный listener на канал `broker:status`, фан-аут на всех известных user_id из активных сессий (`_session_user_map`). Подключён в `lifespan` `app/main.py`.
- **Задача 7.15-be (контракт C1, поставщик):** новый файл `app/trading/ws_sessions.py`.
  - `@router.websocket("/ws/trading-sessions/{user_id}")` — auth через первое сообщение `{action:"auth", token:"<jwt>"}` (паттерн ТЗ §4.12, gotcha-16: токен НЕ в URL). После auth_ok сервер шлёт `snapshot` (все active/paused/suspended сессии пользователя через JOIN strategy.user_id) и подписывается на `trades:{sid}` для каждой + `system:{user_id}` для динамического подхвата новых сессий.
  - Маппинг внутренних событий (`order.placed`, `trade.opened`, `trade.filled`, `trade.closed`, `positions.closed_all`, `session.started/stopped/paused/resumed/added`, `pnl.update`) → клиентские (`position_update`, `trade_filled`, `session_state`, `pnl_update`).
  - Custom close codes: 4401 (auth fail), 4403 (user_id mismatch), 4408 (auth timeout). Cleanup всех subscriptions через `try/finally`.
- **Задача 7.17-be (контракт C2, поставщик):** очередь фоновых бэктестов + WS канал.
  - **Таблица `backtest_jobs`** (`app/backtest/models.py:BacktestJob` + alembic миграция `a7b2c83d4e51_add_backtest_jobs.py`): id (uuid hex) PK, user_id/strategy_id/strategy_version_id (FK), job_type/status/progress/params_json/result_json/error_message/timestamps. Индекс `idx_bj_user_active(user_id, status)`. `alembic upgrade head` + `alembic downgrade -1` отработали корректно. Default'ы — литералы (`'queued'`, `0`, `CURRENT_TIMESTAMP`) во избежание gotcha-12.
  - **`BacktestJobManager`** (`app/backtest/jobs.py`): singleton в `app.state.backtest_job_manager`. API: `submit/get/list_user/cancel/shutdown`. Per-user cap = 3 (`DEFAULT_PER_USER_CAP`, см. arch §5.2 Q1) — `_enforce_cap` считает `queued+running` под `asyncio.Lock`. Runner-callable получает `BacktestJobContext` с `publish_progress`. Cancel — `task.cancel()` + `asyncio.shield` для гарантии записи `cancelled` в БД до повторного cancel. Shutdown — отменяет все активные tasks (lifespan).
  - **WS endpoint `/ws/backtest/{job_id}`** (`app/backtest/ws_backtest.py`): auth-first паттерн, ownership-check `job.user_id == decoded_user_id`, snapshot текущего состояния + delta из канала `backtest_job:{job_id}` (events queued/started/progress/done/error/cancelled). Grace period 30 сек после терминального события до close=1000 (см. arch §5.2 Q4).
  - **REST endpoints** (`app/backtest/router.py`): `POST /api/v1/backtest/run-async` (постановка job, переиспользует существующий `_run_backtest_task` через runner-обёртку, возвращает `{job_id, backtest_id, status:"queued"}`), `GET /api/v1/backtest/jobs?status=…` (список jobs пользователя для бейджа в шапке), `GET /api/v1/backtest/jobs/{id}`, `POST /api/v1/backtest/jobs/{id}/cancel`. `JobLimitExceeded` маппится в `ValidationError` (HTTP 400).
- **Файлы (новые):**
  - `app/trading/ws_sessions.py`, `app/backtest/jobs.py`, `app/backtest/ws_backtest.py`
  - `alembic/versions/a7b2c83d4e51_add_backtest_jobs.py`
  - `tests/test_notification/test_runtime_events.py` (16 тестов: payload contract + listener + multiplexer)
  - `tests/test_trading/test_ws_sessions.py` (3 теста: auth/snapshot/delta)
  - `tests/unit/test_backtest/test_jobs.py` (7 тестов: submit/cap/cancel/list/shutdown)
  - `tests/unit/test_backtest/test_ws_backtest.py` (3 теста: auth/ownership/snapshot+progress)
- **Файлы (изменённые):**
  - `app/notification/service.py` (5 новых EVENT_MAP записей, `listen_broker_status`, `_session_user_map`)
  - `app/broker/tinvest/multiplexer.py` (publish connection events + анти-спам флаг)
  - `app/trading/engine.py` (publish trade.opened/order.partial_fill/order.error + helper `_publish_order_error`)
  - `app/backtest/models.py` (модель `BacktestJob`)
  - `app/backtest/router.py` (4 новых endpoint в стиле существующих)
  - `app/main.py` (registration trading_sessions_ws_router + backtest_job_ws_router; lifespan: BacktestJobManager + listen_broker_status; shutdown reverse-order)
- **Тесты:** `pytest tests/ -q` → **770 passed, 1 failed** (failed = pre-existing `test_process_buy_signal`, не связан с моими изменениями: тест ожидает `status=='pending'` после paper-fill, но код мгновенно ставит `filled` ещё с baseline). Baseline до моих изменений: 729 passed → теперь 770 passed (+41 нового теста, все зелёные). Ruff: 0 issues по всем затронутым файлам.
- **Integration verification (`grep -rn`):**
  - 5 publish-сайтов 7.13: 4 в `app/trading/engine.py` (846/885/1171/1201) + 2 в `app/broker/tinvest/multiplexer.py` (221/244). EVENT_MAP — `app/notification/service.py:76-104`.
  - WS sessions: `app/trading/ws_sessions.py:117 @router.websocket("/ws/trading-sessions/{user_id}")` + `app.include_router` в `main.py:188`.
  - WS backtest: `app/backtest/ws_backtest.py:49 @router.websocket("/ws/backtest/{job_id}")` + `app.include_router` в `main.py:190`.
  - `BacktestJobManager(AsyncSessionLocal)` в `app/main.py:85` (production-инстанциация, не только в тестах).
- **Контракты:**
  - C1 (BACK1 → FRONT1, поставщик): WS `/ws/trading-sessions/{user_id}` опубликован раньше FRONT1-клиента — FRONT1 (DEV-3) уже написал клиент по arch_design_s7.md §4.3 параллельно. Совместимость подтверждена: те же event-имена (`position_update`, `trade_filled`, `pnl_update`, `session_state`).
  - C2 (BACK1 → FRONT1, поставщик): WS `/ws/backtest/{job_id}` опубликован. FRONT1 уже использует endpoint в `useBacktestJobWS`. Совместимы события: `queued/started/progress/done/error/cancelled` + поля `progress, result, message`.
  - C7 (BACK2 → BACK1, потребитель): на момент работы BACK2 (DEV-2) уже опубликовал `app.state.notification_service` через DI helper и `PriceAlertMonitor` singleton. BACK1 потребляет: `notification_service.listen_broker_status()` — зарегистрировано в lifespan; `getattr(request.app.state, "notification_service", None)` в backtest_router. **Контракт соблюдён.**
- **Stack Gotchas применены:**
  - **#04 (T-Invest streaming):** publish_connection_event защищён `try/except` — не ломает reconnect-loop. Backoff не изменён.
  - **#08 (AsyncSession.get_bind в pytest):** в тестах `BacktestJobManager` использован отдельный `create_async_engine` + `StaticPool` per-фикстура. `jobs_manager` фикстура с явным shutdown гарантирует, что фоновые tasks не пишут в disposed engine.
  - **#11 (alembic drift):** новая миграция содержит **только** create_table backtest_jobs + create_index, без drift. Проверено визуально.
  - **#12 (sqlite batch_alter):** в миграции — только `create_table`, default'ы `sa.text("'queued'")` / `sa.text("CURRENT_TIMESTAMP")` (литералы), не `func.now()`.
  - **#16 (relogin race):** WS-эндпоинты используют first-message auth (не URL query), как требует ТЗ §4.12 — снимает риск утечки JWT в логи.
  - **gotcha-18-like:** анти-спам флаг для connection.lost (один publish на disconnect-цикл).
- **Новых Stack Gotchas не создавал** — все встретившиеся ловушки покрыты существующими записями.
- **Плагины:** pyright fallback `python -m py_compile` после каждого Edit/Write — 0 ошибок. ruff — 0 issues. context7 не вызывался (FastAPI WebSocket, SQLAlchemy async, alembic — стабильные API из прошлых спринтов). superpowers TDD — итеративные red→green циклы для `BacktestJobManager.cancel()` (нашёл race с asyncio cleanup, добавил `asyncio.shield`).
- **Открытые вопросы:** нет блокеров. Pre-existing fail `test_process_buy_signal` — задача BACK2 в S7 Review (не моя зона).
- **Результат:** W1 BACK1 ✅. Готов к midsprint ARCH-приёмке + интеграции с FRONT1 (контракты C1/C2).

## 2026-04-25 — DEV-3 W1 (FRONT1): 7.16 аналитика + 7.15-fe WS + 7.17-fe бейдж

- **Что (7.16):** реализована вкладка «Обзор» BacktestResultsPage с двумя новыми компонентами — `PnLDistributionHistogram` (бакеты 0.5%, цвета red/yellow/green, пунктирные средние ср.убыток/ср.прибыль) и `WinLossDonutChart` (SVG-donut Win/Loss/BE с центром = total trades). Добавлены интерактивные зоны на ценовом графике (`InstrumentChart`): hover → подсветка зоны (alpha 0.18→0.40) + белый контур; click → раскрывается `TradeDetailsPanel` под графиком (поля entry/exit time/price/reason, P&L, длительность; Esc/× закрывают).
- **Что (7.15-fe):** новый хук `useTradingSessionsWS` (контракт C1) — WS клиент `/ws/trading-sessions/{user_id}` с auth через первое сообщение (gotcha-16: токен НЕ в URL), snapshot+delta события (position_update/trade_filled/pnl_update/session_state), exponential backoff reconnect 1→30s, ping/pong. Удалён `setInterval(fetchSessions, 10000)` в `TradingPage.tsx` — один источник правды (правило C1 execution_order.md §4). На странице добавлен Badge «Online/Переподключение/Auth error» — индикатор состояния WS.
- **Что (7.17-fe):** добавлены `backgroundBacktestsStore` (Zustand + persist в localStorage; cap 3 = `MAX_CONCURRENT_BACKGROUND_BACKTESTS`), хуки `useBacktestJobWS` + `useBackgroundBacktestsBootstrap` (мульти-WS на active jobs), компонент `BackgroundBacktestsBadge` в шапке (Indicator + Popover со списком jobs, прогресс-бары, кнопки «Открыть результат» / cancel / clear). В `BacktestLaunchModal` добавлена кнопка «Запустить в фоне» (модалка остаётся открытой, toast «Бэктест запущен в фоне»; pre-flight check на cap 3). Endpoint fallback: `/backtest/run-async` → `/backtest` если не готов на backend. `authStore.logout()` очищает background-backtests store + localStorage.
- **Файлы (новые):**
  - `src/components/backtest/PnLDistributionHistogram.tsx`
  - `src/components/backtest/WinLossDonutChart.tsx`
  - `src/components/backtest/TradeDetailsPanel.tsx`
  - `src/hooks/useTradingSessionsWS.ts`
  - `src/hooks/useBacktestJobWS.ts`
  - `src/stores/backgroundBacktestsStore.ts`
  - `src/components/notifications/BackgroundBacktestsBadge.tsx`
  - Тесты: `__tests__/PnLDistributionHistogram.test.tsx`, `__tests__/WinLossDonutChart.test.tsx`, `__tests__/TradeDetailsPanel.test.tsx`, `hooks/__tests__/useTradingSessionsWS.test.ts`, `stores/__tests__/backgroundBacktestsStore.test.ts`, `components/notifications/__tests__/BackgroundBacktestsBadge.test.tsx`.
- **Файлы (изменённые):**
  - `src/pages/BacktestResultsPage.tsx` — вкладка «Обзор» расширена, вкладка «График» получает onZoneClick + панель деталей.
  - `src/components/backtest/InstrumentChart.tsx` — onZoneClick prop, mouseMove/click handlers, hover-подсветка.
  - `src/pages/TradingPage.tsx` — polling удалён, useTradingSessionsWS подключён + статус-Badge.
  - `src/components/backtest/BacktestLaunchModal.tsx` — кнопка «Запустить в фоне», `handleSubmitBackground` + toast.
  - `src/api/backtestApi.ts` — `launchBackground`, `listJobs`, `cancelJob`, типы `BacktestJob`.
  - `src/components/layout/Header.tsx` — `<BackgroundBacktestsBadge />` справа от NotificationBell.
  - `src/stores/authStore.ts` — clear background-backtests при logout (gotcha-16 cleanup chain).
- **Контракты (потребитель):**
  - C1 от BACK1: WS `/ws/trading-sessions/{user_id}` — клиент написан по схеме arch_design_s7.md §4.3 (auth-сообщение, snapshot, delta-events). На mock-WS интегрирован в unit-тестах. Ожидаем backend от DEV-1.
  - C2 от BACK1: WS `/ws/backtest/{job_id}` — клиент написан по схеме §5.4 (queued/started/progress/done/error/cancelled). Endpoint REST fallback /backtest для S6-совместимости.
- **Тесты:** 287 passed / 0 failed (vitest, 58 test files). Новых: 6 файлов, ~30 unit-тестов. `npx tsc --noEmit` → 0 errors.
- **Lint:** наши файлы чистые. Остаются 6 ошибок в pre-existing файлах (CandlestickChart, SessionDashboard, ChartPage, ProfileSettingsPage, priceAlertStore) — не блокируют W1.
- **Stack Gotchas применены:** #16 (token НЕ в URL — auth первым WS-сообщением), Mantine modal lifecycle (BacktestLaunchModal не закрывается на «в фоне»), lightweight-charts cleanup (rAF + event listeners в return useEffect).
- **Результат:** W1 FRONT1 закрыт. Готов к midsprint UX-приёмке + интеграции с C1/C2 от BACK1 после публикации backend WS-эндпоинтов.

## 2026-04-25 — Фикс pre-existing pytest fail (test_process_buy_signal)

- **Что:** обновлён `test_process_buy_signal` (`Develop/backend/tests/test_trading/test_order_manager.py`). Старое ожидание `trade.status == "pending"` было некорректно для фикстуры `test_session.mode == "paper"`: paper-mode мгновенно филит ордер по signal price (см. `OrderManager.process_signal` ветка `if session.mode == "paper"`), эта логика существует с S5/S5R, не от 7.13. Тест был сломан в baseline `s6r/code-fixes` ещё до старта S7.
- **Изменение:** `assert trade.status == "filled"` + добавлен инвариант `trade.filled_lots == trade.volume_lots`. Дописан docstring с пояснением paper-инварианта.
- **Файлы:** `Develop/backend/tests/test_trading/test_order_manager.py` (1 файл, 1 тест).
- **Тесты:** `pytest tests/test_trading/test_order_manager.py -v` → **8/8 passed**. Полный suite `pytest tests/ -q` → **771 passed, 0 failed** в 78.82s. До фикса: 770 passed / 1 failed.
- **Расследование:** diff `s6r/code-fixes..s7/sprint-7` по `app/trading/engine.py` показал, что BACK1 (7.13) добавил вокруг создания трейда try/except и публикацию `trade.opened`, но логику filling не менял — регрессии нет.
- **Открытый вопрос:** покрытие real-mode сценария (`status="pending"` сразу после выставления) сейчас отсутствует — тикет на 7.R: добавить отдельный тест с фикстурой real-mode либо `@pytest.mark.parametrize`.
- **Результат:** baseline backend pytest зелёный, готовы к midsprint checkpoint.

## 2026-04-25 — Midsprint Checkpoint = PASS

- **Что:** оркестратор + ARCH-агент свели гейт midsprint → W2.
- **Контракты W1 (greps):** C1 (`/ws/trading-sessions` поставщик `app/trading/ws_sessions.py:117` ↔ потребитель `useTradingSessionsWS.ts:136` в `TradingPage.tsx`), C2 (`/ws/backtest/{job_id}` поставщик `ws_backtest.py:49` ↔ потребитель `useBacktestJobWS.ts` в `BackgroundBacktestsBadge`), C7 (`grep "NotificationService()" app/` без `main.py` = **0**), C8 (`open_session:`/`open_chart:` handler в `telegram_webhook.py:460,463`). Все стыки опубликованы и потреблены.
- **MR.5 (5 event_type → runtime):** `trade.opened`, `order.partial_fill`, `order.error`, `connection.lost`, `connection.restored` — все 5 в EVENT_MAP `app/notification/service.py`. Publish-сайты: `app/trading/engine.py:846/885/1171/1201`, `app/broker/tinvest/multiplexer.py:221/244`. Проверка ТЗ §1300 / project_state.md MR.5 — выполнена.
- **Тесты (полная регрессия):**
  - Backend: `pytest tests/ -q` → **771 passed / 0 failed** (78.82s).
  - Frontend: `pnpm test` → **287 passed / 0 failed**, `npx tsc --noEmit` → 0 errors.
  - E2E Playwright: `npx playwright test` → **119 passed / 0 failed / 3 skipped** (4.4 мин, соответствует S6 baseline).
- **Frontend lint:** 6 ошибок в pre-existing файлах (`CandlestickChart.tsx`, `SessionDashboard.tsx`, `ChartPage.tsx`, `ProfileSettingsPage.tsx`, `priceAlertStore.ts`) — не связаны с W1, перенесены в скоуп 7.R.
- **Stack Gotchas:** новых не создано. ARCH обоснование: кандидаты (data-testid space-separated, localStorage quota, bucket-edge inclusivity, WS reconnect storm, 403/404 ownership leak) — единичные или относятся к W2-функционалу. Возврат на 7.R после W2.
- **Файлы:** `Спринты/Sprint_7/midsprint_check.md` (новый), `Спринты/Sprint_7/reports/ARCH_midsprint_review.md` (новый), `Спринты/Sprint_7/sprint_state.md` (обновлён — midsprint PASS), `Спринты/Sprint_7/changelog.md` (эта запись).
- **Технические артефакты для разработки:** `restart_dev.sh` в корне проекта (перезапускает backend uvicorn + frontend vite + alembic upgrade head; логи в `/tmp/moex-dev-logs/`).
- **Готовность гейта midsprint → W2:** ✅ можно стартовать W2. Открытые вопросы (7.R / 7.10) не блокирующие. Ожидание команды заказчика.
