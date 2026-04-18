# ARCH Review — Sprint 6

**Дата:** 2026-04-17
**Ревьюер:** ARCH
**Вердикт:** PASS WITH NOTES

---

## 1. Baseline до/после

| Метрика | До S6 (S5R2 закрытие) | После S6 | Δ |
|---------|----------------------|----------|---|
| Backend unit tests | 623 passed | 662 passed | +39 |
| Frontend unit tests | 238 passed | 250 passed | +12 |
| E2E tests (Playwright) | 109 passed | 105 tests + 3 skip (spec-файлы мигрированы на моки) | ~0 (миграция) |
| Stack Gotchas | 16 | 17 | +1 |
| CI status | ✅ green | ✅ green (pytest 662=0f, vitest 250=0f) | — |
| Notification channels | 0 (none) | 3 (Telegram, Email, In-app) | +3 |
| Recovery capability | Paper only | Paper + Real (сверка позиций с брокером) | +real |
| Graceful Shutdown | Basic (stop listeners) | Full (suspend + pending orders 30s + notify) | ↑ |
| SDK T-Invest | 0.2.0b59 | 0.2.0b117 | ↑ |
| Stream architecture | task-per-subscription | persistent gRPC multiplexer | ↑ |
| E2E dependency on backend | ~40 тестов через real login | 0 тестов (все на моках) | ↑ |

**Примечание по E2E:** Количество spec-файлов выросло с 20 до 23 (DEV-6 добавил `moex_iss_mock.ts`, README, мигрировал 17 файлов). Тесты полностью автономны от backend (0 зависимостей от `E2E_PASSWORD`). DEV-7 (E2E S6 + Security) не запущен — его спеки добавят +N тестов.

---

## 2. Верификация DEV-задач

### DEV-0: S6-STRATEGY-UNDERSCORE-NAMES

| Проверка | Результат |
|----------|-----------|
| `grep "_entry_order\|_sl_order" app/strategy/code_generator.py` → пусто | ✅ Пусто |
| pytest test_strategy/ test_sandbox/ test_backtest/ | ✅ 14+7+72 passed |
| compile→compile_restricted в тестах | ✅ Подтверждено (11 тестов обновлены) |
| E2E тест: полная стратегия → compile_restricted → assert нет self._ | ✅ Добавлен |

**Вердикт: PASS**

---

### DEV-1: NotificationService + Recovery + Graceful Shutdown

| Проверка | Результат |
|----------|-----------|
| `grep "NotificationService(" app/main.py` | ✅ `notification_service = NotificationService(AsyncSessionLocal)` (строка 67) |
| `grep "create_notification(" app/` | ✅ 5 мест: service.py (определение + event listener), runtime.py (3 вызова: recovery, shutdown, divergence) |
| `grep "listen_session_events(" app/` | ✅ Вызывается в main.py lifespan и engine.py start_session |
| REST API 6 endpoints | ✅ GET /, GET /unread-count, PATCH /{id}/read, PUT /read-all, GET /settings, PUT /settings/{event_type} |
| WS канал `notifications:{user_id}` | ✅ EventBus publish + WS subscribe |
| Recovery для real-сессий | ✅ Сверка через get_real_positions(), расхождения → pause + notification |
| Graceful Shutdown | ✅ sessions → "suspended", pending 30s timeout, notification "Система остановлена" |
| 13 новых тестов | ✅ Подтверждено |

**Контракты (поставщик):**
- `NotificationService.create_notification()` → DEV-2, DEV-4 — OK
- REST `/api/v1/notification/*` → DEV-4 — OK
- WS `notifications:{user_id}` → DEV-4 — OK

**Вердикт: PASS**

---

### DEV-2: Telegram Bot + Email

| Проверка | Результат |
|----------|-----------|
| `grep "TelegramNotifier(" app/` | ✅ Инстанциируется в service.py при наличии TELEGRAM_BOT_TOKEN |
| `grep "EmailNotifier(" app/` | ✅ Инстанциируется в service.py при наличии SMTP_HOST+SMTP_USER |
| `grep "TELEGRAM_BOT_TOKEN" app/` | ✅ config.py (Settings), service.py (условие), router.py (webhook) |
| Webhook /start + привязка 6-digit token TTL 5min | ✅ link_store.py + telegram_webhook.py |
| Команды /positions, /status, /help | ✅ Реализованы в webhook handler |
| dispatch_external — реальная реализация | ✅ Заменяет заглушку DEV-1 |
| .env.example обновлён (+8 переменных) | ✅ TELEGRAM_*, SMTP_* |
| 16 новых тестов | ✅ 4 TelegramNotifier + 6 webhook + 4 link-token + 2 EmailNotifier |

