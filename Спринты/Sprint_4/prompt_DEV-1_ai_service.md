---
sprint: 4
agent: DEV-1
role: Backend Core (BACK2) — AI Service
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #1 (senior). Реализуй AI Service: pluggable providers (Claude, OpenAI, Custom), шифрование API-ключей, бюджет-трекер, таблицы БД, API настроек.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/ai/ существует (или создать)
3. CryptoService уже реализован в app.broker (для шифрования ключей)
4. pytest tests/ проходит на develop (0 failures)
5. Модуль app.common.exceptions доступен
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-1 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Паттерны проекта (используй как образец)

Существующие модули (`auth/`, `broker/`, `strategy/`) задают паттерн:
- `models.py` — SQLAlchemy модели с `TimestampMixin`
- `schemas.py` — Pydantic v2 модели (BaseModel)
- `service.py` — бизнес-логика (async, принимает `AsyncSession`)
- `router.py` — FastAPI `APIRouter`, зависимости `Depends(get_db)` + `Depends(get_current_user)`

## CryptoService (уже реализован в broker/)

```python
# app/broker/crypto.py (ПРИМЕРНАЯ СТРУКТУРА — прочти реальный файл)
class CryptoService:
    def encrypt(self, plaintext: str) -> tuple[bytes, bytes]:  # (ciphertext, iv)
    def decrypt(self, ciphertext: bytes, iv: bytes) -> str:
```

Используй **тот же** CryptoService для шифрования AI API-ключей.

# Задачи

## 1. Таблица БД: ai_provider_configs (app/ai/models.py)

```python
# Таблица: ai_provider_configs
# id: Integer, PK
# user_id: Integer, FK(users.id), NOT NULL
# provider_type: String(20), NOT NULL          -- 'claude' | 'openai' | 'custom'
# display_name: String(100), NOT NULL
# model_id: String(100), NOT NULL              -- 'claude-sonnet-4-6-20250514', 'gpt-4o', etc.
# api_base_url: String(500), NULLABLE          -- только для 'custom'
# encrypted_api_key: LargeBinary, NOT NULL
# encryption_iv: LargeBinary, NOT NULL
# is_active: Boolean, DEFAULT False
# is_verified: Boolean, DEFAULT False
# daily_limit: Integer, DEFAULT 100
# monthly_limit: Integer, DEFAULT 3000
# usage_today: Integer, DEFAULT 0
# usage_month: Integer, DEFAULT 0
# last_used_at: DateTime, NULLABLE
# UNIQUE: uq_ai_user_active (user_id) WHERE is_active = True  -- только один активный
# INDEX: idx_ai_user (user_id)
```

Alembic-миграция создаёт таблицу + индексы.

## 2. Pluggable Provider Architecture (app/ai/providers/)

### 2.1 Base Provider (app/ai/providers/base.py)

```python
from abc import ABC, abstractmethod
from typing import AsyncGenerator

class BaseLLMProvider(ABC):
    @abstractmethod
    async def chat(self, messages: list[dict], system_prompt: str) -> dict:
        """Синхронный запрос. Возвращает {response: str, tokens_used: int}."""
        ...

    @abstractmethod
    async def stream_chat(self, messages: list[dict], system_prompt: str) -> AsyncGenerator[str, None]:
        """Streaming. Yield-ит текстовые чанки."""
        ...

    @abstractmethod
    def count_tokens(self, text: str) -> int:
        """Приблизительный подсчёт токенов."""
        ...

    @abstractmethod
    async def verify(self) -> dict:
        """Проверка ключа тестовым запросом. Возвращает {verified: bool, model: str, latency_ms: int}."""
        ...
```

### 2.2 Claude Provider (app/ai/providers/claude_provider.py)

- Используй `anthropic` SDK (async client)
- `chat()`: `client.messages.create()`
- `stream_chat()`: `client.messages.stream()` → yield text chunks
- `verify()`: отправь минимальный запрос ("Hello"), верни model и latency
- `count_tokens()`: приблизительно `len(text) / 4`

### 2.3 OpenAI Provider (app/ai/providers/openai_provider.py)

- Используй `openai` SDK (async client)
- `chat()`: `client.chat.completions.create()`
- `stream_chat()`: `client.chat.completions.create(stream=True)` → yield chunks
- `verify()`: аналогично Claude
- `count_tokens()`: приблизительно `len(text) / 4`

### 2.4 Custom Provider (app/ai/providers/custom_provider.py)

