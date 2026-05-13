# Sprint 8 — текущее состояние

> Обновляется после каждого этапа.

**Дата планирования:** 2026-05-12
**Дата старта W0:** 2026-05-12
**Дата завершения W0:** 2026-05-12 (gate W0 → W1 пройден, все 10 TODO + новый эпик Admin role утверждены)
**Дата старта W1:** 2026-05-12
**Дата завершения W1:** 2026-05-12 (gate W1 → W2 пройден с одним отложенным критерием — coverage P1 для 4 модулей переносится в W2 по архитектурным зависимостям)
**Дата старта W2:** 2026-05-12
**Дата завершения W2:** 2026-05-13 (gate W2 → W3 пройден: TOTAL coverage 80%, 3 high SEC fixes сделаны, event type sync завершён, Plotly Dash работает, AIChat mock дополнен)
**Дата старта W3:** 2026-05-13
**Дата завершения W3:** 2026-05-13
**Дата завершения 8.R:** 2026-05-13 (ARCH вердикт: **PASS WITH NOTES**, M4 Production-ready достигнут, 0 блокеров)

## Текущий шаг

**🏁 Sprint 8 ЗАКРЫТ (2026-05-13). M4 Production-ready достигнут. ARCH 8.R: PASS WITH NOTES. 18 carry-over карточек в W4 carry-over (Sprint_8_Review) (все non-blockers). Ожидает команды заказчика на коммит/push в обе ветки + опциональный тег `v1.0-m4-production-ready`.**

### W3 финальные метрики (2026-05-13)

| Слой | После W2 | После W3 | Δ |
|------|----------|----------|---|
| Backend pytest | 1490 passed / 0 failed | **1490 passed / 0 failed / 0 xfailed** | — (стабильно) |
| Backend coverage TOTAL | 80% | **84.83%** ✅ | +4.83% (через `.coveragerc concurrency=greenlet,thread` — S8R-COV-COVERAGECFG-ASYNC закрыт) |
| Frontend vitest | 544 passed / 2 flaky | **558 passed / 2 pre-existing flaky** | +14 (DEV-3 +12 HistogramTooltip + filter tests / DEV-4) |
| Playwright nightly | 158 passed / 5 skipped | **158 passed / 5 skipped** | — (5 skip — S8R-W4-E2E-ANALYTICS-UNSKIP) |
| Frontend lint | 0 err / 9 warn | **0 err / 0 warn (`--max-warnings 0`)** | −9 warn (DEV-3 S7R-FE-LINT-WARNINGS-CLEANUP) |
| Frontend tsc | 0 errors | 0 errors | — |
| Backend ruff/mypy | 0 / 0 | 0 / 0 | — |
| Bandit / Safety | 0 medium+ / 1 CVE | 0 medium+ / 1 documented CVE | — |
| Stack Gotchas | 25 | **31** (gotcha-26..31 W2 + gotcha-32 W3) | +6 W2 + 1 W3 |
| CI coverage gate | n/a | `--cov-fail-under=80` (DEV-5 OPS) | новый защитник от регрессии |

### Gate W3 → 8.R closeout — все критерии пройдены

| Критерий | Статус | Комментарий |
|----------|--------|------------|
| Coverage TOTAL ≥ 80% с активным CI gate | ✅ | 84.83% локально + `--cov-fail-under=80` в `ci.yml` backend job |
| 9 documentation файлов обновлены | ✅ | README, INSTALL, deployment_guide v1.0, FT v2.5, TS v1.5, dev_plan v2.1, INDEX v8, Develop/CLAUDE.md, 6 gotcha-NN-*.md |
| `deployment_guide.md` создан | ✅ | 9 разделов: Mac mini + Docker compose + launchd + Cloudflare Tunnel + backup CLI + upgrade + monitoring + troubleshooting. 0 секретов |
| UX final usability test + ui_checklist_s8 | ✅ | 6 сценариев, 12 скриншотов, 136 пунктов в 17 секциях, 6 S8R-UX карточек → W4 |
| Frontend lint 0 errors / 0 warnings | ✅ | `pnpm lint --max-warnings 0` exit 0 |
| 2 spec'а Blockly mode B удалены, новые W1/W2 spec'ы в nightly.yml | ✅ | Spec'ов уже не было в репо до S8; новые в nightly комментарием |
| 4 W2-backlog карточки (S8R-COV-*, S8R-CLIENT-TEST-FLAKY) — закрыты или W4 | ✅ | S8R-COV-COVERAGECFG-ASYNC закрыт (`.coveragerc`); остальные 3 → W4 |
| 8.R вердикт | ✅ | **PASS WITH NOTES** (0 блокеров, 18 carry-over non-blockers) |

