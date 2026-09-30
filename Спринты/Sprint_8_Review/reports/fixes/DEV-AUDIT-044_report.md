## DEV-AUDIT-044 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту
### 1. Что реализовано
- `TransientBrokerError` / `AuthBrokerError` / `NotFoundBrokerError(BrokerError)`; `BrokerTimeoutError` теперь наследует `TransientBrokerError`.
- Новый `app/broker/tinvest/errors.py`: `grpc_failure`, `error_category`, `to_broker_error`. Текст пользователю строится по классу, в квадратных скобках остаются код gRPC и код T-Invest. `tracking_id` пишется только в лог `tinvest_request_error`.
- `_read_with_retry` повторяет только transient-ошибки: UNAVAILABLE, DEADLINE_EXCEEDED, RESOURCE_EXHAUSTED и INTERNAL 70001. Пауза растёт экспоненциально с джиттером ×[0.5,1] и не превышает потолок `delay`. Сумма пауз ≤ прежнего бюджета (≤6 с против 8 с). На RESOURCE_EXHAUSTED повтор идёт не раньше `ratelimit_reset`; если это дольше потолка, повтора нет. `BrokerTimeoutError` по-прежнему не повторяется (030).
- `detect_token_mode`: при обрыве связи — `TransientBrokerError` «Не удалось проверить API-ключ…», а не «ключ отклонён».
- `get_instrument_info`: при ошибке авторизации или обрыве связи — сразу ошибка своего класса, а не «не найден». Итоговый «не найден» — `NotFoundBrokerError`.
- 17 обёрток `BrokerError(f"…: {e}")` заменены на `to_broker_error(e, …) from e`. Отправка и отмена ордера не повторяются, как и раньше.
### 2. Файлы
Новые: `backend/app/broker/tinvest/errors.py`, `backend/tests/unit/test_broker/test_read_retry_codes.py`. Изменены: `backend/app/broker/tinvest/adapter.py`, `backend/app/common/exceptions.py`.
### 3. Тесты
RED: `BrokerError: Ошибка получения позиций T-Invest: (<StatusCode.UNAVAILABLE…>, …, Metadata(tracking_id='3f2b…'…))`; `AssertionError: сетевой сбой выдан за отказ ключа: API-ключ отклонён T-Invest…`; `AssertionError: отказ авторизации выдан за «не найден»: Инструмент SBER не найден` — 15 failed / 2 passed.
GREEN: 17/17. Мутация «вернуть `if not is_sandbox_internal_error(exc): raise`» дала `test_unavailable_is_retried_on_reads` → `TransientBrokerError: … [UNAVAILABLE …]`, падают 4 теста. Мутация откачена, md5 совпадает.
Гейты: pytest 3629 passed / 5 xfailed / 0 failed (первый прогон дал флейк `test_config::test_preflight_normalize_origin_matches_python[sh]`, отдельно зелёный; повторный полный прогон — 0 failed). `tests/unit/test_broker`: 202 (было 185). ruff 0; mypy Success (189); bandit M0/H0; typecheck 0; lint 0; build ok. vitest: фронт не менялся — на уровне пакета.
### 4. Integration points
✅ `adapter.py`: `_read_with_retry:194`, `detect_token_mode:385`, `get_instrument_info:1315`, 17 × `to_broker_error`.
### 5. Контракты
API и схемы не менялись, миграции нет. Статус 502 прежний, меняется только текст `detail`.
### 6. Проблемы / TODO / правки документов
- ФТ §7.8, новый пункт: «Чтение данных брокера (портфель, баланс, счета, операции, статус ордера) при временном сбое (нет связи, лимит запросов, внутренний сбой песочницы) повторяется автоматически с растущей паузой; при исчерпании лимита — не раньше его сброса. Отправка и отмена ордера не повторяются. Ошибка ключа или прав и “не найдено” показываются отдельными сообщениями; обрыв связи не выдаётся за “ключ отклонён”».
- ТЗ §5.5: классы ошибок `errors.py` и правило backoff, как в п.1.
- Новая находка: `detect_trading_rights` при UNAVAILABLE по-прежнему возвращает `False` и навсегда записывает счёт как read-only. В рецепт не входит.
- Устаревший docstring `engine.py:410` («повторы только на 70001»).
- `tests/test_trading` в конце прогона печатает `Handshake failed … CERTIFICATE_VERIFY_FAILED` (реальный gRPC-канал). Мои правки каналов не создают; то, что лог был и до правок, не проверено.
- Самопроверка: 1 — записей в БД нет; 2 — уведомлений нет; 3 — путь `_unary` → `_read_with_retry`, покрыты и старые вызывающие; 4 — `sleep` вне `asyncio.timeout`, бюджеты 009/011 и `GET_ACCOUNTS_TIMEOUT_SEC` не выросли; 5 — все 9 вызывающих `_read_with_retry` просмотрены; 6 — н/п.
### 7. Применённые Stack Gotchas
56, 55, 74, 30.
### 8. Новые Stack Gotchas
`str(AioRequestError)` содержит `Metadata(tracking_id=…)`: SDK не вызывает `super().__init__`, а `args` заполняется всё равно. Кандидат, если его ещё нет в §6.
### 9. Плагины
py_compile (fallback pyright), tdd-скилл, context7 не нужен: API SDK снят из исходников в venv. typecheck как гейт.
