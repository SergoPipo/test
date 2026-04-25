# UX-макет: Инструменты рисования на графике (для задачи 7.6)

> **Статус:** заполнен UX-агентом на W0 (2026-04-25).
> **Источники:** `Sprint_7/sprint_design.md` Приложение D, `Sprint_7/prompt_UX.md` задача 3.
> **Связь с задачей S7:** 7.6 «Инструменты рисования на графике (lightweight-charts)».
> **Stack Gotchas:** см. `Develop/stack_gotchas/INDEX.md` — lightweight-charts series cleanup; mount/unmount порядок; resize handler.

---

## 1. Описание сценария

Пользователь открывает `/chart?ticker=SBER&tf=1H`. Слева от графика появляется вертикальный тулбар с инструментами разметки. Активируя инструмент, пользователь рисует трендовые линии, горизонтальные уровни и прямоугольные зоны. Объекты сохраняются в `localStorage` по ключу `drawings:{user_id}:{ticker}:{tf}`. При смене ticker/tf — текущие рисунки выгружаются, загружаются новые. Backend не задействован.

---

## 2. Расположение тулбара

**Решение:** вертикальный тулбар слева от графика (как TradingView).

```
┌─ ChartPage ─────────────────────────────────────────────────────────────┐
│ [Ticker: SBER ▾]  [TF: 1H ▾]      [Bg(2)]              sergopipo ▾      │
├──┬──────────────────────────────────────────────────────────────────────┤
│  │                                                                      │
│ ◉│   ← Cursor (active)                                                  │
│  │                                                                      │
│ ╱│   ← Trendline                                                        │
│ ─│   ← Horizontal level                                                 │
│ ▢│   ← Rectangle zone                                                   │
│  │                                                                      │
│ ✎│   ← Edit (manage list)                                               │
│ ⌫│   ← Delete selected                                                  │
│  │   (separator)                                                        │
│ ⟲│   ← Clear all (with confirm)                                          │
│  │                                                                      │
│  │                                                                      │
│  └──────────────────────────────────────────────────────────────────────┤
│                                                                         │
│         [lightweight-charts Series + Drawing Layer]                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

- Ширина тулбара 48px, прижат слева к графику. Иконки — Mantine `<ActionIcon variant="subtle" size="lg">` или Tabler-icons.
- Активный инструмент — `<ActionIcon variant="filled">` с акцентным цветом.
- Tooltip справа от иконки (hover).

Tablet/mobile (<768px): тулбар становится горизонтальным, прижат к верху графика, без подписей (`<ActionIcon size="md">`).

---

## 3. Инструменты

### 3.1 Курсор (по умолчанию)

- Возвращает к стандартному pan/zoom графика.
- Клик по нарисованному объекту — выделяет его (см. § 4 «Selected»).

### 3.2 Трендовая линия

- Активация → cursor crosshair.
- 1-й клик — startPoint.
- При движении мыши — preview линии (lightweight-charts series или canvas overlay).
- 2-й клик — endPoint, объект финализируется и записывается в storage.
- Esc во время рисования — отмена (preview исчезает).
- Двойной клик 2-й точкой завершает с тем же поведением.

### 3.3 Горизонтальный уровень

- Активация → cursor crosshair.
- 1 клик — `priceLine` через `series.createPriceLine()` (нативный API lightweight-charts).
- Параметры: цвет (по умолчанию yellow), `lineStyle: 'dashed'`, `axisLabelVisible: true`.

### 3.4 Прямоугольная зона

- Активация → cursor crosshair.
- Drag (mousedown → drag → mouseup) — рисует прямоугольник (canvas overlay поверх chart).
- Параметры: fill (полупрозрачный, alpha 0.15), stroke (тот же цвет, без прозрачности).

### 3.5 Edit / Delete / Clear

- Edit (✎) — открывает Mantine `<Drawer position="right">` со списком всех объектов: `[type, ticker, tf, label?]`, действия per-row (`Удалить`, `Изменить цвет`).
- Delete (⌫) — удаляет выделенный объект. Disabled если ничего не выбрано.
- Clear (⟲) — диалог подтверждения «Удалить все рисунки на SBER, 1H?» → очищает storage + chart.

---

## 4. States

| State | Визуал | Действия |
|-------|--------|---------|
| Idle (cursor) | курсор default | hover на объекте — slight glow |
| Drawing | crosshair + preview объекта | Esc — cancel; click — finalize |
| Selected | объект — толще на 1px, anchor-точки на концах (для линий — 2 точки, для rect — 4 угла + 4 стороны) | Drag за anchor — изменение размеров; Drag за тело — перенос целиком; контекстное меню (right-click) — `Удалить`, `Изменить цвет`; Del — удалить |
| Editing (drag) | курсор `grabbing` | при mouseup — сохранить новое положение в storage |
| Empty | пустой график | подсказка-tooltip над тулбаром «Выберите инструмент» (только при первом визите) |

Persist:
- При любом изменении (create/edit/delete) — синхронная запись в `localStorage[drawings:{user_id}:{ticker}:{tf}]`.
- При смене `ticker` или `tf` — выгружаем текущий слой (`series.removePriceLine`, `chart.remove`), загружаем рисунки нового ключа.

---

## 5. ASCII-mockup (рисуем трендовую линию)

```
┌──────────────────────────────────────────────────────────────────┐
│ SBER  1H                                                         │
├──┬───────────────────────────────────────────────────────────────┤
│ ◉│                                            ●─────              │
│ ╱│ ←active                                  ╱                    │
│ ─│                                        ╱                      │
│ ▢│                                      ●                        │
│  │ ← cursor here                                                 │
│  │                                                               │
│  │   ↑↑ preview during drawing                                  │
└──┴───────────────────────────────────────────────────────────────┘
```

Selected (трендовая):

```
                      ●═══════ (selected, толще)
                     ╱
                    ╱
                   ●            ← anchor points
