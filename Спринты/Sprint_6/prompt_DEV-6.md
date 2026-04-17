---
sprint: S6
agent: DEV-6
role: "QA/Infra — E2E Infrastructure (Playwright Nightly + ISS Mocks + Mocks Expansion)"
wave: 2
depends_on: [DEV-1, DEV-2, DEV-3]
---

# Роль

Ты — QA/Infra-разработчик (senior), специалист по E2E-тестированию и CI/CD. Твоя задача — три инфраструктурных задачи по E2E:

1. **S6-PLAYWRIGHT-NIGHTLY** — cron-workflow для E2E в рабочие часы MSK.
2. **S6-E2E-CHART-MOCK-ISS** — моки MOEX ISS API для тестов свежести свечей.
3. **S5R-E2E-MOCKS-EXPANSION** — расширить `api_mocks.ts` на оставшиеся ~40 E2E тестов.

Работаешь в `Develop/frontend/` (E2E, фикстуры) и `Develop/.github/` (CI workflows).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Node >= 18, pnpm, Playwright installed
2. Текущий baseline:
   npx playwright test --reporter=list 2>&1 | tail -5
   → Зафиксируй: X passed / Y failed / Z skipped
3. Существующие файлы:
   - e2e/fixtures/api_mocks.ts         — injectFakeAuth, mockAuthEndpoints, mockBrokerAccounts/Balances/Positions/Operations, mockStrategies, mockInstrumentLogos, mockDefaultEmptyApis
   - e2e/s5-chart-timeframes.spec.ts   — 3 теста с skip("S5R-CHART-FRESHNESS")
   - .github/workflows/ci.yml          — CI workflow БЕЗ Playwright
   - playwright.config.ts              — Playwright конфиг
4. Тесты: `npx playwright test` → проверь текущее состояние
```

> **Правило от S5R.5:** предпроверку выполняй реально. Зафиксируй фактические результаты в отчёте (план vs факт).

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — особенно:
   - **Gotcha 1** (`gotcha-01-pydantic-decimal.md`) — Decimal → str. Моки должны возвращать строки для числовых полей.
   - **Gotcha 9** (`gotcha-09-playwright-strict.md`) — strict mode. Использовать `data-testid`.
   - **Gotcha 10** (`gotcha-10-moex-e2e-session.md`) — **ключевая для этой задачи**. E2E с живыми данными MOEX ISS flaky вне торговой сессии.

3. **`Спринты/Sprint_6/backlog.md`** — секции S6-PLAYWRIGHT-NIGHTLY, S6-E2E-CHART-MOCK-ISS, S5R-E2E-MOCKS-EXPANSION — полный контекст каждой задачи.

4. **Цитаты из backlog:**

   > **S6-PLAYWRIGHT-NIGHTLY:** «Завести отдельный workflow playwright-nightly.yml с cron-расписанием только в рабочие часы MSK (Mon-Fri, 10:00-18:00 MSK = 07:00-15:00 UTC), который гоняет Playwright тесты когда MOEX реально работает.»

   > **S6-E2E-CHART-MOCK-ISS:** «Написать полноценные моки MOEX ISS candles endpoint в e2e-фикстурах. Тесты перестают зависеть от живого API, могут гоняться 24/7. Формат ответа MOEX ISS API — строгий (массив [timestamp, open, high, low, close, volume, value]).»

   > **S5R-E2E-MOCKS-EXPANSION:** «В репо ещё ~40 других E2E тестов продолжают требовать E2E_PASSWORD и реальный login через UI. Фикстура есть, паттерн отработан, но применение ограничено двумя файлами.»

# Рабочая директория

`Test/Develop/frontend/` (для E2E), `Test/Develop/` (для .github/)

# Контекст существующего кода

```
- e2e/fixtures/api_mocks.ts       — Хелперы: injectFakeAuth(page), mockAuthEndpoints(page), mockBrokerAccounts(page, data), mockBrokerBalances, mockBrokerPositions, mockBrokerOperations, mockStrategies, mockInstrumentLogos, mockDefaultEmptyApis. Применены к 5 тестам в s5-account.spec.ts и s5-ticker-logos.spec.ts.
- e2e/s5-chart-timeframes.spec.ts — 3 skip-теста: 1m/5m/15m candle freshness. Skip reason: "S5R-CHART-FRESHNESS".
- .github/workflows/ci.yml        — Backend: ruff+mypy+pytest. Frontend: lint+tsc+vitest. Playwright НЕ включён.
- playwright.config.ts             — Базовый конфиг с chromium project.
```

# Задачи

## Задача 6.1: S6-PLAYWRIGHT-NIGHTLY — cron workflow

Создай `.github/workflows/playwright-nightly.yml`:

```yaml
name: Playwright (nightly, work hours MSK)
on:
  schedule:
    - cron: "0 7,9,11,13 * * 1-5"  # 10:00, 12:00, 14:00, 16:00 MSK, пн-пт
  workflow_dispatch:  # ручной запуск для отладки

