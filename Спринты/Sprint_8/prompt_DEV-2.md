---
sprint: 8
agent: DEV-2
role: Backend Core (BACK2) — Security audit + Multiplexer singleton + Event sync + Dashboard widgets
wave: 1+2
depends_on: [ARCH W0, DEV-1 W1 Admin role (для smoke-проверки require_admin)]
---

# Роль

Ты — Backend-разработчик #2 (senior). Зона ответственности по RACI на S8:
- **Security аудит** (R): полный отчёт по 6 направлениям + setup `bandit`/`safety` в CI.
- **Broker stability** (R): root-cause фикс `S7R-MULTIPLEXER-SINGLETON` — `app.state.tinvest_multiplexer` в lifespan.
- **Notification sync** (R): Event type sync L1 — подключить 5 publish-сайтов (`session_recovered`, `backtest_completed`, `daily_stats`, `corporate_action`, `price_alert`) + предоставить контракт для UI.
- **Dashboard widgets backend** (R): 4 endpoint'а для FRONT2 (`/health` extended, `balance/history?since_first_activity`, `market-data/sparkline`, `notifications/telegram/test`).
- **Notification filter** (R): `S7R-CONNECTION-EVENTS-MARKET-CLOSED` — отсекать connection events вне торговых часов MOEX.

На W1 ты — security аудитор и broker singleton инженер. На W2 — backend-author dashboard/notification фич и event sync эпика L1.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python ≥ 3.11, .venv активирован в Develop/backend/.
2. Зависимости предыдущих DEV:
   - DEV-1 W1 Поток F (Admin role) ДОЛЖЕН быть закрыт ДО твоей smoke-проверки `require_admin` (последние 3ч W1).
   - Остальные W1 задачи (security audit + multiplexer) запускаешь параллельно с DEV-1.
3. Существующие файлы:
   - app/common/crypto.py, app/auth/service.py, app/sandbox/executor.py
   - app/middleware/csrf.py, app/middleware/rate_limit.py
   - app/notification/service.py (EVENT_MAP 12 ключей), app/notification/dispatchers.py
   - app/broker/tinvest/multiplexer.py, app/broker/tinvest/adapter.py
   - app/backtest/jobs.py:226, app/corporate_actions/, app/market_data/price_alert_monitor.py
   - app/scheduler/service.py, app/main.py (lifespan)
   - .github/workflows/ci.yml
4. База данных: alembic upgrade head — baseline schema актуальна.
5. Внешние сервисы: T-Invest sandbox (для smoke-проверки multiplexer singleton под нагрузкой), MOEX ISS (для market_closed фильтра).
6. Тесты baseline:
   - cd Develop/backend && .venv/bin/python -m pytest tests/ -q → 1024 / 0 failed (фиксировать актуальное число в отчёте).
   - ruff check . → 0 issues.
   - mypy app/ → 0 errors.
