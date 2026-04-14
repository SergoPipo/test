---
sprint: 5_Review
agent: DEV-3
role: "Backend + Frontend — Real Positions & Operations T-Invest (S5R.3)"
wave: 2
depends_on: [DEV-1]
---

# Роль

Ты — Full-stack разработчик S5R, отвечающий за **замену заглушек на реальные позиции и операции T-Invest** в разделе «Счёт». В Sprint 5 раздел «Счёт» был перестроен под реальные брокерские счета T-Invest: балансы (`GET /broker/accounts/balances`) реализованы через `OperationsService.GetPortfolio`, но позиции и операции **остались заглушками**:

```python
# Develop/backend/app/broker/router.py:113-134
return []                         # GET /broker/accounts/{id}/positions
return {"items": [], "total": 0}  # GET /broker/accounts/{id}/operations
```

Адаптер T-Invest уже умеет получать портфель (`client.operations.get_portfolio`) и операции (`client.operations.get_operations`) — нужно написать маппер, подключить роуты и проверить рендер на frontend.

Ты — **поставщик** контрактов **C8, C9** из [execution_order.md](execution_order.md). Твоя задача **независима** от DEV-2 (Live Runtime Loop) по файлам и может выполняться параллельно после завершения DEV-1 (CI cleanup).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Если хотя бы один пункт не выполнен — **НЕ начинай**, верни `БЛОКЕР: <описание>`.

