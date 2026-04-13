---
sprint: 5
agent: DEV-5
role: Frontend (FRONT2) — Account Screen + Favorites Panel
wave: 3
depends_on: [DEV-3, UX]
---

# Роль

Ты — Frontend-разработчик #5. Реализуй экран «Счёт» (баланс, позиции у брокера, история операций, налоговый отчёт) и панель «Избранные инструменты» (★ справа от графика).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node.js >= 18, pnpm установлен
2. Backend API: /api/v1/broker/accounts — работает (из S2)
3. Backend API: /api/v1/tax/reports — работает (из DEV-3)
4. Backend API: /api/v1/market-data/bonds — работает (из DEV-3)
5. UI-спецификация: Спринты/Sprint_5/ui_spec_s5.md — готова
6. Существующие компоненты: frontend/src/components/charts/ — ChartPage, CandlestickChart
7. Существующие stores: frontend/src/stores/settingsStore.ts, marketDataStore.ts
8. pnpm test проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-5 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст

## Backend API

### Broker (уже есть, S2)
```
GET /api/v1/broker/accounts                 — список подключённых аккаунтов
GET /api/v1/broker/accounts/{id}/balance    — баланс
GET /api/v1/broker/accounts/{id}/positions  — позиции (из DEV-1)
GET /api/v1/broker/accounts/{id}/operations — история операций (из DEV-1)
```

### Tax (новый, DEV-3)
```
POST /api/v1/tax/reports                    — сгенерировать отчёт
GET  /api/v1/tax/reports                    — список отчётов
GET  /api/v1/tax/reports/{id}/download      — скачать файл
```

### Favorites (нужно добавить на бэкенде или использовать localStorage)
Если на бэкенде нет API favorites — использовать `localStorage` для MVP. Формат:
```typescript
interface FavoriteInstrument {
  ticker: string;
  addedAt: string;
}
// localStorage key: 'user_favorites'
```

## Существующие компоненты

- `ChartPage.tsx` — страница графика с `CandlestickChart` и `TimeframeSelector`
- `settingsStore.ts` — хранит brokerAccounts
- `marketDataStore.ts` — candles, subscriptions
- `brokerApi.ts` — API клиент для брокера

# Задачи

## Задача 1: TypeScript типы (src/api/types.ts)

Добавить:

```typescript
// Account
export interface BrokerBalance {
  account_id: number;
  account_name: string;
  total: number;
  available: number;
  blocked: number;
  currency: string;
}

export interface BrokerPosition {
  ticker: string;
  name: string;
  quantity: number;
  average_price: number;
  current_price: number;
  unrealized_pnl: number;
  source: 'strategy' | 'external';  // управляется системой или куплено вне
}

export interface BrokerOperation {
  id: number;
  date: string;
  ticker: string;
  type: 'buy' | 'sell' | 'dividend' | 'coupon' | 'commission';
  quantity: number;
  price: number;
  total: number;
}

// Tax
export interface TaxReport {
  id: number;
  year: number;
  status: 'pending' | 'ready' | 'error';
  total_profit: number | null;
  total_loss: number | null;
  taxable_base: number | null;
  created_at: string;
}

export interface TaxReportRequest {
  year: number;
  format: 'xlsx' | 'csv';
  include_shares: boolean;
  include_bonds: boolean;
  include_etf: boolean;
}

// Favorites
export interface FavoriteInstrument {
  ticker: string;
  backtest_count: number;
  strategy_count: number;
  avg_pnl_pct: number;
}
```

## Задача 2: Account API (src/api/accountApi.ts)

```typescript
export const accountApi = {
  getBalances: () => apiClient.get('/broker/accounts/balances'),
  getPositions: (accountId: number) => apiClient.get(`/broker/accounts/${accountId}/positions`),
  getOperations: (accountId: number, params: { from?: string; to?: string; offset?: number; limit?: number }) =>
    apiClient.get(`/broker/accounts/${accountId}/operations`, { params }),
};
```

## Задача 3: Tax API (src/api/taxApi.ts)

```typescript
export const taxApi = {
  generateReport: (data: TaxReportRequest) => apiClient.post('/tax/reports', data),
  getReports: () => apiClient.get('/tax/reports'),
  downloadReport: (id: number) => {
    // Скачивание файла через blob
    return apiClient.get(`/tax/reports/${id}/download`, { responseType: 'blob' });
  },
};
```

## Задача 4: Account Store (src/stores/accountStore.ts)

```typescript
interface AccountState {
  balances: BrokerBalance[];
  positions: BrokerPosition[];
  operations: BrokerOperation[];
  taxReports: TaxReport[];
  loading: boolean;
  error: string | null;

  fetchBalances: () => Promise<void>;
  fetchPositions: (accountId: number) => Promise<void>;
  fetchOperations: (accountId: number, from?: string, to?: string) => Promise<void>;
  fetchTaxReports: () => Promise<void>;
  generateTaxReport: (data: TaxReportRequest) => Promise<void>;
  downloadTaxReport: (id: number) => Promise<void>;
}
```

