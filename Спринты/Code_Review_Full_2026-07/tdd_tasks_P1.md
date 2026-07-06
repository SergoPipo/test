# TDD-задачи P1 — High (исправить до сдачи)

Развёртка 68 High-находок в задачи по веткам. Формат — test-first: где это баг/уязвимость, сначала пишется падающий тест/PoC, затем фикс; где это качество/рефактор — критерий готовности через рефактор + зелёные тесты + гейты типов + (для UI) Playwright без регресса.

> **Grounding:** «Проблема» и «Fix» под каждым ID взяты дословно из [code_review_full_report.md](code_review_full_report.md). Статус верификации — из [verification_P1.md](verification_P1.md). Приоритеты и полный список — [backlog_fixes.md](backlog_fixes.md).

## Общий Definition of Done (для каждой задачи)
1. Репро-тест/PoC падает **до** фикса (для багов/уязвимостей).
2. Фикс по рекомендации, минимальный, в рамках пункта.
3. Тест зелёный после; для уязвимостей — эксплуатация отклонена.
4. Гейты: `pyright`/`tsc --noEmit` = 0 в затронутых файлах; `pytest --cov-fail-under=80`; security → `bandit`/`safety` без новых Medium+.
5. Существующие тесты модуля зелёные; для UI — Playwright-скриншот затронутого экрана.
6. Запись в `changelog.md` спринта приёмки.

> **Порядок относительно P0:** ветки `be-trading`, `be-authz-idor`, `be-auth`, `be-notification`, `be-broker` пересекаются с P0 (C1–C6) — мержить P1-ветку **после** соответствующей P0-ветки, чтобы не решать одно дважды. Дубли помечены в примечаниях веток.

## Ветки (сводка)

| Ветка | Тема | Пунктов |
|---|---|:--:|
| `fix/be-authz-idor` | Backend: авторизация / IDOR (сквозная) | 5 |
| `fix/be-auth-session` | Backend: аутентификация / сессии | 3 |
| `fix/be-broker` | Backend: брокерская интеграция (T-Invest) | 2 |
| `fix/be-trading` | Backend: торговый движок | 9 |
| `fix/be-strategy` | Backend: стратегии / кодоген | 3 |
| `fix/be-backtest` | Backend: бэктест | 4 |
| `fix/be-market-data` | Backend: рыночные данные / стримы | 5 |
| `fix/be-notification` | Backend: уведомления | 2 |
| `fix/be-ai` | Backend: AI-модуль | 2 |
| `fix/be-runtime` | Backend: circuit breaker / sandbox / scheduler | 3 |
| `fix/be-misc` | Backend: admin / tax / corporate actions / common | 3 |
| `fix/fe-security` | Frontend: хранение токенов / security | 4 |
| `fix/fe-network` | Frontend: сетевой слой / типы | 4 |
| `fix/fe-charts` | Frontend: графики | 3 |
| `fix/fe-backtest-ui` | Frontend: бэктест-компоненты | 4 |
| `fix/fe-core-refactor` | Frontend: ядро / рефакторинг god-компонентов | 8 |
| `fix/fe-ui-misc` | Frontend: strategy / trading / прочий UI | 4 |


---

## `fix/be-authz-idor` — Backend: авторизация / IDOR (сквозная) (5)

**Роль:** Backend-разработчик (security). Закрыть контроль доступа на эндпоинтах чтения/мутаций и WS-каналах.
**Файлы:** `backend/app/`, `backend/app/backtest/`, `backend/app/notification/`, `backend/app/trading/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** Пересекается с P0-веткой `fix/trading-authz-integrity` (C2). AUTHZ-05 = дубль C1, AUTHZ-06 = дубль C3 — при закрытии P0 отметить как выполненные.

### AUTHZ-02 · `backend/app/trading/router.py:101` · ✅ подтверждено
**IDOR: пауза/возобновление чужой торговой сессии без проверки владельца**
- **Проблема:** `PATCH .../sessions/{session_id}/pause` (router.py:108 → `service.pause_session(session_id)`) и `.../resume` (router.py:118 → `service.resume_session(session_id)`) не передают `user_id`; методы service.py:516/521 и `engine.pause_session`/`resume_session` грузят сессию через `_get_session` без фильтра по владельцу. Атакующий перебором `session_id` может поставить на паузу активную стратегию жертвы (сигналы блокируются — управляемый саботаж торговли) либо возобновить остановленную сессию. В отличие от `get_session`/`delete_session`, `user_id` здесь вообще не участвует.
- **Fix:** Добавить `user_id` в `pause_session`/`resume_session` и проверять принадлежность сессии (JOIN `StrategyVersion→Strategy.user_id`) до смены статуса; чужая сессия → 404.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### AUTHZ-03 · `backend/app/trading/router.py:188` · ✅ подтверждено
**IDOR-чтение: история сделок и статистика P&L чужой сессии**
- **Проблема:** `GET .../sessions/{session_id}/trades` (router.py:199 → `service.get_trades`) и `.../stats` (router.py:227 → `service.get_stats`) вызывают методы service.py:713 и 746, фильтрующие `LiveTrade` только по `session_id`, без `user_id`. Аутентифицированный пользователь, подставив чужой `session_id`, читает все сделки, объёмы, цены входа/выхода и агрегированный P&L чужой торговой сессии — раскрытие торговой активности другого пользователя. Остальные эндпоинты сессий (positions/close/delete) владельца проверяют, а эти два — нет.
- **Fix:** Добавить `user_id` в `get_trades`/`get_stats` и проверять владельца через существование сессии с JOIN `Strategy.user_id` (по шаблону `get_positions`, service.py:535); чужая сессия → 404.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### AUTHZ-04 · `backend/app/backtest/ws.py:94` · ✅ подтверждено
**Broken access control на мультиплексном /ws: подписка на любой чужой канал**
- **Проблема:** В `/ws` после JWT-аутентификации клиент шлёт `{action:'subscribe', channel:'...'}` и подписывается на `event_bus` по произвольному имени канала без проверки владения (ws.py:92-108). К `user_id` привязывается только буквальный литерал `'notifications'` (ws.py:94-96). Публикаторы: `trades:{session_id}` (service.py:421), `backtest:{id}` (backtest/router.py:244), `notifications:{user_id}` (service.py:279), `system:{user_id}`. Подписавшись на `'trades:42'`, `'backtest:42'` или напрямую `'notifications:42'` (ID последовательные int), атакующий в реальном времени получает ордера/филлы/P&L чужих сессий, прогресс/результаты чужих бэктестов и чужие уведомления. `'notifications:42'` ≠ `'notifications'`, remap не срабатывает.
- **Fix:** Валидировать каждую подписку: `trades:{sid}`/`backtest:{id}` — проверять владельца в БД; `notifications` строить как `notifications:{user_id}`, запретив явные `notifications:{N}`/`system:{N}`.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### AUTHZ-05 · `backend/app/notification/router.py:428` · ✅ подтверждено
**Обход аутентификации Telegram-webhook при пустом TELEGRAM_WEBHOOK_SECRET**
- **Проблема:** `POST /api/v1/notifications/telegram/webhook` сверяет `secret_header = header('X-...-Secret-Token', '')`; `if secret_header != handler.webhook_secret: 403` (router.py:427-430). `TELEGRAM_WEBHOOK_SECRET` по умолчанию `''` (config.py:23). При выставленном `TELEGRAM_BOT_TOKEN`, но пустом секрете сравнение `''!=''` → `False` → проверка проходит без заголовка, вебхук открыт для любого. Атакующий подделывает `Update` с `effective_chat.id` жертвы и `/closeall` + callback `confirm_closeall` → закрытие всех реальных позиций жертвы (telegram_webhook.py:691), либо `/close`, спуфинг сообщений. Сравнение к тому же не constant-time.
- **Fix:** Не поднимать handler при пустом `webhook_secret` (`_get_webhook_handler` → `None`/503) либо отклонять запрос при пустом секрете. Сравнение — `secrets.compare_digest`.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### AUTHZ-06 · `backend/app/config.py:13` · ✅ подтверждено
**Дефолтный SECRET_KEY только предупреждает — риск подделки JWT и захвата аккаунтов**
- **Проблема:** `SECRET_KEY='dev-secret-key-change-in-production'` задан по умолчанию (config.py:13), а валидатор `check_production_secrets` (config.py:78-91) при `DEBUG=False` лишь выдаёт `warnings.warn`, не прерывая старт. Тем же ключом подписываются все access-JWT (middleware/auth.py:21), им же аутентифицируются WS и `AdminAuthASGIMiddleware`. При развёртывании с дефолтным ключом атакующий сам подписывает токен `{sub:<любой user_id>, type:'access'}` и выдаёт себя за любого, включая `is_admin=True` (`get_current_user` грузит юзера из БД по `sub`) — полный доступ к чужим деньгам и админ-зоне.
- **Fix:** При не-DEBUG останавливать запуск (`raise`), если `SECRET_KEY`/`ENCRYPTION_KEY` начинаются с `dev-` или короче 32 байт, вместо `warnings.warn`.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.


---

## `fix/be-auth-session` — Backend: аутентификация / сессии (3)

**Роль:** Backend-разработчик. Жизненный цикл токенов (refresh/logout/CSRF) и гейты конфигурации.
**Файлы:** `backend/app/`, `backend/app/auth/`, `backend/app/middleware/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** CFG-BE-02 и AUTHZ-06 — дубли C3 (дефолтные ключи), закрываются в P0.

### CFG-BE-02 · `backend/app/config.py:13` · ✅ подтверждено
**Дефолтные значения SECRET_KEY и ENCRYPTION_KEY — предсказуемые строки, отсутствие жёсткого блока запуска в production**
- **Проблема:** `SECRET_KEY = 'dev-secret-key-change-in-production'` и `ENCRYPTION_KEY = 'dev-encryption-key-change-me-32b'` используются как дефолты, если `.env` отсутствует или их не переопределяет. `check_production_secrets` (строки 78–91) при `DEBUG=false` лишь вызывает `warnings.warn(...)`, не бросает исключение и не блокирует старт. `SECRET_KEY` подписывает JWT (auth/service.py:151-152, middleware/auth.py:21, admin/dash_mount.py:114) — предсказуемый ключ даёт подделку токена, включая claim `is_admin`. `ENCRYPTION_KEY` используется в CryptoService (crypto_helpers.py:13, common/crypto.py:14-30, HKDF→AES-256-GCM) для шифрования API-ключей брокера — с известным ключом злоумышленник, получивший доступ к БД (например через backup), расшифрует T-Invest токены пользователей. Дополнительно deployment_guide.md (строки 69–70) велит задать переменную `MASTER_KEY`, тогда как поле в Settings называется `ENCRYPTION_KEY`; из-за `extra="ignore"` (config.py:76) при точном следовании гайду `MASTER_KEY` молча игнорируется, а `ENCRYPTION_KEY` остаётся дефолтным без единой ошибки — это не гипотетический, а воспроизводимый сценарий провала конфигурации.
- **Fix:** Заменить `warnings.warn` на `raise RuntimeError` при `not DEBUG` и SECRET_KEY/ENCRYPTION_KEY, начинающихся с `dev-`. Дополнительно проверять минимальную энтропию/длину. Синхронизировать имя переменной в deployment_guide.md с реальным полем Settings (`ENCRYPTION_KEY`, не `MASTER_KEY`). В docker-compose добавить проверку на старте контейнера, что `backend/.env.production` существует и не содержит дефолтных значений.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-AUTH-02 · `backend/app/middleware/csrf.py:26` · ✅ подтверждено
**/auth/refresh не в EXEMPT_PATHS — в production каждый refresh токена падает с 403 и пользователь разлогинивается**
- **Проблема:** `EXEMPT_PATHS` содержит только login/setup/health. Оба frontend-клиента делают refresh «голым» axios без interceptor'а, добавляющего `X-CSRF-Token` (`client.ts:83` `doRefresh`, `aiStreamClient.ts:16`). В production фронт и бэк на одном origin за nginx, поэтому браузер автоматически прикладывает cookie `csrf_token` (ставится на `/login`) к `POST /api/v1/auth/refresh`. Middleware видит «cookie есть, header нет» → 403 «CSRF token отсутствует». `doRefresh` молча ловит ошибку и возвращает null → через 30 минут (TTL access-токена) пользователь тихо разлогинивается, все запросы падают. В dev это не воспроизводится (cross-origin 5173→8000, cookie не отправляется), поэтому баг проявляется только на проде. Верификация подтвердила цепочку по файлам: `csrf.py:26/46-54`, `router.py:132-140`, `client.ts:63-69/83`, `aiStreamClient.ts:16`, `nginx.conf`.
- **Fix:** Добавить `/api/v1/auth/refresh` в `EXEMPT_PATHS` (эндпоинт аутентифицируется refresh-токеном в JSON-теле, CSRF-атака через form-submit ему не грозит). Дополнительно/альтернативно — в `doRefresh` и `aiStreamClient` слать `X-CSRF-Token` из cookie.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-AUTH-03 · `backend/app/auth/router.py:174` · ✅ подтверждено
**Logout не отзывает refresh-токен, а refresh не ротируется — сессию невозможно принудительно завершить**
- **Проблема:** `POST /auth/logout` заносит в `RevokedToken` только jti access-токена из заголовка Authorization (`router.py:157-178`, `service.py:105-112`). Refresh-токен (TTL 7 суток) имеет собственный независимый jti (`service.py:136-149`, `uuid4`, связи между jti нет) и никогда не отзывается — предъявить его в теле `/logout` физически невозможно. `AuthService.refresh_token` (`service.py:74-91`) проверяет отзыв использованного jti, но при успешном обмене не ротирует и не отзывает старый refresh — один и тот же refresh-токен можно предъявлять многократно все 7 дней. Дополнительно `refresh_token()` не проверяет существование пользователя, `is_active` и `locked_until` — заблокированный или деактивированный аккаунт продолжает получать свежие токены (в отличие от `get_current_user`, не используемого в `/refresh`). `change_password` также не отзывает ранее выданные токены. Сценарий: refresh-токен утёк (localStorage на общем компьютере, XSS, лог) → пользователь нажимает «Выйти», считая сессию завершённой, → злоумышленник продлевает доступ бесконечной цепочкой refresh'ей — для торгового терминала с деньгами это критичный разрыв между ожидаемой и фактической семантикой logout.
- **Fix:** В `/auth/logout` принимать `refresh_token` (или хранить связь access↔refresh по user_id) и заносить его jti в `RevokedToken`. В `refresh_token()` реализовать ротацию: отзывать jti использованного refresh при выдаче новой пары и детектировать повторное использование. Проверять в `refresh_token()` существование пользователя, `is_active` и `locked_until`. При смене пароля инвалидировать все активные токены (например, `token_version` в payload, сверяемый в `get_current_user`).
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.


