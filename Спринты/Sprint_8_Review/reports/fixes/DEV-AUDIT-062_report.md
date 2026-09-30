## DEV-AUDIT-062 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `create_account`: если тот же пользователь снова добавляет счёт с тем же `(broker_type, account_id)` и другим ключом, ключ перешифровывается (путь 041, новый iv), а `has_trading_rights` пересчитывается. Исход — `key_updated`; тот же ключ даёт `already_connected`, новая запись — `created`.
- Если режим нового ключа не совпадает с `is_sandbox` записи, возвращается 422. Проверка идёт до любой записи.
- Если проба прав не удалась (044), регистрация отклоняется до лока, старый ключ остаётся.
- Записи чужого пользователя с тем же `account_id` не затрагиваются.
- После commit `_forget_replaced_key_state` очищает кэш рублей 027 и FIGI-кэши 045 по счёту. Если старый токен больше нигде не записан, он выводится из работы: `retire_token` снимает с реестра и останавливает его мультиплексор, `forget_rate_limiter` убирает лимитер.
- **Как сессия получает новый токен.** После остановки мультиплексора `_stream_task=None`, и `is_stream_healthy` возвращает False. Watchdog `_recover_stale_streams` (≤60 с) вызывает `ensure_stream` с ключом из БД, то есть уже с новым. Ордера, сверка и баланс берут ключ из БД при каждом вызове.
- `get_accounts(open_sandbox_if_empty=False)` — чтение по умолчанию. `True` передают только `create_account` и `refresh_sandbox_account_id`. `discover` и `test-connection` sandbox-счёт больше не открывают. `_read_with_retry` и запись вне повтора (044) не тронуты.
- Фронт:
  - показывает «Ключ обновлён: …» / «Уже подключены этим ключом: …»;
  - store не дублирует вернувшиеся записи;
  - если счетов пока нет (новый sandbox-ключ), сохранить можно: счёт откроет регистрация.

### 2. Файлы
- Новые: `backend/tests/unit/test_broker/test_account_token_rotation.py`, `frontend/src/components/settings/__tests__/AddBrokerFormKeyRotation.test.tsx`.
- Изменённые (app): `broker/{service,router,schemas,base,sandbox_recovery}.py`, `broker/tinvest/{adapter,multiplexer,rate_limiter}.py`, `market_data/service.py`, `trading/{engine,paper_engine}.py`.
- Изменённые (тесты, под новый контракт): `test_broker_service.py`, `test_audit_s8r_create_account_race.py`, `test_adapter_full.py`, `test_read_retry_codes.py`.
- Изменённые (фронт): `api/brokerApi.ts`, `stores/settingsStore.ts`, `components/settings/AddBrokerForm.tsx`.

### 3. Тесты
- RED: 10 failed / 1 passed. По существу дефекта:
  - discover — `assert [DiscoveredAccount(account_id='SB-NEW'…)] == []`;
  - test-connection — `assert 1 == 0` (accounts_seen);
  - инвалидация — `assert 'fake-old-token-…' not in {…: TInvestStreamMultiplexer}`;
  - остальные — `AttributeError: 'BrokerAccount' object has no attribute 'outcome'`.
- GREEN: 11/11.
- Мутация `if old_token == api_key:` → `if True:` (вернуть пропуск существующей записи): `AssertionError: assert ['already_connected'] == ['key_updated']`, упали 4 теста. Мутация откачена, md5 совпадает.
- Гейты:
  - pytest — 4261 passed / 3 xfailed / 0 failed;
  - ruff — 0; mypy — Success (191 файл); bandit — M0/H0;
  - typecheck, lint, build — ok; vitest — 979 passed.

### 4. Integration points
- ✅ `retire_token`, `forget_rate_limiter`, `forget_figi_misses_for_account`, `forget_fallback_figi_for_account` вызываются из `BrokerService._forget_replaced_key_state`, его вызывает `create_account`.
- ✅ `BrokerAccountRegistered` возвращает `POST /api/v1/broker-accounts`; фронт использует его в `AddBrokerForm`.
- ✅ `open_sandbox_if_empty=True` передают `service.create_account` и `sandbox_recovery._refresh_locked`.

### 5. Контракты
- Ответ `POST /broker-accounts` дополнен полем `registration: created|key_updated|already_connected`, код остаётся 201.
- Сервис `create_account` теперь возвращает `list[AccountRegistration]`.
- Сигнатура `BaseBrokerAdapter.get_accounts(*, open_sandbox_if_empty=False)`.
- Миграции нет.