```
1. Окружение: Python >= 3.11, Node >= 18, pnpm >= 9

2. Зависимости предыдущих DEV (S5R):
   - DEV-1 закрыл S5R.1: cd Develop/backend && ruff check . → exit 0
     И cd Develop/frontend && pnpm lint → exit 0
   - Cross-DEV contracts C1, C2, C3 подтверждены DEV-1

3. Существующие файлы:
   - Develop/backend/app/broker/router.py — заглушки строк 113-134
   - Develop/backend/app/broker/service.py — сервис вокруг адаптеров
   - Develop/backend/app/broker/base.py — BaseBrokerAdapter + dataclasses BrokerPosition, BrokerOperation (проверь — возможно их нужно расширить)
   - Develop/backend/app/broker/tinvest/adapter.py — TInvestAdapter с balances через get_portfolio
   - Develop/backend/app/broker/tinvest/mapper.py — существующие маппер-функции
   - Develop/backend/app/trading/models.py — Order (для различения strategy vs external)
   - Develop/frontend/src/components/account/PositionsTable.tsx — уже существует, рендерит mock
   - Develop/frontend/src/components/account/OperationsTable.tsx — уже существует
   - Develop/frontend/src/api/types.ts — BrokerPosition, BrokerOperation типы

4. База данных:
   - Order модель существует, связана с BrokerAccount через account_id
   - BrokerAccount модель существует (one T-Invest account = one record)

5. Внешние сервисы:
   - T-Invest API доступен (тестовый ключ из Develop/backend/.env — спросить у заказчика, не хардкодить)
   - tinkoff-investments SDK установлен (проверено в Sprint 5 preflight)

6. Тесты baseline: pytest tests/broker/ и pnpm test зелёные после S5R.1
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **[Develop/CLAUDE.md](../../Develop/CLAUDE.md)** — **полностью**, особое внимание **«⚠️ Stack Gotchas»**:
   - **Gotcha 1 (Pydantic v2 + Decimal → строка в JSON)** — `BrokerPosition.average_price`, `current_price`, `unrealized_pnl`, `BrokerOperation.amount`, `price` — все Decimal-поля. При сериализации в Pydantic v2 они **должны** быть `str` в JSON (frontend парсит через `toNum`). **Не конвертируй в `float`** — потеря точности.
   - **Gotcha 4 (T-Invest gRPC streaming: persistent connection)** — здесь ты используешь **unary** вызовы (`get_portfolio`, `get_operations`), не streaming, но client должен быть переиспользуемым — не создавай новый на каждый запрос. Смотри как это сделано в существующем `get_balance`.

2. **[Sprint_5_Review/PENDING_S5R_real_account_positions_operations.md](PENDING_S5R_real_account_positions_operations.md)** — полный план задачи.

3. **[Sprint_5_Review/execution_order.md](execution_order.md)** раздел **«Cross-DEV Contracts»**:
   - **Поставщик C8** — `GET /api/v1/broker/accounts/{id}/positions` → `list[BrokerPosition]` с полями `ticker, name, quantity, average_price, current_price, unrealized_pnl, source: 'strategy'|'external', currency`.
   - **Поставщик C9** — `GET /api/v1/broker/accounts/{id}/operations` → `{items: list[BrokerOperation], total: int}` с пагинацией `offset`/`limit`, фильтр `from`/`to`.

4. **Цитаты из ФТ (дословно):**

   > **ФТ 7.3 «Просмотр баланса и состояния счёта» [Must]:**
   > «Экран «Счёт» — отдельный раздел приложения:
   > - Текущий денежный баланс по каждому подключённому брокерскому счёту (включая разбивку: доступные средства / заблокированные).
   > - Открытые позиции у брокера: **в том числе позиции, открытые вне системы (куплено вручную в приложении брокера).**
   > - Нереализованный P&L по открытым позициям.
   > - История операций за выбранный период (список сделок от брокера).»

   **Ключевое требование:** «в том числе позиции, открытые вне системы» — это означает, что позиции нужно **различать** на `strategy` (наши сделки из `Order`) и `external` (куплено вручную). См. задачу 3.1.5.

   > **ФТ 7.7 «Несколько счетов одного брокера» [Must]:**
   > «T-Invest (и другие брокеры) позволяют иметь несколько счетов: брокерский, ИИС и др. При подключении API-ключа система запрашивает список доступных счетов через брокерский API и предлагает пользователю выбрать один или несколько для подключения. Каждый счёт добавляется как отдельная запись с указанием типа счёта (брокерский / ИИС).»

   **Для тебя:** ты работаешь с **одним** `account_id`, не суммируешь позиции по счетам. Фронт уже имеет селектор счёта из S5.

   > **ФТ 7.8 «Работа с rate limits брокерского API» [Must]:**
   > «Брокерский адаптер учитывает ограничения API провайдера (для T-Invest: 300 unary-запросов в минуту, лимиты на объём исторических данных за один запрос). Очередь запросов с автоматическим throttling ...»

   **Для тебя:** `get_portfolio` и `get_operations` — unary вызовы. Rate limiter уже есть в S5 (`broker/tinvest/rate_limiter.py`). Используй его через существующий паттерн в `adapter.get_balance`.

5. **T-Invest API — OperationsService:**

   Документация: `Документация по проекту/tinvest_api_services.md` раздел OperationsService.

   Ключевые методы:
   - `client.operations.get_portfolio(account_id)` → `PortfolioResponse` с `positions: list[PortfolioPosition]`. Каждая `PortfolioPosition` содержит `figi, instrument_type, quantity, average_position_price (MoneyValue), current_price (MoneyValue), expected_yield (Quotation), current_nkd (MoneyValue)` для облигаций, `blocked (Decimal)`, `currency` и др.
   - `client.operations.get_operations(account_id, from_, to, state, figi)` → `OperationsResponse` с `operations: list[Operation]`. Каждая `Operation` содержит `id, parent_operation_id, currency, payment (MoneyValue), price (MoneyValue), state (STATE_EXECUTED / STATE_CANCELED), quantity, figi, instrument_type, date, type (TYPE_BUY / TYPE_SELL / TYPE_DIVIDEND / TYPE_COUPON / TYPE_COMMISSION / TYPE_TAX ...)`.

   **`MoneyValue`** — структура `{currency: str, units: int, nano: int}`. Сумма = `units + nano / 10**9`, но храним как `Decimal` для точности (см. Gotcha 1).

6. **Корневой `CLAUDE.md` — правило Integration Verification.** Твоя задача напрямую касается этого правила: маппер, который никто не вызывает, — бесполезен. См. пункт 4 в Integration Verification Checklist ниже.

# Рабочая директория

- `Test/Develop/backend/app/broker/` (основная работа)
- `Test/Develop/backend/tests/broker/` (тесты)
- `Test/Develop/frontend/src/components/account/` (PositionsTable, OperationsTable)
- `Test/Develop/frontend/src/api/types.ts` (типы)
- `Test/Develop/frontend/e2e/` (новый `s5r-real-account.spec.ts`)

# Контекст существующего кода

- `Develop/backend/app/broker/router.py:113-134` — **две заглушки**: `return []` и `return {"items": [], "total": 0}`. **Заменить** на реальные вызовы через `service.get_positions` / `service.get_operations`.
- `Develop/backend/app/broker/service.py` — `BrokerService` с методами `get_balance`, `get_accounts`. **Добавить** `get_positions(user_id, account_id)` и `get_operations(user_id, account_id, from_, to, offset, limit)`.
- `Develop/backend/app/broker/base.py` — `BaseBrokerAdapter` абстракция + dataclasses `BrokerPosition`, `BrokerOperation`. **Проверить** — возможно надо добавить поля `source: Literal['strategy','external']`, `currency: str`. Если dataclass-ы в модуле схем — обновить и там.
- `Develop/backend/app/broker/tinvest/adapter.py` — `TInvestAdapter.get_balance()` уже использует `client.operations.get_portfolio()` для балансов. **Использовать тот же client** для `get_positions` / `get_operations`, не создавать новый.
- `Develop/backend/app/broker/tinvest/mapper.py` — существующие маппер-функции. **Добавить**: `portfolio_position_to_broker_position(position, orders_by_figi) -> BrokerPosition` и `operation_to_broker_operation(op) -> BrokerOperation`.
- `Develop/backend/app/trading/models.py` — `Order` модель. Связь с BrokerAccount через `account_id`. Для различения `source`: `SELECT DISTINCT figi FROM orders WHERE account_id = ? AND user_id = ?` → если figi позиции есть в этом списке → `source='strategy'`, иначе `'external'`.
- `Develop/frontend/src/components/account/PositionsTable.tsx` — уже существует, рендерит `BrokerPosition[]` через TanStack Table. **Проверить**, что все поля рендерятся: `ticker`, `name`, `quantity`, `average_price`, `current_price`, `unrealized_pnl`, `source` (badge), `currency`. Если каких-то полей нет — добавить колонки.
- `Develop/frontend/src/components/account/OperationsTable.tsx` — уже существует, рендерит `BrokerOperation[]`. **Проверить** поддержку типов операций: `BUY, SELL, DIVIDEND, COUPON, COMMISSION, TAX`. Добавить иконки / цвета по типу.
- `Develop/frontend/src/api/types.ts` — `BrokerPosition`, `BrokerOperation` типы. **Добавить** `source`, `currency`, типы операций, если отсутствуют.

# Задачи

## Задача 3.1: Backend — `BrokerPosition` dataclass / схема

В `Develop/backend/app/broker/base.py` (или `app/broker/schemas.py` — где уже определено):

```python
from dataclasses import dataclass
from decimal import Decimal
from typing import Literal