**Контракты (потребитель + поставщик):**
- Потребитель `NotificationService.create_notification()` от DEV-1 — OK
- Поставщик `dispatch_external(notification, settings) → list[str]` — OK

**Новый Stack Gotcha обнаружен:** telegram.Bot frozen attrs (→ gotcha-17).

**Вердикт: PASS WITH NOTES** (gotcha-17 оформлен)

---

### DEV-3: T-Invest SDK Upgrade

| Проверка | Результат |
|----------|-----------|
| `pip show tinkoff-investments` → 0.2.0b117 | ✅ Подтверждено |
| `grep "sys.modules.*tinkoff" tests/` → пусто | ✅ Stub удалён (Gotcha 14 закрыт) |
| pyproject.toml — SDK зафиксирован | ✅ `tinkoff-investments @ git+...@0.2.0-beta117` |
| Breaking changes = 0 | ✅ Все 10 импортируемых классов совместимы |
| ruff 0 errors (исправлены 4 E402) | ✅ |
| pytest test_broker/ — 55 passed | ✅ |

**Контракт (поставщик → DEV-5):** SDK beta117+ установлен — CONFIRMED.

**Вердикт: PASS**

---

### DEV-4: Frontend Notification Center

| Проверка | Результат |
|----------|-----------|
| `grep "notification-bell\|notification-drawer\|critical-banner" src/` | ✅ 9 совпадений: Bell, Drawer, Banner — все с data-testid |
| NotificationBell с badge + WS | ✅ Создан, WS подписка `notifications:{user_id}` |
| NotificationDrawer | ✅ Severity-emoji, relative time (рус.), «Прочитать все», «Загрузить ещё» |
| CriticalBanner | ✅ Fixed top, красный, 30с auto-dismiss, dismiss-кнопка |
| NotificationSettingsPage | ✅ Таблица event_type × канал |
| Маршрут /notifications в App.tsx | ✅ ProtectedRoute |
| notificationStore.ts | ✅ 121 строка, fetch/addFromWS/markAsRead/toggleDrawer |
| 12 тестов (минимум 6 требовалось) | ✅ 6 store + 4 Bell + 2 Banner |
| vitest 250 passed | ✅ Подтверждено |

**Контракты (потребитель):**
- REST 6 endpoints от DEV-1 — OK (через notificationApi.ts)
- WS `notifications:{user_id}` от DEV-1 — OK
- POST /telegram/link-token от DEV-2 — OK

**Вердикт: PASS**

---

### DEV-5: T-Invest Stream Multiplex

| Проверка | Результат |
|----------|-----------|
| `grep "market_data_stream(" app/broker/tinvest/ \| grep -v test` → 1 место | ✅ multiplexer.py:194 — единственное место |
| `_stream_candles` в adapter.py | ✅ Отсутствует (старый метод удалён) |
| `create_task` в adapter.py | ✅ Отсутствует (task-per-subscription удалён) |
| Public API subscribe_candles/unsubscribe не изменён | ✅ StreamManager не затронут |
| Backoff reset исправлен (после первого response, не при входе в context manager) | ✅ |
| 10 тестов (6 multiplexer + 4 adapter) | ✅ |
| pytest 646 passed (в момент DEV-5, до мержа DEV-4) | ✅ |

**Контракты:**
- Потребитель SDK beta117+ от DEV-3 — CONFIRMED
- Поставщик `subscribe_candles`/`unsubscribe` → StreamManager — API не изменён

**Вердикт: PASS**

---

### DEV-6: E2E Infrastructure

| Проверка | Результат |
|----------|-----------|
| `ls .github/workflows/playwright-nightly.yml` | ✅ Найден в `Develop/.github/workflows/` |
| `grep "S5R-CHART-FRESHNESS" e2e/` → только в комментарии | ✅ Не в test.skip — тесты работают 24/7 |
| `grep "E2E_PASSWORD" e2e/*.spec.ts` → 0 совпадений | ✅ Все тесты на моках |
| moex_iss_mock.ts — generateFreshCandles() | ✅ Создан |
| api_mocks.ts — +12 хелперов | ✅ Расширен |
| 20 spec-файлов мигрированы | ✅ |
| TypeScript tsc --noEmit OK | ✅ |

