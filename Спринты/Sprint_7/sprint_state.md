# Sprint 7 — текущее состояние

> Обновляется после каждого этапа.

**Дата планирования:** 2026-04-25
**Дата старта W0:** 2026-04-25
**Дата завершения W0:** 2026-04-25
**Дата старта W1:** 2026-04-25
**Дата завершения W1:** 2026-04-25
**Дата старта W2 sub-wave 1:** 2026-04-25
**Дата завершения W2 sub-wave 1:** 2026-04-25
**Дата fix-волны W2:** 2026-04-26
**Дата старта W2 sub-wave 2:** 2026-04-26
**Дата завершения W2 sub-wave 2:** 2026-04-26

## Текущий шаг

**W2 sub-wave 2 ✅ ЗАВЕРШЕНА (FRONT2 + FRONT1 PHASE2 параллельно, координация по MiniSparkline). Готовы к W3 (UX полировка 7.10 + финальный E2E 7.11 + ARCH-ревью 7.R).**

Предыдущие шаги (для контекста сохранены ниже):

**W2 sub-wave 1 ✅ ЗАВЕРШЕНА (BACK1 + BACK2 + FRONT1 + OPS параллельно)**

- **BACK2 (DEV-2):** 7.1-be (C4 alembic `strategy_versions` + REST API + history-preserving restore), 7.3 (CSV экспорт; PDF — lazy-import, нужна установка WeasyPrint+pango/cairo), 7.8-be (C6 wizard endpoint + `wizard_completed_at`), 7.18 (C3 AI слэш-команды через новое поле `context_items`, защита от prompt injection). +29 тестов.
- **BACK1 (DEV-1):** 7.2-be (C5 Grid Search через `asyncio.Semaphore + thread executor` — отступление от ТЗ §5.3.4 multiprocessing, обоснование в gotcha-21), 7.7-be (C9 `GET /account/balance/history` агрегация on-the-fly без snapshot-таблицы), 7.9 саппорт OPS (запросов не было). +39 тестов.
- **FRONT1 (DEV-3):** 7.6 (drawing tools: тулбар, hotkeys, ARIA, Canvas overlay для trendline/rect/vline/label, `series.createPriceLine` для hline). Persist через REST `/api/v1/chart_drawings` ⚠️ BACKEND-PENDING — Frontend работает через localStorage fallback. +29 тестов.
- **OPS (DEV-5):** 7.9 BackupService (WAL-aware SQLite + Postgres-ветка) + APScheduler-job (03:00 UTC, `BACKUP_CRON`) + CLI `python -m app.cli.backup` (create/list/restore/rotate, argparse). gotcha-19 (SQLite WAL backup без checkpoint). +36 тестов.

**Контракты W2 sub-wave 1 опубликованы и интегрированы:**
- C3 (BACK2→FRONT1): `ChatRequest.context_items: list[ChatContextItem]` в `app/ai/chat_schemas.py:48`.
- C4 (BACK2→FRONT2): миграция `c1d4e5f6a7b8_add_strategy_versions_meta.py` + endpoints в `app/strategy/router.py:168`.
- C5 (BACK1→FRONT2): `POST /api/v1/backtest/grid` в `app/backtest/router.py:1159`, `GridSearchEngine` в `app/backtest/grid.py`.
- C6 (BACK2→FRONT2): миграция `d2e3f4a5b6c7_add_users_wizard_completed_at.py` + endpoint в `app/auth/router.py:158` (⚠️ DELTA: путь `/auth/me/wizard/complete`, а не `/users/me/...` — модуля `users/` нет).
- C9 (BACK1→FRONT2): `GET /api/v1/account/balance/history?days=N` в `app/account/router.py`.

**Тесты после под-волны 1:**
- Backend pytest: **866 passed / 0 failed** (baseline midsprint 771 → +95: BACK1+39, BACK2+29, OPS+36, минус OPS-overlap до 95).
- Frontend vitest: **316 passed / 0 failed** (baseline 287 → +29 от FRONT1).
- `tsc --noEmit`: **0 errors**. Ruff 0 issues.
- C7 sanity grep `NotificationService()` без main.py = 0 (singleton не сломан).

