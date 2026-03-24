---
sprint: 1
agent: DEV-5
role: Security (SEC)
wave: 3 (после мержа backend + frontend)
depends_on: [DEV-1 (FastAPI каркас), DEV-2 (модель User)]
---

# Роль

Ты — специалист по безопасности. Реализуй модуль аутентификации.

# Рабочая директория

`Test/Develop/backend/`

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы **обязательно** проверь:

```
1. Файл backend/app/main.py СУЩЕСТВУЕТ (создан DEV-1)
2. Файл backend/app/auth/models.py СУЩЕСТВУЕТ и содержит класс User (создан DEV-2)
3. Файл backend/app/config.py СУЩЕСТВУЕТ и содержит SECRET_KEY (создан DEV-1)
4. Файл backend/app/common/database.py СУЩЕСТВУЕТ (создан DEV-1/DEV-2)
5. alembic upgrade head выполняется без ошибок (миграции DEV-2)
6. pytest tests/ проходит без ошибок (тесты DEV-1 и DEV-2)
```

**Если любой из пунктов не выполнен — НЕМЕДЛЕННО ОСТАНОВИ работу** и сообщи:
"БЛОКЕР: [описание]. DEV-5 не может начать работу без результатов DEV-1/DEV-2."

# Контекст

- FastAPI каркас уже создан (DEV-1)
- Модель `User` уже существует в `app/auth/models.py` (DEV-2)
- Конфиг `app/config.py` содержит SECRET_KEY, JWT_ACCESS_TOKEN_EXPIRE_MINUTES, JWT_REFRESH_TOKEN_EXPIRE_DAYS

# Задачи

## 1. app/auth/service.py — AuthService

```python
class AuthService:
    async def register(self, username: str, password: str) -> User:
        """Регистрация. Хеширует пароль через Argon2id."""

    async def login(self, username: str, password: str) -> TokenPair:
        """
        Логин. Проверяет пароль.
        При неудаче: инкрементирует failed_login_count.
        При 5 неудачах: блокирует на 15 минут (locked_until).
        При успехе: сбрасывает failed_login_count, возвращает JWT пару.
        """

    async def refresh_token(self, refresh_token: str) -> TokenPair:
        """Обновление JWT по refresh token."""

    async def change_password(self, user_id: int, old_password: str, new_password: str) -> None:
        """Смена пароля."""

    def _hash_password(self, password: str) -> str:
        """Argon2id хеширование."""

    def _verify_password(self, password: str, hash: str) -> bool:
        """Проверка пароля."""

    def _create_token_pair(self, user_id: int) -> TokenResponse:
        """Создаёт access + refresh JWT tokens с jti для каждого."""

    async def logout(self, jti: str, user_id: int, expires_at: datetime) -> None:
        """Добавляет jti в revoked_tokens. При проверке токена — reject если jti в таблице."""
```

## 2. Хеширование паролей

- Библиотека: `argon2-cffi`
- Алгоритм: Argon2id
- Параметры: defaults из argon2-cffi (memory_cost=65536, time_cost=3, parallelism=4)

## 3. JWT Tokens

- Библиотека: `PyJWT`
- Access token: exp = 30 минут (из конфига)
- Refresh token: exp = 7 дней (из конфига)
- Payload: `{"sub": user_id, "type": "access"|"refresh", "jti": uuid4_hex, "iat": ..., "exp": ...}`
- `jti` (JWT ID) — уникальный идентификатор токена, используется для revocation через таблицу `revoked_tokens`
- Алгоритм: HS256, ключ = SECRET_KEY из конфига

## 4. app/auth/schemas.py — Pydantic schemas

```python
class RegisterRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8, max_length=128)

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # секунды до истечения access_token

class RefreshRequest(BaseModel):
    refresh_token: str

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=128)

class UserResponse(BaseModel):
    id: int
    username: str
    email: str | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
```

## 5. app/auth/router.py — Endpoints

```
POST /api/v1/auth/setup         → RegisterRequest → TokenResponse (только если users=0, иначе 403)
POST /api/v1/auth/login         → LoginRequest → TokenResponse
POST /api/v1/auth/refresh       → RefreshRequest → TokenResponse
POST /api/v1/auth/logout        → (protected) → 204 (добавляет jti в revoked_tokens)
PATCH /api/v1/auth/password     → ChangePasswordRequest (protected) → 200
GET   /api/v1/auth/me           → UserResponse (protected)
GET   /api/v1/auth/setup-status → {"is_configured": bool} (без JWT только при users=0, иначе 403)
```

