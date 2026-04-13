---
sprint: 5
agent: DEV-3
role: Backend Finance (BACK2) — Bond Service + Tax Export
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #3 (senior, финансовые расчёты). Реализуй Bond Service (расчёт НКД, параметры облигаций), Corporate Action Handler (дивиденды, купоны, сплиты) и Tax Report Generator (FIFO, 3-НДФЛ экспорт).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Модель CorporateAction: app/corporate_actions/models.py (уже есть)
3. Сервис corporate_actions: app/corporate_actions/service.py (заглушка)
4. Market Data Service: app/market_data/service.py (работает)
5. Модели LiveTrade, DailyStat: app/trading/models.py (уже есть)
6. ТЗ: секции 3.18 (bond_info_cache), 5.6.5 (BondService), 5.13 (Tax Report)
7. openpyxl установлен (для xlsx экспорта) — проверить pyproject.toml
8. pytest tests/ проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-3 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст

## Существующая модель CorporateAction (app/corporate_actions/models.py)

```python
class CorporateAction(Base):
    __tablename__ = "corporate_actions"
    # id, ticker, action_type, ex_date, record_date, amount, currency, description, created_at
```

**Внимание:** в ТЗ (3.19) предусмотрены дополнительные поля, которых нет в текущей модели:
- `ratio_from`, `ratio_to` — для сплитов
- `amount_per_share` — дивиденд/купон на акцию
- `processed` — обработано ли
- Unique constraint и Index

Нужно обновить модель до спецификации ТЗ.

## Таблица bond_info_cache (ТЗ 3.18)

```
bond_info_cache
├── id: Integer, PK
├── ticker: String(20), UNIQUE, NOT NULL
├── isin: String(20), NOT NULL
├── nominal: Numeric(18, 2), NOT NULL           -- Номинал облигации
├── coupon_rate: Numeric(10, 4), NULLABLE       -- Ставка купона (% годовых)
├── coupon_frequency: Integer, NULLABLE          -- Количество выплат в год
├── maturity_date: Date, NULLABLE                -- Дата погашения
├── coupon_dates_json: Text, NULLABLE            -- JSON массив дат ближайших купонов
├── updated_at: DateTime, NOT NULL
```

## LiveTrade — поля для облигаций

Уже в модели: `nkd_entry`, `nkd_exit` (Numeric(18, 2), nullable).

## MarketDataService (app/market_data/service.py)

Уже работает: HTTP-запросы к MOEX ISS API. Можно добавить bond-специфичные методы сюда или в отдельный `bond_service.py`.

# Задачи

## Задача 1: Bond Info модель (app/market_data/models.py)

Добавить модель `BondInfoCache`:

```python
class BondInfoCache(Base):
    __tablename__ = "bond_info_cache"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ticker: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    isin: Mapped[str] = mapped_column(String(20), nullable=False)
    nominal: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    coupon_rate: Mapped[Decimal | None] = mapped_column(Numeric(10, 4), nullable=True)
    coupon_frequency: Mapped[int | None] = mapped_column(Integer, nullable=True)
    maturity_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    coupon_dates_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now(), nullable=False
    )
```

## Задача 2: Bond Service (app/market_data/bond_service.py)

```python
class BondService:
    """Работа с облигациями: расчёт НКД, параметры выпуска (ТЗ 5.6.5)."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_bond_info(self, ticker: str) -> BondInfoCache:
        """Получить параметры облигации.
        1. Проверить кеш (bond_info_cache, обновление раз в сутки)
        2. Если нет или устарел: запросить MOEX ISS API
           - /iss/securities/{ticker}.json — основная информация
           - /iss/securities/{ticker}/bondization.json — купонное расписание
        3. Альтернативно: T-Invest API GetBondCoupons
        4. Сохранить в кеш"""

    def calculate_nkd(self, bond: BondInfoCache, calc_date: date) -> Decimal:
        """Формула НКД:
        НКД = (Номинал × Ставка_купона / 100) × (Дней_с_последнего_купона / Дней_в_купонном_периоде)

        1. Определить даты последнего и следующего купона из coupon_dates_json
        2. days_since = (calc_date - last_coupon_date).days
        3. days_in_period = (next_coupon_date - last_coupon_date).days
        4. coupon_amount = nominal * coupon_rate / 100 / coupon_frequency
        5. nkd = coupon_amount * days_since / days_in_period
        6. Округлить до 2 знаков (Decimal)
        """

    async def get_nkd_at_date(self, ticker: str, calc_date: date) -> Decimal:
        """Обёртка: get_bond_info + calculate_nkd."""

    async def get_coupon_schedule(self, ticker: str) -> list[dict]:
        """Расписание купонов: дата, сумма, статус (выплачен/предстоит)."""
```

