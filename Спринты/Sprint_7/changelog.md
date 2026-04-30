# Sprint 7 — Changelog

> Лог изменений по дням. Обновляется **немедленно** после каждого блока изменений
> (правило памяти `feedback_changelog_immediate.md`).
>
> Формат записи: `## YYYY-MM-DD — короткое название`. Внутри — bullet'ы:
> - **Что:** краткое описание изменения
> - **Файлы:** перечень
> - **Результат:** что работает / что сломалось / тесты

---

## 2026-04-30 — chart-drawings backlog: cleanup — удаление неиспользуемой lucide-react

### Триггер

В `package.json` остался зависимость `lucide-react@^1.11.0`, которая не импортировалась нигде в коде (единственное упоминание — в комментарии `DrawingToolbar.tsx:43` про дизайн иконок). Иконки в проекте — `@tabler/icons-react` (Mantine стиль) и кастомные SVG (DrawingToolbarIcons.tsx).

### Реализовано

- `pnpm remove lucide-react` → пакет удалён из `package.json` и `pnpm-lock.yaml`.
- Комментарий в `DrawingToolbar.tsx` обновлён (убрано сравнение с lucide-react, добавлено упоминание Tabler в контексте контекстного меню).

### Файлы

- `Develop/frontend/package.json`
- `Develop/frontend/pnpm-lock.yaml`
- `Develop/frontend/src/components/charts/DrawingToolbar.tsx` (комментарий)

### Результат

- TypeScript: 0 errors.
- Vitest (затронутая папка `components/charts/__tests__/`): **48 passed**.

---

## 2026-04-30 — chart-drawings backlog: S7R-DRAW-POSITION-EDIT-MODAL числовая настройка позиций

### Триггер

S7R-DRAW-POSITION-EDIT-MODAL из backlog: для long/short position нужна модалка с числовыми input'ами, чтобы пользователь мог точно задать `target/stop/qty` без drag за углы. Открывается из контекстного меню пункт «Редактировать», который backlog #2 оставил с заглушкой `onEditPosition?: (id) => void`.

### Реализовано (TDD: 12 vitest тестов RED → GREEN)

#### Компонент `PositionEditModal.tsx`

- 3 `<NumberInput>`: «Целевая цена», «Стоп», «Количество» (decimalScale=4, step=0.01 для цен; min=0, step=1 для qty).
- Read-only display: бейдж «Long»/«Short» (color="teal"/"red"), цена входа через `formatCurrency` (`1 234,56 ₽`).
- Live-расчёт под формой:
  - **Соотношение R/R** = Reward / Risk — `2,00` (ru-RU локаль).
  - **Максимальная прибыль** = `|target − entry| × qty` — `formatCurrency` (зелёный).
  - **Максимальный убыток** = `|entry − stop| × qty` — `formatCurrency` (красный).
- Бизнес-валидация (Apply disabled):
  - **long**: `target > entry`, `stop < entry`, `qty > 0`.
  - **short**: `target < entry`, `stop > entry`, `qty > 0`.
