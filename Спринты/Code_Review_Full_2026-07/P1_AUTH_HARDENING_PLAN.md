# Auth-hardening (Model A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести оба JWT-токена в HttpOnly-cookie (JS их не видит), устранить принудительный разлогин при двух вкладках через единый cross-tab single-flight refresh, и аутентифицировать WebSocket по cookie на upgrade.

**Architecture:** Backend перестаёт отдавать токены в теле — ставит `access_token`/`refresh_token`/`csrf_token` cookie; `get_current_user` читает access из cookie ∨ Bearer (аддитивно); `/auth/refresh` читает refresh из cookie + требует CSRF; все 3 WS-эндпоинта аутентифицируются по cookie на upgrade и шлют `auth_ok` первым кадром. Frontend хранит только `{user}` (не токены), делает единый single-flight refresh на `navigator.locks`, WS открывает без токена, бутстрапится через `/auth/me`. Grace-окно НЕ вводим — cross-tab lock + браузер-wide ротация cookie закрывают гонку.

**Tech Stack:** FastAPI, SQLAlchemy async, PyJWT, Starlette middleware; React + TypeScript, Zustand, Axios, Vitest, Playwright.

**Спека:** `Спринты/Code_Review_Full_2026-07/P1_AUTH_HARDENING_DESIGN.md` (§-ссылки ниже — на неё).

## Global Constraints

