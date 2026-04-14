---
sprint: 5_Review
agent: DEV-2
role: "Backend Senior + Frontend — Live Runtime Loop (S5R.2): замкнуть цикл «стрим свечей → SignalProcessor → OrderManager»"
wave: 2
depends_on: [DEV-1]
---

# Роль

Ты — **Senior backend + frontend**-разработчик S5R, отвечающий за самую крупную архитектурную задачу ревью — **замкнуть Live Runtime Loop**. В Sprint 5 все «кирпичи» live-торговли построены (`TradingSessionManager`, `SignalProcessor`, `OrderManager`, `CircuitBreaker`, `StreamManager`, `PaperBrokerAdapter`), но **runtime-цикл не соединён**: `SignalProcessor.process_candle()` нигде в production-коде не вызывается. Твоя задача — создать `SessionRuntime`, который:

1. Подписывается на `market:{ticker}:{timeframe}` через `event_bus`
2. На закрытии бара вызывает `SignalProcessor.process_candle(session, candles, current_candle)` **с историей**, а не одной свечой
3. Передаёт сигнал в `CircuitBreaker.check()` → `OrderManager.process_signal()`
4. Восстанавливается при рестарте backend

Плюс: добавить `TradingSession.timeframe` (модель + миграция + UI-селектор + отображение).

Ты — **поставщик** контрактов **C4, C5, C6, C7** из [execution_order.md](execution_order.md). Без тебя Sprint 6 (задачи 6.3 in-app, 6.4 recovery, 6.5 graceful shutdown) **не может** стартовать.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Если хотя бы один пункт не выполнен — **НЕ начинай**, верни `БЛОКЕР: <описание>`.

