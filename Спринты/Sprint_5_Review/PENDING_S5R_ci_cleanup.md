# [Sprint_5_Review] CI Cleanup: вернуть зелёный baseline backend + frontend

> Новая задача, выявлена 2026-04-14 через Gmail MCP при проверке уведомлений GitHub.
> **Приоритет:** 🔴 Блокер для всех остальных задач S5R (через Integration Verification Checklist).

## Контекст

CI workflow `moex-terminal/.github/workflows/ci.yml` падает **с 2026-04-03** (коммит `a73d902` Sprint 4) на обоих jobs — backend и frontend. Все 9 CI-запусков за 11 дней возвращали `All jobs have failed`. Уведомления приходили на почту `notifications@github.com` и копились в inbox — никто не смотрел.

### Хронология падений (из Gmail)

| Дата | Коммит | Ветка | Что за коммит |
|------|--------|-------|---------------|
| 2026-04-03 | `a73d902` | main + develop | Sprint 4 milestone |
| 2026-04-08 | `3392ab5` | develop | Sprint 5 changelog + планы |
| 2026-04-09 | `0927628` | develop | Sprint 5 замечания 27-31 |
| 2026-04-10 | `13a8b19` | develop | Sprint 5 замечание 32 |
| 2026-04-13 | `9697b47` | develop | UI лоты + «Просадка» 13.04 |
| 2026-04-14 | `5417aa2` | docs/claude-md-stack-gotchas | CLAUDE.md (только docs) |
| 2026-04-14 | `9b9ace2` | develop (merge) | Merge PR #1 |

Моё PR #1 (только документация в `Develop/CLAUDE.md`) упал так же, как и все предыдущие — значит, проблема давно, не от моих правок.

### Почему никто не замечал

1. Уведомления GitHub копились в почте, не в основном рабочем процессе
2. В changelog S5 тесты утверждаются как «passed» — это **ручной** запуск, не CI
3. На ARCH-ревью S5 статус CI не проверялся — только локальный запуск тестов

## Корневые причины падений

### Backend `Lint (ruff)` — F401 в `alembic/env.py`

Команда: `cd backend && ruff check .`

Все ошибки типа `F401 imported but unused`:

```
F401 `sqlalchemy.event` imported but unused      → alembic/env.py:3
F401 `app.auth.models.User` imported but unused  → alembic/env.py:7
F401 `app.auth.models.RevokedToken` imported    → alembic/env.py:7
F401 `app.strategy.models.Strategy`              → alembic/env.py:8
F401 `app.strategy.models.StrategyVersion`       → alembic/env.py:8
F401 `app.market_data.models.Instrument`         → alembic/env.py:9
F401 `app.market_data.models.OHLCVCache`         → alembic/env.py:9
F401 `app.market_data.models.BondInfoCache`      → alembic/env.py:9
F401 `app.backtest.models.Backtest`              → alembic/env.py:10
... (и ещё ~8 таких же)
```

**Это ложные срабатывания.** Alembic `env.py` требует импортировать все модели ради side-effect регистрации в `Base.metadata` — без этого `alembic revision --autogenerate` не увидит таблицы. Символы действительно «не используются как переменные», но импорт нужен. Классический ruff-gotcha.

**Решение:** одна секция в `backend/pyproject.toml`:

```toml
[tool.ruff.lint.per-file-ignores]
"alembic/env.py" = ["F401"]
```

В текущем `pyproject.toml` этого правила нет — там только `[tool.ruff]` с `target-version = "py311"` и `line-length = 100`.

### Frontend `Lint (eslint)` — React 19 + strict rules

Команда: `cd frontend && pnpm lint`

Ошибки делятся на 4 категории:

#### Категория 1: Новые правила React 19 (`eslint-plugin-react-hooks@7.x`)

После апгрейда на React 19 + `eslint-plugin-react-hooks@7.x` включились три новых строгих правила:

**`react-hooks/refs`** — нельзя изменять `ref.current` в теле компонента.
Файл: `InstrumentChart.tsx:39-41`
```tsx
const markersRef = useRef(markers);
const tradesRef = useRef(trades);
candlesRef.current = candles;     // ❌ error
markersRef.current = markers;     // ❌ error
tradesRef.current = trades;       // ❌ error
```
Решение: перенести в `useEffect`.

**`react-hooks/set-state-in-effect`** — нельзя вызывать `setState` синхронно в теле `useEffect`.
Файлы:
- `BacktestLaunchModal.tsx:109` — `setTickerSuggestions(getRecentInstruments())` в useEffect при `opened`
- `TickerLogo.tsx:58` — `setImgError(false)` в useEffect body

Решение: использовать reducer-паттерн или вынести начальное состояние в `useState(() => ...)`.

**`react-hooks/incompatible-library`** — TanStack Table `useReactTable()` несовместима с React Compiler.
Файлы:
- `PositionsTable.tsx:74` — `const table = useReactTable({...})`
- `BacktestTrades.tsx:195` — то же

