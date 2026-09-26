## DEV-AUDIT-003 отчёт — S8R fixes, MEDIUM (итерация 3)
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Переоткрытие стрима sandbox→prod в `stream_manager` **убрано** (файл возвращён к HEAD). Токен стрима выбирает `select_market_data_account` того, кто открывает стрим (prod-first).
- `select_market_data_account(db, user_id, preferred_account_id, sandbox, account_id)` — единственная точка выбора. Порядок: prod → счёт сессии → `id`. Условия: ключ и iv NOT NULL; `account_id` задаёт ровно один счёт (FIGI); без `user_id`/`account_id` — `None`.
- Если у пользователя есть tinvest-счёт без ключа или iv — warning `tinvest_account_without_credentials`. Для него же вернулись понятные сообщения: «Брокерский аккаунт без ключей» (график) и «missing encrypted credentials» (свечи).
- Расшифровка — один хелпер `decrypt_market_data_token`. Мёртвые проверки «ключа нет» убраны из лотности, ISIN, FIGI, свечей, рантайма и роутера.
- Лот: prod → ISS → устаревший authoritative-кэш → sandbox. Лот песочницы в общий кэш не пишется никогда.
  - sandbox-сессия: лот песочницы принимается и strict-путём, раньше устаревшего кэша (это множитель её ордеров);
  - real/paper strict: песочница не запрашивается;
  - ленивый путь: устаревший кэш важнее лота песочницы.
- CB передаёт `user_id` и `session` (из сессии берётся режим).
- `corporate_actions`: лот и владелец определяются один раз на тикер до цикла (`_ticker_lot_fallback`), `_position_units` теперь синхронный.
- Владелец сессии — один хелпер `strategy_version_owner_id`, на него делегирует `SessionRuntime._resolve_user_id`. `_figi_account` удалён: FIGI идёт через `select_market_data_account(account_id=…)`.

### 2. Файлы
- `app/`: `market_data/{service,router}.py`, `trading/{runtime,engine,risk_monitor,service}.py`, `corporate_actions/service.py`, `notification/telegram_webhook.py`, `tax/service.py`.
- В `circuit_breaker/engine.py` изменены только строки 511–515.
- Тесты: `test_token_selection.py` (16 тестов) и 9 файлов с правкой сигнатур моков.

### 3. Тесты
- RED (итерация 1): `AssertionError: без контекста расшифрован чужой токен: [1]`.
- Мутация «real-сессия принимает sandbox-лот» → `Failed: DID NOT RAISE LotSizeUnavailableError` (`test_real_session_strict_never_asks_sandbox`). Откачена из бэкапа, md5 совпал.
- pytest (`faulthandler_timeout=300`): 3548 passed / 7 xfailed / 0 failed.
- ruff 0; mypy Success (188); bandit 0.
- vitest: фронт не менялся — снимается на уровне пакета.

### 4. Integration points
✅ Всё подключено:
- `service.py`: 241 / 511 / 831–840 / 1065 / 1220–1230 / 1370–1380 / 1463–1469;
- `router.py`: 178–186;
- `runtime.py`: 1302 / 1311 / 4115;
- `corporate_actions/service.py`: 441 / 523.

### 5. Контракты
API и схемы не менялись, миграции нет.

### 6. Документы, ограничения, самопроверка
- **ФТ §7.7:** «Рыночные и справочные данные (свечи, поток, размер лота, ISIN) запрашиваются ключом самого пользователя — сначала боевого счёта, затем песочницы; ключи других пользователей не используются. Размер лота, полученный ключом песочницы, не сохраняется в справочник и используется только сессиями песочницы; реальная и бумажная торговля его не принимают. Идентификатор бумаги для сверки берётся ключом счёта сессии. Счёт без ключа отмечается в журнале (с 2026-09-26, S8R-AUDIT-003).»
- **ТЗ §5.6:** `select_market_data_account`, `decrypt_market_data_token`, `tinvest_accounts_without_credentials`, `strategy_version_owner_id`. Лот: prod → ISS → устаревший кэш → sandbox (authoritative только для `mode=sandbox`, без кэша; strict real/paper песочницу не спрашивает).
- **Ограничение (многопользовательский режим):** общий стрим `(ticker, tf)` открывается токеном первого открывшего — сессии или графика. Если первым был пользователь только с песочницей, остальные получают свечи его контура до переоткрытия стрима. В однопользовательской поставке это всегда prod, если он есть.
- **Endpoint:** адаптер `target` не задаёт, контур переключает только `sandbox_token` (влияет на `SandboxService`). Здесь сделано так же; `INVEST_GRPC_API_SANDBOX` вживую не проверен.
- **Самопроверка:**
  1. Записей в БД не добавилось.
  2. Уведомлений нет.
  3. Тесты идут по реальным путям, путь без контекста покрыт.
  4. `wait_for` не менялся.
  5. Вызывающие изменены осознанно.
  6. Н/п.

### 7. Stack Gotchas
Применены 30 и 57. Кандидат в новую ловушку: мок с жёсткой сигнатурой при новом kwarg подвешивает тест-гонку, а не роняет её.

### 9. Плагины
- py_compile по всем изменённым файлам `app/`.
- tdd.
- SDK сверен по исходникам в venv.
