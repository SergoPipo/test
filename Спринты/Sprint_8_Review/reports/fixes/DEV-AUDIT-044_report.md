## DEV-AUDIT-044 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту. Ревью р.2: исправлено 1–10. Ревью р.3: исправлено 1–8.
### 1. Что реализовано
- До паузы уже были: классы `Transient/Auth/NotFoundBrokerError`, `errors.py`, backoff+джиттер, р.2 п.2–6 и п.9. Р.2 п.1, 7, 8, 9 доделаны после паузы.
- Р.3 п.1: новая категория `FailureKind.LOCAL` для исключений не из SDK и не сетевых. На пробе ключа `ExecuteBatchError`/`INVALID_METADATA` → `AuthBrokerError` «ключ некорректен…». Прочий LOCAL → «внутренняя ошибка при проверке». В маппинге инструмента LOCAL → следующий класс. В ордере LOCAL → «внутренняя ошибка при отправке ордера — проверьте портфель». LOCAL не ретраится.
- Р.3 п.2: для ордеров текст «ответ брокера на отправку/отмену ордера не получен — проверьте портфель, не повторяйте вручную», маркера движка в нём нет.
- Р.3 п.3: `OpenSandboxAccount` вынесен из `_read_with_retry`.
- Р.3 п.4: `acquire()` в `get_real_operations` перенесён в замыкание.
- Р.3 п.5: для RETRYABLE/LINK в тексте только код gRPC (5-значный код T-Invest остаётся), `details` пишутся в лог.
- Р.3 п.6: в `sandbox_recovery` публичные `grpc_code_name` (поддерживает вызываемый `code()`), `grpc_details`, `is_sandbox_internal_item`, `iter_exception_chain`, `DEFINITIVE_REJECTION_CODES`. Их используют `classify`, `is_definitive_rejection` и `is_sandbox_internal_error`. Приватных импортов нет.
- Р.3 п.7: `tinvest_read_transient_exhausted` пишется только после повтора. Отказ на первой попытке — `tinvest_read_not_retried` с полем `reason`.
- Р.3 п.8: `adapter.read_worst_case_sec()` = попытки × дедлайн + паузы = 38 с; через неё считается `_position_attempt_estimate`. Функция на уровне модуля: тесты рантайма подменяют класс `TInvestAdapter` целиком. Бюджеты сети держатся: фоновая сверка 55 с, restore 60 с (попытка, которая не влезает, не начинается). Числа повторов не менял.
### 2. Файлы
Новые: `backend/app/broker/tinvest/errors.py`, `tests/unit/test_broker/test_read_retry_codes.py`. Изменены: `adapter.py`, `sandbox_recovery.py`, `common/exceptions.py`, `trading/runtime.py`, `trading/engine.py` (докстринги), `test_adapter_full.py`, `test_adapter_deadlines.py`.
### 3. Тесты
- RED р.3 (прогон на состоянии р.2): 15 failed / 43 passed. Например: `AssertionError: Ошибка размещения ордера T-Invest: связь с брокером прервалась при отправке ордера; исход неизвестен…`, `…повторите попытку позже [UNAVAILABLE failed to connect… ipv4:178.130.128.33:443…]`, `assert 3 == 1` (повтор open). Файлы откачены, md5 совпали.
- GREEN: 58/58.
- Мутация: вернул «исход неизвестен» в текст ордера → 4 failed. Откат, md5 совпал.
- Гейты: pytest 3671 passed / 5 xfailed / 0 failed; ruff 0; mypy Success (189); bandit M0/H0. Фронт не менялся: typecheck/lint/build ok (р.2), vitest — на уровне пакета.
### 4. Integration points
✅ `classify` вызывается в `_read_with_retry`, пробах и ордерах; `probe_is_conclusive` — в `detect_*` и `get_instrument_info`; `read_worst_case_sec` — в `runtime.py:_position_attempt_estimate`; `grpc_code_name` — в `sandbox_recovery` и `errors.py`.
### 5. Контракты
API и схемы не менялись, миграции нет.
### 6. Проблемы / документы / находки
- ФТ §7.8 — текст из р.2, «исход неизвестен» заменить на «ответ брокера не получен». ТЗ §5.5 — категории `errors.py`, включая LOCAL.
- Находка: `_fetch_instrument_info_by_figi` внутри `get_real_positions` делает свои унарные вызовы, и в `read_worst_case_sec` они не учтены.
- `CERTIFICATE_VERIFY_FAILED` в `tests/test_trading` остался, TLS не трогал.
- Самопроверка 1–6: записей в БД и уведомлений нет. Тесты идут через `_unary`/`_read_with_retry`. `sleep` вне `timeout`. Вызывающие `is_definitive_rejection`, `is_sandbox_internal_error` и `get_accounts` просмотрены.
### 7. Stack Gotchas
56, 55, 74, 30, 27.
### 8. Новые Stack Gotchas
`str(AioRequestError)` содержит `tracking_id`. `patch("…adapter.TInvestAdapter")` в тестах рантайма ломает classmethod-оценки: оценки держать на уровне модуля.
### 9. Плагины
py_compile; tdd; context7 — metadata SDK (см. р.2): `getattr` с проверкой типа.