```

> **Правило S5R.5:** реально запусти `pytest`, `ruff`, `mypy` и зафиксируй фактические результаты в отчёте. Если что-то ≠ baseline 1024/0 — это БЛОКЕР, верни `БЛОКЕР: <фактическое расхождение>`.

> Если хоть одно условие не выполнено — верни `БЛОКЕР: <описание>` и не начинай реализацию.

# Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback (если MCP недоступен) |
|--------|--------|--------------------------------|
| pyright-lsp | **да** (mandatory после каждого Edit/Write на .py) | `cd Develop/backend && .venv/bin/python -m py_compile app/<file>.py` |
| typescript-lsp | нет (BACK2 не пишет frontend) | — |
| context7 | **да** — `bandit`, `safety`, `APScheduler` (cron для `daily_stats`), `FastAPI middleware` (CSRF, rate-limit), `argon2-cffi`, `tinkoff-investments` (multiplexer lifecycle) | WebSearch |
| playwright | нет | — |
| WebSearch | **да** — OWASP recommendations 2023 (Argon2id params), bandit/safety best practices, MOEX trading calendar API | — |
| code-review | **да** — после блока security аудит + после multiplexer singleton (критические пути) | — |
| frontend-design | нет | — |
| superpowers (TDD) | **да** — для event sync publishers (критический путь нотификаций) Red-Green-Refactor | — |

**Правило:** после КАЖДОГО Edit/Write на `.py` файл → вызови pyright-lsp diagnostic (или fallback `py_compile`). Hook `plugin-check.sh` напомнит, но обязан следовать и без hook.

# Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью (особенно секция «Правила использования плагинов»).

2. **`Develop/stack_gotchas/INDEX.md`** — таблица «симптом → файл». Открой и применяй ловушки по слоям: `broker/` (multiplexer reconnect), `notification/` (EVENT_MAP контракты, шаблоны), `auth/` (JWT/Argon2id), `sandbox/`, `scheduler/`.

3. **`Спринты/Sprint_8/execution_order.md`** раздел «Cross-DEV contracts» — особое внимание:
   - **Поставщик:** C-S8-1, C-S8-2, C-S8-3, C-S8-4, C-S8-5 (совместно с BACK1), C-S8-6 (внутри backend), C-S8-9
   - **Потребитель:** `require_admin` dependency от DEV-1 (W1 Поток F) — для smoke-проверки

4. **`Спринты/Sprint_8/arch_design_s8.md`** — секции:
   - §3 (Security audit — 6 чек-листов: Crypto / Sandbox / CSRF / Headers / Brute-force / SQL+XSS)
   - §6 (event_type discrepancy — 12 в EVENT_MAP vs 13 в UI, дискрепанс на 9 типов после полной сверки)
   - §8.2-8.3 (Wave breakdown — потоки W1 B + W2 B)
   - §11 batch 2 пункт 3 (Event sync эпик L1 — 4 backend в UI + 5 UI publish-sites)

5. **Цитаты из ТЗ / ФТ** — берутся как есть, не перефразируй:

   > **CLAUDE.md проекта (правила безопасности, дословно):**
   > «Файлы `.env`, `.env.*`, `credentials.*`, ключи API — НИКОГДА не коммитить и не пушить. В коде использовать переменные окружения, а не захардкоженные значения. Если в diff обнаружены токены, пароли или ключи — ОСТАНОВИТЬСЯ и предупредить.»

   > **`arch_design_s8.md` §3.1 (дословно про crypto):**
   > «ключи API брокеров хранятся зашифрованными AES-256-GCM с уникальным IV per encryption»

   > **`arch_design_s8.md` §11 batch 2 пункт 3 (event sync эпик, дословно):**
   > «4 типа в EVENT_MAP, но не в UI: `session_started`, `session_stopped`, `order_placed`, `trade_filled` → добавить в `EVENT_TYPE_LABELS` (`NotificationSettingsPage.tsx:24`).
   > 5 типов в UI, но не в EVENT_MAP: `session_recovered`, `backtest_completed`, `daily_stats`, `corporate_action`, `price_alert` → подключить publish-сайты:
   > - `session_recovered` — после graceful restart NS восстанавливает live-сессии (S6, нужен publish)
   > - `backtest_completed` — `app/backtest/jobs.py:226` (есть `done` publish, добавить EVENT_MAP entry)
   > - `daily_stats` — нужно определить когда публикуется (конец торгового дня?)
   > - `corporate_action` — `app/corporate_actions/` detect job
   > - `price_alert` — `app/market_data/price_alert_monitor.py`»

   > **`technical_specification.md` §Производительность (косвенно для Telegram-test endpoint):**
   > «Время отклика Telegram-команды (от webhook до reply): < 3 секунд» — `POST /notifications/telegram/test` должен укладываться в этот же бюджет.

6. **`Sprint_6_Review/code_review.md`** — записи про EVENT_MAP фикс (`{strategy_name}/{ticker}/{direction}/{volume}/{pnl}`). Образец, как заполнять шаблоны 5 новых EVENT_MAP записей.

7. **`Sprint_7/changelog.md`** записи про `S7R-MULTIPLEXER-SINGLETON` — там описан симптом (несколько TInvestAdapter создают по своему multiplexer'у → rate-limit на gRPC + лишние reconnect).

# Рабочая директория

`Develop/backend/`

# Контекст существующего кода

Перечисляю **только** файлы, которые ты будешь читать/правлять. Не ищи через Glob/Grep — это расход токенов.

- `app/common/crypto.py` — AES-256-GCM `encrypt`/`decrypt`. Проверить IV uniqueness (`secrets.token_bytes(12)`), key-management. **НЕ переписывать** без архитектурного основания, только аудит + точечные фиксы.
- `app/auth/service.py` — JWT issue/verify, Argon2id password hashing. Проверить secret length (текущий warning «23 bytes long, below recommended») — поднять до ≥ 32 в `.env.example` и `config.py`. Argon2id params сверить с OWASP 2023.
- `app/auth/dependencies.py` — точка, где DEV-1 добавит `require_admin` (W1 Поток F). Дождись готовности перед smoke-проверкой.
- `app/sandbox/executor.py` — RestrictedPython sandbox; `_safe_import` whitelist. Проверить блок на `os`/`subprocess`/`socket`/`ctypes`/`importlib`, `__builtins__["__import__"]`, `().__class__.__bases__[0].__subclasses__()`, `compile`/`exec`/`eval`. **НЕ изменять** логику executor'а — только тесты + рекомендации в `security_audit_s8.md`.
- `app/middleware/csrf.py` — double-submit cookie pattern. Проверить SameSite, token rotation на logout.
- `app/middleware/rate_limit.py` — лимит 3-5 попыток/мин на `/auth/login`. Проверить, что persistent (Redis или in-memory с restart-recovery).
- `app/notification/service.py:32-107` — `EVENT_MAP` (12 ключей). Добавить 5 новых: `session_recovered`, `backtest_completed`, `daily_stats`, `corporate_action`, `price_alert` с шаблонами `{...}`. НЕ ломать существующие 12.
- `app/notification/dispatchers.py` — in-app / telegram / email entrypoint (поможет BACK1 закрывать 0% coverage, но это не твоя задача — твоя зона: убедиться, что новые EVENT_MAP записи доходят до dispatchers).
- `app/broker/tinvest/multiplexer.py` — `TInvestMultiplexer` класс; reconnect loop + `connection_lost`/`connection_restored` publish (на строках ~237 и ~271). Здесь ты делаешь S7R-MULTIPLEXER-SINGLETON: в `app/main.py` lifespan единый instance в `app.state.tinvest_multiplexer`, все `TInvestAdapter` его share.
- `app/broker/tinvest/adapter.py` — `TInvestAdapter`. Конструктор/инициализация должны принимать multiplexer извне (через DI или `app.state.tinvest_multiplexer`), не создавать собственный.
- `app/main.py` — `lifespan`: добавить создание `app.state.tinvest_multiplexer = TInvestMultiplexer(...)` на startup + `await multiplexer.close()` на shutdown. Уже есть singleton'ы (`notification_service`, `event_bus`) — следуй паттерну.
- `app/backtest/jobs.py:226` — точка `done` publish после завершения backtest. Добавить publish event_bus + EVENT_MAP entry для `backtest_completed`.
- `app/corporate_actions/` — модуль detect job для `corporate_action` events. Если detect job ещё не зарегистрирован в scheduler — зарегистрируй cron-job + публикуй event_bus.
- `app/market_data/price_alert_monitor.py` — монитор алертов. Добавить publish event_bus для `price_alert` (если ещё не вызывает create_notification).
- `app/scheduler/service.py` — APScheduler. Добавить cron-job для `daily_stats` (конец торгового дня MOEX 19:00 MSK, по будням — учитывай MOEX trading calendar).
- `app/health.py` или `app/main.py` (endpoint `/health`) — расширить response полями `cb_state`, `tinvest_connected`, `scheduler_running`, `scheduler_jobs` (см. контракт C-S8-1).
- `app/market_data/` — новый endpoint `GET /api/v1/market-data/sparkline?ticker=X&hours=24` (см. C-S8-2). Routing через существующий `market_data/router.py`.
- `app/account/` или `app/trading/` — endpoint `GET /api/v1/account/balance/history` — добавить параметр `?since_first_activity=true` (отрезает leading zeros, см. C-S8-3).
- `app/notification/router.py` — новый endpoint `POST /api/v1/notifications/telegram/test` (см. C-S8-4). Mock-friendly: вызов Telegram bot API через `httpx`, возврат `{ok, message}`.
- `.github/workflows/ci.yml` — добавить bandit + safety job (medium+ severity → fail). Существуют backend jobs: pytest, ruff, mypy. Добавь новый job или extend существующий.

# Задачи

## Задача 8B.1: bandit + safety в CI (W1, ~1ч)

**Цель:** Статический анализ Python security (bandit) + CVE-сканер зависимостей (safety) в `.github/workflows/ci.yml`. Medium+ severity блокирует PR.

```yaml
# .github/workflows/ci.yml (добавить job)
security-scan:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with: { python-version: '3.11' }
    - run: pip install bandit safety
    - run: bandit -r app/ -ll  # -ll = medium+ severity
    - run: safety check --policy-file safety_policy.yml || safety check
