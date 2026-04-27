# Sprint 8 Review — Backlog

> Карточки переносов из Sprint 7 (skip-тикеты, deferred-задачи).

---

## S7R-PDF-EXPORT-INSTALL — ✅ DONE 2026-04-26 — установлен в среде разработки, проверен endpoint

- **Источник:** Sprint 7, BACK2 W2, задача 7.3 (CSV/PDF export бэктеста).
- **Закрыто:** Sprint 7, OPS W2 fix-волна (2026-04-26).
- **Что было сделано (фактически):**
  1. ✅ `weasyprint>=60` добавлен в `Develop/backend/pyproject.toml` (`[project] dependencies`).
     Установлено в `.venv`: weasyprint 68.1 (+ Pillow 12.2.0, Pyphen 0.17.2, brotli, cssselect2,
     fonttools, pydyf, tinycss2, tinyhtml5, webencodings, zopfli).
  2. ✅ Системные зависимости (pango 1.57.1, cairo 1.18.4, gdk-pixbuf 2.44.5, libffi)
     уже установлены через brew; в `setup_macos.sh` секция 8 «Зависимости для WeasyPrint»
     корректно их перечисляет (изменений не потребовалось).
  3. ✅ В `tests/unit/test_backtest/test_export.py` ветка `pytest.skip("weasyprint installed")`
     удалена. Negative-path переписан через monkey-patch `sys.modules["weasyprint"] = None`
     (стабилен в любом окружении). Добавлены 2 positive-path теста:
     - `test_generate_pdf_produces_valid_pdf_bytes` (unit, проверка `%PDF-` magic-bytes).
     - `test_export_pdf_endpoint_returns_pdf_bytes` (HTTP, проверка 200 + content-type + magic).
  4. ✅ Endpoint `GET /api/v1/backtest/31/export?format=pdf` локально вернул `HTTP 200`,
     `Content-Type: application/pdf`, 54685 байт, `file → PDF document, version 1.7`.
- **Тесты:** baseline 866 → **867 passed / 0 failed** (+1 positive-path).
- **Файлы изменены:** `Develop/backend/pyproject.toml`,
  `Develop/backend/tests/unit/test_backtest/test_export.py`,
  `Develop/backend/INSTALL.md` (NEW — инструкция по установке системных зависимостей).
- **Файлы НЕ изменены (не потребовалось):** `app/backtest/export.py`, `app/backtest/router.py`,
  `setup_macos.sh` (системные зависимости там уже учтены).

---

## Sprint 7 — переносы из 7.11 финального E2E (QA W3, 2026-04-26)

### S7R-AI-CHAT-TESTID-DRIFT — regression от 7.19 (gotcha-22 кандидат)

- **Источник:** Sprint 7, QA W3 (7.11), `reports/QA_W3_final.md` §3.
- **Симптом:** `e2e/ai-chat.spec.ts:68` (`AI Chat Mode › 2. Send message`) падает с `expect(locator '[data-testid="chat-input"] textarea, [data-testid="chat-input"]').toBeVisible() — element not found`.
- **Причина:** в 7.19 `<Textarea data-testid="chat-input">` обёрнут в Mantine `<Combobox.Target>`, который через `cloneElement` переписывает атрибуты — `data-testid` уезжает на обёртку, а не на DOM-textarea.
- **Что сделать на 7.R fix-волне:** заменить selector в `e2e/ai-chat.spec.ts:81` на `page.locator('[data-testid="ai-chat"] textarea').first()` (или эквивалент, как в `s7-ai-commands.spec.ts`). Production-код НЕ трогать.
- **Опционально:** ARCH решает, заводить ли `Develop/stack_gotchas/gotcha-22-mantine-combobox-target-testid-clone.md` или зафиксировать как тестовый паттерн в `e2e/README.md`.

### S6R-AICHAT-APPLY-MOCK — pre-existing skip с baseline

- **Источник:** `e2e/ai-chat.spec.ts:97` (`test.skip('3. "Apply to blocks" button triggers block loading'`).
- **Причина:** кнопка «Применить на схеме» disabled в mock-окружении (не получает блоков от mock AI-ответа).
- **Что сделать:** дополнить мок аи-ответа реалистичным block_xml, либо построить отдельный fixture с подгрузкой стратегии.

