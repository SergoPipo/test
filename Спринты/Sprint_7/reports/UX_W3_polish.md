---
sprint: 7
agent: UX
wave: 3
phase: 7.10 polish
date: 2026-04-26
---

# UX W3 — финальная полировка 7.10

## 1. Метод аудита

Сверка 6 UX-макетов W0 (`Спринты/Sprint_7/ux/*.md`) с фактической реализацией фронта по матрице:

| Макет | Код фронта (зона аудита) |
|-------|--------------------------|
| `dashboard_widgets.md` (7.7) | `pages/DashboardPage.tsx`, `components/dashboard/{Balance,Health,ActivePositions}Widget.tsx` |
| `wizard_5steps.md` (7.8) | `components/wizard/{FirstRunWizard,FirstRunWizardGate}.tsx`, `App.tsx` |
| `drawing_tools.md` (7.6) | `components/charts/{DrawingToolbar,DrawingsLayer,MiniSparkline}.tsx`, `pages/ChartPage.tsx`, `stores/chartDrawingsStore.ts`, `api/chartDrawingsApi.ts` |
| `backtest_overview_analytics.md` (7.16) | `components/backtest/{PnLDistributionHistogram,WinLossDonutChart,TradeDetailsPanel,InstrumentChart}.tsx`, `pages/BacktestResultsPage.tsx` |
| `background_backtest_badge.md` (7.17) | `components/notifications/BackgroundBacktestsBadge.tsx`, `components/backtest/BacktestLaunchModal.tsx`, `stores/backgroundBacktestsStore.ts` |
| `ai_commands_dropdown.md` (7.18/7.19) | `components/ai/{ChatInput,CommandsDropdown,ContextChip,parseCommand,AIChat}.tsx`, `api/aiApi.ts` |

Источники сравнения: дословные требования макетов (секции «layout», «states», «контракты», «data-testid»), 4 отчёта DEV (`DEV-3_FRONT1_W1`, `_W2_PHASE1`, `_W2_PHASE2`, `DEV-4_FRONT2_W2`), `sprint_state.md`, 18 готовых скриншотов в `Develop/frontend/e2e/screenshots/s7/`.

## 2. Deltas по макетам

**7.7 Dashboard widgets** — соответствие 95%.
- `data-testid` дашборда (UX §11) — все на месте (`dashboard-widget-{balance,health,positions}`, `dashboard-balance-{value,diff,sparkline}`, `dashboard-health-{cb,tinvest,scheduler}`, `dashboard-position-row-{ticker}`).
- ⚠️ **medium**: `ActivePositionsWidget` рендерит sparkline 60×24 с **пустым массивом** `data: []` — нет endpoint OHLCV для виджета. UX §5 показывает реальные мини-графики 24h. **Рекомендация 7.R / S8**: подключить лёгкий `/api/v1/market/{ticker}/sparkline?hours=24` или переиспользовать кэш свечей.
- ⚠️ **low**: `HealthWidget` ссылается на `/notifications` вместо `/logs` (UX §4 требует `/logs`); подходит как разумная адаптация (`/logs` страницы нет).
- ⚠️ **low**: Health полирует через `setInterval(30s)` REST polling, UX §7 требует «WS-обновление». Не критично для S7, перенос на WS — S8.
- ⚠️ **low**: тогглер валют RUB/USD/EUR (UX §3) не реализован — backend возвращает только RUB.

**7.8 First-run wizard** — соответствие 95%.
- Все 5 шагов, gate на шаге 2, Esc/click outside заблокированы — ✅. `data-testid` контракт UX §11 совпадает 1:1.
- ⚠️ **medium**: на шаге 4 отсутствует кнопка **«Проверить подключение»** Telegram (UX §6, `data-testid="wizard-telegram-test"`). Backend endpoint `POST /notifications/telegram/test` не реализован, frontend кнопку скипнул.  **Рекомендация S8**: реализовать smoke-test bot_token/chat_id.
- ⚠️ **low**: `Stepper` без `aria-current="step"` явно (UX §10) — Mantine добавляет автоматически, но стоит проверить QA-снимком.
- ⚠️ **low**: refresh страницы во время wizard — gate ререндерит шаг 1 (UX §11.7 — корректно).

