# Sprint 8 — Changelog

> Лог изменений по дням. Обновляется **немедленно** после каждого блока изменений
> (правило памяти `feedback_changelog_immediate.md`).
>
> Формат записи: `## YYYY-MM-DD — короткое название`. Внутри — bullet'ы:
> - **Что:** краткое описание изменения
> - **Файлы:** перечень
> - **Результат:** что работает / что сломалось / тесты

---

## 2026-05-12 — Sprint 8 инициализирован

### Что
Создан scaffold для Sprint 8 (M4 Production-ready):

- `Sprint_8/README.md` — точка входа, 8 целей M4 + источник backlog
- `Sprint_8/sprint_state.md` — текущий шаг, план волн, baseline тестов
- `Sprint_8/preflight_checklist.md` — чек окружения до W0
- `Sprint_8/prompt_ARCH_design.md` — задание для ARCH-агента (W0)
- `Sprint_8/changelog.md` — этот файл

### Источник backlog
`Спринты/Sprint_8_Review/backlog.md` — 25+ карточек:
- 6 e2e missing spec'ов (S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17)
- 11 DEFERRED-S8 из ARCH 7.R
- Post-S7 hotfix-карточки (multiplexer singleton root cause, API paginated audit, ErrorBoundary, dashboard health/sparkline, strategy status UI, CI Node 24, lint warnings)

### Что дальше
1. Заказчик подтверждает старт W0.
2. ARCH-агент запускается с `prompt_ARCH_design.md` → создаёт `arch_design_s8.md`.
3. По итогам W0 — DEV-промпты + QA-промпт + e2e_test_plan_s8.md.

---

## 2026-05-12 — W0 ARCH-design черновик создан

### Что
- Preflight checklist пройден: baseline 1024 backend / 468 frontend / 142 nightly / 9 lint warnings (известный долг)
- Coverage report собран: TOTAL **71%** (цель 80%, gap ≈1140 строк)
- 13 event_type publishers сверены grep'ом (12 в EVENT_MAP — discrepancy)
- Paginated endpoints аудит: 2 endpoint'а с `response_model=PaginatedResponse`
- `arch_design_s8.md` создан (581 строка, 8 секций, 30 карточек × роли × часы × эпики)

### Файлы
- `Sprint_8/arch_design_s8.md` — новый, основной артефакт W0
- `Sprint_8/sprint_state.md` — обновлён («W0 IN-PROGRESS»)

### Что дальше (gate W0 → W1)
Заказчик отвечает на 10 TODO из секции 11 `arch_design_s8.md`:
1. S5R-BLOCKLY-MODE-B — реализовать или удалить?
2. S6R-AICHAT-APPLY-MOCK — дополнить мок или удалить skip?
3. Coverage gate `--cov-fail-under=80` — W3 S8 или S9?
4. Security audit instrument — добавить bandit + safety в CI?
5. Lighthouse CI — подключить в playwright-nightly?
6. Prometheus/Grafana — scope S8 или S9?
7. `s7-backup.spec.ts` — Playwright (child_process) или pytest integration?
8. `s7-events.spec.ts` — реализовать `_test/emit-event` endpoint?
9. 13-й event_type — найти/удалить/добавить?
10. Deployment target — Docker + systemd / Kubernetes / Bare-metal?

После ответов — создание prompt_DEV-1..N.md + prompt_QA.md + e2e_test_plan_s8.md.

---

## 2026-05-12 — W0 ЗАВЕРШЁН, gate W0 → W1 пройден

### Что
Все 10 TODO утверждены заказчиком + введён новый эпик **Admin role + admin panel**:

| TODO | Решение |
|---|---|
| #1 Blockly mode B | Удалить 2 spec'а (фича удалена в S5/S6) |
| #2 AIChat apply mock | Дополнить мок в W2 (~2ч) |
| #3 Coverage gate | Включить `--cov-fail-under=80` в W3 S8 |
| #4 Security tools | `bandit` + `safety` в CI с W1 |
| #5 Lighthouse | Нет, performance вручную |
| #6 Performance mon | structlog + Plotly Dash `/admin/metrics` (W2) |
| #7 backup spec | pytest integration, не Playwright |
| #8 events spec | Mock WS frame из Playwright |
| #9 13/12 event_type | Полная синхронизация UI ↔ EVENT_MAP в W2 (~12ч) |
| #10 Deployment | Docker compose на Mac mini + launchd + Cloudflare Tunnel |
| **NEW** | **Admin role + admin panel в W1 (~11ч)** |

### Findings W0

