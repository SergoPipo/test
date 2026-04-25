---
sprint: 7
agent: DEV-3
role: Frontend Core (FRONT1) — Charts + Trading + AI chat UX
wave: 1+2
depends_on: [ARCH W0, UX W0, BACK1 (для C1, C2), BACK2 (для C3)]
---

# Роль

Ты — Frontend-разработчик #1 (senior). Зона ответственности по RACI: Charts (TradingView/lightweight-charts) = R, Trading Panel = R, AI chat frontend = коллаборация с FRONT2.

На W1 закрываешь долг S6: интерактивные зоны бэктеста + аналитика, WS карточки сессий вместо polling, фоновый бэктест UI. На W2 — инструменты рисования, AI слэш-команды frontend, саппорт sparklines для дашборд-виджетов.

# Предварительная проверка

```
1. Окружение: Node.js ≥ 18, pnpm установлен.
2. Зависимости (W1): UX опубликовал backtest_overview_analytics.md, background_backtest_badge.md.
3. Зависимости backend (W1): BACK1 опубликовал JSON-схему C1, C2.
4. Зависимости (W2): UX опубликовал drawing_tools.md, ai_commands_dropdown.md.
5. Зависимости backend (W2): BACK2 опубликовал C3 (расширение ChatRequest.context).
6. Существующие файлы: Develop/frontend/src/{components,pages,stores,api}.
7. Тесты baseline: cd Develop/frontend && pnpm test → 0 failures.
8. Type-check baseline: npx tsc --noEmit → 0 errors.
```

# Обязательные плагины

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| typescript-lsp | **да** (после каждого Edit/Write на .ts/.tsx) | `npx tsc --noEmit` |
| context7 | **да** — lightweight-charts API, Mantine, WebSocket клиент, Zustand | WebSearch |
| playwright | **да** (mandatory скриншот после блока изменений в `components/`) | Попросить скриншот у заказчика |
| frontend-design | да (опционально) — для 7.16 (аналитика) и 7.6 (тулбар) | — |
| pyright-lsp | нет | — |
| superpowers TDD | нет (frontend, рекомендуется но не обязателен по CLAUDE.md) | — |
| code-review | нет | — |

# Обязательное чтение

1. **`Develop/CLAUDE.md`** полностью.
2. **`Develop/stack_gotchas/INDEX.md`** — особенно ловушки слоёв `frontend/`, `charts/`, `ws/`.
3. **`Спринты/Sprint_7/execution_order.md`** Cross-DEV contracts:
   - **Потребитель:** C1 (от BACK1), C2 (от BACK1), C3 (от BACK2).
4. **`Спринты/Sprint_7/ui_spec_s7.md`** (если создан UX) и **все 6 макетов** в `Sprint_7/ux/`:
   - `backtest_overview_analytics.md` — для 7.16.
   - `background_backtest_badge.md` — для 7.17-fe.
   - `drawing_tools.md` — для 7.6.
   - `ai_commands_dropdown.md` — для 7.19.
5. **`Спринты/Sprint_7/arch_design_s7.md`** — секции 4 (WS sessions), 5 (фоновый бэктест), 6 (AI commands).
6. **Память:** `project_s7_interactive_zones.md`, `project_s7_background_backtest.md`, `project_slash_commands.md`.
7. **`.claude/plans/purring-herding-badger.md`** — план AI-команд.

# Рабочая директория

`Develop/frontend/`

# Контекст существующего кода

