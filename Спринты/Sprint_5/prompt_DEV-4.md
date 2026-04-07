---
sprint: 5
agent: DEV-4
role: Frontend (FRONT1) — Trading Panel + Real-time Charts
wave: 3
depends_on: [DEV-1, UX]
---

# Роль

Ты — Frontend-разработчик #4 (senior). Реализуй Trading Panel (страница торговли, карточки сессий, форма запуска, позиции, P&L) и real-time обновление графиков через WebSocket.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node.js >= 18, pnpm установлен
2. Backend API торговли работает: /api/v1/trading/sessions (GET)
3. UI-спецификация: Спринты/Sprint_5/ui_spec_s5.md — готова
4. Существующие stores: frontend/src/stores/ — authStore, backtestStore, etc.
5. Существующие API: frontend/src/api/ — client.ts (Axios + interceptors)
6. Существующие графики: frontend/src/components/charts/ — CandlestickChart.tsx
7. WebSocket в бэктесте: работает через /ws?token=JWT
8. pnpm test проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-4 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст

## Стек и конвенции

- **React 18.3+**, TypeScript 5.4+, Vite
- **Mantine 7.8+** (dark theme), Zustand 4.5+ (state)
- **TradingView Lightweight Charts 4.1+** (графики)
- **Axios** с JWT interceptors (src/api/client.ts)
- Формат чисел: `Intl.NumberFormat('ru-RU')`, `1 234 567,89 ₽`
- Формат дат: `ДД.ММ.ГГГГ`
- Компоненты: функциональные, TypeScript strict

## Zustand Stores (ТЗ 6.9)

Паттерн из существующих stores:
```typescript
// Пример: backtestStore.ts
interface BacktestState {
  backtests: Backtest[];
  current: Backtest | null;
  loading: boolean;
  error: string | null;
  fetch: () => Promise<void>;
  // ...
}
export const useBacktestStore = create<BacktestState>()((set, get) => ({...}));
```

## API Client (src/api/client.ts)

```typescript
// Axios instance с:
// - baseURL: '/api/v1'
// - JWT interceptor (access token в header)
// - Refresh token interceptor
// - CSRF token в header для мутаций
```

## WebSocket (используется в бэктесте)

Endpoint: `ws://host/ws?token=JWT`
Протокол: `{"action": "subscribe", "channel": "backtest:123"}`
Ответ: `{"channel": "...", "event": "...", "data": {...}}`

## Backend API (Trading — из DEV-1)

```
POST   /api/v1/trading/sessions              — запуск сессии
GET    /api/v1/trading/sessions              — список сессий
GET    /api/v1/trading/sessions/{id}         — детали
PATCH  /api/v1/trading/sessions/{id}/pause   — пауза
PATCH  /api/v1/trading/sessions/{id}/resume  — возобновление
PATCH  /api/v1/trading/sessions/{id}/stop    — стоп
GET    /api/v1/trading/sessions/{id}/positions — позиции
POST   /api/v1/trading/sessions/{id}/positions/{trade_id}/close — закрыть
POST   /api/v1/trading/sessions/{id}/close-all — закрыть все
GET    /api/v1/trading/sessions/{id}/trades  — сделки (offset, limit)
GET    /api/v1/trading/sessions/{id}/stats   — статистика
GET    /api/v1/trading/dashboard             — сводка
```

WebSocket каналы: `trades:{session_id}` (события: order.placed, trade.filled, trade.closed, session.started, session.stopped)

# Задачи

## Задача 1: TypeScript типы (src/api/types.ts)

Добавить типы в существующий `types.ts`:

```typescript
// Trading
export interface TradingSession {
  id: number;
  ticker: string;
  mode: 'paper' | 'real';
  status: 'active' | 'paused' | 'stopped';
  strategy_name: string;
  initial_capital: number;
  current_pnl: number | null;
  started_at: string;
  stopped_at: string | null;
}

export interface LiveTrade {
  id: number;
  session_id: number;
  direction: 'long' | 'short';
  order_type: string;
  status: string;
  entry_price: number | null;
  exit_price: number | null;
  volume_lots: number;
  filled_lots: number;
  pnl: number | null;
  pnl_pct: number | null;
  commission: number | null;
  slippage: number | null;
  opened_at: string;
  closed_at: string | null;
}

export interface Position {
  trade_id: number;
  ticker: string;
  direction: string;
  entry_price: number;
  current_price: number;
  volume_lots: number;
  unrealized_pnl: number;
  hold_duration: string;
}

export interface SessionStartRequest {
  strategy_version_id: number;
  ticker: string;
  mode: 'paper' | 'real';
  broker_account_id?: number;
  initial_capital: number;
  position_sizing_mode: 'fixed_sum' | 'fixed_lots' | 'percent';
  position_sizing_value: number;
  max_concurrent_positions: number;
  cooldown_seconds: number;
}

export interface TradingDashboard {
  active_sessions: number;
  total_pnl: number;
  sessions: TradingSession[];
}
```

## Задача 2: Trading API (src/api/tradingApi.ts)

```typescript
import { apiClient } from './client';

export const tradingApi = {
  // Сессии
  startSession: (data: SessionStartRequest) => apiClient.post('/trading/sessions', data),
  getSessions: (params?: { status?: string; mode?: string }) =>
    apiClient.get('/trading/sessions', { params }),
  getSession: (id: number) => apiClient.get(`/trading/sessions/${id}`),
  pauseSession: (id: number) => apiClient.patch(`/trading/sessions/${id}/pause`),
  resumeSession: (id: number) => apiClient.patch(`/trading/sessions/${id}/resume`),
  stopSession: (id: number) => apiClient.patch(`/trading/sessions/${id}/stop`),

  // Позиции и сделки
  getPositions: (sessionId: number) => apiClient.get(`/trading/sessions/${sessionId}/positions`),
  closePosition: (sessionId: number, tradeId: number) =>
    apiClient.post(`/trading/sessions/${sessionId}/positions/${tradeId}/close`),
  closeAllPositions: (sessionId: number) =>
    apiClient.post(`/trading/sessions/${sessionId}/close-all`),
  getTrades: (sessionId: number, offset = 0, limit = 50) =>
    apiClient.get(`/trading/sessions/${sessionId}/trades`, { params: { offset, limit } }),
  getStats: (sessionId: number) => apiClient.get(`/trading/sessions/${sessionId}/stats`),

  // Общее
  getDashboard: () => apiClient.get('/trading/dashboard'),
};
```

## Задача 3: Trading Store (src/stores/tradingStore.ts)

```typescript
interface TradingState {
  sessions: TradingSession[];
  activeSession: TradingSession | null;
  positions: Position[];
  trades: LiveTrade[];
  dashboard: TradingDashboard | null;
  loading: boolean;
  error: string | null;

  fetchSessions: () => Promise<void>;
  fetchSession: (id: number) => Promise<void>;
  startSession: (data: SessionStartRequest) => Promise<TradingSession>;
  pauseSession: (id: number) => Promise<void>;
  resumeSession: (id: number) => Promise<void>;
  stopSession: (id: number) => Promise<void>;
  fetchPositions: (sessionId: number) => Promise<void>;
  closePosition: (sessionId: number, tradeId: number) => Promise<void>;
  closeAllPositions: (sessionId: number) => Promise<void>;
  fetchTrades: (sessionId: number, offset?: number) => Promise<void>;
  fetchDashboard: () => Promise<void>;

  // WS updates
  updateSessionFromWS: (data: Partial<TradingSession>) => void;
  addTradeFromWS: (trade: LiveTrade) => void;
  updatePositionFromWS: (position: Position) => void;
}
```

## Задача 4: WebSocket Hook (src/hooks/useWebSocket.ts)

Generic мультиплексированный WebSocket хук с auto-reconnect:

```typescript
export function useWebSocket() {
  // Singleton WebSocket connection
  // subscribe(channel: string, callback: (event, data) => void)
  // unsubscribe(channel: string)
  // Auto-reconnect с exponential backoff
  // JWT token из authStore
}
```

Проверь — возможно в проекте уже есть WS-хук для бэктеста. Если есть — расширь его, не создавай новый.

## Задача 5: Trading Page (src/pages/TradingPage.tsx)

Маршрут: `/trading`

