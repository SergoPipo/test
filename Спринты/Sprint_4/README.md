# Спринт 4: AI-интеграция + Бэктестинг (недели 7-8)

## Цель

AI-ассистент (pluggable providers, SSE streaming, sidebar chat), движок бэктестинга (Backtrader wrapper, метрики, equity curve), отображение результатов (3 вкладки), прогресс через WebSocket.

## Критерии завершения

- [ ] AI Service: pluggable providers (Claude, OpenAI, Custom), хранение ключей (AES-256-GCM)
- [ ] AI chat API + SSE streaming, бюджет (daily/monthly limits)
- [ ] Backtest Engine: Backtrader wrapper, метрики, equity curve, benchmark
- [ ] Backtest API: запуск, статус, результаты, прогресс через WebSocket
- [ ] Frontend: AI sidebar chat в Strategy Editor
- [ ] Frontend: Backtest Results (3 вкладки: обзор, график, сделки)
- [ ] Frontend: форма запуска бэктеста + настройки AI-провайдеров
- [ ] E2E-тесты: полный цикл бэктеста, AI chat (mock), результаты
- [ ] **Все backend-тесты проходят (`pytest tests/ -v` — 0 failures)**
- [ ] **Все frontend-тесты проходят (`pnpm test` — 0 failures)**

## Подход к тестированию

| Агент | Что тестирует |
|-------|--------------|
| DEV-1 | AI Service: providers, encryption, budget tracker (mock LLM) |
| DEV-2 | AI chat API: SSE streaming, history, context compression |
| DEV-3 | Backtest Engine: Backtrader wrapper, метрики, equity curve |
| DEV-4 | Backtest API: endpoints, WebSocket progress, validation |
| DEV-5 | Frontend: AI sidebar chat, SSE client, message rendering |
| DEV-6 | Frontend: Backtest Results, форма запуска, AI settings |
| **QA** | **E2E (Playwright) + ручное тестирование + регрессия S1-S3** |
| **ARCH** | **Запуск ВСЕХ тестов, coverage, интеграция, безопасность** |

## Порядок выполнения

**[execution_order.md](execution_order.md)** — полная схема: кто, когда, от чего зависит, какой промпт, какие артефакты. Начните с этого файла.

## Предполётная проверка

**Перед стартом выполняется [preflight_checklist.md](preflight_checklist.md)** — автоматическая проверка:
- Sprint 3 завершён, 320+ тестов проходят
- Зависимости S4 устанавливаются (backtrader, anthropic, openai)
- Все промпты на месте
- Зависимости между волнами

Спринт **НЕ НАЧИНАЕТСЯ**, пока preflight не пройден.

## Волны

### Фаза UX (foreground, диалог с заказчиком)
- Дашборд результатов бэктеста (3 вкладки: обзор, график, сделки)
- AI sidebar chat в Strategy Editor
- Форма запуска бэктеста
- Настройки AI-провайдеров

### Волна 1 (параллельно с UX)
| Агент | Файл промпта | Задачи |
|-------|-------------|--------|
| DEV-1 | prompt_DEV-1_ai_service.md | AI Service: providers, encryption, budget + **тесты** |
| DEV-3 | prompt_DEV-3_backtest_engine.md | Backtest Engine: Backtrader wrapper + **тесты** |

### Волна 2 (после мержа волны 1 + утверждения UX)
| Агент | Файл промпта | Задачи |
|-------|-------------|--------|
| DEV-2 | prompt_DEV-2_ai_chat_api.md | AI chat API + SSE streaming + **тесты** |
| DEV-4 | prompt_DEV-4_backtest_api.md | Backtest API + WebSocket progress + **тесты** |
| DEV-5 | prompt_DEV-5_ai_sidebar.md | Frontend: AI sidebar chat + **тесты** |
| DEV-6 | prompt_DEV-6_backtest_ui.md | Frontend: Backtest Results + форма + AI settings + **тесты** |

### Ревью (финальная проверка)
| Агент | Файл промпта |
|-------|-------------|
| QA | prompt_QA.md — E2E (Playwright) + ручное тестирование + регрессия |
| ARCH | prompt_ARCH_review.md — запуск тестов, интеграция, безопасность |

## Зависимости от предыдущих спринтов

- Sprint 1 + Sprint 2 + Sprint 3 полностью завершены (320+ тестов)
- Strategy CRUD API, Blockly, Code Generator, Sandbox — всё на месте
- Auth, DB, layout, CI/CD, Broker, Charts, CSRF, Rate Limiting — всё работает

## Состояние спринта (при прерывании)

**[sprint_state.md](sprint_state.md)** — живой файл, обновляется после каждого шага. Если сессия прервалась — новая сессия читает только его, чтобы продолжить работу.

## Результаты (артефакты спринта)

- `ui_spec_s4.md` — утверждённая UI-спецификация S4 (создаётся после UX-фазы)
- `sprint_report.md` — итоговый отчёт (шаблон: `sprint_report_template.md`)
- `sprint_state.md` — финальное состояние (все шаги done)
