# Состояние проекта: Торговый терминал MOEX

> **Это главная точка входа для любой новой сессии Claude.**
> Прочитай этот файл первым, чтобы понять, где мы находимся.
>
> Последнее обновление: 2026-04-14

---

## Текущий спринт: S5 завершён → **Sprint_5_Review (внеплановое, 🔄 этап A завершён, этап B)** → S6

## Прогресс по спринтам

| Спринт | Название | Статус | Ключевой результат | Отчёт |
|--------|----------|--------|-------------------|-------|
| S1 | Фундамент | ✅ завершён | Auth, дашборд, CI, 68 тестов | Sprint_1/sprint_report.md |
| S2 | Данные и графики | ✅ завершён | Брокер, графики, шифрование, 175 тестов | Sprint_2/sprint_report.md |
| S3 | Стратегии + редактор | ✅ завершён | Blockly, Sandbox, CSRF, 320 тестов | Sprint_3/sprint_report.md |
| S4 | AI + бэктестинг | ✅ завершён | AI chat, Backtest Engine, 577 тестов | Sprint_4/sprint_report.md |
| S5 | Торговля | ⚠️ завершён с замечаниями | Trading Engine, Paper Trading, Circuit Breaker, Bond/Tax, 548 тестов + 23 E2E. **Выявлен High-долг:** CI красный, Live Runtime Loop не замкнут, реальные позиции T-Invest — заглушки. Устраняется в Sprint_5_Review. | Sprint_5/arch_review_s5.md |
| **S5 Review** | **Внеплановое ревью: стабилизация перед S6** | **🔄 этап A завершён → этап B (промпты DEV)** | **CI cleanup + Live Runtime Loop + реальные позиции T-Invest + E2E S4 fix + обкатка prompt_template + актуализация ФТ/ТЗ. Первое практическое применение принятых 2026-04-14 правил работы DEV-субагентов.** | **Sprint_5_Review/README.md** |
| S6 | Уведомления | ⬜ не начат | Telegram, Email, In-app, Recovery, Graceful Shutdown | Sprint_6/sprint_report.md |
| S7 | Should-фичи | ⬜ не начат | Версионирование, экспорт | Sprint_7/sprint_report.md |
| S8 | Стабилизация | ⬜ не начат | Coverage 80%, security audit | Sprint_8/sprint_report.md |

**Легенда:** ⬜ не начат · 🔄 в процессе · ✅ завершён · ⚠️ завершён с замечаниями

## Что делать дальше

```
ТЕКУЩЕЕ ДЕЙСТВИЕ: Sprint_5_Review — внеплановое промежуточное ревью
  → Этап A (ЗАВЕРШЁН 2026-04-14): планирование, backlog, PENDING файлы, правки project_state и development_plan
  → Этап B (СЕЙЧАС): preflight_checklist.md + prompt_DEV-*.md по prompt_template.md + детализация Cross-DEV contracts
  → Этап C: выполнение 6 задач DEV/ARCH агентами
  → Этап D: финальное arch_review_s5r.md, закрытие S5R

ПОСЛЕ S5R: Sprint 6 — Уведомления (Telegram, Email, In-App, Recovery) в изначальном объёме
ПРЕДВАРИТЕЛЬНО: Sprint_6_Review после S5+S6 (обновить ФТ/ТЗ)

ФАЙЛ СОСТОЯНИЯ: Sprint_5_Review/README.md (текущее ревью)
```

## Ключевые решения (кросс-спринтовые)

_Решения, влияющие на несколько спринтов:_

| # | Дата | Решение | Влияет на | Принято кем |
|---|------|---------|-----------|-------------|
| 1 | 2026-03-24 | Sidebar сворачиваемый 240→60px | S1-S8 | Заказчик |
| 2 | 2026-03-24 | Footer с динамическим статус-баром 32px | S1-S2 | Заказчик |
| 3 | 2026-03-24 | Таблица с раскрываемыми строками (Вариант Б) | S1-S3 | Заказчик |
| 4 | 2026-03-24 | Тикеры с цветными иконками | S1 | Заказчик |
| 5 | 2026-03-27 | Бэктест нельзя запустить если: код устарел (блоки ≠ код) ИЛИ код содержит ошибки. Кнопка «Запустить бэктест» disabled + tooltip с причиной | S4-S5 | Заказчик |

## Технический долг

_Накапливается по мере продвижения, берётся из sprint_report.md:_

