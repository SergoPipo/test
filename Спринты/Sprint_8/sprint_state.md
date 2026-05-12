# Sprint 8 — текущее состояние

> Обновляется после каждого этапа.

**Дата планирования:** 2026-05-12
**Дата старта W0:** 2026-05-12
**Дата завершения W0:** 2026-05-12 (gate W0 → W1 пройден, все 10 TODO + новый эпик Admin role утверждены)
**Дата старта W1:** —
**Дата завершения W1:** —
**Дата старта W2:** —
**Дата завершения W2:** —
**Дата старта W3:** —
**Дата завершения 8.R:** —

## Текущий шаг

**Sprint 8 ✅ W0 ЗАВЕРШЁН (2026-05-12). Gate W0 → W1 пройден. Готов к W1.**

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

**Что нужно для запуска W1:**
1. ⬜ QA создаёт `e2e_test_plan_s8.md` (по §5 arch_design)
2. ⬜ ARCH создаёт `prompt_DEV-1..N.md` (6 ролей: BACK1, BACK2, FRONT1, FRONT2, QA, OPS) + `prompt_QA.md` + `prompt_UX.md` + `prompt_ARCH_review.md`
3. ⬜ Создать ветку `s8/sprint-8` в Develop репо
4. ⬜ Заказчик подтверждает старт W1

---

## Инструкция для следующей сессии (создание DEV-промптов)

Когда заказчик скажет «продолжим S8» или «создавай промпты», Claude должен:

1. **Прочитать порядок:**
   - `Спринты/project_state.md` (где мы — S8 W0 завершён)
   - `Спринты/Sprint_8/sprint_state.md` (этот файл)
   - `Спринты/Sprint_8/arch_design_s8.md` целиком (8 секций + §11 решения TODO + §12 готовность)
   - `Спринты/Sprint_8/execution_order.md` (потоки W1 + Cross-DEV contracts)
   - `Спринты/prompt_template.md` (шаблон промпта, 11 секций)
   - `Sprint_7/prompt_DEV-1.md` для образца (опционально)

2. **Создать 9 промптов** по `prompt_template.md`:
   - `prompt_DEV-1.md` (BACK1) — Coverage P0+P1, T-Invest adapter, Admin role backend, Performance, Coverage P2 (3 волны)
   - `prompt_DEV-2.md` (BACK2) — Security audit + bandit/safety, MULTIPLEXER-SINGLETON, Event sync publishers, Dashboard endpoints, Notification filter
   - `prompt_DEV-3.md` (FRONT1) — Charts editing эпик (DRAWING-EDITING + DRAWING-INTRADAY-COORDS), low W3 cleanup
   - `prompt_DEV-4.md` (FRONT2) — API paginated audit, ErrorBoundary, Strategy status UI, Dashboard widgets, Admin role frontend, Event sync UI labels, Plotly Dash
   - `prompt_DEV-5.md` (OPS) — Docker compose, launchd plist, deployment_guide.md, README/INSTALL update
   - `prompt_QA.md` — 6 missing E2E (5 Playwright + 1 pytest integration) + AIChat mock + регрессия nightly
   - `prompt_UX.md` — W3 финальный юзабилити-тест + ui_checklist_s8.md
   - `prompt_ARCH_design.md` (W0) — УЖЕ СОЗДАН, не трогать
   - `prompt_ARCH_review.md` — 8.R по образцу Sprint_6_Review/code_review.md

3. **Создать `e2e_test_plan_s8.md`** — 6 spec'ов с детальными сценариями (§5 arch_design).

4. **Создать ветку `s8/sprint-8` в Develop репо.**

5. **Обновить sprint_state.md** — переход «W0 ЗАВЕРШЁН» → «🔄 W1 IN-PROGRESS».

**Ожидаемый объём работы:** 9 файлов промптов × ~200-300 строк = ~2500 строк. Лучше через `general-purpose` subagent с детальным брифингом, либо в свежей сессии с большим контекстом.

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
