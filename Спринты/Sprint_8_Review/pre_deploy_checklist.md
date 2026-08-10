# Что закрыть до деплоя и до старта S9

> Составлено 2026-08-10 по итогам сплошной сверки backlog с кодом.
> Повод: список переносов Sprint 7 (`S7R-*`) вёлся как «открытый», но фактически
> большая его часть закрыта волнами S8 W4/W5 и приёмкой — заголовки карточек
> не обновлялись. Ниже — состояние, проверенное по коду, а не по документам.
>
> ⚠️ **Сверка выполнена дважды.** Первый проход шёл по основному чекауту
> `Develop/`, который стоит на ветке `p1/wave2-backend` — **103 коммита позади
> `develop`**, 201 файл расходится. Все выводы перепроверены в worktree от
> `origin/develop` `fe46f00`; ниже — только вторая, верная версия.
> Один вывод при перепроверке перевернулся (`S7R-CI-NODE24-MIGRATION`, см. A0).

## Итог сверки в одну строку

Из 33 карточек-переносов Sprint 7 **закрыты 29**, реально открыты **4**.
Плюс 6 низкоприоритетных карточек S8R и 3 пункта, зависящих от прод-среды.
Задач со внешним сроком **нет**.

---

## A. Блокеры деплоя

Сделать до первого развёртывания на Mac mini.

### A0. `S7R-CI-NODE24-MIGRATION` — ✅ уже закрыта, срока нет

Проверено на `develop`: `.github/workflows/ci.yml` и `playwright-nightly.yml`
используют `actions/checkout@v7`, `setup-python@v7`, `setup-node@v7`,
`pnpm/action-setup@v6`, `cache@v6`, `upload-artifact@v7` — все далеко за
пределами Node 20. Дедлайн 2026-09-16 неактуален.

Карточка осталась в backlog незакрытой и создавала ложное впечатление срочной
задачи. Пометить закрытой при обновлении учёта (раздел D).

### A1. Mock-курс USD в виджете баланса (`S9-MULTICURRENCY-CBR-RATE`)

**Проверено на `develop`:** `BalanceWidget.tsx:42` — `const USD_RUB_MOCK_RATE = 90`.
Переключатель RUB/USD работает на **захардкоженном курсе**, помеченном
«до production rollout».

В проде пользователь увидит сумму в долларах, которая просто неверна. Это
отображение денег, а не косметика. Либо подключить курс ЦБ, либо убрать
переключатель до появления источника — второе дешевле и честнее.

### A2. `S8R-W5-DOCKER-COMPOSE-VALIDATE` — семантика compose ни разу не проверена

В DEV-окружении нет docker CLI, поэтому `docker compose build` / `up` не
выполнялись **ни разу**; проверена только структурная валидность YAML
(`yaml.safe_load`). Первый деплой станет и первым запуском стека.

Не задача разработки — задача сделать это заранее, а не в момент выкатки.

### A3. `S7R-SESSION-RERUN-PAYLOAD-BROKEN` (medium) — «Запустить заново» ломает sandbox/real

**Подтверждено на `develop`**, `SessionDashboard.tsx:190-200`: payload rerun не
содержит ни `broker_account_id`, ни `timeframe`, а `mode` приводится к
`'paper' | 'real'` — тип врёт, `'sandbox'` теряется.

Backend требует оба поля через `model_validator` (`schemas.py:50`) → для любой
остановленной sandbox/real-сессии кнопка даёт **422**. Paper-rerun работает.

**Стало заметнее после этого цикла:** с запретом двух сессий на инструмент
пользователь чаще будет останавливать и перезапускать сессии — прямо на этот
сценарий.

### A4. `S8R-DELETE-ACCOUNT-ORPHANS-SESSIONS` — в проде это уже не low

Заведена как low, но в бою меняет вес. **Подтверждено на `develop`**: тело
`BrokerService.delete_account` — три строки (`get_account` → `db.delete` →
`commit`), никакой проверки сессий нет, а FK стоит `ondelete='SET NULL'`.
Удаление счёта обнулит `broker_account_id` у работающих сессий — они выпадут и
из нового запрета дублей, и из дедупликации `restore_all`, продолжая торговать.

