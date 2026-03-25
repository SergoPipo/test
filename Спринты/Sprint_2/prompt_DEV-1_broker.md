---
sprint: 2
agent: DEV-1
role: Backend Core (BACK1) — T-Invest Broker Adapter
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #1 (senior). Реализуй абстрактный BrokerAdapter и конкретную реализацию для T-Invest (Тинькофф Инвестиции) через gRPC API.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/broker/ существует
3. Файл backend/app/broker/base.py существует (содержит стаб "# abstract BrokerAdapter")
4. Файл backend/app/broker/models.py существует (модель BrokerAccount)
5. Файл backend/app/config.py существует
6. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-1 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Модель BrokerAccount (уже в БД)

```python
# app/broker/models.py — УЖЕ СУЩЕСТВУЕТ, НЕ МЕНЯТЬ
class BrokerAccount(TimestampMixin, Base):
    __tablename__ = "broker_accounts"
    id: Mapped[int]
    user_id: Mapped[int]  # FK → users.id
    broker_type: Mapped[str]  # "tinvest"
    name: Mapped[str]
    encrypted_api_key: Mapped[bytes | None]  # LargeBinary
    encrypted_api_secret: Mapped[bytes | None]  # LargeBinary
    encryption_iv: Mapped[bytes | None]  # LargeBinary
    account_id: Mapped[str | None]
    account_type: Mapped[str | None]  # "broker", "iis"
    is_active: Mapped[bool]
    has_withdrawal_rights: Mapped[bool]
```

## Config (уже существует)

```python
# app/config.py — переменные, которые ТЫ ДОЛЖЕН ДОБАВИТЬ:
# TINVEST_SANDBOX: bool = True  # использовать sandbox T-Invest
```

**НЕ ДОБАВЛЯЙ** TINVEST_TOKEN в config — токен хранится в зашифрованном виде в BrokerAccount.

# Задачи

## 1. Абстрактный BrokerAdapter (`app/broker/base.py`)

Замени стаб полной реализацией:

```python
from abc import ABC, abstractmethod
from datetime import datetime
from decimal import Decimal

class BaseBrokerAdapter(ABC):
    """Абстрактный адаптер брокера."""

    @abstractmethod
    async def connect(self, api_key: str, api_secret: str | None = None) -> None:
        """Подключиться к API брокера."""

    @abstractmethod
    async def disconnect(self) -> None:
        """Отключиться от API брокера."""

    @abstractmethod
    async def get_accounts(self) -> list[BrokerAccountInfo]:
        """Получить список счетов."""

    @abstractmethod
    async def get_balance(self, account_id: str) -> AccountBalance:
        """Получить баланс счёта."""

    @abstractmethod
    async def get_historical_candles(
        self, ticker: str, timeframe: str,
        from_dt: datetime, to_dt: datetime
    ) -> list[CandleData]:
        """Загрузить исторические свечи."""

    # --- Заглушки для будущих спринтов (raise NotImplementedError) ---
    @abstractmethod
    async def get_positions(self, account_id: str) -> list: ...
    @abstractmethod
    async def place_order(self, ...) -> ...: ...
    @abstractmethod
    async def cancel_order(self, order_id: str) -> bool: ...
    @abstractmethod
    async def get_order_status(self, order_id: str) -> ...: ...
    @abstractmethod
    async def search_instruments(self, query: str) -> list: ...
    @abstractmethod
    async def get_instrument_info(self, ticker: str) -> ...: ...
```

Также определи dataclass-ы:

```python
from dataclasses import dataclass

@dataclass
class BrokerAccountInfo:
    account_id: str
    name: str
    type: str  # "broker", "iis"
    status: str  # "active", "closed"

@dataclass
class AccountBalance:
    total: Decimal
    currency: str
    available: Decimal

@dataclass
class CandleData:
    timestamp: datetime
    open: Decimal
    high: Decimal
    low: Decimal
    close: Decimal
    volume: int
```

## 2. T-Invest Adapter (`app/broker/tinvest/`)

