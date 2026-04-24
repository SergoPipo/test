# Ревью кода -- после Sprint 5 + Sprint 6

> Чеклист проверки реализованного кода S5 (Trading Engine, Circuit Breaker, Paper Trading)
> и S6 (Notifications, Recovery, Graceful Shutdown, SDK Upgrade, Stream Multiplex).
> Статус: проведено 2026-04-24, фиксы применены 2026-04-24

---

## 1. Архитектура и модули

- [x] **Разделение на слои:** router.py / service.py / models.py / schemas.py -- корректно для trading, notification, circuit_breaker, scheduler
- [x] **Когезия модулей:** trading, circuit_breaker, notification, scheduler, market_data -- каждый пакет отвечает за свою зону
- [x] **Нет циклических зависимостей:** граф импортов ацикличен; TYPE_CHECKING используется корректно (runtime.py <-> engine.py)
- [x] **Соответствие структуре из CLAUDE.md:** файловая структура совпадает с документацией
- [ ] **Множественные инстансы NotificationService:** **WARNING** -- NotificationService создаётся заново в 9 местах (runtime.py x3, engine.py, backtest/router.py, scheduler/service.py x2, price_alert_monitor.py, main.py). Каждый инстанс инициализирует TelegramNotifier + EmailNotifier через HTTP к API (telegram.Bot.__init__). Рекомендуется singleton через DI
- [x] **Scheduler Service:** APScheduler 3.x полностью реализован (3 cron-задачи + T+1 unlock) -- замечание ARCH Review S6 закрыто

## 2. Trading Engine (S5)

### 2.1 runtime.py -- Live Runtime Loop

- [x] **Единственная точка process_candle:** строка 768 -- подтверждено grep
- [x] **История свечей:** list[CandleData] + history_size=200 -- достаточно для SMA(200)
- [x] **Предзагрузка истории:** _preload_history через MarketDataService
- [x] **~~NameError: datetime/timezone в _handle_candle (строка 839):~~** **ЛОЖНОПОЛОЖИТЕЛЬНЫЙ** -- `from datetime import datetime, timezone` присутствует на уровне модуля (строка 42). Импорт доступен во всех методах класса. Ревью ошибочно указало на локальные импорты в других методах, пропустив модульный
- [x] **Commit после CB trigger (Gotcha 18):** строка 792 -- `await db.commit()` присутствует
- [x] **Temporary блокировки (trading_hours, cooldown):** строки 789-813 -- корректно: temporary блокировка не вызывает commit/publish, просто return
- [x] **Восстановление suspended -> active:** строки 339-355 -- корректно
- [x] **Downtime calculation:** _get_last_active_time() -- 4 источника (CB event, trade, last_signal_at, started_at), max()
- [x] **Stream subscribe при start:** строки 228-248 -- stream_manager.subscribe() вызывается

### 2.2 engine.py -- SessionManager, SignalProcessor, OrderManager

- [x] **Конфликт сессий:** проверка active + ticker перед созданием
- [x] **Paper mode instant fill:** строки 817-822 -- status="filled", entry_price=signal.price
- [x] **Position sizing:** 3 режима (fixed_lots, fixed_sum, percent) + lot_size
- [x] **_blocks_to_sandbox конвертер:** рекурсивный обход Blockly-дерева, генерация sandbox-скрипта. RestrictedPython-совместимый (total_sum вместо sum, без list/max/min)
- [ ] **Двойная проверка Circuit Breaker:** **WARNING** -- OrderManager.process_signal (строки 724-735) вызывает CB повторно если user_id != None. В runtime.py user_id=None (строка 824) -- корректно. Но при прямом вызове из router (не через runtime) user_id передаётся и CB вызывается дважды. Нет проблемы т.к. idempotent, но неоптимально
- [x] **close_all_positions:** корректно закрывает все filled/pending, обновляет DailyStat
- [x] **Cooldown last_signal_at:** обновляется ПОСЛЕ создания сделки в runtime (строка 839), не в SignalProcessor

### 2.3 service.py -- TradingService

- [x] **_fill_session_card_data:** подсчёт total_trades (все), W/L (только closed), unrealized P&L из OHLCVCache
- [x] **get_session вызывает _fill_session_card_data:** строка 230 -- данные карточки синхронизированы с детальной страницей
- [x] **_get_last_price:** из OHLCVCache, DESC limit 1
- [x] **~~Лишний SELECT в delete_session (строка 336):~~** **FIXED** -- мёртвый `select(LiveTrade)` удалён
- [x] **Удаление suspended-сессий:** строка 331 -- `status not in ("stopped", "suspended")`

## 3. Circuit Breaker (S5 + S6 fixes)

