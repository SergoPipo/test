# Sprint 8 — текущее состояние

> Обновляется после каждого этапа.

**Дата планирования:** 2026-05-12
**Дата старта W0:** 2026-05-12
**Дата завершения W0:** 2026-05-12 (gate W0 → W1 пройден, все 10 TODO + новый эпик Admin role утверждены)
**Дата старта W1:** 2026-05-12
**Дата завершения W1:** 2026-05-12 (gate W1 → W2 пройден с одним отложенным критерием — coverage P1 для 4 модулей переносится в W2 по архитектурным зависимостям)
**Дата старта W2:** —
**Дата завершения W2:** —
**Дата старта W3:** —
**Дата завершения 8.R:** —

## Текущий шаг

**Sprint 8 ✅ W1 ЗАВЕРШЁН (2026-05-12). 5 параллельных потоков (BACK1+BACK2+FRONT1+FRONT2+QA) закрыты. Ожидает команды заказчика «старт W2».**

Sprint 7 финально закрыт со всеми post-S7 closeout-волнами. M3 Phase 1 production-ready.

### W1 финальные метрики (2026-05-12)

| Слой | Baseline | После W1 | Δ |
|------|----------|----------|---|
| Backend pytest | 1024 / 0 | **1098 passed / 6 xfailed / 0 failed** | +74 passed, +6 xfailed (contract для W2 SecurityHeadersMiddleware) |
| Frontend vitest | 468 / 0 | **528 passed / 0 failed** | +60 |
| Playwright nightly | 142 passed | **157 passed / 1 pre-existing flaky / 6 skipped** | +15 (5 новых + регрессия) |
| Backend coverage | 71% TOTAL | dispatchers 0→100%, trading/service 51→88%, остальные P1 в W2 | по 2 модулям ≥80% |
| Frontend lint | 0 err / 9 warn | 0 err / 9 warn (baseline) | W3 cleanup |
| Backend ruff | 0 issues | 0 issues | — |
| Backend mypy | 0 errors | 0 errors | — |
| Bandit | n/a | 0 medium+, 28 low (informational) | новый CI gate |
| Safety | n/a | 0 reported / 1 documented CVE (protobuf транзитив) | новый CI gate |

### Gate W1 → W2 проверка

| Критерий | Статус | Комментарий |
|----------|--------|------------|
| Все medium-high закрыты | ✅ | DRAWING-EDITING (tests), STRATEGY-STATUS-CHANGE-UI, API-PAGINATED-TYPE-MISMATCH, MULTIPLEXER-SINGLETON contract |
| security_audit_s8.md готов с findings + fixes | ✅ | 3 high → W2 (HEADERS, TELEGRAM-XSS, EMAIL-XSS) с обоснованиями; 7 medium + 2 low в backlog |
| 6 E2E зелёные | ✅ | 17 Playwright passed + 3 pytest passed (= 20). 2 теста в s7-backtest-analytics skipped на S8R-ANALYTICS-EQUITY-ZONES-TESTID + S8R-ANALYTICS-TRADE-ROW-CLICK (требуют FRONT2 W2) |
| Coverage P0+P1 advanced до 80% по ≥4 модулям | ⚠️ DEFERRED | 2 из 6 модулей закрыты (P0 dispatchers, P1 trading/service). Остальные 4 P1 (tinvest/adapter, market_data/service, backtest/router, backtest/engine) перенесены в W2 по архитектурной зависимости (adapter нужен MULTIPLEXER-SINGLETON — он готов сейчас, остальные P1 = scope W2 Поток A) |
| Admin role работает | ✅ | Миграция + dependency + CLI + Sidebar + 14 тестов + smoke whitelist |
| bandit + safety в CI (medium+ блокирует) | ✅ | Job `security-scan` в `.github/workflows/ci.yml`, .bandit + safety_policy.yml |

### W1 BACK1 (DEV-1) — DONE 2026-05-12
- Admin role backend каркас (миграция users.is_admin + dependency require_admin + app/admin/router.py + CLI grant_admin + bootstrap первого admin) — контракт C-S8-7 поставлен FRONT2.
- Coverage P0 `notification/dispatchers.py` 0% → 100% (15 тестов).
- Coverage P1 `trading/service.py` 51% → 88% (31 тест).
- Coverage P1 `broker/tinvest/adapter.py` 24% → SKIP до W2 (ждал BACK2 C-S8-6 MULTIPLEXER-SINGLETON; теперь готов к W2 Поток A).
- Тесты: 1027 → 1087 passed / 0 failed (+60). Ruff/mypy чистые. Alembic up/down/up чистый.
- Отчёт: `Sprint_8/reports/DEV-1_W1.md`.

