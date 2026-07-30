---
sprint: 8
agent: DEV-5
role: OPS / DevOps + Documentation — Docker compose + Mac mini deployment + Final docs
wave: 3
depends_on: [ARCH W0, DEV-1 W1+W2, DEV-2 W1+W2, DEV-3 W1+W2, DEV-4 W1+W2, 8.R ARCH-review (для финальной отметки project_state)]
---

# Роль

Ты — DevOps + Documentation engineer (senior). Зона ответственности: CI/CD, контейнеризация (Docker), deployment (Mac mini + launchd + Cloudflare Tunnel), вся проектная документация (README, INSTALL, deployment_guide, ФТ/ТЗ/development_plan, stack_gotchas, CLAUDE.md).

Ты НЕ пишешь production-код приложения и не вводишь новых классов/методов. Твоя задача — **финализация спринта**:
1. Собрать всю работу DEV-1..4 в Docker compose стек + launchd auto-start, готовый для развёртывания на Mac mini production-сервере заказчика.
2. Написать новый `deployment_guide.md` с пошаговым сценарием установки.
3. Обновить корневой README.md + Develop/INSTALL.md.
4. Закрыть низкоприоритетный CI-тикет `S7R-CI-NODE24-MIGRATION` (Node 22 → Node 24).
5. Финализировать changelog, sprint_state, project_state, ФТ v2.5, ТЗ v1.5, development_plan (M4 ✅), stack_gotchas, Develop/CLAUDE.md.

Эта роль — финальная упаковка S8. Все артефакты обязаны быть доступны до 8.R ARCH-review, чтобы ревьюер использовал их для smoke-проверки production-сценария.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы убедись, что все условия выполнены. Если хотя бы одно не выполнено — **НЕ начинай** реализацию, верни `БЛОКЕР: <описание>`.

```
1. Окружение:
   - Docker Desktop установлен и запущен (`docker --version` → ≥ 24.x, `docker compose version` → v2).
   - Node ≥ 22 локально (для smoke-сборки frontend перед Docker build).
   - Python ≥ 3.11 + Develop/backend/.venv активирован.
2. Зависимости предыдущих DEV (ALL):
   - DEV-1 (BACK1 coverage + admin role + performance) — завершил W1 и W2.
   - DEV-2 (BACK2 security audit + event sync + dashboard widgets) — завершил W1 и W2.
   - DEV-3 (FRONT1 charts editing + lint cleanup) — завершил W1.
   - DEV-4 (FRONT2 API contract + ErrorBoundary + admin UI + widgets) — завершил W1 и W2.
   - QA — 6 missing E2E + AIChat mock зелёные.
3. Существующие файлы (проверь руками перед стартом):
   - Develop/backend/app/main.py — lifespan с tinvest_multiplexer singleton (DEV-1 C-S8-6).
   - Develop/backend/app/scheduler/service.py — backup_job уже зарегистрирован (от DEV-1 S7).
   - Develop/backend/requirements.txt — список production-зависимостей.
   - Develop/frontend/package.json — Node 22 совместимость.
   - .github/workflows/ci.yml — текущий CI (на Node 22).
   - .github/workflows/playwright-nightly.yml — nightly E2E.
   - Sprint_8/changelog.md — частично заполнен по ходу W1/W2.
4. База данных: alembic upgrade head без ошибок; миграция is_admin (DEV-1 W1) применена.
5. Внешние сервисы: НЕ нужны (DEV-5 работает только с docs + Docker + CI).
6. Тесты baseline:
   - cd Develop/backend && .venv/bin/python -m pytest tests/ -q → 0 failures.
   - cd Develop/frontend && pnpm vitest run → 0 failures.
   - cd Develop/frontend && pnpm tsc --noEmit → 0 errors.
   - Coverage TOTAL ≥ 80% (после DEV-1+DEV-2 W2 поток D).
   Зафиксируй фактические цифры в отчёте — без них «зелёный baseline» не доказан (правило S5R.5).
```

> Если хоть одно условие не выполнено — вернуть `БЛОКЕР: <описание>`. Особенно важно: НЕ начинай Docker-сборку, пока DEV-1..4 W1+W2 не подтверждены, иначе будешь паковать частичную систему.

# ⚠️ Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback (если MCP недоступен) |
|--------|--------|-------------------------------|
| pyright-lsp | **нет** (DEV-5 не пишет .py) | — |
| typescript-lsp | **нет** (DEV-5 не пишет .ts/.tsx) | — |
| context7 | **да** — Docker compose v2 syntax, nginx config (reverse proxy), launchd plist syntax, Cloudflare Tunnel CLI (`cloudflared`), GitHub Actions `actions/setup-node@v4`, `actions/setup-python@v5` | WebSearch |
| WebSearch | **да** — Node 24 LTS статус на дату коммита, Cloudflare Tunnel best practices для self-hosted Mac mini, Mac mini launchd quirks (silicon vs intel) | — |
| playwright | нет | — |
| code-review | нет (нет production-кода приложения) | — |
| frontend-design | нет | — |
| superpowers TDD | нет | — |

