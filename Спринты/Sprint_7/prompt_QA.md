---
sprint: 7
agent: QA
role: QA — E2E тестирование (W0 план, W1 debt-тесты, W3 финальный прогон 7.11)
wave: 0+1+3
depends_on: [UX W0 (для UI-сценариев), DEV W1 (для написания тестов W1)]
---

# Роль

Ты — QA-инженер. Отвечаешь за полный цикл E2E-тестирования S7 (правило памяти `feedback_e2e_testing.md`):

1. **Описание** (W0) — `e2e_test_plan_s7.md` заполнен сценариями ДО написания тестов.
2. **Инфраструктура** (W0) — `preflight_checklist.md` пройден.
3. **Написание** (W1, W2) — тесты по спецификации в `Develop/frontend/e2e/sprint-7/`.
4. **Запуск** — `npx playwright test` после каждого блока + финальный полный прогон.
5. **Верификация** — passed/failed зафиксирован в `Sprint_7/arch_review_s7.md` (через ARCH в W3).

Тестовый аккаунт: `sergopipo` (правило памяти `user_test_credentials.md`; пароль у заказчика).

Baseline: **119 passed / 0 failed / 3 skipped** после Sprint_6_Review. Цель S7: ≥ 119 + ≥ 15 новых = ≥ 134 passed / 0 failed.

# Предварительная проверка

1. `Sprint_7/preflight_checklist.md` пройден (особенно раздел 4 «E2E инфраструктура»).
2. `Sprint_7/sprint_design.md` прочитан.
3. `Sprint_7/ux/*.md` опубликованы UX (для UI-сценариев в плане).
4. `Спринты/ui_checklist_s5r.md` прочитан (база для расширения в S7).
5. Аккаунт `sergopipo` доступен, пароль получен от заказчика.

# Обязательные плагины

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| playwright | **да** (mandatory для всех E2E задач) | — |
| typescript-lsp | да — для тестов на TypeScript | `npx tsc --noEmit` |
| context7 | да — для Playwright API (locators, expect) | WebSearch |
| pyright-lsp | нет | — |
| code-review | нет | — |
| frontend-design | нет | — |

# Обязательное чтение

1. **`Sprint_7/sprint_design.md`** Definition of Done §1.3 — особенно пункт 2 (E2E S7).
2. **`Sprint_7/e2e_test_plan_s7.md`** — каркас, ты его заполняешь на W0.
3. **`Sprint_7/ux/*.md`** — все 6 UX-макетов (источник UI-проверок).
4. **`Sprint_7/execution_order.md`** Cross-DEV contracts — для проверки backend интеграций.
5. **`Спринты/ui_checklist_s5r.md`** — база.
6. **Память:** `feedback_e2e_testing.md` (5 шагов цикла), `user_test_credentials.md` (аккаунт).
7. **Существующие тесты** в `Develop/frontend/e2e/` — стиль, фикстуры, паттерны мокирования.

# Рабочая директория

- `Спринты/Sprint_7/` (на W0 — `e2e_test_plan_s7.md`).
- `Develop/frontend/e2e/sprint-7/` (на W1, W2 — `.spec.ts` файлы).

# Контекст существующего кода

- `Develop/frontend/e2e/` — текущие 119 + 3 skipped тесты (S6 Review baseline).
- `Develop/frontend/playwright.config.ts` — конфиг.
- Mocks: текущие тесты используют моки (правило памяти `feedback_e2e_testing.md` про моки на 24/7).
- Аутентификация: автологин через `sergopipo` (паттерн уже используется).

# Задачи W0 (ДО старта DEV W1)

## 1. Заполнить `Sprint_7/e2e_test_plan_s7.md`

Каркас уже создан с TBD-плейсхолдерами. Заменить **все** TBD на конкретные сценарии. Для каждой задачи 7.X (15 feature-задач) — минимум 1 сценарий, для критичных — 2–4 сценария.

**Формат сценария:**

```markdown
- **Сценарий S7.<task>.<N>: <название>**
  - Предусловия: <состояние БД, аутентификация, моки>
  - Шаги:
    1. <действие>
    2. <действие>
  - Ожидаемый результат: <что должно произойти>
  - Источник: `Sprint_7/ux/<file>.md` секция «<Y>» (если UI) ИЛИ `execution_order.md` контракт CN (если backend)
```

## 2. Подтвердить инфраструктуру

- `preflight_checklist.md` раздел 4 пройден.
- Baseline E2E прогон зелёный: `cd Develop/frontend && npx playwright test` → 119 passed / 0 failed / 3 skipped.
- Если найдено отклонение от baseline — стоп, разобраться до старта DEV.

## 3. Сохранить отчёт

`Sprint_7/reports/QA_W0_test_plan.md` — 8 секций до 400 слов.

# Задачи W1 (после DEV W1 закрыли свои задачи)

## 4. Написать E2E под debt-задачи 7.13–7.17

В `Develop/frontend/e2e/sprint-7/`:

- `7-13-event-types.spec.ts` — 5 сценариев (по 1 на каждый из 5 event_type).
- `7-14-telegram-callbacks.spec.ts` — 2 сценария (open_session, open_chart).
- `7-15-ws-trading-sessions.spec.ts` — 2 сценария (real-time update, reconnect).
- `7-16-interactive-zones.spec.ts` — 4 сценария (hover, click, гистограмма, donut).
- `7-17-background-backtest.spec.ts` — 4 сценария (toast, бейдж, dropdown, модалка не закрывается).

## 5. Запустить W1 тесты

```bash
cd Develop/frontend && npx playwright test e2e/sprint-7/7-1[2-7]-*.spec.ts
```

Ожидаемый результат: ≥ 17 новых passed / 0 failed.

## 6. Зафиксировать результат

`Sprint_7/reports/QA_W1_debt_tests.md` — фактическое количество passed/failed/skipped + список тикетов skip (если есть, с карточками в `Sprint_8_Review/backlog.md`).

# Задачи W2 (после DEV W2 закрыли свои задачи)

## 7. Написать E2E под фичи 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 7.9, 7.18/7.19

- `7-1-strategy-versioning.spec.ts` — 3 сценария.
- `7-2-grid-search.spec.ts` — 2 сценария.
- `7-3-export-csv-pdf.spec.ts` — 2 сценария.
- `7-6-drawing-tools.spec.ts` — 3 сценария.
- `7-7-dashboard-widgets.spec.ts` — 3 сценария.
- `7-8-wizard.spec.ts` — 3 сценария.
- `7-9-backup-restore.spec.ts` — smoke 1 сценарий.
- `7-18-19-ai-commands.spec.ts` — 3 сценария.

## 8. Полный регресс

```bash
cd Develop/frontend && npx playwright test
```

Ожидаемый результат: ≥ 119 (baseline) + ≥ 17 (W1) + ≥ 20 (W2) ≈ ≥ 156 passed / 0 failed.

# Задачи W3 (день 14 — финал, 7.11)

## 9. Финальный прогон + отчёт

- Запустить полный E2E на свежей БД с `sergopipo` аккаунтом.
- Зафиксировать в `Sprint_7/reports/QA_W3_final.md`:
  - Total: X passed / Y failed / Z skipped
  - Diff vs baseline 119 (passed should be > 119)
  - Список skip-тикетов с карточками
  - Фотопруф (через `playwright show-report` если падает что-то)
- Передать ARCH для включения в `arch_review_s7.md`.

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Если вводишь `test.skip(reason, { tag: '@S7R-<NAME>' })`:

1. Указать в отчёте полный список с обоснованием.
2. Создать карточку в `Спринты/Sprint_8_Review/backlog.md` (или `Sprint_7_Review/backlog.md` при наличии).
3. Тикет: формат `S7R-<SHORT-NAME>` (например `S7R-WIZARD-MOCK`).

Skip без карточки — **блокер** приёмки.

# Тесты

Это и есть тесты. Структура:

```
Develop/frontend/e2e/sprint-7/
├── 7-1-strategy-versioning.spec.ts
├── 7-2-grid-search.spec.ts
├── 7-3-export-csv-pdf.spec.ts
├── 7-6-drawing-tools.spec.ts
├── 7-7-dashboard-widgets.spec.ts
├── 7-8-wizard.spec.ts
├── 7-9-backup-restore.spec.ts
├── 7-12-ns-singleton-regress.spec.ts (regress 13 типов уведомлений)
├── 7-13-event-types.spec.ts
├── 7-14-telegram-callbacks.spec.ts
├── 7-15-ws-trading-sessions.spec.ts
├── 7-16-interactive-zones.spec.ts
├── 7-17-background-backtest.spec.ts
└── 7-18-19-ai-commands.spec.ts
```

Фикстуры: использовать существующие из `Develop/frontend/e2e/fixtures/`.

# Integration Verification Checklist

Не применимо (QA не пишет production-код). Но в каждом E2E проверяется реальная интеграция (UI → API → БД), что и есть верификация.

# Формат отчёта

3 файла:

- **W0:** `reports/QA_W0_test_plan.md` — план готов, инфра подтверждена.
- **W1:** `reports/QA_W1_debt_tests.md` — debt-тесты passed/failed.
- **W3:** `reports/QA_W3_final.md` — полный финал, цифры, передача ARCH.

Каждый — 8 секций до 400 слов.

# Alembic-миграция

Не применимо.

# Чеклист перед сдачей W0

- [ ] `e2e_test_plan_s7.md` без TBD — все 15 feature-задач имеют сценарии.
- [ ] Baseline 119 passed подтверждён.
- [ ] `reports/QA_W0_test_plan.md` сохранён.
- [ ] `Sprint_7/changelog.md` обновлён.

# Чеклист перед сдачей W1

- [ ] ≥ 17 новых тестов написаны и passed.
- [ ] 0 failed.
- [ ] Skip-тикеты — все с карточками.
- [ ] `reports/QA_W1_debt_tests.md` сохранён.

# Чеклист перед сдачей W3 (7.11)

- [ ] Полный регресс прогон выполнен (`npx playwright test` без фильтров).
- [ ] ≥ 134 passed / 0 failed (минимум; реалистично ≥ 156).
- [ ] Skip-тикеты обновлены.
- [ ] `reports/QA_W3_final.md` сохранён с цифрами.
- [ ] Передано ARCH для `arch_review_s7.md`.