---

## `fix/be-broker` — Backend: брокерская интеграция (T-Invest) (2)

**Роль:** Backend-разработчик (broker). Требует context7 по tinkoff-investments. `/code-review` обязателен (критический путь).
**Файлы:** `backend/app/broker/tinvest/`, `backend/app/common/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** Крипто-ключ (BE-BROK-02) пересекается с C3 — согласовать с веткой be-auth.

### BE-BROK-01 · `backend/app/broker/tinvest/multiplexer.py:197` · ✅ подтверждено
**Мультиплексор маршрутизирует свечи только по figi, игнорируя interval — подписчики получают свечи чужого таймфрейма**
- **Проблема:** Докстринг заявляет мультиплексирование «по ключу (figi, interval)», но `self._routes` ключуется только по figi, и `is_first = len(self._routes[figi]) == 0` решает, отправлять ли серверную SUBSCRIBE, без учёта interval. `_dispatch_candle` раздаёт свечи всем listener'ам figi независимо от их interval. Сценарий: график SBER 5m уже подписан (первая подписка, сервер шлёт 5m); затем live-сессия/график 15m того же тикера подписывается на interval=1m для агрегации — SUBSCRIBE 1m на сервер не уходит (`is_first=False`), и callback сессии получает 5m-свечи, интерпретируя их как минутные. Агрегатор строит 15m-бары из искажённых данных → неверные торговые сигналы. В обратном порядке (сначала 1m) 5m-график рисует минутные бары как пятиминутные. UNSUBSCRIBE при этом шлёт interval последнего ушедшего listener'а, который может не совпадать с фактической серверной подпиской — отписка не срабатывает. Аналогичная проблема и в начальной переподписке после reconnect (`_resubscribe_all`/`_request_iterator` берут interval только первого listener'а).
- **Fix:** Ключевать маршруты по `(figi, interval)`: `self._routes[(figi, interval)]`, `is_first` проверять для пары, в `_dispatch_candle` сопоставлять `response.candle.interval` с interval подписчика. SUBSCRIBE/UNSUBSCRIBE отправлять по паре `(figi, interval)`, только когда не осталось listeners именно этой пары; поправить `_resubscribe_all` и `_request_iterator` аналогично. Добавить regression-тест на две одновременные подписки разного interval на один figi.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-BROK-02 · `backend/app/common/crypto.py:14` · ✅ подтверждено
**Production может незаметно работать с публичным dev-ключом шифрования — брокерские токены расшифровываются известным ключом**
- **Проблема:** `CryptoService` принимает любой `master_key` без проверки стойкости; ключ берётся из `settings.ENCRYPTION_KEY` с публичным дефолтом `"dev-encryption-key-change-me-32b"`. Оператор, развернувший production без `ENCRYPTION_KEY` в `.env`, получает лишь предупреждение в логах (легко пропустить), и все `encrypted_api_key`/`encrypted_api_secret` в `broker_accounts` шифруются публично известным ключом. Любой, кто получит `terminal.db` или его копию из бэкапов (BackupService делает ежедневные копии), расшифровывает боевые T-Invest токены и может торговать от имени пользователя — прямой риск потери денег.
- **Fix:** В `check_production_secrets` при `DEBUG=false` заменить `warnings.warn` на `raise RuntimeError` (fail-fast) для `SECRET_KEY` и `ENCRYPTION_KEY` с dev-префиксом. В `CryptoService.__init__` валидировать минимальную длину/энтропию `master_key` (>= 32 байт) и добавить фиксированную соль в HKDF. Рассмотреть ротацию ключа с версионированием (`key_id` в записи).
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.


---

## `fix/be-trading` — Backend: торговый движок (9)

**Роль:** Backend Core (trading). TDD обязателен. Деньги — Decimal. `/code-review` обязателен.
**Файлы:** `backend/app/trading/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** Строить поверх P0-ветки `fix/trading-authz-integrity` (C2/C6 меняют те же файлы) — мержить после неё.

### BE-TRAD-03 · `backend/app/trading/engine.py:904` · ✅ подтверждено
**Exit-сигнал стратегии никогда не закрывает позицию — блокируется `max_concurrent_positions`**
- **Проблема:** W8b exit-bypass в runtime.py:1334 пропускает Circuit Breaker для сигнала, противоположного открытой позиции, но дальше `OrderManager.process_signal` считает открытые сделки и при `open_trades >= max_concurrent_positions` (default 1) возвращает `None` ДО определения направления сигнала. Стратегия, открывшая BUY и на следующей свече давшая SELL (exit), молча теряет сигнал (`logger.debug max_positions_reached`). Позиция закрывается только по SL/TP или вручную; если SL/TP не заданы, RiskMonitor NULL-уровни пропускает — позиция висит бессрочно с неограниченным убытком. Даже при `max_concurrent_positions > 1` сигнал открыл бы новую встречную сделку, а не закрыл существующую — netting/exit-закрытие не реализовано нигде (`PositionTracker.update_position` нигде не вызывается).
- **Fix:** В `OrderManager.process_signal` перед проверкой лимита позиций определять exit-кейс (открытая filled-сделка противоположного направления) и вызывать `close_position` для неё вместо создания новой `LiveTrade`. Лимит `max_concurrent_positions` применять только к entry-сигналам. Покрыть тестом сценарий buy→sell→позиция закрыта.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-TRAD-04 · `backend/app/trading/runtime.py:246` · ✅ подтверждено
**Каждое intra-bar обновление свечи обрабатывается как закрытый бар**
- **Проблема:** ТЗ и docstring требуют сигнальный цикл «на каждой закрытой свече», но `multiplexer.py` подписывается без `waiting_close` (default False в SDK) — T-Invest шлёт обновление формирующейся свечи на каждой сделке, а `_SessionListener._handle_candle` не проверяет смену timestamp бара. Следствия: (1) `history.append` на каждый тик — при лимите 200 реальная история для SMA/RSI вытесняется десятками копий одного формирующегося бара, индикаторы считаются неверно и расходятся с бэктестом; (2) стратегия исполняется по незакрытому бару многократно — сигнал может сработать на внутрибарном всплеске, которого нет в закрытой свече; (3) для агрегированных ТФ (15m/1h/4h) `_AggregatingCandle.update` публикует частичную свечу периода на каждом событии. При `cooldown_seconds=0` (default) от повторных входов спасает только `max_concurrent_positions`.
- **Fix:** Подписываться с `waiting_close=True` либо в `_handle_candle` детектировать закрытие бара по смене `period_start` и запускать сигнальный цикл только на новом баре; обновления текущего бара — только обновлять последний элемент истории. Для агрегатора публиковать отдельное событие `candle.closed` при смене периода.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-TRAD-05 · `backend/app/trading/runtime.py:1010` · ✅ подтверждено
**Сверка позиций real-сессий при рестарте не выполняется никогда**
- **Проблема:** `_check_real_positions` возвращает `False` («расхождений нет»), если `not account.encrypted_api_secret`. Но T-Invest — single-token контракт, `encrypted_api_secret` для него всегда NULL (это явно задокументировано в этом же файле в `_resolve_broker_credentials`, где аналогичный guard уже был удалён как блокировавший стрим на всех T-Invest аккаунтах в проде). Таким образом для 100% real-аккаунтов сверка позиций с брокером после рестарта backend — мёртвый код. Если backend лежал, а пользователь тем временем закрыл позицию через приложение брокера — после рестарта `restore_all` не увидит расхождение, сессия возобновится с фантомной filled-позицией: RiskMonitor будет «закрывать» несуществующую позицию по SL/TP, статистика и торговля работают по неверному состоянию.
- **Fix:** Убрать `not account.encrypted_api_secret` из условия (достаточно `encrypted_api_key + encryption_iv`), как уже сделано в `_resolve_broker_credentials`. Добавить тест: real-сессия + аккаунт без `api_secret` → сверка выполняется.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-TRAD-06 · `backend/app/trading/paper_engine.py:172` · ✅ подтверждено
**Paper-портфель: покупка не списывает средства, ручное закрытие зачисляет выручку «из воздуха»**
- **Проблема:** В production paper-flow (`OrderManager.process_signal`, engine.py:996-1005) сделка заполняется мгновенно без обращения к `PaperBrokerAdapter` и без изменения `PaperPortfolio` — деньги при покупке не списываются и не блокируются. Единственный код, дебетующий портфель (`PositionTracker.on_order_filled`), нигде не вызывается в production (dead code). При этом ручное закрытие вызывает `paper place_order(sell)`: `balance += exit_price × quantity`, причём `quantity` в лотах, без `lot_size`. Итог: каждый цикл buy→manual close увеличивает баланс на всю выручку без списания стоимости покупки; закрытия по SL/TP (`RiskMonitor._apply_close`) портфель вообще не трогают. `PaperPortfolio.balance/peak_equity` — фикция, а от них зависит расчёт equity/drawdown в Circuit Breaker — защита по просадке на paper фактически не работает.
- **Fix:** Ввести единый учёт: при paper-fill в `process_signal` списывать `balance -= entry_price × lots × lot_size`; при любом закрытии (manual, SL/TP, close_all) кредитовать `exit_price × lots × lot_size`. Удалить или подключить `PositionTracker` (сейчас dead code). В `paper_engine.place_order` учитывать `lot_size`.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-TRAD-07 · `backend/app/trading/engine.py:1465` · ✅ подтверждено
**Ручное закрытие pending-сделки (entry_price=NULL) записывает фиктивную прибыль**
- **Проблема:** `close_position` допускает `status='pending'`. У pending-сделки `entry_price=NULL`. Если в `OHLCVCache` есть цена, `exit_price` = рыночная цена, а `RiskMonitor._apply_close` подставляет `entry = trade.entry_price or Decimal('0')`. Для buy-направления `pnl = (exit − 0) × lots × lot_size` — вся номинальная стоимость позиции записывается как прибыль. Сценарий: sandbox-ордер завис в pending, пользователь видит его как открытую позицию и жмёт «Закрыть» — в `LiveTrade.pnl` и `DailyStat.pnl` попадает фиктивная прибыль в размере полной стоимости позиции; дневная статистика и проверки Circuit Breaker по дневному убытку искажаются.
- **Fix:** Для сделок с `entry_price=NULL` не считать PnL (оставить NULL) и помечать `'failed'/'cancelled'` вместо `'closed'`, предварительно попытавшись отменить ордер у брокера. В `_apply_close` добавить guard: при `entry <= 0` не вычислять pnl.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-TRAD-08 · `backend/app/trading/engine.py:929` · ✅ подтверждено
**Нарушение границ: FIGI для sandbox/real-сделок берётся из paper-заглушки**
- **Проблема:** `process_signal` для любого режима создаёт `PaperBrokerAdapter` и вызывает его `get_instrument_info` — заглушку, всегда возвращающую `figi=f"paper_{ticker}"`. В результате `LiveTrade.figi = "paper_SBER"` даже для sandbox/real-сделок, хотя комментарий S5R closeout #9 требует реальный FIGI для матчинга позиций. При рестарте backend с активной real-сессией `_check_real_positions` строит `broker_figi_map` по настоящим FIGI брокера, ищет `trade.figi='paper_SBER'`, не находит и делает ложный вывод «позиция закрыта у брокера» — `trade.status='closed'` с `exit_price=0`, сессия уходит в паузу, хотя реальная позиция жива. Настоящий `TInvestAdapter.get_instrument_info` существует, но здесь не используется.
- **Fix:** Для sandbox/real получать FIGI через реальный брокерский адаптер (или MarketDataService/кэш instruments), `PaperBrokerAdapter` использовать только при `mode='paper'`. Как минимум — не записывать заглушечный `paper_*` FIGI в сделки небумажных режимов.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-TRAD-09 · `backend/app/trading/engine.py:938` · ✅ подтверждено
**Проглоченный `except Exception` при получении lot_size — молчаливый fallback на 1 даёт 10-кратный оверсайз позиции**
- **Проблема:** В `process_signal`: `except Exception: lot_size = 1` — без единой строки лога. При недоступности источника lot_size (T-Invest/ISS упали, сеть, битый кэш) расчёт размера позиции для `fixed_sum` считает `cost_per_lot = price × 1` вместо `price × 10` (для SBER, GAZP и большинства акций MOEX). Пример: sizing 100 000 ₽, SBER по 300 ₽, реальный лот 10 — корректно 33 лота (~99 000 ₽), при fallback — 333 лота (~999 000 ₽), то есть 10-кратный перерасход реальных денег без следа причины в логах. Аналогичные молчаливые проглатывания есть в engine.py:932-933 (figi), engine.py:1514-1515, service.py:448-449, 575-576, 586-587.
- **Fix:** Логировать каждое такое исключение (`logger.error` с ticker и session_id). Fallback на `lot_size=1` для расчёта размера позиции недопустим — при неудаче получения lot_size пропускать сигнал (`return None`) с публикацией `order.error`, а не торговать на заведомо неверном множителе.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-TRAD-10 · `backend/app/trading/router.py:102` · ✅ подтверждено
**IDOR: пауза/возобновление чужой торговой сессии без проверки владельца**
- **Проблема:** `PATCH /sessions/{session_id}/pause` и `/resume` вызывают `service.pause_session(session_id)`/`resume_session(session_id)` без `user_id`. Методы сервиса и `TradingSessionManager` резолвят сессию через `_get_session` по `session_id` без фильтра владельца. Атакующий, перебирая `session_id`, может поставить на паузу чужую активную сессию (жертва перестаёт получать сигналы/сделки) либо возобновить приостановленную жертвой сессию (несанкционированный перезапуск live-торговли на реальном счёте).
- **Fix:** Пробросить `current_user.id` в `pause_session`/`resume_session` и добавить owner-check через JOIN `StrategyVersion → Strategy.user_id` (как в `delete_session`), `NotFoundError` при чужой сессии.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-TRAD-11 · `backend/app/trading/router.py:189` · ✅ подтверждено
**IDOR-чтение: раскрытие всех сделок чужой сессии (цены, объёмы, P&L)**
- **Проблема:** `GET /sessions/{session_id}/trades` вызывает `service.get_trades(session_id=...)` без `user_id`. `get_trades` фильтрует `LiveTrade` только по `session_id`, ownership не проверяется. Атакующий, перебирая `session_id`, получает полную историю чужих сделок с чувствительными полями: `entry_signal_price`, `entry_price`, `exit_price`, `volume_lots`, `volume_rub`, `pnl`, `pnl_pct`, `broker_order_id`, `stop_loss`, `take_profit`. Соседние методы (`get_positions`, `close_position`, `close_all_positions`) этот фикс уже получили (S7R-SECURITY), `get_trades` — нет.
- **Fix:** Добавить `current_user.id` в `get_trades` и предварительно проверять принадлежность сессии (JOIN на `Strategy.user_id`), как в `get_positions`/`get_session`; `NotFoundError` при несоответствии.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.


