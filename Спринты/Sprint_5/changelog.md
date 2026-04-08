# Sprint 5: Changelog

> Лог всех изменений Sprint 5

---

## 2026-04-08 — Замечания по ручному тестированию

**Замечание 1: Скроллинг на странице торговли**
- `components/layout/AppShell.tsx`: `overflow: 'hidden'` → `overflowY: 'auto'` в AppShell.Main
- Причина: контент за пределами viewport обрезался, список сессий не прокручивался

**Замечание 2: Несоответствие mode/status между списком и деталями сессии**
- `backend/app/trading/schemas.py`: добавлены поля `strategy_name` и `current_pnl` в `SessionResponse`
- `backend/app/trading/service.py`: добавлены методы `_get_strategy_name()` и `_get_session_pnl()`, заполняют новые поля в `get_sessions()` и `get_session()`
- `frontend/stores/tradingStore.ts`: `fetchSession` теперь извлекает `raw.session` из вложенного `SessionDetailResponse`
- Причина: API деталей возвращал `{ session: {...} }`, а store записывал весь объект как `activeSession` — поля mode/status были undefined

**Замечание 3: Кнопка «Назад» на странице деталей сессии**
- `components/trading/SessionDashboard.tsx`: добавлен `IconArrowLeft` с навигацией на `/trading`
- Добавлены импорты `useNavigate`, `IconArrowLeft`

**Замечание 4: Тестовые сессии**
- Проверено: 23 сессии в БД, все от E2E тестов (TEST*, LNC* — мусорные тикеры; SBER/GAZP/LKOH — тестовые без реальных данных)
- Стратегия «Тестовая» (id=1) — пустой код, все сессии привязаны к ней
- Решение: не баг, следствие E2E тестирования. Очистка по запросу

**Замечание 6: Красные чёрточки P&L и кнопка удаления**
- `components/trading/SessionCard.tsx`: P&L=0 и null теперь отображаются серым (dimmed), а не красным
- `components/trading/SessionDashboard.tsx`: аналогичный фикс цвета P&L
- `components/trading/SessionCard.tsx`: добавлена кнопка удаления (IconTrash), активна только для остановленных сессий
- `backend/app/trading/router.py`: новый endpoint `DELETE /sessions/{id}` (204, только stopped)
- `backend/app/trading/service.py`: метод `delete_session()` — удаляет сессию + связанные LiveTrade, DailyStat, PaperPortfolio
- `frontend/api/tradingApi.ts`: добавлен `deleteSession(id)`
- `frontend/stores/tradingStore.ts`: добавлен `deleteSession(id)` — удаляет из списка и сбрасывает activeSession

**Замечание 9: Маркеры сделок на графике**
- `pages/ChartPage.tsx`: подключён `useTradingStore`, находит активную/paused сессию для текущего тикера
- Передаёт `sessionId={activeSessionId}` в `CandlestickChart`
- Компонент уже поддерживает маркеры (▲ Buy / ▼ Sell) через WebSocket `trades:{sessionId}`
- Ранее не работало из-за отсутствия передачи sessionId

**Замечание 8+: Стриминг свечей в реальном времени (РЕАЛИЗОВАНО)**
- `backend/app/market_data/stream_manager.py`: новый `MarketDataStreamManager` — подписка на T-Invest gRPC стрим, публикация через Event Bus → WebSocket
- `backend/app/market_data/router.py`: новый endpoint `POST /candles/subscribe` — возвращает WebSocket channel для подписки
- `frontend/api/marketDataApi.ts`: добавлен `subscribeCandleStream(ticker, timeframe)`
- `frontend/pages/ChartPage.tsx`: при загрузке графика подписывается на стрим, передаёт `wsChannel` в CandlestickChart
- CandlestickChart уже поддерживал wsChannel и обновление свечей через `candle.update` — теперь подключён

**Замечание 19: Убрано поле «Макс. одновременных позиций» из модалки запуска сессии**
- `components/trading/LaunchSessionModal.tsx`: удалён `NumberInput` для `maxPositions`
- Причина: Blockly-стратегии не поддерживают множественные позиции (обсуждено ранее)
- Значение по умолчанию изменено с 3 на 1, передаётся в API скрыто

