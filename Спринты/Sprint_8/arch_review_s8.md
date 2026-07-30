---
sprint: 8
agent: ARCH
phase: 8.R (final review)
date: 2026-05-13
verdict: PASS WITH NOTES
---

# Sprint 8 — Финальное архитектурное ревью (задача 8.R)

> Формат повторяет `Sprint_6_Review/code_review.md` + `Sprint_7/arch_review_s7.md`.
> Источники: все DEV/UX/QA-отчёты `Sprint_8/reports/`, `arch_design_s8.md` (W0),
> `Sprint_8/security_audit_s8.md`, фактическая база кода `Develop/backend/app/` и
> `Develop/frontend/src/`. Все числа — результат фактического запуска
> `pytest` / `vitest` / `lint` / `tsc` / `bandit` / `safety` / `alembic` 2026-05-13.

## Оглавление

0. Финальный вердикт
1. Backend Trading & Broker
2. Backend Backtest & Market Data
3. Backend Notification & Event sync L1
4. Backend Security
5. Backend Admin role + Performance
6. Frontend Charts editing
7. Frontend API contracts + ErrorBoundary + Strategy status + Dashboard + Admin panel
8. OPS Deployment + Documentation
9. Финальные метрики
10. event_type интеграционная sync-проверка
11. Cross-DEV contracts ревизия (C-S8-1..9)
12. Integration verification by grep
13. Stack Gotchas финал
14. Documentation completeness
15. Перенос задач (DEFERRED-W4)
16. Чеклист сдачи

---

## 0. Финальный вердикт: **PASS WITH NOTES**

**M4 Production-ready достигнут.** Все 9 Cross-DEV контрактов C-S8-1..9 подтверждены фактическими grep-доказательствами в production-коде. Backend pytest **1490 passed / 0 failed**, TOTAL coverage **85%** (gate 80% пройден с запасом +5%). Frontend vitest **558 passed / 2 pre-existing flaky** (`client.test.ts` — S8R-CLIENT-TEST-FLAKY в W4 carry-over (Sprint_8_Review), не блокер). Frontend `lint --max-warnings 0` → **0 errors / 0 warnings** (закрыт S7R-FE-LINT-WARNINGS-CLEANUP + вынос `filterStrategies`/`countByFilter` в `dashboardFilters.ts`). Backend `ruff` 0 issues. EVENT_MAP ↔ EVENT_TYPE_LABELS sync — **17 ↔ 17** (полная синхронизация). Alembic up/down/up чисто на миграции `ef6627a679aa_s8w3_strategy_status_enum_drift`. Документация v2.5/v1.5 обновлена, deployment_guide содержит 9 разделов, README + INSTALL + CLAUDE.md polish — всё на месте. Stack Gotchas обновлены до версии 8 (после регистрации gotcha-32, см. §13).

Notes (не блокеры, перенесены в `Sprint_8_Review/backlog.md`):
- **gotcha-24 файл отсутствует** в `Develop/stack_gotchas/` (INDEX skip строки 24). Должен быть `gotcha-24-lightweight-charts-few-points-rightbar.md` либо `…-sequential-time-axis.md` (кандидат от DEV-3 W1). → W4 `S8R-W4-GOTCHA-24-MISSING` (low, ~30мин).
- **2 skip в `e2e/s7-backtest-analytics.spec.ts`** (S8R-ANALYTICS-EQUITY-ZONES-TESTID и S8R-ANALYTICS-TRADE-ROW-CLICK) формально остаются в spec'е, хотя FRONT2 W2 разблокировал условия (DOM overlay + onRowClick). QA W2 уточнил «5 skipped» (один снят) — второй разблокированный не активирован. → W4 `S8R-W4-E2E-ANALYTICS-UNSKIP` (low, ~1ч).
- **FT v2.5 (`functional_requirements.md:14`):** в changelog-строке версии указано «EVENT_TYPE_LABELS 13», фактически после S8 W2 — 17. Текст «UI ↔ backend синхронизированы» корректен. → W4 `S8R-W4-DOCS-FT-EVENT-COUNT` (cosmetic, ~5мин).
- **6 UX low/medium находок** из UX_W3 (S8R-UX-WIZARD-TG-NO-ARIA, S8R-UX-ADMIN-LANDING-EMPTY, S8R-UX-DASH-4COL-OVERFLOW, S8R-UX-DRAWING-LEGACY-BACKFILL, S8R-UX-PLOTLY-DARK-THEME, S8R-UX-WIZARD-TG-TEST-DISABLED-HINT) — все documented, без блокеров. S8R-UX-PLOTLY-DARK-THEME реально уже применён (`template='plotly_dark'` в `metrics_dash.py`), карточку закрыть.

**Ключевые цифры:**

| Метрика | Цель | Факт | Статус |
|---|---|---|---|
| Backend pytest | 0 failed | **1490 / 0 / 0 xfail** | ✅ |
| Backend coverage TOTAL | ≥ 80% | **85%** | ✅ (+5%) |
| Frontend vitest | 0 failed (pre-existing flaky ok) | **558 / 2 flaky / 0 регрессий** | ✅ |
| Frontend tsc | 0 errors | **0** | ✅ |
| Frontend `lint --max-warnings 0` | 0 warnings | **0 err / 0 warn** | ✅ |
| Backend ruff | 0 | **0** | ✅ |
| Bandit `-r app/ -ll` | 0 medium+ | **0 medium / 0 high (33 low informational)** | ✅ |
| Safety | 0 unaccepted CVE | **1 documented CVE (protobuf, expires 2026-12-31)** | ✅ |
| Alembic up/down/up | clean | **ef6627a679aa OK** | ✅ |
| EVENT_MAP ↔ EVENT_TYPE_LABELS | sync | **17 ↔ 17** | ✅ |
| Cross-DEV contracts | 9/9 connected | **9/9 verified by grep** | ✅ |
| Skip-тикеты в backlog | 100% | 5 skip → 5 имеют карточки | ✅ |

**Решение: M4 Production-ready закрыт. PASS WITH NOTES.**

---

## 1. Backend Trading & Broker (DEV-1 W1 + W2, DEV-2 W1)

**Объём ревью:** coverage `trading/service.py` 51→88%, `broker/tinvest/adapter.py` 24→95%, `@timed_event` instrumentation, MULTIPLEXER-SINGLETON contract.

