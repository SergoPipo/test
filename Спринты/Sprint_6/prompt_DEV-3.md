---
sprint: S6
agent: DEV-3
role: "Backend Infra (BACK3) — T-Invest SDK Upgrade (beta59 → beta117+)"
wave: 1
depends_on: [DEV-0]
---

# Роль

Ты — Backend-разработчик #3 (senior), специалист по внешним SDK и gRPC-интеграциям. Твоя задача — обновить SDK `tinkoff-investments` с локального `0.2.0b59` (непроизводимого) до актуального публичного тега `0.2.0-beta117` (или новее), адаптировать все точки использования, убрать `sys.modules` stub из тестов.

Работаешь в `Develop/backend/`.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python >= 3.11
2. Текущий SDK: pip show tinkoff-investments → проверь версию (ожидается 0.2.0b59)
3. Существующие файлы с import tinkoff:
   - app/broker/tinvest/adapter.py        — TInvestAdapter (853 строки)
   - app/broker/tinvest/mapper.py          — TInvestMapper
   - app/market_data/stream_manager.py     — MarketDataStreamManager
   - tests/unit/test_broker/test_tinvest_subscribe_candles.py — содержит sys.modules stub
4. Доступность beta117: проверь
   pip install --dry-run "tinkoff-investments @ git+https://github.com/RussianInvestments/invest-python.git@0.2.0-beta117"
   Если ошибка транзитивных deps — зафиксируй какие именно.
5. Тесты baseline: `pytest tests/` → 0 failures
```

> **Правило от S5R.5:** предпроверку выполняй **реально** (запусти pip, проверь выход). Зафиксируй фактические результаты в отчёте.

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — особенно:
   - **Gotcha 4** (`gotcha-04-tinvest-stream.md`) — T-Invest gRPC streaming: persistent connection, rate-limit 429. Правило: StreamManager владеет одним stream, мультиплексирует. Текущий adapter нарушает — DEV-5 починит в волне 2, но ты должен убедиться, что SDK upgrade не усложняет это.
   - **Gotcha 14** (`gotcha-14-sdk-sys-modules-stub.md`) — sys.modules stub для SDK в CI. Твоя задача — убрать этот stub после апгрейда.
   - **Gotcha 15** (`gotcha-15-tinvest-naive-datetime.md`) — UTC-offset в свечах/операциях. Проверь, что beta117 не изменяет формат timestamps.

3. **`Спринты/Sprint_6/execution_order.md`** раздел **«Cross-DEV contracts»**:
   - Ты **поставщик** контракта: обновлённый SDK beta117+ → для DEV-5 (волна 2, Stream Multiplex).

4. **`Спринты/Sprint_6/backlog.md`** секция **«S6-TINVEST-SDK-UPGRADE»** — полный контекст задачи.

5. **Цитаты из backlog (дословно):**

   > «Локальный baseline разработчика — tinkoff-investments 0.2.0b59, установлен из квартин'еного PyPI. Этого тега нет в GitHub RussianInvestments/invest-python. Попытки установить любой актуальный тег в CI ломают на транзитивных зависимостях. SDK beta117 имеет breaking changes по сравнению с beta59 — часть протобуф-классов переименована или перемещена.»

   > «Wave 3 обошла проблему через stub sys.modules в тесте (Gotcha 14), но это заплатка, не решение. На проде backend использует реальный SDK, и текущий baseline beta59 недокументирован и непроизводим.»

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

```
- app/broker/tinvest/adapter.py        — TInvestAdapter: connect(), disconnect(), get_accounts(), get_balance(), get_positions(), get_real_positions(), get_real_operations(), get_historical_candles(), place_order(), subscribe_candles(), unsubscribe(). Импортирует: AsyncClient, InstrumentIdType, CandleInterval, OrderDirection, OrderType, CandleInstrument, MarketDataRequest, SubscribeCandlesRequest, SubscriptionAction, SubscriptionInterval.
- app/broker/tinvest/mapper.py          — TInvestMapper: candle_to_candle_data(), position_to_broker_position(), operation_to_broker_operation(). Конвертация protobuf → dataclasses.
- app/market_data/stream_manager.py     — MarketDataStreamManager: subscribe(), unsubscribe(), unsubscribe_all(). Вызывает adapter.subscribe_candles().
- app/broker/base.py                    — BaseBrokerAdapter, CandleData, AccountBalance, BrokerPosition, BrokerOperation (dataclasses).
- tests/unit/test_broker/test_tinvest_subscribe_candles.py — Содержит sys.modules["tinkoff"] = ... stub. УДАЛИТЬ после апгрейда.
- pyproject.toml                        — Зависимости backend. Зафиксировать SDK здесь.
```

# Задачи

## Задача 3.1: Инвентаризация использований SDK

Выполни:
```bash
grep -rn "from tinkoff.invest import\|import tinkoff\." app/
grep -rn "from tinkoff" tests/
```

Зафиксируй все импортируемые классы. Ожидаемый список:
- `AsyncClient` — основной клиент
- `InstrumentIdType` — enum для поиска инструментов
- `CandleInterval` — enum интервалов свечей
- `OrderDirection` — BUY/SELL
- `OrderType` — MARKET/LIMIT
- `CandleInstrument` — dataclass для подписки
- `MarketDataRequest` — запрос для streaming
- `SubscribeCandlesRequest` — подписка на свечи
- `SubscriptionAction` — SUBSCRIBE/UNSUBSCRIBE
- `SubscriptionInterval` — интервалы подписки

## Задача 3.2: Установка beta117+

```bash
# Вариант A: прямая установка
pip install "tinkoff-investments @ git+https://github.com/RussianInvestments/invest-python.git@0.2.0-beta117"

