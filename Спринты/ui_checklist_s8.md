# UI-чеклист Sprint 8 (M4 Production-ready)

> Расширяет `ui_checklist_s7.md` — **все** проверки оттуда продолжают применяться без изменений.
> Применяется при приёмке Sprint 8 (8.R ARCH-ревью) и QA-прогонах перед M4 production rollout.
> База S7 — `Спринты/ui_checklist_s7.md` (193 строки, 7 секций). База S5R — `Спринты/ui_checklist_s5r.md`.
>
> Источник истины S8: `Спринты/Sprint_8/arch_design_s8.md` §6 (UI scope) + §8 (waves) + 5 отчётов W1/W2 в `Sprint_8/reports/` + код в `Develop/frontend/src/` (HEAD `s8/sprint-8` = `5aea186`).

---

## S8.1 Admin role (frontend, контракт C-S8-7)

- [ ] Sidebar показывает пункт «Администрирование» (`IconShield`, `data-testid="sidebar-admin-link"`) **только** если `useAuthStore().user.is_admin === true`. Источник: `Develop/frontend/src/components/layout/Sidebar.tsx:15` (`navItems.filter(item => !item.adminOnly || isAdmin)`).
- [ ] Обычный пользователь (`is_admin=false`) при попытке открыть `/admin` через прямой URL получает редирект на `/` + toast «Доступ ограничен» — `ProtectedAdminRoute`.
- [ ] Sidebar для admin содержит ровно 8 пунктов: Стратегии, Графики, Бэктесты, Торговля, Счёт, Уведомления, Настройки, **Администрирование**. Для не-admin — 7 (без админки).
- [ ] Backend `/api/v1/admin/*` endpoints отдают 403 без `is_admin=true` (DEV-1 W1, `require_admin` dependency).
- [ ] Bootstrap: первый зарегистрированный пользователь автоматически получает `is_admin=true` (BACK1 W1).
- [ ] CLI `python -m app.cli.users grant_admin <username>` работает и логирует действие в structlog.
- [ ] `/auth/me` response содержит поле `is_admin: bool`. UI-тип `AuthUser.is_admin?: boolean` в `api/types.ts`.
- [ ] `/admin` landing page рендерится с `data-testid="admin-landing-page"`, заголовок «Администрирование», бейдж «admin» зелёный, ссылка на `/admin/metrics`.

## S8.2 Plotly Dash `/admin/metrics` (контракт C-S8-8)

- [ ] Страница `GET /api/v1/admin/metrics/` без JWT — 401.
- [ ] Без `is_admin=true` — 403 (через `AdminAuthASGIMiddleware`).
- [ ] С `is_admin=true` — 200 + Dash HTML с маркером `_dash-app-content`.
- [ ] Рендерится 4 chart'а (по `arch_design_s8.md` §11 batch 2): signal→order latency p50/p95, dashboard LCP p95, Telegram-команда latency, Backtest jobs rate. Известное ограничение: **данные MOCK** до подключения persistent metrics-таблицы (см. отчёт DEV-4 W2 §6).
- [ ] Графики обновляются при reload (Dash callback re-render).
- [ ] CSS dark theme применяется (`prefers-color-scheme: dark` — Dash inline style).

## S8.3 ErrorBoundary (S7R-FRONTEND-ERROR-BOUNDARY-MISSING)

- [ ] Top-level `<ErrorBoundary level="app">` обёртывает `<Routes>` в `App.tsx:32`.
- [ ] Per-widget ErrorBoundary вокруг **каждого** dashboard виджета: Balance / Health / Positions / Sparkline (`DashboardPage.tsx:182-197`).
- [ ] При throw в одном виджете — рендерится fallback UI (Mantine `Alert` с `IconAlertTriangle`), соседние виджеты остаются рабочими (не белый экран).
- [ ] `data-testid="error-boundary-balance|health|positions|sparkline"` присутствуют.
- [ ] Кнопка «Повторить» внутри fallback — сбрасывает error state и пытается re-render.
- [ ] `componentDidCatch` пишет в console: `[ErrorBoundary level=widget] <error>` + componentStack.
- [ ] Chart-страница: `<ErrorBoundary>` вокруг `<CandlestickChart>` (`ChartPage.tsx:293-309`).

## S8.4 Strategy status change UI (S7R-STRATEGY-STATUS-CHANGE-UI, контракт C-S8-2 интегрировано)

- [ ] В строке стратегии Dashboard'a — Mantine `Menu` с target = Badge (`StrategyStatusMenu.tsx:60`).
- [ ] Badge меняет label + цвет по статусу: Черновик (gray), Протестирована (blue), Paper Trading (yellow), Real Trading (red), Пауза (orange), Архив (gray).
- [ ] Клик по Badge раскрывает Menu с 6 пунктами (все статусы); невалидные `transition`'ы — `disabled` (`STRATEGY_STATUS_TRANSITIONS`).
- [ ] Optimistic update: при клике статус меняется в UI до ответа сервера.
- [ ] При успехе PATCH `/strategy/{id}` (S3 endpoint, body `{status}`) — green toast «Статус обновлён».
- [ ] При ошибке — rollback оптимистичного статуса + red toast.
- [ ] **S8 W3** Фильтр `Pause` присутствует в SegmentedControl на DashboardPage (`DashboardPage.tsx:171` — S7R-STRATEGY-STATUS-PAUSED-FILTER).

