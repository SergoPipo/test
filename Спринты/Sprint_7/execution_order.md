# Sprint 7 — Execution Order

> Порядок исполнения работ + Cross-DEV contracts таблица.
> Источник истины для оркестратора. Каждый DEV-агент в W1/W2 цитирует таблицу контрактов.

---

## 1. Обзор спринта

**Цель:** Phase 1 feature-complete — закрыть весь долг S6, реализовать оставшиеся Should-функции, добавить AI слэш-команды.

**Состав:** 17 рабочих задач + 7.R (ARCH ревью).

### Блок A — Should-фичи

| # | Задача | Исполнитель |
|---|--------|-------------|
| 7.1 | Версионирование стратегий (история, откат) | BACK2 + FRONT2 |
| 7.2 | Grid Search оптимизация (multiprocessing) | BACK1 + FRONT2 |
| 7.3 | Экспорт CSV/PDF бэктеста | BACK2 |
| 7.6 | Инструменты рисования (тренды, уровни, зоны) | FRONT1 |
| 7.7 | Дашборд: виджеты баланса, health, sparklines | FRONT1 + FRONT2 |
| 7.8 | Дисклеймер (first-run wizard, 5 шагов) | FRONT2 + BACK2 |
| 7.9 | Backup/restore (автобэкап, ротация, CLI) | OPS + BACK1 |
| 7.10 | UX финальная полировка | UX |
| 7.11 | E2E S7 (полный цикл) | QA |

### Блок B — Переносы из S6

| # | Задача | Исполнитель | Класс |
|---|--------|-------------|-------|
| 7.12 | NotificationService singleton (DI) | BACK2 | tech debt |
| 7.13 | 5 event_type → runtime | BACK1 | tech debt |
| 7.14 | Telegram inline-кнопки | BACK2 | tech debt |
| 7.15 | WS-обновление карточек сессий | BACK1 + FRONT1 | new feature |
| 7.16 | Интерактивные зоны + аналитика P&L/donut | FRONT1 | new feature |
| 7.17 | Фоновый запуск бэктеста | BACK1 + FRONT1 | new feature |

### Блок C — AI-команды (новое в S7)

| # | Задача | Исполнитель |
|---|--------|-------------|
| 7.18 | AI слэш-команды backend (расширение ChatRequest.context) | BACK2 |
| 7.19 | AI слэш-команды frontend (dropdown + рендер контекста) | FRONT1 |

### Блок D — ARCH ревью

| # | Задача | Исполнитель |
|---|--------|-------------|
| 7.R | Финальное ARCH-ревью + ФТ/ТЗ/development_plan sync | ARCH |

### Треки исполнения по DEV (debt first)

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
  W2: саппорт 7.7 — sparklines

FRONT2 (Dashboard + Strategy editor + Settings):
  W1: — (нет debt — подключается к W0 UX-design консультациям)
  W2: 7.1-fe Версионирование UI (history, diff, восстановить)
  W2: 7.7    Дашборд-виджеты (баланс, health, sparklines)
  W2: 7.8-fe First-run wizard (5 шагов)
  W2: 7.2-fe Grid Search UI (форма + heatmap)

OPS:
  W2: 7.9    Backup/restore (главный)
  W2: саппорт 7.11 запуск backend+frontend в E2E

ARCH:
  W0: design ревью + brainstorm 7.1/7.2/7.13/7.15/7.17/7.18
  W1: проверка контрактов после каждой debt-задачи
  Midsprint check после W1 — cross-DEV contracts verification + Stack Gotchas update
  W2: ревью DEV-отчётов
  7.R: финальное ARCH-ревью + проверка MR.5

UX:
  W0: 6 макетов
  Midsprint UX-review реализации W1
  W3: 7.10 финальная полировка

QA:
  W0: e2e_test_plan_s7.md (описание сценариев ДО написания тестов)
  W1: E2E под debt-задачи 7.13–7.17
  W2/W3: E2E под фичи + регрессия 119 baseline + 7.11 финальный прогон

