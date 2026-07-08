# Дизайн: Auth-hardening мини-волна (Model A — полный HttpOnly)

> Спецификация, зафиксированная в brainstorm-фазе (2026-07-08) перед реализацией.
> База: `p1/wave3-frontend @ 0e039be` (Волна 3 завершена). Ветка волны: `p1/auth-hardening`.
> Метод: superpowers brainstorm → эта спека → writing-plans → test-first реализация.
> Источник скоупа: `P1_AUTH_HARDENING_HANDOFF.md`, `P1_WAVE2_LOG.md` (backlog), верификатор ver-6.

---

## 1. Цель и решаемые дефекты

- **CFG-FE-01** — access/refresh токены в `localStorage` (zustand `persist`, ключ `auth-storage`) доступны любому XSS.
- **P1W2-REFRESH-GRACE** — при двух вкладках / активном AI-чате пользователя разлогинивает ~каждые 30 мин: два независимых refresh-клиента (`client.ts doRefresh` + `aiStreamClient.ts refreshTokenIfNeeded`) без общего single-flight; проигравший конкурентный refresh получает «Token отозван» → `logout()`, а `logout()` стирает `auth-storage` соседней вкладки.

Backend и frontend меняются **вместе** — модель хранения токенов нельзя менять «наполовину».

## 2. Принятые решения (brainstorm + независимое ревью + верификация по коду)

| # | Решение | Обоснование |
|---|---|---|
| D0 | **Model A — полный HttpOnly**: оба токена только в cookie, JS их не видит | Закрывает выгрузку и access, и refresh наружу при XSS (Model B оставлял бы access XSS-читаемым ≤30 мин). Соответствует букве handoff «JS их не видит». |
| D1 | **WS-auth = cookie на upgrade (W1)** для всех 3 WS-эндпоинтов | Под Model A JS теряет токен → handshake `{action:auth,token}` невозможен. Cookie на HTTP-upgrade — единый auth, попутно чинит рассогласование `/ws` (Волна 3). |
| D2 | **Grace-окно НЕ вводим** | Под Model A refresh-cookie один на браузер; cross-tab single-flight (Web Locks) + браузер-wide ротация делают проигравшую вкладку успешной (предъявляет уже новый cookie). Grace ослаблял бы reuse-detection и был бы избыточен. Миграция не нужна. |
| D3 | **CSRF на refresh — double-submit, но с фиксом TTL** | handoff требует double-submit на весь cookie-flow; TTL `csrf_token` = refresh-TTL (переставляется на refresh), иначе через 24ч → 403. |
| D4 | `get_current_user` — **аддитивно** cookie ∨ Bearer | Не ломает 2100+ тестов и API-клиентов (header в приоритете). |

## 3. Контракт cookie (backend ставит → браузер шлёт автоматически)

| Cookie | HttpOnly | SameSite | Secure | Path | Max-Age | Потребители |
|---|---|---|---|---|---|---|
| `access_token` | ✅ | `lax` | `not DEBUG` | **`/`** ¹ | `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`·60 | REST `get_access_token` + **WS-upgrade (все 3)** |
| `refresh_token` | ✅ | **`strict`** | `not DEBUG` | **`/api/v1/auth/refresh`** ² | `JWT_REFRESH_TOKEN_EXPIRE_DAYS`·86400 | только `POST /auth/refresh` |
| `csrf_token` | ❌ (JS читает) | `strict` | `not DEBUG` | `/` | **= refresh TTL** ³ | JS → заголовок `X-CSRF-Token` |

¹ **Изменение**: сейчас `access_token` path=`/api`. Расширяем до `/`, т.к. WS-эндпоинты висят в корне (`/ws`, `/ws/trading-sessions/{uid}`, `/ws/backtest/{job}`) — с path=`/api` cookie до WS-upgrade **не доедет**. Токен HttpOnly+Secure, расширение path не ослабляет XSS-постуру.
² Узкий path — refresh-токен физически ездит только на свой единственный endpoint. `/logout` его не получает (рвёт сессию по `rjti` из access-payload) но **удаляет** его `delete_cookie` с тем же path.
³ **Изменение**: сейчас `csrf_token` max_age=24ч и ставится только на login. Делаем max_age = refresh-TTL и переставляем на login **и** refresh (устраняет 403 при сессии >24ч).

