---
sprint: S6
agent: DEV-1
role: "Backend Core (BACK1) — In-app Notifications WS + Recovery + Graceful Shutdown"
wave: 1
depends_on: [DEV-0]
---

# Роль

Ты — Backend-разработчик #1 (senior), специалист по real-time системам и lifecycle management. Твоя задача — реализовать три ключевых подсистемы Sprint 6:

1. **In-app уведомления** — `NotificationService` + REST API + WebSocket bridge для доставки событий из `SessionRuntime` в браузер.
2. **Recovery** — расширить `SessionRuntime.restore_all()` для real-сессий: сверка позиций с брокером + восстановление `StreamManager.subscribe`.
3. **Graceful Shutdown** — расширить `SessionRuntime.shutdown()`: сохранение pending-событий, отправка уведомления «Система остановлена», корректная последовательность завершения.

Работаешь в `Develop/backend/`.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python >= 3.11
2. Зависимости предыдущих DEV: DEV-0 смержен (баг _underscore починен)
3. Существующие файлы (ПРОЧИТАЙ каждый перед началом):
   - app/notification/models.py        — Notification, TelegramLink, UserNotificationSetting (уже определены!)
   - app/notification/service.py       — STUB (1 строка), реализуешь ты
   - app/notification/schemas.py       — STUB (1 строка), реализуешь ты
   - app/notification/router.py        — MINIMAL (5 строк, только APIRouter), расширяешь ты
   - app/trading/runtime.py            — SessionRuntime (548 строк, полностью реализован)
   - app/trading/engine.py             — TradingSessionManager, SignalProcessor, OrderManager
   - app/common/event_bus.py           — EventBus singleton (publish/subscribe/unsubscribe)
   - app/market_data/stream_manager.py — MarketDataStreamManager (subscribe/unsubscribe)
   - app/main.py                       — lifespan с SessionRuntime + все роутеры
4. База данных: модели Notification, TelegramLink, UserNotificationSetting уже в models.py.
   Проверь, что миграция для них существует. Если нет — создай.
5. Тесты baseline: `pytest tests/` → 0 failures
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — особенно:
   - **Gotcha 1** (`gotcha-01-pydantic-decimal.md`) — Decimal → str в JSON. Применить для полей `Notification`.
   - **Gotcha 4** (`gotcha-04-tinvest-stream.md`) — persistent gRPC. Для Recovery: `StreamManager.subscribe` ожидает `api_key`.
   - **Gotcha 5** (`gotcha-05-circuit-breaker-lock.md`) — asyncio.Lock в runtime. Recovery должен восстанавливать Lock-и.
   - **Gotcha 8** (`gotcha-08-asyncsession-get-bind.md`) — AsyncSession в тестах.

3. **`Спринты/Sprint_6/execution_order.md`** раздел **«Cross-DEV contracts»** — ты **поставщик** контрактов:
   - `NotificationService.create_notification()` → для DEV-2 и DEV-4
   - REST API `/api/v1/notifications/*` → для DEV-4
   - WS канал `notifications:{user_id}` → для DEV-4