---

## `fix/be-strategy` — Backend: стратегии / кодоген (3)

**Роль:** Backend-разработчик (strategy). Внимание к двум форматам blocks_json (BE-STRAT-02).
**Файлы:** `backend/app/strategy/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** BE-STRAT-01 (out-of-process sandbox для exec) — переклассифицированный из P0; крупная архитектурная задача, вести отдельным эпиком.

### BE-STRAT-02 · `backend/app/strategy/router.py:244` · ✅ подтверждено
**Два несовместимых формата blocks_json: «Применить из Grid Search» молча не меняет поведение бэктеста/live**
- **Проблема:** В модуле сосуществуют две схемы `blocks_json`: flat-list (`{"blocks":[{"type":"indicator",...}]}` — её понимают `params.py`/`params_sync.py`) и реально сохраняемый фронтендом Blockly workspace (`{"blocks":{"languageVersion":0,"blocks":[{"type":"indicator_rsi","fields":{...}}]}}` — её понимает `ir.parse_blocks`). Детекторы рассинхронизированы: `has_meaningful_blocks` видит только flat, `parse_blocks` — только Blockly. Основной сценарий (версии из Blockly-редактора): IR-ветка не берётся; в legacy-пути `sync_blocks_params` получает dict вместо list, `walk_indicators` итерирует ключи словаря и ничего не патчит — новая версия получает патченный `generated_code`, но старые блоки. Бэктест (`runtime_backtrader_code` приоритизирует `blocks_json`) и live-интерпретатор (`trading/engine` → `evaluate` по IR) исполняют СТАРЫЕ параметры: юзер выбрал `rsi_period=18` в heatmap → создаётся версия «Применено из Grid Search: rsi_period=18», UI показывает 18 (читает `generated_code`), но каждый новый бэктест этой версии тихо гоняет `rsi_period=14` из старых блоков. Для `stop_loss_pct`/`take_profit_pct` даже warning не показывается — regex-патч `text_description` успевает, и параметр считается синхронизированным. Второй сценарий (flat-блоки): ветка берётся, но `parse_blocks(flat)` даёт пустой IR (`entry_signal` vs `signal_entry`) → `ir_to_backtrader_code` возвращает `_empty_strategy()`; при пустом `source.generated_code` сохранится placeholder «Empty strategy» — реальный код версии теряется, бэктест выполняет пустую стратегию без ошибки.
- **Fix:** Выбрать единый канонический формат (Blockly workspace — его уже понимают IR/бэктест/live) и мигрировать `params.py`/`params_sync.py` на него: extract/replace параметров реализовать поверх `StrategyIR`. `has_meaningful_blocks` заменить на проверку через `parse_blocks` (как в `trading/engine.py`). Для flat-блоков — не заменять `generated_code`, если регенерация дала пустой IR. Добавить интеграционный тест: from-params на версии из редактора → новый параметр виден в regenerated runtime-коде.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-STRAT-03 · `backend/app/strategy/evaluator.py:178` · ✅ подтверждено
**evaluate() игнорирует ir.time_filter — live/paper торговля торгует вне временного окна стратегии**
- **Проблема:** `evaluate()`/`evaluate_series()` не учитывают `ir.time_filter`. В бэктесте фильтр работает: `ir_codegen._gen_next` генерирует проверку временного окна, `parity.py:171` применяет `_in_window`. Но live-путь (`trading/engine.py:498-509`, `_interpreter_process_candle`) вызывает `evaluate(ir, candles)` напрямую и нигде не проверяет тайм-окно (grep `time_filter` по `app/trading` — 0 совпадений; SL/TP в live покрыты `risk_monitor`, `time_filter` — никем). При адверсариальной проверке подтверждено: `evaluator.py:178-228` считают только entry/exit, `time_filter` не читается; `ir.py:138,368-374` — отдельное поле IR, не встроенное в `Condition`; `ir_codegen.py:375-383` генерирует проверку в `next()`; `parity.py:171,182` вызывает `evaluate_series`, затем отдельно фильтрует через `_in_window`; `engine.py:481-524` вызывает `evaluate()` на строке 509 без аналогичной проверки. Сценарий: стратегия с блоком ФИЛЬТРЫ 10:00–14:00 успешно бэктестится с фильтром, но live/sandbox сессия открывает реальные сделки в 18:40 на низколиквидном вечернем рынке, которые стратегия по дизайну должна пропускать — расхождение backtest ↔ live с денежными последствиями.
- **Fix:** Применять `time_filter` внутри `evaluate()`/`evaluate_series()` (модуль объявлен «единственной точкой истины») либо в `_interpreter_process_candle`: если время свечи вне окна — возвращать `'hold'`. Уточнить таймзону сравнения (Europe/Moscow) и покрыть тестом live-путь с фильтром.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-STRAT-04 · `backend/app/strategy/models.py:45` · ✅ подтверждено
**N+1 и eager-загрузка тяжёлых blob-полей на списке стратегий (дашборд)**
- **Проблема:** `GET /api/v1/strategies` (`router.list_strategies`) в цикле вызывает `service.get_instruments_summary` для каждой стратегии — минимум 4 запроса на стратегию (version_ids, все бэктесты, сессии, сделки) плюс отдельный запрос к `OHLCVCache` на каждую пару (ticker, timeframe) в цикле. Дополнительно `Strategy.versions` объявлен с `lazy="selectin"` — любой `select(Strategy)`, включая `get_list`, автоматически подтягивает все версии с Text-столбцами (`blocks_json`, `generated_code`, `text_description`, `ai_chat_history`) — мегабайты данных, которые в ответе списка не используются; то же для `user` (`lazy="selectin"`). При 20 стратегиях и сотнях бэктестов дашборд генерирует 100+ SQL-запросов на каждый poll.
- **Fix:** Убрать `lazy="selectin"` у `Strategy.versions`/`user` (явный `selectinload` там, где версии нужны — `get_by_id` уже делает это). Сводку собирать батчево для всех стратегий: один запрос по бэктестам с агрегатами/оконными функциями, один по сессиям, один по последним свечам (GROUP BY ticker, timeframe); выбирать только нужные колонки, а не ORM-объекты целиком.
- **DoD:** рефактор по рекомендации; существующие тесты модуля зелёные; `pyright`/`tsc --noEmit` = 0; для UI — Playwright без визуального регресса.


---

## `fix/be-backtest` — Backend: бэктест (4)

**Роль:** Backend-разработчик (backtest). Требует context7 по Backtrader.
**Файлы:** `backend/app/backtest/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** AUTHZ-04 (WS access control) пересекается с be-authz-idor.