Создай директорию `app/broker/tinvest/` с файлами:

### `__init__.py`
```python
from .adapter import TInvestAdapter
__all__ = ["TInvestAdapter"]
```

### `adapter.py` — `TInvestAdapter(BaseBrokerAdapter)`
- Использует `tinkoff.invest.AsyncClient` из SDK
- Sandbox-режим через `config.TINVEST_SANDBOX`
- Методы:
  - `connect(api_key)` — создаёт `AsyncClient(token=api_key)`
  - `disconnect()` — закрывает клиент
  - `get_accounts()` — `client.users.get_accounts()` → список `BrokerAccountInfo`
  - `get_balance(account_id)` — `client.operations.get_portfolio(account_id=...)` → `AccountBalance`
  - `get_historical_candles(ticker, tf, from_dt, to_dt)` — загрузка чанками:
    - Для дневных свечей: чанки по 1 году
    - Для минутных свечей: чанки по 1 дню
    - Используй `client.market_data.get_candles()`
  - Остальные методы: `raise NotImplementedError("Будет в Sprint 5")`
- Обработка ошибок: ловить `tinkoff.invest.exceptions` → поднимать `BrokerError` из `app.common.exceptions`

### `mapper.py` — `TInvestMapper`
- Конвертация Protobuf-объектов T-Invest в доменные модели:
  - `MoneyValue` → `Decimal` (units + nano / 1_000_000_000)
  - `Quotation` → `Decimal`
  - `HistoricCandle` → `CandleData`
  - `Account` → `BrokerAccountInfo`
  - Mapping таймфреймов: `{"1m": CandleInterval.CANDLE_INTERVAL_1_MIN, "5m": ..., "D": ..., ...}`

### `rate_limiter.py` — Token Bucket Rate Limiter
- 300 запросов в минуту (ограничение T-Invest API)
- `async def acquire()` — ожидает, если лимит исчерпан
- Потокобезопасный (asyncio.Lock)

## 3. BrokerFactory (`app/broker/factory.py`)

Замени стаб:

```python
class BrokerFactory:
    _registry: dict[str, type[BaseBrokerAdapter]] = {
        "tinvest": TInvestAdapter,
    }

    @classmethod
    def create(cls, broker_type: str) -> BaseBrokerAdapter:
        adapter_cls = cls._registry.get(broker_type)
        if not adapter_cls:
            raise ValueError(f"Unknown broker type: {broker_type}")
        return adapter_cls()
```

## 4. Pydantic Schemas (`app/broker/schemas.py`)

Создай файл (сейчас не существует):

```python
from pydantic import BaseModel, Field
from decimal import Decimal

class BrokerAccountCreate(BaseModel):
    broker_type: str = Field(..., pattern="^tinvest$")
    name: str = Field(..., min_length=1, max_length=100)
    api_key: str = Field(..., min_length=10)
    api_secret: str | None = None

class BrokerAccountUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    is_active: bool | None = None

class BrokerAccountResponse(BaseModel):
    id: int
    broker_type: str
    name: str
    account_id: str | None
    account_type: str | None
    is_active: bool
    # API-ключ НИКОГДА не возвращается в ответе

class BrokerAccountWithBalance(BrokerAccountResponse):
    balance: Decimal | None = None
    currency: str = "RUB"

class DiscoverRequest(BaseModel):
    broker_type: str
    api_key: str
    api_secret: str | None = None

class DiscoveredAccount(BaseModel):
    account_id: str
    name: str
    type: str
    status: str
```

## 5. Broker Service (`app/broker/service.py`)

Создай файл (сейчас не существует):

