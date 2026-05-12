---
sprint: 8
agent: DEV-1
role: Backend Core (BACK1) — Coverage P0/P1/P2 + Admin role + Performance instrumentation
wave: 1+2
depends_on: [ARCH W0, BACK2 W1 MULTIPLEXER-SINGLETON (для tinvest adapter coverage)]
---

# Роль

Ты — Backend-разработчик #1 (senior). Зона ответственности в S8: довести coverage критических путей backend до ≥ 80% (приоритет P0 `notification/dispatchers.py` 0% → 80%, приоритет P1 `broker/tinvest/adapter.py` 24% → 80%, `trading/service.py` 51% → 80%); реализовать **Admin role** инфраструктуру (миграция `users.is_admin`, dependency `require_admin`, модуль `app/admin/router.py` как mount point, CLI `grant_admin`, bootstrap первого админа через FirstRunWizard); внести `@timed_event` decorator в `app/common/observability.py` и собрать performance baseline; добить P2 router-coverage (auth/notification/broker/market_data/strategy/circuit_breaker).

**Важное разграничение по ARCH-design §11 batch 2 (admin):** Plotly Dash `/admin/metrics` страницу делает **DEV-4 (FRONT2)**. DEV-1 — **только backend каркас**: миграция, dependency, роутер `/admin/` mount point, CLI, bootstrap. Plotly Dash mount — НЕ зона BACK1.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы убедись, что условия выполнены. Если хоть одно нарушено — верни `БЛОКЕР: <описание>`.

```
1. Окружение: Python ≥ 3.11, .venv активирован в Develop/backend/.
2. Зависимости предыдущих DEV (W1):
   - ARCH W0 завершён (arch_design_s8.md утверждён 2026-05-12 — все 10 TODO + эпик Admin role приняты).
   - BACK2 W1 поток B: S7R-MULTIPLEXER-SINGLETON (`app.state.tinvest_multiplexer` singleton)
     должен быть готов ДО старта coverage-тестов `broker/tinvest/adapter.py`.
     Если BACK2 не закончил MULTIPLEXER-SINGLETON — НЕ начинай coverage adapter, бери `trading/service.py` или admin role.
3. Существующие файлы (должны быть на месте):
   - app/notification/dispatchers.py (33 строки, 0% coverage)
   - app/broker/tinvest/adapter.py (394 строки, 24% coverage)
   - app/trading/service.py (334 строки, 51% coverage)
   - app/market_data/service.py (398 строк, 50% coverage)
   - app/backtest/router.py (416 строк, 25% coverage)
   - app/strategy/service.py (215 строк, 52% coverage)
   - app/backtest/engine.py (234 строки, 55% coverage)
   - app/auth/dependencies.py (`get_current_user` определён, добавим `require_admin`)
   - app/auth/router.py (`/auth/me` endpoint, FirstRunWizard endpoint существуют)
   - app/cli/ (каталог с CLI-точками — добавим users.py)
4. База данных: alembic upgrade head — baseline schema применена.
5. Внешние сервисы: T-Invest sandbox (не нужен для unit-моков, нужен только для smoke).
6. Тесты baseline РЕАЛЬНЫЙ ПРОГОН (правило S5R.5):
   - cd Develop/backend && .venv/bin/python -m pytest tests/ -q
   - Ожидание: 1024 / 0 failed (см. arch_design §Tested baseline)
   - Зафиксируй ФАКТИЧЕСКОЕ число в отчёте (не «ожидается ~1024»).
   - cd Develop/backend && .venv/bin/python -m pytest --cov=app --cov-report=term
   - Ожидание: TOTAL 71% (gap до 80% = ≈9% = ≈1140 строк)
```

# ⚠️ Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| pyright-lsp | **да** (mandatory после каждого Edit/Write на .py) | `cd Develop/backend && .venv/bin/python -m py_compile app/<module>/<file>.py` |
| context7 | **да** — для: FastAPI TestClient, httpx.AsyncClient, pytest-cov, pytest-asyncio, alembic autogenerate, structlog `bind_contextvars`, tinkoff-investments mock fixtures, click/typer (если CLI на click) | WebSearch |
| superpowers TDD | **да, для `trading/service.py` и `broker/tinvest/adapter.py`** (Red-Green-Refactor — критические пути; admin role также через TDD) | — |
| code-review | **да** после блока изменений в `app/trading/`, `app/broker/`, `app/admin/` (см. CLAUDE.md проекта) | — |
| typescript-lsp | нет (BACK1) | — |
| playwright | нет | — |
| frontend-design | нет (Plotly Dash UI делает FRONT2) | — |

