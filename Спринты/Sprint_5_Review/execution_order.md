# Sprint_5_Review — Execution Order

> Порядок выполнения задач и Cross-DEV contracts. Детальные планы в `PENDING_S5R_*.md` и (этап B) в `prompt_DEV-*.md`.

## Статус

- **Ревью:** 🔄 в процессе — этап A завершён 2026-04-14, переход к этапу B
- **Активная фаза:** этап B — создание `preflight_checklist.md` + `prompt_DEV-*.md` по `Спринты/prompt_template.md`
- **Следующая фаза:** этап C — запуск DEV-агентов по порядку (CI cleanup → E2E S4 + Live Runtime Loop + Real Positions параллельно)

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

> **Таблица заполнена детально 2026-04-14 в рамках этапа B.** Каждый контракт содержит точный файл/сигнатуру/команду верификации.

#### C1 — ruff green (DEV-1 → все)

- **Файл:** `Develop/backend/pyproject.toml`
- **Реализация:** секция `[tool.ruff.lint.per-file-ignores]` содержит `"alembic/env.py" = ["F401"]`
- **Верификация поставщика:** `cd Develop/backend && ruff check .` → exit 0
- **Верификация потребителя:** DEV-2/3 запускают `ruff check .` перед коммитом — 0 errors
- **Потребители:** DEV-1 (задача S5R.4), DEV-2, DEV-3

#### C2 — eslint green (DEV-1 → все)

- **Файл:** `Develop/frontend/eslint.config.js` + 6 конкретных файлов исходников
- **Реализация:** 6 React 19 проблем исправлены **адресно** (не через глобальное понижение правил):
  - `src/components/backtest/InstrumentChart.tsx:39-41` — `ref.current =` вынесено в `useEffect`
  - `src/components/common/TickerLogo.tsx:58` — `setImgError` через `key={ticker}` или prev-ref паттерн
  - `src/components/backtest/BacktestLaunchModal.tsx:109` — lazy initializer `useState(() => getRecentInstruments())`
  - `src/components/account/PositionsTable.tsx:74` — `// eslint-disable-next-line react-hooks/incompatible-library` (TanStack Table known issue)
  - `src/components/backtest/BacktestTrades.tsx:195` — то же
  - `src/components/layout/Sidebar.tsx:56` — константы вынесены в новый `src/components/layout/sidebarItems.ts`
- **Верификация:** `cd Develop/frontend && pnpm lint` → exit 0 (warnings допустимы, errors — нет)
- **Потребители:** DEV-1 (S5R.4), DEV-2, DEV-3

#### C3 — все CI jobs доходят до команды (DEV-1 → DEV-2, DEV-3)

- **Файл:** `Develop/.github/workflows/ci.yml`
- **Реализация:** после фиксов C1 и C2 все 6 шагов проходят:
  - backend: `ruff check .` → `mypy app/ --ignore-missing-imports` → `pytest tests/unit/`
  - frontend: `pnpm lint` → `pnpm tsc --noEmit` → `pnpm test`
- **Верификация:** `gh run list --workflow ci.yml --branch s5r/ci-cleanup --limit 1` → `completed success`
- **Потребители:** DEV-2, DEV-3 (без зелёного CI их Integration Verification будет пустой декларацией)

#### C4 — TradingSession.timeframe (DEV-2 → DEV-2 frontend + S6)

- **Backend модель:** `Develop/backend/app/trading/models.py`
  ```python
  timeframe: Mapped[str | None] = mapped_column(String(10), nullable=True)
  ```
- **Миграция:** `Develop/backend/alembic/versions/XXXX_add_timeframe_to_trading_sessions.py` — ADD COLUMN, nullable, без default
- **Pydantic:** `Develop/backend/app/trading/schemas.py`
  ```python
  class SessionResponse(BaseModel):
      timeframe: str | None = None
  ```
- **TypeScript:** `Develop/frontend/src/api/types.ts`
  ```ts
  export interface TradingSession {
    timeframe: string | null;
  }
  ```
