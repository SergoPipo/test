## DEV-AUDIT-055 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. Единый модуль `src/api/baseUrl.ts`: `getApiBaseUrl()` → `/api/v1`, `getWsBase(loc=window.location)` → `wss://host` при `https:`, иначе `ws://host:port`; `VITE_API_BASE_URL`/`VITE_WS_URL` — только override, читаются при вызове.
2. Все 8 fallback'ов переведены на модуль: `client.ts`, `session.ts`, `adminLinks.ts` (не были в карточке, но входят в гейт «grep = 0»), `aiStreamClient.ts`, `wsAuth.ts` (реэкспорт — `useWebSocket.ts`/`backtestStore.ts` не тронуты), `useTradingSessionsWS.ts`, `useBacktestJobWS.ts` ×2. `grep localhost:8000 frontend/src` (без тестов) = 0.
3. `vite.config.ts`: dev-proxy отсутствовал вовсе — добавлен минимально (`/api` → :8000, `/ws` → `ws: true`). Без него относительные дефолты в dev не работают. `Origin` не переписывается → `ws_origin_allowed` видит `http://localhost:5173` из дефолтного `CORS_ORIGINS`; cookie host-scoped (порт не важен) — стенд `start.sh` и E2E на :5173/:8000 работают без `VITE_*`.
4. `frontend/Dockerfile`: `ARG VITE_API_BASE_URL=/api/v1` + `ENV`.
5. `check_production_env.sh`: `check_cors_origins` — при `DEBUG` ≠ true пустой `CORS_ORIGINS` → FATAL (exit 1); только localhost → WARNING (local-only сценарий §5.5 легитимен).
6. CI: шаг «Smoke — бандл без localhost:8000» после `pnpm build` (с проверкой, что glob не пуст).
7. E2E-моки проверены: `page.route('**/api/v1/…')`, `routeWebSocket('**/ws/…')` — глобы, с относительными URL совместимы; `auth-hardening` бьёт в :8000 напрямую (`PW_API_URL`), от бандла не зависит.

### 2. Файлы
Новые: `frontend/src/api/baseUrl.ts`, `frontend/src/api/__tests__/baseUrl.test.ts`.
Изменённые: `frontend/src/api/{client,session}.ts`, `hooks/{wsAuth,useTradingSessionsWS,useBacktestJobWS}.ts`, `pages/admin/adminLinks.ts`, `services/aiStreamClient.ts`, `__tests__/audit_s8r_baseurl.test.ts`, `frontend/vite.config.ts`, `frontend/Dockerfile`, `scripts/check_production_env.sh`, `.github/workflows/ci.yml`, `backend/tests/unit/test_config.py`.

### 3. Тесты
RED: `AssertionError: expected 'ws://localhost:8000' not to contain 'localhost:8000'`; `expected 'http://localhost:8000/api/v1' to be '/api/v1'`; `Failed to resolve import "../baseUrl"`; backend `AssertionError: assert 'CORS_ORIGINS' in ''` (4 failed) → GREEN: 8 vitest (2 файла) + 14 preflight.
Мутация: `'/api/v1'` → `'http://localhost:8000/api/v1'` в `baseUrl.ts` → `AssertionError: expected 'http://localhost:8000/api/v1' to be '/api/v1'`, откачена.
Гейты: pytest 2800 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok, `grep -c localhost:8000 dist/assets/*.js` = 0 (36 файлов); vitest 934 passed.

### 4. Integration points
✅ `getApiBaseUrl()` — `client.ts:8`, `session.ts:5`, `adminLinks.ts:19`, `aiStreamClient.ts:31`; `getWsBase()` — `useTradingSessionsWS.ts:173`, `useBacktestJobWS.ts:120,312`, через `wsAuth` — `useWebSocket.ts:28`, `backtestStore.ts:159`. `check_cors_origins` вызывается в скрипте; скрипт — в `docker-compose.yml command`.

### 5. Контракты
API/схемы/миграций нет.

### 6. Проблемы / предлагаемые правки
- Гайд §3.2, таблица: строка `| CORS_ORIGINS | Публичный origin SPA (Origin браузера за Tunnel), через запятую; проверяется preflight'ом: пусто → контейнер не стартует, только localhost → предупреждение (S8R-AUDIT-055) | https://moex.example.com (+ http://localhost для local-only §5.5) |`.
- Гайд §3.3 после «Проверка эндпоинтов»: «SPA собирается с относительными `/api/v1` и `wss://<host>`; `VITE_*` задавать не нужно (`frontend/Dockerfile` ARG — только для нестандартной раскладки)».
- ТЗ §8.10 «Безопасность»: добавить «`CORS_ORIGINS` обязан содержать публичный origin — `ws_origin_allowed` иначе отбивает WS (403)».
- Новая находка: `.env.example` не читал (permission); проверить, есть ли там `CORS_ORIGINS` с пояснением.
- Стенды на нестандартных портах (gotcha-46) — через `VITE_API_BASE_URL`/`VITE_WS_URL` (proxy целится в :8000).

### 7. Применённые Stack Gotchas
46 (Origin ↔ CORS_ORIGINS, WS 403), 52, 60 (`tsc -b`), 25.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
context7 (Vite `server.proxy`, `ws: true`, `rewriteWsOrigin` не использовать), `mattpocock-skills:tdd`, typecheck `tsc -b` после правок, `sh -n` для скрипта; pyright не нужен (Python-код не менялся, только тесты — прогон pytest).
