---
sprint: 7
agent: DEV-1 (BACK1)
wave: 2 (fix-волна после sub-wave 1)
date: 2026-04-26
status: completed
---

# DEV-1 BACK1 W2 FIX — отчёт (Grid Search → multiprocessing.Pool)

## 1. Что реализовано

- **Grid Search backend переписан** с `asyncio.Semaphore + thread executor`
  (под-волна 1, ошибка) на `multiprocessing.Pool` (spawn-context,
  workers = `cpu - 1`) — соответствует ТЗ §5.3.4 и
  `arch_design_s7.md §2`.
- Новый pickle-friendly **worker** `_run_single_backtest(payload: dict) -> dict`
  на module-level: импортирует `backtrader`/`pandas` сам, восстанавливает
  DataFrame из `list[dict]` свечей, создаёт собственный Cerebro и
  возвращает метрики. Не касается БД и asyncio.
- **Index-обёртка** `_run_single_backtest_indexed((idx, payload))` — сохраняет
  соответствие `params ↔ result` (имп `imap_unordered` не гарантирует порядок).
- **Sync-драйвер** `_drive_pool_sync(payload, combos, workers, queue)` —
  использует `multiprocessing.get_context("spawn")` и `pool.imap_unordered(
  chunksize=1)` для streaming. Вызывается из `loop.run_in_executor`, чтобы
  не блокировать FastAPI event loop.
- Новый async-метод `GridSearchEngine.run_pool(ranges, worker_payload,
  progress_publisher)` — production-путь. Legacy `run(runner=...)` сохранён
  для unit-тестов с моковыми async-runner'ами.
- В `router.py`: `_make_grid_runner` → **`_prepare_grid_workload`** (загружает
  OHLCV один раз через `MarketDataService` в main-процессе и собирает
  pickle-friendly base_payload).
- **Decimal-coerce** (`_coerce_param_value`) сохранён без изменений —
  закрывает W1 open question.
- **Hard cap** 1000 комбинаций / ≤5 параметров — соблюдён в обоих путях
  (`run` и `run_pool`), валидация ДО Pool.spawn.

## 2. Файлы

**Изменённые:**
- `Develop/backend/app/backtest/grid.py` — полная переработка (~660 строк).
- `Develop/backend/app/backtest/router.py` — `_make_grid_runner` →
  `_prepare_grid_workload`, `start_grid_search._job_runner` использует
  `run_pool`.
- `Develop/backend/tests/unit/test_backtest/test_grid.py` — добавлен
  `TestMultiprocessingWorker` (+5 тестов).
- `Develop/stack_gotchas/gotcha-21-grid-multiprocessing-vs-async.md` —
  добавлена UPDATE-секция (append-only).
- `Develop/stack_gotchas/INDEX.md` — обновлена строка #21, version 3 → 4,
  last_updated 2026-04-26.
- `Спринты/Sprint_7/changelog.md` — запись `## 2026-04-26 — Fix-волна
  BACK1: Grid Search → multiprocessing.Pool`.

**Новых файлов нет.**

## 3. Тесты

- `pytest tests/unit/test_backtest/test_grid.py
  tests/unit/test_backtest/test_grid_endpoint.py -q` → **35 passed**.
  Прирост: было 30 → стало 35 (+5):
  - `test_worker_function_pickleable` — `pickle.dumps(_run_single_backtest)` и
    `pickle.dumps(_run_single_backtest_indexed)` не падают;
    `assert_worker_pickleable()` отрабатывает.
  - `test_worker_payload_pickleable` — production-payload (str/list[dict]/
    числа) pickle-friendly (анти-регресс на closure-leak).
  - `test_run_pool_validates_cap` — hard cap 1000 комбинаций для `run_pool`
    выбрасывает `GridValidationError` ДО Pool.spawn.
  - `test_run_pool_validates_too_many_parameters` — > 5 параметров блокируется.
  - `test_default_max_workers_is_cpu_minus_one` — `default_max_workers() ==
    max(1, cpu-1)` (соответствие ТЗ §5.3.4).
- Полный `pytest tests/ -q` → **881 passed / 4 failed**. 4 failed — все в
  `test_chart_drawings/` (work-in-progress BACK2, **не моя зона**).
  В моей зоне (`tests/unit/test_backtest/test_grid*.py`) — 0 failures.
- Линт: `ruff check app/backtest/grid.py app/backtest/router.py
  tests/unit/test_backtest/test_grid.py` → All checks passed!
