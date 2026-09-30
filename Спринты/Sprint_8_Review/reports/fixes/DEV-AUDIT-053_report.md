## DEV-AUDIT-053 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Новый файл `test_denylist_is_exhaustive.py`, 292 теста, в три слоя.
- Слой 1: параметризация по `FORBIDDEN_NAMES`, `FORBIDDEN_MODULES`, `MODULE_ALLOWED_ATTRS` и `ALLOWED_DUNDER_DEFS`. Списки читаются из модуля. Для имён — формы вызова, псевдонима, значения и атрибута; для модулей — `import`, подмодуль и `from`. Проверяется, что денилист модулей сильнее белого списка (monkeypatch), 19 dunder-паттернов (атрибут, имя, def), атрибуты вне allow-list и прокси ⊆ allow-list.
- Слой 2: «золотой» список из 41 обхода. В нём все 5 из карточки, `datetime.sys.modules` без xfail.
- Слой 3: храповик. Денилист не может стать уже снимка аудита.
- Код `app/` не менялся (по рецепту — только тесты).

### 2. Файлы
Новый: `backend/tests/unit/test_sandbox/test_denylist_is_exhaustive.py`. Изменённых и удалённых нет.

### 3. Тесты
- До правок: 3703 passed / 4 xfailed — совпало с оценкой.
- RED (удалён `getattr`): `AssertionError: обход прошёл анализатор: "s = getattr(datetime, 'sys')"` и `AssertionError: из денилиста имён удалены записи: ['getattr']`. Старый набор sandbox+security при этом зелёный: 145 passed.
- GREEN: 292 passed.
- Случайные мутации: `exit` → `[exit]` и храповик; `vars` → `[vars]` и храповик. Дополнительно: `pickle`, `__spec__` → только храповик; allow-list `+sys` → `RuntimeError: sandbox proxy datetime.sys exposes a module`; allow-list `-time` → 3 уже существующих теста. После каждой мутации файл восстановлен из бэкапа, md5 сверен.
- Гейты:
  - pytest: 3995 passed / 4 xfailed / 0 failed.
  - В первом полном прогоне упал 1 тест, не связанный с карточкой: `test_preflight_normalize_origin_matches_python[dash]` (`dash` завершился по SIGABRT под нагрузкой). Повтор `test_config.py` ×3 зелёный, повторный полный прогон зелёный.
  - ruff 0; mypy Success (189); bandit M0/H0; typecheck 0; lint 0; build ok.
  - Маркеров xfail с `S8R-AUDIT-053` нет.
  - vitest: фронт не менялся — снимается на уровне пакета.

### 4. Integration points
Нового production-кода нет. Тесты работают через `ASTAnalyzer.analyze` — его вызывают `sandbox/executor.py:61,76` и `backtest/engine.py:556`.

### 5. Контракты
Нет. Миграции нет.

### 6. Проблемы / новые находки
- Запись `"object.__subclasses__"` в `FORBIDDEN_NAMES` никогда не срабатывает: имя с точкой не совпадает ни с `Name`, ни с `attr`. Конструкцию блокирует правило dunder.
- Все записи `FORBIDDEN_MODULES`, а также `__import__`, `__builtins__`, `__loader__`, `__spec__` поведенчески дублируются белым списком или правилом dunder. Их удаление ловит только храповик. Это сознательное решение, оно описано в докстринге.
- Анализатор не видит цепочку `bt.indicators.sys`: у атрибута значение не `Name`. Границу держит прокси (gotcha-61), покрыто в `test_audit_s8r_escape.py`.
- Список белого списка в ФТ §12.5 отстаёт от кода: нет `math`, `decimal` и allow-list атрибутов. Поведение карточка не меняла, правка ФТ не нужна, но стоит сверить при следующем проходе ФТ.
- Самопроверка: пункты 1, 2, 4 и 6 неприменимы (только тесты). Пункт 3: тест идёт через публичный `analyze`. Пункт 5: вызывающие не менялись.

### 7. Применённые Stack Gotchas
02, 61 (п. 3: граница исполнения проверяется отдельно, без анализатора).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile и ruff по новому файлу; tdd (`mattpocock-skills:tdd`). context7 не нужен: API сторонних библиотек не использовался. typecheck — гейт.
