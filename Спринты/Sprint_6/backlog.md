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
- **S6-TINVEST-SDK-UPGRADE** (ниже) — апгрейд `tinkoff-investments` до актуального beta117+ с ревизией breaking changes
- **S6-TINVEST-STREAM-MULTIPLEX** (ниже) — полноценный persistent gRPC stream в `TInvestAdapter.subscribe_candles` с мультиплексированием подписок

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

---

### S6-TINVEST-SDK-UPGRADE — апгрейд tinkoff-investments до beta117+

**Тип:** Infra (обновление зависимостей)
**Приоритет:** 🟡 Важно (SDK текущей версии — baseline разработчика 0.2.0b59; в CI и на проде нужен публично доступный тег)
**Размер:** M (~3-5 часов)
**Контекст:** S5R closeout wave 3 #13, Gotcha 14 в `Develop/CLAUDE.md`

#### Откуда задача

В S5R closeout wave 3 DEV-1 починил `TInvestAdapter.subscribe_candles` (устранил `.candles` AttributeError). При попытке добавить установку SDK в CI оркестратор обнаружил:

- Локальный baseline разработчика — `tinkoff-investments 0.2.0b59`, установлен из квартин'еного PyPI в давние времена. Этого тега **нет** в GitHub `RussianInvestments/invest-python` (публичные теги начинаются с `0.2.0-beta64`).
- Попытки установить любой актуальный тег (`beta64`, `beta117`) в CI ломают на транзитивных зависимостях `tinkoff<0.2.0`, `deprecation`, `python-dateutil` — часть из них тоже квартин'ены.
- SDK beta117 имеет **breaking changes** по сравнению с beta59 (локальный) — часть протобуф-классов переименована или перемещена.

Wave 3 обошла проблему через stub `sys.modules` в тесте (Gotcha 14), но это **заплатка**, не решение. На проде backend использует реальный SDK, и текущий baseline beta59 недокументирован и непроизводим.

#### Что нужно сделать

1. **Инвентаризация использований.** `grep -rn "from tinkoff.invest import\|import tinkoff\." backend/app/` — найти все места, где код импортирует конкретные классы/модули SDK. Типичные кандидаты: `AsyncClient`, `InstrumentIdType`, `CandleInterval`, `OrderDirection`, `OrderType`, `CandleInstrument`, `MarketDataRequest`, `SubscribeCandlesRequest`, `SubscriptionAction`, `SubscriptionInterval`.

2. **Воспроизвести локально beta117.** Создать отдельный venv, `pip install "git+https://github.com/RussianInvestments/invest-python.git@0.2.0-beta117"` (**с** транзитивными deps, проверив что все доступны). Если упрётся в те же квартин'ены — зафиксировать какие именно и искать обход (форк в monorepo vendor/ директорию?).

3. **Проверить breaking changes.** Для каждого использования в `app/broker/tinvest/` запустить `python -c "from tinkoff.invest import <class>"` в venv beta117 и убедиться, что класс существует. Если нет — найти новое имя через release notes / `dir(tinkoff.invest)`.

4. **Адаптировать код.** Если класс переименован (`OrderDirection` → `OrderDirectionV2`, например) — обновить import. Если логика изменилась (`market_data_stream()` теперь принимает другой формат request) — переписать `subscribe_candles` и другие streaming-методы.

5. **Зафиксировать версию.** Добавить в `pyproject.toml`:
   ```toml
   dependencies = [
       ...
       "tinkoff-investments @ git+https://github.com/RussianInvestments/invest-python.git@0.2.0-beta117",
   ]
   ```
   Либо в `ci.yml` отдельным step'ом с явной версией.

6. **Удалить `sys.modules` stub** в `tests/unit/test_broker/test_tinvest_subscribe_candles.py` — после апгрейда SDK установлен в CI, stub больше не нужен. Gotcha 14 оставить как общее правило для **будущих** SDK.

7. **Регрессионное тестирование.** Локально запустить `pytest tests/unit/test_broker/` + `pytest tests/unit/test_trading/` + реальную paper-сессию через uvicorn, убедиться что работает в обе стороны: `/broker/accounts/{id}/portfolio` выдаёт данные, `subscribe_candles` не валится.

#### Критерии готовности

- [ ] SDK обновлён до актуального публичного тега (`0.2.0-beta117` или новее)
- [ ] Все использования `tinkoff.invest` в `backend/app/broker/tinvest/` и `backend/app/market_data/` работают с новой версией
- [ ] `pyproject.toml` фиксирует конкретную версию SDK
- [ ] CI pipeline устанавливает SDK автоматически (без `sys.modules` stub-ов)
- [ ] `sys.modules` stub удалён из `test_tinvest_subscribe_candles.py`
- [ ] Локальный прогон `pytest tests/unit/ tests/test_broker/ tests/test_trading/` — зелёный
- [ ] Регрессия `adapter.subscribe_candles` — 0 ошибок в логах backend за 30 секунд после старта

#### Подводные камни