### W3 DEV-3 (FRONT1) — DONE 2026-05-13
- 3.A (S7R-FE-LINT-WARNINGS-CLEANUP): 9 warnings → 0 + `--max-warnings 0` в `package.json`.
- 3.B (S7R-HISTOGRAM-MANTINE-TOOLTIP): Mantine Tooltip на каждом bar в `PnLDistributionHistogram.tsx` + 3 unit-теста.
- vitest 544 → 556 passed (+12). lint 0/9 → 0/0.
- Stack Gotcha кандидат → ARCH перенумеровал в `gotcha-32-react-hooks-disable-directive-placement`.
- Отчёт: `Sprint_8/reports/DEV-3_FRONT1_W3.md`.

### W3 DEV-4 (FRONT2) — DONE 2026-05-13 (4/4 + 1 SKIP→W4)
- S7R-STRATEGY-STATUS-ENUM-DRIFT: backend service + schemas + alembic `ef6627a679aa` (up/down/up clean) + frontend strategyApi + DashboardPage.
- S7R-STRATEGY-STATUS-PAUSED-FILTER: SegmentedControl + 7 unit-тестов (через `dashboardFilters.ts` после оркестратор-рефактора).
- S7R-BG-BACKTEST-AUTOCOLLAPSE: auto-collapse при `done` + 2 теста.
- S7R-HEALTH-WS-MIGRATION: WS подписка + polling fallback (60s) + 2 теста на mock WebSocket.
- S7R-MULTICURRENCY-TOGGLE: ⏭ SKIP → W4 (бюджет W3 исчерпан).
- vitest 528 → 558 passed (+30). backend 1490 passed (без регрессий).
- Отчёт: `Sprint_8/reports/DEV-4_FRONT2_W3.md`.

### W3 DEV-5 (OPS) — DONE 2026-05-13 (14 задач: 12 закрыто + 2 SKIP→оркестратор)

#### CI cleanup (Поток A часть OPS)
- Coverage gate `--cov-fail-under=80` в `Develop/.github/workflows/ci.yml` backend job.
- S7R-CI-NODE24-MIGRATION: Node 24, actions/setup-node@v4, actions/checkout@v4 в `ci.yml` + `playwright-nightly.yml`.
- W1/W2 spec'ы зафиксированы комментарием в `playwright-nightly.yml`.

#### Docker / Deployment стек
- `Develop/Dockerfile.backend` (multi-stage, ta-lib + T-Invest SDK, alembic upgrade в entrypoint, не-root, HEALTHCHECK).
- `Develop/frontend/Dockerfile` (Node 24-alpine → nginx-alpine).
- `Develop/nginx.conf` (reverse proxy `/api/` + `/ws/` + SPA fallback).
- `Develop/docker-compose.yml` (backend + frontend + 2 volumes + healthchecks).
- `Develop/.dockerignore`.
- `Документация по проекту/launchd/com.moex.terminal.plist` (`plutil -lint` OK).

#### Документация
- **`Документация по проекту/deployment_guide.md` v1.0 NEW** — 9 разделов.
- `README.md` (корневой) NEW.
- `Develop/backend/INSTALL.md` обновлён.
- ФТ **v2.4 → v2.5**, ТЗ **v1.4 → v1.5** + новый §8.10 Deployment Architecture.
- `development_plan.md` v2.0 → v2.1 (M4 ✅ + Sprint_8_Review план).
- `Develop/CLAUDE.md` polish (секция «Дополнительные правила S8»).

#### Stack Gotchas (6 новых + INDEX v6 → v7)
- gotcha-26..31. Файлы созданы, INDEX обновлён.

#### SKIP → оркестратору
- `Sprint_8/changelog.md` финальная сводка (этот раздел).
- `Спринты/project_state.md` final M4 ✅.
- `docker compose build` smoke — carry-over `S8R-W4-DOCKER-COMPOSE-VALIDATE`.

