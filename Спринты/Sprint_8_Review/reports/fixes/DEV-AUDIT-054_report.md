## DEV-AUDIT-054 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `/api/v1/health` стал readiness: `ok`/200 только если `database == "connected"` и `scheduler_running`, иначе `degraded`/503 с тем же полным телом.
- Новый `/api/v1/health/live` для liveness: всегда 200 `{"status":"ok"}`.
- `tinvest_connected` теперь считается по `_stream_task is not None and not done()` (gotcha-34), а не по флагу `connected`. На статус он не влияет.
- `version` берётся из `app.__version__` (метаданные пакета из pyproject), им же заполняется OpenAPI `version`.
- `cb_state` не менялся.
- В `Dockerfile.backend` `--start-period` поднят с 30 до 60 с, как в compose. Healthcheck в compose уже смотрит на readiness, добавлен только комментарий.

### 2. Файлы
Изменены: `backend/app/main.py`, `backend/app/__init__.py`, `backend/tests/unit/test_health.py`, `backend/tests/unit/test_audit_s8r_health_and_sizing.py` (снят xfail, обновлён докстринг), `Dockerfile.backend`, `docker-compose.yml`.

### 3. Тесты
- RED: `AssertionError: (200, '{"status":"ok",…"database":"disconnected",…}')` / `assert 200 == 503`; `/health/live` → `assert 404 == 200`; tinvest → `assert False is True`.
- GREEN: 15 passed (`test_health.py` + доказательный файл).
- Мутация `ready = True` → 4 failed (`assert 200 == 503`). Откат через бэкап, md5 сошёлся.
- Гейты: pytest **3631 passed / 4 xfailed / 0 failed**; ruff 0; mypy Success (188); bandit 0 issues; typecheck 0; lint 0; build ok.
- vitest: фронт не менялся, прогон на уровне пакета.

### 4. Integration points
✅ `app/main.py:449` (`/health/live`), `:459` (`/health`), `:10/363/546` (`APP_VERSION`); compose и Dockerfile указывают на `/api/v1/health`.

### 5. Контракты
Добавлен эндпоинт `GET /api/v1/health/live`. Поле `status` теперь `ok|degraded`, код ответа 200 или 503. Миграций нет.

### 6. Проблемы / правки документов / находки
- **Гайд §8.1** — заменить JSON на:
  ```json
  {"status":"ok","version":"0.1.0","database":"connected","cb_state":"ok","tinvest_connected":true,"scheduler_running":true,"scheduler_jobs":6}
  ```
  Абзац под ним: «`status`: `ok` (200) или `degraded` (**503**, если БД недоступна или планировщик остановлен); тело при 503 то же. `tinvest_connected` на статус не влияет. Liveness: `GET /api/v1/health/live` → 200 всегда. Healthcheck контейнера — readiness; `restart: unless-stopped` не перезапускает unhealthy-контейнер (только вышедший процесс), при unhealthy backend frontend не поднимется». В строке 113 гайда `"cb_state":"closed"` заменить на `"ok"`. Число `scheduler_jobs` указано примерно.
- **ТЗ §8.5**: добавить пункт «503 `degraded` при БД или планировщике; `/health/live` — liveness». §4.10 описывает контракт, которого нет, — нужна отдельная сверка.
- **Находка (фронт)**: при 503 axios бросает, и `HealthWidget` показывает «Состояние систем недоступно» вместо красного Scheduler. Предложение: в `catch` брать `e.response.data`. Это вне рецепта.
- **Находка**: у `SELECT 1` нет таймаута в 5 с, хотя его требует ТЗ §8.5.
- Самопроверка: 1 — записей в БД нет; 2 — уведомлений нет; 3 — тест идёт через ASGI и реальный `health_check`; 4 — новых таймаутов нет; 5 — из тестов `/health` вызывают security headers и CORS, код ответа они не проверяют, прогон зелёный; 6 — клиентского ввода нет.
- E2E-стенд: lifespan запускает планировщик до приёма HTTP, поэтому при здоровом стенде будет 200.

### 7. Применённые Stack Gotchas
34 (живость задачи, а не `connected`), 30 (патч `app.main.get_db` в месте вызова).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile ok; typecheck (`tsc -b`) 0; context7 не нужен (внешних API не добавлялось, `importlib.metadata` из stdlib); tdd-скилл использован.

### Дополнение (приёмка оркестратора): HealthWidget при 503
- `frontend/src/components/dashboard/HealthWidget.tsx`: `degradedBody(e)` проверяет ошибку duck-typing'ом, как в `utils/apiError.ts`. Если `response.status === 503` и тело — объект с `status: "degraded"`, тело рендерится как обычный ответ. Сетевые ошибки, 503 без такого тела (HTML от прокси) и другие коды по-прежнему дают «Состояние систем недоступно» и «Повторить».
- Добавлена строка «База данных» (`dashboard-health-db`): `connected` — зелёная OK, `disconnected` — красная НЕДОСТУПНА, иначе жёлтая «нет данных». Без неё отказ БД в виджете не был бы красным: при нём `cb_state=unknown`, это жёлтый. В тип `cb_state` добавлен `'unknown'`.
- Другие читатели `/health` во фронте: только HealthWidget. `AdminLandingPage` упоминает эндпоинт лишь в комментарии, а `s7-front2.spec` мокает его с кодом 200.
- vitest `HealthWidget.test.tsx`: 3 новых теста — 503 + БД недоступна; 503 + планировщик остановлен; 503-HTML и 500 → заглушка. Итог 11/11. Если отключить ветку degraded, 2 новых теста падают; проверено через бэкап, md5 сошёлся.
- Гейты фронта: typecheck 0, lint 0, build ok; vitest `src/components/dashboard` + `src/pages/__tests__` — 70 passed (13 файлов). Бэкенд не менялся.
- Для ФТ §19.5 (HealthWidget) текст «3 строки светофора» заменить на «4 строки: База данных / Circuit Breaker / T-Invest / Scheduler; при 503 `degraded` показываются статусы из тела ответа».
