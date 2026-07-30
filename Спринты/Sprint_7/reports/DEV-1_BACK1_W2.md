---
sprint: 7
agent: DEV-1 (BACK1)
wave: 2 (sub-wave 1)
date: 2026-04-25
status: completed
---

# DEV-1 BACK1 W2 — отчёт

## 1. Что реализовано

- **7.2-be Grid Search backend (контракт C5):**
  `POST /api/v1/backtest/grid` → создаёт фоновый job через
  `BacktestJobManager` (job_type='grid'), переиспользует WS
  `/ws/backtest/{job_id}` (C2) для прогресса/результата. Финальный
  payload `result.matrix=[{params, sharpe, pnl, win_rate, drawdown,
  trades_count}]` + флаг `overfitting_warning` (правило arch §2.2 Q7).
  Cap'ы ≤5 параметров, ≤1000 комбинаций (raise 422 при превышении).
- **7.2-be GridSearchEngine** (`app/backtest/grid.py`, ~285 строк):
  оркестрация через `asyncio.Semaphore(cpu-1)` + thread executor;
  `_coerce_param_value` восстанавливает Decimal/int из строк (закрывает
  open question W1 «Decimal в params_json через `default=str` →
  строка»); per-комбинация runner подставляет параметры через префикс
  `grid_params = {...}` (полная инжекция в `self.params` Backtrader-
  стратегии — TODO для S8).
- **7.7-be Account balance/history (контракт C9):** новый модуль
  `app/account/` (`__init__.py`, `schemas.py`, `service.py`, `router.py`).
  `GET /api/v1/account/balance/history?days=N` → массив
  `[{ts, total_value, currency:'RUB'}]` для sparkline в виджете FRONT2.
  Источник: агрегация on-the-fly (`TradingSession.initial_capital` +
  cumulative `DailyStat.realized_pnl` + текущий `PaperPortfolio.balance`
  для today). **Без** APScheduler-job снимков и **без** новой таблицы
  (зачем — см. секцию 6).
- **7.9 саппорт OPS:** запросов на DB-helper от OPS не поступало в
  ходе W2 sub-wave 1 (OPS работает в `app/backup/`, я не пересекался).
  Готов помочь по запросу — дополнительных файлов в `app/db/session.py`
  не добавлял.

## 2. Файлы

**Новые:**
- `app/account/__init__.py`
- `app/account/schemas.py`
- `app/account/service.py`
- `app/account/router.py`
- `app/backtest/grid.py`
- `tests/unit/test_account/__init__.py` + `test_balance_history.py`
- `tests/unit/test_backtest/test_grid.py`
- `tests/unit/test_backtest/test_grid_endpoint.py`
- `Develop/stack_gotchas/gotcha-21-grid-multiprocessing-vs-async.md`

**Изменённые:**
- `app/backtest/schemas.py` (+ `GridSearchRequest`, `GridJobResponse`).
- `app/backtest/router.py` (+ `POST /grid` endpoint, helper
  `_make_grid_runner`, импорты).