@dataclass
class BrokerPosition:
    figi: str
    ticker: str                  # из инструмента — см. MarketDataService.get_instrument_by_figi
    name: str                    # название инструмента
    instrument_type: str         # share / bond / etf / currency
    quantity: Decimal            # количество (для облигаций — в штуках)
    average_price: Decimal       # средняя цена покупки
    current_price: Decimal       # текущая рыночная цена
    unrealized_pnl: Decimal      # (current_price - average_price) * quantity
    currency: str                # RUB / USD / EUR / HKD / CNY
    source: Literal["strategy", "external"]
    blocked: Decimal = Decimal("0")
```

**Pydantic схема для API:**
```python
from pydantic import BaseModel, field_serializer

class BrokerPositionResponse(BaseModel):
    figi: str
    ticker: str
    name: str
    instrument_type: str
    quantity: Decimal
    average_price: Decimal
    current_price: Decimal
    unrealized_pnl: Decimal
    currency: str
    source: Literal["strategy", "external"]
    blocked: Decimal

    @field_serializer("quantity", "average_price", "current_price", "unrealized_pnl", "blocked")
    def ser_decimal(self, v: Decimal) -> str:
        return str(v)  # Gotcha 1 — Decimal → str
```

## Задача 3.2: Backend — `BrokerOperation` dataclass / схема

```python
@dataclass
class BrokerOperation:
    id: str
    parent_operation_id: str | None
    figi: str | None
    ticker: str | None           # может быть None для комиссии / налога
    name: str | None
    type: Literal["BUY", "SELL", "DIVIDEND", "COUPON", "COMMISSION", "TAX", "OTHER"]
    state: Literal["EXECUTED", "CANCELED", "PROGRESS"]
    date: datetime
    quantity: Decimal | None
    price: Decimal | None
    payment: Decimal              # знак: BUY → -, SELL → +, DIVIDEND → +, COMMISSION → -
    currency: str

