# Fix-ready бэклог по результатам код-ревью

**Источник:** [code_review_full_report.md](code_review_full_report.md) (полные описания и рекомендации по каждому пункту — там, по ID/файлу/заголовку).
**Дата формирования:** 2026-07-06
**Всего пунктов:** 354 — 🔴 9 critical (после дедупликации — **7 различных**) · 🟠 68 high · 🟡 152 medium · 🔵 125 low.
**Верификация (шаг 2) завершена:** все High либо подтверждены (65), либо помечены спорными ❓ (3); непроверенных High не осталось. Одна находка (`FE-STOR-01`) отклонена как High и перемещена в P3. Детали — в [`verification_P1.md`](verification_P1.md).

## Как пользоваться бэклогом

- **ID** — стабильный идентификатор `{МОДУЛЬ}-{NN}`. По нему находится полное описание в отчёте (заголовок совпадает).
- **Приоритет:** `P0` = блокер сдачи (critical) · `P1` = до сдачи (high) · `P2` = ближайший бэклог (medium) · `P3` = техдолг (low).
- **Колонка «В» (верификация):** ✅ — находка подтверждена адверсариальной проверкой и/или вручную по коду; ❓ — спорно; «—» — **не проверялась**, перед исправлением обязательно подтвердить по текущему коду (шаг 2 отчёта о верификации закрывает P0/P1).
- **Категория:** 🔓 уязвимость/security · 🐛 баг · ⚙️ качество кода.

### Общий Definition of Done для любой задачи

1. **Репродукция до фикса** — написан тест (или PoC-запрос), который воспроизводит проблему и **падает** на текущем коде.
2. **Фикс** — минимальное изменение, закрывающее причину, не выходящее за рамки пункта.
3. **Зелёный тест после** — тот же тест проходит; для уязвимостей — PoC отклоняется (401/403/валидация).
4. **Гейты проекта:** `pyright`/`tsc --noEmit` = 0 ошибок в затронутых файлах; `pytest --cov-fail-under=80`; для security-пунктов — `bandit`/`safety` без новых Medium+.
5. **Регресс** — существующие тесты модуля зелёные; для UI — Playwright-скриншот затронутого экрана.
6. Запись в `changelog.md` текущего спринта приёмки (правило проекта — не откладывать).

> **Важно про верификацию.** Все P2/P3 и часть P1 помечены «—» (не проверялось). Это результат чтения кода, а не воспроизведённый дефект. Как показал разбор находки об `exec()` (см. отчёт, раздел 3, «Переклассифицировано»), встречаются неточности в атрибуции файла/строки. Поэтому **шаг 1 DoD (репро-тест) обязателен** — он же отсеивает ложные срабатывания.

---

## P0 — Критические (блокеры сдачи)

7 различных проблем. Детальные TDD-задачи по ним — в отдельном файле [`tdd_tasks_P0.md`](tdd_tasks_P0.md) (шаг 3). Ниже — карточки с сутью, acceptance-критерием и репро-тестом.

### C1 · `BE-NOTIF-01` · Telegram-webhook fail-open → неаутентифицированное закрытие чужих позиций
**Файл:** `backend/app/notification/router.py:428` (+ `telegram_webhook.py`, `config.py:23`) · **✅ подтверждено**
Пустой `TELEGRAM_WEBHOOK_SECRET` (дефолт `''`) делает проверку `'' != ''` ложной → `process_update` вызывается без секрета; авторизация по `chat_id` из тела, атакующий подставляет чужой → `/closeall` закрывает реальные позиции жертвы.
- **Acceptance:** запрос на webhook без корректного секрета получает **403/503** и `process_update` не вызывается; при заданном `TELEGRAM_BOT_TOKEN` пустой webhook-секрет **валится на старте** приложения; сравнение секрета — `hmac.compare_digest`.
- **Репро-тест:** `POST /api/v1/notifications/telegram/webhook` с телом `{message:{chat:{id:<чужой>}, text:'/closeall'}}` и без заголовка секрета → ожидаем 403 и `process_update` не тронут (мок). Тест падает на текущем коде.

### C2 · `AUTHZ-01` + `BE-TRAD-02` · IDOR: управление чужой торговой сессией (+ ликвидация позиций)
**Файл:** `backend/app/trading/router.py:101,122` → `service.py:516,526` · **✅ подтверждено**
`stop_session/pause_session/resume_session` не принимают `user_id` и не фильтруют по владельцу; `stop` вызывает `close_all_positions` для чужой сессии.
- **Acceptance:** пользователь A, обратившись к `session_id` пользователя B, получает **404** (или 403); мутирующие методы сервиса принимают и проверяют `user_id`. Аналогично — все чтения по чужому `session_id`.
- **Репро-тест:** создать сессию под B; из-под A вызвать `PATCH /sessions/{B_id}/stop` → ожидаем 404 и сессия B не изменилась. Падает сейчас.

### C3 · `BE-AUTH-01` · Дефолтные `SECRET_KEY`/`ENCRYPTION_KEY` не блокируют старт в production
**Файл:** `backend/app/config.py:13,78` · **✅ подтверждено**
Валидатор на дефолтные ключи вызывает `warnings.warn`, а не `raise` → возможен старт с публично известными ключами (подделка JWT, расшифровка брокерских токенов).
- **Acceptance:** при `ENVIRONMENT=production` и дефолтном `SECRET_KEY` **или** `ENCRYPTION_KEY` приложение **не стартует** (`ValueError`/`SystemExit`); в dev — прежнее предупреждение.
- **Репро-тест:** инстанцировать `Settings(ENVIRONMENT='production', SECRET_KEY='dev-secret-key-change-in-production')` → ожидаем исключение. Падает сейчас.

### C4 · `CFG-BE-01` · Cookie `access_token`/`csrf_token` с `secure=False` без гейта на окружение
**Файл:** `backend/app/auth/router.py:53` · **✅ подтверждено (дважды)**
Флаг `secure` захардкожен `False` → токен уходит по HTTP открытым.
- **Acceptance:** в production cookie ставятся с `secure=True` и корректным `SameSite`; значение вычисляется из окружения/схемы, не захардкожено.
- **Репро-тест:** проверить `Set-Cookie` при `ENVIRONMENT=production` → есть `Secure`. Падает сейчас.

### C5 · `SEC-01` · Реальный `TELEGRAM_WEBHOOK_SECRET` закоммичен в git
**Файл:** `backend/assets/telegram_bot_setup.md:56` · **✅ подтверждено** (файл отслеживается git, значение — реальная hex-строка)
- **Acceptance (вне кода!):** значение удалено из файла (плейсхолдер); секрет **ротирован** у BotFather/в инфраструктуре; вычищен из истории git (`git filter-repo`); `git log -p -- '*.md'` не содержит реальных секретов; добавлено правило в `.gitignore`/pre-commit hook (например `gitleaks`).
- **Проверка:** `git grep` по паттернам секретов в отслеживаемых файлах — пусто; CI-шаг secret-scan зелёный.

### C6 · `BE-TRAD-01` · `close_all_positions` закрывает без exit_price/PnL, без ордера брокеру и возврата средств
**Файл:** `backend/app/trading/engine.py:1673` · **✅ подтверждено**
Позиции помечаются закрытыми без реального ордера и расчёта → рассинхрон с брокером и потеря средств. Этот же путь вызывается из C1/C2.
- **Acceptance:** закрытие идёт через рыночный ордер брокеру (real) или по текущей цене (paper); фиксируются `exit_price`, реализованный PnL, средства возвращаются на баланс; при ошибке брокера позиция **не** помечается закрытой.
- **Репро-тест:** сессия с открытой позицией → `close_all_positions` → у позиции задан `exit_price`, PnL посчитан, баланс изменён на сумму закрытия. Падает сейчас.

### C7 · `BE-MISC-16` · Реверс-сплит обнуляет позицию из-за усечения `int()`
**Файл:** `backend/app/corporate_actions/service.py:52` · **✅ подтверждено**
`int(old_volume * ratio_to / ratio_from)` при консолидации (10:1, 5 лотов) → `int(0.5)=0`: позиция обнуляется, стоимость теряется.
- **Acceptance:** при консолидации объём считается по правилам биржи, дробная часть компенсируется деньгами (cash-in-lieu) либо сплит блокируется с уведомлением при неделимом объёме; стоимость позиции сохраняется (инвариант: `volume*price` до ≈ после + cash).
- **Репро-тест:** позиция 5 лотов, сплит `ratio_from=10, ratio_to=1` → объём не 0, суммарная стоимость сохранена. Падает сейчас.

### ⚠️ Переклассифицировано в High: `BE-STRAT-01` · исполнение пользовательского Python в бэктесте
Исходно critical. Реальный `exec` — в `backtest/engine.py:507`/`sandbox/executor.py`, защищён `ASTAnalyzer` + вычищенными builtins (не «открытый exec», атрибуция `schemas.py:87` неверна). Ведётся как **P1** (`BE-STRAT-01`), рекомендация — вынос исполнения в отдельный процесс/контейнер. Подробно — отчёт, раздел 3.

---

## P1 — High (исправить до сдачи) — 68 пунктов

Сгруппировано по модулям (каждый модуль — кандидат в отдельную ветку/DEV-задачу). Полное описание и рекомендация по каждому ID — в отчёте. Статус в колонке «В»: ✅ — подтверждено (адверсариальная проверка и/или шаг 2), ❓ — спорно/нужен контекст вызова. **Непроверенных High не осталось.**

> 🔧 Все P1 развёрнуты в TDD-задачи по 17 веткам с «Проблемой» и «Fix» из отчёта — см. [`tdd_tasks_P1.md`](tdd_tasks_P1.md).

#### CFG-BE — Security: конфигурация backend (1)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| CFG-BE-02 | `backend/app/config.py:13` | 🔓 уязв | ✅ | Дефолтные значения SECRET_KEY и ENCRYPTION_KEY — предсказуемые строки, отсутствие жёсткого блока запуска в production |

#### CFG-FE — Security: конфигурация frontend/XSS (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| CFG-FE-01 | `frontend/src/stores/authStore.ts:145` | 🔓 уязв | ✅ | JWT access/refresh токены персистятся в localStorage (доступны из JS, нет HttpOnly) |
| CFG-FE-02 | `frontend/src/hooks/useWebSocket.ts:23` | 🔓 уязв | ✅ | JWT передаётся в query-string WebSocket URL (`ws://...?token=...`) |

