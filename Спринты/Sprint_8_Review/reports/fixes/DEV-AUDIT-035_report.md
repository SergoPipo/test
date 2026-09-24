## DEV-AUDIT-035 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. Колонка `users.token_version` (Integer NOT NULL, `server_default='0'`) + миграция `c5e8b2a7f913` (`batch_alter_table`, идемпотентна, обратима).
2. Claim `ver` в обоих JWT (`_create_token_pair(user_id, token_version)`); хелпер `token_version_of(payload)`: токен без `ver` = версия 0 (совпадает с `server_default`) — после деплоя никого не выкидывает, старые пары гаснут при первой смене пароля.
3. Проверка `ver` ≠ `users.token_version` → отказ: `get_current_user` (401 «Токен отозван»), `refresh_token` (ValueError), `ws_authenticate` (None → 4401), плюс зеркало в `AdminAuthASGIMiddleware` (`dash_mount.py`, повторяет `get_current_user`).
4. `change_password` → атомарный `UPDATE … SET token_version = token_version + 1` (`_bump_token_version`), возвращает **новую пару**; роутер кладёт её в cookie (access+refresh+csrf) тем же ответом, тело сохраняет `detail`. Фронт правок не требует: csrf читается из cookie на каждый запрос.
5. Reuse refresh (конфликт jti) → `token_version += 1` (выбран `token_version`, не `family_id`): актуальная пара семейства тоже гаснет. Атомарный `INSERT … ON CONFLICT` не тронут.
6. `ws_authenticate` стал async (читает версию через `app.state.db_factory` / `AsyncSessionLocal`; без фабрики — fail-closed); три вызывающих переведены на `await`. Несуществующий пользователь не отклоняется — это S8R-AUDIT-013 (strict-xfail 013 остались xfail).

### 2. Файлы
Новый: `backend/alembic/versions/c5e8b2a7f913_add_users_token_version.py`.
Изменены: `app/auth/{models,service,router}.py`, `app/middleware/auth.py`, `app/common/ws_auth.py`, `app/backtest/{ws,ws_backtest}.py`, `app/trading/ws_sessions.py`, `app/admin/dash_mount.py`, `tests/unit/test_auth_service.py` (+5 тестов), `tests/unit/test_migration.py` (+round-trip), `tests/test_routers/test_auth_cookie_secure.py` (тест адаптирован: новая пара в cookie).

### 3. Тесты
RED (6 failed): `Failed: DID NOT RAISE <class 'ValueError'>` (×2), `assert (None is not None)`, `DID NOT RAISE AuthenticationError`, `TypeError: object int can't be used in 'await' expression`, `AssertionError: users.token_version обязана появиться в c5e8b2a7f913` → GREEN 6 passed.
Мутация: `new_version = user.token_version` вместо `_bump_token_version` в `change_password` → 3 failed (`DID NOT RAISE ValueError`, `DID NOT RAISE AuthenticationError`, `assert 1 is None`) → откачена.
Гейты: pytest **2698 passed / 21 xfailed / 0 failed**; ruff 0; mypy Success (178); bandit 0/0; typecheck 0; lint 0; build ok; vitest 926 passed (2 expected fail).

### 4. Integration points
✅ `token_version_of` — `middleware/auth.py:64`, `auth/service.py:154`, `admin/dash_mount.py:173`, `common/ws_auth.py:64`; ✅ `_bump_token_version` — `service.py:176,217`; ✅ `await ws_authenticate` — `backtest/ws.py:160`, `backtest/ws_backtest.py:47`, `trading/ws_sessions.py:122`; ✅ `PATCH /auth/password` → `_auth_cookie_response(extra=detail)`.

### 5. Контракты
Миграция `c5e8b2a7f913`, `down_revision='a7b8c9d0e1f2'`, `alembic heads` = 1; round-trip на чистой БД в scratch: upgrade → downgrade -1 → upgrade — колонка появляется/исчезает/появляется. API: `PATCH /auth/password` теперь 200 + `Set-Cookie` ×3, тело `{detail, token_type, expires_in}`. JWT: новый claim `ver`.

### 6. Предлагаемые правки документов
- **deployment_guide.md §7** — `alembic current` ожидается `c5e8b2a7f913 (head)`; блок: «ℹ️ Обновление с версии старше `c5e8b2a7f913` (S8R, 2026-09-24). Ревизия добавляет `users.token_version` (DEFAULT 0). Смена пароля и повторное предъявление использованного refresh-токена теперь отзывают **все** сессии пользователя на всех устройствах; текущая вкладка получает новую пару автоматически. Перелогин после обновления не требуется: токены без версии считаются версией 0. Миграция идемпотентна и обратима; SQLite пересоздаёт `users` (`batch_alter_table`) — снимите backup (§6.1).»
- **ТЗ §7.3** добавить: «Claim `ver` = `users.token_version`; проверяется в HTTP, WS и refresh. Смена пароля и reuse refresh инкрементируют версию → все ранее выданные пары недействительны (S8R-AUDIT-035).»
- Новая находка: WS не проверяет отзыв jti/`is_active` — это S8R-AUDIT-013, не делалось.

### 7. Применённые Stack Gotchas
12 (batch_alter_table, server_default литерал), 13 (колонка + миграция синхронно, `test_fresh_db_schema_matches_models` зелёный), 37 (версия читается отдельным SELECT, не через expire), 48 (файловая БД + NullPool в ws-тесте), 53 (id проверен grep + `alembic heads`), 16 (single-flight refresh на фронте исключает ложный reuse).

### 8. Новые Stack Gotchas
Кандидат: httpx `AsyncClient.cookies.set()` без домена после `Set-Cookie` из ответа кладёт **вторую** cookie с тем же именем — в запрос уходят обе; перед подменой `client.cookies.clear()`. Файл: `tests/test_routers/test_auth_cookie_secure.py`.

### 9. Плагины
py_compile всех 10 `.py` (LSP в worktree не резолвит `app.*`); `pnpm typecheck` (tsc -b); context7 не потребовался (только SQLAlchemy `update().values(col + 1)`, известный API); TDD — `mattpocock-skills:tdd`, вертикальные срезы RED→GREEN→мутация.
