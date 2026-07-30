# Sprint 8 — Порядок выполнения

> Wave-based план M4. **Финальная разбивка задач по DEV-ролям и точные timeline — после W0 ARCH-design.** Этот файл — стартовая дорожная карта.

## W0 — Pre-sprint design (день 1)

| Роль | Задача | Артефакт |
|------|--------|----------|
| ARCH | Аудит `Sprint_8_Review/backlog.md`, приоритезация, разбивка по DEV-ролям, оценка timeline. Brainstorm каждой категории (Coverage / Security / Perf). | `arch_design_s8.md` |
| QA | План E2E: расширить ui_checklist + 6 missing spec'ов | `e2e_test_plan_s8.md` |
| Заказчик | Утверждение `arch_design_s8.md` | подпись/коммент |

**Gate W0 → W1:** ARCH-design утверждён, DEV-промпты созданы, e2e_test_plan_s8.md готов.

## W1 — Параллельные потоки (дни 2-5)

> Обновлено после W0 ARCH-design (см. `arch_design_s8.md` §11-12).
> Цель: закрыть medium-high карточки + начать coverage/security аудит + admin role.

### Поток A: Coverage P0+P1 для критических путей (BACK1, ~30ч)
- `notification/dispatchers.py` 0% → 80% (~4ч)
- `broker/tinvest/adapter.py` 24% → 80% (~16ч, моки tinkoff API)
- `trading/service.py` 51% → 80% (~12ч)

### Поток B: Security audit + bandit/safety + MULTIPLEXER-SINGLETON (BACK2, ~22ч)
- Setup `bandit` + `safety` в `.github/workflows/ci.yml` (~1ч)
- Security audit отчёт `Sprint_8/security_audit_s8.md` (~14ч):
  - Crypto (AES-256-GCM, IV uniqueness, JWT secret length ≥ 32, Argon2id params)
  - Sandbox escape (`_safe_import`, `__builtins__`, subclasses chain, compile/exec/eval)
  - CSRF (double-submit cookie, samesite)
  - Headers (CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy)
  - Brute-force (rate limit, account lockout)
  - SQL injection grep + XSS в TG/Email шаблонах
- `S7R-MULTIPLEXER-SINGLETON` (root cause): `app.state.tinvest_multiplexer`, lifespan create/close (~4ч)
- Smoke-проверка `require_admin` на admin-endpoints (после потока F закрыт) (~3ч)

### Поток C: Charts editing эпик (FRONT1, ~22ч)
- `S7R-DRAWING-EDITING` — drag/перенос/изменение углов (~16ч)
- `S7R-DRAWING-INTRADAY-COORDS` — sequential mode координаты (~6ч)

### Поток D: API contract + ErrorBoundary + Strategy status UI (FRONT2, ~18ч)
- `S7R-API-PAGINATED-TYPE-MISMATCH` audit `frontend/src/api/*.ts` + правка типов (~6ч)
- `S7R-FRONTEND-ERROR-BOUNDARY-MISSING` — ErrorBoundary в App.tsx + per-widget (~4ч)
- `S7R-STRATEGY-STATUS-CHANGE-UI` — контекстное меню + Select (~8ч)

### Поток E: 6 missing E2E (QA, ~20ч)
- `s7-export.spec.ts` (S7R-E2E-7.3): download CSV + PDF magic bytes (~3ч)
- **`tests/integration/test_backup_cli.py`** (S7R-E2E-7.9): pytest + subprocess.run (~3ч) — NB: не Playwright!
- `s7-events.spec.ts` (S7R-E2E-7.13): mock WS frame → bell rendering для 5 event_type (~6ч)
- `s7-tg-callbacks.spec.ts` (S7R-E2E-7.14): deep-link на /sessions, /chart (~3ч)
- `s7-backtest-analytics.spec.ts` (S7R-E2E-7.16): hover/click зон + histogram + donut (~4ч)
- `s7-bg-backtest.spec.ts` (S7R-E2E-7.17): badge инкремент/декремент (~3ч)

