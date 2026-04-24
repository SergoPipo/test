# Sprint 6 — Changelog

> Хронологический журнал выполнения Sprint 6.
> Формат: дата → что изменено → файлы → результат.

---

## 2026-04-24 — DEV-7: E2E S6 + Security testing — Sprint 6 ЗАВЕРШЁН ✅

**Контекст:** Последняя задача Sprint 6 — E2E тесты на новый функционал уведомлений + security тестирование.

**Что сделано:**

*E2E тесты (Playwright) — 10 passed:*
- `s6-notifications.spec.ts` (4): bell counter, drawer, mark-read PATCH, read-all PUT
- `s6-critical-banner.spec.ts` (2): banner visible + dismiss, no banner for non-critical
- `s6-notification-settings.spec.ts` (2): settings table, toggle PUT
- `s6-chart-stability.spec.ts` (2): overlay OHLC stability, D no WS updates

*Security тесты (pytest) — 23 passed:*
- `test_csrf.py` (3): double-submit cookie validation
- `test_rate_limiting.py` (3): brute-force 429, lockout, general limit
- `test_sandbox_escape.py` (14): AST + runtime sandbox restrictions
- `test_notification_security.py` (3): XSS, user isolation, webhook auth

**Файлы:** `frontend/e2e/s6-*.spec.ts`, `backend/tests/test_security/*.py`, `Sprint_6/reports/DEV-7_report.md`
**Итого Sprint 6:** 685 backend + 250 frontend + 10 E2E = **945 тестов, 0 failures**
**Результат:** ✅ Sprint 6 ЗАВЕРШЁН

---

## 2026-04-24 — Фикс: маркеры сделок прыгают при скролле/зуме/смене таймфрейма

**Контекст:** Маркер входа в сделку перескакивал на другую свечу при скролле или зуме графика. Причина: маркер привязывался к sequential индексу (номер в массиве), а при загрузке новых свечей или перестроении mapping индексы менялись.

**Что сделано:**
1. Сделки хранятся в `sessionTradesRef` (timestamps), маркеры пересчитываются из них
2. `rebuildMarkers()` вызывается после каждого `setData()` — позиции пересчитываются по актуальному mapping
3. WS-callback обновляет хранилище сделок и вызывает `rebuildMarkers()`
4. При смене таймфрейма: данные перезагружаются → `setData()` → `rebuildMarkers()` → маркер на правильной свече

**Файлы:** `frontend/src/components/charts/CandlestickChart.tsx`
**Тесты:** tsc 0 errors, Playwright: 0 console errors
**Результат:** ✅

---

## 2026-04-24 — Фикс: маркеры сделок на графике — 3-уровневый дизайн + дедупликация

**Контекст:** Маркеры сделок отображались одной строкой, были мелкими, дублировались на текущем баре из-за WS callback.

**Что сделано:**
1. 3-уровневый маркер: стрелка (цветная, size 3) → Buy/Sell (белый текст) → цена (белый текст)
2. Единый метод `tradeToMarkers()` с `id` на каждом маркере (`entry-{tradeId}-arrow/label/price`)
3. Исторические и WS-маркеры используют одну функцию
4. WS callback — дедупликация по `id`, исключает дубли при повторных событиях

**Файлы:** `frontend/src/components/charts/CandlestickChart.tsx`
**Тесты:** tsc 0 errors
**Результат:** ✅

---

## 2026-04-23 — Docs: секция «Правила использования плагинов» в Develop/CLAUDE.md

**Контекст:** В сессии 22-23.04 ряд ошибок (setMarkers v5, NameError LiveTrade, Decimal→строка, fixedtotal_sum) мог быть предотвращён плагинами Claude Code, но правила их использования не были прописаны.

**Что сделано:**
- Добавлена секция `## 🔌 Правила использования плагинов` в `Develop/CLAUDE.md` (~150 строк)
- Каталог 7 плагинов (typescript-lsp, pyright-lsp, context7, playwright, code-review, frontend-design, superpowers)
- 4 фазы использования: перед кодированием, во время, после (перед коммитом), UI-дизайн
- Матрица «файл → обязательные плагины» для всех модулей проекта
- Fallback-команды при недоступности LSP

**Файлы:** `Develop/CLAUDE.md`
**Результат:** ✅

---

## 2026-04-23 — Фикс: уведомление «восстановлена» показывает неверное время простоя

**Контекст:** При восстановлении сессии уведомление «Время простоя: 22 ч.» считалось от `last_signal_at` или `started_at` — даты запуска сессии, а не реальной остановки. Если сигналов не было — downtime = время жизни сессии.

**Что сделано:**
- Добавлен метод `_get_last_active_time()` — ищет реальный момент последней активности из 4 источников: CB-event, последняя сделка, last_signal_at, started_at (в порядке приоритета, берёт max)
- `restore_all()` использует его вместо `session.last_signal_at or session.started_at`

**Файлы:** `backend/app/trading/runtime.py`
**Результат:** ✅

---

## 2026-04-23 — Фикс: CB trading_hours ставит сессию на постоянную паузу вместо тихого пропуска

**Контекст:** Ночью (06:59 МСК) стратегия генерирует сигнал, CB `_check_trading_hours()` блокирует — но при этом ставит сессию на паузу (`session.status = "paused"`). Утром в 10:00 МСК торги открываются, а сессия остаётся на паузе навсегда. Аналогичная проблема с `cooldown`.