### S5R-BLOCKLY-MODE-B-MODAL — pre-existing skip с baseline

- **Источник:** `e2e/blockly.spec.ts:86` (`test.skip('mode B modal opens and shows template copy button'`).
- **Причина:** mode B (template) feature не реализована во фронтенде на S5R/S6/S7.
- **Что сделать:** либо реализовать mode B в S8 в рамках UX-задачи, либо удалить spec.

### S5R-BLOCKLY-MODE-B-CHECK — pre-existing skip с baseline

- **Источник:** `e2e/blockly.spec.ts:90` (`test.skip('mode B: check button is disabled without template text'`).
- **Причина:** см. выше (mode B).
- **Что сделать:** парный с предыдущим — решается одной задачей.

### S7R-E2E-7.3-MISSING — экспорт CSV/PDF без E2E

- **Источник:** Sprint 7, e2e_test_plan_s7.md секция 7.3 (S7.3.1, S7.3.2). Backend pytest 867/0 покрывает endpoint, но E2E на скачивание + проверка содержимого не написан.
- **Что сделать на S8:** реализовать spec `s7-export.spec.ts` через `page.waitForEvent('download')` — 2 теста (CSV структура колонок, PDF magic-bytes + размер ≥ 5 KB).

### S7R-E2E-7.9-MISSING — backup/restore CLI без E2E

- **Источник:** e2e_test_plan_s7.md секция 7.9. Backend pytest 36/0 покрывает BackupService, но subprocess-spec из Playwright не написан.
- **Что сделать на S8:** spec вызывает `python -m app.cli.backup` через `child_process.spawn`, проверяет файл и `python -m app.cli.restore`.

### S7R-E2E-7.13-MISSING — 5 event_type без E2E

- **Источник:** e2e_test_plan_s7.md секция 7.13 (5 сценариев). MR.5 закрыт W1 backend-тестами BACK1 39/0, frontend-проверки колокольчика не написаны.
- **Что сделать на S8:** spec, который через `_test/emit-event` (или mock-WS) триггерит каждый из 5 типов и проверяет рендер в `[data-testid="notification-bell"]`.

### S7R-E2E-7.14-MISSING — Telegram callbacks без E2E

- **Источник:** e2e_test_plan_s7.md секция 7.14 (2 сценария). Backend BACK2 W1 покрывает CallbackQueryHandler, frontend deep-link тесты не написаны.
- **Что сделать на S8:** spec на `/sessions/{id}` и `/chart?ticker=...` через симуляцию callback'а.

### S7R-E2E-7.16-MISSING — interactive zones и аналитика без E2E

- **Источник:** e2e_test_plan_s7.md секция 7.16 (4 сценария). FRONT1 W1 7.16 реализован, но E2E отсутствует.
- **Что сделать на S8:** spec на hover/клик зон бэктеста, проверку `[data-testid="trade-detail-panel"]`, `[data-testid="pnl-histogram"]`, `[data-testid="win-loss-donut"]`. **Важно:** также проверить расхождение `backtest-pnl-histogram` vs `pnl-histogram` (UX W3 deltas, MEDIUM).

### S7R-E2E-7.17-MISSING — background backtest без E2E

- **Источник:** e2e_test_plan_s7.md секция 7.17 (4 сценария). FRONT1 W1 7.17 реализован, но E2E отсутствует.
- **Что сделать на S8:** spec на toast «запущен в фоне», бейдж `[data-testid="bg-backtest-badge"]` инкремент/декремент через мок WS-фреймов C2.

---

## Sprint 7 — переносы из ARCH 7.R (2026-04-26)

> Карточки добавлены ARCH-агентом по итогам финального ревью S7. Все — DEFERRED-S8 (не блокеры PASS).

### S7R-GRID-HEATMAP-ENTRYPOINT — GridSearchHeatmap PARTIALLY CONNECTED

- **Источник:** Sprint 7, FRONT2 W2 sub-wave 2 (`reports/DEV-4_FRONT2_W2.md` §4), UX W3 §5 #6.
- **Симптом:** компонент `GridSearchHeatmap` написан, имеет 3 режима (bar / 2D heatmap / sortable table) и unit-тесты, но НЕ имеет точки вызова в production-коде. Из `BackgroundBacktestsBadge` нет ссылки «Открыть результат» для grid-job'а с `result.matrix`.
- **Объём:** ≤1 час. Добавить страницу `/backtest/grid/{job_id}/result` или модалку из dropdown badge.
- **Приоритет:** medium. Не блокирует приёмку S7 (Grid Search backend полностью функционален, FRONT2 модалка запуска работает).