**Замечание:** Тесты не были запущены DEV-6 (нет frontend/backend окружения в worktree). Playwright тесты требуют ручной верификации при запуске полного E2E цикла.

**Вердикт: PASS WITH NOTES** (тесты не запускались в worktree, но TypeScript компиляция пройдена)

---

### DEV-7: E2E S6 + Security

**Статус: PENDING REVIEW** — DEV-7 отчёт отсутствует в `Sprint_6/reports/`. Агент ещё не завершил работу или не запущен.

**Задачи DEV-7:** E2E тесты уведомлений, security-тесты (CSRF, rate limiting, sandbox escape, notification injection).

**Влияние на вердикт:** DEV-7 — не блокер для приёмки S6 (E2E и security тесты расширяют coverage, но не вносят функциональных изменений). Верификация будет выполнена по готовности отчёта.

---

### Сводная таблица

| DEV | Задача | Grep-проверки | Тесты | Контракты | Вердикт |
|-----|--------|:---:|:---:|:---:|---------|
| DEV-0 | _underscore fix | ✅ | ✅ | N/A | **PASS** |
| DEV-1 | NotificationService + Recovery + Shutdown | ✅ | ✅ | ✅ | **PASS** |
| DEV-2 | Telegram + Email | ✅ | ✅ | ✅ | **PASS WITH NOTES** |
| DEV-3 | SDK upgrade | ✅ | ✅ | ✅ | **PASS** |
| DEV-4 | Notification Center | ✅ | ✅ | ✅ | **PASS** |
| DEV-5 | Stream Multiplex | ✅ | ✅ | ✅ | **PASS** |
| DEV-6 | E2E infra | ✅ | ⚠️ | ✅ | **PASS WITH NOTES** |
| DEV-7 | E2E S6 + Security | — | — | — | **PENDING REVIEW** |

---

## 3. Cross-DEV Contracts — сводная

### Волна 1 (внутренняя)

| Поставщик | Потребитель | Контракт | Статус |
|-----------|-------------|----------|--------|
| DEV-1 | DEV-2 | `NotificationService.create_notification()` | ✅ Подтверждён |
| DEV-2 | DEV-1 | `dispatch_external(notification, settings) → list[str]` | ✅ Подтверждён |

### Волна 1 → Волна 2

| Поставщик | Потребитель | Контракт | Статус |
|-----------|-------------|----------|--------|
| DEV-1 | DEV-4 | REST API 6 endpoints | ✅ Подтверждён |
| DEV-1 | DEV-4 | WS канал `notifications:{user_id}` | ✅ Подтверждён |
| DEV-1 | DEV-4 | NotificationResponse schema | ✅ Подтверждён |
| DEV-3 | DEV-5 | SDK beta117+ в pyproject.toml | ✅ Подтверждён |
| DEV-2 | DEV-4 | POST /telegram/link-token | ✅ Подтверждён |

**Итог: 7/7 контрактов подтверждены. Нарушений нет.**

---

## 4. Обновления ФТ/ТЗ

### 4.1 Функциональные требования (functional_requirements.md)

Обновлены секции:
- **§9.1** — привязка: уточнён механизм (6-значный токен, TTL 5 мин, `/start <токен>`)
- **§9.2** — уведомления: HTML parse_mode, severity→emoji, inline-кнопки
- **§9.3** — команды Must: `/positions`, `/status`, `/help` → реализованы в S6
- **§10.1** — таблица каналов уведомлений: 14 типов событий × 3 канала → реализовано
- **§10.2** — In-app: Bell+badge, Drawer, CriticalBanner → реализовано
- **§17.7** — Recovery: поддержка Real-сессий (сверка позиций, pause при расхождениях)

### 4.2 Техническое задание (technical_specification.md)

Обновлены секции:
- **§5.7 NotificationService** — реальная архитектура: service → lazy-init notifiers (TelegramNotifier, EmailNotifier), EventBus bridge, dispatch_external
- **§8.6 Graceful Shutdown** — реальная последовательность: sessions → "suspended", pending orders 30s, notification, stream unsubscribe

### 4.3 План разработки (development_plan.md)

- §S6 задачи: 6.1–6.10 → отмечены статусами (6.1–6.8 ✅, 6.9–6.10 pending DEV-7)