#### AUTHZ — Security: авторизация (IDOR) (5)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| AUTHZ-02 | `backend/app/trading/router.py:101` | 🔓 уязв | ✅ | IDOR: пауза/возобновление чужой торговой сессии без проверки владельца |
| AUTHZ-03 | `backend/app/trading/router.py:188` | 🔓 уязв | ✅ | IDOR-чтение: история сделок и статистика P&L чужой сессии |
| AUTHZ-04 | `backend/app/backtest/ws.py:94` | 🔓 уязв | ✅ | Broken access control на мультиплексном /ws: подписка на любой чужой канал |
| AUTHZ-05 | `backend/app/notification/router.py:428` | 🔓 sec | ✅ | Обход аутентификации Telegram-webhook при пустом TELEGRAM_WEBHOOK_SECRET |
| AUTHZ-06 | `backend/app/config.py:13` | 🔓 sec | ✅ | Дефолтный SECRET_KEY только предупреждает — риск подделки JWT и захвата аккаунтов |

#### BE-AUTH — Backend: auth/middleware/ядро (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-AUTH-02 | `backend/app/middleware/csrf.py:26` | 🐛 баг | ✅ | /auth/refresh не в EXEMPT_PATHS — в production каждый refresh токена падает с 403 и пользователь разлогинивается |
| BE-AUTH-03 | `backend/app/auth/router.py:174` | 🔓 уязв | ✅ | Logout не отзывает refresh-токен, а refresh не ротируется — сессию невозможно принудительно завершить |

#### BE-BROK — Backend: брокер/крипто (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-BROK-01 | `backend/app/broker/tinvest/multiplexer.py:197` | 🐛 баг | ✅ | Мультиплексор маршрутизирует свечи только по figi, игнорируя interval — подписчики получают свечи чужого таймфрейма |
| BE-BROK-02 | `backend/app/common/crypto.py:14` | 🔓 уязв | ✅ | Production может незаметно работать с публичным dev-ключом шифрования — брокерские токены расшифровываются известным ключом |

#### BE-TRAD — Backend: торговля (9)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-TRAD-03 | `backend/app/trading/engine.py:904` | 🐛 баг | ✅ | Exit-сигнал стратегии никогда не закрывает позицию — блокируется `max_concurrent_positions` |
| BE-TRAD-04 | `backend/app/trading/runtime.py:246` | 🐛 баг | ✅ | Каждое intra-bar обновление свечи обрабатывается как закрытый бар |
| BE-TRAD-05 | `backend/app/trading/runtime.py:1010` | 🐛 баг | ✅ | Сверка позиций real-сессий при рестарте не выполняется никогда |
| BE-TRAD-06 | `backend/app/trading/paper_engine.py:172` | 🐛 баг | ✅ | Paper-портфель: покупка не списывает средства, ручное закрытие зачисляет выручку «из воздуха» — **✅ РЕШЕНО 2026-07-22 (Model A, ветка `p1/be-trad-06`, коммиты `035f817..50f3335`; `BE_TRAD_06_LOG.md`)** |
| BE-TRAD-07 | `backend/app/trading/engine.py:1465` | 🐛 баг | ✅ | Ручное закрытие pending-сделки (entry_price=NULL) записывает фиктивную прибыль |
| BE-TRAD-08 | `backend/app/trading/engine.py:929` | качест | ✅ | Нарушение границ: FIGI для sandbox/real-сделок берётся из paper-заглушки |
| BE-TRAD-09 | `backend/app/trading/engine.py:938` | качест | ✅ | Проглоченный `except Exception` при получении lot_size — молчаливый fallback на 1 даёт 10-кратный оверсайз позиции |
| BE-TRAD-10 | `backend/app/trading/router.py:102` | 🔓 уязв | ✅ | IDOR: пауза/возобновление чужой торговой сессии без проверки владельца |
| BE-TRAD-11 | `backend/app/trading/router.py:189` | 🔓 уязв | ✅ | IDOR-чтение: раскрытие всех сделок чужой сессии (цены, объёмы, P&L) |

#### BE-STRAT — Backend: стратегии (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-STRAT-02 | `backend/app/strategy/router.py:244` | 🐛 баг | ✅ | Два несовместимых формата blocks_json: «Применить из Grid Search» молча не меняет поведение бэктеста/live |
| BE-STRAT-03 | `backend/app/strategy/evaluator.py:178` | 🐛 баг | ✅ | evaluate() игнорирует ir.time_filter — live/paper торговля торгует вне временного окна стратегии |
| BE-STRAT-04 | `backend/app/strategy/models.py:45` | качест | ✅ | N+1 и eager-загрузка тяжёлых blob-полей на списке стратегий (дашборд) |

#### BE-BTST — Backend: бэктест (4)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-BTST-01 | `backend/app/backtest/router.py:1203` | 🐛 баг | ✅ | GET /backtest/jobs недостижим: маршрут перекрыт /{backtest_id}, эндпоинт возвращает 422 |
| BE-BTST-02 | `backend/app/backtest/engine.py:101` | 🐛 баг | ✅ | TradeRecorder жёстко пишет direction="long" — short-сделки искажены и ложно блокируют live через parity-гейт |
| BE-BTST-03 | `backend/app/backtest/ws.py:92` | 🔓 уязв | ✅ | IDOR на мультиплексном WebSocket /ws: подписка на чужие каналы backtest:{id} и trades:{session_id} |
| BE-BTST-04 | `backend/app/backtest/engine.py:508` | 🔓 уязв | ✅ | exec() пользовательского Python (generated_code) в основном процессе за денилист-фильтром |

#### BE-MKT — Backend: рыночные данные (5)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-MKT-01 | `backend/app/market_data/router.py:139` | 🔓 уязв | ✅ | Cross-user: GET /candles ложно триггерит и деактивирует чужие ценовые оповещения произвольной исторической ценой |
| BE-MKT-02 | `backend/app/market_data/service.py:757` | ⚙️ кач | ✅ | MarketDataService коммитит/роллбэчит чужую (injected) сессию в hot-path'ах трейдинга |
| BE-MKT-03 | `backend/app/market_data/bond_service.py:41` | 🐛 баг | ✅ | TypeError aware-naive datetime: все bond-эндпоинты падают 500 при любом повторном запросе |
| BE-MKT-04 | `backend/app/market_data/service.py:151` | 🐛 баг | ✅ | _build_current_candle подмешивает сегодняшнюю недостроенную свечу в исторический диапазон, включая бэктест |
| BE-MKT-05 | `backend/app/market_data/stream_manager.py:84` | 🐛 баг | ✅ | Многократный overcount volume в live-агрегаторе из-за interim-обновлений незакрытой минутной свечи |

#### BE-NOTIF — Backend: уведомления (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-NOTIF-02 | `backend/app/notification/service.py:286` | 🐛 баг | ✅ | create_notification держит write-транзакцию SQLite во время сетевых вызовов Telegram/SMTP |
| BE-NOTIF-03 | `backend/app/notification/models.py:51` | ⚙️ кач | ✅ | Нет UniqueConstraint (user_id, event_type) на user_notification_settings — дубликаты навсегда ломают уведомления |

#### BE-AI — Backend: AI (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-AI-01 | `backend/app/ai/router.py:118` | 🔓 уязв | ✅ | SSRF: неограниченный `api_base_url` отправляет запросы бэкенда на произвольный внутренний хост |
| BE-AI-02 | `backend/app/ai/context.py:79` | качест | ✅ | `ContextCompressor` формирует сообщения, начинающиеся с `role=assistant` — Claude API отвергает такой запрос |

#### BE-RT — Backend: circuit breaker/sandbox/scheduler (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-RT-01 | `backend/app/circuit_breaker/engine.py:322` | 🐛 баг | ✅ | Проверка max_position_size игнорирует lot_size — риск-лимит занижен в 10–100 раз |
| BE-RT-02 | `backend/app/sandbox/schemas.py:17` | 🔓 уязв | ✅ | timeout в /sandbox/execute не валидируется и не ограничен сверху — DoS общего ThreadPoolExecutor backend |
| BE-RT-03 | `backend/app/circuit_breaker/schemas.py:18` | 🐛 баг | ✅ | trading_hours_start/end не валидируются — конфиг произвольной строкой роняет check_before_order на каждом сигнале |

#### BE-MISC — Backend: common/CLI/backup/admin/tax/corp (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-MISC-17 | `backend/app/admin/dash_mount.py:112` | 🔓 уязв | ✅ | `AdminAuthASGIMiddleware` не привязывает JWT к отзыву токена (`token_version`) |
| BE-MISC-18 | `backend/app/tax/service.py:112` | 🐛 баг | ✅ | Годовой фильтр налогового отчёта смешивает локальное время и naive UTC |
| BE-MISC-19 | `backend/app/tax/service.py:260` | 🐛 баг | ✅ | `_calculate_tax_base` нетит убытки между разными типами инструментов |

#### FE-NET — Frontend: сетевой слой (4)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-NET-01 | `frontend/src/hooks/useWebSocket.ts:23` | 🔓 уязв | ✅ | JWT access/refresh токены передаются в query string общего WebSocket-канала |
| FE-NET-02 | `frontend/src/stores/authStore.ts:145` | 🔓 уязв | ✅ | JWT access/refresh токены персистятся в localStorage — компрометация сессии при любом XSS |
| FE-NET-03 | `frontend/src/api/backtestApi.ts:38` | 🐛 баг | ✅ | Decimal-поля BacktestMetrics/BacktestTrade/EquityPoint типизированы как number вместо string — риск TypeError в проде |
| FE-NET-04 | `frontend/src/hooks/useBacktestJobWS.ts:257` | 🐛 баг | ❓ | useBackgroundBacktestsBootstrap не переподключается при обрыве WS фонового бэктеста |

#### FE-STOR — Frontend: stores (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-STOR-12 | `frontend/src/stores/backtestStore.ts:129` | 🔓 уязв | ✅ | JWT-токен передаётся в query-string WebSocket URL (второе, независимое место) |
| FE-STOR-13 | `frontend/src/stores/authStore.ts:62` | 🔓 уязв | ✅ | Логирование префикса JWT-токена в консоль при логине |

#### FE-PAGE — Frontend: страницы (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-PAGE-01 | `frontend/src/pages/StrategyEditPage.tsx:67` | ⚙️ кач | ✅ | God-компонент StrategyEditPage: 1101 строка, смешаны состояние формы, Blockly, версии, бэктесты и рендер вкладок |
| FE-PAGE-02 | `frontend/src/pages/StrategyEditPage.tsx:1086` | 🐛 баг | ✅ | Массовое удаление бэктестов не обрабатывает частичный отказ Promise.all |
| FE-PAGE-03 | `frontend/src/pages/LoginPage.tsx:53` | 🔓 уязв | ✅ | JWT access/refresh токены хранятся в localStorage через zustand persist — риск полного захвата сессии при XSS |

