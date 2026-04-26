# Состояние проекта: Торговый терминал MOEX

> **Это главная точка входа для любой новой сессии Claude.**
> Прочитай этот файл первым, чтобы понять, где мы находимся.
>
> Последнее обновление: 2026-04-26 (Sprint 7 — ✅ ЗАВЕРШЁН, ARCH 7.R PASS WITH NOTES; готов к старту S8 — feature freeze + стабилизация)

---

## Текущий спринт: **Sprint 7 — ✅ ЗАВЕРШЁН** (PASS WITH NOTES, 2026-04-26). M3 Phase 1 feature-complete. Готов к S8.

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
| **S6** | **Уведомления + Security** | **✅ завершён** | Telegram, Email, In-app, Recovery, Graceful Shutdown, SDK upgrade (beta117), Stream Multiplex, E2E infra, Security tests. 685 backend + 250 frontend + 10 E2E S6 = **945 тестов**. Доп. работы сессий 22-24.04: карточки сессий (Decimal, unrealized P&L), CB fixes (commit, trading hours, downtime), маркеры сделок на графике, правила плагинов в CLAUDE.md, Playwright автологин. | Sprint_6/arch_review_s6.md |
| **Sprint_6_Review** | **Промежуточное ревью M3: code review + UI-проверки + документация** | **✅ завершён (PASS, 2026-04-24)** | **Code review (8 разделов, 6 fixes).** **E2E регрессия:** 107→119 passed (0 failed). **3 code fixes** обнаружены только при E2E/визуальной верификации: AISettingsPage (`providers??[]` + `toLocaleString` guard), marketDataStore (`candles=[]` default). **Визуальная верификация S6:** 6 скриншотов, 5/6 OK. **EVENT_MAP фикс:** 8 publish-сайтов (runtime.py + engine.py) — 5 event_type теперь корректно подставляют `{strategy_name}`/`{ticker}`/`{direction}`/`{volume}`/`{pnl}`. **Документация:** ФТ/ТЗ/development_plan актуализированы за S5+S6. Итого: **11 FIXED + 1 FP + 3 перенесены в S7** (NS singleton, 5 event_type, inline-кнопки Telegram). **Milestone M3 достигнут.** | Sprint_6_Review/code_review.md, backlog.md |
| **S7** | **Should-фичи + переносы + AI-команды** | **✅ завершён (PASS WITH NOTES, 2026-04-26)** | **17 задач + 7.R закрыты.** Phase 1 feature-complete (M3 Phase 1 достигнут). Версионирование стратегий, Grid Search (multiprocessing.Pool, hard cap 1000), CSV/PDF экспорт (WeasyPrint), drawing tools (5 типов), дашборд-виджеты, first-run wizard (5 шагов), backup/restore (CLI + APScheduler), AI слэш-команды (5 команд), фоновые бэктесты (cap=3 + бейдж), WS-сессии (без polling), 5 новых event_type (MR.5), Telegram callbacks. **Тесты: backend 885/0, frontend 394/0, Playwright 136/0/3** (+17 vs S6 baseline 119). **Stack Gotchas созданы:** #19/#20/#21/#22. **DEFERRED-S8:** 11 карточек (1 medium-high, 5 medium, 5 low) — не блокеры. ФТ v2.4 / ТЗ v1.4 / development_plan обновлены. | Sprint_7/arch_review_s7.md |
| S8 | Стабилизация | ⬜ не начат | Coverage 80%, security audit | Sprint_8/sprint_report.md |

**Легенда:** ⬜ не начат · 🔄 в процессе · ✅ завершён · ⚠️ завершён с замечаниями

## Что делать дальше

