# Sprint 7 — Changelog

> Лог изменений по дням. Обновляется **немедленно** после каждого блока изменений
> (правило памяти `feedback_changelog_immediate.md`).
>
> Формат записи: `## YYYY-MM-DD — короткое название`. Внутри — bullet'ы:
> - **Что:** краткое описание изменения
> - **Файлы:** перечень
> - **Результат:** что работает / что сломалось / тесты

---

## 2026-04-26 — DEV-4 (FRONT2) W2 sub-wave 2: задачи 7.7, 7.8-fe, 7.1-fe, 7.2-fe

### 7.7 — Dashboard widgets (Баланс / Health / Активные позиции)
- **Что:** на `/dashboard` добавлен `<SimpleGrid cols={{base:1,sm:2,lg:3}}>`
  с тремя виджетами: BalanceWidget (контракт C9 = `/api/v1/account/balance/history?days=30`,
  MiniSparkline 30 точек от FRONT1, %-diff за день), HealthWidget (3 строки
  светофора CB / T-Invest / Scheduler через `/api/v1/health` с graceful
  degrade на yellow «нет данных» если backend не отдал расширенные поля),
  ActivePositionsWidget (top-5 сессий по abs(P&L) через
  `/api/v1/trading/sessions?status=active`, sparkline-плейсхолдер 24h).
- **Файлы (NEW):** `src/components/dashboard/{BalanceWidget,HealthWidget,
  ActivePositionsWidget}.tsx`; `src/api/accountApi.ts` (+`getBalanceHistory`).
- **Файлы (MOD):** `src/pages/DashboardPage.tsx` (виджеты выше списка стратегий).
- **Тесты:** `BalanceWidget.test.tsx` (4 теста: empty/error/success/days=30).
- **Результат:** tsc 0 errors, vitest 394 passed (baseline 357 + 37 новых
  кумулятивно); playwright скриншот `s7-7.7-dashboard.png`.

### 7.8-fe — First-run wizard (5 шагов)
- **Что:** Mantine `<Modal fullScreen>` с `<Stepper active={n}
  allowNextStepsSelect={false}>`. Шаги: Старт / Риски / Брокер / Уведомления /
  Финиш. Шаг 2 — checkbox-gate, без галки «Далее» disabled. Шаг 3 — выбор
  paper/real (T-Invest disabled, единственная опция S7). Шаг 4 — Telegram
  (token+chatID), Email (validation), in-app (всегда вкл, disabled).
  Шаг 5 — `POST /api/v1/users/me/wizard/complete` (контракт C6 fix-волна
  2026-04-26 = `/users/me/...`, не `/auth/me/...`). Esc/click outside
  заблокированы.
- **Файлы (NEW):** `src/api/usersApi.ts` (`getMe`, `completeWizard`),
  `src/components/wizard/FirstRunWizard.tsx`,
  `src/components/wizard/FirstRunWizardGate.tsx` (проверяет
  `wizard_completed_at` через `/users/me`, монтирует модалку при null).
- **Файлы (MOD):** `src/App.tsx` (`<FirstRunWizardGate />` внутри
  ProtectedRoute, перед `<AppLayout />`).
- **Тесты:** `FirstRunWizard.test.tsx` (4: рендер, шаг 2 gate, finish→complete).
- **Результат:** tsc 0 errors, playwright скриншоты `s7-7.8-wizard-step1.png`,
  `s7-7.8-wizard-step2-disclaimer.png`. Wizard не показывается повторно
  после complete (проверено е2е через mock `wizardCompleted: true`).

### 7.1-fe — Versions history drawer (контракт C4)
- **Что:** на `StrategyEditPage` добавлена кнопка «История» (рядом с
  «Сохранить»), открывающая `<VersionsHistoryDrawer size="lg" position="right">`.
  Список версий через `GET /strategy/{id}/versions/list`; per-row бейдж
  «текущая», кнопки Просмотреть / Diff / Восстановить. Diff делается на
  фронте через простой line-by-line алгоритм (без `react-diff-viewer-continued`
  — экономия зависимости). Restore через confirm-modal → `POST /versions/{ver_id}/restore`.
  Также «Сохранить именованную версию» через `POST /versions/snapshot {comment}`.
- **Файлы (NEW):** `src/components/strategy/VersionsHistoryDrawer.tsx`.
- **Файлы (MOD):** `src/api/strategyApi.ts` (+`listVersions`, `getVersionById`,
  `createNamedSnapshot`, `restoreVersion`, +interfaces `VersionListItem`,
  `VersionRestoreResponse`); `src/pages/StrategyEditPage.tsx` (кнопка + Drawer).
- **Тесты:** `VersionsHistoryDrawer.test.tsx` (5: load list, badge «текущая»,
  diff disabled у current, restore disabled у current, restore→confirm→POST).
- **Результат:** tsc 0 errors; playwright скриншот `s7-7.1-versions-drawer.png`.

### 7.2-fe — Grid Search modal (контракт C5)
- **Что:** на `StrategyEditPage` кнопка «Grid Search» открывает
  `<GridSearchModal>` → `<GridSearchForm>`. Поля: тикер, таймфрейм,
  даты, начальный капитал; динамические параметры (1–5) с
  comma-separated values. Real-time `total = product(len(values))`:
  green ≤200, yellow 201–1000, red >1000 (submit disabled).
  POST `/api/v1/backtest/grid` → `{job_id, total}` → push в общий
  `backgroundBacktestsStore` от FRONT1 (job в badge подхватывается
  WS `/ws/backtest/{job_id}` через `useBackgroundBacktestsBootstrap`).
  Heatmap: 1 параметр → bar chart, 2 → 2D heatmap (gradient red→white→green
  по выбранной метрике), 3+ → таблица с sortable columns + heatmap по
  первым 2. Tooltip ячейки: P&L / Win Rate / Drawdown / Trades.
  При `overfitting_warning=true` — alert «Возможный overfitting».
- **Файлы (NEW):** `src/components/backtest/{GridSearchForm,GridSearchModal,
  GridSearchHeatmap}.tsx`; `src/api/backtestApi.ts` (+`startGridSearch`,
  +interfaces `GridSearchRequest`, `GridJobResponse`, `GridMatrixCell`,
  `GridResult`).
- **Файлы (MOD):** `src/pages/StrategyEditPage.tsx` (кнопка + modal).
- **Тесты:** `GridSearchForm.test.tsx` (12 тестов: parseRangeValues,
  calcTotal, totalSeverity hard cap).
- **Результат:** tsc 0 errors; playwright скриншот `s7-7.2-grid-search.png`.

### Общие итоги W2 sub-wave 2 (DEV-4)
- **tsc:** `npx tsc --noEmit` → 0 errors.
- **vitest:** `pnpm test` → **394 passed** (baseline 357 + 37 новых).
- **playwright:** `npx playwright test e2e/s7-front2.spec.ts` → **4/4 passed**,
  6 скриншотов в `e2e/screenshots/s7/`.
- **Контракты подтверждены:** C4 (versions), C5 (grid), C6 (wizard через
  `/users/me`), C9 (balance/history) — все URL grep'нуты по backend
  и совпадают с реализованным фронтом.
- **Координация с FRONT1:** `MiniSparkline.tsx` уже был опубликован к
  моменту BalanceWidget — переиспользован 1:1 (props `data`, `color`,
  `width`, `height`, `ariaLabel`, `data-testid`).
- **Pre-existing 6 lint errors** (`CandlestickChart`, `SessionDashboard`,
  `ChartPage`, `ProfileSettingsPage`, `priceAlertStore`) НЕ ТРОГАЛИСЬ.

---

## 2026-04-26 — FRONT1 PHASE2 (Блок 2): задача 7.19 AI слэш-команды

- **Что:** реализован полный фронтенд-стек AI слэш-команд (контракт C3
  потребитель). 5 команд: `/chart TICKER [TF]`, `/backtest ID`,
  `/strategy ID`, `/session ID`, `/portfolio` (без аргумента). Парсинг
  локально на фронте, в backend отправляется `context_items: list[ChatContextItem]`
  (новое поле, см. `Develop/backend/app/ai/chat_schemas.py`); legacy
  `context: dict | None` сохранён без изменений (используется блок-режимом
  стратегии).
