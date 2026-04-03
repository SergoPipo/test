# ARCH Review — Sprint 4

> Дата: 2026-03-31
> Ревьюер: ARCH Agent (Claude Opus 4.6)
> Ветка: develop

---

## Вердикт: APPROVED (2 MAJOR исправлены, остальные MINOR)

---

## Тесты

- Backend: 423 passed, 0 failed (по данным QA-отчёта)
- Frontend: 154 passed, 0 failed (по данным QA-отчёта)
- Новых тестов: ~125+ (unit + component тесты по всем S4-модулям)
- E2E: 18 сценариев написано (требуют Playwright)

> **Примечание:** Bash-доступ был ограничен, тесты не были запущены непосредственно в этой сессии. Результаты основаны на QA-отчёте `qa_report_s4.md`.

---

## Проверенные файлы

### Backend (15 файлов)
- `app/ai/providers/base.py` — абстрактный класс BaseLLMProvider
- `app/ai/providers/claude_provider.py` — Anthropic SDK
- `app/ai/providers/openai_provider.py` — OpenAI SDK
- `app/ai/providers/custom_provider.py` — Custom (OpenAI-compatible)
- `app/ai/providers/factory.py` — ProviderFactory
- `app/ai/service.py` — AIService (CRUD, budget, encrypt/decrypt)
- `app/ai/router.py` — AI Settings + Status API
- `app/ai/schemas.py` — Pydantic v2 schemas
- `app/ai/prompts.py` — System prompts
- `app/ai/chat_router.py` — Chat API (non-streaming + SSE)
- `app/ai/chat_schemas.py` — Chat Pydantic schemas
- `app/ai/chat_history.py` — ChatHistoryManager
- `app/ai/context.py` — ContextCompressor
- `app/backtest/engine.py` — BacktestEngine (Backtrader wrapper)
- `app/backtest/metrics.py` — Metrics calculation
- `app/backtest/equity.py` — Equity curve collection
- `app/backtest/benchmark.py` — BenchmarkCalculator
- `app/backtest/router.py` — Backtest REST API
- `app/backtest/service.py` — BacktestService
- `app/backtest/schemas.py` — Backtest Pydantic schemas
- `app/backtest/models.py` — SQLAlchemy models (backtests, backtest_trades)
- `app/backtest/ws.py` — WebSocket handler
- `app/common/event_bus.py` — EventBus (pub/sub)
- `app/common/models.py` — AIProviderConfig model
- `app/config.py` — Settings
- `app/main.py` — Application factory + middleware
- `app/sandbox/executor.py` — CodeSandbox (RestrictedPython)

### Frontend (22 файла)
- `src/components/ai/AnimatedSwitch.tsx` — CSS translateX transitions
- `src/components/ai/AIChat.tsx` — Chat UI with streaming
- `src/components/ai/ChatInput.tsx` — Input + attachments
- `src/components/ai/StrategyDescription.tsx` — Editable description + apply
- `src/components/ai/AIModePanel.tsx` — Split 40/60 panel
- `src/components/backtest/MetricsGrid.tsx` — 4x2 metrics grid
- `src/components/backtest/BenchmarkChart.tsx` — Horizontal bar chart
- `src/components/backtest/EquityCurveChart.tsx` — Lightweight Charts
- `src/components/backtest/CandlestickWithMarkers.tsx` — Candles + markers
- `src/components/backtest/BacktestTrades.tsx` — TanStack Table
- `src/components/backtest/BacktestLaunchModal.tsx` — Launch modal
- `src/components/backtest/BacktestProgress.tsx` — Progress bar + WS
- `src/pages/BacktestResultsPage.tsx` — Tabs: Обзор/График/Сделки
- `src/pages/AISettingsPage.tsx` — CRUD + verify + activate
- `src/pages/StrategyEditPage.tsx` — Updated with AI mode + backtest
- `src/stores/aiChatStore.ts` — Zustand store for AI chat
- `src/stores/backtestStore.ts` — Zustand store for backtest
- `src/services/aiStreamClient.ts` — SSE client
- `src/api/aiApi.ts` — AI API client
- `src/api/aiSettingsApi.ts` — AI Settings API client
- `src/api/backtestApi.ts` — Backtest API client

---

## Замечания