- **База ветки:** `p1/wave3-frontend @ 0e039be`. Рабочая ветка волны: `p1/auth-hardening`. Remote `s8r/bug-31` НЕ трогать.
- **Живой чекаут Develop/** занят Vite+uvicorn: работать в git worktree, НЕ `checkout` в основном дереве (см. память `feedback_git_worktree`).
- **Model A:** токены только в HttpOnly-cookie; в JSON-теле login/refresh/setup токенов НЕТ.
- **Cookie flags:** `Secure=not settings.DEBUG`; `access_token` HttpOnly SameSite=lax path=`/`; `refresh_token` HttpOnly SameSite=strict path=`/api/v1/auth/refresh`; `csrf_token` HttpOnly=False SameSite=strict path=`/` max_age=refresh-TTL.
- **Grace НЕ вводим** (D2). Миграций нет.
- **TDD обязателен для auth** (superpowers:test-driven-development). Каждый backend-таск: pyright 0 (или `py_compile` fallback). Каждый frontend-таск: `tsc --noEmit` 0.
- **Плагины:** после Edit .py → pyright-lsp diagnostic; после Edit .ts → typescript-lsp diagnostic; по auth/api/stores после блока → `/code-review`.
- **Коммиты — на русском.** Финальный push/мерж — по подтверждению заказчика, ветки обоих репо спрашивать отдельно.
- **Точки монтирования (verified):** WS в корне — `/ws` (`app/backtest/ws.py`), `/ws/trading-sessions/{uid}` (`app/trading/ws_sessions.py`), `/ws/backtest/{job}` (`app/backtest/ws_backtest.py`). Auth-роутер под `/api/v1/auth`. WS-close codes: `_WS_AUTH_FAIL=4401`, `_WS_FORBIDDEN=4403`, `_WS_TIMEOUT=4408`.
- **Тест-конвенции backend:** httpx `AsyncClient(ASGITransport(app))`, in-memory SQLite, `get_db` override. Файлы: `tests/test_routers/test_auth_router.py`, `tests/test_routers/test_auth_cookie_secure.py`, `tests/test_trading/test_ws_sessions.py`, `tests/unit/test_backtest/test_ws_backtest.py`.

---

## Файловая структура (что и зачем)

**Backend (Develop/backend):**
- `app/middleware/auth.py` — `oauth2_scheme(auto_error=False)` + новая зависимость `get_access_token`; `get_current_user` через неё.
- `app/auth/router.py` — cookie-хелперы (`_set_access_token_cookie` path→`/`, новые `_set_refresh_token_cookie`, `_set_csrf_cookie`); login/setup/refresh ставят 3 cookie, тело без токенов; refresh читает cookie; logout стирает 3 cookie; logout/change_password через `get_access_token`.
- `app/auth/schemas.py` — тело ответа без токенов (`AuthMetaResponse`).
- `app/middleware/csrf.py` — убрать `/api/v1/auth/refresh` из `EXEMPT_PATHS`.
- `app/middleware/rate_limit.py` — `/api/v1/auth/refresh` → категория `auth`.
- `app/backtest/ws.py`, `app/trading/ws_sessions.py`, `app/backtest/ws_backtest.py` — cookie-auth на upgrade + Origin-check; `auth_ok` первым кадром после accept.

**Frontend (Develop/frontend):**
- `src/api/session.ts` (new) — единый single-flight refresh (`navigator.locks`).
- `src/api/client.ts` — убрать Bearer/guard; 401 → `refreshSession()` → ретрай.
- `src/services/aiStreamClient.ts` — `refreshSession()`; fetch без Authorization.
- `src/stores/authStore.ts` — без токенов; `logout()` зовёт backend; `partialize {user}`.
- `src/hooks/wsAuth.ts` — `sendAuth` больше не шлёт токен (или удаляется из потребителей).
- `src/hooks/useWebSocket.ts`, `src/stores/backtestStore.ts`, `src/hooks/useTradingSessionsWS.ts`, `src/hooks/useBacktestJobWS.ts` — в `onopen` не слать `{action:auth}`; guard по `user`.
- `src/pages/LoginPage.tsx` — bodyless login → `/auth/me`.
- `src/hooks/useAuthBootstrap.ts` (new) + `src/App.tsx` — бутстрап `/auth/me` под loading-гейтом.

---

## Фаза 1 — Backend: cookie-контракт + get_access_token + CSRF + rate-limit

### Task 1: `get_access_token` (cookie ∨ Bearer), `get_current_user` через неё

**Files:**
- Modify: `app/middleware/auth.py`
- Test: `tests/test_routers/test_auth_cookie_secure.py` (дополнить)

**Interfaces:**
- Produces: `async def get_access_token(request: Request, token_hdr: str | None = Depends(oauth2_scheme)) -> str` (raises `AuthenticationError` если оба пусты). `oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)`.

- [ ] **Step 1: Failing test — cookie аутентифицирует**

```python
# tests/test_routers/test_auth_cookie_secure.py
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_get_me_authenticates_via_cookie(async_client_with_user):
    client, access_token = async_client_with_user  # фикстура: юзер + валидный access JWT
    # НЕТ Authorization header — только cookie
    client.cookies.set("access_token", access_token)
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 200

@pytest.mark.asyncio
async def test_get_me_authenticates_via_bearer_still_works(async_client_with_user):
    client, access_token = async_client_with_user
    resp = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {access_token}"})
    assert resp.status_code == 200

@pytest.mark.asyncio
async def test_get_me_401_when_neither(async_client_with_user):
    client, _ = async_client_with_user
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 401
```

Если фикстуры `async_client_with_user` нет — создать в этом же файле по образцу `tests/test_routers/test_auth_router.py` (in-memory SQLite, `get_db` override, `AuthService(db)._create_token_pair(user.id)` для токена).

- [ ] **Step 2: Run → FAIL**

Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_routers/test_auth_cookie_secure.py -k "via_cookie or neither" -v`
Expected: FAIL (cookie-путь даёт 401, т.к. сейчас только Bearer).

- [ ] **Step 3: Реализация в `app/middleware/auth.py`**

```python
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)


async def get_access_token(
    request: Request,
    token_hdr: str | None = Depends(oauth2_scheme),
) -> str:
    """Access-JWT из Authorization: Bearer (приоритет) или cookie access_token.

    Model A: фронт больше не шлёт Bearer (токен в HttpOnly-cookie), но
    тесты/API-клиенты могут — поэтому header в приоритете, cookie как основной
    браузерный канал.
    """
    token = token_hdr or request.cookies.get("access_token")
    if not token:
        raise AuthenticationError("Не авторизован")
    return token


async def get_current_user(
    token: str = Depends(get_access_token),
    db: AsyncSession = Depends(get_db),
) -> User:
    # ... тело без изменений (decode, проверка type/jti/revoked/user) ...
```

Заменить сигнатуру `get_current_user`: было `token: str = Depends(oauth2_scheme)` → стало `token: str = Depends(get_access_token)`. Остальное тело не трогать.

- [ ] **Step 4: Run → PASS**

Run: `.venv/bin/python -m pytest tests/test_routers/test_auth_cookie_secure.py -v`
Expected: PASS. Затем pyright-lsp diagnostic по `app/middleware/auth.py` → 0.

- [ ] **Step 5: Commit**

```bash
git add app/middleware/auth.py tests/test_routers/test_auth_cookie_secure.py
git commit -m "feat(auth): get_access_token — cookie ∨ Bearer для get_current_user (Model A)"
```

---

### Task 2: logout и change_password через `get_access_token`

**Files:**
- Modify: `app/auth/router.py` (строки `token: str = Depends(oauth2_scheme)` в `logout` ~164 и `change_password` ~210)
- Test: `tests/test_routers/test_auth_router.py` (дополнить)

- [ ] **Step 1: Failing test — logout по cookie без Bearer**

```python
@pytest.mark.asyncio
async def test_logout_via_cookie_only(async_client_with_user):
    client, access_token = async_client_with_user
    client.cookies.set("access_token", access_token)
    # csrf: logout мутирующий, но без csrf-cookie middleware пропускает (оба пусты)
    resp = await client.post("/api/v1/auth/logout")
    assert resp.status_code == 204
```

- [ ] **Step 2: Run → FAIL** (`oauth2_scheme` auto_error=False теперь вернёт None → 401 глубже, либо TypeError). Run: `.venv/bin/python -m pytest tests/test_routers/test_auth_router.py -k logout_via_cookie -v`

- [ ] **Step 3: Реализация** — в `app/auth/router.py` заменить в `logout` и `change_password`:

```python
from app.middleware.auth import get_current_user, get_access_token  # добавить импорт

# было: token: str = Depends(oauth2_scheme),
# стало:
    token: str = Depends(get_access_token),
```

(Убрать неиспользуемый импорт `oauth2_scheme`, если он больше не нужен в router.py.)

- [ ] **Step 4: Run → PASS** + pyright 0.

- [ ] **Step 5: Commit**

```bash
git add app/auth/router.py tests/test_routers/test_auth_router.py
git commit -m "feat(auth): logout/change_password читают access через get_access_token"
```

---

### Task 3: Cookie-хелперы + login/setup/refresh ставят 3 cookie, тело без токенов

**Files:**
- Modify: `app/auth/router.py`, `app/auth/schemas.py`
- Test: `tests/test_routers/test_auth_cookie_secure.py`

**Interfaces:**
- Produces: `_set_refresh_token_cookie(response, refresh_token)`, `_set_csrf_cookie(response, csrf_token)`; `_set_access_token_cookie` path=`/`. Тело login/refresh/setup = `{"token_type":"bearer","expires_in":<int>}`.

- [ ] **Step 1: Failing test — cookie ставятся, тело без токенов**

```python
@pytest.mark.asyncio
async def test_login_sets_three_cookies_no_body_tokens(async_client, seeded_user):
    resp = await async_client.post("/api/v1/auth/login",
                                   json={"username": "u", "password": "password123"})
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" not in body and "refresh_token" not in body
    assert body["token_type"] == "bearer" and "expires_in" in body
    cookies = resp.cookies
    assert "access_token" in cookies and "refresh_token" in cookies and "csrf_token" in cookies
    # флаги через Set-Cookie заголовки
    set_cookie = " ".join(resp.headers.get_list("set-cookie"))
    assert "HttpOnly" in set_cookie
    assert "Path=/api/v1/auth/refresh" in set_cookie  # refresh узкий path
    assert "SameSite=strict" in set_cookie.lower() or "samesite=strict" in set_cookie.lower()
```

- [ ] **Step 2: Run → FAIL** (сейчас тело содержит токены, refresh-cookie нет).

- [ ] **Step 3: Реализация** — `app/auth/router.py`:

```python
def _set_access_token_cookie(response: Response, access_token: str) -> None:
    response.set_cookie(
        key="access_token", value=access_token,
        httponly=True, samesite="lax", secure=not settings.DEBUG,
        max_age=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        path="/",  # ИЗМЕНЕНО: было "/api" — WS-эндпоинты в корне /ws*, cookie должна доезжать
    )


def _set_refresh_token_cookie(response: Response, refresh_token: str) -> None:
    response.set_cookie(
        key="refresh_token", value=refresh_token,
        httponly=True, samesite="strict", secure=not settings.DEBUG,
        max_age=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS * 86400,
        path="/api/v1/auth/refresh",
    )


def _set_csrf_cookie(response: Response, csrf_token: str) -> None:
    response.set_cookie(
        key="csrf_token", value=csrf_token,
        httponly=False, samesite="strict", secure=not settings.DEBUG,
        max_age=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS * 86400,  # = refresh TTL (фикс TTL-mismatch)
        path="/",
    )


def _auth_cookie_response(token_response, *, status_code: int = 200) -> JSONResponse:
    """JSON-тело БЕЗ токенов + 3 cookie."""
    csrf_token = secrets.token_urlsafe(32)
    body = {"token_type": token_response.token_type, "expires_in": token_response.expires_in}
    response = JSONResponse(content=body, status_code=status_code)
    _set_access_token_cookie(response, token_response.access_token)
    _set_refresh_token_cookie(response, token_response.refresh_token)
    _set_csrf_cookie(response, csrf_token)
    return response
```

Переписать `login`/`setup`/`refresh` на возврат `_auth_cookie_response(token_response[, status_code=201])`. В `login` prefetch оставить как есть (декодит `token_response.access_token` — внутренний объект, не тело). Убрать старый инлайн-блок set_cookie csrf в login.

`app/auth/schemas.py` — новая схема тела (response_model эндпоинтов):

```python
class AuthMetaResponse(BaseModel):
    token_type: str = "bearer"
    expires_in: int
```

Поменять `response_model=TokenResponse` → `response_model=AuthMetaResponse` в `login`/`setup`/`refresh`. `TokenResponse` (с токенами) остаётся для внутреннего `_create_token_pair`.

- [ ] **Step 4: Run → PASS** + pyright 0. Прогнать регресс: `.venv/bin/python -m pytest tests/test_routers/ tests/unit/test_auth_service.py -q` (существующие тесты, читавшие `resp.json()["access_token"]`, обновить на cookie).

- [ ] **Step 5: Commit**

```bash
git add app/auth/router.py app/auth/schemas.py tests/
git commit -m "feat(auth): login/setup/refresh ставят access+refresh+csrf cookie, тело без токенов (CFG-FE-01)"
```

---

### Task 4: `/auth/refresh` читает refresh из cookie + требует CSRF

**Files:**
- Modify: `app/auth/router.py` (`refresh`), `app/middleware/csrf.py`
- Test: `tests/test_routers/test_auth_cookie_secure.py`

- [ ] **Step 1: Failing tests**

```python
@pytest.mark.asyncio
async def test_refresh_reads_cookie_no_body(logged_in_client):
    client = logged_in_client  # уже с cookie после login
    csrf = client.cookies.get("csrf_token")
    resp = await client.post("/api/v1/auth/refresh", headers={"X-CSRF-Token": csrf})
    assert resp.status_code == 200
    assert "access_token" not in resp.json()

@pytest.mark.asyncio
async def test_refresh_without_csrf_header_403(logged_in_client):
    client = logged_in_client
    resp = await client.post("/api/v1/auth/refresh")  # csrf-cookie есть, header нет
    assert resp.status_code == 403
```

- [ ] **Step 2: Run → FAIL** (refresh сейчас требует тело; exempt от CSRF).

- [ ] **Step 3: Реализация**

`app/auth/router.py` `refresh`:

```python
@router.post("/refresh", response_model=AuthMetaResponse)
async def refresh(request: Request, db: AsyncSession = Depends(get_db)):
    refresh_token = request.cookies.get("refresh_token")
    if not refresh_token:
        # fallback тело — для тестов/API-клиентов
        try:
            payload = await request.json()
            refresh_token = payload.get("refresh_token") if isinstance(payload, dict) else None
        except Exception:
            refresh_token = None
    if not refresh_token:
        raise AuthenticationError("refresh token отсутствует")
    service = AuthService(db)
    try:
        token_response = await service.refresh_token(refresh_token)
    except ValueError as e:
        raise AuthenticationError(str(e))
    return _auth_cookie_response(token_response)
```

`app/middleware/csrf.py` — убрать `/api/v1/auth/refresh` из `EXEMPT_PATHS`:

```python
    EXEMPT_PATHS = {
        "/api/v1/auth/login",
        "/api/v1/auth/setup",
        "/api/v1/health",
    }
```

- [ ] **Step 4: Run → PASS** + pyright 0.

- [ ] **Step 5: Commit**

```bash
git add app/auth/router.py app/middleware/csrf.py tests/
git commit -m "feat(auth): /auth/refresh читает refresh из cookie + требует X-CSRF-Token"
```

---

### Task 5: logout стирает 3 cookie + rate-limit refresh → auth

**Files:**
- Modify: `app/auth/router.py` (`logout`), `app/middleware/rate_limit.py`
- Test: `tests/test_routers/test_auth_cookie_secure.py`

- [ ] **Step 1: Failing test**

```python
@pytest.mark.asyncio
async def test_logout_clears_three_cookies(logged_in_client):
    client = logged_in_client
    csrf = client.cookies.get("csrf_token")
    resp = await client.post("/api/v1/auth/logout", headers={"X-CSRF-Token": csrf})
    assert resp.status_code == 204
    sc = " ".join(resp.headers.get_list("set-cookie")).lower()
    assert 'access_token=' in sc and 'refresh_token=' in sc and 'csrf_token=' in sc
    assert 'max-age=0' in sc or 'expires=thu, 01 jan 1970' in sc

def test_refresh_is_auth_rate_category():
    from app.middleware.rate_limit import RateLimitMiddleware
    mw = RateLimitMiddleware.__new__(RateLimitMiddleware)
    assert mw._get_category("/api/v1/auth/refresh") == "auth"
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Реализация**

`app/auth/router.py` `logout` — заменить финал:

```python
    response = Response(status_code=204)
    response.delete_cookie(key="access_token", path="/")
    response.delete_cookie(key="refresh_token", path="/api/v1/auth/refresh")
    response.delete_cookie(key="csrf_token", path="/")
    return response
```

`app/middleware/rate_limit.py` `CATEGORY_PATHS`:

```python
    CATEGORY_PATHS = {
        "/api/v1/auth/login": "auth",
        "/api/v1/auth/refresh": "auth",
        "/api/v1/trading": "trading",
        "/api/v1/ai": "ai",
    }
```

- [ ] **Step 4: Run → PASS** + pyright 0.

- [ ] **Step 5: Commit**

```bash
git add app/auth/router.py app/middleware/rate_limit.py tests/
git commit -m "feat(auth): logout стирает 3 cookie; /auth/refresh в rate-limit категории auth"
```

---

## Фаза 2 — Backend: WS cookie-auth (все 3 эндпоинта)

> Паттерн для всех трёх: аутентификация из cookie ДО/на accept; при провале `close(4401)`; Origin не из `CORS_ORIGINS` → `close(4403)`; после `accept()` — `send_json({"type":"auth_ok"})` первым кадром (контракт с фронтом сохраняется), затем прежняя логика (snapshot/subscribe-loop). Убрать шаг `receive_text()` для auth-сообщения и чтение `?token=`.

### Task 6: `/ws/trading-sessions/{uid}` и `/ws/backtest/{job}` — cookie-auth

**Files:**
- Modify: `app/trading/ws_sessions.py`, `app/backtest/ws_backtest.py`
- Test: `tests/test_trading/test_ws_sessions.py`, `tests/unit/test_backtest/test_ws_backtest.py`

**Interfaces:**
- Produces: helper `_ws_authenticate(websocket) -> int | None` (читает `access_token` cookie → user_id) и `_ws_origin_allowed(websocket) -> bool`. Вынести в `app/common/ws_auth.py` (DRY для 3 файлов).

- [ ] **Step 1: Failing test (ws_sessions)** — cookie аутентифицирует, снятие handshake

```python
# tests/test_trading/test_ws_sessions.py
def test_ws_sessions_auth_via_cookie(client_with_ws, user_and_token):
    user_id, token = user_and_token
    with client_with_ws.websocket_connect(
        f"/ws/trading-sessions/{user_id}",
        headers={"cookie": f"access_token={token}", "origin": "http://localhost:5173"},
    ) as ws:
        msg = ws.receive_json()
        assert msg["type"] == "auth_ok"   # первым кадром, без отправки {action:auth}

def test_ws_sessions_no_cookie_4401(client_with_ws, user_and_token):
    user_id, _ = user_and_token
    with pytest.raises(WebSocketDisconnect) as exc:
        with client_with_ws.websocket_connect(f"/ws/trading-sessions/{user_id}") as ws:
            ws.receive_json()
    assert exc.value.code == 4401

def test_ws_sessions_bad_origin_4403(client_with_ws, user_and_token):
    user_id, token = user_and_token
    with pytest.raises(WebSocketDisconnect) as exc:
        with client_with_ws.websocket_connect(
            f"/ws/trading-sessions/{user_id}",
            headers={"cookie": f"access_token={token}", "origin": "http://evil.example"},
        ) as ws:
            ws.receive_json()
    assert exc.value.code == 4403
```

(Существующие тесты, слающие `{action:auth}`, обновить: теперь cookie на connect + первый кадр — `auth_ok`.)

- [ ] **Step 2: Run → FAIL**

Run: `.venv/bin/python -m pytest tests/test_trading/test_ws_sessions.py -k "cookie or 4401 or origin" -v`

- [ ] **Step 3: Реализация** — создать `app/common/ws_auth.py`:

```python
import jwt
from fastapi import WebSocket
from app.config import settings


def ws_authenticate(websocket: WebSocket) -> int | None:
    """user_id из access_token cookie на WS-upgrade, либо None."""
    token = websocket.cookies.get("access_token")
    if not token:
        return None
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        if payload.get("type") != "access":
            return None
        sub = payload.get("sub")
        return int(sub) if sub is not None else None
    except (jwt.InvalidTokenError, ValueError):
        return None


def ws_origin_allowed(websocket: WebSocket) -> bool:
    """Defense-in-depth от CSWSH: Origin из CORS_ORIGINS. Нет Origin → разрешаем
    (не-браузерные клиенты/тесты), т.к. cookie SameSite уже режет cross-site WS."""
    origin = websocket.headers.get("origin")
    if origin is None:
        return True
    allowed = {o.strip() for o in settings.CORS_ORIGINS.split(",")}
    return origin in allowed
```

В `ws_sessions.py` `trading_sessions_ws` — заменить блок «1. Auth — первое сообщение» (accept → receive_text → parse → decode → send auth_ok) на:

```python
    if not ws_origin_allowed(websocket):
        await websocket.close(code=_WS_FORBIDDEN)
        return
    decoded_user_id = ws_authenticate(websocket)
    if decoded_user_id is None:
        await websocket.close(code=_WS_AUTH_FAIL)
        return
    if decoded_user_id != user_id:
        await websocket.close(code=_WS_FORBIDDEN)
        return
    await websocket.accept()
    await websocket.send_json({"type": "auth_ok"})
    # далее — прежняя логика snapshot/subscribe без изменений
```

Аналогично `ws_backtest.py` `backtest_job_ws`: Origin+cookie-auth перед accept; после accept — проверка владельца job (как была) → `send_json({"type":"auth_ok"})` → snapshot. Импортировать `ws_authenticate, ws_origin_allowed`. Убрать `_decode_token`/`receive_text`-auth-блок.

- [ ] **Step 4: Run → PASS** + pyright 0 по 3 файлам.

- [ ] **Step 5: Commit**

```bash
git add app/common/ws_auth.py app/trading/ws_sessions.py app/backtest/ws_backtest.py tests/
git commit -m "feat(ws): cookie-auth на upgrade для /ws/trading-sessions и /ws/backtest + Origin-check"
```

---

### Task 7: `/ws` (мультиплексор) — cookie-auth + auth_ok

**Files:**
- Modify: `app/backtest/ws.py`
- Test: `tests/unit/test_backtest/test_ws_authz.py`

- [ ] **Step 1: Failing test**

```python
def test_multiplex_ws_cookie_auth_sends_auth_ok(client_with_ws, user_and_token):
    _, token = user_and_token
    with client_with_ws.websocket_connect(
        "/ws", headers={"cookie": f"access_token={token}", "origin": "http://localhost:5173"},
    ) as ws:
        assert ws.receive_json()["type"] == "auth_ok"
        ws.send_json({"action": "subscribe", "channel": "health"})
        # health — публичный, подписка ок

def test_multiplex_ws_no_cookie_4401(client_with_ws):
    with pytest.raises(WebSocketDisconnect) as exc:
        with client_with_ws.websocket_connect("/ws") as ws:
            ws.receive_json()
    assert exc.value.code == 4401
```

- [ ] **Step 2: Run → FAIL** (сейчас `_authenticate_ws` читает `?token=`, close 4001, нет auth_ok).

- [ ] **Step 3: Реализация** — `app/backtest/ws.py`:

Заменить `_authenticate_ws` (query-param) вызовом общего хелпера. В `websocket_endpoint`:

```python
from app.common.ws_auth import ws_authenticate, ws_origin_allowed

    if not ws_origin_allowed(websocket):
        await websocket.close(code=4403)
        return
    user_id = ws_authenticate(websocket)
    if not user_id:
        await websocket.close(code=4401, reason="Authentication required")  # было 4001
        return
    await websocket.accept()
    await websocket.send_json({"type": "auth_ok"})   # НОВОЕ: контракт с фронтом
    # далее — прежний subscribe/unsubscribe-loop
```

Удалить локальный `_authenticate_ws` (или оставить только если используется в др. тестах — тогда переписать на cookie).

- [ ] **Step 4: Run → PASS** + pyright 0. Регресс WS: `.venv/bin/python -m pytest tests/unit/test_backtest/test_ws_authz.py tests/unit/test_backtest/test_ws_backtest.py tests/test_trading/test_ws_sessions.py -q`

- [ ] **Step 5: Commit**

```bash
git add app/backtest/ws.py tests/
git commit -m "feat(ws): /ws мультиплексор — cookie-auth + auth_ok (чинит рассогласование Волны 3)"
```

---

### Task 8: Backend gate + /code-review

- [ ] **Step 1:** Полный backend прогон: `cd Develop/backend && .venv/bin/python -m pytest tests/ -q` → 0 failed (обновить все тесты, читавшие токены из тела).
- [ ] **Step 2:** pyright по всем изменённым: 0 новых ошибок (сверить с baseline).
- [ ] **Step 3:** `/code-review` по auth (router/service/middleware/ws) → находки исправить test-first.
- [ ] **Step 4: Commit** фиксов ревью.

---

## Фаза 3 — Frontend: single-flight refresh + клиенты

### Task 9: `src/api/session.ts` — единый single-flight refresh (Web Locks)

**Files:**
- Create: `src/api/session.ts`
- Test: `src/api/__tests__/session.test.ts`

**Interfaces:**
- Produces: `export async function refreshSession(): Promise<boolean>` — `true` при успехе (cookie обновлён), `false` при провале. In-flight dedupe + `navigator.locks` cross-tab.

- [ ] **Step 1: Failing test**

```typescript
// src/api/__tests__/session.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';
vi.mock('axios');

describe('refreshSession single-flight', () => {
  beforeEach(() => { vi.resetModules(); vi.clearAllMocks(); });

  it('N параллельных вызовов → один POST /auth/refresh', async () => {
    (axios.post as any) = vi.fn().mockResolvedValue({ status: 200, data: {} });
    // мок navigator.locks (jsdom его не имеет)
    (globalThis.navigator as any).locks = { request: (_n: string, cb: any) => cb() };
    const { refreshSession } = await import('../session');
    const results = await Promise.all([refreshSession(), refreshSession(), refreshSession()]);
    expect(results).toEqual([true, true, true]);
    expect((axios.post as any).mock.calls.length).toBe(1);
  });

  it('провал refresh → false', async () => {
    (axios.post as any) = vi.fn().mockRejectedValue(new Error('401'));
    (globalThis.navigator as any).locks = { request: (_n: string, cb: any) => cb() };
    const { refreshSession } = await import('../session');
    expect(await refreshSession()).toBe(false);
  });
});
```

- [ ] **Step 2: Run → FAIL**

Run: `cd Develop/frontend && pnpm vitest run src/api/__tests__/session.test.ts`

- [ ] **Step 3: Реализация**

```typescript
// src/api/session.ts
import axios from 'axios';

const BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api/v1';

let inFlight: Promise<boolean> | null = null;

function getCSRFToken(): string | null {
  const m = document.cookie.match(/csrf_token=([^;]+)/);
  return m ? m[1] : null;
}

async function doRefresh(): Promise<boolean> {
  try {
    // bodyless: refresh-токен едет из HttpOnly-cookie. CSRF double-submit.
    await axios.post(`${BASE}/auth/refresh`, null, {
      withCredentials: true,
      headers: { 'X-CSRF-Token': getCSRFToken() ?? '' },
    });
    return true;
  } catch {
    return false;
  }
}

/**
 * Единый refresh для всего приложения:
 * - in-flight dedupe внутри вкладки (один POST на N конкурентных 401);
 * - navigator.locks сериализует между вкладками (нет refresh-стада);
 * - результат — boolean (новый токен уже в cookie, вызывающий просто ретраит).
 */
