## DEV-AUDIT-030 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. SDK beta117 per-call `timeout=` **не принимает** (в стаб уходит только `metadata=`) → fallback из решения заказчика: обёртка каждого SDK-await.
2. `adapter.py`: модульный `_unary(operation, coro)` — `asyncio.timeout(TINVEST_UNARY_TIMEOUT_SEC)`; истечение → `BrokerTimeoutError("Брокер T-Invest не ответил за 10 с (…)") from TimeoutError`. `scope.expired()` отличает наш дедлайн от чужого `TimeoutError` изнутри SDK (в 3.11 это один класс) — на этом падал `test_adapter_full::test_error_wraps`; закрыто уточнением фикса.
3. Обёрнуты все 36 унарных сайтов (счета/портфель/операции/свечи/инструменты/FIGI, отправка/отмена/статус ордера, `get_order_status_by_client_id`, sandbox, статические `detect_*`); `grep "await client\."` без обёртки — пусто. `acquire()` лимитера дедлайном не покрыт намеренно (штатный backpressure).
4. Дедлайн — внутри каждой попытки `_read_with_retry`; таймаут не ретраится (только `70001`).
5. `config.py`: `TINVEST_UNARY_TIMEOUT_SEC: float = 10.0` (Q5=a). Локи, `locks.py`, keepalive стрима — не тронуты.
6. Худший случай под `close_trade` (было ∞): вызов ≤ 10 с; `get_order_status` ≤ 2×10+1.5 = 21.5 с; вход: place 10 + lookup 21.5 + poll 5×(1+21.5) ≈ 2,4 мин.

### 2. Файлы
Новые: `backend/tests/unit/test_broker/test_adapter_deadlines.py`, `backend/tests/test_trading/test_order_timeout_unknown_outcome.py` (БД-фикстуры только в `test_trading/`). Изменённые: `backend/app/broker/tinvest/adapter.py`, `backend/app/common/exceptions.py`, `backend/app/config.py`, `backend/app/trading/engine.py` (докстринг/комментарий), `backend/app/broker/sandbox_recovery.py` (комментарий).

### 3. Тесты
RED: `E   TimeoutError` (страховка `wait_for(…, 2 с)` вместо `BrokerError`) — 9 failed / 1 passed. GREEN: 14/14; с `test_adapter_full`, `test_sandbox_flaky_70001`, `test_broker_service`, `test_sandbox_recovery` — 119 passed. Мутация: `async with scope: return await call` → `return await call` → 9 failed `E TimeoutError`; откат, diff сверен. Гейты: pytest **2871 passed / 16 xfailed / 0 failed**; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `_unary` — 36 вызовов в `adapter.py`; ✅ таймаут на отправке → `engine.py` `except BrokerError → _resolve_lost_entry_response` (путь 024; сквозной тест на реальном исключении адаптера); ✅ `BrokerTimeoutError` бросается в `_unary`, ловится в `detect_*`/`get_instrument_info`; ✅ `settings.TINVEST_UNARY_TIMEOUT_SEC` читается в `_unary`.

### 5. Контракты
API/схемы/миграции — без изменений.

### 6. Правки документов / находки
- `.env.example` (не редактировал): `TINVEST_UNARY_TIMEOUT_SEC=10  # дедлайн одного gRPC-вызова к T-Invest, сек`.
- Гайд, таблица env: `| TINVEST_UNARY_TIMEOUT_SEC | (опц.) дедлайн унарного gRPC-вызова T-Invest, сек (S8R-AUDIT-030); стрим не затрагивает | по умолчанию 10 |`.
- ТЗ §5.5: «Каждый унарный вызов SDK — под `asyncio.timeout(TINVEST_UNARY_TIMEOUT_SEC=10)` (`TInvestAdapter._unary`); истечение — `BrokerTimeoutError(BrokerError)` с `TimeoutError` в цепочке `__cause__`, классификаторами 024 отказом не считается; на отправке — «исход неизвестен». Проверка типа токена/прав и поиск инструмента по классам таймаут не глушат: наружу — «T-Invest не ответил, повторите». `_read_with_retry` повторяет только `70001`.» ФТ — без изменений.
- `git stash list` содержит чужую запись — не трогал.

### 7. Применённые Gotchas
14, 30 (патч `tinkoff.invest.AsyncClient` — импорт inline), 56, 59 (мутация обязательна), 71.

### 8. Новые Gotchas
Кандидат: «`asyncio.TimeoutError is TimeoutError` (3.11): `except asyncio.TimeoutError` вокруг `wait_for` ловит и TimeoutError изнутри вызова → ложный «дедлайн истёк». Правило: `asyncio.timeout()` + `scope.expired()`; дедлайн-ошибка — отдельный подкласс, чтобы `except Exception: pass` его не глушил». Файлы: `adapter.py::_unary`, `exceptions.py`.

### 9. Плагины
py_compile после каждой правки; `tsc -b`; интроспекция SDK (`inspect.signature`) вместо context7 — точнее по beta117; `mattpocock-skills:tdd`.

### 10. Доработки по /code-review
Общий механизм: `BrokerTimeoutError(BrokerError)` — ветки `except BrokerError` не менялись.
1. `detect_token_mode`: RED `Failed: DID NOT RAISE BrokerError` (таймаут production-пробы → «sandbox»). Правка: `except BrokerTimeoutError → raise BrokerTimeoutError("T-Invest не ответил на проверку API-ключа (…). Повторите попытку позже.") from exc` в обеих пробах. Мутация (проглотить) → `DID NOT RAISE`.
2. `detect_trading_rights`: RED `DID NOT RAISE` (таймаут → `False` → `has_trading_rights=False` навсегда). Выбрано **пробросить**: следующий шаг регистрации — `get_accounts()` тем же токеном — при той же «чёрной дыре» упадёт всё равно, а «неизвестно» требует nullable-поля и миграции. Реальный отказ брокера → `False`, как прежде (тест-замок). Мутация (`return False`) → `DID NOT RAISE`.
3. `get_instrument_info`: RED `BrokerError('Инструмент SBER не найден').__cause__` = `None`. Правка: `except BrokerTimeoutError: raise` в каждой из трёх проб — ошибка недоступности на первой, цепочка сохранена. Мутация (`pass`) → `Expected bond_by to not have been awaited. Awaited 1 times`.
Комментарии обновлены: `engine.py:~1997`, `config.py`, `sandbox_recovery.py:53-58`. `market_data/service.py::find_instrument` — не трогал.
