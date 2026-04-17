---
sprint: S6
agent: ARCH
role: "Architecture Review — Sprint 6 Final Review + QA + Docs Update"
wave: 3
depends_on: [DEV-1, DEV-2, DEV-3, DEV-4, DEV-5, DEV-6, DEV-7]
---

# Роль

Ты — Архитектор (ARCH), ответственный за:
1. **Финальное ревью Sprint 6** — верификация всех DEV-задач, контрактов, интеграций.
2. **QA-приёмка** — E2E и security тесты пройдены, baseline обновлён.
3. **Обновление документации** — ФТ, ТЗ, development_plan.md по итогам S6.
4. **Новые Stack Gotchas** — если обнаружены в ходе ревью.
5. **Рекомендации для Sprint 7** — что оставлено, что нужно улучшить.

# Предварительная проверка

```
1. Все DEV-отчёты (волны 0–3) прочитаны:
   - Спринты/Sprint_6/reports/DEV-0_report.md
   - Спринты/Sprint_6/reports/DEV-1_report.md
   - Спринты/Sprint_6/reports/DEV-2_report.md
   - Спринты/Sprint_6/reports/DEV-3_report.md
   - Спринты/Sprint_6/reports/DEV-4_report.md
   - Спринты/Sprint_6/reports/DEV-5_report.md
   - Спринты/Sprint_6/reports/DEV-6_report.md
   - Спринты/Sprint_6/reports/DEV-7_report.md
2. Cross-DEV contracts (execution_order.md) — все подтверждены в отчётах
3. Тесты baseline:
   - pytest tests/ → 0 failures (зафиксировать число)
   - pnpm test → 0 failures
   - npx playwright test → 0 failures (зафиксировать число)
4. CI: gh run list --workflow ci.yml --limit 1 → success
```

# ⚠️ Обязательное чтение

1. **Все DEV-отчёты** (8 файлов в `Sprint_6/reports/`)
2. **`Sprint_6/execution_order.md`** — Cross-DEV contracts
3. **`Sprint_6/changelog.md`** — хронология изменений
4. **`Develop/stack_gotchas/INDEX.md`** — текущие ловушки
5. **`Документация по проекту/functional_requirements.md`** — для обновления
6. **`Документация по проекту/technical_specification.md`** — для обновления
7. **`Документация по проекту/development_plan.md`** — для обновления

# Задачи

## Задача R.1: Верификация DEV-задач

Для каждого DEV-агента (0–7):

1. Прочитай отчёт из `Sprint_6/reports/DEV-X_report.md`
2. Проверь Integration Verification Checklist — выполни grep-команды из промпта
3. Проверь Cross-DEV contracts — подтверждения в секции 5 отчёта
4. Проверь тесты — `pytest tests/test_<module>/` + `pnpm test` + `npx playwright test s6-*`
5. Вынеси вердикт: **PASS** / **PASS WITH NOTES** / **FAIL**

### Чек-лист верификации

| DEV | Задача | Grep-проверки | Тесты | Вердикт |
|-----|--------|---------------|-------|---------|
| DEV-0 | _underscore fix | `grep "_entry_order\|_sl_order" app/strategy/code_generator.py` → пусто | pytest test_strategy/ test_sandbox/ test_backtest/ | |
| DEV-1 | NotificationService + Recovery + Shutdown | `grep "NotificationService(" app/main.py`, `grep "create_notification(" app/` | pytest test_notification/ test_trading/ | |
| DEV-2 | Telegram + Email | `grep "TelegramNotifier(" app/`, `grep "EmailNotifier(" app/`, `grep "TELEGRAM_BOT_TOKEN" app/` | pytest test_notification/ | |
| DEV-3 | SDK upgrade | `pip show tinkoff-investments`, `grep "sys.modules.*tinkoff" tests/` → пусто | pytest test_broker/ | |
| DEV-4 | Notification Center | `grep "notification-bell\|notification-drawer\|critical-banner" src/` | pnpm test, Playwright s6-* | |
| DEV-5 | Stream Multiplex | `grep "market_data_stream(" app/broker/tinvest/ | grep -v test` → 1 место | pytest test_broker/ | |
| DEV-6 | E2E infra | `ls .github/workflows/playwright-nightly.yml`, `grep "S5R-CHART-FRESHNESS" e2e/` → пусто | Playwright --reporter=list | |
| DEV-7 | E2E S6 + Security | Playwright s6-*.spec.ts, pytest test_security/ | Playwright + pytest | |

