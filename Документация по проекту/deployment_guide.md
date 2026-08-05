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

#### Проверка миграций на чистой установке

`command` backend-контейнера выполняет `alembic upgrade head` до старта uvicorn
(`docker-compose.yml`), поэтому отдельно миграции запускать не нужно. Но на
**чистой** БД схему обязательно надо сверить — молчаливое расхождение миграций
с моделями (forward model drift) уже приводило к неработающему входу:

```bash
docker compose exec backend alembic current   # ожидается: d1e2f3a4b5c6 (head)
docker compose exec backend alembic heads     # та же ревизия — расхождений нет
```

> **⚠️ Историческая справка (S8R-ALEMBIC-FRESH-DB-DRIFT, 2026-07-28).**
> До ревизии **`d1e2f3a4b5c6`** (`s8r_fresh_db_drift`) сценарий именно из этого
> раздела был сломан: на **чистой** БД после `alembic upgrade head` не
> создавались таблица `user_ai_settings` и восемь колонок
> (`strategies.description`, `instruments.logo_name`, 6 колонок в
> `ai_provider_configs`) — модели ушли вперёд миграций. Первый же вход
> (`POST /api/v1/auth/login`) отдавал **500**
> `no such column: strategies.description`, то есть развёртывание с нуля по
> этому гайду давало неработающую систему. На уже работающих стендах дефект
> не проявлялся — их БД получили недостающие объекты другим путём (`init_db`),
> поэтому он и не всплывал три недели.
> Миграция `d1e2f3a4b5c6` **идемпотентна** (каждый объект добавляется только
> если его ещё нет), поэтому безопасна и для чистой, и для существующей БД.
> Регресс-защита в CI —
> `backend/tests/unit/test_migration.py::test_fresh_db_schema_matches_models`:
> сверяет всю `Base.metadata` (таблицы **и** колонки) с фактической схемой
> чистой БД. Класс ловушки —
> [`Develop/stack_gotchas/gotcha-13-forward-model-drift.md`](../Develop/stack_gotchas/gotcha-13-forward-model-drift.md).

Если `alembic current` пуст или ниже `d1e2f3a4b5c6` — контейнер стартовал без
миграций (см. §9.1), вход работать не будет.

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

После апдейта сверьте, что миграции доехали до головы:

```bash
docker compose exec backend alembic current   # ожидается: e5f6a7b8c9d0 (head)
```

> **ℹ️ Обновление с версии старше `e5f6a7b8c9d0` (S8R, 2026-08-05).**
> Две ревизии одного цикла «сверка с брокером», обе идемпотентны и обратимы.
>
> `d4e5f6a7b8c9` — `live_trades.exit_broker_order_id` и
> `live_trades.exit_order_placed_at` (`S8R-EXIT-ORDER-NOT-TRACKED`).
> Идентификатор **закрывающего** ордера: `broker_order_id` занят ордером входа,
> поэтому до этой версии рестарт backend в момент, когда встречный ордер был в
> полёте, оставлял сделку `filled` навсегда — у брокера позиция закрывалась, а
> в терминале нет. После обновления доучёт делается при старте backend и далее
> раз в минуту: статус ордера **опрашивается**, ордер никогда не отправляется
> повторно. У сделок до этой версии обе колонки `NULL` — это «сведений нет», и
> доучёт их не трогает.
>
> `e5f6a7b8c9d0` — `trading_sessions.position_mismatch_at` и
> `position_mismatch_note` (`S8R-SANDBOX-POSITIONS-NOT-RECONCILED`). При старте
> сессии открытые позиции сверяются с `GetPositions` брокера (теперь и в
> sandbox, не только в `real`). **Расхождение показывается, а не чинится:**
> позиции не закрываются и объём не переписывается, сессия ставится на паузу с
> видимой пометкой в карточке и критическим уведомлением. Автозакрытие вслепую
> здесь запрещено намеренно: песочница умеет вернуть неполный портфель, и
> терминал закрыл бы живую позицию.
>
> ⚠️ После обновления возможна **пауза сессии с пометкой «Расхождение с
> брокером»** — это не сбой обновления, а первая честная сверка. Сверьтесь с
> приложением брокера и закройте лишнее вручную; когда позиции сойдутся,
> пометка снимается сама на следующей сверке.

