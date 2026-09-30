## DEV-AUDIT-047 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (база 4b30058, ничего не закоммичено)

### 1. Что реализовано
1. `place_order`: принимает только `direction` из `buy`/`sell`. Любое другое значение даёт `BrokerError` раньше figi, лимитера и сети. Сравнение стало строгим, `.lower()` убран.
2. LIMIT: в запрос уходит `price=decimal_to_quotation(...)`. Шаг цены читается через `GetInstrumentBy(FIGI)` в `_read_with_retry`. Цена округляется так, чтобы не выйти за заявленную: покупка вниз, продажа вверх. Кратность шагу требует T-Invest, иначе ошибка `30078`. Если шага нет, цена ≤0 или после округления получается 0, заявка не отправляется.
3. Маппер: `UNSPECIFIED` и незнакомый статус теперь дают `unknown`, а не `placed`.
4. Движок: `unknown` на входе и на выходе идёт тем же путём, что `placed`: опрос `GetOrderState` и `order_state_verdict` (правило 024). Раньше вход уходил в `failed`, а выход закрывался без опроса.
5. `models.order_side` / `closing_order_side` лежат рядом с `is_long_direction`. На выходе вместо inline-копии стоит `closing_order_side`: long закрывается SELL, short закрывается BUY. Незнакомое направление даёт `BrokerError` до пометки «в полёте», при этом адаптер освобождается.
6. `search_instruments`: `lot_size=None`, `min_price_increment=None`. `InstrumentInfo` теперь Optional (в `app/` это поле никто не читает).
7. У `OrderResponse.price` и в маппере добавлена пометка из gotcha-33: это сумма за весь ордер, а не цена за штуку. Путь через `average_position_price` не менялся.

### 2. Файлы
Изменены: `backend/app/broker/{base.py, tinvest/adapter.py, tinvest/mapper.py}`, `backend/app/trading/{engine.py, models.py}`, тесты `unit/test_broker/test_adapter_full.py`, `test_broker/test_sandbox_flaky_70001.py` (в оба добавлен мок шага цены для LIMIT).
Новые: `tests/unit/test_broker/test_adapter_contract.py`, `tests/test_trading/test_order_side_unknown_status.py`.

### 3. Тесты
- RED: `Failed: DID NOT RAISE <class 'app.common.exceptions.BrokerError'>` (long), `KeyError: 'price'`, `AssertionError: assert 'placed' == 'unknown'`, `assert 1 is None`, `ImportError: cannot import name 'order_side'`, `assert 'failed' == 'filled'`.
- GREEN: 36/36.
- Мутация: убрал guard и вернул `BUY if direction.lower()=="buy" else SELL`. Итог `DID NOT RAISE` ×4. Откат сделан из бэкапа, md5 совпал.
- Гейты: pytest 4226 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (191); bandit ok; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `closing_order_side` в `engine.py` (закрытие sandbox/real), внутри вызывает `order_side`. ✅ `_min_price_increment` и `_limit_price_on_step` в `place_order`. ✅ `unknown` обрабатывается в `_apply_entry_response` и в exit-ветке `close_position`.

### 5. Контракты
Миграции нет. API и фронт не менялись: поиск фронта идёт через ISS (`market_data/router.py`), а не через адаптер.

### 6. Проблемы / находки
- ФТ и ТЗ поведение не меняет, правки не нужны.
- На входе нормализация не нужна: направление берётся из `SignalAction` (`buy`/`sell`), тест это проверяет.
- Находка: `RiskMonitor.broker_plan` (`risk_monitor.py:239`) по-прежнему считает сторону inline-копией, а параметр `close_direction` в `_close_via_broker` не используется. Ордер при этом строится через `close_position`, так что это мёртвый код для S8R-FIX-015.
- Находка: в `FindInstrument` есть поле `lot`, поиск мог бы отдавать настоящий лот. Сделал `None`, как решил заказчик.
- Самопроверка: 1 — новый отказ случается до любых commit; 2 — новых уведомлений нет; 3 — тесты идут через `_unary`, `close_position` и `process_signal`, путь market без price тоже покрыт; 4 — под дедлайном только чтение шага; 5 — оба `place_order` в движке проверены; 6 — неприменимо.

### 7. Применённые Stack Gotchas
33, 56 (повтор только на чтении шага цены), 27.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile ok; context7 (T-Invest contracts: `30078`, кратность шагу); tdd (`mattpocock-skills:tdd`); typecheck (`tsc -b`) 0.

---

## Ревью р.2: исправлено 1–6
1. `OrderNotSentError(BrokerError)` (`common/exceptions.py`). Все отказы до `PostOrder` собраны в `TInvestAdapter._prepare_order`: направление, цена/шаг, FIGI не определён, не подключён, сбой подготовки. `is_definitive_rejection` находит его в цепочке. Вход → `failed` + `order.error` сразу, без поиска по ключу. Выход → пометка «в полёте» снимается, сделка остаётся открытой, ошибка уходит наружу.
2. Любой сбой `GetInstrumentBy` при подготовке LIMIT (`UNAVAILABLE`, `INTERNAL`, `BrokerTimeoutError`) → `OrderNotSentError`, исходная ошибка в `__cause__`. Шаг читается внутри `place_order`, то есть уже после `note_entry_sent`. Раньше читать нельзя без отдельного вызова адаптера из движка. Практически это ни на что не влияет: отказ окончательный, `pending` не остаётся. Движок LIMIT сегодня не шлёт.
3. Кэш шага по FIGI (`_PRICE_STEP_CACHE`): TTL 24 ч, до 2048 записей, кэшируется только шаг > 0. Справочник `instruments` не использовал: у адаптера нет сессии БД.
4. `instrument_to_instrument_info`: если поля нет, `min_price_increment` и `lot_size` = `None`. Проверил потребителей: `InstrumentInfo.lot_size` из T-Invest в `app/` никто не читает, `ensure_lot_size` берёт `lot` из `FindInstrument` напрямую.
5. `risk_monitor`: сторона считается через `closing_order_side` (`_closing_side_label`), для незнакомого направления пишется «направление не определено». Моя находка р.1 была ошибкой: параметр `close_direction` не мёртвый, он уходит в `order.error` (`_publish_close_failed`). Параметр оставлен.
6. `engine.order_response_status` — одна нормализация для входа, выхода и `_order_status_as_response`. Ветка входа `broker_unexpected_status` → `failed` недостижима и удалена: незнакомый статус теперь уходит в опрос.

Тесты: +19 (адаптер: `OrderNotSentError`, сбой шага ×3, FIGI, кэш, «шага нет» не кэшируется, маппер; движок: вход `direction='long'` / LIMIT без шага → `failed` через настоящий адаптер, выход без пометки, `order_response_status`, `_closing_side_label`). `test_adapter_figi_class_code` теперь ожидает `OrderNotSentError`, `NotFoundBrokerError` у него в `__cause__`.
Мутация: для направления в `_prepare_order` бросаю `BrokerError` вместо `OrderNotSentError` → `AssertionError: assert 'pending' == 'failed'`. Откат сделан из бэкапа, md5 совпал.
Гейты: pytest 4250 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (191); bandit ok.