- **Coverage 71% TOTAL** (12679 строк, 3632 непокрыто) — gap до 80% = ≈1140 строк
- **Critical-path coverage gaps:** `notification/dispatchers.py` 0%, `broker/tinvest/adapter.py` 24%, `backtest/router.py` 25%, `trading/service.py` 51%, `market_data/service.py` 50%, `strategy/service.py` 52%
- **Event type discrepancy:** UI имеет 13, EVENT_MAP 12, расхождение в обе стороны:
  - В UI, но не в backend (5): session_recovered, backtest_completed, daily_stats, corporate_action, price_alert
  - В backend, но не в UI (4): session_started, session_stopped, order_placed, trade_filled
- **Roles model отсутствует:** в `users` таблице нет `is_admin` → admin/user разделение требуется для production (новый эпик)

### Файлы изменены/созданы
- `Sprint_8/arch_design_s8.md` — расширен секциями 11-12 (решения по TODO + готовность к W1)
- `Sprint_8/execution_order.md` — финальная разбивка W1/W2/W3 потоков с новыми эпиками + 9 Cross-DEV contracts
- `Sprint_8/sprint_state.md` — текущий шаг «W0 ЗАВЕРШЁН»

### Что дальше (W1 запускается)
1. ARCH создаёт prompt_DEV-1..N.md (6 ролей), prompt_QA.md, prompt_UX.md, prompt_ARCH_review.md
2. QA создаёт `e2e_test_plan_s8.md` по §5 arch_design
3. Создать ветку `s8/sprint-8` в Develop репо
4. Заказчик подтверждает старт W1 → начало 5 параллельных потоков (A/B/C/D/E/F)

---

## 2026-05-12 — W1 BACK1 (DEV-1) старт: Admin role backend каркас

### Что (Поток F W1)
- Подтверждён baseline `pytest tests/ -q` → **1027 passed / 0 failed** (на 3 теста больше ARCH-baseline 1024, дрейф нормальный).
- Текущий alembic head — `f1a2b3c4d5e6_add_instruments_lot_size_synced_at`.
- Реализован Admin role backend каркас:
  1. **Миграция** `alembic/versions/f3f68784fd5b_add_users_is_admin.py` (autogenerate, batch_alter_table → `users.is_admin BOOLEAN server_default='0' nullable=False`). Прогон up/down/up чистый.
  2. **Модель** `User.is_admin: Mapped[bool]` добавлен в `app/auth/models.py` с дефолтом False + server_default.
  3. **Dependency** `require_admin(user=Depends(get_current_user)) -> User` добавлен в `app/middleware/auth.py` (raises HTTPException 403 если `not user.is_admin`).
  4. **Schema** `UserResponse.is_admin: bool = False` (контракт C-S8-7 для FRONT2) — `/auth/me` теперь содержит `is_admin`.
  5. **Bootstrap** `AuthService.register()`: первый user (`get_user_count() == 0`) получает `is_admin=True` (эквивалент FirstRunWizard policy).
  6. **Router** `app/admin/router.py` (новый mount point с `prefix=/api/v1/admin`, `dependencies=[Depends(require_admin)]`, health-эндпоинт `GET /api/v1/admin/ping`). Зарегистрирован в `app/main.py`.
  7. **CLI** `app/cli/users.py` с подкомандой `grant_admin <username>` (idempotent: уже-админ → exit 0 + сообщение; неизвестный → exit 1 + stderr). Стиль argparse + asyncio.run по аналогии с `app/cli/backup.py`.

### Файлы
- Новые: `alembic/versions/f3f68784fd5b_add_users_is_admin.py`, `app/admin/__init__.py`, `app/admin/router.py`, `app/cli/users.py`.
- Изменены: `app/auth/models.py`, `app/auth/schemas.py`, `app/auth/service.py`, `app/middleware/auth.py`, `app/main.py`.

### Контракты
- **C-S8-7 (поставщик BACK1):** `is_admin: bool` в `User` модели + `/auth/me` ответе. Готово для FRONT2 (useAuthStore, Sidebar, ProtectedAdminRoute).

### Что дальше
- Написать тесты Admin role: `tests/test_admin/test_admin_role.py` (require_admin 403/200), `test_admin_cli.py` (grant_admin), `test_first_run_admin.py` (первый user = admin).
- Затем Coverage P0 `notification/dispatchers.py` 0% → 80%, далее P1 модули.

---

## 2026-05-12 — W1 BACK1 (DEV-1) ЗАВЕРШЕНО

### Admin role tests (14 шт.) — все зелёные

