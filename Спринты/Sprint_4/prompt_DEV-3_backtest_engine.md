---
sprint: 4
agent: DEV-3
role: Backend Core (BACK1) — Backtest Engine
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #3 (senior). Реализуй движок бэктестинга: Backtrader wrapper, расчёт метрик, equity curve, benchmark comparison, таблицы БД.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/backtest/ существует (или создать)
3. Code Sandbox (app.sandbox) работает — execute_backtest()
4. Code Generator (app.strategy.code_generator) работает — generate()
5. Market Data (app.market_data) работает — get_candles()
6. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-3 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Паттерны проекта

Существующие модули задают паттерн:
- `models.py` — SQLAlchemy модели с `TimestampMixin`
- `schemas.py` — Pydantic v2
- `service.py` — бизнес-логика (async)
- `router.py` — FastAPI APIRouter

## Code Sandbox (S3)

```python
# app/strategy/sandbox.py (ПРИМЕРНАЯ СТРУКТУРА — прочти реальный файл)
class SandboxExecutor:
    def execute_backtest(self, code: str, data: pd.DataFrame, params: dict) -> BacktestResult:
        # AST анализ → RestrictedPython compile → subprocess с лимитами
```

## Market Data (S2)

```python
# app/market_data/ (ПРИМЕРНАЯ СТРУКТУРА — прочти реальный файл)
async def get_candles(ticker, timeframe, date_from, date_to) -> tuple[list, str]:
    # Возвращает OHLCV данные из кеша или T-Invest API
```

# Задачи

## 1. Таблицы БД (app/backtest/models.py)

### 1.1 Таблица `backtests`

```python
# Из ТЗ, секция 3.6:
# id, strategy_version_id (FK), ticker, timeframe, date_from, date_to,
# initial_capital, commission_pct, slippage_value, slippage_mode,
# params_json, status ('running'|'completed'|'failed'),
# net_profit, net_profit_pct, total_trades, winning_trades, losing_trades,
# win_rate, profit_factor, max_drawdown_pct, sharpe_ratio,
# avg_profit_per_trade, avg_loss_per_trade, avg_trade_duration_bars,
# avg_trade_duration_seconds, benchmark_buy_hold_pct, benchmark_imoex_pct,
# equity_curve_json, error_message, started_at, completed_at
# INDEX: idx_bt_sv (strategy_version_id), idx_bt_ticker (ticker, timeframe)
```

### 1.2 Таблица `backtest_trades`

```python
# Из ТЗ, секция 3.7:
# id, backtest_id (FK, CASCADE), direction, entry_date, entry_price,
# exit_date, exit_price, volume_lots, volume_rub, pnl, pnl_pct,
# commission, duration_bars, duration_seconds
# INDEX: idx_btt_backtest (backtest_id)
```

Alembic-миграция для обеих таблиц.

## 2. Backtrader Wrapper (app/backtest/engine.py)

Основной класс, который оборачивает Backtrader:

```python
class BacktestEngine:
    def __init__(self):
        self.cerebro = None

    async def run(
        self,
        strategy_code: str,
        ticker: str,
        timeframe: str,
        date_from: datetime,
        date_to: datetime,
        initial_capital: Decimal,
        commission_pct: Decimal,
        slippage_value: Decimal,
        slippage_mode: str,  # 'pct' | 'points'
        progress_callback: Callable | None = None,
    ) -> BacktestResult:
        """
        Полный цикл бэктеста:
        1. Загрузить OHLCV данные через market_data
        2. Создать Backtrader Cerebro
        3. Добавить стратегию (из сгенерированного кода)
        4. Настроить broker (capital, commission, slippage)
        5. Добавить analyzers (для метрик)
        6. Запустить через SandboxExecutor
        7. Собрать результаты
        """
```

### 2.1 Загрузка данных

```python
async def _load_data(self, ticker, timeframe, date_from, date_to) -> pd.DataFrame:
    """Загрузить OHLCV через market_data, конвертировать в pandas DataFrame."""
```

### 2.2 Настройка Cerebro

```python
def _setup_cerebro(self, data: pd.DataFrame, initial_capital, commission_pct, slippage) -> bt.Cerebro:
    """
    cerebro = bt.Cerebro()
    cerebro.broker.setcash(initial_capital)
    cerebro.broker.setcommission(commission=commission_pct/100)
    cerebro.adddata(bt.feeds.PandasData(dataname=df))
    cerebro.addanalyzer(...)  # SharpeRatio, DrawDown, TradeAnalyzer, etc.
    """
```

### 2.3 Custom Analyzers

**ProgressAnalyzer** — отправляет прогресс через callback:

```python
class ProgressAnalyzer(bt.Analyzer):
    """Вызывает callback каждые N баров с текущей датой и процентом."""
    def __init__(self):
        self.total_bars = len(self.data)
        self.current_bar = 0

    def next(self):
        self.current_bar += 1
        if self.current_bar % max(1, self.total_bars // 100) == 0:
            pct = self.current_bar / self.total_bars * 100
            self.params.progress_callback(pct, self.data.datetime.date(0))
```

**MetricsCollector** — собирает все метрики после завершения:

```python
class MetricsCollector(bt.Analyzer):
    """Собирает: net_profit, win_rate, profit_factor, sharpe, drawdown, etc."""
```

## 3. Расчёт метрик (app/backtest/metrics.py)

```python
@dataclass
class BacktestMetrics:
    net_profit: Decimal
    net_profit_pct: Decimal
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: Decimal
    profit_factor: Decimal
    max_drawdown_pct: Decimal
    sharpe_ratio: Decimal
    avg_profit_per_trade: Decimal
    avg_loss_per_trade: Decimal
    avg_trade_duration_bars: Decimal
    avg_trade_duration_seconds: Decimal

def calculate_metrics(analyzer_results: dict) -> BacktestMetrics:
    """Извлечь метрики из результатов Backtrader analyzers."""
```

## 4. Equity Curve (app/backtest/equity.py)

```python
@dataclass
class EquityPoint:
    timestamp: datetime
    equity: Decimal
    drawdown: Decimal  # отрицательное значение

class EquityCurveCollector(bt.Observer):
    """Записывает equity и drawdown на каждом баре."""
```

## 5. Benchmark Comparison (app/backtest/benchmark.py)

```python
class BenchmarkCalculator:
    async def calculate_buy_hold(self, data: pd.DataFrame, initial_capital: Decimal) -> Decimal:
        """Buy & Hold return % за период."""

    async def calculate_imoex(self, date_from, date_to, initial_capital: Decimal) -> Decimal:
        """IMOEX return % за период (загрузить данные IMOEX)."""
```

## 6. Backtest Result (app/backtest/schemas.py)

```python
class BacktestResult(BaseModel):
    metrics: BacktestMetrics
    equity_curve: list[EquityPoint]
    trades: list[TradeRecord]
    benchmark_buy_hold_pct: Decimal | None
    benchmark_imoex_pct: Decimal | None

class TradeRecord(BaseModel):
    direction: str
    entry_date: datetime
    entry_price: Decimal
    exit_date: datetime | None
    exit_price: Decimal | None
    volume_lots: int
    volume_rub: Decimal
    pnl: Decimal | None
    pnl_pct: Decimal | None
    commission: Decimal | None
    duration_bars: int | None
    duration_seconds: int | None
```

## 7. Backtest Service (app/backtest/service.py)

```python
class BacktestService:
    async def create_backtest(self, params: BacktestCreate, user_id: int, db: AsyncSession) -> Backtest:
        """Создать запись в БД, запустить engine, сохранить результат."""

    async def get_backtest(self, backtest_id: int, user_id: int, db: AsyncSession) -> Backtest:
        """Получить бэктест по ID."""

    async def get_trades(self, backtest_id: int, page: int, per_page: int, db: AsyncSession) -> list:
        """Список сделок с пагинацией."""

    async def get_equity_curve(self, backtest_id: int, db: AsyncSession) -> list[EquityPoint]:
        """Equity curve из JSON."""

    async def delete_backtest(self, backtest_id: int, user_id: int, db: AsyncSession) -> None:
        """Удалить бэктест (каскадно удалит trades)."""
```

# Тесты (tests/test_backtest/)

Минимум **25 тестов**:

1. **Модели** (5): создание backtests, backtest_trades, FK constraints, каскадное удаление
2. **Engine** (8): setup cerebro, load data (mock), run с простой стратегией (mock Backtrader), progress callback, error handling (timeout, bad code)
3. **Metrics** (5): calculate_metrics с разными наборами данных, edge cases (0 trades, all winning, all losing)
4. **Benchmark** (3): buy_hold calculation, IMOEX (mock)
5. **Service** (4): create_backtest, get_backtest, get_trades, delete_backtest

**ВАЖНО:** Для тестов engine используй mock для market_data и sandbox. НЕ запускай реальный Backtrader в тестах — мокируй результаты.

# Ветка

```
git checkout -b s4/backtest-engine develop
```

# Критерии приёмки

- [ ] Таблицы `backtests` и `backtest_trades` создаются миграцией
- [ ] BacktestEngine запускает стратегию через Backtrader (с sandbox)
- [ ] Все метрики рассчитываются (net_profit, win_rate, sharpe, drawdown, etc.)
- [ ] Equity curve собирается на каждом баре
- [ ] Progress callback вызывается во время выполнения
- [ ] Benchmark: Buy & Hold и IMOEX
- [ ] BacktestService: CRUD операции
- [ ] ≥25 тестов, 0 failures
- [ ] Регрессия: все существующие тесты проходят
