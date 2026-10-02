## DEV-AUDIT-064 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes-c`, база a78e0c3, не закоммичено)
### 1. Что реализовано
- Мультиплексор: исключение маппера → свеча пропускается, агрегированный WARNING `multiplexer_candles_unmappable_dropped` (общее окно с 048), без reconnect.
- Алерты: в цикле чтения только `_enqueue_alert_check`; проверяет отдельная задача. Очередь `OrderedDict` по ключу (figi, время свечи) → [min, max] close; проверка max, затем min — срабатывание не теряется и не дублируется. Предел 1000 ключей: отбрасываются самые старые, `price_alert_queue_overflow` (накопительный счётчик, не чаще раза в 60 с, хвост — при stop). `stop()` снимает задачу.
- ISS `_request`: повтор 5xx и транспортных ошибок (3 попытки) → `TransientBrokerError`; 4xx, не-JSON, JSON не-объект → `BrokerError`. Повторы `_fetch_candles` убраны (было до 9 попыток). Таймауты не менялись.
- `get_paginated`: курсор `<block>.cursor` при наличии, иначе короткая страница; повтор страницы → стоп; предел `ISS_MAX_PAGES=1000` с WARNING.
- Публичный `get_json` для `bond_service` и `corporate_actions`, без `_get_client()`.
- `MINSTEP` → `Decimal(str(v))`. `parse_candles` уже удалён (063), закреплено тестом.
- Удаление счёта под `session_start_account` — уже сделано в 099 (`test_audit_s8r_delete_account_race.py`, зелёный).
### 2. Файлы
Изменены: `app/broker/moex_iss/client.py`, `parser.py`, `app/broker/tinvest/multiplexer.py`, `app/market_data/service.py`, `bond_service.py`, `app/corporate_actions/service.py`, `tests/unit/test_market_data/test_service_full.py` (тест повторов вызывающего → «одна попытка»). Новые: `tests/unit/test_moex_iss/test_client_errors.py`, `tests/unit/test_broker/test_multiplexer_mapper_error.py`.
### 3. Тесты
RED: `httpx.ConnectError: connection refused`; `assert [10, 11, 12] == [10, 11, 12, 13, …]` (cursor); `AssertionError: пагинация не остановилась: 5001 запросов`; `AssertionError: битая свеча вызвала переподключение: вызовов стрима 5`; алерты — `TimeoutError`. GREEN — 19 тестов карточки.
Мутации (бэкап + md5): `except Exception` → `except MissingCandleTimeError` → «вызовов стрима 5»; слияние «последний close» → `assert [] == [Decimal('110')]`. Откачены.
Гейты: pytest 4856 passed / 1 skipped / 1 xfailed / 0 failed; ruff 0; mypy Success (195); bandit без находок; typecheck 0; lint 0; build ok; vitest — фронт не менялся, на уровне пакета.
### 4. Integration points
✅ `client.py:268` (get_paginated); `bond_service.py:86,123`, `corporate_actions/service.py:605,720,839` (get_json); `multiplexer.py:798` (enqueue), `:292` (stop), `:772,780`.
⚠️ Ранее существовавший дефект: `set_price_alert_monitor` в production не вызывается нигде (`main.py:196` создаёт монитор, к мультиплексору не подключает) → проверка алертов по стриму в проде мертва (до и после правки). Подключение меняет поведение — нужна отдельная карточка.
### 5. Контракты
API и схемы без изменений, миграции нет.
### 6. Проблемы / предложения / новые находки
- Живой GET 2026-10-01: у `candles.json` блока `candles.cursor` нет (есть у `/iss/history`, `history.cursor`). Посылка аудита G3-65 верна только наполовину.
- ТЗ §5.5.3, добавить: «Повторы (S8R-AUDIT-064): 5xx и сбой связи — до 3 попыток внутри клиента, затем `TransientBrokerError`; 4xx/не-JSON — `BrokerError`; вызывающие не повторяют. Пагинация — по `<блок>.cursor`, без него — до короткой страницы, не более 1000 страниц». ТЗ §5.2.4 (стрим): «Битая свеча пропускается без переподключения; ценовые алерты проверяются отдельной задачей из ограниченной очереди».
- Вне рецепта, не правил: `stopped`-сессия с незакрытыми позициями (`filled/pending`) не блокирует удаление счёта (G3-56б); `get_sandbox_balance(currency)` игнорирует валюту (G3-58). Нужно решение заказчика.
- Поведение: `get_bond_info` при 5xx/обрыве теперь даёт ошибку, а не кэширует на 24 ч номинал 1000 по умолчанию.
- Самопроверка: 1 — монитор коммитит сам, сбой → алерт активен, сработает позже; 2 — дублей нет; 3 — путь через `_run_stream`/`_request`; 4 — новых таймаутов нет; 5 — вызывающие `_request` проверены; 6 — очередь и страницы ограничены.
### 7. Применённые Stack Gotchas
28, 27, 59/48 (тест 099), 70.
### 8. Новые Stack Gotchas
Нет.
### 9. Плагины
py_compile (6 файлов); typecheck; context7 не нужен (только `httpx`, иерархия исключений; ISS проверен живым GET); tdd — скилл `mattpocock-skills:tdd`.