### W1 BACK2 (DEV-2) — DONE 2026-05-12
- 8B.1 bandit/safety в CI (job `security-scan`).
- 8B.2 `security_audit_s8.md`: 0 critical / 3 high / 7 medium / 2 low. High → W2 fixes.
- 8B.3 multiplexer singleton — реализация уже была в S7-hotfix через module-level `_singletons`. Зафиксирован contract 6 новыми тестами `test_multiplexer_singleton.py`.
- 8B.4 require_admin smoke — структурный whitelist-тест `test_admin_routes_protection.py`.
- Тесты: 1087 → 1098 passed / 6 xfailed / 0 failed (+11 passed +6 xfailed для будущего SecurityHeadersMiddleware).
- Отчёт: `Sprint_8/reports/DEV-2_BACK2_W1.md`.

### W1 FRONT1 (DEV-3) — DONE 2026-05-12
- S7R-DRAWING-EDITING уже был реализован S7-hotfix'ами; W1 закрыл gap — 23 unit-теста на `coords.ts`.
- S7R-DRAWING-INTRADAY-COORDS — фикс рендера через `isSeriesInSequentialMode(series)` + двухветочный `pointToCoord` (logical-first для sequential mode).
- Файлы: `coords.ts` (изменён), `coords.test.ts` (новый, 23 теста).
- Тесты: 503 → 528 passed (всё зелёное после параллельных правок).
- Stack Gotchas: кандидат `gotcha-24-lightweight-charts-sequential-time-axis.md` (для ARCH-ревью W3 8.R).
- Отчёт: `Sprint_8/reports/DEV-3_FRONT1_W1.md`.

### W1 FRONT2 (DEV-4) — DONE 2026-05-12
- 8.D.1 API paginated audit (C-S8-5): `PaginatedResponse<T>` + `isPaginatedResponse` + `unwrapPaginated`; silent-bug в `accountApi.getBalanceHistory` пофикшен (BalanceWidget рендерил пустой sparkline). 14 unit-тестов.
- 8.D.2 ErrorBoundary (S7R-FRONTEND-ERROR-BOUNDARY-MISSING): `components/common/ErrorBoundary.tsx` (class + Mantine fallback + retry/reload). Top-level в App.tsx + per-widget в DashboardPage + ChartPage. 8 тестов.
- 8.D.3 Strategy status menu (S7R-STRATEGY-STATUS-CHANGE-UI): Mantine Menu + Badge + optimistic update + rollback + toast. 7 тестов.
- 8.D.4 Admin role frontend (C-S8-7): `AuthUser.is_admin`, Sidebar conditional `IconShield`, ProtectedAdminRoute (redirect+toast), AdminLayout + AdminLandingPage заглушка. Plotly Dash /admin/metrics — W2. 8 тестов.
- Тесты: 468 → 528 passed / 0 failed (+60). tsc 0 errors, lint 0 errors / 9 warnings (baseline).
- Stack Gotchas: новый `gotcha-25-api-paginated-type-mismatch.md` (в каталог + INDEX).
- Отчёт: `Sprint_8/reports/DEV-4_FRONT2_W1.md`.

### W1 QA — DONE_WITH_CONCERNS 2026-05-12
- 5 Playwright spec'ов + 1 pytest integration:
  - `s7-export.spec.ts` (3/3), `tests/integration/test_backup_cli.py` (3/3 pytest), `s7-events.spec.ts` (6/6 table-driven через mockWSChannel), `s7-tg-callbacks.spec.ts` (2/2), `s7-backtest-analytics.spec.ts` (3 passed / 2 skipped на блокерах), `s7-bg-backtest.spec.ts` (3/3).
- Расширен `api_mocks.ts` (+310 строк): `mockWSChannel`, `mockBacktestResults`, `mockBacktestWithTrades`, `mockBacktestRun`, `mockMoexCandles`.
- Регрессия nightly: 157 passed / 1 pre-existing flaky (`s5-paper-trading pause-resume`) / 6 skipped.
- Новые блокеры (нужны карточки в backlog):
  - `S8R-ANALYTICS-EQUITY-ZONES-TESTID` — DOM-overlay для зон equity-curve (canvas pixel-based, нет data-testid).
  - `S8R-ANALYTICS-TRADE-ROW-CLICK` — rows в `BacktestTrades.tsx` без `onClick`.