> **ℹ️ Обновление с версии старше `c3d4e5f6a7b8` (S8R, 2026-08-04).**
> Ревизия `c3d4e5f6a7b8` (`commission_source_and_broker_rate`) добавляет три
> колонки:
> * `live_trades.commission_source` — откуда взялась комиссия: `broker`
>   (удержано брокером, T-Invest `OrderState.executed_commission`) или
>   `estimated` (оценка по тарифу — песочница комиссию обычно не удерживает).
>   У сделок до этой версии — `NULL`;
> * `broker_accounts.commission_pct` — тариф счёта, `server_default = '0'`.
>   **Задайте его вручную** на странице «Настройки → Брокер» для каждого
>   счёта: пока он нулевой, sandbox/real-сделки без фактической комиссии
>   брокера продолжат записываться без удержания, а paper-сессии — считать по
>   ставке из формы запуска (0,05 % по умолчанию);
> * `tax_lots.trade_mode` — режим сделки в отчёте 3-НДФЛ. Sandbox-сделки
>   остаются в отчёте, но помечаются колонкой «Режим» и примечанием.
>
> ⚠️ **Отчёты 3-НДФЛ, сформированные до этой версии, следует
> перегенерировать.** Ревизия идёт в паре с исправлением
> `S8R-TAX-PNL-LOSES-LOT-SIZE`: раньше результат сделки считался по лотам без
> множителя штук/лот, и по инструменту с `lot_size = 10` налоговая база была
> занижена в десять раз. Файлы старых отчётов не пересчитываются
> автоматически — их нужно сформировать заново на странице «Счёт».
>
> Миграция **идемпотентна** (колонка уже есть — пропускается) и **обратима**:
> `downgrade` снимает все три колонки.
> ⚠️ SQLite пересоздаёт таблицы целиком (`batch_alter_table`), затронуты
> `live_trades`, `broker_accounts`, `tax_lots` — снимите backup перед
> обновлением (§6.1).

> **ℹ️ Обновление с версии старше `b7c8d9e0f1a2` (S8R, 2026-08-03).**
> Ревизия `b7c8d9e0f1a2` (`add_trading_sessions_commission_pct`) добавляет
> колонку `trading_sessions.commission_pct` — ставку комиссии, которую
> бумажная торговля теперь удерживает так же, как её вычитает бэктест.
> `server_default = '0'`, поэтому **уже запущенные сессии продолжают считать
> деньги по-прежнему**: ретроактивного удержания нет, история не
> пересчитывается. Новые сессии получают ставку из формы запуска (по
> умолчанию 0,05 %).
> Миграция **идемпотентна** (колонка уже есть — проходит без ошибки) и
> **обратима**: `downgrade` снимает колонку.
> ⚠️ SQLite не умеет нативный `ADD COLUMN` с пересозданием ограничений,
> поэтому Alembic пересоздаёт таблицу `trading_sessions` целиком
> (`batch_alter_table`) — снимите backup перед обновлением (§6.1).

> **ℹ️ Обновление с версии старше `e2f3a4b5c6d7` (S8R, 2026-08-03).**
> Ревизия `e2f3a4b5c6d7` (`drop_daily_stats_unrealized_pnl`) удаляет колонку
> `daily_stats.unrealized_pnl`. Колонка не заполнялась никогда с момента
> создания схемы, поэтому **данные не теряются**: все её значения — нули по
> построению. Нереализованный P&L считается на лету
> (`app/trading/unrealized.py`), в БД не хранится.
> Миграция **идемпотентна** (если колонки уже нет — проходит без ошибки) и
> **обратима**: `downgrade` возвращает колонку с прежним типом и
> `DEFAULT 0`. Отдельных действий администратора не требуется.
> ⚠️ SQLite не умеет нативный `DROP COLUMN`, поэтому Alembic пересоздаёт
> таблицу `daily_stats` целиком (`batch_alter_table`) — как и при любой
> правке схемы на SQLite, снимите backup перед обновлением (§6.1).

> **ℹ️ Обновление с версии старше `d1e2f3a4b5c6` (S8R, 2026-07-28).**
> Ревизия `d1e2f3a4b5c6` (`s8r_fresh_db_drift`) досоздаёт таблицу
> `user_ai_settings` и восемь колонок, которых не хватало на чистых установках
> (подробности — §3.3). Она **идемпотентна**: на стенде, где эти объекты уже
> появились через `init_db`, миграция проходит без ошибки «duplicate column» и
> данные не трогает. Отдельных действий администратора не требуется.
> Ограничение `downgrade`: обратная миграция удаляет добавленные объекты
> **вместе с данными** в `user_ai_settings` — перед откатом снимите backup
> (§6.1).

