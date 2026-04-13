---
sprint: 5
agent: DEV-2
role: Backend Security (SEC) — Circuit Breaker
wave: 2
depends_on: [DEV-1]
---

# Роль

Ты — Backend-разработчик по безопасности (SEC). Реализуй полную логику Circuit Breaker — механизм автоматического ограничения торговли при превышении лимитов риска. Интеграция с Trading Engine (DEV-1).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Trading Engine реализован: app/trading/engine.py существует, OrderManager работает
2. Модель CircuitBreakerEvent: app/circuit_breaker/models.py (уже есть)
3. Модели TradingSession, LiveTrade, DailyStat: app/trading/models.py
4. Event Bus: app/common/event_bus.py (работает)
5. User модель: app/auth/models.py — поля risk_daily_loss_pct, risk_max_drawdown_pct, risk_max_position_pct
6. pytest tests/ проходит (0 failures)
```

**Если DEV-1 не завершён — сообщи:** "БЛОКЕР: Trading Engine не реализован. DEV-2 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст

## Существующая модель (app/circuit_breaker/models.py)

```python
class CircuitBreakerEvent(Base):
    __tablename__ = "circuit_breaker_events"
    # id, user_id (FK users.id), event_type, trigger_value, limit_value,
    # action_taken, session_id (FK trading_sessions.id nullable), details, created_at
```

## Поля риск-менеджмента в User (app/auth/models.py)

Прочитай файл — там есть поля:
- `risk_daily_loss_pct` — макс. дневной убыток (% от баланса)
- `risk_max_drawdown_pct` — макс. просадка (% от пикового equity)
- `risk_max_position_pct` — макс. размер одной позиции (% от баланса)

## Спецификация из ТЗ (раздел 5.8)

```python
class CircuitBreakerService:
    async def check_before_order(self, session, signal) -> CheckResult:
        checks = [
            self._check_daily_loss_limit(session),
            self._check_max_drawdown(session),
            self._check_position_size_limit(signal),
            self._check_daily_trade_limit(session),
            self._check_duplicate_instrument(session, signal),
            self._check_cooldown(session),
            self._check_trading_hours(signal),
            self._check_short_block(signal),
            self._check_insufficient_funds_streak(session),
        ]
```

## Спецификация из ФТ (раздел 12.4)

- **Дневной лимит убытков:** при превышении — ВСЕ стратегии на паузу, уведомление. Возобновление — только вручную.
- **Max drawdown:** % от пикового баланса. При достижении — все на паузу.
- **Лимит размера позиции:** макс. сумма одного ордера. Блокировка + уведомление.
- **Лимит сделок в день:** по всем стратегиям суммарно. Блокировка до следующего дня.
- **Запрет разнонаправленной торговли:** нельзя открыть противоположную позицию на том же инструменте + счёте. В фазе 1 Short блокируется полностью.
- **Cooldown:** мин. интервал между сигналами входа одной стратегии.
- **Нехватка средств:** `consecutive_fund_skips >= 3` → пауза + уведомление.

# Задачи

## Задача 1: CircuitBreakerConfig модель (app/circuit_breaker/models.py)

Добавить модель конфигурации (per-user или per-session override):

```python
class CircuitBreakerConfig(Base):
    __tablename__ = "circuit_breaker_configs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    session_id: Mapped[int | None] = mapped_column(
        ForeignKey("trading_sessions.id"), nullable=True
    )  # NULL = глобальные настройки пользователя, NOT NULL = override для сессии

    daily_loss_limit_pct: Mapped[Decimal | None] = mapped_column(Numeric(10, 4), nullable=True)
    daily_loss_limit_fixed: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    max_drawdown_pct: Mapped[Decimal | None] = mapped_column(Numeric(10, 4), nullable=True)
    max_position_size: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    daily_trade_limit: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cooldown_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    trading_hours_start: Mapped[str | None] = mapped_column(String(5), nullable=True)  # "10:00"
    trading_hours_end: Mapped[str | None] = mapped_column(String(5), nullable=True)    # "18:45"
    block_shorts: Mapped[bool] = mapped_column(default=True, server_default="1")

    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime, onupdate=func.now())
```

## Задача 2: Circuit Breaker Engine (app/circuit_breaker/engine.py)

```python
@dataclass
class CheckResult:
    blocked: bool
    reason: str | None = None
    event_type: str | None = None