```
1. Окружение: Python >= 3.11, Node >= 18, pnpm >= 9

2. Зависимости предыдущих DEV (S5R):
   - DEV-1 закрыл S5R.1 (CI cleanup): cd Develop/backend && ruff check . → exit 0
     И cd Develop/frontend && pnpm lint → exit 0
   - Cross-DEV contracts C1, C2, C3 подтверждены DEV-1

3. Существующие файлы:
   - Develop/backend/app/trading/models.py — TradingSession, LiveTrade, PaperPortfolio, DailyStat
   - Develop/backend/app/trading/engine.py — TradingSessionManager, SignalProcessor, OrderManager
   - Develop/backend/app/trading/service.py — сервис вокруг engine
   - Develop/backend/app/market_data/stream_manager.py — MarketDataStreamManager с подписками по (ticker, timeframe)
   - Develop/backend/app/common/event_bus.py — EventBus singleton
   - Develop/backend/app/scheduler/service.py — пустой файл (одна строка-комментарий)
   - Develop/backend/app/backtest/engine.py — _compile_strategy с safe_builtins (без __import__)
   - Develop/frontend/src/components/trading/LaunchSessionModal.tsx — форма запуска сессии
   - Develop/frontend/src/components/trading/SessionCard.tsx — карточка сессии в списке
   - Develop/frontend/src/api/types.ts — TypeScript типы API

4. База данных:
   - TradingSession в БД НЕ содержит поля timeframe (его нужно добавить)
   - SignalProcessor.process_candle уже реализован как метод, но НЕ вызывается в production

5. Внешние сервисы: не требуются (fake-стрим через event_bus)

6. Тесты baseline: pytest tests/ и pnpm test зелёные после S5R.1
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **[Develop/CLAUDE.md](../../Develop/CLAUDE.md)** — **полностью**, особое внимание **«⚠️ Stack Gotchas»**:
   - **Gotcha 2 (CodeSandbox: `__import__` вырезан)** — при переделке `_execute_strategy` под `candles: list[dict]` ты будешь менять namespace sandbox. В сгенерированном коде стратегии **нельзя** писать `import`. Все нужные модули (`bt`, `math`, `Decimal`, возможно `pandas`, если решишь) — прокидывать в namespace через `_compile_strategy`, **а не** через `import` в коде стратегии.
   - **Gotcha 1 (Pydantic v2 + Decimal → строка в JSON)** — при добавлении `timeframe` в `SessionResponse` убедись, что сериализация не ломает существующие Decimal-поля (`balance`, `equity`).
   - **Gotcha 4 (T-Invest gRPC streaming: persistent connection)** — `StreamManager` уже учитывает, но при добавлении timeframe-параметра в подписку проверь, что это не создаёт новую gRPC-сессию на каждый вызов.
   - **Gotcha 5 (Circuit Breaker: asyncio.Lock)** — в listener'е `SessionRuntime` вызов `CircuitBreaker.check()` должен быть защищён существующим lock'ом, не создавать новый.

2. **[Sprint_5_Review/PENDING_S5R_live_runtime_loop.md](PENDING_S5R_live_runtime_loop.md)** — **полный план** задачи: корневая причина, таблица статусов компонентов, 8 подразделов работ, критерии готовности.

3. **[Sprint_5_Review/execution_order.md](execution_order.md)** раздел **«Cross-DEV Contracts»**:
   - **Поставщик C4** — `TradingSession.timeframe: Mapped[str]` (nullable для старых записей), `SessionResponse.timeframe: str | None`, TS тип `TradingSession.timeframe?: string`.
   - **Поставщик C5** — `SessionStartRequest.timeframe: Literal["1m","5m","15m","1h","4h","D","W","M"]` — обязательное поле.
   - **Поставщик C6** — `SessionRuntime.start(session) -> None` и `SessionRuntime.stop(session_id) -> None`. Вызывается из `TradingSessionManager.start_session` после commit, из `stop_session`/`pause_session` перед commit, из `restore_sessions` при старте backend.
   - **Поставщик C7** — EventBus events из runtime: каналы `trades:{session_id}` с events `order.placed`, `trade.filled`, `trade.closed`, `session.started`, `session.stopped`, `cb.triggered`.

4. **Цитаты из ТЗ (дословно):**

   > **ТЗ 5.4.2 — «Поток обработки сигнала (Real)»:**
   > ```
   > MarketDataService → новая свеча
   >     ↓
   > SignalProcessor.process_candle(session, candle)
   >     ↓ (загрузка стратегии в sandbox, расчёт индикаторов, генерация сигнала)
   >     ↓
   > signal: BUY / SELL / HOLD
   >     ↓ (если BUY или SELL)
   > CircuitBreaker.check(session, signal)
   >     ↓ (OK)
   > OrderManager.place_order(session, signal)
   >     ↓
   > BrokerAdapter.place_order(order)
   >     ↓ (ордер отправлен)
   > PositionTracker.register_order(order)
   >     ↓
   > EventBus.publish("order.placed", ...)
   > ```

   > **ТЗ 5.4.2 — «Требование по latency» (дословно):**
   > «Весь путь от получения свечи до `BrokerAdapter.place_order()` < 500ms. Для этого: стратегия предзагружена в RAM, индикаторы обновляются инкрементально.»

   > **ТЗ 5.4.3 — «Восстановление при перезапуске» (дословно):**
   > «При старте `TradingSessionManager`:
   > 1. `SELECT * FROM trading_sessions WHERE status IN ('active', 'suspended')`
   > 2. Для каждой сессии:
   >    - Если mode = 'real': запросить позиции у брокера, сравнить с `live_trades WHERE status = 'filled' AND closed_at IS NULL`.
   >    - При расхождении: пауза + уведомление.
   >    - При совпадении: восстановить подписку на котировки, возобновить обработку сигналов.
   > 3. Уведомление пользователю через все каналы.»

   **Твоя зона ответственности в S5R.2 — только «paper» часть восстановления** (подписка + runtime). Сверка real-позиций с брокером — задача 6.4 Sprint 6 (надстраивается на твою).

5. **Корневой `CLAUDE.md` — правило Integration Verification:**
   > «Integration verification — каждый DEV обязан в отчёте подтвердить, что новые классы/методы вызываются в production-коде (`grep -rn "<ClassName>(" app/`), не только в тестах. Если точка вызова не найдена — явно пометить `⚠️ NOT CONNECTED` в отчёте. Такая пометка блокирует формальную приёмку.»

   **Это ключевое правило для твоей задачи.** Ретроспектива S5 зафиксировала: `SignalProcessor.process_candle()` был принят ARCH-ревью как класс, но не был интегрирован в runtime. Твоя задача — не повторить.

# Рабочая директория

- `Test/Develop/backend/app/trading/` (основная работа)
- `Test/Develop/backend/app/market_data/stream_manager.py` (интеграция с подпиской)
- `Test/Develop/backend/app/scheduler/service.py` (recovery при старте)
- `Test/Develop/backend/alembic/versions/` (новая миграция)
- `Test/Develop/backend/tests/test_trading/` (новые тесты)
- `Test/Develop/frontend/src/components/trading/` (LaunchSessionModal, SessionCard)
- `Test/Develop/frontend/src/api/types.ts`
- `Test/Develop/frontend/e2e/` (новый `s5r-live-runtime.spec.ts`)

# Контекст существующего кода

- `Develop/backend/app/trading/models.py:20-47` — `TradingSession` SQLAlchemy модель. **Нет** поля `timeframe`. Добавить `timeframe: Mapped[str | None] = mapped_column(String(10), nullable=True)`.
- `Develop/backend/app/trading/engine.py:48-60` — `SessionStartParams` dataclass. Добавить `timeframe: str`.
- `Develop/backend/app/trading/engine.py:72-149` — `TradingSessionManager.start_session`. Прокидывать `params.timeframe` при создании модели. После commit — **вызвать** `SessionRuntime.start(session)`.
- `Develop/backend/app/trading/engine.py:246-360` — `SignalProcessor.process_candle()`. **Код есть, принимается одна свеча, нигде не вызывается.** Поменять сигнатуру на `process_candle(session, candles: list[CandleData], user_id: int)` — где `candles[-1]` это текущая, а `candles[:-1]` это история.
- `Develop/backend/app/trading/engine.py:318-344` — `_execute_strategy` получает одну свечу и прокидывает `candle_open/high/low/close/volume` в namespace. **Переделать:** прокидывать `candles: list[dict]` (каждый dict — OHLCV + time), оставить `candle_open/...` как алиасы на последнюю свечу для обратной совместимости со старыми версиями стратегий.
- `Develop/backend/app/trading/engine.py:366+` — `OrderManager.process_signal`. Уже работает, но вызывается только в тестах. **Вызвать из `SessionRuntime`** после прохождения CircuitBreaker.
- `Develop/backend/app/market_data/stream_manager.py` — `MarketDataStreamManager` с методами `subscribe(ticker, timeframe, callback)`. Мультиплексирует подписки, один gRPC-стрим на `(ticker, timeframe)`. Словарь `_TIMEFRAME_TO_INTERVAL` содержит допустимые таймфреймы.
- `Develop/backend/app/common/event_bus.py` — `EventBus` singleton с `publish(channel, data)` и `subscribe(channel, callback)`. Каналы: `market:{ticker}:{tf}` (от StreamManager), `trades:{session_id}` (в SessionRuntime нужно публиковать).
- `Develop/backend/app/scheduler/service.py` — **пустой**, только комментарий. Сюда добавить recovery hook или использовать FastAPI lifespan в `main.py`.
- `Develop/backend/app/backtest/engine.py` — `_compile_strategy` с safe_builtins. **НЕ модифицировать**, но использовать как образец для namespace sandbox.
- `Develop/backend/app/trading/schemas.py` — Pydantic схемы. Добавить `timeframe` в `SessionStartRequest` (обязательно, Literal) и `SessionResponse` (nullable).
- `Develop/frontend/src/components/trading/LaunchSessionModal.tsx` — форма запуска. Нет селекта TF. Добавить `<Select>` по примеру `BacktestLaunchModal.tsx`.
- `Develop/frontend/src/components/trading/SessionCard.tsx` — карточка сессии. Добавить вывод `timeframe` рядом с тикером. Для старых сессий (null) — `—`.
- `Develop/frontend/src/api/types.ts` — TypeScript типы. Добавить `timeframe` в `SessionStartRequest` и `TradingSession`.

# Задачи

## Задача 2.1: Модель `TradingSession.timeframe` + миграция

В `app/trading/models.py` добавить поле:

```python
class TradingSession(Base):
    __tablename__ = "trading_sessions"
    # ... existing fields
    timeframe: Mapped[str | None] = mapped_column(String(10), nullable=True)