class BrokerOperationResponse(BaseModel):
    # те же поля + @field_serializer для Decimal → str
    ...

class BrokerOperationListResponse(BaseModel):
    items: list[BrokerOperationResponse]
    total: int
```

## Задача 3.3: Маппер `portfolio_position_to_broker_position`

В `Develop/backend/app/broker/tinvest/mapper.py`:

```python
from decimal import Decimal
from tinkoff.invest.schemas import PortfolioPosition as TPortfolioPosition
from app.broker.base import BrokerPosition

def money_value_to_decimal(mv) -> Decimal:
    """T-Invest MoneyValue {units, nano} → Decimal."""
    return Decimal(mv.units) + Decimal(mv.nano) / Decimal(10**9)

def quotation_to_decimal(q) -> Decimal:
    return Decimal(q.units) + Decimal(q.nano) / Decimal(10**9)

async def portfolio_position_to_broker_position(
    position: TPortfolioPosition,
    instrument_info: dict,          # {figi → {ticker, name, instrument_type}}
    strategy_figis: set[str],       # figi, связанные с Order нашей системы
) -> BrokerPosition:
    figi = position.figi
    info = instrument_info.get(figi, {})
    return BrokerPosition(
        figi=figi,
        ticker=info.get("ticker", figi),
        name=info.get("name", ""),
        instrument_type=position.instrument_type,
        quantity=quotation_to_decimal(position.quantity),
        average_price=money_value_to_decimal(position.average_position_price),
        current_price=money_value_to_decimal(position.current_price),
        unrealized_pnl=quotation_to_decimal(position.expected_yield),
        currency=position.average_position_price.currency.upper(),
        source="strategy" if figi in strategy_figis else "external",
        blocked=quotation_to_decimal(position.blocked) if position.blocked else Decimal("0"),
    )
```

## Задача 3.4: Маппер `operation_to_broker_operation`

```python
from tinkoff.invest.schemas import Operation as TOperation, OperationType, OperationState

TYPE_MAP = {
    OperationType.OPERATION_TYPE_BUY: "BUY",
    OperationType.OPERATION_TYPE_SELL: "SELL",
    OperationType.OPERATION_TYPE_DIVIDEND: "DIVIDEND",
    OperationType.OPERATION_TYPE_COUPON: "COUPON",
    OperationType.OPERATION_TYPE_BROKER_FEE: "COMMISSION",
    OperationType.OPERATION_TYPE_TAX: "TAX",
    # ... остальные → OTHER
}

STATE_MAP = {
    OperationState.OPERATION_STATE_EXECUTED: "EXECUTED",
    OperationState.OPERATION_STATE_CANCELED: "CANCELED",
    OperationState.OPERATION_STATE_PROGRESS: "PROGRESS",
}