**Stack Gotchas созданы:** #19 (SQLite WAL backup), #20 (FastAPI route ordering — статика после `/{int_param}` даёт 422), #21 (Grid Search async vs multiprocessing).

## Открытые вопросы под-волны 1 (требуют решения заказчика/ARCH перед под-волной 2)

1. **C6 URL delta:** контракт говорит `/users/me/wizard/complete`, реализован `/auth/me/wizard/complete`. **Решение:** обновить execution_order.md (это разумная адаптация — `users/` модуля нет). FRONT2 в под-волне 2 будет дёргать `/auth/me/wizard/complete`.
2. **C5 архитектурное отступление (gotcha-21):** Grid Search использует `asyncio.Semaphore + thread executor` вместо `multiprocessing.Pool`. ARCH в W3 (7.R) формально утвердит/отклонит. Для W2 принимаем.
3. **chart_drawings backend pending:** UI готов, REST `/api/v1/chart_drawings` нет. Опция: добавить мини-CRUD через BACK2 в под-волне 2 (~1 час) — иначе drawings не будут persist между сессиями/устройствами.
4. **PDF экспорт WeasyPrint:** требует `brew install pango cairo gdk-pixbuf libffi`. Skip-тикет `S7R-PDF-EXPORT-INSTALL` в `Sprint_8_Review/backlog.md`. Заказчик решает: ставить сейчас (для 7.10/7.R приёмки) или отложить на S8.
5. **Скриншоты 7.6 не сделаны:** Playwright не запущен в среде агентов. Нужен ручной прогон `./restart_dev.sh` + Playwright скриншот ChartPage с тулбаром — либо при приёмке заказчиком, либо в под-волне 2.

## Готовность к под-волне 2

✅ Все контракты под-волны 1 опубликованы (C3, C4, C5, C6, C9). FRONT2 разблокирован: 7.1-fe (C4), 7.7 (C9), 7.8-fe (C6), 7.2-fe (C5). FRONT1 разблокирован: 7.19 (C3).

## Fix-волна 2026-04-26 ✅ ЗАВЕРШЕНА (4 параллельных агента, по решениям заказчика 1-5)

- **BACK2 fix:**
  - C6 URL переехал `/api/v1/auth/me/wizard/complete` → `/api/v1/users/me/wizard/complete`. Создан модуль `app/users/` (`router.py`, `schemas.py`, `__init__.py`). Удалён endpoint из `app/auth/router.py`. Тесты переехали `tests/unit/test_users/`. +5 тестов.
  - chart_drawings backend mini-CRUD (5 endpoints) под префиксом **`/api/v1/charts/...`** (а не `/api/v1/chart_drawings/...` как в промпте — frontend api-клиент использовал именно этот префикс, source of truth по контракту FRONT1). Модель `ChartDrawing` — переиспользована из `app/common/models.py` (таблица создана в initial-миграции `3d3e4e3036a6`, новой alembic-миграции не потребовалось). +11 тестов.
- **BACK1 fix:** Grid Search переписан на `multiprocessing.Pool` (spawn-context, workers = `cpu-1`). Worker `_run_single_backtest` — top-level pickle-friendly. OHLCV грузится один раз в main-процессе, передаётся как pickle-friendly `list[dict]`. Asyncio + Pool интегрирован через `loop.run_in_executor`. Контракт C5 не изменён (FRONT2 не затрагивается). gotcha-21 не удалён — добавлена UPDATE-секция «решение пересмотрено: multiprocessing.Pool финал». +5 тестов (35/35 grid passed, было 30).
- **OPS fix:** установлен WeasyPrint 68.1 в `Develop/backend/.venv` (brew пакеты pango/cairo/gdk-pixbuf/libffi уже стояли). Зафиксирован в `pyproject.toml` (`weasyprint>=60`). Smoke-тест `GET /api/v1/backtest/31/export?format=pdf` → HTTP 200, PDF 54 685 байт (magic %PDF-1.7). Удалён skip-маркер из `tests/unit/test_backtest/test_export.py`, добавлены 2 positive-path теста. Skip-тикет `S7R-PDF-EXPORT-INSTALL` закрыт в `Sprint_8_Review/backlog.md`. Создан `Develop/backend/INSTALL.md` с инструкцией для macOS + Ubuntu. +1 тест.
- **FRONT1 fix:** 8 Playwright скриншотов drawing tools в `Develop/frontend/e2e/screenshots/s7/` (toolbar default, trend active, trendline drawn, rectangle zone, hline support/resistance, label, eraser modal, hotkeys tooltip). Создан `Develop/frontend/e2e/s7-drawing-tools.spec.ts` (~270 строк, 8 test cases) — все 8 passed (18.8s). Использован injectFakeAuth + замоканные API (не зависит от backend chart_drawings). Полный E2E baseline 119 НЕ запущен — отложено на 7.11.