---

## DEV-AUDIT-064 — правки по код-ревью оркестратора (р.1)
Статус: ✅ готово к коммиту (не закоммичено)

### Сделано (пп. ревью)
1. `stop()`: задача алертов снимается после отмены `_stream_task`; `_enqueue_alert_check` при `_stopping` ничего не делает.
2. «unmappable»: первая ошибка нового типа сразу пишется ERROR `multiplexer_candle_mapper_error` с traceback (`plain_traceback`, gotcha-67). В агрегат добавлены `error_types` и `first_error`.
3. `get_bond_info`: при `TransientBrokerError` отдаёт устаревший кэш с WARNING `bond_info_stale_cache_used`; если кэша нет — ошибка.
4. Купоны в `BondService` берутся через `get_paginated` (`iss.only=coupons`, `limit=100`, до 10 страниц).
5. Исчерпан предел страниц — `BrokerError("выборка ISS усечена: N страниц")`.
6. Детект корпоративных действий: после первого `TransientBrokerError` оставшиеся тикеры, сплиты и купоны прогона пропускаются, пишется один WARNING `detect_iss_unavailable` (`skipped_tickers`, `failed_at`).
7. 408/429 повторяются (≤3 попытки), пауза — по `Retry-After`, но не больше 10 с; после исчерпания — `TransientBrokerError`.
8. `_fetch_candles` пробрасывает `TransientBrokerError`. `/candles` и `/sparkline` отвечают 503 «MOEX ISS недоступен — …» (без этого сработал бы общий обработчик `BrokerError` → 502). Фронт: стор берёт текст 503 из ответа сервера, `ChartPage` показывает строку `chart-error-detail`. Бэктест и торговля до ISS не доходят (`TInvestRequiredError`, проверено тестом). Бенчмарк IMOEX ловит исключение сам — в итоге `None`, как и раньше.
9. `_fetch_coupon_rows` использует `get_paginated`.
10. Тип монитора — `PriceAlertChecker(Protocol)`, `# type: ignore` убран.

### Тесты
- RED: «stop оставил задачу»; `[] == ['ValueError','TypeError']`; «DID NOT RAISE BrokerError» на пределе страниц; «client error: 429»; `KeyError 'iss.only'`; запрос `splits.json` при недоступном ISS; `502 == 503`.
- Мутации (откачены, md5 сверен):
  - п.1: снята проверка `_stopping` → «_alert_worker is None» красный. Порядок «стрим → алерты» — второй слой защиты: отдельной мутацией не ловится, потому что проверка `_stopping` действует на всём протяжении stop().
  - п.8: снят проброс → «DID NOT RAISE TransientBrokerError».
  - Фронт: 503 → общий текст → красный.
