---
sprint: 4
agent: DEV-6
role: Frontend (FRONT1 + FRONT2) — Backtest UI + AI Settings
wave: 2
depends_on: [UX (ui_spec_s4.md), DEV-3 (Backtest Engine)]
---

# Роль

Ты — Frontend-разработчик #6 (senior). Реализуй страницу результатов бэктеста (3 вкладки), форму запуска бэктеста, прогресс через WebSocket, настройки AI-провайдеров.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node >= 18, pnpm >= 9
2. UI-спецификация: Sprint_4/ui_spec_s4.md существует и утверждена
3. Backtest API доступен: POST /backtests, GET /backtests/{id}, etc.
4. WebSocket endpoint /ws доступен
5. AI Settings API доступен: GET/POST/PATCH/DELETE /settings/ai/providers
6. TradingView Lightweight Charts установлен (S2)
7. pnpm test проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-6 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

## Паттерны

- React 18 + TypeScript, Mantine 7.8+, Zustand, TanStack Query
- TradingView Lightweight Charts (установлен в S2)
- Роуты: `src/routes.tsx`

# Задачи

## 1. Backtest Results Page (src/pages/BacktestResultsPage.tsx)

Маршрут: `/backtests/:id`

### 1.1 Tab «Обзор» (BacktestOverview)

**Компоненты:**
- `BacktestHeader` — название стратегии, тикер, период, Badge статуса
- `MetricsGrid` — сетка карточек 4x2 (SimpleGrid + Card):
  - Чистая прибыль (зелёный/красный цвет по знаку)
  - Кол-во сделок
  - Win Rate (%)
  - Profit Factor
  - Max Drawdown (%)
  - Sharpe Ratio
  - Средняя прибыль/убыток
  - Средняя длительность
- `BenchmarkChart` — горизонтальная bar chart: Стратегия vs Buy & Hold vs IMOEX
- Кнопки действий: «Экспорт CSV», «Экспорт PDF», «Запустить торговлю»

### 1.2 Tab «График» (BacktestChart)

**Компоненты (TradingView Lightweight Charts):**
- Верх (60%): `EquityCurveChart`
  - Equity curve (LineSeries, зелёная `#40C057`)
  - Drawdown (AreaSeries, красная `#FA5252`, инвертированная)
  - Benchmark: Buy & Hold (серая), IMOEX (синяя `#339AF0`)
- Низ (40%): `CandlestickWithMarkers`
  - Свечной график инструмента
  - Маркеры входа (▲ зелёный) и выхода (▼ красный) через `chart.addMarkers()`

### 1.3 Tab «Сделки» (BacktestTrades)

**Компоненты:**
- TanStack Table (`@tanstack/react-table`):
  - Колонки: дата входа, дата выхода, цена входа, цена выхода, объём, P&L (цветной), длительность
  - Сортировка по любой колонке
  - Фильтрация: все / прибыльные / убыточные (SegmentedControl)
  - Пагинация
- Кнопка «Экспорт CSV»

## 2. Backtest Launch Form (src/components/backtest/BacktestLaunchModal.tsx)

Модальное окно (Modal), открывается из StrategyEditPage (кнопка «Запустить бэктест»):

