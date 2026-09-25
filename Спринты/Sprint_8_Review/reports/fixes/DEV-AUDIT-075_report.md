## DEV-AUDIT-075 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. Реестр `_EXIT_IN_FLIGHT` (TTL 900 с) и предварительный пропуск по локальному таймеру удалены; `import time` убран.
2. Источник истины «ордер в полёте» — колонки сделки: на каждой свече монитор идёт в `close_position` (единственный путь отправки), чей guard перечитывает `exit_broker_order_id`/`exit_order_placed_at` под локом `close_trade` (`refresh`, gotcha-58) и бросает `OrderInFlightError` без обращения к брокеру.
3. После снятия пометки recovery (`rejected`/`cancelled`) следующая свеча снова закрывает — без ожидания TTL.
4. `OrderInFlightError` → уведомление существующим `_publish_close_failed` (`order.error`, текст «автозакрытие по … не выполнено, позиция остаётся открытой»), один раз на эпизод: кэш `_IN_FLIGHT_NOTIFIED[trade_id] = exit_order_placed_at`, инвалидируется самой пометкой (новый момент = новый эпизод) и чистится при закрытии.
5. Гонка с ручным закрытием (G2-16): перед публикацией «не выполнено» статус перечитывается запросом по колонкам (`_trade_exit_state`, безопасно после rollback — gotcha-37); закрыта → лог `risk_monitor_close_skipped_already_closed`, публикации нет.
6. Лог `risk_monitor_close_order_in_flight` получил поле `first_in_episode`.
7. Autouse-фикстура conftest переведена на новый кэш (иначе все trading-тесты падали бы на `AttributeError`).

### 2. Файлы
- Изменён: `backend/app/trading/risk_monitor.py`
- Изменён: `backend/tests/test_trading/conftest.py` (фикстура сброса)
- Новый: `backend/tests/test_trading/test_risk_monitor_in_flight.py` (4 теста)

### 3. Тесты
RED: `AssertionError: ордер в полёте должен дойти до пользователя / assert 0 == 1 where 0 = len([])`; гонка: `Left contains one more item: {'reason': 'автозакрытие по stop_loss не выполнено, позиция остаётся открытой: Невозможно закрыть сделку со статусом closed', …}`.
GREEN: `test_order_in_flight_publishes_notification`, `test_retry_allowed_after_exit_order_released`, `test_same_episode_notifies_once`, `test_manual_close_race_does_not_publish_failure`; смежные `test_sltp_review_fixes`, `test_risk_monitor`, `test_exit_order_tracking` — 41 passed.
Мутация «вернуть таймер» (модульный dict + пропуск при `monotonic() − t < 900`) → `test_retry_allowed_after_exit_order_released`: `assert 1 == 2 … place_order.await_count`; откат по бэкапу, md5 совпал.
Гейты: pytest 2891 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `runtime.py:2720` → `check_sl_tp` → `_close_via_broker` → `_trade_exit_state`/`_publish_close_failed` (`risk_monitor.py:531,548,565,584`); `order.error` → `EVENT_MAP` (`notification/service.py:110`), листенер `listen_session_events` (`main.py:215`, `engine.py:966`). Новых event_type нет.

### 5. Контракты
API/схемы/миграции не менялись.

### 6. Проблемы / TODO / правки документов
- ФТ v4.0 (таблица истории, карточка 075): «Если закрывающий ордер отправлен брокеру, но исполнение не подтвердилось, пользователь получает то же уведомление «автозакрытие не выполнено, позиция остаётся открытой» — один раз на эпизод, не на каждой свече; после подтверждения брокером отказа повтор закрытия уходит на следующей же свече. Ложное уведомление для позиции, закрытой вручную в тот же момент, устранено.»
- ТЗ v3.0 §5.4: «`S8R-AUDIT-075`: реестр `risk_monitor._EXIT_IN_FLIGHT` (TTL 15 мин) удалён; состояние «в полёте» — только колонки `LiveTrade`, guard `close_position` под локом; дедуп уведомления `_IN_FLIGHT_NOTIFIED` по `(trade_id, exit_order_placed_at)`; статус перечитывается перед `order.error`.»
- Вне карточки (не правил): устаревшие комментарии со ссылкой на `_EXIT_IN_FLIGHT` — `models.py:99`, `engine.py:3521`; предлагаю заменить на «пометка на сделке (`S8R-AUDIT-075`)».
- Развилка: при гонке с ручным закрытием `close_failed` остаётся `True` (сигнал стратегии на этой свече пропускается) — консервативно, поведение не менял.

### 7. Применённые Stack Gotchas
37 (чтение колонок после rollback), 58 (refresh под локом, не `populate_existing`), 71 (фабрики исключений/ответов в моках), 51 (in-app подтверждается `order.error`, внешняя доставка — DEV_MODE).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile (fallback pyright) — OK; typecheck `tsc -b` — 0; context7 — не требовался (сторонние API не менялись); tdd (`mattpocock-skills:tdd`) — RED → GREEN → мутация.

### 10. Доработки по /code-review
**П.1 (medium)** — `_trade_exit_state` теперь сам ловит сбой чтения (warning `risk_monitor_trade_state_read_failed`, возврат `None`); обе `except`-ветки трактуют `None` консервативно: позиция считается открытой, уведомление уходит, цикл по сделкам свечи продолжается. В in-flight-ветке при неизвестном моменте пометки ключ-заглушка `None` ограничивает повтор одним уведомлением после первого удачного чтения.
Тест `test_status_reread_failure_does_not_break_candle[order_in_flight|broker_error]` (две сделки, `db.execute` падает `OperationalError("database is locked")` после первого закрытия). RED: `sqlalchemy.exc.OperationalError: (builtins.Exception) database is locked` выходит из `check_sl_tp`. Мутация «`raise read_exc` вместо warning/None» → та же строка; откат по бэкапу, md5 совпал.

**П.2 (low)** — `_prune_in_flight_notified()` в начале `check_sl_tp`: при непустом кэше один запрос по его ключам (`status in (filled, pending) AND exit_order_placed_at IS NOT NULL`), остальные ключи снимаются — закрытие recovery/вручную/«Стопом» больше не оставляет запись до рестарта; сбой чтения — пропуск прохода. Выбрано как простейшее: не требует хуков в recovery/`close_position`/stop и покрывает все пути закрытия.
Тест `test_notified_cache_pruned_when_trade_closed_elsewhere`. RED: `assert 1 not in {1: datetime(2026, 9, 25, …)}`. Мутация «убрать вызов `_prune_in_flight_notified`» → та же строка; откат по бэкапу, md5 совпал.

Попутно: mypy нашёл `str | None` → `str` в двух присваиваниях `status` — добавлены аннотации, поведение не менялось. `engine.py` (правка оркестратора по комментарию `_EXIT_IN_FLIGHT`) не трогал.
Гейты после доработок: pytest 2894 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; фронт не менялся (typecheck/lint/build — по первому прогону, vitest — на уровне пакета). Integration: `risk_monitor.py:274` (`_prune_in_flight_notified`), `:532/:577` (`_trade_exit_state`). Файлы карточки в `git status`: `risk_monitor.py`, `conftest.py`, `test_risk_monitor_in_flight.py` (+ `engine.py` оркестратора); ничего не закоммичено.