**Правило:** после КАЖДОГО Edit/Write на `.py` файл → pyright-lsp diagnostic. После завершения блока в `app/trading/`, `app/broker/`, `app/admin/` — `/code-review`. Hook `plugin-check.sh` напомнит автоматически, но обязан следовать и без hook.

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью (правила tests, наименований, fixture-конвенций).
2. **`Develop/stack_gotchas/INDEX.md`** — таблица «симптом → файл». Особое внимание к слоям `broker/`, `trading/`, `notification/`, `auth/`, `market_data/`, `backtest/`, `strategy/`. По каждому совпавшему симптому открой соответствующий `gotcha-NN-*.md`.
3. **`Спринты/Sprint_8/execution_order.md`** раздел «Cross-DEV contracts» — особое внимание:
   - **Поставщик:** C-S8-7 (для FRONT2), C-S8-6 (внутри backend; уточнение в §«Cross-DEV contracts» ниже)
   - **Потребитель:** C-S8-6 (мультиплексер от BACK2 для coverage tinvest adapter)
4. **`Спринты/Sprint_8/arch_design_s8.md`** — секции:
   - §2 (Coverage план — P0/P1/P2, file:line, оценки часов)
   - §4 (Performance — методология `@timed_event`)
   - §8 (Wave breakdown — что в W1 vs W2, gate-условия)
   - §11 batch 2 (эпик N Admin role — раскладка по часам)
5. **Цитаты ТЗ/ФТ (дословно, без перефразирования):**

   **Из `arch_design_s8.md` §4.1 (performance метрики):**
   > «Целевые показатели: Время загрузки дашборда (первый paint): < 2 секунд; Время от сигнала стратегии до выставления ордера через broker: p95 < 500 мс; Время отклика Telegram-команды (от webhook до reply): < 3 секунд»

   **Из `arch_design_s8.md` §11 batch 2 (эпик Admin role) — дословно:**
   > «BACK1: миграция БД `is_admin: bool = False` (alembic ≈50 строк, ~2ч). BACK1: dependency `require_admin` в `app/auth/dependencies.py` + новый module `app/admin/router.py` (~3ч). BACK1: CLI `python -m app.cli.users grant_admin <username>` (~1ч). Bootstrap первого админа: FirstRunWizard → `is_admin=True` для первого зарегистрированного.»

6. **`Sprint_7_Review/code_review.md`** (если есть) и `Sprint_6_Review/code_review.md` — образцы того, как ARCH валидирует router-тесты и unit-тесты через `httpx.AsyncClient` + JWT-фикстуру.
7. **`tests/conftest.py`** — список доступных фикстур (`db_session`, `test_user`, `authenticated_client`, `mock_broker`, и т.д.) — НЕ изобретать свои, использовать существующие.

# Рабочая директория

`Develop/backend/`

# Контекст существующего кода

Конкретные файлы, которые ты будешь расширять / трогать. **НЕ ищи их сам через Glob/Grep** — они перечислены ниже.

## W1 — Coverage P0 + P1 + Admin role

