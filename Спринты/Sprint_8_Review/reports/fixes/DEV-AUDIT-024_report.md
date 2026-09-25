## DEV-AUDIT-024 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (живой прогон S-1/S-2 на счёте #3 — за оркестратором)

### 1. Что реализовано
1. `LiveTrade.client_order_id` / `exit_client_order_id` (UUID4, String(36)) — пишутся ДО отправки (вход — тем же commit, что `pending`; выход — вместе с `exit_order_placed_at`).
2. `place_order(..., client_order_id)` → `PostOrder.order_id`; `get_order_status_by_client_id` = `GetOrderState(order_id_type=ORDER_ID_TYPE_REQUEST)` через `_read_with_retry` (чтение; `NOT_FOUND` в `__cause__`).
3. **Одна функция разбора ордера входа** `resolve_entry_order` (engine + runtime): состояние (по id или ключу) → если активен и надо — отмена → снова состояние; `lots_executed>0` = позиция на факт; «нет» — только подтверждённый `NOT_FOUND` и не раньше `UNKNOWN_OUTCOME_CONFIRM_AGE_SEC` (120 с) от момента ПОСЛЕДНЕЙ отправки (`entry_sent_at`: `opened_at` ∨ отметка процесса). Общий вердикт `order_state_verdict` (filled/gone/active) — и для выхода.
4. Вход: исключение `place_order` → счёт `NOT_FOUND`/детерминированный отказ (`is_definitive_rejection`) → `failed`; найден → общий учёт `_apply_entry_response(state=…)`; иначе `pending` + `order.error` «исход неизвестен».
5. Отмена: `_confirm_pending_order_gone` через `resolve_entry_order(cancel_active=True)`; исполнено → `filled` на факт и штатное закрытие тем же адаптером; счёт удалён → `cancelled`.
6. Выход: пометка+ключ до отправки; исключение → lookup; REJECTED (в т.ч. без id) снимает пометку; исполненная часть при `rejected/cancelled` — учёт по факту.
7. Повтор ордера на пересозданном sandbox-счёте — вне `except` (классификаторы не видят `__context__` = NOT_FOUND 50004); `_ENTRY_SENT_AT` очищается на любом терминале; адаптер закрытия отключается в `finally` вызывающего.
8. Recovery: pending — под `close_trade` с перечиткой статуса; exit — порог 120 с для пометок без id, `partially_filled`/частичное исполнение → finalize + флаг расхождения (существующий механизм); сверка позиций пропускает и «ответ потерян».

### 2. Файлы
Новые: `alembic/versions/d4f1a9c2b7e0_add_live_trades_client_order_ids.py`, `tests/test_trading/test_order_path_unknown_outcome.py` (46 тестов).
Изменённые: `app/trading/{engine,runtime,models,paper_engine}.py`, `app/broker/{base,sandbox_recovery}.py`, `app/broker/tinvest/adapter.py`, `tests/test_trading/{test_engine_sandbox_flow,test_entry_path_close_lock,test_sltp_broker_close,test_exit_order_tracking,test_reconcile_review_fixes,test_runtime_orphan_recovery}.py`, `tests/unit/{test_migration.py,test_broker/test_adapter_full.py}`.

### 3. Тесты
RED (до прод-правок): `18 failed, 1 passed`, `AttributeError: client_order_id`. Мутация «без запроса статуса в except» → `assert 'failed' == 'pending'`, откачена. Гейты (финал): pytest **2820 passed / 16 xfailed / 0 failed**; ruff 0; mypy Success (179); bandit 0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `resolve_entry_order`: `engine.py:2831/2907`, `runtime.py:1295`; `read_order_state`: `runtime.py:1575`; `order_state_verdict`: `engine.py:2259/2593/3523`, `runtime.py:1550/1588`; `note_entry_sent`: `engine.py:2345/2414`; `is_definitive_rejection`, `lookup_order_by_client_id`, `_broker_account_gone_reason` (`runtime` делегирует в `OrderManager`), `_close_filled_position_locked`: `engine.py:3392`. Схемы/эндпоинты/события не менялись.

### 5. Контракты
Миграция `d4f1a9c2b7e0` (down `c5e8b2a7f913`), `batch_alter_table`, идемпотентна, round-trip чист, `alembic heads` = 1. `BaseBrokerAdapter.place_order(client_order_id=None)`; `get_order_status_by_client_id` неабстрактный. `_apply_entry_response(state=)`; `_cancel_pending_trade(adapter_pair=)`.

