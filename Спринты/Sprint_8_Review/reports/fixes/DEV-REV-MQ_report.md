## DEV-REV-MQ отчёт — S8R fixes, LOW (итерация 4)
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Новая функция `_broker_commission_is_fact(session, value)` — единственное место правила «комиссия брокера — факт» (`> 0`, а на real и `0`) для S8R-FIX-049. Её используют `_record_broker_commission` и `_apply_entry_order_commission`.
- `_apply_entry_order_commission` (только из `_extend_partial_entry`):
  - факт `> 0.00` → `max(записанный broker-факт, факт)`, источник `broker`;
  - иначе: записан broker — не трогать; записана оценка — пересчитать на весь `volume_rub`;
  - нет записи — вызов `_record_broker_commission(..., volume_rub)`: совпадает с первым fill по построению, включая 0.004.
- Пропорциональный `volume_rub` убран. «Нет цены» = None или ≤ 0: `entry_price`/`volume_rub` не перезаписываются; `_attach_sl_tp` вызывается безусловно, как в ffc2a42.
- `_estimate_commission` и лог `entry_commission_set` — без изменений с итерации 3.

### 2. Файлы
Изменены `engine.py`, `csrf.py` (только комментарий), `test_partial_fill_timeout.py`. Таблица первого fill — 14 строк (добавлено 0.004 для sandbox и real), довыполнение — 30 кейсов.

### 3. Тесты
- ffc2a42 (подмена `engine.py` через `git show` с бэкапом, md5 сверен): таблица первого fill 14/14 зелёная; довыполнение — 9 красных, в том числе `(3.52,'estimated') == (0.50,'broker')` и `Decimal('0E-8') == Decimal('100.50')` (цена 0).
- GREEN: 53 passed.
- Мутации, все красные, откат по бэкапу:
  - «прибавлять cumulative» → `(0.80,'broker') == (0.50,'broker')`, 8 красных;
  - «0 как факт» → `(0.00,'broker') == (5.04,'estimated')`, 5 красных;
  - «цена 0 — цена» → `0E-8 == 100.50`, 1 красный.
- Повторный recovery (с ценой, без цены — None и 0): комиссия и `volume_rub` не меняются.
- Гейты: pytest 4609 passed / 1 skipped / 3 xfailed / 0 failed; ruff 0; mypy Success (196); bandit 0; typecheck/lint/build ok. vitest: фронт не менялся, прогон на уровне пакета.

### 4. Integration
✅ `engine.py:3456`, `:3531` (предикат); helper — в `_extend_partial_entry`.

### 5. ТЗ §5.4
«Довыполнение частичного входа: `executed_commission` кумулятивен по ордеру и пишется итогом. Факт > 0 заменяет оценку и не уменьшает записанный факт (`broker`). Иначе факт сохраняется, оценка пересчитывается на весь оборот входа, а сделка без записи учитывается правилом первого fill. Средняя цена None/0 не перезаписывает цену и объём. Правило первого fill не изменилось».

### 6. Gotchas / плагины
Применены 57, 48, 27; новых нет. Плагины: py_compile, typecheck, tdd.