- Новая Stack Gotcha (кандидат): Mantine 0-height bar + Playwright `toBeVisible` → использовать `toBeAttached()`/`count()`.
- Отчёт: `Sprint_8/reports/QA_W1.md`.

### Что дальше (W2)
1. Заказчик подтверждает старт W2.
2. Поток A (BACK1, ~20ч): coverage P1 закрытие (`tinvest/adapter` 24→80%, `market_data/service` 50→80%, `backtest/router` 25→80%, `backtest/engine` 55→80%) + AIChat mock дополнение + performance instrumentation `@timed_event`.
3. Поток B (BACK2, ~25ч): Event type sync (4 backend в UI + 5 UI publish-sites) + Dashboard widgets backend + S8R-SEC-HEADERS / TELEGRAM-XSS / EMAIL-XSS фиксы.
4. Поток C (FRONT2, ~22ч): Dashboard widgets frontend + Grid Heatmap entrypoint + widgets unit coverage + **Plotly Dash `/admin/metrics`** + event_type sync UI labels + S8R-ANALYTICS-EQUITY-ZONES-TESTID + TRADE-ROW-CLICK.
5. Поток D (BACK1, ~10ч): Coverage P2 (router-тесты).
6. QA: AIChat mock block_xml дополнение (~2ч).

### W1 BACK1 (DEV-1) — DONE 2026-05-12
- Admin role backend каркас (миграция users.is_admin + dependency require_admin + app/admin/router.py + CLI grant_admin + bootstrap первого admin) — контракт C-S8-7 поставлен FRONT2.
- Coverage P0 `notification/dispatchers.py` 0% → 100% (15 тестов).
- Coverage P1 `trading/service.py` 51% → 88% (31 тест).
- Coverage P1 `broker/tinvest/adapter.py` 24% → SKIP до W2 (ждёт BACK2 C-S8-6 MULTIPLEXER-SINGLETON).
- Тесты: 1027 → **1087 passed / 0 failed** (+60). Ruff/mypy чистые. Alembic up/down/up чистый.
- Отчёт: `Sprint_8/reports/DEV-1_W1.md` (9 секций).

### W1 BACK2 (DEV-2) — DONE 2026-05-12
- **8B.1 bandit/safety в CI:** новый job `security-scan` (`.github/workflows/ci.yml`).
  Конфиг `.bandit` + `safety_policy.yml`. 3 medium suppressed `# nosec B102` (intentional
  `exec` в RestrictedPython/Backtrader) + 1 принятый CVE (protobuf транзитив).
- **8B.2 security_audit_s8.md:** 6 секций, verdict 0 critical / 3 high / 7 medium / 2 low.
  High: `S8R-SEC-HEADERS` (missing CSP/HSTS/XFO/XCTO/Referrer/Permissions),
  `S8R-SEC-TELEGRAM-XSS` (no html.escape перед HTML parse_mode),
  `S8R-SEC-EMAIL-XSS` (аналогично). High рекомендован к фиксу в W2.
- **8B.3 multiplexer singleton:** root-cause фикс был реализован в S7 hotfix
  через module-level `_singletons` + `get_or_create_multiplexer` +
  `shutdown_multiplexers` (lifespan teardown в `app/main.py:196-202`). BACK2
  зафиксировал contract через 6 новых тестов `test_multiplexer_singleton.py`
  (same-token=same-id, multi-token=different-id, start-once, shutdown clears
  + stops, swallow errors, recovery after shutdown).
- **8B.4 require_admin smoke:** структурный whitelist-тест
  `test_admin_routes_protection.py` — итерация по `app.routes`, проверка наличия
  `require_admin` в DI-цепочке каждого `/api/v1/admin/*`. 2 теста (routes_exist
  + every_admin_route_protected) → защищает от регрессии при добавлении новых
  admin endpoint'ов (W2 Plotly Dash).
- Тесты: 1087 → **1098 passed / 6 xfailed / 0 failed** (+11 passed +6 xfailed
  contract-тестов для будущего SecurityHeadersMiddleware). Ruff 0 issues, mypy 0
  errors. Bandit 0 medium+, safety 1 documented CVE.
- Отчёт: `Sprint_8/reports/DEV-2_BACK2_W1.md` (9 секций).

