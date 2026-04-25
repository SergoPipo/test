---
sprint: 7
agent: DEV-5
role: OPS — Backup/restore + E2E support
wave: 2
depends_on: [BACK1 (для 7.9 backup integration), QA (для E2E support)]
---

# Роль

Ты — DevOps-инженер. Зона ответственности по RACI: Deploy scripts/CI/CD = R, Backup/Logs/Health = R, Документация = R.

На W2 реализуешь backup/restore (главный по 7.9, BACK1 — саппорт по DB layer). На W3 — саппорт QA по поднятию backend+frontend для E2E.

# Предварительная проверка

```
1. Окружение: Python ≥ 3.11, .venv активирован, доступ к директории Develop/backend/.
2. Зависимости (W2): BACK1 закрыл W1 (debt-задачи), готов помогать с DB layer.
3. Существующие файлы: app/scheduler/service.py (APScheduler), app/cli/ (если есть, иначе создаём), app/db/ (sessionmaker, Base).
4. Тесты baseline: pytest tests/ -q → 0 failures.
5. Доступ к Postgres/SQLite (зависит от текущего окружения).
```

# Обязательные плагины

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| pyright-lsp | **да** (после каждого Edit/Write на .py) | `python -m py_compile` |
| context7 | **да** — APScheduler, FastAPI lifespan, SQLAlchemy для дампов | WebSearch |
| code-review | да (после блока изменений) | — |
| typescript-lsp | нет | — |
| playwright | нет (но саппорт инфры для QA) | — |

# Обязательное чтение

1. **`Develop/CLAUDE.md`** — особенно правила плагинов и backup-секции (если есть).
2. **`Develop/stack_gotchas/INDEX.md`** — APScheduler init/shutdown, FastAPI lifespan.
3. **`Спринты/Sprint_7/sprint_design.md`** — задача 7.9 описание.
4. **`Спринты/Sprint_7/arch_design_s7.md`** — секция backup/restore (если ARCH её включил).
5. **`Спринты/Sprint_7/preflight_checklist.md`** — что должно быть готово.

# Рабочая директория

`Develop/backend/`

# Контекст существующего кода

- `app/scheduler/service.py` — APScheduler service. Регистрировать backup_job сюда.
- `app/main.py` — FastAPI app + lifespan. APScheduler инициализируется в lifespan.
- `app/cli/` — каталог CLI entry points (если нет — создать).
- `app/db/session.py` — SQLAlchemy session/engine.
- Текущий тип БД: SQLite или Postgres (проверить в `.env` / `app/config.py`).

# Задачи

## Задача 7.9: Backup/restore (W2, главный)

### 7.9.1 — BackupService (с BACK1 саппорт)

```python
# app/backup/service.py (новый)

class BackupService:
    """Создание резервных копий БД с ротацией."""

    BACKUP_DIR = Path("Develop/backend/backups")
    KEEP_LAST = 7

    async def create_backup(self) -> Path:
        """Создаёт snapshot БД. Возвращает путь к файлу."""
        timestamp = datetime.utcnow().strftime("%Y-%m-%d_%H%M%S")
        backup_path = self.BACKUP_DIR / f"backup_{timestamp}.sqlite"  # или .sql.gz для PG
        # Если SQLite: shutil.copy(db_path, backup_path)
        # Если Postgres: subprocess `pg_dump --no-owner --format=custom > backup_path`
        return backup_path

    async def rotate(self):
        """Удаляет всё кроме последних KEEP_LAST копий."""
        files = sorted(self.BACKUP_DIR.glob("backup_*"), reverse=True)
        for old in files[self.KEEP_LAST:]:
            old.unlink()

    async def restore(self, backup_path: Path):
        """Восстанавливает БД из бэкапа."""
        # Если SQLite: shutil.copy(backup_path, db_path)
        # Если Postgres: subprocess `pg_restore --clean --no-owner < backup_path`
```

### 7.9.2 — Регистрация в APScheduler

```python
# app/scheduler/service.py (расширение)

from app.backup.service import BackupService

def setup_scheduler(scheduler: AsyncIOScheduler):
    backup_service = BackupService()

    @scheduler.scheduled_job('cron', hour=3, minute=0)
    async def daily_backup():
        path = await backup_service.create_backup()
        await backup_service.rotate()
        logger.info(f"Backup created: {path}")
```

### 7.9.3 — CLI восстановление