- `src/pages/BacktestResultsPage.tsx` — страница результатов бэктеста с вкладками («График», «Обзор», «Сделки» и т.д.). Расширить вкладку «Обзор» для 7.16 аналитики.
- `src/components/charts/CandlestickChart.tsx` — основной график на lightweight-charts. Добавить интерактивные зоны (7.16) + инструменты рисования (7.6).
- `src/pages/TradingPage.tsx` — страница торговли с карточками сессий. Заменить polling на WS (7.15-fe).
- `src/components/BacktestLaunchModal.tsx` — модалка запуска бэктеста. Добавить кнопку «в фоне» (7.17-fe).
- `src/stores/marketDataStore.ts` — Zustand store для свечей.
- `src/stores/notificationsStore.ts` — Zustand store для in-app уведомлений (S6).
- `src/api/` — API клиенты (расширить для backtest grid C5, AI chat context C3).
- `src/components/AIChat/` — AI чат компоненты (для 7.19).
- `src/components/Header.tsx` — шапка приложения. Добавить бейдж фоновых бэктестов (7.17-fe).
- Polling в trading-сессиях: `setInterval(refetch, 10000)` — найти и удалить (правило C1: один источник правды).

# Задачи

## Задача 7.16: Интерактивные зоны + аналитика (W1, debt-перенос из S6)

### 7.16.1 — Интерактивные зоны на графике

В `src/components/charts/CandlestickChart.tsx`:

- **Hover на зону** — зона ярче, белый контур (использовать `priceLine` или `markers` API lightweight-charts).
- **Клик на зону** — открыть панель деталей сделки под графиком (новый компонент `TradeDetailsPanel`).
- **Источник данных:** `entry_reason` / `exit_reason` в `TradeRecord` (зависимость от backend, может потребоваться доработка S5 BACK2).

### 7.16.2 — Аналитика на вкладке «Обзор»

Источник: `Sprint_7/ux/backtest_overview_analytics.md` + память `project_s7_interactive_zones.md`.

Создать **2 компонента:**

```tsx
// src/components/backtest/PnLDistributionHistogram.tsx
export function PnLDistributionHistogram({ trades }: { trades: TradeRecord[] }) {
  // Бакеты по % P&L: -2%, -1.5%, ..., +4%, +4.5%
  // Красные столбики = убытки, зелёные = прибыли
  // Пунктирные вертикальные: средний убыток, средняя прибыль
  // Используем recharts (если уже есть) или Mantine charts
}

// src/components/backtest/WinLossDonutChart.tsx
export function WinLossDonutChart({ trades }: { trades: TradeRecord[] }) {
  // Donut: Победы (зелёный), Убытки (красный), Безубыточность (жёлтый)
  // В центре donut: число сделок
  // Справа: легенда с числами и %
}
```

Расположение — рядом на вкладке «Обзор» (`BacktestResultsPage` → `OverviewTab`).

## Задача 7.15-fe: WS-замена polling карточек сессий (W1)

**Контракт C1 (потребитель):**

```tsx
// src/hooks/useTradingSessionsWS.ts (новый)
export function useTradingSessionsWS(userId: number) {
  const [sessions, setSessions] = useState<TradingSession[]>([]);

  useEffect(() => {
    const ws = new WebSocket(`${WS_BASE}/ws/trading-sessions/${userId}?token=${token}`);
    ws.onmessage = (event) => {
      const { event: eventType, session_id, payload } = JSON.parse(event.data);
      // Обновить sessions согласно eventType (position_update | trade_filled | pnl_update | session_state)
    };
    ws.onclose = () => { /* reconnect strategy */ };
    return () => ws.close();
  }, [userId]);

  return sessions;
}
```

**Удалить polling** в `TradingPage.tsx`:

```tsx
// БЫЛО:
useEffect(() => {
  const interval = setInterval(refetchSessions, 10000);
  return () => clearInterval(interval);
}, []);

// СТАЛО — заменить на useTradingSessionsWS.
```

**Один PR — переход без двойного источника правды.**

## Задача 7.17-fe: Фоновый бэктест (W1)

**Контракт C2 (потребитель):**

### 7.17.1 — Кнопка «в фоне» в `BacktestLaunchModal`

Источник: `Sprint_7/ux/background_backtest_badge.md`.

