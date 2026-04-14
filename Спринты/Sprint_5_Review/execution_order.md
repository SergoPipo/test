# Sprint_5_Review — Execution Order

> Порядок выполнения задач и Cross-DEV contracts. Детальные планы в `PENDING_S5R_*.md` и (этап B) в `prompt_DEV-*.md`.

## Статус

- **Ревью:** 🔄 в процессе — этап A (планирование)
- **Активная фаза:** документация + backlog
- **Следующая фаза:** этап B — создание `prompt_DEV-*.md` по `Спринты/prompt_template.md`, потом запуск DEV-агентов

## Последовательность выполнения

```
Фаза 0: Preflight (до запуска DEV-агентов)
├── этап A (ТЕКУЩИЙ)
│   ├── README.md, backlog.md, execution_order.md — созданы
│   ├── PENDING_S5R_*.md файлы — созданы
│   ├── project_state.md, development_plan.md — обновлены
│   └── Cross-DEV contracts (ниже) — заполнены
└── этап B
    ├── preflight_checklist.md — создать
    ├── prompt_DEV-1.md — CI cleanup + E2E S4 fix
    ├── prompt_DEV-2.md — Live Runtime Loop
    ├── prompt_DEV-3.md — Реальные позиции T-Invest
    └── prompt_ARCH_review.md — финальное ревью S5R

Фаза 1: CI Baseline (блокер для всех последующих)
└── DEV-1 → Задача 1 (CI cleanup)
    Вывод: зелёный CI, можно запускать остальных DEV без шума failed-уведомлений

Фаза 2: Параллельные фиксы на baseline
├── DEV-1 → Задача 4 (E2E S4 fix)          [продолжает работу]
├── DEV-2 → Задача 2 (Live Runtime Loop)   [начинает параллельно]
└── DEV-3 → Задача 3 (Реальные позиции)    [начинает параллельно]

Фаза 3: Интеграция и ревью
├── DEV-2 финиширует Live Runtime Loop
├── DEV-3 финиширует Реальные позиции
├── DEV-1 финиширует E2E S4 fix
└── ARCH → Задача 6 (Актуализация ФТ/ТЗ) + финальный arch_review_s5r.md
    ├── Оценка нового процесса работы DEV-субагентов (Задача 5)
    ├── Обновлённые ФТ/ТЗ/development_plan
    └── Пустой техдолг перед S6

Фаза 4: Закрытие S5R
├── Коммиты+push в оба репо
├── project_state.md — S5R ✅, переходим к S6
└── S6 стартует с зелёного CI + работающего runtime + реальных позиций
```

### Почему CI cleanup — первым (блокер всего остального)

- Без зелёного CI невозможно использовать Integration Verification Checklist из `prompt_template.md` (grep-правила проверяют факт вызова, но без работающих тестов мы не узнаем о регрессиях)
- Любой PR от DEV-2 или DEV-3 будет показывать `All jobs failed` в mixed-сигнале со старыми падениями
- Failed-уведомления GitHub продолжат засорять почту, скрывая новые проблемы

### Почему E2E S4 fix вторым (перед Live Runtime Loop)

- Для задачи 2 (Live Runtime Loop) критерии готовности включают E2E тест «fake-стрим → сессия → ордер». Без работающего baseline Playwright новый E2E не добавишь в общий прогон.
- Задача 4 — тоже чисто infrastructure, делается тем же DEV-1 сразу после CI cleanup в одной сессии.

### Почему Live Runtime Loop и реальные позиции — параллельно

- Задача 2 (Live Runtime Loop) и задача 3 (реальные позиции) **не пересекаются** по файлам:
  - Задача 2 — `trading/engine.py`, `trading/runtime.py` (новый), `trading/models.py`, `market_data/stream_manager.py`, frontend trading-компоненты
  - Задача 3 — `broker/router.py`, `broker/service.py`, `broker/tinvest/mapper.py`, frontend account-компоненты
- Оба DEV-агента могут работать в изолированных git worktree (см. правила в корневом `CLAUDE.md` про субагентов) без конфликтов.

---

## ⚠️ Cross-DEV Contracts

> **Обязательный раздел** для каждого `execution_order.md` начиная с Sprint 6. Для Sprint_5_Review — первое применение правила. Таблица заполняется **до** запуска DEV-агентов (конец этапа A / начало этапа B).
>
> Правила:
> - Если DEV указан как **поставщик** контракта, в своём отчёте он обязан явно подтвердить реализацию: «Контракт X реализован как Y».
> - Если DEV указан как **потребитель** контракта, в отчёте он обязан явно подтвердить использование: «Использую контракт X, реализованный DEV-Z».
> - Несоответствие контракта — **блокирующая ошибка** для оркестратора.

### Контракты Sprint_5_Review