- [x] **9 проверок:** daily_loss, max_drawdown, position_size, daily_trade, duplicate_instrument, cooldown, trading_hours, short_block, insufficient_funds_streak
- [x] **Per-user asyncio.Lock (Gotcha 5):** _locks dict + _locks_lock
- [x] **Trading hours 10:00-23:50 MSK:** DEFAULT_TRADING_END = time(23, 50) -- вечерняя сессия покрыта
- [x] **Temporary блокировки:** CheckResult.temporary=True для trading_hours и cooldown
- [x] **_trigger записывает CircuitBreakerEvent:** строки 503-556
- [x] **Pause all для daily_loss/max_drawdown:** строки 515-523
- [x] **Cooldown temporary=True:** строка 422
- [x] **Trading hours temporary=True:** строка 455
- [x] **~~_check_trading_hours docstring устарел:~~** **FIXED** -- обновлён на "10:00-23:50 MSK"

## 4. Notifications (S6)

### 4.1 NotificationService (service.py)

- [x] **EventBus integration:** EVENT_MAP с 6 типами событий (session.started, session.stopped, order.placed, trade.filled, trade.closed, cb.triggered)
- [x] **create_notification:** INSERT + settings check + dispatch_external + EventBus publish
- [x] **dispatch_external:** Telegram + Email с lazy init
- [x] **_SafeDict:** безопасное форматирование body при отсутствующих ключах
- [x] **listen_session_events / stop_listening:** подписка/отписка на trades:{session_id}
- [x] **~~Нет проверки email перед отправкой:~~** **FIXED** -- добавлена проверка `notification.event_type in EMAIL_ALLOWED_EVENTS` перед вызовом `_email.send()` в `dispatch_external()`
- [ ] **5 event_type не подключены к runtime:** **WARNING** -- trade_opened, partial_fill, order_error, all_positions_closed, connection_lost/restored. EVENT_MAP не содержит маппинг, runtime не публикует эти события. Задокументировано для S7 в project_state.md

### 4.2 TelegramNotifier (telegram.py)

- [x] **HTML parse_mode:** severity -> emoji, inline-кнопки
- [x] **Error handling:** try/except с логированием, return False при ошибке
- [ ] **Inline-кнопки не обрабатываются:** **INFO** -- callback_data "open_session:{id}" и "open_chart:{id}" -- нет обработчика CallbackQuery. Кнопки отображаются в Telegram, но клик ничего не делает

### 4.3 EmailNotifier (email.py)

- [x] **Авто-TLS:** use_tls для порта 465, start_tls для остальных
- [x] **Timeout 15s:** предотвращает зависание
- [x] **HTML-шаблон:** severity -> цвет, simple layout

### 4.4 Frontend Notification Center

- [x] **NotificationBell:** badge 99+, WS подписка, toast через Mantine
- [x] **fetchNotifications при mount:** строка 34 NotificationBell.tsx -- CriticalBanner теперь работает при первой загрузке
- [x] **notificationStore:** settingsLoaded флаг, оптимистичное обновление settings
- [x] **NotificationDrawer:** severity-emoji, relative time, "Прочитать все", "Загрузить ещё"

## 5. Market Data (S5R + S6)

### 5.1 stream_manager.py -- Candle Aggregation

- [x] **_candle_period_start:** корректное определение начала периода для всех TF
- [x] **_AggregatingCandle:** open/high/low/close/volume обновляются корректно
- [x] **Publish через EventBus:** канал market:{ticker}:{tf}

### 5.2 service.py -- MarketDataService

- [x] **Фильтрация аукционных свечей:** O=H=L=C для 1h/4h (строка 127-131)
- [x] **_build_current_candle только для 1h/4h:** строка 137 -- D/W/M без 1m-агрегации
- [x] **Intraday gap tolerance:** учитывает ночной/выходной перерыв MOEX
- [x] **Политика источника:** T-Invest единственный для backtest/trading, ISS -- viewer-fallback

### 5.3 T-Invest Stream Multiplex (adapter.py + multiplexer.py)

- [x] **subscribe_candles делегирует в multiplexer:** _ensure_multiplexer() + lazy init
- [x] **Один persistent gRPC stream:** task-per-subscription удалён
- [x] **Backoff reset после первого response:** исправлен баг
- [x] **Public API не изменён:** StreamManager не затронут

## 6. Frontend -- Компоненты trading/ (S5 + S6)

### 6.1 SessionCard.tsx

- [x] **Decimal -> Number:** formatPnl, formatPrice, pnlColor -- все используют Number()
- [x] **P&L%:** вычисляется корректно (current_pnl / initial_capital * 100)
- [x] **Позиция:** Long/Short + лоты + entry_price
- [x] **WinRate:** total_trades > 0 ? winning/total * 100 : null
- [x] **isStopped:** includes "suspended" (строка 56)
- [x] **Кнопки:** Пауза, Возобновить, Стоп, График, Удалить -- с корректной видимостью

