## DEV-AUDIT-033 отчёт — S8R fixes, BLOCKER
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. `POST /auth/setup` закрыт после первого пользователя: `get_user_count() > 0` → 403 «Регистрация закрыта: пользователь уже создан. Новые учётные записи создаёт администратор». Ветка 409 (BUG-12) поглощена гейтом — дубликат недостижим, 500 нет.
2. Атомарный bootstrap `AuthService.bootstrap_first_user`: одна инструкция `INSERT … SELECT … WHERE NOT EXISTS (users)`; проигравший гонку получает `rowcount=0` → 403. Без лока (не пересекается с `locks.py`) и без миграции.
3. `POST /api/v1/admin/users` (Q4-033=a): `RegisterRequest` (та же валидация), `AuthService.register` → `is_admin=False`, 409 на дубликат; под роутерным `require_admin`, CSRF общий.
4. `/api/v1/auth/setup` → категория `auth` лимитера.
5. Фронт: `SetupPage` — гейт по `GET /auth/setup-status` (`is_configured: true` → `/login`, лоадер на время проверки), комментарий «доступна всегда» убран; `LoginPage` — `is_configured: false` → `/setup` (ТЗ п.1303), ссылка «Создать аккаунт» удалена (вела на страницу, которая теперь возвращает назад).
6. E2E-моки `setup-status` в `auth.spec.ts`, `s4-review.spec.ts` → `{ is_configured: true, needs_setup: false }` (контракт бэка; `api_mocks.ts` уже был верен).
7. `test_setup_endpoint_allows_multiple_users` → `test_setup_rejected_after_first_user` (403, detail «закрыта», без cookie). Тесты второго пользователя (`test_me_second_user_is_not_admin`, `chart_drawings_crud` ×4) переведены на создание через admin-эндпоинт + login.

### 2. Файлы
Изменены: `backend/app/auth/{router,service}.py`, `app/admin/router.py`, `app/middleware/rate_limit.py`; тесты `unit/test_audit_s8r_auth_setup.py`, `unit/test_auth_router.py`, `test_routers/test_auth_router.py`, `unit/test_chart_drawings/test_chart_drawings_crud.py`, `unit/test_middleware/test_rate_limit.py`; `frontend/src/pages/{SetupPage,LoginPage}.tsx`, `e2e/auth.spec.ts`, `e2e/s4-review.spec.ts`.
Новые: `backend/tests/test_admin/test_admin_users_create.py`, `frontend/src/pages/__tests__/SetupPage.test.tsx`.

### 3. Тесты
RED: `assert 201 == 403` (`test_setup_rejected_after_first_user`), `assert 201 in (403, 409)` (доказательный), гонка `assert [201, 201] == [201, 403]`, admin `assert 404 == 422`, лимитер `assert 'general' == 'auth'`.
GREEN: все перечисленные + гонка (файловая БД, NullPool, рандеву в `get_user_count` до вставки) → `[201, 403]`, 1 пользователь, 1 admin.
Мутация: тело `setup()` возвращено к `register()` без гейта → три теста красные (`assert 201 == 403`, `[201, 201] == [201, 403]`); откачена.
Гейты: pytest 2633 passed / 24 xfailed / 0 failed; ruff 0; mypy Success (178); bandit 0/0; typecheck 0; lint 0; build ok; vitest 926 passed.

### 4. Integration points
✅ `bootstrap_first_user` — `app/auth/router.py:154`; ✅ `POST /admin/users` — `app/admin/router.py:40`, роутер подключён `main.py:353`, структурный тест `test_every_admin_route_requires_admin` зелёный; ✅ лимитер `rate_limit.py:47`; ✅ фронт `SetupPage.tsx` ↔ `setup-status`.

### 5. Контракты
`POST /auth/setup`: 201 только на пустой БД, иначе 403 `{detail}`. Новый `POST /api/v1/admin/users` → 201 `UserResponse` / 401 / 403 / 409 / 422. Миграции нет.

### 6. Проблемы / предлагаемые правки
- ТЗ §API (стр. ~871): добавить `POST /api/v1/admin/users — создание учётной записи (admin)`. ТЗ п.1303: убрать фразу «На странице логина отображается ссылка "Первый запуск? Создать аккаунт"» (авто-редирект остаётся).
- Гайд: новый подраздел «Дополнительные пользователи»: `curl -X POST /api/v1/admin/users -H 'Authorization: Bearer <admin>' -d '{"username":…,"password":…}'` (UI для этого нет — кандидат в S9).
- Стенд E2E (CLAUDE.md): рецепт `/auth/setup` работает только на чистой БД; `auth-hardening.spec.ts` `beforeAll` получит 403 на настроенной БД — игнорируется по замыслу.
- `register()` оставлен с неатомарным `is_admin = count == 0`: в проде вызывается только под admin (count>0), ветка bootstrap там недостижима.

### 7. Применённые Stack Gotchas
31, 48, 59 (тест гонки), 37 (скаляры до commit не понадобились — refresh после), 60 (`tsc -b`), 53 (миграций нет).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile ×4 (LSP в worktree не резолвит `app.*`), `pnpm typecheck`, context7 (SQLAlchemy `Insert.from_select(include_defaults)`), скилл `mattpocock-skills:tdd`.
