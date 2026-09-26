## DEV-AUDIT-037 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (код-ревью, итерация 3)

### 1. Что реализовано
- refresh не проверяет `locked_until`. Истёкшая блокировка сбрасывает `failed_login_count` — вечного lockout больше нет.
- IP клиента выставляет uvicorn `--proxy-headers --forwarded-allow-ips="$TRUSTED_PROXY_IPS"`. По умолчанию доверие только nginx: `172.28.0.10`, фиксированный `ipv4_address` в moex-net `172.28.0.0/24`. nginx: `real_ip_header CF-Connecting-IP` от `172.28.0.1` и `192.168.65.0/24`, XFF перезаписывается `$remote_addr`, порт опубликован как `127.0.0.1:80:80`.
- Ключ IP: для IPv4 — адрес, для IPv6 — его /64.
- login/setup и всё под их префиксами (единый `_classify`):
  - потолок на IP `4×` лимит auth проверяется до чтения тела;
  - затем потолок и ключ `(IP, username)` проверяются и учитываются атомарно под одним локом;
  - тело читается только при `Content-Length ≤ 4096`.
- refresh: ключ `(sub, IP)`; при невалидном токене — IP.
- Общий хелпер `app/auth/request_tokens.py` (cookie → тело, `sub`) используют и роутер, и лимитер.
- Память: `MAX_KEYS = 10_000` с вытеснением холодных ключей; уборка с холодного конца; окно — константа `WINDOW_SECONDS`.

### 2. Файлы
- Новый: `backend/app/auth/request_tokens.py`.
- Изменены: `backend/app/auth/{service,router}.py`, `backend/app/middleware/rate_limit.py`, `docker-compose.yml`, `Dockerfile.backend`, `nginx.conf`, тесты `test_auth_service.py` и `test_rate_limit.py`.

### 3. Тесты
- RED:
  - исходный — `ValueError: Аккаунт заблокирован` и 5× `assert 429 == 200`;
  - п.2 — `E assert 6 == 1`.
- GREEN:
  - в `test_auth_service` — 2 теста;
  - в `test_rate_limit` — 18 тестов по карточке: proxy-headers через uvicorn `ProxyHeadersMiddleware`, недоверенный пир и шлюз, compose, спрей, `/login/`, IPv6 /64, тело > 4 КБ, не-JSON, refresh по cookie/телу, `(sub, IP)`, вытеснение и уборка.
- Мутации (откачены из бэкапа, md5 сверены):
  - «не сбрасывать счётчик» → `assert user.failed_login_count == 1` (`test_expired_lockout_resets_failed_count`);
  - ранее «убрать IP-потолок» → `assert 200 == 429`.
- Гейты: pytest 3107 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (181); bandit M0/H0. Фронт не менялся.

### 4. Integration points
✅ `router.py:217` `extract_refresh_token`; `rate_limit.py:203-208` хелперы; `:114,129,137` `_classify`/`_check`; `main.py:353`.

### 5. Контракты
API не менялся. Переменная compose `TRUSTED_PROXY_IPS`. Миграции нет.

### 6. Тексты для документов
- **Гайд §3.3**: «Backend: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips="$TRUSTED_PROXY_IPS"`. `TRUSTED_PROXY_IPS` — от кого принимается `X-Forwarded-For`; по умолчанию `172.28.0.10` (фиксированный адрес nginx в сети moex-net `172.28.0.0/24`). Переопределяется в окружении или `.env` compose (IP/CIDR через запятую). При `Pool overlaps` сменить одновременно подсеть `networks.moex-net.ipam`, `ipv4_address` frontend, `TRUSTED_PROXY_IPS` и `set_real_ip_from` в `nginx.conf`».
- **Гайд §5.3**: в `ingress` указать `service: http://127.0.0.1:80`. Далее: «nginx опубликован только на `127.0.0.1:80`. Доступ из LAN (`"80:80"`) — осознанное изменение: придётся править тест `test_compose_trusts_forwarded_for_only_from_nginx` и доверие `CF-Connecting-IP`, иначе клиент сети подделает свой IP для лимитера входа. **Проверка при первом запуске:** открыть сайт через Tunnel и выполнить `docker compose logs frontend | tail`. Первым полем строки запроса должен стоять публичный IP клиента. Если там `172.x`/`192.168.x` — это адрес cloudflared, которому nginx не поверил: добавить его в `set_real_ip_from` (`nginx.conf`) и выполнить `docker compose restart frontend`».
- **ТЗ §7.5**: «login/setup: 5 req/min по (IP, username) и потолок 20 req/min на IP; refresh: 5 req/min по (sub, IP). IP: IPv4 — адрес, IPv6 — /64. IP выставляет uvicorn из `X-Forwarded-For` nginx (доверие только 172.28.0.10); `CF-Connecting-IP` переводит nginx. In-memory, на процесс, не более 10 000 ключей».
- **ФТ §2.1 / §12.1**: «Блокировка запрещает новый вход, но не завершает открытые сеансы. По истечении 15 минут счётчик неудачных попыток обнуляется — снова доступны 5 попыток».
- Риск: Docker не запускался — `nginx -t`, реальный источник cloudflared и конфликт подсети не проверены.

### Ревью-2: исправлено 1–8
1. IPv6 ключуется по /64.
2. Сброс счётчика после истёкшей блокировки.
3. refresh ключуется по `(sub, IP)`.
4. Фиксированный адрес nginx; узкий `set_real_ip_from`.
5. Единый `_classify`; тест на `/login/`.
6. Комментарий в compose про тест и доверие `CF-Connecting-IP`.
7. Хелпер `auth/request_tokens.py`.
8. `WINDOW_SECONDS`; потолок и ключ — под одним локом.

### 7. Stack Gotchas
50, 60. Новых нет.

### 9. Плагины
py_compile, TDD (`mattpocock-skills:tdd`).
