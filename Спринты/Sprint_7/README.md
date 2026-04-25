# Sprint 7 — Should-фичи + 6 переносов из S6 + AI-команды

> **Главная точка входа** для агентов, работающих в этом спринте.
> Состояние: см. `sprint_state.md`. Дизайн спринта: см. `sprint_design.md`.

## Файлы

| Файл | Назначение |
|------|-----------|
| sprint_design.md | Дизайн спринта (spec, утверждён 2026-04-25) |
| sprint_implementation_plan.md | План создания файлов спринта (этот этап) |
| sprint_state.md | Текущий шаг (обновляется по ходу) |
| execution_order.md | Порядок W0/W1/midsprint/W2/W3 + Cross-DEV contracts |
| preflight_checklist.md | Чек окружения перед стартом |
| e2e_test_plan_s7.md | План E2E (заполняется QA на W0) |
| arch_design_s7.md | Итог W0 ARCH-design ревью (создаётся ARCH в W0) |
| changelog.md | Лог изменений (обновляется немедленно) |
| midsprint_check.md | Гейт между W1 и W2 (создаётся в день 7) |
| ui_checklist_s7.md | Обновлённый чеклист UI (создаётся на W3) |
| arch_review_s7.md | Финальное ARCH-ревью (создаётся в день 14) |

## Промпты

| Файл | Агент | Этап |
|------|-------|------|
| prompt_ARCH_design.md | ARCH | W0 |
| prompt_UX.md | UX | W0 + W3 |
| prompt_QA.md | QA | W0 + W1 + W3 |
| prompt_DEV-1.md | BACK1 | W1 + W2 |
| prompt_DEV-2.md | BACK2 | W1 + W2 |
| prompt_DEV-3.md | FRONT1 | W1 + W2 |
| prompt_DEV-4.md | FRONT2 | W2 |
| prompt_DEV-5.md | OPS | W2 |
| prompt_ARCH_review.md | ARCH | W3 (7.R) |

## UX-макеты (Sprint_7/ux/)

| Файл | Покрывает |
|------|-----------|
| dashboard_widgets.md | 7.7 |
| wizard_5steps.md | 7.8 |
| drawing_tools.md | 7.6 |
| backtest_overview_analytics.md | 7.16 |
| background_backtest_badge.md | 7.17 |
| ai_commands_dropdown.md | 7.19 |

## Отчёты (Sprint_7/reports/)

DEV/ARCH/UX/QA сохраняют 8-секционные отчёты как файлы (правило S5R.5).

## Старт

1. Прочитай `Спринты/project_state.md` — пойми где мы.
2. Прочитай `Sprint_7/sprint_state.md` — пойми текущий шаг.
3. Прочитай `Sprint_7/execution_order.md` — пойми порядок.
4. Возьми нужный `prompt_*.md` — выполни задачу.
5. Сохрани отчёт в `reports/`. Обнови `changelog.md` немедленно.