- **Компоненты:**
  - `parseCommand` — парсер с поддержкой множественного контекста
    (`/chart SBER /backtest 42 сравни...` → 2 contextItems + remainder),
    валидацией id (int positive для backtest/strategy/session, ticker regex
    для chart), фильтрацией невалидных аргументов в remainder.
  - `CommandsDropdown` (Mantine `<Combobox>`) — открывается при `/`
    в начале строки или после whitespace; фильтрация по префиксу
    (`/cha` → только `/chart`); ↑/↓/Enter/Tab/Esc keyboard; **IME
    composition guard** (compositionstart/end) — НЕ открывает dropdown
    во время русского ввода с диакритикой (UX §12).
  - `ContextChip` — Mantine `<Badge variant="light"
    leftSection={<icon />}>` с навигацией react-router; статусы
    `ok|forbidden|not_found` (UX §6) — красный chip с tooltip при
    ownership-ошибке backend'а.
  - Render `[CONTEXT]...[/CONTEXT]` в assistant-ответе → collapsible
    «Контекст» (default closed) с monospace-блоком (defense-in-depth
    от echo backend'а).
- **Файлы (NEW):**
  - `Develop/frontend/src/components/ai/parseCommand.ts`
  - `Develop/frontend/src/components/ai/CommandsDropdown.tsx`
  - `Develop/frontend/src/components/ai/commandsDropdownHelpers.ts`
    (вынесено: `useCaretAndComposition` + `dropdownKeyAction` —
    react-refresh требует чисто-компонентных файлов)
  - `Develop/frontend/src/components/ai/ContextChip.tsx`
  - Tests: `parseCommand.test.ts` (34), `CommandsDropdown.test.tsx` (6),
    `ContextChip.test.tsx` (8)
  - E2E: `Develop/frontend/e2e/s7-ai-commands.spec.ts` (5 кейсов) +
    5 PNG в `e2e/screenshots/s7/s7-7.19-*.png`.
- **Файлы (MOD):**
  - `Develop/frontend/src/components/ai/ChatInput.tsx` — обёрнут в
    `CommandsDropdown`, добавлен IME composition handling.
  - `Develop/frontend/src/components/ai/AIChat.tsx` — рендер
    `ContextChip` в user-сообщениях, `splitContextBlocks` + `Collapse`
    для assistant-ответа.
  - `Develop/frontend/src/api/aiApi.ts` — новое поле
    `context_items?: ChatContextItem[]` в `ChatMessagePayload` (legacy
    `context?: object` сохранён).
  - `Develop/frontend/src/services/aiStreamClient.ts` — параметр
    `contextItems` в `streamChat()`, прокинут в SSE body как
    `context_items`.
  - `Develop/frontend/src/stores/aiChatStore.ts` — `parseCommand`
    в `sendMessage` и `sendMessageStream`, `ChatMessage.contextItems`
    для рендера chip'ов в истории.
  - `Develop/frontend/src/components/ai/__tests__/ChatInput.test.tsx` —
    адаптирован: `getTextarea()` через `document.querySelector('textarea')`
    (Combobox.Target переписывает data-testid на dropdown).
- **Тесты:** `pnpm test --run` → **371 passed / 0 failed (65 files)**
  (baseline 316, +55 новых: 7 MiniSparkline + 34 parseCommand + 6
  CommandsDropdown + 8 ContextChip + переадаптация ChatInput).
- **Type-check:** `npx tsc --noEmit` → **0 errors**.
- **Lint:** проходит на новых файлах; 10 pre-existing baseline ошибок
  (S7.R) не тронуты.
- **Playwright E2E:** `npx playwright test e2e/s7-ai-commands.spec.ts`
  → **5 passed / 0 failed (7.3s)**. Скриншоты:
  - `s7-7.19-dropdown-open.png` — dropdown с 5 командами.
  - `s7-7.19-filter-chart.png` — фильтрация `/cha` → /chart.
  - `s7-7.19-chip-in-message.png` — `/chart SBER` → chip в чате.
  - `s7-7.19-multi-chips.png` — два контекста в одном сообщении.
  - `s7-7.19-portfolio-chip.png` — `/portfolio` без аргумента.
- **Stack Gotcha кандидат (новая):** Mantine `Combobox.Target`
  `cloneElement` переписывает `data-testid` дочернего input'а на
  `data-testid` самого popover (`ai-chat-slash-popover`). В тестах
  это ловится `getByTestId('chat-input')` → undefined. Workaround:
  получать textarea через `document.querySelector('textarea')`.
  Будет вынесено в `gotcha-22-mantine-combobox-target-clone.md`
  при ARCH-ревью.
- **Контракт C3 (потребитель):** payload `POST /api/v1/ai/chat`
  и `POST /api/v1/ai/chat/stream` теперь содержит
  `context_items: [{type, id}, ...]` (точное имя поля; backend
  `chat_schemas.py:48`). Legacy `context: dict` оставлен без изменений.
- **Координация с FRONT2:** FRONT2 успел подцепить `MiniSparkline`
  в `dashboard/BalanceWidget.tsx` ещё до старта Блока 2 — параллельная
  работа без конфликтов.

---

## 2026-04-26 — FRONT1 PHASE2 (Блок 1): MiniSparkline опубликован для FRONT2

- **Что:** создан компонент `MiniSparkline` для виджетов дашборда S7 7.7
  (саппорт FRONT2). Чистый SVG, без зависимости от lightweight-charts.
- **Контракт компонента:**
  ```ts
  export interface MiniSparklineProps {
    data: number[];
    color?: 'green' | 'red' | string;  // default — var(--mantine-color-blue-6)
    width?: number;   // default 120
    height?: number;  // default 40
    ariaLabel?: string;  // обязательно для prod
    'data-testid'?: string;
  }
  ```
- **Поведение:** пустой data → пустой SVG (no crash); 1 элемент →
  горизонтальная линия; ≥2 элементов → polyline с нормализацией min..max →
  0..height; все одинаковые значения → горизонтальная линия (range=0 fallback).
- **Файлы (NEW):**
  - `Develop/frontend/src/components/charts/MiniSparkline.tsx`
  - `Develop/frontend/src/components/charts/__tests__/MiniSparkline.test.tsx`
    (7 тестов: empty / 1 point / multi-points / range=0 / colors / a11y / size)
- **Тесты:** `pnpm test src/components/charts/__tests__/MiniSparkline.test.tsx
  --run` → **7 passed / 0 failed**.
- **Type-check:** `npx tsc --noEmit` → 0 errors.
- **Координация с FRONT2:** компонент опубликован в начале PHASE2, FRONT2
  может импортировать `import { MiniSparkline } from
  '../charts/MiniSparkline'` для виджета «Баланс» и «Активные позиции» (7.7).

---

## 2026-04-26 — Fix-волна BACK1: Grid Search → multiprocessing.Pool

- **Что:** заказчик потребовал переделать Grid Search с
  `asyncio.Semaphore + thread executor` (под-волна 1 W2) на
  `multiprocessing.Pool` (spawn-context, workers = `cpu - 1`),
  как предписывает ТЗ §5.3.4 и `arch_design_s7.md §2`. Asyncio.Semaphore не давал
  CPU-параллелизма для CPU-bound Backtrader, что плохо масштабируется на
  1000-комбинациях.
- **Подход (как решены подводные камни):**
  - **AsyncSession не pickle-able** → OHLCV грузим один раз в main-процессе
    через `MarketDataService` (новый `_prepare_grid_workload` в `router.py`),
    worker'у передаём только pickle-friendly `list[dict]` свечей.
  - **macOS spawn** → используем `multiprocessing.get_context("spawn")` явно;
    worker `_run_single_backtest(payload: dict)` — top-level функция (без
    closures, без bound-методов), импортирует backtrader/pandas сама.
  - **asyncio + Pool в FastAPI** → Pool управляется синхронным драйвером
    `_drive_pool_sync` (вызывается через `loop.run_in_executor`), результаты
    стримятся в `queue.SimpleQueue` по мере `imap_unordered(chunksize=1)` yield.
    Главный async-таск читает очередь и публикует прогресс в WS через
    `progress_publisher`. Event loop FastAPI не блокируется.
  - **Index-tracking** → `_run_single_backtest_indexed(idx, payload)` обёртка
    сохраняет соответствие `params ↔ result` (imap_unordered не гарантирует
    порядок).
- **Контракт C5 НЕ изменился:** `POST /api/v1/backtest/grid` body/response
  идентичны; WS `/ws/backtest/{job_id}` финальный payload `result.matrix`
  имеет ту же структуру. FRONT2 (sub-wave 2) не затрагивается.
- **Совместимость с тестами:** `GridSearchEngine.run(runner=...)` сохранён
  для unit-тестов с моковыми async-runner'ами; production переключён на новый
  метод `GridSearchEngine.run_pool(worker_payload=...)`.
- **Decimal-coerce** (`_coerce_param_value`) сохранён без изменений — закрывает
  open question W1 (`params_json` Decimal→str).
- **Файлы (CHANGED):**
  - `Develop/backend/app/backtest/grid.py` — переписан: новый worker
    `_run_single_backtest`, индекс-обёртка `_run_single_backtest_indexed`,
    sync-драйвер `_drive_pool_sync` (spawn-context), новый async-метод
    `run_pool(...)`. Legacy `run(runner=...)` сохранён.
  - `Develop/backend/app/backtest/router.py` — `_make_grid_runner` →
    `_prepare_grid_workload` (загрузка candles в main-процессе).
    `start_grid_search` использует `run_pool` через `_job_runner`.
  - `Develop/backend/tests/unit/test_backtest/test_grid.py` — добавлен
    `TestMultiprocessingWorker` (5 тестов: pickleable worker/payload, cap
    для run_pool, max_workers default).
  - `Develop/stack_gotchas/gotcha-21-grid-multiprocessing-vs-async.md` —
    добавлена UPDATE-секция «решение пересмотрено: multiprocessing.Pool
    финал» (append-only, оригинальный текст сохранён как урок).
  - `Develop/stack_gotchas/INDEX.md` — обновлена строка #21, version 3 → 4.
- **Тесты:** `pytest tests/unit/test_backtest/test_grid.py
  tests/unit/test_backtest/test_grid_endpoint.py -q` → **35 passed**
  (было 30 + новые 5: pickleable worker, pickleable payload, run_pool cap,
  run_pool too-many-params, default_max_workers).
  Полный pytest: **881 passed / 4 failed** (4 failed — `test_chart_drawings/`
  — work-in-progress BACK2, не моя зона).
- **Линт:** ruff check `app/backtest/grid.py app/backtest/router.py
  tests/unit/test_backtest/test_grid.py` → 0 issues. py_compile — 0 errors.
- **Integration verification:** `grep -rn "GridSearchEngine|run_pool|
  _run_single_backtest|multiprocessing.Pool|_prepare_grid_workload"
  app/` подтверждает production-вызовы в `router.py` (lines 1085, 1202,
  1207, 1213) — нет `⚠️ NOT CONNECTED`.

---

## 2026-04-26 — Fix-волна FRONT1: Playwright скриншоты drawing tools

- **Что:** закрыт долг W2 PHASE1 — DrawingToolbar/DrawingsLayer (задача 7.6) не
  имели визуального подтверждения через Playwright (отчёт `DEV-3_FRONT1_W2_PHASE1.md`
  §8: «dev-сервера не запущены, скриншот не сделан»). Создан e2e-тест с 8
  сценариями, прогнан, все скриншоты сохранены.
- **Подход:** фейковый auth (injectFakeAuth) + замоканные backend API
  (mockCatchAllApi, специфичные моки `/api/v1/market-data/candles**`,
  `/api/v1/charts/**/drawings`, `instrument-info`). Свечи фиксированные
  (15 дневных свечей SBER 23.03–10.04) — для воспроизводимых координат фигур.
  Готовые рисунки подставляются через мок `GET .../drawings` → store пишет items
  → DrawingsLayer отрисовывает на canvas (trendline/rect/label/vline) или через
  нативный `series.createPriceLine()` (hline). Это не зависит от backend
  REST-router'а (он BACKEND-PENDING для chart_drawings).
- **Скриншоты (8/8) в `Develop/frontend/e2e/screenshots/s7/`:**
  - `s7-7.6-toolbar-default.png` — тулбар слева, курсор активен (aria-pressed=true)
  - `s7-7.6-toolbar-trend-active.png` — выбран trendline, кнопка filled blue
  - `s7-7.6-trendline-drawn.png` — жёлтая трендлиния от 25.03 до 08.04
  - `s7-7.6-rectangle-zone.png` — зелёная rect-зона 30.03–09.04 / 320–332
  - `s7-7.6-hline.png` — два priceLine: зелёный «Support 320» + красный «Resistance 332»
  - `s7-7.6-label.png` — текстовая метка «Breakout!» в синей рамке
  - `s7-7.6-eraser-mode.png` — Modal `chart-drawings-editor` со списком (rect+trend) + per-row «Удалить»
  - `s7-7.6-keyboard-shortcuts.png` — Tooltip «Трендовая линия (T)» с hotkey
- **Файлы (NEW):**
  - `Develop/frontend/e2e/s7-drawing-tools.spec.ts` (+275 строк, 8 test cases)
  - `Develop/frontend/e2e/screenshots/s7/` (8 PNG)
- **Тесты:** `npx playwright test e2e/s7-drawing-tools.spec.ts --reporter=line`
  → **8 passed (18.8s)**. Полный baseline E2E (119) — НЕ запускался ради
  экономии времени (правило промпта: «если не успеваешь — пропусти, укажи в отчёте»).
- **Замечание (не блокер):** Mantine Tooltip в headless показывается с задержкой,
  поэтому `waitForTimeout(900)` после hover. Скриншот ловит tooltip стабильно.
- **Без изменений в production-коде** — только e2e тест и артефакты screenshots.

## 2026-04-26 — Fix-волна OPS: WeasyPrint установка + PDF-экспорт работает

- **Что:** закрыт skip-тикет `S7R-PDF-EXPORT-INSTALL` (Sprint_8_Review/backlog.md).
  В среду разработки установлен WeasyPrint 68.1, PDF-экспорт бэктеста проверен
  через живой endpoint и набор тестов.
- **Системные зависимости (brew):** уже установлены ранее (pango 1.57.1, cairo 1.18.4,
  gdk-pixbuf 2.44.5, libffi). Изменений в `setup_macos.sh` не потребовалось — секция 8
  «Зависимости для WeasyPrint» уже корректно перечисляет нужные пакеты.
- **Python-зависимость:** добавлено `weasyprint>=60` в `[project] dependencies`
  pyproject.toml. Установлено: `weasyprint 68.1` + транзитивные (Pillow 12.2.0,
  Pyphen 0.17.2, brotli 1.2.0, cssselect2 0.9.0, fonttools 4.62.1, pydyf 0.12.1,
  tinycss2 1.5.1, tinyhtml5 2.1.0, webencodings 0.5.1, zopfli 0.4.1). Lockfile
  у проекта нет — зафиксировано только в pyproject.toml.
- **Тесты:** в `tests/unit/test_backtest/test_export.py` удалена ветка
  `pytest.skip("weasyprint installed")`. Negative-path переписан через
  `sys.modules["weasyprint"] = None` (стабилен в любом окружении). Добавлены
  2 positive-path теста: unit (`test_generate_pdf_produces_valid_pdf_bytes`,
  проверка `%PDF-` magic-bytes) + HTTP (`test_export_pdf_endpoint_returns_pdf_bytes`,
  проверка 200 + content-type + magic). 8/8 passed в файле test_export.py.
- **Endpoint smoke-test:** `GET /api/v1/backtest/31/export?format=pdf` (sergopipo,
  user_id=1) → `HTTP 200`, `Content-Type: application/pdf`, размер 54 685 байт,
  `file → PDF document, version 1.7`. Lazy-import в `export.py` подхватил
  свежеустановленный модуль без перезапуска процесса.
- **Документация:** создан `Develop/backend/INSTALL.md` — инструкция по системным
  зависимостям (macOS + Ubuntu/Debian) и проверке установки.
- **Файлы (MOD):**
  - `Develop/backend/pyproject.toml` (+1 строка: `weasyprint>=60`)
  - `Develop/backend/tests/unit/test_backtest/test_export.py` (negative-path
    переписан, +2 positive-path теста)
  - `Спринты/Sprint_8_Review/backlog.md` (тикет S7R-PDF-EXPORT-INSTALL → ✅ DONE)
- **Файлы (NEW):**
  - `Develop/backend/INSTALL.md`
  - `Спринты/Sprint_7/reports/DEV-5_OPS_W2_FIX.md`
- **Полный регресс backend:** `pytest tests/ -q` → **867 passed / 0 failed** (82s).
  Baseline до волны: 866 passed → +1 positive-path PDF.
- **Координация:** backend был поднят FRONT1 ранее (PID 57707, порт 8000) — НЕ
  перезапускал. Lazy-import корректно подхватил weasyprint при первом обращении
  к endpoint. Перезапуск НЕ требуется.

---

## 2026-04-26 — Fix-волна BACK2: chart_drawings backend mini-CRUD (5 endpoint'ов)

- **Что:** реализован REST mini-CRUD для пользовательских разметок графика
  (`trendline / hline / vline / rect / label`). Контракт согласован с
  `Develop/frontend/src/api/chartDrawingsApi.ts` — frontend = source of truth.
  Frontend больше НЕ зависит от localStorage-fallback (`backendAvailable=false`)
  для persist между устройствами.
- **Маршруты (под `/api/v1/charts`):**
  - `GET    /{ticker}/{tf}/drawings` → `ChartDrawing[]`
  - `POST   /{ticker}/{tf}/drawings` → `ChartDrawing` (201)
  - `PATCH  /drawings/{id}`           → `ChartDrawing`
  - `DELETE /drawings/{id}`           → 204
  - `DELETE /{ticker}/{tf}/drawings`  → 204 (clear all)
- **Модель:** переиспользована существующая `ChartDrawing` из
  `app/common/models.py` (создана в initial-миграции `3d3e4e3036a6`,
  таблица + индекс `idx_drawing_lookup` уже существуют).
  **Новой alembic-миграции НЕТ** — таблица была заведена авансом ещё в S0.
- **Ownership:** при попытке доступа к чужой разметке возвращается **404
  Drawing not found** (НЕ 403 — чтобы не leak'ить existence ID). Единое
  поведение для PATCH/DELETE/single-GET.
- **Валидация payload по типу:** `trendline/rect` требуют `p1+p2`,
  `hline` → `price`, `vline` → `t`, `label` → `text+anchor`. Нарушение → 422.
- **Файлы (NEW):**
  - `Develop/backend/app/chart_drawings/__init__.py`
  - `Develop/backend/app/chart_drawings/schemas.py`
  - `Develop/backend/app/chart_drawings/router.py`
  - `Develop/backend/tests/unit/test_chart_drawings/__init__.py`
  - `Develop/backend/tests/unit/test_chart_drawings/test_chart_drawings_crud.py` (11 тестов)
- **Файлы (MOD):** `Develop/backend/app/main.py` — `+chart_drawings_router`
  под префиксом `/api/v1/charts`.
- **Тесты:** `pytest tests/unit/test_chart_drawings/ -v` → **11/11 passed**.
  Покрытие: full CRUD lifecycle, ownership PATCH/DELETE → 404, delete-nonexistent → 404,
  валидация (hline без price / trendline без p2 / unknown type), bulk-list filter
  по (ticker, tf) с изоляцией от чужих user, clear-all не трогает другого user,
  401 без токена.
- **Полный backend pytest:** `pytest tests/ -q` → **885 passed / 0 failed** (86s).
  Baseline после OPS-волны = 867 passed. +18 моих за день
  (5 wizard + 11 chart_drawings + 2 от OPS positive PDF).
- **Lint:** `ruff check app/users app/chart_drawings app/auth app/main.py`
  → All checks passed!
- **Integration verification:**
  - `grep -rn "chart_drawings" app/` → присутствует в `app/main.py`,
    `app/chart_drawings/{router,schemas,__init__}.py`, `app/common/models.py`.
  - `grep -rn "from app.users\|from app.chart_drawings" app/` → импорты в `main.py`.
- **Координация с FRONT1:** контракт `chartDrawingsApi.ts` совпадает 1:1
  (включая `id: string`, `data: DrawingPayload`, `style: DrawingStyle`).
  При следующем запуске frontend перейдёт с localStorage-fallback на live backend
  без изменений в api-клиенте.
- **Применённые Stack Gotchas:**
  - **#20 (FastAPI route ordering):** статические маршруты `/drawings/{id}` (PATCH/DELETE)
    заведены **выше** динамических `/{ticker}/{tf}/drawings` — иначе FastAPI
    интерпретирует `drawings` как `ticker` и матчит неверный шаблон.
- **URL contract delta vs промпт:** промпт указывал префикс
  `/api/v1/chart_drawings`, но frontend api-клиент уже использует
  `/api/v1/charts/{ticker}/{tf}/drawings`. Чтобы избежать schema drift и
  не править frontend, заведено под префиксом `/api/v1/charts` (frontend = SoT).

---

## 2026-04-26 — Fix-волна BACK2: вынос wizard endpoint в `app.users` (контракт C6 URL-fix)

- **Что:** wizard endpoint `POST /me/wizard/complete` перенесён из `/api/v1/auth/*`
  в новый модуль `app/users/` под путём `POST /api/v1/users/me/wizard/complete`
  (как и было задумано в контракте C6). Заказчик в W2 fix-wave потребовал чистоты —
  без deprecated alias'а в auth/router.
- **Что ещё:** добавлен прокси `GET /api/v1/users/me` (тот же `UserResponse`,
  что и `GET /api/v1/auth/me`), чтобы фронт мог постепенно мигрировать на
  единый префикс `/users/*` без двойного запроса.
- **Файлы (NEW):**
  - `Develop/backend/app/users/__init__.py`
  - `Develop/backend/app/users/router.py`
  - `Develop/backend/app/users/schemas.py` (`WizardCompleteResponse` перенесён сюда)
  - `Develop/backend/tests/unit/test_users/__init__.py`
  - `Develop/backend/tests/unit/test_users/test_wizard.py` (5 тестов)
- **Файлы (MOD):**
  - `Develop/backend/app/auth/router.py` — удалён endpoint и импорт `WizardCompleteResponse`
  - `Develop/backend/app/auth/schemas.py` — `WizardCompleteResponse` удалён (вынесен в users)
  - `Develop/backend/app/main.py` — добавлен `users_router` под `/api/v1/users`
- **Файлы (DEL):**
  - `Develop/backend/tests/unit/test_auth/test_wizard.py` — переехал в `test_users/`
- **Тесты:** `pytest tests/unit/test_users/ -v` → 5/5 passed (включая новый
  тест `test_legacy_auth_wizard_path_returns_404` и `test_complete_wizard_idempotent`).
- **Integration:** `grep -rn "users/me/wizard/complete"` → присутствует только
  в `app/users/router.py` + соответствующих тестах. Фронт пока бьёт `/auth/me` —
  миграция фронта в `FRONT2 sub-wave 2`. Backward compat для `GET /auth/me` сохранён.

---

## 2026-04-25 — BACK2 W2 sub-wave 1: реализация 7.1-be / 7.3 / 7.8-be / 7.18 + 29 тестов

- **Что 7.1-be:** реализованы 4 endpoint'а версионирования (контракт C4 published):
  `GET /strategy/{id}/versions/list`, `GET /strategy/{id}/versions/by-id/{ver_id}`,
  `POST /strategy/{id}/versions/snapshot`, `POST /strategy/{id}/versions/{ver_id}/restore`.
  Политика «авто-снимок на Save с idempotency 5 мин» в `StrategyService.create_version`,
  history-preserving `restore_version()`.
- **Что 7.3:** CSV экспорт работает полностью (`csv.DictWriter` нативно — `#metric`+`#trades` блоки),
  PDF endpoint реализован с lazy-import WeasyPrint и возвращает HTTP 503 с ссылкой на skip-тикет,
  если WeasyPrint не установлен. Файлы: `app/backtest/export.py` (NEW), `app/backtest/router.py` (+ endpoint).
- **Что 7.8-be:** endpoint `POST /api/v1/auth/me/wizard/complete` + расширение `UserResponse`
  с полем `wizard_completed_at` (контракт C6 published). Урегулирование URL: т.к. в репозитории
  нет `app/users/`, маршрут смонтирован под `/auth/me/wizard/complete` (фронт уже использует `/auth/me`).
- **Что 7.18:** новый модуль `app/ai/slash_context.py` — резолверы для chart/backtest/strategy/session/portfolio,
  ownership-check + sanitization + prompt-injection защита через `[CONTEXT]...[/CONTEXT]` + `[USER]...[/USER]`.
  Расширение `ChatRequest` полем `context_items: list[ChatContextItem]` (контракт C3 published).
  Подключение в `_build_messages` обоих /chat и /chat/stream.
- **Файлы:**
  - `Develop/backend/app/strategy/{router,service,schemas,models}.py` (изменены)
  - `Develop/backend/app/auth/{router,schemas,models}.py` (изменены)
  - `Develop/backend/app/ai/{chat_router,chat_schemas}.py` (изменены) + `app/ai/slash_context.py` (NEW)
  - `Develop/backend/app/backtest/{router,export}.py` (router изменён, export NEW)
  - `Develop/backend/tests/unit/test_strategy/test_versioning.py` (NEW, 6 тестов)
  - `Develop/backend/tests/unit/test_auth/test_wizard.py` (NEW, 3 теста) + `__init__.py`
  - `Develop/backend/tests/unit/test_ai/test_slash_context.py` (NEW, 13 тестов)
  - `Develop/backend/tests/unit/test_backtest/test_export.py` (NEW, 7 тестов)
  - `Develop/stack_gotchas/gotcha-20-fastapi-static-vs-int-path.md` (NEW) + `INDEX.md` (+1 строка)
  - `Спринты/Sprint_8_Review/backlog.md` (NEW, S7R-PDF-EXPORT-INSTALL)
- **Применённые gotchas:** #11 (миграции без drift), #12 (batch_alter_table + FK naming).
- **Новый gotcha:** #20 — FastAPI route ordering (статический сегмент `/list` после
  `/{int_param}` → 422). Зафиксирован в `gotcha-20-fastapi-static-vs-int-path.md`.
- **Skip-тикет:** `S7R-PDF-EXPORT-INSTALL` (установить WeasyPrint + системные `pango/cairo`).
- **Тесты:** 29 новых passed, полный suite `pytest tests/ -q` → **866 passed / 0 failed**.
- **Линтер:** `ruff check` по 12 изменённым файлам — All checks passed.
- **Контракты опубликованы:** C3 (ChatContextItem schema + slash_context resolvers),
  C4 (alembic + 4 endpoints), C6 (alembic + wizard endpoint + UserResponse).

## 2026-04-25 — DEV-3 (FRONT1) W2 sub-wave 1 PHASE1: 7.6 Drawing tools

- **Что:** реализованы инструменты рисования на ChartPage по UX-макету `Sprint_7/ux/drawing_tools.md`. Тулбар (cursor / trendline / hline / vline / rect / label / edit-list / delete / clear) слева от графика, hotkeys V/T/H/R/L/Esc/Delete, ARIA-labels, role=toolbar. Рендер фигур: hline → нативный `series.createPriceLine`; trendline / rect / vline / label → overlay-canvas через `chart.timeScale().timeToCoordinate` + `series.priceToCoordinate`. Preview во время двух-клик-фигур; Esc отменяет. Persist: REST `/api/v1/charts/{ticker}/{tf}/drawings` (контракт по ARCH-delta §8 + ТЗ §3.14) с fallback на localStorage `drawings:{userId}:{ticker}:{tf}` (квота 100 объектов на ключ).
- **⚠️ BACKEND-PENDING:** модель `chart_drawings` в БД есть, REST-router НЕ реализован. Frontend работает через fallback — оставляет `local-*` id, отображает рисунки локально. Технический долг для S7 фиксы или S8 (нужны 5 endpoint'ов: list / create / patch / delete / clear-all).
- **Файлы (NEW):**
  - `Develop/frontend/src/api/chartDrawingsApi.ts` — REST CRUD клиент.
  - `Develop/frontend/src/utils/drawingsPersistence.ts` — localStorage fallback + квота-лимит.
  - `Develop/frontend/src/stores/chartDrawingsStore.ts` — Zustand store: items / currentTool / selectedId / backendAvailable / warning, actions add/update/remove/clearAll/setContext с optimistic update.
  - `Develop/frontend/src/components/charts/DrawingToolbar.tsx` — Mantine тулбар (`role=toolbar`, ARIA, hotkeys, edit Modal, clear confirm Modal).
  - `Develop/frontend/src/components/charts/DrawingsLayer.tsx` — overlay-canvas (рендер figures + preview), subscribeClick / subscribeCrosshairMove, координатные конверсии.
  - Тесты: `utils/__tests__/drawingsPersistence.test.ts` (9), `stores/__tests__/chartDrawingsStore.test.ts` (8), `components/charts/__tests__/DrawingToolbar.test.tsx` (12).
- **Файлы (MODIFIED):**
  - `Develop/frontend/src/components/charts/CandlestickChart.tsx` — новый optional prop `onChartReady?: (chart, series) => void`, вызывается после addSeries и при cleanup. Без поломок существующего поведения (alertLines / crosshair / WS streaming).
  - `Develop/frontend/src/pages/ChartPage.tsx` — Group layout: `<DrawingToolbar/> <Box ref=chartContainerRef>{<CandlestickChart onChartReady=...>}{<DrawingsLayer chart series container/>}</Box>`. useEffect → `setDrawingsContext(userId, ticker, currentTimeframe)`. Notification бэйдж для `drawingsWarning`.
- **Применённые Stack Gotchas:**
  - **#16 (401 race):** не релевантно напрямую — fallback на localStorage не зависит от token; setContext сам не упадёт при 401, store просто запишет `backendAvailable=false`.
  - **lightweight-charts cleanup:** overlay canvas + priceLines удаляются в return useEffect (DrawingsLayer cleanup). При смене series (chart.remove) — onChartReady(null,null) триггерит снятие subscribeClick/subscribeCrosshairMove.
  - **localStorage quota (UX W0 кандидат):** реализован hard-limit `MAX_DRAWINGS_PER_KEY=100` + try/catch QuotaExceededError → toast пользователю.
- **Новый кандидат на Stack Gotcha** (для ARCH-ревью оформит файл): «lightweight-charts time coordinate offset» — `chart.timeScale().timeToCoordinate(time)` ожидает Time в формате серии. CandlestickChart прибавляет `MSK_OFFSET_SEC=10800` к UTC, поэтому DrawingsLayer ОБЯЗАН делать ту же конверсию (`isoToTime` в DrawingsLayer.tsx:24 + обратное вычитание при subscribeClick `time - MSK_OFFSET_SEC`). Без этого фигуры рисуются со сдвигом 3 часа.
- **Sequential mode (intraday):** в текущей реализации drawing tools в sequential-режиме (intraday TF) не поддержаны — `time` там это индекс свечи, а не unix-сек. Записано как известное ограничение, отдельная задача в backlog (или PHASE2).
- **Тесты:** `pnpm test` → **316 passed (61 files)** (baseline 287/58, +29). `npx tsc --noEmit` → 0 errors.
- **Integration verification:** `grep -rn "DrawingToolbar\|DrawingsLayer\|useChartDrawingsStore" src/pages/` → ChartPage.tsx (production использование). Не только в тестах.
- **Скриншоты:** dev-сервера (frontend:5173, backend:8000) не запущены в среде агента → Playwright-скриншот **не сделан**. Прошу заказчика приложить скриншот в ходе ручной приёмки.

## 2026-04-25 — BACK1 W2 sub-wave 1: 7.2-be Grid Search backend (C5 published)

- **Что:** Опубликован контракт **C5** (`POST /api/v1/backtest/grid`). FRONT2 виджет Grid Search разблокирован. Прогресс/результат — через переиспользованный WS `/ws/backtest/{job_id}` (контракт C2 W1) с финальным payload `result.matrix=[{params, sharpe, pnl, win_rate, drawdown, trades_count}]` + `overfitting_warning: bool`.
- **Архитектура:** `GridSearchEngine` оркестрирует комбинации через `asyncio.Semaphore(cpu-1)` + thread executor (BacktestEngine.run уже в `loop.run_in_executor`). **Отступление от ТЗ §5.3.4** (Pool → Semaphore) обосновано: BacktestEngine async, multiprocessing требует переписать engine ради IPC pickle. Зафиксировано в новом gotcha-21.
- **Hard caps:** ≤5 параметров, ≤1000 комбинаций (raise 422 ValidationError при превышении до постановки в очередь). Per-user cap=3 наследуется от BacktestJobManager (W1).
- **Decimal-coerce:** open question из W1 (params_json через `default=str` → строка) закрыт — `_coerce_param_value` восстанавливает int/Decimal перед запуском runner.
- **Overfitting:** flag по правилу arch §2.2 Q7 — `(sharpe[0] - sharpe[4]) / sharpe[0] > 0.5`.
- **Файлы:**
  - `Develop/backend/app/backtest/grid.py` (NEW)
  - `Develop/backend/app/backtest/schemas.py` (+`GridSearchRequest`, +`GridJobResponse`)
  - `Develop/backend/app/backtest/router.py` (+`POST /grid` endpoint, +`_make_grid_runner` helper)
  - `Develop/backend/tests/unit/test_backtest/test_grid.py` (NEW, 22 теста — engine + validators)
  - `Develop/backend/tests/unit/test_backtest/test_grid_endpoint.py` (NEW, 8 тестов — endpoint contract C5)
  - `Develop/stack_gotchas/gotcha-21-grid-multiprocessing-vs-async.md` (NEW)
  - `Develop/stack_gotchas/INDEX.md` (+ строка #21)
- **Результат:** `pytest tests/ -q` → **866 passed / 0 failed** (baseline 771 → +95 тестов W1+W2 BACK1+BACK2). Ruff на затронутых файлах — no issues.
- **Контракты для FRONT2:** C5 + C9 опубликованы — FRONT2 разблокирован для виджетов баланса и Grid Search.

## 2026-04-25 — BACK1 W2 sub-wave 1: 7.7-be Account balance/history (C9 published)

- **Что:** Опубликован контракт **C9** (`GET /api/v1/account/balance/history?days=N`). FRONT2 виджет «Баланс» (sparkline) разблокирован.
- **Решение по источнику:** агрегация on-the-fly (TradingSession.initial_capital + cumulative DailyStat.realized_pnl + текущий PaperPortfolio.balance для today). **Без** APScheduler-job снимков — это снимет потребность в новой таблице/миграции, sparkline 30 точек в виджете точечно обходится без полноценного timeseries.
- **Файлы:**
  - `Develop/backend/app/account/__init__.py` (NEW — модуль)
  - `Develop/backend/app/account/schemas.py` (NEW — `BalanceHistoryPoint`, `BalanceHistoryResponse`)
  - `Develop/backend/app/account/service.py` (NEW — `AccountService.get_balance_history`)
  - `Develop/backend/app/account/router.py` (NEW — endpoints `/balance/history` и `/balance/history/full`)
  - `Develop/backend/app/main.py` (+1 импорт, +1 include_router)
  - `Develop/backend/tests/unit/test_account/__init__.py` + `test_balance_history.py` (NEW — 9 тестов)
- **Применённые gotchas:** #08 (in-memory aiosqlite + StaticPool в фикстурах не нужны — обычная sessionmaker работает, get_db переопределён через dependency_override).
- **Результат:** `pytest tests/unit/test_account/ -q` → 9 passed. `ruff check app/account/ app/main.py` → no issues. py_compile — 0 errors.

## 2026-04-25 — BACK2 W2 sub-wave 1: миграции strategy_versions + users.wizard_completed_at (C4 + C6 published)

- **Что:** Опубликован контракт **C4** (strategy_versions: +created_by, +comment, idx_sv_history). FRONT2 разблокирован.
- **Что:** Опубликован контракт **C6** (users.wizard_completed_at). FRONT2 wizard разблокирован.
- **Файлы:**
  - `Develop/backend/alembic/versions/c1d4e5f6a7b8_add_strategy_versions_meta.py` (NEW, revision c1d4e5f6a7b8 от a7b2c83d4e51)
  - `Develop/backend/alembic/versions/d2e3f4a5b6c7_add_users_wizard_completed_at.py` (NEW, revision d2e3f4a5b6c7 от c1d4e5f6a7b8)
  - `Develop/backend/app/strategy/models.py` (+created_by, +comment, idx_sv_history)
  - `Develop/backend/app/auth/models.py` (+wizard_completed_at)
- **Применённые gotchas:** #11 (миграция содержит ТОЛЬКО намеренное изменение), #12 (batch_alter_table + naming_convention для FK).
- **Результат:** `alembic upgrade head` → ok; `alembic downgrade -2 → upgrade head` round-trip успешен. Текущий head = `d2e3f4a5b6c7`.

## 2026-04-25 — Планирование Sprint 7

- **Что:** Утверждён spec `sprint_design.md` (5 секций + 4 приложения, 17 задач + 7.R).
- **Что:** Создан `sprint_implementation_plan.md` (21 задача) для разворачивания файлов спринта.
- **Что:** Развёрнуты файлы спринта inline-исполнением плана: README, sprint_state, preflight, changelog, execution_order, e2e_test_plan, 9 промптов, 6 UX-плейсхолдеров, reports/.gitkeep.
- **Файлы:** `Sprint_7/*` (~22 файла), указатели в `docs/superpowers/{specs,plans}/`.
- **Решения:**
  - AI слэш-команды включены в S7 как 7.18/7.19 (требуют обновления ФТ/ТЗ/плана на 7.R).
  - Блок A — все 7 Should-задач (7.1–7.9 без 7.4/7.5, закрытых в S6).
  - 6 переносов из S6 закрываем все (7.12–7.17), debt first.
  - Подход 2 — параллельные треки с pre-sprint W0.
  - RACI-корректировка: 7.1 → BACK2 (Strategy Engine), 7.12 → BACK2 (Notification Service).
- **Ветка:** `docs/sprint-7-plan` (имя подтверждено заказчиком, базовая `main`).
- **Результат:** 17 задач, ~14 рабочих дней, гибкое продление при необходимости. Файлы спринта готовы к запуску W0.

## 2026-04-25 — QA W0 (E2E план + preflight)

- **Что:** заполнен `e2e_test_plan_s7.md` — 47 сценариев на 17 задач (TBD устранены), карта регрессии 16 групп ui-checks, performance-таблица, кандидаты на skip-тикеты.
- **Что:** pre-flight окружения (W0 часть) пройден: Python 3.11.15, Node v20.20.1, pnpm 9.15.9, playwright 1.59.1, venv/node_modules/playwright.config — на месте; sergopipo (id=1) подтверждён в `Develop/backend/data/terminal.db`.
- **Что:** длительные пункты (uvicorn/pnpm dev, baseline pytest/vitest, baseline E2E 119/0/3) помечены `⏸️ deferred to W1`.
- **Файлы:** `Sprint_7/e2e_test_plan_s7.md`, `Sprint_7/reports/QA_W0_test_plan.md`.
- **Замечание:** текущая ветка `main` (план: `docs/sprint-7-plan`) — оркестратор согласует перед коммитом DEV W1. UX-макеты в `ux/` пока плейсхолдеры — `data-testid` в плане ожидаемые, точечно правятся после публикации UX W0.
- **Результат:** QA-часть гейта W0 → W1 готова. Блокеров на старт DEV нет.

## 2026-04-25 — ARCH W0 (design ревью + brainstorm 6 задач)

- **Что:** создан `arch_design_s7.md` — 10 секций, дословные цитаты ТЗ/ФТ для каждой подзадачи, brainstorm-итерации (вопрос → варианты → решение → обоснование) для 7.1, 7.2, 7.13, 7.15, 7.17, 7.18.
- **Что:** §1 Версионирование: расширение существующей `strategy_versions` (`+created_by`, `+comment`), политика «авто-снимок на Save с idempotency 5 мин» + явная именованная версия + history-preserving restore. DDL подготовлен для DEV-2 W2.
- **Что:** §2 Grid Search: `multiprocessing.Pool` (workers = cpu-1), hard cap 1000 комбинаций ≤ 5 параметров, переиспользуем `/ws/backtest/{job_id}` с `result.matrix`, overfitting-предупреждение по разбросу sharpe.
- **Что:** §3 5 event_type → runtime: добавлены EVENT_MAP записи (`trade.opened`, `order.partial_fill`, `order.error`, `connection.lost`, `connection.restored`); указаны file:line publish-сайтов (engine.py on_order_filled, OrderManager.process_signal helper, multiplexer.py:207/213). Анти-спам флаг для connection_lost.
- **Что:** §4 WS `/ws/trading-sessions/{user_id}`: auth через первое сообщение (паттерн ТЗ §4.12), snapshot+delta, подписка на `system:{user_id}` для динамики, удаление polling 10s одним PR.
- **Что:** §5 фоновые бэктесты: новая таблица `backtest_jobs` (DDL готов), per-user cap 3, кастомный executor (asyncio.create_task + BacktestJobManager в app.state, не FastAPI BackgroundTasks), WS-канал закрывается через 30 сек после терминала.
- **Что:** §6 AI context: `ChatRequest.context: list[ContextItem]` с типами {chart, backtest, strategy, session, portfolio}; защита — Pydantic + ownership-check + sanitization + `[CONTEXT]...[/CONTEXT]` prefix + rate-limit 10/min. Frontend парсит slash-команды локально.
- **Что:** §7 Stack Gotchas pre-read: 7 ключевых ловушек выписаны (#04, #08, #11, #12, #15, #16, #17) с привязкой к задачам S7.
- **Что:** §8 UX-стыки: 6 макетов проверены, найдена 1 delta — нужен новый легковесный endpoint `GET /api/v1/account/balance/history?days=30` для sparkline в виджете баланса (контракт C9 NEW).
- **Что:** §9 Cross-DEV контракты — добавлен C9 (balance/history); C1-C8 синхронизированы со sprint_design.
- **Файлы:** `Sprint_7/arch_design_s7.md`, `Sprint_7/reports/ARCH_W0_design.md`.
- **Плагины:** WebSearch — JWT WS auth и multiprocessing.Pool best practices; superpowers:brainstorming — итерации внутри секций; context7 не вызывался (паттерны стабильные, проверены в коде).
- **Результат:** ARCH-часть гейта W0 → W1 готова. Блокеры для старта W1 — нет. Alembic-миграции отложены на W2 (по DDL §1.3 и §5.3).

## 2026-04-25 — UX W0 (6 макетов)

- **Что:** заполнены все 6 макетов в `Sprint_7/ux/*.md` по `prompt_UX.md` секция «Задачи W0». Плейсхолдеры заменены полным содержимым: ASCII-mockup, состояния (loading/empty/error/success), поведение, контракт с backend, a11y, тестовые сценарии для QA с `data-testid`, Stack Gotchas замечания.
- **Что:** проведено согласование с `arch_design_s7.md` §8 — внесены ARCH-delta:
  - `drawing_tools.md` — persist в БД (`chart_drawings` по ТЗ §3.14), не в localStorage.
  - `dashboard_widgets.md` — sparkline через новый endpoint C9 `GET /api/v1/account/balance/history?days=30`.
  - `background_backtest_badge.md` — per-user cap = 3 (а не 5–10), bootstrap через `GET /api/v1/backtest/jobs?status=running`, отмена через `DELETE /api/v1/backtest/jobs/{id}`, WS-канал закрывается через 30s после терминала.
- **Файлы:**
  - `Спринты/Sprint_7/ux/dashboard_widgets.md` (7.7)
  - `Спринты/Sprint_7/ux/wizard_5steps.md` (7.8)
  - `Спринты/Sprint_7/ux/drawing_tools.md` (7.6)
  - `Спринты/Sprint_7/ux/backtest_overview_analytics.md` (7.16)
  - `Спринты/Sprint_7/ux/background_backtest_badge.md` (7.17)
  - `Спринты/Sprint_7/ux/ai_commands_dropdown.md` (7.18/7.19)
  - `Спринты/Sprint_7/reports/UX_W0_design.md` (новый)
- **Кандидаты в Stack Gotchas:** localStorage quota для drawings; bucket-edge inclusivity для гистограммы P&L; WS reconnect storm на reload; 403 vs 404 ownership leak в AI-context. ARCH регистрирует на 7.R.
- **Результат:** UX-часть гейта W0 → W1 готова. Блокеров нет.

## 2026-04-25 — DEV-2 W1 (BACK2): 7.12 NS singleton DI + 7.14 Telegram callbacks

- **Задача 7.12 (контракт C7 — поставщик):**
  - **Что:** опубликован FastAPI Depends-helper `get_notification_service` для singleton'а NotificationService. Все потребители вне `main.py` берут сервис только через `app.state.notification_service` либо `Depends(get_notification_service)`. Ранее `app/market_data/router.py:84` создавал `PriceAlertMonitor(db_factory=None)` без NS — уведомления о ценовых алертах вне in-app канала молча терялись. Теперь `PriceAlertMonitor` создаётся один раз в lifespan вместе с NS singleton'ом и кладётся в `app.state.price_alert_monitor`.
  - **Файлы:** `app/notification/dependencies.py` (новый), `app/notification/__init__.py` (экспорт helper'а), `app/main.py` (PriceAlertMonitor singleton в lifespan), `app/market_data/router.py` (read singleton из `app.state`, добавлен `request: Request`).
  - **Контрактная проверка C7:** `grep -rn "NotificationService()" app/` → 0 совпадений вне `main.py`. Потребители DI: `app/backtest/router.py:314,485` (через `app.state.notification_service`), все `app/trading/`, `app/scheduler/`, `app/market_data/price_alert_monitor.py` (через ctor injection из main).
- **Задача 7.14 (контракт C8 — поставщик):**
  - **Что:** доработан `_handle_callback` в `TelegramWebhookHandler` — по `open_session:{id}` теперь идёт ownership-check (`Strategy.user_id == user.id` через JOIN на `StrategyVersion → TradingSession`); по `open_chart:{ticker}` — валидация тикера (alnum + `_`, ≤ 20 симв) и deep link через новый `settings.FRONTEND_URL`. Раньше `open_chart:` принимал id и не строил deep link на фронтенд.
  - **Что:** `TelegramNotifier.send` принимает `ticker` отдельным аргументом — `_build_keyboard` теперь корректно собирает `open_chart:{ticker}` для price_alert/trade-уведомлений (раньше использовался id алерта/трейда). `NotificationService.dispatch_external` резолвит ticker по `related_entity_type` (`instrument` → `PriceAlert.ticker`, `trade` → `LiveTrade.session.ticker`).
  - **Файлы:** `app/notification/telegram_webhook.py`, `app/notification/telegram.py`, `app/notification/service.py`, `app/config.py` (новый `FRONTEND_URL`).
  - **Deep link формат:** `{FRONTEND_URL}/trading?session={id}` для сессий, `{FRONTEND_URL}/chart/{TICKER}` для тикеров.
- **Тесты:**
  - `tests/test_notification/test_singleton_di.py` (5 тестов: helper-singleton, dual-call same id, RuntimeError при пустом state, override через state, и контрактный grep на отсутствие `NotificationService()` вне main.py).
  - `tests/test_notification/test_telegram_callbacks.py` (7 тестов: deep link, uppercase ticker, отказ на мусорный ticker, owned session → deep link, foreign session → 404, unlinked chat → отказ, invalid id).
  - Запуск: `pytest tests/test_notification/ tests/unit/test_notification/ -q` — **61 passed, 0 failed**.
  - Полный subset (без trading/market_data/circuit_breaker — параллельная работа BACK1) — **604 passed**. В `test_trading/test_order_manager.py::test_process_buy_signal` фиксируется failure, но это территория BACK1 (изменён OrderManager, BUY-сигнал теперь сразу `filled` вместо `pending`) — не связано с 7.12/7.14.
- **Stack Gotchas:** прочитаны #11 (alembic drift — миграций в W1 нет), #12 (sqlite batch_alter — миграций нет), #17 (telegram bot frozen attrs — в новых тестах используются stub-объекты, патч `Bot.send_message` не нужен). Новых ловушек не найдено.
- **Плагины:** pyright fallback `python -m py_compile` после каждого Edit — 0 ошибок. context7/WebSearch не вызывались (FastAPI Request, python-telegram-bot 20+ уже использовались в S6).
- **Cross-DEV координация:** BACK1 параллельно расширил `EVENT_MAP` (5 новых event_type для 7.13) и добавил `listen_broker_status()` — конфликтов в `service.py` нет, изменения дополняют друг друга.
- **Результат:** W1 BACK2 ✅. Контракты C7, C8 опубликованы первыми (как требуется в `execution_order.md` «Контрактные точки W1»). Готов к ARCH midsprint checkpoint после завершения BACK1/FRONT1.

## 2026-04-25 — W0 завершён, гейт W0 → W1 закрыт

- **Что:** оркестратор свёл отчёты ARCH/UX/QA, проверил гейт W0 → W1.
- **Гейт W0 → W1 (по `execution_order.md` §3 «Гейт W0 → W1»):**
  - ✅ ARCH `arch_design_s7.md` опубликован (618 строк, 10 секций, 6 design-точек).
  - ✅ UX 6 макетов в `ux/` опубликованы без TBD.
  - ✅ QA `e2e_test_plan_s7.md` заполнен (47 сценариев на 17 задач, без TBD).
  - 🟡 `preflight_checklist.md` — облегчённый прогон W0 (11 ✅ / 2 ⚠️ / 17 ⏸️ deferred to W1). Длительные пункты (полный pytest, baseline E2E 119/0/3, uvicorn/pnpm dev) корректно отложены на старт W1 — это первый шаг QA на W1.
- **Синхронизация контракта C9:** `GET /api/v1/account/balance/history?days=30` (BACK1 → FRONT2 для виджета «Баланс», 7.7) добавлен в `execution_order.md` (таблица контрактов + W2 BACK1 + контрактные точки). 7.7-be передан BACK1 в W2.
- **Файлы:** `Спринты/Sprint_7/execution_order.md` (C9, W2 BACK1, contract sync), `Спринты/Sprint_7/sprint_state.md` (W0 завершён, C9 добавлен в риски).
- **Открытые вопросы для заказчика перед W1:**
  - Ветка корневого Test для коммита W0-артефактов (сейчас работа на `main`; preflight ожидает `docs/sprint-7-plan` или согласованную).
  - Ветка Develop/ для DEV-агентов W1 (сейчас `s6r/code-fixes`).
- **Результат:** W0 ✅. Готовы к старту W1 — параллельный запуск BACK1 + BACK2 + FRONT1 (6 debt-переносов). Ожидание команды заказчика.

## 2026-04-25 — DEV-1 W1 (BACK1): 7.13 event_type + 7.15-be WS sessions + 7.17-be фоновый бэктест

- **Задача 7.13 (debt из S6, MR.5):** к runtime подключены 5 новых event_type через `EVENT_MAP` + publish-сайты в production-коде.
  - **EVENT_MAP** (`app/notification/service.py`): добавлены `trade.opened`, `order.partial_fill`, `order.error`, `connection.lost`, `connection.restored` с `severity` и шаблонами (полный набор плейсхолдеров покрыт unit-тестом контракта payload ↔ template, защита от регрессии gotcha-19).
  - **engine.py:** в `OrderManager.process_signal` критическая секция (insert LiveTrade + commit) обёрнута в try/except → `order.error`. После paper-fill публикуется `trade.opened`. В `PositionTracker.on_order_filled`: при `filled_lots < volume_lots` → `order.partial_fill` (вместо `trade.filled`); иначе — `trade.filled` + `trade.opened` (real-mode параллельный publish).
  - **multiplexer.py:** в `_run_stream` reconnect-loop вызывается `_publish_connection_event` на канал `broker:status`. Анти-спам флаг `_connection_event_published` — событие `connection.lost` публикуется один раз при первом disconnect, сбрасывается после первого успешного response (тогда же публикуется `connection.restored`). Это аналог gotcha-18 (CB-уведомления спамили на каждой свече).
  - **NotificationService.listen_broker_status / stop_broker_listener:** глобальный listener на канал `broker:status`, фан-аут на всех известных user_id из активных сессий (`_session_user_map`). Подключён в `lifespan` `app/main.py`.
- **Задача 7.15-be (контракт C1, поставщик):** новый файл `app/trading/ws_sessions.py`.
  - `@router.websocket("/ws/trading-sessions/{user_id}")` — auth через первое сообщение `{action:"auth", token:"<jwt>"}` (паттерн ТЗ §4.12, gotcha-16: токен НЕ в URL). После auth_ok сервер шлёт `snapshot` (все active/paused/suspended сессии пользователя через JOIN strategy.user_id) и подписывается на `trades:{sid}` для каждой + `system:{user_id}` для динамического подхвата новых сессий.
  - Маппинг внутренних событий (`order.placed`, `trade.opened`, `trade.filled`, `trade.closed`, `positions.closed_all`, `session.started/stopped/paused/resumed/added`, `pnl.update`) → клиентские (`position_update`, `trade_filled`, `session_state`, `pnl_update`).
  - Custom close codes: 4401 (auth fail), 4403 (user_id mismatch), 4408 (auth timeout). Cleanup всех subscriptions через `try/finally`.
- **Задача 7.17-be (контракт C2, поставщик):** очередь фоновых бэктестов + WS канал.
  - **Таблица `backtest_jobs`** (`app/backtest/models.py:BacktestJob` + alembic миграция `a7b2c83d4e51_add_backtest_jobs.py`): id (uuid hex) PK, user_id/strategy_id/strategy_version_id (FK), job_type/status/progress/params_json/result_json/error_message/timestamps. Индекс `idx_bj_user_active(user_id, status)`. `alembic upgrade head` + `alembic downgrade -1` отработали корректно. Default'ы — литералы (`'queued'`, `0`, `CURRENT_TIMESTAMP`) во избежание gotcha-12.
  - **`BacktestJobManager`** (`app/backtest/jobs.py`): singleton в `app.state.backtest_job_manager`. API: `submit/get/list_user/cancel/shutdown`. Per-user cap = 3 (`DEFAULT_PER_USER_CAP`, см. arch §5.2 Q1) — `_enforce_cap` считает `queued+running` под `asyncio.Lock`. Runner-callable получает `BacktestJobContext` с `publish_progress`. Cancel — `task.cancel()` + `asyncio.shield` для гарантии записи `cancelled` в БД до повторного cancel. Shutdown — отменяет все активные tasks (lifespan).
  - **WS endpoint `/ws/backtest/{job_id}`** (`app/backtest/ws_backtest.py`): auth-first паттерн, ownership-check `job.user_id == decoded_user_id`, snapshot текущего состояния + delta из канала `backtest_job:{job_id}` (events queued/started/progress/done/error/cancelled). Grace period 30 сек после терминального события до close=1000 (см. arch §5.2 Q4).
  - **REST endpoints** (`app/backtest/router.py`): `POST /api/v1/backtest/run-async` (постановка job, переиспользует существующий `_run_backtest_task` через runner-обёртку, возвращает `{job_id, backtest_id, status:"queued"}`), `GET /api/v1/backtest/jobs?status=…` (список jobs пользователя для бейджа в шапке), `GET /api/v1/backtest/jobs/{id}`, `POST /api/v1/backtest/jobs/{id}/cancel`. `JobLimitExceeded` маппится в `ValidationError` (HTTP 400).
- **Файлы (новые):**
  - `app/trading/ws_sessions.py`, `app/backtest/jobs.py`, `app/backtest/ws_backtest.py`
  - `alembic/versions/a7b2c83d4e51_add_backtest_jobs.py`
  - `tests/test_notification/test_runtime_events.py` (16 тестов: payload contract + listener + multiplexer)
  - `tests/test_trading/test_ws_sessions.py` (3 теста: auth/snapshot/delta)
  - `tests/unit/test_backtest/test_jobs.py` (7 тестов: submit/cap/cancel/list/shutdown)
  - `tests/unit/test_backtest/test_ws_backtest.py` (3 теста: auth/ownership/snapshot+progress)
- **Файлы (изменённые):**
  - `app/notification/service.py` (5 новых EVENT_MAP записей, `listen_broker_status`, `_session_user_map`)
  - `app/broker/tinvest/multiplexer.py` (publish connection events + анти-спам флаг)
  - `app/trading/engine.py` (publish trade.opened/order.partial_fill/order.error + helper `_publish_order_error`)
  - `app/backtest/models.py` (модель `BacktestJob`)
  - `app/backtest/router.py` (4 новых endpoint в стиле существующих)
  - `app/main.py` (registration trading_sessions_ws_router + backtest_job_ws_router; lifespan: BacktestJobManager + listen_broker_status; shutdown reverse-order)
- **Тесты:** `pytest tests/ -q` → **770 passed, 1 failed** (failed = pre-existing `test_process_buy_signal`, не связан с моими изменениями: тест ожидает `status=='pending'` после paper-fill, но код мгновенно ставит `filled` ещё с baseline). Baseline до моих изменений: 729 passed → теперь 770 passed (+41 нового теста, все зелёные). Ruff: 0 issues по всем затронутым файлам.
- **Integration verification (`grep -rn`):**
  - 5 publish-сайтов 7.13: 4 в `app/trading/engine.py` (846/885/1171/1201) + 2 в `app/broker/tinvest/multiplexer.py` (221/244). EVENT_MAP — `app/notification/service.py:76-104`.
  - WS sessions: `app/trading/ws_sessions.py:117 @router.websocket("/ws/trading-sessions/{user_id}")` + `app.include_router` в `main.py:188`.
  - WS backtest: `app/backtest/ws_backtest.py:49 @router.websocket("/ws/backtest/{job_id}")` + `app.include_router` в `main.py:190`.
  - `BacktestJobManager(AsyncSessionLocal)` в `app/main.py:85` (production-инстанциация, не только в тестах).
- **Контракты:**
  - C1 (BACK1 → FRONT1, поставщик): WS `/ws/trading-sessions/{user_id}` опубликован раньше FRONT1-клиента — FRONT1 (DEV-3) уже написал клиент по arch_design_s7.md §4.3 параллельно. Совместимость подтверждена: те же event-имена (`position_update`, `trade_filled`, `pnl_update`, `session_state`).
  - C2 (BACK1 → FRONT1, поставщик): WS `/ws/backtest/{job_id}` опубликован. FRONT1 уже использует endpoint в `useBacktestJobWS`. Совместимы события: `queued/started/progress/done/error/cancelled` + поля `progress, result, message`.
  - C7 (BACK2 → BACK1, потребитель): на момент работы BACK2 (DEV-2) уже опубликовал `app.state.notification_service` через DI helper и `PriceAlertMonitor` singleton. BACK1 потребляет: `notification_service.listen_broker_status()` — зарегистрировано в lifespan; `getattr(request.app.state, "notification_service", None)` в backtest_router. **Контракт соблюдён.**
- **Stack Gotchas применены:**
  - **#04 (T-Invest streaming):** publish_connection_event защищён `try/except` — не ломает reconnect-loop. Backoff не изменён.
  - **#08 (AsyncSession.get_bind в pytest):** в тестах `BacktestJobManager` использован отдельный `create_async_engine` + `StaticPool` per-фикстура. `jobs_manager` фикстура с явным shutdown гарантирует, что фоновые tasks не пишут в disposed engine.
  - **#11 (alembic drift):** новая миграция содержит **только** create_table backtest_jobs + create_index, без drift. Проверено визуально.
  - **#12 (sqlite batch_alter):** в миграции — только `create_table`, default'ы `sa.text("'queued'")` / `sa.text("CURRENT_TIMESTAMP")` (литералы), не `func.now()`.
  - **#16 (relogin race):** WS-эндпоинты используют first-message auth (не URL query), как требует ТЗ §4.12 — снимает риск утечки JWT в логи.
  - **gotcha-18-like:** анти-спам флаг для connection.lost (один publish на disconnect-цикл).
- **Новых Stack Gotchas не создавал** — все встретившиеся ловушки покрыты существующими записями.
- **Плагины:** pyright fallback `python -m py_compile` после каждого Edit/Write — 0 ошибок. ruff — 0 issues. context7 не вызывался (FastAPI WebSocket, SQLAlchemy async, alembic — стабильные API из прошлых спринтов). superpowers TDD — итеративные red→green циклы для `BacktestJobManager.cancel()` (нашёл race с asyncio cleanup, добавил `asyncio.shield`).
- **Открытые вопросы:** нет блокеров. Pre-existing fail `test_process_buy_signal` — задача BACK2 в S7 Review (не моя зона).
- **Результат:** W1 BACK1 ✅. Готов к midsprint ARCH-приёмке + интеграции с FRONT1 (контракты C1/C2).

## 2026-04-25 — DEV-3 W1 (FRONT1): 7.16 аналитика + 7.15-fe WS + 7.17-fe бейдж

- **Что (7.16):** реализована вкладка «Обзор» BacktestResultsPage с двумя новыми компонентами — `PnLDistributionHistogram` (бакеты 0.5%, цвета red/yellow/green, пунктирные средние ср.убыток/ср.прибыль) и `WinLossDonutChart` (SVG-donut Win/Loss/BE с центром = total trades). Добавлены интерактивные зоны на ценовом графике (`InstrumentChart`): hover → подсветка зоны (alpha 0.18→0.40) + белый контур; click → раскрывается `TradeDetailsPanel` под графиком (поля entry/exit time/price/reason, P&L, длительность; Esc/× закрывают).
- **Что (7.15-fe):** новый хук `useTradingSessionsWS` (контракт C1) — WS клиент `/ws/trading-sessions/{user_id}` с auth через первое сообщение (gotcha-16: токен НЕ в URL), snapshot+delta события (position_update/trade_filled/pnl_update/session_state), exponential backoff reconnect 1→30s, ping/pong. Удалён `setInterval(fetchSessions, 10000)` в `TradingPage.tsx` — один источник правды (правило C1 execution_order.md §4). На странице добавлен Badge «Online/Переподключение/Auth error» — индикатор состояния WS.
- **Что (7.17-fe):** добавлены `backgroundBacktestsStore` (Zustand + persist в localStorage; cap 3 = `MAX_CONCURRENT_BACKGROUND_BACKTESTS`), хуки `useBacktestJobWS` + `useBackgroundBacktestsBootstrap` (мульти-WS на active jobs), компонент `BackgroundBacktestsBadge` в шапке (Indicator + Popover со списком jobs, прогресс-бары, кнопки «Открыть результат» / cancel / clear). В `BacktestLaunchModal` добавлена кнопка «Запустить в фоне» (модалка остаётся открытой, toast «Бэктест запущен в фоне»; pre-flight check на cap 3). Endpoint fallback: `/backtest/run-async` → `/backtest` если не готов на backend. `authStore.logout()` очищает background-backtests store + localStorage.
- **Файлы (новые):**
  - `src/components/backtest/PnLDistributionHistogram.tsx`
  - `src/components/backtest/WinLossDonutChart.tsx`
  - `src/components/backtest/TradeDetailsPanel.tsx`
  - `src/hooks/useTradingSessionsWS.ts`
  - `src/hooks/useBacktestJobWS.ts`
  - `src/stores/backgroundBacktestsStore.ts`
  - `src/components/notifications/BackgroundBacktestsBadge.tsx`
  - Тесты: `__tests__/PnLDistributionHistogram.test.tsx`, `__tests__/WinLossDonutChart.test.tsx`, `__tests__/TradeDetailsPanel.test.tsx`, `hooks/__tests__/useTradingSessionsWS.test.ts`, `stores/__tests__/backgroundBacktestsStore.test.ts`, `components/notifications/__tests__/BackgroundBacktestsBadge.test.tsx`.
- **Файлы (изменённые):**
  - `src/pages/BacktestResultsPage.tsx` — вкладка «Обзор» расширена, вкладка «График» получает onZoneClick + панель деталей.
  - `src/components/backtest/InstrumentChart.tsx` — onZoneClick prop, mouseMove/click handlers, hover-подсветка.
  - `src/pages/TradingPage.tsx` — polling удалён, useTradingSessionsWS подключён + статус-Badge.
  - `src/components/backtest/BacktestLaunchModal.tsx` — кнопка «Запустить в фоне», `handleSubmitBackground` + toast.
  - `src/api/backtestApi.ts` — `launchBackground`, `listJobs`, `cancelJob`, типы `BacktestJob`.
  - `src/components/layout/Header.tsx` — `<BackgroundBacktestsBadge />` справа от NotificationBell.
  - `src/stores/authStore.ts` — clear background-backtests при logout (gotcha-16 cleanup chain).
- **Контракты (потребитель):**
  - C1 от BACK1: WS `/ws/trading-sessions/{user_id}` — клиент написан по схеме arch_design_s7.md §4.3 (auth-сообщение, snapshot, delta-events). На mock-WS интегрирован в unit-тестах. Ожидаем backend от DEV-1.
  - C2 от BACK1: WS `/ws/backtest/{job_id}` — клиент написан по схеме §5.4 (queued/started/progress/done/error/cancelled). Endpoint REST fallback /backtest для S6-совместимости.
- **Тесты:** 287 passed / 0 failed (vitest, 58 test files). Новых: 6 файлов, ~30 unit-тестов. `npx tsc --noEmit` → 0 errors.
- **Lint:** наши файлы чистые. Остаются 6 ошибок в pre-existing файлах (CandlestickChart, SessionDashboard, ChartPage, ProfileSettingsPage, priceAlertStore) — не блокируют W1.
- **Stack Gotchas применены:** #16 (token НЕ в URL — auth первым WS-сообщением), Mantine modal lifecycle (BacktestLaunchModal не закрывается на «в фоне»), lightweight-charts cleanup (rAF + event listeners в return useEffect).
- **Результат:** W1 FRONT1 закрыт. Готов к midsprint UX-приёмке + интеграции с C1/C2 от BACK1 после публикации backend WS-эндпоинтов.

## 2026-04-25 — Фикс pre-existing pytest fail (test_process_buy_signal)

- **Что:** обновлён `test_process_buy_signal` (`Develop/backend/tests/test_trading/test_order_manager.py`). Старое ожидание `trade.status == "pending"` было некорректно для фикстуры `test_session.mode == "paper"`: paper-mode мгновенно филит ордер по signal price (см. `OrderManager.process_signal` ветка `if session.mode == "paper"`), эта логика существует с S5/S5R, не от 7.13. Тест был сломан в baseline `s6r/code-fixes` ещё до старта S7.
- **Изменение:** `assert trade.status == "filled"` + добавлен инвариант `trade.filled_lots == trade.volume_lots`. Дописан docstring с пояснением paper-инварианта.
- **Файлы:** `Develop/backend/tests/test_trading/test_order_manager.py` (1 файл, 1 тест).
- **Тесты:** `pytest tests/test_trading/test_order_manager.py -v` → **8/8 passed**. Полный suite `pytest tests/ -q` → **771 passed, 0 failed** в 78.82s. До фикса: 770 passed / 1 failed.
- **Расследование:** diff `s6r/code-fixes..s7/sprint-7` по `app/trading/engine.py` показал, что BACK1 (7.13) добавил вокруг создания трейда try/except и публикацию `trade.opened`, но логику filling не менял — регрессии нет.
- **Открытый вопрос:** покрытие real-mode сценария (`status="pending"` сразу после выставления) сейчас отсутствует — тикет на 7.R: добавить отдельный тест с фикстурой real-mode либо `@pytest.mark.parametrize`.
- **Результат:** baseline backend pytest зелёный, готовы к midsprint checkpoint.

## 2026-04-25 — DEV-5 W2 (OPS): 7.9 Backup/restore (BackupService + APScheduler + CLI)

- **Что:** реализована задача 7.9 — `BackupService` (snapshot/rotate/restore с WAL-aware copy для SQLite + ветка Postgres через `pg_dump --format=custom`/`pg_restore --clean --no-owner --single-transaction`), регистрация ежедневного APScheduler-job `backup_db_daily` в существующем `SchedulerService` (расписание из `settings.BACKUP_CRON`, дефолт 03:00 UTC, misfire_grace_time=3600), CLI `python -m app.cli.backup {create,list,restore,rotate}` на `argparse` (без новой зависимости — typer не в `pyproject.toml`).
- **Тип БД:** определён как **SQLite** (по `app/config.py`: `DATABASE_URL=sqlite+aiosqlite:///./data/terminal.db`, WAL включён в `app/common/database.py:47`). Postgres-ветка реализована «на вырост» под будущий VPS-deploy и покрыта mock-тестом.
- **Файлы (новые):**
  - `Develop/backend/app/backup/__init__.py`, `Develop/backend/app/backup/service.py` — `BackupService` (async API, `asyncio.Lock`, `loop.run_in_executor` для блокирующих I/O), `BackupInfo`, `BackupError`.
  - `Develop/backend/app/cli/__init__.py`, `Develop/backend/app/cli/backup.py` — argparse-CLI с подкомандами `create/list/restore/rotate`, флаг `--yes` для CI, `--no-alembic-upgrade` для скриптов.
  - `Develop/backend/tests/test_backup/__init__.py`, `tests/test_backup/test_service.py` (18 unit-тестов: create, list, rotate, restore, integrity check, lock-сериализация, Postgres-mock), `tests/test_backup/test_cli.py` (9 integration-тестов через subprocess).
  - `Develop/stack_gotchas/gotcha-19-sqlite-wal-backup.md` — новая ловушка про WAL-checkpoint при backup; строка добавлена в `INDEX.md` (version 2 → 3).
- **Файлы (изменённые):**
  - `Develop/backend/app/config.py` — `BACKUP_CRON: str = "03:00"` + `BACKUP_KEEP_LAST: int = 7` (env-настройки).
  - `Develop/backend/app/scheduler/service.py` — конструктор принимает `backup_service: BackupService | None`, в `start()` зарегистрирован cron-job `backup_db_daily` в UTC-таймзоне, добавлен метод `backup_db()` + хелпер `_parse_cron_time(HH:MM)`. Существующие jobs не затронуты.
  - `Develop/.gitignore` — добавлены явные правила `backups/`, `backend/backups/`, `*.sqlite`, `*.dump` (ранее `data/` + `*.db` уже игнорировались, но `.sqlite`/`.dump` — нет).
- **Тесты:** `pytest tests/test_backup/ -v` → **27/27 passed** (1.50s). Полный suite `pytest tests/ -q` → **807 passed / 0 failed** (69.03s; baseline было 771 passed → +36 новых, все зелёные). `ruff check app/backup app/cli app/scheduler` → **All checks passed**.
- **Integration verification:**
  - `grep -rn "BackupService(" app/` → 2 production call site: `app/scheduler/service.py:49` (singleton в SchedulerService) + `app/cli/backup.py:156` (CLI-инстанциация). Не только в тестах ✅.
  - `grep -rn "backup_db_daily\|backup_db\b" app/` → job id зарегистрирован в `app/scheduler/service.py:101`, метод-исполнитель `backup_db` в `service.py:362`. SchedulerService уже инстанциируется в lifespan (`app/main.py:110`), значит `backup_db_daily` job стартует с FastAPI приложением.
  - CLI: `python -m app.cli.backup --help` → корректный вывод 4 подкоманд, restore-help содержит `--yes` и `--path`.
- **Контракты:** 7.9 — самостоятельная задача без cross-DEV контрактов (не входит в C1–C9). Зависимость на BACK1 «DB layer helper» **не понадобилась** — `app/common/database.py` уже предоставлял `engine.dispose()`, а WAL-checkpoint работает через прямой `sqlite3.connect` без участия SQLAlchemy.
- **Stack Gotchas применены:**
  - **Новая #19 (создана):** SQLite WAL → backup без checkpoint = неполный snapshot. Решение в `_copy_sqlite()`: `BEGIN IMMEDIATE` → `PRAGMA wal_checkpoint(FULL)` → `shutil.copy2` + копирование `*.db-wal`/`*.db-shm`. При restore удаляются старые WAL/SHM рядом с целью (иначе SQLite «дочитывает» их и портит snapshot). `INDEX.md` обновлён (v3, last_updated=2026-04-25).
  - **#11 (alembic drift):** при restore выполняется `alembic upgrade head` (схема в backup может быть старее текущей). Опция `--no-alembic-upgrade` для CI.
  - **#08 (AsyncSession.get_bind):** `BackupService` не использует SQLAlchemy session — работает с raw `sqlite3` через `loop.run_in_executor`, чтобы не блокировать asyncio event loop. Тесты используют tmp_path фикстуру, не разделяемую engine.
  - **APScheduler init/shutdown:** новый job регистрируется до `_scheduler.start()` через тот же паттерн `add_job(replace_existing=True)`, что и существующие 3 job'а. `shutdown()` без изменений — APScheduler корректно отменит pending-job.
- **Плагины:** pyright fallback `.venv/bin/python -m py_compile` после каждого Edit/Write — 0 ошибок. ruff — 0 issues. context7 не вызывался: `argparse`, `sqlite3`, `subprocess`, APScheduler `add_job(CronTrigger)` — стабильные API из stdlib и предыдущих спринтов; для `pg_dump --format=custom`/`pg_restore --clean --single-transaction` сверился с существующей практикой DevOps (опции корректны для cross-version совместимости).
- **Открытые вопросы:** нет блокеров. CLI `restore` для Postgres не имеет реального «before-snapshot» (только log-файл) — это документированное ограничение, описано в docstring `_restore_postgres`. Фактический rollback в Postgres — через `--single-transaction`.
- **Результат:** W2 OPS ✅. 7.9 закрыто полностью (service + scheduler-job + CLI + тесты + gotcha-19 + .gitignore).

## 2026-04-25 — Midsprint Checkpoint = PASS

- **Что:** оркестратор + ARCH-агент свели гейт midsprint → W2.
- **Контракты W1 (greps):** C1 (`/ws/trading-sessions` поставщик `app/trading/ws_sessions.py:117` ↔ потребитель `useTradingSessionsWS.ts:136` в `TradingPage.tsx`), C2 (`/ws/backtest/{job_id}` поставщик `ws_backtest.py:49` ↔ потребитель `useBacktestJobWS.ts` в `BackgroundBacktestsBadge`), C7 (`grep "NotificationService()" app/` без `main.py` = **0**), C8 (`open_session:`/`open_chart:` handler в `telegram_webhook.py:460,463`). Все стыки опубликованы и потреблены.
- **MR.5 (5 event_type → runtime):** `trade.opened`, `order.partial_fill`, `order.error`, `connection.lost`, `connection.restored` — все 5 в EVENT_MAP `app/notification/service.py`. Publish-сайты: `app/trading/engine.py:846/885/1171/1201`, `app/broker/tinvest/multiplexer.py:221/244`. Проверка ТЗ §1300 / project_state.md MR.5 — выполнена.
- **Тесты (полная регрессия):**
  - Backend: `pytest tests/ -q` → **771 passed / 0 failed** (78.82s).
  - Frontend: `pnpm test` → **287 passed / 0 failed**, `npx tsc --noEmit` → 0 errors.
  - E2E Playwright: `npx playwright test` → **119 passed / 0 failed / 3 skipped** (4.4 мин, соответствует S6 baseline).
- **Frontend lint:** 6 ошибок в pre-existing файлах (`CandlestickChart.tsx`, `SessionDashboard.tsx`, `ChartPage.tsx`, `ProfileSettingsPage.tsx`, `priceAlertStore.ts`) — не связаны с W1, перенесены в скоуп 7.R.
- **Stack Gotchas:** новых не создано. ARCH обоснование: кандидаты (data-testid space-separated, localStorage quota, bucket-edge inclusivity, WS reconnect storm, 403/404 ownership leak) — единичные или относятся к W2-функционалу. Возврат на 7.R после W2.
- **Файлы:** `Спринты/Sprint_7/midsprint_check.md` (новый), `Спринты/Sprint_7/reports/ARCH_midsprint_review.md` (новый), `Спринты/Sprint_7/sprint_state.md` (обновлён — midsprint PASS), `Спринты/Sprint_7/changelog.md` (эта запись).
- **Технические артефакты для разработки:** `restart_dev.sh` в корне проекта (перезапускает backend uvicorn + frontend vite + alembic upgrade head; логи в `/tmp/moex-dev-logs/`).
- **Готовность гейта midsprint → W2:** ✅ можно стартовать W2. Открытые вопросы (7.R / 7.10) не блокирующие. Ожидание команды заказчика.