## S8.5 Dashboard widgets новые (контракты C-S8-1, C-S8-2, C-S8-3)

- [ ] **SparklineWidget** (`data-testid="dashboard-widget-sparkline-24h"`) — 24h SVG sparkline для выбранного тикера. Использует `getRecentInstruments()[0] ?? 'SBER'` как ticker.
- [ ] Endpoint `GET /market-data/sparkline?ticker=X&hours=24` возвращает `{points: [{t, p}], current}` (C-S8-2). UI рендерит через `MiniSparkline` (inline SVG, не lightweight-charts — обход Gotcha-24).
- [ ] States Sparkline: loading (Skeleton), error (Alert + кнопка «Повторить»), empty (пустой график + «Нет данных»), no-ticker placeholder («Выберите тикер»).
- [ ] **HealthWidget** расширен полями: `cb_state`, `tinvest_connected`, `scheduler_running`, `scheduler_jobs` (C-S8-1).
- [ ] Health badge цвет соответствует `cb_state`: ok=green, warn=yellow, triggered=red.
- [ ] **BalanceWidget** — sparkline история обрезается с момента первой активности (`accountApi.getBalanceHistory(30, since_first_activity=true)`, C-S8-3).
- [ ] Polling 30s для `/health` через `useEffect` setInterval (известное ограничение S7 — миграция на WS = S7R-HEALTH-WS-MIGRATION в W3 Поток A).
- [ ] States all 3 widgets: loading skeleton, error retry, empty.
- [ ] data-testids: `dashboard-widget-sparkline-24h`, `dashboard-widget-health`, `dashboard-widget-balance`, `dashboard-widget-positions` — все 4 widget'а на одной строке `<SimpleGrid cols={{base:1,sm:2,lg:4}}>`.

## S8.6 Wizard Telegram test button (контракт C-S8-4)

- [ ] На шаге 4 wizard есть раскрываемый блок «Свой бот» (`Collapse`).
- [ ] При expanded — `PasswordInput` для `bot_token` (`data-testid="wizard-telegram-bot-token-input"`).
- [ ] `TextInput` для `chat_id` (`data-testid="wizard-telegram-chat-id-input"`).
- [ ] Кнопка «Отправить тестовое сообщение» (`data-testid="wizard-telegram-test-button"`) — disabled пока оба поля не заполнены.
- [ ] При клике — `POST /notifications/telegram/test` (C-S8-4) с body `{bot_token, chat_id}`.
- [ ] Toast «✅ Сообщение отправлено» при 200 или «❌ Ошибка: <detail>» при 4xx/5xx.
- [ ] При завершении wizard (`handleFinish`) — telegram_enabled автовключается для критичных event_types через `notificationApi.bulkUpdate()` (правило `project_wizard_notifications_save`).

## S8.7 Event type labels синхронизация UI ↔ EVENT_MAP (контракт C-S8-9)

- [ ] `NotificationSettingsPage.tsx:24-43` содержит **17 ключей** в `EVENT_TYPE_LABELS`.
- [ ] 13 UI типов (S7): `trade_opened`, `trade_closed`, `partial_fill`, `cb_triggered`, `order_error`, `all_positions_closed`, `session_recovered`, `connection_lost`, `connection_restored`, `backtest_completed`, `daily_stats`, `corporate_action`, `price_alert`.
- [ ] 4 новых backend-типа S8 (W2 / C-S8-9): `session_started`, `session_stopped`, `order_placed`, `trade_filled` — лейблы добавлены, синхронны с `app/notification/event_map.py`.
- [ ] Включить Telegram + Email для типа `trade_filled` → реальная сделка → **in-app + Telegram** по самой сделке. **Email подтверждается на событии из белого списка** `EMAIL_ALLOWED_EVENTS` — например `all_positions_closed`, которое порождается закрытием позиции той же сделкой (`notifications.channels_sent = in_app,telegram,email`).
  ⚠️ Email по событиям сделок (`order_placed`, `trade_opened`, `trade_filled`, `trade_closed`) не рассылается **намеренно**: иначе активная стратегия слала бы письмо на каждую сделку. API отдаёт по ним `email_supported: false`, тумблер Email в UI погашен — это не дефект (`S8R-S87-EMAIL-NOT-FOR-TRADE-EVENTS`, решение заказчика 2026-07-31).
- [ ] data-testid `event-type-row-<event_name>` или таблица с `<tr data-event-type=...>` для каждого ивента.
- [ ] Дефолт: `in_app_enabled=true`, остальные `false`.

## S8.8 Drawing tools editing (S7R-DRAWING-EDITING + S7R-DRAWING-INTRADAY-COORDS)

- [ ] Drag фигуры (trendline / rect / label) мышью — плавное перемещение, persist в backend + fallback localStorage. Источник: `DrawingsLayer.tsx:485` (pointer handler Phase 4).
- [ ] Изменение углов через handle (vertex/corner). Cursor меняется при наведении на handle (`cursor: pointer` / `nwse-resize`).
- [ ] Sequential-index координаты на intraday TF (1m/5m/15m/1h/4h) — корректные. Детектор `isSeriesInSequentialMode()` через `series.data()[0].time < 1e6` (`coords.ts`, DEV-3 W1).
- [ ] Backspace / Delete удаляет выделенную фигуру (через `DrawingToolbar` keyboard listener).
- [ ] Esc снимает выделение + переключает tool на cursor.
- [ ] Контекстное меню (правый клик) — пункт «Удалить» работает.
- [ ] `legacy drawings` без `logical` на intraday TF — не рендерятся (`pointToCoord → null`). Сознательный выбор «hide > misposition»; backfill миграция = S8R-DRAWING-LEGACY-BACKFILL в S9.