### 6. Проблемы / предлагаемые правки
- **ФТ §7.7, заменить пункт S8R-AUDIT-101:** «Один реальный счёт брокера подключается у пользователя один раз. Повторное подключение тем же ключом возвращает существующую запись („уже подключён“). Повторное подключение новым ключом (после перевыпуска токена) заменяет ключ и пересчитывает права, интерфейс сообщает „ключ обновлён“. Работающие сессии переходят на новый ключ в течение минуты. Сменить режим счёта (песочница/боевой) новым ключом нельзя. „Обнаружить счета“ и „Проверить подключение“ счёт у брокера не открывают (с 2026-09-30, S8R-AUDIT-062).»
- **ТЗ §4.2 / API:** описать поле `registration` и флаг `open_sandbox_if_empty`.
- **Не сделано:** `has_withdrawal_rights` нигде не вычисляется, пробы для него нет. Новую сетевую пробу выдумывать не стал — это отдельная находка к ФТ §12.2.
- **Новые находки:**
  - (а) стрим, открытый только графиком, после остановки мультиплексора не переоткрывается: `open_stream` не проверяет здоровье записи. Это то же поведение, что при отозванном токене в 061;
  - (б) при `IntegrityError` (второй воркер) замены ключа этого вызова откатываются, исход `already_connected`.
- **Самопроверка:**
  1. Сбой commit — БД и кэши не изменены, инвалидация идёт после commit.
  2. Уведомлений нет.
  3. Тесты проходят через настоящий `TInvestAdapter`, `_read_with_retry` и реальный роутер.
  4. Сети под таймаутом нет.
  5. Вызывающие `get_accounts` (4 шт.) проверены.
  6. Размер ввода ограничен существующей схемой.

### 7. Применённые Stack Gotchas
37 (перечитывание после rollback), 56 (повтор чтений не тронут), 34 (здоровье стрима — по задаче), 48, 59.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile/mypy — ok; pnpm typecheck (`tsc -b`) — ok; context7 не понадобился (новых API сторонних библиотек нет); tdd — скилл `mattpocock-skills:tdd`.

---

## Ревью р.2: исправлено 1–9
1. **Чужой пользователь.** `_tokens_in_use_by_other_users`: запрос по активным записям других пользователей. Токен выводится из работы, только если его не держит ни своя, ни чужая активная запись.
2. **Стрим графика.** `_open_stream_locked`: мёртвая запись (`is_stream_healthy=False`) переоткрывается через `unsubscribe(keep_state=True)` и ключом вызывающего из БД. `needs_subscription` для неё возвращает True (нужен FIGI). Находка (а) закрыта.
3. **Гонка со старым токеном.** `retire_token` под `_singletons_lock` ставит отметку в `_terminal_tokens` (sha256, причина «API-ключ счёта заменён новым») и снимает экземпляр с реестра. Если позже вызвать `get_or_create_multiplexer(old)`, он откажет. Отметку снимает `clear_terminal_token` при повторной регистрации того же токена.
4. **Ошибки после commit.** Порядок: commit → сброс (try/except, в лог только тип ошибки) → pay-in только что созданных записей. Pay-in не зависит от того, удался ли сброс.
5. **IntegrityError.** Rollback, затем один повтор тела под тем же локом по свежему чтению; исход считается по сохранённому ключу. Второй конфликт подряд даёт `BrokerError` «повторите подключение».
6. **Форма.** Смена ключа сбрасывает `discoveryDone`, найденные счета и выбор. Пока идёт обнаружение, поле ключа отключено, поэтому гонки «ответ по старому ключу» нет.
7. **Protocol.** `get_accounts(*, open_sandbox_if_empty=False)`.
8. **Лишнее чтение.** Своё множество «ключ ещё используется» считается под локом из уже загруженных строк; расшифровка — один раз на шифротекст (`_TokenReader`). Совсем без расшифровки нельзя: у одного токена в разных регистрациях разные iv, а колонки с отпечатком в схеме нет (нужна была бы миграция).
9. **Роутер.** Возвращает словари из полей `BrokerAccountResponse` плюс `registration`. Валидирует только `response_model`.

- Тесты: +6 backend, +1 vitest; 17/17 и 19/19 своих.
- Мутация п.1 (проверять только своего пользователя): `test_old_token_used_by_other_user_is_not_retired` падает с `assert None is <TInvestStreamMultiplexer …>`. Мутация откачена, md5 совпадает.
- Гейты: pytest 4267 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (191 файл); bandit M0/H0; typecheck, lint, build — ok.
- Дополнительно изменён файл `backend/app/market_data/stream_manager.py` (п.2).