- `tests/test_admin/conftest.py` — фикстуры `db_session`, `regular_user`, `admin_user`, `auth_service`.
- `tests/test_admin/test_admin_role.py` (4) — `require_admin` 403/200; `UserResponse.is_admin` для admin/regular.
- `tests/test_admin/test_admin_cli.py` (7) — grant_admin promotes regular_user; idempotent для админа; unknown user → exit 1; persists в БД; argparse no-subcommand/unknown/missing-username.
- `tests/test_admin/test_first_run_admin.py` (3) — первый user = admin; второй/третий = не-admin.

### Coverage P0 — `app/notification/dispatchers.py` 0% → 100%

- 15 тестов в `tests/test_notification/test_dispatchers.py` — telegram (happy / disabled / no-notifier / no-link / inactive-link / send=False / body=None) + email (happy / disabled / no-notifier / no-email / unknown-user / send=False) + комбинированные.

### Coverage P1 — `app/trading/service.py` 51% → 88%

- 31 тест в `tests/test_trading/test_service_full.py` — start_session error paths (user mismatch, real+sandbox-acc, sandbox+real-acc, unknown broker_account); get_sessions filters (mode+ticker, user_id match/mismatch, pagination); get_session permission; get_positions (empty, unknown, mismatch, with-buy); close_position/all permission; get_trades pagination/filters; dashboard/get_all_positions user-filter; delete_session lifecycle (active raises, stopped succeeds, mismatch, unknown); _get_last_price (cached/none); get_stats edge cases (unknown, only-winning profit_factor=0).

### Coverage P1 deferred — `broker/tinvest/adapter.py` 24% → W2

- Явное deferral по промпту: «Если BACK2 не закончил MULTIPLEXER-SINGLETON — НЕ начинай coverage adapter». Wait BACK2 C-S8-6.

### Финальные метрики

- `pytest tests/ -q` → **1087 passed / 0 failed** (+60 новых vs baseline 1027).
- `ruff check .` → All checks passed.
- `mypy app/admin/ app/cli/users.py app/middleware/auth.py app/auth/` → 0 errors.
- Alembic up/down/up для `f3f68784fd5b_add_users_is_admin` → чисто.

### Контракты
- **C-S8-7 (поставщик BACK1):** ✅ DONE — `is_admin` в `User` + `UserResponse` + `/auth/me` + dependency `require_admin`. Готов потребителю FRONT2.

### Отчёт
- `Sprint_8/reports/DEV-1_W1.md` — 9 секций по шаблону.

### Что дальше
- BACK2 W1 завершает MULTIPLEXER-SINGLETON, FRONT2 потребляет C-S8-7, далее BACK1 W2 берёт tinvest adapter coverage + `@timed_event` + остальные модули P1/P2.

---

## 2026-05-12 — W1 FRONT2 (DEV-4): 8.D.1 paginated audit DONE

### Что
- Аудит paginated endpoints backend (`grep PaginatedResponse` + `items: list`):
  - **Generic `PaginatedResponse{items,total,offset,limit}` (RUNTIME-CRASH RISK):** `/trading/sessions`, `/trading/sessions/{id}/trades` — 2 endpoint'а.
  - **Именованные wrapper'ы:** `StrategyListResponse`, `BalanceHistoryResponse`, `BrokerOperationListResponse`, `InstrumentSearchResponse` — уже типизированы своими shape'ами на фронте.
  - **Скрытый bug:** `accountApi.getBalanceHistory` имел `Promise<BalanceHistoryPoint[]>`, но backend отдаёт `BalanceHistoryResponse{items,...}` → BalanceWidget silently рендерил empty state. Fixed.
- Введены `PaginatedResponse<T>`, `isPaginatedResponse<T>()` type-guard, `unwrapPaginated<T>()` хелпер в `frontend/src/api/types.ts`.
- `tradingApi.getSessions` / `getTrades` теперь возвращают `PaginatedResponse<TradingSession|LiveTrade>`.
- `accountApi.getBalanceHistory` возвращает `BalanceHistoryResponse` (с экспортом нового типа).
- Потребители обновлены: `tradingStore.fetchSessions/fetchTrades/fetchPositions`, `ActivePositionsWidget`, `CandlestickChart` (session trades fetch для маркеров), `BalanceWidget`.

### Файлы
- Изменены: `src/api/types.ts`, `src/api/tradingApi.ts`, `src/api/accountApi.ts`, `src/stores/tradingStore.ts`, `src/components/dashboard/ActivePositionsWidget.tsx`, `src/components/dashboard/BalanceWidget.tsx`, `src/components/charts/CandlestickChart.tsx`, `src/components/trading/__tests__/tradingStore.test.ts` (мок переведён на `{items,total,offset,limit}` формат).
- Новые: `src/api/__tests__/paginated.test.ts` (14 unit-тестов: isPaginatedResponse 7 + unwrapPaginated 7).