| # | Критичность | Агент | Описание | Рекомендация | Статус |
|---|-------------|-------|----------|-------------|--------|
| 1 | **MAJOR** | DEV-3 | `BacktestEngine._compile_strategy()` использовал `exec()` без AST-анализа | Добавлен вызов `ASTAnalyzer.analyze()` перед exec(). Код теперь проходит проверку безопасности | **Исправлено** |
| 2 | **MAJOR** | DEV-4 | WebSocket endpoint `/ws` не имел аутентификации | Добавлена JWT-аутентификация через query param `?token=`. Подключения без токена отклоняются (code 4001). WS тесты обновлены | **Исправлено** |
| 3 | MINOR | DEV-3 | Progress callback async/sync mismatch в ProgressAnalyzer | Добавлена корректная диспетчеризация async callback через asyncio.ensure_future / call_soon_threadsafe | **Исправлено** |
| 4 | MINOR | DEV-2 | SSE streaming без лимита одновременных соединений | Добавлен MAX_CONCURRENT_STREAMS=3 на пользователя с cleanup в finally | **Исправлено** |
| 5 | MINOR | DEV-5 | `AIChat.tsx:50` — сообщения AI рендерятся через `<Text style={{ whiteSpace: 'pre-wrap' }}>{message.content}</Text>`, что безопасно (React escapes HTML). Однако если в будущем добавят Markdown-рендеринг, потребуется sanitization | Зафиксировать в TODO: при добавлении markdown-рендеринга использовать DOMPurify | Информационно |
| 6 | MINOR | DEV-1 | Claude/OpenAI провайдеры создавали новый HTTP-клиент на каждый вызов | Клиент кеширован в self._client с lazy-инициализацией | **Исправлено** |
| 7 | MINOR | DEV-6 | `BacktestProgress.tsx` auto-navigate (строка 59): `navigate(/backtest/${backtestId})` — маршрут не совпадает с `BacktestResultsPage` который зарегистрирован на `/backtests/:id` | Исправить на `navigate(/backtests/${backtestId})` для согласованности маршрутов | **Исправлено (ARCH)** |
| 8 | MINOR | DEV-2 | `aiStreamClient.ts:87` — при SSE error event считывает `parsed.message`, но backend отправляет `parsed.detail` (chat_router.py:247) | Согласовать: либо `error.detail` на обеих сторонах, либо `error.message` | **Исправлено (ARCH)** |
| 9 | MINOR | DEV-1 | `AIService.check_budget()` (service.py:102-107) — при .env fallback `usage_today=0, usage_month=0` всегда, т.е. бюджет не отслеживается для .env-провайдеров | Допустимо на текущем этапе (MVP), но стоит зафиксировать как tech debt: добавить in-memory или DB-счётчик для .env fallback | Информационно |
| 10 | MINOR | DEV-3 | _extract_trades() возвращал пустой список — сделки не извлекались | Добавлен TradeRecorder (bt.Analyzer) с notify_trade() для per-trade записей. _extract_trades() парсит реальные данные | **Исправлено** |

---

## Архитектурный анализ

### AI Service (DEV-1) — PASS

- **BaseLLMProvider** — корректный абстрактный класс с 4 методами (chat, stream_chat, count_tokens, verify)
- **Factory pattern** — чистая реализация с валидацией типа
- **Шифрование ключей** — CryptoService (AES-256-GCM), единый механизм с брокерскими ключами
- **Маскирование** — `mask_api_key()` корректно показывает первые 4 + последние 4
- **Budget tracker** — daily + monthly лимиты, reset через scheduler
- **Fallback .env > БД** — приоритет БД, затем .env, затем ошибка. Корректно
- API-ключи **не логируются** — в structlog передаётся только `error=str(e)`, ключи не в параметрах

### AI Chat API (DEV-2) — PASS

- **SSE streaming** — EventSourceResponse с правильным форматом `data: {...}`
- **Budget проверяется ПЕРЕД запросом** — строки 127-129 в chat_router.py
- **Chat history** — сохраняется в `strategy_versions.ai_chat_history` (JSON Text)
- **Контекстное сжатие** — при 80% лимита (80K токенов), сохраняет последние 3 сообщения
- **suggested_blocks** — извлекается regex из ```json_blocks``` блока
- **Error handling** — timeout, provider error, budget exceeded — все обработаны
- **CSRF** — CSRFMiddleware в main.py покрывает POST-запросы

### Backtest Engine (DEV-3) — PASS (с замечаниями)