- **`app/notification/dispatchers.py`** — 33 строки, 0% coverage; экспортирует `InAppDispatcher`, `TelegramDispatcher`, `EmailDispatcher`. Entrypoint: `dispatch(notification, channel)`. Здесь нужны новые тесты, исходник НЕ менять.
- **`app/broker/tinvest/adapter.py`** — 394 строки, 24% coverage. Методы: `get_balance`, `get_positions`, `get_operations`, `place_order`, `cancel_order`, плюс streaming. Для моков см. fixture-патчи в `tests/test_broker_tinvest/` (уже работают, расширь). Использует `app.state.tinvest_multiplexer` (контракт C-S8-6 от BACK2).
- **`app/trading/service.py`** — 334 строки, 51% coverage. Методы: `start_session`, `stop_session`, `pause`, `resume`, `get_session`, `get_dashboard`, `get_stats`. Возьми `tests/test_trading/test_service.py` как baseline и допиши кейсы (happy + error path).
- **`app/auth/dependencies.py`** — добавь `require_admin(user: User = Depends(get_current_user)) -> User`; raises `HTTPException 403` если `user.is_admin is False`. **НЕ ломать существующий `get_current_user`.**
- **`app/auth/router.py`** — изменение: добавить `is_admin` в response `/auth/me` (Pydantic `UserResponse` или эквивалент); в FirstRunWizard endpoint (создание первого пользователя) выставлять `is_admin=True`. Проверить по grep, где FirstRunWizard создаёт User.
- **`app/admin/router.py`** — **НОВЫЙ модуль (mount point)**. Каркас:
  ```python
  from fastapi import APIRouter, Depends
  from app.auth.dependencies import require_admin

  router = APIRouter(prefix="/api/v1/admin", tags=["admin"], dependencies=[Depends(require_admin)])

  # Здесь FRONT2 в W2 примонтирует Plotly Dash на /metrics — НЕ делай этого сам.
  # Для каркаса добавь health-эндпоинт:
  @router.get("/ping")
  async def admin_ping() -> dict:
      return {"ok": True}
  ```
- **`app/cli/users.py`** — **НОВЫЙ CLI** с командой `grant_admin <username>` (через click или typer — выбери в соответствии с existing CLI стилем; см. `app/cli/restore.py` из S7 как образец). Запуск: `python -m app.cli.users grant_admin <username>`.
- **`app/main.py`** — добавить `app.include_router(admin_router)` (по аналогии с другими include_router вызовами).
- **Alembic-миграция** — `Develop/backend/alembic/versions/<timestamp>_add_users_is_admin.py` — autogenerate, ≈ 50 строк.

## W2 — Performance + Coverage P1 закрытие + P2 router-тесты

- **`app/common/observability.py`** — **НОВЫЙ файл** с `@timed_event(event_name: str)` decorator. Поддерживает async и sync функции. Пишет в structlog `event=<event_name>, duration_ms=<float>` после `await`/`return`. Расположение — `app/common/`, рядом с `crypto.py`, `event_bus.py`.
- **`app/market_data/service.py`** — 398 строк, 50% coverage. OHLCV cache, prefetch, ISS+TInvest fallback. Тесты — `tests/test_market_data/test_service_full.py`.
- **`app/backtest/router.py`** — 416 строк, 25% coverage. Endpoints: `POST /backtest`, `GET /:id/results`, `POST /grid`, `GET /list`, `POST /:id/rerun`, `POST /:id/export`. Тесты через `httpx.AsyncClient` + JWT-фикстуру.
- **`app/strategy/service.py`** — 215 строк, 52% coverage. CRUD + versioning. Тесты — `tests/test_strategy/test_service_full.py`.
- **`app/backtest/engine.py`** — 234 строки, 55% coverage. Backtrader integration + метрики. Тесты — `tests/test_backtest/test_engine_full.py`.
- **P2 router-тесты:** `app/auth/router.py`, `app/notification/router.py`, `app/broker/router.py`, `app/market_data/router.py`, `app/strategy/router.py`, `app/circuit_breaker/router.py`. Только endpoint-тесты через `httpx.AsyncClient` (не unit-логика, а HTTP-контракт).

# Задачи

## ─── W1 ───

### Задача W1.1 (P0, ~4ч): `notification/dispatchers.py` 0% → 80%

**Цель:** написать unit-тесты для трёх dispatcher'ов: `InAppDispatcher`, `TelegramDispatcher`, `EmailDispatcher`.

Файл тестов: `tests/test_notification/test_dispatchers.py`.

