# Sprint 8 — E2E Test Plan

> **Создан:** 2026-05-12 (W0 → W1 transition).
> **Автор:** оркестратор по правилу CLAUDE.md проекта «E2E тесты — обязательный процесс п.1: описание ПЕРЕД написанием spec'ов».
> **Покрытие S8:** 5 Playwright spec'ов + 1 pytest integration test (тикеты `S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17`).
> **Регрессионный baseline:** 142 Playwright nightly (после S7 closeout). Финальный таргет S8: **142 + 5 (новые) − 2 (Blockly mode B) = 145 Playwright passed / 0 failed** + 2 новых pytest integration (backup_cli).

## Источники

- `Sprint_8/arch_design_s8.md` §5 — детальные сценарии 6 missing spec'ов (источник истины).
- `Sprint_8/arch_design_s8.md` §11 — решения заказчика (batch 1 пункты 1–2, batch 3 пункты 8–9).
- `Sprint_8/prompt_QA.md` — задачи QA по wave (W0/W1/W2/W3).
- `Sprint_8/execution_order.md` — Cross-DEV contracts (потребитель: BACK1 admin / BACK2 event sync / BACK1 Plotly Dash / DEV-4 widgets).
- `Sprint_7/e2e_test_plan_s7.md` — образец формата плана и стиля сценариев.
- `Спринты/ui_checklist_s5r.md` — текущий UI-чеклист (база регрессии до обновления в S8).

## Тестовый аккаунт

`sergopipo` — правило памяти `user_test_credentials.md`; пароль спрашивать у заказчика. Подтверждено: запись `id=1, username='sergopipo'` в `Develop/backend/data/terminal.db`.

В моках (`Develop/frontend/e2e/fixtures/api_mocks.ts`) используется `injectFakeAuth(page)` с `user.id=1, username='e2e-user'` — для UI-only сценариев (CI=true, без реального backend). Сценарии W3 smoke поверх real backend используют `sergopipo`.

## 1. Общие принципы

- **Mock-based:** все Playwright spec'ы — `CI=true` (webServer отключён в `playwright.config.ts`). Используются моки из `Develop/frontend/e2e/fixtures/api_mocks.ts`.
- **Селекторы:** только `data-testid` атрибуты. CSS-классы запрещены (нестабильны при рефакторе UI).
- **Тест-пользователь:** `sergopipo` (real backend) / `e2e-user` (mock через `injectFakeAuth`).
- **Объём:** каждый Playwright spec ≤ 200 строк; pytest integration ≤ 200 строк.
- **Запуск spec'а локально:** `cd Develop/frontend && CI=true npx playwright test e2e/<file>.spec.ts --reporter=line`.
- **Запуск pytest:** `cd Develop/backend && .venv/bin/python -m pytest tests/integration/test_backup_cli.py -v`.
- **CI nightly:** после стабилизации новые spec'ы добавляются в `Develop/.github/workflows/playwright-nightly.yml`.

## 2. Расположение тестов

```
Develop/frontend/e2e/
├── s7-export.spec.ts                 # NEW (S7R-E2E-7.3)
├── s7-events.spec.ts                 # NEW (S7R-E2E-7.13)
├── s7-tg-callbacks.spec.ts           # NEW (S7R-E2E-7.14)
├── s7-backtest-analytics.spec.ts     # NEW (S7R-E2E-7.16)
└── s7-bg-backtest.spec.ts            # NEW (S7R-E2E-7.17)

Develop/frontend/e2e/fixtures/
└── api_mocks.ts                      # EXTEND: + mockWSChannel + mockBacktestWithTrades + AIChat block_xml

Develop/backend/tests/integration/
└── test_backup_cli.py                # NEW (S7R-E2E-7.9, pytest integration)
```

> Префикс `s7-` сохраняем (мы закрываем долг Sprint 7) — соответствует решению arch_design §11 batch 3.

## 3. Спецификации сценариев

### 3.1 `s7-export.spec.ts` (S7R-E2E-7.3) — Export CSV/PDF

**Предусловия:** `injectFakeAuth(page)`; мок `mockBacktestResults(page, { id, ticker, status, metrics })`.