**Что сделано:**
1. Добавлено поле `temporary: bool = False` в `CheckResult` — помечает временные блокировки
2. `_check_trading_hours()` и `_check_cooldown()` возвращают `temporary=True`
3. `check_before_order()`: для temporary — только логирует, НЕ вызывает `_trigger()` (без паузы, без записи CB-события)
4. `_handle_candle()` (runtime): для temporary — НЕ коммитит, НЕ шлёт уведомление в Telegram
5. Сессии восстановлены в `active`

**Файлы:** `backend/app/circuit_breaker/engine.py`, `backend/app/trading/runtime.py`
**Результат:** ✅

---

## 2026-04-22 — График: фильтрация аукционных свечей + маркеры входов/выходов сделок

**Контекст:** 1) Часовой график SBER содержал аукционные свечи (O=H=L=C в 06:00 МСК) — TradingView их не показывает. 2) Маркеры входов/выходов сделок на графике, привязанном к сессии, не загружались из истории — только через WebSocket в реальном времени. 3) Маркеры не имели MSK-смещения, смещаясь на 3 часа от свечей.

**Что сделано:**

*Backend:*
1. Фильтрация аукционных свечей (O=H=L=C) для таймфреймов 1h/4h в `market_data/service.py`

*Frontend (CandlestickChart.tsx):*
2. Загрузка исторических сделок сессии при mount (`tradingApi.getTrades`) — маркеры видны сразу при открытии графика
3. MSK-смещение маркеров (`+3ч`) для соответствия свечам
4. Поддержка sequential mode — поиск ближайшего индекса по timestamp
5. Маркеры входа (▲ Buy / ▼ Sell) с ценой, маркеры выхода (обратная стрелка) для закрытых сделок
6. Реалтайм-обновление маркеров через WebSocket сохранено

**Файлы:** `backend/app/market_data/service.py`, `frontend/src/components/charts/CandlestickChart.tsx`
**Тесты:** tsc 0 errors, service.py syntax OK
**Результат:** ✅

---

## 2026-04-22 — UX: предупреждение при паузе сессии с открытой позицией

**Контекст:** При ручной паузе сессии с открытой позицией пользователь не получал предупреждения о рисках. Позиция оставалась без защиты (стоп-лосс/тейк-профит не мониторятся).

**Что сделано:**
- Создан `PauseConfirmModal` — диалог с тремя вариантами: «Отмена», «Пауза, позицию оставить», «Закрыть позицию и пауза»
- Показывает текущую позицию (тикер, направление, лоты) и предупреждение о рисках
- Если открытых позиций нет — пауза выполняется сразу, без диалога
- Подключён в `SessionCard` и `SessionDashboard`

**Файлы:** `PauseConfirmModal.tsx` (новый), `SessionCard.tsx`, `SessionDashboard.tsx`
**Тесты:** tsc 0 errors
**Результат:** ✅

---

## 2026-04-22 — Фикс: карточка сессии — P&L без unrealized, trades=0, entry 8 знаков

**Контекст:** Карточка показывала P&L=0 при открытой позиции с нереализованным P&L 8.37 ₽, «Сделок: 0» при наличии 1 сделки, entry_price с 8 знаками после запятой.

**Что сделано:**
1. `_fill_session_card_data()` — `total_trades` теперь считает ВСЕ сделки (не только closed), W/L по-прежнему только closed
2. `_fill_session_card_data()` — добавлен расчёт нереализованного P&L: `current_price - entry_price` × lots, добавляется к realized P&L
3. `_fill_session_card_data()` — `entry_price` округляется до 2 знаков (как в `get_positions`)
4. Вынесен метод `_get_last_price()` — получает последнюю цену тикера из OHLCV кеша

**Файлы:** `backend/app/trading/service.py`
**Результат:** ✅ Данные карточки и детальной страницы совпадают

---

## 2026-04-22 — Фикс: торговые часы CB не учитывают вечернюю сессию MOEX

**Контекст:** CB проверка `_check_trading_hours()` блокировала сделки после 18:45 МСК, хотя MOEX имеет вечернюю сессию 19:00-23:50.

**Что сделано:**
- `DEFAULT_TRADING_END` изменён с `time(18, 45)` на `time(23, 50)` в `circuit_breaker/engine.py`

**Файлы:** `backend/app/circuit_breaker/engine.py`
**Результат:** ✅

---

## 2026-04-22 — Фикс: CB-уведомления спамят в Telegram (missing commit)

**Контекст:** Circuit Breaker при срабатывании ставит сессию на паузу (`session.status = "paused"`) через `_trigger()` + `flush()`, но `_handle_candle()` выходит без `commit()`. `async with session_factory()` при выходе делает rollback → сессия остаётся `active` в БД → следующая свеча снова генерирует сигнал → CB снова блокирует → ещё одно Telegram-уведомление. Результат: бесконечный поток `🚨 Circuit Breaker сработал` на каждой свече.

**Что сделано:**
- Добавлен `await db.commit()` в ветке `cb_result.blocked` перед `return` в `_handle_candle()`, чтобы CB-пауза персистилась в БД и прекращала цикл обработки сигналов

**Файлы:** `backend/app/trading/runtime.py`
**Результат:** ✅

---

## 2026-04-22 — Фикс: Decimal-форматирование во всех trading-компонентах + синхронизация данных карточка↔детали

**Контекст:** Pydantic v2 сериализует `Decimal` как строку (`"324.33000000"`), а `String.toLocaleString()` в JS не форматирует числа — возвращает строку как есть. Проблема затрагивала все компоненты торговых сессий: карточки, детальную страницу, таблицы позиций/сделок, статистику. Дополнительно: данные на детальной странице сессии отличались от карточки — `get_session()` не заполнял расширенные поля (trades, position).

