## DEV-AUDIT-078 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `_drive_pool_sync`: Pool без `with`, поллинг `imap_unordered().next(timeout=0.1)` с проверкой `threading.Event`; по отмене — `pool.terminate()` + `join()`, штатно — `close()` + `join()`. Результаты — только из очереди Pool (ловушка 5).
- `run_pool`: перехват `CancelledError` → взвести событие → дождаться драйвера (`shield` + таймаут 5 с) → re-raise. К моменту `status=cancelled` воркеров уже нет.
- `GridWorkerSlots` (threading.Condition) — общий лимит воркеров на процесс backend; job берёт `min(max_workers, свободно)`, ждёт при нуле; отмена в ожидании — Pool не создаётся (проверено скриптом: 0.02 с, 0 детей, слоты не утекли).
- Singleton `default_worker_slots()` из `GRID_MAX_WORKERS_TOTAL` (config.py, `0` = авто `cpu-1` — одиночный grid как прежде). `app.config` импортируется лениво — модуль stdlib-only для spawn-ребёнка.
- `jobs.py::_run_job`: в обработчике отмены `_tasks.pop` до публикаций + внешний `finally` на любом исходе.
- Сейм для тестов: `run_pool(worker_fn=...)`, `GridSearchEngine(worker_slots=...)`; `spawn` и pickle-friendly воркер не тронуты.
- Логи: `grid_waiting_for_worker_slots`, `grid_cancel_requested`, `grid_pool_terminated`, `grid_pool_cancelled_before_start`.

### 2. Файлы
Изменены: `backend/app/backtest/grid.py`, `backend/app/backtest/jobs.py`, `backend/app/config.py`.
Новые: `backend/tests/unit/test_backtest/test_grid_cancel_terminates_pool.py`, `backend/tests/unit/test_backtest/_grid_sleep_worker.py` (stdlib-only спящий воркер).

### 3. Тесты
RED (после добавления сейма): `AssertionError: воркеры живы после cancel: pids=[5253, 5254], elapsed=0.00s`; `AssertionError: одновременно живых воркеров 4 > лимита 2`; `AssertionError: job осталась в реестре _tasks после отмены со сбоем записи статуса` (до сейма — `ImportError: cannot import name 'GridWorkerSlots'`).
GREEN: 3 passed in 2.7 s, ×3 без флейков. Мутация `pool.terminate()` → `pool.close()` в ветке отмены: `AssertionError: run_pool завершился через 3.00s после cancel (> 2.0s)`; откачена.
Гейты (итоговые, после доработок по /code-review): pytest 2806 passed / 16 xfailed / 0 failed (137 с); файл карточки 6 passed ≈ 3 с; `test_grid*`+`test_jobs`+`test_router_full` 84 passed; ruff 0; mypy Success (179); bandit 0 (код возврата самой команды); typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `default_worker_slots()` — `grid.py:700` внутри `run_pool`, вызываемого из `router.py:1527`; `cancel_event` взводится в `run_pool` при `Task.cancel()` из `jobs.py::cancel`/`shutdown`.

### 5. Контракты
API/схемы/миграции не менялись. Новая настройка `GRID_MAX_WORKERS_TOTAL: int = 0`.

### 6. Проблемы / предлагаемые правки
- `.env.example` (не редактировал): `# Общий лимит worker-процессов Grid Search на backend (0 = cpu-1)` / `GRID_MAX_WORKERS_TOTAL=0`.
- `deployment_guide.md` §3.2, строка таблицы: `GRID_MAX_WORKERS_TOTAL` | Общий предел процессов Grid Search на все параллельные job'ы (S8R-AUDIT-078); `0` — авто `cpu-1` | по умолчанию `0`, уменьшить, если live-торговля соседствует с гридами.
- ФТ §19.2: после «workers = os.cpu_count() - 1» добавить: «сумма воркеров всех параллельных Grid-job'ов ограничена `GRID_MAX_WORKERS_TOTAL` (по умолчанию `cpu-1`); второй grid ждёт освобождения слотов; отмена job гасит процессы Pool ≤ 2 с». ТЗ §5.3.4 — аналогично.
- Поведение: при занятых слотах второй grid стоит в `running/0%` без отдельного события — кандидат на `waiting`-прогресс (вне карточки).
- Новая находка: `shutdown()` не ограничен таймаутом ожидания задач (gotcha-48) — отдельная карточка.

### 7. Применённые Stack Gotchas
21 (spawn, top-level воркер, stdlib-only модуль для ребёнка), 38 (fresh-session на каждый `_update_status` — fallback не требуется), 48 (NullPool + файловая БД, отменил → дождись с таймаутом), 59 (мутация обязательна), 50 (проверочный скрипт — из `backend/`).

### 8. Новые Stack Gotchas
Кандидат: «`Task.cancel()` над `run_in_executor` не останавливает поток и `multiprocessing.Pool` — нужен флаг для драйвера + `terminate()/join()`; `with Pool` на выходе всегда `terminate()`, различать close/terminate вручную». Номер — оркестратору.

### Доработки по /code-review
1. [high] Исключение воркера → `close()+join()` ждал остальные комбинации, отмена в этом `join()` игнорировалась. Тест `TestWorkerExceptionTerminatesPool::test_worker_exception_terminates_pool_and_releases_slots` (воркер `raising_worker` бросает на combo 1 из 10 × 1 с): RED `AssertionError: после исключения воркера драйвер ждал остальные комбинации: 5.10s`. Правка: флаг `finished_normally` (только `StopIteration`) → `close()`, иначе `terminate()`; `join()` всегда; лог `grid_pool_terminated reason=worker_error`. GREEN. Мутация (вернуть `terminate` только при `cancel_event`): `... ждал остальные комбинации: 5.09s` → откачена (маркеров 0, `git diff` проверен).
2. [medium] Отмена, пока драйвер в очереди executor'а → Pool поднимался после `cancelled`. Тесты `TestCancelBeforeDriverStarts`: `test_acquire_returns_zero_when_already_cancelled` — RED `assert 2 == 0`; `test_cancel_while_driver_queued_does_not_start_pool` (executor на 1 поток, занятый блокером; cancel до старта драйвера; spy-наследник `GridWorkerSlots` считает выданные слоты) — RED `AssertionError: драйвер взял 2 слотов и поднял Pool после отмены`. Правка: `cancel_event.is_set()` в начале `acquire()` и в драйвере до `acquire()`. GREEN.
Файл карточки: 6 passed ≈ 3 с, ×3 без флейков; полный гейт — см. §3.

### 9. Плагины
py_compile после каждого Edit (LSP в worktree не резолвит `app.*`); `pnpm typecheck` (`tsc -b`); context7 не требовался (stdlib `multiprocessing`/`threading`); tdd — `mattpocock-skills:tdd` (RED → GREEN → мутация).