```
ТЕКУЩЕЕ ДЕЙСТВИЕ: Sprint 7 — ✅ ЗАВЕРШЁН (PASS WITH NOTES, 2026-04-26)

  Финальный вердикт ARCH 7.R: PASS WITH NOTES
    - 17 задач + 7.R закрыты
    - M3 Phase 1 feature-complete
    - Тесты: backend 885/0, frontend 394/0, Playwright 136/0/3
    - MR.5 (5 event_type): ✅ FIXED — все publish-сайты в production
    - C1–C9 контракты: ✅ опубликованы и интегрированы
    - 11 карточек DEFERRED-S8 (не блокеры)
    - ФТ v2.4 / ТЗ v1.4 / development_plan обновлены
    - Stack Gotchas: #19/#20/#21/#22 созданы; INDEX.md v5
    - ui_checklist_s7.md создан UX W3

  Файлы 7.R:
    - Sprint_7/arch_review_s7.md (полный отчёт по 8 разделам)
    - Sprint_7/reports/ARCH_S7_review.md (краткая 8-секционная сводка)
    - Sprint_7/changelog.md (финальная запись «7.R PASS WITH NOTES»)
    - Sprint_7/sprint_state.md (✅ завершён)
    - Sprint_8_Review/backlog.md (+11 DEFERRED-S8 карточек)
    - Develop/stack_gotchas/gotcha-22-*.md + INDEX.md v5
    - Sprint_7/ux/backtest_overview_analytics.md (testid drift синхронизирован с кодом)

СЛЕДУЮЩЕЕ ДЕЙСТВИЕ: Запуск Sprint 8 — feature freeze + стабилизация (M4 Production-ready)

  S8 цели:
    1. Coverage ≥ 80% по каждому модулю (unit + integration)
    2. Security audit (crypto, sandbox escape, CSRF, headers, brute-force)
    3. Performance testing (дашборд < 2с, сигнал→ордер < 500мс, Telegram < 3с)
    4. Регрессия E2E (полный прогон + добавление spec'ов из S7R-E2E-*)
    5. Закрытие 11 DEFERRED-S8 карточек (приоритет: medium-high → medium → low)
    6. UX финальный юзабилити-тест + UX-баги
    7. Документация (README, deployment guide, итоговый changelog)
    8. 8.R финальное ARCH-ревью + sign-off

  Подготовка к S8 (до старта спринта):
    - Прочитать Sprint_8_Review/backlog.md (карточки S7 переносов)
    - Прочитать Sprint_7/arch_review_s7.md (контекст, что в каком состоянии)
    - Прочитать Документация по проекту/development_plan.md §«Спринт 8»

ВЕТКИ ПОСЛЕ S7 (НЕ закоммичено ARCH-ом, заказчик коммитит сам):
  - Корневой Test (docs/sprint-7-plan): обновления документации, ARCH 7.R отчёты, project_state, changelog, sprint_state, ui_checklist_s7, backlog S8
  - Develop/ (s7/sprint-7): gotcha-22 + INDEX.md v5 (ARCH 7.R единственная правка)
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

## Обязательные проверки будущих спринтов

### S7 — ARCH-задача: подключение оставшихся event_type к runtime

После завершения всех DEV-задач S7 архитектор **обязан** проверить, что следующие 5 типов уведомлений подключены к реальным runtime-событиям через `create_notification`:

| event_type | Что нужно | Источник события |
|------------|-----------|-----------------|
| `trade_opened` | EVENT_MAP: маппинг на открытие позиции | `trading/runtime.py` или `engine.py` |
| `partial_fill` | Частичное исполнение ордера | `trading/engine.py` → OrderManager |
| `order_error` | Ошибка выставления ордера | `trading/engine.py` → OrderManager |
| `all_positions_closed` | Все позиции закрыты | `trading/engine.py:681` (event уже есть, нет `create_notification`) |
| `connection_lost` / `connection_restored` | Потеря/восстановление gRPC-соединения | `broker/tinvest/multiplexer.py` (reconnect loop) |

Механизм доставки (in-app + Telegram + Email) работает для всех 13 типов — подтверждено тестом `test_dispatch_all_events.py` (14 passed). Нужно только подключить источники.

### S8 Review — обязательный чеклист: верификация всех обработчиков событий

В рамках Sprint_8_Review (M4: Production) **включить** следующую проверку:

- [ ] Все 13 event_type из `NotificationSettingsPage` реально генерируют уведомления при соответствующих runtime-событиях
- [ ] Для каждого event_type: включить Telegram + Email в настройках → вызвать событие → проверить доставку во все 3 канала
- [ ] Тест `test_dispatch_all_events.py` проходит (unit — механизм доставки)
- [ ] E2E или интеграционный тест: реальный сценарий (бэктест → notification → Telegram/Email) работает

### Post-Sprint — планы на развитие

Подробные описания вынесены в `Спринты/Планы на развитие/`. Краткий реестр: [README.md](Планы на развитие/README.md).

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
| **Sprint_6_Review** | S5 + S6 | **M3: Торговля + Notifications** | **✅ завершён (PASS, 2026-04-24)** | **Sprint_6_Review/code_review.md** |
| **Sprint_7_ARCH (7.R)** | **S7** | **M3 Phase 1 feature-complete** | **✅ завершён (PASS WITH NOTES, 2026-04-26)** | **Sprint_7/arch_review_s7.md** |
| Sprint_8_Review | S7 + S8 | M4: Production | ⬜ не начат | Sprint_8_Review/backlog.md |

## Milestones

| Milestone | Спринт | Статус | Критерии |
|-----------|--------|--------|----------|
| M1: Каркас | S1 | ✅ | Auth, дашборд, CI, 68 тестов |
| M2: Бэктест | S4 | ✅ | Стратегия → бэктест → результаты. Ревью: 21/28 задач исправлено, 7 отложено |
| M3: Paper Trading + Notifications | S5 + S6 + Sprint_6_Review | ✅ (2026-04-24) | Paper+Real Trading + Circuit Breaker + Bond НКД + Tax FIFO + Notifications (Telegram/Email/In-app) + Recovery + Graceful Shutdown. 945 тестов + 119 E2E. ARCH: PASS |
| **M3 Phase 1 feature-complete** | **S7** | **✅ (2026-04-26)** | **Версионирование стратегий, Grid Search, экспорт CSV/PDF, drawing tools, дашборд-виджеты, first-run wizard, backup/restore, AI слэш-команды, аналитика бэктеста, фоновые бэктесты, WS-сессии, 5 новых event_type, Telegram callbacks. 1279 unit-тестов (885 backend + 394 frontend) + 136 E2E. ARCH 7.R: PASS WITH NOTES.** |
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
