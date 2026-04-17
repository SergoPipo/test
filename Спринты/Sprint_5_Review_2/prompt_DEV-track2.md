---
sprint: S5R-2
agent: DEV-track2
role: "Backend — верификация live-агрегации 1m→D/1h/4h"
wave: 3
depends_on: []
---

# Роль

Ты — Backend-разработчик (senior), специалист по рыночным данным и time-series агрегации. Твоя задача: **верифицировать** корректность существующей live-агрегации 1m-свечей в D/1h/4h в `stream_manager.py`, написать исчерпывающие unit-тесты, проверить timezone-корректность (gotcha-15), исправить баги если найдены. Работаешь в `Develop/backend/`.

**Ключевое:** `stream_manager.py` УЖЕ содержит класс `_AggregatingCandle` и функцию `_candle_period_start()`, которые реализуют агрегацию. Тесты НЕ написаны, end-to-end не проверялось. **НЕ переписывай с нуля** — верифицируй, тестируй, фикси.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python >= 3.11
2. Зависимости предыдущих DEV: нет (трек 2 параллелен треку 1)
3. Существующие файлы:
   - app/market_data/stream_manager.py   — _candle_period_start() (строки 34-52), _AggregatingCandle (строки 55-93), subscribe() (строки 120-181)
   - app/broker/base.py                  — CandleData dataclass (строки 28-37)
   - app/common/event_bus.py             — EventBus singleton (строки 15-76)
   - tests/conftest.py                   — test_db, async_client фикстуры