Минимум — запретить удаление счёта с активными сессиями.

---

## B. Гигиена до старта S9

Не блокеры, но с ними S9 начнётся с чистого листа.

| Карточка | Sev | Суть | Оценка |
|---|---|---|---|
| `S8R-RESUME-STOP-NO-SESSION-LOCK` | low | «Стоп» + «Возобновить» одновременно — побеждает последний коммит | ~2 ч |
| `S8R-ENTRY-PATH-NO-CLOSE-LOCK` | low | путь открытия позиции не берёт лок сделки | ~3 ч |
| `S8R-FIGI-NO-NEGATIVE-CACHE` | low | неудачный резолв FIGI не кэшируется, запрос повторяется на каждый сигнал | ~1 ч |
| `S8R-PAPER-TARIFF-UNREACHABLE-FROM-UI` | low | наследование тарифа счёта paper-сессией через UI недостижимо | ~2 ч |
| `S7R-E2E-7.9-MISSING` | low | нет E2E на backup/restore CLI — единственный непокрытый пункт плана S7 | ~3 ч |
| `S7R-BG-BACKTEST-AUTOCOLLAPSE` | low | завершённые фоновые бэктесты не сворачиваются сами | ~1 ч |

**Отдельно — решение, а не работа:**

- `S8R-TRADES-WITHOUT-FIGI-UNMATCHABLE` (low) — на вашем стенде таких сделок
  **нет** (все sandbox-сделки закрыты). Предлагаю закрыть как неприменимую,
  а не тащить в S9.
- `S5R-BLOCKLY-MODE-B-MODAL` + `S5R-BLOCKLY-MODE-B-CHECK` (low) — два
  `test.skip` в `e2e/blockly.spec.ts:86,90` на функцию «mode B» (шаблоны),
  которая не реализована с S5. Либо делать функцию, либо удалить спеки —
  сейчас они создают ложное впечатление покрытия.
- Незакоммиченная правка `.env.example` в `Develop/` — ваше решение от
  2026-07-29 «оставить как есть» в силе, отмечено чтобы не потерялось.

---

## C. Требует прод-условий (не задачи)

Проверяется только после развёртывания, планировать как наблюдения:

- живые p50/p95 «сигнал → ордер» под нагрузкой (сейчас есть только synthetic
  baseline из `Sprint_8/perf_baseline_w5.md`);
- визуальный resize фигур на графике — воспроизводится только руками;
- `S8R-TINVEST-SANDBOX-FLAKY-70001` — поведение песочницы T-Invest, от нас
  не зависит; движок ведёт себя корректно.

---

## D. Карточки Sprint 7, закрытые по факту (обновление учёта)

Проверено по коду; в разделе «Sprint 7 — переносы» они выглядят открытыми,
но работа сделана. Помечать при следующей правке backlog.

