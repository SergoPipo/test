---
sprint: 7
agent: ARCH
role: Финальное архитектурное ревью S7 (задача 7.R)
wave: 3
depends_on: [все DEV/UX/QA отчёты завершены]
---

# Роль

Ты — архитектор проекта. Проводишь финальное ревью S7 после завершения всех 17 задач. Формат — как в `Sprint_6_Review/code_review.md` (8 разделов).

# Предварительная проверка

```
1. Все DEV-отчёты в Sprint_7/reports/* опубликованы:
   - DEV-1_BACK1_W1.md, DEV-1_BACK1_W2.md
   - DEV-2_BACK2_W1.md, DEV-2_BACK2_W2.md
   - DEV-3_FRONT1_W1.md, DEV-3_FRONT1_W2.md
   - DEV-4_FRONT2_W2.md
   - DEV-5_OPS_W2.md
   - ARCH_W0_design.md, ARCH_midsprint_check.md
   - UX_W0_design.md, UX_W3_polish.md
   - QA_W0_test_plan.md, QA_W1_debt_tests.md, QA_W3_final.md
2. Midsprint check пройден (Sprint_7/midsprint_check.md существует, статус PASS).
3. CI зелёный (если есть CI pipeline).
4. Все changelog записи S7 синхронизированы.
```

# Обязательные плагины

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| code-review | **да** (mandatory для каждого слоя) | — |
| context7 | да — для проверки API контрактов | WebSearch |
| pyright-lsp | да (выборочно для верификации) | `python -m py_compile` |
| typescript-lsp | да (выборочно) | `npx tsc --noEmit` |
| playwright | да — финальная регрессия | — |
| superpowers (TDD) | нет (ревью существующего кода) | — |

# Обязательное чтение

1. **`Sprint_7/sprint_design.md`** Definition of Done §1.3 — критерии закрытия.
2. **Все 8 DEV-отчётов** + UX + QA + ARCH-design — целиком.
3. **`Sprint_6_Review/code_review.md`** — формат финального ревью (повторить структуру).
4. **`Спринты/project_state.md:79–90`** — MR.5 (5 event_type) — обязательная проверка.
5. **Текущие ФТ/ТЗ/development_plan** — для определения, что обновить.

# Рабочая директория

`Спринты/Sprint_7/`

# Задачи

## 1. Code review всех 17 задач (8 разделов как в Sprint_6_Review)

### Раздел 1 — Trading Engine (7.13, 7.15-be, 7.17-be)
- 7.13: 5 event_type → runtime. Проверка `app/trading/runtime.py`, `app/trading/engine.py`, `app/broker/tinvest/multiplexer.py`.
- 7.15-be: WS endpoint `/ws/trading-sessions/{user_id}`. Проверка auth, payload, подписка на event_bus.
- 7.17-be: WS endpoint `/ws/backtest/{job_id}` + параллельные jobs.

### Раздел 2 — Notification Service (7.12, 7.14)
- 7.12: NS singleton DI. Проверка `app/main.py:state.notification_service` + Depends pattern.
- 7.14: Telegram CallbackQueryHandler. Проверка регистрации router + handlers.

### Раздел 3 — Strategy Engine + AI (7.1, 7.18)
- 7.1: `strategy_versions` миграция, endpoints, политика автоверсий.
- 7.18: `ChatRequest.context` расширение, ownership validation, prompt injection защита.

### Раздел 4 — Backtest Engine (7.2, 7.3, 7.17-be)
- 7.2: Grid Search backend, multiprocessing, hard cap.
- 7.3: Экспорт CSV/PDF (WeasyPrint, openpyxl).
- 7.17-be: фоновые jobs, очередь, BackgroundTasks.

### Раздел 5 — Frontend Charts + Trading + AI chat (7.6, 7.15-fe, 7.16, 7.17-fe, 7.19)
- 7.6: Инструменты рисования, lightweight-charts API, persist.
- 7.15-fe: WS-замена polling, удаление setInterval.
- 7.16: Интерактивные зоны + аналитика (гистограмма + donut).
- 7.17-fe: Бейдж + dropdown + toast + модалка не закрывается.
- 7.19: AI-команды dropdown, парсер, рендер chip.