4. База данных: не применимо (in-memory агрегация, без миграций)
5. Внешние сервисы: нет (тесты mock'ают CandleData)
6. Тесты baseline: `pytest tests/` → 0 failures
```

Выполни реальный запуск `pytest tests/` и `ruff check .` при предпроверке и зафиксируй фактические результаты.

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — ищи gotcha по слоям:
   - **gotcha-04** (`gotcha-04-tinvest-stream-reconnect.md`) — T-Invest stream reconnect: гарантии доставки, дубли при reconnect, пропуски при обрыве. Учти при написании integration-теста.
   - **gotcha-15** (`gotcha-15-naive-datetime-utc-offset.md`) — naive datetime UTC-offset: `CandleData.timestamp` — naive UTC. При агрегации Daily/Weekly нужно учитывать, что midnight UTC ≠ начало торгового дня MOEX (07:00 UTC / 10:00 MSK).

3. **`Спринты/Sprint_5_Review_2/execution_order.md`** — Cross-DEV contracts: трек 2 — **поставщик** WS-сообщений с derived-TF для существующего WS-клиента на фронте.

4. **Цитаты из кода (по состоянию на 2026-04-17):**

   > **stream_manager.py — `_candle_period_start()` (строки 34-52):**
   > ```python
   > def _candle_period_start(dt: datetime, timeframe: str) -> datetime:
   >     """Определить начало текущего периода свечи для заданного таймфрейма."""
   >     if timeframe == "1m":
   >         return dt.replace(second=0, microsecond=0)
   >     elif timeframe == "5m":
   >         return dt.replace(minute=dt.minute - dt.minute % 5, second=0, microsecond=0)
   >     elif timeframe == "15m":
   >         return dt.replace(minute=dt.minute - dt.minute % 15, second=0, microsecond=0)
   >     elif timeframe == "1h":
   >         return dt.replace(minute=0, second=0, microsecond=0)
   >     elif timeframe == "4h":
   >         return dt.replace(hour=dt.hour - dt.hour % 4, minute=0, second=0, microsecond=0)
   >     elif timeframe == "D":
   >         return dt.replace(hour=0, minute=0, second=0, microsecond=0)
   >     elif timeframe == "W":
   >         weekday = dt.weekday()
   >         return (dt - timedelta(days=weekday)).replace(hour=0, minute=0, second=0, microsecond=0)
   >     else:  # M
   >         return dt.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
   > ```
   >
   > **⚠️ ПОТЕНЦИАЛЬНЫЙ БАГ:** `_candle_period_start("D")` возвращает `dt.replace(hour=0)` — midnight UTC. Но торговый день MOEX начинается в 07:00 UTC (10:00 MSK). Свечи вечерней сессии (после 21:00 UTC / 00:00 MSK следующего дня) попадут в СЛЕДУЮЩИЙ торговый день по UTC, но в ТОТ ЖЕ торговый день по MOEX. Для viewer-режима это допустимо (T-Invest GetCandles тоже отдаёт Daily с midnight UTC), но нужно **верифицировать** совпадение с T-Invest API.

   > **stream_manager.py — `_AggregatingCandle` (строки 55-93):**
   > ```python
   > class _AggregatingCandle:
   >     """Агрегирует минутные свечи в текущую формирующуюся свечу."""
   >
   >     def __init__(self, timeframe: str):
   >         self.timeframe = timeframe
   >         self.period_start: datetime | None = None
   >         self.open: Decimal = Decimal("0")
   >         self.high: Decimal = Decimal("0")
   >         self.low: Decimal = Decimal("0")
   >         self.close: Decimal = Decimal("0")
   >         self.volume: int = 0
   >
   >     def update(self, candle: CandleData) -> dict:
   >         """Обновить агрегированную свечу. Возвращает данные для публикации."""
   >         period = _candle_period_start(candle.timestamp, self.timeframe)
   >         if self.period_start != period:
   >             # Новый период — начать свечу заново
   >             self.period_start = period
   >             self.open = candle.open
   >             self.high = candle.high
   >             self.low = candle.low
   >             self.close = candle.close
   >             self.volume = candle.volume
   >         else:
   >             # Тот же период — обновить
   >             self.high = max(self.high, candle.high)
   >             self.low = min(self.low, candle.low)
   >             self.close = candle.close
   >             self.volume += candle.volume
   >         return {
   >             "timestamp": self.period_start.isoformat(),
   >             "open": float(self.open),
   >             "high": float(self.high),
   >             "low": float(self.low),
   >             "close": float(self.close),
   >             "volume": self.volume,
   >         }
   > ```

   > **stream_manager.py — `subscribe()` (строки 120-181), фрагмент:**
   > ```python
   > needs_aggregation = timeframe not in ("1m", "5m")
   > aggregator = _AggregatingCandle(timeframe) if needs_aggregation else None
   > stream_tf = "1m" if needs_aggregation else timeframe
   >
   > async def _on_candle(candle: CandleData) -> None:
   >     if aggregator:
   >         data = aggregator.update(candle)
   >     else:
   >         data = {"timestamp": candle.timestamp.isoformat(), ...}
   >     await event_bus.publish(channel, "candle.update", data)
   > ```

   > **broker/base.py — `CandleData` (строки 28-37):**
   > ```python
   > @dataclass
   > class CandleData:
   >     timestamp: datetime   # naive UTC
   >     open: Decimal
   >     high: Decimal
   >     low: Decimal
   >     close: Decimal
   >     volume: int
   > ```

   > **event_bus.py — `EventBus` (строки 15-76):**
   > ```python
   > async def publish(self, channel: str, event: str, data: dict[str, Any]) -> None:
   >     message = {"channel": channel, "event": event, "data": data}
   >     for sub_id, queue in subscribers.items():
   >         queue.put_nowait(message)
   > ```
   > Глобальный singleton: `event_bus = EventBus()`

   > **conftest.py — фикстуры (строки 1-53):**
   > - `test_db` — AsyncSession с in-memory SQLite
   > - `async_client` — AsyncClient с ASGI транспортом

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

```
- app/market_data/stream_manager.py  — _candle_period_start(), _AggregatingCandle, subscribe(). ВЕРИФИЦИРУЕМ, фиксим баги если есть. НЕ переписывать.
- app/broker/base.py                 — CandleData dataclass. НЕ модифицировать.
- app/common/event_bus.py            — EventBus singleton. НЕ модифицировать.
- tests/conftest.py                  — фикстуры test_db, async_client. Можно расширить, не ломать.
```

# Задачи

## Задача 2.1: Unit-тесты `_candle_period_start()`

Создать файл `tests/test_market_data/test_stream_aggregation.py`.

**Тесты:**

1. **`test_period_start_1h`** — `datetime(2026,4,17, 10,30,15)` → `datetime(2026,4,17, 10,0,0)`
2. **`test_period_start_4h`** — `datetime(2026,4,17, 10,30)` → `datetime(2026,4,17, 8,0,0)` (час 10 → блок [8-12))
3. **`test_period_start_D`** — `datetime(2026,4,17, 15,30)` → `datetime(2026,4,17, 0,0,0)` (midnight UTC)
4. **`test_period_start_W`** — среда 2026-04-15 → понедельник 2026-04-13 00:00:00
5. **`test_period_start_M`** — 17 апреля → 1 апреля 00:00:00

```python
from datetime import datetime
from app.market_data.stream_manager import _candle_period_start

def test_period_start_1h():
    dt = datetime(2026, 4, 17, 10, 30, 15)
    result = _candle_period_start(dt, "1h")
    assert result == datetime(2026, 4, 17, 10, 0, 0)

def test_period_start_4h():
    dt = datetime(2026, 4, 17, 10, 30)
    result = _candle_period_start(dt, "4h")
    assert result == datetime(2026, 4, 17, 8, 0, 0)

def test_period_start_D():
    dt = datetime(2026, 4, 17, 15, 30)
    result = _candle_period_start(dt, "D")
    assert result == datetime(2026, 4, 17, 0, 0, 0)

def test_period_start_W():
    # 2026-04-15 = Wednesday → Monday 2026-04-13
    dt = datetime(2026, 4, 15, 12, 0)
    result = _candle_period_start(dt, "W")
    assert result == datetime(2026, 4, 13, 0, 0, 0)

def test_period_start_M():
    dt = datetime(2026, 4, 17, 9, 15)
    result = _candle_period_start(dt, "M")
    assert result == datetime(2026, 4, 1, 0, 0, 0)
```

## Задача 2.2: Unit-тесты `_AggregatingCandle`

В том же файле `tests/test_market_data/test_stream_aggregation.py`:

6. **`test_aggregate_60m_to_1h`** — создать `_AggregatingCandle("1h")`, скормить 60 `CandleData` с `timestamp` от 10:00 до 10:59, по одному тику на минуту. Проверить:
   - `open` = open первого тика (10:00)
   - `high` = max(high всех 60 тиков)
   - `low` = min(low всех 60 тиков)
   - `close` = close последнего тика (10:59)
   - `volume` = sum(volume всех 60 тиков)

7. **`test_aggregate_period_transition`** — тики в 10:58, 10:59, 11:00 для `_AggregatingCandle("1h")`:
   - После тика 10:58 и 10:59: `period_start` = `datetime(2026,4,17, 10,0,0)`
   - После тика 11:00: `period_start` = `datetime(2026,4,17, 11,0,0)` (новая свеча!)
   - `open` = open тика 11:00, `volume` = volume тика 11:00 (не накопленная сумма)

8. **`test_aggregate_daily`** — тики за 1 торговый день (допустим, 10:00-18:45 UTC с интервалом 1m) → 1 Daily свеча. `period_start` = midnight UTC того дня.

9. **`test_aggregate_returns_dict`** — проверить формат возврата `update()`:
   - `timestamp` — строка в isoformat
   - `open`, `high`, `low`, `close` — `float`
   - `volume` — `int`

```python
from decimal import Decimal
from app.market_data.stream_manager import _AggregatingCandle
from app.broker.base import CandleData

def _make_candle(dt: datetime, o: str, h: str, l: str, c: str, v: int) -> CandleData:
    """Хелпер для создания CandleData из строковых Decimal."""
    return CandleData(
        timestamp=dt,
        open=Decimal(o), high=Decimal(h),
        low=Decimal(l), close=Decimal(c),
        volume=v,
    )
```

## Задача 2.3: Верификация timezone-корректности

10. **`test_period_start_D_midnight_vs_moex`** — T-Invest отдаёт `datetime` в naive UTC. Daily-свеча `_candle_period_start("D")` начинается с midnight UTC.
    - Тик в `datetime(2026,4,17, 21,30)` (вечерняя сессия MOEX, 00:30 MSK 18 апреля) → `period_start = datetime(2026,4,17, 0,0,0)` (17 апреля UTC).
    - Тик в `datetime(2026,4,18, 0,30)` (после полуночи UTC, 03:30 MSK) → `period_start = datetime(2026,4,18, 0,0,0)` (18 апреля UTC).
    - **Задокументировать:** совпадает ли это с T-Invest GetCandles API? Если да — оставить, если нет — фиксить.
    - **Ожидание:** T-Invest GetCandles для Daily тоже использует midnight UTC (подтверждено API-документацией), поэтому текущая логика **корректна**. Если тест покажет иное — эскалировать.

11. **`test_period_start_4h_moex_session`** — проверить, что блоки 4h правильно выровнены:
    - `[0-4)`, `[4-8)`, `[8-12)`, `[12-16)`, `[16-20)`, `[20-24)` по UTC.
    - Торговая сессия MOEX: 07:00-15:45 UTC (основная) + вечерняя до 20:50 UTC.
    - Тик 07:00 UTC → блок `[4-8)`, `period_start = 04:00`.
    - Тик 11:59 UTC → блок `[8-12)`, `period_start = 08:00`.
    - Тик 20:30 UTC → блок `[20-24)`, `period_start = 20:00`.

## Задача 2.4: Интеграционный тест `publish → event_bus`

12. **`test_on_candle_publishes_aggregated`** — integration-тест:
    - Импортировать `event_bus` singleton из `app.common.event_bus`
    - Подписаться на event_bus канал `"market:SBER:1h"`
    - Создать `_AggregatingCandle("1h")`
    - Скормить 3 тика (10:00, 10:01, 10:02)
    - Для каждого тика: вызвать `aggregator.update(candle)`, затем `await event_bus.publish("market:SBER:1h", "candle.update", data)`
    - Проверить, что подписчик получил 3 сообщения
    - Проверить, что данные корректно агрегированы: `open` = open первого тика, `high` растёт, `volume` накапливается

```python
import asyncio
import pytest
from app.common.event_bus import event_bus

@pytest.mark.asyncio
async def test_on_candle_publishes_aggregated():
    # setup: подписаться на канал
    queue = asyncio.Queue()
    sub_id = event_bus.subscribe("market:SBER:1h", queue)
    try:
        agg = _AggregatingCandle("1h")
        candles = [
            _make_candle(datetime(2026,4,17,10,0), "100","102","99","101", 1000),
            _make_candle(datetime(2026,4,17,10,1), "101","105","100","104", 1500),
            _make_candle(datetime(2026,4,17,10,2), "104","106","103","105", 800),
        ]
        for c in candles:
            data = agg.update(c)
            await event_bus.publish("market:SBER:1h", "candle.update", data)

        # Проверить 3 сообщения
        messages = []
        while not queue.empty():
            messages.append(queue.get_nowait())
        assert len(messages) == 3

        last = messages[-1]["data"]
        assert last["open"] == 100.0          # open первого тика
        assert last["high"] == 106.0          # max high всех 3
        assert last["low"] == 99.0            # min low всех 3
        assert last["close"] == 105.0         # close последнего
        assert last["volume"] == 3300         # 1000+1500+800
    finally:
        event_bus.unsubscribe(sub_id)
```

> **Примечание:** API `event_bus.subscribe()` / `event_bus.unsubscribe()` может отличаться — проверь реальную сигнатуру в `app/common/event_bus.py` и адаптируй тест. Ключевое: подписаться, опубликовать, прочитать из очереди, проверить данные.

## Задача 2.5: Фикс багов (если найдены)

Если тесты обнаруживают ошибки:
- Исправить `_candle_period_start()` и/или `_AggregatingCandle.update()`
- **НЕ переписывать** модуль целиком — точечные фиксы
- Если баг в timezone (Daily period = midnight UTC vs MOEX trading day):
  - **Если T-Invest GetCandles API тоже использует midnight UTC** → оставить как есть, задокументировать
  - **Если T-Invest использует MSK midnight (07:00 UTC)** → переключить `_candle_period_start("D")` на `dt.replace(hour=7, minute=0, second=0, microsecond=0)` для совпадения с API
  - В любом случае: добавить комментарий в коде с обоснованием

## Задача 2.6: Stack Gotcha (если обнаружена)

Если найден баг — создать описание новой gotcha в секции 8 отчёта в формате: симптом / причина / правило / related_files. ARCH создаст файл `gotcha-<N+1>-*.md` после приёмки.

Если багов не найдено: «Новых ловушек не обнаружено, агрегация верифицирована. Поведение `_candle_period_start()` совпадает с T-Invest GetCandles API (midnight UTC для Daily).»

# Тесты

```
tests/test_market_data/
└── test_stream_aggregation.py    # 12 тестов (задачи 2.1-2.4)
```

**Минимум:** 12 тестов.

**Фикстуры:** стандартные pytest + `pytest-asyncio` для integration-теста. Для event_bus теста — cleanup подписки в `finally`. Хелпер `_make_candle()` для создания `CandleData`.

# ⚠️ Integration Verification Checklist

- [ ] **`_AggregatingCandle` используется в production:**
  `grep -rn "_AggregatingCandle(" app/` — класс создаётся в `stream_manager.subscribe()` (строка ~138). Подтвердить.

- [ ] **`_candle_period_start()` вызывается в production:**
  `grep -rn "_candle_period_start(" app/` — вызывается в `_AggregatingCandle.update()` (строка ~72). Подтвердить.

- [ ] **`event_bus.publish()` вызывается с агрегированными данными:**
  `grep -rn "event_bus.publish" app/market_data/stream_manager.py` — вызывается в `_on_candle()` (строка ~162). Подтвердить.

- [ ] **Тесты зелёные:**
  `pytest tests/test_market_data/test_stream_aggregation.py` → 12/12 passed, 0 failures.

- [ ] **Общий тест-сьют не сломан:**
  `pytest tests/` → 0 failures (регрессия отсутствует).

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.

Сохрани отчёт как файл: **`Спринты/Sprint_5_Review_2/reports/DEV-track2_report.md`**.

**НЕ возвращай:**
- Полный код реализованных файлов (их видно через `git diff`)
- Полный лог tool-вызовов
- Подробные объяснения каждого решения

**Верни** 8 секций: Что реализовано / Файлы / Тесты / Integration points / Контракты / Проблемы / Применённые Stack Gotchas / Новые Stack Gotchas.

# Чеклист перед сдачей

- [ ] Задачи 2.1–2.6 реализованы
- [ ] `pytest tests/` → 0 failures (включая 12+ новых)
- [ ] `ruff check .` → 0 errors
- [ ] Integration verification checklist пройден (4 пункта)
- [ ] Формат отчёта соблюдён — все 8 секций заполнены
- [ ] Отчёт сохранён в `Спринты/Sprint_5_Review_2/reports/DEV-track2_report.md`
- [ ] Существующий стриминг 1m/5m НЕ сломан (регрессия отсутствует)
- [ ] Cross-DEV contract: подтверждена публикация WS-сообщений с derived-TF через event_bus
- [ ] Если баг найден — исправлен точечно и задокументирован (gotcha в секции 8)
- [ ] Если баг НЕ найден — явно указано: «Агрегация верифицирована, багов не обнаружено»
- [ ] НЕ модифицирован frontend
- [ ] Используется structlog для логирования (если добавлены новые логи)
