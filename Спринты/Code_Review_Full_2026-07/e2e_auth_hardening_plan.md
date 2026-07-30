# E2E-план: P1 Auth-hardening (Model A cookie-flow)

> Составлен ДО написания тестов (правило проекта E2E: план → инфра → фикстуры → тесты → запуск → верификация).
> Источник сценариев: `P1_AUTH_HARDENING_DESIGN.md` §6.3 + §3 (контракт cookie) + `ui_checklist`.
> Ветка: `p1/auth-hardening` (worktree `.claude/worktrees/auth-hardening`), база `fe56162`.
> Спецификация теста: `Develop/frontend/e2e/auth-hardening.spec.ts`.

## Что проверяем (суть волны)

Оба JWT (access+refresh) уехали в **HttpOnly+Secure cookie** — JS их не видит (Model A).
Refresh — единый cross-tab single-flight (`navigator.locks`). WS аутентифицируется cookie
на upgrade + `auth_ok` первым кадром. E2E — финальная проверка в **реальном браузере**
(cookie-flow нельзя надёжно мокать), поверх unit/integration + `/code-review`.

## Инфраструктура

- **Playwright** `@playwright/test` (см. `frontend/playwright.config.ts`, baseURL `http://localhost:5173`,
  chromium, workers=1, timeout 30s).
- **Реальные серверы из worktree** (cookie-flow):
  - backend: `cd worktree/backend && DATABASE_URL=sqlite+aiosqlite:///./data/e2e_auth.db DEBUG=true
    CORS_ORIGINS=http://localhost:5173 <venv>/python -m uvicorn app.main:app --port 8000`
  - frontend: `cd worktree/frontend && pnpm dev --port 5173` (дефолт API/WS → :8000).
  - `webServer.reuseExistingServer=true` → Playwright переиспользует уже поднятые серверы.
- **Изолированная тест-БД** `data/e2e_auth.db`:
  - схема — `Base.metadata.create_all` из моделей worktree (alembic-миграции имеют дрейф
    `strategies.description`, поэтому схему строим из моделей, как conftest тестов);
  - `DEBUG=true` → cookie `Secure=false` (доезжают по http на localhost);
  - тест-юзер создаётся через `POST /auth/setup` (пароль sergopipo НЕ нужен — заказчик
    разрешил путь «БД пустая → /setup»); `wizard_completed_at` выставлен, чтобы модалка
    FirstRunWizard не перекрывала UI.
- **Тест-юзер (real backend):** `e2e_auth` / `E2ePassw0rd!` (см. `E2E_REAL_USER` в `api_mocks.ts`).

## Контракт cookie (проверяемый, DESIGN §3)

| Cookie | HttpOnly | SameSite | Path | Потребитель |
|---|---|---|---|---|
| `access_token` | ✅ | lax | `/` | REST + WS-upgrade (3 эндпоинта) |
| `refresh_token` | ✅ | strict | `/api/v1/auth/refresh` | только `POST /auth/refresh` |
| `csrf_token` | ❌ (JS) | strict | `/` | JS → заголовок `X-CSRF-Token` |

## Фикстуры под Model A (что починено ПЕРЕД прогоном)

Под Model A токенов в `localStorage` нет; старый автологин (инъекция `auth-storage` с токеном)
+ старт без бутстрапа `/auth/me` сломались. Исправлено:

- `e2e/fixtures/api_mocks.ts`:
  - `FAKE_AUTH_STATE` → только `{ user }` (как `authStore.partialize`), без `token/refreshToken`.
  - `injectFakeAuth` дополнительно мокает `/auth/me` (+ refresh/logout/setup-status): под Model A
    `useAuthBootstrap` ОБЯЗАТЕЛЬНО зовёт `GET /auth/me` под loading-гейтом — иначе 401→refresh→logout.
  - `mockAuthEndpoints`: добавлен `/auth/me` (профиль), `/auth/logout` (204); тело login/refresh
    приведено к Model A (без токенов).
  - Новые хелперы для real-backend: `E2E_REAL_USER`, `realLogin(page)` (реальный `POST /auth/login`
    через `page.request` — cookie ставятся в контекст; localStorage-инъекция аутентификации НЕ даёт).