#### Сценарий A — Download CSV (happy path)
- **Шаги:**
  1. Открыть `/backtest/1/results` (мок `id=1, status='completed', ticker='SBER'`).
  2. Кликнуть `[data-testid="export-csv-btn"]`.
  3. `const download = await page.waitForEvent('download')`.
  4. `download.saveAs(tmpPath)` → `fs.readFileSync(tmpPath, 'utf-8')`.
- **Ожидаемый результат:** content-type ответа содержит `text/csv`; содержимое файла начинается с подстроки `Тикер,` (заголовок CSV).
- **Селекторы:** `[data-testid="export-csv-btn"]`.

#### Сценарий B — Download PDF (happy path)
- **Шаги:**
  1. Открыть `/backtest/1/results`.
  2. Кликнуть `[data-testid="export-pdf-btn"]`.
  3. `page.waitForEvent('download')` → `saveAs(tmpPath)`.
- **Ожидаемый результат:** первые 4 байта файла === `%PDF`; `fs.statSync(tmpPath).size >= 5 * 1024` (≥ 5 KB).
- **Селекторы:** `[data-testid="export-pdf-btn"]`.

#### Сценарий C — Disabled при running (edge)
- **Предусловия:** `mockBacktestResults(page, { id: 2, status: 'running' })`.
- **Шаги:**
  1. Открыть `/backtest/2/results`.
  2. Проверить состояние кнопки.
- **Ожидаемый результат:** `[data-testid="export-csv-btn"]` имеет атрибут `disabled`; клик не вызывает download (нет события).
- **Tricky:** не использовать `waitForEvent('download')` с таймаутом — `toBeDisabled()` достаточно.

---

### 3.2 `tests/integration/test_backup_cli.py` (S7R-E2E-7.9) — Backup CLI

> **Тип:** **pytest integration** (НЕ Playwright). Решение arch_design §11 batch 3 пункт 8: «backup — backend CLI, не UI».

**Предусловия:**
- Фикстуры `tmp_path`, `monkeypatch`, `db_session` (из `Develop/backend/tests/conftest.py`).
- `data/backups/` writable (через monkeypatch `BACKUP_DIR` → `tmp_path / "backups"`).
- DB env-override поддерживается backup CLI (если нет — БЛОКЕР, согласовать с DEV-1).

#### Сценарий A — `create` создаёт файл
- **Шаги:**
  1. `monkeypatch.setenv("BACKUP_DIR", str(tmp_path / "backups"))`.
  2. `subprocess.run([sys.executable, "-m", "app.cli.backup", "create"], capture_output=True, check=True)`.
- **Ожидаемый результат:** в `BACKUP_DIR` ровно 1 файл `backup_*.sqlite`, `stat.st_size > 0`, exit code 0.

#### Сценарий B — Smoke create → delete → restore
- **Шаги:**
  1. Через `db_session` создать тестовую запись (например, `User(username='backup-smoke')`).
  2. `subprocess.run([..., "create"])` → получить путь к backup-файлу.
  3. Удалить запись (`db_session.delete(...)` + commit).
  4. `subprocess.run([..., "restore", str(backup_file)])`.
  5. `db_session.query(User).filter_by(username='backup-smoke').one()` — запись вернулась.
- **Ожидаемый результат:** обе записи (до и после restore) совпадают; exit code 0.

#### Сценарий C — Restore с несуществующим файлом (edge)
- **Шаги:** `subprocess.run([..., "restore", "/no/such/file.sqlite"], capture_output=True)`.
- **Ожидаемый результат:** exit code != 0, stderr содержит понятное сообщение (например, `File not found`).

---

### 3.3 `s7-events.spec.ts` (S7R-E2E-7.13) — 5 event_type через mock WS

> **Подход:** `page.route('**/ws/notifications', ...)` + push fixture-фреймов. Решение arch_design §11 batch 3 пункт 9: «БЕЗ `_test/emit-event` endpoint».

**Предусловия:** `injectFakeAuth(page)`; `mockWSChannel(page, 'notifications', frames)` (новый helper в `api_mocks.ts`); открыт DashboardPage.

