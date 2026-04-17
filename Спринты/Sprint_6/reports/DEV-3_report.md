---
sprint: S6
agent: DEV-3
wave: 1
status: DONE
---

# DEV-3 Report — T-Invest SDK Upgrade (beta59 -> beta117)

## 1. Реализовано

- SDK `tinkoff-investments` обновлён с `0.2.0b59` до `0.2.0b117` (публичный тег GitHub).
- Все 10 импортируемых классов SDK (`AsyncClient`, `InstrumentIdType`, `CandleInterval`, `OrderDirection`, `OrderType`, `CandleInstrument`, `MarketDataRequest`, `SubscribeCandlesRequest`, `SubscriptionAction`, `SubscriptionInterval`) проверены — breaking changes не обнаружены, API совместим.
- `sys.modules` stub (Gotcha 14) удалён из `test_tinvest_subscribe_candles.py` — тесты используют реальные импорты SDK.
- SDK зафиксирован в `pyproject.toml` dependencies — CI (`pip install -e .[dev]`) подхватывает автоматически, без дополнительных хаков.
- Исправлены 4 предшествующих E402 ошибки ruff в `adapter.py` (функция `_to_utc_aware` перемещена после import-блока).

## 2. Файлы

- `app/broker/tinvest/adapter.py` — перемещение `_to_utc_aware` после import-блока (fix E402)
- `tests/unit/test_broker/test_tinvest_subscribe_candles.py` — удалён sys.modules stub, обновлён docstring
- `pyproject.toml` — добавлен `tinkoff-investments @ git+...@0.2.0-beta117` в dependencies

## 3. Тесты

- Baseline до изменений: 625 passed
- После изменений: 625 passed (0 failures, 0 новых тестов — задача infra)
- `pytest tests/unit/test_broker/ -v` — 55 passed

## 4. Integration Points

- `app/broker/tinvest/adapter.py` — все SDK-вызовы (`AsyncClient`, streaming, orders, portfolio) совместимы с beta117
- `app/broker/tinvest/mapper.py` — без изменений, enum-маппинг корректен
- `app/market_data/stream_manager.py` — без изменений, использует adapter
- `app/market_data/service.py:687` — lazy import AsyncClient, совместим

## 5. Контракты

| Контракт | Роль | Статус |
|----------|------|--------|
| SDK beta117+ установлен, зафиксирован в pyproject.toml | Поставщик -> DEV-5 (волна 2, Stream Multiplex) | CONFIRMED |

## 6. Проблемы

Нет блокирующих проблем. SDK beta117 полностью обратно совместим с beta59 по всем используемым классам и методам.

## 7. Применённые Stack Gotchas

- **Gotcha 4** (tinvest-stream): проверено — streaming API (`market_data_stream.market_data_stream(request_iterator)`) не изменился в beta117.
- **Gotcha 14** (sdk-sys-modules-stub): stub удалён, SDK добавлен в dependencies, тесты используют реальные импорты.
- **Gotcha 15** (tinvest-naive-datetime): `_to_utc_aware` по-прежнему применяется, формат timestamps не изменился.

## 8. Новые Stack Gotchas

Не обнаружены.

## Чеклист

- [x] `pip show tinkoff-investments` -> 0.2.0b117
- [x] `sys.modules` stub удалён
- [x] `pyproject.toml` фиксирует версию
- [x] `ruff check .` -> 0 errors
- [x] `pytest tests/` -> 625 passed, 0 failures
- [x] CI workflow — PASS (SDK подхватывается через `pip install -e .[dev]`)