```

Создай `.banditignore` (если есть false positives — задокументируй) и `safety policy` (если есть legitimate ignores — задокументируй CVE-номер + reason).

## Задача 8B.2: Security audit отчёт `security_audit_s8.md` (W1, ~14ч)

**Цель:** Создать `Спринты/Sprint_8/security_audit_s8.md` — структурированный отчёт по 6 направлениям из `arch_design_s8.md §3`.

**Структура отчёта (обязательная):**

```markdown
# Security Audit — Sprint 8

## 1. Crypto (AES-256-GCM + JWT + Argon2id)
- [x] AES-256-GCM IV uniqueness: <verdict + evidence>
- [x] Key rotation procedure: <verdict>
- [x] JWT secret length: <фактическое значение из config.py + .env.example> → <рекомендация ≥ 32>
- [x] Argon2id params: memory_cost=<X>, time_cost=<Y>, parallelism=<Z>; OWASP 2023 рекомендует ≥ 19 MiB / ≥ 2 iters / ≥ 1
- [x] Refresh token storage: <plain / hash + threat model>

## 2. Sandbox escape (RestrictedPython)
- [x] _safe_import whitelist: <список разрешённых модулей>
- [x] __builtins__ access: blocked / not blocked
- [x] subclasses chain attack: blocked / not blocked
- [x] compile/exec/eval: blocked / not blocked
- [x] Resource limits: timeout=<X>s, memory=<Y>MB

