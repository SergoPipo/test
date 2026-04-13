---
sprint: 5
agent: DEV-1
role: Backend Core (BACK1) — Trading Engine + Broker Adapter
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #1 (senior). Реализуй ядро торгового движка: Trading Engine (session manager, signal processor, order manager, position tracker), Paper Trading Engine, доработку Broker Adapter (6 методов + streaming), персистентность Rate Limiter.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/trading/ — модели есть (models.py), заглушки (router.py, service.py, schemas.py)
3. Broker Adapter: backend/app/broker/base.py — абстрактный класс BaseBrokerAdapter
4. T-Invest Adapter: backend/app/broker/tinvest/adapter.py — 6 методов raise NotImplementedError
5. Rate Limiter: backend/app/broker/tinvest/rate_limiter.py — in-memory TokenBucketRateLimiter
6. Event Bus: backend/app/common/event_bus.py — pub/sub (уже работает)
7. WebSocket: backend/app/backtest/ws.py — мультиплексор /ws (уже работает)
8. pytest tests/ проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-1 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Паттерны проекта

Каждый модуль следует паттерну:
- `models.py` — SQLAlchemy 2.0 mapped_column, `Base` из `app.common.database`
- `schemas.py` — Pydantic v2 (BaseModel)
- `service.py` — async бизнес-логика
- `router.py` — `APIRouter(prefix="/api/v1/{module}", tags=["{module}"])`

Финансовые данные: `Numeric(18, 8)` для цен, `Numeric(18, 2)` для денег, `Numeric(10, 4)` для процентов. В Python — `decimal.Decimal`.

## Существующие модели (app/trading/models.py)

Уже определены 4 модели — **НЕ ПЕРЕСОЗДАВАТЬ**, использовать как есть:

```python
class TradingSession(Base):      # trading_sessions
    # id, strategy_version_id (FK), broker_account_id (FK nullable),
    # ticker, mode ("paper"/"real"), status ("active"/"paused"/"stopped"),
    # position_sizing_mode, position_sizing_value, max_concurrent_positions,
    # cooldown_seconds, initial_capital, consecutive_fund_skips,
    # started_at, stopped_at, last_signal_at
    # Relationships: live_trades, paper_portfolio, daily_stats

class LiveTrade(Base):           # live_trades
    # id, session_id (FK), broker_order_id, direction, order_type, status,
    # entry_signal_price, entry_price, exit_signal_price, exit_price,
    # volume_lots, filled_lots, volume_rub, stop_loss, take_profit,
    # pnl, pnl_pct, commission, slippage, nkd_entry, nkd_exit,
    # opened_at, closed_at

class PaperPortfolio(Base):      # paper_portfolios
    # id, session_id (FK unique), balance, blocked_amount, peak_equity, updated_at

class DailyStat(Base):           # daily_stats
    # id, session_id (FK), date (unique с session_id),
    # trades_opened, trades_closed, pnl, realized_pnl, unrealized_pnl, peak_equity
```

## Broker Adapter (app/broker/base.py)

Уже есть:
- `BaseBrokerAdapter` (ABC) с методами: `connect`, `disconnect`, `get_accounts`, `get_balance`, `get_historical_candles`
- Stub-методы (нужно реализовать в TInvestAdapter): `get_positions`, `place_order`, `cancel_order`, `get_order_status`, `search_instruments`, `get_instrument_info`
- Dataclasses: `BrokerAccountInfo`, `AccountBalance`, `CandleData`

**Отсутствует в base.py** (нужно добавить): `subscribe_candles`, `subscribe_orderbook`, `subscribe_trades`, `get_operations`.

## T-Invest Adapter (app/broker/tinvest/adapter.py)

Реализовано: `connect`, `disconnect`, `get_accounts`, `get_balance`, `get_historical_candles`, `_resolve_figi` (кеш ticker→FIGI).
Паттерн вызовов: `self._ensure_connected()` → `self._rate_limiter.acquire()` → `async with self._create_client() as client:`.

## Event Bus (app/common/event_bus.py)

```python
event_bus = EventBus()  # глобальный синглтон
await event_bus.publish(channel, event, data)
sub_id, queue = event_bus.subscribe(channel)
event_bus.unsubscribe(channel, sub_id)
```

Каналы в проекте: `backtest:{id}`, `market:{ticker}:{tf}`, `trades:{session_id}`, `notifications`, `health`.

## WebSocket Мультиплексор (app/backtest/ws.py)

