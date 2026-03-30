---
sprint: 3
agent: DEV-1
role: Backend Core (BACK1) — Strategy CRUD API
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #1 (senior). Реализуй модуль стратегий: модели БД, Alembic-миграция, CRUD API, версионирование стратегий.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/strategy/ существует
3. Файл backend/app/strategy/router.py существует (может содержать стаб)
4. Файл backend/app/main.py подключает strategy_router
5. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-1 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Паттерны проекта (используй как образец)

Существующие модули (`auth/`, `broker/`) задают паттерн:
- `models.py` — SQLAlchemy модели с `TimestampMixin`
- `schemas.py` — Pydantic v2 модели (BaseModel)
- `service.py` — бизнес-логика (async, принимает `AsyncSession`)
- `router.py` — FastAPI `APIRouter`, зависимости `Depends(get_db)` + `Depends(get_current_user)`

## Регистрация роутера (уже в main.py)

```python
# app/main.py — strategy_router УЖЕ подключён:
app.include_router(strategy_router, prefix="/api/v1/strategy", tags=["strategy"])
```

## Существующие исключения (app/common/exceptions.py)

```python
NotFoundError(detail, status_code=404)
ValidationError(detail, status_code=422)
AuthenticationError(detail, status_code=401)
ForbiddenError(detail, status_code=403)
```

# Задачи

## 1. Модели БД (app/strategy/models.py)

Создай две модели. **Если файл уже содержит стабы — замени их реальной реализацией.**

### Strategy

```python
class Strategy(TimestampMixin, Base):
    __tablename__ = "strategies"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="draft"
    )  # draft, tested, paper, live, paused, archived
    current_version_id: Mapped[int | None] = mapped_column(
        ForeignKey("strategy_versions.id", use_alter=True), nullable=True
    )

    # relationships
    versions: Mapped[list["StrategyVersion"]] = relationship(
        back_populates="strategy", cascade="all, delete-orphan",
        order_by="StrategyVersion.version_number"
    )
    user: Mapped["User"] = relationship(back_populates="strategies")
```

### StrategyVersion

```python
class StrategyVersion(Base):
    __tablename__ = "strategy_versions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    strategy_id: Mapped[int] = mapped_column(
        ForeignKey("strategies.id"), nullable=False, index=True
    )
    version_number: Mapped[int] = mapped_column(nullable=False)
    text_description: Mapped[str | None] = mapped_column(Text, nullable=True)
    blocks_json: Mapped[str] = mapped_column(Text, nullable=False, default="{}")
    generated_code: Mapped[str] = mapped_column(Text, nullable=False, default="")
    parameters_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # unique constraint
    __table_args__ = (
        UniqueConstraint("strategy_id", "version_number", name="uq_strategy_version"),
    )

    # relationships
    strategy: Mapped["Strategy"] = relationship(back_populates="versions")
```

**Важно:**
- `blocks_json` хранит JSON блочной схемы Blockly
- `generated_code` хранит сгенерированный Python-код
- `parameters_json` хранит параметры стратегии (stop-loss, take-profit, sizing)
- Используй `Text`, не `String` — блоки и код могут быть большими

## 2. Alembic-миграция

```bash
cd backend
alembic revision --autogenerate -m "add_strategies_and_strategy_versions"
alembic upgrade head
```

Проверь, что миграция создаёт обе таблицы и все индексы.

## 3. Pydantic-схемы (app/strategy/schemas.py)

```python
# Request schemas
class StrategyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str | None = None

class StrategyUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    status: str | None = None  # validate: draft/tested/paper/live/paused/archived

class VersionCreate(BaseModel):
    text_description: str | None = None
    blocks_json: str  # JSON string
    generated_code: str
    parameters_json: str | None = None

# Response schemas
class StrategyResponse(BaseModel):
    id: int
    name: str
    status: str
    current_version_id: int | None
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

class StrategyDetailResponse(StrategyResponse):
    versions: list["VersionResponse"]
    text_description: str | None = None  # from current version

class VersionResponse(BaseModel):
    id: int
    version_number: int
    text_description: str | None
    blocks_json: str
    generated_code: str
    parameters_json: str | None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class StrategyListResponse(BaseModel):
    strategies: list[StrategyResponse]
    total: int
```

