---
sprint: 4
agent: DEV-4
role: Backend (BACK1) — Backtest API + WebSocket Progress
wave: 2
depends_on: [DEV-3 (Backtest Engine)]
---

# Роль

Ты — Backend-разработчик #4 (senior). Реализуй REST API для бэктестинга и прогресс бэктеста через WebSocket.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11
2. Backtest Engine реализован: app.backtest.engine.BacktestEngine работает
3. Backtest Service реализован: app.backtest.service.BacktestService работает
4. Модели backtests, backtest_trades — в БД
5. WebSocket endpoint /ws уже настроен (если нет — создать)
6. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-4 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Задачи

## 1. Backtest REST API (app/backtest/router.py)

Из ТЗ (секция 4.3):

```
POST   /api/v1/backtests
       Body: {
           strategy_version_id: int,
           ticker: str,
           timeframe: str,        # '1m'|'5m'|'15m'|'1h'|'4h'|'D'|'W'|'M'
           date_from: str,        # "2021-01-01"
           date_to: str,          # "2026-01-01"
           initial_capital: float,
           commission_pct: float,
           slippage_value: float,
           slippage_mode: str     # 'pct' | 'points'
       }
       Response: 202 { backtest_id, status: "running" }

GET    /api/v1/backtests/{id}
       Response: 200 { backtest with all metrics }

GET    /api/v1/backtests/{id}/trades
       Query: ?page=1&per_page=50&sort_by=entry_date&order=desc
       Response: 200 { items: [...], total, page, per_page }

GET    /api/v1/backtests/{id}/equity-curve
       Response: 200 { points: [{timestamp, equity, drawdown}] }

DELETE /api/v1/backtests/{id}
       Response: 204
```

### 1.1 Запуск бэктеста (POST)

```python
@router.post("/", status_code=202)
async def create_backtest(params: BacktestCreate, ...):
    """
    1. Валидация: strategy_version существует, принадлежит user
    2. Валидация: период >= 30 дней
    3. Валидация: стратегия валидна (код без ошибок) — решение #5 из project_state
    4. Создать запись в БД (status='running')
    5. Запустить BacktestEngine в background task
    6. Вернуть 202 { backtest_id, status: "running" }
    """
```

**Background task** — `asyncio.create_task` или `BackgroundTasks`:

```python
async def _run_backtest_task(backtest_id: int, params: BacktestCreate):
    try:
        result = await engine.run(...)
        # Сохранить метрики, trades, equity_curve в БД
        # Отправить WebSocket event: backtest.completed
    except Exception as e:
        # Обновить status='failed', error_message
        # Отправить WebSocket event: backtest.failed
```

### 1.2 Валидация перед запуском

Из project_state (решение #5):
- Бэктест нельзя запустить если код устарел (блоки ≠ код) → 422
- Бэктест нельзя запустить если код содержит ошибки → 422
- Кнопка disabled + tooltip с причиной (frontend)

```python
async def _validate_strategy(version_id: int, db: AsyncSession) -> list[str]:
    """Проверить, что стратегия валидна для запуска бэктеста.
    Возвращает список ошибок (пустой = ОК)."""
```

## 2. WebSocket Progress (app/backtest/ws.py)

### 2.1 WebSocket канал

Из ТЗ (секция 4.12): канал `backtest:{backtest_id}`:

```python
# Формат сообщений:
# Прогресс:
{
    "channel": "backtest:789",
    "event": "backtest.progress",
    "data": {
        "backtest_id": 789,
        "progress_pct": 67.5,
        "current_date": "2023-06-15",
        "elapsed_seconds": 12
    }
}

# Завершение:
{
    "channel": "backtest:789",
    "event": "backtest.completed",
    "data": {
        "backtest_id": 789,
        "net_profit_pct": 15.2,
        "total_trades": 127,
        "sharpe_ratio": 1.23
    }
}

# Ошибка:
{
    "channel": "backtest:789",
    "event": "backtest.failed",
    "data": {
        "backtest_id": 789,
        "error": "Timeout exceeded"
    }
}
```

### 2.2 Event Bus (app/common/event_bus.py)

Если event bus ещё не реализован — создать простой in-memory pub/sub:

```python
class EventBus:
    """Simple in-memory pub/sub for WebSocket events."""

    async def publish(self, channel: str, event: str, data: dict) -> None:
        """Отправить событие всем подписчикам канала."""

    async def subscribe(self, channel: str) -> AsyncGenerator[dict, None]:
        """Подписаться на канал. Yield events."""

    async def unsubscribe(self, channel: str, subscriber_id: str) -> None:
        """Отписаться от канала."""
```

### 2.3 WebSocket Handler

```python
@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    Мультиплексированный WebSocket.
    Клиент отправляет:
      {"action": "subscribe", "channel": "backtest:789"}
      {"action": "unsubscribe", "channel": "backtest:789"}
    Сервер пушит события подписанных каналов.
    """
```

### 2.4 Интеграция с BacktestEngine

Progress callback из BacktestEngine должен публиковать в EventBus:

```python
async def progress_callback(pct: float, current_date: date):
    await event_bus.publish(
        channel=f"backtest:{backtest_id}",
        event="backtest.progress",
        data={"progress_pct": pct, "current_date": str(current_date)}
    )
```

## 3. Регистрация роутера

```python
app.include_router(backtest_router, prefix="/api/v1/backtests", tags=["backtests"])
```

# Тесты (tests/test_backtest/test_api.py)

Минимум **20 тестов**:

1. **REST API** (10): POST create (success, invalid strategy, invalid period, code errors), GET by id, GET trades (pagination, sorting), GET equity-curve, DELETE, 404 handling
2. **Validation** (3): code outdated, code has errors, valid code
3. **WebSocket** (4): subscribe, receive progress, receive completed, receive failed
4. **EventBus** (3): publish/subscribe, multiple subscribers, unsubscribe

Для тестов — mock BacktestEngine (не запускать реальный Backtrader).

# Ветка

```
git checkout -b s4/backtest-api develop
```

# Критерии приёмки

- [ ] POST /backtests → 202 + background task
- [ ] GET /backtests/{id} → метрики и параметры
- [ ] GET /backtests/{id}/trades → пагинация + сортировка
- [ ] GET /backtests/{id}/equity-curve → массив точек
- [ ] DELETE /backtests/{id} → 204
- [ ] Валидация стратегии перед запуском (решение #5)
- [ ] WebSocket: подписка на канал backtest:{id}
- [ ] WebSocket: прогресс, completed, failed events
- [ ] EventBus: pub/sub работает
- [ ] ≥20 тестов, 0 failures
- [ ] Регрессия: все существующие тесты проходят
