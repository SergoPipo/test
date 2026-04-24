# Бэклог доработок -- после Sprint 5 + Sprint 6

> Задачи, выявленные при ревью кода S5+S6.
> Включает: замечания code_review.md, незакрытые задачи из Sprint_4_Review/backlog.md,
> технический долг и рекомендации для S7.

## Задачи

| # | Приоритет | Модуль | Описание | Статус |
|---|-----------|--------|----------|--------|
| 1 | ~~CRITICAL~~ | trading/runtime.py | ~~**NameError: datetime/timezone в _handle_candle.**~~ **ЛОЖНОПОЛОЖИТЕЛЬНЫЙ** -- `from datetime import datetime, timezone` на строке 42 модуля, доступен во всех методах | closed (FP) |
| 2 | WARNING | notification/service.py + email.py | **EMAIL_ALLOWED_EVENTS не проверяется.** Добавлена проверка `event_type in EMAIL_ALLOWED_EVENTS` в `dispatch_external()` | **FIXED** |
| 3 | WARNING | trading/*.py, notification/*.py и др. | **Множественные инстансы NotificationService (9 мест).** Singleton уже создан в main.py:68, но не используется в остальных модулях. Требуется DI-рефакторинг | open (S7) |
| 4 | WARNING | PauseConfirmModal.tsx | **Side effect в render body.** Вынесено в `useEffect([opened, session, hasPosition])` | **FIXED** |
| 5 | WARNING | trading/service.py:336 | **Мёртвый SELECT.** Удалён | **FIXED** |
| 6 | WARNING | notification/service.py (EVENT_MAP) | **5 event_type не подключены к runtime.** Запланировано для S7 | open (S7) |
| 7 | WARNING | telegram.py | **Inline-кнопки не обрабатываются.** Запланировано для S7 | open (S7) |
| 8 | INFO | circuit_breaker/engine.py:428 | **Docstring устарел.** Обновлён: "10:00-23:50 MSK" | **FIXED** |
| 9 | INFO | CandlestickChart.tsx:457,509 | **console.error в production.** Заменены на silent-комментарии | **FIXED** |
| 10 | INFO | BlocklyWorkspace.tsx:198,200 | **console.log в production.** Удалены | **FIXED** |
| 11 | INFO | middleware/rate_limit.py | **In-memory state per-worker (из S4 backlog #19).** Приемлемо для single-worker | open (S8) |
| 12 | INFO | StrategyEditPage.tsx | **935 строк, монолит (из S4 backlog #19).** Требует рефакторинга | open (S8) |
| 13 | WARNING | AISettingsPage.tsx:131 | **Crash при `providers = undefined`** (API вернул `{}` без providers). Добавлен `?? []` | **FIXED** |
| 14 | WARNING | AISettingsPage.tsx:381-382 | **Crash `undefined.toLocaleString()`** когда `prompt_tokens_limit` не задан. Заменено на `!p.prompt_tokens_limit ? '∞'` | **FIXED** |
| 15 | WARNING | marketDataStore.ts:221,274 | **Crash при невалидном ответе API свечей** (`candles = undefined`). Добавлен default `= []` | **FIXED** |
| 16 | WARNING | runtime.py + engine.py (8 publish-сайтов) | **EVENT_MAP шаблоны не подставляются** (`{strategy_name}`, `{ticker}`, `{direction}`, `{volume}`, `{pnl}`) — 5 из 7 event_type в `EVENT_MAP` публиковали неполные данные. Исправлены все publish в `trading/runtime.py` и `trading/engine.py`: `session.started`, `session.stopped`, `order.placed`, `trade.filled`, `trade.closed`. В `_SessionListener` добавлено поле `strategy_name`. | **FIXED** |
| 17 | INFO | 10 E2E тестов | **Исправлены тесты, упавшие из-за pre-existing проблем моков/локаторов** (s4-review-full навигация, s6-notifications scroll, strategy редирект, Unicode в regex, CB crash на /settings и др.) | **FIXED** |

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

| Приоритет | Всего | FIXED | FP | open (S7/S8) |
|-----------|-------|-------|-----|-------------|
| CRITICAL | 1 | 0 | 1 | 0 |
| WARNING | 9 | 7 | 0 | 2 |
| INFO | 5 | 4 | 0 | 1 |
| **Итого** | **17** (новых) + **5** (техдолг) | **11** | **1** | **3** |

Дополнительно из визуальной верификации и E2E прогона:
- 3 code fixes (AISettingsPage x2, marketDataStore)
- 10 E2E тестов исправлены (с 107 passed / 12 failed → 119 passed / 0 failed)
- Фикс шаблонов EVENT_MAP в 8 publish-сайтах (`trading/runtime.py`, `trading/engine.py`) — 5 event_type теперь корректно заполняют контекст для уведомлений