async def operation_to_broker_operation(
    op: TOperation,
    instrument_info: dict,
) -> BrokerOperation:
    info = instrument_info.get(op.figi, {}) if op.figi else {}
    return BrokerOperation(
        id=op.id,
        parent_operation_id=op.parent_operation_id or None,
        figi=op.figi or None,
        ticker=info.get("ticker"),
        name=info.get("name"),
        type=TYPE_MAP.get(op.operation_type, "OTHER"),
        state=STATE_MAP.get(op.state, "EXECUTED"),
        date=op.date,
        quantity=Decimal(op.quantity) if op.quantity else None,
        price=money_value_to_decimal(op.price) if op.price else None,
        payment=money_value_to_decimal(op.payment),
        currency=op.currency.upper(),
    )
```

## Задача 3.5: Backend — `TInvestAdapter.get_positions` / `get_operations`

В `Develop/backend/app/broker/tinvest/adapter.py`:

```python
async def get_positions(self, account_id: str) -> list[BrokerPosition]:
    """Реальные позиции через OperationsService.GetPortfolio."""
    async with self.rate_limiter.acquire():
        portfolio = await self._run_in_executor(
            lambda: self._client.operations.get_portfolio(account_id=account_id)
        )

    # Префетч инфо инструментов (ticker, name, type) по FIGI
    instrument_info = await self._fetch_instrument_info(
        [p.figi for p in portfolio.positions]
    )

    # Префетч figi из Order нашей системы для определения source
    strategy_figis = await self._fetch_strategy_figis(account_id)

    positions = []
    for p in portfolio.positions:
        if quotation_to_decimal(p.quantity) == 0:
            continue  # закрытые позиции пропускаем
        positions.append(
            await portfolio_position_to_broker_position(p, instrument_info, strategy_figis)
        )
    return positions

async def get_operations(
    self,
    account_id: str,
    from_: datetime,
    to: datetime,
    offset: int = 0,
    limit: int = 100,
) -> tuple[list[BrokerOperation], int]:
    """Реальные операции через OperationsService.GetOperations."""
    async with self.rate_limiter.acquire():
        response = await self._run_in_executor(
            lambda: self._client.operations.get_operations(
                account_id=account_id,
                from_=from_,
                to=to,
                state=OperationState.OPERATION_STATE_EXECUTED,
            )
        )

    all_ops = response.operations
    total = len(all_ops)
    page = all_ops[offset : offset + limit]

    instrument_info = await self._fetch_instrument_info(
        [op.figi for op in page if op.figi]
    )

    mapped = [await operation_to_broker_operation(op, instrument_info) for op in page]
    return mapped, total
```

**Внимание:** T-Invest API возвращает **все** операции за период одним ответом — пагинацию делаем в Python (не на стороне T-Invest, там её нет для этого метода).

## Задача 3.6: Backend — `BrokerService.get_positions` / `get_operations`

В `Develop/backend/app/broker/service.py`:

```python
async def get_positions(self, user_id: int, account_id: int) -> list[BrokerPosition]:
    account = await self._get_account_or_raise(user_id, account_id)
    adapter = await self._get_adapter_for_account(account)
    return await adapter.get_positions(account.tinvest_account_id)

async def get_operations(
    self,
    user_id: int,
    account_id: int,
    from_: datetime,
    to: datetime,
    offset: int = 0,
    limit: int = 100,
) -> tuple[list[BrokerOperation], int]:
    account = await self._get_account_or_raise(user_id, account_id)
    adapter = await self._get_adapter_for_account(account)
    return await adapter.get_operations(account.tinvest_account_id, from_, to, offset, limit)
```

## Задача 3.7: Backend — подключить роуты в `router.py`

В `Develop/backend/app/broker/router.py` **заменить заглушки**:

```python
@router.get("/accounts/{account_id}/positions", response_model=list[BrokerPositionResponse])
async def get_account_positions(
    account_id: int,
    user: User = Depends(get_current_user),
    service: BrokerService = Depends(get_broker_service),
) -> list[BrokerPositionResponse]:
    positions = await service.get_positions(user.id, account_id)
    return [BrokerPositionResponse.model_validate(p) for p in positions]

