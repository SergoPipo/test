## DEV-AUDIT-099 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Предпроверка: worktree `534658f`, дерево чистое, Python 3.11.15, `alembic heads` = 1 (`b8e4d17c9a52`).
- `BrokerService.delete_account` берёт `keyed_lock("session_start_account", account_id)`; тело (get_account → SELECT блокирующих → `delete`+`commit`) вынесено в `_delete_account_locked` по конвенции `locks.py`. `BLOCKING_SESSION_STATUSES` и ответ 409 не тронуты.
- **Развилка, решена сама:** проверка существования счёта при старте живёт в `TradingService.start_session` — *до* лока. Лок в `delete_account` сам по себе закрывал только порядок «старт первым»; в порядке «удаление первым» (ровно сценарий J2) старт под локом всё равно создавал сессию на удалённом счёте. Добавлена минимальная перепроверка в `_create_session_locked` (sandbox/real: `SELECT BrokerAccount.id` под локом → `ValidationError` «Брокерский счёт №N удалён»). Поведение продукта не меняется (несуществующий счёт и раньше отклонялся), денег/ФТ не касается.
- `locks.py`: задокументировано использование ключа `session_start_account` удалением счёта; порядок захвата не изменён (отдельная ветвь, внутри секции локов и сети нет; `delete_account` вызывается только из роутера).
- Тест гонки детерминирован в обе стороны (гейт первой задачи + сигнал второй, таймаут штатен под локом): два теста, оба RED 10/10 до правки, GREEN 10/10 после.

### 2. Файлы
- Новый: `backend/tests/test_broker/test_audit_s8r_delete_account_race.py`
- Изменены: `backend/app/broker/service.py`, `backend/app/trading/engine.py`, `backend/app/common/locks.py`

### 3. Тесты
RED (10/10, оба порядка): `AssertionError: активная сессия [1] ссылается на удалённый счёт №1: старт=TradingSession, удаление=NoneType` → GREEN `test_delete_account_and_start_session_are_mutually_exclusive`, `test_start_session_then_delete_account_is_rejected` — 10 прогонов подряд, 10/10 зелёных (~4 с/прогон — таймаут гейта под локом). Мутация: снять `async with lock:` в `delete_account` → оба теста красные той же строкой; откачена, контрольный прогон зелёный.
Гейты: pytest **2817 passed / 16 xfailed / 0 failed** (150 с); ruff 0; mypy Success (179); bandit exit 0 (M0/H0); typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `_delete_account_locked` ← `delete_account` (`app/broker/service.py:572`) ← роутер `app/broker/router.py:178`; ✅ проверка счёта — внутри `_create_session_locked` (`app/trading/engine.py:432-453`), путь `TradingService.start_session` → `TradingSessionManager.start_session`. Новых эндпоинтов/событий/схем нет.

### 5. Контракты
API/схемы без изменений; миграции нет.

### 6. Предлагаемые правки документов / находки
- **ТЗ v3.0, строка истории `S8R-AUDIT-NNN` (§5.4, `locks.py`):** «`S8R-AUDIT-099`: `BrokerService.delete_account` — проверка живых сессий и удаление под `keyed_lock("session_start_account", account_id)` (тот же ключ, что у старта sandbox/real-сессии; тело — `_delete_account_locked`); `_create_session_locked` перепроверяет существование счёта под локом → `ValidationError`. Порядок захвата не меняется — отдельная ветвь.»
- **ФТ v4.0, история:** «Удаление брокерского счёта и запуск сессии на нём больше не могут пройти одновременно: либо сессия создаётся и удаление отклоняется, либо счёт удаляется и запуск отклоняется с понятным текстом. Сессии, ссылающейся на удалённый счёт, не бывает.»
- Новая находка (в отчёт, не в код): `resume_session` проверяет уникальность под `session_start_account`, но существование счёта не перепроверяет; сессия при этом уже существует и удаление её видит (409) — реального окна нет, отметить при ревью.

### 7. Применённые Stack Gotchas
48 (файловая БД + NullPool), 59 (рандеву до лока, таймаут штатен, мутация обязательна), 37 (скаляры под локом, объекты после commit не читаются), 53 (проверка `alembic heads`).

### 8. Новые Stack Gotchas
Кандидат (номер не присваиваю): тест гонки «рандеву до лока» без гейта внутри первой задачи даёт 40 % ложно-зелёных без лока — второй законный исход (409) выпадает по расписанию; для мутационной проверки порядок проверок фиксировать гейтом первой задачи + сигналом второй.

### 9. Плагины
pyright-lsp → fallback `py_compile` (3 файла OK); `pnpm typecheck` (tsc -b); context7 не требовался (стандартные SQLAlchemy `select`/`asyncio`); TDD — `mattpocock-skills:tdd` (RED → GREEN → мутация).