### Тесты
- `pnpm vitest run src/api/__tests__/paginated.test.ts` → **14/14 passed**.
- Полный прогон будет в конце блока FRONT2 W1.

### Контракты
- **C-S8-5 (потребитель FRONT2):** ✅ DONE. Аудит paginated завершён, типы TS приведены в соответствие, runtime защита через `unwrapPaginated()`.

### Stack Gotchas
- Будет создан `gotcha-25-api-paginated-type-mismatch.md` после блока FRONT2 W1 (готовый шаблон в отчёте).

---

## 2026-05-12 — W1 FRONT2 (DEV-4): 8.D.2/3/4 + полный W1 closeout

### 8.D.2 ErrorBoundary (S7R-FRONTEND-ERROR-BOUNDARY-MISSING)
- Новый `components/common/ErrorBoundary.tsx` — React class component с Mantine Alert fallback, варианты `app`/`widget`, кнопка retry, опциональный `reloadOnReset`, structured `console.error` в `componentDidCatch`.
- Top-level wrap вокруг `<Routes>` в `App.tsx` (level=app, reloadOnReset).
- Per-widget wrap каждого виджета `DashboardPage` (Balance / Health / Active Positions) + `CandlestickChart` в `ChartPage`.
- TODO: POST `/api/v1/errors/frontend` пока закомментирован (backend endpoint не реализован).
- 8 unit-тестов (`ErrorBoundary.test.tsx`): happy / throw / widget custom title / retry button reset / onError callback / structured console.error / custom fallback prop / reloadOnReset.

### 8.D.3 Strategy status change UI (S7R-STRATEGY-STATUS-CHANGE-UI)
- Новый `components/strategy/StrategyStatusMenu.tsx` — Mantine Menu + кликабельный Badge.
- Полный набор статусов из backend `VALID_STATUSES`: draft/tested/paper/live/paused/archived.
- Карта допустимых transition'ов `STRATEGY_STATUS_TRANSITIONS` экспортирована из `api/strategyApi.ts`. Невалидные опции `disabled`.
- Optimistic update local state + sync в `useStrategyStore` + rollback при ошибке.
- Toast feedback (`@mantine/notifications`): green «Статус обновлён» / red «Не удалось обновить статус».
- API shortcut: `strategyApi.updateStatus(id, status)` → `PUT /strategy/{id}` body `{status}`. Backend endpoint существует с S3 (`StrategyUpdate` accepts `status` + validator).
- Подключён в `DashboardPage` (заменил статический Badge в колонке «Статус»). Удалён неиспользуемый `STATUS_MAP`.
- 7 unit-тестов (`StrategyStatusMenu.test.tsx`): label, dropdown items, transitions enabled/disabled, archived terminal, success path, optimistic update freeze, error rollback.

### 8.D.4 Admin role frontend (Поток F, C-S8-7)
- `AuthUser.is_admin?: boolean` добавлен в `authStore.ts`. Persist-снапшоты совместимы (optional поле).
- `Sidebar.tsx` — фильтрация `navItems.filter(item => !item.adminOnly || isAdmin)`. `IconShield` пункт «Администрирование» с `data-testid="sidebar-admin-link"`.
- `routes/ProtectedAdminRoute.tsx` — гейт: null→/login, non-admin→/ + Mantine toast «Доступ ограничен», admin→children.
- `pages/admin/AdminLayout.tsx` + `pages/admin/AdminLandingPage.tsx` — минимальная заглушка с карточкой приветствия admin и списком admin backend endpoint'ов (smoke ping + W2 metrics placeholder).
- App.tsx: новый Route `path="admin/*"` обёрнут в `<ProtectedAdminRoute>`.
- Тесты: расширен `Sidebar.test.tsx` (+4 admin-conditional кейса), новый `ProtectedAdminRoute.test.tsx` (4 теста: null/non-admin/missing flag/admin).
- W2 Plotly Dash `/admin/metrics` НЕ реализована (по промпту).

### Файлы (W1 FRONT2 сводно)
**Новые:** `frontend/src/components/common/ErrorBoundary.tsx` + test; `frontend/src/components/strategy/StrategyStatusMenu.tsx` + test; `frontend/src/routes/ProtectedAdminRoute.tsx` + test; `frontend/src/pages/admin/AdminLayout.tsx`, `AdminLandingPage.tsx`; `frontend/src/api/__tests__/paginated.test.ts`; `Develop/stack_gotchas/gotcha-25-api-paginated-type-mismatch.md`; `Sprint_8/reports/DEV-4_FRONT2_W1.md`.
**Изменены:** `App.tsx`, `DashboardPage.tsx`, `ChartPage.tsx`, `Sidebar.tsx`/`sidebarItems.ts`/`Sidebar.test.tsx`, `authStore.ts`, `api/strategyApi.ts`/`tradingApi.ts`/`accountApi.ts`/`types.ts`, `stores/tradingStore.ts`, `components/dashboard/ActivePositionsWidget.tsx`/`BalanceWidget.tsx`, `components/charts/CandlestickChart.tsx`, `components/trading/__tests__/tradingStore.test.ts`, `Develop/stack_gotchas/INDEX.md`.