```python
class TestInAppDispatcher:
    async def test_creates_in_app_notification(self, db_session, test_user):
        """Happy path: dispatcher creates row in notifications table."""
        ...
    async def test_handles_db_error(self, db_session, test_user, monkeypatch):
        """Error path: SQLAlchemyError → logged + не падает."""
        ...

class TestTelegramDispatcher:
    async def test_sends_to_bot_when_chat_id_present(self, mock_telegram_client):
        ...
    async def test_skips_when_no_chat_id(self, mock_telegram_client):
        """Если notification_settings.telegram_chat_id пуст — silently skip."""
        ...

class TestEmailDispatcher:
    async def test_sends_via_smtp(self, mock_smtp):
        ...
    async def test_handles_smtp_failure(self, mock_smtp):
        ...
```

**Критерий приёмки:** `pytest --cov=app/notification/dispatchers.py` ≥ 80%.

### Задача W1.2 (P1, ~16ч, TDD): `broker/tinvest/adapter.py` 24% → 80%

**Цель:** покрыть 5 методов адаптера unit-тестами с моками tinkoff-investments SDK.

Файл тестов: `tests/test_broker_tinvest/test_adapter_full.py`.

Для каждого метода (`get_balance`, `get_positions`, `get_operations`, `place_order`, `cancel_order`):
- **happy path** — корректный ответ tinkoff SDK → корректный возврат адаптера.
- **error path 1** — `RequestError`/`AioRequestError` → adapter raises наше доменное исключение `BrokerError`.
- **error path 2** — таймаут (asyncio.TimeoutError) → BrokerError с правильным сообщением.
- **error path 3** — невалидный response (None, пустой список где не ожидается) → graceful degrade.
- **error path 4** — circuit-breaker / retry path (если применимо для метода).

**TDD:** Red-Green-Refactor. **Не модифицируй сам адаптер**, если только тесты не выявят реальный баг — тогда зафиксируй в `Sprint_8/changelog.md`.

**Использует контракт C-S8-6:** в setup-фикстуре получай `tinvest_multiplexer` от BACK2 через `app.state.tinvest_multiplexer` (mock) — НЕ создавай свой мультиплексер per-test.

**Критерий приёмки:** coverage `app/broker/tinvest/adapter.py` ≥ 80%.

### Задача W1.3 (P1, ~12ч, TDD): `trading/service.py` 51% → 80%

**Цель:** дозакрыть тесты для `start_session`, `stop_session`, `pause`, `resume`, `get_session`, `get_dashboard`, `get_stats`.

Файл тестов: `tests/test_trading/test_service_full.py` (новый), `tests/test_trading/test_service.py` — НЕ дублировать, только дополнить.

Кейсы (минимум):
- **start_session:** конфликт (active session уже есть на (user_id, ticker, account)) → ValueError; missing strategy_version → 404; success → возвращает `TradingSession`.
- **stop_session:** session_id не найден; session уже stopped; success.
- **pause/resume:** state transitions (active→paused→active); недопустимый переход (stopped→paused) → ошибка.
- **get_session, get_dashboard, get_stats:** empty case, full case, фильтрация по user.
- **Permission check:** другой user не может остановить чужую сессию.

**TDD:** Red-Green-Refactor. Реализация уже есть — пишешь только тесты.

**Критерий приёмки:** coverage `app/trading/service.py` ≥ 80%.

### Задача W1.4 (эпик N, ~6ч): Admin role backend

#### W1.4.a (~2ч): Alembic-миграция

```bash
cd Develop/backend
.venv/bin/alembic revision --autogenerate -m "add users.is_admin"
# Проверь сгенерированный файл — должно быть add_column('users', Column('is_admin', Boolean, default=False, nullable=False))
.venv/bin/alembic upgrade head
.venv/bin/alembic downgrade -1
.venv/bin/alembic upgrade head
```

В модели `app/user/models.py` (или где определён `User`) добавь:
```python
is_admin: Mapped[bool] = mapped_column(default=False, nullable=False)
```

#### W1.4.b (~3ч): Dependency + Admin router модуль

В `app/auth/dependencies.py`:
```python
async def require_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Admin privileges required")
    return user
```

Создай `app/admin/__init__.py` и `app/admin/router.py` (см. секцию «Контекст существующего кода» — каркас выше).

Зарегистрируй в `app/main.py`:
```python
from app.admin.router import router as admin_router
app.include_router(admin_router)
```

#### W1.4.c (~1ч): CLI grant_admin