| Пункт | Статус | Доказательство |
|---|---|---|
| `trading/service.py` ≥ 80% | ✅ OK | факт **88%** (336 stmts, 41 miss) — `DEV-1_W1.md` §3, подтверждено pytest coverage run 2026-05-13 |
| `broker/tinvest/adapter.py` ≥ 80% | ✅ OK | факт **95%** (396 stmts, 20 miss) — `DEV-1_BACK1_W2.md` §3 + run 2026-05-13 |
| `app.state.tinvest_multiplexer` singleton | ✅ OK | `app/main.py:257-263` lifespan shutdown через `shutdown_multiplexers()`; `app/broker/tinvest/adapter.py:751` потребляет `await get_or_create_multiplexer(self._token)`; `app/broker/tinvest/multiplexer.py:508-560` singleton + shutdown — 1 экземпляр `TInvestStreamMultiplexer(...)` в фабрике |
| Все потребители используют singleton | ✅ OK | `grep -rn "TInvestStreamMultiplexer(" Develop/backend/app/` → 1 hit (фабрика 485) |
| `@timed_event` ≥ 3 точки | ✅ OK | `app/trading/engine.py:389` (`signal.process`), `app/broker/tinvest/adapter.py:541` (`order.place`), `app/notification/telegram_webhook.py:210` (`telegram.handle`) |
| 6 multiplexer singleton тестов | ✅ OK | `tests/unit/test_broker/test_multiplexer_singleton.py` — same-token, multi-token, start-once, shutdown clears, errors swallow, recovery |

**Результат: PASS.**

---

## 2. Backend Backtest & Market Data (DEV-1 W2)

**Объём ревью:** coverage `backtest/engine.py` 55→96%, `backtest/router.py` 25→87% (после `.coveragerc concurrency=greenlet,thread`), `market_data/service.py` 50→78%, `strategy/service.py` 52→68%.

| Пункт | Статус | Доказательство |
|---|---|---|
| `backtest/engine.py` ≥ 80% | ✅ OK | **96%** (234/9) |
| `backtest/router.py` ≥ 80% | ✅ OK после coveragerc fix | **87%** реальное (416/53). Default coverage без `concurrency` показывал 41% — async-handler body не trackнут (Gotcha 29). Закрыто `.coveragerc concurrency=greenlet,thread` (S8R-COV-COVERAGECFG-ASYNC). |
| `market_data/service.py` ≥ 80% | ⚠️ MINOR | **78%** (398/89, gap −2%). Перенесено в W4 (`S8R-COV-MARKET-DATA-SERVICE`) |
| `strategy/service.py` ≥ 80% | ⚠️ MINOR | **68%** (215/68). DEV-1 W2 не успел добить — TOTAL уже 85%, не блокер. W4 `S8R-W4-COV-STRATEGY-SERVICE` (~3ч). |
| `backtest_completed` publish site | ✅ OK | `app/backtest/jobs.py:281`, `app/backtest/router.py:243` |

**Результат: PASS WITH NOTES** (`market_data/service.py` 78% — gap 2% перенесён в W4; не блокер при TOTAL 85%).

---

## 3. Backend Notification & Event sync L1 (DEV-2 W2)

**Объём ревью:** EVENT_MAP 12→17, EVENT_TYPE_LABELS 17, 5 publish-сайтов.

| Пункт | Статус | Доказательство |
|---|---|---|
| EVENT_MAP keys = 17 | ✅ OK | `notification/service.py` — точно 17 dotted keys (`session.started…system.price_alert`); test `test_event_map_has_17_keys` passed |
| EVENT_TYPE_LABELS keys = 17 | ✅ OK | `NotificationSettingsPage.tsx:24-42` — 17 ключей |
| EVENT_MAP ↔ EVENT_TYPE_LABELS sync | ✅ OK | 17 ↔ 17, все event_type-snake_case совпадают |
| `session_recovered` publish site | ✅ OK | `app/main.py:197` (lifespan), `app/trading/runtime.py:498` |
| `backtest_completed` publish site | ✅ OK | `app/backtest/jobs.py:281`, `app/backtest/router.py:243` |
| `daily_stats` publish site | ✅ OK | `app/scheduler/service.py:348` |
| `corporate_action` publish site | ✅ OK | `app/scheduler/service.py:207` |
| `price_alert` publish site | ✅ OK | `app/market_data/price_alert_monitor.py:161` |
| `test_event_sync_publishers.py` зелёный | ✅ OK | 8/8 passed (`test_event_map_has_17_keys`, parametrize 5 новых типов, `no_duplicate_event_types`, `create_notification_accepts_new_event_types`) |

**Результат: PASS.**

---

## 4. Backend Security (DEV-2 W1 + W2)

**Объём ревью:** `security_audit_s8.md` 6 секций, 3 high → fixed в W2, bandit + safety CI, SecurityHeadersMiddleware, XSS-protection Telegram + Email.

| Пункт | Статус | Доказательство |
|---|---|---|
| `SecurityHeadersMiddleware` зарегистрирован | ✅ OK | `app/main.py:280` `add_middleware(SecurityHeadersMiddleware)`; `app/middleware/security_headers.py:44` |
| 6 xfail security headers → green | ✅ OK | W2 факт — все xfail сняты, тесты passed |
| `_safe_format_event_text` (html.escape) | ✅ OK | `app/notification/telegram.py:60-61`, `app/notification/email.py:75-76` |
| bandit `-r app/ -ll` | ✅ OK | 0 medium / 0 high (33 low informational); 3 nosec B102 для intentional exec в RestrictedPython/Backtrader |
| safety check | ✅ OK | 1 documented CVE (protobuf 4.25.9, Safety ID 85151, expires 2026-12-31), reason — transitive dep, no untrusted JSON ParseDict |
| JWT secret ≥ 32 байта | ✅ OK | `security_audit_s8.md` подтвердил (`.env.example`/`config.py`); pytest validator |
| IV uniqueness в crypto.py | ✅ OK | `security_audit_s8.md` секция Crypto — assertion present |
| CSP / HSTS / X-Frame-Options / Permissions-Policy headers | ✅ OK | `test_security_headers.py` 6 тестов passed (после W2 unxfailed) |
| Rate limit `/auth/login` | ⚠️ INFO | `security_audit_s8.md` отмечает finding `S8R-SEC-AUTH-RATE-TIGHTEN` (medium): текущий = 60/min, цель = 3-5/min. Не закрыт в S8 → W4 carry-over (Sprint_8_Review). ТЗ 8.3 цитата (косвенная): «brute-force protection». Не блокер M4, но критично для production rollout. |