### Финальные метрики (FRONT2 W1)
- `pnpm vitest run` → **528 passed / 0 failed** (+60 vs baseline 468).
- `pnpm tsc --noEmit` → 0 errors.
- `pnpm lint` → 0 errors, 9 warnings (baseline).

### Контракты
- **C-S8-5 (потребитель FRONT2):** ✅ DONE — API paginated audit.
- **C-S8-7 (потребитель FRONT2):** ✅ DONE — Admin role frontend (Sidebar conditional, ProtectedAdminRoute, /admin landing).

### Stack Gotchas
- **Новый `gotcha-25-api-paginated-type-mismatch.md`** добавлен в каталог + INDEX.md.

### Что дальше
- Оркестратор подтверждает закрытие W1 для FRONT2 (4 задачи DONE: 8.D.1/2/3/4).
- FRONT2 W2 (~22ч): Dashboard widgets (4 шт. от BACK2), event_type sync UI labels, Grid Heatmap entrypoint, widget unit coverage 80%, Plotly Dash `/admin/metrics`.

---

## 2026-05-12 — W1 FRONT1 (DEV-3): 8.C.1+8.C.2 Drawing editing + intraday coords DONE

### Что
- **S7R-DRAWING-EDITING** — на момент старта W1 фактически уже реализован S7-hotfix'ами:
  hit-test через primitives (`TrendlinePrimitive.hitTest` / `RectPrimitive.hitTest`), drag по
  `body`/`p1`/`p2`/`corner-tl..br` через `applyHandleDrag` в `coords.ts`, селект по клику,
  cursor-style по handle (`cursorForHandle`), keyboard Delete/Backspace в `DrawingToolbar`,
  context-menu (Mantine `<Menu>`) с пунктами «На передний план», «Скопировать», «Удалить».
  Gap для W1: unit-tests на координатную математику отсутствовали (только `hitTest.test.ts`
  на чистую геометрию).
- **S7R-DRAWING-INTRADAY-COORDS** — реальный фикс рендера. До W1: `pointToCoord` использовал
  `timeToCoordinate(isoToTime(t))` независимо от режима графика. В **sequential mode**
  (intraday TF: 1m/5m/15m/1h/4h) time-axis у series = sequential-index (0,1,2,...), и
  `timeToCoordinate` ожидает индекс, а не unix-timestamp → старые drawings возвращали
  null и **не рендерились вообще**, а для новых drawings — fallback на logical был
  ограничен условием `logical >= dataLen` (forward-extrapolation only). Это и был тот
  «съезд» из карточки backlog.
- **Фикс:** новая утилита `isSeriesInSequentialMode(series)` детектит sequential-mode через
  численный диапазон `series.data()[0].time` (< 1e6 → sequential, иначе unix). `pointToCoord`
  выбирает приоритет:
  - **sequential**: logical-first, legacy fallback через `findIndexByIsoTimestamp` (только
    если series почему-то хранит unix-time).
  - **regular**: time-first как было.
- `shiftPoint` тоже знает про sequential-mode: вместо генерации мусорного ISO через
  `synthesizeIsoFromLogical` (который в sequential возвращал бы '1970-01-01...' от
  sequential-index) — оставляет `point.t` нетронутым (источник истины для intraday — logical).

### Файлы
- Изменён: `src/components/charts/primitives/coords.ts`
  - new `isSeriesInSequentialMode(series)` — детектор режима графика.
  - `pointToCoord` — двухветочная логика sequential vs regular mode.
  - new private `findIndexByIsoTimestamp(series, iso)` — legacy fallback для drawings
    без `logical` (защитный код для случая если series хранит unix-time).
  - `shiftPoint` — пропуск `synthesizeIsoFromLogical` в sequential mode, сохранение
    оригинального `point.t`.