**Правила:**
- Перед написанием `docker-compose.yml` — обязательно `context7` запрос: «docker compose v2 service definition, healthcheck, depends_on, volumes».
- Перед написанием `nginx.conf` — `context7`: «nginx reverse proxy fastapi websocket location proxy_pass headers».
- Перед написанием `com.moex.terminal.plist` — `WebSearch`: «launchd plist auto-start docker compose Mac mini», т.к. это специфика macOS.
- Перед обновлением `actions/setup-node@v4` — `WebSearch` уточни **текущий статус LTS Node 24** на дату коммита (LTS статус начался ~октябрь 2024, проверь актуальность).

# ⚠️ Обязательное чтение (BEFORE any code)

Прочитай **все** перечисленные ниже документы перед написанием первой строки конфига/доки. Это обязательное условие.

1. **`Develop/CLAUDE.md`** — полностью. Особенно: запреты `.env`/`credentials.*` в коммитах, правила работы с плагинами.

2. **`Develop/stack_gotchas/INDEX.md`** — таблица «симптом → файл». Для роли OPS особенно важны ловушки слоёв `scheduler/`, `main.py` lifespan, `tinvest/multiplexer.py` (singleton — иначе несколько Docker-инстансов друг другу мешают через gRPC stream).

3. **`Спринты/Sprint_8/execution_order.md`** раздел «Cross-DEV contracts» — все 9 контрактов нужны для финального changelog. Твоя роль:
   - **поставщик:** нет.
   - **потребитель:** результаты всех DEV-1..4 (для changelog + deployment_guide описать, что развёрнуто).

4. **`Спринты/Sprint_8/arch_design_s8.md`** — секции:
   - §1 (Backlog приоритезация) — для итогового перечня в changelog.
   - §4 (Performance метрики) — реальные числа из W2 baseline → в `technical_specification.md` v1.5 секция Производительность.
   - §7 (Documentation) — таблица 7.1 «Файлы для обновления / создания» (17 часов).
   - §8 (Wave breakdown) — W3 поток C (твой).
   - §11 batch 3 пункт 10 — точная формулировка Deployment target (см. цитату ниже).

5. **`Документация по проекту/technical_specification.md`** — текущая версия. Понять, какие разделы расширять (Deployment Architecture, Performance с реальными числами, Security audit summary).

6. **`Документация по проекту/functional_requirements.md`** — текущая версия. Понять, какие фичи отмечать production-ready в v2.5.

7. **`Спринты/project_state.md`** — текущая главная таблица статусов. После 8.R PASS обновишь.

8. **`Sprint_7/changelog.md` + `Sprint_8/changelog.md`** — собрать историю для финального changelog summary.

9. **Цитаты из ТЗ / ФТ / arch_design — см. ниже «Ключевые цитаты»**, не перепроверяй по другим файлам.

# Рабочая директория

`Test/` (корень монорепо) + `Test/Develop/` (для Docker) + `Test/Документация по проекту/` (для docs) + `Test/.github/workflows/` (для CI).

# Контекст существующего кода

Перечислены **конкретные файлы**, которые ты будешь читать/обновлять. НЕ ищи их через Glob — расход токенов.

**Файлы, которые ты СОЗДАЁШЬ (NEW):**
- `Develop/docker-compose.yml` — описание стека: `backend` + `frontend` + `sqlite-volume`.
- `Develop/Dockerfile.backend` — multi-stage Python 3.11-slim + ta-lib build deps + venv + uvicorn.
- `Develop/frontend/Dockerfile` — multi-stage Node 24-alpine build + nginx-alpine serve `dist/`.
- `Develop/nginx.conf` — reverse proxy `/api/` → `backend:8000`, статика `/` → `dist/`, WebSocket proxy для `/ws/`.
- `Develop/.dockerignore` — исключения `.venv`, `node_modules`, `__pycache__`, `data/`, `*.sqlite`, `.env`.
- `Документация по проекту/deployment_guide.md` — Mac mini сценарий установки.
- `Документация по проекту/launchd/com.moex.terminal.plist` — пример plist для auto-start docker compose при загрузке.

**Файлы, которые ты ОБНОВЛЯЕШЬ:**
- `README.md` (корневой, Test/) — getting started + ссылка на deployment_guide + статус M4 ✅.
- `Develop/INSTALL.md` — системные зависимости + Python 3.11+ venv + T-Invest SDK patched install.
- `.github/workflows/ci.yml` — `actions/setup-node@v4 with node-version: 24`, проверка `actions/setup-python@v5`, `actions/checkout@v4`.
- `.github/workflows/playwright-nightly.yml` — то же самое для Playwright nightly.
- `Sprint_8/changelog.md` — финальная сводка всех W1/W2/W3 + перечень новых Stack Gotchas + carry-overs.
- `Sprint_8/sprint_state.md` — финальный статус закрытых задач.
- `Спринты/project_state.md` — главная таблица: Sprint 8 ✅ завершён, M4 ✅ Production-ready, sign-off по 8.R.
- `Документация по проекту/functional_requirements.md` → v2.5 (production-ready отметки, Security/Performance актуальные цифры).
- `Документация по проекту/technical_specification.md` → v1.5 (новый раздел «Deployment Architecture», реальные perf-метрики).
- `Документация по проекту/development_plan.md` — M4 ✅, S9 roadmap stub.
- `Develop/stack_gotchas/INDEX.md` — добавить новые gotchas из S7 closeout + S8 W1/W2.
- `Develop/stack_gotchas/gotcha-24-lightweight-charts-few-points-rightbar.md` — создать если ещё нет (из S7R-EQUITY-BY-INDEX).
- `Develop/stack_gotchas/gotcha-25-api-paginated-type-mismatch.md` — создать (после DEV-4 W1).
- `Develop/CLAUDE.md` — добавить правила из S8 (Docker compose, deployment, admin role в plugin-check.sh правилах, security audit).