## 3. CSRF + Headers
- [x] Double-submit cookie: enabled on POST/PUT/DELETE
- [x] SameSite: Strict/Lax + обоснование
- [x] CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy: <проверка наличия в response>

## 4. Brute-force
- [x] /auth/login rate limit: <фактический лимит и persistent?>
- [x] Account lockout: <есть/нет + after N attempts>
- [x] CAPTCHA/2FA: <есть/нет>

## 5. SQL injection + XSS
- [x] Raw SQL grep: `text(`/`.execute(` без параметризации → <0 findings / список>
- [x] XSS в Telegram-сообщениях: <user-input экранируется при формировании HTML>
- [x] XSS в email-шаблонах: <аналогично>

## 6. bandit + safety report
- bandit: <X high, Y medium, Z low findings + краткий список>
- safety: <CVE count + список с CVSS>

## Итог + рекомендации
- Critical findings (требуют W1 фикса): <список>
- High findings (W2): <список>
- Medium/Low (S9-backlog): <список>
```

**Метод сбора evidence:** ручной аудит code + pytest assertions + grep. Каждое утверждение в отчёте — со ссылкой на file:line или конкретный pytest-тест.

## Задача 8B.3: S7R-MULTIPLEXER-SINGLETON (W1, ~4ч)

**Симптом (из Sprint_7 changelog):** Несколько `TInvestAdapter` инстансов создают каждый свой `TInvestMultiplexer` → дубли gRPC connections → rate-limit от T-Invest API + лишние reconnect loops.

**Root cause fix:**

```python
# app/main.py — lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    # ... existing singletons ...
    app.state.tinvest_multiplexer = TInvestMultiplexer(token=settings.TINVEST_TOKEN)
    await app.state.tinvest_multiplexer.start()
    try:
        yield
    finally:
        await app.state.tinvest_multiplexer.close()
        # ... existing teardown ...
```

```python
# app/broker/tinvest/adapter.py
class TInvestAdapter(BaseBrokerAdapter):
    def __init__(self, multiplexer: TInvestMultiplexer, ...):
        self._mux = multiplexer  # БЫЛО: self._mux = TInvestMultiplexer(...) — УБРАТЬ
        ...