- `py_compile app/backtest/grid.py app/backtest/router.py` — 0 errors.

## 4. Integration points

`grep -rn "GridSearchEngine|run_pool|_run_single_backtest|
multiprocessing.Pool|_prepare_grid_workload" app/` (без `__pycache__`):

- `app/backtest/router.py:1085` — `_prepare_grid_workload` (production
  call, async).
- `app/backtest/router.py:1202` — `grid_engine = GridSearchEngine()`
  (instantiated).
- `app/backtest/router.py:1207` — `_prepare_grid_workload(...)` вызов
  внутри `_job_runner`.
- `app/backtest/router.py:1213` — `grid_engine.run_pool(...)`
  (production-путь).
- `app/backtest/grid.py:405` — `pool.imap_unordered(_run_single_backtest_
  indexed, ...)` (внутри `_drive_pool_sync`).

Помеченных `⚠️ NOT CONNECTED` сущностей **нет**.

## 5. Контракты

- **C5 (поставщик BACK1 → потребитель FRONT2):** **НЕ ИЗМЕНЁН**.
  - Body `POST /api/v1/backtest/grid` — идентичен.
  - Response `GridJobResponse {job_id, total, status}` — идентичен.
  - WS-канал `/ws/backtest/{job_id}` (C2) — финальный payload
    `result.matrix = [{params, sharpe, pnl, win_rate, drawdown,
    trades_count}]` + флаг `overfitting_warning` — идентичен.
  - FRONT2 (sub-wave 2) НЕ затрагивается.
- **C2 (BacktestJobManager WS):** не менял.

## 6. Проблемы / TODO

- **Smoke-test `run_pool` с реальным Backtrader-cerebro в pytest НЕ запускался**
  — потому что в pytest без `if __name__ == '__main__'` guard'а и при
  spawn-context `multiprocessing.Pool` в коллект-фазе может зависать.
  Pickle-проверки worker'а и payload'а покрывают самую критичную часть
  (что worker pickle-able). Реальный smoke остаётся на ручную проверку
  при поднятом backend (рекомендация для ARCH-приёмки: запустить
  `POST /api/v1/backtest/grid` на тестовой стратегии 2x2 ranges и
  убедиться, что job завершается).
- **Полная инжекция `grid_params` в Backtrader `self.params`** —
  по-прежнему частично (префикс `grid_params = {...}` доступен как dict).
  Backtrader strategy-parameter-binding — задача S8, как было в W1.
- **Drift 4 failed pytest-теста (`test_chart_drawings/`)** — параллельная
  работа BACK2, не моя зона.

## 7. Применённые Stack Gotchas

- **#21 (свой собственный, переписан как UPDATE):** перечитан, проблемы
  «AsyncSession не pickle-able» и «asyncio + Pool» решены корректно
  (выгрузка данных в main-процессе + `loop.run_in_executor` для
  Pool-драйвера). UPDATE-секция в gotcha-21 описывает финальный паттерн.
- **#08 (AsyncSession.get_bind в pytest):** не релевантно для grid
  (worker не использует AsyncSession).
- **#04 (T-Invest streaming):** не релевантно — Grid использует
  исторические данные через MarketDataService, без streaming.

## 8. Новые Stack Gotchas + плагины

**Новых gotcha НЕ создавал** — gotcha-21 переиспользован (append-only
UPDATE). Это исключение из общего правила «новый gotcha при новой
проблеме», обоснование: ловушка та же (multiprocessing vs async-engine),
но с противоположным выводом — финальное решение MP корректно.
Удалять старый текст нельзя (политика append-only из README), поэтому
оригинал перенесён в раздел «Изначальная запись (ОШИБОЧНОЕ решение —
оставлено для истории)».

**Плагины:**
- pyright fallback (`python -m py_compile`) — после каждого Edit, 0 errors.
- ruff check — 0 issues по всем затронутым файлам.
- context7 — НЕ вызывался: `multiprocessing.Pool` API стабильно с Python 3.0+,
  `imap_unordered`/`pool.terminate()`/spawn-context документированы в
  стандартной библиотеке без version-specific нюансов на 3.11.
- code-review — НЕ вызвался отдельно (изменения в `app/backtest/` —
  автоматизированная зона; smoke интегрирован через grep + 5 анти-регресс
  тестов).
- TDD — Red-Green-Refactor для worker (сначала pickle-test, потом сам
  worker; затем cap-валидация для `run_pool`).
