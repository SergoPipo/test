## ARCH отчёт — Sprint 8, задача 8.R Final Review

**Wave:** W3 / Поток D
**Date:** 2026-05-13
**Verdict:** **PASS WITH NOTES** — M4 Production-ready достигнут

### 1. Что реализовано (ARCH-аспект)

Финальное 8.R архитектурное ревью Sprint 8 по образцу `Sprint_6_Review/code_review.md` + `Sprint_7/arch_review_s7.md`. Выполнены все 8 частей (A-H) промпта: 8-секционный code review (Backend Trading/Broker, Backtest/MarketData, Notification/Event sync, Security, Admin/Performance, Frontend Charts, Frontend widgets/admin, OPS Deployment), фактическое измерение всех метрик через прогоны `pytest` / `vitest` / `lint` / `tsc` / `bandit` / `safety` / `alembic`, ревизия 9 Cross-DEV контрактов C-S8-1..9 grep'ом, integration verification 20+ новых символов W1+W2+W3, ревизия Stack Gotchas (зарегистрирована gotcha-32 с перенумерацией DEV-3 кандидата), проверка documentation completeness (README/INSTALL/ФТ v2.5/ТЗ v1.5/development_plan v2.1/deployment_guide 9 разделов/CLAUDE.md polish).

### 2. Файлы

- **Новые:**
  - `Спринты/Sprint_8/arch_review_s8.md` (полный 16-раздельный отчёт, ~750 строк).
  - `Спринты/Sprint_8/reports/ARCH_S8_review.md` (текущий, краткая сводка).
  - `Develop/stack_gotchas/gotcha-32-react-hooks-disable-directive-placement.md` (перенумерован DEV-3 W3 кандидат; gotcha-26 уже занят DEV-5 для `structlog event kwarg`).
- **Изменённые:**
  - `Develop/stack_gotchas/INDEX.md` (версия 7 → 8, +1 строка gotcha-32).

**НЕ модифицировано** (по правилам промпта): production-код, `changelog.md`, `sprint_state.md`, `project_state.md` — финальные апдейты делает оркестратор после моего PASS.

### 3. Тесты

| Прогон | Цель | Факт | Статус |
|---|---|---|---|
| Backend pytest | 0 failed | **1490 passed / 0 failed / 0 xfail** (244s) | ✅ |
| Backend coverage TOTAL | ≥ 80% | **85%** (gate +5% запас) | ✅ |
| Frontend vitest | 0 failed (pre-existing flaky ok) | **558 passed / 2 flaky / 0 регрессий** | ✅ |
| Frontend tsc | 0 | **0** | ✅ |
| Frontend `lint --max-warnings 0` | 0 | **0 err / 0 warn** | ✅ |
| Backend ruff | 0 | **0** | ✅ |
| Bandit medium+ | 0 | **0 medium / 0 high** | ✅ |
| Safety unaccepted CVE | 0 | **0** (1 documented expires 2026-12-31) | ✅ |
| Alembic up/down/up | clean | **clean** (head=ef6627a679aa) | ✅ |
| EVENT_MAP ↔ EVENT_TYPE_LABELS | sync | **17 ↔ 17** | ✅ |
| Cross-DEV contracts | 9/9 connected | **9/9 verified** | ✅ |

Per-module P0+P1: `dispatchers.py` 100%, `trading/service` 88%, `adapter` 95%, `backtest/engine` 96%, `backtest/router` 87% (real), `market_data/service` 78% (gap −2%, перенос в W4), `circuit_breaker/router` 100%, `auth/router` 94% (real), `broker/router` 99% (real).

### 4. Integration points (контракты C-S8-1..9 статус)

**Все 9 контрактов CONNECTED** через grep production-кода:
- C-S8-1: `/health` extended → `HealthWidget.tsx:59,84,139`
- C-S8-2: sparkline → `SparklineWidget.tsx:51,72`
- C-S8-3: since_first_activity → `BalanceWidget.tsx:52`
- C-S8-4: telegram/test → `notificationApi.ts:45`
- C-S8-5: PaginatedResponse → 5 потребителей через `unwrapPaginated`
- C-S8-6: multiplexer singleton → `main.py:257-263`, `adapter.py:751`, 1 hit `TInvestStreamMultiplexer(` factory only
- C-S8-7: is_admin → `Sidebar.tsx`, `ProtectedAdminRoute.tsx`
- C-S8-8: Plotly Dash `/admin/metrics` → `main.py:317-332` mount; 3/3 integration тестов
- C-S8-9: 17 event_type ↔ 17 UI labels (полная sync)

### 5. Контракты для других DEV (W4 DEFERRED list (Sprint_8_Review))

**18 переносных карточек в `Sprint_8_Review/backlog.md`:** 0 critical/high; 6 medium (S8R-W4-PERF-BASELINE-MEASUREMENTS, S8R-SEC-AUTH-RATE-TIGHTEN, S8R-COV-MARKET-DATA-SERVICE, S8R-W4-TEST-EVENT-DELIVERY-E2E, S8R-UX-DRAWING-LEGACY-BACKFILL, S8R-UX-ADMIN-LANDING-EMPTY); 11 low (gotcha-24 register, e2e analytics unskip, FT cosmetic typo, client.test flaky, 4 UX, S8R-W4-COV-STRATEGY-SERVICE, S7R-MULTICURRENCY-TOGGLE, S8R-UX-PLOTLY-DARK закрыть); 2 informational (docker compose validate на первом deployment, Playwright nightly rerun перед production).