@router.get("/accounts/{account_id}/operations", response_model=BrokerOperationListResponse)
async def get_account_operations(
    account_id: int,
    from_: datetime = Query(..., alias="from"),
    to: datetime = Query(...),
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user: User = Depends(get_current_user),
    service: BrokerService = Depends(get_broker_service),
) -> BrokerOperationListResponse:
    items, total = await service.get_operations(user.id, account_id, from_, to, offset, limit)
    return BrokerOperationListResponse(
        items=[BrokerOperationResponse.model_validate(op) for op in items],
        total=total,
    )
```

## Задача 3.8: Frontend — проверка `PositionsTable` / `OperationsTable`

1. **`PositionsTable.tsx`** — убедиться, что колонки покрывают все поля: ticker, name, quantity, average_price, current_price, unrealized_pnl, **source** (Badge «Стратегия» / «Внешняя»), currency. Если каких-то колонок нет — добавить. Декимал-поля парсить через `toNum` (helper уже есть в проекте).
2. **`OperationsTable.tsx`** — колонки: дата, тип (с иконкой/цветом), ticker, quantity, price, payment, currency. Типы: BUY/SELL (акции), DIVIDEND/COUPON (зелёный +), COMMISSION/TAX (красный -).
3. **Multi-currency:** в шапке таблицы или футере группировать по валютам — по крайней мере не конвертировать всё в RUB (валюты разные, суммы не имеют смысла).

## Задача 3.9: Frontend — TypeScript типы

В `Develop/frontend/src/api/types.ts`:

```ts
export type PositionSource = 'strategy' | 'external';

export interface BrokerPosition {
  figi: string;
  ticker: string;
  name: string;
  instrument_type: string;
  quantity: string;        // Decimal → string (Gotcha 1)
  average_price: string;
  current_price: string;
  unrealized_pnl: string;
  currency: string;
  source: PositionSource;
  blocked: string;
}

export type OperationType = 'BUY' | 'SELL' | 'DIVIDEND' | 'COUPON' | 'COMMISSION' | 'TAX' | 'OTHER';
export type OperationState = 'EXECUTED' | 'CANCELED' | 'PROGRESS';

export interface BrokerOperation {
  id: string;
  parent_operation_id: string | null;
  figi: string | null;
  ticker: string | null;
  name: string | null;
  type: OperationType;
  state: OperationState;
  date: string;            // ISO
  quantity: string | null;
  price: string | null;
  payment: string;
  currency: string;
}

export interface BrokerOperationListResponse {
  items: BrokerOperation[];
  total: number;
}
```

## Задача 3.10: Удалить заглушки и комментарии

В `Develop/backend/app/broker/router.py` удалить **все** комментарии вида «TODO: реальная интеграция в будущем», «заглушка для Sprint 5», и т.п. Они становятся неактуальными.

# Тесты

```
Develop/backend/tests/broker/
├── test_tinvest_mapper.py              # unit: portfolio_position_to_broker_position, operation_to_broker_operation
├── test_tinvest_adapter_real.py        # unit с моком tinkoff SDK: get_positions, get_operations
├── test_broker_service_positions.py    # integration: service → adapter через mock
└── test_broker_router_positions.py     # integration: TestClient → роут → service (с моком adapter)