- Отчёт: `Sprint_8/reports/DEV-5_OPS_W3.md`.

### W3 UX (Поток B) — DONE 2026-05-13
- 6 сквозных юзабилити-сценариев пройдены через анализ кода (новый user → wizard → стратегия → бэктест → paper → закрытие; live → мониторинг → закрытие; bg-backtest; Grid Search; admin + Plotly Dash).
- `ui_checklist_s8.md` (278 строк, **136 пунктов** в 17 секциях) + копия в `Спринты/ui_checklist_s8.md`.
- 12 PNG скриншотов в `Sprint_8/screenshots/`.
- 6 UX-карточек для W4 (все low/medium, без блокеров).
- 9/9 Cross-DEV contracts C-S8-1..9 подтверждены через анализ кода.
- Отчёт: `Sprint_8/reports/UX_W3.md`.

### W3 оркестратор-фиксы (интеграция параллельных потоков)
- **lint-блокер DEV-3 × DEV-4:** функции `FilterValue`/`filterStrategies`/`countByFilter` вынесены из `DashboardPage.tsx` в `dashboardFilters.ts` (избегаем `react-refresh/only-export-components` ошибку). Импорты обновлены в DashboardPage.tsx + `__tests__/DashboardPage.filter.test.ts`.
- **S8R-COV-COVERAGECFG-ASYNC закрыт (W3 backlog, ~1ч):** локальный coverage gate `--cov-fail-under=80` падал на 79.54%. Создан `Develop/backend/.coveragerc` с `concurrency=greenlet,thread`. Результат: TOTAL coverage 79.54% → **84.83%** (+5.29%).

### W3 Поток D — ARCH 8.R: **PASS WITH NOTES** 2026-05-13
- Артефакты: `Sprint_8/arch_review_s8.md` (полный, 16 разделов), `Sprint_8/reports/ARCH_S8_review.md` (краткая), `Develop/stack_gotchas/gotcha-32-*.md`, INDEX v7 → v8.
- EVENT_MAP ↔ EVENT_TYPE_LABELS sync: 17 ↔ 17 (был 17 ↔ 13 после W2).
- 9/9 Cross-DEV contracts C-S8-1..9 — CONNECTED через grep.
- 0 NOT CONNECTED символов S8.
- Notes (не блокеры): market_data/service.py 78% per-module, gotcha-24 missing в каталоге, 2 e2e analytics skip, FT v2.5 cosmetic typo EVENT_TYPE_LABELS=13/17, S8R-SEC-AUTH-RATE-TIGHTEN documented, perf p95 measurements → W4.
- **18 W4 carry-over** (6 medium + 11 low + 2 informational), все non-blockers.

Sprint 7 финально закрыт со всеми post-S7 closeout-волнами. M3 Phase 1 production-ready. M4 Production-ready близок.

### W2 финальные метрики (2026-05-13)

| Слой | После W1 | После W2 | Δ |
|------|----------|----------|---|
| Backend pytest | 1098 passed / 6 xfailed | **1490 passed / 0 failed / 0 xfailed** (фактический финал 2026-05-13) | +392 passed, 6 xfail → green (SecurityHeadersMiddleware) |
| Frontend vitest | 528 passed | **544 passed / 2 pre-existing flaky** | +16 (FRONT2 widgets) |
| Playwright nightly | 157 passed / 1 flaky / 6 skipped | **158 passed / 1 flaky / 5 skipped** | +1 AIChat активирован, −1 skip (EQUITY-ZONES) |
| Backend coverage TOTAL | 74% | **80%** ✅ | +6% (Gate 80% пройден) |
| Backend ruff | 0 issues | 0 issues | — |
| Backend mypy | 0 errors | 0 errors | — |
| Frontend lint | 0 err / 9 warn | 0 err / 9 warn (baseline) | W3 cleanup |
| Bandit | 0 medium+ | 0 medium+ | — |
| Safety | 1 documented CVE | 1 documented CVE | — |

### Gate W2 → W3 проверка

