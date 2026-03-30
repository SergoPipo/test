---
sprint: 3
agent: DEV-4
role: Security (SEC) — CSRF Protection + Rate Limiting
wave: 1
depends_on: []
---

# Роль

Ты — специалист по безопасности. Реализуй CSRF-защиту и Rate Limiting для всего API.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/middleware/ существует
3. Файл backend/app/main.py доступен для редактирования
4. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-4 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## main.py — текущие middleware

```python
# CORS уже настроен:
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins_list, ...)

# Exception handlers:
register_exception_handlers(app)
```

## Auth middleware (app/middleware/auth.py)

```python
async def get_current_user(request: Request, db: AsyncSession = Depends(get_db)) -> User:
    # Извлекает JWT из Authorization header, валидирует, возвращает User
```

## Frontend API client (frontend/src/api/client.ts)

```typescript
// Axios instance с JWT interceptor
const apiClient = axios.create({ baseURL: import.meta.env.VITE_API_BASE_URL || '/api/v1' });
apiClient.interceptors.request.use(config => {
  const token = useAuthStore.getState().token;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
```

# Задачи

## Часть 1: CSRF Protection

### 1.1 CSRF Middleware (app/middleware/csrf.py)

Реализуй double-submit cookie pattern:
- При **логине** бэкенд устанавливает cookie `csrf_token` (SameSite=Strict, HttpOnly=False — чтобы JS мог читать)
- Frontend читает cookie и отправляет его же в заголовке `X-CSRF-Token` при мутирующих запросах
- Бэкенд сравнивает cookie и header — если не совпадают → 403

```python
import secrets
from starlette.middleware.base import BaseHTTPMiddleware

class CSRFMiddleware(BaseHTTPMiddleware):
    SAFE_METHODS = {'GET', 'HEAD', 'OPTIONS'}
    EXEMPT_PATHS = {'/api/v1/auth/login', '/api/v1/auth/setup', '/api/v1/health'}

    async def dispatch(self, request: Request, call_next):
        # Пропустить safe methods
        if request.method in self.SAFE_METHODS:
            return await call_next(request)

        # Пропустить exempt paths
        if request.url.path in self.EXEMPT_PATHS:
            return await call_next(request)

        # Извлечь токен из cookie
        cookie_token = request.cookies.get('csrf_token')
        # Извлечь токен из header
        header_token = request.headers.get('X-CSRF-Token')

        # Валидация
        if not cookie_token or not header_token:
            raise ForbiddenError("CSRF token отсутствует")
        if not secrets.compare_digest(cookie_token, header_token):
            raise ForbiddenError("CSRF token невалиден")

        return await call_next(request)
```

### 1.2 Генерация CSRF-токена при логине

В `app/auth/router.py` (endpoint `/login`) добавь установку cookie после успешного логина:

```python
@router.post("/login")
async def login(...):
    # ... существующая логика ...

    # Генерация CSRF-токена
    csrf_token = secrets.token_urlsafe(32)

    response = JSONResponse(content=token_response.model_dump())
    response.set_cookie(
        key="csrf_token",
        value=csrf_token,
        httponly=False,      # JS должен читать
        samesite="strict",
        secure=False,        # localhost; в production → True
        max_age=3600 * 24,   # 24 часа
        path="/api",
    )
    return response
```

### 1.3 Frontend: отправка CSRF-токена

Обнови `frontend/src/api/client.ts` — добавь interceptor для CSRF:

```typescript
// Читаем CSRF-токен из cookie
function getCSRFToken(): string | null {
  const match = document.cookie.match(/csrf_token=([^;]+)/);
  return match ? match[1] : null;
}

apiClient.interceptors.request.use(config => {
  // ... существующий JWT interceptor ...

  // CSRF token для мутирующих запросов
  if (config.method && !['get', 'head', 'options'].includes(config.method.toLowerCase())) {
    const csrfToken = getCSRFToken();
    if (csrfToken) {
      config.headers['X-CSRF-Token'] = csrfToken;
    }
  }

  return config;
});
```

### 1.4 Регистрация CSRF middleware

В `app/main.py`:

```python
from app.middleware.csrf import CSRFMiddleware

# Добавить ПОСЛЕ CORS middleware:
app.add_middleware(CSRFMiddleware)
```

---

## Часть 2: Rate Limiting

### 2.1 Rate Limiter (app/middleware/rate_limit.py)

In-memory sliding window.

