---
sprint: 7
agent: DEV-1
role: Backend Core (BACK1) — Trading источники + Backtest Engine + Backup
wave: 1+2
depends_on: [ARCH W0]
---

# Роль

Ты — Backend-разработчик #1 (senior). Зона ответственности по RACI: Trading Engine = R, Backtest Engine = R, Market Data Service = R, Broker Adapter = R.

На W1 закрываешь долг S6 (5 event_type подключение, WS-каналы trading-sessions и backtest). На W2 реализуешь Grid Search backend и Backup/restore.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python ≥ 3.11, .venv активирован.
2. Зависимости предыдущих DEV (W2): BACK2 закрыл 7.12 (NS singleton DI) — без этого 7.13 нельзя интегрировать корректно.
3. Существующие файлы: app/trading/runtime.py, app/trading/engine.py, app/broker/tinvest/multiplexer.py, app/notification/service.py, app/backtest/, app/main.py, app/scheduler/service.py.
4. База данных: alembic upgrade head — миграции применены, baseline schema.
5. Внешние сервисы: T-Invest sandbox (для проверок connection_lost/restored), MOEX ISS.
6. Тесты baseline: cd Develop/backend && .venv/bin/python -m pytest tests/ -q → 0 failures.
   Зафиксируй фактическое число тестов в отчёте (правило S5R.5).
```

> Если хоть одно условие не выполнено — вернуть `БЛОКЕР: <описание>`.

# Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| pyright-lsp | **да** (mandatory после каждого Edit/Write на .py) | `cd Develop/backend && .venv/bin/python -m py_compile app/<file>.py` |
| context7 | **да** — FastAPI WebSocket, multiprocessing, APScheduler, SQLAlchemy | WebSearch |
| superpowers TDD | **да, для 7.13 и 7.2** (Red-Green-Refactor — критические пути trading + backtest) | — |
| code-review | **да** после блока изменений в `app/trading/` или `app/backtest/` | — |
| typescript-lsp | нет (BACK1 не пишет frontend) | — |
| playwright | нет | — |
| frontend-design | нет | — |

**Правило:** после КАЖДОГО Edit/Write на `.py` файл → вызови pyright-lsp diagnostic. Hook `plugin-check.sh` напомнит, но обязан следовать и без hook.

# Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.
2. **`Develop/stack_gotchas/INDEX.md`** — пройти все ловушки слоёв `trading/`, `backtest/`, `broker/`, `scheduler/`.
3. **`Спринты/Sprint_7/execution_order.md`** раздел «Cross-DEV contracts» — особое внимание:
   - **Поставщик:** C1 (для FRONT1), C2 (для FRONT1), C5 (для FRONT2)
   - **Потребитель:** C7 (от BACK2 — `request.app.state.notification_service`)
4. **`Спринты/Sprint_7/arch_design_s7.md`** — секции 2 (Grid Search), 3 (5 event_type — file:line publish-сайтов), 4 (WS sessions), 5 (фоновый бэктест) с дословными цитатами ТЗ.
5. **`Спринты/project_state.md:79–90`** — MR.5 «5 event_type подключение к runtime» (дословно):

   > Цитата из project_state.md:79–90 — берётся как есть, без перефразирования.

6. **`Sprint_6_Review/code_review.md`** записи про EVENT_MAP фикс — образец того, как заполнять шаблоны (`{strategy_name}/{ticker}/{direction}/{volume}/{pnl}`).
7. **`Sprint_5_Review/changelog.md`** — Live Runtime Loop (S5R.2): не оставлять `NOT CONNECTED` сущности.
8. **Цитаты ТЗ/ФТ** для своих задач — копировать из `arch_design_s7.md` (ARCH сделал извлечение в W0).

# Рабочая директория

`Develop/backend/`

# Контекст существующего кода

- `app/trading/runtime.py` — `SessionRuntime` управляет live торговлей; `_handle_candle` и `_SessionListener` (тут добавляли `strategy_name` в S6 Review).
- `app/trading/engine.py` — `OrderManager`, `PositionTracker`, publish событий через EventBus. На строке 681 уже есть event `all_positions_closed`, но без `create_notification`.
- `app/broker/tinvest/multiplexer.py` — gRPC stream multiplexer; reconnect loop — место для `connection_lost/restored`.
- `app/notification/service.py` — `NotificationService` + `EVENT_MAP` (поставляет BACK2 в 7.12 как singleton через DI).
- `app/main.py:68` — singleton NotificationService (BACK2 расширит DI в 7.12).
- `app/backtest/` — `BacktestEngine`, `BacktestRunner`, REST endpoint `POST /api/v1/backtest`.
- `app/scheduler/service.py` — APScheduler регистрация jobs (для 7.9 backup_job).
- `app/cli/` — каталог CLI-точек (для 7.9 restore CLI).

# Задачи

## Задача 7.13: 5 event_type → runtime (W1, debt, TDD обязателен)

**Цель:** Подключить 5 типов уведомлений к runtime-источникам через `create_notification`. Механизм доставки уже работает (тест `test_dispatch_all_events.py`, 14 passed).

**5 publish-сайтов** (точные file:line — из `arch_design_s7.md` секция 3):

| event_type | Файл | Что подставлять в EVENT_MAP |
|------------|------|------------------------------|
| `trade_opened` | `app/trading/engine.py` или `runtime.py` (по итогу ARCH design) | `{strategy_name, ticker, direction, volume, price}` |
| `partial_fill` | `app/trading/engine.py` (OrderManager) | `{strategy_name, ticker, filled_qty, total_qty, avg_price}` |
| `order_error` | `app/trading/engine.py` (OrderManager) | `{strategy_name, ticker, reason, error_code}` |
| `all_positions_closed` | `app/trading/engine.py:681` (event есть, нет `create_notification`) | `{strategy_name, total_pnl}` |
| `connection_lost` / `connection_restored` | `app/broker/tinvest/multiplexer.py` (reconnect loop) | `{broker_name, reason}` |

**Подход TDD:**
1. Для каждого event_type — failing test в `tests/test_notification/test_runtime_events.py`:
   - Запустить mock-trading session.
   - Триггернуть событие.
   - Assert: `notification_service.create_notification` вызван с правильным `event_type` и контекстом.
2. Запустить тесты — Red.
3. Реализовать publish с `create_notification` в указанных file:line.
4. Запустить тесты — Green.
5. Refactor (общий helper для publish, если повторяется код).
6. Commit.

**Критично:** Шаблоны EVENT_MAP заполняются по аналогии с фиксом S6 Review (8 publish-сайтов в runtime.py + engine.py — там добавляли `strategy_name`).

## Задача 7.15-be: WS endpoint /ws/trading-sessions/{user_id} (W1)

**Контракт C1 (поставщик для FRONT1):**

```python
# app/trading/ws.py (новый файл)

