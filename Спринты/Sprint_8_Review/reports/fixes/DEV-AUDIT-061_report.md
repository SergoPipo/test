## DEV-AUDIT-061 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (после доработок по /code-review)

### 1. Что реализовано
1. Очередь команд — своя на каждый стрим; при закрытии стрима в старую кладётся sentinel `None` → старый `_request_iterator` завершается, grpc-aio `_consume_request_iterator` умирает и не ворует `SUBSCRIBE` у нового стрима.
2. Переподписка при reconnect — один `MarketDataRequest` на все пары; команды, попавшие в очередь до старта итератора, не дублируются.
3. `subscribe_candles_response`: статус ≠ SUCCESS у SUBSCRIBE → маршрут снят, warning `multiplexer_subscription_rejected`, подписчику `on_error(reason)`; `stream_manager` по нему убирает `_StreamEntry` (watchdog увидит нездоровье).
4. Классификатор `_is_terminal_auth_error`: `UNAUTHENTICATED`/`PERMISSION_DENIED` → терминальное состояние без backoff, `connection.lost` с причиной (`force=True` — минуя порог 30 с и фильтр «рынок закрыт»), `subscribe()` → `BrokerError` без запросов к API.
5. Ноль подписчиков → `_evict_if_idle`: `stop()` + снятие с `_singletons` под `_singletons_lock`; `subscribe()` на остановленном экземпляре → `BrokerError` (нет ghost-стрима).
6. `stream_manager`: держатели стримов, `release()`; `runtime.stop()` снимает держателя сессии.
Не тронуто: watchdog «живость = `_stream_task`», backoff 1→30 с.

### 2. Файлы
Новые: `backend/tests/unit/test_broker/test_multiplexer_reconnect_queue.py`, `backend/tests/test_market_data/test_stream_manager_refcount.py`.
Изменённые: `app/broker/tinvest/multiplexer.py`, `app/broker/tinvest/adapter.py`, `app/market_data/stream_manager.py`, `app/market_data/router.py`, `app/backtest/ws.py`, `app/broker/service.py`, `app/trading/runtime.py`; тесты: `test_tinvest_multiplexer.py` (K1 → `_retire_command_queue`), `test_stream_health.py` (дабл принимает `on_error`), `test_market_data_router.py` (мок `open_stream`), `test_ws_authz.py` (+класс держателей), `test_runtime_recovery.py` (+`TestStreamWatchdogHolders`).

### 3. Тесты
RED: `assert 'FIGI-B' in ['FIGI-A']` (команда съедена); `unexpected keyword argument 'on_error'`; `задача стрима обязана завершиться … Task pending`; `singleton не снят`; `assert 0 == 1` (release).
Мутации: «общая очередь без sentinel» → `assert 'FIGI-B' in ['FIGI-A']`; «игнорировать ack» → `подписчик не получил ошибку … assert []`. Откачены через `cp`-бэкап (md5 совпал).
Гейты (финальные, после §11): pytest 2834 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `runtime.py:474-475` (`stop()` → `_release_session_stream`, после `event_bus.unsubscribe`, до отмены task — единственная точка для слияния с DEV-074), `:512` метод, `:383-416` флаг в `start()`, `:1162-1170` watchdog (`acquire`); `stream_manager.py:223` `on_error`; `adapter.py:1028`; `multiplexer.py` (ack, terminal, evict); `router.py:196` `open_stream`; `ws.py:256-266, 281, 302`; `service.py:161` `clear_terminal_token`. Событие — существующий `connection.lost`.

### 5. Контракты
API/схемы/миграций нет. `TInvestAdapter.subscribe_candles(..., on_error=None)`, `stream_manager.subscribe(..., holder=None)`, `release(..., holder)` — необязательные/новые параметры внутренних API.

### 6. Проблемы / TODO / находки
- Фронт (карточку заводит оркестратор): после WS-reconnect хук `useWebSocket` пересылает `subscribe` каналов, но `POST /candles/subscribe` не повторяет; если разрыв дольше grace (60 с) — стрим графика снят, держатель `ws:*` есть, свечей нет до смены ТФ. Нужен повтор REST-подписки при reconnect (или на `auth_ok`).
- Ключ `(ticker, timeframe)` без токена — не менял (решение заказчика), остаётся находкой.
- Терминальный токен у активной сессии: watchdog раз в 60 с получает `BrokerError` (`stream_watchdog_iteration_failed`) — без запросов к API; после `create_account` с ключом запрет снимается.
- gotcha-71 из обязательного чтения в дереве отсутствует.
- ТЗ, раздел «Мультиплексор T-Invest»: «очередь команд на стрим и sentinel; ack подписки; терминальные статусы UNAUTHENTICATED/PERMISSION_DENIED → реестр по отпечатку токена, `connection.lost` без повторов, сброс при переподключении счёта; eviction при нуле подписчиков; держатели стримов (`session:{id}`, `ws:{conn}`), grace 60 с».