```python
import time
from collections import defaultdict
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

class RateLimitMiddleware(BaseHTTPMiddleware):
    """Sliding window rate limiter."""

    # (max_requests, window_seconds)
    LIMITS = {
        'auth': (5, 60),        # 5 req/min для логина
        'trading': (10, 60),    # 10 req/min для торговых операций
        'ai': (10, 60),        # 10 req/min для AI
        'general': (100, 60),   # 100 req/min для всего остального
    }

    CATEGORY_PATHS = {
        '/api/v1/auth/login': 'auth',
        '/api/v1/auth/setup': 'auth',
        '/api/v1/trading': 'trading',     # prefix match
        '/api/v1/ai': 'ai',              # prefix match
    }

    def __init__(self, app):
        super().__init__(app)
        # { (user_id_or_ip, category): [timestamp, ...] }
        self._requests: dict[tuple[str, str], list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        # Определить категорию
        category = self._get_category(request.url.path)
        max_requests, window = self.LIMITS[category]

        # Определить ключ (user_id если авторизован, иначе IP)
        key = self._get_key(request, category)

        # Sliding window
        now = time.time()
        window_start = now - window
        timestamps = self._requests[(key, category)]

        # Очистить старые записи
        timestamps[:] = [t for t in timestamps if t > window_start]

        # Проверить лимит
        if len(timestamps) >= max_requests:
            retry_after = int(timestamps[0] - window_start) + 1
            return JSONResponse(
                status_code=429,
                content={"detail": "Превышен лимит запросов. Попробуйте позже."},
                headers={"Retry-After": str(retry_after)},
            )

        # Записать запрос
        timestamps.append(now)

        return await call_next(request)

    def _get_category(self, path: str) -> str:
        """Определяет категорию по пути."""
        # Exact match
        if path in self.CATEGORY_PATHS:
            return self.CATEGORY_PATHS[path]
        # Prefix match
        for prefix, cat in self.CATEGORY_PATHS.items():
            if path.startswith(prefix):
                return cat
        return 'general'

    def _get_key(self, request: Request, category: str) -> str:
        """Ключ: IP для auth, user_id для остального."""
        if category == 'auth':
            return request.client.host if request.client else 'unknown'
        # Для авторизованных — user_id из JWT (если есть)
        auth_header = request.headers.get('authorization', '')
        if auth_header.startswith('Bearer '):
            try:
                from app.auth.jwt import decode_token
                payload = decode_token(auth_header.split(' ')[1])
                return str(payload.get('sub', 'unknown'))
            except Exception:
                pass
        return request.client.host if request.client else 'unknown'
```

### 2.2 Регистрация Rate Limit middleware

В `app/main.py`:

```python
from app.middleware.rate_limit import RateLimitMiddleware

# Добавить ПЕРЕД CSRF middleware (rate limit проверяется первым):
app.add_middleware(RateLimitMiddleware)
```

**Порядок middleware (снизу вверх в Starlette = сверху вниз в обработке):**
1. RateLimitMiddleware — первый, отсекает спам
2. CSRFMiddleware — второй, проверяет токен
3. CORSMiddleware — третий, добавляет CORS-заголовки

---

## 3. Тесты

```
tests/unit/test_middleware/
├── __init__.py
├── test_csrf.py
└── test_rate_limit.py
```

### test_csrf.py
- `test_get_request_passes_without_csrf` — GET-запросы не требуют CSRF
- `test_post_without_csrf_rejected` — POST без CSRF → 403
- `test_post_with_valid_csrf_passes` — POST с корректным CSRF → OK
- `test_post_with_mismatched_csrf_rejected` — cookie и header не совпадают → 403
- `test_login_exempt_from_csrf` — POST /auth/login не требует CSRF
- `test_setup_exempt_from_csrf` — POST /auth/setup не требует CSRF
- `test_health_exempt_from_csrf` — GET /health не требует CSRF
- `test_csrf_cookie_set_on_login` — после логина cookie csrf_token установлен

### test_rate_limit.py
- `test_under_limit_passes` — 1 запрос → OK
- `test_general_limit_exceeded` — 101 запросов за минуту → 429
- `test_auth_limit_exceeded` — 6 запросов к /auth/login → 429
- `test_retry_after_header` — ответ 429 содержит Retry-After header
- `test_different_users_separate_limits` — разные пользователи имеют независимые лимиты
- `test_window_slides` — после истечения окна запросы снова проходят

# Что НЕ делать

- **НЕ** реализуй Sandbox — это задача DEV-3
- **НЕ** реализуй Strategy API — это задача DEV-1
- **НЕ** трогай Blockly или frontend страницы — это задачи DEV-2 и DEV-6
- **НЕ** ломай существующие тесты — middleware не должен сломать auth, broker, market_data

# Артефакты

По завершении:
1. `app/middleware/csrf.py` — CSRF middleware
2. `app/middleware/rate_limit.py` — Rate Limiting middleware
3. Обновлён `app/auth/router.py` — CSRF cookie при логине
4. Обновлён `frontend/src/api/client.ts` — CSRF interceptor
5. Обновлён `app/main.py` — подключены оба middleware
6. `tests/unit/test_middleware/` — ≥14 тестов
7. **Все тесты проходят:** `pytest tests/ -v` → 0 failures
