---
sprint: 7
agent: ARCH
phase: midsprint (W1 → W2 gate)
date: 2026-04-25
status: PASS
---

# ARCH Midsprint Review — W1 → W2 Gate

## 1. Что проверено

- Прочитаны 3 W1-отчёта (BACK1, BACK2, FRONT1) + W0 (ARCH, UX, QA) + arch_design_s7.md + execution_order.md §3–§7 + changelog.md записи 2026-04-25.
- Выполнены 9 grep-проверок (C1, C2, C7, C8, MR.5 EVENT_MAP, MR.5 publish-сайты, BacktestJobManager production-инстанциация, frontend WS-хуки в production, BackgroundBacktestsBadge в Header).
- Прочитана миграция `a7b2c83d4e51_add_backtest_jobs.py` (upgrade + downgrade).
- Сверён INDEX.md Stack Gotchas с разделом 7 каждого DEV-отчёта.

## 2. Найденные delta'ы W0 → W1

- **Нет архитектурных delta.** Все реализации соответствуют arch_design_s7.md §3 (event_type), §4 (WS sessions), §5 (BacktestJobManager + WS backtest).
- **Frontend минор:** один data-testid `bg-backtest-badge` вместо двух space-separated (Testing Library exact match). UX-плану (e2e_test_plan_s7.md L301) соответствует.
- **UX delta для 7.10:** TradeDetailsPanel выводит «—» при отсутствии `entry_reason`/`exit_reason` (assume-ARCH §10 принят); Mantine `<Tooltip>` вместо нативного `title` — кандидат на polish W3.
- **Pre-existing fail починен** (`test_process_buy_signal`) — корректно: paper-mode фиксит ордер мгновенно ещё с S5/S5R, тест ожидал `'pending'` ошибочно. Reggression нет.

## 3. Контракты (детальная сверка)

- **C1, C2** — поставщик BACK1, потребитель FRONT1 — PUBLISHED, оба endpoint видны в `app/main.py:188,190`, frontend hooks в production-страницах (`TradingPage.tsx:6,22`, `BackgroundBacktestsBadge.tsx:27`).
- **C7** — `grep "NotificationService()" app/ | grep -v main.py` = 0 строк кода (есть только docstring в dependencies.py:11). PriceAlertMonitor singleton переведён в lifespan корректно.
- **C8** — handler в telegram_webhook.py:460,463; build keyboard в telegram.py:92,99; ownership-check (JOIN Strategy.user_id) реализован.
- **C9** — добавлен в execution_order.md (строки 204, 259, 270). Поставщик BACK1, потребитель FRONT2, отметка W2.

## 4. MR.5 (5 event_type — обязательная для финала проверка)

EVENT_MAP в service.py — 5 типов присутствуют. Production publish-сайты:
- `trade.opened`: engine.py:846, engine.py:1201
- `order.partial_fill`: engine.py:1171
- `order.error`: engine.py:885 (helper `_publish_order_error` + try/except в process_signal:812)
- `connection.lost`: multiplexer.py:244
- `connection.restored`: multiplexer.py:221

Listener `listen_broker_status` подключён в lifespan main.py:71. Анти-спам флаг (аналог gotcha-18) — multiplexer.py:79–80.

## 5. Alembic / Integration verification

- `a7b2c83d4e51_add_backtest_jobs.py` — есть `downgrade()` (drop_index + drop_table). Server_default'ы — литералы (`sa.text("'queued'")`, `sa.text("0")`, `sa.text("CURRENT_TIMESTAMP")`) — gotcha-12 соблюдён. Drift отсутствует — только create_table + create_index.
- `BacktestJobManager(AsyncSessionLocal)` — main.py:85 (production-инстанциация).
- Frontend hooks в production: `TradingPage.tsx:6,22`, `BackgroundBacktestsBadge.tsx:27`, `Header.tsx:13,128`.
- Polling sessions удалён: `grep setInterval.*sessions` = 0.
- Помеченных `⚠️ NOT CONNECTED` нет.

## 6. Stack Gotchas

- Применены: #04 (try/except в reconnect), #08 (StaticPool в jobs тестах), #11 (no drift), #12 (литералы default'ов), #16 (auth-first WS), #17 (stub-объекты вместо patch.object), gotcha-18-аналог (анти-спам connection.lost).
- Кандидаты в новые: data-testid space-separated (FRONT1) — единичный случай; UX-кандидаты (localStorage quota, bucket-edge, WS storm, 403/404 leak) — относятся к W2-функционалу. **Решение ARCH:** не создаю новые `gotcha-NN-*.md` в midsprint — недостаточно повторений в W1 + симптомы пока не подтверждены production-кодом. Возврат к вопросу на 7.R после W2.

## 7. Проблемы / Blockers

Блокеров нет. Открытые вопросы (не блокирующие W2):
1. Покрытие real-mode test_order_manager — тикет на 7.R.
2. `BacktestJob.params_json` Decimal→str при rerun — учесть в 7.2-be.
3. 6 frontend lint errors в pre-existing файлах — фикс-волна 7.R.
4. UX midsprint review реализации W1 — параллельная задача UX-агента.

## 8. Артефакты + рекомендации W2

**Созданные файлы:**
- `Спринты/Sprint_7/midsprint_check.md` (гейт-отчёт).
- `Спринты/Sprint_7/reports/ARCH_midsprint_review.md` (этот файл).

**Не созданы:** новые `gotcha-NN-*.md` (см. п.6 — обоснование).

**Рекомендации W2 (приоритеты):**
1. BACK2 публикует **C4** (alembic `strategy_versions`) первым в треке — FRONT2 не стартует пока schema не закоммичена.
2. BACK1 публикует **C9** (`GET /account/balance/history`) до старта FRONT2 7.7 sparkline.
3. Новые W2 endpoints — через `Depends(get_notification_service)` (helper уже готов).
4. Migrations W2 — повторить чек gotcha-11/gotcha-12 для каждой новой revision.

**Гейт midsprint → W2: PASS. Можно стартовать W2.**
