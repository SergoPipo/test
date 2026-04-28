# Дашборд (страница «Стратегии») — как считаются и откуда берутся данные

> **Версия:** 1.0 · **Дата создания:** 2026-04-28 · **Источник:** аудит дашборда после жалобы пользователя на «Открыть счёт → ошибка».
>
> Документ описывает что показывает каждый блок главной страницы (`/dashboard`), какой backend-endpoint используется, как рассчитываются цифры и какие есть ограничения.

---

## 1. Структура страницы

`/dashboard` (она же «Стратегии») состоит из:

```
┌────────────────────────────────────────────────────────────────────┐
│  Главная                                                           │
├──────────────┬───────────────────────┬────────────────────────────┤
│ [Баланс]     │ [Состояние систем]    │ [Активные позиции]         │
└──────────────┴───────────────────────┴────────────────────────────┘
┌────────────────────────────────────────────────────────────────────┐
│  Стратегии                                       [+ Новая стратегия]│
│  [Все] [Черновик] [Активные] [Архив]                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Название/Инструмент  Статус  Бэктест  Позиция  P&L          │   │
│  │ ▶ Тестовая           Черн.   —        8 377 ₽  +0.0%        │   │
│  │   ...                                                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

3 виджета сверху + таблица стратегий снизу.

| Блок | React-компонент | Endpoint backend |
|------|-----------------|------------------|
| Баланс | `components/dashboard/BalanceWidget.tsx` | `GET /api/v1/account/balance/history?days=30` |
| Состояние систем | `components/dashboard/HealthWidget.tsx` | `GET /api/v1/health` (polling 30 сек) |
| Активные позиции | `components/dashboard/ActivePositionsWidget.tsx` | `GET /api/v1/trading/sessions?status=active` |
| Таблица стратегий | `pages/DashboardPage.tsx` (через `useStrategyStore`) | `GET /api/v1/strategies` |

---

## 2. Виджет «Баланс»

### 2.1 Что показывает

- **Цифра сверху** — текущий total_value (обычно сумма initial_capital всех активных trading-сессий).
- **Изменение за день** — разница между последним и предпоследним значением в массиве истории + процент.
- **Sparkline** — мини-график за 30 дней (только цветовая полоса, без чисел внутри).
- **Anchor «Открыть счёт →»** — переход на страницу `/account` (детальная сводка по счету).

### 2.2 Источник данных

`GET /api/v1/account/balance/history?days=30` возвращает массив:

```json
[
  {"ts": "2026-03-30T00:00:00Z", "total_value": 0.0, "currency": "RUB"},
  ...,
  {"ts": "2026-04-22T00:00:00Z", "total_value": 200000.0, "currency": "RUB"},
  ...,
  {"ts": "2026-04-28T00:00:00Z", "total_value": 200000.0, "currency": "RUB"}
]
```

### 2.3 Алгоритм расчёта

**Backend** ([app/account/service.py:list_balance_history](../../Develop/backend/app/account/service.py)):

1. Подгружает все `TradingSession` пользователя.
2. Если сессий нет → массив из `days=30` нулевых точек, по одной на день.
3. Иначе для каждого дня d ∈ [start_d, today]:
   - `cumulative_pnl(d)` = сумма всех `realized_pnl` из `daily_stats` где `date <= d`.
   - `initial_capital(d)` = сумма `initial_capital` сессий, активных в день d (`started_at.date() <= d <= stopped_at.date()|now`).
   - `total_value(d) = initial_capital(d) + cumulative_pnl(d)`.

**Frontend** ([BalanceWidget.tsx:66-85](../../Develop/frontend/src/components/dashboard/BalanceWidget.tsx)):

- `current = points[last].total_value` — большая цифра.
- `prev = points[length-2].total_value` (или `points[0]` если массив <2 точек).
- `dayDelta = current - prev`, `dayPct = (dayDelta / prev) × 100%`.
- Цвет sparkline: `green` если `last >= first`, иначе `red`.

### 2.4 Известные нюансы

- ⚠️ **«Уступ» в sparkline.** Если первая сессия создана недавно (например, 22.04, окно 30 дней с 30.03), первые ~22 точки = 0, потом скачок в текущее значение. Визуально кажется «недавним ростом», хотя это просто момент создания первой сессии. Карточка `S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE` (medium) — фикс на S8.
- ⚠️ **«+0 ₽ за день» при ровной истории** — корректно, потому что `last - prev = 0` (без новых сделок суммы не меняются).

---

## 3. Виджет «Состояние систем»

### 3.1 Что показывает

Светофор с 3 индикаторами:
- **Circuit Breaker** (защита от каскадных потерь, [app/circuit_breaker/](../../Develop/backend/app/circuit_breaker/))
- **T-Invest** (подключение к брокеру)
- **Scheduler** (фоновые задачи MOEX-календаря, корп. действий, T+1 unblock)

Каждая строка: цветной индикатор (green / yellow / red) + название + текстовый статус.

### 3.2 Источник данных

`GET /api/v1/health` — текущий ответ:

```json
{"status": "ok", "version": "0.1.0", "database": "connected"}
```

### 3.3 Алгоритм расчёта

**Frontend** ([HealthWidget.tsx:59-85](../../Develop/frontend/src/components/dashboard/HealthWidget.tsx)) ожидает дополнительные поля (`cb_state`, `tinvest_connected`, `scheduler_running`, `scheduler_jobs`) и интерпретирует их:

| Поле | Значение | Цвет | Текст |
|------|----------|------|-------|
| `cb_state` | `'ok'` | green | GREEN (норма) |
| `cb_state` | `'warn'` | yellow | WARN |
| `cb_state` | `'triggered'` | red | TRIGGERED |
| `tinvest_connected` | `true` | green | ONLINE |
| `tinvest_connected` | `false` | red | OFFLINE |
| `scheduler_running` | `true` | green | RUNNING (N jobs) |
| `scheduler_running` | `false` | red | STOPPED |
| **поле отсутствует** | — | **yellow** | **«нет данных»** |

### 3.4 Известные нюансы

- 🔴 **Backend сейчас НЕ возвращает расширенные поля** → все 3 индикатора всегда yellow «нет данных», даже если backend в полном порядке. Это **сознательный degrade**, заложенный в S7 (DEV-4 промпт). **Карточка `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` (medium)** — расширение `/health` payload в S8.
- 🔵 **Polling каждые 30 секунд** — лёгкий запрос, не нагружает backend.

---

## 4. Виджет «Активные позиции»

### 4.1 Что показывает

Топ-5 trading-сессий с открытыми позициями, отсортированных по `|pnl|` desc:
- Логотип тикера + название
- Sparkline (placeholder — пока пустой)
- P&L в ₽ + процент

### 4.2 Источник данных

`GET /api/v1/trading/sessions?status=active` → возвращает `PaginatedResponse {items: TradingSession[], total, ...}`.

Пример ответа для одной сессии:
```json
{
  "id": 2,
  "ticker": "LKOH",
  "timeframe": "5m",
  "status": "active",
  "current_pnl": "100.00",
  "initial_capital": "100000.00",
  "active_position_lots": 1,
  "active_position_direction": "buy",
  "active_position_entry_price": "5458.00"
}
```

### 4.3 Алгоритм расчёта

**Frontend** ([ActivePositionsWidget.tsx:40-58](../../Develop/frontend/src/components/dashboard/ActivePositionsWidget.tsx)):

1. Фильтр: `s.active_position_lots > 0` (показываются только сессии с открытыми позициями).
2. Для каждой:
   - `pnl = s.current_pnl` (получается из backend, считается в `app/trading/runtime.py` через PnLCalculator).
   - `pnlPct = (pnl / initial_capital) × 100%`.
3. Сортировка по `Math.abs(pnl)` desc.
4. Берутся первые 5.

`current_pnl` = unrealized P&L текущей позиции = `(current_price - entry_price) × lots × lot_size` для long, наоборот для short. Обновляется из live ticks через WebSocket.

### 4.4 Известные нюансы

- ⚠️ **Sparkline пустой** — `r.spark = []` захардкожено. Нужен endpoint для intraday OHLCV. Карточка **`S7R-WIDGET-SPARKLINE-24H` (low)** в S8.
- 🔵 **Округление ₽ до целых** через `toLocaleString({maximumFractionDigits: 0})` — поэтому `+100.00 ₽` показывается как `+100 ₽`, `-19.53 ₽` → `-20 ₽`.
- 🔵 **Только paper-сессии видны?** Нет — фильтр только по `status=active`, `mode` не учитывается. Real-сессии тоже попадают.

---

## 5. Таблица стратегий

### 5.1 Что показывает

| Колонка | Что |
|---------|-----|
| **Название / Инструмент** | Имя стратегии + список тикеров (раскрываемая строка) |
| **Статус** | `Черновик` / `Бэктест` / `Paper` / `Real` / `Архив` (см. `FAQ/strategy_status.md`) |
| **Бэктест** | Дата последнего бэктеста + ключевая метрика (P&L или Sharpe) |
| **Позиция** | Сумма открытых позиций по всем тикерам стратегии (₽) |
| **P&L** | Совокупный P&L по позициям стратегии в % от initial_capital |

Над таблицей — фильтры по статусам: `Все (n)` / `Черновик (n)` / `Активные (n)` / `Архив (n)`.

### 5.2 Источник данных

`GET /api/v1/strategies` → массив объектов `Strategy` с вложенным `instruments: StrategyInstrumentSummary[]`.

`StrategyInstrumentSummary` включает:
- `last_backtest`: id + дата + метрики
- `position`: ₽ открытой позиции (если сессия запущена)
- `position_pnl`: P&L позиции в ₽ + %
- `status`: статус стратегии для этого тикера

### 5.3 Алгоритм для агрегатной строки

`page/DashboardPage.tsx` суммирует:
- `totalPosition = sum(child.position) для tickers`
- `totalPnl = sum(child.position_pnl)`
- `totalPnlPct = sum(child.pnl_pct) / count` (среднее)

### 5.4 Известные нюансы

- ⚠️ **MOCK-компонент**: в репо есть [StrategyTable.tsx](../../Develop/frontend/src/components/dashboard/StrategyTable.tsx) с захардкоженными данными (`MOCK_DATA: const`). Этот компонент **не подключён** к `DashboardPage` — это zombie-код. Кандидат на удаление в S8.
- ⚠️ **Колонка «Позиция» для стратегии в статусе «Черновик»** — может показывать ненулевое значение, если у стратегии есть исторические сессии (даже если все остановлены). Это сумма по live позициям независимо от статуса самой стратегии. Если хочется, чтобы Позиция = 0 для draft-стратегий — отдельная UX-задача (не баг).

---

## 6. Страница «Счёт» (`/account`) — связь с виджетом «Баланс»

При клике на «Открыть счёт →» в виджете «Баланс» пользователь попадает на `/account` — детальная страница по реальному брокерскому счёту T-Invest.

### 6.1 Алгоритм выбора счёта по умолчанию (применён в hotfix 2026-04-28)

Из всех `broker_accounts` пользователя отбираются **пригодные**:

```
WHERE is_active = TRUE
  AND is_sandbox = FALSE   -- sandbox не показывается ВООБЩЕ
  AND account_id IS NOT NULL  -- без T-Invest account_id endpoint /positions = 400