**Замечание 18: Номер сессии на странице деталей**
- `components/trading/SessionDashboard.tsx`: добавлен `#{session.id}` между тикером и названием стратегии
- Также `strategy_name` показывает «(удалённая стратегия)» если пусто

**Замечание 17: Выравнивание карточек сессий в списке + стратегия всегда видна**
- `components/trading/SessionCard.tsx`: карточки теперь фиксированной минимальной высоты (180px)
  - `Stack justify="space-between"` — кнопки всегда внизу карточки
  - `strategy_name` отображается всегда: если стратегия удалена → «(удалённая стратегия)»
  - `lineClamp={1}` — длинные названия обрезаются
- `components/trading/SessionDashboard.tsx`: откачены изменения (кнопки остались раздельные для active/stopped)
- `backend/app/trading/models.py`: добавлено поле `strategy_name` в модель TradingSession (VARCHAR 200)
- `backend/app/trading/service.py`: `_get_strategy_name()` возвращает «(удалённая стратегия)» если JOIN не нашёл запись
- БД: колонка добавлена, существующие 8 сессий заполнены через UPDATE

**E2E тест: Актуальность данных на всех таймфреймах**
- `frontend/e2e/s5-chart-timeframes.spec.ts`: 5 тестов (D, 4h, 1h, 15m, 5m)
- Каждый тест: переключает ТФ → запрашивает API → проверяет что последняя свеча не старше порога
- Пороги: D=24ч, 4h=4ч, 1h=1ч, 15m=30мин, 5m=12мин

**Замечание 16: Текущая формирующаяся свеча через агрегацию 1m**
- `backend/app/market_data/service.py`: новый метод `_build_current_candle()`
  - T-Invest GetCandles возвращает только завершённые свечи
  - Для текущей незакрытой свечи: запрашиваем 1m свечи за текущий период и агрегируем OHLCV
  - Работает для 5m, 15m, 1h, 4h, D, W
  - Результат добавляется/обновляется в конце массива свечей
- `components/charts/CandlestickChart.tsx`: `parseUtcTimestamp()` — таймштампы без Z парсятся как UTC

**Замечание 15: Номер сессии на карточке в списке**
- `components/trading/SessionCard.tsx`: добавлен `#{session.id}` рядом с тикером

**Замечание 14: Стриминг не работал (500 ошибка)**
- `backend/app/market_data/router.py`: добавлен `from sqlalchemy import select` — отсутствовал, вызывал NameError при подписке на стрим
- `backend/app/market_data/router.py`: выбор аккаунта `ORDER BY is_sandbox ASC` — production первым
- После исправления: `POST /candles/subscribe?ticker=SBER&timeframe=1h` → `{"channel": "market:SBER:1h", "source": "tinvest"}`

**Замечание 13: Баннер сессии в строку таймфреймов, свежие данные на всех ТФ, избранное**
- `pages/ChartPage.tsx`: баннер сессии перенесён в строку таймфреймов (справа, компактно)
- `backend/app/market_data/service.py`: tail_tolerance теперь точно соответствует таймфрейму:
  D=6ч, 4h=4ч, 1h=1ч, 5m/15m=duration×2 — данные всегда актуальны при смене ТФ
- `components/charts/FavoritesPanel.tsx`: убран вводящий в заблуждение процент (avg_pnl_pct=0)
- `components/charts/CandlestickChart.tsx`: `parseUtcTimestamp()` — таймштампы без Z интерпретируются как UTC

**Замечание 12: Кнопка графика внутри торговой сессии**
- `components/trading/SessionDashboard.tsx`: добавлена кнопка графика (IconChartLine) — видна всегда, переходит на `/chart/{ticker}`
- Кнопка «Назад» на графике использует `navigate(-1)` — вернёт обратно внутрь сессии

**Замечание 10: Кнопка «Назад» на странице графика**
- `pages/ChartPage.tsx`: добавлена кнопка ← (IconArrowLeft) с `navigate(-1)` — возвращает на предыдущую страницу (торговля, бэктесты и т.д.)