### S7R-FE-LINT-PRE-EXISTING-6 — 6 frontend lint errors в legacy-файлах

- **Источник:** Sprint 7, FRONT1 W1 §3, midsprint_check §47.
- **Симптом:** 6 lint errors в `CandlestickChart.tsx`, `SessionDashboard.tsx`, `ChartPage.tsx`, `ProfileSettingsPage.tsx`, `priceAlertStore.ts` — pre-existing, не вызваны кодом S7.
- **Что сделать:** мини-волна `pnpm lint --fix` с ручным разбором non-fixable.
- **Приоритет:** low.

### S7R-WIDGETS-UNIT-COVERAGE — HealthWidget / ActivePositionsWidget без unit-тестов

- **Источник:** Sprint 7, UX W3 §5 #11.
- **Симптом:** unit-тесты есть только для `BalanceWidget` (4 теста). `HealthWidget` и `ActivePositionsWidget` покрыты только E2E `s7-front2.spec.ts` (smoke render).
- **Что сделать:** написать по 3–5 unit-тестов на каждый виджет (graceful degrade на yellow, sortable по abs(P&L), navigate на click).
- **Приоритет:** low.

### S7R-ORDER-MANAGER-REAL-MODE-COVERAGE — paper-only тесты OrderManager

- **Источник:** midsprint_check §53, Sprint 7 W1 BACK1 §6.
- **Симптом:** `tests/test_trading/test_order_manager.py::TestOrderManagerProcessSignal::test_process_buy_signal` покрывает только paper-mode (instant fill `status='filled'`). Real-mode (`status='pending'` до broker callback) не покрыт.
- **Что сделать:** `@pytest.mark.parametrize` с двумя ветвями — paper и real (mock broker_adapter).
- **Приоритет:** medium (касается trading-engine, критический путь).

### S7R-DRAWING-EDITING — drag/перенос/изменение углов фигуры

