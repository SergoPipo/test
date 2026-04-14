---
sprint: 5_Review
agent: ARCH
role: "Архитектурное ревью S5R + задача S5R.6 (актуализация ФТ/ТЗ) + оценка нового процесса работы DEV-субагентов"
wave: 3 (финал)
depends_on: [DEV-1, DEV-2, DEV-3]
---

# Роль

Ты — **Архитектор-ревьюер** Sprint_5_Review. Твоя задача трёхкомпонентная:

1. **Финальная приёмка S5R.1-5** — проверить, что все 3 DEV-агента (DEV-1 CI cleanup + E2E S4 fix, DEV-2 Live Runtime Loop, DEV-3 Real Positions) сдали работу по **всем** критериям: код, тесты, Integration Verification, контракты, формат отчёта.
2. **S5R.6 Актуализация ФТ/ТЗ** — обновить `functional_requirements.md`, `technical_specification.md`, `development_plan.md`, `ui_checklist` за весь S5 + S5R.
3. **Оценка эффективности нового процесса работы DEV-субагентов (S5R.5)** — первая обкатка `prompt_template.md` + Stack Gotchas + Integration Verification + Cross-DEV contracts. Что сработало, что надо доработать перед Sprint 6.

Результат твоей работы — `arch_review_s5r.md` с вердиктом **PASS / PASS WITH NOTES / FAIL**, обновлённые документы ФТ/ТЗ/план, **пустой техдолг** S5R, и рекомендации для Sprint 6.

Ты — **поставщик** контракта **C11** из [execution_order.md](execution_order.md).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Если хотя бы один пункт не выполнен — **НЕ начинай** ревью, верни `БЛОКЕР: <описание>` и дождись, пока оркестратор устранит.

```
1. Все 3 DEV-отчёта сданы:
   - DEV-1 отчёт (S5R.1 + S5R.4) — получен, в формате prompt_template.md (8 секций, ≤ 400 слов)
   - DEV-2 отчёт (S5R.2) — получен, в формате
   - DEV-3 отчёт (S5R.3) — получен, в формате

2. Cross-DEV contracts подтверждены в отчётах:
   - C1, C2, C3, C10 — DEV-1
   - C4, C5, C6, C7 — DEV-2
   - C8, C9 — DEV-3

3. Весь код смержен в develop (или в единую feature-ветку S5R):
   - cd Develop && git log --oneline origin/develop..HEAD — пусто или только твой текущий коммит
   - git status --porcelain — чисто

4. Baseline тестов зелёный (ожидание ПОСЛЕ DEV-работ):
   - cd Develop/backend && ruff check . → exit 0
   - cd Develop/backend && mypy app/ → exit 0
   - cd Develop/backend && pytest tests/ → 0 failures
   - cd Develop/frontend && pnpm lint → exit 0
   - cd Develop/frontend && pnpm tsc --noEmit → 0 errors
   - cd Develop/frontend && pnpm test → 0 failures
   - cd Develop/frontend && npx playwright test → 0 failures
   - gh run list --workflow ci.yml --limit 1 → completed success

5. Миграции применены:
   - cd Develop/backend && alembic current → последняя миграция (add_timeframe_to_trading_sessions)
   - alembic downgrade -1 && alembic upgrade head → идемпотентно
```

# ⚠️ Обязательное чтение (BEFORE any review)

1. **[Develop/CLAUDE.md](../../Develop/CLAUDE.md)** — **полностью**, особое внимание:
   - Секция «⚠️ Stack Gotchas» (1-5) — проверить, что DEV-отчёты в секции 7 действительно ссылаются на применённые ловушки
   - Если DEV-отчёт упоминает **новые** Stack Gotchas — **твоя задача** добавить их в `Develop/CLAUDE.md` после приёмки

2. **[Sprint_5_Review/README.md](README.md)** + **[backlog.md](backlog.md)** — контекст ревью, 6 задач, критерии готовности

3. **[Sprint_5_Review/execution_order.md](execution_order.md)** раздел «Cross-DEV Contracts» — 11 контрактов C1-C11. **Твоя обязанность** — сверить каждый контракт с фактической реализацией в коде, а не просто полагаться на подтверждение DEV.