@app.websocket("/ws/trading-sessions/{user_id}")
async def trading_sessions_ws(websocket: WebSocket, user_id: int, token: str):
    # 1. Валидация JWT в query param token (по итогу ARCH design — JWT в query или cookie)
    # 2. Accept connection
    # 3. Подписка на event_bus каналы trades:{session_id} для всех активных сессий user'а
    # 4. Forward events в WebSocket в формате:
    #    {"event": "position_update"|"trade_filled"|"pnl_update"|"session_state",
    #     "session_id": int, "payload": {...}}
    # 5. Reconnect — клиентская задача FRONT1, backend просто принимает повторные подключения
```

**Регистрация:** `app.include_router(trading_ws_router)` в `app/main.py`.

**Integration verification:** `grep -rn "@app.websocket" app/` показывает `/ws/trading-sessions/`.

## Задача 7.17-be: WS endpoint /ws/backtest/{job_id} + параллельные jobs (W1)

**Контракт C2 (поставщик для FRONT1):**

```python
# app/backtest/ws.py (новый файл) или расширение существующего

@app.websocket("/ws/backtest/{job_id}")
async def backtest_ws(websocket: WebSocket, job_id: str, token: str):
    # 1. JWT валидация
    # 2. Регистрация подписчика на job_id
    # 3. Forward events:
    #    {"progress": 0..100, "status": "queued"|"running"|"done"|"error", "result": {...}?}
    # 4. После status="done" + N сек — закрытие WS
```

**Параллельные jobs:**
- Каждый POST /api/v1/backtest возвращает `job_id`.
- Запускается через FastAPI BackgroundTasks или кастомный executor (по итогу ARCH design).
- WS каналы независимы — N jobs = N подключений.

## Задача 7.2-be: Grid Search backend (W2, TDD обязателен)

**Контракт C5 (поставщик для FRONT2):**

```python
# app/backtest/grid_search.py (новый файл)

@router.post("/api/v1/backtest/grid", response_model=GridJobResponse)
async def start_grid_search(request: GridSearchRequest, current_user: User = Depends(get_current_user)):
    # request: {"strategy_id": int, "ranges": {"param_name": [v1, v2, ...]}}
    # Hard cap N комбинаций (по итогу ARCH design, рекомендуется 1000)
    # Запуск параллельных backtests через multiprocessing.Pool / asyncio + Semaphore
    # Возврат: {"job_id": str}
    # Прогресс — через WS C2 (общий /ws/backtest/) с матрицей в result