## Финальные тесты после fix-волны (2026-04-26)

- **Backend pytest: 885 passed / 0 failed** (baseline midsprint 771 → W2 sub-wave 1 866 → fix-волна 885, +19 относительно конца под-волны 1).
- **Frontend vitest: 316 passed / 0 failed**, `tsc --noEmit` 0 errors.
- **Frontend Playwright (drawing tools spec):** 8 passed.
- **Frontend Playwright (baseline 119):** не запускался — отложено на 7.11/7.R.

## Открытые вопросы — закрыты

| # | Вопрос | Решение | Закрыт |
|---|--------|---------|--------|
| 1 | C6 URL delta | переделано на `/users/me/wizard/complete` | ✅ |
| 2 | C5 multiprocessing | переделано на `multiprocessing.Pool` | ✅ |
| 3 | chart_drawings backend | реализован под `/api/v1/charts/...` (frontend = source of truth) | ✅ |
| 4 | PDF WeasyPrint | установлен, endpoint работает | ✅ |
| 5 | Playwright скриншоты 7.6 | 8 скриншотов в `e2e/screenshots/s7/` | ✅ |

## Минорное отклонение от промпта (зафиксировано)

- chart_drawings смонтирован под `/api/v1/charts/...`, а не `/api/v1/chart_drawings/...`. Причина: frontend api-клиент `chartDrawingsApi.ts` уже использовал этот префикс (написан в под-волне 1 PHASE1 FRONT1). BACK2 принял frontend как source of truth, чтобы не править frontend код. Решение разумное — handoff-промпт для следующей сессии содержит это для FRONT2 (если он захочет дёрнуть API).

## W2 sub-wave 2 ✅ ЗАВЕРШЕНА (2026-04-26, 2 параллельных агента, вариант (а))

Координация: FRONT1 опубликовал `MiniSparkline` ПЕРВЫМ шагом (Блок 1 ~10 минут), FRONT2 импортировал его без создания дубликата.

- **FRONT1 (DEV-3) PHASE2:**
  - **Блок 1 — саппорт 7.7:** `MiniSparkline.tsx` (чистый SVG, без lightweight-charts, безопасные ветки empty/1-point/multi/range=0, обязательный `aria-label`). 7 unit-тестов. **Опубликован первым** — координационный приоритет соблюдён.
  - **Блок 2 — задача 7.19 (контракт C3):** Mantine `<Combobox>` dropdown по `/`, парсер 5 команд (`/chart`, `/backtest`, `/strategy`, `/session`, `/portfolio`) с поддержкой множественного контекста и валидации, `ContextChip` (3 статуса: ok / forbidden / not_found), render `[CONTEXT]...[/CONTEXT]` в ответе AI как collapsible (defense-in-depth). **IME composition guard** — dropdown НЕ открывается во время русского ввода с диакритикой. Поле `context_items` в `aiApi.ts` / `aiStreamClient.ts` / `aiChatStore.ts` (legacy `context: dict` сохранён, блок-режим стратегии не сломан). 48 unit-тестов (parseCommand 34, CommandsDropdown 6, ContextChip 8). 5 Playwright скриншотов в `e2e/screenshots/s7/s7-7.19-*.png`.
