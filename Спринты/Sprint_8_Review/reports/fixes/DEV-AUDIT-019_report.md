## DEV-AUDIT-019 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту
### 1. Что реализовано
- Удалены модули без вызывающих в `app/`: `strategy/code_generator.py`, `sandbox/executor.py` (`CodeSandbox`), `sandbox/router.py`, `sandbox/schemas.py`, `notification/dispatchers.py`. `_blocks_to_sandbox` уже удалила карточка 001.
- Из `TradingSessionManager` удалён `restore_sessions`.
- Из `BacktestService` удалены `create_backtest`, `get_backtest`, `get_trades`, `get_equity_curve`, `delete_backtest` и их private-хелперы, а также `self.engine`. Остались `_save_result` и `_run_parity_check`.
- Из `rate_limiter.py` удалена персистентность: `Persistent…`, `save_all/load_all`, `get_state/restore_state`, `DEFAULT_PERSIST_PATH`.
- В `get_instruments_summary` теперь используется `user_id`: владелец проверяется JOIN'ом в том же запросе, по чужой стратегии сводка пустая.
- Parity-турнир `test_signal_parity` перенацелен на `ir_codegen`. Stochastic-xfail снят: паритет закреплён в `test_ir_codegen_parity`.
- Тесты песочницы `test_sandbox_escape` перенацелены на `BacktestEngine._compile_strategy`. Синхронные сценарии `promotes_draft` идут через `_run_backtest_task`.
- `test_executor.py` и `test_timeout_validation.py` удалены: компиляцию кода из IR через реальный путь покрывают parity-тесты, лимиты — `test_execution_limits.py`.
### 2. Файлы
Новые: `tests/unit/test_dead_code_guard.py`. Удалены: 5 модулей (п. 1) и тесты `test_code_generator`, `test_executor`, `test_timeout_validation`, `test_dispatchers`. Изменены: `backtest/service.py`, `strategy/service.py`, `trading/engine.py`, `rate_limiter.py`; комментарии в `main.py`, `backtest/engine.py`, `module_proxies.py`; 13 тестовых файлов.
### 3. Тесты
RED: `AssertionError: app.strategy.code_generator вернулся (S8R-AUDIT-019)` и `assert [StrategyInst…] == []` (22 failed). GREEN: guard 21 + owner 1.
Мутации:
- вернул `code_generator.py` → тест падает с той же строкой;
- убрал фильтр владельца → тест падает с `assert [StrategyInst…] == []`.
Гейты: pytest **4562 passed / 1 skipped / 1 xfailed / 0 failed** (было ≥4604, разница — удалённые тесты); coverage **91 %** (`rate_limiter` 100 %); ruff 0; mypy Success (192); bandit Medium 0 / High 0; typecheck 0; lint 0; build ok. vitest: фронт не менялся — на уровне пакета.
### 4. Integration points
✅ `strategy/router.py:96` → `get_instruments_summary(user.id, s.id)`. Нового production-кода нет.
### 5. Контракты
API, схемы и миграции не менялись. `/api/v1/sandbox/*` был снят ещё в 001.
### 6. Проблемы / ТЗ / находки
Предлагаемые правки ТЗ:
- §3 (стр. 213): убрать строку `code_generator.py`;
- §5.2.3: заменить на «Генерация кода — `ir_codegen.ir_to_backtrader_code` (§5.2.4)»;
- §5.2.4: убрать фразу «Старый `code_generator.py` оставлен…»;
- §5.7 dispatch_external: путь `app/notification/service.py::NotificationService.dispatch_external`;
- §5.11 (стр. 2027): вместо «executor… не используется» — «удалён (S8R-AUDIT-019)»;
- стр. 2036: «в namespace `BacktestEngine._compile_strategy`»;
- таблица тестов (стр. 2723): `strategy/code_generator` → `strategy/ir_codegen`.

Новые находки:
- (а) `RestrictedPython==8.1` в `pyproject.toml` больше не используется — убрать отдельно.
- (б) Возможный дрейф ключей параметров: `params.py`/`params_sync.py` дают `bb_*`, а `ir_codegen._gen_params` — `bollinger_period/_dev`. Комментарии там и в `strategy/router.py:272` ссылаются на удалённый `code_generator`. Нужна проверка по 048 или отдельной карточкой.

Самопроверка: 1–2 — новых записей и уведомлений нет; 3 — тесты идут через `_run_backtest_task` и `_compile_strategy`; 4 — н/п; 5 — единственный вызывающий проверен; 6 — н/п.
### 7. Stack Gotchas
35 (единый IR), 50 (только worktree), 29 (coverage).
### 8. Новые Stack Gotchas
Нет.
### 9. Плагины
py_compile/ruff/mypy — да; typecheck — да; context7 — не нужен (сторонние API не трогались); tdd — `mattpocock-skills:tdd`.
