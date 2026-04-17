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