### W1 FRONT1 (DEV-3) — DONE 2026-05-12
- **S7R-DRAWING-EDITING** — фактически уже реализован S7-hotfix'ами (hit-test, drag, корнеры, keyboard delete, контекстное меню). W1 закрыл gap: 23 unit-теста на `coords.ts` (math и API conversion), документация поведения.
- **S7R-DRAWING-INTRADAY-COORDS** — реальный фикс рендера: `pointToCoord` теперь детектит sequential-mode через `isSeriesInSequentialMode(series)` и идёт logical-first путём (вместо невалидного `timeToCoordinate(unix)` на индексной оси). `shiftPoint` в sequential mode сохраняет оригинальный `point.t` (не пишет мусор от `synthesizeIsoFromLogical`).
- Файлы: `src/components/charts/primitives/coords.ts` (изменён), `src/components/charts/primitives/__tests__/coords.test.ts` (новый, 23 теста).
- Тесты: `pnpm vitest run` → **503 passed / 2 failed** (2 failed — pre-existing flaky timeouts в `client.test.ts`, baseline сам по себе 484/505 без моих изменений; мои +23 чистого прироста). `pnpm tsc --noEmit` → 0 errors. `pnpm lint` → 0 errors / 9 warnings (baseline для W3 cleanup).
- Cross-DEV: поставщик — нет; потребитель — нет напрямую (косвенно паттерн `sequentialIndex.ts`).
- Stack Gotchas: кандидат `gotcha-24-lightweight-charts-sequential-time-axis.md` (sequential-mode time-axis = индекс, не unix; `timeToCoordinate(unix)` молча возвращает null) — для ARCH-ревью.
- Отчёт: `Sprint_8/reports/DEV-3_FRONT1_W1.md` (9 секций).

**Что сделано в W0 на 2026-05-12:**
- ✅ Preflight checklist пройден (baseline зелёный)
- ✅ Coverage report собран: TOTAL 71%, цель 80%, gap ≈1140 строк
- ✅ 13 event_type аудит — **discrepancy 12 в EVENT_MAP / 13 в UI / 5 «молчаливых» типов**
- ✅ Paginated endpoints аудит: 2 endpoint'а (`/trading/sessions`, `/trading/sessions/{id}/trades`)
- ✅ `arch_design_s8.md` создан (8 секций + 12 разделов = 660+ строк)
- ✅ Все 10 TODO утверждены заказчиком + новый эпик **Admin role + admin panel (W1)**
- ✅ `execution_order.md` обновлён с финальной разбивкой потоков W1/W2/W3 (≈155ч)
- ✅ Cross-DEV contracts таблица — 9 контрактов опубликованы

**Утверждённый scope S8 (W0 → W1):**
- 30 backlog карточек (3 medium-high, ~10 medium, ~10 low)
- 2 новых эпика: **Admin role + admin panel** (W1, ~11ч), **Event type sync** (W2, ~12ч)
- 6 missing E2E (5 Playwright + 1 pytest integration для backup CLI)
- Coverage P0 + P1 + P2 (TOTAL 71% → 80%) с CI gate в W3
- Security audit + `bandit` + `safety` в CI с W1
- Performance: structlog + Plotly Dash `/admin/metrics` (W2, под admin role)
- Deployment guide: Docker compose на Mac mini + launchd + Cloudflare Tunnel SSL (W3)

