# QA W3 (7.11) — Финальный E2E регресс Sprint 7

**Дата:** 2026-04-26
**Агент:** QA
**Команда:** `cd Develop/frontend && npx playwright test --reporter=line`
**Окружение:** dev-серверы подняты через `restart_dev.sh` (backend :8000 / frontend :5173, оба HTTP 200).
**Длительность прогона:** ~4 мин 54 с.

---

## 1. Total

- **Total: 139 / 135 passed / 1 failed / 3 skipped**
- Запуск без фильтров, headless chromium, workers=1, retries=0 (CI=false).

## 2. Diff vs baseline 119 (Sprint 6 Review)

| Метрика | S6 Review baseline | S7 final | Δ |
|---------|-------------------:|---------:|--:|
| passed | 119 | 135 | **+16** |
| failed | 0 | 1 | **+1** |
| skipped | 3 | 3 | 0 |
| total | 122 | 139 | +17 |

Прирост +17 тестов даёт три новых S7-spec'а:
- `s7-drawing-tools.spec.ts` — 8 (7.6, FRONT1 PHASE1).
- `s7-ai-commands.spec.ts` — 5 (7.19, FRONT1 PHASE2).
- `s7-front2.spec.ts` — 4 (7.7 / 7.8-fe / 7.1-fe / 7.2-fe, FRONT2 W2).

Из этих 17 новых passed — 16 (один failing — see §3 — не из новых, а regression в legacy `ai-chat.spec.ts`).

Критерий приёмки 7.11 (`≥ 119 + ≥ 15 = ≥ 134 passed / 0 failed`) выполнен **частично**: passed = 135 (≥ 134 ✅), но failed = 1 ❌ из-за data-testid drift в legacy spec, см. §3.

## 3. Failing tests

| # | Test | Файл / line | Симптом | Классификация |
|---|------|-------------|---------|---------------|
| 1 | `AI Chat Mode — Sprint 4 › 2. Send message -> receive AI response (mock)` | `e2e/ai-chat.spec.ts:68` | `expect(locator '[data-testid="chat-input"] textarea, [data-testid="chat-input"]').toBeVisible()` → element not found, timeout 5000 ms | **regression / data-testid drift** (gotcha-22 кандидат от 7.19) |

**Анализ:** в задаче 7.19 (FRONT1 PHASE2) `<Textarea data-testid="chat-input">` обёрнут в Mantine `<Combobox>` через `<Combobox.Target>`. Mantine `cloneElement` переписывает атрибуты дочернего элемента и `data-testid` теряется (атрибут уезжает на Combobox-обёртку, а не на DOM-textarea). Новый s7-spec FRONT1 уже использовал workaround `document.querySelector('textarea')`, и в отчёте `DEV-3_FRONT1_W2_PHASE2.md` это явно отмечено как **gotcha-22 кандидат**.

**Регресс подтверждён повторным прогоном** (`npx playwright test e2e/ai-chat.spec.ts`) — flakiness исключён.

**Не лечил production-код** (правило промпта). Также **не лечил spec** — фикс `ai-chat.spec.ts:81` через переход на `page.locator('textarea').first()` либо `page.locator('[data-testid="ai-chat"] textarea').first()` тривиален, но это не моя зона на 7.11. Передаётся на 7.R fix-волну вместе с решением по gotcha-22.

## 4. Skip-тикеты

3 skipped — все pre-existing baseline, новых skip не заведено.

| # | Skip | Файл | Причина | Карточка |
|---|------|------|---------|----------|
| 1 | `AI Chat Mode › 3. "Apply to blocks" button triggers block loading` | `e2e/ai-chat.spec.ts:97` | Кнопка disabled в mock-окружении (комментарий в коде) | **`S6R-AICHAT-APPLY-MOCK`** — добавлена в `Sprint_8_Review/backlog.md` |
| 2 | `Strategy Editor › mode B modal opens and shows template copy button` | `e2e/blockly.spec.ts:86` | mode B (template) feature не реализован | **`S5R-BLOCKLY-MODE-B-MODAL`** — добавлена в backlog |
| 3 | `Strategy Editor › mode B: check button is disabled without template text` | `e2e/blockly.spec.ts:90` | то же | **`S5R-BLOCKLY-MODE-B-CHECK`** — добавлена в backlog |

Все три — переносятся как технический долг, не блокируют S7.

## 5. Покрытие S7-задач