4. **[Sprint_5/arch_review_s5.md](../Sprint_5/arch_review_s5.md)** — формат финального ревью предыдущего спринта как образец. Твой `arch_review_s5r.md` должен иметь **как минимум** те же разделы, **плюс**:
   - Раздел «Оценка эффективности нового процесса работы DEV-субагентов»
   - Раздел «Baseline до/после» (CI красный/зелёный, тесты не гонялись/гоняются, Live Runtime NOT CONNECTED / CONNECTED)
   - Раздел «Обновления ФТ/ТЗ» (список изменённых секций)

5. **4× `PENDING_S5R_*.md`** — критерии готовности каждой задачи

6. **[Документация по проекту/functional_requirements.md](../../Документация%20по%20проекту/functional_requirements.md)** — особенно разделы 6 (Торговля), 7.3 (Счёт), 7.7 (Несколько счетов), 12.4 (Circuit Breaker)

7. **[Документация по проекту/technical_specification.md](../../Документация%20по%20проекту/technical_specification.md)** — особенно разделы 5.4 (Trading Engine + 5.4.2 Signal flow + 5.4.3 Recovery), 5.6.5 (Bond), 5.13 (Tax), 6.6 (Trading Panel), 6.7 (Account)

8. **[Документация по проекту/development_plan.md](../../Документация%20по%20проекту/development_plan.md)** — раздел S5R.1-6, убедиться что все задачи закрыты

9. **Цитата корневого CLAUDE.md (дословно):**

   > **Правило «Integration Verification» (из корневого CLAUDE.md):**
   > «Каждый DEV обязан в отчёте подтвердить, что новые классы/методы вызываются в production-коде (`grep -rn "<ClassName>(" app/`), не только в тестах. Если точка вызова не найдена — явно пометить `⚠️ NOT CONNECTED` в отчёте. Такая пометка блокирует формальную приёмку.»

   **Твоя задача как ARCH:** повторить grep самостоятельно, а не верить отчёту на слово. Это именно та проверка, которой не хватило в ARCH-ревью S5 — и именно она создала техдолг #4, ставший причиной этого ревью.

# Рабочая директория

