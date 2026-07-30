---
sprint: 7
agent: DEV-5 (OPS)
wave: 2
date: 2026-04-25
task: 7.9 Backup/restore
status: ✅ DONE
---

# DEV-5 OPS W2 — Отчёт

## 1. Реализовано
Задача 7.9 закрыта целиком: `BackupService` (snapshot/rotate/restore с WAL-aware copy для SQLite + Postgres-ветка через `pg_dump`/`pg_restore`), регистрация ежедневного APScheduler-job `backup_db_daily` в существующем `SchedulerService` (расписание из `settings.BACKUP_CRON`, дефолт 03:00 UTC, misfire_grace_time=3600), CLI `python -m app.cli.backup {create,list,restore,rotate}` на `argparse`. Тип БД определён как **SQLite** (по `app/config.py`).

## 2. Файлы
**Новые:** `app/backup/__init__.py`, `app/backup/service.py`, `app/cli/__init__.py`, `app/cli/backup.py`, `tests/test_backup/__init__.py`, `tests/test_backup/test_service.py` (18 unit-тестов), `tests/test_backup/test_cli.py` (9 integration-тестов через subprocess), `Develop/stack_gotchas/gotcha-19-sqlite-wal-backup.md`.
**Изменённые:** `app/config.py` (+ `BACKUP_CRON`, `BACKUP_KEEP_LAST`), `app/scheduler/service.py` (job `backup_db_daily` + метод `backup_db()` + хелпер `_parse_cron_time`), `Develop/.gitignore` (+ `backups/`, `backend/backups/`, `*.sqlite`, `*.dump`), `Develop/stack_gotchas/INDEX.md` (строка 19, version v3).

## 3. Тесты
- `pytest tests/test_backup/ -v` → **27/27 passed** (1.50s).
- Полный suite `pytest tests/ -q` → **807 passed / 0 failed** (69.03s; baseline 771 passed → +36 новых, все зелёные).
- `ruff check app/backup app/cli app/scheduler` → All checks passed.
- `python -m app.cli.backup --help` → корректный вывод 4 подкоманд.

## 4. Integration points
- `grep -rn "BackupService(" app/` → 2 production call site:
  - `app/scheduler/service.py:49` — singleton в SchedulerService (создаётся в `__init__`, если не передан явно).
  - `app/cli/backup.py:156` — CLI-инстанциация.
- Не только в тестах ✅. SchedulerService инстанциируется в lifespan (`app/main.py:110`), значит `backup_db_daily` job стартует с FastAPI приложением.
- Метод-исполнитель: `app/scheduler/service.py:362 async def backup_db()`.

## 5. Контракты
7.9 — самостоятельная задача, не входит в C1–C9. Зависимость на BACK1 «DB layer helper» **не понадобилась** — `app/common/database.py` уже предоставляет всё необходимое, а WAL-checkpoint выполняется через прямой `sqlite3.connect` (минуя SQLAlchemy, чтобы избежать блокировки event-loop через async-сессию). Запросов к BACK1 не выставлял.

## 6. Проблемы / решения
- **WAL-mode SQLite:** прямой `shutil.copy(.db)` под нагрузкой даёт неполный snapshot (последние транзакции остаются в `.db-wal`). Решение: `BEGIN IMMEDIATE` → `PRAGMA wal_checkpoint(FULL)` → `copy2` + копирование `*.db-wal`/`*.db-shm`. См. новый gotcha-19.
- **CLI без typer:** typer не в pyproject — выбран `argparse` из stdlib (проще, быстрее импорт, нет новой зависимости).
- **Restore-integrity:** битый sqlite-файл вызывал unhandled `sqlite3.DatabaseError` — обернул в `BackupError` для консистентного поведения.
- **Postgres restore «before-snapshot»:** Postgres не позволяет дёшево сохранить state перед restore — используется `--single-transaction` для атомарности; `before_marker` — log-файл, документировано в docstring.

## 7. Применённые Stack Gotchas
- **#11 (alembic drift):** `restore()` опционально запускает `alembic upgrade head` (схема в backup может быть старее).
- **#08 (AsyncSession.get_bind):** не используем AsyncSession — работаем с raw `sqlite3` через `loop.run_in_executor`.
- **APScheduler init/shutdown:** новый job — тот же паттерн `add_job(replace_existing=True)` до `_scheduler.start()`; shutdown не требует изменений.
- **#19 (новый, создан мной):** SQLite WAL backup без checkpoint — см. секцию 8.

## 8. Новые Stack Gotchas
**`gotcha-19-sqlite-wal-backup.md`** — SQLite WAL: backup через `shutil.copy` без `wal_checkpoint(FULL)` под нагрузкой даёт неполный snapshot (теряются транзакции из `.db-wal`). Правило обхода: `BEGIN IMMEDIATE` → `PRAGMA wal_checkpoint(FULL)` → `copy2` + опциональная копия `*.db-wal`/`*.db-shm`. При restore — удалять старые WAL/SHM рядом с целью, иначе SQLite дочитает их после подмены файла. Эталонная реализация: `app/backup/service.py::BackupService._copy_sqlite`. INDEX.md обновлён до v3.