4. **Цитаты из ТЗ / ФТ:**

   > **ТЗ 5.7 NotificationService (дословно):**
   > «NotificationService слушает event bus и маршрутизирует события по каналам. Каналы: TelegramNotifier, EmailNotifier, InAppNotifier. Маршрутизация на основе user_notification_settings.»
   > «InAppNotifier: Создаёт запись в notifications. Пушит через WebSocket канал notifications.»

   > **ФТ 10.2 In-app notifications (дословно):**
   > «Иконка колокольчика в навигационной панели с счётчиком непрочитанных. Лента событий (выдвижная панель): событие, время, инструмент, краткое описание. Критические события (circuit breaker, потеря связи) — красный баннер на весь экран с dismiss-кнопкой.»

   > **ФТ 17.7 Recovery after restart (дословно):**
   > «При старте системы: проверка наличия сессий со статусом «active» или «suspended» (как Real, так и Paper). Для каждой такой сессии: 1. Сверка позиций с брокером (запрос текущих позиций через API) — для Real-сессий. Для Paper — восстановление виртуального баланса и позиций из БД. 2. Восстановление подписки на котировки. 3. Возобновление мониторинга сигналов стратегии. Уведомление пользователю о восстановленных сессиях с указанием времени простоя. Если обнаружены расхождения позиций (позиция закрыта на стороне брокера, или объём изменился) — стратегия ставится на паузу с уведомлением и деталями расхождений.»

   > **ТЗ 8.6 Graceful Shutdown (дословно):**
   > «При получении SIGTERM/SIGINT: 1. Установить флаг shutting_down = True. 2. Прекратить приём новых HTTP-запросов. 3. Для каждой активной trading session: сохранить состояние в БД (status → 'suspended'), отменить активные подписки. 4. Дождаться завершения текущих ордеров (timeout 30s). 5. Закрыть gRPC-каналы, WebSocket-соединения. 6. Отправить уведомление "Система остановлена" в Telegram. 7. Закрыть БД-соединения.»

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

```
- app/notification/models.py       — Notification(id, user_id, event_type, title, body, severity, is_read, channels_sent, related_entity_type/id, created_at), TelegramLink(user_id, chat_id), UserNotificationSetting(user_id, event_type, telegram/email/in_app_enabled). НЕ пересоздавать модели — они уже определены.
- app/notification/service.py      — STUB. Реализуешь NotificationService здесь.
- app/notification/schemas.py      — STUB. Реализуешь Pydantic-схемы здесь.
- app/notification/router.py       — Только `router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])`. Добавляешь endpoints.
- app/trading/runtime.py           — SessionRuntime: start(), stop(), restore_all(), shutdown(), _handle_candle(). EventBus events: "session.started", "session.stopped", "order.placed", "trade.filled", "trade.closed", "cb.triggered" на канале `trades:{session_id}`. НЕ ломать существующую логику.
- app/common/event_bus.py          — EventBus: publish(channel, event, data), subscribe(channel) → (sub_id, queue), unsubscribe(channel, sub_id). Singleton: `event_bus`.
- app/market_data/stream_manager.py — MarketDataStreamManager: subscribe(ticker, tf, api_key, api_secret, is_sandbox) → channel_name. НЕ модифицировать.
- app/main.py                      — lifespan: init_db(), SessionRuntime(AsyncSessionLocal), restore_all(active_sessions), yield, shutdown(), close_db(). Роутеры: notification_router уже подключён.
- app/broker/tinvest/adapter.py    — TInvestAdapter: get_positions(account_id), get_real_positions(). Для Recovery.
```

# Задачи

## Задача 1.1: NotificationService — ядро маршрутизации

В `app/notification/service.py` реализуй:

```python
class NotificationService:
    """Маршрутизирует события из EventBus по каналам (in-app, telegram, email).
    Слушает каналы trades:{session_id} и system:{user_id}.
    """

    def __init__(self, db_factory: async_sessionmaker[AsyncSession]) -> None:
        """db_factory — для создания per-event сессий."""

    async def create_notification(
        self,
        db: AsyncSession,
        user_id: int,
        event_type: str,
        title: str,
        body: str,
        severity: str = "info",
        related_entity_type: str | None = None,
        related_entity_id: int | None = None,
    ) -> Notification:
        """Создаёт запись Notification в БД + пушит через EventBus канал notifications:{user_id}.
        
        Логика:
        1. INSERT в таблицу notifications
        2. Загрузить UserNotificationSetting для event_type + user_id
        3. Если in_app_enabled (default True) — publish в EventBus:
           канал: f"notifications:{user_id}"
           event: "notification.new"
           data: NotificationResponse.model_dump()
        4. Заполнить channels_sent (comma-separated: "in_app", "in_app,telegram", etc.)
        5. Return Notification
        """

    async def dispatch_external(
        self,
        notification: Notification,
        settings: UserNotificationSetting,
    ) -> list[str]:
        """Отправить уведомление во внешние каналы (telegram, email).
        Реализацию Telegram/Email оставить как заглушку — DEV-2 реализует.
        Вернуть список каналов, куда отправлено.
        """
        channels: list[str] = []
        if settings.telegram_enabled:
            # TODO: DEV-2 реализует TelegramNotifier.send()
            channels.append("telegram")
        if settings.email_enabled:
            # TODO: DEV-2 реализует EmailNotifier.send()
            channels.append("email")
        return channels

    async def listen_session_events(self, session_id: int, user_id: int) -> None:
        """Подписывается на EventBus канал trades:{session_id},
        конвертирует runtime-события в Notification-и.
        
        Маппинг событий (из runtime.py C7 контракт):
          "session.started" → event_type="session_started", severity="info"
          "session.stopped" → event_type="session_stopped", severity="info"
          "order.placed"    → event_type="order_placed", severity="info"
          "trade.filled"    → event_type="trade_filled", severity="success"
          "trade.closed"    → event_type="trade_closed", severity="success"
          "cb.triggered"    → event_type="cb_triggered", severity="critical"
        """

    async def stop_listening(self, session_id: int) -> None:
        """Отписаться от канала trades:{session_id}."""
```

**Маппинг event_type → title/body (для ФТ 10.1):**

| EventBus event | event_type | title (ru) | body (ru) |
|---------------|------------|------------|-----------|
| session.started | session_started | Сессия запущена | {strategy_name}: {ticker} ({timeframe}) |
| session.stopped | session_stopped | Сессия остановлена | {strategy_name}: {ticker} |
| order.placed | order_placed | Ордер выставлен | {ticker}: {direction} {volume} лот(ов) |
| trade.filled | trade_filled | Сделка исполнена | {ticker}: {direction} по {price} ₽ |
| trade.closed | trade_closed | Сделка закрыта | {ticker}: P&L {pnl} ₽ |
| cb.triggered | cb_triggered | Circuit Breaker сработал | {signal}: {reason} |

## Задача 1.2: Notification Pydantic-схемы

В `app/notification/schemas.py`:

```python
from pydantic import BaseModel, ConfigDict
from datetime import datetime

class NotificationResponse(BaseModel):
    id: int
    event_type: str
    title: str
    body: str | None
    severity: str
    is_read: bool
    created_at: datetime
    related_entity_type: str | None = None
    related_entity_id: int | None = None
    model_config = ConfigDict(from_attributes=True)

class NotificationSettingResponse(BaseModel):
    event_type: str
    telegram_enabled: bool
    email_enabled: bool
    in_app_enabled: bool
    model_config = ConfigDict(from_attributes=True)

class NotificationSettingUpdateRequest(BaseModel):
    telegram_enabled: bool | None = None
    email_enabled: bool | None = None
    in_app_enabled: bool | None = None

class UnreadCountResponse(BaseModel):
    count: int
```

## Задача 1.3: REST API эндпоинты

В `app/notification/router.py` добавь:

```python
@router.get("/", response_model=list[NotificationResponse])
async def get_notifications(
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[NotificationResponse]:
    """Список уведомлений пользователя, отсортированных по created_at DESC."""

@router.get("/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UnreadCountResponse:
    """Количество непрочитанных уведомлений."""

@router.patch("/{notification_id}/read")
async def mark_as_read(
    notification_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Пометить уведомление как прочитанное."""

@router.put("/read-all")
async def mark_all_read(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Пометить все уведомления как прочитанные."""

@router.get("/settings", response_model=list[NotificationSettingResponse])
async def get_notification_settings(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[NotificationSettingResponse]:
    """Настройки уведомлений пользователя по event_type."""

@router.put("/settings/{event_type}")
async def update_notification_setting(
    event_type: str,
    body: NotificationSettingUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Обновить настройку для конкретного event_type (upsert)."""
```