**Замечание 11: Агрегация минутных свечей для старших таймфреймов**
- `backend/app/market_data/stream_manager.py`: T-Invest gRPC поддерживает подписку только на 1m и 5m
- Для 15m, 1h, 4h, D, W, M — подписка на 1m с агрегацией через `_AggregatingCandle`
- Агрегатор: определяет начало периода (`_candle_period_start`), аккумулирует OHLCV минутных свечей в текущую формирующуюся свечу нужного ТФ

**Замечание 8++: Исправление timezone MOEX ISS**
- `backend/app/broker/moex_iss/parser.py`: MOEX ISS возвращает время в МСК → теперь явно конвертируется в UTC через `.astimezone(timezone.utc)`
- Ранее: `.replace(tzinfo=MOSCOW_TZ)` — привязывал таймзону, но не конвертировал, вызывая сдвиг при сравнении с UTC-данными T-Invest

**Замечание 8: График не показывает данные до текущего момента**
- `backend/app/market_data/service.py`: разделён tolerance на два уровня:
  - `mid_tolerance` — для промежуточных gap'ов (выходные/праздники): D=5 дней, W=14, M=45, интрадей=3 дня
  - `tail_tolerance` — для правого края (актуальность данных): D/W/M=2 дня, интрадей=2 часа
- Причина: единый tolerance=5 дней для D приводил к тому, что кеш с данными от 06.04 считался актуальным 08.04 и не дозапрашивал свежие свечи
- После исправления: tail_tolerance учитывает что T-Invest и MOEX поддерживают торги в выходные для ряда инструментов
  - M: 2 дня, W: 1 день, D: 18 часов, интрадей: duration×3 (мин. 30 мин)
  - Промежуточные gap'ы (mid_tolerance) оставлены с запасом на выходные/праздники

**Замечание 7: Удаление и перезапуск в деталях сессии**
- `components/trading/SessionDashboard.tsx`: для остановленных сессий показываются 2 кнопки:
  - «Запустить заново» (IconRestore) — создаёт новую сессию с теми же параметрами и переходит на неё
  - «Удалить» (IconTrash) — удаляет сессию и возвращает к списку
- `api/types.ts`: расширен `TradingSession` — добавлены `strategy_version_id`, `broker_account_id`, `position_sizing_mode`, `position_sizing_value`, `max_concurrent_positions`, `cooldown_seconds`

**Замечание 5: Autocomplete тикера в модалке запуска сессии + мин. 1 символ**
- `components/trading/LaunchSessionModal.tsx`: `TextInput` → `Autocomplete` с поиском через `marketDataApi.searchInstruments()`, debounce 300мс
- `components/backtest/BacktestLaunchModal.tsx`: `query.length < 2` → `< 1`
- `components/layout/Header.tsx`: `query.length < 2` → `< 1`
- Поиск инструментов теперь начинается с 1 символа во всех 3 компонентах

---

## 2026-04-07

### Фаза 0: Отложенные задачи S4 Review

**#15 — float→Decimal в block_parser.py** (Medium, M)
- `block_parser.py`: добавлен `from decimal import Decimal, InvalidOperation`
- Все финансовые параметры переведены на `Decimal`: zone bounds, indicator thresholds, stop_loss (percent/points), take_profit (percent/points), position_size (percent), generic params
- `code_generator.py`: добавлен `from decimal import Decimal`, обновлён `isinstance` check для поддержки `Decimal`

**#16 — code_generator.py параметры** (Medium, S) → закрыто в рамках #15
- `isinstance(right_ref, (int, float, Decimal))` — поддержка всех числовых типов

**#23 — фильтрация поиска по instrument_type** (Low, S)
- `market_data/router.py`: добавлен query-параметр `instrument_type: str | None`
- `frontend/api/marketDataApi.ts`: добавлен параметр `instrumentType?` в `searchInstruments()`

**#24 — иконки сортировки в таблице сделок** (Low, S)
- `BacktestTrades.tsx`: добавлен `color="var(--mantine-color-blue-4)"` для `IconArrowUp`/`IconArrowDown`