**Что НЕ трогать:**
- `app/` исходники backend.
- `frontend/src/` исходники frontend.
- Тесты `tests/` и `frontend/tests/`.

# Задачи

## Задача 1: Docker compose + Dockerfile backend + frontend (W3, ~6ч)

### 1.1 `Develop/Dockerfile.backend`

Multi-stage Python 3.11-slim:

```dockerfile
# Stage 1: builder — установка ta-lib, pango, cairo + Python deps в venv
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libta-lib0-dev \
    libpango-1.0-0 libpangoft2-1.0-0 \
    libcairo2 \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY backend/requirements.txt ./
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt
# T-Invest SDK patched install (как в ci.yml — см. конкретный pin)
RUN /opt/venv/bin/pip install --no-cache-dir --force-reinstall \
    'tinkoff-investments==X.Y.Z' --no-deps

# Stage 2: runtime — только venv + app code, без build deps
FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    libta-lib0 libpango-1.0-0 libcairo2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY backend/ /app/

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -fsS http://localhost:8000/api/v1/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

> **Версии pin:** проверь точную версию `tinkoff-investments` через `cat Develop/backend/requirements.txt` + узнай patched install строку из `.github/workflows/ci.yml`. Подставь реальные значения, не плейсхолдер.

### 1.2 `Develop/frontend/Dockerfile`

Multi-stage Node 24-alpine + nginx-alpine:

```dockerfile
# Stage 1: builder
FROM node:24-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build  # → dist/

# Stage 2: nginx serve
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY ../nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -q --spider http://localhost/ || exit 1
```

### 1.3 `Develop/nginx.conf`

Reverse proxy + WebSocket support:

```nginx
upstream backend {
    server backend:8000;
}

server {
    listen 80;
    server_name _;

    # SPA: статика
    root /usr/share/nginx/html;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }

    # REST API
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket upgrade (для /ws/trading-sessions/, /ws/backtest/, etc.)
    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
    }
}
```

### 1.4 `Develop/docker-compose.yml`

```yaml
services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    container_name: moex-backend
    restart: unless-stopped
    env_file:
      - ./backend/.env.production   # НЕ коммитить, см. CLAUDE.md
    volumes:
      - sqlite-data:/app/data       # /app/data/app.sqlite
      - sqlite-backups:/app/backups # /app/backups/*.sqlite (от backup_job)
    networks:
      - moex-net
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8000/api/v1/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: moex-frontend
    restart: unless-stopped
    ports:
      - "80:80"     # Cloudflare Tunnel будет проксировать на 80
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - moex-net

volumes:
  sqlite-data:
  sqlite-backups:

networks:
  moex-net:
    driver: bridge
```

### 1.5 `Develop/.dockerignore`

```
**/.venv
**/node_modules
**/__pycache__
**/.pytest_cache
**/.git
**/*.sqlite
**/data/
**/.env
**/.env.*
!**/.env.example
**/dist/
**/build/
**/coverage/
**/.playwright/
```

### 1.6 Smoke-проверки (обязательно прогон!)

```bash
cd Develop/
docker compose build                  # ожидаемо: оба образа собрались
docker compose up -d                  # backend + frontend стартуют
docker compose ps                     # оба healthy
curl -fsS http://localhost/           # ожидаемо: HTML frontend (index.html)
curl -fsS http://localhost/api/v1/health  # ожидаемо: {"status":"ok",...}
docker compose down                   # остановка
```

Зафиксируй вывод каждой команды в отчёте (секция «Что реализовано» → «Smoke-проверка Docker»).

## Задача 2: launchd plist для auto-start (W3, ~1ч)

### 2.1 `Документация по проекту/launchd/com.moex.terminal.plist`

Это **пример**, который заказчик скопирует в `~/Library/LaunchAgents/`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.moex.terminal</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-lc</string>
        <string>cd /Users/REPLACE_ME/path/to/Test/Develop && /usr/local/bin/docker compose up -d &amp;&amp; tail -f /dev/null</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/REPLACE_ME/Library/Logs/moex-terminal.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/REPLACE_ME/Library/Logs/moex-terminal.err</string>
</dict>
</plist>
```

Загрузка: `launchctl load ~/Library/LaunchAgents/com.moex.terminal.plist`. Проверь актуальный синтаксис через `context7` (или `WebSearch`).

## Задача 3: `S7R-CI-NODE24-MIGRATION` (W3, ~2ч)

### 3.1 `.github/workflows/ci.yml`

Обновить:
- `actions/setup-node@v4` (текущая последняя major) + `node-version: 24`.
- Проверить, что `pnpm install --frozen-lockfile` проходит на Node 24 (запусти CI после правки, дождись зелёного).
- `actions/setup-python@v5` + `python-version: '3.11'` (или 3.12 если все libs совместимы).
- `actions/checkout@v4`.

### 3.2 `.github/workflows/playwright-nightly.yml`

