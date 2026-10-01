## DEV-AUDIT-022 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту (только тест, код не менялся — угрозу закрыла 096)

### 1. Что реализовано
- Предпроверка: HEAD `4f31507`, дерево было чистым, `alembic heads` = 1 (`7fe0fae4293c`).
- Угроза проверена: после 096 файл называется `tax_report_{report.id}.{ext}` (`app/tax/service.py:286`, `_report_file_path`), им пользуются `_export_csv` и `_export_xlsx`. Две генерации дают два файла.
- Ловушка рецепта проверена. Очистки или ротации каталога `data/tax_reports` в `app/` нет. Единственный `unlink` (`service.py:250`) удаляет недописанный файл откаченного отчёта. Ротация в `backup/service.py` относится только к бэкапам. Эндпоинта удаления отчёта нет.
- Добавлен тест по рецепту `test_second_report_same_year_keeps_first_file`. Проверяет: файлы разные, файл первого отчёта побайтово прежний, скачивание через `GET /download` по первому id отдаёт исходные байты.
- Добавлен тест на ловушку `test_regeneration_keeps_files_referenced_by_previous_reports`. Сценарий: генерации csv, xlsx, csv и одна сбойная. Проверяет: файлы всех ready-строк на месте и не изменены, набор `file_path` в БД совпадает с ними.

### 2. Файлы
Новый: `backend/tests/unit/test_tax/test_report_file_isolation.py`. Изменённых и удалённых нет.

### 3. Тесты
RED не получен: тест сразу GREEN, потому что 096 уже закрыла угрозу. Это честно зафиксировано.
GREEN: 2 passed. `tests/unit/test_tax`: 52 passed (было 50).
Мутация: в `_report_file_path` общее имя `tax_report_shared_year.{ext}` (через бэкап, md5 сверен) → `AssertionError: у каждой строки отчёта — свой файл` и `AssertionError: три генерации → три разных файла / assert 2 == 3`. Мутация откачена.
Гейты: pytest 4564 passed / 1 xfailed / 1 skipped / 0 failed (`-o faulthandler_timeout=300`); маркеров 022 нет (0); ruff 0; mypy Success (192); bandit rc 0, M/H нет; typecheck 0; lint 0; build ok. vitest: фронт не менялся, прогон на уровне пакета.

### 4. Integration points
Нового production-кода нет. Тест идёт через `TaxReportService.generate_report` и настоящий роутер `/api/v1/tax/reports/{id}/download`.

### 5. Контракты
API, схемы и миграции не менялись.

### 6. Проблемы / находки
- В карточке устаревший адрес «Где» (`service.py:515/524`): код ушёл после 096.
- Мелочь, вне карточки: в `router.py:84` имя `Content-Disposition` — `tax_report_{year}.{fmt}`, оно одинаково у всех отчётов года. Содержимое у каждого своё, но в «Загрузках» файлы различит только суффикс браузера. Можно предложить `tax_report_{year}_{id}`.
- ФТ, ТЗ и гайд правок не требуют.
- Самопроверка: пп. 1, 2, 4, 6 — нет нового кода; п. 3 — реальный путь сервис → роутер; п. 5 — вызывающие не менялись.

### 7. Применённые Stack Gotchas
gotcha-48 (файловая БД + NullPool для клиента в другом loop).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
tdd-скилл — да; py_compile не нужен (app не менялся); typecheck — гейт; context7 не нужен (API сторонних библиотек не использовался).