## S8.9 AIChat / StrategyDescription apply (mock blocks_json)

- [ ] В Blockly editor — кнопка «AI-описание» открывает `AIModePanel`.
- [ ] Внутри панели `StrategyDescription` рендерит textarea для описания.
- [ ] Кнопка `data-testid="apply-to-blocks-btn"` — отправляет описание, получает `blocks_json` (mock в S8, реальный template parser планируется S9).
- [ ] При успехе — `onApplyBlocks(blocksJson)` пробрасывается в `BlocklyWorkspace`, блоки рендерятся.
- [ ] При warnings — Alert с предупреждениями (например, «не найден тикер X»).
- [ ] Loading state — `<Loader>` блокирует кнопку.

## S8.10 SecurityHeadersMiddleware (CSP / HSTS — поведение UI)

- [ ] Все HTTP-ответы backend содержат headers: `Strict-Transport-Security`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (запрет camera/microphone/geolocation/payment/usb).
- [ ] Frontend не использует inline-scripts (CSP нарушит). Все `<script>` через bundler chunks.
- [ ] Frontend не пытается embed-нуть приложение в iframe (X-Frame-Options DENY).
- [ ] WebSocket handshake (101) не получает security headers (приемлемо).
- [ ] Известное ограничение: 2 vitest `client.test.ts` flaky после введения middleware — карточка `S8R-CLIENT-TEST-FLAKY` в W3 backlog.

## S8.11 BG-backtest panel (S7 baseline + S8 polish)

- [ ] **Bg-backtest badge** в шапке (`data-testid="bg-backtest-badge"`) показывает count активных + завершённых jobs.
- [ ] Click → Popover со списком (см. S7.17 чеклист). Полностью унаследовано из S7.
- [ ] **Grid Heatmap entry-point (S8.D.7)** — кнопка `data-testid="bg-backtest-grid-heatmap-open"` в popover открывает Modal с `<GridSearchHeatmap>` для completed grid job'ов. Подтверждено DEV-4 W2 §1.
- [ ] **AUTO-COLLAPSE (S7R-BG-BACKTEST-AUTOCOLLAPSE)** — W3 Поток A: при `running.length === 0 && done.length > 0` panel сворачивается через 5 сек. (~1ч задача).
- [ ] Cap = 3 параллельных bg-backtests (`MAX_CONCURRENT_BACKGROUND_BACKTESTS`).

## S8.12 Backtest analytics tabs (S7R-E2E-7.16 + S8R-ANALYTICS-*)

- [ ] `/backtests/{id}` — 4 вкладки: Обзор / График / Показатели / Сделки.
- [ ] **Equity zones** на ценовом графике (`InstrumentChart.tsx:226`) — `data-testid="equity-curve-zone-{idx}"` DOM overlay поверх canvas, `pointerEvents:none` на overlay, hover на zone — подсветка trade-range.
- [ ] **Trade row click → TradeDetailsPanel** (`BacktestTrades.tsx:285`) — `onRowClick` prop пробрасывается из `BacktestResultsPage`; per-row `data-testid="backtest-trade-row-{trade_id}"`.
- [ ] При клике на сделку — раскрывается `<TradeDetailsPanel>` с entry/exit (time, price, reason, pnl, duration).
- [ ] `data-testid="pnl-histogram"` (гистограмма P&L) и `data-testid="win-loss-donut"` рендерятся на вкладке «Обзор» (наследовано из S7).
- [ ] Кнопка «Запустить торговлю из бэктеста» — открывает `LaunchSessionModal` с предзаполненными параметрами (ticker/timeframe/initial_capital/strategy_id) — наследовано из S7.

## S8.13 API contract / Paginated types (контракт C-S8-5)

- [ ] Generic `PaginatedResponse<T> { items: T[]; total: number; ... }` в `api/types.ts`. Type-guard `isPaginatedResponse<T>()`.
- [ ] Хелпер `unwrapPaginated<T>()` — defensively принимает legacy/null/unexpected формат, возвращает `T[]`.
- [ ] Все API-вызовы с `response_model=PaginatedResponse` корректно типизированы (нет runtime crash «cannot read items of undefined»).
- [ ] data-testid="loading-paginated" присутствует при загрузке.
- [ ] Empty state «Нет данных» рендерится при `items.length === 0`.
- [ ] Точки потребления `unwrapPaginated()`: `tradingStore.ts:60,162,196`, `ActivePositionsWidget.tsx:82`, `CandlestickChart.tsx:805`.

## S8.14 Performance / Observability (целевые ТЗ + контракт BACK1 W2)

