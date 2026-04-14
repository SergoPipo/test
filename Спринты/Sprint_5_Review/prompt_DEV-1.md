---
sprint: 5_Review
agent: DEV-1
role: "Infrastructure / Test baseline — CI cleanup (S5R.1) + E2E S4 fix (S5R.4)"
wave: 1-2
depends_on: []
---

# Роль

Ты — Full-stack инженер S5R, отвечающий за **инфраструктуру тестирования и lint baseline**. Твои задачи не меняют бизнес-логику — но без них остальные DEV-агенты S5R не смогут пройти Integration Verification Checklist. Ты работаешь в двух волнах:

- **Волна 1 — S5R.1 CI cleanup:** починить `ruff`, `pnpm lint`, проверить, что `mypy`, `pytest`, `tsc`, `vitest` вообще запускаются и зелёные. Результат — зелёный CI на `moex-terminal` develop.
- **Волна 2 — S5R.4 E2E S4 fix:** после CI cleanup починить 30+ падающих Playwright-тестов AI Chat / Backtest / Blockly, убрать хаос в `e2e/` (не-spec файлы), опционально добавить Playwright в CI.

Ты — **поставщик** контрактов C1, C2, C3, C10 из [execution_order.md](execution_order.md). Без твоего зелёного baseline DEV-2 и DEV-3 не стартуют.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Если хотя бы один пункт не выполнен — **НЕ начинай** реализацию, верни `БЛОКЕР: <описание>`.

