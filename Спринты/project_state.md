# Состояние проекта: Торговый терминал MOEX

> **Это главная точка входа для любой новой сессии Claude.**
> Прочитай этот файл первым, чтобы понять, где мы находимся.
>
> Последнее обновление: 2026-08-04 (**S8R, хвост комиссии и налоговый модуль: налоговая база больше не занижается в lot_size раз, комиссия появилась во всех трёх режимах, красный nightly вскрыл дефект rate-limiter под Model A**. Гейты: pytest 2406, vitest 855, E2E 169/3/0. Новая ловушка — gotcha-54. ФТ → v3.3, ТЗ → v2.3.)
>
> **2026-08-04 — S8R: хвост комиссии, налоговый модуль и стабильность E2E** (одиночная сессия, ветка `s8r/tax-and-commission-tail` от `develop` `cff1eb7`).
> **Красный nightly оказался дефектом продукта, а не теста.** Сюита `P1 Auth-hardening` падала на «WS не отдал кадр», но лог backend'а показал `GET /auth/me → 429` и `WebSocket /ws/trading-sessions/undefined → 403`: тест не проверял статус и брал `id` из тела ошибки. Причина 429 — `RateLimitMiddleware._get_key` искал JWT только в заголовке `Authorization`, которого после перехода на Model A нет ни у одного браузерного запроса: ключ деградировал до IP, и лимит 200 req/min стал общим на всех пользователей (за обратным прокси выбирался бы ещё быстрее). Дефект дожил до этого дня потому, что nightly впервые пошёл на живом backend'е.
> **Налоговый модуль занижал базу в lot_size раз (`S8R-TAX-PNL-LOSES-LOT-SIZE`).** Результат сделки считался по лотам, а не по штукам. Критерий приёмки — сходимость с движком, а не «формула поправлена»: тест гоняет ту же сделку через `RiskMonitor._apply_close` и сверяет. На инструменте с лотом 10: `TaxLot.realized_pnl` **487,25 ₽** против `pnl − commission` = **487,25 ₽**, расхождение 0,00 ₽ (до фикса — 37,25 ₽). Попутно найдено расхождение половинок комиссии: `round(total/2)` на 12,75 ₽ давал 12,76 ₽ в колонках отчёта. **Отчёты, сформированные раньше, требуют перегенерации** — записано в `deployment_guide` §7.
> **Комиссия sandbox/real (`Q2=a`, фактическая).** Источник — `OrderState.executed_commission` из того же `GetOrderState`, которым движок уже уточняет цену исполнения: комиссия там привязана к ордеру, и разбор `GetOperations` с сопоставлением операций не нужен (решение принято исполнителем, постановка предполагала `GetOperations`). Когда факта нет (в песочнице комиссия не удерживается) — оценка по тарифу счёта с пометкой `commission_source='estimated'`, в интерфейсе знак ≈. Сверка sandbox против paper на одних данных: комиссия **12,75 ₽** и «чистый P&L» **487,25 ₽** в обоих режимах. Денежный учёт sandbox/real не тронут — баланс ведёт брокер.
> **Тариф брокерского счёта (`Q5=a`)** — `broker_accounts.commission_pct`, поле в «Настройки → Брокер». Paper наследует его при запуске, если ставка не задана; sandbox/real считают по нему оценку.
> **Интерфейс (`Q6=a`):** пометка источника в журнале сделок, карточка «Комиссия за период» в статистике. **3-НДФЛ (`Q3=b`):** колонка «Режим» и примечание про виртуальные деньги песочницы.
> **Флейк E2E закрыт (`Q4=a`)** — тест проверял флаг сразу после `click()`, тогда как запрос уходит позже; на CI это маскировали `retries: 2`. Критерий приёмки выполнен: **40 passed за 10 прогонов подряд** (`--repeat-each=10 --retries=0`).
> **Код-ревью (5 независимых ревьюеров) нашло 6 реальных дефектов в свежих правках — все исправлены.** Комиссия входа терялась на основном пути песочницы (`PLACED → опрос статуса`) и при восстановлении зависшей сделки; комиссия выхода — при закрытии по SL/TP в sandbox/real; paper-сделки оставались без источника; оценка выхода завышалась при частичном исполнении входа; ноль от **реального** брокера подменялся оценкой. Одна находка отклонена как предсуществующая и заведена карточкой.
> **Новая находка high, не чинилась:** `S8R-SLTP-SANDBOX-NO-BROKER-ORDER` — `RiskMonitor` закрывает позицию только в учёте терминала, ордер брокеру не отправляет **ни в одном режиме**; в sandbox/real позиция после стопа остаётся открытой у брокера. Плюс `S8R-CLOSE-POSITION-NO-LOCK` (medium) и две low.
> Гейты: pytest **2406 passed / 1 xfailed / 0 failed**, vitest **855 / 124 файла**, tsc 0, eslint 0, ruff 0, mypy Success (177 файлов), bandit 0, E2E **169 passed / 3 skipped / 0 failed** одним прогоном. Stack Gotchas 53 → **54** (gotcha-54: `info/exclude` в worktree пишется в общий gitdir), `INDEX.md` version 19. ФТ **v3.2 → v3.3**, ТЗ **v2.2 → v2.3**.