Создай `app/cli/users.py`. Стиль — посмотри `app/cli/restore.py` (S7). Пример (если click):

```python
import click
import asyncio
from app.user.repository import get_user_by_username, update_user

@click.group()
def cli(): pass

@cli.command()
@click.argument("username")
def grant_admin(username: str) -> None:
    """Grant admin privileges to user by username."""
    asyncio.run(_grant_admin(username))

async def _grant_admin(username: str) -> None:
    user = await get_user_by_username(username)
    if user is None:
        click.echo(f"User {username} not found", err=True)
        raise SystemExit(1)
    user.is_admin = True
    await update_user(user)
    click.echo(f"User {username} is now admin")

if __name__ == "__main__":
    cli()
```

Запуск: `python -m app.cli.users grant_admin <username>`.

#### W1.4.d (~1ч): Bootstrap первого админа через FirstRunWizard

Найди endpoint FirstRunWizard (`grep -rn "first_run\|FirstRun\|needs_setup" app/`). При создании первого пользователя (когда `User.count() == 0`) выставляй `is_admin=True`.

Условие: **если в БД ещё нет пользователей** → новый пользователь = admin. Аналогично существующему `needs_setup` flag.

#### W1.4.e (~3ч): тесты Admin role

Файл `tests/test_admin/test_admin_role.py`:
```python
async def test_require_admin_blocks_non_admin(authenticated_client, test_user):
    """Обычный user → 403 на /api/v1/admin/ping."""
    ...
async def test_require_admin_allows_admin(authenticated_client, admin_user):
    """Admin user → 200 на /api/v1/admin/ping."""
    ...
```

Файл `tests/test_admin/test_admin_cli.py`:
```python
def test_grant_admin_promotes_user(db_session, test_user):
    """CLI grant_admin <username> → User.is_admin == True."""
    ...
def test_grant_admin_unknown_user_exits_nonzero(db_session):
    """Неизвестный username → SystemExit(1) + stderr."""
    ...
```

Файл `tests/test_admin/test_first_run_admin.py`:
```python
async def test_first_user_becomes_admin(client, empty_db):
    """FirstRunWizard → первый registered user is_admin=True."""
    ...
async def test_second_user_is_not_admin(client, test_user):
    """Если в БД уже есть пользователь → новый user is_admin=False."""
    ...
```

Также добавь фикстуру `admin_user` в `tests/conftest.py` (если её нет) — копия `test_user` с `is_admin=True`.

**Критерий приёмки:** все 3 файла зелёные, миграция up/down/up чистая.

## ─── W2 ───

### Задача W2.1 (~4ч): `@timed_event` decorator в `app/common/observability.py`

**Цель:** инструментировать критические пути для performance baseline (см. §4.3 arch_design).

```python
# app/common/observability.py
import functools
import time
from typing import Any, Callable, Awaitable
import structlog

log = structlog.get_logger(__name__)

def timed_event(event_name: str) -> Callable:
    """Decorator: logs duration_ms after function returns/awaits."""

    def decorator(func: Callable) -> Callable:
        if asyncio.iscoroutinefunction(func):
            @functools.wraps(func)
            async def async_wrapper(*args, **kwargs) -> Any:
                start = time.perf_counter()
                try:
                    result = await func(*args, **kwargs)
                    return result
                finally:
                    duration_ms = (time.perf_counter() - start) * 1000
                    log.info("timed_event", event=event_name, duration_ms=duration_ms)
            return async_wrapper

        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs) -> Any:
            start = time.perf_counter()
            try:
                return func(*args, **kwargs)
            finally:
                duration_ms = (time.perf_counter() - start) * 1000
                log.info("timed_event", event=event_name, duration_ms=duration_ms)
        return sync_wrapper

    return decorator
```

Применить хотя бы на 3 критических точках (для W3 perf baseline):
- `app/trading/runtime.py` — `SignalProcessor.process_candle` или `_handle_candle` → `@timed_event("signal.process")`
- `app/broker/tinvest/adapter.py` — `place_order` → `@timed_event("order.place")`
- `app/notification/telegram_webhook.py` — основной handler → `@timed_event("telegram.handle")`