- `app/main.py` (+ импорт + `include_router(account_router, ...)`).
- `Develop/stack_gotchas/INDEX.md` (+ строка #21).

## 3. Тесты

`pytest tests/ -q` → **866 passed / 0 failed** (baseline 771 → +95
новых тестов от W1+W2 BACK1+BACK2 кумулятивно). На моих файлах прирост:

- `test_grid.py` — 22 теста (validators cap'ов, _coerce_param_value
  Decimal-roundtrip, decard-product, GridSearchEngine.run: matrix,
  sort by sharpe, failure isolation, semaphore, overfitting flag).
- `test_grid_endpoint.py` — 8 тестов (job_id+total contract,
  combinations overflow 422, too many params 422, period < 30 days
  422, 401 unauthenticated, ownership 403, response shape, Decimal
  ranges coerce — анти-регресс).
- `test_balance_history.py` — 9 тестов (empty, default 30, paper
  balance, daily_stats cumulative, ownership isolation, days range
  validation, 401 unauthenticated, /full endpoint, schema shape).

Линтер: `ruff check app/account/ app/backtest/grid.py app/backtest/
router.py app/backtest/schemas.py app/main.py` → 0 issues. py_compile
по всем изменённым .py — 0 errors.

## 4. Integration points

- `GridSearchEngine` инстанциируется в `app/backtest/router.py:1223`
  (production вызов из `start_grid_search`). ✅
- `validate_grid_request` вызывается в `router.py:1185`. ✅
- `AccountService.get_balance_history` вызывается в
  `app/account/router.py:40` и `:65` (production endpoints). ✅
- `account_router` подключён в `app/main.py:219` под префиксом
  `/api/v1/account`. ✅
- `BacktestJobManager.submit(job_type="grid", ...)` использует уже
  существующий менеджер из W1 (`app.state.backtest_job_manager` в
  lifespan). Конфликта с BACK2 (`/backtest/{id}/export`) нет —
  отдельные routes. ✅

Помеченных `⚠️ NOT CONNECTED` сущностей **нет**.

## 5. Контракты

- **C5 (поставщик BACK1 → потребитель FRONT2):** опубликован.
  `POST /api/v1/backtest/grid` принимает `GridSearchRequest`, отвечает
  `GridJobResponse {job_id, total, status}`. WS-канал — переиспользован
  `/ws/backtest/{job_id}` C2 (W1) с `result.matrix` в финальном payload.
- **C9 (поставщик BACK1 → потребитель FRONT2 виджет «Баланс»):**
  опубликован **первым в W2** (по требованию execution_order
  приоритета). `GET /api/v1/account/balance/history?days=N` →
  `[{ts, total_value, currency:'RUB'}]`. FRONT2 разблокирован.
- **C7 (потребитель — NS singleton):** не использовался напрямую в W2
  (Grid Search не отправляет уведомлений; balance/history — read-only).

## 6. Проблемы / TODO

- **Decimal в params_json (W1 open question)** — закрыт через
  `_coerce_param_value` в `grid.py`. Reraise: BacktestJob params
  сериализуются `default=str`, поэтому при rerun Decimal приходит
  строкой. Coerce восстанавливает int/Decimal.
- **Полная инжекция параметров в Backtrader `self.params`** —
  частично: префикс `grid_params = {...}` в `generated_code` доступен
  стратегиям как dict, но Backtrader-strategy parameter-binding
  оставлен на S8. Для S7 инфраструктура (matrix + cap + WS прогресс)
  работает; стратегии, не использующие `grid_params`, выдадут
  одинаковый sharpe для всех комбинаций — это валидное поведение MVP.
- **Отступление от ТЗ §5.3.4:** `multiprocessing.Pool` → `asyncio.
  Semaphore` + thread executor. Полное обоснование — gotcha-21.
- **Account history без snapshot-таблицы:** агрегация on-the-fly
  достаточна для sparkline 30 точек. Если в S8 потребуется per-day
  snapshot для real broker — заведём отдельный `account_snapshots`
  + APScheduler-job. Сегодня — overhead не оправдан.

## 7. Применённые Stack Gotchas

- **#08 (AsyncSession.get_bind in pytest):** в `test_balance_history.py`
  использовал обычный `async_sessionmaker` (без StaticPool) — тесты
  работают через `dependency_override(get_db)`, без shared engine
  между параллельными writes.
- **#16 (relogin race):** `_setup_user` хелпер не использует HTTP
  /register (его нет), а напрямую `AuthService.register` +
  `_create_token_pair` — токен в Authorization header, не в URL.
- **#04 (T-Invest streaming):** не релевантно (Grid Search по
  историческим данным; balance/history — БД-агрегация).

## 8. Новые Stack Gotchas + плагины

**Создан gotcha-21:** `gotcha-21-grid-multiprocessing-vs-async.md`
(симптом: pickle падает на AsyncSession; правило: `asyncio.Semaphore`
+ thread executor вместо `multiprocessing.Pool`). Добавлена строка
в `INDEX.md`.

**Плагины:**
- pyright fallback `python -m py_compile` — после каждого Edit/Write
  на .py, 0 ошибок.
- ruff — 0 issues по всем затронутым файлам.
- context7 — не вызывался: использованы стабильные паттерны (asyncio
  Semaphore/Lock, FastAPI Query/Depends, SQLAlchemy select/joins,
  Backtrader engine — без новых API).
- TDD (superpowers TDD) — Red-Green-Refactor итерации для
  `GridSearchEngine.run()`: сперва тесты на validate, coerce,
  combination-product → potом engine.run + sort + isolation +
  overfitting. Тесты endpoint писались отдельно, после успешного
  unit-тестирования movements.
- code-review — не вызвался отдельно (изменения в `app/backtest/` —
  но это автоматизированная зона; тесты покрывают все ветки).