### BE-BTST-01 · `backend/app/backtest/router.py:1203` · ✅ подтверждено
**GET /backtest/jobs недостижим: маршрут перекрыт /{backtest_id}, эндпоинт возвращает 422**
- **Проблема:** `@router.get("/{backtest_id}")` объявлен на строке 861, а `@router.get("/jobs")` — на строке 1203. Starlette матчит маршруты по порядку регистрации: запрос `GET /api/v1/backtest/jobs` попадает в `/{backtest_id}`, валидация int для строки "jobs" падает, и FastAPI возвращает 422, не пробуя следующие маршруты. Endpoint списка фоновых jobs — недостижимый код. Frontend реально его вызывает (`frontend/src/api/backtestApi.ts:179`, `listJobs` для бейджа фоновых бэктестов в шапке) и получает 422 на каждый опрос. Проблема известна команде и затикечена (S8R-FASTAPI-STATIC-JOBS-PATH, Gotcha 20), тест `test_router_full.py:472` закрепляет 422 как «известное поведение» (`assert in (200, 422)`), но production-код не исправлен. Публичный API-контракт S7 7.17 фактически сломан: восстановить список jobs после перезагрузки страницы через REST невозможно.
- **Fix:** Переместить объявления `GET /jobs`, `GET /jobs/{job_id}` и `POST /jobs/{job_id}/cancel` ВЫШЕ всех маршрутов с `/{backtest_id}` (порядок регистрации в APIRouter решает конфликт), либо задать path-конвертер `/{backtest_id:int}`. После правки ужесточить assert в тесте до строгого 200 и закрыть тикет.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-BTST-02 · `backend/app/backtest/engine.py:101` · ✅ подтверждено
**TradeRecorder жёстко пишет direction="long" — short-сделки искажены и ложно блокируют live через parity-гейт**
- **Проблема:** В `notify_trade` при открытии сделки direction всегда `"long"`, хотя кодогенератор поддерживает short-стратегии (`ir_codegen.py:128,397` — `entry_direction="short"` генерирует `self.sell()`). Последствия: 1) в `BacktestTrade.direction` все сделки помечены `"long"` — UI/CSV/PDF показывают неверное направление; 2) `exit_price` восстанавливается по формуле long (`exit = entry + pnl/size`), для short правильно `exit = entry − pnl/size` — при прибыльном шорте показывается exit ВЫШЕ входа; 3) parity-гейт (`service._run_parity_check → compare_signals`) сравнивает direction из БД (`"long"`) с интерпретатором (`"short"`) — каждая пара даёт SIGNAL-расхождение "direction", допуск к которому не применяется → `parity_signals_match=False` → live-гейт (Task 14, `trading/service.py:155-157`) ложно блокирует ЛЮБУЮ short-стратегию. Направление определяется по знаку `trade.size` при открытии (у short он отрицательный). Цепочка воспроизведена по коду: `service.py:319` кладёт неверный direction в `BacktestTrade`; `parity.py:169-170,317-322,365,397-401` — расхождение строгого SIGNAL-класса без допуска.
- **Fix:** В ветке `trade.isopen` определять направление по знаку размера: `"long" if trade.size > 0 else "short"` (или через атрибут `trade.long`). Формула `exit_price` уже ветвится по direction и станет корректной автоматически. Добавить тест: short-стратегия → `direction="short"`, `exit_price = entry − pnl/size`, parity без direction-расхождений.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-BTST-03 · `backend/app/backtest/ws.py:92` · ✅ подтверждено
**IDOR на мультиплексном WebSocket /ws: подписка на чужие каналы backtest:{id} и trades:{session_id}**
- **Проблема:** После аутентификации по JWT `websocket_endpoint` принимает от клиента произвольную строку канала и вызывает `event_bus.subscribe(effective_channel)` (стр. 104) БЕЗ проверки владельца. Скоупится к пользователю только канал `notifications` (стр. 95-96); `backtest:{id}`, `trades:{session_id}`, `market:{...}` — нет. Сценарий: атакующий шлёт `{"action":"subscribe","channel":"backtest:123"}`, где 123 — id чужого бэктеста (id последовательны, легко перебрать), и получает `backtest.completed` (net_profit_pct, total_trades, sharpe_ratio — `router.py:315-324`) и `backtest.failed` (текст ошибки — `router.py:373-380`) чужого пользователя. Аналогично `trades:{session_id}` раскрывает сделки/позиции чужих торговых сессий — межарендная утечка финданных. Подтверждено: `event_bus.py:44-53` — pub/sub без авторизации; `ws_router` смонтирован в `main.py:359`, мидлвари на `/ws` нет. Отдельный защищённый `/ws/backtest/{job_id}` (`ws_backtest.py:107`) существует, но не устраняет уязвимость общего `/ws`.
- **Fix:** Авторизовать канал при подписке: парсить префикс и проверять владельца по user_id (для `backtest:{id}` — цепочка backtest→version→strategy.user_id как в `_get_backtest_for_user`; для `trades:{session_id}` — владелец сессии). Либо публиковать в user-скоупленные каналы, либо вести allowlist на соединение. Отклонять подписку на неавторизованный канал.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-BTST-04 · `backend/app/backtest/engine.py:508` · ✅ подтверждено
**exec() пользовательского Python (generated_code) в основном процессе за денилист-фильтром**
- **Проблема:** `_compile_strategy` исполняет `exec(compiled, namespace)` над кодом стратегии. Код берётся из `runtime_backtrader_code(blocks_json, generated_code)`: при пустом/битом `blocks_json` (нет entry/exit) идёт fallback на `version.generated_code` (`ir_codegen.py:160-173`), а `generated_code` — свободно задаваемое поле версии (`strategy/service.py:417`, `schemas.py:131`, принимается `POST /strategies/{id}/versions` без AST-проверки). Пользователь может создать версию с `blocks_json=''` и произвольным Python в `generated_code`, запустить бэктест — код исполняется в процессе бэкенда (`run_in_executor(None, ...)` — тред того же процесса, доступ к `SECRET_KEY`, `config.py:13`). Единственный барьер — денилист `ASTAnalyzer` (blacklist имён/модулей/дандеров) + частично урезанные builtins; денилист-песочницы для произвольного Python — известно ненадёжный паттерн. При обходе — кража SECRET_KEY (форж JWT → захват любого аккаунта) и брокерских токенов (реальная торговля). Тот же exec в `grid.py:301/319` внутри worker-процесса. Тесты `sandbox_escape.py` покрывают лишь простые обходы, не гарантируют полноты денилиста.
- **Fix:** Не исполнять stored `generated_code` напрямую: для блочных стратегий генерировать код только детерминированно из IR и убрать fallback на произвольный `generated_code`. Исполнять бэктест в изолированном процессе без доступа к settings/токенам/сети/ФС (seccomp, ограничение ресурсов). Заменить денилист на allowlist AST, запретить объявление dunder-методов.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.


---

## `fix/be-market-data` — Backend: рыночные данные / стримы (5)

**Роль:** Backend-разработчик (market_data). Внимание к aware/naive datetime и границам сессий.
**Файлы:** `backend/app/market_data/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### BE-MKT-01 · `backend/app/market_data/router.py:139` · ✅ подтверждено
**Cross-user: GET /candles ложно триггерит и деактивирует чужие ценовые оповещения произвольной исторической ценой**
- **Проблема:** GET /candles после загрузки свечей вызывает `check_alerts_for_ticker_with_session(db, ticker, candles[-1].close)`, не проверяя, что запрошенный диапазон (`from`/`to`) относится к текущему моменту. В `_check_ticker` алерты выбираются только по `ticker + is_active`, БЕЗ фильтра `user_id` — проверяются оповещения ВСЕХ пользователей. Диапазон `from`/`to` полностью контролирует вызывающий (viewer-режим без T-Invest не требуется). Сценарий: любой аутентифицированный пользователь запрашивает `GET /candles?ticker=SBER&timeframe=D&from=2007-01-01&to=2008-05-01` — `candles[-1].close` становится историческим экстремумом. Все чужие алерты `above`/`below`, пороги которых укладываются в этот экстремум, срабатывают: `is_active=False`, уходит ложное уведомление владельцу, а настоящее срабатывание по актуальной цене больше никогда не произойдёт. Двумя запросами (на максимум и минимум цены) можно массово погасить чужие алерты по тикеру у всех пользователей — потеря реальных торговых сигналов.
- **Fix:** Не проверять алерты из GET-эндпоинта на произвольном историческом диапазоне; проверять только когда `to_dt` близок к `now` и по реальной текущей цене (last price), в идеале — вынести проверку целиком в фоновый монитор по стрим-данным (аналогично figi-пути в multiplexer), убрав её из user-facing viewer-эндпоинта.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-MKT-02 · `backend/app/market_data/service.py:757` · ✅ подтверждено
**MarketDataService коммитит/роллбэчит чужую (injected) сессию в hot-path'ах трейдинга**
- **Проблема:** Сервис получает `AsyncSession` через DI, но сам управляет транзакцией: `ensure_lot_size` (commit на 757, rollback на 760), `_save_to_cache` (пакетные commit на 646/648), `_purge_iss_cache` (commit на 207), `get_or_fetch_logo_isin` (853/864). При этом сервис вызывается с чужой сессией из `trading/engine.py:937`, `trading/service.py:447,585`, `trading/risk_monitor.py:257`, `trading/runtime.py:1509`. Сценарий: трейдинг-движок накапливает в сессии несохранённые изменения позиции, вызывает `ensure_lot_size` для расчёта P&L → TTL кэша истёк → апсерт lot_size и commit фиксируют половину unit-of-work трейдинга; если движок дальше падает и делает rollback — частичное состояние уже в БД. Обратный случай: rollback внутри `ensure_lot_size` стирает накопленные изменения вызывающего кода.
- **Fix:** Убрать commit/rollback из методов, работающих на injected-сессии: либо `flush()` + управление транзакцией на уровне вызывающего кода, либо для внутренних кэш-апсертов (lot_size, logo, ohlcv_cache) открывать собственную короткоживущую сессию через `async_sessionmaker` (как делает prefetch.py), не трогая сессию запроса.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-MKT-03 · `backend/app/market_data/bond_service.py:41` · ✅ подтверждено
**TypeError aware-naive datetime: все bond-эндпоинты падают 500 при любом повторном запросе**
- **Проблема:** `get_bond_info` пишет в `BondInfoCache.updated_at` aware-datetime (`datetime.now(timezone.utc)`), но колонка — обычный `DateTime`; SQLite-диалект SQLAlchemy при записи молча отбрасывает tzinfo, а при чтении возвращает naive. На втором и каждом последующем запросе `age = datetime.now(timezone.utc) - cached.updated_at` вычитает naive из aware → `TypeError`. Исключение не перехватывается → `GET /bonds/{ticker}/info`, `/nkd` и `/coupons` отдают 500 навсегда после первого успешного запроса по тикеру (кэш-строка уже создана и не исчезает, unique по ticker).
- **Fix:** Сравнивать в naive UTC: `now_naive = datetime.now(timezone.utc).replace(tzinfo=None); age = now_naive - cached.updated_at`. Аналогично писать `updated_at` как naive UTC (как уже делает `ensure_lot_size` в service.py, паттерн не унифицирован). Добавить тест на второй вызов `get_bond_info` с существующей кэш-строкой.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-MKT-04 · `backend/app/market_data/service.py:151` · ✅ подтверждено
**_build_current_candle подмешивает сегодняшнюю недостроенную свечу в исторический диапазон, включая бэктест**
- **Проблема:** Блок merge (строки 151–157) выполняется для 1h/4h при любом `mode` и не проверяет, что запрошенный `to_dt` близок к текущему моменту. Rebuilt-свечи строятся от `datetime.now()` и вливаются в результат без фильтра по `[from_dt, to_dt]`. Сценарий: бэктест (`backtest/engine.py:351`, `mode="backtest"`, tf=1h) за период 2025-01-01…2025-06-01 получает в конце массива 1–2 свечи за сегодня, одна из которых незакрытая. Auto-close позиции в конце диапазона исполняется по цене этой случайной свечи вне периода → мусорный и недетерминированный P&L (тот же класс проблемы, что чинился в BUG-18). Также ломает просмотр исторического окна графика.
- **Fix:** Вызывать `_build_current_candle` только если `to_dt` покрывает текущий период (например, `to_dt >= _period_start(now, timeframe)`), и/или после merge фильтровать результат по `from_dt <= ts <= to_dt`. Для `mode="backtest"` достройку текущей свечи отключить полностью.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-MKT-05 · `backend/app/market_data/stream_manager.py:84` · ✅ подтверждено
**Многократный overcount volume в live-агрегаторе из-за interim-обновлений незакрытой минутной свечи**
- **Проблема:** Multiplexer подписывается через `SubscribeCandlesRequest` без `waiting_close` (`multiplexer.py:389`) → T-Invest шлёт промежуточные обновления текущей минутной свечи с кумулятивным объёмом минуты. `_AggregatingCandle.update()` на каждый callback делает `self.volume += candle.volume`, то есть кумулятивные снапшоты одной минуты суммируются повторно: обновления 100→250→400 дают вклад 750 вместо 400, и так каждую минуту. Агрегированные live-свечи 15m/1h/4h получают объём, завышенный в разы. Эти данные идут не только на график, но и в `SignalProcessor` live-торговли (через `trading/runtime.py`) — стратегии с volume-условиями генерируют ложные сигналы на реальных деньгах.
- **Fix:** Хранить объёмы по-минутно: `dict[minute_ts] = candle.volume` (последний снапшот минуты замещает предыдущий), итоговый `volume = sum(dict.values())`. Либо подписываться с `waiting_close=True` для агрегируемых таймфреймов.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.


---

## `fix/be-notification` — Backend: уведомления (2)

**Роль:** Backend-разработчик (notification). Тесты изолировать (см. acceptance-чеклист).
**Файлы:** `backend/app/notification/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** AUTHZ-05 = дубль C1 (webhook), закрывается в P0.

### BE-NOTIF-02 · `backend/app/notification/service.py:286` · ✅ подтверждено
**create_notification держит write-транзакцию SQLite во время сетевых вызовов Telegram/SMTP**
- **Проблема:** Порядок в `create_notification`: `db.flush()` (строка 258, открывает write-транзакцию SQLite) → `dispatch_external(...)` (строка 286, сетевые вызовы Telegram Bot API и `aiosmtplib` с таймаутом 15 с) → `db.commit()` (строка 290, уже после сети). SQLite — single-writer (WAL, `busy_timeout=30000` в `common/database.py:106-107`, подтверждено). Пока SMTP/Telegram отвечают медленно, write-lock удерживается, и остальные писатели — включая торговый движок, сохраняющий ордера и `LiveTrade` в момент события `trade.filled` — получают задержку или «database is locked» после `busy_timeout`. Пример конкретного пересечения в критическом пути: `runtime.py:1091-1107` коммитит паузу сессии, затем на той же сессии вызывается `create_notification` с severity critical, транзакция держится во время `dispatch_external`; `_listen_loop` (строки 581-592) вызывает `dispatch` через `await` без `create_task`, поэтому одна медленная отправка блокирует все последующие уведомления сессии. Дополнительно `create_notification` вызывает `commit()` на переданной извне сессии — вызывающие (scheduler, роутеры) теряют контроль над границей транзакции, их незакоммиченные изменения фиксируются посреди чужой операции.
- **Fix:** Коммитить уведомление до `dispatch_external` (с `channels_sent='in_app'`); внешнюю доставку выполнять после commit — через `asyncio.create_task` или отдельную очередь, `channels_sent` обновлять отдельной короткой транзакцией. Убрать commit чужой сессии — транзакцией должен управлять вызывающий слой, либо всегда работать через `self._db_factory`.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-NOTIF-03 · `backend/app/notification/models.py:51` · ✅ подтверждено
**Нет UniqueConstraint (user_id, event_type) на user_notification_settings — дубликаты навсегда ломают уведомления**
- **Проблема:** Таблица `user_notification_settings` не имеет уникального ограничения на `(user_id, event_type)` ни в модели, ни в миграции `3d3e4e3036a6`, а «upsert» в `router.py:155-169` — неатомарный select-then-insert. При двух конкурентных `PUT /settings/{event_type}` (двойной клик, две вкладки) оба select возвращают `None`, и вставляются две строки. После этого `service.py:267` (`scalar_one_or_none()`) в `create_notification` бросает `MultipleResultsFound` для каждого уведомления этого event_type: в `_listen_loop` ошибка логируется и уведомление теряется, у прямых вызовов (scheduler, price_alert_monitor) — исключение наверх. Дефект самоподдерживающийся: до ручной чистки БД уведомления данного типа молча пропадают.
- **Fix:** Добавить `UniqueConstraint("user_id", "event_type")` в `__table_args__` + alembic-миграцию с предварительной дедупликацией строк. В `router.py` использовать SQLite `INSERT ... ON CONFLICT DO UPDATE` (`sqlalchemy.dialects.sqlite.insert`) вместо select-then-insert. В `create_notification` заменить `scalar_one_or_none` на `first()` как защиту.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.