#### FE-CHART — Frontend: графики (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-CHART-01 | `frontend/src/components/charts/primitives/VlinePrimitive.ts:27` | 🐛 баг | ❓ | VlinePrimitive не поддерживает sequential (intraday) mode — линия не отображается или рисуется в неверном месте |
| FE-CHART-02 | `frontend/src/components/charts/CandlestickChart.tsx:138` | ⚙️ кач | ✅ | God-компонент: 907 строк, 8 useEffect, смешение data-layer/WS/маркеров/рендера |
| FE-CHART-03 | `frontend/src/components/charts/primitives/coords.ts:17` | ⚙️ кач | ✅ | MSK_OFFSET_SEC и парсинг UTC-таймстампа с MSK-сдвигом продублированы в трёх файлах |

#### FE-BTST — Frontend: бэктест (4)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-BTST-13 | `frontend/src/components/backtest/BacktestProgress.tsx:55` | 🐛 баг | ✅ | Автонавигация `BacktestProgress` не сверяет id завершившегося бэктеста — переход на чужой |
| FE-BTST-14 | `frontend/src/components/backtest/BacktestProgress.tsx:34` | 🐛 баг | ✅ | `BacktestProgress` не отписывается от WS/polling при размонтировании — утечка и запись в стор после ухода |
| FE-BTST-15 | `frontend/src/components/backtest/InstrumentChart.tsx:289` | 🐛 баг | ❓ | rAF-цикл перерисовки фоновых зон в `InstrumentChart` работает даже на скрытом компоненте |
| FE-BTST-16 | `frontend/src/components/backtest/PnLDistributionHistogram.tsx:50` | 🐛 баг | ✅ | `PnLDistributionHistogram`: `bucketCount` не ограничен сверху — риск подвесить рендер на аномальных данных |

#### FE-STRAT — Frontend: конструктор стратегий (1)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-STRAT-01 | `frontend/src/components/strategy/BlocklyWorkspace.tsx:196` | 🔓 уязв | ✅ | Загрузка Blockly workspace state/XML без валидации типов блоков против allow-list |

#### FE-TRAD — Frontend: торговля/дашборд/счёт (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-TRAD-01 | `frontend/src/stores/tradingStore.ts:156` | 🐛 баг | ✅ | Race condition: устаревший ответ fetchPositions/fetchTrades/fetchStats перетирает данные другой сессии |
| FE-TRAD-02 | `backend/app/trading/schemas.py:110` | 🐛 баг | ✅ | SessionResponse сериализует даты без Z-суффикса — время сессии сдвигается на 3 часа на фронтенде |

#### FE-UI — Frontend: прочий UI (1)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-UI-01 | `frontend/src/components/notifications/CriticalBanner.tsx:12` | 🐛 баг | ✅ | Автозакрытие критического баннера ломается при любом новом уведомлении |

#### FE-CORE — Frontend: утилиты/ядро (5)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-CORE-01 | `frontend/src/utils/tradeMarkerUtils.ts:108` | 🐛 баг | ✅ | computeChartZones перезаписывает pnl чужой сделки при близких entry-маркерах (±3600с), искажая цвет зоны на графике |
| FE-CORE-02 | `frontend/src/utils/formatters.ts:15` | 🐛 баг | ✅ | formatDate/formatDateTime не нормализуют naive UTC datetime от backend — даты сделок/операций отображаются со сдвигом на 3 часа |
| FE-CORE-06 | `frontend/src/utils/formatters.ts:16` | ⚙️ кач | ✅ | `formatDate`/`formatDateTime` парсят дату в обход `parseBackendDate` (тот же класс багов, что закрыт ранее) |
| FE-CORE-07 | `frontend/src/App.tsx:3` | ⚙️ кач | ✅ | Тяжёлые страницы (Blockly, lightweight-charts) не загружаются лениво |
| FE-CORE-08 | `frontend/src/App.tsx:27` | ⚙️ кач | ✅ | Дублирование guard-логики защищённых роутов — `frontend/src/App.tsx:27` и `frontend/src/routes/ProtectedAdminRoute.tsx:23` |


---

## P2 — Medium (ближайший бэклог) — 152 пункта

Рекомендация по каждому ID — в отчёте. Верификация — по мере взятия в работу (репро-тест обязателен).

#### CFG-BE — Security: конфигурация backend (1)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| CFG-BE-03 | `backend/app/main.py:301` | 🔓 sec | — | CORS allow_credentials=True скомбинирован с CORS_ORIGINS из .env без валидации на wildcard |

#### CFG-FE — Security: конфигурация frontend/XSS (1)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| CFG-FE-03 | `nginx.conf:20` | 🔓 sec | — | Отсутствуют HTTP security-заголовки (CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy) |

#### BE-AUTH — Backend: auth/middleware/ядро (15)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-AUTH-04 | `backend/app/auth/router.py:58` | 🔓 уязв | — | Cookie access_token и csrf_token выставляются с secure=False |
| BE-AUTH-05 | `backend/app/middleware/rate_limit.py:93` | 🔓 уязв | — | Rate-limit логина ключуется по request.client.host — за nginx все клиенты делят один лимит |
| BE-AUTH-06 | `backend/app/auth/router.py:64` | 🔓 уязв | — | Открытая регистрация /auth/setup без гейта и без rate-limit |
| BE-AUTH-07 | `backend/app/middleware/rate_limit.py:46` | 🐛 баг | — | Неограниченный рост in-memory словаря rate limiter'а + блокирующий Lock в async-контексте |
| BE-AUTH-08 | `backend/app/main.py:73` | ⚙️ кач | — | lifespan — перегруженная функция в composition root с проглоченными исключениями и бизнес-логикой чужих модулей |
| BE-AUTH-09 | `backend/app/auth/router.py:110` | ⚙️ кач | — | Бизнес-логика market_data (prefetch) внутри auth-роутера + fire-and-forget asyncio.create_task без сохранения ссылки |
| BE-AUTH-10 | `backend/app/account/service.py:170` | ⚙️ кач | — | Денежные значения конвертируются в float вопреки конвенции проекта (Decimal для денег) |
| BE-AUTH-11 | `backend/app/config.py:19` | ⚙️ кач | — | Невалидный дефолт AI_MODEL: датированный суффикс не существует |
| BE-AUTH-12 | `backend/app/auth/service.py:61` | ⚙️ кач | — | Фантомная конфигурация: getattr на несуществующих полях Settings (LOGIN_MAX_ATTEMPTS/LOGIN_LOCKOUT_MINUTES) |
| BE-AUTH-13 | `backend/app/main.py:416` | ⚙️ кач | — | health_check обращается к приватным внутренностям чужих модулей и некорректно использует генератор get_db |
| BE-AUTH-14 | `backend/app/auth/service.py:63` | 🐛 баг | — | Счётчик failed_login_count не сбрасывается после истечения блокировки — одна ошибка повторно блокирует аккаунт на 15 минут |
| BE-AUTH-15 | `backend/app/auth/service.py:126` | 🐛 баг | — | Синхронные argon2 hash/verify блокируют event loop на каждом login/register/change_password |
| BE-AUTH-16 | `backend/app/account/service.py:150` | 🐛 баг | — | Сессии со started_at=None считаются активными на все даты — initial_capital ретроактивно надувает историю баланса |
| BE-AUTH-17 | `backend/app/account/service.py:79` | 🐛 баг | — | Окно истории баланса строится по UTC-датам, а DailyStat.date пишется локальной датой сервера (MSK) — свежий PnL пропадает до 03:00 МСК |
| BE-AUTH-18 | `backend/app/account/router.py:59` | 🐛 баг | — | since_first_activity: фильтрация в роутере вместо сервиса + предикат «> 0» теряет активность при нулевом/отрицательном балансе |

#### BE-BROK — Backend: брокер/крипто (10)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-BROK-03 | `backend/app/broker/router.py:244` | ⚙️ кач | — | Бизнес-логика в роутере: `get_account_balances` и `test_broker_connection` расшифровывают ключи и управляют адаптером напрямую |
| BE-BROK-04 | `backend/app/broker/schemas.py:78` | 🐛 баг | — | Денежные поля BrokerBalance — float вместо Decimal, а available приравнен к total — `backend/app/broker/schemas.py:78`, `backend/app/broker/router.py:293`, `backend/app/broker/tinvest/adapter.py:249` |
| BE-BROK-05 | `backend/app/broker/tinvest/adapter.py:362` | ⚙️ кач | — | N+1 к T-Invest: `_fetch_instrument_info_by_figi` без кеша на каждый FIGI |
| BE-BROK-06 | `backend/app/broker/tinvest/adapter.py:150` | 🐛 баг | — | `detect_token_mode`/`detect_trading_rights` глушат любые исключения — сетевой сбой диагностируется как «ключ отклонён» |
| BE-BROK-07 | `backend/app/broker/moex_iss/client.py:274` | ⚙️ кач | — | `get_trading_calendar` принимает параметр `year`, но никогда его не использует |
| BE-BROK-08 | `backend/app/broker/tinvest/adapter.py:270` | ⚙️ кач | — | `_resolve_figi` ищет только акции (class_code=TQBR) — ордера и подписки по облигациям/ETF невозможны |
| BE-BROK-09 | `backend/app/broker/service.py:21` | ⚙️ кач | — | Инверсия границ модулей: `broker.service` импортирует модели `trading` (LiveTrade, TradingSession) |
| BE-BROK-10 | `backend/app/broker/service.py:460` | ⚙️ кач | — | Duck-typing через `getattr` вместо расширения `BaseBrokerAdapter`; ABC `get_operations` возвращает нетипизированный `list[dict]` |
| BE-BROK-11 | `backend/app/broker/service.py:118` | 🐛 баг | — | Повторное подключение с новым API-ключом молча оставляет в БД старый (протухший) ключ |
| BE-BROK-12 | `backend/app/broker/tinvest/adapter.py:582` | 🐛 баг | — | `place_order` выбирает `ORDER_TYPE_LIMIT`, но не передаёт `price` в `post_order` — лимитные ордера всегда падают |