```

**Миграция:**
```bash
cd Develop/backend
alembic revision --autogenerate -m "add_timeframe_to_trading_sessions"
alembic upgrade head
alembic downgrade -1
alembic upgrade head  # проверка идемпотентности
```

**Важно:** `nullable=True` без default — существующие записи остаются с NULL (старые сессии «без таймфрейма»). Новые сессии обязаны указать TF (валидация на уровне Pydantic `SessionStartRequest`).

## Задача 2.2: Pydantic schemas

В `app/trading/schemas.py`:

```python
from typing import Literal

SupportedTimeframe = Literal["1m", "5m", "15m", "1h", "4h", "D", "W", "M"]

class SessionStartRequest(BaseModel):
    # ... existing fields
    timeframe: SupportedTimeframe  # обязательное

class SessionResponse(BaseModel):
    # ... existing fields
    timeframe: str | None = None
```

**Важно:** `Literal` даёт автоматическую валидацию Pydantic — неправильный TF возвращает 422.

## Задача 2.3: `SessionStartParams` + `start_session` прокидывают TF

В `app/trading/engine.py`:

```python
@dataclass
class SessionStartParams:
    user_id: int
    strategy_id: int
    ticker: str
    mode: Literal["paper", "real"]
    initial_capital: Decimal
    account_id: int | None
    timeframe: str  # NEW — обязательное