### 6. Проблемы / TODO (minor notes, не блокеры)

1. `market_data/service.py` 78% (gap −2% до 80%) — W4.
2. **gotcha-24 файл отсутствует** в `Develop/stack_gotchas/` (INDEX строка 24 пропущена). Кандидат от DEV-3 W1 и S7 closeout — W4 регистрация.
3. **2 skip в `e2e/s7-backtest-analytics.spec.ts`** — FRONT2 W2 разблокировал условия (DOM overlay + onRowClick) но skip формально остался — W4 активация.
4. **FT v2.5 (`functional_requirements.md:14`):** «EVENT_TYPE_LABELS 13» (фактически 17) — cosmetic typo, W4 fix.
5. `S8R-SEC-AUTH-RATE-TIGHTEN` (medium): rate limit `/auth/login` = 60/min, цель 3-5/min. Documented в `security_audit_s8.md`, не закрыто в S8.
6. **Performance baseline числа не измерены** через `pytest-benchmark`. Инфраструктура `@timed_event` готова (3 hot-path), но фактические p95 для dashboard LCP / signal→order / Telegram cmd — W4 (`S8R-W4-PERF-BASELINE-MEASUREMENTS`).
7. **`docker compose config` не запущен** — нет docker CLI в DEV-окружении (DEV-5 W3 явно отметил). Финальная семантическая валидация на первом Mac mini deployment.
8. **`client.test.ts` 2 pre-existing flaky** — НЕ S8-регрессия (`git stash` без правок воспроизводит). W4 диагноз.
9. `S8R-UX-PLOTLY-DARK-THEME` из UX_W3 — **уже реализовано** (`template='plotly_dark'` в metrics_dash.py), карточку закрыть.

### 7. Применённые Stack Gotchas (для верификации)

- **Gotcha 11/12/13** — проверил alembic up/down/up для миграции `ef6627a679aa_s8w3_strategy_status_enum_drift` (W3 DEV-4).
- **Gotcha 20** — `auth/router.py:39` (FastAPI static vs int path) — структурно учтён.
- **Gotcha 25** — паттерн `PaginatedResponse<T>` + `unwrapPaginated` — верифицирован у 5 потребителей.
- **Gotcha 29** — `concurrency=greenlet,thread` в `.coveragerc` — подтвердил, реальное coverage 85% (без него было бы 80%).
- **Gotcha 31** — `AdminAuthASGIMiddleware` для Plotly Dash mount — 3/3 integration теста.

### 8. Новые Stack Gotchas (зарегистрировано ARCH в 8.R)

- **`gotcha-32-react-hooks-disable-directive-placement.md`** (frontend/lint, severity low). Перенумерован DEV-3 W3 кандидат `gotcha-26-react-hooks-disable-directive-placement.md` (номер 26 уже занят DEV-5 для `structlog event kwarg`). Симптом: `// eslint-disable-next-line react-hooks/exhaustive-deps` над сигнатурой `useEffect(...)` → «Unused directive» + warning остаётся. Решение: класть директиву над строкой с deps-array `}, [...])`. Применено в 7 файлах frontend (CandlestickChart, BlocklyWorkspace×2, StrategyEditPage, AIChat, PositionsTable, BacktestTrades) при закрытии S7R-FE-LINT-WARNINGS-CLEANUP. Защита от регрессии: `--max-warnings 0` в CI.

### 9. Использование плагинов

- **pyright-lsp / typescript-lsp:** не вызывал MCP отдельно — fallback через `pytest`, `pnpm tsc --noEmit`, `pnpm lint --max-warnings 0` (все 0 errors). Достаточно для ARCH-режима (read-only ревью).
- **context7:** не запрашивал (нет новых API — только верификация существующих).
- **playwright:** ⚠️ SKIP — W3 фичи unit-tests coverage адекватная (Histogram Tooltip 3 unit, HealthWidget WS 2 unit, BackgroundBacktestsBadge auto-collapse 2 unit, DashboardPage paused-filter 7 unit). Playwright nightly суит финально прогнан в W2 (158 passed). Полная регрессия nightly перед Mac mini deployment — W4 informational item.
- **code-review:** не вызывал отдельно — ARCH в финальном ревью использует grep + read + pytest + ручное чтение reports/. Промпт явно даёт право пропустить `/code-review` skill в финале.
- **superpowers:** не применимо (ARCH мета-уровень, не TDD/brainstorm).
- **WebSearch:** не использовал.

**Итог 9:** все обязательные инструменты ревью выполнены через CLI + fallback. MCP-плагины не критичны для read-only финала.

---

**Сдача оркестратору:** PASS WITH NOTES → закрытие M4 Production-ready → перенос 18 DEFERRED-W4 карточек → финальные апдейты `project_state.md` / `Sprint_8/changelog.md` / `sprint_state.md` (задача оркестратора).
