# [Sprint_5_Review] E2E S4 fix: починить 30+ падающих тестов

> Задача из техдолга #2 Medium S5 («30+ E2E тестов S4 падают — AI Chat, Backtest, Blockly»), перенесена в Sprint_5_Review при открытии ревью 2026-04-14.
> **Приоритет:** 🔴 Блокер — без работающего Playwright baseline нельзя валидировать новый E2E для Live Runtime Loop (задача 2).

## Контекст

В Sprint 4 (M2 Бэктест) написано ~30+ E2E-тестов для AI Chat, Backtest workflow и Blockly-редактора. Файлы:
- `frontend/e2e/s4-review-ai-chat.spec.ts`
- `frontend/e2e/s4-review-blockly-backtest.spec.ts`
- `frontend/e2e/s4-review-full.spec.ts`
- `frontend/e2e/s4-review.spec.ts`
- `frontend/e2e/test-backtest-fixes.ts` (не-spec, возможно утилита)
- `frontend/e2e/test-backtest-flow.ts` (не-spec, возможно утилита)
- `frontend/e2e/test-lkoh-full.ts` (не-spec)

**С момента Sprint 4 эти тесты падают.** В техдолге #2 Medium зафиксировано, но в S5 их не чинили. ARCH-ревью S5 упомянул факт в рекомендациях для будущих спринтов, но не исправил.

### Причины падений (гипотезы, подтверждаются в процессе работы)

1. **Изменения селекторов** — за S4+S5 компоненты существенно переделаны: новые Mantine-версии, Blockly 12.x, новые структуры Tabs, Autocomplete, Select. Селекторы `getByRole`, `getByTestId`, `getByText` могут промахиваться.
2. **Изменения URL-структуры** — в S5 добавлены новые роуты и query-параметры:
   - `?tab=description` в `StrategyEditPage`
   - `/backtests/{id}/rerun` endpoint
   - Навигация `← К стратегии` с `strategy_id`
3. **Изменения Zustand stores** — новые методы `rerunBacktest`, новые утилиты `recentInstruments`, изменения `backtestStore.error`. Тесты могут ожидать старые сигнатуры.
4. **Изменения API ответов** — новые поля в Backtest response (`strategy_id`), новые endpoints. Старые моки в тестах могут не соответствовать.
5. **Flaky тесты** — отсутствие явных `waitFor` / `expect.poll` для async-операций. При обновлении React 19 + новые таймауты могли усилить flakiness.
6. **React 19 behavior changes** — strict mode + concurrent features могут ломать тесты, которые полагались на синхронное поведение.

### Почему задача — блокер

- Для задачи 2 (Live Runtime Loop) критерий готовности — **E2E тест «fake market publisher → session → LiveTrade в БД»**. Если существующие тесты в общем прогоне красные, новый E2E утонет в хаосе — нельзя будет отличить его регрессию от старых падений.
- Integration Verification Checklist в `prompt_template.md` требует «тесты зелёные». Если до фикса половина E2E красная, DEV-агенты будут путаться, что им чинить.
- ARCH-ревью S5R не сможет дать `PASS WITH NOTES`, если Playwright baseline сам сломан.

## Что нужно сделать

### Фаза 1: Диагностика

1. Запустить `cd frontend && npx playwright test` на текущем состоянии `develop` (после CI cleanup — задача 1).
2. Зафиксировать **точный список** упавших тестов и причины по каждому:
   ```
   s4-review-ai-chat.spec.ts > "AI chat sends message" — timeout waiting for .ai-chat-input
   s4-review-blockly-backtest.spec.ts > "strategy compiles" — ReferenceError: Blockly is undefined
   ...
   ```
3. Сгруппировать по причинам: селекторы, URL, stores, API, flaky, React 19.

### Фаза 2: Починка

**Правило: не коммит на каждый тест, а один логический фикс на группу.**

4. **Селекторы** — заменить устаревшие на новые. Использовать `data-testid` там, где роль нестабильна.
5. **URL-структура** — обновить ожидания URL (`?tab=description` и т.п.), добавить проверки query-параметров.
6. **Stores** — обновить моки и ожидания под новые методы. Если тест делает `jest.spyOn(useBacktestStore.getState(), ...)` — пересверить сигнатуру.
7. **API моки** — обновить типы ответов (`Backtest.strategy_id`), пересверить MSW/Playwright mocks.
8. **Flaky** — добавить явные `await expect(...).toBeVisible({ timeout: 5000 })`, `waitFor`, `expect.poll` там, где их нет.
9. **React 19** — если тест полагался на синхронный re-render, переписать через `await expect(...)` / `waitFor`.

### Фаза 3: Не-spec файлы

10. `test-backtest-fixes.ts`, `test-backtest-flow.ts`, `test-lkoh-full.ts` — разобрать:
    - Если это вспомогательные утилиты (helpers) — переместить в `e2e/utils/` или `e2e/helpers/`, обновить ESLint конфиг чтобы их не проверял как тесты
    - Если это черновики незаписанных тестов — дописать до рабочего состояния или удалить
    - Если это deprecated — удалить

### Фаза 4: Playwright в CI