### Поток F: НОВЫЙ — Admin role + bootstrap (BACK1 + FRONT2, ~11ч)
- BACK1: миграция alembic `users.is_admin: bool = False` (~2ч)
- BACK1: `require_admin` dependency + `app/admin/router.py` модуль (~3ч)
- FRONT2: `useAuthStore.user.is_admin`, `Sidebar` conditional, `ProtectedAdminRoute` (~2ч)
- BACK1: CLI `python -m app.cli.users grant_admin <username>` (~1ч)
- Bootstrap: FirstRunWizard → первый = admin (~1ч)
- Тесты: 1 unit + 2 integration (~3ч)

**Gate W1 → W2:** все medium-high закрыты, security audit отчёт готов, 6 E2E зелёные, coverage P0+P1 на 80%+ хотя бы по 4 модулям, admin role работает.

## W2 — Performance + Event sync + закрытие medium (дни 6-9)

### Поток A: Performance + AIChat mock + Coverage P1 закрытие (BACK1, ~20ч)
- Performance baseline + instrumentation `@timed_event` в `app/common/observability.py` (~4ч)
- AIChat mock — реалистичный block_xml в e2e/fixtures/api_mocks.ts (~2ч) [TODO #2]
- Coverage P1 (`market_data/service.py`, `backtest/router.py`, `strategy/service.py`, `backtest/engine.py`) (~14ч)

> **Уточнение по решению заказчика (2026-05-12, после W0):** Plotly Dash `/admin/metrics` страница (~4ч) переходит из BACK1 в **FRONT2 (Поток C)** — это admin UI задача. BACK1 обеспечивает только `app/admin/router.py` mount point в W1 (Поток F).

### Поток B: НОВЫЙ — Event type sync L1 + Dashboard widgets backend (BACK2, ~25ч)
**Event type sync (~12ч):**
- Добавить в UI `EVENT_TYPE_LABELS`: session_started, session_stopped, order_placed, trade_filled (~30мин фронт-задача, но фиксим контракт здесь)
- Подключить publish-сайты для 5 UI-типов:
  - `session_recovered` — после graceful restart NS (~2ч)
  - `backtest_completed` — `app/backtest/jobs.py:226` event + EVENT_MAP entry (~2ч)
  - `daily_stats` — определить семантику + scheduler-trigger (~2ч)
  - `corporate_action` — `app/corporate_actions/` detect job (~3ч)
  - `price_alert` — `app/market_data/price_alert_monitor.py` (~2ч)

**Dashboard widgets backend + Notification filter (~13ч):**
- `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` — `/health` extended с cb_state/tinvest_connected/scheduler_running (~3ч)
- `S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE` — отрезать leading zeros (~2ч)
- `S7R-WIDGET-SPARKLINE-24H` — новый endpoint sparkline (~3ч)
- `S7R-WIZARD-TELEGRAM-TEST-BUTTON` — endpoint `POST /api/v1/notifications/telegram/test` (~2ч)
- `S7R-CONNECTION-EVENTS-MARKET-CLOSED` — фильтр MOEX calendar (~3ч)

### Поток C: Frontend medium + дозакрытие event sync UI + Plotly Dash (FRONT2, ~22ч)
- 4 widget'а из эпика E (frontend интеграция endpoint'ов из потока B) (~10ч)
- 4 backend event_types в `EVENT_TYPE_LABELS` (`NotificationSettingsPage.tsx:24`) (~1ч)
- `S7R-GRID-HEATMAP-ENTRYPOINT` — точка вызова из BG-badge (~2ч)
- `S7R-WIDGETS-UNIT-COVERAGE` (~4ч)
- **Plotly Dash `/admin/metrics` страница (~4ч)** — `app/admin/metrics_dash.py` + mount через WSGIMiddleware в `app/admin/router.py` (требует C-S8-7 is_admin + Поток F W1)
- `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE` (если успеет — иначе W3) (~3ч)

### Поток D: Coverage P2 (router-тесты) (BACK1, ~10ч)
- `auth/router`, `notification/router`, `broker/router`, `market_data/router`, `strategy/router`, `circuit_breaker/router`

**Gate W2 → W3:** coverage TOTAL ≥ 80%, performance метрики baseline'ed и в норме, event type sync завершён (UI ↔ EVENT_MAP консистентны), ≥ 80% medium-карточек закрыто.

