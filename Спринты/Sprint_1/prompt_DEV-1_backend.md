---
sprint: 1
agent: DEV-1
role: Backend Core (BACK1)
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #1 (senior). Инициализируй каркас FastAPI-приложения.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы **обязательно** проверь:

```
1. Python >= 3.11 установлен (python3 --version)
2. pip доступен (python3 -m pip --version)
3. Директория backend/app/ существует
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-1 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Задачи

## 1. Структура проекта

Создай следующую структуру:

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                  # FastAPI application factory
│   ├── config.py                # Pydantic Settings
│   ├── dependencies.py          # FastAPI dependency injection
│   ├── middleware/
│   │   ├── __init__.py
│   │   └── auth.py              # JWT verification (заглушка)
│   ├── auth/
│   │   ├── __init__.py
│   │   ├── router.py            # Заглушки endpoints
│   │   ├── service.py
│   │   ├── schemas.py
│   │   └── models.py
│   ├── strategy/
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   ├── schemas.py
│   │   └── models.py
│   ├── backtest/
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   ├── schemas.py
│   │   └── models.py
│   ├── trading/
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   ├── schemas.py
│   │   └── models.py
│   ├── broker/
│   │   ├── __init__.py
│   │   ├── base.py              # Абстрактный BrokerAdapter
│   │   └── factory.py
│   ├── market_data/
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   ├── schemas.py
│   │   └── models.py
│   ├── notification/
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   ├── schemas.py
│   │   └── models.py
│   ├── ai/
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   └── schemas.py
│   ├── circuit_breaker/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   └── service.py
│   ├── corporate_actions/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   └── service.py
│   ├── scheduler/
│   │   ├── __init__.py
│   │   └── service.py
│   ├── sandbox/
│   │   ├── __init__.py
│   │   └── executor.py
│   └── common/
│       ├── __init__.py
│       ├── database.py          # SQLAlchemy async engine + session
│       ├── models.py            # AuditLog, PendingEvent, ChartDrawing, PriceAlert, AIProviderConfig
│       ├── exceptions.py        # Кастомные исключения
│       ├── pagination.py        # Утилиты пагинации
│       └── crypto.py            # AES-256-GCM helpers (заглушка)
├── pyproject.toml
└── scripts/
    └── start_backend.sh
```

## 2. main.py — Application Factory

```python
# Создай FastAPI app с:
# - title="MOEX Trading Terminal"
# - version="0.1.0"
# - Подключение всех роутеров с prefix="/api/v1/{module}"
# - Lifespan: инициализация БД, закрытие сессий
# - CORS middleware (allow_origins=["http://localhost:5173"])
```

## 3. config.py — Pydantic Settings

```python
# Настройки из .env:
# DATABASE_URL: str = "sqlite+aiosqlite:///./data/terminal.db"
# SECRET_KEY: str (для JWT)
# JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
# JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7
# ENCRYPTION_KEY: str (для AES-256-GCM)
# AI_PROVIDER: str = "claude"
# AI_API_KEY: str = ""
# TELEGRAM_BOT_TOKEN: str = ""
# MOEX_ISS_BASE_URL: str = "https://iss.moex.com"
# DEBUG: bool = False
```

## 4. common/database.py

- Async SQLAlchemy engine (aiosqlite)
- AsyncSessionLocal
- Base = declarative_base()
- get_db() — async generator для FastAPI Depends
- WAL-режим для SQLite

## 5. Health endpoint

`GET /api/v1/health` → `{"status": "ok", "version": "0.1.0", "database": "connected"}`

Проверяет подключение к БД (SELECT 1).

## 6. common/exceptions.py

Кастомные исключения + exception handlers для FastAPI:
- `NotFoundError` → 404
- `ValidationError` → 422
- `AuthenticationError` → 401
- `ForbiddenError` → 403
- `BrokerError` → 502

## 7. pyproject.toml

```toml
[project]
name = "moex-terminal-backend"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.110",
    "uvicorn[standard]>=0.29",
    "sqlalchemy[asyncio]>=2.0",
    "aiosqlite>=0.20",
    "alembic>=1.13",
    "pydantic>=2.6",
    "pydantic-settings>=2.2",
    "pyjwt>=2.8",
    "argon2-cffi>=23.1",
    "cryptography>=42.0",
    "structlog>=24.1",
    "httpx>=0.27",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "pytest-cov>=5.0",
    "ruff>=0.3",
    "mypy>=1.9",
    "httpx>=0.27",
]
```

## 8. Тесты

Ты отвечаешь за тестирование своего кода. Создай тесты в `tests/unit/test_health.py` и `tests/unit/test_config.py`.

### tests/conftest.py

```python
# Общие фикстуры:
# - async_client: httpx.AsyncClient с TestClient для FastAPI
# - test_db: in-memory SQLite для тестов (sqlite+aiosqlite:///:memory:)
# Используй pytest-asyncio
```

### tests/unit/test_health.py

```python
# Тесты:
# - test_health_endpoint_returns_200
# - test_health_response_contains_status_ok
# - test_health_response_contains_version
# - test_health_response_contains_database_status
```

### tests/unit/test_config.py

```python
# Тесты:
# - test_default_config_values (DATABASE_URL, JWT_ACCESS_TOKEN_EXPIRE_MINUTES, etc.)
# - test_config_reads_from_env (используй monkeypatch)
```

### tests/unit/test_exceptions.py

```python
# Тесты:
# - test_not_found_error_returns_404
# - test_authentication_error_returns_401
# - test_forbidden_error_returns_403
# - test_broker_error_returns_502
```

**Запусти тесты и убедись, что все проходят:**
```bash
cd backend && pip install -e .[dev] && pytest tests/ -v
```

# Конвенции

- Все I/O — async/await
- Именование: snake_case функции, PascalCase классы
- Каждый роутер: `APIRouter(prefix="/api/v1/{module}", tags=["{module}"])`
- Структурированное логирование через structlog
- Все модули содержат `__init__.py` с `__all__`

# Критерий завершения

- `uvicorn app.main:app` запускается без ошибок
- `GET /api/v1/health` возвращает 200
- Все модули имеют заглушки router/service/schemas
- pyproject.toml содержит все зависимости
- **Все тесты проходят: `pytest tests/ -v` — 0 failures**
- **Тесты покрывают: health endpoint, config, exceptions**