### 6. Проблемы / TODO / правки документов
- **UI**: статуса «исход неизвестен» во фронте нет (`TradesTable` статус не показывает) — есть `order.error` и ручной путь «Закрыть». Нужна карточка.
- 030: `asyncio.TimeoutError` вне адаптера `except BrokerError` не ловит — оборачивать в `BrokerError`.
- Развилки (мои): детерминированный gRPC-отказ = «не принят» сразу (иначе каждый «недостаточно средств» занимал бы слот на 5 мин), проверка только структурная; exit-сигнал вне торговых часов логирует по сделке (best-effort); `partially_filled` ордера ВХОДА — активен (ждём терминала; по истечении опроса — `pending`, recovery отменит остаток через 30 мин и учтёт факт) — до этого позиция на часть без SL/TP до 30 мин; `partially_filled` ордера ВЫХОДА — существующий механизм (finalize + флаг + пауза) сохранён.
- Для 025: частично исполненный закрывающий ордер закрывает сделку целиком с флагом «частично … остаток не закрыт» — учёт частичного закрытия как такового не реализован.
- ФТ §14.3, добавить: «Потерянный ответ брокера на отправку/отмену ордера не считается отказом: клиентский ключ сохраняется до отправки, судьба ордера выясняется у брокера по ключу; «не исполнен»/«отменён» — только по подтверждению брокера (отсутствие — спустя ≥120 с от последней отправки), иначе сделка остаётся в ожидании с уведомлением «исход неизвестен» и доводится автоматически (при старте и раз в минуту). Исполненная часть ордера учитывается как позиция; активный частично исполненный ордер входа отменяется на остаток при доведении. Повторная отправка при неизвестном исходе запрещена.»
- ТЗ: колонки `live_trades.client_order_id`, `exit_client_order_id`; `get_order_status_by_client_id`; `resolve_entry_order`/`order_state_verdict`; `UNKNOWN_OUTCOME_CONFIRM_AGE_SEC=120`; recovery под `close_trade`; счёт удалён → `failed`.
- Гайд §7: `alembic current` → `d4f1a9c2b7e0 (head)`; блок: «Обновление с версии старше `d4f1a9c2b7e0` (S8R-AUDIT-024): две nullable-колонки `live_trades`, данные не меняются, обратима; SQLite пересоздаёт таблицу — backup (§6.1)».

### 7. Применённые Stack Gotchas
56, 33, 27, 12/53, 37/58, 59, 05 (лок в recovery).

### 8. Новые Stack Gotchas (кандидат №71, tests/asyncio)
Симптом: в **чужих** конкурентных тестах `RuntimeError: <asyncio.locks.Lock [locked]> is bound to a different event loop` после добавления файла; в изоляции зелено. Причина: модульная константа-исключение (`LOST = BrokerError(...)`) поднимается в каждом тесте, `raise` дописывает `__traceback__`, кадр `_submit_order_locked` держит `lock` → `keyed_lock` живёт в `WeakValueDictionary` вечно; первый контендер привязывает его к своему loop. Второй вариант того же класса (второй проход): тест, захвативший `keyed_lock` вручную и упавший до `release()`, подвешивает весь дальнейший прогон (`_release_exit_order` ждёт тот же лок) — нужен `try/finally`. Диагностика: `gc.get_referrers(lock)` → `frame`. Правило: исключения для моков — фабрики на вызов; ручной захват общего лока — только с `finally: release()`. Файлы: `tests/test_trading/test_order_path_unknown_outcome.py`, `app/common/locks.py`.

### 9. Плагины
py_compile после каждой правки (pyright-LSP в worktree не резолвит `app.*`); typecheck `tsc -b`; context7 (`get_order_state`, `OrderIdType`) + proto-docstring SDK; `mattpocock-skills:tdd`.

### 10. Доработки по /code-review (первый проход, RED → GREEN)
RED-прогон: `17 failed, 16 passed`. 1 [high] порог 120 с для exit-пометок без id + проверка под локом; RED `assert None is not None`, `assert None == 'exit-placed-1'` → GREEN; мутация «убрать проверку под локом» → красный. 2 [high] лок отпускается только при `is_account_not_found`, после захвата — `refresh`; RED `assert False = all([False])`. 3 [high] незнакомый статус → `placed`; RED `assert 'failed' == 'pending'`. 4 [high] `NOT_FOUND` при потере ответа = неизвестно, порог `absence_confirmable`; RED вход `'failed' == 'pending'`, выход `BrokerError` вместо `OrderInFlightError`, отмена `DID NOT RAISE ValidationError`; мутация «без порога» → красный. 5 [high] состояние → отмена → состояние, частичное → факт; RED `Expected cancel_order to not have been awaited`, `assert 0 == 4`. 6 [medium] счёт удалён → `failed`+`order.error`, временно недоступен → `pending`; RED `'pending' == 'failed'`, `ValidationError: Брокер недоступен`. 7 [medium] после `filled` — штатное закрытие; RED `'filled' == 'closed'`. 8 [medium] exit-сигнал best-effort; RED `ValidationError: Судьба ордера … не подтверждена`. 9/10 [low] дубли и внешние ретраи убраны; RED `assert 3 == 1`.