class TradingSessionManager:
    async def start_session(self, params: SessionStartParams) -> TradingSession:
        # ... create TradingSession with timeframe
        session = TradingSession(
            user_id=params.user_id,
            strategy_id=params.strategy_id,
            ticker=params.ticker,
            mode=params.mode,
            timeframe=params.timeframe,  # NEW
            # ...
        )
        self.db.add(session)
        await self.db.commit()
        await self.db.refresh(session)

        # NEW — запустить runtime
        await self.runtime.start(session)

        return session
```

**Внимание:** `self.runtime` — новый инстанс `SessionRuntime`, создаётся при инициализации `TradingSessionManager`. См. задачу 2.4.

## Задача 2.4: `SessionRuntime` в новом модуле `app/trading/runtime.py`

Создать **новый** файл `Develop/backend/app/trading/runtime.py`:

```python
from __future__ import annotations
import asyncio
import logging
import time
from typing import Any

from app.common.event_bus import EventBus
from app.market_data.stream_manager import MarketDataStreamManager
from app.market_data.service import MarketDataService
from app.trading.engine import SignalProcessor, OrderManager
from app.circuit_breaker.service import CircuitBreaker
from app.trading.models import TradingSession

logger = logging.getLogger(__name__)


class SessionRuntime:
    """Замыкает цикл: стрим свечей → стратегия → сигнал → ордер.

    По одному listener'у на сессию. Мультиплексирование подписок (один gRPC-стрим
    на (ticker, tf) независимо от числа сессий) — ответственность MarketDataStreamManager.
    """

    def __init__(
        self,
        signal_processor: SignalProcessor,
        order_manager: OrderManager,
        circuit_breaker: CircuitBreaker,
        stream_manager: MarketDataStreamManager,
        market_data_service: MarketDataService,
        event_bus: EventBus,
        history_size: int = 200,
    ) -> None:
        self._signal_processor = signal_processor
        self._order_manager = order_manager
        self._circuit_breaker = circuit_breaker
        self._stream_manager = stream_manager
        self._market_data_service = market_data_service
        self._event_bus = event_bus
        self._history_size = history_size
        self._listeners: dict[int, str] = {}  # session_id → event_bus listener_id
        self._history_cache: dict[tuple[str, str], list[dict[str, Any]]] = {}

    async def start(self, session: TradingSession) -> None:
        """Поднять listener для сессии. Вызывается из start_session + restore_sessions."""
        if session.id in self._listeners:
            logger.warning("SessionRuntime: session %s already running", session.id)
            return

        if session.timeframe is None:
            logger.error("SessionRuntime: session %s has no timeframe, skipping", session.id)
            return

        channel = f"market:{session.ticker}:{session.timeframe}"

        # 1. Предзагрузка истории
        history = await self._market_data_service.get_candles(
            ticker=session.ticker,
            timeframe=session.timeframe,
            limit=self._history_size,
        )
        self._history_cache[(session.ticker, session.timeframe)] = [c.model_dump() for c in history]

        # 2. Подписка на стрим (мультиплексируется stream_manager)
        await self._stream_manager.subscribe(session.ticker, session.timeframe)

        # 3. Listener на event_bus
        async def on_candle(candle_data: dict[str, Any]) -> None:
            await self._handle_candle(session, candle_data)

        listener_id = await self._event_bus.subscribe(channel, on_candle)
        self._listeners[session.id] = listener_id

        # 4. Публикация session.started
        await self._event_bus.publish(
            f"trades:{session.id}",
            {"type": "session.started", "session_id": session.id, "timeframe": session.timeframe},
        )
        logger.info("SessionRuntime: started session %s on %s %s", session.id, session.ticker, session.timeframe)

    async def stop(self, session_id: int) -> None:
        """Остановить listener. Вызывается из stop_session / pause_session."""
        listener_id = self._listeners.pop(session_id, None)
        if listener_id:
            await self._event_bus.unsubscribe(listener_id)
        await self._event_bus.publish(
            f"trades:{session_id}",
            {"type": "session.stopped", "session_id": session_id},
        )
        logger.info("SessionRuntime: stopped session %s", session_id)

    async def _handle_candle(self, session: TradingSession, candle_data: dict[str, Any]) -> None:
        """Обработать новую свечу: добавить в историю → SignalProcessor → CB → OrderManager."""
        started_at = time.monotonic()

        history_key = (session.ticker, session.timeframe)
        history = self._history_cache.setdefault(history_key, [])
        history.append(candle_data)
        if len(history) > self._history_size:
            history.pop(0)

        # 1. SignalProcessor
        try:
            signal = await self._signal_processor.process_candle(
                session=session,
                candles=list(history),  # копия — стратегия не должна мутировать
                user_id=session.user_id,
            )
        except Exception as e:
            logger.exception("SignalProcessor failed for session %s: %s", session.id, e)
            return

        if signal is None or signal.action == "hold":
            return

        # 2. CircuitBreaker
        cb_ok = await self._circuit_breaker.check(session, signal)
        if not cb_ok:
            await self._event_bus.publish(
                f"trades:{session.id}",
                {"type": "cb.triggered", "session_id": session.id, "signal": signal.action},
            )
            return

        # 3. OrderManager
        try:
            order = await self._order_manager.process_signal(
                session=session,
                signal=signal,
                user_id=session.user_id,
            )
        except Exception as e:
            logger.exception("OrderManager failed for session %s: %s", session.id, e)
            return

        # 4. Latency check
        elapsed_ms = (time.monotonic() - started_at) * 1000
        if elapsed_ms > 500:
            logger.warning(
                "SessionRuntime: session %s latency %.0fms > 500ms (ТЗ 5.4.2)",
                session.id, elapsed_ms,
            )

        await self._event_bus.publish(
            f"trades:{session.id}",
            {"type": "order.placed", "session_id": session.id, "order_id": order.id, "latency_ms": elapsed_ms},
        )

    async def restore_all(self, sessions: list[TradingSession]) -> None:
        """Восстановить все active/paused сессии при старте backend."""
        for session in sessions:
            if session.status in ("active", "paused") and session.timeframe:
                await self.start(session)
            elif session.status in ("active", "paused") and not session.timeframe:
                logger.warning("SessionRuntime: cannot restore session %s — no timeframe (legacy)", session.id)
