# UI-чеклист Sprint 7

> Расширяет `ui_checklist_s5r.md` — все проверки оттуда продолжают применяться.
> Применяется при приёмке S7 и QA-прогонах перед Sprint 8.
> Источник истины: 6 UX-макетов в `Спринты/Sprint_7/ux/` + отчёты W1+W2 (см. `Спринты/Sprint_7/reports/UX_W3_polish.md`).

## 7.7 Дашборд-виджеты (Главная)

- [ ] `/dashboard` (= маршрут «Главная») рендерит 3 виджета через `<SimpleGrid cols={{base:1,sm:2,lg:3}}>` ДО таблицы стратегий.
  - Desktop ≥1024 — 3 колонки. Tablet 640–1023 — 2 колонки (Активные позиции уходит на новую строку). Mobile <640 — 1 колонка.
- [ ] **Виджет «Баланс»** — `data-testid="dashboard-widget-balance"`.
  - Большое значение баланса в `₽` (формат `1 234 567 ₽`) — `data-testid="dashboard-balance-value"`.
  - Diff за день (число + %), стрелка вверх (зелёная) или вниз (красная) — `data-testid="dashboard-balance-diff"`.
  - Sparkline (SVG `<MiniSparkline>`, 240×56) — `data-testid="dashboard-balance-sparkline"`. Цвет = green если last≥first, иначе red.
  - States: loading (`<Skeleton>` ×3), empty («Нет данных» + кнопка «Подключить брокера»), error («Не удалось получить баланс» + retry).
  - Ссылка `Открыть счёт →` ведёт на `/account`.
- [ ] **Виджет «Состояние систем» (Health)** — `data-testid="dashboard-widget-health"`.
  - 3 строки светофора: Circuit Breaker, T-Invest, Scheduler — `data-testid="dashboard-health-cb|tinvest|scheduler"`.
  - Цветные точки (Mantine `<Indicator>` 12px) с `aria-label="<system> — <state>"`.
  - При отсутствии расширенных полей backend (`cb_state`/`tinvest_connected`/`scheduler_running`) — yellow + tooltip «нет данных» (graceful degrade).
  - Ссылка «Подробнее в логах →» ведёт на `/notifications` (DELTA: UX макет указывал `/logs`, но `/logs` нет — допустимая адаптация).
  - Polling — 30 сек через `setInterval` (DELTA: UX-макет говорит «WS-обновление», но реально health через REST polling — приемлемо для S7, перевод на WS — S8).
- [ ] **Виджет «Активные позиции»** — `data-testid="dashboard-widget-positions"`.
  - Top-5 сессий с `active_position_lots > 0`, отсортированы по `abs(P&L)` убыв.
  - Каждая строка — `data-testid="dashboard-position-row-{TICKER}"`, клик ведёт на `/chart/{TICKER}`.
  - Колонки: `<TickerLogo>` + ticker, sparkline 60×24 (цвет по знаку P&L), abs P&L (₽), pct P&L (%).
  - States: loading skeleton, empty «Нет активных позиций» + кнопка «К сессиям», error с retry.
  - Ссылка «Все позиции →» ведёт на `/trading`.
  - ⚠️ Известное ограничение: Sparkline 24h в строке передан с `data: []` (нет endpoint OHLCV для виджета) — рендерится пустой SVG. План на S8: подключить мини-OHLCV.

## 7.8 First-run wizard (Onboarding)

- [ ] При логине пользователя с `wizard_completed_at IS NULL` поверх любой страницы (внутри `<ProtectedRoute>`) рендерится `<Modal fullScreen>` `data-testid="wizard-modal"`.
- [ ] Модалка не закрывается ни Esc, ни клик вне (`closeOnEscape={false}`, `closeOnClickOutside={false}`, `withCloseButton={false}`).
- [ ] `<Stepper active={step}>` `data-testid="wizard-stepper"` с 5 шагами: Старт / Риски / Брокер / Уведомления / Финиш.
- [ ] **Шаг 1 «Старт»** — `data-testid="wizard-step-1"`.
  - Иконка `IconShieldCheck`, заголовок «Добро пожаловать», текст приветствия.
- [ ] **Шаг 2 «Риски»** — `data-testid="wizard-step-2"`.
  - `<ScrollArea h={320}>` с дисклеймером.
  - Чекбокс `data-testid="wizard-disclaimer-checkbox"` (required).
  - Кнопка `Далее` `data-testid="wizard-button-next"` **disabled** до галки.
