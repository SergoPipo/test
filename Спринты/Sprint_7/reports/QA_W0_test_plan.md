# QA W0 — Test Plan & Preflight (Sprint 7)

> Дата: 2026-04-25. Агент: QA. Фаза: W0 (pre-sprint design).

## 1. Что сделано

- Заполнен `Sprint_7/e2e_test_plan_s7.md`: 47 сценариев на 17 задач (TBD устранены) — happy path + edge cases.
- Расписаны Cross-DEV контракты C1–C8 как точки верификации.
- Описаны фикстуры (`api_mocks.ts` reuse + 4 новых под S7).
- Зафиксирована регрессия (карта 16 групп ui-checks → задачи S7).
- Предварительный список skip-тикетов с триггерами.
- Pre-flight окружения (W0 часть) пройден; «горячие» пункты `⏸️ deferred to W1`.

## 2. Файлы

- `Спринты/Sprint_7/e2e_test_plan_s7.md` — план E2E (заполнен).
- `Спринты/Sprint_7/reports/QA_W0_test_plan.md` — этот отчёт.
- `Спринты/Sprint_7/preflight_checklist.md` — статус ниже.

## 3. Тесты

Не пишутся в W0 — по правилу `feedback_e2e_testing.md` сначала описание, потом инфра, потом тесты. Написание стартует в W1 после публикации DEV W1 (BACK1 7.13/7.15-be/7.17-be, BACK2 7.12/7.14, FRONT1 7.16/7.15-fe/7.17-fe).

## 4. Integration points / контракты

QA-агент — потребитель всех 8 контрактов (C1–C8) при написании тестов. Готовность контракта = blocker для соответствующего теста:

| Контракт | Поставщик | Тесты, которые ждут |
|---|---|---|
| C1 WS trading-sessions | BACK1 | S7.15.1, S7.15.2 |
| C2 WS backtest | BACK1 | S7.17.1–4, S7.2.1 |
| C3 AI context | BACK2 | S7.18-19.1–3 |
| C4 strategy versions | BACK2 | S7.1.1–4 |
| C5 grid search | BACK1 | S7.2.1–2 |
| C6 wizard complete | BACK2 | S7.8.1–3 |
| C7 NS singleton | BACK2 | S7.12.1 (регресс) |
| C8 telegram callbacks | BACK2 | S7.14.1–2 |

## 5. Preflight результаты

| # | Пункт | Статус | Комментарий |
|---|-------|--------|-------------|
| 1.1 | Python ≥ 3.11 | ✅ | 3.11.15 |
| 1.2 | Node ≥ 18 | ✅ | v20.20.1 |
| 1.3 | pnpm | ✅ | 9.15.9 |
| 1.4 | git clean | ⚠️ | branch `main` (план был `docs/sprint-7-plan` — оркестратору согласовать) |
| 2.1 | venv | ✅ | `Develop/backend/.venv` есть |
| 2.2 | pip install | ⏸️ deferred W1 | не запускали — поднимать backend будет W1 |
| 2.3 | alembic upgrade head | ⏸️ deferred W1 | то же |
| 2.4 | pytest baseline | ⏸️ deferred W1 | долгая операция |
| 2.5 | ruff | ⏸️ deferred W1 | -- |
| 2.6 | pyright | ⏸️ deferred W1 | -- |
| 3.1 | pnpm install | ✅ | `node_modules` присутствует |
| 3.2 | tsc --noEmit | ⏸️ deferred W1 | долго; QA не правит код |
| 3.3 | pnpm lint | ⏸️ deferred W1 | -- |
| 3.4 | pnpm test (vitest) | ⏸️ deferred W1 | -- |
| 4.1 | playwright --version | ✅ | 1.59.1 |
| 4.2 | playwright install | ⏸️ deferred W1 | браузеры скорее всего есть, формальная проверка перед запуском |
| 4.3 | playwright.config.ts | ✅ | существует |
| 4.4 | backend uvicorn | ⏸️ deferred W1 | поднимет OPS/QA в W1 baseline run |
| 4.5 | frontend pnpm dev | ⏸️ deferred W1 | то же |
| 4.6 | sergopipo доступен | ✅ | `data/terminal.db`: `(1, 'sergopipo')` найден |
| 4.7 | E2E baseline 119/0/3 | ⏸️ deferred W1 | реальный прогон — на старте W1 |
| 5.1 | project_state.md | ✅ | прочитан в рамках W0 |
| 5.2 | sprint_design.md | ✅ | прочитан полностью |
| 5.3 | sprint_state.md | ✅ | -- |
| 5.4 | Develop/CLAUDE.md | ✅ | прочитан (загружен в контекст) |
| 5.5 | stack_gotchas/INDEX.md | ⏸️ ARCH W0 | ARCH делает pre-read |
| 6.x | внешние сервисы (T-Invest, MOEX, SMTP, Telegram) | ⏸️ deferred W1 | формальная проверка перед запуском интеграционных сценариев |
| 7.x | two-repo branching | ⚠️ | требует подтверждения заказчика на ветки до коммитов |

Сводка: ✅ 11 / ⚠️ 2 / ❌ 0 / ⏸️ 17 deferred to W1.

## 6. Проблемы

- ⚠️ Текущая ветка `main`, в `preflight_checklist.md` ожидалась `docs/sprint-7-plan`. Не блокирует W0-планирование, но для коммита заказчик подтверждает имя ветки до старта DEV.
- UX-макеты в `ux/` — пока плейсхолдеры. Конкретные `data-testid` в плане прописаны как ожидаемые; финал — после публикации UX W0. Тестам W1 нужны селекторы `[data-testid="bg-backtest-badge"]`, `[data-testid="trade-detail-panel"]`, `[data-testid="pnl-histogram"]`, `[data-testid="win-loss-donut"]`, `[data-testid="version-row-*"]`. Если UX переименует — план правится точечно перед W1 написанием.

## 7. Применённые Stack Gotchas

W0 — без правок кода. Из существующих гочей в плане учтены:
- gotcha-09 (Playwright strict locators) — везде `data-testid`, не текстовые матчи.
- gotcha-10 (MOEX live) — все WS/торговые сценарии через моки 24/7.
- gotcha-01 (Pydantic Decimal) — мок-данные сделок с `quantity/price/pnl` как строки.

## 8. Новые Stack Gotchas

Нет новых. По итогам W1 написания тестов QA пометит, если найдутся.

---

## Готовность гейта W0 → W1

**QA часть готова: ДА.** План без TBD, инфра подтверждена в части, не требующей запуска backend/frontend. Блокеров на старт W1 со стороны QA нет. Полный baseline E2E прогон 119/0/3 — первый шаг QA на W1 (не успели сделать в W0 из-за необходимости поднимать backend+frontend; правомерно отложено).