Develop/frontend/e2e/
└── s5r-real-account.spec.ts            # E2E: открыть «Счёт» → видны позиции и операции
```

**Фикстуры:**
- `mock_tinvest_portfolio` — фейковый `PortfolioResponse` с 3 позициями (акция RUB, акция USD, облигация)
- `mock_tinvest_operations` — фейковый `OperationsResponse` с 10 операциями разных типов
- `fake_instrument_info` — словарь figi → {ticker, name, instrument_type}
- `db_session` с несколькими `Order` для проверки `source=strategy`
- `test_user`, `test_broker_account`

**Сценарии `test_tinvest_mapper.py`:**
1. Position с RUB → BrokerPosition с правильными decimal'ами
2. Position с USD → currency='USD'
3. Position с figi из strategy_figis → `source='strategy'`
4. Position с figi не из strategy_figis → `source='external'`
5. Bond position → instrument_type='bond'
6. Operation BUY → type='BUY', payment < 0
7. Operation DIVIDEND → type='DIVIDEND', payment > 0
8. Operation CANCELED → state='CANCELED' (фильтровать или нет — по спеке EXECUTED)

**E2E сценарий `s5r-real-account.spec.ts`:**
```ts
test('account page shows real positions and operations', async ({ page }) => {
  // Предполагается: test user имеет подключённый T-Invest sandbox ключ
  await page.goto('/account');
  await expect(page.getByTestId('positions-table')).toBeVisible();
  await expect(page.getByTestId('positions-table').locator('tbody tr')).toHaveCount.greaterThan(0);
  // Operation history
  await page.getByRole('tab', { name: 'Операции' }).click();
  await expect(page.getByTestId('operations-table')).toBeVisible();
});
```

**Заметка:** для E2E нужен sandbox-ключ T-Invest, без production данных. Если ключа нет — `test.skip()` с аннотацией «нужен T-Invest sandbox key».

# ⚠️ Integration Verification Checklist

- [ ] **Grep на вызов маппера:**
  `grep -rn "portfolio_position_to_broker_position" app/broker/` → вызывается в `adapter.py`, не только в `mapper.py` (определение) и тестах
  `grep -rn "operation_to_broker_operation" app/broker/` → то же
- [ ] **Grep на `get_portfolio` в service/router:**
  `grep -rn "get_positions(" app/broker/` → вызывается из `service.py` (production), не только в тестах
- [ ] **Grep на endpoint регистрацию:**
  `grep -rn "get_account_positions\|get_account_operations" app/` → endpoint зарегистрирован через `@router.get(...)`
- [ ] **API endpoint проверен через TestClient:**
  Тест `test_broker_router_positions.py::test_get_positions_returns_real_data` → `GET /api/v1/broker/accounts/1/positions` возвращает 200 + list с полями из C8
- [ ] **CSRF:** GET endpoint'ы не требуют CSRF (это read-only) — проверено
- [ ] **Auth:** оба endpoint'а имеют `Depends(get_current_user)` — проверено
- [ ] **Frontend → Backend:** `PositionsTable.tsx` делает fetch на `/api/v1/broker/accounts/{id}/positions` и рендерит ответ — проверено через network inspection или unit-тест компонента с моком fetch
- [ ] **Заглушки удалены:** `grep -rn "return \[\]" app/broker/router.py` → 0 результатов (или только в других endpoint'ах, не в positions/operations)

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни в финальном ответе **только** структурированную сводку **до 400 слов**.

```markdown
## DEV-3 отчёт — Sprint_5_Review, S5R.3 Real Positions & Operations T-Invest

### 1. Что реализовано
- BrokerPosition / BrokerOperation dataclass + Pydantic схемы (с Decimal → str)
- Мапперы portfolio_position_to_broker_position, operation_to_broker_operation
- TInvestAdapter.get_positions/get_operations через client.operations.*
- BrokerService.get_positions/get_operations
- Роуты GET /accounts/{id}/positions и /operations — заглушки удалены
- PositionsTable/OperationsTable рендерят реальные поля + source badge + multi-currency
- TS types в api/types.ts

### 2. Файлы
- **Новые:** `backend/tests/broker/test_tinvest_mapper.py`, `test_broker_router_positions.py`, `frontend/e2e/s5r-real-account.spec.ts`
- **Изменённые:** `backend/app/broker/router.py`, `service.py`, `base.py` (или `schemas.py`), `tinvest/adapter.py`, `tinvest/mapper.py`, `frontend/src/components/account/PositionsTable.tsx`, `OperationsTable.tsx`, `src/api/types.ts`
- **Удалённые:** заглушки и TODO-комментарии в `router.py`

