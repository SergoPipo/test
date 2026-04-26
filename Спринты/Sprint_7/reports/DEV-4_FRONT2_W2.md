---
sprint: 7
agent: DEV-4 (FRONT2)
wave: W2 sub-wave 2
date: 2026-04-26
status: completed
---

# DEV-4 FRONT2 W2 — отчёт

## 1. Реализовано (4 задачи)

- **7.7 Dashboard widgets:** на `/dashboard` подключены три карточки в
  `<SimpleGrid cols={{base:1,sm:2,lg:3}}>`. BalanceWidget читает
  C9 `/account/balance/history?days=30` и рендерит value, %-diff, sparkline
  (через MiniSparkline от FRONT1). HealthWidget использует `/health` с
  graceful degrade (yellow «нет данных» при отсутствии расширенных полей —
  backend пока возвращает только status/version/database). ActivePositionsWidget
  показывает top-5 сессий из `/trading/sessions?status=active`, sortable
  по abs(P&L), переход по клику на `/chart/{ticker}`.
- **7.8-fe FirstRunWizard:** Mantine `<Modal fullScreen>` + `<Stepper>` 5
  шагов. Шаг 2 — gate-checkbox, шаг 3 — paper/real radio, шаг 4 — Telegram/
  Email/in-app, шаг 5 — POST C6. Esc/click outside заблокированы.
  `FirstRunWizardGate` монтируется в App.tsx внутри ProtectedRoute и
  читает `wizard_completed_at` из `/users/me`.
- **7.1-fe VersionsHistoryDrawer:** на StrategyEditPage кнопка «История»
  открывает Drawer с `/strategy/{id}/versions/list`; per-row Просмотреть/
  Diff/Restore. Diff — собственный line-by-line (без новых зависимостей).
  Restore — confirm-modal → POST `/versions/{ver_id}/restore`. Также
  «Сохранить именованную версию» через `/versions/snapshot {comment}`.
- **7.2-fe GridSearchForm + GridSearchHeatmap:** модалка с динамическим
  списком параметров (1–5), real-time `total = product(len(values))`
  с цветовым feedback (≤200 green / 201–1000 yellow / >1000 red blocked).
  POST C5 `/api/v1/backtest/grid` → push в backgroundBacktestsStore от
  FRONT1 → подписка на WS C2 уже настроена. Heatmap: bar (1 param) /
  2D heatmap (2 params) / sortable table (3+).

## 2. Файлы

**NEW:**
- `src/api/usersApi.ts`
- `src/components/dashboard/{BalanceWidget,HealthWidget,ActivePositionsWidget}.tsx`
- `src/components/wizard/{FirstRunWizard,FirstRunWizardGate}.tsx`
- `src/components/strategy/VersionsHistoryDrawer.tsx`
- `src/components/backtest/{GridSearchForm,GridSearchModal,GridSearchHeatmap}.tsx`
- `src/components/{dashboard,wizard,strategy,backtest}/__tests__/*.test.tsx`
  (4 файла unit-тестов: BalanceWidget, FirstRunWizard, VersionsHistoryDrawer,
  GridSearchForm).
- `e2e/s7-front2.spec.ts`

**MOD:**
- `src/api/accountApi.ts` (+`getBalanceHistory`, +`BalanceHistoryPoint`)
- `src/api/strategyApi.ts` (+versions endpoints + types)
- `src/api/backtestApi.ts` (+`startGridSearch` + Grid types)
- `src/pages/DashboardPage.tsx` (3 виджета через SimpleGrid)
- `src/pages/StrategyEditPage.tsx` (кнопки «История» / «Grid Search» + 2 модалки)
- `src/App.tsx` (`<FirstRunWizardGate />` внутри ProtectedRoute)
- `Спринты/Sprint_7/changelog.md`

## 3. Тесты

- **vitest:** `pnpm test` → **394 passed / 0 failed** (baseline 357 → +37
  кумулятивно за W2 sub-wave 2). Из них от меня: 4 BalanceWidget +
  4 FirstRunWizard + 5 VersionsHistoryDrawer + 12 GridSearchForm = **25 новых**.
- **tsc:** `npx tsc --noEmit` → **0 errors**.
- **playwright:** `npx playwright test e2e/s7-front2.spec.ts` → **4/4 passed**
  за 3.0s. 6 скриншотов сохранены в `e2e/screenshots/s7/`.

## 4. Integration points

`grep -rn` в `src/`:
- `BalanceWidget` / `HealthWidget` / `ActivePositionsWidget` — импортируются
  и инстанциируются в `src/pages/DashboardPage.tsx:20-22, 173-175`.
- `FirstRunWizardGate` — `src/App.tsx:22, 43` (внутри `<ProtectedRoute>`).
- `VersionsHistoryDrawer` — `src/pages/StrategyEditPage.tsx:29, 685`.
- `GridSearchModal` — `src/pages/StrategyEditPage.tsx:30, 695`.
- `GridSearchForm` — внутри `GridSearchModal`. `GridSearchHeatmap` —
  готовый компонент для отображения final result.matrix (вызывается
  потребителем при состоянии job=`done`; в badge от FRONT1 будет
  кликабельная карточка). ⚠️ **PARTIALLY CONNECTED:** Heatmap-компонент
  написан и протестирован, но точка вызова из badge / отдельной страницы
  результата пока отсутствует — это перейдёт во FRONT1 W2 sub-wave 3 / S8
  (визуализация finished grid jobs). Кандидат на следующий шаг.

