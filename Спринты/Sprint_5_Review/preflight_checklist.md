# Предполётная проверка — Sprint_5_Review

> Этот чеклист выполняется **ДО** запуска любого DEV-агента S5R.
> Если хотя бы один пункт не выполнен — ревью НЕ стартует.
> Оркестратор (Claude) выполняет проверки автоматически и сообщает результат.

---

## 1. Системные требования (автопроверка)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 1.1 | Python установлен | `python3 --version` | >= 3.11 | [ ] |
| 1.2 | Node.js установлен | `node --version` | >= 18 | [ ] |
| 1.3 | pnpm установлен | `pnpm --version` | >= 9 | [ ] |
| 1.4 | Git установлен | `git --version` | any | [ ] |
| 1.5 | Playwright установлен | `cd Develop/frontend && npx playwright --version` | any | [ ] |

## 2. Состояние репозитория `moex-terminal` (Develop/)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 2.1 | Ветка `develop` активна | `cd Develop && git branch --show-current` | `develop` | [ ] |
| 2.2 | Рабочая директория чистая | `cd Develop && git status --porcelain` | пусто | [ ] |
| 2.3 | Синхронизация с remote | `cd Develop && git fetch && git status` | up to date | [ ] |
| 2.4 | `Develop/CLAUDE.md` существует и содержит раздел Stack Gotchas | Grep `## ⚠️ Stack Gotchas` | найдено | [ ] |

## 3. Состояние репозитория `test` (корневой)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 3.1 | Этап A S5R завершён | Все `[x]` в `Sprint_5_Review/execution_order.md` секция «Чек-лист этапа A» | кроме последнего (коммит) | [ ] |
| 3.2 | `Sprint_5_Review/` содержит все PENDING-файлы | `ls Спринты/Sprint_5_Review/PENDING_S5R_*.md` | 4 файла | [ ] |
| 3.3 | `development_plan.md` содержит раздел S5R.1-S5R.6 | Grep `S5R.1` | найдено | [ ] |
| 3.4 | `project_state.md` — статус S5R «этап A завершён, этап B» | Grep `этап A завершён` | найдено | [ ] |

## 4. Baseline тестов (ожидаемо красный — это причина ревью)

> ⚠️ **Ожидание:** baseline **красный**. Это не блокер для старта DEV-1 — наоборот, DEV-1 как раз и чинит CI. Фиксируем факт для последующей сверки «до/после».

| # | Проверка | Команда | Ожидание (до DEV-1) | Статус |
|---|----------|---------|---------------------|--------|
| 4.1 | Backend ruff | `cd Develop/backend && ruff check .` | ❌ F401 в `alembic/env.py` (~14 строк) | [ ] |
| 4.2 | Backend pytest | `cd Develop/backend && pytest tests/unit/` | ? (не запускалось в CI с 03.04) | [ ] |
| 4.3 | Frontend eslint | `cd Develop/frontend && pnpm lint` | ❌ React 19 hooks + unused-vars + any | [ ] |
| 4.4 | Frontend vitest | `cd Develop/frontend && pnpm test` | ? (не запускалось в CI с 03.04) | [ ] |
| 4.5 | Frontend tsc | `cd Develop/frontend && pnpm tsc --noEmit` | ? (не запускалось в CI с 03.04) | [ ] |
| 4.6 | Playwright baseline | `cd Develop/frontend && npx playwright test` | ❌ 30+ s4-review тестов падают | [ ] |
| 4.7 | Последний CI-запуск на GitHub | `gh run list --workflow ci.yml --limit 1` | ❌ `All jobs have failed` | [ ] |

**Фиксируется в `arch_review_s5r.md` как baseline «было».** После S5R те же команды должны вернуть 0 failures.

## 5. Prompt-файлы S5R на месте (этап B)

| # | Файл | Нужен для | Статус |
|---|------|-----------|--------|
| 5.1 | `README.md` | контекст ревью | [x] этап A |
| 5.2 | `backlog.md` | 6 задач | [x] этап A |
| 5.3 | `execution_order.md` | порядок + Cross-DEV contracts | [x] этап A |
| 5.4 | `PENDING_S5R_ci_cleanup.md` | план S5R.1 | [x] этап A |
| 5.5 | `PENDING_S5R_e2e_s4_fix.md` | план S5R.4 | [x] этап A |
| 5.6 | `PENDING_S5R_live_runtime_loop.md` | план S5R.2 | [x] этап A |
| 5.7 | `PENDING_S5R_real_account_positions_operations.md` | план S5R.3 | [x] этап A |
| 5.8 | `preflight_checklist.md` | этот файл | [ ] |
| 5.9 | `prompt_DEV-1.md` | DEV-1 (CI cleanup + E2E S4 fix) | [ ] |
| 5.10 | `prompt_DEV-2.md` | DEV-2 (Live Runtime Loop) | [ ] |
| 5.11 | `prompt_DEV-3.md` | DEV-3 (Real Positions T-Invest) | [ ] |
| 5.12 | `prompt_ARCH_review.md` | финальное ревью + S5R.6 ФТ/ТЗ | [ ] |
| 5.13 | `changelog.md` | лог выполнения (создаётся при старте этапа C) | [ ] |
| 5.14 | `arch_review_s5r.md` | финальный отчёт (создаётся в этапе D) | [ ] |