**Шаблон сценария** (table-driven, `for...test`):

| # | event_type | severity | Expected text в bell |
|---|------------|----------|----------------------|
| 1 | `trade.opened` | info | «Позиция открыта» (для тикера SBER) |
| 2 | `order.partial_fill` | info | «Частичное исполнение» |
| 3 | `order.error` | warning | «Ошибка выставления» (жёлтая иконка severity=warning) |
| 4 | `positions.closed_all` | info | «Все позиции закрыты» |
| 5 | `connection.lost` / `connection.restored` | warning / info | «Соединение потеряно» / «Соединение восстановлено» |

- **Шаги (для каждого):**
  1. Подать WS frame через `mockWSChannel`: `{ event: '<type>', ticker: 'SBER', payload: {...} }`.
  2. Открыть `[data-testid="notification-bell"]`.
  3. Проверить текст уведомления.
- **Ожидаемый результат:** bell содержит текст из EVENT_MAP template; для `severity='warning'` дополнительно виден `[data-testid="severity-warning"]`.

> Контракт C: DEV-2 (BACK2) поставляет EVENT_MAP entries и publish-сайты. Spec может имитировать frames заранее; integration test `test_notification_e2e.py` валидирует реальный publish.

---

### 3.4 `s7-tg-callbacks.spec.ts` (S7R-E2E-7.14) — Telegram deep-links

**Подход:** Telegram callback приходит через webhook (не от UI), spec симулирует переход по deep-link.

#### Сценарий A — `view_session` deep-link
- **Предусловия:** `mockSessions(page, [{ id: 42, ticker: 'GAZP', status: 'running' }])`.
- **Шаги:** `page.goto('/sessions/42?from=tg')`.
- **Ожидаемый результат:** `[data-testid="session-detail-42"]` видна; `[data-testid="session-ticker"]` содержит `GAZP`; параметр `?from=tg` сохраняется в URL (для трекинга sourcing).

#### Сценарий B — `view_chart` deep-link
- **Предусловия:** `mockMoexCandles(page, { ticker: 'SBER', tf: '5m' })`.
- **Шаги:** `page.goto('/chart?ticker=SBER&tf=5m&from=tg')`.
- **Ожидаемый результат:** `[data-testid="chart-container"]` видна; `[data-testid="chart-ticker-label"]` содержит `SBER`; selectedTimeframe = `5m`.

---

### 3.5 `s7-backtest-analytics.spec.ts` (S7R-E2E-7.16) — Analytics

**Предусловия:** `mockBacktestWithTrades(page, trades[])` (новый helper) — 10 сделок c P&L `[+1500, -800, +2200, ...]`; открыта `/backtest/1/analytics`.

#### Сценарий A — Hover зоны equity-curve → tooltip
- **Шаги:** `page.getByTestId('equity-curve-zone-2').hover()`.
- **Ожидаемый результат:** `[data-testid="trade-tooltip"]` видна; содержит price_in, price_out, P&L 3-й сделки (zone-2 = индекс 2, 0-based).

#### Сценарий B — Click зоны → trade detail panel
- **Шаги:** `page.getByTestId('equity-curve-zone-4').click()`.
- **Ожидаемый результат:** `[data-testid="trade-detail-panel"]` видна; содержит детали 5-й сделки (entry/exit/pnl/commission).

#### Сценарий C — Histogram render
- **Ожидаемый результат:** `[data-testid="pnl-histogram"]` видна; locator `[data-testid^="hist-bar-"]` имеет `>= 1` bar.

#### Сценарий D — Donut Win/Loss
- **Ожидаемый результат:** `[data-testid="win-loss-donut"]` видна; locator `[data-testid^="donut-seg-"]` имеет ровно 2 сегмента.

---

### 3.6 `s7-bg-backtest.spec.ts` (S7R-E2E-7.17) — Background backtest

**Подход:** `mockBacktestRun` + `mockWSChannel('backtest:<job_id>', frames)`.

