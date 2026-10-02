## DEV-AUDIT-043 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту (worktree wt-s8r-fixes-c, HEAD 9efb76e, не закоммичено)
### 1. Что реализовано
- Политика нового пароля (`NewPassword`): ≥ 12 символов, буква и цифра. Действует на регистрацию, создание пользователя админом и смену пароля. Вход и текущий пароль политикой не проверяются.
- `GET /auth/setup-status` отдаёт `password_policy`. SetupPage и ProfileSettingsPage берут правило оттуда (`utils/passwordPolicy.ts`).
- Login: у несуществующего логина пароль проверяется против dummy-хеша (тот же `PasswordHasher`, хеш считается один раз при импорте). У заблокированной учётки пароль тоже проверяется. «Нет пользователя», «неверный пароль» и «заблокирован» дают один 401 с одним текстом; причина пишется в журнал и лог. Ветка 423 убрана на бэке и фронте.
- Джоба `cleanup_revoked_tokens`: раз в сутки и сразу после старта, удаляет строки с `expires_at < now`, идемпотентна.
- `POST /users/me/disclaimer/accept`: условный UPDATE (если поле пусто) и аудит `user.disclaimer_accepted` в одной транзакции. Поле `disclaimer_accepted_at` есть в `/auth/me` и `/users/me`.
- Гейт: без принятого дисклеймера `POST /trading/sessions` отвечает 403 `error_code=disclaimer_required`. Пауза и resume не гейтятся.
- Фронт: шаг «Риски» мастера вызывает accept (при ошибке остаётся на шаге). Если мастер пройден, а дисклеймер не принят, показывается `DisclaimerModal` с тем же текстом (`disclaimerText.ts`).
- E2E: мок профиля дополнен полем дисклеймера; `realLogin` и beforeAll в auth-hardening принимают дисклеймер; добавлен мок accept.
### 2. Файлы
Новые: `test_auth_schemas.py`, `test_revoked_tokens_cleanup.py`, `test_users_router.py`, `test_start_requires_disclaimer.py`, `passwordPolicy.ts`, `DisclaimerModal.tsx`, `disclaimerText.ts` + 3 vitest-файла.
Изменённые: `auth/{schemas,service,router}.py`, `common/{audit,exceptions}.py`, `scheduler/service.py`, `trading/router.py`, `users/{router,schemas}.py`, SetupPage, LoginPage, ProfileSettingsPage, FirstRunWizard(+Gate), usersApi, authStore, 3 e2e-файла. В 22 тест-файлах фикстура `"password123"` заменена на `"password1234"`. Поправлены тесты, где ожидался 423 или старт сессии шёл без дисклеймера.
### 3. Тесты
RED: `E assert 0 == 1` (verify не вызван), `PermissionError: Аккаунт заблокирован`, `AttributeError: … no attribute 'cleanup_revoked_tokens'`, `assert 200 == 403`, `KeyError: 'password_policy'`, `ImportError … PASSWORD_MIN_LENGTH`.
GREEN: все тесты карточки.
Мутации:
- убрал dummy-verify → `E assert 0 == 1`;
- убрал гейт → `assert 200 == 403` (3 failed).

