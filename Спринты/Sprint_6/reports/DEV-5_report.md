# DEV-5 Report — T-Invest Stream Multiplex

**Sprint:** S6 | **Wave:** 2 | **Agent:** DEV-5 | **Status:** DONE

---

## 1. Реализовано

- **TInvestStreamMultiplexer** (`app/broker/tinvest/multiplexer.py`) — верифицирован и улучшен: удалён мёртвый `_sandbox_mode` property, исправлен backoff reset (сбрасывается только после первого успешного response, а не при входе в context manager), вынесен `_sleep()` для тестируемости.
- **TInvestAdapter** (`app/broker/tinvest/adapter.py`) — рефакторинг `subscribe_candles`/`unsubscribe` через multiplexer. Удалён `_stream_candles()` inner function и task-per-subscription паттерн. Lazy init через `_ensure_multiplexer()`. Удалены неиспользуемые импорты `asyncio`, `uuid`.
- Public API `subscribe_candles(ticker, tf, callback) → subscription_id` и `unsubscribe(subscription_id)` — **НЕ изменён**.

## 2. Файлы

| Файл | Действие |
|------|----------|
| `app/broker/tinvest/multiplexer.py` | Модифицирован (исправления) |
| `app/broker/tinvest/adapter.py` | Модифицирован (рефакторинг streaming) |
| `tests/unit/test_broker/test_tinvest_multiplexer.py` | Создан (6 тестов) |
| `tests/unit/test_broker/test_tinvest_subscribe_candles.py` | Переписан (4 теста) |

## 3. Тесты

- **6 новых** в `test_tinvest_multiplexer.py`: routing по figi, unsubscribe, reconnect+resubscribe, single stream, exponential backoff, active_subscriptions property.
- **4 обновлённых** в `test_tinvest_subscribe_candles.py`: multiplexer delegation, lazy init, unsubscribe delegation, disconnect stops multiplexer.
- `pytest tests/` (исключая notification — pre-existing import errors): **646 passed, 0 failures**.
- `ruff check .`: **0 errors**.

## 4. Integration Points

- `TInvestStreamMultiplexer(` создаётся в `adapter.py` (lazy init) — **CONNECTED**
- `market_data_stream(` — **одно** место: `multiplexer.py:194` (не в adapter)
- `_stream_candles` — **отсутствует** в adapter (старый метод удалён)
- `create_task` — **отсутствует** в adapter (task-per-subscription уд��лён)
- `StreamManager` (`app/market_data/stream_manager.py`) вызывает `adapter.subscribe_candles` / `adapter.unsubscribe` — API не изменён, совместимость сохранена.

## 5. Контракты

| Поставщик | Потребитель | Контракт | Статус |
|-----------|------------|----------|--------|
| DEV-3 | DEV-5 | SDK beta117+ в pyproject.toml | ✅ Подтверждён |
| DEV-5 | StreamManager | `subscribe_candles(ticker, tf, cb) → str` | ✅ API не изменён |
| DEV-5 | StreamManager | `unsubscribe(sub_id) → None` | ✅ API не изменён |

## 6. Проблемы

- Backoff reset в исходной версии multiplexer сбрасывался при входе в `async with AsyncClient`, что обнуляло delay при мгновенных disconnectах. Исправлено: delay сбрасывается только после первого успешного response.

## 7. Применённые Stack Gotchas

- **Gotcha 4** (tinvest-stream) — основная задача: persistent stream вместо task-per-subscription.
- **Gotcha 15** (tinvest-naive-datetime) — существующий `_to_utc_aware` в adapter не затронут рефакторингом.

## 8. Новые Stack Gotchas

Нет.