#### BE-TRAD — Backend: торговля (10)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-TRAD-12 | `backend/app/trading/service.py:309` | ⚙️ кач | — | N+1 и загрузка всех сделок в память в `get_sessions` — 4-5 запросов на каждую сессию списка |
| BE-TRAD-13 | `backend/app/trading/engine.py:1788` | ⚙️ кач | — | `PositionTracker` — мёртвый код с устаревшей логикой (PnL без lot_size, N+1 в цикле) |
| BE-TRAD-14 | `backend/app/trading/engine.py:1216` | 🐛 баг | — | `volume_rub` при fill от брокера считается без lot_size — занижение в lot_size раз |
| BE-TRAD-15 | `backend/app/trading/risk_monitor.py:361` | 🐛 баг | — | `_apply_close` считает PnL по `volume_lots` вместо `filled_lots` — завышение при частичном исполнении |
| BE-TRAD-16 | `backend/app/trading/engine.py:1616` | 🐛 баг | — | Timeout поллинга закрытия sandbox/real провоцирует повторный ордер и незапланированный шорт |
| BE-TRAD-17 | `backend/app/trading/runtime.py:1313` | ⚙️ кач | — | SignalProcessor создаётся заново на каждую свечу — кеш стратегий мёртв, `parse_blocks` выполняется дважды за свечу |
| BE-TRAD-18 | `backend/app/trading/runtime.py:684` | ⚙️ кач | — | Дублирование `_resolve_broker_adapter` + connect/disconnect брокера на каждый orphan-trade |
| BE-TRAD-19 | `backend/app/trading/engine.py:1134` | ⚙️ кач | — | `_submit_order_to_broker` и `close_position` — методы по 200+ строк с продублированными ветками обработки fill |
| BE-TRAD-20 | `backend/app/trading/runtime.py:399` | 🐛 баг | — | `SessionRuntime.stop` не отписывает market-стрим — утечка gRPC-подписок T-Invest |
| BE-TRAD-21 | `backend/app/trading/router.py:221` | 🔓 уязв | — | IDOR-чтение: агрегированная статистика (P&L, equity-кривая) чужой сессии |

#### BE-STRAT — Backend: стратегии (9)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-STRAT-05 | `backend/app/strategy/code_generator.py:13` | качест | — | code_generator.py — 682 строки мёртвого кода, на который живые модули ссылаются как на эталон |
| BE-STRAT-06 | `backend/app/strategy/ir_codegen.py:104` | качест | — | Расхождение имён параметров: ir_codegen генерирует kind-based (bollinger_*), params/params_sync ждут name-based (bb_*) |
| BE-STRAT-07 | `backend/app/strategy/evaluator.py:64` | 🐛 баг | — | Разные default-периоды SMA/EMA в интерпретаторе (20) и кодогенераторе (14) — parity ломается по построению |
| BE-STRAT-08 | `backend/app/strategy/router.py:276` | 🐛 баг | — | IR-путь from-params: parse_blocks не читает flat-формат — generated_code может быть затёрт пустым placeholder'ом |
| BE-STRAT-09 | `backend/app/strategy/service.py:368` | 🐛 баг | — | delete() удаляет стратегию без проверки активных торговых сессий и бэктестов — висячие FK |
| BE-STRAT-10 | `backend/app/strategy/service.py:553` | 🐛 баг | — | Идемпотентность auto-snapshot сравнивает только blocks+code — правки описания молча теряются |
| BE-STRAT-11 | `backend/app/strategy/block_parser.py:893` | 🐛 баг | — | Decimal утекает в blocks_json (старый формат + _parse_params_str) — фронт получает строки вместо чисел — `backend/app/strategy/block_parser.py:893` (доп. `:841`) |
| BE-STRAT-12 | `backend/app/strategy/router.py:186` | качест | — | create_version_from_params: ~190 строк бизнес-логики и прямые запросы к БД в роутере |
| BE-STRAT-13 | `backend/app/strategy/ir_codegen.py:250` | 🔓 уязв | — | Неотфильтрованное поле source индикатора инъектируется в генерируемый Python-код |

#### BE-BTST — Backend: бэктест (7)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-BTST-05 | `backend/app/backtest/service.py:74` | ⚙️ кач | — | Сервисный слой практически мёртв: логика продублирована в роутере, роутер вызывает приватный _save_result |
| BE-BTST-06 | `backend/app/backtest/router.py:488` | ⚙️ кач | — | N+1 запрос имён стратегий в list_backtests + lazy="selectin" на trades грузит все сделки всех бэктестов |
| BE-BTST-07 | `backend/app/backtest/jobs.py:237` | 🐛 баг | — | Двойное уведомление «Бэктест завершён» для фоновых бэктестов, второе — с пустыми плейсхолдерами |
| BE-BTST-08 | `backend/app/backtest/router.py:783` | ⚙️ кач | — | except Exception: pass без логирования при загрузке свечей в _build_backtest_response |
| BE-BTST-09 | `backend/app/backtest/grid.py:407` | ⚙️ кач | — | Grid Search пиклит полную серию свечей на каждую комбинацию (до 1000 копий через IPC) |
| BE-BTST-10 | `—` | — | — | GET /api/v1/backtest/jobs перекрыт маршрутом GET /{backtest_id} — эндпоинт возвращает 422 (дубль записи из измерения bugs) |
| BE-BTST-11 | `backend/app/backtest/jobs.py:194` | 🐛 баг | — | Отмена фоновой job не останавливает вычисления и оставляет Backtest навсегда в running/queued |

#### BE-MKT — Backend: рыночные данные (15)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-MKT-06 | `backend/app/market_data/service.py:60` | баг /  | — | MOEXISSClient создаётся на каждый запрос и никогда не закрывается — утечка httpx.AsyncClient |
| BE-MKT-07 | `backend/app/market_data/router.py:142` | ⚙️ кач | — | Проверка price alerts в GET /candles: бизнес-логика в роутере + `except Exception: pass` без логирования |
| BE-MKT-08 | `backend/app/market_data/router.py:208` | 🔓 уязв | — | subscribe_candle_stream: резолв BrokerAccount и расшифровка ключей в роутере, ошибки возвращаются как str(e) с HTTP 200 |
| BE-MKT-09 | `backend/app/market_data/service.py:871` | ⚙️ кач | — | Дублирование: _fetch_isin_from_tinvest и _fetch_lot_size_from_tinvest — два почти идентичных метода (плюс ещё 2 копии резолва аккаунта) |
| BE-MKT-10 | `backend/app/market_data/service.py:333` | ⚙️ кач | — | Таймфрейм-машинерия продублирована между service.py и stream_manager.py и уже разошлась |
| BE-MKT-11 | `backend/app/market_data/service.py:606` | ⚙️ кач | — | _save_to_cache вставляет свечи по одной строке в цикле — десятки тысяч последовательных execute |
| BE-MKT-12 | `backend/app/market_data/bond_service.py:78` | ⚙️ кач | — | _fetch_bond_from_iss обходит публичный API ISS-клиента: приватный _get_client(), без retry и без проверки статуса ответа |
| BE-MKT-13 | `backend/app/market_data/stream_manager.py:249` | ⚙️ кач | — | is_stream_healthy читает приватные атрибуты адаптера через getattr |
| BE-MKT-14 | `backend/app/market_data/price_alert_monitor.py:40` | ⚙️ кач | — | Trigger-логика алертов продублирована в check_alerts_for_figi и _check_ticker; check_alerts_for_ticker — мёртвый код |
| BE-MKT-15 | `backend/app/market_data/router.py:35` | ⚙️ кач | — | Третий экземпляр MOEXCalendarService в fallback-режиме: /market-status и /calendar не знают реальных праздников MOEX |
| BE-MKT-16 | `backend/app/market_data/stream_manager.py:132` | 🐛 баг | — | Race condition в subscribe: параллельные вызовы создают дублирующие адаптеры и подписки |
| BE-MKT-17 | `backend/app/market_data/stream_manager.py:132` | 🔓 уязв | — | Cross-tenant переиспользование брокерского токена: стрим кэшируется по ticker:timeframe без привязки к пользователю |
| BE-MKT-18 | `backend/app/market_data/service.py:141` | 🐛 баг | — | Фильтр «аукционных» свечей выбрасывает реальные doji-свечи без проверки объёма |
| BE-MKT-19 | `backend/app/market_data/router.py:161` | 🐛 баг | — | Стримы свечей никогда не отписываются: подписки накапливаются до рестарта приложения |
| BE-MKT-20 | `backend/app/market_data/service.py:595` | 🐛 баг | — | Незакрытая (текущая) свеча из T-Invest REST кэшируется как завершённая |

#### BE-NOTIF — Backend: уведомления (9)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-NOTIF-04 | `backend/app/notification/dispatchers.py:26` | ⚙️ кач | — | dispatchers.py — мёртвый код в production, дублирующий и расходящийся с NotificationService.dispatch_external |
| BE-NOTIF-05 | `backend/app/notification/telegram_webhook.py:56` | 🐛 баг | — | _get_last_close_price не фильтрует OHLCVCache по timeframe — P&L в боте считается по свече чужого таймфрейма (регрессия ранее исправленного бага) |
| BE-NOTIF-06 | `backend/app/notification/telegram_webhook.py:532` | баг /  | — | /balance: adapter.disconnect() не в finally — утечка gRPC-канала при ошибке get_balance, плюс дублирование логики broker/router.py |
| BE-NOTIF-07 | `backend/app/notification/telegram_webhook.py:841` | ⚙️ кач | — | Дублирование ownership-check и закрытия позиции между _handle_close и _execute_close_position |
| BE-NOTIF-08 | `backend/app/notification/router.py:234` | ⚙️ кач | — | Глобальное мутабельное состояние _webhook_handler в модуле роутера вместо app.state (нарушение собственного паттерна C7) |
| BE-NOTIF-09 | `backend/app/notification/router.py:349` | ⚙️ кач | — | /telegram/test: бизнес-логика и HTTP-клиент прямо в роутере, inline-схема, deprecated datetime.utcnow() |
| BE-NOTIF-10 | `backend/app/notification/service.py:405` | ⚙️ кач | — | Молчаливые except Exception без логирования в резолвинге ticker/цены/lot_size |
| BE-NOTIF-11 | `backend/app/notification/router.py:54` | 🐛 баг | — | Фильтры date_from/date_to сравнивают aware-datetime с naive-UTC created_at — сдвиг на 3 часа для МСК |
| BE-NOTIF-12 | `backend/app/notification/link_store.py:26` | 🔓 уязв | — | Слабая энтропия токена привязки Telegram (6 цифр) без ограничения попыток |