```python
# app/cli/restore.py (новый)
import argparse
import asyncio
from pathlib import Path
from app.backup.service import BackupService

def main():
    parser = argparse.ArgumentParser(description="Restore DB from backup.")
    parser.add_argument("--from", dest="from_path", required=True, type=Path)
    args = parser.parse_args()

    if not args.from_path.exists():
        print(f"Error: {args.from_path} not found")
        exit(1)

    confirm = input(f"Restore from {args.from_path}? Current DB will be replaced. [yes/no]: ")
    if confirm != "yes":
        print("Cancelled")
        exit(0)

    asyncio.run(BackupService().restore(args.from_path))
    print("Restored successfully")

if __name__ == "__main__":
    main()
```

Запуск: `python -m app.cli.restore --from Develop/backend/backups/backup_2026-04-25_030000.sqlite`

### 7.9.4 — Smoke-тест integration

```python
# tests/test_backup/test_backup_restore.py
async def test_create_delete_restore_smoke(db_session):
    # 1. Создать запись (User, Strategy, или другой)
    user = User(email="smoke@test.com")
    db_session.add(user)
    db_session.commit()

    # 2. Backup
    bs = BackupService()
    backup_path = await bs.create_backup()
    assert backup_path.exists()

    # 3. Удалить запись
    db_session.delete(user)
    db_session.commit()
    assert db_session.query(User).filter_by(email="smoke@test.com").first() is None

    # 4. Restore
    await bs.restore(backup_path)

    # 5. Запись на месте
    db_session.expire_all()
    assert db_session.query(User).filter_by(email="smoke@test.com").first() is not None
```

### 7.9.5 — Документация

Создать `Develop/backend/BACKUP.md`:

```markdown
# Backup & Restore

## Автоматический бэкап
- Расписание: ежедневно в 03:00 UTC
- Расположение: `Develop/backend/backups/backup_YYYY-MM-DD_HHMMSS.<ext>`
- Ротация: keep last 7

## Восстановление вручную
```bash
cd Develop/backend
.venv/bin/python -m app.cli.restore --from backups/backup_2026-04-25_030000.sqlite
```

## Проверка работоспособности
```bash
pytest tests/test_backup/test_backup_restore.py
```
```

## Саппорт 7.11 (E2E)

На W3 (день 13–14) — помочь QA с инфраструктурой:

1. Поднять backend (`uvicorn app.main:app`) и frontend (`pnpm dev`) для E2E прогонов.
2. Если QA сообщает о проблемах с playwright config или поднятием — диагностировать.
3. Документировать в `Develop/RUNBOOK.md` (или `BACKUP.md` секция «E2E setup»), как воспроизвести окружение.

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Если ввёл `@pytest.mark.skip` — карточка в backlog.

# Тесты

```
tests/
└── test_backup/
    └── test_backup_restore.py    # 7.9 smoke (см. выше)
```

# Integration Verification Checklist

- [ ] **7.9 BackupService:** `grep -rn "BackupService" app/` показывает регистрацию в scheduler.
- [ ] **7.9 backup_job:** `grep -rn "scheduled_job.*cron" app/scheduler/` показывает daily_backup.
- [ ] **7.9 CLI:** `python -m app.cli.restore --help` работает (выводит help).
- [ ] **7.9 Smoke-тест:** прогнан вручную, результат в отчёте (создал → удалил → восстановил → запись на месте).
- [ ] **7.9 Документация:** `Develop/backend/BACKUP.md` создан.
- [ ] **APScheduler init/shutdown gotcha:** соблюдён в lifespan FastAPI.

# Формат отчёта

**1 файл:** `reports/DEV-5_OPS_W2.md` — после 7.9 + саппорт 7.11.

8 секций до 400 слов.

# Alembic-миграция

Не применимо (backup не модифицирует схему).

# Чеклист перед сдачей

- [ ] BackupService реализован с rotate.
- [ ] APScheduler job daily_backup зарегистрирован.
- [ ] CLI restore работает.
- [ ] Smoke-тест прогнан и passed.
- [ ] Документация создана.
- [ ] `pytest tests/test_backup/ -v` → green.
- [ ] `ruff check app/backup/ app/cli/` → no issues.
- [ ] pyright чист.
- [ ] Stack Gotchas применены (APScheduler init/shutdown).
- [ ] `Sprint_7/changelog.md` обновлён.
- [ ] Отчёт сохранён файлом.
- [ ] Саппорт 7.11 задокументирован (если активный).
