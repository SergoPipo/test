---
sprint: 2
agent: DEV-4
role: Backend (BACK1 + BACK2) — Market Data Service
wave: 2
depends_on: [DEV-1, DEV-2, DEV-3]
---

# Роль

Ты — Backend-разработчик. Реализуй Market Data Service — центральный сервис для загрузки, кеширования и валидации рыночных данных.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Файл backend/app/market_data/service.py существует (стаб)
3. Файл backend/app/market_data/models.py существует (OHLCVCache, Instrument)
4. Код DEV-1 (broker adapter) смержен в develop:
   - app/broker/base.py содержит BaseBrokerAdapter (не стаб)
   - app/broker/tinvest/adapter.py существует
5. Код DEV-2 (MOEX ISS) смержен в develop:
   - app/broker/moex_iss/client.py существует
   - app/scheduler/moex_calendar.py существует
6. Код DEV-3 (crypto) смержен в develop:
   - app/common/crypto.py содержит CryptoService (не стаб)
7. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-4 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Модели (уже в БД, НЕ МЕНЯТЬ)

```python
# app/market_data/models.py
class Instrument(Base):
    # ticker, figi, isin, name, type, currency, lot_size, min_price_increment, ...

class OHLCVCache(Base):
    # ticker, timeframe, timestamp, open, high, low, close, volume, source
    # UniqueConstraint("ticker", "timeframe", "timestamp", name="uq_ohlcv_lookup")
```

## BaseBrokerAdapter (от DEV-1)

```python
# app/broker/base.py
async def get_historical_candles(self, ticker, timeframe, from_dt, to_dt) -> list[CandleData]
```

## MOEXISSClient (от DEV-2)

```python
# app/broker/moex_iss/client.py
async def get_candles(self, ticker, timeframe, from_dt, to_dt) -> list[dict]
async def get_instrument_info(self, ticker) -> dict | None
async def search_instruments(self, query) -> list[dict]
```

## CryptoService (от DEV-3)

```python
# app/broker/crypto_helpers.py
def decrypt_broker_credentials(encrypted_key, encrypted_secret, iv) -> tuple[str, str | None]
```

# Задачи

## 1. Market Data Service (`app/market_data/service.py`)

Замени стаб полной реализацией:

```python
class MarketDataService:
    """Центральный сервис рыночных данных.

    Стратегия:
    1. Проверить кеш (ohlcv_cache) на наличие данных
    2. Определить пропуски (gaps)
    3. Загрузить недостающие данные:
       a. Первый источник: T-Invest (через BrokerAdapter)
       b. Fallback: MOEX ISS
    4. Сохранить в кеш
    5. Вернуть полный набор данных
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self._iss_client = MOEXISSClient(settings.MOEX_ISS_BASE_URL)

    async def get_candles(
        self, ticker: str, timeframe: str,
        from_dt: datetime, to_dt: datetime,
        user_id: int | None = None,
    ) -> list[CandleData]:
        """Получить свечи с автоматическим кешированием.

        Args:
            user_id: Если указан — попробовать загрузить через брокера пользователя.
                     Если нет — только MOEX ISS.
        """
        # 1. Проверить кеш
        cached = await self._get_cached(ticker, timeframe, from_dt, to_dt)

        # 2. Определить пропуски
        gaps = self._find_gaps(cached, from_dt, to_dt, timeframe)

        if not gaps:
            return cached

        # 3. Загрузить недостающие данные
        for gap_start, gap_end in gaps:
            new_candles = await self._fetch_candles(
                ticker, timeframe, gap_start, gap_end, user_id
            )
            # 4. Сохранить в кеш
            await self._save_to_cache(ticker, timeframe, new_candles)

        # 5. Вернуть полный набор
        return await self._get_cached(ticker, timeframe, from_dt, to_dt)

    async def _get_cached(self, ticker, timeframe, from_dt, to_dt) -> list[CandleData]:
        """Запросить данные из ohlcv_cache."""
        ...

    def _find_gaps(self, cached, from_dt, to_dt, timeframe) -> list[tuple[datetime, datetime]]:
        """Определить пропуски в кешированных данных."""
        ...

    async def _fetch_candles(self, ticker, timeframe, from_dt, to_dt, user_id) -> list[CandleData]:
        """Загрузить данные из источника (broker → ISS fallback)."""
        # Попытка 1: через брокер (если есть активный аккаунт)
        if user_id:
            try:
                return await self._fetch_via_broker(ticker, timeframe, from_dt, to_dt, user_id)
            except Exception:
                pass  # fallback to ISS

        # Попытка 2: через MOEX ISS
        return await self._fetch_via_iss(ticker, timeframe, from_dt, to_dt)

    async def _fetch_via_broker(self, ticker, tf, from_dt, to_dt, user_id) -> list[CandleData]:
        """Загрузить через T-Invest API."""
        ...

    async def _fetch_via_iss(self, ticker, tf, from_dt, to_dt) -> list[CandleData]:
        """Загрузить через MOEX ISS (fallback)."""
        ...

    async def _save_to_cache(self, ticker, timeframe, candles: list[CandleData]) -> None:
        """Сохранить свечи в ohlcv_cache (INSERT OR IGNORE для дубликатов)."""
        ...

    def _validate_candles(self, candles: list[CandleData]) -> list[CandleData]:
        """Валидация OHLCV:
        - open/high/low/close > 0
        - high >= max(open, close)
        - low <= min(open, close)
        - volume >= 0
        Невалидные свечи логируются и отбрасываются.
        """
        ...

    async def search_instruments(self, query: str) -> list[dict]:
        """Поиск инструментов через MOEX ISS."""
        return await self._iss_client.search_instruments(query)

    async def get_instrument_info(self, ticker: str) -> dict | None:
        """Информация об инструменте."""
        return await self._iss_client.get_instrument_info(ticker)
```

