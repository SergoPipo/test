# Бэклог доработок -- после Sprint 5 + Sprint 6

> Задачи, выявленные при ревью кода S5+S6.
> Включает: замечания code_review.md, незакрытые задачи из Sprint_4_Review/backlog.md,
> технический долг и рекомендации для S7.

## Задачи

| # | Приоритет | Модуль | Описание | Статус |
|---|-----------|--------|----------|--------|
| 1 | CRITICAL | trading/runtime.py | **NameError: datetime/timezone в _handle_candle (строка 839).** `session.last_signal_at = datetime.now(timezone.utc)` -- `datetime` и `timezone` не импортированы ни на уровне модуля, ни внутри метода _handle_candle(). Результат: NameError при каждой сделке, last_signal_at не обновляется, cooldown не работает. **Фикс:** добавить `from datetime import datetime, timezone` в начало _handle_candle или на уровне модуля | open |
| 2 | WARNING | notification/service.py + email.py | **EMAIL_ALLOWED_EVENTS не проверяется.** Константа `EMAIL_ALLOWED_EVENTS` определена в email.py (frozenset из 5 типов), но `dispatch_external()` в service.py не фильтрует по ней. Email отправится для любого event_type если пользователь включил email_enabled. **Фикс:** добавить проверку `notification.event_type in EMAIL_ALLOWED_EVENTS` перед вызовом _email.send() | open |
| 3 | WARNING | trading/*.py, notification/*.py, backtest/router.py, scheduler/service.py, market_data/price_alert_monitor.py | **Множественные инстансы NotificationService (9 мест).** Каждый вызов создаёт новый экземпляр + инициализирует TelegramNotifier и EmailNotifier. Рекомендация: singleton через app.state или DI | open |
| 4 | WARNING | PauseConfirmModal.tsx:34-37 | **Side effect в render body.** Если нет открытых позиций, pauseSession() и onClose() вызываются прямо в теле render-функции (не в useEffect). В React StrictMode -- двойной вызов pauseSession(). **Фикс:** вынести в useEffect или обработать в родительском компоненте SessionCard | open |
| 5 | WARNING | trading/service.py:336 | **Мёртвый SELECT.** `await self.db.execute(select(LiveTrade).where(LiveTrade.session_id == session_id))` -- результат не используется, следующая строка делает sa_delete. Удалить | open |
| 6 | WARNING | notification/service.py (EVENT_MAP) | **5 event_type не подключены к runtime.** trade_opened, partial_fill, order_error, all_positions_closed, connection_lost/restored -- EVENT_MAP не содержит маппинг, runtime не публикует события. Запланировано для S7 (project_state.md) | open (S7) |
| 7 | WARNING | telegram.py | **Inline-кнопки не обрабатываются.** callback_data "open_session:{id}" и "open_chart:{id}" генерируются, но CallbackQueryHandler не реализован. Кнопки отображаются в Telegram, клик ничего не делает | open (S7) |
| 8 | INFO | circuit_breaker/engine.py:428 | **Docstring устарел.** Говорит "10:00-18:45 MSK", реальное значение DEFAULT_TRADING_END = time(23, 50) | open |
| 9 | INFO | CandlestickChart.tsx:457,509 | **console.error в production.** "Chart live update failed" и "Chart setData failed". Допустимо для отладки, но в production лучше structlog/Sentry | open |
| 10 | INFO | BlocklyWorkspace.tsx:198,200 | **console.log в production.** Отладочные логи загрузки блоков | open |
| 11 | INFO | middleware/rate_limit.py | **In-memory state per-worker (из S4 backlog #19).** При N Uvicorn workers лимит = N x limit. Приемлемо для single-worker, при масштабировании нужен Redis | open (S8) |
| 12 | INFO | StrategyEditPage.tsx | **935 строк, монолит (из S4 backlog #19).** Требует рефакторинга: разбить на подкомпоненты | open (S8) |

## Незакрытые задачи из Sprint_4_Review/backlog.md

| # из S4R | Описание | Статус в S6R |
|----------|----------|-------------|
| #19 | StrategyEditPage.tsx -- 935 строк, монолит | Перенесён (бэклог #12) |
| #22 | executor.py -- SIGALRM Unix-only (не актуально для macOS) | Не актуален |

Все остальные задачи S4R (26 из 28) закрыты в S5/S5R.

## Технический долг (обнаружен при ревью)

| # | Описание | Источник |
|---|----------|----------|
| TD-1 | pending_events -- таблица описана в ТЗ, не реализована в коде | ТЗ 3.20, ARCH S6 |
| TD-2 | Telegram webhook без signature verification (HMAC) | Security review |
| TD-3 | EmailNotifier: нет retry при transient SMTP errors | email.py |
| TD-4 | NotificationService._listen_loop: нет backpressure -- если создание notification медленное, очередь EventBus растёт бесконечно | notification/service.py |
| TD-5 | SessionRuntime._listeners не очищается при ошибке start() -- если start() упал после subscribe, listener зарегистрирован в EventBus, но не в _listeners | runtime.py |

## Рекомендации для Sprint 7

1. **Подключить оставшиеся 5 event_type** (бэклог #6) -- task из project_state.md
2. **Telegram CallbackQuery handler** (бэклог #7) -- inline-кнопки без обработчика
3. **NotificationService singleton** (бэклог #3) -- DI через app.state
4. **WS-обновление карточек сессий** (005_realtime_trading_session_updates.md) -- заменить polling 10s
5. **StrategyEditPage рефакторинг** (бэклог #12) -- разбить на подкомпоненты
6. **channelTf split валидация** (из S5R2 рекомендаций) -- перенести в S7

## Статистика

| Приоритет | Всего | open | open (S7/S8) |
|-----------|-------|------|-------------|
| CRITICAL | 1 | 1 | 0 |
| WARNING | 6 | 4 | 2 |
| INFO | 4 | 2 | 2 |
| **Итого** | **12** (новых) + **5** (техдолг) | **7** | **4** |