Компоненты:
- Заголовок «Торговля» + кнопка «Запустить сессию»
- `SessionList` — сетка карточек (Grid, 3 колонки)
- Пустое состояние: иллюстрация + "Нет активных сессий"

## Задача 6: Trading Components (src/components/trading/)

### 6.1 SessionCard.tsx
- Карточка сессии: плашка PAPER/REAL, тикер, стратегия, P&L, sparkline
- Кнопки: Пауза/Возобновление, Стоп, График
- Клик по карточке → `/trading/sessions/:id`

### 6.2 SessionList.tsx
- Фильтры: все / active / paused / stopped
- Сортировка: по дате, по P&L

### 6.3 LaunchSessionModal.tsx
- Модалка (Mantine Modal)
- Поля: стратегия (Select), тикер (поиск с autocomplete), режим (SegmentedControl Paper/Real)
- Параметры: начальный капитал, sizing, cooldown
- Для Real: дополнительный Select брокер + счёт, confirm-диалог
- Валидация: все обязательные поля

### 6.4 SessionDashboard.tsx
Страница `/trading/sessions/:id`:
- Header: тикер, стратегия, плашка режима, статус, кнопки управления
- Tabs: Позиции | Сделки | Статистика

### 6.5 PositionsTable.tsx
- TanStack Table: тикер, направление (▲ зелёный / ▼ красный), цена входа, текущая, P&L, время, кнопка «Закрыть»
- Real-time обновление через WS

### 6.6 TradesTable.tsx
- Все сделки сессии с пагинацией
- Колонки: дата, направление, вход, выход, P&L, P&L%, комиссия, slippage

### 6.7 PnLSummary.tsx
- Карточки: дневной P&L, суммарный P&L, Win Rate, кол-во сделок
- Equity curve сессии (Lightweight Charts, линейный график)

## Задача 7: Real-time графики (обновление CandlestickChart.tsx)

В существующем `src/components/charts/CandlestickChart.tsx`:

1. **WebSocket streaming**: подписка на канал `market:{ticker}:{tf}` через useWebSocket
2. **Обновление свечей в реальном времени**: `chart.update()` при получении новой свечи
3. **Маркеры сделок**: при наличии активной торговой сессии для этого тикера:
   - Зелёные маркеры ▲ (покупка) при trade.filled + direction=long
   - Красные маркеры ▼ (продажа) при trade.filled + direction=short
4. **Индикатор подключения**: мигающий кружок в углу (зелёный = connected, красный = disconnected)

## Задача 8: Навигация

В `src/components/layout/Sidebar.tsx` (или аналог):
- Добавить пункт «Торговля» с иконкой `IconChartLine`
- Маршрут: `/trading`

В `src/App.tsx` (или router):
- Route `/trading` → `TradingPage`
- Route `/trading/sessions/:id` → `SessionDashboard`

# Тесты

Минимум 15 тестов в `src/components/trading/__tests__/`:

```
__tests__/
├── SessionCard.test.tsx      — рендер Paper/Real, P&L цвета
├── LaunchSessionModal.test.tsx — валидация, confirm для Real
├── PositionsTable.test.tsx   — рендер позиций, кнопка закрытия
├── TradesTable.test.tsx      — пагинация, рендер данных
├── PnLSummary.test.tsx       — рендер метрик
├── TradingPage.test.tsx      — пустое состояние, загрузка
└── tradingStore.test.ts      — store actions
```

# Чеклист перед сдачей

- [ ] TypeScript типы добавлены в types.ts
- [ ] tradingApi.ts — все endpoints
- [ ] tradingStore.ts — все actions + WS updates
- [ ] useWebSocket hook (generic, с reconnect)
- [ ] TradingPage — список сессий + кнопка запуска
- [ ] SessionCard — PAPER жёлтый / REAL красный
- [ ] LaunchSessionModal — полная форма + confirm для Real
- [ ] SessionDashboard — позиции, сделки, статистика
- [ ] PositionsTable — real-time через WS
- [ ] CandlestickChart — WS streaming + маркеры сделок
- [ ] Навигация: sidebar + routes
- [ ] 15+ тестов, все зелёные
- [ ] pnpm test: 0 failures