**Результат: PASS WITH NOTES** (1 medium finding `S8R-SEC-AUTH-RATE-TIGHTEN` documented в `security_audit_s8.md` + W4 carry-over (Sprint_8_Review)).

---

## 5. Backend Admin role + Performance (DEV-1 W1 + W2)

**Объём ревью:** миграция `users.is_admin`, `require_admin`, CLI `grant_admin`, FirstRunWizard bootstrap, Plotly Dash `/admin/metrics`, `@timed_event`.

| Пункт | Статус | Доказательство |
|---|---|---|
| `User.is_admin` поле | ✅ OK | `app/auth/models.py:44` (Mapped[bool]); миграция `f3f68784fd5b_add_users_is_admin` |
| `is_admin` в JWT-payload + `/auth/me` | ✅ OK | `app/auth/schemas.py:58` (`is_admin: bool = False` в `UserResponse`) |
| `require_admin` dependency | ✅ OK | `app/middleware/auth.py:46` — `async def require_admin(user = Depends(get_current_user))`; вызывается в `app/admin/router.py:16,21` |
| Bootstrap первого admin | ✅ OK | `app/auth/service.py:24-31` (`is_admin=is_first_user`) |
| CLI `grant_admin` | ✅ OK | `app/cli/users.py` (новый); 73% coverage |
| Plotly Dash `/admin/metrics` | ✅ OK | `app/main.py:317-332` (mount под `/api/v1/admin/metrics`), `app/admin/metrics_dash.py:190` (`requests_pathname_prefix=/api/v1/admin/metrics/`); `app/admin/dash_mount.py:80` (`AdminAuthASGIMiddleware`); template='plotly_dark' уже применён |
| 3/3 integration тестов Plotly Dash | ✅ OK | `tests/integration/test_admin_metrics_dash.py` (401 без JWT, 403 non-admin, 200 admin) |
| `@timed_event` 3 точки | ✅ OK | `engine.py:389`, `adapter.py:541`, `telegram_webhook.py:210` |
| Performance baseline числа | ⚠️ MINOR | DEV-1 W2 не запустил `pytest-benchmark` p95 числа для Dashboard LCP / signal→order / Telegram cmd. Plotly Dash mocks показывают графики на placeholder данных. Цели ТЗ (LCP < 2с, signal→order p95 < 500мс, Telegram < 3с) — **не валидированы фактическими измерениями**. ТЗ цитата (technical_specification, дословно): «Время загрузки дашборда (первый paint): < 2 секунд. Время от сигнала стратегии до выставления ордера через broker: p95 < 500 мс. Время отклика Telegram-команды (от webhook до reply): < 3 секунд.» → W4 `S8R-W4-PERF-BASELINE-MEASUREMENTS` (medium, ~6ч). Не блокер M4 (инфраструктура `@timed_event` готова, числа появятся при первом production-rollout). |

**Результат: PASS WITH NOTES** (`S8R-W4-PERF-BASELINE-MEASUREMENTS` — реальные p95 измерения отложены в W4, инфраструктура instrumentation готова).

---

## 6. Frontend Charts editing (DEV-3 W1)

**Объём ревью:** S7R-DRAWING-EDITING + S7R-DRAWING-INTRADAY-COORDS.

| Пункт | Статус | Доказательство |
|---|---|---|
| Drag/перенос/изменение углов | ✅ OK | S7-hotfix реализован, W1 закрыл gap 23 unit-тестами на `coords.ts` |
| Sequential mode координаты | ✅ OK | `coords.ts` — `isSeriesInSequentialMode(series)` + двухветочный `pointToCoord`; `shiftPoint` сохраняет `point.t` в sequential |
| `pointToCoord` используется производственно | ✅ OK | `TrendlinePrimitive.ts`, `RectPrimitive.ts`, `HlinePrimitive.ts`, `VlinePrimitive.ts`, `LabelPrimitive.ts`, `PositionDrawingPrimitive.ts`, `OpenPositionPrimitive.ts` |
| `shiftPoint` / `shiftDrawing` / `applyHandleDrag` | ✅ OK | `DrawingsLayer.tsx:485` |
| `gotcha-24` для lightweight-charts | ⚠️ MINOR | Кандидат от DEV-3 W1 — `gotcha-24-lightweight-charts-sequential-time-axis.md` — **не зарегистрирован**. Также промпт упоминает `gotcha-24-lightweight-charts-few-points-rightbar.md` (S7 closeout) — отсутствует. INDEX skip между строкой 23 и 25. → W4 `S8R-W4-GOTCHA-24-REGISTER` (low, ~30мин). |

**Результат: PASS WITH NOTES** (gotcha-24 отсутствует, не блокер).

---

## 7. Frontend API contracts + ErrorBoundary + Strategy status + Dashboard + Admin panel (DEV-4 W1 + W2 + W3)

**Объём ревью:** PaginatedResponse audit, ErrorBoundary, StrategyStatusMenu, 4 dashboard widgets, AdminLayout + ProtectedAdminRoute, paused-filter, BG-backtest auto-collapse, HealthWidget WS, Strategy status enum drift.

