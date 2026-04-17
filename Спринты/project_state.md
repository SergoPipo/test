# Состояние проекта: Торговый терминал MOEX

> **Это главная точка входа для любой новой сессии Claude.**
> Прочитай этот файл первым, чтобы понять, где мы находимся.
>
> Последнее обновление: 2026-04-17 (Sprint 6 открыт, промпты DEV-0..7 + ARCH созданы)

---

## Текущий спринт: **S6 🔄 в процессе** (Уведомления + Recovery + Graceful Shutdown) + S5R-2 параллельно

## Прогресс по спринтам

| Спринт | Название | Статус | Ключевой результат | Отчёт |
|--------|----------|--------|-------------------|-------|
| S1 | Фундамент | ✅ завершён | Auth, дашборд, CI, 68 тестов | Sprint_1/sprint_report.md |
| S2 | Данные и графики | ✅ завершён | Брокер, графики, шифрование, 175 тестов | Sprint_2/sprint_report.md |
| S3 | Стратегии + редактор | ✅ завершён | Blockly, Sandbox, CSRF, 320 тестов | Sprint_3/sprint_report.md |
| S4 | AI + бэктестинг | ✅ завершён | AI chat, Backtest Engine, 577 тестов | Sprint_4/sprint_report.md |
| S5 | Торговля | ⚠️ завершён с замечаниями (весь долг устранён в S5R + closeout) | Trading Engine, Paper Trading, Circuit Breaker, Bond/Tax, 548 тестов + 23 E2E | Sprint_5/arch_review_s5.md |
| **S5 Review** | **Внеплановое ревью + 3 волны closeout + wave 4 (chart bug-fixes): стабилизация перед S6** | **✅ закрыт полностью** | **CI зелёный впервые с 2026-04-03 на всех 5 ветках + develop. Live Runtime Loop замкнут, реальные позиции T-Invest (source через FIGI), 109 Playwright passed (моки, работают 24/7 без seed), **15** Stack Gotchas, 2 бизнес-бага починены, schema drift устранён, tinvest stream API исправлен, iss_tail_fetch timezone, кнопка Запустить торговлю из бэктеста подключена. **Wave 4 (фазы 3.3–3.7, 2026-04-16):** T-Invest naive→aware (gotcha-15), client-side `candlesCache` + persist в localStorage, race-guard в `fetchCandles`/`fetchOlderCandles`, фикс D-мигания в ChartPage. Крупные треки (backend prefetch, live-агрегация 1m→D, sequential-index mode, 401 debug) вынесены в **Sprint_5_Review_2** (S5R-2). Вердикт ARCH: PASS WITH NOTES, блокеров нет.** | **Sprint_5_Review/arch_review_s5r.md** + **Sprint_5_Review/changelog.md** разделы closeout + фазы 3.3–3.7 |
| **Sprint_5_Review_2** | **Chart hardening — 5 треков патч-цикла** | **✅ закрыт (ARCH: ПРИНЯТ)** | **Трек 4:** 401 fix (cleanup+guard+gotcha-16). **Трек 5:** TF-aware upsertLiveCandle. **Трек 3:** sequential-index mode intraday. **Трек 1:** prefetch свечей при логине (warm cache). **Трек 2:** верификация агрегации 1m→D/1h/4h (12 тестов, багов нет). ARCH-ревью: 15 проверок, 14 OK, 1 minor. Тесты: 238 frontend + 623 backend = 861 total, 0 failures. | Sprint_5_Review_2/arch_review_s5r2.md |
| **S6** | **Уведомления** | **🔄 в процессе** | Telegram, Email, In-app, Recovery, Graceful Shutdown, SDK upgrade, Stream Multiplex, E2E infra + backlog задачи | Sprint_6/sprint_state.md |
| S7 | Should-фичи | ⬜ не начат | Версионирование, экспорт | Sprint_7/sprint_report.md |
| S8 | Стабилизация | ⬜ не начат | Coverage 80%, security audit | Sprint_8/sprint_report.md |

**Легенда:** ⬜ не начат · 🔄 в процессе · ✅ завершён · ⚠️ завершён с замечаниями

## Что делать дальше

```
ТЕКУЩЕЕ ДЕЙСТВИЕ: Sprint 6 — Уведомления + Recovery + Graceful Shutdown
  Волновая параллелизация: 4 волны, 8 DEV-агентов + ARCH.
  Промпты DEV-0..7 + ARCH созданы 2026-04-17.

  Волна 0 (blocker): DEV-0 — S6-STRATEGY-UNDERSCORE-NAMES
  Волна 1 (3 параллельных):
    DEV-1 — In-app WS + Recovery + Graceful Shutdown
    DEV-2 — Telegram Bot + Email
    DEV-3 — T-Invest SDK upgrade (beta59 → beta117+)
  Волна 2 (3 параллельных):
    DEV-4 — Frontend Notification Center
    DEV-5 — T-Invest Stream Multiplex (persistent gRPC)
    DEV-6 — E2E infra (playwright-nightly, ISS моки, mocks expansion)
  Волна 3 (2 параллельных):
    DEV-7 — E2E S6 + Security
    ARCH  — финальное ревью + docs update

S5R-2 ЗАКРЫТ ✅ (2026-04-17): все 5 треков, ARCH ПРИНЯТ.
  Рекомендации для S6: channelTf split валидация, localStorage-prefetch, aggregator warm-up.

ФАЙЛ СОСТОЯНИЯ: Sprint_6/sprint_state.md
ФАЙЛ ПОРЯДКА: Sprint_6/execution_order.md
ФАЙЛ BACKLOG: Sprint_6/backlog.md
СЛЕДУЮЩЕЕ ДЕЙСТВИЕ: запуск волны 0 (DEV-0 багфикс _underscore)
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