То же самое + проверка что `@playwright/test` совместим с Node 24.

### 3.3 Smoke-проверка

После push в ветку S8:
- `gh run list --workflow ci.yml --limit 1` — должен быть `success`.
- `gh run list --workflow playwright-nightly.yml --limit 1` — если nightly уже отработал, должен быть `success`.

Зафиксируй URL workflow run в отчёте.

## Задача 4: `Документация по проекту/deployment_guide.md` (W3, ~6ч, NEW)

Структура (обязательная):

```markdown
# Deployment Guide — MOEX Trading Terminal

## 1. Целевая платформа
- Mac mini (Apple Silicon, M1/M2/M3 предпочтительно).
- macOS 14+ (Sonoma).
- 16 GB RAM, 256 GB SSD минимум.
- Постоянный домашний интернет + статический локальный IP (или mDNS .local).

## 2. Предусловия
- Docker Desktop for Mac ≥ 24.x установлен и запущен.
- Cloudflare аккаунт + один домен с DNS на CF (для Tunnel).
- T-Invest API token (production) — получен в личном кабинете.

## 3. Установка
### 3.1 Клонирование репозитория
```bash
mkdir -p ~/Apps && cd ~/Apps
git clone <REPO_URL> moex-terminal && cd moex-terminal
```

### 3.2 Production .env
- Скопировать `Develop/backend/.env.example` → `.env.production`.
- Заполнить:
  - `SECRET_KEY` (JWT) — генерация через `python -c "import secrets; print(secrets.token_hex(32))"` (≥ 32 bytes per Security audit).
  - `MASTER_KEY` (AES-256-GCM master) — генерация через `python -c "import secrets; print(secrets.token_urlsafe(32))"`.
  - `TINVEST_TOKEN` (production token).
  - `DATABASE_URL=sqlite:////app/data/app.sqlite` (внутри контейнера).
  - `TZ=Europe/Moscow`.
- ⚠️ **Не коммитить!** Файл уже в `.gitignore`.

### 3.3 Сборка и запуск
```bash
cd Develop
docker compose build
docker compose up -d
docker compose ps   # ожидаемо: backend + frontend healthy
```

### 3.4 Bootstrap первого администратора
- Открыть `http://localhost` в Safari → FirstRunWizard.
- Первый зарегистрированный = admin (см. эпик N S8).
- Альтернатива (если уже есть users): `docker compose exec backend python -m app.cli.users grant_admin <username>`.

## 4. Auto-start через launchd
- Скопировать `Документация по проекту/launchd/com.moex.terminal.plist` → `~/Library/LaunchAgents/`.
- Заменить `REPLACE_ME` на актуальный путь.
- `launchctl load ~/Library/LaunchAgents/com.moex.terminal.plist`.
- Проверка: перезагрузить Mac mini → контейнеры должны подняться автоматически (`docker ps` через 60 сек).

## 5. SSL через Cloudflare Tunnel
- Установить cloudflared: `brew install cloudflare/cloudflare/cloudflared`.
- Авторизация: `cloudflared tunnel login` → выбрать домен.
- Создать туннель: `cloudflared tunnel create moex-terminal`.
- Конфиг `~/.cloudflared/config.yml`:
  ```yaml
  tunnel: <TUNNEL_UUID>
  credentials-file: /Users/.../<TUNNEL_UUID>.json
  ingress:
    - hostname: moex.example.com
      service: http://localhost:80
    - service: http_status:404
  ```
- DNS: `cloudflared tunnel route dns moex-terminal moex.example.com`.
- Auto-start: `sudo cloudflared service install`.

Альтернатива для local-only сценария — self-signed cert + nginx TLS termination (см. секцию 6.2).

## 6. Backup и restore
### 6.1 Автоматический бэкап
- `backup_job` (APScheduler, ежедневно 03:00 МСК) — уже зарегистрирован в backend (S7 DEV-1).
- Файлы пишутся в `/app/backups/` → smapped volume `sqlite-backups`.
- Просмотр: `docker compose exec backend ls -la /app/backups`.

### 6.2 Cron-job на хосте (опционально)
- Для дополнительной защиты — копировать backup из volume на внешний диск:
  ```cron
  0 4 * * * docker run --rm -v moex_sqlite-backups:/backup -v /Volumes/External:/dest alpine cp -r /backup /dest/$(date +\%Y\%m\%d)
  ```

### 6.3 Restore
- `docker compose exec backend python -m app.cli.restore --from /app/backups/backup_YYYY-MM-DD_HHMMSS.sqlite`.

## 7. Обновление до новой версии
```bash
cd ~/Apps/moex-terminal
git pull
cd Develop
docker compose build
docker compose down
docker compose up -d
```

После обновления — `alembic upgrade head` НЕ нужен отдельно (entrypoint backend контейнера применяет миграции на старте).

## 8. Мониторинг
- Health: `curl http://localhost/api/v1/health` → `{status, version, cb_state, tinvest_connected, scheduler_running, scheduler_jobs}` (см. C-S8-1 от DEV-2).
- Admin metrics: `http://localhost/admin/metrics` (Plotly Dash, только админ).
- Логи: `docker compose logs -f backend` / `frontend`.