---

## `fix/be-ai` — Backend: AI-модуль (2)

**Роль:** Backend-разработчик (ai). Проверить контракт сообщений с провайдером (claude-api).
**Файлы:** `backend/app/ai/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### BE-AI-01 · `backend/app/ai/router.py:118` · ✅ подтверждено
**SSRF: неограниченный `api_base_url` отправляет запросы бэкенда на произвольный внутренний хост**
- **Проблема:** Endpoint `POST /api/v1/settings/ai/providers/verify-credentials` принимает поле `api_base_url` (схема ограничивает только `max_length=500`, без проверки схемы/хоста) и сразу создаёт провайдера через `ProviderFactory.create(...)` → `OpenAIProvider`, после чего вызывает `provider.verify()`, выполняющий исходящий HTTP-запрос на `{api_base_url}/chat/completions`. То же происходит при `create/update_provider` (service.py:205,237) и в чате. Любой аутентифицированный пользователь (регистрация открыта через `/auth/setup`) может задать `api_base_url = http://169.254.169.254/latest/meta-data`, `http://localhost:8000/api/v1/admin/...` или `http://10.0.0.5:6379` и заставить сервер обращаться к внутренним сервисам/облачным метаданным. Ответ/ошибка возвращаются клиенту, а `latency_ms` даёт тайминговый оракул для сканирования портов. Проверок на приватные диапазоны (127/8, 10/8, 172.16/12, 192.168/16, 169.254/16, ::1) нет. Подтверждено при верификации: `verify-credentials` (router.py:112-123) требует лишь `get_current_user`; `api_base_url` (schemas.py:60) не проверяет хост; значение передаётся as-is в `ProviderFactory.create` → `OpenAIProvider/CustomProvider(base_url=...)`; `provider.verify()` (openai_provider.py:33-35,103-107) шлёт реальный HTTP POST на `{base_url}/chat/completions`; ответ/error/latency_ms возвращаются клиенту (router.py:124-129). Тот же дефект в `create/update_provider` (service.py:193-237). Фильтрации private/loopback/link-local нигде нет.
- **Fix:** Добавить валидацию `api_base_url`: разрешить только https, резолвить хост и отклонять приватные/loopback/link-local/metadata IP (`ipaddress.is_private/is_loopback/is_link_local`), запретить редиректы на приватные адреса. Лучше — allowlist известных провайдерских доменов. Валидировать в Pydantic и повторно перед запросом (защита от DNS-rebinding).
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-AI-02 · `backend/app/ai/context.py:79` · ✅ подтверждено
**`ContextCompressor` формирует сообщения, начинающиеся с `role=assistant` — Claude API отвергает такой запрос**
- **Проблема:** После сжатия `compress()` возвращает `[{role: 'assistant', content: '[Краткое содержание...]'}]` + последние 3 сообщения. Anthropic Messages API требует, чтобы первое сообщение имело `role='user'` (иначе 400 `invalid_request_error`, «first message must use the "user" role»). Сценарий: пользователь с активным провайдером claude ведёт длинный диалог (история ~320К символов, порог 80% от 100К токенов) → `should_compress()` срабатывает → `compress()` ставит assistant первым → каждый последующий запрос `/api/v1/ai/chat` и `/chat/stream` падает с 400 от Anthropic, превращающимся в `ValidationError «Ошибка AI-провайдера: ...»`. Так как история приходит с клиента и не уменьшается, чат для стратегии становится перманентно неработоспособным именно в тот момент, когда сжатие должно было его спасти. Fallback-ветка (recent_messages при ошибке суммаризации) тоже может начинаться с assistant. Для OpenAI-совместимых провайдеров запрос проходит — дефект абстракции: компрессор генерирует последовательность ролей, невалидную для одного из поддерживаемых провайдеров.
- **Fix:** Выдавать summary как user-сообщение (например, `{role: 'user', content: '[Краткое содержание предыдущего диалога]: ...'}` + `{role: 'assistant', content: 'Принял.'}`), либо переносить summary в system prompt; гарантировать, что `recent_messages` также начинается с `role=user` (сдвигать срез при необходимости). Добавить unit-тест: после `compress()` первый message имеет `role='user'`.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.


---

## `fix/be-runtime` — Backend: circuit breaker / sandbox / scheduler (3)

**Роль:** Backend-разработчик (runtime). TDD обязателен (circuit_breaker). `/code-review` обязателен.
**Файлы:** `backend/app/circuit_breaker/`, `backend/app/sandbox/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### BE-RT-01 · `backend/app/circuit_breaker/engine.py:322` · ✅ подтверждено
**Проверка max_position_size игнорирует lot_size — риск-лимит занижен в 10–100 раз**
- **Проблема:** В `_check_position_size_limit` для режима fixed_lots сумма ордера считается как `signal.price * position_sizing_value` (число лотов), без множителя lot_size. Реальная стоимость ордера в OrderManager: `volume_rub = price × volume_lots × lot_size` (engine.py:962), и там же в комментарии прямо указано, что при игнорировании lot_size сумма занижается в 10×. Пример: у пользователя max_position_size=50 000 ₽, сессия fixed_lots=20 по SBER (лот 10 акций, цена 300 ₽). CB посчитает 300×20=6 000 ₽ и пропустит ордер, а реальная сумма составит 300×20×10=60 000 ₽ — риск-лимит по размеру позиции фактически не работает для всех бумаг MOEX с лотом больше 1 (то есть для большинства акций). Верификация подтвердила полную цепочку: Signal.price — цена за акцию, position_sizing_value для fixed_lots — число лотов, check_before_order вызывается с исходным signal без коррекции на lot_size.
- **Fix:** Получать lot_size через `MarketDataService.ensure_lot_size(session.ticker)` (как это уже делает OrderManager) и считать `order_amount = signal.price × lots × lot_size`; для режимов fixed_sum/percent сверяться с той же формулой, что использует `_calculate_position_size`.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-RT-02 · `backend/app/sandbox/schemas.py:17` · ✅ подтверждено
**timeout в /sandbox/execute не валидируется и не ограничен сверху — DoS общего ThreadPoolExecutor backend**
- **Проблема:** Поле `timeout` в CodeExecuteRequest объявлено как `int | None` с комментарием «секунд, max 30», но без `Field(ge=1, le=30)`. В executor.py:68 `timeout = timeout or self.MAX_EXECUTION_TIME` — верхнего ограничения нет. Любой аутентифицированный пользователь (endpoint доступен без admin-прав) отправляет POST `/api/v1/sandbox/execute` с `timeout=86400` (или больше) и кодом `while True: pass` — `worker.join(timeout)` и `asyncio.wait_for(timeout+2)` честно ждут вплоть до суток и более. Прерывание через `PyThreadState_SetAsyncExc` не прерывает C-код/плотные аллокации, а заявленный лимит памяти MAX_MEMORY=512MB нигде не применяется (нет setrlimit). Несколько параллельных таких запросов исчерпывают общий default ThreadPoolExecutor всего процесса (размер `min(32, cpu+4)`) — зависают все остальные компоненты backend'а, использующие `run_in_executor`; rate-limit для этого пути общий (200/мин), что недостаточно для compute-эндпоинта. Отрицательный timeout уходит в join/alarm с неопределённым поведением. Верификация подтвердила весь путь эксплуатации по коду.
- **Fix:** В схеме задать `timeout: int | None = Field(default=None, ge=1, le=30)`. В `CodeSandbox.execute` дополнительно клампить: `timeout = min(timeout or self.MAX_EXECUTION_TIME, self.MAX_EXECUTION_TIME)`. Исполнять код в изолированном ephemeral-процессе с жёстким лимитом памяти/CPU (resource.setrlimit) вместо общего ThreadPoolExecutor, добавить отдельную строгую категорию rate-limit для `/sandbox`. Также стоит либо реализовать MAX_MEMORY, либо убрать неиспользуемую константу.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-RT-03 · `backend/app/circuit_breaker/schemas.py:18` · ✅ подтверждено
**trading_hours_start/end не валидируются — конфиг произвольной строкой роняет check_before_order на каждом сигнале**
- **Проблема:** CircuitBreakerConfigRequest принимает `trading_hours_start/end` как `str | None` без валидации формата. PUT `/api/v1/circuit-breaker/config` с значением `"10"`, `"abc"` или `"10-00"` успешно сохраняется. Далее в `_check_trading_hours` (engine.py:449-459) выполняется `parts = trading_hours_start.split(":"); time(int(parts[0]), int(parts[1]))` — IndexError/ValueError на каждом вызове `check_before_order`. Исключение вылетает из CB и ловится только широким except в listener (runtime.py:256): каждая свеча логирует ошибку, но ордера не выставляются и пауза CB не ставится — торговый цикл всех сессий пользователя молча «умирает», пока конфиг не будет исправлен вручную.
- **Fix:** Добавить в схему валидатор формата (`Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")` или `field_validator` через `time.fromisoformat`). В engine дополнительно обернуть парсинг в try/except с fallback на DEFAULT_TRADING_START/END и warning-логом, чтобы некорректный конфиг не убивал hot path.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.


---

## `fix/be-misc` — Backend: admin / tax / corporate actions / common (3)

**Роль:** Backend-разработчик. Внимание к налоговой логике (НК РФ) и admin-авторизации.
**Файлы:** `backend/app/admin/`, `backend/app/tax/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### BE-MISC-17 · `backend/app/admin/dash_mount.py:112` · ✅ подтверждено
**`AdminAuthASGIMiddleware` не привязывает JWT к отзыву токена (`token_version`)**
- **Проблема:** ASGI-гейт для Dash-метрик валидирует только подпись и `type=access`, затем грузит юзера по `sub` и проверяет `is_active`/`is_admin`. В отличие от основного `get_current_user` (который проверяет отзыв токена — `middleware/auth.py:34`), здесь нет проверки чёрного списка/`token_version`. Отозванный, но ещё не истёкший access-токен админа даёт доступ к `/api/v1/admin/metrics`. Дополнительно `int(payload.get('sub', 0))` при отсутствии `sub` даёт `user_id=0`, а не отказ — хрупкий fallback.
- **Fix:** Переиспользовать общую логику проверки токена (включая отзыв/`token_version`), а не дублировать урезанную версию. Явно отклонять отсутствующий/нулевой `sub` (`401`).
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### BE-MISC-18 · `backend/app/tax/service.py:112` · ✅ подтверждено
**Годовой фильтр налогового отчёта смешивает локальное время и naive UTC**
- **Проблема:** `year_start`/`year_end` строятся как `datetime(year, 1, 1)` — naive без TZ, и сравниваются с `LiveTrade.closed_at`, который по контракту хранится как **naive UTC**. Для биржи Europe/Moscow (UTC+3) сделки, закрытые в первые ~3 часа 1 января по МСК, имеют `closed_at` в предыдущем UTC-годе (или наоборот на границе 31 декабря) и попадут не в тот налоговый период — искажение 3-НДФЛ на границах года.
- **Fix:** Считать границы года в МСК и переводить в UTC перед сравнением, либо явно приводить обе стороны к одной TZ-семантике.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### BE-MISC-19 · `backend/app/tax/service.py:260` · ✅ подтверждено
**`_calculate_tax_base` нетит убытки между разными типами инструментов**
- **Проблема:** `taxable_base = max(0, total_profit + total_loss)` суммирует прибыли и убытки по всем инструментам вместе, хотя `by_type` (акции/облигации/ETF) уже считается раздельно и далее не используется. В РФ налоговые базы по разным категориям считаются раздельно, и убыток одной категории не всегда уменьшает прибыль другой. Смешивание искажает налоговую базу и делает отчёт некорректным для подачи.
- **Fix:** Считать налоговую базу отдельно по категориям (использовать готовый `by_type`), применять `max(0, ...)` к каждой группе согласно правилам НК РФ.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.


---

## `fix/fe-security` — Frontend: хранение токенов / security (4)

**Роль:** Frontend-разработчик (security). Пересмотреть модель хранения JWT и логирование.
**Файлы:** `frontend/src/hooks/`, `frontend/src/stores/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** Связано с backend: переход на HttpOnly-cookie требует правок в be-auth (выдача cookie).

