---
sprint: 7
agent: DEV-2 (BACK2)
wave: W2 fix-wave
date: 2026-04-26
---

# DEV-2 BACK2 W2 fix-волна — отчёт

## 1. Реализовано

- **Задача 1 (C6 URL-fix).** Wizard-endpoint перенесён из `/api/v1/auth/me/wizard/complete`
  в новый модуль `app/users/` под путём `POST /api/v1/users/me/wizard/complete`
  (контракт C6). Без deprecated alias'а в auth (заказчик потребовал чистоты).
  Дополнительно — прокси `GET /api/v1/users/me` (тот же `UserResponse`,
  что и `/auth/me`), чтобы фронт мог мигрировать постепенно.
- **Задача 2 (chart_drawings backend mini-CRUD).** Новый модуль `app/chart_drawings/`
  c 5 endpoint'ами (контракт совпадает с `Develop/frontend/src/api/chartDrawingsApi.ts`):
  `GET/POST /charts/{ticker}/{tf}/drawings`, `PATCH/DELETE /charts/drawings/{id}`,
  `DELETE /charts/{ticker}/{tf}/drawings`. Модель `ChartDrawing` переиспользована
  из `app/common/models.py` — таблица создана ещё в initial-миграции
  `3d3e4e3036a6`, новой миграции **не требуется**.

## 2. Файлы

NEW:
- `Develop/backend/app/users/{__init__.py, router.py, schemas.py}`
- `Develop/backend/app/chart_drawings/{__init__.py, router.py, schemas.py}`
- `Develop/backend/tests/unit/test_users/{__init__.py, test_wizard.py}` (5 тестов)
- `Develop/backend/tests/unit/test_chart_drawings/{__init__.py, test_chart_drawings_crud.py}` (11 тестов)

MOD:
- `Develop/backend/app/main.py` — +`users_router`/`chart_drawings_router`.
- `Develop/backend/app/auth/router.py` — удалены endpoint и импорт `WizardCompleteResponse`.
- `Develop/backend/app/auth/schemas.py` — `WizardCompleteResponse` удалён (вынесен).

DEL:
- `Develop/backend/tests/unit/test_auth/test_wizard.py` (переехал в `test_users/`).

## 3. Тесты

- `pytest tests/unit/test_users/ -v` → **5/5 passed**: `users/me` proxy, set/idempotent wizard,
  401 без токена, **legacy `/auth/me/wizard/complete` → 404** (подтверждение чистоты).
- `pytest tests/unit/test_chart_drawings/ -v` → **11/11 passed**:
  full CRUD lifecycle, ownership PATCH/DELETE → 404, delete-nonexistent → 404,
  валидация (hline без price / trendline без p2 / unknown type), bulk-list
  filter по (ticker, tf) с изоляцией от чужого user, clear-all не трогает
  другого user, 401 без токена.
- **Полный backend pytest:** `pytest tests/ -q` → **885 passed / 0 failed** (86 s).
  Baseline после OPS-волны 867 passed → +18 моих за день (5 wizard + 11 chart_drawings + 2 OPS PDF positive).
- **Lint:** `ruff check app/users app/chart_drawings app/auth app/main.py` → All checks passed.
- **py_compile:** все изменённые `.py` компилируются без ошибок.

## 4. Integration points

- `grep -rn "users/me/wizard/complete" Develop/backend/` → присутствует в `app/users/router.py:4,40`,
  `app/main.py:224`, `app/users/__init__.py:4`, `app/users/schemas.py:14`,
  `tests/unit/test_users/test_wizard.py:74,79,97,107,111`. Auth-роутер — только комментарий.
- `grep -rn "chart_drawings" app/` → `app/main.py:49-50,228`, `app/chart_drawings/{router,schemas,__init__}.py`,
  `app/common/models.py:55` (модель). Production-точки = есть.
- `grep -rn "from app.users\|from app.chart_drawings" app/` → `app/main.py:48,50`,
  `app/chart_drawings/router.py:29`, `app/users/router.py:24`. Импорты подключены.

## 5. Контракты

| # | Артефакт | Поставщик/потребитель | Статус |
|---|----------|-----------------------|--------|
| **C6** (URL-fix) | `POST /api/v1/users/me/wizard/complete` + `GET /api/v1/users/me` | BACK2 → FRONT2 (wizard sub-wave 2) | ✅ финализировано |
| **drawing_tools** | 5 endpoint'ов под `/api/v1/charts/...` | BACK2 → FRONT1 (live backend вместо localStorage) | ✅ опубликовано |

Frontend `chartDrawingsApi.ts` совпадает 1:1 (id: string, type union, DrawingPayload, DrawingStyle).
**Schema drift vs промпт:** промпт указывал префикс `/api/v1/chart_drawings`, но frontend api
уже использует `/api/v1/charts/{ticker}/{tf}/drawings`. Выбор `/api/v1/charts` сделан, чтобы
не править frontend и не создать второй контракт-источник.

## 6. Проблемы и решения

- **Тесты setup_user падали с KeyError 'access_token'** при `username="u1"/"u2"` —
  `RegisterRequest` требует `min_length=3`. Исправлено на `user_alpha/user_beta`.
  Записал в self-debrief: всегда сверяться со схемой `RegisterRequest` в новых тестах.
- **Префикс `/api/v1/chart_drawings` vs `/api/v1/charts`** — выбран frontend-контракт
  как source of truth. Решение: один контракт, нет дублирования.
- **Модель `ChartDrawing` уже существует** в `app/common/models.py` (initial-миграция
  S0). Новой alembic-миграции НЕ создавал — иначе drift и риск конфликта индексов.

## 7. Применённые Stack Gotchas

- **#20 (FastAPI route ordering):** в `app/chart_drawings/router.py` статические маршруты
  `PATCH/DELETE /drawings/{id}` объявлены **выше** динамических `GET/POST /{ticker}/{tf}/drawings`.
  Если перепутать порядок — FastAPI матчит `drawings` как `ticker` (422 Unprocessable Entity на int-ID).
  Все 11 тестов это подтверждают.
- **#11/#12 (Alembic drift / SQLite batch_alter):** не сработали — новой миграции в этой fix-волне
  нет (модель и таблица уже существуют в initial schema).

## 8. Новые Stack Gotchas

Не выявлено. Все встреченные проблемы укладываются в gotcha-20 (route ordering).
Кандидат на формализацию: «Pydantic `RegisterRequest.min_length=3` — username в тестах
должен быть ≥3 символов» — но это локальная схема, не stack-level. В каталог НЕ добавлял.