### 7. Применённые Stack Gotchas
04, 34, 27, 14, 26, 59.

### 8. Новые Stack Gotchas
Кандидат: «`Call.cancel()`/`aclose()` не снимает потребителя request_iterator grpc-aio; при пересоздании стрима общая `asyncio.Queue` отдаёт команды первому ждущему — старому. Правило: очередь на стрим + sentinel». Файлы: `multiplexer.py`, `test_subscribe_after_reconnect_reaches_new_stream`.

### 9. Плагины
py_compile (fallback pyright) — все `.py`; `tsc -b`; tdd-скилл; context7 не потребовался — SDK-схемы прочитаны из venv.

### 10. Доработки по /code-review
1. [high] Терминальность переживает eviction: `_terminal_tokens` (sha256-отпечаток токена → причина; в логах только отпечаток) — `get_or_create_multiplexer` → `BrokerError` без подключения; сброс: `clear_terminal_token` из `BrokerService.create_account` (`update_account` токен не меняет), `shutdown_multiplexers`, рестарт. RED `ImportError: cannot import name 'clear_terminal_token'`; мутация «`terminal = None`» → `Failed: DID NOT RAISE BrokerError`.
2. [medium] Держатели — именованный set `_holders[key]` отдельно от `_StreamEntry`; отказ подписки и `ensure_stream` их не трогают; `_release_session_stream` по `session:{id}`; watchdog после пере-подписки `acquire` (идемпотентно). Тест A+B → отказ → пере-подписка → стоп A → B получает `candle.update`. RED `unexpected keyword argument 'holder'`.
3. [medium] `asyncio.Lock` на ключ в `stream_manager` (`_lock_for`) вокруг открытия стрима. Листовой лок: под ним только адаптер/`_singletons_lock`; берётся из `runtime.start` (под `_start_lock`), роутера, watchdog'а — в `locks.py` не входит, обратного порядка нет. Тест `gather` двух `subscribe` (фейк-`connect` уступает loop) → один адаптер.
4. [medium] Роутер → `open_stream` без держателя; `ws.py`: подписка `market:{t}:{tf}` → `acquire(holder="ws:{conn}")`, `unsubscribe` и `finally` закрытия WS → `release`; стрим без держателей снимается `sweep_idle` через grace 60 с (таймер `call_later`), тот же grace после ухода последнего держателя (рестарт сессии / WS-reconnect без нового gRPC-подключения). Тесты: WS acquire/release/close (`test_ws_authz.py::TestMarketStreamHolders`, RED `assert 0 == 1`), сирота снимается, с держателем — нет.
Полный гейт после доработок — 2831 passed (перекрыт §11).

### 11. Контрольный /code-review
1. [high] Watchdog при **здоровом** стриме и `stream_subscribed=False` (subscribe в `start()` упал, стрим открыл график) регистрирует держателя `session:{id}` (`runtime.py:~1140`, `acquire` идемпотентен, в try — сбой не валит watchdog). RED `assert [] == [('SBER', '1h', 'session:1')]` → GREEN.
2. [medium] Гонка `stop()` ↔ пере-подписка: после `ensure_stream` перепроверка `self._listeners.get(session_id) is not listener` непосредственно перед `acquire`, без await между (`runtime.py:~1185`, лог `stream_watchdog_session_gone_before_acquire`). Тест с рандеву в фейковом `ensure_stream` (Event до критической секции, ожидание с таймаутом — gotcha-59). RED `держатель утёк после stop(): ['session:1']` → GREEN; мутация «`if False:` вместо перепроверки» → та же строка, откат через `cp`-бэкап (md5 совпал).
3. [medium] `clear_terminal_token` стал `async`: снимает отпечаток **и** под `_singletons_lock` убирает терминальный экземпляр из `_singletons`, затем `stop()` (как `_evict_if_idle`); вызов в `service.py:161` — `await`. RED `TypeError: object NoneType can't be used in 'await' expression` (+ `fresh is mux` без правки) → GREEN: `test_clear_terminal_token_replaces_terminal_instance` — новый экземпляр, старый `is_stopped`, второе подключение.
Полный гейт: pytest 2834 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; фронт не менялся; маркеров `S8R-AUDIT-061` нет; дерево — только файлы карточки, ничего не закоммичено.
