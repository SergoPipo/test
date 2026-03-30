# Спринт 3: Стратегии + Блочный редактор + Защита API (недели 5-6)

## Цель

Создание стратегий через блочный редактор (Blockly) или текстовый шаблон, генерация Python-кода для Backtrader, защита API (CSRF + Rate Limiting), песочница для безопасного выполнения кода.

## Критерии завершения

- [ ] Strategy CRUD API: создание, чтение, редактирование, удаление стратегий
- [ ] Blockly-редактор: кастомные блоки (индикаторы, условия, сигналы, фильтры)
- [ ] Code Generator: блочная схема → Python/Backtrader код
- [ ] Template Parser (режим B): текстовый шаблон → блочная схема
- [ ] Code Sandbox: AST-анализ + RestrictedPython блокирует вредоносный код
- [ ] CSRF protection: токены обязательны для мутирующих запросов
- [ ] Rate Limiting: 100 req/min general, 10 req/min trading, 5 req/min auth
- [ ] Strategy Editor UI: 3 вкладки (Description, Blockly, Code)
- [ ] Mode B: модальное окно «Скопировать шаблон»
- [ ] E2E-тесты (Playwright): стратегии, Blockly, mode B
- [ ] **Все backend-тесты проходят (`pytest tests/ -v` — 0 failures)**
- [ ] **Все frontend-тесты проходят (`pnpm test` — 0 failures)**

## Подход к тестированию (S3+)

Начиная со спринта 3, к unit-тестам добавляются **E2E-тесты (Playwright)**:
- Каждый DEV-агент пишет unit-тесты для своего кода
- QA-агент пишет E2E-тесты и проводит ручное тестирование
- ARCH при ревью **запускает все тесты** и проверяет качество

| Агент | Что тестирует |
|-------|--------------|
| DEV-1 | Strategy CRUD, models, router (mock DB) |
| DEV-2 | Blockly блоки: рендер, toolbox, drag&drop |
| DEV-3 | Sandbox: AST-анализ, блокировка запрещённых конструкций |
| DEV-4 | CSRF: validation/rejection; Rate Limiting: 429 + Retry-After |
| DEV-5 | Code Generator: blocks→code; Template Parser: text→blocks |
| DEV-6 | Strategy Editor: tabs, navigation, store |
| **QA** | **E2E (Playwright) + ручное тестирование + регрессия S1-S2** |
| **ARCH** | **Запуск ВСЕХ тестов, coverage, интеграция, безопасность** |

## Порядок выполнения

**[execution_order.md](execution_order.md)** — полная схема: кто, когда, от чего зависит, какой промпт, какие артефакты. Начните с этого файла.

## Предполётная проверка

**Перед стартом выполняется [preflight_checklist.md](preflight_checklist.md)** — автоматическая проверка:
- Sprint 2 завершён, 139+ тестов проходят
- Зависимости S3 устанавливаются (blockly, restrictedpython)
- Все промпты на месте (14 файлов)
- Зависимости между волнами

Спринт **НЕ НАЧИНАЕТСЯ**, пока preflight не пройден.

## Волны

### Фаза UX (foreground, диалог с заказчиком)
- Strategy Editor: 3 вкладки (Description, Blockly, Code)
- Blockly workspace: палитра блоков, drag&drop
- Mode B: модальное окно вставки шаблона
- Список стратегий на дашборде

### Волна 1 (параллельно с UX)
| Агент | Файл промпта | Задачи |
|-------|-------------|--------|
| DEV-1 | prompt_DEV-1_strategy_api.md | Strategy CRUD API + models + migration + **тесты** |
| DEV-2 | prompt_DEV-2_blockly_blocks.md | Blockly кастомные блоки + **тесты** |
| DEV-3 | prompt_DEV-3_sandbox.md | Code Sandbox (AST + RestrictedPython) + **тесты** |
| DEV-4 | prompt_DEV-4_csrf_ratelimit.md | CSRF middleware + Rate Limiting + **тесты** |

### Волна 2 (после мержа волны 1 + утверждения UX)
| Агент | Файл промпта | Задачи |
|-------|-------------|--------|
| DEV-5 | prompt_DEV-5_codegen.md | Code Generator + Template Parser + **тесты** |
| DEV-6 | prompt_DEV-6_strategy_editor.md | Strategy Editor page + Mode B modal + **тесты** |

### Ревью (финальная проверка)
| Агент | Файл промпта |
|-------|-------------|
| QA | prompt_QA.md — E2E (Playwright) + ручное тестирование + регрессия |
| ARCH | prompt_ARCH_review.md — **включает запуск тестов и отчёт** |

## Зависимости от предыдущих спринтов

- Sprint 1 + Sprint 2 полностью завершены (139+ тестов)
- Sprint_2_Review завершён (18/18 задач, 17 багфиксов)
- Auth, DB-модели, layout, CI/CD, Broker, Charts — всё на месте

## Состояние спринта (при прерывании)

**[sprint_state.md](sprint_state.md)** — живой файл, обновляется после каждого шага. Если сессия прервалась — новая сессия читает только его, чтобы продолжить работу.

## Результаты (артефакты спринта)

- `ui_spec_s3.md` — утверждённая UI-спецификация S3 (создаётся после UX-фазы)
- `sprint_report.md` — итоговый отчёт (шаблон: `sprint_report_template.md`)
- `sprint_state.md` — финальное состояние (все шаги done)