```

**Result format:** `{"matrix": [{"params": {...}, "sharpe": float, "pnl": float, "win_rate": float, "drawdown": float}]}` (по итогу ARCH design).

**TDD:** failing test «hard cap превышен → 400 error», failing test «10 параметров → 10 строк matrix».

## Задача 7.9: Backup/restore (W2, с OPS)

**Состав:**

1. **Автоматический бэкап:**
   - APScheduler job `backup_job` в `app/scheduler/service.py` (cron: ежедневно 03:00 МСК).
   - Имя файла: `backup_YYYY-MM-DD_HHMMSS.sqlite` (или dump для PostgreSQL).
   - Папка: `Develop/backend/backups/`.

2. **Ротация:**
   - Keep 7 копий, остальное удалять.

3. **CLI восстановление:**
   - `python -m app.cli.restore --from <path>` — копирует backup в текущий БД.
   - В `app/cli/restore.py` — entry point.

4. **Smoke-тест integration:**
   - Создать запись в test БД → backup → удалить запись → restore → запись на месте.

OPS делает основные изменения, BACK1 помогает с DB layer и интеграцией с scheduler.

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Если ввёл `@pytest.mark.skip(reason="<причина>")` — обязательно:
1. В отчёте полный список с обоснованием.
2. Карточка в `Sprint_8_Review/backlog.md` (или `Sprint_7_Review/backlog.md`) с тикетом `S7R-<NAME>`.

Skip без карточки — **блокер**.

# Тесты

```
tests/
├── test_notification/
│   └── test_runtime_events.py        # 7.13: 5 event_type триггерятся в runtime
├── test_trading/
│   └── test_ws_sessions.py           # 7.15-be: WS auth, payload, реконнект
├── test_backtest/
│   ├── test_ws_backtest.py           # 7.17-be: WS прогресс, параллельные jobs
│   └── test_grid_search.py           # 7.2-be: hard cap, matrix, multiprocessing
├── test_backup/
│   └── test_backup_restore.py        # 7.9: smoke create→delete→restore
```

**Фикстуры:** `db_session`, `test_user`, `test_strategy`, `mock_broker`, `mock_event_bus`.

# Integration Verification Checklist

Для **каждой** новой сущности:

- [ ] **7.13:** `grep -rn "create_notification" app/trading/ app/broker/` показывает 5 новых вхождений.
- [ ] **7.13:** Каждый из 5 event_type — runtime тест проходит (`test_runtime_events.py`).
- [ ] **7.15-be:** `grep -rn "@app.websocket.*trading-sessions" app/` показывает регистрацию.
- [ ] **7.15-be:** `app.include_router(...)` в `main.py` — endpoint registered.
- [ ] **7.17-be:** `grep -rn "@app.websocket.*backtest" app/` показывает регистрацию.
- [ ] **7.17-be:** Параллельные jobs — N jobs создают N WS-каналов.
- [ ] **7.2-be:** `grep -rn '"/api/v1/backtest/grid"' app/` показывает endpoint.
- [ ] **7.2-be:** `Depends(get_current_user)` присутствует.
- [ ] **7.2-be:** CSRF protection (для POST endpoint).
- [ ] **7.9:** `grep -rn "BackupService\|backup_job" app/` показывает регистрацию в scheduler.
- [ ] **7.9:** CLI: `grep -rn "restore" app/cli/` показывает entry point.
- [ ] **7.9:** Smoke-тест прогнан вручную, лог в отчёте.
- [ ] **C7 (потребитель):** Везде, где раньше был `NotificationService()`, теперь `request.app.state.notification_service` (или Depends).
- [ ] **Если точка вызова не найдена** — `⚠️ NOT CONNECTED` в отчёте + следующая задача.

# Формат отчёта (МАНДАТНЫЙ)

**2 файла**, каждый — 8 секций до 400 слов по шаблону.

1. **`reports/DEV-1_BACK1_W1.md`** — после задач 7.13, 7.15-be, 7.17-be.
2. **`reports/DEV-1_BACK1_W2.md`** — после задач 7.2-be, 7.9.

Шаблон секций:
1. Что реализовано (5–10 пунктов).
2. Файлы (новые / изменённые / удалённые).
3. Тесты (X/Y passed; failed → диагноз).
4. Integration points (`<ClassName>.<method>` вызывается из `<file:line>` ✅ или ⚠️ NOT CONNECTED).
5. Контракты (поставляю — потребитель кто; использую — от кого, контракт соблюдён).
6. Проблемы / TODO.
7. Применённые Stack Gotchas.
8. Новые Stack Gotchas (если найдены).
9. Использование плагинов.

# Alembic-миграция

Не требуется (BACK1 не вводит новых таблиц).

# Чеклист перед сдачей

- [ ] Все задачи (7.13, 7.15-be, 7.17-be для W1; 7.2-be, 7.9 для W2) реализованы.
- [ ] Тесты зелёные: `pytest tests/ -q` → 0 failures (число тестов сохранено в отчёте).
- [ ] Линтер: `ruff check app/` → no issues.
- [ ] Type-check: `pyright app/` → 0 errors.
- [ ] Integration verification checklist полностью пройден.
- [ ] Формат отчёта соблюдён (8 секций).
- [ ] Отчёт сохранён как файл (`reports/DEV-1_BACK1_W1.md`, `reports/DEV-1_BACK1_W2.md`).
- [ ] Cross-DEV contracts: C1, C2, C5 как поставщик подтверждены; C7 как потребитель подтверждён.
- [ ] Stack Gotchas применены (минимум 3 ловушки в отчёте).
- [ ] Плагины использованы (pyright, context7, TDD, code-review для trading-блока).
- [ ] Skip-тикеты с карточками.
- [ ] Миграции применены (если есть).
- [ ] `Sprint_7/changelog.md` обновлён немедленно после каждого блока изменений.
- [ ] `Sprint_7/sprint_state.md` отражает прогресс.