#### BE-AI — Backend: AI (10)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-AI-03 | `backend/app/ai/chat_router.py:418` | качест | — | `/explain` проверяет бюджет, но никогда не списывает токены — обход лимита расходов |
| BE-AI-04 | `backend/app/ai/service.py:150` | качест | — | `increment_usage`: неатомарный read-modify-write счётчиков токенов (lost update) + произвольный commit |
| BE-AI-05 | `backend/app/ai/providers/claude_provider.py:44` | качест | — | `ClaudeProvider` выбрасывает реальный usage из ответа API — учёт токенов идёт по грубой оценке len/4 |
| BE-AI-06 | `backend/app/ai/chat_schemas.py:43` | 🐛 баг | — | Attachments из запроса чата молча отбрасываются — вложения никогда не доходят до LLM |
| BE-AI-07 | `backend/app/ai/slash_context.py:213` | 🐛 баг | — | PnL в slash-контексте `/session` и `/portfolio` считается без стоимости открытых позиций |
| BE-AI-08 | `backend/app/ai/providers/factory.py:30` | 🐛 баг | — | Провайдеры deepseek/openrouter/groq/qwen без `api_base_url` дают необработанный `ValueError` → 500 в чате |
| BE-AI-09 | `backend/app/ai/chat_router.py:236` | качест | — | Широкие `except Exception` превращают любые ошибки (включая баги кода) в 400/SSE-error и отдают `str(e)` клиенту |
| BE-AI-10 | `backend/app/ai/chat_router.py:270` | ⚙️ кач | — | ~50 строк дублирования между `chat()` и `chat_stream()` |
| BE-AI-11 | `backend/app/ai/router.py:243` | качест | — | `update_instructions` принимает нетипизированный `dict` без валидации — риск роста стоимости и 500 при некорректном значении |
| BE-AI-12 | `backend/app/ai/chat_router.py:238` | 🔓 уязв | — | Раскрытие внутренних деталей через возврат сырого `str(e)` провайдера клиенту |

#### BE-RT — Backend: circuit breaker/sandbox/scheduler (10)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-RT-04 | `backend/app/circuit_breaker/engine.py:96` | ⚙️ кач | — | N+1 на hot path circuit breaker: каждая проверка заново грузит config, user и список сессий |
| BE-RT-05 | `backend/app/circuit_breaker/engine.py:398` | 🐛 баг | — | scalar_one_or_none() падает с MultipleResultsFound при 2+ открытых противоположных сделках |
| BE-RT-06 | `backend/app/circuit_breaker/engine.py:179` | 🐛 баг | — | Дневной лимит убытков и лимит сделок обходятся через stop/start сессий |
| BE-RT-07 | `backend/app/circuit_breaker/engine.py:579` | 🐛 баг | — | CircuitBreakerEvent всегда пишется с trigger_value=0 и limit_value=0 — поля мертвы с момента создания |
| BE-RT-08 | `backend/app/circuit_breaker/engine.py:449` | ⚙️ кач | — | Session-override конфига молча игнорируется в _check_trading_hours и _check_short_block |
| BE-RT-09 | `backend/app/scheduler/service.py:45` | 🐛 баг | — | sync_moex_calendar — no-op: ISS-клиент никогда не передаётся, лог рапортует о несуществующем успехе |
| BE-RT-10 | `backend/app/scheduler/service.py:364` | 🐛 баг | — | Unrealized PnL в дневной статистике считается без lot_size — занижен в разы |
| BE-RT-11 | `backend/app/scheduler/service.py:487` | ⚙️ кач | — | schedule_t1_unlock — мёртвый код, docstring модуля заявляет несуществующую задачу |
| BE-RT-12 | `backend/app/sandbox/executor.py:101` | ⚙️ кач | — | Мутация общего safe_globals RestrictedPython через shallow copy — процесс-wide side effect |
| BE-RT-13 | `backend/app/sandbox/ast_analyzer.py:65` | ⚙️ кач | — | WHITELIST_MODULES анализатора не согласован с _safe_import исполнителя — противоречивая валидация /analyze vs /execute |

#### BE-MISC — Backend: common/CLI/backup/admin/tax/corp (13)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-MISC-01 | `backend/app/tax/service.py:281` | ⚙️ кач | — | Рассчитанный налог (tax_amount) и разбивка by_type вычисляются и выбрасываются |
| BE-MISC-02 | `backend/app/tax/service.py:96` | ⚙️ кач | — | Широкий except Exception в generate_report: причина ошибки теряется, клиент получает 200 без деталей |
| BE-MISC-03 | `backend/app/tax/service.py:350` | ⚙️ кач | — | Блокирующий файловый I/O (openpyxl, csv) внутри async-эндпоинта без run_in_executor |
| BE-MISC-04 | `backend/app/tax/service.py:112` | 🐛 баг | — | Границы налогового года считаются в naive UTC вместо Europe/Moscow |
| BE-MISC-05 | `backend/app/tax/service.py:419` | 🐛 баг | — | Эвристика _detect_instrument_type классифицирует акции с префиксом RU/SU как облигации + warning-спам |
| BE-MISC-06 | `backend/app/tax/service.py:84` | ⚙️ кач | — | TaxLot не связан с TaxReport: дубликаты лотов при каждой генерации отчёта |
| BE-MISC-07 | `backend/app/common/trading_hours.py:19` | 🐛 баг | — | Дублирование торговых часов с circuit_breaker и игнорирование выходных/конфига |
| BE-MISC-08 | `backend/app/corporate_actions/service.py:194` | ⚙️ кач | — | Нарушение границы модуля: обращение к приватному _get_client() ISS-клиента и ручной парсинг ISS-ответа |
| BE-MISC-09 | `backend/app/corporate_actions/service.py:223` | ⚙️ кач | — | N+1 запросы: existence-check на каждую строку дивидендов и SELECT портфеля/статистики на каждый trade |
| BE-MISC-10 | `backend/app/admin/metrics_dash.py:70` | ⚙️ кач | — | Страница /admin/metrics целиком на захардкоженных mock-данных при сдаче в production |
| BE-MISC-20 | `backend/app/corporate_actions/router.py:79` | 🔓 уязв | — | `POST /corporate-actions/detect` — тяжёлые внешние запросы по произвольным тикерам без ограничений |
| BE-MISC-21 | `backend/app/backup/service.py:136` | 🐛 баг | — | `rotate()` бэкапов не берёт `asyncio.Lock` и падает на исчезнувшем файле |
| BE-MISC-22 | `backend/app/corporate_actions/service.py:37` | 🐛 баг | — | `process_split`/`process_dividend`/`process_coupon` затрагивают позиции всех пользователей и не откатываются при частичном сбое |

#### FE-NET — Frontend: сетевой слой (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-NET-05 | `frontend/src/hooks/useBacktestJobWS.ts:20` | ⚙️ кач | — | Тройное дублирование reconnect/auth-логики WebSocket между хуками |
| FE-NET-06 | `frontend/src/api/backtestApi.ts:38` | ⚙️ кач | — | Денежные/процентные поля backend Decimal типизированы как number на фронте (дубль-аспект бага из High) |
| FE-NET-07 | `frontend/src/hooks/useTradingSessionsWS.ts:83` | ⚙️ кач | — | Четыре `as never`-каста отключают проверку типов на границе WS-delta → store |

#### FE-STOR — Frontend: stores (4)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-STOR-02 | `frontend/src/stores/marketDataStore.ts:307` | 🐛 баг | — | Сортировка/дедупликация свечей по naive Date.parse вместо toUtcUnix — рассинхронизация хронологии графика |
| FE-STOR-03 | `frontend/src/stores/userFavoritesStore.ts:77` | 🐛 баг | — | Race condition при параллельных add/remove — откат по устаревшему снапшоту стирает более новое изменение |
| FE-STOR-04 | `frontend/src/stores/backtestStore.ts:125` | ⚙️ кач | — | subscribeProgress: WS и polling независимо триггерят обработку терминального статуса — дублирование логики |
| FE-STOR-14 | `frontend/src/stores/settingsStore.ts:112` | 🔓 уязв | — | Сырые секреты брокера (`api_key`/`api_secret`) проходят через состояние стора |

#### FE-PAGE — Frontend: страницы (6)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-PAGE-04 | `frontend/src/pages/BacktestListPage.tsx:20` | ⚙️ кач | — | Дублирование словарей TIMEFRAME_LABELS и STATUS_MAP в трёх страницах |
| FE-PAGE-05 | `frontend/src/pages/DashboardPage.tsx:71` | ⚙️ кач | — | Функция formatRub продублирована с разными сигнатурами в трёх местах |
| FE-PAGE-06 | `frontend/src/pages/StrategyDetailPage.tsx:1` | ⚙️ кач | — | Мёртвые страницы-заглушки StrategyDetailPage/BacktestDetailPage дублируют рабочие маршруты |
| FE-PAGE-07 | `frontend/src/pages/ProfileSettingsPage.tsx:47` | ⚙️ кач | — | Клиентская валидация нового пароля (мин. 6 символов) расходится с требованием бэкенда (мин. 8 символов) |
| FE-PAGE-08 | `frontend/src/pages/DashboardPage.tsx:369` | 🐛 баг | — | Нулевой P&L стратегии отображается как «нет данных» (falsy-проверка вместо undefined-проверки) |
| FE-PAGE-09 | `frontend/src/pages/AccountPage.tsx:112` | 🐛 баг | — | Гонка при быстрой смене выбранного брокерского счёта — устаревший ответ может перетереть данные текущего счёта |

#### FE-CHART — Frontend: графики (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-CHART-04 | `frontend/src/components/charts/PriceAlertModal.tsx:22` | 🐛 баг | — | Целевая цена в модалке создания price alert не обновляется при повторном открытии — предзаполняется устаревшей ценой |
| FE-CHART-05 | `frontend/src/components/charts/DrawingsLayer.tsx:296` | ⚙️ кач | — | Идентичный hit-test цикл продублирован в трёх местах |
| FE-CHART-06 | `frontend/src/components/charts/primitives/OpenPositionPrimitive.ts:193` | ⚙️ кач | — | Дублирование бизнес-формулы расчёта unrealized PnL на фронтенде вместо единого источника |

#### FE-BTST — Frontend: бэктест (6)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-BTST-01 | `frontend/src/components/backtest/GridSearchHeatmap.tsx:114` | ⚙️ кач | — | Компонент содержит 5 разных ответственностей в одном файле без разделения |
| FE-BTST-02 | `frontend/src/components/backtest/TradeDetailsPanel.tsx:73` | ⚙️ кач | — | Небезопасный каст as unknown as {...} маскирует рассинхрон типа BacktestTrade с API |
| FE-BTST-03 | `frontend/src/components/backtest/InstrumentChart.tsx:289` | ⚙️ кач | — | Непрерывный requestAnimationFrame-цикл перерисовки без диртификации грузит CPU/GPU |
| FE-BTST-17 | `frontend/src/components/backtest/GridSearchForm.tsx:209` | 🐛 баг | — | `GridSearchForm`: даты `type="date"` трактуются как UTC-полночь — сдвиг диапазона на границе суток |
| FE-BTST-18 | `frontend/src/components/backtest/ParityBadge.tsx:37` | 🐛 баг | — | `ParityBadge`: двусмысленная семантика полей `bt`/`it` (число vs булево) при значении `0` |
| FE-BTST-19 | `frontend/src/components/backtest/BacktestTrades.tsx:143` | 🐛 баг | — | `BacktestTrades`: `duration_days === 0` показывается как «0 ч» вместо «—» |