Тесты в `tests/test_common/test_observability.py`:
- async function — duration_ms логируется.
- sync function — duration_ms логируется.
- exception inside function — duration_ms всё равно логируется (finally), исключение пробрасывается.

### Задача W2.2 (P1, ~14ч): Coverage P1 закрытие

- **`market_data/service.py`** 50% → 80% (~12ч из общего пула, реалистично ~5ч) — OHLCV cache, prefetch, ISS+TInvest fallback. Тесты в `tests/test_market_data/test_service_full.py`. Мокать ISS и TInvest клиенты.
- **`backtest/router.py`** 25% → 80% (~12ч общий пул, ~4ч практика) — endpoint-тесты через `httpx.AsyncClient` + JWT-фикстура. Покрыть все 6 endpoints (POST /backtest, GET /:id/results, POST /grid, GET /list, POST /:id/rerun, POST /:id/export). Файл `tests/test_backtest/test_router_full.py`.
- **`strategy/service.py`** 52% → 80% (~3ч) — CRUD + versioning. Файл `tests/test_strategy/test_service_full.py`.
- **`backtest/engine.py`** 55% → 80% (~2ч) — Backtrader integration + metrics computation paths. Файл `tests/test_backtest/test_engine_full.py`.

### Задача W2.3 (P2, ~10ч): Router-тесты

Файл `tests/test_routers/` (новый каталог) с шестью файлами:
- `test_auth_router.py` — POST /login, /logout, /refresh, GET /me, FirstRunWizard endpoint (`auth/router.py` 67% → 80%, ~2ч)
- `test_notification_router.py` — GET/POST /notifications, settings (`notification/router.py` 51% → 80%, ~2ч)
- `test_broker_router.py` — broker endpoints (`broker/router.py` 37% → 80%, ~2ч)
- `test_market_data_router.py` — quotes, candles, sparkline (`market_data/router.py` 62% → 80%, ~1ч)
- `test_strategy_router.py` — CRUD + versioning endpoints (`strategy/router.py` 52% → 80%, ~2ч)
- `test_circuit_breaker_router.py` — CB endpoints (`circuit_breaker/router.py` 60% → 80%, ~1ч)

Все тесты — через `httpx.AsyncClient` + `authenticated_client` фикстура. Проверять: 200/201 happy, 401 (no auth), 403 (wrong user), 422 (validation), 404 (not found).

# Опциональные задачи

Если время позволяет (W2 запас) — добить P2 «secondary modules» из arch_design §2.2 (P2):
- `notification/telegram_webhook.py` 74% → 80%
- `ai/service.py` 55% → 80%
- `ai/router.py` 51% → 80%
- `scheduler/service.py` 44% → 80%
- `tax/service.py` 76% → 80%

В отчёте явно укажи **PASS — реализовано** для каждой добитой или **SKIP — reason: <out of W2 budget>** для пропущенной. Молчание = блокер.

# Skip-тикеты в тестах

Если ввёл `@pytest.mark.skip(reason="<причина>")` — обязательно:
1. В отчёте полный список с обоснованием.
2. Карточка в `Sprint_8_Review/backlog.md` или `Sprint_9_Review/backlog.md` с тикетом `S8R-<NAME>`.

Skip без карточки — **блокер**.

# Тесты

```
tests/
├── test_notification/
│   └── test_dispatchers.py         # W1: P0 — in-app, telegram, email dispatch entrypoint
├── test_broker_tinvest/
│   └── test_adapter_full.py        # W1: P1 — 5 методов × (happy + 4 error path)
├── test_trading/
│   └── test_service_full.py        # W1: P1 — start/stop/pause/resume/get/dashboard/stats
├── test_admin/
│   ├── test_admin_role.py          # W1: require_admin dependency
│   ├── test_admin_cli.py           # W1: CLI grant_admin
│   └── test_first_run_admin.py     # W1: FirstRunWizard bootstrap
├── test_common/
│   └── test_observability.py       # W2: @timed_event decorator (async/sync/exception)
├── test_market_data/
│   └── test_service_full.py        # W2: P1 — cache, prefetch, fallback
├── test_backtest/
│   ├── test_router_full.py         # W2: P1 — 6 endpoints через httpx.AsyncClient
│   └── test_engine_full.py         # W2: P1 — metrics paths
├── test_strategy/
│   └── test_service_full.py        # W2: P1 — CRUD + versioning
└── test_routers/                    # W2: P2
    ├── test_auth_router.py
    ├── test_notification_router.py
    ├── test_broker_router.py
    ├── test_market_data_router.py
    ├── test_strategy_router.py
    └── test_circuit_breaker_router.py
```

