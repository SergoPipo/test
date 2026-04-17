---
sprint: S6
agent: DEV-0
role: "Backend Fix — S6-STRATEGY-UNDERSCORE-NAMES (code_generator + sandbox compatibility)"
wave: 0
depends_on: []
---

# Роль

Ты — Backend-разработчик (senior), специалист по code generation и sandbox security. Твоя задача: устранить критический баг, при котором сгенерированный код стратегии не может выполниться в RestrictedPython sandbox из-за `_`-префиксных имён. Работаешь в `Develop/backend/`.

## Суть проблемы

`code_generator.py` генерирует Python-код Backtrader-стратегии с атрибутами `self._entry_order`, `self._sl_order`, `self._tp_order`, `self._is_long` и локальной переменной `_size`. Эти имена корректны для Backtrader, но **RestrictedPython категорически отвергает** любые идентификаторы с ведущим `_`:

```
SyntaxError: "_entry_order" is an invalid attribute name because it starts with "_".
```

Результат: `compile_restricted()` в `executor.py:80` возвращает ошибку, `_execute_strategy` возвращает `None`, живая сессия не генерирует сигналов. В логах — ~12 000 повторов `strategy_execution_failed` в час.

**Критический момент:** существующий тест `test_code_generator.py:66` использует стандартный `compile()`, а не `compile_restricted()`, поэтому баг не ловился.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python >= 3.11
2. Зависимости: RestrictedPython установлен (`pip show RestrictedPython`)
3. Существующие файлы:
   - Develop/backend/app/strategy/code_generator.py
   - Develop/backend/app/sandbox/executor.py
   - Develop/backend/tests/test_strategy/test_code_generator.py
   - Develop/backend/tests/test_sandbox/test_executor.py
4. База данных: не требуется (pure code fix)
5. Тесты baseline: `pytest tests/` → 0 failures
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.
2. **`Develop/stack_gotchas/INDEX.md`** — Gotcha 2 (CodeSandbox `__import__`), Gotcha 3 (Backtrader SL/TP OCO).
3. **Backlog:** `Спринты/Sprint_6/backlog.md` секция «S6-STRATEGY-UNDERSCORE-NAMES» — полный контекст бага.

4. **Цитаты из кода (по состоянию на 2026-04-17):**

   > **code_generator.py** (строки 306-309, `__init__`):
   > ```python
   > lines.append("        self._entry_order = None")
   > lines.append("        self._sl_order = None")
   > lines.append("        self._tp_order = None")
   > lines.append("        self._is_long = True")
   > ```

   > **code_generator.py** (строка 483, `next()`):
   > ```python
   > lines.append("        _size = int(self.broker.get_cash() * ...")
   > ```

   > **code_generator.py** (строки 330-521): ~30 ссылок на `self._entry_order`, `self._sl_order`, `self._tp_order`, `self._is_long` в методах `notify_order()` и `next()`.

   > **executor.py** (строка 80): `compiled = compile_restricted(code, "<strategy>", "exec")`
   > RestrictedPython policy: reject all identifiers starting with `_`.

   > **test_code_generator.py** (строка 66): `compile(code, "<test>", "exec")` — **стандартный** compile, не ловит `_` restriction.

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

```
- app/strategy/code_generator.py       — генерация Python-кода из Blockly JSON. МОДИФИЦИРУЕМ.
- app/sandbox/executor.py              — RestrictedPython sandbox. НЕ МОДИФИЦИРУЕМ (правило enforced by design).
- app/backtest/engine.py               — Backtrader engine. Проверить, что переименование не ломает OCO (Gotcha 3).
- tests/test_strategy/test_code_generator.py — тесты генератора. РАСШИРЯЕМ.
- tests/test_sandbox/test_executor.py  — тесты sandbox. РАСШИРЯЕМ.
```

# Задачи

## Задача 0.1: Переименование `_`-переменных в code_generator.py

Заменить все `_`-prefixed имена на безопасные альтернативы:

| Было | Стало | Описание |
|------|-------|----------|
| `self._entry_order` | `self.entry_order_ref` | Ссылка на entry ордер |
| `self._sl_order` | `self.sl_order_ref` | Ссылка на stop-loss ордер |
| `self._tp_order` | `self.tp_order_ref` | Ссылка на take-profit ордер |
| `self._is_long` | `self.is_long_pos` | Флаг направления позиции |
| `_size` | `position_size` | Размер позиции в лотах |

**Обязательно:** применить замену **во всех** строках файла. `grep -n "self\._entry_order\|self\._sl_order\|self\._tp_order\|self\._is_long\|_size" app/strategy/code_generator.py` → 0 результатов после фикса.

## Задача 0.2: End-to-end тест (code generation → compile_restricted)

Добавить тест, который генерирует код через `CodeGenerator` и компилирует его через `compile_restricted()` (не стандартный `compile()`):

```python
def test_generated_code_passes_restricted_python():
    """Сгенерированный код должен проходить compile_restricted без ошибок.
    Ловит баг S6-STRATEGY-UNDERSCORE-NAMES: _-prefixed identifiers запрещены."""
    from RestrictedPython import compile_restricted
    from app.strategy.code_generator import CodeGenerator

    # Минимальный блочный JSON с BUY entry + SL + TP
    blocks = [...]  # использовать фикстуру из test_code_generator.py

    generator = CodeGenerator()
    code = generator.generate(blocks)

    # Главная проверка: compile_restricted НЕ бросает SyntaxError
    compiled = compile_restricted(code, "<test-strategy>", "exec")
    assert compiled is not None
    assert compiled.errors == []  # или проверить что ошибок нет
```

## Задача 0.3: Обновить существующий тест

В `test_code_generator.py` заменить `compile(code, "<test>", "exec")` на `compile_restricted()` — чтобы такие баги ловились автоматически:

```python
# БЫЛО:
compile(code, "<test>", "exec")

# СТАЛО:
from RestrictedPython import compile_restricted
result = compile_restricted(code, "<test>", "exec")
assert not result.errors, f"RestrictedPython errors: {result.errors}"
```

## Задача 0.4: Регрессия Backtrader OCO (Gotcha 3)

Убедиться, что переименование не ломает логику OCO-трекинга в Backtrader:
- `notify_order()` метод: `entry_order_ref`, `sl_order_ref`, `tp_order_ref` — те же ссылки, просто новые имена
- Backtrader не зависит от имён атрибутов (они внутренние для стратегии)
- Запустить: `pytest tests/test_backtest/` → 0 failures

# Тесты

```
tests/
├── test_strategy/
│   └── test_code_generator.py    # Заменить compile→compile_restricted, добавить e2e тест
├── test_sandbox/
│   └── test_executor.py          # Добавить тест с реально сгенерированным кодом
└── test_backtest/
    └── test_engine.py            # Регрессия: OCO-трекинг работает с новыми именами
```

**Минимум:** 2 новых теста (e2e compile_restricted + регрессия backtrader) + 1 обновлённый.

# ⚠️ Integration Verification Checklist

- [ ] `grep -rn "self\._entry_order\|self\._sl_order\|self\._tp_order\|self\._is_long" app/strategy/code_generator.py` → **пусто**
- [ ] `grep -rn "_size" app/strategy/code_generator.py` → **только комментарии**, не код
- [ ] `grep -rn "compile_restricted" tests/test_strategy/test_code_generator.py` → **найдено**
- [ ] `pytest tests/test_strategy/ tests/test_sandbox/ tests/test_backtest/ -x` → 0 failures
- [ ] `ruff check app/strategy/code_generator.py` → 0 errors

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.

Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-0_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 0.1–0.4 реализованы
- [ ] `ruff check .` → 0 errors
- [ ] `pytest tests/` → 0 failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-0_report.md`
- [ ] Ни одного `_`-prefixed идентификатора в сгенерированном коде
- [ ] Backtrader OCO регрессия — 0 failures