Endpoint `/ws?token=JWT`. Клиент отправляет `{"action": "subscribe", "channel": "..."}`. Сервер пушит события из подписанных каналов. Уже работает — **не модифицировать**, только публиковать события в EventBus.

# Задачи

## Задача 1: Trading Engine (app/trading/engine.py)

### 1.1 TradingSessionManager

```python
class TradingSessionManager:
    """Управление жизненным циклом торговых сессий."""

    async def start_session(self, user_id: int, params: SessionStartParams) -> TradingSession:
        """Создать и запустить новую сессию.
        1. Проверить конфликты (нет ли уже active сессии на том же тикере + счёте)
        2. Создать TradingSession в БД
        3. Для Paper: создать PaperPortfolio с initial_capital
        4. Подписаться на котировки (EventBus / broker subscribe_candles)
        5. Опубликовать event: trades:{session_id} → session.started
        """

    async def pause_session(self, session_id: int) -> None:
        """Пауза: блокировать новые сигналы, удерживать позиции."""

    async def resume_session(self, session_id: int) -> None:
        """Возобновить обработку сигналов."""

    async def stop_session(self, session_id: int) -> None:
        """Остановить сессию: закрыть все позиции, отписаться от котировок."""

    async def restore_sessions(self) -> None:
        """Восстановление при перезапуске (ТЗ 5.4.3):
        1. SELECT trading_sessions WHERE status IN ('active', 'suspended')
        2. Для real: сверить позиции с брокером
        3. При расхождении: пауза + уведомление
        4. При совпадении: восстановить подписки"""
```

### 1.2 SignalProcessor

```python
class SignalProcessor:
    """Получает свечи, прогоняет через стратегию, генерирует сигналы."""

    async def process_candle(self, session: TradingSession, candle: CandleData) -> Signal | None:
        """Поток из ТЗ 5.4.2:
        1. Загрузить стратегию из strategy_version (код уже в БД)
        2. Обновить данные (добавить свечу)
        3. Выполнить стратегию через SandboxExecutor
        4. Вернуть Signal: BUY / SELL / HOLD
        Требование: весь путь < 500ms (стратегия предзагружена в RAM)
        """
```

### 1.3 OrderManager

```python
class OrderManager:
    """Конвертация сигналов в ордера, отправка в брокер."""

    async def process_signal(self, session: TradingSession, signal: Signal) -> LiveTrade | None:
        """
        1. CircuitBreaker.check(session, signal) — если BLOCK → return None + event
        2. Рассчитать размер позиции (position_sizing_mode + value)
        3. Для Paper: PaperTradingEngine.execute_order()
        4. Для Real: BrokerAdapter.place_order()
        5. Создать LiveTrade в БД (status='pending')
        6. Обновить DailyStat (trades_opened++)
        7. EventBus.publish("trades:{session_id}", "order.placed", {...})
        """

    async def close_position(self, trade_id: int, reason: str = "manual") -> None:
        """Принудительное закрытие позиции (из UI или по сигналу)."""

    async def close_all_positions(self, session_id: int) -> None:
        """Закрыть все позиции сессии (требует подтверждения на фронте)."""
```

### 1.4 PositionTracker

```python
class PositionTracker:
    """Отслеживание позиций и P&L."""

    async def update_position(self, trade: LiveTrade, fill_price: Decimal, filled_lots: int) -> None:
        """Обновить позицию при исполнении ордера."""

    async def calculate_unrealized_pnl(self, session_id: int, current_prices: dict[str, Decimal]) -> Decimal:
        """Нереализованный P&L по открытым позициям."""

    async def on_order_filled(self, trade: LiveTrade) -> None:
        """Колбэк при исполнении ордера:
        1. Обновить trade.entry_price, filled_lots, status
        2. Для Paper: обновить PaperPortfolio.balance
        3. Обновить DailyStat
        4. Обновить peak_equity
        5. EventBus.publish — trade.filled / trade.closed"""
```

## Задача 2: Paper Trading Engine (app/trading/paper_engine.py)

```python
class PaperBrokerAdapter(BaseBrokerAdapter):
    """Виртуальный брокер для бумажной торговли.
    Совместим с интерфейсом BaseBrokerAdapter (ТЗ 5.4.4).
    """

    async def place_order(self, ...) -> dict:
        """Виртуальное исполнение:
        1. Проверить достаточность средств в PaperPortfolio
        2. Исполнить по текущей рыночной цене + slippage
        3. Эмулировать T+1: заблокировать средства (blocked_amount) на 1 торговый день
           - Использовать MOEX-календарь (app/scheduler/) для определения следующего торгового дня
        4. Обновить PaperPortfolio.balance
        5. Вернуть результат в том же формате, что и реальный брокер
        """

    async def get_positions(self, account_id: str) -> list:
        """Позиции из live_trades WHERE session.mode='paper' AND status='filled' AND closed_at IS NULL"""

    async def get_balance(self, account_id: str) -> AccountBalance:
        """Баланс из PaperPortfolio"""
```

