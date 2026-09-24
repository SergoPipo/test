## DEV-AUDIT-001 отчёт — S8R fixes, BLOCKER
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes`, HEAD 47bf073, ничего не закоммичено)

### 1. Что реализовано
1. Новый `app/sandbox/module_proxies.py`: allow-list атрибутов `datetime/math/decimal/bt` + прокси `SimpleNamespace` вместо модулей (свежие на запуск; `bt.indicators` — только классы; инвариант «атрибут не модуль»).
2. `ast_analyzer.py`: allow-list атрибутов на именах разрешённых модулей (учтены `import X as y`, `from X import Y`).
3. `executor.py`: прокси в namespace и в `_safe_import`; копия `safe_builtins` (раньше мутировался общий словарь RestrictedPython).
4. `backtest/engine.py::_compile_strategy`: builtins → allow-list `_STRATEGY_BUILTINS` (без `print/getattr/type`), `__name__`, прокси для `bt/math/datetime` и legacy-`import`.
5. Q4-001=(а): `runtime_backtrader_code(blocks_json)` без fallback → `StrategyNotExecutableError` (наследник `ValidationError`, 422). Единая проверка `ir.parse_executable_blocks` — бэктест/rerun/queued/grid, старт сессии (`TradingService.start_session` → 422), live-маршрутизация.
6. `trading/engine.py`: legacy-путь (`_legacy_process_candle`, `_get_strategy_code`, `_blocks_to_sandbox`, `_execute_strategy`) удалён, −313 строк; версия без IR → HOLD + warning.
7. `_validate_strategy_for_backtest`: битые/пустые блоки → понятный текст (`except: pass` убран).
8. 028 закрыто целиком; из 019 — `_blocks_to_sandbox`; остальное 019 (`code_generator.py`, `restore_sessions`, мёртвые методы `BacktestService`, `dispatchers.py`) — LOW, не трогал.
9. `create_version`/`generated_code` не менял: поле хранится (превью), не исполняется нигде (grep: только чтение параметров).

### 2. Файлы
Новые: `app/sandbox/module_proxies.py`, `tests/strategy_blocks.py`, `tests/test_trading/test_audit_s8r_001_no_legacy_code_path.py`. Изменены: `app/common/exceptions.py`, `sandbox/{ast_analyzer,executor}.py`, `backtest/{engine,router,service}.py`, `strategy/{ir,ir_codegen}.py`, `trading/{engine,service}.py`; тесты `test_audit_s8r_escape.py`, sandbox `test_router.py`, `test_ir_codegen.py`, backtest `test_api/test_router_full/test_grid_endpoint/test_service.py`, `test_trading/conftest.py`. Удалён `test_engine_blocks_to_sandbox.py`.

### 3. Тесты
RED: `AssertionError: AnalysisResult(is_safe=True, issues=[])`; `ExecutionResult(success=True, output='S8R_AUDIT_001_CWD=/…/backend\n')`; `Failed: DID NOT RAISE` (engine, `bt.sys`, `bt.indicators.sys`); `assert 202 == 422` (D1-04, `POST /api/v1/backtest`); `DID NOT RAISE ValidationError` (старт сессии); `hasattr(SignalProcessor, '_blocks_to_sandbox')`.
GREEN: 22 (`test_audit_s8r_escape.py`) + 3 (trading) + эндпоинт `sandbox/execute`.
Мутация: голый `datetime` в namespace executor и engine → `test_executor_boundary_holds_without_analyzer`: `success=True, output='S8R_AUDIT_001_CWD=…'`; `test_backtest_boundary_holds_without_analyzer`: `DID NOT RAISE` → откат → 22 passed (тесты с отключённым анализатором нужны: слой AST маскирует мутацию).
Гейты (первый круг): pytest 2692/19/0; итог после доработок — см. раздел 10.

### 4. Integration points
✅ `build_stdlib_proxies` — `executor.py:101`, `engine.py:575`; `build_backtrader_proxy` — `engine.py:576`; `parse_executable_blocks` — `backtest/router.py:81`, `ir_codegen.py:179`, `trading/service.py:76`, `trading/engine.py:839`; sandbox-роутер — `main.py:348`.

### 5. Контракты
Миграций нет. Старт бэктеста/rerun/run-async/grid/сессии для версии без блоков → 422 `detail: «Версия стратегии не содержит блоков: исполнение произвольного кода отключено, пересоберите стратегию в конструкторе»`. Сигнатура `runtime_backtrader_code(blocks_json)` (параметр `fallback_code` удалён). Фронт не менялся.

### 6. Проблемы / правки документов / находки
- ФТ §12.5: «Исполняется только код, сгенерированный из валидированных блоков; сохранённый текст кода не исполняется. Модули — по allow-list атрибутов (`datetime`: классы дат; `math`; `decimal`: `Decimal`/округления; `backtrader`: `Strategy, indicators, Order, TimeFrame`). Версия без блоков — отказ 422».
- ТЗ §5.11.1: `MODULE_ALLOWED_ATTRS` (источник `app/sandbox/module_proxies.py`); §5.11.2: прокси вместо модулей, builtins бэктеста — allow-list; live: только IR-интерпретатор.
- Фикстуры с `blocks_json="{}"` (7 файлов) → `ENTRY_SMA20_GT_70`.
- Находки: докстринг `strategy/code_consistency.py` устарел; лимиты ресурсов — S8R-AUDIT-006.

### 7. Применённые Stack Gotchas
02, 30, 35, 50, 60.

### 8. Новые Stack Gotchas
Кандидат audit §6 **№61 подтверждён**: симптом — `datetime.sys.modules['os']` проходит денилист; причина — модули в namespace; правило — прокси с allow-list + тест с отключённым анализатором; файлы `module_proxies.py`, `test_audit_s8r_escape.py`.

### 9. Плагины
pyright-lsp недоступен → `py_compile` (все OK); `tsc -b` 0; context7 не вызывался — API RestrictedPython/backtrader проверены интроспекцией в venv (`safe_globals={'__builtins__'}`, `backtrader` держит `sys/os`); TDD — `mattpocock-skills:tdd`.

### 10. Доработки по /code-review (оркестратор, 2026-09-24)
Правка оркестратора (`ImportFrom` allow-list + 2 теста) сохранена. По каждому пункту — тест первым.
1. **[high] `type` индикатора → идентификатор в коде.** RED: `Failed: DID NOT RAISE ValidationError` (`parse_blocks` с `type='indicator_sma\n    x = 1'`). Правка: `ir.py::_ind_from_block` — `kind` только из `_IND_MAP`, иначе `ValidationError`; `parse_executable_blocks` вызывает `validate_blocks_json` (allow-list типов и полей) до IR. GREEN: `test_unknown_indicator_type_is_rejected_not_interpolated`, `..._still_generates_code`.
2. **[high] `/api/v1/sandbox/*`.** Фронт не вызывает (`grep frontend/src` пуст), `/analyze` тоже → роутер снят с регистрации в `main.py` (модуль и `CodeSandbox` оставлены — 019). RED: `assert 200 == 404` (execute и analyze). `test_router.py` переписан: не регистрирован + 404 для обоих под auth.
3. **[medium] resume/restore без IR.** RED: `DID NOT RAISE ValidationError` (resume); `assert 3 not in {3: _SessionListener}` (restore поднял listener). Правка: `_resume_session_locked` → `parse_executable_blocks` (422); `restore_all` → `_executable_session_ids` (один запрос) → неисполнимые `active/suspended` → `paused` (`_pause_not_executable`), listener не поднимается, пару не занимают, событие `session.paused` с `reason` (существующее, без нового `event_type`) + warning. Тесты: `test_resume_refuses_session_on_version_without_ir`, `TestRestoreVersionWithoutIR`.
4. **[medium] предикат flat-list.** Production-путей, пишущих flat, нет: `POST /strategy/parse-template` отдаёт flat фронту, тот конвертирует `flatBlocksToWorkspaceState` → Blockly до сохранения; AI-чат `blocks_json` не пишет. Сделано (а): `strategy/router.py::create_version_from_params` — предикат `_is_executable_blocks` (`parse_executable_blocks`); flat/code-only → text-путь (параметр не в коде → 422 «не найдены в коде»). RED: `assert 201 == 422`. (б) не требуется; `has_meaningful_blocks` в `params.py` оставлен (тесты).
5. **[medium] `GET /backtest/strategy-params/{id}`.** Имена из `runtime_backtrader_code(blocks_json)`; без IR → `params: []` (фронт `GridSearchForm` на `[]` откатывается к свободному вводу). RED: `{'rsi_period','stop_loss_pct'} != {'sma_period'}`.
6. **[medium] `from X import Y` отключал проверку.** `module_proxies.public_attrs_of_import` (из тех же прокси, без модулей); анализатор: allow-list модуля ∪ публичные атрибуты импортированного объекта, без анализа областей. RED: `is_safe=True` для `leak = datetime.sys.modules\ndef f(): from datetime import datetime`. GREEN + позитивные (`datetime.now()`, `indicators.RSI`, `dt.time`).
7. **[low] двойной парс.** `_executable_ir` → IR один раз, передаётся в `_interpreter_process_candle(session, candles, ir)`. RED: `parse_blocks вызван 2 раз(а)`.
8. **[low] мёртвая ветка валидатора.** `_validate_strategy_for_backtest`: единственная точка — `runtime_backtrader_code` при `code is None`; тексты сохранены. RED: `Left contains … 'не удалось разобрать (AssertionError: reparsed)'`.
Мутация: `kind = _IND_MAP.get(btype_str, btype_str)` + отключён `validate_blocks_json` → `FAILED test_unknown_indicator_type_is_rejected_not_interpolated: DID NOT RAISE` → откат → 40 passed.
Фикстуры с `blocks_json="{}"` у restore/resume-тестов (4 файла) → `ENTRY_SMA20_GT_70`.
**Гейты после первого круга:** pytest 2708/19/0 (итог — раздел 11); ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 926 passed; xfail/it.fails с `S8R-AUDIT-001` — 0. Integration: `_is_executable_blocks` — `strategy/router.py:255`; `_executable_session_ids`/`_pause_not_executable` — `runtime.py:566/595`; `public_attrs_of_import` — `ast_analyzer.py:214`; `_executable_ir` — `trading/engine.py:809`. Контракт: `/api/v1/sandbox/*` → 404; `POST /trading/sessions/{id}/resume` → 422 для версии без блоков. Для ТЗ §5.11: «эндпоинты песочницы удалены из API». Не трогал (по указанию): SL/TP из `generated_code` (080), лимиты (006). Git: ничего не закоммичено, HEAD 47bf073.

### 11. Второй круг /code-review (restore_all, 2026-09-24)
Тесты — `tests/test_trading/test_runtime_recovery.py::TestRestoreVersionWithoutIRSecondReview` (по одному на находку, RED фактической строкой до правки).
1. **[medium] причина паузы не сохранялась.** RED: `AssertionError: ожидалось постоянное уведомление о паузе / assert []`. Правка: `_pause_not_executable` — тем же механизмом, что `_notify_position_mismatch`: `create_notification(event_type="session_recovered", severity="warning", title="Сессия не восстановлена: поставлена на паузу", body="<стратегия> (<тикер>): <причина>", related_entity_type="trading_session")`, best-effort (warning при сбое); событие `session.paused` сохранено. Нового event_type нет: `session_recovered` уже в `EVENT_MAP`/`EVENT_TYPE_LABELS` (категория «Восстановление сессии» — исход restore; sync-тест 18 ключей не тронут). `position_mismatch_note` не использую: его семантика на фронте — расхождение позиций.
2. **[medium] пауза до сверки позиций.** RED: `AssertionError: сверка позиций не выполнена до паузы / assert None` (`position_mismatch_note`). Правка: для неисполнимых sandbox/real-сессий с `broker_account_id` в `restore_all` вызывается тот же `_reconcile_broker_positions(session, portfolio_cache=portfolio_cache)` ДО `_pause_not_executable` (тот же лок-порядок `locks.py`, ничего нового не берётся). Введён `portfolio_cache` на весь проход restore и передан также в существующий вызов сверки (`runtime.py:604/698`) — «один опрос портфеля на счёт за проход» теперь выполняется и в restore (раньше сверка в restore опрашивала брокера на каждую сессию).
3. **[low] `_executable_session_ids` не обёрнут.** RED: `sqlalchemy.exc.OperationalError: (builtins.Exception) database is locked`. Правка: запрос в `try/except` → warning `session_restore_executability_check_failed` и прежнее поведение (все сессии исполнимы; неисполнимую поймает `_executable_ir` на первой свече → HOLD), restore продолжается.
Мутация (п.2): пауза без вызова сверки → `FAILED test_sandbox_session_without_ir_is_reconciled_before_pause: assert None (position_mismatch_note)` → откат → 3 passed. Не трогал: имена параметров Bollinger (`bollinger_period` vs `bb_period`) — отдельная карточка оркестратора.
**Итоговые гейты:** pytest **2711 passed / 19 xfailed / 0 failed** (baseline 2670/22); ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 926 passed; xfail/it.fails с `S8R-AUDIT-001` — 0. Файлы круга: `app/trading/runtime.py`, `tests/test_trading/test_runtime_recovery.py`. Git: ничего не закоммичено, HEAD 47bf073, 28 файлов в diff (+1214/−836).