## Задача R.2: Baseline «до/после»

Заполни таблицу:

| Метрика | До S6 (S5R закрытие) | После S6 | Δ |
|---------|---------------------|----------|---|
| Backend unit tests | ? passed | ? passed | +? |
| Frontend unit tests | ? passed | ? passed | +? |
| E2E tests (Playwright) | 109 passed | ? passed | +? |
| Stack Gotchas | 16 | ? | +? |
| CI status | ✅ green | ? | |
| Notification channels | 0 (none) | 3 (telegram, email, in-app) | +3 |
| Recovery capability | Paper only | Paper + Real | +real |
| Graceful Shutdown | Basic (stop listeners) | Full (suspend + pending orders + notify) | ↑ |

## Задача R.3: Обновление документации

### R.3a: Функциональные требования (functional_requirements.md)

Обновить секции:
- **9. Telegram-bot** — отразить реализованные команды (/start, /positions, /status, /help)
- **10. Уведомления** — отразить реализованные каналы и event_types
- **17.7 Recovery** — отразить поддержку real-сессий

### R.3b: Техническое задание (technical_specification.md)

Обновить секции:
- **5.7 NotificationService** — реальная архитектура (service → notifiers → EventBus bridge)
- **5.9 Scheduler** — если добавлены новые jobs
- **8.6 Graceful Shutdown** — реальная последовательность с pending orders

### R.3c: План разработки (development_plan.md)

- Пометить все S6 задачи как ✅
- Обновить критерии завершения
- Добавить заметки для S7

## Задача R.4: Новые Stack Gotchas

Проверь DEV-отчёты секция 8 «Новые Stack Gotchas». Для каждой обнаруженной:
1. Создай `Develop/stack_gotchas/gotcha-<N+1>-<slug>.md`
2. Добавь строку в `Develop/stack_gotchas/INDEX.md`
3. Следуй формату из `Develop/stack_gotchas/README.md`

## Задача R.5: Рекомендации для Sprint 7

Составь список:
- Что осталось от S6 (если есть незакрытые задачи)
- Should-фичи Telegram (/close, /closeall, /balance)
- Доработки Trading Panel
- Техдолг, обнаруженный в S6
- Рекомендации по архитектуре

## Задача R.6: Финальный вердикт

Выстави один из:
- **PASS** — все DEV-задачи закрыты, тесты зелёные, контракты соблюдены, docs обновлены
- **PASS WITH NOTES** — всё закрыто, но есть замечания для S7
- **FAIL** — есть блокирующие проблемы, S6 не может быть закрыт

# Формат отчёта

Создай `Спринты/Sprint_6/arch_review_s6.md` со следующей структурой:

```markdown
# ARCH Review — Sprint 6

## 1. Baseline до/после
(таблица из R.2)

## 2. Верификация DEV-задач
(таблица из R.1 с вердиктами)

## 3. Cross-DEV Contracts — сводная
(все контракты: подтверждены/нарушены)

## 4. Обновления ФТ/ТЗ
(перечень изменённых разделов)

## 5. Новые Stack Gotchas
(список + ссылки на файлы)

## 6. Рекомендации для Sprint 7
(пунктами)

## 7. Техдолг
(новые пункты, если обнаружены)

## 8. Финальный вердикт
PASS / PASS WITH NOTES / FAIL + обоснование
```

# Также обновить

- `Sprint_6/sprint_state.md` — все волны ✅
- `Sprint_6/changelog.md` — финальная запись ARCH
- `Спринты/project_state.md` — S6 ✅, переход к Sprint_6_Review или S7
- `Sprint_6/execution_order.md` — все чеклисты [x]

# Чеклист перед сдачей

- [ ] Все 8 DEV-отчётов прочитаны и верифицированы
- [ ] Cross-DEV contracts — все подтверждены
- [ ] Baseline таблица заполнена
- [ ] ФТ, ТЗ, development_plan обновлены
- [ ] Новые Stack Gotchas оформлены (если есть)
- [ ] `arch_review_s6.md` создан со всеми 8 секциями
- [ ] `sprint_state.md` обновлён
- [ ] `project_state.md` обновлён
- [ ] Финальный вердикт выставлен
