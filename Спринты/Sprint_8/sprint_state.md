# Sprint 8 — текущее состояние

> Обновляется после каждого этапа.

**Дата планирования:** 2026-05-12
**Дата старта W0:** 2026-05-12
**Дата завершения W0:** 2026-05-12 (gate W0 → W1 пройден, все 10 TODO + новый эпик Admin role утверждены)
**Дата старта W1:** 2026-05-12 (ожидает команды заказчика «старт W1»)
**Дата завершения W1:** —
**Дата старта W2:** —
**Дата завершения W2:** —
**Дата старта W3:** —
**Дата завершения 8.R:** —

## Текущий шаг

**Sprint 8 🔄 W1 IN-PROGRESS (2026-05-12). Все промпты созданы, ветка `s8/sprint-8` готова, ожидает команды «старт W1».**

Sprint 7 финально закрыт со всеми post-S7 closeout-волнами. M3 Phase 1 production-ready.

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
