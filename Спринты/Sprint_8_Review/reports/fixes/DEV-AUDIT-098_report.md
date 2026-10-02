## DEV-AUDIT-098 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes`, база `1e45465`, не закоммичено)
### 1. Что реализовано
- CLI `revoke_admin` (алиас `revoke-admin`): идемпотентна. Последнего активного админа разжаловать нельзя (exit 1): проверка и снятие идут одним `UPDATE … WHERE EXISTS(другой активный админ)`, поэтому гонки нет. Неактивные админы не считаются.
- Оба CLI: `sqlite3.Error`/`SQLAlchemyError` → `Database error: <текст драйвера>`, exit 1, без traceback и без SQL.
- Избранное: не больше 100 записей на пользователя → 422 «Достигнут лимит избранного — 100 записей…». Повтор существующего значения работает как раньше, строки сверх лимита не удаляются. Фронт показывает текст сервера (`favorites-error`).
- `initial_capital` = `_initial_at(end_d)`. `BalanceHistoryPoint` хранит Decimal.
- `Ticker`: запрещён `..`; `/` и `%` в разрешённые символы не входят.
### 2. Файлы
Изменены: `backend/app/{cli/users.py, cli/backup.py, user_favorites/service.py, account/schemas.py, account/service.py, common/ticker.py}`, `frontend/src/{stores/userFavoritesStore.ts, components/charts/FavoritesPanel.tsx, components/charts/__tests__/FavoritesPanel.test.tsx}`.
Новые: `tests/unit/test_cli/{__init__,test_audit_s8r_users}.py`, `tests/test_backup/test_audit_s8r_cli_db_errors.py`, `tests/test_routers/test_audit_s8r_{favorites_limit,detect_schema}.py`, `tests/unit/test_account/test_audit_s8r_initial_capital.py`.
### 3. Тесты
RED: `invalid choice: 'revoke_admin' (choose from 'grant_admin')`; `sqlite3.OperationalError: database is locked`; `AssertionError: {"id":101,…"value":"NEWT"…}`; `('..', '{"detected_count":0,"actions":[]}')`; `assert Decimal('150000.10') == Decimal('100000.10')`.
GREEN: 28 тестов карточки + 214 в смежных наборах.
Мутации:
- `if is_active:` → `if False:` в `users.py` → `test_audit_s8r_users.py:112 assert 0 == 1`;
- фронт: `getApiErrorMessage` → `e.message` → `Expected element to have text content`.
Обе откачены из бэкапа, md5 совпали.
Гейты: pytest 4863 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (195); bandit M0/H0; typecheck 0; lint 0; build ok.
vitest: 1108 passed / 1 failed. Упал `StrategyEditPageDelete` «Удалить все…» — к правке не относится; отдельно прошёл 2/2 дважды. Флейк S8R-FIX-005.
### 4. Integration points
✅ `users.py:188` → `_revoke_admin`; `user_favorites/service.py:106` (лимит, через `add` → router); `account/service.py` (точки и `/full`); `ticker.py:59` (все схемы с `Ticker`); `FavoritesPanel.tsx` читает `error` из store.
### 5. Контракты
Миграции нет.
- `POST /user-favorites/{kind}` → новый ответ 422.
- JSON `/balance/history` не изменился: деньги по-прежнему числами.
- `/full`: `initial_capital` теперь по активным сессиям.
### 6. Проблемы / ФТ-ТЗ / находки
- **Отступление от развилки 4.** `BalanceHistoryPoint` — это и ответ ПОДКЛЮЧЁННОГО `/balance/history`: виджет проверяет `typeof trading_pnl === 'number'`, и 10+ тестов ждут числа. Поэтому внутри Decimal, а в JSON число (`PlainSerializer(float, when_used="json")`, как `DecimalAsNumber`). Если нужна строка — отдельная правка виджета.
- `BEGIN IMMEDIATE` из карточки уже убран в 092.
- Тесты избранного и detect положены в `tests/test_routers/`, где есть фикстуры: каталогов из рецепта нет.
- Лимит мягкий: при одновременных POST возможна 101-я запись.
- `is_valid_ticker` (стрим, 058) по-прежнему пропускает `..`. В URL ISS он не идёт.
- Гайд §3.4, после `grant_admin`: «Снять права: `python -m app.cli.users revoke_admin <username>` (последнего активного админа — нельзя, exit 1).»
- ТЗ §11.12: «`initial_capital` (`/full`) — сумма по сессиям, активным на сегодня; деньги в точках — Decimal, в JSON числом».
- ТЗ, таблица §4 у `POST /user-favorites/{kind}`: «≤ 100 на пользователя, иначе 422».
- Самопроверка: 1 — новых записей статуса нет (UPDATE+commit, при сбое exit 1); 2 — уведомлений нет; 3 — CLI через `main`/подпроцесс, HTTP; 4 — таймаутов нет; 5 — вызывающие `get_balance_history`: два эндпоинта, сравнение `> 0` работает с Decimal; 6 — лимит добавлен.
### 7. Применённые Stack Gotchas
1, 19, 37, 60, 81.
### 8. Новые Stack Gotchas
Нет.
### 9. Плагины
py_compile/mypy; `pnpm typecheck` (tsc -b); context7 (pydantic `PlainSerializer when_used`); скилл `mattpocock-skills:tdd`.

