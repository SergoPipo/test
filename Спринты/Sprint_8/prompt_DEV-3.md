---
sprint: 8
agent: DEV-3
role: Frontend Charts (FRONT1) — Drawing editing + intraday coords + lint cleanup
wave: 1+3
depends_on: [ARCH W0]
---

# Роль

Ты — Frontend-разработчик #1 (senior). Зона ответственности по RACI: `lightweight-charts` + drawing tools = R, `frontend/src/components/charts/*` = R, `chartDrawingsStore` = R.

На **W1** закрываешь эпик A «Charts editing» (S7R-DRAWING-EDITING + S7R-DRAWING-INTRADAY-COORDS, ≈22ч). Это medium-high и medium карточки из `Sprint_8_Review/backlog.md` — без них M4 не закрывается, заказчик уже жаловался: «нарисовал линию — отредактировать не могу».

На **W3** добиваешь две low-карточки финального cleanup'а (S7R-FE-LINT-WARNINGS-CLEANUP в FRONT-части + S7R-HISTOGRAM-MANTINE-TOOLTIP, ≈6ч).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Node >= 18 (планируется миграция на 24 в W3 OPS-задаче, тебя не касается), pnpm активен.
2. Зависимости предыдущих DEV: нет — изолированный frontend-эпик, не блокируется другими DEV.
3. Существующие файлы:
   - frontend/src/pages/ChartPage.tsx — главная страница графика
   - frontend/src/components/charts/CandlestickChart.tsx — сам chart-контейнер (lightweight-charts)
   - frontend/src/components/charts/DrawingsLayer.tsx — слой отрисовки фигур
   - frontend/src/components/charts/DrawingToolbar.tsx — тулбар выбора инструментов
   - frontend/src/components/charts/sequentialIndex.ts — утилита sequential-index mode
   - frontend/src/stores/chartDrawingsStore.ts — zustand store + localStorage persist
   - frontend/src/components/backtest/PnLDistributionHistogram.tsx — гистограмма для W3 #2
4. База данных: не требуется (всё в localStorage).
5. Внешние сервисы: не требуется.
6. Тесты baseline: cd Develop/frontend && pnpm vitest run → 468 / 0 failed; pnpm tsc --noEmit → 0 errors;
   pnpm lint → 0 errors / 9 warnings (известный долг, который ты в W3 закрываешь).
   Зафиксируй фактическое число тестов/warnings в отчёте (правило S5R.5).
