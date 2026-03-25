---
sprint: 2
agent: DEV-5
role: Frontend #1 (FRONT1) — Charts
wave: 3
depends_on: [UX (ui_spec_s2.md), DEV-4 (market data endpoints)]
---

# Роль

Ты — Frontend-разработчик #1 (senior). Реализуй модуль графиков на TradingView Lightweight Charts и динамический footer.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node >= 18 (node --version)
2. pnpm >= 9 (pnpm --version)
3. Файл Sprint_2/ui_spec_s2.md существует и утверждён
4. Backend endpoint работает: GET /api/v1/market-data/candles
5. Backend endpoint работает: GET /api/v1/market-data/market-status
6. pnpm test проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-5 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

## Layout (AppShell.tsx)

```typescript
// Текущий footer — СТАТИЧЕСКИЙ, нужно сделать динамическим:
<AppShell.Footer p={4}>
  <Group justify="space-between" px="md" h="100%">
    <Badge size="xs" color="green" variant="dot">MOEX Online</Badge>
    <Text size="xs" c="dimmed">Paper Trading</Text>
    <Text size="xs" c="dimmed">До закрытия: 2ч 15м</Text>
  </Group>
</AppShell.Footer>
```

## Header (Header.tsx)

```typescript
// Поиск инструмента — DISABLED, нужно сделать функциональным:
<TextInput
  placeholder="Поиск инструмента..."
  leftSection={<IconSearch size={16} />}
  w={300}
  size="sm"
  disabled  // ← убрать disabled, добавить Autocomplete
/>
```

## App.tsx — Роутинг

```typescript
// Текущие маршруты:
<Route index element={<DashboardPage />} />
<Route path="strategy/:id" element={<StrategyDetailPage />} />
<Route path="backtest/:id" element={<BacktestDetailPage />} />
// Нужно добавить: <Route path="chart/:ticker?" element={<ChartPage />} />
```

## Sidebar (Sidebar.tsx)

```typescript
// Текущие пункты навигации:
const navItems = [
  { label: 'Стратегии', icon: IconChartBar, path: '/' },
  { label: 'Бэктесты', icon: IconChartLine, path: '/backtests' },
  // Нужно добавить: { label: 'Графики', icon: IconChartCandle, path: '/chart' },
  ...
];
```

## Stores

```typescript
// authStore — token, user, login, logout, isAuthenticated
// uiStore — sidebarCollapsed, toggleSidebar
```

## API client

```typescript
// api/client.ts — Axios с JWT interceptors, baseURL: http://localhost:8000/api/v1
```

# Задачи

## 1. Установить зависимость

```bash
pnpm add lightweight-charts
```

## 2. Market Data API (`src/api/marketDataApi.ts`)

```typescript
import apiClient from './client';

export interface Candle {
  timestamp: string;  // ISO datetime
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface InstrumentInfo {
  ticker: string;
  name: string;
  type: string;
  currency: string;
  lot_size: number;
}

export interface MarketStatus {
  status: 'online' | 'evening' | 'auction' | 'offline' | 'weekend';
  time_until_close: string | null;
  is_trading_day: boolean;
}

export const marketDataApi = {
  getCandles: (ticker: string, timeframe: string, from: string, to: string) =>
    apiClient.get<Candle[]>('/market-data/candles', {
      params: { ticker, timeframe, from, to },
    }),

  searchInstruments: (query: string) =>
    apiClient.get<{ results: InstrumentInfo[]; total: number }>(
      '/market-data/instruments',
      { params: { query } },
    ),

  getInstrumentInfo: (ticker: string) =>
    apiClient.get<InstrumentInfo>(`/market-data/instruments/${ticker}`),

  getMarketStatus: () =>
    apiClient.get<MarketStatus>('/market-data/market-status'),
};
```

## 3. Market Data Store (`src/stores/marketDataStore.ts`)

```typescript
import { create } from 'zustand';

interface MarketDataState {
  currentTicker: string | null;
  currentTimeframe: string;
  candles: Candle[];
  loading: boolean;
  error: string | null;
  marketStatus: MarketStatus | null;

  setTicker: (ticker: string) => void;
  setTimeframe: (tf: string) => void;
  fetchCandles: () => Promise<void>;
  fetchMarketStatus: () => Promise<void>;
}
```

## 4. CandlestickChart Component (`src/components/charts/CandlestickChart.tsx`)

Обёртка над TradingView Lightweight Charts:

```typescript
import { createChart, IChartApi, ISeriesApi, CandlestickData, HistogramData } from 'lightweight-charts';
import { useRef, useEffect } from 'react';

interface CandlestickChartProps {
  candles: Candle[];
  showVolume?: boolean;
  height?: number;
}

// Требования:
// - useRef для DOM-контейнера
// - useEffect для создания/обновления/уничтожения chart
// - Dark theme: background '#1A1B1E', text '#C1C2C5'
// - Зелёные свечи: upColor '#40C057', wickUpColor '#40C057'
// - Красные свечи: downColor '#FA5252', wickDownColor '#FA5252'
// - Volume histogram ниже (отдельная серия, toggle)
// - Crosshair с tooltip (OHLCV данные)
// - Автоматический resize (ResizeObserver)
// - Cleanup на unmount: chart.remove()
```

