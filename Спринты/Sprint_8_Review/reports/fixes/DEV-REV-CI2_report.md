## DEV-REV-CI2 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `alembic/env.py`: `fileConfig(config.config_file_name, disable_existing_loggers=False)` + комментарий. CLI не меняется.
- Регрессионный тест `test_alembic_env_keeps_existing_loggers_enabled`: логгер `app.config` создан → `command.upgrade` через настоящий env.py → логгер не disabled, warning `Settings(POSITION_CHECK_RETRIES=9)` доходит до обработчика.
- Точечные обходы убраны (проверено: других источников `disabled=True` в app/tests нет): `monkeypatch.setattr(logger, "disabled", False)` — 1 в `test_config.py` (фикстура `config_warnings`; свой обработчик оставлен, т.к. fileConfig по-прежнему снимает обработчики корня и меняет его уровень; докстринг поправлен), 4 в `test_secret_masks.py`; лишние `monkeypatch` в параметрах удалены.

### 2. Файлы
Изменены: `backend/alembic/env.py`, `backend/tests/unit/test_migration.py`, `backend/tests/unit/test_config.py`, `backend/tests/unit/test_common/test_secret_masks.py`.

### 3. Тесты
RED (порядок CI: `test_config.py::test_cors_public_http_origin_warns_in_production` → `test_migration.py::test_alembic_upgrade_head` → `test_retry_settings_clamped_not_fatal`, `-p no:randomly`): `AssertionError: assert 'POSITION_CHECK_RETRIES=9' in ''`; новый тест: `AssertionError: alembic fileConfig выключил логгер app.config` / `assert True is False`.
GREEN: та же тройка + новый тест — 4 passed; migration+config+secret_masks+reconcile — 220 passed.
Мутация: вернуть `fileConfig(config.config_file_name)` → `AssertionError: alembic fileConfig выключил логгер app.config`; откат через бэкап, md5 совпал.
Гейты: pytest 5170 passed / 1 skipped / 0 xfailed / 0 failed (`-o faulthandler_timeout=240`); ruff 0; mypy Success (199); bandit rc 0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `backend/alembic/env.py:26`. Новых функций в app/ нет.

### 5. Контракты
Нет; миграции нет.

### 6. Проблемы / новые находки
ФТ/ТЗ/гайд не затронуты. Самопроверка: п.1–2, 4, 6 — неприменимо; п.3 — тест идёт через реальный `command.upgrade` → env.py; п.5 — fileConfig вызывается только из env.py.

### 7. Применённые Stack Gotchas
—

### 8. Новые Stack Gotchas
Кандидат: «caplog пуст только в полном прогоне — `fileConfig` (alembic в процессе pytest) выключает существующие логгеры; `disable_existing_loggers=False`».

### 9. Плагины
py_compile env.py; tdd-скилл; context7 не нужен (stdlib `logging.config`).