- [ ] **Шаг 3 «Брокер»** — `data-testid="wizard-step-3"`.
  - `<Select>` Брокер = T-Invest (disabled).
  - `<Radio.Group>` Режим: paper (default) / real — `data-testid="wizard-mode-paper|real"`.
  - При выборе `real` — Alert с подсказкой о настройке токена в `/settings`.
- [ ] **Шаг 4 «Уведомления»** — `data-testid="wizard-step-4"`.
  - Telegram-чекбокс + (при включении) Bot token (`PasswordInput`, `data-testid="wizard-telegram-token"`) + Chat ID (`data-testid="wizard-telegram-chatid"`).
  - Email-чекбокс + email-input (валидация — кнопка `Далее` disabled при невалидном email).
  - In-app — checked + disabled (нельзя отключить).
  - ⚠️ Отсутствует кнопка «Проверить подключение» Telegram (UX-макет требует `data-testid="wizard-telegram-test"`) — S8 backlog.
- [ ] **Шаг 5 «Финиш»** — `data-testid="wizard-step-5"`.
  - Иконка `IconCheck`, summary настроек, кнопка `data-testid="wizard-button-finish"`.
  - На клик: `POST /api/v1/users/me/wizard/complete` (контракт C6) → toast «Настройка завершена» → модалка закрывается, главная доступна.
  - Кнопка `disabled` пока submit идёт (`loading` state).
- [ ] Кнопки «Назад» `data-testid="wizard-button-back"` всегда доступна (кроме шага 1).
- [ ] После успешного `POST /wizard/complete` повторный логин не показывает wizard (проверка `wizard_completed_at != null`).

## 7.6 Drawing tools на графике

- [ ] На `/chart/:ticker` слева от графика — вертикальный тулбар 48px, `data-testid="chart-toolbar"`, `role="toolbar"`, `aria-label="Инструменты рисования на графике"`.
- [ ] **9 кнопок** (`data-testid` совпадают с UX §11):
  - `chart-tool-cursor` (V), `chart-tool-trendline` (T), `chart-tool-hline` (H), `chart-tool-vline` (без hotkey), `chart-tool-rect` (R), `chart-tool-label` (L) — выбор инструмента.
  - `chart-tool-edit` — открыть `<Modal data-testid="chart-drawings-editor">` со списком текущих рисунков.
  - `chart-tool-delete` — disabled пока ничего не выделено; удаляет выделенное.
  - `chart-tool-clear` — disabled при `items.length === 0`; открывает `<Modal data-testid="chart-clear-confirm">` для подтверждения.
- [ ] Активный инструмент — `<ActionIcon variant="filled" color="blue" aria-pressed="true">`.
- [ ] **Hotkeys** работают через `window.keydown` listener; игнорируются при фокусе в `INPUT`/`TEXTAREA`/`contentEditable`:
  - V → cursor; T → trendline; H → hline; R → rect; L → label.
  - Esc → tool=cursor + selectedId=null (отмена preview + снятие выбора).
  - Delete / Backspace → удалить выделенное (если есть).
- [ ] **Persist:**
  - Источник истины — backend `/api/v1/charts/{ticker}/{tf}/drawings` (mini-CRUD добавлен в fix-волне fix W2). 
  - При 4xx/5xx ошибке — fallback на `localStorage[drawings:{userId}:{ticker}:{tf}]` с лимитом 100 рисунков (квота `QuotaExceededError` → toast «Слишком много рисунков»).
- [ ] При смене ticker / timeframe — `setDrawingsContext(userId, ticker, tf)` подгружает рисунки нового ключа; cleanup старых (в `DrawingsLayer`).
- [ ] При unmount `DrawingsLayer` — `removeChild(canvas)`, `removePriceLine` для всех hline, `unsubscribeClick/Crosshair/VisibleTimeRange`, `ResizeObserver.disconnect()`.
- [ ] **Stack Gotcha (новая)**: координаты overlay-canvas конвертируются с учётом `MSK_OFFSET_SEC` (в lightweight-charts оси UTC, MSK имитируется сдвигом данных). Проверка: trendline/rect не «уезжают» при zoom/pan и правильно ложатся на свечи.
- [ ] ⚠️ Известные ограничения (S7 PHASE1):
  - Drag/перенос/изменение углов выделенной фигуры не реализованы — UX §4 «editing(drag)». Долг.
  - Sequential mode (intraday TF: 1m/5m/15m/1h/4h) — неточная конверсия time→x. Долг.