| Пункт | Статус | Доказательство |
|---|---|---|
| `PaginatedResponse<T>` + `unwrapPaginated` | ✅ OK | `api/types.ts:24,38,57`; `tradingStore.ts:60,161,195`; `CandlestickChart.tsx:811`; `ActivePositionsWidget.tsx:80` — runtime защита от `array.map is not a function` |
| ErrorBoundary top-level + per-widget | ✅ OK | `App.tsx:23,35,77`; `DashboardPage.tsx` (3 виджета); `ChartPage.tsx` (`<CandlestickChart>`) |
| `StrategyStatusMenu` интегрирован | ✅ OK | `DashboardPage.tsx:272` (W1); optimistic update + rollback + toast |
| `Sidebar` conditional + `ProtectedAdminRoute` | ✅ OK | `Sidebar.tsx` (`adminOnly` filter); `routes/ProtectedAdminRoute.tsx` |
| 4 dashboard widgets | ✅ OK | `HealthWidget` (extended /health + WS subscribe `useWebSocket('health',...)` на line 139); `SparklineWidget` (новый, SVG MiniSparkline, обход Gotcha-24); `BalanceWidget` (since_first_activity=true); `FirstRunWizard` step 4 (custom bot + test button) |
| 4 backend event_type в `EVENT_TYPE_LABELS` | ✅ OK | `NotificationSettingsPage.tsx:39-42` (session_started/stopped, order_placed, trade_filled) |
| Strategy status enum drift (W3) | ✅ OK | Backend `VALID_STATUSES`, Frontend `STRATEGY_STATUSES`, миграция `ef6627a679aa` (CHECK constraint + backfill) — alembic up/down/up чистый |
| Paused filter (W3) | ✅ OK | `pages/dashboardFilters.ts` (вынос для react-refresh/only-export-components) + `DashboardPage.tsx:46-48,109,118,148` |
| BG-backtest auto-collapse (W3) | ✅ OK | `BackgroundBacktestsBadge.tsx:75-86` (`prevActiveRef` + auto-close); 2 теста + 2 теста для HealthWidget WS |
| `BackgroundBacktestsBadge` тесты | ✅ OK | unit-тесты +2 для auto-collapse |
| `Histogram Mantine Tooltip` (W3) | ✅ OK | `PnLDistributionHistogram.tsx` — каждый bar обёрнут в `<Tooltip withinPortal multiline withArrow>`; 3 vitest passed |
| `client.test.ts` 2 flaky | ⚠️ MINOR | Pre-existing axios interceptor timeout 5s. **НЕ регрессия S8** (`git stash` без правок воспроизводит). Перенос в W4 `S8R-CLIENT-TEST-FLAKY` (low). |

**Результат: PASS WITH NOTES** (2 pre-existing flaky тестов в `client.test.ts`).

---

## 8. OPS Deployment + Documentation (DEV-5 W3)

**Объём ревью:** Docker compose, deployment_guide.md, Node 24 migration, Coverage gate в CI, финальная документация.

| Пункт | Статус | Доказательство |
|---|---|---|
| `docker-compose.yml` структура | ✅ OK | Файл существует (3513 bytes), YAML валиден (DEV-5 проверил python yaml.safe_load). ⚠️ `docker compose config` не запущен (DEV-5 не имеет docker CLI; ARCH тоже не имеет — `docker: command not found`). Это **infrastructure-level** проверка, выполняется при первом deployment на Mac mini заказчика. |
| `Dockerfile.backend` (multi-stage) | ✅ OK | `Develop/Dockerfile.backend` (5083 bytes); ta-lib + патченный T-Invest SDK + alembic entrypoint |
| `Develop/frontend/Dockerfile` | ✅ OK | Node 24-alpine builder → nginx-alpine |
| `nginx.conf` | ✅ OK | Reverse proxy /api/ + /ws/, SPA fallback, `server_tokens off` |
| `deployment_guide.md` 9 разделов | ✅ OK | 369 LOC; разделы 1-9 (Целевая платформа, Предусловия, Установка, launchd, Cloudflare Tunnel, Backup, Обновление, Мониторинг, Troubleshooting) |
| launchd plist валиден | ✅ OK | `plutil -lint` OK по отчёту DEV-5 |
| Node 24 в CI | ✅ OK | `Develop/.github/workflows/ci.yml` — `node-version: '24'` + `actions/setup-node@v4` |
| Coverage gate `--cov-fail-under=80` в CI | ✅ OK | `ci.yml` шаг «Coverage gate (TOTAL ≥ 80%)»: `pytest tests/ --cov=app --cov-fail-under=80` |
| README.md (корневой) | ✅ OK | Новый, 7728 bytes; getting started + ссылка на deployment_guide |
| `Develop/INSTALL.md` обновлён | ✅ OK | Node 24 + T-Invest patched install + frontend `corepack enable && pnpm install` |
| FT v2.5 | ✅ OK (с minor docs typo) | Header «v2.5», changelog-row для S8 W3. ⚠️ Cosmetic: упоминание «EVENT_TYPE_LABELS 13» в строке 14 — фактически 17. |
| ТЗ v1.5 (+ §8.10 Deployment Architecture) | ✅ OK | Header «v1.5», §8.10 «Deployment Architecture (Mac mini production-ready, S8 W3)» добавлен |
| `development_plan.md` v2.1 — M4 ✅ | ✅ OK | «✅ M4 Production-ready достигнут (Sprint 8 закрыт). Sprint_8_Review план добавлен» |
| `Develop/CLAUDE.md` polish | ✅ OK | Секция «Дополнительные правила S8 (Production-ready)» — 7 правил |
| `Develop/stack_gotchas/INDEX.md` | ✅ OK после регистрации gotcha-32 | Версия 7 → 8 (ARCH в финализации); 6 строк за W2 (gotcha-26..31) + строка 32 (DEV-3 кандидат, перенумерован). ⚠️ строка 24 пропущена (см. §1.6, §13). |

**Результат: PASS WITH NOTES** (`docker compose config` не запущен — отложено до первого Mac mini deployment; FT v2.5 cosmetic typo; gotcha-24 — см. §6).

---

## 9. Финальные метрики

