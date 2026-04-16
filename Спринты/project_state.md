# Состояние проекта: Торговый терминал MOEX

> **Это главная точка входа для любой новой сессии Claude.**
> Прочитай этот файл первым, чтобы понять, где мы находимся.
>
> Последнее обновление: 2026-04-16 (после закрытия Sprint_5_Review wave 4: фазы 3.3–3.7 — chart bug-fixes)

---

## Текущий спринт: S5 ✅ + **Sprint_5_Review ✅ закрыт полностью (фазы 1-2 + closeout 7-14 + wave 4: фазы 3.3–3.7)** → **S5R-2 как преемник chart-hardening + S6 готов к старту**

## Прогресс по спринтам

| Спринт | Название | Статус | Ключевой результат | Отчёт |
|--------|----------|--------|-------------------|-------|
| S1 | Фундамент | ✅ завершён | Auth, дашборд, CI, 68 тестов | Sprint_1/sprint_report.md |
| S2 | Данные и графики | ✅ завершён | Брокер, графики, шифрование, 175 тестов | Sprint_2/sprint_report.md |
| S3 | Стратегии + редактор | ✅ завершён | Blockly, Sandbox, CSRF, 320 тестов | Sprint_3/sprint_report.md |
| S4 | AI + бэктестинг | ✅ завершён | AI chat, Backtest Engine, 577 тестов | Sprint_4/sprint_report.md |
| S5 | Торговля | ⚠️ завершён с замечаниями (весь долг устранён в S5R + closeout) | Trading Engine, Paper Trading, Circuit Breaker, Bond/Tax, 548 тестов + 23 E2E | Sprint_5/arch_review_s5.md |
| **S5 Review** | **Внеплановое ревью + 3 волны closeout + wave 4 (chart bug-fixes): стабилизация перед S6** | **✅ закрыт полностью** | **CI зелёный впервые с 2026-04-03 на всех 5 ветках + develop. Live Runtime Loop замкнут, реальные позиции T-Invest (source через FIGI), 109 Playwright passed (моки, работают 24/7 без seed), **15** Stack Gotchas, 2 бизнес-бага починены, schema drift устранён, tinvest stream API исправлен, iss_tail_fetch timezone, кнопка Запустить торговлю из бэктеста подключена. **Wave 4 (фазы 3.3–3.7, 2026-04-16):** T-Invest naive→aware (gotcha-15), client-side `candlesCache` + persist в localStorage, race-guard в `fetchCandles`/`fetchOlderCandles`, фикс D-мигания в ChartPage. Крупные треки (backend prefetch, live-агрегация 1m→D, sequential-index mode, 401 debug) вынесены в **Sprint_5_Review_2** (S5R-2). Вердикт ARCH: PASS WITH NOTES, блокеров нет.** | **Sprint_5_Review/arch_review_s5r.md** + **Sprint_5_Review/changelog.md** разделы closeout + фазы 3.3–3.7 |
| **Sprint_5_Review_2** | **Chart hardening — отдельный патч-цикл после S5R wave 4** | ⬜ не начат | Backend prefetch свечей при логине (идея пользователя) · live-агрегация 1m→D/1h/4h · sequential-index mode intraday · 401-debug · **TF-aware `upsertLiveCandle`** (фикс остаточного Daily-мигания — 3.7 закрыл часть окна гонки, но singleton WebSocket может доставить тик в микро-интервал между store-update и unsubscribe). Каждый трек — в отдельной Claude-сессии для экономии контекста. | Sprint_5_Review_2/ (создаётся в следующей сессии) |
| S6 | Уведомления | ⬜ готов к старту | Telegram, Email, In-app, Recovery, Graceful Shutdown + 3 backlog задачи (см. ниже) | Sprint_6/sprint_report.md |
| S7 | Should-фичи | ⬜ не начат | Версионирование, экспорт | Sprint_7/sprint_report.md |
| S8 | Стабилизация | ⬜ не начат | Coverage 80%, security audit | Sprint_8/sprint_report.md |

**Легенда:** ⬜ не начат · 🔄 в процессе · ✅ завершён · ⚠️ завершён с замечаниями

## Что делать дальше

