---
sprint: 2
agent: DEV-2
role: Backend #2 (BACK2) — MOEX ISS Client + Calendar
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #2. Реализуй клиент для MOEX ISS REST API (публичный источник рыночных данных) и Calendar Service (торговое расписание).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/ существует
3. Файл backend/app/config.py содержит MOEX_ISS_BASE_URL
4. httpx в зависимостях pyproject.toml
5. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-2 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Config

```python
# app/config.py — УЖЕ СУЩЕСТВУЕТ:
MOEX_ISS_BASE_URL: str = "https://iss.moex.com"
```

## Модели OHLCVCache и Instrument (уже в БД)

```python
# app/market_data/models.py — УЖЕ СУЩЕСТВУЮТ, НЕ МЕНЯТЬ
class Instrument(Base):
    ticker, figi, isin, name, type, currency, lot_size,
    min_price_increment, exchange, sector, is_active, updated_at

class OHLCVCache(Base):
    ticker, timeframe, timestamp, open, high, low, close, volume, source
    # UniqueConstraint("ticker", "timeframe", "timestamp", name="uq_ohlcv_lookup")
```

# Задачи

## 1. MOEX ISS Client (`app/broker/moex_iss/`)

Создай директорию `app/broker/moex_iss/` с файлами:

### `__init__.py`
```python
from .client import MOEXISSClient
__all__ = ["MOEXISSClient"]
```

### `client.py` — `MOEXISSClient`

HTTP-клиент для MOEX ISS REST API. Публичный API, авторизация **НЕ** требуется.

```python
import httpx
from decimal import Decimal
from datetime import datetime, date

class MOEXISSClient:
    def __init__(self, base_url: str = "https://iss.moex.com"):
        self.base_url = base_url
        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                timeout=httpx.Timeout(connect=10.0, read=30.0, write=10.0, pool=10.0),
            )
        return self._client

    async def close(self) -> None:
        if self._client:
            await self._client.aclose()
            self._client = None

    async def get_candles(
        self, ticker: str, timeframe: str,
        from_dt: date, to_dt: date
    ) -> list[dict]:
        """Загрузить свечи с MOEX ISS.

        URL: /iss/engines/stock/markets/shares/securities/{ticker}/candles.json
        Параметры: interval, from, till, start (для пагинации)

        Mapping таймфреймов ISS:
          "1m" → 1, "10m" → 10, "1h" → 60, "D" → 24, "W" → 7, "M" → 31
        """
        ...

    async def get_instrument_info(self, ticker: str) -> dict | None:
        """Информация об инструменте.

        URL: /iss/securities/{ticker}.json
        """
        ...

    async def get_trading_calendar(self, year: int | None = None) -> list[dict]:
        """Торговый календарь MOEX.

        URL: /iss/engines/stock/markets/shares/dates.json
        """
        ...

    async def search_instruments(self, query: str) -> list[dict]:
        """Поиск инструментов.

        URL: /iss/securities.json?q={query}
        """
        ...
```

**Формат ответа MOEX ISS:**
```json
{
  "candles": {
    "metadata": { "open": {"type": "double"}, ... },
    "columns": ["open", "close", "high", "low", "value", "volume", "begin", "end"],
    "data": [
      [287.5, 288.0, 289.0, 286.5, 1234567.89, 42000, "2024-01-15 10:00:00", "2024-01-15 11:00:00"],
      ...
    ]
  }
}
```

Парсинг: zip(columns, row) для каждой строки data.

**Обработка ошибок:**
- 5xx → retry с exponential backoff (1s → 2s → 4s, макс 3 попытки)
- 4xx → raise `BrokerError`
- Пустой ответ (data = []) → вернуть пустой список, не ошибку

**Пагинация:**
- ISS возвращает max 500 свечей за запрос
- Используй параметр `start` для получения следующей страницы
- Продолжай, пока `data` не пуст

### `parser.py` — Парсер ответов ISS

```python
class MOEXISSParser:
    @staticmethod
    def parse_candles(raw: dict) -> list[CandleData]:
        """Конвертировать ответ ISS в список CandleData."""
        ...

    @staticmethod
    def parse_instrument(raw: dict) -> dict:
        """Извлечь информацию об инструменте из ответа ISS."""
        ...

    @staticmethod
    def parse_calendar(raw: dict) -> list[date]:
        """Извлечь торговые дни из ответа ISS."""
        ...
```