### 3. Тесты
- Backend unit маппер: X/X passed
- Backend integration router: Y/Y passed
- Frontend vitest: Z/Z passed
- Playwright s5r-real-account: passed (или skipped с «нужен sandbox key»)

### 4. Integration points
- `portfolio_position_to_broker_position` вызывается из `adapter.py:get_positions:L<N>` (✅)
- `operation_to_broker_operation` вызывается из `adapter.py:get_operations:L<N>` (✅)
- `service.get_positions` вызывается из `router.py:get_account_positions:L<N>` (✅)
- `service.get_operations` вызывается из `router.py:get_account_operations:L<N>` (✅)
- Endpoint'ы зарегистрированы в `main.py` через `app.include_router(broker_router)` (✅ — не изменяется, уже было)

### 5. Контракты для других DEV
- **Поставляю C8** (positions endpoint): `GET /api/v1/broker/accounts/{id}/positions` → `list[BrokerPosition]` с полями ticker, name, quantity, average_price, current_price, unrealized_pnl, source, currency, blocked — подтверждено
- **Поставляю C9** (operations endpoint): `GET /api/v1/broker/accounts/{id}/operations?from=&to=&offset=&limit=` → `{items, total}` — подтверждено
- **Использую C1, C2, C3** (от DEV-1): ruff/eslint/CI зелёные — подтверждаю, baseline работает

### 6. Проблемы / TODO
- Фильтр `source` на frontend (кнопка «только стратегии») — опционально, не реализовано (можно в S6)
- Конвертация в единую валюту — ФТ 7.3 не требует, multi-currency рендерится как есть

### 7. Применённые Stack Gotchas
- **Gotcha 1** (Pydantic v2 + Decimal): все Decimal-поля (`quantity`, `average_price`, `current_price`, `unrealized_pnl`, `payment`, `price`, `blocked`) сериализуются через `@field_serializer` как `str`. Frontend парсит через `toNum`.
- **Gotcha 4** (T-Invest persistent connection): использую существующий `self._client` из `TInvestAdapter`, не создаю новый client на каждый запрос.

### 8. Новые Stack Gotchas (если обнаружены)
- <если обнаружена новая — описать>
```

# Alembic-миграция (если применимо)

**Не применимо** — задача не добавляет новых полей в модели. Если при написании мапперов обнаружится, что `BrokerPosition` должен сохраняться в БД для кеширования — это **новое** требование, согласовать с оркестратором перед реализацией.

# Чеклист перед сдачей

- [ ] Все задачи 3.1-3.10 реализованы
- [ ] `cd Develop/backend && pytest tests/broker/` → 0 failures
- [ ] `cd Develop/backend && pytest tests/` → 0 failures (не сломать остальное)
- [ ] `cd Develop/frontend && pnpm tsc --noEmit` → 0 errors
- [ ] `cd Develop/frontend && pnpm lint` → 0 errors
- [ ] `cd Develop/frontend && pnpm test` → 0 failures
- [ ] `cd Develop/frontend && npx playwright test e2e/s5r-real-account.spec.ts` → passed (или явный skip с аннотацией)
- [ ] **Integration Verification Checklist полностью пройден** — все пункты с конкретными строками
- [ ] **Формат отчёта соблюдён** — 8 секций, ≤ 400 слов
- [ ] **Cross-DEV contracts C8, C9 подтверждены** в секции 5 отчёта
- [ ] **Stack Gotchas применены** — секция 7 отчёта (минимум Gotcha 1)
- [ ] **Заглушки `return []` / `return {"items": [], "total": 0}` удалены** из `router.py`
- [ ] **Рренкер проверен:** `PositionsTable` и `OperationsTable` отрисовывают реальные данные с корректным парсингом Decimal → number