### 11. Второй проход /code-review (RED → GREEN по пунктам)
RED-прогон: `11 failed` (+ тест п.5 отдельно). Мутации: **п.1** «recovery без лока `close_trade`» → красный `assert False` («recovery записал статус сделки, не взяв лок»); **п.3** «вердикт игнорирует исполненные лоты у rejected/cancelled» → 5 красных (`assert 'failed' == 'filled'`, `'filled' == 'closed'`); обе откачены → 44 passed.
1. [high] `_recover_orphan_pending_trades` — под `keyed_lock("close_trade")`, `refresh` и работа только при `status=='pending'`. RED `assert False` (задача завершилась без лока) → GREEN.
2. [high] активный `partially_filled` — не терминал: `order_state_verdict` → `active`; отмена остатка → перечитка → факт; `_poll_order_status_until_filled` ждёт терминала; `_order_status_as_response`: `partially_filled` → `placed`. RED `Expected cancel_order to have been awaited once. Awaited 0 times`, `assert 4 == 30` → GREEN.
3. [high] pending-recovery через `resolve_entry_order` (общее правило, `cancel_active` по TTL). RED `assert 'failed' == 'filled'` (4 лота списаны), `assert 1 >= 2` (после отмены не перечитано) → GREEN.
4. [high] exit-recovery: `rejected/cancelled` с исполнением → finalize + `_flag_partial_exit`; stale `new` → отмена → перечитка. RED `assert 'filled' == 'closed'` → GREEN.
5. [high] сверка позиций пропускает пометку «ответ потерян» (`exit_order_placed_at` без id). RED `assert True is False` → GREEN.
6. [medium] `NOT_FOUND 50004` на чтении = подтверждённое отсутствие (с тем же порогом): на исчезнувшем счёте ордер по старому ключу исполниться не может; путь восстановления песочницы нужен для отправки, не для чтения. RED `assert 'pending' == 'failed'` → GREEN.
7. [medium] известный `broker_order_id` + `NOT_FOUND` → тот же порог (`read_order_state`). RED `DID NOT RAISE ValidationError` → GREEN.
8. [medium] момент последней отправки: `note_entry_sent`/`entry_sent_at` (память процесса, `opened_at` — нижняя граница; миграции нет — после рестарта порог 300 с pending-recovery консервативнее). RED `ImportError: cannot import name 'note_entry_sent'` → GREEN.
9. [low] `_release_exit_order`: пустой `order_id` → снятие по ключу. RED «REJECTED без id оставил пометку» → GREEN.
10. [low] один адаптер на закрытие (`_close_position_locked` → `_close_filled_position_locked`), состояние не перечитывается (`state=`), `_broker_account_gone_reason` делегирован, возраст через `absence_confirmable`. RED `assert 2 == 1` (resolve_calls) → GREEN.
Побочно обновлены 3 старых теста под «после отмены — перечитка» (`test_runtime_orphan_recovery`, `test_exit_order_tracking`, `_LiveAdapter` в `test_reconcile_review_fixes`) и 1 тест первого прохода (активный частичный → отмена).

### 12. Контрольный (третий) проход /code-review (RED → GREEN)
RED-прогон: `2 failed`. Мутация **п.1** «повтор `place_order` снова в контексте NOT_FOUND 50004 (`raise … / except: повтор`)» → красный `assert 'failed' == 'pending'`; откачена → 46 passed.
1. [high] повторная отправка на пересозданном счёте вынесена за пределы `except Exception as order_exc` (флаг `retry_account` → отправка после блока): исключение повтора больше не наследует `__context__` первой ошибки, и `_resolve_lost_entry_response` ищет ордер по НОВОМУ ключу. Классификаторы оставлены на цепочке `__cause__ or __context__` намеренно: адаптер оборачивает ошибки SDK в `BrokerError` без `from` в `place_order`/`cancel_order`, и `is_account_not_found`/`is_order_not_found` опираются именно на неявный `__context__`. RED `assert 'failed' == 'pending'` (поиск по новому ключу не вызван) → GREEN (`get_order_status_by_client_id("reopened-account", <новый ключ>)`, два разных ключа в `place_order`).
2. [low] `forget_entry_sent` на всех терминальных исходах: engine — `rejected`, `gone` после опроса, неожиданный статус, `cancelled`; runtime — три ветки `failed` (без ключа, подтверждённое отсутствие, счёт исчез).
3. [low] `_close_position_locked` отключает поднятый им адаптер в `finally` при любом исходе; `_close_filled_position_locked` отключает только свой (`own_adapter`). RED `assert 0 >= 1` (disconnect не вызван при `ValidationError` вне торговых часов) → GREEN.
Не трогал (по указанию, зона 025): частичное исполнение встречного ордера в движке закрывает сделку целиком без `_flag_partial_exit`.