## 2. Market Data Schemas (`app/market_data/schemas.py`)

Замени стаб:

```python
from pydantic import BaseModel, Field
from datetime import datetime
from decimal import Decimal
from enum import Enum

class Timeframe(str, Enum):
    M1 = "1m"
    M5 = "5m"
    M15 = "15m"
    H1 = "1h"
    H4 = "4h"
    D = "D"
    W = "W"
    M = "M"

class CandleResponse(BaseModel):
    timestamp: datetime
    open: Decimal
    high: Decimal
    low: Decimal
    close: Decimal
    volume: int

class CandlesRequest(BaseModel):
    ticker: str = Field(..., min_length=1, max_length=20)
    timeframe: Timeframe
    from_dt: datetime
    to_dt: datetime

class InstrumentResponse(BaseModel):
    ticker: str
    name: str
    type: str
    currency: str
    lot_size: int

class InstrumentSearchResponse(BaseModel):
    results: list[InstrumentResponse]
    total: int

class MarketStatusResponse(BaseModel):
    status: str  # online, evening, auction, offline, weekend
    time_until_close: str | None  # "2ч 15м" или None
    is_trading_day: bool
```

## 3. Market Data Router (`app/market_data/router.py`)

Замени пустой router:

```python
router = APIRouter(prefix="/api/v1/market-data", tags=["market-data"])

# GET /api/v1/market-data/candles?ticker=SBER&timeframe=D&from=2024-01-01&to=2024-12-31
#   → list[CandleResponse]

# GET /api/v1/market-data/instruments?query=SBER
#   → InstrumentSearchResponse

# GET /api/v1/market-data/instruments/{ticker}
#   → InstrumentResponse

# GET /api/v1/market-data/market-status
#   → MarketStatusResponse
#   (использует MOEXCalendarService от DEV-2)
```

Endpoints candles и instruments требуют авторизацию.
Endpoint market-status — публичный (для footer).

## 4. Подключение роутера

В `app/main.py` — убедись, что market_data router подключён:
```python
from app.market_data.router import router as market_data_router
app.include_router(market_data_router)
```

## 5. Тесты

Создай `tests/unit/test_market_data/`:

### `test_service.py`
- test_get_candles_from_cache (все данные в кеше → не вызывает fetch)
- test_get_candles_cache_miss (пустой кеш → вызывает fetch → сохраняет)
- test_find_gaps_no_gaps
- test_find_gaps_full_gap
- test_find_gaps_partial (данные есть частично)
- test_fetch_fallback_to_iss (broker fails → ISS works)
- test_validate_candles_valid (все проходят)
- test_validate_candles_invalid_high (high < open → отброшена)
- test_save_to_cache_ignores_duplicates

### `test_router.py`
- test_get_candles_endpoint (mock service)
- test_search_instruments_endpoint (mock service)
- test_market_status_endpoint (mock calendar)
- test_candles_requires_auth
- test_market_status_is_public

### `test_schemas.py`
- test_timeframe_enum_values
- test_candles_request_validation
- test_candle_response_decimal

**Запусти тесты:**
```bash
cd backend && pip install -e .[dev] && pytest tests/ -v
```

# Конвенции

- Все I/O — async/await
- Финансовые данные: `Decimal`, не `float`
- INSERT OR IGNORE для кеша (uq_ohlcv_lookup не должен падать)
- Логирование через structlog: загрузка данных, пропуски, fallback
- Не грузить больше 1 года данных за один запрос

# Критерий завершения

- `MarketDataService` с кешированием и fallback (T-Invest → MOEX ISS)
- Определение пропусков в кеше
- Валидация OHLCV данных
- REST API endpoints для candles, instruments, market-status
- Pydantic schemas с Timeframe enum
- **Все тесты проходят: `pytest tests/ -v` — 0 failures**
- **~10-15 новых тестов**