## 7.16 Аналитика бэктеста — гистограмма + donut + интерактивные зоны

- [ ] `/backtests/{id}` имеет 4 вкладки: Обзор / График / Показатели / Сделки. Вкладка **Обзор** активна по умолчанию (`defaultValue="overview"`).
  - `data-testid` на вкладках: `tab-overview`, `tab-chart`, `tab-indicators`, `tab-trades`.
  - Контент — `data-testid="backtest-overview-tab"`.
- [ ] **Гистограмма «Распределение P&L»** — `data-testid="pnl-histogram"`.
  - Бакеты по 0.5% (политика `[low, high)` — нижняя граница включительно), минимум 6.
  - Цвета: red-6 для loss, green-6 для profit, yellow-5 для BE (центр в `[-0.05%, +0.05%]`).
  - Каждый bar — `data-testid="pnl-histogram-bar-{i}"`, `role="img"`, `aria-label`/`title` с количеством сделок и Σ P&L.
  - Пунктирные средние линии: `pnl-histogram-avg-loss-line`, `pnl-histogram-avg-profit-line` + текстовые подписи `pnl-histogram-avg-loss|profit` («Ср. убыток: -1.2%», «Ср. прибыль: +1.8%»).
  - Decimal precision: `Number(t.pnl_pct ?? 0)` — backend Decimal-как-строка (Gotcha S5R).
  - Empty state: `<IconChartBar>` + «Нет сделок для анализа».
- [ ] **Donut «Win/Loss/BE»** — `data-testid="win-loss-donut"`.
  - 3 сегмента: green-6 / red-6 / yellow-5 — `data-testid="win-loss-donut-wins|losses|be"`.
  - В центре `data-testid="win-loss-donut-total"` — общее число сделок.
  - Легенда справа с количеством и %.
  - ⚠️ DELTA: `data-testid` UX-макета — `backtest-pnl-histogram` / `backtest-winloss-donut`; в коде — `pnl-histogram` / `win-loss-donut`. E2E-спеки используют код. Документировать в `e2e_test_plan_s7.md`.
- [ ] **Интерактивные зоны на ценовом графике** (`InstrumentChart`) — `data-testid="instrument-chart"`.
  - Hover на зоне трейда → подсветка (alpha 0.18 → 0.40 + белый контур 1px), курсор `pointer`.
  - Click на зоне → `<TradeDetailsPanel>` `data-testid="trade-detail-panel"` с полями entry/exit (time, price, reason, pnl, duration).
  - `data-testid` в панели: `trade-detail-entry-time|entry-price`, `backtest-trade-detail-entry-reason`, `trade-detail-exit-time|exit-price`, `backtest-trade-detail-exit-reason`, `trade-detail-pnl`, `trade-detail-duration`, `trade-detail-jump-to-candle`, `trade-detail-panel-close`.
  - При отсутствии `entry_reason`/`exit_reason` в trade — рендер «—» (graceful degrade — backend поле опциональное).
  - Esc / × закрывает панель.
  - ⚠️ DELTA: UX макет требует `data-testid="backtest-trade-zone-{trade_id}"` на зоне. В реализации зоны нарисованы на canvas без отдельного DOM-элемента. Hover/click обрабатываются через `findZoneAt(clientX)` на контейнере. Тестируем через клик по координатам или через mock-store.
- [ ] При смене бэктеста (другой `id`) — cleanup графика без утечек lightweight-charts (`chart.remove()`, отписка от listeners, удаление bgCanvas).

## 7.17 Бейдж фоновых бэктестов в шапке