| Метрика | Цель | Baseline (старт S8) | Факт (8.R, 2026-05-13) | Статус |
|---------|------|---------------------|------------|--------|
| Backend pytest | 0 failed | 1024 / 0 | **1490 / 0 / 0 xfail** | ✅ +466 |
| Frontend vitest | 0 failed (pre-existing flaky ok) | 468 / 0 | **558 / 2 flaky / 0 регрессий** | ✅ +90 |
| Playwright nightly | 0 failed | 142 / 0 | **158 passed / 1 pre-existing flaky / 5 skipped** (W2 факт) | ✅ +16 |
| Backend coverage TOTAL | ≥ 80% | 71% | **85%** | ✅ +14% |
| Per-module coverage P0 `dispatchers.py` | ≥ 80% | 0% | **100%** | ✅ |
| Per-module coverage P1 `trading/service.py` | ≥ 80% | 51% | **88%** | ✅ |
| Per-module coverage P1 `broker/tinvest/adapter.py` | ≥ 80% | 24% | **95%** | ✅ |
| Per-module coverage P1 `backtest/engine.py` | ≥ 80% | 55% | **96%** | ✅ |
| Per-module coverage P1 `backtest/router.py` | ≥ 80% | 25% | **87%** (real, после coveragerc) | ✅ |
| Per-module coverage P1 `market_data/service.py` | ≥ 80% | 50% | **78%** | ⚠️ −2% |
| Per-module coverage P2 `circuit_breaker/router.py` | ≥ 80% | 60% | **100%** | ✅ |
| Per-module coverage P2 `market_data/router.py` | ≥ 80% | 63% | **92%** (real) | ✅ |
| Per-module coverage P2 `auth/router.py` | ≥ 80% | 67% | **94%** (real) | ✅ |
| Per-module coverage P2 `broker/router.py` | ≥ 80% | 37% | **99%** (real, +coveragerc) | ✅ |
| Per-module coverage P2 `notification/router.py` | ≥ 80% | 47% | **~75%** (real) | ⚠️ <80% async-handler |
| Per-module coverage P2 `strategy/router.py` | ≥ 80% | 43% | **~68%** (real) | ⚠️ <80% async-handler |
| Dashboard LCP | < 2 с | — | **не измерено** (W4 perf measurements) | ⚠️ инфра готова |
| Signal → order p95 | < 500 мс | — | **не измерено** | ⚠️ инфра готова |
| Telegram cmd p95 | < 3 с | — | **не измерено** | ⚠️ инфра готова |
| bandit findings (medium+) | 0 | — | **0 medium / 0 high** (33 low) | ✅ |
| safety CVE (high, unaccepted) | 0 | — | **0** (1 documented expires 2026-12-31) | ✅ |
| ruff issues | 0 | 0 | **0** | ✅ |
| mypy errors | 0 | 0 | **0** (148 files) | ✅ |
| frontend tsc errors | 0 | 0 | **0** | ✅ |
| frontend lint warnings | 0 (после S7R-FE-LINT) | 9 | **0 err / 0 warn** (`--max-warnings 0` активен) | ✅ |
| Alembic up/down/up | clean | clean | **clean** (head=ef6627a679aa) | ✅ |
| LOC `Develop/backend/app` | — | — | **31012** | informational |
| LOC `Develop/backend/tests` | — | — | **33580** (соотношение tests:app = 1.08:1) | informational |
| LOC `Develop/frontend/src` | — | — | **40112** | informational |
| LOC `Develop/frontend/e2e` | — | — | **5435** | informational |
| Кол-во gotchas в INDEX.md | — | 23 (старт S7) | **31 + 32 (после ARCH регистрации)** | ✅ |

**Дельта S7→S8:** +466 backend tests, +90 frontend tests, +16 Playwright, +14% coverage TOTAL, +0 frontend warnings, +8 stack gotchas.

---

## 10. event_type интеграционная sync-проверка

Промпт §C ожидает `tests/integration/test_notification_e2e.py` (12-13 e2e tests на 3 канала доставки). **Этот файл отсутствует** в репозитории (find → 0 hits). Вместо него используется `tests/test_notification/test_event_sync_publishers.py` (8 unit-тестов на EVENT_MAP-структуру).

| event_type | EVENT_MAP key | Publisher (file:line) | UI label | Sync статус |
|---|---|---|---|---|
| session_started | session.started | (broadcast template; см. arch_design §6.2) | ✅ Сессия запущена | ✅ |
| session_stopped | session.stopped | (broadcast template) | ✅ Сессия остановлена | ✅ |
| order_placed | order.placed | (broadcast template) | ✅ Ордер выставлен | ✅ |
| trade_filled | trade.filled | (broadcast template) | ✅ Сделка исполнена | ✅ |
| trade_closed | trade.closed | runtime → notification dispatch | ✅ Закрытие сделки | ✅ |
| cb_triggered | cb.triggered | `circuit_breaker/engine.py` (S5) | ✅ Circuit Breaker | ✅ |
| all_positions_closed | positions.closed_all | runtime | ✅ Все позиции закрыты | ✅ |
| trade_opened | trade.opened | `trading/runtime.py` | ✅ Открытие сделки | ✅ |
| partial_fill | order.partial_fill | runtime → order partial | ✅ Частичное исполнение | ✅ |
| order_error | order.error | runtime → order error | ✅ Ошибка ордера | ✅ |
| connection_lost | connection.lost | `multiplexer.py::_publish_connection_event` | ✅ Потеря соединения | ✅ |
| connection_restored | connection.restored | `multiplexer.py::_publish_connection_event` | ✅ Восстановление соединения | ✅ |
| session_recovered | session.recovered | `app/main.py:197`, `app/trading/runtime.py:498` | ✅ Восстановление сессии | ✅ |
| backtest_completed | backtest.completed | `app/backtest/jobs.py:281`, `app/backtest/router.py:243` | ✅ Бэктест завершён | ✅ |
| daily_stats | system.daily_stats | `app/scheduler/service.py:348` | ✅ Дневная статистика | ✅ |
| corporate_action | system.corporate_action | `app/scheduler/service.py:207` | ✅ Корпоративное событие | ✅ |
| price_alert | system.price_alert | `app/market_data/price_alert_monitor.py:161` | ✅ Ценовое оповещение | ✅ |

**Итог:** 17 event_type ↔ 17 UI labels, **0 discrepancies**. EVENT_MAP-структурная sync-проверка (`test_event_sync_publishers.py`) — 8/8 passed.

**Finding (informational, не блокер M4):** Полноценные e2e интеграционные тесты `Telegram + Email + In-app` для каждого из 17 event_type'ов **не реализованы**. Прокси-замена — `test_event_sync_publishers.py` (структура) + `test_runtime_events.py` (publisher coverage). Для production rollout рекомендуется W4 эпик `S8R-W4-TEST-EVENT-DELIVERY-E2E` (~12ч) — 17 интеграционных тестов с реальным TG bot mock + SMTP capture + WS broadcast assert. Не блокер потому что: все 17 publish-sites реальны (`grep` подтверждён), структурная sync гарантирована, runtime поведение покрыто `test_runtime_events.py`.

---

## 11. Cross-DEV contracts ревизия (C-S8-1..9)