class CircuitBreakerEngine:
    """Ядро проверок. Singleton per user (asyncio.Lock для race conditions)."""

    def __init__(self, db: AsyncSession, user_id: int):
        self.db = db
        self.user_id = user_id
        self._lock = asyncio.Lock()

    async def check_before_order(self, session: TradingSession, signal: Signal) -> CheckResult:
        """Последовательно проверяет все ограничения.
        Первое сработавшее — блокирует ордер.
        ВАЖНО: использовать asyncio.Lock для предотвращения race conditions."""
        async with self._lock:
            # ... все проверки

    async def _check_daily_loss_limit(self, session) -> CheckResult:
        """Расчёт дневных убытков (ТЗ 5.8):
        - SUM(pnl) по live_trades за текущий торговый день
        - + unrealized P&L открытых позиций
        - Начало торгового дня: 10:00 MSK
        - Сброс: 10:00 MSK следующего торгового дня по календарю MOEX
        - Сравнение с user.risk_daily_loss_pct * balance ИЛИ config.daily_loss_limit_fixed
        """

    async def _check_max_drawdown(self, session) -> CheckResult:
        """peak_equity обновляется при каждом закрытии позиции.
        current_drawdown = (peak_equity - current_equity) / peak_equity * 100
        """

    async def _check_position_size_limit(self, signal) -> CheckResult:
        """Сумма ордера не должна превышать config.max_position_size."""

    async def _check_daily_trade_limit(self, session) -> CheckResult:
        """COUNT trades за текущий торговый день ПО ВСЕМ стратегиям пользователя."""

    async def _check_duplicate_instrument(self, session, signal) -> CheckResult:
        """Нельзя открыть позицию в противоположном направлении
        на том же инструменте + том же брокерском счёте."""

    async def _check_cooldown(self, session) -> CheckResult:
        """session.last_signal_at + cooldown_seconds > now() → блок."""

    async def _check_trading_hours(self, signal) -> CheckResult:
        """Проверить, что текущее время в пределах торговых часов.
        По умолчанию: 10:00-18:45 MSK (основная сессия MOEX)."""

    async def _check_short_block(self, signal) -> CheckResult:
        """Фаза 1: блокировать все Short-ордера."""

    async def _check_insufficient_funds_streak(self, session) -> CheckResult:
        """consecutive_fund_skips >= 3 → пауза."""
```

**При срабатывании (`_trigger`):**
1. Записать `CircuitBreakerEvent` в БД
2. Поставить сессию (или все сессии) на паузу через `TradingSessionManager`
3. Опубликовать в EventBus: `notifications` канал + `trades:{session_id}` канал
4. Для daily_loss и max_drawdown: пауза ВСЕХ стратегий пользователя

## Задача 3: Schemas (app/circuit_breaker/schemas.py)

```python
class CircuitBreakerConfigRequest(BaseModel):
    daily_loss_limit_pct: Decimal | None = None
    daily_loss_limit_fixed: Decimal | None = None
    max_drawdown_pct: Decimal | None = None
    max_position_size: Decimal | None = None
    daily_trade_limit: int | None = None
    cooldown_seconds: int | None = None
    trading_hours_start: str | None = None
    trading_hours_end: str | None = None
    block_shorts: bool = True

class CircuitBreakerConfigResponse(BaseModel):
    # все поля + id, user_id, session_id, timestamps
    model_config = ConfigDict(from_attributes=True)

class CircuitBreakerEventResponse(BaseModel):
    id: int
    event_type: str
    trigger_value: Decimal
    limit_value: Decimal
    action_taken: str
    session_id: int | None
    details: str | None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
```

## Задача 4: Router (app/circuit_breaker/router.py)

```python
router = APIRouter(prefix="/api/v1/circuit-breaker", tags=["circuit-breaker"])

GET    /config                — текущая конфигурация CB пользователя
PUT    /config                — обновить глобальную конфигурацию
PUT    /config/session/{id}   — override для конкретной сессии
GET    /events                — лог срабатываний (пагинация: offset, limit)
GET    /events/session/{id}   — события по конкретной сессии
GET    /status                — текущий статус: сколько сделок сегодня, текущий drawdown, etc.
```

## Задача 5: Service (app/circuit_breaker/service.py)

Оркестрация Router ↔ Engine + CRUD для конфигурации.

## Задача 6: Интеграция с OrderManager

В `app/trading/engine.py` → `OrderManager.process_signal()`:
```python
# Перед размещением ордера:
cb_engine = CircuitBreakerEngine(self.db, user_id)
result = await cb_engine.check_before_order(session, signal)
if result.blocked:
    logger.warning("circuit_breaker_blocked", reason=result.reason)
    return None
```

# Тесты

Минимум 15 тестов в `tests/test_circuit_breaker/`:

```
test_circuit_breaker/
├── test_engine.py       # Каждая проверка отдельно + комбинации
├── test_config.py       # CRUD конфигурации, override
├── test_router.py       # HTTP endpoints
└── test_integration.py  # CB + OrderManager: сигнал → блокировка
```

Ключевые сценарии:
- Дневной убыток: 3 убыточные сделки → порог → блок
- Max drawdown: peak 1M → текущее 850K → 15% drawdown → блок при пороге 10%
- Cooldown: сигнал через 30с после предыдущего при cooldown=60 → блок
- Race condition: 2 параллельных сигнала — только первый должен пройти
- Insufficient funds: 3 пропуска подряд → пауза

# Alembic-миграция

Создать миграцию для `circuit_breaker_configs`.

# Чеклист перед сдачей

- [ ] CircuitBreakerConfig модель + миграция
- [ ] CircuitBreakerEngine: все 9 проверок
- [ ] asyncio.Lock для race conditions
- [ ] Trigger: запись события + пауза сессии + EventBus
- [ ] daily_loss: расчёт по торговому дню (10:00 MSK)
- [ ] Интеграция с OrderManager
- [ ] CRUD конфигурации (router + service)
- [ ] 15+ тестов, все зелёные
- [ ] pytest всего проекта: 0 failures
