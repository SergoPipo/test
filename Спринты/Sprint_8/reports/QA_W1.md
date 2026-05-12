# QA отчёт — Sprint 8, W1 (6 missing E2E spec'ов)

## 1. Что реализовано
- 5 Playwright spec'ов (`s7-export`, `s7-events`, `s7-tg-callbacks`, `s7-backtest-analytics`, `s7-bg-backtest`) + 1 pytest integration (`test_backup_cli.py`).
- Расширен `e2e/fixtures/api_mocks.ts`: новые helpers `mockWSChannel` (через `page.routeWebSocket`, Playwright 1.59), `mockBacktestResults`, `mockBacktestWithTrades`, `mockBacktestRun`, `mockMoexCandles`. Существующие helpers НЕ переписывались.
- Подход к WS (arch_design §11 batch 3 п.9): подмена singleton `/ws?token=...` через `page.routeWebSocket` без `_test/emit-event` endpoint.
- Backup CLI тест (arch_design §11 batch 3 п.8): pytest+`subprocess.run` вместо Playwright spec; использует CLI flag `--backup-dir` (env-var `BACKUP_DIR` CLI не поддерживает — подтверждено в `app/cli/backup.py`).
- `playwright.config.ts`: `reuseExistingServer=true` для CI-режима локального прогона (не влияет на nightly CI).

## 2. Файлы
- **Новые:** `Develop/frontend/e2e/s7-export.spec.ts`, `s7-events.spec.ts`, `s7-tg-callbacks.spec.ts`, `s7-backtest-analytics.spec.ts`, `s7-bg-backtest.spec.ts`; `Develop/backend/tests/integration/__init__.py`, `test_backup_cli.py`.
- **Изменённые:** `Develop/frontend/e2e/fixtures/api_mocks.ts` (+~310 строк helpers), `Develop/frontend/playwright.config.ts` (reuseExistingServer для CI).
- **Удалённые:** нет (Blockly mode B — W3).

## 3. Тесты (РЕАЛЬНО ПРОГНАНЫ)
- `s7-export.spec.ts` → **3/3 passed** (CSV, PDF, running status).
- `s7-events.spec.ts` → **6/6 passed** (5 event_type + connection.restored, table-driven).
- `s7-tg-callbacks.spec.ts` → **2/2 passed** (view_session, view_chart).
- `s7-backtest-analytics.spec.ts` → **3 passed / 2 skipped** (C histogram, D donut, B+ trade rows — passed; A equity-zone hover и B trade-row click — skip, blocked: см. секцию 6).
- `s7-bg-backtest.spec.ts` → **3/3 passed** (badge=1, popover rows, cap=3).
- `tests/integration/test_backup_cli.py` → **3/3 passed** (`pytest -v`, 0.4s).
- **Все 5 spec'ов вместе:** 17 passed / 2 skipped (24.1s).
- **Полная регрессия Playwright:** 157 passed / 1 failed / 6 skipped / 1 did not run (5.8 мин). 1 failure — pre-existing `s5-paper-trading.spec.ts:143 pause and resume session` (resume-btn не найден; падает изолированно, не связан с моими изменениями, в S5 baseline помечен flaky).

## 4. Integration points
- `data-testid` найдены в product code: `export-csv-btn/export-pdf-btn` (BacktestResultsPage:223,234), `notification-bell` (NotificationBell:63), `bg-backtest-badge/bg-backtest-badge-btn/bg-backtest-popover` (BackgroundBacktestsBadge:126,134,143), `pnl-histogram`/`pnl-histogram-bar-N` (PnLDistributionHistogram), `win-loss-donut/-wins/-losses/-total` (WinLossDonutChart), `chart-page/chart-empty-state` (ChartPage:230,242), `session-dashboard` (SessionDashboard:102), `backtest-overview-tab/tab-trades/backtest-trades/trade-detail-panel/trade-detail-pnl` (BacktestResultsPage/BacktestTrades/TradeDetailsPanel).
- `mockWSChannel`/`mockBacktestResults`/`mockBacktestWithTrades`/`mockBacktestRun`/`mockMoexCandles` экспортированы из `e2e/fixtures/api_mocks.ts:665+`.
- **NOT CONNECTED / BLOCKED:** `equity-curve-zone-*` (отсутствует — canvas pixel-based hover в InstrumentChart), `trade-tooltip` (зависит от canvas), trade-row onClick (rows без handler в BacktestTrades.tsx) — см. секцию 6.