**#28 — DI для синглтонов chat_router.py** (Low, M)
- Добавлены DI-фабрики: `get_ai_service()`, `get_history_manager()`, `get_context_compressor()`
- Endpoint'ы `chat`, `chat/stream`, `explain`, `history`, `clear` переведены на `Depends()`
- Модульные синглтоны сохранены для обратной совместимости тестов
- Тест-mock: добавлен `get_last_usage` в `_mock_provider` — исправлены 2 ранее падавших теста

### Планирование
- Создан `execution_order.md` — порядок выполнения задач
- Создан `sprint_state.md` — начальное состояние
- Создан `changelog.md`
- Ветка: `s5/trading` от main (6cafadb)

### Prompt-файлы (7 штук)
- `prompt_UX.md` — дизайн Trading Panel, Account, Favorites, RT-графики
- `prompt_DEV-1.md` — Trading Engine, Paper Trading, Broker Adapter (6 методов + streaming), Rate Limiter
- `prompt_DEV-2.md` — Circuit Breaker (9 проверок, asyncio.Lock, интеграция с OrderManager)
- `prompt_DEV-3.md` — Bond Service (НКД), Corporate Actions, Tax Export (FIFO, 3-НДФЛ, xlsx/csv)
- `prompt_DEV-4.md` — Frontend Trading Panel, SessionCard, LaunchModal, WS real-time, маркеры сделок
- `prompt_DEV-5.md` — Frontend Account Screen, BalanceCards, TaxReportModal, FavoritesPanel ★
- `prompt_ARCH_review.md` — ревью всех модулей, E2E тесты (4 сценария), проверка latency
- `preflight_checklist.md` — предполётная проверка ПО и зависимостей (7 секций)

### Preflight: установка зависимостей
- Установлены `openpyxl 3.1.5` (xlsx-экспорт для налогового отчёта) и `APScheduler 3.11.2` (MOEX-календарь)

### DEV-1: Trading Engine + Broker Adapter (Волна 1)

**Задача 1 — Trading Engine (`app/trading/engine.py`)** — СОЗДАН
- `TradingSessionManager`: start_session (конфликт-проверка, PaperPortfolio), pause, resume, stop, restore_sessions
- `SignalProcessor`: process_candle → Signal (BUY/SELL/HOLD), кеширование стратегий, sandbox execution
- `OrderManager`: process_signal (cooldown, max positions, position sizing), close_position, close_all_positions, DailyStat
- `PositionTracker`: update_position, calculate_unrealized_pnl, on_order_filled (portfolio update, peak equity)
- Классы: `Signal`, `SignalAction` (enum), `SessionStartParams` (dataclass)
- EventBus-события: session.started/paused/resumed/stopped, order.placed, trade.filled/closed, positions.closed_all

**Задача 2 — Paper Trading Engine (`app/trading/paper_engine.py`)** — СОЗДАН
- `PaperBrokerAdapter(BaseBrokerAdapter)`: полная реализация интерфейса брокера для бумажной торговли
- Виртуальное исполнение с slippage (0.05%), проверка достаточности средств
- T+1 settlement: blocked_amount в PaperPortfolio
- Методы: place_order, get_positions, get_balance, subscribe_candles, get_operations

**Задача 3 — Broker Adapter** — МОДИФИЦИРОВАН
- `app/broker/base.py`: добавлены dataclasses (PositionInfo, OrderResponse, OrderStatus, InstrumentInfo)
- Добавлены абстрактные методы: subscribe_candles, unsubscribe, get_operations
- Обновлены return types стабов: get_positions→list[PositionInfo], place_order→OrderResponse и др.
- `app/broker/tinvest/adapter.py`: реализованы 6 stub-методов + 3 новых (subscribe_candles, unsubscribe, get_operations)
- subscribe_candles: gRPC streaming с auto-reconnect через asyncio.Task
- `app/broker/tinvest/mapper.py`: 4 новых метода маппинга (portfolio_position, order_response, order_state, instrument)
- `app/broker/__init__.py`: экспортированы новые dataclasses