| # | Спринт | Описание | Приоритет | Когда исправить |
|---|--------|----------|-----------|-----------------|
| 1 | S1 | Footer со статическими данными | Low | Отложено (не критично) |
| 2 | S4 | 30+ E2E тестов S4 падают (AI Chat, Backtest, Blockly) | **High** (переоценено — блокер) | **Sprint_5_Review** (см. Sprint_5_Review/PENDING_S5R_e2e_s4_fix.md) |
| 3 | S5 | Реальные позиции и операции брокерского счёта T-Invest | Medium | **Sprint_5_Review** (см. Sprint_5_Review/PENDING_S5R_real_account_positions_operations.md) |
| 4 | S5 | **Live Runtime Loop не замкнут:** `SignalProcessor.process_candle()` реализован, но нигде не вызывается. Стрим свечей и торговые сессии существуют независимо, у `TradingSession` нет поля `timeframe`, `scheduler/service.py` пуст. ARCH-ревью S5 формально принял класс SignalProcessor, но интеграцию не проверил. Архитектура в ТЗ описана ([technical_specification.md:1396-1417](../Документация%20по%20проекту/technical_specification.md)), но не реализована. | **High** | **Sprint_5_Review** (см. Sprint_5_Review/PENDING_S5R_live_runtime_loop.md) |
| 5 | S1-S5 (накопленный) | **CI красный 11+ дней.** Backend `ruff check .` падает на `F401 imported but unused` в `alembic/env.py` (ложные срабатывания — нужен `per-file-ignores`). Frontend `pnpm lint` падает на новых правилах React 19 (`react-hooks/refs`, `react-hooks/set-state-in-effect`, `react-hooks/incompatible-library`) + legacy `no-unused-vars`/`no-explicit-any` в e2e. Из-за `bash -e` в actions `mypy`/`pytest`/`tsc`/`vitest` ни разу не запускались после 2026-04-03. Обнаружено через Gmail MCP 2026-04-14. | **High** | **Sprint_5_Review** (см. Sprint_5_Review/PENDING_S5R_ci_cleanup.md) |

## Перенесённые задачи

_Задачи, не выполненные в спринте и перенесённые на следующий:_

| # | Из спринта | Задача | Перенесена в | Причина |
|---|------------|--------|-------------|---------|
| 1 | S4 (техдолг #2) | E2E S4 fix (30+ падающих тестов) | Sprint_5_Review | Блокирует Integration Verification в Sprint_5_Review и S6 |
| 2 | S5 (техдолг #3) | Реальные позиции/операции T-Invest | Sprint_5_Review | Первоначально запланировано в S6 как 6.9, перенесено выше из-за накопления долга перед S6 |
| 3 | S5 (техдолг #4) | Live Runtime Loop | Sprint_5_Review | Первоначально запланировано в S6 как 6.0, перенесено выше — блокер для всех остальных задач S6 |
| 4 | — (новый, 14.04) | CI cleanup | Sprint_5_Review | Блокер для Integration Verification Checklist из `prompt_template.md` |

## Промежуточные ревью

| Ревью | После спринтов | Milestone | Статус | Бэклог |
|-------|---------------|-----------|--------|--------|
| Sprint_2_Review | S1 + S2 | M1: Каркас | ✅ завершён | Sprint_2_Review/backlog.md |
| Sprint_4_Review | S3 + S4 | M2: Бэктест | ✅ завершён | Sprint_4_Review/backlog.md |
| **Sprint_5_Review** | S5 (внеплановое) | — (стабилизация перед M3 full scope) | **🔄 этап A завершён, этап B** | **Sprint_5_Review/backlog.md** |
| Sprint_6_Review | S5 + S6 | M3: Торговля | ⬜ не начат | Sprint_6_Review/backlog.md |
| Sprint_8_Review | S7 + S8 | M4: Production | ⬜ не начат | Sprint_8_Review/backlog.md |

## Milestones

| Milestone | Спринт | Статус | Критерии |
|-----------|--------|--------|----------|
| M1: Каркас | S1 | ✅ | Auth, дашборд, CI, 68 тестов |
| M2: Бэктест | S4 | ✅ | Стратегия → бэктест → результаты. Ревью: 21/28 задач исправлено, 7 отложено |
| M3: Paper Trading | S5 | ✅ | Paper Trading + Circuit Breaker + Bond НКД + Tax FIFO + 23 E2E. ARCH: PASS |
| M4: Production-ready | S8 | ⬜ | Coverage 80%, security, performance |

---

## Ссылки

| Документ | Путь |
|----------|------|
| Функциональные требования | Документация по проекту/functional_requirements.md |
| Техническое задание | Документация по проекту/technical_specification.md |
| План разработки | Документация по проекту/development_plan.md |
| Контекст для агентов | Develop/CLAUDE.md |
| Текущий спринт (детали) | Sprint_N/sprint_state.md |

---

## Как продолжить работу (инструкция для новой сессии)

1. Прочитай **этот файл** — пойми, на каком мы спринте
2. Перейди в папку текущего спринта → прочитай **sprint_state.md** — пойми, на каком мы шаге
3. Если нужен порядок работы → прочитай **execution_order.md**
4. Если нужен контекст проекта → прочитай **Develop/CLAUDE.md**
5. Выполни следующее действие из sprint_state.md