> **⚠️ Разовая процедура при обновлении до версии с BE-TRAD-06 (денежный учёт paper-портфеля, Model A).**
> До этой версии paper-BUY не списывал `PaperPortfolio.balance` и не блокировал капитал. Позиция, **открытая на старом коде и ещё не закрытая на момент апдейта**, при закрытии на новом коде получит зачисление `proceeds` без парного списания при открытии → `balance` завысится, а `blocked_amount` уйдёт в underflow (безопасно зажимается в 0 с `log.error("paper_blocked_amount_underflow")`). Эффект только на paper, транзиентный (само-исцеляется после одного цикла закрытия), но искажает equity/CB-drawdown для straddle-позиций.
> **Перед обновлением:** закрыть/сбросить открытые paper-сессии (в UI закрыть все позиции активных paper-сессий, либо остановить paper-сессии). Оба пути ведут в один и тот же код: `stop_session` → `OrderManager.close_all_positions` → `close_position` → `PaperPortfolioAccountant.apply_close`, то есть деньги возвращаются в портфель штатно.
> **Закрытие — best-effort, обязательно проверьте результат.** `stop_session` доводит сессию до `stopped` даже если часть позиций закрыть не удалось (нет рыночной цены, брокер недоступен): такие позиции остаются в реальном open-статусе, в лог уходит `stop_session_positions_not_closed`, пользователю — уведомление `positions.close_failed`. Drain считается выполненным только когда открытых paper-позиций не осталось:
> ```bash
> docker compose exec backend python -c "
> import asyncio, sqlalchemy as sa
> import app.common.database as database
> from app.trading.models import LiveTrade, TradingSession
> async def main():
>     # AsyncSessionLocal создаётся в init_db() (lifespan приложения); в разовом
>     # скрипте её надо инициализировать явно, иначе она равна None.
>     await database.init_db()
>     async with database.AsyncSessionLocal() as db:
>         rows = (await db.execute(
>             sa.select(TradingSession.id, sa.func.count(LiveTrade.id))
>             .join(LiveTrade, LiveTrade.session_id == TradingSession.id)
>             .where(TradingSession.mode == 'paper',
>                    LiveTrade.status.in_(['filled', 'pending']),
>                    LiveTrade.closed_at.is_(None))
>             .group_by(TradingSession.id)
>         )).all()
>         print(rows or 'открытых paper-позиций нет — drain выполнен')
> asyncio.run(main())
> "
> ```
> **Альтернатива** — одноразовая реконсиляция БД: `blocked_amount = Σ(volume_rub открытых сделок)`, `balance = initial_capital + Σ(realized pnl)`, **и обязательно** `peak_equity = balance + blocked_amount`. Про `peak_equity` забывать нельзя: по нему Circuit Breaker считает max drawdown (`(peak_equity − equity) / peak_equity`, `app/circuit_breaker/engine.py`), и оставленное завышенное пред-апдейтное значение даст фиктивную просадку на первой же проверке — CB поставит сессии на паузу без причины. `volume_rub` для paper уже включает `lot_size` (пишется как `price × lots × lot_size` при создании сделки), так что множитель в формуле не нужен. Пред-апдейтные значения `balance/blocked_amount` и так были фикцией (см. `Спринты/Code_Review_Full_2026-07/BE_TRAD_06_LOG.md`), поэтому сброс безопасен.

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
- Графики: signal→order latency, оценка стратегии на свече, dashboard LCP,
  Telegram webhook latency, backtest jobs throughput.

**Источник данных и его ограничения (S8R, 2026-07-30).** До этой версии все
графики рисовали зашитые в код mock-массивы. Теперь четыре из пяти питаются
живыми замерами `@timed_event` из кольцевого буфера
`app/common/metrics_store.py`; пятый (backtest jobs) пока остаётся mock и так и
подписан на странице. Что из этого следует для эксплуатации:

- **Буфер в памяти процесса.** Рестарт backend (`docker compose restart
  backend`, деплой, падение) обнуляет графики — это не потеря данных, а
  отсутствие персистентности по замыслу: писать в SQLite на каждый тик
  торгового хот-пути дороже, чем сама метрика.
- **Глубина = ёмкость буфера**, последние N замеров на метрику, а не
  фиксированное окно времени. На тихом стенде это сутки, под нагрузкой —
  минуты.
- **Несколько воркеров покажут только свою долю.** Текущая поставка
  однопроцессная (один backend-контейнер), поэтому вопрос не стоит; при
  масштабировании график перестанет быть полным.
- **Пустой график с подписью «нет замеров» — нормальное состояние** сразу
  после старта: метрика ещё не срабатывала. Правдоподобных чисел вместо
  пустоты страница не рисует намеренно.
- **Dashboard LCP приходит из браузера**: `PerformanceObserver` в SPA шлёт
  замер в `POST /api/v1/observability/lcp` при уходе вкладки в фон. Эндпоинт
  требует обычной аутентификации (не admin — замер шлёт пользователь) и
  отбрасывает значения свыше 10 минут. Если график LCP пуст, а остальные
  наполнены — значит SPA не доходит до отправки (пользователь не логинился,
  либо браузер не поддерживает `largest-contentful-paint`).

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
