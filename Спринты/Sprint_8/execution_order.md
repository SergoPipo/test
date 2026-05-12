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

**Цель:** закрыть medium-high карточки + начать coverage/security аудит.

### Поток A: Coverage gap audit (DEV-1, backend)
Прогон `pytest --cov=app --cov-report=html` → таблица модулей < 80% → план довода. Минимум:
- `app/trading/` (критический путь — приоритет 1)
- `app/circuit_breaker/`
- `app/broker/tinvest/`
- `app/sandbox/`

### Поток B: Security audit (DEV-2, backend)
Чек-листы:
- **Crypto:** AES-256-GCM ключи (rotation, IV uniqueness), JWT secret length (≥32 bytes)
- **Sandbox escape:** RestrictedPython `_safe_import` whitelist, попытка побега через `__builtins__`/`object.__subclasses__()`
- **CSRF:** double-submit cookie актуален, `samesite=Strict`
- **Headers:** CSP, X-Frame-Options, HSTS, X-Content-Type-Options
- **Brute-force:** rate limit на `/auth/login` (3-5 попыток/мин), Argon2id корректные параметры

### Поток C: Backend medium-high
- `S7R-MULTIPLEXER-SINGLETON` (root cause) — `app.state.tinvest_multiplexer`, lifespan
- `S7R-API-PAGINATED-TYPE-MISMATCH` audit `frontend/src/api/*.ts` и backend `response_model=PaginatedResponse`

### Поток D: Frontend medium-high
- `S7R-STRATEGY-STATUS-CHANGE-UI` — контекстное меню `⋮` на dashboard + Select на edit
- `S7R-FRONTEND-ERROR-BOUNDARY-MISSING` — ErrorBoundary вокруг routes + per-widget

### Поток E: 6 missing E2E (QA)
- `s7-export.spec.ts` (S7R-E2E-7.3): download CSV + PDF magic bytes
- `s7-backup.spec.ts` (S7R-E2E-7.9): subprocess CLI backup/restore
- `s7-events.spec.ts` (S7R-E2E-7.13): 5 event_type → bell rendering
- `s7-tg-callbacks.spec.ts` (S7R-E2E-7.14): deep-link на /sessions, /chart
- `s7-backtest-analytics.spec.ts` (S7R-E2E-7.16): hover/click зон + histogram + donut
- `s7-bg-backtest.spec.ts` (S7R-E2E-7.17): badge инкремент/декремент

**Gate W1 → W2:** все medium-high закрыты, security audit отчёт готов, 6 missing E2E зелёные, coverage план есть.

## W2 — Performance + закрытие medium (дни 6-9)

### Поток A: Performance testing (DEV-1)
Метрики из ТЗ:
- Дашборд первый paint: цель < 2с
- Signal → place_order: цель < 500мс p95
- Telegram-команда от webhook до reply: цель < 3с

Инструменты: `pytest-benchmark`, Chrome DevTools Performance, custom timing logs.

### Поток B: Backend medium (DEV-2)
- `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE` — параметризовать paper+real
- `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` — extend `/health` с cb_state/tinvest_connected/scheduler_running
- `S7R-CONNECTION-EVENTS-MARKET-CLOSED` — фильтр MOEX calendar
- `S7R-WIDGET-SPARKLINE-24H` — endpoint sparkline

### Поток C: Frontend medium (DEV-3)
- `S7R-DRAWING-EDITING` — drag/перенос/изменение углов (medium-high, большая задача)
- `S7R-DRAWING-INTRADAY-COORDS` — sequential mode координаты
- `S7R-GRID-HEATMAP-ENTRYPOINT` — точка вызова из BG-badge
- `S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE` — отрезать leading zeros
- `S7R-WIZARD-TELEGRAM-TEST-BUTTON` — кнопка + endpoint

### Поток D: Coverage довод (DEV-1)
Покрытие модулей по плану из W1 потока A до 80%.

**Gate W2 → W3:** coverage ≥ 80% по всем критическим модулям, performance метрики измерены и в пределах нормы, ≥ 80% medium-карточек закрыто.

## W3 — Финализация (дни 10-12)

### Поток A: Low-карточки и cleanup (DEV)
- `S7R-CI-NODE24-MIGRATION` — обновить actions/* или FORCE_JAVASCRIPT_ACTIONS_TO_NODE24
- `S7R-FE-LINT-WARNINGS-CLEANUP` — 10 react-hooks/exhaustive-deps + `--max-warnings 0`
- `S7R-HEALTH-WS-MIGRATION`, `S7R-MULTICURRENCY-TOGGLE`, остальной low

### Поток B: UX финальный юзабилити-тест (UX)
- Сценарии: новый пользователь от регистрации до первой сделки
- Чеклист: `ui_checklist_s7.md` дополнить
- UX-баги: либо закрыть, либо в S9-backlog

### Поток C: Документация (DEV-1 или OPS)
- `README.md` — актуальный установочный гайд
- `Develop/INSTALL.md` — обновить
- `Документация по проекту/deployment_guide.md` — новый (Docker/systemd/nginx)
- `Sprint_8/changelog.md` — финальная сводка
- `Спринты/project_state.md` — финальная отметка M4

### Поток D: 8.R ARCH-ревью (ARCH)
- Code review (8 секций по образцу `Sprint_6_Review/code_review.md`)
- Метрики финальные (тесты / coverage / lint / perf)
- 13 event_type верификация (см. `project_state.md:105`)
- Вердикт: PASS / PASS WITH NOTES / NEED FIXES

**Gate W3 → Closeout:** 8.R PASS, M4 milestone достигнут.

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

> Заполняется ARCH на W0 ПЕРЕД запуском DEV-агентов. Без раздела «Cross-DEV contracts» — DEV-промпт не валиден (правило из ретроспективы S5).

| # | Поставщик | Потребитель | Контракт | Формат / сигнатура |
|---|-----------|-------------|----------|--------------------|
| — | — | — | (заполняется в W0) | — |

---

## Stack Gotchas — обязательное обновление

Каждый новый баг → новый файл `Develop/stack_gotchas/gotcha-NN-*.md` + строка в `INDEX.md`. Регламент: `Develop/stack_gotchas/README.md`.

Кандидаты в Stack Gotchas, известные на старте S8:
- `gotcha-24-lightweight-charts-few-points-rightbar.md` (см. `Sprint_7/changelog.md:103` S7R-EQUITY-BY-INDEX «новая Stack Gotcha»)
- `gotcha-NN-api-paginated-type-mismatch.md` (см. `Sprint_8_Review/backlog.md` `S7R-API-PAGINATED-TYPE-MISMATCH`)
