---
sprint: 7
agent: DEV-3 (FRONT1)
wave: 2
phase: 1
date: 2026-04-25
---

# DEV-3 (FRONT1) — отчёт W2 PHASE1

Скоуп этой волны — **только задача 7.6** (Drawing tools). 7.19 (AI слэш-команды) и саппорт 7.7 (sparklines) — в PHASE2 после публикации backend-контрактов C3 и C9.

## 1. Реализовано

- **7.6 Drawing tools.** Тулбар инструментов рисования слева от графика (`DrawingToolbar`), 9 кнопок: cursor / trendline / hline / vline / rect / label / список / delete / clear. Активный инструмент подсвечен (Mantine `variant=filled`, `aria-pressed`). Hotkeys `V/T/H/R/L`, `Esc` (отмена preview + cursor + снять выбор), `Delete` (удалить выделенное); работают через `window.keydown` listener и игнорятся когда фокус в input/textarea/contentEditable.
- **Рендер фигур (`DrawingsLayer`):** `hline` → нативный `series.createPriceLine()` (lightweight-charts API подтверждён через context7 `/websites/tradingview_github_io_lightweight-charts_5_0`). `trendline / rect / vline / label` → overlay `<canvas>` поверх chart-контейнера, `pointer-events:none`, перерисовка по `subscribeVisibleTimeRangeChange` + ResizeObserver. Координатные конверсии: `chart.timeScale().timeToCoordinate(timeWithMSKOffset)` + `series.priceToCoordinate(price)`. Preview во время двух-клик-фигур (trendline/rect) — синий цвет.
- **Persist:** REST CRUD `chartDrawingsApi` (5 endpoint'ов) + fallback на `localStorage[drawings:{userId}:{ticker}:{tf}]` с квотой 100 рисунков на ключ. Optimistic update в store: сначала локально, затем backend.
- **a11y / UX:** `role=toolbar`, `aria-label="Инструменты рисования на графике"`, `aria-label`/`aria-pressed` на каждой кнопке, Mantine Tooltip с подсказкой клавиш. Tablet/mobile вариант (`horizontal=true` prop) — не подключён в ChartPage, но готов для адаптива.

## 2. Файлы

NEW:
- `Develop/frontend/src/api/chartDrawingsApi.ts`
- `Develop/frontend/src/utils/drawingsPersistence.ts`
- `Develop/frontend/src/stores/chartDrawingsStore.ts`
- `Develop/frontend/src/components/charts/DrawingToolbar.tsx`
- `Develop/frontend/src/components/charts/DrawingsLayer.tsx`
- Tests: `utils/__tests__/drawingsPersistence.test.ts`, `stores/__tests__/chartDrawingsStore.test.ts`, `components/charts/__tests__/DrawingToolbar.test.tsx`.

MODIFIED:
- `Develop/frontend/src/components/charts/CandlestickChart.tsx` — добавлен optional prop `onChartReady?: (chart, series) => void` + стабильный ref + вызов после addSeries и в cleanup. Существующее поведение (alertLines, sequentialMode, WS, markers) не затронуто.
- `Develop/frontend/src/pages/ChartPage.tsx` — Group layout с DrawingToolbar/Box(ref)/CandlestickChart/DrawingsLayer; setDrawingsContext useEffect; warning notification.

## 3. Тесты

- `cd Develop/frontend && pnpm test` → **316 passed / 0 failed (61 files)** (baseline 287/58, +29 / +3).
- `npx tsc --noEmit` → **0 errors**.
- Lint новых файлов: чистые. Pre-existing 6 errors не трогал (S7.R).
- Подробности: drawingsPersistence (9 test), chartDrawingsStore (8), DrawingToolbar (12) — покрывают: сохранение/загрузку/изоляцию по ключу, truncate >100, версионирование, optimistic flow, fallback на 404, hotkeys T/H/V/Esc, ARIA, disabled-состояния, переключение currentTool.

## 4. Integration points

- `grep -rn "DrawingToolbar\|DrawingsLayer\|useChartDrawingsStore" src/pages/` → `ChartPage.tsx:18-20, 45-47, 250, 265` (production).
- `grep -rn "useChartDrawingsStore" src/` → store используется в DrawingToolbar, DrawingsLayer, ChartPage, тестах.
- `grep -rn "onChartReady" src/` → CandlestickChart (объявление + вызов), ChartPage (callback). Не только в тестах.
- Все 4 новых модуля вызываются в production-коде.

## 5. Контракты

**Контракт frontend → backend (drawing_tools, по ARCH-delta `arch_design_s7.md` §8 + ТЗ §3.14):**

- `GET    /api/v1/charts/{ticker}/{tf}/drawings` → `ChartDrawing[]`
- `POST   /api/v1/charts/{ticker}/{tf}/drawings` → `ChartDrawing` (201)
- `PATCH  /api/v1/charts/drawings/{id}` body partial → `ChartDrawing`
- `DELETE /api/v1/charts/drawings/{id}` → 204
- `DELETE /api/v1/charts/{ticker}/{tf}/drawings` → 204 (clear all)

Schema: `{ id, user_id, ticker, timeframe, type ∈ {trendline,hline,vline,rect,label}, data: {p1?,p2?,price?,t?,text?,anchor?}, style?: {color,fill,lineWidth}, created_at, updated_at }`.

**⚠️ BACKEND-PENDING:** модель `ChartDrawing` есть в `Develop/backend/app/common/models.py:54`, миграция применена (`3d3e4e3036a6_initial_schema.py:144`), но REST router НЕ реализован. Frontend полностью функционален через localStorage-fallback (`backendAvailable=false` в store при первом 404). Технический долг для S7.R или S8.

## 6. Соответствие UX-макетам

`ux/drawing_tools.md`:
- §2 layout (вертикальный 48px слева) ✅, кнопки edit/delete/clear/separator ✅.
- §3.1-3.5 инструменты: cursor/trendline (2 клика)/hline (1 клик)/rectangle (2 клика, не drag — упрощено для надёжности subscribeClick) — ✅. Vline/label — добавлены сверх UX (промпт DEV-3 их упоминает).
- §4 states: idle/drawing (preview)/selected (anchor visible) — реализованы; editing(drag)/empty-tooltip — НЕ реализованы (за рамками PHASE1, известное ограничение).
- §6 cleanup при unmount/смене ticker/tf — ✅ (DrawingsLayer cleanup useEffect + setContext очищает items).
- §8 контракт с backend (REST + БД-источник истины) — ✅ frontend-side; backend pending.
- §9 a11y (aria-label, hotkeys, focus ring) — ✅. Hotkey `Backspace` добавлен как алиас Delete.
- §10 Stack Gotchas — применены: lightweight-charts cleanup ✅, localStorage quota ✅, timeScale conversion ✅.
- §11 data-testid — точное совпадение: `chart-toolbar`, `chart-tool-cursor/trendline/hline/vline/rect/label/edit/delete/clear`, плюс `chart-drawings-editor`, `chart-clear-confirm`, `chart-drawings-canvas`.

Delta vs макет: drag-edit/move выделенной фигуры не реализован в PHASE1 (требует hit-test на canvas). Записано в долг.

## 7. Применённые Stack Gotchas

- **lightweight-charts cleanup** — DrawingsLayer cleanup: removeChild canvas, removePriceLine для всех hline, unsubscribeClick/Crosshair/VisibleTimeRange, ResizeObserver.disconnect(). При смене series (onChartReady(null,null)) priceLines очищаются автоматически.
- **localStorage quota (UX W0 кандидат)** — hard limit MAX_DRAWINGS_PER_KEY=100 + try/catch QuotaExceededError → store.warning → Notification toast в ChartPage.
- **#16 (401 race)** — не релевантно (fallback на localStorage не требует токена); store при ошибке backend просто переходит в `backendAvailable=false`, не блокирует UI.

## 8. Новые Stack Gotchas + плагины

**Кандидат на новый gotcha (для ARCH-ревью):** **«lightweight-charts: timeScale.timeToCoordinate ожидает Time в формате серии (не сырое UTC)»**.

- **Симптом:** trendline/rect рендерятся с горизонтальным сдвигом ≈ 3 часа от точки клика.
- **Причина:** `CandlestickChart` хранит time как `unix_sec_utc + MSK_OFFSET_SEC` (lightweight-charts всегда показывает оси в UTC, поэтому MSK имитируется сдвигом данных). DrawingsLayer обязан использовать ту же конверсию: `isoToTime(iso) = unix_sec_utc + MSK_OFFSET_SEC`. При subscribeClick — обратное вычитание `(param.time as number) - MSK_OFFSET_SEC` перед сохранением ISO.
- **Правило обхода:** любой сторонний overlay поверх CandlestickChart должен импортировать константу `MSK_OFFSET_SEC` (или хелперы) из общего места. Вынести в `components/charts/utils.ts` — задача S7.R.
- **related_files:** `Develop/frontend/src/components/charts/DrawingsLayer.tsx:23-28, 232-235`, `Develop/frontend/src/components/charts/CandlestickChart.tsx:34-43`.

**Известные ограничения (не gotcha, а tech-debt):**
- Drawing tools в **sequential mode** (intraday TF) — `time` это индекс свечи, конверсия другая. Сейчас фигуры в intraday могут рисоваться неточно. Долг.
- Drag/перенос/изменение углов выделенной фигуры — UX §4 «editing» не реализован в PHASE1.

**Плагины:**
- **typescript-lsp** (fallback `npx tsc --noEmit`) — после каждого Edit/Write, финал: 0 errors.
- **context7** `/websites/tradingview_github_io_lightweight-charts_5_0` — подтверждены API: `subscribeClick(handler)`, `subscribeCrosshairMove(handler)`, `series.createPriceLine(opts)`, `series.priceToCoordinate(price)`, `series.coordinateToPrice(y)`, `chart.timeScale().timeToCoordinate(time)`. Custom primitives (`attachPrimitive`) рассмотрены, но решено использовать overlay-canvas — проще и достаточно для S7.
- **playwright** — dev-сервера (frontend:5173, backend:8000) не запущены в среде агента (`curl localhost:5173 → 000`). Скриншот **не сделан**, прошу заказчика приложить ручной скриншот ChartPage с тулбаром в приёмке.
