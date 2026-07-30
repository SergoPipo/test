# Полное код-ревью MOEX Trading Terminal

**Дата:** 2026-07-05 — 2026-07-06
**Объём:** весь production-код — backend (`Develop/backend/app`, ~35 000 строк, 19 модулей) и frontend (`Develop/frontend/src`, ~33 000 строк, 9 блоков).
**Критерии ревью:** (1) качество кода, (2) баги, (3) уязвимости, (4) security-check конфигурации и деплоя.
**Статус:** правки в код НЕ вносились — только анализ и рекомендации.

---

## 1. Как проводилось ревью (методология)

Ревью выполнено многоагентным конвейером (61 независимый ревью-агент):

- **Поблочно × по измерениям.** Кодовая база разбита на 19 функциональных блоков (10 backend + 9 frontend). Каждый блок независимо просмотрели 3 агента — по одному на «качество кода», «баги» и «уязвимости». Это исключает эффект «одного взгляда», когда ревьюер фокусируется на первой найденной проблеме.
- **4 сквозные security-проверки** поверх блоков: (а) конфигурация и деплой backend (CORS, cookie-флаги, docker, дефолтные секреты); (б) конфигурация frontend и XSS-поверхность; (в) поиск секретов в обоих git-репозиториях; (г) аудит авторизации всех HTTP/WebSocket-эндпоинтов на IDOR.
- **Адверсариальная верификация.** Каждую критичную и высокую находку из категорий «баг»/«уязвимость» проверял отдельный агент-скептик, пытавшийся *опровергнуть* её по коду (для critical — двое независимых). Отметка **✅ подтверждено** означает, что находка прошла эту проверку.
- **Ручная доверификация.** Все критичные находки, попавшие в раздел 3, дополнительно перепроверены вручную по исходному коду при сборке отчёта.

> **Оговорка о полноте.** Прогон несколько раз упирался в лимиты сессии и доводился порциями. 5 измерений (be-misc: баги+уязвимости, fe-stores: уязвимости, fe-backtest: баги, fe-core: качество) на первом проходе не завершились и были добраны отдельным повторным ревью — их результаты помечены в тексте плашкой «Дополнение». Тестовые файлы (`test_*`, `*.test.*`), alembic-миграции и содержимое внешних библиотек намеренно не ревьюировались. Отчёт фиксирует **потенциальные** дефекты по чтению кода — перед исправлением каждый пункт стоит подтвердить прогоном/тестом.

---

## 2. Сводная статистика

Всего зафиксировано **~344 наблюдения** (318 в основном прогоне + 26 при доборе упавших измерений). Разбивка по severity (как найдено агентами; часть критичных дублируется между сквозными и поблочными секциями — дедуплицированный список см. в разделе 3):

| Severity | Кол-во | Что это значит |
|----------|:---:|----------------|
| 🔴 **Critical** | 8 (7 различных) | Потеря денег/данных, компрометация, неаутентифицированный доступ к критичным операциям |
| 🟠 **High** | ~67 | Серьёзный дефект или реальная уязвимость, требует исправления до сдачи |
| 🟡 **Medium** | ~145 | Заметная проблема, часто с обходным путём |
| 🔵 **Low** | ~123 | Незначительное; качество/техдолг |
| ⚪ Отклонено | 1 | Опровергнуто при верификации |

### Разбивка по модулям

| # | Блок | 🔴 | 🟠 | 🟡 | 🔵 |
|---|------|:--:|:--:|:--:|:--:|
| 1 | Security-check: конфигурация backend | 1 | 1 | 1 | 3 |
| 2 | Security-check: конфигурация frontend / XSS | 0 | 2 | 1 | 1 |
| 3 | Security-check: секреты в репозиториях | 1 | 0 | 0 | 0 |
| 4 | Security-check: авторизация эндпоинтов (IDOR) | 1 | 5 | 0 | 0 |
| 10 | Backend: auth, middleware, users, ядро | 1 | 2 | 14 | 3 |
| 11 | Backend: брокер (T-Invest), крипто | 0 | 2 | 9 | 11 |
| 12 | Backend: торговля (live) | 2 | 8 | 10 | 6 |
| 13 | Backend: стратегии | 1 | 2 | 9 | 6 |
| 14 | Backend: бэктест | 0 | 4 | 6 | 9 |
| 15 | Backend: рыночные данные | 0 | 5 | 15 | 6 |
| 16 | Backend: уведомления | 1 | 2 | 9 | 12 |
| 17 | Backend: AI-модуль | 0 | 2 | 8 | 8 |
| 18 | Backend: circuit breaker, sandbox, scheduler | 0 | 3 | 9 | 6 |
| 19 | Backend: common, CLI, backup, admin, tax, corp. actions | 1 | 3 | 13 | 7 |
| 20 | Frontend: сетевой слой (api/hooks) | 0 | 4 | 3 | 5 |
| 21 | Frontend: состояние (stores) | 0 | 3 | 4 | 8 |
| 22 | Frontend: страницы | 0 | 3 | 6 | 5 |
| 23 | Frontend: графики | 0 | 3 | 3 | 4 |
| 24 | Frontend: бэктест-компоненты | 0 | 4 | 6 | 9 |
| 25 | Frontend: конструктор стратегий (Blockly) | 0 | 1 | 4 | 3 |
| 26 | Frontend: торговля, дашборд, счёт | 0 | 2 | 5 | 8 |
| 27 | Frontend: прочий UI | 0 | 1 | 4 | 2 |
| 28 | Frontend: утилиты и ядро | 0 | 5 | 6 | 1 |

---

## 3. Критические проблемы — исправить до сдачи

Ниже — дедуплицированный список из **7 различных** критических проблем (некоторые фигурируют в отчёте дважды: в сквозной security-секции и в поблочной). Все перепроверены вручную по коду.

### 🔴 C1. Telegram-webhook fail-open → неаутентифицированное закрытие чужих позиций
`backend/app/notification/router.py:428` · **✅ подтверждено**

Если `TELEGRAM_BOT_TOKEN` задан, а `TELEGRAM_WEBHOOK_SECRET` пуст (дефолт — пустая строка, валидатор его не требует), проверка вебхука `'' != ''` проходит для запроса без заголовка секрета. Авторизация бота строится на `chat_id` из тела запроса, которым атакующий полностью управляет — подставив `chat_id` жертвы и сфабриковав команду `/closeall` + `confirm_closeall`, злоумышленник **без аутентификации принудительно закрывает все реальные позиции жертвы** (прямая потеря денег), читает баланс и позиции. CSRF не защищает запрос без cookie, сравнение не constant-time.
**Fix:** fail-closed (пустой секрет → 503), `hmac.compare_digest`, в валидаторе конфига требовать непустой webhook-секрет при заданном токене бота.

### 🔴 C2. IDOR: остановка/пауза чужой торговой сессии с принудительной ликвидацией
`backend/app/trading/router.py:101,122` → `service.py:516,526` · **✅ подтверждено**

`stop_session(session_id)`, `pause_session`, `resume_session` в сервисе не принимают `user_id` и не фильтруют по владельцу (в отличие от `get_session(session_id, user_id=...)`). Любой аутентифицированный пользователь, подставив чужой `session_id`, останавливает чужую сессию; `stop_session` при этом вызывает `close_all_positions` — то есть **ликвидирует чужие позиции**.
**Fix:** пробрасывать `current_user.id` во все мутирующие методы сессии и фильтровать выборку по владельцу (404 при чужом id).

### 🔴 C3. Дефолтные `SECRET_KEY`/`ENCRYPTION_KEY` не блокируют старт в production
`backend/app/config.py:13,78` · **✅ подтверждено**

Валидатор конфигурации на дефолтные `dev-secret-key-change-in-production` / `dev-encryption-key-change-me-32b` вызывает лишь `warnings.warn`, а не `raise`. При случайном деплое без `.env` приложение стартует с публично известными ключами: **подделка любого JWT** (полный обход аутентификации) и **расшифровка хранимых брокерских API-ключей** известным ключом.
**Fix:** в production (`ENVIRONMENT=production`) поднимать эти дефолты в `ValueError` при старте.

### 🔴 C4. Cookie `access_token`/`csrf_token` выставляются с `secure=False` без гейта на окружение
`backend/app/auth/router.py:53` · **✅ подтверждено (дважды)**

Флаг `secure` захардкожен в `False`. По HTTP (или при даунгрейде) cookie с access-токеном уходит в открытом виде и перехватывается MITM.
**Fix:** `secure=True` в production, вычислять из `ENVIRONMENT`/схемы; выставить `SameSite`.

### 🔴 C5. Реальный `TELEGRAM_WEBHOOK_SECRET` закоммичен в git
`backend/assets/telegram_bot_setup.md:56` · **✅ подтверждено (файл отслеживается git, значение — реальная hex-строка, не плейсхолдер)**

В markdown-инструкции хранится настоящее значение webhook-секрета. Любой с доступом к репозиторию его видит; в связке с C1 (fail-open) обесценивает единственный барьер вебхука.
**Fix:** удалить значение из файла (заменить плейсхолдером), **ротировать секрет** у BotFather/в инфраструктуре, вычистить из истории git (`git filter-repo`), проверить, что `assets/*.md` не содержат иных секретов.

### 🔴 C6. `close_all_positions` закрывает позиции без exit_price/PnL, без ордера брокеру и без возврата средств
`backend/app/trading/engine.py:1673` · **✅ подтверждено**

Массовое закрытие помечает позиции закрытыми, но не рассчитывает `exit_price`/PnL, не отправляет ордер брокеру и не возвращает средства на баланс. Реальные позиции у брокера остаются открытыми, а в системе — «закрыты» с нулевым результатом: **рассинхрон учёта и потеря денег**. Усугубляется тем, что этот же путь вызывается из C1 и C2.
**Fix:** закрывать через реальный рыночный ордер брокеру, фиксировать `exit_price`/PnL из исполнения, возвращать средства; для paper-режима — считать по текущей рыночной цене.

### 🔴 C7. Реверс-сплит обнуляет позицию из-за усечения `int()`
`backend/app/corporate_actions/service.py:52` · **✅ подтверждено**

Объём после сплита считается как `int(old_volume * ratio_to / ratio_from)` с усечением к нулю. При консолидации (например 10:1 для 5 лотов) → `int(0.5) = 0`: **позиция молча обнуляется, стоимость теряется**; `entry_price` при этом растёт в 10 раз. Дробные остатки при любом сплите отбрасываются без компенсации.
**Fix:** корректное округление + денежная компенсация дробной части (cash-in-lieu), либо блокировка сплита с уведомлением при неделимом объёме.

### ⚠️ Переклассифицировано: исполнение пользовательского Python в бэктесте (было critical → **High**)
`backend/app/backtest/engine.py:507`, `backend/app/sandbox/executor.py`

Исходная находка утверждала «тривиальный `exec()` произвольного кода в `strategy/schemas.py:87». **Атрибуция неверна:** `schemas.py:87` — обычное Pydantic-поле `generated_code: str`, никакого `exec` там нет. Реальное исполнение — в `backtest/engine.py` и `sandbox/executor.py`, и оно защищено эшелонированно: `ASTAnalyzer` блокирует `eval/exec/open/__import__`, запрещённые модули, dunder-имена и dunder-атрибуты (в т.ч. `.__class__`, `.__subclasses__`); из builtins удалены `getattr/setattr/delattr/globals/locals/eval/exec/compile/open`; импорты — по белому списку. Остаточный риск реален (in-process исполнение кода аутентифицированного пользователя; AST-блэклист в принципе трудно сделать герметичным), но это **High**, а не «открытый exec». Подробнее — в секции 13 и 18.
**Fix:** рассмотреть вынос исполнения стратегий в отдельный процесс/контейнер с resource-limits (истинная граница изоляции вместо AST-блэклиста).

---

## 4. Сквозные темы (повторяются во многих модулях)

- **Таймзоны.** Систематическое смешение naive UTC и Europe/Moscow: границы налогового года (C7-сосед, `tax/service.py`), торговые часы (`common/trading_hours.py` дублирует `circuit_breaker`), даты на графиках и в форматтерах фронтенда (`formatters.ts` в обход `parseBackendDate`), даты грид-серча.
- **Деньги во `float`.** Местами суммы/цены проходят через `float` вместо `Decimal` (`broker/schemas.py` `BrokerBalance`, отдельные метрики) — риск потери точности в домене, где это критично.
- **Блокирующий I/O в event loop.** Синхронные `openpyxl`/`csv`/файловые операции в async-эндпоинтах (`tax/service.py`) при однопроцессном монолите замораживают торговый движок и WS-клиентов. Есть образец правильного подхода — `BackupService` с `run_in_executor`.
- **Хранение токенов на фронте.** JWT в `localStorage` и в query-string WebSocket-URL (несколько мест) — уязвимо к XSS и утечке через access-логи.
- **Дублирование логики авторизации/guard'ов.** `AdminAuthASGIMiddleware` дублирует урезанную проверку токена; `ProtectedRoute`/`ProtectedAdminRoute` — две копии guard'а.
- **N+1 и отсутствие пагинации.** Запросы к БД/ISS в циклах (`corporate_actions`, `broker`), list-эндпоинты без limit/offset (заглушка `common/pagination.py` не реализована).

---

## 5. Рекомендуемый порядок работы

1. **Немедленно (блокеры сдачи):** C1–C7. Особое внимание — C1+C6 (неаутентифицированная потеря денег) и C5 (ротация утёкшего секрета).
2. **До сдачи:** все High — прежде всего security-config (CORS/cookie/заголовки), IDOR-чтение (история сделок/статистика чужих сессий, мультиплексный `/ws`), брокер (лимитные ордера без цены, маршрутизация свечей по figi без interval), сверка позиций real-сессий при рестарте.
3. **Ближайший бэклог:** Medium — таймзоны, блокирующий I/O, налоговая логика, N+1.
4. **Техдолг:** Low — по мере касания модулей.

---

## 6. Детальные находки по блокам

Ниже — полные результаты по каждому блоку в порядке: сквозные security-проверки (1–4), затем backend (10–19), затем frontend (20–28). Внутри блока находки сгруппированы по severity. Плашкой «Дополнение» помечены измерения, добранные повторным ревью.

---

## 1. Security-check: конфигурация и деплой бэкенда

Проверены docker-compose.yml, Dockerfile.backend/frontend, nginx.conf, .dockerignore, .gitignore, pyproject.toml, alembic.ini/versions, safety_policy.yml, main.py, config.py и 4 middleware. Главная проблема — cookie `access_token`/`csrf_token` жёстко ставятся с `secure=False` без гейта на окружение, при этом деплой-схема (Cloudflare Tunnel терминирует TLS вне контейнера, nginx внутри слушает только HTTP) не даёт приложению узнать о HTTPS снаружи. Второй существенный риск — дефолтные `SECRET_KEY`/`ENCRYPTION_KEY` при отсутствии переопределения блокируются лишь предупреждением, а не остановкой старта, что при пропуске `.env.production` открывает подделку JWT и расшифровку брокерских токенов. Остальные находки (CORS-валидация, публичный `/health`, CSRF fallback, устаревание supressed-уязвимости) — менее критичны. CORS по умолчанию безопасен, admin-роуты и Dash-mount защищены корректно, non-root в backend-контейнере настроен верно, секреты не попадают в git/миграции, зависимости запинены с обоснованием. Не проверялись: `.env.example` (заблокирован политикой прав), сети Cloudflare Tunnel и launchd хоста.

### 🔴 Critical

#### 🔴 Cookie access_token и csrf_token отправляются с secure=False, захардкожено без гейта на окружение — `backend/app/auth/router.py:53`

- **Категория:** уязвимость (security-config)  |  **Верификация:** ✅ подтверждено (дважды, независимо)

- **Проблема:** Функция `_set_access_token_cookie` (строки 53–61) и `login()` (строки 132–140) жёстко ставят `secure=False` для cookie `access_token` (HttpOnly JWT) и `csrf_token`. Production-стек — Cloudflare Tunnel, терминирующий TLS снаружи контейнера; nginx внутри слушает только plain HTTP :80 (nginx.conf, строки 11–14). Комментарий в коде (строки 47–48) прямо признаёт, что `secure=True` должен появиться «в Sprint 9», но правило проекта требует чинить такие вещи в текущем спринте приёмки, а не откладывать в S9. Более того, даже когда до этого дойдут руки, вычислить нужный флаг сейчас неоткуда: приложение не читает `X-Forwarded-Proto` от Cloudflare (хотя nginx его шлёт — nginx.conf:57,75) и не имеет флага `PRODUCTION`/`ENVIRONMENT`; uvicorn запущен без `--proxy-headers`. `config.py:42` уже содержит `DEBUG`, используемый как prod/dev индикатор в других местах (78–91), поэтому `secure=not DEBUG` реализуемо без новой инфраструктуры.

- **Рекомендация:** Добавить в config.py флаг `ENVIRONMENT`/`PRODUCTION: bool` (или переиспользовать `DEBUG`) и вычислять `secure=not settings.DEBUG` при вызове `set_cookie` для access_token и csrf_token. Задокументировать в deployment_guide.md, что Cloudflare Tunnel должен слать `X-Forwarded-Proto: https`, и/или добавить `ProxyHeadersMiddleware`/`TrustedHostMiddleware`. Сделать это сейчас, а не переносить в Sprint 9.

### 🟠 High

#### 🟠 Дефолтные значения SECRET_KEY и ENCRYPTION_KEY — предсказуемые строки, отсутствие жёсткого блока запуска в production — `backend/app/config.py:13`

- **Категория:** уязвимость (security-config)  |  **Верификация:** ✅ подтверждено

- **Проблема:** `SECRET_KEY = 'dev-secret-key-change-in-production'` и `ENCRYPTION_KEY = 'dev-encryption-key-change-me-32b'` используются как дефолты, если `.env` отсутствует или их не переопределяет. `check_production_secrets` (строки 78–91) при `DEBUG=false` лишь вызывает `warnings.warn(...)`, не бросает исключение и не блокирует старт. `SECRET_KEY` подписывает JWT (auth/service.py:151-152, middleware/auth.py:21, admin/dash_mount.py:114) — предсказуемый ключ даёт подделку токена, включая claim `is_admin`. `ENCRYPTION_KEY` используется в CryptoService (crypto_helpers.py:13, common/crypto.py:14-30, HKDF→AES-256-GCM) для шифрования API-ключей брокера — с известным ключом злоумышленник, получивший доступ к БД (например через backup), расшифрует T-Invest токены пользователей. Дополнительно deployment_guide.md (строки 69–70) велит задать переменную `MASTER_KEY`, тогда как поле в Settings называется `ENCRYPTION_KEY`; из-за `extra="ignore"` (config.py:76) при точном следовании гайду `MASTER_KEY` молча игнорируется, а `ENCRYPTION_KEY` остаётся дефолтным без единой ошибки — это не гипотетический, а воспроизводимый сценарий провала конфигурации.

- **Рекомендация:** Заменить `warnings.warn` на `raise RuntimeError` при `not DEBUG` и SECRET_KEY/ENCRYPTION_KEY, начинающихся с `dev-`. Дополнительно проверять минимальную энтропию/длину. Синхронизировать имя переменной в deployment_guide.md с реальным полем Settings (`ENCRYPTION_KEY`, не `MASTER_KEY`). В docker-compose добавить проверку на старте контейнера, что `backend/.env.production` существует и не содержит дефолтных значений.

### 🟡 Medium

#### 🟡 CORS allow_credentials=True скомбинирован с CORS_ORIGINS из .env без валидации на wildcard — `backend/app/main.py:301`

- **Категория:** security-check  |  **Верификация:** — не проверялось

- **Проблема:** `allow_origins=[o.strip() for o in settings.CORS_ORIGINS.split(',')]` вместе с `allow_credentials=True` и `allow_methods=['*']`/`allow_headers=['*']` (main.py 301-307). Дефолт безопасен (`http://localhost:5173`), но конфигурация полностью доверяет строке из `.env` без валидации: если оператор при деплое по ошибке поставит `CORS_ORIGINS=*`, поведение зависит от точной версии starlette==1.0.0 и может пропустить это без явной ошибки, открывая CSRF/credential-leak поверхность для credentialed-запросов с произвольных origin. Нет ни валидатора в Settings, ни теста на этот инвариант.

- **Рекомендация:** Добавить `model_validator` в Settings, который бросает исключение, если `CORS_ORIGINS` содержит `*` при `allow_credentials=True`. Добавить регрессион-тест на этот сценарий.

### 🔵 Low

#### 🔵 /api/v1/health отдаёт внутренние детали инфраструктуры без авторизации — `backend/app/main.py:366`

- **Категория:** security-check  |  **Верификация:** — не проверялось

- **Проблема:** Эндпоинт `/api/v1/health` документирован как «доступен без авторизации» (строка 380-381) и возвращает `cb_state` (агрегированное состояние Circuit Breaker), `tinvest_connected` и `scheduler_jobs`/`scheduler_running` без авторизации. `cb_state: triggered` внешнему наблюдателю сигнализирует, что у пользователя недавно сработал риск-контроль — утечка информации о торговом аккаунте человеку, просто дёргающему `/health` без токена. Также нет отдельной rate-limit категории (попадает в general, 200/min).

- **Рекомендация:** Оставить только `status`/`database`/`version` в публичном ответе, а `cb_state`/`tinvest_connected`/`scheduler_*` вынести в `/api/v1/health/detailed` с `Depends(require_admin)`.

#### 🔵 CSRF-защита пропускает запросы без cookie/header насквозь — `backend/app/middleware/csrf.py:46`

- **Категория:** security-check  |  **Верификация:** — не проверялось

- **Проблема:** `CSRFMiddleware.dispatch` (строки 40-47): если ни cookie `csrf_token`, ни header `x-csrf-token` не переданы — запрос пропускается без проверки, включая мутирующие методы. Разумно для чистого Bearer-token API, но тот же backend параллельно ставит HttpOnly `access_token` cookie (auth/router.py:34-61) для `AdminAuthASGIMiddleware`, и комбинация «браузер с access_token cookie, но без csrf_token» (например `csrf_token` cookie истёк раньше, TTL 24ч против 30 мин у access_token с продлением через refresh) создаёт окно, где мутирующий cookie-based запрос не потребует csrf-подтверждения.

- **Рекомендация:** Если запрос содержит cookie `access_token`, но отсутствует `csrf_token` — не пропускать, а требовать оба. Пропуск «both missing» оставить только для запросов без `access_token` cookie вовсе.

#### 🔵 Подавленная уязвимость protobuf (CVE-2026-0994) — нет автоматической проверки актуальности обоснования — `backend/safety_policy.yml:15`

- **Категория:** security-check  |  **Верификация:** — не проверялось

- **Проблема:** `safety_policy.yml` игнорирует Safety ID 85151 с обоснованием «не парсим внешний JSON через ParseDict» и датой ревью 2026-12-31, но нет привязки к конкретному коду — только текстовое обоснование. Если в будущем появится вызов `ParseDict` (например admin-импорт конфигурации), исключение останется активным и скроет реальную уязвимость.

- **Рекомендация:** Добавить grep-guard/тест в CI, который фейлит сборку при появлении `google.protobuf.json_format.ParseDict` в кодовой базе.


---

## 2. Security-check: конфигурация фронтенда и XSS-поверхность

Прямых XSS-синков (`dangerouslySetInnerHTML`, `innerHTML`, `insertAdjacentHTML`, `eval`, `new Function`, `document.write`) в `frontend/src` не обнаружено — sweep по всей директории дал 0 совпадений; `window.open` и `target="_blank"` использованы корректно (same-origin переход и `rel="noopener noreferrer"` соответственно). Секретов в бандле и незакоммиченных `.env` не найдено, версии `axios`/`vite` актуальны без известных критичных CVE. Основные риски лежат не в самом коде приложения, а в конфигурации хранения/передачи аутентификационных токенов и в отсутствии серверных security-заголовков: JWT хранится в localStorage вместо HttpOnly cookie, токен передаётся в query-string WebSocket URL (риск утечки через access-логи), а nginx не выставляет ни одного защитного HTTP-заголовка (CSP/X-Frame-Options/nosniff/Referrer-Policy). Вне периметра проверки остались backend CORS/cookie-конфигурация (`app/main.py`) и содержимое CI security-scan (bandit/safety).

### 🟠 High

#### 🟠 JWT access/refresh токены персистятся в localStorage (доступны из JS, нет HttpOnly) — `frontend/src/stores/authStore.ts:145`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `zustand persist(...)` с `partialize: { token, refreshToken, user }` записывает оба токена в localStorage под ключом `auth-storage` (подтверждено также вызовом `localStorage.removeItem('auth-storage')` в logout, строка 83). Любой XSS-вектор (в т.ч. будущий — через сторонний npm-пакет, Blockly custom field, XSS в зависимости Mantine/lightweight-charts) получает доступ к `localStorage.getItem('auth-storage')` и может похитить одновременно access и refresh токен, полностью компрометируя сессию пользователя торгового терминала (доступ к брокерскому счёту, управление live-сессиями) без возможности обнаружения — refresh token украден вместе с access, инвалидация при краже отсутствует. В проекте уже есть паттерн HttpOnly cookie (используется для admin/Plotly Dash аутентификации, см. комментарий в `api/client.ts:7-13`), но основной auth-flow его не использует — подтверждено также докстрингом в `backend/app/auth/router.py:40`, прямо описывающим хранение JWT в localStorage.

- **Рекомендация:** Перевести access/refresh токены на HttpOnly+Secure+SameSite=Strict cookie (по аналогии с уже реализованным подходом для admin/Plotly Dash), а в localStorage/zustand persist хранить только несекретные UI-данные (`user.username`, `is_admin` для отображения). Существующую частичную CSRF-защиту (`X-CSRF-Token` в `client.ts`) расширить на весь auth flow при переходе на cookie-based токены.

#### 🟠 JWT передаётся в query-string WebSocket URL (`ws://...?token=...`) — `frontend/src/hooks/useWebSocket.ts:23`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `getWsUrl()` формирует `${base}/ws?token=${token}`, подставляя токен в открытом виде в URL; аналогичный паттерн — в `stores/backtestStore.ts:130`. Backend (`backend/app/backtest/ws.py:20-37`, `_authenticate_ws`) читает токен только из query-параметров, альтернативы нет — query-string обязателен для аутентификации. Такой URL оседает в: (1) истории браузера, (2) access-логах nginx на этапе HTTP upgrade-запроса — `nginx.conf:25` содержит `access_log /dev/stdout;` на уровне `server{}` без кастомного `log_format` (дефолтный `combined` пишет `$request` целиком), а `location /ws/` (67-80) не переопределяет `access_log`, то есть токены пользователей оседают в открытых текстовых логах контейнера (`docker compose logs`, что подтверждается и комментарием в самом файле), (3) логах промежуточных прокси/CDN (Cloudflare Tunnel). Любой, у кого есть доступ к этим логам, получает валидный JWT без необходимости перехватывать трафик.

- **Рекомендация:** Передавать токен через WebSocket subprotocol header или отправлять его первым сообщением после установления соединения (auth handshake), а не в URL. Если на переходном этапе отказаться от query-string нельзя — исключить путь `/ws/` из access_log (кастомный `log_format` без `$request_uri` или `access_log off;` для этого location) на стороне nginx.

### 🟡 Medium

#### 🟡 Отсутствуют HTTP security-заголовки (CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy) — `nginx.conf:20`

- **Категория:** security-check  |  **Верификация:** — не проверялось

- **Проблема:** Серверный блок nginx отдаёт SPA-статику и проксирует `/api/`, `/ws/`, но нигде не добавляет `add_header` для Content-Security-Policy, X-Frame-Options (или `frame-ancestors` в CSP), X-Content-Type-Options: nosniff, Referrer-Policy. При отсутствии X-Frame-Options/frame-ancestors терминал можно встроить в скрытый iframe на стороннем сайте и организовать clickjacking поверх торговых действий (запуск сессии, отмена ордера). Отсутствие CSP убирает второй рубеж защиты от XSS даже при чистом коде приложения — защиту от будущих сторонних скриптов/расширений/supply-chain рисков в зависимостях (Blockly, `@tabler/icons-react` и др.).

- **Рекомендация:** Добавить в блок `server{}`: `add_header X-Frame-Options DENY;`, `add_header X-Content-Type-Options nosniff;`, `add_header Referrer-Policy strict-origin-when-cross-origin;`, `add_header Content-Security-Policy` с директивами под конкретные источники (`connect-src` для ws/wss на backend, `img-src` для CDN логотипов T-Invest, `script-src 'self'`).

### 🔵 Low

#### 🔵 VITE_API_BASE_URL/VITE_WS_URL — build-time дефолт на localhost без явной проверки при сборке — `frontend/src/api/client.ts:5`

- **Категория:** security-config  |  **Верификация:** — не проверялось

- **Проблема:** `import.meta.env.VITE_API_BASE_URL` и `VITE_WS_URL` инлайнятся Vite в бандл на этапе сборки (ожидаемое поведение для VITE_-префикса, не секрет сам по себе). Секретов не обнаружено — grep по `VITE_` и `import.meta.env` в `src` показал только два публичных URL-параметра с безопасными дефолтами (`http://localhost:8000`). Риска утечки credentials нет, но фолбэк на localhost:8000 в проде (если `.env.production` не подхватился при сборке Docker-образа) молча направит прод-фронтенд на локальный бэкенд разработчика — это функциональная, а не security проблема сама по себе.

- **Рекомендация:** На этапе CI/сборки production-образа проверять, что `VITE_API_BASE_URL`/`VITE_WS_URL` заданы явно и не равны дефолту localhost (fail build, если ENV не установлен).


---

## 3. Security-check: секреты в репозиториях

Проверены оба репозитория: внешний (Test, только документация) и вложенный (Develop, код). Внешний репозиторий чист — `.env`, `node_modules`, `.venv`, `Develop/` корректно исключены через `.gitignore`, вложенный репозиторий не заведён как git submodule. У Develop есть полноценный `.gitignore` (`.env*`, `*.db`, `*.sqlite`, `backups/`, `logs/`, `node_modules/`, `dist/`, `coverage`), а в git log единственный когда-либо добавленный `*.env*`-файл — ожидаемый `.env.example`. Grep по секрет-паттернам (600 строк во внешнем, 1827 во вложенном репозитории) дал в основном легитимные совпадения: переменные кода, тестовые фикстуры с фейковыми значениями и dev-дефолты в `config.py`, явно помеченные `change-in-production`/`change-me`. Единственная реальная находка — критическая: реальный `TELEGRAM_WEBHOOK_SECRET`, используемый в production-коде для верификации Telegram-вебхуков, закоммичен в открытом виде в `assets/telegram_bot_setup.md`. Содержимое `.env.example` не проверялось (заблокировано permission-политикой sandbox на чтение файлов `.env*`), но по `git ls-files` подтверждено, что это единственный `*.env*`-файл в репозитории.

### 🔴 Critical

#### 🔴 Реальный TELEGRAM_WEBHOOK_SECRET закоммичен в открытом виде в markdown-документации — `backend/assets/telegram_bot_setup.md:56`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** Файл `backend/assets/telegram_bot_setup.md` (добавлен коммитом 6635589, 2026-04-20, отслеживается git) содержит строку `TELEGRAM_WEBHOOK_SECRET=90f0...` — реальное значение, начинается с «90f0», длина 64 символа, hex. То же значение продублировано в строках 34 и 43 как параметр `secret_token=` в curl-примерах настройки Telegram webhook. Переменная реально используется в production-коде: `backend/app/config.py:23` (`TELEGRAM_WEBHOOK_SECRET: str = ""`) и `backend/app/notification/router.py:246` (`webhook_secret = getattr(app_settings, "TELEGRAM_WEBHOOK_SECRET", "")`) для проверки подлинности входящих Telegram webhook-запросов (заголовок `X-Telegram-Bot-Api-Secret-Token`). Эндпоинт `POST /telegram/webhook` (`router.py:427-429`) сравнивает этот заголовок со значением `handler.webhook_secret` и при несовпадении отдаёт 403 — это единственная проверка подлинности вебхука. Рядом в файле указаны реальный username бота (@moex_terminal_bot) и его ID (8630412731), что подтверждает: это настоящий, а не демонстрационный секрет — в отличие от соседнего `TELEGRAM_BOT_TOKEN=<от BotFather>`, оформленного как плейсхолдер. Локальный (не отслеживаемый git) `.env` содержит то же значение и того же бота, что окончательно подтверждает утечку реального секрета в git-историю. Любой, у кого есть доступ к репозиторию (или к его истории после ротации), может подделать webhook-запрос к `/api/v1/notifications/telegram/webhook`, обходя проверку подлинности отправителя.

- **Рекомендация:** Немедленно сгенерировать новый `TELEGRAM_WEBHOOK_SECRET` и обновить его в реальном `.env` на сервере (текущее значение считать скомпрометированным, т.к. попало в git-историю). В `backend/assets/telegram_bot_setup.md` заменить конкретное значение на плейсхолдер, например `secret_token=<сгенерировать: openssl rand -hex 32>` и `TELEGRAM_WEBHOOK_SECRET=<см. .env, не коммитить реальное значение>`. Проверить остальные `assets/*.md` на аналогичные утечки. Рассмотреть `git filter-repo`/BFG для очистки истории от значения, если репозиторий не приватный или предполагается публикация.


---

## 4. Security-check: аудит авторизации всех endpoint`ов (IDOR)

Проверено около 140 эндпоинтов (137 HTTP + 3 WS) в 24 роутерах (auth, users, strategy, backtest, trading, broker, market_data, price_alert, notification+telegram webhook, ai, ai/chat, sandbox, tax, corporate_actions, circuit_breaker, account, chart_drawings, user_favorites, admin+Dash mount, WS `/ws`, `/ws/trading-sessions`, `/ws/backtest`). Все требуют `get_current_user`, кроме публичных `/health`, `/market-status`, `/calendar`; админ-зона защищена `require_admin` и `AdminAuthASGIMiddleware`. IDOR по id в strategy, backtest, broker, chart_drawings, price_alert, tax, notifications, ai — проверены, владелец фильтруется по `user_id`; CSRF-мутаций нет (API работает только через Bearer). Однако в модуле `trading` обнаружен ряд критических и высоких IDOR — операции stop/pause/resume/trades/stats с чужими торговыми сессиями не проверяют владельца, а `stop` чужой сессии приводит к принудительной ликвидации реальных позиций жертвы. Дополнительно найдены проблемы в WS-мультиплексоре, обходе Telegram-webhook при пустом секрете и небезопасном дефолтном `SECRET_KEY`. Не была глубоко оттрассирована ветка `broker.get_operations`/`get_positions` через T-Invest — рекомендуется точечная ручная проверка.

### 🔴 Critical

#### 🔴 IDOR: остановка чужой сессии принудительно ликвидирует все её позиции — `backend/app/trading/router.py:121`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `PATCH /api/v1/trading/sessions/{session_id}/stop` вызывает `service.stop_session(session_id)` без `user_id` (router.py:128). `TradingService.stop_session` (service.py:526) → `OrderManager.close_all_positions` + `SessionManager.stop_session`, а `engine._get_session` (engine.py:379-387) грузит сессию только по id, без фильтра по владельцу. Любой аутентифицированный пользователь, подставив чужой `session_id` (последовательный int), закрывает все открытые позиции чужой live-сессии по рынку — прямая денежная потеря жертвы и срыв её стратегии. Сессии реальные (mode=real, T-Invest). Комментарии `S7R-SECURITY` (service.py:660-664, 693-694) показывают, что аналогичный IDOR уже был исправлен для `close_position` и `close_all_positions` (router.py:181 передаёт `user_id`), но не для `stop_session`.

- **Рекомендация:** Пробросить `user_id=current_user.id` в `stop_session` и внутри `SessionManager`/`engine._get_session` фильтровать сессию JOIN'ом `StrategyVersion→Strategy.user_id` (как в `delete_session`/`close_position`). Чужой `session_id` → 404.

### 🟠 High

#### 🟠 IDOR: пауза/возобновление чужой торговой сессии без проверки владельца — `backend/app/trading/router.py:101`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `PATCH .../sessions/{session_id}/pause` (router.py:108 → `service.pause_session(session_id)`) и `.../resume` (router.py:118 → `service.resume_session(session_id)`) не передают `user_id`; методы service.py:516/521 и `engine.pause_session`/`resume_session` грузят сессию через `_get_session` без фильтра по владельцу. Атакующий перебором `session_id` может поставить на паузу активную стратегию жертвы (сигналы блокируются — управляемый саботаж торговли) либо возобновить остановленную сессию. В отличие от `get_session`/`delete_session`, `user_id` здесь вообще не участвует.

- **Рекомендация:** Добавить `user_id` в `pause_session`/`resume_session` и проверять принадлежность сессии (JOIN `StrategyVersion→Strategy.user_id`) до смены статуса; чужая сессия → 404.

#### 🟠 IDOR-чтение: история сделок и статистика P&L чужой сессии — `backend/app/trading/router.py:188`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `GET .../sessions/{session_id}/trades` (router.py:199 → `service.get_trades`) и `.../stats` (router.py:227 → `service.get_stats`) вызывают методы service.py:713 и 746, фильтрующие `LiveTrade` только по `session_id`, без `user_id`. Аутентифицированный пользователь, подставив чужой `session_id`, читает все сделки, объёмы, цены входа/выхода и агрегированный P&L чужой торговой сессии — раскрытие торговой активности другого пользователя. Остальные эндпоинты сессий (positions/close/delete) владельца проверяют, а эти два — нет.

- **Рекомендация:** Добавить `user_id` в `get_trades`/`get_stats` и проверять владельца через существование сессии с JOIN `Strategy.user_id` (по шаблону `get_positions`, service.py:535); чужая сессия → 404.

#### 🟠 Broken access control на мультиплексном /ws: подписка на любой чужой канал — `backend/app/backtest/ws.py:94`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** В `/ws` после JWT-аутентификации клиент шлёт `{action:'subscribe', channel:'...'}` и подписывается на `event_bus` по произвольному имени канала без проверки владения (ws.py:92-108). К `user_id` привязывается только буквальный литерал `'notifications'` (ws.py:94-96). Публикаторы: `trades:{session_id}` (service.py:421), `backtest:{id}` (backtest/router.py:244), `notifications:{user_id}` (service.py:279), `system:{user_id}`. Подписавшись на `'trades:42'`, `'backtest:42'` или напрямую `'notifications:42'` (ID последовательные int), атакующий в реальном времени получает ордера/филлы/P&L чужих сессий, прогресс/результаты чужих бэктестов и чужие уведомления. `'notifications:42'` ≠ `'notifications'`, remap не срабатывает.

- **Рекомендация:** Валидировать каждую подписку: `trades:{sid}`/`backtest:{id}` — проверять владельца в БД; `notifications` строить как `notifications:{user_id}`, запретив явные `notifications:{N}`/`system:{N}`.

#### 🟠 Обход аутентификации Telegram-webhook при пустом TELEGRAM_WEBHOOK_SECRET — `backend/app/notification/router.py:428`

- **Категория:** security-check  |  **Верификация:** ✅ подтверждено

- **Проблема:** `POST /api/v1/notifications/telegram/webhook` сверяет `secret_header = header('X-...-Secret-Token', '')`; `if secret_header != handler.webhook_secret: 403` (router.py:427-430). `TELEGRAM_WEBHOOK_SECRET` по умолчанию `''` (config.py:23). При выставленном `TELEGRAM_BOT_TOKEN`, но пустом секрете сравнение `''!=''` → `False` → проверка проходит без заголовка, вебхук открыт для любого. Атакующий подделывает `Update` с `effective_chat.id` жертвы и `/closeall` + callback `confirm_closeall` → закрытие всех реальных позиций жертвы (telegram_webhook.py:691), либо `/close`, спуфинг сообщений. Сравнение к тому же не constant-time.

- **Рекомендация:** Не поднимать handler при пустом `webhook_secret` (`_get_webhook_handler` → `None`/503) либо отклонять запрос при пустом секрете. Сравнение — `secrets.compare_digest`.

#### 🟠 Дефолтный SECRET_KEY только предупреждает — риск подделки JWT и захвата аккаунтов — `backend/app/config.py:13`

- **Категория:** security-check  |  **Верификация:** — не проверялось

- **Проблема:** `SECRET_KEY='dev-secret-key-change-in-production'` задан по умолчанию (config.py:13), а валидатор `check_production_secrets` (config.py:78-91) при `DEBUG=False` лишь выдаёт `warnings.warn`, не прерывая старт. Тем же ключом подписываются все access-JWT (middleware/auth.py:21), им же аутентифицируются WS и `AdminAuthASGIMiddleware`. При развёртывании с дефолтным ключом атакующий сам подписывает токен `{sub:<любой user_id>, type:'access'}` и выдаёт себя за любого, включая `is_admin=True` (`get_current_user` грузит юзера из БД по `sub`) — полный доступ к чужим деньгам и админ-зоне.

- **Рекомендация:** При не-DEBUG останавливать запуск (`raise`), если `SECRET_KEY`/`ENCRYPTION_KEY` начинаются с `dev-` или короче 32 байт, вместо `warnings.warn`.


---

## 10. Backend: аутентификация, middleware, пользователи, ядро приложения

Блок в целом зрелый и аккуратно структурирован (сервисный слой в auth, Decimal в части расчётов баланса, argon2id, lockout и rate-limit присутствуют), но содержит одну критическую уязвимость и несколько серьёзных дефектов, ломающих реальную семантику сессий. Главные проблемы: дефолтные `SECRET_KEY`/`ENCRYPTION_KEY` с валидатором, который лишь предупреждает (а при `DEBUG=true` не срабатывает вовсе) — прямой путь к подделке JWT и расшифровке брокерских токенов; logout не отзывает refresh-токен, а refresh не ротируется — сессию невозможно принудительно завершить; в production связка CSRF-middleware и «голого» axios-рефреша даёт тихий разлогин каждые 30 минут. Средний пласт — rate-limit и lockout деградируют за nginx и после первой блокировки, синхронный argon2 стопорит event loop с live-стримами, история баланса искажается незапущенными сессиями и рассинхроном UTC/MSK-дат, неограниченный рост in-memory rate-limiter'а, перегруженный lifespan с проглоченными исключениями, market_data-логика внутри auth-роутера, деньги во float, невалидный дефолт AI_MODEL и фантомные настройки конфигурации. Не проверено: app/common (только как контекст), покрытие тестами lockout/refresh-revocation, фронтовая часть, admin/dash_mount и WS-роутеры (последние — вне зоны, но обнаружен смежный дефект в `ws.py:_authenticate_ws`, не проверяющий type токена).

### 🔴 Critical

#### 🔴 Дефолтные SECRET_KEY и ENCRYPTION_KEY — валидатор только предупреждает, не блокирует старт — `backend/app/config.py:13`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `SECRET_KEY='dev-secret-key-change-in-production'` и `ENCRYPTION_KEY='dev-encryption-key-change-me-32b'` захардкожены как дефолты и лежат в публичном репо. `check_production_secrets()` (строки 78-91) при `DEBUG=false` лишь вызывает `warnings.warn()`, но не прерывает запуск; при `DEBUG=true` (стандартный режим для dev по документации проекта) проверка пропускается полностью. Деплой без корректного `.env` стартует со стандартным ключом. Зная его из репозитория, атакующий кует любой JWT (`jwt.encode({sub:1,type:'access',...}, дефолтный_ключ, 'HS256')`) и получает доступ к любому аккаунту, включая `is_admin`. Тот же `ENCRYPTION_KEY` через HKDF (`common/crypto.py:30`, `salt=None`) детерминированно даёт AES-ключ — все сохранённые брокерские токены T-Invest расшифровываются любым, у кого есть доступ к БД. Верификация подтвердила использование `SECRET_KEY` в `auth/service.py:151-152`, `middleware/auth.py:21`, `admin/dash_mount.py:114`, а `ENCRYPTION_KEY` — в `broker/crypto_helpers.py:13`; иного гейта секретов в main.py/CI/Dockerfile не найдено.

- **Рекомендация:** В `check_production_secrets` при не-DEBUG (лучше — всегда при `ENV=production`) поднимать `RuntimeError` вместо `warnings.warn`, чтобы приложение отказывалось стартовать с dev-ключами. Убрать рабочие дефолты из кода (сделать `SECRET_KEY`/`ENCRYPTION_KEY` обязательными полями без default), проверять длину/энтропию. Не пропускать секрет-гейт при `DEBUG=true`.

### 🟠 High

#### 🟠 /auth/refresh не в EXEMPT_PATHS — в production каждый refresh токена падает с 403 и пользователь разлогинивается — `backend/app/middleware/csrf.py:26`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** `EXEMPT_PATHS` содержит только login/setup/health. Оба frontend-клиента делают refresh «голым» axios без interceptor'а, добавляющего `X-CSRF-Token` (`client.ts:83` `doRefresh`, `aiStreamClient.ts:16`). В production фронт и бэк на одном origin за nginx, поэтому браузер автоматически прикладывает cookie `csrf_token` (ставится на `/login`) к `POST /api/v1/auth/refresh`. Middleware видит «cookie есть, header нет» → 403 «CSRF token отсутствует». `doRefresh` молча ловит ошибку и возвращает null → через 30 минут (TTL access-токена) пользователь тихо разлогинивается, все запросы падают. В dev это не воспроизводится (cross-origin 5173→8000, cookie не отправляется), поэтому баг проявляется только на проде. Верификация подтвердила цепочку по файлам: `csrf.py:26/46-54`, `router.py:132-140`, `client.ts:63-69/83`, `aiStreamClient.ts:16`, `nginx.conf`.

- **Рекомендация:** Добавить `/api/v1/auth/refresh` в `EXEMPT_PATHS` (эндпоинт аутентифицируется refresh-токеном в JSON-теле, CSRF-атака через form-submit ему не грозит). Дополнительно/альтернативно — в `doRefresh` и `aiStreamClient` слать `X-CSRF-Token` из cookie.

#### 🟠 Logout не отзывает refresh-токен, а refresh не ротируется — сессию невозможно принудительно завершить — `backend/app/auth/router.py:174`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `POST /auth/logout` заносит в `RevokedToken` только jti access-токена из заголовка Authorization (`router.py:157-178`, `service.py:105-112`). Refresh-токен (TTL 7 суток) имеет собственный независимый jti (`service.py:136-149`, `uuid4`, связи между jti нет) и никогда не отзывается — предъявить его в теле `/logout` физически невозможно. `AuthService.refresh_token` (`service.py:74-91`) проверяет отзыв использованного jti, но при успешном обмене не ротирует и не отзывает старый refresh — один и тот же refresh-токен можно предъявлять многократно все 7 дней. Дополнительно `refresh_token()` не проверяет существование пользователя, `is_active` и `locked_until` — заблокированный или деактивированный аккаунт продолжает получать свежие токены (в отличие от `get_current_user`, не используемого в `/refresh`). `change_password` также не отзывает ранее выданные токены. Сценарий: refresh-токен утёк (localStorage на общем компьютере, XSS, лог) → пользователь нажимает «Выйти», считая сессию завершённой, → злоумышленник продлевает доступ бесконечной цепочкой refresh'ей — для торгового терминала с деньгами это критичный разрыв между ожидаемой и фактической семантикой logout.

- **Рекомендация:** В `/auth/logout` принимать `refresh_token` (или хранить связь access↔refresh по user_id) и заносить его jti в `RevokedToken`. В `refresh_token()` реализовать ротацию: отзывать jti использованного refresh при выдаче новой пары и детектировать повторное использование. Проверять в `refresh_token()` существование пользователя, `is_active` и `locked_until`. При смене пароля инвалидировать все активные токены (например, `token_version` в payload, сверяемый в `get_current_user`).

### 🟡 Medium

#### 🟡 Cookie access_token и csrf_token выставляются с secure=False — `backend/app/auth/router.py:58`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `_set_access_token_cookie` (`router.py:53-61`) и csrf-cookie в login (`router.py:132-140`) выставляются с `secure=False`. Проект уходит в production за nginx под HTTPS. С `secure=False` браузер отправит HttpOnly `access_token` и `csrf_token` и по обычному http:// (первый заход, downgrade, редирект, подменённая Wi-Fi-точка) — токен доступа и CSRF-секрет перехватываются в открытом виде (MITM). Захардкоженный `secure=False` рискует попасть в прод, если про доработку забудут.

- **Рекомендация:** Вычислять `secure` из настроек (`settings.PRODUCTION`/`ENV`) и в production выставлять `secure=True`. Рассмотреть `__Host-`/`__Secure-` префиксы. Не хардкодить `secure=False`.

#### 🟡 Rate-limit логина ключуется по request.client.host — за nginx все клиенты делят один лимит — `backend/app/middleware/rate_limit.py:93`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `_get_key` для категории `auth` возвращает `request.client.host` (для остальных категорий — тот же fallback, строка 105). В production все запросы приходят через nginx, но backend не обрабатывает `X-Forwarded-For`/`Forwarded` (uvicorn не запущен с `--proxy-headers`) — `client.host` всегда равен адресу прокси/докер-сети. Итог: лимит `LOGIN_RATE_LIMIT_PER_MINUTE=5` действует суммарно на ВСЕХ пользователей. Один клиент (или атакующий, целенаправленно шлющий 5 `POST /auth/login` в минуту) полностью блокирует вход в терминал для всех остальных — дешёвый DoS на аутентификацию; атакующий и жертва неразличимы, brute-force защита по IP бесполезна. Если позже начнут доверять XFF без валидации — тривиальный обход спуфингом заголовка.

- **Рекомендация:** Запускать uvicorn с `--proxy-headers` и `forwarded-allow-ips=<ip nginx>`, либо извлекать реальный IP из доверенного `X-Forwarded-For` (только от доверенного прокси, нужный hop). Не доверять XFF от произвольного источника.

#### 🟡 Открытая регистрация /auth/setup без гейта и без rate-limit — `backend/app/auth/router.py:64`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `POST /api/v1/auth/setup` вызывает `AuthService.register`, который создаёт нового пользователя при КАЖДОМ вызове (гейтится лишь флаг `is_admin` для первого юзера, а не сам факт создания). Эндпоинт исключён из CSRF (`csrf.py:26`) и не входит в категорию `auth` rate-limiter'а (`rate_limit.py:38` содержит только `/auth/login`) → попадает в `general` с лимитом 200/мин. На уже настроенном терминале любой неаутентифицированный клиент шлёт `POST /auth/setup {username,password}` и создаёт аккаунты — до 200/мин на IP: неавторизованное создание учёток и флуд таблицы users.

- **Рекомендация:** Определиться с моделью доступа: если терминал одно-/малопользовательский — блокировать `/setup` после первого пользователя (403 при `get_user_count()>0`) либо закрыть регистрацию за админ-инвайтом. Добавить `/auth/setup` в auth-категорию rate-limiter'а с жёстким лимитом.

#### 🟡 Неограниченный рост in-memory словаря rate limiter'а + блокирующий Lock в async-контексте — `backend/app/middleware/rate_limit.py:46`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `self._requests` (`defaultdict(list)`) пополняется на каждый запрос парой `(key, category)`, но устаревшие timestamp'ы чистятся только при повторном обращении с тем же ключом — сами ключи не удаляются никогда (само обращение `self._requests[(key, category)]` создаёт запись при read). Бот-сканирование `POST /api/v1/auth/login` с множества IP создаёт по записи навсегда; за недели аптайма процесс монотонно набирает память — медленная утечка без верхней границы. Дополнительно `dispatch()` держит блокирующий `threading.Lock` внутри async-обработчика (при contention блокируется весь event loop), а `jwt.decode` с проверкой подписи выполняется на каждом запросе только ради ключа лимита.

- **Рекомендация:** Добавить эвикцию: периодически (каждый N-ный запрос или по таймеру) удалять ключи с пустым/просроченным списком, либо перейти на TTL-структуру (`cachetools.TTLCache`); не использовать `defaultdict` на read-path. Заменить `threading.Lock` на `asyncio.Lock` или убрать блокировку. Для ключа `user_id` достаточно `jwt.decode(..., options={'verify_signature': False})` либо кэша token→sub.

#### 🟡 lifespan — перегруженная функция в composition root с проглоченными исключениями и бизнес-логикой чужих модулей — `backend/app/main.py:73`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `lifespan()` совмещает инициализацию 6 сервисов, recovery торговых сессий, резолв имени стратегии прямым запросом к `Strategy`/`StrategyVersion` (строки 190-211), создание уведомления `session_recovered` и shutdown-каскад. Вложенность for → try → try → try (строки 170-238), при этом на строках 210-211 голый `except Exception: pass` — ошибка резолва имени стратегии проглатывается без логирования. Также вызывается приватный метод `session_runtime._resolve_user_id()` (строка 173). Рефакторинг моделей strategy или `_resolve_user_id` ломает startup-код, а проглоченные исключения делают диагностику recovery по логам невозможной.

- **Рекомендация:** Вынести блок «подписки + нотификация session_recovered» в метод `SessionRuntime`/`NotificationService` (например, `notify_sessions_recovered(sessions)`). `_resolve_user_id` сделать публичным контрактом. В except на 210-211 добавить хотя бы `logger.debug`. В lifespan оставить только оркестрацию create/start/shutdown.

#### 🟡 Бизнес-логика market_data (prefetch) внутри auth-роутера + fire-and-forget asyncio.create_task без сохранения ссылки — `backend/app/auth/router.py:110`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Endpoint `/login` содержит прогрев кеша свечей: импорт `app.market_data.prefetch`, декодирование только что созданного JWT ради `user_id` (сервис знает `user.id`, но не возвращает) и `asyncio.create_task` без сохранения ссылки. Event loop держит только weak reference — таск prefetch может быть собран GC до завершения (документация asyncio явно предупреждает об этом), т.е. прогрев кеша молча не выполнится, недетерминированно, чаще под нагрузкой. Нарушение границ: auth напрямую управляет подсистемой market_data, логика не переиспользуется при `/refresh` или восстановлении сессии. Пользователь получает медленную первую загрузку графиков без каких-либо логов об ошибке.

- **Рекомендация:** 1) Вернуть из `AuthService.login()` пару (user, TokenResponse) — убрать декодирование собственного JWT. 2) Перенести планирование prefetch в событие event_bus (`user_logged_in`), на которое подписан market_data. 3) Если `create_task` остаётся — хранить сильную ссылку (модульный `_bg_tasks: set[asyncio.Task]` с `discard` в `done_callback`, там же логировать `exception()`), или использовать `BackgroundTasks`.

#### 🟡 Денежные значения конвертируются в float вопреки конвенции проекта (Decimal для денег) — `backend/app/account/service.py:170`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `AccountService` считает `total_value`/`cumulative_pnl` в Decimal, но на выходе делает `float(total_value)` и `float(cumulative_pnl)`, а `BalanceHistoryPoint` объявляет `total_value: float`, `trading_pnl: float` (`schemas.py:28-29`). При этом в том же файле `BalanceHistoryResponse.initial_capital: Decimal` — несогласованная типизация в одном модуле. Накопленная сумма `realized_pnl` типа `0.1+0.2` после float-конверсии даёт `300000.30000000004` в JSON — виджет баланса показывает артефакты двоичной арифметики; конвенция `Develop/CLAUDE.md` («Финансовые данные … в Python — decimal.Decimal») нарушена.

- **Рекомендация:** Объявить `total_value`/`trading_pnl` как `Decimal` в `BalanceHistoryPoint` (Pydantic v2 сериализует Decimal сам) и убрать `float(...)` в `service.py`. Если фронту нужен number — задать serializer с квантованием `Decimal('0.01')`.

#### 🟡 Невалидный дефолт AI_MODEL: датированный суффикс не существует — `backend/app/config.py:19`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Актуальные model id Anthropic для семейства 4.6 — алиасы без датового суффикса (`claude-sonnet-4-6`); строка `'claude-sonnet-4-6-20250514'` невалидна, и API вернёт 404 `not_found_error` (проверено по актуальному каталогу моделей). Дефолт используется как fallback в `app/ai/service.py:72` и `ai/router.py:218`. Пользователь, задающий в `.env` только `AI_API_KEY` без переопределения `AI_MODEL`, получит падение всех AI-запросов (генерация стратегий, чат) с 404 `model_not_found` — причина неочевидна.

- **Рекомендация:** Заменить дефолт на валидный алиас `'claude-sonnet-4-6'`. Не конструировать датированные id вручную; при старте можно валидировать модель через `GET /v1/models`.

#### 🟡 Фантомная конфигурация: getattr на несуществующих полях Settings (LOGIN_MAX_ATTEMPTS/LOGIN_LOCKOUT_MINUTES) — `backend/app/auth/service.py:61`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В `Settings` нет полей `LOGIN_MAX_ATTEMPTS` и `LOGIN_LOCKOUT_MINUTES` (есть только `LOGIN_RATE_LIMIT_PER_MINUTE`), а `model_config` задан с `extra='ignore'` — значения из `.env` не станут атрибутами. `getattr(...)` всегда возвращает захардкоженные 5 и 15 — код выглядит конфигурируемым, но им не является. Администратор, ставящий `LOGIN_MAX_ATTEMPTS=100` в `.env` для нагрузочного теста, получит молчаливое игнорирование настройки — аккаунты продолжат блокироваться после 5 попыток.

- **Рекомендация:** Либо объявить `LOGIN_MAX_ATTEMPTS: int = 5` и `LOGIN_LOCKOUT_MINUTES: int = 15` полями `Settings` и обращаться к ним напрямую, либо заменить `getattr` на явные константы модуля без иллюзии конфигурируемости.

#### 🟡 health_check обращается к приватным внутренностям чужих модулей и некорректно использует генератор get_db — `backend/app/main.py:416`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `/api/v1/health` импортирует приватный словарь `_singletons` из `app.broker.tinvest.multiplexer` (строка 416) и читает `scheduler_svc._scheduler` (строки 430-431) — приватные атрибуты без контракта: рефакторинг multiplexer/scheduler молча сломает health-check, а т.к. все ветки обёрнуты в `except Exception`, статусы тихо станут `'unknown'`/`False`, и деградацию мониторинга никто не заметит. Отдельно: блок `cb_state` итерирует `get_db()` вручную через `async for` и выходит по `break` (строка 409) — async-генератор остаётся приостановленным, и `async with AsyncSessionLocal()` внутри него закрывается лишь при GC async-генератора (недетерминированно); ручная итерация dependency-генератора — анти-паттерн. При частом опросе `/health` (балансировщиком/Dashboard) между циклами GC копятся открытые `AsyncSession`/соединения SQLite-пула, что под нагрузкой даёт всплески «database is locked» — класс проблем, с которым проект уже боролся (busy_timeout 30s). Также используется deprecated `datetime.utcnow()` (Python 3.12) и CB-запрос без `limit(1)`.

- **Рекомендация:** Добавить публичные фасады: `multiplexer.any_connected()` и `SchedulerService.health() -> (running, jobs_count)`. Для БД использовать `async with AsyncSessionLocal() as session:` вместо ручной итерации `get_db()`; добавить `.limit(1)` и `datetime.now(timezone.utc)`.

#### 🟡 Счётчик failed_login_count не сбрасывается после истечения блокировки — одна ошибка повторно блокирует аккаунт на 15 минут — `backend/app/auth/service.py:63`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** При неверном пароле счётчик инкрементируется, и при `failed_login_count >= 5` ставится `locked_until`. Когда блокировка истекает, счётчик остаётся `>= 5`: следующий же неверный ввод пароля делает `6 >= 5` и мгновенно ставит новую блокировку на 15 минут. Легитимный пользователь после первой блокировки, один раз опечатавшийся в пароле, снова блокируется на 15 минут — по кругу, фактически «одна попытка» после первой блокировки. Счётчик сбрасывается только при успешном входе, что в состоянии «забыл пароль» недостижимо.

- **Рекомендация:** При проверке `locked_until`: если блокировка истекла — обнулять `failed_login_count` (и `locked_until`) перед подсчётом новой неудачной попытки. Либо считать попытки в скользящем окне (сбрасывать счётчик, если последняя неудачная попытка старше `LOCKOUT_MINUTES`).

#### 🟡 Синхронные argon2 hash/verify блокируют event loop на каждом login/register/change_password — `backend/app/auth/service.py:126`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `ph.hash()` и `ph.verify()` (argon2id: `time_cost=3`, `memory_cost=64MB`) — CPU/memory-bound операции на ~100-400 мс, вызываются напрямую в async-обработчиках (register, login, change_password). На это время замирает весь event loop процесса: gRPC-стрим котировок T-Invest, обработка live-свечей торговых сессий, WebSocket-каналы. Во время активной live-торговли пользователь логинится со второго устройства (или перебирает пароль в пределах rate-limit) → торговый цикл получает паузы в сотни миллисекунд на каждый запрос — реальная деградация для системы, реагирующей на тики. Rate-limit 5/мин смягчает, но не устраняет.

- **Рекомендация:** Выносить хеширование в thread pool: `await asyncio.to_thread(ph.verify, hash, password)` и `await asyncio.to_thread(ph.hash, password)` (или `anyio.to_thread.run_sync`). Argon2 освобождает GIL в C-коде, поэтому thread pool решает проблему.

#### 🟡 Сессии со started_at=None считаются активными на все даты — initial_capital ретроактивно надувает историю баланса — `backend/app/account/service.py:150`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В `_initial_at` при `s.started_at is None` берётся `started = d`, из-за чего условие `started <= d` истинно для ЛЮБОЙ даты окна. Запрос сессий (строки 83-91) не фильтрует по статусу — грузятся и созданные, но не запущенные сессии. Пользователь, создавший paper-сессию с `initial_capital = 1 000 000 ₽`, но не нажавший «Старт», немедленно увидит виджет «Баланс» с +1 000 000 на всех 30 (или 365) точках истории, включая даты до создания сессии. График капитала врёт и по значению, и ретроспективно.

- **Рекомендация:** Не учитывать сессии без `started_at` вовсе (`if s.started_at is None: continue`), либо использовать `created_at` как нижнюю границу. Дополнительно исключить статусы created/cancelled из выборки сессий.

#### 🟡 Окно истории баланса строится по UTC-датам, а DailyStat.date пишется локальной датой сервера (MSK) — свежий PnL пропадает до 03:00 МСК — `backend/app/account/service.py:79`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `end_d = _today_utc()` — дата по UTC, и фильтр `DailyStat.date <= end_d` отсекает по ней. При этом trading-модуль пишет `DailyStat.date` как `date.today()` — локальная дата процесса (`engine.py:1758`, `risk_monitor.py:295`), на прод-сервере это Europe/Moscow. С 00:00 до 03:00 МСК (21:00-24:00 UTC) московская дата на день впереди UTC: сделки вечерней сессии MOEX записываются с датой d+1, а окно заканчивается UTC-датой d → последний торговый день полностью выпадает из `/account/balance/history`. Пользователь, торговавший на вечерней сессии и открывший Dashboard в 23:30 МСК, не увидит сегодняшний PnL — виджет баланса «теряет» дневную дельту до трёх часов ночи; кумулятивные точки сдвинуты на день.

- **Рекомендация:** Привести обе стороны к одной таймзоне: либо писать `DailyStat.date` по фиксированной зоне биржи (`datetime.now(ZoneInfo("Europe/Moscow")).date()`) и строить окно в `AccountService` по той же зоне, либо везде UTC. Не полагаться на локальную TZ сервера (`date.today()`).

#### 🟡 since_first_activity: фильтрация в роутере вместо сервиса + предикат «> 0» теряет активность при нулевом/отрицательном балансе — `backend/app/account/router.py:59`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Логика отрезания leading-точек реализована в роутере, а не в `AccountService` (бизнес-правило в транспортном слое). Первая «активная» точка ищется по `(p.total_value or 0) > 0`, хотя по докстрингу нужна «первая ненулевая». Если все точки окна ≤ 0 (сессии остановлены — `_initial_at` даёт 0, а накопленный `realized_pnl` отрицательный) либо `initial_capital = 0`, `first_idx = None` и endpoint возвращает `[]` — виджет показывает «нет данных», хотя торговая активность и убыток есть. Убыток тем самым маскируется — для финансового виджета это искажение хуже пустоты.

- **Рекомендация:** Перенести фильтр в `AccountService.get_balance_history(since_first_activity=...)` и определять первую активность по `!= 0`, либо по факту событий (первая дата с ненулевым `trading_pnl` или дата первой активной сессии `started_at`), а не по `> 0`.

### 🔵 Low

#### 🔵 Дублирование email-валидации с расходящимися regex в auth и users + отсутствие сервисного слоя в users — `backend/app/users/schemas.py:15`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Два независимых email-regex: `auth/schemas.py:33` (только ASCII-латиница) и `users/schemas.py:15` (любые не-пробельные символы). Email обновляется двумя маршрутами с разной валидацией: `PATCH /auth/profile` и `POST /users/me/wizard/complete`. Адрес с кириллицей `иван@почта.рф` принимается wizard'ом, но отклоняется при правке в профиле — рассинхрон поведения UI. Также `GET /me` задублирован в обоих роутерах, а `users/router.py` напрямую мутирует `User` и коммитит в роутере (сервиса в модуле нет) — противоречит принятой структуре router/service/schemas.

- **Рекомендация:** Вынести единый `EMAIL_RE` в `app/common` и переиспользовать в обеих схемах. Логику «обновить email + отметить wizard» вынести в `UserService`; `/auth/me` удалить в пользу `/users/me` (frontend уже мигрировал, судя по `usersApi.ts`).

#### 🔵 Роутер вызывает приватный метод сервиса _create_token_pair — `backend/app/auth/router.py:81`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Endpoint `/setup` после `register()` вызывает `service._create_token_pair(user.id)` — внутреннюю деталь `AuthService` (имя с подчёркиванием). Если сервис при выпуске токенов начнёт делать дополнительные действия (аудит, регистрация jti в БД — как дополнение к `login()`), маршрут `/setup` их молча пропустит — токены, выданные при регистрации, поведут себя иначе, чем токены из `/login`.

- **Рекомендация:** Добавить публичный метод `AuthService.register_and_login(...) -> TokenResponse` либо сделать `create_token_pair` публичным контрактом с docstring и перевести роутер на него.

#### 🔵 Таблица revoked_tokens никогда не чистится — просроченные записи копятся, SELECT на каждом запросе — `backend/app/auth/models.py:55`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `RevokedToken` хранит `expires_at`, но нигде (включая `SchedulerService`) нет джоба удаления записей с истёкшим `expires_at` — grep по проекту находит только вставку и SELECT'ы. При этом `get_current_user` делает запрос к `revoked_tokens` на каждом аутентифицированном запросе. За месяцы работы таблица монотонно растёт (каждый logout — новая строка), замедляя горячий путь аутентификации и раздувая БД/бэкапы без функциональной пользы: токен с истёкшим `exp` всё равно отвергается `jwt.decode`.

- **Рекомендация:** Добавить в `SchedulerService` периодический джоб `DELETE FROM revoked_tokens WHERE expires_at < now (UTC)` (раз в сутки достаточно, можно совместить с backup-джобом).

---

Дополнительно упомянуто ревьюерами вне основного списка находок (не оформлено как отдельные записи, для справки): тайминговая user-enumeration в login (`service.py:47-52` — ранний возврат без argon2 для несуществующего username); CSRF-middleware пропускает запрос при отсутствии и cookie, и header (эксплуатируемость низкая, т.к. эндпоинты требуют Bearer-header); `ws.py:_authenticate_ws` не проверяет `type` токена (принимает refresh как access) — смежный дефект вне зоны ревью; `int(payload["sub"])` в `middleware/auth.py` даст 500 вместо 401 на нечисловом `sub`; `csrf_token` cookie не удаляется при logout; docstring `/setup` не отражает bootstrap первого админа.


---

## 11. Backend: брокерская интеграция (T-Invest) и криптография

Блок в целом зрелый: единообразный `BrokerError`, `Decimal` в мапере, per-token rate limiter, продуманный reconnect/watchdog в мультиплексоре, аккуратная авторизация (JWT + ownership-фильтр `user_id`, IDOR не найден, ключи не возвращаются в ответах). TIMEFRAME_MAP и обработка временных зон в ISS-клиенте верифицированы против SDK и живого API — корректны. Главные проблемы: мультиплексор маршрутизирует live-свечи только по FIGI без учёта таймфрейма (искажённые OHLCV у стратегий), production может незаметно стартовать с публичным dev-ключом шифрования (превращает шифрование брокерских токенов в обфускацию), нарушена слоистость (бизнес-логика в роутере, циклическая зависимость broker↔trading), а денежные суммы в `BrokerBalance` посчитаны как `float` с неверной логикой `available`. Дополнительно есть N+1 к T-Invest без кеша справочника инструментов и заметный объём мёртвого кода (persistence rate limiter, `parse_candles`).

### 🟠 High

#### 🟠 Мультиплексор маршрутизирует свечи только по figi, игнорируя interval — подписчики получают свечи чужого таймфрейма — `backend/app/broker/tinvest/multiplexer.py:197`

- **Категория:** баг  |  **Верификация:** ⚠️ не опровергнуто

- **Проблема:** Докстринг заявляет мультиплексирование «по ключу (figi, interval)», но `self._routes` ключуется только по figi, и `is_first = len(self._routes[figi]) == 0` решает, отправлять ли серверную SUBSCRIBE, без учёта interval. `_dispatch_candle` раздаёт свечи всем listener'ам figi независимо от их interval. Сценарий: график SBER 5m уже подписан (первая подписка, сервер шлёт 5m); затем live-сессия/график 15m того же тикера подписывается на interval=1m для агрегации — SUBSCRIBE 1m на сервер не уходит (`is_first=False`), и callback сессии получает 5m-свечи, интерпретируя их как минутные. Агрегатор строит 15m-бары из искажённых данных → неверные торговые сигналы. В обратном порядке (сначала 1m) 5m-график рисует минутные бары как пятиминутные. UNSUBSCRIBE при этом шлёт interval последнего ушедшего listener'а, который может не совпадать с фактической серверной подпиской — отписка не срабатывает. Аналогичная проблема и в начальной переподписке после reconnect (`_resubscribe_all`/`_request_iterator` берут interval только первого listener'а).

- **Рекомендация:** Ключевать маршруты по `(figi, interval)`: `self._routes[(figi, interval)]`, `is_first` проверять для пары, в `_dispatch_candle` сопоставлять `response.candle.interval` с interval подписчика. SUBSCRIBE/UNSUBSCRIBE отправлять по паре `(figi, interval)`, только когда не осталось listeners именно этой пары; поправить `_resubscribe_all` и `_request_iterator` аналогично. Добавить regression-тест на две одновременные подписки разного interval на один figi.

#### 🟠 Production может незаметно работать с публичным dev-ключом шифрования — брокерские токены расшифровываются известным ключом — `backend/app/common/crypto.py:14`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено — `CryptoService.__init__` (crypto.py:14-20) не валидирует `master_key`, HKDF без соли (crypto.py:27). Дефолт `ENCRYPTION_KEY` захардкожен в config.py:16 и закоммичен. `check_production_secrets` (config.py:78-91) при `DEBUG=false` лишь `warnings.warn` (не `raise`) — старт не блокируется; в main.py доп. проверки нет, тестами fail-fast не покрыт. `get_crypto_service` создаёт singleton с этим ключом для шифрования broker `api_key`/`api_secret`. Эксплуатация воспроизводима: prod без `.env ENCRYPTION_KEY` → старт с легко теряемым warning → токены в БД/бэкапах расшифровываются известным ключом.

- **Проблема:** `CryptoService` принимает любой `master_key` без проверки стойкости; ключ берётся из `settings.ENCRYPTION_KEY` с публичным дефолтом `"dev-encryption-key-change-me-32b"`. Оператор, развернувший production без `ENCRYPTION_KEY` в `.env`, получает лишь предупреждение в логах (легко пропустить), и все `encrypted_api_key`/`encrypted_api_secret` в `broker_accounts` шифруются публично известным ключом. Любой, кто получит `terminal.db` или его копию из бэкапов (BackupService делает ежедневные копии), расшифровывает боевые T-Invest токены и может торговать от имени пользователя — прямой риск потери денег.

- **Рекомендация:** В `check_production_secrets` при `DEBUG=false` заменить `warnings.warn` на `raise RuntimeError` (fail-fast) для `SECRET_KEY` и `ENCRYPTION_KEY` с dev-префиксом. В `CryptoService.__init__` валидировать минимальную длину/энтропию `master_key` (>= 32 байт) и добавить фиксированную соль в HKDF. Рассмотреть ротацию ключа с версионированием (`key_id` в записи).

### 🟡 Medium

#### 🟡 Бизнес-логика в роутере: `get_account_balances` и `test_broker_connection` расшифровывают ключи и управляют адаптером напрямую — `backend/app/broker/router.py:244`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Endpoint `/balances` (~80 строк) сам вызывает `decrypt_broker_credentials`, `BrokerFactory.create`, `connect/get_balance/disconnect` и вычисляет `blocked` — это слой сервиса, а не роутера (конвенция проекта: router → service). То же в `test_broker_connection` (строка 162): decrypt + adapter lifecycle + замер latency в роутере. Ошибки по конкретному счёту маскируются `total=0/available=0` — пользователь не может отличить реальный нулевой баланс от отказа T-Invest API. Балансы счетов запрашиваются последовательно — при 3 счетах и деградации сети время ответа складывается.

- **Рекомендация:** Перенести логику в `BrokerService` (`get_balances(user_id)`, `test_connection(account_id)`); для упавшего счёта возвращать явный признак ошибки (`ok=false`/error), а не нули; счета опрашивать через `asyncio.gather`.

#### 🟡 Денежные поля BrokerBalance — float вместо Decimal, а available приравнен к total — `backend/app/broker/schemas.py:78`, `backend/app/broker/router.py:293`, `backend/app/broker/tinvest/adapter.py:249`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Две связанные проблемы в одной цепочке. (1) `BrokerBalance.total/available/blocked` объявлены `float`, хотя конвенция проекта — деньги считать в `Decimal`; в router.py Decimal из адаптера явно конвертируется (`total = float(balance.total)`), давая двоичную погрешность (например, `12345.679999999999`) и контрастируя с соседними схемами, которые сериализуют Decimal строками. (2) В адаптере `AccountBalance.available` приравнивается к `total_amount_portfolio` (полная стоимость портфеля, включая позиции), хотя T-Invest честно отдаёт `total_amount_currencies` (свободные деньги) — этот же атрибут уже используется в `get_sandbox_balance` того же файла. В результате `blocked = total - available` в router.py всегда 0, а UI/Telegram-бот показывают «доступно» = вся стоимость портфеля вместо реально свободных средств. Сценарий: портфель 1 000 000 ₽, из них 950 000 ₽ в акциях — пользователь видит «доступно 1 000 000 ₽» вместо 50 000 ₽.

- **Рекомендация:** `available` брать из `portfolio.total_amount_currencies`, `total` — из `total_amount_portfolio`; `blocked` считать от корректных значений. Параллельно перевести `BrokerBalance.total/available/blocked` на `Decimal` с `@field_serializer` в строку (как `BrokerPositionResponse`), убрать `float()`-конверсии в роутере.

#### 🟡 N+1 к T-Invest: `_fetch_instrument_info_by_figi` без кеша на каждый FIGI — `backend/app/broker/tinvest/adapter.py:362`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** На каждый запрос `GET /positions` или `/operations` адаптер в цикле последовательно дергает `instruments.get_instrument_by` по каждому уникальному FIGI через rate limiter. Портфель из 20 позиций — 20 unary-вызовов на каждый рефреш вкладки «Счёт»; страница операций (limit до 500) — до сотен вызовов. Справочник инструментов практически статичен, но не кешируется (в отличие от `_figi_cache` для ticker→FIGI). Это съедает бюджет rate limiter (300 req/min на токен), замедляя параллельные торговые операции того же токена, и даёт секунды латентности на endpoint.

- **Рекомендация:** Добавить кеш `figi→{ticker,name,instrument_type}` с TTL (например, сутки) по аналогии с `_figi_cache`, либо один вызов `instruments.shares()/bonds()/etfs()` с построением полного словаря при первом обращении.

#### 🟡 `detect_token_mode`/`detect_trading_rights` глушат любые исключения — сетевой сбой диагностируется как «ключ отклонён» — `backend/app/broker/tinvest/adapter.py:150`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Первая попытка (production `get_accounts`) обёрнута в `except Exception: pass` — без лога. Если запрос упал по transient-причине (таймаут gRPC, DNS, недоступность T-Invest), код молча пробует sandbox-режим, который для production-токена тоже падает, и пользователь получает «API-ключ отклонён T-Invest…» — ложная диагностика при рабочем ключе; идёт перевыпускать токен вместо повторной попытки. У detect-вызовов нет явного таймаута — создание аккаунта может висеть неограниченно. Аналогично `detect_trading_rights` при любой ошибке молча низводит токен до read-only (`has_trading_rights=False` фиксируется в БД).

- **Рекомендация:** Различать `grpc.StatusCode.UNAUTHENTICATED/PERMISSION_DENIED` (реально невалидный токен) от transient-ошибок (`UNAVAILABLE`/`DEADLINE_EXCEEDED`/сетевые): последние логировать и пробрасывать как `BrokerError` «T-Invest недоступен, попробуйте позже». Обернуть detect-вызовы в `asyncio.wait_for` с таймаутом.

#### 🟡 `get_trading_calendar` принимает параметр `year`, но никогда его не использует — `backend/app/broker/moex_iss/client.py:274`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Сигнатура `get_trading_calendar(self, year: int | None = None)` — параметр не попадает в params запроса (`params = {"iss.meta": "off"}`). При этом `MOEXCalendarService.load_calendar` (scheduler/moex_calendar.py:42) осмысленно передаёт `year=year`, полагая, что получает календарь конкретного года. Фактически ISS всегда возвращает диапазон по умолчанию, и запрос календаря будущего/прошлого года молча отдаёт не то, что просили: расписание торговых дней для планировщика формируется из неполных/нерелевантных данных без какой-либо ошибки или предупреждения.

- **Рекомендация:** Либо реализовать фильтрацию (прокидывать from/till по границам года в params), либо удалить параметр из сигнатуры и из вызова в moex_calendar.py, чтобы API не вводил в заблуждение.

#### 🟡 `_resolve_figi` ищет только акции (class_code=TQBR) — ордера и подписки по облигациям/ETF невозможны — `backend/app/broker/tinvest/adapter.py:270`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `place_order` и `subscribe_candles` резолвят FIGI через `_resolve_figi`, захардкоженный на `share_by(class_code="TQBR")`. Для тикера облигации (TQCB) или ETF (TQTF) вызов падает с «Не удалось найти FIGI» — хотя `get_instrument_info` в этом же адаптере честно перебирает share/bond/etf (дублирование похожей логики с разным поведением). Проект декларирует поддержку облигаций (bond_service в market_data): стратегия на облигации не сможет ни подписаться на свечи, ни выставить ордер. Плюс `_figi_cache` — класс-уровневый неограниченный dict без инвалидации.

- **Рекомендация:** Переиспользовать в `_resolve_figi` цепочку `share_by→bond_by→etf_by` из `get_instrument_info` (или `instruments.find_instrument`), вынеся общий код в один метод; кешу задать ограничение размера/TTL.

#### 🟡 Инверсия границ модулей: `broker.service` импортирует модели `trading` (LiveTrade, TradingSession) — `backend/app/broker/service.py:21`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Инфраструктурный модуль broker на верхнем уровне импортирует доменные модели `app.trading.models` и строит по ним запросы (`_fetch_strategy_tickers`, `_fetch_strategy_figis`, плюс импорт Strategy/StrategyVersion внутри метода) — при том что `trading` сам импортирует `app.broker.tinvest.adapter` (runtime.py:717, engine.py:1097). Получается двунаправленная зависимость broker↔trading: модули нельзя менять/тестировать независимо, а доменное правило классификации позиций «strategy/external» закопано в брокерском слое. Циклический импорт пока не срабатывает лишь потому, что импортируются разные подмодули.

- **Рекомендация:** Вынести определение source в вызывающий слой: broker возвращает «сырые» позиции, а trading/account-слой обогащает их source по своим моделям. Как минимум — передавать `strategy_tickers`/`figis` параметрами снаружи, убрав импорт `trading.models` из broker.

#### 🟡 Duck-typing через `getattr` вместо расширения `BaseBrokerAdapter`; ABC `get_operations` возвращает нетипизированный `list[dict]` — `backend/app/broker/service.py:460`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `service.get_positions/get_operations` достают методы адаптера через `getattr(adapter, "get_real_positions", None)` с runtime-проверкой на None — `get_real_positions/get_real_operations` не объявлены в `BaseBrokerAdapter`, поэтому статический анализ (pyright, обязательный по правилам проекта) контракт не видит: опечатка в имени или несовместимая сигнатура будущего адаптера обнаружится только в проде как `BrokerError 503`. Параллельно абстрактный `BaseBrokerAdapter.get_operations` возвращает нетипизированный `list[dict]`, хотя типизированный dataclass `BrokerOperation` уже есть — два конкурирующих контракта операций в одном интерфейсе.

- **Рекомендация:** Добавить `get_real_positions`/`get_real_operations` в базовый интерфейс (или отдельный `typing.Protocol`-capability) и вызывать напрямую; legacy `get_operations` перевести на `list[BrokerOperation]` или удалить из ABC.

#### 🟡 Повторное подключение с новым API-ключом молча оставляет в БД старый (протухший) ключ — `backend/app/broker/service.py:118`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В `create_account` при идемпотентном скипе (запись с тем же broker_type+account_id уже есть) существующая запись возвращается как есть — новые `encrypted_api_key/iv` в неё не записываются. Сценарий: токен T-Invest истёк (срок жизни 3 месяца), сообщение об ошибке ведёт пользователя заново подключить ключ; он вводит свежий токен, discover находит те же account_id, сервис возвращает 201 — пользователь уверен, что ключ обновлён, но в БД остался старый, и все вызовы брокера продолжают падать. `BrokerAccountUpdate` поддерживает только name/is_active — легального пути ротации ключа нет, кроме delete+create (при этом `TradingSession.broker_account_id` обнуляется через `ondelete=SET NULL` — теряется связь истории сессий со счётом).

- **Рекомендация:** При совпадении account_id обновлять `encrypted_api_key/encrypted_api_secret/encryption_iv` (и `is_sandbox/has_trading_rights`) существующей записи новыми значениями, либо добавить явный endpoint ротации ключа.

#### 🟡 `place_order` выбирает `ORDER_TYPE_LIMIT`, но не передаёт `price` в `post_order` — лимитные ордера всегда падают — `backend/app/broker/tinvest/adapter.py:582`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** При `price is not None` выставляется `order_type=ORDER_TYPE_LIMIT`, однако в вызовы `client.orders.post_order`/`client.sandbox.post_sandbox_order` параметр `price` (Quotation) не передаётся вовсе (в SDK он Optional, по умолчанию None). T-Invest отклонит лимитную заявку без цены (`INVALID_ARGUMENT`) → `BrokerError`. Сейчас trading engine вызывает `place_order` только с `price=None` (market), поэтому дефект латентный, но публичный контракт `BaseBrokerAdapter.place_order(price=...)` сломан: любой будущий вызов с ценой (лимитные входы, SL/TP через лимитки) молча уйдёт без цены и упадёт.

- **Рекомендация:** Передавать price в SDK: `from tinkoff.invest.utils import decimal_to_quotation`; `price_q = decimal_to_quotation(price) if price is not None else None` и прокидывать `price=price_q` в `post_order`/`post_sandbox_order`. Добавить unit-тест на лимитную ветку.

### 🔵 Low

#### 🔵 Дублирование ~40 строк между `get_sandbox_balance` и `top_up_sandbox_to` + обход `BrokerFactory` прямым `TInvestAdapter` — `backend/app/broker/service.py:208`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Оба sandbox-метода повторяют идентичный блок: три проверки аккаунта, decrypt, `TInvestAdapter(sandbox=True)`, connect, try/finally с проглоченным disconnect. Остальной сервис создаёт адаптеры через `BrokerFactory.create` — sandbox-методы жёстко привязаны к T-Invest в обход собственной фабрики. Тот же паттерн размножен по кодовой базе (market_data/service.py:535, stream_manager.py:136, trading/runtime.py:717,1044, engine.py:1097, telegram_webhook.py:521) — `BrokerFactory` фактически декоративная, появление второго брокера потребует правок в 7+ местах.

- **Рекомендация:** Выделить асинхронный contextmanager `_connected_sandbox_adapter(account)` с валидацией+decrypt+connect/disconnect; адаптер получать через `BrokerFactory.create(account.broker_type, sandbox=True)`.

#### 🔵 Дублирование логики resubscribe: после reconnect каждый figi подписывается дважды — `backend/app/broker/tinvest/multiplexer.py:459`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** После обрыва `_run_stream` вызывает `_resubscribe_all()` (кладёт SUBSCRIBE-команды в очередь для всех routes), но новый `_request_iterator()` при старте сам yield'ит начальную подписку на те же figi из `self._routes`. В результате на каждый reconnect T-Invest получает по два `SubscribeCandlesRequest` на figi (идемпотентно, но лишние запросы), а логика начальной переподписки живёт в двух местах и может разъехаться при правках. Старый `_request_iterator` предыдущего соединения может оставаться подвешенным на `command_queue.get()` и конкурировать за команды с новым.

- **Рекомендация:** Оставить один источник истины: убрать `_resubscribe_all` (начальная подписка уже есть в `_request_iterator`) либо наоборот; при пересоздании стрима явно закрывать предыдущий request-итератор (`aclose`).

#### 🔵 Мёртвый код персистентности rate limiter — `PersistentTokenBucketRateLimiter` и `save/load_all_limiters` никогда не срабатывают — `backend/app/broker/tinvest/rate_limiter.py:80`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `get_rate_limiter` — единственная точка создания лимитеров — всегда создаёт базовый `TokenBucketRateLimiter`, поэтому isinstance-проверки в `save_all_limiters`/`load_all_limiters` всегда False: класс персистентности, сериализация состояния и `DEFAULT_PERSIST_PATH` (относительный путь, зависящий от cwd) — ~70 строк недостижимого в production кода. Вызовов `save_all`/`load_all` в `app/` вообще нет. Создаётся ложное впечатление, что состояние rate limiter переживает рестарт; на деле после рестарта бакет полный (300 токенов), и залп запросов сразу после деплоя может превысить фактический остаток лимита T-Invest → 429.

- **Рекомендация:** Либо реально включить: создавать `PersistentTokenBucketRateLimiter` в `get_rate_limiter` (путь — hash токена, не сам токен) и звать `load`/`save` из lifespan startup/shutdown, либо удалить персистентный слой целиком.

#### 🔵 Мёртвый метод `parse_candles` и дублирующий dataclass `CandleData` с рассинхронной обработкой таймзоны — `backend/app/broker/moex_iss/parser.py:46`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `MOEXISSParser.parse_candles` не вызывается нигде в production (client использует только `parse_candles_raw`); вместе с ним мёртв локальный dataclass `CandleData`, чьё имя коллидирует с `app.broker.base.CandleData` (риск ошибочного импорта). Мёртвая версия парсит begin/end как naive datetime, а живая `parse_candles_raw` помечает `tzinfo=UTC` — если кто-то «переиспользует» `parse_candles`, свечи молча сдвинутся на offset системной таймзоны (та же ловушка, ради которой в adapter.py завели `_to_utc_aware`).

- **Рекомендация:** Удалить `parse_candles` и локальный `CandleData`; если нужен типизированный результат — возвращать доменный `CandleData` из broker/base.py с tz-aware временем.

#### 🔵 `encrypt/decrypt_broker_credentials` лезут в приватный `_aes_key` и дублируют AESGCM-логику `CryptoService` — `backend/app/broker/crypto_helpers.py:58`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Хелперы обходят публичный API `CryptoService` и напрямую читают `crypto._aes_key`, создавая собственный AESGCM и повторяя шифрование с XOR-производным IV в двух местах. Инкапсуляция сломана: любое изменение внутренностей `CryptoService` (ротация ключа, смена алгоритма, добавление AAD) молча разъедется с этим дублем, а знание о деривации sub-IV (`b ^ 0x01`) размазано по модулю broker вместо крипто-слоя. ARCH-REVIEW NOTE в докстринге сам признаёт схему компромиссом из-за единственной колонки `encryption_iv`.

- **Рекомендация:** Добавить в `CryptoService` методы `encrypt_pair`/`decrypt_pair` (или `encrypt_with_iv`), инкапсулировав деривацию sub-IV внутри; `crypto_helpers` оставить тонкой обёрткой без доступа к приватным полям. Долгосрочно — отдельная колонка IV на каждое шифруемое поле.

#### 🔵 Сортировка операций смешивает naive `datetime.min` с aware датами — TypeError валит весь endpoint — `backend/app/broker/tinvest/adapter.py:494`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `all_ops.sort(key=lambda o: getattr(o, "date", None) or datetime.min, reverse=True)`: операции T-Invest имеют tz-aware date (UTC), а fallback `datetime.min` — naive. Если хотя бы у одной операции date отсутствует/None, сравнение aware и naive datetime бросит `TypeError: can't compare offset-naive and offset-aware datetimes` → исключение заворачивается в `BrokerError` → `GET /broker/accounts/{id}/operations` возвращает 503 для всего запрошенного периода.

- **Рекомендация:** Использовать aware-fallback: `datetime.min.replace(tzinfo=timezone.utc)`.

#### 🔵 `get_sandbox_balance` игнорирует параметр `currency` — top-up в не-RUB валюте считает diff от неверной базы — `backend/app/broker/tinvest/adapter.py:691`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Метод принимает `currency`, но парсит `portfolio.total_amount_currencies` — агрегат денежных средств по всем валютам (в рублях), без фильтра по запрошенной валюте. Сценарий: `top_up_sandbox_to(target=1000, currency="usd")` сравнит целевые $1000 с рублёвой оценкой всех валют и сделает PayIn на бессмысленную разницу; при наличии на sandbox-счёте валюты, отличной от RUB, даже рублёвый top-up до target вычислит diff с учётом чужой валюты и пополнит не на ту сумму. Router (`SandboxTopUpRequest`) при этом допускает любой 3-символьный код валюты.

- **Рекомендация:** Получать баланс конкретной валюты (`positions.money` с фильтром по currency через `get_sandbox_positions`) либо явно ограничить API валютой rub и валидировать `currency == "rub"` на входе.

#### 🔵 `checked_at = datetime.utcnow()` — naive datetime уходит в API без таймзоны — `backend/app/broker/router.py:180`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `BrokerTestConnectionResponse.checked_at` заполняется naive `datetime.utcnow()` (deprecated в Python 3.12). Pydantic сериализует его без суффикса Z/+00:00, и фронтенд, распарсив строку через `new Date()`, интерпретирует её как локальное время. Сценарий: пользователь в MSK жмёт «проверить подключение» — «проверено в HH:MM» отображается со сдвигом на 3 часа.

- **Рекомендация:** Использовать `datetime.now(timezone.utc)` — aware значение сериализуется с `+00:00` и корректно парсится фронтендом.

#### 🔵 Первые 8 символов брокерского токена пишутся в логи (`token_prefix`) — `backend/app/broker/tinvest/multiplexer.py:597`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `get_or_create_multiplexer` и `shutdown_multiplexers` логируют `token_prefix=token[:8]` (строки 597, 613, 618). Токены T-Invest начинаются с "t.", то есть в лог попадает ~6 символов реального секрета. При доступе к файловым логам (лог-агрегатор, бэкап логов, CI-артефакты) атакующий получает частичный материал токена и возможность коррелировать активность токенов/пользователей. Полностью восстановить токен по префиксу нельзя, поэтому severity низкая.

- **Рекомендация:** Логировать не срез токена, а необратимый идентификатор: `hashlib.sha256(token.encode()).hexdigest()[:8]`. Это сохраняет различимость multiplexer'ов в логах без утечки материала ключа.

#### 🔵 Ticker без валидации интерполируется в URL MOEX ISS — path/query-инъекция в исходящие запросы — `backend/app/broker/moex_iss/client.py:136`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** В `_fetch_native`, `get_instrument_info`, `get_lot_size` тикер подставляется в f-string URL без валидации и URL-кодирования. Тикер приходит из пользовательских параметров market_data router (только min/max_length, без паттерна) и из path-параметра `/instruments/{ticker}`, где Starlette декодирует `%2F` в "/". Сценарий: `ticker="SBER%2F..%2F..%2Fturnovers"` или тикер с "?" позволяет запросить произвольный endpoint iss.moex.com или подменить query-параметры (from/till/interval) и записать искажённые свечи в OHLCV-кеш под этим псевдо-тикером. Хост зафиксирован base_url (публичные данные MOEX), поэтому полноценный SSRF во внутреннюю сеть невозможен — отсюда низкая severity.

- **Рекомендация:** Валидировать тикер по whitelist-паттерну на входе (Pydantic pattern `^[A-Za-z0-9@._-]{1,20}$` в market_data router и в самом `MOEXISSClient` как defense-in-depth) и/или прогонять через `urllib.parse.quote(ticker, safe="")` перед подстановкой в путь.

#### 🔵 Неограниченный реестр `_global_limiters` с плейнтекст-токенами в качестве ключей, без эвикции — `backend/app/broker/tinvest/rate_limiter.py:122`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `get_rate_limiter` кладёт каждый уникальный `api_key` (сырой брокерский токен) в module-level словарь `_global_limiters` и никогда не удаляет записи; `adapter.disconnect()` обнуляет только ссылку в адаптере. Аналогично `_singletons` в multiplexer.py хранит токены как ключи. Сценарии: (1) аутентифицированный пользователь, спамя `POST /api/v1/broker-accounts/discover` случайными строками ≥10 символов (общий rate limit 200 req/min), бесконечно растит словарь — медленный memory-DoS; (2) отозванные/заменённые токены остаются в памяти процесса в открытом виде на всё время жизни backend'а и попадают в core dump/снапшоты памяти.

- **Рекомендация:** Ключом реестра сделать хеш токена (sha256), а не сырое значение; ограничить размер реестра (LRU/TTL-эвикция неиспользуемых limiter'ов). То же для `_singletons` мультиплексора: ключ — хеш, сам токен хранить только внутри активного экземпляра.

---

**Не вошло в находки, отмечено ревьюерами как заслуживающее внимания:** deprecated `datetime.utcnow()` в других местах router.py; `BrokerAccountWithBalance.balance` всегда None; последовательный (не параллельный) вызов callbacks в `_dispatch_candle`; `get_instrument_info` глушит все исключения в fallback-цепочке; `str(e)` от gRPC уходит в detail HTTP-ответов; `/discover` — потенциальный оракул валидации чужих T-Invest токенов (ограничен общим лимитом 200 req/min). Не проверено в рамках ревью: соответствие TIMEFRAME_MAP актуальным enum SDK для отдельных таймфреймов вне выборки, корректность 4h-агрегации ISS относительно сессий MOEX, unit-тесты reconnect-логики мультиплексора и лимитной ветки `place_order`, содержимое middleware/auth.py и .env/.env.example.


---

## 12. Backend: торговый модуль (live-торговля)

Модуль `backend/app/trading` работает и неплохо задокументирован, но несёт следы серийных hotfix'ов: логика закрытия позиции разошлась на три копии (`close_position` / `close_all_positions` / `RiskMonitor._apply_close`), присутствует мёртвый код (`PositionTracker`, `_condition_to_expr`), а критичные для денег пути — остановка сессии, exit-сигналы стратегий, paper-учёт средств и сверка real-позиций при рестарте — либо ломают учёт капитала, либо не работают вовсе. Дополнительно обнаружен системный кластер IDOR: пять эндпоинтов (`stop`, `pause`, `resume`, `trades`, `stats`) управляют или раскрывают чужие торговые сессии по одному лишь `session_id`, хотя аналогичные соседние методы (`close`, `get_positions`, `get_session`) уже защищены owner-check'ом. Тестов на `close_all_positions`, exit-сигнал и paper-учёт средств не обнаружено. Часть находок (N+1 запросы, дублирование кода, magic strings, дизайн ответов API) отнесена к техдолгу среднего/низкого приоритета и не создаёт прямой угрозы деньгам пользователей.

### 🔴 Critical

#### 🔴 `close_all_positions` закрывает позиции без exit_price/PnL, без ордера брокеру и без возврата средств — `backend/app/trading/engine.py:1673`

- **Категория:** баг (дублирует находку по качеству кода)  |  **Верификация:** ✅ подтверждено

- **Проблема:** `OrderManager.close_all_positions` лишь ставит `status='closed'` и `closed_at`, в отличие от полнофункционального `close_position` (строка 1446), который берёт рыночную цену, возвращает средства через `PaperBrokerAdapter`, шлёт реальный ордер для sandbox/real и считает PnL через `RiskMonitor._apply_close`. Метод вызывается из `TradingService.stop_session` (service.py:529, кнопка «Остановить сессию») и эндпоинта `POST /sessions/{id}/close-all` (router.py:181). Для paper: `exit_price/pnl/pnl_pct` остаются NULL, средства в `PaperPortfolio` не возвращаются, `pnl=NULL` не попадает ни в win, ни в loss статистики. Для sandbox/real ещё хуже: терминал показывает «позиции закрыты», но у брокера позиция реально остаётся открытой без ордера на закрытие и без мониторинга SL/TP — рассинхрон учёта и потенциальная потеря денег. Docstring `close_position` описывает то же поведение как уже исправленный ранее баг — фикс не портирован во второй метод. Telegram-бот `/closeall` использует корректный per-trade `close_position`, поэтому поведение двух «одинаковых» операций расходится.

- **Рекомендация:** Переписать `close_all_positions` как цикл по открытым trade'ам с вызовом `self.close_position(trade.id, reason='close_all')` (как уже делает `telegram_webhook._execute_closeall`), убрав дублирующую упрощённую ветку. Pending-сделки без `broker_order_id` помечать `'failed'`, а не `'closed'`. Ошибку по одному trade логировать и продолжать цикл.

#### 🔴 IDOR: любой пользователь может остановить чужую торговую сессию — `backend/app/trading/router.py:122`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `PATCH /sessions/{session_id}/stop` вызывает `service.stop_session(session_id)` без `current_user.id`, хотя `current_user` доступен в эндпоинте. `service.stop_session` (service.py:526) вообще не принимает `user_id` и внутри вызывает `order_manager.close_all_positions(session_id)` + `session_manager.stop_session(session_id)` — обе фильтруют только по `session_id`, owner-check отсутствует. Соседние методы (`close_position`, `delete_session`, `get_positions`) уже защищены JOIN на `Strategy.user_id` (рефактор S7R-SECURITY), но `stop` этот фикс пропустил. Аутентифицированный атакующий, перебирая autoincrement `session_id`, может остановить чужую live-сессию: торговля жертвы принудительно прекращается, все её позиции помечаются `status='closed'` (для real-режима — без реальных ордеров брокеру, см. находку выше) — рассинхрон учёта и потенциальная потеря денег жертвы.

- **Рекомендация:** Добавить `current_user` в Depends, пробросить `user_id` в `service.stop_session` и выполнить JOIN-ownership-check `StrategyVersion → Strategy.user_id` (как в `close_position`/`delete_session`), возвращать `NotFoundError` при чужом владельце.

### 🟠 High

#### 🟠 Exit-сигнал стратегии никогда не закрывает позицию — блокируется `max_concurrent_positions` — `backend/app/trading/engine.py:904`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** W8b exit-bypass в runtime.py:1334 пропускает Circuit Breaker для сигнала, противоположного открытой позиции, но дальше `OrderManager.process_signal` считает открытые сделки и при `open_trades >= max_concurrent_positions` (default 1) возвращает `None` ДО определения направления сигнала. Стратегия, открывшая BUY и на следующей свече давшая SELL (exit), молча теряет сигнал (`logger.debug max_positions_reached`). Позиция закрывается только по SL/TP или вручную; если SL/TP не заданы, RiskMonitor NULL-уровни пропускает — позиция висит бессрочно с неограниченным убытком. Даже при `max_concurrent_positions > 1` сигнал открыл бы новую встречную сделку, а не закрыл существующую — netting/exit-закрытие не реализовано нигде (`PositionTracker.update_position` нигде не вызывается).

- **Рекомендация:** В `OrderManager.process_signal` перед проверкой лимита позиций определять exit-кейс (открытая filled-сделка противоположного направления) и вызывать `close_position` для неё вместо создания новой `LiveTrade`. Лимит `max_concurrent_positions` применять только к entry-сигналам. Покрыть тестом сценарий buy→sell→позиция закрыта.

#### 🟠 Каждое intra-bar обновление свечи обрабатывается как закрытый бар — `backend/app/trading/runtime.py:246`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** ТЗ и docstring требуют сигнальный цикл «на каждой закрытой свече», но `multiplexer.py` подписывается без `waiting_close` (default False в SDK) — T-Invest шлёт обновление формирующейся свечи на каждой сделке, а `_SessionListener._handle_candle` не проверяет смену timestamp бара. Следствия: (1) `history.append` на каждый тик — при лимите 200 реальная история для SMA/RSI вытесняется десятками копий одного формирующегося бара, индикаторы считаются неверно и расходятся с бэктестом; (2) стратегия исполняется по незакрытому бару многократно — сигнал может сработать на внутрибарном всплеске, которого нет в закрытой свече; (3) для агрегированных ТФ (15m/1h/4h) `_AggregatingCandle.update` публикует частичную свечу периода на каждом событии. При `cooldown_seconds=0` (default) от повторных входов спасает только `max_concurrent_positions`.

- **Рекомендация:** Подписываться с `waiting_close=True` либо в `_handle_candle` детектировать закрытие бара по смене `period_start` и запускать сигнальный цикл только на новом баре; обновления текущего бара — только обновлять последний элемент истории. Для агрегатора публиковать отдельное событие `candle.closed` при смене периода.

#### 🟠 Сверка позиций real-сессий при рестарте не выполняется никогда — `backend/app/trading/runtime.py:1010`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** `_check_real_positions` возвращает `False` («расхождений нет»), если `not account.encrypted_api_secret`. Но T-Invest — single-token контракт, `encrypted_api_secret` для него всегда NULL (это явно задокументировано в этом же файле в `_resolve_broker_credentials`, где аналогичный guard уже был удалён как блокировавший стрим на всех T-Invest аккаунтах в проде). Таким образом для 100% real-аккаунтов сверка позиций с брокером после рестарта backend — мёртвый код. Если backend лежал, а пользователь тем временем закрыл позицию через приложение брокера — после рестарта `restore_all` не увидит расхождение, сессия возобновится с фантомной filled-позицией: RiskMonitor будет «закрывать» несуществующую позицию по SL/TP, статистика и торговля работают по неверному состоянию.

- **Рекомендация:** Убрать `not account.encrypted_api_secret` из условия (достаточно `encrypted_api_key + encryption_iv`), как уже сделано в `_resolve_broker_credentials`. Добавить тест: real-сессия + аккаунт без `api_secret` → сверка выполняется.

#### 🟠 Paper-портфель: покупка не списывает средства, ручное закрытие зачисляет выручку «из воздуха» — `backend/app/trading/paper_engine.py:172`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** В production paper-flow (`OrderManager.process_signal`, engine.py:996-1005) сделка заполняется мгновенно без обращения к `PaperBrokerAdapter` и без изменения `PaperPortfolio` — деньги при покупке не списываются и не блокируются. Единственный код, дебетующий портфель (`PositionTracker.on_order_filled`), нигде не вызывается в production (dead code). При этом ручное закрытие вызывает `paper place_order(sell)`: `balance += exit_price × quantity`, причём `quantity` в лотах, без `lot_size`. Итог: каждый цикл buy→manual close увеличивает баланс на всю выручку без списания стоимости покупки; закрытия по SL/TP (`RiskMonitor._apply_close`) портфель вообще не трогают. `PaperPortfolio.balance/peak_equity` — фикция, а от них зависит расчёт equity/drawdown в Circuit Breaker — защита по просадке на paper фактически не работает.

- **Рекомендация:** Ввести единый учёт: при paper-fill в `process_signal` списывать `balance -= entry_price × lots × lot_size`; при любом закрытии (manual, SL/TP, close_all) кредитовать `exit_price × lots × lot_size`. Удалить или подключить `PositionTracker` (сейчас dead code). В `paper_engine.place_order` учитывать `lot_size`.

#### 🟠 Ручное закрытие pending-сделки (entry_price=NULL) записывает фиктивную прибыль — `backend/app/trading/engine.py:1465`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** `close_position` допускает `status='pending'`. У pending-сделки `entry_price=NULL`. Если в `OHLCVCache` есть цена, `exit_price` = рыночная цена, а `RiskMonitor._apply_close` подставляет `entry = trade.entry_price or Decimal('0')`. Для buy-направления `pnl = (exit − 0) × lots × lot_size` — вся номинальная стоимость позиции записывается как прибыль. Сценарий: sandbox-ордер завис в pending, пользователь видит его как открытую позицию и жмёт «Закрыть» — в `LiveTrade.pnl` и `DailyStat.pnl` попадает фиктивная прибыль в размере полной стоимости позиции; дневная статистика и проверки Circuit Breaker по дневному убытку искажаются.

- **Рекомендация:** Для сделок с `entry_price=NULL` не считать PnL (оставить NULL) и помечать `'failed'/'cancelled'` вместо `'closed'`, предварительно попытавшись отменить ордер у брокера. В `_apply_close` добавить guard: при `entry <= 0` не вычислять pnl.

#### 🟠 Нарушение границ: FIGI для sandbox/real-сделок берётся из paper-заглушки — `backend/app/trading/engine.py:929`

- **Категория:** качество кода / потенциальный баг  |  **Верификация:** — не проверялось

- **Проблема:** `process_signal` для любого режима создаёт `PaperBrokerAdapter` и вызывает его `get_instrument_info` — заглушку, всегда возвращающую `figi=f"paper_{ticker}"`. В результате `LiveTrade.figi = "paper_SBER"` даже для sandbox/real-сделок, хотя комментарий S5R closeout #9 требует реальный FIGI для матчинга позиций. При рестарте backend с активной real-сессией `_check_real_positions` строит `broker_figi_map` по настоящим FIGI брокера, ищет `trade.figi='paper_SBER'`, не находит и делает ложный вывод «позиция закрыта у брокера» — `trade.status='closed'` с `exit_price=0`, сессия уходит в паузу, хотя реальная позиция жива. Настоящий `TInvestAdapter.get_instrument_info` существует, но здесь не используется.

- **Рекомендация:** Для sandbox/real получать FIGI через реальный брокерский адаптер (или MarketDataService/кэш instruments), `PaperBrokerAdapter` использовать только при `mode='paper'`. Как минимум — не записывать заглушечный `paper_*` FIGI в сделки небумажных режимов.

#### 🟠 Проглоченный `except Exception` при получении lot_size — молчаливый fallback на 1 даёт 10-кратный оверсайз позиции — `backend/app/trading/engine.py:938`

- **Категория:** качество кода / потенциальный баг  |  **Верификация:** — не проверялось

- **Проблема:** В `process_signal`: `except Exception: lot_size = 1` — без единой строки лога. При недоступности источника lot_size (T-Invest/ISS упали, сеть, битый кэш) расчёт размера позиции для `fixed_sum` считает `cost_per_lot = price × 1` вместо `price × 10` (для SBER, GAZP и большинства акций MOEX). Пример: sizing 100 000 ₽, SBER по 300 ₽, реальный лот 10 — корректно 33 лота (~99 000 ₽), при fallback — 333 лота (~999 000 ₽), то есть 10-кратный перерасход реальных денег без следа причины в логах. Аналогичные молчаливые проглатывания есть в engine.py:932-933 (figi), engine.py:1514-1515, service.py:448-449, 575-576, 586-587.

- **Рекомендация:** Логировать каждое такое исключение (`logger.error` с ticker и session_id). Fallback на `lot_size=1` для расчёта размера позиции недопустим — при неудаче получения lot_size пропускать сигнал (`return None`) с публикацией `order.error`, а не торговать на заведомо неверном множителе.

#### 🟠 IDOR: пауза/возобновление чужой торговой сессии без проверки владельца — `backend/app/trading/router.py:102`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `PATCH /sessions/{session_id}/pause` и `/resume` вызывают `service.pause_session(session_id)`/`resume_session(session_id)` без `user_id`. Методы сервиса и `TradingSessionManager` резолвят сессию через `_get_session` по `session_id` без фильтра владельца. Атакующий, перебирая `session_id`, может поставить на паузу чужую активную сессию (жертва перестаёт получать сигналы/сделки) либо возобновить приостановленную жертвой сессию (несанкционированный перезапуск live-торговли на реальном счёте).

- **Рекомендация:** Пробросить `current_user.id` в `pause_session`/`resume_session` и добавить owner-check через JOIN `StrategyVersion → Strategy.user_id` (как в `delete_session`), `NotFoundError` при чужой сессии.

#### 🟠 IDOR-чтение: раскрытие всех сделок чужой сессии (цены, объёмы, P&L) — `backend/app/trading/router.py:189`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `GET /sessions/{session_id}/trades` вызывает `service.get_trades(session_id=...)` без `user_id`. `get_trades` фильтрует `LiveTrade` только по `session_id`, ownership не проверяется. Атакующий, перебирая `session_id`, получает полную историю чужих сделок с чувствительными полями: `entry_signal_price`, `entry_price`, `exit_price`, `volume_lots`, `volume_rub`, `pnl`, `pnl_pct`, `broker_order_id`, `stop_loss`, `take_profit`. Соседние методы (`get_positions`, `close_position`, `close_all_positions`) этот фикс уже получили (S7R-SECURITY), `get_trades` — нет.

- **Рекомендация:** Добавить `current_user.id` в `get_trades` и предварительно проверять принадлежность сессии (JOIN на `Strategy.user_id`), как в `get_positions`/`get_session`; `NotFoundError` при несоответствии.

### 🟡 Medium

#### 🟡 N+1 и загрузка всех сделок в память в `get_sessions` — 4-5 запросов на каждую сессию списка — `backend/app/trading/service.py:309`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Для каждой из до 200 сессий в цикле выполняются: `_get_strategy_name` (JOIN-запрос), `_get_session_pnl` (SUM-запрос), `_fill_session_card_data` — `SELECT *` всех `LiveTrade` сессии без лимита только ради подсчёта win/loss, плюс `_get_last_price` и `MarketDataService.ensure_lot_size`. У пользователя с 50 сессиями, часть из которых с тысячами сделок, `GET /sessions` выполняет 200+ SQL-запросов и грузит десятки тысяч строк на каждый рендер списка; на SQLite это блокирует WAL и увеличивает latency остальных запросов, включая hot path обработки свечей.

- **Рекомендация:** Заменить per-session запросы одним агрегатным: `SELECT session_id, COUNT(*), SUM(CASE...), SUM(pnl) FROM live_trades WHERE session_id IN (...) GROUP BY session_id`; strategy_name — тем же батч-JOIN'ом, что уже сделан для `user_id`; последнюю цену тикеров — одним запросом по множеству тикеров.

#### 🟡 `PositionTracker` — мёртвый код с устаревшей логикой (PnL без lot_size, N+1 в цикле) — `backend/app/trading/engine.py:1788`

- **Категория:** качество кода (пересекается с находками по paper-учёту средств)  |  **Верификация:** — не проверялось

- **Проблема:** `PositionTracker` инстанцируется в `TradingService.__init__`, но ни один из его методов (`update_position`, `calculate_unrealized_pnl`, `on_order_filled`) не вызывается в production-коде — только в тестах (⚠️ NOT CONNECTED). При этом логика внутри разошлась с актуальными правилами модуля: `calculate_unrealized_pnl` считает PnL без `lot_size` (та же ошибка «занижение в 10×», уже исправленная в других местах) и делает запрос `TradingSession` внутри цикла по trade'ам (N+1). `on_order_filled` ведёт учёт `PaperPortfolio` по семантике, противоречащей `PaperBrokerAdapter.place_order`. Риск: следующий DEV «подключает» готовый на вид класс и реинтродуцирует lot_size-баг в расчёт денег.

- **Рекомендация:** Удалить `PositionTracker` целиком (вместе с полем `service.position_tracker`) либо, если он планируется для real-mode fill-callback'ов, привести формулы к актуальным (lot_size, единый учёт портфеля) и подключить вызовом из production-кода.

#### 🟡 `volume_rub` при fill от брокера считается без lot_size — занижение в lot_size раз — `backend/app/trading/engine.py:1216`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** При создании сделки `volume_rub = signal.price × volume_lots × lot_size` (с явным комментарием «критично: при lot_size=1 сумма занижается в 10×»). Но после fill в `_submit_order_to_broker` (строка 1216, и polled-ветка 1275-1277) значение перезаписывается: `trade.volume_rub = fill_price × trade.filled_lots` — без `lot_size`, хотя `fill_price` по контракту W8j — цена за 1 акцию. Для sandbox/real сделки по SBER (лот 10) на 10 лотов по 300 ₽ получается `volume_rub=3 000` вместо 30 000 — искажаются отчёты по операциям и любые проверки лимита объёма позиции по `volume_rub`.

- **Рекомендация:** В обеих ветках `_submit_order_to_broker` считать `volume_rub = fill_price × filled_lots × lot_size` (lot_size уже получен выше в `process_signal` — пробросить параметром). Аналогично поправить `PositionTracker`, если его подключат.

#### 🟡 `_apply_close` считает PnL по `volume_lots` вместо `filled_lots` — завышение при частичном исполнении — `backend/app/trading/risk_monitor.py:361`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `lots = trade.volume_lots or 0`, хотя реально исполнено `filled_lots` (может быть меньше при `partially_filled`). Если заказано 10 лотов, исполнено 6 — при закрытии по SL/TP или вручную PnL считается на 10 лотов, искажение результата на 67%, попадает в `LiveTrade.pnl`, `DailyStat` и статистику сессии. При этом закрывающий ордер брокеру в `close_position` шлётся на `filled_lots` — количество в ордере и в формуле PnL расходятся.

- **Рекомендация:** В `_apply_close` использовать `lots = trade.filled_lots or trade.volume_lots or 0` — единообразно с количеством в закрывающем ордере.

#### 🟡 Timeout поллинга закрытия sandbox/real провоцирует повторный ордер и незапланированный шорт — `backend/app/trading/engine.py:1616`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** При `response.status='placed'` и таймауте поллинга (5 сек) бросается `ValidationError`, trade остаётся `'filled'`, но закрывающий market-ордер уже отправлен брокеру и с высокой вероятностью исполнится. Ничто не связывает этот ордер со сделкой: `broker_order_id` закрывающего ордера не сохраняется, recovery-механизм ищет только pending-сделки. Пользователь видит ошибку, позиция в UI остаётся «открытой», при повторном нажатии «Закрыть» уходит второй market-sell — непреднамеренная короткая позиция на реальном счёте. Даже без повтора сделка навсегда остаётся `filled` при уже закрытой у брокера позиции.

- **Рекомендация:** Сохранять `broker_order_id` закрывающего ордера (поле `close_order_id`) и переводить сделку в промежуточный статус `'closing'`; periodic recovery доводит `'closing'` до `closed` по `get_order_status`. Повторный close для `'closing'` — отклонять с понятным сообщением.

#### 🟡 SignalProcessor создаётся заново на каждую свечу — кеш стратегий мёртв, `parse_blocks` выполняется дважды за свечу — `backend/app/trading/runtime.py:1313`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_handle_candle` на каждой закрытой свече создаёт новый `SignalProcessor(db)`, поэтому его RAM-кеш `_strategy_cache` никогда не даёт попаданий — мёртвая оптимизация. На interpreter-пути `parse_blocks` вызывается дважды за свечу (в `_has_meaningful_blocks` и затем в `_interpreter_process_candle`), `StrategyVersion` загружается из БД каждый раз. При 5-10 активных сессиях на таймфрейме 1m на каждом закрытии бара выполняются лишние SELECT и двойной JSON-парсинг `blocks_json` в hot path с задекларированным бюджетом <500ms.

- **Рекомендация:** Держать `SignalProcessor` как поле `_SessionListener`/`SessionRuntime` с инвалидацией кеша по `strategy_version_id`; парсить IR один раз — `_has_meaningful_blocks` может возвращать сам распарсенный `StrategyIR` вместо bool.

#### 🟡 Дублирование `_resolve_broker_adapter` + connect/disconnect брокера на каждый orphan-trade — `backend/app/trading/runtime.py:684`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `SessionRuntime._resolve_broker_adapter` — почти построчная копия `OrderManager._resolve_broker_adapter`. Расхождение уже началось: версия в engine.py логирует каждую причину отказа, версия в runtime.py возвращает `None` молча. Доработка резолва в одной копии рискует не попасть во вторую — recovery и торговля начнут вести себя по-разному. Дополнительно `_recover_orphan_pending_trades` для каждого orphan-trade создаёт новый `TInvestAdapter`, делает connect и disconnect — при N застрявших сделках одной сессии это N gRPC-подключений каждые 60 секунд.

- **Рекомендация:** Вынести резолв адаптера в одну функцию (например, `app/broker/adapter_factory.py`); в recovery-цикле группировать orphan-trades по `broker_account_id` и переиспользовать одно подключение на группу.

#### 🟡 `_submit_order_to_broker` и `close_position` — методы по 200+ строк с продублированными ветками обработки fill — `backend/app/trading/engine.py:1134`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_submit_order_to_broker` (~220 строк) содержит две почти идентичные ветки «filled сразу» и «placed → poll → filled», обе повторяют один блок (`status='filled'`, `entry_price`, `filled_lots`, `volume_rub`, `_attach_sl_tp`, commit, refresh, publish). `close_position` (~225 строк) дублирует ту же логику третий раз. При следующей правке контракта T-Invest (как уже было с W8j per-share vs total) исправление вносится в одну из трёх копий, остальные продолжают писать неверную цену — это уже происходило исторически (серия hotfix'ов W8d/W8g/W8j).

- **Рекомендация:** Выделить приватные helpers `_resolve_fill_price(adapter, account_id, response)` и `_mark_trade_filled(trade, session, price, qty)`. Обе ветки и `close_position` должны вызывать их, а не копировать код.

#### 🟡 `SessionRuntime.stop` не отписывает market-стрим — утечка gRPC-подписок T-Invest — `backend/app/trading/runtime.py:399`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `start()` вызывает `stream_manager.subscribe(ticker, timeframe)`, но `stop()` отписывает только EventBus-подписку listener'а; `stream_manager.unsubscribe` не вызывается нигде, кроме `unsubscribe_all` при shutdown backend. При запуске/остановке сессий по 10 разным тикерам/ТФ за день все 10 gRPC-стримов продолжают жить и публиковать `candle.update` в пустые каналы до рестарта backend — лишние соединения, расход rate-limit T-Invest, watchdog продолжает «лечить» никому не нужные стримы. При повторных pause/resume утечка накапливается.

- **Рекомендация:** В `stop()` проверять, остались ли другие активные listener'ы на ту же пару (ticker, timeframe), и если нет — вызывать `stream_manager.unsubscribe(ticker, timeframe)`. Как минимум добавить refcount в `MarketDataStreamManager`.

#### 🟡 IDOR-чтение: агрегированная статистика (P&L, equity-кривая) чужой сессии — `backend/app/trading/router.py:221`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `GET /sessions/{session_id}/stats` вызывает `service.get_stats(session_id)` без `user_id`. `get_stats` грузит сессию и closed-сделки только по `session_id`, ownership-проверки нет. Атакующий, перебирая `session_id`, получает `net_pnl`, `net_pnl_pct`, `win_rate`, `profit_factor`, `max_drawdown` и полную equity-кривую чужой сессии — раскрытие финансовой результативности других пользователей.

- **Рекомендация:** Пробросить `current_user.id` в `get_stats` и добавить owner-check по `Strategy.user_id` перед выборкой статистики; `NotFoundError` при несоответствии.

### 🔵 Low

#### 🔵 Мёртвая функция `_condition_to_expr` — не вызывается нигде — `backend/app/trading/engine.py:31`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Модульная функция (строки 31-71) не имеет ни одного вызова в кодовой базе. Внутри — логика, которая при «оживлении» станет багом: операторы `crosses_above`/`crosses_below` молча маппятся на простые `>`/`<` без учёта предыдущего бара; нераспознанное значение справа молча заменяется на `"0"`. Разработчик, нашедший функцию по имени и использовавший её для конвертации condition-блоков, получит стратегию, сигналящую на каждой свече выше уровня вместо момента пересечения.

- **Рекомендация:** Удалить функцию. Если семантика `crosses_above`/`crosses_below` нужна — реализовать её в едином интерпретаторе (`app/strategy/evaluator.py`) с доступом к предыдущему значению.

#### 🔵 Подсчёт позиций через `len(list(SELECT *))` и отдельная DB-сессия на каждую торговую сессию в snapshot — `backend/app/trading/ws_sessions.py:64`

- **Категория:** качество кода (пересекается с багом молчаливого проглатывания исключений в WS-цикле)  |  **Верификация:** — не проверялось

- **Проблема:** `_serialize_session` загружает все открытые `LiveTrade` строки и считает `len(list(...))` вместо `SELECT COUNT(*)`, а вызывающий код открывает новую `AsyncSession` на каждую сессию пользователя. При переподключении WebSocket пользователем с 10 сессиями (frontend делает reconnect автоматически) выполняется 20+ запросов и 10 открытий сессий БД; при нестабильной сети reconnect-шторм создаёт заметную нагрузку на SQLite. Дополнительно `except (asyncio.CancelledError, Exception): continue` молча проглатывает любые ошибки чтения из очереди без лога, а после ошибки задача для канала не пересоздаётся — события `trades:{session_id}` перестают доходить до клиента до реконнекта незаметно для пользователя.

- **Рекомендация:** Использовать `select(func.count())` для `positions_count`, собирать snapshot всех сессий в одной DB-сессии агрегатными запросами (`GROUP BY session_id`); в главном цикле логировать неожиданные исключения и пересоздавать задачу очереди (`queue_tasks[asyncio.create_task(queue.get())] = (channel, queue)`) перед `continue`.

#### 🔵 Мёртвые/рассинхронизированные константы статусов; статусы — magic strings по всему модулю — `backend/app/trading/schemas.py:14`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `VALID_MODES`/`VALID_STATUSES`/`VALID_SIZING_MODES`/`VALID_DIRECTIONS`/`VALID_ORDER_TYPES`, а также схемы `SessionFilterParams`, `TradeFilterParams` и `DailyStatResponse` не используются нигде (валидация идёт через `Literal`-типы). При этом `VALID_STATUSES = ("active", "paused", "stopped")` не содержит реально существующий статус `"suspended"`. Если разработчик применит `VALID_STATUSES` для валидации фильтра `?status=`, suspended-сессии станут недоступны для выборки/удаления. Статусы разбросаны по модулю строковыми литералами без единого Enum — опечатка не ловится ни pyright, ни тестами.

- **Рекомендация:** Удалить неиспользуемые константы и схемы либо ввести `StrEnum SessionStatus`/`TradeStatus` в `models.py` и использовать его во всех сравнениях и `Literal`-типах (включая `"suspended"`).

#### 🔵 Путь маркера shutdown захардкожен относительным `Path('data/.last_shutdown_at')` — `backend/app/trading/runtime.py:72`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_LAST_SHUTDOWN_MARKER` — относительный путь, зависящий от CWD процесса, не вынесенный в config. Если backend запущен из другого каталога (systemd unit, docker-контейнер, запуск uvicorn из корня репо), маркер пишется/ищется в другом месте: `_read_shutdown_marker` возвращает `None`, `restore()` уходит на признанный багованным fallback `_get_last_active_time`, пользователь получает ложное уведомление о простое либо не получает нужное. Ошибка проявляется тихо.

- **Рекомендация:** Вынести путь в `app/config.py` (Settings) и строить его от директории данных БД, а не от CWD — например, `settings.DATA_DIR / '.last_shutdown_at'`.

#### 🔵 `PaginatedResponse.items: list` — нетипизированный ответ, response_model не валидирует элементы — `backend/app/trading/schemas.py:257`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Роутер кладёт в `items` результат `item.model_dump()`. FastAPI `response_model` не проверяет и не документирует структуру элементов: в OpenAPI `/sessions` и `/trades` элементы имеют тип «any», фронтовый codegen не получает контракт. При переименовании поля на бэке ответ проходит валидацию, OpenAPI не меняется, фронт ломается только в рантайме. Ручной `model_dump()` без `mode='json'` отдаёт datetime объектом, минуя `field_serializer iso_utc` с Z-суффиксом у `TradeResponse`, который специально добавляли в W8f.

- **Рекомендация:** Сделать `PaginatedResponse` дженериком (`class PaginatedResponse(BaseModel, Generic[T]): items: list[T]`); в роутере возвращать `PaginatedResponse[SessionResponse]` с самими объектами без ручного `model_dump()`.

#### 🔵 `DailyStat` использует `date.today()` в таймзоне сервера вместо Europe/Moscow — `backend/app/trading/engine.py:1758`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `_update_daily_stat` (и аналогичный метод в `risk_monitor.py:296`) берут `date.today()` — локальную дату сервера. В Docker-продакшене (UTC) сделки вечерней сессии MOEX после 00:00 MSK запишутся в другой торговый день, чем видит пользователь в МСК; дневная статистика и расчёты дневного P&L (включая проверки Circuit Breaker по дневному убытку) смещаются на границе суток. На машине заказчика (уже в МСК) не воспроизводится — проявится именно на сервере.

- **Рекомендация:** Считать дату явно в МСК: `datetime.now(ZoneInfo('Europe/Moscow')).date()` в обоих местах, вынести в общий helper в `app/common`.

---

**Не проверено (вне скоупа/времени ревью, не является отклонённой находкой):** соседние модули `circuit_breaker`, `broker`, `notification` смотрели только в точках интеграции; наличие unit-тестов у `RiskMonitor` и recovery-логики `runtime.py` не проверялось; string-interpolation в `engine._blocks_to_sandbox/_execute_strategy` — потенциальная инъекция ограничена RestrictedPython-песочницей, эскалация за её границы не подтверждена; `settings.SECRET_KEY` имеет dev-дефолт с warning в проде (config.py:13) — отмечено ревьюером как затрагивающее WS-JWT, но отдельно не оценивалось.

Отклонённых при верификации находок (`verify_status=refuted`) в переданных данных нет.


---

## 13. Backend: стратегии (конструктор, шаблоны, индикаторы)

Проверены все 16 production-файлов `backend/app/strategy` (~5800 строк). Сильные стороны: `indicators.py`/`evaluator.py` чистые и документированные, `sizing.py` — образцовый «единый канон» формулы, авторизация и владение (ownership) реализованы последовательно, IDOR не обнаружен, SQL — только через ORM с bound-параметрами. Системная проблема блока — неконсолидированные слои эволюции: два несовместимых формата `blocks_json` (flat vs Blockly workspace) с рассинхронизированными детекторами, три кодогенератора (один мёртвый на 682 строки), четыре реализации маппинга имён параметров с разными базами имён и default-значениями — из-за этого «Применить к стратегии» из Grid Search для редакторских стратегий молча не меняет поведение бэктеста/live, а `evaluate()` (заявленная «единая точка истины») не применяет `time_filter` в live-торговле. Отдельно — критическая уязвимость исполнения кода: клиент может передать произвольный Python в `generated_code`, который в определённых условиях исполняется через `exec()` в обход blacklist AST-анализатора. Также отмечена деградация производительности дашборда (N+1 запросы + eager-загрузка тяжёлых Text-блобов версий на каждый список стратегий).

### 🔴 Critical

#### 🔴 Клиент передаёт произвольный Python в generated_code, который сервер исполняет через exec() — `backend/app/strategy/schemas.py:87`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `VersionCreate.generated_code` принимается как свободная строка от клиента (POST `/api/v1/strategies/{id}/versions`) и сохраняется без валидации (`service.py:417`). Поле задумано как сгенерированный сервером код, но API берёт его из тела запроса. При бэктесте `runtime_backtrader_code()` (`ir_codegen.py:160-173`) отдаёт этот код as-is как fallback, если `blocks_json` пуст/битый: достаточно прислать `blocks_json="{}"` (IR без entry/exit → регенерация пропускается) и произвольный `generated_code`. Код попадает в `_compile_strategy` (`backtest/service.py:113` → `engine.py:507-508`), где `compile()+exec()` выполняется в namespace с `bt`/`math`/`datetime`. Единственная защита — blacklist-анализатор `app/sandbox/ast_analyzer.py`, проверяющий `ast.Attribute`/`Name`, но не видящий доступ к атрибутам внутри строк/дандер-методов. При адверсариальной проверке прямой PoC через `str.format` с dunder не дал RCE напрямую (import `string` заблокирован, `eval` забанен), но найден рабочий альтернативный обход: dunder-метод как имя `FunctionDef` (`__init_subclass__`) не проверяется анализатором и автоматически вызывается при `exec()` — blacklist реально обходим, исполнение недоверенного клиентского кода подтверждено эмпирически.

- **Рекомендация:** Не принимать `generated_code` от клиента: генерировать код на сервере только из `blocks_json` через `ir_to_backtrader_code`. Убрать `generated_code` из `VersionCreate`/`VersionFromParamsCreate` либо игнорировать в `service.create_version`. Если fallback на stored-код нужен для legacy — перегенерировать при сохранении или пометить read-only. Исполнение перевести на allowlist-песочницу (RestrictedPython/подпроцесс с seccomp), т.к. blacklist AST обходится через дандер-методы/str.format.

### 🟠 High

#### 🟠 Два несовместимых формата blocks_json: «Применить из Grid Search» молча не меняет поведение бэктеста/live — `backend/app/strategy/router.py:244`

- **Категория:** баг (+ дефект качества архитектуры)  |  **Верификация:** ⚠️ не опровергнуто

- **Проблема:** В модуле сосуществуют две схемы `blocks_json`: flat-list (`{"blocks":[{"type":"indicator",...}]}` — её понимают `params.py`/`params_sync.py`) и реально сохраняемый фронтендом Blockly workspace (`{"blocks":{"languageVersion":0,"blocks":[{"type":"indicator_rsi","fields":{...}}]}}` — её понимает `ir.parse_blocks`). Детекторы рассинхронизированы: `has_meaningful_blocks` видит только flat, `parse_blocks` — только Blockly. Основной сценарий (версии из Blockly-редактора): IR-ветка не берётся; в legacy-пути `sync_blocks_params` получает dict вместо list, `walk_indicators` итерирует ключи словаря и ничего не патчит — новая версия получает патченный `generated_code`, но старые блоки. Бэктест (`runtime_backtrader_code` приоритизирует `blocks_json`) и live-интерпретатор (`trading/engine` → `evaluate` по IR) исполняют СТАРЫЕ параметры: юзер выбрал `rsi_period=18` в heatmap → создаётся версия «Применено из Grid Search: rsi_period=18», UI показывает 18 (читает `generated_code`), но каждый новый бэктест этой версии тихо гоняет `rsi_period=14` из старых блоков. Для `stop_loss_pct`/`take_profit_pct` даже warning не показывается — regex-патч `text_description` успевает, и параметр считается синхронизированным. Второй сценарий (flat-блоки): ветка берётся, но `parse_blocks(flat)` даёт пустой IR (`entry_signal` vs `signal_entry`) → `ir_to_backtrader_code` возвращает `_empty_strategy()`; при пустом `source.generated_code` сохранится placeholder «Empty strategy» — реальный код версии теряется, бэктест выполняет пустую стратегию без ошибки.

- **Рекомендация:** Выбрать единый канонический формат (Blockly workspace — его уже понимают IR/бэктест/live) и мигрировать `params.py`/`params_sync.py` на него: extract/replace параметров реализовать поверх `StrategyIR`. `has_meaningful_blocks` заменить на проверку через `parse_blocks` (как в `trading/engine.py`). Для flat-блоков — не заменять `generated_code`, если регенерация дала пустой IR. Добавить интеграционный тест: from-params на версии из редактора → новый параметр виден в regenerated runtime-коде.

#### 🟠 evaluate() игнорирует ir.time_filter — live/paper торговля торгует вне временного окна стратегии — `backend/app/strategy/evaluator.py:178`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** `evaluate()`/`evaluate_series()` не учитывают `ir.time_filter`. В бэктесте фильтр работает: `ir_codegen._gen_next` генерирует проверку временного окна, `parity.py:171` применяет `_in_window`. Но live-путь (`trading/engine.py:498-509`, `_interpreter_process_candle`) вызывает `evaluate(ir, candles)` напрямую и нигде не проверяет тайм-окно (grep `time_filter` по `app/trading` — 0 совпадений; SL/TP в live покрыты `risk_monitor`, `time_filter` — никем). При адверсариальной проверке подтверждено: `evaluator.py:178-228` считают только entry/exit, `time_filter` не читается; `ir.py:138,368-374` — отдельное поле IR, не встроенное в `Condition`; `ir_codegen.py:375-383` генерирует проверку в `next()`; `parity.py:171,182` вызывает `evaluate_series`, затем отдельно фильтрует через `_in_window`; `engine.py:481-524` вызывает `evaluate()` на строке 509 без аналогичной проверки. Сценарий: стратегия с блоком ФИЛЬТРЫ 10:00–14:00 успешно бэктестится с фильтром, но live/sandbox сессия открывает реальные сделки в 18:40 на низколиквидном вечернем рынке, которые стратегия по дизайну должна пропускать — расхождение backtest ↔ live с денежными последствиями.

- **Рекомендация:** Применять `time_filter` внутри `evaluate()`/`evaluate_series()` (модуль объявлен «единственной точкой истины») либо в `_interpreter_process_candle`: если время свечи вне окна — возвращать `'hold'`. Уточнить таймзону сравнения (Europe/Moscow) и покрыть тестом live-путь с фильтром.

#### 🟠 N+1 и eager-загрузка тяжёлых blob-полей на списке стратегий (дашборд) — `backend/app/strategy/models.py:45`

- **Категория:** качество (производительность)  |  **Верификация:** — не проверялось

- **Проблема:** `GET /api/v1/strategies` (`router.list_strategies`) в цикле вызывает `service.get_instruments_summary` для каждой стратегии — минимум 4 запроса на стратегию (version_ids, все бэктесты, сессии, сделки) плюс отдельный запрос к `OHLCVCache` на каждую пару (ticker, timeframe) в цикле. Дополнительно `Strategy.versions` объявлен с `lazy="selectin"` — любой `select(Strategy)`, включая `get_list`, автоматически подтягивает все версии с Text-столбцами (`blocks_json`, `generated_code`, `text_description`, `ai_chat_history`) — мегабайты данных, которые в ответе списка не используются; то же для `user` (`lazy="selectin"`). При 20 стратегиях и сотнях бэктестов дашборд генерирует 100+ SQL-запросов на каждый poll.

- **Рекомендация:** Убрать `lazy="selectin"` у `Strategy.versions`/`user` (явный `selectinload` там, где версии нужны — `get_by_id` уже делает это). Сводку собирать батчево для всех стратегий: один запрос по бэктестам с агрегатами/оконными функциями, один по сессиям, один по последним свечам (GROUP BY ticker, timeframe); выбирать только нужные колонки, а не ORM-объекты целиком.

### 🟡 Medium

#### 🟡 code_generator.py — 682 строки мёртвого кода, на который живые модули ссылаются как на эталон — `backend/app/strategy/code_generator.py:13`

- **Категория:** качество  |  **Верификация:** — не проверялось

- **Проблема:** Класс `CodeGenerator` не импортируется ни в одном production-файле: после BUG-31 генерация идёт через `ir_codegen.ir_to_backtrader_code`. Мёртвый файл содержит устаревшее поведение (`bt.indicators.Stochastic` slow вместо `StochasticFast`, без `safediv` — ровно те баги, что чинили в `ir_codegen`), а живые `params.py` и `params_sync.py` в докстрингах декларируют «конвенция ключей полностью совпадает с `code_generator._gen_params`» — синхронизируются с мёртвым эталоном, тогда как реальный генератор имеет другую конвенцию. Следующий разработчик с высокой вероятностью отредактирует не тот файл.

- **Рекомендация:** Удалить `app/strategy/code_generator.py` (история останется в git). Докстринги `params.py`/`params_sync.py` переписать на актуальный источник конвенции; саму конвенцию вынести в один модуль, из которого читают и кодоген, и extract/replace.

#### 🟡 Расхождение имён параметров: ir_codegen генерирует kind-based (bollinger_*), params/params_sync ждут name-based (bb_*) — `backend/app/strategy/ir_codegen.py:104`

- **Категория:** качество (+ баг применения Grid Search к BB-стратегиям)  |  **Верификация:** — не проверялось

- **Проблема:** `ir_codegen` строит имя переменной из IR-kind (`ref.kind` → `'bollinger'` → параметры `bollinger_period`/`bollinger_dev`), а `params.py`/`params_sync.py` — из `block.name` (`'BB'` → `bb_period`/`bb_dev`). Для стратегии с Bollinger Bands runtime-код экспортирует `bollinger_period`; Grid Search берёт имена из `generated_code` (`extract_strategy_params`, AST), фронт шлёт `{"bollinger_period": 18}` в POST `/versions/from-params`. Для flat-блоков в IR-ветке: `known_keys` из `extract_params_from_blocks` = `{bb_period,...}`, `requested` = `{bollinger_period}` → `isdisjoint` → `ValidationError 400` «параметры не найдены в блоках» — применить результат перебора к BB-стратегии нельзя; в legacy-пути параметр стабильно попадает в unsynced. Четыре параллельные реализации маппинга имён (`ir_codegen`, `params.py`, `params_sync`, мёртвый `code_generator`) гарантируют дальнейший дрейф.

- **Рекомендация:** Единый словарь «kind/имя индикатора → базовое имя + суффиксы + дефолты» в одном модуле (по схеме «единого канона» `sizing.py`), использовать во всех точках. Тест-инвариант: имена из `extract_strategy_params(ir_to_backtrader_code(ir))` совпадают с именами из `extract_params_from_blocks` для одного workspace.

#### 🟡 Разные default-периоды SMA/EMA в интерпретаторе (20) и кодогенераторе (14) — parity ломается по построению — `backend/app/strategy/evaluator.py:64`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `evaluator._series` для sma/ema берёт `p = _pi(ref.params, "period", 20)`, а `ir_codegen._gen_params` для тех же индикаторов подставляет `_pint(p, 'period', 14)`. Если блок SMA/EMA пришёл без явного PERIOD (шаблон/AI-генерация с неполными params), backtrader-код бэктеста посчитает SMA(14), а shadow-прогон интерпретатора и live-торговля — SMA(20): parity-сверка даст ложный mismatch, live-сигналы разойдутся с бэктестом. Прямое следствие дублирования магических дефолтов по модулям (ещё дубли: 12/26/9 для MACD, 14/3 для Stochastic, 20/2.0 для BB — в `ir_codegen`, `evaluator`, `params.py`, `code_generator`).

- **Рекомендация:** Вынести дефолты параметров индикаторов в единые константы и использовать их в `evaluator._series` и `ir_codegen._gen_params`/`_gen_init`. Добавить тест на равенство дефолтов между интерпретатором и кодогеном.

#### 🟡 IR-путь from-params: parse_blocks не читает flat-формат — generated_code может быть затёрт пустым placeholder'ом — `backend/app/strategy/router.py:276`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Ветка `if has_meaningful_blocks(...)` срабатывает только для flat-формата блоков (`type='indicator'`/`'stop_loss'`), но затем код регенерируется через `parse_blocks` (`ir.py`), который понимает только Blockly-типы (`signal_entry` ≠ `entry_signal`, `indicator_sma` ≠ `indicator`, `management_stop_loss` ≠ `stop_loss`). Для flat-блоков `parse_blocks` всегда даёт пустой IR → `ir_to_backtrader_code` возвращает `_empty_strategy()`: заявленная гарантия консистентности `blocks_json` ↔ `generated_code` не работает никогда. Lockstep-fallback спасает только если в `source.generated_code` есть распознаваемый `params = (...)`: иначе (рукописный/AI-код без params-тюпла) новая версия молча получает `generated_code = «Empty strategy»` — реальный код версии теряется, бэктест такой версии выполняет пустую стратегию с 0 сделок без какой-либо ошибки.

- **Рекомендация:** Конвертировать flat-блоки в IR отдельным адаптером перед `ir_to_backtrader_code`, либо не заменять `generated_code`, если регенерация дала пустой IR (entry/exit is None → безусловный текстовый fallback). Тест: from-params на flat-версии с кодом без params-тюпла не должен затирать код.

#### 🟡 delete() удаляет стратегию без проверки активных торговых сессий и бэктестов — висячие FK — `backend/app/strategy/service.py:368`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `delete()` каскадно удаляет `Strategy` и все `StrategyVersion`, но не проверяет, что на версии ссылаются `TradingSession` (в т.ч. активные live/sandbox) и `Backtest` (`strategy_version_id` nullable=False без ondelete). SQLite не проверяет FK по умолчанию, а `PRAGMA foreign_keys=ON` не включается — удаление проходит, оставляя dangling `strategy_version_id`. Сценарий: юзер удаляет стратегию с активной paper/live сессией → сессия остаётся `status='active'`, runtime на следующей свече не может загрузить версию (`_get_version` → None), сигналы молча перестают обрабатываться, открытая позиция остаётся без управления; история бэктестов ссылается на несуществующие версии.

- **Рекомендация:** В `delete()` запрещать удаление при наличии активных `TradingSession` (409 «остановите сессии») и либо каскадно чистить `Backtest`, либо архивировать (`status='archived'`) вместо физического удаления. Дополнительно включить `PRAGMA foreign_keys=ON` в connect-hook.

#### 🟡 Идемпотентность auto-snapshot сравнивает только blocks+code — правки описания молча теряются — `backend/app/strategy/service.py:553`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `_is_same_payload` сравнивает только `blocks_json` и `generated_code`. Если пользователь в течение 5 минут (AUTOSAVE_IDEMPOTENCY_WINDOW) после последнего сохранения правит только `text_description` или `parameters_json`, не трогая блоки, и сохраняет без комментария — `create_version` возвращает старую версию (idempotent-skip), новые `text_description`/`parameters_json` никуда не записываются. UI получает 201 и считает сохранение успешным; правка описания безвозвратно теряется при уходе со страницы. `text_description` — источник для AI-ассистента и синхронизации параметров, так что это тихая потеря пользовательских данных.

- **Рекомендация:** Включить `text_description` и `parameters_json` в `_is_same_payload`, либо при совпадении blocks/code, но отличии текста — обновлять поля последней версии in-place вместо тихого skip.

#### 🟡 Decimal утекает в blocks_json (старый формат + _parse_params_str) — фронт получает строки вместо чисел — `backend/app/strategy/block_parser.py:893` (доп. `:841`)

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В ref-формате порог сравнения сознательно приводится к float (Stack Gotcha 1: «Decimal сериализуется в JSON как строка и Blockly FieldNumber падает»). Но тот же класс бага остался в двух местах: (1) старый numbered/header-формат — `threshold = Decimal(match.group(3))` (строка 893) кладёт Decimal в `right.value`; (2) `_parse_params_str` (строка 841) парсит нецелые значения параметров индикаторов в Decimal — это основной путь и для текущего ref-формата: `[I1] BB(period=20, std_dev=2.5)` даёт `params={"std_dev": Decimal("2.5")}`. Pydantic v2 сериализует Decimal в JSON-строку → POST `/parse-template` возвращает `"std_dev": "2.5"` → `flatBlocksToWorkspace`/Blockly FieldNumber получает строку — ровно тот сбой загрузки редактора, который проект уже фиксировал в другой точке.

- **Рекомендация:** В `_parse_params_str` заменить `Decimal(value_str)` на `float(value_str)`; в `_parse_conditions` (строка 893) — `threshold = float(...)`. Точность здесь не критична — это параметры блоков, а не деньги.

#### 🟡 create_version_from_params: ~190 строк бизнес-логики и прямые запросы к БД в роутере — `backend/app/strategy/router.py:186`

- **Категория:** качество  |  **Верификация:** — не проверялось

- **Проблема:** Обработчик POST `/{strategy_id}/versions/from-params` содержит всю доменную логику: выбор source-версии прямыми `db.execute(select(StrategyVersion)...)` в обход сервиса (хотя `StrategyService._get_version_by_id` делает ровно то же — дублирование), ветвление IR/legacy, lockstep-supplement, построение diff, audit-маркера и comment. Импорты sqlalchemy/моделей внутри тела функции. Логику нельзя юнит-тестировать без HTTP-слоя и переиспользовать; любое изменение политики версионирования требует правки транспортного слоя, что нарушает принятую в проекте архитектуру router/service.

- **Рекомендация:** Перенести логику в `StrategyService.create_version_from_params(user_id, strategy_id, data) → (version, unsynced)`; в роутере оставить вызов сервиса и сборку `VersionResponse`. Выбор source-версии — через существующий метод сервиса (сделав его публичным).

#### 🟡 Неотфильтрованное поле source индикатора инъектируется в генерируемый Python-код — `backend/app/strategy/ir_codegen.py:250`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** В `_gen_init` `source` берётся из блока без whitelist: `src = str(p.get('source','close') or 'close')` (строка 225) и подставляется напрямую в код `self.data.{src}` (строки 250, 255). Значение приходит из поля SOURCE блока Blockly, полностью контролируется аутентифицированным пользователем через `blocks_json`. Аналогично имя переменной индикатора берётся из `ref.kind`, где `kind` — произвольный `type` блока при промахе `_IND_MAP`. Пример: `source="close) or PAYLOAD  #"` даёт синтаксически валидный код с внедрённым выражением, исполняемым в бэктест-движке. `evaluator._series` валидирует `source` по whitelist (open/high/low/close), а кодоген — нет: рассинхрон защиты. Эксплуатация ограничена тем же AST-анализатором (второй независимый путь инъекции в exec), поэтому severity medium, а не critical.

- **Рекомендация:** В `_gen_init` валидировать `source` по whitelist `{open,high,low,close}` (как в evaluator), иначе — `'close'`. Имя переменной строить только из фиксированного набора kind (`_BT_CLASS`/`_IND_MAP`); для неизвестного kind — отвергать блок или безопасный слог `ind_{n}`. Прогонять сгенерированный код через AST-анализатор и на этапе generate-code, а не только compile().

### 🔵 Low

#### 🔵 Роутер вызывает приватный метод сервиса service._get_version_by_id — `backend/app/strategy/router.py:434`

- **Категория:** качество  |  **Верификация:** — не проверялось

- **Проблема:** `get_strategy_version_by_id` обращается к подчёркнутому методу `StrategyService._get_version_by_id` напрямую. Приватный контракт сервиса становится зависимостью транспортного слоя: рефакторинг внутренностей (переименование/смена сигнатуры) молча ломает endpoint. Ownership-проверка размазана по двум вызовам (`get_by_id` + приватный метод) вместо одного метода сервиса.

- **Рекомендация:** Добавить публичный `StrategyService.get_version_by_id(user_id, strategy_id, version_id)` с ownership-проверкой внутри; роутер переключить на него.

#### 🔵 get_instruments_summary: 250-строчный метод возвращает кортеж из 6 позиционных значений — `backend/app/strategy/service.py:74`

- **Категория:** качество  |  **Верификация:** — не проверялось

- **Проблема:** Метод делает четыре разные вещи (агрегаты бэктестов с ручной медианой, сбор сессий, расчёт unrealized PnL, сборка строк) и возвращает `tuple[list, float|None, float, float, int, float|None]` — в роутере распаковывается шестью позиционными переменными. Перестановка/добавление элемента компилируется молча и меняет семантику полей (`total_abs` и `total_pct` — оба float). Сборка `InstrumentBacktest` payload продублирована дословно (строки 210-219 и 288-297).

- **Рекомендация:** Ввести dataclass/NamedTuple с именованными полями, вынести сборку `InstrumentBacktest` в helper, медиану заменить на `statistics.median`.

#### 🔵 parse_blocks молча оставляет только последний signal_entry/signal_exit из workspace — `backend/app/strategy/ir.py:340`

- **Категория:** качество  |  **Верификация:** — не проверялось

- **Проблема:** `_walk` перезаписывает nonlocal `entry`/`exit_` при каждом встреченном блоке `signal_entry`/`signal_exit`: workspace с двумя блоками входа (пользователь добавил второй сигнал в редакторе или шаблон с двумя строками «ВХОД ... КОГДА») молча теряет первый — без warning в лог и без предупреждения пользователю. Мёртвый блок остаётся в редакторе и создаёт ложное ощущение, что условие действует. То же для `management_stop_loss`/`take_profit`/`position_size` — последний побеждает.

- **Рекомендация:** При повторном `signal_entry`/`signal_exit`/`management_*` логировать warning со списком проигнорированных block id или возвращать warnings наружу (по аналогии с `ParseResult.warnings`). Альтернатива — объединять несколько условий входа через OR.

#### 🔵 Дублирование пайплайна парсинга между parse() и _parse_ref_format() (~80 строк) и дубли regex-констант — `backend/app/strategy/block_parser.py:256`

- **Категория:** качество  |  **Верификация:** — не проверялось

- **Проблема:** Резолв секций, warning про игнорируемые секции, назначение ID, резолв `__idx_`-ссылок и связывание сигнала с ближайшим условием реализованы дважды почти дословно (`parse`: строки 141-227; `_parse_ref_format`: 277-393). `PERCENT_PATTERN` и `TIME_RANGE_PATTERN` определены и в `TemplateParser`, и в `template_format_rules.py`; `INDICATOR_NAME_MAP` продублирован в обоих файлах. Фикс в одной копии (как уже случилось с Decimal→float) не попадает во вторую.

- **Рекомендация:** Вынести общие шаги (`resolve_sections`, `assign_ids`, `resolve_idx_refs`, `link_signals`) в приватные методы, используемые обоими форматами; regex-константы и `INDICATOR_NAME_MAP` оставить только в `template_format_rules.py`.

#### 🔵 Разные дефолты периода SMA/EMA: интерпретатор 20, кодоген 14 (дубль-упоминание в измерении bugs)

*См. medium-находку выше «Разные default-периоды SMA/EMA» — объединено.*

#### 🔵 Семантика crossover при равенстве серий отличается от bt.indicators.CrossOver — `backend/app/strategy/evaluator.py:139`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `_eval_crossover` считает пересечение вверх при `l0 <= r0 and l1 > r1`. backtrader `CrossOver` построен на `NonZeroDifference`: при `l0 == r0` знак берётся из последней ненулевой разницы. Сценарий: быстрая MA была выше медленной, коснулась её (равенство на баре i-1) и снова ушла вверх — интерпретатор (live) даёт сигнал buy, backtrader (бэктест) пересечения не видит. Расхождение live vs backtest и parity-шум на «касаниях»; с float-данными редко, но на круглых ценах низковолатильных бумаг встречается.

- **Рекомендация:** Повторить семантику `NonZeroDifference`: брать последний ненулевой знак разности (пробег назад до первого `l != r`) и фиксировать кросс только при смене знака, как в backtrader.

#### 🔵 Гонка на version_number: SELECT max()+1 без блокировки → IntegrityError 500 — `backend/app/strategy/service.py:405`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `create_version` и `_copy_as_new_version` вычисляют следующий номер через `select(max(version_number))` и вставляют `max+1`. Два конкурентных запроса (auto-snapshot из редактора + «Применить из Grid Search», или сохранение в двух вкладках) читают одинаковый max и оба вставляют один `version_number` → `UniqueConstraint uq_strategy_version` → необработанный `IntegrityError` → 500, пользователь видит «ошибка сохранения» без объяснения, транзакция сессии сломана.

- **Рекомендация:** Retry по `IntegrityError` (перечитать max и повторить) либо считать номер в самом INSERT через подзапрос `COALESCE(MAX(version_number),0)+1`.

---

**Примечание по измерениям:** ни одно из измерений (quality/bugs/security) не помечено `failed=true`, все три завершены полностью по заявленной области. Каждое измерение отдельно отметило непроверенные зоны вне лимита: грамматика `_split_logic` на вложенных скобках и фронтовая сторона `unsynced_params` (quality); таймзона свечей UTC/MSK в `time_filter` кодогена (bugs); `ast_analyzer.py` и `engine._compile_strategy` как зона песочницы, а также отсутствие rate-limit/`max_length` на `parse-template`/`generate-code` (security) — рекомендуется адресный ревью песочницы отдельным блоком.


> **⚠️ Уточнение при ручной верификации (важно).** Находка про исполнение пользовательского Python через `exec()` в этом блоке указывает файл/строку `strategy/schemas.py:87` — это **ошибка атрибуции**: там обычное Pydantic-поле `generated_code: str`, никакого `exec` нет. Реальное исполнение — в `backtest/engine.py:507` и `sandbox/executor.py`, и оно защищено эшелонированно (`ASTAnalyzer` + вычищенные builtins + белый список импортов), поэтому переклассифицировано с **Critical в High**. Точная формулировка и остаточный риск — см. раздел 3 (плашка «Переклассифицировано») и секцию 18 (sandbox). Остальные находки блока — в силе.


---

## 14. Backend: бэктест (движок, метрики, джобы)

Модуль `backend/app/backtest` (16 production-файлов, ~5.7k строк) архитектурно зрелый в расчётной части: Decimal на границах, ownership-проверки почти во всех REST-хендлерах, ретраи SQLite-локов, продуманный parity-гейт. Но слои нарушены — сервис фактически мёртв, вся бизнес-логика стянута в 1448-строчный `router.py`. Обнаружены два HIGH-дефекта с реальным пользовательским/безопасностным импактом: недостижимый `GET /backtest/jobs` (известная, но не исправленная Gotcha 20) и жёстко захардкоженный `direction="long"` в TradeRecorder, ломающий short-стратегии и parity-гейт. В измерении security подтверждены две HIGH-уязвимости: IDOR на мультиплексном WebSocket `/ws` (чужие каналы `backtest:{id}`/`trades:{session_id}`) и exec() пользовательского кода стратегии в основном процессе за ненадёжным денилист-фильтром. Прочие находки — дублирующиеся уведомления, N+1/selectin-перегрузка, мёртвый код (сервис, MetricsCollector, схемы), рассинхронизированные таблицы длительности таймфреймов и мелкие low-риски.

### 🔴 Critical

_(нет находок этой категории)_

### 🟠 High

#### 🟠 GET /backtest/jobs недостижим: маршрут перекрыт /{backtest_id}, эндпоинт возвращает 422 — `backend/app/backtest/router.py:1203`

- **Категория:** баг (дублируется как quality-находка) | **Верификация:** — не проверялось (verify_status=not_checked в обоих измерениях, но природа бага детерминирована и подтверждается кодом маршрутизации)
- **Проблема:** `@router.get("/{backtest_id}")` объявлен на строке 861, а `@router.get("/jobs")` — на строке 1203. Starlette матчит маршруты по порядку регистрации: запрос `GET /api/v1/backtest/jobs` попадает в `/{backtest_id}`, валидация int для строки "jobs" падает, и FastAPI возвращает 422, не пробуя следующие маршруты. Endpoint списка фоновых jobs — недостижимый код. Frontend реально его вызывает (`frontend/src/api/backtestApi.ts:179`, `listJobs` для бейджа фоновых бэктестов в шапке) и получает 422 на каждый опрос. Проблема известна команде и затикечена (S8R-FASTAPI-STATIC-JOBS-PATH, Gotcha 20), тест `test_router_full.py:472` закрепляет 422 как «известное поведение» (`assert in (200, 422)`), но production-код не исправлен. Публичный API-контракт S7 7.17 фактически сломан: восстановить список jobs после перезагрузки страницы через REST невозможно.
- **Рекомендация:** Переместить объявления `GET /jobs`, `GET /jobs/{job_id}` и `POST /jobs/{job_id}/cancel` ВЫШЕ всех маршрутов с `/{backtest_id}` (порядок регистрации в APIRouter решает конфликт), либо задать path-конвертер `/{backtest_id:int}`. После правки ужесточить assert в тесте до строгого 200 и закрыть тикет.

#### 🟠 TradeRecorder жёстко пишет direction="long" — short-сделки искажены и ложно блокируют live через parity-гейт — `backend/app/backtest/engine.py:101`

- **Категория:** баг | **Верификация:** ✅ подтверждено
- **Проблема:** В `notify_trade` при открытии сделки direction всегда `"long"`, хотя кодогенератор поддерживает short-стратегии (`ir_codegen.py:128,397` — `entry_direction="short"` генерирует `self.sell()`). Последствия: 1) в `BacktestTrade.direction` все сделки помечены `"long"` — UI/CSV/PDF показывают неверное направление; 2) `exit_price` восстанавливается по формуле long (`exit = entry + pnl/size`), для short правильно `exit = entry − pnl/size` — при прибыльном шорте показывается exit ВЫШЕ входа; 3) parity-гейт (`service._run_parity_check → compare_signals`) сравнивает direction из БД (`"long"`) с интерпретатором (`"short"`) — каждая пара даёт SIGNAL-расхождение "direction", допуск к которому не применяется → `parity_signals_match=False` → live-гейт (Task 14, `trading/service.py:155-157`) ложно блокирует ЛЮБУЮ short-стратегию. Направление определяется по знаку `trade.size` при открытии (у short он отрицательный). Цепочка воспроизведена по коду: `service.py:319` кладёт неверный direction в `BacktestTrade`; `parity.py:169-170,317-322,365,397-401` — расхождение строгого SIGNAL-класса без допуска.
- **Рекомендация:** В ветке `trade.isopen` определять направление по знаку размера: `"long" if trade.size > 0 else "short"` (или через атрибут `trade.long`). Формула `exit_price` уже ветвится по direction и станет корректной автоматически. Добавить тест: short-стратегия → `direction="short"`, `exit_price = entry − pnl/size`, parity без direction-расхождений.

#### 🟠 IDOR на мультиплексном WebSocket /ws: подписка на чужие каналы backtest:{id} и trades:{session_id} — `backend/app/backtest/ws.py:92`

- **Категория:** уязвимость | **Верификация:** ✅ подтверждено
- **Проблема:** После аутентификации по JWT `websocket_endpoint` принимает от клиента произвольную строку канала и вызывает `event_bus.subscribe(effective_channel)` (стр. 104) БЕЗ проверки владельца. Скоупится к пользователю только канал `notifications` (стр. 95-96); `backtest:{id}`, `trades:{session_id}`, `market:{...}` — нет. Сценарий: атакующий шлёт `{"action":"subscribe","channel":"backtest:123"}`, где 123 — id чужого бэктеста (id последовательны, легко перебрать), и получает `backtest.completed` (net_profit_pct, total_trades, sharpe_ratio — `router.py:315-324`) и `backtest.failed` (текст ошибки — `router.py:373-380`) чужого пользователя. Аналогично `trades:{session_id}` раскрывает сделки/позиции чужих торговых сессий — межарендная утечка финданных. Подтверждено: `event_bus.py:44-53` — pub/sub без авторизации; `ws_router` смонтирован в `main.py:359`, мидлвари на `/ws` нет. Отдельный защищённый `/ws/backtest/{job_id}` (`ws_backtest.py:107`) существует, но не устраняет уязвимость общего `/ws`.
- **Рекомендация:** Авторизовать канал при подписке: парсить префикс и проверять владельца по user_id (для `backtest:{id}` — цепочка backtest→version→strategy.user_id как в `_get_backtest_for_user`; для `trades:{session_id}` — владелец сессии). Либо публиковать в user-скоупленные каналы, либо вести allowlist на соединение. Отклонять подписку на неавторизованный канал.

#### 🟠 exec() пользовательского Python (generated_code) в основном процессе за денилист-фильтром — `backend/app/backtest/engine.py:508`

- **Категория:** уязвимость | **Верификация:** ✅ подтверждено
- **Проблема:** `_compile_strategy` исполняет `exec(compiled, namespace)` над кодом стратегии. Код берётся из `runtime_backtrader_code(blocks_json, generated_code)`: при пустом/битом `blocks_json` (нет entry/exit) идёт fallback на `version.generated_code` (`ir_codegen.py:160-173`), а `generated_code` — свободно задаваемое поле версии (`strategy/service.py:417`, `schemas.py:131`, принимается `POST /strategies/{id}/versions` без AST-проверки). Пользователь может создать версию с `blocks_json=''` и произвольным Python в `generated_code`, запустить бэктест — код исполняется в процессе бэкенда (`run_in_executor(None, ...)` — тред того же процесса, доступ к `SECRET_KEY`, `config.py:13`). Единственный барьер — денилист `ASTAnalyzer` (blacklist имён/модулей/дандеров) + частично урезанные builtins; денилист-песочницы для произвольного Python — известно ненадёжный паттерн. При обходе — кража SECRET_KEY (форж JWT → захват любого аккаунта) и брокерских токенов (реальная торговля). Тот же exec в `grid.py:301/319` внутри worker-процесса. Тесты `sandbox_escape.py` покрывают лишь простые обходы, не гарантируют полноты денилиста.
- **Рекомендация:** Не исполнять stored `generated_code` напрямую: для блочных стратегий генерировать код только детерминированно из IR и убрать fallback на произвольный `generated_code`. Исполнять бэктест в изолированном процессе без доступа к settings/токенам/сети/ФС (seccomp, ограничение ресурсов). Заменить денилист на allowlist AST, запретить объявление dunder-методов.

### 🟡 Medium

#### 🟡 Сервисный слой практически мёртв: логика продублирована в роутере, роутер вызывает приватный _save_result — `backend/app/backtest/service.py:74`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** `BacktestService.create_backtest`, `get_backtest`, `get_trades`, `get_equity_curve`, `delete_backtest`, `_get_strategy_version`, `_verify_ownership` нигде в production не вызываются (единственная инстанциация `BacktestService` — `router.py:311`, только ради приватного `_save_result`). `router.py` (1448 строк) заново реализует всё то же: ownership-проверки, пагинацию сделок, парсинг `equity_curve_json` (в трёх местах), удаление, плюс бизнес-логику (`_position_size_warning`, `_run_backtest_task`, `_prepare_grid_workload`, 220-строчный `_build_backtest_response`). Мёртвый sync-путь `service.create_backtest` расходится с боевым: не публикует события EventBus и не шлёт уведомления — если кто-то начнёт его использовать, получит молча другое поведение. Отдельно: `BacktestService.create_backtest` не передаёт `user_id` в `engine.run` — по политике S5R («T-Invest обязателен для backtest») это даёт `TInvestRequiredError` даже для пользователя с настроенным T-Invest; сейчас путь мёртв, но любой будущий вызов (AI-команды, интеграции) молча получит ложный отказ.
- **Рекомендация:** Выбрать один слой: перенести логику запуска/сборки ответа/валидаций из `router.py` в `BacktestService` (сделав `_save_result` публичным контрактом), а мёртвые дублирующие методы сервиса удалить или переиспользовать в роутере. При сохранении сервисного пути — передавать `user_id=user_id` в `engine.run` по аналогии с `_run_backtest_task`.

#### 🟡 N+1 запрос имён стратегий в list_backtests + lazy="selectin" на trades грузит все сделки всех бэктестов — `backend/app/backtest/router.py:488`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** Два источника избыточной нагрузки. 1) В `list_backtests` внутри цикла на каждый бэктест выполняется отдельный SELECT имени стратегии и версии (строки 488-492): 100 бэктестов — 101 запрос, хотя join уже есть в основном запросе. 2) `Backtest.trades` объявлен `lazy="selectin"` (`models.py:75-76`) — при загрузке списка SQLAlchemy автоматически догружает ВСЕ сделки ВСЕХ бэктестов (100 × 300 сделок = 30 000 строк в память) ради ответа, где сделки не используются. Каскад бьёт и по `get_backtest_trades`: страница из 50 `BacktestTrade` через selectin-связь `trade.backtest` подтягивает родительский `Backtest`, а тот через свой selectin — весь список сделок, т.е. пагинация ничего не экономит.
- **Рекомендация:** В `list_backtests` добавить `Strategy.name` и `StrategyVersion.version_number` в основной select и убрать цикл-запрос. `lazy="selectin"` заменить на `lazy="select"`/`"raise"` и грузить сделки явно через `selectinload` только там, где они нужны.

#### 🟡 Двойное уведомление «Бэктест завершён» для фоновых бэктестов, второе — с пустыми плейсхолдерами — `backend/app/backtest/jobs.py:237`

- **Категория:** баг (дублируется как quality-находка) | **Верификация:** — не проверялось
- **Проблема:** Логика уведомления продублирована в двух модулях и срабатывает дважды. Для `POST /backtest/run-async` runner (`_make_single_backtest_runner`) вызывает `_run_backtest_task` с `notification_service` из `app.state` — тот при успехе создаёт нотификацию (`router.py:333`). Затем `BacktestJobManager._run_job` после успешного runner'а вызывает `_notify_completed` (`jobs.py:237`), а manager создан в `main.py:109` с тем же `notification_service` — вторая нотификация. Ключи рассинхронизированы: `_notify_completed` ищет `result["metrics"]["pnl"]`/`result["pnl"]` и `params["strategy_name"]`, а runner возвращает `net_profit_pct`/`sharpe_ratio` и `job_params` без `strategy_name` (`router.py:1188-1198`) — пользователь видит второй тост вида «— (SBER, 1h): P&L —, Sharpe —».
- **Рекомендация:** Оставить одну точку отправки (логично — `_notify_completed` в менеджере), убрав передачу `notification_service` в `_run_backtest_task` из runner'а, и согласовать ключи result (читать `net_profit_pct`/`sharpe_ratio` либо возвращать `metrics.pnl`/`sharpe`).

#### 🟡 except Exception: pass без логирования при загрузке свечей в _build_backtest_response — `backend/app/backtest/router.py:783`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** Блок загрузки свечей для ответа `GET /backtest/{id}` (строки 750-784) обёрнут в `except Exception: pass` — без единой строки лога. Сценарий: `MarketDataService.get_candles` падает (T-Invest недоступен, сетевой сбой, битый кеш) — пользователь получает завершённый бэктест с пустым графиком (`candles=[]`, `trade_markers=[]`), а в логах ноль следов; диагностика сводится к гаданию. Кроме того, этот вызов выполняется на КАЖДЫЙ GET бэктеста — потенциально внешний сетевой запрос (T-Invest/ISS) в hot-path чтения записи, без таймаута на этом слое.
- **Рекомендация:** Минимум — `logger.warning("backtest_candles_load_failed", backtest_id=..., error=str(e))` вместо pass и сузить перехват. Лучше — вынести свечи в отдельный endpoint/параметр (`?include=candles`) или кешировать.

#### 🟡 Grid Search пиклит полную серию свечей на каждую комбинацию (до 1000 копий через IPC) — `backend/app/backtest/grid.py:407`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** `_drive_pool_sync` строит `indexed_payloads`, где каждый элемент через `_make_combo_payload` содержит ссылку на общий candles-список, но при отправке в `Pool` с `chunksize=1` каждый task пиклится целиком: полная OHLCV-серия сериализуется и гоняется через pipe на каждую из до 1000 комбинаций. Сценарий: intraday-бэктест 1m за год ≈ 100k свечей ≈ 10-20 МБ payload × 1000 комбинаций = десятки ГБ IPC-трафика и повторной десериализации в worker'ах — сериализация начинает доминировать над самим бэктестом.
- **Рекомендация:** Передавать candles/strategy_code один раз на worker через `Pool(initializer=..., initargs=(base_payload,))` с module-level переменной в worker'е, а через `imap` гонять только `(idx, params)`. Альтернатива — `multiprocessing.shared_memory`.

#### 🟡 GET /api/v1/backtest/jobs перекрыт маршрутом GET /{backtest_id} — эндпоинт возвращает 422 (дубль записи из измерения bugs)

_Объединено с находкой High "GET /backtest/jobs недостижим" выше — см. секцию High._

#### 🟡 Отмена фоновой job не останавливает вычисления и оставляет Backtest навсегда в running/queued — `backend/app/backtest/jobs.py:194`

- **Категория:** баг | **Верификация:** — не проверялось
- **Проблема:** `cancel()` делает `task.cancel()`: job помечается cancelled, но: 1) связанная запись Backtest не переводится в терминальный статус — остаётся running/queued до рестарта сервера (`reconcile_orphaned` только на старте), фронт бесконечно видит «выполняется»; 2) `cerebro.run` идёт в `run_in_executor` — поток нельзя прервать, он дорабатывает бэктест до конца, а `_progress_cb` продолжает публиковать progress-события отменённой job; 3) для grid-job отмена прерывает `await out_q.get` в `run_pool` (`grid.py:562`), но `_drive_pool_sync` и `multiprocessing.Pool` продолжают прогонять ВСЕ оставшиеся комбинации (до 1000 бэктестов CPU впустую), а поток executor'а, заблокированный на `out_q.get`, может зависнуть. Сценарий: пользователь ставит grid 1000 комбинаций и жмёт «Отменить» — сервер продолжает грузить все ядра ещё десятки минут.
- **Рекомендация:** В `except asyncio.CancelledError` дополнительно помечать связанный Backtest (backtest_id есть в `job.params_json`) статусом failed/cancelled. Для grid — передать в `_drive_pool_sync` `threading.Event` и при отмене вызывать `pool.terminate()`. Для одиночного бэктеста — флаг остановки, проверяемый в `ProgressAnalyzer.next` (raise для раннего выхода cerebro).

### 🔵 Low

#### 🔵 BacktestResponse/BacktestBenchmark — мёртвые схемы: endpoint возвращает рукописный dict без response_model — `backend/app/backtest/schemas.py:143`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** Схема `BacktestResponse` объявлена как контракт ответа `GET /backtest/{id}`, но endpoint (`router.py:861`) не имеет `response_model` и возвращает вручную собранный dict из `_build_backtest_response`. Схема уже разошлась с реальностью: в dict есть `warning`, `strategy_id`, `candles`, `trade_markers`, benchmark-как-dict, которых нет в `BacktestResponse`. Кто ориентируется на схему (OpenAPI-доки, генерация клиентов, новые разработчики), получает неверный контракт; валидация типов ответа не выполняется вовсе.
- **Рекомендация:** Либо довести `BacktestResponse` до фактического ответа и повесить `response_model` на endpoint, либо удалить мёртвые схемы, чтобы не вводить в заблуждение.

#### 🔵 MetricsCollector — мёртвый analyzer: регистрируется, но результат никогда не читается — `backend/app/backtest/engine.py:420`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** Analyzer `MetricsCollector` добавляется в cerebro (`engine.py:420`, `_name="metrics_collector"`), но `strat.analyzers.metrics_collector` нигде не читается — итоговая стоимость портфеля берётся напрямую из `cerebro.broker.getvalue()` (строка 242). Класс (`engine.py:65-83`) — мёртвый код, выполняющий работу на каждом прогоне и вводящий читателя в заблуждение об источнике метрик.
- **Рекомендация:** Удалить класс и строку `addanalyzer`, либо использовать его вместо прямого обращения к broker — одно из двух.

#### 🔵 avg_trade_duration_seconds жёстко = 0: колонка БД всегда пуста, ветка в router недостижима — `backend/app/backtest/metrics.py:89`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** `calculate_metrics` всегда присваивает `avg_duration_seconds = 0` («not available from bt directly»), хотя `TradeRecorder` в `engine.py` реально считает `duration_seconds` по каждой сделке — агрегат просто не вычисляется. `_save_result` сохраняет 0 в `Backtest.avg_trade_duration_seconds`, поэтому ветка `router.py:664` `if backtest.avg_trade_duration_seconds:` никогда не срабатывает и всегда используется грубая аппроксимация через `_tf_hours` по барам. Итог: мёртвая колонка + недостижимая ветка + менее точная средняя длительность сделки в UI, хотя точные данные уже собраны.
- **Рекомендация:** Считать `avg_trade_duration_seconds` как среднее по `duration_seconds` сделок `TradeRecorder` и передавать в `calculate_metrics`; либо удалить поле и ветку в router.

#### 🔵 Маппинг таймфрейм→длительность продублирован в трёх модулях и рассинхронизирован — `backend/app/backtest/router.py:659`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** Одна и та же таблица длительности бара существует трижды: `_tf_hours` инлайном в `_build_backtest_response` (`router.py:659`), `_TF_TO_SECONDS` в `export.py:77` и `TIMEFRAME_DURATIONS` в `market_data/service.py:21`. Наборы ключей уже разошлись: `export.py` содержит несуществующий в системе `"30m"`, но НЕ содержит поддерживаемый `"M"` — для месячного бэктеста колонка «Длит., баров» в CSV/PDF молча пустая (`bar_sec=None`), хотя `duration_seconds` есть. Router для неизвестного таймфрейма молча подставляет 24h/бар. При добавлении нового таймфрейма придётся править три места.
- **Рекомендация:** Вынести единый источник (`TIMEFRAME_DURATIONS` из market_data или `app/common/timeframes.py`) и использовать в router и export, удалив локальные копии.

#### 🔵 Дублирование JWT-декодирования для WebSocket в ws.py и ws_backtest.py — `backend/app/backtest/ws_backtest.py:36`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** `_decode_token` (`ws_backtest.py:36-46`) и `_authenticate_ws` (`ws.py:20-37`) содержат идентичную логику: `jwt.decode` с SECRET_KEY/HS256, проверка `type=="access"`, `int(sub)`, одинаковый перехват исключений. При изменении схемы токенов (алгоритм, claims, ротация ключей) придётся править оба места; они могут разъехаться незаметно — тесты на один хендлер не покрывают второй.
- **Рекомендация:** Вынести общую функцию `decode_ws_token(token) -> int | None` в `app/middleware/auth.py` или `app/common` и использовать в обоих WS-хендлерах.

#### 🔵 datetime.utcnow() — deprecated в Python 3.12 и нарушает конвенцию UTC-aware дат — `backend/app/backtest/grid.py:466`

- **Категория:** качество кода | **Верификация:** — не проверялось
- **Проблема:** `grid.py` использует `datetime.utcnow()` (строки 466, 538, 625) — метод deprecated в Python 3.12 (проект на 3.12, DeprecationWarning в логах/тестах) и возвращает naive datetime, тогда как остальной модуль backtest (router, service, jobs) использует `datetime.now(timezone.utc)`. `started_at`/`finished_at` grid-результата получают naive ISO-строки без смещения — потребитель не может отличить UTC от локального времени.
- **Рекомендация:** Заменить все три вызова на `datetime.now(timezone.utc)`.

#### 🔵 Двойное уведомление «Бэктест завершён» для run-async: второе — с плейсхолдерами «—» (дубль записи из измерения quality)

_Объединено с находкой Medium "Двойное уведомление «Бэктест завершён»" выше._

#### 🔵 Комиссия в ответе API пересчитывается приближённо и расходится с фактической в БД/CSV — `backend/app/backtest/router.py:730`

- **Категория:** баг | **Верификация:** — не проверялось
- **Проблема:** `_build_backtest_response` игнорирует сохранённое `trade.commission` (реальная комиссия backtrader с разными нотионалами входа/выхода) и подставляет `commission = volume_rub × commission_pct/100 × 2`, считая обе ноги по нотионалу ВХОДА. Сценарий: вход 100 000 ₽, выход 120 000 ₽ при 0.05% — реально 50+60=110 ₽, UI покажет 100 ₽. CSV/PDF-экспорт (`export.py`) берёт значение из БД — пользователь видит разные комиссии в UI и экспорте одного бэктеста.
- **Рекомендация:** Использовать сохранённое значение: `float(tr.commission) if tr.commission is not None else <текущая аппроксимация как fallback>`.

#### 🔵 SharpeRatio=None превращается в 0.0 — искажение метрики и ранжирования Grid Search — `backend/app/backtest/metrics.py:69`

- **Категория:** баг | **Верификация:** — не проверялось
- **Проблема:** `bt.analyzers.SharpeRatio` возвращает `sharperatio=None` при недостатке периодов (короткий период, 0 сделок). `_to_decimal(None)` молча даёт `Decimal("0")` — в БД/UI отображается Sharpe 0.0000, неотличимый от честного нулевого. В Grid Search (`grid.py:346`) worker вернёт `sharpe=0.0` вместо None, и в `_finalize` такие комбинации сортируются ВЫШЕ комбинаций с реальным отрицательным Sharpe — верх heatmap могут занять комбинации без единой сделки, и пользователь «применит к стратегии» пустышку.
- **Рекомендация:** Прокидывать None до схемы/БД (`sharpe_ratio: Decimal | None`); в grid-worker возвращать None — `_finalize` уже сортирует None как -inf. В UI показывать «n/a» вместо 0.

#### 🔵 Гонка между снапшотом job и подпиской на event_bus — терминальное событие может быть потеряно — `backend/app/backtest/ws_backtest.py:137`

- **Категория:** баг | **Верификация:** — не проверялось
- **Проблема:** Между чтением снапшота из БД (строки 94-125) и `event_bus.subscribe` (строка 137) есть окно в несколько await. Если job переходит в done/error именно в этом окне (быстрый бэктест, мгновенная ошибка), терминальное событие публикуется до подписки и теряется (in-memory event_bus не хранит историю): снапшот показал running, новых событий не будет — бейдж фоновых бэктестов вечно висит на «выполняется» до перезагрузки страницы.
- **Рекомендация:** Подписываться на канал ДО чтения снапшота (subscribe → снапшот → цикл) — событие из окна попадёт в очередь. После подписки перечитать статус и при терминальном сразу слать финальное событие.

#### 🔵 Инъекция в заголовок Content-Disposition через невалидированный ticker при экспорте — `backend/app/backtest/router.py:998`

- **Категория:** уязвимость | **Верификация:** — не проверялось
- **Проблема:** В `export_backtest` имя файла собирается как `filename_base = f"backtest_{backtest_id}_{backtest.ticker}"` и подставляется в `Content-Disposition: attachment; filename="{filename_base}.csv"` (стр. 989, 997-999, 1012-1014). `ticker` валидируется только по длине (`schemas.py:16`, max_length=20), без ограничения символов, и экспорт работает при любом статусе бэктеста (проверки status нет). Сценарий: создать бэктест с ticker вида `a";x="b` и вызвать экспорт — кавычка разрывает quoting имени файла в заголовке. Полный CRLF-сплиттинг блокируется h11, а воздействие ограничено собственным ответом атакующего (нужна аутентификация, свои данные) — отсюда low.
- **Рекомендация:** Санитизировать имя файла (оставить `[A-Za-z0-9_.-]`, усечь), либо кодировать по RFC 5987 (`filename*=UTF-8''...`). Добавить в `BacktestCreate` pattern для ticker (напр. `^[A-Z0-9.\-]{1,20}$`).

#### 🔵 Оракул существования: 403 вместо 404 для чужих версий/бэктестов — `backend/app/backtest/router.py:180`

- **Категория:** уязвимость | **Верификация:** — не проверялось
- **Проблема:** `_get_version_for_user` (стр. 180-181) и `_get_backtest_for_user` (стр. 208-209) для чужого СУЩЕСТВУЮЩЕГО ресурса бросают `ForbiddenError` (403), а для несуществующего — `NotFoundError` (404). Разница ответов позволяет перебором id различать существующие чужие strategy_version/backtest от несуществующих (enumeration). Это прямо противоречит комментарию в `get_strategy_params` (стр. 1439: «404... не leak'аем существование»). Импакт низкий, но нарушает заявленную модель.
- **Рекомендация:** Для чужих ресурсов возвращать тот же 404, что и для несуществующих (единый NotFoundError), чтобы не раскрывать существование чужих объектов.

---

Отклонено при верификации: находок со `verify_status=refuted` в предоставленных данных нет.


---

## 15. Backend: рыночные данные (стримы, свечи, алерты цен)

Модуль market_data в целом зрелый: Decimal соблюдён на ценовых путях, naive-UTC конвенция задокументирована, структурное логирование почти везде, есть ретраи и батч-коммиты. При этом найден системный клубок проблем: сервис управляет транзакциями чужой (injected) сессии в money-critical путях трейдинга, резолв T-Invest-аккаунта и таймфрейм/алерт-логика продублированы в 3-4 местах и уже разошлись, а lifecycle внешних клиентов (MOEXISSClient, MOEXCalendarService) не соблюдается. Обнаружены реальные дефекты: перманентный TypeError на bond-эндпоинтах после первого запроса, подмешивание недостроенной сегодняшней свечи в исторический бэктест (недетерминированный P&L), многократный overcount volume в live-агрегаторе (искажение данных для реальной торговли) и cross-user уязвимость, позволяющая любому пользователю ложно триггерить и гасить чужие ценовые оповещения произвольной исторической ценой. Дополнительно — cross-tenant риск переиспользования брокерского токена в singleton-стримах, race condition при параллельной подписке, утечки httpx-клиентов и вечные gRPC-подписки без отписки.

### 🟠 High

#### 🔴 Cross-user: GET /candles ложно триггерит и деактивирует чужие ценовые оповещения произвольной исторической ценой — `backend/app/market_data/router.py:139`

- **Категория:** уязвимость (объединено с багом «ложные срабатывания price alerts по исторической свече»)  |  **Верификация:** ✅ подтверждено

- **Проблема:** GET /candles после загрузки свечей вызывает `check_alerts_for_ticker_with_session(db, ticker, candles[-1].close)`, не проверяя, что запрошенный диапазон (`from`/`to`) относится к текущему моменту. В `_check_ticker` алерты выбираются только по `ticker + is_active`, БЕЗ фильтра `user_id` — проверяются оповещения ВСЕХ пользователей. Диапазон `from`/`to` полностью контролирует вызывающий (viewer-режим без T-Invest не требуется). Сценарий: любой аутентифицированный пользователь запрашивает `GET /candles?ticker=SBER&timeframe=D&from=2007-01-01&to=2008-05-01` — `candles[-1].close` становится историческим экстремумом. Все чужие алерты `above`/`below`, пороги которых укладываются в этот экстремум, срабатывают: `is_active=False`, уходит ложное уведомление владельцу, а настоящее срабатывание по актуальной цене больше никогда не произойдёт. Двумя запросами (на максимум и минимум цены) можно массово погасить чужие алерты по тикеру у всех пользователей — потеря реальных торговых сигналов.
- **Рекомендация:** Не проверять алерты из GET-эндпоинта на произвольном историческом диапазоне; проверять только когда `to_dt` близок к `now` и по реальной текущей цене (last price), в идеале — вынести проверку целиком в фоновый монитор по стрим-данным (аналогично figi-пути в multiplexer), убрав её из user-facing viewer-эндпоинта.

#### 🔴 MarketDataService коммитит/роллбэчит чужую (injected) сессию в hot-path'ах трейдинга — `backend/app/market_data/service.py:757`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Сервис получает `AsyncSession` через DI, но сам управляет транзакцией: `ensure_lot_size` (commit на 757, rollback на 760), `_save_to_cache` (пакетные commit на 646/648), `_purge_iss_cache` (commit на 207), `get_or_fetch_logo_isin` (853/864). При этом сервис вызывается с чужой сессией из `trading/engine.py:937`, `trading/service.py:447,585`, `trading/risk_monitor.py:257`, `trading/runtime.py:1509`. Сценарий: трейдинг-движок накапливает в сессии несохранённые изменения позиции, вызывает `ensure_lot_size` для расчёта P&L → TTL кэша истёк → апсерт lot_size и commit фиксируют половину unit-of-work трейдинга; если движок дальше падает и делает rollback — частичное состояние уже в БД. Обратный случай: rollback внутри `ensure_lot_size` стирает накопленные изменения вызывающего кода.
- **Рекомендация:** Убрать commit/rollback из методов, работающих на injected-сессии: либо `flush()` + управление транзакцией на уровне вызывающего кода, либо для внутренних кэш-апсертов (lot_size, logo, ohlcv_cache) открывать собственную короткоживущую сессию через `async_sessionmaker` (как делает prefetch.py), не трогая сессию запроса.

#### 🔴 TypeError aware-naive datetime: все bond-эндпоинты падают 500 при любом повторном запросе — `backend/app/market_data/bond_service.py:41`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** `get_bond_info` пишет в `BondInfoCache.updated_at` aware-datetime (`datetime.now(timezone.utc)`), но колонка — обычный `DateTime`; SQLite-диалект SQLAlchemy при записи молча отбрасывает tzinfo, а при чтении возвращает naive. На втором и каждом последующем запросе `age = datetime.now(timezone.utc) - cached.updated_at` вычитает naive из aware → `TypeError`. Исключение не перехватывается → `GET /bonds/{ticker}/info`, `/nkd` и `/coupons` отдают 500 навсегда после первого успешного запроса по тикеру (кэш-строка уже создана и не исчезает, unique по ticker).
- **Рекомендация:** Сравнивать в naive UTC: `now_naive = datetime.now(timezone.utc).replace(tzinfo=None); age = now_naive - cached.updated_at`. Аналогично писать `updated_at` как naive UTC (как уже делает `ensure_lot_size` в service.py, паттерн не унифицирован). Добавить тест на второй вызов `get_bond_info` с существующей кэш-строкой.

#### 🔴 _build_current_candle подмешивает сегодняшнюю недостроенную свечу в исторический диапазон, включая бэктест — `backend/app/market_data/service.py:151`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** Блок merge (строки 151–157) выполняется для 1h/4h при любом `mode` и не проверяет, что запрошенный `to_dt` близок к текущему моменту. Rebuilt-свечи строятся от `datetime.now()` и вливаются в результат без фильтра по `[from_dt, to_dt]`. Сценарий: бэктест (`backtest/engine.py:351`, `mode="backtest"`, tf=1h) за период 2025-01-01…2025-06-01 получает в конце массива 1–2 свечи за сегодня, одна из которых незакрытая. Auto-close позиции в конце диапазона исполняется по цене этой случайной свечи вне периода → мусорный и недетерминированный P&L (тот же класс проблемы, что чинился в BUG-18). Также ломает просмотр исторического окна графика.
- **Рекомендация:** Вызывать `_build_current_candle` только если `to_dt` покрывает текущий период (например, `to_dt >= _period_start(now, timeframe)`), и/или после merge фильтровать результат по `from_dt <= ts <= to_dt`. Для `mode="backtest"` достройку текущей свечи отключить полностью.

#### 🔴 Многократный overcount volume в live-агрегаторе из-за interim-обновлений незакрытой минутной свечи — `backend/app/market_data/stream_manager.py:84`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** Multiplexer подписывается через `SubscribeCandlesRequest` без `waiting_close` (`multiplexer.py:389`) → T-Invest шлёт промежуточные обновления текущей минутной свечи с кумулятивным объёмом минуты. `_AggregatingCandle.update()` на каждый callback делает `self.volume += candle.volume`, то есть кумулятивные снапшоты одной минуты суммируются повторно: обновления 100→250→400 дают вклад 750 вместо 400, и так каждую минуту. Агрегированные live-свечи 15m/1h/4h получают объём, завышенный в разы. Эти данные идут не только на график, но и в `SignalProcessor` live-торговли (через `trading/runtime.py`) — стратегии с volume-условиями генерируют ложные сигналы на реальных деньгах.
- **Рекомендация:** Хранить объёмы по-минутно: `dict[minute_ts] = candle.volume` (последний снапшот минуты замещает предыдущий), итоговый `volume = sum(dict.values())`. Либо подписываться с `waiting_close=True` для агрегируемых таймфреймов.

### 🟡 Medium

#### 🟠 MOEXISSClient создаётся на каждый запрос и никогда не закрывается — утечка httpx.AsyncClient — `backend/app/market_data/service.py:60`

- **Категория:** баг / качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `MarketDataService` и `BondService` инстанцируются per-request (роутеры, trading/engine, risk_monitor, prefetch), и каждый создаёт свой `MOEXISSClient` с внутренним `httpx.AsyncClient` (connection pool). Метод `close()` есть, но не вызывается нигде в market_data (закрывает клиента только `corporate_actions/service.py:249`). Сценарий: пользователь без T-Invest активно ищет инструменты и листает графики (viewer-fallback на ISS) — на каждый запрос остаётся незакрытый httpx-клиент с открытыми keep-alive сокетами до сборки мусора → рост числа дескрипторов, ResourceWarning, при долгой работе — исчерпание fd/пулов соединений.
- **Рекомендация:** Сделать `MOEXISSClient` процесс-синглтоном (модульный инстанс или `app.state` в lifespan с `aclose()` при shutdown) и внедрять его в `MarketDataService`/`BondService`, либо оборачивать использование в `async with` с гарантированным close.

#### 🟠 Проверка price alerts в GET /candles: бизнес-логика в роутере + `except Exception: pass` без логирования — `backend/app/market_data/router.py:142`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Роутер `/candles` сам достаёт monitor из `app.state`, конвертирует цену и вызывает `check_alerts_for_ticker_with_session` на request-сессии — бизнес-логика мониторинга алертов размазана в HTTP-слой. Ошибки гасятся голым `except Exception: pass` без логирования. Сценарий: `_check_ticker` начинает падать (например, после миграции схемы `PriceAlert` или на закрытой сессии) — ценовые оповещения молча перестают срабатывать для всех пользователей, а в логах пусто. Дополнительно commit внутри `_check_ticker` фиксирует request-сессию посреди обработчика (та же проблема владения транзакцией, что и в service.py).
- **Рекомендация:** Вынести проверку в сервисный слой/подписку на EventBus (как уже сделано для figi-пути в multiplexer), в роутере оставить максимум вызов одного метода. Минимум: заменить `pass` на `logger.warning(..., exc_info=True)`.

#### 🟠 subscribe_candle_stream: резолв BrokerAccount и расшифровка ключей в роутере, ошибки возвращаются как str(e) с HTTP 200 — `backend/app/market_data/router.py:208`

- **Категория:** уязвимость (объединено с находкой качества о нарушении границы слоёв)  |  **Верификация:** — не проверялось

- **Проблема:** Endpoint `POST /candles/subscribe` сам делает select по чужой модели `BrokerAccount`, вызывает `decrypt_broker_credentials` и держит plaintext-ключи в теле роутера — нарушение границы слоёв (та же логика резолва аккаунта уже есть в `MarketDataService._fetch_via_broker` и двух `_fetch_*_from_tinvest`). Финальный `except Exception as e: return {"channel": None, "source": "error", "message": str(e)}` превращает любую ошибку (включая ошибки дешифрования и gRPC) в успешный HTTP 200 с текстом исключения, уходящим на фронт — раскрытие внутренних деталей (типы объектов, конфиг, состояние адаптера) аутентифицированному клиенту. Сценарий: у stream_manager падает подписка (просроченный токен) — клиент получает 200 без канала, ретраев/алертинга нет, а message раскрывает детали инфраструктуры.
- **Рекомендация:** Вынести резолв аккаунта + расшифровку в метод сервиса (единый helper, переиспользуемый `_fetch_via_broker`), в роутере — только вызов и маппинг доменных исключений на HTTP-коды; `str(e)` наружу не отдавать, логировать через structlog.

#### 🟠 Дублирование: _fetch_isin_from_tinvest и _fetch_lot_size_from_tinvest — два почти идентичных метода (плюс ещё 2 копии резолва аккаунта) — `backend/app/market_data/service.py:871`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Оба метода (строки 765–822 и 871–945) повторяют один и тот же конвейер: select `BrokerAccount` с `ORDER BY is_sandbox` → проверка `encrypted_api_key`/`encryption_iv` → `decrypt_broker_credentials` → `AsyncClient` → `find_instrument` → поиск точного совпадения по тикеру; различаются только извлекаемым полем (lot vs isin). Тот же паттерн резолва аккаунта живёт в `_fetch_via_broker` и в `router.subscribe_candle_stream` — итого 4 копии. Фикс BUG-16 (учёт sandbox-аккаунтов) пришлось вносить в каждую копию отдельно; следующая правка политики выбора аккаунта с высокой вероятностью пропустит одну из копий, и поведение разойдётся.
- **Рекомендация:** Выделить helper `_resolve_tinvest_credentials() -> tuple[str, bool] | None` (токен + is_sandbox) и `_find_instrument_exact(ticker) -> Instrument | None`; оба метода свести к извлечению нужного поля из общего результата.

#### 🟠 Таймфрейм-машинерия продублирована между service.py и stream_manager.py и уже разошлась — `backend/app/market_data/service.py:333`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `TIMEFRAME_DURATIONS` (service.py:21) и `_TF_DURATION` (stream_manager.py:22) — идентичные словари; `_period_start` (service.py:333) и `_candle_period_start` (stream_manager.py:34) — почти идентичные функции выравнивания на начало периода. Дрейф уже случился: версия в service не обрабатывает `"1m"` и `"M"` (возвращает None), версия в stream_manager обрабатывает оба. При добавлении нового ТФ или изменении границы недели правка вносится в один файл — REST-агрегация текущей свечи и live-агрегация стрима начинают класть свечи в разные `period_start`, на графике появляются дубли/расщепление последней свечи.
- **Рекомендация:** Вынести словарь длительностей и функцию `period_start` в общий модуль (например `app/market_data/timeframes.py` или `app/broker/base.py` рядом с `CandleData`) и импортировать в обоих местах.

#### 🟠 _save_to_cache вставляет свечи по одной строке в цикле — десятки тысяч последовательных execute — `backend/app/market_data/service.py:606`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Для каждой свечи строится отдельный `INSERT ... ON CONFLICT` и выполняется отдельный `await self.db.execute()`. Сценарий: первый бэктест на 10-летнем диапазоне 15m (лимит `MAX_REQUEST_SPAN` теперь 3650 дней) — это ~130 000 свечей, то есть ~130 000 последовательных round-trip'ов в aiosqlite-поток; заполнение кэша занимает десятки секунд и удерживает event loop под нагрузкой.
- **Рекомендация:** Формировать один statement на пачку: `sqlite_insert(OHLCVCache).values([...N dict...])` с `on_conflict_do_update`/`do_nothing` (SQLite поддерживает multi-VALUES upsert), чанками по `_CACHE_COMMIT_BATCH`; либо `db.execute(stmt, list_of_params)` (executemany).

#### 🟠 _fetch_bond_from_iss обходит публичный API ISS-клиента: приватный _get_client(), без retry и без проверки статуса ответа — `backend/app/market_data/bond_service.py:78`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `BondService` лезет в приватный метод чужого класса `self._iss_client._get_client()` и делает сырые `client.get(...)` + `resp.json()`, минуя `MOEXISSClient._request`, где реализованы retry на 5xx и маппинг ошибок в `BrokerError`. Сценарий: MOEX ISS возвращает 503 с HTML-телом — `resp.json()` кидает `JSONDecodeError`, наружу уходит необработанный 500 вместо ретрая, который сработал бы для любого другого ISS-вызова проекта; при 404 по несуществующему тикеру код молча парсит пустую структуру и сохраняет в кэш облигацию-пустышку с `nominal=1000` на 24 часа.
- **Рекомендация:** Добавить в `MOEXISSClient` публичные методы `get_security_description(ticker)` и `get_bondization(ticker)`, реализованные через `_request` (retry + статус-коды), и использовать их из `BondService`; при отсутствии данных — доменное исключение, а не кэш дефолтов.

#### 🟠 is_stream_healthy читает приватные атрибуты адаптера через getattr — `backend/app/market_data/stream_manager.py:249`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Health-check watchdog'а построен на двойном `getattr` по приватным полям соседнего модуля: `entry.adapter._multiplexer` и `mux._stream_task`. Контракта нет — при любом рефакторинге broker/tinvest (переименование поля, смена структуры) `getattr` тихо вернёт `None`, `is_stream_healthy` начнёт всегда отдавать `False`, и watchdog будет на каждом тике рвать и пересоздавать живой стрим (unsubscribe → disconnect → subscribe), то есть ровно тот thrash, от которого предостерегает собственный docstring метода. Ошибка не проявится ни в тестах типов, ни в логах — только деградацией live-котировок.
- **Рекомендация:** Добавить в `TInvestAdapter` публичный метод/свойство `is_stream_alive()` (инкапсулирующий проверку задачи мультиплексера) и вызывать его из stream_manager; getattr-цепочку удалить.

#### 🟠 Trigger-логика алертов продублирована в check_alerts_for_figi и _check_ticker; check_alerts_for_ticker — мёртвый код — `backend/app/market_data/price_alert_monitor.py:40`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `check_alerts_for_figi` (строки 40–84) и `_check_ticker` (97–138) — две копии одного и того же цикла: select активных алертов → сравнение above/below → `is_active=False`, `triggered_at`, `_create_notification`, commit. Отличается только `WHERE` (figi vs ticker.upper()). Сценарий дрейфа: правка семантики срабатывания (например, «пересечение» вместо «>=», или повторные алерты) вносится в одну копию — live-стрим и REST начинают триггерить алерты по разным правилам для одного пользователя. Метод `check_alerts_for_ticker` (строка 92) в production-коде не вызывается вообще (только в тестах) — мёртвая обёртка.
- **Рекомендация:** Свести обе проверки к одному приватному методу `_check(db, where_clause, price)` с параметризованным фильтром; `check_alerts_for_ticker` удалить или пометить как test-only и убрать из публичного API.

#### 🟠 Третий экземпляр MOEXCalendarService в fallback-режиме: /market-status и /calendar не знают реальных праздников MOEX — `backend/app/market_data/router.py:35`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Модульный синглтон `_calendar_service` создаётся без `iss_client`, и `load_calendar` для него никогда не вызывается — `is_trading_day` работает по fallback'у «будни = торговые дни». Параллельно свои экземпляры создают `scheduler/service.py:45` и `broker/tinvest/multiplexer.py:43` (последний — новый объект на каждый вызов). Сценарий: официальный праздник MOEX в будний день (например 8 января) — `GET /market-status` и `/calendar` отвечают `is_trading_day=true` и показывают время до закрытия несуществующей сессии; «настоящий» календарь с данными ISS может жить в scheduler, но роутер к нему не подключён.
- **Рекомендация:** Создавать один `MOEXCalendarService` с ISS-клиентом в lifespan (`app.state.moex_calendar`), загружать календарь при старте и по расписанию; router, scheduler и multiplexer должны получать общий экземпляр через `Depends`/`app.state`.

#### 🟠 Race condition в subscribe: параллельные вызовы создают дублирующие адаптеры и подписки — `backend/app/market_data/stream_manager.py:132`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Между проверкой `if key in self._streams` (строка 132) и записью `self._streams[key] = ...` (строка 178) несколько await-точек (`adapter.connect`, `subscribe_candles`). Два конкурентных запроса на один `ticker:timeframe` (две вкладки браузера, либо HTTP-запрос + trading runtime) оба проходят проверку → создаются два адаптера и две подписки в multiplexer. Вторая перезаписывает первую в dict, но первая подписка остаётся жить в `multiplexer._routes`: каждая свеча публикуется в канал дважды, два агрегатора параллельно шлют конфликтующие candle.update (у каждого свой volume/open), отписаться от «потерянной» подписки уже невозможно до рестарта.
- **Рекомендация:** Добавить `asyncio.Lock` (per-key или общий) вокруг критической секции subscribe/unsubscribe/ensure_stream, либо повторно проверять key после await'ов и откатывать (unsubscribe+disconnect) проигравшую подписку.

#### 🟠 Cross-tenant переиспользование брокерского токена: стрим кэшируется по ticker:timeframe без привязки к пользователю — `backend/app/market_data/stream_manager.py:132`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `MarketDataStreamManager` — глобальный singleton, `_streams` ключуется только `_key(ticker, timeframe)` (строки 117–118), без `user_id`. В `subscribe()` при существующем ключе (строка 132) возвращается channel без создания нового стрима. Сценарий: пользователь A вызывает `POST /candles/subscribe` для SBER:1m — `_StreamEntry` с `TInvestAdapter` на расшифрованном токене A. Затем пользователь B подписывается на тот же SBER:1m — ключ есть, B получает данные стрима, работающего на токене A. Токен A расходует rate-limit и держит gRPC-соединение, обслуживая других (нарушение ToS брокера, риск бана/лимитов для владельца). `unsubscribe()`/`unsubscribe_all()` тоже глобальны: действие одного рвёт стрим у других.
- **Рекомендация:** Включить `user_id`/`account_id` в ключ `_streams`, чтобы каждый стримил на своём токене, либо явно ввести shared-pool на серверном токене. `unsubscribe` должен считать подписчиков и не рвать стрим, пока есть другие потребители.

#### 🟠 Фильтр «аукционных» свечей выбрасывает реальные doji-свечи без проверки объёма — `backend/app/market_data/service.py:141`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Для 1h/4h из результата удаляются все свечи с O=H=L=C, хотя комментарий говорит «при малом объёме» — проверки volume в коде нет. Для неликвидных инструментов (облигации, третий эшелон) час без изменения цены при ненулевом объёме — нормальная свеча; она молча пропадает из ответа, включая `mode="backtest"`/`"trading"` (фильтр применяется до merge, независимо от mode). Индикаторные окна (SMA/RSI) в бэктесте считаются по ряду с выкинутыми барами → смещённые сигналы и P&L, отличающийся от реальности.
- **Рекомендация:** Добавить условие по объёму (например, отбрасывать только при O=H=L=C И `volume == 0` или ниже порога), не применять фильтр в режимах backtest/trading, где полнота ряда важнее косметики графика.

#### 🟠 Стримы свечей никогда не отписываются: подписки накапливаются до рестарта приложения — `backend/app/market_data/router.py:161`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `POST /candles/subscribe` создаёт постоянную gRPC-подписку в stream_manager, но unsubscribe-endpoint отсутствует, а `stream_manager.unsubscribe` вызывается только из `unsubscribe_all` при shutdown (`main.py:269`). Сценарий: пользователь за день просматривает 30 тикеров/таймфреймов — 30 вечных подписок продолжают получать свечи и публиковать в event_bus каналы, которые никто не слушает. Растёт нагрузка на T-Invest stream (лимит подписок на соединение), CPU на агрегацию, и все «просмотренные» стримы держатся до перезапуска backend.
- **Рекомендация:** Добавить endpoint/механизм отписки (например, refcount по WebSocket-подписчикам канала: при нуле слушателей — `stream_manager.unsubscribe`), либо idle-TTL: фоновая задача снимает стримы без подписчиков дольше N минут (`last_event_at` уже есть в `_StreamEntry`).

#### 🟠 Незакрытая (текущая) свеча из T-Invest REST кэшируется как завершённая — `backend/app/market_data/service.py:595`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `_save_to_cache` пишет в `OHLCVCache` все свечи из `_fetch_candles`, включая последнюю формирующуюся (`get_historical_candles` в adapter не фильтрует `is_complete`). Из-за tail_tolerance (`_find_gaps`: D — 6ч, 4h — 4ч, 1h — 1ч) повторный запрос не дозапрашивает хвост, пока свеча «не постареет»: дневной график может показывать close, устаревший на несколько часов, из кэша. Для 1h/4h это маскируется `_build_current_candle`, но для D/W/M и 5m/15m отдаются устаревшие OHLCV; бэктест с `to_dt=сегодня` считает сигналы по неполной дневной свече.
- **Рекомендация:** Не сохранять в кэш свечу текущего (незавершённого) периода: перед `_save_to_cache` отрезать свечи с `timestamp >= _period_start(now, timeframe)`, либо фильтровать по `is_complete` на уровне адаптера и помечать хвост отдельным source.

### 🔵 Low

#### 🔵 Раскрытие внутренних деталей через str(e) в ответе (доп. к находке про subscribe_candle_stream) — `backend/app/market_data/router.py:209`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** В `subscribe_candle_stream` ветка except возвращает `{'channel': None, 'source': 'error', 'message': str(e)}`. Ошибка может прийти из `decrypt_broker_credentials`, `adapter.connect` или `stream_manager.subscribe` и содержать внутренние подробности (типы объектов, детали gRPC/конфига, состояние адаптера, ошибки расшифровки), которые попадают напрямую в HTTP-ответ аутентифицированному клиенту, упрощая разведку внутренней реализации.
- **Рекомендация:** Возвращать клиенту обобщённое сообщение, полный текст/traceback писать только в structlog. Не проксировать `str(e)` во внешний ответ.

#### 🔵 Отсутствие валидации формата ticker: значение подставляется в URL-путь запросов к MOEX ISS — `backend/app/market_data/router.py:106`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `ticker` в `/candles` — `Query(min_length=1, max_length=20)` без pattern, может содержать `/`, `..` и спецсимволы. Далее попадает в `MarketDataService._fetch_via_iss` → `MOEXISSClient.get_candles` → `f'/iss/engines/stock/markets/{market}/securities/{ticker}/candles.json'`. Значение вроде `SBER/../../../iss/other` изменяет путь запроса к iss.moex.com (httpx резолвит `..`), позволяя дёргать произвольные пути на фиксированном публичном хосте. Хост не меняется, API read-only и публичный — импакт ограничен, но подстановка ввода в URL-путь неконтролируема. Bond-эндпоинты тоже берут ticker как path-параметр без валидации и подставляют в `f'/iss/securities/{ticker}.json'` (`bond_service.py:79`).
- **Рекомендация:** Валидировать ticker строгим паттерном (например `^[A-Z0-9._-]{1,20}$`) на уровне Query/Path и `.upper()` перед использованием; отклонять символы вне алфавита тикеров MOEX до формирования URL.

#### 🔵 _purge_iss_cache: DELETE на каждый вызов get_candles и детекция ошибки по подстроке 'database is locked' — `backend/app/market_data/service.py:216`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** При активном T-Invest DELETE по `ohlcv_cache` выполняется на каждый `get_candles` (график, sparkline, runtime-циклы трейдинга) — лишний write-запрос в hot path, хотя после первой очистки ISS-записей для пары заведомо нет. Retry построен на `"database is locked" in str(e)` — хрупкое сравнение по тексту сообщения: обёрнутое или локализованное исключение не совпадёт со строкой, и запрос упадёт без ретрая; порядок sleep→rollback тоже сомнителен (сессия держит failed-транзакцию во время паузы).
- **Рекомендация:** Кэшировать в памяти множество уже очищенных пар (ticker, timeframe) на процесс, чтобы DELETE выполнялся один раз; ловить конкретно `sqlalchemy.exc.OperationalError` и делать rollback до sleep.

#### 🔵 _build_current_candle глушит все исключения без логирования — `backend/app/market_data/service.py:390`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `except Exception: return []` вокруг `_fetch_candles` — единственный except в модуле вообще без записи в лог. Сценарий: у пользователя протух T-Invest-токен → достройка текущей 1h/4h свечи молча перестаёт работать, график стабильно отстаёт на 5–30 минут, а в логах нет ни одного события, по которому это можно связать с ошибкой fetch'а.
- **Рекомендация:** Заменить на `except Exception: logger.warning("current_candle_rebuild_failed", ticker=ticker, timeframe=timeframe, exc_info=True); return []`.

#### 🔵 Фильтрация инструментов и ALLOWED_TYPES захардкожены в теле роутера, ошибки парсинга молча отбрасывают записи — `backend/app/market_data/router.py:224`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `GET /instruments` содержит бизнес-логику нормализации ответа ISS: множество `ALLOWED_TYPES` объявлено внутри функции (пересоздаётся на каждый запрос), маппинг полей secid/ticker/lotsize и `except (ValueError, TypeError): continue` живут в HTTP-слое. Сценарий: ISS отдаёт у части бумаг lotsize строкой с пробелом — записи молча выпадают из поиска без лога, пользователь не находит существующий тикер. Аналогичная нормализация ISS-полей уже есть в `get_instrument_info` — логика размазана по двум роутерам вместо сервиса.
- **Рекомендация:** Перенести нормализацию и фильтрацию в `MarketDataService.search_instruments` (вернуть уже типизированные объекты), `ALLOWED_TYPES` — в константу модуля/настройку, отбрасывание записи сопровождать `logger.debug` с сырой записью.

#### 🔵 _fetch_lot_size_from_tinvest/_fetch_isin_from_tinvest берут чужой токен без фильтра по user_id и в обход rate limiter — `backend/app/market_data/service.py:781`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Оба хелпера выбирают первый активный `BrokerAccount` по всей таблице (без user_id) и дёргают T-Invest напрямую через `AsyncClient`, минуя per-token `RateLimiter` адаптера. В многопользовательской установке запросы логотипов/лотности одного пользователя расходуют лимиты API-токена другого; при всплеске (страница со списком из десятков тикеров без закэшированных ISIN) возможен 429/RESOURCE_EXHAUSTED на токене, который параллельно используется live-торговлей владельца.
- **Рекомендация:** Прокидывать `user_id` и выбирать токен запрашивающего пользователя (fallback — ISS), а вызовы `find_instrument` вести через `TInvestAdapter` с его rate limiter'ом, либо через общий limiter по токену.

Отклонённых при верификации находок нет (verify_status=refuted не встречался).


---

## 16. Backend: уведомления (Telegram, Email, webhook)

Модуль notification в целом качественный и хорошо покрыт тестами: ownership-проверки (фильтр по user_id) в REST-эндпоинтах и в командах Telegram-бота (`/close`, `/closeall`, open_session) на месте, XSS в Telegram/email закрыт через `html.escape`, IDOR в REST не обнаружен. Главная системная проблема — `create_notification` удерживает write-транзакцию SQLite во время внешних сетевых вызовов (Telegram/SMTP до ~15–20 с), что в связке с single-writer SQLite создаёт риск `database is locked` для торгового движка; находка подтверждена адверсариальной проверкой по коду (`service.py`, `database.py`, `runtime.py`). Критическая security-находка — дефолтный пустой `TELEGRAM_WEBHOOK_SECRET` делает проверку вебхука fail-open, что при включённом боте позволяет неаутентифицированно исполнять команды бота (включая принудительное закрытие позиций) — также подтверждено. Дополнительно есть архитектурный долг: отсутствие unique-ограничения на `user_notification_settings` (самоподдерживающаяся потеря уведомлений), мёртвый дублирующий код в `dispatchers.py`, разрастание бизнес-логики broker/trading в `telegram_webhook.py` с дублированием и утечкой gRPC-соединения, а также воспроизведённая регрессия «P&L по цене без фильтра timeframe», ранее уже исправленная в `trading/service.py`.

### 🔴 Critical

#### 🔴 Telegram webhook fail-open при пустом TELEGRAM_WEBHOOK_SECRET → неаутентифицированное исполнение команд бота — `backend/app/notification/router.py:428`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** Верификация вебхука — `if secret_header != handler.webhook_secret: return 403`, где `webhook_secret = getattr(app_settings, 'TELEGRAM_WEBHOOK_SECRET', '')`, а дефолт в `config.py:23` — пустая строка; валидатор конфигурации проверяет только `SECRET_KEY`, но не webhook-секрет. Если `TELEGRAM_BOT_TOKEN` задан (бот включён), а `TELEGRAM_WEBHOOK_SECRET` не задан, `webhook_secret == ''`. Атакующий шлёт `POST /api/v1/notifications/telegram/webhook` без заголовка секрета → `secret_header=''` → `'' != ''` = False → проверка формально пройдена, вызывается `process_update(attacker_json)`. Авторизация бота строится только на `chat_id` из тела запроса (`_get_user_by_chat_id`), который атакующий полностью контролирует и может подставить `chat_id` жертвы: сфабриковав `/closeall` + callback `confirm_closeall` (`_execute_closeall`, `telegram_webhook.py:904`), можно принудительно закрыть все реальные позиции жертвы (прямая потеря денег), либо выполнить `/close`, читать `/positions`, `/balance`. Сравнение секрета также не constant-time. Верификация проследила полную цепочку по коду: `config.py:23`, `router.py:246,427-430,433-434`, `telegram_webhook.py:217,237,700,906,988-1004`, `engine.py:1446`, `csrf.py:46-47` (CSRF не защищает запрос без cookie).

- **Рекомендация:** Fail closed: если `webhook_secret` пустой — возвращать 503 и не обрабатывать update. Сравнивать секрет через `hmac.compare_digest`. В валидаторе конфигурации требовать непустой `TELEGRAM_WEBHOOK_SECRET`, если задан `TELEGRAM_BOT_TOKEN`.

### 🟠 High

#### 🟠 create_notification держит write-транзакцию SQLite во время сетевых вызовов Telegram/SMTP — `backend/app/notification/service.py:286`

- **Категория:** баг (архитектурная, также отмечена как quality-находка)  |  **Верификация:** ✅ подтверждено

- **Проблема:** Порядок в `create_notification`: `db.flush()` (строка 258, открывает write-транзакцию SQLite) → `dispatch_external(...)` (строка 286, сетевые вызовы Telegram Bot API и `aiosmtplib` с таймаутом 15 с) → `db.commit()` (строка 290, уже после сети). SQLite — single-writer (WAL, `busy_timeout=30000` в `common/database.py:106-107`, подтверждено). Пока SMTP/Telegram отвечают медленно, write-lock удерживается, и остальные писатели — включая торговый движок, сохраняющий ордера и `LiveTrade` в момент события `trade.filled` — получают задержку или «database is locked» после `busy_timeout`. Пример конкретного пересечения в критическом пути: `runtime.py:1091-1107` коммитит паузу сессии, затем на той же сессии вызывается `create_notification` с severity critical, транзакция держится во время `dispatch_external`; `_listen_loop` (строки 581-592) вызывает `dispatch` через `await` без `create_task`, поэтому одна медленная отправка блокирует все последующие уведомления сессии. Дополнительно `create_notification` вызывает `commit()` на переданной извне сессии — вызывающие (scheduler, роутеры) теряют контроль над границей транзакции, их незакоммиченные изменения фиксируются посреди чужой операции.

- **Рекомендация:** Коммитить уведомление до `dispatch_external` (с `channels_sent='in_app'`); внешнюю доставку выполнять после commit — через `asyncio.create_task` или отдельную очередь, `channels_sent` обновлять отдельной короткой транзакцией. Убрать commit чужой сессии — транзакцией должен управлять вызывающий слой, либо всегда работать через `self._db_factory`.

#### 🟠 Нет UniqueConstraint (user_id, event_type) на user_notification_settings — дубликаты навсегда ломают уведомления — `backend/app/notification/models.py:51`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Таблица `user_notification_settings` не имеет уникального ограничения на `(user_id, event_type)` ни в модели, ни в миграции `3d3e4e3036a6`, а «upsert» в `router.py:155-169` — неатомарный select-then-insert. При двух конкурентных `PUT /settings/{event_type}` (двойной клик, две вкладки) оба select возвращают `None`, и вставляются две строки. После этого `service.py:267` (`scalar_one_or_none()`) в `create_notification` бросает `MultipleResultsFound` для каждого уведомления этого event_type: в `_listen_loop` ошибка логируется и уведомление теряется, у прямых вызовов (scheduler, price_alert_monitor) — исключение наверх. Дефект самоподдерживающийся: до ручной чистки БД уведомления данного типа молча пропадают.

- **Рекомендация:** Добавить `UniqueConstraint("user_id", "event_type")` в `__table_args__` + alembic-миграцию с предварительной дедупликацией строк. В `router.py` использовать SQLite `INSERT ... ON CONFLICT DO UPDATE` (`sqlalchemy.dialects.sqlite.insert`) вместо select-then-insert. В `create_notification` заменить `scalar_one_or_none` на `first()` как защиту.

### 🟡 Medium

#### 🟡 dispatchers.py — мёртвый код в production, дублирующий и расходящийся с NotificationService.dispatch_external — `backend/app/notification/dispatchers.py:26`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Модуль `dispatchers.py` (102 строки: `dispatch_external`, `_get_telegram_link`, `_get_user`) не импортируется ни одним production-файлом (grep по `app/` — 0 вхождений вне модуля), живёт только в `tests/test_notification/test_dispatchers.py`. `NotificationService.dispatch_external` (`service.py:294`) реализует ту же логику заново, но с расхождениями: версия в `dispatchers.py` не содержит DEV_MODE-гейта, не резолвит ticker для кнопки `open_chart` и не знает про `EMAIL_ALLOWED_EVENTS`. Разработчик может найти «готовый» `dispatch_external` в `dispatchers.py`, подключить его — и получить Telegram-спам в dev-режиме и email по неразрешённым событиям; зелёные тесты `test_dispatchers.py` создают ложную уверенность в корректности этого пути.

- **Рекомендация:** Удалить `dispatchers.py` вместе с `test_dispatchers.py`, либо сделать его единственной реализацией и вызывать из `NotificationService`, устранив копию в `service.py`. По правилам проекта такой код обязан помечаться «NOT CONNECTED».

#### 🟡 _get_last_close_price не фильтрует OHLCVCache по timeframe — P&L в боте считается по свече чужого таймфрейма (регрессия ранее исправленного бага) — `backend/app/notification/telegram_webhook.py:56`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Запрос `select(OHLCVCache.close).where(ticker==...).order_by(timestamp.desc())` берёт последнюю свечу по любому timeframe. Docstring утверждает «тот же источник, что в `trading/service.py::_get_last_price`», но там с 2026-05-09 фильтр по timeframe добавлен явно после реального инцидента (exit_price 5087.50 при рыночной 5147.50 из-за перекрытия stale 5m-бара свежим 1h-баром). Здесь тот же баг воспроизведён заново: `/positions` и `/close` (picker) показывают нереализованный P&L по цене из произвольного таймфрейма. Сценарий: сессия 5m по SBER, в кэше есть 1h/1d бары с более поздним timestamp → бот показывает искажённый P&L, пользователь принимает решение закрыть/держать позицию по неверной цифре.

- **Рекомендация:** Передавать в `_get_last_close_price` timeframe сессии (`session.timeframe` доступен в обоих местах вызова) и добавить `.where(OHLCVCache.timeframe == timeframe)`, как в `trading/service.py::_get_last_price` и `OrderManager.close_position`.

#### 🟡 /balance: adapter.disconnect() не в finally — утечка gRPC-канала при ошибке get_balance, плюс дублирование логики broker/router.py — `backend/app/notification/telegram_webhook.py:532`

- **Категория:** баг / качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В `_handle_balance` цепочка `adapter.connect()` → `get_balance()` → `disconnect()` (строки 525-532) не обёрнута в try/finally: если `get_balance` бросает исключение (T-Invest недоступен, невалидный account_id, gRPC timeout), управление уходит в общий except, `disconnect()` не вызывается — gRPC-канал остаётся открытым. При повторных неудачных `/balance` соединения накапливаются в long-running процессе. Аналогичный код в `broker/router.py:287-291` корректно использует try/finally — логика подключения к брокеру продублирована в notification-модуле в ухудшенном виде; заодно notification-модуль напрямую обращается к внутренностям брокерского слоя (`decrypt_broker_key`, `TInvestAdapter`, приоритизация аккаунтов) — нарушение границ модулей.

- **Рекомендация:** Вынести получение баланса «по лучшему аккаунту пользователя» в метод `BrokerService` (с try/finally вокруг connect/disconnect) и вызывать его и из `broker/router.py`, и из `_handle_balance`. Минимум — обернуть `get_balance`/`disconnect` в try/finally.

#### 🟡 Дублирование ownership-check и закрытия позиции между _handle_close и _execute_close_position — `backend/app/notification/telegram_webhook.py:841`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_handle_close` (строки 583-631) и `_execute_close_position` (строки 841-902) содержат идентичные ~45 строк: тот же join-запрос `LiveTrade→TradingSession→StrategyVersion→Strategy` с фильтром `user_id`, та же проверка `status != "filled"`, тот же вызов `OrderManager.close_position` и те же тексты ошибок. Расхождение уже началось: в `_handle_close` ответ с `parse_mode="HTML"`, в callback-версии — без. При следующем изменении ownership-правила (например, учёт статуса `partially_filled`) правка попадёт только в одну копию — вторая продолжит закрывать/отклонять позиции по старым правилам, что в money-критичном пути (закрытие реальной позиции) даёт рассинхрон поведения кнопки и команды.

- **Рекомендация:** Выделить общий метод `_close_trade_for_user(user_id, trade_id) -> tuple[bool, str]`, возвращающий результат и текст ответа; обе точки входа (Message и CallbackQuery) только отправляют полученный текст.

#### 🟡 Глобальное мутабельное состояние _webhook_handler в модуле роутера вместо app.state (нарушение собственного паттерна C7) — `backend/app/notification/router.py:234`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Webhook-handler хранится в module-level переменных `_webhook_handler`/`_webhook_initialized` с ленивой инициализацией, хотя проект сам ввёл паттерн C7 (singleton через `app.state` + `Depends`) именно чтобы уйти от такого. Последствия: race при первых конкурентных webhook-запросах — оба увидят `None` и создадут два `Application`; в тестах состояние протекает между кейсами; если `initialize()` бросил исключение, `_webhook_handler` остаётся созданным при `_webhook_initialized=False` — следующий запрос повторно вызовет `initialize()` на том же `Application`, что для `python-telegram-bot` не гарантированно идемпотентно.

- **Рекомендация:** Создавать `TelegramWebhookHandler` в lifespan `app/main.py`, класть в `app.state.telegram_webhook_handler` и получать через `Depends`-функцию в `dependencies.py` (по аналогии с `get_notification_service`). Минимум — защитить инициализацию `asyncio.Lock`.

#### 🟡 /telegram/test: бизнес-логика и HTTP-клиент прямо в роутере, inline-схема, deprecated datetime.utcnow() — `backend/app/notification/router.py:349`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Endpoint `telegram_test` нарушает слоистость: Pydantic-модель `_Body` объявляется внутри функции-обработчика (класс пересоздаётся на каждый запрос и не попадает в OpenAPI-схему), тело парсится вручную через `request.json()` вместо штатной валидации FastAPI, прямой httpx-вызов Telegram API конструируется в роутере вместо `TelegramNotifier`. Строка 373 использует `datetime.utcnow()` — deprecated в Python 3.12. Фронтенд-разработчик не видит контракт body в `/docs` (endpoint принимает «сырой» Request), изменения формата общения с Telegram приходится искать по роутерам, а не в notifier-слое.

- **Рекомендация:** Вынести `_Body` в `schemas.py` (`TelegramTestRequest`) и принимать как типизированный параметр; логику отправки тестового сообщения перенести в `TelegramNotifier`/сервис. `datetime.utcnow()` заменить на `datetime.now(timezone.utc)`.

#### 🟡 Молчаливые except Exception без логирования в резолвинге ticker/цены/lot_size — `backend/app/notification/service.py:405`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Три хелпера проглатывают любые исключения без единой записи в лог: `_resolve_ticker_for_notification` (`service.py:405` — `except Exception: return None`), `_get_last_close_price` (`telegram_webhook.py:63`) и `_get_lot_size` (`telegram_webhook.py:80`). После рефакторинга market_data, ломающего запрос (например, переименовали поле `OHLCVCache`), `/positions` начинает всегда показывать «P&L: пока неизвестен», кнопка «Открыть график» исчезает из уведомлений — и ни одной строки в логах. В `_get_lot_size` тихий fallback `return 1` дополнительно даёт заниженный (в lot_size раз, для SBER — в 10 раз) P&L в Telegram — пользователь принимает торговое решение по неверной цифре без признака деградации.

- **Рекомендация:** В каждом из трёх мест логировать `logger.warning(..., error=str(exc))` перед `return`; в `_get_lot_size` при fallback показывать «неизвестен» или маркер приблизительности вместо заниженного значения.

#### 🟡 Фильтры date_from/date_to сравнивают aware-datetime с naive-UTC created_at — сдвиг на 3 часа для МСК — `backend/app/notification/router.py:54`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `Notification.created_at` хранится как naive UTC (`DateTime` + `func.now()`, SQLite `CURRENT_TIMESTAMP`). Если клиент передаёт `date_from=2026-07-05T12:00:00+03:00` (валидный ISO-вход, FastAPI распарсит в aware datetime), SQLite-диалект SQLAlchemy при биндинге отбрасывает tzinfo без конвертации в UTC: сравнение идёт по «12:00:00» вместо «09:00:00». Пользователь в Europe/Moscow, фильтруя уведомления «с 12:00 по 15:00 МСК», реально получит записи за 12:00–15:00 UTC — окно сдвинуто на 3 часа, часть уведомлений молча теряется из выдачи.

- **Рекомендация:** Нормализовать входные datetime в endpoint: если `tzinfo is not None` — `dt.astimezone(timezone.utc).replace(tzinfo=None)` перед подстановкой в запрос; helper вынести в `common/datetime_utils.py`.

#### 🟡 Слабая энтропия токена привязки Telegram (6 цифр) без ограничения попыток — `backend/app/notification/link_store.py:26`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `token = f"{secrets.randbelow(1_000_000):06d}"` — 10^6 вариантов (~20 бит). Успешный `consume` привязывает произвольный `chat_id` к `user_id` и даёт контроль над торговлей через бота (`/closeall`, `/close`, `/balance`). `consume` не считает неудачные попытки — каждый неверный код просто возвращает `None` без штрафа. Единственный барьер — общий `RateLimit 'general'` 200/мин по IP (`/telegram/webhook` и `/telegram/link-token` не входят в `CATEGORY_PATHS`). В связке с fail-open вебхуком (или распределённо по IP) атакующий может перебирать коды в 5-минутном TTL-окне и привязать свой `chat_id` к чужому аккаунту.

- **Рекомендация:** Увеличить энтропию (например `secrets.token_urlsafe`, 8-10 символов) и/или ввести счётчик неудачных `consume` с временной блокировкой `chat_id`/IP; добавить выделенный rate-limit для `/telegram/*`.

### 🔵 Low

#### 🔵 N+1 запросы и дублирование цикла построения позиций между /positions и /close-picker — `backend/app/notification/telegram_webhook.py:361`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_handle_positions` (строки 347-382) и `_show_close_picker` (строки 644-674) в цикле по сессиям выполняют по 2 отдельных запроса на каждую сессию (`_get_last_close_price` + `_get_lot_size`, причём второй может уйти во внешний источник через `MarketDataService.ensure_lot_size`). При 15 активных сессиях — 30+ последовательных запросов на одну Telegram-команду, заметная задержка ответа бота (бюджет <3с). Цикл «сессии → цена/лот → filled-трейды → форматирование» скопирован в оба метода — отличается только представление (текст vs кнопки).

- **Рекомендация:** Собрать уникальные тикеры сессий и получить цены/лоты одним batched-запросом (`WHERE ticker IN (...)`); выделить общий метод `_iter_open_positions(user_id)`, из которого обе команды строят своё представление.

#### 🔵 Проглатывание ошибок фоновых задач при остановке listener'ов — `backend/app/notification/service.py:450`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В `stop_listening` (строка 450) и `stop_broker_listener` (строка 484) конструкция `except (asyncio.CancelledError, Exception): pass` глотает не только ожидаемый `CancelledError`, но и любые реальные исключения таска. Если `_listen_loop` падает из-за бага вне внутренних try/except (например, ошибка распаковки `EVENT_MAP` после рефакторинга), уведомления по сессии молча перестают создаваться, а при `stop_listening` исключение окончательно исчезает без следа в логах — теряется единственный шанс увидеть причину.

- **Рекомендация:** Разделить ветки: `except asyncio.CancelledError: pass` и `except Exception as exc: logger.error(...)`. Дополнительно добавить `done_callback` на task при создании, логирующий неожиданное завершение цикла.

#### 🔵 link_store.cleanup() никогда не вызывается; _awaiting_token в webhook-хендлере растёт неограниченно — `backend/app/notification/link_store.py:58`

- **Категория:** качество кода / баг  |  **Верификация:** — не проверялось

- **Проблема:** Метод `cleanup()` не вызывается нигде в `app/` (grep — 0 вхождений) — мёртвый код. Истёкший токен удаляется только при `consume()` или повторном `generate()` тем же пользователем: кто запросил код и не привязал Telegram — оставляет запись навсегда. Аналогично в `telegram_webhook.py:181` словарь `_awaiting_token` пополняется на каждый `/start` без аргумента и чистится только если тот же чат напишет текст: боты-спамеры, шлющие `/start` публичному боту, наращивают словарь без ограничения. Утечка медленная, но процесс long-running (терминал работает неделями).

- **Рекомендация:** Вызывать `link_store.cleanup()` периодически (APScheduler-джоба) либо инлайн в начале `generate()`/`consume()`; для `_awaiting_token` — при каждом `/start` попутно удалять записи с истёкшим `expires_at`.

#### 🔵 _execute_closeall не проверяет query.message на None — AttributeError и молчаливый отказ закрытия — `backend/app/notification/telegram_webhook.py:906`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В отличие от `_execute_close_position` и `_handle_open_session_callback` (guard `if not query.message or not query.message.chat: return`), `_execute_closeall` сразу делает `str(query.message.chat.id)`. По Bot API поле `message` в `callback_query` опционально (callback от старого/недоступного сообщения). Пользователь нажимает «Да, закрыть все» на старом сообщении подтверждения → `AttributeError` → исключение гасится в `router.telegram_webhook` (лог + 200 OK) → позиции не закрыты, пользователь не получает ответа и считает, что позиции закрываются.

- **Рекомендация:** Добавить в начало `_execute_closeall` тот же guard, что в соседних callback-хендлерах.

#### 🔵 /status показывает время паузы в UTC вместо Europe/Moscow — `backend/app/notification/telegram_webhook.py:441`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `stopped_at` пишется как `datetime.now(timezone.utc)` в naive-колонку (офсет отбрасывается при сохранении в SQLite) — в БД лежит UTC-время. `_handle_status` выводит `s.stopped_at.strftime('%H:%M')` без конвертации в таймзону биржи. Сессия поставлена на паузу в 15:30 МСК → бот пишет «На паузе с 12:30» — время врёт на 3 часа для пользователя в Москве.

- **Рекомендация:** Трактовать `stopped_at` как UTC и конвертировать: `dt.replace(tzinfo=timezone.utc).astimezone(ZoneInfo('Europe/Moscow'))` перед `strftime`.

#### 🔵 _awaiting_token растёт неограниченно — истёкшие записи чистятся только при следующем сообщении того же чата — `backend/app/notification/telegram_webhook.py:241`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Любой Telegram-пользователь (бот публичный) командой `/start` без аргумента добавляет в dict запись `chat_id→expires_at`. Запись удаляется только если тот же чат пришлёт следующее текстовое сообщение или привяжется; записи чатов, которые больше не написали, живут вечно. Спам-боты, шлющие `/start` с тысяч `chat_id`, монотонно наращивают dict — медленная утечка памяти в long-running бэкенде. (Дублирует находку по `link_store.cleanup()` выше в части `_awaiting_token`.)

- **Рекомендация:** При каждом обращении к `_awaiting_token` (или периодически, аналогично `link_store.cleanup`) удалять все записи с `expires_at < now`; опционально ограничить размер dict.

#### 🔵 _link_account вставляет username в HTML-ответ без экранирования — подтверждение привязки может не дойти — `backend/app/notification/telegram_webhook.py:321`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `reply_text(f"✅ Telegram привязан к аккаунту <b>{username}</b>", parse_mode="HTML")` — username пользовательский и не проходит `html.escape` (в отличие от `TelegramNotifier.send`, где escape добавлен именно против этой проблемы). Если username содержит `<` или `&`, Telegram API отвечает 400 (can't parse entities) → `reply` падает исключением после `db.commit()` — привязка создана, но пользователь не получает подтверждения и считает процедуру сломанной.

- **Рекомендация:** Экранировать username через уже существующий `_safe_format_event_text` (`html.escape`) перед подстановкой в HTML.

#### 🔵 LinkTokenStore.generate не проверяет коллизию токена — возможна привязка Telegram к чужому аккаунту — `backend/app/notification/link_store.py:37`

- **Категория:** баг / уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** Токен — 6 цифр (1 млн вариантов). `generate()` пишет `self._tokens[token] = (user_id, ...)` без проверки, что такой токен уже выдан другому пользователю. Пользователь A получил код 123456 и ещё не ввёл; пользователь B случайно генерирует те же 123456 — запись A перезаписывается на B. A вводит свой код в Telegram → `consume` возвращает `user_id` B → чат A привязывается к аккаунту B: A получает уведомления и может закрывать позиции (`/close`, `/closeall`) чужого аккаунта. Вероятность коллизии ~1e-6, но последствие — кросс-аккаунтный доступ к деньгам.

- **Рекомендация:** В `generate()` под локом перегенерировать токен, пока он есть в `self._tokens`, либо увеличить длину/энтропию кода.

#### 🔵 _format_decimal конвертирует Decimal в float при форматировании денежных сумм — `backend/app/notification/telegram_webhook.py:46`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Проектная конвенция — деньги на бэке только в Decimal. `_format_decimal` делает `f"{float(value):,.{precision}f}"` — Decimal→float конверсия перед выводом P&L, баланса и цен входа в Telegram. Для типичных сумм ошибка скрыта округлением, но для крупных портфелей и накопленных сумм float может дать расхождение в последних знаках с UI, который форматирует Decimal напрямую, — пользователь видит разные цифры в терминале и в боте.

- **Рекомендация:** Заменить на `f"{value:,.{precision}f}".replace(",", " ")` без `float()` — Decimal форматируется без потери точности.

#### 🔵 /test-email дублирует сборку EmailNotifier из настроек, уже реализованную в NotificationService — `backend/app/notification/router.py:208`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Endpoint `send_test_email` вручную конструирует `EmailNotifier` из пяти SMTP-настроек — точная копия проводки из `NotificationService._init_external_channels` (`service.py:218-227`). При добавлении шестого параметра (например, TLS-режима) правка в одном месте не попадёт во второе: тестовое письмо начнёт вести себя иначе, чем боевые уведомления, обесценивая test-endpoint. Заодно в функции локальный `import JSONResponse as _JSONResponse`, хотя `JSONResponse` уже импортирован на уровне модуля (строка 20).

- **Рекомендация:** Получать `NotificationService` через `Depends(get_notification_service)` и добавить в него метод `send_test_email(user)`, использующий уже инициализированный `self._email`. Локальный импорт `_JSONResponse` удалить.

#### 🔵 /telegram/test — аутентифицированный релей к Telegram Bot API с произвольным bot_token/chat_id — `backend/app/notification/router.py:378`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** URL = `https://api.telegram.org/bot{body.bot_token}/sendMessage` из полностью пользовательских `bot_token` и `chat_id` без валидации и специального rate-limit (путь в категории 'general' 200/мин). Хост захардкожен, SSRF на внутренний хост не проходит (`@`/`/` уходят в path), но любой аутентифицированный пользователь может использовать сервер как исходящий релей к Telegram с произвольными токенами/chat_id (спам, зондирование с IP сервера). Любая ошибка возвращает HTTP 200 с `ok:false`, маскируя сбои.

- **Рекомендация:** Валидировать формат `bot_token` (regex `^\d+:[A-Za-z0-9_-]+$`) до URL; добавить строгий per-user rate-limit; ограничить отправку лишь на уже привязанные chat_id либо пометить dev-only.


---

## 17. Backend: AI-модуль (чат, слэш-команды)

Модуль `app/ai` структурирован в целом грамотно: абстракция провайдеров с фабрикой, продуманная sanitization в `slash_context.py` (маркеры, ownership через JOIN по user_id), authz/IDOR закрыты почти везде, ключи провайдеров хранятся зашифрованными (AES-256-GCM) и маскируются в ответах. Главная реальная уязвимость — SSRF через неограниченный `api_base_url`, усиленный возвратом сырого `str(e)` клиенту (SSRF-оракул). Основные функциональные дефекты сосредоточены вокруг учёта токенов/бюджета (обход лимита через `/explain`, lost-update гонка при инкременте, эвристика вместо реального usage у Claude), несовместимости `ContextCompressor` с Anthropic API (первое сообщение `role=assistant` → 400), молча отбрасываемых attachments и ложного PnL в slash-контексте. Отдельный пласт — дублирование пайплайна между `chat()` и `chat_stream()`, несогласованное управление транзакциями и точечные проблемы валидации/устойчивости (TOCTOU в лимите SSE-стримов, нетипизированный `dict` в `update_instructions`, провайдеры без дефолтного `api_base_url`).

### 🟠 High

#### 🔴 SSRF: неограниченный `api_base_url` отправляет запросы бэкенда на произвольный внутренний хост — `backend/app/ai/router.py:118`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** Endpoint `POST /api/v1/settings/ai/providers/verify-credentials` принимает поле `api_base_url` (схема ограничивает только `max_length=500`, без проверки схемы/хоста) и сразу создаёт провайдера через `ProviderFactory.create(...)` → `OpenAIProvider`, после чего вызывает `provider.verify()`, выполняющий исходящий HTTP-запрос на `{api_base_url}/chat/completions`. То же происходит при `create/update_provider` (service.py:205,237) и в чате. Любой аутентифицированный пользователь (регистрация открыта через `/auth/setup`) может задать `api_base_url = http://169.254.169.254/latest/meta-data`, `http://localhost:8000/api/v1/admin/...` или `http://10.0.0.5:6379` и заставить сервер обращаться к внутренним сервисам/облачным метаданным. Ответ/ошибка возвращаются клиенту, а `latency_ms` даёт тайминговый оракул для сканирования портов. Проверок на приватные диапазоны (127/8, 10/8, 172.16/12, 192.168/16, 169.254/16, ::1) нет. Подтверждено при верификации: `verify-credentials` (router.py:112-123) требует лишь `get_current_user`; `api_base_url` (schemas.py:60) не проверяет хост; значение передаётся as-is в `ProviderFactory.create` → `OpenAIProvider/CustomProvider(base_url=...)`; `provider.verify()` (openai_provider.py:33-35,103-107) шлёт реальный HTTP POST на `{base_url}/chat/completions`; ответ/error/latency_ms возвращаются клиенту (router.py:124-129). Тот же дефект в `create/update_provider` (service.py:193-237). Фильтрации private/loopback/link-local нигде нет.

- **Рекомендация:** Добавить валидацию `api_base_url`: разрешить только https, резолвить хост и отклонять приватные/loopback/link-local/metadata IP (`ipaddress.is_private/is_loopback/is_link_local`), запретить редиректы на приватные адреса. Лучше — allowlist известных провайдерских доменов. Валидировать в Pydantic и повторно перед запросом (защита от DNS-rebinding).

#### 🔴 `ContextCompressor` формирует сообщения, начинающиеся с `role=assistant` — Claude API отвергает такой запрос — `backend/app/ai/context.py:79`

- **Категория:** качество кода / баг  |  **Верификация:** — не проверялось

- **Проблема:** После сжатия `compress()` возвращает `[{role: 'assistant', content: '[Краткое содержание...]'}]` + последние 3 сообщения. Anthropic Messages API требует, чтобы первое сообщение имело `role='user'` (иначе 400 `invalid_request_error`, «first message must use the "user" role»). Сценарий: пользователь с активным провайдером claude ведёт длинный диалог (история ~320К символов, порог 80% от 100К токенов) → `should_compress()` срабатывает → `compress()` ставит assistant первым → каждый последующий запрос `/api/v1/ai/chat` и `/chat/stream` падает с 400 от Anthropic, превращающимся в `ValidationError «Ошибка AI-провайдера: ...»`. Так как история приходит с клиента и не уменьшается, чат для стратегии становится перманентно неработоспособным именно в тот момент, когда сжатие должно было его спасти. Fallback-ветка (recent_messages при ошибке суммаризации) тоже может начинаться с assistant. Для OpenAI-совместимых провайдеров запрос проходит — дефект абстракции: компрессор генерирует последовательность ролей, невалидную для одного из поддерживаемых провайдеров.

- **Рекомендация:** Выдавать summary как user-сообщение (например, `{role: 'user', content: '[Краткое содержание предыдущего диалога]: ...'}` + `{role: 'assistant', content: 'Принял.'}`), либо переносить summary в system prompt; гарантировать, что `recent_messages` также начинается с `role=user` (сдвигать срез при необходимости). Добавить unit-тест: после `compress()` первый message имеет `role='user'`.

### 🟡 Medium

#### 🟡 `/explain` проверяет бюджет, но никогда не списывает токены — обход лимита расходов — `backend/app/ai/chat_router.py:418`

- **Категория:** качество кода / баг  |  **Верификация:** — не проверялось

- **Проблема:** В `explain_code` вызывается `ai_service.increment_usage(user.id, db)` с дефолтными `prompt_tokens=0, completion_tokens=0` — реальные токены из результата/провайдера не передаются вообще, обновляется только `last_used_at`. Сценарий: пользователь с лимитом `prompt_tokens_limit=10000` может бесконечно вызывать `/api/v1/ai/explain` с фрагментами до 50000 символов — каждый вызов реально тратит токены (и деньги владельца ключа) у AI-провайдера, но счётчик использования не растёт, `check_budget` всегда `allowed=true`. Учёт бюджета для этого endpoint'а фиктивен — лимит расходов обходится неограниченно.

- **Рекомендация:** Передавать реальные токены как в `/chat`: `usage = provider.get_last_usage()`; при нулях — оценка через `provider.count_tokens(request.code_snippet)` и `count_tokens(explanation)`. Вынести общий блок «usage → fallback-оценка → increment_usage» в хелпер, чтобы он не расходился между `/chat`, `/chat/stream` и `/explain`.

#### 🟡 `increment_usage`: неатомарный read-modify-write счётчиков токенов (lost update) + произвольный commit — `backend/app/ai/service.py:150`

- **Категория:** качество кода / баг  |  **Верификация:** — не проверялось

- **Проблема:** Счётчики инкрементируются в Python (`config.prompt_tokens_used += prompt_tokens`) с последующим `db.commit()`. При параллельных запросах одного пользователя (до 3 SSE-стримов одновременно + non-streaming `/chat`, либо `/chat` + `/explain`) два запроса читают одно значение и оба пишут «старое + своё» — инкремент одного из них теряется (last-write-wins). Итог: `prompt_tokens_used`/`completion_tokens_used` систематически занижены, бюджетный лимит (`check_budget`) срабатывает позже, чем должен — пользователь тратит больше оплачиваемых токенов провайдера, чем разрешено. Дополнительно `commit()` внутри `increment_usage` фиксирует всё, что накопилось в request-scoped сессии к этому моменту (частичное состояние запроса): например, в `/chat` usage коммитится ДО сохранения истории — при падении `save_message` токены уже списаны, а сообщений в истории нет.

- **Рекомендация:** Заменить на атомарный UPDATE: `await db.execute(update(AIProviderConfig).where(id==...).values(prompt_tokens_used=AIProviderConfig.prompt_tokens_used + prompt_tokens, completion_tokens_used=..., last_used_at=...))`. Управление транзакцией (commit) вынести на границу запроса единой политикой; в сервисных методах — только flush.

#### 🟡 `ClaudeProvider` выбрасывает реальный usage из ответа API — учёт токенов идёт по грубой оценке len/4 — `backend/app/ai/providers/claude_provider.py:44`

- **Категория:** качество кода / баг  |  **Верификация:** — не проверялось

- **Проблема:** `OpenAIProvider` реализует `get_last_usage()`, но метода нет в `BaseLLMProvider`, поэтому `chat_router.py:244/344` вызывает его через `hasattr(provider, 'get_last_usage')`. `ClaudeProvider` метода не имеет, хотя реальные `input_tokens`/`output_tokens` доступны в `response.usage` (chat) и через `stream.get_final_message()` (стриминг) — они выбрасываются. В итоге для Claude бюджет всегда считается эвристикой `len(text)//4` по `json.dumps` содержимого сообщений: для русскоязычных промптов (системный промпт и UI на русском, экранирование кириллицы `\uXXXX`) реальный расход токенов в ~1.5–2 раза выше оценки — лимиты пользователя недосчитываются, стоимость недооценивается. Эвристика «4 символа = токен» продублирована в трёх местах (claude_provider.py:72, openai_provider.py:96, context.py:39–40). В non-streaming ответе точный `result['tokens_used']` уже вычислен, но в `increment_usage` не используется.

- **Рекомендация:** Добавить `get_last_usage()` в `BaseLLMProvider` (абстрактный или с дефолтом `{}`); в `ClaudeProvider` сохранять `response.usage.input_tokens/output_tokens` в `_last_usage` для `chat()` и через `get_final_message()` для `stream_chat()`. Убрать `hasattr` в роутере. Эвристику `count_tokens` сделать дефолтной реализацией базового класса.

#### 🟡 Attachments из запроса чата молча отбрасываются — вложения никогда не доходят до LLM — `backend/app/ai/chat_schemas.py:43`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `ChatRequest.attachments` принимается схемой, фронтенд реально отправляет вложения (`frontend/src/services/aiStreamClient.ts:54`, `ChatInput.tsx`), но в `chat_router.py` поле `request.attachments` нигде не читается: ни `_build_messages`, ни провайдеры его не получают. Сценарий: пользователь прикладывает скриншот графика или файл со стратегией и спрашивает «что на картинке?» — модель отвечает, не видя вложения, часто галлюцинируя содержимое. Пользователь считает, что AI проанализировал файл.

- **Рекомендация:** Либо пробрасывать attachments в messages (для Claude/OpenAI — content-блоки типа image/base64, для text/* — вставка текста в prompt), либо до реализации возвращать 400 «вложения не поддерживаются» и убрать поле из UI.

#### 🟡 PnL в slash-контексте `/session` и `/portfolio` считается без стоимости открытых позиций — `backend/app/ai/slash_context.py:213`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `_resolve_session`: `pnl = (portfolio.balance + portfolio.blocked_amount) - initial_capital`. В `paper_engine` при покупке `balance` не уменьшается, а `blocked_amount += total_cost`; после T+1 unblock `balance -= blocked`. Сценарий: капитал 100 000, куплено акций на 10 000: до T+1 equity=110 000 → модель получает `pnl=+10000` (двойной учёт заблокированных средств), после T+1 equity=90 000 → `pnl=-10000`, хотя реальный PnL ≈ 0 (стоимость открытой позиции игнорируется). В `_resolve_portfolio` (строка 265-267) та же формула отдаётся как `total_unrealized_pnl`. AI-ассистент строит рекомендации («стратегия убыточна, останавливай сессию») на ложных цифрах.

- **Рекомендация:** Считать equity как `cash + стоимость открытых позиций` (LiveTrade с `exit_price IS NULL`: `quantity * entry_price` или последняя цена из кеша котировок), не складывая `blocked_amount` с неуменьшенным `balance`. Либо честно помечать значение как `cash_balance`, а не `pnl`/`unrealized_pnl`.

#### 🟡 Провайдеры deepseek/openrouter/groq/qwen без `api_base_url` дают необработанный `ValueError` → 500 в чате — `backend/app/ai/providers/factory.py:30`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Для типов из `_openai_compatible` фабрика вызывает `CustomProvider(base_url=api_base_url or "")`, а `CustomProvider.__init__` бросает `ValueError` при пустом `base_url`. `api_base_url` в `AIProviderCreate` необязателен, значит конфиг «deepseek без URL» успешно создаётся и активируется. Сценарий: `POST /providers {provider_type:'deepseek', без api_base_url}` → activate → `POST /chat`: try в `chat_router` ловит только `AIProviderNotConfiguredError`, `ValueError` пролетает наверх → 500 Internal Server Error без осмысленного сообщения. Для этих типов не заданы известные дефолтные URL (в отличие от gemini/mistral) — тип нерабочий «из коробки».

- **Рекомендация:** Задать дефолтные `base_url` (deepseek: `https://api.deepseek.com/v1`, openrouter: `https://openrouter.ai/api/v1`, groq: `https://api.groq.com/openai/v1` и т.д.), и/или валидировать наличие `api_base_url` на этапе создания (Pydantic-валидатор), а в chat-эндпоинтах перехватывать `ValueError` как `ValidationError`.

#### 🟡 Широкие `except Exception` превращают любые ошибки (включая баги кода) в 400/SSE-error и отдают `str(e)` клиенту — `backend/app/ai/chat_router.py:236`

- **Категория:** качество кода / уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** В `chat()` (стр. 234–238), `explain_code()` (стр. 412–416), `event_generator()` (стр. 374–380) и `router.py verify_credentials` (стр. 126–129) любое исключение — не только сетевые ошибки провайдера, но и программные (`AttributeError`, `KeyError`, `TypeError` из-за несовпадения контракта провайдера) — ловится `except Exception` и возвращается клиенту как `ValidationError 400 «Ошибка AI-провайдера: <str(e)>»` или SSE-событие `{type: 'error', detail: str(e)}`. Для custom/openai-провайдера с подставленным внутренним `api_base_url` текст исключения httpx/openai содержит целевой URL, код ответа и часто фрагмент тела ответа внутреннего сервиса — это превращает слепой SSRF (см. находку выше) в наблюдаемый: по сообщению (ConnectionRefused vs Timeout vs HTTP 200/403) атакующий точно определяет доступность хоста/порта. Дополнительно регрессия в коде (например, отсутствие поля `usage` у нового OpenAI-совместимого API) даёт `AttributeError` → клиент видит 400 с внутренним текстом ошибки, в мониторинге это выглядит как ошибка пользовательского ввода, а не баг; стектрейс теряется (`logger.error` пишет только `str(e)`, без `exc_info`).

- **Рекомендация:** В провайдерах транслировать SDK-исключения в типизированное доменное исключение (`AIProviderError` с безопасным сообщением), в роутере ловить только его; остальное — в глобальный 500-хендлер. Логировать с `exc_info=True`. Клиенту — обобщённый текст без `str(e)` и без URL/деталей ответа внутреннего сервиса.

#### 🟡 ~50 строк дублирования между `chat()` и `chat_stream()` — `backend/app/ai/chat_router.py:270`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Пайплайн подготовки запроса (валидация стратегии → check_budget → выбор провайдера → history → build_enriched_prefix → `_build_messages` → `_get_user_instructions` → компрессия) и пост-обработки (`get_last_usage` → fallback-оценка → `increment_usage` → `_extract_suggested_blocks` → `save_message`×2 → commit) скопирован между `chat()` (стр. 195–261) и `chat_stream()` (стр. 288–365) практически дословно. Расхождения уже есть: `/explain` «забыл» передать токены в `increment_usage` (отдельная находка), `tokens_used` в `ChatResponse` берётся из `result`, а в done-событии SSE — из `prompt+completion` (разные числа для одного запроса). Любой будущий фикс (лимит на историю, новая проверка безопасности) с высокой вероятностью попадёт только в один из двух endpoint'ов, и поведение streaming/non-streaming разойдётся незаметно для тестов.

- **Рекомендация:** Извлечь общие хелперы: `prepare_chat_call(request, user, db) -> (provider, messages, system_prompt)` и `finalize_chat_call(...)` для учёта usage и сохранения истории. Endpoint'ы оставить тонкими обёртками (non-streaming / SSE).

#### 🟡 `update_instructions` принимает нетипизированный `dict` без валидации — риск роста стоимости и 500 при некорректном значении — `backend/app/ai/router.py:243`

- **Категория:** качество кода / баг  |  **Верификация:** — не проверялось

- **Проблема:** `PUT /api/v1/settings/ai/instructions` объявлен как `data: dict` — без Pydantic-схемы, без ограничения длины и типа значения. Сценарий A: пользователь сохраняет строку в несколько мегабайт — Text-колонка примет её без ошибок; после этого каждый запрос `/chat` и `/chat/stream` приклеивает этот текст к system prompt (`chat_router.py:227`) → резкий рост расхода токенов/стоимости либо постоянные ошибки превышения контекста. Сценарий B: `PUT {"custom_instructions": 123}` — int сохраняется в Text-колонку SQLite как есть; при следующем `POST /chat` функция `_get_user_instructions` вызывает `settings.custom_instructions.strip()` → `AttributeError` → 500 на каждом сообщении чата и стрима, пока запись не исправят вручную; значение `null` даст `IntegrityError` (колонка NOT NULL) уже при сохранении. Дополнительно: оба endpoint'а инструкций содержат бизнес-логику и работу с моделью `UserAISettings` прямо в роутере с локальными импортами, минуя сервисный слой.

- **Рекомендация:** Ввести Pydantic-схему (`custom_instructions: str = Field('', max_length=5000)`) и response-модель; перенести чтение/запись `UserAISettings` в `AIService`. Защититься в `_get_user_instructions`: `(settings.custom_instructions or '')`. Убрать локальные импорты из тел функций.

#### 🟡 Раскрытие внутренних деталей через возврат сырого `str(e)` провайдера клиенту — `backend/app/ai/chat_router.py:238`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** Дублирует технически ту же причину, что и широкие `except Exception` выше, но выделяется отдельно как канал усиления SSRF: в `chat` (строка 238) и `explain_code` (строка 416) исключение провайдера отдаётся как `ValidationError(f"Ошибка AI-провайдера: {str(e)}")`, а в `verify_credentials` (router.py:128) `str(e)` кладётся в поле `error` ответа. Текст исключения httpx/openai для подставленного внутреннего `api_base_url` содержит целевой URL, код ответа и часто фрагмент тела ответа внутреннего сервиса — атакующий по сообщению (ConnectionRefused/Timeout/HTTP 200/403) точно определяет доступность хоста/порта и может извлекать данные внутренних endpoint'ов.

- **Рекомендация:** Не возвращать `str(e)` клиенту. Логировать полную ошибку через structlog на сервере, пользователю отдавать обобщённое сообщение без URL/ответа. В verify-ответе поле `error` заполнять только нормализованными категориями.

### 🔵 Low

#### 🔵 TOCTOU в лимите одновременных SSE-стримов: проверка и инкремент разнесены — `backend/app/ai/chat_router.py:327`

- **Категория:** качество кода / баг  |  **Верификация:** — не проверялось

- **Проблема:** Проверка `current >= MAX_CONCURRENT_STREAMS` выполняется в теле endpoint'а (стр. 327–332), а инкремент `_active_streams` — только при первом шаге генератора `event_generator` (стр. 335–336), который начинает исполняться только когда Starlette стартует отдачу ответа. Сценарий: клиент открывает 10 SSE-соединений одновременно — все проходят проверку (счётчик ещё 0) и все стартуют; лимит 3 не работает именно в том случае, от которого должен защищать. Дополнительно: `threading.Lock` — блокирующий примитив в event loop (секции короткие, но паттерн неудачный), а словарь `_active_streams` живёт в памяти процесса — при нескольких uvicorn-воркерах фактический лимит становится 3×N.

- **Рекомендация:** Атомарный check-and-increment под одним lock'ом в endpoint'е ДО возврата ответа (инкремент сразу при проверке); декремент — в `finally` генератора плюс страховка через BackgroundTask/response callback на случай, если генератор не будет итерирован. Для многопроцессного деплоя — общее хранилище или существующий rate-limit middleware.

#### 🔵 Lost update в `increment_usage` (дубль в измерении bugs) — `backend/app/ai/service.py:150`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** См. основную находку в разделе Medium («`increment_usage`: неатомарный read-modify-write»); здесь измерение bugs фиксирует тот же дефект с акцентом на конкретную гонку между `/chat` и `/explain` или двумя параллельными SSE-стримами: оба читают `used=1000`, оба прибавляют свои токены и коммитят — одно из приращений теряется (last-write-wins).

- **Рекомендация:** См. выше — атомарный UPDATE вместо изменения ORM-объекта.

#### 🔵 `_resolve_session` считает открытые позиции загрузкой всех строк `LiveTrade` в память — `backend/app/ai/slash_context.py:216`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Для подсчёта `open_positions` выполняется `select(LiveTrade).where(...)` и затем `len(list(result.scalars().all()))` — все ORM-объекты сделок сессии материализуются в память ради одного числа. Сценарий: активная сессия с тысячами сделок → каждая slash-команда `/session` в чате тянет из SQLite и гидрирует тысячи объектов, замедляя ответ чата, хотя нужен `COUNT(*)`.

- **Рекомендация:** Заменить на `select(func.count()).select_from(LiveTrade).where(...)` и `scalar()`. Проверить остальные резолверы на выборку полных сущностей там, где нужны агрегаты.

#### 🔵 `save_message`: повторные запросы к БД и полная перезапись неограниченно растущей JSON-истории — `backend/app/ai/chat_history.py:47`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `save_message` вызывает `_get_current_version` (1–2 SELECT), затем `get_history`, который снова вызывает `_get_current_version` (ещё 1–2 SELECT) и парсит весь JSON истории. Один запрос `/chat` делает два `save_message` (user + assistant) → до 8 SELECT'ов и два полных цикла `json.loads`/`json.dumps` всей истории. История в `strategy_versions.ai_chat_history` не ограничена по размеру: каждое новое сообщение перечитывает и перезаписывает весь Text-блоб. Сценарий: после нескольких сотен сообщений с длинными ответами AI каждая реплика чата парсит и пишет мегабайты JSON в SQLite, латентность чата растёт линейно с длиной истории.

- **Рекомендация:** Загружать версию один раз и сохранять обе реплики одной операцией (`save_messages(version, [(role, content), ...])`); добавить ограничение хранимой истории (например, последние 100 сообщений с усечением старых).

#### 🔵 Непоследовательное владение транзакцией: двойной commit и фиксация частичного состояния посреди запроса — `backend/app/ai/router.py:170`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Границы транзакций размазаны между слоями: `reset_usage` коммитит внутри сервиса (service.py:164), после чего роутер коммитит ещё раз (router.py:170); create/update/delete/activate/`increment_usage` коммитят сами, а `chat_router` дополнительно коммитит после `save_message`. Сценарий: в `/chat` `increment_usage` делает commit ДО сохранения истории — если `save_message` или финальный commit упадёт, usage уже зафиксирован, а сообщений в истории нет; повторная отправка того же сообщения спишет токены дважды. Каждая функция сама решает, когда фиксировать — такие ошибки трудно отлаживать.

- **Рекомендация:** Принять единую политику: сервисные методы делают только flush, commit — один раз на границе запроса (в endpoint'е или в `get_db`-dependency). Убрать лишний commit из `reset_usage`-роута.

#### 🔵 Цены за 1M токенов — `float` в схемах и `float()` в ответе при колонке `Numeric(10,4)`: нарушение конвенции Decimal — `backend/app/ai/schemas.py:15`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Проектная конвенция (Develop/CLAUDE.md): финансовые значения — Numeric в БД и `decimal.Decimal` в Python. Колонки `price_per_1m_prompt`/`completion` объявлены `Numeric(10,4)`, но Pydantic-схемы `AIProviderCreate`/`Update` принимают `float`, а `router._to_response` отдаёт `float(config.price_per_1m_prompt or 0)`. Сценарий: при подключении расчёта стоимости (цена × миллионы токенов) накапливаются двоичные погрешности float — в отчёте о расходах появляются суммы вида `2.7500000000000004`. Пока цены используются только для отображения — риск мал, но конвенция нарушена и будущий расчёт будет построен на float.

- **Рекомендация:** В схемах использовать `Decimal` (`Field(..., ge=0, max_digits=10, decimal_places=4)`), в `_to_response` отдавать `str`/`Decimal`, а не `float`. Будущие вычисления стоимости вести в Decimal.

#### 🔵 `max_tokens=4096` захардкожен во всех провайдерах — длинный ответ обрезается, `json_blocks` молча теряется — `backend/app/ai/providers/claude_provider.py:39`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `max_tokens=4096` зашит в `chat()`/`stream_chat()` и `ClaudeProvider`, и `OpenAIProvider` — не читается ни из settings, ни из конфигурации провайдера. Сценарий: пользователь просит AI сгенерировать развёрнутое описание стратегии + блочную схему; ответ упирается в 4096 токенов и обрезается посреди блока ` ```json_blocks ` — закрывающая тройная кавычка не приходит, regex в `_extract_suggested_blocks` не матчится, `suggested_blocks` молча `None`. Пользователь видит оборванный текст без блоков и без признака усечения (`stop_reason`/`finish_reason` нигде не проверяется).

- **Рекомендация:** Вынести `max_tokens` в settings (`AI_MAX_TOKENS`) или в поле `AIProviderConfig`; проверять `stop_reason`/`finish_reason` ответа и сигнализировать усечение (поле `truncated=true` или предупреждение в ответе).

#### 🔵 `PUT /settings/ai/instructions` не покрыт rate-limit усиленной категории; `verify-credentials` не покрыт строгим AI rate-limit — `backend/app/ai/router.py:112`

- **Категория:** security-check  |  **Верификация:** — не проверялось

- **Проблема:** `RateLimitMiddleware.CATEGORY_PATHS` (middleware/rate_limit.py:38) относит к строгой категории «ai» (10 req/min) только префикс `/api/v1/ai`. Endpoint'ы конструктора провайдеров смонтированы под `/api/v1/settings/ai` (main.py:320) и попадают в категорию «general» — 200 req/min. SSRF-пробинг через `verify-credentials` и перебор `base_url` возможны со скоростью до 200 запросов/мин на пользователя, чего достаточно для сканирования внутренней сети/портов. Это дешёвый endpoint, инициирующий исходящие сетевые запросы.

- **Рекомендация:** Добавить `/api/v1/settings/ai/providers/verify-credentials` и verify-операции в строгую категорию rate-limit (отдельный лимит 5-10 req/min/пользователь). Совместно с SSRF-фильтрацией это ограничивает массовое злоупотребление исходящими запросами.

---

**Не проверено измерением security:** статически проверялись только редиректы httpx и DNS-rebinding — полноценная динамическая проверка не проводилась.

**Не проверено измерением bugs:** фактический прогон тестов (`tests/test_routers/test_ai_router.py` существует, но покрытие `ContextCompressor`, providers и SSE-пути отдельными тестами, судя по структуре `tests/`, отсутствует); поведение request-scoped сессии БД внутри SSE-генератора проверялось только статически по исходникам vendored FastAPI 0.135.3.


---

## 18. Backend: circuit breaker, sandbox, планировщик

Блок в целом рабочий: архитектура router-service-engine чистая, MSK-офсеты и Decimal используются последовательно, per-user asyncio.Lock в CB корректен. Но hot path circuit breaker страдает от N+1 запросов и хрупкого парсинга конфига, риск-проверка размера позиции игнорирует lot_size (лимит занижен в 10–100 раз), дневной лимит убытков обходится через stop/start сессий, а невалидный конфиг торговых часов или 2+ pending-сделки роняют check_before_order молча (сигналы теряются listener'ом без уведомления). Sandbox исполняет пользовательский код в общем процессе backend с расшифрованными брокерскими токенами: unbounded timeout способен исчерпать общий ThreadPoolExecutor приложения, а белые списки модулей рассинхронизированы между /analyze и /execute. Планировщик содержит мёртвый код (schedule_t1_unlock) и no-op синхронизацию календаря MOEX с ложным успешным логом — проект фактически живёт на fallback-календаре без учёта переносов праздников.

### 🟠 High

#### 🟠 Проверка max_position_size игнорирует lot_size — риск-лимит занижен в 10–100 раз — `backend/app/circuit_breaker/engine.py:322`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** В `_check_position_size_limit` для режима fixed_lots сумма ордера считается как `signal.price * position_sizing_value` (число лотов), без множителя lot_size. Реальная стоимость ордера в OrderManager: `volume_rub = price × volume_lots × lot_size` (engine.py:962), и там же в комментарии прямо указано, что при игнорировании lot_size сумма занижается в 10×. Пример: у пользователя max_position_size=50 000 ₽, сессия fixed_lots=20 по SBER (лот 10 акций, цена 300 ₽). CB посчитает 300×20=6 000 ₽ и пропустит ордер, а реальная сумма составит 300×20×10=60 000 ₽ — риск-лимит по размеру позиции фактически не работает для всех бумаг MOEX с лотом больше 1 (то есть для большинства акций). Верификация подтвердила полную цепочку: Signal.price — цена за акцию, position_sizing_value для fixed_lots — число лотов, check_before_order вызывается с исходным signal без коррекции на lot_size.

- **Рекомендация:** Получать lot_size через `MarketDataService.ensure_lot_size(session.ticker)` (как это уже делает OrderManager) и считать `order_amount = signal.price × lots × lot_size`; для режимов fixed_sum/percent сверяться с той же формулой, что использует `_calculate_position_size`.

#### 🟠 timeout в /sandbox/execute не валидируется и не ограничен сверху — DoS общего ThreadPoolExecutor backend — `backend/app/sandbox/schemas.py:17`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** Поле `timeout` в CodeExecuteRequest объявлено как `int | None` с комментарием «секунд, max 30», но без `Field(ge=1, le=30)`. В executor.py:68 `timeout = timeout or self.MAX_EXECUTION_TIME` — верхнего ограничения нет. Любой аутентифицированный пользователь (endpoint доступен без admin-прав) отправляет POST `/api/v1/sandbox/execute` с `timeout=86400` (или больше) и кодом `while True: pass` — `worker.join(timeout)` и `asyncio.wait_for(timeout+2)` честно ждут вплоть до суток и более. Прерывание через `PyThreadState_SetAsyncExc` не прерывает C-код/плотные аллокации, а заявленный лимит памяти MAX_MEMORY=512MB нигде не применяется (нет setrlimit). Несколько параллельных таких запросов исчерпывают общий default ThreadPoolExecutor всего процесса (размер `min(32, cpu+4)`) — зависают все остальные компоненты backend'а, использующие `run_in_executor`; rate-limit для этого пути общий (200/мин), что недостаточно для compute-эндпоинта. Отрицательный timeout уходит в join/alarm с неопределённым поведением. Верификация подтвердила весь путь эксплуатации по коду.

- **Рекомендация:** В схеме задать `timeout: int | None = Field(default=None, ge=1, le=30)`. В `CodeSandbox.execute` дополнительно клампить: `timeout = min(timeout or self.MAX_EXECUTION_TIME, self.MAX_EXECUTION_TIME)`. Исполнять код в изолированном ephemeral-процессе с жёстким лимитом памяти/CPU (resource.setrlimit) вместо общего ThreadPoolExecutor, добавить отдельную строгую категорию rate-limit для `/sandbox`. Также стоит либо реализовать MAX_MEMORY, либо убрать неиспользуемую константу.

#### 🟠 trading_hours_start/end не валидируются — конфиг произвольной строкой роняет check_before_order на каждом сигнале — `backend/app/circuit_breaker/schemas.py:18`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** CircuitBreakerConfigRequest принимает `trading_hours_start/end` как `str | None` без валидации формата. PUT `/api/v1/circuit-breaker/config` с значением `"10"`, `"abc"` или `"10-00"` успешно сохраняется. Далее в `_check_trading_hours` (engine.py:449-459) выполняется `parts = trading_hours_start.split(":"); time(int(parts[0]), int(parts[1]))` — IndexError/ValueError на каждом вызове `check_before_order`. Исключение вылетает из CB и ловится только широким except в listener (runtime.py:256): каждая свеча логирует ошибку, но ордера не выставляются и пауза CB не ставится — торговый цикл всех сессий пользователя молча «умирает», пока конфиг не будет исправлен вручную.

- **Рекомендация:** Добавить в схему валидатор формата (`Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")` или `field_validator` через `time.fromisoformat`). В engine дополнительно обернуть парсинг в try/except с fallback на DEFAULT_TRADING_START/END и warning-логом, чтобы некорректный конфиг не убивал hot path.

### 🟡 Medium

#### 🟡 N+1 на hot path circuit breaker: каждая проверка заново грузит config, user и список сессий — `backend/app/circuit_breaker/engine.py:96`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `check_before_order` вызывается на каждую закрытую свечу каждой активной сессии под глобальным per-user `asyncio.Lock`. При этом семь независимых проверок (`_check_daily_loss_limit`, `_check_max_drawdown`, `_check_position_size_limit`, `_check_daily_trade_limit`, `_check_cooldown`, `_check_trading_hours`, `_check_short_block`) каждая по отдельности вызывают `_get_config` (до 2 SELECT) и/или `_get_user`, а `_get_user_sessions` (JOIN из 3 таблиц) выполняется дважды. Итого ~15+ SQL-запросов на один сигнал вместо достаточных 4-5. Под lock'ом это сериализует все сессии пользователя: при 5-10 активных сессиях на минутных свечах задержки складываются.

- **Рекомендация:** В начале `check_before_order` один раз загрузить config (override+global), user и user_sessions и передавать их параметрами во все проверки. Это заодно устранит рассинхронизацию, когда разные проверки видят разные версии конфига.

#### 🟡 scalar_one_or_none() падает с MultipleResultsFound при 2+ открытых противоположных сделках — `backend/app/circuit_breaker/engine.py:398`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Запрос выбирает все LiveTrade со статусом filled/pending и противоположным направлением, но результат читается через `scalar_one_or_none()`, хотя строк может быть несколько (max_concurrent_positions допускает до 100). Сценарий: block_shorts выключен, в сессии 2+ открытых sell-сделок (в т.ч. ещё не исполненных pending), приходит buy-сигнал → `opposite="sell"` → запрос возвращает две строки → SQLAlchemy бросает `MultipleResultsFound`. Это относится и к сигналам выхода из позиции: `_is_exit_signal` в runtime смотрит только на status='filled', поэтому bypass не срабатывает и CB всё равно вызывается. Исключение убивает весь `check_before_order`, глушится широким except в listener'е (runtime.py:256) — сигнал молча теряется, и так повторяется на каждой следующей свече.

- **Рекомендация:** Заменить на `select(...).limit(1)` + `result.scalars().first()`, либо использовать `select(func.count(...))` и сравнивать с нулём — достаточно факта существования хотя бы одной противоположной позиции.

#### 🟡 Дневной лимит убытков и лимит сделок обходятся через stop/start сессий — `backend/app/circuit_breaker/engine.py:179`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `_get_user_sessions` выбирает только сессии со статусом active/paused, и именно этот список session_ids используется в `_check_daily_loss_limit` (сумма LiveTrade.pnl за торговый день) и `_check_daily_trade_limit` (счётчик сделок). Сценарий: пользователь утром потерял 40 000 ₽ в сессии A и остановил её (status='stopped'), затем запустил сессию B — убыток сессии A полностью исчезает из подсчёта дневного убытка, и CB позволит потерять ещё полный лимит в сессии B. Дневная защита капитала обходится обычным stop/start сессий; аналогично обнуляется счётчик daily_trade_limit.

- **Рекомендация:** Считать дневной P&L и число сделок по всем сессиям пользователя за торговый день независимо от статуса сессии (фильтровать только по времени closed_at/opened_at >= начало торгового дня, без фильтра по status).

#### 🟡 CircuitBreakerEvent всегда пишется с trigger_value=0 и limit_value=0 — поля мертвы с момента создания — `backend/app/circuit_breaker/engine.py:579`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `_trigger` всегда записывает `trigger_value=Decimal("0")` и `limit_value=Decimal("0")`, хотя модель объявляет их NOT NULL Numeric(18,2), а CircuitBreakerEventResponse отдаёт их в API. Реальные значения (размер убытка, процент просадки, лимит) существуют только внутри свободного текста `details` (русскоязычная f-строка, формат разный у каждой проверки — надёжно не распарсить). Пользователь в UI и любая аналитика по событиям CB видят нули; журнал срабатываний (GET /events) не позволяет понять, насколько был превышен лимит — данные для разбора инцидентов теряются безвозвратно.

- **Рекомендация:** Расширить CheckResult полями trigger_value/limit_value: Decimal, заполнять их в каждой `_check_*` (daily_loss/abs_limit, drawdown_pct/limit_pct, order_amount/max_size, trade_count/limit и т.д.) и прокидывать в `_trigger`. Либо честно удалить неиспользуемые столбцы миграцией.

#### 🟡 Session-override конфига молча игнорируется в _check_trading_hours и _check_short_block — `backend/app/circuit_breaker/engine.py:449`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Семь проверок читают конфиг через `_get_config(session.id)` (учитывая per-session override), но `_check_trading_hours` (строка 449) и `_check_short_block` (строка 480) вызывают `_get_config()` без session_id — только глобальный конфиг. Endpoint PUT `/api/v1/circuit-breaker/config/session/{id}` позволяет сохранить override с `block_shorts=false` или своими торговыми часами (например, окно 10:00–18:45), роутер вернёт 200 и сохранённую запись, но engine эти значения никогда не прочитает: short-сигналы сессии продолжат блокироваться, часы останутся глобальными (в 20:00 сигналы всё равно пройдут по дефолтным 10:00–23:50). Несогласованное поведение без ошибок — пользователь не поймёт, почему настройка «не работает».

- **Рекомендация:** Передавать `session.id` в обеих проверках (дополнить сигнатуры `_check_trading_hours`/`_check_short_block` параметром session). Либо явно задокументировать и запретить эти поля в session-override на уровне схемы.

#### 🟡 sync_moex_calendar — no-op: ISS-клиент никогда не передаётся, лог рапортует о несуществующем успехе — `backend/app/scheduler/service.py:45`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `SchedulerService` создаёт `MOEXCalendarService()` без iss_client (конструктор SchedulerService его вообще не принимает; main.py:146 передаёт только db_factory и notification_service). `load_calendar` при `_iss_client is None` сразу возвращается, но job после этого логирует `moex_calendar_synced year=...` — лог врёт об успешной синхронизации. Весь проект живёт на fallback-календаре (будни минус захардкоженный RUSSIAN_HOLIDAYS): переносы выходных и торговые субботы не учитываются (например, перенесённый праздник 2 мая считался бы торговым днём). Вдобавок потребители фрагментированы: `broker/tinvest/multiplexer.py:43` создаёт новый MOEXCalendarService на каждый вызов, `market_data/router.py:35` — свой; даже загруженный кеш никогда бы не разделился между потребителями. И третье: если клиент всё же подключить, `load_calendar` трактует begin/end из `/iss/.../dates.json` (диапазон доступности данных) как непрерывные торговые дни — в кэш попали бы все субботы/воскресенья.

- **Рекомендация:** Прокинуть MOEXISSClient в SchedulerService/MOEXCalendarService через DI, сделать календарь общим экземпляром (app.state), используемым multiplexer/router/scheduler. Лог успеха писать только при реальном обновлении кеша; при отсутствии клиента — warning. При реализации реального источника — фильтровать выходные при разворачивании диапазона дат.

#### 🟡 Unrealized PnL в дневной статистике считается без lot_size — занижен в разы — `backend/app/scheduler/service.py:364`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В `send_daily_stats` нереализованный PnL открытой позиции считается как `(last_price − entry) × qty`, где qty — количество лотов, без множителя lot_size. Канонический расчёт в `RiskMonitor._apply_close`: `(exit − entry) × lots × lot_size`. Пример: открыта позиция 5 лотов SBER (лот 10), цена выросла на 10 ₽ — реальный unrealized +500 ₽, в ежедневном отчёте пользователю придёт +50 ₽. Кроме того, в выборку попадают только сделки, открытые/закрытые сегодня, поэтому unrealized ранее открытых позиций вообще не отражается — строка «unreal» в отчёте систематически неверна. Метод дополнительно построен как ~226-строчный с N+1 запросами в тройном цикле (для каждой открытой сделки каждого пользователя — отдельный SELECT последнего close, плюс отдельный SELECT портфелей на пользователя): при 20 пользователях по 10 открытых позиций — 200+ последовательных запросов, метод фактически нетестируем по частям.

- **Рекомендация:** Получать lot_size через `MarketDataService.ensure_lot_size(session.ticker)` и умножать на него; добавлять в open_trades все filled-позиции сессии, а не только сегодняшние. Разбить метод на `_collect_day_trades()`, `_latest_prices(tickers)` (один запрос с GROUP BY по тикеру/таймфрейму) и `_build_user_report()`; портфели грузить одним запросом с группировкой по user_id.

#### 🟡 schedule_t1_unlock — мёртвый код, docstring модуля заявляет несуществующую задачу — `backend/app/scheduler/service.py:487`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** grep по production-коду показывает: `schedule_t1_unlock` не вызывается нигде, кроме собственного определения (NOT CONNECTED); реальная разблокировка T+1 сделана лениво в `paper_engine._auto_unblock_if_settled`. При этом docstring модуля перечисляет `schedule_t1_unlock` как одну из трёх активных задач планировщика — следующий разработчик будет искать логику здесь и не найдёт. Даже если бы метод использовался: DateTrigger-задачи живут в in-memory jobstore — рестарт backend'а терял бы запланированные разблокировки средств, механизм принципиально ненадёжен без persistent jobstore. Дополнительно: при подключении naive `unlock_at` был бы истолкован APScheduler как MSK, что сдвинуло бы unlock на 3 часа раньше срока.

- **Рекомендация:** Удалить `schedule_t1_unlock` и `_execute_t1_unlock` вместе с упоминанием в module docstring (по правилу проекта пометка NOT CONNECTED блокирует приёмку). Если планируется push-модель разблокировки — заводить `SQLAlchemyJobStore` для персистентности задач.

#### 🟡 Мутация общего safe_globals RestrictedPython через shallow copy — процесс-wide side effect — `backend/app/sandbox/executor.py:101`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `restricted_globals = safe_globals.copy()` — поверхностная копия: ключ `__builtins__` указывает на тот же словарь `safe_builtins` из `RestrictedPython.Guards`. Строка `restricted_globals["__builtins__"]["__import__"] = _safe_import` мутирует библиотечный глобальный объект на весь процесс: после первого execute любой другой код, взявший `safe_globals` (будущие потребители RestrictedPython в проекте), молча получит включённый `__import__`. Классический межзапросный side effect на shared state; сейчас безвреден только потому, что sandbox — единственный потребитель и значение всегда одно и то же.

- **Рекомендация:** Копировать builtins отдельно: `builtins = dict(safe_globals["__builtins__"]); builtins["__import__"] = _safe_import; restricted_globals["__builtins__"] = builtins`.

#### 🟡 WHITELIST_MODULES анализатора не согласован с _safe_import исполнителя — противоречивая валидация /analyze vs /execute — `backend/app/sandbox/ast_analyzer.py:65`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `ASTAnalyzer.WHITELIST_MODULES` разрешает backtrader, pandas, numpy, ta, collections, itertools, functools, typing и др., но `_safe_import` в executor.py пропускает только math, decimal, datetime. Сценарий: пользователь вызывает POST `/sandbox/analyze` с кодом `import pandas as pd` — ответ `is_valid=true`; затем POST `/sandbox/execute` с тем же кодом — `ImportError "Import of 'pandas' is not allowed in sandbox"`. Два endpoint'а одного модуля дают противоречащие вердикты об одном и том же коде — контракт API несогласован, пользователь конструктора стратегий получает ложноположительную валидацию.

- **Рекомендация:** Вынести единый источник правды (одна константа ALLOWED_MODULES, импортируемая и анализатором, и `_safe_import`), либо расширить `_build_safe_modules` до фактически поддерживаемого списка и сузить WHITELIST_MODULES до него же.

### 🔵 Low

#### 🔵 get_status опирается на приватные методы engine и делает портфельный цикл по сессиям вместо одного запроса — `backend/app/circuit_breaker/service.py:120`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `CircuitBreakerService.get_status` вызывает `engine._get_config()`, `engine._get_user()`, `engine._get_trading_day_start()`, `engine._get_user_sessions()` — четыре приватных метода чужого класса; граница service/engine размыта, рефакторинг engine молча ломает service. Далее — отдельный SELECT PaperPortfolio на каждую сессию пользователя в цикле вместо одного запроса с IN. Комментарий «Drawdown — по первой активной сессии (упрощение)» устарел: код на деле берёт максимум по всем сессиям.

- **Рекомендация:** Сделать нужные методы engine публичными или вынести общие выборки в отдельный queries-модуль. Портфели — `select(PaperPortfolio).where(PaperPortfolio.session_id.in_(session_ids))` одним запросом. Комментарий поправить.

#### 🔵 Мёртвая ветка signal.alarm в _run_sandboxed — недостижима в production — `backend/app/sandbox/executor.py:112`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_run_sandboxed` передаётся в `loop.run_in_executor(None, ...)` — всегда исполняется в worker-потоке ThreadPoolExecutor, поэтому `threading.current_thread() is threading.main_thread()` всегда False: ветка с `signal.signal`/`signal.alarm` недостижима в production. Реально работает только else-ветка, которая порождает ещё один поток внутри executor-потока (два потока на одно выполнение) и прерывает его через `ctypes.PyThreadState_SetAsyncExc`. Мёртвый код с сигналами вводит в заблуждение при сопровождении и создаёт иллюзию надёжного таймаута.

- **Рекомендация:** Удалить main-thread ветку и импорт signal; оставить единственный путь worker-thread + `join(timeout)` + `SetAsyncExc`, задокументировав ограничения (C-код таким образом не прерывается).

#### 🔵 Дублирование торгового расписания MOEX и таймзоны между engine и MOEXCalendarService — `backend/app/circuit_breaker/engine.py:31`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** engine.py заводит собственные константы `MSK_OFFSET=timezone(timedelta(hours=3))` и `DEFAULT_TRADING_START/END` (10:00–23:50), тогда как `scheduler/moex_calendar.py` уже содержит `MOSCOW_TZ=ZoneInfo("Europe/Moscow")` и точное расписание (10:00–18:50 основная, 19:05–23:50 вечерняя). Два источника правды: CB разрешает ордера в клиринговый перерыв 18:50–19:05 и вообще не проверяет выходные/праздники (только время суток) — в субботу `_check_trading_hours` пропустит сигнал, хотя рядом уже существует `is_trading_day()`. Изменение расписания MOEX потребует правок в двух местах.

- **Рекомендация:** Переиспользовать MOEXCalendarService (общий экземпляр) в `_check_trading_hours`: `is_trading_day` + оба интервала сессий; `MSK_OFFSET` заменить на `MOSCOW_TZ` (проектная конвенция — Europe/Moscow).

#### 🔵 Несогласованная граница «дня»: realized PnL с 10:00 MSK, unrealized — по date.today() сервера — `backend/app/circuit_breaker/engine.py:243`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_check_daily_loss_limit` суммирует realized PnL от `_get_trading_day_start()` (10:00 MSK, timezone-aware), а unrealized из DailyStat фильтрует по `DailyStat.date == date.today()` — локальная дата сервера без таймзоны. При деплое в другой TZ или в интервале 00:00–10:00 MSK realized относится к предыдущему торговому дню, а unrealized — к календарному «сегодня»: лимит дневного убытка считается по смеси двух разных дней. Заодно inline-import `from datetime import date as date_type` посреди метода — против конвенций проекта.

- **Рекомендация:** Вычислять дату торгового дня из `_get_trading_day_start()`: `trading_date = trading_day_start.astimezone(MOSCOW_TZ).date()` и использовать её в фильтре DailyStat. Импорт date поднять в шапку модуля.

#### 🔵 «Портфель» в дневной статистике суммирует балансы всех сессий, включая остановленные — `backend/app/scheduler/service.py:410`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `portfolio_stmt` выбирает `PaperPortfolio.balance` по всем сессиям пользователя без фильтра по статусу сессии и без учёта `blocked_amount`. Сценарий: пользователь за месяц создал 10 paper-сессий по 100 000 ₽ и все остановил, активна одна — отчёт покажет «Портфель: ~1 000 000 ₽». Плюс для активных сессий с открытыми позициями balance не включает blocked_amount (стоимость позиций), т.е. цифра дополнительно занижена на размер открытых позиций.

- **Рекомендация:** Фильтровать по `TradingSession.status in ('active','paused')` и суммировать `balance + blocked_amount` (equity, как в `_check_max_drawdown`).

#### 🔵 Нет проверки владельца session_id при сохранении session-override конфига CB — `backend/app/circuit_breaker/router.py:51`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** PUT `/api/v1/circuit-breaker/config/session/{session_id}` вызывает `service.upsert_config(current_user.id, data, session_id=session_id)` без проверки, что session_id принадлежит текущему пользователю. Атакующий передаёт чужой session_id и создаёт CircuitBreakerConfig, привязанный к своему user_id и чужому session_id. Прямого cross-user эффекта нет: `engine._get_config` фильтрует по `user_id==self.user_id`, конфиг не применится к сессии жертвы; но это missing-authz на изменяющей операции и создание мусорных записей на чужие сущности (FK ondelete=CASCADE).

- **Рекомендация:** Перед upsert проверять владение: join `TradingSession` → `StrategyVersion` → `Strategy.user_id == current_user.id`; иначе возвращать 403/404.

---

**Отклонено при верификации:**

- «Sandbox: AST-анализатор не проверяет строковые литералы — обход dunder-защиты через str.format» (`backend/app/sandbox/ast_analyzer.py:95`) — PoC не воспроизвёлся: `_getattr_` в executor.py — это `RestrictedPython.Guards.safer_getattr`, который явно проверяет `name in ('format', 'format_map')` для str и кидает `NotImplementedError`; f-string/%-формат с dunder блокируются уже на этапе `compile_restricted` (SyntaxError). ASTAnalyzer не единственный рубеж защиты — executor добавляет второй эшелон (compile_restricted + safer_getattr), закрывающий этот вектор атаки.


---

## 19. Backend: common, CLI, бэкапы, админка, налоги, корп. действия и пр.

Блок в целом аккуратный: `chart_drawings` и `user_favorites` — образцовые модули (ownership-проверки, идемпотентность, валидация), `backup`/`cli` хорошо структурированы (executor для блокирующего I/O, asyncio.Lock). Главные проблемы сосредоточены в `tax/service.py`: проглоченный `except Exception` без traceback и error_message, потерянный `tax_amount`, блокирующий экспорт в event loop, naive-UTC границы года, хрупкая эвристика типа инструмента — модуль про деньги, но наименее доведён. Системные темы: дублирование торговых часов (common vs circuit_breaker) без учёта выходных, приватный `_get_client` ISS-клиента в `corporate_actions`, N+1 в детекции/обработке корп. действий, mock-данные в `/admin/metrics` при сдаче. Тесты на все модули блока существуют (unit/test_tax, test_corporate_actions, test_backup и др.), их содержимое по условию не проверялось; alembic-миграции и фронтенд-потребители контрактов не смотрели.

### 🟡 Medium

#### 🟡 Рассчитанный налог (tax_amount) и разбивка by_type вычисляются и выбрасываются — `backend/app/tax/service.py:281`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_calculate_tax_base` считает `tax_amount` (прогрессивная ставка 13%/15%) и `by_type` (share/bond/etf), возвращает их в dict, но `generate_report` читает только total_profit/total_loss/total_commission/taxable_base. В модели `TaxReport` и в `TaxReportResponse` поля `tax_amount` нет вовсе (grep по проекту: `tax_amount` встречается только внутри service.py). Итог: пользователь запрашивает отчёт 3-НДФЛ, а сумма налога — главное число отчёта — нигде не сохраняется, не возвращается API и не попадает в xlsx/csv (в файле только taxable_base). Мёртвое вычисление + функционально неполный отчёт.

- **Рекомендация:** Добавить колонку tax_amount (Numeric(18,2)) в TaxReport и поле в TaxReportResponse, записывать его в generate_report и выводить в xlsx/csv (строка «Налог к уплате»). Разбивку by_type либо использовать (раздельные секции в отчёте — так заявлено в docstring), либо удалить из возврата.

#### 🟡 Широкий except Exception в generate_report: причина ошибки теряется, клиент получает 200 без деталей — `backend/app/tax/service.py:96`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Весь пайплайн генерации (загрузка сделок, FIFO, расчёт, экспорт файла) обёрнут в `except Exception: report.status='error', logger.error(error=str(e))` — без exc_info/traceback. В БД нет поля error_message, клиенту возвращается HTTP 200 с отчётом в статусе error и пустыми полями. Сценарий: нет прав на data/tax_reports или не установлен openpyxl → пользователь видит «ошибка» без причины, а в логе только "[Errno 13] Permission denied" без stack trace — на каком из 6 шагов упало, не определить. Дополнительно: TaxLot'ы, добавленные в сессию до падения экспорта, всё равно коммитятся (commit вне try).

- **Рекомендация:** Логировать через logger.exception (или exc_info=True), добавить TaxReport.error_message и возвращать его в схеме; при ошибке откатывать добавленные лоты (коммитить их только при успехе).

#### 🟡 Блокирующий файловый I/O (openpyxl, csv) внутри async-эндпоинта без run_in_executor — `backend/app/tax/service.py:350`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_export_xlsx`/`_export_csv` объявлены async, но выполняют синхронные `wb.save()`, `open()`/csv.writer прямо в event loop. Приложение — однопроцессный монолит: в том же loop живут trading engine, gRPC-стримы котировок и WebSocket'ы. Сценарий: пользователь в торговые часы генерирует отчёт за год с тысячами сделок — построение workbook и запись файла занимают секунды, на это время замирает обработка сигналов/стоп-лоссов и все WS-клиенты. Контраст: соседний BackupService аккуратно выносит все блокирующие операции в `loop.run_in_executor` — конвенция в проекте есть, здесь нарушена.

- **Рекомендация:** Обернуть построение workbook/CSV и сохранение файла в `await loop.run_in_executor(None, ...)` по образцу BackupService (и убрать бессмысленный async у самих экспортёров).

#### 🟡 Границы налогового года считаются в naive UTC вместо Europe/Moscow — `backend/app/tax/service.py:112`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** closed_at хранится как naive UTC (см. docstring app/common/datetime_utils.py), а фильтр года — `datetime(year,1,1)…datetime(year,12,31,23,59,59)` без TZ-конверсии. Налоговый год для 3-НДФЛ определяется по московскому времени. Сценарий: сделка закрыта 01.01.2027 в 01:30 MSK (вечерняя сессия) = 31.12.2026 22:30 UTC — попадёт в отчёт за 2026, хотя относится к 2027; и наоборот — сделки 31.12 после 21:00 UTC выпадают из отчёта года. Плюс верхняя граница `<=23:59:59` теряет записи с дробными секундами последней секунды. Готовый MSK_OFFSET из common/trading_hours.py не используется.

- **Рекомендация:** Считать границы в MSK и конвертировать в naive UTC (astimezone(UTC).replace(tzinfo=None)); верхнюю границу задавать полуинтервалом `closed_at < начало следующего года`.

#### 🟡 Эвристика _detect_instrument_type классифицирует акции с префиксом RU/SU как облигации + warning-спам — `backend/app/tax/service.py:419`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Любой тикер, начинающийся с SU/RU/XS, считается облигацией. Сценарий: RUAL (РУСАЛ — акция MOEX) → 'bond': сделка попадает не в ту группу, к ней применяется НКД-логика, а при include_bonds=False она вообще выпадает из налогового отчёта — занижение базы. Захардкоженный список ETF из 9 тикеров молча устаревает (LQDT, AKME и т.д. посчитаются акциями). Вдобавок дефолтная ветка 'share' пишет logger.warning на КАЖДУЮ сделку самого массового типа — спам в логах.

- **Рекомендация:** Брать instrument_type из данных инструмента (T-Invest InstrumentInfo / MOEX ISS), как в TODO — до сдачи. Минимум: сузить префиксы до реальных SECID-паттернов ОФЗ (напр. `SU\d{5}`), вынести списки в конфиг, warning логировать один раз на тикер.

#### 🟡 TaxLot не связан с TaxReport: дубликаты лотов при каждой генерации отчёта — `backend/app/tax/service.py:84`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** У TaxLot нет FK на tax_reports (только user_id). generate_report при каждом вызове создаёт и коммитит полный набор лотов по тем же сделкам. Сценарий: пользователь трижды перегенерировал отчёт за 2026 (менял фильтры include_*) — в tax_lots лежат 3 перекрывающихся набора строк без привязки к отчёту/фильтрам; таблица растёт неограниченно, а любая будущая агрегация tax_lots по user_id+году завысит PnL втрое. Лоты от прогонов со status='error' тоже остаются.

- **Рекомендация:** Добавить `tax_lots.report_id` (FK, ondelete=CASCADE), при регенерации удалять/заменять старые лоты. Либо, если лоты нужны только для файла, не персистить их вовсе.

#### 🟡 Дублирование торговых часов с circuit_breaker и игнорирование выходных/конфига — `backend/app/common/trading_hours.py:19`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** MSK_OFFSET/DEFAULT_TRADING_START/DEFAULT_TRADING_END определены дважды: здесь и в circuit_breaker/engine.py:31-35 (docstring признаёт: «в будущем — общий источник»). Circuit breaker читает настраиваемые trading_hours_start/end из БД, а is_within_trading_hours (pre-check ручного закрытия позиции, trading/engine.py:1547) — всегда хардкод 10:00-23:50 без учёта дня недели. Сценарий: суббота 12:00 MSK — pre-check пропускает, ордер уходит в T-Invest и падает «непонятным gRPC-фейлом» — ровно тем, от которого pre-check по BUG-10 должен защищать. И при изменении часов в конфиге circuit breaker две проверки расходятся.

- **Рекомендация:** Сделать common/trading_hours.py единственным источником (circuit_breaker импортирует константы), прокидывать конфиг часов и учитывать weekday()<5 / торговый календарь MOEX (уже доступен через MOEXISSClient.get_trading_calendar).

#### 🟡 Нарушение границы модуля: обращение к приватному _get_client() ISS-клиента и ручной парсинг ISS-ответа — `backend/app/corporate_actions/service.py:194`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** detect_corporate_actions вызывает `iss_client._get_client()` (приватный метод чужого модуля broker/moex_iss) и сам формирует URL `/iss/securities/{ticker}/dividends.json` + парсит columns/data-формат ISS. У MOEXISSClient есть публичные методы и единый `_request` с обработкой ошибок — логика парсинга ISS-таблиц размазана по двум модулям. Сценарий: рефакторинг клиента (переименование _get_client, смена схемы пула/ретраев) молча ломает детекцию корп. действий — зависимость идёт мимо публичного контракта и тестов клиента.

- **Рекомендация:** Добавить в MOEXISSClient публичный метод `get_dividends(ticker) -> list[dict]`, инкапсулирующий URL и разбор columns/data (по образцу get_trading_calendar), и вызывать его из CorporateActionService.

#### 🟡 N+1 запросы: existence-check на каждую строку дивидендов и SELECT портфеля/статистики на каждый trade — `backend/app/corporate_actions/service.py:223`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В detect_corporate_actions для каждой строки истории дивидендов каждого тикера выполняется отдельный SELECT CorporateAction (50 тикеров × 20 исторических записей ≈ 1000 запросов за прогон планировщика). В process_dividend/process_coupon внутри цикла по (trade, session) на каждый trade делаются отдельные SELECT PaperPortfolio и DailyStat — при 10 сделках одной сессии один портфель грузится 10 раз. На SQLite с единственным writer'ом это удлиняет транзакции джоба и провоцирует «database is locked» для параллельных бэктестов (известная боль проекта, см. persist_with_retry).

- **Рекомендация:** В detect: одним SELECT загрузить существующие (action_type, ex_date) по тикеру в set и проверять в памяти (uq_corp_action уже страхует от гонок). В process_*: предзагрузить PaperPortfolio/DailyStat по session_id IN (...) в dict до цикла.

#### 🟡 Страница /admin/metrics целиком на захардкоженных mock-данных при сдаче в production — `backend/app/admin/metrics_dash.py:70`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Все 4 графика (signal→order latency, LCP, Telegram latency, backtest jobs) построены на массивах констант, зашитых в код; TODO «заменить после BACK1 W2 observability» не выполнен, хотя @timed_event-инструментирование в проекте уже есть. Пометка «MOCK» — только в заголовках графиков. Сценарий: админ после сдачи видит правдоподобные p95=395мс при SLA 500мс и делает вывод, что система укладывается в бюджет, хотя реальные данные вообще не собираются. Плюс используется deprecated `datetime.utcnow()` (Python 3.12).

- **Рекомендация:** До сдачи либо подключить реальный источник (агрегация timed_event из логов/таблицы метрик), либо показывать явную заглушку «метрики не собираются» вместо фиктивных чисел. datetime.utcnow() заменить на datetime.now(timezone.utc).

### 🔵 Low

#### 🔵 Несогласованный учёт комиссии: realized_pnl использует commission_total, а в лоты пишется 2×округлённая половина — `backend/app/tax/service.py:183`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** commission_half = round(commission_total/2) записывается и в commission_entry, и в commission_exit, но realized_pnl вычитает исходный commission_total. Для нечётной комиссии (0.05 ₽ → half=0.03) сумма по лоту = 0.06 ≠ 0.05: total_commission в отчёте (сумма entry+exit в _calculate_tax_base) систематически расходится с комиссией, фактически учтённой в PnL, на 1 копейку на сделку — в налоговом документе колонки «Комиссия» и «Финансовый результат» не бьются между собой.

- **Рекомендация:** Писать commission_entry = round(total/2), commission_exit = total − commission_entry, чтобы сумма половин всегда равнялась total; либо в realized_pnl вычитать (commission_entry + commission_exit).

#### 🔵 rotate() не удаляет sidecar-файлы -wal/-shm; before_restore-копии накапливаются бессрочно — `backend/app/backup/service.py:226`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** _copy_sqlite при активном WAL копирует backup_X.sqlite-wal/-shm рядом со снапшотом, но _iter_backup_files фильтрует по suffix ∈ {.sqlite, .dump} (для 'backup_X.sqlite-wal' Path.suffix = '.sqlite-wal') — rotate() удалит backup_X.sqlite, а его wal/shm останутся сиротами в backups/. Аналогично _restore_sqlite создаёт полноразмерную копию `<db>.before_restore_<ts>` при каждом restore и никто её не ротирует — на Mac mini с ежедневным бэкапом и парой restore диск постепенно забивается мёртвыми копиями БД.

- **Рекомендация:** В rotate() при удалении основного файла удалять и парные .sqlite-wal/.sqlite-shm; добавить чистку старых *.before_restore_* (оставлять последний).

#### 🔵 Дублирование JWT-валидации из middleware/auth.py + молчаливые except Exception: pass — `backend/app/admin/dash_mount.py:50`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** AdminAuthASGIMiddleware заново реализует цепочку jwt.decode → type=='access' → загрузка User → is_active/is_admin, которая уже есть в middleware/auth.py (get_current_user + require_admin). При изменении семантики токена (алгоритм, claims, blacklist) два места разойдутся — mount-точка Dash продолжит принимать токены по старым правилам. В _extract_token два блока `except Exception: pass` глотают ошибки разбора заголовков без логирования — при кривом Authorization-заголовке админ получает 401 «Missing authentication token» и по логам причину не восстановить.

- **Рекомендация:** Вынести валидацию токена и проверку админа в общие функции в app/middleware/auth.py и переиспользовать их и в dependency, и в ASGI-middleware. Except'ы сузить и логировать debug-сообщение.

#### 🔵 Несогласованное объявление префиксов роутеров: конвенция prefix в APIRouter нарушена в 4 модулях — `backend/app/tax/router.py:14`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Конвенция проекта (Develop/CLAUDE.md): «Каждый роутер: APIRouter(prefix="/api/v1/{module}", tags=[...])». По факту tax, corporate_actions, chart_drawings, user_favorites создают голый APIRouter(), префиксы и теги разбросаны по main.py; admin — наоборот, задаёт prefix в роутере. Сценарий: разработчик копирует существующий модуль как образец и получает роутер, молча регистрируемый на неожиданном пути; источник истины о URL модуля в самом модуле отсутствует (в chart_drawings путь описан только в docstring).

- **Рекомендация:** Привести все роутеры к конвенции: prefix и tags задавать в APIRouter внутри модуля, main.py — только include_router(router).

#### 🔵 Мёртвый файл-заглушка pagination.py; list-эндпоинты без пагинации грузят всё в память — `backend/app/common/pagination.py:1`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** common/pagination.py содержит единственный комментарий «will be implemented in later sprints» — проект сдаётся, файл мёртвый. Симптоматично: get_actions (corporate_actions) и другие list-эндпоинты возвращают неограниченные списки — после пары лет работы detect-джоба corporate_actions накопит тысячи записей, и GET /api/v1/corporate-actions/ каждый раз будет сериализовать всю таблицу в память/JSON без limit/offset.

- **Рекомендация:** Либо реализовать общий limit/offset-хелпер и применить к list-эндпоинтам (минимум corporate_actions), либо удалить пустой файл и добавить limit по умолчанию прямо в get_actions.


> **Дополнение (добор упавших измерений «Баги» и «Уязвимости»).** Ниже — находки, полученные при повторном ревью после сбоя двух измерений блока. Часть пересекается с уже перечисленными выше находками измерения «Качество кода» (в частности, TZ-баг границ налогового года) — в таких случаях справедлива более высокая severity из указанных.

### 🔴 Critical

#### 🔴 Реверс-сплит обнуляет позицию из-за усечения `int()` — `backend/app/corporate_actions/service.py:52`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено (чтением кода)

- **Проблема:** В `process_split` объём пересчитывается как `int(old_volume * ratio_to / ratio_from)` с усечением к нулю. При обратном сплите (консолидации), например ratio_from=10, ratio_to=1 и позиции в 5 лотов, результат `int(5 * 1 / 10) = int(0.5) = 0` — позиция молча обнуляется, лоты и их стоимость теряются. Аналогично `filled_lots`. При этом `entry_price` домножается на `ratio_from/ratio_to` (растёт в 10 раз), но объём уже 0, так что учёт позиции полностью разрушается. Даже при прямом сплите любые дробные остатки отбрасываются без переноса стоимости в баланс.

- **Рекомендация:** Не усекать вслепую: для консолидаций округлять по правилам биржи и компенсировать дробную часть денежной выплатой (cash-in-lieu) в баланс/PnL, либо блокировать сплит и уведомлять, если `old_volume * ratio_to % ratio_from != 0`. Как минимум использовать корректное округление вместо `int()` и логировать потерю дробной части.

### 🟠 High

#### 🟠 `AdminAuthASGIMiddleware` не привязывает JWT к отзыву токена (`token_version`) — `backend/app/admin/dash_mount.py:112`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** ASGI-гейт для Dash-метрик валидирует только подпись и `type=access`, затем грузит юзера по `sub` и проверяет `is_active`/`is_admin`. В отличие от основного `get_current_user` (который проверяет отзыв токена — `middleware/auth.py:34`), здесь нет проверки чёрного списка/`token_version`. Отозванный, но ещё не истёкший access-токен админа даёт доступ к `/api/v1/admin/metrics`. Дополнительно `int(payload.get('sub', 0))` при отсутствии `sub` даёт `user_id=0`, а не отказ — хрупкий fallback.

- **Рекомендация:** Переиспользовать общую логику проверки токена (включая отзыв/`token_version`), а не дублировать урезанную версию. Явно отклонять отсутствующий/нулевой `sub` (`401`).

#### 🟠 Годовой фильтр налогового отчёта смешивает локальное время и naive UTC — `backend/app/tax/service.py:112`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено (пересечение с находкой измерения «Качество», severity повышена до High)

- **Проблема:** `year_start`/`year_end` строятся как `datetime(year, 1, 1)` — naive без TZ, и сравниваются с `LiveTrade.closed_at`, который по контракту хранится как **naive UTC**. Для биржи Europe/Moscow (UTC+3) сделки, закрытые в первые ~3 часа 1 января по МСК, имеют `closed_at` в предыдущем UTC-годе (или наоборот на границе 31 декабря) и попадут не в тот налоговый период — искажение 3-НДФЛ на границах года.

- **Рекомендация:** Считать границы года в МСК и переводить в UTC перед сравнением, либо явно приводить обе стороны к одной TZ-семантике.

#### 🟠 `_calculate_tax_base` нетит убытки между разными типами инструментов — `backend/app/tax/service.py:260`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `taxable_base = max(0, total_profit + total_loss)` суммирует прибыли и убытки по всем инструментам вместе, хотя `by_type` (акции/облигации/ETF) уже считается раздельно и далее не используется. В РФ налоговые базы по разным категориям считаются раздельно, и убыток одной категории не всегда уменьшает прибыль другой. Смешивание искажает налоговую базу и делает отчёт некорректным для подачи.

- **Рекомендация:** Считать налоговую базу отдельно по категориям (использовать готовый `by_type`), применять `max(0, ...)` к каждой группе согласно правилам НК РФ.

### 🟡 Medium

#### 🟡 `POST /corporate-actions/detect` — тяжёлые внешние запросы по произвольным тикерам без ограничений — `backend/app/corporate_actions/router.py:79`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** Эндпоинт доступен любому аутентифицированному пользователю и принимает произвольный `tickers: list[str]` без ограничения длины и без rate-limit. Каждый тикер порождает синхронно-последовательный внешний HTTP-запрос к MOEX ISS. Запрос со списком в тысячи тикеров — усилитель нагрузки (DoS на ISS и на собственный event loop) и пишет в общую таблицу. Тикеры не валидируются и идут прямо в URL.

- **Рекомендация:** Ограничить размер списка (`Field(max_length=...)`), валидировать формат тикера, добавить rate-limit, выполнять детекцию фоновой задачей. Рассмотреть ограничение до админ-роли.

#### 🟡 `rotate()` бэкапов не берёт `asyncio.Lock` и падает на исчезнувшем файле — `backend/app/backup/service.py:136`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `BackupService` использует один `asyncio.Lock` для `create`/`restore`, но `rotate()` его НЕ берёт. Ротация вычисляет `sorted(..., key=lambda p: p.stat().st_mtime)` и затем `unlink()`; между `_iter_backup_files()` и `stat()` файл может исчезнуть — `stat()` в ключе сортировки бросит непойманный `FileNotFoundError`, и джоб ротации упадёт.

- **Рекомендация:** Брать тот же `self._lock` в `rotate()`; ключ сортировки сделать устойчивым к исчезновению файла (ловить `OSError`).

#### 🟡 `process_split`/`process_dividend`/`process_coupon` затрагивают позиции всех пользователей и не откатываются при частичном сбое — `backend/app/corporate_actions/service.py:37`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Запросы фильтруют открытые `LiveTrade` только по `TradingSession.ticker`, и каждый обработчик делает собственный `commit()`. В `process_pending` действия обрабатываются в цикле: если после успешного (уже закоммиченного) `process_split` следующее действие бросает исключение — откатить применённый сплит нельзя. Плюс дивиденд начисляется на позиции в статусе `open` (ещё не исполненные), что завышает выплату.

- **Рекомендация:** Обрабатывать пачку действий в одной транзакции (или хранить маркеры идемпотентности на уровне позиции); начислять дивиденд/купон только по `filled`-позициям с ненулевым `filled_lots`.

### 🔵 Low

#### 🔵 `record_date` корп. действия ошибочно приравнивается к `ex_date` — `backend/app/corporate_actions/service.py:236`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** При детекции дивидендов `record_date=ex_date_parsed`, тогда как значение берётся из `registryclosedate` MOEX ISS (дата закрытия реестра = record date, а не ex-dividend date). Оба поля заполняются одним значением, семантика ex-date/record-date теряется.

- **Рекомендация:** Разделить источники (ex-date отдельно по правилам MOEX) либо явно пометить, что хранится record date.

#### 🔵 HKDF без соли для деривации ключа шифрования брокерских ключей — `backend/app/common/crypto.py:26`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `_derive_key` вызывает HKDF с `salt=None` (комментарий признаёт «salt can be added later»). Без соли деривация детерминирована от `master_key`; при компрометации мастер-ключа нет доменного разделения. Для GCM не критично (IV случаен), но снижает запас прочности и усложняет ротацию.

- **Рекомендация:** Добавить постоянную соль (из конфига/секрета) в HKDF и версионировать схему деривации для безопасной ротации мастер-ключа.


---

## 20. Frontend: сетевой слой (api, services, hooks)

Просмотрены все production-файлы в `frontend/src/api` (17-18 файлов), `frontend/src/services` (1 файл) и `frontend/src/hooks` (7 файлов), суммарно ~2650 строк. Слои API хорошо типизированы, есть type-guard'ы для paginated-ответов и комментарии, фиксирующие исторические баги (Stack Gotchas S7R/S8/gotcha-16). Главная системная проблема — рассинхрон Decimal↔string между backend Pydantic и frontend: `backtestApi.ts` типизирует Decimal-поля backend (net_profit, sharpe_ratio, entry_price и др.) как `number` вместо `string`, что уже приводит к риску рантайм-ошибки `toFixed()`. Вторая системная проблема — тройное дублирование WebSocket reconnect/auth-логики между хуками, при этом реально используемый в проде `useBackgroundBacktestsBootstrap` не переподключается при обрыве соединения, а старый общий `useWebSocket.ts` продолжает передавать JWT в query string, хотя параллельные хуки уже перешли на безопасную схему auth-первым-сообщением. Дополнительно найдены хранение JWT access/refresh токенов в localStorage, `as never`/`as number` касты, отключающие проверку типов на границе WS-delta → store, и дублирование логики refresh JWT-токена между `client.ts` и `aiStreamClient.ts` без общего мьютекса.

### 🟠 High

#### JWT access/refresh токены передаются в query string общего WebSocket-канала — `frontend/src/hooks/useWebSocket.ts:23`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** `getWsUrl()` формирует `ws://.../ws?token=<jwt>` — токен уходит в URL, оседает в браузерной истории, логах reverse-proxy/nginx/CDN, Referer и devtools Network-панели. Соседние хуки `useTradingSessionsWS.ts` (gotcha-16) и `useBacktestJobWS.ts` уже используют безопасный паттерн — передают JWT первым WS-сообщением `{action:'auth', token}` после открытия сокета. `useWebSocket.ts` (общий мультиплексированный `/ws` для market/trades/notifications/health, используется в CandlestickChart.tsx, HealthWidget.tsx, NotificationBell.tsx, SessionDashboard.tsx, ChartPage.tsx) остался на старой уязвимой схеме. Верификация трассы: backend `app/backtest/ws.py:20-37` (`_authenticate_ws`, смонтирован в `main.py:42,359` как `/ws`) читает JWT строго из `query_params.get("token")`, иначе `close(4001)` — альтернативы на backend нет.

- **Рекомендация:** Привести `useWebSocket.ts` к паттерну `useTradingSessionsWS.ts`/`useBacktestJobWS.ts`: открывать сокет без токена в URL, отправлять `{action:'auth', token}` первым сообщением после `onopen`, ждать `auth_ok`/`auth_error` от сервера перед подпиской на каналы. Потребует согласованного изменения на backend (`app/backtest/ws.py`), так как текущий backend поддерживает только query-param.

#### JWT access/refresh токены персистятся в localStorage — компрометация сессии при любом XSS — `frontend/src/stores/authStore.ts:145`

- **Категория:** уязвимость  |  **Верификация:** ⚠️ не опровергнуто

- **Проблема:** `persist` middleware Zustand сохраняет `token` и `refreshToken` в `localStorage` под ключом `auth-storage` (partialize включает оба поля). `client.ts` и `aiStreamClient.ts` читают токен и кладут в заголовок `Authorization: Bearer`. Любой XSS в приложении (сторонний npm-пакет, Blockly-плагин и т.п.) даёт атакующему доступ к обоим токенам, включая long-lived refresh_token, которым можно продлевать сессию даже после смены пароля жертвой, если backend не ревокирует refresh_token при смене пароля. Backend уже частично поддерживает HttpOnly cookie (для Plotly Dash), т.е. инфраструктура для более безопасной схемы частично есть, но SPA-флоу на неё не переведён.

- **Рекомендация:** Перевести аутентификацию SPA полностью на HttpOnly+Secure+SameSite cookie (аналогично уже существующей cookie для Plotly Dash), отказаться от чтения token в JS и от Bearer-заголовка для browser-flow. Если полный переход невозможен в текущем спринте — минимум не хранить refresh_token в localStorage (только в памяти/HttpOnly cookie).

#### Decimal-поля BacktestMetrics/BacktestTrade/EquityPoint типизированы как number вместо string — риск TypeError в проде — `frontend/src/api/backtestApi.ts:38`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Backend `app/backtest/schemas.py` (BacktestMetrics: net_profit, net_profit_pct, win_rate, profit_factor, max_drawdown_pct, sharpe_ratio, avg_profit_per_trade, avg_loss_per_trade; BacktestTrade.entry_price/exit_price/pnl/pnl_pct/commission; EquityPoint.equity/drawdown — все Decimal) сериализует Decimal как JSON-строку (Pydantic v2 без json_encoders/PlainSerializer, задокументировано в проекте как Stack Gotcha #1, `api/types.ts:82-87`). Frontend же типизирует эти поля в `backtestApi.ts` как `number`. Практическое следствие: `MetricsGrid.tsx` вызывает `netProfitPct.toFixed(1)` (проп из `BacktestResultsPage.tsx:290`) на значении, приходящем строкой — `String.prototype.toFixed` не существует, что бросает `TypeError: netProfitPct.toFixed is not a function` и ломает страницу результатов бэктеста. Другой потребитель, `StrategyTesterPanel.tsx:297` (`metrics?.net_profit ?? 0` → `formatMoney` → `Intl.NumberFormat`), пока не падает благодаря неявному ToNumber внутри Intl.NumberFormat — это маскирует некорректность контракта, а не подтверждает его правильность.

- **Рекомендация:** Привести типы BacktestMetrics, BacktestTrade, EquityPoint, BacktestCandle, BacktestBenchmark в `backtestApi.ts` к `string` для всех Decimal-полей (net_profit, win_rate, profit_factor, sharpe_ratio, entry_price, exit_price, pnl, pnl_pct, commission, equity, drawdown, buy_hold, index и т.д.), как уже сделано для TradingSession/LiveTrade/Position в `api/types.ts`, и обернуть точки потребления в `Number(...)` перед арифметикой/`.toFixed()`, либо ввести единый helper `toNumber()` на границе API.

#### useBackgroundBacktestsBootstrap не переподключается при обрыве WS фонового бэктеста — `frontend/src/hooks/useBacktestJobWS.ts:257`

- **Категория:** баг  |  **Верификация:** ⚠️ не опровергнуто

- **Проблема:** Эффект в `useBackgroundBacktestsBootstrap()` (строки 179-271) переоткрывает сокеты только при изменении `idsKey` (join активных job_id из стора). `socket.onclose` (строка 257-259) при разрыве соединения лишь удаляет id из карты sockets — reconnect не планируется, в отличие от соседнего `useBacktestJobWS` с корректным exponential backoff. Если во время работы фонового бэктеста backend перезапустится, упадёт сеть или сервер закроет idle-соединение, WS для job_id не переоткроется, пока список активных job'ов не изменится по другой причине. В результате бейдж «Фоновые бэктесты» в шапке застревает на последнем полученном progress и никогда не покажет done/error, пока пользователь не обновит страницу вручную. Это единственный реально используемый в продакшене WS-клиент для фоновых job'ов — соседний `useBacktestJobWS` с корректной reconnect-логикой нигде не вызывается (мёртвый код).

- **Рекомендация:** Добавить в `socket.onclose` планирование reconnect с exponential backoff (по аналогии с `useBacktestJobWS`/`useTradingSessionsWS`), либо переиспользовать существующий `useBacktestJobWS` для каждого активного job_id вместо параллельной ad-hoc реализации без reconnect, либо явно вызывать `store.setStatus(id, 'error', ...)` при неожиданном закрытии.

### 🟡 Medium

#### Тройное дублирование reconnect/auth-логики WebSocket между хуками — `frontend/src/hooks/useBacktestJobWS.ts:20`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `useBacktestJobWS.ts` (connect/scheduleReconnect/onclose-обработка кодов 4401/4403/ping-pong), `useBackgroundBacktestsBootstrap` (тот же файл, строки 179-271) и `useTradingSessionsWS.ts` (строки 150-241) реализуют идентичную по структуре логику exponential backoff reconnect, auth-handshake первым сообщением, обработку `type:'ping'`→pong и коды закрытия 4401/4403 — вместо переиспользования generic `useWebSocket` (singleton, тоже с reconnect) или общего helper'а. Изменение стратегии backoff требует правки в 3 местах; несогласованное исправление в одном месте (аналогично уже наблюдавшемуся паттерну — ретроспектива Sprint 5) создаёт риск рассинхрона поведения reconnect между backtest-job WS и trading-sessions WS.

- **Рекомендация:** Вынести общий `createReconnectingSocket({url, onOpen, onMessage, authToken, onAuthError})` helper с параметризуемым auth-handshake и backoff, использовать его в обоих хуках и в bootstrap-функции вместо трёх независимых копий connect/scheduleReconnect.

#### Денежные/процентные поля backend Decimal типизированы как number на фронте (дубль-аспект бага из High) — `frontend/src/api/backtestApi.ts:38`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Та же корневая проблема, что и выше (Decimal→number вместо string), рассмотренная под углом качества контракта: backend `app/market_data/schemas.py` для аналогичных случаев явно использует `DecimalAsNumber = Annotated[Decimal, PlainSerializer(float)]`, тогда как `app/backtest/schemas.py` этого не делает. Несогласованность контракта между модулями backend усугубляет проблему — на фронте нет единого правила, когда ожидать string, а когда number, что повышает риск при будущих рефакторингах (например, замена `Intl.NumberFormat` на `.toFixed()`).

- **Рекомендация:** См. рекомендацию выше (привести типы к `string` + `Number(...)` на границе потребления); дополнительно рассмотреть унификацию сериализации Decimal на backend (`PlainSerializer` либо единая политика "Decimal всегда строка") во избежание расхождений между модулями schemas.py.

#### Четыре `as never`-каста отключают проверку типов на границе WS-delta → store — `frontend/src/hooks/useTradingSessionsWS.ts:83`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В `updateStore` (строки 79-103) каждый вызов `tradingStore.updateSessionFromWS(...)` завершается кастом `as never`, подавляя проверку соответствия объекта сигнатуре `Partial<TradingSession> & {id: number}`. Например, pnl_update-ветка (строка 85) берёт `payload.current_pnl ?? payload.pnl` и приводит к `number | null`, хотя `TradingSession.current_pnl` в `api/types.ts` объявлен как `string | null` (Decimal-строка) — компилятор должен был поймать несоответствие, но `as never` его скрывает. Если backend delta-протокол пришлёт `current_pnl` строкой (что соответствует Decimal-контракту), в store попадёт значение неверного JS-типа без предупреждения компилятора.

- **Проблема (связанный аспект, `useTradingSessionsWS.ts:85`):** Строка `const current_pnl = (payload.current_pnl ?? payload.pnl ?? null) as number | null;` использует TS-каст `as number`, не выполняющий реального приведения значения — тот же корневой риск рассинхрона string/number на WS-границе. Видимого краха сейчас нет, поскольку потребители (`SessionCard.formatPnl`, `SessionList`) заново оборачивают значение в `Number(...)` при рендере.

- **Рекомендация:** Убрать `as never`/`as number`, явно типизировать частичные payload'ы под сигнатуру `Partial<TradingSession>` (привести `current_pnl` к строке через `String(...)`, если backend шлёт число, либо поправить тип, если шлёт Decimal-строку), типизировать `updateSessionFromWS` так, чтобы TS реально проверял форму объекта, и документировать, что WS-payload может прийти в любом из двух форматов, пока backend event-bus не гарантирует единую Decimal-сериализацию для WS-дельт.

### 🔵 Low

#### Дублирование логики refresh JWT-токена между client.ts и aiStreamClient.ts без общего мьютекса — `frontend/src/services/aiStreamClient.ts:10`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Функция `refreshTokenIfNeeded` (`aiStreamClient.ts:10-27`) почти дословно дублирует `doRefresh` из `api/client.ts:78-97` — тот же POST на `/auth/refresh`, тот же `setToken`/`refreshToken` в authStore, тот же try/catch с молчаливым `return null`. Отличие: `client.ts` использует общий `isRefreshing`/`refreshPromise` guard для дедупликации параллельных refresh-запросов, а версия в `aiStreamClient.ts` — нет. Сценарий: если пользователь одновременно отправляет AI-сообщение (SSE stream) и выполняет обычный REST-запрос в момент истёкшего токена, оба независимо инициируют refresh — второй refresh-запрос может инвалидировать refresh_token, использованный первым (в зависимости от backend-политики ротации), приводя к неожиданному logout.

- **Рекомендация:** Экспортировать `doRefresh` (с guard'ом `isRefreshing`/`refreshPromise`) из `client.ts` и переиспользовать в `aiStreamClient.ts` вместо копии.

#### Обработчики WS в useBackgroundBacktestsBootstrap не имеют backoff (дубль-аспект найденного бага) — `frontend/src/hooks/useBacktestJobWS.ts:179`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Тот же дефект, что и в находке High про отсутствие reconnect, зафиксированный измерением quality под отдельным углом: в отличие от `useBacktestJobWS` (у которого есть `scheduleReconnect` с exponential backoff), `useBackgroundBacktestsBootstrap` в `socket.onclose` просто удаляет сокет из Map без попытки переподключения.

- **Рекомендация:** См. рекомендацию к находке High выше (добавить reconnect с backoff либо явный `store.setStatus(id, 'error', ...)`).

#### Префикс JWT-токена логируется в консоль браузера — `frontend/src/api/client.ts:60`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** В режиме `import.meta.env.DEV` каждый запрос логирует `token=${token.slice(0, 12)}...` в консоль (аналогично `authStore.ts:63` при login). Хотя обёрнуто DEV-флагом, DEV-сборки нередко разворачивают на staging/demo окружениях, доступных большему кругу лиц, а содержимое консоли может собираться сторонними инструментами мониторинга ошибок (Sentry breadcrumbs с console capture) или browser-расширениями.

- **Рекомендация:** Убрать фрагмент токена из `console.debug` полностью (логировать только факт наличия/отсутствия токена булевым флагом), либо использовать непечатаемый маркер (hash первых байт) вместо среза токена.

#### CSRF-токен читается из non-HttpOnly cookie и тихо не отправляется при его отсутствии — `frontend/src/api/client.ts:30`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `getCSRFToken()` парсит `document.cookie` на клиенте — cookie `csrf_token` не может быть HttpOnly и потенциально читаема JS при XSS (стандартный double-submit паттерн, сам по себе допустим). Более практическая проблема: если `csrfToken` отсутствует (`null`), интерцептор просто не добавляет заголовок `X-CSRF-Token`, и запрос всё равно уходит — если backend endpoint ошибочно не проверяет обязательность этого заголовка (несогласованность конфигурации), мутирующий запрос пройдёт без CSRF-защиты незаметно для фронта. Поскольку часть путей аутентифицируется по HttpOnly cookie (для Plotly Dash, `withCredentials:true`), для них отсутствие обязательного CSRF-заголовка критично.

- **Рекомендация:** Убедиться (на backend, вне зоны этого ревью), что все cookie-аутентифицированные mutating-эндпоинты жёстко требуют валидный `X-CSRF-Token` и отклоняют запрос при его отсутствии. На фронте рассмотреть явную ошибку/предупреждение, если `csrfToken` ожидался, но отсутствует, вместо молчаливого пропуска заголовка.

#### BrokerBalance.total/available/blocked типизированы как string, хотя backend отдаёт float — `frontend/src/api/types.ts:199`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Backend `app/broker/schemas.py::BrokerBalance` объявляет total/available/blocked как `float` (не Decimal) — сериализуется в JSON как числа. Frontend `api/types.ts` (строки 199-208) типизирует их как `string` с комментарием «Decimal-поля → string (Stack Gotcha #1)», что неверно для этой конкретной схемы. Текущий потребитель (`components/account/BalanceCards.tsx`) оборачивает в `Number(b.total)` при чтении, поэтому видимого сбоя сейчас нет (`Number(number)` идемпотентен), но контракт вводит в заблуждение: если кто-то по аналогии с другими Decimal-полями применит `.replace(',', '.')` или другую строковую обработку — упадёт, так как реальное значение уже number.

- **Рекомендация:** Исправить тип `BrokerBalance` в `api/types.ts` на `total: number; available: number; blocked: number;` в соответствии с backend float, оставив `BrokerPosition`/`BrokerOperation` как string (там реально Decimal).

---

Отклонено при верификации: находок со статусом `refuted` в переданных данных не обнаружено.


---

## 21. Frontend: состояние (zustand stores)

Просмотрены все production-файлы в `Develop/frontend/src/stores` (15-16 файлов, ~2688 строк) по двум измерениям — качество кода и баги. Общее качество хорошее: консистентный паттерн zustand-экшенов, race-guard'ы для устаревших запросов, задокументированные решения по прошлым багам (BUG-20, BUG-5). Критичных для денег багов (потеря точности, неверный знак P&L, прямые мутации стора) не найдено — Decimal-поля хранятся строками. Главная находка — вероятный рецидив паттерна BUG-20: `authStore.logout()` не чистит `accountSelectionStore`, что может привести к утечке/рассинхрону выбора брокерского счёта между пользователями одного устройства. Также отмечены рассинхронизация сортировки свечей по naive-датам вместо UTC-нормализации и race condition при параллельных optimistic-update в `userFavoritesStore`. Гипотеза о смешивании позиций разных торговых сессий в `tradingStore` проверена и отклонена — WS-канал фильтрует по `session_id`.

### 🟠 High

#### 🟠 logout() не очищает accountSelectionStore — рецидив паттерна BUG-20 — `frontend/src/stores/authStore.ts:69`

- **Категория:** баг / качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `authStore.logout()` явно чистит `candlesCache`, `background-backtests`, `user_favorites`, `favoriteTimeframes` (по аналогии с уже исправленным BUG-20), но не трогает персистентный `account-selection-storage` (`accountSelectionStore`, zustand/persist, глобальный ключ на устройство, не привязан к user). Сценарий: пользователь A выбирает брокерский счёт №2 на `/account`, делает logout; на этом же устройстве логинится пользователь B — `selectedAccountId` остаётся равным ID счёта пользователя A. Если у пользователя B есть счёт со случайно совпадающим числовым ID, `resolveSelectedAccountId()` сочтёт persisted ID валидным (просто по совпадению id в eligible-списке), и `AccountPage` отобразит не дефолтный, а этот счёт — нарушение ожидаемого поведения «новый пользователь видит дефолтный счёт» и тот же класс проблемы «непочищенный per-device state», что уже фиксился как BUG-20 для остальных stores.

- **Рекомендация:** В `authStore.logout()` добавить сброс: `useAccountSelectionStore.getState().setSelectedAccountId(null)` и `localStorage.removeItem('account-selection-storage')`, аналогично остальным store.

### 🟡 Medium

#### 🟡 Сортировка/дедупликация свечей по naive Date.parse вместо toUtcUnix — рассинхронизация хронологии графика — `frontend/src/stores/marketDataStore.ts:307`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В `fetchOlderCandles` (обе ветки: `stillActive` и `!stillActive`) дедупликация и сортировка идут через `new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()` (строки 307, 324) вместо уже существующей в этом же файле `toUtcUnix()`, которая корректно трактует naive-строки (без tz-суффикса, как приходят исторические свечи из SQLite) как UTC. Если один массив содержит live-tick от T-Invest с суффиксом `+00:00` (через `upsertLiveCandle`), а другой — naive-строки из REST, `new Date('2026-01-01T10:00:00')` парсится JS как локальное время браузера, а не UTC. Для пользователя не в часовом поясе Europe/Moscow сортировка даст сдвиг на несколько часов относительно правильного UTC-порядка — соседние свечи могут поменяться местами или показать «дыру»/наложение при подгрузке истории скроллом влево. Тот же баг для дедупликации по `seen.has(c.timestamp)` (строки 303-304, 319-321) — сравнение по сырой строке, а не по нормализованному unix, так что одна и та же свеча в разных tz-представлениях не считается дубликатом.

- **Рекомендация:** Использовать `toUtcUnix(c.timestamp)` как ключ в Set для дедупликации и как компаратор в `sort()`, вместо `new Date(...).getTime()` на сырой строке — аналогично тому, как уже сделано в `upsertLiveCandle`.

#### 🟡 Race condition при параллельных add/remove — откат по устаревшему снапшоту стирает более новое изменение — `frontend/src/stores/userFavoritesStore.ts:77`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В `add()` и `remove()` снапшот массива (`current`) захватывается синхронно ДО await запроса к backend. Если пользователь быстро выполняет два независимых действия подряд (добавить тикер A, затем сразу тикер B) и первый запрос (add A) завершается сетевой ошибкой ПОСЛЕ того, как второй запрос (add B) уже применил свой optimistic update, catch-блок первого вызовет `set({[key]: current})` со снапшотом до обоих действий — это стирает уже применённое (и потенциально успешно ушедшее на backend) изменение B из UI, хотя оно осталось в БД. Стор и backend расходятся до следующего `load()`.

- **Рекомендация:** При откате не перезаписывать весь список снапшотом, а точечно убирать/возвращать конкретное значение: в catch для add — `set((s) => ({ [key]: s[key].filter((x) => x !== v) }))`; для remove — `set((s) => ({ [key]: s[key].includes(value) ? s[key] : [...s[key], value] }))`.

#### 🟡 subscribeProgress: WS и polling независимо триггерят обработку терминального статуса — дублирование логики — `frontend/src/stores/backtestStore.ts:125`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `subscribeProgress` одновременно открывает WebSocket и запускает `setInterval`-poll каждые 2 секунды для одного и того же `backtestId`. Оба канала независимо вызывают `get().setProgress`/`fetchBacktest`/`setFailed` при получении терминального статуса (poll: строки ~145-153, WS onmessage: строки ~171-176) — два практически идентичных блока обработки одного события с разной точностью payload. Если один канал завершит обработку раньше другого, оба обработчика могут вызвать `fetchBacktest`/`unsubscribeProgress` с разной последовательностью — не критично по данным, но избыточно дублирует одну и ту же ветвь логики вместо единого источника истины.

- **Рекомендация:** Свести обработку терминального статуса в общий helper, вызываемый из обоих обработчиков (WS onmessage и poll interval), либо явно оставить только WS с fallback на polling исключительно при `socket.onerror`.

### 🔵 Low

#### 🔵 downloadTaxReport: revokeObjectURL не в finally — утечка Blob URL при исключении — `frontend/src/stores/accountStore.ts:133`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В `downloadTaxReport()` `URL.createObjectURL(blob)` создаётся до `link.click()`, а `revokeObjectURL` стоит сразу после `click()` без try/finally. Если между `createObjectURL` и `revokeObjectURL` произойдёт исключение, `revokeObjectURL` не выполнится, и blob URL останется висеть в памяти до закрытия вкладки. При частых скачиваниях отчётов — накопление утечек памяти.

- **Рекомендация:** Обернуть `createObjectURL`/`click`/`revokeObjectURL` в try/finally, чтобы `revokeObjectURL` гарантированно вызывался.

#### 🔵 unsubscribeProgress() без параметра закрывает ВСЕ активные WS/poll, включая чужие backtest id — `frontend/src/stores/backtestStore.ts:94`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `fetchBacktest(id)` при finished вызывает `get().unsubscribeProgress()` без аргумента (строка 95), что закрывает и удаляет ВСЕ записи из `wsMap`/`pollMap` (строки 197-203), а не только запись для конкретного id. Аналогично `setCompleted`/`setFailed` вызывают `unsubscribeProgress()` без id. Если окажутся активны две параллельные подписки `subscribeProgress` для разных `backtestId` в одном browser tab (метод публичный, ничто в сторе этого не запрещает), завершение одного бэктеста оборвёт WS/polling второго ещё незавершённого — его прогресс перестанет обновляться.

- **Рекомендация:** В `fetchBacktest`/`setCompleted`/`setFailed` передавать конкретный id в `unsubscribeProgress(id)`, если предполагается поддержка параллельных foreground-подписок; либо явно задокументировать инвариант «только один активный id одновременно» и защитить его assert'ом.

#### 🔵 Магические константы диапазона volumeHeightPercent (10/40) без единого источника с UI — `frontend/src/stores/marketDataStore.ts:415`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `setVolumeHeightPercent` жёстко клэмпит значение в диапазон [10, 40] инлайн-числами. Если UI-слайдер настройки объёма задаёт свой независимый min/max (например, 5/50), пользователь увидит, что слайдер визуально позволяет выставить 5%, но store молча приведёт к 10% — рассинхрон представления и реального состояния без объяснения в UI.

- **Рекомендация:** Вынести MIN/MAX как экспортируемые именованные константы модуля и переиспользовать их в UI-компоненте слайдера, чтобы границы были одним источником истины.

#### 🔵 Дублирование логики persist в localStorage: generic loader и специализированный кеш свечей — `frontend/src/stores/marketDataStore.ts:111`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В файле определены два независимых механизма persist в localStorage: generic `loadFromStorage`/`saveToStorage` (для showOHLCV/volumeHeightPercent) и специализированные `loadCandlesCache`/`saveCandlesCache` с TTL и LRU-обрезкой. Логика try/catch-проглатывания ошибок дублируется в четырёх местах в одном файле. При добавлении ещё одного persisted-поля с похожими требованиями (TTL/LRU) велика вероятность копипасты этого кода в третий раз вместо переиспользования общей утилиты.

- **Рекомендация:** Выделить общий helper с TTL+LRU (например, в `utils/`) и параметризовать его для разных use-case, либо явно задокументировать, что `loadFromStorage` — только для простых значений, а `*CandlesCache` — единственный TTL/LRU-кейс.

#### 🔵 duplicate(): копирование полей drawing data без discriminated union по DrawingType — `frontend/src/stores/chartDrawingsStore.ts:315`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В `duplicate()` поля `d.p1`/`d.p2`/`d.anchor`/`d.entry`/`d.end` читаются и присваиваются в `newData` без проверки соответствия типа `DrawingType` (например, для `'hline'` есть `price`/`t`, но нет `p1`/`p2`). Код полагается на то, что необязательные поля будут просто undefined для несовместимых типов — работает, но при добавлении нового `DrawingType` с иной структурой data разработчику придётся вспомнить дописать branch вручную — нет исчерпывающей проверки по `d.type` (switch/discriminated union), что снижает типобезопасность при расширении набора инструментов рисования.

- **Рекомендация:** Рассмотреть explicit switch по `src.type` с per-type копированием полей, чтобы TypeScript выдавал ошибку компиляции при добавлении нового `DrawingType` без соответствующей ветки duplicate-логики.

#### 🔵 Идентичный try/catch-паттерн обработки ошибок продублирован в 12 экшенах без общей обёртки — `frontend/src/stores/tradingStore.ts:44`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Паттерн `try { ... } catch (err: unknown) { const message = err instanceof Error ? err.message : '...'; set({ error: message, loading: false }); }` повторяется практически идентично во всех 12 async-экшенах этого store (и аналогично в strategyStore, accountStore, settingsStore, backtestStore). Любое будущее изменение обработки ошибок (например, добавление toast-уведомления или логирования в Sentry) потребует правки в десятках мест по всей кодовой базе stores, с высоким риском пропустить одно из них.

- **Рекомендация:** Выделить общий helper (например, `withAsyncAction(set, fn, fallbackMessage)`) в `utils/store-helpers.ts` и переиспользовать во всех store, снижая копипасту и риск рассинхрона обработки ошибок между модулями.

#### 🔵 Громоздкая сигнатура типа add() через Omit+Partial+Pick усложняет сопровождение — `frontend/src/stores/backgroundBacktestsStore.ts:78`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `add: (bt: Omit<BackgroundBacktest, 'progress' | 'status' | 'started_at'> & Partial<Pick<BackgroundBacktest, 'progress' | 'status' | 'started_at'>>) => void` — конструкция читается тяжело и создаёт риск, что при рефакторинге `BackgroundBacktest` (добавление нового обязательного поля) разработчик забудет обновить этот Omit/Pick список, и TypeScript не всегда прозрачно подсветит проблему (structural typing может подставить undefined в неожиданных местах, если поле забыто в обоих списках).

- **Рекомендация:** Определить отдельный явный тип `NewBackgroundBacktestInput` с явным перечислением обязательных/опциональных полей вместо комбинации Omit+Partial+Pick над одним и тем же типом.


> **Дополнение (добор упавшего измерения «Уязвимости»).** Ниже — находки повторного ревью после сбоя измерения. Основные проблемы хранения токенов вынесены в раздел 2 (Security-check фронтенда); здесь — специфичные для stores.

### 🟠 High

#### 🟠 JWT-токен передаётся в query-string WebSocket URL (второе, независимое место) — `frontend/src/stores/backtestStore.ts:129`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `subscribeProgress` берёт `token` из `authStore` и подставляет в URL (`/ws?token=${token}`) при подключении WebSocket прогресса бэктеста. Query-string логируется прокси/веб-серверами, попадает в browser history и Referer — тот же класс уязвимости, что и в `useWebSocket.ts` (см. раздел 2), но здесь это отдельное место создания `WebSocket`, которое легко пропустить при исправлении первого.

- **Рекомендация:** Централизовать подключение WS через единый клиент, передающий токен не в URL, а через subprotocol или сообщение после `onopen` (`{action:'auth', token}`); убрать дублирующую реализацию.

#### 🟠 Логирование префикса JWT-токена в консоль при логине — `frontend/src/stores/authStore.ts:62`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** В `login()` при `import.meta.env.DEV` выполняется `console.debug('[auth] login — token set:', token?.slice(0,12) + '...')`. 12 символов JWT попадают в консоль браузера и потенциально в session-replay/error-трекеры (Sentry/LogRocket мирроят `console.*`). При активации такого инструмента в дев/стейджинге с реальными данными — частичная утечка токена.

- **Рекомендация:** Убрать вывод любого содержимого токена; логировать только факт события без среза строки.

### 🟡 Medium

#### 🟡 Сырые секреты брокера (`api_key`/`api_secret`) проходят через состояние стора — `frontend/src/stores/settingsStore.ts:112`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `discoverAccounts({broker_type, api_key, api_secret})` принимает сырые секреты и прогоняет их через zustand-store; строка `error` из бэкенда прокидывается напрямую в UI и оседает в state. Если backend когда-либо отразит введённый ключ в теле ошибки — он будет сохранён и отрендерен.

- **Рекомендация:** Гарантировать, что backend не отражает `api_key`/`api_secret` в ошибках; на клиенте не хранить сырые секреты дольше времени запроса, очищать переменную после отправки.


---

## 22. Frontend: страницы (pages)

Просмотрены все 20 production-файлов в `frontend/src/pages` (~5000 строк) по трём измерениям — качество, баги и безопасность. Типизация в целом дисциплинированная (any/небезопасные касты не найдены), утечек в useEffect нет, XSS-паттернов и открытых редиректов не обнаружено. Главные системные проблемы: гигантский God-компонент `StrategyEditPage.tsx` (1101 строка) со всей логикой Blockly/версий/сохранения в одном месте, копипаста словарей и хелперов форматирования по 3 файлам, две заглушки-страницы, дублирующие рабочие маршруты, и хранение JWT-токенов в localStorage через zustand persist — потенциальная точка полного захвата сессии трейдера при XSS. Отдельно подтверждён верификацией баг с необработанным частичным отказом `Promise.all` при массовом удалении бэктестов.

### 🟠 High

#### 🟠 God-компонент StrategyEditPage: 1101 строка, смешаны состояние формы, Blockly, версии, бэктесты и рендер вкладок — `frontend/src/pages/StrategyEditPage.tsx:67`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Компонент держит ~25 useState/useRef, две сериализации Blockly (getCanonicalBlocks и getBlocksForBackend с разной семантикой), логику сохранения версий, авто-сброс query-параметров, построение AI-контекста и вёрстку двух вкладок с таблицами и модалками — всё в одном файле без выделения в кастомные хуки или дочерние компоненты. При добавлении новой фичи (например, ещё один тип валидации блоков) высок риск случайно сломать несвязанную логику (например, сохранение версии или таб-навигацию), т.к. все состояния находятся в одной функции и неявно взаимодействуют через замыкания (см. `handleBlocksLoaded` с `eslint-disable-next-line` на exhaustive-deps).

- **Рекомендация:** Вынести работу с Blockly (getCanonicalBlocks/getBlocksForBackend/getBlockWarnings/replaceInlineWithRefs) в отдельный хук `useStrategyBlocks(workspace)`, логику сохранения (doSave/handleGenerate/handleSaveClick) в `useStrategySave(...)`, а таблицу бэктестов стратегии — в отдельный компонент `StrategyBacktestsTable`.

#### 🟠 Массовое удаление бэктестов не обрабатывает частичный отказ Promise.all — `frontend/src/pages/StrategyEditPage.tsx:1086`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** Обработчик кнопки «Удалить все» вызывает `Promise.all(strategyBacktests.map((bt) => backtestApi.delete(bt.id)))` без `.catch()`. Если хотя бы один из N DELETE-запросов вернёт ошибку (сетевой сбой, 404 — бэктест уже удалён другой вкладкой, 403 и т.п.), весь `Promise.all` реджектится — необработанный rejection в обработчике клика. Часть бэктестов на бэкенде уже могла быть успешно удалена, но `setStrategyBacktests([])` и `setDeleteAllConfirmOpened(false)` не выполнятся: модалка «зависает» открытой, список в UI остаётся прежним (показывает уже удалённые записи), и пользователь не получает никакого уведомления об ошибке — состояние UI рассинхронизировано с БД до ручного обновления страницы. Подтверждено при верификации: `backtestApi.delete` идёт через `apiClient`, чей response-interceptor (api/client.ts:99-149) всегда делает `Promise.reject(error)` при ошибке, не глушит её; глобального `unhandledrejection`-хендлера нет (в ErrorBoundary.tsx:21 явно отмечено «отложено»), safety net отсутствует. Соседний одиночный delete (строка 882) страдает тем же паттерном — подтверждает системность бага.

- **Рекомендация:** Использовать `Promise.allSettled` вместо `Promise.all`, показать notification с числом успешных/неуспешных удалений, обновить список только реально удалёнными id, и в любом случае закрыть модалку или дать явный retry.

#### 🟠 JWT access/refresh токены хранятся в localStorage через zustand persist — риск полного захвата сессии при XSS — `frontend/src/pages/LoginPage.tsx:53`

- **Категория:** уязвимость  |  **Верификация:** ✅ подтверждено

- **Проблема:** LoginPage и SetupPage (SetupPage.tsx:47) вызывают `login(resp.data.access_token, resp.data.refresh_token, ...)` из authStore, обёрнутого в `persist()` (zustand/middleware) с дефолтным storage — localStorage. Любой XSS на любой странице приложения (в т.ч. через сторонние npm-пакеты Blockly/lightweight-charts или будущую уязвимость) получает полный доступ к access_token и refresh_token через `localStorage.getItem('auth-storage')`, что даёт постоянный захват сессии трейдера (можно выставлять реальные ордера через /trading, менять брокерские настройки) без возможности отзыва токена сервером до истечения TTL refresh_token. Подтверждено при верификации: authStore.ts:52-53,145-148 — `persist()`, `name:'auth-storage'`, `partialize` сохраняет token и refreshToken, storage не задан → дефолт zustand — localStorage; `logout()` делает `localStorage.removeItem('auth-storage')` (authStore.ts:83); client.ts:33,50 берёт token из стора в Authorization-header, `doRefresh` (client.ts:78-97) читает refreshToken оттуда же. Backend уже ставит HttpOnly cookie (router.py:34-56), но фронт использует не её, а JS-доступный localStorage как основной канал.

- **Рекомендация:** Хранить access_token только в памяти (не в persist zustand), refresh_token — в HttpOnly Secure cookie с SameSite=Strict, обновляемой через /auth/refresh. Расширить существующую серверную поддержку HttpOnly cookie (`_set_access_token_cookie`) на весь фронтенд, а не только на admin-ASGI-путь, и убрать persist токенов в localStorage.

### 🟡 Medium

#### 🟡 Дублирование словарей TIMEFRAME_LABELS и STATUS_MAP в трёх страницах — `frontend/src/pages/BacktestListPage.tsx:20`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Идентичный объект TIMEFRAME_LABELS (и почти идентичный STATUS_MAP для статусов бэктеста) продублирован дословно в BacktestListPage.tsx, BacktestResultsPage.tsx и StrategyEditPage.tsx. При добавлении нового таймфрейма (например '2h') или изменении цвета статуса разработчик должен не забыть обновить все три места — иначе на одной из страниц новый таймфрейм отобразится как сырой код вместо локализованной метки.

- **Рекомендация:** Вынести TIMEFRAME_LABELS и STATUS_MAP (backtest) в общий модуль, например `frontend/src/utils/labels.ts` или `frontend/src/constants/backtest.ts`, и импортировать во всех трёх файлах.

#### 🟡 Функция formatRub продублирована с разными сигнатурами в трёх местах — `frontend/src/pages/DashboardPage.tsx:71`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** formatRub реализована отдельно в pages/DashboardPage.tsx (value: number | null | undefined), components/dashboard/ActivePositionsWidget.tsx (value: number) и components/trading/PnLSummary.tsx (v: number | string | null | undefined) — три разные версии одной и той же логики форматирования рублей с разным поведением на edge-case (например, только PnLSummary принимает строку). Если поправить логику округления/знака в одном месте, два других места останутся со старым (потенциально неверным) форматированием, и суммы на разных страницах будут показываться по-разному для одних и тех же данных.

- **Рекомендация:** Вынести единственную реализацию formatRub (с поддержкой number|string|null|undefined) в `frontend/src/utils/format.ts` и заменить все три локальные копии на импорт.

#### 🟡 Мёртвые страницы-заглушки StrategyDetailPage/BacktestDetailPage дублируют рабочие маршруты — `frontend/src/pages/StrategyDetailPage.tsx:1`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** App.tsx регистрирует одновременно `strategy/:id` → StrategyDetailPage (заглушка «будет реализовано в Sprint 3») и `strategies/:id` → StrategyEditPage (реальный редактор); аналогично `backtest/:id` → BacktestDetailPage (заглушка «Sprint 4») и `backtests/:id` → BacktestResultsPage (реальная страница). Если где-то в коде или у пользователя в закладке окажется ссылка на единственное число (`/strategy/5` вместо `/strategies/5`), он попадёт на пустую заглушку без каких-либо данных вместо 404 или редиректа, и решит, что стратегия/бэктест потеряны.

- **Рекомендация:** Удалить оба файла-заглушки и соответствующие маршруты из App.tsx, либо превратить их в `<Navigate to={`/strategies/${id}`} replace />` для обратной совместимости старых ссылок.

#### 🟡 Клиентская валидация нового пароля (мин. 6 символов) расходится с требованием бэкенда (мин. 8 символов) — `frontend/src/pages/ProfileSettingsPage.tsx:47`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** handleChangePassword проверяет `newPassword.length < 6`, тогда как backend/app/auth/schemas.py::ChangePasswordRequest (new_password) требует `min_length=8`. Пользователь, введя пароль из 6-7 символов, пройдёт клиентскую проверку, увидит состояние loading, а затем получит 422 от сервера с сырым/непонятным сообщением — несогласованная UX и рассинхрон constraint'ов между фронтом и бэком, которые нужно поддерживать синхронно вручную.

- **Рекомендация:** Поднять клиентский порог до 8 символов (как в SetupPage.tsx, где уже `password.length < 8`), либо ещё лучше — вынести константу MIN_PASSWORD_LENGTH в общий модуль и использовать её в обоих местах.

#### 🟡 Нулевой P&L стратегии отображается как «нет данных» (falsy-проверка вместо undefined-проверки) — `frontend/src/pages/DashboardPage.tsx:369`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В ячейке «P&L» для случая, когда `strategy.total_position_rub` не задан, используется ветка `strategy.total_abs_pnl ? ... : '—'` — это truthy-проверка, а не `!== undefined`, как в соседней ветке. Если у стратегии `total_abs_pnl === 0` (например, позиция была открыта и закрыта в ноль, либо инструмент только что добавлен без сделок), `0` считается falsy, и колонка покажет прочерк «—», хотя данные есть и означают конкретный нулевой результат. Пользователь не отличит «нет сделок» от «сделки, но P&L = 0», что критично для трейдинг-дашборда, где решения принимаются по видимым цифрам.

- **Рекомендация:** Заменить проверку на `strategy.total_abs_pnl !== undefined` (как уже сделано в соседней ветке), чтобы 0 корректно рендерился как `(0 ₽)`.

#### 🟡 Гонка при быстрой смене выбранного брокерского счёта — устаревший ответ может перетереть данные текущего счёта — `frontend/src/pages/AccountPage.tsx:112`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** useEffect при каждой смене `selectedAccountId` вызывает `fetchPositions(selectedAccountId)` и `fetchOperations(selectedAccountId, ...)` без cancellation guard (нет `cancelled`-флага и cleanup-функции, в отличие от аналогичных паттернов в ChartPage/AdminLandingPage этого же ревью). Если пользователь быстро переключает счёт в селекторе (А → Б), а ответ для счёта А приходит позже ответа для Б, `accountStore.positions/operations` перезапишутся данными счёта А, хотя в UI уже выбран счёт Б — таблицы «Позиции» и «История операций» покажут чужие/устаревшие данные под текущим выбором счёта, что для финансового приложения означает показ неверных остатков и операций пользователю.

- **Рекомендация:** Добавить cancellation-guard в эффект (локальная переменная `cancelled`/AbortController, сравнение accountId с актуальным при получении ответа) либо переносить проверку «ответ относится к текущему selectedAccountId» в сам store перед записью в state.

### 🔵 Low

#### 🔵 handleDownloadExisting хардкодит расширение файла .xlsx независимо от реального формата отчёта — `frontend/src/pages/AccountPage.tsx:161`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** TaxReportResponse (backend/app/tax/schemas.py) не содержит поля format, поэтому handleDownloadExisting всегда подставляет `const ext = 'xlsx'` для имени скачиваемого файла. Если пользователь ранее сгенерировал отчёт с format='csv' (TaxReportRequest поддерживает и csv, и xlsx), при повторном скачивании через список «Налоговые отчёты» файл будет содержать CSV-данные, но иметь расширение .xlsx — Excel/ОС могут показать ошибку открытия или неверно интерпретировать содержимое.

- **Рекомендация:** Добавить поле format в TaxReportResponse на бэкенде и использовать его для выбора расширения на фронте; либо, как временная мера, показывать в таблице отчётов колонку «Формат» и брать расширение из неё.

#### 🔵 Все 4 вкладки настроек монтируются одновременно, вызывая fetch-запросы всех разделов сразу — `frontend/src/pages/SettingsPage.tsx:22`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Mantine Tabs по умолчанию рендерит содержимое всех Tabs.Panel (просто скрывая неактивные через display:none, а не размонтируя), поэтому при открытии /settings одновременно монтируются BrokerSettingsPage, AIProvidersContent, ProfileSettingsPage и NotificationSettingsPage — каждый со своим useEffect, вызывающим fetchAccounts, listProviders+getInstructions, fetchSettings+getTelegramStatus. Пользователь, открывший вкладку «Брокер», всё равно инициирует запросы к AI-провайдерам и уведомлениям, увеличивая нагрузку и время до интерактивности страницы без необходимости.

- **Рекомендация:** Передать `keepMounted={false}` в Mantine `<Tabs>` (или рендерить активную панель условно через if (activeTab === 'ai')), чтобы содержимое неактивных вкладок не монтировалось до первого выбора.

#### 🔵 LoginPage и SetupPage дублируют идентичную разметку формы аутентификации — `frontend/src/pages/LoginPage.tsx:20`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Оба компонента почти дословно повторяют одинаковый Paper/Center layout, поля TextInput/PasswordInput, обработку Alert с ошибками и текст 'MOEX Terminal' — различается только состав полей и submit-логика. Изменение общего стиля формы логина (например, добавление логотипа или смена отступов) требует правки в обоих файлах, и уже сейчас незначительные расхождения (checking-состояние есть только в LoginPage) увеличивают риск, что визуальные правки в одном файле не попадут в другой.

- **Рекомендация:** Выделить общий компонент AuthFormLayout (Paper+Center+заголовок+блок ошибок) и переиспользовать его в LoginPage и SetupPage, оставив уникальными только поля формы и submit-обработчики.

#### 🔵 Ценовое оповещение в шапке графика показывается без форматирования числа — `frontend/src/pages/ChartPage.tsx:391`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В Badge оповещения `target_price` выводится напрямую как `{al.target_price}` — это уже сконвертированный `Number(a.target_price)`, без `toLocaleString`/`toFixed`. Для цен с большим количеством знаков после запятой (что бывает у Decimal-цен облигаций/фьючерсов, приходящих строкой с backend) в шапке отобразится длинное нечитаемое число (например `123.456789`), вместо принятого в проекте формата отображения цены/суммы.

- **Рекомендация:** Форматировать `target_price` через единый хелпер форматирования цены (как используется в других местах проекта для цен инструмента), например `target_price.toLocaleString('ru-RU', { maximumFractionDigits: 2 })`.

#### 🔵 API-ключ AI-провайдера вводится в обычном TextInput, а не PasswordInput — `frontend/src/pages/AISettingsPage.tsx:498`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** В форме добавления/редактирования AI-провайдера (handleOpenAdd/handleOpenEdit) поле api_key (например ключ вида sk-ant-api03-...) рендерится через Mantine `<TextInput>`, а не `<PasswordInput>`, в отличие от полей пароля пользователя (LoginPage, SetupPage, ProfileSettingsPage используют PasswordInput). Значение видно открытым текстом на экране во время ввода/редактирования — при демонстрации экрана, скриншоте, записи сессии поддержки или физическом shoulder-surfing секретный ключ провайдера утекает целиком.

- **Рекомендация:** Заменить `<TextInput>` на `<PasswordInput>` для поля api_key, сохранив текущее поведение маскировки уже сохранённого ключа (masked_api_key).


---

## 23. Frontend: графики (components/charts)

Проверены все production-файлы `frontend/src/components/charts` (24 файла, ~5500 строк): CandlestickChart, DrawingsLayer, DrawingToolbar(+Icons), FavoritesPanel, MiniSparkline, OpenPositionsLayer, модалки, TimeframeSelector, sequentialIndex.ts и весь primitives/. Главные системные проблемы — тройное дублирование логики MSK-сдвига времени между CandlestickChart, coords.ts и sequentialIndex.ts (уже отмечено в комментариях как Stack Gotcha 15, но не устранено) и God-компонент CandlestickChart.tsx (907 строк, 8 useEffect). Найден реальный высокоприоритетный функциональный баг: VlinePrimitive не поддерживает sequential/intraday режим в отличие от остальных drawing-примитивов — вертикальные линии на intraday-таймфреймах не отображаются или рисуются в неверном месте. Уязвимостей (XSS, хранение токенов, открытые редиректы, утечка секретов) не найдено — весь пользовательский текст рендерится через React JSX или Canvas 2D безопасным образом. Не проверялись тестовые файлы и стор-модули вне заданной директории (chartDrawingsStore, marketDataStore, tradingStore, userFavoritesStore, priceAlertStore) — часть находок про error-handling опирается на предполагаемое поведение этих сторов по контракту.

### 🟠 High

#### 🟠 VlinePrimitive не поддерживает sequential (intraday) mode — линия не отображается или рисуется в неверном месте — `frontend/src/components/charts/primitives/VlinePrimitive.ts:27`

- **Категория:** баг (объединено с находкой качества)  |  **Верификация:** ⚠️ не опровергнуто

- **Проблема:** `VlineRenderer.draw()`/`hitTest()` вычисляют X-координату напрямую через `timeToX(chart, isoToTime(t))`, т.е. по unix-времени + MSK-offset. Но на intraday-таймфреймах (1m/5m/15m/1h/4h) CandlestickChart включает sequential mode, и серия индексирована по 0,1,2… вместо unix-timestamp (см. `isSeriesInSequentialMode` в `primitives/coords.ts`, отдельная logical-first ветка `pointToCoord()`, строки 63-86). Все остальные примитивы (Trendline, Rect, Label, PositionDrawing) корректно используют `pointToCoord`, который учитывает sequential mode через `point.logical`. VlinePrimitive — единственный, кто вызывает `timeToCoordinate` с числом вида unix_sec+10800 (>1.7e9), далеко за пределами реального диапазона индексов серии (0..N) — `timeToCoordinate` вернёт `null` или неверную координату. Сценарий: пользователь на графике SBER 5m ставит вертикальную линию — она либо не отображается вовсе, либо после дозагрузки/reload оказывается в произвольном месте графика. Дополнительно: при создании vline в `DrawingsLayer.tsx:247` (`add({type:'vline', data:{t: pt.t}})`) точка вообще не сохраняет `point.logical`, хотя `clickToDrawingPoint` его вычисляет — то есть даже потенциальный fallback через logical недоступен.

- **Рекомендация:** Переписать `VlinePrimitive.draw()`/`hitTest()` на использование `pointToCoord({t, logical}, chart, series)` вместо прямого `timeToX(isoToTime(t))`, аналогично Trendline/Rect/Label. При создании vline в `DrawingsLayer.handleCreation` сохранять и `logical` из `pt` (`data: { t: pt.t, logical: pt.logical }`).

#### 🟠 God-компонент: 907 строк, 8 useEffect, смешение data-layer/WS/маркеров/рендера — `frontend/src/components/charts/CandlestickChart.tsx:138`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** CandlestickChart одновременно отвечает за: создание/ресайз chart-инстанса, парсинг таймзоны, sequential-индексацию, подписку на market WS, подписку на trade WS, построение и пересчёт маркеров сделок (`tradeTimeValue`/`tradeToMarkers`/`rebuildMarkers`), управление price-alert линиями и рендер overlay. При любом изменении одной из зон разработчик вынужден читать все 907 строк и держать в голове взаимодействие 6+ ref'ов. Конкретный сценарий: при добавлении новой фичи велика вероятность нарушить порядок операций в useEffect №2 (строки 419-606), помеченном множеством `eslint-disable exhaustive-deps` из-за вызова `rebuildMarkers` вне deps — уже сейчас источник скрытых багов (ссылки на BUG-28 в комментариях подтверждают историю подобных инцидентов).

- **Рекомендация:** Выделить логику построения/пересчёта trade-маркеров в отдельный хук `useTradeMarkers(sessionId, ...)`, а WS-обвязку — в `useChartLiveData`. Это уменьшит компонент и уберёт часть `eslint-disable` по exhaustive-deps.

#### 🟠 MSK_OFFSET_SEC и парсинг UTC-таймстампа с MSK-сдвигом продублированы в трёх файлах — `frontend/src/components/charts/primitives/coords.ts:17`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Константа `MSK_OFFSET_SEC=3*3600` и идентичная логика нормализации ISO+деление на 1000+сдвиг определены независимо в `CandlestickChart.tsx` (строки 41-49, `parseUtcTimestamp`), `sequentialIndex.ts` (строки 5-11, отдельная копия той же функции) и `coords.ts` (строки 17-27, `isoToTime`/`timeToIso`). Комментарии сами признают риск («Stack Gotcha 15»), но не устраняют его. При изменении политики времени правку придётся синхронно вносить в 3 местах — пропуск одного создаст рассинхрон между отображением цены на графике и координатами drawings/маркеров (визуальный сдвиг фигур относительно свечей).

- **Рекомендация:** Вынести `MSK_OFFSET_SEC` и `parseUtcTimestamp`/`isoToTime`/`timeToIso` в один модуль (например `utils/mskTime.ts`) и импортировать из него во всех трёх местах.

### 🟡 Medium

#### 🟡 Целевая цена в модалке создания price alert не обновляется при повторном открытии — предзаполняется устаревшей ценой — `frontend/src/components/charts/PriceAlertModal.tsx:22`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `const [targetPrice, setTargetPrice] = useState<number | string>(currentPrice ?? 0)` инициализируется только один раз при монтировании компонента. В ChartPage модалка смонтирована постоянно (пока `ticker` истинный) и лишь скрывается/показывается через prop `opened` — компонент не размонтируется между открытиями, а `currentPrice` меняется во времени (WS live-обновления). Сценарий: пользователь открывает график SBER (цена 250 руб), `targetPrice` инициализируется значением 250 при первом рендере; цена растёт до 300 руб за час наблюдения; при повторном открытии модалки поле «Целевая цена» показывает устаревшие 250 руб вместо актуальных 300, и пользователь рискует создать алерт с неверным порогом.

- **Рекомендация:** Синхронизировать `targetPrice` с `currentPrice` при каждом открытии модалки: `useEffect(() => { if (opened) setTargetPrice(currentPrice ?? 0); }, [opened])`.

#### 🟡 Идентичный hit-test цикл продублирован в трёх местах — `frontend/src/components/charts/DrawingsLayer.tsx:296`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Один и тот же паттерн top-down перебора items + `primitivesRef.get(id).hitTest(x,y)` реализован отдельно в `onClick` (строки 296-309, режим cursor), в hover-эффекте (строки 415-426) и в `onContextMenu` (строки 551-562). При изменении семантики hit-test (например z-order или multi-select) нужно синхронно поправить 3 копии; пропуск одной приведёт к рассинхрону: пользователь наведётся на фигуру А (подсвечивается она), но клик выделит фигуру Б, если Z-order соседних фигур пересекается.

- **Рекомендация:** Вынести общий helper `hitTestTopmost(items, primitivesRef, x, y)` и переиспользовать во всех трёх местах.

#### 🟡 Дублирование бизнес-формулы расчёта unrealized PnL на фронтенде вместо единого источника — `frontend/src/components/charts/primitives/OpenPositionPrimitive.ts:193`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `computeLivePnl()` реинтерпретирует PnL-формулу бэкенда через линейную экстраполяцию `k=oldPnl/(oldCur-entry)`, а не запрашивает пересчёт у сервера. Предполагает, что PnL строго линеен по цене. При изменении бэкенд-формулы (например комиссии за удержание позиции) фронтовый расчёт молча разойдётся с реальным PnL, показывая неверную цифру на бейдже графика. Комментарии в коде сами признают, что это «зеркальный» пересчёт.

- **Рекомендация:** Либо получать `unrealized_pnl` из WS-обновления напрямую, либо вынести формулу в общий модуль с unit-тестом, синхронизированным с backend-формулой.

### 🔵 Low

#### 🔵 Price-alert линии не пересоздаются на новой series после пересоздания chart — ref на price lines не сбрасывается — `frontend/src/components/charts/CandlestickChart.tsx:609`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `alertPriceLinesRef` (Map<number, PriceLine>) живёт вне useEffect №1 (создание chart). При пересоздании chart-инстанса старая candlestick series уничтожается вместе со своими price lines, но `alertPriceLinesRef.current` продолжает хранить ссылки на них как на «существующие». useEffect на alertLines (строка 611) проверяет `currentLines.has(alert.id)` и, найдя ID уже «существующим», не создаёт price line заново на новой серии — горизонтальные линии ценовых оповещений исчезают с графика после пересоздания chart, хотя alertLines в сторе не изменились. Сейчас `showVolume` — константа (true), поэтому основной путь пересоздания не задействован, но ResizeObserver-путь (строки 326-327, `createChartInstance` при `chartRef.current==null`) потенциально достижим при ошибке инициализации.

- **Рекомендация:** В cleanup useEffect №1 (return-функция, строка 348) дополнительно очищать `alertPriceLinesRef.current.clear()` перед `chart.remove()`, чтобы следующий useEffect на alertLines гарантированно пересоздал все линии на новой серии.

#### 🔵 Избыточная hit-test проверка: isPointInBox и isPointInRect с одинаковыми аргументами через OR — `frontend/src/components/charts/primitives/PositionDrawingPrimitive.ts:256`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `isPointInBox({x,y},{x:x1,y:yMin},x2-x1,yMax-yMin) || isPointInRect({x,y},{x:x1,y:yMin},{x:x2,y:yMax},4)` — `isPointInRect` с теми же координатами и `edgeThreshold=4` строго покрывает область `isPointInBox` (без threshold). Первая проверка избыточна: результат OR всегда равен результату второй. Не ломает поведение, но вводит в заблуждение при чтении кода.

- **Рекомендация:** Убрать первый вызов `isPointInBox`, оставить только `isPointInRect(..., 4)`.

#### 🔵 Отсутствие обработки ошибки при загрузке избранного — `frontend/src/components/charts/FavoritesPanel.tsx:40`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `useEffect(() => { if (!loaded) void load(); }, [loaded, load])` — вызов `load()` не имеет catch и не отображает ошибку. Если запрос `/api/v1/user-favorites` упадёт, пользователь видит просто пустой список без объяснения, и возможны повторные вызовы `load()` при каждом ре-рендере, если `loaded` не выставляется после ошибки.

- **Рекомендация:** Добавить в `useUserFavoritesStore` явное состояние error/loading и отрисовать соответствующее сообщение в FavoritesPanel при ошибке загрузки.

#### 🔵 Ошибка создания price alert не отображается пользователю — `frontend/src/components/charts/PriceAlertModal.tsx:32`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `const alert = await createAlert(...)` — если `createAlert` бросит исключение (сетевая ошибка) без внутреннего try/catch в store, `handleSubmit` не ловит его, `setSubmitting(false)` не выполняется — кнопка останется в `loading=true` бесконечно без какого-либо сообщения об ошибке.

- **Рекомендация:** Обернуть вызов `createAlert` в try/catch/finally: в finally выставлять `setSubmitting(false)`, в catch показывать ошибку через Mantine notifications.

### ✅ Security-check

Уязвимостей категории «Уязвимости» (XSS, хранение токенов, открытые редиректы, `window.open` без `noopener`, утечка секретов, отсутствие CSRF) не найдено. Весь пользовательский текст (метки, тикеры, цены) рендерится либо через React JSX (авто-экранирование), либо через Canvas 2D `fillText`/`fillRect` — оба пути безопасны от XSS. `style.color`/`fill` из ChartDrawing применяются только как `ctx.strokeStyle`/`fillStyle`, не как CSS/DOM. `localStorage` используется только в тестах; FavoritesPanel явно перешёл от localStorage к backend-источнику (BUG-20). `window.open`, `eval`, `import.meta.env`, `console.log` с чувствительными данными — не встречаются. Не проверялось: TickerLogo.tsx (физически в components/common), API-клиенты с JWT (src/api/, src/stores/) и CSRF бэкенда — вне заданного пути.


---

## 24. Frontend: бэктест-компоненты (components/backtest)

Проверено 15 production-файлов (~5065 строк) в `Develop/frontend/src/components/backtest` по измерениям качества кода и безопасности. Явных `any` и уязвимостей (XSS через `dangerouslySetInnerHTML`/`innerHTML`, хранение токенов, открытые редиректы, утечка секретов) не найдено — компоненты презентационные и рендерят данные через типизированный JSX с автоэкранированием. Основные проблемы лежат в области качества: небезопасные двойные касты `as unknown as {...}` для обхода рассинхрона типов с API и для примешивания кастомных полей к объектам сторонних библиотек, а также системное дублирование утилит/форматтеров (дедупликация точек, форматирование денег, эпсилон-пороги breakeven) между компонентами, что создаёт риск рассинхрона поведения одинаковых виджетов на одной странице результатов. Отдельно отмечены смешение сетевой логики с представлением и дублирование сортировки в `GridSearchHeatmap.tsx`, а также непрерывный `requestAnimationFrame`-цикл в `InstrumentChart.tsx` без диртификации, постоянно нагружающий CPU/GPU. Тестовые файлы и построчное соответствие типов backend-схемам вне зоны ревью.

### 🟡 Medium

#### 🟡 Компонент содержит 5 разных ответственностей в одном файле без разделения — `frontend/src/components/backtest/GridSearchHeatmap.tsx:114`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** GridSearchHeatmap.tsx (620 строк) объединяет основной компонент с бизнес-логикой запуска бэктеста/применения параметров к стратегии (runBacktestWithParams, applyParamsToStrategy), BarView, HeatmapView, SortHead и MatrixTable. Побочные эффекты (сетевые запросы, навигация, нотификации) свёрстаны прямо в JSX-обработчиках onClick (строки 219-256). Хуже, что сортировка дублируется дважды: inline в sortMatrix (строка 271) и в MatrixTable через useMemo (строка 562) с идентичной логикой сравнения — рассинхрон этих двух копий приведёт к тому, что «Прогнать бэктест»/«Применить к стратегии» применит параметры не той строки, что визуально выделена пользователем.

- **Рекомендация:** Вынести sortMatrix в общий helper и переиспользовать в MatrixTable. Вынести runBacktestWithParams/applyParamsToStrategy в отдельный hook/service-файл, отделив сетевую логику от представления.

#### 🟡 Небезопасный каст as unknown as {...} маскирует рассинхрон типа BacktestTrade с API — `frontend/src/components/backtest/TradeDetailsPanel.tsx:73`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `trade as unknown as { entry_reason?: string | null; exit_reason?: string | null }` (строки 73-76) читает поля, которых нет в официальном типе BacktestTrade (frontend/src/api/backtestApi.ts, строки 24-35). Комментарий признаёт, что поля «могут отсутствовать в текущей схеме (S5)», но вместо расширения типа опциональными полями используется двойной каст через unknown, который отключает проверку компилятора: если бэкенд переименует entry_reason в reason_entry, TypeScript не заметит несоответствие и UI молча покажет прочерк без предупреждения о поломке контракта.

- **Рекомендация:** Добавить `entry_reason?: string | null; exit_reason?: string | null` непосредственно в интерфейс BacktestTrade в backtestApi.ts — единственный источник истины по контракту с бэкендом, каст через unknown станет не нужен.

#### 🟡 Непрерывный requestAnimationFrame-цикл перерисовки без диртификации грузит CPU/GPU — `frontend/src/components/backtest/InstrumentChart.tsx:289`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Строки 289-298: rAF-цикл loop() вызывает drawBgZones() на каждый кадр (~60/сек) бесконечно, пока компонент смонтирован, независимо от того, скроллит ли пользователь график или просто смотрит на статичную картинку. При открытой вкладке «Обзор» браузер постоянно перерисовывает canvas 60 fps, что на слабых устройствах увеличивает энергопотребление и конкурирует за кадр с другими графиками на странице.

- **Рекомендация:** Перерисовывать зоны только по событию (subscribeVisibleTimeRangeChange + ResizeObserver), а не непрерывным rAF-циклом; либо добавить диртификацию — перерисовывать только при реальном изменении диапазона time scale.

### 🔵 Low

#### 🔵 Дублирование утилиты deduplicateByTime между компонентами с разными сигнатурами — `frontend/src/components/backtest/StrategyTesterPanel.tsx:21`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** StrategyTesterPanel.tsx (строка 21-25) и InstrumentChart.tsx (строка 20-28) независимо реализуют идентичную по смыслу функцию deduplicateByTime (сортировка по time + фильтрация дублей через Set), но с разными сигнатурами (одна типизирована под EquityPoint, другая — generic). При изменении алгоритма дедупликации высок риск поправить только одну копию, и графики equity/candles будут вести себя по-разному при одинаковых дефектных входных данных от бэкенда.

- **Рекомендация:** Вынести generic-версию `deduplicateByTime<T extends {time:number}>` в общий utils-модуль и использовать в обоих компонентах.

#### 🔵 Два независимых механизма сброса состояния модалки на одно и то же событие opened — `frontend/src/components/backtest/BacktestLaunchModal.tsx:111`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Строки 110-125: паттерн «update state during rendering» (сравнение lastOpened !== opened) используется для сброса tickerSuggestions/errors при открытии модалки, но сразу следом (строки 121-125) для той же зависимости (opened) используется обычный useEffect для clearError(). Два разных механизма реакции на одно и то же событие «модалка открылась» затрудняют понимание кода.

- **Рекомендация:** Объединить сброс состояния в одном месте — либо оба сброса через паттерн «update during render», либо оба через единый useEffect(() => { if (opened) {...} }, [opened]).

#### 🔵 Дублирование извлечения HTTP-статуса ошибки в двух местах обработчика — `frontend/src/components/backtest/BacktestLaunchModal.tsx:233`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** В handleSubmitBackground дважды (строки 233-234 и 268) выполняется идентичный небезопасный каст `(err as { response?: { status?: number } }).response?.status` вместо axios.isAxiosError. Если формат ошибки backend изменится, оба места придётся чинить синхронно, а любое расхождение приведёт к тому, что 429 (превышен лимит фоновых бэктестов) не будет корректно распознан.

- **Рекомендация:** Вынести helper `getHttpStatus(err: unknown): number | undefined` с использованием axios.isAxiosError(err) и использовать в обоих местах.

#### 🔵 Вычисление min/max без useMemo пересчитывается на каждый рендер компонента — `frontend/src/components/backtest/GridSearchHeatmap.tsx:131`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** После строки 127 (if (matrix.length === 0) return ...) идут строки 131-133, где values/min/max вычисляются через Math.min/Math.max(...values) при каждом рендере компонента без мемоизации, хотя matrix пересчитывается через useMemo. При большом grid search (до 1000 комбинаций) это создаёт новый массив и два прохода Math.min/max на каждый рендер, включая рендеры от sortBy/sortDir/selectedIndex, не влияющих на min/max.

- **Рекомендация:** Обернуть values/min/max в `useMemo(() => {...}, [matrix, metric])`.

#### 🔵 Пустой useEffect с cleanup-заглушкой не выполняет никакой функции — `frontend/src/components/backtest/BacktestProgress.tsx:33`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Строки 34-38: `useEffect(() => { return () => { /* не отписываемся сразу */ }; }, [backtestId])` не делает ничего — мёртвый код, создающий впечатление, что здесь должна быть логика подписки/отписки на WS, вводя в заблуждение при последующих правках.

- **Рекомендация:** Удалить пустой useEffect и перенести комментарий туда, где реально управляется WS-подпиской.

#### 🔵 Несогласованные эпсилон-пороги breakeven в разных компонентах одной страницы — `frontend/src/components/backtest/PnLDistributionHistogram.tsx:22`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** BE_EPSILON=0.05 (в %, PnLDistributionHistogram.tsx строка 22) и BE_PNL_EPSILON_RUB=1 (в руб., WinLossDonutChart.tsx строка 11) — два независимых определения «breakeven сделки» с разными единицами. На одной странице результатов сделка с pnl=50₽ на капитале 1млн (pnl_pct=0.005%) будет «be» в гистограмме P&L, но «win» в donut-диаграмме Win/Loss — расхождение метрик рядом.

- **Рекомендация:** Вынести единое определение breakeven-порога в общий constants-файл и использовать в обоих компонентах, либо явно согласовать с продуктом, что критерии намеренно разные.

#### 🔵 Дублирование форматирования сумм в рублях в 3+ компонентах с расхождениями — `frontend/src/components/backtest/BacktestTrades.tsx:50`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** formatPrice (строка 50) в BacktestTrades.tsx и аналогичное форматирование в TradeDetailsPanel.tsx (строки 119, 134, 154) реализуют одно и то же форматирование денег с минимальными отличиями (Intl.NumberFormat vs toLocaleString), при том что формат денег зафиксирован в конвенциях проекта. Рассинхрон реализаций даст на экране бэктеста разные форматы одного и того же типа значения.

- **Рекомендация:** Вынести единый `formatRub(value, opts?)` в utils/formatters.ts и использовать во всех компонентах backtest.

#### 🔵 Отсутствует индикация состояния загрузки availableParams — `frontend/src/components/backtest/GridSearchForm.tsx:103`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** useEffect (строки 103-116) переводит availableParams из null в массив без промежуточного состояния loading. Если сеть медленная, пользователь может успеть вручную ввести имя параметра в TextInput, и после ответа сервера форма внезапно переключается на Select с потерей введённого текста, так как Select использует value={p.name || null} без введённого вручную значения в data.

- **Рекомендация:** Добавить явное состояние loading и не подменять TextInput на Select, если пользователь уже начал ввод в конкретной строке.

#### 🔵 Небезопасный каст объекта chart для хранения кастомных полей вместо явного состояния — `frontend/src/components/backtest/StrategyTesterPanel.tsx:135`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `(chart as unknown as { __cleanupListeners?: () => void }).__cleanupListeners = ...` (строка 135) прикрепляет произвольные поля к объекту IChartApi через двойной каст, обходя типизацию библиотеки. Тот же паттерн повторяется в InstrumentChart.tsx (строки 286-298). При обновлении lightweight-charts или Object.freeze объекта присвоение молча не сработает и слушатели не будут отписаны при размонтировании.

- **Рекомендация:** Хранить cleanup-функцию в отдельном useRef на уровне компонента вместо примешивания её к объекту chart.

---

**Security-check:** отдельно проверены все production-файлы каталога (16 файлов, ~3900 строк) на паттерны уязвимостей — `dangerouslySetInnerHTML`/`innerHTML`, хранение токенов, `window.open` без noopener, открытые редиректы, `VITE_`-секреты, CSRF. Совпадений не найдено. CSV-экспорт в BacktestTrades.tsx содержит только числовые поля (риск formula injection незначим), навигация использует только внутренние числовые ID. Находок category=vulnerability нет.


> **Дополнение (добор упавшего измерения «Баги»).** Ниже — находки повторного ревью после сбоя измерения. Критических багов не выявлено.

### 🟠 High

#### 🟠 Автонавигация `BacktestProgress` не сверяет id завершившегося бэктеста — переход на чужой — `frontend/src/components/backtest/BacktestProgress.tsx:55`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `useEffect` реагирует на `currentBacktest.status === 'completed'` и делает `navigate('/backtests/${backtestId}')`, где `backtestId` — проп, а `currentBacktest` берётся из глобального `useBacktestStore()` без сверки id. Если пока компонент смонтирован в сторе обновится `currentBacktest` от другого бэктеста (стор — синглтон), эффект сработает и произойдёт редирект на `backtestId` из пропсов, хотя завершился другой бэктест.

- **Рекомендация:** Сверять `currentBacktest.id === backtestId` перед навигацией, либо хранить id подписки в сторе.

#### 🟠 `BacktestProgress` не отписывается от WS/polling при размонтировании — утечка и запись в стор после ухода — `frontend/src/components/backtest/BacktestProgress.tsx:34`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Комментарий «Не отписываемся сразу — polling fallback может ещё работать» оставляет `useEffect` с пустым cleanup. `subscribeProgress` создаёт WS/интервал, а `unsubscribeProgress` вызывается только при `finished`/error внутри стора. Если пользователь уходит со страницы до завершения бэктеста, WS и `setProgress`/`setResult` продолжают писать в глобальный стор — утечка сокета и источник багов при повторном заходе.

- **Рекомендация:** В cleanup вызывать `unsubscribeProgress(backtestId)` при размонтировании, если компонент был последним потребителем, либо перенести управление подпиской на страницу-контейнер.

#### 🟠 rAF-цикл перерисовки фоновых зон в `InstrumentChart` работает даже на скрытом компоненте — `frontend/src/components/backtest/InstrumentChart.tsx:289`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `requestAnimationFrame`-цикл запускается безусловно на каждый созданный `chart` и вызывает `drawBgZones()` до 60 раз/сек всё время жизни компонента, включая случаи, когда контейнер скрыт (`display:none` при переключении вкладок). Постоянная нагрузка CPU/GPU; на скрытом контейнере (`clientWidth===0`) возможны нулевые размеры canvas.

- **Рекомендация:** Останавливать rAF при `document.hidden` / через `IntersectionObserver`, либо перерисовывать по событию `subscribeVisibleTimeRangeChange` вместо цикла на каждый кадр.

#### 🟠 `PnLDistributionHistogram`: `bucketCount` не ограничен сверху — риск подвесить рендер на аномальных данных — `frontend/src/components/backtest/PnLDistributionHistogram.tsx:50`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `bucketCount = Math.round((upperBound - lowerBound) / bucketSize)` не ограничен сверху. При аномальном выбросе `pnl_pct` (баг бэкенда или доли вместо процентов) диапазон становится огромным при мелком `bucketSize` — создаются десятки тысяч бакетов, каждый рендерит `Tooltip`+`Box`, что подвешивает рендер.

- **Рекомендация:** Ограничить `bucketCount` сверху (например, 200) и агрегировать хвостовые значения в крайние бакеты.

### 🟡 Medium

#### 🟡 `GridSearchForm`: даты `type="date"` трактуются как UTC-полночь — сдвиг диапазона на границе суток — `frontend/src/components/backtest/GridSearchForm.tsx:209`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `dateFrom`/`dateTo` — строки `YYYY-MM-DD` из `<input type="date">`. При сборке запроса дата принудительно интерпретируется как UTC-полночь (`+'T00:00:00Z'`), что расходится с локальным (МСК) восприятием пользователя. Для тикеров MOEX может сдвинуть первую/последнюю сессию грид-серча относительно того, что показывает форма.

- **Рекомендация:** Выровнять политику: использовать смещение МСК либо явно указать в UI, что даты трактуются как UTC.

#### 🟡 `ParityBadge`: двусмысленная семантика полей `bt`/`it` (число vs булево) при значении `0` — `frontend/src/components/backtest/ParityBadge.tsx:37`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В разных `reason` поля `backtrader`/`interpreter` используются то как номер бара (`typeof === 'number'`, корректно учитывает `0`), то как признак наличия сделки (`!= null`). Единого типа в `ParityDivergence` нет — при значении `0` ветки могут интерпретироваться неоднозначно.

- **Рекомендация:** Задать union-типы `ParityDivergence` под каждый `reason`, чтобы исключить двусмысленность `0`/`null`/`false`.

#### 🟡 `BacktestTrades`: `duration_days === 0` показывается как «0 ч» вместо «—» — `frontend/src/components/backtest/BacktestTrades.tsx:143`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Для `duration_days < 1` считается `Math.round(days*24)` часов. Если `duration_days === 0` (сделка закрыта в ту же секунду или backend прислал `0` как заглушку «нет данных»), UI покажет «0 ч» — выглядит как валидная мгновенная сделка.

- **Рекомендация:** Трактовать `0` как edge case, уточнить у бэкенда семантику нулевой длительности, показывать «<1 ч» или «—».


---

## 25. Frontend: конструктор стратегий (strategy, blockly)

Проверены все production-файлы конструктора стратегий: `components/strategy` (9 файлов), `components/blockly` (5 файлов), `utils/blocksToTemplate.ts`, `utils/flatBlocksToWorkspace.ts`. TypeScript-компиляция чистая, критичных/high уязвимостей не выявлено, весь вывод идёт через React/Mantine без `dangerouslySetInnerHTML`/`innerHTML`. Главная системная проблема — фрагментация: накопились мёртвые дублирующие компоненты (CodePanel/CodeDisplay/TemplatePanel вместо используемого SharedDescriptionPanel) и несколько независимых источников правды (toolbox-список блоков, EMPTY_TEMPLATE в трёх вариантах), что создаёт риск рассинхронизации при будущих правках. Из багов отмечены: несинхронизируемый optimistic-статус в StrategyStatusMenu, отсутствие защиты от циклических ссылок в flatBlocksToWorkspace.ts (риск падения редактора), наивный построчный diff версий и проглатывание ошибки парсинга blocks_json без уведомления пользователя. Единственная security-находка — десериализация Blockly workspace без валидации типов блоков против allow-list, сейчас low-риск, но актуализируется при появлении шаринга стратегий. Не проверялись: `pages/StrategyEditPage.tsx` (ключевой потребитель обеих utils, вне зоны) и backend-контроль владения версиями стратегий.

### 🟠 High

#### Загрузка Blockly workspace state/XML без валидации типов блоков против allow-list — `frontend/src/components/strategy/BlocklyWorkspace.tsx:196`

- **Категория:** уязвимость  |  **Верификация:** — не проверялось

- **Проблема:** `initialBlocksXml` (blocks_json версии стратегии) десериализуется через `Blockly.serialization.workspaces.load`, а при ошибке — через XML fallback `Blockly.Xml.domToWorkspace(Blockly.utils.xml.textToDom(...))` без проверки, что `block.type` входит в allow-list `ALL_BLOCKS`. Сейчас поле контролируется только владельцем стратегии через `/strategy/{id}/versions`, шаринга/импорта чужих стратегий в этой зоне нет, поэтому прямой XSS не реализован. Но если в будущем появится шаринг стратегий между пользователями либо на бэкенде окажется ослаблен IDOR-контроль владения в `GET /strategy/{id}/versions/by-id/{ver_id}`, в компонент попадёт чужой workspace state с произвольным `type`/`fields` без серверной валидации; в связке с кастомными полями типа `FieldImage` с `data:image/svg+xml` (BlockDefinitions.ts:236) это даёт поверхность для спекулятивной атаки через рендеринг непроверенных полей.

- **Рекомендация:** На бэкенде при сохранении/восстановлении версии валидировать blocks_json по строгой схеме (allow-list типов из `ALL_BLOCKS` + разрешённые поля/значения), отклоняя неизвестные type. На фронте перед `workspaces.load`/`domToWorkspace` проверять `block.type ∈ ALL_BLOCKS`. Дополнительно убедиться, что `/strategy/{id}/versions/by-id/{ver_id}` и restore проверяют принадлежность `owner_id`, а не только существование id.

*Примечание: находка изначально оценена автором ревью как low-severity (нет текущего вектора эксплуатации в зоне файлов), но повышена до High в этой сводке из-за характера риска (десериализация недоверенных данных без схемной валидации) и потенциального воздействия при ослаблении серверного контроля — рекомендуется приоритизировать проверку соответствующего backend-эндпоинта.*

### 🟡 Medium

#### Мёртвые дублирующие компоненты CodePanel/CodeDisplay/TemplatePanel не используются в production — `frontend/src/components/strategy/CodePanel.tsx`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** CodePanel.tsx (144 строки), CodeDisplay.tsx (67 строк) и TemplatePanel.tsx (191 строка) не импортируются нигде в production-коде (grep по всему src/ кроме `__tests__` и самих файлов не находит потребителей) — их функциональность полностью поглощена SharedDescriptionPanel.tsx, единственным подключённым в StrategyEditPage.tsx. CodeDisplay и CodePanel к тому же почти буквально дублируют друг друга (идентичный header/code-area JSX, разница только в блоке статусов). При будущих правках логики отображения кода/шаблона разработчик может по ошибке отредактировать неиспользуемый файл и не увидеть эффекта, либо тесты этих файлов будут создавать видимость покрытия несуществующего в UI функционала.

- **Рекомендация:** Удалить CodePanel.tsx, CodeDisplay.tsx, TemplatePanel.tsx вместе с их тестами, либо, если они зарезервированы под будущий functionality-toggle, явно задокументировать это и подключить хотя бы за feature-flag.

#### Список блоков toolbox продублирован в двух независимых источниках правды — `frontend/src/components/blockly/BlocklyToolbox.ts:1`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `toolboxConfig` в BlocklyToolbox.ts и `CATEGORIES` в CustomToolbox.tsx независимо перечисляют один и тот же набор блоков (indicator_sma, indicator_ema, ... management_take_profit) со своими подписями/группировкой. `toolboxConfig` при этом экспортируется из `components/blockly/index.ts`, но реально нигде не потребляется (grep не находит использования, только реэкспорт) — это мёртвый код. Реальный toolbox рендерится через CustomToolbox.tsx. При добавлении нового типа блока (что происходит регулярно, судя по BlockDefinitions.ts с 20 типами блоков) разработчик с высокой вероятностью обновит только один из двух списков — например, добавит новый indicator_* в BlockDefinitions без синхронизации CATEGORIES, и блок станет недоступен для добавления через панель (хотя формально существует и может прийти через AI/template-парсер).

- **Рекомендация:** Удалить неиспользуемый `toolboxConfig` (или, если легаси-Blockly-toolbox планируется вернуть, генерировать оба списка из единого источника — например, экспортировать CATEGORIES из BlockDefinitions.ts и строить toolboxConfig программно из него).

#### Ошибка загрузки блоков стратегии проглатывается без уведомления пользователя — `frontend/src/components/strategy/BlocklyWorkspace.tsx:205`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В useEffect загрузки initialBlocksXml (строки 196-229): если JSON.parse/Blockly.serialization.workspaces.load падает, код логирует в console.error и пытается XML-fallback; если и XML-fallback падает (пустой catch, комментарий "// Ignore invalid data"), рабочая область уже была очищена вызовом `ws.clear()` и остаётся пустой без единого визуального сигнала пользователю. Пользователь, открывший редактор существующей стратегии с повреждёнными/несовместимыми blocks_json (например, после отката миграции формата блоков или ручной правки в БД), увидит пустой холст и решит, что стратегия действительно не содержит блоков, и может пересохранить её, необратимо затерев исходные данные на бэкенде при следующем autosave/handleBlocksChange.

- **Рекомендация:** При провале обеих путей парсинга показывать `notifications.show` с ошибкой ("Не удалось загрузить блоки стратегии — проверьте данные") и/или не выполнять `ws.clear()` до успешного parse второго формата, чтобы не терять исходное состояние на экране.

#### Локальный optimistic-статус не синхронизируется с изменением currentStatus извне — `frontend/src/components/strategy/StrategyStatusMenu.tsx:58`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `const [optimistic, setOptimistic] = useState<string>(currentStatus)` инициализирует state только при первом маунте компонента. Если родитель (Dashboard/Sidebar) перерисовывает этот же смонтированный экземпляр с новым `currentStatus` (например, после фонового рефетча списка стратегий, WS-события об изменении статуса из другой сессии/вкладки, или после отмены/восстановления версии, которая меняет статус), локальный `optimistic` не обновится — бейдж продолжит показывать устаревший статус, а `allowedSet`/переходы будут рассчитаны от неверного текущего статуса. Пользователь увидит, например, «Черновик», хотя стратегия уже переведена в «Real Trading» другим процессом, и получит недоступные/неверные пункты меню переходов.

- **Рекомендация:** Добавить `useEffect(() => { setOptimistic(currentStatus); }, [currentStatus])` либо использовать `key={strategyId}` на уровне родителя для сброса, либо убрать локальный стейт и опираться только на store/проп с отдельным полем `pendingStatus` для optimistic-индикации.

#### resolveBlock не защищён от циклических ссылок между блоками — бесконечная рекурсия — `frontend/src/utils/flatBlocksToWorkspace.ts:269`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `resolveBlock` дедуплицирует повторное использование одного и того же `refId` через `usedIds`, но при циклической ссылке (блок A ссылается сам на себя, либо цикл A→B→A через `left`/`right`/`condition`/`conditions`) каждый повторный визит блока с тем же `refId` создаёт лишь новый id (`${refId}_dup${n}`) и продолжает рекурсивный спуск в `attachInput`→`resolveBlock` по тому же `refId` — `usedIds.has(refId)` не останавливает рекурсию, а только генерирует очередной дубликат. Если backend когда-либо вернёт повреждённые/циклические blocks_json (баг парсера, ручное редактирование через API, порча в БД), при открытии такой стратегии в редакторе произойдёт `RangeError: Maximum call stack size exceeded`, и страница редактирования станет непригодной для использования (нельзя будет восстановить/поправить стратегию через UI).

- **Рекомендация:** Передавать в resolveBlock/attachInput отдельный Set "текущий путь рекурсии" (visiting-set, отдельно от usedIds-для-дедупликации) и прерывать с понятной ошибкой/логом при обнаружении цикла, вместо бесконечного создания дублей с одним и тем же refId.

### 🔵 Low

#### Константа EMPTY_TEMPLATE (7-секционный шаблон) дублируется дословно, третий вариант шаблона расходится по структуре — `frontend/src/components/strategy/TemplatePanel.tsx:24`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** EMPTY_TEMPLATE в TemplatePanel.tsx (строки 24-43) и SharedDescriptionPanel.tsx (строки 28-47) — побайтово идентичная многострочная константа с 7 секциями (ИНДИКАТОРЫ/УСЛОВИЯ ВХОДА/.../ФИЛЬТРЫ). При этом в TemplateModeModal.tsx (строки 23-51) объявлена третья версия EMPTY_TEMPLATE с 10 пронумерованными секциями (включая НАЗВАНИЕ, ИНСТРУМЕНТЫ, ТАЙМФРЕЙМ, которых нет в двух других). Если бэкенд-парсер шаблонов (template_parser) изменит ожидаемый формат секций, есть риск обновить только один-два из трёх мест, и пользователи, скопировавшие "пустой шаблон" из другого модала/панели, получат текст, который парсер либо не распознаёт, либо распознаёт не полностью.

- **Рекомендация:** Вынести единственный EMPTY_TEMPLATE (или, если реально существуют два разных формата — короткий и полный с метаданными — переименовать их по-разному, например EMPTY_TEMPLATE_SHORT/EMPTY_TEMPLATE_FULL) в общий модуль (например utils/strategyTemplateText.ts) и импортировать во все три компонента.

#### Дедупликация id блоков реализована через module-level мутируемую переменную _dupCounter — `frontend/src/utils/flatBlocksToWorkspace.ts:262`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `_dupCounter` (строка 262) — module-scope let, инкрементируется внутри resolveBlock/attachInput и сбрасывается в начале flatBlocksToWorkspaceState (строка 379). Функция не реентерабельна: если flatBlocksToWorkspaceState будет вызвана параллельно для двух разных стратегий (например, в будущем при параллельной предзагрузке нескольких стратегий или вызове из Promise.all), сброс счётчика в одном вызове перепишет прогресс другого, и сгенерированные ID дублей (`${refId}_dup${_dupCounter}`) могут схлопнуться между двумя независимыми workspace-стейтами. Сейчас единственная точка вызова — синхронный код в StrategyEditPage.tsx, поэтому баг не проявляется, но это скрытая ловушка при рефакторинге на параллельную загрузку.

- **Рекомендация:** Передавать счётчик как локальную переменную/объект-аккумулятор через параметры функции (например `{ value: 0 }` объект или замыкание, создаваемое заново в каждом вызове flatBlocksToWorkspaceState) вместо module-level state.

#### lineDiff — наивный построчный diff без выравнивания искажает сравнение версий — `frontend/src/components/strategy/VersionsHistoryDrawer.tsx:79`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** lineDiff сравнивает строки только по индексу (`aLines[i] === bLines[i]`) без поиска общей подпоследовательности. При добавлении/удалении даже одной строки в середине generated_code/blocks_json весь последующий текст помечается как full removed+added построчно, хотя реально изменилась только одна строка. Пользователь, сравнивающий версии стратегии перед restore, увидит "стену" красного/зелёного там, где стоп-лосс/тейк-профит фактически не менялись, и может ошибочно принять решение о restore, не увидев реальную точку различия.

- **Рекомендация:** Использовать простой LCS-based diff (или существующую библиотеку diff/jsdiff, если разрешено добавить зависимость) вместо позиционного сравнения; либо явно пометить в UI, что это только "line-by-line" сравнение без выравнивания.

---

Не проверялось (вне зоны ревью): `pages/StrategyEditPage.tsx` (1101 строка, ключевой потребитель BlocklyWorkspace/flatBlocksToWorkspace и обеих utils); backend-контроль владения версиями стратегий (`backend/app/strategy/` — авторизация эндпоинтов versions, серверная валидация blocks_json); расхождение формата percent/points для stop_loss/take_profit между frontend-генератором и backend (block_parser.py, code_generator.py) — обнаружено, но локализовано вне frontend-зоны. Тесты на `blocksToTemplate.ts` (322 строки рекурсивной логики) отсутствуют — критичная для UX логика форматирования текстового описания стратегии не покрыта.

Отклонено при верификации: находок со статусом refuted нет — все findings имеют verify_status "not_checked".


---

## 26. Frontend: торговля, дашборд, счёт (trading, dashboard, account)

Качество кода в проверенной зоне выше среднего: строгая типизация Decimal-строк, аккуратный WebSocket-хук без утечек подписок, в account/ — хорошая практика переиспользования `utils/formatters.ts` и мемоизации тяжёлых вычислений. Системная слабость — рассинхрон практик между модулями: trading/ заново реализует форматтеры даты/суммы в 4-5 файлах вместо переиспользования общего модуля, что уже привело к разному парсингу дат в разных таблицах. Среди багов выделяются два high-severity: race condition при перезаписи данных сессии устаревшими ответами в `tradingStore`, и рассинхрон сериализации дат сессии на бэкенде (нет `iso_utc()`-serializer), из-за чего время на карточках сессий сдвигается на 3 часа для московских пользователей. Уязвимостей категории security не обнаружено — весь рендер идёт через стандартный React JSX, секреты в этой зоне не хранятся и не логируются. Runtime-проверка не выполнялась, только статический анализ; Blockly/graph-компоненты вне зоны ревью.

### 🟠 High

#### 🟠 Race condition: устаревший ответ fetchPositions/fetchTrades/fetchStats перетирает данные другой сессии — `frontend/src/stores/tradingStore.ts:156`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** `fetchPositions`, `fetchTrades`, `fetchStats` и `fetchSession` не проверяют, что `sessionId` ответа совпадает с текущей открытой сессией (нет `AbortController`, нет guard по актуальному id). В `SessionDashboard.tsx` (строки 55-66) при смене `sessionId` (быстрый переход между сессиями) вызывается `fetch*` для нового id без отмены предыдущих promise. Если ответ для сессии A придёт позже ответа для B, `set({positions/trades/stats})` перезапишет актуальные данные сессии B устаревшими данными A. Для `activeSession` есть guard (`activeSession.id !== sessionId`, строка 96), но он защищает только шапку — positions/trades/stats читаются без проверки, поэтому пользователь может увидеть чужие позиции/P&L на экране активной сессии. Store глобален, а один route на `:id` не размонтирует компонент при смене сессии, так что запоздалый resolve перезапишет данные даже после навигации.

- **Рекомендация:** Добавить в `tradingStore` проверку актуальности перед `set()` (сравнивать `sessionId` ответа с `get().activeSession?.id`) либо использовать `AbortController`/request-token паттерн, игнорируя ответы с устаревшим id.

#### 🟠 SessionResponse сериализует даты без Z-суффикса — время сессии сдвигается на 3 часа на фронтенде — `backend/app/trading/schemas.py:110`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено (с уточнением)

- **Проблема:** `TradingSession.started_at/stopped_at/last_signal_at` хранятся как naive UTC datetime (`models.py`, `DateTime` без timezone, `server_default=func.now()`). В отличие от `TradeResponse` (schemas.py:154-156) с `@field_serializer(..., when_used='json')` и `iso_utc()`, `SessionResponse` такого serializer не имеет — Pydantic отдаёт строку без `Z`. На фронте `SessionCard.tsx` (строки 21-30, рендерит `started_at`/`last_signal_at`) использует `new Date(iso)` напрямую вместо уже существующего `parseBackendDate()` (используется в `TradesTable.tsx`). Браузер интерпретирует строку без TZ как local time — для московского пользователя (UTC+3) дата запуска и время последнего сигнала будут показаны на 3 часа раньше реального. Тот же класс проблемы, что закрытый ранее BUG-3/4, но не устранённый для сессий. Уточнение при верификации: `SessionDashboard.tsx` сам не содержит `new Date`, лишь композирует `SessionCard` — баг там опосредован, но суть находки не отменяется.

- **Рекомендация:** Добавить `@field_serializer('started_at','stopped_at','last_signal_at', when_used='json')` с `iso_utc()` в `SessionResponse`, и на фронтенде заменить `new Date(iso)` на `parseBackendDate(iso)` в `SessionCard.tsx` — по аналогии с уже исправленным BUG-3/4 в `TradesTable.tsx`.

### 🟡 Medium

#### 🟡 Мёртвый компонент на хардкоженных mock-данных, нигде не используется в production — `frontend/src/components/dashboard/StrategyTable.tsx:26`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Весь компонент `StrategyTable` (231 строка) построен вокруг константы `MOCK_DATA` с зашитыми тикерами SBER/GAZP/LKOH/YNDX/MTSS, P&L и датами бэктестов. Grep по всему `src/` (исключая тесты) не находит ни одного импорта этого компонента ни в `pages/`, ни в других компонентах. Если компонент всё же где-то подключается динамически или временно оставлен «для истории», заказчик получит страницу с вымышленными данными вместо реальных стратегий, что для торгового терминала выглядит как грубая имитация функциональности.

- **Рекомендация:** Либо удалить файл как техдолг (реальная таблица стратегий сейчас в другом месте), либо явно пометить компонент как WIP/unused (исключить из билда, добавить TODO с номером задачи) и подтвердить с заказчиком, что он не импортируется по ошибке.

#### 🟡 Дублирование форматтеров рубля/цены/даты вместо переиспользования utils/formatters.ts — `frontend/src/components/trading/SessionCard.tsx:10`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Функции `formatPnl`/`formatPrice`/`formatDate`/`formatTime` в `SessionCard.tsx` почти буквально повторены в `SessionDashboard.tsx` (17-23), `PositionsTable.tsx` trading/ (4-9), `TradesTable.tsx` (5-10) и `PnLSummary.tsx` (7-12) — все реализуют одну и ту же формулу `toLocaleString('ru-RU', {...})`. Централизованный `frontend/src/utils/formatters.ts` уже существует и используется в `account/BalanceCards.tsx` и `account/OperationsTable.tsx`. Изменение формата потребует синхронной правки 5 файлов — риск разъехаться уже реализовался: `TradesTable` использует `parseBackendDate`, а `SessionCard` — голый `new Date(iso)`, то есть даты в разных таблицах трейдинга парсятся по-разному.

- **Рекомендация:** Вынести единые `formatMoney(value)`/`formatPct`/`formatDateTime` в `utils/formatters.ts` (расширив поддержкой null и Decimal-string), заменить локальные копии во всех перечисленных файлах trading/.

#### 🟡 LaunchSessionModal смешивает форму, валидацию, поиск инструментов и бизнес-логику parity в одном 526-строчном файле — `frontend/src/components/trading/LaunchSessionModal.tsx:62`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Компонент содержит: debounce-поиск тикеров с ручным ref на таймер, загрузку брокерских счетов, загрузку и матчинг версий стратегии (цикл try/catch по кандидатам `strategy.getById`), паттерн «set state during render» в трёх местах (159-167, 208-224), полную форму с 8+ полями, валидацию и обработку 409 parity-ошибок. Такой объём ответственности затрудняет тестирование отдельных частей (например, логика подбора `initialStrategyVersionId` в useEffect 90-128 нетривиальна и не вынесена в функцию/хук) и повышает риск регрессии при правках.

- **Рекомендация:** Выделить: (1) хук `useTickerAutocomplete` для debounce-поиска (переиспользуется в `SparklineWidget.tsx`), (2) хук `useStrategyOptionsForLaunch(initialStrategyVersionId)`, (3) хук `useLaunchForm` для полей формы и валидации. Компонент должен остаться тонкой презентационной обёрткой.

#### 🟡 Частичный сброс диапазона дат не применяет фильтр — таблица показывает данные по старому диапазону — `frontend/src/components/account/OperationsTable.tsx:56`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `handleFromChange`/`handleToChange` вызывают `onDateRangeChange` только когда обе даты установлены либо обе пусты. Сценарий: пользователь выбрал «С» и «По» (фильтр применён), затем очищает «С» — `handleFromChange(null)` вызывается с `dateTo` всё ещё установленным: оба условия (`d && dateTo`, `!d && !dateTo`) ложны → `onDateRangeChange` не вызывается вовсе. Локальный state `dateFrom` обнулён (поле в UI пустое), но перезагрузка операций не срабатывает — таблица продолжает показывать данные по старому `dateFrom`, хотя визуально фильтр «С» пуст.

- **Рекомендация:** При изменении одной даты, если вторая всё ещё задана, а текущая обнулена — вызывать `onDateRangeChange(undefined, dateTo?.toISOString())` (аналогично для `handleToChange`), чтобы фильтр синхронизировался с фактическим состоянием обоих полей.

#### 🟡 useEffect авто-паузы может повторно вызвать pauseSession пока модалка ещё открыта — `frontend/src/components/trading/PauseConfirmModal.tsx:20`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `useEffect` зависит от объекта `session` целиком (новая ссылка при каждом WS-обновлении). Сценарий: пользователь открывает паузу для сессии без позиции — эффект стартует `pauseSession(id).then(onClose())`, `onClose` асинхронно ставит `setPauseModalOpen(false)` после resolve. Если за это время в store прилетит WS-апдейт сессии (новая ссылка, `hasPosition` всё ещё false, `opened` всё ещё true), эффект сработает повторно и вызовет `pauseSession(session.id)` второй раз для уже приостанавливаемой сессии — лишний API-запрос.

- **Рекомендация:** Убрать `session` целиком из зависимостей useEffect, оставить `session.id` и `hasPosition`, либо добавить ref-флаг, блокирующий повторный вызов `pauseSession` до закрытия модалки.

### 🔵 Low

#### 🔵 Дублирование debounce-логики поиска тикеров между SparklineWidget и LaunchSessionModal — `frontend/src/components/dashboard/SparklineWidget.tsx:122`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `handleTickerSearch` в `SparklineWidget.tsx` (122-144, с `searchDebounceRef`, 300мс debounce, вызовом `marketDataApi.searchInstruments`) почти дословно копирует одноимённую функцию в `LaunchSessionModal.tsx` (184-202) — комментарий в коде сам указывает на источник копирования, то есть дублирование осознанное, но не устранённое. Два независимых места для внесения любых изменений поведения поиска.

- **Рекомендация:** Вынести общий хук `useTickerSearch(onResults)` в `hooks/` и использовать его в обоих компонентах и будущих местах с автокомплитом тикеров.

#### 🔵 Debounced поиск тикеров без отмены/проверки актуальности — устаревший ответ может перетереть свежие подсказки — `frontend/src/components/trading/LaunchSessionModal.tsx:192`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `clearTimeout` защищает только от ещё не сработавшего таймера, но не от уже отправленных запросов. Сценарий: пользователь печатает «SB», через 300мс уходит запрос, затем быстро дописывает «ER» — второй запрос «SBER» уходит через ещё 300мс. Если ответ на «SB» придёт позже ответа на «SBER», `setTickerSuggestions` перезапишет актуальный список подсказок устаревшими результатами. Аналогичный паттерн в `dashboard/SparklineWidget.tsx:129`.

- **Рекомендация:** Использовать `AbortController` на каждый запрос или сверять query с текущим значением поля перед `setTickerSuggestions` в колбэке ответа.

#### 🔵 Признак «есть ещё страница» для пагинации сделок — эвристика по остатку от деления, ломается на границе кратности 50 — `frontend/src/components/trading/SessionDashboard.tsx:244`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `hasMore={trades.length > 0 && trades.length % 50 === 0}` — если у сессии ровно 50, 100, 150... сделок и это действительно последняя страница, кнопка «Загрузить ещё» всё равно отобразится. Пользователь нажмёт её, backend вернёт пустой список, кнопка не исчезнет (тот же `trades.length`), и пользователь может кликать бесконечно без обратной связи о том, что данных больше нет.

- **Рекомендация:** Использовать явный признак от backend (total count или `has_more` флаг в `PaginatedResponse`) вместо эвристики по остатку деления; либо скрывать кнопку после первого пустого ответа, сохраняя флаг `isLastPageEmpty` в сторе.

#### 🔵 Паттерн «set state during render» используется трижды подряд для разных полей — усложняет чтение и рискован при добавлении новых сравнений — `frontend/src/components/trading/LaunchSessionModal.tsx:159`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Строки 159-167 (сброс mode/brokerAccountId) и 208-224 (пересинхронизация ticker/timeframe/strategyVersionId) вызывают `setState` прямо в теле функции компонента, сравнивая текущее значение с предыдущим через дополнительные shadow-переменные `lastMode`/`lastOpened`. Валидный React-паттерн, но три независимых блока в одном компоненте создают неочевидный порядок выполнения при ре-рендерах — не с первого взгляда понятно, что произойдёт, если `opened` и `mode` изменятся в одном рендере.

- **Рекомендация:** Свести к одному `useEffect` с зависимостью `[opened]` для инициализации при открытии и отдельному `useMemo`/derived-value для `modeOptions` без побочных `setState` в теле рендера.

#### 🔵 Расчёт pnlPct использует initial_capital сессии как знаменатель без защиты от NaN и с произвольным fallback на 1 — `frontend/src/components/dashboard/ActivePositionsWidget.tsx:47`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `const cap = Number(s.initial_capital) || 1;` — при `initial_capital`, равном строке '0' или невалидной Decimal-строке, `cap=1`, и `pnlPct = pnl/1*100` даёт дикие проценты вроде «+500000.00%» вместо корректной обработки отсутствия капитала. Аналогичный паттерн уже был явно исправлен в `SessionCard.tsx` (строка 136-151, с проверкой `Number(session.initial_capital) > 0`) — несогласованность между двумя похожими виджетами.

- **Рекомендация:** При `cap <= 0` или NaN — не показывать `pnlPct` вовсе (return null для этого поля), аналогично условной проверке в `SessionCard`.

#### 🔵 collectSuggestedTickers пересчитывается в нескольких местах без единого источника правды — `frontend/src/components/trading/LaunchSessionModal.tsx:173`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `collectSuggestedTickers(userStrategies)` вызывается в lazy-init `useState` (174), в `handleTickerSearch` при пустом query (188), в блоке `lastOpened` (211) и в отдельном `useEffect` (229-234) — 4 разных места, реагирующих на пересечение `(opened, ticker, userStrategies)` с разными условиями. Функционально работает, но для нового разработчика неочевидно, какой из 4 путей сработает первым, что повышает риск регрессии при рефакторинге логики подсказок.

- **Рекомендация:** Свести к одному `useMemo(() => collectSuggestedTickers(userStrategies), [userStrategies])` как базовому списку «по умолчанию» и использовать его во всех трёх точках вместо повторных вызовов функции с побочными `setState`.

#### 🔵 Статус сессии suspended визуально неотличим от stopped — вводит в заблуждение относительно причины остановки — `frontend/src/components/trading/sessionMode.ts:20`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** Backend использует статус `suspended` для сессий, приостановленных автоматически при рестарте сервера, в отличие от `stopped` (пользователь сам остановил). В `SessionCard.tsx` (statusColor/statusLabel, 59-65) и `SessionDashboard.tsx` `suspended` попадает в `default`: цвет gray, текст «Остановлена» — то же самое, что и для явно завершённой пользователем сессии. Пользователь не может по UI отличить свою остановку от прерывания из-за рестарта сервера.

- **Рекомендация:** Добавить отдельную ветку для `status === 'suspended'` с отличимым цветом/лейблом, используя тот же принцип, что уже применён в `getSessionModeMeta`.

### Security-check (без findings)

Проверка на уязвимости (dangerouslySetInnerHTML/eval/window.open, утечки токенов в localStorage/логах, сторонние домены, CSRF) не выявила проблем в зоне trading/dashboard/account — весь рендер идёт через стандартный React JSX с авто-экранированием, localStorage используется только для UI-предпочтений, авторизация вне зоны ревью.


---

## 27. Frontend: прочий UI (ai, notifications, settings, wizard, layout, common)

Просмотрены все production TS/TSX файлы в ai/, notifications/, settings/, wizard/, layout/, common/ (24–26 файлов, ~4800 строк). Общее качество хорошее: компоненты небольшие, loading/error почти везде обработаны, много поясняющих комментариев о нетривиальных решениях. Найден один реальный высокоприоритетный баг — автозакрытие критического баннера ломается при активном потоке уведомлений, а также ряд средних и мелких проблем: утечка blob-URL, тройное дублирование логики уведомлений, неполная инвалидация состояния формы добавления брокера, отсутствие реакции на частичные ошибки при массовом включении уведомлений в wizard, и несколько мелких проблем производительности. Критичных уязвимостей безопасности не найдено: XSS исключён (автоэкранирование Mantine, отсутствие dangerouslySetInnerHTML/eval), секреты (API-ключи, Telegram bot_token) вводятся через маскированные поля и не попадают в localStorage/query/консоль, редиректы и window.open используют только серверные enum-значения и same-origin пути.

### 🟠 High

#### 🟠 Автозакрытие критического баннера ломается при любом новом уведомлении — `frontend/src/components/notifications/CriticalBanner.tsx:12`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** criticalNotifications вычисляется через notifications.filter(...) в теле компонента без useMemo — новый массив на каждый рендер. useEffect с зависимостью [criticalNotifications, dismiss] срабатывает на КАЖДОЕ изменение notifications в сторе (не только критических — любое новое уведомление любого severity, приходящее по WS). Cleanup-функция эффекта вызывает currentTimers.clear() (очищает Map целиком, не только просроченные), а затем цикл заново создаёт таймеры на AUTO_DISMISS_MS=30000 для всех текущих критических уведомлений. Итог: если во время показа критического алерта (например, cb_triggered при экстренной остановке торговли) приходит хотя бы одно любое другое уведомление раньше истечения 30 секунд — 30-секундный отсчёт сбрасывается и начинается заново. При активном потоке уведомлений (типично во время торговой сессии) критический баннер может никогда не закрыться автоматически, требуя ручного закрытия пользователем. Подтверждено трассировкой: CriticalBanner.tsx:8 подписан на весь notifications; строки 12–14 создают новую ссылку каждый рендер (нет useMemo); useEffect(26-41) зависит от [criticalNotifications, dismiss], Object.is даёт перезапуск при любом ререндере. notificationStore.ts:137-142 addFromWS добавляет любое уведомление без фильтра severity, вызывается из NotificationBell.tsx:41-44 на каждый WS notification.new; оба компонента глобальны в App.tsx, общий стор — некритическое уведомление триггерит ререндер баннера. Cleanup(37-40) чистит все таймеры, новый проход(27-35) ставит их заново на 30000мс без защиты.

- **Рекомендация:** Мемоизировать criticalNotifications через useMemo по стабильному ключу (например, join id критических непрочитанных). В cleanup эффекта не делать currentTimers.clear() безусловно — очищать только таймеры уведомлений, которых больше нет в списке, оставляя таймеры для всё ещё критических/непрочитанных нетронутыми. Либо перейти на хранение deadline (absolute timestamp) вместо relative setTimeout, чтобы повторный запуск эффекта не сбрасывал прогресс.

### 🟡 Medium

#### 🟡 Утечка blob-URL для превью вложений-изображений — `frontend/src/components/ai/ChatInput.tsx:171`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** URL.createObjectURL(file) вызывается напрямую в JSX внутри map по attachments при каждом рендере ChatInput (например, при каждом нажатии клавиши в textarea, так как text — state того же компонента). Возвращаемый blob: URL нигде не сохраняется и не освобождается через URL.revokeObjectURL — при активной переписке с несколькими прикреплёнными изображениями создаётся десятки/сотни объектных URL за сессию, которые остаются в памяти до полной перезагрузки страницы.

- **Рекомендация:** Создавать objectURL один раз на файл (например, в useMemo/useState при handleFileSelect или в useEffect с зависимостью от attachments) и вызывать URL.revokeObjectURL при удалении вложения / размонтировании компонента.

#### 🟡 Тройное дублирование SEVERITY_EMOJI/getNotificationLink/formatRelativeTime/NotificationItem — `frontend/src/components/notifications/NotificationDrawer.tsx:8`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** SEVERITY_EMOJI, getNotificationLink, formatRelativeTime и почти идентичный компонент NotificationItem продублированы буквально (с минимальными отличиями в вёрстке) между NotificationDrawer.tsx (строки 8-111) и NotificationList.tsx (строки 10-121); карта SEVERITY_EMOJI (и родственная SEVERITY_COLOR) продублирована ещё и в NotificationBell.tsx. При добавлении нового event_type/related_entity_type или severity разработчик должен не забыть обновить 3 разных места — велик риск рассинхронизации (например, ссылка на новый related_entity_type будет добавлена в одном файле и забыта в другом, из-за чего «Перейти» в drawer будет работать, а в общем списке уведомлений — нет).

- **Рекомендация:** Вынести SEVERITY_EMOJI/SEVERITY_COLOR, getNotificationLink, formatRelativeTime в общий модуль (например, utils/notificationFormatting.ts), а NotificationItem — в общий компонент с props для variant (drawer-компакт/list-развёрнутый), переиспользуемый обоими местами.

#### 🟡 Массовое включение Telegram/Email уведомлений в wizard без реакции на частичные ошибки — `frontend/src/components/wizard/FirstRunWizard.tsx:240`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** В handleFinish при telegramReady true выполняется Promise.all по 4 event_type с .catch(() => null) на каждый вызов updateSetting — при ошибке сервера (например, 500 или временная недоступность backend) пользователь не получает никакого уведомления о том, что часть критичных типов события (trade_opened/trade_closed/cb_triggered/order_error) не была включена, wizard всё равно бодро репортует «Настройка завершена». Пользователь может считать, что уведомления о срабатывании circuit breaker включены, хотя фактически часть или все settings не сохранились — узнает об этом только когда реально пропустит critical-алерт о принудительной остановке торговли.

- **Рекомендация:** Собирать результаты Promise.allSettled, и если хотя бы один updateSetting завершился ошибкой — показать warning-notification с перечнем не сохранившихся типов, чтобы пользователь мог перепроверить Настройки → Уведомления вручную.

#### 🟡 discoveredAccounts не инвалидируются при изменении apiKey/apiSecret/brokerType после Discover — `frontend/src/components/settings/AddBrokerForm.tsx:71`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** После успешного handleDiscover пользователь может изменить apiKey, apiSecret или brokerType, не нажимая повторно «Обнаружить счета» — discoveredAccounts/selectedAccounts остаются от предыдущего запроса. validate() проверяет только discoveredAccounts.length > 0, а не их актуальность относительно текущих apiKey/brokerType. handleSubmit() в этом случае отправит addAccount с новым (изменённым) apiKey, но с selected_account_ids от СТАРОГО обнаружения — сервер может создать привязку к несуществующим/чужим account_id или получить рассинхрон между ключом и списком счетов.

- **Рекомендация:** Сбрасывать discoveredAccounts/selectedAccounts (resetForm-подобно, но частично) при любом onChange apiKey/apiSecret/brokerType после того, как Discover уже был выполнен — чтобы пользователь был вынужден повторно нажать «Обнаружить счета» перед сохранением с новыми учётными данными.

### 🔵 Low

#### 🔵 TYPE_BADGE_CONFIG пересоздаётся на каждый рендер AppHeader — `frontend/src/components/layout/Header.tsx:78`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Константный объект TYPE_BADGE_CONFIG объявлен внутри тела компонента AppHeader (не вынесен на уровень модуля), из-за чего он создаётся заново при каждом рендере — а AppHeader ре-рендерится довольно часто (при каждом изменении searchValue в поисковой строке, то есть на каждое нажатие клавиши). Объект используется только для чтения внутри renderOption, стабильность объекта не критична функционально, но это лишняя аллокация в хот-пути ввода текста.

- **Рекомендация:** Вынести TYPE_BADGE_CONFIG (и, по возможности, renderOption через useCallback) за пределы компонента на уровень модуля — он не зависит от props/состояния.

#### 🔵 Последовательная (не параллельная) загрузка sandbox-балансов в цикле for-await — `frontend/src/components/settings/BrokerAccountList.tsx:80`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** loadSandboxBalances делает for (const acc of sandboxAccounts) { await brokerApi.getSandboxBalance(acc.id) } — при N sandbox-аккаунтах запросы выполняются строго последовательно, а не параллельно. При 5+ подключённых sandbox-счетах (вполне вероятно при активной разработке/демо стратегии) экран будет показывать «—» для ещё не загруженных балансов заметно дольше, чем нужно, особенно при повышенной задержке до backend/T-Invest sandbox API.

- **Рекомендация:** Заменить последовательный цикл на Promise.allSettled(sandboxAccounts.map(acc => brokerApi.getSandboxBalance(acc.id).then(...))), обновляя стейт по мере получения каждого результата.

### Security-check (без находок)

Проверка безопасности не выявила уязвимостей: пользовательский/API-контент рендерится через Mantine `<Text>`/`<Code>` с автоэкранированием, `dangerouslySetInnerHTML`/`innerHTML`/`eval` не используются; API-ключ брокера и Telegram bot_token вводятся через `PasswordInput`, уходят в теле POST, не в localStorage/sessionStorage; `console.*` только в ErrorBoundary без секретов; `window.open` (BackgroundBacktestsBadge.tsx:111) — только same-origin путь, риска tabnabbing нет; редиректы строятся по backend-enum значениям. Вне scope: backend ownership-проверки для AI-команд, server-side enforcement скрытия admin-пункта Sidebar.


---

## 28. Frontend: утилиты и ядро приложения (utils, App, main, routes)

Проверены все production-файлы зоны: `frontend/src/utils/*.ts` (9 файлов), `App.tsx`, `main.tsx`, `routes/ProtectedAdminRoute.tsx`. Классических уязвимостей (XSS, небезопасный innerHTML/eval, утечки секретов, ReDoS) не обнаружено — `ProtectedAdminRoute.tsx` признан корректным (client-side gate, реальная защита на сервере). Основные проблемы — в категории «баги»: перезапись P&L при близких entry-таймстемпах на интрадей-графиках бэктеста, отсутствие переиспользования `parseBackendDate` в форматтерах дат (риск сдвига на 3 часа), несовпадение ссылок из уведомлений с реальными маршрутами приложения, хардкод символа рубля в `formatCurrency` и некритичная гонка при миграции localStorage между вкладками. Ревью проводилось в read-only режиме, без запуска приложения/тестов — выводы основаны на статическом анализе.

### 🟠 High

#### 🟠 computeChartZones перезаписывает pnl чужой сделки при близких entry-маркерах (±3600с), искажая цвет зоны на графике — `frontend/src/utils/tradeMarkerUtils.ts:108`

- **Категория:** баг  |  **Верификация:** ✅ подтверждено

- **Проблема:** В `computeChartZones` для каждой сделки `t` во внешнем цикле идёт вложенный проход по всем маркерам `sorted` с условием `Math.abs(m.time - ts) < 3600` без `break` — если entry-время другой сделки попадает в тот же часовой интервал (частый случай на интрадей-таймфреймах M5/M15/H1), `tradePnlByEntry.set(m.time, t.pnl)` перезаписывается результатом последней по порядку итерации сделки, а не сделки, реально начавшейся в `m.time`. Зона на графике окрашивается как «profit» для реально убыточной сделки или наоборот. Похожая логика в `enrichMarkersWithLots` корректна (есть `break` после первого совпадения), а в `computeChartZones` `break` отсутствует. Файл не покрыт unit-тестами. Верификация подтвердила на конкретном примере (сделки A и B с Δ=1000с<3600): оба ключа в итоге получают pnl последней по порядку сделки, а зона красится по `get(currentEntry)` — сценарий реален при хронологическом порядке trades на M5/M15/H1.

- **Рекомендация:** Убрать fallback-подбор по tolerance полностью (только точное совпадение timestamp) либо выбирать ближайшее совпадение и делать `break` вместо безусловной перезаписи по всем маркерам.

#### 🟠 formatDate/formatDateTime не нормализуют naive UTC datetime от backend — даты сделок/операций отображаются со сдвигом на 3 часа — `frontend/src/utils/formatters.ts:15`

- **Категория:** баг  |  **Верификация:** ⚠️ не опровергнуто (не проверено адверсариально)

- **Проблема:** `formatDate`/`formatDateTime` делают `new Date(date)` напрямую для строк, не пропуская через `parseBackendDate` из этого же каталога, который специально чинит проблему из W8f BUG-3/4: backend отдаёт naive datetime без Z-суффикса, JS трактует его как local time, что в Europe/Moscow даёт сдвиг +3ч. Проверка `backend/app/backtest/schemas.py` показала: `BacktestTrade.entry_date/exit_date` — обычный `datetime` без `iso_utc()` (только 3 из 76 файлов backend с datetime используют `iso_utc`). Сценарий: FastAPI сериализует `entry_date` без Z; `TradesTable.tsx`/`BacktestTrades.tsx` вызывают `formatDate(trade.entry_date)` — время сделки показывается на 3ч раньше фактического времени исполнения на MOEX.

- **Рекомендация:** Переиспользовать `parseBackendDate` внутри `formatDate`/`formatDateTime` вместо `new Date(date)`, либо обеспечить применение `iso_utc()` во всех backend-схемах с datetime.

### 🟡 Medium

#### 🟡 Ссылки из уведомлений на бэктест и инструмент ведут на несуществующие маршруты — `frontend/src/App.tsx:58`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `NotificationList.tsx`/`NotificationDrawer.tsx` формируют `getNotificationLink` для `type='backtest'` как `` `/backtest/${id}/results` ``, но в `App.tsx` зарегистрированы только `backtest/:id` и `backtests/:id`. Путь с суффиксом `/results` не матчится ни с одним `Route` и попадает на catch-all `*` → `NotFoundPage`. Аналогично `type='instrument'` даёт `` `/chart?ticker=${id}` `` (query string), а `ChartPage.tsx` читает тикер через `useParams` из path-сегмента `chart/:ticker?`, а не через `useSearchParams` — переход открывает `/chart` без выбранного тикера.

- **Рекомендация:** Исправить `getNotificationLink`: для backtest — `` `/backtests/${id}` ``; для instrument — `` `/chart/${id}` `` (path-параметр вместо query-string), либо расширить `ChartPage`.

#### 🟡 formatCurrency жёстко хардкодит знак рубля независимо от фактической валюты суммы — `frontend/src/utils/formatters.ts:1`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `formatCurrency(value)` всегда добавляет суффикс « ₽» без параметра валюты. В `components/account/OperationsTable.tsx` (строка 105) это даёт дублирование валюты: `{formatCurrency(payment)} {op.currency}` рендерит, например, «1 234,56 ₽ USD» для операции в долларах — противоречивая информация о валюте суммы.

- **Рекомендация:** Добавить в `formatCurrency` необязательный параметр `currency` (по умолчанию `'RUB'`) и подставлять соответствующий символ/код вместо жёстко закодированного ₽.

### 🔵 Low

#### 🔵 Миграция рисунков из ключа anon в localStorage не идемпотентна при параллельных вкладках — `frontend/src/utils/drawingsPersistence.ts:56`

- **Категория:** баг  |  **Верификация:** — не проверялось

- **Проблема:** `loadLocalDrawings` при первом обращении для `userId` копирует `anonItems` в новый ключ и удаляет `anonKey`. Если открыто несколько вкладок с одинаковым ticker/tf сразу после логина, между чтением `anonItems` и `removeItem(anonKey)` нет атомарности — вторая вкладка может прочитать `anonKey` до его удаления первой и тоже выполнить перенос — данные не теряются, но выполняется двойная запись.

- **Рекомендация:** Проверять наличие целевого ключа перед миграцией, чтобы не повторять перенос при второй вкладке. Не блокирует релиз.

---

**Вне зоны ревью (для сведения оркестратора):** JWT/refreshToken персистятся в localStorage через zustand persist и логируются (обрезанно) в `console.debug` в `stores/authStore.ts` — классический риск кражи через XSS, но файл не входит в заданный периметр. Также `drawingsPersistence.ts` мигрирует рисунки с ключа `anon` на `userId` при логине — возможная утечка данных между пользователями общего браузера, но не подпадает под заданные категории (XSS/токены/редиректы/CSRF/секреты).


> **Дополнение (добор упавшего измерения «Качество кода»).** Ниже — находки повторного ревью после сбоя измерения.

### 🟠 High

#### 🟠 `formatDate`/`formatDateTime` парсят дату в обход `parseBackendDate` (тот же класс багов, что закрыт ранее) — `frontend/src/utils/formatters.ts:16`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `formatDate`/`formatDateTime` парсят строку через `new Date(date)` напрямую, минуя `parseBackendDate` из `dateParsing.ts`, где в комментарии описано, что backend отдаёт naive UTC без TZ-суффикса (даёт сдвиг +3 ч для Москвы, известные BUG-3/4). Именно эти функции выводят даты пользователю и не защищены от того же бага. При невалидной строке `new Date()` даёт `Invalid Date`, и `toLocaleDateString/Time` тихо вернут «Invalid Date» в UI без обработки.

- **Рекомендация:** Использовать `parseBackendDate` вместо сырого `new Date(...)`; явно обрабатывать `null` (возвращать `'—'`) вместо протекания «Invalid Date».

#### 🟠 Тяжёлые страницы (Blockly, lightweight-charts) не загружаются лениво — `frontend/src/App.tsx:3`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Все ~15 страниц импортируются статически, без `React.lazy`/`Suspense`. `ChartPage`/`StrategyEditPage` тянут тяжёлые `lightweight-charts` и `blockly`, которые попадают в основной бандл и грузятся даже пользователям, открывающим только `/login` или `/account`.

- **Рекомендация:** Обернуть как минимум `ChartPage`, `StrategyEditPage`, `TradingPage`, `AdminLayout` в `React.lazy(() => import(...))` + один `<Suspense>` вокруг `<Routes>`.

#### 🟠 Дублирование guard-логики защищённых роутов — `frontend/src/App.tsx:27` и `frontend/src/routes/ProtectedAdminRoute.tsx:23`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `ProtectedRoute` и `ProtectedAdminRoute` независимо реализуют одинаковую проверку `isAuthenticated → <Navigate to="/login"/>` в разных файлах. При будущих изменениях (редирект с сохранением `from` и т.п.) легко поправить один guard и забыть второй.

- **Рекомендация:** Вынести проверку аутентификации в один компонент/хук (`useRequireAuth`) и построить `ProtectedAdminRoute` поверх него, добавляя только проверку `is_admin`.

### 🟡 Medium

#### 🟡 Дублирование защитной конвертации чисел (`toNum`) без общей утилиты — `frontend/src/utils/flatBlocksToWorkspace.ts:66`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `toNum()` — локальная функция безопасного парсинга «Decimal-как-строка из backend»; та же задача концептуально нужна в `blocksToTemplate.ts` (там `getFieldValue` используется напрямую без защиты). Логика «backend отдаёт Decimal строкой» размазана по модулю.

- **Рекомендация:** Вынести `toNum` в общий модуль (`utils/numberParsing.ts` или `formatters.ts`), задокументировать контракт один раз.

#### 🟡 Магические числа допуска по времени (`3600`) захардкожены в нескольких местах — `frontend/src/utils/tradeMarkerUtils.ts:39`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Толеранс сопоставления маркеров и сделок (±3600 секунд) продублирован магическим числом в `enrichMarkersWithLots` и `computeChartZones` без общей константы и объяснения выбора часа.

- **Рекомендация:** Вынести в именованную константу (`MATCH_TOLERANCE_SEC = 3600`) с комментарием об источнике допуска.

#### 🟡 `main.tsx` не защищает верхнеуровневый рендер (нет проверки `root`, нет boundary до провайдеров) — `frontend/src/main.tsx:19`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** `ErrorBoundary` есть только внутри `App.tsx`. В `main.tsx` — non-null assertion `getElementById('root')!` без проверки и без защиты от ошибок инициализации `MantineProvider`/`BrowserRouter`. Если провайдер упадёт при инициализации до внутреннего boundary — белый экран без диагностики.

- **Рекомендация:** Добавить явную проверку `root` на `null` с понятным сообщением (fail fast с логом).

#### 🟡 Дублирование паттерна «safe localStorage read/write» без общей обёртки — `frontend/src/utils/recentInstruments.ts:12`, `frontend/src/utils/drawingsPersistence.ts:27`

- **Категория:** качество кода  |  **Верификация:** — не проверялось

- **Проблема:** Оба модуля с нуля реализуют try/catch вокруг `localStorage` + `JSON.parse` с проверкой формата и тихим поглощением ошибок. Общей типобезопасной обёртки нет — при появлении третьего места логика снова будет скопирована.

- **Рекомендация:** Выделить типизированную утилиту безопасной работы с `localStorage` (get/set + JSON + версионирование), использовать в обоих модулях.


---
