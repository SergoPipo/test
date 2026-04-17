# DEV-track2 Report — Верификация live-агрегации 1m->D/1h/4h

**Sprint:** S5R-2 | **Agent:** DEV-track2 | **Date:** 2026-04-17

## 1. Что реализовано

- 12 unit/integration-тестов для `_candle_period_start()` и `_AggregatingCandle` (задачи 2.1-2.4)
- Верификация timezone-корректности: Daily period = midnight UTC совпадает с T-Invest GetCandles API (gotcha-15 учтена)
- Интеграционный тест: `_AggregatingCandle.update()` -> `event_bus.publish()` -> subscriber queue
- Баги не обнаружены, код stream_manager.py не модифицирован (задача 2.5: фиксы не потребовались)

## 2. Файлы

| Файл | Действие |
|------|----------|
| `tests/test_market_data/__init__.py` | создан |
| `tests/test_market_data/test_stream_aggregation.py` | создан (12 тестов) |

Production-код (`app/market_data/stream_manager.py`) **не изменялся** — верификация подтвердила корректность.

## 3. Тесты

```
pytest tests/test_market_data/test_stream_aggregation.py → 12/12 passed
pytest tests/ → 619 passed, 0 failures (baseline 607 + 12 новых)
ruff check tests/test_market_data/ → All checks passed
```

Покрытие: `_candle_period_start()` (5 TF), `_AggregatingCandle` (60m->1h, period transition, daily, dict format), timezone (Daily midnight vs MOEX, 4h blocks), event_bus integration.

## 4. Integration points

- [x] `_AggregatingCandle` создаётся в production: `stream_manager.subscribe()` строка 142
- [x] `_candle_period_start()` вызывается в production: `_AggregatingCandle.update()` строка 69
- [x] `event_bus.publish()` вызывается с агрегированными данными: `_on_candle()` строка 162
- [x] Тесты зелёные: 12/12 passed
- [x] Регрессия отсутствует: 619/619 passed

## 5. Контракты

| Роль | Контракт | Статус |
|------|----------|--------|
| Поставщик: WS-сообщения с derived-TF | `event_bus.publish(channel, "candle.update", data)` где channel = `market:{ticker}:{tf}`, data = `{timestamp, open, high, low, close, volume}` | Подтверждён (строка 162 stream_manager.py) |

## 6. Проблемы

Нет. Агрегация верифицирована, багов не обнаружено.

## 7. Применённые Stack Gotchas

- **gotcha-15** (naive datetime UTC-offset): учтена при написании timezone-тестов (тесты 10-11). `CandleData.timestamp` — naive UTC, `_candle_period_start("D")` возвращает midnight UTC, что совпадает с T-Invest GetCandles API.
- **gotcha-04** (T-Invest stream reconnect): учтена при анализе `subscribe()` — `StreamManager` использует единое gRPC-соединение с мультиплексацией.

## 8. Новые Stack Gotchas

Новых ловушек не обнаружено, агрегация верифицирована. Поведение `_candle_period_start()` совпадает с T-Invest GetCandles API (midnight UTC для Daily).