jobs:
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - uses: pnpm/action-setup@v4
      - name: Install deps
        run: cd frontend && pnpm install --frozen-lockfile
      - name: Cache Playwright browsers
        uses: actions/cache@v4
        with:
          path: ~/.cache/ms-playwright
          key: playwright-${{ hashFiles('frontend/pnpm-lock.yaml') }}
      - name: Install Playwright browsers
        run: cd frontend && npx playwright install --with-deps chromium
      - name: Run E2E
        run: cd frontend && npx playwright test --project=chromium
        env:
          TEST_USER_LOGIN: sergopipo
          TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: frontend/playwright-report/
          retention-days: 7
```

**Важно:**
- Secret `TEST_USER_PASSWORD` — настраивается вручную в GitHub Settings → Secrets. Не хардкодить.
- `workflow_dispatch` — обязателен для ручного тестирования.
- Playwright НЕ добавлять в основной `ci.yml` (Gotcha 10).

## Задача 6.2: S6-E2E-CHART-MOCK-ISS — моки MOEX ISS

Создай `e2e/fixtures/moex_iss_mock.ts`:

```typescript
import { Page } from '@playwright/test';

/**
 * Генерирует массив свежих свечей в формате MOEX ISS.
 * Формат: [timestamp_ISO, open, high, low, close, volume, value]
 */
export function generateFreshCandles(
  ticker: string,
  timeframe: '1m' | '5m' | '15m' | '1h' | '4h' | 'D',
  count: number = 50,
  now: Date = new Date(),
): Array<[string, number, number, number, number, number, number]> {
  // Генерировать count свечей, где последняя — now - intervalMs
  // Цены: random walk от базовой цены (SBER~250, GAZP~180)
  // Volume: random 1000-50000
  // Timestamp в MSK формате (MOEX ISS отдаёт MSK)
}

/**
 * Мокирует endpoint MOEX ISS candles для Playwright.
 * Перехватывает запросы к /api/moex/candles/* или /iss/engines/stock/markets/shares/securities/*/candles
 */