**Источники данных MOEX ISS для облигаций:**
- `/iss/securities/{ticker}.json` → секция `description`: FACEVALUE, COUPONVALUE, COUPONPERIOD, MATDATE
- `/iss/securities/{ticker}/bondization.json` → секция `coupons`: coupondate, value, valueprc

## Задача 3: Обновить CorporateAction модель

Обновить `app/corporate_actions/models.py` до спецификации ТЗ 3.19:

```python
class CorporateAction(Base):
    __tablename__ = "corporate_actions"
    __table_args__ = (
        UniqueConstraint("ticker", "action_type", "ex_date", name="uq_corp_action"),
        Index("idx_corp_ticker", "ticker", "ex_date"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ticker: Mapped[str] = mapped_column(String(20), nullable=False)
    action_type: Mapped[str] = mapped_column(String(30), nullable=False)  # 'split', 'dividend', 'coupon'
    ex_date: Mapped[date] = mapped_column(Date, nullable=False)  # было nullable
    record_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Для сплитов:
    ratio_from: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ratio_to: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Для дивидендов/купонов:
    amount_per_share: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    amount: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    currency: Mapped[str] = mapped_column(String(10), default="RUB", server_default="RUB")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    processed: Mapped[bool] = mapped_column(default=False, server_default="0")
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), nullable=False)
```

## Задача 4: Corporate Action Handler (app/corporate_actions/service.py)

```python
class CorporateActionService:
    """Обработка корпоративных действий (ТЗ 5.12, ФТ 6.4)."""

    async def process_split(self, action: CorporateAction) -> None:
        """Сплит: корректировка цены входа и объёма открытых позиций.
        1. Найти все открытые позиции по ticker
        2. new_volume = old_volume * ratio_to / ratio_from
        3. new_entry_price = old_entry_price * ratio_from / ratio_to
        4. Записать в audit_log
        5. Уведомление пользователю"""

    async def process_dividend(self, action: CorporateAction) -> None:
        """Дивиденд: начисление в P&L.
        1. Найти открытые позиции по ticker
        2. dividend_total = amount_per_share × volume
        3. Для Paper: увеличить PaperPortfolio.balance
        4. Записать в DailyStat.pnl
        5. Уведомление"""

    async def process_coupon(self, action: CorporateAction) -> None:
        """Купон по облигации: аналогично дивиденду,
        с учётом НКД через BondService.calculate_nkd()."""

    async def detect_corporate_actions(self, tickers: list[str]) -> list[CorporateAction]:
        """Проверить MOEX ISS / T-Invest API на новые корп. действия.
        Вызывается по расписанию (scheduler)."""

    async def process_pending(self) -> None:
        """Обработать все непроцессированные действия (processed=False)."""
```

## Задача 5: Tax модуль (новый: app/tax/)

### 5.1 Модели (app/tax/models.py)

```python
class TaxReport(Base):
    __tablename__ = "tax_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    format: Mapped[str] = mapped_column(String(10), nullable=False)  # "xlsx", "csv"
    status: Mapped[str] = mapped_column(String(20), default="pending")  # pending, ready, error
    file_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    total_profit: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    total_loss: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    total_commission: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    taxable_base: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

class TaxLot(Base):
    __tablename__ = "tax_lots"
    __table_args__ = (
        Index("idx_tax_lot_ticker", "ticker", "opened_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    ticker: Mapped[str] = mapped_column(String(20), nullable=False)
    instrument_type: Mapped[str] = mapped_column(String(20), nullable=False)  # share, bond, etf
    direction: Mapped[str] = mapped_column(String(10), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    remaining_quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    entry_price: Mapped[Decimal] = mapped_column(Numeric(18, 8), nullable=False)
    commission_entry: Mapped[Decimal] = mapped_column(Numeric(18, 2), default=0)
    nkd_entry: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    opened_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    exit_price: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    commission_exit: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    nkd_exit: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    realized_pnl: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
```

### 5.2 Service (app/tax/service.py)

```python
class TaxReportService:
    """Генерация налогового отчёта 3-НДФЛ (ТЗ 5.13, ФТ 18.2)."""

    async def generate_report(self, user_id: int, year: int, format: str,
                               include_shares: bool = True,
                               include_bonds: bool = True,
                               include_etf: bool = True) -> TaxReport:
        """Полный цикл:
        1. Загрузить все closed LiveTrade за указанный год
        2. Построить FIFO-очередь (TaxLot)
        3. Рассчитать финансовый результат
        4. Сгенерировать файл (xlsx или csv)
        5. Сохранить TaxReport в БД"""

    def _build_fifo_queue(self, trades: list[LiveTrade]) -> list[TaxLot]:
        """FIFO matching:
        - Для каждой продажи: закрыть самый ранний непроданный лот
        - При частичном исполнении: разделить лот
        - Для облигаций: отдельно учитывать ценовую составляющую и НКД"""

    def _calculate_tax_base(self, lots: list[TaxLot]) -> dict:
        """Расчёт налогооблагаемой базы:
        - Раздельно: акции, облигации (+ купоны), ETF/БПИФ
        - Комиссии уменьшают базу
        - Для облигаций: НКД считается отдельной строкой
        - Ставка: 13% (до 5M ₽), 15% (свыше 5M ₽)"""

    async def _export_xlsx(self, report: TaxReport, lots: list[TaxLot]) -> str:
        """Экспорт в Excel через openpyxl.
        Колонки: дата сделки, тикер, ISIN, направление, цена покупки,
        цена продажи, объём (лоты/штуки), комиссия, финансовый результат.
        Группировка по типу инструмента.
        Итоговая строка с суммами."""

    async def _export_csv(self, report: TaxReport, lots: list[TaxLot]) -> str:
        """CSV экспорт с тем же набором колонок."""
```