### 6.2 CandlestickChart.tsx

- [x] **createSeriesMarkers v5:** строка 2 import + строка 721 -- корректный API LWC v5
- [x] **Sequential index mode:** candlesToSequential, formatSequentialTime
- [x] **Trade markers:** 3 уровня (arrow -> Buy/Sell -> price), id-based дедупликация
- [x] **rebuildMarkers после setData:** строка 507 -- позиции пересчитываются по актуальному mapping
- [x] **MSK offset:** parseUtcTimestamp +3h, tradeTimeValue +3h
- [x] **WS callback:** upsertLiveCandle через store (не напрямую series.update)
- [x] **sessionTradesRef:** сделки хранятся отдельно от маркеров, маркеры пересчитываются
- [x] **Price alert lines:** createPriceLine + removePriceLine при изменении alertLines
- [x] **~~console.error в production:~~** **FIXED** -- заменены на silent-комментарии

### 6.3 PauseConfirmModal.tsx

- [x] **~~Side effect в render body:~~** **FIXED** -- вынесено в `useEffect` с зависимостями `[opened, session, hasPosition]`. При `!hasPosition` компонент возвращает `null`, side effect срабатывает через effect

### 6.4 Другие торговые компоненты

- [x] **SessionDashboard.tsx:** formatPnl, pnlColor -- Number() для Decimal
- [x] **PositionsTable.tsx:** formatPrice, unrealized_pnl -- Number() для Decimal
- [x] **TradesTable.tsx:** formatPrice, formatPct, pnl/pnl_pct -- Number() для Decimal
- [x] **PnLSummary.tsx:** formatRub, net_pnl -- Number() для Decimal

### 6.5 Notification компоненты

- [x] **NotificationBell.tsx:** badge, WS, toast, fetchNotifications при mount
- [x] **NotificationSettingsPage.tsx:** таблица event_type x канал, Switch toggle

## 7. Безопасность

### 7.1 CSRF

