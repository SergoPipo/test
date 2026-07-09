# Лог P1 — Auth-hardening мини-волна (backend+frontend, Model A)

**Дата:** 2026-07-08 … 2026-07-09
**Ветка:** `p1/auth-hardening` (Develop, worktree `.claude/worktrees/auth-hardening`), база `0e039be` (итог Волны 3, `p1/wave3-frontend`). Remote `s8r/bug-31` НЕ тронут. Ничего не запушено.
**Модель:** Opus 4.8 (implementer/reviewer субагенты), оркестрация — subagent-driven-development. Строго test-first (Red→Green) для auth.
**Метод:** brainstorm → независимое ревью дизайна (с верификацией по коду) → spec (`P1_AUTH_HARDENING_DESIGN.md`) → план (`P1_AUTH_HARDENING_PLAN.md`, 18 тасков) → per-task implementer+reviewer → per-phase `/code-review` → финальное whole-branch ревью.

## Что решено (CFG-FE-01 + P1W2-REFRESH-GRACE)

- **CFG-FE-01:** оба JWT (access+refresh) уехали из `localStorage` в **HttpOnly + Secure cookie** — JS их не видит (Model A). XSS больше не может выгрузить ни access, ни refresh.
- **P1W2-REFRESH-GRACE:** устранён принудительный разлогин при двух вкладках / активном AI-чате — через **единый cross-tab single-flight refresh** (`navigator.locks`) вместо двух независимых refresh-клиентов; проигравшая вкладка предъявляет уже ротированный cookie и не разлогинивается. **Grace-окно сознательно НЕ вводилось** (решение по итогам независимого ревью: под Model A refresh-cookie один на браузер + single-flight закрывают гонку; grace ослаблял бы reuse-detection и требовал fragile read-back `revoked_at`).
- **Побочно закрыт `P1W3-WS-AUTH-CONSOLIDATE`:** рассогласование мультиплексного `/ws` (фронт ждал `auth_ok`, backend читал `?token=`) устранено — все WS на cookie-auth + `auth_ok`.

## Реализовано (18 тасков → 17 коммитов)

### Backend (Tasks 1–8)
| Область | Суть |
|---|---|
| `middleware/auth.py` | `oauth2_scheme(auto_error=False)` + `get_access_token(request, token_hdr)` — Bearer ∨ cookie `access_token` (Bearer в приоритете для тестов/API); `get_current_user`, `logout`, `change_password` переведены на неё. |
| `auth/router.py` | `_set_refresh_token_cookie` / `_set_csrf_cookie` + `_auth_cookie_response`; `login`/`setup`/`refresh` ставят 3 cookie, тело — `AuthMetaResponse{token_type, expires_in}` без токенов; `refresh` читает refresh из cookie (fallback тело); `logout` стирает 3 cookie. access-cookie path `/api`→`/`. |
| `auth/schemas.py` | `AuthMetaResponse`; удалён мёртвый `RefreshRequest`. |
| `middleware/csrf.py` | `/api/v1/auth/refresh` убран из `EXEMPT_PATHS` → требует `X-CSRF-Token` (double-submit). |
| `middleware/rate_limit.py` | `/api/v1/auth/refresh` → категория `auth`. |
| `common/ws_auth.py` (new) | `ws_authenticate` (cookie `access_token`→user_id, требует `type=access`), `ws_origin_allowed` (Origin ∈ CORS_ORIGINS, defense-in-depth от CSWSH). |
| `backtest/ws.py`, `trading/ws_sessions.py`, `backtest/ws_backtest.py` | WS-auth из cookie на upgrade (ДО `accept`), close 4401/4403, `{"type":"auth_ok"}` первым кадром; удалён handshake `{action:auth}` / `_decode_token` / query-param `?token=`. |

### Frontend (Tasks 9–15)
| Область | Суть |
|---|---|
| `api/session.ts` (new) | `refreshSession(): Promise<boolean>` — единый на приложение: per-tab in-flight dedupe + cross-tab `navigator.locks('auth-refresh')` + bodyless `POST /auth/refresh` + `X-CSRF-Token` из cookie. defensive try/catch → `false`. |
| `api/client.ts` | убраны чтение `token`/`Authorization`/token-guard/`doRefresh`; 401 → `refreshSession()` → один ретрай → иначе logout+`/login`; guard: 401 от `/auth/logout`\|`/auth/refresh` не ре-входит в каскад. |
| `services/aiStreamClient.ts` | `refreshSession` + `credentials:'include'`, без `Authorization`. |
| `stores/authStore.ts` | убраны `token`/`refreshToken`/`setToken`; `login(user)`; `isAuthenticated=user!=null`; `logout()` async → `POST /auth/logout` (сервер стирает cookie) → чистит `user`, без нукинга `auth-storage`; `partialize {user}`. |
| `pages/LoginPage.tsx`, `pages/SetupPage.tsx` | bodyless login → `login({id,username})` → `refreshUser()` (/auth/me). |
| `hooks/useAuthBootstrap.ts` (new) + `App.tsx` | на reload `GET /auth/me` под loading-гейтом (spinner до `booted`) — снимает «залогинен по токену в localStorage», без флэша защищённого контента. |
| WS-хуки (`useWebSocket`, `useTradingSessionsWS`, `useBacktestJobWS`, `wsAuth`, `backtestStore`) | не шлют `{action:auth}` (auth по cookie на upgrade), guard по `user`, ожидание `auth_ok` сохранено; `e2e/fixtures/api_mocks.ts` шлёт `auth_ok` сам. |
| `api/types.ts` | удалены мёртвые `TokenResponse.access_token/refresh_token`. |