> **2026-07-30 — Хвост Sprint_8_Review (одиночная сессия, ветка `s8r/tail-fixes` от `develop` `81ef068`; НЕ закоммичена).**
> **Блок A — все пять карточек закрыты test-first.** `S8R-DEPLOYMENT-GUIDE-MIGRATION-SYNC` (гайд §3.3/§7 догнал миграцию `d1e2f3a4b5c6`), `S8R-WS-CLEANUP-TIMEOUT-SILENT` (ImportError → 3 passed), `S8R-SANDBOX-ACCOUNT-ID-COLLISION` (3 failed → 31 passed; попутно закрыт смежный дефект — живой, но не первый активный счёт **молча подменялся соседним**), `S8R-BROKER-FACTORY-BYPASS` = `BE-BROK-13` (4 failed → 184 passed), `S8R-RECONCILE-DAILYSTAT-EVENT` (2 failed → 7 passed, использован существующий `trade.closed` — новый `event_type` не заводился).
> **Побочная находка A4 — тесты ходили в реальный T-Invest.** Патч класса `TInvestAdapter` перестал действовать после перевода на `BrokerFactory` (реестр держит ссылку, захваченную при импорте), и вскрылось, что `test_broker` шёл 101 с с `UNAUTHENTICATED 40003` от живого API. После переноса патча на фабрику — те же 184 теста за **2,3 с**, без сети.
> **Код-ревью блока A (5 ревьюеров) нашло 2 дефекта в свежих правках — оба конкурентные, оба исправлены.** (1) Реконсиляция задваивала `DailyStat` и слала два `trade.closed` на одну сделку: один sandbox-счёт обслуживает несколько сессий, у каждой свой `AsyncSession`; пока закрытие было идемпотентной перезаписью полей, гонка была безобидна, а добавленные `_update_daily_stat`+`publish` — нет (на первой за день сделке ещё и `IntegrityError` на `uq_daily_stat`). (2) Два `BrokerAccount` одного токена получали один `account_id`: проверка «занят ли счёт» — обычный SELECT, то есть TOCTOU. Обе гонки воспроизведены детерминированно и закрыты сериализацией через новый `app/common/locks.py::keyed_lock` (приём Circuit Breaker, gotcha-05).
> **Метрики стали живыми (решение заказчика, вне блоков A/B/C).** Вскрылось, что метрики существовали только на бумаге: `/admin/metrics` рисовал **зашитые в код mock-массивы**, `@timed_event` писал в structlog на уровне DEBUG и никуда не агрегировал, декоратора `trading.signal_to_order` из ТЗ §4 **не существовало**, `PerformanceObserver` не был реализован нигде. Реализовано: кольцевой буфер `app/common/metrics_store.py`, запись из `@timed_event`, недостающий декоратор на `OrderManager.process_signal`, callable-layout Dash (иначе страница застыла бы на состоянии при импорте), клиентский LCP → `POST /api/v1/observability/lcp`. Проверено вживую: отправленные замеры попали в график, пустые метрики честно подписаны «нет замеров».
> **B1 — измеренный потолок.** `signal.process` ≤ 5,6 мс p95 на любой нагрузке; `trading.signal_to_order` p95: 1 сессия — 21 мс, 5 — 33 мс, 20 — **172 мс**, 40 — **828 мс**. **Цель ТЗ < 500 мс держится до ~20 одновременных сессий и нарушается при 40** (в 1,7×). Узкое место — не стратегия, а обвязка ордера (последовательные записи в SQLite). Решение о поднятии потолка — за заказчиком.
> **B3 — развёртывание с нуля.** Docker CLI в окружении отсутствует, docker-часть не выполнялась (имитировать не стал). Нативно пройдена цепочка, которую чинила миграция: чистая БД → `upgrade head` → `current` = `d1e2f3a4b5c6` → сверка `Base.metadata` (30 таблиц, 0 недостающих) → `setup` **201** → `login` **200** при `DEBUG=false`.
> **B4 — три расхождения гайда с кодом, все исправлены.** Закрытие позиций best-effort (гайд подавал как гарантию) — добавлен обязательный шаг проверки; скрипт из гайда **не запускался** (`AsyncSessionLocal is None` вне lifespan) — проверено исполнением и исправлено; альтернативная реконсиляция забывала `peak_equity`, по которому CB считает drawdown — завышенное значение поставило бы сессии на паузу без причины.
> **B2 НЕ ВЫПОЛНЕН.** Стенды заказчика (:8100, :8110) на момент старта сессии уже были погашены (агент их не трогал). Нужны пароль пользователя и T-Invest/Telegram из `.env` — ожидает заказчика.
> **Блок C.** Worktree `s8r-sandbox` и `s8r-develop-merge` удалены после самостоятельной сверки с `origin/develop`; `.git/info/exclude` вычищен. Ветка `s8r/merge-to-develop` **не удалена** — команда заблокирована permission-правилом; безопасность проверена (её единственный коммит вне `develop` — merge, чьё разрешение конфликта побайтово совпадает с `origin/develop`).
> Гейты хвоста: pytest **2276 / 1 xfailed / 0 failed**, vitest **842 / 122 файла**, tsc 0, eslint 0, ruff 0, mypy Success (174 файла), bandit 0 medium+, E2E **162 / 3 skipped / 0 failed** одним прогоном. Stack Gotchas 49 → **50** (gotcha-50: скрипт вне worktree молча меряет код основного чекаута через editable-install), `INDEX.md` version 15. ТЗ **v1.8 → v1.9**.
>
> **2026-07-29 — S8R финальное сведение (пятая волна).**
> **Мержи.** **PR #10 смёржен** merge-commit'ом в `s8r/bug-31-unified-codegen` (`cc04ef5`); дерево `bug-31` после мержа побайтово равно дереву `backlog-fixes`. Сверка по remote-рефам вскрыла, что **`p1/wave2-backend` уже полностью содержится** в S8R-ветке (прямой предок), как и `p1/wave3-frontend`, `p1/auth-hardening`, `s8r/acceptance-fixes-2026-07-26` — сводить их не требовалось; локальный ref `s8r/bug-31` был протухшим (behind 92), из-за чего счётчики коммитов в постановке цикла расходились с фактом. Единственный конфликт при сведении в `develop` — `frontend/e2e/s5-paper-trading.spec.ts`: обе стороны **независимо сделали один и тот же** фикс flaky-теста (та же `currentStatus`, та же `sessionPayload()`), S8R дополнительно снял 6 `networkidle`; разрешение — версия S8R + развёрнутый комментарий из PR #6.
> **`S8R-SANDBOX-ACCOUNT-STALE-REOPEN` (medium) закрыт** по решению заказчика (вариант «автодетект + кнопка в UI»; в живой сессии — обновить счёт и продолжить торговать). Новый модуль `app/broker/sandbox_recovery.py` (вынесен отдельно: потребители — и `broker/service.py`, и `trading/engine.py`, обратный импорт замкнул бы цикл); три точки подключения строго под `is_sandbox`; ручной endpoint `POST /broker-accounts/{id}/reopen-sandbox` + кнопка на `/settings?tab=broker`. **Ключевая добавка к выбранному варианту:** при подмене счёта сессия реконсилирует позиции — старый счёт удалён брокером вместе с позициями, и без этого SL/TP закрывали бы несуществующие позиции, а CB мерил бы просадку по мёртвым данным. +23 теста.
> **Флейк `test_order_passes_when_no_violations` (low) закрыт — причина воспроизведена детерминированно.** `process_signal` → `ensure_lot_size_strict` → при пустом кэше инструментов **реальный сетевой запрос** в T-Invest/MOEX ISS; при подтормаживании ISS строгий резолв бросает `LotSizeUnavailableError`, CB блокирует сигнал fail-closed, `process_signal` возвращает `None`. RED: `MOEX_ISS_BASE_URL=http://127.0.0.1:9 pytest … → 1 failed`, в обычных условиях — passed. Тот же класс, что закрытый `test_max_positions_limit`. GREEN: `autouse`-фикстура патчит lot_size (приём уже применён в соседнем `test_engine.py`) — 4 passed в условиях сбоя, 65 passed по директории, файл ускорился с ~3 с до 0.23 с.
> **E2E — 162 passed / 3 skipped / 0 failed** из 165 (паритет с baseline 163/3: разница — один `auth-hardening`-тест, проходящий на моках). Два ложных вывода стоили двух лишних прогонов: (а) «набор завис» — виснет **выход** Playwright уже после последнего пройденного теста (0% CPU, браузеров нет, сводки нет) → **[gotcha-49](../Develop/stack_gotchas/gotcha-49-playwright-hangs-after-last-test.md)**, Stack Gotchas 48 → **49**; (б) «регресс в `s7-export`» — 2 падения появлялись только когда параллельно шёл backend-pytest, чистый прогон дал 0. Урок: не гонять тяжёлое параллельно с E2E.
> Гейты пятой волны: pytest **2246 passed / 1 xfailed / 0 failed**, vitest **835 / 121 файл**, tsc 0, eslint 0, ruff 0, mypy Success (171 файл), bandit 0 issues.
>
> **2026-07-28/29 — closeout S8R: PR #10 полностью зелёный, backend job в CI снова работает** — тесты не выполнялись ~3 недели; E2E-набор пошёл одним прогоном. Первый реальный прогон CI вскрыл и закрыл три дефекта, включая гонку в WS-хендлере, вешавшую весь набор. Плюс закрыт `S8R-ALEMBIC-FRESH-DB-DRIFT` — чистая установка отдавала 500 на входе. ТЗ → v1.8.
>
> **2026-07-28 — S8R closeout (четвёртая волна).** Закрыт остаток раздела «⬜ ОТКРЫТО» из `Sprint_8_Review/backlog.md`.
> **CI (high).** Гипотеза подтверждена по логу до правки: `pytest` падал на **импорте** `tests/conftest.py` → `app.main` → `settings = Settings()`, а не на тестах. В `.github/workflows/ci.yml` job `backend` получил `env` с не-дефолтными фиктивными `SECRET_KEY`/`ENCRYPTION_KEY` при `DEBUG=false` — **выбран вариант, сохраняющий production-гейт секретов** (`DEBUG=true` отвергнут: глушит гейт и уводит тесты с прод-путей — strict-режим `CryptoService`, `Secure`-cookie). ⚠️ Первоначальная оценка «паритет 2222 passed» была получена прогоном, где перебивались только ключи, а `DEBUG` молча брался из `.env` (=true) — то есть `DEBUG=False` не проверялся. Честная проверка (`DEBUG=false` + без `.env`) вскрыла 5 падений; после их разбора — **2223 passed / 1 xfailed / 0 failed**, см. запись про первый прогон CI ниже.
> **E2E (medium).** `waitForLoadState('networkidle')` убран из всех спек — 20 файлов, 34 вхождения; где следом идёт `expect(...).toBeVisible()`/`click()` — просто удалён, где шла кастомная логика — заменён на ожидание конкретного маркера. **Набор впервые прошёл одним прогоном: 163 passed / 3 skipped, 9.6 мин, без зависаний** (было: только пофайлово, 158 passed / 4 failed).
> **4 падавших теста `s5-account.spec.ts` (low) — дефект теста, не продукта.** Фикс `S8R-ACCEPTANCE-FIX-BUG-4` добавил в `AccountPage` загрузку `GET /tax/reports` при монтировании, мок не завели → 401 → `accountStore.error` подменял страницу алертом. Добавлен `mockTaxReports()`: **4 failed → 4 passed**.
> **`auth-hardening.spec.ts` (low).** Спека параметризована (`PW_ORIGIN`), прогнана на выделенном стенде `:8120`/`:5193` без остановки стенда заказчика — **7 passed / 0 failed за 5.0 с**. Попутно: дефолтный `LOGIN_RATE_LIMIT_PER_MINUTE=5` меньше числа логинов в спеке (нужен ≥ 10), а без `wizard_completed_at` у тест-пользователя модалка мастера съедает все клики — [gotcha-47](../Develop/stack_gotchas/gotcha-47-modal-blocks-clicks-retry-until-global-timeout.md), Stack Gotchas 46 → **47**.
> **`.env.example`** дополнен четырьмя `BACKTEST_DATA_TIMEOUT_*` с русскими комментариями.
> **`S8R-ALEMBIC-FRESH-DB-DRIFT` (high) — найден и закрыт в тот же день.** На **чистой** БД после `alembic upgrade head` отсутствовали таблица `user_ai_settings` и 8 колонок (`strategies.description`, `instruments.logo_name`, 6 в `ai_provider_configs`) → `POST /auth/login` отдавал 500, то есть развёртывание по `deployment_guide.md` давало неработающий вход. Существующие стенды не затронуты (их БД «доросли» раньше) — поэтому дефект и не всплывал. Класс — [gotcha-13](../Develop/stack_gotchas/gotcha-13-forward-model-drift.md). По отдельной команде заказчика объём цикла расширен и дефект закрыт TDD: RED — новый `test_fresh_db_schema_matches_models` (сверяет всю `Base.metadata` с фактической схемой чистой БД; прежний `test_all_tables_exist` смотрел только список таблиц), GREEN — идемпотентная миграция `d1e2f3a4b5c6`. Проверено сквозняком: на чистой БД `setup` **201**, `login` **200**; на копии рабочей БД миграция проходит без дублей.
> **Первый за три недели реальный прогон backend-job в CI вскрыл три дефекта, невидимых локально.** (а) `test_auth_cookie_secure` — 3 теста держались на `DEBUG=true` из `.env` разработчика: при `DEBUG=False` cookie уходят с `Secure`, httpx их по http не переотправляет → 403. (б) `test_backup_cli` — 2 теста: подпроцесс стартует со стерильным окружением и держался на наличии `.env`. (в) **зависание всего прогона** — job горел до 6-часового лимита runner'а, не назвав ни одного теста. Диагностику дали добавленные в `ci.yml` `timeout-minutes: 40`, `PYTHONUNBUFFERED=1` и `faulthandler_timeout=120`: сторож указал на `test_ws_sessions.py::test_auth_via_cookie`. Диагноз занял три итерации — первые две (`cancel()` без `await` в `ws_sessions.py`; уехавшая версия `anyio` 4.13→4.14.2) зависание не снимали, обе правки оставлены как полезные сами по себе. **Настоящая причина — кросс-loop доступ к aiosqlite:** async-фикстуры идут в loop pytest-asyncio, `TestClient` — в своём loop портала, а `:memory:` + `StaticPool` давали им одно соединение, чей `Future` привязан к loop создателя. Фикс — файловая БД в `tmp_path` + `NullPool`. Stack Gotchas 47 → **48** ([gotcha-48](../Develop/stack_gotchas/gotcha-48-cancelled-tasks-not-awaited-hang-testclient.md)). **PR #10 полностью зелёный: backend 2223 passed / 1 xfailed / 0 failed за 5 мин 45 с, frontend и security-scan pass.** Уроки: сломанный гейт не просто не ловит новые дефекты — он копит старые; а при «локально зелено, в CI красно» первым вопросом должен быть «что отличается на раннере?», а не «что не так в коде?».
> Гейты closeout: pytest **2223 / 1 xfailed / 0 failed** — и локально (в конфигурации CI-шага: `DEBUG=false`, без `.env`, с coverage), и **в самом CI**, vitest **832 / 120 файлов**, tsc 0, eslint 0, ruff 0, mypy 0, bandit 0 medium+. ТЗ §9 дополнено контрактом окружения CI, запретом `networkidle` в спеках и требованиями к стенду `auth-hardening` (ТЗ **v1.7 → v1.8**). ФТ не менялись — пользовательское поведение не затронуто.
>
> **2026-07-27 — Дозакрытие S8.8 и актуализация документации.** Заказчик проверил глазами единственный оставшийся пункт чеклиста (S8.8 «Изменение формы») и **завернул** его: «при попытке переместить точку линии она исчезает с графика». Разбор (systematic-debugging + Playwright с временной инструментацией) дал **два дефекта**: **BUG-33** (HIGH — `series.attachPrimitive()` не запрашивает перерисовку, `renderer.draw()` не вызывался ни разу после загрузки: фигура была и в store, и в БД, но холст пустой; появлялась только после движения мыши/pan/нового бара — то же делало фигуры «пропавшими» после F5 и re-attach) и **BUG-34** (MEDIUM — drag стартовал только для **уже выделенной** фигуры, иначе захват проваливался в lightweight-charts и вместо перемещения точки начиналось панорамирование: фигура уезжала вместе со свечами). Фиксы test-first: `param.requestUpdate()` в `attached()`; выбор фигуры под курсором вынесен в общую `pickTopHit()` (click/hover/меню/drag), `onPointerDown` выделяет фигуру и пере-опрашивает hit-тест ради нужного handle. **Гейт: vitest 772 passed (111 файлов), tsc 0, eslint 0.** Верифицировано на стенде: линия видна сразу после F5 без движения мыши, конец линии и угол прямоугольника тянутся с первого захвата, панорамирование по пустому месту не сломано. Пункт S8.8 переведён `[-]` → `[x]` — **непокрытых пунктов чеклиста не осталось**. Ловушка занесена в `Develop/stack_gotchas/gotcha-36-attachprimitive-no-redraw.md`. **PR #9** (`s8r/acceptance-fixes-2026-07-26` → `s8r/bug-31-unified-codegen`) собирает все пять фиксов приёмки: BUG-32, BUG-33, BUG-34, FIND-06, FIND-01 — **ожидает мержа**. **Документация синхронизирована** (правило «на каждом ревью обновлять ФТ и ТЗ»): ФТ **v2.5 → v2.8** (Model A auth, денежный учёт paper, перенос капитала из бэктеста, поведение инструментов рисования, торговые часы для закрытия, ограничения AI-провайдеров), ТЗ **v1.5 → v1.6** (cookie-контракт Model A + правило `X-CSRF-Token` для не-axios клиентов, `PaperPortfolioAccountant` и инвариант `Δequity == trade.pnl`, контракт слоя разметки графика, Alembic и `DATABASE_URL`, drain paper-сессий при выкатке, baseline тестов); ссылки на версии поправлены в `deployment_guide.md` и `development_plan.md`.
>
> **2026-07-26 — Gate Sprint_8_Review: ✅ PASS WITH NOTES.** Финальный прогон приёмки выполнен на изолированном стенде (worktree `s8r-acceptance` от `s8r/bug-31-unified-codegen`, копия рабочей БД `acceptance.db`, backend :8100 / frontend :5173, T-Invest-стримы придержаны). UI-секции **S8.1–S8.12 + S8.17 пройдены через Playwright** со скриншотами-evidence (`Sprint_8_Review/screenshots/`, 39 файлов): админ-меню и отказ non-admin, Dash-метрики, error-boundary (сбой сымитирован перехватом сети — соседние блоки живы, «Повторить» лечит), статус-бейджи + переходы + фильтр «Пауза», 4 виджета дашборда, Telegram-мастер (+ **реальная доставка**: `telegram_notification_sent`, `email_notification_sent`), 17 типов уведомлений, рисование на графике (клик–клик, drag, persist после F5, удаление, внутридневные ТФ), AI-описание → блоки на **живом** `deepseek-v4-pro`, панель фоновых бэктестов (лимит 3 + автосворачивание), вкладки результата бэктеста (зоны, `TradeDetailsPanel`, запуск торговли). Ф2b: WS-рукопожатие `connected → auth_ok → subscribed` (cookie-auth Model A) и арифметика BE-TRAD-06 на UI (позиция −273,50 ₽ = (269,14−296,49)×10, −9,22% поз. / −0,27% кап.). **Исправлено test-first прямо в цикле приёмки:** **BUG-32** (HIGH — AI-помощник был полностью нерабочим: SSE-клиент `aiStreamClient.ts` ходил голым `fetch` без `X-CSRF-Token` → 403 «CSRF token отсутствует»; тот же класс, что BUG-21, но другой клиент), **FIND-06** (MEDIUM — `alembic/env.py` игнорировал `DATABASE_URL` и катил миграции в БД из `alembic.ini`; всплыло как 500 `ON CONFLICT clause does not match any PRIMARY KEY or UNIQUE constraint` при сохранении настроек уведомлений — прямая грабля деплоя Sprint 9), **FIND-01** (LOW — «Запустить торговлю из бэктеста» не переносила капитал). **Гейт после фиксов: backend 2186 passed / 1 xfailed / 0 failed, frontend vitest 765 passed, tsc 0, eslint 0, bandit 0 medium+.** Открытых багов severity ≥ medium нет. Остаток (S9-backlog, косметика): пустой SPA-роут `/admin/metrics`, сырое «Request failed with status code 503» при залповом запуске 4 фоновых бэктестов (+ осиротевшие `queued`-строки), молчаливое игнорирование ввода AI на несохранённой стратегии, англоязычные предупреждения парсера блоков, Email-тумблер для событий вне `EMAIL_ALLOWED_EVENTS`, автозаполнение менеджером паролей в поле «Bot token». Требует прод-условий: живые p50/p95 «сигнал→ордер» под нагрузкой и визуальный resize фигуры на графике. Детали: `Sprint_8_Review/acceptance_checklist.md` (вердикт внизу) + `Sprint_8_Review/s8r_acceptance_run_2026-07-26.md`.
>
> **2026-07-06 — Полное код-ревью всей кодовой базы + исправление всех 7 критических (P0).** Многоагентный аудит (~344 находки): `Спринты/Code_Review_Full_2026-07/` (отчёт, бэклог, верификация, TDD-задачи P0/P1). Все 7 critical (C1–C7: webhook fail-open, IDOR сессий, дефолтные ключи, cookie Secure, утёкший секрет, close_all_positions, реверс-сплит) исправлены test-first (Opus 4.8), `/code-review` по trading пройден, смёржено в `s8r/bug-31-unified-codegen` и запушено (`1107ec3`). Детали: `Code_Review_Full_2026-07/P0_FIXES_LOG.md`. C5-чистка git-истории пропущена по решению заказчика (репозиторий приватный).
>
> **2026-07-06 — P1 Волна 1 (backend) исправлена и запушена (`a936e1a`).** 18 High: be-trading (BE-TRAD-03/04/05/07/08/09), be-market-data (BE-MKT-01..05), be-backtest (BE-BTST-01/02/04 + WS-authz AUTHZ-04), be-strategy (BE-STRAT-03/04 + 02 частично). `/code-review` по trading нашёл 9 дефектов в свежих фиксах (2 money-критичных: BE-TRAD-09 не закрывал ×10; фантом-close при figi=None) — все исправлены test-first (`review-followup` FIX-1..9). Гейт: 1329 passed, pyright 0. Детали: `Code_Review_Full_2026-07/P1_WAVE1_LOG.md`. **Осталось:** P1 Волна 2 (auth/broker/notification/ai/runtime/misc) + Волна 3 (frontend); NEEDS-REVIEW BE-TRAD-06 / BE-STRAT-02 / BE-MKT-02 → ARCH.
>
> **2026-07-07 — P1 Волна 2 (backend) исправлена и запушена в `p1/wave2-backend` (Develop, HEAD `9cd44aa`; remote `s8r/bug-31` не тронут — Волна 2 на отдельной ветке для ревью/мержа).** 13 High через 6 DEV-агентов в worktree'ах: be-auth-session (BE-AUTH-02/03), be-broker (BE-BROK-01/02), be-notification (BE-NOTIF-02/03 + alembic `c9f1a2b3d4e5`), be-ai (BE-AI-01/02), be-runtime (BE-RT-01/02/03), be-misc (BE-MISC-17/18/19). `/code-review` (xhigh, 10 углов + верификация) нашёл **8 дефектов в свежих фиксах** + до-верификация мультиплексора **ещё 5** — все исправлены test-first (5 review-коммитов): CB fixed_sum обходил лимит ×3 + fail-closed паузил сессию + сеть под lock без таймаута (BE-RT-01); блокирующий DNS в event loop + SSRF-обход редиректом + Ollama-500 (BE-AI-01); неатомарная reuse-detection refresh → 500/обход (BE-AUTH-03); потеря уведомлений при shutdown + shield-сирота (BE-NOTIF-02); мультиплексор — двойной SUBSCRIBE/reconnect без backoff/отравленная пара/interval-less broadcast/воскрешение mux (BE-BROK-01, K1-K5). Гейт: **2129 passed, 0 failed, pyright 0 новых**. Детали: `Code_Review_Full_2026-07/P1_WAVE2_LOG.md`. **Осталось:** Волна 3 (frontend); backlog: P1W2-SSRF-PINNING, P1W2-AI-LOCAL-PROVIDER-UPGRADE, P1W2-SANDBOX-EPHEMERAL-PROC, P1W2-BE-MISC-19-TAX-CATEGORIES, P1W2-MULTIPLEXER-STOPPED-CANDLE-RACE (low).
>
> **2026-07-07 — Решения по продолжению P1 (заказчик).** (1) **Ветвление:** копить `p1/wave*` отдельно (`p1/wave2-backend` есть, дальше `p1/wave3-frontend`, `p1/auth-hardening`), remote `s8r/bug-31` не трогать; свести всё в `s8r/bug-31` одним PR/мержем с финальным ревью ПОСЛЕ всех волн. Локальный `s8r/bug-31` возвращён к remote (a936e1a); живой чекаут Develop — на `p1/wave2-backend`. (2) **Auth-hardening вынесен** из Волны 3 в отдельную координированную backend+frontend мини-волну: CFG-FE-01 (токены→HttpOnly cookie) + P1W2-REFRESH-GRACE (grace-окно + single-flight + cross-tab) — `Code_Review_Full_2026-07/P1_AUTH_HARDENING_HANDOFF.md`. Волна 3 (frontend) — без CFG-FE-01: `P1_WAVE3_HANDOFF.md`. (3) Открытая мелочь: `backend/.env.example` не содержит `AI_ALLOW_PRIVATE_PROVIDER_URLS=false` — заблокировано permission-правилом `.env*` (правится вручную; флаг задокументирован в `config.py`).
>
> **2026-07-07 — P1 Волна 3 (frontend) исправлена в ветке `p1/wave3-frontend` (Develop, база `9cd44aa`; remote `s8r/bug-31` не тронут; коммиты/push ожидают подтверждения).** ~23 High через 6 DEV-агентов Opus test-first в worktree'ах: fe-security (WS-кластер CFG-FE-02/FE-NET-01/FE-STOR-12 → auth-handshake первым сообщением вместо токена в query-string + FE-STOR-13), fe-network (FE-NET-03 Decimal-нормализатор + FE-NET-04 reconnect backoff), fe-charts (FE-CHART-01 vline sequential + FE-CHART-02 рефактор CandlestickChart 907→702 + FE-CHART-03 mskTime), fe-backtest-ui (FE-BTST-13/14/15/16), fe-core-refactor (FE-PAGE-01 рефактор StrategyEditPage 1101→783 + FE-PAGE-02 + FE-CORE-01/02/06/07/08), fe-ui-misc (FE-STRAT-01 allow-list блоков фронт+бэк + FE-TRAD-01/02 + FE-UI-01). Мерж 6 веток — clean, без конфликтов. `/code-review` (xhigh, 5 углов Opus — перезапуск после исчерпания лимита Fable 5) нашёл **6 дефектов в свежих фиксах** — исправлены test-first (`0e039be`): WS-auth контракт (4001→4401 + onclose-guard + e2e-мок auth_ok — устранён reconnect-шторм на протухшем токене), visibleRafLoop (ResizeObserver-пробуждение), StrategyBacktestsTable (formatDate вместо new Date, BUG-3/4), backtestStore race-guard, ws.py binary-frame/timeout. Гейт: **vitest 745 / 0 failed, tsc 0, backend backtest+trading+strategy 860 / 0 failed** (полный backend 2152 на живом `.env`). Детали: `Code_Review_Full_2026-07/P1_WAVE3_LOG.md`. **CFG-FE-01/FE-NET-02/FE-PAGE-03 НЕ делались** (дубли → auth-мини-волна). **Осталось:** Playwright-скриншоты (нужен инстанс на коде волны 3 — ожидает решения); push обеих веток (по подтверждению); auth-hardening мини-волна; backlog: P1W3-WS-AUTH-CONSOLIDATE, P1W3-DRAWINGS-MSK-CONSOLIDATE, P1W3-BACKTESTAPI-DECIMAL-CONVENTION, P1W3-MULTIPLEX-WS-REFRESH.
>
> **2026-07-08…09 — Auth-hardening мини-волна (backend+frontend, координированно) реализована в ветке `p1/auth-hardening` (Develop, worktree; база `0e039be`; remote `s8r/bug-31` не тронут; НЕ запушено).** Model A — оба JWT переведены из `localStorage` в **HttpOnly+Secure cookie** (CFG-FE-01) + устранён разлогин двух вкладок через **единый cross-tab single-flight refresh** на `navigator.locks` (P1W2-REFRESH-GRACE; grace-окно сознательно НЕ вводилось — по итогам независимого ревью дизайна). Метод: brainstorm → независимое ревью дизайна с верификацией по коду → spec (`P1_AUTH_HARDENING_DESIGN.md`) → план (`P1_AUTH_HARDENING_PLAN.md`) → 18 тасков subagent-driven (implementer+reviewer Opus, test-first). **Backend (8):** `get_access_token` cookie∨Bearer; `login/setup/refresh` ставят 3 cookie (access path=/, refresh path=/api/v1/auth/refresh, csrf TTL=refresh), тело без токенов (`AuthMetaResponse`); refresh из cookie + CSRF double-submit (убран из exempt); logout стирает 3 cookie; WS cookie-auth на upgrade ×3 (`common/ws_auth.py`) + `auth_ok` первым кадром + Origin-check. **Frontend (7):** `api/session.ts` single-flight; client/aiStream на cookie; authStore без токенов + logout→backend + `partialize{user}`; LoginPage/SetupPage bodyless; bootstrap `/auth/me` под loading-гейтом; WS-хуки без токена. **Гейт: backend 2170 passed/0 failed, pyright 0 новых; frontend tsc 0 + vitest 761/0.** `/code-review` backend **MINOR-ONLY**, frontend **MINOR-ONLY** (3 фикса), финальное whole-branch ревью **READY-TO-MERGE** (cross-cutting контракт согласован). Детали: `Code_Review_Full_2026-07/P1_AUTH_HARDENING_LOG.md`. **Побочно закрыт `P1W3-WS-AUTH-CONSOLIDATE`.** **Осталось:** push (по подтверждению, ветки обоих репо); финальное сведение всех `p1/wave*`+`p1/auth-hardening` в `s8r/bug-31`. Backlog: P1-AUTH-NET-LOSS-RELOGIN, P1W3-MULTIPLEX-WS-REFRESH (1006-reconnect), WS-revoked-token, refresh rate-limit per-IP.
>
> **2026-07-09 — Playwright E2E волны auth-hardening ✅ (реальный браузер, cookie-flow).** Отдельный инстанс: backend+frontend из worktree, изолированная тест-БД `data/e2e_auth.db` (схема из моделей, `DEBUG=true`→Secure=false, тест-юзер через `/setup` — пароль sergopipo не понадобился). План `e2e_auth_hardening_plan.md` → фикс фикстур под Model A → новые сценарии → **реальный прогон**. **`e2e/auth-hardening.spec.ts` — 7/7 passed:** login→3 HttpOnly-cookie→работа→logout (cookie исчезли); тихий refresh при удалённом access (без разлогина); **две вкладки через ротацию — ни одну не выкидывает** (P1W2-REFRESH-GRACE); reload через cookie-бутстрап `/auth/me`; WS `/ws`+`/ws/trading-sessions` cookie-auth на upgrade + `auth_ok` (+ негатив: без cookie нет auth_ok). Контракт cookie (имена/flags/path/TTL) верифицирован вживую = DESIGN §3. **Регрессия mock-suite (CI=1): 161 passed, 3 skipped, 1 flaky** (`s5-account` — проходит изолированно). Всплывшие 8 падений — пре-существующий дрейф фикстур (git: файлы не менялись волной), не регресс Model A, починены в E2E-скоупе: FirstRunWizard-модалка (гейт читает `/auth/me`), `/user-favorites` backend-миграция (S8R BUG-20), `mockS7Apis` гейт `/users/me`→`/auth/me` (S8 W8t). Файлы: `e2e/auth-hardening.spec.ts` (new), `e2e/fixtures/api_mocks.ts`, `e2e/s5-favorites.spec.ts`, `e2e/s7-front2.spec.ts`, `e2e/s7r-chart-drawings-fix.spec.ts`, `scripts/playwright_login.sh`. **Волна auth-hardening полностью готова; осталось только push + сведение в `s8r/bug-31` (по подтверждению).**
>
> **2026-07-22 — BE-TRAD-06 (денежный учёт paper-портфеля, Model A) ЗАКРЫТ — последняя открытая P1.** PR #7 (`p1/auth-hardening` → `s8r/bug-31-unified-codegen`) **смёржен** (merge-commit `94721e8`, fast-forward) по решению заказчика; ветка `p1/be-trad-06` создана от обновлённого `s8r` (worktree, живой чекаут не тронут). Метод: superpowers **subagent-driven-development** по готовому плану (7 задач, TDD Red→Green, implementer+reviewer на каждую + финальное whole-branch ревью Opus). **Model A:** `balance`=свободный кэш, `blocked_amount`=капитал открытых позиций по входу, `equity=balance+blocked`; единая точка мутации `PaperPortfolioAccountant`; три точки учёта починены (buy-fill списывает+reject при нехватке; ручное/all-close и SL/TP-close кредитуют ×lot_size); инертный T+1 нейтрализован (`unblock_settled_funds`→no-op, `available=balance`); CB/AI не менялись. Инвариант `Δequity==trade.pnl` (после review-fix quantize — копейка-в-копейку и для облигаций). **Гейт: `test_circuit_breaker+test_trading` = 327 passed, 0 failed; ruff/py_compile чисто; 0 новых pyright; CB-drawdown на paper реально срабатывает** (`test_cb_drawdown_triggers_on_paper`). Финальное ревью: **0 Critical**, все actionable-Minor закрыты (`50f3335`). Коммиты `035f817..50f3335`. **Deploy-нюанс (не код-баг):** paper-позиции на границе деплоя → разовый drain открытых paper-сессий перед апдейтом (`deployment_guide.md` §7). Детали: `Code_Review_Full_2026-07/BE_TRAD_06_LOG.md`. **Открытых P1 не осталось.**

