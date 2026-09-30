## DEV-AUDIT-086 отчёт — S8R fixes, MEDIUM (после ревью р.2)
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes-b`, d4222dc, ничего не закоммичено)

### 1. Что реализовано
- `app/common/audit.py`:
  - `audit()` / `build_audit()`, все action — константы `AUDIT_*`;
  - строка журнала пишется в транзакции действия;
  - секреты из деталей вырезаются, детали не длиннее `_MAX_DETAILS` (JSON всегда валиден).
- `app/common/outbox.py` + `NotificationService`:
  - `PendingEvent` пишется до commit состояния, publish идёт с `outbox_id`;
  - `processed_at` ставится вместе с in-app уведомлением;
  - при старте повторяются только `order.placed`, `trade.filled`, `cb.triggered`.
- Журнал ведётся по: auth, admin, broker, trading (старт/пауза/возобновление/стоп/закрытия), ордер, CB.

**Ревью р.2: исправлено 1–9**
1. `order.placed` в runtime больше не публикуется повторно, единственный издатель — движок. WS-карточки и метрики на это событие не опирались: фронт читает только `active_position_*`, `latency_ms` никто не читал. Тест: один вход даёт одно «Ордер выставлен».
2. Фан-аут идемпотентен по `(outbox_id, user_id)` без миграции. Уведомление помечается полями `related_entity_type="pending_event"` и `related_entity_id=outbox_id`; для этого неизвестного типа фронт не строит ссылку, а Telegram — кнопку. `processed_at` ставится после доставки всем получателям, уже обработанную строку повторно не рассылаем.
3. `connection.lost` при старте не доставляется: строка помечается обработанной с причиной `stale_state`, путь пересчёта получателей удалён.
4. Запись `connection.lost` в outbox и publish идут фоновой задачей: потолок 5 с, ссылки хранятся в set, ошибки пишутся в лог. Цикл стрима и `_enter_terminal_state` БД не ждут. В shutdown задачи дожидаются до `close_db`.
5. Ручное закрытие: `TradeResponse` собирается до записи журнала, журнал пишется отдельной короткой сессией, основная сессия не откатывается.
6. Неудачный вход: для неизвестного логина пишутся только `username_sha256[:12]` и длина, для существующего — только `user_id`.
7. Аудит неудачных входов идёт отдельной транзакцией. Сброс блокировки у деактивированного не фиксируется. Ошибка записи журнала — лог, ответ по-прежнему 401.
8. `SessionRuntime` передаёт `user_id` в `process_signal` → `_open_entry` → `_stage_order_placed`, без SELECT. Раньше runtime параметр не передавал. Тот же `user_id` теперь идёт в резолв лота — это тот же владелец, семантика прежняя.
9. `parity_override` пишется через `build_audit(request=…)`.

### 2. Файлы
- Новые: `backend/app/common/{audit,outbox}.py`, `backend/tests/test_security/test_audit_log_events.py`, `backend/tests/test_notification/test_pending_events.py`.
- Изменены: `app/{admin,auth,broker,trading}/router.py`, `auth/service.py`, `broker/service.py`, `broker/tinvest/multiplexer.py`, `circuit_breaker/engine.py`, `common/event_bus.py`, `main.py`, `notification/service.py`, `trading/{engine,runtime,service}.py`.

### 3. Тесты
- RED (р.1): `KeyError: 'auth.login'` и `AssertionError: cb.triggered опубликован до записи pending_events`.
- GREEN: 23 теста карточки.
- Мутация р.2 («processed_at после первого получателя») падает на `assert datetime(...) is None` в `test_fan_out_retry_delivers_rest_without_duplicates`; откачена, md5 сверен.
- Дополнительные проверки: возврат второй публикации `order.placed` → `assert 2 == 1`; р.1 — удаление `audit()` из `change_password` → `KeyError`.
- Гейты: pytest 4419 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (194); bandit M0/H0.
- Фронт не менялся (typecheck/lint/build ok в р.1); vitest — на уровне пакета.

### 4. Integration points
Всё подключено: `main.py` (фабрика, replay, ожидание при shutdown), `multiplexer.py:842`, `notification/service.py:397/892`, `circuit_breaker/engine.py`, `trading/engine.py`, `runtime.py`. NOT CONNECTED нет.

### 5. Контракты
- Миграции нет.
- `TradingSessionManager.start_session(audit_entries=…)`.
- В payload четырёх событий добавлен `outbox_id`.
- Runtime больше не публикует `order.placed`: пропадают поля `latency_ms` и `order_id`, у них не было потребителей.

### 6. Тексты для документов
- **ТЗ §2.4** (замена абзаца «Гарантия доставки»): «Для `order.placed`, `trade.filled` (исполнение), `cb.triggered`, `connection.lost` строка `pending_events` пишется в транзакции состояния до commit; publish — после, с `outbox_id`. `processed_at` ставится в транзакции in-app уведомления (идемпотентно); фан-аут `connection.lost` — идемпотентно по (outbox_id, user_id), `processed_at` после доставки всем. При старте повторяются необработанные `order.placed`/`trade.filled`/`cb.triggered` в окне 1 с…1 ч, ≤200 строк; `connection.lost` снимается с повтора (`stale_state`). Запись `connection.lost` — фоновой задачей ≤5 с, стрим её не ждёт.»
- **ТЗ §3.11**: «action — перечень `AUDIT_ACTIONS` (`app/common/audit.py`): auth.*, admin.user_created, broker.*, session.*, position.closed_manual, order.placed, cb.triggered, parity_override; source — `web` (с ip) | `system`. Детали — только идентификаторы; неизвестный логин — sha256[:12] и длина.»
- **Гайд §3.3**: «На старте backend повторно доставляет необработанные критические события прошлого запуска (`pending_events`, окно 1 ч); при остановке дожидается фоновых записей outbox (≤6 с).»
- Не покрыто: закрытия из Telegram и SL/TP, запись о восстановлении после рестарта, ротация таблиц по `created_at`.

### 7. Применённые Stack Gotchas
18, 26, 37, 48.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
tdd; вместо LSP — mypy и py_compile.