| Задача | Spec-файл | Сценариев в spec | Сценариев в e2e_test_plan_s7.md | Статус |
|--------|-----------|-----------------:|-------------------------------:|--------|
| 7.1 versions | `s7-front2.spec.ts` (1 из 4) | 1 | 4 (S7.1.1–S7.1.4) | ⚠️ partial (smoke only — drawer + список) |
| 7.2 grid search | `s7-front2.spec.ts` (1 из 4) | 1 | 2 | ⚠️ partial (modal + total cap, без heatmap) |
| 7.3 export CSV/PDF | — | 0 | 2 | ⚠️ NOT COVERED (E2E нет; backend pytest 867/0 покрывает) |
| 7.6 drawing tools | `s7-drawing-tools.spec.ts` | 8 | 4 | ✅ full + extra |
| 7.7 widgets | `s7-front2.spec.ts` (1 из 4) | 1 | 3 | ⚠️ partial (smoke render всех 3 виджетов) |
| 7.8 wizard | `s7-front2.spec.ts` (1 из 4) | 1 | 3 | ⚠️ partial (gate-checkbox; happy path + repeat не покрыты) |
| 7.9 backup | — | 0 | 3 (CLI subprocess) | ⚠️ NOT COVERED (E2E нет; backend OPS pytest 36/0) |
| 7.12 NotificationService | `s6-notifications.spec.ts` | 4 (regression) | 1 (regression-flag) | ✅ via S6 baseline |
| 7.13 5 event_type | — | 0 | 5 | ⚠️ NOT COVERED (backend MR.5 закрыт W1 тестами 39/0) |
| 7.14 Telegram callbacks | — | 0 | 2 | ⚠️ NOT COVERED (backend pytest BACK2 W1) |
| 7.15 WS sessions | `s5-paper-trading.spec.ts` | 4 (regression) | 2 | ⚠️ partial (paper-trading regression проходит; WS-specific нет) |
| 7.16 interactive zones | — | 0 | 4 | ⚠️ NOT COVERED |
| 7.17 background backtest | — | 0 | 4 | ⚠️ NOT COVERED |
| 7.18 AI slash backend | `s7-ai-commands.spec.ts` (5 fe → backend косвенно) | 5 | 3 | ✅ via FRONT |
| 7.19 AI slash frontend | `s7-ai-commands.spec.ts` | 5 | 3 | ✅ full |

**Итого:** 17 новых S7-сценариев, покрывают **6 фич полностью или частично из 15** задач плана. **9 задач без E2E spec'а** — все backend-задачи покрыты pytest, frontend-задачи 7.16/7.17 — НЕ покрыты вообще (карточки `S7R-E2E-7.16-MISSING`, `S7R-E2E-7.17-MISSING`, `S7R-E2E-7.3-MISSING`, `S7R-E2E-7.9-MISSING` заведены в backlog).

## 6. Stack Gotchas

- **gotcha-22 (кандидат) подтверждён E2E прогоном** — Mantine `<Combobox.Target>` через `cloneElement` теряет/переписывает `data-testid` дочернего `<Textarea>` (legacy spec `ai-chat.spec.ts:82` падает, новый `s7-ai-commands.spec.ts` обходит через `document.querySelector('textarea')`). Передаётся ARCH в 7.R: либо создать `Develop/stack_gotchas/gotcha-22-mantine-combobox-target-testid-clone.md`, либо зафиксировать как тестовый паттерн в `e2e/README.md`.
- Новых ловушек Playwright не выявлено.

## 7. Что передаётся ARCH (вход в 7.R)

1. **regression `ai-chat.spec.ts:68`** — фикс одной строки selector (либо `[data-testid="ai-chat"] textarea`, либо `chat-input` через `getByRole('textbox')`). Кандидаты на исполнителя: FRONT1 (он автор 7.19 и владеет gotcha-22).
2. **9 задач без E2E spec'а** — список в §5; решение ARCH: достаточно ли pytest+ручная приёмка, или нужен dev-time на S8.
3. Открытые вопросы W2 sub-wave 2 (унаследованы из `sprint_state.md` секция «Открытые вопросы»):
   - GridSearchHeatmap entry point из badge — PARTIALLY CONNECTED.
   - Pre-existing 6 frontend lint errors.
   - Health/ActivePositions widgets без unit-тестов.
   - Real-mode coverage `test_order_manager`.
4. **Production-код НЕ тронут** в 7.11 (правило промпта).
5. **E2E spec'ы НЕ правились** — selector-fix не делал, оставлено явно для 7.R fix-волны.

## 8. Применённые плагины

- **playwright** — основной (полный регресс + повторный прогон ai-chat).
- **typescript-lsp** — не использовался (spec'ы не правились).
- **context7** — не вызывался.
- **Read / Bash / grep** — стандартный набор.