```

Все точки создания `TInvestAdapter(...)` (через DI в роутерах + `broker/service.py`) — передавать `request.app.state.tinvest_multiplexer` или через `Depends(get_tinvest_multiplexer)`.

**TDD:**
1. Failing test `tests/test_broker/test_multiplexer_singleton.py::test_lifespan_creates_one_instance` — assert `id(adapter1._mux) == id(adapter2._mux)`.
2. Fix → Green.
3. Failing test `test_close_called_on_shutdown` — assert `multiplexer.close()` вызван при `lifespan.__aexit__`.
4. Fix → Green.

## Задача 8B.4: Smoke-проверка require_admin (W1, ~3ч, ПОСЛЕ DEV-1 Поток F)

**Зависимость:** DEV-1 W1 Поток F должен зафиксировать `app/auth/dependencies.py::require_admin` + миграцию `users.is_admin`.

**Что делать:**
1. Grep `grep -rn "require_admin\|is_admin" app/` — найти все endpoint'ы, помеченные как admin-only.
2. Для каждого — pytest integration:
   - GET/POST endpoint от non-admin user → 403.
   - От admin user → 200.
3. Зафиксировать в `security_audit_s8.md` §4 (Brute-force / Authorization) список endpoint'ов + статусы.

Если DEV-1 ещё не закрыл Поток F к моменту твоей готовности — **не блокируй** свои другие задачи, эту перенеси в конец W1.

## Задача 8B.5: Event sync L1 — 5 publish-сайтов (W2, ~12ч, TDD обязателен)

**Цитата из arch_design_s8.md §11 batch 2 (дословно, см. выше).**

**5 новых записей в `EVENT_MAP` (`app/notification/service.py`):**

```python
# app/notification/service.py:32-107 (расширение EVENT_MAP)
EVENT_MAP = {
    # ... existing 12 ...
    "session_recovered": EventTemplate(
        event_type="session_recovered",
        severity="info",
        title_template="Сессия восстановлена",
        body_template="Стратегия {strategy_name} ({ticker}) восстановлена после перезапуска",
    ),
    "backtest_completed": EventTemplate(
        event_type="backtest_completed",
        severity="info",
        title_template="Бэктест завершён",
        body_template="Бэктест {strategy_name} ({ticker}, {timeframe}): P&L {pnl:+.2f}, Sharpe {sharpe:.2f}",
    ),
    "daily_stats": EventTemplate(
        event_type="daily_stats",
        severity="info",
        title_template="Итоги торгового дня",
        body_template="Сессий: {sessions_count}, сделок: {trades_count}, P&L дня: {daily_pnl:+.2f}",
    ),
    "corporate_action": EventTemplate(
        event_type="corporate_action",
        severity="warning",
        title_template="Корпоративное событие",
        body_template="{ticker}: {action_type} — {description}",
    ),
    "price_alert": EventTemplate(
        event_type="price_alert",
        severity="info",
        title_template="Ценовой алерт",
        body_template="{ticker}: цена {current_price} {direction} порог {threshold}",
    ),
}
```

**5 publish-сайтов (точные file:line):**

| event_type | Файл | Что подставлять |
|------------|------|------------------|
| `session_recovered` | `app/notification/service.py` (graceful restart hook — после `restore_sessions`) | `{strategy_name, ticker}` |
| `backtest_completed` | `app/backtest/jobs.py:226` (точка `done` publish) | `{strategy_name, ticker, timeframe, pnl, sharpe}` |
| `daily_stats` | `app/scheduler/service.py` (новый cron-job 19:05 МСК будни) | `{sessions_count, trades_count, daily_pnl}` |
| `corporate_action` | `app/corporate_actions/` detect job | `{ticker, action_type, description}` |
| `price_alert` | `app/market_data/price_alert_monitor.py` | `{ticker, current_price, direction, threshold}` |

**Подход TDD:**
1. Failing test `tests/test_notification/test_event_sync_publishers.py::test_<event>` — mock runtime → trigger publish-site → assert `create_notification` вызван с правильным `event_type` + контекстом.
2. Запустить — Red.
3. Реализовать publish.
4. Запустить — Green.
5. Refactor (общий helper если повторяется).

**Семантика `daily_stats`:** конец торгового дня MOEX (19:00 МСК) + 5 минут на агрегацию → 19:05 МСК cron, только по будням (учитывай MOEX trading calendar). Считай метрики за день из `TradingSession` + `LiveTrade` + `DailyStat`.

## Задача 8B.6: Dashboard widgets backend (W2, ~10ч)

### 8B.6.1: `/health` extended (C-S8-1, ~3ч)

```python
# app/health.py (или app/main.py)

@router.get("/api/v1/health")
async def health(request: Request) -> dict:
    return {
        "status": "ok",
        "version": settings.VERSION,
        "database": await check_db(),  # "ok" / "error"
        "cb_state": await get_cb_state(),  # "ok" | "warn" | "triggered"
        "tinvest_connected": request.app.state.tinvest_multiplexer.is_connected,
        "scheduler_running": scheduler_service.scheduler.running,
        "scheduler_jobs": len(scheduler_service.scheduler.get_jobs()),
    }