```python
class BrokerService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_account(self, user_id: int, data: BrokerAccountCreate) -> BrokerAccount:
        """Создать аккаунт. Шифрование ключа — заглушка (DEV-3 реализует CryptoService)."""
        # Пока сохраняй api_key как есть (без шифрования)
        # В DEV-4 / после мержа DEV-3 будет добавлено шифрование
        ...

    async def get_accounts(self, user_id: int) -> list[BrokerAccount]: ...
    async def get_account(self, account_id: int, user_id: int) -> BrokerAccount: ...
    async def update_account(self, account_id: int, user_id: int, data: BrokerAccountUpdate) -> BrokerAccount: ...
    async def delete_account(self, account_id: int, user_id: int) -> None: ...

    async def discover_accounts(self, data: DiscoverRequest) -> list[DiscoveredAccount]:
        """Подключиться к брокеру и получить список доступных счетов."""
        adapter = BrokerFactory.create(data.broker_type)
        await adapter.connect(data.api_key, data.api_secret)
        try:
            accounts = await adapter.get_accounts()
            return [DiscoveredAccount(...) for a in accounts]
        finally:
            await adapter.disconnect()
```

## 6. Broker Router (`app/broker/router.py`)

Создай файл (сейчас не существует):

```python
router = APIRouter(prefix="/api/v1/broker-accounts", tags=["broker"])

# POST   /api/v1/broker-accounts          — создать аккаунт
# GET    /api/v1/broker-accounts          — список аккаунтов
# GET    /api/v1/broker-accounts/{id}     — аккаунт с балансом
# PATCH  /api/v1/broker-accounts/{id}     — обновить
# DELETE /api/v1/broker-accounts/{id}     — удалить
# POST   /api/v1/broker-accounts/discover — обнаружить счета у брокера
```

Все endpoints требуют авторизацию (auth middleware из S1).

## 7. Зависимости (`pyproject.toml`)

Добавь в `[project] dependencies`:
```
"grpcio>=1.60",
"tinkoff-investments>=0.2.0",
```

## 8. Config

Добавь в `app/config.py` класс Settings:
```python
TINVEST_SANDBOX: bool = True
```

## 9. Подключение роутера

В `app/main.py` подключи broker router:
```python
from app.broker.router import router as broker_router
app.include_router(broker_router)
```

## 10. Тесты

Создай `tests/unit/test_broker/`:

### `test_base_adapter.py`
- test_base_adapter_is_abstract (нельзя создать экземпляр)
- test_candle_data_creation
- test_broker_account_info_creation
- test_account_balance_creation

### `test_mapper.py`
- test_money_value_to_decimal (units + nano)
- test_quotation_to_decimal
- test_candle_mapping
- test_account_mapping
- test_timeframe_mapping

### `test_rate_limiter.py`
- test_acquire_under_limit (мгновенный проход)
- test_acquire_at_limit (ожидание)

### `test_factory.py`
- test_create_tinvest_adapter
- test_create_unknown_broker_raises

### `test_broker_router.py`
- test_create_account (mock service)
- test_list_accounts (mock service)
- test_get_account (mock service)
- test_delete_account (mock service)
- test_discover_accounts (mock service)
- test_unauthorized_access_returns_401

**ВАЖНО:** Все тесты с T-Invest API должны использовать **mock** — НЕ подключаться к реальному API.

**Запусти тесты:**
```bash
cd backend && pip install -e .[dev] && pytest tests/ -v
```

# Конвенции

- Все I/O — async/await
- Именование: snake_case функции, PascalCase классы
- API-ключи **НИКОГДА** не логировать (используй structlog filter)
- Ошибки от брокера → raise `BrokerError` (из `app.common.exceptions`)
- Финансовые данные: `Decimal`, не `float`
- Каждый роутер: `APIRouter(prefix="/api/v1/{module}", tags=["{module}"])`

# Критерий завершения

- Абстрактный `BaseBrokerAdapter` с полным интерфейсом
- `TInvestAdapter` реализует: connect, disconnect, get_accounts, get_balance, get_historical_candles
- Rate limiter для T-Invest (300 req/min)
- BrokerFactory создаёт правильный адаптер
- CRUD router для broker-accounts
- Broker service с бизнес-логикой
- **Все тесты проходят: `pytest tests/ -v` — 0 failures**
- **~15-20 новых тестов**