**Что сделано:**

*Frontend — Decimal→Number во всех format-функциях и сравнениях:*
1. `SessionCard.tsx` — `formatPnl()`, `formatPrice()`, `pnlColor`, P&L%
2. `SessionDashboard.tsx` — `formatPnl()`, `pnlColor`, `isStopped` (+ suspended)
3. `PositionsTable.tsx` — `formatPrice()`, `unrealized_pnl` сравнение
4. `TradesTable.tsx` — `formatPrice()`, `formatPct()`, `pnl`/`pnl_pct` сравнения
5. `PnLSummary.tsx` — `formatRub()`, `net_pnl` сравнения (цвет линии + метрика)

*Backend — синхронизация данных:*
6. `service.py: get_session()` — добавлен вызов `_fill_session_card_data()` для `SessionResponse` внутри `SessionDetailResponse`, чтобы данные детальной страницы совпадали с карточкой

*Backend — баг:*
7. `engine.py` — опечатка `"fixedtotal_sum"` → `"fixed_sum"` в двух местах

**Файлы:** `SessionCard.tsx`, `SessionDashboard.tsx`, `PositionsTable.tsx`, `TradesTable.tsx`, `PnLSummary.tsx`, `backend/app/trading/service.py`, `backend/app/trading/engine.py`
**Тесты:** tsc 0 errors, service.py syntax OK
**Результат:** ✅

---

## 2026-04-18 — Фикс: бесконечный Loader на странице настроек уведомлений

**Контекст:** При переходе на /notifications → вкладка «Настройки» — бесконечный spinner. Причина: API `GET /notifications/settings` возвращает `[]` для нового пользователя (нет записей UserNotificationSetting в БД), а компонент показывал Loader при `settings.length === 0`.

**Что сделано:**
- Добавлен флаг `settingsLoaded` в `notificationStore` — Loader показывается только до завершения запроса
- При пустом ответе API — отображаются дефолтные настройки (in-app: вкл, telegram/email: выкл)

**Файлы:** `stores/notificationStore.ts`, `pages/NotificationSettingsPage.tsx`
**Тесты:** tsc 0 errors, vitest 250 passed
**Результат:** ✅

---

## 2026-04-18 — Исправление 4 замечаний ARCH-ревью

**Контекст:** ARCH выдал вердикт PASS WITH NOTES — 4 замечания. Заказчик принял решение исправить все сейчас, не переносить в S7.

**Что сделано:**
1. **API prefix mismatch:** `/api/v1/notification` → `/api/v1/notifications` (REST convention). Обновлены URL в тестах router и security.
2. **CriticalBanner:** добавлен `fetchNotifications()` при mount в NotificationBell — баннер теперь появляется при первой загрузке.
3. **SchedulerService:** полная реализация на APScheduler 3.x вместо заглушки. Jobs: sync_moex_calendar (cron 00:05 MSK), detect_corporate_actions (каждые 6ч), schedule_t1_unlock (one-shot). Интеграция в lifespan. 9 тестов. CLAUDE.md обновлён.
4. **Telegram команды:** /balance (баланс счёта), /close <trade_id> (закрыть позицию), /closeall (закрыть все с confirmation). /help обновлён. 9 тестов.

**Тесты:** pytest 703 passed (было 685), vitest 250 passed, ruff 0 errors.
**Результат:** ✅ Все замечания закрыты. Sprint 6 — PASS (чистый, без notes).

---

## 2026-04-17 — Открытие Sprint 6: планирование

**Контекст:** S5R полностью закрыт, S5R-2 идёт параллельно. S6 — «Уведомления + восстановление».

**Что сделано:**
- Создан `execution_order.md` — волновая параллелизация (4 волны, 8 DEV-агентов + ARCH).
- Создан `sprint_state.md` — трекинг состояния по волнам и DEV-агентам.
- Создан `preflight_checklist.md` — baseline проверки backend + frontend.
- Создан `prompt_DEV-0.md` — критич��ский багфикс S6-STRATEGY-UNDERSCORE-NAMES (волна 0, blocker).
- Создан `changelog.md` — этот файл.

**Результат:** ✅ ��ланирование S6 начато, blocker-промпт готов.

---

## 2026-04-17 — Завершение планирования: все промпты S6

**Контекст:** продолжение планирования S6 в новой сессии.

**Что сделано:**
- Создан `prompt_DEV-1.md` — волна 1: In-app WS + Recovery + Graceful Shutdown (NotificationService, REST API, WS bridge, restore_all для real-сессий, shutdown с pending orders).
- Создан `prompt_DEV-2.md` — волна 1: Telegram Bot + Email (TelegramNotifier, webhook, привязка через 6-значный токен, /positions /status /help, EmailNotifier через aiosmtplib).
- Создан `prompt_DEV-3.md` — волна 1: T-Invest SDK upgrade (beta59 → beta117+, инвентаризация breaking changes, удаление sys.modules stub, фиксация в pyproject.toml).
- Создан `prompt_DEV-4.md` — волна 2: Frontend Notification Center (колокольчик + badge, drawer, critical banner, настройки каналов, notificationStore, маршрут /notifications).
- Создан `prompt_DEV-5.md` — волна 2: T-Invest Stream Multiplex (TInvestStreamMultiplexer, persistent gRPC, routing по FIGI, auto-reconnect с exponential backoff).
- Создан `prompt_DEV-6.md` — волна 2: E2E инфраструктура (playwright-nightly.yml cron, моки MOEX ISS для chart-freshness, расширение api_mocks.ts на ~40 тестов).
- Создан `prompt_DEV-7.md` — волна 3: E2E S6 + Security (notifications E2E, CSRF, rate limiting, sandbox escape, notification injection).
- Создан `prompt_ARCH_review.md` — волна 3: финальное ревью + docs update + Stack Gotchas.
- Обновлён `project_state.md` — S6 🔄 в процессе, полная волновая схема.
- Обновлён `execution_order.md` — все чеклисты [x], статус «готов к запуску».

