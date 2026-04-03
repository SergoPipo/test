---
sprint: 4
agent: ARCH
role: Технический архитектор
wave: review (после всех DEV + QA)
depends_on: [DEV-1, DEV-2, DEV-3, DEV-4, DEV-5, DEV-6, QA]
---

# Роль

Ты — технический архитектор проекта «Торговый терминал для MOEX». Проведи code review результатов Спринта 4.

# Контекст

Документация проекта:
- ТЗ: `Test/Документация по проекту/technical_specification.md`
- ФТ: `Test/Документация по проекту/functional_requirements.md`
- UI-спецификация S4: `Test/Спринты/Sprint_4/ui_spec_s4.md`
- QA-отчёт: `Test/Спринты/Sprint_4/qa_report_s4.md` (если создан)

Код находится в `Test/Develop/` (backend/ и frontend/).

# Контекст принятых решений

Ключевые архитектурные и дизайн-решения, принятые в ходе спринта.
Если при ревью возникает вопрос «почему сделано так?» — сначала свериться с этим списком.

## Решения из project_state

- **Решение #5:** Бэктест нельзя запустить если: код устарел (блоки ≠ код) ИЛИ код содержит ошибки. Кнопка «Запустить бэктест» disabled + tooltip с причиной.

## AI Service: двойной источник конфигурации

- Приоритет: БД > .env. Если в БД есть активный провайдер — используется он. Fallback на .env.
- **Причина:** пользователь настраивает через UI, .env — для автоматизированных сценариев.

## AI API-ключи: шифрование в БД

- Используется тот же CryptoService (AES-256-GCM), что для брокерских ключей.
- **Причина:** единый механизм шифрования, проверен в S2.

## Backtest Engine: Sandbox execution

- Стратегия выполняется через SandboxExecutor (AST + RestrictedPython + subprocess).
- **Причина:** безопасность — пользовательский код не должен иметь полный доступ к системе.

# Что проверить

## 1. AI Service (DEV-1)

- [ ] `BaseLLMProvider` — абстрактный класс с правильным интерфейсом
- [ ] `ClaudeProvider` — использует `anthropic` SDK корректно
- [ ] `OpenAIProvider` — использует `openai` SDK корректно
- [ ] `CustomProvider` — корректно передаёт `base_url`
- [ ] API-ключи шифруются через CryptoService (не хранятся в plaintext)
- [ ] Маскирование ключа в API-ответах (первые 4 + последние 4)
- [ ] Budget tracker: daily + monthly limits работают, reset корректен
- [ ] Fallback .env → БД работает в правильном приоритете
- [ ] Миграция: таблица `ai_provider_configs` создаётся корректно
- [ ] Тесты: mock API, нет реальных запросов к LLM

## 2. AI Chat API (DEV-2)

- [ ] SSE streaming: правильный формат `text/event-stream`
- [ ] SSE: корректная обработка abort/disconnect клиента
- [ ] Budget проверяется ПЕРЕД запросом к AI (не после)
- [ ] Chat history сохраняется в `strategy_versions.ai_chat_history`
- [ ] Контекстное сжатие: логика корректна, не теряет критичную информацию
- [ ] `suggested_blocks` корректно извлекается из ответа AI
- [ ] Error handling: timeout, provider error, budget exceeded
- [ ] CSRF-токен учитывается для POST-запросов

## 3. Backtest Engine (DEV-3)

- [ ] Модели `backtests` и `backtest_trades` соответствуют ТЗ (секции 3.6-3.7)
- [ ] Типы полей: Numeric, не Float для финансовых данных
- [ ] BacktestEngine использует SandboxExecutor (не прямой exec)
- [ ] Метрики рассчитываются корректно (формулы для Sharpe, Profit Factor, etc.)
- [ ] Equity curve собирается на каждом баре
- [ ] Progress callback: частота вызовов разумная (не каждый бар при 600K баров)
- [ ] Benchmark: Buy & Hold и IMOEX корректно считаются
- [ ] Error handling: timeout sandbox, bad strategy code, no data
- [ ] Каскадное удаление: DELETE backtest → CASCADE backtest_trades

## 4. Backtest API (DEV-4)

- [ ] POST /backtests → 202 (async, background task)
- [ ] Валидация перед запуском: решение #5 реализовано корректно
- [ ] Background task: не блокирует event loop
- [ ] WebSocket: мультиплексированный, один endpoint /ws
- [ ] WebSocket: формат сообщений соответствует ТЗ (секция 4.12)
- [ ] EventBus: memory-safe (нет утечек при disconnect)
- [ ] Пагинация trades: cursor-based или offset-based, корректная
- [ ] CSRF учитывается для POST/DELETE

## 5. AI Sidebar (DEV-5)

- [ ] SSE-клиент: корректная обработка stream, abort, reconnect
- [ ] Streaming: текст появляется плавно, нет мерцания
- [ ] «Применить к блокам»: загружает JSON в Blockly workspace
- [ ] AI unavailable: предупреждение + ссылка на настройки
- [ ] Sidebar не ломает layout Blockly workspace
- [ ] Zustand store: корректное управление состоянием

## 6. Backtest UI (DEV-6)

- [ ] MetricsGrid: все 8 метрик, правильные цвета (green/red)
- [ ] Equity curve: корректный рендеринг Lightweight Charts
- [ ] Маркеры входа/выхода на свечном графике
- [ ] TanStack Table: сортировка, фильтрация, пагинация работают
- [ ] BacktestLaunchModal: валидация, disabled state
- [ ] WebSocket progress: плавное обновление, auto-navigate
- [ ] AI Settings: CRUD, verify, маскирование ключа
- [ ] Форматирование чисел: `1 234 567,89 ₽`

## 7. Безопасность

- [ ] AI API-ключи не логируются, не отправляются в plaintext
- [ ] WebSocket: аутентификация (JWT или session)
- [ ] SSE: rate limiting (не позволять DDoS через streaming)
- [ ] Backtest: sandbox ограничивает CPU/RAM
- [ ] No XSS в chat messages (AI может вернуть HTML)
- [ ] CSRF-токены на всех мутирующих запросах

## 8. Общее

- [ ] **Запустить ВСЕ тесты:**
  ```bash
  cd backend && pytest tests/ -v --tb=short
  cd frontend && pnpm test
  ```
- [ ] 0 failures (backend + frontend)
- [ ] Новые тесты: ≥125 новых (25+20+25+20+15+20)
- [ ] Alembic миграции: up + down работают
- [ ] Нет TODO/FIXME без номера задачи

# Формат отчёта

Результат → файл `arch_review_s4.md`:

```markdown
# ARCH Review — Sprint 4

## Вердикт: APPROVED / APPROVED WITH MINOR / CHANGES REQUESTED

## Тесты
- Backend: X passed, Y failed
- Frontend: X passed, Y failed
- Новых тестов: N

## Замечания

| # | Критичность | Агент | Описание | Рекомендация |
|---|-------------|-------|----------|-------------|
```

Критичность: CRITICAL (блокер), MAJOR (исправить до мержа), MINOR (tech debt).