```

### 8B.6.2: `/account/balance/history?since_first_activity` (C-S8-3, ~2ч)

Найти существующий endpoint (`app/account/router.py` или `app/trading/router.py`). Добавить query param:

```python
@router.get("/api/v1/account/balance/history")
async def balance_history(
    since_first_activity: bool = False,
    ...
):
    # Если since_first_activity=True — найти timestamp первой активности (LiveTrade/PaperPortfolio change),
    # отрезать leading zeros (период до первой активности).
```

### 8B.6.3: `/market-data/sparkline` (C-S8-2, ~3ч)

```python
# app/market_data/router.py

@router.get("/api/v1/market-data/sparkline")
async def sparkline(
    ticker: str,
    hours: int = 24,
    current_user: User = Depends(get_current_user),
) -> dict:
    """
    Return: {"points": [{"t": timestamp, "p": float}], "current": float}
    """
    # 24h свечей с минутным/5-минутным timeframe через market_data_service.
    # current = последняя цена.
```

### 8B.6.4: `POST /notifications/telegram/test` (C-S8-4, ~2ч)

```python
# app/notification/router.py

class TelegramTestRequest(BaseModel):
    bot_token: str
    chat_id: str

@router.post("/api/v1/notifications/telegram/test")
async def telegram_test(
    request: TelegramTestRequest,
    current_user: User = Depends(get_current_user),
) -> dict:
    """
    Отправляет тестовое сообщение через Telegram bot API.
    Return: {"ok": bool, "message": str}
    """
    # httpx POST https://api.telegram.org/bot{token}/sendMessage
    # text: "Тестовое сообщение от MOEX Terminal ({timestamp})"
    # На ошибку: {"ok": false, "message": "<HTTP error / Telegram error description>"}
```

CSRF protection (POST), бюджет p95 < 3 сек (см. ТЗ).

## Задача 8B.7: S7R-CONNECTION-EVENTS-MARKET-CLOSED (W2, ~3ч)

**Цель:** Не публиковать `connection_lost` / `connection_restored` вне торговых часов MOEX (ночью / в выходные).

**Источник торгового календаря:** существующий `app/common/moex_calendar.py` (если есть) или WebSearch — ISS API endpoint `https://iss.moex.com/iss/calendar.json` (или подобный). Не вводи hard-coded расписание; используй ISS calendar или существующий сервис.

**Где фильтровать:** `app/broker/tinvest/multiplexer.py` — перед publish event'ов connection_lost/restored проверка `is_moex_open_now()`.

```python
# app/broker/tinvest/multiplexer.py (псевдокод)
async def _publish_connection_event(self, kind: str, reason: str):
    if not is_moex_open_now():
        logger.debug("MOEX closed, suppressing connection event", kind=kind)
        return
    await event_bus.publish(f"connection.{kind}", {...})
```

# Опциональные задачи

Нет. Все задачи обязательны.

# Skip-тикеты в тестах

Если ввёл `@pytest.mark.skip(reason="<причина>")` — обязательно:
1. В отчёте полный список с обоснованием.
2. Карточка в `Sprint_8_Review/backlog.md` (создать, если нет) с тикетом `S8R-<NAME>`.

Skip без карточки — **блокер** формальной приёмки.

# Тесты

```
tests/
├── test_security/
│   ├── test_crypto_iv_uniqueness.py       # 8B.2: encrypt() × 2 → IV_1 != IV_2
│   ├── test_sandbox_escape.py             # 8B.2: ≥ 10 attack vectors hypothesis-based
│   ├── test_csrf_protection.py            # 8B.2: POST/PUT/DELETE без CSRF → 403
│   ├── test_security_headers.py           # 8B.2: CSP/HSTS/X-Frame-Options в response
│   ├── test_brute_force.py                # 8B.2: 10 параллельных login → 429
│   └── test_xss_telegram_email.py         # 8B.2: user-input strategy_name экранируется
├── test_broker/
│   └── test_multiplexer_singleton.py      # 8B.3: lifespan create один экземпляр
├── test_notification/
│   ├── test_event_sync_publishers.py      # 8B.5: 5 publish-сайтов триггерят EVENT_MAP
│   └── test_market_closed_filter.py       # 8B.7: connection events вне торгов не публикуются
└── test_dashboard/
    ├── test_health_extended.py            # 8B.6.1: /health extended fields
    ├── test_balance_history_since_first.py # 8B.6.2: since_first_activity=true отрезает zeros
    ├── test_sparkline_endpoint.py         # 8B.6.3: /market-data/sparkline happy/error
    └── test_telegram_test_endpoint.py     # 8B.6.4: /notifications/telegram/test mock bot
```