**Файлы:**
- `Sprint_6/prompt_DEV-1.md` .. `Sprint_6/prompt_DEV-7.md` (7 файлов)
- `Sprint_6/prompt_ARCH_review.md`
- `Спринты/project_state.md` (обновлён)
- `Sprint_6/execution_order.md` (обновлён)
- `Sprint_6/changelog.md` (этот файл)

**Следующее действие:** запуск волны 0 — DEV-0 (багфикс S6-STRATEGY-UNDERSCORE-NAMES).

**Результат:** ✅ планирование S6 полн��стью завершено, все 10 промптов готовы.

---

## 2026-04-17 — Волна 1: DEV-1 + DEV-2 + DEV-3 (параллельно)

**Контекст:** Три DEV-агента запущены параллельно после прохождения merge gate 0→1.

**DEV-1 — In-app WS + Recovery + Graceful Shutdown:**
- NotificationService: create_notification, dispatch_external, listen_session_events, stop_listening
- 6 REST endpoints: GET /, GET /unread-count, PATCH /{id}/read, PUT /read-all, GET/PUT /settings
- WS канал `notifications:{user_id}` интегрирован в существующий мультиплексор `/ws`
- Recovery: restore_all расширен для real-сессий (сверка позиций с брокером, расхождения → pause + notification)
- Graceful Shutdown: sessions → "suspended", pending orders timeout 30s, notification "Система остановлена"
- NotificationService интегрирован в lifespan + start_session
- 13 новых тестов

**DEV-2 — Telegram Bot + Email:**
- TelegramNotifier: HTML parse_mode, severity→emoji, inline-кнопки
- TelegramWebhookHandler: /start (привязка 6-значным токеном TTL 5 мин), /positions, /status, /help
- EmailNotifier: SMTP через aiosmtplib, только критические события
- dispatch_external: реальная реализация (TelegramNotifier + EmailNotifier)
- link_store: in-memory хранилище токенов
- config.py: 6 новых полей (TELEGRAM_*, SMTP_*), .env.example обновлён
- 16 новых тестов

**DEV-3 — T-Invest SDK upgrade:**
- SDK 0.2.0b117 зафиксирован в pyproject.toml (тег 0.2.0-beta117)
- sys.modules stub удалён (Gotcha 14 закрыт)
- 4 предсуществующих ruff E402 исправлены в adapter.py
- Breaking changes = 0

**Файлы:** 29 файлов (14 DEV-1 + 12 DEV-2 + 3 DEV-3)
**Тесты:** pytest 654 passed, 0 failed; ruff 0 errors
**Stack Gotchas применённые:** Gotcha 1, 4, 5, 8, 14
**Stack Gotchas новые:** нет
**Результат:** ✅ Волна 1 завершена. Merge gate 1→2 пройден.

---

## 2026-04-17 — Волна 0: DEV-0 S6-STRATEGY-UNDERSCORE-NAMES

**Контекст:** Критический баг — `code_generator.py` генерировал `_`-prefixed имена (`self._entry_order`, `self._sl_order`, `self._tp_order`, `self._is_long`, `_size`), которые RestrictedPython категорически отвергает. Live-сессии не могли генерировать сигналы (~12 000 `strategy_execution_failed` в час).

**Что сделано:**
- Переименованы 5 идентификаторов (~30 замен): `_entry_order` → `entry_order_ref`, `_sl_order` → `sl_order_ref`, `_tp_order` → `tp_order_ref`, `_is_long` → `is_long_pos`, `_size` → `position_size`
- Все 11 существующих тестов `test_code_generator.py` обновлены: `compile()` → `compile_restricted()` (баг больше не проскочит)
- Добавлен E2E тест: полная стратегия (SMA+EMA+crossover+SL+TP+position_size) → `compile_restricted` → assert нет `self._`
- Добавлен тест в `test_executor.py`: реально сгенерированный код проходит sandbox

**Файлы:**
- `Develop/backend/app/strategy/code_generator.py` (модифицирован)
- `Develop/backend/tests/unit/test_strategy/test_code_generator.py` (модифицирован + 1 новый тест)
- `Develop/backend/tests/unit/test_sandbox/test_executor.py` (модифицирован + 1 новый тест)

**Тесты:** pytest strategy 14 passed, sandbox 7 passed, backtest 72 passed (OCO регрессия = 0 failures)
**Stack Gotchas применённые:** Gotcha 2 (CodeSandbox `__import__`), Gotcha 3 (Backtrader OCO)
**Stack Gotchas новые:** нет
**Результат:** ✅ Blocker устранён. Сгенерированный код полностью совместим с RestrictedPython sandbox.

---

## 2026-04-17 — Волна 2: DEV-6 E2E Infrastructure (Playwright Nightly + ISS Mocks + Mocks Expansion)

**Контекст:** E2E инфраструктура требовала трёх улучшений: nightly CI workflow, моки MOEX ISS для 24/7 тестов, миграция ~17 файлов с UI-login на API-моки.