- **Верификация:**
  ```bash
  grep -n "timeframe" Develop/backend/app/trading/models.py
  grep -n "timeframe" Develop/backend/app/trading/schemas.py
  grep -n "timeframe" Develop/frontend/src/api/types.ts
  alembic upgrade head && alembic downgrade -1 && alembic upgrade head
  ```
- **Потребители:** DEV-2 (frontend-часть той же задачи), DEV-3 (косвенно — для доработок trading panel в S6)

#### C5 — SessionStartRequest.timeframe обязательное (DEV-2 backend → DEV-2 frontend)

- **Backend схема:** `Develop/backend/app/trading/schemas.py`
  ```python
  from typing import Literal
  SupportedTimeframe = Literal["1m", "5m", "15m", "1h", "4h", "D", "W", "M"]

  class SessionStartRequest(BaseModel):
      timeframe: SupportedTimeframe  # обязательное
  ```
- **Frontend:** `LaunchSessionModal.tsx` — `<Select data-testid="session-timeframe-select" required>` с теми же 8 значениями
- **Верификация:**
  ```bash
  pytest tests/test_trading/ -k "test_start_session_requires_timeframe" -v
  # POST /trading/sessions/start без timeframe → 422
  ```
- **Потребители:** DEV-2 frontend, Sprint 6 задача 6.8 (доработки Trading Panel)

#### C6 — SessionRuntime API (DEV-2 → Sprint 6 задача 6.4 Recovery)

- **Файл:** `Develop/backend/app/trading/runtime.py` (**новый**)
- **Сигнатура:**
  ```python
  class SessionRuntime:
      async def start(self, session: TradingSession) -> None: ...
      async def stop(self, session_id: int) -> None: ...
      async def restore_all(self, sessions: list[TradingSession]) -> None: ...
  ```
- **Вызовы из production:**
  - `TradingSessionManager.start_session` → `await self.runtime.start(session)` **после** `db.commit()`
  - `TradingSessionManager.stop_session` → `await self.runtime.stop(session_id)` **до** `db.commit()`
  - `TradingSessionManager.pause_session` → `await self.runtime.stop(session_id)` **до** `db.commit()`
  - `main.py` lifespan → `await runtime.restore_all(active_sessions)` **при старте** backend
- **Верификация:**
  ```bash
  grep -rn "SessionRuntime(" app/        # инстанциирование где-то кроме runtime.py
  grep -rn "runtime\.start\(\|runtime\.stop\(" app/
  grep -rn "restore_all" app/
  ```
- **Потребители:** Sprint 6 задача 6.4 (Recovery with real-side sync), 6.5 (Graceful Shutdown)

#### C7 — EventBus events из runtime (DEV-2 → Sprint 6 задача 6.3 In-app)

- **Файл:** `Develop/backend/app/trading/runtime.py`
- **Канал:** `trades:{session_id}` (строка, не список)
- **События:** каждое — dict с ключом `type`:
  ```python
  {"type": "session.started", "session_id": int, "timeframe": str}
  {"type": "session.stopped", "session_id": int}
  {"type": "order.placed", "session_id": int, "order_id": int, "latency_ms": float}
  {"type": "trade.filled", "session_id": int, "trade_id": int, "ticker": str, "action": str, "price": str}
  {"type": "trade.closed", "session_id": int, "trade_id": int, "pnl": str}
  {"type": "cb.triggered", "session_id": int, "signal": str, "reason": str}
  ```
- **Верификация:**
  ```bash
  grep -rn 'f"trades:{' Develop/backend/app/trading/runtime.py
  # Должно найти publish() вызовы со всеми 6 типами событий
  ```
- **Потребители:** Sprint 6 задача 6.3 (In-app notifications WebSocket), задача 6.4 (Recovery слушает `session.started` для пересборки состояния UI)

#### C8 — GET /broker/accounts/{id}/positions (DEV-3 → S5R finalisation, S6)

- **Файл:** `Develop/backend/app/broker/router.py`
- **Endpoint:**
  ```python
  @router.get("/accounts/{account_id}/positions", response_model=list[BrokerPositionResponse])
  async def get_account_positions(
      account_id: int,
      user: User = Depends(get_current_user),
      service: BrokerService = Depends(get_broker_service),
  ) -> list[BrokerPositionResponse]: ...
  ```
