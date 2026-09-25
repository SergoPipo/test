## DEV-AUDIT-101 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `BrokerService.create_account`: SELECT+INSERT+commit вынесены в `_register_discovered_locked` под `keyed_lock("create_account", user_id)`; discovery (сеть) — до лока, sandbox auto-topup — после освобождения.
- `except IntegrityError: rollback()` → перечитывание существующих записей (gotcha-37), возврат их вызывающему; конфликт не по нашему ключу — re-raise.
- Модель: `UniqueConstraint(user_id, broker_type, account_id)` `uq_broker_accounts_user_type_account` (NULL `account_id` не конфликтует).
- Миграция `b8e4d17c9a52`: слияние дублей (порядок: больше ссылок из `trading_sessions` → активная → меньший `id`; ссылки перевешиваются явным UPDATE — FK не действуют, 015; если выжившая выключена, а удаляемая была активна — включается), затем `batch_alter_table` → UNIQUE. Идемпотентна; `downgrade` снимает ограничение, данные не восстанавливает.
- `locks.py` «Порядок захвата»: ветвь `create_account` задокументирована (отдельная; только из роутера, не из-под другого лока).
- Посев `test_sandbox_commission.py::_make_session` сеял `account_id="acc-1"` дважды в одну БД — теперь `acc-{mode}`.

### 2. Файлы
Новые: `backend/alembic/versions/b8e4d17c9a52_broker_accounts_unique_account.py`, `backend/tests/test_broker/test_audit_s8r_create_account_race.py`.
Изменённые: `backend/app/broker/service.py`, `backend/app/broker/models.py`, `backend/app/common/locks.py`, `backend/tests/test_trading/test_sandbox_commission.py`.

### 3. Тесты
RED: `AssertionError: вызовы вернули разные записи: 1 и 2` → GREEN: 9 тестов файла (гонка; `IntegrityError`→existing при обезвреженном локе; два на topup; round-trip; слияние дублей + перевес сессий; два на порядок выбора; идемпотентность). Гонка — 10/10 прогонов подряд. Мутация «`async with lock` → `if True` + снять UniqueConstraint» → `AssertionError: вызовы вернули разные записи: 2 и 1`; «только лок» → зелёный (второй уровень держит). Откачены.
Гейты: pytest 2815 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета. `alembic heads` = 1; `alembic check` — только дрейф карточки 004, по `broker_accounts` diff нет.

### 4. Integration points
✅ `app/broker/service.py:158` (`keyed_lock("create_account")`), `:160` (`_register_discovered_locked`), `_existing_by_account_id` — там же; вызов из `app/broker/router.py:52`.

### 5. Контракты
API/схемы не менялись. Миграция `b8e4d17c9a52` ← `c5e8b2a7f913`; round-trip на чистой временной БД и на БД с дублями — тестами. При интеграции с 024 оркестратор переставляет `down_revision` на `d4f1a9c2b7e0`; колонок 024 миграция не касается.

### 6. Предлагаемые правки документов / находки
- **Гайд §7**: `alembic current` → `b8e4d17c9a52 (head)`; блок: «**Обновление с версии старше `b8e4d17c9a52` (S8R-AUDIT-101).** Ревизия добавляет `UNIQUE (user_id, broker_type, account_id)` на `broker_accounts`. Перед этим дубли одного счёта сливаются: остаётся запись, на которую ссылаются торговые сессии, при равенстве — активная, затем старшая; ссылки остальных перевешиваются на неё, лишние удаляются; если среди удалённых была активная — выжившая включается. Обратима по схеме; слитые дубли `downgrade` не восстанавливает. SQLite пересоздаёт таблицу — снимите backup (§6.1).»
- **ТЗ §3.2**: `└── UNIQUE: uq_broker_accounts_user_type_account (user_id, broker_type, account_id)`; история v3.0: «`S8R-AUDIT-101`: `create_account` — `keyed_lock("create_account", user_id)` вокруг SELECT+INSERT, `IntegrityError` → существующая запись, sandbox-пополнение только созданных этим вызовом; миграция `b8e4d17c9a52` (§3.2, §8)».
- **ФТ §7.7**: «Один реальный счёт брокера подключается у пользователя один раз: повторное подключение того же ключа, в том числе одновременное (двойной клик), возвращает существующую запись, а не создаёт вторую; стартовый sandbox-баланс выставляется только вновь созданным записям.» + строка истории v4.0.
- Находка: лок `sandbox_recovery_user` (`sandbox_recovery.py:263`) в «Порядке захвата» `locks.py` не описан — отдельная карточка.
- В `git stash list` worktree одна запись — не моя, не трогал.

### 7. Применённые Stack Gotchas
12, 15, 37, 48, 53, 59.

### 8. Новые Stack Gotchas
Кандидат: при двухуровневой защите (лок + UNIQUE) мутация «снять лок» остаётся зелёной — снимать оба уровня; и UNIQUE ломает посевы тестов, дважды сеющие один внешний id в одну БД.

### 9. Плагины
py_compile по всем `.py` (LSP в worktree не резолвит `app.*`); `pnpm typecheck` (`tsc -b`); context7 не требовался (образцы репо `c5e8b2a7f913`, `user_favorites/service.py`); TDD — `mattpocock-skills:tdd`.

### 10. Доработки по /code-review
1. **Topup при конфликте.** RED: `AssertionError: пополнений: 2, ожидалось 1` и `пополнены записи [1, 2], ожидалась только 2`. Правка: `_register_discovered_locked` возвращает `(записи по всем обнаруженным счетам, created_ids)`; после `IntegrityError` `created_ids` пуст (транзакция откачена — всё создал сосед); topup — только для `acc.id in created_ids`. Ответ API не менялся (все обнаруженные). Развилка: обычный путь раньше тоже пополнял ранее зарегистрированный счёт — приведено к одному правилу по ФТ W8a («после создания BrokerAccount»). GREEN: `test_conflict_loser_does_not_top_up_account_created_by_winner`, `test_topup_only_for_accounts_created_by_this_call`.
2. **Выбор выжившей.** RED: `assert {1: False} == {2: True}` и `{1: False} == {1: True}`. Правка: `ORDER BY refs DESC, is_active DESC, id ASC` + перенос активности на выжившую. GREEN: `test_active_duplicate_survives_inactive_older`, `test_referenced_inactive_survives_but_becomes_active`. Полный гейт — в §3.
