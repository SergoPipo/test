# Sprint 7 Design — Should-фичи + 6 переносов из S6 + AI-команды

> **Статус документа:** черновик от 2026-04-25 (после Sprint 6 Review).
> **Тип:** spec для последующего разворачивания через `superpowers:writing-plans` skill в полный набор файлов спринта.
> **Канонический путь (брейнштром-скил):** `docs/superpowers/specs/2026-04-25-sprint-7-design.md` (указатель на этот файл).
> **Базовая ветка:** `main`. Рабочая ветка планирования: `docs/sprint-7-plan` (имя — на подтверждении заказчика).

---

## Оглавление

1. [Цели и Definition of Done](#1-цели-и-definition-of-done)
2. [Состав работ + распределение по DEV](#2-состав-работ--распределение-по-dev)
3. [W0 + midsprint + расписание](#3-w0--midsprint--расписание)
4. [Структура файлов спринта](#4-структура-файлов-спринта)
5. [Метаданные планирования и переход к writing-plans](#5-метаданные-планирования-и-переход-к-writing-plans)
6. [Приложение A — Cross-DEV contracts (полная таблица)](#приложение-a--cross-dev-contracts-полная-таблица)
7. [Приложение B — Календарный график W0/W1/W2/W3](#приложение-b--календарный-график-w0w1w2w3)
8. [Приложение C — Маппинг 5 event_type ↔ publish-сайтов (MR.5)](#приложение-c--маппинг-5-event_type--publish-сайтов-mr5)
9. [Приложение D — Список UX-макетов](#приложение-d--список-ux-макетов)

---

## 1. Цели и Definition of Done

### 1.1 Цель спринта

Завершить **Phase 1 feature-complete** — закрыть весь долг S6 (6 переносов), реализовать оставшиеся Should-функции, добавить AI слэш-команды. После S7 проект готов к S8 (feature freeze + регрессия + security audit + production-ready).

### 1.2 Milestone

S7 не завершает M-вех (M3 уже достигнут в Sprint_6_Review, 2026-04-24). S7 — последний feature-спринт перед M4 (Production-ready), который закрывается в S8.

### 1.3 Definition of Done — критерии закрытия S7

1. **Все 17 задач закрыты с integration verification.** Каждый DEV в отчёте подтверждает `grep -rn "<NewClass>(" app/` + ссылку на production call site. Помеченные `⚠️ NOT CONNECTED` блокируют приёмку (правило CLAUDE.md, Sprint 6+).
2. **E2E S7 пройдено по полному циклу:** `e2e_test_plan_s7.md` (описание ДО написания тестов) → запуск backend+frontend → `npx playwright test` → результат в `arch_review_s7.md`. Регрессия не хуже S6 Review baseline (**119 passed / 0 failed / 3 skipped**) + ≥ 15 новых E2E под фичи S7.
3. **ARCH-приёмка (7.R):** Stack Gotchas обновлены (новый `gotcha-NN-*.md` + строка в `INDEX.md` для каждой найденной ловушки), все Cross-DEV контракты подтверждены, MR.5 проверка из `Спринты/project_state.md:79–90` (5 event_type подключены к runtime — задача 7.13).
4. **UX-приёмка:** макеты W0 совпадают с реализацией; `ui_checklist_s7.md` дополнен новыми проверками S7 (правило `feedback_ui_checklist_update.md`).
5. **Документация синхронизирована:** ФТ (`functional_requirements.md`), ТЗ (`technical_specification.md`), `development_plan.md` обновлены за S7 (правило `feedback_review_docs.md`, закреплено как стандарт в S6 Review).
6. **Логи спринта актуальны:** `changelog.md` ведётся **немедленно** после каждого блока изменений; `sprint_state.md` отражает текущий шаг (правило `feedback_changelog_immediate.md`).
7. **Критерий готовности к S8:** feature freeze возможен — никаких WIP, `NOT CONNECTED`, незакрытых E2E.

### 1.4 Что S7 НЕ делает (вне scope, явно)

- Никаких новых Phase 2 идей. `Спринты/Планы на развитие/` обновляется только если в ходе S7 что-то найдено.
- Coverage / performance / security audit — это S8.
- Новые форматы экспорта бэктестов сверх CSV/PDF (например, Excel-расширенный) — нет.
- Расширение списка AI-команд сверх 5 утверждённых (`/chart`, `/backtest`, `/strategy`, `/session`, `/portfolio`) — нет.

---

## 2. Состав работ + распределение по DEV

### 2.1 Задачи S7 (всего 17 + 7.10 UX полировка + 7.11 E2E)

#### Блок A — Should-фичи (8 задач, новый функционал)

| # | Задача | Исполнитель | Источник |
|---|--------|-------------|----------|
| 7.1 | Версионирование стратегий (история, откат) | BACK2 + FRONT2 | development_plan.md (RACI: Strategy Engine = BACK2) |
| 7.2 | Grid Search оптимизация параметров (multiprocessing) | BACK1 + FRONT2 | development_plan.md |
| 7.3 | Экспорт CSV/PDF бэктеста (WeasyPrint + openpyxl) | BACK2 | development_plan.md |
| 7.6 | Инструменты рисования на графике (тренды, уровни, зоны) | FRONT1 | development_plan.md |
| 7.7 | Дашборд: виджет баланса, health, sparklines, мини-графики | FRONT1 + FRONT2 | development_plan.md |
| 7.8 | Дисклеймер (first-run wizard, 5 шагов) | FRONT2 + BACK2 | development_plan.md |
| 7.9 | Backup/restore (автобэкап, ротация, CLI восстановление) | OPS + BACK1 | development_plan.md |
| 7.10 | UX: финальная полировка UI, консистентность | UX | development_plan.md |
| 7.11 | E2E S7: полный цикл (план → инфра → тесты → запуск → верификация) | QA | development_plan.md + `feedback_e2e_testing.md` |

#### Блок B — Переносы из S6 (6 задач)

| # | Задача | Исполнитель | Класс |
|---|--------|-------------|-------|
| 7.12 | NotificationService singleton через DI (убрать 9 инстансов) | BACK2 | technical debt |
| 7.13 | Подключение 5 event_type к runtime (`trade_opened`, `partial_fill`, `order_error`, `all_positions_closed`, `connection_lost/restored`) | BACK1 | technical debt |
| 7.14 | Telegram inline-кнопки (CallbackQueryHandler для `open_session:{id}` / `open_chart:{id}`) | BACK2 | technical debt |
| 7.15 | WS-обновление карточек сессий (заменить polling 10s) | BACK1 + FRONT1 | new feature (отложен из S6) |
| 7.16 | Интерактивные зоны бэктеста + аналитика (гистограмма P&L + donut Win/Loss) | FRONT1 | new feature (отложен из S6) |
| 7.17 | Фоновый запуск бэктеста (параллельные, бейдж в шапке) | BACK1 + FRONT1 | new feature (отложен из S6) |

#### Блок C — AI слэш-команды (новое в S7, требует обновления ФТ/ТЗ/плана)

| # | Задача | Исполнитель | Источник |
|---|--------|-------------|----------|
| 7.18 | AI слэш-команды backend: расширение `ChatRequest.context`, парсинг команд, защита от prompt injection | BACK2 | `.claude/plans/purring-herding-badger.md` (план утверждён) |
| 7.19 | AI слэш-команды frontend: dropdown с 5 командами, рендер «контекстных блоков» в чате | FRONT1 | тот же план |

> **Обоснование:** в `Спринты/project_state.md` Sprint 7 уже отмечен как «Should-фичи + переносы». Команды добавляются по решению заказчика от 2026-04-25 (выбор A на вопрос «куда определяем AI-команды»).

#### Блок D — Архитектурное ревью

| # | Задача | Исполнитель |
|---|--------|-------------|
| 7.R | Финальное ARCH-ревью + QA-приёмка + UX-приёмка | ARCH + QA + UX |

### 2.2 RACI-корректировка относительно `development_plan.md` v2

В плане для 7.1 и 7.12 указан BACK1, но это противоречит RACI-матрице (Strategy Engine = BACK2 R, Notification Service = BACK2 R). Перевыставляем:

| Задача | План (v2) | RACI | Решение |
|--------|-----------|------|---------|
| 7.1 Версионирование стратегий | BACK1+FRONT2 | Strategy Engine: BACK2 R | **BACK2** + FRONT2 |
| 7.12 NS singleton | BACK1 | Notification Service: BACK2 R | **BACK2** |

`development_plan.md` будет обновлён в задаче 7.R.

### 2.3 Треки исполнения по DEV

```
BACK1 (Backtest + Trading источники):
  W1: 7.13   5 event_type → runtime/engine.py (debt)
  W1: 7.15-be WS endpoint /ws/trading-sessions/{user_id}
  W1: 7.17-be WS endpoint /ws/backtest/{job_id} + параллельные jobs
  W2: 7.2-be Grid Search backend (multiprocessing)
  W2: 7.9    Backup/restore (с OPS)

BACK2 (Strategy + Notification + AI + Telegram):
  W1: 7.12   NS singleton (DI через app.state) (debt)
  W1: 7.14   Telegram CallbackQueryHandler (debt)
  W2: 7.1-be Версионирование стратегий (миграция + endpoints)
  W2: 7.3    Экспорт CSV/PDF
  W2: 7.8-be Wizard backend (флаг users.wizard_completed_at)
  W2: 7.18   AI слэш-команды backend (расширение ChatRequest.context)

FRONT1 (Charts + Trading panel + AI chat UX):
  W1: 7.16   Интерактивные зоны + аналитика (debt — перенос из S6)
  W1: 7.15-fe WS-замена polling карточек сессий
  W1: 7.17-fe Toast + бейдж + dropdown в шапке
  W2: 7.6    Инструменты рисования (lightweight-charts)
  W2: 7.19   AI слэш-команды frontend (dropdown + рендер контекста)
  W2: саппорт 7.7 — sparklines, использовать chart-обёртку

FRONT2 (Dashboard + Strategy editor + Settings):
  W1: — нет debt → подключается к W0 UX-design консультациям
  W2: 7.1-fe Версионирование UI (history, diff, восстановить)
  W2: 7.7    Дашборд-виджеты (баланс, health, sparklines)
  W2: 7.8-fe First-run wizard (5 шагов)
  W2: 7.2-fe Grid Search UI (форма + heatmap)

OPS:
  W2: 7.9    Backup/restore: автоскрипт, ротация, CLI восстановление, smoke-тест
  W2: саппорт 7.11 запуск backend+frontend в E2E

ARCH:
  W0: design ревью (версионирование, фоновые бэктесты, AI-команды, WS-канал)
  W1: проверка контрактов после каждой debt-задачи
  Midsprint check (после W1) — cross-DEV contracts verification + Stack Gotchas update
  W2: ревью DEV-отчётов
  7.R: финальное ARCH-ревью + проверка MR.5 (5 event_type подключены)

UX:
  W0: 6 макетов — дашборд-виджеты, wizard 5 шагов, инструменты рисования,
     гистограмма P&L + donut Win/Loss, бейдж фоновых бэктестов в шапке,
     dropdown AI-команд + рендер контекста в чате
  Midsprint UX-review реализации W1
  W3: 7.10 финальная полировка

QA:
  W0: e2e_test_plan_s7.md (описание сценариев ДО написания тестов)
  W1: E2E под debt-задачи (7.13–7.17)
  W2/W3: E2E под фичи + регрессия 119 baseline + 7.11 финальный прогон

SEC:
  Ревью 7.13 (event leakage), 7.14 (callback origin validation),
  7.18 (AI command injection защита)
```

### 2.4 Cross-DEV контракты — краткая сводка

См. полную таблицу в [Приложении A](#приложение-a--cross-dev-contracts-полная-таблица). Ключевые контракты:

- **C1, C2, C5 — WS-каналы:** BACK1 публикует пустой WS-эндпоинт + JSON-схему первой; FRONT1/FRONT2 пишут клиент по схеме; интеграция — после реальной публикации сообщений. Перевод polling→WS делается ровно одним PR.
- **C3 — AI context:** BACK2 первым публикует расширение схемы запроса; FRONT1 идёт по уже задокументированному формату.
- **C4 — versioning:** Alembic-миграция от BACK2 — ПЕРВОЕ, что делается в треке (FRONT2 не стартует пока schema не закоммичена).
- **C7 — NS singleton:** одной волной правится во всех вызывающих модулях. После завершения 7.12 в коде должно быть `grep -rn "NotificationService()" app/` = 0 совпадений вне `main.py`.

---

## 3. W0 + midsprint + расписание

### 3.1 W0 — Pre-sprint Design (дни 1–2, ДО запуска DEV-агентов)

#### 3.1.1 UX-макеты (исполнитель UX, складываются в `Sprint_7/ux/`)

См. [Приложение D](#приложение-d--список-ux-макетов) — 6 макетов.

#### 3.1.2 ARCH design-ревью (исполнитель ARCH, итог в `Sprint_7/arch_design_s7.md`)

Брейнштормы по крупным/межмодульным задачам **до** написания DEV-промптов (правило CLAUDE.md «3+ модуля или критический путь» + использование skill `superpowers:brainstorming`):

| Задача | Что решается на W0 |
|--------|---------------------|
| 7.1 Версионирование | Модель `strategy_versions`: что хранить (blocks_xml + code? только diff?), миграция, политика автоверсий, чем считать «откат», совместимость с redis-кэшем |
| 7.2 Grid Search | Параллелизация (multiprocessing.Pool / asyncio + Semaphore), как ограничивать N комбинаций (защита от 10^6), shape матрицы результата, переиспользование `/ws/backtest/` канала C2 |
| 7.15 WS sessions | Авторизация JWT в WS, реконнект, content (snapshot vs delta-events), как избежать двойного источника правды с polling-fallback |
| 7.17 фоновый бэктест | Управление N одновременных jobs на пользователя, очередь, ресурсные лимиты, как один WS-канал переиспользует BackgroundTasks |
| 7.18 AI commands | Расширение `ChatRequest.context`, защита от prompt injection (валидация id принадлежит user), формат enriched prompt, кэширование |
| 7.13 5 event_type | Какие именно publish-сайты в `trading/runtime.py` и `trading/engine.py`, contract с EVENT_MAP, цитировать MR.5 из `project_state.md:79–90` (см. [Приложение C](#приложение-c--маппинг-5-event_type--publish-сайтов-mr5)) |

#### 3.1.3 TDD-обязательные блоки

По CLAUDE.md «TDD: Red-Green-Refactor для trading/circuit_breaker/sandbox»:

- **7.13** (trading-engine source) — TDD обязателен.
- **7.12** (DI-рефакторинг с поломкой существующих тестов) — TDD обязателен.
- **7.2** (backtest grid — критическая ветка вычислений) — TDD обязателен.

Через skill `superpowers:test-driven-development`.

#### 3.1.4 Stack Gotchas pre-read

Каждый DEV-промпт цитирует релевантные строки `Develop/stack_gotchas/INDEX.md`. ARCH в W0 проходит INDEX и подсвечивает 5–7 ключевых ловушек на S7:

1. WS reconnect и cleanup (gotcha-04 или релевантный)
2. Alembic auto-generate gotchas
3. T-Invest tz-naive→aware (gotcha-15)
4. lightweight-charts series cleanup (для 7.6 инструментов рисования)
5. Mantine modal lifecycle (для 7.8 wizard)
6. SQLAlchemy session per-request (для 7.1 versioning)
7. 401 cleanup+guard (gotcha-16)

#### 3.1.5 QA pre-sprint

`e2e_test_plan_s7.md` — описание ВСЕХ сценариев ДО написания тестов (правило `feedback_e2e_testing.md`). Структура: для каждой задачи 7.x — список сценариев, предусловия, шаги, ожидаемый результат. Берётся за основу `Спринты/ui_checklist_s5r.md` + новые проверки.

Аккаунт для тестов: `sergopipo` (память `user_test_credentials.md`; пароль запрашивается у заказчика).

### 3.2 Midsprint Checkpoint (день 7, после закрытия W1)

**Гейт перед запуском W2.** Цель — не пускать новые фичи на сломанный фундамент.

Чек-лист (исполнитель ARCH, итог в `Sprint_7/midsprint_check.md`):

1. **Все 6 переносов закрыты с integration verification.** Для 7.13 — отдельная проверка по MR.5: каждый из 5 event_type производит `create_notification` в production-коде (не только в тестах). См. [Приложение C](#приложение-c--маппинг-5-event_type--publish-сайтов-mr5).
2. **Контракты W1 (C1, C2, C7, C8) подтверждены.** `grep -rn "NotificationService()" app/` = 0 вне `main.py`.
3. **Регрессия E2E baseline 119 passed / 0 failed** не сломана. Если хоть один тест упал из-за W1 — стоп.
4. **Stack Gotchas обновлены:** новые `gotcha-NN-*.md` за каждую найденную ловушку + строки в `INDEX.md`.
5. **UX-приёмка W0-макетов реализацией 7.16, 7.15-fe, 7.17-fe.** UX подтверждает соответствие или фиксирует delta для 7.10.
6. **Логи синхронизированы:** `changelog.md` ведётся, `sprint_state.md` отражает шаг.

**Если гейт провален:** W2 не стартует. Любые проблемы W1 закрываются волной фиксов до запуска W2.

### 3.3 Расписание

См. [Приложение B](#приложение-b--календарный-график-w0w1w2w3). Базовый календарь — ~14 рабочих дней (3 недели). При расширении W1/W2 — пролонгация (заказчик подтвердил: «делаем всё, время гибкое»).

---

## 4. Структура файлов спринта

```
Sprint_7/
├── README.md                       — навигация по спринту
├── sprint_design.md                — этот документ (spec)
├── execution_order.md              — порядок W0/W1/midsprint/W2/W3 + Cross-DEV contracts
├── sprint_state.md                 — текущий шаг, обновляется по ходу
├── preflight_checklist.md          — проверка окружения до старта
│   (Python ≥ 3.11, Node ≥ 18, .venv, pnpm install, alembic upgrade head,
│    npx playwright --version, npx playwright install,
│    backend+frontend поднимаются, baseline pytest/vitest/playwright = green)
├── e2e_test_plan_s7.md             — описание ВСЕХ E2E-сценариев ДО написания тестов
├── arch_design_s7.md               — итог W0 ARCH-design ревью
├── changelog.md                    — лог изменений по дням, обновляется немедленно
│
├── reports/                        — DEV-отчёты (S5R.5 правило: отчёт-как-файл)
│   ├── DEV-1_BACK1_W1.md
│   ├── DEV-1_BACK1_W2.md
│   ├── DEV-2_BACK2_W1.md
│   ├── DEV-2_BACK2_W2.md
│   ├── DEV-3_FRONT1_W1.md
│   ├── DEV-3_FRONT1_W2.md
│   ├── DEV-4_FRONT2_W2.md
│   ├── DEV-5_OPS_W2.md
│   ├── ARCH_W0_design.md
│   ├── ARCH_midsprint_check.md
│   ├── UX_W0_design.md
│   ├── UX_midsprint_review.md
│   └── QA_W0_test_plan.md
│
├── ux/                             — UX-макеты W0
│   ├── dashboard_widgets.md
│   ├── wizard_5steps.md
│   ├── drawing_tools.md
│   ├── backtest_overview_analytics.md
│   ├── background_backtest_badge.md
│   └── ai_commands_dropdown.md
│
├── prompt_ARCH_design.md           — задание ARCH на W0 (design ревью)
├── prompt_ARCH_review.md           — задание ARCH на W3 (финальное 7.R)
├── prompt_UX.md                    — задание UX на W0 + W3 (7.10)
├── prompt_QA.md                    — задание QA на W0 + W1 + W3 (7.11)
├── prompt_DEV-1.md (BACK1)         — 7.13, 7.15-be, 7.17-be, 7.2-be, 7.9
├── prompt_DEV-2.md (BACK2)         — 7.12, 7.14, 7.1-be, 7.3, 7.8-be, 7.18
├── prompt_DEV-3.md (FRONT1)        — 7.16, 7.15-fe, 7.17-fe, 7.6, 7.19
├── prompt_DEV-4.md (FRONT2)        — 7.1-fe, 7.7, 7.8-fe, 7.2-fe
├── prompt_DEV-5.md (OPS)           — 7.9 + саппорт E2E
│
├── midsprint_check.md              — итог гейта между W1 и W2 (создаётся в день 7)
├── ui_checklist_s7.md              — обновлённый чеклист UI после S7
└── arch_review_s7.md               — финальное ARCH-ревью (создаётся в день 14)
```

### 4.1 Структура DEV-промпта (5 файлов)

Все 5 DEV-промптов следуют **обязательному шаблону** `Спринты/prompt_template.md` (правило CLAUDE.md «Работа с DEV-субагентами в спринтах», действует с S6). 11 секций строго:

1. **Frontmatter** — `sprint: 7`, `agent: DEV-X`, `wave: 1|2`, `depends_on: [...]`
2. **Роль** — грейд + зона ответственности + ссылка на RACI
3. **Предварительная проверка** — окружение, baseline-тесты, конкретные команды (с реальным запуском, правило S5R.5)
4. **Обязательные плагины** — таблица (pyright/tsc/context7/playwright/code-review/TDD) с fallback'ами
5. **Обязательное чтение** — `Develop/CLAUDE.md` полностью + `Develop/stack_gotchas/INDEX.md` + `Sprint_7/execution_order.md` (Cross-DEV contracts) + `Sprint_7/ux/*.md` (для FRONT-ролей) + **дословные цитаты** из ФТ/ТЗ для своих задач (правило CLAUDE.md S6+)
6. **Рабочая директория** — `Test/Develop/<backend|frontend>/`
7. **Контекст существующего кода** — конкретные файлы с одной строкой пояснения
8. **Задачи** — пронумерованный список с примерами кода/сигнатур/DDL
9. **Опциональные задачи** — явный PASS/SKIP+reason (правило S5R.5)
10. **Skip-тикеты** — обязательная карточка в backlog для каждого `test.skip`
11. **Тесты** — структура `tests/`, конкретные фикстуры, минимум сценариев
12. **Integration Verification Checklist** — `grep -rn "<NewClass>(" app/` + listener'ы + scheduler/lifespan + endpoint registration. Для 7.13 — отдельный чеклист по 5 event_type
13. **Формат отчёта** — мандатные 8 секций до 400 слов, отчёт сохраняется как файл в `reports/`
14. **Alembic-миграция** — если применимо (DEV-2 для 7.1, 7.8)
15. **Чеклист перед сдачей** — 13 пунктов, включая «отчёт сохранён как файл»

### 4.2 Структура prompt_ARCH_design.md (W0, новый — отдельно от 7.R)

```
- Роль: ARCH design ревьюер на W0
- Задачи:
  1. Прочитать спецификации по 7.1, 7.2, 7.15, 7.17, 7.18, 7.13
  2. Провести brainstorm по каждой через superpowers:brainstorming — итог секциями
  3. Создать arch_design_s7.md с: модель данных версионирования, схема Grid Search,
     дизайн WS-канала, структура очереди фоновых бэктестов, формат AI-context, MR.5 mapping
  4. Зафиксировать 5–7 ключевых Stack Gotchas из INDEX.md, релевантных S7
  5. Согласовать макеты UX W0 на стыке с архитектурой
- Критерий завершения: arch_design_s7.md закрыт, DEV-промпты можно начинать заполнять
```

### 4.3 Структура prompt_UX.md (W0 + W3)

```
- W0 задачи (ДО старта DEV):
  1. Создать 6 макетов в Sprint_7/ux/ (см. Приложение D)
  2. Согласовать с ARCH архитектурные ограничения (после arch_design_s7.md)
  3. Принять UI-spec для каждого макета (компоненты, состояния, ошибки)
- midsprint UX-review реализации W1 (7.16, 7.15-fe, 7.17-fe)
- W3 задача 7.10: финальная полировка по выявленным delta
- Контекст: design system memory (Mantine), правило памяти feedback_ui_checklist_update.md
```

### 4.4 Структура prompt_QA.md (W0 + W1 + W3)

```
- W0 задача (ОБЯЗАТЕЛЬНО ДО написания тестов — правило feedback_e2e_testing.md):
  1. Создать e2e_test_plan_s7.md с описанием ВСЕХ сценариев
     (предусловия, шаги, ожидаемый результат) — основа: ui_checklist_s5r.md +
     новые проверки за S7
  2. Аккаунт: sergopipo (правило памяти user_test_credentials.md)
  3. Подтвердить инфраструктуру в preflight_checklist.md
- W1: написать E2E под debt-задачи 7.13–7.17, запустить, верифицировать
- W3 задача 7.11: написать E2E под фичи + полный регресс прогон
- Критерий: 119 baseline + ≥ 15 новых E2E проходят, отчёт прикладывается
  в arch_review_s7.md
```

### 4.5 Структура prompt_ARCH_review.md (W3 финальное ревью 7.R)

```
- Code review всех 17 задач (по 8 разделам как в S6 Review)
- Проверка integration verification во всех reports/ файлах
- Проверка MR.5 (5 event_type подключены — обязательная по project_state.md:79)
- Stack Gotchas: новые gotcha-NN-*.md созданы, INDEX.md обновлён
- Cross-DEV contracts: каждый контракт C1-C8 проверен через grep + runtime
- Регрессия E2E ≥ baseline 119 + новые ≥ 15
- ФТ/ТЗ/development_plan актуализация (правило памяти feedback_review_docs.md)
- ui_checklist_s7.md обновлён (правило памяти feedback_ui_checklist_update.md)
- Финальный вердикт: PASS / PASS WITH NOTES / FAIL
- Перенос задач в S8/Phase 2 backlog при необходимости
```

---

## 5. Метаданные планирования и переход к writing-plans

### 5.1 Расположение spec

- **Основной spec:** `Спринты/Sprint_7/sprint_design.md` (этот файл)
- **Канонический указатель:** `docs/superpowers/specs/2026-04-25-sprint-7-design.md` (одна строка ссылки на основной)

### 5.2 Ветка и коммит

- **Текущая ветка:** `docs/sprint-6-review` (последний коммит `2f1cfc4 docs(s6r): Sprint 6 Review — ФТ/ТЗ/план обновлены, M3 достигнут`).
- **Базовая ветка:** `main`.
- **Ветка планирования S7:** `docs/sprint-7-plan` (имя на подтверждении заказчика).
- **Репозиторий:** только корневой (Test). `Develop/` не затрагивается на этапе планирования (память `feedback_two_repos.md`).
- **Коммит:** только по явной команде заказчика (правило CLAUDE.md).

### 5.3 План следующих шагов (после approval)

1. ✅ Создан spec в `Sprint_7/sprint_design.md` + указатель в `docs/superpowers/specs/`.
2. ✅ Self-review spec (placeholder/consistency/scope/ambiguity).
3. ⏸️ Заказчик подтверждает spec или запрашивает правки.
4. ⏳ Переход к skill `superpowers:writing-plans`: skill превращает spec в детальные файлы спринта (`prompt_*.md`, `execution_order.md`, `preflight_checklist.md`, `e2e_test_plan_s7.md`, `ux/*` placeholders) по структуре из секции 4.
5. ⏳ Заказчик ревьюит и подтверждает финальные файлы.
6. ⏳ После команды заказчика — коммит в выбранную ветку.
7. ⏳ Запуск W0 (ARCH design + UX макеты + QA test plan).

---

## Приложение A — Cross-DEV contracts (полная таблица)

| # | Задача | Поставщик | Потребитель | Контракт |
|---|--------|-----------|-------------|----------|
| C1 | 7.15 | BACK1 | FRONT1 | `WS /ws/trading-sessions/{user_id}` → `{event:'position_update'\|'trade_filled'\|'pnl_update'\|'session_state', session_id, payload}`. Авторизация — JWT в query/cookie |
| C2 | 7.17 | BACK1 | FRONT1 | `WS /ws/backtest/{job_id}` → `{progress:0..100, status:'queued'\|'running'\|'done'\|'error', result?}`. Параллельные jobs — отдельные WS-каналы |
| C3 | 7.18/7.19 | BACK2 | FRONT1 | `POST /api/v1/ai/chat` body расширяется: `context:[{type:'chart'\|'backtest'\|'strategy'\|'session'\|'portfolio', id}]`. Backend сам подгружает данные по id |
| C4 | 7.1 | BACK2 | FRONT2 | `GET /api/v1/strategies/{id}/versions`, `POST /api/v1/strategies/{id}/versions`, `POST /api/v1/strategies/{id}/versions/{ver_id}/restore`. Хранение: `strategy_versions(id, strategy_id, blocks_xml, code, created_at, created_by, comment)` |
| C5 | 7.2 | BACK1 | FRONT2 | `POST /api/v1/backtest/grid` body: `{strategy_id, ranges:{param_name:[v1,v2,...]}}` → `{job_id}`; результат через WS C2 (общий `/ws/backtest/`) с матрицей в `result` |
| C6 | 7.8 | BACK2 | FRONT2 | `POST /api/v1/users/me/wizard/complete`; `GET /api/v1/users/me` отдаёт `wizard_completed_at:datetime\|null` |
| C7 | 7.12 | BACK2 | BACK1, OPS | `request.app.state.notification_service` (FastAPI Depends pattern). Все `NotificationService()` в коде заменяются. Проверка: `grep -rn "NotificationService()" app/` = 0 вне `main.py` |
| C8 | 7.14 | BACK2 | (deep link) | CallbackData scheme: `open_session:{session_id}`, `open_chart:{ticker}`. Deep link → `/sessions/{id}` или `/chart?ticker=...` |

### Правила гонки и приёмки контрактов

- **C1, C2, C5 (WS-каналы):** BACK1 публикует пустой WS-эндпоинт + JSON-схему первой; FRONT1/FRONT2 пишут клиент по схеме; интеграция — после реальной публикации сообщений. Перевод polling→WS делается ровно одним PR (избежать двойного источника правды).
- **C3 (AI context):** BACK2 первым публикует расширение схемы запроса; FRONT1 идёт по уже задокументированному формату.
- **C4 (versioning):** Alembic-миграция от BACK2 — ПЕРВОЕ, что делается в треке (FRONT2 не стартует пока schema не закоммичена).
- **C7 (NS singleton):** одной волной правится во всех вызывающих модулях. Hook `plugin-check.sh` ловит compile-time ошибки сразу.
- **Integration verification:** каждый DEV в отчёте подтверждает `grep -rn "<NewClass>(" app/` (правило CLAUDE.md). C7 проверяется отдельно: `grep -rn "NotificationService()" app/` должен дать 0 совпадений вне `main.py`.

---

## Приложение B — Календарный график W0/W1/W2/W3

```
ДЕНЬ  ЭТАП                                  ИСПОЛНИТЕЛИ          АРТЕФАКТЫ
────────────────────────────────────────────────────────────────────────────
1-2   W0: UX макеты (6 файлов)              UX                   Sprint_7/ux/*
        + ARCH design ревью                 ARCH                 arch_design_s7.md
        + brainstorm 7.1/7.2/7.13/                               reports/ARCH_W0_design.md
        7.15/7.17/7.18                                           reports/UX_W0_design.md
        + e2e_test_plan_s7.md               QA                   e2e_test_plan_s7.md
        + Stack Gotchas pre-read            ARCH                 (записи в INDEX.md)
        + DEV-промпты заполняются           оркестратор          prompt_DEV-1..5.md

3-6   W1: 6 переносов параллельно           BACK1+BACK2+FRONT1   reports/DEV-X_W1.md
        7.12, 7.13, 7.14,                                         changelog.md
        7.15, 7.16, 7.17                                          (E2E под debt от QA)

7     Midsprint checkpoint                  ARCH                 midsprint_check.md
        Если провал — фиксы (день +1)                             reports/ARCH_midsprint_check.md
                                                                   reports/UX_midsprint_review.md

8-12  W2: новый функционал параллельно      все DEV              reports/DEV-X_W2.md
        7.1, 7.2, 7.3, 7.6, 7.7, 7.8,                             changelog.md
        7.9, 7.18, 7.19                                           (E2E под фичи от QA)

13    UX полировка 7.10 + предфинал E2E    UX, FRONT, QA        ui_checklist_s7.md update
                                                                   regression run

14    7.R ARCH ревью + 7.11 финальный E2E   ARCH, QA             arch_review_s7.md
        + ФТ/ТЗ/development_plan sync                             functional_requirements.md update
        + ui_checklist update                                     technical_specification.md update
                                                                   development_plan.md update
```

**Гибкость:** при срыве W1 (фейл midsprint) или W2 — пролонгация на необходимое количество дней. Решение заказчика 2026-04-25: «делаем всё, время гибкое».

---

## Приложение C — Маппинг 5 event_type ↔ publish-сайтов (MR.5)

> Источник: `Спринты/project_state.md:79–90` (раздел «S7 — ARCH-задача: подключение оставшихся event_type к runtime»).
> Задача 7.13 — закрыть всё ниже. Механизм доставки (in-app + Telegram + Email) уже работает для всех 13 типов (подтверждено `test_dispatch_all_events.py`, 14 passed). Нужно только подключить источники.

| event_type | Что нужно реализовать | Источник события |
|------------|------------------------|------------------|
| `trade_opened` | EVENT_MAP: маппинг на открытие позиции | `app/trading/runtime.py` или `app/trading/engine.py` |
| `partial_fill` | Частичное исполнение ордера | `app/trading/engine.py` → OrderManager |
| `order_error` | Ошибка выставления ордера | `app/trading/engine.py` → OrderManager |
| `all_positions_closed` | Все позиции закрыты | `app/trading/engine.py:681` (event уже есть, нет `create_notification`) |
| `connection_lost` / `connection_restored` | Потеря/восстановление gRPC-соединения | `app/broker/tinvest/multiplexer.py` (reconnect loop) |

### Verification (midsprint и в 7.R)

```bash
# В production-коде на каждое событие должен быть вызов create_notification:
grep -rn "create_notification" app/trading/ app/broker/

# Должно встречаться для каждого из 5 типов (помимо других 8, уже подключенных в S6).
```

DEV-1 в отчёте по 7.13 обязан перечислить все 5 publish-сайтов с `<file:line>`.

---

## Приложение D — Список UX-макетов

> Все 6 макетов создаются в `Sprint_7/ux/` на W0 (дни 1–2) ДО старта DEV-агентов.
> Согласование с ARCH — после `arch_design_s7.md`, чтобы UX знал архитектурные ограничения.

| Файл | Покрывает | Содержание |
|------|-----------|------------|
| `dashboard_widgets.md` | 7.7 | Виджет баланса (значение + sparkline + ↑/↓ за день), health indicator (CB-state, T-Invest connection, scheduler), мини-графики активных позиций |
| `wizard_5steps.md` | 7.8 | Шаг 1: приветствие → 2: дисклеймер о рисках → 3: выбор брокера/режим (paper/real) → 4: настройка уведомлений → 5: финиш. Прогресс-бар, нельзя «пропустить дисклеймер» |
| `drawing_tools.md` | 7.6 | Тулбар графика: трендовые линии, горизонтальные уровни, прямоугольные зоны. Persist в localStorage по `{user_id, ticker, tf}` |
| `backtest_overview_analytics.md` | 7.16 (аналитика) | Гистограмма «Распределение P&L» (бакеты, цвета, средние линии) + donut «Win/Loss/BE» (3 сегмента, легенда) — два графика рядом на вкладке «Обзор». Источник: память `project_s7_interactive_zones.md` |
| `background_backtest_badge.md` | 7.17 | Бейдж в шапке справа: число активных + dropdown с прогрессом по каждому. Toast «бэктест запущен в фоне». Модалка `BacktestLaunchModal` остаётся открытой после клика «в фоне». Источник: память `project_s7_background_backtest.md` |
| `ai_commands_dropdown.md` | 7.19 | Dropdown при вводе `/` в чате: список 5 команд (`/chart`, `/backtest`, `/strategy`, `/session`, `/portfolio`) с подсказками; рендер «контекстного блока» в сообщении (тикер/период/id). Источник: `.claude/plans/purring-herding-badger.md` |

---

**Конец spec-документа.**
