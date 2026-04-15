# Sprint 6 — Backlog (предварительный, накопленный до открытия)

> Этот файл создан **до формального открытия Sprint 6** — в нём накапливаются задачи, известные заранее:
> - Изначальный scope S6 из `development_plan.md` (Уведомления, Recovery, Graceful Shutdown и т.д.)
> - Задачи, перенесённые из `Sprint_5_Review/arch_review_s5r.md` секция 8
>
> При открытии Sprint 6 оркестратор превратит эти карточки в полноценные `prompt_DEV-*.md` по `prompt_template.md`, разнесёт по DEV-агентам, заполнит Cross-DEV contracts в `execution_order.md`.
>
> **ВАЖНО для оркестратора при построении промптов S6:** обязательно прочитай секции «Перенесённые из S5R» ниже — ARCH специально выделил эти задачи с контекстом, причиной переноса и критериями готовности.

---

## Перенесённые из S5R (ARCH-ревью 2026-04-14)

Эти две задачи ARCH признал «не блокерами S5R, подходящими для S6». Заказчик согласился перенести, при условии, что они будут чётко зафиксированы в S6 backlog до открытия спринта.

### S6-PLAYWRIGHT-NIGHTLY — отдельный cron-workflow для E2E в рабочие часы MSK

**Тип:** Infra (CI/CD)
**Приоритет:** 🟡 Важно (без него Playwright не гоняется автоматически)
**Размер:** S (~1 час написания + 1-2 дня ожидания реального cron-запуска для валидации)
**Контекст:** arch_review_s5r.md секция 5 ответ 2 + секция 8

#### Откуда задача

В S5R.4 DEV-1 волна 2 привёл Playwright baseline к **101 passed / 0 failed / 8 skipped**, но **не добавил** Playwright job в основной CI workflow (`.github/workflows/ci.yml`). Причина — Gotcha 10 в `Develop/CLAUDE.md`:

> E2E-тесты с живыми данными MOEX ISS flaky вне торговой сессии (выходные, ночью, праздники). В PR runner'ах (которые работают 24/7) это сделает тесты нестабильными и будет блокировать merge без вины кода.

ARCH в арх-ревью принял это решение как **PASS WITH NOTES**, но предложил компромисс: завести **отдельный** workflow `playwright-nightly.yml` с cron-расписанием **только в рабочие часы MSK** (Mon-Fri, 10:00-18:00 MSK = 07:00-15:00 UTC), который гоняет Playwright тесты когда MOEX реально работает.

#### Что нужно сделать

1. **Создать `.github/workflows/playwright-nightly.yml`:**
   ```yaml
   name: Playwright (nightly, work hours only)
   on:
     schedule:
       - cron: "0 7,9,11,13 * * 1-5"  # 10:00, 12:00, 14:00, 16:00 MSK, пн-пт
     workflow_dispatch:  # ручной запуск для отладки

   jobs:
     e2e:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-node@v4
           with: { node-version: '20' }
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
   ```
2. **Создать GitHub secret** `TEST_USER_PASSWORD` в настройках репо (пароль `sergopipo` — не хардкодить в yml).
3. **Добавить skip-guard в тесты**, которые зависят от живых данных MOEX — они должны сами определять «сейчас рабочие часы?» и skip-аться вне них (это Gotcha 10 в действии, уже описана).
4. **Валидация:** запустить вручную через `workflow_dispatch` в рабочие часы → убедиться, что тесты зелёные. Потом дождаться одного реального cron-запуска.

#### Критерии готовности

- [ ] Файл `playwright-nightly.yml` создан, схема cron работает
- [ ] GitHub secret `TEST_USER_PASSWORD` настроен
- [ ] Ручной workflow_dispatch-запуск в рабочие часы — зелёный
- [ ] Один реальный cron-запуск (дождаться 10:00 или 12:00 MSK следующего рабочего дня) — зелёный или скипает с причиной
- [ ] В `Develop/CLAUDE.md` добавлен комментарий к Gotcha 10 с ссылкой на этот workflow

#### Подводные камни