**ВАЖНО:** TradingView LW Charts — императивная библиотека. Используй `useRef` + `useEffect`, а **не** декларативный подход. Обязательно очищай chart при unmount для предотвращения утечек памяти.

## 5. TimeframeSelector (`src/components/charts/TimeframeSelector.tsx`)

```typescript
// Кнопки таймфреймов: 1м, 5м, 15м, 1ч, 4ч, Д, Н, М
// Активная кнопка подсвечена
// При клике → setTimeframe → refetch candles

// Используй Mantine SegmentedControl или Button.Group
// Русские подписи: "1м", "5м", "15м", "1ч", "4ч", "Д", "Н", "М"
```

## 6. ChartPage (`src/pages/ChartPage.tsx`)

```typescript
// URL: /chart/:ticker?
// Layout (по ui_spec_s2.md):
// - Верх: инфо об инструменте (тикер, название, цена, изменение)
// - Под ним: TimeframeSelector
// - Основная область: CandlestickChart (занимает всё доступное пространство)

// При первом открытии без ticker: "Выберите инструмент для отображения графика"
// При выборе ticker: загрузить candles, показать график
```

## 7. Поиск инструмента в Header (`src/components/layout/Header.tsx`)

Обнови существующий Header:

```typescript
// Замени disabled TextInput на функциональный Autocomplete:
// - Mantine Autocomplete с debounce 300ms
// - При вводе >= 1 символа → searchInstruments API
// - Каждый результат: "SBER — Сбербанк ао (акция)"
// - При выборе: navigate(`/chart/${ticker}`)
// - Иконка поиска слева
```

## 8. Динамический Footer (`src/components/layout/StatusFooter.tsx`)

Создай отдельный компонент и используй его в AppShell:

```typescript
// Компонент StatusFooter:
// - Запрашивает GET /market-data/market-status каждые 60 секунд
// - Статус MOEX: Badge с dot
//   - status === 'online' → color="green", "MOEX Online"
//   - status === 'evening' → color="yellow", "MOEX Вечерняя"
//   - status === 'auction' → color="orange", "MOEX Аукцион"
//   - status === 'offline' → color="red", "MOEX Offline"
//   - status === 'weekend' → color="gray", "Выходной"
// - Режим торговли: "Paper Trading" (жёлтый) / "Нет активных сессий" (серый)
//   (Real Trading будет в S5)
// - Время до закрытия: time_until_close || "Торги завершены"
```

Обнови AppShell.tsx — замени статический footer на `<StatusFooter />`.

## 9. Обновление Sidebar

Добавь пункт "Графики" в `navItems` в Sidebar.tsx:
```typescript
{ label: 'Графики', icon: IconChartCandle, path: '/chart' },
```
Добавь его после "Стратегии" и перед "Бэктесты".

## 10. Обновление роутинга

В App.tsx добавь маршрут:
```typescript
<Route path="chart/:ticker?" element={<ChartPage />} />
```

## 11. Тесты

### `src/components/charts/__tests__/TimeframeSelector.test.tsx`
- test_renders_all_timeframes (8 кнопок)
- test_active_timeframe_highlighted
- test_click_changes_timeframe

### `src/stores/__tests__/marketDataStore.test.ts`
- test_initial_state (null ticker, empty candles)
- test_set_ticker
- test_set_timeframe
- test_loading_state_during_fetch

### `src/components/layout/__tests__/StatusFooter.test.tsx`
- test_renders_moex_status
- test_renders_time_until_close
- test_renders_trading_mode

### `src/pages/__tests__/ChartPage.test.tsx`
- test_renders_empty_state_without_ticker
- test_renders_chart_with_ticker (mock candles)

**Запусти тесты:**
```bash
pnpm test
```

# Конвенции

- TypeScript strict mode
- Функциональные компоненты
- Zustand для state management
- Mantine компоненты для UI
- Русский язык интерфейса
- Числа: `1 234,56 ₽`, даты: `ДД.ММ.ГГГГ`
- Dark theme: фон `#1A1B1E`, карточки `#25262B`

# Критерий завершения

- CandlestickChart отображает свечи (dark theme, volume)
- TimeframeSelector переключает таймфреймы
- ChartPage доступен по `/chart/:ticker`
- Поиск в Header работает (autocomplete → navigate to chart)
- Footer показывает динамический статус MOEX
- Sidebar содержит пункт "Графики"
- **Все тесты проходят: `pnpm test` — 0 failures**
- **~8-10 новых тестов**
