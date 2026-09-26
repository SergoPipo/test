## DEV-AUDIT-038 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes-b`, 25143f8, не закоммичено). Ревью-1: исправлено 1–8. Ревью-2: исправлено 1, 3–7; п. 2 не трогал (карточка 039); п. 8 — находка.
### 1. Что реализовано
- Cookie-сессия (`access_token`/`refresh_token`): мутирующий запрос требует double-submit, источник (`Origin`, иначе `Referer`) должен быть из allowlist. Клиенты без cookie (Bearer/CLI/webhook) не проверяются.
- login/setup проверяют источник всегда (login-CSRF). logout и refresh освобождены от double-submit, но при cookie-сессии обязан прийти свой источник. Без источника при cookie-сессии эти 4 пути → 403.
- `app/common/origin.py`:
  - нормализация: только http/https, нижний регистр, без пути и `/`, без порта по умолчанию;
  - `*`, userinfo, мусорный хост/порт → не origin;
  - allowlist — кортеж, кэш по значению `CORS_ORIGINS`; этот же объект получают CORSMiddleware, WS и CSRF;
  - модуль лёгкий (есть тест, что импорт не тянет jwt/ws_auth/БД).
- Safe-запрос с cookie-сессией без `csrf_token` получает её заново; установка — единственная функция `set_csrf_cookie`.
- Preflight — зеркало `normalize_origin`: нет валидного origin → fail; мусорные записи → WARNING; `set -f` против раскрытия `*` в имена файлов.
- `index.html`: `<meta name="referrer" content="strict-origin-when-cross-origin">`. `playwright_login.sh`: Origin берётся из `PW_ORIGIN`.
### 2. Файлы
- Новый: `backend/app/common/origin.py`.
- Изменены:
  - backend: `app/middleware/csrf.py`, `app/common/ws_auth.py`, `app/main.py`, `app/auth/router.py`;
  - тесты: `tests/unit/test_middleware/test_csrf.py`, `tests/test_routers/test_auth_cookie_secure.py`, `tests/unit/test_config.py`;
  - `frontend/index.html`, `scripts/check_production_env.sh`, `scripts/playwright_login.sh`.
### 3. Тесты
- RED `E       assert 200 == 403` → GREEN: CSRF-набор 88 тестов + 22 preflight, включая паритет shell↔Python под `sh` и `dash`.
- Мутация ревью-2: refresh убран из освобождённых от double-submit → 4 теста падают, в том числе `test_refresh_with_refresh_cookie_without_csrf_allowed_origin_passes` (`assert 403 == 200`). Откат из бэкапа, md5 совпал.
- Гейты: pytest 3174 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (182); bandit M0/H0; typecheck 0; lint 0; build ok, meta в `dist/index.html`.
- vitest: изменён только `index.html`, тестов на него нет — на уровне пакета.
### 4. Integration points
✅ `origin_allowed` — `csrf.py`, `ws_auth.py:72`; `cors_origins_list` — `main.py:364`; `set_csrf_cookie` — `csrf.py`, `router.py:117`.
### 5. Контракты
API/схемы без изменений, миграции нет. Новые 403: «Запрос с недопустимого источника (Origin)», «Запрос без источника (Origin) отклонён».
### 6. Проблемы / документы / находки
- **ТЗ §7.4, заменить** пункты про проверку на: «Cookie-сессия (`access_token`/`refresh_token`) → мутирующий запрос требует источник (`Origin`, иначе `Referer`) из `CORS_ORIGINS` и double-submit `csrf_token` = `X-CSRF-Token`. login/setup проверяют источник всегда; logout/refresh — при cookie-сессии; все четыре освобождены от double-submit. Без источника при cookie-сессии они → 403. Клиенты без cookie (Bearer/CLI/webhook) не проверяются. Safe-запрос с cookie-сессией без `csrf_token` переиздаёт её. Allowlist нормализуется (http/https, регистр, `/`, порт по умолчанию; `*` и мусор отбрасываются) и общий для CORS/WS/CSRF. SPA задаёт `referrer` = `strict-origin-when-cross-origin` (S8R-AUDIT-038).»
- **Гайд §2, `CORS_ORIGINS`:** «…только `http(s)://host[:port]`; регистр, завершающий `/` и порт по умолчанию не важны; `*` и записи без схемы игнорируются (preflight предупреждает, а без единого валидного origin — падает); без него вход, все изменяющие запросы и WS отбиваются 403».
- **Находка (п. 8):** гонка переиздания csrf на параллельных GET — запрос со старым значением может один раз получить 403. Возможно только при потерянной cookie.
- **Находка:** POST-колбэки Dash-mount без `X-CSRF-Token` — проверить на стенде.
- nginx: заголовок `Referrer-Policy` для SPA не добавлял — хватает meta; Docker на машине нет, конфиг не проверить.
- **Самопроверка:**
  1. Сбой записи в БД — n/a.
  2. Уведомления — n/a.
  3. Реальный путь — тесты идут через ASGI и через полное приложение.
  4. Таймауты — n/a.
  5. У `ws_origin_allowed` сравнение теперь нормализованное; у CORSMiddleware тот же объект — осознанно.
  6. Заголовки ограничивает сервер; кэш allowlist ключуется конфигом, а не данными клиента.
### 7. Gotchas
46, 60.
### 8. Новые Gotchas
Нет.
### 9. Плагины
py_compile, `pnpm typecheck`, tdd; context7 не нужен (stdlib, Starlette `Middleware.kwargs`/`set_cookie` проверены по месту).