- `workflow_dispatch` триггер обязателен — иначе не потестить без ожидания cron.
- Secret `TEST_USER_PASSWORD` — **не** в коде, **не** в yml, только в settings репо.
- Playwright в PR — **не добавлять**. Эта задача именно про отдельный nightly workflow.

---

### S6-E2E-CHART-MOCK-ISS — моки MOEX ISS API для тестов актуальности свечей

**Тип:** Feature (E2E infrastructure)
**Приоритет:** 🟡 Важно (без него 3 E2E теста остаются skipped)
**Размер:** M–L (~3-6 часов)
**Контекст:** arch_review_s5r.md секция 5 ответ 4 + `Sprint_5_Review/backlog.md` secция Closeout

#### Откуда задача

В S5R.4 DEV-1 волна 2 обнаружил, что 3 Playwright теста падают вне торговой сессии:

- `s5-chart-timeframes.spec.ts` «1m/5m/15m candle freshness» — проверяют, что последняя свеча получена < X минут назад. В выходные MOEX ISS возвращает устаревшие данные — тесты падают.

DEV-1 сделал `test.skip("S5R-CHART-FRESHNESS")` с TODO-тикетом. Теперь нужно либо:
- **Вариант А (рекомендуемый ARCH):** написать полноценные моки MOEX ISS candles endpoint в e2e-фикстурах. Тесты перестают зависеть от живого API, могут гоняться 24/7.
- **Вариант Б (альтернатива):** просто добавить guard в сам тест, который сам skip-ает вне торговой сессии (по UTC-проверке). Тесты продолжают работать только в рабочие часы, но хотя бы явно.

ARCH рекомендует **вариант А** — моки. Это серьёзный инфраструктурный кусок (нужно точно воспроизводить формат ответа ISS, учитывать временные зоны, cycle poller backend-а).

#### Что нужно сделать

**Frontend E2E:**
1. Создать `frontend/e2e/fixtures/moex_iss_mock.ts` — helper функция, которая через `page.route('**/api/moex/candles/**', ...)` подменяет ответ MOEX ISS candles API. Формат ответа должен совпадать с реальным (см. `backend/app/broker/moex_iss/parser.py` для формата).
2. Генератор моков: функция `generateFreshCandles(ticker, tf, now)` — возвращает N синтетических свечей, где последняя — с timestamp в пределах «свежести» теста (т.е. `now - 1min` для 1m TF).
3. Применить моки в 3 тестах: `s5-chart-timeframes.spec.ts` (1m, 5m, 15m).
4. Снять `test.skip("S5R-CHART-FRESHNESS")`.

**Backend (возможно):**
- Проверить, что backend-endpoint `GET /api/moex/candles/...` не делает дополнительную валидацию timestamp'ов, которая сломается от синтетических свечей из моков.

#### Критерии готовности

- [ ] `e2e/fixtures/moex_iss_mock.ts` создан с helper'ом `mockMoexCandles(page, ticker, tf, freshness)`
- [ ] 3 теста в `s5-chart-timeframes.spec.ts` переписаны на моки и зелёные
- [ ] `grep -rn "S5R-CHART-FRESHNESS" frontend/e2e/` → пусто
- [ ] Тесты проходят в **любое** время суток, включая выходные (запустить в выходные для подтверждения)
- [ ] `npx playwright test s5-chart-timeframes.spec.ts` → 0 failures

#### Подводные камни

- Формат ответа MOEX ISS API — **строгий** (массив `[timestamp, open, high, low, close, volume, value]`), любое отклонение ломает backend-парсер.
- Временные зоны: MOEX ISS отдаёт timestamps в MSK, backend работает в UTC. Моки должны учитывать конверсию.
- `cycle poller` backend-а (из `StreamManager`) может перезаписать замоканные данные своим реальным polling'ом. Нужно проверить, что `page.route` перехватывает **все** запросы, включая периодические.

---

## Изначальный scope Sprint 6 (из development_plan.md)

Эти задачи планировались в Sprint 6 ещё до S5R. После S5R часть из них **уже реализована** в рамках closeout-фазы ревью — они помечены как скипнутые или сужают объём.