**Фикстуры (уже существуют в `tests/conftest.py` — использовать, не пересоздавать):**
- `db_session` — sqlite memory session per test
- `test_user`, `admin_user` (admin_user добавишь сам, если нет)
- `authenticated_client` — httpx.AsyncClient с JWT в headers
- `test_strategy`, `test_strategy_version`
- `mock_broker`, `mock_telegram_client`, `mock_smtp`
- `mock_event_bus`

# ⚠️ Integration Verification Checklist

Для **каждой** новой сущности:

## W1

- [ ] **W1.1 (dispatchers):** `pytest --cov=app/notification/dispatchers.py` → ≥ 80%. Все 3 dispatcher'а покрыты.
- [ ] **W1.2 (tinvest adapter):** `pytest --cov=app/broker/tinvest/adapter.py` → ≥ 80%. 5 методов × 5 кейсов = ≥ 25 новых test-функций.
- [ ] **W1.3 (trading service):** `pytest --cov=app/trading/service.py` → ≥ 80%. 7 методов покрыты.
- [ ] **W1.4 (Admin role):**
  - [ ] `grep -rn "is_admin" app/user/` показывает поле в модели User
  - [ ] `grep -rn "require_admin" app/` показывает определение в `app/auth/dependencies.py` **и** использование в `app/admin/router.py`
  - [ ] `grep -rn "from app.admin" app/main.py` показывает include_router
  - [ ] `grep -rn "is_admin" app/auth/router.py` показывает поле в `/auth/me` response и установку в FirstRunWizard
  - [ ] `python -m app.cli.users grant_admin <username>` запускается без ImportError
  - [ ] Миграция `alembic upgrade head` → `alembic downgrade -1` → `alembic upgrade head` чистая
  - [ ] `app.include_router(admin_router)` в `main.py` присутствует

## W2

- [ ] **W2.1 (`@timed_event`):**
  - [ ] `grep -rn "timed_event" app/` показывает определение в `app/common/observability.py` **и** ≥ 3 применения (в `trading/`, `broker/`, `notification/`)
  - [ ] Тест прогоняется: async + sync + exception сценарии зелёные
- [ ] **W2.2 (P1 closure):** все 4 модуля (market_data/service, backtest/router, strategy/service, backtest/engine) ≥ 80%
- [ ] **W2.3 (P2 router-тесты):** все 6 router'ов ≥ 80%
- [ ] **TOTAL coverage** на конец W2 — `pytest --cov=app` → ≥ 80% (Gate W2 → W3 из arch_design §8.3)

## Контракты

- [ ] **C-S8-7 (поставщик BACK1):** `is_admin: bool` поле в User + `/auth/me` response показывает `is_admin`. Подтверждено grep'ом и тестом `test_auth_me_returns_is_admin` в `test_auth_router.py`.
- [ ] **C-S8-6 (потребитель BACK1):** Используешь `app.state.tinvest_multiplexer` в фикстурах `test_adapter_full.py` (НЕ создаёшь свой). Если BACK2 не сделал MULTIPLEXER-SINGLETON к моменту твоего старта — пометь `⚠️ BLOCKER: waiting for BACK2 C-S8-6` в отчёте и переключись на W1.3 / W1.4.

## Если точка вызова не найдена

`⚠️ Runtime integration: NOT CONNECTED — <class/method> не вызывается в runtime. Требуется следующая задача: <X.Y>`. Такая пометка блокирует приёмку.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

**2 файла**, каждый — 8 секций до 400 слов по шаблону.

1. **`reports/DEV-1_BACK1_W1.md`** — после задач W1.1, W1.2, W1.3, W1.4.
2. **`reports/DEV-1_BACK1_W2.md`** — после задач W2.1, W2.2, W2.3.