- Новый: `src/components/charts/primitives/__tests__/coords.test.ts` — **23 unit-теста**:
  - isoToTime / timeToIso round-trip (2).
  - pointToCoord regular mode (3): timeToCoordinate path, logical-fallback ban при
    logical<dataLen, allow для logical>=dataLen.
  - pointToCoord sequential mode (3): logical-first, render inside visible range
    (был блокирован до фикса), null для legacy без logical.
  - pointToCoord null on price out of range (1).
  - shiftPoint (3): logical+price update в regular, сохранение point.t в sequential,
    no-op без logical в sequential.
  - shiftDrawing trendline/hline/label (3).
  - applyHandleDrag body/p1/p2/corner-tl + label fallback (5).
  - clickToDrawingPoint (3): with time, synth without time, null on bad price.

### Тесты
- `pnpm vitest run src/components/charts/primitives/__tests__/coords.test.ts` → **23/23 passed**.
- `pnpm vitest run` → **503 passed / 2 failed** (failed — pre-existing flaky в
  `client.test.ts: request interceptor guard`, timeout по race с zustand persist; не
  связано с моими изменениями. Baseline по факту 484/505, мои тесты дают +23 чистого
  прироста).
- `pnpm tsc --noEmit` → **0 errors**.
- `pnpm lint` → 0 errors / 9 warnings (baseline, к W3 cleanup в составе
  `S7R-FE-LINT-WARNINGS-CLEANUP`).

### Integration points
- `pointToCoord` вызывается всеми primitives (`TrendlinePrimitive.ts`,
  `RectPrimitive.ts`, `HlinePrimitive.ts`, `VlinePrimitive.ts`, `LabelPrimitive.ts`,
  `PositionDrawingPrimitive.ts`, `OpenPositionPrimitive.ts`) в их `draw()` →
  `grep -rn "pointToCoord(" src/components/charts/primitives/` подтверждает 7+ вызовов.
- `shiftPoint` / `shiftDrawing` / `applyHandleDrag` — в `DrawingsLayer.tsx`
  (pointer-handlers Phase 4, `useEffect` строки 438-522) при drag-завершении.
- `isSeriesInSequentialMode` — private helper, используется только в coords.ts; экспорта не требуется.

### Контракты
- **Cross-DEV:** поставщик — нет, потребитель — нет напрямую. Косвенно использую
  паттерн `sequentialIndex.ts` из S7-closeout (см. Stack Gotchas).

### Stack Gotchas
- Применён существующий паттерн `sequentialIndex.ts` (S7R-EQUITY-BY-INDEX, S7-closeout).
- **Новая ловушка кандидат:** `gotcha-24-lightweight-charts-sequential-time-axis.md` —
  в sequential-mode time-axis у series это индекс (0,1,2,...), а не unix-timestamp.
  Любая координатная конверсия через `timeToCoordinate(unix)` молча возвращает null.
  ARCH-ревью должно создать `gotcha-24-*.md` по чеклисту README.md.

### Что дальше
- W1 FRONT1 завершён. W3 задачи: `S7R-FE-LINT-WARNINGS-CLEANUP` (9 warnings → 0 +
  `--max-warnings 0`) + `S7R-HISTOGRAM-MANTINE-TOOLTIP`.
- Playwright скриншот цикла drag editing — оркестратор/QA в W1 wrap-up (не запускался
  в FRONT1, поскольку backend uncommitted и polluted рабочая директория).

---

## 2026-05-12 — W1 BACK2 (DEV-2): 8B.1 bandit/safety + 8B.2 audit + 8B.3 multiplexer singleton contract + 8B.4 admin smoke DONE

### Что
- **8B.1 (bandit/safety):** новый CI job `security-scan` в `.github/workflows/ci.yml`
  с двумя проверками: `bandit -r app/ -ll -c .bandit` (medium+ блокирует PR) +
  `safety check --policy-file safety_policy.yml`. Конфиг bandit + safety policy
  созданы с документированными suppression'ами (3 `# nosec B102` для intentional
  `exec` в RestrictedPython / Backtrader engine; 1 принятый CVE-2026-0994 protobuf
  4.25.9 — транзитив от tinkoff-investments, не аффектит нас).
- **8B.2 (security audit отчёт):** `Sprint_8/security_audit_s8.md` — 6 секций
  (Crypto / Sandbox / CSRF+Headers / Brute-force / SQL+XSS / bandit+safety).
  Verdict: 0 critical, 3 high (S8R-SEC-HEADERS, S8R-SEC-TELEGRAM-XSS,
  S8R-SEC-EMAIL-XSS), 7 medium (HKDF salt, key rotation CLI, JWT min-length,
  CSRF SameSite explicit, CSRF logout rotate, sandbox memory limit, auth rate
  tighten), 2 low (rate Redis, 2FA).
