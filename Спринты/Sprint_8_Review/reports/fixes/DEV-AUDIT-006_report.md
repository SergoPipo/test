## DEV-AUDIT-006 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Одиночный бэктест: компиляция стратегии и `cerebro.run` выполняются в spawn-процессе (`_backtest_child_main`). Свечи грузятся в main. Прогресс `(pct, date)` передаётся через Pipe в прежнем формате. Интерфейс `BacktestEngine.run` не менялся.
- Жёсткий дедлайн `BACKTEST_EXEC_TIMEOUT_SEC` (900 с, минимум 1 с) отсчитывается от сигнала «started» после импорта библиотек. По истечении — `Process.kill()` (SIGKILL) и `BacktestExecutionTimeoutError`. Текст «превышено время исполнения стратегии (N с)» попадает в `failed` через существующий `persist_with_retry` и fallback на свежую сессию.
- Лимит памяти: RLIMIT_AS = размер процесса после импорта + `BACKTEST_EXEC_MEMORY_LIMIT_MB` (2048). Действует только на Linux. `MemoryError` превращается в `BacktestMemoryLimitError` («превышен лимит памяти…»).
- Отмена job: процесс убит и собран (join) до выхода `CancelledError`. Для этого executor-future обёрнут в `shield`, иначе `Task.cancel()` отменял его раньше, чем процесс успевали убить.
- Grid: сохранён `imap_unordered`. Воркер сообщает о старте комбинации через очередь инициализатора, у каждой комбинации свой дедлайн. Зависшая комбинация получает ошибку, Pool гасится `terminate()` и пересоздаётся для непосчитанных. Отмена (078) и остановка при исключении воркера работают как раньше.
- `executor.py` в production не используется (роутер снят в 001) — не переписывался, предлагаю удалить (вместе с 019).

### 2. Файлы
Новые: `backend/app/backtest/exec_limits.py`, `backend/tests/unit/test_backtest/test_execution_limits.py`.
Изменённые: `backend/app/backtest/engine.py`, `backend/app/backtest/grid.py`, `backend/app/common/exceptions.py`, `backend/app/config.py`, `docs/env_vars.md`, `backend/tests/unit/test_backtest/test_engine.py` и `test_engine_full.py` (6 тестов с моком `_setup_cerebro` переведены на шов `_run_isolated`).

### 3. Тесты
- RED, grid: `E TimeoutError` (собственный предел теста 48 с). RED, engine: `FAILED …::test_backtest_infinite_loop_terminates`, строка ошибки не напечаталась. Faulthandler показал поток executor'а в `<strategy> line 5 in next`, а главный поток pytest отнимает GIL. Процесс не завершился даже за 1500 с, что само подтверждает дефект.
- GREEN: 6 passed и 1 skipped (`test_memory_limit` — только Linux). Покрыто: бесконечный цикл, отмена, эталонные метрики до правки, передача ошибки того же типа, MemoryError, зависание в grid.
- Мутации (каждая откачена, md5 сверен):
  - дедлайн → `+10**9`: `E TimeoutError`, 48.7 с;
  - в grid снят `break` по дедлайну: `E TimeoutError`;
  - снят `shield`: `AssertionError: процесс исполнения жив после отмены`.
- Гейты:
  - pytest 4392 passed / 3 xfailed / 1 skipped / 0 failed;
  - ruff 0; mypy Success (194); bandit M0/H0;
  - typecheck 0; lint 0; build ok;
  - vitest: фронт не менялся — на уровне пакета.
- Первый полный прогон завис на 39% в `test_ws_sessions.py::test_auth_via_cookie` (TestClient portal, gotcha-48, прогон шёл параллельно с другим исполнителем). Файл отдельно — 6 passed, повтор полного прогона зелёный.

### 4. Integration points
✅ `engine.py:306` → `_run_isolated` → `_run_backtest_child_sync` → `_backtest_child_main`.
✅ `grid.py:872` `resolve_exec_limits` → `_drive_pool_sync` → `_run_pool_round` → `_pool_initializer`/`_run_tracked`.
Вызывающие: `router._run_backtest_task` (single и job), grid job. `BacktestService.create_backtest` в production не вызывается.

### 5. Контракты
API и WS не менялись. Миграции нет. Появились 2 настройки (`docs/env_vars.md`).

### 6. Проблемы / правки документов / находки
- ТЗ §5.11, п. 7 → «Лимиты исполнения (S8R-AUDIT-006): `cerebro.run` бэктеста — в spawn-процессе с дедлайном `BACKTEST_EXEC_TIMEOUT_SEC` (SIGKILL), комбинация Grid — с дедлайном от старта в воркере, Pool пересоздаётся; RLIMIT_AS (`BACKTEST_EXEC_MEMORY_LIMIT_MB` сверх базы) — только Linux; на macOS лимит памяти не ставится». Эскиз 5.11.2 (psutil на macOS) не реализован.
- Гайд деплоя, таблица env (рядом с `GRID_MAX_WORKERS_TOTAL`): две строки из `docs/env_vars.md`.
- `.env.example` не трогал (решение заказчика).
- Находка: до фикса тело `class` стратегии исполнялось через `_setup_cerebro` прямо в event loop. Теперь исполняется в дочернем процессе.
- Самопроверка:
  - сбой commit → существующий fallback на свежую сессию;
  - уведомлений не добавлял;
  - тесты идут через `_run_backtest_task` и `run_pool`;
  - под таймаутом только процесс, БД не затрагивается;
  - вызывающие проверены;
  - ресурсы от клиента не затрагиваются.

### 7. Stack Gotchas
21, 38, 48, 73.

### 8. Новые Stack Gotchas
Кандидат: «`Task.cancel()` отменяет сам future из `run_in_executor`, и `shield(future)` в обработчике отмены сразу бросает CancelledError. Правило: ждать через `shield(future)` с самого начала». Файл: `engine.py::_run_isolated`.

### 9. Плагины
py_compile и mypy вместо pyright; typecheck (`tsc -b`); TDD — `mattpocock-skills:tdd`; context7 не понадобился (использован только stdlib multiprocessing/resource).