export function refreshSession(): Promise<boolean> {
  if (inFlight) return inFlight;
  const run = async (): Promise<boolean> => {
    if (typeof navigator !== 'undefined' && navigator.locks?.request) {
      return navigator.locks.request('auth-refresh', doRefresh);
    }
    return doRefresh(); // fallback: per-tab single-flight
  };
  inFlight = run().finally(() => { inFlight = null; });
  return inFlight;
}
```

- [ ] **Step 4: Run → PASS** + typescript-lsp diagnostic 0.

- [ ] **Step 5: Commit**

```bash
git add src/api/session.ts src/api/__tests__/session.test.ts
git commit -m "feat(api): единый single-flight refresh на Web Locks (P1W2-REFRESH-GRACE)"
```

---

### Task 10: `client.ts` — убрать Bearer/guard, 401 → refreshSession

**Files:**
- Modify: `src/api/client.ts`
- Test: `src/api/__tests__/client.test.ts` (создать/дополнить)

- [ ] **Step 1: Failing test**

```typescript
it('401 → refreshSession() → ретрай оригинала', async () => {
  // мок session.refreshSession → true; проверить повторный вызов запроса
  // (детали — по образцу существующих interceptor-тестов)
});
it('повторный 401 после refresh → logout + redirect /login', async () => { /* ... */ });
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Реализация** — `src/api/client.ts`:
  - Удалить `doRefresh`, `isRefreshing`, `refreshPromise` (уходит в session.ts).
  - Request-интерцептор: удалить чтение `token`, установку `Authorization` и token-guard `if (!token && !config.url?.startsWith('/auth/'))`. Оставить `withCredentials`, AbortController, CSRF-заголовок на мутациях.
  - Response-интерцептор 401:

```typescript
import { refreshSession } from './session';
// ...
    if (error.response?.status === 401 && !originalRequest._retried) {
      const path = window.location.pathname;
      if (path === '/login' || path === '/setup') return Promise.reject(error);
      originalRequest._retried = true;
      if (await refreshSession()) {
        return apiClient(originalRequest);  // cookie обновлён, Authorization не нужен
      }
      useAuthStore.getState().logout();
      window.location.href = '/login';
    }
    return Promise.reject(error);
```

- [ ] **Step 4: Run → PASS** + tsc 0.

- [ ] **Step 5: Commit**

```bash
git add src/api/client.ts src/api/__tests__/client.test.ts
git commit -m "refactor(api): client.ts — cookie-auth, 401 через единый refreshSession"
```

---

### Task 11: `aiStreamClient.ts` — refreshSession, fetch без Authorization

**Files:**
- Modify: `src/services/aiStreamClient.ts`
- Test: `src/services/__tests__/aiStreamClient.test.ts` (обновить)

- [ ] **Step 1: Failing test** — при 401 зовётся `refreshSession` (мок), fetch без Authorization-заголовка, есть `credentials:'include'`.

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Реализация**:
  - Удалить локальный `refreshTokenIfNeeded`; импорт `refreshSession` из `../api/session`.
  - `doFetch`: убрать `Authorization`, добавить `credentials: 'include'`:

```typescript
  const doFetch = async () => fetch(`${baseUrl}/ai/chat/stream`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: buildBody(),
    credentials: 'include',
    signal,
  });
  // ...
  let response = await doFetch();
  if (response.status === 401) {
    if (await refreshSession()) response = await doFetch();
    else { useAuthStore.getState().logout(); window.location.href = '/login'; return; }
  }
```

- [ ] **Step 4: Run → PASS** + tsc 0.

- [ ] **Step 5: Commit**

```bash
git add src/services/aiStreamClient.ts src/services/__tests__/aiStreamClient.test.ts
git commit -m "refactor(ai): aiStreamClient — cookie-auth + единый refreshSession"
```

---

## Фаза 4 — Frontend: authStore, LoginPage, bootstrap

### Task 12: `authStore.ts` — без токенов, logout зовёт backend

**Files:**
- Modify: `src/stores/authStore.ts`
- Test: `src/stores/__tests__/authStore.test.ts` (создать/дополнить)

**Interfaces:**
- Produces: `login(user: AuthUser): void` (без токенов); `isAuthenticated(): boolean` = `user != null`; `logout(): Promise<void>` зовёт `POST /auth/logout`; `partialize` → `{ user }`.

- [ ] **Step 1: Failing tests**

```typescript
it('partialize не сохраняет токены — только user', () => {
  // после login persist содержит {user}, без token/refreshToken
});
it('logout() зовёт POST /auth/logout и чистит user', async () => {
  const post = vi.spyOn(apiClient, 'post').mockResolvedValue({} as any);
  await useAuthStore.getState().logout();
  expect(post).toHaveBeenCalledWith('/auth/logout');
  expect(useAuthStore.getState().user).toBeNull();
});
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Реализация** — `src/stores/authStore.ts`:
  - `AuthState`: удалить `token`, `refreshToken`, `setToken`. `login: (user: AuthUser) => void`. `isAuthenticated: () => get().user !== null`.
  - `login(user)`: `renewAbortController(); set({ user });`
  - `logout`:

```typescript
      logout: async () => {
        try { await apiClient.post('/auth/logout'); } catch { /* best-effort: сервер стирает cookie */ }
        closeWS();
        abortAllInflight();
        renewAbortController();
        set({ user: null });
        clearCandlesCache();
        try { useBackgroundBacktestsStore.getState().clear(); localStorage.removeItem('background-backtests'); } catch { /**/ }
        try { useUserFavoritesStore.getState().reset(); localStorage.removeItem('user_favorites'); localStorage.removeItem('favoriteTimeframes'); } catch { /**/ }
        // НЕ удаляем 'auth-storage' целиком — секрета там нет, не рвём соседнюю вкладку
      },