- [ ] `@timed_event` декоратор в `app/common/observability.py` применён на 3 hot path: `SignalProcessor.process_candle` (`signal.process`), `TInvestAdapter.place_order` (`order.place`), `TelegramWebhookHandler.process_update` (`telegram.handle`).
- [ ] structlog event: `event="timed_event", timed_event=<name>, duration_ms=<float>`.
- [ ] **Целевые метрики** (отображаются в `/admin/metrics` после persistent storage):
  - p95 signal-to-order < 500ms.
  - p95 Telegram webhook < 3000ms.
  - Dashboard LCP < 2s (chrome devtools manual measurement).
- [ ] Финальные метрики W2 baseline: backend pytest 1490 passed @ 80% coverage; frontend vitest 544 passed; playwright nightly 158 passed.

## S8.15 6 сквозных юзабилити-сценариев (UX W3)

> Проверены **анализом кода + 11 playwright скриншотов** в `Sprint_8/screenshots/`.
> Backend HTTP не отвечал в момент UX-прогона — реальное e2e отложено в QA W3.

### Сценарий 1: Новый пользователь от регистрации до завершения wizard

- [ ] `GET /register` доступен без авторизации (`s8-register.png`).
- [ ] POST `/register` → подтверждение → `/login` → FirstRunWizardGate перехватывает `wizard_completed_at IS NULL`.
- [ ] **Шаг 1-2** Wizard — приветствие + дисклеймер (галочка required). Источник: `FirstRunWizard.tsx`.
- [ ] **Шаг 3** Брокер — Select T-Invest (disabled), Radio paper/real.
- [ ] **Шаг 4** Уведомления — Telegram, Email (in-app всегда checked + disabled), **кнопка «Проверить подключение» новинка S8** (W2 8.D.5.4).
- [ ] **Шаг 5** Финиш — `POST /users/me/wizard/complete` → редирект на `/dashboard`, повторный логин не показывает wizard.

### Сценарий 2: Стратегия → бэктест → запуск Paper Trading

- [ ] Dashboard «Новая стратегия» → `/strategies/new` (Blockly editor).
- [ ] Save → strategy появляется в таблице на `/dashboard`.
- [ ] **Strategy status menu (S8 W1)** — клик по Badge → Menu, выбор статуса → optimistic update → toast.
- [ ] Бэктест → результаты (`/backtests/:id`) → 4 вкладки.
- [ ] **Equity zones (S8 W2)** — hover на зоне трейда, **Trade row click → TradeDetailsPanel (S8 W2)**.
- [ ] Кнопка «Запустить торговлю из бэктеста» → `LaunchSessionModal` с предзаполнением.

### Сценарий 3: Live торговля → мониторинг → закрытие

- [ ] Карточка позиции: ticker, qty, entry_price, P&L (dual % daily + total).
- [ ] **Sparkline 24h (S8 W2)** на DashboardPage — мини-график выбранного тикера.
- [ ] **Health badge extended (S8 W2)** — цвет соответствует `cb_state` (ok/warn/triggered).
- [ ] Telegram `/status` команда — reply с актуальными позициями (backend BACK2).
- [ ] Кнопка «Закрыть позицию» → ордер выставлен, P&L зафиксирован, маркер на графике.

### Сценарий 4: Bg-backtest параллельные jobs

- [ ] BacktestLaunchModal «В фоне» 3 раза → badge count=3.
- [ ] Завершение → декремент badge + toast «Бэктест X завершён».
- [ ] Click badge → Popover с прогресс-барами + кнопками «Открыть результат».
- [ ] Попытка 4-го параллельного → toast «Превышен лимит параллельных бэктестов».

### Сценарий 5: Admin role + Plotly Dash /admin/metrics

- [ ] Bootstrap или CLI: `users.is_admin = True` для `sergopipo`.
- [ ] После релогина — Sidebar пункт «Администрирование» виден.
- [ ] Click → `/admin` (AdminLandingPage) → ссылка на `/admin/metrics`.
- [ ] `/admin/metrics` — Plotly Dash страница с 4 mock-графиками.
- [ ] Non-admin user пытается открыть `/admin/metrics` напрямую → 403 (через AdminAuthASGIMiddleware).

### Сценарий 6: Drawing tools editing + intraday

- [ ] `/chart/SBER` (timeframe день) — нарисовать trendline, drag, изменить угол.
- [ ] Backspace удаляет выделенное, Cmd+Z (если undo реализован).
- [ ] Switch на 5m/15m intraday TF — новая линия. Sequential-index координаты корректны.
- [ ] Известное ограничение: legacy drawings без `logical` не рендерятся на intraday (backfill = S8R-DRAWING-LEGACY-BACKFILL в S9).

## S8.16 Cross-DEV contracts verification (UX как потребитель)

- [ ] **C-S8-1 (health extended):** HealthWidget показывает `cb_state` цвет — ✅ через анализ кода (`HealthWidget.tsx`).
- [ ] **C-S8-2 (sparkline 24h):** SparklineWidget рендерит SVG с реальными точками от `marketDataApi.getSparkline()` — ✅.
- [ ] **C-S8-3 (balance history range):** BalanceWidget шлёт `since_first_activity=true`, sparkline обрезается с первой активности — ✅.
- [ ] **C-S8-4 (Telegram test):** кнопка работает в Wizard step 4 — ✅ (`wizard-telegram-test-button` в `FirstRunWizard.tsx:512`).
- [ ] **C-S8-5 (paginated types):** `unwrapPaginated()` потребляется в 5 точках, нет runtime-crash — ✅.
- [ ] **C-S8-6 (multiplexer singleton):** не визуальное (skip).
- [ ] **C-S8-7 (is_admin field):** Sidebar пункт условный — ✅ (`Sidebar.tsx:12,15`).
- [ ] **C-S8-8 (/admin/metrics):** страница рендерится — ✅ через анализ `metrics_dash.py` + `AdminAuthASGIMiddleware`.
- [ ] **C-S8-9 (event sync):** NotificationSettingsPage содержит 17 ключей — ✅ (`NotificationSettingsPage.tsx:24-43`).

