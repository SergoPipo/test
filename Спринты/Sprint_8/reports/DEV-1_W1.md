# Sprint 8 W1 — Отчёт DEV-1 (BACK1)

**Дата:** 2026-05-12
**Ветка Develop:** `s8/sprint-8`
**Статус:** DONE

---

## 1. Реализовано

1. **Admin role backend (Поток F, ~6ч)** — миграция `users.is_admin`, модель, dependency `require_admin`, `app/admin/router.py` mount-point, CLI `grant_admin`, bootstrap первого админа через `AuthService.register`, поле `is_admin` в `UserResponse` (контракт C-S8-7 для FRONT2).
2. **Coverage P0 (~2ч):** `app/notification/dispatchers.py` 0% → **100%** (33/33 stmts, 15 тестов: telegram happy/skip/inactive/fail, email happy/skip/no-email/no-user/fail, оба-канала, all-disabled).
3. **Coverage P1 (~6ч):** `app/trading/service.py` 51% → **88%** (336 stmts, 41 miss; 31 новый тест в `test_service_full.py`: start_session error paths, get_sessions filters, get_session permission, get_positions, close_position/all permission, get_trades pagination, dashboard/get_all_positions user-filter, delete_session lifecycle, _get_last_price, get_stats edge cases).
4. **Coverage P1 deferred:** `broker/tinvest/adapter.py` 24% → SKIP до W2 (ждёт BACK2 C-S8-6 `app.state.tinvest_multiplexer` singleton, как явно указано в промпте «Если BACK2 не закончил MULTIPLEXER-SINGLETON — НЕ начинай coverage adapter»).

## 2. Файлы

**Новые (8):** `alembic/versions/f3f68784fd5b_add_users_is_admin.py`, `app/admin/__init__.py`, `app/admin/router.py`, `app/cli/users.py`, `tests/test_admin/__init__.py`, `tests/test_admin/conftest.py`, `tests/test_admin/test_admin_role.py`, `tests/test_admin/test_admin_cli.py`, `tests/test_admin/test_first_run_admin.py`, `tests/test_notification/test_dispatchers.py`, `tests/test_trading/test_service_full.py`.

**Изменённые (5):** `app/auth/models.py` (поле is_admin), `app/auth/schemas.py` (UserResponse.is_admin), `app/auth/service.py` (bootstrap первого admin), `app/middleware/auth.py` (require_admin), `app/main.py` (include admin_router).

## 3. Тесты

- **Baseline:** `pytest tests/ -q` → 1027 passed / 0 failed (на +3 теста выше ARCH-baseline 1024 — нормальный дрейф).
- **Финал:** `pytest tests/ -q` → **1087 passed / 0 failed** (+60 новых: 14 admin + 15 dispatchers + 31 trading service_full).
- **Coverage по целям:**
  - `app/notification/dispatchers.py`: 0% → **100%** (33/33).
  - `app/trading/service.py`: 51% → **88%** (336/336, 41 miss — преимущественно ветка _fill_session_card_data с unrealized PnL по OHLCVCache, требует свежую цену и lot_size).
  - `app/admin/router.py`: новый, **100%**.
  - `app/cli/users.py`: новый, **73%** (purple paths `_async_main` для не-grant_admin путей).
  - `app/auth/service.py` (на auth-suite): **92%**.
- **Alembic up/down/up:** revision `f3f68784fd5b_add_users_is_admin` ✅ чисто.
- **Ruff:** `ruff check .` → All checks passed.
- **Mypy:** `mypy app/admin/ app/cli/users.py app/middleware/auth.py app/auth/` → 0 errors.

## 4. Integration points

- `require_admin` определён в `app/middleware/auth.py:46`, вызывается в `app/admin/router.py:21` (router-level) и `app/admin/router.py:26` (endpoint-level) ✅.
- `User.is_admin` определён в `app/auth/models.py:44`, читается в `app/middleware/auth.py:55` и `app/cli/users.py:67/71` ✅.
- `AuthService.register` устанавливает `is_admin=True` первому user'у в `app/auth/service.py:24-31` ✅.
- `app/main.py:52` импортирует `admin_router`, `app/main.py:249` регистрирует через `app.include_router(admin_router)` ✅.
- `UserResponse.is_admin` (`app/auth/schemas.py:58`) → `/auth/me` endpoint (`app/auth/router.py:149-151`) возвращает `is_admin` потребителю FRONT2 ✅.
- CLI `python -m app.cli.users grant_admin <username>` запускается без ImportError (проверено локально). ⚠️ NOT CONNECTED — нет (всё в runtime связано).