```

  - `persist`: `partialize: (state) => ({ user: state.user })`.

- [ ] **Step 4: Run → PASS** + tsc 0. Прогнать зависимые (`client.ts`, `aiStreamClient.ts`, `useWebSocket.ts` — обновить их обращения к `getState().token`).

- [ ] **Step 5: Commit**

```bash
git add src/stores/authStore.ts src/stores/__tests__/authStore.test.ts
git commit -m "refactor(auth): authStore без токенов, logout зовёт backend (Model A)"
```

---

### Task 13: LoginPage — bodyless login → /auth/me

**Files:**
- Modify: `src/pages/LoginPage.tsx`
- Test: `src/pages/__tests__/LoginPage.test.tsx` (если есть) или e2e

- [ ] **Step 1: Failing test** — `handleSubmit` вызывает `login({id, username})` без чтения `resp.data.access_token`, затем `refreshUser()`.

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Реализация** — в `handleSubmit`:

```typescript
      await apiClient.post('/auth/login', { username, password });  // cookie ставятся
      login({ id: 0, username });                                    // без токенов
      await refreshUser();                                           // /auth/me → полный профиль
      navigate('/');
```

(Сигнатура `login` теперь `(user)` — см. Task 12.)

- [ ] **Step 4: Run → PASS** + tsc 0.

- [ ] **Step 5: Commit**

```bash
git add src/pages/LoginPage.tsx
git commit -m "refactor(auth): LoginPage — bodyless login + /auth/me (Model A)"
```

---

### Task 14: Бутстрап `/auth/me` под loading-гейтом

**Files:**
- Create: `src/hooks/useAuthBootstrap.ts`
- Modify: `src/App.tsx`
- Test: `src/hooks/__tests__/useAuthBootstrap.test.ts`

**Interfaces:**
- Produces: `useAuthBootstrap(): { booted: boolean }`. На старте зовёт `refreshUser()` один раз; `booted=true` после ответа. `App` рендерит `<Loader/>` пока `!booted`.

- [ ] **Step 1: Failing test** — хук вызывает `refreshUser` один раз на монтировании, `booted` становится true.

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Реализация**

```typescript
// src/hooks/useAuthBootstrap.ts
import { useEffect, useState, useRef } from 'react';
import { useAuthStore } from '../stores/authStore';