**Что сделано в подготовке к W1 (2026-05-12, сессия после W0):**
1. ✅ `e2e_test_plan_s8.md` создан (по §5 arch_design — 6 spec'ов с детальными сценариями)
2. ✅ 9 промптов созданы:
   - `prompt_DEV-1.md` (BACK1) — Coverage P0+P1+P2, Admin role backend, Performance instrumentation
   - `prompt_DEV-2.md` (BACK2) — Security audit + bandit/safety, MULTIPLEXER-SINGLETON, Event sync publishers, Dashboard endpoints, Notification market-closed filter
   - `prompt_DEV-3.md` (FRONT1) — Charts editing эпик (DRAWING-EDITING + DRAWING-INTRADAY-COORDS), W3 lint cleanup
   - `prompt_DEV-4.md` (FRONT2) — API paginated audit, ErrorBoundary, Strategy status UI, Dashboard widgets, Admin role frontend, Event sync UI labels, **Plotly Dash /admin/metrics** (перемещён из BACK1)
   - `prompt_DEV-5.md` (OPS) — Docker compose + Mac mini deployment + Cloudflare Tunnel + node-24 + final docs
   - `prompt_QA.md` — 6 missing E2E (5 Playwright + 1 pytest integration) + AIChat mock + регрессия nightly
   - `prompt_UX.md` — W3 финальный юзабилити-тест + ui_checklist_s8.md
   - `prompt_ARCH_design.md` (W0) — уже был создан
   - `prompt_ARCH_review.md` — 8.R финальное ревью по образцу Sprint_6_Review/code_review.md
3. ✅ Обновлён `execution_order.md`: Plotly Dash перемещён из W2 Поток A (BACK1) в W2 Поток C (FRONT2) — по уточнению заказчика
4. ✅ Ветка `s8/sprint-8` создана в Develop репо и запушена на origin
5. ⬜ Заказчик подтверждает старт W1

## Цели спринта (M4)

| # | Цель | Критерий приёмки |
|---|------|------------------|
| 1 | Coverage ≥ 80% | Каждый модуль `app/*` имеет coverage ≥ 80% (unit + integration). Отчёт `pytest-cov`. |
| 2 | Security audit | Crypto/sandbox/CSRF/headers/brute-force — каждый аудит с отчётом, найденные проблемы исправлены. |
| 3 | Performance testing | Дашборд первый paint < 2с; signal→order p95 < 500мс; Telegram-команда < 3с. |
| 4 | E2E регрессия + 6 missing spec'ов | `npx playwright test` зелёный; 6 новых spec'ов покрывают S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17. |
| 5 | Закрытие S8 backlog | ≥ 80% медиум-карточек закрыты. Все medium-high закрыты обязательно. |
| 6 | UX финальный юзабилити-тест | Чеклист `ui_checklist_s7.md` дополнен, найденные UX-баги закрыты или внесены в S9-backlog. |
| 7 | Документация | README актуален, deployment_guide создан, итоговый changelog. |
| 8 | 8.R ARCH-ревью | PASS / PASS WITH NOTES / NEED FIXES вердикт с обоснованием. |

## План волн (предварительный — ARCH уточнит в W0)

| Wave | Фокус | Длительность |
|------|-------|--------------|
| **W0** | ARCH-design: приоритезация backlog, разбивка на DEV-роли, оценка timeline, QA пишет E2E план | 1 день |
| **W1** | Параллельно: coverage gaps (DEV-1), security audit (DEV-2), API-paginated audit + ErrorBoundary (DEV-3), 6 missing E2E (QA) | 3–4 дня |
| **W2** | Параллельно: performance testing (DEV-1), backlog medium (DEV-2 + DEV-3), strategy status UI (FRONT) | 3–4 дня |
| **W3** | Documentation + UX тест + 8.R ARCH-ревью | 2 дня |

## Подготовка к W0

Перед запуском ARCH-агента:

1. ✅ `Sprint_8_Review/backlog.md` — 25+ карточек систематизированы.
2. ✅ `Sprint_8/README.md` создан.
3. ✅ `Sprint_8/preflight_checklist.md` создан.
4. ✅ `Sprint_8/prompt_ARCH_design.md` создан.
5. ⬜ `Sprint_8/arch_design_s8.md` — создаётся ARCH в W0.
6. ⬜ `Sprint_8/prompt_DEV-1..N.md` — создаются после W0 ARCH-design.
7. ⬜ `Sprint_8/prompt_QA.md` — создаётся после W0.
8. ⬜ `Sprint_8/e2e_test_plan_s8.md` — создаётся QA по образцу `Sprint_7/e2e_test_plan_s7.md`.

## Тестовый baseline (на старте S8)

После всех post-S7 волн и финального closeout 2026-05-12:

| Слой | Baseline | Источник |
|------|----------|----------|
| Backend pytest unit | 750 passed / 0 failed | `pytest tests/unit/` |
| Backend pytest всех | ~1019 passed / 0 failed | `pytest tests/` |
| Frontend vitest | 468 passed / 0 failed | `pnpm vitest run` |
| Frontend tsc | 0 errors | `pnpm tsc --noEmit` |
| Backend ruff | 0 issues | `ruff check .` |
| Backend mypy | 0 errors (только notes) | `mypy app/` |
| Playwright nightly | 142 passed (135 базовых + 7 nightly) | `npx playwright test` |
| CI develop | ✅ зелёный | github actions |

## Stack Gotchas (на старте S8)

- Текущий каталог: `Develop/stack_gotchas/INDEX.md` (23 ловушки на конец S7 closeout).
- При выявлении новых в S8 — заводить `gotcha-NN-*.md` + строка в INDEX.

## Ссылки

- Backlog S8 (источник задач): `Спринты/Sprint_8_Review/backlog.md`
- Финальный ARCH-отчёт S7: `Sprint_7/arch_review_s7.md`
- Sprint 7 changelog (для контекста): `Sprint_7/changelog.md`
- Общий статус: `Спринты/project_state.md`