- OpenAI-совместимый API с кастомным `base_url`
- Для Ollama, LM Studio и подобных
- Использует `openai` SDK с `base_url` параметром

### 2.5 Provider Factory (app/ai/providers/factory.py)

```python
class ProviderFactory:
    @staticmethod
    def create(provider_type: str, api_key: str, model_id: str,
               api_base_url: str | None = None) -> BaseLLMProvider:
        ...
```

## 3. AI Service (app/ai/service.py)

```python
class AIService:
    async def get_active_provider(self, user_id: int, db: AsyncSession) -> BaseLLMProvider:
        """
        Приоритет: БД > .env
        1. ai_provider_configs WHERE user_id=X AND is_active=True
        2. Fallback: settings.AI_API_KEY
        3. Raise AIProviderNotConfiguredError
        """

    async def check_budget(self, user_id: int, db: AsyncSession) -> dict:
        """Проверить лимит. Возвращает {allowed: bool, usage_today, limit_today, usage_month, limit_month}."""

    async def increment_usage(self, user_id: int, db: AsyncSession) -> None:
        """Инкремент usage_today и usage_month."""

    async def reset_daily_usage(self, db: AsyncSession) -> None:
        """Сброс usage_today для всех. Вызывается scheduler-ом ежедневно."""

    async def reset_monthly_usage(self, db: AsyncSession) -> None:
        """Сброс usage_month для всех. 1-го числа каждого месяца."""
```

## 4. Settings API (app/ai/router.py)

Эндпоинты настроек AI-провайдеров (из ТЗ, секция 4.7 + 4.9):

```
GET    /api/v1/settings/ai/providers           — список провайдеров (ключ маскирован)
POST   /api/v1/settings/ai/providers           — добавить провайдер
PATCH  /api/v1/settings/ai/providers/{id}      — обновить
DELETE /api/v1/settings/ai/providers/{id}       — удалить
POST   /api/v1/settings/ai/providers/{id}/verify   — проверить ключ
POST   /api/v1/settings/ai/providers/{id}/activate — сделать активным
GET    /api/v1/settings/ai/usage               — статистика использования
GET    /api/v1/ai/status                       — статус AI (available, provider, usage)
```

**Маскирование ключа:** показывать первые 4 + последние 4 символа (`sk-ab...xyz1`).

## 5. Системный промпт (app/ai/prompts.py)

Вынеси системный промпт в отдельный файл. Содержание — из ТЗ (секция 5.10.2):

```python
MOEX_SYSTEM_PROMPT = """
Ты — AI-ассистент в торговом терминале для рынка MOEX...
"""
```

## 6. Конфигурация (.env fallback)

Добавь в `app/core/config.py` (Settings):
```python
AI_PROVIDER: str = "claude"
AI_API_KEY: str = ""
AI_MODEL: str = "claude-sonnet-4-6-20250514"
AI_DAILY_LIMIT: int = 100
AI_MONTHLY_LIMIT: int = 3000
```

## 7. Регистрация роутера

В `app/main.py`:
```python
app.include_router(ai_settings_router, prefix="/api/v1/settings/ai", tags=["ai-settings"])
app.include_router(ai_router, prefix="/api/v1/ai", tags=["ai"])
```

# Тесты (app/tests/test_ai/)

Минимум **25 тестов**:

1. **Модели** (5): создание ai_provider_configs, уникальность is_active, шифрование/дешифрация ключа
2. **Providers** (6): mock-тесты для Claude, OpenAI, Custom — chat(), stream_chat(), verify()
3. **AIService** (6): get_active_provider (из БД, из .env, не настроен), check_budget, increment_usage, reset
4. **Router** (8): CRUD endpoints, verify, activate, usage, status, маскирование ключа

Для тестов providers — используй mock/patch, **НЕ** делай реальных запросов к API.

# Ветка

```
git checkout -b s4/ai-service develop
```

# Критерии приёмки

- [ ] Таблица `ai_provider_configs` создаётся миграцией
- [ ] 3 провайдера: Claude, OpenAI, Custom — все реализуют BaseLLMProvider
- [ ] API-ключи шифруются через существующий CryptoService
- [ ] Budget tracker: daily + monthly лимиты
- [ ] CRUD + verify + activate API endpoints работают
- [ ] Ключ маскируется в ответах API
- [ ] .env fallback работает
- [ ] ≥25 тестов, 0 failures
- [ ] Регрессия: все существующие тесты проходят
