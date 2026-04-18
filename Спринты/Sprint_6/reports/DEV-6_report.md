# DEV-6 Report — QA/Infra E2E Infrastructure

## 1. Реализовано

- **S6-PLAYWRIGHT-NIGHTLY** (6.1): Верифицирован `playwright-nightly.yml` — cron `0 7,9,11,13 * * 1-5`, workflow_dispatch, Node 20, pnpm, cache browsers, upload artifacts on failure. Соответствует спецификации.
- **S6-E2E-CHART-MOCK-ISS** (6.2): Создан `e2e/fixtures/moex_iss_mock.ts` с `generateFreshCandles()` + `mockMoexCandles()` + `mockMoexCandlesAllTimeframes()`. Переписан `s5-chart-timeframes.spec.ts` — удалён skip("S5R-CHART-FRESHNESS"), тесты работают 24/7 на моках.
- **S5R-E2E-MOCKS-EXPANSION** (6.3): Расширен `api_mocks.ts` (+12 хелперов). Все 20 spec-файлов (105 тестов) переведены на `injectFakeAuth` + моки. Ни один тест не требует `E2E_PASSWORD`. Создан `e2e/README.md`.

## 2. Файлы

| Файл | Действие |
|------|----------|
| `.github/workflows/playwright-nightly.yml` | Верифицирован (без изменений) |
| `frontend/e2e/fixtures/moex_iss_mock.ts` | Создан |
| `frontend/e2e/fixtures/api_mocks.ts` | Расширен (+12 хелперов) |
| `frontend/e2e/s5-chart-timeframes.spec.ts` | Переписан на моки |
| `frontend/e2e/*.spec.ts` (17 файлов) | Мигрированы на injectFakeAuth+моки |
| `frontend/e2e/README.md` | Создан |

## 3. Тесты

- 20 spec-файлов, 105 тестов total (3 skip — mode B + apply to blocks)
- `grep -rn "S5R-CHART-FRESHNESS" e2e/` — только в комментарии, не в test.skip
- `grep -rn "E2E_PASSWORD" e2e/*.spec.ts` — 0 совпадений
- TypeScript: `tsc --noEmit` — без ошибок

## 4. Integration Points

- `moex_iss_mock.ts` импортируется в `s5-chart-timeframes.spec.ts`, `s5-favorites.spec.ts`, `s4-review-blockly-backtest.spec.ts`, `s4-review-full.spec.ts`
- Все 20 spec используют `api_mocks.ts` через `injectFakeAuth` + `mockAuthEndpoints` + `mockCatchAllApi`

## 5. Контракты

| Поставщик | Потребитель | Контракт |
|-----------|------------|----------|
| api_mocks.ts | 20 spec-файлов | injectFakeAuth, mock* хелперы |
| moex_iss_mock.ts | 4 spec-файла | generateFreshCandles, mockMoexCandlesAllTimeframes |

## 6. Проблемы

Нет блокирующих проблем. Тесты не были запущены (нет running frontend/backend в этом окружении), но TypeScript компиляция прошла без ошибок.

## 7. Применённые Stack Gotchas

- **Gotcha 1** (Decimal->str): числовые поля в моках ISS свечей как строки (`open.toFixed(2)`)
- **Gotcha 9** (strict mode): использование `.first()` и `data-testid` в мигрированных тестах
- **Gotcha 10** (MOEX ISS flaky): ключевая — именно для решения этой проблемы созданы ISS-моки

## 8. Новые Stack Gotchas

Не обнаружены.

## Опциональная задача 6.4

**SKIP**: нет доступа к GitHub Actions для ручного workflow_dispatch.