**Фикстуры (уже есть в `tests/conftest.py`):** `db_session`, `test_user`, `test_admin_user` (от DEV-1 W1), `mock_broker`, `mock_event_bus`, `httpx_mock`.

# Integration Verification Checklist

> Без полного прохождения этого чеклиста ARCH-ревью НЕ примет работу. Sprint 5 показал: класс реализован, но не вызывается в runtime = техдолг.

Для **каждой** новой сущности:

- [ ] **8B.1 (bandit/safety):** Workflow прогнан хотя бы 1 раз на этой ветке (зелёный или с задокументированными ignores). Скриншот/URL run в отчёте.
- [ ] **8B.2 (security audit):** Файл `Спринты/Sprint_8/security_audit_s8.md` создан, все 6 секций заполнены конкретикой (file:line + pytest-evidence).
- [ ] **8B.3 (multiplexer singleton):**
  - `grep -rn "TInvestMultiplexer(" app/` показывает **ровно 1** вызов конструктора — в `app/main.py` lifespan.
  - `grep -rn "app.state.tinvest_multiplexer" app/` показывает использование в `broker/service.py`, `broker/router.py`, тестах.
  - `grep -rn "self._mux\s*=\s*TInvestMultiplexer" app/` — **0 findings** (адаптер больше не создаёт свой mux).
- [ ] **8B.4 (require_admin smoke):** Для каждого admin-only endpoint в `security_audit_s8.md` указан pytest, который проверяет 403 от non-admin.
- [ ] **8B.5 (event sync publishers):**
  - `grep -rn "create_notification.*session_recovered" app/` → найдено.
  - `grep -rn "create_notification.*backtest_completed" app/backtest/jobs.py` → найдено на :226 или рядом.
  - `grep -rn "create_notification.*daily_stats" app/scheduler/` → найдено.
  - `grep -rn "create_notification.*corporate_action" app/corporate_actions/` → найдено.
  - `grep -rn "create_notification.*price_alert" app/market_data/price_alert_monitor.py` → найдено.
  - `EVENT_MAP` содержит ровно 17 ключей (12 + 5 новых).
- [ ] **8B.6.1 (/health extended):** `grep -rn '"/api/v1/health"' app/` показывает endpoint. Response содержит все 7 полей (status, version, database, cb_state, tinvest_connected, scheduler_running, scheduler_jobs).
- [ ] **8B.6.2 (balance/history):** `grep -rn "since_first_activity" app/` → найдено.
- [ ] **8B.6.3 (/sparkline):** `grep -rn "/market-data/sparkline" app/` → найдено. `Depends(get_current_user)` присутствует.
- [ ] **8B.6.4 (/telegram/test):** `grep -rn "/notifications/telegram/test" app/` → найдено. CSRF + `Depends(get_current_user)` присутствуют.
- [ ] **8B.7 (market closed filter):** В `app/broker/tinvest/multiplexer.py` есть проверка `is_moex_open_now()` перед publish connection events. Тест `test_market_closed_filter.py` проходит.
- [ ] **Cross-DEV contracts** (секция 5 отчёта): C-S8-1, C-S8-2, C-S8-3, C-S8-4, C-S8-6, C-S8-9 как поставщик подтверждены. C-S8-5 совместно с BACK1. `require_admin` как потребитель — подтверждён или явно отложен.
- [ ] **Если точка вызова не найдена** — `⚠️ NOT CONNECTED` в отчёте + указать следующую задачу/спринт.

# Формат отчёта (МАНДАТНЫЙ)

**2 файла**, каждый — 9 секций до 400 слов по шаблону.

1. **`Спринты/Sprint_8/reports/DEV-2_BACK2_W1.md`** — после задач 8B.1, 8B.2, 8B.3, 8B.4.
2. **`Спринты/Sprint_8/reports/DEV-2_BACK2_W2.md`** — после задач 8B.5, 8B.6, 8B.7.

**Содержимое каждого файла (9 секций):**