```
ТЕКУЩЕЕ ДЕЙСТВИЕ: Sprint 6 — Уведомления + 3 задачи backlog из S5R closeout
  → 6.0 — закрыто в S5R.2 (Live Runtime Loop замкнут)
  → 6.3 — In-app уведомления (EventBus trades:{session_id} с 6 событиями готов)
  → 6.4 — Recovery (SessionRuntime.restore_all готов, добавить real-side
            StreamManager.subscribe + сверка позиций с брокером)
  → 6.5 — Graceful Shutdown (SessionRuntime.shutdown готов, добавить
            сохранение pending событий)
  → 6.6 — Telegram/Email/In-App интеграции
  → 6.9 — закрыто в S5R.3 (реальные позиции T-Invest)
  → 6.11 — закрыто в S5R closeout #9 (FIGI в LiveTrade + source через FIGI)

БЭКЛОГ ИЗ S5R closeout (см. Sprint_6/backlog.md):
  → S6-PLAYWRIGHT-NIGHTLY — cron-workflow для E2E в рабочие часы MSK
  → S6-E2E-CHART-MOCK-ISS — моки MOEX ISS для 3 тестов свежести свечей
  → S5R-E2E-MOCKS-EXPANSION — расширить api_mocks.ts на ~40 login-зависимых E2E
  → S6-TINVEST-SDK-UPGRADE — апгрейд tinkoff-investments до beta117+ (wave 3)
  → S6-TINVEST-STREAM-MULTIPLEX — persistent gRPC stream с multiplex (wave 3)

ПАРАЛЛЕЛЬНО (chart-hardening, независимо от S6):
  → S5R-2 Трек 1 — backend prefetch свечей для активных торговых сессий при логине
  → S5R-2 Трек 2 — backend live-агрегация 1m→D/1h/4h (Daily/1h не растут в реальном времени)
  → S5R-2 Трек 3 — sequential-index mode для intraday (визуальные «дыры» нерабочих часов)
  → S5R-2 Трек 4 — 401 Unauthorized после релогина (диагностика + фикс)
  → S5R-2 Трек 5 — TF-aware upsertLiveCandle (остаточное Daily-мигание после 3.7)

ПРЕДВАРИТЕЛЬНО: Sprint_6_Review после S6 (обновить ФТ/ТЗ по новому объёму S6)

ФАЙЛ СОСТОЯНИЯ: Sprint_6/sprint_state.md (когда S6 откроется)
ФАЙЛ BACKLOG S6: Sprint_6/backlog.md (создан 2026-04-14, дополнен 2026-04-15)
ПОСЛЕДНЕЕ РЕВЬЮ: Sprint_5_Review/arch_review_s5r.md + closeout + wave 4 (фазы 3.3–3.7) в changelog.md
СЛЕДУЮЩИЙ ПАТЧ-ЦИКЛ: Sprint_5_Review_2/ (будет создан в отдельной сессии)
```

## Ключевые решения (кросс-спринтовые)

_Решения, влияющие на несколько спринтов:_

| # | Дата | Решение | Влияет на | Принято кем |
|---|------|---------|-----------|-------------|
| 1 | 2026-03-24 | Sidebar сворачиваемый 240→60px | S1-S8 | Заказчик |
| 2 | 2026-03-24 | Footer с динамическим статус-баром 32px | S1-S2 | Заказчик |
| 3 | 2026-03-24 | Таблица с раскрываемыми строками (Вариант Б) | S1-S3 | Заказчик |
| 4 | 2026-03-24 | Тикеры с цветными иконками | S1 | Заказчик |
| 5 | 2026-03-27 | Бэктест нельзя запустить если: код устарел (блоки ≠ код) ИЛИ код содержит ошибки. Кнопка «Запустить бэктест» disabled + tooltip с причиной | S4-S5 | Заказчик |

## Технический долг

_Накапливается по мере продвижения, берётся из sprint_report.md:_