Обе откачены, md5 сверен.
Гейты: pytest **4644 passed / 1 xfailed / 0 failed**; ruff 0; mypy Success (193); bandit 0; typecheck 0; lint 0; build ok; vitest **1037 passed**.
### 4. Integration points
✅ `main.py:218` → `scheduler.start()` → джоба регистрируется (`scheduler/service.py:193`); ✅ users_router `main.py:431` (Depends(get_current_user), CSRF глобальный); ✅ обработчик `DisclaimerRequiredError` в `register_exception_handlers`; ✅ `<DisclaimerModal>` в Gate (App.tsx:85); ✅ `acceptDisclaimer()` в FirstRunWizard и DisclaimerModal.
### 5. Контракты
`setup-status.password_policy{min_length,max_length,require_letter,require_digit,description}`; `UserResponse.disclaimer_accepted_at`; `POST /users/me/disclaimer/accept → {ok, disclaimer_accepted_at}`; 403 `{detail, error_code:"disclaimer_required"}`; login 423 удалён. Миграция не нужна.
### 6. Проблемы / правки документов
- ФТ §2.1: «Пароль нового пользователя и при смене — не менее 12 символов, хотя бы одна буква и одна цифра; вход со старым паролем сохраняется (S8R-AUDIT-043)».
- ФТ §12.1: «Форма входа не сообщает о блокировке — ответ тот же, что при неверном пароле».
- ФТ §18.1: «Принятие фиксируется на сервере (`disclaimer_accepted_at` + аудит); без него запуск новой торговой сессии отклоняется; прошедшим мастер раньше показывается блокирующее окно».
- ТЗ §7.1: 8 → 12.
- ТЗ §4.1: убрать `Error 423`, добавить `password_policy`.
- ТЗ §4.x (users): новый эндпоинт accept.
- ТЗ, таблица джоб: `cleanup_revoked_tokens` — «каждые 24 ч от старта + при старте».
- CLAUDE.md, раздел «стенд»: после wizard/complete добавить `POST /api/v1/users/me/disclaimer/accept`.

Находки:
- Класс `AccountLockedError` и его обработчик больше не используются (оставлены: на них есть test_exceptions).
- Текст дисклеймера в мастере не совпадает с текстом ФТ §18.1.

Самопроверка 1–6: при сбое commit accept ничего не пишет (аудит в той же транзакции); уведомлений нет; тесты идут через HTTP; таймаутов нет; у `login` один вызывающий; длина пароля ограничена 128.
### 7. Stack Gotchas
26, 30, 40, 47, 60.
### 8. Новые
Нет.
### 9. Плагины
py_compile/mypy, `pnpm typecheck` (tsc -b), tdd-скилл; context7 не понадобился (стандартные `AfterValidator`/`IntervalTrigger`).

---

## DEV-AUDIT-043 — правки по код-ревью оркестратора (раунд 2)
Статус: ✅ готово к коммиту (не закоммичено; HEAD 9efb76e)

### По пунктам
1. Выборка пользователя при входе идёт с `options(noload("*"))`: «лишние» SELECT по selectin-связям ушли.
2. В каждой ветке отказа одна транзакция: UPDATE users + INSERT audit_log + COMMIT. В ветках «нет пользователя» и «заблокирован» делается UPDATE того же вида без изменения значений (у неизвестного логина он затрагивает 0 строк). Сбой commit дают rollback и тот же 401 (решение 086 п.7 сохранено). Цена: в такой попытке теряется инкремент счётчика. Ветка «деактивирован» (верный пароль) по-прежнему пишет журнал отдельной сессией.
3. В `DisclaimerModal` добавлена кнопка «Выйти» (`logout` стора).
4. Интерцептор `apiClient`: 403 `disclaimer_required` ставит `authStore.disclaimerRequired`, Gate открывает модалку. После accept флаг сбрасывается. Если `refreshUser()` вернул null, дисклеймер принятым не считается: на следующей навигации идёт перепроверка (`pathname` в зависимостях эффекта).
5. Гейт перенесён в `TradingService.start_session` (`_require_disclaimer`): владелец определяется по стратегии версии, проверка стоит после 404 по владению. Из роутера проверка убрана. Resume и restore не затронуты.
6. SetupPage разбирает 422 по `loc`: username → «Имя пользователя: от 3 до 50 символов», password → описание политики, прочее → «Проверьте введённые данные».
7. LoginPage: 401 → единый текст; 429 → «Слишком много попыток, повторите через N с» (Retry-After); 5xx и сеть → «Сервер недоступен, повторите позже».
8. В `passwordPolicy.ts` добавлен `DEFAULT_PASSWORD_POLICY` (fallback, когда политика не загрузилась). ProfileSettingsPage при 422 по `new_password` показывает описание политики.
9. Argon2 verify (вход и смена пароля) выполняется через `asyncio.to_thread`. Dummy-хеш считается лениво при первом использовании, в потоке.
10. `AccountLockedError`, его обработчик и тест удалены; добавлен тест, что класса нет.
11. `DISCLAIMER_TEXT` — дословно ФТ §18.1 (сверено со строкой 1082).

