# Sprint 6 — Changelog

> Хронологический журнал выполнения Sprint 6.
> Формат: дата → что изменено → файлы → результат.

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