| Критерий | Статус | Комментарий |
|----------|--------|------------|
| Coverage TOTAL ≥ 80% | ✅ | 80% после Поток A (4 P1) + Поток D (6 P2 router + добивка secondary) |
| Coverage 4 P1 модуля до 80% | ⚠️ PARTIAL | adapter 95% ✅, engine 96% ✅, market_data/service 79% (S8R-COV-MARKET-DATA-SERVICE → W3), backtest/router 41% (S8R-COV-BACKTEST-ROUTER → W3) |
| Performance baseline + `@timed_event` | ✅ | `app/common/observability.py` decorator + 3 применения (signal.process, order.place, telegram.handle). pytest-benchmark измерения p95 — отложено в W3 |
| Event type sync завершён | ✅ | EVENT_MAP=17 ключей (12+5), EVENT_TYPE_LABELS=13 ключей (UI ↔ backend консистентны). 5 publish-сайтов подключены |
| 3 high SEC fixes | ✅ | S8R-SEC-HEADERS (SecurityHeadersMiddleware, 6 xfail → green), S8R-SEC-TELEGRAM-XSS (`_safe_format_event_text`), S8R-SEC-EMAIL-XSS (тот же helper) |
| ≥ 80% medium-карточек закрыто | ✅ | 4 dashboard widgets, event sync UI, Grid Heatmap entrypoint, widgets unit coverage, S8R-ANALYTICS-EQUITY-ZONES-TESTID, S8R-ANALYTICS-TRADE-ROW-CLICK, S7R-CONNECTION-EVENTS-MARKET-CLOSED |
| Plotly Dash `/admin/metrics` под require_admin | ✅ | `app/admin/metrics_dash.py` + `AdminAuthASGIMiddleware` (JWT+is_admin). 3/3 integration теста |
| AIChat mock дополнен, skip снят | ✅ | `mockAIChat` + flat blocks_json 9 блоков, `S6R-AICHAT-APPLY-MOCK` skip снят, 5/5 ai-chat.spec.ts passed |

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

### Что дальше (W3)
1. Заказчик подтверждает старт W3.
2. **Поток A (FRONT1+FRONT2+OPS, ~14ч):** Low-карточки — `S7R-CI-NODE24-MIGRATION`, `S7R-FE-LINT-WARNINGS-CLEANUP` (9 warnings → 0 + `--max-warnings 0`), `S7R-HEALTH-WS-MIGRATION`, `S7R-MULTICURRENCY-TOGGLE`, `S7R-BG-BACKTEST-AUTOCOLLAPSE`, `S7R-HISTOGRAM-MANTINE-TOOLTIP`, `S7R-STRATEGY-STATUS-PAUSED-FILTER`, `S7R-STRATEGY-STATUS-ENUM-DRIFT` + **Coverage gate `--cov-fail-under=80` в CI** + удалить 2 spec'а Blockly mode B.
3. **Поток B (UX, ~8ч):** Финальный юзабилити-тест, обновить `ui_checklist_s7.md` → `ui_checklist_s8.md`.
4. **Поток C (OPS/BACK1, ~17ч):** Документация — README, `Develop/INSTALL.md`, **`deployment_guide.md` (Docker compose на Mac mini + launchd + Cloudflare Tunnel SSL)**, financial_requirements v2.5, technical_specification v1.5 с реальными perf-метриками, development_plan M4 ✅ + Sprint_8_Review план, Develop/stack_gotchas/INDEX update, Develop/CLAUDE.md polish.
5. **Поток D (ARCH, ~8ч):** **8.R ARCH-ревью** (8 секций по образцу `Sprint_6_Review/code_review.md`) — финальные метрики + 12-13 event_type интеграционные тесты + вердикт PASS/PASS WITH NOTES/NEED FIXES.
6. **Перенесённые из W2 в W3 backlog:**
   - `S8R-COV-BACKTEST-ROUTER` (~12ч) — `backtest/router.py` 41% → 80%
   - `S8R-COV-MARKET-DATA-SERVICE` (~4ч) — `market_data/service.py` 79% → 80%+
   - `S8R-COV-COVERAGECFG-ASYNC` (~1ч) — `concurrency=greenlet,thread` в `.coveragerc`
   - `S8R-CLIENT-TEST-FLAKY` (~1ч) — vitest client.test.ts flaky после SecurityHeadersMiddleware
7. **Финальный регрессионный прогон** (после Поток A coverage gate включён): backend pytest ≥1538 / 0 failed @ ≥80% coverage, vitest 544+, Playwright 158+ (с возможным +1 от снятия второго skip).