- `Test/Спринты/Sprint_5_Review/` — создать `arch_review_s5r.md` и `changelog.md` (если ещё нет)
- `Test/Develop/` — повторная верификация кода (grep'ы, тесты, CI)
- `Test/Документация по проекту/` — обновление ФТ/ТЗ/плана
- `Test/Спринты/project_state.md` — финальный статус S5R
- `Test/Спринты/Sprint_5/sprint_state.md` — финальная пометка про закрытие S5R

# Задачи

## Задача ARCH.1: Верификация S5R.1 (CI cleanup)

**DEV-1 обещал:** контракты C1, C2, C3, C10. Проверить факты.

1. **C1 — ruff:**
   ```bash
   cd Develop/backend && ruff check .
   # Ожидание: All checks passed!
   grep -A2 "per-file-ignores" pyproject.toml
   # Ожидание: секция содержит "alembic/env.py" = ["F401"]
   ```

2. **C2 — eslint:**
   ```bash
   cd Develop/frontend && pnpm lint
   # Ожидание: 0 errors
   # Проверить, что 6 React 19 мест исправлены АДРЕСНО (а не через глобальный eslint-disable):
   grep -n "eslint-disable-next-line" src/components/backtest/InstrumentChart.tsx   # ничего или точечно
   grep -n "useEffect" src/components/backtest/InstrumentChart.tsx                  # useEffect добавлены
   ```

3. **C3 — все CI jobs доходят до команды:**
   ```bash
   cd Develop/backend && mypy app/ --ignore-missing-imports && pytest tests/unit/
   cd Develop/frontend && pnpm tsc --noEmit && pnpm test
   # Все 4 команды exit 0
   gh run list --workflow ci.yml --branch develop --limit 3
   # Последние 3 runs — completed success
   ```

4. **C10 — Playwright baseline:**
   ```bash
   cd Develop/frontend && npx playwright test --reporter=list
   # Ожидание: 0 failures (допустимы test.skip() с аннотацией-тикетом)
   ```

**Вердикт по S5R.1:** PASS / PASS WITH NOTES / FAIL.

## Задача ARCH.2: Верификация S5R.2 (Live Runtime Loop) — ГЛАВНАЯ

**DEV-2 обещал:** контракты C4, C5, C6, C7 + замкнутый runtime.

Это **самая важная** часть ревью. Именно отсутствие этой проверки в ARCH-ревью S5 создало техдолг #4 → причину этого ревью.

1. **Integration Verification grep'ы (повторить самостоятельно):**
   ```bash
   cd Develop/backend

   # Главное: process_candle вызывается в production (не только тесты)
   grep -rn "process_candle(" app/
   # Ожидание: минимум
   #   app/trading/engine.py:<определение>
   #   app/trading/runtime.py:<production вызов> ← КРИТИЧНО
   # Если runtime.py нет в результатах → FAIL немедленно

   # SessionRuntime создаётся где-то кроме runtime.py
   grep -rn "SessionRuntime(" app/
   # Ожидание: app/main.py или app/trading/service.py (DI)

   # runtime.start и runtime.stop вызываются
   grep -rn "runtime\.start\|runtime\.stop" app/
   # Ожидание: app/trading/engine.py или service.py в start_session/stop_session/pause_session

   # Listener на event_bus
   grep -rn "event_bus.subscribe" app/trading/
   # Ожидание: runtime.py с каналом market:{ticker}:{tf}

   # Recovery при старте
   grep -rn "restore_all\|restore_sessions" app/
   # Ожидание: вызов из main.py lifespan
   ```

2. **C4 — TradingSession.timeframe:**
   ```bash
   grep -n "timeframe" app/trading/models.py
   # Ожидание: Mapped[str | None] = mapped_column(String(10), nullable=True)

   ls alembic/versions/ | grep timeframe
   # Ожидание: миграция add_timeframe_to_trading_sessions

   alembic upgrade head
   alembic downgrade -1
   alembic upgrade head
   # Все 3 команды exit 0
   ```

3. **C5 — SessionStartRequest.timeframe:**
   ```bash
   grep -n "timeframe" app/trading/schemas.py
   # Ожидание: Literal["1m","5m","15m","1h","4h","D","W","M"] обязательное

   # Интеграционный тест: POST /trading/sessions/start без timeframe → 422
   pytest tests/test_trading/ -k "test_start_session_requires_timeframe" -v
   ```

4. **C6 — SessionRuntime API:**
   Прочитать `app/trading/runtime.py` — класс должен иметь `async def start(session)` и `async def stop(session_id)`. Проверить вызовы из `TradingSessionManager`.

5. **C7 — EventBus events:**
   ```bash
   grep -rn "trades:{session_id}\|trades:{session.id}" app/trading/runtime.py
   # Ожидание: publish событий session.started, session.stopped, order.placed, cb.triggered
   ```

6. **E2E latency:**
   Прочитать лог интеграционного теста `test_runtime_integration.py::test_end_to_end_paper_session` — должен показывать `latency < 500ms` или warning при превышении.

7. **Frontend:**
   ```bash
   grep -n "session-timeframe-select" Develop/frontend/src/components/trading/LaunchSessionModal.tsx
   # Ожидание: <Select data-testid="session-timeframe-select"> с опциями TF

   grep -n "timeframe" Develop/frontend/src/api/types.ts
   # Ожидание: Timeframe type + SessionStartRequest.timeframe + TradingSession.timeframe
   ```

**Вердикт по S5R.2:** PASS / PASS WITH NOTES / FAIL.

**Если `grep "process_candle("` не показывает вызов из `runtime.py` — немедленно FAIL, блокировать приёмку, вернуть DEV-2 на доработку.**

## Задача ARCH.3: Верификация S5R.3 (Real Positions T-Invest)

**DEV-3 обещал:** контракты C8, C9 + замена заглушек на реальные вызовы.

1. **Заглушки удалены:**
   ```bash
   grep -n "return \[\]" app/broker/router.py
   # Ожидание: НЕ найдено в endpoint'ах positions/operations
   grep -n "return {\"items\": \[\], \"total\": 0}" app/broker/router.py
   # Ожидание: НЕ найдено
   ```

2. **Integration grep:**
   ```bash
   grep -rn "portfolio_position_to_broker_position" app/broker/
   # Ожидание: определение в mapper.py + вызов в adapter.py

   grep -rn "operation_to_broker_operation" app/broker/
   # Ожидание: определение в mapper.py + вызов в adapter.py

   grep -rn "\.get_positions(" app/broker/
   # Ожидание: определение в service.py + вызов в router.py
   ```

3. **C8 — endpoint positions:**
   ```bash
   pytest tests/broker/test_broker_router_positions.py -v
   # Ожидание: GET /api/v1/broker/accounts/1/positions → 200 + list с полями ticker, source, currency
   ```

4. **C9 — endpoint operations:**
   ```bash
   pytest tests/broker/test_broker_router_operations.py -v
   # Ожидание: с query from/to/offset/limit → 200 + {items, total}
   ```

5. **Gotcha 1 (Decimal → str):**
   Прочитать `BrokerPositionResponse` / `BrokerOperationResponse` — должны иметь `@field_serializer` для Decimal полей.

6. **Frontend:**
   ```bash
   grep -n "source" Develop/frontend/src/components/account/PositionsTable.tsx
   # Ожидание: колонка source рендерится как Badge
   ```

**Вердикт по S5R.3:** PASS / PASS WITH NOTES / FAIL.

## Задача ARCH.4: Верификация S5R.4 (E2E S4 fix)

1. **Полный прогон:**
   ```bash
   cd Develop/frontend && npx playwright test --reporter=list
   # Ожидание: X passed, 0 failed, K skipped (с аннотацией)
   ```

2. **Не-spec файлы:**
   ```bash
   ls Develop/frontend/e2e/test-backtest-*.ts Develop/frontend/e2e/test-lkoh-*.ts 2>/dev/null
   # Ожидание: НЕ найдено в корне e2e/ (перемещены в helpers/ или удалены)
   ```

3. **Отчёт DEV-1 содержит число:** «X тестов прогоняется, Y passing, Z skipped» — должно быть конкретное число, не «примерно 30».

**Вердикт по S5R.4:** PASS / PASS WITH NOTES / FAIL.

## Задача ARCH.5: Оценка эффективности нового процесса работы DEV-субагентов (S5R.5)

Это **первое практическое применение** принятых 2026-04-14 правил:
- `prompt_template.md` (11 секций)
- Stack Gotchas в `Develop/CLAUDE.md`
- Integration Verification Checklist
- Cross-DEV contracts
- Формат отчёта до 400 слов / 8 секций

**Оценочные критерии:**

| # | Критерий | Источник | Оценка |
|---|----------|----------|--------|
| 1 | Все 3 DEV использовали `prompt_template.md` как основу | prompt_DEV-*.md существуют и содержат все 11 секций | PASS/FAIL |
| 2 | Все 3 DEV в отчёте ссылаются на Stack Gotchas | секция 7 отчётов | PASS/FAIL |
| 3 | Все 3 DEV прошли Integration Verification | секция 4 отчётов + твой повторный grep | PASS/FAIL |
| 4 | Cross-DEV contracts подтверждены обеими сторонами (поставщик + потребитель) | секция 5 отчётов | PASS/FAIL |
| 5 | Отчёты соответствуют формату (≤ 400 слов, 8 секций) | визуальная проверка | PASS/FAIL |
| 6 | Ни один DEV не вернул `⚠️ NOT CONNECTED` после сдачи | секция 4 отчётов | PASS/FAIL |
| 7 | Обнаружены ли новые Stack Gotchas? | секция 8 отчётов | количество |

**Findings & рекомендации:**

Напиши свободным текстом (до 500 слов в `arch_review_s5r.md` раздел «Оценка эффективности нового процесса»):

1. **Что сработало хорошо:** какие секции `prompt_template.md` были реально полезны, сэкономили ли время, предотвратили ли баги
2. **Что не сработало:** какие секции оказались избыточными или непонятными, где DEV-агенты спотыкались
3. **Доработки перед Sprint 6:**
   - Изменения в `prompt_template.md` (если нужны)
   - Новые Stack Gotchas в `Develop/CLAUDE.md` (если обнаружены)
   - Уточнения в корневом `CLAUDE.md` разделе «Работа с DEV-субагентами в спринтах»
   - Изменения в формате отчёта
4. **Оценка по шкале «готовы ли запускать Sprint 6 с этими правилами»:** готовы / готовы с доработками / нет, нужна вторая итерация обкатки

## Задача ARCH.6: Актуализация ФТ/ТЗ (S5R.6)

### `Документация по проекту/functional_requirements.md`

**Раздел 6 (Торговля):**
- Добавить подраздел «Таймфрейм торговой сессии»: обязательное поле при запуске, список поддерживаемых TF (1m/5m/15m/1h/4h/D/W), стратегия реагирует на **закрытие бара** этого TF
- Уточнить, что стратегия получает **скользящее окно** последних N свечей (N = 200 по умолчанию), а не одну свечу

**Раздел 7.3 (Счёт):**
- Уточнить: позиции различаются на **strategy** (открытые нашими сессиями) и **external** (куплено вручную через приложение брокера) — отразить, что UI показывает badge `source`
- Multi-currency: балансы и позиции поддерживают RUB/USD/EUR/HKD/CNY без автоконвертации
- Операции: типы `BUY/SELL/DIVIDEND/COUPON/COMMISSION/TAX/OTHER`, фильтр по датам + пагинация

**Раздел 7.3 дополнительно:** упомянуть S5 новые фичи, если не упомянуты:
- Bond НКД (накопленный купонный доход)
- Налоговый отчёт FIFO
- Избранные инструменты (Favorites)

**Раздел 12.4 (Circuit Breaker):**
- Уточнить, что `daily_loss` считается на **закрытии свечи TF** (через `SessionRuntime._handle_candle`), а не на каждый тик

### `Документация по проекту/technical_specification.md`

**Раздел 5.4 (Trading Engine):**
- **5.4.2** — добавить описание `SessionRuntime` как основного класса, замыкающего цикл. Показать диаграмму listener → event_bus → SignalProcessor → CircuitBreaker → OrderManager → place_order.
- Указать, что стратегия получает `candles: list[dict]` (скользящее окно) и алиасы `candle_open/high/low/close/volume` для обратной совместимости.
- **5.4.3** — уточнить, что recovery при старте backend **в S5R** реализован только для paper-сессий (подписка). Real-часть (сверка позиций) — задача 6.4 Sprint 6.

**Раздел 5.6.5 (BondService):** подтвердить, что реализация S5 (НКД, купоны) совпадает со спецификацией.

**Раздел 5.13 (Tax Report):** подтвердить, что реализация S5 (FIFO + xlsx экспорт) совпадает со спецификацией.

**Раздел 5.14 или новый (Market Data Stream):** описать `StreamManager` с reconnect, мультиплексированием подписок, `_TIMEFRAME_TO_INTERVAL`.

**Раздел 6.6 (Trading Panel):** обновить UI-описание — селект таймфрейма в форме запуска, вывод TF на карточке сессии.

**Раздел 6.7 (Account Screen):** добавить multi-currency, source badge, пагинацию operations, фильтр по датам.

**Раздел 5.3 или новый (Frontend helpers):** упомянуть новые технические решения:
- `TickerLogo` с CDN (fallback к буквам при ошибке)
- `StreamManager` с reconnect (backend)
- `recentInstruments` утилита (localStorage последних тикеров)
- `toNum` helper (парсинг Decimal → number)

### `Документация по проекту/development_plan.md`

- Отметить S5R как завершённый
- Убрать упоминания 6.0 и 6.9 (они закрыты в S5R) — если ещё есть
- Подтвердить, что S6 стартует с зелёным CI, замкнутым runtime, реальными позициями

### `Спринты/ui_checklist_s4_review.md` (или создать `ui_checklist_s5r.md`)

Добавить проверки:
- [ ] Форма запуска торговой сессии содержит селектор таймфрейма
- [ ] На карточке сессии отображается таймфрейм (или прочерк для старых)
- [ ] Позиции в разделе «Счёт» имеют badge source: «Стратегия» / «Внешняя»
- [ ] Operations table показывает реальные типы T-Invest с иконками
- [ ] Multi-currency в балансах/позициях без автоконвертации
- [ ] React 19 hooks rules не нарушены в новых компонентах (InstrumentChart, TickerLogo, BacktestLaunchModal, PositionsTable, BacktestTrades, Sidebar)

## Задача ARCH.7: Создать `arch_review_s5r.md`

Файл: `Спринты/Sprint_5_Review/arch_review_s5r.md`

Структура:

```markdown
# Sprint_5_Review — Финальное архитектурное ревью

**Дата:** 2026-04-NN
**Ревьюер:** ARCH
**Статус:** PASS / PASS WITH NOTES / FAIL
**Охватывает:** S5R.1, S5R.2, S5R.3, S5R.4, S5R.5 (процесс), S5R.6 (ФТ/ТЗ)

## 1. Baseline «до/после»

| Метрика | До S5R (14.04) | После S5R (NN.04) |
|---------|----------------|-------------------|
| CI состояние | ❌ All jobs failed (11 дней) | ✅ completed success |
| backend ruff | ❌ ~14 × F401 | ✅ 0 errors |
| backend mypy | ? не запускался | ✅/⚠️ X errors |
| backend pytest | ? не запускался | ✅ X/X passed |
| frontend eslint | ❌ 40+ errors | ✅ 0 errors |
| frontend tsc | ? не запускался | ✅ 0 errors |
| frontend vitest | ? не запускался | ✅ X/X passed |
| Playwright S4 тесты | ❌ 30+ падающих | ✅ Y passing, Z skipped |
| SignalProcessor.process_candle вызов в production | ❌ NOT CONNECTED | ✅ CONNECTED |
| TradingSession.timeframe | ❌ поля нет | ✅ nullable |
| T-Invest positions endpoint | ❌ заглушка `return []` | ✅ реальные данные |
| T-Invest operations endpoint | ❌ заглушка `return {...}` | ✅ реальные данные |
| Техдолг (High) | 4 (CI + E2E + Runtime + Positions) | 0 |

## 2. Верификация по задачам

### S5R.1 CI Cleanup — <PASS / PASS WITH NOTES / FAIL>
(детали из задачи ARCH.1)

### S5R.2 Live Runtime Loop — <PASS / PASS WITH NOTES / FAIL>
(детали из задачи ARCH.2)

### S5R.3 Real Positions T-Invest — <PASS / PASS WITH NOTES / FAIL>
(детали из задачи ARCH.3)

### S5R.4 E2E S4 Fix — <PASS / PASS WITH NOTES / FAIL>
(детали из задачи ARCH.4)

## 3. Cross-DEV contracts — сводная таблица

| # | Контракт | Поставщик | Потребитель | Статус | Комментарий |
|---|----------|-----------|-------------|--------|-------------|
| C1 | ruff green | DEV-1 | DEV-1, DEV-2, DEV-3 | ✅ | pyproject.toml L<N> |
| ... | ... | ... | ... | ... | ... |
| C11 | arch_review_s5r.md | ARCH | Оркестратор | ✅ | этот файл |

## 4. Оценка эффективности нового процесса работы DEV-субагентов (S5R.5)

(из задачи ARCH.5 — до 500 слов)

## 5. Обновления ФТ/ТЗ (S5R.6)

Перечислить все изменённые разделы:
- functional_requirements.md: 6, 7.3, 7.7, 12.4
- technical_specification.md: 5.4.2, 5.4.3, 5.6.5, 5.13, 6.6, 6.7
- development_plan.md: раздел S5R
- ui_checklist: новые проверки

## 6. Новые Stack Gotchas (если обнаружены)

Если DEV-отчёты выявили новые ловушки стека — описать здесь и добавить в `Develop/CLAUDE.md`.

## 7. Рекомендации для Sprint 6

- С какого состояния стартует S6 (baseline)
- Какие задачи S6 стали проще благодаря S5R (6.3, 6.4, 6.5)
- Какие риски остались (например, Graceful Shutdown S6 будет первым тестом того, что SessionRuntime.stop корректно обрабатывает массовую отписку)
- Обновления процессных правил перед S6 (если есть)

## 8. Вердикт

**Статус:** PASS / PASS WITH NOTES / FAIL

**Блокеры для Sprint 6:** <список или «отсутствуют»>

**Подпись:** ARCH, 2026-04-NN
```

## Задача ARCH.8: Финализация состояния проекта

После того, как `arch_review_s5r.md` сдан с PASS / PASS WITH NOTES:

1. **`Спринты/project_state.md`:**
   - S5R → ✅ завершён
   - Таблица техдолга — убрать пункты 2, 3, 4, 5 (они закрыты S5R)
   - «Текущий спринт:» → `Sprint 6 — Уведомления (⬜ готов к старту)`
   - «ТЕКУЩЕЕ ДЕЙСТВИЕ» → «Sprint 6 — стартовать с зелёного CI, замкнутого runtime, реальных позиций»

2. **`Спринты/Sprint_5/sprint_state.md`:**
   - Финальная пометка: «S5R завершён NN.04.2026, все техдолги S5 закрыты, M3 Paper Trading полный scope»

3. **`Спринты/Sprint_5_Review/changelog.md`** — лог выполнения задач S5R (если ещё не ведётся)

4. **Коммиты:**
   - Отдельный коммит в `moex-terminal` с обновлённым `Develop/CLAUDE.md` (новые Stack Gotchas, если есть)
   - Отдельный коммит в `test` с обновлёнными ФТ/ТЗ/планом и `arch_review_s5r.md`
   - **НЕ пушить автоматически** — только по подтверждению оркестратора

# Тесты

Ты не пишешь новый код — но **обязан** самостоятельно прогнать все тесты:

```bash
cd Develop/backend
ruff check .
mypy app/ --ignore-missing-imports
pytest tests/ -v

cd Develop/frontend
pnpm lint
pnpm tsc --noEmit
pnpm test
npx playwright test
```

Все должны быть зелёные. Если что-то красное — это **блокер** сдачи DEV-работы, не ревью. Вернуть на доработку.

# ⚠️ Integration Verification Checklist

Для ARCH-ревью Integration Verification — это **повторная проверка** того, что DEV-агенты заявили в своих отчётах. Ты делаешь grep'ы сам, не веришь на слово.

Все grep'ы уже описаны в задачах ARCH.1-ARCH.4. **Критичный пункт:**

- [ ] `grep -rn "process_candle(" app/` возвращает **production-вызов** из `runtime.py`, а не только `engine.py` (определение) и `tests/`. Если нет — **FAIL немедленно**, блокировать приёмку S5R.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Итоговый вывод ARCH — **`arch_review_s5r.md`** по структуре из задачи ARCH.7. Плюс в финальном ответе оркестратору — короткая сводка до 400 слов:

```markdown
## ARCH отчёт — Sprint_5_Review, финальное ревью

### 1. Вердикт
- S5R.1: <PASS / PASS WITH NOTES / FAIL>
- S5R.2: <...>
- S5R.3: <...>
- S5R.4: <...>
- S5R.5 (процесс): <...>
- S5R.6 (ФТ/ТЗ): <...>
- **Общий:** PASS / PASS WITH NOTES / FAIL

### 2. Baseline до/после
- CI: ❌ → ✅
- process_candle в production: NOT CONNECTED → CONNECTED
- Техдолг High: 4 → 0

### 3. Проверенные контракты
- C1-C11: все подтверждены (или FAIL с указанием)

### 4. Новые Stack Gotchas
- <список или «нет»> — добавлены в `Develop/CLAUDE.md`

### 5. Обновления ФТ/ТЗ
- functional_requirements.md: разделы <...>
- technical_specification.md: разделы <...>
- development_plan.md: S5R
- ui_checklist: <...>

### 6. Оценка нового процесса (краткое резюме S5R.5)
- Что сработало: <...>
- Что доработать перед S6: <...>
- Готовность запускать S6: да / да с доработками / нет

### 7. Блокеры для Sprint 6
- <список или «отсутствуют»>

### 8. Поставленные контракты
- **C11** (arch_review_s5r.md): создан по формату, вердикт <...> — подтверждено
```

# Alembic-миграция (если применимо)

**Не применимо** — ARCH не создаёт миграций. Проверяет, что DEV-2 применил свою (`add_timeframe_to_trading_sessions`).

# Чеклист перед сдачей

- [ ] Все 3 DEV-отчёта получены и прочитаны
- [ ] Все Cross-DEV contracts C1-C10 верифицированы самостоятельно (не «поверил отчёту»)
- [ ] **`grep -rn "process_candle(" app/` показывает production-вызов** — главная проверка
- [ ] Все тесты зелёные локально (ruff/mypy/pytest/eslint/tsc/vitest/playwright)
- [ ] CI на GitHub зелёный (`gh run list`)
- [ ] `functional_requirements.md` обновлён (разделы 6, 7.3, 7.7, 12.4)
- [ ] `technical_specification.md` обновлён (разделы 5.4.2, 5.4.3, 5.6.5, 5.13, 6.6, 6.7)
- [ ] `development_plan.md` обновлён
- [ ] `ui_checklist_*.md` обновлён
- [ ] `Develop/CLAUDE.md` дополнен новыми Stack Gotchas (если обнаружены)
- [ ] `arch_review_s5r.md` создан по формату
- [ ] `project_state.md` — статус S5R ✅, S6 ⬜ готов к старту, техдолг очищен
- [ ] `Sprint_5/sprint_state.md` — финальная пометка про S5R
- [ ] `Спринты/Sprint_5_Review/changelog.md` — лог выполнения
- [ ] **Формат отчёта соблюдён** — 8 секций, ≤ 400 слов (плюс полный `arch_review_s5r.md`)
- [ ] **Контракт C11 поставлен** — `arch_review_s5r.md` с вердиктом
- [ ] Коммиты подготовлены (по одному в каждое репо), но **не запушены** — ждём подтверждения оркестратора