#### Сценарий A — Запуск в фоне → toast
- **Шаги:**
  1. Открыть `/backtest/new`, задать параметры.
  2. Кликнуть `[data-testid="run-in-background-btn"]`.
- **Ожидаемый результат:** виден toast «Запущен в фоне»; `[data-testid="bg-backtest-badge"]` содержит `1`.

#### Сценарий B — WS frame `completed` → badge декремент
- **Предусловия:** badge стартует с `1` (из A).
- **Шаги:** подать WS frame `{ event: 'completed', job_id: '<id>', result: {...} }`.
- **Ожидаемый результат:** `[data-testid="bg-backtest-badge"]` либо скрывается, либо содержит `0` (`not.toBeVisible({ timeout: 5000 })`).

#### Сценарий C — Cap превышен
- **Шаги:** запустить 3 фоновых бэктеста подряд (badge = `3`); запустить 4-й.
- **Ожидаемый результат:** toast «Превышен лимит параллельных бэктестов»; badge остаётся `3` (не инкрементится).

## 4. Новые helpers в `api_mocks.ts` (W1)

| Helper | Сигнатура | Применение |
|--------|-----------|------------|
| `mockWSChannel(page, channel, frames[])` | `Promise<void>` | задачи 3.3 (events), 3.6 (bg-backtest) |
| `mockBacktestWithTrades(page, trades[])` | `Promise<void>` | задача 3.5 (analytics) |
| `mockBacktestRun(page, { mode })` | `Promise<void>` | задача 3.6 (bg-backtest) |
| `mockMoexCandles(page, { ticker, tf })` | `Promise<void>` | задача 3.4 (tg-callbacks chart) |
| (расширение) `mockBacktestResults` — добавить параметр `status` | — | задача 3.1 (export edge case) |

> Существующие helpers (`injectFakeAuth`, `mockAuthEndpoints`, `mockSessions`, `mockAiChat`) НЕ переписывать — только дополнять.

## 5. AIChat mock (W2)

Решение arch_design §11 batch 1 пункт 2: «дополнить мок реалистичным `block_xml`, снять skip».

- В `mockAiChat` ответе assistant добавить валидный Blockly XML с ≥ 3 блоками (condition + indicator + action). Пример:
  ```xml
  <xml xmlns="https://developers.google.com/blockly/xml">
    <block type="when_condition"><field name="OP">crosses_above</field>...</block>
    <block type="indicator_rsi"><field name="PERIOD">14</field></block>
    <block type="action_buy"><field name="QTY">1</field></block>
  </xml>
  ```
- Через `grep -rn "S6R-AICHAT-APPLY-MOCK" Develop/frontend/e2e/` найти `test.skip(..., 'S6R-AICHAT-APPLY-MOCK')`, перевести в активный `test(...)`.
- Sanity: после `Apply` → `[data-testid="blockly-workspace"]` содержит ≥ 3 блока.

## 6. Регрессионная защита (W3)

### 6.1 Удаление зомби-spec'ов Blockly mode B
Решение arch_design §11 batch 1 пункт 1: «фича удалена из UI в S5/S6, spec'ы зомби».

- `grep -rn "S5R-BLOCKLY-MODE-B-MODAL\|S5R-BLOCKLY-MODE-B-CHECK" Develop/frontend/e2e/` → найти и удалить тесты **целиком** (не `.skip`).
- Если файл становится пустым — удалить файл целиком.
- После удаления: `grep -rn "S5R-BLOCKLY-MODE-B" Develop/frontend/e2e/` → пусто.

### 6.2 Финальный регрессионный прогон
- **Frontend Playwright:** `cd Develop/frontend && CI=true npx playwright test` → ожидание **145 passed / 0 failed** (= 142 baseline + 5 новых − 2 удалённых). При добавлении DEV-3/DEV-4 spec'ов цифра вырастет — фиксируем фактическую в отчёте W3.
- **Backend pytest unit:** `cd Develop/backend && .venv/bin/python -m pytest tests/unit/ -q` → ≥ 750 passed / 0 failed (S8 baseline; растёт от coverage P0+P1+P2 DEV-1/DEV-2).
- **Backend pytest integration:** `.venv/bin/python -m pytest tests/integration/ -q` → 0 failed; новый `test_backup_cli.py` — 3 passed.