**Задача 4 — Rate Limiter** — МОДИФИЦИРОВАН
- `app/broker/tinvest/rate_limiter.py`: добавлены get_state/restore_state в TokenBucketRateLimiter
- Новый класс `PersistentTokenBucketRateLimiter`: load/save JSON-файл (data/rate_limiter_state.json)
- Функции `save_all_limiters()`, `load_all_limiters()` для shutdown/startup

**Задача 5 — Trading Schemas (`app/trading/schemas.py`)** — ЗАПОЛНЕН
- Pydantic v2: SessionStartRequest (model_validator для real mode), SessionResponse, TradeResponse
- PositionResponse, DailyStatResponse, PaperPortfolioResponse, SessionDetailResponse
- DashboardResponse, PaginatedResponse, ClosePositionRequest, SessionFilterParams, TradeFilterParams

**Задача 6 — Trading Router (`app/trading/router.py`)** — ЗАПОЛНЕН
- POST/GET /sessions, GET /sessions/{id}, PATCH pause/resume/stop
- GET /sessions/{id}/positions, POST close position, POST close-all
- GET /sessions/{id}/trades (пагинация), GET /sessions/{id}/stats
- GET /positions (все), GET /dashboard

**Задача 7 — Trading Service (`app/trading/service.py`)** — ЗАПОЛНЕН
- `TradingService`: оркестрация Router ↔ Engine через DI (get_db → TradingService)
- CRUD сессий, позиций, сделок + stats + dashboard
- get_all_positions — кросс-сессионный запрос через JOIN