- SDK тянет grpc-стабы из `.proto`-файлов — переименования полей в protobuf могут быть скрытыми (`subscription_action` → `action`, например).
- Enum'ы SubscriptionAction / SubscriptionInterval / OrderDirection / OrderType могут быть полностью заменены на новые версии с разными числовыми значениями — нужна проверка по сериализации.
- `AsyncClient` context manager API может измениться (`__aenter__` → фабричный метод, например).

---

### S6-TINVEST-STREAM-MULTIPLEX — полноценный persistent stream с мультиплексированием

**Тип:** Feature + Refactor (Backend)
**Приоритет:** 🟡 Важно (без него каждая подписка на свечи создаёт отдельное gRPC-соединение → rate-limit T-Invest → нестабильность)
**Размер:** L (~4-6 часов)
**Контекст:** S5R closeout wave 3 #13 + Gotcha 4 в `Develop/CLAUDE.md`

#### Откуда задача

В S5R closeout wave 3 DEV-1 починил `TInvestAdapter.subscribe_candles` от AttributeError, но **не реализовал** полное мультиплексирование подписок в одном gRPC-stream. Сейчас на каждую подписку (`subscribe_candles("SBER", "1m", ...)`, `subscribe_candles("GAZP", "1m", ...)`, etc.) создаётся **отдельное** `async with self._create_client() as client: async for response in client.market_data_stream.market_data_stream(...)` — отдельное соединение, отдельный request_iterator.

Это **антипаттерн**, явно запрещённый **Gotcha 4** в `Develop/CLAUDE.md`:

> Gotcha 4 — T-Invest gRPC streaming: persistent connection обязателен
> Правило: `TInvestAdapter.subscribe_candles()` использует `StreamManager` из `app/market_data/stream_manager.py`. `StreamManager` поддерживает **одно** MarketDataStream, мультиплексирует подписки по ключу (ticker, timeframe), делает auto-reconnect.

На проде это приведёт к **rate-limit** T-Invest (`429 Too Many Requests`) при первых же 5-10 торговых сессиях на разные тикеры.

#### Что нужно сделать

1. **Архитектура multiplexer.** В `TInvestAdapter` (или в новом классе `TInvestMarketDataStreamMultiplexer`):
   - **Одно** долгоживущее `MarketDataStream` соединение на весь процесс backend.
   - `asyncio.Queue` для incoming-запросов подписки/отписки (`{"action": "subscribe", "figi": "...", "interval": "..."}`).
   - Async request-iterator, который потребляет из queue и yield'ит `MarketDataRequest(subscribe_candles_request=SubscribeCandlesRequest(action=SUBSCRIBE, ...))` на каждое событие.
   - Маршрутизация ответов: один `MarketDataStream` отдаёт response'ы для **всех** подписок. Нужно router, который по `response.candle.figi` определяет, в какой callback его отдать.

2. **Register/unregister подписки.** Публичный API `TInvestAdapter.subscribe_candles(ticker, timeframe, callback)`:
   - Добавляет `(figi, callback)` в internal routing dict.
   - Шлёт `{"action": "subscribe", ...}` в queue.
   - Возвращает `subscription_id` (как сейчас).
   
   `unsubscribe(subscription_id)`:
   - Удаляет запись из routing dict.
   - Если это был последний listener для данного figi — шлёт `{"action": "unsubscribe", ...}` в queue.

3. **Auto-reconnect с exponential backoff.** При разрыве gRPC (stream exception) — переоткрыть соединение, переподписаться на все активные figi из routing dict. Backoff: 1s → 2s → 4s → 8s → max 30s.

4. **StreamManager интеграция.** `app/market_data/stream_manager.py` сейчас вызывает `adapter.subscribe_candles` — он должен продолжить работать без изменений. Новая архитектура внутри adapter'а, StreamManager сверху.

5. **Unit-тесты.** Покрыть:
   - 2 подписки на разные figi → 2 разных callback'а получают свои candles.
   - Отписка от одной из двух → вторая продолжает работать.
   - Разрыв соединения → auto-reconnect, подписки восстанавливаются.
   - Rate limit response от T-Invest → корректная обработка (retry с backoff).

6. **Регрессия:** прогнать весь `tests/unit/test_broker/` + реальная paper-сессия на 2-3 тикера одновременно.

#### Критерии готовности

- [ ] `TInvestAdapter.subscribe_candles` использует **один** `MarketDataStream` на весь adapter (не один на подписку)
- [ ] `grep -rn "market_data_stream(" backend/app/broker/tinvest/ | grep -v test` → **одно** место инстанциирования
- [ ] Unit-тесты покрывают мульти-подписку, отписку, reconnect
- [ ] Реальная paper-сессия на 2-3 тикера одновременно работает >10 минут без rate-limit
- [ ] `ruff` + `mypy` + `pytest` — зелёные

#### Зависимости

- **Идеально после** S6-TINVEST-SDK-UPGRADE — чтобы работать с актуальным API SDK.
- **Блокирует** полноценное использование real-trading в S6 (раздел 6.4 Recovery): без мультиплексирования real-сессии будут ломаться под load'ом.