**Что сделано:**
- **6.1 S6-PLAYWRIGHT-NIGHTLY:** Верифицирован `playwright-nightly.yml` — cron `0 7,9,11,13 * * 1-5`, workflow_dispatch, Node 20, pnpm, cache, artifacts. Соответствует спецификации.
- **6.2 S6-E2E-CHART-MOCK-ISS:** Создан `e2e/fixtures/moex_iss_mock.ts` — `generateFreshCandles()` (random walk), `mockMoexCandles()`, `mockMoexCandlesAllTimeframes()`. Свечи генерируются с Gotcha 1 (числа → строки). Переписан `s5-chart-timeframes.spec.ts` — удалён `test.skip("S5R-CHART-FRESHNESS")`, 5 тестов работают 24/7 без MOEX.
- **6.3 S5R-E2E-MOCKS-EXPANSION:** Расширен `api_mocks.ts` на 12 новых хелперов (mockStrategyDetail, mockBacktests, mockTradingSessions, mockTradingTrades, mockCircuitBreakerState, mockAIChat, mockNotifications, mockInstrumentSearch, mockCatchAllApi). Все 20 spec-файлов (105 тестов, 3 skip) переведены на `injectFakeAuth` + моки. 0 файлов требуют `E2E_PASSWORD`.
- Создан `e2e/README.md` — документация паттернов моков.

**Файлы:**
- `Develop/frontend/e2e/fixtures/moex_iss_mock.ts` (создан)
- `Develop/frontend/e2e/fixtures/api_mocks.ts` (расширен +12 хелперов, ~250 строк)
- `Develop/frontend/e2e/s5-chart-timeframes.spec.ts` (переписан)
- `Develop/frontend/e2e/*.spec.ts` (17 файлов мигрированы)
- `Develop/frontend/e2e/README.md` (создан)

**Тесты:** 20 spec-файлов, 105 test(), 3 test.skip(). TypeScript: tsc --noEmit OK.
**Stack Gotchas применённые:** Gotcha 1 (Decimal→str в ISS моках), Gotcha 9 (strict mode — .first() + data-testid), Gotcha 10 (MOEX ISS flaky — ключевая мотивация)
**Stack Gotchas новые:** нет
**Результат:** ✅ Все 3 задачи реализованы. E2E полностью автономны от backend.

---

## 2026-04-18 — Волна 2: DEV-5 T-Invest Stream Multiplex (persistent gRPC)

**Контекст:** `subscribe_candles` создавал отдельный gRPC stream + asyncio.Task на каждую подписку — антипаттерн Gotcha 4, ведущий к 429 Too Many Requests при 5+ торговых сессиях.

**Что сделано:**
- **Верификация multiplexer.py:** удалён мёртвый `_sandbox_mode` property; исправлен баг — backoff delay теперь сбрасывается только после первого успешного response (а не при входе в `async with AsyncClient`); вынесен `_sleep()` для тестируемости.
- **Рефакторинг adapter.py:** удалён `_stream_candles()` inner function и task-per-subscription паттерн. `subscribe_candles` делегирует в `TInvestStreamMultiplexer.subscribe()` через lazy init `_ensure_multiplexer()`. `unsubscribe` делегирует в `multiplexer.unsubscribe()`. Удалены неиспользуемые `import asyncio, uuid`.
- **Public API `subscribe_candles`/`unsubscribe` НЕ изменён** — `StreamManager` не затронут.
- **10 тестов** (6 новых multiplexer + 4 обновлённых adapter): routing, unsubscribe, reconnect, single stream, exponential backoff, active_subscriptions, lazy init, delegation.

**Файлы:**
- `Develop/backend/app/broker/tinvest/multiplexer.py` (модифицирован)
- `Develop/backend/app/broker/tinvest/adapter.py` (модифицирован)
- `Develop/backend/tests/unit/test_broker/test_tinvest_multiplexer.py` (создан)
- `Develop/backend/tests/unit/test_broker/test_tinvest_subscribe_candles.py` (переписан)

**Тесты:** pytest 646 passed, 0 failed; ruff 0 errors
**Stack Gotchas применённые:** Gotcha 4 (tinvest-stream), Gotcha 15 (tinvest-naive-datetime — не затронут)
**Stack Gotchas новые:** нет
**Результат:** ✅ Gotcha 4 устранена. Все подписки через один persistent gRPC stream.

---

## 2026-04-17 — Волна 2: DEV-4 Frontend Notification Center

**Контекст:** Frontend-реализация центра уведомлений: колокольчик, drawer, critical banner, настройки, страница /notifications.

**Что сделано:**
- **NotificationBell** — колокольчик с badge (99+ при >99), WS подписка `notifications:{user_id}`, toast через Mantine notifications.show()
- **NotificationDrawer** — Drawer справа, severity-emoji, relative time (рус.), цветная полоска для непрочитанных, «Прочитать все», «Загрузить ещё»
- **CriticalBanner** — fixed top, красный фон, 30с auto-dismiss, dismiss-кнопка
- **NotificationSettingsPage** — таблица event_type × канал (Telegram/Email/In-app) со Switch
- **Маршрут /notifications** в App.tsx (ProtectedRoute)
- notificationStore проверен — корректен (121 строка)
- 12 новых тестов: 6 store + 4 Bell + 2 Banner

**Файлы:** 11 файлов (6 создано, 2 изменено, 3 проверено без изменений)
**Тесты:** vitest 250 passed, 0 failed
**Stack Gotchas применённые:** Gotcha 9 (strict mode), Gotcha 16 (relogin race)
**Stack Gotchas новые:** нет
**Результат:** ✅ Notification Center полностью реализован

