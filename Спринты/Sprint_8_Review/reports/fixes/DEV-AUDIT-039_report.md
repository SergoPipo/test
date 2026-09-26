## DEV-AUDIT-039 отчёт — S8R fixes, MEDIUM (после ревью оркестратора)
Статус: ✅ готово к коммиту (worktree B, от 16daf82, не закоммичено)
### 1. Что реализовано
- `POST /auth/logout` без валидного access: **всегда 204** и Max-Age=0 для `access_token` (/), `refresh_token` (/api/v1/auth и прежний /api/v1/auth/refresh), `csrf_token` (/). Ответ одинаков для любого токена и тела, поэтому по нему нельзя узнать, существует ли пользователь.
- Refresh-cookie выдаётся на path `/api/v1/auth`, поэтому доезжает и до logout. Cookie со старым path стирается при каждой выдаче: иначе две cookie на /refresh → reuse-detection.
- Отзыв делается одной транзакцией (`revoke_for_logout`) без SELECT; дубль rjti = refresh.jti пропускается. Access ищется сначала в Bearer, затем в cookie (битый Bearer → отзывается токен из cookie). Refresh ищется в cookie, затем в теле.
- Отзыв best-effort: при сбое БД — лог и rollback, но 204 и стирание cookie всё равно уходят. Тело разбирается только в `extract_refresh_token` (≤ 4 КБ); схема тела — в `openapi_extra`.
- CSRF: logout в `ORIGIN_CHECKED_PATHS` — чужой Origin → 403 и без cookie-сессии.
- Общие хелперы: `refresh_token_claims` (request_tokens, заодно и для лимитера), `decode_access_payload` (middleware/auth, заодно для `get_current_user`).
- CORS: `expose_headers=["Retry-After"]`.
- Фронт: `refreshSession()` → `'refreshed'|'rejected'|'unavailable'`. Повтор **только на 429**: до 3 попыток, Retry-After ≤ 10 с, иначе backoff 1→2 с. На 5xx и обрыв сети — сразу `unavailable`. После `unavailable` — пауза 10 с без новых refresh. Logout — только на `rejected`. `getCSRFToken` берётся из `client.ts`. Single-flight не тронут.
### 2. Файлы (изменены)
backend app: `auth/router.py`, `auth/service.py`, `auth/request_tokens.py`, `middleware/auth.py`, `middleware/csrf.py`, `middleware/rate_limit.py` (константа), `main.py`.
tests: `unit/test_auth_router.py`, `unit/test_auth_service.py`, `unit/test_middleware/test_csrf.py`, `test_routers/test_auth_router.py`, `test_routers/test_auth_cookie_secure.py`.
frontend: `api/session.ts`, `api/client.ts`, `services/aiStreamClient.ts` и их тесты; `e2e/auth-hardening.spec.ts` (path cookie).
### 3. Тесты
RED (исходный): `assert 401 == 204`; фронт: `expected false to be 'unavailable'`.
GREEN: logout — истёкший access + cookie на новом path → jti отозван; `{"refresh_token":123}`, массив, битый JSON → 204; упавший commit → 204 и Max-Age=0; чужой Origin → 403; login → path /api/v1/auth и стирание старого path; CORS Retry-After; сервис — 1 commit и 2 строки. Фронт: 502 и сеть → 1 запрос `unavailable`; 429×3; cooldown.
Мутации:
- бэк: `Depends(get_current_user)` → `assert 401 == 204`;
- фронт (новая): «повтор и на 5xx» → `502 … expected 3 to be 1`.
Обе откачены по md5.
Гейты: pytest 3191 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (182); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 952 passed.
### 4. Integration points
✅ `router.py:293-313, 115, 333`; ✅ `middleware/auth.py:97`; ✅ `request_tokens.py:88` (лимитер); ✅ `csrf.py:130`; ✅ `client.ts`, `aiStreamClient.ts`.
### 5. Контракты
Logout: 204 всегда (было 401/422). Path refresh-cookie `/api/v1/auth`. Миграции нет.
### 6. Проблемы / документы
- **ТЗ §7.3**, заменить пункт logout: «Logout всегда 204 и стирает cookie (refresh — по path `/api/v1/auth` и прежнему `/api/v1/auth/refresh`). Отзыв одной транзакцией: access+rjti при валидном access (Bearer, иначе cookie), refresh-jti при валидном refresh (cookie → тело). Сбой БД не мешает стиранию (S8R-AUDIT-039)». Там же: «refresh-cookie: HttpOnly, SameSite=Strict, path `/api/v1/auth`».
- **ТЗ §7.4**, дописать: «logout проверяет источник и без cookie-сессии (чужой Origin → 403)».
- **ТЗ §7.5**, дописать: «`Retry-After` открыт через CORS `expose_headers`».
- **ФТ** (строка Model A): «Выход завершает сеанс и после простоя. Временный сбой сервера при продлении сеанса не выкидывает: при перегрузке продление повторяется, при недоступности сервера пользователь остаётся в системе».
- E2E `auth-hardening` (path) — прогон на стороне оркестратора.
- Самопроверка: 1 — сбой commit даёт rollback, лог, 204 и стирание (тест); 2 — уведомлений нет; 3 — тесты через полный ASGI и CSRF; 4 — таймаутов нет; 5 — вызывающие `refreshSession` (2), `refresh_token_subject` (лимитер), `get_current_user` проверены; 6 — тело ≤ 4 КБ.
- **Ревью: исправлено 1–10.**
### 7. Применённые Stack Gotchas
16, 60.
### 8. Новые Stack Gotchas
Кандидат: смена `Promise<boolean>` на строковый union ломает `if (await fn())` без ошибки типов.
### 9. Плагины
py_compile + mypy; `tsc -b`; context7 не нужен; скилл tdd.