- **FRONT2 (DEV-4):**
  - **7.7 Dashboard widgets:** `<SimpleGrid cols={{base:1,sm:2,lg:3}}>` на `DashboardPage`. `BalanceWidget` (C9 → MiniSparkline 240×56), `HealthWidget` (3 строки светофора через `/health` с graceful degrade на yellow при отсутствии расширенных полей), `ActivePositionsWidget` (top-5 active sessions, sparkline-плейсхолдер 60×24, переход на `/chart/{ticker}`).
  - **7.8-fe FirstRunWizard:** Mantine `<Modal fullScreen>` + `<Stepper>` 5 шагов, шаг 2 gate-checkbox обязательный, шаг 5 → `POST /api/v1/users/me/wizard/complete` (C6). `FirstRunWizardGate` подключён в `App.tsx` внутри `<ProtectedRoute>`, читает `wizard_completed_at` из `/users/me`. Esc/click outside заблокированы.
  - **7.1-fe VersionsHistoryDrawer:** кнопка «История» на `StrategyEditPage` → Drawer со списком версий через C4. На каждом row: Просмотреть / Diff (line-by-line, без новых зависимостей) / Restore (с `modals.openConfirmModal`). «Сохранить именованную версию» через `POST /versions/snapshot {comment}`.
  - **7.2-fe Grid Search:** `GridSearchModal` + `GridSearchForm` с динамическим списком параметров (1–5), real-time `total = product(len(values))` с цветовым feedback (≤200 green / 201–1000 yellow / >1000 red disabled). POST `/api/v1/backtest/grid` (C5) → push в `backgroundBacktestsStore` от FRONT1. `GridSearchHeatmap` поддерживает 3 режима: bar (1 param) / 2D heatmap (2 params) / sortable table (3+).
  - 25 новых unit-тестов (BalanceWidget 4, FirstRunWizard 4, VersionsHistoryDrawer 5, GridSearchForm 12). 6 Playwright скриншотов в `e2e/screenshots/s7/`.

**Контракты W2 как потребитель — подтверждены grep'ом по backend:**
- C3 (BACK2→FRONT1): `context_items` отправляется FRONT1, legacy `context` сохранён.
- C4 (BACK2→FRONT2): URL `/strategy/{id}/versions/{list,by-id/{ver_id},snapshot,{ver_id}/restore}` — фактически совпадают.
- C5 (BACK1→FRONT2): `POST /api/v1/backtest/grid` body/response 1:1 с `GridSearchRequest`/`GridJobResponse`.
- C6 (BACK2→FRONT2, fix-волна): `/api/v1/users/me/wizard/complete` (старый `/auth/...` 404).
- C9 (BACK1→FRONT2): `GET /account/balance/history?days=30`.