## S8.18 Статус-футер и WS торговых сессий (S8R, 2026-07-31)

Добавлено по итогам находки `S8R-FOOTER-NO-ACTIVE-SESSIONS`. Подпись в футере
была строкой-константой «Нет активных сессий» — она не зависела ни от каких
данных и врала при живой сессии.

- [ ] При **активной** торговой сессии футер (`data-testid="trading-mode"`) показывает «Активных сессий: N», где N — число сессий в статусе `active`. Скриншот: `Sprint_8_Review/screenshots/b1_footer_active_sessions.png`.
- [ ] `paused` и `stopped` в счётчик **не** входят: остановили последнюю сессию → подпись сразу вернулась к «Нет активных сессий» (без перезагрузки страницы — список сессий на `/trading` живёт по WS).
- [ ] Число берётся из `GET /trading/dashboard` (опрос раз в минуту плюс внеочередной — при изменении состава сессий) и показывается одинаково на всех страницах: Дашборд, Графики, Настройки. ⚠️ Отдельно проверить сценарий из код-ревью: открыть `/trading` с активными сессиями → уйти на Дашборд → остановить сессии из другого места → подпись обязана обновиться (список сессий в store не очищается и вне `/trading` не живёт по WS, поэтому опираться на него нельзя).
- [ ] Backend недоступен → футер не ломается и **не** подменяет содержимое страницы `/trading` алертом ошибки (опрос идёт мимо `tradingStore.error`).
- [ ] Бейдж WS на `/trading` (`data-testid="trading-ws-status"`) при живом соединении — «ПОДКЛЮЧЕНО». Проверять после перезагрузки страницы в **dev**-режиме: `<React.StrictMode>` монтирует эффект дважды, и раньше закрытие первого сокета переводило бейдж в «ПЕРЕПОДКЛЮЧЕНИЕ» при исправно идущих данных и оставляло второе соединение незакрытым.

---

## S8.19 Дневной отчёт в Telegram — нереализованный P&L (S8R, 2026-08-03)

Добавлено по итогам `S8R-DAILY-STATS-UNREALIZED-NO-LOT`. Отчёт считал
нереализованный P&L как `(цена − вход) × лоты` — **без** множителя штук/лот,
и для инструментов с `lot_size = 10` (SBER, GAZP, VTBR — большинство акций
MOEX) занижал величину ровно в 10 раз.

- [ ] Открыта позиция по инструменту с `lot_size = 10` (например SBER). В дневном отчёте (`event_type=daily_stats`, 19:00 МСК или ручной запуск `SchedulerService.send_daily_stats`) значение `unreal` совпадает с «Нереализованный P&L» на карточке сессии `/trading/sessions/{id}` — **до копейки**.
- [ ] То же число показывает Circuit Breaker при расчёте дневного лимита. Три источника (отчёт, карточка сессии, CB) обязаны сходиться на одних данных — расхождение и было дефектом.
- [ ] Позиция, открытая **вчера** и не закрытая сегодня, входит в `unreal` дневного отчёта. Раньше не входила: открытые позиции брались из выборки «сделки за сегодня», и переходящая экспозиция в отчёте не отражалась вовсе.
- [ ] Сессия без открытых позиций: в строке отчёта `unreal +0 ₽`, строка не пропадает и не ломает итоговую сумму.
- [ ] Позиция по инструменту, у которого в `OHLCVCache` нет свечей нужного таймфрейма: позиция в сумму **не** входит (выдуманный убыток хуже отсутствующего), отчёт не падает.
- [ ] **Сессия без сегодняшних сделок, но с открытой позицией — в отчёте есть** (`S8R-DAILY-STATS-IDLE-SESSION-HIDDEN`, исправлено 2026-08-03): строка вида «0 откр / 0 закр, real PnL +0 ₽, unreal …». Раньше такая сессия не попадала в отчёт вовсе, а если других сессий не было — отчёт не отправлялся, и живая экспозиция выглядела как «ничего не происходит».
- [ ] Сессия **без** позиций и без сделок строки по-прежнему **не** получает — «нет активности» должно что-то значить.
- [ ] Сессия, у которой есть и сегодняшняя сделка, и открытая позиция, даёт **одну** строку; итоговая сумма не задваивается.

---

## S8.17 Общие проверки за S8