| Карточка | Доказательство в коде |
|---|---|
| `S7R-AI-CHAT-TESTID-DRIFT` | `e2e/ai-chat.spec.ts:81` — селектор `[data-testid="ai-chat"] textarea` |
| `S6R-AICHAT-APPLY-MOCK` | `ai-chat.spec.ts:97` — `test(`, не `test.skip(` |
| `S7R-E2E-7.3-MISSING` | `e2e/s7-export.spec.ts` |
| `S7R-E2E-7.13-MISSING` | `e2e/s7-events.spec.ts` |
| `S7R-E2E-7.14-MISSING` | `e2e/s7-tg-callbacks.spec.ts` |
| `S7R-E2E-7.16-MISSING` | `e2e/s7-backtest-analytics.spec.ts` |
| `S7R-E2E-7.17-MISSING` | `e2e/s7-bg-backtest.spec.ts` |
| `S7R-GRID-HEATMAP-ENTRYPOINT` | `BackgroundBacktestsBadge.tsx:215` — компонент отрисовывается |
| `S7R-WIDGETS-UNIT-COVERAGE` | `dashboard/__tests__/HealthWidget.test.tsx`, `ActivePositionsWidget.test.tsx` |
| `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE` | `TestRealMode` в `test_engine_sandbox_flow.py`; `order_manager.py` как файл больше не существует — карточка описывает исчезнувшую структуру |
| `S7R-DRAWING-EDITING` | drag-обработчики в `DrawingsLayer.tsx` |
| `S7R-DRAWING-INTRADAY-COORDS` | `charts/sequentialIndex.ts` + `e2e/s7r-chart-drawings-fix.spec.ts`. Косметика: `MSK_OFFSET_SEC` продублирована в `CandlestickChart.tsx:41` и `sequentialIndex.ts:5` |
| `S7R-WIDGET-SPARKLINE-24H` | `GET /api/v1/market-data/sparkline` (`market_data/router.py:53`) |
| `S7R-DASHBOARD-POSITION-SPARKLINE-EMPTY` | дубликат предыдущей |
| `S7R-WIZARD-TELEGRAM-TEST-BUTTON` | `POST /notifications/telegram/test` (`router.py:362`) + проверено в приёмке 26.07 живой доставкой |
| `S7R-HEALTH-WS-MIGRATION` | `HealthWidget.tsx` — подписка на WS-канал `health`, polling оставлен страховкой |
| `S7R-MULTICURRENCY-TOGGLE` | `BalanceWidget.tsx:31,38` — `SegmentedControl` (см. A2 про курс) |
| `S7R-HISTOGRAM-MANTINE-TOOLTIP` | `PnLDistributionHistogram.tsx:189` — комментарий прямо ссылается на карточку |
| `S7R-API-PAGINATED-TYPE-MISMATCH` | `tradingApi.ts` — `PaginatedResponse<TradingSession>`; `unwrapPaginated` в 8 файлах |
| `S7R-FRONTEND-ERROR-BOUNDARY-MISSING` | `App.tsx:35` (app-level) + `DashboardPage.tsx:218` (по виджету) |
| `S7R-CONNECTION-EVENTS-MARKET-CLOSED` | `multiplexer.py:594` — `multiplexer_connection_event_suppressed_market_closed` |
| `S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE` | `account/router.py:31` — параметр `since_first_activity` |
| `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` | `main.py:389-428` — `cb_state`, `tinvest_connected`, `scheduler_running` |
| `S7R-STRATEGY-STATUS-CHANGE-UI` | `components/strategy/StrategyStatusMenu.tsx` + `strategyApi.updateStatus` |
| `S7R-STRATEGY-STATUS-PAUSED-FILTER` | `DashboardPage.tsx:205` — фильтр «Пауза» со счётчиком |
| `S7R-STRATEGY-STATUS-ENUM-DRIFT` | `strategy/schemas.py:48` — унифицировано на `live`, «real» помечен устаревшим |
| `S7R-FE-LINT-WARNINGS-CLEANUP` | `package.json` — `eslint . --max-warnings 0`, факт 0 |
| `S7R-SANDBOX-ACCOUNT-ID-MISSING` | `trading/service.py:112` — pre-flight проверка `account.account_id is None` |
| `S7R-CI-NODE24-MIGRATION` | `ci.yml`, `playwright-nightly.yml` — `checkout@v7`, `setup-python@v7`, `setup-node@v7`, `pnpm/action-setup@v6` |

---

## Предлагаемый порядок

1. **A3 + A4** — один цикл, оба про торговые сессии, общие тесты и общий риск.
2. **A1** — решить: курс ЦБ или убрать переключатель до появления источника.
3. **A2** — приурочить к подготовке деплоя.
4. **B** — одной «уборочной» волной, все шесть пунктов ~12 часов суммарно.
5. Обновить backlog по разделу **D** — учётная работа, полчаса.

Оценки грубые: это верхнеуровневый взгляд на код, не разбор каждой задачи.