### Тесты
RED:
- `{'bad': [SELECT×4, UPDATE, COMMIT, …], 'unknown': [SELECT, INSERT, COMMIT]}`;
- `no attribute '_dummy_hash'`;
- `DID NOT RAISE DisclaimerRequiredError`;
- `hasattr(…AccountLockedError)` → True;
- 14 vitest × (новые кейсы).

GREEN: всё. Мутации (откат через бэкап, md5 сверен):
- снят `noload` → unknown `[SELECT, UPDATE, INSERT, COMMIT]` против `[SELECT×4, …]`;
- отдельный commit счётчика → `'bad': [SELECT, UPDATE, COMMIT, INSERT, COMMIT]`;
- снят `_require_disclaimer` → `assert 200 == 403`.

Затронутые фикстуры: в `tests/test_trading/conftest.py::test_user` и в seed `test_audit_s8r_delete_strategy_race.py` добавлен `disclaimer_accepted_at`.

### Гейты
pytest **4648 passed / 1 xfailed / 0 failed**; ruff 0; mypy Success (193); bandit 0; typecheck 0; lint 0; build ok; vitest **1051 passed** (148 файлов).
⚠️ Первый полный прогон pytest завис примерно на 40% (процесс 0% CPU, область `tests/test_trading/test_stream_gap.py` / `test_ai/test_budget_ceiling.py`, не auth). Параллельно шёл pytest другого DEV в `wt-s8r-fixes`. Процесс снят, повторный прогон с `faulthandler_timeout=120` прошёл целиком за 6:40. Похоже на флейк под нагрузкой; файлы этих тестов не менялись.

### Не сделано / находки
- Хеширование нового пароля (`_hash_password` в register и смене пароля) осталось в event loop: ревью п.9 касался только verify.
- Подпись чекбокса в модалке и мастере («Я прочитал и понимаю риски…») отличается от ФТ §18.1 («Я прочитал и принимаю условия»): ревью п.11 касался только текста.
- Предложенные правки ФТ/ТЗ — из раунда 1. Дополнительно для ТЗ §4.1 login: «429 — Retry-After; сбой записи журнала — тот же 401».

---

## DEV-AUDIT-043 — раунд 3 (хвосты)
Статус: ✅ готово к коммиту (не закоммичено)
1. Хеширование нового пароля (`bootstrap_first_user`, `register` в т.ч. админом, `change_password`) — `_hash_password_async` → `asyncio.to_thread`. Тест `test_argon2_hash_off_event_loop`: RED `AssertionError: [8499993984, …]` (все 3 hash в потоке цикла) → GREEN.
2. Подписи по ФТ §18.1: чекбокс «Я прочитал и принимаю условия» (мастер и `DisclaimerModal`), кнопка шага «Риски» в мастере — «Принимаю» (в модалке уже была). vitest: RED 2 × → GREEN.
Гейты: точечный pytest (auth_service, auth-роутеры, admin, users, audit_log_events, versioning) — passed; ruff 0; mypy Success (193); typecheck 0; lint 0; vitest 1052 passed (148). Полный pytest не запускался (по указанию).

---

