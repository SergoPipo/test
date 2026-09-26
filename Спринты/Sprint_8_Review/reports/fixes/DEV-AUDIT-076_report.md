## DEV-AUDIT-076 отчёт — S8R fixes, MEDIUM (после код-ревью)
Статус: ✅ готово к коммиту. Ревью: исправлены пункты 1–10

### 1. Что реализовано
- `paper_engine.paper_portfolio_section`: лок `paper_portfolio` + свежее чтение одним запросом (`populate_existing` + `lazyload(session)`). Для нескольких сессий — `paper_portfolio_locks` (по возрастанию id).
- Правило «лок до первой записи в транзакции» (п.1):
  - вход — секция открывается до `INSERT` сделки и `DailyStat`;
  - закрытие и SL — до `_apply_close`;
  - корп. действия — до правок, а `ensure_lot_size` (возможна сеть) вынесен до лока.
  
  Правило описано в `locks.py`.
- Единственный вызывающий, который писал до лока, — CB `_force_close_open_positions`. Там добавлен commit паузы перед закрытиями. Семантика не меняется: первое закрытие и так коммитило эту же сессию.
- п.2: дивиденды, купоны и cash-in-lieu сплита теперь идут под теми же локами, баланс читается свежим.
- п.3: обоснование отказа от атомарного UPDATE (REAL в SQLite) записано в докстринги `fresh_paper_portfolio` и `locks.py`.
- п.5: общий `_settle_paper_close` для ручного закрытия и SL.
- п.6: вызов через `nullcontext`.
- п.7: внутри секции остаются только запись и commit; refresh, события и логи вынесены наружу.
  - Исключение — `_attach_sl_tp`: он пишет в тот же единственный commit (F1), а вынос дал бы второй commit. Денег он не трогает, сети не вызывает.
- п.9: лишняя проверка режима убрана; для SL добавлен ранний выход при пустом `decisions`.
- п.10: пробел исправлен.

### 2. Файлы
- Новый: `tests/test_trading/test_paper_portfolio_race.py`.
- Изменены: `app/trading/{engine,paper_engine,risk_monitor}.py`, `app/corporate_actions/service.py`, `app/circuit_breaker/engine.py`, `app/common/locks.py`.

### 3. Тесты
- RED (до фикса): `AssertionError: blocked_amount 0.00 ≠ стоимость открытых позиций 9000.00`.
- GREEN: 6 из 6, 5 прогонов подряд без флейков.
- Новая мутация «лок после flush»: `test_concurrent_open_and_close_keep_invariant` падает (`database is locked` по busy_timeout).
- Мутация «снять лок» по путям — каждая краснит свой тест, все откачены, md5 совпал:

| Путь | Сколько тестов красные | Среди них |
|---|---|---|
| вход | 6 из 6 | — |
| ручное закрытие | 3 | `test_close_waits_for_open` |
| SL | 1 | `test_stop_loss_waits_for_open` |
| дивиденд | 1 | `test_dividend_waits_for_open` |

- Гейты: pytest 3413 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (186); bandit M0/H0. Фронт не менялся.

### 4. Integration points
✅ `engine.py:2144` (вход), `:4538` и `:4652` (закрытие), `risk_monitor.py:286` и `:309`, `corporate_actions/service.py:291`, `:421`, `:503`.

### 5. Контракты
API и миграции не менялись.

### 6. Проблемы / документы / находки
- Предлагаемая правка ТЗ §5.4 (строка «`PaperTradingEngine`…»), дописать: «Денежная мутация paper-портфеля (вход, закрытие, SL/TP, дивиденды/купоны/cash-in-lieu) — в секции `keyed_lock("paper_portfolio", session_id)` (после `close_trade`), взятой до первой записи транзакции; баланс внутри перечитывается. Атомарный SQL не применяется: Numeric в SQLite хранится как REAL — S8R-AUDIT-076».
- Самопроверка:
  1. Сбой commit → rollback, лок снимается в `async with`, инвариант 008 не затронут.
  2. Уведомления — прежние события, в прежнем порядке.
  3. Все тесты идут через `process_signal`, `close_position`, `check_sl_tp`, `process_dividend`.
  4. Новых таймаутов нет.
  5. Вызывающие `close_position` проверены, CB поправлен.
  6. Не применимо.
- Нужно решение оркестратора: CB-правка выходит за рамки карточки, но без неё правило п.1 нарушалось бы.

### 7. Применённые Stack Gotchas
59, 48, 71, 58, 37.

### 8. Новые Stack Gotchas
Кандидат: «asyncio-лок + писатель SQLite = скрытый дедлок». Задача, ставшая писателем, не должна ждать asyncio-лок, который держит другой будущий писатель. Правило: лок брать до первой записи. Второй кандидат: `select()` под локом возвращает объект из identity map (selectin) — нужен `populate_existing`.

### 9. Плагины
py_compile — ok; context7 не понадобился, API SQLAlchemy (`populate_existing`, `lazyload`) сверены по исходникам 2.0.49; tdd — `mattpocock-skills:tdd`.
