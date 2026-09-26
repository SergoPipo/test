## DEV-AUDIT-040 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (после ревью оркестратора)
### 1. Что реализовано
- `COOKIE_SECURE` (`config.py`): если не задан или пуст — fail-closed: при DEBUG=false Secure ставится всегда, при DEBUG=true работает `auto`. Явные `auto`/`true`/`false` перекрывают это правило. Принимаются алиасы `1/yes/on` и `0/no/off`, регистр и пробелы не важны; любое другое значение — ошибка старта с понятным текстом.
- `app/common/cookies.py` (новый лёгкий модуль): `cookie_secure` (при auto — `request.url.is_secure`, это https и wss) и `set_csrf_cookie`. Модуль используют router и CSRFMiddleware. Для access, refresh и csrf — один и тот же Secure и при выдаче, и при стирании.
- nginx: `geo $realip_remote_addr` + `map` — `X-Forwarded-Proto: https` принимается только с адресов cloudflared (те же, что `set_real_ip_from`), от остальных подставляется `$scheme`.
- preflight: при недопустимом `COOKIE_SECURE` — fail; `false` в проде — WARNING «cookie без Secure».
- LAN уже закрыт карточкой 037 (`127.0.0.1:80`). E2E-стенд (DEBUG=true, http) — cookie без Secure, как раньше.
- Cloudflare передаёт схему посетителя в X-Forwarded-Proto: [http-headers](https://developers.cloudflare.com/fundamentals/reference/http-headers/). Через tunnel заголовок доходит до origin — это видно в [cloudflared#358](https://github.com/cloudflare/cloudflared/issues/358).
### 2. Файлы
Новый: `backend/app/common/cookies.py`. Изменены: `backend/app/{config.py, auth/router.py, middleware/csrf.py}`, `nginx.conf`, `scripts/check_production_env.sh`, тесты `unit/test_auth_router.py`, `unit/test_config.py`, `test_routers/test_auth_cookie_secure.py`.
### 3. Тесты
RED: `AttributeError: 'Settings' object has no attribute 'COOKIE_SECURE'`, затем `{'access_token': {False}} != {'access_token': {True}}`. GREEN — 46 тестов в test_auth_router и 77 в test_config. Мутация «дефолт auto в проде» → падает `test_default_in_production_is_secure_even_over_http` (`{'access_token': {False}} != {'access_token': {True}}`); откат сверен по md5. Гейты: pytest 3244 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (183); bandit — проблем нет; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета. `nginx -t` не выполнялся: на машине нет nginx и docker, конфигурация проверена тестом по тексту.
### 4. Integration points
✅ `router.py:152` (setup/login/refresh/password), `router.py:345` (logout), `csrf.py:100` (переиздание).
### 5. Контракты
API не менялся, миграции нет. Новая env `COOKIE_SECURE`.
### 6. Правки документов / находки
- **Гайд §3.2 (строка таблицы):** «`COOKIE_SECURE` | (опц.) Secure у cookie сессии. Не задано — в production всегда Secure; `auto` — по схеме запроса; `true`/`false` — принудительно (алиасы 1/yes/on, 0/no/off). Доступ без TLS (LAN/local-only) — `false`, **не** `DEBUG=true`; preflight предупредит | по умолчанию не задано».
- **Гайд §3.3:** «`--proxy-headers`/`TRUSTED_PROXY_IPS` передают backend и схему (`X-Forwarded-Proto`); nginx пропускает `https` только от cloudflared (geo+map, те же адреса, что `set_real_ip_from`)».
- **Гайд §5.3, проверка:** «После входа через `https://<домен>` откройте DevTools → Application → Cookies: у `access_token`, `refresh_token`, `csrf_token` стоит ✓ Secure. Включите в Cloudflare *Always Use HTTPS*».
- **ТЗ §7.4:** «Secure у access/refresh/csrf и при их стирании — `app/common/cookies.cookie_secure`: `COOKIE_SECURE` не задан → prod всегда, dev по схеме; `auto` — `url.is_secure` (X-Forwarded-Proto только от доверенного прокси); `true`/`false` — принудительно (S8R-AUDIT-040)». **§8.10:** «nginx передаёт `X-Forwarded-Proto: https` только от адресов cloudflared».
- Строку для `.env.example` добавляет оркестратор.
- Ревью: исправлены все пункты 1–9.
- Самопроверка: п.1, 2, 4 — не затронуты; п.3 — тесты идут через реальный `ProxyHeadersMiddleware` и полное приложение, путь по умолчанию (`None`) покрыт тестами; п.5 — все вызывающие проверены; п.6 — нет.
### 7. Stack Gotchas
46, 50.
### 8. Новые
Кандидат: «TLS снимает внешний прокси, nginx шлёт `X-Forwarded-Proto $scheme` → backend всегда видит http».
### 9. Плагины
py_compile + прогон; tdd; WebSearch/WebFetch (Cloudflare). context7 (pydantic-settings): env-значения простых полей передаются «как есть», пустая строка тоже (`env_ignore_empty` выключен). Поэтому `field_validator(mode="before")` получает сырую строку. Проверено прогоном: `''`/`'  '` → None, `YES` → true, `maybe` → ValidationError.