---
## DEV-AUDIT-098 — раунд 2 ревью
Статус: ✅ готово к коммиту (не закоммичено)
1. Избранное: лимиты по видам — инструменты ≤ 100, таймфреймы ≤ 20. Проверка и вставка — один условный `INSERT … SELECT … WHERE NOT EXISTS(дубль) AND count < limit`; 0 строк и нет дубля → 422. Фронт `syncTimeframeFavorites`: сначала DELETE вытесненного, POST только после ответа; если DELETE не прошёл, POST не уходит. Откат — по факту ответов, применяется к текущему состоянию. `setFavoriteTimeframes` переведён на тот же хелпер.
2. `revoke_admin`: всё решение в одном UPDATE (`username AND is_admin AND (NOT is_active OR EXISTS другой активный админ)`). При 0 строк — перечитать: нет пользователя → 1, уже не админ → 0, иначе отказ.
3. Общий `app/cli/_errors.py` для users и backup. Печатается только `exc.orig` у `StatementError`/`DBAPIError` и текст `sqlite3.Error`; у прочих — имя класса; пустой текст → имя класса.
4. `load()`/`remove()` → `getApiErrorMessage`.
5. `/full` `initial_capital` — число в JSON, в схеме есть описание «капитал активных сессий»; фронт-тип `number`.
6. `iss_path(*segments)` (`broker/moex_iss/client.py`, публичное имя: импортируется из трёх модулей) отклоняет `.`/`..` и всё вне `[A-Za-z0-9._-]`. Через него идут все 7 путей с тикером (клиент, облигации, корп. действия). `is_valid_ticker` и `Ticker` — тот же запрет (`is_dot_path_like`).

RED: параллельные POST → `{"id":105,…NEW0…}` (несколько 201); `[0, 1] == [0, 0]` (параллельный revoke); `'100000.10' == 100000.1`; 5/5 vitest, например `'Request failed with status code 503'`; ImportError `_errors`/`iss_path`.
Мутации (откачены, md5 сверены):
- счёт отдельно от INSERT → `test_audit_s8r_favorites_limit.py:166` (лишние 201);
- POST параллельно с DELETE → `expected "vi.fn()" to not be called`;
- `str(exc)` в хелпере → `"bind failed…" == 'bad bind value'`.

Гейты: pytest 4900 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (196); bandit M0/H0; typecheck/lint/build 0; vitest 1114 passed.
Сообщения CLI оставлены английскими, как у `grant_admin`.

---
## DEV-AUDIT-098 — раунд 3 ревью (финальный)
Статус: ✅ готово к коммиту (не закоммичено)
1. Избранное, сервер: timeframe — по enum `Timeframe`, иначе 422; лимит 20 убран. instrument — тип `Ticker` (upper-case) и лимит 100 через условный INSERT. `remove` формат не проверяет: старые значения можно удалить.
2. Фронт: `marketDataStore.ts` побайтово равен `1e45465`. В сторе осталось только `getApiErrorMessage`. Откат неудачного `remove` возвращает значение на исходную позицию.
3. Ошибки раздельно: `errors.instrument` / `errors.timeframe`. Сбрасываются успешной операцией того же вида; ошибка `load` ставится обоим видам. Панель показывает только `errors.instrument`.
4. Один алиас `DecimalAsNumber` в `app/common/money.py` (сериализация числом всегда, как было у market_data). `MoneyAsNumber` удалён.
5. `_errors.py`: перехватываются только `DBAPIError` и `sqlite3.Error`. InvalidRequestError, ArgumentError и PendingRollbackError пробрасываются.

