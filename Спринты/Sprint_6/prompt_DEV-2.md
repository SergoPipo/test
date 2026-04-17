---
sprint: S6
agent: DEV-2
role: "Backend Integrations (BACK2) — Telegram Bot + Email Notifications"
wave: 1
depends_on: [DEV-0]
---

# Роль

Ты — Backend-разработчик #2 (senior), специалист по внешним интеграциям. Твоя задача — реализовать два внешних канала доставки уведомлений:

1. **Telegram Bot** — привязка chat_id через одноразовый токен, доставка уведомлений, обработка команд `/positions`, `/status`, `/help`.
2. **Email уведомления** — SMTP через `aiosmtplib`, доставка критических событий.

Оба канала интегрируются с `NotificationService` (реализуется DEV-1 параллельно). Ты реализуешь dispatch-логику, DEV-1 вызывает её через `dispatch_external()`.

Работаешь в `Develop/backend/`.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python >= 3.11
2. Зависимости:
   - python-telegram-bot >= 20.x (pip install python-telegram-bot)
   - aiosmtplib >= 2.x (pip install aiosmtplib)
   - Проверь: pip show python-telegram-bot aiosmtplib
3. Существующие файлы:
   - app/notification/models.py       — TelegramLink(user_id, chat_id, linked_at, is_active), UserNotificationSetting(event_type, telegram/email/in_app_enabled)
   - app/notification/service.py      — NotificationService (реализуется DEV-1)
   - app/common/database.py           — AsyncSessionLocal, Base
   - app/auth/models.py               — User(id, username, email)
4. База данных: TelegramLink уже определён в models.py
5. Env-переменные (добавить в .env.example):
   - TELEGRAM_BOT_TOKEN — токен бота из BotFather
   - TELEGRAM_WEBHOOK_SECRET — секрет для верификации вебхуков
   - SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
6. Тесты baseline: `pytest tests/` → 0 failures
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — особенно:
   - **Gotcha 1** (`gotcha-01-pydantic-decimal.md`) — Decimal → str. Для Telegram-форматирования цен.
   - **Gotcha 8** (`gotcha-08-asyncsession-get-bind.md`) — AsyncSession в тестах.

3. **`Спринты/Sprint_6/execution_order.md`** раздел **«Cross-DEV contracts»**:
   - Ты **потребитель** контракта `NotificationService.create_notification()` от DEV-1.
   - Ты **поставщик** контракта `dispatch_external(notification, settings) → channels_sent: list[str]` для DEV-1.

4. **Цитаты из ТЗ / ФТ:**

   > **ТЗ 5.7 TelegramNotifier (дословно):**
   > «Библиотека: python-telegram-bot в webhook-режиме (endpoint /api/v1/telegram/webhook). Верификация webhook через secret token. Форматирование сообщений по шаблонам (HTML parse mode). Inline-кнопки: "График" (deep link), "Закрыть" (callback query с confirmation). Обработка команд: /start, /positions, /status, /help, /close, /closeall, /balance.»

   > **ТЗ 5.7 EmailNotifier (дословно):**
   > «SMTP через aiosmtplib. Используется только для критических событий (circuit breaker, потеря связи, дневная статистика). Настраивается в .env: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS.»

   > **ФТ 9.1 Привязка Telegram (дословно):**
   > «В настройках профиля пользователь нажимает "Привязать Telegram". Система генерирует одноразовый 6-значный токен с TTL = 5 минут. По истечении — токен инвалидируется. Пользователь отправляет этот токен боту в Telegram командой /start <токен>. Бот регистрирует chat_id — все дальнейшие сообщения идут только на этот chat_id.»

   > **ФТ 9.3 Bot Commands — Must (дословно):**
   > «/positions — Список всех открытых позиций с unrealized P&L. /status — Статус всех запущенных стратегий (Real + Paper). /help — Список команд.»

   > **ФТ 10.1 Таблица каналов — Email-события:**
   > Email отправляется только для: circuit breaker, потеря соединения с брокером, закрытие всех позиций, дневная статистика, восстановление после перезапуска.

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

```
- app/notification/models.py       — TelegramLink(user_id→users.id, chat_id, linked_at, is_active). НЕ менять модель.
- app/notification/service.py      — NotificationService с dispatch_external() — заглушка от DEV-1. Ты заменяешь заглушку реальной логикой.
- app/auth/models.py               — User(id, username, email). Поле email — для EmailNotifier.
- app/trading/models.py            — TradingSession, LiveTrade. Для /positions и /status команд.
- app/trading/schemas.py           — SessionResponse, TradeResponse. Для форматирования ответов.
- app/common/database.py           — AsyncSessionLocal. Для DB-запросов из Telegram-хендлеров.
```

# Задачи

## Задача 2.1: TelegramNotifier — доставка уведомлений

Создай `app/notification/telegram.py`:

```python
from telegram import Bot

class TelegramNotifier:
    """Отправка уведомлений в Telegram через Bot API."""
    
    def __init__(self, bot_token: str) -> None:
        self._bot = Bot(token=bot_token)
    
    async def send(
        self,
        chat_id: str,
        title: str,
        body: str,
        severity: str,
        related_entity_type: str | None = None,
        related_entity_id: int | None = None,
    ) -> bool:
        """Отправить уведомление в Telegram.
        
        Форматирование: HTML parse_mode.
        Severity → emoji:
          info → ℹ️, success → ✅, warning → ⚠️, critical → 🚨
        
        Шаблон сообщения:
          {emoji} <b>{title}</b>
          {body}
          
          [inline_keyboard если related_entity_type]
        
        Inline-кнопки:
          - Если related_entity_type == "session": кнопка "📊 Открыть сессию" → deep link /trading/sessions/{id}
          - Если related_entity_type == "trade": кнопка "📈 Открыть график" → deep link /chart/{ticker}
        
        Return True если отправлено, False при ошибке (логируй, не бросай exception).
        """
```

## Задача 2.2: Привязка Telegram — токен + webhook

### 2.2a: Генерация токена (REST API)

В `app/notification/router.py` добавь endpoint:

```python
@router.post("/telegram/link-token", response_model=TelegramLinkTokenResponse)
async def generate_telegram_link_token(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TelegramLinkTokenResponse:
    """Генерирует 6-значный одноразовый токен для привязки Telegram.
    TTL = 5 минут. Хранится в Redis или in-memory dict с TTL.
    
    Response: {"token": "123456", "bot_username": "moex_terminal_bot", "expires_in": 300}
    """
```

### 2.2b: Telegram webhook handler

Создай `app/notification/telegram_webhook.py`:

```python
from telegram import Update
from telegram.ext import Application, CommandHandler, CallbackQueryHandler

class TelegramWebhookHandler:
    """Обработка входящих Telegram-обновлений через webhook."""
    
    def __init__(
        self,
        bot_token: str,
        webhook_secret: str,
        db_factory: async_sessionmaker[AsyncSession],
    ) -> None:
        self._app = Application.builder().token(bot_token).build()
        self._webhook_secret = webhook_secret
        self._db_factory = db_factory
        
        # Регистрация хендлеров
        self._app.add_handler(CommandHandler("start", self._handle_start))
        self._app.add_handler(CommandHandler("positions", self._handle_positions))
        self._app.add_handler(CommandHandler("status", self._handle_status))
        self._app.add_handler(CommandHandler("help", self._handle_help))
        self._app.add_handler(CallbackQueryHandler(self._handle_callback))
    
    async def _handle_start(self, update, context):
        """Привязка: /start <6-digit-token>
        1. Извлечь токен из args
        2. Найти user_id по токену (из in-memory store)
        3. Создать/обновить TelegramLink(user_id, chat_id)
        4. Ответить: "✅ Telegram привязан к аккаунту {username}"
        """
    
    async def _handle_positions(self, update, context):
        """Показать открытые позиции.
        1. Найти user по chat_id из TelegramLink
        2. Загрузить LiveTrade(status="filled") для всех active сессий пользователя
        3. Форматировать:
           📊 <b>Открытые позиции</b>
           
           SBER: 100 лот(ов), вход 250.50 ₽, текущая 265.30 ₽
           P&L: +1 480.00 ₽ (+5.91%)
           
           GAZP: 50 лот(ов), вход 180.20 ₽, текущая 175.10 ₽
           P&L: -255.00 ₽ (-2.83%)
        """
    
    async def _handle_status(self, update, context):
        """Статус стратегий.
        1. Найти user по chat_id
        2. Загрузить TradingSession(status in ("active", "paused")) 
        3. Форматировать:
           🤖 <b>Стратегии</b>
           
           ✅ MA Cross — SBER (1h) — Paper
           Сделок сегодня: 3, P&L: +450 ₽
           
           ⏸ RSI Reversal — GAZP (15m) — Real
           На паузе с 14:30
        """
    
    async def _handle_help(self, update, context):
        """Список команд — статический текст."""
    
    async def _handle_callback(self, update, context):
        """Обработка inline-кнопок (callback_query)."""
```

### 2.2c: FastAPI endpoint для webhook

```python
# В router.py или отдельном файле
@router.post("/telegram/webhook")
async def telegram_webhook(request: Request):
    """Endpoint для Telegram webhook.
    Верифицирует secret_token из заголовка X-Telegram-Bot-Api-Secret-Token.
    Передаёт Update в TelegramWebhookHandler.
    """
```

## Задача 2.3: EmailNotifier — SMTP через aiosmtplib

Создай `app/notification/email.py`:

```python
import aiosmtplib
from email.message import EmailMessage

class EmailNotifier:
    """Отправка email-уведомлений через SMTP."""
    
    def __init__(
        self,
        smtp_host: str,
        smtp_port: int,
        smtp_user: str,
        smtp_pass: str,
        from_address: str,
    ) -> None:
        self._host = smtp_host
        self._port = smtp_port
        self._user = smtp_user
        self._pass = smtp_pass
        self._from = from_address
    
    async def send(
        self,
        to_email: str,
        title: str,
        body: str,
        severity: str,
    ) -> bool:
        """Отправить email.
        
        Только для критических событий (ФТ 10.1):
        - cb_triggered (Circuit Breaker)
        - connection_lost (потеря соединения с брокером)
        - all_positions_closed (закрытие всех позиций)
        - daily_stats (дневная статистика)
        - session_recovered (восстановление после перезапуска)
        
        HTML-шаблон: простой, без CSS-фреймворков.
        Subject: f"MOEX Terminal: {title}"
        
        Return True если отправлено.
        При ошибке — логируй, return False (не блокируй основной поток).
        """
```

## Задача 2.4: Интеграция dispatch_external

Замени заглушку в `NotificationService.dispatch_external()` (файл service.py, реализованный DEV-1) на реальные вызовы:

```python
async def dispatch_external(
    self,
    notification: Notification,
    settings: UserNotificationSetting,
) -> list[str]:
    channels: list[str] = []
    
    if settings.telegram_enabled:
        # Найти TelegramLink по user_id
        link = await self._get_telegram_link(notification.user_id)
        if link and link.is_active:
            sent = await self._telegram.send(
                chat_id=link.chat_id,
                title=notification.title,
                body=notification.body or "",
                severity=notification.severity,
                related_entity_type=notification.related_entity_type,
                related_entity_id=notification.related_entity_id,
            )
            if sent:
                channels.append("telegram")
    
    if settings.email_enabled:
        user = await self._get_user(notification.user_id)
        if user and user.email:
            sent = await self._email.send(
                to_email=user.email,
                title=notification.title,
                body=notification.body or "",
                severity=notification.severity,
            )
            if sent:
                channels.append("email")
    
    return channels
```

**Важно:** DEV-1 создаёт заглушку dispatch_external, ты заменяешь реализацию. При мерже: DEV-1 первый, DEV-2 вторым (ПРАВИЛО 1 из execution_order).

## Задача 2.5: Обновить .env.example

Добавь в `Develop/backend/.env.example` (или `.env.template`):

```env
# Telegram Bot
TELEGRAM_BOT_TOKEN=
TELEGRAM_WEBHOOK_SECRET=
TELEGRAM_BOT_USERNAME=moex_terminal_bot

# Email (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_FROM=noreply@moex-terminal.local
```

# Тесты

```
tests/
├── test_notification/
│   ├── test_telegram_notifier.py     # send() с mock Bot
│   ├── test_telegram_webhook.py      # /start, /positions, /status, /help, callback_query
│   ├── test_telegram_link.py         # Генерация токена, привязка, TTL-экспирация
│   └── test_email_notifier.py        # send() с mock aiosmtplib
```

**Минимум:** 10 тестов:
- 2 на TelegramNotifier.send() (success, failure)
- 4 на webhook commands (/start+token, /positions, /status, /help)
- 2 на привязку (token valid, token expired)
- 2 на EmailNotifier.send() (success, failure)

**Мокирование:** mock `telegram.Bot.send_message`, mock `aiosmtplib.send`. НЕ делать реальных HTTP-запросов к Telegram/SMTP.

# ⚠️ Integration Verification Checklist

- [ ] `grep -rn "TelegramNotifier(" app/` — инстанциируется в `service.py` или `main.py`
- [ ] `grep -rn "EmailNotifier(" app/` — инстанциируется в `service.py` или `main.py`
- [ ] `grep -rn "telegram/webhook" app/` — endpoint зарегистрирован в router
- [ ] `grep -rn "telegram/link-token" app/` — endpoint зарегистрирован в router
- [ ] `grep -rn "dispatch_external" app/notification/service.py` — реальная реализация (не заглушка)
- [ ] `grep -rn "TELEGRAM_BOT_TOKEN" app/` — читается из env/settings
- [ ] `grep -rn "SMTP_HOST" app/` — читается из env/settings
- [ ] Env-переменные добавлены в .env.example

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.
Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-2_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 2.1–2.5 реализованы
- [ ] `ruff check .` → 0 errors
- [ ] `mypy app/ --ignore-missing-imports` → 0 errors
- [ ] `pytest tests/` → 0 failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-2_report.md`
- [ ] **Cross-DEV contracts подтверждены:** dispatch_external реализован, TelegramNotifier.send() и EmailNotifier.send() подключены
- [ ] Telegram webhook верифицирует secret token
- [ ] .env.example обновлён
