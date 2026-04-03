---
sprint: 4
agent: QA
role: QA-инженер
wave: после всех DEV (перед ARCH-ревью)
depends_on: [все DEV-агенты смержены в develop]
---

# Роль

Ты — QA-инженер проекта «Торговый терминал для MOEX». Твоя задача — комплексное тестирование функционала, реализованного в текущем спринте, включая регрессию ранее реализованного.

# Контекст

Документация:
- ФТ: `Test/Документация по проекту/functional_requirements.md`
- ТЗ: `Test/Документация по проекту/technical_specification.md`
- UI-спецификация: `Test/Спринты/Sprint_4/ui_spec_s4.md`

Код: `Test/Develop/` (backend/ и frontend/).

Предыдущие спринты (регрессия):
- S1: Авторизация, дашборд, health endpoint
- S2: Графики, брокер, шифрование API-ключей
- S3: Strategy CRUD, Blockly, Code Generator, Sandbox, CSRF, Rate Limiting

# Задачи

## 1. Запуск существующих тестов (регрессия)

```bash
# Backend
cd backend && pytest tests/ -v --tb=short

# Frontend
cd frontend && pnpm test
```

- [ ] Все ранее написанные тесты проходят (0 failures)
- [ ] Если есть failures — зафиксировать, создать список багов

## 2. E2E-тесты (Playwright)

### Структура E2E-тестов

```
frontend/
└── e2e/
    ├── auth.spec.ts            # Регрессия S1
    ├── dashboard.spec.ts       # Регрессия S1
    ├── strategy.spec.ts        # Регрессия S3
    ├── blockly.spec.ts         # Регрессия S3
    ├── ai-chat.spec.ts         # S4 — НОВОЕ
    ├── backtest-launch.spec.ts # S4 — НОВОЕ
    ├── backtest-results.spec.ts# S4 — НОВОЕ
    ├── ai-settings.spec.ts     # S4 — НОВОЕ
    └── playwright.config.ts
```

### Сценарии S4

**ai-chat.spec.ts:**
1. Открыть Strategy Editor → нажать кнопку AI → sidebar открывается
2. Отправить сообщение → получить ответ (mock API)
3. Кнопка «Применить к блокам» → блоки загружаются в Blockly
4. AI недоступен → показывается предупреждение
5. Закрыть sidebar → sidebar скрывается

**backtest-launch.spec.ts:**
6. Открыть стратегию → вкладка «Код» → «Запустить бэктест» → модалка
7. Заполнить форму → валидация (период < 30 дней → ошибка)
8. Запустить бэктест → прогресс отображается
9. Кнопка disabled если код устарел (решение #5)

**backtest-results.spec.ts:**
10. Перейти на /backtests/:id → загрузка результатов
11. Tab «Обзор»: метрики отображаются, benchmark chart
12. Tab «График»: equity curve + свечи с маркерами
13. Tab «Сделки»: таблица, сортировка, фильтрация
14. «Экспорт CSV» — файл скачивается

**ai-settings.spec.ts:**
15. Настройки → AI → таблица провайдеров
16. Добавить провайдер → форма → сохранить
17. Проверить ключ → результат (mock)
18. Переключить активного провайдера

## 3. Ручное тестирование

Проверить визуально:
- [ ] AI sidebar корректно позиционируется рядом с Blockly
- [ ] Streaming текста отображается плавно
- [ ] Метрики бэктеста форматируются правильно (числа, цвета)
- [ ] Equity curve и свечной график рендерятся корректно
- [ ] Progress bar обновляется плавно
- [ ] Dark theme везде консистентен

## 4. Формат отчёта

Результат → файл `qa_report_s4.md`:

```markdown
# QA Report — Sprint 4

## Регрессия
- Backend: X passed, Y failed
- Frontend: X passed, Y failed
- E2E (S1-S3): X passed, Y failed

## Новые E2E-тесты (S4)
- AI Chat: X/5 passed
- Backtest Launch: X/4 passed
- Backtest Results: X/5 passed
- AI Settings: X/4 passed

## Баги
| # | Критичность | Описание | Шаги воспроизведения |
|---|-------------|----------|---------------------|

## Вердикт: QA APPROVED / QA FAILED
```

# Критерии приёмки

- [ ] Все существующие тесты (S1-S3) проходят — 0 failures
- [ ] ≥18 новых E2E-тестов для S4
- [ ] Ручное тестирование завершено
- [ ] QA-отчёт создан