SEC: ревью 7.13 (event leakage), 7.14 (callback origin), 7.18 (prompt injection).
```

---

## 2. Календарный график

```
ДЕНЬ  ЭТАП                                  ИСПОЛНИТЕЛИ          АРТЕФАКТЫ
────────────────────────────────────────────────────────────────────────────
1-2   W0: UX макеты (6 файлов)              UX                   Sprint_7/ux/*
        + ARCH design ревью                 ARCH                 arch_design_s7.md
        + brainstorm 7.1/7.2/7.13/                               reports/ARCH_W0_design.md
        7.15/7.17/7.18                                           reports/UX_W0_design.md
        + e2e_test_plan_s7.md (полное)      QA                   e2e_test_plan_s7.md
        + Stack Gotchas pre-read            ARCH                 (записи в INDEX.md если найдено)

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

## 3. W0 Preflight (ДО старта DEV-агентов)

ARCH, UX, QA выполняют параллельно за 1–2 дня.

### ARCH (prompt_ARCH_design.md)

1. Brainstorm 7.1, 7.2, 7.13, 7.15, 7.17, 7.18 через `superpowers:brainstorming`.
2. Создать `Sprint_7/arch_design_s7.md` со схемами:
   - Модель `strategy_versions` (поля, индексы, миграция, политика автоверсий).
   - Дизайн Grid Search (параллелизация, лимит N комбинаций, формат matrix).
   - WS-канал `/ws/trading-sessions/{user_id}` (auth, payload, reconnect).
   - Очередь фоновых бэктестов + `/ws/backtest/{job_id}`.
   - Расширение `ChatRequest.context` для AI-команд (схема, защита от injection).
   - 5 event_type publish-сайтов (file:line, контекст, EVENT_MAP шаблоны).
3. Stack Gotchas pre-read: 5–7 ключевых ловушек из `Develop/stack_gotchas/INDEX.md` для S7.
4. Согласовать стыки с UX-макетами после публикации UX 6 файлов.
5. **Дословные цитаты ТЗ/ФТ** для каждой подзадачи (DEV-промпты ссылаются на эти цитаты).
6. Сохранить отчёт в `Sprint_7/reports/ARCH_W0_design.md`.

### UX (prompt_UX.md, фаза W0)

1. Создать 6 макетов в `Sprint_7/ux/` (см. список в `sprint_design.md` Приложение D).
2. Согласовать с ARCH архитектурные ограничения после `arch_design_s7.md`.
3. Сохранить отчёт в `Sprint_7/reports/UX_W0_design.md`.

### QA (prompt_QA.md, фаза W0)

1. Создать `Sprint_7/e2e_test_plan_s7.md` с описанием ВСЕХ сценариев ДО написания тестов (правило памяти `feedback_e2e_testing.md`).
2. Подтвердить инфраструктуру через `preflight_checklist.md`.
3. Сохранить отчёт в `Sprint_7/reports/QA_W0_test_plan.md`.

### Гейт W0 → W1

- ARCH `arch_design_s7.md` опубликован.
- UX 6 макетов в `ux/` опубликованы.
- QA `e2e_test_plan_s7.md` опубликован (без TBD).
- `preflight_checklist.md` пройден.

Тогда оркестратор запускает DEV-агентов (W1).

---

## 4. Cross-DEV contracts

> Один источник истины. Каждый DEV-промпт цитирует свою роль в этой таблице (поставщик/потребитель).

| # | Задача | Поставщик | Потребитель | Контракт |
|---|--------|-----------|-------------|----------|
| C1 | 7.15 | BACK1 | FRONT1 | `WS /ws/trading-sessions/{user_id}` → `{event:'position_update'\|'trade_filled'\|'pnl_update'\|'session_state', session_id, payload}`. Авторизация — JWT в query string или cookie |
| C2 | 7.17 | BACK1 | FRONT1 | `WS /ws/backtest/{job_id}` → `{progress:0..100, status:'queued'\|'running'\|'done'\|'error', result?}`. Параллельные jobs — отдельные WS-каналы |
| C3 | 7.18/7.19 | BACK2 | FRONT1 | `POST /api/v1/ai/chat` body расширяется: `context:[{type:'chart'\|'backtest'\|'strategy'\|'session'\|'portfolio', id}]`. Backend сам подгружает данные по id и формирует enriched prompt |
| C4 | 7.1 | BACK2 | FRONT2 | `GET /api/v1/strategies/{id}/versions`, `POST /api/v1/strategies/{id}/versions`, `POST /api/v1/strategies/{id}/versions/{ver_id}/restore`. Хранение: `strategy_versions(id, strategy_id, blocks_xml, code, created_at, created_by, comment)` |
| C5 | 7.2 | BACK1 | FRONT2 | `POST /api/v1/backtest/grid` body: `{strategy_id, ranges:{param_name:[v1,v2,...]}}` → `{job_id}`; результат через WS C2 (общий `/ws/backtest/`) с матрицей `{params, sharpe, pnl, win_rate}[]` в `result` |
| C6 | 7.8 | BACK2 | FRONT2 | `POST /api/v1/users/me/wizard/complete`; `GET /api/v1/users/me` отдаёт `wizard_completed_at:datetime\|null` |
| C7 | 7.12 | BACK2 | BACK1, OPS | `request.app.state.notification_service` (FastAPI Depends pattern). Все `NotificationService()` в коде заменяются. Проверка: `grep -rn "NotificationService()" app/` = 0 вне `main.py` |
| C8 | 7.14 | BACK2 | (deep link) | CallbackData scheme: `open_session:{session_id}`, `open_chart:{ticker}`. Deep link → `/sessions/{id}` или `/chart?ticker=...` |
| C9 | 7.7 | BACK1 | FRONT2 | `GET /api/v1/account/balance/history?days=30` → `[{ts:datetime, total_value:float, currency:'RUB'}]` для sparkline в виджете «Баланс». Источник — агрегированные снимки баланса (см. `arch_design_s7.md` §8). Добавлен после ARCH W0 review. |

### Правила гонки и приёмки контрактов

- **C1, C2, C5 (WS-каналы):** BACK1 публикует пустой WS-эндпоинт + JSON-схему первой; FRONT1/FRONT2 пишут клиент по схеме; интеграция — после реальной публикации сообщений. Перевод polling→WS делается ровно одним PR (избежать двойного источника правды).
- **C3 (AI context):** BACK2 первым публикует расширение схемы запроса; FRONT1 идёт по уже задокументированному формату.
- **C4 (versioning):** Alembic-миграция от BACK2 — ПЕРВОЕ, что делается в треке (FRONT2 не стартует пока schema не закоммичена).
- **C7 (NS singleton):** одной волной правится во всех вызывающих модулях. Hook `plugin-check.sh` ловит compile-time ошибки сразу.
- **Integration verification:** каждый DEV в отчёте подтверждает `grep -rn "<NewClass>(" app/` (правило CLAUDE.md). C7 проверяется отдельно: `grep -rn "NotificationService()" app/` должен дать 0 совпадений вне `main.py`.

---

## 5. W1 Порядок (параллельно, debt first)

| DEV | Задачи | Зависит от | Блокирует |
|-----|--------|-----------|-----------|
| BACK1 (DEV-1) | 7.13, 7.15-be, 7.17-be | W0 ARCH design | C1, C2 для FRONT1 |
| BACK2 (DEV-2) | 7.12, 7.14 | W0 ARCH design | C7 для BACK1, OPS, всех |
| FRONT1 (DEV-3) | 7.16, 7.15-fe, 7.17-fe | W0 UX (`backtest_overview_analytics.md`, `background_backtest_badge.md`), C1 от BACK1, C2 от BACK1 | midsprint UX-review |
| FRONT2 (DEV-4) | — | — | (FRONT2 ждёт W2) |
| OPS (DEV-5) | — | — | (OPS ждёт W2) |

Все 3 DEV-агента (BACK1, BACK2, FRONT1) запускаются одновременно.

**Контрактные точки W1:**

- BACK2 публикует C7 (NS singleton) ПЕРВЫМ — это снимает риск гонок с BACK1 (BACK1 потребитель C7 для 7.13).
- BACK1 публикует C1 (WS схема trading-sessions) до того, как FRONT1 пишет клиент.
- BACK1 публикует C2 (WS схема backtest) до того, как FRONT1 пишет dropdown.

**Финиш W1:** все 6 переносов закрыты с integration verification → midsprint checkpoint.

---

## 6. Midsprint Checkpoint (день 7)

**Гейт перед запуском W2.** Цель — не пускать новые фичи на сломанный фундамент.

Чек-лист (исполнитель ARCH, итог в `Sprint_7/midsprint_check.md`):

1. **Все 6 переносов закрыты с integration verification.** Для 7.13 — отдельная проверка по MR.5: каждый из 5 event_type производит `create_notification` в production-коде (не только в тестах).
2. **Контракты W1 (C1, C2, C7, C8) подтверждены.** `grep -rn "NotificationService()" app/` = 0 вне `main.py`.
3. **Регрессия E2E baseline 119 passed / 0 failed** не сломана. Если хоть один тест упал из-за W1 — стоп.
4. **Stack Gotchas обновлены:** новые `gotcha-NN-*.md` за каждую найденную ловушку + строки в `INDEX.md`.
5. **UX-приёмка W0-макетов реализацией 7.16, 7.15-fe, 7.17-fe.** UX подтверждает соответствие или фиксирует delta для 7.10.
6. **Логи синхронизированы:** `changelog.md` ведётся, `sprint_state.md` отражает шаг.

**Если гейт провален:** W2 не стартует. Любые проблемы W1 закрываются волной фиксов до запуска W2.

---

## 7. W2 Порядок (параллельно)

| DEV | Задачи | Зависит от | Блокирует |
|-----|--------|-----------|-----------|
| BACK1 (DEV-1) | 7.2-be, 7.7-be (C9 balance/history), 7.9 | W1 завершён, OPS саппорт для 7.9 | C5, C9 для FRONT2 |
| BACK2 (DEV-2) | 7.1-be, 7.3, 7.8-be, 7.18 | W1 завершён, ARCH design (для 7.18) | C3 для FRONT1, C4 для FRONT2, C6 для FRONT2 |
| FRONT1 (DEV-3) | 7.6, 7.19 + саппорт 7.7 | W0 UX (`drawing_tools.md`, `ai_commands_dropdown.md`), C3 от BACK2 | — |
| FRONT2 (DEV-4) | 7.1-fe, 7.7, 7.8-fe, 7.2-fe | W0 UX (`dashboard_widgets.md`, `wizard_5steps.md`), C4 от BACK2, C5 от BACK1, C6 от BACK2 | — |
| OPS (DEV-5) | 7.9 (главный) | W1 завершён | — |

**Контрактные точки W2:**

- BACK2 публикует C4 (Alembic миграция `strategy_versions`) ПЕРВЫМ в треке — FRONT2 не стартует пока schema не закоммичена.
- BACK2 публикует C3 (расширение ChatRequest.context) до того, как FRONT1 пишет dropdown.
- BACK1 публикует C5 (POST /backtest/grid) — FRONT2 пишет UI.
- BACK1 публикует C9 (GET /account/balance/history) до старта FRONT2 7.7 (sparkline в виджете «Баланс»).

**Финиш W2:** все 9 фич W2 закрыты с integration verification → W3.

---

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
| ARCH | Обновить `Спринты/ui_checklist_s7.md` (правило памяти `feedback_ui_checklist_update.md`) |
| ARCH | Обновить ФТ (`functional_requirements.md`), ТЗ (`technical_specification.md`), `development_plan.md` (правило памяти `feedback_review_docs.md`). В частности добавить разделы про AI-команды (7.18/7.19), которых ещё нет в `development_plan.md` |
| ARCH | Сохранить итог в `Sprint_7/arch_review_s7.md` (формат как `Sprint_6_Review/code_review.md`) |
| ARCH | Финальный вердикт: PASS / PASS WITH NOTES / FAIL |

**Гейт PASS:** S7 закрыт → можно ставить S8 (feature freeze).