- **Response (`BrokerPositionResponse`):**
  ```json
  [
    {
      "figi": "BBG004730N88",
      "ticker": "SBER",
      "name": "Сбербанк",
      "instrument_type": "share",
      "quantity": "100",
      "average_price": "250.50",
      "current_price": "265.30",
      "unrealized_pnl": "1480.00",
      "currency": "RUB",
      "source": "strategy",
      "blocked": "0"
    }
  ]
  ```
  **Все Decimal-поля сериализуются как `str`** (Gotcha 1).
- **Source правило:** `"strategy"` если FIGI позиции есть в таблице `orders` для данного `account_id` + `user_id`, иначе `"external"`.
- **Верификация:**
  ```bash
  grep -n "return \[\]" Develop/backend/app/broker/router.py   # должно быть 0 в positions endpoint
  pytest tests/broker/test_broker_router_positions.py -v
  ```
- **Потребители:** frontend `PositionsTable`, ARCH финальная приёмка S5R

#### C9 — GET /broker/accounts/{id}/operations (DEV-3 → S5R finalisation, S6)

- **Файл:** `Develop/backend/app/broker/router.py`
- **Endpoint:**
  ```python
  @router.get("/accounts/{account_id}/operations", response_model=BrokerOperationListResponse)
  async def get_account_operations(
      account_id: int,
      from_: datetime = Query(..., alias="from"),
      to: datetime = Query(...),
      offset: int = Query(0, ge=0),
      limit: int = Query(100, ge=1, le=500),
      user: User = Depends(get_current_user),
      service: BrokerService = Depends(get_broker_service),
  ) -> BrokerOperationListResponse: ...
  ```
- **Response:**
  ```json
  {
    "items": [
      {
        "id": "...",
        "parent_operation_id": null,
        "figi": "BBG004730N88",
        "ticker": "SBER",
        "name": "Сбербанк",
        "type": "BUY",
        "state": "EXECUTED",
        "date": "2026-04-14T10:15:00Z",
        "quantity": "100",
        "price": "250.50",
        "payment": "-25050.00",
        "currency": "RUB"
      }
    ],
    "total": 128
  }
  ```
- **Типы:** `BUY | SELL | DIVIDEND | COUPON | COMMISSION | TAX | OTHER`
- **Верификация:** `pytest tests/broker/test_broker_router_operations.py -v`
- **Потребители:** frontend `OperationsTable`, ARCH финальная приёмка

#### C10 — Playwright baseline (DEV-1 E2E S4 fix → DEV-2 тест Live Runtime)

- **Реализация:** `cd Develop/frontend && npx playwright test` → 0 failures
- **Допустимо:** `test.skip(reason, { tag: '@s4-legacy' })` с TODO-комментом и тикетом
- **Объём отчёта:** в отчёте DEV-1 указано **конкретное число** «X тестов, Y passing, Z skipped»
- **Не-spec файлы:** `e2e/test-backtest-*.ts`, `test-lkoh-*.ts` перемещены в `e2e/helpers/` или удалены
- **Верификация:**
  ```bash
  cd Develop/frontend && npx playwright test --reporter=list
  ls Develop/frontend/e2e/test-backtest-*.ts 2>/dev/null   # должно быть пусто
  ```
- **Потребители:** DEV-2 (новый `s5r-live-runtime.spec.ts` встраивается в общий зелёный прогон)

#### C11 — arch_review_s5r.md (ARCH → Оркестратор)

- **Файл:** `Спринты/Sprint_5_Review/arch_review_s5r.md`
- **Обязательные разделы:**
  1. Baseline «до/после» — таблица CI/тестов/техдолга
  2. Верификация по задачам S5R.1-4 с вердиктами
  3. Cross-DEV contracts — сводная таблица (все C1-C11 подтверждены)
  4. **Оценка эффективности нового процесса работы DEV-субагентов (S5R.5)** — обязательная секция, до 500 слов
  5. Обновления ФТ/ТЗ (S5R.6) — перечень изменённых разделов
  6. Новые Stack Gotchas (если обнаружены)
  7. Рекомендации для Sprint 6
  8. Финальный вердикт: **PASS / PASS WITH NOTES / FAIL**