**7.6 Drawing tools** — соответствие 80%.
- Тулбар 48px вертикальный слева, 9 кнопок (cursor/trendline/hline/vline/rect/label/edit/delete/clear), hotkeys V/T/H/R/L/Esc/Delete, ARIA (toolbar/aria-pressed/aria-label) — ✅.
- Backend mini-CRUD `/api/v1/charts/...` добавлен в fix-волне W2; persist работает через REST + localStorage fallback.
- ⚠️ **high**: **drag/перенос/изменение углов выделенной фигуры не реализованы** (UX §4 «editing» state). PHASE1 ограничен; нужен hit-test на canvas. **Рекомендация 7.R**: либо реализовать в FRONT1 PHASE3, либо явно скипнуть и записать долгом в S8.
- ⚠️ **medium**: **sequential mode (intraday TF: 1m/5m/15m/1h/4h)** — координатная конверсия time→x неточна (Stack Gotcha кандидат от FRONT1: `MSK_OFFSET_SEC` + sequentialIndex несинхронизированы). Drawings в intraday могут «уезжать». 7.R fix.
- ⚠️ **low**: tooltip-подсказка «Выберите инструмент» при первом визите (UX §4 «empty») не реализован — низкий приоритет.

**7.16 Backtest analytics** — соответствие 90%.
- Гистограмма (бакеты 0.5%, цвета red/green/yellow, пунктирные средние, tooltip), donut (3 сегмента + центр + легенда), интерактивные зоны (hover-подсветка → click → `TradeDetailsPanel`) — ✅.
- ⚠️ **medium**: **`data-testid` отличаются от UX §13**:
  - UX: `backtest-pnl-histogram` / `backtest-winloss-donut` → код: `pnl-histogram` / `win-loss-donut`.
  - UX: `backtest-trade-zone-{trade_id}` → зоны рисуются на canvas без DOM-элемента, тестирование через клик-координаты.
  - **Рекомендация**: либо обновить UX-макет (закрепить код), либо добавить алиасы. E2E-спеки используют код — не блокирует тесты.
- ⚠️ **low**: tooltip на bar — нативный `title` (UX §4 рекомендует Mantine `<Tooltip>`). 7.R polish.
- ⚠️ **low**: для скринридеров color-blind safe «диагональные штрихи для loss / точки для profit» при `prefers-contrast: more` (UX §4 a11y) — не реализовано.

**7.17 Background backtest badge** — соответствие 95%.
- Кнопка «в фоне» в модалке + модалка не закрывается, бейдж в шапке с цветом-приоритетом (red→green→blue), popover со списком, прогресс-бары, cancel/open/clear, cap=3, persist через localStorage, restore на reload, cleanup на logout — ✅.
- ⚠️ **low**: `data-testid="header-bg-backtests-badge"` (UX §11) → в коде `bg-backtest-badge` (документировано в DEV-3 W1: Testing Library не поддерживает space-separated testids). Невелика, e2e использует код.
- ⚠️ **low**: `done`-запись остаётся до явного «Очистить завершённые» (UX §5 предлагал auto-collapse через 10s) — текущее поведение допустимо.

**7.19 AI commands dropdown** — соответствие 100%.
- Dropdown по `/`, 5 команд с описанием и примером, фильтрация, IME composition guard, ↑/↓/Enter/Tab/Esc, контекстный chip с навигацией (3 статуса ok/forbidden/not_found), render `[CONTEXT]` блока collapsible, контракт C3 (`context_items` параллельно с legacy `context`) — ✅. `data-testid` 1:1 с UX §11.

## 3. Обновление `ui_checklist_s7.md`

Создан `Спринты/ui_checklist_s7.md` (расширение `ui_checklist_s5r.md`) — 9 секций:
- 7.7 Дашборд-виджеты (3 виджета + общие проверки SimpleGrid).
- 7.8 First-run wizard (5 шагов + gate + lifecycle).
- 7.6 Drawing tools (тулбар + hotkeys + persist + cleanup + Stack Gotcha MSK_OFFSET).
- 7.16 Backtest analytics (histogram + donut + interactive zones + TradeDetailsPanel).
- 7.17 Background backtest badge (cap=3 + popover + bootstrap restore + logout cleanup).
- 7.19 AI commands dropdown (parser + IME guard + chip navigate + render `[CONTEXT]`).
- 7.1 Versioning UI (Drawer + Diff + Restore).
- 7.2 Grid Search UI (real-time total + цветовой feedback + heatmap 3 режима).
- 7.15 WS sessions (без polling, auth-first, badge статуса).
- Общие: vitest≥394, tsc 0, lint новых файлов 0, 18 скриншотов, dark theme контраст, a11y.

Все известные deltas (s7) задокументированы прямо в чеклисте `⚠️` пометками.

## 4. Скриншот-сравнение