- `e2e/s7r-chart-drawings-fix.spec.ts`: `loginViaScript` → `realLogin` (был `execSync playwright_login.sh`
  + инъекция токенов; под Model A сломан).
- `scripts/playwright_login.sh`: успех логина по `Set-Cookie access_token` (а не по токену в теле);
  печатает Model-A `{user}`-стейт.

## Сценарии

### A. Login → cookies → работа → logout → cookies исчезли
- **Предусловие:** чистый контекст (нет cookie), тест-юзер существует.
- **Шаги:** goto `/login` → заполнить «Имя пользователя»/«Пароль» → «Войти».
- **Ожидание:**
  - редирект НЕ на `/login` (дашборд);
  - `context.cookies()` содержит `access_token` (`httpOnly=true`), `refresh_token` (`httpOnly=true`),
    `csrf_token` (`httpOnly=false`);
  - `GET /auth/me` (через контекст) → 200 (сессия рабочая);
  - logout (меню в Header → «Выйти») → URL `/login`;
  - `access_token`/`refresh_token`/`csrf_token` в `context.cookies()` **исчезли**.

### B. Тихий refresh при истёкшем/отсутствующем access (без разлогина)
- **Предусловие:** залогинен (cookie стоят).
- **Шаги:** удалить ТОЛЬКО `access_token` cookie (симуляция истечения), оставить `refresh_token`+`csrf_token`
  → `page.reload()` (бутстрап `/auth/me` даст 401 → interceptor `refreshSession()`).
- **Ожидание:** пользователь НЕ на `/login` (остался залогинен); появился НОВЫЙ `access_token` cookie;
  зафиксирован `POST /auth/refresh` (200).

### C. ДВЕ ВКЛАДКИ (ключевой сценарий P1W2-REFRESH-GRACE)
- **Предусловие:** залогинен; две страницы (`page1`,`page2`) одного контекста (общий cookie-jar + Web Locks).
- **Шаги:** удалить `access_token` cookie (общий) → одновременно `Promise.all([page1.reload(), page2.reload()])`.
- **Ожидание:** НИ ОДНУ вкладку не выкинуло на `/login` (обе остались на дашборде); `POST /auth/refresh`
  прошёл без ошибки (single-flight на `navigator.locks` сериализует — проигравшая вкладка предъявляет
  уже ротированный cookie и выживает). Обе вкладки далее делают успешный `GET /auth/me`.

### D. Reload сохраняет сессию (cookie-бутстрап `/auth/me`)
- **Предусловие:** залогинен.
- **Шаги:** `page.reload()` (F5).
- **Ожидание:** остаёшься залогинен (URL не `/login`), `GET /auth/me` → 200, дашборд виден.

### E. WS: cookie-auth на upgrade + `auth_ok`
- **E1 (позитив, /ws мультиплексор):** залогинен → в контексте страницы открыть
  `new WebSocket('ws://localhost:8000/ws')` → первый кадр `{"type":"auth_ok"}` (cookie ушла на upgrade).
- **E2 (негатив):** свежий контекст без cookie → тот же WS → закрытие с кодом `4401`.
- **E3 (data-канал, /ws/trading-sessions/{uid}):** залогинен → открыть
  `ws://localhost:8000/ws/trading-sessions/1` → `auth_ok` первым кадром, затем `snapshot` (данные приходят).

## Регрессия под Model A

Существующий mock-suite (`injectFakeAuth` + `page.route`) прогоняется в CI-режиме (`CI=1`):
vite-only webServer, real-backend спеки (`test.skip(!!process.env.CI)`) пропускаются, всё остальное
работает на моках. Цель — Model A не сломал автологин/бутстрап (см. фикс `injectFakeAuth`).

## Критерий приёмки

`npx playwright test auth-hardening.spec.ts` — все сценарии A–E **passed** (реальный прогон, не только
написаны). Регрессия mock-suite — passed/failed числа в `P1_AUTH_HARDENING_LOG.md`; падения не из-за
Model A (seed-зависимые real-backend спеки) помечаются отдельно.
