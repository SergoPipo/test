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