---

## 2026-04-17 — Волна 3: ARCH Review — финальное ревью Sprint 6

**Контекст:** Финальная верификация всех DEV-задач (0–6), baseline, обновление документации, новые Stack Gotchas.

**Что сделано:**
- **R.1 Верификация:** DEV-0..6 — все grep-проверки пройдены, контракты подтверждены (7/7). DEV-7 — pending (отчёт не готов).
- **R.2 Baseline:** pytest 662 passed (+39), vitest 250 passed (+12), Stack Gotchas 17 (+1).
- **R.3 Обновление документации:** ФТ §9, §10, §17.7 — подготовлены для обновления. ТЗ §5.7, §8.6 — подготовлены. development_plan.md §S6 — подготовлен.
- **R.4 Новые Stack Gotchas:** gotcha-17-telegram-bot-frozen-attrs (из DEV-2 report).
- **R.5 Рекомендации S7:** Scheduler Service, pending_events, channelTf validation, Should Telegram commands.
- **R.6 Вердикт:** **PASS WITH NOTES** (DEV-7 pending, Scheduler заглушка).

**Файлы:**
- `Sprint_6/arch_review_s6.md` (создан)
- `Sprint_6/sprint_state.md` (обновлён)
- `Sprint_6/changelog.md` (этот файл)
- `Sprint_6/execution_order.md` (обновлён)
- `Спринты/project_state.md` (обновлён)
- `Develop/stack_gotchas/gotcha-17-telegram-bot-frozen-attrs.md` (создан)
- `Develop/stack_gotchas/INDEX.md` (об��овлён)

**Результат:** ✅ ARCH Review завершён. S6 → PASS WITH NOTES (DEV-7 pending).

---

## 2026-04-18 — Волна 3: DEV-7 QA + Security Testing

**Контекст:** Финальная волна S6 — E2E тесты на Notification Center + Security тесты (CSRF, rate limiting, sandbox escape, notification ACL/XSS/webhook).

**Что сделано:**
- **E2E (Playwright) — 9 тестов:**
  - `s6-notifications.spec.ts` (4): bell badge, drawer open, mark-read PATCH, read-all PUT
  - `s6-critical-banner.spec.ts` (2): critical banner visible + dismiss, non-critical = no banner
  - `s6-notification-settings.spec.ts` (3): settings table, toggle PUT, all event types loaded
- **Security (pytest) — 23 теста:**
  - `test_csrf.py` (3): POST без CSRF → 403, с CSRF → 200, ротация → 403
  - `test_rate_limiting.py` (3): auth brute-force → 429, lockout expiry, general limit
  - `test_sandbox_escape.py` (14): AST — reject import/exec/eval/open/dunder (7); Sandbox — reject import/exec/os/file/underscore + allow safe math/datetime (7)
  - `test_notification_security.py` (3): XSS raw storage, ACL user isolation, webhook secret 403/503

**Проблемы обнаружены:**
- Frontend API prefix mismatch: `notificationApi.ts` → `/notifications`, backend → `/api/v1/notification` (без s)
- CriticalBanner не показывается без открытия drawer (notifications не загружаются автоматически при unread > 0)
- Mantine Switch `<input>` invisible для Playwright — клик через `.mantine-Switch-track`
- Mantine Drawer root `data-testid` резолвится как hidden — scope через children

**Файлы:**
- `Develop/frontend/e2e/s6-notifications.spec.ts` (создан)
- `Develop/frontend/e2e/s6-critical-banner.spec.ts` (создан)
- `Develop/frontend/e2e/s6-notification-settings.spec.ts` (создан)
- `Develop/backend/tests/test_security/__init__.py` (создан)
- `Develop/backend/tests/test_security/test_csrf.py` (создан)
- `Develop/backend/tests/test_security/test_rate_limiting.py` (создан)
- `Develop/backend/tests/test_security/test_sandbox_escape.py` (создан)
- `Develop/backend/tests/test_security/test_notification_security.py` (создан)
- `Спринты/Sprint_6/reports/DEV-7_report.md` (создан)

**Тесты:** E2E 9 passed / 0 failed; pytest security 23 passed / 0 failed; ruff 0 errors
**Stack Gotchas применённые:** Gotcha 9 (Playwright strict), Gotcha 10 (MOEX ISS flaky)
**Stack Gotchas новые (кандидаты):** Mantine Switch E2E (hidden input), Mantine Drawer visibility (root hidden)
**Результат:** ✅ DEV-7 завершён. 32 теста, все зелёные.

---

## 2026-04-22 — Расширенные карточки торговых сессий + фикс live-торговли

**Контекст:** Торговые сессии не открывали сделок (backtrader-код не исполняется в sandbox, CB cooldown блокировал, стрим свечей не запускался). Карточки сессий показывали только тикер и 0₽.

**Что сделано:**

1. **Sandbox-конвертер backtrader→sandbox (engine.py):** `_blocks_to_sandbox` парсит Blockly-дерево, извлекает индикаторы (RSI/SMA/EMA) и условия (condition_compare), генерирует sandbox-скрипт с `print("buy"/"sell"/"hold")`. RestrictedPython-совместимый (без sum/max/min/list).

2. **Запуск стрима свечей при старте сессии (runtime.py):** `stream_manager.subscribe()` вызывается при `runtime.start()` — свечи поступают в EventBus канал `market:TICKER:TF` без необходимости открывать график.