## W3 — Финализация (дни 10-12)

### Поток A: Low-карточки и cleanup (FRONT1 + FRONT2 + OPS, ~14ч)
- `S7R-CI-NODE24-MIGRATION` — обновить actions/* (~2ч)
- `S7R-FE-LINT-WARNINGS-CLEANUP` — 9 react-hooks/exhaustive-deps + `--max-warnings 0` (~4ч)
- `S7R-HEALTH-WS-MIGRATION` (~4ч)
- `S7R-MULTICURRENCY-TOGGLE` (~6ч если успеет — иначе S9)
- `S7R-BG-BACKTEST-AUTOCOLLAPSE`, `S7R-HISTOGRAM-MANTINE-TOOLTIP`, `S7R-STRATEGY-STATUS-PAUSED-FILTER`, `S7R-STRATEGY-STATUS-ENUM-DRIFT` (~4ч)
- **Coverage gate в CI:** `--cov-fail-under=80` в backend job [TODO #3] (~1ч)
- Удалить 2 spec'а Blockly mode B [TODO #1] (~5мин)

### Поток B: UX финальный юзабилити-тест (UX, ~8ч)
- Сценарии новый пользователь от регистрации до первой сделки
- Обновить `ui_checklist_s7.md` → `ui_checklist_s8.md`
- UX-баги фиксить или в S9-backlog

### Поток C: Документация + Deployment guide (OPS/BACK1, ~17ч)
- `README.md` — актуальный установочный гайд (~2ч)
- `Develop/INSTALL.md` — обновить (~1ч)
- `Документация по проекту/deployment_guide.md` — **NEW**: Docker compose + Mac mini + launchd + Cloudflare Tunnel SSL [TODO #10] (~6ч)
- `Sprint_8/changelog.md` — финальная сводка (~ongoing)
- `Спринты/project_state.md` — финальная отметка M4 ✅ (~1ч)
- `functional_requirements.md` v2.5 (~2ч)
- `technical_specification.md` v1.5 с реальными perf-метриками (~2ч)
- `development_plan.md` обновить M4 ✅ + S9 roadmap (~1ч)
- `Develop/stack_gotchas/` обновить новыми gotchas (~1ч)
- `Develop/CLAUDE.md` polish (~1ч)

### Поток D: 8.R ARCH-ревью (ARCH, ~8ч)
- Code review (8 секций по образцу `Sprint_6_Review/code_review.md`)
- Метрики финальные (тесты / coverage / lint / perf)
- 12-13 event_type интеграционные тесты (после event sync эпика)
- Вердикт: PASS / PASS WITH NOTES / NEED FIXES

**Gate W3 → Closeout:** 8.R PASS, M4 milestone достигнут, deployment_guide готов для production rollout на Mac mini.

---

## Приоритизация backlog (исходник)

См. `Sprint_8_Review/backlog.md`. Краткая разбивка:

### Medium-high (обязательно к закрытию в S8)
1. `S7R-DRAWING-EDITING` (FRONT, medium-high) — drag фигур
2. `S7R-STRATEGY-STATUS-CHANGE-UI` (FRONT, medium-high) — UI смены статуса
3. `S7R-API-PAGINATED-TYPE-MISMATCH` (FRONT+BACK audit, medium-high) — runtime crash защита
4. `S7R-MULTIPLEXER-SINGLETON` (BACK, medium) — но root cause critical

### Medium (≥ 80% закрытие)
5. `S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17-MISSING` (QA × 6, medium)
6. `S7R-FRONTEND-ERROR-BOUNDARY-MISSING` (FRONT, medium)
7. `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` (BACK+FRONT, medium)
8. `S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE` (BACK+FRONT, medium)
9. `S7R-WIDGET-SPARKLINE-24H` (BACK+FRONT, medium)
10. `S7R-WIZARD-TELEGRAM-TEST-BUTTON` (BACK+FRONT, medium)
11. `S7R-DRAWING-INTRADAY-COORDS` (FRONT, medium)
12. `S7R-GRID-HEATMAP-ENTRYPOINT` (FRONT, medium)
13. `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE` (BACK tests, medium)
14. `S7R-WIDGETS-UNIT-COVERAGE` (FRONT tests, low → подымаем до medium ради S8 coverage цели)

### Low (по остаточному принципу)
15. `S7R-CI-NODE24-MIGRATION` (OPS, low)
16. `S7R-FE-LINT-WARNINGS-CLEANUP` (FRONT, low)
17. `S7R-HEALTH-WS-MIGRATION` (BACK+FRONT, low)
18. `S7R-MULTICURRENCY-TOGGLE` (BACK+FRONT, low)
19. `S7R-BG-BACKTEST-AUTOCOLLAPSE` (FRONT, low)
20. `S7R-HISTOGRAM-MANTINE-TOOLTIP` (FRONT, low)
21. `S7R-CONNECTION-EVENTS-MARKET-CLOSED` (BACK, low)
22. `S7R-STRATEGY-STATUS-PAUSED-FILTER` (FRONT, low — зависит от #2)
23. `S7R-STRATEGY-STATUS-ENUM-DRIFT` (BACK migration, low)

### Pre-existing skips (решить или удалить)
- `S6R-AICHAT-APPLY-MOCK`
- `S5R-BLOCKLY-MODE-B-MODAL`
- `S5R-BLOCKLY-MODE-B-CHECK`

---

## Cross-DEV contracts

> Заполнено ARCH в W0 (2026-05-12). Полная таблица — см. `arch_design_s8.md` §8.5.

| # | Поставщик (волна) | Потребитель | Контракт | Формат / сигнатура |
|---|------------------|-------------|----------|--------------------|
| **C-S8-1** | BACK2 (W2) | FRONT2 (W2) | Extended `GET /api/v1/health` | `{status, version, database, cb_state: 'ok'\|'warn'\|'triggered', tinvest_connected: bool, scheduler_running: bool, scheduler_jobs: int}` |
| **C-S8-2** | BACK2 (W2) | FRONT2 (W2) | `GET /api/v1/market-data/sparkline?ticker=X&hours=24` | `{points: [{t: timestamp, p: number}], current: number}` |
| **C-S8-3** | BACK2 (W2) | FRONT2 (W2) | `GET /api/v1/account/balance/history?since_first_activity=true` | существующий формат + параметр |
| **C-S8-4** | BACK2 (W2) | FRONT2 (W2) | `POST /api/v1/notifications/telegram/test` | request `{bot_token, chat_id}`, response `{ok: bool, message: str}` |
| **C-S8-5** | BACK2+BACK1 (W1) | FRONT2 (W1) | API paginated audit results | таблица endpoint'ов с `response_model=PaginatedResponse` + правка `frontend/src/api/*.ts` |
| **C-S8-6** | BACK1 (W1) | (внутри backend) | `app.state.tinvest_multiplexer` singleton | `lifespan` создаёт один экземпляр, все `TInvestAdapter` его share |
| **C-S8-7** | BACK1 (W1) | FRONT2 (W1) | `is_admin` поле в User + `/auth/me` response | `User { is_admin: bool }` (миграция + dependency `require_admin`) |
| **C-S8-8** | BACK1 (W1) | FRONT2 (W2) | `GET /api/v1/admin/metrics` | Plotly Dash страница (require_admin) |
| **C-S8-9** | BACK2 (W2) | FRONT2 (W2) | Event type sync — 4 backend + 5 publish-sites | `EVENT_MAP` дополнен, `EVENT_TYPE_LABELS` синхронизирован |

---

## Stack Gotchas — обязательное обновление

Каждый новый баг → новый файл `Develop/stack_gotchas/gotcha-NN-*.md` + строка в `INDEX.md`. Регламент: `Develop/stack_gotchas/README.md`.

Кандидаты в Stack Gotchas, известные на старте S8:
- `gotcha-24-lightweight-charts-few-points-rightbar.md` (см. `Sprint_7/changelog.md:103` S7R-EQUITY-BY-INDEX «новая Stack Gotcha»)
- `gotcha-NN-api-paginated-type-mismatch.md` (см. `Sprint_8_Review/backlog.md` `S7R-API-PAGINATED-TYPE-MISMATCH`)
