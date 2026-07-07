# Лог P1 — Волна 2 (backend: auth / broker / notification / ai / runtime / misc)

**Дата:** 2026-07-06 … 2026-07-07
**Ветка:** `s8r/bug-31-unified-codegen` (Develop/, → origin `moex-terminal`). База волны — `a936e1a` (итог Волны 1).
**Модель фиксов:** Opus 4.8 (DEV-агенты), оркестрация — Fable 5. Строго test-first (Red→Green→Refactor).
**Метод:** 6 DEV-агентов в изолированных git-worktree'ах (base = `a936e1a`) → integration-мерж + полный gate + `/code-review` (xhigh, 10 углов + верификация) по broker/circuit_breaker/критпутям + отдельный test-first раунд фиксов найденных дефектов + повторный gate.

## Реализовано (13 High)

| Ветка | Пункты | Тесты (в worktree) |
|---|---|---|
| `fix/be-auth-session` | BE-AUTH-02 (CSRF exempt /auth/refresh), BE-AUTH-03 (ротация refresh + отзыв jti + user-state проверки), doc/docker-часть CFG-BE-02 | 126 passed + 40 регресс |
| `fix/be-broker` | BE-BROK-01 (маршрутизация (figi, interval)), BE-BROK-02 крипто (валидация master_key + явная соль) | 325 passed |
| `fix/be-notification` | BE-NOTIF-02 (транзакционные границы SQLite), BE-NOTIF-03 (UniqueConstraint + alembic-миграция `c9f1a2b3d4e5`) | 113 passed |
| `fix/be-ai` | BE-AI-01 (SSRF url_validator), BE-AI-02 (ContextCompressor role-order) | 172 passed |
| `fix/be-runtime` | BE-RT-01 (lot_size в CB, fail-closed), BE-RT-02 (timeout sandbox), BE-RT-03 (валидация trading_hours) | 125 passed + 343 регресс |
| `fix/be-misc` | BE-MISC-17 (admin отзыв токена), BE-MISC-18 (границы года МСК), BE-MISC-19 (раздельная налоговая база) | 118 passed |

**Дубли P0 (не делались):** CFG-BE-02 core = C3, BE-BROK-02 config-часть = C3, AUTHZ-05 = C1.

## Интеграционные фиксы при мерже (совместимость волны)

- **CryptoService strict-режим:** живой `.env` содержит 31-байтовый `ENCRYPTION_KEY` (им зашифрованы существующие broker-токены). Жёсткий `raise` ломал бы dev-окружение → добавлен параметр `strict` (prod fail-fast, dev warning); `crypto_helpers` → `strict=not settings.DEBUG`.
- **BE-NOTIF-02 async-контракт доставки:** тесты `test_dispatch_all_events` переведены на `wait_for_pending_dispatch` + `scalars().first()`.
- **test_config:** изоляция от env `DEBUG` (детерминизм гейта).
- **shield при отмене listener'а:** отмена посреди транзакции `create_notification` рвала сессию (MissingGreenlet под StaticPool, флейк полного прогона) → `_create_notification_shielded` + `wait_for_pending_dispatch` в teardown тестов runtime_events.

## `/code-review` (xhigh, 10 углов + фаза верификации)

10 finder-углов (5 корректностных A–E + reuse/simplification/efficiency/altitude/conventions) → ~24 уникальных кандидата → 14 верификаторов (CONFIRMED/PLAUSIBLE/REFUTED с цитатами кода). **Ревью нашло 8 реальных дефектов в свежих фиксах Волны 2** (как и в Волне 1). Исправлены отдельным test-first проходом (коммиты `1e84ae5`, `b80b998`, `ee98302`, `b5ddb76`):

### CB (BE-RT-01) — `1e84ae5`, 3 дефекта
- **fixed_sum обходил лимит:** CB сверял сырую сумму, но движок берёт `max(1, int(value/cost_per_lot))` лотов — при `value < cost_per_lot` это 1 полный лот стоимостью `cost_per_lot` ₽ > заявленной суммы. Пример: `fixed_sum=5000₽`, лот=30000₽ → ордер 30000₽ проходил лимит 10000₽ (×3). Все три режима переведены на расчёт через `cost_per_lot`.
- **fail-closed давал перманентную паузу:** при недоступном lot_size блок был НЕ-`temporary` → `_trigger` паузил сессию + force-close всех позиций от транзиентного сбоя сети. Теперь `temporary=True` (пропуск сигнала, сессия active).
- **сеть под per-user Lock без таймаута:** T-Invest gRPC find_instrument (без дедлайна) резолвился под `check_before_order`-локом → зависание блокировало все сессии пользователя. Добавлен `asyncio.wait_for` (`LOT_SIZE_RESOLVE_TIMEOUT_SEC=8с`).