**Финальные тесты после sub-wave 2 (2026-04-26):**
- **Backend pytest: 885 passed / 0 failed** (без изменений в этой волне — фронт-only).
- **Frontend vitest: 394 passed / 0 failed** (baseline 316 → FRONT1 +55 → 371 → FRONT2 +25 кумулятивно ≈394). `tsc --noEmit` 0 errors.
- **Frontend Playwright (новые S7 spec'ы):** drawing tools 8 + AI commands 5 + FRONT2 4 = **17 passed** (3 spec-файла). Полный baseline 119 — НЕ запускался, отложен на 7.11.

**Открытые вопросы под-волны 2 (НЕ блокируют W3):**

| # | Вопрос | Статус | Решение/передача |
|---|--------|--------|------------------|
| 6 | `GridSearchHeatmap` готов и unit-тестирован, но точка вызова из badge / отдельной страницы результата не подключена | ⚠️ PARTIALLY CONNECTED | Передаётся в 7.10 (UX полировка) или FRONT1 W3: badge с finished grid job → клик открывает Heatmap. Это <1 час работы. |
| 7 | gotcha-22 кандидат: «Mantine `Combobox.Target.cloneElement` переписывает `data-testid` дочернего input'а» — workaround в тестах через `document.querySelector('textarea')`. Файл НЕ создан | ⚠️ Кандидат | ARCH в 7.R решает: создавать `gotcha-22-mantine-combobox-target-testid-clone.md` или зафиксировать как тестовый паттерн в README. |
| 8 | Pre-existing 6 frontend lint errors (`CandlestickChart`, `SessionDashboard`, `ChartPage`, `ProfileSettingsPage`, `priceAlertStore`) | ⚠️ Известная | Фикс-волна на 7.R. |
| 9 | Полный E2E baseline 119 не прогонялся в этой волне | ⚠️ Отложено | Обязательный прогон в 7.11 — убедиться что drawing tools, виджеты, wizard, versioning, grid search ничего не сломали. |
| 10 | Real-mode покрытие `test_order_manager` отсутствует (paper-mode зафиксирован W1) | ⚠️ Известная | Фикс-волна на 7.R, либо `@pytest.mark.parametrize` на S8. |

## Готовность к W3

✅ Все 17 рабочих задач S7 закрыты. Остались задачи W3:
- **7.10 UX полировка** — UX-агент: delta из реализации W1+W2 vs макеты, мелкие правки на FRONT.
- **7.11 финальный E2E** — QA-агент: полный baseline 119 + новые S7-сценарии (drawing tools 8 + AI commands 5 + FRONT2 4 = ≥17 новых).
- **7.R ARCH ревью** — ARCH-агент: code review 17 задач, MR.5 (5 event_type), Stack Gotchas, Cross-DEV контракты, GridSearchHeatmap entry point, gotcha-22 решение, real-mode coverage. Финальный вердикт PASS / PASS WITH NOTES / FAIL. Обновление ФТ/ТЗ/development_plan + ui_checklist_s7.md.

## Следующее действие

**W2 sub-wave 2 — DONE (2026-04-26).** Backend 885/0, Frontend 394/0, tsc 0, Playwright S7 spec'ы 17/0.

Дальше — старт **W3** (3 задачи):
1. **7.10 UX полировка** (UX-агент): пройти UX-макеты vs фактическую реализацию, собрать delta-список, передать FRONT-агентам мелкие правки.
2. **7.11 финальный E2E** (QA-агент): прогон baseline 119 + 17 новых S7-сценариев на свежеподнятом dev-окружении.
3. **7.R ARCH-ревью** (ARCH-агент): code review всех 17 задач + sync ФТ/ТЗ/development_plan.

Возможный порядок W3: 7.10 + 7.11 параллельно → 7.R после обоих (ARCH должен видеть финальное состояние). Альтернатива: сначала 7.10 (минорные правки), затем 7.11 + 7.R параллельно. Решение — за заказчиком.

**Не закоммичено** (две репы — корневая Test и Develop/, по правилу `feedback_two_repos.md` ветки спрашиваются отдельно):
- Корневой Test: `Спринты/Sprint_7/changelog.md`, `sprint_state.md`, +2 новых отчёта в `reports/` (FRONT1 PHASE2, FRONT2 W2). Текущая ветка: `docs/sprint-7-plan`.
- Develop/: ~10 новых файлов (MiniSparkline, ai/parseCommand+CommandsDropdown+ContextChip, dashboard widgets, FirstRunWizard+Gate, VersionsHistoryDrawer, GridSearchForm/Modal/Heatmap, accountApi, usersApi, e2e spec'ы), ~10 modified (ChatInput, AIChat, aiApi, aiStreamClient, aiChatStore, accountApi, strategyApi, backtestApi, DashboardPage, StrategyEditPage, App.tsx). Текущая ветка: `s7/sprint-7`.

## Прогресс по этапам

| Этап | Статус | Артефакты |
|------|--------|-----------|
| Планирование (sprint_design + prompts) | ✅ завершено | sprint_design.md, prompt_*.md, execution_order.md |
| W0 — UX макеты + ARCH design + QA test plan | ✅ завершено | ux/* (6), arch_design_s7.md, e2e_test_plan_s7.md, reports/ARCH_W0_design.md, reports/UX_W0_design.md, reports/QA_W0_test_plan.md |
| W1 — 6 переносов из S6 (debt first) | ✅ завершено | reports/DEV-1_BACK1_W1.md (✅ 7.13, 7.15-be, 7.17-be), reports/DEV-2_BACK2_W1.md (✅ 7.12, 7.14), reports/DEV-3_FRONT1_W1.md (✅ 7.16, 7.15-fe, 7.17-fe) |
| Midsprint checkpoint | ✅ PASS | midsprint_check.md, reports/ARCH_midsprint_review.md (pytest 771/0, vitest 287/0, Playwright 119/0/3) |
| W2 sub-wave 1 — backend контракты + drawing tools + backup | ✅ завершено | reports/DEV-1_BACK1_W2.md (✅ 7.2-be C5, 7.7-be C9), reports/DEV-2_BACK2_W2.md (✅ 7.1-be C4, 7.3, 7.8-be C6, 7.18 C3), reports/DEV-3_FRONT1_W2_PHASE1.md (✅ 7.6), reports/DEV-5_OPS_W2.md (✅ 7.9). Backend 866/0, Frontend 316/0. |
| W2 fix-волна — 5 решений заказчика | ✅ завершено | 4 W2_FIX отчёта. Backend 885/0, Frontend 316/0 + 8 PNG drawing tools. |
| W2 sub-wave 2 — FRONT2 фичи + FRONT1 7.19 + sparkline | ✅ завершено | reports/DEV-3_FRONT1_W2_PHASE2.md (✅ MiniSparkline + 7.19), reports/DEV-4_FRONT2_W2.md (✅ 7.7, 7.8-fe, 7.1-fe, 7.2-fe). Frontend 394/0, Playwright +9 (5 AI + 4 FRONT2). |
| W3 — UX полировка 7.10 + финальный E2E 7.11 + ARCH 7.R | ⬜ не начат | arch_review_s7.md, ui_checklist_s7.md |

## Прогресс по задачам

См. `execution_order.md` для трекеров. Задачи S7:

**Блок A (Should-фичи):** 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11
**Блок B (переносы из S6):** 7.12, 7.13, 7.14, 7.15, 7.16, 7.17
**Блок C (AI-команды):** 7.18, 7.19
**Блок D:** 7.R

## Ключевые риски

- **Объём:** 17 рабочих задач + UX/ARCH/QA. Заказчик подтвердил: «делаем всё, время гибкое».
- **Midsprint gate:** если W1 (debt) не закроется чисто — W2 не стартует.
- **MR.5 (5 event_type подключены):** обязательная проверка ARCH на финале (см. `project_state.md:79–90` и Приложение C спека).
- **Cross-DEV контракты C1–C9:** должны публиковаться в правильном порядке (см. `execution_order.md` раздел «Правила гонки и приёмки контрактов»). C9 (`GET /account/balance/history`) добавлен после ARCH W0 review для sparkline в виджете «Баланс».

## Следующее действие

**W2 sub-wave 1 — DONE (2026-04-25).** Backend 866/0, Frontend 316/0, tsc 0. Все контракты W2 (C3/C4/C5/C6/C9) опубликованы и интегрированы. FRONT2 и FRONT1 (часть 7.19) разблокированы.

**Перед стартом sub-wave 2 — решения заказчика по 5 открытым вопросам выше** (особенно chart_drawings backend pending, PDF WeasyPrint, C6 URL delta).

Дальше — старт **W2 sub-wave 2** (FRONT-волна):
- **FRONT2 (DEV-4):** 7.1-fe (versioning UI: history, diff, restore через C4), 7.7 (dashboard виджеты: баланс sparkline через C9 + health-checks), 7.8-fe (first-run wizard 5 шагов через C6), 7.2-fe (Grid Search heatmap через C5).
- **FRONT1 (DEV-3) PHASE2:** 7.19 (AI слэш-команды dropdown + рендер контекста через C3), саппорт 7.7 (sparkline компоненты).

Ожидание команды заказчика на запуск sub-wave 2.