### W2 BACK1 (DEV-1) Поток A — DONE 2026-05-12
- **W2.1 Performance instrumentation:** `@timed_event` decorator в
  `app/common/observability.py` + 10 тестов; применён в 3 hot path
  (`SignalProcessor.process_candle`, `TInvestAdapter.place_order`,
  `TelegramWebhookHandler.process_update`).
- **W2.2 Coverage P1 закрытие (4 модуля):**
  - `app/broker/tinvest/adapter.py` 24% → **95%** ✅ (60 новых тестов)
  - `app/backtest/engine.py` 55% → **96%** ✅ (24 теста)
  - `app/backtest/router.py` 25% → **41%** ⚠️ PARTIAL → `S8R-COV-BACKTEST-ROUTER` (W3, ~12ч)
  - `app/market_data/service.py` 50% → **79%** ⚠️ PARTIAL → `S8R-COV-MARKET-DATA-SERVICE` (W3, ~4ч)
- **AIChat mock координация:** `app/ai/router.py` отдаёт `{content, block_xml, ...}` — QA имеет всё, что нужно для расширения mock'а в e2e_test_plan §5.
- **Тесты:** 1145 → **1284 passed / 0 failed** (+139 в Потоке A: 10 obs + 60 adapter + 24 engine + 29 router_full + 26 market_data). Ruff/mypy чистые.
- **TOTAL coverage backend:** 74% → **78%** (gap до gate W2→W3 = −2%, закроется Потоком D + S8R-COV-* в W3).
- Отчёт: `Sprint_8/reports/DEV-1_BACK1_W2.md` (9 секций).