- На Apply: `store.update(id, {type, data: {...currentData, target, stop, qty}, style})` — replace-семантика (см. backlog #1).
- На Cancel/закрытие: ничего не меняет.
- Если `drawingId === null` или указывает на не-position тип — Modal не рендерится (no-op).

#### Интеграция

- `pages/ChartPage.tsx`:
  - state `editingPositionId: string | null`,
  - `<DrawingsLayer onEditPosition={setEditingPositionId} />`,
  - `<PositionEditModal drawingId={editingPositionId} onClose={() => setEditingPositionId(null)} />`.
- В контекстном меню (backlog #2) пункт «Редактировать» теперь активен для position-типов и вызывает `onEditPosition(ctxItem.id)`.

#### Тесты

- **Vitest** (`PositionEditModal.test.tsx`, 12 тестов):
  - drawingId=null → не рендерится; не-position тип → не рендерится.
  - Long/short — корректные начальные значения и Badge.
  - R/R и Max profit/loss — formula-correct (long и short).
  - Бизнес-валидация (target/stop/qty) → Apply disabled.
  - Apply вызывает update с правильным payload + onClose.
  - Cancel вызывает onClose без update.
- **Playwright e2e** (`s7-drawing-tools.spec.ts`):
  - long_position → right-click → click «Редактировать» → Modal открыт → Cancel закрывает.
  - Скриншот `s7-7.6-position-edit-modal.png` подтверждает: Long badge, цена входа `320,00 ₽`, R/R = 2,00, прибыль `100,00 ₽` (teal), убыток `50,00 ₽` (red), Mantine dark theme.

### Файлы

- `Develop/frontend/src/components/charts/PositionEditModal.tsx` (new)
- `Develop/frontend/src/components/charts/__tests__/PositionEditModal.test.tsx` (new, 12 тестов)
- `Develop/frontend/src/pages/ChartPage.tsx` (state + props + render Modal)
- `Develop/frontend/e2e/s7-drawing-tools.spec.ts` (+ e2e тест)

### Результат

- Vitest: **457 passed** (445 + 12 новых, 0 регрессий).
- TypeScript: `npx tsc --noEmit` → 0 errors.
- Playwright: новый e2e PASSED (3.0s).
- Скриншот вживую подтверждает: модалка открывается ровно на месте позиции, форматирование `ru-RU` корректно.

### Известные ограничения

- Текущий контекстное меню (backlog #2): «Редактировать» disabled для не-position типов — реализация «базовой редактуры цвета» отнесена в будущий backlog (формальной задачи в S7R пока нет).

---

## 2026-04-30 — chart-drawings backlog: S7R-DRAW-CONTEXT-MENU контекстное меню + display_order

### Триггер

S7R-DRAW-CONTEXT-MENU из backlog: правый клик по выделенному drawing'у должен показывать меню «Редактировать / На передний план / Скопировать / Удалить».

### Реализовано

#### Backend (TDD: 4 новых теста RED → GREEN)

- **Миграция** `e8a1f2b3c4d9_add_chart_drawings_display_order.py`:
  - `chart_drawings.display_order INTEGER NULL` через `batch_alter_table` (SQLite-совместимо).
  - Down: drop_column. NULL backfill — без server_default (Gotcha-12).
- **ORM** `app/common/models.py:67`: `display_order: Mapped[int | None]` с docstring о z-order.
- **Schemas** `app/chart_drawings/schemas.py`:
  - `ChartDrawingUpdate.display_order: int | None = None`
  - `ChartDrawingResponse.display_order: int | None = None`
- **Router** `app/chart_drawings/router.py`:
  - `update_drawing` принимает `display_order` (отдельная ветка, не затирает data).
  - `list_drawings` сортирует `display_order ASC NULLS FIRST, id ASC` — фигура с бо́льшим значением рендерится последней (поверх).
  - `_row_to_response` пробрасывает `row.display_order` в ответ.
- **Тесты** (4 новых в `test_chart_drawings_position.py`):
  - `test_display_order_default_null_returned` — POST → response содержит `display_order: None`.
  - `test_patch_display_order_persists_in_response` — PATCH сохраняет значение.
  - `test_list_orders_by_display_order_then_id` — порядок меняется после PATCH.
  - `test_patch_display_order_alone_does_not_clear_data` — PATCH только display_order не затирает data.

#### Frontend store (`stores/chartDrawingsStore.ts`)

- Тип `display_order?: number | null` в `ChartDrawing`.
- Новый интерфейс `ChartDrawingUpdate extends Partial<ChartDrawingCreate>` для PATCH-семантики (display_order вне Create-схемы).
- `bringToFront(id)`:
  - находит `max(display_order)` (или 0), ставит drawing'у `max+1`,
  - локально переносит в конец `items` (lightweight-charts рендерит primitives в порядке attach → последний поверх),
  - PATCH'ит на backend (для local-id PATCH пропускается).
- `duplicate(id, barWidthSec)`:
  - сдвиг `+1 бар` для всех «временных» точек (`p1/p2/anchor/entry/end`, `vline.t`),
  - `+0.5%` к `hline.price`,
  - target/stop/qty position'а сохраняются как есть.
  - Использует существующий `add()` — корректно обрабатывает optimistic id.

#### Frontend component (`components/charts/DrawingsLayer.tsx`)

- **Z-order re-attach**: при изменении ПОРЯДКА items (а не только содержимого) — detach всех primitives + attach в новом порядке. Существование (add/remove) и содержимое (drag, setDrawing) — incremental, без re-attach (нет лишних flicker'ов).
- **Right-click listener** на container (capture):
  - hit-test от верхнего слоя к нижнему,
  - при попадании — `e.preventDefault()`, `setSelected(hitId)`, открывает меню,
  - в режиме рисования (currentTool ≠ cursor) меню не открывается.
- **Mantine Menu через `<Portal>`** с invisible target div (position:fixed по координатам курсора): пункты меню «Редактировать» (Tabler IconEdit), «На передний план» (IconArrowUp), «Скопировать» (IconCopy), Divider, «Удалить» (IconTrash, color="red"). Mantine управляет click-outside / Escape / a11y / focus.
- **Props `onEditPosition?: (id: string) => void`** — callback для задачи S7R-DRAW-POSITION-EDIT-MODAL. Если callback не передан — пункт «Редактировать» disabled. Для не-position типов (trendline/hline/...) — также disabled.
- **Esc** теперь закрывает контекстное меню (помимо отмены preview).

### Файлы

**Backend:**
- `Develop/backend/app/common/models.py` (+display_order)
- `Develop/backend/app/chart_drawings/schemas.py` (+поле в Update/Response)
- `Develop/backend/app/chart_drawings/router.py` (+sort, +PATCH-ветка, +response field)
- `Develop/backend/alembic/versions/e8a1f2b3c4d9_add_chart_drawings_display_order.py` (new)
- `Develop/backend/tests/unit/test_chart_drawings/test_chart_drawings_position.py` (+4 теста)

**Frontend:**
- `Develop/frontend/src/api/chartDrawingsApi.ts` (+display_order, +ChartDrawingUpdate)
- `Develop/frontend/src/stores/chartDrawingsStore.ts` (+bringToFront, +duplicate)
- `Develop/frontend/src/stores/__tests__/chartDrawingsStore.test.ts` (+6 тестов)
- `Develop/frontend/src/components/charts/DrawingsLayer.tsx` (contextmenu + Mantine Menu + reattach)
- `Develop/frontend/e2e/s7-drawing-tools.spec.ts` (+ e2e «right-click on drawing»)

### Результат

- Backend: `pytest tests/` → **907 passed** (было 903 + 4 новых, 0 регрессий).
- Frontend Vitest: 71 файлов, **445 passed** (было 430 + 15 новых, 0 регрессий).
- TypeScript: `npx tsc --noEmit` → 0 errors.
- Playwright e2e: новый тест `right-click on drawing opens context menu` → **PASSED**, скриншот `e2e/screenshots/s7/s7-7.6-context-menu.png` подтверждает: меню рендерится с тенью, dark theme, иконками Tabler, разделителем, красным «Удалить».
- 2 уже существовавшие регрессии (`trendline tool active`, `keyboard shortcuts tooltip`) не моей ответственности — упали и до изменений (проверено через `git stash`).

### Известные ограничения

- «Редактировать» — disabled до реализации S7R-DRAW-POSITION-EDIT-MODAL (задача 3 backlog'а). Для не-position типов остаётся disabled (по плану — «no-op или базовая редактура цвета»).
- Колонка `display_order` опциональная: существующие рисунки в БД с NULL продолжают работать, сортируются первыми (по id).

---

## 2026-04-30 — chart-drawings backlog: S7R-DRAW-BACKEND расширение schemas (position-типы + logical)

### Триггер

S7R-DRAW-BACKEND из backlog: рисунки long_position/short_position сохранялись только в localStorage, потому что backend схема (`app/chart_drawings/schemas.py`) не знала про эти типы. POST с `type=long_position` возвращал 422, фронт уходил в catch и работал в fallback-режиме.

### Аудит: что уже было

Роутер `app/chart_drawings/router.py` + ORM-модель `ChartDrawing` + 11 тестов CRUD/ownership/auth — уже реализованы (S7 fix-волна BACK2, коммит до начала backlog'а). Реальный gap — только schemas:

- `DrawingType` Literal — 5 типов вместо 7 (нет `long_position` / `short_position`)
- `DrawingPayload` — нет полей `entry`, `end`, `target`, `stop`, `qty`
- `DrawingPoint` — нет поля `logical?: number` (фронт-rev2 экстраполяция за last bar, см. `chartDrawingsApi.ts:38`)
- `validate_payload_for_type` — нет правил для position-типов

### Реализовано (TDD)

**RED** → 15 новых тестов в `tests/unit/test_chart_drawings/test_chart_drawings_position.py`:
- POST long_position / short_position со всем payload → 201
- PATCH с полным data сохраняет все поля (явный тест replace-контракта)
- Валидация: parametrize по 5 обязательным полям × 2 типа = 10 422-кейсов
- `logical` round-trip для trendline (присутствует / опциональное)

**GREEN** → расширил `schemas.py`:
- `DrawingType` Literal +`long_position`, +`short_position`
- `ALLOWED_TYPES` (set) — синхронизирован
- `DrawingPoint.logical: float | None = None` (opaque-passthrough, без валидации)
- `DrawingPayload` +`entry: DrawingPoint | None`, +`end: DrawingPoint | None`, +`target/stop/qty: float | None`
- `validate_payload_for_type` — ветка для `long_position` / `short_position`: проверяет наличие entry/end (как dict-points) и target/stop/qty (`is None` — 0 валидное значение)
- Module docstring обновлён: явно зафиксирована **replace-семантика PATCH** (фронт обязан отправлять весь payload, server заменяет `data_json` целиком — это уже соответствует поведению `chartDrawingsStore.update`)

### Файлы

- `Develop/backend/app/chart_drawings/schemas.py` — расширение Literal/Payload/Point + validate
- `Develop/backend/tests/unit/test_chart_drawings/test_chart_drawings_position.py` — новый файл, 15 тестов

### Frontend

Не менялся. После backend-deploy `chartDrawingsStore` перестанет уходить в catch для position-типов и автоматически переключится на backend как источник истины (см. `setContext` логику: при наличии backend-items они затирают localStorage; при пустом ответе localStorage остаётся как cache).

### Результат

- `pytest tests/` — **903 passed** (было 888 ± регрессий нет; +15 position).
- `py_compile` schemas.py + router.py — OK.
- Контракт совпал с frontend `chartDrawingsApi.ts` (тип, payload, logical).

---

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
