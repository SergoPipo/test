## DEV-AUDIT-051 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (часть «дополнить `.env.example`» — ⏸ по решению заказчика)
### 1. Что реализовано
- `docs/env_vars.md`: все 45 настроек `Settings` с дефолтами и назначением. Три таблицы: для оператора (36), служебные с причиной (9: `DEV_MODE`, `SQL_ECHO`, `MOEX_ISS_BASE_URL`, `BACKTEST_DATA_TIMEOUT_*` ×4, `AI_DAILY_LIMIT`/`AI_MONTHLY_LIMIT`), compose (`TRUSTED_PROXY_IPS`). Там же сказано, что `TINVEST_TOKEN`/`TELEGRAM_CHAT_ID`/`TZ` задаются не через env.
- Тесты сверяют таблицы с кодом в обе стороны: полнота, дефолты и подстановки `${…}` в compose.
- compose: `logging` json-file 10m×5 у backend и frontend; `--timeout-graceful-shutdown 10`.
- `start.sh`: preflight при `DEBUG≠true` читает `.env`/`MOEX_ENV_FILE` через python-dotenv, как pydantic-settings. Ротация `dev.log` (copytruncate, 50 МБ × 5) при старте и раз в минуту, пока жив backend. При `source` скрипт ничего не запускает.
### 2. Файлы
Новый: `docs/env_vars.md`. Изменены: `backend/tests/unit/test_config.py`, `docker-compose.yml`, `scripts/start.sh`, `backend/app/config.py` (только комментарий).
### 3. Тесты
RED: `AssertionError: настройки config.py не описаны в docs/env_vars.md: ['AI_ALLOW_PRIVATE_PROVIDER_URLS', 'AI_API_KEY', 'AI_DAILY_LIMIT', 'AI_MODEL', …]` (перечень по гайду §3.2); `uvicorn в compose запущен без --timeout-graceful-shutdown`; `start.sh: production_preflight: command not found`. GREEN: 13 тестов. Мутация: новое поле `MUTANT_UNDOCUMENTED_LIMIT` в `Settings` дало `…не описаны в docs/env_vars.md: ['MUTANT_UNDOCUMENTED_LIMIT']`; откат через бэкап, md5 совпал. Гейты: pytest 3644 passed / 4 xfailed / 0 failed; ruff 0; mypy Success (188); bandit M0/H0; typecheck 0; lint 0; build ok; vitest не запускал — фронт не менялся, прогон на уровне пакета.
### 4. Integration points
✅ `production_preflight`/`rotate_log`/`watch_log_rotation` вызываются в `scripts/start.sh`; новых Python-символов нет.
### 5. Контракты
API и миграций нет. `alembic heads` = `1d92db59f28d`: это значение для гайда §3.3 вместо `d1e2f3a4b5c6`.
### 6. Проблемы / правки документов / находки
- Отклонение от рецепта: таймаут 10 вместо 30. uvicorn 0.44 запускает lifespan shutdown (45 с) только после ожидания соединений (`server.py:286-301`), а 30 + 45 > 60 привело бы к SIGKILL. Тест проверяет `drain + 45 < stop_grace_period`.
- Гайд §3.2: вставить таблицы из `docs/env_vars.md`, убрать `TINVEST_TOKEN`, `TELEGRAM_CHAT_ID`, `TZ`. §3.3: в uvicorn добавить `--timeout-graceful-shutdown 10`. §8.3: лимит логов 10m×5; нативный `start.sh` запускает preflight и ротирует `backend/logs/dev.log`. §3.3, 113/150: `alembic current` → `1d92db59f28d`. Ссылки внизу гайда: ФТ v4.0, ТЗ v3.0. ТЗ §8.2: вместо `JWT_SECRET_KEY` — `SECRET_KEY`, `SMTP_FROM` (а не `EMAIL_FROM`), `SMTP_PORT=465`, `BACKUP_KEEP_LAST`/`BACKUP_CRON` (а не `BACKUP_RETENTION`); таблица — ссылкой на `docs/env_vars.md`.
- Новые находки: (1) `AI_DAILY_LIMIT`/`AI_MONTHLY_LIMIT` код не читает — мёртвые настройки. (2) Дефолт `AI_MODEL=claude-sonnet-4-6-20250514` — не существующий ID; у Sonnet 4.6 ID `claude-sonnet-4-6`, текущая Sonnet — `claude-sonnet-5`. Дефолт не менял, пометил в перечне. (3) `start.sh` и при `DEBUG=false` запускает uvicorn с `--reload`. (4) Base-образы без digest не трогал.
- Самопроверка: пп. 1, 2, 4 и 6 не затронуты; п. 3 — тесты вызывают реальные функции скрипта; п. 5 — вызывающих нет.
### 7. Stack Gotchas
50 (worktree), 60.
### 8. Новые Stack Gotchas
Кандидат: `--timeout-graceful-shutdown` не покрывает lifespan shutdown — бюджет `stop_grace_period` = drain + lifespan.
### 9. Плагины
py_compile, mattpocock tdd, claude-api (ID модели), typecheck (`tsc -b`); context7 не понадобился — API uvicorn сверен по исходнику.
