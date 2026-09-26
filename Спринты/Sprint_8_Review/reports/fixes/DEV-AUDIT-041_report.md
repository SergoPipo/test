## DEV-AUDIT-041 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes-b`, база e914a72, не закоммичено). Ревью-1: исправлены п. 1–8, п. 9 записан находкой. Ревью-2: исправлены п. 1–3, 5–10.

### 1. Что реализовано
- **Формат шифртекста.** Заголовок `MTK\x01` + key_id (8 байт HKDF), заголовок = AAD. Формат без заголовка читается. IV и HKDF не менялись.
- **`python -m app.cli rotate-encryption-key`**, шаги по порядку:
  1. Разбор адреса compose: неразбираемый → код 2.
  2. Проверка живого сервера: `127.0.0.1:port` и `backend:8000` (или `BACKEND_COMPOSE_ADDR`) → код 3.
  3. Проверка нового ключа: правила production-секрета, ≠ старому, ≠ `SECRET_KEY`, без `$ # ' " \` и перевода строки, без пробелов по краям. Длина и энтропия проверяются один раз.
  4. Read-only проход: всё ли читается старым ключом. Нет → код 1, снимка нет.
  5. Снимок БД через `BackupService`.
  6. Одна транзакция: чтение нужных колонок, `UPDATE … WHERE id`. Строки без шифртекста или IV пропускаются с логом.
  - Отказ сообщает причину и id записи, без данных.
- **argparse.** Значения из argv не выводятся вообще. Показываются только известные имена флагов и подсказка `--new-key=<значение>`. `allow_abbrev=False`.
- **Роль процесса.** Выставляется только при запуске `python -m app.cli` (всё под `__main__`); простой импорт модуля её не включает. Сервер проверку слабых ключей проходит как прежде.
- **Путь SQLite.** Относительный путь нормализуется один раз в валидаторе `Settings`, от корня backend/. `:memory:`, абсолютные пути и не-SQLite не трогаются. Dev (uvicorn из backend/) и Docker (`/app/data/...`) получают прежний путь. `_pin_database_url` и правка `BackupService` удалены.
- **Старт сервера.** В `main.py:110` key_id ключа сверяется с данными; расхождение → `critical encryption_key_mismatch` с id записей, старт не роняется.
- **`MOEX_ENV_FILE`.** Пустое значение отключает `.env` (изоляция подпроцессов в тестах); без переменной поведение прежнее.
- **`rotate-jwt-secret`**: `token_version + 1` всем.

### 2. Файлы
Новые: `backend/app/cli/secrets_rotation.py`, `backend/app/cli/__main__.py`, `backend/app/common/process_role.py`, `backend/tests/unit/test_cli_rotate_key.py`.
Изменённые: `backend/app/common/crypto.py`, `backend/app/broker/crypto_helpers.py`, `backend/app/cli/__init__.py`, `backend/app/config.py`, `backend/app/main.py`, `backend/tests/unit/test_config.py` (2 ожидания пути → абсолютный, по п. 5).

### 3. Тесты
- RED: `ImportError: cannot import name 'secrets_rotation' from 'app.cli'`.
- GREEN: 46/46.
- Мутация ревью-2: снять guard `__main__` → `test_importing_cli_main_module_does_not_set_role` красный, `assert 'role False' in ''`. Откачена, md5 сверен.
- Мутации прошлых проходов: AI-таблица → `InvalidTag`; `is_current → False` → `assert 1 == 0`; `_weak_secret_reason` → `assert 0 == 2`.
- Гейты: pytest 3290 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (186); bandit rc 0. Фронт не менялся.

### 4. Integration points
- ✅ `check_encryption_key_matches_data` — `app/main.py:110`.
- ✅ `normalize_sqlite_url` — `app/config.py:249`.
- ✅ `is_secrets_rotation_cli` — `app/config.py:299`.
- ✅ `encrypt_with_iv` — `app/broker/crypto_helpers.py`.
- ✅ CLI в подпроцессе: запуск из временного cwd с `PYTHONPATH` и `MOEX_ENV_FILE=""`.

### 5. Контракты
Миграции нет, API не менялся.

### 6. Проблемы / тексты / находки
- **Остаточный риск (живой сервер).** Проверяется только TCP на двух адресах. Backend на ином хосте, порту или под другим именем сервиса не обнаружится. Чужой слушатель даст ложный отказ, его снимает `--server-stopped`.
- **Alembic.** `alembic/env.py` берёт `DATABASE_URL` из env мимо `Settings`, относительный путь там разрешается от cwd. Не менял — вне карточки.
- **ТЗ §8.8:** «`python -m app.cli rotate-encryption-key [--old-key=K --new-key=K]` (или `OLD_/NEW_ENCRYPTION_KEY`; значение, начинающееся с `-`, — только через `=`). Требует остановленного backend: 127.0.0.1:8000 и `backend:8000`/`BACKEND_COMPOSE_ADDR`, иначе код 3. Новый ключ — правила production-секрета, ≠ SECRET_KEY, без `$ # кавычек` и перевода строки. Порядок: read-only проверка старого ключа → снимок БД → перешифровка `broker_accounts`, `ai_provider_configs` одной транзакцией; строки без IV пропускаются; повтор идемпотентен по key_id. CLI стартует и при слабых текущих ключах с DEBUG=false. На старте сервера расхождение key_id → лог `encryption_key_mismatch` (critical), старт не блокируется. `rotate-jwt-secret` — `users.token_version + 1`; `SECRET_KEY` меняет оператор.»
- **ТЗ §7.2:** «Шифртекст = `MTK\x01` + key_id (8 байт HKDF) + AES-GCM, заголовок — AAD; формат без заголовка читается. Относительный SQLite-путь в `DATABASE_URL` разрешается от корня backend/.»
- **Гайд «Ротация секретов»:**
  1. `docker compose stop backend`.
  2. `docker compose run --rm -e OLD_ENCRYPTION_KEY=… -e NEW_ENCRYPTION_KEY=… backend python -m app.cli rotate-encryption-key`. Ключ генерировать: `python -c 'import secrets; print(secrets.token_urlsafe(48))'`.
  3. Новый `ENCRYPTION_KEY` в `.env`, затем `docker compose start backend`; в логе не должно быть `encryption_key_mismatch`.
  4. Снимок до ротации и старые бэкапы зашифрованы старым ключом: при утечке — увести офлайн или удалить.
  5. JWT: `… python -m app.cli rotate-jwt-secret`, новый `SECRET_KEY`, рестарт.
  6. Откат кода после деплоя = повторный ввод ключей.
- **Находка (п. 9 ревью-1):** шифртекст не привязан к таблице, колонке и id через AAD. Пару шифртекст+IV можно перенести в чужую строку.
- **Самопроверка:**
  1. обе фазы — отдельные сессии, запись одной транзакцией; сбой → код 1;
  2. уведомлений нет, critical на старте — однократный;
  3. тесты через `main()`, `init_db` и `BackupService`; роль и weak-key — через подпроцесс;
  4. таймаутов нет;
  5. `Settings.DATABASE_URL`: потребители (`init_db`, `BackupService`, тесты с `:memory:`) проверены полным прогоном;
  6. значения argv не выводятся.
- Scratch `rot041*` не удалён: удаление запрещено правами.

### 7–8. Stack Gotchas
Применены 19 и 50. Новых нет.

### 9. Плагины
py_compile, mypy, context7 (SQLAlchemy), `mattpocock-skills:tdd`.