| # | Поставщик | Потребитель | Контракт | Формат/сигнатура |
|---|-----------|-------------|----------|-------------------|
| C1 | DEV-1 (CI cleanup) | DEV-1, DEV-2, DEV-3 | Зелёный `ruff check .` в `backend/` | `pyproject.toml` секция `[tool.ruff.lint.per-file-ignores]` содержит `"alembic/env.py" = ["F401"]` |
| C2 | DEV-1 (CI cleanup) | DEV-1, DEV-2, DEV-3 | Зелёный `pnpm lint` в `frontend/` | `eslint.config.js` — либо `react-hooks/*` → `warn`, либо конкретные 6 мест исправлены |
| C3 | DEV-1 (CI cleanup) | DEV-2, DEV-3 | Зелёный `pnpm tsc --noEmit`, `pytest tests/unit/`, `vitest`, `playwright` | Каждый job в `.github/workflows/ci.yml` доходит до выполнения своей команды и возвращает exit 0 |
| C4 | DEV-2 (Live Runtime) | DEV-2 frontend-часть, DEV-3 (косвенно — для доработок trading panel в S6) | Поле `TradingSession.timeframe: str` в модели и API | SQLAlchemy `Mapped[str]` nullable, Pydantic `SessionResponse.timeframe: str \| None`, TS `TradingSession.timeframe?: string` |
| C5 | DEV-2 (Live Runtime backend) | DEV-2 frontend-часть | `SessionStartRequest.timeframe` обязательное поле | `Literal["1m","5m","15m","1h","4h","D","W","M"]` |
| C6 | DEV-2 (Live Runtime) | S6 задача 6.4 (Recovery) | Сигнатура `SessionRuntime.start(session: TradingSession) -> None` и `SessionRuntime.stop(session_id: int) -> None` | Вызывается из `TradingSessionManager.start_session` после commit в БД; из `stop_session` / `pause_session` перед commit; из `restore_sessions` при старте backend |
| C7 | DEV-2 (Live Runtime) | S6 задача 6.3 (In-app notifications) | EventBus events из runtime | Каналы: `trades:{session_id}` с events `order.placed`, `trade.filled`, `trade.closed`, `session.started`, `session.stopped`, `cb.triggered` — data формат из `trading/engine.py:SignalProcessor` |
| C8 | DEV-3 (Real positions) | S5R finalisation, S6 | `GET /api/v1/broker/accounts/{id}/positions` реальная имплементация | Response: `list[BrokerPosition]` с полями `ticker, name, quantity, average_price, current_price, unrealized_pnl, source: 'strategy'\|'external', currency` |
| C9 | DEV-3 (Real positions) | S5R finalisation, S6 | `GET /api/v1/broker/accounts/{id}/operations` реальная имплементация | Response: `{items: list[BrokerOperation], total: int}` с пагинацией `offset`/`limit`, фильтр `from`/`to` |
| C10 | DEV-1 (E2E S4 fix) | DEV-2 (тест Live Runtime) | Работающий baseline Playwright | `npx playwright test` запускается, существующие s4-* тесты зелёные или явно skipped с аннотацией |
| C11 | ARCH (финальное ревью) | Оркестратор | `arch_review_s5r.md` с PASS / PASS WITH NOTES / FAIL | Формат как в `Sprint_5/arch_review_s5.md`: сводка, детали по модулям, найденные проблемы, рекомендации для S6. Обязательная секция «Оценка эффективности нового процесса работы DEV-субагентов» |

### Подтверждения контрактов (заполняется DEV-агентами в отчётах)

| # | Контракт | Поставщик | Статус | Комментарий |
|---|----------|-----------|--------|-------------|
| C1 | ruff green | DEV-1 | ⬜ | — |
| C2 | eslint green | DEV-1 | ⬜ | — |
| C3 | all CI jobs reach command | DEV-1 | ⬜ | — |
| C4 | TradingSession.timeframe | DEV-2 | ⬜ | — |
| C5 | SessionStartRequest.timeframe | DEV-2 | ⬜ | — |
| C6 | SessionRuntime API | DEV-2 | ⬜ | — |
| C7 | EventBus events | DEV-2 | ⬜ | — |
| C8 | positions endpoint | DEV-3 | ⬜ | — |
| C9 | operations endpoint | DEV-3 | ⬜ | — |
| C10 | Playwright baseline | DEV-1 | ⬜ | — |
| C11 | arch_review_s5r.md | ARCH | ⬜ | — |

---

## Чек-лист этапа A (текущий)

- [x] `Sprint_5_Review/README.md` — создан
- [x] `Sprint_5_Review/backlog.md` — создан с 6 задачами
- [x] `Sprint_5_Review/execution_order.md` — этот файл, с Cross-DEV contracts (скелет)
- [ ] `Sprint_5_Review/PENDING_S5R_live_runtime_loop.md` — перемещён из `Sprint_6/`
- [ ] `Sprint_5_Review/PENDING_S5R_real_account_positions_operations.md` — перемещён из `Sprint_6/`
- [ ] `Sprint_5_Review/PENDING_S5R_ci_cleanup.md` — новый
- [ ] `Sprint_5_Review/PENDING_S5R_e2e_s4_fix.md` — новый
- [ ] `Спринты/project_state.md` — обновлён (S5R в разделе ревью, техдолг S6 → S5R)
- [ ] `Документация по проекту/development_plan.md` — обновлён (откат 6.0 и 6.9 из S6, новый раздел S5R)
- [ ] `Спринты/Sprint_5/sprint_state.md` + `changelog.md` — финальная пометка про внеплановое S5R
- [ ] Коммит+push в репо `test`

## Чек-лист этапа B (следующая сессия)

- [ ] `Sprint_5_Review/preflight_checklist.md` — создать (проверки среды, состояние репо, тесты baseline)
- [ ] `Sprint_5_Review/prompt_DEV-1.md` — по `prompt_template.md`, задачи 1 + 4
- [ ] `Sprint_5_Review/prompt_DEV-2.md` — по `prompt_template.md`, задача 2
- [ ] `Sprint_5_Review/prompt_DEV-3.md` — по `prompt_template.md`, задача 3
- [ ] `Sprint_5_Review/prompt_ARCH_review.md` — финальное ревью
- [ ] Заполнить детали всех Cross-DEV contracts (точные endpoint / типы / сигнатуры)