## Задача 1.4: WebSocket bridge для notifications

В `app/notification/ws.py` (новый файл) или расширь существующий WS-мультиплексор в `app/backtest/ws.py`:

```python
async def notification_ws_handler(websocket: WebSocket, user_id: int):
    """WebSocket endpoint для push-уведомлений.
    
    Подписывается на EventBus канал notifications:{user_id}.
    Отправляет каждое событие notification.new клиенту.
    При disconnect — отписывается.
    """
```

**Важно:** текущий WS-мультиплексор уже работает на `/ws?token=...` и поддерживает каналы `market:{ticker}:{tf}`, `trades:{session_id}`, `backtest:{id}`. Frontend `useWebSocket.ts` подключается к нему. Не создавай отдельный WS-endpoint — **интегрируй** канал `notifications:{user_id}` в существующий мультиплексор. Клиент подписывается через JSON-сообщение `{"action": "subscribe", "channel": "notifications"}` (user_id берётся из JWT-токена).

## Задача 1.5: Recovery — расширение restore_all для real-сессий

В `app/trading/runtime.py` расширь метод `restore_all()`:

```python
async def restore_all(self, sessions: list[TradingSession]) -> None:
    """Восстановление всех активных сессий после рестарта.
    
    Текущая логика (paper-only, уже работает):
    - Фильтрует status == "active" (paused пропускает)
    - Вызывает self.start(session) для каждой
    
    НОВОЕ (real-сессии, задача 6.4):
    Для каждой real-сессии (mode == "real"):
    1. Получить broker_account из БД по session.broker_account_id
    2. Вызвать TInvestAdapter.get_real_positions(account_id, strategy_tickers, strategy_figis)
    3. Сравнить с LiveTrade (status="filled") в БД:
       - Если позиция закрыта на стороне брокера, а у нас "filled" → обновить trade.status="closed", trade.exit_price=0
       - Если объём изменился → обновить filled_lots
    4. Если расхождения найдены:
       - Поставить сессию на паузу (status="paused")
       - Создать notification: event_type="recovery_mismatch", severity="critical"
    5. Если расхождений нет → вызвать self.start(session) как обычно
    
    Также:
    - Для ВСЕХ восстановленных сессий (paper и real) — создать notification:
      event_type="session_recovered", severity="info",
      body: f"Сессия {session.strategy_name} восстановлена. Время простоя: {downtime}"
    - downtime = now() - max(session.last_signal_at, session.started_at)
    """
```

**Для recovery подписки на котировки** (ФТ 17.7 п.2):
`StreamManager.subscribe()` требует `api_key`. Получить его из `BrokerAccount.encrypted_api_key` → `decrypt()`. Эта логика уже есть в `TradingSessionManager.start_session()` — переиспользуй её.

## Задача 1.6: Graceful Shutdown — расширение

В `app/trading/runtime.py` расширь `shutdown()` и в `app/main.py` расширь `lifespan`:

```python
# runtime.py
async def shutdown(self) -> None:
    """Graceful shutdown — корректная остановка всех сессий.
    
    Текущая логика (уже работает):
    - Вызывает stop() для всех активных listener'ов
    
    НОВОЕ (задача 6.5):
    1. Установить self._shutting_down = True
    2. Для каждой активной сессии:
       a. Обновить status → "suspended" в БД (не "stopped"!)
       b. Вызвать stop() (отписка от EventBus)
    3. Дождаться завершения текущих ордеров (timeout 30s):
       - Проверить LiveTrade.status == "pending" — ждать max 30s
    4. Создать notification: event_type="system_shutdown", severity="warning",
       body="Система остановлена для обслуживания"
    5. Закрыть StreamManager: await stream_manager.unsubscribe_all()
    """

# main.py lifespan (расширить finally блок)
finally:
    logger.info("Shutdown: saving session states...")
    await session_runtime.shutdown()  # уже вызывается, но теперь с новой логикой
    logger.info("Shutdown: closing stream manager...")
    await stream_manager.unsubscribe_all()
    await close_db()
```

