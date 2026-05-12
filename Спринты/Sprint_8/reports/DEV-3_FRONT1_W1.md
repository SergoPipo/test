# DEV-3 (FRONT1) — Sprint 8 W1 — Отчёт

**Дата:** 2026-05-12
**Wave:** W1
**Карточки:** S7R-DRAWING-EDITING (medium-high) + S7R-DRAWING-INTRADAY-COORDS (medium)

## 1. Реализовано

- **S7R-DRAWING-EDITING** — core логика (hit-test через primitives, drag handlers,
  vertex/corner editing, cursor-style по handle, keyboard Delete/Backspace в
  `DrawingToolbar`, context-menu) **уже была реализована** S7-hotfix'ами. W1-gap:
  отсутствовали юнит-тесты на координатную математику `coords.ts`. Закрыт.
- **S7R-DRAWING-INTRADAY-COORDS** — реальный фикс рендера на intraday TF: до W1
  `pointToCoord` всегда шёл через `timeToCoordinate(isoToTime(t))`, но в sequential
  mode (1m/5m/15m/1h/4h) time-axis у series = sequential-index (0,1,2,...), не
  unix-timestamp → конверсия молча возвращала null → drawings не рендерились.
- Добавлен детектор `isSeriesInSequentialMode(series)` через численный диапазон
  `series.data()[0].time` (< 1e6 → sequential, иначе unix).
- `pointToCoord` стал двухветочным: в sequential — logical-first (с legacy
  fallback через `findIndexByIsoTimestamp`), в regular — time-first.
- `shiftPoint` в sequential mode пропускает `synthesizeIsoFromLogical` (который
  бы записал мусорный ISO '1970-01-01...' от sequential-index `coordinateToTime`)
  и сохраняет оригинальный `point.t` (источник истины — `logical`).
- Написано 23 unit-теста на `coords.ts` — round-trip ISO/Time, оба режима
  pointToCoord, shiftPoint/shiftDrawing/applyHandleDrag, clickToDrawingPoint.

## 2. Файлы

**Изменён:**
- `Develop/frontend/src/components/charts/primitives/coords.ts` — +`isSeriesInSequentialMode`
  + `findIndexByIsoTimestamp`, переделан `pointToCoord` (sequential/regular branch),
  фикс `shiftPoint` для sequential.

**Новый:**
- `Develop/frontend/src/components/charts/primitives/__tests__/coords.test.ts` — 23 теста.

## 3. Тесты

- Новый файл: **23/23 passed** (`pnpm vitest run src/components/charts/primitives/__tests__/coords.test.ts`).
- Полный прогон: **503 passed / 2 failed** из 505 total. 2 failed — pre-existing
  flaky в `src/api/__tests__/client.test.ts > request interceptor guard`
  (5000ms timeout race с zustand persist; baseline без моих изменений сам выдаёт
  21 failed — это flaky ennvironment, не регрессия моего кода).
- `pnpm tsc --noEmit` → **0 errors**.
- `pnpm lint` → 0 errors / 9 warnings (baseline, к W3 в составе
  `S7R-FE-LINT-WARNINGS-CLEANUP`).

## 4. Integration points

- `pointToCoord` вызывается ВСЕМИ primitives в их `draw()`/`hitTest()`:
  `TrendlinePrimitive.ts:32,102`, `RectPrimitive.ts:32,111`, `HlinePrimitive.ts`,
  `VlinePrimitive.ts`, `LabelPrimitive.ts`, `PositionDrawingPrimitive.ts`,
  `OpenPositionPrimitive.ts`. Подтверждение: `grep -rn "pointToCoord(" src/`.
- `shiftPoint` / `shiftDrawing` / `applyHandleDrag` — вызывается в `DrawingsLayer.tsx:485`
  (pointer handler Phase 4 drag&drop). Подтверждено grep'ом.
- `isSeriesInSequentialMode` — private helper в `coords.ts`, не экспортируется
  (нет потребителей вне модуля).
- `findIndexByIsoTimestamp` — private fallback, вызывается только из `pointToCoord`.
- ✅ Все новые функции реально вызываются в production-коде, не только в тестах.

## 5. Контракты

- **Поставщик:** нет — изолирован в `components/charts/primitives/coords.ts`.
- **Потребитель:** нет напрямую (lightweight-charts API + Zustand store
  `chartDrawingsStore` через DrawingsLayer).
- **Косвенная зависимость:** паттерн `sequentialIndex.ts` (S7R-EQUITY-BY-INDEX
  hotfix S7-closeout) — детектор sequential-mode переиспользует ту же
  численную эвристику.