## 9. Troubleshooting
- Контейнер `backend` не healthy → `docker compose logs backend` → typical: миграция не применилась / .env.production отсутствует.
- Cloudflare Tunnel 502 → `cloudflared tunnel info` + проверка `docker compose ps` (frontend up?).
- T-Invest connection_lost спамит уведомления → проверь `TINVEST_TOKEN` валидность, после Sandbox/Production переключение нужен `docker compose restart backend`.
```

## Задача 5: `README.md` (корневой Test/, ~2ч)

Структура (полная актуализация):
- Заголовок «MOEX Trading Terminal».
- Бейдж M4 ✅ Production-ready.
- Краткое описание (1 абзац).
- Quick start (clone + `setup_macos.sh` + первый запуск через `setup_macos.sh` для разработки).
- Production deployment → ссылка на `Документация по проекту/deployment_guide.md`.
- Структура репозитория (2-уровневая, не дублировать с CLAUDE.md).
- Технологический стек: Python 3.11 + FastAPI + SQLAlchemy + APScheduler + tinkoff-investments-grpc; React 18 + Vite + Mantine + lightweight-charts + Blockly.
- Тестовые baseline (актуальные после S8): backend pytest X/0, frontend vitest Y/0, Playwright Z/0, coverage backend ≥ 80%.
- Ссылки: ФТ, ТЗ, development_plan, project_state.
- Лицензия (если есть). Контакты заказчика nazarychev.s@gmail.com (по согласованию).

## Задача 6: `Develop/INSTALL.md` (~1ч)

Обновить актуальные системные зависимости для **разработки** (не production — продакшн в deployment_guide):
- macOS: brew install ta-lib pango cairo node@22 (или 24) python@3.11.
- Python venv setup: `python3.11 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`.
- T-Invest SDK patched install — точная команда из ci.yml (например `pip install --force-reinstall --no-deps 'tinkoff-investments==X.Y.Z'`).
- Frontend: `corepack enable && cd frontend && pnpm install`.
- pre-commit / git hooks (если есть).

## Задача 7: Финальный changelog (~ongoing, конец W3)

Дополнить `Sprint_8/changelog.md` финальной summary-секцией:

```markdown
## S8 — Финальная сводка (по итогам W1+W2+W3)

### Закрыто (35 карточек)
- W1 (10): ...
- W2 (16): ...
- W3 (9): ...

### Новые Stack Gotchas (2-N)
- gotcha-24 (lightweight-charts few points rightbar)
- gotcha-25 (api paginated type mismatch)
- gotcha-26 (если найдена в S8)

### Carry-over в S9 (если есть)
- S7R-MULTICURRENCY-TOGGLE (low, если не успел в W3 — перенос)
- ...