# Если ошибка транзитивных deps — Вариант B:
pip install "tinkoff-investments @ git+https://github.com/RussianInvestments/invest-python.git@0.2.0-beta117" --no-deps
pip install grpcio protobuf  # установить core deps вручную
```

**Если beta117 недоступен** — попробуй последний доступный тег:
```bash
git ls-remote --tags https://github.com/RussianInvestments/invest-python.git | grep "0.2.0" | tail -5
```

## Задача 3.3: Проверка breaking changes

Для каждого класса из задачи 3.1:
```bash
python -c "from tinkoff.invest import AsyncClient; print('OK')"
python -c "from tinkoff.invest import InstrumentIdType; print('OK')"
# ... и так далее для каждого класса
```

Если класс переименован — найди новое имя:
```python
import tinkoff.invest
print([x for x in dir(tinkoff.invest) if 'Order' in x])  # пример
```

Зафиксируй маппинг старое_имя → новое_имя.

## Задача 3.4: Адаптация кода

Для каждого breaking change:
1. Обнови import в файле
2. Обнови использование (если API метода изменился)
3. Проверь enum-значения (числовые значения могут измениться!)

**Критические точки для проверки:**
- `AsyncClient.__aenter__` / `__aexit__` — context manager API
- `client.market_data_stream.market_data_stream(request_iterator)` — streaming API
- `client.orders.post_order(...)` — размещение ордера
- `client.operations.get_portfolio(...)` — получение позиций
- `client.instruments.find_instrument(...)` — поиск по тикеру
- `SubscriptionAction.SUBSCRIPTION_ACTION_SUBSCRIBE` — enum value

## Задача 3.5: Фиксация версии в pyproject.toml

```toml
[project]
dependencies = [
    # ... existing deps ...
    "tinkoff-investments @ git+https://github.com/RussianInvestments/invest-python.git@0.2.0-beta117",
]
```

Или если используется requirements.txt:
```
tinkoff-investments @ git+https://github.com/RussianInvestments/invest-python.git@0.2.0-beta117
```

## Задача 3.6: Удаление sys.modules stub

В `tests/unit/test_broker/test_tinvest_subscribe_candles.py`:
1. Удали блок `sys.modules["tinkoff"] = ...` (Gotcha 14 stub)
2. Замени на реальные импорты из SDK
3. Убедись, что тесты проходят с реальным SDK

## Задача 3.7: Регрессионное тестирование

```bash
# Unit-тесты брокера
pytest tests/unit/test_broker/ -v

# Unit-тесты trading
pytest tests/unit/test_trading/ -v

# Все тесты
pytest tests/ -v
```

Если тесты падают из-за переименований — починить. Зафиксировать количество до/после.

# Опциональные задачи

## Задача 3.8 (опциональная): Обновить CI workflow

В `.github/workflows/ci.yml` убедиться, что SDK устанавливается автоматически через `pip install -e .` (из pyproject.toml) без дополнительных хаков.

**DEV обязан вернуть PASS или SKIP + reason.**

# Тесты

```
tests/
├── unit/test_broker/
│   ├── test_tinvest_subscribe_candles.py  # Удалить sys.modules stub, перейти на реальный SDK
│   ├── test_tinvest_adapter.py            # Регрессия: connect, get_accounts, get_positions
│   └── test_tinvest_mapper.py             # Регрессия: candle/position/operation mapping
```

**Минимум:** все существующие тесты в `test_broker/` должны пройти (0 failures). Новых тестов не нужно — задача infra, не feature.

# ⚠️ Integration Verification Checklist

- [ ] `pip show tinkoff-investments` → версия 0.2.0-beta117 (или актуальнее)
- [ ] `python -c "from tinkoff.invest import AsyncClient, MarketDataRequest, SubscribeCandlesRequest"` → OK
- [ ] `grep -rn "sys.modules.*tinkoff" tests/` → **пусто** (stub удалён)
- [ ] `grep -rn "tinkoff-investments" pyproject.toml` → версия зафиксирована
- [ ] `pytest tests/unit/test_broker/ -v` → 0 failures
- [ ] `pytest tests/ -v` → 0 failures
- [ ] `ruff check .` → 0 errors

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.
Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-3_report.md`.

# Чеклист перед сдачей

- [ ] SDK обновлён до публичного тега (0.2.0-beta117 или новее)
- [ ] Все `from tinkoff.invest import ...` работают с новой версией
- [ ] `sys.modules` stub удалён из тестов
- [ ] `pyproject.toml` фиксирует конкретную версию
- [ ] `ruff check .` → 0 errors
- [ ] `pytest tests/` → 0 failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-3_report.md`
- [ ] **Cross-DEV contracts подтверждены:** SDK beta117+ установлен → DEV-5 (волна 2) может работать с ним
- [ ] Опциональная задача 3.8 — PASS или SKIP + reason
