# Deployment Guide — MOEX Trading Terminal

> **Версия:** v1.0 (2026-05-13, Sprint 8 W3, M4 Production-ready).
> **Целевая платформа:** Mac mini + Docker compose + launchd + Cloudflare Tunnel.
> Утверждено заказчиком 2026-05-12 (arch_design_s8 §7.2, batch 3 п.10).

---

## 1. Целевая платформа

MOEX Trading Terminal — single-user приложение, развёрнутое на личном Mac mini.

| Параметр | Минимум | Рекомендуется |
|---------|---------|---------------|
| Hardware | Mac mini Intel 2018 | Mac mini Apple Silicon (M1/M2/M3) |
| ОЗУ | 8 GB | 16 GB |
| SSD | 256 GB | 512 GB |
| OS | macOS 13 Ventura | macOS 14 Sonoma+ |
| Сеть | Стационарный домашний интернет (≥ 50 Мбит/с) | + UPS на роутер и Mac mini |
| Docker | Docker Desktop ≥ 24.x | Docker Desktop 25+ |

**NB (Apple Silicon):** на M1/M2/M3 контейнеры собираются под `linux/arm64`. Все используемые base-образы (`python:3.11-slim`, `node:24-alpine`, `nginx:alpine`) поддерживают arm64 нативно — Rosetta не требуется.

---

## 2. Предусловия

### 2.1 Установленные локально

- **Docker Desktop for Mac ≥ 24.x** — `docker --version`, `docker compose version`.
- **Git** — для `git pull` обновлений.
- **Homebrew** (рекомендуется) — для `cloudflared`.

### 2.2 Сторонние сервисы