## 2. MOEX Calendar Service (`app/scheduler/moex_calendar.py`)

Создай файл (scheduler/service.py — стаб):

```python
from datetime import date, time, datetime, timedelta
import zoneinfo

MOSCOW_TZ = zoneinfo.ZoneInfo("Europe/Moscow")

class MOEXCalendarService:
    """Сервис торгового расписания MOEX."""

    # Расписание основной сессии (фондовый рынок)
    MARKET_OPEN = time(10, 0)   # 10:00 МСК
    MARKET_CLOSE = time(18, 50) # 18:50 МСК
    EVENING_OPEN = time(19, 5)  # 19:05 МСК
    EVENING_CLOSE = time(23, 50)  # 23:50 МСК

    def __init__(self, iss_client: MOEXISSClient | None = None):
        self._iss_client = iss_client
        self._trading_days_cache: set[date] | None = None

    async def load_calendar(self, year: int | None = None) -> None:
        """Загрузить торговый календарь из ISS (или использовать fallback)."""
        ...

    def is_trading_day(self, d: date) -> bool:
        """Торговый ли день? Fallback: пн-пт, исключая известные праздники."""
        ...

    def get_trading_hours(self, d: date) -> tuple[time, time] | None:
        """Время работы рынка (open, close). None если выходной."""
        ...

    def get_next_trading_day(self, d: date) -> date:
        """Следующий торговый день."""
        ...

    def time_until_close(self) -> timedelta | None:
        """Время до закрытия рынка. None если рынок закрыт."""
        ...

    def get_market_status(self) -> str:
        """Текущий статус: 'online', 'evening', 'auction', 'offline', 'weekend'."""
        ...
```

**Fallback-расписание** (если ISS недоступен):
- Рабочие дни: пн-пт
- Известные праздники РФ (1-8 января, 23 февраля, 8 марта, 1 мая, 9 мая, 12 июня, 4 ноября)
- Основная сессия: 10:00–18:50 МСК
- Вечерняя сессия: 19:05–23:50 МСК

## 3. API endpoints для календаря

Добавь в существующий `app/market_data/router.py`:

```python
# GET /api/v1/market-data/market-status  → {"status": "online", "time_until_close": "2h 15m"}
# GET /api/v1/market-data/calendar       → {"is_trading_day": true, "next_trading_day": "2024-01-16"}
```

## 4. Тесты

Создай `tests/unit/test_moex_iss/`:

### `test_client.py`
- test_get_candles_parses_response (mock httpx с фикстурой JSON)
- test_get_candles_empty_response (пустой data)
- test_get_candles_pagination (несколько страниц)
- test_get_instrument_info (mock)
- test_search_instruments (mock)
- test_retry_on_5xx (mock 500 → 500 → 200)
- test_raise_on_4xx (mock 404)

### `test_parser.py`
- test_parse_candles_correct_fields
- test_parse_candles_decimal_precision
- test_parse_instrument

### `test_calendar.py`
- test_is_trading_day_weekday (пн = True)
- test_is_trading_day_weekend (сб = False)
- test_is_trading_day_holiday (1 января = False)
- test_time_until_close_during_session
- test_time_until_close_after_close (None)
- test_get_market_status_online
- test_get_market_status_offline
- test_get_next_trading_day

**Запусти тесты:**
```bash
cd backend && pip install -e .[dev] && pytest tests/ -v
```

# Конвенции

- Все I/O — async/await
- Именование: snake_case функции, PascalCase классы
- Финансовые данные: `Decimal`, не `float`
- Даты: UTC в БД, МСК для логики расписания
- Структурированное логирование через structlog

# Критерий завершения

- `MOEXISSClient` с методами: get_candles, get_instrument_info, get_trading_calendar, search_instruments
- `MOEXISSParser` для парсинга JSON-ответов ISS
- `MOEXCalendarService` с расписанием и fallback
- API endpoints: market-status, calendar
- **Все тесты проходят: `pytest tests/ -v` — 0 failures**
- **~10-12 новых тестов**