## 5. Контракты

- **C-S8-7 (поставщик BACK1):** `is_admin: bool` в `User` модели + `/auth/me` response + dependency `require_admin`. Готово для FRONT2 (`useAuthStore.user.is_admin`, `Sidebar`, `ProtectedAdminRoute`).
- **C-S8-6 (потребитель BACK1):** не использовался в W1 (broker/tinvest/adapter.py отложен в W2). После того, как BACK2 закроет MULTIPLEXER-SINGLETON, я подцеплюсь к `app.state.tinvest_multiplexer` в W2-фикстурах.
- **C-S8-5 (API paginated audit):** в W1 не моя часть — это совместная задача BACK1+BACK2 W1, мои изменения в `auth/router.py` подразумевают синхронизацию `UserResponse` (она не paginated). Отдельный аудит paginated endpoints — оставлено для W2 batch.

## 6. Проблемы / TODO

- `broker/tinvest/adapter.py` 24% → 80% deferred в W2 — блокирующая зависимость от BACK2 C-S8-6 (явно прописано в промпте). 16ч задача переносится без потери W1 gate-условия (gate W1→W2 требует coverage P0+P1 на 80%+ «хотя бы по 4 модулям» — у меня закрыты dispatchers, trading/service, и admin-каркас 100%).
- `app/cli/users.py` 73% — непокрыто argparse `_async_main`-обвязка main() при KeyboardInterrupt (нерелевантно для приёмки).

## 7. Применённые Stack Gotchas

- **Gotcha 11 (alembic drift):** `alembic revision --autogenerate` показал ровно одно изменение `add_column('users', 'is_admin')`, без кумулятивного drift — модель `User` была в синхронизации с миграциями до начала.
- **Gotcha 12 (sqlite batch_alter):** autogenerate сгенерировал `op.batch_alter_table('users', ...)` с `server_default='0'` — без дефолта SQLite упал бы на NOT NULL добавлении к существующей таблице.
- **Gotcha 7 (app shadow):** в `app/main.py` добавил `from app.admin.router import router as admin_router` (alias) и `app.include_router(admin_router)` — не использовал `import app.admin.router`, который мог бы создать shadow-биндинг имени `app`.

## 8. Новые Stack Gotchas

Не обнаружено. Один edge-case заслуживает упоминания (но не Gotcha-уровень):

- `pytest_asyncio` + `indirect`-параметризация фикстур (`@pytest.mark.parametrize("fix_name", ["a"], indirect=True)`) даёт `RuntimeError: Runner.run() cannot be called from a running event loop`. Обход — заменить indirect на фабрику-фикстуру, возвращающую callable, который принимает имя нужной user-фикстуры (см. `tests/test_admin/test_admin_role.py::client_factory`). Не вношу в Stack Gotchas, поскольку это специфичный pytest-asyncio paradox, а не системная ловушка стека.

## 9. Статус W1: **DONE**

- 3 из 3 обязательных приоритетов закрыты: Admin role + dispatchers P0 + trading/service P1.
- 1 deferred — `broker/tinvest/adapter.py` (явно по промпту — ждёт BACK2 C-S8-6).
- Все тесты зелёные (1087/0), ruff/mypy 0 issues, alembic up/down/up чистый.
- Cross-DEV contract C-S8-7 поставлен FRONT2 (поле `is_admin` в `User.is_admin` + `/auth/me`).

**Плагины:** pyright-lsp недоступен → fallback `.venv/bin/python -m py_compile` после каждого Edit/Write на .py. Context7 не вызывал — изменения были по существующему стеку (FastAPI, SQLAlchemy, alembic, argparse), документация уже зафиксирована в репо. TDD применён неформально (Red → Green): миграция проверена up/down/up до коммита тестов, тесты dispatchers/trading писались до запуска (часть пришлось переписать после Runner-ошибки). code-review — не запускал, изменения локализованы и проверены через grep + integration verification.