- **8B.3 (S7R-MULTIPLEXER-SINGLETON contract):** singleton-инфраструктура уже
  была реализована в S7 hotfix через module-level `_singletons` dict +
  `get_or_create_multiplexer` + `shutdown_multiplexers` (lifespan teardown в
  `app/main.py:196-202`). Я зафиксировал contract через 6 новых тестов в
  `tests/unit/test_broker/test_multiplexer_singleton.py`: same-token=same-id,
  multi-token=different-id, start()-once, shutdown clears + stops, swallow
  stop errors, recovery after shutdown. `grep -rn "TInvestStreamMultiplexer("
  app/` показывает ровно 1 вызов конструктора (в фабрике) — контракт выполнен.
- **8B.4 (require_admin smoke):** `tests/test_admin/test_admin_routes_protection.py`
  — структурный whitelist-тест: итерация по `app.routes`, для каждого
  `/api/v1/admin/*` проверка наличия `require_admin` в DI-цепочке (рекурсивный
  walk `dependant.dependencies`). 2 теста (routes_exist + every_admin_route_protected).
  Существующий `test_admin_role.py` (BACK1) проверяет 403/200 на `/ping`;
  моя проверка дополняет — никакой новый admin endpoint не утечёт без защиты.

### Файлы

**Новые:**
- `Спринты/Sprint_8/security_audit_s8.md`
- `Develop/backend/.bandit`
- `Develop/backend/safety_policy.yml`
- `Develop/backend/tests/unit/test_broker/test_multiplexer_singleton.py` (6 тестов)
- `Develop/backend/tests/test_admin/test_admin_routes_protection.py` (2 теста)
- `Develop/backend/tests/test_security/test_security_headers.py` (6 xfail-тестов —
  contract для будущего `SecurityHeadersMiddleware`)

**Изменённые:**
- `Develop/.github/workflows/ci.yml` — добавлен job `security-scan`.
- `Develop/backend/app/backtest/engine.py:492` — `# nosec B102` + reason.
- `Develop/backend/app/sandbox/executor.py:118,169` — `# nosec B102` + reason.

### Тесты
- Backend full pytest: **1098 passed / 6 xfailed / 0 failed** в 189s.
  Baseline до BACK2 был 1087 (после BACK1), мой прирост — **+11 passed +6 xfailed**.
- `bandit -r app/ -ll` → 0 medium+, 28 low (informational).
- `safety check --policy-file safety_policy.yml` → 1 ignored CVE (документирована).
- `ruff check app/ tests/test_security/test_security_headers.py
  tests/test_admin/test_admin_routes_protection.py
  tests/unit/test_broker/test_multiplexer_singleton.py` → 0 issues.
- `mypy app/ --ignore-missing-imports` → 0 errors на 147 файлах.

### Integration points
- `app.state.tinvest_multiplexer` контракт — мы не используем такое поле напрямую,
  потому что S7-hotfix реализовал singleton через module-level
  `_singletons[token]`. Это **функционально эквивалентно** контракту C-S8-6
  (один экземпляр на token, lifespan shutdown). Adapter получает экземпляр
  через `get_or_create_multiplexer` (`app/broker/tinvest/adapter.py:741-746`).
  → grep `TInvestStreamMultiplexer(` app/ → 1 hit (в фабрике).
- `require_admin` подключён в `app/admin/router.py:21-23` (router-level
  `dependencies=[Depends(require_admin)]`). Мой smoke-тест работает на runtime
  через `app.routes` — найдёт любой forgotten endpoint без защиты.

### Контракты
- **Поставщик C-S8-6** (multiplexer singleton) — реализован S7 hotfix; зафиксирован
  contract-тестами BACK2. Готов.
- **Поставщик C-S8-5** (paginated audit, совместно с BACK1) — backend-сторона:
  `grep -rn "PaginatedResponse" app/` — найден в существующих endpoint'ах
  (`account/router.py`, `broker/router.py`). Frontend audit — BACK1+FRONT2.
  Полная W1 проверка — на оркестраторе.
- **Потребитель `require_admin`** (от BACK1, C-S8-7) — контракт соблюдён.
  Smoke-тест прошёл.

### Stack Gotchas (применённые / новые)
Применённые:
- **Gotcha 4** (T-Invest streaming 429) — основа S7R-MULTIPLEXER-SINGLETON.
  Тесты multiplexer_singleton защищают именно от регрессии этой ловушки.
- **Gotcha 14** (CI vs local SDK stub) — учтена при выборе bandit/safety
  как чистых tools, не зависящих от tinkoff-investments SDK в CI.

Новые: нет (все находки security audit — стандартные web-security паттерны).