Помеченных `⚠️ NOT CONNECTED` других сущностей нет.

## 5. Контракты (как потребитель)

- **C4 versioning** (BACK2): URL фактически использован 1:1 с backend
  `app/strategy/router.py:163-275`: `/strategy/{id}/versions/list`,
  `/versions/by-id/{ver_id}`, `/versions/snapshot`, `/versions/{ver_id}/restore`.
  Response shape `VersionListItem[]` совпадает с `VersionListItem`
  Pydantic-схемой backend.
- **C5 grid** (BACK1): `POST /api/v1/backtest/grid` body
  `{strategy_id, strategy_version_id, ticker, timeframe, date_from,
  date_to, initial_capital, ranges}` → `{job_id, total, status:'queued'}`.
  Полностью совпадает с `app/backtest/router.py:1140` и
  `GridSearchRequest`/`GridJobResponse` из `app/backtest/schemas.py`.
- **C6 wizard** (BACK2 fix-волна 2026-04-26): `GET /users/me`
  (UserResponse с `wizard_completed_at`) и `POST /users/me/wizard/complete`.
  Старый `/auth/me/wizard/complete` (404) НЕ используется.
- **C9 balance history** (BACK1): `GET /account/balance/history?days=30` →
  массив `[{ts, total_value, currency:'RUB'}]`. URL и shape совпадают
  с `app/account/router.py:24-46`.

## 6. Координация с FRONT1 (sparkline)

`MiniSparkline.tsx` уже был в репо к началу моей работы (опубликован
FRONT1 в первые минуты W2 sub-wave 2). Использован 1:1 в `BalanceWidget`
(width=240, height=56, color='green'|'red' от направления тренда) и
в `ActivePositionsWidget` (width=60, height=24, плейсхолдер для 24h
цен — пустой массив рендерит безопасно по контракту FRONT1).
Свой sparkline НЕ создавал.

## 7. Применённые Stack Gotchas

- **#16 401 cleanup+guard:** все API-вызовы через `apiClient` (axios
  interceptor + AbortController + 401-cleanup уже работают). Wizard
  Gate сбрасывает `fetchedRef` при `!isAuthenticated` — повторный
  логин снова дёрнет `/users/me`.
- **#20 FastAPI route ordering:** учтено при использовании
  `/versions/by-id/{ver_id}` и `/versions/snapshot` — статические
  сегменты идут первыми (см. backend grep выше).
- **lightweight-charts cleanup:** не применимо, MiniSparkline — чистый
  SVG (без LWC), unmount-cleanup не требуется.
- **Mantine modal lifecycle:** в `FirstRunWizard` все side-effects
  (POST /wizard/complete) — в onClick handler, НЕ в render body.
  В `FirstRunWizardGate` — `useEffect` для fetch, `useRef` для guard
  «один раз на login».

## 8. Новые Stack Gotchas + плагины

**Новых Stack Gotchas НЕ выявлено** в этой волне. Кандидат для будущего
(если повторится): «Mantine `<Drawer>`/`<Modal>` в Playwright — корневой
`Modal-root` div всегда в DOM, но `data-testid` на нём `visibility:hidden`
до открытия → use `getByRole('dialog')` или `getByText(<заголовок>)`».
Это не stack-bug, а тестовый паттерн — формализовать только если упадёт
в нескольких спринтах.

**Плагины:**
- **typescript-lsp fallback** (`npx tsc --noEmit`): после каждого блока
  Edit/Write на .ts/.tsx — 0 errors на финальной проверке.
- **playwright**: 4 скриншот-теста запущены реально (`npx playwright
  test e2e/s7-front2.spec.ts` → 4/4 passed, 3.0s), 6 PNG сохранены.
- **context7**: НЕ вызывался — используемые Mantine паттерны
  (Stepper, Modal, Drawer, SimpleGrid) уже знакомы по предыдущим
  спринтам, новых API не использовал.
- **frontend-design**: НЕ вызывался — UX-макеты от UX-агента уже
  достаточно детальны (ASCII-mockups, data-testid, состояния).
- **code-review**: НЕ вызывался — изменения в фронте, не критический путь.

## Скриншоты

`Develop/frontend/e2e/screenshots/s7/`:
- `s7-7.7-dashboard.png` — дашборд с 3 виджетами (Баланс / Health /
  Активные позиции).
- `s7-7.8-wizard-step1.png` — шаг 1 «Старт» first-run wizard.
- `s7-7.8-wizard-step2-disclaimer.png` — шаг 2 «Риски» с обязательным
  чекбоксом.
- `s7-7.1-versions-drawer.png` — Drawer истории версий с 3 row'ами
  (v1/v2/v3, бейдж «текущая» на v3).
- `s7-7.2-grid-search.png` — модалка Grid Search с динамическим
  списком параметров и счётчиком total.
- (heatmap pictures генерируются позже, когда badge от FRONT1
  обзаведётся ссылкой на finished grid job — `GridSearchHeatmap`
  компонент готов и unit-тестирован.)
