# Sprint 8 — Changelog

> Лог изменений по дням. Обновляется **немедленно** после каждого блока изменений
> (правило памяти `feedback_changelog_immediate.md`).
>
> Формат записи: `## YYYY-MM-DD — короткое название`. Внутри — bullet'ы:
> - **Что:** краткое описание изменения
> - **Файлы:** перечень
> - **Результат:** что работает / что сломалось / тесты

---

## 2026-05-12 — Sprint 8 инициализирован

### Что
Создан scaffold для Sprint 8 (M4 Production-ready):

- `Sprint_8/README.md` — точка входа, 8 целей M4 + источник backlog
- `Sprint_8/sprint_state.md` — текущий шаг, план волн, baseline тестов
- `Sprint_8/preflight_checklist.md` — чек окружения до W0
- `Sprint_8/prompt_ARCH_design.md` — задание для ARCH-агента (W0)
- `Sprint_8/changelog.md` — этот файл

### Источник backlog
`Спринты/Sprint_8_Review/backlog.md` — 25+ карточек:
- 6 e2e missing spec'ов (S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17)
- 11 DEFERRED-S8 из ARCH 7.R
- Post-S7 hotfix-карточки (multiplexer singleton root cause, API paginated audit, ErrorBoundary, dashboard health/sparkline, strategy status UI, CI Node 24, lint warnings)

### Что дальше
1. Заказчик подтверждает старт W0.
2. ARCH-агент запускается с `prompt_ARCH_design.md` → создаёт `arch_design_s8.md`.
3. По итогам W0 — DEV-промпты + QA-промпт + e2e_test_plan_s8.md.

---

## 2026-05-12 — W0 ARCH-design черновик создан

### Что
- Preflight checklist пройден: baseline 1024 backend / 468 frontend / 142 nightly / 9 lint warnings (известный долг)
- Coverage report собран: TOTAL **71%** (цель 80%, gap ≈1140 строк)
- 13 event_type publishers сверены grep'ом (12 в EVENT_MAP — discrepancy)
- Paginated endpoints аудит: 2 endpoint'а с `response_model=PaginatedResponse`
- `arch_design_s8.md` создан (581 строка, 8 секций, 30 карточек × роли × часы × эпики)

### Файлы
- `Sprint_8/arch_design_s8.md` — новый, основной артефакт W0
- `Sprint_8/sprint_state.md` — обновлён («W0 IN-PROGRESS»)

### Что дальше (gate W0 → W1)
Заказчик отвечает на 10 TODO из секции 11 `arch_design_s8.md`:
1. S5R-BLOCKLY-MODE-B — реализовать или удалить?
2. S6R-AICHAT-APPLY-MOCK — дополнить мок или удалить skip?
3. Coverage gate `--cov-fail-under=80` — W3 S8 или S9?
4. Security audit instrument — добавить bandit + safety в CI?
5. Lighthouse CI — подключить в playwright-nightly?
6. Prometheus/Grafana — scope S8 или S9?
7. `s7-backup.spec.ts` — Playwright (child_process) или pytest integration?
8. `s7-events.spec.ts` — реализовать `_test/emit-event` endpoint?
9. 13-й event_type — найти/удалить/добавить?
10. Deployment target — Docker + systemd / Kubernetes / Bare-metal?

После ответов — создание prompt_DEV-1..N.md + prompt_QA.md + e2e_test_plan_s8.md.

---

## 2026-05-12 — W0 ЗАВЕРШЁН, gate W0 → W1 пройден

### Что
Все 10 TODO утверждены заказчиком + введён новый эпик **Admin role + admin panel**:

| TODO | Решение |
|---|---|
| #1 Blockly mode B | Удалить 2 spec'а (фича удалена в S5/S6) |
| #2 AIChat apply mock | Дополнить мок в W2 (~2ч) |
| #3 Coverage gate | Включить `--cov-fail-under=80` в W3 S8 |
| #4 Security tools | `bandit` + `safety` в CI с W1 |
| #5 Lighthouse | Нет, performance вручную |
| #6 Performance mon | structlog + Plotly Dash `/admin/metrics` (W2) |
| #7 backup spec | pytest integration, не Playwright |
| #8 events spec | Mock WS frame из Playwright |
| #9 13/12 event_type | Полная синхронизация UI ↔ EVENT_MAP в W2 (~12ч) |
| #10 Deployment | Docker compose на Mac mini + launchd + Cloudflare Tunnel |
| **NEW** | **Admin role + admin panel в W1 (~11ч)** |

### Findings W0

- **Coverage 71% TOTAL** (12679 строк, 3632 непокрыто) — gap до 80% = ≈1140 строк
- **Critical-path coverage gaps:** `notification/dispatchers.py` 0%, `broker/tinvest/adapter.py` 24%, `backtest/router.py` 25%, `trading/service.py` 51%, `market_data/service.py` 50%, `strategy/service.py` 52%
- **Event type discrepancy:** UI имеет 13, EVENT_MAP 12, расхождение в обе стороны:
  - В UI, но не в backend (5): session_recovered, backtest_completed, daily_stats, corporate_action, price_alert
  - В backend, но не в UI (4): session_started, session_stopped, order_placed, trade_filled
- **Roles model отсутствует:** в `users` таблице нет `is_admin` → admin/user разделение требуется для production (новый эпик)

### Файлы изменены/созданы
- `Sprint_8/arch_design_s8.md` — расширен секциями 11-12 (решения по TODO + готовность к W1)
- `Sprint_8/execution_order.md` — финальная разбивка W1/W2/W3 потоков с новыми эпиками + 9 Cross-DEV contracts
- `Sprint_8/sprint_state.md` — текущий шаг «W0 ЗАВЕРШЁН»

### Что дальше (W1 запускается)
1. ARCH создаёт prompt_DEV-1..N.md (6 ролей), prompt_QA.md, prompt_UX.md, prompt_ARCH_review.md
2. QA создаёт `e2e_test_plan_s8.md` по §5 arch_design
3. Создать ветку `s8/sprint-8` в Develop репо
4. Заказчик подтверждает старт W1 → начало 5 параллельных потоков (A/B/C/D/E/F)