```

**Критично:**
- `SessionRuntime` создаётся **один раз** при старте backend (в `main.py` lifespan или в DI-контейнере) и инжектится в `TradingSessionManager`.
- Listener подписан на **один** канал event_bus, но `_handle_candle` получает callback **от одного** session'а (замыкание по `session` в `on_candle`). Это работает потому, что разные сессии на одном `(ticker, tf)` имеют **разные** listener_id — каждый вызывается независимо.

## Задача 2.5: Интеграция в `TradingSessionManager`

В `app/trading/engine.py` / `app/trading/service.py`:

```python
class TradingSessionManager:
    def __init__(self, db, runtime: SessionRuntime, ...):
        self.runtime = runtime
        # ...

    async def start_session(self, params: SessionStartParams) -> TradingSession:
        # ... create session in DB
        session = TradingSession(...)
        self.db.add(session)
        await self.db.commit()
        await self.db.refresh(session)

        await self.runtime.start(session)  # NEW

        return session

    async def stop_session(self, session_id: int) -> None:
        await self.runtime.stop(session_id)  # NEW — ДО commit
        session = await self.db.get(TradingSession, session_id)
        session.status = "stopped"
        await self.db.commit()

    async def pause_session(self, session_id: int) -> None:
        await self.runtime.stop(session_id)  # NEW — ДО commit
        session = await self.db.get(TradingSession, session_id)
        session.status = "paused"
        await self.db.commit()
```

## Задача 2.6: Recovery при старте backend

В `app/scheduler/service.py` **или** `Develop/backend/app/main.py` lifespan:

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.trading.runtime import SessionRuntime
from app.trading.engine import TradingSessionManager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # ... existing startup code
    runtime: SessionRuntime = app.state.session_runtime
    manager: TradingSessionManager = app.state.session_manager

    active_sessions = await manager.get_active_sessions()  # SELECT status IN ('active', 'paused')
    await runtime.restore_all(active_sessions)

    yield

    # ... existing shutdown code (Graceful Shutdown — задача 6.5 S6)
```

**Важно:** DEV-2 реализует **только paper-часть** recovery (поднять listener). Real-часть (сверка позиций с брокером) — задача 6.4 Sprint 6.

## Задача 2.7: Переделка `SignalProcessor._execute_strategy`

Текущая сигнатура принимает одну свечу. Новая:

```python
class SignalProcessor:
    async def process_candle(
        self,
        session: TradingSession,
        candles: list[dict[str, Any]],   # NEW — список свечей, candles[-1] = текущая
        user_id: int,
    ) -> Signal | None:
        # ... load strategy from cache
        current = candles[-1]
        signal = await self._execute_strategy(strategy, candles, current, session)
        return signal

    async def _execute_strategy(
        self,
        strategy_code: str,
        candles: list[dict[str, Any]],
        current_candle: dict[str, Any],
        session: TradingSession,
    ) -> Signal | None:
        namespace = {
            "candles": candles,
            "candle": current_candle,
            # Алиасы на последнюю свечу для обратной совместимости
            "candle_open": current_candle["open"],
            "candle_high": current_candle["high"],
            "candle_low": current_candle["low"],
            "candle_close": current_candle["close"],
            "candle_volume": current_candle["volume"],
            "ticker": session.ticker,
            "position": None,  # TODO: реальная позиция из PositionTracker
            "signal": "hold",
            # safe_builtins — без __import__ (Gotcha 2)
            # bt, datetime, math, Decimal прокидываются из _compile_strategy
        }
        try:
            exec(strategy_code, namespace)  # noqa: S102 — sandbox
        except Exception as e:
            logger.error("Strategy execution failed: %s", e)
            return None

        action = namespace.get("signal", "hold")
        if action not in ("buy", "sell", "hold"):
            return None
        return Signal(action=action, ticker=session.ticker, ...)
```

**Stack Gotcha 2 — ключевое:** в `namespace` **нельзя** полагаться на `import` из кода стратегии. Все модули (`bt`, `math`, `Decimal`, `datetime`) прокидывай явно. Смотри `_compile_strategy` в `app/backtest/engine.py` как образец.

## Задача 2.8: Обработка ошибок стрима

- Разрыв стрима: `StreamManager` сам переподписывается, listener'ы остаются живыми (проверь — если нет, добавь re-subscribe в `SessionRuntime`).
- Недостаточно истории: если `len(candles) < required_lookback` — стратегия не вызывается, в `DailyStat` фиксируется `skipped_candles += 1`.
- Таймаут стратегии: `asyncio.wait_for(self._execute_strategy(...), timeout=5.0)` — чтобы одна сломанная стратегия не заблокировала другие.

## Задача 2.9: Frontend — `LaunchSessionModal` селект TF

В `Develop/frontend/src/components/trading/LaunchSessionModal.tsx` добавить:

```tsx
import { Select } from '@mantine/core';

const TIMEFRAMES = [
  { value: '1m', label: '1 минута' },
  { value: '5m', label: '5 минут' },
  { value: '15m', label: '15 минут' },
  { value: '1h', label: '1 час' },
  { value: '4h', label: '4 часа' },
  { value: 'D', label: '1 день' },
  { value: 'W', label: '1 неделя' },
];

// в форме:
<Select
  label="Таймфрейм"
  placeholder="Выберите таймфрейм"
  data={TIMEFRAMES}
  value={timeframe}
  onChange={(v) => setTimeframe(v || 'D')}
  required
  data-testid="session-timeframe-select"
/>
```

**Дефолт:** `D` (согласовано с BacktestLaunchModal). При отправке формы `timeframe` уходит в `POST /trading/sessions/start`.

## Задача 2.10: Frontend — вывод TF на `SessionCard`

В `Develop/frontend/src/components/trading/SessionCard.tsx`:

```tsx
<Badge variant="light">
  {session.ticker} · {session.timeframe ?? '—'}
</Badge>
```

Для старых сессий (`timeframe === null`) — прочерк.

## Задача 2.11: TypeScript типы

В `Develop/frontend/src/api/types.ts`:

```ts
export type Timeframe = '1m' | '5m' | '15m' | '1h' | '4h' | 'D' | 'W' | 'M';

export interface SessionStartRequest {
  // ... existing fields
  timeframe: Timeframe;
}

export interface TradingSession {
  // ... existing fields
  timeframe: string | null;
}
```

# Тесты

```
Develop/backend/tests/test_trading/
├── test_runtime.py                  # unit: SessionRuntime.start/stop, _handle_candle, latency, CB, errors
├── test_runtime_integration.py       # integration: fake event_bus → session → LiveTrade в БД
├── test_signal_processor_candles.py  # обновлённый _execute_strategy с candles: list
└── test_order_manager.py             # актуализация под новый контракт

Develop/frontend/e2e/
└── s5r-live-runtime.spec.ts          # E2E: запуск сессии с TF → симуляция свечи → LiveTrade в UI
```

**Фикстуры:** `db_session`, `test_user`, `test_strategy_version`, `fake_event_bus`, `fake_market_data_service` (с предзагруженной историей свечей).