**Cross-origin в dev** (`:5173→:8000`): same-site (`localhost`, порт SameSite игнорирует) → все cookie доходят на XHR и на WS-upgrade; `Secure=false` при `DEBUG=True` → http работает; `withCredentials:true` (`client.ts`) + `allow_credentials:true` + явный `allow_origins` (`main.py`) — уже настроено. `lax`/`strict` на same-site XHR/WS отдаются.

## 4. Backend

### 4.1 `app/config.py`
- (grace не вводим — новых настроек нет).

### 4.2 `app/auth/router.py`
- Новые хелперы `_set_refresh_token_cookie(response, token)` и `_set_csrf_cookie(response, token)` рядом с `_set_access_token_cookie`; последний — path `/api`→`/`.
- `POST /login`, `POST /setup`, `POST /refresh`: ставят `access_token` + `refresh_token` + `csrf_token` cookie; **в JSON-теле токенов больше нет** (только `token_type`, `expires_in`). `TokenResponse` для body → без `access_token`/`refresh_token` (или отдельная `AuthMetaResponse`); внутренний объект `service._create_token_pair` продолжает возвращать сами токены (их читает cookie-хелпер и login-prefetch — prefetch берёт токен из объекта, не из тела, поэтому переживает).
- `POST /refresh`: читает refresh из cookie `request.cookies["refresh_token"]` (fallback — тело `RefreshRequest`, для тестов/API); тела не требует.
- `POST /logout`: `delete_cookie` для `access_token` (path `/`), `refresh_token` (path `/api/v1/auth/refresh`), `csrf_token` (path `/`). Токен для jti берёт через новый `get_access_token`.
- `PATCH /password`: токен через `get_access_token`.

### 4.3 `app/middleware/auth.py`
- `oauth2_scheme` → `OAuth2PasswordBearer(..., auto_error=False)`.
- Новая зависимость `get_access_token(request, token_hdr=Depends(oauth2_scheme)) -> str`: `token_hdr or request.cookies.get("access_token")`; если оба пусты → `AuthenticationError`. Header в приоритете.
- `get_current_user` использует `get_access_token`. Проверка отозванности jti (RevokedToken) — одинаково для обоих источников.
- Все 3 подтверждённых места `Depends(oauth2_scheme)` (`auth.py:17`, `router.py:164` logout, `router.py:210` change_password) → на `get_access_token`.

### 4.4 `app/middleware/csrf.py`
- `/api/v1/auth/refresh` **убрать** из `EXEMPT_PATHS` (теперь требует X-CSRF-Token; TTL csrf-cookie синхронизирован — см. §3.³). `login`/`setup`/`health` остаются exempt.

### 4.5 grace — НЕ реализуем
- `refresh_token` в `service.py` без изменений семантики: `inserted=True` → пара; `inserted=False` → «Token отозван» (строгая reuse-detection, как в Волне 2). Двух-вкладочную гонку закрывает frontend (§5).

### 4.6 WS — cookie на upgrade (W1), все 3 эндпоинта
- `app/backtest/ws.py` (`/ws`), `app/trading/ws_sessions.py` (`/ws/trading-sessions/{uid}`), `app/backtest/ws_backtest.py` (`/ws/backtest/{job}`):
  - Аутентификация из cookie: `token = websocket.cookies.get("access_token")` → decode → `user_id`; невалидно/нет → `close(4401)` (было `/ws`: query-param + 4001; двух других: handshake-message).
  - **Убрать** ожидание `{action:'auth', token}` и отправку `{type:'auth_ok'}` из `ws_sessions`/`ws_backtest`; `/ws` — убрать чтение `?token=`. После `accept()` эндпоинт работает как раньше (`ws_sessions` шлёт `snapshot` сразу; `/ws` ждёт `subscribe`).
  - **Origin-check** на upgrade (defense-in-depth от CSWSH; SameSite=lax уже не отдаёт cookie на cross-site WS, Origin — второй слой): сверять `websocket.headers["origin"]` с `CORS_ORIGINS`, иначе `close(4403)`.
- per-channel authz (`_authorize_channel`) не меняется — `user_id` теперь из cookie.

### 4.7 `app/middleware/rate_limit.py`
- Добавить `/api/v1/auth/refresh` в категорию `auth` (защита от refresh-шторма при сбое Web Locks).