3. **Фикс CB cooldown (engine.py + runtime.py):** `last_signal_at` обновляется **после** успешного создания сделки (не до CB-проверки). Первый сигнал больше не блокируется cooldown-ом.

4. **Восстановление suspended-сессий (main.py + runtime.py):** `suspended` → `active` при рестарте. Lifespan запрашивает сессии с status IN (active, paused, suspended).

5. **Расширенные карточки сессий (SessionCard.tsx + service.py + schemas.py):**
   - Позиция: Long/Short + лоты + цена входа
   - P&L с знаком (+/-)
   - Сделок: N (WW / LL), Win Rate %
   - Последний сигнал: ЧЧ:ММ
   - Polling 10 сек (TradingPage.tsx)

6. **Фикс _-prefix в сохранённых стратегиях:** 23 версии обновлены в БД (`_size` → `position_size`).

7. **Удаление suspended-сессий (service.py):** `delete_session` принимает status `stopped` и `suspended`.

8. **Планы на развитие:** создан `005_realtime_trading_session_updates.md` — WS-обновление карточек сессий (вместо polling).

**Файлы:**
- `Develop/backend/app/trading/engine.py` (_blocks_to_sandbox, _condition_to_expr, last_signal_at fix)
- `Develop/backend/app/trading/runtime.py` (stream_manager.subscribe, _resolve_broker_credentials, suspended→active)
- `Develop/backend/app/trading/service.py` (_fill_session_card_data, delete suspended)
- `Develop/backend/app/trading/schemas.py` (новые поля SessionResponse)
- `Develop/backend/app/main.py` (suspended в lifespan query)
- `Develop/frontend/src/api/types.ts` (новые поля TradingSession)
- `Develop/frontend/src/components/trading/SessionCard.tsx` (расширенная карточка)
- `Develop/frontend/src/pages/TradingPage.tsx` (polling 10 сек)
- `Спринты/Планы на развитие/005_realtime_trading_session_updates.md` (создан)

**Результат:** ✅ Сделки создаются, карточки отображают позиции и статистику.

---

## 2026-04-21 — Удалена кнопка gap/без gap, фикс дёргающейся D-свечи

**Контекст:** Кнопка переключения sequential/real-time режима запутывала пользователя, показывала некорректные метки. Дневная свеча дёргалась из-за пересборки из 1m-данных при каждом запросе.

**Что сделано:**
1. **Кнопка gap/без gap удалена (ChartPage.tsx):** sequential mode теперь всегда включён для intraday (1h/4h/5m/15m/1m) — бары идут подряд без ночных разрывов. Для D/W/M — обычный режим.
2. **Дёргающаяся D-свеча (service.py):** `_build_current_candle` из 1m-агрегации теперь вызывается только для 1h и 4h. Для D/W/M — T-Invest отдаёт актуальную свечу напрямую, 1m-агрегация не используется (устраняет дрожание OHLC).
3. **Метки времени (CandlestickChart.tsx):** `regularFormatter` с `timeZone: 'UTC'` — корректное отображение MSK-времени без двойного сдвига.

**Файлы:**
- `Develop/frontend/src/pages/ChartPage.tsx` (удалена кнопка, удалён state sequentialPref)
- `Develop/backend/app/market_data/service.py` (_build_current_candle только для 1h/4h)
- `Develop/frontend/src/components/charts/CandlestickChart.tsx` (regularFormatter timeZone UTC)

**Результат:** ✅

---

## 2026-04-21 — PriceAlertMonitor подключён + метки времени + удаление алертов

**Контекст:** Ценовые оповещения не срабатывали — PriceAlertMonitor существовал, но не был подключён ни к одному процессу. Также: метки времени на графике показывали Unix-числа; не было UI для удаления алертов.

**Что сделано:**
1. **PriceAlertMonitor подключён (market_data/router.py):** при каждом запросе GET /candles проверяется последняя свеча против активных алертов. При срабатывании: `is_active=False`, создаётся notification через NotificationService (in-app + Telegram + Email).
2. **PriceAlertMonitor → NotificationService (price_alert_monitor.py):** `_create_notification` теперь использует `NotificationService.create_notification()` вместо прямого INSERT — уведомления отправляются во все каналы.
3. **Метки времени (CandlestickChart.tsx):** явный `regularFormatter` для обычного режима — ДД.ММ ЧЧ:ММ для intraday, ДД.ММ для daily+.
4. **Удаление алертов (ChartPage.tsx):** оранжевые бейджи с ценой и кнопкой удаления (IconBellOff) рядом с кнопкой создания.

**Файлы:**
- `Develop/backend/app/market_data/router.py` (alert check на GET /candles)
- `Develop/backend/app/market_data/price_alert_monitor.py` (NotificationService вместо прямого INSERT)
- `Develop/frontend/src/components/charts/CandlestickChart.tsx` (regularFormatter)
- `Develop/frontend/src/pages/ChartPage.tsx` (alert badges + deleteAlert)

**Результат:** ✅

---

## 2026-04-21 — Фикс: intraday gap detection, suspended sessions, failed backtest в дашборде

**Контекст:** Три бага обнаружены при ручном тестировании.

**Что сделано:**

1. **Intraday gap detection (market_data/service.py):** `_find_gaps()` для 1h/4h/1m/5m/15m использовал `mid_tolerance = 1.5 × duration` — каждый ночной перерыв MOEX (~12ч) детектировался как "пропуск" и запускал запрос к T-Invest API. Для 6 месяцев на 1h это ~175 лишних API-вызовов, бэктест загружал данные 7+ минут вместо секунд. Исправлено: tolerance учитывает ночной/выходной перерыв MOEX (1h → 65ч, 4h → 16ч, 1m/5m/15m → 14ч).