### Проблемы / TODO
- 6 high/medium findings зарегистрированы в `security_audit_s8.md`. Из них
  `S8R-SEC-HEADERS` (HIGH) рекомендуется внедрить в W2 — middleware простой
  (~30 LoC), xfail-тесты уже готовы → станут green после внедрения.
- `S8R-SEC-TELEGRAM-XSS` + `S8R-SEC-EMAIL-XSS` — fix в W2 в составе event sync
  (BACK2 W2 расширяет EVENT_MAP — самое время добавить `_safe_format()` helper).
- В backlog `Sprint_8_Review/backlog.md` отдельные карточки не создавал —
  оркестратор/ARCH формирует по итогам W1 (так делалось в S7).

---

## 2026-05-12 — QA W1 (6 missing E2E spec'ов)

### Что
Закрыты 5 Playwright spec'ов + 1 pytest integration (S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17):

- `e2e/s7-export.spec.ts` — Export CSV/PDF (3/3 passed).
- `tests/integration/test_backup_cli.py` — Backup CLI create/restore/missing-file (3/3 passed).
- `e2e/s7-events.spec.ts` — 5 event_type через mock WS (6/6 passed, table-driven).
- `e2e/s7-tg-callbacks.spec.ts` — Telegram deep-links view_session/view_chart (2/2 passed).
- `e2e/s7-backtest-analytics.spec.ts` — histogram/donut/trade-rows (3 passed / 2 skipped — см. блокеры).
- `e2e/s7-bg-backtest.spec.ts` — bg-backtest badge + popover + cap (3/3 passed).

Расширен `e2e/fixtures/api_mocks.ts` (+310 строк):
- `mockWSChannel(page, channel, frames[])` — через `page.routeWebSocket` (Playwright 1.59), без `_test/emit-event` (arch_design §11 batch 3 п.9).
- `mockBacktestResults(page, {id, status, ticker})` — управляемый id/status + `/export?format=csv|pdf` body.
- `mockBacktestWithTrades(page, trades[])` — для analytics.
- `mockBacktestRun(page, {mode})` — для bg-backtest.
- `mockMoexCandles(page, {ticker, tf})` — для chart deep-link.

`playwright.config.ts`: `reuseExistingServer=true` для CI-режима (S8 W1) — позволяет локальный прогон поверх запущенного `pnpm dev`; на CI каждый worker всё равно стартует свой.

### Файлы
- **Новые:** `Develop/frontend/e2e/s7-export.spec.ts`, `s7-events.spec.ts`, `s7-tg-callbacks.spec.ts`, `s7-backtest-analytics.spec.ts`, `s7-bg-backtest.spec.ts`; `Develop/backend/tests/integration/__init__.py`, `test_backup_cli.py`.
- **Изменённые:** `Develop/frontend/e2e/fixtures/api_mocks.ts`, `Develop/frontend/playwright.config.ts`.
- **Отчёт:** `Sprint_8/reports/QA_W1.md`.

### Результат
- Локальный прогон 5 spec'ов: **17 passed / 2 skipped** (24.1s).
- Pytest backup: **3/3 passed** (0.4s).
- Полная Playwright регрессия: **157 passed / 1 failed / 6 skipped / 1 did not run** (5.8 мин). 1 failure — pre-existing `s5-paper-trading.spec.ts:143 pause and resume session` (НЕ связан с W1).
- TypeScript `tsc --noEmit`: 0 errors.

### Blocked / Skip-тикеты (нужны карточки в backlog)
- `S8R-ANALYTICS-EQUITY-ZONES-TESTID` — equity-curve zones отрисованы canvas pixel-based в `InstrumentChart.tsx`, нет DOM-overlay с `data-testid`. Требуется FRONT-задача добавить overlay.
- `S8R-ANALYTICS-TRADE-ROW-CLICK` — rows в `BacktestTrades.tsx` без `onClick` handler; открытие `trade-detail-panel` через таблицу невозможно.

### Контракты (потребитель)
- Dashboard widgets (FRONT2) — `bg-backtest-badge`, `notification-bell` в Header (подтверждено через product code).
- Event sync publishers (BACK2 W2) — имитируем frames через `mockWSChannel`, реальная интеграция тестируется отдельно через `test_notification_e2e.py`.
- `is_admin` от BACK1 — не используется в W1 specs.

### Stack Gotchas
Применены: 1 (Decimal-string sериализация), 9 (Playwright strict via data-testid), 10 (MOEX live mock-only).

Новые (предлагается зафиксировать): **Mantine 0-height bar + Playwright `toBeVisible`** — для DOM-баров с динамической высотой использовать `toBeAttached()`/`count()`, не `toBeVisible()` (height=0 = hidden). Зафиксирован в `s7-backtest-analytics.spec.ts:92`.

