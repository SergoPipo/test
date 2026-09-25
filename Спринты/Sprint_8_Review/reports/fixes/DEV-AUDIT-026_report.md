## DEV-AUDIT-026 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (с доработками по /code-review)

### 1. Что реализовано
- Добавлена `calculate_position_lots` (`engine.py:458`) — единая формула лотов для движка и CB, без `max(1, …)`. Бюджет меньше лота → 0 лотов. `fixed_lots` не менялся, база `percent` тоже (это карточка 027).
- При 0 лотов `process_signal` возвращает `None` и публикует `order.error` с причиной «Бюджет меньше одного лота: выделено X ₽, лот стоит Y ₽». Уведомление одно на серию пропусков (`_BELOW_LOT_SKIP_STREAK`, в памяти процесса).
- CB `_check_position_size_limit` считает лоты той же функцией (с комиссией). При 0 лотов CB не блокирует.
- Серия сбрасывается в pause/resume/stop (`forget_below_lot_series`) и когда бюджета снова хватает на лот.

### 2. Файлы
Изменены: `backend/app/trading/engine.py`, `backend/app/circuit_breaker/engine.py`, `backend/tests/test_circuit_breaker/test_engine.py`, `backend/tests/unit/test_audit_s8r_health_and_sizing.py` (сняты 2 xfail 026).
Новый: `backend/tests/test_trading/test_position_sizing_budget.py`. Фронт не менялся (см. п.2 доработок).

### 3. Тесты
- RED исходного фикса: `assert 1 == 0 … _calculate_position_size(…, Decimal('6000'), 1)`. Мутация `return max(1, …)` → 5 failed.
- Гейты: pytest 2951 passed / 13 xfailed / 0 failed; ruff 0; mypy Success (179); bandit 0; typecheck 0; lint 0; build ok; vitest 937 passed (135 files).

### 4. Integration points
✅ `circuit_breaker/engine.py:385` → `calculate_position_lots`; `trading/engine.py:4385` (сайзинг), `:1761` (`process_signal`), `:1177/1234/1284` (pause/resume/stop → `forget_below_lot_series`).

### 5. Контракты
API, схемы и миграции не менялись.

### 6. Проблемы / правки ФТ
- Развилка, решённая мной: `consecutive_fund_skips` не используется. Его читает CB (3 подряд → пауза), а сбрасывается он только в paper-ветке.
- ФТ §3.4, после «Лотность»: «Если сумма на сделку (или доля капитала) меньше стоимости одного лота с учётом комиссии, сделка не открывается. Сигнал пропускается, как в бэктесте, и приходит одно уведомление „Бюджет меньше одного лота“ на серию; Circuit Breaker такой сигнал не считает нарушением лимита позиции (S8R-AUDIT-026).»
- Шапка ФТ v4.0: «**Сделка не превышает заданный бюджет** (S8R-AUDIT-026).»
- **Нужна карточка:** эндпоинт лота для формы запуска. Например, `GET /market-data/instruments/{ticker}/lot` (или `lot_size` в существующем ответе) через `ensure_lot_size_strict`, плюс текущая цена. Только тогда можно вернуть предупреждение «сумма меньше лота» (ловушка п.5).

### Доработки по /code-review
1. [high] CB считал `max(1)` → переведён на `calculate_position_lots`. Старый тест `test_fixed_sum_below_cost_per_lot_blocks` закреплял дефект → стал `…_not_blocked`. Новые тесты: сценарий ревью через `check_before_order` и тест на учёт комиссии. RED: `AssertionError: Размер ордера 6000 превышает лимит 5000`. Мутация `max(1)` в общей функции → 7 failed (движок + CB), откат по md5.
2. [high] Существующего эндпоинта с корректным лотом нет: `/instruments/{t}` и поиск берут данные из ISS без LOTSIZE, получается 1. Фронтовое предупреждение удалено целиком, модалка восстановлена из HEAD.
3. [low] Неактуально после п.2.
4. [low] Добавлен сброс серии в pause/resume/stop + 2 теста. RED: `assert 0 == 1` (после resume нет уведомления), `assert 1 not in {1: 1}`. Мутация «убрать сброс» → `test_resume_starts_new_below_lot_series` красный.

### 7. Stack Gotchas
Проверил 27, 28, 57, 71. В тестах серия пропусков сбрасывается фикстурой (id сессий повторяются между тестами).

### 8. Новые
Нет. Однократное зависание полного прогона на ~43% не повторилось в трёх прогонах — кандидат в gotcha-71.

### 9. Плагины
py_compile + mypy; tsc -b; скилл `mattpocock-skills:tdd`; context7 не требовался.
