## DEV-AUDIT-072 отчёт — S8R fixes, MEDIUM (после код-ревью оркестратора)
Статус: ✅ готово к коммиту
### 1. Что реализовано
- `common/trading_hours` различает входы и закрытия.
  - Входы: `market_closed_reason`/`is_market_open` блокируют неторговый день календаря (включая Сб/Вс), время вне 10:00–23:50 и окно [18:40, 19:05).
  - Закрытия: `close_blocked_reason`/`is_within_trading_hours` блокируют только ночь и будничный праздник.
- Торговый день всегда определяет `MOEXCalendarService.is_trading_day`, включая его встроенный fallback. Если календарь не загружен, раз в сутки пишется warning. Если календарь бросил исключение — правило Пн–Пт.
- CB: календарь применяется только к sandbox/real, paper как раньше; пользовательский диапазон накладывается сверху. Своих копий `MSK_OFFSET` и окна в CB больше нет (реэкспорт); «сейчас» — через `trading_hours._now_msk`.
- Ручное закрытие (п.2): текст 422 берётся из `close_blocked_reason`, часы в нём не захардкожены.
- RiskMonitor (п.1): Сб/Вс и перерыв больше не блокируют закрытие, ордер уходит брокеру.
- Мультиплексор (п.6): добавлен `_maybe_publish_lost`; флаг ставится только по факту публикации, а `_publish_connection_event` возвращает `bool`.
- п.8: при сохранении конфига с окном шире 10:00–23:50 пишется warning `cb_trading_hours_wider_than_market`.
### 2. Файлы
- Код: `app/common/trading_hours.py`, `app/circuit_breaker/{engine,service}.py`, `app/trading/engine.py`, `app/broker/tinvest/multiplexer.py`.
- Изменённые тесты: `test_engine.py`, `test_integration.py`, `test_trading_hours_validation.py` (добавлена подмена `_now_msk`), `test_market_closed_filter.py`, `test_sltp_broker_close.py`, `test_engine_close_position_w8g.py`, `test_audit_s8r_*` (2 файла).
- Новые тесты: `test_trading_hours_calendar.py`, `test_trading_hours_holiday.py`.
### 3. Тесты
- RED (первый такт): `assert True is False` (`is_within_trading_hours(2026-11-04 12:00)`).
- GREEN: 435 тестов в смежных наборах.
- Мутация: закрытия блокируются и в выходные → `Expected place_order to have been awaited once. Awaited 0 times` (`test_stop_loss_order_is_sent[saturday]`). Откачена через бэкап, md5 сверен.
- Гейты: pytest 3594 passed / 6 xfailed / 0 failed (`faulthandler_timeout=300`, прогон в субботу); ruff 0; mypy Success (188); bandit 0.
- Фронт не менялся, vitest и typecheck — на уровне пакета.
### 4. Integration points
✅ `circuit_breaker/engine.py` (`_check_trading_hours(session)`), `trading/engine.py:4551`, `risk_monitor.py:382`, `multiplexer.py` (`_is_moex_open_now`, `_maybe_publish_lost`), `circuit_breaker/service.py` (upsert).
### 5. Контракты
API и схема не менялись, миграции нет. Изменился только текст 422.
### 6. Проблемы / ФТ-ТЗ
- **Отклонение от п.1**: в будничный праздник RiskMonitor пропускает закрытие. Причина — тот же pre-check из п.2 всё равно дал бы 422; к тому же свечей в такой день нет. В Сб/Вс и в перерыв закрытие проходит.
- Если event_bus упал, lost повторяется на следующем реконнекте.
- `_is_moex_open_now` находится в `multiplexer.py`, а не в `notification/service.py`, как указано в карточке.
- E2E: в Сб/Вс входы sandbox/real пропускаются; paper работает.
- **ФТ §1.6**, после «блокируется»: «Входы sandbox/real — только в торговый день календаря §1.7, 10:00–23:50 MSK, кроме аукциона закрытия и перерыва 18:40–19:05; paper календарём не ограничен. Закрытия (ручное, SL/TP) блокируются только ночью и в будничный праздник биржи; в выходные и в перерыв решает брокер. Пользовательское окно CB для sandbox/real действует только внутри 10:00–23:50 (S8R-AUDIT-072)».
- **ФТ §12.4**: «trading_hours: для sandbox/real учитывает календарь MOEX и перерыв 18:40–19:05».
- **ТЗ** (после блока 093): «`app/common/trading_hours`: `market_closed_reason`/`is_market_open` для входов, `close_blocked_reason`/`is_within_trading_hours` для закрытий; единственная точка “сейчас” — `_now_msk`; торговый день — `get_calendar_service().is_trading_day`».
- Находка: `dailytable` загружается за год; даты следующего года до синхронизации определяются по недельному правилу.
- Самопроверка: 1 — новых записей в БД нет; 2 — уведомление не больше одного, lost больше не теряется; 3 — реальные пути (`check_before_order`, `check_sl_tp`, `close_position`, `_maybe_publish_lost`); 4 — таймаутов нет; 5 — все вызывающие перечислены в §4; 6 — неприменимо.
### 7. Gotchas
10, 30, 70.
### 8. Новые
Нет.
### 9. Плагины
py_compile, ruff, mypy; скилл tdd; context7 не нужен (только stdlib).
