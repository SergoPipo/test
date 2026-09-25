## DEV-AUDIT-007 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes`, HEAD bca0cec, ничего не закоммичено)

### 1. Что реализовано
1. `_recover_orphan_pending_trades`: исключение из `get_order_status` (сеть/таймаут/`INTERNAL 70001`) больше не переводит сделку в `failed` — warning, `still_pending += 1`, сделка остаётся `pending`.
2. Ветка `new` старше `STALE_PENDING_CANCEL_THRESHOLD_SEC`: исключение из `cancel_order` → warning, `still_pending += 1`, `continue` (без записи в БД); `failed` — только после подтверждённой отмены.
3. `failed` по-прежнему ставится по подтверждённому `rejected`/`cancelled` и в ветке без `broker_order_id` (не тронута), порог TTL не тронут.
4. Докстринг метода описывает новую семантику; следующий проход `_periodic_recovery_loop` (60 с) доводит сделку по ответу брокера.
5. Тесты: сняты оба `xfail`, `get_order_status` параметризован (`RuntimeError` + `asyncio.TimeoutError`), добавлены регресс-страховка `rejected`/`cancelled` → `failed` и сценарий «сбой → следующий проход даёт `filled` с ценой брокера».
6. Существующий W8h-тест `test_pending_new_above_ttl_cancel_fails_still_failed` закреплял старое поведение — перевёрнут и переименован в `..._keeps_pending`, докстринг класса дополнен.
7. Моки — `AsyncMock(spec=BaseBrokerAdapter)` (gotcha-27). `is_order_not_found` для входных ордеров намеренно не вводил (не в рецепте; см. §6).

### 2. Файлы
Изменённые: `backend/app/trading/runtime.py`; `backend/tests/test_trading/test_audit_s8r_orphan_recovery_errors.py`; `backend/tests/test_trading/test_runtime_orphan_recovery.py`. Новых/удалённых нет.

### 3. Тесты
RED: `AssertionError: failed` / `assert 'failed' == 'pending'` (`test_audit_s8r_orphan_recovery_errors.py:100` и `:116`; лог `orphan_pending_recovery_done … resolved_failed=1 still_pending=0`). GREEN: 6 тестов файла карточки + 10 `test_runtime_orphan_recovery.py` = 16 passed. Мутация: в наружный `except` возвращена запись `db_trade.status = "failed"` → `assert 'failed' == 'pending'` (3 теста красные), откачена (`grep MUTATION` → 0), снова 16 passed. Гейты: pytest **2765 passed / 16 xfailed / 0 failed** (≥ 2752; xfailed 18 − 2); `reason="S8R-AUDIT-007` → пусто, `it.fails` → 0; ruff 0; mypy Success (179); bandit M0/H0 (exit 0); typecheck 0; lint 0; build ok; vitest **925 passed / 2 expected fail / 1 failed** (`StrategyEditPageDelete` — `Test timed out in 5000ms`, отдельно проходит; флейк под нагрузкой, фронт не менялся — см. §6).

### 4. Integration points
✅ Новых сущностей нет. Правленый метод вызывается в production: `runtime.py:514` (`restore_all`) и `:951` (`_periodic_recovery_loop`).

### 5. Контракты
API/схемы/миграции не менялись.

### 6. Проблемы / TODO / правки документов / находки
- **vitest**: при load average 19–25 (параллельные субагенты) три полных прогона дают 1/7/1 упавших файлов, все — `Test timed out in 5000ms`; каждый файл проходит отдельно (`StrategyEditPageDelete` с `--testTimeout=60000` — 2/2). Регресса нет (`git status`: только backend). Оркестратору: перегнать `pnpm test` на тихой машине; порог 926 не достигнут на 1 тест только из-за таймаута.
- **ФТ v4.0** (таблица истории, дописать): «**Сделка не закрывается «неудачной» по молчанию брокера** (S8R-AUDIT-007): если при проверке зависшего входного ордера брокер не ответил или отмена не подтверждена, сделка остаётся в ожидании и проверяется снова через минуту; «неудачной» она становится только по подтверждённому отказу/отмене брокера. Раньше сбой связи закрывал в учёте реально купленные бумаги: стоп-лосс не отслеживался, а следующий сигнал открывал вторую позицию.» Строка W8h («Cancel exception ловится — статус всё равно failed») — устарела, пометить.
- **ТЗ v3.0** (таблица истории, §5.4): «`S8R-AUDIT-007`: `SessionRuntime._recover_orphan_pending_trades` — исключение из `get_order_status`/`cancel_order` → `still_pending`, без записи в БД; `failed` только по `rejected`/`cancelled` или после успешного `cancel_order` (зеркало `_recover_orphan_exit_orders`).»
- Находка: входной ордер с `NOT_FOUND` у брокера теперь останется `pending` бессрочно (в exit-recovery для этого есть `is_order_not_found` → release). Вне рецепта; предлагаю отдельной карточкой.
- Находка (ловушка п.5 карточки): во фронте нет подписи для `LiveTrade.status='pending'` в торговых компонентах (есть только у бэктестов) — «ожидает подтверждения брокера» пользователю не показывается.

### 7. Применённые Stack Gotchas
56 (нет ответа ≠ нет ордера), 27 (`spec=` у моков), 33 (цена из `GetOrderState`), 05/58 — прочитаны, локи и `populate_existing` не затронуты.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
pyright-lsp → fallback `py_compile` (OK); typecheck `tsc -b` (0); context7 не требовался (сторонние API не менялись); `mattpocock-skills:tdd` — швы по карточке, RED → GREEN → мутация.
