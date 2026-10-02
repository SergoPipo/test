## DEV-REV-LQ отчёт — S8R fixes, LOW (раунд 4)
Статус: ✅ готово к коммиту
### 1. Реализовано
- п.1: реестр `_JOBS` по `broker_account_id`; повторный запуск — флаг «ещё проход» (самое свежее переоткрытие, `exclude_ids` объединяются).
- п.2: `ReopenPassResult.status` (done/portfolio_unknown/locks_busy); занятые локи → отложенный повтор, флаг — только если портфель не прочитан ни разу; флагуются сессии неподтверждённых кандидатов.
- п.3: первый проход движка — в своей сессии и в try; исключение → job; отмена → job, затем проброс.
- п.4/п.7: единое правило `reopen_trade_class` + один запрос `_reopen_snapshot`; снимок под локами пересчитывает deferred.
- п.5: `begin_reconcile_shutdown` в начале shutdown; `cancel_reconcile_tasks` + `set_reconcile_runtime(None)` — после `session_runtime.shutdown()`.
- п.6/п.8: удалены `_reconcile_positions_after_reopen`, `_reconcile_candidate_ids`, `RECONCILE_LOCK_ATTEMPTS`, `_sandbox_adapter`; комментарии обновлены.
### 2. Тесты (миграция)
Хелпер `tests/reopen_pass.py`; 7 файлов переведены на новый путь. Смена семантики: pending сверка не трогает (`test_accounting_edges`), появившаяся сделка — в deferred вместо перезахода, выход в полёте — deferred без ожидания лока (`test_reconcile_lock_divergence`).
### 3. Результаты
RED: `assert 5 == 1`, `OperationalError: database is locked`, `после отказа по локам нет отложенного повтора`, `no attribute 'begin_reconcile_shutdown'`. GREEN 23/23. Мутации: п.1 → `assert 5 == 1`; п.3 → `OperationalError`. Гейты: pytest 5166/1 skipped/0 failed; ruff 0; mypy Success (199); bandit M0/H0; typecheck/lint/build ok; vitest — фронт не менялся.
### 4. Integration
✅ `service.py` `_spawn_reconcile`; `engine.py` `_recover_stale_sandbox_account`; `main.py` lifespan.
### 6. Находки
Бывший pending, исполнившийся за время ожидания локов (по п.4 — в deferred), защищён только портфелем Y (риск неполного портфеля, gotcha-56).

### Дополнение (точечная правка: портфель «только деньги»)
`AccountSwitch.reopened_at_exact` (из `recovery.reopened_at`): при неточном моменте портфель без бумаг → `None` (не прочитан), кандидаты не закрываются, повтор по общим правилам; при точном — законный свежий счёт. RED: `unexpected keyword argument 'reopened_at_exact'`. GREEN 26/26 (+3 теста); точечные reopen-тесты 79 passed. Мутации: правило всегда → `assert False` (точный момент не закрыл фантомы); никогда → `assert 1 == 3` (нет повтора). ruff 0, mypy Success (199). Полный pytest после правки не перезапускался.