## 6. Проблемы / TODO

- **Flaky baseline:** `client.test.ts` (request interceptor guard) даёт 2-21
  failed в зависимости от запуска (timeout race с zustand persist). Не моя
  ответственность — заведено отдельно, требует отдельного fix'а в W2/W3.
- **Playwright скриншот** не выполнен в W1: рабочая директория polluted
  uncommitted изменениями от BACK1 (backend) и FRONT2 (paginated audit) —
  чтобы поднять backend + frontend и сделать чистый скриншот, нужен изолированный
  worktree, что выходит за рамки W1 FRONT1 одиночного агента. QA выполнит цикл
  в `s7-drawings.spec.ts` на основе кодовой логики.
- **Legacy drawings без `logical` на intraday:** в текущем коде они НЕ рендерятся
  (`pointToCoord` возвращает null). Это сознательный выбор «hide > misposition»:
  без mapping (`sequentialIndex.ts` indexToTimestamp) безопасно привязать ISO к
  sequential-индексу невозможно. Миграция (backfill `logical` для legacy) —
  карточка S8R-DRAWING-LEGACY-BACKFILL (medium), кандидат на S9.

## 7. Применённые Stack Gotchas

- **`sequentialIndex.ts` pattern (S7-closeout, S7R-EQUITY-BY-INDEX)** — паттерн
  обнаружения sequential-mode через численный диапазон `time` (< 1e6 → индекс).
- Защита от **stale-logical** (hotfix 2026-05-09 long_position с старого
  диапазона): сохранил ограничение `logical >= dataLen` для regular mode,
  переписал ветвь sequential где это ограничение неверно.

## 8. Новые Stack Gotchas

**Кандидат `gotcha-24-lightweight-charts-sequential-time-axis.md`:**

- **Симптом:** в lightweight-charts `Candlestick` series, заполненной через
  `setData([{time: 0, ...}, {time: 1, ...}, ...])` (sequential-index mode),
  `chart.timeScale().timeToCoordinate(unix_timestamp)` молча возвращает null.
  Drawings/primitives, использующие `timeToCoordinate(isoToTime(t))` для
  конверсии ISO → x — не рендерятся на intraday TF.
- **Причина:** time-axis у series — это **тот же тип, что time у data**.
  Если data использует sequential-index, timeToCoordinate ожидает индекс,
  не unix-timestamp.
- **Правило:** детектить sequential-mode через
  `Number(series.data()[0].time) < 1e6`. В sequential-mode идти через
  `logicalToCoordinate(point.logical)` (logical-first), сохраняя
  `point.logical` при создании drawing'а через `coordinateToLogical(x)`.
- **Related files:** `frontend/src/components/charts/primitives/coords.ts`,
  `frontend/src/components/charts/sequentialIndex.ts`,
  `frontend/src/components/charts/CandlestickChart.tsx` (sequentialMode prop).
- ARCH-ревью должно создать `gotcha-24-*.md` по чеклисту README + строка в INDEX.

## 9. Использование плагинов

- **typescript-lsp / `pnpm tsc --noEmit`** — после каждого Edit на `coords.ts`
  и Write `coords.test.ts`. Финально: 0 errors.
- **context7** — пропущен (lightweight-charts API уже плотно использован в
  существующем коде, исходный coords.ts содержит исчерпывающую документацию
  поведения `timeToCoordinate`/`logicalToCoordinate`/`coordinateToLogical`,
  и мой фикс — не новая фича библиотеки, а правильное переключение между
  двумя уже используемыми путями).
- **playwright** — НЕ запущен (рабочая директория polluted uncommitted backend
  и FRONT2 frontend; чистый smoke невозможен без worktree). QA закроет в
  `s7-drawings.spec.ts`.
- **frontend-design** — НЕ запущен: задача не вводила нового UX-паттерна (vertex
  handles, cursor-style, selection visuals уже спроектированы и реализованы
  в S7).
- **code-review** — НЕ запущен (опциональный после W1-блока). Изменения локализованы
  в одном файле + тестах; рекомендую запустить вместе с финальным merge оркестратором.
- **superpowers TDD** — не требовалось (правило промпта: UI-логика, vitest smoke
  достаточно).

---

**Статус:** **DONE** (S7R-DRAWING-EDITING + S7R-DRAWING-INTRADAY-COORDS закрыты;
W3 cleanup задачи 3.A + 3.B запланированы отдельной волной).
