# [Sprint_5_Review] Live Runtime Loop: замкнуть цикл «стрим свечей → стратегия → ордер»

> Задача перенесена из Sprint 6 → Sprint_5_Review при открытии внепланового ревью 2026-04-14.
> **Исходно:** техдолг #4 High из S5, обнаружено при ретроспективе S5 (несоответствие ТЗ vs фактическая реализация).
> **Приоритет:** 🔴 Блокер для S6.

В Sprint 5 реализованы все компоненты Trading Engine (`TradingSessionManager`, `SignalProcessor`, `OrderManager`, `PaperBrokerAdapter`, `CircuitBreaker`), но **runtime-цикл live-торговли не замкнут**: `SignalProcessor.process_candle()` нигде в production-коде не вызывается. Архитектура в ТЗ описана ([technical_specification.md:1396-1417](../../Документация%20по%20проекту/technical_specification.md)), но не реализована.

## Контекст

В Sprint 5 построены все «кирпичи» live-торговли:

| Компонент | Путь | Статус |
|-----------|------|--------|
| Создание сессии в БД | [trading/engine.py:72-149](../../Develop/backend/app/trading/engine.py#L72-L149) | ✅ работает |
| Подписка на стрим свечей | [market_data/stream_manager.py](../../Develop/backend/app/market_data/stream_manager.py) | ✅ с параметром `timeframe` |
| `SignalProcessor.process_candle()` | [trading/engine.py:246-360](../../Develop/backend/app/trading/engine.py#L246-L360) | ⚠️ код есть, но stateless и не вызывается |
| `OrderManager.process_signal()` | [trading/engine.py:366+](../../Develop/backend/app/trading/engine.py#L366) | ✅ работает (вызывается в тестах вручную) |
| Circuit Breaker, Paper Portfolio, Tax, Bond НКД | различные модули | ✅ реализованы |
| **Связь «стрим → SignalProcessor → OrderManager»** | — | ❌ **отсутствует** |
| **`TradingSession.timeframe`** | [trading/models.py:20-47](../../Develop/backend/app/trading/models.py#L20-L47) | ❌ поля нет |
| **Scheduler для live-сессий** | [scheduler/service.py](../../Develop/backend/app/scheduler/service.py) | ❌ файл пуст (одна строка-комментарий) |
| **Выбор таймфрейма в форме запуска** | [frontend/.../LaunchSessionModal.tsx](../../Develop/frontend/src/components/trading/LaunchSessionModal.tsx) | ❌ селектора нет |

Как следствие:
1. После `start_session()` никто не подписывается на маркет-стрим и не дёргает `SignalProcessor`.
2. Даже если бы дёргал — `process_candle(session, candle)` получает **одну свечу** без истории (см. [engine.py:318-344](../../Develop/backend/app/trading/engine.py#L318-L344): стратегия получает только `candle_open/high/low/close/volume` одной свечи). Для индикаторов (MA, RSI, …) нужно скользящее окно последних N свечей.
3. Сессия не знает свой таймфрейм — непонятно, на какой период подписываться и какую историю хранить.

**Симптом, с которого обнаружилось:** заказчик попросил «вывести таймфрейм в списке торговых сессий», и оказалось, что поля нет нигде по стеку.

**Почему ARCH-ревью S5 этого не поймал:** в [arch_review_s5.md:37](../Sprint_5/arch_review_s5.md) отмечено `| SignalProcessor.process_candle | ✅ | Sandbox execution, кеш стратегий, < 500ms (sandbox timeout=5s) |` — это проверка класса как такового, но не интеграции в runtime. Grep по `process_candle(` в production-коде даёт только определение метода. Это корневая причина, из-за которой в `prompt_template.md` появился обязательный раздел «Integration Verification Checklist» — см. `Спринты/prompt_template.md`.

## Архитектура из ТЗ (что должно быть)

Согласно [technical_specification.md:1396-1417](../../Документация%20по%20проекту/technical_specification.md) цикл выглядит так:

```
MarketDataService → новая свеча (закрытие бара TF)
    ↓
SignalProcessor.process_candle(session, candle, history)
    ↓ (загрузка стратегии в sandbox, расчёт индикаторов по history)
    ↓
signal: BUY / SELL / HOLD
    ↓
CircuitBreaker.check(session, signal)
    ↓
OrderManager.process_signal(session, signal)
    ↓
BrokerAdapter.place_order(order)
```

Требование по latency из ТЗ (1417): `Весь путь от получения свечи до BrokerAdapter.place_order() < 500ms`.

## Что нужно сделать

### 1. Backend: добавить `timeframe` в модель сессии

1. **Модель** `TradingSession.timeframe: Mapped[str] = mapped_column(String(10), nullable=True)` — nullable для совместимости со старыми записями в БД. См. [trading/models.py:20-47](../../Develop/backend/app/trading/models.py#L20-L47).
2. **Alembic миграция** `add_timeframe_to_trading_sessions` — ADD COLUMN с nullable=True, без default (существующие записи остаются с NULL и помечаются как «без таймфрейма»).
3. **Схемы** ([trading/schemas.py](../../Develop/backend/app/trading/schemas.py)):
   - `SessionStartRequest.timeframe: Literal["1m","5m","15m","1h","4h","D","W","M"]` — обязательное поле
   - `SessionResponse.timeframe: str | None`
4. **`SessionStartParams`** ([trading/engine.py:48-60](../../Develop/backend/app/trading/engine.py#L48-L60)) — добавить `timeframe: str` и прокинуть в модель при создании.
5. **Валидация в сервисе**: `SessionStartRequest.timeframe` должен быть из списка поддерживаемых стрим-менеджером. См. `_TIMEFRAME_TO_INTERVAL` в [stream_manager.py](../../Develop/backend/app/market_data/stream_manager.py).

### 2. Backend: runtime-loop (главное)

Создать новый модуль `app/trading/runtime.py` с классом `SessionRuntime` (или интегрировать в `TradingSessionManager`):

6. **`SessionRuntime.start(session)`** — запускается после `start_session()`:
   - Получает или создаёт подписку через `MarketDataStreamManager.subscribe(ticker, timeframe)`.
   - Регистрирует listener в `event_bus` на канал `market:{ticker}:{timeframe}`.
   - Listener при получении закрытой свечи:
     1. Загружает «скользящее окно» последних N свечей того же `(ticker, timeframe)` из кеша OHLCV (N — параметр, по умолчанию 200; должен покрывать максимальный период индикатора в стратегии).
     2. Вызывает `SignalProcessor.process_candle(session, candle, history)` с **историей**, а не одной свечой.
     3. Если получен `Signal`, передаёт в `OrderManager.process_signal(session, signal, user_id)`.
     4. Проверяет latency < 500ms, логирует превышения.
7. **`SessionRuntime.stop(session_id)`** — вызывается из `stop_session` / `pause_session`: отменяет listener, отписывается от стрима (если других сессий на том же `(ticker, tf)` нет).
8. **Восстановление** — интегрировать с задачей 6.4 Sprint 6 «Восстановление после перезапуска»: при старте backend вызвать `restore_sessions()` из [trading/engine.py](../../Develop/backend/app/trading/engine.py), для каждой `active/paused` сессии поднять `SessionRuntime` заново. **Примечание:** в S5R реализуется интеграционная точка (метод `restore_sessions` уже есть в S5), в S6 задача 6.4 добавляет сверку с брокером для real-сессий.

### 3. Backend: переделать `SignalProcessor._execute_strategy`

9. Сменить сигнатуру: принимать не одну `candle: CandleData`, а **список свечей** `history: list[CandleData]` + `current_candle: CandleData`. См. текущую реализацию [engine.py:318-360](../../Develop/backend/app/trading/engine.py#L318-L360).
10. В namespace sandbox пробрасывать:
    - `candles: list[dict]` (или pandas DataFrame) — последние N свечей
    - `candle: dict` — текущая закрытая свеча (алиас на `candles[-1]`)
    - `ticker: str`
    - `position: dict | None` — текущая открытая позиция, если есть
11. Пересмотреть формат контракта стратегии: переменная `signal` должна содержать `"buy"/"sell"/"hold"` (остаётся как есть), но теперь код стратегии может использовать `candles` для расчёта индикаторов.
12. Совместимость: если старый код стратегии использует `candle_close`/`candle_open` — оставить их как алиасы на поля `candle` для обратной совместимости.
13. **Внимание — Stack Gotcha 2:** не писать `import` в сгенерированном коде стратегии (см. `Develop/CLAUDE.md` секция Stack Gotchas). Nеобходимые модули (`bt`, `datetime`, `math`, `Decimal`) — в namespace через `_compile_strategy`.

### 4. Frontend: выбор таймфрейма в форме запуска

14. **`LaunchSessionModal`** ([frontend/.../LaunchSessionModal.tsx](../../Develop/frontend/src/components/trading/LaunchSessionModal.tsx)) — добавить `<Select>` «Таймфрейм» с опциями `1m, 5m, 15m, 1h, 4h, D, W` (как в форме запуска бэктеста — см. [BacktestLaunchModal.tsx](../../Develop/frontend/src/components/backtest/BacktestLaunchModal.tsx)). Обязательное поле, дефолт `1h` или `D` (согласовать с заказчиком).
15. **TypeScript тип** `SessionStartRequest.timeframe` и `TradingSession.timeframe` в [api/types.ts](../../Develop/frontend/src/api/types.ts).

### 5. Frontend: вывод таймфрейма в списке сессий

16. **`SessionCard`** ([frontend/.../SessionCard.tsx](../../Develop/frontend/src/components/trading/SessionCard.tsx)) — добавить отображение `timeframe` рядом с тикером / mode-badge. Для старых сессий (`timeframe === null`) показывать `—`.
17. **`SessionList`** — учесть новое поле в заголовке/фильтрах, если уместно.
18. **Фильтр по TF в списке сессий** (опционально) — добавить SegmentedControl для быстрой фильтрации активных сессий по TF.

### 6. Обработка ошибок стрима и деградации

19. Разрыв стрима: listener должен автоматически пере-подписаться (логика есть в `stream_manager`, нужно убедиться что `SessionRuntime` не теряет подписку при reconnect).
20. Отсутствие истории в OHLCV-кеше: если `history.length < required_lookback`, стратегия не вызывается, в логи пишется `insufficient_history` и в `DailyStat` фиксируется счётчик пропущенных свечей.
21. Таймаут выполнения стратегии (> 500ms) — логируется как warning, не блокирует следующую свечу.

### 7. Тесты

22. **Unit** на `SessionRuntime`:
    - `start` → подписка на правильный канал
    - `stop` → отписка и удаление listener
    - получение свечи → вызов `SignalProcessor` → вызов `OrderManager`
    - разрыв стрима → переподписка
23. **Unit** на обновлённый `SignalProcessor._execute_strategy` — стратегия видит `candles` и вычисляет индикатор.
24. **Integration** «end-to-end от fake-стрима до ордера»: фейк MarketDataService эмитит последовательность свечей → поднимается сессия → проверяем появление `LiveTrade` в БД.
25. **E2E**: запустить paper-сессию на `SBER` + `1h` → симулировать публикацию свечей в event_bus → проверить, что сессия реагирует и появляется сделка в списке.
26. Обновить существующие тесты `test_order_manager.py`, `test_circuit_breaker/test_integration.py` — они используют ручное создание `Signal`, проверить, что это всё ещё работает.
27. **Integration Verification (из `prompt_template.md`):**
    - `grep -rn "process_candle(" app/` → результат показывает **не только** `engine.py:253` и тесты, но и `runtime.py` (production вызов)
    - `grep -rn "SessionRuntime(" app/` → `service.py` или `trading/__init__.py` (инстанциирование)
    - `grep -rn "event_bus.subscribe" app/trading/` → `runtime.py` с каналом `market:{ticker}:{tf}`

### 8. Документация

28. **ФТ** ([functional_requirements.md:362+](../../Документация%20по%20проекту/functional_requirements.md)) — уточнить, что сессия запускается на конкретном таймфрейме и что стратегия реагирует на закрытие баров этого TF.
29. **ТЗ** ([technical_specification.md:1396+](../../Документация%20по%20проекту/technical_specification.md)) — дополнить архитектурной схемой `SessionRuntime`, правилами ведения истории и обработки разрывов стрима.
30. **План развития** — снять задачу из техдолга `project_state.md#4` после готовности.

## Файлы, которые затронет задача

| Файл | Изменение |
|------|-----------|
| `Develop/backend/app/trading/models.py` | `TradingSession.timeframe` |
| `Develop/backend/alembic/versions/XXXX_add_timeframe.py` | Новая миграция |
| `Develop/backend/app/trading/schemas.py` | `SessionStartRequest.timeframe`, `SessionResponse.timeframe` |
| `Develop/backend/app/trading/engine.py` | `SessionStartParams.timeframe`, `start_session` прокидывает TF, `SignalProcessor._execute_strategy` принимает `history` |
| `Develop/backend/app/trading/runtime.py` | **Новый модуль** `SessionRuntime` (listener + стрим ↔ сессия) |
| `Develop/backend/app/trading/service.py` | Интеграция с `SessionRuntime.start/stop` |
| `Develop/backend/app/scheduler/service.py` | Recovery сессий при старте backend (или в `main.py` lifespan) |
| `Develop/backend/tests/test_trading/test_runtime.py` | Новый файл тестов |
| `Develop/backend/tests/test_trading/test_order_manager.py` | Актуализация под новый контракт |
| `Develop/frontend/src/api/types.ts` | `timeframe` в `SessionStartRequest` и `TradingSession` |
| `Develop/frontend/src/components/trading/LaunchSessionModal.tsx` | Селект «Таймфрейм» |
| `Develop/frontend/src/components/trading/SessionCard.tsx` | Вывод TF на карточке |
| `Develop/frontend/src/components/trading/SessionList.tsx` | Возможный фильтр по TF |
| `Develop/frontend/e2e/s5r-live-runtime.spec.ts` | Новый E2E |

## Связь с другими задачами

### Внутри Sprint_5_Review

| Задача | Связь |
|--------|-------|
| **Задача 1** CI cleanup | Предусловие — без зелёного CI integration verification работает только частично |
| **Задача 4** E2E S4 fix | Предусловие — без работающего Playwright baseline новый E2E «fake-стрим → сделка» утонет в общем хаосе |
| **Задача 3** Реальные позиции T-Invest | Независима по файлам, можно параллелить |
| **Задача 6** Актуализация ФТ/ТЗ | Финальная — после реализации |

### С Sprint 6

| Задача S6 | Связь |
|-----------|-------|
| **6.3** In-app уведомления + Event Bus | `SessionRuntime` публикует события в event_bus — уведомления их получают |
| **6.4** Восстановление после перезапуска | Вызывает `SessionRuntime.start()` для каждой active/paused сессии после рестарта + добавляет сверку с брокером |
| **6.5** Graceful Shutdown | При shutdown вызывает `SessionRuntime.stop()` для всех активных сессий |

## Критерии готовности

- [ ] В БД у `TradingSession` есть поле `timeframe`, миграция применена.
- [ ] Форма запуска торговой сессии требует выбрать таймфрейм.
- [ ] На карточке сессии в списке отображается таймфрейм (для старых сессий — прочерк).
- [ ] После `start_session()` автоматически поднимается `SessionRuntime`, подписанный на `market:{ticker}:{timeframe}`.
- [ ] При публикации свечи закрытия в event_bus стратегия вызывается со **списком** последних N свечей и может корректно вычислять индикаторы.
- [ ] Сигнал `BUY`/`SELL` корректно проходит через `CircuitBreaker` → `OrderManager` → `LiveTrade` в БД.
- [ ] При `stop_session()` / `pause_session()` listener отписывается.
- [ ] При рестарте backend все active/paused сессии восстанавливают подписки (через `restore_sessions`).
- [ ] **Integration Verification (из `prompt_template.md`):** `grep -rn "process_candle(" app/` показывает вызов из `runtime.py`, а не только тесты. Cross-DEV contracts C4-C7 (из `execution_order.md`) подтверждены в отчёте.
- [ ] Интеграционный тест end-to-end: fake-стрим → сессия → ордер → запись в БД.
- [ ] E2E тест: запуск сессии, симуляция свечей, появление сделки в UI.
- [ ] Latency < 500ms от свечи до `place_order()` — залогировано и проверено.
- [ ] ФТ/ТЗ обновлены (в рамках задачи 6 S5R).
- [ ] Техдолг #4 в `project_state.md` снят.

## Риски

1. **Scope creep** — задача большая (runtime + история + sandbox-контракт). **Митигация:** чётко разделить с задачей 6.4 S6 (Recovery): в S5R делаем `SessionRuntime` и вызов `start/stop` из lifecycle-методов; в S6.4 добавляется сверка с брокером для real-сессий.
2. **Sandbox-контракт меняется** — старые сохранённые версии стратегий, которые используют `candle_close` и т.п., должны продолжать работать. **Митигация**: оставить алиасы `candle_open/high/low/close/volume` → поля `candle` для обратной совместимости.
3. **История в OHLCV-кеше** может быть неполной сразу после подписки на новый инструмент. **Митигация**: при `SessionRuntime.start` предварительно догрузить `N` последних свечей через `market_data_service.get_candles` (синхронно, до запуска listener'а).
4. **Производительность** при параллельных сессиях на одном тикере: listener'ов много, а подписка одна. **Митигация**: `MarketDataStreamManager` уже мультиплексирует подписки по `(ticker, tf)` — listener'ы подписываются на один event_bus канал.
5. **React 19 + новые правила eslint** могут сломать сборку frontend при добавлении Select-компонента, если он использует устаревшие паттерны. **Митигация:** задача 1 (CI cleanup) выполняется первой, включая адаптацию React 19 правил.

## Ссылки

- ТЗ, раздел Trading Engine: `Документация по проекту/technical_specification.md` (строки 1396-1417)
- ФТ, раздел Live Trading: `Документация по проекту/functional_requirements.md` (строки 362-363)
- ARCH-ревью S5: `Спринты/Sprint_5/arch_review_s5.md` (строка 37 — формальная приёмка SignalProcessor)
- Техдолг: `Спринты/project_state.md` пункт #4
- Смежная задача S5R: `Sprint_5_Review/PENDING_S5R_real_account_positions_operations.md`
- Stack Gotchas: `Develop/CLAUDE.md` раздел «⚠️ Stack Gotchas» — особенно Gotcha 2 (CodeSandbox __import__), Gotcha 4 (T-Invest gRPC streaming)
- Процессные правила: корневой `CLAUDE.md` раздел «Работа с DEV-субагентами в спринтах», `Спринты/prompt_template.md`
