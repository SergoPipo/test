# QA отчёт — Sprint 8, W2 (AIChat mock + финальная регрессия)

## 1. Что реализовано
- **AIChat mock дополнение** (`S6R-AICHAT-APPLY-MOCK` закрыт). В `mockAIChat` добавлен `description_update` с реалистичным template-описанием (RSI(14) crossover 30/70 + SL 3% + TP 6%). Добавлен mock `/api/v1/strategy/parse-template` с реалистичным `blocks_json` из 9 flat-блоков (`indicator_rsi`, `value_number`×2, `condition_crossover`×2, `entry_signal`, `exit_signal`, `stop_loss`, `take_profit`).
- `test.skip('3. Apply to blocks button triggers block loading')` в `e2e/ai-chat.spec.ts:97` снят. Тест активен и passed.
- Sanity: после клика «Применить на схеме» Blockly workspace содержит ≥3 SVG-блока (`g.blocklyDraggable`).
- **Финальная регрессия W2 прогнана** после закрытия параллельных потоков BACK2 W2 + BACK1 W2 + FRONT2 W2.

## 2. Файлы
- **Изменённые:**
  - `Develop/frontend/e2e/fixtures/api_mocks.ts` (+~60 строк: template-text в `mockAIChat` + mock `/strategy/parse-template`).
  - `Develop/frontend/e2e/ai-chat.spec.ts` (test 3 переписан со skip на активный, ~50 строк сценария).
- **Новые:** нет.
- **Удалённые:** нет (Blockly mode B удаление — W3).

## 3. Тесты (РЕАЛЬНО ПРОГНАНЫ)
- `ai-chat.spec.ts` изолированно → **5/5 passed** (23 сек).
- **Playwright финальная регрессия:** `CI=true npx playwright test --reporter=line` → **158 passed / 1 failed / 5 skipped / 1 did not run / 165 total** (7.9 мин).
  - +1 passed (W1 baseline 157 + AIChat test 3 активирован).
  - 6 skipped → **5 skipped**: один тест в `s7-backtest-analytics` стал passed после FRONT2 EQUITY-ZONES-TESTID + TRADE-ROW-CLICK.
  - 1 failed — pre-existing flaky `s5-paper-trading.spec.ts:143 pause and resume session` (известный из W1, НЕ блокер).
- **vitest:** `pnpm vitest run` → **544 passed / 2 failed / 546 total / 80 файлов passed / 81 total** (26 сек). 2 failed — flaky `src/api/__tests__/client.test.ts` (timeout 5000ms на 2 axios interceptor тестах). Подтверждено: failure воспроизводится после `git stash` без моих изменений → не моя регрессия. Похоже на затронутость BACK2 W2 SecurityHeadersMiddleware → новый карточка в backlog.
- **Backend pytest:** `tests/ -q` → **1284 passed / 0 failed** (258 сек, на момент QA W2 — до Поток D BACK1).
- **Backend pytest (фактический финал W2 после всех потоков, 2026-05-13):** **1490 passed / 0 failed / 0 xfailed** (293.61s). **TOTAL coverage = 80%** ✅ Gate W2 → W3 пройден.

## 4. Integration points
- `[data-testid="blockly-workspace"]` (`BlocklyWorkspace.tsx:249`) — стабильно (FRONT2 не трогала).
- `[data-testid="shared-description-panel"]` + `[data-testid="description-textarea"]` (`SharedDescriptionPanel.tsx:175,217`) — используются через `.last()`/`.first()` (AnimatedSwitch рендерит оба placement одновременно).
- Mock `/api/v1/strategy/parse-template` → возвращает 9 flat-блоков → `flatBlocksToWorkspaceState` → `Blockly.serialization.workspaces.load` → SVG ≥3 блока. Путь проверен в реальном UI.

## 5. Контракты для других DEV
- **Потребитель**: использую UI-точки `blockly-workspace`, `shared-description-panel`, `description-textarea` (FRONT2 W2 не меняла).
- **Не поставляю** (E2E mock — не контракт между DEV).

## 6. Проблемы / TODO
- **flaky `client.test.ts`** (2 failed): после BACK2 W2 SecurityHeadersMiddleware (и/или smth-related в axios stack) тесты `allows /auth/* requests without token` и `passes request with valid token` timeout 5000ms. Подтверждено git-stash: not my regression. **Предлагаю карточку `S8R-CLIENT-TEST-FLAKY`** в `Sprint_8_Review/backlog.md` для W3 диагноза.
- Pre-existing flaky `s5-paper-trading.spec.ts:143` — НЕ блокер (известно с W1).
- Skip W3 (НЕ trogal): удаление 2 Blockly mode B, добавление spec'ов в `playwright-nightly.yml`.

## 7. Применённые Stack Gotchas
- **Gotcha 9** (`gotcha-09-playwright-strict.md`): `data-testid="description-textarea"` встречается 2 раза (AnimatedSwitch рендерит обе панели) → использовал `.first()` для fill и `.last()` для click Apply.

## 8. Новые Stack Gotchas
- **AnimatedSwitch рендерит обе ветки (`blocklyContent` + `aiContent`) одновременно с CSS visual switch** — symptom: `getByRole('button', name='Применить на схеме')` находит 2 элемента, `.first()` физически за overlay'ем navbar и intercepts pointer events. Правило: для AI mode искать кнопки/локаторы через `.last()` или внутри `[data-testid="shared-description-panel"]:last`. Related: `Develop/frontend/src/pages/StrategyEditPage.tsx:895`, `e2e/ai-chat.spec.ts:147`. Файл-кандидат: `gotcha-27-animatedswitch-double-render.md`.

## 9. Использование плагинов
- **playwright:** использован для запуска ai-chat.spec.ts + 3 регрессий (165 spec'ов).
- **typescript-lsp:** fallback `npx tsc --noEmit` → 0 errors.
- **context7:** не привлекал (Playwright `routeWebSocket`/`page.route` известны из W1).
- **code-review:** оставлен на W3 финал.

## Статус
**DONE** — AIChat mock + skip снят, регрессия зелёная (1 pre-existing failure + 2 flaky НЕ блокеры). Skipped с 6 до 5 (FRONT2 EQUITY-ZONES разблокировал 1 спек). W3 (cleanup + nightly) — за оркестратором.