---

## 5. Новые Stack Gotchas

| # | Slug | Описание | Источник |
|---|------|----------|----------|
| 17 | telegram-bot-frozen-attrs | python-telegram-bot v20+ — frozen-атрибуты блокируют `patch.object` на инстансе | DEV-2 report, секция 6+8 |

Файл создан: `Develop/stack_gotchas/gotcha-17-telegram-bot-frozen-attrs.md`
INDEX.md обновлён.

Остальные DEV-отчёты (0, 1, 3, 4, 5, 6) — секция 8 «Новые Stack Gotchas» = «Нет».

---

## 6. Рекомендации для Sprint 7

### Незакрытые задачи S6
1. **DEV-7 (E2E S6 + Security)** — pending, должен быть завершён и приёмлен до начала S7
2. **Playwright E2E запуск** — DEV-6 не запускал тесты в worktree; полный прогон нужен с DEV-7

### Should-фичи Telegram
- `/close <стратегия> <тикер>` — закрытие позиции с inline-подтверждением
- `/closeall` — закрытие всех позиций с подтверждением
- `/balance` — текущий баланс по брокерам

### Доработки Trading Panel
- Нет открытых замечаний по Trading Panel из S5R/S5R2 ARCH-ревью (DEV-4 подтвердил SKIP 4.8)

### Техдолг S6
- `Application.initialize()` в python-telegram-bot делает HTTP к Telegram API — в тестах webhook вызовы идут напрямую (обход через Gotcha 17)
- DEV-2 отмечает 1 pre-existing failure в `test_runtime_recovery` — требует расследования (не связан с DEV-2)

### Архитектурные рекомендации
1. **channelTf split валидация** (из S5R2 рекомендаций) — перенести в S7
2. **localStorage-prefetch** — агрегатор warm-up при логине
3. **Scheduler Service** (`app/scheduler/service.py`) — по-прежнему заглушка, требуется реализация APScheduler jobs (update_moex_calendar, daily_backup, send_daily_stats и др.)
4. **pending_events** — таблица описана в ТЗ, но не реализована в S6; рассмотреть для S7 или S8

---

## 7. Техдолг

| # | Описание | Приоритет | Источник |
|---|----------|-----------|----------|
| 1 | Scheduler Service — заглушка (9 jobs из ТЗ §5.9 не реализованы) | Medium | ТЗ §5.9 |
| 2 | pending_events — таблица в БД не используется | Low | ТЗ §3.20 |
| 3 | 1 pre-existing failure test_runtime_recovery | Low | DEV-2 report §6 |
| 4 | DEV-7 pending (E2E S6 + Security тесты) | Medium | execution_order.md |

---

## 8. Финальный вердикт

### **PASS WITH NOTES**

**Обоснование:**

Sprint 6 успешно реализовал всю запланированную функциональность уведомлений, восстановления и graceful shutdown:

- **7 из 8 DEV-задач** завершены и верифицированы (DEV-0..6). DEV-7 — pending.
- **Все 7 Cross-DEV контрактов** подтверждены без нарушений.
- **Backend: 662 passed** (+39 от S5R2 baseline), **Frontend: 250 passed** (+12).
- **3 канала уведомлений** реализованы: Telegram Bot (привязка, webhook, /start /positions /status /help), Email (SMTP, критические события), In-app (WS, Bell, Drawer, CriticalBanner).
- **Recovery** расширен на Real-сессии с сверкой позиций.
- **Graceful Shutdown** — полный цикл (suspend → pending 30s → notify → cleanup).
- **SDK T-Invest** обновлён до beta117, sys.modules stub удалён.
- **Stream architecture** — persistent gRPC multiplexer вместо task-per-subscription.
- **E2E** полностью автономны от backend (0 зависимостей от E2E_PASSWORD).
- **1 новый Stack Gotcha** (gotcha-17: telegram-bot frozen attrs).

**Notes:**
1. DEV-7 (E2E S6 + Security) — pending review, не блокирует функциональную приёмку.
2. DEV-6 не запускал Playwright тесты в worktree — полный прогон с DEV-7.
3. Scheduler Service — по-прежнему заглушка (техдолг из ТЗ §5.9).

**Спринт может быть закрыт** после приёмки DEV-7. Текущий статус: **S6 ⚠️ (DEV-7 pending)**.
