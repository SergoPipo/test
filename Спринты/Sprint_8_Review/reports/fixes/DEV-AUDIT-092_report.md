## DEV-AUDIT-092 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (после доработок по /code-review)

### 1. Что реализовано
1. `_copy_sqlite` → `sqlite3.Connection.backup()` (Online Backup API, отдельное dst-соединение), копия переводится в `journal_mode=DELETE` (самодостаточный файл) + `PRAGMA integrity_check` сразу после создания; битый снимок удаляется, `BackupError`.
2. Restore под файловым локом: существование + integrity снимка (ro) → полная копия во временный файл в каталоге БД → снимок текущей БД `before_restore_*` тем же Backup API (с WAL) → `wal_checkpoint(TRUNCATE)` текущей → `os.replace` → удаление старых `-wal/-shm`. До `os.replace` рабочий файл не меняется; при сбое temp/before убираются.
3. Межпроцессный `fcntl.flock` на `backup_dir/.lock` для create/restore (`_run_locked`): в executor-потоке, `LOCK_NB` + опрос с дедлайном 300 с → `BackupError`.
4. `restore` отказывает пути вне `backup_dir` (`is_relative_to`).
5. `OSError`/`sqlite3.Error` → `BackupError`.
6. CLI restore: `--server-port` (default 8000) — порт слушается → код 3; `--server-stopped` — явное подтверждение.
7. `settings.BACKUP_DIR` (default `"backups"`, от корня backend/), `BackupService.default_backup_dir()`.
8. Уникальные имена под локом (`_unique_path`: `backup_<ts>_2.sqlite` при коллизии; то же для `before_restore_*`/`restore_tmp_*`).
Ротация, `BACKUP_CRON` не тронуты.

### 2. Файлы
Новый: `backend/tests/test_backup/test_audit_s8r_restore_atomic.py` (10 тестов; каталог модуля — `tests/test_backup/`).
Изменены: `backend/app/backup/service.py`, `backend/app/cli/backup.py`, `backend/app/config.py`, `backend/tests/test_backup/test_cli.py`, `test_cli_restore_roundtrip.py` (restore-вызовы получили `--server-stopped`; докстринг WAL-теста).

### 3. Тесты
RED (карточка): `AssertionError: restore не использует os.replace — подмена БД не атомарна`; `Failed: DID NOT RAISE BackupError` (×2); `assert 1920064.08 >= 1920066.98`; `error: unrecognized arguments: --server-port`; `AttributeError: Settings … has no attribute 'BACKUP_DIR'`.
GREEN: `tests/test_backup/` 42 passed.
Мутация (карточка): `_run_locked` без `_file_lock` → `assert 1920278.14 >= 1920281.01`, откачена.
Гейты: pytest 2794 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit rc=0 (M0/H0); typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета. Маркеров `S8R-AUDIT-092` нет.
Ручной прогон (синтетическая БД в scratch, `alembic upgrade head`, WAL с открытым соединением): строка из WAL в снимке, restore вернул данные, integrity ok, alembic после restore OK, stray-файл отклонён, temp-остатков нет.

### 4. Integration points
✅ `_run_locked` — `service.py` (create ×2, restore ×2); `default_backup_dir()` — через `scheduler/service.py:89` и `cli/backup.py:205`; `_server_is_listening` — `cli/backup.py:158`; `_verify_integrity`/`_unique_path`/`_checkpoint_truncate` — из `_copy_sqlite`/`_create_sqlite_snapshot`/`_restore_sqlite`.

### 5. Контракты
API/схем/миграций нет. CLI: флаги `--server-port`, `--server-stopped`; код возврата 3. Настройка `BACKUP_DIR`. Снимки теперь `journal_mode=DELETE` (приложение включает WAL при первом подключении).

### 6. Предлагаемые правки документов / находки
- `deployment_guide.md` §6.1: «снимок через `sqlite3.Connection.backup` + `integrity_check`; каталог — `BACKUP_DIR` (default `backend/backups`, в контейнере `/app/backups`); рядом `.lock` — межпроцессный flock, каталог должен быть локальным томом (не NFS/SMB)». §6.3: «`docker compose stop backend` → `python -m app.cli.backup restore --path <файл внутри BACKUP_DIR> --yes` (под живым сервером — отказ, код 3; `--server-stopped` только если порт занят чужим сервисом) → `docker compose start backend`».
- `.env.example` (карточка 051): `BACKUP_DIR=backups  # каталог снимков БД; относительный — от backend/`.
- ФТ §17.2: UI-настройки каталога нет — предлагаю «в указанную директорию (`BACKUP_DIR`)».
- gotcha-19 «Правило»: заменить шаги copy2/checkpoint на `Connection.backup`.
- Git stash в worktree содержит 1 чужую запись — не трогал.

### 7. Применённые Stack Gotchas
19, 48, 59 (рандеву до лока + мутация), 50.

### 8. Новые Stack Gotchas
Кандидат: «тест на потерю WAL с живым держателем ложно зелёный — `close()` последнего соединения чекпойнтит даже удалённый `-wal` через открытый fd; аварию моделировать подпроцессом с `os._exit`». Номер не присваивал.

### 9. Плагины
py_compile OK; typecheck/lint/build прогнаны; context7 — не требовался (stdlib, API проверены прототипами в scratch); tdd — RED→GREEN→мутация по каждому тесту.

### Доработки по /code-review
| # | Тест (RED — фактическая строка) | Правка |
|---|---|---|
| 1 | `test_before_restore_snapshot_includes_wal_rows` — `assert ['alice','bob'] == ['alice','bob','in_wal']` | снимок `before_restore_*` через `_copy_sqlite` (Backup API) |
| 2 | `test_failed_replace_leaves_current_db_and_wal_intact` — та же строка (с «аварийным» WAL через `os._exit`) | `wal_checkpoint(TRUNCATE)` текущей БД → `os.replace` → удаление `-wal/-shm` после подмены; сбой → `BackupError`, temp/before убраны |
| 3 | `test_restore_rechecks_backup_under_lock` — `DID NOT RAISE BackupError` (БД заменялась пустой) | существование + `integrity_check` снимка под локом, открытие `file:…?mode=ro` (uri) |
| 4 | `test_two_snapshots_in_same_second_get_distinct_names` — `второй снимок перезаписал первый` | `_unique_path` под локом; формат `backup_*.sqlite` сохранён, ротация сортирует по mtime |
Мутация п. 2: удаление `-wal/-shm` перенесено до снимка/подмены → тесты 1 и 2 RED (`… == ['alice','bob','in_wal']`), откачена. Полный гейт после доработок — числа в §3. Первый вариант теста 2 был ложно-зелёным (см. §8) — переписан до правки кода.