```tsx
// src/components/BacktestLaunchModal.tsx — расширение

<Group>
  <Button onClick={handleLaunch}>Запустить</Button>
  <Button variant="outline" onClick={handleLaunchBackground}>
    Запустить в фоне
  </Button>
</Group>

const handleLaunchBackground = async () => {
  const { job_id } = await api.startBacktest(params);
  notifications.show({ message: 'Бэктест запущен в фоне' });
  backgroundBacktestsStore.add({ job_id, params, started_at: Date.now() });
  // Модалка остаётся открытой — пользователь может изменить параметры и запустить ещё
};
```

### 7.17.2 — Store фоновых бэктестов

```tsx
// src/stores/backgroundBacktestsStore.ts (новый)
interface BackgroundBacktest {
  job_id: string;
  params: BacktestParams;
  progress: number;  // 0..100
  status: 'queued' | 'running' | 'done' | 'error';
  result?: BacktestResult;
  started_at: number;
}

export const backgroundBacktestsStore = create<BackgroundBacktestsStore>((set, get) => ({
  items: [],
  add: (bt) => set(state => ({ items: [...state.items, { ...bt, progress: 0, status: 'queued' }] })),
  // подписка на /ws/backtest/{job_id} для каждого
}));
```

### 7.17.3 — Бейдж в шапке

```tsx
// src/components/Header.tsx — добавление
<BackgroundBacktestsBadge count={activeCount} />
```

С dropdown-выпадашкой со списком и прогрессом каждого.

## Задача 7.6: Инструменты рисования (W2)

Источник: `Sprint_7/ux/drawing_tools.md`.

Использовать lightweight-charts API (через context7 актуальная документация):

- **Трендовая линия** — два клика (точка1, точка2), отрисовка через `series.createPriceLine()` или `IChartApi` рисующих API.
- **Горизонтальный уровень** — один клик, persistent `priceLine`.
- **Прямоугольная зона** — drag, `RectangleSeries` (если доступно) или кастомный canvas overlay.

**Persist:**

```tsx
// src/utils/drawingsPersistence.ts
const STORAGE_KEY = (userId: number, ticker: string, tf: string) =>
  `drawings:${userId}:${ticker}:${tf}`;

export function saveDrawings(userId, ticker, tf, drawings) {
  localStorage.setItem(STORAGE_KEY(userId, ticker, tf), JSON.stringify(drawings));
}

export function loadDrawings(userId, ticker, tf): Drawing[] {
  const raw = localStorage.getItem(STORAGE_KEY(userId, ticker, tf));
  return raw ? JSON.parse(raw) : [];
}
```

**Тулбар** — `<DrawingToolbar>` слева/сверху графика с 3 кнопками + delete + clear all.

## Задача 7.19: AI слэш-команды frontend (W2)

**Контракт C3 (потребитель):** расширение `ChatRequest.context`.

Источник: `Sprint_7/ux/ai_commands_dropdown.md` + `.claude/plans/purring-herding-badger.md`.

### 7.19.1 — Dropdown при вводе `/`

```tsx
// src/components/AIChat/CommandsDropdown.tsx (новый)
const COMMANDS = [
  { name: '/chart', description: 'Контекст графика', argHint: 'TICKER [TF]' },
  { name: '/backtest', description: 'Метрики бэктеста', argHint: 'BACKTEST_ID' },
  { name: '/strategy', description: 'Код стратегии', argHint: 'STRATEGY_ID' },
  { name: '/session', description: 'Состояние сессии', argHint: 'SESSION_ID' },
  { name: '/portfolio', description: 'Текущий портфель', argHint: '' },
];
```

### 7.19.2 — Парсинг команды

```tsx
// src/components/AIChat/parseCommand.ts (новый)
export function parseCommand(input: string): { command: ChatContextItem | null, remainder: string } {
  // Парсим "/chart EURUSD 1H какой тренд?" → { context: { type: 'chart', id: 'EURUSD', tf: '1H' }, remainder: 'какой тренд?' }
}
```

### 7.19.3 — Рендер «контекстного блока»

В сообщении пользователя отображается chip:

```tsx
<Badge>📊 Chart: EURUSD, 1H</Badge>
```

Кликабельный → переход на `/chart?ticker=EURUSD&tf=1H`.

## Саппорт 7.7 (sparklines)

FRONT2 ведёт 7.7 (дашборд-виджеты) полностью, но для sparklines использует chart-обёртку из `src/components/charts/`. Координация: предоставить `<MiniSparkline data={...} color={...} />` компонент.

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Если ввёл `test.skip(reason, { tag: '@S7R-<NAME>' })` — карточка в backlog обязательна.

# Тесты

```
Develop/frontend/src/
├── components/charts/CandlestickChart.test.tsx     # 7.16: интерактивные зоны
├── components/backtest/PnLDistributionHistogram.test.tsx  # 7.16: рендер
├── components/backtest/WinLossDonutChart.test.tsx  # 7.16: рендер
├── hooks/useTradingSessionsWS.test.ts              # 7.15-fe: WS subscribe/unsubscribe
├── stores/backgroundBacktestsStore.test.ts         # 7.17-fe: add/update/remove
├── components/Header.test.tsx                      # 7.17-fe: бейдж
├── utils/drawingsPersistence.test.ts               # 7.6: localStorage
├── components/AIChat/parseCommand.test.ts          # 7.19: парсер команд
```

И E2E (`Develop/frontend/e2e/sprint-7/...`) пишет QA отдельно.

# Integration Verification Checklist

- [ ] **7.15-fe:** `grep -rn 'useWebSocket\|new WebSocket.*trading-sessions' Develop/frontend/src/` показывает использование.
- [ ] **7.15-fe:** `grep -rn 'setInterval.*sessions\|setInterval.*refetch' Develop/frontend/src/` → 0 (polling удалён).
- [ ] **7.16:** `grep -rn 'PnLDistributionHistogram\|WinLossDonutChart' Develop/frontend/src/` показывает использование на `BacktestResultsPage`.
- [ ] **7.17-fe:** `grep -rn 'BackgroundBacktestsBadge\|backgroundBacktestsStore' Develop/frontend/src/` показывает реализацию.
- [ ] **7.17-fe:** Бейдж подключен в `Header.tsx`.
- [ ] **7.17-fe:** Модалка `BacktestLaunchModal` НЕ закрывается на «в фоне» — проверить локально.
- [ ] **7.6:** `grep -rn 'DrawingToolbar\|drawingsPersistence' Develop/frontend/src/` показывает реализацию.
- [ ] **7.19:** `grep -rn 'CommandsDropdown\|parseCommand' Develop/frontend/src/` показывает использование.
- [ ] **Playwright скриншоты:** для 7.16, 7.17-fe, 7.6, 7.19 — приложить в отчёт.
- [ ] **Mantine modal lifecycle gotcha:** соблюдён для wizard и модалки бэктеста.

# Формат отчёта

**2 файла:**

1. **`reports/DEV-3_FRONT1_W1.md`** — после 7.15-fe, 7.16, 7.17-fe.
2. **`reports/DEV-3_FRONT1_W2.md`** — после 7.6, 7.19.

8 секций до 400 слов.

# Alembic-миграция

Не применимо (frontend).

# Чеклист перед сдачей

- [ ] Все задачи реализованы.
- [ ] `npx tsc --noEmit` → 0 errors.
- [ ] `pnpm test` → 0 failures.
- [ ] `pnpm lint` → no issues.
- [ ] Playwright скриншоты для UI-блоков приложены.
- [ ] Integration verification пройден.
- [ ] Контракты C1, C2, C3 как потребитель подтверждены.
- [ ] Stack Gotchas применены (минимум: lightweight-charts cleanup, WS reconnect, 401 cleanup, Mantine modal lifecycle).
- [ ] Skip-тикеты с карточками.
- [ ] `Sprint_7/changelog.md` обновлён.
- [ ] Отчёт сохранён файлом.
