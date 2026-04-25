# Sprint 7 Implementation Plan — план создания файлов спринта

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Подготовить полный набор файлов `Спринты/Sprint_7/` (промпты DEV-агентов, ARCH/UX/QA-промпты, execution_order, e2e_test_plan, ux/* макеты, служебные файлы) в соответствии со spec'ом `Sprint_7/sprint_design.md`. После завершения плана можно запускать W0 (UX макеты + ARCH design + QA test plan) → W1 → midsprint → W2 → W3.

**Architecture:** План создаёт документацию (Markdown), а не код. Каждая задача = один файл в `Sprint_7/`. Для промптов используется обязательный шаблон `Спринты/prompt_template.md` (правило CLAUDE.md «Работа с DEV-субагентами в спринтах», действует с S6). Все DEV-промпты следуют единой структуре из 11 секций. Cross-DEV контракты описаны один раз в `execution_order.md` и цитируются из DEV-промптов.

**Tech Stack:** Markdown, никакого кода. Используются дословные цитаты из ФТ/ТЗ, ссылки на `Develop/stack_gotchas/INDEX.md`, ссылки на UX-макеты `Sprint_7/ux/*.md`, ссылки на план `.claude/plans/purring-herding-badger.md` (для AI-команд).

---

## Карта файлов

### Служебные файлы спринта (создаются полностью на этом этапе)

| # | Файл | Назначение | Объём |
|---|------|-----------|-------|
| 1 | `Sprint_7/README.md` | Навигация по файлам спринта | малый |
| 2 | `Sprint_7/sprint_state.md` | Текущий шаг (стартовое состояние «W0 готов к запуску») | малый |
| 3 | `Sprint_7/preflight_checklist.md` | Чек окружения перед стартом | средний |
| 4 | `Sprint_7/changelog.md` | Лог изменений (стартовое состояние пустое) | малый |
| 5 | `Sprint_7/execution_order.md` | Порядок W0/W1/midsprint/W2/W3 + Cross-DEV contracts таблица + UX/ARCH/QA preflight | большой |
| 6 | `Sprint_7/e2e_test_plan_s7.md` | Каркас плана E2E для QA на W0 (заполняется QA-агентом) | средний |

### Промпты для агентов (создаются полностью)

| # | Файл | Кому | Объём |
|---|------|------|-------|
| 7 | `Sprint_7/prompt_ARCH_design.md` | ARCH на W0 | средний |
| 8 | `Sprint_7/prompt_UX.md` | UX на W0 + W3 | средний |
| 9 | `Sprint_7/prompt_QA.md` | QA на W0 + W1 + W3 | средний |
| 10 | `Sprint_7/prompt_DEV-1.md` | BACK1 (7.13, 7.15-be, 7.17-be, 7.2-be, 7.9) | большой |
| 11 | `Sprint_7/prompt_DEV-2.md` | BACK2 (7.12, 7.14, 7.1-be, 7.3, 7.8-be, 7.18) | большой |
| 12 | `Sprint_7/prompt_DEV-3.md` | FRONT1 (7.16, 7.15-fe, 7.17-fe, 7.6, 7.19) | большой |
| 13 | `Sprint_7/prompt_DEV-4.md` | FRONT2 (7.1-fe, 7.7, 7.8-fe, 7.2-fe) | большой |
| 14 | `Sprint_7/prompt_DEV-5.md` | OPS (7.9 + саппорт E2E) | средний |
| 15 | `Sprint_7/prompt_ARCH_review.md` | ARCH на W3 (7.R) | средний |

### Каталог UX (создаются плейсхолдеры — заполняет UX-агент в W0)

| # | Файл | Покрывает | Стартовое состояние |
|---|------|-----------|----------------------|
| 16 | `Sprint_7/ux/dashboard_widgets.md` | 7.7 | заголовок + ToC (заполнит UX) |
| 17 | `Sprint_7/ux/wizard_5steps.md` | 7.8 | заголовок + ToC |
| 18 | `Sprint_7/ux/drawing_tools.md` | 7.6 | заголовок + ToC |
| 19 | `Sprint_7/ux/backtest_overview_analytics.md` | 7.16 | заголовок + ToC |
| 20 | `Sprint_7/ux/background_backtest_badge.md` | 7.17 | заголовок + ToC |
| 21 | `Sprint_7/ux/ai_commands_dropdown.md` | 7.19 | заголовок + ToC |

### Прочее

| # | Файл | Назначение |
|---|------|-----------|
| 22 | `Sprint_7/reports/.gitkeep` | Пустая директория для отчётов DEV-агентов |
| 23 | `Спринты/project_state.md` (правка) | Перевод текущего шага на «Sprint 7 — готов к старту W0» |
| 24 | `docs/superpowers/plans/2026-04-25-sprint-7-implementation.md` | Указатель на этот план |

---

## Принципы заполнения

1. **Шаблон DEV-промпта:** все 5 DEV-промптов копируют структуру `Спринты/prompt_template.md`. Все 11 секций обязательны. Цитаты из ФТ/ТЗ — дословные, не ссылки.
2. **Cross-DEV contracts:** определены в `execution_order.md` как один источник истины. DEV-промпты ссылаются на них с указанием своей роли (поставщик/потребитель).
3. **Stack Gotchas pre-read:** каждый DEV-промпт цитирует релевантные строки `Develop/stack_gotchas/INDEX.md` (правило CLAUDE.md S6+).
4. **Integration verification:** в каждом DEV-промпте — отдельный чеклист с конкретными `grep -rn "<NewClass>(" app/` командами для каждой задачи (правило CLAUDE.md S6+).
5. **Цитаты из памяти:** где правило исходит из памяти (например `feedback_e2e_testing.md`, `feedback_changelog_immediate.md`, `user_test_credentials.md`) — цитируется с указанием источника.

---

## Задачи

### Task 1: Создать Sprint_7/README.md

**Files:**
- Create: `Спринты/Sprint_7/README.md`

- [ ] **Step 1: Создать файл с навигацией**

```markdown
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
```

- [ ] **Step 2: Проверить отображение** — открыть файл, убедиться что Markdown рендерится (заголовки, таблицы).

---

### Task 2: Создать Sprint_7/sprint_state.md

**Files:**
- Create: `Спринты/Sprint_7/sprint_state.md`

- [ ] **Step 1: Создать стартовое состояние «W0 готов к запуску»**

```markdown
# Sprint 7 — текущее состояние

> Обновляется после каждого этапа.

**Дата старта:** 2026-04-25 (планирование)
**Дата старта W0:** TBD (после команды заказчика)

## Текущий шаг

**W0 — pre-sprint design (готов к запуску)**

Все файлы спринта подготовлены. Ожидание команды заказчика на старт W0.

## Прогресс по этапам

| Этап | Статус | Артефакты |
|------|--------|-----------|
| Планирование (sprint_design + prompts) | ✅ завершено | sprint_design.md, prompt_*.md |
| W0 — UX макеты + ARCH design + QA test plan | ⬜ не начат | ux/*, arch_design_s7.md, e2e_test_plan_s7.md |
| W1 — 6 переносов из S6 | ⬜ не начат | reports/DEV-X_W1.md |
| Midsprint checkpoint | ⬜ не начат | midsprint_check.md |
| W2 — новый функционал | ⬜ не начат | reports/DEV-X_W2.md |
| W3 — UX полировка + 7.R ARCH ревью + 7.11 E2E | ⬜ не начат | arch_review_s7.md |

## Прогресс по задачам

См. `execution_order.md`. Задачи: 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11, 7.12, 7.13, 7.14, 7.15, 7.16, 7.17, 7.18, 7.19, 7.R.

## Ключевые риски

- Объём: 17 рабочих задач + UX/ARCH/QA. Заказчик подтвердил: «делаем всё, время гибкое».
- Midsprint gate: если W1 (debt) не закроется чисто — W2 не стартует.
- MR.5 (5 event_type подключены): обязательная проверка ARCH на финале.

## Следующее действие

Получить команду заказчика на старт W0.
```

- [ ] **Step 2: Сохранить и проверить.**

---

### Task 3: Создать Sprint_7/preflight_checklist.md

**Files:**
- Create: `Спринты/Sprint_7/preflight_checklist.md`

- [ ] **Step 1: Создать чек-лист окружения**

Содержание (полное, без TBD):

```markdown
# Sprint 7 — Preflight Checklist

> Чеклист выполняется ДО старта W0. Любая красная строка — стоп.

## 1. Системное окружение

- [ ] Python ≥ 3.11: `python3 --version`
- [ ] Node.js ≥ 18: `node --version`
- [ ] pnpm установлен: `pnpm --version`
- [ ] git clean: `git status` → working tree clean
- [ ] Текущая ветка корневого репо: `docs/sprint-7-plan` (или производная)

## 2. Backend (Develop/backend/)

- [ ] Виртуальное окружение активировано: `source .venv/bin/activate`
- [ ] Зависимости установлены: `pip install -r requirements.txt -r requirements-dev.txt` без ошибок
- [ ] Alembic в актуальной версии: `alembic upgrade head` (миграции применены)
- [ ] Baseline тесты зелёные: `pytest tests/ -q` → 0 failures (число тестов сохранить в отчёте)
- [ ] Линтер чистый: `ruff check app/` → no issues
- [ ] Type-check чистый: `pyright app/` → 0 errors (или fallback `python -m py_compile`)

## 3. Frontend (Develop/frontend/)

- [ ] Зависимости установлены: `pnpm install` без ошибок
- [ ] Type-check: `npx tsc --noEmit` → 0 errors
- [ ] Линтер: `pnpm lint` → no issues
- [ ] Юнит-тесты: `pnpm test` → 0 failures

## 4. E2E инфраструктура (правило памяти feedback_e2e_testing.md)

- [ ] Playwright установлен: `npx playwright --version`
- [ ] Браузеры установлены: `npx playwright install` (chromium, firefox, webkit при необходимости)
- [ ] Конфиг существует: `playwright.config.ts` доступен
- [ ] Backend поднимается: `cd Develop/backend && uvicorn app.main:app` запускается без ошибок
- [ ] Frontend поднимается: `cd Develop/frontend && pnpm dev` запускается без ошибок
- [ ] Тестовый аккаунт `sergopipo` доступен (правило памяти user_test_credentials.md; пароль у заказчика)
- [ ] Baseline E2E прогон зелёный: `npx playwright test` → 119 passed / 0 failed / 3 skipped (S6 Review baseline)

## 5. Документация и память

- [ ] `Спринты/project_state.md` прочитан
- [ ] `Sprint_7/sprint_design.md` прочитан полностью
- [ ] `Sprint_7/sprint_state.md` отражает текущее состояние
- [ ] `Develop/CLAUDE.md` прочитан (правила плагинов, Stack Gotchas)
- [ ] `Develop/stack_gotchas/INDEX.md` пройден (15+ ловушек)

## 6. Внешние сервисы

- [ ] T-Invest sandbox доступен (для проверок 7.13 connection_lost/restored)
- [ ] MOEX ISS отвечает: `curl https://iss.moex.com/iss/index.json`
- [ ] SMTP настроен в `.env` (для 7.13 email-уведомлений на partial_fill, order_error)
- [ ] Telegram bot токен настроен в `.env` (для 7.14 callback handler)

## 7. Two-repo branching (правило памяти feedback_two_repos.md)

> Develop/ — отдельный репозиторий (private moex-terminal). Корневой Test — public.
> При коммитах нужно подтверждать ветки **отдельно** для каждого.

- [ ] Корневой репо ветка: `docs/sprint-7-plan` (или согласованная с заказчиком)
- [ ] Develop/ ветка: согласовать перед стартом DEV-агентов (не делать commit без подтверждения)

## Финиш

Все строки выше — ✅ → можно стартовать W0.
```

- [ ] **Step 2: Сохранить.**

---

### Task 4: Создать Sprint_7/changelog.md (стартовый)

**Files:**
- Create: `Спринты/Sprint_7/changelog.md`

- [ ] **Step 1: Создать стартовый changelog**

```markdown
# Sprint 7 — Changelog

> Лог изменений по дням. Обновляется **немедленно** после каждого блока изменений
> (правило памяти `feedback_changelog_immediate.md`).
>
> Формат записи: `## YYYY-MM-DD — короткое название`. Внутри — bullet'ы:
> - **Что:** краткое описание изменения
> - **Файлы:** перечень
> - **Результат:** что работает / что сломалось / тесты

---

## 2026-04-25 — Планирование Sprint 7

- **Что:** Утверждён spec `sprint_design.md` (5 секций + 4 приложения, 17 задач + 7.R)
- **Что:** Создан `sprint_implementation_plan.md` для разворачивания файлов спринта
- **Файлы:** `Sprint_7/sprint_design.md`, `Sprint_7/sprint_implementation_plan.md`, указатели в `docs/superpowers/{specs,plans}/`
- **Решения:**
  - AI слэш-команды включены в S7 как 7.18/7.19 (требуют обновления ФТ/ТЗ/плана)
  - Блок A — все 7 Should-задач (7.1–7.9 без 7.4/7.5, закрытых в S6)
  - 6 переносов из S6 закрываем все (7.12–7.17)
  - Подход 2 — параллельные треки с pre-sprint W0
  - RACI-корректировка: 7.1 → BACK2 (Strategy Engine), 7.12 → BACK2 (Notification Service)
- **Ветка:** `docs/sprint-7-plan` (имя подтверждено заказчиком)
- **Результат:** 17 задач, ~14 рабочих дней, гибкое продление при необходимости
```

- [ ] **Step 2: Сохранить.**

---

### Task 5: Создать Sprint_7/execution_order.md

**Files:**
- Create: `Спринты/Sprint_7/execution_order.md`

- [ ] **Step 1: Создать с заголовками**

Файл состоит из 7 разделов:

1. **Обзор спринта** — список 17 задач, треки по DEV (копия из `sprint_design.md` §2.1, §2.3)
2. **Календарный график** — таблица W0/W1/midsprint/W2/W3 (копия из `sprint_design.md` Приложение B)
3. **W0 preflight** — что должны сделать ARCH/UX/QA в W0 ДО старта DEV
4. **Cross-DEV contracts** — таблица C1–C8 (копия из `sprint_design.md` Приложение A) + правила гонки и приёмки
5. **W1 порядок** — DEV-1, DEV-2, DEV-3 параллельно по своим трекам; зависимости между задачами
6. **Midsprint checkpoint** — чеклист гейта (копия из `sprint_design.md` §3.2)
7. **W2 порядок** — все 5 DEV параллельно; зависимости от W1 и от W0 макетов
8. **W3 завершение** — UX полировка → E2E финал → ARCH ревью → ФТ/ТЗ/development_plan sync

- [ ] **Step 2: Заполнить раздел 1 «Обзор спринта»** — скопировать из `sprint_design.md` §2.1 (списки задач) и §2.3 (треки DEV).

- [ ] **Step 3: Заполнить раздел 2 «Календарный график»** — скопировать из `sprint_design.md` Приложение B.

- [ ] **Step 4: Заполнить раздел 3 «W0 preflight»**

```markdown
## 3. W0 Preflight (ДО старта DEV-агентов)

ARCH, UX, QA выполняют параллельно за 1–2 дня:

### ARCH (prompt_ARCH_design.md)
1. Brainstorm 7.1, 7.2, 7.13, 7.15, 7.17, 7.18 через `superpowers:brainstorming`
2. Создать `Sprint_7/arch_design_s7.md` со схемами:
   - Модель `strategy_versions` (поля, индексы, миграция)
   - Дизайн Grid Search (параллелизация, лимит N комбинаций, формат matrix)
   - WS-канал `/ws/trading-sessions/{user_id}` (auth, payload, reconnect)
   - Очередь фоновых бэктестов + `/ws/backtest/{job_id}`
   - Расширение `ChatRequest.context` для AI-команд (схема, защита от injection)
   - 5 event_type publish-сайтов (см. Приложение C)
3. Stack Gotchas pre-read: 5–7 ключевых ловушек из `Develop/stack_gotchas/INDEX.md` для S7
4. Сохранить отчёт в `Sprint_7/reports/ARCH_W0_design.md`

### UX (prompt_UX.md, фаза W0)
1. Создать 6 макетов в `Sprint_7/ux/` (см. список ниже)
2. Согласовать с ARCH архитектурные ограничения после `arch_design_s7.md`
3. Сохранить отчёт в `Sprint_7/reports/UX_W0_design.md`

### QA (prompt_QA.md, фаза W0)
1. Создать `Sprint_7/e2e_test_plan_s7.md` с описанием ВСЕХ сценариев ДО написания тестов
   (правило памяти `feedback_e2e_testing.md`)
2. Подтвердить инфраструктуру через `preflight_checklist.md`
3. Сохранить отчёт в `Sprint_7/reports/QA_W0_test_plan.md`

### Гейт W0 → W1
- ARCH `arch_design_s7.md` опубликован
- UX 6 макетов в `ux/` опубликованы
- QA `e2e_test_plan_s7.md` опубликован
- `preflight_checklist.md` пройден
- Тогда оркестратор запускает DEV-агентов (W1)
```

- [ ] **Step 5: Заполнить раздел 4 «Cross-DEV contracts»** — скопировать таблицу C1–C8 из `sprint_design.md` Приложение A + правила гонки.

- [ ] **Step 6: Заполнить раздел 5 «W1 порядок»**

```markdown
## 5. W1 Порядок (параллельно, debt first)

| DEV | Задачи | Зависит от | Блокирует |
|-----|--------|-----------|-----------|
| BACK1 (DEV-1) | 7.13, 7.15-be, 7.17-be | W0 ARCH design | C1, C2 для FRONT1 |
| BACK2 (DEV-2) | 7.12, 7.14 | W0 ARCH design | C7 для BACK1, OPS, всех |
| FRONT1 (DEV-3) | 7.16, 7.15-fe, 7.17-fe | W0 UX (backtest_overview_analytics.md, background_backtest_badge.md), C1 от BACK1, C2 от BACK1 | midsprint UX-review |
| FRONT2 (DEV-4) | — | — | (FRONT2 ждёт W2) |
| OPS (DEV-5) | — | — | (OPS ждёт W2) |

Все 3 DEV-агента (BACK1, BACK2, FRONT1) запускаются одновременно.

**Контрактные точки W1:**
- BACK2 публикует C7 (NS singleton) ПЕРВЫМ — это снимает риск гонок с BACK1
- BACK1 публикует C1 (WS схема trading-sessions) до того, как FRONT1 пишет клиент
- BACK1 публикует C2 (WS схема backtest) до того, как FRONT1 пишет dropdown

**Финиш W1:** все 6 переносов закрыты с integration verification → midsprint checkpoint.
```

- [ ] **Step 7: Заполнить раздел 6 «Midsprint checkpoint»** — скопировать из `sprint_design.md` §3.2.

- [ ] **Step 8: Заполнить раздел 7 «W2 порядок»**

```markdown
## 7. W2 Порядок (параллельно)

| DEV | Задачи | Зависит от | Блокирует |
|-----|--------|-----------|-----------|
| BACK1 (DEV-1) | 7.2-be, 7.9 | W1 завершён, OPS саппорт для 7.9 | C5 для FRONT2 |
| BACK2 (DEV-2) | 7.1-be, 7.3, 7.8-be, 7.18 | W1 завершён, ARCH design (для 7.18) | C3 для FRONT1, C4 для FRONT2, C6 для FRONT2 |
| FRONT1 (DEV-3) | 7.6, 7.19 + саппорт 7.7 | W0 UX (drawing_tools.md, ai_commands_dropdown.md), C3 от BACK2 | — |
| FRONT2 (DEV-4) | 7.1-fe, 7.7, 7.8-fe, 7.2-fe | W0 UX (dashboard_widgets.md, wizard_5steps.md), C4 от BACK2, C5 от BACK1, C6 от BACK2 | — |
| OPS (DEV-5) | 7.9 (главный) | W1 завершён | — |

**Контрактные точки W2:**
- BACK2 публикует C4 (Alembic миграция `strategy_versions`) ПЕРВЫМ в треке — FRONT2 не стартует пока schema не закоммичена
- BACK2 публикует C3 (расширение ChatRequest.context) до того, как FRONT1 пишет dropdown
- BACK1 публикует C5 (POST /backtest/grid) — FRONT2 пишет UI

**Финиш W2:** все 9 фич W2 закрыты с integration verification → W3.
```

- [ ] **Step 9: Заполнить раздел 8 «W3 завершение»**

```markdown
## 8. W3 Завершение (дни 13–14)

### День 13 — UX полировка + предфинал E2E

| Агент | Задачи |
|-------|--------|
| UX | 7.10 финальная полировка (delta из реализации W1+W2 vs макеты) |
| FRONT1, FRONT2 | Применить UX delta |
| QA | Запустить полный E2E прогон (baseline 119 + новые ≥ 15) |

### День 14 — финал

| Агент | Задачи |
|-------|--------|
| ARCH | 7.R: code review всех 17 задач, проверка integration verification, MR.5, Stack Gotchas, Cross-DEV contracts |
| ARCH | Обновить `Спринты/ui_checklist_s7.md` (правило памяти feedback_ui_checklist_update.md) |
| ARCH | Обновить ФТ (`functional_requirements.md`), ТЗ (`technical_specification.md`), `development_plan.md` (правило памяти feedback_review_docs.md). В частности добавить разделы про AI-команды (7.18/7.19), которых ещё нет в `development_plan.md` |
| ARCH | Сохранить итог в `Sprint_7/arch_review_s7.md` (формат как Sprint_6_Review/code_review.md) |
| ARCH | Финальный вердикт: PASS / PASS WITH NOTES / FAIL |

**Гейт PASS:** S7 закрыт → можно ставить S8 (feature freeze).
```

- [ ] **Step 10: Сохранить, проверить.**

---

### Task 6: Создать Sprint_7/e2e_test_plan_s7.md (каркас для QA)

**Files:**
- Create: `Спринты/Sprint_7/e2e_test_plan_s7.md`

- [ ] **Step 1: Создать каркас (QA заполнит на W0 полностью)**

```markdown
# E2E Test Plan — Sprint 7

> **Заполняется QA-агентом на W0 ДО написания тестов** (правило памяти `feedback_e2e_testing.md`).
> Этот файл — **скелет** с разделами по каждой задаче. QA дополняет конкретные сценарии, предусловия, шаги, ожидаемый результат.

## Источники

- `Спринты/ui_checklist_s5r.md` — текущий UI-чеклист (база)
- `Sprint_7/sprint_design.md` — функциональность задач S7
- `Sprint_7/ux/*.md` — UX-макеты W0 (источник истины для UI-проверок)

## Тестовый аккаунт

`sergopipo` (правило памяти `user_test_credentials.md`; пароль у заказчика).

## Регрессия

Baseline после Sprint_6_Review: **119 passed / 0 failed / 3 skipped**. После S7: ≥ 119 + ≥ 15 новых (по 1+ на задачу 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 7.9, 7.12, 7.13, 7.14, 7.15, 7.16, 7.17, 7.18, 7.19).

---

## Сценарии по задачам

### 7.1 Версионирование стратегий
- [ ] **TBD by QA** — сценарий «создал → отредактировал → откатил»
- [ ] **TBD by QA** — сценарий «история показывает все версии с метаданными»

### 7.2 Grid Search
- [ ] **TBD by QA** — сценарий «параметры → запуск → matrix отображается»

### 7.3 Экспорт CSV/PDF
- [ ] **TBD by QA** — сценарий «бэктест → экспорт CSV скачивается»
- [ ] **TBD by QA** — сценарий «бэктест → экспорт PDF скачивается»

### 7.6 Инструменты рисования
- [ ] **TBD by QA** — сценарий «провёл линию → перезагрузил → линия осталась»

### 7.7 Дашборд-виджеты
- [ ] **TBD by QA** — сценарий «виджет баланса показывает корректное значение»
- [ ] **TBD by QA** — сценарий «health indicator реагирует на состояние CB»

### 7.8 First-run wizard
- [ ] **TBD by QA** — сценарий «новый юзер → wizard показывается → 5 шагов → completed»
- [ ] **TBD by QA** — сценарий «после complete не показывается повторно»

### 7.9 Backup/restore
- [ ] **TBD by QA** — smoke сценарий «бэкап создаётся → восстанавливается»

### 7.12 NS singleton
- [ ] **TBD by QA** — регресс: уведомления продолжают приходить (по всем 13 типам)

### 7.13 5 event_type
- [ ] **TBD by QA** — сценарий: trade_opened → notification приходит in-app + Telegram + Email
- [ ] **TBD by QA** — сценарий: partial_fill → notification приходит
- [ ] **TBD by QA** — сценарий: order_error → notification приходит
- [ ] **TBD by QA** — сценарий: all_positions_closed → notification приходит
- [ ] **TBD by QA** — сценарий: connection_lost / restored → notifications приходят

### 7.14 Telegram inline-кнопки
- [ ] **TBD by QA** — сценарий «клик `Открыть сессию` → редирект на /sessions/{id}»
- [ ] **TBD by QA** — сценарий «клик `Открыть график` → редирект на /chart?ticker=...»

### 7.15 WS карточки сессий
- [ ] **TBD by QA** — сценарий «открыта вкладка Торговля → новая сделка → карточка обновилась без перезагрузки»

### 7.16 Интерактивные зоны + аналитика
- [ ] **TBD by QA** — сценарий «hover на зону → выделение»
- [ ] **TBD by QA** — сценарий «клик на зону → панель деталей»
- [ ] **TBD by QA** — сценарий «вкладка Обзор → гистограмма P&L отображается»
- [ ] **TBD by QA** — сценарий «вкладка Обзор → donut Win/Loss отображается»

### 7.17 Фоновый бэктест
- [ ] **TBD by QA** — сценарий «клик `в фоне` → toast → бейдж в шапке инкрементируется»
- [ ] **TBD by QA** — сценарий «модалка остаётся открытой после клика `в фоне`»
- [ ] **TBD by QA** — сценарий «несколько фоновых параллельно — все в dropdown»

### 7.18 / 7.19 AI-команды
- [ ] **TBD by QA** — сценарий «ввёл `/` → dropdown показывается»
- [ ] **TBD by QA** — сценарий «выбрал `/chart EURUSD` → enriched prompt отправлен → AI ответил с контекстом»

---

## Шаги верификации (правило памяти feedback_e2e_testing.md)

1. Описание ВЫШЕ — заполнено QA до написания тестов ✅
2. Инфраструктура: `preflight_checklist.md` пройден ✅
3. Написание тестов: `Develop/frontend/e2e/sprint-7/*.spec.ts`
4. Запуск: `cd Develop/frontend && npx playwright test`
5. Результат: passed/failed зафиксирован в `Sprint_7/arch_review_s7.md`

QA не имеет права отчитываться «тесты написаны» без раздела «тесты прогнаны» с цифрами.
```

- [ ] **Step 2: Сохранить.**

---

### Task 7: Создать Sprint_7/prompt_ARCH_design.md

**Files:**
- Create: `Спринты/Sprint_7/prompt_ARCH_design.md`

- [ ] **Step 1: Создать промпт для ARCH на W0**

Структура (полное содержание создаётся по этой структуре, заполнить каждый пункт):

```markdown
---
sprint: 7
agent: ARCH
role: Архитектурное design-ревью на W0 (pre-sprint)
wave: 0
depends_on: []
---

# Роль
Ты — архитектор проекта на этапе W0 (pre-sprint design). Твоя задача — подготовить
архитектурные решения для крупных задач S7 ДО запуска DEV-агентов, чтобы избежать
переделок в W1/W2.

# Предварительная проверка
1. Прочитан `Спринты/Sprint_7/sprint_design.md` (особенно §2, §3.1.2, Приложение C)
2. Прочитан `Develop/CLAUDE.md` полностью
3. Прочитан `Develop/stack_gotchas/INDEX.md`
4. Доступен `Спринты/Sprint_7/preflight_checklist.md` (пройден)

# Обязательные плагины
- superpowers:brainstorming (обязательный для каждой подзадачи)
- context7 (для документации SQLAlchemy, FastAPI WebSocket, multiprocessing)

# Обязательное чтение
1. `Спринты/Sprint_7/sprint_design.md` полностью
2. `Спринты/project_state.md:79–90` — MR.5 «5 event_type подключение к runtime»
3. `Develop/stack_gotchas/INDEX.md` — выбрать 5–7 релевантных для S7
4. `.claude/plans/purring-herding-badger.md` — план AI-команд (для 7.18 design)
5. Цитаты из ТЗ:
   - ТЗ 5.4.x (версионирование стратегий — найти и процитировать дословно)
   - ТЗ 6.x (Grid Search — найти и процитировать)
   - ТЗ 7.x (WebSocket-каналы — найти и процитировать)

# Рабочая директория
`Спринты/Sprint_7/`

# Задачи

## 1. Brainstorm 7.1 «Версионирование стратегий»
Через skill superpowers:brainstorming спроектировать:
- Модель `strategy_versions(id, strategy_id, blocks_xml, code, created_at, created_by, comment)`
- Политика создания версий: на каждый Save? явный «снапшот»? автосохранение каждые N минут?
- Как делать «откат»: создать новую версию из старой? перезаписать текущую?
- Совместимость с redis-кэшем стратегий (если есть)
- Alembic-миграция

## 2. Brainstorm 7.2 «Grid Search»
- Параллелизация: multiprocessing.Pool / asyncio + Semaphore? Сравнить.
- Лимит на N комбинаций: hard cap (например 1000) + предупреждение пользователю
- Shape матрицы результата: `[{params: {p1: v1, p2: v2}, sharpe: ..., pnl: ..., win_rate: ...}]`
- Переиспользование `/ws/backtest/{job_id}` канала (контракт C2)

## 3. Brainstorm 7.13 «5 event_type → runtime»
- Для каждого из 5 event_type — точный publish-сайт (file:line) и контекст
- Цитировать MR.5 из `project_state.md:79–90` дословно
- Шаблоны EVENT_MAP — заполнение `{strategy_name}/{ticker}/{direction}/{volume}/{pnl}` по аналогии с фиксом из S6 Review

## 4. Brainstorm 7.15 «WS канал торговых сессий»
- Авторизация: JWT в query string или cookie?
- Содержание: snapshot (вся карточка) или delta (только изменения)?
- Реконнект: client-side reconnect стратегия
- Как избежать двойного источника правды с polling

## 5. Brainstorm 7.17 «Фоновый бэктест»
- Управление N одновременных jobs на пользователя (cap?)
- Очередь: in-memory или Redis?
- Жизненный цикл WS-канала /ws/backtest/{job_id}
- Связь с BackgroundTasks FastAPI

## 6. Brainstorm 7.18 «AI слэш-команды»
- Расширение `ChatRequest.context = [{type, id}]`
- Защита: валидация `id` принадлежит current_user (по таблицам strategies, backtests, sessions)
- Формат enriched prompt
- Кэширование context-данных для повторных запросов

## 7. Stack Gotchas pre-read
Выбрать 5–7 ловушек из `Develop/stack_gotchas/INDEX.md` релевантных S7:
- WS reconnect (для C1, C2, 7.15, 7.17)
- Alembic auto-generate (для 7.1 миграции)
- T-Invest tz-naive→aware (для 7.13 connection events)
- lightweight-charts series cleanup (для 7.6)
- Mantine modal lifecycle (для 7.8 wizard)
- SQLAlchemy session per-request (для 7.1 versioning)
- 401 cleanup+guard (для всех новых endpoint'ов)

# Тесты
Не применимо (design ревью).

# Integration Verification Checklist
Не применимо (design ревью).

# Формат отчёта
Сохранить в `Спринты/Sprint_7/reports/ARCH_W0_design.md` + `Спринты/Sprint_7/arch_design_s7.md`.

Структура `arch_design_s7.md` — 7 разделов по подзадачам выше + раздел «Stack Gotchas pre-read» + раздел «Контракты с UX (макеты vs архитектура)».

Краткий отчёт в `reports/ARCH_W0_design.md` — до 400 слов, 8 секций по шаблону.

# Чеклист перед сдачей
- [ ] `arch_design_s7.md` опубликован
- [ ] Все 6 brainstorm-секций заполнены
- [ ] Stack Gotchas pre-read готов (5–7 ловушек)
- [ ] Согласование с UX-макетами проверено
- [ ] `reports/ARCH_W0_design.md` сохранён
- [ ] `Sprint_7/changelog.md` обновлён немедленно
- [ ] `Sprint_7/sprint_state.md` отражает «W0 ARCH ✅»
```

- [ ] **Step 2: Сохранить.**

---

### Task 8: Создать Sprint_7/prompt_UX.md

**Files:**
- Create: `Спринты/Sprint_7/prompt_UX.md`

- [ ] **Step 1: Создать промпт UX на W0 + W3**

Структура (заполнить полностью):

```markdown
---
sprint: 7
agent: UX
role: UX-дизайнер на W0 (макеты) + W3 (полировка)
wave: 0+3
depends_on: [ARCH W0]
---

# Роль
Ты — UX-дизайнер MOEX-терминала. На W0 готовишь 6 макетов для UI-задач S7;
на W3 проводишь финальную полировку (7.10) по выявленным delta.

# Предварительная проверка
1. Прочитан `Sprint_7/sprint_design.md` Приложение D (список макетов)
2. Прочитан `Sprint_7/arch_design_s7.md` (опубликован ARCH в W0)
3. Прочитан `Спринты/ui_checklist_s5r.md` — текущий стандарт UI

# Обязательные плагины
- frontend-design (опционально для генерации мокапов через `/frontend-design`)

# Обязательное чтение
1. `Sprint_7/sprint_design.md` Приложение D
2. `Sprint_7/arch_design_s7.md` секция «Контракты с UX»
3. Память: `project_s7_interactive_zones.md`, `project_s7_background_backtest.md`, `project_slash_commands.md`
4. План AI-команд: `.claude/plans/purring-herding-badger.md`
5. Mantine Design System (текущий стек frontend)

# Рабочая директория
`Спринты/Sprint_7/ux/`

# Задачи W0

## 1. Создать `Sprint_7/ux/dashboard_widgets.md` (для 7.7)
- Виджет «Баланс» (значение + sparkline + ↑/↓ за день, цветовое кодирование)
- Виджет «Health» (CB-state, T-Invest connection, scheduler, цвет светофора)
- Виджет «Активные позиции» (мини-графики)
- Сетка/расположение, поведение на mobile
- States: loading, error, empty
- ASCII-mockup или ссылка на изображение

## 2. Создать `Sprint_7/ux/wizard_5steps.md` (для 7.8)
Шаги:
1. Приветствие
2. Дисклеймер о рисках (нельзя пропустить, обязательная галка «прочитал»)
3. Выбор брокера / режим (paper / real)
4. Настройка уведомлений (Telegram, Email, In-app)
5. Финиш
- Прогресс-бар
- Кнопки Назад / Дальше / Завершить
- States каждого шага

## 3. Создать `Sprint_7/ux/drawing_tools.md` (для 7.6)
- Тулбар графика (расположение)
- 3 инструмента: трендовая линия, горизонтальный уровень, прямоугольная зона
- Persist в localStorage по `{user_id, ticker, tf}`
- States: рисую / выделено / редактирую / удалить

## 4. Создать `Sprint_7/ux/backtest_overview_analytics.md` (для 7.16)
- Гистограмма «Распределение P&L»: бакеты, цвета (красный=убыток, зелёный=прибыль), пунктирные линии средних
- Donut «Win/Loss/BE»: 3 сегмента, легенда справа с числами и %
- Расположение на вкладке «Обзор» (рядом)
- Источник данных: trades[] из BacktestResult
- Источник идеи: память `project_s7_interactive_zones.md`

## 5. Создать `Sprint_7/ux/background_backtest_badge.md` (для 7.17)
- Бейдж в шапке справа (число активных)
- Dropdown по клику: список с прогрессом каждого
- Toast «бэктест запущен в фоне»
- Модалка `BacktestLaunchModal` остаётся открытой после клика «в фоне»
- Источник: память `project_s7_background_backtest.md`

## 6. Создать `Sprint_7/ux/ai_commands_dropdown.md` (для 7.19)
- Dropdown при вводе `/` в чате (5 команд: `/chart`, `/backtest`, `/strategy`, `/session`, `/portfolio`)
- Подсказки по каждой команде
- Рендер «контекстного блока» в сообщении (тикер/период/id)
- States: ввод, выбор, подтверждение
- Источник: `.claude/plans/purring-herding-badger.md`

# Задачи W3 (после W2)

## 7. Финальная полировка 7.10
- Проверить все реализованные UI на соответствие макетам
- Зафиксировать delta → промпты для FRONT1, FRONT2 на исправление
- Обновить `Спринты/ui_checklist_s7.md` (правило памяти feedback_ui_checklist_update.md)
- Сохранить отчёт в `reports/UX_W3_polish.md`

# Тесты
Не применимо (макеты).

# Integration Verification Checklist
Не применимо (макеты).

# Формат отчёта
W0: `reports/UX_W0_design.md` — 8 секций по шаблону, до 400 слов
W3: `reports/UX_W3_polish.md` — 8 секций, список delta + что исправлено

# Чеклист перед сдачей W0
- [ ] 6 макетов опубликованы в `Sprint_7/ux/`
- [ ] Согласовано с ARCH (после `arch_design_s7.md`)
- [ ] `reports/UX_W0_design.md` сохранён
- [ ] `Sprint_7/changelog.md` обновлён
- [ ] `Sprint_7/sprint_state.md` отражает «W0 UX ✅»

# Чеклист перед сдачей W3
- [ ] Все delta vs макеты исправлены (FRONT1, FRONT2)
- [ ] `Спринты/ui_checklist_s7.md` создан/обновлён
- [ ] `reports/UX_W3_polish.md` сохранён
```

- [ ] **Step 2: Сохранить.**

---

### Task 9: Создать Sprint_7/prompt_QA.md

**Files:**
- Create: `Спринты/Sprint_7/prompt_QA.md`

- [ ] **Step 1: Создать промпт QA на W0 + W1 + W3**

Структура аналогично UX-промпту, но:
- Зона ответственности: E2E тесты, regression
- W0: создать `e2e_test_plan_s7.md` (заполнить TBD-плейсхолдеры конкретными сценариями)
- W1: написать E2E тесты под debt-задачи 7.13–7.17 в `Develop/frontend/e2e/sprint-7/`
- W3: написать E2E под фичи + полный регресс прогон + `7.11` итог
- Обязательные плагины: playwright (правило CLAUDE.md)
- Цитата правила памяти `feedback_e2e_testing.md`: 5 шагов (описание → инфра → написание → запуск → верификация)
- Аккаунт `sergopipo` (правило памяти `user_test_credentials.md`)
- Baseline 119 + новые ≥ 15 = ≥ 134 passed / 0 failed
- Формат отчёта: `reports/QA_W0_test_plan.md`, `reports/QA_W1_debt_tests.md`, `reports/QA_W3_final.md`

Полное содержание следует структуре prompt_template.md, разделы как у UX выше, но адаптированы под QA.

- [ ] **Step 2: Сохранить.**

---

### Task 10: Создать Sprint_7/prompt_DEV-1.md (BACK1)

**Files:**
- Create: `Спринты/Sprint_7/prompt_DEV-1.md`

- [ ] **Step 1: Заполнить шаблон prompt_template.md под BACK1**

**Frontmatter:**
```yaml
---
sprint: 7
agent: DEV-1
role: Backend Core (BACK1) — Trading источники + Backtest Engine + Backup
wave: 1+2
depends_on: [ARCH W0]
---
```

**Роль:**
> Ты — Backend-разработчик #1 (senior). На W1 закрываешь долг S6 (5 event_type подключение, WS-каналы trading-sessions и backtest). На W2 реализуешь Grid Search backend и Backup/restore.
> RACI: Trading Engine = R, Backtest Engine = R.

**Задачи (5):**
1. **7.13 — 5 event_type → runtime** (W1, debt, TDD обязателен)
   - 5 publish-сайтов (см. Приложение C спека и ARCH design):
     - `trade_opened` в `app/trading/engine.py` или `runtime.py`
     - `partial_fill` в `OrderManager`
     - `order_error` в `OrderManager`
     - `all_positions_closed` в `engine.py:681`
     - `connection_lost` / `connection_restored` в `app/broker/tinvest/multiplexer.py`
   - Шаблоны EVENT_MAP заполняются `{strategy_name}/{ticker}/{direction}/{volume}/{pnl}` по аналогии с фиксом S6 Review
   - Integration verification: `grep -rn "create_notification" app/trading/ app/broker/` — должно быть 5 новых вхождений

2. **7.15-be — WS endpoint /ws/trading-sessions/{user_id}** (W1)
   - Контракт C1 (см. execution_order.md): `{event:'position_update'\|'trade_filled'\|'pnl_update'\|'session_state', session_id, payload}`
   - JWT auth в query или cookie
   - Подписка на event_bus каналы `trades:{session_id}`
   - Reconnect: client-side задача FRONT1, backend просто принимает повторное подключение

3. **7.17-be — WS endpoint /ws/backtest/{job_id} + параллельные jobs** (W1)
   - Контракт C2: `{progress:0..100, status:'queued'\|'running'\|'done'\|'error', result?}`
   - Параллельные jobs — отдельные WS-каналы
   - BackgroundTasks FastAPI или очередь (по итогу ARCH design)

4. **7.2-be — Grid Search backend** (W2)
   - Контракт C5: `POST /api/v1/backtest/grid` body `{strategy_id, ranges:{param_name:[v1,v2,...]}}` → `{job_id}`
   - Параллелизация по итогу ARCH design (multiprocessing.Pool / asyncio + Semaphore)
   - Hard cap N комбинаций (по итогу ARCH design, рекомендуется 1000)
   - Результат через WS C2 (общий /ws/backtest/) с матрицей в `result`

5. **7.9 — Backup/restore** (W2, с OPS)
   - Автоматический бэкап (ежедневный)
   - Ротация (не более 7 копий)
   - CLI восстановление: `python -m app.cli.restore --from <path>`
   - Smoke-тест: создать → удалить запись → восстановить → запись на месте

**Обязательные плагины:**
- pyright-lsp (mandatory после каждого Edit/Write на .py)
- context7 (для FastAPI WebSocket, SQLAlchemy, multiprocessing, APScheduler)
- superpowers TDD (mandatory для 7.13, 7.2)
- code-review (mandatory после блока изменений в `app/trading/`)

**Stack Gotchas pre-read:**
Цитата из `Develop/stack_gotchas/INDEX.md` строк по ловушкам: WebSocket reconnect, multiprocessing pickle, T-Invest reconnect (gotcha-15 timezone, gotcha связанная с stream API).

**Контракты:**
- Поставщик: C1 (для FRONT1), C2 (для FRONT1), C5 (для FRONT2)
- Потребитель: C7 (от BACK2 — NS singleton, использовать `request.app.state.notification_service`)

**Цитаты ТЗ/ФТ:**
- ТЗ раздел про trading engine + EVENT_MAP — дословно
- ФТ раздел про backup/restore — дословно
- MR.5 из `Спринты/project_state.md:79–90` — дословно

**Integration Verification (специфично для DEV-1):**
- 7.13: `grep -rn "create_notification" app/trading/ app/broker/` показывает 5 новых вхождений
- 7.15-be: `grep -rn "@app.websocket" app/` показывает `/ws/trading-sessions/`
- 7.17-be: `grep -rn "@app.websocket" app/` показывает `/ws/backtest/`
- 7.2-be: `grep -rn '"/api/v1/backtest/grid"' app/` показывает endpoint
- 7.9: `grep -rn "BackupService" app/` показывает регистрацию в scheduler

**Формат отчёта:**
2 файла отчёта (W1 и W2):
- `reports/DEV-1_BACK1_W1.md` — после задач 7.13, 7.15-be, 7.17-be
- `reports/DEV-1_BACK1_W2.md` — после задач 7.2-be, 7.9

Каждый — 8 секций до 400 слов по шаблону.

**Alembic-миграция:** не требуется (BACK1 не вводит новых таблиц).

**Чеклист перед сдачей** — 13 пунктов из шаблона.

- [ ] **Step 2: Заполнить полное содержание (~400-500 строк) согласно шаблону + указанные данные.**
- [ ] **Step 3: Сохранить.**

---

### Task 11: Создать Sprint_7/prompt_DEV-2.md (BACK2)

**Files:**
- Create: `Спринты/Sprint_7/prompt_DEV-2.md`

- [ ] **Step 1: Заполнить шаблон prompt_template.md под BACK2**

**Frontmatter:**
```yaml
---
sprint: 7
agent: DEV-2
role: Backend Core (BACK2) — Strategy + Notification + Telegram + AI
wave: 1+2
depends_on: [ARCH W0]
---
```

**Роль:**
> Ты — Backend-разработчик #2 (senior). На W1 закрываешь долг S6 (NS singleton, Telegram inline-кнопки). На W2 реализуешь версионирование стратегий, экспорт CSV/PDF, wizard backend, AI слэш-команды.
> RACI: Strategy Engine = R, Notification Service = R, Telegram Bot = R, AI Service = R.

**Задачи (6):**
1. **7.12 — NS singleton через DI** (W1, debt, TDD обязателен)
   - Singleton уже создан в `app/main.py:68`
   - Все вызывающие модули заменяют `NotificationService()` на `Depends(get_notification_service)` или `request.app.state.notification_service`
   - Контракт C7 — поставщик
   - Integration verification: `grep -rn "NotificationService()" app/` → 0 совпадений вне `main.py`

2. **7.14 — Telegram CallbackQueryHandler** (W1, debt)
   - CallbackData схема: `open_session:{session_id}`, `open_chart:{ticker}`
   - Deep link → `/sessions/{id}` или `/chart?ticker=...`
   - Контракт C8 — поставщик
   - SEC ревью: валидация origin/signature

3. **7.1-be — Версионирование стратегий backend** (W2)
   - Alembic-миграция `strategy_versions(id, strategy_id, blocks_xml, code, created_at, created_by, comment)` ПЕРВЫЙ ШАГ В ТРЕКЕ
   - Endpoints (контракт C4):
     - `GET /api/v1/strategies/{id}/versions` — список
     - `POST /api/v1/strategies/{id}/versions` — создать версию (snapshot)
     - `POST /api/v1/strategies/{id}/versions/{version_id}/restore` — восстановить
   - Политика автоверсий по итогу ARCH design

4. **7.3 — Экспорт CSV/PDF бэктеста** (W2)
   - WeasyPrint (PDF) + openpyxl или pandas.to_csv (CSV)
   - Endpoint: `GET /api/v1/backtests/{id}/export?format=csv|pdf`
   - Использовать context7 для документации WeasyPrint

5. **7.8-be — Wizard backend** (W2)
   - Колонка `users.wizard_completed_at: datetime|null` (Alembic миграция)
   - Endpoint `POST /api/v1/users/me/wizard/complete`
   - `GET /api/v1/users/me` отдаёт `wizard_completed_at`
   - Контракт C6 — поставщик

6. **7.18 — AI слэш-команды backend** (W2)
   - Расширение `ChatRequest.context = [{type:'chart'\|'backtest'\|'strategy'\|'session'\|'portfolio', id}]`
   - Защита: валидация id принадлежит current_user (по таблицам)
   - Backend подгружает данные по id, формирует enriched prompt
   - Контракт C3 — поставщик
   - Источник плана: `.claude/plans/purring-herding-badger.md`
   - SEC ревью: prompt injection защита

**Обязательные плагины:**
- pyright-lsp, context7 (для WeasyPrint, openpyxl, Aiogram), TDD (для 7.12), code-review (для notification + AI)

**Stack Gotchas pre-read:**
Цитировать из INDEX.md: SQLAlchemy session per-request, Alembic auto-generate gotchas, Aiogram callback handler, релевантные.

**Контракты:**
- Поставщик: C3 (для FRONT1), C4 (для FRONT2), C6 (для FRONT2), C7 (для BACK1, OPS), C8 (deep link)
- Потребитель: нет

**Цитаты ТЗ/ФТ:**
- ТЗ про NotificationService DI
- ТЗ про версионирование стратегий
- ФТ про экспорт CSV/PDF
- ФТ про first-run wizard и дисклеймер
- `.claude/plans/purring-herding-badger.md` — план AI-команд (дословно ключевые блоки)

**Integration Verification:**
- 7.12: `grep -rn "NotificationService()" app/` = 0 вне main.py
- 7.14: `grep -rn "CallbackQueryHandler" app/notification/telegram/` показывает регистрацию
- 7.1-be: `grep -rn 'strategy_versions' app/` + `grep -rn '"/api/v1/strategies/.*/versions"' app/`
- 7.3: `grep -rn '"/api/v1/backtests/.*/export"' app/`
- 7.8-be: `grep -rn 'wizard_completed_at' app/` + `grep -rn '"/wizard/complete"' app/`
- 7.18: `grep -rn 'ChatRequest' app/` показывает расширение схемы

**Формат отчёта:** 2 файла (W1 и W2):
- `reports/DEV-2_BACK2_W1.md`
- `reports/DEV-2_BACK2_W2.md`

**Alembic-миграция:** 2 миграции (для 7.1 strategy_versions и 7.8 wizard_completed_at).

- [ ] **Step 2: Заполнить полное содержание (~500 строк).**
- [ ] **Step 3: Сохранить.**

---

### Task 12: Создать Sprint_7/prompt_DEV-3.md (FRONT1)

**Files:**
- Create: `Спринты/Sprint_7/prompt_DEV-3.md`

- [ ] **Step 1: Заполнить шаблон prompt_template.md под FRONT1**

**Frontmatter:**
```yaml
---
sprint: 7
agent: DEV-3
role: Frontend Core (FRONT1) — Charts + Trading + AI chat UX
wave: 1+2
depends_on: [ARCH W0, UX W0, BACK1 (для C1, C2), BACK2 (для C3)]
---
```

**Роль:**
> Ты — Frontend-разработчик #1 (senior). На W1 закрываешь долг S6 (интерактивные зоны + аналитика, WS карточки сессий, фоновый бэктест). На W2 реализуешь инструменты рисования и frontend AI слэш-команд.
> RACI: Charts (TradingView) = R, Trading Panel = R.

**Задачи (5):**
1. **7.16 — Интерактивные зоны бэктеста + аналитика** (W1, debt-перенос)
   - Зоны на графике: hover (ярче + белый контур), клик (панель деталей со сделкой)
   - Вкладка «Обзор»: гистограмма «Распределение P&L» + donut «Win/Loss/BE»
   - Источник UX: `Sprint_7/ux/backtest_overview_analytics.md`
   - Источник памяти: `project_s7_interactive_zones.md`

2. **7.15-fe — WS-замена polling карточек сессий** (W1)
   - Контракт C1 (потребитель): `useWebSocket('/ws/trading-sessions/{user_id}')`
   - Удалить polling 10s
   - Один PR — переход без двойного источника правды

3. **7.17-fe — Toast + бейдж + dropdown в шапке** (W1)
   - Контракт C2 (потребитель): подписка на `/ws/backtest/{job_id}` для каждого активного
   - Бейдж в шапке справа (число активных)
   - Dropdown по клику: список с прогрессом
   - Toast «бэктест запущен в фоне»
   - Модалка `BacktestLaunchModal` остаётся открытой после клика «в фоне»
   - Источник UX: `Sprint_7/ux/background_backtest_badge.md`

4. **7.6 — Инструменты рисования на графике** (W2)
   - lightweight-charts: тренды, уровни, прямоугольные зоны
   - Persist в localStorage по `{user_id, ticker, tf}`
   - Источник UX: `Sprint_7/ux/drawing_tools.md`
   - Использовать context7 для lightweight-charts API

5. **7.19 — AI слэш-команды frontend** (W2)
   - Контракт C3 (потребитель): расширение `ChatRequest.context`
   - Dropdown при вводе `/`: 5 команд
   - Парсинг команды + аргументов
   - Рендер «контекстного блока» в сообщении
   - Источник UX: `Sprint_7/ux/ai_commands_dropdown.md`
   - Источник плана: `.claude/plans/purring-herding-badger.md`

**Саппорт 7.7:** sparklines использовать chart-обёртку — координация с FRONT2.

**Обязательные плагины:**
- typescript-lsp (mandatory после каждого Edit/Write на .ts/.tsx)
- context7 (для lightweight-charts, Mantine, WebSocket клиента)
- playwright (mandatory после блока изменений в components/, скриншот)
- frontend-design (опционально для 7.16 аналитики, 7.6 тулбара)

**Stack Gotchas pre-read:**
Цитировать из INDEX.md: WebSocket reconnect, lightweight-charts series cleanup, candlesCache + persist (gotcha-NN), 401 cleanup+guard (gotcha-16).

**Контракты:**
- Потребитель: C1, C2 (от BACK1), C3 (от BACK2)
- Поставщик: нет

**Цитаты ТЗ/ФТ:**
- ТЗ раздел про инструменты рисования
- ФТ раздел про аналитику бэктеста
- Память `project_s7_interactive_zones.md`, `project_s7_background_backtest.md` дословно

**Integration Verification:**
- 7.15-fe: `grep -rn 'useWebSocket.*trading-sessions' Develop/frontend/` → есть; `grep -rn 'setInterval.*sessions' Develop/frontend/` → удалено
- 7.17-fe: бейдж в шапке (`grep -rn 'BackgroundBacktestBadge' Develop/frontend/`)
- 7.6: тулбар графика (`grep -rn 'DrawingTools' Develop/frontend/`)
- 7.19: `/`-dropdown (`grep -rn 'AICommandsDropdown' Develop/frontend/`)

**Формат отчёта:** 2 файла (W1 и W2):
- `reports/DEV-3_FRONT1_W1.md`
- `reports/DEV-3_FRONT1_W2.md`

- [ ] **Step 2: Заполнить полное содержание (~500 строк).**
- [ ] **Step 3: Сохранить.**

---

### Task 13: Создать Sprint_7/prompt_DEV-4.md (FRONT2)

**Files:**
- Create: `Спринты/Sprint_7/prompt_DEV-4.md`

- [ ] **Step 1: Заполнить шаблон prompt_template.md под FRONT2**

**Frontmatter:**
```yaml
---
sprint: 7
agent: DEV-4
role: Frontend Core (FRONT2) — Dashboard + Strategy editor + Settings
wave: 2
depends_on: [ARCH W0, UX W0, BACK2 (для C4, C6), BACK1 (для C5)]
---
```

**Роль:**
> Ты — Frontend-разработчик #2. На W2 реализуешь UI версионирования стратегий, дашборд-виджеты, first-run wizard, Grid Search UI.
> RACI: Dashboard, Settings UI = R.

**Задачи (4, все на W2):**
1. **7.1-fe — Версионирование стратегий UI**
   - Контракт C4 (потребитель)
   - История версий, diff-просмотр, кнопка «Восстановить»
   - Расширение `StrategyEditPage.tsx`

2. **7.7 — Дашборд-виджеты** (с FRONT1 саппортом sparklines)
   - Виджет баланса + sparkline + ↑/↓
   - Health indicator
   - Мини-графики активных позиций
   - Источник UX: `Sprint_7/ux/dashboard_widgets.md`

3. **7.8-fe — First-run wizard 5 шагов**
   - Контракт C6 (потребитель)
   - Mantine Modal stepper
   - Источник UX: `Sprint_7/ux/wizard_5steps.md`
   - Stack Gotcha: Mantine modal lifecycle

4. **7.2-fe — Grid Search UI**
   - Контракт C5 (потребитель)
   - Форма параметров (диапазоны)
   - Heatmap результата (matrix)
   - Подключение к WS `/ws/backtest/{job_id}` контракт C2

**Обязательные плагины:**
- typescript-lsp, context7 (Mantine, lightweight-charts для sparklines), playwright (скриншоты), frontend-design (опционально для виджетов и heatmap)

**Stack Gotchas pre-read:** Mantine modal lifecycle, lightweight-charts series cleanup (для sparklines).

**Контракты:**
- Потребитель: C4 (от BACK2), C5 (от BACK1), C6 (от BACK2)

**Integration Verification:**
- 7.1-fe: `grep -rn 'StrategyVersions' Develop/frontend/`
- 7.7: `grep -rn 'BalanceWidget\|HealthIndicator' Develop/frontend/`
- 7.8-fe: `grep -rn 'WizardModal' Develop/frontend/`
- 7.2-fe: `grep -rn 'GridSearchForm\|GridSearchHeatmap' Develop/frontend/`

**Формат отчёта:** 1 файл (только W2):
- `reports/DEV-4_FRONT2_W2.md`

- [ ] **Step 2: Заполнить полное содержание (~400 строк).**
- [ ] **Step 3: Сохранить.**

---

### Task 14: Создать Sprint_7/prompt_DEV-5.md (OPS)

**Files:**
- Create: `Спринты/Sprint_7/prompt_DEV-5.md`

- [ ] **Step 1: Заполнить шаблон prompt_template.md под OPS**

**Frontmatter:**
```yaml
---
sprint: 7
agent: DEV-5
role: OPS — Backup/restore + E2E support
wave: 2
depends_on: [BACK1 (для 7.9 backup integration)]
---
```

**Роль:**
> Ты — DevOps-разработчик. На W2 реализуешь backup/restore (главный по 7.9), помогаешь QA с поднятием backend+frontend для E2E.

**Задачи (1 + саппорт):**
1. **7.9 — Backup/restore** (W2, с BACK1)
   - Автоматический бэкап (ежедневный cron / APScheduler job)
   - Ротация (keep 7 копий)
   - CLI восстановление: `python -m app.cli.restore --from <path>`
   - Smoke-тест integration
   - Документация (README или RUNBOOK)

2. **Саппорт 7.11 (E2E):**
   - Поднять backend+frontend для E2E прогонов
   - Помочь QA с playwright config (если нужно)

**Обязательные плагины:**
- pyright-lsp, context7 (APScheduler, FastAPI lifespan), code-review

**Stack Gotchas pre-read:** APScheduler init/shutdown, FastAPI lifespan.

**Контракты:** нет (OPS работает в общей зоне с BACK1).

**Integration Verification:**
- 7.9: `grep -rn 'BackupService\|backup_job' app/` показывает scheduler регистрацию
- CLI: `grep -rn 'restore' app/cli/` показывает entry point
- Smoke-тест: реальный прогон создание→удаление→восстановление, лог в отчёте

**Формат отчёта:** 1 файл:
- `reports/DEV-5_OPS_W2.md`

- [ ] **Step 2: Заполнить полное содержание (~300 строк).**
- [ ] **Step 3: Сохранить.**

---

### Task 15: Создать Sprint_7/prompt_ARCH_review.md (W3, 7.R)

**Files:**
- Create: `Спринты/Sprint_7/prompt_ARCH_review.md`

- [ ] **Step 1: Заполнить промпт ARCH на финальное ревью**

Структура (полное содержание):

```markdown
---
sprint: 7
agent: ARCH
role: Архитектурное ревью S7 (7.R)
wave: 3
depends_on: [все DEV/UX/QA отчёты]
---

# Роль
Ты — архитектор проекта. Проводишь финальное ревью S7 после завершения всех 17 задач.

# Предварительная проверка
1. Все DEV-отчёты в `Sprint_7/reports/*` опубликованы
2. UX-отчёты W0 и W3 опубликованы
3. QA-отчёт W3 (7.11) с E2E результатами опубликован
4. CI зелёный

# Обязательные плагины
- code-review (mandatory для каждого слоя кода)
- context7 (для проверки API контрактов)

# Обязательное чтение
Все 17 файлов отчётов в `reports/`.

# Задачи

## 1. Code review всех 17 задач (по 8 разделам как в Sprint_6_Review/code_review.md)
Разделы:
1. Trading Engine (7.13, 7.15-be, 7.17-be)
2. Notification Service (7.12, 7.14)
3. Strategy Engine + AI (7.1, 7.18)
4. Backtest Engine (7.2, 7.3, 7.17-be — фоновые jobs)
5. Frontend Charts + Trading + AI chat (7.6, 7.15-fe, 7.16, 7.17-fe, 7.19)
6. Frontend Dashboard + Strategy + Wizard (7.1-fe, 7.2-fe, 7.7, 7.8)
7. OPS (7.9 backup)
8. E2E + UX полировка (7.10, 7.11)

## 2. Integration verification — обязательная проверка
Для каждого нового класса/метода/endpoint:
- `grep -rn "<NewClass>(" app/` — есть production call site
- C1–C8 контракты подтверждены через grep + runtime
- C7 особо: `grep -rn "NotificationService()" app/` = 0 вне main.py

## 3. MR.5 — обязательная проверка из project_state.md:79
Все 5 event_type подключены к runtime (7.13):
- trade_opened, partial_fill, order_error, all_positions_closed, connection_lost/restored
- Каждый — реальный publish в production-коде с правильным контекстом
- E2E тест: реальное событие → notification приходит во все 3 канала

## 4. Stack Gotchas
Каждая ловушка, найденная в S7:
- Создан `Develop/stack_gotchas/gotcha-<N+1>-<slug>.md`
- Строка добавлена в `Develop/stack_gotchas/INDEX.md`
- Чеклист из `Develop/stack_gotchas/README.md` пройден

## 5. Регрессия E2E
- Baseline 119 passed / 0 failed / 3 skipped
- Новые ≥ 15 (по 1+ на feature-задачу)
- Итог: passed/failed/skipped зафиксированы

## 6. Документация (правило памяти feedback_review_docs.md)
- ФТ `functional_requirements.md` — обновлены за S7 (новые секции про AI-команды, версионирование, аналитику бэктеста, фоновые бэктесты, WS карточки, экспорт, wizard, backup, инструменты рисования)
- ТЗ `technical_specification.md` — обновлено (новые контракты C1–C8, модели, endpoints)
- `development_plan.md` — обновлён (S7 ✅, добавлены 7.18/7.19, переносы из S6 закрыты)

## 7. UI checklist (правило памяти feedback_ui_checklist_update.md)
- `Спринты/ui_checklist_s7.md` создан/обновлён по итогам S7

## 8. Перенос задач
Если найдены open-задачи (skip-тикеты, технический долг) — перенести в `Sprint_8_Review/backlog.md` или `Спринты/Планы на развитие/`.

## 9. Финальный вердикт
- PASS / PASS WITH NOTES / FAIL
- Если FAIL — список блокеров и ремидиаций
- Если PASS — обновить `Спринты/project_state.md` (S7 ✅)

# Тесты
Не применимо (ревью).

# Integration Verification Checklist
Не применимо (мета-проверка).

# Формат отчёта
Сохранить в:
- `Sprint_7/arch_review_s7.md` — полный отчёт по 8 разделам
- `reports/ARCH_S7_review.md` — краткая 8-секционная сводка до 400 слов

# Чеклист перед сдачей
- [ ] Code review всех 8 разделов проведён
- [ ] Integration verification для каждой новой сущности подтверждён
- [ ] MR.5 проверка пройдена (5 event_type подключены)
- [ ] Stack Gotchas обновлены (новые gotcha-NN-*.md + INDEX.md)
- [ ] Регрессия E2E ≥ baseline + новые ≥ 15
- [ ] ФТ/ТЗ/development_plan обновлены
- [ ] ui_checklist_s7.md создан
- [ ] Перенос задач (если есть)
- [ ] Финальный вердикт зафиксирован
- [ ] `Спринты/project_state.md` обновлён
- [ ] `Sprint_7/changelog.md` обновлён
```

- [ ] **Step 2: Сохранить.**

---

### Task 16: Создать UX-плейсхолдеры в Sprint_7/ux/

**Files:**
- Create: `Sprint_7/ux/dashboard_widgets.md`
- Create: `Sprint_7/ux/wizard_5steps.md`
- Create: `Sprint_7/ux/drawing_tools.md`
- Create: `Sprint_7/ux/backtest_overview_analytics.md`
- Create: `Sprint_7/ux/background_backtest_badge.md`
- Create: `Sprint_7/ux/ai_commands_dropdown.md`

- [ ] **Step 1: Создать 6 файлов с заголовками + ToC**

Каждый файл — заголовок + блок «Заполняется UX-агентом на W0»:

```markdown
# UX-макет: <название> (для задачи 7.X)

> **Статус:** плейсхолдер. Заполняется UX-агентом на W0 по `prompt_UX.md`.
> Источники макета:
> - `Sprint_7/sprint_design.md` Приложение D
> - <ссылки на память / план>

## Содержание

1. Описание экрана/компонента
2. Расположение на странице
3. States (loading, error, empty, success)
4. Поведение (hover, click, drag, keyboard)
5. ASCII-mockup или ссылка на изображение
6. Контракт с backend (если есть)
7. Тестовые сценарии для QA

(заполняется UX-агентом)
```

Адаптировать под каждый файл (название, источники, специфику).

- [ ] **Step 2: Сохранить все 6 файлов.**

---

### Task 17: Создать Sprint_7/reports/.gitkeep

**Files:**
- Create: `Sprint_7/reports/.gitkeep`

- [ ] **Step 1: Создать пустой `.gitkeep`** для трекинга директории git'ом.

```bash
touch "Sprint_7/reports/.gitkeep"
```

---

### Task 18: Обновить Спринты/project_state.md

**Files:**
- Modify: `Спринты/project_state.md`

- [ ] **Step 1: Прочитать текущее содержимое (200+ строк).**

- [ ] **Step 2: Обновить секцию «Что делать дальше»**

Заменить блок «СЛЕДУЮЩЕЕ ДЕЙСТВИЕ» с «Планирование Sprint 7» на:

```
ТЕКУЩЕЕ ДЕЙСТВИЕ: Sprint 7 — ПЛАНИРОВАНИЕ ЗАВЕРШЕНО ✅ (2026-04-25)

  Все файлы спринта подготовлены:
    - sprint_design.md (spec, утверждён 2026-04-25)
    - sprint_implementation_plan.md
    - 9 промптов (ARCH design, ARCH review, UX, QA, DEV-1..5)
    - execution_order.md, preflight_checklist.md, e2e_test_plan_s7.md
    - 6 UX-плейсхолдеров в ux/

  Состав S7: 17 задач + 7.R
    - Блок A (7 Should-фич): 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 7.9
    - Блок B (6 переносов из S6): 7.12, 7.13, 7.14, 7.15, 7.16, 7.17
    - Блок C (AI-команды, новый): 7.18, 7.19
    - 7.10 UX полировка, 7.11 E2E

  Подход: параллельные треки + W0 pre-sprint design

СЛЕДУЮЩЕЕ ДЕЙСТВИЕ:
  1. Заказчик команда «start W0»
  2. Запустить ARCH (prompt_ARCH_design.md), UX (prompt_UX.md), QA (prompt_QA.md)
     в W0 параллельно
  3. После W0 завершён → старт W1 (DEV-1, DEV-2, DEV-3 параллельно)
```

- [ ] **Step 3: Обновить таблицу «Прогресс по спринтам»**

Заменить строку S7:
```
| S7 | Should-фичи + переносы + AI-команды | 🔄 планирование завершено | 17 задач + 7.R готовы к запуску W0 | Sprint_7/sprint_design.md |
```

- [ ] **Step 4: Сохранить.**

---

### Task 19: Создать docs/superpowers/plans/2026-04-25-sprint-7-implementation.md (указатель)

**Files:**
- Create: `docs/superpowers/plans/2026-04-25-sprint-7-implementation.md`

- [ ] **Step 1: Создать одностраничный указатель**

```markdown
# Sprint 7 Implementation Plan — указатель

> Канонический путь для skill `superpowers:writing-plans`.
> Основной план — рядом с другими файлами спринта.

**Основной документ:** [`Спринты/Sprint_7/sprint_implementation_plan.md`](../../../Спринты/Sprint_7/sprint_implementation_plan.md)
**Spec:** [`Спринты/Sprint_7/sprint_design.md`](../../../Спринты/Sprint_7/sprint_design.md)
**Дата:** 2026-04-25
```

- [ ] **Step 2: Сохранить.**

---

### Task 20: Self-review всего набора файлов

- [ ] **Step 1: Проверить целостность**

Прогон по чек-листу:
- Все 17 рабочих задач S7 покрыты как минимум одним промптом (DEV-1..5)
- 7.10 UX полировка — в prompt_UX.md
- 7.11 E2E — в prompt_QA.md
- 7.R ARCH ревью — в prompt_ARCH_review.md
- Cross-DEV contracts C1–C8 описаны в execution_order.md и упомянуты в DEV-промптах с ролью (поставщик/потребитель)
- MR.5 покрыт: задача 7.13 в prompt_DEV-1.md (DEV-1) и обязательная проверка в prompt_ARCH_review.md
- Все правила CLAUDE.md S6+ применены: prompt_template.md, Stack Gotchas, integration verification, формат отчёта 8 секций
- Все правила памяти применены:
  - feedback_changelog_immediate.md → правило в каждом промпте
  - feedback_review_docs.md → задача в prompt_ARCH_review.md
  - feedback_ui_checklist_update.md → задача в prompt_UX.md и prompt_ARCH_review.md
  - feedback_e2e_testing.md → правило в prompt_QA.md (5 шагов цикла)
  - user_test_credentials.md → аккаунт sergopipo в prompt_QA.md
  - feedback_two_repos.md → правило в preflight_checklist.md (две ветки)

- [ ] **Step 2: Проверить отсутствие TBD/TODO в созданных файлах** (кроме UX-плейсхолдеров и e2e_test_plan_s7.md, где TBD by QA — намеренно).

- [ ] **Step 3: Проверить ссылки** — все relative-ссылки внутри Sprint_7/ работают.

---

### Task 21: Финальный отчёт пользователю

- [ ] **Step 1: Сообщить заказчику**

Сообщение должно содержать:
- Сколько файлов создано (итоговое число)
- Где основной spec и план
- Какие промпты готовы к запуску в W0/W1/W2/W3
- Что осталось до старта спринта (команда заказчика «start W0», подтверждение веток в обоих репо)
- Запрос на коммит файлов планирования в `docs/sprint-7-plan`

---

## Self-Review

После выполнения всех 21 задачи плана — выполнить:

**1. Spec coverage:**
- Все 7 секций спека (включая 4 приложения) покрыты файлами Sprint_7/?
- Все 17 задач + 7.R + UX полировка + E2E — у каждой есть исполнитель в каком-то промпте?
- DoD из §1.3 — каждый из 7 пунктов покрыт промптом?

**2. Placeholder scan:**
- Поискать в созданных файлах TBD/TODO/«implement later». Кроме UX-плейсхолдеров и e2e_test_plan, остальное должно быть полным.

**3. Type consistency:**
- Имена контрактов C1–C8 совпадают между execution_order.md, DEV-промптами, sprint_design.md
- Имена задач 7.x совпадают везде
- Имена файлов отчётов совпадают (DEV-X_<role>_W<N>.md)

**4. Внутренние ссылки:**
- Все ссылки `Sprint_7/...` работают
- Ссылки на `Develop/stack_gotchas/INDEX.md` работают
- Ссылки на ФТ/ТЗ/development_plan работают
- Ссылки на память (`feedback_*.md`, `project_*.md`) — это указатели для агентов, формально файлы памяти не часть репо

Любые проблемы — фиксы инлайн.

---

## Execution Handoff

После выполнения плана и self-review — **варианты исполнения:**

**1. Subagent-Driven (рекомендуется)** — диспатчить fresh subagent на каждую задачу (1–21), ревьюить между задачами. Скил `superpowers:subagent-driven-development`.

**2. Inline Execution** — выполнять задачи в текущей сессии последовательно. Скил `superpowers:executing-plans`.

**Рекомендация:** Inline Execution для этого плана. Причины:
- Все задачи — создание Markdown-файлов, не код. Subagent-driven избыточен.
- Между задачами почти нет зависимостей (кроме task 18 после остальных).
- В рамках одной сессии оркестратор удерживает весь контекст из spec.

Финальный коммит — после выполнения всех 21 задачи и self-review, в ветку `docs/sprint-7-plan`.