## 6. Cross-DEV contracts детализированы

| # | Проверка | Ожидание | Статус |
|---|----------|----------|--------|
| 6.1 | Все 11 контрактов C1-C11 в `execution_order.md` раздел «Cross-DEV Contracts» имеют точные endpoint/тип/сигнатуру | не «скелет», а конкретика | [ ] |
| 6.2 | Каждый контракт имеет явного поставщика и потребителя | — | [ ] |
| 6.3 | Нет контрактов «TBD» / «будет уточнён позже» | — | [ ] |

## 7. Зависимости МЕЖДУ DEV-агентами S5R

| DEV | Волна | Зависимости | Проверка перед запуском |
|-----|-------|-------------|--------------------------|
| **DEV-1 (CI cleanup)** | 1 | Нет | `prompt_DEV-1.md` на месте |
| **DEV-1 (E2E S4 fix)** | 2 | **S5R.1 завершён** | CI зелёный, `ruff` + `pnpm lint` exit 0 |
| **DEV-2 (Live Runtime)** | 2 | **S5R.1 завершён** | CI зелёный baseline |
| **DEV-3 (Real Positions)** | 2 | **S5R.1 завершён** | CI зелёный baseline |
| **ARCH (S5R.6 + финал)** | 3 | **S5R.1-4 завершены, контракты C1-C10 подтверждены** | все DEV отчёты сданы по формату |

### Блокирующие правила

```
ПРАВИЛО 1: DEV-2 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ DEV-1 закрыл S5R.1 (CI cleanup)
  ✓ cd Develop/backend && ruff check . → exit 0
  ✓ cd Develop/frontend && pnpm lint → exit 0
  ✓ Cross-DEV contracts C1, C2, C3 подтверждены в отчёте DEV-1

ПРАВИЛО 2: DEV-3 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ DEV-1 закрыл S5R.1 (CI cleanup)
  ✓ Cross-DEV contracts C1, C2, C3 подтверждены
  (DEV-3 независим от DEV-2 по файлам — параллелится)

ПРАВИЛО 3: DEV-1 S5R.4 (E2E S4 fix) НЕ ЗАПУСКАЕТСЯ пока:
  ✓ S5R.1 закрыт (lint зелёный, иначе часть ошибок e2e-файлов — от lint)

ПРАВИЛО 4: ARCH НЕ ЗАПУСКАЕТСЯ пока:
  ✓ DEV-1 закрыл S5R.1 и S5R.4
  ✓ DEV-2 закрыл S5R.2 (с подтверждёнными контрактами C4-C7)
  ✓ DEV-3 закрыл S5R.3 (с подтверждёнными контрактами C8-C9)
  ✓ Все DEV-отчёты по формату prompt_template.md (8 секций, до 400 слов)
  ✓ Integration Verification Checklist пройден в каждом отчёте
  ✓ cd Develop/backend && pytest tests/ → 0 failures
  ✓ cd Develop/frontend && pnpm test → 0 failures
  ✓ cd Develop/frontend && npx playwright test → 0 failures
  ✓ alembic upgrade head → применено
```

---

## Процедура выполнения preflight

1. Оркестратор (Claude) **автоматически** выполняет проверки 1-6 и фиксирует baseline
2. Результат выводится в формате:

```
═══════════════════════════════════════════
  PREFLIGHT CHECK — Sprint_5_Review
═══════════════════════════════════════════

  [✓] Python 3.11.x / Node 20.x / pnpm 9.x
  [✓] Develop: ветка develop, рабочее дерево чистое
  [✓] test: этап A завершён (коммит b502794), push в origin/main
  [⚠️] Baseline тестов: КРАСНЫЙ (ожидаемо — причина ревью)
       • backend ruff: 14 × F401 в alembic/env.py
       • frontend eslint: 40+ ошибок (React 19 + unused-vars + any)
       • Playwright: 30+ s4-review тестов падают
  [✓] 4× PENDING_S5R_*.md на месте
  [ ] 4× prompt_DEV/ARCH.md — этап B (текущий)
  [ ] Cross-DEV contracts C1-C11 — требуют детализации

  NEXT: создать preflight (этот файл) → prompts → детализация C1-C11
  RESULT: PREFLIGHT PARTIAL — этап B в процессе

═══════════════════════════════════════════
```

3. Заказчик видит результат и даёт команду на запуск DEV-1 (волна 1).