export function useAuthBootstrap(): { booted: boolean } {
  const [booted, setBooted] = useState(false);
  const ran = useRef(false);
  const refreshUser = useAuthStore((s) => s.refreshUser);
  useEffect(() => {
    if (ran.current) return;
    ran.current = true;
    // /auth/me: 200 → user; 401 → interceptor сам refresh→ретрай или logout→/login.
    refreshUser().finally(() => setBooted(true));
  }, [refreshUser]);
  return { booted };
}
```

`src/App.tsx` — обернуть Routes:

```typescript
export default function App() {
  const { booted } = useAuthBootstrap();
  if (!booted) return <Center h="100vh"><Loader size="lg" /></Center>;
  return (<Routes> {/* ... */} </Routes>);
}
```

(Гейт предотвращает флэш защищённого контента до проверки cookie.)

- [ ] **Step 4: Run → PASS** + tsc 0.

- [ ] **Step 5: Commit**

```bash
git add src/hooks/useAuthBootstrap.ts src/App.tsx src/hooks/__tests__/useAuthBootstrap.test.ts
git commit -m "feat(auth): бутстрап /auth/me под loading-гейтом (Model A reload)"
```

---

## Фаза 5 — Frontend: WS-хуки (убрать отправку токена)

### Task 15: 5 WS-потребителей — не слать `{action:auth}`, guard по user

**Files:**
- Modify: `src/hooks/wsAuth.ts`, `src/hooks/useWebSocket.ts`, `src/stores/backtestStore.ts`, `src/hooks/useTradingSessionsWS.ts`, `src/hooks/useBacktestJobWS.ts`
- Test: обновить `src/hooks/__tests__/useWebSocket.test.ts`, `src/hooks/__tests__/useTradingSessionsWS.test.ts`, `src/stores/__tests__/backtestStoreWs.test.ts`

- [ ] **Step 1: Failing test** — `onopen` НЕ вызывает `socket.send({action:'auth',...})`; после `auth_ok` (мок) идут подписки/данные; guard: без `user` соединение не открывается.

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Реализация** (единый паттерн; токен из JS исчез — auth делает cookie на upgrade):
  - `wsAuth.ts` `sendAuth`: больше не нужен; удалить его вызовы. Оставить `getWsBase`, `isAuthOk`, `isAuthError`.
  - `useWebSocket.ts` `connectWS`: `const user = useAuthStore.getState().user; if (!user) return;` (вместо `token`). В `socket.onopen`: убрать `if (!sendAuth(socket)) socket.close()` — оставить пустой onopen (auth уже сделан cookie; подписки уйдут после `auth_ok` в onmessage — логика `wsAuthed`/`flushSubscriptions` без изменений).
  - `backtestStore.ts`: `socket.onopen`: убрать `if (!sendAuth(socket)) …`; guard по `user`. Ожидание `auth_ok` перед subscribe остаётся.
  - `useTradingSessionsWS.ts`: `const token = ...` → `const user = useAuthStore.getState().user; if (!user) { setStatus('disconnected'); return; }`. В `socket.onopen`: удалить `socket.send(JSON.stringify({action:'auth', token}))`. Ожидание `auth_ok` в onmessage — без изменений.
  - `useBacktestJobWS.ts`: обе реализации (одиночная ~128 и map ~252) — удалить `socket.send({action:'auth', token})` в onopen; guard по `user`.

- [ ] **Step 4: Run → PASS**: `pnpm vitest run src/hooks src/stores` + tsc 0. Playwright WS-моки (`auth_ok`) обновить, если слали auth.

- [ ] **Step 5: Commit**

```bash
git add src/hooks/wsAuth.ts src/hooks/useWebSocket.ts src/stores/backtestStore.ts src/hooks/useTradingSessionsWS.ts src/hooks/useBacktestJobWS.ts src/**/__tests__
git commit -m "refactor(ws): фронт не шлёт токен — auth по cookie на upgrade, auth_ok первым кадром"
```

---

## Фаза 6 — Playwright + гейт + /code-review

### Task 16: E2E план + сценарии

**Files:**
- Create: `Спринты/Code_Review_Full_2026-07/e2e_auth_hardening_plan.md`
- Create/Modify: `Develop/frontend/e2e/auth-hardening.spec.ts`

- [ ] **Step 1:** Написать `e2e_auth_hardening_plan.md` (сценарии/предусловия/шаги/ожидания) — ДО тестов (правило проекта E2E).
- [ ] **Step 2:** Инфраструктура: `npx playwright --version`, поднять backend+frontend (реальный инстанс — cookie-flow нельзя мокать).
- [ ] **Step 3:** Тесты:
  - login → cookie появились (`access_token`/`refresh_token` HttpOnly в DevTools/context.cookies()) → работа → logout → cookie исчезли;
  - тихий refresh при истёкшем access (подождать/подделать TTL) — без разлогина;
  - **ДВЕ вкладки**: обе активны через ротацию — ни одну не выкидывает;
  - reload сохраняет сессию (cookie-бутстрап `/auth/me`);
  - WS: график/сессии/бэктест получают данные (cookie-auth).
- [ ] **Step 4:** `npx playwright test` — реально прогнать. Результат (passed/failed) — в `P1_AUTH_HARDENING_LOG.md`.
- [ ] **Step 5: Commit** тестов + плана.

### Task 17: Полный гейт + /code-review + фиксы

- [ ] **Step 1:** Backend `pytest tests/ -q` = 0 failed; pyright 0 новых.
- [ ] **Step 2:** Frontend `pnpm vitest run` = 0 failed; `npx tsc --noEmit` = 0.
- [ ] **Step 3:** Playwright = passed.
- [ ] **Step 4:** `/code-review` по auth (backend) и api/stores (frontend) → находки исправить test-first → повторный гейт.
- [ ] **Step 5: Commit** фиксов.

---

## Фаза 7 — Документация

### Task 18: Лог волны + project_state

**Files:**
- Create: `Спринты/Code_Review_Full_2026-07/P1_AUTH_HARDENING_LOG.md`
- Modify: `Спринты/project_state.md`

- [ ] **Step 1:** `P1_AUTH_HARDENING_LOG.md` — реализовано / файлы / тесты (числа гейта) / integration points / `/code-review` находки+фиксы / известные ограничения (`P1-AUTH-NET-LOSS-RELOGIN`, family-revocation) / закрытый попутно `P1W3-WS-AUTH-CONSOLIDATE`.
- [ ] **Step 2:** `project_state.md` — новая запись 2026-07-08 (auth-hardening на `p1/auth-hardening`, база `0e039be`, гейт, backlog).
- [ ] **Step 3:** Обновить `Develop/CLAUDE.md` stack_gotchas при необходимости (напр. cookie path vs WS root path; CSRF на refresh + TTL).
- [ ] **Step 4:** Push `p1/auth-hardening` (обе репо — ветки спросить отдельно; remote `s8r/bug-31` не трогать) — **по подтверждению заказчика**.
- [ ] **Step 5:** Предложить финальное сведение всех `p1/wave*` + `p1/auth-hardening` в `s8r/bug-31` одним PR (после Волны 3 — уже готова).

---

## Self-Review (покрытие спеки)

- §2 D0 Model A → Tasks 3,12 (тело без токенов; стор без токенов). ✔
- §2 D1 WS cookie-on-upgrade (3 эндпоинта) → Tasks 6,7,15. ✔
- §2 D2 без grace → отражено (Task 4 не добавляет grace-логику). ✔
- §2 D3 CSRF+TTL → Tasks 3 (csrf TTL=refresh),4 (refresh требует CSRF). ✔
- §2 D4 get_current_user cookie∨Bearer → Task 1. ✔
- §3 cookie-контракт (access path→/, refresh узкий, csrf TTL) → Task 3. ✔
- §4.2 login/setup/refresh/logout → Tasks 3,4,5. §4.3 get_access_token/3 сайта → Tasks 1,2. §4.4 CSRF exempt → Task 4. §4.6 WS → Tasks 6,7. §4.7 rate-limit → Task 5. §4.8 HTTPException → покрыто (throw AuthenticationError). ✔
- §5.1 authStore → Task 12. §5.2 session.ts → Task 9. §5.3 client → Task 10. §5.4 aiStream → Task 11. §5.5 WS-хуки → Task 15. §5.6 LoginPage → Task 13. §5.7 bootstrap → Task 14. ✔
- §6 тесты (pytest/vitest/Playwright, гонка ver-6) → Tasks 1-15 (unit) + 16 (E2E) + 17 (гейт). ⚠ Гонка ver-6 (два конкурентных refresh) — добавить явный backend-тест в Task 4/8 (atomic `_revoke_jti` уже покрыт в Волне 2; здесь проверить, что фронтовый single-flight + cookie-модель не создают её в UI).
- §7 ограничения → Task 18 (лог). §8 порядок → фазы 1-7. §9 карта файлов → «Файловая структура». ✔

**Type-consistency:** `refreshSession(): Promise<boolean>` (Tasks 9,10,11); `login(user)` (Tasks 12,13); `get_access_token` (Tasks 1,2); `ws_authenticate`/`ws_origin_allowed` (Tasks 6,7); `_auth_cookie_response`/`_set_*_cookie` (Tasks 3,4,5). Согласованы.

**Дополнение (из self-review):** в Task 8 добавить явный тест гонки ver-6 —

```python
@pytest.mark.asyncio
async def test_concurrent_refresh_same_jti_one_wins(db_and_two_clients):
    # два конкурентных /auth/refresh с ОДНИМ refresh-jti (cookie скопирован):
    # ровно один 200, второй 401 «Token отозван» (atomic _revoke_jti, grace нет)
    ...
```