#### FE-STRAT — Frontend: конструктор стратегий (5)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-STRAT-02 | `frontend/src/components/strategy/CodePanel.tsx` | ⚙️ кач | — | Мёртвые дублирующие компоненты CodePanel/CodeDisplay/TemplatePanel не используются в production |
| FE-STRAT-03 | `frontend/src/components/blockly/BlocklyToolbox.ts:1` | ⚙️ кач | — | Список блоков toolbox продублирован в двух независимых источниках правды |
| FE-STRAT-04 | `frontend/src/components/strategy/BlocklyWorkspace.tsx:205` | 🐛 баг | — | Ошибка загрузки блоков стратегии проглатывается без уведомления пользователя |
| FE-STRAT-05 | `frontend/src/components/strategy/StrategyStatusMenu.tsx:58` | 🐛 баг | — | Локальный optimistic-статус не синхронизируется с изменением currentStatus извне |
| FE-STRAT-06 | `frontend/src/utils/flatBlocksToWorkspace.ts:269` | 🐛 баг | — | resolveBlock не защищён от циклических ссылок между блоками — бесконечная рекурсия |

#### FE-TRAD — Frontend: торговля/дашборд/счёт (5)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-TRAD-03 | `frontend/src/components/dashboard/StrategyTable.tsx:26` | ⚙️ кач | — | Мёртвый компонент на хардкоженных mock-данных, нигде не используется в production |
| FE-TRAD-04 | `frontend/src/components/trading/SessionCard.tsx:10` | ⚙️ кач | — | Дублирование форматтеров рубля/цены/даты вместо переиспользования utils/formatters.ts |
| FE-TRAD-05 | `frontend/src/components/trading/LaunchSessionModal.tsx:62` | ⚙️ кач | — | LaunchSessionModal смешивает форму, валидацию, поиск инструментов и бизнес-логику parity в одном 526-строчном файле |
| FE-TRAD-06 | `frontend/src/components/account/OperationsTable.tsx:56` | 🐛 баг | — | Частичный сброс диапазона дат не применяет фильтр — таблица показывает данные по старому диапазону |
| FE-TRAD-07 | `frontend/src/components/trading/PauseConfirmModal.tsx:20` | 🐛 баг | — | useEffect авто-паузы может повторно вызвать pauseSession пока модалка ещё открыта |

#### FE-UI — Frontend: прочий UI (4)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-UI-02 | `frontend/src/components/ai/ChatInput.tsx:171` | ⚙️ кач | — | Утечка blob-URL для превью вложений-изображений |
| FE-UI-03 | `frontend/src/components/notifications/NotificationDrawer.tsx:8` | ⚙️ кач | — | Тройное дублирование SEVERITY_EMOJI/getNotificationLink/formatRelativeTime/NotificationItem |
| FE-UI-04 | `frontend/src/components/wizard/FirstRunWizard.tsx:240` | 🐛 баг | — | Массовое включение Telegram/Email уведомлений в wizard без реакции на частичные ошибки |
| FE-UI-05 | `frontend/src/components/settings/AddBrokerForm.tsx:71` | 🐛 баг | — | discoveredAccounts не инвалидируются при изменении apiKey/apiSecret/brokerType после Discover |

#### FE-CORE — Frontend: утилиты/ядро (6)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-CORE-03 | `frontend/src/App.tsx:58` | 🐛 баг | — | Ссылки из уведомлений на бэктест и инструмент ведут на несуществующие маршруты |
| FE-CORE-04 | `frontend/src/utils/formatters.ts:1` | 🐛 баг | — | formatCurrency жёстко хардкодит знак рубля независимо от фактической валюты суммы |
| FE-CORE-09 | `frontend/src/utils/flatBlocksToWorkspace.ts:66` | ⚙️ кач | — | Дублирование защитной конвертации чисел (`toNum`) без общей утилиты |
| FE-CORE-10 | `frontend/src/utils/tradeMarkerUtils.ts:39` | ⚙️ кач | — | Магические числа допуска по времени (`3600`) захардкожены в нескольких местах |
| FE-CORE-11 | `frontend/src/main.tsx:19` | ⚙️ кач | — | `main.tsx` не защищает верхнеуровневый рендер (нет проверки `root`, нет boundary до провайдеров) |
| FE-CORE-12 | `frontend/src/utils/recentInstruments.ts:12` | ⚙️ кач | — | Дублирование паттерна «safe localStorage read/write» без общей обёртки — `frontend/src/utils/recentInstruments.ts:12`, `frontend/src/utils/drawingsPersistence.ts:27` |


---

## P3 — Low (техдолг) — 125 пунктов

Исправлять по мере касания модулей. Включает `FE-STOR-01`, переклассифицированную из High на шаге 2.

#### CFG-BE — Security: конфигурация backend (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| CFG-BE-04 | `backend/app/main.py:366` | 🔓 sec | — | /api/v1/health отдаёт внутренние детали инфраструктуры без авторизации |
| CFG-BE-05 | `backend/app/middleware/csrf.py:46` | 🔓 sec | — | CSRF-защита пропускает запросы без cookie/header насквозь |
| CFG-BE-06 | `backend/safety_policy.yml:15` | 🔓 sec | — | Подавленная уязвимость protobuf (CVE-2026-0994) — нет автоматической проверки актуальности обоснования |

#### CFG-FE — Security: конфигурация frontend/XSS (1)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| CFG-FE-04 | `frontend/src/api/client.ts:5` | 🔓 sec | — | VITE_API_BASE_URL/VITE_WS_URL — build-time дефолт на localhost без явной проверки при сборке |

#### BE-AUTH — Backend: auth/middleware/ядро (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-AUTH-19 | `backend/app/users/schemas.py:15` | ⚙️ кач | — | Дублирование email-валидации с расходящимися regex в auth и users + отсутствие сервисного слоя в users |
| BE-AUTH-20 | `backend/app/auth/router.py:81` | ⚙️ кач | — | Роутер вызывает приватный метод сервиса _create_token_pair |
| BE-AUTH-21 | `backend/app/auth/models.py:55` | 🐛 баг | — | Таблица revoked_tokens никогда не чистится — просроченные записи копятся, SELECT на каждом запросе |

#### BE-BROK — Backend: брокер/крипто (11)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-BROK-13 | `backend/app/broker/service.py:208` | ⚙️ кач | — | Дублирование ~40 строк между `get_sandbox_balance` и `top_up_sandbox_to` + обход `BrokerFactory` прямым `TInvestAdapter` |
| BE-BROK-14 | `backend/app/broker/tinvest/multiplexer.py:459` | ⚙️ кач | — | Дублирование логики resubscribe: после reconnect каждый figi подписывается дважды |
| BE-BROK-15 | `backend/app/broker/tinvest/rate_limiter.py:80` | ⚙️ кач | — | Мёртвый код персистентности rate limiter — `PersistentTokenBucketRateLimiter` и `save/load_all_limiters` никогда не срабатывают |
| BE-BROK-16 | `backend/app/broker/moex_iss/parser.py:46` | ⚙️ кач | — | Мёртвый метод `parse_candles` и дублирующий dataclass `CandleData` с рассинхронной обработкой таймзоны |
| BE-BROK-17 | `backend/app/broker/crypto_helpers.py:58` | ⚙️ кач | — | `encrypt/decrypt_broker_credentials` лезут в приватный `_aes_key` и дублируют AESGCM-логику `CryptoService` |
| BE-BROK-18 | `backend/app/broker/tinvest/adapter.py:494` | 🐛 баг | — | Сортировка операций смешивает naive `datetime.min` с aware датами — TypeError валит весь endpoint |
| BE-BROK-19 | `backend/app/broker/tinvest/adapter.py:691` | 🐛 баг | — | `get_sandbox_balance` игнорирует параметр `currency` — top-up в не-RUB валюте считает diff от неверной базы |
| BE-BROK-20 | `backend/app/broker/router.py:180` | 🐛 баг | — | `checked_at = datetime.utcnow()` — naive datetime уходит в API без таймзоны |
| BE-BROK-21 | `backend/app/broker/tinvest/multiplexer.py:597` | 🔓 уязв | — | Первые 8 символов брокерского токена пишутся в логи (`token_prefix`) |
| BE-BROK-22 | `backend/app/broker/moex_iss/client.py:136` | 🔓 уязв | — | Ticker без валидации интерполируется в URL MOEX ISS — path/query-инъекция в исходящие запросы |
| BE-BROK-23 | `backend/app/broker/tinvest/rate_limiter.py:122` | 🔓 уязв | — | Неограниченный реестр `_global_limiters` с плейнтекст-токенами в качестве ключей, без эвикции |

#### BE-TRAD — Backend: торговля (6)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-TRAD-22 | `backend/app/trading/engine.py:31` | ⚙️ кач | — | Мёртвая функция `_condition_to_expr` — не вызывается нигде |
| BE-TRAD-23 | `backend/app/trading/ws_sessions.py:64` | ⚙️ кач | — | Подсчёт позиций через `len(list(SELECT *))` и отдельная DB-сессия на каждую торговую сессию в snapshot |
| BE-TRAD-24 | `backend/app/trading/schemas.py:14` | ⚙️ кач | — | Мёртвые/рассинхронизированные константы статусов; статусы — magic strings по всему модулю |
| BE-TRAD-25 | `backend/app/trading/runtime.py:72` | ⚙️ кач | — | Путь маркера shutdown захардкожен относительным `Path('data/.last_shutdown_at')` |
| BE-TRAD-26 | `backend/app/trading/schemas.py:257` | ⚙️ кач | — | `PaginatedResponse.items: list` — нетипизированный ответ, response_model не валидирует элементы |
| BE-TRAD-27 | `backend/app/trading/engine.py:1758` | 🐛 баг | — | `DailyStat` использует `date.today()` в таймзоне сервера вместо Europe/Moscow |

#### BE-STRAT — Backend: стратегии (7)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-STRAT-14 | `backend/app/strategy/router.py:434` | качест | — | Роутер вызывает приватный метод сервиса service._get_version_by_id |
| BE-STRAT-15 | `backend/app/strategy/service.py:74` | качест | — | get_instruments_summary: 250-строчный метод возвращает кортеж из 6 позиционных значений |
| BE-STRAT-16 | `backend/app/strategy/ir.py:340` | качест | — | parse_blocks молча оставляет только последний signal_entry/signal_exit из workspace |
| BE-STRAT-17 | `backend/app/strategy/block_parser.py:256` | качест | — | Дублирование пайплайна парсинга между parse() и _parse_ref_format() (~80 строк) и дубли regex-констант |
| BE-STRAT-18 | `—` | — | — | Разные дефолты периода SMA/EMA: интерпретатор 20, кодоген 14 (дубль-упоминание в измерении bugs) |
| BE-STRAT-19 | `backend/app/strategy/evaluator.py:139` | 🐛 баг | — | Семантика crossover при равенстве серий отличается от bt.indicators.CrossOver |
| BE-STRAT-20 | `backend/app/strategy/service.py:405` | 🐛 баг | — | Гонка на version_number: SELECT max()+1 без блокировки → IntegrityError 500 |