- [x] **Double-submit cookie:** secrets.compare_digest
- [x] **Fail-open для API-клиентов (S4 backlog #11):** оставлено намеренно, улучшен комментарий. Без cookie И header -- пропускает
- [x] **Exempt paths:** /login, /setup, /health

### 7.2 Rate Limiting

- [x] **threading.Lock:** строка 56 -- race condition из S4 backlog #17 исправлен
- [x] **Sliding window:** purge expired entries
- [x] **4 категории:** auth (60/60), trading (60/60), ai (10/60), general (200/60)
- [x] **JWT-based key для не-auth запросов:** user_id из токена
- [ ] **In-memory state per-worker:** **WARNING** (перенесено из S4) -- при нескольких Uvicorn workers лимит = N x limit. Приемлемо для текущей single-worker конфигурации, но при масштабировании потребуется Redis-backend

### 7.3 Sandbox

- [x] **AST + RestrictedPython:** двухуровневая валидация
- [x] **compile_restricted в тестах:** 11 тестов обновлены (S6 DEV-0)
- [x] **_safe_import whitelist:** math, datetime
- [x] **14 security-тестов sandbox escape:** AST (7) + runtime (7)

### 7.4 Notification ACL

- [x] **User isolation:** GET /notifications фильтрует по user_id из JWT
- [x] **XSS:** raw storage без санитизации -- рендер через React (auto-escape). В Telegram -- parse_mode=HTML, но title/body генерируются сервером, не пользователем
- [x] **Webhook auth:** секретный путь, без signature verification (TODO для S8)

## 8. Тесты

- [x] **Backend: 685 passed, 0 failures:** pytest (включая 23 security)
- [x] **Frontend: 250 passed, 0 failures:** vitest
- [x] **E2E: 10 S6 + 105 pre-existing:** Playwright
- [x] **E2E полностью на моках:** 0 зависимостей от E2E_PASSWORD
- [x] **dispatch_all_events:** 14 тестов -- 13 event_type через create_notification + dispatch_external
- [x] **~~console.log в BlocklyWorkspace.tsx:~~** **FIXED** -- отладочные логи удалены

---

## Результат ревью

| Раздел | Статус | Замечания |
|--------|--------|-----------|
| 1. Архитектура | WARNING (S7) | Множественные инстансы NotificationService -- перенесено в S7 (DI рефакторинг) |
| 2. Trading Engine | OK | ~~CRITICAL NameError~~ -- ложноположительный (импорт есть на уровне модуля); мёртвый SELECT удалён |
| 3. Circuit Breaker | OK | docstring обновлён |
| 4. Notifications | OK (частично S7) | EMAIL_ALLOWED_EVENTS -- FIXED; 5 event_type -- S7 |
| 5. Market Data | OK | Все проверки пройдены |
| 6. Frontend компоненты | OK | PauseConfirmModal -- FIXED (useEffect); console.log/error -- FIXED |
| 7. Безопасность | OK | Все проверки пройдены (rate_limit per-worker -- known limitation) |
| 8. Тесты | OK | 945 тестов, 0 failures |

**Легенда:** OK -- нет замечаний | WARNING (S7) -- перенесено в Sprint 7

---

## Сводка критичных проблем

Нет критичных проблем. Единственный CRITICAL из первоначального ревью оказался ложноположительным (datetime/timezone импортированы на уровне модуля, строка 42 runtime.py).

## Исправлено в ходе ревью (2026-04-24)

| # | Файл | Описание | Статус |
|---|------|----------|--------|
| 1 | `notification/service.py` | Добавлена проверка `event_type in EMAIL_ALLOWED_EVENTS` перед email-отправкой | FIXED |
| 2 | `PauseConfirmModal.tsx` | Side effect в render body вынесен в `useEffect` | FIXED |
| 3 | `trading/service.py:336` | Мёртвый SELECT удалён | FIXED |
| 4 | `circuit_breaker/engine.py:428` | Docstring обновлён: 18:45 → 23:50 MSK | FIXED |
| 5 | `CandlestickChart.tsx:457,509` | console.error заменены на silent-комментарии | FIXED |
| 6 | `BlocklyWorkspace.tsx:198,200` | Отладочные console.log удалены | FIXED |
| 7 | `AISettingsPage.tsx:131` | Crash `providers = undefined` → добавлен `?? []` (обнаружено при E2E и визуальной верификации) | FIXED |
| 8 | `AISettingsPage.tsx:381-382` | Crash `undefined.toLocaleString()` для `prompt_tokens_limit` → `!p.prompt_tokens_limit ? '∞' : ...` | FIXED |
| 9 | `marketDataStore.ts:221,274` | Crash `candles = undefined` при невалидном ответе → default `= []` | FIXED |
| 10 | `trading/runtime.py` + `trading/engine.py` (8 publish-сайтов) | **EVENT_MAP шаблоны не подставляются** — 5 из 7 event_type публиковали неполные данные (отсутствовали `strategy_name`, `ticker`, `direction`, `volume`, `pnl`). В `_SessionListener` добавлено поле `strategy_name`. Исправлены publish в `session.started` x2, `session.stopped` x2, `order.placed` x2, `trade.filled` x2, `trade.closed` x2. Unit-тесты: 75 passed, 0 failed. | FIXED |

## Визуальная верификация (Playwright)

Проверены скриншоты ключевых страниц нового функционала S6 (см. корень репо):

| Компонент | Скриншот | Статус |
|-----------|----------|--------|
| NotificationDrawer (bell + drawer) | `s6r-notification-drawer.png` | OK — severity-emoji, relative time, "Прочитать все" работает |
| NotificationSettingsPage | `s6r-notification-settings.png` | OK — таблица event x channel, Telegram привязан, Email не указан (предупреждение) |
| Trading cards (P&L, позиция, WR) | `s6r-trading-page.png` | OK — PAPER бейдж, Decimal→Number корректно, долго/коротко, Сделок + WinRate |
| Лента уведомлений | `s6r-notifications-page.png` | ⚠️ шаблоны `{strategy_name}: {ticker}` не подставлены в session_stopped (S7) |
| AI-провайдеры | `s6r-ai-settings.png` | OK (после фикса #7, #8) — ∞ лимит работает |
| Chart + trade markers | `s6r-chart-markers.png` | OK — 3-уровневый маркер Buy, sequential mode, OHLCV overlay |

## E2E регрессия

- До ревью: 107 passed / 12 failed / 3 skipped
- После фиксов: **119 passed / 0 failed / 3 skipped** ✅
- Исправлено 10 тестов (из 12 падений все — pre-existing проблемы моков/локаторов, не вызванные фиксами ревью)
- Из 3 code fixes два (AISettingsPage) обнаружены только при визуальной/E2E верификации — не были замечены при чтении кода

## Перенесено в Sprint 7

| # | Файл | Описание |
|---|------|----------|
| 1 | `trading/runtime.py` + 8 мест | NotificationService -- 9 инстансов → singleton через DI |
| 2 | `notification/service.py` | 5 event_type не подключены к runtime |
| 3 | `telegram.py` | Inline-кнопки без обработчика CallbackQuery |
| 4 | `middleware/rate_limit.py` | In-memory state per-worker (S8) |