## DEV-AUDIT-043 — раунд 4
Статус: ✅ готово к коммиту (не закоммичено)
1. Счётчик: `_register_failure` — один `UPDATE … SET failed_login_count = CASE(истёкшая блокировка→1, иначе +1), locked_until = CASE(≥max→until, иначе NULL) WHERE username AND не заблокирован RETURNING id`; успех — `UPDATE … WHERE id AND не заблокирован RETURNING is_active` (0 строк → 401 «locked»; деактивированному CASE не сбрасывает). Снимок из SELECT не используется. Тесты (файловая SQLite, `gather`): 4 параллельных → 4; max+3 → ровно max + блокировка; верный пароль при блокировке → 401; блокировка между SELECT и решением → 401.
2. Ветки отказа: UPDATE+аудит+commit в одном try → rollback+лог, тот же 401. Тест: OperationalError на UPDATE («нет пользователя», «неверный пароль») → 401, журнал пуст.
3. `updated_at=User.updated_at` в обоих UPDATE; остаточная разница I/O описана в докстринге `login`. Тест: у заблокированной учётки `updated_at` не меняется.
4. `warm_dummy_password_hash()` в lifespan (до `init_db`, в потоке); ленивый — запасной путь. Тест через lifespan.
5. Гейт на `resume` (`TradingService.resume_session`); пауза и restore не гейтятся. Тест: resume → 403 `disclaimer_required`, после принятия → 200.
6. Флаг ставится из 403, только если в сторе нет `disclaimer_accepted_at`; `markDisclaimerAccepted` (мастер и модалка) снимает флаг и помечает профиль. vitest: поздний 403; принятие через мастер.
7. Gate: флаг отмены в cleanup (незавершённая загрузка перезапускается). vitest: logout посреди загрузки.
8. LoginPage — общий `retryAfterMs` (экспорт из `session.ts`); vitest с HTTP-датой.
9. Docstring `admin/router.py` обновлён.

RED: `assert 1 == 4`, `'ok' == 'Неверный…'`, `OperationalError … database is locked`, `updated_at` изменился, `_dummy_hash is None`, `200 == 403`, 4 vitest ×.
Мутации: ORM-инкремент (read-modify-write) → `assert 1 == 4`; снят гейт resume → `200 == 403`.
Гейты: pytest **4655 passed / 1 xfailed / 0 failed**; ruff 0; mypy Success (193); bandit 0; typecheck 0; lint 0; build ok; vitest **1056 passed**.
Решение вне списка: сбой БД на reset-UPDATE после ВЕРНОГО пароля — 503 (как у успешного входа), не 401.

---

## DEV-AUDIT-043 — раунд 5 (финальный)
Статус: ✅ готово к коммиту (не закоммичено; ФТ/ТЗ/гайд не трогал)
1+2. Сбой записи при входе — `DatabaseBusyError` → 503 «База данных временно занята…» + Retry-After во ВСЕХ ветках (нет пользователя / неверный / заблокирован / деактивирован / успех: reset-UPDATE и commit). «Сбой журнала → 401» (086 п.7) заменён; тест 086 переписан на 503. Тест: OperationalError на UPDATE и на COMMIT → 4 ветки дают один `(503, текст)`, cookie нет. Мутация «отказ → 401» → `{(401,…),(503,…)}` красный.
5. Rehash: `ph.check_needs_rehash` → новый хеш (в потоке) пишется тем же reset-UPDATE. Тест на хеше t=1/m=8192.
6. Гейт: `_require_disclaimer(version_id|session_id)` — один JOIN (TradingSession→)StrategyVersion→Strategy→User; владелец не найден → 404 (fail-closed). Тест (владелец удалён) — для start и resume.
7. Интерцептор 403: `refreshUser()`; свежий профиль без принятия или null → флаг; принят → нет. vitest: 3 сценария.
8. Gate: повтор загрузки только после ошибки и не чаще 30 с; запрос в полёте навигация не отменяет; результат отбрасывается только после logout (generation). vitest: навигация во время загрузки → 1 запрос, результат применён; повтор после ошибки — по интервалу.

RED: `{(401,…),(503,…)}`, хеш не изменился, `DisclaimerRequiredError` вместо 404, 5 vitest ×.
Гейты: pytest **4658 passed / 1 xfailed / 0 failed**; ruff 0; mypy Success (193); bandit 0; typecheck 0; lint 0; build ok; vitest **1058 passed**.
Решение вне списка: несуществующая версия при `start_session` теперь 404 из гейта («Владелец стратегии не найден») раньше прочих проверок.
