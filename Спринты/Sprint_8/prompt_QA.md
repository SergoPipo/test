---
sprint: 8
agent: QA
role: E2E QA Engineer — 6 missing E2E specs + AIChat mock + regression suite
wave: 1+2+3
depends_on: [ARCH W0, DEV-2 W2 (event sync для events spec), DEV-4 W2 (widgets для regression)]
---

# Роль

Ты — Senior E2E QA Engineer. Зона ответственности по RACI: Playwright suite = R, pytest integration (CLI smoke) = R, mock infrastructure (`e2e/fixtures/api_mocks.ts`) = R, regression nightly = R.

В Sprint 8 закрываешь 6 missing E2E spec'ов (из закрытия S7 ушли в backlog как `S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17-MISSING`), дополняешь AIChat mock реалистичным `block_xml`, удаляешь 2 зомби-spec'а Blockly mode B и прогоняешь финальную регрессию (142 nightly + 6 новых = 148 spec'ов).

**Важно:** ты — потребитель ARCH W0 (`arch_design_s8.md` секция 5 — детальные сценарии всех 6 spec'ов) и контрактов DEV-2 W2 (event sync publishers) + DEV-4 W2 (widgets, `/admin/metrics`). E2E spec'ы по событиям не пишутся до того, как BACK2 подключит publish-сайты.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение:
   - Node ≥ 18, pnpm установлен
   - Playwright установлен: `cd Develop/frontend && npx playwright --version` → ≥ 1.40
   - Браузеры Playwright: `npx playwright install chromium` (если не установлены)
   - Python ≥ 3.11, .venv активирован для test_backup_cli.py
2. Зависимости предыдущих DEV (W1 → W2 → W3):
   - W1: ARCH утвердил `arch_design_s8.md` §5 (6 сценариев — детально)
   - W1: оркестратор создал `e2e_test_plan_s8.md` (по правилу CLAUDE.md проекта "E2E — обязательный процесс п.1: описание ПЕРЕД написанием spec'ов"). Если файла нет — БЛОКЕР.
   - W2: DEV-2 закрыл event sync publish-сайты (5 publish-сайтов BACK + EVENT_MAP entries) — без этого `s7-events.spec.ts` имитирует frames, но регрессия integration `test_notification_e2e.py` может падать
   - W2: DEV-4 закрыл widget'ы DashboardPage + Plotly Dash `/admin/metrics` — без этого regression nightly падает на новых dashboard сценариях
3. Существующие файлы:
   - `Develop/frontend/playwright.config.ts` — конфиг (CI=true mock-based)
   - `Develop/frontend/e2e/fixtures/api_mocks.ts` — существующая фабрика моков (mockBacktestResults, mockSessions, и т.д.)
   - `Develop/frontend/e2e/fixtures/moex_iss_mock.ts` — MOEX ISS моки
   - `Develop/frontend/e2e/` — flat-структура spec'ов (НЕ e2e/specs/!). Все новые spec'ы создавать прямо в `Develop/frontend/e2e/`.
   - `Develop/backend/tests/integration/` — каталог pytest integration (для backup_cli)
   - `Develop/backend/app/cli/backup.py` — backup CLI (S7 deliverable DEV-1)
4. База данных: alembic upgrade head выполнен (нужно для smoke create→backup→delete→restore).
5. Внешние сервисы: НЕ требуются (CI=true mock-based). Real backend для smoke check только в W3 regression.
6. Тесты baseline (зафиксируй ФАКТИЧЕСКИЕ значения, правило S5R.5):
   - `cd Develop/frontend && CI=true npx playwright test --list | tail -3` → ожидается ≥ 142 spec'ов
   - `cd Develop/frontend && CI=true npx playwright test` → 142 passed / 0 failed / 3 skip (nightly run #25736055151 от 12.05 13:00 МСК)
   - `cd Develop/backend && .venv/bin/python -m pytest tests/integration/ -q` → 0 failures
```

> Если хоть одно условие не выполнено — вернуть `БЛОКЕР: <описание>`.

# Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback (если MCP недоступен) |
|--------|--------|-------------------------------|
| playwright | **да, mandatory** — после каждого Edit/Write `.spec.ts` запустить spec в headed/headless: `cd Develop/frontend && CI=true npx playwright test e2e/<file>.spec.ts --reporter=line` | Попросить скриншот у заказчика |
| typescript-lsp | **да, mandatory** — после каждого Edit/Write `.ts/.spec.ts` файла | `cd Develop/frontend && npx tsc --noEmit` |
| pyright-lsp | **да** — для `tests/integration/test_backup_cli.py` | `cd Develop/backend && .venv/bin/python -m py_compile tests/integration/test_backup_cli.py` |
| context7 | **да** — `playwright` (page.route для WS mock, page.waitForEvent download, locator best practices, Playwright fixtures), `pytest` (subprocess.run integration, tmp_path fixture) | WebSearch |
| code-review | **да** — после W1 завершения 6 spec'ов прогнать `/code-review` на изменения в `e2e/` | — |
| superpowers TDD | нет (E2E spec'ы пишутся вокруг готового UI/API — Red-Green-Refactor не применим напрямую) | — |
| frontend-design | нет (UI не создаёшь) | — |

**Правило:** после КАЖДОГО Edit/Write на `.spec.ts` или `.ts` файл → typescript-lsp diagnostic + запуск spec через playwright. После КАЖДОГО Edit/Write на `.py` → pyright-lsp diagnostic. Hook `plugin-check.sh` напомнит, но обязан следовать и без hook.

# Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — пройти строки с пометкой `frontend`/`e2e`/`playwright`. Особое внимание:
   - Любые gotcha по WebSocket моку через `page.route` (если уже зафиксированы)
   - Любые gotcha по timing/race в Playwright (`page.waitForEvent`, `waitForResponse`)

3. **`Спринты/Sprint_8/arch_design_s8.md`** — обязательные секции:
   - **§5 (6 missing E2E spec'ов)** — детальные сценарии, моки, edge cases. Это твой главный источник.
   - **§11 «TODO summary»** — решения заказчика по batch 1 (удаление Blockly mode B + AIChat mock дополнение) и batch 3 (backup → pytest integration, events → mock WS без _test endpoint).
   - **§8 (Wave breakdown)** — где QA работает (W1 поток E + W2 + W3 регрессия).

4. **`Спринты/Sprint_8/execution_order.md`** — раздел W1 поток E + раздел «Cross-DEV contracts».

5. **`Спринты/Sprint_8/e2e_test_plan_s8.md`** — план, который оркестратор создаёт после W0 (твой согласованный план; spec'ы реализуешь по нему).

6. **`Спринты/Sprint_7/e2e_test_plan_s7.md`** — образец формата плана + стиля сценариев.

7. **`Develop/frontend/e2e/s6-notifications.spec.ts`** + **`Develop/frontend/e2e/s7-front2.spec.ts`** — образцы моков и `data-testid` локаторов из текущего кода.

8. **Цитаты из ТЗ/ФТ и CLAUDE.md проекта** (берутся как есть):

   > **CLAUDE.md проект (E2E тесты — обязательный процесс, дословно):**
   > «Создай E2E тесты = полный цикл, а не просто файлы:
   > 1. Описание — ПЕРЕД написанием тестов создать `e2e_test_plan_sN.md`: сценарии, предусловия, шаги, ожидаемый результат. Основа — `ui_checklist` + новый функционал спринта.
   > 2. Инфраструктура — в `preflight_checklist.md`: проверить Playwright (`npx playwright --version`, `playwright.config.ts`). В `execution_order.md`: шаг «поднять backend + frontend».
   > 3. Написание — тесты по спецификации из п.1.
   > 4. Запуск — `npx playwright test`. Тесты ОБЯЗАНЫ быть реально выполнены, не просто написаны.
   > 5. Верификация — результат прикладывается в `arch_review_sN.md`. Критерий: passed/failed, а не «файлы созданы».»

   > **MEMORY user_test_credentials (дословно):**
   > «E2E: пользователь sergopipo — в тестах логин sergopipo, пароль спрашивать у заказчика»

   > **ARCH design §11 batch 3 пункт 8 (дословно):**
   > «§5.2 `s7-backup.spec.ts` → ✅ pytest integration test. Создать `tests/integration/test_backup_cli.py` с `subprocess.run()` вместо Playwright spec. Backup — backend CLI, не UI. Удалить упоминание `s7-backup.spec.ts` из QA плана.»

   > **ARCH design §11 batch 3 пункт 9 (дословно):**
   > «§5.3 `s7-events.spec.ts` → ✅ Mock WS frame из Playwright. Использовать `page.route` для WS endpoint и подсовывать frames из fixture. Без backend изменений. Уже знакомый паттерн в `api_mocks.ts`. Не вводить `_test/emit-event` endpoint.»

   > **ARCH design §11 batch 1 пункт 1 (дословно):**
   > «#30 `S5R-BLOCKLY-MODE-B` → ✅ удалить 2 spec'а (`mode B modal opens`, `check button is disabled`). Фича удалена из UI в S5/S6, spec'ы зомби.»

   > **ARCH design §11 batch 1 пункт 2 (дословно):**
   > «#29 `S6R-AICHAT-APPLY-MOCK` → ✅ дополнить мок в W2 (~2ч). QA добавляет реалистичный `block_xml` в мок AI-ответа, снимает skip.»

# Рабочая директория

`Develop/frontend/` (Playwright spec'ы + fixtures) и `Develop/backend/` (pytest integration).

# Контекст существующего кода

- **`Develop/frontend/e2e/fixtures/api_mocks.ts`** — фабрика моков. Уже содержит helpers типа `mockSessions`, `mockBacktestResults`, `mockAiChat`. Расширяешь: `mockWSChannel(channel, frames)`, `mockBacktestWithTrades(trades)`, реалистичный `block_xml` для AIChat. **НЕ переписывать существующее**, только добавлять.
- **`Develop/frontend/e2e/`** — flat-каталог spec'ов (НЕ `e2e/specs/`!). Файлы s4/s5/s6/s7-*.spec.ts. Новые 5 spec'ов создавай прямо тут с префиксом `s7-` (закрываешь S7-долг).
- **`Develop/frontend/playwright.config.ts`** — `CI=true` отключает webServer, использует моки.
- **`Develop/backend/app/cli/backup.py`** — backup CLI (S7). Команды: `python -m app.cli.backup create` и `python -m app.cli.backup restore <path>`.
- **`Develop/backend/tests/integration/`** — каталог pytest integration. conftest.py с фикстурами `db_session`, `tmp_path`.
- **`Develop/.github/workflows/playwright-nightly.yml`** — nightly workflow. После стабилизации новых spec'ов добавишь их сюда.
- **Spec для удаления:** в существующих файлах найди `test.skip(..., 'S5R-BLOCKLY-MODE-B-MODAL')` и `'S5R-BLOCKLY-MODE-B-CHECK')` через `grep -rn "S5R-BLOCKLY-MODE-B" e2e/`. Удалить **тесты целиком** (фича вырезана из UI).

# Задачи

## W0 — Согласование плана (≈4ч, параллельно с ARCH)

**Цель:** убедиться, что `e2e_test_plan_s8.md` (создаёт оркестратор/ARCH после §5 arch_design_s8.md) содержит все 6 сценариев в твоём формате и понятен.

- Прочитай `e2e_test_plan_s8.md`, сверь с `arch_design_s8.md` §5.
- Если найдёшь несоответствие сценариев или отсутствие edge case'ов — **подними БЛОКЕР до начала W1**, оркестратор корректирует план.
- В отчёте W0 укажи: «План прочитан, 6 сценариев согласованы / есть N расхождений: ...».

> **Правило проекта (CLAUDE.md):** ПЕРЕД написанием spec'ов должен существовать `e2e_test_plan_sN.md`. Если его нет — БЛОКЕР, не начинай W1.

## W1 — 6 missing E2E spec'ов (≈20ч)

### Задача 1: `e2e/s7-export.spec.ts` (S7R-E2E-7.3, ~3ч)

**Тип:** Playwright spec.

**Сценарии (из arch_design §5.1):**

```typescript
test.describe('S7R-E2E-7.3 — Export CSV/PDF', () => {
  test('download CSV: content-type + содержит "Тикер,"', async ({ page }) => {
    await mockBacktestResults(page, { id: 1, ticker: 'SBER', metrics: {...} });
    await page.goto('/backtest/1/results');
    const downloadPromise = page.waitForEvent('download');
    await page.getByTestId('export-csv-btn').click();
    const download = await downloadPromise;
    // assert content-type содержит "text/csv" (через response headers)
    // assert содержимое начинается с "Тикер," (saveAs + readFileSync)
  });

  test('download PDF: %PDF- magic + size ≥ 5 KB', async ({ page }) => {
    // аналогично, assert первые 4 байта === "%PDF" и stat.size >= 5*1024
  });

  test('click на disabled-кнопку (status=running) → нет download', async ({ page }) => {
    await mockBacktestResults(page, { id: 2, status: 'running' });
    await page.goto('/backtest/2/results');
    await expect(page.getByTestId('export-csv-btn')).toBeDisabled();
    // нет ожидания download — таймаут невозможен (кнопка disabled)
  });
});
```

**Моки:** `mockBacktestResults(page, {...})` в `api_mocks.ts` (расширить, если нет id/status параметра).

**Ключевое API:** `page.waitForEvent('download')`, `download.saveAs(tmpPath)`, `fs.readFileSync(tmpPath)`. Через context7 запроси документацию Playwright по download events.

### Задача 2: `tests/integration/test_backup_cli.py` (S7R-E2E-7.9, ~3ч)

**Тип:** pytest integration (НЕ Playwright!). Решение arch_design §11 batch 3 пункт 8: backup — backend CLI, не UI.

**Сценарии:**

```python
import subprocess
import sys
from pathlib import Path

import pytest


@pytest.mark.integration
def test_backup_create_produces_file(tmp_path, monkeypatch):
    """`python -m app.cli.backup create` создаёт файл в data/backups/."""
    backups_dir = tmp_path / "backups"
    backups_dir.mkdir()
    monkeypatch.setenv("BACKUP_DIR", str(backups_dir))
    result = subprocess.run(
        [sys.executable, "-m", "app.cli.backup", "create"],
        capture_output=True, text=True, check=True,
    )
    files = list(backups_dir.glob("backup_*.sqlite"))
    assert len(files) == 1
    assert files[0].stat().st_size > 0


@pytest.mark.integration
def test_backup_restore_recovers_data(tmp_path, db_session, monkeypatch):
    """Smoke: create record → backup → delete record → restore → record вернулся."""
    # 1. Создать запись в БД (например, User или TradingSession)
    # 2. subprocess.run create
    # 3. Удалить запись
    # 4. subprocess.run restore <path>
    # 5. assert запись на месте через db_session.query(...)
```

**Использовать фикстуры:** `tmp_path`, `monkeypatch`, `db_session` (из `tests/conftest.py`). Через context7 запроси `pytest tmp_path`, `subprocess.run` best practices.

**Important:** конструктор БД должен поддерживать env-override `BACKUP_DIR` — если не поддерживает, согласовать с DEV-1 (поставщик backup CLI) до начала задачи.

### Задача 3: `e2e/s7-events.spec.ts` (S7R-E2E-7.13, ~6ч)

**Тип:** Playwright + mock WS frame через `page.route` (решение arch_design §11 batch 3 пункт 9, БЕЗ `_test` endpoint).

**Сценарии — 5 event_type:**

```typescript
test.describe('S7R-E2E-7.13 — Notification bell для 5 event_type', () => {
  const cases = [
    { event: 'trade.opened',         label: 'Позиция открыта',          severity: 'info' },
    { event: 'order.partial_fill',   label: 'Частичное исполнение',     severity: 'info' },
    { event: 'order.error',          label: 'Ошибка выставления',       severity: 'warning' },
    { event: 'positions.closed_all', label: 'Все позиции закрыты',      severity: 'info' },
    { event: 'connection.lost',      label: 'Соединение потеряно',      severity: 'warning' },
    { event: 'connection.restored',  label: 'Соединение восстановлено', severity: 'info' },
  ];
  for (const c of cases) {
    test(`event ${c.event} → bell "${c.label}"`, async ({ page }) => {
      await mockWSChannel(page, 'notifications', [{ event: c.event, payload: {...} }]);
      await page.goto('/dashboard');
      await expect(page.getByTestId('notification-bell')).toContainText(c.label);
      // severity badge:
      await expect(page.getByTestId(`severity-${c.severity}`)).toBeVisible();
    });
  }
});
```

**Mock helper** (новый в `api_mocks.ts`):

```typescript
export async function mockWSChannel(
  page: Page, channel: string, frames: WsFrame[]
): Promise<void> {
  await page.route(`**/ws/${channel}**`, async route => {
    // подсовываем frames через WebSocket handshake mock
    // (детали через context7 → Playwright WS routing)
  });
}
```

**Через context7:** запроси Playwright docs по `page.route` для WebSocket (есть ли native support / используется `route.fulfill` для upgrade-response).

### Задача 4: `e2e/s7-tg-callbacks.spec.ts` (S7R-E2E-7.14, ~3ч)

**Тип:** Playwright spec.

**Сценарии:**

```typescript
test('deep-link /sessions/42?from=tg → рендер сессии', async ({ page }) => {
  await mockSessions(page, [{ id: 42, ticker: 'GAZP', status: 'running' }]);
  await page.goto('/sessions/42?from=tg');
  await expect(page.getByTestId('session-detail-42')).toBeVisible();
  await expect(page.getByTestId('session-ticker')).toHaveText('GAZP');
});

test('deep-link /chart?ticker=SBER&tf=5m&from=tg → рендер графика', async ({ page }) => {
  await mockMoexCandles(page, { ticker: 'SBER', tf: '5m' });
  await page.goto('/chart?ticker=SBER&tf=5m&from=tg');
  await expect(page.getByTestId('chart-container')).toBeVisible();
  await expect(page.getByTestId('chart-ticker-label')).toHaveText('SBER');
});
```

**Tricky:** Telegram callback приходит через webhook, не от UI. Spec симулирует `goto` + render check (как если бы пользователь кликнул на ссылку из ТГ-сообщения).

### Задача 5: `e2e/s7-backtest-analytics.spec.ts` (S7R-E2E-7.16, ~4ч)

**Тип:** Playwright spec.

**Сценарии:**

```typescript
test('hover зоны → tooltip с trade detail', async ({ page }) => {
  await mockBacktestWithTrades(page, [{ entry: ..., exit: ..., pnl: 1500 }]);
  await page.goto('/backtest/1/analytics');
  await page.getByTestId('equity-curve-zone-0').hover();
  await expect(page.getByTestId('trade-tooltip')).toBeVisible();
  await expect(page.getByTestId('trade-tooltip-pnl')).toContainText('1500');
});

test('click зоны → панель trade-detail-panel', async ({ page }) => {
  // аналогично, click + assert панель
});

test('гистограмма pnl-histogram рендерится (≥ 1 bar)', async ({ page }) => {
  const bars = page.getByTestId('pnl-histogram').locator('[data-testid^="hist-bar-"]');
  await expect(bars.first()).toBeVisible();
});

test('donut win-loss-donut (2 сегмента)', async ({ page }) => {
  const segments = page.getByTestId('win-loss-donut').locator('[data-testid^="donut-seg-"]');
  await expect(segments).toHaveCount(2);
});
```

**Моки:** `mockBacktestWithTrades(page, trades)` (новый helper в `api_mocks.ts`).

### Задача 6: `e2e/s7-bg-backtest.spec.ts` (S7R-E2E-7.17, ~3ч)

**Тип:** Playwright spec.

**Сценарии:**

```typescript
test('POST /backtest/run в фоне → toast "Запущен в фоне"', async ({ page }) => {
  await mockBacktestRun(page, { mode: 'background' });
  await page.goto('/backtest/new');
  await page.getByTestId('run-in-background-btn').click();
  await expect(page.getByText('Запущен в фоне')).toBeVisible();
});

test('Badge bg-backtest-badge → счётчик 1 → 0 после completed', async ({ page }) => {
  await mockWSChannel(page, 'backtest:1', [{ event: 'completed', payload: {...} }]);
  // 1. Стартануть бэктест → badge показывает "1"
  await expect(page.getByTestId('bg-backtest-badge')).toContainText('1');
  // 2. Дождаться completed frame → badge декремент (исчезает или "0")
  await expect(page.getByTestId('bg-backtest-badge')).not.toBeVisible({ timeout: 5000 });
});

test('Cap=3 параллельных → 4-й → toast "Превышен лимит"', async ({ page }) => {
  // запустить 3 в фоне, 4-й → toast
  await expect(page.getByText('Превышен лимит параллельных бэктестов')).toBeVisible();
});
```

**Моки:** `mockWSChannel('backtest:N', frames)` (используется тот же helper, что в задаче 3).

## W2 — AIChat mock дополнение (≈2ч)

Решение arch_design §11 batch 1 пункт 2.

- В `e2e/fixtures/api_mocks.ts` найди существующий `mockAiChat`. Расширь ответ ассистента реалистичным `block_xml` (валидный Blockly XML с ≥ 3 блоками: condition + indicator + action).
- Найди spec с `test.skip(reason='S6R-AICHAT-APPLY-MOCK')` (через `grep -rn "S6R-AICHAT-APPLY-MOCK" e2e/`).
- Сними `.skip` → переведи в активный тест.
- Запусти spec: `cd Develop/frontend && CI=true npx playwright test e2e/<file>.spec.ts`.
- Если spec падает — диагностируй, фикси (мок может не покрывать новые ассерты).

## W3 — Регрессия + удаление мёртвых spec'ов (≈6ч)

### Шаг 1: Удалить 2 spec'а Blockly mode B (5 мин)

Решение arch_design §11 batch 1 пункт 1.

- `grep -rn "S5R-BLOCKLY-MODE-B-MODAL\|S5R-BLOCKLY-MODE-B-CHECK" Develop/frontend/e2e/` — найди тесты.
- Удалить **тесты целиком** (не оставлять `.skip`).
- Если после удаления файл пустой — удалить файл целиком.

### Шаг 2: Финальный регрессионный прогон (≈4ч)

```bash
# 1. Frontend Playwright
cd Develop/frontend && CI=true npx playwright test --reporter=line
# Ожидание: 142 (S7 baseline) + 6 (новые) - 2 (Blockly удалены) = 146 spec'ов
# Все passed.

# 2. Backend pytest unit
cd Develop/backend && .venv/bin/python -m pytest tests/unit/ -q
# Ожидание: 750 / 0 failed (S8 baseline, может вырасти из-за coverage P0+P1+P2)

# 3. Backend pytest integration (в том числе новый test_backup_cli.py)
cd Develop/backend && .venv/bin/python -m pytest tests/integration/ -q
# Ожидание: все passed, новые backup тесты — passed.
```

Если в любом блоке есть `failed` — диагностируй, фикси или подними БЛОКЕР с конкретным `pytest --tb=short` / Playwright trace.

### Шаг 3: E2E coverage отчёт → `arch_review_s8.md`

В `Спринты/Sprint_8/reports/QA_W3_regression.md` (создаёт оркестратор после твоего отчёта) сохраняй:
- Точное число spec'ов прогнано (passed/failed/skip).
- Список новых spec'ов с тегами `S7R-E2E-7.X-MISSING` → CLOSED.
- Время регрессии (sec/min).
- Скриншоты failure (если есть) в `e2e/screenshots/s8/`.

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Если по обоснованной причине вводишь `test.skip(..., 'S8R-<TICKET>')` (например, фича не доделана DEV'ом к W3) — обязательно:

1. Полный список skip-тикетов в отчёте с обоснованием.
2. Карточка в `Sprint_8_Review/backlog.md` с тикетом `S8R-<NAME>`.

Skip без карточки — **блокер** приёмки.

Особый случай: `S6R-AICHAT-APPLY-MOCK` skip — **обязан** быть снят в W2 (это твоя задача). Если не снят — отдельно объясни почему.

# Тесты

Структура которую создаёт QA:

```
Develop/frontend/e2e/
├── s7-export.spec.ts                # NEW (S7R-E2E-7.3)
├── s7-events.spec.ts                # NEW (S7R-E2E-7.13)
├── s7-tg-callbacks.spec.ts          # NEW (S7R-E2E-7.14)
├── s7-backtest-analytics.spec.ts    # NEW (S7R-E2E-7.16)
└── s7-bg-backtest.spec.ts           # NEW (S7R-E2E-7.17)

Develop/frontend/e2e/fixtures/
└── api_mocks.ts                     # EXTEND: mockWSChannel + mockBacktestWithTrades + AIChat block_xml

Develop/backend/tests/integration/
└── test_backup_cli.py               # NEW (S7R-E2E-7.9)
```

**Spec ≤ 200 строк каждый, без real-backend (CI=true mock-based).**
**Использовать `data-testid` локаторы (не CSS-классы — это нестабильно).**
**E2E пользователь: `sergopipo` (memory user_test_credentials). Пароль — спросить у заказчика перед запуском real-backend smoke в W3.**

**Фикстуры backend:** `db_session`, `tmp_path`, `monkeypatch`, `test_user` (из `tests/conftest.py`).

# Integration Verification Checklist

Для **каждого** нового spec'а / mock helper'а:

- [ ] **Задача 1 (export):** spec фактически выполнен — `CI=true npx playwright test e2e/s7-export.spec.ts` → 3 passed. Лог приложить в отчёт.
- [ ] **Задача 1:** в spec используется `data-testid="export-csv-btn"`, `data-testid="export-pdf-btn"` — `grep -rn "export-csv-btn\|export-pdf-btn" Develop/frontend/src/` показывает реальные точки в UI (если нет — БЛОКЕР, согласовать с DEV-3/FRONT2).
- [ ] **Задача 2 (backup):** `.venv/bin/python -m pytest tests/integration/test_backup_cli.py -v` → 2 passed.
- [ ] **Задача 2:** CLI вызовы `subprocess.run([sys.executable, '-m', 'app.cli.backup', ...])` работают (smoke руками: `python -m app.cli.backup create` создаёт файл).
- [ ] **Задача 3 (events):** 6 событий × 1 spec = 6 sub-tests passed (`test.each` или `for...test`).
- [ ] **Задача 3:** `mockWSChannel` экспортирован из `api_mocks.ts` (`grep -rn "export.*mockWSChannel" e2e/fixtures/`).
- [ ] **Задача 4 (tg-callbacks):** 2 spec'а passed; deep-link рендерит правильный компонент.
- [ ] **Задача 5 (analytics):** 4 spec'а passed; `data-testid="trade-detail-panel"`, `pnl-histogram`, `win-loss-donut`, `equity-curve-zone-*` есть в UI (`grep` в `Develop/frontend/src/`).
- [ ] **Задача 6 (bg-backtest):** 3 spec'а passed; `data-testid="bg-backtest-badge"`, `run-in-background-btn` есть в UI.
- [ ] **AIChat mock (W2):** `test.skip('S6R-AICHAT-APPLY-MOCK')` снят, spec passed.
- [ ] **Удаление Blockly mode B:** `grep -rn "S5R-BLOCKLY-MODE-B" Develop/frontend/e2e/` → пусто.
- [ ] **Regression W3:** общий прогон `CI=true npx playwright test` → 146 passed / 0 failed (или больше, если DEV-ы добавили свои spec'ы); pytest backend → 0 failed.
- [ ] **Cross-DEV контракты (потребитель):**
  - DEV-1 `is_admin` + `/admin/` — если ARCH потребует admin spec, согласовать (по умолчанию admin spec не в scope QA в S8 — он в W1 на BACK1).
  - DEV-2 5 dashboard endpoints + event sync publishers — используются для regression (existing s7-front2.spec.ts + новый s7-events.spec.ts).
  - DEV-4 Plotly Dash `/admin/metrics` — smoke goto `/admin/metrics` в regression W3 (1 строка assertion).
  - DEV-4 4 widget'а на DashboardPage — regression s7-front2.spec.ts или extension.
- [ ] **Если spec падает на CI**, но локально passed — приложить trace через `npx playwright show-trace` + диагноз в отчёте (race condition? mock не покрывает?).
- [ ] **Если real backend нужен для W3 smoke** — БЛОКЕР: согласовать пароль `sergopipo` user'а с заказчиком до запуска.

> **Если новый spec не падает ни на одном пути после удаления стороннего mock'а** — это flaky-тест, **NOT ACCEPTED** (assertion-free).

# Формат отчёта (МАНДАТНЫЙ)

**3 файла отчётов**, каждый ≤ 400 слов, 8 секций:

1. **`Sprint_8/reports/QA_W0_plan_sync.md`** — после W0 (план согласован).
2. **`Sprint_8/reports/QA_W1_6_specs.md`** — после 6 spec'ов W1.
3. **`Sprint_8/reports/QA_W2W3_regression.md`** — после AIChat mock (W2) + регрессии (W3).

Шаблон (8 секций):

```markdown
## QA отчёт — Sprint 8, <стадия (W0/W1/W2-W3)>

### 1. Что реализовано
- 5-10 пунктов крупными мазками

### 2. Файлы
- **Новые:** <пути>
- **Изменённые:** <пути>
- **Удалённые:** <пути>

### 3. Тесты (РЕАЛЬНО ПРОГНАНЫ)
- Playwright: `npx playwright test e2e/<file>` → X/Y passed (точные числа, лог в `reports/`)
- pytest integration: X/Y passed
- Regression W3: X/Y passed
- Если есть `failed` — краткий диагноз: «<что упало, почему>»

### 4. Integration points
- `mockWSChannel` экспортирован из `e2e/fixtures/api_mocks.ts:NNN` (✅)
- `data-testid="export-csv-btn"` найден в `Develop/frontend/src/<file>.tsx:NNN` (✅)
- Если точка вызова не найдена в UI — ⚠️ NOT CONNECTED + блокер

### 5. Контракты для других DEV
- **Использую:** is_admin от BACK1 / dashboard endpoints от BACK2 / `/admin/metrics` от BACK1 — подтверждаю
- **Поставляю:** нет (spec'ы — не контракт между DEV'ами)

### 6. Проблемы / TODO
- известные flaky, отложенные сценарии, skip-тикеты

### 7. Применённые Stack Gotchas
- `Gotcha NN` (`gotcha-NN-<slug>.md`): одно предложение, как обошёл

### 8. Новые Stack Gotchas (если обнаружены)
- симптом / причина / правило / related_files в формате arch_design_s8.md §8.6

### 9. Использование плагинов
- playwright: использован для X/Y spec'ов / fallback скриншот
- typescript-lsp: использован / fallback `tsc --noEmit`
- pyright-lsp: использован / fallback `py_compile`
- context7: запрошено для: Playwright page.route WS / page.waitForEvent download / subprocess.run / pytest tmp_path
- code-review: выполнен после W1
```

**Правило S5R.5:** отчёт сохраняется как файл в `Спринты/Sprint_8/reports/QA_<stage>.md`. Это обязательный артефакт репо, ARCH-ревьюер валидирует через grep/git.

# Alembic-миграция

Не требуется (QA не вводит таблиц).

# Чеклист перед сдачей

- [ ] W0: `e2e_test_plan_s8.md` прочитан, расхождения с arch_design §5 подняты или подтверждены
- [ ] W1: 6 spec'ов реализованы (5 Playwright + 1 pytest integration)
- [ ] W1: каждый spec **реально запущен** через `npx playwright test` или `pytest`, лог сохранён в отчёте
- [ ] W2: AIChat mock дополнен реалистичным `block_xml`, `test.skip('S6R-AICHAT-APPLY-MOCK')` снят
- [ ] W3: 2 spec'а Blockly mode B удалены (`grep` показывает пусто)
- [ ] W3: финальная регрессия прогнана — Playwright 146+ passed / 0 failed, pytest backend 0 failed
- [ ] Все spec'ы используют `data-testid` локаторы (не CSS-классы)
- [ ] Spec'ы ≤ 200 строк каждый, CI=true mock-based
- [ ] TypeScript сборка чистая: `cd Develop/frontend && npx tsc --noEmit` → 0 errors
- [ ] Python типы чистые: `cd Develop/backend && pyright tests/integration/test_backup_cli.py` → 0 errors
- [ ] Integration verification checklist полностью пройден
- [ ] Формат отчёта соблюдён — 9 секций (с плагинами) × 3 файла отчёта
- [ ] Отчёты сохранены как файлы в `Sprint_8/reports/QA_W0_plan_sync.md`, `QA_W1_6_specs.md`, `QA_W2W3_regression.md`
- [ ] Cross-DEV contracts (потребитель): is_admin / dashboard / `/admin/metrics` / widgets подтверждены
- [ ] Stack Gotchas применены (минимум 2 ловушки из INDEX.md в отчёте секция 7)
- [ ] Плагины использованы (playwright, typescript-lsp, pyright-lsp, context7, code-review)
- [ ] Skip-тикеты — все имеют карточку в `Sprint_8_Review/backlog.md`
- [ ] `Sprint_8/changelog.md` обновлён немедленно после каждой стадии (W0/W1/W2/W3)
- [ ] `Sprint_8/sprint_state.md` отражает прогресс QA-потока
- [ ] (опц.) Новые spec'ы добавлены в `Develop/.github/workflows/playwright-nightly.yml` после стабилизации — PASS или SKIP с reason