**Важно по T+1:**
- После покупки средства блокируются до следующего торгового дня по календарю MOEX
- `PaperPortfolio.blocked_amount` уже есть в модели
- При расчёте доступных средств: `available = balance - blocked_amount`
- Разблокировка: scheduled job или проверка при каждом запросе

## Задача 3: Broker Adapter — реализация stub-методов

### 3.1 Обновить BaseBrokerAdapter (app/broker/base.py)

Добавить новые абстрактные методы и dataclasses:

```python
@dataclass
class PositionInfo:
    ticker: str
    direction: str  # "long" / "short"
    quantity: int
    average_price: Decimal
    current_price: Decimal
    unrealized_pnl: Decimal

@dataclass
class OrderResponse:
    order_id: str
    status: str  # "placed", "filled", "partially_filled", "rejected"
    filled_quantity: int
    price: Decimal | None

@dataclass
class OrderStatus:
    order_id: str
    status: str
    filled_quantity: int
    total_quantity: int
    average_price: Decimal | None
    message: str | None

@dataclass
class InstrumentInfo:
    ticker: str
    figi: str
    name: str
    type: str  # "share", "bond", "etf", "currency"
    lot_size: int
    min_price_increment: Decimal
    currency: str
    trading_status: str

# Новые абстрактные методы:
@abstractmethod
async def subscribe_candles(
    self, ticker: str, timeframe: str,
    callback: Callable[[CandleData], Awaitable[None]]
) -> str:
    """Подписаться на свечи. Возвращает subscription_id."""

@abstractmethod
async def unsubscribe(self, subscription_id: str) -> None:
    """Отменить подписку."""

@abstractmethod
async def get_operations(
    self, account_id: str, from_dt: datetime, to_dt: datetime
) -> list[dict]:
    """Получить историю операций."""
```

Обновить сигнатуры существующих stub-методов:
- `get_positions` → возвращает `list[PositionInfo]`
- `place_order` → возвращает `OrderResponse`
- `get_order_status` → возвращает `OrderStatus`
- `search_instruments` → возвращает `list[InstrumentInfo]`
- `get_instrument_info` → возвращает `InstrumentInfo`

### 3.2 Реализовать в TInvestAdapter (app/broker/tinvest/adapter.py)

Реализовать 6 stub-методов + 3 новых. Использовать T-Invest gRPC API:

- **get_positions**: `client.operations.get_portfolio(account_id)` → маппинг через TInvestMapper
- **place_order**: `client.orders.post_order(figi, quantity, price, direction, account_id, order_type)` или `client.sandbox.post_sandbox_order(...)` для sandbox
- **cancel_order**: `client.orders.cancel_order(account_id, order_id)` или sandbox аналог
- **get_order_status**: `client.orders.get_order_state(account_id, order_id)`
- **search_instruments**: `client.instruments.find_instrument(query)`
- **get_instrument_info**: `client.instruments.share_by(...)` или `bond_by(...)` с определением типа

**subscribe_candles** — gRPC streaming:
```python
async def subscribe_candles(self, ticker: str, timeframe: str, callback) -> str:
    """Важно: gRPC streaming требует persistent connection.
    Создать отдельный StreamManager, который:
    1. Поддерживает одно long-lived соединение MarketDataStream
    2. Мультиплексирует подписки на свечи по разным тикерам
    3. При обрыве — автоматический reconnect
    """
```

### 3.3 Добавить в TInvestMapper (app/broker/tinvest/mapper.py)

Методы маппинга:
- `portfolio_position_to_position_info()`
- `order_response_to_order_response()`
- `order_state_to_order_status()`
- `instrument_to_instrument_info()`

## Задача 4: Rate Limiter — персистентность (app/broker/tinvest/rate_limiter.py)

Текущий `TokenBucketRateLimiter` — in-memory. Добавить SQLite-персистентность для переживания перезапуска:

```python
class PersistentTokenBucketRateLimiter(TokenBucketRateLimiter):
    """Расширение: сохраняет состояние в БД при shutdown, восстанавливает при startup.
    Модель: можно использовать pending_events или отдельную таблицу.
    Или проще: сохранять tokens + last_refill в JSON-файл."""
```