- [ ] **Кнопка «Запустить в фоне»** в `BacktestLaunchModal` — `data-testid="backtest-launch-button-background"`. Рядом — primary `data-testid="launch-button"` («Запустить»).
- [ ] При клике «в фоне»: POST `/api/v1/backtest` → push в `backgroundBacktestsStore` (Zustand+persist) → toast «Бэктест запущен в фоне». **Модалка НЕ закрывается** — параметры можно поменять и запустить ещё.
- [ ] **Бейдж в шапке** — `<Indicator>` `data-testid="bg-backtest-badge"`, кнопка `data-testid="bg-backtest-badge-btn"`.
  - При `count === 0` — Indicator disabled (бейдж скрыт).
  - Цвет приоритетом: red (есть errors) → green (есть done) → blue (running). 
  - Hover — tooltip «N бэктестов в фоне» / «N в фоне, M ошибок».
  - ⚠️ DELTA: UX-макет требует `data-testid="header-bg-backtests-badge"`. В коде — `bg-backtest-badge`. Документировано в DEV-3 W1, e2e использует код.
- [ ] Click → `<Popover>` `data-testid="bg-backtest-popover"` со списком.
  - Каждая строка — `data-testid="bg-backtest-row-{job_id}"`:
    - Имя стратегии · ticker · timeframe + chip статуса (queued/running/done/error/cancelled).
    - Прогресс-бар `data-testid="bg-backtest-progress-{job_id}"` (`role="progressbar"`).
    - Для `running` — кнопка cancel `data-testid="bg-backtest-cancel-{job_id}"`.
    - Для `done` — кнопка `data-testid="bg-backtest-open-{job_id}"` «Открыть результат» → navigate `/backtests/{result_id}`.
    - Для `error` — текст ошибки `data-testid="bg-backtest-error-{job_id}"`.
- [ ] Кнопка `data-testid="bg-backtest-clear-completed"` появляется при `done.length + error.length > 0` — удаляет завершённые из store.
- [ ] **Cap = 3** (`MAX_CONCURRENT_BACKGROUND_BACKTESTS = 3`, согласовано с ARCH §5). При попытке запустить 4-й — backend 429, frontend показывает toast.
- [ ] При reload страницы — `useBackgroundBacktestsBootstrap` восстанавливает подписки на все `running` jobs.
- [ ] При logout — `authStore.logout()` очищает `backgroundBacktestsStore` + `localStorage.removeItem('background-backtests')`.

## 7.19 AI слэш-команды dropdown

- [ ] В `<ChatInput>` (`/ai/chat` или AI-панель в редакторе стратегии) — textarea `data-testid="chat-input"`.
- [ ] При вводе `/` в начале строки или после whitespace — открывается `<Combobox>` dropdown `data-testid="ai-chat-slash-popover"`.
  - 5 опций: `/chart`, `/backtest`, `/strategy`, `/session`, `/portfolio` — `data-testid="ai-chat-slash-option-{cmd}"`.
  - Каждая опция показывает имя + описание + пример.
  - Фильтрация по префиксу: `/cha` оставляет только `/chart`.
  - Empty state — `data-testid="ai-chat-slash-popover-empty"`.
- [ ] **IME composition guard**: dropdown НЕ открывается во время русского ввода с диакритикой (`compositionstart` / `compositionend`).
- [ ] Клавиатурная навигация: ↑/↓ / Enter / Tab / Esc — стандартная Mantine `useCombobox`.
- [ ] **Парсер** (`parseCommand`) распознаёт 5 команд:
  - `/chart TICKER [TF]` — TICKER обязателен, TF опционален; невалидный TICKER → весь сегмент в `remainder`.
  - `/backtest ID` / `/strategy ID` / `/session ID` — ID = positive int.
  - `/portfolio` — без аргументов.
  - Множественный контекст в одном сообщении: `/chart SBER /backtest 42 ...` → 2 chip + остальной текст.
- [ ] **Контекстный chip** в сообщении пользователя — `data-testid="ai-chat-message-chip-{type}-{id}"`.
  - Mantine `<Badge variant="light">` + Tabler icon по типу.
  - Кликабельный → react-router navigate: `/chart/{ticker}`, `/backtests/{id}`, `/strategies/{id}`, `/trading/sessions/{id}`, `/portfolio` (или `/account`).
  - Статусы: `ok` (default), `forbidden` (красный, tooltip «Нет доступа»), `not_found` (серый, tooltip «Не найдено»).
- [ ] Render `[CONTEXT type=... id=...]\n...\n[/CONTEXT]\n` блока в **assistant-ответе** → collapsible «Контекст» (defense-in-depth от echo).
- [ ] При отправке — `context_items: ChatContextItem[]` уходит в `POST /api/v1/ai/chat` (контракт C3, поле параллельно с legacy `context: dict`).

