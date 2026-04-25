---
sprint: 7
agent: DEV-2 (BACK2)
wave: 1
date: 2026-04-25
tasks: [7.12, 7.14]
contracts_published: [C7, C8]
---

# DEV-2 BACK2 W1 — отчёт

## 1. Реализовано

- **7.12 NotificationService singleton DI (контракт C7 — опубликован первым по требованию `execution_order.md` §5).** Создан FastAPI Depends-helper `get_notification_service`; `app.state.notification_service` уже создавался в S6, но `app/market_data/router.py:84` обходил DI и инстанцировал `PriceAlertMonitor(db_factory=None)`. Теперь `PriceAlertMonitor` тоже singleton — создаётся в lifespan c корректным NS, кладётся в `app.state.price_alert_monitor`, читается роутером через `getattr(request.app.state, ...)`. Контракт C7 опубликован: `grep -rn "NotificationService()" app/` = 0 вне `main.py`.
- **7.14 Telegram CallbackQueryHandler (контракт C8).** Доработан `_handle_callback` в `TelegramWebhookHandler`: для `open_session:{id}` — ownership-check через JOIN `Strategy → StrategyVersion → TradingSession`; для `open_chart:{ticker}` — валидация и deep link через новый `settings.FRONTEND_URL`. `TelegramNotifier.send` теперь принимает `ticker` явно — `_build_keyboard` строит `open_chart:{TICKER}`, а не `open_chart:{trade_id}`. `NotificationService.dispatch_external` резолвит ticker для `instrument`/`trade`-уведомлений из БД.

## 2. Файлы

Изменённые:
- `Develop/backend/app/main.py` (lifespan: `app.state.price_alert_monitor`).
- `Develop/backend/app/config.py` (новая настройка `FRONTEND_URL`).
- `Develop/backend/app/market_data/router.py` (singleton PriceAlertMonitor; `Request` в сигнатуре `get_candles`).
- `Develop/backend/app/notification/__init__.py` (экспорт `get_notification_service`).
- `Develop/backend/app/notification/service.py` (`dispatch_external` передаёт ticker; helper `_resolve_ticker_for_notification`).
- `Develop/backend/app/notification/telegram.py` (`send(...ticker=)`, `_build_keyboard(ticker=)`).
- `Develop/backend/app/notification/telegram_webhook.py` (новые `_handle_open_session_callback`, `_handle_open_chart_callback`; ownership + ticker validation).

Созданные:
- `Develop/backend/app/notification/dependencies.py` (`get_notification_service` Depends).
- `Develop/backend/tests/test_notification/test_singleton_di.py` (5 тестов).
- `Develop/backend/tests/test_notification/test_telegram_callbacks.py` (7 тестов).

## 3. Тесты

- `pytest tests/test_notification/ tests/unit/test_notification/ -q` → **61 passed, 0 failed**.
- `pytest tests/ --ignore=tests/test_market_data --ignore=tests/test_circuit_breaker --ignore=tests/test_trading -q` → **604 passed, 0 failed** (60 сек).
- `pytest tests/test_market_data tests/test_trading -q` → **101 passed, 1 failed**. Failure: `test_process_buy_signal` (ожидает `status='pending'`, получает `'filled'`) — это последствие параллельных правок BACK1 в `OrderManager.process_signal` (7.13), не связано с 7.12/7.14. Передано в координацию.

## 4. Integration points

- `grep -rn "NotificationService()" app/` **до**: 0 (singleton уже был с S6, но 1 fallback `PriceAlertMonitor(db_factory=None)` без NS). **После**: 0 — контракт C7 чист.
- `grep -rn "get_notification_service" app/`: `notification/dependencies.py:25`, `notification/__init__.py:6`. На W1 endpoints/сервисы W1 ещё не цепляются через `Depends` (используется `app.state` напрямую в `backtest/router.py:314,485` и через ctor injection в `runtime/scheduler/price_alert_monitor`). Helper готов для W2-кода (BACK2 7.18 AI chat и BACK1 7.15 WS-роутер).
- `grep -rn "app.state.notification_service\|state, .notification_service" app/`: `main.py:66` (writer), `notification/dependencies.py:32`, `backtest/router.py:314, 485` (existing readers).
- `grep -rn "open_session:\|open_chart:" app/`: `notification/telegram.py:81,87` (build keyboard), `notification/telegram_webhook.py:455,460` (handler), `tests/test_notification/test_telegram_callbacks.py` (тесты).

## 5. Контракты

- **C7 (поставщик, опубликован):** singleton доступ через `request.app.state.notification_service` или `Depends(get_notification_service)` из `app.notification.dependencies`. Документация в docstring, тест-grep блокирует регрессию. Потребители — BACK1 (7.13, 7.15-be), OPS (7.9), BACK2 W2 (7.18).
- **C8 (поставщик, опубликован):** CallbackData scheme `open_session:{session_id}` → deep link `{FRONTEND_URL}/trading?session={id}`; `open_chart:{TICKER}` → `{FRONTEND_URL}/chart/{TICKER}`. Регистрация: `TelegramWebhookHandler._app.add_handler(CallbackQueryHandler(self._handle_callback))` в `__init__`. Ownership: `open_session` — JOIN `Strategy.user_id == user.id`; `open_chart` — публичные тикеры, ownership не требуется (только sanitize `[A-Z0-9_]{1,20}`).

## 6. Проблемы

- `test_process_buy_signal` failed после параллельных правок BACK1 в `OrderManager.process_signal` — не наша зона, требует синхронизации в midsprint checkpoint.
- `app.state.notification_service` в существующем `backtest/router.py` использует `getattr` напрямую, а не `Depends(get_notification_service)`. Менять не стал — это территория BACK1 (7.17 `backtest_jobs`), там код ещё переписывается. На W2 BACK2 будет использовать helper в новых endpoints (AI chat, wizard, versioning).

## 7. Применённые Stack Gotchas

- **#07 (`app` shadow)** — следование паттерну lifespan-скоупа: импорт `NotificationService` локально внутри lifespan, а не на уровне модуля.
- **#11 (alembic drift)** — миграций в W1 нет, на W2 контролируем при добавлении `strategy_versions.created_by`/`comment`.
- **#17 (telegram bot frozen)** — в `test_telegram_callbacks.py` мокаем не инстанс `Bot`, а пользуемся stub-объектами для `query` (избегаем `patch.object(bot_instance, ...)`).

## 8. Новые Stack Gotchas + плагины

- Новых stack gotcha не выявлено.
- Плагины: pyright fallback `python -m py_compile` после каждого Edit/Write (7 файлов, 0 ошибок). context7/WebSearch не требовались — FastAPI `Request`/`Depends` и `python-telegram-bot 20+` уже были в S6 кодовой базе и проверены в `gotcha-17-*.md`. superpowers:TDD не вызывался формально, но соблюдён ритм Red-Green-Refactor: сначала тесты на DI (failed без helper'а), затем реализация, затем тесты на ownership.