### AI (BE-AI-01) — `b80b998`, 3 дефекта
- **блокирующий event loop:** `socket.getaddrinfo` резолвился синхронно в Pydantic-валидаторе и в `ProviderFactory.create` на каждое сообщение чата → висящий DNS замораживал весь backend (торговый цикл, стримы). Валидатор разделён: синтаксис (sync, без DNS) в схемах + DNS в тред-пуле (`create_async`, `anyio.to_thread`). Убран двойной резолв на settings-запрос. Денилист локальных хостнеймов (localhost/*.local/metadata) ловит их по имени без DNS.
- **обход SSRF редиректом:** openai/anthropic SDK строили httpx-клиент с `follow_redirects=True` — публичный хост мог ответить `30x Location` на `169.254.169.254`. Клиенты → `follow_redirects=False`.
- **Ollama-провайдеры из БД → 500:** `InvalidProviderURLError` (подкласс ValueError) не ловился в chat_router. Глобальный хэндлер → 422 с текстом-подсказкой про флаг.

### auth (BE-AUTH-03) — `ee98302`, 1 дефект
- **неатомарная reuse-detection:** отдельный SELECT + SELECT-then-INSERT с await'ами между ними → два конкурентных `/refresh` с одним токеном давали `IntegrityError→500` или оба получали свежие пары (обход reuse). `_revoke_jti` → атомарный `INSERT ... ON CONFLICT(jti) DO NOTHING` с возвратом факта вставки; `inserted=False` → «Token отозван».

### notification (BE-NOTIF-02) — `fa8d887`, 2 дефекта
- **потеря уведомлений при shutdown:** `wait_for_pending_dispatch` был построен, но не подключён к lifespan → уведомления «система остановлена»/critical, ушедшие в fire-and-forget задачу, уничтожались при закрытии loop. Подключено в `main.py` lifespan (timeout=15с) после `session_runtime.shutdown()`.
- **shield-сирота при двойной отмене:** незащищённый `await handler` в ветке `except CancelledError` → повторная отмена осиротеляла handler посреди транзакции. Handler регистрируется в реестре фоновых задач (strong ref + done-callback), дожидается в `wait_for_pending_dispatch`.

### broker / мультиплексор (BE-BROK-01) — `9cd44aa`, 5 дефектов (до-верификация критпути)

Мультиплексор `/code-review` не успел довести (верификаторы упёрлись в лимит субагентов) — до-верифицирован отдельно. Все 5 кандидатов угла E подтверждены, исправлены test-first:
- **K1 двойной SUBSCRIBE при reconnect:** `_resubscribe_all` клал SUBSCRIBE в очередь, а начальный цикл нового `_request_iterator` подписывал те же пары повторно → 2×N `SubscribeCandlesRequest` на reconnect (риск 429/RESOURCE_EXHAUSTED при reconnect-шторме, профиль Gotcha 4). → `_drain_command_queue` (только дренаж; переподписку делает initial-loop итератора).
- **K2 reconnect без backoff при graceful close:** `StopAsyncIteration → break` уводил во внешний while без `_sleep` и без сброса `_connected` — плотный цикл connect→subscribe→close при штатном закрытии сервером. → тот же backoff, что на error-пути.
- **K3 «отравленная пара»:** `subscribe()` принимал любой int; невалидный interval уронил бы `SubscriptionInterval(...)` в `_request_iterator` → вечный crash-reconnect всего стрима. → валидация interval (1..13) на входе.
- **K4 interval-less broadcast (self-inflicted BE-BROK-01):** fallback при candle без interval рассылал свечу ВСЕМ interval-подписчикам figi — реинтродукция cross-interval утечки. → свеча дропается с warning.
- **K5 воскрешение остановленного mux:** адаптер кэшировал ссылку и не проверял `is_stopped` → `subscribe()` воскрешал остановленный mux вне singleton-реестра (ghost-стрим / 2 стрима на токен). → property `is_stopped` + re-check в `_ensure_multiplexer`.

**Новая Stack Gotcha (для ARCH):** `TIMEFRAME_MAP` хранит значения `CandleInterval`, но для всех 13 таймфреймов они численно СОВПАДАЮТ с `SubscriptionInterval` (расходятся только секундные 14-16, которых в карте нет) — маршрутизация корректна, но это совпадение value-space двух разных enum, не тождество. Комментарий в `_dispatch_candle` («тот же enum») формально неточен.

## Верификация (объединённый результат)

- **pytest** (весь backend): **2129 passed, 2 xfailed, 0 failed** (было 2114 @ мерж — +15 review-тестов: 10 по CB/AI/auth/notification + 5 по мультиплексору).
- **pyright** по всем изменённым prod-файлам: **0 новых ошибок** (50 предсуществующих — openpyxl None-cell в tax, RestrictedPython-dict в sandbox, типизация SDK-сообщений в claude/openai провайдерах; счётчики идентичны baseline @ `a936e1a`).

## Осталось / заведено в backlog

**REFUTED ревью (не дефекты — зафиксировано):**
- CB блокировка ВЫХОДА из позиции — REFUTED: в production runtime exit-bypass (W8b) срабатывает до CB; остаётся узкий edge со встречным сигналом против только-`pending` позиции.

**NEEDS-REVIEW / backlog (крупное или вне скоупа backend-волны):**
- **P1W2-SSRF-PINNING** — полный anti-DNS-rebinding через кастомный httpx transport с IP-pinning (K2 из ревью). `follow_redirects=False` закрыл redirect-вектор (K1); rebinding TOCTOU остаётся (валидатор и httpx резолвят независимо). Средне-крупная задача (кастомный transport + тесты).
- **P1W2-REFRESH-GRACE (Волна 3, фронт+бэк)** — ротация refresh без grace-окна + два независимых refresh-клиента фронта (`client.ts` + `aiStreamClient`) + отсутствие cross-tab sync → принудительный разлогин при двух вкладках/активном AI-чате (~каждые 30 мин). Атомарность отзыва (бэк) уже сделана; нужен grace-период на бэке + общий single-flight и storage-listener на фронте.
- **P1W2-AI-LOCAL-PROVIDER-UPGRADE** — существующие локальные AI-провайдеры (Ollama `http://localhost:11434`) из БД ломаются после апгрейда при дефолтном `AI_ALLOW_PRIVATE_PROVIDER_URLS=false` (теперь 422 с подсказкой вместо 500). Нужна data-migration/уведомление или флаг в setup.
- ~~**P1W2-MULTIPLEXER-RECONNECT**~~ — ✅ **закрыто** (до-верифицировано + исправлено, коммит `9cd44aa`, см. раздел «broker / мультиплексор» выше). Остаётся отдельный **P1W2-MULTIPLEXER-STOPPED-CANDLE-RACE** (низкий приоритет): доставка in-flight свечи после `unsubscribe` во время `await callback` — snapshot listeners не видит завершившийся конкурентный unsubscribe (кандидат угла E, не критичный).
- **P1W2-SANDBOX-EPHEMERAL-PROC** — жёсткий лимит памяти (`setrlimit`) + отдельная rate-limit категория для `/sandbox` (BE-RT-02 опциональная часть). Крупный рефактор, ~1–2 дня.
- **P1W2-BE-MISC-19-TAX-CATEGORIES** — раздельная налоговая база по share/bond/etf реализована по спеке, но по ст. 214.1 НК обращающиеся на MOEX бумаги всех трёх типов в общем случае входят в ОДНУ сальдируемую базу; правильная граница — «обращающиеся vs необращающиеся/ПФИ». Требует решения заказчика.

**Cleanup-техдолг (из reuse/simplification углов, низкий приоритет):**
- Три копии inline-запроса отзыва jti (middleware/auth, auth/service, admin/dash_mount) → общий `is_jti_revoked`.
- Четвёртая копия `MOSCOW_TZ` в tax/service.py (уже в scheduler/market_data/strategy + `MSK_OFFSET` в common/trading_hours).
- Общий sizing-хелпер для CB и trading/engine (формула лотов дублируется).
- Мёртвый параметр `db` в `create_notification` + sentinel-дефолты; мёртвая константа `MAX_MEMORY` в sandbox.
- Единый парсер HH:MM + дефолты торговых часов (engine / schemas / common.trading_hours).

**Осталось по P1:** Волна 3 (frontend: fe-security, fe-network, fe-charts, fe-backtest-ui, fe-core-refactor, fe-ui-misc).