| # | Задача | Статус после S5R |
|---|--------|------------------|
| 6.0 | Live Runtime Loop | ✅ **Реализовано в S5R.2** (DEV-2) — скипнуто из S6 |
| 6.1 | Telegram уведомления | ⬜ TODO (полный scope) |
| 6.2 | Email уведомления | ⬜ TODO (полный scope) |
| 6.3 | In-app WebSocket уведомления | ⬜ TODO — **EventBus канал `trades:{session_id}` с 6 событиями готов из S5R.2**, остаётся только WebSocket bridge |
| 6.4 | Recovery (восстановление сессий после рестарта) | ⬜ TODO — **`SessionRuntime.restore_all` готов из S5R.2**, дополнить real-side `StreamManager.subscribe` и сверкой позиций с брокером |
| 6.5 | Graceful Shutdown | ⬜ TODO — **`SessionRuntime.shutdown()` готов из S5R.2**, добавить сохранение pending событий |
| 6.6 | Trading Panel UX (доработки) | ⬜ TODO |
| 6.7 | ... | (см. development_plan.md для полного списка) |
| 6.9 | Реальные позиции T-Invest | ✅ **Реализовано в S5R.3** (DEV-3) — скипнуто из S6 |
| 6.10 | E2E тесты S6 | ⬜ TODO |
| 6.11 | **S6-MODEL-FIGI** | ✅ **Реализовано в S5R.9 closeout** (DEV-1 closeout) — можно удалить из S6 |

---

## Новые задачи, созданные в S5R и перенесённые в S6

- **S6-PLAYWRIGHT-NIGHTLY** (выше) — отдельный cron-workflow для E2E
- **S6-E2E-CHART-MOCK-ISS** (выше) — моки MOEX ISS для тестов свечей
- **S5R-E2E-MOCKS-EXPANSION** (ниже) — расширение `api_mocks.ts` на оставшиеся ~40 login-зависимых E2E тестов

---

### S5R-E2E-MOCKS-EXPANSION — расширить api_mocks.ts на оставшиеся E2E

**Тип:** Fix (E2E infrastructure)
**Приоритет:** 🟡 Важно (без него ~40 тестов остаются зависимыми от `E2E_PASSWORD`)
**Размер:** L (~6-10 часов)
**Контекст:** Sprint_5_Review closeout wave 2 задача #10 + DEV-1 отчёт wave 2 секция «Проблемы / TODO»

#### Откуда задача

В S5R closeout wave 2 задача #10 DEV-1 создал общую фикстуру `frontend/e2e/fixtures/api_mocks.ts` с хелперами `injectFakeAuth`, `mockAuthEndpoints`, `mockBrokerAccounts/Balances/Positions/Operations`, `mockStrategies`, `mockInstrumentLogos`, `mockDefaultEmptyApis`. Применил её к 5 тестам в `s5-account.spec.ts` и `s5-ticker-logos.spec.ts` — они теперь работают **без** `E2E_PASSWORD` и **без** seed-данных user `sergopipo`, прогоняются 24/7.

Но в репо ещё **~40 других E2E тестов** (всё, что ниже `s5-paper-trading.spec.ts`, `s5-favorites.spec.ts`, `s5-account.spec.ts`, `s5-ticker-logos.spec.ts`, `dashboard.spec.ts`, `strategy.spec.ts`, `s5-chart-timeframes.spec.ts`, `s5-pnl-card.spec.ts`, `s5-strategy-status.spec.ts`, `s5-trading-create.spec.ts`, `s5-trading-status.spec.ts`, `s5-bond-trading.spec.ts`, `s5-tax-report.spec.ts`, `s5-circuit-breaker.spec.ts`, `s5-broker-settings.spec.ts`) — **продолжают** требовать `E2E_PASSWORD` и реальный login через UI.

Это **технический долг** S5R closeout: фикстура есть, паттерн отработан, но применение ограничено двумя файлами.

#### Что нужно сделать

1. **Аудит каждого E2E файла** — для каждого из ~40 тестов определить:
   - Какие API-endpoints вызываются (через grep по стораджам / API-клиентам)
   - Какие данные нужны для прохождения (минимальный набор моков)
   - Зависит ли тест от состояния БД (например, существование стратегии, аккаунта, бэктеста, открытой сессии)