### 5.3 Schemas (app/tax/schemas.py)

```python
class TaxReportRequest(BaseModel):
    year: int = Field(ge=2020, le=2030)
    format: Literal["xlsx", "csv"] = "xlsx"
    include_shares: bool = True
    include_bonds: bool = True
    include_etf: bool = True

class TaxReportResponse(BaseModel):
    id: int
    year: int
    status: str
    total_profit: Decimal | None
    total_loss: Decimal | None
    total_commission: Decimal | None
    taxable_base: Decimal | None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class TaxReportDownloadResponse(BaseModel):
    download_url: str
    filename: str
```

### 5.4 Router (app/tax/router.py)

```python
router = APIRouter(prefix="/api/v1/tax", tags=["tax"])

POST /reports          — сгенерировать отчёт
GET  /reports          — список отчётов пользователя
GET  /reports/{id}     — детали отчёта
GET  /reports/{id}/download — скачать файл
```

### 5.5 __init__.py

Создать `app/tax/__init__.py` (пустой).

## Задача 6: Роутер для Corporate Actions

```python
# app/corporate_actions/router.py
router = APIRouter(prefix="/api/v1/corporate-actions", tags=["corporate-actions"])

GET /           — список корп. действий (фильтр: ticker, type, date_from, date_to)
GET /{id}       — детали
POST /detect    — принудительный запуск детекции (admin)
```

## Задача 7: Интеграция

### Bond endpoints в Market Data Router

Добавить в `app/market_data/router.py`:
```python
GET /api/v1/market-data/bonds/{ticker}/info    — информация об облигации
GET /api/v1/market-data/bonds/{ticker}/nkd     — текущий НКД
GET /api/v1/market-data/bonds/{ticker}/coupons — расписание купонов
```

### Регистрация роутеров в main.py

Добавить `tax.router` и `corporate_actions.router` в `app/main.py`.

# Тесты

Минимум 20 тестов:

```
tests/
├── test_bond_service/
│   ├── test_nkd_calculation.py   # Формула НКД: разные периоды, граничные случаи
│   ├── test_bond_info.py         # Кеш, обновление, MOEX ISS парсинг
│   └── test_coupon_schedule.py   # Расписание купонов
├── test_corporate_actions/
│   ├── test_split.py             # Корректировка объёма и цены
│   ├── test_dividend.py          # Начисление в P&L
│   └── test_coupon.py            # Купон + НКД
├── test_tax/
│   ├── test_fifo.py              # FIFO matching: простой, partial, multiple
│   ├── test_tax_calculation.py   # Налогооблагаемая база, 13%/15%
│   ├── test_export_xlsx.py       # Генерация xlsx
│   ├── test_export_csv.py        # Генерация csv
│   └── test_router.py            # HTTP endpoints
```

Ключевые тестовые сценарии FIFO:
1. Простой: купил 100, продал 100 → один лот
2. Частичный: купил 100, продал 50 → лот с remaining_quantity=50
3. Множественный: купил 50 (по 100), купил 50 (по 110), продал 70 → FIFO: 50@100 + 20@110
4. Облигации: НКД при покупке уменьшает финрез, НКД при продаже увеличивает

# Alembic-миграция

Создать миграции для:
- `bond_info_cache` (новая таблица)
- `corporate_actions` (обновление: новые поля, constraints)
- `tax_reports` (новая)
- `tax_lots` (новая)

# Чеклист перед сдачей

- [ ] BondInfoCache модель + миграция
- [ ] BondService: get_bond_info, calculate_nkd, get_nkd_at_date, get_coupon_schedule
- [ ] Формула НКД корректна (проверить на реальных облигациях)
- [ ] CorporateAction модель обновлена до ТЗ 3.19
- [ ] CorporateActionService: split, dividend, coupon, detect, process_pending
- [ ] TaxReport + TaxLot модели + миграции
- [ ] TaxReportService: FIFO, расчёт базы, xlsx/csv экспорт
- [ ] Роутеры зарегистрированы в main.py
- [ ] 20+ тестов, все зелёные
- [ ] pytest всего проекта: 0 failures