```

> Если хотя бы одно условие не выполнено — верни `БЛОКЕР: <описание>`.

# ⚠️ Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| typescript-lsp | **да** (mandatory после каждого Edit/Write на .ts/.tsx) | `cd Develop/frontend && pnpm tsc --noEmit` |
| context7 | **да** — `lightweight-charts` (hit-testing, mouse events, `timeToCoordinate`/`priceToCoordinate`), Mantine `Tooltip`, react-hooks/exhaustive-deps best practices | WebSearch |
| playwright | **да** — после реализации drag editing **обязательно** скриншот: `/chart/SBER?session=1`, демонстрация цикла «рисуем линию → перетаскиваем → меняем угол → удаляем Backspace». QA пишет полный E2E (`s7-drawings.spec.ts`), но FRONT1 прикладывает screenshot в `Sprint_8/reports/DEV-3_BACK1_W1.md` для arch_review | Попросить пользователя сделать скриншот |
| frontend-design | **да** — **перед началом** S7R-DRAWING-EDITING вызвать `/frontend-design` чтобы согласовать визуал control-points (vertex handles), hover state, drag cursor, delete-state. Цель — не изобретать UX, а взять production-grade паттерн (TradingView/Figma-like) | — |
| code-review | **да** — после блока «DRAWING-EDITING + DRAWING-INTRADAY-COORDS» (W1) обязательно `/code-review`. После W3 — опционально | — |
| pyright-lsp | нет (FRONT1 не пишет backend) | — |
| superpowers TDD | нет — UI-логика, достаточно vitest smoke + manual playwright скриншот | — |

**Правило:** после **КАЖДОГО** Edit/Write на `.ts/.tsx` файл → вызови **typescript-lsp** diagnostic (или fallback `pnpm tsc --noEmit`). Hook `plugin-check.sh` напомнит, но обязан следовать и без hook'а. Пропуск проверки типов = **блокер приёмки** (см. `Develop/CLAUDE.md` секция «Правила использования плагинов»).

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью. Особое внимание: «Правила использования плагинов», матрица «файл → обязательные плагины» (строка `components/charts/*` требует **ts-lsp + context7 + playwright + code-review**).

2. **`Develop/stack_gotchas/INDEX.md`** — таблица 23 ловушек. Релевантные для тебя:
   - **`gotcha-22-mantine-combobox-target-testid-clone.md`** — на случай если в тулбаре есть Combobox (атрибут `data-testid` теряется через `cloneElement`).
   - **`gotcha-09-playwright-strict.md`** — для playwright скриншота (strict mode на дублях кнопок).
   - **⚠️ Кандидат `gotcha-24-lightweight-charts-few-points-rightbar.md`** — на момент написания этого промпта файл ещё **не создан** (`gotcha-24` отсутствует в `INDEX.md`, последний — `gotcha-23`). Источник правила: `Sprint_7/changelog.md` запись S7R-EQUITY-BY-INDEX + реализация в `frontend/src/components/charts/sequentialIndex.ts`. **Перед началом** S7R-DRAWING-INTRADAY-COORDS проверь, не появился ли уже файл `gotcha-24-lightweight-charts-few-points-rightbar.md` в `Develop/stack_gotchas/` — если да, читай его. Если нет — изучи реализацию `sequentialIndex.ts` + S7-changelog, в секции 8 отчёта (новые Stack Gotchas) подтверди применение шаблона.

3. **`Спринты/Sprint_8/execution_order.md`** раздел «Cross-DEV contracts» (таблица C-S8-1 … C-S8-9). Твоя роль:
   - **Поставщик:** нет (изолирован в charts UI, ни один контракт не идёт от тебя).
   - **Потребитель:** нет напрямую (работаешь с `lightweight-charts` API + localStorage).
   - **Косвенная зависимость:** sequential-index pattern из S7-closeout (см. §1.2 этого промпта про `gotcha-24`).

4. **`Спринты/Sprint_8/arch_design_s8.md`** — секция 1 (Эпик A — Charts editing, твои карточки #1, #16, #25 и часть #21), секция 8 (Wave breakdown, поток C W1 + поток A W3).

5. **`Спринты/Sprint_7/changelog.md`** — запись S7R-EQUITY-BY-INDEX (sequential-index в charts) — источник правил для DRAWING-INTRADAY-COORDS.

6. **Цитаты из ФТ/CLAUDE.md (дословно):**

   > **ФТ (функциональные требования, фрагмент):** «Пользователь может рисовать на графике линии, прямоугольники, Фибоначчи. Рисунки сохраняются между сессиями (localStorage). После рисования пользователь может перетащить фигуру или изменить её точки.»

   > **CLAUDE.md (правила для UI):** «Создаёшь новый UI-компонент или страницу? frontend-design: вызови `/frontend-design` перед реализацией. После завершения блока — playwright скриншот.»

   > **CLAUDE.md (матрица плагинов для `components/charts/*`):** ts-lsp ✅ + context7 ✅ + playwright ✅ + code-review ✅.

# Рабочая директория

`Develop/frontend/`

# Контекст существующего кода

- `frontend/src/pages/ChartPage.tsx` — главная страница графика; рендерит `CandlestickChart`, `DrawingToolbar`, `FavoritesPanel`. Хук подключён через `useChart...` (проверь точное имя).
- `frontend/src/components/charts/CandlestickChart.tsx` — обёртка вокруг `lightweight-charts`; хранит ref на series/chart, обрабатывает WS streaming. **НЕ переписывать**, только расширять: добавить mouse handlers (mousedown/move/up) поверх chart-canvas.
- `frontend/src/components/charts/DrawingsLayer.tsx` — слой отрисовки фигур (линии, прямоугольники, Фибоначчи). **Точка вставки drag-handlers + hit-testing + control-points**.
- `frontend/src/components/charts/DrawingToolbar.tsx` — кнопки выбора инструмента (линия, прямоугольник, Фибоначчи, удалить). Не трогай UX, только добавь cursor-state «edit/drag».
- `frontend/src/components/charts/sequentialIndex.ts` — утилита: timestamp ↔ sequential-index (избегает gaps между торговыми сессиями на intraday TF). **Источник правила для DRAWING-INTRADAY-COORDS**.
- `frontend/src/stores/chartDrawingsStore.ts` — zustand store с localStorage persist по ключу `chartDrawings:{ticker}:{tf}`. Содержит actions `addDrawing`, `removeDrawing`, `clearDrawings`. **Нужно добавить:** `updateDrawing(id, patch)` для drag-результата, `selectDrawing(id)` для UI-state.
- `frontend/src/components/backtest/PnLDistributionHistogram.tsx` — гистограмма распределения P&L. **Точка вставки Mantine Tooltip для W3 #2.**
- `frontend/package.json` — `"lint": "eslint ."`. **В W3 заменить на:** `"lint": "eslint . --max-warnings 0"`.

Все имена выше — фактические (проверены ls на момент написания промпта 2026-05-12). Если в процессе работы окажется, что файл переименован — **не угадывай**, сделай `grep -rn "<имя>" src/` и подтверди.

# Задачи

## Задача 1.A (W1, ≈16ч): S7R-DRAWING-EDITING — drag/edit фигур

**Цель:** Пользователь нарисовал линию → может схватить за конец → перетащить → переместить всю фигуру → удалить через Backspace. То же для прямоугольника (4 угла) и Фибоначчи (2 опорные точки).

**Подэтапы:**

1. **(2ч) frontend-design pass.** Перед кодом вызови `/frontend-design`:
   - control-points (vertices) — круги диаметром 8px, hover → 10px, цвет — accent;
   - selected drawing — обводка 2px тем же accent-цветом;
   - cursor: `crosshair` для рисования, `move` для drag всей фигуры, `nwse-resize`/`nesw-resize`/`ew-resize`/`ns-resize` для vertex по типу угла;
   - keyboard delete: Backspace, Delete (только если drawing selected).
   Зафиксируй спеку в комментарии в `DrawingsLayer.tsx` (5-10 строк).

2. **(4ч) Hit-testing.** Функция `hitTest(x: number, y: number, drawing: Drawing): HitResult` где `HitResult = { type: 'vertex' | 'edge' | 'body' | 'none', vertexIndex?: number }`. Tolerance: 6px для vertex, 4px для edge. Координаты — pixels на canvas. Конвертация back через `chart.timeScale().coordinateToTime()` + `series.coordinateToPrice()` (см. context7 lightweight-charts).

3. **(5ч) Drag handlers.** На canvas (или overlay div поверх chart):
   - `mousedown` → `hitTest` → если попал, выставить `dragState = { drawingId, hitResult, startX, startY }` + `selectDrawing(id)`.
   - `mousemove` → если `dragState != null`, посчитать новые координаты, вызвать `updateDrawing(id, patch)`. Patch различается по hitResult.type: для `vertex` — обновляем одну точку, для `body` — сдвигаем все точки на (dx, dy).
   - `mouseup` → `dragState = null`. Store автоматически персистит в localStorage через middleware.

4. **(2ч) Keyboard delete + undo.** Глобальный `keydown` listener на `ChartPage`:
   - Backspace / Delete → если есть selected drawing → `removeDrawing(id)`.
   - Cmd+Z / Ctrl+Z → undo последнего действия (нужен `history` stack в store — push при каждом add/update/remove, pop в undo).

5. **(3ч) Tests + manual screenshot.**
   - vitest unit (`DrawingEditing.test.tsx`): hit-testing на синтетических фигурах, `updateDrawing` action.
   - playwright screenshot: рисуем линию → drag за конец → меняем угол → Backspace → исчезла. Файл `Sprint_8/reports/DEV-3_screenshot_drawing_editing.png`.

**Критично:**
- Не дублируй state — single source of truth = `chartDrawingsStore`. `DrawingsLayer` подписан через `useChartDrawingsStore(state => state.drawings)`.
- LocalStorage ключ — **уже** `chartDrawings:{ticker}:{tf}` (не меняй формат, иначе сломаешь существующие drawings у пользователей).

## Задача 1.B (W1, ≈6ч): S7R-DRAWING-INTRADAY-COORDS — sequential-index

**Цель:** На intraday TF (1m / 5m / 15m / 1h / 4h) drawings должны жить в координатах sequential-index (как свечи в S7-fix), а не в timestamp. Иначе после смены TF фигуры «съезжают» из-за gap между торговыми сессиями.

**Подэтапы:**

1. **(1ч) context7 pass.** Запроси доку `lightweight-charts` по `timeScale.coordinateToLogical()` / `logicalToCoordinate()` — это API для логического индекса (что и есть sequential-index в нашей реализации). Проверь, как `sequentialIndex.ts` уже это использует.

2. **(2ч) Расширить тип `Drawing`** в `chartDrawingsStore.ts`:
   ```ts
   type Point = {
     time: UTCTimestamp;       // оригинальный timestamp — для daily/weekly/monthly
     logical?: number;          // sequential-index — для intraday (заполняется на intraday TF)
     price: number;
   };
   ```
   Migration: при загрузке старых drawings из localStorage — если `logical` отсутствует и TF intraday — пересчитать из `time` через `chart.timeScale().timeToCoordinate()` → `chart.timeScale().coordinateToLogical()`.

3. **(2ч) Сохранение координат.** В drag handlers (задача 1.A) при `mouseup`:
   - если TF intraday → сохраняем `logical` (из `coordinateToLogical(mouseX)`);
   - если TF daily+ → сохраняем `time` (из `coordinateToTime(mouseX)`).
   Render в `DrawingsLayer`: симметрично, выбираем `logicalToCoordinate` либо `timeToCoordinate` по наличию `logical`.

4. **(1ч) Tests.** vitest unit `DrawingCoordsConversion.test.tsx`:
   - На intraday TF добавляем drawing → проверяем что `logical` заполнено, `time` сохранён как fallback.
   - На daily TF — drawing использует `time`.
   - Migration old → new: drawing без `logical` после открытия на intraday TF получает `logical`.

**Критично:** не ломай совместимость с уже сохранёнными drawings у пользователей. Migration silent — без потери данных.

## Задача 3.A (W3, ≈4ч): S7R-FE-LINT-WARNINGS-CLEANUP (FRONT1-часть)

**Цель:** Привести 9 react-hooks/exhaustive-deps warnings к нулю + закрепить регрессионную защиту через `--max-warnings 0`.

**Подэтапы:**

1. **(0.5ч) Inventory.** `cd Develop/frontend && pnpm lint` → собрать список 9 warnings с file:line. Зафиксируй список в отчёте.

2. **(2.5ч) Fixes.** По каждому warning:
   - Если deps реально нужны (зависимость влияет на эффект) → добавить в массив.
   - Если deps **не** нужны (false positive, объект стабилен) → обернуть в `useMemo`/`useCallback` ИЛИ добавить eslint-disable-next-line **с комментарием** «// reason: <короткое объяснение>». Слепое отключение без комментария — **запрещено**.
   - Если deps создают infinite loop → перепроектировать (вынести вычисление наружу useEffect, использовать ref).

3. **(0.5ч) Регрессионная защита.** В `frontend/package.json`:
   ```diff
   - "lint": "eslint ."
   + "lint": "eslint . --max-warnings 0"
   ```
   Повторно `pnpm lint` → 0 errors, 0 warnings.

4. **(0.5ч) CI verification (опциональная — PASS/SKIP).**
   - **PASS** — реализовано: проверь `.github/workflows/ci.yml` frontend job — там должна быть строчка `pnpm lint`. Если её нет — добавить.
   - **SKIP — reason: …** — если CI задача делегирована OPS в W3 (`S7R-CI-NODE24-MIGRATION`), укажи это явно с reason «`pnpm lint` уже в ci.yml, OPS обновит только Node-actions».
   Молчание здесь = блокер (правило `Sprint_5_Review` S5R.5).

**NB:** карточка `S7R-FE-LINT-WARNINGS-CLEANUP` совместная (FRONT1 + FRONT2 в `arch_design §1.2 # 21`), но 9 warnings — это **все** warnings, FRONT1 закрывает их в W3 целиком, FRONT2 не дублирует. Если разделение нужно — координируй через оркестратора.

## Задача 3.B (W3, ≈2ч): S7R-HISTOGRAM-MANTINE-TOOLTIP

**Цель:** При hover на bar гистограммы (`PnLDistributionHistogram.tsx`) показывать кастомный Mantine `Tooltip` с детальной информацией bin'а: диапазон P&L, кол-во сделок, доля от общего.

**Подэтапы:**

1. **(0.5ч) context7 pass** для Mantine `Tooltip` — нужен `withinPortal`, `multiline`, custom `label` через ReactNode.

2. **(1ч) Реализация.** В `PnLDistributionHistogram.tsx` обернуть каждый `<rect>` (bar) в `<Tooltip label={...}>`. Контент:
   ```
   Диапазон: [-500 ₽, -300 ₽)
   Сделок: 12 (8.5%)
   ```

3. **(0.5ч) Tests.** vitest `HistogramTooltip.test.tsx` — render histogram с 3 bin'ами → проверяем что tooltip-labels формируются корректно по mock-data.

# Опциональные задачи

Только одна — задача 3.A подпункт 4 (CI verification). Обязательно вернуть **PASS** (с диффом строки) или **SKIP + reason**. Молчание = блокер.

# Skip-тикеты в тестах

Если введёшь `test.skip(reason, { tag: '@ticket-X' })` или `it.skip(...)` — обязательно:
1. В отчёте полный список с reason.
2. Карточка в `Sprint_8_Review/backlog.md` с тикетом формата `S8R-<NAME>`.

Skip без карточки — **блокер**.

# Тесты

```
frontend/src/__tests__/
├── components/charts/
│   ├── DrawingEditing.test.tsx           # W1 1.A: hit-testing + drag handlers + undo
│   └── DrawingCoordsConversion.test.tsx  # W1 1.B: sequential-index vs timestamp + migration
└── components/backtest/
    └── HistogramTooltip.test.tsx         # W3 3.B: Mantine tooltip render с mock bin'ами

# E2E (QA пишет на основе твоего скриншота):
e2e/specs/s7-drawings.spec.ts             # расширение существующего spec'а на drag/delete
```

**Используемые фикстуры:** `mockChartData`, `mockDrawings` (если есть; иначе создать в `__tests__/fixtures/drawings.ts`).

# ⚠️ Integration Verification Checklist

Для **каждой** нового action / hook / handler:

- [ ] **1.A:** `grep -rn "updateDrawing\|selectDrawing" src/` показывает использование в `DrawingsLayer.tsx` (mouse handlers), не только в `chartDrawingsStore.ts` и тестах.
- [ ] **1.A:** Hit-testing функция вызывается из mouse-handlers (`grep -rn "hitTest(" src/`).
- [ ] **1.A:** `keydown` listener на Backspace зарегистрирован в `ChartPage.tsx` (или дочернем компоненте) — `grep -rn "addEventListener.*keydown" src/`.
- [ ] **1.A:** После reload браузера drawings персистятся (manual smoke: открой DevTools → Application → LocalStorage → ключ `chartDrawings:SBER:1m` содержит изменённую фигуру). Лог в отчёте.
- [ ] **1.B:** `coordinateToLogical` / `logicalToCoordinate` действительно вызываются в `DrawingsLayer.tsx` (`grep -rn "coordinateToLogical\|logicalToCoordinate" src/`).
- [ ] **1.B:** Migration старых drawings — manual smoke: руками положи в localStorage старую запись без `logical`, открой intraday TF, проверь что `logical` появилось.
- [ ] **1.B:** Смена TF (например, 5m → 15m) пересчитывает `logical` для всех drawings (так как logical-index новый на новом TF).
- [ ] **3.A:** `pnpm lint` → `0 problems (0 errors, 0 warnings)`. Лог в отчёте.
- [ ] **3.A:** `package.json` script содержит `--max-warnings 0`.
- [ ] **3.B:** `<Tooltip>` оборачивает реальные `<rect>` элементы (`grep -rn "<Tooltip" src/components/backtest/`).
- [ ] **Если точка вызова не найдена** — `⚠️ NOT CONNECTED` в отчёте + следующая задача.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

**2 файла** (по фазе), каждый — 9 секций до 400 слов по шаблону `prompt_template.md`:

1. **`Спринты/Sprint_8/reports/DEV-3_FRONT1_W1.md`** — после задач 1.A + 1.B.
2. **`Спринты/Sprint_8/reports/DEV-3_FRONT1_W3.md`** — после задач 3.A + 3.B.

Шаблон секций (строго):
1. Что реализовано (5–10 пунктов).
2. Файлы (новые / изменённые / удалённые).
3. Тесты (vitest X/Y passed; tsc errors; lint warnings — фактические числа; failed → диагноз).
4. Integration points (`<thing>.<method>` вызывается из `<file:line>` ✅ или ⚠️ NOT CONNECTED + следующая задача).
5. Контракты (поставляю: нет / использую: lightweight-charts API, Mantine Tooltip, sequentialIndex.ts pattern).
6. Проблемы / TODO.
7. Применённые Stack Gotchas (минимум 1 — паттерн `sequentialIndex.ts` или ожидаемый `gotcha-24-*.md`).
8. Новые Stack Gotchas (если найдены — формат симптом/причина/правило/related_files).
9. Использование плагинов (typescript-lsp, context7 — для каких библиотек, playwright — какой URL, frontend-design — что согласовано, code-review — выполнен или нет).

**НЕ возвращай:** полный код, лог tool-вызовов.

# Alembic-миграция

Не требуется (FRONT1 не трогает backend / БД).

# Чеклист перед сдачей

- [ ] W1: задачи 1.A (S7R-DRAWING-EDITING) + 1.B (S7R-DRAWING-INTRADAY-COORDS) реализованы.
- [ ] W3: задачи 3.A (S7R-FE-LINT-WARNINGS-CLEANUP) + 3.B (S7R-HISTOGRAM-MANTINE-TOOLTIP) реализованы.
- [ ] Опциональная подзадача 3.A.4 (CI verification) явно закрыта **PASS** или **SKIP + reason**.
- [ ] Тесты зелёные: `pnpm vitest run` → 0 failures (число тестов в отчёте, baseline 468).
- [ ] TypeScript: `pnpm tsc --noEmit` → 0 errors.
- [ ] Lint: `pnpm lint` → 0 errors / 0 warnings (после W3).
- [ ] Playwright скриншот цикла drag editing сохранён в `Sprint_8/reports/DEV-3_screenshot_drawing_editing.png`.
- [ ] Integration verification checklist полностью пройден; для каждой новой сущности доказан вызов в runtime, не только в тестах.
- [ ] Формат отчёта соблюдён (9 секций × 2 файла, до 400 слов каждый).
- [ ] Отчёты сохранены: `DEV-3_FRONT1_W1.md`, `DEV-3_FRONT1_W3.md` в `Спринты/Sprint_8/reports/`.
- [ ] Cross-DEV contracts: поставщик = нет, потребитель = нет напрямую (косвенно `gotcha-24` pattern) — явно подтверждено в секции 5 отчёта.
- [ ] Stack Gotchas: минимум sequentialIndex pattern (или `gotcha-24-*.md` если уже создан) применён.
- [ ] Плагины использованы: typescript-lsp после каждого Edit/Write, context7 для lightweight-charts + Mantine, playwright screenshot, frontend-design pass перед DRAWING-EDITING, code-review после W1-блока.
- [ ] Skip-тикеты с карточками в `Sprint_8_Review/backlog.md`.
- [ ] `Sprint_8/changelog.md` обновлён немедленно после каждого блока (правило из `~/.claude/CLAUDE.md`).
- [ ] `Sprint_8/sprint_state.md` отражает прогресс твоих задач.
- [ ] LocalStorage compat: старые drawings пользователей не теряются после миграции на новую схему `Point.logical`.
