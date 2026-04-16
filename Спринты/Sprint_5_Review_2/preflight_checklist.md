# Предполётная проверка — Sprint_5_Review_2

> Этот чеклист выполняется **ДО** запуска любой DEV-сессии S5R-2.
> Если хотя бы один пункт не выполнен — трек НЕ стартует.
> Оркестратор (Claude) выполняет проверки автоматически и сообщает результат.

> **Примечание:** поскольку каждый трек — отдельная Claude-сессия, чеклист выполняется **перед каждым треком**, а не один раз на весь S5R-2.

---

## 1. Системные требования (автопроверка)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 1.1 | Python установлен | `python3 --version` | >= 3.11 | [ ] |
| 1.2 | Node.js установлен | `node --version` | >= 18 | [ ] |
| 1.3 | pnpm установлен | `pnpm --version` | >= 9 | [ ] |
| 1.4 | Playwright установлен | `cd Develop/frontend && npx playwright --version` | any | [ ] |

## 2. Состояние репозитория `moex-terminal` (Develop/)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 2.1 | Активна правильная ветка трека | `cd Develop && git branch --show-current` | `fix/s5r2-track-N-*` | [ ] |
| 2.2 | Рабочая директория чистая | `cd Develop && git status --porcelain` | пусто | [ ] |
| 2.3 | Синхронизация с remote | `cd Develop && git fetch && git status` | up to date | [ ] |
| 2.4 | `Develop/CLAUDE.md` + `stack_gotchas/INDEX.md` доступны | `ls Develop/stack_gotchas/INDEX.md` | найдено | [ ] |

## 3. Состояние репозитория `test` (корневой)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 3.1 | Этап A S5R-2 завершён | Все `[x]` в `Sprint_5_Review_2/execution_order.md` секция «Чек-лист этапа A» | кроме последнего (коммит) | [ ] |
| 3.2 | `PENDING_S5R2_track*.md` для текущего трека детализирован | Grep `TODO` в нужном файле | минимум | [ ] |
| 3.3 | `project_state.md` — S5R-2 значится в роадмапе | Grep `Sprint_5_Review_2` | найдено | [ ] |

## 4. Baseline — CI зелёный (после S5R)

> **Ожидание:** CI **зелёный** (закрыт S5R wave 4). Если красный — сначала разобраться с CI, потом трек.

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 4.1 | Backend ruff | `cd Develop/backend && ruff check .` | ✅ 0 errors | [ ] |
| 4.2 | Backend pytest | `cd Develop/backend && pytest tests/unit/` | ✅ 0 failures | [ ] |
| 4.3 | Frontend eslint | `cd Develop/frontend && pnpm lint` | ✅ 0 errors | [ ] |
| 4.4 | Frontend vitest | `cd Develop/frontend && pnpm test` | ✅ 0 failures | [ ] |
| 4.5 | Frontend tsc | `cd Develop/frontend && pnpm tsc --noEmit` | ✅ 0 errors | [ ] |
| 4.6 | Playwright baseline | `cd Develop/frontend && npx playwright test --reporter=dot` | ✅ 109 passed | [ ] |
| 4.7 | Последний CI-запуск на GitHub | `gh run list --workflow ci.yml --limit 1` | ✅ success | [ ] |

## 5. Prompt-файлы S5R-2 для запуска трека (этап B)

TODO заполнить при этапе B по образцу `Sprint_5_Review/preflight_checklist.md` секция 5.

| # | Файл | Нужен для | Статус |
|---|------|-----------|--------|
| 5.1 | `README.md` | контекст патч-цикла | [x] этап A |
| 5.2 | `backlog.md` | 5 треков | [x] этап A (скелет) |
| 5.3 | `execution_order.md` | порядок | [x] этап A (скелет) |
| 5.4 | `PENDING_S5R2_track*.md` | план текущего трека | [x] этап A (скелет) |
| 5.5 | `prompt_DEV-<track>.md` для этого трека | задание DEV | [ ] этап B |

---

## Протокол

Перед каждой DEV-сессией оркестратор выполняет проверки 1-5 последовательно, фиксирует результаты в `changelog.md` (секция «Preflight трека N»), только после этого выдаёт DEV-промпт.
