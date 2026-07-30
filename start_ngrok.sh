#!/bin/bash
# Запуск ngrok-туннеля + регистрация Telegram webhook.
#
# Тонкая обёртка над Develop/scripts/start_ngrok_webhook.sh: позволяет
# вызывать одной командой из любого места проекта, без cd в Develop/scripts/.
#
# Использование (из корня Test/):
#   ./start_ngrok.sh
#
# Или с любым cwd:
#   bash /Users/sergopipo/Documents/Claude_Code/Test/start_ngrok.sh
#
# Что делает:
#   1. pkill старого ngrok (если висит).
#   2. ngrok http 8000 → публичный HTTPS-URL.
#   3. setWebhook у Telegram Bot API → URL + secret из Develop/.env.
#
# После запуска бот @moex_terminal_bot снова получает апдейты.
# Дашборд ngrok: http://localhost:4040.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/Develop/scripts/start_ngrok_webhook.sh" "$@"
