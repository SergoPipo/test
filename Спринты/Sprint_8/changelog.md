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