- **Верификация:** файл создан, все 8 разделов заполнены, вердикт выставлен
- **Потребитель:** Оркестратор (для принятия решения о старте S6)

### Подтверждения контрактов (заполняется DEV-агентами в отчётах)

| # | Контракт | Поставщик | Статус | Комментарий |
|---|----------|-----------|--------|-------------|
| C1 | ruff green | DEV-1 | ✅ | `pyproject.toml` per-file-ignores + автофикс 158 errors. CI run #24406811582. |
| C2 | eslint green | DEV-1 | ✅ | 9 React 19 hooks мест адресно + расчистка unused-vars. 0 errors (7 warn). |
| C3 | all CI jobs reach command | DEV-1 | ✅ | Все 6 шагов exit 0. mypy 77→0 (overrides удалены), vitest 22→0 (excluded удалены). Run #24406811582. |
| C4 | TradingSession.timeframe | DEV-2 | ⬜ | — |
| C5 | SessionStartRequest.timeframe | DEV-2 | ⬜ | — |
| C6 | SessionRuntime API | DEV-2 | ⬜ | — |
| C7 | EventBus events | DEV-2 | ⬜ | — |
| C8 | positions endpoint | DEV-3 | ⬜ | — |
| C9 | operations endpoint | DEV-3 | ⬜ | — |
| C10 | Playwright baseline | DEV-1 | ⬜ | — (волна 2) |
| C11 | arch_review_s5r.md | ARCH | ⬜ | — |

---

## Чек-лист этапа A (завершён 2026-04-14)

- [x] `Sprint_5_Review/README.md` — создан
- [x] `Sprint_5_Review/backlog.md` — создан с 6 задачами
- [x] `Sprint_5_Review/execution_order.md` — этот файл, с Cross-DEV contracts (скелет)
- [x] `Sprint_5_Review/PENDING_S5R_live_runtime_loop.md` — перемещён из `Sprint_6/`
- [x] `Sprint_5_Review/PENDING_S5R_real_account_positions_operations.md` — перемещён из `Sprint_6/`
- [x] `Sprint_5_Review/PENDING_S5R_ci_cleanup.md` — новый
- [x] `Sprint_5_Review/PENDING_S5R_e2e_s4_fix.md` — новый
- [x] `Спринты/project_state.md` — обновлён (S5R в разделе ревью, техдолг S6 → S5R)
- [x] `Документация по проекту/development_plan.md` — обновлён (откат 6.0 и 6.9 из S6, новый раздел S5R с задачами S5R.1-6)
- [x] `Спринты/Sprint_5/sprint_state.md` + `changelog.md` — финальная пометка про внеплановое S5R
- [ ] Коммит+push в репо `test` (этап A — единый коммит)

## Чек-лист этапа B (завершён 2026-04-14)

- [x] `Sprint_5_Review/preflight_checklist.md` — создан (системные требования, состояние репо, baseline тестов, блокирующие правила)
- [x] `Sprint_5_Review/prompt_DEV-1.md` — по `prompt_template.md`, задачи S5R.1 + S5R.4
- [x] `Sprint_5_Review/prompt_DEV-2.md` — по `prompt_template.md`, задача S5R.2 (Live Runtime Loop)
- [x] `Sprint_5_Review/prompt_DEV-3.md` — по `prompt_template.md`, задача S5R.3 (Real Positions T-Invest)
- [x] `Sprint_5_Review/prompt_ARCH_review.md` — финальное ревью + S5R.5 (оценка процесса) + S5R.6 (ФТ/ТЗ)
- [x] Cross-DEV contracts C1-C11 — детализированы (точные файлы, сигнатуры, endpoint'ы, команды верификации)
- [ ] Коммит+push в репо `test` (этап B — единый коммит)