## 6. app/middleware/auth.py — JWT Middleware

```python
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Декодирует JWT access token.
    Возвращает User или raises 401.
    """
```

Использовать `OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")`.

## 7. Защита от брутфорса

- После 5 неудачных попыток входа: `locked_until = utcnow + 15 минут`
- При попытке входа с `locked_until > utcnow`: возвращать **423 (Locked)** с телом `{"detail": "Аккаунт заблокирован", "retry_after": 900}` (900 секунд = 15 минут)
- При успешном входе: `failed_login_count = 0`, `locked_until = None`
- Логирование в `audit_log`: все попытки входа (успех/неудача)

## 8. First-run check

`GET /api/v1/auth/setup-status` → `{"is_configured": bool}`

Если в таблице `users` нет записей — `is_configured: false`. Frontend покажет мастер регистрации.

## 9. Тесты

Ты отвечаешь за тестирование своего кода. Модуль auth — критически важен, тесты обязательны.

### tests/unit/test_auth_service.py

```python
# Тесты AuthService:
# - test_register_creates_user_with_argon2id_hash
# - test_register_duplicate_username_raises_error
# - test_login_success_returns_token_pair
# - test_login_wrong_password_returns_error
# - test_login_wrong_username_returns_generic_error (не раскрывает что именно неверно)
# - test_login_increments_failed_count
# - test_login_locks_after_5_attempts
# - test_login_locked_user_returns_429
# - test_login_success_resets_failed_count
# - test_change_password_success
# - test_change_password_wrong_old_password
```

### tests/unit/test_auth_jwt.py

```python
# Тесты JWT:
# - test_create_token_pair_returns_access_and_refresh
# - test_access_token_expires_in_30_minutes
# - test_refresh_token_expires_in_7_days
# - test_access_token_contains_correct_payload (sub, type, jti, iat, exp)
# - test_each_token_has_unique_jti
# - test_refresh_token_generates_new_access_token
# - test_expired_access_token_is_rejected
# - test_invalid_token_is_rejected
```

### tests/unit/test_auth_router.py

```python
# Тесты API endpoints (через httpx.AsyncClient):
# - test_setup_endpoint_creates_first_user_201
# - test_setup_endpoint_returns_403_if_user_exists
# - test_login_endpoint_200_returns_expires_in
# - test_refresh_endpoint_200
# - test_logout_endpoint_204_revokes_token
# - test_logout_token_cannot_be_reused (после logout — 401)
# - test_patch_password_200
# - test_patch_password_wrong_current_returns_error
# - test_me_endpoint_requires_auth (401 без токена)
# - test_me_endpoint_returns_user (200 с валидным токеном)
# - test_setup_status_not_configured (пустая БД → is_configured: false)
# - test_setup_status_configured_returns_403 (есть пользователь → 403)
# - test_brute_force_protection_423 (6 неудачных попыток → 423 + retry_after)
```

**Запусти тесты:**
```bash
cd backend && pytest tests/unit/test_auth*.py -v
```

# Конвенции

- Все пароли хранятся ТОЛЬКО как Argon2id hash. Никогда не логировать пароли.
- JWT revocation через таблицу `revoked_tokens`: при logout/смене пароля jti добавляется в таблицу. При проверке токена — reject если jti найден в `revoked_tokens`. Ежедневная очистка истёкших записей (APScheduler).
- Все ошибки auth — generic "Неверный логин или пароль" (не раскрывать, что именно неверно).

# Критерий завершения

- Регистрация создаёт пользователя с Argon2id хешем
- Логин возвращает JWT пару
- Refresh обновляет access token
- Защищённые endpoints требуют valid JWT
- Брутфорс-защита: блокировка после 5 попыток на 15 минут
- `/api/v1/auth/setup-status` корректно определяет первый запуск
- **Все тесты проходят: `pytest tests/unit/test_auth*.py -v` — 0 failures**
- **Тесты покрывают: регистрацию, логин, JWT, брутфорс-защиту, endpoints, setup-status**