RED: `('garbage1', '{"id":1,…}')`; 6× `DID NOT RAISE` (InvalidRequestError/ArgumentError/PendingRollbackError); ImportError `DecimalAsNumber`; vitest 5×, например `[A, C, B] ≠ [A, B, C]`.
Мутация п.1: без проверки `Timeframe` → `test_audit_s8r_favorites_limit.py:84 ('garbage1', …)`; откачена, md5 совпал.
Гейты: pytest 4907 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (196); bandit M0/H0; typecheck/lint/build 0; vitest 1115 passed.
Находка: `Ticker` переводит в верхний регистр — фьючерс `SiZ6` сохранится как `SIZ6`, и панель (`includes(currentTicker)`) его не узнает.

---
## DEV-AUDIT-098 — находка «регистр тикера в избранном»
✅ В `app/common/ticker.py` добавлен `TickerExact`: проверка формата `Ticker` (включая `.`/`..`), регистр не меняется. Избранное (`instrument`) использует его, остальные места `Ticker` не тронуты. RED: `assert 'SIZ6' == 'SiZ6'` → GREEN. Точечные тесты: 194 passed (SiZ6/RIZ6/BRF7 сохраняются как пришли); ruff 0, mypy Success (196).

---
## S8R-FIX-056 (в рамках 098) — `Ticker` без upper-case
✅ `normalize_ticker` проверяет формат (`[A-Za-z0-9._-]{1,20}`, запреты `.`/`..`/`/`) и возвращает значение как пришло. `TickerExact` удалён. `is_valid_ticker` (стрим/WS) использует те же `TICKER_RE` и `is_dot_path_like`.
Потребители:
- график, sparkline, инструмент, облигации, бэктест, сессии, алерты, избранное — значение как пришло;
- `/corporate-actions/detect` — явный `.upper()`: корп. действия бывают только у акций и облигаций, их тикеры всегда в верхнем регистре, а сверка с позициями идёт по строке.

`sber` — осознанно, как до 065: ISS к регистру нечувствителен (проверено живым запросом: `sber` → SECID `SBER`, `SIZ6` → `SiZ6`), резолв FIGI T-Invest сравнивает в upper. Минус — отдельный ключ кэша свечей для `sber`.
Тесты (HTTP, ISS замокан на `_request`): `SiZ6` → путь ISS, кэш и бэктест — `SiZ6`; `sber` → ISS `sber.json`, ответ `SBER`. Тесты 065 обновлены. Мутация: вернуть `.upper()` → 3 failed.
Гейты: pytest 4946 passed / 1 xfailed / 0 failed; ruff 0; mypy Success; bandit 0; typecheck/lint/build 0; vitest 1115.
Находки:
- `market_data/service.py` (`_resolve_lot_size`, `ensure_figi_lookup`, `get_or_fetch_logo_isin`), logo-эндпоинт и алерты сами переводят тикер в верхний регистр: для фьючерсов поиск в БД по `SIZ6` промахивается, срабатывает fallback T-Invest.
- Свечи ISS для фьючерсов идут в `engines/stock` — пути `futures` нет.

---
## Откат FIX-056 — состояние «098 раунд 3»
✅ `normalize_ticker` снова переводит в верхний регистр и проверяет формат; запреты `.`/`..` сохранены. `TickerExact` нет, избранное на общем `Ticker`.
Восстановлены из `1e45465`: `backtest/schemas`, `trading/schemas`, `market_data/router`, `corporate_actions/router`, `test_api.py`, `test_schemas_ticker_pattern.py`. Удалены `test_audit_s8r_ticker_case.py` и тесты `SiZ6`. `ticker.py` и `market_data/schemas.py` пересобраны от `1e45465` с правками только 098.
Набор файлов совпадает с раундом 3.
Гейты: pytest 4907 passed / 1 xfailed / 0 failed (как в раунде 3); ruff, mypy, bandit 0; typecheck/lint/build 0; vitest 1115.
Отступление: `is_valid_ticker` оставлен на своём `_TICKER_RE` (смешанный регистр, S8R-AUDIT-058) плюс `is_dot_path_like`, как было в раунде 3. Общий `TICKER_RE` принимает только верхний регистр и сломал бы стрим фьючерсов `SiZ6`.