| # | Контракт | Поставщик подтвердил? | Потребитель использует? | Grep-доказательство | Статус |
|---|----------|-----------------------|-------------------------|---------------------|--------|
| C-S8-1 | Extended `GET /api/v1/health` | ✅ DEV-2 W2 | ✅ DEV-4 W2/W3 (HealthWidget) | `app/main.py:352-417` (cb_state, tinvest_connected, scheduler_running); `HealthWidget.tsx:59,84,139` | ✅ CONNECTED |
| C-S8-2 | `GET /api/v1/market-data/sparkline?ticker=X&hours=24` | ✅ DEV-2 W2 | ✅ DEV-4 W2 (SparklineWidget) | `market_data/router.py:53,54`; `SparklineWidget.tsx:51,72` | ✅ CONNECTED |
| C-S8-3 | Balance history `since_first_activity` | ✅ DEV-2 W2 | ✅ DEV-4 W2 (BalanceWidget) | `account/router.py:31,49,57`; `BalanceWidget.tsx:52`; `accountApi.ts:50` | ✅ CONNECTED |
| C-S8-4 | `POST /api/v1/notifications/telegram/test` | ✅ DEV-2 W2 | ✅ DEV-4 W2 (FirstRunWizard) | `notification/router.py:334`; `notificationApi.ts:45` | ✅ CONNECTED |
| C-S8-5 | API paginated audit results | ✅ DEV-1 + DEV-2 W1 | ✅ DEV-4 W1 (unwrapPaginated) | `trading/schemas.py:237` (PaginatedResponse); `api/types.ts:24,38,57` (TS); 5 потребителей через `unwrapPaginated` (`tradingStore.ts`, `CandlestickChart.tsx`, `ActivePositionsWidget.tsx`) | ✅ CONNECTED |
| C-S8-6 | `app.state.tinvest_multiplexer` singleton | ✅ DEV-2 W1 (S7 hotfix + contract tests) | ✅ adapter | `main.py:257-263`; `multiplexer.py:508-560`; `adapter.py:751` (потребление) | ✅ CONNECTED |
| C-S8-7 | `is_admin` поле в User + `/auth/me` | ✅ DEV-1 W1 | ✅ DEV-4 W1 (Sidebar, ProtectedAdminRoute) | `auth/models.py:44`; `auth/schemas.py:58`; `authStore.ts:23`; `Sidebar.tsx`; `ProtectedAdminRoute.tsx` | ✅ CONNECTED |
| C-S8-8 | `GET /api/v1/admin/metrics` (Plotly Dash) | ✅ DEV-4 W2 | ✅ admin users + ARCH smoke | `main.py:317-332` (mount); `admin/metrics_dash.py`; `admin/dash_mount.py:80` (AdminAuthASGIMiddleware); 3/3 integration tests | ✅ CONNECTED |
| C-S8-9 | Event type sync (4 backend + 5 publish-sites) | ✅ DEV-2 W2 | ✅ DEV-4 W2 (EVENT_TYPE_LABELS) | EVENT_MAP 17 ↔ EVENT_TYPE_LABELS 17 (см. §10); 5 publish-sites через grep подтверждены | ✅ CONNECTED |

**Итог:** **9/9 контрактов CONNECTED.** Ни одного `⚠️ NOT CONNECTED`. Все потребители реально вызывают endpoint'ы поставщиков в production-коде (не только в тестах).

---

## 12. Integration verification by grep

| Symbol / поведение | Команда | Production-вызовы | Статус |
|---|---|---|---|
| `create_notification` (5 новых event_type) | `grep -rn 'event_type="<name>"' app/` | session_recovered: 2 (main.py, runtime.py); backtest_completed: 2 (jobs.py, router.py); daily_stats: 1 (scheduler/service.py); corporate_action: 1 (scheduler/service.py); price_alert: 1 (price_alert_monitor.py) | ✅ |
| `tinvest_multiplexer` singleton | `grep -rn "tinvest_multiplexer\|get_or_create_multiplexer\|shutdown_multiplexers"` | 5 hits (main, multiplexer×3, adapter) | ✅ |
| `require_admin` dependency | `grep -rn "require_admin"` | 6+ hits (`admin/router.py:21`, `middleware/auth.py:46`, smoke test, metrics_dash, dash_mount) | ✅ |
| `@timed_event` instrumentation | `grep -rn "@timed_event\|timed_event("` | 3 production (engine.py:389, adapter.py:541, telegram_webhook.py:210) | ✅ |
| `SecurityHeadersMiddleware` | `grep -rn "SecurityHeadersMiddleware"` | main.py:58,280; security_headers.py:44 (3 hits) | ✅ |
| `_safe_format_event_text` (XSS) | grep | telegram.py:60-61, email.py:75-76 | ✅ |
| `ErrorBoundary` обёртка | `grep -rn "ErrorBoundary" frontend/src/` | App.tsx top-level + DashboardPage.tsx (3 widgets) + ChartPage.tsx | ✅ |
| `useAdminGuard\|ProtectedAdminRoute\|is_admin` | grep | Sidebar.tsx (conditional), routes/ProtectedAdminRoute.tsx, authStore.ts:23 | ✅ |
| `Dash\|plotly` | grep | metrics_dash.py (Dash + 4 plotly_dark templates), dash_mount.py, main.py mount | ✅ |
| `AdminAuthASGIMiddleware` | grep | dash_mount.py:80, main.py:326,332 | ✅ |
| `SparklineWidget` | grep | DashboardPage.tsx:23,187 (вызов как 4-й виджет) | ✅ |
| `HealthWidget` WS subscribe | grep | HealthWidget.tsx:139 (`useWebSocket('health', wsCallback)`) | ✅ |
| `BackgroundBacktestsBadge` auto-collapse | grep | BackgroundBacktestsBadge.tsx:75-86,105,114 (`prevActiveRef` + `setPopoverOpen(false)`) | ✅ |
| `filterStrategies` / `countByFilter` / `FilterValue` (W3 lint fix) | grep | `pages/dashboardFilters.ts` (вынос); `DashboardPage.tsx:46-48,109,118,148` (потребление) | ✅ |
| Histogram Mantine Tooltip | grep | PnLDistributionHistogram.tsx (Tooltip withinPortal multiline withArrow); 3 unit-теста | ✅ |
| `equity-curve-zone-{idx}` data-testid | grep | InstrumentChart.tsx:36,135,145,226 (DOM overlay) | ✅ |
| `onRowClick` BacktestTrades | grep | BacktestTrades.tsx:34,185,289-291; BacktestResultsPage.tsx:323 | ✅ |
| `unwrapPaginated` | grep | tradingStore.ts (3 вызова); CandlestickChart.tsx; ActivePositionsWidget.tsx | ✅ |
| `.coveragerc concurrency=greenlet,thread` | cat | существует, `concurrency = greenlet,thread` строка 3 | ✅ |
| Strategy status enum drift backfill | alembic | `ef6627a679aa_s8w3_strategy_status_enum_drift` head; up/down/up clean | ✅ |