## 4. Сервис (app/strategy/service.py)

```python
class StrategyService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, user_id: int, data: StrategyCreate) -> Strategy:
        # Создать стратегию + первую версию (v1) с пустыми блоками

    async def get_list(self, user_id: int) -> list[Strategy]:
        # Список стратегий пользователя, отсортированных по updated_at DESC

    async def get_by_id(self, user_id: int, strategy_id: int) -> Strategy:
        # Получить стратегию с versions. Проверить user_id (нельзя видеть чужие)

    async def update(self, user_id: int, strategy_id: int, data: StrategyUpdate) -> Strategy:
        # Обновить name/status. Проверить ownership.

    async def delete(self, user_id: int, strategy_id: int) -> None:
        # Удалить стратегию + каскадно все версии. Проверить ownership.

    async def create_version(self, user_id: int, strategy_id: int, data: VersionCreate) -> StrategyVersion:
        # Создать новую версию (version_number = max + 1)
        # Обновить strategy.current_version_id

    async def get_version(self, user_id: int, strategy_id: int, version_number: int) -> StrategyVersion:
        # Получить конкретную версию
```

**Правила:**
- Все методы проверяют `user_id` — нельзя получить/изменить чужую стратегию → `ForbiddenError`
- Несуществующая стратегия → `NotFoundError`
- Невалидный статус → `ValidationError`

## 5. API Endpoints (app/strategy/router.py)

```
POST   /api/v1/strategy              → create
GET    /api/v1/strategy              → list (user's strategies)
GET    /api/v1/strategy/{id}         → get detail (with versions)
PUT    /api/v1/strategy/{id}         → update
DELETE /api/v1/strategy/{id}         → delete (204)

POST   /api/v1/strategy/{id}/versions           → create version
GET    /api/v1/strategy/{id}/versions/{number}   → get version
```

Все endpoints требуют `Authorization: Bearer <token>` через `Depends(get_current_user)`.

## 6. Связь User → Strategy

Добавь relationship в модель User (если ещё нет):

```python
# app/auth/models.py (добавь, не ломая существующее)
strategies: Mapped[list["Strategy"]] = relationship(back_populates="user", cascade="all, delete-orphan")
```

## 7. Тесты (tests/unit/test_strategy/)

Создай тесты:

```
tests/unit/test_strategy/
├── __init__.py
├── test_models.py          # Strategy + StrategyVersion creation, relationships
├── test_service.py         # CRUD operations, ownership check, versioning
├── test_router.py          # API endpoints (mock service)
└── test_schemas.py         # Pydantic validation
```

**Минимальные тест-кейсы:**
- `test_create_strategy` — создание стратегии с первой версией
- `test_list_strategies` — возвращает только стратегии текущего пользователя
- `test_get_strategy_detail` — включает versions
- `test_update_strategy_name`
- `test_update_strategy_status_invalid` — невалидный статус → 422
- `test_delete_strategy` — 204, каскадное удаление версий
- `test_create_version` — version_number инкрементируется
- `test_get_version`
- `test_forbidden_access` — попытка получить чужую стратегию → 403
- `test_not_found` — несуществующий ID → 404

# Что НЕ делать

- **НЕ** реализуй Code Generator или Template Parser — это задача DEV-5
- **НЕ** реализуй эндпоинты `/generate-code` или `/parse-template` — это задача DEV-5
- **НЕ** реализуй Sandbox — это задача DEV-3
- **НЕ** реализуй CSRF/Rate Limiting — это задача DEV-4
- **НЕ** трогай frontend — это задачи DEV-2 и DEV-6

# Артефакты

По завершении:
1. `app/strategy/models.py` — модели Strategy + StrategyVersion
2. `app/strategy/schemas.py` — Pydantic-схемы
3. `app/strategy/service.py` — бизнес-логика
4. `app/strategy/router.py` — API endpoints
5. Alembic-миграция
6. `tests/unit/test_strategy/` — ≥10 тестов
7. **Все тесты проходят:** `pytest tests/ -v` → 0 failures