### 4.8 Общее правило
- Новый auth-код бросает `HTTPException`/`AuthenticationError` (обрабатываются внутри CORS-middleware), **не** голые исключения (иначе generic-500 уйдёт без CORS-заголовков → браузер «Origin not allowed»).

## 5. Frontend

### 5.1 `src/stores/authStore.ts`
- Убрать `token`/`refreshToken` из state и из `persist`; `partialize → { user }`. `AuthState` без токенов.
- `login(user)` — без токенов (cookie уже поставлены backend'ом на `/auth/login`).
- `isAuthenticated = user != null`.
- `logout()`:
  1. `await apiClient.post('/auth/logout')` (interceptor добавит `X-CSRF-Token`; сервер стирает 3 cookie) — best-effort, в try/catch;
  2. `closeWS()`, `abortAllInflight()`, `renewAbortController()`;
  3. `set({ user: null })`; чистка не-секретных кэшей (`clearCandlesCache`, background-backtests, favorites) — как сейчас;
  4. **убрать** `localStorage.removeItem('auth-storage')`-нукинг токена (секрета там больше нет; порча соседней вкладки под Model A растворяется).

### 5.2 `src/api/session.ts` (новый) — единый single-flight refresh
- `refreshSession(): Promise<boolean>` — общий для `client.ts` и `aiStreamClient.ts`.
- Внутри: `navigator.locks.request('auth-refresh', async () => …)` (cross-tab сериализация); внутри лока — bodyless `axios.post(baseURL + '/auth/refresh')` с `X-CSRF-Token` (из cookie); успех → `true` (токен уже в cookie, вызывающему возвращать нечего), провал → `false`.
- In-flight dedupe внутри вкладки (один promise на приложение).
- Fallback без `navigator.locks` (очень старый браузер): просто per-tab single-flight (корректно, слегка избыточно; строгая reuse-detection backend не даст двойной ротации — проигравший получит 401 и уйдёт на re-login в редком случае).

### 5.3 `src/api/client.ts`
- Убрать `Authorization`-хедер и token-guard (нет токена в JS). `withCredentials:true` оставить.
- 401-интерцептор: `if (await refreshSession()) retry(originalRequest) else logout()+redirect('/login')`. Один ретрай (`_retried`). `doRefresh` удалить (уходит в `session.ts`).
- `getCSRFToken()` + `X-CSRF-Token` на мутациях — оставить.

### 5.4 `src/services/aiStreamClient.ts`
- `refreshTokenIfNeeded` → `refreshSession()`; `fetch` без `Authorization` (cookie сам). 401 → `refreshSession()` → повтор или logout.

### 5.5 WS: `src/hooks/wsAuth.ts`, `src/hooks/useWebSocket.ts` (+ хуки backtest/trading WS)
- Убрать `sendAuth`/`{action:'auth'}`/ожидание `auth_ok`. Сокет открывается без токена (cookie на upgrade).
- `onopen` ⇒ уже аутентифицирован (backend `accept()` только после cookie-auth) → `flushSubscriptions` сразу.
- `ws_sessions`/`ws_backtest`-хуки: `snapshot`/данные приходят сразу после open (без auth-шага).
- `onclose 4401/4403` — без reconnect-шторма (guard уже есть; при 4403 Origin — тоже не реконнектить).

### 5.6 `src/pages/LoginPage.tsx`
- `await apiClient.post('/auth/login', {...})` (cookie ставятся) → **без** `resp.data.access_token`; `login({ id, username })` → `await refreshUser()` (`/auth/me` даёт полный профиль) → `navigate('/')`.

### 5.7 Бутстрап на reload (`App`/guard)
- На монтировании (или в guard) `GET /auth/me` под loading-гейтом (как `checking` в LoginPage): 200 → `set user`; 401 → интерцептор сам делает `refreshSession()` → ретрай `/auth/me`; провал → `/login`. Снимает «залогинен по наличию токена в localStorage».
- Гейт предотвращает флэш защищённого контента до проверки. Защита от бесконечного цикла: на `/auth/me` `_retried` даёт максимум один refresh→ретрай.

## 6. Тест-план (test-first; superpowers TDD обязателен для auth)

### 6.1 Backend pytest (Red→Green→Refactor)
- `get_access_token`/`get_current_user`: авторизация по cookie; по Bearer; header в приоритете; оба пусты → 401; отозванный jti → 401 для обоих источников.
- `/auth/login`,`/setup`,`/refresh`: ставят 3 cookie с верными flags/path/TTL; тело без токенов.
- `/auth/refresh`: по cookie без тела → 200; без `X-CSRF-Token` (при наличии csrf-cookie) → 403; reuse (повторный jti) → «Token отозван» (grace нет).
- **Гонка ротации (ver-6)**: два конкурентных `/refresh` одним refresh-jti → ровно один ротирует (atomic `_revoke_jti`), второй → 401 «Token отозван» (frontend single-flight не даёт этому случиться в UI).
- `/auth/logout`: стирает 3 cookie; требует X-CSRF-Token.
- WS (все 3): upgrade с валидной cookie → accept; без cookie → 4401; чужой Origin → 4403; per-channel authz по user_id из cookie.

### 6.2 Frontend vitest
- `session.ts`: N параллельных 401 → **один** `POST /auth/refresh` (мок `navigator.locks`); cross-tab лок; провал → `false`.
- `authStore`: `partialize` не сохраняет токены; `logout()` зовёт backend + не нукает соседнюю вкладку.
- `client.ts` interceptor: 401 → refresh → ретрай; повторный 401 → logout+redirect.

### 6.3 Playwright (реальный браузер, cookie-flow)
- login → работа → logout (cookie появляются/исчезают).
- Тихий refresh при истёкшем access (без разлогина).
- **Сценарий ДВУХ вкладок**: обе живут через ротацию (ни одну не разлогинивает).
- reload сохраняет сессию через cookie-бутстрап `/auth/me`.
- WS: график/сессии/бэктест-прогресс получают данные (cookie-auth на upgrade).

### 6.4 Гейт
`pytest` (полный) + `pnpm test` (vitest) + `tsc --noEmit 0` + pyright 0 + Playwright зелёные → `/code-review` по auth (backend) и api/stores (frontend) → фиксы test-first → повторный гейт.

## 7. Известные ограничения / вне скоупа

- **Сеть теряет ответ refresh** (сервер ротировал, cookie до браузера не дошёл) → следующий refresh предъявит старый cookie → «Token отозван» → один вынужденный re-login. Редкий кейс (решался бы grace, D2 — сознательно отказались). → backlog `P1-AUTH-NET-LOSS-RELOGIN` (низкий).
- Family-revocation при смене пароля (полная инвалидация всех устройств) — прежнее ограничение без `token_version` (не в скоупе, отдельный NEEDS-REVIEW).
- WS-редизайн закрывает и `P1W3-WS-AUTH-CONSOLIDATE` (рассогласование `/ws`) как побочный эффект.

## 8. Порядок реализации (для writing-plans)

Backend и frontend неразделимы, но внутри ветки допустимы промежуточные коммиты (мерж в `s8r/bug-31` — только после полного зелёного гейта).
1. Backend: cookie-контракт (§4.2–4.4) + `get_access_token` (§4.3) + CSRF (§4.4) + rate-limit (§4.7) — test-first.
2. Backend: WS cookie-auth все 3 эндпоинта (§4.6) — test-first.
3. Frontend: `session.ts` single-flight (§5.2) + `client.ts`/`aiStreamClient.ts` (§5.3–5.4) — vitest.
4. Frontend: `authStore`/logout (§5.1) + LoginPage/bootstrap (§5.6–5.7) — vitest.
5. Frontend: WS хуки (§5.5) — vitest.
6. Playwright (§6.3) + гейт (§6.4) + `/code-review` + фиксы.
7. Доки: `P1_AUTH_HARDENING_LOG.md`, обновить `project_state.md`. Push в `p1/auth-hardening` (обе репо — ветки спросить отдельно; remote `s8r/bug-31` не трогать).

## 9. Файлы под изменение (карта)

**Backend:** `auth/router.py`, `auth/schemas.py` (body без токенов), `middleware/auth.py`, `middleware/csrf.py`, `middleware/rate_limit.py`, `backtest/ws.py`, `trading/ws_sessions.py`, `backtest/ws_backtest.py`; тесты `tests/test_auth/*`, `tests/test_*ws*`.
**Frontend:** `stores/authStore.ts`, `api/client.ts`, `api/session.ts` (new), `services/aiStreamClient.ts`, `hooks/wsAuth.ts`, `hooks/useWebSocket.ts` (+ backtest/trading WS-хуки), `pages/LoginPage.tsx`, `App.tsx`/guard; тесты `__tests__/*`, `e2e/*`.
