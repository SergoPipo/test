---
sprint: 4
agent: DEV-2
role: Backend (BACK2 + BACK1) — AI Chat API + SSE Streaming
wave: 2
depends_on: [DEV-1 (AI Service)]
---

# Роль

Ты — Backend-разработчик #2 (senior). Реализуй AI chat API с SSE streaming, историю чата, контекстное сжатие, интеграцию с AI Service из DEV-1.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11
2. AI Service реализован: app.ai.service.AIService работает
3. AI Providers реализованы: app.ai.providers (Claude, OpenAI, Custom)
4. Системный промпт: app.ai.prompts.MOEX_SYSTEM_PROMPT существует
5. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-2 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Задачи

## 1. AI Chat API (app/ai/chat_router.py)

### 1.1 Chat endpoint (non-streaming)

```
POST /api/v1/ai/chat
Body: {
    strategy_id: int,
    message: str,
    history?: [{role: "user"|"assistant", content: str}]
}
Response: 200 {
    response: str,
    suggested_blocks?: dict,   // JSON блочной схемы, если AI предложил
    updated_code?: str,        // Обновлённый Python код
    tokens_used: int
}
```

**Логика:**
1. Проверить budget (`AIService.check_budget`)
2. Получить active provider (`AIService.get_active_provider`)
3. Сформировать messages: system prompt + history + user message
4. Вызвать `provider.chat()`
5. Инкрементировать usage (`AIService.increment_usage`)
6. Если ответ содержит JSON блочной схемы — извлечь в `suggested_blocks`
7. Вернуть результат

### 1.2 SSE Streaming endpoint

```
POST /api/v1/ai/chat/stream
Body: { strategy_id, message, history? }
Response: SSE stream (text/event-stream)
  data: {"type": "chunk", "content": "текст..."}
  data: {"type": "chunk", "content": "продолжение..."}
  data: {"type": "done", "suggested_blocks": {...}, "tokens_used": 42}
  data: {"type": "error", "detail": "..."}
```

Используй `sse-starlette` для SSE:

```python
from sse_starlette.sse import EventSourceResponse

@router.post("/chat/stream")
async def chat_stream(request: ChatRequest, ...):
    async def event_generator():
        async for chunk in provider.stream_chat(messages, system_prompt):
            yield {"data": json.dumps({"type": "chunk", "content": chunk})}
        yield {"data": json.dumps({"type": "done", "tokens_used": total_tokens})}
    return EventSourceResponse(event_generator())
```

### 1.3 Explain endpoint

```
POST /api/v1/ai/explain
Body: { code_snippet: str }
Response: 200 { explanation: str }
```

Объясняет фрагмент Python/Backtrader кода. Использует упрощённый промпт.

## 2. История чата (app/ai/chat_history.py)

Чат-история хранится в `strategy_versions.ai_chat_history` (поле уже определено в ТЗ, тип Text — JSON):

```python
class ChatHistoryManager:
    async def get_history(self, strategy_id: int, db: AsyncSession) -> list[dict]:
        """Загрузить историю из strategy_versions.ai_chat_history."""

    async def save_message(self, strategy_id: int, role: str, content: str, db: AsyncSession) -> None:
        """Добавить сообщение в историю."""

    async def clear_history(self, strategy_id: int, db: AsyncSession) -> None:
        """Очистить историю."""
```

## 3. Контекстное сжатие (app/ai/context.py)

Из ТЗ (секция 5.10.3): при превышении 80% лимита контекстного окна:

```python
class ContextCompressor:
    MAX_CONTEXT_TOKENS = 100_000  # настраиваемое
    COMPRESSION_THRESHOLD = 0.8

    def should_compress(self, messages: list[dict]) -> bool:
        """Проверить, нужно ли сжатие."""

    async def compress(self, messages: list[dict], provider: BaseLLMProvider) -> list[dict]:
        """
        1. Суммаризировать старые сообщения в один блок
        2. Сохранить последние 3 сообщения и финальное решение
        3. Вернуть сжатый список
        """
```

## 4. Регистрация роутера

В `app/main.py` добавить:
```python
app.include_router(ai_chat_router, prefix="/api/v1/ai", tags=["ai-chat"])
```

# Тесты (tests/test_ai/test_chat.py)

Минимум **20 тестов**:

1. **Chat endpoint** (5): successful chat, budget exceeded (403), provider not configured (422), invalid strategy_id (404), with history
2. **SSE streaming** (4): stream chunks, stream error, stream with suggested_blocks, budget check before stream
3. **Explain** (2): successful explain, empty snippet
4. **ChatHistoryManager** (4): get/save/clear history, append message
5. **ContextCompressor** (3): should_compress false, should_compress true, compress output
6. **Integration** (2): chat → save history → get history, budget decrement

Для всех тестов — mock AI provider (не делать реальных запросов).

# Ветка

```
git checkout -b s4/ai-chat-api develop
```

# Критерии приёмки

- [ ] POST /ai/chat работает (non-streaming)
- [ ] POST /ai/chat/stream работает (SSE)
- [ ] POST /ai/explain работает
- [ ] Budget проверяется перед каждым запросом
- [ ] Chat history сохраняется в БД
- [ ] Контекстное сжатие при превышении 80% лимита
- [ ] suggested_blocks извлекается из ответа AI
- [ ] ≥20 тестов, 0 failures
- [ ] Регрессия: все существующие тесты проходят
