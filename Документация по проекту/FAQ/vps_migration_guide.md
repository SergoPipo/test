# Миграция MOEX Trading Terminal на VPS

> Пошаговая инструкция переезда с Mac Mini + ngrok на выделенный сервер (VPS).

---

## 1. Требования к VPS

| Параметр | Минимум | Рекомендация |
|----------|---------|-------------|
| ОС | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| CPU | 2 vCPU | 4 vCPU |
| RAM | 2 GB | 4 GB |
| Диск | 20 GB SSD | 40 GB SSD |
| Порты | 80, 443, 22 | + 8000 (для диагностики) |
| Домен | Обязателен (для SSL) | Например: moex-terminal.ru |

## 2. Первоначальная настройка VPS

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка зависимостей
sudo apt install -y python3.11 python3.11-venv python3-pip \
    nodejs npm nginx certbot python3-certbot-nginx \
    git sqlite3 curl

# Установка pnpm (для frontend)
npm install -g pnpm
```

## 3. Деплой приложения

```bash
# Клонировать репозиторий
git clone git@github.com:SergoPipo/moex-terminal.git /opt/moex-terminal
cd /opt/moex-terminal

# Backend
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
alembic upgrade head

# Скопировать .env с Mac Mini
scp user@mac-mini:~/Documents/Claude_Code/Test/Develop/backend/.env /opt/moex-terminal/backend/.env

# Frontend
cd ../frontend
pnpm install --frozen-lockfile
pnpm build
```

## 4. Nginx как reverse proxy

```bash
sudo nano /etc/nginx/sites-available/moex-terminal
```

Содержимое:

```nginx
server {
    listen 80;
    server_name moex-terminal.ru;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name moex-terminal.ru;

    # SSL (certbot заполнит автоматически)
    ssl_certificate /etc/letsencrypt/live/moex-terminal.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/moex-terminal.ru/privkey.pem;

    # Frontend (статика)
    location / {
        root /opt/moex-terminal/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket
    location /ws {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/moex-terminal /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 5. SSL-сертификат (Let's Encrypt)

```bash
# Перед этим: DNS A-запись moex-terminal.ru → IP вашего VPS
sudo certbot --nginx -d moex-terminal.ru

# Автообновление (certbot добавляет cron автоматически)
sudo certbot renew --dry-run
```

## 6. Systemd для автозапуска backend

```bash
sudo nano /etc/systemd/system/moex-terminal.service
```

Содержимое:

```ini
[Unit]
Description=MOEX Trading Terminal Backend
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/moex-terminal/backend
Environment=PATH=/opt/moex-terminal/backend/.venv/bin:/usr/bin
ExecStart=/opt/moex-terminal/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable moex-terminal
sudo systemctl start moex-terminal
sudo systemctl status moex-terminal
```

## 7. Регистрация Telegram webhook (одноразово)

```bash
curl -X POST "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook" \
  -d "url=https://moex-terminal.ru/api/v1/notifications/telegram/webhook" \
  -d "secret_token=<TELEGRAM_WEBHOOK_SECRET>"
```

Проверка:
```bash
curl -s "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getWebhookInfo" | python3 -m json.tool
```

Webhook фиксированный — не нужно обновлять при перезагрузке (в отличие от ngrok).

## 8. SMTP

На VPS исходящие SMTP-соединения обычно не заблокированы (в отличие от домашнего ISP). Настройки в `.env`:

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER=nazarychev.s@gmail.com
SMTP_PASS=<app-password>
SMTP_FROM=nazarychev.s@gmail.com
```

**Примечание о портах:**
- Порт 465 (прямой SSL) — рекомендуется, работает через большинство ISP
- Порт 587 (STARTTLS) — стандартный, но может блокироваться некоторыми ISP через DPI
- Код автоматически выбирает `use_tls` (465) или `start_tls` (587) по значению `SMTP_PORT`

**Примечание:** Gmail подставит адрес отправителя `nazarychev.s@gmail.com` независимо от SMTP_FROM. Чтобы использовать `noreply@moex-terminal.ru` — нужно настроить свой почтовый сервер или использовать сервис типа SendGrid/Mailgun.

Проверка:
```bash
curl -X POST https://moex-terminal.ru/api/v1/notifications/test-email \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

## 9. Что удалить с Mac Mini

После успешной миграции:

```bash
# Остановить и удалить LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.moex-terminal.ngrok.plist
rm ~/Library/LaunchAgents/com.moex-terminal.ngrok.plist

# Остановить ngrok
pkill -f "ngrok http"

# Опционально: удалить ngrok
brew uninstall ngrok
```

Файлы `start_ngrok_webhook.sh` и `com.moex-terminal.ngrok.plist` в репозитории можно пометить как deprecated или удалить.

## 10. Чеклист после миграции

- [ ] VPS доступен по SSH
- [ ] Домен резолвится в IP VPS (`dig moex-terminal.ru`)
- [ ] `https://moex-terminal.ru` открывается (frontend)
- [ ] `https://moex-terminal.ru/api/v1/health` возвращает 200
- [ ] WebSocket работает (графики обновляются)
- [ ] Telegram webhook: `getWebhookInfo` показывает правильный URL и `pending_update_count: 0`
- [ ] Бот отвечает на `/start`, `/positions`, `/help`
- [ ] Email: тестовое письмо доходит
- [ ] Backend перезапускается автоматически (`sudo systemctl restart moex-terminal`)
- [ ] SSL-сертификат действителен (`certbot certificates`)
- [ ] ngrok остановлен на Mac Mini