Прошёл 3 ключевых скриншота:
- `s7-7.7-dashboard.png` — соответствует §6 UX-макета (3 виджета, sparkline зелёный в Balance, Health «нет данных» yellow корректно как graceful degrade, ActivePositions с 2 строками SBER/GAZP — но без sparkline 24h, как и описано delta).
- `s7-7.6-toolbar-default.png` — вертикальный 48px тулбар слева, 9 иконок в правильном порядке, активный cursor подсвечен, разделитель между tools и edit/delete/clear — ✅.
- `s7-7.19-dropdown-open.png` — 5 команд в dropdown с описанием и примером, hover-подсветка `/chart`, input `/` внизу — ✅ 1:1 с UX §3.

## 5. Открытые вопросы W2

| # | Вопрос | Статус |
|---|--------|--------|
| 6 | `GridSearchHeatmap` готов, точка вызова из badge не подключена | ⚠️ PARTIALLY CONNECTED |
| 7 | gotcha-22 кандидат: Mantine `Combobox.Target.cloneElement` testid clone | ⚠️ Кандидат, ARCH в 7.R |
| 8 | Pre-existing 6 frontend lint errors | ⚠️ Известная, фикс на 7.R |
| 9 | Полный E2E baseline 119 не прогонялся в W2 sub-wave 2 | ⚠️ QA-агент сейчас прогоняет в 7.11 |
| 10 | Real-mode coverage `test_order_manager` отсутствует | ⚠️ Backend, не моя зона |
| 11 | Health/ActivePositions widgets без unit-тестов | ⚠️ FRONT2 не покрыл, 7.R fix |

## 6. Передаётся на 7.R fix-волну (приоритет)

1. **HIGH** — 7.6 drawing tools editing/drag (UX §4) — реализовать или явно скипнуть в S8 backlog.
2. **MEDIUM** — 7.6 sequential mode (intraday TF) координаты — Stack Gotcha кандидат + фикс конверсии.
3. **MEDIUM** — 7.7 ActivePositions sparkline 24h данные (новый endpoint или кэш свечей).
4. **MEDIUM** — 7.8 wizard Telegram test-кнопка + backend `POST /notifications/telegram/test`.
5. **MEDIUM** — 7.16 синхронизация `data-testid` с UX-макетом (либо обновить макет, либо добавить алиасы в код).
6. **MEDIUM** — открытый вопрос #6: подключить `GridSearchHeatmap` к BackgroundBacktestsBadge или отдельной странице результата.
7. **LOW** — 7.7 HealthWidget polling 30s → WS (S8 миграция).
8. **LOW** — 7.16 Mantine `<Tooltip>` на гистограмме вместо native `title`.
9. **LOW** — 7.7 multi-currency toggler RUB/USD/EUR.
10. **LOW** — 7.17 auto-collapse done через 10s.
11. **LOW** — open #11: unit-тесты для `HealthWidget` / `ActivePositionsWidget`.

## 7. Out of scope S7 (на S8)

- 7.6 inner-picker для drawing tools (анкеры с drag, контекстное меню right-click, изменение цвета per-shape).
- 7.16 показ рисунков read-only поверх ценового графика бэктеста.
- 7.19 inner-picker (выбор тикера/бэктеста списком при вводе аргумента).
- BroadcastChannel sync `backgroundBacktestsStore` между табами.
- 7.16 паттерны color-blind safe (`prefers-contrast: more`).
- Sprint 8 ARCH planning.

## 8. Применённые плагины

- **Read** — все 6 UX-макетов, 4 отчёта DEV W1+W2, `ui_checklist_s5r.md`, `sprint_state.md`, основные .tsx/.ts файлы фронта (DashboardPage, BalanceWidget, HealthWidget, ActivePositionsWidget, FirstRunWizard, DrawingToolbar, PnLDistributionHistogram + grep по InstrumentChart/CommandsDropdown/ContextChip).
- **Bash + grep** — поиск `data-testid`, integration points, наличие endpoints (backend `/api/v1/charts`), cap=3 в store, отсутствие polling.
- **Read скриншотов** — 3 ключевых PNG из `e2e/screenshots/s7/` для визуального сравнения с ASCII-mockup'ами.
- **context7 / playwright / frontend-design / typescript-lsp / pyright-lsp** — НЕ вызывались (UX-аудит read-only, без правок кода и без новых компонентов).

Соответствует политике: UX W3 = read-only по коду, write только в `Спринты/Sprint_7/ui_checklist_s7.md` + `reports/UX_W3_polish.md` + `Sprint_7/changelog.md`.