#### BE-BTST — Backend: бэктест (12)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-BTST-12 | `backend/app/backtest/schemas.py:143` | ⚙️ кач | — | BacktestResponse/BacktestBenchmark — мёртвые схемы: endpoint возвращает рукописный dict без response_model |
| BE-BTST-13 | `backend/app/backtest/engine.py:420` | ⚙️ кач | — | MetricsCollector — мёртвый analyzer: регистрируется, но результат никогда не читается |
| BE-BTST-14 | `backend/app/backtest/metrics.py:89` | ⚙️ кач | — | avg_trade_duration_seconds жёстко = 0: колонка БД всегда пуста, ветка в router недостижима |
| BE-BTST-15 | `backend/app/backtest/router.py:659` | ⚙️ кач | — | Маппинг таймфрейм→длительность продублирован в трёх модулях и рассинхронизирован |
| BE-BTST-16 | `backend/app/backtest/ws_backtest.py:36` | ⚙️ кач | — | Дублирование JWT-декодирования для WebSocket в ws.py и ws_backtest.py |
| BE-BTST-17 | `backend/app/backtest/grid.py:466` | ⚙️ кач | — | datetime.utcnow() — deprecated в Python 3.12 и нарушает конвенцию UTC-aware дат |
| BE-BTST-18 | `—` | — | — | Двойное уведомление «Бэктест завершён» для run-async: второе — с плейсхолдерами «—» (дубль записи из измерения quality) |
| BE-BTST-19 | `backend/app/backtest/router.py:730` | 🐛 баг | — | Комиссия в ответе API пересчитывается приближённо и расходится с фактической в БД/CSV |
| BE-BTST-20 | `backend/app/backtest/metrics.py:69` | 🐛 баг | — | SharpeRatio=None превращается в 0.0 — искажение метрики и ранжирования Grid Search |
| BE-BTST-21 | `backend/app/backtest/ws_backtest.py:137` | 🐛 баг | — | Гонка между снапшотом job и подпиской на event_bus — терминальное событие может быть потеряно |
| BE-BTST-22 | `backend/app/backtest/router.py:998` | 🔓 уязв | — | Инъекция в заголовок Content-Disposition через невалидированный ticker при экспорте |
| BE-BTST-23 | `backend/app/backtest/router.py:180` | 🔓 уязв | — | Оракул существования: 403 вместо 404 для чужих версий/бэктестов |

#### BE-MKT — Backend: рыночные данные (6)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-MKT-21 | `backend/app/market_data/router.py:209` | 🔓 уязв | — | Раскрытие внутренних деталей через str(e) в ответе (доп. к находке про subscribe_candle_stream) |
| BE-MKT-22 | `backend/app/market_data/router.py:106` | 🔓 уязв | — | Отсутствие валидации формата ticker: значение подставляется в URL-путь запросов к MOEX ISS |
| BE-MKT-23 | `backend/app/market_data/service.py:216` | ⚙️ кач | — | _purge_iss_cache: DELETE на каждый вызов get_candles и детекция ошибки по подстроке 'database is locked' |
| BE-MKT-24 | `backend/app/market_data/service.py:390` | ⚙️ кач | — | _build_current_candle глушит все исключения без логирования |
| BE-MKT-25 | `backend/app/market_data/router.py:224` | ⚙️ кач | — | Фильтрация инструментов и ALLOWED_TYPES захардкожены в теле роутера, ошибки парсинга молча отбрасывают записи |
| BE-MKT-26 | `backend/app/market_data/service.py:781` | 🐛 баг | — | _fetch_lot_size_from_tinvest/_fetch_isin_from_tinvest берут чужой токен без фильтра по user_id и в обход rate limiter |

#### BE-NOTIF — Backend: уведомления (11)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-NOTIF-13 | `backend/app/notification/telegram_webhook.py:361` | ⚙️ кач | — | N+1 запросы и дублирование цикла построения позиций между /positions и /close-picker |
| BE-NOTIF-14 | `backend/app/notification/service.py:450` | ⚙️ кач | — | Проглатывание ошибок фоновых задач при остановке listener'ов |
| BE-NOTIF-15 | `backend/app/notification/link_store.py:58` | качест | — | link_store.cleanup() никогда не вызывается; _awaiting_token в webhook-хендлере растёт неограниченно |
| BE-NOTIF-16 | `backend/app/notification/telegram_webhook.py:906` | 🐛 баг | — | _execute_closeall не проверяет query.message на None — AttributeError и молчаливый отказ закрытия |
| BE-NOTIF-17 | `backend/app/notification/telegram_webhook.py:441` | 🐛 баг | — | /status показывает время паузы в UTC вместо Europe/Moscow |
| BE-NOTIF-18 | `backend/app/notification/telegram_webhook.py:241` | 🐛 баг | — | _awaiting_token растёт неограниченно — истёкшие записи чистятся только при следующем сообщении того же чата |
| BE-NOTIF-19 | `backend/app/notification/telegram_webhook.py:321` | 🐛 баг | — | _link_account вставляет username в HTML-ответ без экранирования — подтверждение привязки может не дойти |
| BE-NOTIF-20 | `backend/app/notification/link_store.py:37` | баг /  | — | LinkTokenStore.generate не проверяет коллизию токена — возможна привязка Telegram к чужому аккаунту |
| BE-NOTIF-21 | `backend/app/notification/telegram_webhook.py:46` | ⚙️ кач | — | _format_decimal конвертирует Decimal в float при форматировании денежных сумм |
| BE-NOTIF-22 | `backend/app/notification/router.py:208` | ⚙️ кач | — | /test-email дублирует сборку EmailNotifier из настроек, уже реализованную в NotificationService |
| BE-NOTIF-23 | `backend/app/notification/router.py:378` | 🔓 уязв | — | /telegram/test — аутентифицированный релей к Telegram Bot API с произвольным bot_token/chat_id |

#### BE-AI — Backend: AI (8)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-AI-13 | `backend/app/ai/chat_router.py:327` | качест | — | TOCTOU в лимите одновременных SSE-стримов: проверка и инкремент разнесены |
| BE-AI-14 | `backend/app/ai/service.py:150` | 🐛 баг | — | Lost update в `increment_usage` (дубль в измерении bugs) |
| BE-AI-15 | `backend/app/ai/slash_context.py:216` | ⚙️ кач | — | `_resolve_session` считает открытые позиции загрузкой всех строк `LiveTrade` в память |
| BE-AI-16 | `backend/app/ai/chat_history.py:47` | ⚙️ кач | — | `save_message`: повторные запросы к БД и полная перезапись неограниченно растущей JSON-истории |
| BE-AI-17 | `backend/app/ai/router.py:170` | ⚙️ кач | — | Непоследовательное владение транзакцией: двойной commit и фиксация частичного состояния посреди запроса |
| BE-AI-18 | `backend/app/ai/schemas.py:15` | ⚙️ кач | — | Цены за 1M токенов — `float` в схемах и `float()` в ответе при колонке `Numeric(10,4)`: нарушение конвенции Decimal |
| BE-AI-19 | `backend/app/ai/providers/claude_provider.py:39` | ⚙️ кач | — | `max_tokens=4096` захардкожен во всех провайдерах — длинный ответ обрезается, `json_blocks` молча теряется |
| BE-AI-20 | `backend/app/ai/router.py:112` | 🔓 sec | — | `PUT /settings/ai/instructions` не покрыт rate-limit усиленной категории; `verify-credentials` не покрыт строгим AI rate-limit |

#### BE-RT — Backend: circuit breaker/sandbox/scheduler (6)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-RT-14 | `backend/app/circuit_breaker/service.py:120` | ⚙️ кач | — | get_status опирается на приватные методы engine и делает портфельный цикл по сессиям вместо одного запроса |
| BE-RT-15 | `backend/app/sandbox/executor.py:112` | ⚙️ кач | — | Мёртвая ветка signal.alarm в _run_sandboxed — недостижима в production |
| BE-RT-16 | `backend/app/circuit_breaker/engine.py:31` | ⚙️ кач | — | Дублирование торгового расписания MOEX и таймзоны между engine и MOEXCalendarService |
| BE-RT-17 | `backend/app/circuit_breaker/engine.py:243` | ⚙️ кач | — | Несогласованная граница «дня»: realized PnL с 10:00 MSK, unrealized — по date.today() сервера |
| BE-RT-18 | `backend/app/scheduler/service.py:410` | 🐛 баг | — | «Портфель» в дневной статистике суммирует балансы всех сессий, включая остановленные |
| BE-RT-19 | `backend/app/circuit_breaker/router.py:51` | 🔓 уязв | — | Нет проверки владельца session_id при сохранении session-override конфига CB |

#### BE-MISC — Backend: common/CLI/backup/admin/tax/corp (7)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| BE-MISC-11 | `backend/app/tax/service.py:183` | ⚙️ кач | — | Несогласованный учёт комиссии: realized_pnl использует commission_total, а в лоты пишется 2×округлённая половина |
| BE-MISC-12 | `backend/app/backup/service.py:226` | ⚙️ кач | — | rotate() не удаляет sidecar-файлы -wal/-shm; before_restore-копии накапливаются бессрочно |
| BE-MISC-13 | `backend/app/admin/dash_mount.py:50` | ⚙️ кач | — | Дублирование JWT-валидации из middleware/auth.py + молчаливые except Exception: pass |
| BE-MISC-14 | `backend/app/tax/router.py:14` | ⚙️ кач | — | Несогласованное объявление префиксов роутеров: конвенция prefix в APIRouter нарушена в 4 модулях |
| BE-MISC-15 | `backend/app/common/pagination.py:1` | ⚙️ кач | — | Мёртвый файл-заглушка pagination.py; list-эндпоинты без пагинации грузят всё в память |
| BE-MISC-23 | `backend/app/corporate_actions/service.py:236` | 🐛 баг | — | `record_date` корп. действия ошибочно приравнивается к `ex_date` |
| BE-MISC-24 | `backend/app/common/crypto.py:26` | 🔓 уязв | — | HKDF без соли для деривации ключа шифрования брокерских ключей |

