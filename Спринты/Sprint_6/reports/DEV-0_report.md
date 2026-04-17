# DEV-0 Report — S6-STRATEGY-UNDERSCORE-NAMES

**Sprint:** S6 | **Wave:** 0 | **Date:** 2026-04-17

---

## 1. Реализовано

- Переименованы все `_`-prefixed идентификаторы в сгенерированном коде стратегий:
  - `self._entry_order` → `self.entry_order_ref`
  - `self._sl_order` → `self.sl_order_ref`
  - `self._tp_order` → `self.tp_order_ref`
  - `self._is_long` → `self.is_long_pos`
  - `_size` → `position_size`
- Все 11 тестов code_generator обновлены: `compile()` → `compile_restricted()`
- Добавлен E2E тест: генерация кода с SL/TP/OCO + `compile_restricted` + проверка отсутствия `self._`
- Добавлен тест в sandbox: реально сгенерированный код проходит `compile_restricted`

## 2. Файлы

| Файл | Действие |
|------|----------|
| `app/strategy/code_generator.py` | Модифицирован — 5 переименований (~30 замен) |
| `tests/unit/test_strategy/test_code_generator.py` | Модифицирован — 11 `compile`→`compile_restricted` + 1 новый тест |
| `tests/unit/test_sandbox/test_executor.py` | Модифицирован — 1 новый тест |

## 3. Тесты

- `pytest tests/unit/test_strategy/` — 14 passed (было 13, +1 E2E)
- `pytest tests/unit/test_sandbox/` — 7 passed (+1 новый)
- `pytest tests/unit/test_backtest/` — 72 passed, 0 failed (регрессия OCO)
- `ruff check app/strategy/code_generator.py` — All checks passed

## 4. Integration Points

- `code_generator.py` → `executor.py:80` (`compile_restricted`) — теперь совместимы
- `code_generator.py` → `backtest/engine.py` (`_compile_strategy`) — работает (backtrader не зависит от имён атрибутов)

## 5. Контракты

Нет cross-DEV контрактов в волне 0. DEV-0 — self-contained blocker fix.

## 6. Проблемы

Нет.

## 7. Применённые Stack Gotchas

- **Gotcha 2** (CodeSandbox `__import__`): подтверждено, что `import` по-прежнему не генерируется
- **Gotcha 3** (Backtrader SL/TP OCO): переименование не ломает OCO — Backtrader сравнивает по `order.ref`, имена атрибутов внутренние

## 8. Новые Stack Gotchas

Нет новых. Проблема полностью описана в backlog `S6-STRATEGY-UNDERSCORE-NAMES` и покрыта Gotcha 2 (RestrictedPython policy).