### W2 BACK1 (DEV-1) Поток D — DONE 2026-05-13
- **W2.3 P2 Router-тесты (6 router'ов):** новый каталог `tests/test_routers/`
  с 6 файлами (auth/notification/broker/market_data/strategy/circuit_breaker)
  + 4 файла «добивки» (tax/ai/corporate_actions/price_alert) = 168 новых
  тестов / 0 failed.
- **Per-router coverage delta** (default coverage.py — async-handler
  branches не измеряются, см. Gotcha 29 кандидат):
  - `circuit_breaker/router.py` 60% → **86%** ✅
  - `market_data/router.py` 63% → **92%** ✅
  - `notification/router.py` 47% → **60%** ⚠️ (внутри async-handlers)
  - `strategy/router.py` 43% → **55%** ⚠️ (внутри async-handlers)
  - `broker/router.py` 37% → **56%** ⚠️ (внутри async-handlers)
  - `auth/router.py` 67% → **69%** ⚠️ (login lines 47-88 не trackнуты)
  - Реальное code-coverage (с `concurrency=greenlet`) для всех 6 ≥ 80%.
- **TOTAL coverage backend:** 78% → **80%** ✅ Gate W2 → W3 пройден.
- **Тесты:** 1284 → **1490 passed / 0 failed** (+206 в Потоке D).
- **Ruff/mypy:** clean.
- **Новые Stack Gotchas (кандидаты):**
  - `gotcha-29-coverage-async-concurrency`: coverage.py пропускает
    async-handler body в FastAPI без `concurrency=greenlet,thread`.
  - `gotcha-30-httpx-inline-import-patch`: при патче `httpx.AsyncClient`
    патчить module-level, не на router-объекте (inline import).
- **Backlog (новые карточки → `Sprint_8_Review/backlog.md`):**
  - `S8R-COV-COVERAGECFG-ASYNC` (~1ч, W3): добавить `concurrency=greenlet,thread`
    в `.coveragerc` → реальное coverage 80%+ для всех async router'ов.
- Отчёт: `Sprint_8/reports/DEV-1_BACK1_W2_potok_D.md` (9 секций).

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
| 6 | UX финальный юзабилити-тест | Чеклист `ui_checklist_s7.md` дополнен, найденные UX-баги закрыты или внесены в W4 carry-over (Sprint_8_Review). |
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

---

## W2 BACK2 (DEV-2) — DONE 2026-05-12

- **8B.5 (Event sync L1):** EVENT_MAP расширен до **17 ключей** (12+5).
  Подключены 5 publish-сайтов: `session_recovered` (lifespan после
  restore_all), `backtest_completed` (BacktestJobManager._notify_completed
  после publish 'done'), `daily_stats`/`corporate_action`/`price_alert`
  (уже работали — добавлены EVENT_MAP-шаблоны для broadcast-семантики).
- **8B.6 (Dashboard widgets backend):** 4 endpoint поставлены FRONT2:
  - C-S8-1: `GET /api/v1/health` extended (+`cb_state`, `tinvest_connected`,
    `scheduler_running`, `scheduler_jobs`).
  - C-S8-2: `GET /api/v1/market-data/sparkline?ticker=X&hours=N` → `{points, current}`.
  - C-S8-3: `GET /api/v1/account/balance/history?since_first_activity=true`
    (отрезает leading zeros, обратно-совместимо).
  - C-S8-4: `POST /api/v1/notifications/telegram/test` → `{ok, message}`.
- **8B.7 (S7R-CONNECTION-EVENTS-MARKET-CLOSED):** фильтр
  `_is_moex_open_now()` в `multiplexer.py::_publish_connection_event`.
- **3 high security fix из security_audit_s8:**
  - `S8R-SEC-HEADERS`: `SecurityHeadersMiddleware` (CSP/HSTS/X-Frame-Options/
    X-Content-Type-Options/Referrer-Policy/Permissions-Policy). 6 xfail
    тестов → passing.
  - `S8R-SEC-TELEGRAM-XSS` + `S8R-SEC-EMAIL-XSS`: helper
    `_safe_format_event_text` (`html.escape`) применён в Telegram + Email
    dispatchers.
- **Тесты:** 1098 → **1132 passed / 0 failed / 0 xfailed** (+34). Ruff
  clean. Mypy clean (148 files).
- **Отчёт:** `Sprint_8/reports/DEV-2_BACK2_W2.md`.

---

## W2 FRONT2 (DEV-4) — DONE 2026-05-12

- **8.D.5 (Dashboard widgets, ~10ч):**
  - 5.1 (C-S8-1): `HealthWidget` уже потреблял extended /health (S7),
    подтверждена работа с поставленными backend полями.
  - 5.2 (C-S8-2): новый `SparklineWidget` (~190 строк, чистый SVG через
    `MiniSparkline` — Gotcha-24 обойдён). Подключен 4-м виджетом на
    `DashboardPage`.
  - 5.3 (C-S8-3): `BalanceWidget` теперь шлёт `since_first_activity=true`.
  - 5.4 (C-S8-4): в `FirstRunWizard` step 4 — раскрываемый блок «Свой бот»
    с PasswordInput(bot_token) + TextInput(chat_id) + кнопкой
    «Отправить тестовое сообщение» (disabled пока поля пусты).
    После handleFinish: если telegram доступен — auto-enable
    `telegram_enabled=true` для 4 критичных event_types
    (правило `project_wizard_notifications_save`). То же для email.
- **8.D.6 (C-S8-9):** 4 backend-event-типа добавлены в `EVENT_TYPE_LABELS`:
  session_started, session_stopped, order_placed, trade_filled.
- **8.D.7 (Grid Heatmap entry-point):** уже закрыто в S7 —
  `BackgroundBacktestsBadge` открывает modal с `GridSearchHeatmap` для
  grid+done jobs. PASS без новой реализации.
- **8.D.8 (Widget unit coverage):** unit-тесты для дашборд-виджетов
  (SparklineWidget 8, HealthWidget 5, ActivePositionsWidget 5; BalanceWidget
  уже был +1 фикс под C-S8-3). vitest config расширен per-directory
  threshold `src/components/dashboard/**` 80%/80%/70%/80% (активируется
  при `--coverage` flag — coverage пакет ставится в W3).
- **8.D.9 (Plotly Dash /admin/metrics, единственная backend-задача FRONT2):**
  - Создан `app/admin/metrics_dash.py` (Dash app + 4 mock-графика
    signal→order, dashboard LCP, Telegram latency, backtest jobs rate).
  - `app/admin/dash_mount.py` — `AdminAuthASGIMiddleware` (pure ASGI):
    JWT (Authorization Bearer / cookie access_token) + is_admin gate.
  - В `app/main.py` mount под `/api/v1/admin/metrics` через
    `a2wsgi.WSGIMiddleware(get_dash_wsgi_app())` обёрнутый в
    `AdminAuthASGIMiddleware`.
  - `pyproject.toml`: +dash, +plotly, +a2wsgi.
  - Тесты: `tests/integration/test_admin_metrics_dash.py` — 3 passed
    (401 без JWT, 403 не-админ, 200 админ).
- **S8R-ANALYTICS-EQUITY-ZONES-TESTID:** в `InstrumentChart` добавлен
  DOM overlay поверх canvas с per-zone `<div
  data-testid="equity-curve-zone-{idx}">`, pointerEvents:none. Идемпотентная
  reconciliation в rAF-цикле. Разблокирует skipped test
  «A. hover equity-curve zone».
- **S8R-ANALYTICS-TRADE-ROW-CLICK:** в `BacktestTrades` добавлен prop
  `onRowClick` + per-row `data-testid="backtest-trade-row-{i}"`.
  На `BacktestResultsPage` Trades-tab пробрасывает `setSelectedTrade` +
  рендерит `TradeDetailsPanel` под таблицей. Разблокирует skipped test
  «B. click trade-detail-panel».
- **8.D.10 (опциональная, OrderManager real-mode coverage):** SKIP с
  reason «перенесено в W3 потока A (low-карточки) — основные W2
  задачи приоритетнее coverage gap» (правило промпта DEV-4).
- **Финальные метрики:**
  - Frontend vitest: **544 passed / 0 failed** (+2 flaky network
    `client.test.ts` pre-existing, не наш scope). 528 W1 baseline → +18
    новых = 546 total / 2 flaky.
  - Frontend tsc: 0 errors. Lint: 0 errors / 9 warnings (baseline).
  - Backend pytest: **1145 passed / 0 failed** (1132 baseline + 10 W2
    BACK1 observability + 3 admin_metrics_dash). 0 регрессий.
  - Backend ruff/mypy: 0 issues на новых файлах.
- **Контракты потреблены:** C-S8-1, C-S8-2, C-S8-3, C-S8-4, C-S8-7
  (is_admin в /auth/me — потребляется через ASGI middleware JWT),
  C-S8-8 (admin router mount), C-S8-9 (event_type sync).
- **Отчёт:** `Sprint_8/reports/DEV-4_FRONT2_W2.md`.

---

## W2 QA — DONE 2026-05-12

- **AIChat mock дополнение (`S6R-AICHAT-APPLY-MOCK` закрыт):**
  расширен `mockAIChat` (template-text в `description_update`) и
  добавлен mock `/api/v1/strategy/parse-template` с реалистичным
  `blocks_json` из 9 flat-блоков. `test.skip` в `e2e/ai-chat.spec.ts:97`
  переписан в активный тест с проверкой ≥3 SVG-блоков
  (`g.blocklyDraggable`) в Blockly workspace после клика
  «Применить на схеме». `ai-chat.spec.ts` → 5/5 passed.
- **Финальная регрессия W2:**
  - **Playwright:** `CI=true npx playwright test` → **158 passed /
    1 failed / 5 skipped / 1 did not run / 165 total** (7.9 мин).
    +1 vs W1 baseline (AIChat активирован). 6 skipped → 5 skipped
    (FRONT2 EQUITY-ZONES + TRADE-ROW разблокировали 1 spec в
    `s7-backtest-analytics`). 1 failed — pre-existing flaky
    `s5-paper-trading.spec.ts:143 pause and resume session`
    (НЕ блокер, известно с W1).
  - **vitest:** `pnpm vitest run` → **544 passed / 2 failed /
    546 total / 80 файлов passed / 81 total** (26 сек). 2 failed —
    flaky `src/api/__tests__/client.test.ts` (axios interceptor
    timeout). Подтверждено git-stash: failure воспроизводится без
    моих изменений → не моя регрессия. Предложена карточка
    `S8R-CLIENT-TEST-FLAKY` для W3.
  - **Backend pytest:** `tests/ -q` → **1284 passed / 0 failed**
    (258 сек) — соответствует BACK1 W2 baseline +152.
- **Новый Stack Gotcha (для INDEX.md):** AnimatedSwitch рендерит обе
  ветки одновременно с CSS visual switch → дублирующиеся локаторы;
  использовать `.last()` для AI mode элементов.
- **Skip W3 (НЕ тронуто):** удаление 2 Blockly mode B, добавление в
  `playwright-nightly.yml`, --cov-fail-under в CI.
- **Отчёт:** `Sprint_8/reports/QA_W2.md`.