#### FE-NET — Frontend: сетевой слой (5)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-NET-08 | `frontend/src/services/aiStreamClient.ts:10` | ⚙️ кач | — | Дублирование логики refresh JWT-токена между client.ts и aiStreamClient.ts без общего мьютекса |
| FE-NET-09 | `frontend/src/hooks/useBacktestJobWS.ts:179` | ⚙️ кач | — | Обработчики WS в useBackgroundBacktestsBootstrap не имеют backoff (дубль-аспект найденного бага) |
| FE-NET-10 | `frontend/src/api/client.ts:60` | 🔓 уязв | — | Префикс JWT-токена логируется в консоль браузера |
| FE-NET-11 | `frontend/src/api/client.ts:30` | 🔓 уязв | — | CSRF-токен читается из non-HttpOnly cookie и тихо не отправляется при его отсутствии |
| FE-NET-12 | `frontend/src/api/types.ts:199` | 🐛 баг | — | BrokerBalance.total/available/blocked типизированы как string, хотя backend отдаёт float |

#### FE-STOR — Frontend: stores (8)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-STOR-01 | `frontend/src/stores/authStore.ts:69` | баг /  | ⚠️ | logout() не очищает accountSelectionStore — рецидив паттерна BUG-20 |
| FE-STOR-05 | `frontend/src/stores/accountStore.ts:133` | ⚙️ кач | — | downloadTaxReport: revokeObjectURL не в finally — утечка Blob URL при исключении |
| FE-STOR-06 | `frontend/src/stores/backtestStore.ts:94` | 🐛 баг | — | unsubscribeProgress() без параметра закрывает ВСЕ активные WS/poll, включая чужие backtest id |
| FE-STOR-07 | `frontend/src/stores/marketDataStore.ts:415` | ⚙️ кач | — | Магические константы диапазона volumeHeightPercent (10/40) без единого источника с UI |
| FE-STOR-08 | `frontend/src/stores/marketDataStore.ts:111` | ⚙️ кач | — | Дублирование логики persist в localStorage: generic loader и специализированный кеш свечей |
| FE-STOR-09 | `frontend/src/stores/chartDrawingsStore.ts:315` | ⚙️ кач | — | duplicate(): копирование полей drawing data без discriminated union по DrawingType |
| FE-STOR-10 | `frontend/src/stores/tradingStore.ts:44` | ⚙️ кач | — | Идентичный try/catch-паттерн обработки ошибок продублирован в 12 экшенах без общей обёртки |
| FE-STOR-11 | `frontend/src/stores/backgroundBacktestsStore.ts:78` | ⚙️ кач | — | Громоздкая сигнатура типа add() через Omit+Partial+Pick усложняет сопровождение |

#### FE-PAGE — Frontend: страницы (5)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-PAGE-10 | `frontend/src/pages/AccountPage.tsx:161` | ⚙️ кач | — | handleDownloadExisting хардкодит расширение файла .xlsx независимо от реального формата отчёта |
| FE-PAGE-11 | `frontend/src/pages/SettingsPage.tsx:22` | ⚙️ кач | — | Все 4 вкладки настроек монтируются одновременно, вызывая fetch-запросы всех разделов сразу |
| FE-PAGE-12 | `frontend/src/pages/LoginPage.tsx:20` | ⚙️ кач | — | LoginPage и SetupPage дублируют идентичную разметку формы аутентификации |
| FE-PAGE-13 | `frontend/src/pages/ChartPage.tsx:391` | 🐛 баг | — | Ценовое оповещение в шапке графика показывается без форматирования числа |
| FE-PAGE-14 | `frontend/src/pages/AISettingsPage.tsx:498` | 🔓 уязв | — | API-ключ AI-провайдера вводится в обычном TextInput, а не PasswordInput |

#### FE-CHART — Frontend: графики (4)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-CHART-07 | `frontend/src/components/charts/CandlestickChart.tsx:609` | 🐛 баг | — | Price-alert линии не пересоздаются на новой series после пересоздания chart — ref на price lines не сбрасывается |
| FE-CHART-08 | `frontend/src/components/charts/primitives/PositionDrawingPrimitive.ts:256` | ⚙️ кач | — | Избыточная hit-test проверка: isPointInBox и isPointInRect с одинаковыми аргументами через OR |
| FE-CHART-09 | `frontend/src/components/charts/FavoritesPanel.tsx:40` | ⚙️ кач | — | Отсутствие обработки ошибки при загрузке избранного |
| FE-CHART-10 | `frontend/src/components/charts/PriceAlertModal.tsx:32` | ⚙️ кач | — | Ошибка создания price alert не отображается пользователю |

#### FE-BTST — Frontend: бэктест (9)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-BTST-04 | `frontend/src/components/backtest/StrategyTesterPanel.tsx:21` | ⚙️ кач | — | Дублирование утилиты deduplicateByTime между компонентами с разными сигнатурами |
| FE-BTST-05 | `frontend/src/components/backtest/BacktestLaunchModal.tsx:111` | ⚙️ кач | — | Два независимых механизма сброса состояния модалки на одно и то же событие opened |
| FE-BTST-06 | `frontend/src/components/backtest/BacktestLaunchModal.tsx:233` | ⚙️ кач | — | Дублирование извлечения HTTP-статуса ошибки в двух местах обработчика |
| FE-BTST-07 | `frontend/src/components/backtest/GridSearchHeatmap.tsx:131` | ⚙️ кач | — | Вычисление min/max без useMemo пересчитывается на каждый рендер компонента |
| FE-BTST-08 | `frontend/src/components/backtest/BacktestProgress.tsx:33` | ⚙️ кач | — | Пустой useEffect с cleanup-заглушкой не выполняет никакой функции |
| FE-BTST-09 | `frontend/src/components/backtest/PnLDistributionHistogram.tsx:22` | ⚙️ кач | — | Несогласованные эпсилон-пороги breakeven в разных компонентах одной страницы |
| FE-BTST-10 | `frontend/src/components/backtest/BacktestTrades.tsx:50` | ⚙️ кач | — | Дублирование форматирования сумм в рублях в 3+ компонентах с расхождениями |
| FE-BTST-11 | `frontend/src/components/backtest/GridSearchForm.tsx:103` | ⚙️ кач | — | Отсутствует индикация состояния загрузки availableParams |
| FE-BTST-12 | `frontend/src/components/backtest/StrategyTesterPanel.tsx:135` | ⚙️ кач | — | Небезопасный каст объекта chart для хранения кастомных полей вместо явного состояния |

#### FE-STRAT — Frontend: конструктор стратегий (3)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-STRAT-07 | `frontend/src/components/strategy/TemplatePanel.tsx:24` | ⚙️ кач | — | Константа EMPTY_TEMPLATE (7-секционный шаблон) дублируется дословно, третий вариант шаблона расходится по структуре |
| FE-STRAT-08 | `frontend/src/utils/flatBlocksToWorkspace.ts:262` | ⚙️ кач | — | Дедупликация id блоков реализована через module-level мутируемую переменную _dupCounter |
| FE-STRAT-09 | `frontend/src/components/strategy/VersionsHistoryDrawer.tsx:79` | 🐛 баг | — | lineDiff — наивный построчный diff без выравнивания искажает сравнение версий |

#### FE-TRAD — Frontend: торговля/дашборд/счёт (7)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-TRAD-08 | `frontend/src/components/dashboard/SparklineWidget.tsx:122` | ⚙️ кач | — | Дублирование debounce-логики поиска тикеров между SparklineWidget и LaunchSessionModal |
| FE-TRAD-09 | `frontend/src/components/trading/LaunchSessionModal.tsx:192` | 🐛 баг | — | Debounced поиск тикеров без отмены/проверки актуальности — устаревший ответ может перетереть свежие подсказки |
| FE-TRAD-10 | `frontend/src/components/trading/SessionDashboard.tsx:244` | ⚙️ кач | — | Признак «есть ещё страница» для пагинации сделок — эвристика по остатку от деления, ломается на границе кратности 50 |
| FE-TRAD-11 | `frontend/src/components/trading/LaunchSessionModal.tsx:159` | ⚙️ кач | — | Паттерн «set state during render» используется трижды подряд для разных полей — усложняет чтение и рискован при добавлении новых сравнений |
| FE-TRAD-12 | `frontend/src/components/dashboard/ActivePositionsWidget.tsx:47` | ⚙️ кач | — | Расчёт pnlPct использует initial_capital сессии как знаменатель без защиты от NaN и с произвольным fallback на 1 |
| FE-TRAD-13 | `frontend/src/components/trading/LaunchSessionModal.tsx:173` | ⚙️ кач | — | collectSuggestedTickers пересчитывается в нескольких местах без единого источника правды |
| FE-TRAD-14 | `frontend/src/components/trading/sessionMode.ts:20` | 🐛 баг | — | Статус сессии suspended визуально неотличим от stopped — вводит в заблуждение относительно причины остановки |

#### FE-UI — Frontend: прочий UI (2)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-UI-06 | `frontend/src/components/layout/Header.tsx:78` | ⚙️ кач | — | TYPE_BADGE_CONFIG пересоздаётся на каждый рендер AppHeader |
| FE-UI-07 | `frontend/src/components/settings/BrokerAccountList.tsx:80` | ⚙️ кач | — | Последовательная (не параллельная) загрузка sandbox-балансов в цикле for-await |

#### FE-CORE — Frontend: утилиты/ядро (1)

| ID | Файл:строка | Кат. | В | Заголовок |
|---|---|---|:--:|---|
| FE-CORE-05 | `frontend/src/utils/drawingsPersistence.ts:56` | 🐛 баг | — | Миграция рисунков из ключа anon в localStorage не идемпотентна при параллельных вкладках |

---

## Follow-up (обнаружено при исправлении P0 / `/code-review`, 2026-07-06)

Заведено по ходу исправления критических (см. [P0_FIXES_LOG.md](P0_FIXES_LOG.md)). Не блокеры P0, но требуют отдельных задач.

| ID | Файл:строка | Кат. | Заголовок |
|---|---|:--:|---|
| FUP-01 | `backend/app/corporate_actions/service.py` | 🐛 баг | После полного реверс-сплита позиция остаётся `status='open'` с `volume_lots=0` (стоимость возвращена cash-in-lieu, но «пустая» запись висит) — авто-закрывать/помечать closed |
| FUP-02 | `backend/app/trading/engine.py:1532` | 🐛 баг | `close_position`: брокерский ордер по `filled_lots or volume_lots`, а PnL (`_apply_close`) по `volume_lots` — при частичном филле рассинхрон количества/PnL |
| FUP-03 | `backend/app/trading/service.py:491` | 🔓 уязв | `delete_session` для `stopped`-сессии с открытыми real-позициями каскадно удаляет `LiveTrade` из БД → фантом у брокера. Добавить guard: запрет удаления при открытых sandbox/real-позициях (предсуществующее, усилено вниманием при доработке C6) |