**Сценарии test_runtime.py:**
1. `start` → подписка на `market:SBER:1h`, предзагрузка 200 свечей
2. `stop` → отписка, publish `session.stopped`
3. Свеча закрытия → `SignalProcessor.process_candle` вызван со списком
4. `signal=buy` → `CircuitBreaker.check` → `OrderManager.process_signal` → `LiveTrade` в БД
5. `signal=buy` + CB не пропускает → publish `cb.triggered`, ордера нет
6. `SignalProcessor` бросает исключение → логируется, runtime не падает
7. Latency > 500ms → warning в логе

**Integration test:**
```python
async def test_end_to_end_paper_session(db_session, fake_event_bus, ...):
    # 1. Создать paper-сессию на SBER, 1h
    session = await manager.start_session(SessionStartParams(
        ..., timeframe="1h"
    ))
    # 2. Публиковать свечу в event_bus
    await fake_event_bus.publish("market:SBER:1h", {"open": 100, "high": 102, ...})
    # 3. Ждать обработки
    await asyncio.sleep(0.1)
    # 4. Проверить, что LiveTrade появился (если стратегия buy)
    trades = await db_session.execute(select(LiveTrade).where(LiveTrade.session_id == session.id))
    assert len(trades.scalars().all()) == 1
```

**E2E сценарий `s5r-live-runtime.spec.ts`:**
```ts
test('fake market publisher → live trade in session list', async ({ page }) => {
  await page.goto('/trading');
  await page.getByRole('button', { name: 'Новая сессия' }).click();
  await page.getByTestId('session-ticker-input').fill('SBER');
  await page.getByTestId('session-timeframe-select').click();
  await page.getByText('1 час').click();
  // ... submit
  // Публикация fake-свечи через API endpoint для тестов (если есть) или через WebSocket mock
  // Проверка появления сделки
  await expect(page.getByTestId('session-card-SBER')).toContainText('1h');
});
```

# ⚠️ Integration Verification Checklist

**КРИТИЧНО:** это именно та проверка, отсутствие которой в S5 создало технический долг #4 (причину этого ревью). Пройди честно.

- [ ] **Grep на инстанциирование:**
  `grep -rn "SessionRuntime(" app/` → класс создаётся **кроме** `runtime.py` и тестов — например, в `main.py` lifespan или DI-контейнере
- [ ] **Grep на вызов start/stop:**
  `grep -rn "runtime\.start\(" app/` и `grep -rn "runtime\.stop\(" app/` → вызовы **в** `TradingSessionManager.start_session` / `stop_session` / `pause_session` / recovery hook
- [ ] **Grep на `process_candle`:**
  `grep -rn "process_candle(" app/` → **НЕ только** в `engine.py` (определение) и в тестах, но и в `runtime.py:_handle_candle` (production вызов). Это **главная проверка** — именно её не прошёл S5.
- [ ] **Listener на event_bus:**
  `grep -rn "event_bus.subscribe" app/trading/` → в `runtime.py:start()` подписка на канал `market:{ticker}:{tf}`
- [ ] **Lifespan / recovery hook:**
  `grep -rn "restore_all" app/` → вызов в `main.py` lifespan или `scheduler/service.py`
- [ ] **API endpoint:**
  `POST /trading/sessions/start` принимает `timeframe` (проверить через `TestClient` тест → payload с `timeframe: "1h"` возвращает 200, без `timeframe` → 422)
- [ ] **Frontend → Backend:**
  `LaunchSessionModal` отправляет `timeframe` в запросе — проверить через Network tab или unit-тест компонента
- [ ] **Если точка вызова не найдена** — `⚠️ NOT CONNECTED` в отчёте. Такая пометка **блокирует** приёмку ARCH.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни в финальном ответе **только** структурированную сводку **до 400 слов**.