### Раздел 6 — Frontend Dashboard + Strategy + Wizard (7.1-fe, 7.2-fe, 7.7, 7.8)
- 7.1-fe: VersionsHistoryDrawer, diff, restore confirmation.
- 7.2-fe: GridSearchForm + Heatmap.
- 7.7: BalanceWidget, HealthWidget, ActivePositionsWidget.
- 7.8-fe: FirstRunWizard 5 шагов, Mantine Stepper, дисклеймер.

### Раздел 7 — OPS (7.9 backup)
- BackupService, rotate, CLI restore.
- Smoke-тест прогнан.

### Раздел 8 — E2E + UX полировка (7.10, 7.11)
- E2E: ≥ 134 passed (baseline 119 + ≥ 15 новых).
- UX: delta-доработки выполнены.

## 2. Integration verification — обязательная проверка

Для **каждой** новой сущности из всех 8 DEV-отчётов:

- `grep -rn "<NewClass>(" app/` — есть production call site (не только в тестах).
- C1–C8 контракты подтверждены через grep + runtime проверку.
- **C7 особо:** `grep -rn "NotificationService()" app/` = 0 вне `main.py`.

Любая `⚠️ NOT CONNECTED` помета в DEV-отчёте — блокер до закрытия.

## 3. MR.5 — обязательная проверка из `project_state.md:79–90`

Все 5 event_type подключены к runtime (задача 7.13):

| event_type | Проверка |
|------------|----------|
| trade_opened | `grep -rn "create_notification.*trade_opened" app/trading/` показывает publish-сайт |
| partial_fill | то же для `partial_fill` |
| order_error | то же для `order_error` |
| all_positions_closed | `app/trading/engine.py:681` (или новая строка) — есть `create_notification` |
| connection_lost / connection_restored | `app/broker/tinvest/multiplexer.py` (reconnect loop) |

E2E подтверждение: реальный сценарий (trade открыт → notification приходит во все 3 канала: in-app, Telegram, Email).

## 4. Stack Gotchas

Каждая ловушка, найденная в S7:

- Создан `Develop/stack_gotchas/gotcha-<N+1>-<slug>.md` (формат — см. `README.md` каталога).
- Строка добавлена в `Develop/stack_gotchas/INDEX.md`.
- Чеклист из `Develop/stack_gotchas/README.md` пройден.

Если новых ловушек нет — явно зафиксировать в отчёте «Новых Stack Gotchas в S7 не обнаружено».

## 5. Регрессия E2E

- Baseline 119 passed / 0 failed / 3 skipped (S6 Review).
- После S7: ≥ 119 + ≥ 15 новых = ≥ 134 passed.
- Из `reports/QA_W3_final.md` взять фактические цифры.
- Если есть `failed` — блокер.
- Если есть `skipped` без карточек в backlog — блокер.

## 6. Документация (правило памяти `feedback_review_docs.md`)

### ФТ — `Документация по проекту/functional_requirements.md`

Добавить разделы за S7:

- Версионирование стратегий (история, откат).
- Grid Search оптимизация.
- Экспорт CSV/PDF.
- Инструменты рисования.
- Дашборд-виджеты.
- First-run wizard.
- Backup/restore.
- AI слэш-команды (5 команд + контекстные блоки).
- Аналитика бэктеста (гистограмма P&L, donut Win/Loss, интерактивные зоны).
- Фоновые бэктесты.
- WS обновление карточек сессий.
- 5 новых event_type (trade_opened, partial_fill, order_error, all_positions_closed, connection_lost/restored).
- Telegram inline-кнопки.

Версия документа: v2.4.

### ТЗ — `Документация по проекту/technical_specification.md`

- Cross-DEV contracts C1–C8 как формальные интерфейсы.
- Модель `strategy_versions`.
- Колонка `users.wizard_completed_at`.
- WS endpoints `/ws/trading-sessions/{user_id}`, `/ws/backtest/{job_id}`.
- Расширение `ChatRequest.context`.
- BackupService архитектура.
- Раздел про NotificationService DI.

Версия: v1.4.