2. **Suspended sessions (trading/runtime.py + frontend):** Graceful Shutdown ставил сессии в статус `suspended`, но при рестарте backend они не переводились в `stopped`. Результат: кнопка "Стоп" видна для остановленных сессий, фильтр "Остановленные" не находит их. Исправлено: `restore_all()` переводит `suspended` → `stopped`; frontend трактует `suspended` как `stopped` для кнопок и фильтров; вкладка "Завершённые" → "Остановленные" (соответствует бейджу "Остановлена").

3. **Failed backtest в дашборде (strategy/service.py):** `latest_bt_by_ticker` брал самый свежий бэктест по дате, включая failed. LKOH показывал "20.04" без PF/DD (из failed бэктеста). Исправлено: фильтр `bt_row.status == "completed"`.

**Файлы:**
- `Develop/backend/app/market_data/service.py` (intraday tolerance)
- `Develop/backend/app/trading/runtime.py` (suspended → stopped)
- `Develop/backend/app/strategy/service.py` (only completed backtests)
- `Develop/frontend/src/components/trading/SessionCard.tsx` (isStopped logic)
- `Develop/frontend/src/components/trading/SessionList.tsx` (фильтр + название вкладки)

**Результат:** ✅

---

## 2026-04-21 — Уведомление backtest_completed + зависимости + Playwright CI fix

**Контекст:** При завершении бэктеста не создавалось уведомление (Telegram/Email/In-app). Также backtrader и pandas были потеряны из venv (не были в pyproject.toml). Playwright nightly CI падал из-за отсутствия версии pnpm.

**Что сделано:**
1. **backtest_completed notification:** в `backtest/router.py` добавлен вызов `NotificationService.create_notification()` после успешного завершения бэктеста. Текст: тикер, таймфрейм, P&L%, кол-во сделок, Sharpe. Severity: success (P&L ≥ 0) или warning (P&L < 0). Related entity: backtest.
2. **pyproject.toml — 6 зависимостей:** backtrader, pandas, TA-Lib, apscheduler, python-telegram-bot, aiosmtplib — больше не теряются при переустановке venv.
3. **Playwright nightly:** добавлен `version: 9` в `pnpm/action-setup@v4` (ошибка "No pnpm version is specified").
4. **Develop/CLAUDE.md:** секция «Зависимости НЕ в pyproject.toml» заменена на «Системные зависимости» (только libta-lib и особенности tinkoff-investments).
5. **Тест dispatch_all_events:** 14 тестов — каждый из 13 event_type проходит через create_notification → dispatch_external (Telegram + Email). Подтверждает, что механизм доставки работает для всех типов.

**Файлы:**
- `Develop/backend/app/backtest/router.py` (notification при backtest completed)
- `Develop/backend/pyproject.toml` (+6 зависимостей)
- `Develop/backend/app/config.py` (дефолт SMTP_PORT 465)
- `Develop/.github/workflows/playwright-nightly.yml` (pnpm version: 9)
- `Develop/CLAUDE.md` (обновлена секция зависимостей)
- `Develop/backend/tests/unit/test_notification/test_dispatch_all_events.py` (создан, 14 тестов)

**Карта покрытия event_type (8/13 подключены к runtime):**
- ✅ trade_closed, cb_triggered, session_recovered, backtest_completed, daily_stats, corporate_action, price_alert, system_shutdown
- ⚠️ trade_opened, partial_fill, order_error, all_positions_closed, connection_lost/restored — EVENT_MAP не содержит маппинг или runtime не публикует событие → задача S7

**Тесты:** pytest 14 passed (dispatch_all_events)
**Результат:** ✅

---

## 2026-04-20 — Фикс: SMTP email-уведомления не отправлялись

**Контекст:** Кнопка «Отправить тестовое письмо» зависала бесконечно. Диагностика: ISP блокирует SMTP на портах 587 (STARTTLS) и 465 (SSL) для Gmail через DPI. При этом Yandex SMTP (587) работает, а Gmail SMTP на порту 465 — работает без VPN (ISP блокирует выборочно, не все серверы/порты одинаково). Порт 465 с прямым SSL оказался рабочим.

**Что сделано:**
1. **Таймаут aiosmtplib:** добавлен `timeout=15` в `aiosmtplib.send()` — запрос больше не зависает бесконечно, возвращает ошибку через 15 сек
2. **Авто-выбор TLS-режима:** `use_tls=True` для порта 465 (прямой SSL), `start_tls=True` для остальных портов — один код работает с обоими вариантами
3. **Дефолт порта:** `config.py` `SMTP_PORT` изменён с 587 → 465
4. **`.env`:** обновлён `SMTP_PORT=465`

**Файлы:**
- `Develop/backend/app/notification/email.py` (таймаут + авто TLS)
- `Develop/backend/app/config.py` (дефолт 465)

**Результат:** ✅ Тестовое письмо отправлено и получено на почту.

---

## Шаблон для будущих записей

```
## YYYY-MM-DD — Волна N: <название>

**Контекст:** ...
**Что сделано:**
- ...
**Файлы:** ...
**Тесты:** ...
**Stack Gotchas применённые:** ...
**Stack Gotchas новые:** `gotcha-NN-*.md` (если есть)
**Результат:** ✅/⚠️/❌
```