**Минимальный вариант:** при shutdown (app.on_event("shutdown")) сохранить состояние в JSON-файл, при startup — восстановить. Не нужна полноценная таблица.

## Задача 5: Trading Schemas (app/trading/schemas.py)

Pydantic v2 схемы:

```python
class SessionStartRequest(BaseModel):
    strategy_version_id: int
    ticker: str
    mode: Literal["paper", "real"]
    broker_account_id: int | None = None  # обязателен для real
    initial_capital: Decimal
    position_sizing_mode: Literal["fixed_sum", "fixed_lots", "percent"] = "fixed_sum"
    position_sizing_value: Decimal = Decimal("100000")
    max_concurrent_positions: int = 1
    cooldown_seconds: int = 0

class SessionResponse(BaseModel):
    id: int
    ticker: str
    mode: str
    status: str
    strategy_name: str  # из join
    initial_capital: Decimal
    current_pnl: Decimal | None
    started_at: datetime
    model_config = ConfigDict(from_attributes=True)

class TradeResponse(BaseModel):
    # все поля LiveTrade для API
    ...

class PositionResponse(BaseModel):
    # открытая позиция с unrealized P&L
    ...
```

## Задача 6: Trading Router (app/trading/router.py)

```python
router = APIRouter(prefix="/api/v1/trading", tags=["trading"])

# Сессии
POST   /sessions              — запуск новой сессии
GET    /sessions              — список всех сессий (фильтр: status, mode)
GET    /sessions/{id}         — детали сессии
PATCH  /sessions/{id}/pause   — пауза
PATCH  /sessions/{id}/resume  — возобновление
PATCH  /sessions/{id}/stop    — остановка

# Позиции
GET    /sessions/{id}/positions   — открытые позиции сессии
POST   /sessions/{id}/positions/{trade_id}/close — закрыть позицию
POST   /sessions/{id}/close-all  — закрыть все позиции

# Сделки
GET    /sessions/{id}/trades     — сделки с пагинацией (offset, limit)

# Статистика
GET    /sessions/{id}/stats      — daily stats

# Общее
GET    /positions                — все открытые позиции по всем сессиям
GET    /dashboard                — сводка: active sessions count, total P&L
```

**CSRF:** мутирующие endpoints (POST, PATCH) должны использовать CSRF-защиту (см. middleware/csrf.py).

## Задача 7: Trading Service (app/trading/service.py)

Оркестрация: связывает Router ↔ Engine. Использует DI через FastAPI Depends:

```python
class TradingService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.session_manager = TradingSessionManager(db)
        self.order_manager = OrderManager(db)
        self.position_tracker = PositionTracker(db)
```

# Тесты

Минимум 30 тестов в `tests/test_trading/`:

```
test_trading/
├── test_engine.py           # SessionManager: start, pause, stop, конфликты
├── test_paper_engine.py     # PaperBrokerAdapter: place_order, T+1, баланс
├── test_order_manager.py    # Обработка сигналов, sizing, close
├── test_position_tracker.py # P&L расчёт, peak equity
├── test_schemas.py          # Валидация входных данных
├── test_router.py           # HTTP endpoints (TestClient)
└── test_service.py          # Integration: service + engine
```

Фикстуры: `db_session`, `test_user`, `test_strategy_version`, `test_broker_account`.

# Alembic-миграция

Создать миграцию если нужны новые таблицы (rate_limiter_state). Основные таблицы (trading_sessions, live_trades, paper_portfolios, daily_stats) уже должны быть в миграциях — проверь.

# Чеклист перед сдачей

- [ ] TradingSessionManager: start, pause, resume, stop, restore
- [ ] SignalProcessor: process_candle → Signal
- [ ] OrderManager: process_signal, close_position, close_all
- [ ] PositionTracker: unrealized P&L, on_order_filled
- [ ] PaperBrokerAdapter: виртуальное исполнение, T+1, баланс
- [ ] BaseBrokerAdapter: новые dataclasses, новые абстрактные методы
- [ ] TInvestAdapter: 6 stub → реализация + subscribe_candles
- [ ] Rate Limiter: персистентность при restart
- [ ] Schemas: все request/response модели
- [ ] Router: все endpoints
- [ ] Service: оркестрация
- [ ] EventBus: публикация событий (order.placed, trade.filled, session.started/stopped)
- [ ] 30+ тестов, все зелёные
- [ ] pytest всего проекта: 0 failures