11. Проверить, запускается ли `pnpm playwright test` в CI вообще. Если нет — **добавить шаг** в `.github/workflows/ci.yml`:
    ```yaml
    - name: E2E tests
      run: cd frontend && npx playwright install --with-deps && npx playwright test
    ```
    Это требует:
    - Установки Playwright browsers в CI (несколько минут)
    - Запуска backend + frontend серверов перед тестом (через `playwright.config.ts` webServer)
    - Возможно, тестовой базы данных
12. Если E2E в CI существенно замедлит workflow — рассмотреть отдельный job `e2e` с `if: github.event_name == 'pull_request'`, чтобы не гонять на каждый коммит в `develop`.

### Фаза 5: Integration Verification

13. После всех правок локально:
    - `cd frontend && npx playwright test` → 0 failures (допустимы `test.skip()` с тикетом в аннотации)
    - `cd frontend && npx playwright test --project=chromium` → 0 failures
14. Push в feature-ветку → проверка CI → все тесты зелёные
15. В отчёте DEV указать **количество**: «X тестов было, Y починено, Z skipped с обоснованием»

## Файлы, которые затронет задача

| Файл | Изменение |
|------|-----------|
| `Develop/frontend/e2e/s4-review-ai-chat.spec.ts` | Обновление селекторов, URL, ожиданий |
| `Develop/frontend/e2e/s4-review-blockly-backtest.spec.ts` | То же |
| `Develop/frontend/e2e/s4-review-full.spec.ts` | То же |
| `Develop/frontend/e2e/s4-review.spec.ts` | То же |
| `Develop/frontend/e2e/test-backtest-fixes.ts` | Переместить в `e2e/helpers/` или удалить |
| `Develop/frontend/e2e/test-backtest-flow.ts` | То же |
| `Develop/frontend/e2e/test-lkoh-full.ts` | То же |
| `Develop/frontend/e2e/helpers/*.ts` (возможно новая папка) | Вспомогательные функции |
| `Develop/.github/workflows/ci.yml` | Возможно добавление e2e job |
| `Develop/frontend/playwright.config.ts` | Уточнения webServer если нужно |

## Связь с другими задачами S5R

| Задача | Связь |
|--------|-------|
| **Задача 1** CI cleanup | **Предусловие** — после неё `pnpm lint` и `pnpm tsc --noEmit` зелёные, что уже убирает половину ошибок в e2e-файлах (unused-vars, no-explicit-any). Эта задача продолжает ту же линию — «baseline tests работают». Исполняется тем же DEV-агентом (DEV-1). |
| **Задача 2** Live Runtime Loop | **Потребитель** — новый E2E `s5r-live-runtime.spec.ts` от Live Runtime Loop должен встраиваться в общий зелёный прогон |
| **Задача 3** Реальные позиции T-Invest | Независима, но тоже добавит E2E `s5r-real-account.spec.ts` |

## Критерии готовности

- [ ] `cd frontend && npx playwright test` → 0 failures на чистой ветке S5R
- [ ] В `arch_review_s5r.md` указано точное число: «X тестов прогоняется, Y passing, Z skipped»
- [ ] Все `skipped` тесты имеют аннотацию `test.skip(reason, ticket)` с тикетом (или `TODO` комментарием со ссылкой на issue)
- [ ] Не-spec файлы `test-backtest-*.ts`, `test-lkoh-*.ts` разобраны: удалены, перемещены в helpers, или дописаны как полноценные spec
- [ ] (опционально) E2E job добавлен в `.github/workflows/ci.yml`
- [ ] **Cross-DEV contract C10** (из `execution_order.md`) подтверждён в отчёте DEV
- [ ] Новые E2E тесты от задач 2 и 3 S5R встраиваются в общий прогон без регрессии существующих

## Риски

1. **Объём неизвестен до диагностики.** 30+ тестов могут оказаться 30+ мелкими правками (1 час работы) или 30+ крупными (1-2 дня). **Митигация:** фаза 1 (диагностика) даёт точную оценку. Если объём слишком большой — разделить на «критические» (блокирующие задачу 2) и «некритические» (можно skip'ать с тикетом).
2. **React 19 может требовать переписывания не отдельных строк, а архитектуры теста.** Например, `act()` в React 19 работает иначе, чем в 18. **Митигация:** начать с простейших тестов, накопить опыт, потом переходить к сложным.
3. **Playwright install в CI существенно замедлит workflow.** Фул прогон E2E с установкой браузеров — 5-10 минут. **Митигация:** cache Playwright browsers через `actions/cache`, запуск только на PR (не на каждый push в develop).
4. **Flaky тесты могут возвращаться.** После фикса один раз, тест может пройти, а через день упасть из-за race condition. **Митигация:** использовать `expect.poll`, `waitFor` с достаточными таймаутами, избегать `page.waitForTimeout` (sleep).

## Ссылки

- Playwright: https://playwright.dev/docs/intro
- React 19 + testing: https://react.dev/blog/2024/12/05/react-19#act
- Stack Gotchas: `Develop/CLAUDE.md` — в ходе этой задачи возможно появится новая Gotcha про E2E + React 19
- Техдолг: `Спринты/project_state.md` пункт #2
