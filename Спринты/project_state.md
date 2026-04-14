# Состояние проекта: Торговый терминал MOEX

> **Это главная точка входа для любой новой сессии Claude.**
> Прочитай этот файл первым, чтобы понять, где мы находимся.
>
> Последнее обновление: 2026-04-14 (после закрытия Sprint_5_Review)

---

## Текущий спринт: S5 ✅ + **Sprint_5_Review ✅ завершён** → **S6 готов к старту**

## Прогресс по спринтам

| Спринт | Название | Статус | Ключевой результат | Отчёт |
|--------|----------|--------|-------------------|-------|
| S1 | Фундамент | ✅ завершён | Auth, дашборд, CI, 68 тестов | Sprint_1/sprint_report.md |
| S2 | Данные и графики | ✅ завершён | Брокер, графики, шифрование, 175 тестов | Sprint_2/sprint_report.md |
| S3 | Стратегии + редактор | ✅ завершён | Blockly, Sandbox, CSRF, 320 тестов | Sprint_3/sprint_report.md |
| S4 | AI + бэктестинг | ✅ завершён | AI chat, Backtest Engine, 577 тестов | Sprint_4/sprint_report.md |
| S5 | Торговля | ⚠️ завершён с замечаниями (долг устранён в S5R) | Trading Engine, Paper Trading, Circuit Breaker, Bond/Tax, 548 тестов + 23 E2E | Sprint_5/arch_review_s5.md |
| **S5 Review** | **Внеплановое ревью: стабилизация перед S6** | **✅ завершён** | **CI зелёный впервые с 2026-04-03, Live Runtime Loop замкнут, реальные позиции T-Invest, 101 Playwright passed, 10 Stack Gotchas, 2 бизнес-бага починены. Вердикт ARCH: PASS WITH NOTES, блокеров нет.** | **Sprint_5_Review/arch_review_s5r.md** |
| S6 | Уведомления | ⬜ готов к старту | Telegram, Email, In-app, Recovery, Graceful Shutdown + S6-MODEL-FIGI + S6-PLAYWRIGHT-NIGHTLY + 3 E2E fix | Sprint_6/sprint_report.md |
| S7 | Should-фичи | ⬜ не начат | Версионирование, экспорт | Sprint_7/sprint_report.md |
| S8 | Стабилизация | ⬜ не начат | Coverage 80%, security audit | Sprint_8/sprint_report.md |

**Легенда:** ⬜ не начат · 🔄 в процессе · ✅ завершён · ⚠️ завершён с замечаниями

## Что делать дальше

```
ТЕКУЩЕЕ ДЕЙСТВИЕ: Sprint 6 — Уведомления + накопленный backlog S5R
  → 6.0 — скипнуто (Live Runtime Loop замкнут в S5R)
  → 6.3 — In-app уведомления (EventBus канал trades:{session_id} с 6 событиями готов из S5R)
  → 6.4 — Recovery (SessionRuntime.restore_all готов, дополнить real-side StreamManager.subscribe)
  → 6.5 — Graceful Shutdown (SessionRuntime.shutdown готов, добавить сохранение pending событий)
  → 6.6 — Telegram/Email/In-App интеграции
  → 6.9 — скипнуто (реальные позиции T-Invest готовы из S5R)
  → 6.11 — S6-MODEL-FIGI: FIGI в LiveTrade/Order, source-правило на FIGI

ДОП.БЭКЛОГ S6 (из Sprint_5_Review arch_review секция 8):
  → S6-PLAYWRIGHT-NIGHTLY — отдельный cron-workflow в рабочие часы MSK
  → S6-E2E-FAVORITES-INPUT — text-input в FavoritesPanel + снять skip ×4
  → S6-E2E-PAPER-REAL-MODE — fixture non-sandbox, снять skip ×1
  → S6-E2E-CHART-MOCK-ISS — моки ISS для нерабочих часов, снять skip ×3

ПРЕДВАРИТЕЛЬНО: Sprint_6_Review после S6 (обновить ФТ/ТЗ по новому объёму S6)

ФАЙЛ СОСТОЯНИЯ: Sprint_6/sprint_state.md (когда S6 откроется)
ПОСЛЕДНЕЕ РЕВЬЮ: Sprint_5_Review/arch_review_s5r.md (вердикт PASS WITH NOTES)
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

| # | Спринт | Описание | Приоритет | Статус |
|---|--------|----------|-----------|--------|
| 1 | S1 | Footer со статическими данными | Low | Отложено (не критично) |
| 2 | S4 | 30+ E2E тестов S4 падают | ~~High~~ | ✅ **Закрыт S5R.4** (DEV-1 волна 2, 101 passed / 0 failed) |
| 3 | S5 | Реальные позиции/операции T-Invest | ~~Medium~~ | ✅ **Закрыт S5R.3** (DEV-3, endpoints работают с реальными данными) |
| 4 | S5 | Live Runtime Loop не замкнут | ~~High~~ | ✅ **Закрыт S5R.2** (DEV-2, `runtime.py:374` — единственная production-точка `process_candle`) |
| 5 | S1-S5 | CI красный 11+ дней | ~~High~~ | ✅ **Закрыт S5R.1** (DEV-1 волна 1+1b, зелёный CI, 10 Stack Gotchas) |

**Текущий High-долг: 0.** Все блокеры, выявленные до S5R, закрыты полностью.

## Перенесённые задачи

_Все 4 перенесённые задачи из S4/S5 закрыты в Sprint_5_Review 2026-04-14:_

| # | Из спринта | Задача | Перенесена в | Статус |
|---|------------|--------|-------------|--------|
| 1 | S4 (техдолг #2) | E2E S4 fix | Sprint_5_Review | ✅ закрыта (S5R.4) |
| 2 | S5 (техдолг #3) | Реальные позиции T-Invest | Sprint_5_Review | ✅ закрыта (S5R.3) |
| 3 | S5 (техдолг #4) | Live Runtime Loop | Sprint_5_Review | ✅ закрыта (S5R.2) |
| 4 | — (новый 14.04) | CI cleanup | Sprint_5_Review | ✅ закрыта (S5R.1) |

## Промежуточные ревью

| Ревью | После спринтов | Milestone | Статус | Отчёт |
|-------|---------------|-----------|--------|-------|
| Sprint_2_Review | S1 + S2 | M1: Каркас | ✅ завершён | Sprint_2_Review/backlog.md |
| Sprint_4_Review | S3 + S4 | M2: Бэктест | ✅ завершён | Sprint_4_Review/backlog.md |
| **Sprint_5_Review** | S5 (внеплановое) | — (стабилизация M3) | **✅ завершён (PASS WITH NOTES)** | **Sprint_5_Review/arch_review_s5r.md** |
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
