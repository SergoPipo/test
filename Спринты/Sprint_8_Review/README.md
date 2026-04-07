# Финальное ревью после Sprint 8

> **Milestone M4: Production-ready**
> Охватывает: Sprint 7 (Should-фичи + Полировка) + Sprint 8 (Стабилизация)

## Цель

Финальное ревью всего проекта перед релизом: coverage 80%, security audit, performance, полное регрессионное тестирование.

## Что реализовано к этому моменту

### Sprints 1-6 (M1-M3)
_См. Sprint_6_Review/README.md — полный список реализованного до S7._

### Sprint 7 (Should-фичи + Полировка)
_Заполняется после завершения Sprint 7._
_Запланировано: интерактивные зоны сделок, аналитика P&L, фоновый запуск бэктестов._

### Sprint 8 (Стабилизация)
_Заполняется после завершения Sprint 8._

**Статистика:** _обновить после завершения S8_

## Порядок работы

1. **UI-проверки (Playwright)** → [ui_checklist_s8_review.md](ui_checklist_s8_review.md)
   - **Полная регрессия** всех UI-проверок за все спринты (S1-S8)
   - Финальный прогон перед релизом
   - Скриншоты в `e2e/screenshots/s8-review/`
   - При ❌ → исправление → повторный прогон

2. **Финальная актуализация ФТ/ТЗ** → `Документация по проекту/`
   - Собрать все изменения за S7+S8 (changelog, sprint_report, решения заказчика)
   - Финальная сверка ФТ/ТЗ с реализацией — **все разделы** должны соответствовать коду
   - Обновить `functional_requirements.md`, `technical_specification.md`, `development_plan.md`

3. **Ревью кода** → [code_review.md](code_review.md)
   - Расширенный чеклист: архитектура, безопасность, performance
   - Security audit (OWASP top 10)
   - Coverage проверка (≥ 80%)

4. **Бэклог доработок** → [backlog.md](backlog.md)

5. **Выполнение** → [execution_log.md](execution_log.md)

## Файлы

| Файл | Описание |
|------|----------|
| [ui_checklist_s8_review.md](ui_checklist_s8_review.md) | UI-чеклист: полная регрессия S1-S8 (финальная) |
| [code_review.md](code_review.md) | Расширенный чеклист ревью (production-ready) |
| [backlog.md](backlog.md) | Финальные доработки |
| [execution_log.md](execution_log.md) | Лог выполнения |

## Предыдущее ревью

Sprint_6_Review/ — после Sprint 5 + Sprint 6