Шаблон секций:
1. Что реализовано (5–10 пунктов, крупными мазками).
2. Файлы (новые / изменённые / удалённые).
3. Тесты (X/Y passed; coverage по каждому целевому модулю; failed → диагноз).
4. Integration points (`<ClassName>.<method>` вызывается из `<file:line>` ✅ или ⚠️ NOT CONNECTED).
5. Контракты (поставляю — C-S8-7 потребитель FRONT2; использую — C-S8-6 от BACK2, контракт соблюдён).
6. Проблемы / TODO.
7. Применённые Stack Gotchas (минимум 3 ловушки из `Develop/stack_gotchas/INDEX.md`).
8. Новые Stack Gotchas (если найдены — формат симптом/причина/правило/related_files).
9. Использование плагинов (pyright-lsp, context7, TDD, code-review — статус по каждому).

# Alembic-миграция (W1.4.a)

```bash
cd Develop/backend
.venv/bin/alembic revision --autogenerate -m "add users.is_admin"
.venv/bin/alembic upgrade head
.venv/bin/alembic downgrade -1
.venv/bin/alembic upgrade head
```

В отчёте укажи имя сгенерированного файла (`alembic/versions/<timestamp>_add_users_is_admin.py`) и лог up/down/up прогона.

# Чеклист перед сдачей

## W1

- [ ] Все задачи W1.1–W1.4 реализованы.
- [ ] Coverage modulewise: `notification/dispatchers.py` ≥ 80%, `broker/tinvest/adapter.py` ≥ 80%, `trading/service.py` ≥ 80%.
- [ ] Admin role полностью: миграция + dependency + admin/router.py + CLI + FirstRunWizard bootstrap + 3 файла тестов зелёные.
- [ ] Тесты зелёные: `pytest tests/ -q` → 0 failures.
- [ ] Линтер: `ruff check app/ tests/` → 0 issues.
- [ ] Type-check: `pyright app/` → 0 errors (или fallback `py_compile`).
- [ ] Integration verification checklist W1 полностью пройден.
- [ ] Формат отчёта W1 соблюдён (8 секций).
- [ ] Отчёт сохранён: `Sprint_8/reports/DEV-1_BACK1_W1.md`.
- [ ] Cross-DEV contracts W1: C-S8-7 поставщик подтверждён; C-S8-6 потребитель — статус (используется / waiting).
- [ ] Stack Gotchas применены (минимум 3 ловушки в отчёте W1).
- [ ] `Sprint_8/changelog.md` обновлён немедленно после каждого блока W1.
- [ ] `Sprint_8/sprint_state.md` отражает прогресс W1.

## W2

- [ ] Все задачи W2.1–W2.3 реализованы.
- [ ] `@timed_event` decorator работает (async + sync + exception) + применён минимум на 3 критических точках.
- [ ] Coverage P1 закрытие: market_data/service, backtest/router, strategy/service, backtest/engine — все ≥ 80%.
- [ ] Coverage P2 router-тесты: 6 router'ов ≥ 80%.
- [ ] **TOTAL coverage ≥ 80%** (gate W2 → W3 из arch_design §8.3).
- [ ] Опциональные задачи (P2 secondary modules) явно закрыты PASS/SKIP+reason в отчёте.
- [ ] Тесты зелёные: `pytest tests/ -q` → 0 failures.
- [ ] Линтер чистый.
- [ ] Type-check чистый.
- [ ] Integration verification checklist W2 полностью пройден.
- [ ] Формат отчёта W2 соблюдён.
- [ ] Отчёт сохранён: `Sprint_8/reports/DEV-1_BACK1_W2.md`.
- [ ] Skip-тикеты (если есть) с карточками в backlog.
- [ ] `Sprint_8/changelog.md` обновлён немедленно после каждого блока W2.
- [ ] `Sprint_8/sprint_state.md` отражает прогресс W2.
- [ ] Плагины: pyright-lsp использован на всех Edit/Write; context7 использован для FastAPI TestClient/httpx/structlog (отметить в секции 9 отчёта); code-review запущен после блоков в `app/trading/`, `app/broker/`, `app/admin/`.
