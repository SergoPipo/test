# UI-чеклист Sprint_5_Review

> Дополняет проверки предыдущих UI-чеклистов. Применяется при приёмке S5R и QA-прогонах перед Sprint 6.

## Torговая сессия — таймфрейм (S5R.2 Live Runtime Loop)

- [ ] Форма запуска торговой сессии (`LaunchSessionModal`) содержит селектор таймфрейма.
  - `data-testid="session-timeframe-select"`
  - 8 значений: `1m`, `5m`, `15m`, `1h`, `4h`, `D`, `W`, `M`
  - Значение по умолчанию: `D`
  - Required — попытка submit без таймфрейма → ошибка валидации (UI) и 422 (backend).
- [ ] На карточке активной торговой сессии (`SessionCard` в `ActiveSessionsList`) отображается badge таймфрейма.
  - Для legacy-сессий без `timeframe` — прочерк или скрытый badge (не краш).
- [ ] `/trading/sessions/:id` детальный экран показывает таймфрейм рядом с режимом (PAPER/REAL).
- [ ] Стратегия реагирует на закрытие бара выбранного таймфрейма — визуально подтверждается появлением событий `order.placed` в логе сессии только после закрытия свечи.

## Счёт — позиции и операции (S5R.3 Real Positions T-Invest)

- [ ] `/account` → таб «Позиции»: `PositionsTable` показывает реальные данные T-Invest.
  - Колонки: тикер, название, тип инструмента, количество, avg price, current price, unrealized P&L, currency, **source** (badge), blocked.
  - `data-testid="source-badge-strategy"` / `data-testid="source-badge-external"` — оба рендерятся в зависимости от происхождения позиции.
  - Все числовые поля корректно отображаются (нет `NaN`, `undefined`, пустых ячеек) — backend шлёт Decimal как строку, frontend парсит через `toNum()`.
- [ ] `/account` → таб «Операции»: `OperationsTable` показывает реальные типы T-Invest.
  - Типы: `BUY`, `SELL`, `DIVIDEND`, `COUPON`, `COMMISSION`, `TAX`, `OTHER` — каждый с иконкой.
  - Состояния: `EXECUTED`, `CANCELED`, `PROGRESS`.
  - Фильтр по диапазону дат `from`/`to` работает (POST на backend содержит query `from`/`to`).
  - Пагинация работает (default 100, максимум 500).
- [ ] Мульти-валютность: если у счёта есть позиции в RUB + USD + EUR — отображаются раздельно, без автоконвертации в рубли.
- [ ] При первом открытии вкладки `Счёт` backend вызывает `GET /broker/accounts/{id}/positions` и `GET /broker/accounts/{id}/operations` (не заглушки `return []`) — проверить в DevTools Network.

## E2E baseline (S5R.4)

- [ ] `npx playwright test` → 101 passed / 0 failed / 8 skipped (tracked: `S5R-FAVORITES-INPUT` ×4, `S5R-PAPER-REAL-MODE` ×1, `S5R-CHART-FRESHNESS` ×3).
- [ ] В папке `e2e/` нет не-spec файлов (`test-backtest-*.ts`, `test-lkoh-*.ts`, `check-*.ts`, `screenshot*.ts`) — только `*.spec.ts`.
- [ ] `.gitignore` содержит `e2e/screenshots/`, `playwright-report/`, `test-results/`.

## React 19 hooks rules (S5R.1)

- [ ] ESLint не выдаёт ошибок `react-hooks/refs`, `react-hooks/set-state-in-effect` в новых/редактированных компонентах:
  - `src/components/backtest/InstrumentChart.tsx`
  - `src/components/common/TickerLogo.tsx`
  - `src/components/backtest/BacktestLaunchModal.tsx`
  - `src/components/trading/LaunchSessionModal.tsx`
  - `src/components/layout/Sidebar.tsx`
  - `src/hooks/useWebSocket.ts`
  - `src/pages/ChartPage.tsx`
- [ ] TanStack Table `react-hooks/incompatible-library` warnings остаются только в `PositionsTable.tsx` и `BacktestTrades.tsx` (это known issue плагина, не ошибка).

## Circuit Breaker (S5R.2 уточнение)

- [ ] Проверки CB срабатывают **на закрытии свечи таймфрейма сессии**, не на каждый тик. Визуальное подтверждение: в event log сессии `cb.triggered` появляется с частотой закрытия бара (не чаще).