## Задача 1.7: Интеграция NotificationService в lifespan

В `app/main.py` добавь создание `NotificationService` и подписку на события сессий:

```python
# В lifespan, после restore_all:
notification_service = NotificationService(AsyncSessionLocal)
fastapi_app.state.notification_service = notification_service

# Для каждой восстановленной active-сессии — слушать events:
for session in active_sessions:
    if session.status == "active":
        user_id = await _resolve_user_id(session)  # из runtime.py
        await notification_service.listen_session_events(session.id, user_id)
```

Также в `TradingSessionManager.start_session()` после `runtime.start()` — вызвать `notification_service.listen_session_events()`.

# Тесты

```
tests/
├── test_notification/
│   ├── test_notification_service.py   # create_notification, listen_session_events, маппинг событий
│   ├── test_notification_router.py    # CRUD endpoints, auth, pagination
│   └── test_notification_ws.py        # WS bridge: subscribe, receive, disconnect
├── test_trading/
│   ├── test_runtime_recovery.py       # restore_all с real-сессиями, расхождения позиций
│   └── test_runtime_shutdown.py       # graceful shutdown, pending orders timeout
```

**Минимум:** 12 тестов:
- 4 на NotificationService (create, маппинг, settings, dispatch_external stub)
- 3 на REST API (get, unread-count, mark-read)
- 2 на WS bridge (subscribe + receive, disconnect)
- 2 на Recovery (paper ok, real mismatch → pause)
- 1 на Shutdown (sessions → suspended, pending orders wait)

**Фикстуры:** `db_session`, `test_user`, `event_bus` (из `app/common/event_bus.py`)

# ⚠️ Integration Verification Checklist

- [ ] `grep -rn "NotificationService(" app/` — инстанциируется в `main.py` lifespan
- [ ] `grep -rn "create_notification(" app/` — вызывается из `runtime.py` (recovery) и `service.py`
- [ ] `grep -rn "listen_session_events(" app/` — вызывается из `main.py` lifespan и `engine.py` start_session
- [ ] `grep -rn "notifications:{" app/` — EventBus publish в service.py + WS subscribe в ws.py/мультиплексоре
- [ ] `grep -rn "notification_service" app/main.py` — сервис доступен через `app.state`
- [ ] REST endpoints зарегистрированы: `GET /notifications`, `GET /unread-count`, `PATCH /{id}/read`, `PUT /read-all`, `GET /settings`, `PUT /settings/{event_type}`
- [ ] WS канал `notifications:{user_id}` интегрирован в мультиплексор `/ws`

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.
Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-1_report.md`.

# Alembic-миграция (если применимо)

Модели Notification, TelegramLink, UserNotificationSetting уже определены в `models.py`. Проверь:
```bash
alembic upgrade head  # убедиться, что таблицы создаются
```
Если миграции нет — создай:
```bash
alembic revision --autogenerate -m "add notification tables"
alembic upgrade head && alembic downgrade -1 && alembic upgrade head
```

# Чеклист перед сдачей

- [ ] Все задачи 1.1–1.7 реализованы
- [ ] `ruff check .` → 0 errors
- [ ] `mypy app/ --ignore-missing-imports` → 0 errors
- [ ] `pytest tests/` → 0 failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-1_report.md`
- [ ] **Cross-DEV contracts подтверждены:** NotificationService API, REST endpoints, WS канал
- [ ] Recovery: real-сессии сверяются с брокером, расхождения → pause + notification
- [ ] Shutdown: сессии → suspended (не stopped!), pending orders timeout 30s