export async function mockMoexCandles(
  page: Page,
  ticker: string,
  timeframe: string,
  freshness: 'fresh' | 'stale' = 'fresh',
): Promise<void> {
  const candles = generateFreshCandles(ticker, timeframe as any);
  
  // Перехват: page.route для URL-паттерна candles API
  await page.route(`**/api/v1/market-data/candles*ticker=${ticker}*`, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        candles: candles.map(c => ({
          timestamp: c[0],
          open: String(c[1]),  // Gotcha 1: Decimal → str
          high: String(c[2]),
          low: String(c[3]),
          close: String(c[4]),
          volume: c[5],
        })),
      }),
    });
  });
}
```

Применить в `s5-chart-timeframes.spec.ts`:
1. Заменить `test.skip("S5R-CHART-FRESHNESS")` на `await mockMoexCandles(page, ticker, tf)`
2. Тесты должны проходить в **любое** время суток

## Задача 6.3: S5R-E2E-MOCKS-EXPANSION — миграция ~40 тестов

### 6.3a: Аудит всех E2E файлов

Для каждого E2E spec-файла:
```bash
ls e2e/*.spec.ts
```
Определи, какие используют `injectFakeAuth` (уже на моках) и какие — нет (требуют login).

### 6.3b: Расширить api_mocks.ts

Добавь хелперы по мере необходимости:
- `mockBacktests(page, data)` — для бэктест-тестов
- `mockTradingSessions(page, data)` — для trading-тестов
- `mockTradingTrades(page, data)` — для trades-тестов
- `mockBondCoupons(page, data)` — для bond-тестов
- `mockTaxReport(page, data)` — для tax-тестов
- `mockCircuitBreakerState(page, data)` — для CB-тестов
- `mockAIChat(page)` — для AI-тестов
- `mockNotifications(page, data)` — для notification-тестов (если DEV-4 добавит E2E)

### 6.3c: Применить моки

Для каждого spec-файла, который сейчас логинится через UI:
1. Заменить `await page.goto('/login'); await page.fill(...)` на `await injectFakeAuth(page)`
2. Добавить нужные `mock*()` в `beforeEach`
3. Убедиться, что тест проходит без `E2E_PASSWORD`

### 6.3d: Документация

Создай `e2e/README.md`:
```markdown
# E2E Tests

## Моки vs Integration тесты

### Smoke E2E (на моках, 24/7)
Тесты, использующие `injectFakeAuth` + `mock*` хелперы из `fixtures/api_mocks.ts`.
Не требуют backend, не зависят от времени суток.

### Integration E2E (с реальным backend)
Тесты, требующие `E2E_PASSWORD` и запущенный backend.
Помечены `test.describe('integration', ...)`.

## Паттерн добавления нового теста
1. В `beforeEach`: `await injectFakeAuth(page)`
2. Замокировать нужные API через `mock*(page, data)`
3. Использовать `data-testid` для элементов (Gotcha 9)
```

# Опциональные задачи

## Задача 6.4 (опциональная): Валидация cron-запуска

Если есть возможность — запустить `playwright-nightly.yml` через `workflow_dispatch` и проверить результат. Если нет доступа к GitHub Actions — SKIP + reason.

**DEV обязан вернуть PASS или SKIP + reason.**

# Тесты

Эта задача **сама является** тестовой инфраструктурой. Критерий:
- `npx playwright test s5-chart-timeframes.spec.ts` → 0 failures (моки ISS)
- `npx playwright test` **без** `E2E_PASSWORD` → минимум 90% passed (135+ из ~150)
- `grep -rn "S5R-CHART-FRESHNESS" e2e/` → пусто (skip удалён)

# ⚠️ Integration Verification Checklist

- [ ] `.github/workflows/playwright-nightly.yml` создан с cron + workflow_dispatch
- [ ] `e2e/fixtures/moex_iss_mock.ts` создан с `mockMoexCandles` + `generateFreshCandles`
- [ ] `grep -rn "S5R-CHART-FRESHNESS" e2e/` → **пусто**
- [ ] `npx playwright test s5-chart-timeframes.spec.ts` → 0 failures
- [ ] `e2e/fixtures/api_mocks.ts` расширен новыми хелперами (mockBacktests, mockTradingSessions, etc.)
- [ ] Минимум 35 из ~40 тестов переведены на `injectFakeAuth` + моки
- [ ] `e2e/README.md` создан
- [ ] `npx playwright test` без `E2E_PASSWORD` → 90%+ passed

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.
Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-6_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 6.1–6.3 реализованы
- [ ] Опциональная задача 6.4 — PASS или SKIP + reason
- [ ] `npx playwright test` → максимум passed, минимум failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-6_report.md`
- [ ] ISS моки работают 24/7 (не зависят от торговой сессии)
- [ ] Playwright nightly workflow создан с правильным cron
- [ ] E2E не требуют E2E_PASSWORD для smoke-прогона