**Тесты — 55 тестов в tests/test_trading/**
- test_engine.py: 12 тестов (start, pause, resume, stop, restore, конфликты)
- test_order_manager.py: 8 тестов (signals, sizing, close, close_all)
- test_position_tracker.py: 5 тестов (update, P&L, on_order_filled, portfolio)
- test_paper_engine.py: 7 тестов (connect, balance, place_order, slippage, insufficient_funds)
- test_schemas.py: 10 тестов (валидация, defaults, real mode validation)
- test_service.py: 6 тестов (start, list, detail, lifecycle, dashboard)
- test_router.py: 4 теста (HTTP endpoints: dashboard, list, detail, 404)
- conftest.py: фикстуры (db_session, test_user, test_strategy_version, test_session, test_trade)
- Итого: 512 passed, 0 failed (включая 457 существующих)

### DEV-2: Circuit Breaker (Волна 2)

**Задача 1 — CircuitBreakerConfig модель (`app/circuit_breaker/models.py`)** — ДОБАВЛЕНА
- `CircuitBreakerConfig`: per-user + per-session override конфигурация
- Поля: daily_loss_limit_pct/fixed, max_drawdown_pct, max_position_size, daily_trade_limit, cooldown_seconds, trading_hours_start/end, block_shorts
- UniqueConstraint(user_id, session_id), Index(user_id)

**Задача 2 — CircuitBreakerEngine (`app/circuit_breaker/engine.py`)** — СОЗДАН
- 9 проверок: daily_loss_limit, max_drawdown, position_size_limit, daily_trade_limit, duplicate_instrument, cooldown, trading_hours, short_block, insufficient_funds_streak
- asyncio.Lock per user_id для race conditions
- `_trigger()`: запись CircuitBreakerEvent + пауза сессии(й) + EventBus publish (notifications + trades:{session_id})
- daily_loss и max_drawdown → пауза ВСЕХ сессий пользователя
- Торговый день с 10:00 MSK (UTC+3)
- Ленивый вызов проверок (lambda) для корректного управления корутинами

**Задача 3 — Schemas (`app/circuit_breaker/schemas.py`)** — СОЗДАН
- Pydantic v2: CircuitBreakerConfigRequest/Response, CircuitBreakerEventResponse, CheckStatusResponse

**Задача 4 — Router (`app/circuit_breaker/router.py`)** — СОЗДАН
- GET/PUT /config, PUT /config/session/{id}, GET /events, GET /events/session/{id}, GET /status
- НЕ зарегистрирован в main.py (по требованию задачи)

**Задача 5 — Service (`app/circuit_breaker/service.py`)** — ЗАПОЛНЕН
- CRUD конфигурации (upsert глобальная + session override)
- Получение событий (пагинация, фильтр по сессии)
- get_status: trades_today, daily_pnl, current_drawdown, лимиты

**Задача 6 — Интеграция с OrderManager** — ДОБАВЛЕНА
- `app/trading/engine.py`: OrderManager.process_signal() принимает опциональный user_id
- При наличии user_id — вызов CircuitBreakerEngine.check_before_order() перед ордером
- Обратная совместимость: без user_id CB не вызывается

**Alembic миграция** — СОЗДАНА
- `b5f6c7d8e9f0_add_circuit_breaker_configs.py`: CREATE TABLE circuit_breaker_configs

**Тесты — 36 тестов в tests/test_circuit_breaker/**
- test_engine.py: 18 тестов (каждая из 9 проверок: pass + block, trigger, daily_loss pauses all, race condition lock)
- test_config.py: 4 теста (create, update/upsert, session override, get_config None)
- test_router.py: 8 тестов (логика endpoints через service: config CRUD, events, status)
- test_integration.py: 4 теста (CB + OrderManager: short block, passes, skip CB without user_id, insufficient_funds)
- conftest.py: фикстуры (db_session, test_user, test_strategy/version, test_session, test_config)
- Итого: 548 passed, 0 failed (включая 512 существующих)

### Preflight: исправление 47 падающих тестов → 422 passed, 0 failed
- `block_parser.py:385` — `block_idx` не определён → добавлен `enumerate(blocks)`
- `test_round_trip.py` — 5 тестов: логические блоки OR/AND/NOT имеют type `"logic"`, не `"condition"`
- `test_ai/` (13 тестов) — модель `AIProviderConfig` изменилась: `daily_limit` → `prompt_tokens_limit` и др.
- `test_ai/test_providers.py` — `"gemini"` теперь поддерживается, заменён на `"unknown_provider"`
- `sandbox/executor.py` — `signal.alarm()` не работает вне main thread → добавлен fallback через threading
- `auth/service.py` — `max_attempts=50` в DEBUG-режиме ломал тесты → `getattr(settings, "LOGIN_MAX_ATTEMPTS", 5)`
- `test_backtest/test_api.py` — метрики во вложенном объекте `data["metrics"]["total_trades"]`
- `test_backtest/test_engine.py` — `callback in all_args` → `any(arg is callback for arg in all_args)` (pandas)

### DEV-4: Trading Panel + Real-time Charts (Волна 3)

**Задача 1 — TypeScript типы (`src/api/types.ts`)** — ДОБАВЛЕНЫ
- TradingSession, LiveTrade, Position, SessionStartRequest, TradingDashboard, SessionStats
- Все типы соответствуют Backend API из DEV-1

**Задача 2 — Trading API (`src/api/tradingApi.ts`)** — СОЗДАН
- startSession, getSessions, getSession, pauseSession, resumeSession, stopSession
- getPositions, closePosition, closeAllPositions, getTrades, getStats, getDashboard
- Типизированные ответы через generics Axios

**Задача 3 — Trading Store (`src/stores/tradingStore.ts`)** — СОЗДАН
- Zustand store: sessions, activeSession, positions, trades, stats, dashboard
- Все CRUD actions + WS update методы: updateSessionFromWS, addTradeFromWS, updatePositionFromWS
- Паттерн аналогичен backtestStore (loading, error, clearError)

**Задача 4 — WebSocket Hook (`src/hooks/useWebSocket.ts`)** — СОЗДАН
- Generic мультиплексированный singleton WebSocket
- subscribe/unsubscribe по каналам, auto-reconnect с exponential backoff (до 30с)
- Re-subscribe всех каналов при reconnect
- getWSConnectionState() для индикатора подключения

**Задача 5 — TradingPage (`src/pages/TradingPage.tsx`)** — СОЗДАН
- Маршрут `/trading`: заголовок «Торговля» + кнопка «Запустить сессию»
- SessionList + LaunchSessionModal
- Состояния: loading, error с Alert

**Задача 6 — Trading Components (`src/components/trading/`)** — СОЗДАНЫ
- `SessionCard.tsx`: Badge PAPER (yellow.6) / REAL (red.6), P&L с цветом, кнопки Пауза/Стоп/График
- `SessionList.tsx`: SegmentedControl фильтр (все/active/paused/stopped), Select сортировка (дата/P&L), пустое состояние
- `LaunchSessionModal.tsx`: Modal с SegmentedControl Paper/Real, Select стратегия, TextInput тикер, NumberInput капитал/sizing/cooldown, Alert для Real mode, confirm-диалог
- `SessionDashboard.tsx`: маршрут `/trading/sessions/:id`, header с тикер/стратегия/режим/статус/P&L, Tabs Позиции|Сделки|Статистика, WS подписка на trades:{session_id}
- `PositionsTable.tsx`: Table с тикер/направление(▲/▼)/цена/P&L/время, кнопка «Закрыть»
- `TradesTable.tsx`: Table с дата/направление/вход/выход/P&L/P&L%/комиссия/slippage, пагинация «Загрузить ещё»
- `PnLSummary.tsx`: MetricCard (P&L, Win Rate, сделки, Profit Factor) + Equity Curve (Lightweight Charts LineSeries)

**Задача 7 — Real-time графики (`CandlestickChart.tsx`)** — ОБНОВЛЁН
- WS streaming: подписка на канал `market:{ticker}:{tf}`, real-time update свечей через chart.update()
- Маркеры сделок: ▲ зелёный (long) / ▼ красный (short) при получении trade.filled
- Индикатор подключения: кружок в правом верхнем углу (зелёный = connected, красный = disconnected)
- Props: wsChannel, sessionId — опциональные для обратной совместимости

**Задача 8 — Навигация**
- `App.tsx`: Route `/trading` → TradingPage, Route `/trading/sessions/:id` → SessionDashboard
- `Sidebar.tsx`: пункт «Торговля» (IconTrendingUp) уже присутствовал

**Тесты — 36 тестов в 7 файлах**
- SessionCard.test.tsx: 7 тестов (PAPER/REAL badge, P&L цвета, кнопки pause/resume)
- LaunchSessionModal.test.tsx: 5 тестов (рендер, Paper/Real switch, Real warning)
- PositionsTable.test.tsx: 4 теста (пустое состояние, строки, close callback)
- TradesTable.test.tsx: 4 теста (пустое состояние, строки, load more)
- PnLSummary.test.tsx: 4 теста (null stats, metric cards, total trades, win rate)
- TradingPage.test.tsx: 4 теста (заголовок, кнопка, empty state, fetchSessions)
- tradingStore.test.ts: 8 тестов (initial, fetchSessions, fetchSession, startSession, WS updates, clearError, dashboard)
- Все 36 тестов DEV-4 проходят (0 failures)

### DEV-5: Account Screen + Favorites Panel (Волна 3)

**Задача 1 — TypeScript типы (`src/api/types.ts`)** — ДОБАВЛЕНЫ
- BrokerBalance, BrokerPosition, BrokerOperation (Account)
- TaxReport, TaxReportRequest (Tax)
- FavoriteInstrument (Favorites)
- Существующие типы DEV-4 (Trading) сохранены без изменений

**Задача 2 — Account API (`src/api/accountApi.ts`)** — СОЗДАН
- getBalances, getPositions(accountId), getOperations(accountId, params)

**Задача 3 — Tax API (`src/api/taxApi.ts`)** — СОЗДАН
- generateReport(data), getReports(), downloadReport(id) с responseType: 'blob'

**Задача 4 — Account Store (`src/stores/accountStore.ts`)** — СОЗДАН
- Zustand store: balances, positions, operations, operationsTotal, taxReports
- Actions: fetchBalances, fetchPositions, fetchOperations, fetchTaxReports, generateTaxReport, downloadTaxReport
- downloadTaxReport: создаёт Blob → скачивание через link.click()

**Задача 5 — AccountPage (`src/pages/AccountPage.tsx`)** — СОЗДАН
- Маршрут `/account`: заголовок «Счёт» + кнопка «Налоговый отчёт»
- 3 секции: BalanceCards, PositionsTable (Paper), OperationsTable (Paper)
- Интеграция с settingsStore для activeAccountId
- Состояния: loading, error, пагинация операций, фильтр по датам

**Задача 6 — Account Components (`src/components/account/`)** — СОЗДАНЫ
- `BalanceCards.tsx`: SimpleGrid cols={3}, Paper карточки (Всего/Доступно/Заблокировано), P&L-цвета
- `PositionsTable.tsx`: TanStack Table с сортировкой, Badge «Стратегия» (blue) / «Внешняя» (gray), пустое состояние
- `OperationsTable.tsx`: DatePickerInput type="range", пагинация Pagination, локализованные типы операций
- `TaxReportModal.tsx`: Modal с Select (год), Radio (xlsx/csv), Checkbox (акции/облигации/ETF), loading state

**Задача 7 — FavoritesPanel (`src/components/charts/FavoritesPanel.tsx`)** — СОЗДАН
- Панель 220px справа от графика с toggle по кнопке ★
- localStorage для хранения (key: 'user_favorites')
- Добавление через TextInput + Enter, удаление по hover → ✕
- Каждый элемент: тикер (bold), статистика «N бэкт · M стр», P&L с цветом
- Клик → onSelectTicker → navigate

**Задача 8 — Навигация**
- `App.tsx`: Route `/account` → AccountPage (добавлен рядом с существующими)
- `Sidebar.tsx`: пункт «Счёт» (IconWallet) уже присутствовал
- `ChartPage.tsx`: интеграция FavoritesPanel (Flex layout, ActionIcon ★ toggle)

**Тесты — 24 теста в 7 файлах**
- BalanceCards.test.tsx: 3 теста (рендер карточек, форматирование, пустой массив)
- PositionsTable.test.tsx: 3 теста (рендер, badges, пустое состояние)
- OperationsTable.test.tsx: 3 теста (рендер, типы операций, date picker)
- TaxReportModal.test.tsx: 2 теста (форма, submit с данными)
- FavoritesPanel.test.tsx: 4 теста (пустое состояние, добавление, клик, localStorage)
- AccountPage.test.tsx: 4 теста (рендер, балансы, кнопка отчёта, error state)
- accountStore.test.ts: 5 тестов (initial, fetchBalances, fetchPositions, fetchOperations, fetchTaxReports)
- Все 24 теста DEV-5 проходят, существующие тесты (ChartPage, Sidebar) не сломаны

### ARCH: Архитектурное ревью + E2E тесты (Волна 4)

**Исправление CRIT-1 — Двойной prefix в Trading Router**
- `app/trading/router.py`: убран `prefix="/api/v1/trading"` из APIRouter (дублировался с main.py)
- Routes в production были бы `/api/v1/trading/api/v1/trading/sessions` (недоступны)
- Тесты маскировали баг: fixture добавляла router отдельно

**Исправление CRIT-2 — JWT авторизация на Trading endpoints**
- `app/trading/router.py`: добавлен `current_user: User = Depends(get_current_user)` ко всем 12 endpoints
- `tests/test_trading/test_router.py`: обновлен fixture с override_get_current_user
- Итого: 548 passed, 0 failed

**E2E тесты (4 сценария, 19 тестов)**
- `e2e/s5-paper-trading.spec.ts` (3 теста): запуск Paper-сессии, детали, pause/resume
- `e2e/s5-circuit-breaker.spec.ts` (5 тестов): CB config, events API, status, update, UI
- `e2e/s5-account.spec.ts` (4 теста): balance cards, formatting, tax modal, download
- `e2e/s5-favorites.spec.ts` (7 тестов): add, remove, multiple, persist, click, duplicate

**Архитектурное ревью**
- `arch_review_s5.md`: статус PASS WITH NOTES
- 2 critical (исправлены), 5 medium (документированы), 4 low (документированы)
- Все модули проверены: Trading Engine, Circuit Breaker, Bond Service, Tax Export, Corporate Actions, Broker Adapter, Security, Frontend UI