### CFG-FE-01 · `frontend/src/stores/authStore.ts:145` · ✅ подтверждено
**JWT access/refresh токены персистятся в localStorage (доступны из JS, нет HttpOnly)**
- **Проблема:** `zustand persist(...)` с `partialize: { token, refreshToken, user }` записывает оба токена в localStorage под ключом `auth-storage` (подтверждено также вызовом `localStorage.removeItem('auth-storage')` в logout, строка 83). Любой XSS-вектор (в т.ч. будущий — через сторонний npm-пакет, Blockly custom field, XSS в зависимости Mantine/lightweight-charts) получает доступ к `localStorage.getItem('auth-storage')` и может похитить одновременно access и refresh токен, полностью компрометируя сессию пользователя торгового терминала (доступ к брокерскому счёту, управление live-сессиями) без возможности обнаружения — refresh token украден вместе с access, инвалидация при краже отсутствует. В проекте уже есть паттерн HttpOnly cookie (используется для admin/Plotly Dash аутентификации, см. комментарий в `api/client.ts:7-13`), но основной auth-flow его не использует — подтверждено также докстрингом в `backend/app/auth/router.py:40`, прямо описывающим хранение JWT в localStorage.
- **Fix:** Перевести access/refresh токены на HttpOnly+Secure+SameSite=Strict cookie (по аналогии с уже реализованным подходом для admin/Plotly Dash), а в localStorage/zustand persist хранить только несекретные UI-данные (`user.username`, `is_admin` для отображения). Существующую частичную CSRF-защиту (`X-CSRF-Token` в `client.ts`) расширить на весь auth flow при переходе на cookie-based токены.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### CFG-FE-02 · `frontend/src/hooks/useWebSocket.ts:23` · ✅ подтверждено
**JWT передаётся в query-string WebSocket URL (`ws://...?token=...`)**
- **Проблема:** `getWsUrl()` формирует `${base}/ws?token=${token}`, подставляя токен в открытом виде в URL; аналогичный паттерн — в `stores/backtestStore.ts:130`. Backend (`backend/app/backtest/ws.py:20-37`, `_authenticate_ws`) читает токен только из query-параметров, альтернативы нет — query-string обязателен для аутентификации. Такой URL оседает в: (1) истории браузера, (2) access-логах nginx на этапе HTTP upgrade-запроса — `nginx.conf:25` содержит `access_log /dev/stdout;` на уровне `server{}` без кастомного `log_format` (дефолтный `combined` пишет `$request` целиком), а `location /ws/` (67-80) не переопределяет `access_log`, то есть токены пользователей оседают в открытых текстовых логах контейнера (`docker compose logs`, что подтверждается и комментарием в самом файле), (3) логах промежуточных прокси/CDN (Cloudflare Tunnel). Любой, у кого есть доступ к этим логам, получает валидный JWT без необходимости перехватывать трафик.
- **Fix:** Передавать токен через WebSocket subprotocol header или отправлять его первым сообщением после установления соединения (auth handshake), а не в URL. Если на переходном этапе отказаться от query-string нельзя — исключить путь `/ws/` из access_log (кастомный `log_format` без `$request_uri` или `access_log off;` для этого location) на стороне nginx.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-STOR-12 · `frontend/src/stores/backtestStore.ts:129` · ✅ подтверждено
**JWT-токен передаётся в query-string WebSocket URL (второе, независимое место)**
- **Проблема:** `subscribeProgress` берёт `token` из `authStore` и подставляет в URL (`/ws?token=${token}`) при подключении WebSocket прогресса бэктеста. Query-string логируется прокси/веб-серверами, попадает в browser history и Referer — тот же класс уязвимости, что и в `useWebSocket.ts` (см. раздел 2), но здесь это отдельное место создания `WebSocket`, которое легко пропустить при исправлении первого.
- **Fix:** Централизовать подключение WS через единый клиент, передающий токен не в URL, а через subprotocol или сообщение после `onopen` (`{action:'auth', token}`); убрать дублирующую реализацию.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-STOR-13 · `frontend/src/stores/authStore.ts:62` · ✅ подтверждено
**Логирование префикса JWT-токена в консоль при логине**
- **Проблема:** В `login()` при `import.meta.env.DEV` выполняется `console.debug('[auth] login — token set:', token?.slice(0,12) + '...')`. 12 символов JWT попадают в консоль браузера и потенциально в session-replay/error-трекеры (Sentry/LogRocket мирроят `console.*`). При активации такого инструмента в дев/стейджинге с реальными данными — частичная утечка токена.
- **Fix:** Убрать вывод любого содержимого токена; логировать только факт события без среза строки.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.


---

## `fix/fe-network` — Frontend: сетевой слой / типы (4)

