# Sprint 8 — Стабилизация (M4 Production-ready)

> **Главная точка входа** для агентов, работающих в этом спринте.
> Состояние: см. `sprint_state.md`. Дизайн спринта будет создан ARCH на W0 в `arch_design_s8.md`.

## Цели M4

Закрытие production-readiness gap'ов после M3 Phase 1 (S7 feature-complete):

1. **Coverage ≥ 80%** по каждому модулю (unit + integration)
2. **Security audit** (crypto, sandbox escape, CSRF, headers, brute-force)
3. **Performance testing** (дашборд < 2с, сигнал→ордер < 500мс, Telegram < 3с)
4. **Регрессия E2E** + добавление 6 missing spec'ов (S7R-E2E-7.3/7.9/7.13/7.14/7.16/7.17)
5. **Закрытие S8 backlog** (~25 карточек: medium-high → medium → low)
6. **UX финальный юзабилити-тест** + UX-баги
7. **Документация** (README, deployment guide, итоговый changelog)
8. **8.R финальное ARCH-ревью + sign-off**

## Источник backlog

`Спринты/Sprint_8_Review/backlog.md` — 25+ карточек, перенесённых из:

- S7 W3 финального E2E (6 missing spec'ов)
- ARCH 7.R DEFERRED-S8 (11 карточек)
- Post-S7 hotfix'ов 2026-04-27 → 2026-05-12 (multiplexer singleton, paginated type mismatch, error boundary, dashboard health/sparkline, strategy status UI, CI Node 24, lint warnings cleanup)

Приоритезация:
- **Medium-high (3 шт):** DRAWING-EDITING, STRATEGY-STATUS-CHANGE-UI, API-PAGINATED-TYPE-MISMATCH
- **Medium (~10):** 6 E2E missing, GRID-HEATMAP, ORDER-MANAGER-REAL, DRAWING-INTRADAY-COORDS, SPARKLINE-24H, WIZARD-TG-TEST, ERROR-BOUNDARY, BALANCE-SPARKLINE-RANGE, HEALTH-EXTENDED, MULTIPLEXER-SINGLETON
- **Low (~10):** HEALTH-WS, MULTICURRENCY, AUTOCOLLAPSE, MANTINE-TOOLTIP, CONNECTION-MARKET-CLOSED, STRATEGY-STATUS-PAUSED, STRATEGY-STATUS-ENUM-DRIFT, CI-NODE24, FE-LINT-WARNINGS

## Файлы

| Файл | Назначение |
|------|-----------|
| sprint_state.md | Текущий шаг (обновляется по ходу) |
| execution_order.md | Порядок W0/W1/W2/W3 + приоритеты backlog |
| preflight_checklist.md | Чек окружения перед стартом |
| arch_design_s8.md | Итог W0 ARCH-design (создаётся ARCH в W0) |
| changelog.md | Лог изменений (обновляется немедленно) |
| arch_review_s8.md | Финальное 8.R ARCH-ревью (создаётся в день 14) |

## Промпты

| Файл | Агент | Этап |
|------|-------|------|
| prompt_ARCH_design.md | ARCH | W0 |
| prompt_DEV-1.md … prompt_DEV-N.md | DEV | W1 + W2 (создаются по итогам W0 ARCH-design) |
| prompt_QA.md | QA | W0 (E2E план) + W1 + W3 |
| prompt_UX.md | UX | W3 (юзабилити-тест) |
| prompt_ARCH_review.md | ARCH | W3 (8.R) |

## Старт

1. Прочитай `Спринты/project_state.md` — пойми, где мы.
2. Прочитай `Sprint_8/sprint_state.md` — пойми текущий шаг.
3. Прочитай `Sprint_8/execution_order.md` — пойми порядок.
4. Прочитай `Sprint_8_Review/backlog.md` — пойми источник задач.
5. Запусти ARCH-агента с `prompt_ARCH_design.md` для W0 design-фазы.
