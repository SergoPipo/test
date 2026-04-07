# Промежуточное ревью после Sprint 6

> **Milestone M3: Торговля**
> Охватывает: Sprint 5 (Торговля + Circuit Breaker) + Sprint 6 (Уведомления)

## Цель

Ревью кода и бэклог доработок по итогам реализации Paper/Real Trading, Circuit Breaker, облигаций (НКД), Telegram-уведомлений.

## Что реализовано к этому моменту

### Sprints 1-4 (M1: Каркас + M2: Бэктест)
_См. Sprint_4_Review/README.md — полный список реализованного до S5._

### Sprint 5 (Торговля + Bond)
_Заполняется после завершения Sprint 5._

### Sprint 6 (Уведомления)
_Заполняется после завершения Sprint 6._

**Статистика:** _обновить после завершения S6_

## Порядок работы

1. **UI-проверки (Playwright)** → [ui_checklist_s6_review.md](ui_checklist_s6_review.md)
   - Полная регрессия всех UI-проверок (S1-S6)
   - Новые проверки: торговля, ордера, Circuit Breaker, уведомления
   - Скриншоты в `e2e/screenshots/s6-review/`
   - При ❌ → исправление → повторный прогон

2. **Актуализация ФТ/ТЗ** → `Документация по проекту/`
   - Собрать все изменения за S5+S6 (changelog, sprint_report, решения заказчика)
   - Обновить `functional_requirements.md`, `technical_specification.md`, `development_plan.md`

3. **Ревью кода** → [code_review.md](code_review.md)
   - Чеклист по S5 + S6 компонентам
   - Регрессия архитектурных решений S1-S4

4. **Бэклог доработок** → [backlog.md](backlog.md)

5. **Выполнение** → [execution_log.md](execution_log.md)

## Файлы

| Файл | Описание |
|------|----------|
| [ui_checklist_s6_review.md](ui_checklist_s6_review.md) | UI-чеклист: полная регрессия S1-S6 |
| [code_review.md](code_review.md) | Чеклист ревью кода S5+S6 |
| [backlog.md](backlog.md) | Бэклог доработок |
| [execution_log.md](execution_log.md) | Лог выполнения |

## Предыдущее ревью

Sprint_4_Review/ — после Sprint 3 + Sprint 4