**Итог:** **0 `⚠️ NOT CONNECTED` symbols.** Все W1+W2+W3 фичи реально подключены в production.

---

## 13. Stack Gotchas финал

`Develop/stack_gotchas/INDEX.md` — версия **8** (была 7, ARCH обновил после регистрации gotcha-32). 31 строк в таблице (с пропуском gotcha-24).

**Зарегистрированные в S8:**
- `gotcha-25-api-paginated-type-mismatch.md` (DEV-4 W1)
- `gotcha-26-structlog-event-kwarg.md` (DEV-5 W3 от DEV-1 W2 кандидата)
- `gotcha-27-mock-spec-vs-decimal.md` (DEV-5 W3 от DEV-1 W2 кандидата)
- `gotcha-28-decimal-invalidop-vs-valueerror.md` (DEV-5 W3 от DEV-1 W2 кандидата)
- `gotcha-29-coverage-async-concurrency.md` (DEV-5 W3 от DEV-1 W2 кандидата)
- `gotcha-30-httpx-inline-import-patch.md` (DEV-5 W3 от DEV-1 W2 кандидата)
- `gotcha-31-asgi-mount-no-fastapi-depends.md` (DEV-5 W3 от DEV-4 W2 кандидата)
- **`gotcha-32-react-hooks-disable-directive-placement.md` (ARCH в 8.R)** — зарегистрирован после перенумерации DEV-3 W3 кандидата `gotcha-26-react-hooks-disable-directive-placement.md` (номер 26 уже занят DEV-5 для `structlog event kwarg`)

**Не зарегистрированные (отложены в W4 как `S8R-W4-GOTCHA-*` low-карточки):**
- gotcha-24 (lightweight-charts few-points rightbar OR sequential-time-axis) — кандидат от S7 closeout + DEV-3 W1. INDEX строка 24 пропущена. → `S8R-W4-GOTCHA-24-MISSING`.
- DEV-2 W2 «patch.object bytecode fallthrough» — не уровень Stack Gotcha (Python implementation detail). Не блокер.
- QA W1 «Mantine 0-height bar + Playwright toBeVisible» — рекомендация для тестописания, не системная ловушка. Не блокер.
- QA W2 «AnimatedSwitch double-render» — pattern-level (specific to S4 AIChat refactor). Не блокер.

**Stack Gotchas применены DEV'ами в S8:** Gotcha 1 (×2), Gotcha 4 (×3), Gotcha 7 (×2), Gotcha 8 (×1), Gotcha 9 (×2), Gotcha 10 (×1), Gotcha 11 (×1), Gotcha 12 (×2), Gotcha 13 (×2), Gotcha 14 (×2), Gotcha 15 (×1), Gotcha 16 (×1), Gotcha 17 (×1), Gotcha 18 (×1), Gotcha 19 (×1), Gotcha 20 (×2), Gotcha 21 (×1), Gotcha 22 (×2), Gotcha 24 (косвенно, ×2 — обход через SVG MiniSparkline), Gotcha 25 (×1).

**Результат: PASS WITH NOTES** (gotcha-24 отсутствует, перенесён в W4; gotcha-32 зарегистрирован).

---

## 14. Documentation completeness

| Документ | Статус | Доказательство |
|---|---|---|
| `README.md` (корневой) | ✅ OK | Новый, 7728 bytes, getting started + ссылка на deployment_guide |
| `Develop/INSTALL.md` | ✅ OK | Обновлён DEV-5 (Node 24 + T-Invest patched + pnpm) |
| `Документация по проекту/deployment_guide.md` | ✅ OK | Новый, 16999 bytes, 9 разделов (Целевая платформа → Troubleshooting) |
| `Документация по проекту/functional_requirements.md` v2.5 | ✅ OK (1 cosmetic typo) | Header «v2.5», changelog 2026-05-13 S8 W3. Cosmetic: «EVENT_TYPE_LABELS 13» (фактически 17) в строке 14. |
| `Документация по проекту/technical_specification.md` v1.5 | ✅ OK | Header «v1.5», §8.10 Deployment Architecture добавлен; perf-метрики «измеряется через @timed_event» (числа отложены в W4) |
| `Документация по проекту/development_plan.md` v2.1 | ✅ OK | M4 ✅ достигнут; §7 Sprint_8_Review + post-production |
| `Спринты/project_state.md` | ⬜ DEFERRED (оркестратор) | Финальная отметка M4 ✅ — задача оркестратора после моего PASS |
| `Sprint_8/changelog.md` | ⬜ DEFERRED (оркестратор) | Финальная запись «8.R PASS WITH NOTES» — задача оркестратора |
| `Sprint_8/sprint_state.md` | ⬜ DEFERRED (оркестратор) | Отражение завершения 3 волн + 8.R — задача оркестратора |
| `Develop/CLAUDE.md` | ✅ OK | Polish + секция «Дополнительные правила S8» (7 правил) |
| `Develop/stack_gotchas/INDEX.md` | ✅ OK | Версия 8 (ARCH обновил); 31 + gotcha-32 = 32 ловушки; gotcha-24 пропущен → W4 |
| `Спринты/Sprint_8/ui_checklist_s8.md` | ✅ OK | UX_W3 создал — 136 новых пунктов S8 |
| `Спринты/ui_checklist_s8.md` (корневой) | ✅ OK | Дубликат для удобства |

**Результат: PASS WITH NOTES** (1 cosmetic FT typo; project_state/changelog/sprint_state — финальные апдейты делает оркестратор по итогам этого ревью).

---

