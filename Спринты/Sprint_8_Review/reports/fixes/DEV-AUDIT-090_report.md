## DEV-AUDIT-090 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. `process_pending(today=None)` берёт только действия с `coalesce(record_date, ex_date) <= today` (дата МСК; параметр — для детерминированных тестов).
2. Ex-date = предыдущий торговый день от даты реестра по `get_calendar_service()` (093; fallback Пн–Пт): помощники `accrual_record_date` / `accrual_ex_date` / `accrual_opened_before` / `accrual_position_clauses`.
3. Дивиденд и купон — только по позициям, державшимся на 00:00 МСК ex-date (порог в naive UTC — шкала `opened_at`).
4. Сбой действия → `logger.error(action_id, action_type)` + `await self.db.rollback()`; действие остаётся `processed=False`, повторится следующим прогоном. Поля под ошибку у модели нет — миграцию не заводил (решение заказчика).
5. `process_pending` идёт по скалярам `(id, action_type)` и грузит действие `db.get()` в каждой итерации: rollback экспайрит identity map (gotcha-37).
6. Даты: `detect` пишет `registryclosedate` ISS в обе колонки, `ex_date` — в ключе дедупа `uq_corp_action`, переписывать нельзя (дубли, data-миграция). `record_date` = дата реестра, ex-date вычисляется при обработке. Данных ISS достаточно.
7. Дедуп, формула split, `detect` — не тронуты.

### 2. Файлы
- изменены `backend/app/corporate_actions/service.py`, `backend/app/scheduler/service.py`
- новый `backend/tests/unit/test_corporate_actions/test_audit_s8r_ex_date.py` (5 тестов)
- изменён `.../test_audit_s8r_lot_size.py` — фикстуре 089 задан `opened_at=2026-09-01` (позиции открывались «сейчас» и по новому правилу выплату не получали)

### 3. Тесты
RED: `assert True is False` (`processed`, будущий реестр); `assert Decimal('1000.00') == Decimal('0.00')` (позиция в ex-date; утечка баланса SBER в коммит GAZP) → GREEN.
Мутация 1: снят `due_date <= today` → `test_future_ex_date_is_not_processed`: `assert True is False`. Мутация 2: `rollback()` → `pass` → `test_failed_action_does_not_leak_into_next_commit`: `Decimal('1000.00') == Decimal('0.00')`. Откачены.
Гейты (итог): pytest 2774 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `process_pending` — `app/scheduler/service.py:~231`; ✅ `accrual_position_clauses` — `corporate_actions/service.py` (дивиденд, купон); ✅ `_DetectedAction` — там же в джобе.

### 5. Контракты
API/схемы/миграции — без изменений.

### 6. Правки документов / новые находки
- ФТ §6.4 «Дивиденды»: «Начисление — при наступлении даты закрытия реестра (МСК) по позициям, державшимся на ex-date (предыдущий торговый день по календарю MOEX, T+1), включая закрытые после ex-date. Сбой одного действия откатывается, действие повторяется следующим прогоном (S8R-AUDIT-090).» То же — купоны.
- ТЗ §5.12: `process_pending(today)` — `coalesce(record_date, ex_date) <= today_msk`, `rollback()` в `except`; критерий позиции `opened_at < ex-date ≤ closed_at|NULL`.
- Находки: (а) уведомление пишет «дата отсечки {ex_date}», а там дата реестра; (б) сплит применяется ко всем открытым позициям в момент обработки; (в) ФТ/ТЗ «ежедневно 08:00 MSK» vs джоба раз в 6 ч.

### 7. Применённые Stack Gotchas
37, 38, 15.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
pyright-lsp: диагностики у LSP-инструмента нет → `py_compile` OK + mypy; typecheck `tsc -b`; context7 не требовался; tdd — `mattpocock-skills:tdd`.

### Доработки по /code-review
1. [high] Scheduler: скаляры новых действий снимаются в `_DetectedAction` до `process_pending`; цикл уведомлений читает их, не ORM. Тест `test_new_action_notified_when_other_pending_action_fails` (реальная фабрика сессий, падающий pending-сплит, новый дивиденд): RED `assert 0 == 1` (`create_notification.await_count`) → GREEN; мутация «итерировать `new_actions`» → та же строка.
2. [medium] Право на выплату — `status in (filled, open, closed) AND opened_at < порог AND (closed_at IS NULL OR closed_at >= порог)`. Закрытая позиция идёт тем же путём: дивиденд — доход сессии (paper-баланс, DailyStat), `LiveTrade.pnl` не меняется ни для открытой, ни для закрытой — минимально инвазивно, без пересчёта зафиксированного P&L сделки. Тест `test_position_closed_between_ex_date_and_record_date_gets_dividend` (01.10→06.10, реестр 07.10 — есть; открыта 06.10 — нет; закрыта 05.10 — нет; `pnl` закрытой = 0.00): RED `assert Decimal('0.00') == Decimal('1000.00')` → GREEN; мутация «статусы `filled/open` без `closed_at`» → та же строка.
Полный backend-гейт после доработок — см. §3.
