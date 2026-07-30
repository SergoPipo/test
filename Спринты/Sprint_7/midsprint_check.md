# Sprint 7 — Midsprint Checkpoint

**Дата:** 2026-04-25
**Исполнитель:** ARCH
**Гейт:** W1 → W2

## Статус: PASS

Все 6 debt-задач W1 закрыты, контракты W1 (C1, C2, C7, C8) опубликованы и состыкованы, MR.5 (5 event_type) подтверждён в production-коде, alembic-миграция корректна. Pre-existing fail `test_process_buy_signal` починен (771 passed / 0 failed). Готово к старту W2.

## Контракты — таблица

| # | Поставщик | Потребитель | Статус | Доказательство |
|---|-----------|-------------|--------|----------------|
| C1 | BACK1 | FRONT1 | ✅ PUBLISHED | `app/trading/ws_sessions.py:117` ↔ `frontend/src/hooks/useTradingSessionsWS.ts:136` (использован в `TradingPage.tsx:6,22`) |
| C2 | BACK1 | FRONT1 | ✅ PUBLISHED | `app/backtest/ws_backtest.py:49` ↔ `frontend/src/hooks/useBacktestJobWS.ts:100` (бутстрап в `BackgroundBacktestsBadge`) |
| C3 | BACK2 | FRONT1 | ⏸ W2 | (AI ChatRequest.context — отложено) |
| C4 | BACK2 | FRONT2 | ⏸ W2 | (alembic strategy_versions — первоочередная W2) |
| C5 | BACK1 | FRONT2 | ⏸ W2 | (Grid Search — W2) |
| C6 | BACK2 | FRONT2 | ⏸ W2 | (Wizard — W2) |
| C7 | BACK2 | BACK1, OPS | ✅ PUBLISHED | `grep "NotificationService()" app/` без main.py = 0 (только docstring в dependencies.py) |
| C8 | BACK2 | (deep link) | ✅ PUBLISHED | `notification/telegram.py:92,99` build keyboard, `telegram_webhook.py:460,463` handler |
| C9 | BACK1 | FRONT2 | ✅ В execution_order | строка 204 (таблица), 259 (W2 BACK1), 270 (контрактные точки) |

## MR.5 — 5 event_type

EVENT_MAP в `app/notification/service.py` содержит все 5 типов. Production publish-сайты:

| event_type | file:line |
|------------|-----------|
| `trade.opened` | `engine.py:846` (paper-fill), `engine.py:1201` (real-mode параллельно с trade.filled) |
| `order.partial_fill` | `engine.py:1171` (PositionTracker при `filled_lots < volume_lots`) |
| `order.error` | `engine.py:885` (через helper `_publish_order_error`, вызов из process_signal:812) |
| `connection.lost` | `multiplexer.py:244` (с анти-спам флагом) |
| `connection.restored` | `multiplexer.py:221` (после первого успешного response) |

Listener `NotificationService.listen_broker_status` подключён в lifespan `main.py:71`, фан-аут на user_id через `_session_user_map`.

## Stack Gotchas

- DEV-1, DEV-2, DEV-3 применили существующие ловушки: #04, #08, #11, #12, #16, #17 (плюс анти-спам аналог #18).
- Кандидаты на новые ловушки (UX W0 + DEV-3): localStorage quota для drawings, bucket-edge inclusivity для гистограммы P&L, WS reconnect storm на reload, 403 vs 404 ownership leak в AI-context, data-testid space-separated. **Решение:** все они единичные / относятся к W2-функционалу — отложены на 7.R, недостаточно повторений в S7.
- Новых файлов `gotcha-NN-*.md` ARCH в midsprint не создавал.

## Регрессия и тесты

- backend `pytest tests/ -q`: **771 passed / 0 failed** (после фикса pre-existing test_process_buy_signal).
- frontend `pnpm test`: **287 passed / 0 failed**, `tsc --noEmit` 0 errors.
- 6 frontend lint errors в pre-existing файлах (CandlestickChart, SessionDashboard, ChartPage, ProfileSettingsPage, priceAlertStore) — отложено на 7.R.
- E2E baseline 119/0/3 — параллельно прогоняется оркестратором, не блокирует midsprint.

## Открытые вопросы для W2

1. Real-mode сценарий test_order_manager (`status="pending"` сразу после выставления) — нет покрытия, тикет на 7.R.
2. `BacktestJob.params_json` при `default=str` сериализует `Decimal` в строку — при rerun нужен явный парсинг (учесть в 7.2-be Grid Search).
3. Frontend lint 6 errors — требует 7.R фикс-волну.
4. UX-приёмка реализации W1 (UX midsprint review) — параллельная задача, не блокирует.

## Рекомендации по W2

1. **C4 (alembic strategy_versions)** — первоочередно, FRONT2 7.1-fe ждёт schema.
2. **C9 (balance/history)** — публикуется BACK1 до старта FRONT2 7.7.
3. **C7 helper** — новые W2 endpoints (BACK2 7.18 AI chat, 7.1 versioning) использовать `Depends(get_notification_service)`, не `getattr(app.state)`.
4. Новая alembic-миграция (C4) — проверить на gotcha-12 (server_default'ы как литералы для SQLite batch_alter), gotcha-11 (drift).

**Гейт midsprint → W2: PASS. Можно стартовать W2.**