| # | Спринт | Описание | Приоритет | Статус |
|---|--------|----------|-----------|--------|
| 1 | S1 | Footer со статическими данными | Low | Отложено (не критично) |
| 2 | S4 | 30+ E2E тестов S4 падают | ~~High~~ | ✅ **Закрыт S5R.4** (DEV-1 волна 2, 102 passed / 0 failed после closeout) |
| 3 | S5 | Реальные позиции/операции T-Invest | ~~Medium~~ | ✅ **Закрыт S5R.3** + S5R closeout #9 (FIGI source-правило вместо ticker) |
| 4 | S5 | Live Runtime Loop не замкнут | ~~High~~ | ✅ **Закрыт S5R.2** (DEV-2, `runtime.py:374` — единственная production-точка `process_candle`) |
| 5 | S1-S5 | CI красный 11+ дней | ~~High~~ | ✅ **Закрыт S5R.1** (DEV-1 волна 1+1b, зелёный CI, 13 Stack Gotchas) |
| 6 | S5R closeout | Schema drift в БД (forward model drift) | ~~Medium~~ | ✅ **Закрыт S5R closeout #11** (миграция `0896e228f3ed_schema_drift_sanitizer`) |
| 7 | S5R closeout | E2E зависимость от seed user `sergopipo` | ~~Medium~~ | ✅ **Частично закрыт S5R closeout #10** (5 тестов на моках, остальные ~40 — `S5R-E2E-MOCKS-EXPANSION` в S6) |
| 8 | S5R closeout wave 3 | BacktestResultsPage: кнопка «Запустить торговлю» — заглушка без onClick | ~~Medium~~ | ✅ **Закрыт S5R closeout #12** (подключён LaunchSessionModal с предзаполнением из бэктеста, CSV/PDF → disabled + tooltip про Sprint 7) |
| 9 | S5R closeout wave 3 | tinvest_stream бесконечный reconnect (`'MarketDataStreamService' object has no attribute 'candles'`) | ~~High~~ | ✅ **Закрыт S5R closeout #13** (правильный API `market_data_stream(request_iterator)` через SubscribeCandlesRequest, Gotcha 4 соблюдён) |
| 10 | S5R closeout wave 3 | iss_tail_fetch offset-naive vs offset-aware compare | ~~Low~~ | ✅ **Закрыт S5R closeout #14** (нормализация timestamps ISS к naive UTC) |

**Текущий High-долг: 0.** Все блокеры, выявленные до S5R и в ходе 3 волн closeout, закрыты полностью.

## Перенесённые задачи

_Все 4 перенесённые задачи из S4/S5 закрыты в Sprint_5_Review 2026-04-14:_

| # | Из спринта | Задача | Перенесена в | Статус |
|---|------------|--------|-------------|--------|
| 1 | S4 (техдолг #2) | E2E S4 fix | Sprint_5_Review | ✅ закрыта (S5R.4) |
| 2 | S5 (техдолг #3) | Реальные позиции T-Invest | Sprint_5_Review | ✅ закрыта (S5R.3) |
| 3 | S5 (техдолг #4) | Live Runtime Loop | Sprint_5_Review | ✅ закрыта (S5R.2) |
| 4 | — (новый 14.04) | CI cleanup | Sprint_5_Review | ✅ закрыта (S5R.1) |

## Промежуточные ревью

| Ревью | После спринтов | Milestone | Статус | Отчёт |
|-------|---------------|-----------|--------|-------|
| Sprint_2_Review | S1 + S2 | M1: Каркас | ✅ завершён | Sprint_2_Review/backlog.md |
| Sprint_4_Review | S3 + S4 | M2: Бэктест | ✅ завершён | Sprint_4_Review/backlog.md |
| **Sprint_5_Review** | S5 (внеплановое) | — (стабилизация M3) | **✅ завершён (PASS WITH NOTES)** | **Sprint_5_Review/arch_review_s5r.md** |
| Sprint_6_Review | S5 + S6 | M3: Торговля | ⬜ не начат | Sprint_6_Review/backlog.md |
| Sprint_8_Review | S7 + S8 | M4: Production | ⬜ не начат | Sprint_8_Review/backlog.md |

## Milestones

| Milestone | Спринт | Статус | Критерии |
|-----------|--------|--------|----------|
| M1: Каркас | S1 | ✅ | Auth, дашборд, CI, 68 тестов |
| M2: Бэктест | S4 | ✅ | Стратегия → бэктест → результаты. Ревью: 21/28 задач исправлено, 7 отложено |
| M3: Paper Trading | S5 | ✅ | Paper Trading + Circuit Breaker + Bond НКД + Tax FIFO + 23 E2E. ARCH: PASS |
| M4: Production-ready | S8 | ⬜ | Coverage 80%, security, performance |

---

## Ссылки

| Документ | Путь |
|----------|------|
| Функциональные требования | Документация по проекту/functional_requirements.md |
| Техническое задание | Документация по проекту/technical_specification.md |
| План разработки | Документация по проекту/development_plan.md |
| Контекст для агентов | Develop/CLAUDE.md |
| Текущий спринт (детали) | Sprint_N/sprint_state.md |

---

## Как продолжить работу (инструкция для новой сессии)

1. Прочитай **этот файл** — пойми, на каком мы спринте
2. Перейди в папку текущего спринта → прочитай **sprint_state.md** — пойми, на каком мы шаге
3. Если нужен порядок работы → прочитай **execution_order.md**
4. Если нужен контекст проекта → прочитай **Develop/CLAUDE.md**
5. Выполни следующее действие из sprint_state.md
