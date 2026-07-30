---
sprint: 8
agent: DEV-4
role: Frontend Core (FRONT2) — API contract + ErrorBoundary + Strategy status + Dashboard widgets + Admin panel + Plotly Dash
wave: 1+2
depends_on: [ARCH W0, DEV-1 W1 (is_admin поле, /admin/ router mount), DEV-2 W2 (5 dashboard endpoints, event sync publishers)]
---

# Роль

Ты — Frontend-разработчик #2 (senior). Зона ответственности: API contracts, defensive UI, admin panel, dashboard widgets, event sync UI, Plotly Dash страница метрик.

В **W1 (~20ч)** ты закрываешь medium-high frontend долг S7:
- Аудит TS-типов для paginated endpoints (runtime crash protection).
- React `ErrorBoundary` top-level + per-widget.
- UI смены статуса стратегии (контекстное меню / Select с disabled-state).
- Frontend часть нового эпика **Admin role** (Sidebar conditional, `ProtectedAdminRoute`, `is_admin` в authStore).

В **W2 (~22ч)** ты реализуешь:
- 4 дашборд-виджета (frontend интеграция backend-endpoint'ов от BACK2 / DEV-2).
- Синхронизацию `EVENT_TYPE_LABELS` (4 backend-типа из эпика L1).
- Grid Heatmap entry-point из BG-Backtest badge.
- Unit-тесты дашборд-виджетов (coverage gate 80%).
- **Plotly Dash страница `/admin/metrics`** (под mount от BACK1) — единственная backend-составляющая в твоей зоне.
- (если успеешь) Order Manager real-mode coverage.

Твой код трогает: `frontend/src/api/*.ts`, `frontend/src/components/`, `frontend/src/pages/`, `frontend/src/stores/authStore.ts`, `frontend/src/routes/`, и единственный backend-файл `app/admin/metrics_dash.py` (Plotly Dash app mount).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы — реальный прогон (правило S5R.5):

```
1. Окружение: Node ≥ 18 (Node 24 ещё не мигрирован, см. S7R-CI-NODE24-MIGRATION), pnpm доступен; Python ≥ 3.11 для Plotly Dash backend.
2. Зависимости предыдущих DEV:
   - DEV-1 W1 закрыл миграцию `users.is_admin: bool = False` и dependency `require_admin`.
   - DEV-1 W1 создал модуль `app/admin/router.py` и mount в `app/main.py`.
   - DEV-2 W2 завершил 5 dashboard endpoints (C-S8-1..4) и event sync publishers (C-S8-9).
   - Если зависимости не готовы — НЕ начинать W2 задачи, идти на W1.
3. Существующие файлы (должны быть на месте):
   - frontend/src/api/*.ts (все API модули)
   - frontend/src/App.tsx
   - frontend/src/components/Sidebar.tsx
   - frontend/src/stores/authStore.ts
   - frontend/src/pages/StrategyListPage.tsx
   - frontend/src/pages/NotificationSettingsPage.tsx
   - frontend/src/pages/FirstRunWizard.tsx
   - frontend/src/pages/DashboardPage.tsx
   - frontend/src/components/dashboard/ (каталог)
   - frontend/src/components/backtest/GridSearchResults.tsx
4. База данных: не трогаешь (Plotly Dash читает существующие таблицы).
5. Внешние сервисы: T-Invest sandbox для проверки health badge (не критично).
6. Тесты baseline:
   - `cd Develop/frontend && pnpm vitest run` → 0 failures, зафиксировать число тестов (старт S8: 468/0).
   - `cd Develop/frontend && pnpm tsc --noEmit` → 0 errors.
   - `cd Develop/frontend && pnpm lint` → 0 errors (9 warnings допустимы, S7R-FE-LINT-WARNINGS-CLEANUP).
   - `cd Develop/backend && pytest tests/ -q` → 0 failures (для Plotly Dash backend интеграции).
   Зафиксируй фактическое число в отчёте.
```

> Если хотя бы одно условие не выполнено — вернуть `БЛОКЕР: <описание>`. Не строить заглушки для C-S8-1..9 (нарушение integration verification).

# Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback (если MCP недоступен) |
|--------|--------|-------------------------------|
| typescript-lsp | **да** (mandatory после каждого Edit/Write на .ts/.tsx) | `cd Develop/frontend && npx tsc --noEmit` |
| pyright-lsp | **да** (только для `app/admin/metrics_dash.py`) | `cd Develop/backend && .venv/bin/python -m py_compile app/admin/metrics_dash.py` |
| context7 | **да** — Mantine (Select, Menu/ContextMenu), React Router (ProtectedRoute pattern), Plotly Dash (mount в FastAPI), Zustand (useAuthStore extension), Vitest (coverage threshold per directory) | WebSearch |
| playwright | **да** — скриншоты после реализации Admin Sidebar (видимость только для `is_admin`), Strategy status change UI, Dashboard 24h sparkline widget, Plotly Dash `/admin/metrics` страница | Попросить скриншот у заказчика |
| frontend-design | **да** — ПЕРЕД реализацией: StrategyStatusChange UI (контекстное меню vs Select), ErrorBoundary fallback UI, Admin Sidebar пункт (иконка, расположение) | — |
| code-review | **да** — после блока ErrorBoundary + Admin frontend, после Plotly Dash | — |
| superpowers (TDD) | **нет** (UI-логика, vitest unit-тесты пишутся параллельно с реализацией) | — |

**Правило:** после КАЖДОГО Edit/Write на `.ts/.tsx` файл → typescript-lsp diagnostic. После КАЖДОГО Edit/Write на `.py` файл → pyright-lsp diagnostic. Hook `plugin-check.sh` напомнит, но обязан соблюдать без напоминания.

# Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью (правила frontend стека, плагины).

2. **`Develop/stack_gotchas/INDEX.md`** — пройти все ловушки слоёв `frontend/`, `api/`, `auth/`. По симптомам обязательно проверить:
   - `gotcha-NN-api-paginated-type-mismatch.md` (создаётся в S8 при работе над эпиком C — будь готов добавить новую запись)
   - `gotcha-24-lightweight-charts-few-points-rightbar.md` (актуально для SparklineWidget)
   - Все ловушки про React/Zustand/Mantine.

3. **`Спринты/Sprint_8/arch_design_s8.md`** — секции:
   - **§1** (эпики B, C, E, F, G — твоя зона ответственности)
   - **§6** (event_type discrepancy: 12 vs 13, 4 backend-типа надо добавить в `EVENT_TYPE_LABELS`)
   - **§8** (Wave breakdown — W1 поток D, W2 поток C)
   - **§11** batch 2 пункт 7 (Plotly Dash — дословная цитата заказчика)
   - **§12** (Новый эпик Admin role — frontend часть твоя)

4. **`Спринты/Sprint_8/execution_order.md`** — раздел «Cross-DEV contracts», особое внимание:
   - **Потребитель:** C-S8-1, C-S8-2, C-S8-3, C-S8-4, C-S8-5, C-S8-7, C-S8-8, C-S8-9 (7 контрактов на потребление; ни одного — поставщик)

5. **Цитаты из ТЗ / ФТ:**

   > **arch_design_s8 §1 эпик C (S7R-API-PAGINATED-TYPE-MISMATCH, дословно):**
   > «Defensive UI, runtime crash защита. Backend возвращает `{items, total, page, size}`, frontend ожидает `T[]` — runtime ошибка `array.map is not a function`.»

   > **CLAUDE.md проекта (правила frontend):**
   > «Создаёшь новый UI-компонент или страницу? frontend-design: вызови /frontend-design перед реализацией.»

   > **arch_design_s8 §11 batch 2 пункт 7 (Plotly Dash дословно):**
   > «structlog + Plotly Dash страница `/admin/metrics` (~4ч в W2). Mac mini single-user сценарий: внутри приложения, без отдельных Docker контейнеров.»

   > **arch_design_s8 §6.2 (Event type discrepancy):**
   > «4 типа в EVENT_MAP, но не в UI: `session_started`, `session_stopped`, `order_placed`, `trade_filled` → добавить в `EVENT_TYPE_LABELS` (`NotificationSettingsPage.tsx:24`).»

6. **`Sprint_7/changelog.md`** — последние записи (S7R-EQUITY-BY-INDEX, lightweight-charts few-points) — образец Stack Gotchas формата.

# Рабочая директория

`Develop/frontend/` (основное), `Develop/backend/app/admin/` (только `metrics_dash.py`).

# Контекст существующего кода

- `frontend/src/api/*.ts` — все API модули (`tradingApi.ts`, `strategiesApi.ts`, `backtestApi.ts`, etc.); найти типы вида `Promise<T[]>` для paginated endpoints. **НЕ удалять существующие функции** — только корректировать типы возврата.
- `frontend/src/App.tsx` — top-level Routes; здесь добавлять ErrorBoundary wrapper. **НЕ ломать lazy-loading роутов.**
- `frontend/src/components/Sidebar.tsx` — основная навигация; добавить conditional admin link. **НЕ переделывать структуру меню.**
- `frontend/src/stores/authStore.ts` — Zustand-стор; расширить интерфейс `User` полем `is_admin: boolean`. **Сохранить обратную совместимость.**
- `frontend/src/pages/StrategyListPage.tsx` — список стратегий; добавить контекстное меню статуса (по согласованному UX-варианту). **Не трогать существующую фильтрацию/сортировку.**
- `frontend/src/pages/NotificationSettingsPage.tsx:24` — `EVENT_TYPE_LABELS` константа; добавить 4 ключа (по контракту C-S8-9).
- `frontend/src/pages/FirstRunWizard.tsx` — мастер первого запуска; шаг 4 (notifications) — добавить кнопку «Отправить тестовое сообщение». **Не ломать переход между шагами.**
- `frontend/src/pages/DashboardPage.tsx` — главный дашборд; расширить health badge + добавить 24h sparkline widget.
- `frontend/src/components/dashboard/` — каталог виджетов; именно сюда добавлять новые компоненты + покрывать unit-тестами.
- `frontend/src/components/backtest/GridSearchResults.tsx` — компонент grid heatmap; добавить entry-point из BG badge.
- `frontend/src/routes/ProtectedAdminRoute.tsx` — **НОВЫЙ компонент**, обёртка для admin-роутов (редирект не-админов на `/`).
- `app/admin/metrics_dash.py` — **НОВЫЙ файл**, Plotly Dash app + mount в FastAPI через `dash_app.server`.
- `app/admin/router.py` — admin-router (создаёт DEV-1 W1); добавить mount Plotly Dash под `/admin/metrics`.
- `app/main.py` — убедиться, что admin router включён через `app.include_router(...)` (это работа DEV-1, но проверка — твоя).

# Задачи

## W1

### Задача 8.D.1: API paginated type audit (S7R-API-PAGINATED-TYPE-MISMATCH, ~6ч)

**Цель:** Защитить frontend от runtime crash `array.map is not a function`. Backend `response_model=PaginatedResponse` возвращает `{items, total, page, size}`, frontend сейчас типизирован как `T[]`.

**Шаги:**
1. Найти все API-модули с paginated endpoints. Стартовые точки (известны 2):
   - `tradingApi.getSessions(...)` → `/trading/sessions`
   - `tradingApi.getTrades(...)` → `/trading/sessions/{id}/trades`
2. `grep -rn "PaginatedResponse" Develop/backend/app/` — собрать полный список backend endpoint'ов.
3. Для каждого endpoint:
   - Создать TS-тип:
     ```typescript
     export interface PaginatedResponse<T> {
       items: T[];
       total: number;
       page: number;
       size: number;
     }
     ```
   - Заменить сигнатуру: `Promise<T[]>` → `Promise<PaginatedResponse<T>>`.
   - В **потребителях** (компоненты/хуки/страницы) — обновить: `data` → `data.items`.
   - Если потребитель ожидал просто массив (например, `.map(...)`) — добавить unwrap: `(response.items ?? []).map(...)`.

**Tests:** `frontend/src/__tests__/api/typeguards.test.ts` — unit-тесты для `isPaginatedResponse(x)` typeguard (если ввёл) + проверка структуры моков `{items, total, page, size}`.

**Координация:** контракт C-S8-5 — BACK2+BACK1 поставляют список endpoint'ов в reports, FRONT2 правит TS.

### Задача 8.D.2: ErrorBoundary (S7R-FRONTEND-ERROR-BOUNDARY-MISSING, ~4ч)

**Цель:** Sentry-like top-level + per-widget fallback на случай React render error.

**Шаги:**
1. **ПЕРЕД реализацией:** вызови `frontend-design` для согласования fallback UI (текст, кнопка «Перезагрузить», цветовая схема Mantine).
2. Создай `frontend/src/components/ErrorBoundary.tsx` (class component):
   ```tsx
   interface Props {
     children: React.ReactNode;
     fallback?: React.ReactNode;
     onError?: (error: Error, info: React.ErrorInfo) => void;
   }
   class ErrorBoundary extends React.Component<Props, { hasError: boolean; error: Error | null }> {
     // getDerivedStateFromError + componentDidCatch + reset()
   }
   ```
3. **Top-level** в `App.tsx` — обернуть `<Routes>` в `<ErrorBoundary>` с глобальным fallback.
4. **Per-widget** — обернуть в локальные ErrorBoundary:
   - `Sidebar` (если sidebar упадёт — не должен валить весь экран)
   - `ChartPage` (chart-библиотека lightweight-charts может падать)
   - `DashboardPage` (каждый виджет — independently отдельно)
5. **Logging:** в `componentDidCatch` — `console.error(error, info)` + (опционально) `POST /api/v1/errors/frontend` (без блокировки, fire-and-forget). Если backend endpoint не реализован — пропустить с TODO-комментарием.

**Tests:** `frontend/src/__tests__/components/ErrorBoundary.test.tsx`:
- Дочерний компонент кидает → fallback рендерится.
- Кнопка «Перезагрузить» сбрасывает state → дочерний компонент перерендерится.
- `onError` callback вызван.

### Задача 8.D.3: Strategy status change UI (S7R-STRATEGY-STATUS-CHANGE-UI, ~8ч)

**Цель:** UI смены статуса стратегии: `DRAFT → ACTIVE → PAUSED → ARCHIVED`.

**Шаги:**
1. **ПЕРЕД реализацией:** `frontend-design` — выбрать вариант (Mantine `Menu` / `Select` / контекстное меню по правому клику). Согласовать disabled-states для невалидных transitions.
2. Допустимые transitions (по бизнес-логике):
   - `DRAFT` → `ACTIVE`, `ARCHIVED`
   - `ACTIVE` → `PAUSED`, `ARCHIVED`
   - `PAUSED` → `ACTIVE`, `ARCHIVED`
   - `ARCHIVED` → (терминальный, никуда)
3. API call: `PATCH /strategies/{id}/status` body `{"status": "ACTIVE"}`. Если endpoint не существует — создать в `frontend/src/api/strategiesApi.ts` функцию `updateStrategyStatus(id, status)`. **Координация с BACK1:** убедиться, что endpoint реально реализован (контракт не оформлен в Cross-DEV — проверить в reports BACK1 W1, иначе блокер).
4. **Toast feedback:** успех → green «Статус обновлён»; ошибка → red «Не удалось обновить статус».
5. **Optimistic update:** обновить local state до ответа сервера, откат при ошибке.

**Tests:** `frontend/src/__tests__/pages/StrategyListPage.test.tsx`:
- Открытие меню статуса.
- Disabled для невалидной transition.
- Mock API → toast рендерится.
- Optimistic update + rollback при ошибке.

### Задача 8.D.4: Admin role frontend (новый эпик N, ~2ч)

**Цель:** Frontend-часть admin role (зависит от DEV-1 W1: миграция `is_admin`, `require_admin` dependency, mount `/admin/`).

**Шаги:**
1. **`authStore.ts`** — расширить `User`:
   ```typescript
   interface User {
     id: number;
     username: string;
     // ... existing fields
     is_admin: boolean;  // NEW
   }
   ```
   `/auth/me` response уже включает `is_admin` (контракт C-S8-7) — fetch автоматически подтянет.

2. **`Sidebar.tsx`** — добавить conditional пункт:
   ```tsx
   {user?.is_admin && (
     <NavLink to="/admin" leftSection={<IconShield />}>
       Админ-панель
     </NavLink>
   )}
   ```
   **ПЕРЕД реализацией:** `frontend-design` — иконка и позиция в меню.

3. **`ProtectedAdminRoute.tsx`** — НОВЫЙ файл:
   ```tsx
   import { Navigate } from 'react-router-dom';
   import { useAuthStore } from '@/stores/authStore';

   export function ProtectedAdminRoute({ children }: { children: React.ReactNode }) {
     const user = useAuthStore((s) => s.user);
     if (!user) return <Navigate to="/login" replace />;
     if (!user.is_admin) return <Navigate to="/" replace />;
     return <>{children}</>;
   }
   ```

4. **`App.tsx`** — обернуть admin-роуты в `<ProtectedAdminRoute>`:
   ```tsx
   <Route path="/admin/*" element={<ProtectedAdminRoute><AdminLayout /></ProtectedAdminRoute>} />
   ```

5. **Playwright скриншот** — `e2e/screenshots/sidebar-admin-visibility.png` (один с `is_admin=true`, один без).

**Tests:** `frontend/src/__tests__/components/Sidebar.test.tsx`:
- `is_admin=true` → пункт виден.
- `is_admin=false` → пункт скрыт.
- `user=null` → пункт скрыт.

`frontend/src/__tests__/routes/ProtectedAdminRoute.test.tsx`:
- `user=null` → редирект `/login`.
- `is_admin=false` → редирект `/`.
- `is_admin=true` → children рендерятся.

## W2

### Задача 8.D.5: Dashboard widgets — 4 шт. (~10ч)

**Зависимость:** BACK2 (DEV-2) поставил 4 endpoint'а из C-S8-1..4. Если не готовы — БЛОКЕР, см. preflight.

**5.1 Health badge расширенный (C-S8-1, ~2ч):**
- В `DashboardPage.tsx` (или отдельном `HealthBadge.tsx`) — fetch `/api/v1/health` (расширенный).
- Рендер:
  - `cb_state`: зелёный (`ok`) / жёлтый (`warn`) / красный (`triggered`).
  - `tinvest_connected`: зелёный / серый.
  - `scheduler_running`: зелёный / серый + tooltip с `scheduler_jobs` count.
- Polling каждые 30 сек (или WS, если миграция S7R-HEALTH-WS-MIGRATION в W3 — пока polling).

**5.2 24h sparkline widget (C-S8-2, ~3ч):**
- **ПЕРЕД реализацией:** `frontend-design` — выбор библиотеки (lightweight-charts vs Mantine Charts vs SVG inline). Sparkline — компактный, без осей.
- Новый файл `frontend/src/components/dashboard/SparklineWidget.tsx`:
  ```tsx
  interface Props { ticker: string }
  export function SparklineWidget({ ticker }: Props) {
    // fetch /api/v1/market-data/sparkline?ticker=X&hours=24
    // render: компактный line chart, current price справа
  }
  ```
- Применить `gotcha-24-lightweight-charts-few-points-rightbar.md` — если используется lightweight-charts с малым числом точек.
- Разместить под `<TickerCard>` на DashboardPage.

**5.3 Balance history range (C-S8-3, ~1.5ч):**
- В существующем balance history компоненте — добавить параметр запроса `since_first_activity=true`.
- Не показывать leading zeros (нулевой баланс до первой активности).

**5.4 Wizard Telegram test button (C-S8-4, ~3.5ч):**
- В `FirstRunWizard.tsx` шаг 4 (notifications) — добавить кнопку «Отправить тестовое сообщение».
- Disabled, пока `bot_token` и `chat_id` не заполнены.
- Click → `POST /api/v1/notifications/telegram/test` `{bot_token, chat_id}`.
- Loading state → response: success toast (зелёный, «Сообщение отправлено в Telegram») / error toast.
- **Critical (MEMORY заметка):** настройки telegram/email из FirstRunWizard ОБЯЗАНЫ сохраняться в `notification_settings`. Убедись, что после теста значения не сбрасываются, а попадают в save-payload шага 4.

### Задача 8.D.6: Event type sync UI labels (C-S8-9, ~1ч)

**Цель:** Синхронизировать `EVENT_TYPE_LABELS` (`NotificationSettingsPage.tsx:24`) с EVENT_MAP backend.

**Шаги:**
1. Открой `frontend/src/pages/NotificationSettingsPage.tsx`, найди `EVENT_TYPE_LABELS` (строка ~24).
2. Добавь 4 ключа (см. C-S8-9):
   ```typescript
   const EVENT_TYPE_LABELS: Record<string, string> = {
     // existing 9...
     session_started: 'Сессия запущена',
     session_stopped: 'Сессия остановлена',
     order_placed: 'Ордер выставлен',
     trade_filled: 'Сделка исполнена',
   };
   ```
3. Убедись, что соответствующие настройки доставки (telegram/email/in-app) генерируются для всех 4 типов на UI.

**Tests:** `frontend/src/__tests__/pages/NotificationSettingsPage.test.tsx` — проверка наличия 4 новых лейблов в DOM.

### Задача 8.D.7: Grid Heatmap entry-point (S7R-GRID-HEATMAP-ENTRYPOINT, ~2ч)

**Цель:** Точка вызова Grid Heatmap из BG-Backtest badge (если grid_search job завершён → клик на badge → модал с heatmap).

**Шаги:**
1. В компоненте BG-Backtest badge (предположительно в `frontend/src/components/backtest/BackgroundBacktestBadge.tsx`) — добавить onClick handler для job типа `grid_search` со статусом `done`.
2. Открыть модал с `GridSearchResults` (компонент уже есть в `frontend/src/components/backtest/GridSearchResults.tsx`).
3. Передать `job_id` в модал, внутри fetch результатов и рендер heatmap.

**Tests:** проверить рендер heatmap при клике в существующем тесте badge'а.

### Задача 8.D.8: Widget unit coverage (S7R-WIDGETS-UNIT-COVERAGE, ~4ч)

**Цель:** Vitest unit-тесты для дашборд-виджетов; coverage gate 80% для `frontend/src/components/dashboard/`.

**Шаги:**
1. Покрыть все компоненты `frontend/src/components/dashboard/`:
   - `SparklineWidget.test.tsx`
   - `HealthBadge.test.tsx` (если выделен)
   - Существующие виджеты, у которых coverage < 80%.
2. Настроить per-directory coverage threshold в `vitest.config.ts`:
   ```typescript
   coverage: {
     thresholds: {
       'src/components/dashboard/**': { lines: 80, statements: 80, branches: 70, functions: 80 }
     }
   }
   ```
   **Уточнение через context7:** проверить актуальный синтаксис Vitest per-directory thresholds.

### Задача 8.D.9: Plotly Dash `/admin/metrics` (~4ч) **— единственная backend-задача FRONT2**

**Цель:** Страница метрик performance — Mac mini single-user сценарий, mounted в FastAPI.

**Зависимость:** DEV-1 W1 создал `app/admin/router.py` и `require_admin` dependency.

**Шаги:**
1. **Установить зависимости:**
   ```bash
   cd Develop/backend && .venv/bin/pip install dash plotly
   ```
   Зафиксировать в `requirements.txt`.

2. **Создать `app/admin/metrics_dash.py`:**
   ```python
   from dash import Dash, html, dcc
   import plotly.graph_objects as go
   from fastapi import FastAPI

   def create_dash_app(requests_pathname_prefix: str = '/admin/metrics/') -> Dash:
       dash_app = Dash(
           __name__,
           requests_pathname_prefix=requests_pathname_prefix,
           title='MOEX Terminal — Admin Metrics',
       )

       dash_app.layout = html.Div([
           html.H1('Метрики производительности'),
           dcc.Graph(id='signal-to-order-latency', figure=build_signal_latency_fig()),
           dcc.Graph(id='dashboard-lcp', figure=build_lcp_fig()),
           dcc.Graph(id='telegram-latency', figure=build_telegram_fig()),
           dcc.Graph(id='backtest-jobs-rate', figure=build_jobs_fig()),
       ])
       return dash_app

   def build_signal_latency_fig() -> go.Figure:
       # читать structlog-логи из app/common/observability.py или БД
       # p50 / p95 за последние 24 часа
       ...

   # build_lcp_fig, build_telegram_fig, build_jobs_fig аналогично
   ```

3. **Mount в FastAPI** (внутри `app/admin/router.py` или `app/main.py` через WSGIMiddleware):
   ```python
   from starlette.middleware.wsgi import WSGIMiddleware
   from app.admin.metrics_dash import create_dash_app

   dash_app = create_dash_app()
   app.mount('/admin/metrics', WSGIMiddleware(dash_app.server))
   ```
   **Защита:** Mount должен происходить ПОСЛЕ `require_admin` middleware. Если starlette WSGIMiddleware не пропускает dependency — обернуть в свой middleware с проверкой JWT cookie + `is_admin`. Через **context7** запросить актуальный паттерн Plotly Dash + FastAPI auth.

4. **Графики (4 шт.):**
   - **signal → order latency p50/p95** — bar chart по часам последних 24ч.
   - **dashboard LCP** — line chart, p95 за неделю.
   - **Telegram-команда latency** — bar chart, p50/p95 для 5 команд.
   - **Backtest jobs per hour** — line chart, rate за 7 дней.

   Источник данных: structlog логи (`app/common/observability.py` от DEV-1 / DEV-2 W2) или дополнительная таблица `metrics_events` если решена в W1. Если структуры данных нет — добавить TODO + временный placeholder с моками.

5. **Playwright скриншот:** `e2e/screenshots/admin-metrics-dash.png` после рендера всех 4 графиков.

**Tests:** `tests/integration/test_admin_metrics_dash.py`:
- `GET /admin/metrics` без JWT → 401/403.
- `GET /admin/metrics` с не-админом → 403.
- `GET /admin/metrics` с админом → 200, body содержит HTML с `id="signal-to-order-latency"` (Dash рендерит).

### Задача 8.D.10 (опциональная): Order Manager real-mode coverage (S7R-ORDER-MANAGER-REAL-MODE-COVERAGE, ~3ч)

**Если успеешь** после W2 основных задач — параметризовать paper+real тесты `OrderManager` через pytest fixture. **Иначе SKIP с reason:** "Перенесено в W3 потока A (low-карточки) — основные W2 задачи приоритетнее coverage gap".

# Опциональные задачи

Помечены в задачах 8.D.10. В отчёте — обязательно явный PASS / SKIP с reason (правило S5R.5).

# Skip-тикеты в тестах

Если ввёл `test.skip(...)` или `it.skip(...)` — в отчёте полный список + карточка в `Спринты/Sprint_9/backlog.md` (или `Sprint_8_Review/backlog.md` если 8.R принимает) с тикетом формата `S8R-<NAME>`.

Skip без карточки — **блокер**.

# Тесты

```
frontend/src/__tests__/
├── api/
│   └── typeguards.test.ts              # W1 8.D.1: PaginatedResponse unwrap
├── components/
│   ├── ErrorBoundary.test.tsx          # W1 8.D.2: fallback render, retry button, onError callback
│   ├── Sidebar.test.tsx                # W1 8.D.4: admin link conditional
│   └── dashboard/
│       ├── SparklineWidget.test.tsx    # W2 8.D.5/8.D.8
│       ├── HealthBadge.test.tsx        # W2 8.D.5/8.D.8
│       └── (existing widgets, добить до 80%)
├── pages/
│   ├── StrategyListPage.test.tsx       # W1 8.D.3: status change menu, disabled, toast, optimistic
│   └── NotificationSettingsPage.test.tsx  # W2 8.D.6: 4 новых лейбла в DOM
└── routes/
    └── ProtectedAdminRoute.test.tsx    # W1 8.D.4: redirect non-admin / non-auth

Develop/backend/tests/integration/
└── test_admin_metrics_dash.py          # W2 8.D.9: GET /admin/metrics auth + 200 admin
```

**Фикстуры (frontend):** `mockAuthStore`, `mockApiClient`, `mockNotifications` — взять из существующего `__tests__/utils/`. Если фикстура не существует — создать рядом с тестом, описать в отчёте.

**Фикстуры (backend для Plotly Dash):** `client` (FastAPI TestClient), `admin_user_token`, `regular_user_token` — из `tests/conftest.py`.

# Integration Verification Checklist

Для **каждой** новой сущности — провести grep + явная отметка в отчёте.

**W1:**

- [ ] **8.D.1:** `grep -rn "PaginatedResponse<" frontend/src/api/` показывает применение типа во всех найденных endpoint'ах.
- [ ] **8.D.1:** Каждый потребитель paginated endpoint использует `.items` (а не raw array). Grep на `\.items\b` в frontend/src/pages/ frontend/src/components/.
- [ ] **8.D.2:** `grep -rn "ErrorBoundary" frontend/src/` показывает: top-level в `App.tsx` + per-widget (Sidebar, ChartPage, DashboardPage).
- [ ] **8.D.2:** Console.error вызывается в componentDidCatch — verified в тесте.
- [ ] **8.D.3:** `frontend/src/api/strategiesApi.ts` содержит `updateStrategyStatus`. Backend endpoint существует (verify в DEV-1 W1 report; если отсутствует — БЛОКЕР).
- [ ] **8.D.4:** `Sidebar.tsx` содержит conditional `{user?.is_admin && ...}`.
- [ ] **8.D.4:** `App.tsx` содержит `<ProtectedAdminRoute>` для admin-роутов.
- [ ] **8.D.4:** `authStore.ts` `User` интерфейс содержит `is_admin: boolean`.

**W2:**

- [ ] **8.D.5:** `DashboardPage.tsx` fetch `/api/v1/health` (расширенный) — verified screenshot Playwright.
- [ ] **8.D.5:** `SparklineWidget` импортируется в `DashboardPage.tsx`. `grep -rn "SparklineWidget" frontend/src/`.
- [ ] **8.D.5:** `FirstRunWizard.tsx` шаг 4 содержит кнопку «Отправить тестовое сообщение». Telegram настройки попадают в save-payload (см. MEMORY: wizard_notifications_save).
- [ ] **8.D.6:** `NotificationSettingsPage.tsx:24` содержит 4 новых ключа в `EVENT_TYPE_LABELS`.
- [ ] **8.D.7:** BG-Backtest badge для grid_search job со статусом done — onClick обработан, открывает модал с `GridSearchResults`.
- [ ] **8.D.8:** `vitest.config.ts` содержит per-directory threshold для `src/components/dashboard/`.
- [ ] **8.D.8:** `pnpm vitest run --coverage` показывает ≥ 80% для `frontend/src/components/dashboard/`.
- [ ] **8.D.9:** `app/main.py` содержит `app.mount('/admin/metrics', WSGIMiddleware(dash_app.server))` (или эквивалент). `grep -rn "WSGIMiddleware\|dash_app" Develop/backend/app/`.
- [ ] **8.D.9:** Backend integration test `test_admin_metrics_dash.py` — 3 сценария (401, 403, 200).

**Cross-DEV potreбители:**

- [ ] **C-S8-1..4 (от BACK2):** все 4 endpoint'а реально вызываются из соответствующих frontend-компонентов — подтверждено grep и/или Playwright скриншотом.
- [ ] **C-S8-5 (от BACK1+BACK2):** аудит paginated завершён, список endpoint'ов из reports BACK совпадает с правками FRONT2.
- [ ] **C-S8-7 (от BACK1):** `is_admin` приходит в `/auth/me` response — verified mock + Playwright (Admin Sidebar появляется только при `is_admin=true`).
- [ ] **C-S8-8 (от BACK1):** `/admin/*` router включён в `app/main.py` — verified grep.
- [ ] **C-S8-9 (от BACK2):** все 4 новых event_type в `EVENT_TYPE_LABELS` имеют соответствие в EVENT_MAP backend (verified через grep `EVENT_MAP\|event_type` в backend/app/notification/).

- [ ] **Если точка вызова не найдена** — `⚠️ NOT CONNECTED` в отчёте + следующая задача (S9 backlog).

# Формат отчёта (МАНДАТНЫЙ)

**2 файла**, каждый — 8 секций до 400 слов (правило S5R.5).

1. **`reports/DEV-4_FRONT2_W1.md`** — после задач 8.D.1, 8.D.2, 8.D.3, 8.D.4.
2. **`reports/DEV-4_FRONT2_W2.md`** — после задач 8.D.5, 8.D.6, 8.D.7, 8.D.8, 8.D.9 (+ 8.D.10 опционально).

Шаблон секций (для каждого отчёта):
1. **Что реализовано** (5–10 пунктов крупными мазками).
2. **Файлы** (новые / изменённые / удалённые — абсолютные пути).
3. **Тесты** (Frontend: `X/Y passed`; Backend: `X/Y passed` для Plotly Dash). Если есть failed — диагноз.
4. **Integration points** (`<ClassName>.<method>` / `<Component>` вызывается из `<file:line>` ✅ или ⚠️ NOT CONNECTED).
5. **Контракты** — раздел «Использую» (потребитель): для каждого из C-S8-1..9 (где применимо) явное подтверждение: «Использую `<contract>` от `<DEV-X>` — контракт соблюдён» или «БЛОКЕР: контракт не реализован».
6. **Проблемы / TODO** (известные ограничения, отложенные сценарии, S9 backlog ссылки).
7. **Применённые Stack Gotchas** (`gotcha-NN-<slug>.md` — каких ловушек избежал, как).
8. **Новые Stack Gotchas** (если обнаружил новую — формат симптом / причина / правило / related_files; ARCH создаст файл в `Develop/stack_gotchas/`).
9. **Использование плагинов** — для каждого из таблицы «Обязательные плагины» статус: использован / fallback / не требовался.

**НЕ возвращать:** полный код реализованных файлов, полный лог tool-вызовов.

# Alembic-миграция

Не требуется (FRONT2 не вводит новых таблиц). Миграцию `is_admin` делает DEV-1 W1 — ты только потребитель этого поля во frontend.

# Чеклист перед сдачей

- [ ] Все задачи (W1: 8.D.1, 8.D.2, 8.D.3, 8.D.4; W2: 8.D.5, 8.D.6, 8.D.7, 8.D.8, 8.D.9) реализованы.
- [ ] Опциональная 8.D.10 явно закрыта PASS или SKIP + reason.
- [ ] `pnpm vitest run` — 0 failures (зафиксировать число тестов до/после).
- [ ] `pnpm tsc --noEmit` — 0 errors.
- [ ] `pnpm lint` — 0 errors (warnings допустимы, см. S7R-FE-LINT-WARNINGS-CLEANUP — будет закрыто в W3).
- [ ] **Backend** (для Plotly Dash): `pytest tests/integration/test_admin_metrics_dash.py -q` — 0 failures.
- [ ] **Backend** ruff/pyright чистые на `app/admin/metrics_dash.py`.
- [ ] **Coverage:** `frontend/src/components/dashboard/` ≥ 80% (per-directory threshold).
- [ ] Integration verification checklist полностью пройден.
- [ ] Формат отчёта соблюдён (8 секций × 2 файла = DEV-4_FRONT2_W1.md + DEV-4_FRONT2_W2.md).
- [ ] **Cross-DEV contracts (как потребитель):** C-S8-1, C-S8-2, C-S8-3, C-S8-4, C-S8-5, C-S8-7, C-S8-8, C-S8-9 — для каждого явное подтверждение в отчёте.
- [ ] **Stack Gotchas** применены — минимум 2 ловушки в отчёте (paginated type mismatch + lightweight-charts few-points).
- [ ] **Playwright скриншоты** сохранены: `sidebar-admin-visibility.png`, `strategy-status-change.png`, `dashboard-24h-sparkline.png`, `admin-metrics-dash.png`.
- [ ] **Плагины:** typescript-lsp использован после каждого .ts/.tsx Edit; pyright-lsp — для `metrics_dash.py`; context7 — для Mantine/Plotly Dash/React Router/Zustand/Vitest; frontend-design — перед StrategyStatusChange/ErrorBoundary/Admin Sidebar; playwright — 4 скриншота; code-review — после ErrorBoundary + Admin frontend + Plotly Dash.
- [ ] Skip-тикеты с карточками в `Sprint_9/backlog.md` (если есть).
- [ ] `Sprint_8/changelog.md` обновлён немедленно после каждого блока изменений (правило MEMORY: changelog_immediate).
- [ ] `Sprint_8/sprint_state.md` отражает прогресс W1/W2.