```markdown
## DEV-2 отчёт — Sprint 8, W<X>: <короткое название>

### 1. Что реализовано
- <bullet list, 5-10 пунктов>

### 2. Файлы
- **Новые:** `<путь>`
- **Изменённые:** `<путь>`
- **Удалённые:** `<путь>`

### 3. Тесты
- Backend: X / Y passed (фактическое число; сравни с baseline 1024).
- Если failed → краткий диагноз.

### 4. Integration points
- `<ClassName>.<method>` вызывается из `<file:line>` ✅
- `<ClassName>.<method>` — ⚠️ **NOT CONNECTED**, требуется задача <X.Y>

### 5. Контракты для других DEV
- **Поставляю:** C-S8-1 — `<endpoint/signature>` — потребитель FRONT2
- **Использую:** `require_admin` от DEV-1 — контракт соблюдён

### 6. Проблемы / TODO
- <известные ограничения, отложенные сценарии>

### 7. Применённые Stack Gotchas
- `Gotcha <N>` (`gotcha-NN-<slug>.md`): <одно предложение>

### 8. Новые Stack Gotchas (если обнаружены)
- симптом / причина / правило / related_files

### 9. Использование плагинов
- pyright-lsp: <использован / fallback>
- context7: <запрошена документация для: bandit, safety, APScheduler, Argon2id, FastAPI middleware>
- WebSearch: <темы: OWASP 2023, MOEX calendar, ...>
- code-review: <выполнен / нет>
- superpowers TDD: <использован для 8B.3, 8B.5>
```

**НЕ возвращай в чате:** полный код реализованных файлов, лог tool-вызовов, длинные обоснования. Только сводка ≤ 400 слов на каждый файл отчёта.

# Alembic-миграция

**Не требуется** для задач 8B.* — все изменения работают на существующих таблицах.

> Исключение: если в задаче 8B.5 `daily_stats` потребуется новая таблица для агрегатов (вместо вычисления on-the-fly из `LiveTrade`/`TradingSession`) — определи семантику в W2 и согласуй с ARCH ДО создания миграции. Рекомендуется: считать on-the-fly, без новой таблицы.

# Чеклист перед сдачей

- [ ] Все задачи (8B.1, 8B.2, 8B.3, 8B.4 для W1; 8B.5, 8B.6, 8B.7 для W2) реализованы.
- [ ] Опциональные задачи — нет.
- [ ] Тесты зелёные: `cd Develop/backend && .venv/bin/python -m pytest tests/ -q` → 0 failures (число тестов сохранено в отчёте, ≥ baseline 1024).
- [ ] Линтер: `ruff check app/` → 0 issues.
- [ ] Type-check: `pyright app/` (или fallback `mypy app/`) → 0 errors на изменённых файлах.
- [ ] bandit: 0 medium+ findings (или задокументированы в `.banditignore`).
- [ ] safety: 0 critical CVE (или задокументированы в `safety_policy.yml`).
- [ ] **Integration Verification Checklist полностью пройден** — все 13 пунктов выше.
- [ ] **Формат отчёта соблюдён** — 9 секций в каждом из 2 файлов отчёта.
- [ ] **Отчёты сохранены как файлы:** `reports/DEV-2_BACK2_W1.md`, `reports/DEV-2_BACK2_W2.md`.
- [ ] **Cross-DEV contracts:** C-S8-1, C-S8-2, C-S8-3, C-S8-4, C-S8-6, C-S8-9 как поставщик подтверждены в секции 5; C-S8-5 (совместно с BACK1) подтверждён; `require_admin` (потребитель) — статус указан.
- [ ] **Stack Gotchas:** минимум 2 применённых ловушки в секции 7 каждого отчёта.
- [ ] **Плагины:** pyright-lsp вызван после каждого .py Edit/Write; context7 — для bandit/safety/APScheduler/Argon2id/FastAPI middleware; WebSearch — OWASP 2023 + MOEX calendar; code-review — после security блока и после multiplexer singleton; superpowers TDD — для 8B.3 и 8B.5.
- [ ] **Skip-тикеты:** все `@pytest.mark.skip` имеют карточки в backlog.
- [ ] Миграций нет (или согласовано с ARCH).
- [ ] **`Sprint_8/changelog.md` обновлён немедленно** после каждого блока изменений.
- [ ] **`Sprint_8/sprint_state.md`** отражает прогресс W1 → W2.
- [ ] **`security_audit_s8.md`** создан и заполнен по 6 направлениям.
- [ ] **Чувствительные данные:** `.env` / токены / ключи **не закоммичены**; `.gitignore` проверен.