## 7.1 Versioning UI стратегий

- [ ] На `StrategyEditPage` кнопка **«История»** открывает `<Drawer position="right">` со списком версий (контракт C4: `GET /strategy/{id}/versions/list`).
- [ ] Каждая строка — версия с тремя действиями: Просмотреть / Diff / Restore.
  - Diff — собственный line-by-line компонент (без новых зависимостей), сравнивает текущую версию с выбранной.
  - Restore — Mantine `modals.openConfirmModal` с подтверждением → `POST /versions/{ver_id}/restore`.
- [ ] Кнопка «Сохранить именованную версию» открывает форму ввода `comment` → `POST /versions/snapshot {comment}`.
- [ ] Бейдж «текущая» на head-версии.
- [ ] При успешном restore — toast + рефетч стратегии.

## 7.2 Grid Search UI

- [ ] На `StrategyEditPage` кнопка **«Grid Search»** открывает `<GridSearchModal>` с формой `<GridSearchForm>`.
- [ ] Динамический список параметров (1–5): для каждого — name, values (CSV или массив).
- [ ] **Real-time `total = product(len(values))`** с цветовым feedback:
  - ≤200 — green;
  - 201–1000 — yellow;
  - >1000 — red, кнопка submit **disabled** (с подсказкой «Слишком много комбинаций»).
- [ ] POST `/api/v1/backtest/grid` (контракт C5) → push в `backgroundBacktestsStore` от FRONT1 → подписка на WS C2.
- [ ] **Heatmap** `<GridSearchHeatmap>` поддерживает 3 режима:
  - 1 параметр → bar chart.
  - 2 параметра → 2D heatmap (Mantine).
  - 3+ параметров → sortable table с колонками params + metric.
- [ ] ⚠️ **PARTIALLY CONNECTED**: `GridSearchHeatmap` написан и unit-тестирован, но точка вызова из BackgroundBacktestsBadge / отдельной страницы результата grid job отсутствует. Открытый вопрос W2 №6 — на 7.R / S8.

## 7.15 WS карточки сессий (без polling)

- [ ] `/trading` рендерит активные сессии через `useTradingSessionsWS` (контракт C1) — без `setInterval`.
- [ ] `grep -rn "setInterval.*sessions\|setInterval.*fetchSessions" src/` → **0** (polling удалён).
- [ ] **Auth первым сообщением** WS: `{action: 'auth', token}` → ответ `{type: 'auth_ok'}` → snapshot/delta события (Stack Gotcha #16: токен НЕ в URL).
- [ ] Badge статуса соединения в шапке/панели сессий: `online` (зелёный) / `reconnecting` (yellow) / `auth_error` (red).
- [ ] Exponential backoff reconnect (1s → 2s → 4s → ... cap 30s).
- [ ] Ping/pong heartbeat (30s).
- [ ] Cleanup при unmount: `socket.close()`, `clearInterval(ping)`.

## Общие проверки за S7

- [ ] **vitest:** `pnpm test --run` → ≥394 passed / 0 failed (S7 baseline после W2 sub-wave 2).
- [ ] **TypeScript:** `npx tsc --noEmit` → 0 errors.
- [ ] **Lint:** новые файлы S7 без ошибок. Известные 6/10 pre-existing baseline ошибок (W2 sub-wave 1/2) — задача 7.R fix.
- [ ] **Playwright e2e baseline 119:** не падает (запуск в задаче 7.11). Скриншоты `s7-7.6-*` (8), `s7-7.7-dashboard.png`, `s7-7.8-wizard-step1|2-disclaimer.png`, `s7-7.1-versions-drawer.png`, `s7-7.2-grid-search.png`, `s7-7.19-*` (5) присутствуют в `Develop/frontend/e2e/screenshots/s7/`.
- [ ] **Dark theme контраст:** все цветные индикаторы (green/red/yellow) проходят ≥4.5:1 на тёмной теме.
- [ ] **a11y:** `role="article|toolbar|dialog|progressbar|combobox|option|img"` + `aria-label` / `aria-pressed` / `aria-required` / `aria-disabled` / `aria-current="step"` корректно расставлены.
- [ ] **Известные deltas с UX-макетами** — задокументированы в `Спринты/Sprint_7/reports/UX_W3_polish.md` секция 2 + переданы на 7.R fix-волну (секция 6 отчёта).