Это **known issue** TanStack Table + React Compiler. Решения два:
- `// eslint-disable-next-line react-hooks/incompatible-library` перед каждым вызовом (pragmatic)
- Вручную оборачивать в `useMemo` с грамотной инвалидацией (сложно, риск stale UI)

#### Категория 2: Legacy `@typescript-eslint/no-unused-vars`

Множество файлов в `e2e/` и `src/components/`:
```
e2e/s4-review-ai-chat.spec.ts:7   — 'expect' is defined but never used
e2e/s4-review-full.spec.ts:7, 150 — 'expect', 'toolbar' not used
e2e/test-backtest-flow.ts:61      — 'url' assigned, never used
e2e/test-lkoh-full.ts:57, 97      — 'finalStatus', 'cacheResp' not used
src/components/backtest/BacktestLaunchModal.tsx:61       — 'strategyId' not used
src/components/backtest/BacktestProgress.tsx:26, 27      — 'subscribeProgress', 'unsubscribeProgress' не используются
src/components/backtest/__tests__/BacktestProgress.test.tsx:2 — 'fireEvent' не используется
src/components/blockly/BlockDefinitions.ts:222           — 'INPUT_NAMES' не используется
src/components/blockly/BlockGenerators.ts:15,29,43...    — 13× '_generator' не используется
src/components/charts/FavoritesPanel.tsx:6,14,44,69      — 'TextInput', 'formatPercent', 'showAdd', 'handleKeyDown' не используются
src/components/strategy/__tests__/BlocklyWorkspace.test.tsx:1 — 'beforeEach' не используется
```

Решение: массовый автофикс через `pnpm eslint --fix` + ручная правка тех, что `--fix` не трогает (удаление ненужных импортов / переименование в `_var`).

#### Категория 3: Legacy `@typescript-eslint/no-explicit-any`

```
e2e/s4-review-ai-chat.spec.ts:16         — Unexpected any
e2e/s4-review-blockly-backtest.spec.ts:17,291 — Unexpected any
e2e/s4-review-full.spec.ts:16,28         — Unexpected any
e2e/s4-review.spec.ts:19                 — Unexpected any
e2e/test-backtest-fixes.ts:203,204       — Unexpected any
src/components/backtest/StrategyTesterPanel.tsx:50,53,54,131,158,233 — 6× Unexpected any
```

Решение: заменить `any` на `unknown`, конкретные типы, или `satisfies` где уместно. Для e2e-файлов — можно `Record<string, unknown>`.

#### Категория 4: `react-refresh/only-export-components`

```
src/components/layout/Sidebar.tsx:56 — Fast refresh only works when a file only exports components
```

Решение: вынести константы из `Sidebar.tsx` в отдельный файл (например, `sidebarItems.ts`).

## Важный нюанс: что с mypy, pytest, tsc, vitest, playwright?

В `.github/workflows/ci.yml` после `Lint` идут:
- Backend: `mypy app/ --ignore-missing-imports`, `pytest tests/unit/ -v`
- Frontend: `pnpm tsc --noEmit`, `pnpm test`

Из-за `bash -e` в actions ни одна из этих команд **ни разу не запускалась в CI** после 3 апреля. Мы **не знаем**, проходят ли они. В Changelog S5 пользователь утверждает «548 backend tests passed + 23 E2E passed», но это был ручной прогон.

**Обязательная часть этой задачи:**
- После починки lint локально запустить **все 6 команд** и подтвердить, что они проходят:
  1. `cd backend && ruff check .`
  2. `cd backend && mypy app/ --ignore-missing-imports`
  3. `cd backend && pytest tests/unit/`
  4. `cd frontend && pnpm lint`
  5. `cd frontend && pnpm tsc --noEmit`
  6. `cd frontend && pnpm test`
- Если какая-то команда падает — это **новая** проблема, которую мы раньше не видели (её скрывала ошибка lint). Фиксить в рамках этой же задачи.
- Только после того, как все 6 команд локально зелёные — push в ветку → проверка CI на GitHub → зелёный ✅.

Также: **`pnpm playwright test`** не запускается в CI вообще (workflow не содержит шага для E2E). Это задача 4 (E2E S4 fix) — она не часть CI cleanup, но логически связана.

## Что нужно сделать

### Backend

1. Добавить в `backend/pyproject.toml`:
   ```toml
   [tool.ruff.lint.per-file-ignores]
   "alembic/env.py" = ["F401"]
   ```
2. Локально прогнать `cd backend && ruff check .` → 0 errors.
3. Локально прогнать `cd backend && mypy app/ --ignore-missing-imports` → если ошибки, фиксить в этой же задаче.
4. Локально прогнать `cd backend && pytest tests/unit/` → 0 failures.

### Frontend

5. **Исправить 6 конкретных React 19 проблем** (см. Категория 1 выше):
   - `InstrumentChart.tsx:39-41` — ref.current в useEffect
   - `TickerLogo.tsx:58` — setImgError(false) через useState initializer или useEffect с зависимостью на ticker
   - `BacktestLaunchModal.tsx:109` — setTickerSuggestions через useState initializer или useEffect body без setState
   - `PositionsTable.tsx:74`, `BacktestTrades.tsx:195` — `// eslint-disable-next-line react-hooks/incompatible-library`
   - `Sidebar.tsx:56` — вынести константы в `sidebarItems.ts`