```
1. Окружение:
   - python3 --version → >= 3.11
   - node --version → >= 18
   - pnpm --version → >= 9
   - cd Develop/frontend && npx playwright --version → любая установленная

2. Репозиторий Develop (moex-terminal):
   - git branch --show-current → develop
   - git status --porcelain → пусто
   - git fetch && git log HEAD..origin/develop → пусто (синхронизация с remote)

3. Существующие файлы:
   - Develop/backend/pyproject.toml — есть, секция [tool.ruff] присутствует
   - Develop/backend/alembic/env.py — есть, содержит импорты моделей для side-effect
   - Develop/frontend/eslint.config.js — есть
   - Develop/frontend/e2e/s4-review-*.spec.ts — 4 файла тестов S4
   - Develop/.github/workflows/ci.yml — есть, содержит backend + frontend jobs
   - Develop/CLAUDE.md — есть, содержит раздел «⚠️ Stack Gotchas»

4. Baseline тестов (ожидаемо красный — это причина задачи):
   - cd Develop/backend && ruff check . → ожидается ~14× F401 в alembic/env.py
   - cd Develop/frontend && pnpm lint → ожидается 40+ ошибок React 19 + unused-vars + any
   - cd Develop/frontend && npx playwright test → ожидается 30+ s4-review падений

5. GitHub CLI:
   - gh --version → любая (для проверки статуса CI после push)
   - gh auth status → authenticated (для просмотра run list)
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **[Develop/CLAUDE.md](../../Develop/CLAUDE.md)** — **полностью**, особое внимание секции **«⚠️ Stack Gotchas»** (Gotchas 1-5). Каждая ловушка уже приводила к реальному багу в S5. Стек-специфика работы с Pydantic v2 / CodeSandbox / Backtrader / T-Invest gRPC / Circuit Breaker locks применима и к тебе — например, при фиксах `no-explicit-any` в файлах, где есть Decimal, надо помнить про Gotcha 1.

2. **[Sprint_5_Review/PENDING_S5R_ci_cleanup.md](PENDING_S5R_ci_cleanup.md)** — **полный план** S5R.1: хронология падений, корневые причины по категориям (ruff F401, React 19 hooks, unused-vars, no-explicit-any, react-refresh), конкретные файлы и строки, решения.

3. **[Sprint_5_Review/PENDING_S5R_e2e_s4_fix.md](PENDING_S5R_e2e_s4_fix.md)** — **полный план** S5R.4: причины падений, фазы работы, правило «не коммит на каждый тест, а один логический фикс на группу».

4. **[Sprint_5_Review/execution_order.md](execution_order.md)** раздел **«Cross-DEV Contracts»** — твои контракты:
   - **Поставщик C1** — «Зелёный `ruff check .` в backend/». Реализация: `[tool.ruff.lint.per-file-ignores]` содержит `"alembic/env.py" = ["F401"]`.
   - **Поставщик C2** — «Зелёный `pnpm lint` в frontend/». Реализация: `eslint.config.js` либо переводит `react-hooks/*` в `warn`, либо конкретные 6 мест исправлены (предпочтительно исправлены).
   - **Поставщик C3** — «Зелёный `pnpm tsc --noEmit`, `pytest tests/unit/`, `vitest`, `playwright`». Каждый job в CI доходит до выполнения и возвращает exit 0.
   - **Поставщик C10** — «Работающий baseline Playwright». `npx playwright test` запускается, существующие s4-* тесты зелёные или явно `test.skip()` с аннотацией.

5. **Цитаты из корневого `CLAUDE.md`** (проектные правила):

   > **Правила работы с DEV-субагентами в спринтах (дословно):**
   > «Integration verification — каждый DEV обязан в отчёте подтвердить, что новые классы/методы вызываются в production-коде (`grep -rn "<ClassName>(" app/`), не только в тестах. Если точка вызова не найдена — явно пометить `⚠️ NOT CONNECTED` в отчёте.»

   Для CI cleanup это правило трансформируется: вместо «класс вызывается в runtime» — «изменение правила линтера действительно применяется в CI» (проверка через фактический push в тестовую ветку и зелёный run).

6. **Хронология падений CI из [PENDING_S5R_ci_cleanup.md:10-22](PENDING_S5R_ci_cleanup.md):** CI красный **с 2026-04-03** (коммит `a73d902` Sprint 4 milestone), все 9 запусков за 11 дней → `All jobs have failed`. Уведомления копились в почте. Моё собственное PR #1 (только документация) тоже упало — это значит, проблема в main, а не в конкретном коммите.

# Рабочая директория

- `Test/Develop/backend/` (часть 1 — ruff, mypy, pytest)
- `Test/Develop/frontend/` (часть 2 — eslint, tsc, vitest, playwright)
- `Test/Develop/.github/workflows/` (CI workflow)

# Контекст существующего кода

- `Develop/backend/pyproject.toml` — есть секция `[tool.ruff]` с `target-version = "py311"` и `line-length = 100`. **НЕТ** секции `[tool.ruff.lint.per-file-ignores]` — её нужно добавить.
- `Develop/backend/alembic/env.py` — импорты моделей (`User`, `RevokedToken`, `Strategy`, ..., ~14 символов) для side-effect регистрации в `Base.metadata`. Эти импорты **необходимы** для `alembic revision --autogenerate`, но ruff видит их как `F401 imported but unused`. **НЕ удалять импорты** — добавить исключение в `per-file-ignores`.
- `Develop/frontend/eslint.config.js` — конфигурация ESLint 9 flat config + `eslint-plugin-react-hooks@7.x` (React 19 strict rules). Содержит `react-hooks/refs`, `react-hooks/set-state-in-effect`, `react-hooks/incompatible-library` на уровне `error`.
- `Develop/frontend/src/components/backtest/InstrumentChart.tsx:39-41` — три строки `candlesRef.current = candles; markersRef.current = markers; tradesRef.current = trades;` в теле компонента — нарушают `react-hooks/refs`. **Решение:** перенести в `useEffect`.
- `Develop/frontend/src/components/common/TickerLogo.tsx:58` — `setImgError(false)` в теле `useEffect` при изменении `ticker` — нарушает `react-hooks/set-state-in-effect`. **Решение:** `useEffect(() => { setImgError(false); }, [ticker])` либо использовать `useState(() => ...)` с `key={ticker}` в родителе.
- `Develop/frontend/src/components/backtest/BacktestLaunchModal.tsx:109` — `setTickerSuggestions(getRecentInstruments())` в `useEffect` при `opened` — то же правило. **Решение:** та же схема.
- `Develop/frontend/src/components/account/PositionsTable.tsx:74` и `Develop/frontend/src/components/backtest/BacktestTrades.tsx:195` — `useReactTable({...})` из TanStack Table несовместим с React Compiler. **Решение:** `// eslint-disable-next-line react-hooks/incompatible-library` (known issue TanStack Table, pragmatic).
- `Develop/frontend/src/components/layout/Sidebar.tsx:56` — файл экспортирует и компонент, и константы (массив навигации) → `react-refresh/only-export-components`. **Решение:** вынести константы в новый `Develop/frontend/src/components/layout/sidebarItems.ts`.
- `Develop/frontend/e2e/s4-review-*.spec.ts` — 4 файла, ~30+ тестов, **падают** с момента Sprint 4 milestone.
- `Develop/frontend/e2e/test-backtest-fixes.ts`, `test-backtest-flow.ts`, `test-lkoh-full.ts` — **не-spec** файлы (не `.spec.ts`), вероятно черновики или утилиты, ESLint ругается на них как на тесты.
- `Develop/.github/workflows/ci.yml` — workflow с двумя jobs: backend (`ruff → mypy → pytest`) и frontend (`pnpm lint → pnpm tsc --noEmit → pnpm test`). Из-за `bash -e` после первого упавшего шага остальные **не запускаются**. **НЕ модифицировать структуру** без необходимости — только опционально добавить e2e job в S5R.4.
- `Develop/frontend/playwright.config.ts` — конфигурация с webServer (backend + frontend). Используется для E2E.

# Задачи

## Часть 1: S5R.1 — CI cleanup (Волна 1)

### Задача 1.1: Backend ruff — per-file-ignores для alembic/env.py

В `Develop/backend/pyproject.toml` добавить секцию:

```toml
[tool.ruff.lint.per-file-ignores]
"alembic/env.py" = ["F401"]
```

**Почему F401 — ложное срабатывание:** импорты моделей в `alembic/env.py` нужны для side-effect регистрации в `Base.metadata` (для `alembic revision --autogenerate`). Символы действительно «не используются как переменные», но импорт обязателен.

**НЕ удалять импорты** — это сломает автогенерацию миграций.

**Проверка:**
```bash
cd Develop/backend && ruff check .
# Ожидание: All checks passed!
```

### Задача 1.2: Backend mypy + pytest — проверить, что работают

После задачи 1.1 запустить **последовательно**:

```bash
cd Develop/backend
mypy app/ --ignore-missing-imports
# Ожидание: либо 0 errors, либо задокументированные warn-only.
# Если errors — это новые проблемы, которые скрывал ruff. Чинить в этой же задаче.

pytest tests/unit/
# Ожидание: 0 failures. В S5 утверждается «548 tests passed» локально — проверить.
# Если failed — чинить в этой же задаче.
```

**Если в mypy/pytest обнаружатся новые проблемы** — зафиксируй в отчёте DEV (секция 6 «Проблемы / TODO»), но **не блокируй** задачу: общая цель — «все 6 команд на CI зелёные». Если какая-то ошибка явно относится к незакрытому техдолгу S5R.2 (Live Runtime Loop) или S5R.3 — пометь как «ожидает DEV-2/DEV-3».

### Задача 1.3: Frontend — 6 конкретных React 19 проблем

#### 1.3.1 — `InstrumentChart.tsx:39-41`

**Текущий код (неправильный):**
```tsx
const candlesRef = useRef(candles);
const markersRef = useRef(markers);
const tradesRef = useRef(trades);
candlesRef.current = candles;     // ❌ react-hooks/refs
markersRef.current = markers;     // ❌
tradesRef.current = trades;       // ❌
```

**Исправление:** вынести присваивание в `useEffect`:
```tsx
const candlesRef = useRef(candles);
const markersRef = useRef(markers);
const tradesRef = useRef(trades);

useEffect(() => { candlesRef.current = candles; }, [candles]);
useEffect(() => { markersRef.current = markers; }, [markers]);
useEffect(() => { tradesRef.current = trades; }, [trades]);
```

#### 1.3.2 — `TickerLogo.tsx:58`

**Текущий код:**
```tsx
useEffect(() => {
  setImgError(false);   // ❌ react-hooks/set-state-in-effect
}, [ticker]);
```

**Исправление:** сбросить ошибку через `key={ticker}` в родителе (предпочтительно) или использовать паттерн, который React Compiler одобряет — например, сравнение предыдущего ticker через ref:
```tsx
const prevTickerRef = useRef(ticker);
const [imgError, setImgError] = useState(false);
if (prevTickerRef.current !== ticker) {
  prevTickerRef.current = ticker;
  setImgError(false);  // прямой setState в рендере допустим по React docs
}
```

(См. https://react.dev/reference/react/useState#storing-information-from-previous-renders)

#### 1.3.3 — `BacktestLaunchModal.tsx:109`

**Текущий код:**
```tsx
useEffect(() => {
  if (opened) {
    setTickerSuggestions(getRecentInstruments());  // ❌
  }
}, [opened]);
```

**Исправление:** использовать `useMemo` или вычислять при открытии через ref, либо переписать через lazy initializer, если логика допускает. Простейший вариант:
```tsx
const [tickerSuggestions, setTickerSuggestions] = useState<string[]>(() => getRecentInstruments());

useEffect(() => {
  if (opened) {
    setTickerSuggestions(getRecentInstruments());
  }
}, [opened]);
// + eslint-disable-next-line react-hooks/set-state-in-effect (если нет альтернативы)
```

Если получится сделать через `useMemo` + зависимость от `opened` — это чище.

#### 1.3.4 — `PositionsTable.tsx:74` и `BacktestTrades.tsx:195`

**Текущий код:**
```tsx
const table = useReactTable({
  data,
  columns,
  // ...
});
```

**Исправление:** это known issue TanStack Table + React Compiler. Добавь pragma:
```tsx
// eslint-disable-next-line react-hooks/incompatible-library
const table = useReactTable({
  data,
  columns,
  // ...
});
```

Альтернатива (сложнее, риск stale UI) — оборачивать в `useMemo` вручную, **не делать** без согласования.

#### 1.3.5 — `Sidebar.tsx:56` — react-refresh

**Текущая проблема:** файл экспортирует `Sidebar` компонент + массив константы (`navigationItems` или аналог). Fast refresh не работает.

**Исправление:** создать новый файл `Develop/frontend/src/components/layout/sidebarItems.ts`:
```ts
import { IconHome, IconChartLine, ... } from '@tabler/icons-react';

export const navigationItems = [
  { icon: IconHome, label: 'Главная', path: '/' },
  // ...
];
```

В `Sidebar.tsx` импортировать: `import { navigationItems } from './sidebarItems';`.

### Задача 1.4: Frontend — массовый фикс no-unused-vars

```bash
cd Develop/frontend && pnpm eslint --fix .
```

`--fix` должен автоматически удалить часть импортов. Остаётся ручная доработка:
- `e2e/s4-review-*.spec.ts` — убрать неиспользуемые `expect`, `toolbar` и т.п.
- `src/components/blockly/BlockGenerators.ts:15,29,43...` — 13× `_generator` не используется (переименовать в `_unused` или удалить, если параметр вообще не нужен)
- `src/components/backtest/BacktestProgress.tsx:26,27` — `subscribeProgress`, `unsubscribeProgress` — проверить, нужны ли вообще (возможно, legacy после S5 реализации через event_bus)
- `src/components/charts/FavoritesPanel.tsx:6,14,44,69` — `TextInput`, `formatPercent`, `showAdd`, `handleKeyDown` — удалить лишние импорты / параметры
- `src/components/blockly/BlockDefinitions.ts:222` — `INPUT_NAMES` не используется

**Правило:** если не уверен, нужна ли переменная — переименуй в `_varname` (ESLint игнорирует `_*`), **не удаляй** логику.

### Задача 1.5: Frontend — фикс no-explicit-any

Файлы:
- `e2e/s4-review-ai-chat.spec.ts:16`
- `e2e/s4-review-blockly-backtest.spec.ts:17,291`
- `e2e/s4-review-full.spec.ts:16,28`
- `e2e/s4-review.spec.ts:19`
- `e2e/test-backtest-fixes.ts:203,204`
- `src/components/backtest/StrategyTesterPanel.tsx:50,53,54,131,158,233`

**Правило замены:**
- В e2e — `Record<string, unknown>` или `unknown` (тесты часто работают с сырыми JSON-ответами)
- В `StrategyTesterPanel.tsx` — конкретные типы из `api/types.ts`, если есть; иначе `unknown` + type guard

**НЕ использовать** `any` — это именно то, что запрещено. Если тип нужен и его нет — создать `interface` в том же файле или `api/types.ts`.

### Задача 1.6: Локальная проверка всех 6 команд

После всех фиксов запустить **последовательно**:

```bash
cd Develop/backend
ruff check .                               # exit 0
mypy app/ --ignore-missing-imports         # exit 0
pytest tests/unit/                          # 0 failures

cd ../frontend
pnpm lint                                   # exit 0 (warnings допустимы)
pnpm tsc --noEmit                           # 0 errors
pnpm test                                   # 0 failures
```

**Все 6 должны пройти** до push в remote.

### Задача 1.7: Push и проверка CI

```bash
cd Develop
git checkout -b s5r/ci-cleanup
git add -A
git commit -m "fix(ci): зелёный baseline — ruff per-file-ignores + React 19 hooks"
git push -u origin s5r/ci-cleanup
gh run watch  # или: gh run list --workflow ci.yml --limit 1
```

**Ожидание:** backend job ✅, frontend job ✅. Если какой-то шаг падает — локально воспроизвести и починить в той же ветке.

После зелёного CI — **не мержить автоматически**. Оркестратор / заказчик решают про merge в `develop` отдельно.

---

## Часть 2: S5R.4 — E2E S4 fix (Волна 2)

Запускается **после** того, как S5R.1 завершён (CI зелёный baseline).

### Задача 2.1: Диагностика

```bash
cd Develop/frontend
npx playwright test --reporter=list 2>&1 | tee /tmp/playwright_baseline.log
```

Зафиксировать **точный список** упавших тестов с причинами. Сгруппировать:
- **Селекторы** (Mantine / Blockly / Lightweight Charts обновления)
- **URL** (`?tab=description`, `/backtests/{id}/rerun`, новые роуты)
- **Stores** (`rerunBacktest`, `recentInstruments`, новые методы Zustand)
- **API моки** (новые поля `Backtest.strategy_id`)
- **Flaky** (отсутствие `waitFor` / `expect.poll`)
- **React 19** (strict mode, concurrent behaviour)

### Задача 2.2: Починка по группам

**Правило: не коммит на каждый тест, а один логический фикс на группу.**

Фиксы описаны в [PENDING_S5R_e2e_s4_fix.md:52-60](PENDING_S5R_e2e_s4_fix.md). Конкретные действия:

- **Селекторы** — предпочтительно `getByTestId` (добавь `data-testid` в компоненты, если нет). Не использовать `getByText` для меняющихся переводов.
- **URL** — `await expect(page).toHaveURL(/\?tab=description/)`.
- **Stores** — проверить сигнатуры через `useBacktestStore.getState()` в `page.evaluate`.
- **Flaky** — `await expect(locator).toBeVisible({ timeout: 5000 })`, избегать `page.waitForTimeout(N)`.
- **React 19** — если тест полагался на синхронный re-render, переписать через `await expect(...)` с polling.

### Задача 2.3: Не-spec файлы

`e2e/test-backtest-fixes.ts`, `e2e/test-backtest-flow.ts`, `e2e/test-lkoh-full.ts`:

1. Прочитать содержимое, понять назначение.
2. Если helpers → переместить в `Develop/frontend/e2e/helpers/` и обновить `playwright.config.ts` / ESLint игнор.
3. Если черновики тестов → дописать как `*.spec.ts` или удалить.
4. Если deprecated → удалить.

### Задача 2.4 (опциональная): Playwright в CI

В `.github/workflows/ci.yml` добавить job (если ещё нет):

```yaml
e2e:
  runs-on: ubuntu-latest
  needs: [frontend]
  if: github.event_name == 'pull_request'  # только на PR, не на каждый push
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with: { node-version: '20' }
    - name: Install pnpm
      uses: pnpm/action-setup@v3
    - name: Install deps
      run: cd frontend && pnpm install --frozen-lockfile
    - name: Cache Playwright browsers
      uses: actions/cache@v4
      with:
        path: ~/.cache/ms-playwright
        key: playwright-${{ hashFiles('frontend/pnpm-lock.yaml') }}
    - name: Install Playwright browsers
      run: cd frontend && npx playwright install --with-deps chromium
    - name: Run E2E
      run: cd frontend && npx playwright test --project=chromium
```

**Только если** baseline уже стабильный. Иначе — отложить на Sprint 6.

### Задача 2.5: Финальная проверка

```bash
cd Develop/frontend && npx playwright test
# Ожидание: 0 failures (допустимы test.skip() с аннотацией-тикетом)
```

В отчёте указать: **«X тестов прогоняется, Y passing, Z skipped с обоснованием»**.

# Тесты

Для S5R.1 (CI cleanup) — отдельных unit-тестов нет, проверка через сами линтеры и суиты:

```
Develop/backend/
├── ruff check .         # 0 errors
├── mypy app/            # 0 errors
└── pytest tests/unit/   # 0 failures

Develop/frontend/
├── pnpm lint            # 0 errors
├── pnpm tsc --noEmit    # 0 errors
├── pnpm test            # 0 failures (vitest)
└── npx playwright test  # 0 failures (после S5R.4)
```

**Фикстуры для S5R.4:** существующие `Develop/frontend/e2e/fixtures/` (авто-логин `sergopipo`, моки API). Пароль для `sergopipo` — **спросить у заказчика** перед запуском E2E, не хардкодить.

# ⚠️ Integration Verification Checklist

Для S5R.1 (CI cleanup) checklist трансформируется в «CI правила действительно применяются»:

- [ ] **Backend ruff правило применяется:**
  `cd Develop/backend && ruff check alembic/env.py` → exit 0 (доказывает, что per-file-ignores сработал, а не просто добавлен в файл)
- [ ] **Frontend hooks правила не нарушаются:**
  `cd Develop/frontend && pnpm lint --rule 'react-hooks/refs: error' --rule 'react-hooks/set-state-in-effect: error' --rule 'react-hooks/incompatible-library: error'` → exit 0 на конкретных файлах из задачи 1.3
- [ ] **GitHub Actions run зелёный:**
  `gh run list --workflow ci.yml --branch s5r/ci-cleanup --limit 1` → `completed success`
- [ ] **Все 6 команд из задачи 1.6 возвращают exit 0** — подтвердить командной строкой + вставить лог в отчёт (кратко)

Для S5R.4 (E2E S4 fix):

- [ ] **Playwright baseline работает:**
  `npx playwright test --list` → показывает все тесты без ошибок конфигурации
- [ ] **0 failures:**
  `npx playwright test` → exit 0, либо явно `test.skip(reason, ticket)` с аннотацией
- [ ] **Точное число в отчёте:**
  «X тестов, Y passing, Z skipped с TODO»

**Не применяется** (потому что это не фича): grep на class instantiation, listener на event_bus, background task, API endpoint. Твоя задача — **инфраструктура**, а не runtime-код.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни в финальном ответе **только** структурированную сводку **до 400 слов**. Без полного кода файлов и без лога `Read`/`Grep`.

```markdown
## DEV-1 отчёт — Sprint_5_Review, S5R.1 CI cleanup + S5R.4 E2E S4 fix

### 1. Что реализовано
- S5R.1: ruff per-file-ignores, 6 React 19 hooks фиксов, массовый no-unused-vars, фикс no-explicit-any, вынос Sidebar констант
- S5R.4: X → Y passing Playwright тестов, не-spec файлы реорганизованы, (опционально) e2e job в CI

### 2. Файлы
- **Новые:** `frontend/src/components/layout/sidebarItems.ts`, (опционально) `frontend/e2e/helpers/*.ts`
- **Изменённые:** `backend/pyproject.toml`, `frontend/src/components/backtest/InstrumentChart.tsx`, ...
- **Удалённые/перемещённые:** `frontend/e2e/test-backtest-*.ts` (при необходимости)

### 3. Тесты
- Backend: ruff 0 err, mypy 0 err, pytest X/X passed
- Frontend: eslint 0 err, tsc 0 err, vitest Y/Y passed, playwright Z/Z passed (K skipped с тикетом)
- CI run на GitHub (s5r/ci-cleanup): backend ✅ / frontend ✅

### 4. Integration points
- Правило `[tool.ruff.lint.per-file-ignores]` применено (проверено через `ruff check alembic/env.py`)
- React 19 hooks правила соблюдены (конкретные 6 мест исправлены, не через eslint-disable глобально)
- CI на GitHub для PR s5r/ci-cleanup: зелёный run #NNN

### 5. Контракты для других DEV
- **Поставляю C1** (ruff green): `backend/pyproject.toml` содержит `[tool.ruff.lint.per-file-ignores] "alembic/env.py" = ["F401"]` — подтверждено
- **Поставляю C2** (eslint green): конкретные 6 мест исправлены (не через понижение правил) — подтверждено
- **Поставляю C3** (all CI jobs reach command): PR run показывает все 6 шагов ✅
- **Поставляю C10** (Playwright baseline): `npx playwright test` → 0 failures (или явные skip)

### 6. Проблемы / TODO
- <если mypy/pytest/tsc/vitest выявили новые проблемы — здесь>
- <test.skip() с тикетами — здесь>

### 7. Применённые Stack Gotchas
- `Gotcha 1` (Pydantic v2 Decimal): при фиксе `no-explicit-any` в `StrategyTesterPanel.tsx` Decimal-поля оставлены как `string` (а не `number`) — избежали потери точности
- `Gotcha <N>`: <...>

### 8. Новые Stack Gotchas (если обнаружены)
- Если найдена новая ловушка (например, React 19 Compiler + TanStack Table) — описать в формате симптом/причина/правило для добавления в `Develop/CLAUDE.md` после приёмки
```

# Alembic-миграция (если применимо)

**Не применимо** — задача не касается моделей БД.

# Чеклист перед сдачей

- [ ] Все задачи 1.1-1.7 (S5R.1) выполнены
- [ ] Все задачи 2.1-2.5 (S5R.4) выполнены
- [ ] `cd Develop/backend && ruff check .` → exit 0
- [ ] `cd Develop/backend && mypy app/ --ignore-missing-imports` → exit 0
- [ ] `cd Develop/backend && pytest tests/unit/` → 0 failures
- [ ] `cd Develop/frontend && pnpm lint` → exit 0
- [ ] `cd Develop/frontend && pnpm tsc --noEmit` → 0 errors
- [ ] `cd Develop/frontend && pnpm test` → 0 failures
- [ ] `cd Develop/frontend && npx playwright test` → 0 failures (после S5R.4)
- [ ] Push в `s5r/ci-cleanup` → CI на GitHub зелёный (`gh run list`)
- [ ] **Integration Verification Checklist полностью пройден** (CI правила применяются, все 6 команд зелёные)
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены, ≤ 400 слов
- [ ] **Cross-DEV contracts C1, C2, C3, C10 подтверждены** в секции 5 отчёта
- [ ] **Stack Gotchas применены** — секция 7 отчёта содержит применённые ловушки
- [ ] **Никаких глобальных `--no-verify` / `eslint-disable` для всего файла** — только точечные `eslint-disable-next-line` с комментарием «known issue X»