- Гейты: pytest 4874 passed / 1 skipped / 1 xfailed / 0 failed; ruff 0; mypy Success (195); bandit без находок; typecheck 0; lint 0; build ok; vitest 1062 passed.

### Поправка к прошлому отчёту
`BrokerError` из роутеров даёт 502 (общий обработчик), а не 500.

### Предложение в ТЗ §5.5.3 (дополнить)
«408/429 — повтор с `Retry-After` (≤10 с); исчерпан предел страниц — ошибка "выборка усечена"; график без T-Invest при недоступном ISS — 503 "MOEX ISS недоступен"; облигация — устаревший кэш».

Находка «монитор алертов не подключён» не чинилась — по решению оркестратора.

---

## DEV-AUDIT-064 — код-ревью р.2 (финальный)
Статус: ✅ готово к коммиту (не закоммичено, правки р.1 на месте)

### Сделано
1. `get_candles`: при `TransientBrokerError` на одном из пропусков остальные пропуски не запрашиваются. Если кэш за диапазон есть — отдаётся он с WARNING `iss_unavailable_serving_cache` (source=`cache`). 503 — только когда кэш пуст.
2. `BondService`: если не удалось получить купоны (сбой ISS или предел страниц), запись кэша не меняется вообще — ни купоны, ни `updated_at`. Если кэша нет, ответ отдаётся без купонов и в кэш не пишется.
3. Фронт: если график уже показан из кэша, сбой фонового обновления пишется в `refreshError` и показывается жёлтым `Notification` (`chart-refresh-error`). Alert вместо графика — только при пустом кэше.
4. HTTP 200 с не-JSON телом — повтор, затем `TransientBrokerError`.
5. stop()/eviction: задача алертов сначала дочитывает очередь (не дольше 1 с). Не успела — WARNING `price_alert_checks_lost_on_stop` (`lost` = очередь + проверка в работе), задача отменяется.
6. Воркер алертов выходит по `_stopping`, когда очередь пуста; проверка в начале каждого оборота, в том числе после пробуждения. stop() из колбэка монитора сироты не оставляет. Отмена самого stop() отменяет и воркер.
7. `Retry-After`: 0 — повтор сразу; больше 10 с — сразу `TransientBrokerError`, без лишних попыток. На одну выборку `get_paginated` общий бюджет пауз — 20 с.
8. SparklineWidget показывает текст ответа сервера (через `getApiErrorMessage`); при ошибке без ответа — общий текст.
9. Купоны получаются одним методом `MOEXISSClient.get_coupons(ticker)` (`ISS_COUPONS_PAGE=100`, `ISS_COUPONS_MAX_PAGES=10`) — и в BondService, и в corporate_actions.

### Тесты
- RED, фактические строки:
  - п.1: `assert 503 == 200`;
  - п.2 и п.9: `does not have the attribute 'get_coupons'`;
  - п.4: `BrokerError: MOEX ISS: ответ не JSON`;
  - п.7: `assert [1.0] == []`, `assert 3 == 1`;
  - п.5: `assert [] == [100, 101, 102]`;
  - п.6: `TimeoutError` (воркер-сирота);
  - п.3: `refreshError` undefined.
- Мутации (откачены, md5 сверен):
  - п.1: 503 при непустом кэше → `assert 503 == 200`;
  - п.3: ветка кэша отключена → `expected 'MOEX ISS недоступен…' to be null`.
- Гейты: pytest 4887 passed / 1 skipped / 1 xfailed / 0 failed; ruff 0; mypy Success (195); bandit без находок; typecheck 0; lint 0; build ok; vitest 1067 passed.

### Для ТЗ §5.5.3 (дополнить к р.1)
- «ISS недоступен, а кэш за диапазон есть — график отдаётся из кэша; ошибка фонового обновления показывается пометкой».
- «Retry-After больше 10 с — без ожидания; бюджет пауз на выборку — 20 с».
- «Сбой купонов облигации не перезаписывает кэш».