- **Модели** — `Numeric(18, 8)` для цен, `Numeric(18, 2)` для денег, `Numeric(10, 4)` для процентов — **соответствует конвенциям**
- **Cascade delete** — `cascade="all, delete-orphan"` + `ondelete="CASCADE"` на FK — корректно
- **Metrics** — Sharpe, Profit Factor, Win Rate, Max DD — формулы верны, используют `Decimal`
- **Equity curve** — собирается per-bar через EquityCurveObserver (bt.Analyzer)
- **Progress** — вызывается каждый 1% (step = total_bars // 100), разумная частота
- **Benchmark** — Buy & Hold и IMOEX корректно считаются через MarketDataService
- **Sandbox** — **MAJOR: exec() без sandbox** (замечание #1)

### Backtest API (DEV-4) — PASS (с замечаниями)

- **POST /backtests → 202** — асинхронный запуск через BackgroundTasks
- **Валидация** — решение #5 реализовано (code empty, outdated, syntax error)
- **Background task** — использует собственную DB-сессию, не блокирует event loop
- **WebSocket** — мультиплексированный `/ws`, формат `{channel, event, data}`
- **EventBus** — memory-safe: `maxsize=256`, cleanup в `finally` блоке ws.py
- **Пагинация trades** — offset-based с cursor (page/per_page), сортировка по whitelist столбцов
- **WebSocket auth** — **MAJOR: отсутствует** (замечание #2)

### AI Sidebar (DEV-5) — PASS

- **SSE-клиент** — `aiStreamClient.ts` с AbortSignal, ReadableStream, корректный парсинг
- **Streaming** — Loader dots перед первым чанком, текст плавно через `streamingContent`
- **«Применить к блокам»** — загружает JSON через `onApplyBlocks`, закрывает AI-режим
- **AI unavailable** — Alert с ссылкой на `/settings/ai`
- **Layout** — AnimatedSwitch с translateX, не ломает Blockly (absolute positioning)
- **Zustand store** — корректное управление: messages, streaming, providers, abort

### Backtest UI (DEV-6) — PASS (с замечаниями)

- **MetricsGrid** — 8 метрик, цвета по порогам (green/neutral/red) — соответствует спецификации
- **Equity curve** — Lightweight Charts с drawdown area, Buy & Hold и IMOEX линиями
- **Маркеры** — arrowUp/arrowDown с правильными цветами и позициями
- **TanStack Table** — сортировка, фильтр (Все/Прибыльные/Убыточные), пагинация 10/страница
- **BacktestLaunchModal** — валидация >= 30 дней, disabled + Tooltip (решение #5)
- **Progress** — WebSocket + animated Progress bar + elapsed timer + auto-navigate
- **AI Settings** — CRUD + verify + mask + activate (radio buttons)
- **Форматирование чисел** — `Intl.NumberFormat('ru-RU')` с `₽` — корректно

### Безопасность

| Проверка | Результат |
|----------|-----------|
| API-ключи не логируются | PASS — structlog не содержит ключей |
| API-ключи не в plaintext | PASS — AES-256-GCM через CryptoService |
| Маскирование в API-ответах | PASS — `mask_api_key()` в router |
| WebSocket аутентификация | **FAIL** — см. замечание #2 |
| SSE rate limiting | PARTIAL — общий лимит 10/мин для /ai/* |
| Backtest sandbox | **PARTIAL** — exec() без RestrictedPython (замечание #1) |
| XSS в chat messages | PASS — React escapes, нет dangerouslySetInnerHTML |
| CSRF на мутирующих запросах | PASS — CSRFMiddleware (double-submit cookie) |
| Нет hardcoded secrets в frontend | PASS — токены из .env / localStorage |

### Соответствие паттернам S1-S3

- **Модульная структура** — router/service/schemas/models — консистентна
- **Async** — все I/O через async/await
- **Именование** — snake_case / PascalCase — соблюдается
- **Pydantic v2** — `model_config`, `model_dump`, `ConfigDict` — корректно
- **Zustand stores** — паттерн `create<Store>()(set, get)` — консистентен
- **API client** — Axios через `apiClient` с interceptors — единообразно
- **Mantine** — dark theme, Tabler Icons — соответствует дизайн-системе

---

## Рекомендации по приоритету

### До мержа (MAJOR)

1. **Замечание #1** — Интегрировать `CodeSandbox.validate()` перед `exec()` в `BacktestEngine._compile_strategy()`. Это основной security gap — пользовательский код стратегии (пусть и сгенерированный) выполняется без AST-анализа.

2. **Замечание #2** — Добавить JWT-аутентификацию в WebSocket handshake. Минимальная реализация: query param `?token=JWT`, проверка в `websocket_endpoint` перед `accept()`.

### После мержа (MINOR / tech debt)

3. Замечание #3 — Исправить async/sync mismatch в progress callback
4. Замечание #7 — Исправить маршрут в `BacktestProgress` navigate
5. Замечание #8 — Согласовать error field name (detail vs message) в SSE
6. Замечание #10 — Реализовать custom observer для per-trade записи
7. Замечание #6 — Кеширование HTTP-клиентов провайдеров

---

## Итоги

Sprint 4 реализован качественно. Архитектура AI-модуля (провайдеры, фабрика, шифрование) и бэктестинга (Backtrader wrapper, метрики, EventBus, WebSocket) соответствует ТЗ и конвенциям проекта. Frontend-компоненты следуют UI-спецификации и дизайн-системе.

Два MAJOR-замечания требуют внимания перед мержем:
1. Sandbox bypass в BacktestEngine
2. Отсутствие аутентификации WebSocket

Остальные замечания — tech debt уровня MINOR, допустимы к исправлению в следующих спринтах.