- **Источник:** Sprint 7, FRONT1 PHASE1 §6 + UX W3 §2 (HIGH).
- **Симптом:** UX-макет drawing_tools.md §4 предусматривает state «editing» (drag/перенос/изменение углов выделенной фигуры) — НЕ реализован в S7 (PHASE1 ограничен hit-test'ом). Удаление через delete-кнопку и список — есть.
- **Что сделать:** реализовать hit-test на canvas + drag-handler. Требует серьёзной работы FRONT1 (~1–2 дня).
- **Приоритет:** medium-high (UX delta).

### S7R-DRAWING-INTRADAY-COORDS — sequential mode координаты

- **Источник:** Sprint 7, FRONT1 PHASE1 §8 + UX W3 §2 (MEDIUM).
- **Симптом:** в sequential index mode (intraday TF: 1m/5m/15m/1h/4h) координаты time→x для drawings рассчитываются неточно — `MSK_OFFSET_SEC + sequentialIndex` не синхронизированы. Фигуры могут «уезжать».
- **Что сделать:** вынести `MSK_OFFSET_SEC` + хелперы в `components/charts/utils.ts`, синхронизировать конверсию между `CandlestickChart` и `DrawingsLayer`. Кандидат на новый Stack Gotcha.
- **Приоритет:** medium.

### S7R-WIDGET-SPARKLINE-24H — endpoint для ActivePositions sparkline

- **Источник:** Sprint 7, UX W3 §2 (MEDIUM).
- **Симптом:** `ActivePositionsWidget` рендерит sparkline 60×24 с **пустым массивом** `data: []`. UX-макет dashboard_widgets.md §5 требует реальные мини-графики 24h.
- **Что сделать:** новый endpoint `GET /api/v1/market-data/sparkline?ticker=X&hours=24` (агрегация из существующего OHLCV-кэша свечей 1h) + подключение в виджет.
- **Приоритет:** medium.

### S7R-WIZARD-TELEGRAM-TEST-BUTTON — кнопка «Проверить подключение» Telegram

- **Источник:** Sprint 7, UX W3 §2 (MEDIUM).
- **Симптом:** на шаге 4 wizard'а (настройка уведомлений) UX-макет требует кнопку «Проверить подключение» Telegram (`data-testid="wizard-telegram-test"`). Backend endpoint `POST /api/v1/notifications/telegram/test` не реализован, frontend кнопку скипнул.
- **Что сделать:** smoke-тест endpoint (отправляет тестовое сообщение с bot_token/chat_id из payload, без сохранения), кнопка во frontend.
- **Приоритет:** medium.

### S7R-HEALTH-WS-MIGRATION — HealthWidget polling 30s → WS

- **Источник:** Sprint 7, UX W3 §2 (LOW).
- **Симптом:** `HealthWidget` обновляется через `setInterval(30s)` REST polling. UX-макет dashboard_widgets.md §7 требует WS-обновление.
- **Что сделать:** новый WS-канал `health` (или переиспользовать существующий) → push при изменении CB/T-Invest/Scheduler состояния.
- **Приоритет:** low.

### S7R-MULTICURRENCY-TOGGLE — переключатель валют RUB/USD/EUR в BalanceWidget

- **Источник:** Sprint 7, UX W3 §2 (LOW).
- **Симптом:** UX-макет dashboard_widgets.md §3 предусматривает toggle RUB/USD/EUR. Backend возвращает только RUB. Не реализовано.
- **Приоритет:** low.

### S7R-BG-BACKTEST-AUTOCOLLAPSE — auto-collapse done через 10s

- **Источник:** Sprint 7, UX W3 §2 (LOW).
- **Симптом:** UX-макет background_backtest_badge.md §5 предлагал auto-collapse `done`-записи через 10 секунд. Текущее поведение: запись остаётся до явного «Очистить завершённые» — допустимо, но UX просил иначе.
- **Приоритет:** low.

### S7R-HISTOGRAM-MANTINE-TOOLTIP — Mantine `<Tooltip>` на bar гистограммы

- **Источник:** Sprint 7, UX W3 §2 (LOW).
- **Симптом:** `PnLDistributionHistogram` использует нативный `title` для tooltip'а bar'а. UX-макет рекомендует Mantine `<Tooltip>` для консистентности.
- **Что сделать:** замена + проверка a11y (aria-describedby).
- **Приоритет:** low.

---

## Sprint 7 — Hotfix-карточки 2026-04-27 (post-S7 closeout)

> Карточки заведены оркестратором по итогам двух production-bug'ов, обнаруженных заказчиком после закрытия S7. Hotfix'ы применены defensive-уровнем (виджет / NS cooldown), архитектурные правки — DEFERRED-S8.

### S7R-MULTIPLEXER-SINGLETON — ✅ DONE 2026-04-27 (закрыто оркестратором)

> Закрыто в hotfix-волне фазы 2 (см. `Sprint_7/changelog.md:13-32`). Module-level singleton `get_or_create_multiplexer(token)` + `shutdown_multiplexers()` в lifespan. Полная регрессия 885/0 backend pytest. Live-проверка: `multiplexer_singleton_created` 1 раз, 2 подписки на один stream.

### ~~S7R-MULTIPLEXER-SINGLETON — TInvestStreamMultiplexer не singleton~~ (исходное описание)

- **Источник:** Sprint 7, hotfix 2026-04-27 «спам Telegram-уведомлений `connection_restored` за ночь» (см. `Sprint_7/changelog.md` запись от 2026-04-27).
- **Симптом:** `TInvestStreamMultiplexer` создаётся per-`TInvestAdapter` (`Develop/backend/app/broker/tinvest/adapter.py:724`). При нескольких adapter'ах в системе (например, для свечей в `MarketDataService` + для торговли в `TradingService`) запускается несколько `_run_stream` циклов. Каждый имеет свой `_connection_event_published` флаг → каждый publish'ит свою пару `connection.lost`/`connection.restored` независимо → дубликаты на `event_bus`. На ночном reconnect-storm T-Invest (соединение разрывается ~1 раз/мин в нерабочие часы) пользователь получил **до 2880 Telegram-сообщений за ночь**.
- **Текущая защита (hotfix 2026-04-27):** cooldown 15 мин в `NotificationService._broker_status_loop` (см. `_broker_event_cooldown_sec`). Закрывает симптом, но не root cause.
- **Что сделать на S8:** сделать `TInvestStreamMultiplexer` singleton в `app.state.tinvest_multiplexer`, share между всеми `TInvestAdapter`. Lifespan создаёт/закрывает один экземпляр. Флаг `_connection_event_published` гарантированно один.
- **Приоритет:** medium. Cooldown работает как defense-in-depth, но архитектурно multiplexer должен быть singleton (как описано в Gotcha 4 для S6 DEV-5: «единственный persistent gRPC stream на весь адаптер» — но требование не распространено на «весь процесс»).

### S7R-API-PAGINATED-TYPE-MISMATCH — type/runtime mismatch в api-клиентах

- **Источник:** Sprint 7, hotfix 2026-04-26 «ActivePositionsWidget runtime crash» (см. `Sprint_7/changelog.md` запись от 2026-04-26 после S7 closeout).
- **Симптом:** `tradingApi.getSessions` (`Develop/frontend/src/api/tradingApi.ts:17`) декларирует возврат `TradingSession[]`, но backend `GET /api/v1/trading/sessions` возвращает `PaginatedResponse {items, total, ...}` (см. `Develop/backend/app/trading/router.py:list_sessions(response_model=PaginatedResponse)`). TS не отловил — ложная аннотация. FRONT2 в W2 sub-wave 2 написал `setSessions(r.data)` доверившись типу — на runtime `r.data.filter is not a function` крашит весь дашборд.
- **Текущая защита (hotfix):** defensive guard в `ActivePositionsWidget.tsx:76-83` (`Array.isArray(data) ? data : data.items ?? []`).
- **Что сделать на S8:**
  1. **Audit всех `Develop/frontend/src/api/*.ts`** — найти все `apiClient.get<X[]>` для endpoint'ов, у которых backend `response_model=PaginatedResponse`. Привести типы к реальности (`Promise<{ data: PaginatedResponse<X> }>`).
  2. **Поправить вызывающий код** — заменить `r.data` на `r.data.items` (или адаптер).
  3. Опционально: создать `Develop/stack_gotchas/gotcha-23-api-paginated-type-mismatch.md` для будущих DEV.
- **Приоритет:** medium-high. Аналогичные runtime-crash могут быть в других виджетах/страницах. ErrorBoundary вокруг top-level routes (как минимум) — отдельная карточка S7R-FRONTEND-ERROR-BOUNDARY-MISSING.

### S7R-FRONTEND-ERROR-BOUNDARY-MISSING — нет ErrorBoundary вокруг страниц

- **Источник:** Sprint 7, hotfix 2026-04-26 «ActivePositionsWidget runtime crash».
- **Симптом:** runtime-ошибка в одном виджете (ActivePositionsWidget) уронила всю страницу `/dashboard` — пустой экран, мигание. React не имеет ErrorBoundary вокруг роутов / виджетов.
- **Что сделать на S8:** добавить `<ErrorBoundary>` в `App.tsx` вокруг `<Routes>` (top-level fallback) + `<ErrorBoundary>` вокруг каждого виджета на `DashboardPage` (graceful degrade — один сломанный виджет не валит остальные).
- **Приоритет:** medium. Защита от любых будущих runtime-багов в UI.

### S7R-CONNECTION-EVENTS-MARKET-CLOSED — не публиковать в нерабочие часы

- **Источник:** Sprint 7, hotfix 2026-04-27.
- **Симптом:** ночью биржа MOEX закрыта (~19:00–10:00 МСК + выходные). T-Invest всё равно держит соединение, но регулярно разрывает по idle/lifecycle. `connection.lost`/`connection.restored` уведомления в это время — некритичны, пользователь не торгует.
- **Что сделать на S8:** в `NotificationService._broker_status_loop` (или в `multiplexer._publish_connection_event`) проверять MOEX-календарь через `app/scheduler/calendar.py` (или эквивалент). Если биржа закрыта — пропускать publish (но логировать в backend.log на debug). Cooldown 15 мин остаётся как defense-in-depth.
- **Приоритет:** low (cooldown 15 мин уже сильно сглаживает, market-closed filter — улучшение качества).