- **Cloudflare аккаунт** — бесплатный, для Tunnel.
- **Домен на Cloudflare DNS** — хотя бы один (можно free `.workers.dev` или купленный).
- **T-Invest API token (production)** — получен в личном кабинете Тинькофф Инвестиций ([T-Invest API tokens](https://www.tinkoff.ru/invest/settings/api/)).
- **Telegram-бот** (опционально) — для notifications: создать через `@BotFather`, получить `BOT_TOKEN` и `chat_id`.

### 2.3 Сетевые требования

- Постоянный IP / DDNS НЕ требуется — Cloudflare Tunnel создаёт исходящий канал.
- Открытые порты НЕ нужны — все соединения исходящие к Cloudflare edge.

---

## 3. Установка

### 3.1 Клонирование репозитория

```bash
mkdir -p ~/Apps && cd ~/Apps
git clone <REPO_URL> moex-terminal && cd moex-terminal
```

> Replace `<REPO_URL>` на актуальный private repo URL.

### 3.2 Production `.env`

```bash
cd Develop
# Шаблон .env.example лежит в корне Develop/; docker-compose (env_file)
# читает production-конфиг из backend/.env.production — туда и копируем.
cp .env.example backend/.env.production
# Откройте `backend/.env.production` и заполните:
```

| Переменная | Назначение | Как получить |
|------------|-----------|--------------|
| `SECRET_KEY` | JWT signing key | `python3 -c "import secrets; print(secrets.token_hex(32))"` (≥ 32 байт, см. Security audit §S8R-SEC-JWT) |
| `ENCRYPTION_KEY` | AES-256-GCM master key для шифрования broker token'ов (**≥ 32 байт**, не начинается с `dev-`) | `python3 -c "import secrets; print(secrets.token_urlsafe(32))"` |
| `TINVEST_TOKEN` | Production T-Invest API token | Личный кабинет T-Invest |
| `DATABASE_URL` | SQLite путь внутри контейнера | `sqlite+aiosqlite:////app/data/app.sqlite` (НЕ менять) |
| `TZ` | Часовой пояс торговли | `Europe/Moscow` (НЕ менять) |
| `TELEGRAM_BOT_TOKEN` | (опционально) Telegram уведомления | `@BotFather` |
| `TELEGRAM_CHAT_ID` | (опционально) ID чата для уведомлений | через bot /start, getUpdates API |

> ⚠️ **`.env.production` НЕ коммитится в git!** Файл уже включён в `.gitignore` (`.env.*`). Перед `git commit` проверьте `git status` — никаких `.env*` в diff не должно быть.

### 3.3 Сборка и запуск Docker compose

```bash
cd ~/Apps/moex-terminal/Develop
docker compose build         # ~5-10 минут на первой сборке (компиляция ta-lib, install node deps)
docker compose up -d
docker compose ps            # должно показать оба сервиса: Up X seconds (healthy)
```

Ожидаемый вывод `ps`:

```
NAME            STATUS                      PORTS
moex-backend    Up 2 minutes (healthy)
moex-frontend   Up 1 minute  (healthy)      0.0.0.0:80->80/tcp
```

Проверка эндпоинтов:

```bash
curl -fsS http://localhost/                  # HTML с <div id="root">
curl -fsS http://localhost/api/v1/health     # {"status":"ok", "cb_state":"closed", ...}
```

### 3.4 Bootstrap первого администратора

При первом запуске backend применяет миграции (`alembic upgrade head`) — таблицы создаются пустыми.

**Вариант A:** через UI.
- Откройте `http://localhost` в Safari/Chrome → `FirstRunWizard` (4 шага).
- Зарегистрируйте первого пользователя — он автоматически получает `is_admin=true` (см. C-S8-7 DEV-1 W1, эпик Admin role).

**Вариант B:** через CLI (если уже есть users без admin'а).
```bash
docker compose exec backend python -m app.cli.users grant_admin <username>
```

---

## 4. Auto-start через launchd

Чтобы контейнеры поднимались автоматически после перезагрузки Mac mini:

```bash
# 1. Скопируйте plist в ~/Library/LaunchAgents/
cp "~/Apps/moex-terminal/Документация по проекту/launchd/com.moex.terminal.plist" \
   ~/Library/LaunchAgents/

# 2. Откройте в редакторе и замените placeholder'ы:
#    __USER__         → ваш macOS username (например, `sergopipo`)
#    __PATH_TO_REPO__ → путь от ~ (например, `Apps/moex-terminal`)
nano ~/Library/LaunchAgents/com.moex.terminal.plist

# 3. Проверка синтаксиса:
plutil -lint ~/Library/LaunchAgents/com.moex.terminal.plist
# Ожидается: "OK"

# 4. Загрузка:
launchctl load -w ~/Library/LaunchAgents/com.moex.terminal.plist

# 5. Проверка статуса:
launchctl list | grep com.moex.terminal
```

Чтобы протестировать auto-start — перезагрузите Mac mini, через 60 секунд после загрузки проверьте `docker compose ps` (должны быть оба контейнера healthy).

**Известный нюанс:** Docker Desktop стартует не моментально после login. Если launchd запустился до Docker — `docker compose up -d` упадёт. KeepAlive=false означает, что launchd попытку не повторит. Workaround: вручную выполнить `docker compose up -d` либо настроить Docker Desktop «Start Docker Desktop when you log in» в Settings.

---

## 5. SSL через Cloudflare Tunnel

Cloudflare Tunnel = исходящий TLS-туннель от Mac mini до Cloudflare edge. Не требует открытых портов на роутере, бесплатен.

### 5.1 Установка cloudflared

```bash
brew install cloudflare/cloudflare/cloudflared
cloudflared --version       # должно быть ≥ 2024.x
```

### 5.2 Авторизация и создание туннеля

```bash
cloudflared tunnel login                              # откроется браузер для подтверждения домена
cloudflared tunnel create moex-terminal               # создаёт ~/.cloudflared/<UUID>.json
cloudflared tunnel route dns moex-terminal moex.example.com  # автоматически добавляет DNS-запись
```

### 5.3 Конфиг `~/.cloudflared/config.yml`

```yaml
tunnel: <TUNNEL_UUID>             # из вывода `cloudflared tunnel create`
credentials-file: /Users/<USER>/.cloudflared/<TUNNEL_UUID>.json

ingress:
  - hostname: moex.example.com
    service: http://localhost:80
  - service: http_status:404      # fallback для прочих hostnames
```

### 5.4 Запуск как macOS service

```bash
sudo cloudflared service install                       # регистрирует launchctl service
sudo launchctl start com.cloudflare.cloudflared        # если не стартует автоматически
```

После этого `https://moex.example.com` будет доступен с любого устройства (TLS термirовался на Cloudflare edge).

### 5.5 Альтернатива: self-signed (local-only сценарий)

Если выход в интернет не нужен — можно ограничиться `http://localhost` или сгенерировать self-signed cert и добавить TLS-секцию в `nginx.conf`. Не рекомендуется для production (предупреждение в браузере, нет Let's Encrypt автоматического обновления).

---

## 6. Backup и restore

### 6.1 Автоматический backup_job

В `app/scheduler/service.py` зарегистрирован `backup_job` (APScheduler, cron daily 03:00 МСК — см. S7 DEV-1). Пишет snapshot SQLite через `sqlite3 .backup` (WAL-safe, см. Gotcha 19) в `/app/backups/backup_YYYY-MM-DD_HHMMSS.sqlite`.

Просмотр:
```bash
docker compose exec backend ls -la /app/backups
```

Файлы переживают `docker compose down` (хранятся в named volume `moex-sqlite-backups`).

### 6.2 Cron на хосте (опционально, для off-site copy)

```cron
# Каждый день в 04:00 копировать backup'ы на внешний диск.
0 4 * * * docker run --rm \
    -v moex-sqlite-backups:/backup:ro \
    -v /Volumes/External:/dest \
    alpine sh -c "mkdir -p /dest/$(date +\%Y\%m\%d) && cp -r /backup/* /dest/$(date +\%Y\%m\%d)/"
```

### 6.3 Restore

```bash
# 1. Скопировать нужный backup в место, доступное контейнеру:
docker compose cp ~/path/to/backup.sqlite backend:/app/data/app.sqlite

# 2. Перезапустить backend (применит миграции если нужно):
docker compose restart backend
```

---

## 7. Обновление до новой версии

```bash
cd ~/Apps/moex-terminal
git pull origin main

cd Develop
docker compose build         # пересобрать образы (только изменившиеся слои)
docker compose down          # без -v — volumes сохраняются
docker compose up -d
docker compose ps            # проверить healthy
```

Миграции `alembic upgrade head` выполняются в entrypoint backend контейнера автоматически — отдельно запускать не нужно.

> **⚠️ Разовая процедура при обновлении до версии с BE-TRAD-06 (денежный учёт paper-портфеля, Model A).**
> До этой версии paper-BUY не списывал `PaperPortfolio.balance` и не блокировал капитал. Позиция, **открытая на старом коде и ещё не закрытая на момент апдейта**, при закрытии на новом коде получит зачисление `proceeds` без парного списания при открытии → `balance` завысится, а `blocked_amount` уйдёт в underflow (безопасно зажимается в 0 с `log.error("paper_blocked_amount_underflow")`). Эффект только на paper, транзиентный (само-исцеляется после одного цикла закрытия), но искажает equity/CB-drawdown для straddle-позиций.
> **Перед обновлением:** закрыть/сбросить открытые paper-сессии (в UI закрыть все позиции активных paper-сессий, либо остановить paper-сессии). Альтернатива — одноразовая реконсиляция БД: `blocked_amount = Σ(volume_rub открытых сделок)`, `balance = initial_capital + Σ(realized pnl)`. Пред-апдейтные значения `balance/blocked_amount` и так были фикцией (см. `Спринты/Code_Review_Full_2026-07/BE_TRAD_06_LOG.md`), поэтому сброс безопасен.

**Rollback** (при провале миграции):
```bash
cd ~/Apps/moex-terminal
git checkout <previous-tag>
cd Develop && docker compose build && docker compose down && docker compose up -d
# Если миграция уже применилась — откатить вручную:
docker compose exec backend alembic downgrade -1
```

---

## 8. Мониторинг

### 8.1 Health endpoint

```bash
curl http://localhost/api/v1/health
```

Возвращает (см. C-S8-1 DEV-2 W2):
```json
{
  "status": "ok",
  "version": "1.0",
  "cb_state": "closed",
  "tinvest_connected": true,
  "scheduler_running": true,
  "scheduler_jobs": ["backup_job", "moex_calendar_refresh_job", ...]
}
```

### 8.2 Admin metrics (`/api/v1/admin/metrics`)

Plotly Dash панель — только для admin role (см. C-S8-9 DEV-4 W2):
- Откройте `http://localhost/api/v1/admin/metrics`.
- Авторизуйтесь через JWT (cookie `access_token` после логина в SPA).
- Графики: signal→order latency, dashboard LCP, Telegram webhook latency, backtest jobs throughput.

### 8.3 Логи

```bash
docker compose logs -f backend         # tail backend
docker compose logs -f frontend        # tail nginx
docker compose logs --since 1h         # за последний час, оба сервиса
```

### 8.4 Метрики Performance baseline (Sprint 8 W2)

| Метрика | Цель | Фактический baseline |
|---------|------|----------------------|
| Signal → order place p95 | < 500 мс | измеряется `@timed_event(name="trading.signal_to_order")` |
| Dashboard первый paint (LCP) | < 2 с | измеряется через PerformanceObserver |
| Telegram webhook → reply | < 3 с | `@timed_event(name="telegram.webhook_to_reply")` |

Реальные числа — на странице `/api/v1/admin/metrics` после ≥ 1 дня работы.

---

## 9. Troubleshooting

### 9.1 `docker compose up -d` падает / контейнер не healthy

```bash
docker compose logs backend | tail -100
```

| Симптом | Причина | Решение |
|---------|---------|---------|
| `sqlite3.OperationalError: unable to open database file` | volume не примонтирован / нет write-прав | проверить `docker volume inspect moex-sqlite-data` |
| `alembic.util.exc.CommandError: Can't locate revision` | свежий clone, не применились миграции | `docker compose exec backend alembic upgrade head` |
| `ModuleNotFoundError: tinkoff` | T-Invest SDK не установился в builder | очистить `docker compose build --no-cache backend` |
| `KeyError: 'SECRET_KEY'` | `.env.production` не загружен | проверить `docker compose config` (секция env_file) |
| контейнер backend сразу выходит (`exit 1`), в логах `check_production_env`: обнаружены dev-значения / нет `.env.production` | preflight-проверка секретов (CFG-BE-02): `.env.production` отсутствует, либо `SECRET_KEY`/`ENCRYPTION_KEY` начинаются с `dev-` или короче 32 байт | заполнить `.env.production` реальными значениями (см. §3.2); ключи ≥ 32 байт, без префикса `dev-` |
| `ValueError: master_key too short` при первом брокер/AI-запросе | `ENCRYPTION_KEY` короче 32 байт (production, DEBUG=false — fail-fast) | сгенерировать новый ключ ≥ 32 байт; ⚠️ смена ключа делает уже сохранённые broker-токены нерасшифровываемыми — пользователям нужно заново ввести токены |

### 9.2 Cloudflare Tunnel 502 Bad Gateway

```bash
cloudflared tunnel info moex-terminal      # connections должны быть active
docker compose ps                          # frontend должен быть Up healthy
```

Если `frontend` healthy, но Tunnel показывает 502 — проверить, что `cloudflared` смотрит на `http://localhost:80` (не `http://moex-frontend:80` — это имя только внутри Docker сети).

### 9.3 T-Invest connection_lost спамит уведомления

См. C-S8-7 DEV-2 W2 (S7R-CONNECTION-EVENTS-MARKET-CLOSED): фильтр `_is_moex_open_now()` уже подавляет уведомления вне торговой сессии. Если они приходят в рабочее время:
- Проверить `TINVEST_TOKEN` валидность через UI Settings → Broker.
- После Sandbox/Production токен switch: `docker compose restart backend` (singleton multiplexer кэширует token, см. C-S8-6).

### 9.4 Frontend lint падает локально (для разработчика)

```bash
cd Develop/frontend
pnpm install               # обновить deps до lock'а
pnpm lint                  # max-warnings 0 включён
```

Если падает в CI с Node 24 — проверить, что локально тоже Node 24 (`node -v`), `pnpm` через corepack.

### 9.5 Backup_job не пишет файлы

```bash
docker compose exec backend python -c "from app.scheduler.service import scheduler; print(scheduler.get_jobs())"
```

Если `backup_job` в списке нет — проверить `app/main.py` lifespan startup hooks; убедиться, что `scheduler.start()` вызывается.

### 9.6 Контейнер `frontend` показывает старую версию SPA после `git pull`

Vite hashes JS-файлы по контенту — браузер кеш не виноват. Причина: Docker layer cache. Решение:
```bash
docker compose build --no-cache frontend
docker compose up -d frontend
```

---

## Ссылки

- [README.md](../README.md) — общее описание проекта и Quick Start (для разработки).
- [Develop/INSTALL.md](../Develop/INSTALL.md) — локальная установка для разработки (без Docker).
- [functional_requirements.md](functional_requirements.md) v2.8 — функциональные требования (M4 production-ready).
- [technical_specification.md](technical_specification.md) v1.6 — техническое задание (раздел «Deployment Architecture»; §8 — Alembic и `DATABASE_URL`, drain paper-сессий при выкатке).
- [development_plan.md](development_plan.md) — дорожная карта (M4 ✅, Sprint_8_Review план).
- [Sprint_8/arch_design_s8.md](../Спринты/Sprint_8/arch_design_s8.md) §7 — Deployment target rationale.
- [Sprint_8/security_audit_s8.md](../Спринты/Sprint_8/security_audit_s8.md) — security findings и принятые fix'ы.