## Задача 5: Account Page (src/pages/AccountPage.tsx)

Маршрут: `/account`

Структура:
1. **Balance Cards** — 3 карточки: Всего, Доступно, Заблокировано (Mantine `SimpleGrid` + `Paper`)
2. **Positions Table** — TanStack Table (тикер, кол-во, ср.цена, текущая, P&L, источник)
3. **Operations Table** — история с DateRangePicker фильтром, пагинация
4. **Tax Report Button** — «Налоговый отчёт» → открывает TaxReportModal

### Компоненты (src/components/account/):

#### BalanceCards.tsx
- 3 карточки в ряд (SimpleGrid cols={3})
- Mantine `Paper` + `Text` + `Title`
- P&L подсвечивается: зелёный/красный

#### PositionsTable.tsx
- TanStack Table с сортировкой
- Колонка «Источник»: Badge «Стратегия» (blue) или «Внешняя» (gray)
- Пустое состояние: "Нет открытых позиций"

#### OperationsTable.tsx
- DateRangePicker (Mantine DatePickerInput, type="range")
- По умолчанию: последние 30 дней
- Пагинация (offset/limit)
- Колонки: дата, тикер, тип, кол-во, цена, сумма

#### TaxReportModal.tsx
- Modal: выбор года (Select), формат (Radio: xlsx/csv), чекбоксы (акции/облигации/ETF)
- Кнопка «Скачать отчёт» → POST /tax/reports → polling status → download
- Loading state при генерации

## Задача 6: Панель «Избранные инструменты» (src/components/charts/FavoritesPanel.tsx)

Расположение: **справа** от графика на ChartPage.

```typescript
export function FavoritesPanel({ onSelectTicker }: { onSelectTicker: (ticker: string) => void }) {
  // Загрузка избранных (localStorage или API)
  // Для каждого ticker: запросить статистику (кол-во бэктестов, стратегий, ср. P&L)
  // Рендер: список карточек с кликом → onSelectTicker(ticker)
}
```

Элементы:
- Toggle кнопка ★ в toolbar графика (показать/скрыть панель)
- Каждый элемент: тикер (жирный), «3 бэкт · 2 стр», P&L (цвет по знаку)
- Клик → переключение графика на этот тикер
- Кнопка «+ Добавить» → autocomplete поиск инструмента
- Hover → иконка ✕ для удаления
- Ширина: ~200px

### Данные для статистики

Для каждого избранного тикера:
- Кол-во бэктестов: `GET /api/v1/backtests?ticker={ticker}` → count
- Кол-во стратегий: из бэктестов (distinct strategy_id)
- Средний P&L: из бэктестов (avg net_profit_pct)

Эти данные можно агрегировать одним запросом на бэкенде или на фронте из кеша бэктестов.

## Задача 7: Интеграция в ChartPage

В существующем `src/pages/ChartPage.tsx`:
1. Добавить `FavoritesPanel` справа (flex layout: chart | favorites)
2. Кнопка ★ в toolbar → toggle panel visibility
3. При клике на тикер в favorites → обновить текущий тикер графика

## Задача 8: Навигация

В Sidebar:
- Добавить пункт «Счёт» с иконкой `IconWallet`
- Маршрут: `/account`

В Router:
- Route `/account` → `AccountPage`

# Тесты

Минимум 10 тестов:

```
__tests__/
├── BalanceCards.test.tsx       — рендер 3 карточек, форматирование
├── PositionsTable.test.tsx    — рендер, сортировка, badges
├── OperationsTable.test.tsx   — фильтр дат, пагинация
├── TaxReportModal.test.tsx    — форма, валидация
├── FavoritesPanel.test.tsx    — список, добавление, удаление, клик
├── AccountPage.test.tsx       — общий рендер, loading/error states
└── accountStore.test.ts       — store actions
```

# Чеклист перед сдачей

- [ ] TypeScript типы добавлены
- [ ] accountApi.ts, taxApi.ts — все endpoints
- [ ] accountStore.ts — balances, positions, operations, tax reports
- [ ] AccountPage — 3 секции: баланс, позиции, операции
- [ ] BalanceCards — 3 карточки, форматирование ₽
- [ ] PositionsTable — badge «Стратегия» / «Внешняя»
- [ ] OperationsTable — DateRangePicker, пагинация
- [ ] TaxReportModal — выбор периода + формата + скачивание
- [ ] FavoritesPanel — список ★, добавление, удаление, клик → график
- [ ] Интеграция в ChartPage (layout + toggle)
- [ ] Навигация: sidebar «Счёт» + routes
- [ ] 10+ тестов, все зелёные
- [ ] pnpm test: 0 failures