**Поля:**
- Стратегия + версия (read-only)
- Инструмент (Autocomplete — тикер MOEX, переиспользовать поиск из S2)
- Таймфрейм (SegmentedControl: 1м|5м|15м|1ч|4ч|Д|Н|М)
- Период: дата начала + дата конца (DatePickerInput)
- Начальный капитал (NumberInput, default 300000)
- Комиссия % (NumberInput, default 0.05)
- Проскальзывание (NumberInput + Select: %|пункты)
- Кнопка «Запустить бэктест» — disabled если код устарел или с ошибками (решение #5)
  - Tooltip с причиной disabled

**Валидация:**
- Период >= 30 дней
- Капитал > 0
- Тикер обязателен

## 3. Backtest Progress (src/components/backtest/BacktestProgress.tsx)

Отображается после запуска бэктеста (в модалке или inline):

**Компоненты:**
- Progress bar (Mantine Progress) с процентом
- Текущая дата обработки
- Elapsed time (таймер)
- Кнопка «Отменить»
- При завершении — автонавигация на BacktestResultsPage

**WebSocket подписка:**
```typescript
// Subscribe to backtest:{id} channel
ws.send(JSON.stringify({ action: "subscribe", channel: `backtest:${backtestId}` }));
// Handle events: backtest.progress, backtest.completed, backtest.failed
```

## 4. AI Provider Settings (src/pages/AISettingsPage.tsx)

Секция на странице Settings (или отдельная вкладка в SettingsPage):

**Компоненты:**
- `AIProviderTable` — таблица провайдеров (Table):
  - Radio для активного
  - Название, тип, модель, использование, статус, действия
- `AddProviderModal` — модалка добавления/редактирования:
  - Тип (Select: Claude, OpenAI, Custom)
  - Название (TextInput)
  - API-ключ (PasswordInput)
  - Модель (Select, зависит от типа)
  - Base URL (TextInput, только для Custom — показывать/скрывать)
  - Лимиты (NumberInput)
  - Кнопка «Проверить ключ» (POST verify)
- `UsageStats` — счётчик использования с Progress bars (today/month)

**Маскирование ключа:** отображать как `sk-ab...xyz1`.

## 5. Backtest Store (src/stores/backtestStore.ts)

```typescript
interface BacktestStore {
  currentBacktest: Backtest | null;
  isRunning: boolean;
  progress: number;
  currentDate: string;

  launchBacktest: (params: BacktestParams) => Promise<number>;
  fetchBacktest: (id: number) => Promise<void>;
  subscribeProgress: (id: number) => void;
  unsubscribeProgress: (id: number) => void;
}
```

## 6. Роутинг

Добавить в `src/routes.tsx`:
```typescript
{ path: '/backtests/:id', element: <BacktestResultsPage /> }
```

Обновить sidebar: элемент «Бэктесты» ведёт на список бэктестов.

## 7. Активация кнопки «Запустить бэктест»

**ВАЖНО:** Вкладка «Код» убрана (решение заказчика). Кнопка «Запустить бэктест» теперь в **toolbar вкладки «Редактор»** (рядом с Zoom/Undo/Redo и кнопкой AI-помощника). В S3 была disabled — теперь активна. При клике — открывает BacktestLaunchModal.

Вкладки StrategyEditPage: **Содержание** | **Редактор** (вкладка «Код» убрана DEV-5).

# Тесты (src/__tests__/backtest/)

Минимум **20 тестов**:

1. **BacktestResultsPage** (4): renders overview tab, renders chart tab, renders trades tab, loading state
2. **MetricsGrid** (3): renders all metrics, green/red profit, handles nulls
3. **BacktestTrades** (3): renders table, pagination, filtering
4. **BacktestLaunchModal** (4): renders form, validation, disabled state (code errors), submit
5. **BacktestProgress** (3): renders progress, updates from WS, auto-navigate on complete
6. **AISettingsPage** (3): renders providers table, add provider modal, verify button

# Ветка

```
git checkout -b s4/backtest-ui develop
```

# Критерии приёмки

- [ ] BacktestResultsPage: 3 вкладки (Обзор, График, Сделки) работают
- [ ] MetricsGrid: все 8 метрик отображаются с правильным форматированием
- [ ] Equity curve + drawdown + benchmarks рисуются (Lightweight Charts)
- [ ] Свечной график с маркерами входа/выхода
- [ ] TanStack Table: сортировка, фильтрация, пагинация, экспорт CSV
- [ ] BacktestLaunchModal: валидация, disabled state, submit → POST
- [ ] BacktestProgress: WebSocket прогресс, авто-навигация
- [ ] AISettingsPage: CRUD провайдеров, verify, activate, usage stats
- [ ] Кнопка «Запустить бэктест» активна в StrategyEditPage
- [ ] ≥20 тестов, 0 failures
- [ ] Регрессия: все существующие тесты проходят
