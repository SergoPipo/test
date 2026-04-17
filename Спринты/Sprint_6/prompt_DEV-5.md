---
sprint: S6
agent: DEV-5
role: "Backend Streaming (BACK4) — T-Invest Stream Multiplex (persistent gRPC)"
wave: 2
depends_on: [DEV-3]
---

# Роль

Ты — Backend-разработчик #5 (senior), специалист по gRPC и асинхронному программированию. Твоя задача — рефакторить `TInvestAdapter.subscribe_candles()` из «один stream на подписку» в «один persistent stream с мультиплексированием». Это устраняет нарушение Gotcha 4 и предотвращает `429 Too Many Requests` при 5+ торговых сессиях.

Работаешь в `Develop/backend/`.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python >= 3.11
2. Зависимости: DEV-3 (волна 1) обновил SDK до beta117+ — проверь: pip show tinkoff-investments
3. Существующие файлы:
   - app/broker/tinvest/adapter.py        — TInvestAdapter (853 строки). subscribe_candles() создаёт ОТДЕЛЬНЫЙ stream на каждую подписку — это нарушение Gotcha 4.
   - app/market_data/stream_manager.py    — MarketDataStreamManager вызывает adapter.subscribe_candles(). НЕ модифицировать public API StreamManager.
   - app/common/event_bus.py              — EventBus singleton.
4. База данных: не требуется
5. Тесты baseline: `pytest tests/` → 0 failures
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — **критично:**
   - **Gotcha 4** (`gotcha-04-tinvest-stream.md`) — **основная задача этого промпта**. Полная цитата:
     > «T-Invest gRPC streaming: persistent connection обязателен. Правило: TInvestAdapter.subscribe_candles() использует StreamManager из app/market_data/stream_manager.py. StreamManager поддерживает одно MarketDataStream, мультиплексирует подписки по ключу (ticker, timeframe), делает auto-reconnect.»
   - **Gotcha 15** (`gotcha-15-tinvest-naive-datetime.md`) — UTC-offset. При reconnect'е не потерять timezone normalization.

3. **`Спринты/Sprint_6/execution_order.md`** раздел **«Cross-DEV contracts»**:
   - Ты **потребитель** контракта от DEV-3: обновлённый SDK beta117+.

4. **`Спринты/Sprint_6/backlog.md`** секция **«S6-TINVEST-STREAM-MULTIPLEX»** — полный контекст.

5. **Цитаты из backlog (дословно):**

   > «Сейчас на каждую подписку создаётся отдельное async with self._create_client() as client: async for response in client.market_data_stream.market_data_stream(...) — отдельное соединение, отдельный request_iterator. Это антипаттерн, явно запрещённый Gotcha 4. На проде это приведёт к rate-limit T-Invest (429 Too Many Requests) при первых же 5-10 торговых сессиях на разные тикеры.»

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

```
- app/broker/tinvest/adapter.py        — TInvestAdapter. subscribe_candles(ticker, tf, callback) → subscription_id. Создаёт asyncio.create_task(_stream_candles()) для каждой подписки. _stream_candles() открывает свой AsyncClient + market_data_stream. Поле self._subscriptions: dict[str, asyncio.Task].
- app/broker/tinvest/mapper.py          — TInvestMapper: candle_to_candle_data(candle) → CandleData.
- app/market_data/stream_manager.py     — MarketDataStreamManager: subscribe(ticker, tf, api_key) → channel_name. Создаёт TInvestAdapter per-stream, вызывает subscribe_candles. Public API НЕ МЕНЯТЬ.
- app/broker/base.py                    — CandleData(timestamp, open, high, low, close, volume).
```

# Задачи

## Задача 5.1: StreamMultiplexer — архитектура

Создай класс `TInvestStreamMultiplexer` в `app/broker/tinvest/multiplexer.py` (новый файл):