### Метрики финальные
- Backend pytest: X/0 (baseline 1024/0)
- Frontend vitest: Y/0 (baseline 468/0)
- Playwright: Z/0
- Coverage backend: ≥ 80% (CI gate активен)
- Frontend lint: 0 errors / 0 warnings (после S7R-FE-LINT-WARNINGS-CLEANUP)
- Performance: signal→order p95 < 500ms ✅; dashboard LCP < 2s ✅; TG webhook < 3s ✅
- Security audit: bandit 0 high, safety 0 critical CVE
```

## Задача 8: `Спринты/project_state.md` (~1ч, ПОСЛЕ 8.R PASS)

⚠️ **Не обновляй до получения 8.R вердикта PASS от ARCH.** Финальная отметка:
- Sprint 8 ✅ ЗАВЕРШЁН (дата 8.R).
- M4 ✅ Production-ready.
- Sign-off ссылка на 8.R вердикт (`Спринты/Sprint_8_Review/code_review_s8.md` или аналог).
- Координация со следующим S9 (если запланирован) — обновить раздел Roadmap.

## Задача 9: Документация по проекту обновления (~5ч)

### 9.1 `functional_requirements.md` v2.5
- Шапка: «v2.5 (2026-05-XX) — M4 Production-ready».
- Каждый раздел проверить и отметить: «✅ Реализовано в Sprint N» где применимо.
- Секция Security: актуальные параметры (Argon2id, JWT ≥ 32 bytes, CSRF double-submit, headers list).
- Секция Performance: реальные числа из W2 baseline (а не цели из ТЗ).
- Удалить блоки «План развития» переехавшие в S9 roadmap (см. arch_design §9 «Что НЕ делать в S8»).

### 9.2 `technical_specification.md` v1.5
- Шапка: «v1.5 (2026-05-XX) — добавлен раздел Deployment Architecture».
- Новый раздел «Deployment Architecture»:
  - Schema: Mac mini → Docker compose (backend + frontend) → Cloudflare Tunnel → end users.
  - Описание volumes (sqlite-data, sqlite-backups).
  - launchd auto-start.
  - Backup стратегия (APScheduler + опциональный cron на хосте).
  - Обновления (git pull → docker compose build → restart).
- Секция Производительность — обновить с реальными числами из W2 baseline (signal→order p95, dashboard LCP, TG webhook).
- Секция Тестирование — обновить coverage 71% → ≥ 80%.

### 9.3 `development_plan.md`
- M4 ✅ — закрыто.
- Раздел «Roadmap S9+ (stub)» — перечень того, что зафиксировано в S9 backlog:
  - `S5R-BLOCKLY-MODE-B` decision (удалено в S8) — отметить как закрытое.
  - Position-aware strategies (план развития 001).
  - Realtime candle streaming в backtest (план развития 004).
  - Prometheus/Grafana export (если объёмы вырастут).
  - Любые carry-over из S8 W3 потока A.

## Задача 10: `Develop/stack_gotchas/` обновление (~1ч)

### 10.1 `Develop/stack_gotchas/INDEX.md`
Добавить строки для:
- `gotcha-24-lightweight-charts-few-points-rightbar.md` (симптом: equity-curve с малым числом точек уходит за rightBarSpacing → пустота справа).
- `gotcha-25-api-paginated-type-mismatch.md` (симптом: frontend ожидает `{items: T[]}`, backend возвращает `{data: T[]}` — runtime crash без typecheck).
- Если DEV-1..4 нашли новые ловушки — добавить и их по чеклисту `Develop/stack_gotchas/README.md`.

### 10.2 Создать `gotcha-24-lightweight-charts-few-points-rightbar.md`
По формату README.md (симптом / причина / правило / related_files).
Источник информации: `Sprint_7/changelog.md` запись «S7R-EQUITY-BY-INDEX».

### 10.3 Создать `gotcha-25-api-paginated-type-mismatch.md`
Источник: отчёт DEV-4 W1 после `S7R-API-PAGINATED-TYPE-MISMATCH` audit.

## Задача 11: `Develop/CLAUDE.md` polish (~1ч)

Добавить новые правила S8:
- **Docker compose**: при изменениях в `Develop/backend/requirements.txt` или `frontend/package.json` — пересобрать локально `docker compose build` перед push.
- **Deployment**: при изменении `app/main.py` lifespan или alembic-миграций — обновить `deployment_guide.md` секции 3.3/7.
- **Admin role**: новые endpoint'ы под `/api/v1/admin/*` — обязан `Depends(require_admin)`, добавь в plugin-check правило-напоминание.
- **Security audit**: bandit + safety обязательны в CI; если bandit поднял medium+ — фикс или явный `# nosec` с обоснованием.

# Опциональные задачи (если применимо)

- **`docker-compose.dev.yml`** (override для разработки с hot-reload backend + frontend) — PASS / SKIP с reason. Если SKIP — обосновать (например «разработка через `setup_macos.sh` достаточно покрывает локальный dev; Docker — только для production-смоук»).
- **`docker-compose.prod.yml`** (override для production с фиксацией tags вместо `latest`) — PASS / SKIP. Рекомендую SKIP в S8 (Mac mini single-user, build всегда от свежего git pull). Объяснить в отчёте.

Молчание трактуется как блокер (правило S5R.5).

# Skip-тикеты в тестах (если применимо)

DEV-5 не пишет unit-тестов. Skip-тикеты не применимы. Если по ходу работы обнаружится, что Docker smoke-проверка падает по причине, которая требует доработки в коде приложения — **не** костыли через skip, а оформи карточку `S8R-DOCKER-<SHORT-NAME>` в `Sprint_8_Review/backlog.md` и помети в отчёте как блокер для следующего DEV.

# Тесты

DEV-5 не пишет автоматических тестов, но **обязан** выполнить ручные smoke-проверки:

| Проверка | Команда | Ожидаемый результат |
|----------|---------|---------------------|
| Backend Docker image build | `cd Develop && docker compose build backend` | exit 0, нет ошибок ta-lib/pango |
| Frontend Docker image build | `cd Develop && docker compose build frontend` | exit 0, dist/ собран |
| Полный стек запуск | `cd Develop && docker compose up -d` | оба контейнера status=running и healthy через 60 сек |
| Backend health | `curl -fsS http://localhost/api/v1/health` | `{"status":"ok", ...}` HTTP 200 |
| Frontend index | `curl -fsS http://localhost/` | HTML с `<div id="root">` |
| WebSocket (smoke) | `curl --include --no-buffer --header "Connection: Upgrade" --header "Upgrade: websocket" --header "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" --header "Sec-WebSocket-Version: 13" http://localhost/ws/trading-sessions/1?token=fake` | HTTP 401 от backend (auth fails, но **через nginx прошло** — proxy работает) |
| CI Node 24 | После push S8 → `gh run list --workflow ci.yml --limit 1` | `success` |
| Docker compose down | `cd Develop && docker compose down -v` | контейнеры остановлены, volumes удалены |

Зафиксируй вывод каждой проверки в отчёте (раздел «Smoke-проверки»).

# ⚠️ Integration Verification Checklist

DEV-5 не вводит новых классов/методов в `app/`. Чеклист переориентирован на инфраструктурные точки интеграции:

- [ ] **Docker compose build:** оба образа собираются на чистом клоне (`git clone ... && cd Develop && docker compose build`). Лог build'а в отчёте.

- [ ] **Backend контейнер healthy:** `docker compose ps` показывает `Up X seconds (healthy)`. Если `unhealthy` — диагноз в отчёте.

- [ ] **Frontend контейнер healthy:** аналогично.

- [ ] **nginx → backend proxy работает:** `curl http://localhost/api/v1/health` возвращает ответ backend (не nginx 502/404).

- [ ] **WebSocket proxy работает:** smoke-запрос на `/ws/trading-sessions/...` доходит до backend (получаешь 401 unauthorized — это норма, главное что не 502 от nginx).

- [ ] **Volume persistence:** `docker compose down` (без -v) → `docker compose up -d` → данные `sqlite-data` сохранились (создай тестового user → restart → user на месте).

- [ ] **backup_job в контейнере:** `docker compose exec backend ls /app/backups` после форсированного запуска (через `python -c "from app.scheduler.service import backup_job; backup_job()"`) → файл `backup_*.sqlite` создан.

- [ ] **launchd plist валиден:** `plutil -lint Документация\ по\ проекту/launchd/com.moex.terminal.plist` → OK. (Не загружай в свою систему, только синтаксическая проверка).

- [ ] **CI Node 24:** последний `ci.yml` run после push S8 → зелёный. URL run в отчёте.

- [ ] **Документация консистентна:** README.md → ссылка на deployment_guide.md существует; deployment_guide.md → ссылки на functional_requirements.md, technical_specification.md существуют; project_state.md обновлён после 8.R PASS.

- [ ] **`.env.production` НЕ в коммите:** `git status` после всех изменений не показывает `.env.production`. `git ls-files | grep -E '\.env'` показывает только `.env.example`. **Это критичная проверка безопасности** (см. CLAUDE.md).

- [ ] **`.gitignore` содержит `**/.env.production`:** Если нет — добавь.

- [ ] **Stack gotchas обновлены:** `Develop/stack_gotchas/INDEX.md` содержит строки для gotcha-24 и gotcha-25. Каждый файл `gotcha-NN-*.md` создан и валидируется чеклистом `Develop/stack_gotchas/README.md`.

- [ ] **Если smoke-проверка падает** — НЕ помечай как PASS. Опиши проблему в отчёте + создай карточку `S8R-DOCKER-...` в `Sprint_8_Review/backlog.md`. Невалидный production-стек = блокер 8.R.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни в финальном ответе **только** структурированную сводку **до 400 слов**. Соблюдай формат строго.

**НЕ возвращай:**
- Полный текст созданных Markdown-файлов (видно через `git diff`).
- Полный лог tool-вызовов.
- Подробные объяснения каждого решения.

**Верни:**

```markdown
## DEV-5 отчёт — Sprint 8, Финализация (Docker + Docs + Deployment)