2. **Расширить `api_mocks.ts`** новыми хелперами по мере необходимости (например, `mockBacktests`, `mockTradingSessions`, `mockBondCoupons`, `mockTaxReport`, `mockCircuitBreakerState`).
3. **Применить хелперы** к каждому тесту в `beforeEach`. Заменить login через UI на `injectFakeAuth(page)`.
4. **Снять зависимость от `E2E_PASSWORD`** — после миграции всех тестов поле `E2E_PASSWORD` в `.env.local` и в фикстурах должно быть **полностью удалено**.
5. **Обновить `playwright.config.ts`** — убрать webServer-команду, которая запускает реальный backend (если применимо). Тесты должны работать только с моками.

**Альтернативный подход (если полная миграция слишком дорогая):**
- Разделить тесты на 2 категории: **smoke E2E** (быстрые, на моках, гоняются в `playwright-nightly.yml`) и **integration E2E** (медленные, требуют реального backend + production data, гоняются вручную перед релизом).
- Промигрировать smoke-тесты на моки, integration оставить с `E2E_PASSWORD`. Это сокращает scope в 2-3 раза.

#### Критерии готовности

- [ ] **Минимум 90% E2E тестов** (35+ из ~40) переведены на `api_mocks.ts`
- [ ] `npx playwright test --project=chromium` **без** `E2E_PASSWORD` env проходит зелёным (102 + 35 ≈ 137 passed)
- [ ] Пароль `sergopipo` НЕ требуется для прогона smoke E2E
- [ ] Документация в `frontend/e2e/README.md` (создать, если нет) с описанием паттерна `injectFakeAuth + mockX(page, ...)`
- [ ] Для оставшихся integration-тестов (если применяется альтернативный подход) — explicit маркер в имени теста или в `test.describe` ярлыке

#### Зависимости и подводные камни

- **Gotcha 1** (Decimal → str): моки положений/операций/балансов должны строго возвращать строки, не числа. Hint: `JSON.stringify` сам не гарантирует это, надо явно указывать как строки в фикстурах.
- **Gotcha 9** (Playwright strict mode): в новых моках использовать `data-testid`, не `getByRole({name})`.
- **Gotcha 10** (E2E vs MOEX live data): если тест проверяет «свежесть» свечей, он по-прежнему должен использовать моки `mockMoexCandles` (см. `S6-E2E-CHART-MOCK-ISS` выше) или skip-аться вне торговой сессии.
- **Gotcha 12 / 13** (Alembic schema drift): после `0896e228f3ed_schema_drift_sanitizer` не должно быть проблем с fresh БД в e2e webServer, но если webServer вообще убирается — тогда не релевантно.
- Если во время аудита обнаруживаются E2E тесты, которые проверяют **реальные** реакции backend (например, реальное выставление ордера в T-Invest sandbox) — **не мигрируй их на моки**, оставь как integration. Цель — smoke-тесты на моках, не «всё подряд на моках».

---

## Для оркестратора: чек-лист при открытии Sprint 6

- [ ] Прочитать этот файл + `Sprint_5_Review/arch_review_s5r.md` секция 8 (рекомендации для S6)
- [ ] Создать `Sprint_6/execution_order.md` с Cross-DEV contracts (сверять контракты против **существующих моделей**, не только «желаемого» — ретро S5R.5)
- [ ] Создать `Sprint_6/preflight_checklist.md` — с **реальными** запусками baseline линтеров/тестов (ретро S5R.5)
- [ ] Создать `prompt_DEV-*.md` по `Спринты/prompt_template.md` (уже обновлён после S5R.5 с новыми секциями «Опциональные задачи» и «Skip-тикеты в тестах»)
- [ ] Для `S6-PLAYWRIGHT-NIGHTLY`: явно пометить как **опциональная** в промпте, DEV должен вернуть PASS или SKIP + reason
- [ ] Для `S6-E2E-CHART-MOCK-ISS`: явно выделить как отдельную подзадачу, не группировать с другими E2E
- [ ] Удалить задачи 6.0, 6.9, 6.11 из scope S6 (они закрыты в S5R/S5R closeout)
- [ ] Проверить, что новые DEV-агенты сохраняют отчёты в `Sprint_6/reports/DEV-X_report.md` (ретро S5R.5)