```

---

## 6. Поведение / связи

- При unmount компонента графика — `useEffect` cleanup: удалить series/lines, отписаться от resize observer (`Develop/stack_gotchas/INDEX.md` ловушка про lightweight-charts cleanup).
- `useEffect` deps: `[ticker, tf, userId]` — при смене реинициализация рисунков.
- Изменения в storage синхронизируются между табами (опционально — `window.addEventListener('storage')`); если упрощаем — last-write-wins на refresh.
- Resize окна — все объекты пересчитываются (lightweight-charts handles чрез timeScale).

---

## 7. Связь с другими экранами

- `/chart` (sole consumer) — других экранов нет.
- Опционально: backtest-страница может показывать рисунки read-only поверх графика результата (за рамками S7, оформить как идею в S8).

---

## 8. Контракт с backend

> **ARCH-delta (2026-04-25, `arch_design_s7.md` §8):** ТЗ §3.14 описывает таблицу `chart_drawings`. ARCH принял решение **persist в БД**, а не в localStorage (как в первоначальной версии этого макета). UX обновляется: localStorage остаётся только как кэш на время offline / draft, источник истины — БД.

- Endpoints (BACK + FRONT):
  - `GET /api/v1/charts/{ticker}/{tf}/drawings` → массив объектов (см. schema ниже).
  - `POST /api/v1/charts/{ticker}/{tf}/drawings` body — один объект → 201 + созданный.
  - `PATCH /api/v1/charts/drawings/{id}` body — частичные поля.
  - `DELETE /api/v1/charts/drawings/{id}`.
  - `DELETE /api/v1/charts/{ticker}/{tf}/drawings` — clear all (на текущем ticker/tf).
- Схема таблицы (по ТЗ §3.14): `chart_drawings(id, user_id, ticker, tf, type, payload JSON, created_at, updated_at)`.
- При offline / API недоступно — frontend сохраняет в localStorage, при возврате online — sync.

Schema (localStorage):

```json
{
  "version": 1,
  "items": [
    {"id": "uuid", "type": "trendline", "p1": {"t": 1714032000, "p": 305.5}, "p2": {"t": 1714063600, "p": 312.0}, "color": "#fbbf24", "createdAt": "2026-04-25T..."},
    {"id": "uuid", "type": "hline", "price": 305.5, "color": "#22c55e"},
    {"id": "uuid", "type": "rect", "p1": {"t": 1714032000, "p": 305.5}, "p2": {"t": 1714063600, "p": 312.0}, "fill": "#22c55e26"}
  ]
}
```

---

## 9. Доступность

- ActionIcon с `aria-label` («Трендовая линия», «Горизонтальный уровень», «Прямоугольник», «Удалить»).
- Hotkeys (видны в tooltip):
  - `T` — трендовая линия.
  - `H` — горизонтальный уровень.
  - `R` — прямоугольник.
  - `Esc` — отменить рисование / снять выбор.
  - `Delete` — удалить выделенный объект.
  - `V` — курсор.
- Visual focus ring на ActionIcon.
- Контраст цветов рисунков на тёмной теме — palette подобрана из Mantine yellow-5/green-5/red-5.

---

## 10. Stack Gotchas — пометки

- **lightweight-charts series cleanup** (`gotcha-NN-lightweight-charts-cleanup.md` если есть, иначе создать в W3): при unmount/смене ticker — обязательно `chart.removeSeries(...)` и снять resize observer; иначе утечка памяти и double-render.
- **localStorage quota** (новый Stack Gotcha кандидат): ограничить число объектов на ключ (max 100), при превышении — toast «Слишком много рисунков, удалите часть».
- **timeScale conversion**: координаты сохраняем в (ts, price), не в screen px — иначе при zoom/pan объекты «уезжают». См. lightweight-charts API `timeScale().timeToCoordinate()`.

---

## 11. Тестовые сценарии для QA

(в `e2e_test_plan_s7.md`, секция 7.6)

1. Активировать «Трендовая линия» → 2 клика → линия отрисована.
2. Refresh страницы → линия осталась (persist).
3. Сменить tf 1H → 4H → линия исчезла (другой ключ).
4. Вернуться на 1H → линия снова есть.
5. Drag за середину линии → перенос; refresh → линия в новом положении.
6. Drag за anchor-точку → изменение угла.
7. Удалить через контекстное меню → линия пропала; refresh — её нет.
8. Запустить «Очистить всё» → подтверждение → пусто; refresh — пусто.
9. Hotkey T активирует Trendline.
10. Esc во время рисования отменяет preview.
11. Сменить ticker SBER → GAZP → рисунки SBER не показаны на GAZP.

`data-testid`:
- `chart-toolbar`, `chart-tool-cursor`, `chart-tool-trendline`, `chart-tool-hline`, `chart-tool-rect`, `chart-tool-edit`, `chart-tool-delete`, `chart-tool-clear`.
- `chart-drawing-{id}` (для каждой нарисованной фигуры).