6. **Массовый фикс no-unused-vars:** `cd frontend && pnpm eslint --fix .` + ручная правка тех, что `--fix` не трогает
7. **Фикс no-explicit-any** в `e2e/` и `StrategyTesterPanel.tsx`: заменить на `unknown` / конкретные типы
8. **Удалить / переименовать** `e2e/test-backtest-fixes.ts` и `e2e/test-backtest-flow.ts` — они не соответствуют паттерну `*.spec.ts`, возможно это вспомогательные скрипты, надо либо оформить как utils, либо удалить
9. Локально прогнать `cd frontend && pnpm lint` → 0 errors (или только warnings)
10. Локально прогнать `cd frontend && pnpm tsc --noEmit` → 0 errors (если ошибки — фиксить в этой же задаче)
11. Локально прогнать `cd frontend && pnpm test` → 0 failures (если ошибки — фиксить в этой же задаче)

### CI verification

12. Push всех правок в feature-ветку `s5r/ci-cleanup` (или аналогичную)
13. Проверить на GitHub Actions: backend job зелёный, frontend job зелёный
14. Проверить, что уведомления `Run failed: CI` прекратились после merge в develop
15. **Integration Verification:** `grep -rn "per-file-ignores" backend/pyproject.toml` показывает настройку; `grep -rn "react-hooks/refs\|react-hooks/set-state-in-effect\|react-hooks/incompatible-library" frontend/eslint.config.js` — если использовались pragma-комменты, подтвердить факт или альтернативу

## Файлы, которые затронет задача

| Файл | Изменение |
|------|-----------|
| `Develop/backend/pyproject.toml` | + `[tool.ruff.lint.per-file-ignores]` секция |
| `Develop/frontend/src/components/backtest/InstrumentChart.tsx` | Перенос ref.current в useEffect |
| `Develop/frontend/src/components/backtest/BacktestLaunchModal.tsx` | setState вне useEffect body |
| `Develop/frontend/src/components/common/TickerLogo.tsx` | setState вне useEffect body |
| `Develop/frontend/src/components/account/PositionsTable.tsx` | `// eslint-disable-next-line react-hooks/incompatible-library` |
| `Develop/frontend/src/components/backtest/BacktestTrades.tsx` | `// eslint-disable-next-line react-hooks/incompatible-library` |
| `Develop/frontend/src/components/layout/Sidebar.tsx` | Вынос констант в отдельный файл |
| `Develop/frontend/src/components/layout/sidebarItems.ts` | **Новый файл** — константы sidebar |
| `Develop/frontend/src/components/**/*.tsx` | Массовый фикс no-unused-vars через eslint --fix |
| `Develop/frontend/e2e/**/*.ts` | Ручной фикс no-explicit-any, no-unused-vars |
| `Develop/frontend/e2e/test-backtest-*.ts` | Переименование / удаление не-тестовых файлов |

## Связь с другими задачами S5R

| Задача | Связь |
|--------|-------|
| **Задача 2** Live Runtime Loop | Предусловие — DEV-2 будет делать PR с большим количеством правок в frontend trading-компонентах, React 19 новые правила могут затронуть |
| **Задача 3** Реальные позиции T-Invest | Предусловие — DEV-3 будет делать PR с frontend account-компонентами, lint должен быть зелёный baseline |
| **Задача 4** E2E S4 fix | Тесно связана — чинит Playwright, а CI cleanup чинит ESLint. Оба про «тесты работают». Исполняются одним DEV-агентом |

## Критерии готовности

- [ ] `backend/pyproject.toml` содержит `[tool.ruff.lint.per-file-ignores]` для `alembic/env.py`
- [ ] `cd backend && ruff check .` → exit 0
- [ ] `cd backend && mypy app/ --ignore-missing-imports` → exit 0 (или задокументированы warn-only)
- [ ] `cd backend && pytest tests/unit/` → 0 failures
- [ ] `cd frontend && pnpm lint` → exit 0 (warnings допустимы)
- [ ] `cd frontend && pnpm tsc --noEmit` → 0 errors
- [ ] `cd frontend && pnpm test` → 0 failures
- [ ] CI на GitHub для merge commit в `develop` зелёный (backend + frontend оба)
- [ ] Следующее PR в `moex-terminal` получает письмо `Run succeeded: CI` вместо `Run failed: CI`
- [ ] **Cross-DEV contracts C1, C2, C3** (из `execution_order.md`) подтверждены в отчёте DEV

## Ссылки

- Workflow: `Develop/.github/workflows/ci.yml`
- Pyproject: `Develop/backend/pyproject.toml`
- ESLint config: `Develop/frontend/eslint.config.js`
- Stack Gotchas: `Develop/CLAUDE.md` — вероятно, по итогам этой задачи появится **новая Gotcha 6** про React 19 + ESLint 9 новые правила
- Процессные правила: `Спринты/prompt_template.md`