---

## Текущая фаза: **Sprint_8_Review закрыт содержательно — раздел «⬜ ОТКРЫТО» пуст, PR #9 и #10 смёржены. Остались только организационные мержи веток и сдача. Sprint 9 не стартовать.**

> ⚠️ 2026-07-09: секция ниже актуализирована — W7 давно сделан (был устаревший статус «стартует 2026-05-14»).

- **Sprint 8 (код, основной scope)** — 🏁 закрыт окончательно 2026-05-13 (W3+8.R+W4+W5+W5-hotfix). M4 Production-ready тэг по факту относится только к paper-trading.
- **Sprint 8 W7 (BUG-1, sandbox/real trading)** — ✅ **сделан** (коммит `fbd616b` + доработки `s8-w8a…w8h`, Вариант C++ синхронный fill). 33 юнит-теста зелёные. **Живо переподтверждён 2026-07-09** (свежий реальный sandbox buy→sell на текущем коде: filled + `broker_order_id`, per-share цена через GetOrderState). ⚠️ При этом выявлено: T-Invest пересоздал sandbox-аккаунт — старый `account_id` в БД протух, обновлён на живой `f925da17…` (иначе новая sandbox-сессия падала «Account not found»). См. backlog `S8R-SANDBOX-ACCOUNT-STALE-REOPEN`.
- **Sprint_8_Review — доведение, вторая волна** — ✅ **ЗАКРЫТА 2026-07-27.** По команде заказчика закрыты все 6 находок «попутно» (ruff F401 в alembic — из-за него CI job `lint` был красным и PR #9 висел UNSTABLE; серверная нормализация email в `PUT`; диагностика в `detail` PDF-экспорта; сырой `e.message` в Grid Search; REST-реконсиляция «висящих» фоновых бэктестов; разбор плавающего `test_max_positions_limit` — оказалось, юнит-тест ходил в MOEX ISS за размером лота). Плюс адаптивный таймаут выборки данных по запросу заказчика (`clamp(чанки × 15 с, 60 с, 1800 с)` вместо фиксированных 180 с). Гейт: pytest **2222/0 failed**, vitest **831/120 файлов**, tsc 0, eslint 0, ruff 0, mypy 0, bandit 0 medium+. E2E: **158 passed / 4 failed / 3 skipped** (4 падения предсуществующие — подтверждено прогоном той же спеки на базовой ветке; `auth-hardening.spec.ts` требует штатных портов 8000/5173 и не прогонялся). Stack Gotchas 45 → **46**. Коммит `a5698a7`.
- **Sprint_8_Review — остаток приёмки (8 замечаний)** — ✅ **ЗАКРЫТ 2026-07-27.** Все 8 карточек вердикта PASS WITH NOTES исправлены в текущем цикле (решение заказчика от 2026-06-11: багфиксы — в цикле приёмки, не в S9). Ветка кода `s8r/backlog-fixes-2026-07-27` от `s8r/acceptance-fixes-2026-07-26` (PR #9 на момент работ не смёржен). 4 параллельных DEV-агента в изолированных worktree, TDD по каждой карточке. Гейт: backend **2213 passed / 1 xfailed / 0 failed** (baseline 2186, +27 новых тестов), vitest **828 passed / 119 файлов** (baseline 772/111, +56), tsc 0, eslint 0, mypy 0, bandit 0 medium+. Evidence — 10 скриншотов `Sprint_8_Review/screenshots/s9-*.png`, проверка на изолированном стенде :8110/:5183 на копии БД приёмки. Stack Gotchas: 36 → **45** (9 новых). Детали по каждой карточке — `Sprint_8_Review/backlog.md`.
- **Sprint_8_Review** — ✅ **ЗАКРЫТ 2026-07-26, вердикт PASS WITH NOTES.** Все шаги чеклиста закрыты (102 `[x]`, 2 `[-]` — resize фигуры глазами и живые p95 «сигнал→ордер», оба требуют прод-условий). В цикле приёмки исправлены BUG-32 (HIGH), FIND-06 (MEDIUM), FIND-01 (LOW). Гейт: backend 2186 / frontend 765 / tsc 0 / eslint 0 / bandit 0 medium+. Артефакты: `Sprint_8_Review/acceptance_checklist.md`, `s8r_acceptance_run_2026-07-26.md`, `screenshots/`.
- **P1 код-ревью (P0+P1)** — ✅ волны 1/2/3 + auth-hardening + E2E + **BE-TRAD-06** готовы. PR #7 (`p1/auth-hardening` → `s8r/bug-31-unified-codegen`) **смёржен** (`94721e8`). **BE-TRAD-06 закрыт** (2026-07-22, ветка `p1/be-trad-06`, коммиты `035f817..50f3335`, гейт 327 passed / 0 failed, финальное ревью 0 Critical) — см. `Code_Review_Full_2026-07/BE_TRAD_06_LOG.md`. **Открытых P1-находок не осталось.** **Сведение в `s8r/bug-31-unified-codegen` ЗАВЕРШЕНО** (PR #7 `94721e8` + PR #8 `eba6427`; wave2/wave3 уже содержались) — s8r содержит все P0/P1 + BE-TRAD-06. Осталось только: деплой-нюанс BE-TRAD-06 (разовый drain paper-сессий при выкатке, `deployment_guide.md` §7).
- **Sprint 9 "Перевод в продуктив"** — ⬜ запланирован, стартует после Gate Sprint_8_Review. Содержание: фаза 9.1 = Mac mini Docker prod (18080) + LAN + backup; фаза 9.2 = canary (18081) + автоматизация.
- **Sprint 9 "Перевод в продуктив"** — ⬜ запланирован, стартует после Gate Sprint_8_Review (PASS / PASS WITH NOTES, который зависит от W7). Содержание: фаза 9.1 = Mac mini Docker prod (18080) + LAN + backup; фаза 9.2 = canary (18081) + автоматизация. Спека-черновик: `docs/superpowers/specs/2026-05-13-s8-w6-design.md`.

## Прогресс по спринтам

| Спринт | Название | Статус | Ключевой результат | Отчёт |
|--------|----------|--------|-------------------|-------|
| S1 | Фундамент | ✅ завершён | Auth, дашборд, CI, 68 тестов | Sprint_1/sprint_report.md |
| S2 | Данные и графики | ✅ завершён | Брокер, графики, шифрование, 175 тестов | Sprint_2/sprint_report.md |
| S3 | Стратегии + редактор | ✅ завершён | Blockly, Sandbox, CSRF, 320 тестов | Sprint_3/sprint_report.md |
| S4 | AI + бэктестинг | ✅ завершён | AI chat, Backtest Engine, 577 тестов | Sprint_4/sprint_report.md |
| S5 | Торговля | ⚠️ завершён с замечаниями (весь долг устранён в S5R + closeout) | Trading Engine, Paper Trading, Circuit Breaker, Bond/Tax, 548 тестов + 23 E2E | Sprint_5/arch_review_s5.md |
| **S5 Review** | **Внеплановое ревью + 3 волны closeout + wave 4 (chart bug-fixes): стабилизация перед S6** | **✅ закрыт полностью** | **CI зелёный впервые с 2026-04-03 на всех 5 ветках + develop. Live Runtime Loop замкнут, реальные позиции T-Invest (source через FIGI), 109 Playwright passed (моки, работают 24/7 без seed), **15** Stack Gotchas, 2 бизнес-бага починены, schema drift устранён, tinvest stream API исправлен, iss_tail_fetch timezone, кнопка Запустить торговлю из бэктеста подключена. **Wave 4 (фазы 3.3–3.7, 2026-04-16):** T-Invest naive→aware (gotcha-15), client-side `candlesCache` + persist в localStorage, race-guard в `fetchCandles`/`fetchOlderCandles`, фикс D-мигания в ChartPage. Крупные треки (backend prefetch, live-агрегация 1m→D, sequential-index mode, 401 debug) вынесены в **Sprint_5_Review_2** (S5R-2). Вердикт ARCH: PASS WITH NOTES, блокеров нет.** | **Sprint_5_Review/arch_review_s5r.md** + **Sprint_5_Review/changelog.md** разделы closeout + фазы 3.3–3.7 |
| **Sprint_5_Review_2** | **Chart hardening — 5 треков патч-цикла** | **✅ закрыт (ARCH: ПРИНЯТ)** | **Трек 4:** 401 fix (cleanup+guard+gotcha-16). **Трек 5:** TF-aware upsertLiveCandle. **Трек 3:** sequential-index mode intraday. **Трек 1:** prefetch свечей при логине (warm cache). **Трек 2:** верификация агрегации 1m→D/1h/4h (12 тестов, багов нет). ARCH-ревью: 15 проверок, 14 OK, 1 minor. Тесты: 238 frontend + 623 backend = 861 total, 0 failures. | Sprint_5_Review_2/arch_review_s5r2.md |
| **S6** | **Уведомления + Security** | **✅ завершён** | Telegram, Email, In-app, Recovery, Graceful Shutdown, SDK upgrade (beta117), Stream Multiplex, E2E infra, Security tests. 685 backend + 250 frontend + 10 E2E S6 = **945 тестов**. Доп. работы сессий 22-24.04: карточки сессий (Decimal, unrealized P&L), CB fixes (commit, trading hours, downtime), маркеры сделок на графике, правила плагинов в CLAUDE.md, Playwright автологин. | Sprint_6/arch_review_s6.md |
| **Sprint_6_Review** | **Промежуточное ревью M3: code review + UI-проверки + документация** | **✅ завершён (PASS, 2026-04-24)** | **Code review (8 разделов, 6 fixes).** **E2E регрессия:** 107→119 passed (0 failed). **3 code fixes** обнаружены только при E2E/визуальной верификации: AISettingsPage (`providers??[]` + `toLocaleString` guard), marketDataStore (`candles=[]` default). **Визуальная верификация S6:** 6 скриншотов, 5/6 OK. **EVENT_MAP фикс:** 8 publish-сайтов (runtime.py + engine.py) — 5 event_type теперь корректно подставляют `{strategy_name}`/`{ticker}`/`{direction}`/`{volume}`/`{pnl}`. **Документация:** ФТ/ТЗ/development_plan актуализированы за S5+S6. Итого: **11 FIXED + 1 FP + 3 перенесены в S7** (NS singleton, 5 event_type, inline-кнопки Telegram). **Milestone M3 достигнут.** | Sprint_6_Review/code_review.md, backlog.md |
| **S7** | **Should-фичи + переносы + AI-команды + post-S7 closeout** | **🏁 закрыт окончательно (2026-05-12)** | **17 задач + 7.R + ~30 post-S7 closeout волн.** Формально завершён 2026-04-26 (ARCH 7.R PASS WITH NOTES, M3 Phase 1 feature-complete). 27.04 → 12.05 — 16 рабочих дней post-S7 closeout: multiplexer singleton hotfix, paper SL/TP мониторинг, telegram positions/balance/close polish, P&L dual % формат, Grid Search + applySync полировка, chart drawings backlog (context menu, position-edit, trade markers exact-price), OHLCV timeframe filter, close_position exit/PnL fix, S7R-EQUITY-PER-TRADE + EQUITY-BY-INDEX (BusinessDay-индексы), S7R-BACKTEST-EXPORT-RU (русские заголовки + auto-landscape + DejaVu), S7R-NIGHTLY-CI-MOCKS (Playwright без backend на CI), ruff F821/F841 + mypy non-None narrowing. **Финальные тесты: 750 backend unit / 468 frontend vitest / 142 Playwright nightly, CI на develop ✅.** **DEFERRED-S8:** 25+ карточек (3 medium-high, ~10 medium, ~10 low) — не блокеры. | Sprint_7/arch_review_s7.md + Sprint_7/changelog.md (запись «🏁 SPRINT 7 FINAL CLOSEOUT 2026-05-12») |
| **S8** | **Стабилизация (M4 Production-ready)** | **🏁 закрыт + W4 ✅ + W5 ✅ (2026-05-13, ARCH 8.R: PASS WITH NOTES)** | **W0+W1+W2+W3+8.R+W4+W5 за 2 дня (12-13.05).** Coverage 71% → **≥84.83% TOTAL** (gate `--cov-fail-under=80` в CI). Per-module: market_data/service 50→**83%**, strategy/service 51→**97%**, backtest/router 25→**87%**, dispatchers 0→100%, trading/service 51→88%, adapter 24→95%, backtest/engine 55→96%. Security: 3 high + auth rate tighten (60 → 5/min) закрыты, bandit/safety в CI. Admin role + Plotly Dash `/admin/metrics`. Event sync: EVENT_MAP=17 ↔ EVENT_TYPE_LABELS=17. Dashboard widgets: 4 виджета (Sparkline, Health WS, Balance с RUB/USD toggle, ActivePositions, responsive cols). Drawing editing + intraday coords + legacy backfill. Production-ready инфра: Docker compose + Dockerfile + nginx + launchd + Cloudflare Tunnel + deployment_guide.md v1.0. Документация: ФТ v2.5 (17 EVENT_TYPE_LABELS), ТЗ v1.5 + §8.10 Deployment Architecture, dev_plan v2.1, perf_baseline_w5. Stack Gotchas: 23 → **32**. Performance: `@timed_event` overhead 14 мкс, hot-path synthetic 1.4-2.5 мс (все цели ТЗ с запасом). **Финальные тесты после W5: 1547 backend / 0 failed @ ≥80% coverage, 578 vitest / 0 failed, 160 Playwright / 1 flaky / 3 skipped, 0 lint warnings (--max-warnings 0), 0 xfailed (event_delivery race починен).** ARCH 8.R: 0 блокеров. W4 закрыл 12/18 carry-over + 1 partial; W5 закрыл оставшиеся 7/7. Все 25 W3+W4 carry-over закрыты внутри S8. Sprint_8_Review — без накопления переносов, только финальная приёмка решений. | Sprint_8/arch_review_s8.md, Sprint_8/changelog.md, Sprint_8/sprint_state.md, Sprint_8_Review/backlog.md, Sprint_8/perf_baseline_w5.md |

**Легенда:** ⬜ не начат · 🔄 в процессе · ✅ завершён · ⚠️ завершён с замечаниями

## Что делать дальше

```
ТЕКУЩЕЕ ДЕЙСТВИЕ (2026-08-06): цикл «один инструмент — одна сессия на
  счёте» ВЫПОЛНЕН — см. backlog, раздел от 2026-08-06.
  Ответы заказчика закрыты полностью (Q1=a, Q2=a, Q3=a, Q4=a, Q5=a, Q6=a,
  Q7=a, Q8=a, Q9, Q10, Q11, Q12=a). Q12 в первом ответе не пришёл —
  реализация шла по варианту (a) на усмотрение исполнителя и была вынесена
  в отчёт отдельным пунктом; заказчик подтвердил (a) тем же днём.
  Sprint 9 по-прежнему НЕ стартовать.

    ГЛАВНОЕ, ЧТО ИЗМЕНИЛОСЬ ДЛЯ ПОЛЬЗОВАТЕЛЯ:
    1. По одному инструменту на одном брокерском счёте теперь можно вести
       только ОДНУ стратегию. Причина не формальная: позиции у брокера
       обезличены, и две сессии по одному тикеру делили общий пул бумаг —
       стоп-лосс одной мог закрыть бумаги, которые учёт относил к другой,
       а результат каждой считался по её цене входа. Тот же тикер на ДРУГОМ
       счёте разрешён. Бумажный режим не ограничен.
    2. Форма запуска предупреждает ЗАРАНЕЕ: кнопка «Запустить» неактивна, а
       под формой видно, какая именно сессия мешает и почему. Раньше вторая
       сессия просто запускалась.
    3. «Возобновить» тоже проверяется — вторую сессию можно было создать
       раньше, чем запустят первую.
    4. Существующие сессии не тронуты: пара #4/#6 осталась в истории как
       есть, запрет действует на новые запуски. Перезапуск терминала такую
       пару переживает — поднимается одна.
    5. Ложное «расхождение с брокером» больше не показывается: раньше
       суммарный портфель счёта сравнивался со сделками ОДНОЙ сессии, и при
       нескольких сессиях «у брокера больше» получалось всегда. Теперь
       сравнивается сумма по всему счёту, а портфель запрашивается один раз
       на счёт, а не на каждую сессию.

    Код-ревью (3 независимых ревьюера) нашло 9 находок, 8 подтвердились и
    закрыты в этом же цикле. Две из них — прямое следствие обобщения «по
    сессии» → «по счёту»: ослабла защита от неполного портфеля песочницы, и
    незакрытая сделка ОСТАНОВЛЕННОЙ сессии могла заглушить здоровую соседку.
    Ещё одна отменила моё же решение не трогать статус: сессия, которую
    восстановление не поднимает, оставалась «активной» без listener'а —
    не торговала, не сверялась, но в интерфейсе выглядела работающей.
    Одна находка НЕ подтвердилась и отклонена разбором.

    МИГРАЦИЙ НЕТ (Q5=a). Alembic head прежний — a7b8c9d0e1f2.
    РАБОЧАЯ БД НЕ ТРОГАЛАСЬ. Живой брокер не требовался: sandbox-счёт #3
    не открывался, .env не читался, симлинк не ставился.

    ГЕЙТЫ: pytest 2552 / 1 xfailed / 0 failed · vitest 864 / 125 ·
    tsc 0 · eslint 0 · ruff 0 · mypy Success (177) · bandit 0 medium+ ·
    E2E 169 passed / 3 skipped одним прогоном · nightly на develop ЗЕЛЁНЫЙ.
    Stack Gotchas 58 → 59, INDEX version 23.
    Документация: ФТ v3.7, ТЗ v2.7, ui_checklist S8.30 (обе копии).

    ПОСТ-МЕРЖ CI НА develop — ЗАКРЫТ 2026-08-10 (перезапуск, правок кода нет).
    Прогон 31119745716 на fe46f00: backend 2558 passed / 1 xfailed,
    frontend 864 / 125, security-scan pass — все три джобы зелёные.
    С 06.08 по 09.08 гейт висел НЕ из-за кода: джобы backend и frontend
    четыре раза подряд завершались с НУЛЁМ выполненных шагов (раннеры не
    выделялись, отмена ровно через 15 мин; на одной попытке Service
    Unavailable на «Set up job»). Инцидент GitHub Actions — тот же класс,
    что 31 июля. 2558 против 2552 выше — +6 тестов paper-цикла.

    ОТКРЫТО ПОСЛЕ ЭТОГО ЦИКЛА (новые находки, чинить отдельно):
    - S8R-RESUME-STOP-NO-SESSION-LOCK (low) — «Стоп» и «Возобновить» по одной
      сессии одновременно: побеждает последний коммит, «Стоп» может молча
      отмениться. Предсуществующее.
    - S8R-DELETE-ACCOUNT-ORPHANS-SESSIONS (low) — удаление брокерского счёта
      обнуляет broker_account_id у живых сессий и выводит их из-под запрета.
    - S8R-PAPER-CONFLICT-BY-VERSION-NOT-TIMEFRAME — ЗАКРЫТА в тот же день
      по вашему указанию: ограничение снято, две paper-сессии по одному
      тикеру запускаются свободно (в том числе на одинаковых настройках).
      У каждой свой виртуальный портфель, брокерских бумаг они не занимают.
      Запрет для песочницы и реального счёта не затронут.

    СПИСОК «ДО ДЕПЛОЯ И ДО S9» — 2026-08-10, по вашему запросу.
    Sprint_8_Review/pre_deploy_checklist.md. Проведена сплошная сверка
    33 карточек-переносов Sprint 7 С КОДОМ (не с документами): 28 из них
    фактически закрыты волнами S8 W4/W5 и приёмкой, но заголовки в backlog
    не обновлялись — раздел «Sprint 7 — переносы» вводил в заблуждение.
    Реально открыты 5. СРОЧНАЯ ОДНА: S7R-CI-NODE24-MIGRATION, дедлайн
    2026-09-16 — после этой даты Node 20 удаляют с раннеров и CI встанет
    целиком (coverage-gate и security-scan в том числе).
    Блокеры деплоя: Node 24; mock-курс 90 ₽/$ в BalanceWidget (в проде
    пользователь увидит неверные деньги); docker compose ни разу не
    запускался семантически; «Запустить заново» даёт 422 для sandbox/real
    (S7R-SESSION-RERUN-PAYLOAD-BROKEN, подтверждено в коде); удаление
    брокерского счёта выводит живые сессии из-под запрета дублей.
    Гигиена до S9: 6 карточек low, ~12 ч суммарно.

  ---
  Предыдущее (2026-08-06): цикл «FIGI сделок, гонка реконсиляций и
  хвост сверки» ВЫПОЛНЕН — см. backlog, раздел от 2026-08-06.
  Ответы заказчика закрыты полностью (Q1=a, Q2=b, Q3=a, Q4=a, Q6, Q7, Q8).
  Sprint 9 по-прежнему НЕ стартовать.

    ГЛАВНОЕ, ЧТО ИЗМЕНИЛОСЬ ДЛЯ ПОЛЬЗОВАТЕЛЯ:
    1. Сверка с брокером наконец РАБОТАЕТ на sandbox/real-сделках. Раньше в
       сделку писался фиктивный `paper_SBER` либо (после прошлого фикса)
       вообще ничего — справочник инструментов у вас пуст по FIGI, а другого
       источника не было. Теперь FIGI берётся у самого брокера и кэшируется.
       Проверено на живом счёте: куплен 1 лот SBER → сделка получила
       BBG004730N88 → СВЕРКА СОШЛАСЬ (расхождения нет, сессия работает).
       Счёт возвращён в исходное состояние.
    2. Расхождение теперь проверяется НЕ только при старте, а раз в 15 минут
       в фоне. Сессия без открытых сделок и без пометки не опрашивается —
       лишних запросов к брокеру нет.
    3. Ложных остановок стало меньше. Если у брокера бумаг БОЛЬШЕ, чем знает
       сессия (второй сессией на том же счёте или вашей ручной покупкой) —
       это показывается, но сессию больше не глушит. Пауза осталась только
       там, где бумаг у брокера МЕНЬШЕ, то есть наша позиция не обеспечена.
    4. Возобновление сессии после расхождения больше не «молчит»: если она
       снова уходит на паузу, приходит уведомление, а не тишина.

    Код-ревью (3 независимых ревьюера) нашло 11 находок, 10 подтвердились и
    закрыты в этом же цикле (5 failed → 7 passed). Две из них — прямое
    следствие фоновой сверки: она превращала разовые дефекты старта в
    остановку торговли каждые 15 минут. Ещё одна (зависшая сделка запирала
    ВЕСЬ счёт вместе с SL/TP) — следствие унификации локов.
    Одна находка НЕ подтвердилась и отклонена с измерением.

    МИГРАЦИЯ: a7b8c9d0e1f2 (данные: paper_* → настоящий FIGI либо NULL у
    sandbox/real-сделок; paper-сделки не тронуты). Head — a7b8c9d0e1f2.
    РАБОЧАЯ БД НАКАТАНА (Q4=a): c3d4e5f6a7b8 → a7b8c9d0e1f2, бэкап
    data/terminal.db.bak-2026-08-06, integrity_check ok, данные целы.
    Backend с вашей БД теперь поднимется — схема догнала код.

    ГЕЙТЫ: pytest 2518 / 1 xfailed / 0 failed · vitest 858 / 124 ·
    tsc 0 · eslint 0 · ruff 0 · mypy Success (177) · bandit 0 ·
    E2E 169 passed / 3 skipped одним прогоном · nightly на develop ЗЕЛЁНЫЙ.
    Stack Gotchas 57 → 58, INDEX version 22.
    Документация: ФТ v3.6, ТЗ v2.6, ui_checklist S8.29 (обе копии).

    КЛЮЧИ .env ПРИВЕДЕНЫ В ПОРЯДОК (2026-08-06, вечер):
    SECRET_KEY сменил заказчик, ENCRYPTION_KEY ротирован перешифровкой —
    оба по 64 байта. 3 брокерских токена и 2 AI-ключа перешифрованы новым
    ключом, повторный ввод не потребовался; проверено живым вызовом T-Invest.
    Бэкапы: terminal.db.bak-reencrypt-2026-08-06, .env.bak-reencrypt-2026-08-06.
    Побочно: при DEBUG=false слабый ключ давал fail-fast, то есть в
    production-режиме стенд бы не поднялся — теперь поднимается.
    Карточка S8R-ENV-KEYS-TOO-SHORT ЗАКРЫТА.

    ОТКРЫТО ПОСЛЕ ЭТОГО ЦИКЛА (новые находки, чинить отдельно):
    - S8R-RECONCILE-NO-ACCOUNT-DEDUP (low) — фоновая сверка опрашивает
      портфель на каждую сессию отдельно; 10 сессий одного счёта = 10
      одинаковых запросов. Таймаут ограничивает ущерб, дедупликации нет.
    - S8R-ENTRY-PATH-NO-CLOSE-LOCK (low) — путь открытия позиции не берёт
      лок сделки (предсуществующее).
    - S8R-TRADES-WITHOUT-FIGI-UNMATCHABLE (low) — сделка, открытая ДО
      миграции и оставшаяся открытой, FIGI задним числом не получит. У вас
      таких нет (все sandbox-сделки закрыты).
    - S8R-FIGI-NO-NEGATIVE-CACHE (low) — неудачный резолв FIGI не кэшируется.

  ---
  Предыдущее (2026-08-05, вечер): цикл «сверка с брокером как
  источником правды» ВЫПОЛНЕН — см. backlog, раздел от 2026-08-05 (вечер).
  Ответы заказчика закрыты полностью (Q1=a, Q2=a, Q3=a, Q4=a, Q5, Q6, Q7).
  Sprint 9 по-прежнему НЕ стартовать.

    ГЛАВНОЕ, ЧТО ИЗМЕНИЛОСЬ ДЛЯ ПОЛЬЗОВАТЕЛЯ:
    1. Закрывающий ордер больше не теряется при перезапуске backend.
       Его идентификатор сохраняется ДО ожидания ответа брокера, и при
       следующем старте (далее раз в минуту) терминал СПРАШИВАЕТ у брокера
       судьбу ордера. Повторно ордер не отправляется никогда.
       Проверено на живом sandbox-счёте: сделка #53 доехала до closed,
       exit_price=287,29 (факт брокера), комиссия 0,14 (source=broker),
       позиция SBER у брокера исчезла, DailyStat сошёлся.
    2. Позиции сверяются с брокером при старте сессии — теперь и в sandbox
       (раньше только real; именно поэтому сделки #42/#43 числились
       открытыми с июня). Расхождение ПОКАЗЫВАЕТСЯ: пауза сессии, пометка
       «Расхождение с брокером» в карточке с обоими числами, уведомление.
       Позиции НЕ закрываются и объём НЕ переписывается.
    3. Спорадический сбой песочницы (INTERNAL 70001) распознаётся: чтение
       повторяется автоматически, пользователь видит понятный текст.
       Отправка ордера не повторяется — сообщение предупреждает сверить
       портфель, «ордер мог уйти». За вечер это подтвердилось трижды на
       живом брокере, включая случай, когда ордер ушёл несмотря на ошибку.

    Код-ревью (2 независимых ревьюера) нашло 12 реальных дефектов в свежих
    правках — все закрыты в этом же цикле (9 failed → 12 passed). Три из них
    делали позицию НЕЗАКРЫВАЕМОЙ из терминала, ещё один (штуки против лотов)
    останавливал бы здоровую сессию на каждом рестарте.

    МИГРАЦИИ: d4e5f6a7b8c9 (live_trades.exit_broker_order_id,
    exit_order_placed_at) и e5f6a7b8c9d0 (trading_sessions.position_mismatch_at,
    position_mismatch_note). Head — e5f6a7b8c9d0. deployment_guide §7 обновлён.

    ОТКРЫТО ПОСЛЕ ЭТОГО ЦИКЛА (новые находки, чинить отдельно):
    - S8R-SANDBOX-TRADES-FAKE-FIGI (medium) — у sandbox-сделок в figi лежит
      `paper_SBER` вместо настоящего FIGI, поэтому сверка не может
      сопоставить их с портфелем брокера.
    - S8R-RECONCILE-LOCK-DIVERGENCE (low) — реконсиляция удалённого счёта и
      закрытие сделки берут РАЗНЫЕ локи; узкое окно на задвоение DailyStat.
      Унификация в лоб даёт дедлок — чинить отдельно и осознанно.
    - S8R-RECONCILE-NOT-PERIODIC (low) — сверка только при старте сессии.

  ---
  Предыдущее (2026-08-05, день): цикл «SL/TP у брокера, гонки и
  уведомления» ВЫПОЛНЕН — см. backlog, раздел от 2026-08-05.
  Ответы заказчика закрыты полностью (Q1=a, Q2=a, Q3=a, Q4=b, Q5=a, Q6, Q7, Q8).
  Sprint 9 по-прежнему НЕ стартовать.

    ГЛАВНОЕ: стоп-лосс и тейк-профит в sandbox/real теперь действительно
    закрывают позицию У БРОКЕРА (встречный market-ордер через
    OrderManager.close_position), а не только в учёте терминала. Сверено на
    живом sandbox-счёте: GetPositions до — SBER 1 шт, после срабатывания
    стопа — позиции нет. Если ордер не ушёл, сделка НЕ помечается закрытой,
    и пользователь получает уведомление.
    Двойное закрытие одной сделки исключено (keyed_lock по trade_id, оба
    режима). Уведомление о закрытии показывает чистый P&L и комиссию.

    Код-ревью (3 ревьюера) нашло 7 реальных дефектов в свежих правках —
    все закрыты в этом же цикле (7 failed → 9 passed).

    ГЕЙТЫ: pytest 2441 / 1 xfailed / 0 failed · vitest 855 / 124 ·
    tsc 0 · eslint 0 · ruff 0 · mypy Success (177) · bandit 0 ·
    E2E 169 passed / 3 skipped одним прогоном · nightly на develop ЗЕЛЁНЫЙ
    (run 30986475050, запущен вручную — планового после PR #17 ещё не было).
    Stack Gotchas 54 → 56, INDEX version 20.
    Документация: ФТ v3.4, ТЗ v2.4, ui_checklist S8.25–S8.27 (обе копии).

    ОТКРЫТО ПОСЛЕ ЭТОГО ЦИКЛА (новые находки, чинить отдельно):
    - S8R-EXIT-ORDER-NOT-TRACKED (high) — id закрывающего ордера нигде не
      сохраняется. Рестарт backend в момент, когда ордер в полёте, оставит
      сделку навсегда открытой в терминале при закрытой позиции у брокера.
      Нужна колонка live_trades.exit_broker_order_id + доучёт при старте.
    - S8R-SANDBOX-POSITIONS-NOT-RECONCILED (medium) — нет сверки открытых
      позиций с брокером при старте сессии. На стенде уже проявилось:
      сделки #42 и #43 числятся открытыми с 25-26 июня, у брокера позиций
      нет (счёт 8de9093c брокером удалён).
    - S8R-TINVEST-SANDBOX-FLAKY-70001 (low) — песочница спорадически
      отвечает INTERNAL 70001; движок ведёт себя верно, но текст ошибки
      пользователю ничего не объясняет.

    ПРИМЕНЕНО 2026-08-05 (по команде заказчика):
    - CI по PR #18 зелёный, backend-job реально прогнал 2441 passed —
      совпадает с локальным; frontend 855/124.
    - РАЗЪЕХАВШИЕСЯ СДЕЛКИ ЗАКРЫТЫ (решение заказчика по Q1-бис). Бэкап
      `data/terminal.db.bak-2026-08-05` (через backup API SQLite, gotcha-19).
      Закрытие выполнено штатным путём продукта
      (`OrderManager._reconcile_positions_after_reopen` для счетов #3 и #4),
      а не ручным UPDATE — иначе DailyStat разошёлся бы с числом сделок
      (S8R-RECONCILE-DAILYSTAT-EVENT). Результат: #42 (сессия 3) и #43
      (сессия 6) → status=closed, exit_price=entry_price, pnl=0.00
      (позиций у брокера нет, результат выдумывать нечем), в DailyStat обеих
      сессий строка за 2026-08-05 с trades_closed=1. Открытых sandbox/real
      сделок в рабочей БД не осталось; paper-сделки #50 и #52 не трогались.

    ТРЕБУЕТ РУЧНОГО ДЕЙСТВИЯ ЗАКАЗЧИКА:
    - Ветки. Команда прошлого цикла называла ветки, которых уже нет
      (s8r/merge-to-develop-2, s8r/ci-green-2026-08,
      s8r/tax-and-commission-tail, fix/nightly-pause-resume) — заказчик
      получил на неё «branch not found». Фактически в `Develop` остались
      локальные ветки, полностью содержащиеся в develop:
      ```
      git -C Develop branch -D s8r-acceptance s8r/acceptance-fixes-2026-07-26 \
          s8r/backlog-cleanup-2026-08 s8r/backlog-fixes-2026-07-27 \
          s8r/bug-23-interpreter s8r/bug-31-unified-codegen \
          s8r/sandbox-account-reopen s8r/sandbox-review-fixes s8r/tail-fixes
      ```
      `s8r/sltp-broker-close` — удалять ПОСЛЕ мержа PR #18 (сейчас не в
      develop). `branch -D` заблокирована permission-правилом у исполнителя.

    ПОСТАНОВКА СЛЕДУЮЩЕГО ЦИКЛА: не подготовлена. Кандидаты — три карточки
    выше, начиная с S8R-EXIT-ORDER-NOT-TRACKED.

  ---
  Предыдущее (2026-08-04): цикл «хвост комиссии, налоговый модуль
  и стабильность E2E» ВЫПОЛНЕН — см. backlog, раздел от 2026-08-04.
  Все шесть вопросов постановки закрыты (Q1=a, Q2=a, Q3=b, Q4=a, Q5=a, Q6=a).
  Sprint 9 по-прежнему НЕ стартовать.

    ОТКРЫТО ПОСЛЕ ЭТОГО ЦИКЛА (новые находки, чинить отдельно):
    - S8R-SLTP-SANDBOX-NO-BROKER-ORDER (high) — RiskMonitor закрывает
      позицию только в учёте терминала; в sandbox/real она остаётся
      открытой у брокера. Предсуществующий, найден при разборе комиссии.
    - S8R-CLOSE-POSITION-NO-LOCK (medium) — нет сериализации по trade_id.
    - S8R-PAPER-TARIFF-UNREACHABLE-FROM-UI (low),
      S8R-TELEGRAM-TRADE-CLOSED-GROSS-PNL (low).

    СВЕДЕНО И ПРИМЕНЕНО 2026-08-04 (по команде заказчика):
    - PR #17 смёржен в develop (ecf5c3a). CI зелёный, backend-job реально
      прогнал 2406 passed / 1 xfailed — сверено с локальным baseline.
    - Документация: docs/backlog-006-strategy-builder → main (41beaef).
    - РАБОЧАЯ БД `Develop/backend/data/terminal.db` обновлена:
      бэкап `terminal.db.bak-2026-08-04`; накачена с b8c4d2e6f3a1 до
      c3d4e5f6a7b8 (пять ревизий, БД отставала); тариф всех трёх
      брокерских счетов выставлен 0,05 % (та же ставка, что у формы
      запуска и бэктеста); устаревшие отчёты 3-НДФЛ удалены — 21 запись
      `tax_reports`, 21 `tax_lots` и 2 файла xlsx (считались по лотам,
      база занижена; формируются заново по запросу).

    ТРЕБУЕТ РУЧНОГО ДЕЙСТВИЯ ЗАКАЗЧИКА:
    - `git -C Develop branch -D s8r/merge-to-develop-2 s8r/ci-green-2026-08 \
       s8r/tax-and-commission-tail fix/nightly-pause-resume`
      (команда заблокирована permission-правилом у исполнителя). Первые три
      содержатся в develop; fix/nightly-pause-resume в origin уже нет, а её
      единственный коммит возвращает 6 вхождений networkidle (gotcha-46) —
      сводить нельзя, только удалять.
    - Проверить nightly на develop после мержа: он падал из-за ключа
      rate-limiter, теперь должен пройти без 429.

    ПОСТАНОВКА СЛЕДУЮЩЕГО ЦИКЛА: Sprint_8_Review/prompt_s8r_sltp_and_locks.md
    (SL/TP не закрывает позицию у брокера — high; гонки close_position;
    Telegram с валовым P&L; тариф paper в UI).

  ---
  Предыдущее (2026-07-29): Sprint_8_Review закрыт содержательно.
  Раздел «⬜ ОТКРЫТО» в Sprint_8_Review/backlog.md ПУСТ — закрыты и
  S8R-SANDBOX-ACCOUNT-STALE-REOPEN, и флейк test_order_passes_when_no_violations.

  ВСЕ ВЕТКИ СВЕДЕНЫ (2026-07-30):
    - PR #9  (s8r/acceptance-fixes-2026-07-26 → s8r/bug-31) — ранее.
    - PR #10 (s8r/backlog-fixes-2026-07-27  → s8r/bug-31) — merge commit cc04ef5.
    - PR #11 (s8r/sandbox-account-reopen    → s8r/bug-31) — 3a57caf, CI 2246 passed.
    - PR #12 (s8r/bug-31-unified-codegen    → develop)    — 4c3678c, CI 2246 passed.
      208 коммитов; develop стоял на 21c3326 от 2026-05-18. Конфликт в
      frontend/e2e/s5-paper-trading.spec.ts разрешён (версия S8R + комментарий
      из PR #6). s8r/bug-31 сверх develop: 0 коммитов.
    - Репо документации: main РАЗМОРОЖЕН — merge --no-ff a4a7873
      (был 48f53f2 от 2026-04-25, Sprint 7). Актуальные доки теперь и в main.
    - p1/wave2-backend, p1/wave3-frontend, p1/auth-hardening, s8r/acceptance-fixes
      сводить НЕ потребовалось: сверка показала, что все они уже прямые предки
      S8R-ветки.

  ХВОСТ S8R ЗАКРЫТ 2026-07-30 (кроме B2) — см. блок выше и
  Sprint_8_Review/backlog.md раздел «Хвост S8R — 2026-07-30».
    - Блок A: 5/5 карточек закрыты test-first.
    - Код-ревью блока A: 2 конкурентных дефекта в свежих правках исправлены.
    - Блок B: B1/B3/B4 выполнены, B2 заблокирован доступами.
    - Блок C: worktree убраны, ветка ждёт ручного удаления.
    - Сверх объёма (по решению заказчика): /admin/metrics переведён с mock
      на живые замеры, заведён недостающий декоратор trading.signal_to_order
      и клиентский PerformanceObserver → POST /api/v1/observability/lcp.

  ХВОСТ S8R, ЧАСТЬ 2 — ЗАКРЫТ 2026-07-30, вечер (блоки D, E, F).
    - Блок D: 4/4 находки закрыты. D1 оказалась НЕ косметической —
      derive_lot_size выводит множитель ИЗ volume_rub, поэтому потеря
      lot_size занижала PnL закрытия sandbox/real в lot_size раз
      (тест: 10,50 ₽ вместо 105,00 ₽). D4 закрыта как «персистентность
      не требуется» — решение заказчика.
    - Блок E (B2): ВЫПОЛНЕН. Реальный ордер в T-Invest sandbox исполнен,
      channels_sent = in_app,telegram,email. Пароль заказчика не
      понадобился: стенд поднят на КОПИИ рабочей БД со сброшенным в копии
      паролем. ⚠️ Уточнение: три канала на событии самой сделки
      невозможны — email по событиям сделок не рассылается намеренно
      (EMAIL_ALLOWED_EVENTS). Подтверждено на all_positions_closed.
    - Блок F: все три меры внедрены. Пишущих транзакций на сигнал 2,2 → 1,1.
      Замеры «до» сняты на ОТДЕЛЬНОМ worktree с базой 81ef068, по 3 прогона:
      1 сессия p95 18,9 → 13,1 мс (−31%), p50 везде −3…−30%.
      ⚠️ Честно: p95 при 20 и 40 сессиях НЕ улучшился — разница внутри
      шума (±20% между прогонами). Потолок снимет только смена СУБД, то
      есть разделение решения замером подтверждено. Меры не откатывались:
      выигрыш подтверждён на p50, на 1 сессии и по числу транзакций.
    - Код-ревью (4 независимых ревьюера): найден и исправлен 1 реальный
      дефект в свежем коде — окно агрегата backtest jobs считалось по
      локальной зоне процесса вместо UTC (в проде TZ=Europe/Moscow это
      уводило границу окна на день). Регрессий исторических фиксов нет.
    - Гейты: pytest 2327 passed / 1 xfailed / 0 failed (было 2276),
      vitest 842/122, tsc 0, eslint 0, ruff 0, mypy Success (176 файлов),
      bandit 0 medium+, E2E 162 passed / 3 skipped / 0 failed одним
      прогоном. Stack Gotchas 50 → 51, INDEX.md version 16.
    - Уборка: свой стенд (:8140/:5190) погашен, временный worktree
      s8r-perf-base удалён, копии БД и временные конфиги удалены,
      .git/info/exclude вычищен. Стенды заказчика не поднимались.

  КОММИТЫ ЧАСТИ 2 СДЕЛАНЫ 2026-07-30 (ветки подтверждены заказчиком —
  продолжены текущие, обе НЕ ЗАПУШЕНЫ):
    - код: s8r/tail-fixes, HEAD 7053e66 (18 файлов, +2910/−166),
      worktree Develop/.claude/worktrees/s8r-tail;
    - документация: docs/backlog-006-strategy-builder, этот коммит
      (backlog, project_state, ТЗ §4, 5 скриншотов-evidence).
    Локальные prompt_s8r_*.md и s8r-evidence/ намеренно не коммитятся.

  РЕШЕНИЯ ЗАКАЗЧИКА ПО НАХОДКАМ (2026-07-30, вечер):
    - Исторический PnL sandbox-сделок (S8R-D1-HISTORICAL-PNL-UNDERSTATED)
      НЕ пересчитывать: это тестовые данные, будут зачищены при переходе
      на реальную базу. Карточка закрыта.
    - Остальные находки части 2 чинить в СЛЕДУЮЩЕМ цикле (отдельная
      сессия). Постановка — Sprint_8_Review/prompt_s8r_findings.md.
    - Обе ветки запушены.

  ПОЧИНКА НАХОДОК ЧАСТИ 2 — ВЫПОЛНЕНА 2026-07-31 (см. backlog,
  раздел «Починка находок части 2»). Sprint 9 по-прежнему НЕ стартовать.
    - A1 realized_pnl: закрытие ЛЮБЫМ способом (ручное, close-all,
      остановка сессии) теперь двигает кривую капитала на «Счёте» —
      раньше её двигало только закрытие по SL/TP. 3 failed → 3 passed.
    - A2 дата планировщика → UTC. Смежная проверка: год календаря MOEX
      оставлен БИРЖЕВЫМ (Europe/Moscow) — на UTC 1 января в 00:05 МСК
      загрузился бы уходящий год. 1 failed → 2 passed.
    - B1 оказался ДВУМЯ дефектами: подпись в футере была строкой-
      константой (врала всегда, стенд для этого не нужен), а бейдж
      «ПЕРЕПОДКЛЮЧЕНИЕ» — гонка обработчиков закрытого сокета под
      StrictMode (третий сокет через секунду, живой терялся). 4+3 теста.
      Проверено на ШТАТНОМ стенде :8000/:5173 на копии рабочей БД:
      футер «Активных сессий: 1», бейдж ONLINE, ровно 2 WS-подключения.
      Evidence: screenshots/b1_footer_active_sessions.png. gotcha-52.
    - C1 PositionTracker удалён целиком (все 3 метода мертвы, включая
      четвёртую копию расчёта unrealized). Новый baseline test_trading:
      299 passed. C2 закрыта БЕЗ фикса: и MOEX ISS, и T-Invest отдают
      для SBER lot=1 — посылка «биржевой лот 10» устарела, кэш верен.
    - Блок E (решение заказчика 2026-07-31 «чинить сейчас», 3 находки,
      вскрытые по ходу): дата daily_stats переведена на UTC (писали по
      локальной, читали по UTC — точка графика теряла сегодняшний P&L);
      lot_size из T-Invest берётся у ТОРГУЕМОГО инструмента, а не у
      первого совпадения (у SBER 6 совпадений, у двух lot=10 против
      реального 1 — риск ×10 в sizing); Circuit Breaker считает
      нереализованный P&L на лету — колонку daily_stats.unrealized_pnl
      не заполнял никто, и убыток открытой позиции в дневной лимит
      не попадал вообще.
    - D1 (S8.7 email): заказчик выбрал УТОЧНЕНИЕ ФОРМУЛИРОВКИ пункта
      приёмки, код не тронут. Правки в ui_checklist (обе копии),
      ФТ v2.9 → v3.0, ТЗ v1.9 → v2.0.
    - Код-ревью (4 независимых ревьюера): найден 1 РЕАЛЬНЫЙ дефект в моей же
      свежей правке — футер предпочитал список сессий из store, а тот не
      очищается никогда и вне /trading не обновляется, то есть подпись
      показывала бы устаревшее число. Источник сведён к одному (опрос
      /trading/dashboard), +2 теста. Опасение «N+1 в горячем пути CB»
      проверено ЗАМЕРОМ: добавка ≈1 мс (типично) и ≈2 мс (5 тикеров) при
      бюджете 500 мс. Попутно вскрылось, что нагрузочный стенд
      load_signal_to_order.py вообще не гоняет Circuit Breaker (зовёт
      process_signal без user_id) — заведено в backlog.
    - Гейты: pytest 2338 passed / 1 xfailed / 0 failed, vitest 851/124,
      tsc 0, eslint 0, ruff 0, mypy Success (177 файлов), bandit
      0 medium+, E2E одним прогоном. Stack Gotchas 51 → 52, INDEX v17.
    - Новые находки (в backlog, НЕ чинились): дневной отчёт в Telegram
      считает unrealized без множителя лота; дрейф типа TradingDashboard
      между фронтом и backend; колонка daily_stats.unrealized_pnl стала
      доказуемо мёртвой (удалять миграцией — отдельная задача).

  СВЕДЕНИЕ ВЕТОК И ОСТАТОК ЗАМЕЧАНИЙ — ВЫПОЛНЕНО 2026-08-03
  (ветка s8r/backlog-cleanup-2026-08 от develop 9fc729d; см. backlog,
  раздел «Сведение веток и остаток замечаний»). Sprint 9 НЕ стартовать.

    БЛОК A — ВСЁ СВЕДЕНО, вопрос «а всё ли сведено» закрыт.
    - PR #14 (s8r/tail-fixes → develop) смёржен --no-ff, коммит 9fc729d.
      CI ЗЕЛЁНЫЙ, backend-job реально прогнал 2338 passed / 1 xfailed —
      сверено с локальным baseline. Дерево develop после мержа побайтово
      равно дереву s8r/tail-fixes.
      ⚠️ Красный CI 31 июля был НЕ из-за кода: GitHub Actions вообще не
      стартовал job'ы («spending limit»). Лимит сбросился 1 августа.
    - Остальные 25 удалённых веток кода содержатся в develop целиком
      (проверено git merge-base --is-ancestor по origin/*).
      fix/nightly-pause-resume уже удалена из origin — сводить её было
      нельзя, она возвращала networkidle, убранный closeout'ом (gotcha-46).
    - Документация: docs/sprint-8-review свёрнута в рабочую ветку
      (7434f84, конфликт «add/add» разрешён вручную — сохранены ОБА
      блока карточек), рабочая ветка → main --no-ff (a79b11d).
      docs/s7-chart-drawings-backlog сводить НЕЧЕГО: все 219 её
      уникальных строк уже в актуальном changelog побайтово.
    - Попутно: шапки ФТ и ТЗ отстали от таблиц истории (2.9/1.9 против
      3.0/2.0) — выровнены.

    РЕШЕНИЕ ЗАКАЗЧИКА 2026-08-03: main В РЕПОЗИТОРИИ КОДА НЕ
    РАЗМОРАЖИВАТЬ. Единственная интеграционная ветка кода — develop.
    origin/main отстаёт на 377 коммитов и не используется НАМЕРЕННО.
    Вопрос закрыт, в следующих циклах не поднимать.
    (В репозитории ДОКУМЕНТАЦИИ main разморожен 2026-07-30 — там иначе.)

    БЛОК B — шесть замечаний закрыты test-first:
    - B1 дневной отчёт в Telegram занижал unrealized в lot_size раз
      (для SBER/GAZP — в 10). Переведён на общий хелпер; критерий
      приёмки — согласие ТРЁХ потребителей на одних данных (отчёт,
      get_positions, хелпер Circuit Breaker): 500 ₽ у всех, было 50 ₽
      у отчёта. Побочно исправлено: переходящая со вчера открытая
      позиция раньше в unrealized отчёта не входила вовсе.
    - B2 нагрузочный стенд теперь гоняет Circuit Breaker (раньше не звал
      его вовсе). ⚠️ ПОСЫЛКА ПОСТАНОВКИ БЫЛА НЕВЕРНОЙ, вскрыто код-ревью:
      в рантайме user_id в process_signal НЕ передаётся никогда —
      runtime.py зовёт check_before_order сам, а в process_signal шлёт
      user_id=None, чтобы 9 проверок не отработали дважды. Первая версия
      правки завела бы CB внутрь окна @timed_event, то есть мерила бы
      несуществующий путь. Стенд переписан под порядок рантайма, замеры
      пересняты. Фактическая задержка сигнал→ордер (3 повтора, медиана):
      1 сессия 23,7/24,7 мс, 5 — 51,7/79,0, 20 — 183,0/335,5,
      40 — 407,3/776,7. Вывод по бюджету ТЗ НЕ изменился: потолок ~20
      сессий. Ограничение стенда честное: все сессии одного пользователя,
      делят один per-user лок — сериализация максимальная.

      🔴 ГЛАВНОЕ ВСКРЫТОЕ — НЕ ПРОИЗВОДИТЕЛЬНОСТЬ, А СЛЕПОТА МОНИТОРИНГА.
      Метрика trading.signal_to_order в /admin/metrics ПЛОСКАЯ (6–10 мс)
      на всех уровнях 1/5/20/40, потому что очередь за локом Circuit
      Breaker выстаивается ДО декорированной функции. При 40 сессиях
      дашборд покажет 7,7 мс при фактических 407 мс (p95: 9,7 против 777).
      То есть индикатор насыщения бесполезен и создаёт ложное спокойствие
      ровно тогда, когда бюджет ТЗ уже превышен в полтора раза.
      Заведено S8R-METRIC-SIGNAL-TO-ORDER-BLIND (high) — НЕ чинилось.
    - B3 тип TradingDashboard приведён к DashboardResponse + заведена
      СВЕРКА (backend-тест читает types.ts). Мёртвый store-экшен
      fetchDashboard удалён: он не просто не использовался, а был известен
      как вредный для единственного правдоподобного вызывающего.
    - B4 колонка daily_stats.unrealized_pnl удалена миграцией
      e2f3a4b5c6d7 (идемпотентна, downgrade проверен round-trip тестом).
      deployment_guide.md §7 обновлён синхронно.
    - B5 посылка карточки оказалась НЕВЕРНОЙ и это важнее опечатки:
      в paper-торговле комиссия НЕ УДЕРЖИВАЕТСЯ ВООБЩЕ. FAQ описывал
      списание, которого никогда не происходило. Заведена новая карточка.
    - B6 float-дефолты риск-лимитов → Decimal. RED воспроизвёл ровно тот
      TypeError, что ловил микрозамер прошлого цикла.

    НОВЫЕ НАХОДКИ (в backlog, НЕ чинились):
    - S8R-METRIC-SIGNAL-TO-ORDER-BLIND (high) — см. выше, метрика не видит
      ожидание за локом CB. Кандидат на первую задачу следующего цикла:
      без неё нельзя доверять ни одному будущему замеру производительности.
    - S8R-PAPER-NO-COMMISSION (medium) — paper не удерживает комиссию,
      а бэктест её вычитает, поэтому результат paper систематически
      оптимистичнее бэктеста. Нужно решение заказчика: брать ставку из
      настроек брокера или из параметров сессии.
    - S8R-DAILY-STATS-IDLE-SESSION-HIDDEN (low) — сессия без сегодняшних
      сделок выпадает из дневного отчёта вместе с открытой позицией.
    - S8R-UNIT-TESTS-REACH-NETWORK (medium) — _resolve_lot_size без свежего
      кэша Instrument делает реальный HTTP к MOEX ISS, поэтому тесты
      test_engine_sandbox_flow.py уходят в сеть. ВОСПРОИЗВЕДЕНО: полный
      прогон дал 1 failed (test_paper_does_not_call_adapter), повтор того
      же прогона — 2352 passed, файл изолированно — 13 passed. Флейк
      порядко/таймингозависимый. Маскирует настоящие регрессии в CI.

    КОД-РЕВЬЮ (5 независимых ревьюеров): найден 1 РЕАЛЬНЫЙ дефект в моей
    же свежей правке — B2 чинился по неверной посылке постановки. Два
    ревьюера независимо показали, что runtime зовёт process_signal с
    user_id=None намеренно. Исправлено, замеры пересняты. Плюс уточнена
    неточность моего комментария про переходящую позицию.

    Гейты: pytest 2352 passed / 1 xfailed / 0 failed (было 2338, +14
    новых), vitest 850/124 (было 851 — минус удалённый тест мёртвого
    экшена, новый baseline 850), tsc 0, eslint 0, ruff 0, mypy Success
    (177 файлов), bandit 0 medium+, E2E 162 passed / 3 skipped / 0 failed
    одним прогоном. Stack Gotchas 52, INDEX v17 — новых нет.

  ЗЕЛЁНЫЙ CI, НАБЛЮДАЕМОСТЬ И ОСТАТОК НАХОДОК — ВЫПОЛНЕНО 2026-08-03
  (ветка s8r/ci-green-2026-08 от develop 7c5a718; см. backlog, раздел
  «Зелёный CI, наблюдаемость и остаток находок»). Sprint 9 НЕ стартовать.
  Ответы заказчика: Q1=b, Q2=a, Q3=a, Q4=c (ретроактивно нет), Q5=a,
  Q6=все, Q7=a, Q8=b, Q9=рекомендованные, Q10 = пуш по команде.

    БЛОК 1 — ЗЕЛЁНЫЙ CI.
    - PR #15 (s8r/backlog-cleanup-2026-08 → develop) смёржен --no-ff,
      коммит 7c5a718. CI зелёный, backend-job РЕАЛЬНО прогнал тесты:
      2352 passed / 1 xfailed — совпало с локальным baseline.
    - Q1=b: nightly ПОДНИМАЕТ backend (deps + alembic upgrade head +
      uvicorn + посев e2e_auth через /auth/setup). Две неочевидности:
      DEBUG=true обязателен (иначе auth-cookie уходят с флагом Secure и
      браузер по http их не сохраняет — противоположно ci.yml), и
      LOGIN_RATE_LIMIT_PER_MINUTE=1000 (штатные 5/мин рассчитаны на
      человека; сюита логинится 6 раз, а retries=2 умножает втрое →
      429 выглядел бы как дефект продукта). При падении job выкладывает
      лог backend'а артефактом.
    - Q2=a: autouse-фикстура режет исходящий httpx во всех unit-тестах.
      Вскрыла 22 теста в ЧЕТЫРЁХ файлах (постановка ожидала 13 в одном).
      Все закрыты посевом кэша Instrument. RED 12 failed → GREEN 0 failed.
      lot_size=1 в посеве — фактический ответ ISS (совпадает с выводом
      C2 от 2026-07-31: и ISS, и T-Invest отдают для SBER lot=1).

    БЛОК 2 — НАБЛЮДАЕМОСТЬ (Q3=a). Заведена ВТОРАЯ метрика
    trading.signal_to_order_full (полное окно, включая ожидание за локом
    Circuit Breaker); старая не тронута — исторические замеры блока F
    остаются сопоставимыми. Новый контекстный менеджер timed_block:
    декоратором эту границу задать нельзя. На /admin/metrics полное окно
    выводится ПЕРВЫМ (доп. вопрос Q3 остался без ответа — решение
    принято исполнителем).
      Замеры (3 прогона, медиана): при 40 сессиях старая метрика
      7,2 / 9,0 мс, новая 407,2 / 764,4 мс при факте 406,9 / 764,4 мс.
      Новая совпадает с секундомером стенда — граница проведена верно.
      Вывод по бюджету ТЗ §4 не изменился (потолок ~20 сессий);
      изменилось то, что это видно на дашборде.

    БЛОК 3 — ФУНКЦИОНАЛЬНЫЕ ПРАВКИ.
    - Q4: paper удерживает комиссию по ставке сессии (новое поле
      commission_pct, миграция b7c8d9e0f1a2, поле «Комиссия, %» в модалке
      запуска, дефолт 0,05 % — как у бэктеста). Удержание с КАЖДОЙ
      стороны, включая закрытие по SL/TP. Колонка live_trades.commission
      впервые получила писателя. Критерий приёмки выполнен НА ЧИСЛАХ:
      backtrader 101 949,00 ₽ против paper 101 949,00 ₽, расхождение 0,00.
      Инвариант BE-TRAD-06 уточнён: Δequity == trade.pnl − commission
      (при нулевой ставке вырождается в прежний). Ретроактивно НЕ
      удерживаем — дефолт в модели ноль.
    - Q5: дневной отчёт включает сессии с открытой позицией без
      сегодняшних сделок. Сессия без позиций строки не получает,
      итог не задваивается. RED 2 failed → GREEN 4 passed.

    БЛОК 4 — МЕЛОЧИ (Q6 = все). noqa убрана (ruff без предупреждений);
    версии actions СВЕРЕНЫ через GitHub API, а не по догадке (checkout@v7,
    setup-node@v7, setup-python@v7, cache@v6, upload-artifact@v7,
    pnpm/action-setup@v6); в ФТ сноска про удалённый PositionTracker.

    ⚠️ ДЕФЕКТ, ПОЙМАННЫЙ СОБСТВЕННЫМ ПРОГОНОМ: первая версия миграции
    получила id a1b2c3d4e5f6, уже занятый другой ревизией. Alembic молча
    завёл вторую голову — 6 failed в тестах миграций. Переименовано в
    b7c8d9e0f1a2, добавлен round-trip тест. Урок: после ручного id —
    обязательно alembic heads.

  РАНЕЕ (2026-07-30): коммиты по итогам цикла.
    - Удалить мёртвую ветку (команда агенту заблокирована permission-правилом):
      git -C Develop branch -D s8r/merge-to-develop
      Безопасность проверена: её единственный коммит вне develop — merge,
      чьё разрешение конфликта побайтово совпадает с origin/develop.
    - Worktree auth-hardening и основной чекаут Develop/ (на p1/wave2-backend)
      — решение не принималось.
    - Старт Sprint 9 — НЕ стартовать (решение заказчика).

  РЕШЕНО ЗАКАЗЧИКОМ 2026-07-30:
    - Ветка s8r/merge-to-develop удалена.
    - Коммиты сделаны: код s8r/tail-fixes 2f1a180, документация
      docs/backlog-006-strategy-builder a598e7f. НЕ запушены.
    - ПОТОЛОК ПРОИЗВОДИТЕЛЬНОСТИ РАЗДЕЛЁН НАДВОЕ. Цель ТЗ «signal→order
      p95 < 500 мс» держится до ~20 одновременных сессий, при 40
      нарушается в 1,7×. Причина архитектурная: у SQLite один писатель,
      БД в WAL с busy_timeout=30000, поэтому конкурирующие транзакции
      ЖДУТ, а не падают (деградация тихая, в виде задержки).
        * Переход на более производительную СУБД → SPRINT 9, не трогаем.
        * Сокращение пишущих транзакций внутри текущей архитектуры →
          ТЕКУЩИЙ ЦИКЛ, три меры (блок F постановки):
            F1 — схлопнуть два commit в один на paper-пути;
            F2 — DailyStat через атомарный upsert вместо read-then-write;
            F3 — убрать лишние refresh (кандидат, требует проверки).
          Требование заказчика: реализовать все три и ОЧЕНЬ ТЩАТЕЛЬНО
          проверить, что ничего не сломалось, в т.ч. Playwright и E2E.
      Не противоречит решению от 2026-06-11 «багфиксы — в цикле приёмки,
      не в S9»: миграция СУБД это развитие, сокращение транзакций —
      доведение.
      ⚠️ Обязательный порядок: замер «до» → профилирование → фиксы →
      замер «после». Раскладку по конкретным записям НИКТО не
      профилировал (вывод получен косвенно). Измерения сняты в paper —
      без gRPC к брокеру, то есть это ПОЛ, а не полное время. Если
      выигрыш не подтвердится замером — меру откатить.
      ⚠️ E2E идёт на моках и backend'ову семантику событий НЕ проверяет:
      зелёный прогон сам по себе не доказывает, что F1 ничего не сломал.
      Нужна живая проверка на стенде через Playwright.
    - Четыре новые находки чинятся в следующем цикле, не откладываются.
      Постановка — Sprint_8_Review/prompt_s8r_tail2.md, блок D.
      Порядок работы в следующем цикле: D → E → F.

  ОСТАЁТСЯ ПРОВЕРИТЬ В ПРОДЕ (не задачи цикла, уже в backlog):
    - живые p50/p95 «сигнал→ордер», «Telegram-команда», «загрузка дашборда»
      под нагрузкой — Dash сейчас на mock-данных;
    - повтор S8.7 «реальная сделка → уведомление в 3 канала» в торговые часы;
    - развёртывание с нуля по deployment_guide.md — миграция d1e2f3a4b5c6 чинила
      ровно этот сценарий, но живой прогон установки на чистой машине не делался;
    - разовый drain paper-сессий при выкатке (deployment_guide §7).

ИСТОРИЯ: Sprint 8 — 🏁 ЗАКРЫТ (2026-05-13). M4 Production-ready достигнут.

  Sprint 8 закрыт за 2 рабочих дня (12-13.05) в формате 4-волнового спринта:
    W0 ARCH-design (1 день) → W1 (4 потока) → W2 (4 потока + QA) → W3 (4 потока) → 8.R.

  ARCH 8.R вердикт: PASS WITH NOTES.
    - 0 блокеров production rollout.
    - 18 carry-over карточек для W4 (6 medium + 11 low + 2 informational).
    - Все non-blockers.

  M4 Production-ready критерии — выполнение:
    1. Coverage ≥ 80% по каждому модулю          ✅ 84.83% TOTAL + CI gate
    2. Security audit                              ✅ 3 high закрыты + bandit/safety в CI
    3. Performance testing                         ⚠️ инфра готова (@timed_event), p95 → W4 (S8R-W4-PERF-BASELINE-MEASUREMENTS)
    4. E2E регрессия + 6 missing spec'ов          ✅ 158 passed + 5 skipped → W4 (S8R-W4-E2E-ANALYTICS-UNSKIP)
    5. Закрытие S8 backlog                         ✅ medium-high 100%, medium 90%+
    6. UX финальный юзабилити-тест                 ✅ 6 сценариев + 12 скриншотов
    7. Документация                                ✅ deployment_guide v1.0 + FT v2.5 + TS v1.5
    8. 8.R финальное ARCH-ревью + sign-off         ✅ PASS WITH NOTES

  Финальные тестовые метрики:
    - Backend pytest: 1490 passed / 0 failed @ 84.83% coverage
    - Frontend vitest: 558 passed / 2 pre-existing flaky
    - Playwright nightly: 158 passed / 5 skipped / 1 flaky
    - Frontend lint: 0 errors / 0 warnings (--max-warnings 0)
    - Frontend tsc + Backend ruff + mypy: 0 issues
    - Bandit: 0 medium+ / Safety: 1 documented CVE

СЛЕДУЮЩЕЕ ДЕЙСТВИЕ: Коммит / push / тег

  1. Заказчик подтверждает финальные коммиты в обе ветки:
     - test-репо (docs/sprint-8): документация W3 + 4 W3 reports + ARCH report
       + sprint_state + changelog + project_state + ui_checklist + screenshots + ФТ/ТЗ/dev_plan.
     - Develop-репо (s8/sprint-8): W3 код (lint cleanup + status enum drift + paused filter
       + bg autocollapse + health WS + Histogram tooltip + dashboardFilters refactor) +
       OPS (Docker compose + Dockerfile + nginx + launchd + CI gate + Node 24) +
       6 stack_gotchas (+ gotcha-32 W3) + INDEX + .coveragerc + CLAUDE.md polish + INSTALL.md.
  2. Push'ы на origin (после подтверждения).
  3. Опционально: создать тег `v1.0-m4-production-ready` (по команде заказчика).

ВЕТКИ НА КОНЦЕ S8:
  - Корневой Test: docs/sprint-8 (HEAD после W3 финализации).
  - Develop/: s8/sprint-8 (HEAD после W3 финализации).

W4 ✅ ЗАВЕРШЕНО (2026-05-13): 12/18 carry-over + 1 partial.
W5 ✅ ЗАВЕРШЕНО (2026-05-13): оставшиеся 7/7 закрыты внутри текущего спринта:
  - S8R-W5-DOCKER-COMPOSE-VALIDATE — BLOCKED (нет docker CLI; смок при первом деплое).
  - S8R-W5-PLAYWRIGHT-NIGHTLY-RERUN — 160 passed / 1 flaky / 3 skipped.
  - S8R-W5-TEST-EVENT-DELIVERY-FIX-FIXTURES — passthrough fixture, 21 passed.
  - S8R-W5-COV-MARKET-DATA-SERVICE — 78% → 83%.
  - S8R-W5-COV-STRATEGY-SERVICE — 68% → 97%.
  - S8R-W5-PERF-BASELINE-MEASUREMENTS — pytest-benchmark + 4 теста.
  - S8R-W5-MULTICURRENCY-TOGGLE — Mantine SegmentedControl RUB/USD.

СЛЕДУЮЩЕЕ ДЕЙСТВИЕ: W5 push + тег update
  1. Push W5 в обе ветки (docs/sprint-8 + s8/sprint-8).
  2. Тег v1.0-m4-production-ready — либо переместить на W5-коммит (force-push),
     либо создать v1.1-m4-production-ready (по решению заказчика).
  3. Sprint_8_Review — финальная приёмка решений, без переносов.
```

## Ключевые решения (кросс-спринтовые)

_Решения, влияющие на несколько спринтов:_

| # | Дата | Решение | Влияет на | Принято кем |
|---|------|---------|-----------|-------------|
| 1 | 2026-03-24 | Sidebar сворачиваемый 240→60px | S1-S8 | Заказчик |
| 2 | 2026-03-24 | Footer с динамическим статус-баром 32px | S1-S2 | Заказчик |
| 3 | 2026-03-24 | Таблица с раскрываемыми строками (Вариант Б) | S1-S3 | Заказчик |
| 4 | 2026-03-24 | Тикеры с цветными иконками | S1 | Заказчик |
| 5 | 2026-03-27 | Бэктест нельзя запустить если: код устарел (блоки ≠ код) ИЛИ код содержит ошибки. Кнопка «Запустить бэктест» disabled + tooltip с причиной | S4-S5 | Заказчик |

## Обязательные проверки будущих спринтов

### S7 — ARCH-задача: подключение оставшихся event_type к runtime

После завершения всех DEV-задач S7 архитектор **обязан** проверить, что следующие 5 типов уведомлений подключены к реальным runtime-событиям через `create_notification`:

| event_type | Что нужно | Источник события |
|------------|-----------|-----------------|
| `trade_opened` | EVENT_MAP: маппинг на открытие позиции | `trading/runtime.py` или `engine.py` |
| `partial_fill` | Частичное исполнение ордера | `trading/engine.py` → OrderManager |
| `order_error` | Ошибка выставления ордера | `trading/engine.py` → OrderManager |
| `all_positions_closed` | Все позиции закрыты | `trading/engine.py:681` (event уже есть, нет `create_notification`) |
| `connection_lost` / `connection_restored` | Потеря/восстановление gRPC-соединения | `broker/tinvest/multiplexer.py` (reconnect loop) |

Механизм доставки (in-app + Telegram + Email) работает для всех 13 типов — подтверждено тестом `test_dispatch_all_events.py` (14 passed). Нужно только подключить источники.

### S8 Review — обязательный чеклист: верификация всех обработчиков событий

В рамках Sprint_8_Review (M4: Production) **включить** следующую проверку:

- [ ] Все 13 event_type из `NotificationSettingsPage` реально генерируют уведомления при соответствующих runtime-событиях
- [ ] Для каждого event_type: включить Telegram + Email в настройках → вызвать событие → проверить доставку во все 3 канала
- [ ] Тест `test_dispatch_all_events.py` проходит (unit — механизм доставки)
- [ ] E2E или интеграционный тест: реальный сценарий (бэктест → notification → Telegram/Email) работает

### Post-Sprint — планы на развитие

Подробные описания вынесены в `Спринты/Планы на развитие/`. Краткий реестр: [README.md](Планы на развитие/README.md).

## Технический долг

_Накапливается по мере продвижения, берётся из sprint_report.md:_

| # | Спринт | Описание | Приоритет | Статус |
|---|--------|----------|-----------|--------|
| 1 | S1 | Footer со статическими данными | Low | Отложено (не критично) |
| 2 | S4 | 30+ E2E тестов S4 падают | ~~High~~ | ✅ **Закрыт S5R.4** (DEV-1 волна 2, 102 passed / 0 failed после closeout) |
| 3 | S5 | Реальные позиции/операции T-Invest | ~~Medium~~ | ✅ **Закрыт S5R.3** + S5R closeout #9 (FIGI source-правило вместо ticker) |
| 4 | S5 | Live Runtime Loop не замкнут | ~~High~~ | ✅ **Закрыт S5R.2** (DEV-2, `runtime.py:374` — единственная production-точка `process_candle`) |
| 5 | S1-S5 | CI красный 11+ дней | ~~High~~ | ✅ **Закрыт S5R.1** (DEV-1 волна 1+1b, зелёный CI, 13 Stack Gotchas) |
| 6 | S5R closeout | Schema drift в БД (forward model drift) | ~~Medium~~ | ✅ **Закрыт S5R closeout #11** (миграция `0896e228f3ed_schema_drift_sanitizer`) |
| 7 | S5R closeout | E2E зависимость от seed user `sergopipo` | ~~Medium~~ | ✅ **Частично закрыт S5R closeout #10** (5 тестов на моках, остальные ~40 — `S5R-E2E-MOCKS-EXPANSION` в S6) |
| 8 | S5R closeout wave 3 | BacktestResultsPage: кнопка «Запустить торговлю» — заглушка без onClick | ~~Medium~~ | ✅ **Закрыт S5R closeout #12** (подключён LaunchSessionModal с предзаполнением из бэктеста, CSV/PDF → disabled + tooltip про Sprint 7) |
| 9 | S5R closeout wave 3 | tinvest_stream бесконечный reconnect (`'MarketDataStreamService' object has no attribute 'candles'`) | ~~High~~ | ✅ **Закрыт S5R closeout #13** (правильный API `market_data_stream(request_iterator)` через SubscribeCandlesRequest, Gotcha 4 соблюдён) |
| 10 | S5R closeout wave 3 | iss_tail_fetch offset-naive vs offset-aware compare | ~~Low~~ | ✅ **Закрыт S5R closeout #14** (нормализация timestamps ISS к naive UTC) |

**Текущий High-долг: 0.** Все блокеры, выявленные до S5R и в ходе 3 волн closeout, закрыты полностью.

## Перенесённые задачи

_Все 4 перенесённые задачи из S4/S5 закрыты в Sprint_5_Review 2026-04-14:_

| # | Из спринта | Задача | Перенесена в | Статус |
|---|------------|--------|-------------|--------|
| 1 | S4 (техдолг #2) | E2E S4 fix | Sprint_5_Review | ✅ закрыта (S5R.4) |
| 2 | S5 (техдолг #3) | Реальные позиции T-Invest | Sprint_5_Review | ✅ закрыта (S5R.3) |
| 3 | S5 (техдолг #4) | Live Runtime Loop | Sprint_5_Review | ✅ закрыта (S5R.2) |
| 4 | — (новый 14.04) | CI cleanup | Sprint_5_Review | ✅ закрыта (S5R.1) |

## Промежуточные ревью

| Ревью | После спринтов | Milestone | Статус | Отчёт |
|-------|---------------|-----------|--------|-------|
| Sprint_2_Review | S1 + S2 | M1: Каркас | ✅ завершён | Sprint_2_Review/backlog.md |
| Sprint_4_Review | S3 + S4 | M2: Бэктест | ✅ завершён | Sprint_4_Review/backlog.md |
| **Sprint_5_Review** | S5 (внеплановое) | — (стабилизация M3) | **✅ завершён (PASS WITH NOTES)** | **Sprint_5_Review/arch_review_s5r.md** |
| **Sprint_6_Review** | S5 + S6 | **M3: Торговля + Notifications** | **✅ завершён (PASS, 2026-04-24)** | **Sprint_6_Review/code_review.md** |
| **Sprint_7_ARCH (7.R)** | **S7** | **M3 Phase 1 feature-complete** | **✅ завершён (PASS WITH NOTES, 2026-04-26)** | **Sprint_7/arch_review_s7.md** |
| **Sprint_8_Review** | S7 + S8 | **M4: Production** | **✅ завершён (PASS WITH NOTES, 2026-07-26; пять волн доведения, backlog закрыт полностью 2026-07-29)** | **Sprint_8_Review/backlog.md** + `acceptance_checklist.md` |

## Milestones

| Milestone | Спринт | Статус | Критерии |
|-----------|--------|--------|----------|
| M1: Каркас | S1 | ✅ | Auth, дашборд, CI, 68 тестов |
| M2: Бэктест | S4 | ✅ | Стратегия → бэктест → результаты. Ревью: 21/28 задач исправлено, 7 отложено |
| M3: Paper Trading + Notifications | S5 + S6 + Sprint_6_Review | ✅ (2026-04-24) | Paper+Real Trading + Circuit Breaker + Bond НКД + Tax FIFO + Notifications (Telegram/Email/In-app) + Recovery + Graceful Shutdown. 945 тестов + 119 E2E. ARCH: PASS |
| **M3 Phase 1 feature-complete** | **S7** | **✅ (2026-04-26)** | **Версионирование стратегий, Grid Search, экспорт CSV/PDF, drawing tools, дашборд-виджеты, first-run wizard, backup/restore, AI слэш-команды, аналитика бэктеста, фоновые бэктесты, WS-сессии, 5 новых event_type, Telegram callbacks. 1279 unit-тестов (885 backend + 394 frontend) + 136 E2E. ARCH 7.R: PASS WITH NOTES.** |
| **M4: Production-ready** | **S8** | **✅ (2026-05-13)** | **Coverage 84.83% + CI gate, 3 high security fixes (HEADERS/TG-XSS/Email-XSS) + bandit/safety, performance instrumentation `@timed_event`, admin role + Plotly Dash, Docker compose + launchd + Cloudflare Tunnel, deployment_guide v1.0, 1490 backend + 558 vitest + 158 Playwright. ARCH 8.R: PASS WITH NOTES, 0 блокеров.** |

---

## Ссылки

| Документ | Путь |
|----------|------|
| Функциональные требования | Документация по проекту/functional_requirements.md |
| Техническое задание | Документация по проекту/technical_specification.md |
| План разработки | Документация по проекту/development_plan.md |
| Контекст для агентов | Develop/CLAUDE.md |
| Текущий спринт (детали) | Sprint_N/sprint_state.md |

---

## Как продолжить работу (инструкция для новой сессии)

1. Прочитай **этот файл** — пойми, на каком мы спринте
2. Перейди в папку текущего спринта → прочитай **sprint_state.md** — пойми, на каком мы шаге
3. Если нужен порядок работы → прочитай **execution_order.md**
4. Если нужен контекст проекта → прочитай **Develop/CLAUDE.md**
5. Выполни следующее действие из sprint_state.md