```python
import asyncio
from collections import defaultdict
from typing import Callable, Awaitable
from app.broker.base import CandleData

class TInvestStreamMultiplexer:
    """Мультиплексор подписок в одном gRPC MarketDataStream.
    
    Архитектура:
    - Одно долгоживущее MarketDataStream соединение на весь процесс backend.
    - asyncio.Queue для incoming-запросов подписки/отписки.
    - Async request-iterator, который потребляет из queue и yield'ит MarketDataRequest.
    - Маршрутизация ответов: по response.candle.figi → callback.
    """
    
    def __init__(self, token: str, app_name: str = "moex-terminal") -> None:
        self._token = token
        self._app_name = app_name
        
        # Routing: figi → list[(subscription_id, callback)]
        self._routes: dict[str, list[tuple[str, Callable[[CandleData], Awaitable[None]]]]] = defaultdict(list)
        
        # Queue для subscribe/unsubscribe команд
        self._command_queue: asyncio.Queue = asyncio.Queue()
        
        # Background task для stream
        self._stream_task: asyncio.Task | None = None
        
        # Reconnect state
        self._connected = False
        self._reconnect_delay = 1.0  # exponential backoff: 1→2→4→8→max 30
    
    async def start(self) -> None:
        """Запустить background stream task."""
        if self._stream_task is None or self._stream_task.done():
            self._stream_task = asyncio.create_task(self._run_stream())
    
    async def stop(self) -> None:
        """Остановить stream и очистить все подписки."""
        if self._stream_task:
            self._stream_task.cancel()
            try:
                await self._stream_task
            except asyncio.CancelledError:
                pass
        self._routes.clear()
    
    async def subscribe(
        self,
        figi: str,
        interval: "SubscriptionInterval",
        callback: Callable[[CandleData], Awaitable[None]],
    ) -> str:
        """Добавить подписку на figi.
        
        1. Генерирует subscription_id (UUID)
        2. Добавляет (subscription_id, callback) в self._routes[figi]
        3. Если это первый listener для данного figi — шлёт SUBSCRIBE в queue
        4. Если stream не запущен — запускает
        5. Return subscription_id
        """
    
    async def unsubscribe(self, subscription_id: str) -> None:
        """Удалить подписку.
        
        1. Находит figi по subscription_id
        2. Удаляет (subscription_id, callback) из routes
        3. Если это был последний listener для figi — шлёт UNSUBSCRIBE в queue
        """
    
    async def _run_stream(self) -> None:
        """Основной цикл: поддерживает persistent gRPC stream.
        
        while True:
            try:
                async with AsyncClient(token=self._token, app_name=self._app_name) as client:
                    self._connected = True
                    self._reconnect_delay = 1.0  # reset backoff
                    
                    async for response in client.market_data_stream.market_data_stream(
                        self._request_iterator()
                    ):
                        if response.candle:
                            await self._dispatch_candle(response.candle)
            except asyncio.CancelledError:
                raise
            except Exception as e:
                self._connected = False
                logger.warning(f"Stream disconnected: {e}. Reconnecting in {self._reconnect_delay}s...")
                await asyncio.sleep(self._reconnect_delay)
                self._reconnect_delay = min(self._reconnect_delay * 2, 30.0)
                # При reconnect — переподписаться на все активные figi
                await self._resubscribe_all()
        """
    
    async def _request_iterator(self):
        """Async generator: yield MarketDataRequest из command_queue.
        
        При старте — подписаться на все figi из self._routes.
        Затем бесконечно ждать новых команд из queue.
        """
        # Начальная подписка на все активные figi
        for figi, listeners in self._routes.items():
            if listeners:
                yield self._make_subscribe_request(figi)
        
        # Бесконечный цикл для новых subscribe/unsubscribe
        while True:
            command = await self._command_queue.get()
            yield command
    
    async def _dispatch_candle(self, candle) -> None:
        """Маршрутизация candle по figi → callbacks.
        
        1. figi = candle.figi
        2. Найти listeners в self._routes[figi]
        3. Для каждого (sub_id, callback): await callback(candle_data)
        4. Обработать ошибки в callback — логировать, не ломать stream
        """
    
    async def _resubscribe_all(self) -> None:
        """После reconnect: отправить SUBSCRIBE для всех активных figi."""
        for figi, listeners in self._routes.items():
            if listeners:
                await self._command_queue.put(self._make_subscribe_request(figi))
    
    def _make_subscribe_request(self, figi: str) -> "MarketDataRequest":
        """Создать MarketDataRequest с SubscribeCandlesRequest(SUBSCRIBE, figi)."""
    
    def _make_unsubscribe_request(self, figi: str) -> "MarketDataRequest":
        """Создать MarketDataRequest с SubscribeCandlesRequest(UNSUBSCRIBE, figi)."""
    
    @property
    def active_subscriptions(self) -> int:
        """Количество активных figi-подписок."""
        return sum(1 for listeners in self._routes.values() if listeners)
```