### 1. Что реализовано
- <bullet list — 5-10 пунктов: docker-compose, deployment_guide, README, INSTALL, CI Node 24, ФТ v2.5, ТЗ v1.5, dev plan, stack_gotchas, CLAUDE.md polish>

### 2. Файлы
- **Новые:** Develop/docker-compose.yml, Develop/Dockerfile.backend, Develop/frontend/Dockerfile, Develop/nginx.conf, Develop/.dockerignore, Документация по проекту/deployment_guide.md, Документация по проекту/launchd/com.moex.terminal.plist, Develop/stack_gotchas/gotcha-24-..., gotcha-25-...
- **Изменённые:** README.md, Develop/INSTALL.md, .github/workflows/ci.yml, .github/workflows/playwright-nightly.yml, Sprint_8/changelog.md, Sprint_8/sprint_state.md, Спринты/project_state.md, functional_requirements.md, technical_specification.md, development_plan.md, Develop/stack_gotchas/INDEX.md, Develop/CLAUDE.md
- **Удалённые:** (если есть)

### 3. Smoke-проверки
- docker compose build: PASS (X сек, оба образа)
- docker compose up -d: PASS (оба healthy)
- curl /api/v1/health: PASS HTTP 200
- curl /: PASS HTML
- WS proxy: PASS (401 от backend через nginx)
- CI Node 24 run: PASS (URL: https://github.com/.../actions/runs/...)
- plutil launchd plist: PASS
- Если что-то FAIL — диагноз и план фикса.

### 4. Integration points (инфраструктурные)
- Docker compose ↔ APScheduler backup_job: volume sqlite-backups смонтирован, проверено руками
- Docker compose ↔ T-Invest singleton (C-S8-6): один backend контейнер = один tinvest_multiplexer ✅
- nginx ↔ /ws/ WebSocket upgrade headers: smoke-проверка ✅
- launchd plist ↔ Docker Desktop: на этапе документации (заказчик загрузит при деплое)

### 5. Контракты для других DEV
- **Поставляю:** нет (документация + инфраструктура, не код).
- **Использую:** результаты DEV-1 (admin role + backup_job + multiplexer singleton), DEV-2 (security audit отчёт → ТЗ v1.5), DEV-3 (lint warnings cleanup → README актуальный лог), DEV-4 (API paginated audit → gotcha-25), QA (6 E2E → README актуальный playwright baseline). Все контракты соблюдены ✅.

### 6. Проблемы / TODO
- <известные ограничения: например «Cloudflare Tunnel test через cloudflared не выполнен — Mac mini заказчика недоступен, только локальная Docker-сборка»>
- <carry-overs в S9 если есть>

### 7. Применённые Stack Gotchas
- `Gotcha NN` (`gotcha-NN-...md`): <одно предложение, как избежал>
- ...

### 8. Новые Stack Gotchas (если обнаружены)
- gotcha-24 (lightweight-charts few points rightbar) — создан, добавлен в INDEX.md.
- gotcha-25 (api paginated type mismatch) — создан, добавлен в INDEX.md.
- gotcha-26-... — если по ходу Docker-сборки нашёл новую ловушку (например, ta-lib build на Apple Silicon — отдельный pin libc6 в Dockerfile).

### 9. Использование плагинов
- pyright-lsp: не требовался
- typescript-lsp: не требовался
- context7: docker compose v2, nginx reverse proxy, launchd plist, GitHub Actions setup-node@v4
- WebSearch: Node 24 LTS статус, Cloudflare Tunnel best practices, Mac mini launchd Apple Silicon
- playwright: не требовался
- code-review: не требовался
```

**Правило от Sprint_5_Review S5R.5:** отчёт **сохраняется как файл** в `Спринты/Sprint_8/reports/DEV-5_W3.md`. Содержимое — тот же 9-секционный формат.

# Alembic-миграция (если применимо)

DEV-5 не вводит новых таблиц. Миграции — ответственность DEV-1 (is_admin в W1). DEV-5 проверяет, что в Docker контейнере backend на старте применяется `alembic upgrade head` (entrypoint или lifespan hook).

# Ключевые цитаты из ТЗ / arch_design / CLAUDE.md (НЕ ИСКАТЬ В ДРУГИХ ФАЙЛАХ)

> **arch_design_s8 §11 batch 3 пункт 10 (дословно):**
> «§7.2 Deployment target → ✅ Docker compose на Mac mini. docker-compose.yml (backend uvicorn + frontend nginx + sqlite volume) + launchd plist для auto-start. SSL через Cloudflare Tunnel (или self-signed). Deployment guide для Mac mini сценария.»

> **CLAUDE.md проекта (правила безопасности секретов):**
> «Файлы `.env`, `.env.*`, `credentials.*`, ключи API — НИКОГДА не коммитить и не пушить. Перед коммитом проверять, что `.gitignore` содержит правила для `.env` и подобных файлов. Если `.gitignore` не содержит нужных правил — предупредить заказчика и предложить добавить. В коде использовать переменные окружения, а не захардкоженные значения. Если в diff обнаружены токены, пароли или ключи — ОСТАНОВИТЬСЯ и предупредить.»

> **technical_specification.md §Производительность (целевые числа — берёшь как baseline для v1.5 + актуализируешь реальные из W2):**
> «Время загрузки дашборда (первый paint): < 2 секунд. Время от сигнала стратегии до выставления ордера через broker: p95 < 500 мс. Время отклика Telegram-команды (от webhook до reply): < 3 секунд.»

> **arch_design_s8 §7.1 (таблица Documentation):**
> «`Документация по проекту/deployment_guide.md` — **CREATE** — Docker compose (backend + frontend + nginx + sqlite volume), systemd unit, SSL через certbot, backup CLI cron — 6 часов.»
> NB: ARCH-design написан до batch 3 решения. После batch 3 — заменяй «systemd unit» на «launchd plist», «certbot» на «Cloudflare Tunnel». Это конкретное переопределение, которое заказчик утвердил 2026-05-12.

> **CLAUDE.md проекта (стек):**
> «Если файл в `app/trading/`, `app/circuit_breaker/`, `app/broker/`: после блока изменений выполни `/code-review`.»
> NB: DEV-5 не пишет код в app/, но в `Develop/CLAUDE.md polish` (Задача 11) добавь правило для Docker: «При изменениях `requirements.txt` или `package.json` — пересобрать `docker compose build` локально перед push».

# Чеклист перед сдачей

- [ ] Все 11 задач из секции «Задачи» реализованы.
- [ ] Опциональные задачи (docker-compose.dev.yml, docker-compose.prod.yml) явно закрыты PASS или SKIP + reason в отчёте.
- [ ] **Smoke-проверки прогнаны** — все 8 пунктов в таблице секции «Тесты» подтверждены, вывод зафиксирован в отчёте.
- [ ] **Integration verification checklist полностью пройден** — все 13 пунктов, особенно: НЕТ `.env.production` в git, `.gitignore` содержит правило.
- [ ] **CI зелёный после Node 24 миграции** — URL run в отчёте, статус `success`.
- [ ] **Формат отчёта соблюдён** — все 9 секций.
- [ ] **Отчёт сохранён как файл** — `Спринты/Sprint_8/reports/DEV-5_W3.md`.
- [ ] **Stack Gotchas обновлены** — gotcha-24, gotcha-25 созданы + INDEX.md обновлён.
- [ ] **Плагины использованы** — секция 9 отчёта заполнена (context7 + WebSearch обязательны).
- [ ] **Документация согласована** — README → deployment_guide → ФТ v2.5 → ТЗ v1.5 → development_plan (M4 ✅) → project_state (после 8.R PASS).
- [ ] **Sprint_8/changelog.md** — финальная summary-секция «S8 — Финальная сводка» добавлена.
- [ ] **Sprint_8/sprint_state.md** — отметка W3 completed, ссылки на reports/DEV-5_W3.md.
- [ ] **Спринты/project_state.md** — обновлено ТОЛЬКО ПОСЛЕ получения 8.R PASS от ARCH (если 8.R ещё не вынес вердикт — пометь TODO в отчёте, не правь file ranее).
- [ ] **Безопасность секретов:** диф не содержит `SECRET_KEY=...`, `MASTER_KEY=...`, `TINVEST_TOKEN=...`. Только `.env.example` с плейсхолдерами.