### development_plan.md

- S7 → ✅ завершён.
- Добавить 7.18, 7.19 в таблицу спринта (отсутствовали в v2).
- Все переносы 7.12–7.17 → ✅.
- Sprint_7_Review (если делается) — добавить раздел.
- M3 Phase 1 feature-complete — обновить статус.

## 7. UI checklist (правило памяти `feedback_ui_checklist_update.md`)

Создать `Спринты/ui_checklist_s7.md` (или обновить `ui_checklist_s5r.md` → переименовать в `ui_checklist_s7.md`):

- Дашборд-виджеты (баланс, health, sparklines).
- Wizard 5 шагов.
- Инструменты рисования (persist).
- Аналитика бэктеста (гистограмма, donut).
- Бейдж фоновых бэктестов в шапке.
- AI-команды dropdown.
- WS карточки сессий (без polling).
- Интерактивные зоны бэктеста.
- Версионирование стратегий UI.
- Grid Search Heatmap.

## 8. Перенос задач

Если найдены open-задачи (skip-тикеты, технический долг, недоделки):

- Перенести в `Sprint_8_Review/backlog.md` (или `Sprint_7_Review/backlog.md` при наличии).
- Каждый тикет с обоснованием и приоритетом.
- Обновить `Спринты/project_state.md` раздел «Технический долг».

## 9. Финальный вердикт

В `Sprint_7/arch_review_s7.md`:

- **PASS** — все критерии DoD выполнены, S7 закрыт.
- **PASS WITH NOTES** — DoD выполнены, но есть замечания на S8 (списком).
- **FAIL** — блокеры, S7 не закрыт, требуются фиксы.

При PASS обновить:

- `Спринты/project_state.md` — S7 ✅ + обновлена секция «Что делать дальше» (следующее: S8 feature freeze).

# Опциональные задачи

Нет.

# Skip-тикеты

Не применимо (ARCH ревью не пишет тесты, проверяет skip других).

# Тесты

Не применимо (мета-проверка). Однако ARCH прогоняет полную регрессию `pytest` + `playwright` и фиксирует.

# Integration Verification Checklist

Не применимо (мета-проверка). Все DEV-отчёты должны содержать integration verification — ARCH верифицирует.

# Формат отчёта

**2 файла:**

1. **`Sprint_7/arch_review_s7.md`** — полный отчёт по 8 разделам:
   - Каждый раздел: что проверено, что найдено (FIXED/WARNING/INFO/CRITICAL), статус.
   - Раздел «MR.5» — отдельный.
   - Раздел «Регрессия E2E» — цифры.
   - Раздел «Документация» — что обновлено в ФТ/ТЗ/плане.
   - Финальный вердикт.

2. **`Sprint_7/reports/ARCH_S7_review.md`** — краткая 8-секционная сводка до 400 слов.

# Alembic-миграция

Не применимо.

# Чеклист перед сдачей

- [ ] Code review всех 8 разделов проведён.
- [ ] Integration verification для каждой новой сущности подтверждён.
- [ ] MR.5 проверка пройдена (5 event_type подключены через `create_notification`).
- [ ] Stack Gotchas обновлены (новые `gotcha-NN-*.md` + `INDEX.md`).
- [ ] Регрессия E2E ≥ 134 passed / 0 failed.
- [ ] ФТ обновлены за S7.
- [ ] ТЗ обновлено за S7.
- [ ] development_plan.md обновлён (S7 ✅, 7.18/7.19 добавлены).
- [ ] `Спринты/ui_checklist_s7.md` создан.
- [ ] Перенос задач (skip-тикеты, техдолг) в `Sprint_8_Review/backlog.md` (если есть).
- [ ] Финальный вердикт зафиксирован (PASS / PASS WITH NOTES / FAIL).
- [ ] `Спринты/project_state.md` обновлён (S7 ✅).
- [ ] `Sprint_7/changelog.md` обновлён последней записью «7.R PASS».
- [ ] `Sprint_7/sprint_state.md` отражает «✅ завершён».
- [ ] `arch_review_s7.md` сохранён.
- [ ] `reports/ARCH_S7_review.md` сохранён.
