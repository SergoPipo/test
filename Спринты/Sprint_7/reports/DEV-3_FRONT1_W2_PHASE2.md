---
sprint: 7
agent: DEV-3 (FRONT1)
wave: 2
phase: 2
date: 2026-04-26
---

# DEV-3 (FRONT1) — отчёт W2 PHASE2

Скоуп: **Блок 1** саппорт 7.7 — `MiniSparkline` для FRONT2 (приоритет, опубликован первым); **Блок 2** задача 7.19 — AI слэш-команды dropdown + парсер + chip-рендер + интеграция с контрактом C3.

## 1. Реализовано

- **Блок 1 (7.7 саппорт):** SVG-`MiniSparkline` для виджетов дашборда. Empty/1-point/multi-point/range=0 ветки, `green|red|string` color, обязательный `aria-label`, опциональный `data-testid`. Чистый SVG (без lightweight-charts), безопасен внутри карточек 80×40 / 120×40.
- **Блок 2 (7.19):**
  - Парсер 5 команд (`/chart TICKER [TF]`, `/backtest ID`, `/strategy ID`, `/session ID`, `/portfolio`), множественный контекст в одном сообщении, валидация id (positive int / ticker regex), невалидные аргументы → остаются в `remainder`.
  - `CommandsDropdown` на Mantine `<Combobox>` (документация через context7 `/mantinedev/mantine`). Открывается при `/` в начале строки или после whitespace, фильтрация по префиксу, ↑/↓/Enter/Tab/Esc, **IME composition guard** (compositionstart/end — не открывает dropdown во время русского ввода).
  - `ContextChip` — `<Badge variant="light" leftSection={<icon/>}>` с react-router navigate; статусы `ok|forbidden|not_found` с tooltip («Нет доступа» / «Не найдено»).
  - Render `[CONTEXT]...[/CONTEXT]` в assistant-ответе → collapsible «Контекст» (defense-in-depth от echo backend'а).
  - Расширены `aiApi.ts`, `aiStreamClient.ts`, `aiChatStore.ts` — поле `context_items` отправляется параллельно с legacy `context` (не сломал блок-режим стратегии).

## 2. Файлы

NEW:
- `Develop/frontend/src/components/charts/MiniSparkline.tsx`
- `Develop/frontend/src/components/charts/__tests__/MiniSparkline.test.tsx`
- `Develop/frontend/src/components/ai/parseCommand.ts`
- `Develop/frontend/src/components/ai/CommandsDropdown.tsx`
- `Develop/frontend/src/components/ai/commandsDropdownHelpers.ts` (вынесено для react-refresh)
- `Develop/frontend/src/components/ai/ContextChip.tsx`
- `Develop/frontend/src/components/ai/__tests__/parseCommand.test.ts`
- `Develop/frontend/src/components/ai/__tests__/CommandsDropdown.test.tsx`
- `Develop/frontend/src/components/ai/__tests__/ContextChip.test.tsx`
- `Develop/frontend/e2e/s7-ai-commands.spec.ts`

MOD:
- `Develop/frontend/src/components/ai/ChatInput.tsx` — обёрнут в `CommandsDropdown` + IME composition handling.
- `Develop/frontend/src/components/ai/AIChat.tsx` — рендер `ContextChip` + collapsible `[CONTEXT]` блок.
- `Develop/frontend/src/api/aiApi.ts` — поле `context_items?: ChatContextItem[]` (legacy `context` сохранён).
- `Develop/frontend/src/services/aiStreamClient.ts` — параметр `contextItems` в `streamChat()`.
- `Develop/frontend/src/stores/aiChatStore.ts` — `parseCommand` + `ChatMessage.contextItems`.
- `Develop/frontend/src/components/ai/__tests__/ChatInput.test.tsx` — `getTextarea()` через DOM (Combobox.Target переписывает data-testid).

## 3. Тесты

- **Vitest:** `pnpm test --run` → **371 passed / 0 failed (65 files)** (baseline 316, +55 новых).
  - MiniSparkline: 7 (empty / 1-point / multi / range=0 / colors / a11y / size).
  - parseCommand: 34 (5 команд / multi-context / invalid args / edge cases / detectSlashPrefix / catalog).
  - CommandsDropdown: 6 (открытие / 5 опций / фильтр `/cha` / IME-guard / закрытие после whitespace / фильтр после слова).
  - ContextChip: 8 (chart / backtest / portfolio / navigate routes / forbidden / not_found / a11y).
  - ChatInput: 5 (адаптирован, все pass).
- **TSC:** `npx tsc --noEmit` → **0 errors**.
- **Lint:** новые файлы чистые; 10 pre-existing baseline ошибок (S7.R) не тронуты.
- **Playwright:** `npx playwright test e2e/s7-ai-commands.spec.ts` → **5 passed / 0 failed (7.3s)**.

## 4. Integration points (`grep -rn`)

- `MiniSparkline` → `Develop/frontend/src/components/dashboard/BalanceWidget.tsx:31` (FRONT2 уже импортировал параллельно — координация успешна) + тесты.
- `parseCommand` → `aiChatStore.ts:84,145` (sendMessage + sendMessageStream).
- `CommandsDropdown` → `components/ai/ChatInput.tsx`.
- `ContextChip` → `components/ai/AIChat.tsx:119`.
- `context_items` → `aiApi.ts:48`, `aiStreamClient.ts:60` (отправка в SSE body), `aiChatStore.ts:107` (sync), `aiChatStore.ts:passed-by-name` (stream).
- Все 4 новых модуля вызываются в production-коде, не только в тестах.

## 5. Контракты (потребитель)

**C3 (BACK2 → FRONT1):** `ChatRequest.context_items: list[ChatContextItem]` где `ChatContextItem = {type: 'chart'|'backtest'|'strategy'|'session'|'portfolio', id: int|str|None}`. Подтверждено по `Develop/backend/app/ai/chat_schemas.py:48`. Legacy `context: dict | None` (строка 46) сохранён без изменений — блок-режим стратегии не сломан. Backend сам выполняет ownership-check (404 на чужой ресурс), sanitization (control-chars + 2 КБ truncation), оборачивает в `[CONTEXT type=... id=...]\n...\n[/CONTEXT]\n`. Frontend-ответственность: парсинг slash-команд + отправка `(type, id)`.

## 6. Координация с FRONT2

- **MiniSparkline опубликован первым (приоритет промпта):** код + tests + tsc 0 + changelog запись «Блок 1 опубликован для FRONT2» обновлена ДО начала Блока 2. Контракт `MiniSparklineProps` точно соответствовал ожиданию FRONT2.
- На момент grep'а (после завершения Блока 2) FRONT2 уже импортировал `MiniSparkline` в `dashboard/BalanceWidget.tsx:31` и оставил комментарий «MiniSparkline используется без lightweight-charts cleanup (это чистый SVG от FRONT1)» — параллельная работа без конфликтов.
- Зоны не пересекались: я не трогал `pages/DashboardPage.tsx`, `components/dashboard/*`, `components/wizard/*` и др. файлы FRONT2.

## 7. Применённые Stack Gotchas

- **#16 (401 race relogin):** `aiStreamClient.ts` уже содержит refresh-loop, не сломан добавлением `context_items`.
- **lightweight-charts cleanup (соответствует #N PHASE1):** в Блоке 1 не применимо (SVG без подписок); в Блоке 2 не применимо (нет графиков).
- **JSDOM scrollIntoView mock** (известная ловушка тестов Mantine Combobox): добавлен `beforeAll` в `CommandsDropdown.test.tsx`, не трогая глобальный setup.

## 8. Новые Stack Gotchas + плагины

**Кандидат на новый gotcha (для ARCH-ревью):** **«Mantine `Combobox.Target` `cloneElement` переписывает `data-testid` дочернего input'а на `data-testid` самого Combobox»** (например, `ai-chat-slash-popover` затирает `chat-input` на textarea). Симптом: `screen.getByTestId('chat-input')` находит обёртку Combobox, а не textarea. Workaround: в тестах получать native textarea через `document.querySelector('textarea')`. Имя файла: `gotcha-22-mantine-combobox-target-testid-clone.md`. Опишу строку в `INDEX.md` после ARCH-ревью.

**Плагины:**
- **typescript-lsp** (fallback `npx tsc --noEmit`) — после каждого Edit/Write, финал по полному фронту: **0 errors**.
- **context7** `/mantinedev/mantine` — подтверждены API: `useCombobox({onDropdownOpen, onDropdownClose, loop})`, `Combobox.Target`, `Combobox.Dropdown`, `Combobox.Options`, `Combobox.Option`, `combobox.openDropdown()/closeDropdown()/selectFirstOption()`. Не использовал `searchable Select` — он жёстко связан с input'ом, не подходит для slash-команд внутри Textarea.
- **playwright** — dev-сервера были запущены (`curl :5173 → 200`, `:8000/health → 200`), spec выполнился полностью локально, **5/5 passed**.

## Скриншоты

- `Develop/frontend/e2e/screenshots/s7/s7-7.19-dropdown-open.png` — dropdown с 5 командами, открыт по `/`.
- `Develop/frontend/e2e/screenshots/s7/s7-7.19-filter-chart.png` — фильтрация `/cha` → только `/chart`.
- `Develop/frontend/e2e/screenshots/s7/s7-7.19-chip-in-message.png` — `/chart SBER ...` → chip `Chart: SBER` в user-сообщении.
- `Develop/frontend/e2e/screenshots/s7/s7-7.19-multi-chips.png` — `/chart SBER /backtest 42` → два chip в одном сообщении.
- `Develop/frontend/e2e/screenshots/s7/s7-7.19-portfolio-chip.png` — `/portfolio` без аргумента → chip `Portfolio`.