## 5. Контракты для других DEV
- **Использую (потребитель):** dashboard widgets (FRONT2) — `bg-backtest-badge` rendering, NotificationBell в Header. event sync publishers (BACK2 W2) — здесь имитирую через mock WS frames (без real backend). admin role (BACK1 W1) — не используется в W1 specs.
- **Поставляю:** mock helpers через `api_mocks.ts` (reusable для других spec'ов).

## 6. Проблемы / TODO
Skip-тикеты (требуют карточек в backlog):
- `S8R-ANALYTICS-EQUITY-ZONES-TESTID` — equity-curve zones отрисованы canvas-only в `InstrumentChart.tsx`, hover/click работает через pixel-coord listeners. Нужны `data-testid="equity-curve-zone-N"` DOM-overlay для E2E hover.
- `S8R-ANALYTICS-TRADE-ROW-CLICK` — rows в `BacktestTrades.tsx` (TanStack table) не имеют `onClick` хендлера; открыть `trade-detail-panel` через клик из таблицы невозможно — только через canvas-zone click. Нужен handler + `data-testid="backtest-trade-row-N"`.
- Pre-existing flaky `s5-paper-trading.spec.ts:143` (resume-btn) — НЕ исправлено в scope W1.

## 7. Применённые Stack Gotchas
- **Gotcha 9** (`gotcha-09-playwright-strict.md`): все локаторы через `getByTestId`, не CSS-классы.
- **Gotcha 1** (`gotcha-01-pydantic-decimal.md`): в mock backtest `net_profit_pct`/`win_rate` приведены к Number (frontend вызывает `.toFixed()`), `pnl`/`entry_price` — строки.
- **Gotcha 10** (`gotcha-10-moex-e2e-session.md`): все backtest/MOEX тесты mock-based, не зависят от торговой сессии.

## 8. Новые Stack Gotchas
- **Playwright `page.route` vs `route.fallback` для overlapping patterns + Mantine 0-height bars** — симптом: `[data-testid^="pnl-histogram-bar-"].toBeVisible()` возвращает hidden (низкая частота bucket → height=0). Правило: для DOM-элементов с возможной нулевой высотой использовать `toBeAttached()` или проверять `count()`, не `toBeVisible()`. Related: `frontend/e2e/s7-backtest-analytics.spec.ts:92`.

## 9. Использование плагинов
- playwright: использован для 5 spec'ов (запуск + диагностика failure через trace/error-context). Все spec'ы реально выполнены, числа passed/failed зафиксированы.
- typescript-lsp: fallback `npx tsc --noEmit` — 0 errors.
- pyright-lsp: fallback `pytest -v` — 3 passed.
- context7: не привлекал (Playwright `routeWebSocket` подсказан из доки 1.48+ release notes; в проекте Playwright 1.59).
- code-review: не запускал (только W1 deliverable, /code-review — финал W3 по плану).

## Статус
**DONE_WITH_CONCERNS** — все 6 заданий W1 закрыты с покрытием 17 passed sub-tests + 3 pytest, но 2 сценария analytics (equity-zone hover, trade-row click) заблокированы отсутствием data-testid/onClick в product code. Заведены skip-тикеты с обоснованием: `S8R-ANALYTICS-EQUITY-ZONES-TESTID`, `S8R-ANALYTICS-TRADE-ROW-CLICK`. Регрессия 157 passed / 1 failed (failure pre-existing). Финальный коммит — за оркестратором.