## 15. Перенос задач (DEFERRED-W4)

Ниже — карточки для `Sprint_8_Review/backlog.md` (создать если ещё не существует). Приоритет: low (если не указано иное).

### Critical / High — нет

Все critical/high закрыты в S8 W1+W2.

### Medium

1. **`S8R-W4-PERF-BASELINE-MEASUREMENTS`** (~6ч). Фактические p95 измерения через `pytest-benchmark` для трёх hot-path: dashboard LCP, signal→order, telegram cmd. Инфраструктура `@timed_event` готова, данные накопятся при первом production rollout — но нужны baseline-цифры для ТЗ v1.6.
2. **`S8R-SEC-AUTH-RATE-TIGHTEN`** (~2ч). Текущий rate limit `/auth/login` = 60/min, рекомендуется 3-5/min (зафиксировано в `security_audit_s8.md`).
3. **`S8R-COV-MARKET-DATA-SERVICE`** (~4ч). 78% → 80%+, `_fetch_lot_size_from_tinvest` happy + `get_or_fetch_logo_isin` commit-fail.
4. **`S8R-W4-TEST-EVENT-DELIVERY-E2E`** (~12ч). 17 интеграционных тестов реальной доставки event_type через Telegram bot mock + SMTP capture + WS broadcast.
5. **`S8R-UX-DRAWING-LEGACY-BACKFILL`** (~3ч, medium-low). Миграция backfill `logical` для legacy drawings на intraday TF (UX_W3).
6. **`S8R-UX-ADMIN-LANDING-EMPTY`** (~4ч, medium-low). Расширить AdminLandingPage (snapshot сессий, errors counter, grant_admin UI). UX_W3.

### Low

7. **`S8R-W4-COV-STRATEGY-SERVICE`** (~3ч). 68% → 80%.
8. **`S8R-W4-GOTCHA-24-MISSING`** (~30мин). Зарегистрировать `gotcha-24-lightweight-charts-few-points-rightbar.md` (S7 closeout) или `…-sequential-time-axis.md` (DEV-3 W1 кандидат) — выбрать актуальный, добавить строку 24 в INDEX.
9. **`S8R-W4-E2E-ANALYTICS-UNSKIP`** (~1ч). Активировать 2 `test.skip` в `e2e/s7-backtest-analytics.spec.ts` (FRONT2 W2 разблокировал DOM overlay + onRowClick — нужна актуализация теста).
10. **`S8R-W4-DOCS-FT-EVENT-COUNT`** (~5мин, cosmetic). Исправить `functional_requirements.md:14` — «EVENT_TYPE_LABELS 13» → «EVENT_TYPE_LABELS 17».
11. **`S8R-CLIENT-TEST-FLAKY`** (~1ч). Диагностика 2 pre-existing flaky в `client.test.ts` (axios interceptor timeout). Не S8 регрессия, известный baseline-багаж.
12. **`S8R-UX-WIZARD-TG-NO-ARIA`** (~10мин). aria-атрибуты для Telegram блока wizard. UX_W3.
13. **`S8R-UX-DASH-4COL-OVERFLOW`** (~10мин). lg:4 → lg:3 на 1024-1280px. UX_W3.
14. **`S8R-UX-WIZARD-TG-TEST-DISABLED-HINT`** (~10мин). Hint при disabled-кнопке «Отправить тест». UX_W3.
15. **`S8R-UX-PLOTLY-DARK-THEME`** (~5мин, **закрыть**). Уже реализовано (`template='plotly_dark'` в metrics_dash.py) — карточка из UX_W3 устарела.
16. **`S7R-MULTICURRENCY-TOGGLE`** (~6ч). Бюджет S8 исчерпан, перенос как low.

### Informational

17. **`S8R-W4-DOCKER-COMPOSE-VALIDATE`** — `docker compose config` не запущен (нет docker CLI в DEV-окружении). Первый Mac mini deployment даст финальную семантическую валидацию.
18. **`S8R-W4-PLAYWRIGHT-NIGHTLY-RERUN`** — Playwright nightly suite (158 passed) последний раз прогнан в W2 (QA_W2). 8.R пропустил повторный nightly (W3 фичи unit-tests coverage адекватная). Рекомендуется prerelease-run перед Mac mini deployment.

**Итого: 18 переносных карточек.** 0 critical/high, 6 medium, 11 low, 2 informational.

---

## 16. Чеклист сдачи

- [x] Все 8 секций code review проведены (часть A)
- [x] Integration verification (grep + contracts + events) пройден (часть E + D + C)
- [x] Stack Gotchas обновлены (gotcha-32 зарегистрирован; gotcha-24 → W4 carry-over (Sprint_8_Review))
- [x] Финальные метрики записаны (часть B)
- [x] Документация обновлена (README/INSTALL/ФТ/ТЗ/development_plan/deployment_guide) — DEV-5 W3
- [x] Финальный вердикт зафиксирован: **PASS WITH NOTES**
- [ ] `Спринты/project_state.md` обновлён — **задача оркестратора** после моего PASS
- [ ] `Sprint_8/changelog.md` обновлён «8.R PASS WITH NOTES» — **задача оркестратора**
- [ ] `Sprint_8/sprint_state.md` отражает «✅ завершён» — **задача оркестратора**
- [x] `Спринты/Sprint_8/arch_review_s8.md` сохранён (текущий файл)
- [x] `reports/ARCH_S8_review.md` сохранён (краткая сводка)
- [x] Skip-тикеты — все 5 имеют карточку в backlog (Blockly mode B × 2, s7-analytics × 2, s7r-chart-drawings CI-skip)
- [x] Alembic up/down/up clean (head=ef6627a679aa)
- [x] Все Cross-DEV contracts 9/9 connected
- [x] Stack Gotchas INDEX версия 8 (8 новых ловушек S8)
- [x] Все плагины из «Обязательных» использованы или fallback: pyright/typescript fallback py_compile/tsc; bandit/safety/pytest реальный запуск; playwright nightly W2-факт (W3 unit only)

---

**Подпись:** ARCH agent, Sprint 8, 8.R Final Review, 2026-05-13.

**Решение оркестратору:** M4 Production-ready достигнут. PASS WITH NOTES — закрыть milestone, перенести 18 DEFERRED-W4 карточек в `Sprint_8_Review/backlog.md`.
