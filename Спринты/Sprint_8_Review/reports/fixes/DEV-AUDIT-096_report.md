## DEV-AUDIT-096 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту
### 1. Что реализовано
- Модель `TaxLot`: `report_id` NOT NULL → `tax_reports.id` (CASCADE) плюс индекс `idx_tax_lot_report`. Колонка `remaining_quantity` удалена: миграция этой таблицы всё равно нужна, поэтому отдельная миграция не понадобилась.
- `_build_report`: отчёт делает flush уже после резолва лотности (порядок 097 сохранён). Затем удаляются лоты прежних отчётов того же года (`_delete_lots_of_previous_reports`), новые лоты получают `report_id`. Строки старых отчётов и их файлы остаются.
- При сбое (кроме «locked») сначала `rollback()`, потом удаляется недописанный файл этого отчёта (чужие файлы не трогаются), затем пишется новая строка со `status="error"`.
- Файл называется `tax_report_{report.id}.{ext}`. Имя для скачивания (`tax_report_{year}`, router и фронт) не менялось.
- `_build_fifo_queue` переименован в `_build_lots`, докстринги описывают фактическое поведение. Формулы базы и ставок не трогал.
### 2. Файлы
Новые: `alembic/versions/7fe0fae4293c_tax_lots_report_id.py`, `tests/unit/test_tax/test_audit_s8r_lots.py`.
Изменённые: `app/tax/{models,service}.py`, `tests/unit/test_migration.py`, `tests/unit/test_tax/{test_fifo,test_lot_size_convergence}.py` (переименование).
### 3. Тесты
RED: `AssertionError: лоты прежнего отчёта года обязаны удаляться / assert 4 == 2`; `AttributeError: type object 'TaxLot' has no attribute 'report_id'`; `assert '…/tax_report_1_2026.csv' != '…/tax_report_1_2026.csv'`.
GREEN: 4 теста карточки + `test_tax_lots_report_id_round_trip`.
Мутация: вызов `_delete_lots_of_previous_reports` заменён на `pass`. Результат: `assert 4 == 2`, `assert 3 == 2`; откат сделан через бэкап, md5 совпал.
Гейты: pytest 4512 passed / 3 xfailed / 7 failed. Все 7 падений — `test_f2_daily_stat_upsert.py`, flake по времени (см. §6); с `TZ=UTC` 9/9 passed. ruff 0; mypy Success (196); bandit rc 0; typecheck/lint/build — 0. vitest не запускал: фронт не менялся, прогон на уровне пакета.
### 4. Integration points
✅ `service.py:166` `_build_lots`; `:181` `_delete_lots_of_previous_reports`; `:188/:621/:629` `_report_file_path`. Путь `POST /tax/reports` и `/download` не изменился, скачивание старого id проверено тестом через HTTP.
### 5. Контракты
Миграция `7fe0fae4293c` (down `c7d2e5a19f84`): upgrade → `downgrade -1` → upgrade на чистой БД, `alembic check` — изменений нет, `heads` = 1. API и схемы не менялись.
Текст для гайда §7: «`7fe0fae4293c` (S8R-AUDIT-096): `tax_lots.report_id` FK → `tax_reports` CASCADE, `remaining_quantity` снята. Существующие лоты удаляются: это производные данные, пересоздаются следующей генерацией отчёта. Downgrade возвращает `remaining_quantity=0`.»
### 6. Проблемы / находки
- Почему лоты удаляются, а не привязываются: никто их не читает, а при привязке к одному отчёту остались бы накопленные дубли регенераций.
- Остаток: если упадёт сам commit (после экспорта, вне `_build_report`), файл может остаться без строки. Обычно SQLite переиспользует rowid, и следующий отчёт с тем же id его перезапишет.
- На пути ошибки rollback сбрасывает (expire) объекты сессии вызывающего (gotcha-37); router после вызова их не читает.
- ФТ §18.2 / ТЗ 5.13, предлагаемый текст: «Каждый отчёт хранит собственный файл; регенерация за год заменяет расчётные лоты, прежние отчёты остаются доступны для скачивания».
- **Новая находка:** `test_f2_daily_stat_upsert.py::_read_stat` фильтрует по локальному `date.today()`, а код (`daily_stats.py:59`) пишет дату по UTC. Между 00:00 локального времени и 00:00 UTC падают 7 тестов.
- Самопроверка: 1 — ok (откат целиком); 2 — уведомлений нет; 3 — реальный путь, HTTP-download; 4 — таймаутов нет; 5 — вызывающие `_build_*` только тесты и `_build_report`; 6 — н/п.
### 7. Применённые Stack Gotchas
12, 37, 48, 53, 79.
### 8. Новые Stack Gotchas
Кандидат: тест сравнивает локальный `date.today()` с датой, которую код пишет по UTC, — flake около полуночи.
### 9. Плагины
py_compile/mypy; typecheck `tsc -b`; context7 не нужен (API alembic batch известен, проверен round-trip); tdd — скилл загружен.