## Задача 5.2: Интеграция в TInvestAdapter

В `app/broker/tinvest/adapter.py` рефакторь `subscribe_candles`:

```python
class TInvestAdapter:
    def __init__(self):
        # ...
        self._multiplexer: TInvestStreamMultiplexer | None = None
    
    async def _ensure_multiplexer(self) -> TInvestStreamMultiplexer:
        """Ленивая инициализация multiplexer."""
        if self._multiplexer is None:
            self._multiplexer = TInvestStreamMultiplexer(token=self._token)
            await self._multiplexer.start()
        return self._multiplexer
    
    async def subscribe_candles(
        self,
        ticker: str,
        timeframe: str,
        callback: Callable[[CandleData], Awaitable[None]],
    ) -> str:
        """РЕФАКТОРИНГ: вместо отдельного stream → через multiplexer.
        
        1. Resolve FIGI from ticker (с кешированием, как сейчас)
        2. Map timeframe → SubscriptionInterval
        3. multiplexer = await self._ensure_multiplexer()
        4. subscription_id = await multiplexer.subscribe(figi, interval, callback)
        5. Сохранить в self._subscriptions[subscription_id] = figi
        6. Return subscription_id
        """
    
    async def unsubscribe(self, subscription_id: str) -> None:
        """Через multiplexer.unsubscribe()."""
        if self._multiplexer:
            await self._multiplexer.unsubscribe(subscription_id)
        self._subscriptions.pop(subscription_id, None)
    
    async def disconnect(self) -> None:
        """Остановить multiplexer + очистить."""
        if self._multiplexer:
            await self._multiplexer.stop()
            self._multiplexer = None
        self._subscriptions.clear()
```

**Критично:** public API `subscribe_candles(ticker, tf, callback) → subscription_id` и `unsubscribe(subscription_id)` **не меняется**. `StreamManager` вызывает эти методы — он не должен знать про multiplexer.

## Задача 5.3: Тесты

```python
# tests/unit/test_broker/test_tinvest_multiplexer.py

async def test_two_subscriptions_different_figi():
    """2 подписки на разные figi → 2 callback'а получают свои candles."""

async def test_unsubscribe_one_of_two():
    """Отписка от одной из двух → вторая продолжает работать."""

async def test_reconnect_resubscribes():
    """Разрыв соединения → auto-reconnect, подписки восстанавливаются."""

async def test_single_stream_instance():
    """Все подписки проходят через один MarketDataStream (grep на инстанциирование)."""

async def test_backoff_on_repeated_failure():
    """Повторные разрывы → exponential backoff 1→2→4→8→max 30."""
```

**Мокирование:** mock `AsyncClient.market_data_stream.market_data_stream()` — отдавай fake candle responses. НЕ подключаться к реальному T-Invest.

# Тесты

```
tests/
├── unit/test_broker/
│   ├── test_tinvest_multiplexer.py    # 5 тестов выше
│   └── test_tinvest_adapter.py        # Регрессия: subscribe_candles через multiplexer
```

**Минимум:** 5 новых тестов + регрессия существующих.

# ⚠️ Integration Verification Checklist

- [ ] `grep -rn "TInvestStreamMultiplexer(" app/` — создаётся в adapter.py (lazy init)
- [ ] `grep -rn "market_data_stream(" app/broker/tinvest/ | grep -v test` → **одно** место (в multiplexer.py)
- [ ] `grep -rn "_stream_candles" app/broker/tinvest/adapter.py` → **отсутствует** (старый метод удалён)
- [ ] `grep -rn "create_task" app/broker/tinvest/adapter.py` → **отсутствует** (task-per-subscription удалён)
- [ ] `pytest tests/unit/test_broker/ -v` → 0 failures
- [ ] `ruff check .` → 0 errors

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.
Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-5_report.md`.

# Чеклист перед сдачей

- [ ] `TInvestStreamMultiplexer` реализован с persistent stream + routing + auto-reconnect
- [ ] `TInvestAdapter.subscribe_candles` рефакторен через multiplexer
- [ ] Старый `_stream_candles` / task-per-subscription удалён
- [ ] `ruff check .` → 0 errors
- [ ] `pytest tests/` → 0 failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-5_report.md`
- [ ] **Cross-DEV contracts подтверждены:** SDK beta117+ от DEV-3 используется
- [ ] Public API subscribe_candles/unsubscribe **не изменён** (StreamManager не трогать)