**Роль:** Frontend-разработчик. Типобезопасность Decimal-полей и устойчивость WS.
**Файлы:** `frontend/src/api/`, `frontend/src/hooks/`, `frontend/src/stores/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### FE-NET-01 · `frontend/src/hooks/useWebSocket.ts:23` · ✅ подтверждено
**JWT access/refresh токены передаются в query string общего WebSocket-канала**
- **Проблема:** `getWsUrl()` формирует `ws://.../ws?token=<jwt>` — токен уходит в URL, оседает в браузерной истории, логах reverse-proxy/nginx/CDN, Referer и devtools Network-панели. Соседние хуки `useTradingSessionsWS.ts` (gotcha-16) и `useBacktestJobWS.ts` уже используют безопасный паттерн — передают JWT первым WS-сообщением `{action:'auth', token}` после открытия сокета. `useWebSocket.ts` (общий мультиплексированный `/ws` для market/trades/notifications/health, используется в CandlestickChart.tsx, HealthWidget.tsx, NotificationBell.tsx, SessionDashboard.tsx, ChartPage.tsx) остался на старой уязвимой схеме. Верификация трассы: backend `app/backtest/ws.py:20-37` (`_authenticate_ws`, смонтирован в `main.py:42,359` как `/ws`) читает JWT строго из `query_params.get("token")`, иначе `close(4001)` — альтернативы на backend нет.
- **Fix:** Привести `useWebSocket.ts` к паттерну `useTradingSessionsWS.ts`/`useBacktestJobWS.ts`: открывать сокет без токена в URL, отправлять `{action:'auth', token}` первым сообщением после `onopen`, ждать `auth_ok`/`auth_error` от сервера перед подпиской на каналы. Потребует согласованного изменения на backend (`app/backtest/ws.py`), так как текущий backend поддерживает только query-param.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-NET-02 · `frontend/src/stores/authStore.ts:145` · ✅ подтверждено
**JWT access/refresh токены персистятся в localStorage — компрометация сессии при любом XSS**
- **Проблема:** `persist` middleware Zustand сохраняет `token` и `refreshToken` в `localStorage` под ключом `auth-storage` (partialize включает оба поля). `client.ts` и `aiStreamClient.ts` читают токен и кладут в заголовок `Authorization: Bearer`. Любой XSS в приложении (сторонний npm-пакет, Blockly-плагин и т.п.) даёт атакующему доступ к обоим токенам, включая long-lived refresh_token, которым можно продлевать сессию даже после смены пароля жертвой, если backend не ревокирует refresh_token при смене пароля. Backend уже частично поддерживает HttpOnly cookie (для Plotly Dash), т.е. инфраструктура для более безопасной схемы частично есть, но SPA-флоу на неё не переведён.
- **Fix:** Перевести аутентификацию SPA полностью на HttpOnly+Secure+SameSite cookie (аналогично уже существующей cookie для Plotly Dash), отказаться от чтения token в JS и от Bearer-заголовка для browser-flow. Если полный переход невозможен в текущем спринте — минимум не хранить refresh_token в localStorage (только в памяти/HttpOnly cookie).
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-NET-03 · `frontend/src/api/backtestApi.ts:38` · ✅ подтверждено
**Decimal-поля BacktestMetrics/BacktestTrade/EquityPoint типизированы как number вместо string — риск TypeError в проде**
- **Проблема:** Backend `app/backtest/schemas.py` (BacktestMetrics: net_profit, net_profit_pct, win_rate, profit_factor, max_drawdown_pct, sharpe_ratio, avg_profit_per_trade, avg_loss_per_trade; BacktestTrade.entry_price/exit_price/pnl/pnl_pct/commission; EquityPoint.equity/drawdown — все Decimal) сериализует Decimal как JSON-строку (Pydantic v2 без json_encoders/PlainSerializer, задокументировано в проекте как Stack Gotcha #1, `api/types.ts:82-87`). Frontend же типизирует эти поля в `backtestApi.ts` как `number`. Практическое следствие: `MetricsGrid.tsx` вызывает `netProfitPct.toFixed(1)` (проп из `BacktestResultsPage.tsx:290`) на значении, приходящем строкой — `String.prototype.toFixed` не существует, что бросает `TypeError: netProfitPct.toFixed is not a function` и ломает страницу результатов бэктеста. Другой потребитель, `StrategyTesterPanel.tsx:297` (`metrics?.net_profit ?? 0` → `formatMoney` → `Intl.NumberFormat`), пока не падает благодаря неявному ToNumber внутри Intl.NumberFormat — это маскирует некорректность контракта, а не подтверждает его правильность.
- **Fix:** Привести типы BacktestMetrics, BacktestTrade, EquityPoint, BacktestCandle, BacktestBenchmark в `backtestApi.ts` к `string` для всех Decimal-полей (net_profit, win_rate, profit_factor, sharpe_ratio, entry_price, exit_price, pnl, pnl_pct, commission, equity, drawdown, buy_hold, index и т.д.), как уже сделано для TradingSession/LiveTrade/Position в `api/types.ts`, и обернуть точки потребления в `Number(...)` перед арифметикой/`.toFixed()`, либо ввести единый helper `toNumber()` на границе API.
- **DoD:** рефактор по рекомендации; существующие тесты модуля зелёные; `pyright`/`tsc --noEmit` = 0; для UI — Playwright без визуального регресса.

### FE-NET-04 · `frontend/src/hooks/useBacktestJobWS.ts:257` · ❓ спорно (уточнить перед фиксом)
**useBackgroundBacktestsBootstrap не переподключается при обрыве WS фонового бэктеста**
- **Проблема:** Эффект в `useBackgroundBacktestsBootstrap()` (строки 179-271) переоткрывает сокеты только при изменении `idsKey` (join активных job_id из стора). `socket.onclose` (строка 257-259) при разрыве соединения лишь удаляет id из карты sockets — reconnect не планируется, в отличие от соседнего `useBacktestJobWS` с корректным exponential backoff. Если во время работы фонового бэктеста backend перезапустится, упадёт сеть или сервер закроет idle-соединение, WS для job_id не переоткроется, пока список активных job'ов не изменится по другой причине. В результате бейдж «Фоновые бэктесты» в шапке застревает на последнем полученном progress и никогда не покажет done/error, пока пользователь не обновит страницу вручную. Это единственный реально используемый в продакшене WS-клиент для фоновых job'ов — соседний `useBacktestJobWS` с корректной reconnect-логикой нигде не вызывается (мёртвый код).
- **Fix:** Добавить в `socket.onclose` планирование reconnect с exponential backoff (по аналогии с `useBacktestJobWS`/`useTradingSessionsWS`), либо переиспользовать существующий `useBacktestJobWS` для каждого активного job_id вместо параллельной ad-hoc реализации без reconnect, либо явно вызывать `store.setStatus(id, 'error', ...)` при неожиданном закрытии.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.


---

## `fix/fe-charts` — Frontend: графики (3)

**Роль:** Frontend-разработчик (charts). Требует typescript-lsp + Playwright после правок.
**Файлы:** `frontend/src/components/charts/`, `frontend/src/components/charts/primitives/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### FE-CHART-01 · `frontend/src/components/charts/primitives/VlinePrimitive.ts:27` · ❓ спорно (уточнить перед фиксом)
**VlinePrimitive не поддерживает sequential (intraday) mode — линия не отображается или рисуется в неверном месте**
- **Проблема:** `VlineRenderer.draw()`/`hitTest()` вычисляют X-координату напрямую через `timeToX(chart, isoToTime(t))`, т.е. по unix-времени + MSK-offset. Но на intraday-таймфреймах (1m/5m/15m/1h/4h) CandlestickChart включает sequential mode, и серия индексирована по 0,1,2… вместо unix-timestamp (см. `isSeriesInSequentialMode` в `primitives/coords.ts`, отдельная logical-first ветка `pointToCoord()`, строки 63-86). Все остальные примитивы (Trendline, Rect, Label, PositionDrawing) корректно используют `pointToCoord`, который учитывает sequential mode через `point.logical`. VlinePrimitive — единственный, кто вызывает `timeToCoordinate` с числом вида unix_sec+10800 (>1.7e9), далеко за пределами реального диапазона индексов серии (0..N) — `timeToCoordinate` вернёт `null` или неверную координату. Сценарий: пользователь на графике SBER 5m ставит вертикальную линию — она либо не отображается вовсе, либо после дозагрузки/reload оказывается в произвольном месте графика. Дополнительно: при создании vline в `DrawingsLayer.tsx:247` (`add({type:'vline', data:{t: pt.t}})`) точка вообще не сохраняет `point.logical`, хотя `clickToDrawingPoint` его вычисляет — то есть даже потенциальный fallback через logical недоступен.
- **Fix:** Переписать `VlinePrimitive.draw()`/`hitTest()` на использование `pointToCoord({t, logical}, chart, series)` вместо прямого `timeToX(isoToTime(t))`, аналогично Trendline/Rect/Label. При создании vline в `DrawingsLayer.handleCreation` сохранять и `logical` из `pt` (`data: { t: pt.t, logical: pt.logical }`).
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-CHART-02 · `frontend/src/components/charts/CandlestickChart.tsx:138` · ✅ подтверждено
**God-компонент: 907 строк, 8 useEffect, смешение data-layer/WS/маркеров/рендера**
- **Проблема:** CandlestickChart одновременно отвечает за: создание/ресайз chart-инстанса, парсинг таймзоны, sequential-индексацию, подписку на market WS, подписку на trade WS, построение и пересчёт маркеров сделок (`tradeTimeValue`/`tradeToMarkers`/`rebuildMarkers`), управление price-alert линиями и рендер overlay. При любом изменении одной из зон разработчик вынужден читать все 907 строк и держать в голове взаимодействие 6+ ref'ов. Конкретный сценарий: при добавлении новой фичи велика вероятность нарушить порядок операций в useEffect №2 (строки 419-606), помеченном множеством `eslint-disable exhaustive-deps` из-за вызова `rebuildMarkers` вне deps — уже сейчас источник скрытых багов (ссылки на BUG-28 в комментариях подтверждают историю подобных инцидентов).
- **Fix:** Выделить логику построения/пересчёта trade-маркеров в отдельный хук `useTradeMarkers(sessionId, ...)`, а WS-обвязку — в `useChartLiveData`. Это уменьшит компонент и уберёт часть `eslint-disable` по exhaustive-deps.
- **DoD:** рефактор по рекомендации; существующие тесты модуля зелёные; `pyright`/`tsc --noEmit` = 0; для UI — Playwright без визуального регресса.

### FE-CHART-03 · `frontend/src/components/charts/primitives/coords.ts:17` · ✅ подтверждено
**MSK_OFFSET_SEC и парсинг UTC-таймстампа с MSK-сдвигом продублированы в трёх файлах**
- **Проблема:** Константа `MSK_OFFSET_SEC=3*3600` и идентичная логика нормализации ISO+деление на 1000+сдвиг определены независимо в `CandlestickChart.tsx` (строки 41-49, `parseUtcTimestamp`), `sequentialIndex.ts` (строки 5-11, отдельная копия той же функции) и `coords.ts` (строки 17-27, `isoToTime`/`timeToIso`). Комментарии сами признают риск («Stack Gotcha 15»), но не устраняют его. При изменении политики времени правку придётся синхронно вносить в 3 местах — пропуск одного создаст рассинхрон между отображением цены на графике и координатами drawings/маркеров (визуальный сдвиг фигур относительно свечей).
- **Fix:** Вынести `MSK_OFFSET_SEC` и `parseUtcTimestamp`/`isoToTime`/`timeToIso` в один модуль (например `utils/mskTime.ts`) и импортировать из него во всех трёх местах.
- **DoD:** рефактор по рекомендации; существующие тесты модуля зелёные; `pyright`/`tsc --noEmit` = 0; для UI — Playwright без визуального регресса.


---

## `fix/fe-backtest-ui` — Frontend: бэктест-компоненты (4)

**Роль:** Frontend-разработчик. Внимание к lifecycle подписок и глобальному стору.
**Файлы:** `frontend/src/components/backtest/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### FE-BTST-13 · `frontend/src/components/backtest/BacktestProgress.tsx:55` · ✅ подтверждено
**Автонавигация `BacktestProgress` не сверяет id завершившегося бэктеста — переход на чужой**
- **Проблема:** `useEffect` реагирует на `currentBacktest.status === 'completed'` и делает `navigate('/backtests/${backtestId}')`, где `backtestId` — проп, а `currentBacktest` берётся из глобального `useBacktestStore()` без сверки id. Если пока компонент смонтирован в сторе обновится `currentBacktest` от другого бэктеста (стор — синглтон), эффект сработает и произойдёт редирект на `backtestId` из пропсов, хотя завершился другой бэктест.
- **Fix:** Сверять `currentBacktest.id === backtestId` перед навигацией, либо хранить id подписки в сторе.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-BTST-14 · `frontend/src/components/backtest/BacktestProgress.tsx:34` · ✅ подтверждено
**`BacktestProgress` не отписывается от WS/polling при размонтировании — утечка и запись в стор после ухода**
- **Проблема:** Комментарий «Не отписываемся сразу — polling fallback может ещё работать» оставляет `useEffect` с пустым cleanup. `subscribeProgress` создаёт WS/интервал, а `unsubscribeProgress` вызывается только при `finished`/error внутри стора. Если пользователь уходит со страницы до завершения бэктеста, WS и `setProgress`/`setResult` продолжают писать в глобальный стор — утечка сокета и источник багов при повторном заходе.
- **Fix:** В cleanup вызывать `unsubscribeProgress(backtestId)` при размонтировании, если компонент был последним потребителем, либо перенести управление подпиской на страницу-контейнер.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-BTST-15 · `frontend/src/components/backtest/InstrumentChart.tsx:289` · ❓ спорно (уточнить перед фиксом)
**rAF-цикл перерисовки фоновых зон в `InstrumentChart` работает даже на скрытом компоненте**
- **Проблема:** `requestAnimationFrame`-цикл запускается безусловно на каждый созданный `chart` и вызывает `drawBgZones()` до 60 раз/сек всё время жизни компонента, включая случаи, когда контейнер скрыт (`display:none` при переключении вкладок). Постоянная нагрузка CPU/GPU; на скрытом контейнере (`clientWidth===0`) возможны нулевые размеры canvas.
- **Fix:** Останавливать rAF при `document.hidden` / через `IntersectionObserver`, либо перерисовывать по событию `subscribeVisibleTimeRangeChange` вместо цикла на каждый кадр.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-BTST-16 · `frontend/src/components/backtest/PnLDistributionHistogram.tsx:50` · ✅ подтверждено
**`PnLDistributionHistogram`: `bucketCount` не ограничен сверху — риск подвесить рендер на аномальных данных**
- **Проблема:** `bucketCount = Math.round((upperBound - lowerBound) / bucketSize)` не ограничен сверху. При аномальном выбросе `pnl_pct` (баг бэкенда или доли вместо процентов) диапазон становится огромным при мелком `bucketSize` — создаются десятки тысяч бакетов, каждый рендерит `Tooltip`+`Box`, что подвешивает рендер.
- **Fix:** Ограничить `bucketCount` сверху (например, 200) и агрегировать хвостовые значения в крайние бакеты.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.


---

## `fix/fe-core-refactor` — Frontend: ядро / рефакторинг god-компонентов (8)

**Роль:** Frontend-разработчик (senior). Декомпозиция крупных компонентов, единые утилиты дат/чисел, lazy-load.
**Файлы:** `frontend/src/`, `frontend/src/pages/`, `frontend/src/utils/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.
**Примечание:** Крупные рефакторы (StrategyEditPage 1101 стр., CandlestickChart 907 стр.) — делать инкрементально с Playwright-регрессом.

### FE-PAGE-01 · `frontend/src/pages/StrategyEditPage.tsx:67` · ✅ подтверждено
**God-компонент StrategyEditPage: 1101 строка, смешаны состояние формы, Blockly, версии, бэктесты и рендер вкладок**
- **Проблема:** Компонент держит ~25 useState/useRef, две сериализации Blockly (getCanonicalBlocks и getBlocksForBackend с разной семантикой), логику сохранения версий, авто-сброс query-параметров, построение AI-контекста и вёрстку двух вкладок с таблицами и модалками — всё в одном файле без выделения в кастомные хуки или дочерние компоненты. При добавлении новой фичи (например, ещё один тип валидации блоков) высок риск случайно сломать несвязанную логику (например, сохранение версии или таб-навигацию), т.к. все состояния находятся в одной функции и неявно взаимодействуют через замыкания (см. `handleBlocksLoaded` с `eslint-disable-next-line` на exhaustive-deps).
- **Fix:** Вынести работу с Blockly (getCanonicalBlocks/getBlocksForBackend/getBlockWarnings/replaceInlineWithRefs) в отдельный хук `useStrategyBlocks(workspace)`, логику сохранения (doSave/handleGenerate/handleSaveClick) в `useStrategySave(...)`, а таблицу бэктестов стратегии — в отдельный компонент `StrategyBacktestsTable`.
- **DoD:** рефактор по рекомендации; существующие тесты модуля зелёные; `pyright`/`tsc --noEmit` = 0; для UI — Playwright без визуального регресса.

### FE-PAGE-02 · `frontend/src/pages/StrategyEditPage.tsx:1086` · ✅ подтверждено
**Массовое удаление бэктестов не обрабатывает частичный отказ Promise.all**
- **Проблема:** Обработчик кнопки «Удалить все» вызывает `Promise.all(strategyBacktests.map((bt) => backtestApi.delete(bt.id)))` без `.catch()`. Если хотя бы один из N DELETE-запросов вернёт ошибку (сетевой сбой, 404 — бэктест уже удалён другой вкладкой, 403 и т.п.), весь `Promise.all` реджектится — необработанный rejection в обработчике клика. Часть бэктестов на бэкенде уже могла быть успешно удалена, но `setStrategyBacktests([])` и `setDeleteAllConfirmOpened(false)` не выполнятся: модалка «зависает» открытой, список в UI остаётся прежним (показывает уже удалённые записи), и пользователь не получает никакого уведомления об ошибке — состояние UI рассинхронизировано с БД до ручного обновления страницы. Подтверждено при верификации: `backtestApi.delete` идёт через `apiClient`, чей response-interceptor (api/client.ts:99-149) всегда делает `Promise.reject(error)` при ошибке, не глушит её; глобального `unhandledrejection`-хендлера нет (в ErrorBoundary.tsx:21 явно отмечено «отложено»), safety net отсутствует. Соседний одиночный delete (строка 882) страдает тем же паттерном — подтверждает системность бага.
- **Fix:** Использовать `Promise.allSettled` вместо `Promise.all`, показать notification с числом успешных/неуспешных удалений, обновить список только реально удалёнными id, и в любом случае закрыть модалку или дать явный retry.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-PAGE-03 · `frontend/src/pages/LoginPage.tsx:53` · ✅ подтверждено
**JWT access/refresh токены хранятся в localStorage через zustand persist — риск полного захвата сессии при XSS**
- **Проблема:** LoginPage и SetupPage (SetupPage.tsx:47) вызывают `login(resp.data.access_token, resp.data.refresh_token, ...)` из authStore, обёрнутого в `persist()` (zustand/middleware) с дефолтным storage — localStorage. Любой XSS на любой странице приложения (в т.ч. через сторонние npm-пакеты Blockly/lightweight-charts или будущую уязвимость) получает полный доступ к access_token и refresh_token через `localStorage.getItem('auth-storage')`, что даёт постоянный захват сессии трейдера (можно выставлять реальные ордера через /trading, менять брокерские настройки) без возможности отзыва токена сервером до истечения TTL refresh_token. Подтверждено при верификации: authStore.ts:52-53,145-148 — `persist()`, `name:'auth-storage'`, `partialize` сохраняет token и refreshToken, storage не задан → дефолт zustand — localStorage; `logout()` делает `localStorage.removeItem('auth-storage')` (authStore.ts:83); client.ts:33,50 берёт token из стора в Authorization-header, `doRefresh` (client.ts:78-97) читает refreshToken оттуда же. Backend уже ставит HttpOnly cookie (router.py:34-56), но фронт использует не её, а JS-доступный localStorage как основной канал.
- **Fix:** Хранить access_token только в памяти (не в persist zustand), refresh_token — в HttpOnly Secure cookie с SameSite=Strict, обновляемой через /auth/refresh. Расширить существующую серверную поддержку HttpOnly cookie (`_set_access_token_cookie`) на весь фронтенд, а не только на admin-ASGI-путь, и убрать persist токенов в localStorage.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-CORE-01 · `frontend/src/utils/tradeMarkerUtils.ts:108` · ✅ подтверждено
**computeChartZones перезаписывает pnl чужой сделки при близких entry-маркерах (±3600с), искажая цвет зоны на графике**
- **Проблема:** В `computeChartZones` для каждой сделки `t` во внешнем цикле идёт вложенный проход по всем маркерам `sorted` с условием `Math.abs(m.time - ts) < 3600` без `break` — если entry-время другой сделки попадает в тот же часовой интервал (частый случай на интрадей-таймфреймах M5/M15/H1), `tradePnlByEntry.set(m.time, t.pnl)` перезаписывается результатом последней по порядку итерации сделки, а не сделки, реально начавшейся в `m.time`. Зона на графике окрашивается как «profit» для реально убыточной сделки или наоборот. Похожая логика в `enrichMarkersWithLots` корректна (есть `break` после первого совпадения), а в `computeChartZones` `break` отсутствует. Файл не покрыт unit-тестами. Верификация подтвердила на конкретном примере (сделки A и B с Δ=1000с<3600): оба ключа в итоге получают pnl последней по порядку сделки, а зона красится по `get(currentEntry)` — сценарий реален при хронологическом порядке trades на M5/M15/H1.
- **Fix:** Убрать fallback-подбор по tolerance полностью (только точное совпадение timestamp) либо выбирать ближайшее совпадение и делать `break` вместо безусловной перезаписи по всем маркерам.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-CORE-02 · `frontend/src/utils/formatters.ts:15` · ✅ подтверждено
**formatDate/formatDateTime не нормализуют naive UTC datetime от backend — даты сделок/операций отображаются со сдвигом на 3 часа**
- **Проблема:** `formatDate`/`formatDateTime` делают `new Date(date)` напрямую для строк, не пропуская через `parseBackendDate` из этого же каталога, который специально чинит проблему из W8f BUG-3/4: backend отдаёт naive datetime без Z-суффикса, JS трактует его как local time, что в Europe/Moscow даёт сдвиг +3ч. Проверка `backend/app/backtest/schemas.py` показала: `BacktestTrade.entry_date/exit_date` — обычный `datetime` без `iso_utc()` (только 3 из 76 файлов backend с datetime используют `iso_utc`). Сценарий: FastAPI сериализует `entry_date` без Z; `TradesTable.tsx`/`BacktestTrades.tsx` вызывают `formatDate(trade.entry_date)` — время сделки показывается на 3ч раньше фактического времени исполнения на MOEX.
- **Fix:** Переиспользовать `parseBackendDate` внутри `formatDate`/`formatDateTime` вместо `new Date(date)`, либо обеспечить применение `iso_utc()` во всех backend-схемах с datetime.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-CORE-06 · `frontend/src/utils/formatters.ts:16` · ✅ подтверждено
**`formatDate`/`formatDateTime` парсят дату в обход `parseBackendDate` (тот же класс багов, что закрыт ранее)**
- **Проблема:** `formatDate`/`formatDateTime` парсят строку через `new Date(date)` напрямую, минуя `parseBackendDate` из `dateParsing.ts`, где в комментарии описано, что backend отдаёт naive UTC без TZ-суффикса (даёт сдвиг +3 ч для Москвы, известные BUG-3/4). Именно эти функции выводят даты пользователю и не защищены от того же бага. При невалидной строке `new Date()` даёт `Invalid Date`, и `toLocaleDateString/Time` тихо вернут «Invalid Date» в UI без обработки.
- **Fix:** Использовать `parseBackendDate` вместо сырого `new Date(...)`; явно обрабатывать `null` (возвращать `'—'`) вместо протекания «Invalid Date».
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-CORE-07 · `frontend/src/App.tsx:3` · ✅ подтверждено
**Тяжёлые страницы (Blockly, lightweight-charts) не загружаются лениво**
- **Проблема:** Все ~15 страниц импортируются статически, без `React.lazy`/`Suspense`. `ChartPage`/`StrategyEditPage` тянут тяжёлые `lightweight-charts` и `blockly`, которые попадают в основной бандл и грузятся даже пользователям, открывающим только `/login` или `/account`.
- **Fix:** Обернуть как минимум `ChartPage`, `StrategyEditPage`, `TradingPage`, `AdminLayout` в `React.lazy(() => import(...))` + один `<Suspense>` вокруг `<Routes>`.
- **DoD:** рефактор по рекомендации; существующие тесты модуля зелёные; `pyright`/`tsc --noEmit` = 0; для UI — Playwright без визуального регресса.

### FE-CORE-08 · `frontend/src/App.tsx:27` · ✅ подтверждено
**Дублирование guard-логики защищённых роутов — `frontend/src/App.tsx:27` и `frontend/src/routes/ProtectedAdminRoute.tsx:23`**
- **Проблема:** `ProtectedRoute` и `ProtectedAdminRoute` независимо реализуют одинаковую проверку `isAuthenticated → <Navigate to="/login"/>` в разных файлах. При будущих изменениях (редирект с сохранением `from` и т.п.) легко поправить один guard и забыть второй.
- **Fix:** Вынести проверку аутентификации в один компонент/хук (`useRequireAuth`) и построить `ProtectedAdminRoute` поверх него, добавляя только проверку `is_admin`.
- **DoD:** рефактор по рекомендации; существующие тесты модуля зелёные; `pyright`/`tsc --noEmit` = 0; для UI — Playwright без визуального регресса.


---

## `fix/fe-ui-misc` — Frontend: strategy / trading / прочий UI (4)

**Роль:** Frontend-разработчик. Разные мелкие High по UI-модулям.
**Файлы:** `backend/app/trading/`, `frontend/src/components/notifications/`, `frontend/src/components/strategy/`, `frontend/src/stores/`
**Предпроверка:** baseline-тесты модуля зелёные; прочитать релевантные `stack_gotchas` по симптому.

### FE-STRAT-01 · `frontend/src/components/strategy/BlocklyWorkspace.tsx:196` · ✅ подтверждено
**Загрузка Blockly workspace state/XML без валидации типов блоков против allow-list**
- **Проблема:** `initialBlocksXml` (blocks_json версии стратегии) десериализуется через `Blockly.serialization.workspaces.load`, а при ошибке — через XML fallback `Blockly.Xml.domToWorkspace(Blockly.utils.xml.textToDom(...))` без проверки, что `block.type` входит в allow-list `ALL_BLOCKS`. Сейчас поле контролируется только владельцем стратегии через `/strategy/{id}/versions`, шаринга/импорта чужих стратегий в этой зоне нет, поэтому прямой XSS не реализован. Но если в будущем появится шаринг стратегий между пользователями либо на бэкенде окажется ослаблен IDOR-контроль владения в `GET /strategy/{id}/versions/by-id/{ver_id}`, в компонент попадёт чужой workspace state с произвольным `type`/`fields` без серверной валидации; в связке с кастомными полями типа `FieldImage` с `data:image/svg+xml` (BlockDefinitions.ts:236) это даёт поверхность для спекулятивной атаки через рендеринг непроверенных полей.
- **Fix:** На бэкенде при сохранении/восстановлении версии валидировать blocks_json по строгой схеме (allow-list типов из `ALL_BLOCKS` + разрешённые поля/значения), отклоняя неизвестные type. На фронте перед `workspaces.load`/`domToWorkspace` проверять `block.type ∈ ALL_BLOCKS`. Дополнительно убедиться, что `/strategy/{id}/versions/by-id/{ver_id}` и restore проверяют принадлежность `owner_id`, а не только существование id.
- 🔴 **Red/PoC:** запрос/сценарий, эксплуатирующий проблему, отклоняется (401/403/валидация) — тест падает до фикса. 🟢 фикс по рекомендации.

### FE-TRAD-01 · `frontend/src/stores/tradingStore.ts:156` · ✅ подтверждено
**Race condition: устаревший ответ fetchPositions/fetchTrades/fetchStats перетирает данные другой сессии**
- **Проблема:** `fetchPositions`, `fetchTrades`, `fetchStats` и `fetchSession` не проверяют, что `sessionId` ответа совпадает с текущей открытой сессией (нет `AbortController`, нет guard по актуальному id). В `SessionDashboard.tsx` (строки 55-66) при смене `sessionId` (быстрый переход между сессиями) вызывается `fetch*` для нового id без отмены предыдущих promise. Если ответ для сессии A придёт позже ответа для B, `set({positions/trades/stats})` перезапишет актуальные данные сессии B устаревшими данными A. Для `activeSession` есть guard (`activeSession.id !== sessionId`, строка 96), но он защищает только шапку — positions/trades/stats читаются без проверки, поэтому пользователь может увидеть чужие позиции/P&L на экране активной сессии. Store глобален, а один route на `:id` не размонтирует компонент при смене сессии, так что запоздалый resolve перезапишет данные даже после навигации.
- **Fix:** Добавить в `tradingStore` проверку актуальности перед `set()` (сравнивать `sessionId` ответа с `get().activeSession?.id`) либо использовать `AbortController`/request-token паттерн, игнорируя ответы с устаревшим id.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-TRAD-02 · `backend/app/trading/schemas.py:110` · ✅ подтверждено
**SessionResponse сериализует даты без Z-суффикса — время сессии сдвигается на 3 часа на фронтенде**
- **Проблема:** `TradingSession.started_at/stopped_at/last_signal_at` хранятся как naive UTC datetime (`models.py`, `DateTime` без timezone, `server_default=func.now()`). В отличие от `TradeResponse` (schemas.py:154-156) с `@field_serializer(..., when_used='json')` и `iso_utc()`, `SessionResponse` такого serializer не имеет — Pydantic отдаёт строку без `Z`. На фронте `SessionCard.tsx` (строки 21-30, рендерит `started_at`/`last_signal_at`) использует `new Date(iso)` напрямую вместо уже существующего `parseBackendDate()` (используется в `TradesTable.tsx`). Браузер интерпретирует строку без TZ как local time — для московского пользователя (UTC+3) дата запуска и время последнего сигнала будут показаны на 3 часа раньше реального. Тот же класс проблемы, что закрытый ранее BUG-3/4, но не устранённый для сессий. Уточнение при верификации: `SessionDashboard.tsx` сам не содержит `new Date`, лишь композирует `SessionCard` — баг там опосредован, но суть находки не отменяется.
- **Fix:** Добавить `@field_serializer('started_at','stopped_at','last_signal_at', when_used='json')` с `iso_utc()` в `SessionResponse`, и на фронтенде заменить `new Date(iso)` на `parseBackendDate(iso)` в `SessionCard.tsx` — по аналогии с уже исправленным BUG-3/4 в `TradesTable.tsx`.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.

### FE-UI-01 · `frontend/src/components/notifications/CriticalBanner.tsx:12` · ✅ подтверждено
**Автозакрытие критического баннера ломается при любом новом уведомлении**
- **Проблема:** criticalNotifications вычисляется через notifications.filter(...) в теле компонента без useMemo — новый массив на каждый рендер. useEffect с зависимостью [criticalNotifications, dismiss] срабатывает на КАЖДОЕ изменение notifications в сторе (не только критических — любое новое уведомление любого severity, приходящее по WS). Cleanup-функция эффекта вызывает currentTimers.clear() (очищает Map целиком, не только просроченные), а затем цикл заново создаёт таймеры на AUTO_DISMISS_MS=30000 для всех текущих критических уведомлений. Итог: если во время показа критического алерта (например, cb_triggered при экстренной остановке торговли) приходит хотя бы одно любое другое уведомление раньше истечения 30 секунд — 30-секундный отсчёт сбрасывается и начинается заново. При активном потоке уведомлений (типично во время торговой сессии) критический баннер может никогда не закрыться автоматически, требуя ручного закрытия пользователем. Подтверждено трассировкой: CriticalBanner.tsx:8 подписан на весь notifications; строки 12–14 создают новую ссылку каждый рендер (нет useMemo); useEffect(26-41) зависит от [criticalNotifications, dismiss], Object.is даёт перезапуск при любом ререндере. notificationStore.ts:137-142 addFromWS добавляет любое уведомление без фильтра severity, вызывается из NotificationBell.tsx:41-44 на каждый WS notification.new; оба компонента глобальны в App.tsx, общий стор — некритическое уведомление триггерит ререндер баннера. Cleanup(37-40) чистит все таймеры, новый проход(27-35) ставит их заново на 30000мс без защиты.
- **Fix:** Мемоизировать criticalNotifications через useMemo по стабильному ключу (например, join id критических непрочитанных). В cleanup эффекта не делать currentTimers.clear() безусловно — очищать только таймеры уведомлений, которых больше нет в списке, оставляя таймеры для всё ещё критических/непрочитанных нетронутыми. Либо перейти на хранение deadline (absolute timestamp) вместо relative setTimeout, чтобы повторный запуск эффекта не сбрасывал прогресс.
- 🔴 **Red:** юнит-тест, воспроизводящий дефект (падает до фикса). 🟢 фикс по рекомендации → тест зелёный.
