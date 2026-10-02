## DEV-AUDIT-031 отчёт — S8R fixes, LOW (ревью р.2: исправлено 1–5)
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Р.1, всё сохранено: (а) комментарий `commission_pct`; (б) реконсиляция `pending` без входа → `cancelled`; (в) `filled` без цены не допускается; (г) `app/common/money.py::quantize_money` (HALF_UP).
- **п.1** «Нет цены» = `None` или ≤ 0. Одна функция `positive_price`, через `entry_fill_price` в обеих ветках (синхронный filled и опрос после PLACED).
- **п.2** Источники цены: (1) `average_price`; (2) `executed_order_price / (лоты × лот)` — новое поле `OrderStatus.executed_order_price` из `OrderState` в маппере; затем, как в W8j, `response.price` > 0. (3) Портфель не используется: это новый сетевой путь. Цены нет дольше `UNKNOWN_OUTCOME_CONFIRM_AGE_SEC` (тот же смысл «брокер не подтвердил») → `_entry_without_price`: `filled` без цены, `position_mismatch_at`/нота, пауза, критичный `position.mismatch`, без SL/TP и `trade.opened`. Поля сессии пишутся через `UPDATE` (сессия recovery отсоединена). В recovery `resolved_filled` считается по факту.
- **п.3** В `cancelled` реконсиляции записанная комиссия идёт в `realized_pnl` (`trades_closed` не растёт).
- **п.4** `apply_open` блокирует и списывает `quantize_money(cost/commission)`.
- **п.5** `quantize_money` — в `net_pnl`/`total_commission`/`avg_trade_pnl` статистики, в CB (`_MONEY_Q` удалён), в корпоративных действиях (`_MONEY_QUANT` удалён). `win_rate`/`profit_factor`/проценты не тронуты.

### 2. Файлы
Новые: `app/common/money.py`, `tests/test_trading/test_accounting_edges.py`. Изменены: `broker/base.py`, `broker/tinvest/mapper.py`, `circuit_breaker/engine.py`, `corporate_actions/service.py`, `trading/{engine,paper_engine,risk_monitor,runtime,schemas,service}.py`.

### 3. Тесты
RED р.2 (7): `'filled' == 'pending'` ×2; `Decimal('0E-8') == Decimal('325.44')`; `Decimal('0E-8') is None`; `0 == Decimal('-4.89')`; `Decimal('1000.005') == Decimal('1000.00')`; `Decimal('0.12') == Decimal('0.13')` → GREEN 10/10. Цены построены через `TInvestMapper`.
Мутация п.1 (`positive_price` снова только по типу): 4 красных, например `AssertionError: пустая цена брокера (Decimal 0 из маппера) — не цена исполнения`. Откачено из бэкапа, md5 совпал.
Гейты: pytest 4576 passed / 1 skipped / 1 xfailed / 0 failed; ruff 0; mypy Success (193); bandit 0. Фронт не менялся: typecheck/lint/build ok в р.1, vitest — на уровне пакета.

### 4. Integration points
✅ `positive_price`/`entry_fill_price` — `engine.py:4305, 4418`; ✅ `_entry_without_price` — `engine.py:4305, 4418`; ✅ `executed_order_price` — mapper → `entry_fill_price`; ✅ `quantize_money` — 6 модулей.

### 5. Контракты
`OrderStatus.executed_order_price` (с дефолтом `None`). Миграции нет, API не менялось.

### 6. ТЗ / находки
**ТЗ §5.4, текст:** «Цена исполнения входа: `average_position_price` из `GetOrderState`, иначе `executed_order_price / (лоты × лот)` (сумма ордера), иначе цена ответа `PostOrder`; ноль — не цена. Без цены сделка остаётся `pending`; дольше `UNKNOWN_OUTCOME_CONFIRM_AGE_SEC` (120 с) — `filled` без цены входа: пометка расхождения сессии, пауза, критичное уведомление, SL/TP не ставятся, закрытие из терминала доступно (P&L не рассчитывается — сделка `cancelled` по FIX-5). Реконсиляция после переоткрытия счёта: сделка без входа — `cancelled`, вне `trades_closed`, удержанная комиссия — в `realized_pnl`. Деньги округляются `quantize_money` (копейки, HALF_UP)».
Находка: у закрытой «слепой» позиции цена выхода в учёт не попадает (FIX-5). Пересчёт P&L по факту — отдельная карточка.
Самопроверка 1–6: commit одной транзакцией, уведомление одно и только после commit, тесты идут через recovery/`process_signal`/`close_position`, повторного ордера нет (`place_order` не вызван).

### 7–9
Gotcha 27, 33, 57 (лот 10 в тесте); новых нет. Использованы py_compile, скилл tdd; context7 не нужен (stdlib `decimal`, поля SDK сверены по `schemas.py`).