```markdown
## DEV-2 отчёт — Sprint_5_Review, S5R.2 Live Runtime Loop

### 1. Что реализовано
- TradingSession.timeframe + миграция
- SessionRuntime: start/stop, _handle_candle, restore_all, latency check, event_bus publish
- TradingSessionManager.start/stop/pause → вызов SessionRuntime
- SignalProcessor._execute_strategy принимает candles: list (не одну свечу)
- Lifespan hook в main.py — restore_all при старте backend
- LaunchSessionModal + SessionCard + types.ts — timeframe в UI

### 2. Файлы
- **Новые:** `backend/app/trading/runtime.py`, `backend/tests/test_trading/test_runtime.py`, `backend/tests/test_trading/test_runtime_integration.py`, `backend/alembic/versions/XXXX_add_timeframe.py`, `frontend/e2e/s5r-live-runtime.spec.ts`
- **Изменённые:** `backend/app/trading/models.py`, `engine.py`, `service.py`, `schemas.py`, `main.py`, `frontend/src/components/trading/LaunchSessionModal.tsx`, `SessionCard.tsx`, `src/api/types.ts`

### 3. Тесты
- Backend unit: X/X passed (runtime, signal_processor_candles)
- Backend integration: Y/Y passed (end-to-end paper session)
- Frontend vitest: Z/Z passed
- Frontend Playwright: новый `s5r-live-runtime.spec.ts` passes
- Alembic: upgrade/downgrade/upgrade проверено

### 4. Integration points
- `SessionRuntime()` создаётся в `main.py:lifespan` (✅ подключено)
- `SessionRuntime.start` вызывается из `TradingSessionManager.start_session:L<N>` (✅)
- `SessionRuntime.stop` вызывается из `stop_session:L<N>`, `pause_session:L<N>` (✅)
- `SignalProcessor.process_candle` вызывается из `SessionRuntime._handle_candle:L<N>` (✅ — фикс техдолга #4)
- `restore_all` вызывается из `main.py:lifespan:L<N>` при старте (✅)

### 5. Контракты для других DEV
- **Поставляю C4** (TradingSession.timeframe): SQLAlchemy `Mapped[str | None]` nullable, Pydantic `str | None`, TS `string | null` — подтверждено
- **Поставляю C5** (SessionStartRequest.timeframe): `Literal["1m","5m","15m","1h","4h","D","W","M"]` обязательное — подтверждено
- **Поставляю C6** (SessionRuntime API): `start(session) -> None`, `stop(session_id) -> None` — вызывается из `TradingSessionManager`, точные строки выше
- **Поставляю C7** (EventBus events): каналы `trades:{session_id}`, events `order.placed`, `trade.filled`, `trade.closed`, `session.started`, `session.stopped`, `cb.triggered` — publish'атся из `runtime.py`
- **Использую C1, C2, C3** (от DEV-1): `ruff check`, `pnpm lint`, все CI команды — подтверждаю, baseline зелёный

### 6. Проблемы / TODO
- Recovery real-позиций (сверка с брокером) — задача 6.4 S6, NOT CONNECTED пока
- `PositionTracker` в namespace стратегии — заглушка, реальные позиции из БД — TODO в S6

### 7. Применённые Stack Gotchas
- **Gotcha 2** (CodeSandbox __import__): `candles` передан в namespace как `list[dict]`, `bt/math/Decimal` прокинуты через `_compile_strategy` без `import` в коде стратегии. Алиасы `candle_open/...` оставлены для обратной совместимости.
- **Gotcha 5** (CB asyncio.Lock): `CircuitBreaker.check()` в listener'е использует существующий lock, новый не создаю.
- **Gotcha 1** (Pydantic Decimal): `balance`/`equity` в `SessionResponse` остались `str` — не менял сериализацию.

### 8. Новые Stack Gotchas (если обнаружены)
- <если обнаружена новая — описать>
```

# Alembic-миграция (если применимо)

```bash
cd Develop/backend
alembic revision --autogenerate -m "add_timeframe_to_trading_sessions"
# Проверить файл миграции — должно быть ADD COLUMN timeframe VARCHAR(10) NULL
alembic upgrade head
alembic downgrade -1
alembic upgrade head
```

# Чеклист перед сдачей

- [ ] Все задачи 2.1-2.11 реализованы
- [ ] `cd Develop/backend && pytest tests/test_trading/` → 0 failures
- [ ] `cd Develop/backend && pytest tests/` → 0 failures (не сломать остальное)
- [ ] `cd Develop/frontend && pnpm tsc --noEmit` → 0 errors
- [ ] `cd Develop/frontend && pnpm lint` → 0 errors
- [ ] `cd Develop/frontend && pnpm test` → 0 failures
- [ ] `cd Develop/frontend && npx playwright test e2e/s5r-live-runtime.spec.ts` → passed
- [ ] Миграция применена (`alembic upgrade head` + `downgrade -1` + `upgrade head`)
- [ ] **Integration Verification Checklist полностью пройден** — все 7 пунктов с конкретными строками
- [ ] **Формат отчёта соблюдён** — 8 секций, ≤ 400 слов
- [ ] **Cross-DEV contracts C4, C5, C6, C7 подтверждены** в секции 5 отчёта
- [ ] **Stack Gotchas применены** — секция 7 отчёта
- [ ] **Grep `process_candle(` показывает production-вызов** из `runtime.py`, не только тесты — **главный критерий**, без которого задача не принимается
- [ ] Latency < 500ms проверено в логах (warning при превышении)