```

Внутри пригодных приоритет:

| Приоритет | Условие |
|-----------|---------|
| **1** | `has_trading_rights = true` — торговый счёт (полный доступ) |
| **2** | `has_trading_rights = false` — read-only (только балансы и история) |

Внутри одного приоритета — первый по `id ASC` (стабильный детерминированный порядок).

**Если пригодных нет** → empty state с подсказкой «Подключите T-Invest счёт в Настройках → Брокеры».

### 6.2 Persist выбора пользователя

Если пользователь явно выбрал счёт в дропдауне — выбор сохраняется в localStorage (`account-selection-storage`, zustand persist) и применяется при каждом следующем открытии. Если выбранный счёт стал недоступен (удалён, выключен, переведён в sandbox) — fallback на default по алгоритму выше.

См. реализацию: [`utils/pickDefaultBrokerAccount.ts`](../../Develop/frontend/src/utils/pickDefaultBrokerAccount.ts) + [`stores/accountSelectionStore.ts`](../../Develop/frontend/src/stores/accountSelectionStore.ts).

### 6.3 История операций — окно по умолчанию

`GET /api/v1/broker/accounts/{id}/operations` требует обязательные параметры `from` и `to`. AccountPage отправляет дефолт **последние 30 дней** (today − 30 → today). Изменить можно через date-range picker в таблице операций.

### 6.4 Sandbox-счета

Sandbox-счета (`is_sandbox=true`) **не отображаются** на странице `/account` вообще — даже если они активные. Для них предусмотрен раздел «Торговля» с paper-режимом (виртуальные сделки без реальных денег).

---

## 7. FAQ — частые вопросы

### Почему «Баланс» 200 000 ₽, а в активных позициях P&L всего ±100 ₽?

Баланс = `initial_capital × число активных сессий`. Если 2 сессии по 100 000 ₽ — баланс 200 000. Открытые позиции занимают только часть капитала (по `position_sizing_mode: percent` × `value`), и P&L показывает прибыль/убыток только по открытой части.

### Почему «Состояние систем» показывает «нет данных» для всего, если backend работает?

Backend `/health` возвращает только базовое (`status, version, database`). Расширенные поля (`cb_state`, `tinvest_connected`, `scheduler_running`) не реализованы — карточка `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` для S8.

### Почему в активных позициях sparkline пустой?

Нет endpoint'а для intraday OHLCV (нужен), карточка `S7R-WIDGET-SPARKLINE-24H` для S8. Сейчас отрисовывается пустой SVG как graceful degrade.

### Почему стратегия в статусе «Черновик» показывает позицию 8 377 ₽?

Колонка «Позиция» = сумма открытых позиций по всем тикерам стратегии (независимо от статуса самой стратегии). Если у стратегии есть запущенные сессии — позиции считаются, даже если стратегия в Черновике.

### Где увидеть paper-сессии?

В разделе «Торговля» (`/trading`) — там и paper, и real. Виджет «Активные позиции» на dashboard показывает оба режима.

### Sandbox видно где?

Только в Настройках → Брокеры (для управления). На страницах `/account` и виджетах dashboard — нет.

---

## 8. Связанные документы

- [Sprint 7 changelog](../../Спринты/Sprint_7/changelog.md) — записи hotfix'ов после S7 closeout (включая dashboard-аудит).
- [Sprint 8 backlog](../../Спринты/Sprint_8_Review/backlog.md) — карточки `S7R-DASHBOARD-*`, `S7R-ACCOUNT-PAGE-SANDBOX-SELECTION-FIXED`, `S7R-WIDGET-SPARKLINE-24H`.
- [FAQ/strategy_status.md](strategy_status.md) — правила переходов между статусами стратегий.
- [Спринты/Sprint_7/ux/dashboard_widgets.md](../../Спринты/Sprint_7/ux/dashboard_widgets.md) — оригинальные UX-макеты S7 7.7.