- [ ] **vitest:** `pnpm test --run` → 544 passed / 0 failed (+2 flaky `client.test.ts` pre-existing, baseline `S7` 528 + 16 новых тестов S8 widget'ов = 544).
- [ ] **TypeScript:** `npx tsc --noEmit` → 0 errors.
- [ ] **Lint:** 0 errors / 9 warnings (baseline после W2; цель W3 Поток A — `--max-warnings 0`).
- [ ] **Playwright nightly baseline 158:** не падает. Скриншоты для новых компонентов S8 (Sparkline / Health-extended / Wizard-step4 / Admin-landing) — частично собраны UX W3 (см. `Sprint_8/screenshots/`).
- [ ] **Backend pytest:** 1490 passed / 0 failed / coverage 80%+ (gate active в W3).
- [ ] **Bandit/Safety:** 0 medium+ findings (см. `security_audit_s8.md` — все medium вынесены в S9-backlog).
- [ ] **Dark theme контраст:** новые виджеты (SparklineWidget, HealthWidget extended, BalanceWidget с since_first_activity) — green/red/yellow проходят ≥4.5:1.
- [ ] **a11y:** `IconShield` в Sidebar имеет implicit label через NavLink (`label={item.label}`); кнопка test Telegram в wizard — без `aria-label` (TODO в S9-backlog).
- [ ] **Sidebar collapsed 240→60:** Tooltip с label position="right" работает на admin item (`Sidebar.tsx:33`).

---

## Известные DELTA vs макет / S9-backlog

> Список несовпадений UI с UX-макетами S7 + найденные UX-баги для S9 (severity medium-high заносятся в `Sprint_8_Review/backlog.md` оркестратором по итогам UX W3).

### DELTA с UX-макетами (некритичные)

- **Plotly Dash графики — MOCK данные.** Реальные метрики появятся в S9 после persistent metrics-storage (см. отчёт DEV-4 W2 §6).
- **`/admin/metrics`** — не имеет custom dark theme; Dash default light-on-dark. Допустимая адаптация для production-rollout.
- **AdminLandingPage** — минимальный placeholder (карточка + ссылки на endpoint'ы). UX-макет admin-панели с user management + grant_admin UI = S9 scope.

### UX-баги найдены (UX W3, severity medium / low — кандидаты в S9-backlog)

- **S8R-UX-WIZARD-TG-NO-ARIA** — кнопка `wizard-telegram-test-button` без `aria-label`. Screen reader просто читает «отправить тестовое сообщение» (текст кнопки) — приемлемо, но добавление aria сделает UX полнее. Severity: low. ~10мин.
- **S8R-UX-ADMIN-LANDING-EMPTY** — `/admin` landing — placeholder без полезной информации сверх ссылки на `/admin/metrics`. Не блокер, но S9 должен расширить (текущие метрики snapshot, активные сессии, последние ошибки). Severity: medium-low. ~4ч (S9).
- **S8R-UX-DASH-4COL-OVERFLOW** — Dashboard `<SimpleGrid cols={{base:1,sm:2,lg:4}}>` — на ширине 1024-1280px 4 виджета визуально тесные. Желательно перейти на `lg:3, xl:4`. Severity: low. ~10мин.
- **S8R-UX-DRAWING-LEGACY-BACKFILL** — legacy drawings без `logical` не рендерятся на intraday TF. Sознательный выбор. Backfill миграция = medium severity, ~3ч (DEV-3, S9).
- **S8R-UX-PLOTLY-DARK-THEME** — `/admin/metrics` рендерится в light Dash style (тёмный фон, светлые графики, контраст слабоват). Желательно `template='plotly_dark'`. Severity: low. ~30мин (BACK1, S9).
- **S8R-UX-WIZARD-TG-TEST-DISABLED-HINT** — кнопка test Telegram disabled пока оба поля не заполнены, но нет подсказки почему. Tooltip «Заполните токен и chat_id» — UX-улучшение. Severity: low. ~10мин.

### Архитектурные карточки (medium-high — кандидаты блокеров)

- **S8R-UX-HEALTH-WS-MIGRATION** (medium-high) — REST polling 30s для /health — приемлемо для S8, но для production-rollout WS-подписка через `/ws health` снизит трафик. ~4ч (FRONT2, W3 Поток A).
- **S8R-UX-SPARKLINE-NO-WS** (medium) — SparklineWidget делает один fetch при mount + при смене ticker. Live-обновление через WS отложено. Через WS C-S8-2 streaming OHLCV → SparklineWidget real-time. ~4ч (S9).
- **S8R-UX-MULTICURRENCY-TOGGLE** (medium) — переключение валюты USD/RUB в BalanceWidget — карточка W3 Поток A (опционально, иначе S9). ~6ч.

> **Замечание:** окончательные карточки `S8R-UX-*` оркестратор переносит в `Sprint_8_Review/backlog.md` (или `Sprint_9_Review/backlog.md`) после UX W3. UX-агент не модифицирует backlog напрямую.

---

## Summary checklist coverage

| Категория | Пунктов | Источник |
|-----------|---------|----------|
| S7 базовые (через `ui_checklist_s7.md`) | ~80 | наследовано |
| S5R базовые (через `ui_checklist_s5r.md`) | ~30 | наследовано |
| S8.1 Admin role | 8 | C-S8-7 |
| S8.2 Plotly Dash | 6 | C-S8-8 |
| S8.3 ErrorBoundary | 7 | S7R-ERROR-BOUNDARY |
| S8.4 Strategy status menu | 7 | S7R-STRATEGY-STATUS |
| S8.5 Dashboard widgets | 9 | C-S8-1/2/3 |
| S8.6 Wizard Telegram test | 7 | C-S8-4 |
| S8.7 Event sync 17 типов | 6 | C-S8-9 |
| S8.8 Drawing editing | 7 | S7R-DRAWING-* |
| S8.9 AIChat apply | 6 | S8 mock |
| S8.10 SecurityHeaders | 5 | S8R-SEC-HEADERS |
| S8.11 BG-backtest panel | 5 | S7 + S8.D.7 |
| S8.12 Backtest analytics | 6 | S7R-E2E-7.16 + S8R-ANALYTICS-* |
| S8.13 Paginated types | 6 | C-S8-5 |
| S8.14 Performance | 4 | BACK1 W2 |
| S8.15 6 сценариев | 30 | UX W3 |
| S8.16 9 Cross-DEV contracts | 9 | C-S8-1..9 |
| S8.17 Общие S8 | 8 | baseline |
| S8.18 Статус-футер и WS сессий | 5 | S8R-FOOTER-NO-ACTIVE-SESSIONS |
| S8.19 Дневной отчёт — unrealized + idle-сессии | 8 | S8R-DAILY-STATS-UNREALIZED-NO-LOT + S8R-DAILY-STATS-IDLE-SESSION-HIDDEN |

## S8.20 Комиссия в бумажной торговле (S8R, 2026-08-03)

Добавлено по итогам `S8R-PAPER-NO-COMMISSION`. Paper не удерживал комиссию
вообще, тогда как бэктест той же стратегии её вычитает — результат paper был
систематически оптимистичнее, а сверять его с бэктестом ради этого и нужно.

- [ ] Модалка запуска сессии (`LaunchSessionModal`) содержит поле «Комиссия, %» (`data-testid="commission-pct-input"`) со значением по умолчанию **0,05** — тем же, что предлагается для бэктеста.
- [ ] Поле принимает 0 (удержания нет) и дробные значения до 4 знаков; отрицательное не принимается.
- [ ] После запуска paper-сессии с ненулевой ставкой и первой покупки: свободный кэш уменьшился на стоимость позиции **плюс** комиссию, а «в позиции» (`blocked_amount`) — ровно на стоимость позиции.
- [ ] В журнале сделок закрытой позиции колонка «Комиссия» заполнена и равна сумме удержаний входа и выхода (раньше колонка всегда пустовала).
- [ ] P&L сделки показывается **до** комиссии, а изменение капитала счёта равно P&L минус комиссия обеих сторон — так же считает бэктест.
- [ ] Сессия, запущенная **до** обновления (ставка 0): комиссия не удерживается, поведение прежнее — ретроактивного пересчёта нет.

## S8.21 Метрика полного окна сигнал → ордер (S8R, 2026-08-03)

Добавлено по итогам `S8R-METRIC-SIGNAL-TO-ORDER-BLIND`.

- [ ] На `/admin/metrics` **первым** идёт график «Signal → order, полное окно с Circuit Breaker», под ним — прежний «Signal → order latency».
- [ ] Под нагрузкой значения на первом графике заметно выше, чем на втором: разница и есть ожидание за локом Circuit Breaker, которого прежняя метрика не видела.
- [ ] При отсутствии замеров график рисуется пустым с подписью «нет замеров», а не правдоподобными числами.
## S8.22 Комиссия в sandbox/real и тариф счёта (S8R, 2026-08-04)

Добавлено по итогам `S8R-SANDBOX-REAL-COMMISSION-NOT-RECORDED` (Q2) и
`S8R-PAPER-COMMISSION-BROKER-RATE` (Q5). До этого комиссию писал только
paper-путь: в sandbox/real её удерживает брокер, а терминал об этом не знал —
«чистый P&L» вычитал ноль, и sandbox с бэктестом не сверялся.

- [ ] «Настройки → Брокер», редактирование счёта: есть поле «Комиссия брокера, %» (`data-testid="broker-commission-input"`); принимает 0 и дробные значения, отрицательное и >100 не принимает.
- [ ] Значение сохраняется и после перезагрузки страницы показывается прежним.
- [ ] Запуск **paper**-сессии без явной ставки берёт тариф счёта; ставка, введённая в модалке запуска, имеет приоритет над тарифом.
- [ ] Sandbox-сделка: в журнале сделок колонка «Комиссия» заполнена (раньше всегда пустовала).
- [ ] Если комиссия посчитана по тарифу (песочница брокером её не удерживает), значение показано со знаком **≈**; при наведении — подсказка «Оценка по тарифу счёта, а не удержание брокера».
- [ ] Комиссия, подтверждённая брокером, показана **без** знака ≈.
- [ ] Sandbox-сессия и paper-сессия на одних входных данных дают одинаковый «чистый P&L».

## S8.23 Комиссия за период в статистике сессии (S8R, 2026-08-04)

Добавлено по решению заказчика (Q6): удержание вычиталось из результата, но
самого числа пользователь не видел — разница между результатом стратегии и
изменением счёта выглядела необъяснённой.

- [ ] Вкладка «Статистика» сессии содержит карточку «Комиссия за период» (`data-testid="metric-commission"`) с суммой удержаний.
- [ ] Если хотя бы одна сделка периода посчитана по тарифу, заголовок карточки — «Комиссия за период (оценка)».
- [ ] Сумма в карточке равна сумме колонки «Комиссия» журнала сделок за тот же период.
- [ ] «Суммарный P&L» = валовой P&L сделок − «Комиссия за период».

## S8.24 Режим сделки в отчёте 3-НДФЛ (S8R, 2026-08-04)

Добавлено по итогам `S8R-TAX-SANDBOX-IN-DECLARATION` (Q3=b) и
`S8R-TAX-PNL-LOSES-LOT-SIZE` (Q1).

- [ ] Выгрузка 3-НДФЛ (xlsx и csv) содержит колонку «Режим» со значением «песочница» либо «реальный счёт».
- [ ] Если в отчёте есть sandbox-строки, ниже таблицы напечатано примечание о том, что деньги в песочнице виртуальные и такие строки не подлежат декларированию.
- [ ] Колонка количества называется «Кол-во, шт» и содержит количество в ШТУКАХ (лоты × размер лота), а не в лотах.
- [ ] Для инструмента с размером лота 10 финансовый результат строки совпадает с P&L сделки из журнала за вычетом её комиссии.
- [ ] Сумма колонок «Комиссия (вход)» и «Комиссия (выход)» строки в точности равна комиссии сделки в журнале (без расхождения в копейку).

## S8.25 Закрытие по SL/TP доходит до брокера (S8R, 2026-08-05)

Добавлено по итогам `S8R-SLTP-SANDBOX-NO-BROKER-ORDER` (Q1=a). До этого
срабатывание уровня закрывало позицию только в учёте терминала: у брокера она
оставалась открытой, и расходились P&L, число позиций и лимит одновременных
позиций.

- [ ] Sandbox-сессия, стоп сработал: в журнале сделок сделка «Закрыта», а на странице «Счёт» позиции по этому тикеру нет (данные берутся у брокера).
- [ ] Цена выхода в журнале — фактическая цена исполнения у брокера, а не ровно уровень стопа.
- [ ] Комиссия закрытой по стопу sandbox-сделки заполнена; при фактическом удержании брокера показана без знака ≈, при расчёте по тарифу — со знаком ≈.
- [ ] Комиссия выхода начислена **один раз** (сумма колонки «Комиссия» = вход + выход, не больше).
- [ ] Вне торговых часов MOEX сделка со сработавшим уровнем остаётся открытой (статус не меняется), P&L не выставляется.
- [ ] При отказе брокера приходит уведомление «автозакрытие … не выполнено, позиция остаётся открытой», а сделка в журнале остаётся открытой.
- [ ] Paper-сессия: закрытие по SL/TP работает как раньше, средства возвращаются в бумажный портфель.

## S8.26 Повторное закрытие одной сделки (S8R, 2026-08-05)

Добавлено по итогам `S8R-CLOSE-POSITION-NO-LOCK` (Q2=a).

- [ ] Двойной клик по «Закрыть» в карточке позиции: закрытие происходит один раз, второй запрос отвечает понятной ошибкой «Невозможно закрыть сделку со статусом closed».
- [ ] После двойного клика в журнале ровно одна закрытая сделка, а не две записи и не двойная комиссия.
- [ ] Paper: баланс портфеля после двойного клика вырос на одну выручку, а не на две.
- [ ] «Закрыть все» при нескольких открытых позициях закрывает каждую ровно один раз (число закрытых = числу бывших открытых).

## S8.27 Уведомление о закрытии сделки (S8R, 2026-08-05)

Добавлено по итогам `S8R-TELEGRAM-TRADE-CLOSED-GROSS-PNL` (Q3=a).

- [ ] Уведомление «Сделка закрыта» (Telegram и центр уведомлений) показывает **чистый** результат — P&L за вычетом комиссии.
- [ ] В том же уведомлении комиссия показана отдельной величиной.
- [ ] Если комиссия рассчитана по тарифу, а не удержана брокером, в тексте есть пометка «(оценка)».
- [ ] В тексте уведомления нет незаполненных плейсхолдеров вида `{net_pnl}`.

| S8.20 Комиссия в paper | 6 | S8R-PAPER-NO-COMMISSION |
| S8.21 Метрика полного окна | 3 | S8R-METRIC-SIGNAL-TO-ORDER-BLIND |
| S8.22 Комиссия sandbox/real и тариф | 7 | S8R-SANDBOX-REAL-COMMISSION-NOT-RECORDED, S8R-PAPER-COMMISSION-BROKER-RATE |
| S8.23 Комиссия за период | 4 | Q6, решение заказчика 2026-08-04 |
| S8.24 Режим сделки в 3-НДФЛ | 5 | S8R-TAX-SANDBOX-IN-DECLARATION, S8R-TAX-PNL-LOSES-LOT-SIZE |
| S8.25 SL/TP доходит до брокера | 7 | S8R-SLTP-SANDBOX-NO-BROKER-ORDER |
| S8.26 Повторное закрытие сделки | 4 | S8R-CLOSE-POSITION-NO-LOCK |
| S8.27 Уведомление о закрытии сделки | 4 | S8R-TELEGRAM-TRADE-CLOSED-GROSS-PNL |
| **Итого S8 (новых пунктов)** | **189** | |

**Расширение S7 базы:** 136 новых пунктов > требуемых 50. Можно дополнить дополнительными edge-cases по факту QA-прогона в 8.R.
