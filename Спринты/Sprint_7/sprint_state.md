# Sprint 7 — текущее состояние

> Обновляется после каждого этапа.

**Дата планирования:** 2026-04-25
**Дата старта W0:** 2026-04-25
**Дата завершения W0:** 2026-04-25
**Дата старта W1:** 2026-04-25
**Дата завершения W1:** 2026-04-25

## Текущий шаг

**W1 — 6 debt-переносов ✅ ЗАВЕРШЁН (BACK1 + BACK2 + FRONT1 параллельно)**

- BACK1 (DEV-1): 7.13 (5 event_type → runtime через EVENT_MAP + publish-сайты), 7.15-be (`/ws/trading-sessions/{user_id}`), 7.17-be (`backtest_jobs` + `BacktestJobManager` + `/ws/backtest/{job_id}` + REST jobs API).
- BACK2 (DEV-2): 7.12 (NS singleton DI), 7.14 (Telegram inline-кнопки + ownership-check).
- FRONT1 (DEV-3): 7.16 (аналитика + интерактивные зоны), 7.15-fe (WS клиент сессий), 7.17-fe (бейдж + dropdown в шапке).

Контракты W1 опубликованы и состыкованы: C7 (BACK2→BACK1, NotificationService DI), C8 (BACK2 callback scheme), C1 (BACK1→FRONT1, `/ws/trading-sessions/`), C2 (BACK1→FRONT1, `/ws/backtest/{job_id}`).

Тесты: backend +41 нового теста, все зелёные (770 passed суммарно, 1 failed = pre-existing `test_process_buy_signal`). Frontend 287/0. Ruff 0 issues.

Готовы к midsprint ARCH-checkpoint, далее — W2.

## Прогресс по этапам

| Этап | Статус | Артефакты |
|------|--------|-----------|
| Планирование (sprint_design + prompts) | ✅ завершено | sprint_design.md, prompt_*.md, execution_order.md |
| W0 — UX макеты + ARCH design + QA test plan | ✅ завершено | ux/* (6), arch_design_s7.md, e2e_test_plan_s7.md, reports/ARCH_W0_design.md, reports/UX_W0_design.md, reports/QA_W0_test_plan.md |
| W1 — 6 переносов из S6 (debt first) | ✅ завершено | reports/DEV-1_BACK1_W1.md (✅ 7.13, 7.15-be, 7.17-be), reports/DEV-2_BACK2_W1.md (✅ 7.12, 7.14), reports/DEV-3_FRONT1_W1.md (✅ 7.16, 7.15-fe, 7.17-fe) |
| Midsprint checkpoint | ✅ PASS | midsprint_check.md, reports/ARCH_midsprint_review.md (pytest 771/0, vitest 287/0, Playwright 119/0/3) |
| W2 — новый функционал | ⬜ не начат | reports/DEV-X_W2.md |
| W3 — UX полировка + 7.R + 7.11 финальный E2E | ⬜ не начат | arch_review_s7.md, ui_checklist_s7.md |

## Прогресс по задачам

См. `execution_order.md` для трекеров. Задачи S7:

**Блок A (Should-фичи):** 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11
**Блок B (переносы из S6):** 7.12, 7.13, 7.14, 7.15, 7.16, 7.17
**Блок C (AI-команды):** 7.18, 7.19
**Блок D:** 7.R

## Ключевые риски

- **Объём:** 17 рабочих задач + UX/ARCH/QA. Заказчик подтвердил: «делаем всё, время гибкое».
- **Midsprint gate:** если W1 (debt) не закроется чисто — W2 не стартует.
- **MR.5 (5 event_type подключены):** обязательная проверка ARCH на финале (см. `project_state.md:79–90` и Приложение C спека).
- **Cross-DEV контракты C1–C9:** должны публиковаться в правильном порядке (см. `execution_order.md` раздел «Правила гонки и приёмки контрактов»). C9 (`GET /account/balance/history`) добавлен после ARCH W0 review для sparkline в виджете «Баланс».

## Следующее действие

**Midsprint checkpoint — PASS (2026-04-25).**

- Backend pytest: **771 passed / 0 failed** (после фикса pre-existing `test_process_buy_signal`).
- Frontend vitest: **287 passed / 0 failed**, `tsc --noEmit` 0 errors.
- E2E Playwright: **119 passed / 0 failed / 3 skipped** (соответствует S6 baseline, 4.4 мин).
- Контракты W1 (C1/C2/C7/C8) состыкованы, MR.5 (5 event_type) — все publish-сайты в production-коде.
- ARCH midsprint review = PASS (см. `reports/ARCH_midsprint_review.md`).

Открытые на 7.R: real-mode test_order_manager (нет покрытия), Decimal→str в `BacktestJob.params_json`, 6 lint errors в pre-existing файлах.

Дальше — старт **W2** (новый функционал): 7.1, 7.2-be, 7.3, 7.6, 7.7+C9, 7.8, 7.9, 7.18, 7.19. Приоритеты публикации контрактов: BACK2 публикует C4 (alembic `strategy_versions`) первым → BACK1 публикует C9 (`/account/balance/history`) до старта FRONT2 7.7. Ожидание команды заказчика на запуск W2.