## Верификация (гейт)

- **Backend pytest** (весь сук): **2170 passed, 2 xfailed, 0 failed** (base 2162 → +8 auth/WS-тестов).
- **Frontend:** `tsc --noEmit` **0 errors**; **vitest 761 passed / 0 failed**.
- **pyright** (изменённые prod-файлы): 0 новых ошибок (2 предсуществующие baseline в `ws_sessions.py` main-loop `message.get`, не введены волной).

## `/code-review`

- **Backend (auth/WS):** вердикт **MINOR-ONLY** — реальных дефектов корректности/безопасности нет. Проверены auth-bypass, CSRF, cookie-флаги/paths/TTL, WS ownership/Origin, refresh cookie-priority + reuse-detection. Actionable: удалён мёртвый `RefreshRequest`.
- **Frontend (api/stores/hooks):** вердикт **MINOR-ONLY** — 3 фикса (commit `b393f6d`): (1) 401-интерцептор не ре-входит в refresh/logout (ограниченный каскад при истёкшей сессии); (2) defensive try/catch в `session.ts` (reject `navigator.locks` → `false`); (3) cleanup мёртвого типа.
- **Финальное whole-branch ревью:** **READY-TO-MERGE** — cross-cutting контракт backend↔frontend согласован по 7 пунктам (имена cookie, `X-CSRF-Token`, refresh path↔URL, 401-каскад без рекурсии, `auth_ok` на 3 эндпоинтах ↔ 5 консьюмеров, access path=/ ↔ корневые WS, тело без токенов). Один MINOR — устаревший docstring — исправлен (`fe56162`).

## Осталось / backlog

- **Playwright E2E** (login/refresh/logout/**2 вкладки**/WS) — вынесено отдельным шагом (нужны живые backend+frontend серверы; по правилу E2E проекта: план→запуск→верификация). Volume unit/integration + `/code-review` покрывает контракт; E2E — финальная проверка в реальном браузере.
- **P1-AUTH-NET-LOSS-RELOGIN** (низкий): при потере ответа refresh (сервер ротировал, cookie до браузера не дошёл) — один вынужденный re-login. Grace-окно сознательно не вводилось (см. выше).
- **P1W3-MULTIPLEX-WS-REFRESH** (низкий): при живом persisted `user` и мёртвой access-cookie WS-upgrade рвётся браузером как close `1006` (не 4401), guard `event.code===4401/4403` его не ловит → reconnect ограничен backoff'ом ≤30с до следующего login/refresh.
- **WS не проверяет RevokedToken** (низкий, не регресс): отозванный (logout/смена пароля) access-JWT открывает WS до естественного истечения ≤`JWT_ACCESS_TOKEN_EXPIRE_MINUTES`. Прежнее поведение (старый handshake тоже не смотрел на revoked). HTTP-путь revoked-jti проверяет.
- **rate-limit `/auth/refresh` = per-IP категория `auth`** (5/мин, делит с login): за прокси без проброса реального IP — общий бакет; при баге в single-flight lock возможен упор в лимит. By-design.
- **Топологическое требование деплоя:** double-submit CSRF + SameSite предполагают **same-site** фронт/бэк (за nginx — same-origin). Cross-site деплой сломал бы refresh/CSRF. Зафиксировано в `P1_AUTH_HARDENING_DESIGN.md`.
- **Закрыто попутно:** `P1W3-WS-AUTH-CONSOLIDATE`.

## Коммиты ветки (0e039be..fe56162, 17)

`54a28be` get_access_token · `e2819a5` logout/change_password cookie · `12870c5`+`f11433f` login/setup/refresh cookie + pyright-фикс · `aad1869` refresh из cookie + CSRF · `3ee18d1` logout 3 cookie + rate-limit · `a7e4a7d` WS cookie-auth (sessions/backtest) · `f30614d` /ws cookie-auth · `b48d881` cleanup RefreshRequest · `161047e` session.ts · `db8876d` client.ts · `9359d37` aiStreamClient · `50c814f` WS-хуки · `39c3e34` authStore+LoginPage · `a67cbb8` bootstrap · `b393f6d` frontend review-фиксы · `fe56162` docstring.

## Как продолжить (Playwright + push)

- **Playwright:** worktree готов (`.env` + `pnpm install`). Поднять backend (`uvicorn`) + frontend (`vite`) на портах из `.env`, написать/прогнать E2E по `e2e_test_plan` (login→работа→logout; тихий refresh; 2 вкладки; reload через cookie-бутстрап; WS-данные). Результат — сюда.
- **Push:** `p1/auth-hardening` (Develop) + доковая ветка (Test) — по подтверждению заказчика, ветки для обоих репо отдельно. remote `s8r/bug-31` не трогать.
- **После Волны 3 + этой волны:** финальное сведение всех `p1/wave*` + `p1/auth-hardening` в `s8r/bug-31` одним PR с финальным ревью.