### 6.3 E2E coverage отчёт
- Результаты прогона прикладываются в `Sprint_8/reports/QA_W2W3_regression.md` (≤ 400 слов, 9 секций по шаблону из `prompt_QA.md`).
- Дублирующая сводка — в `Sprint_8/arch_review_s8.md` (критерий S5R.5: passed/failed, а не «файлы созданы»).

## 7. Инфраструктура (preflight, дополнения)

В `Sprint_8/preflight_checklist.md` зафиксировать:
- `cd Develop/frontend && npx playwright --version` → ≥ 1.40.
- `npx playwright install chromium` (если не установлены браузеры).
- `Develop/frontend/playwright.config.ts` корректен (CI=true отключает webServer, mock-based).
- `Develop/frontend/e2e/fixtures/api_mocks.ts` существует и компилируется (`npx tsc --noEmit`).
- `Develop/backend/tests/integration/` существует, `conftest.py` экспортирует `db_session` + `test_user`.
- `Develop/backend/app/cli/backup.py` — backup CLI (S7 deliverable DEV-1). Поддержка env `BACKUP_DIR` — подтвердить с DEV-1.
- `data-testid` атрибуты добавлены в новые компоненты от DEV-3/DEV-4 (обязанность DEV; QA проверяет через `grep -rn "<testid>" Develop/frontend/src/`).

В `Sprint_8/execution_order.md` — шаг W3 «прогнать backend pytest + frontend Playwright» (real backend smoke только для AIChat W2 и backup pytest W1).

## 8. Тест-окружение

- **E2E пользователь:** `sergopipo`, пароль через ENV `E2E_PASSWORD` (real backend smoke W3); для mock-based UI — `injectFakeAuth(e2e-user)`.
- **CI:** `CI=true`, без реального backend, mock-based.
- **Browser:** chromium (default).
- **Параллелизм:** `workers=4` в CI.
- **Trace:** `--trace=on-first-retry` (для диагностики flaky).

## 9. Acceptance criteria (sprint exit)

- [ ] 5 Playwright spec'ов созданы (`s7-export`, `s7-events`, `s7-tg-callbacks`, `s7-backtest-analytics`, `s7-bg-backtest`) и проходят локально.
- [ ] 1 pytest integration test `tests/integration/test_backup_cli.py` создан и проходит (3 сценария).
- [ ] Регрессия 142 baseline + 5 новых − 2 удалённых = **145 Playwright passed / 0 failed** (минимум; больше при участии DEV-3/DEV-4).
- [ ] 2 spec'а Blockly mode B (`S5R-BLOCKLY-MODE-B-MODAL`, `S5R-BLOCKLY-MODE-B-CHECK`) удалены полностью.
- [ ] AIChat mock дополнен реалистичным `block_xml`, `test.skip('S6R-AICHAT-APPLY-MOCK')` снят.
- [ ] Все 6 spec'ов используют `data-testid` локаторы, ≤ 200 строк каждый.
- [ ] Skip-тикеты (если есть) имеют карточки в `Sprint_8_Review/backlog.md`.
- [ ] Отчёты `QA_W0_plan_sync.md`, `QA_W1_6_specs.md`, `QA_W2W3_regression.md` сохранены в `Sprint_8/reports/`.
- [ ] Результаты приложены в `Sprint_8/arch_review_s8.md` (passed/failed, не «файлы созданы»).

## 10. Связь с UI-чеклистом

После завершения W3 — обновить `Sprint_8/ui_checklist_s8.md` (или базовый `Спринты/ui_checklist_s5r.md` → версия `s8`):
- Раздел «E2E coverage»: список 6 новых тикетов `S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17` → ✅.
- Раздел «Регрессия»: 145+ Playwright nightly зелёный, фактическое число.
- Раздел «Удалено»: 2 зомби-spec'а Blockly mode B.
- Раздел «AIChat»: skip `S6R-AICHAT-APPLY-MOCK` снят, mock дополнен `block_xml`.
