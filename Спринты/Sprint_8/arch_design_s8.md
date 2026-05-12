# ARCH-design Sprint 8 — M4 Production-ready

> **Создан:** 2026-05-12 (W0 ARCH-design phase).
> **Источник:** `prompt_ARCH_design.md` (8 секций), `Sprint_8_Review/backlog.md` (25+ карточек), фактический preflight + grep code-base.
> **Статус:** черновик, ожидает утверждения заказчика (gate W0 → W1).
>
> Все пункты, помеченные **⚠️ TODO**, требуют решения заказчика перед запуском DEV-агентов.

---

## Tested baseline (на старте S8, 2026-05-12)

| Слой | Значение | Источник |
|------|----------|----------|
| Backend pytest всех | **1024 / 0 failed** | `pytest tests/` |
| Backend pytest unit | 750 / 0 | `pytest tests/unit/` |
| Backend ruff | 0 issues | `ruff check .` |
| Backend mypy | 0 errors (notes ok) | `mypy app/` |
| Frontend vitest | **468 / 0 failed** | `pnpm vitest run` |
| Frontend tsc | 0 errors | `pnpm tsc --noEmit` |
| Frontend lint | 0 errors / **9 warnings** | `pnpm lint` (известный долг → `S7R-FE-LINT-WARNINGS-CLEANUP`) |
| Playwright nightly | 142 passed / 0 failed / 3 skip | run #25736055151 (schedule 13:00 MSK 12.05) |
| **Backend coverage** | **71%** (12679 строк, 3632 непокрыто) | `pytest --cov=app` |

Coverage gap до цели 80%: **≈9% = ≈1140 строк** нужно дозакрыть.

---

## 1. Backlog приоритезация

### 1.1 Источник

`Sprint_8_Review/backlog.md` — 25+ карточек. Группировка по эпикам, ролям, оценка часов.

### 1.2 Финальная приоритизированная таблица

| # | Карточка | Роль | Эпик | Часы | Приоритет |
|---|----------|------|------|------|-----------|
| 1 | `S7R-DRAWING-EDITING` | FRONT1 | Charts editing | 16 | **medium-high** |
| 2 | `S7R-STRATEGY-STATUS-CHANGE-UI` | FRONT2 | Strategy status | 8 | **medium-high** |
| 3 | `S7R-API-PAGINATED-TYPE-MISMATCH` | FRONT2 + BACK | API contract | 6 | **medium-high** |
| 4 | `S7R-MULTIPLEXER-SINGLETON` | BACK1 | Broker stability | 4 | medium |
| 5 | `S7R-FRONTEND-ERROR-BOUNDARY-MISSING` | FRONT2 | Defensive UI | 4 | medium |
| 6 | `S7R-E2E-7.3-MISSING` (export) | QA | E2E coverage | 3 | medium |
| 7 | `S7R-E2E-7.9-MISSING` (backup) | QA | E2E coverage | 4 | medium |
| 8 | `S7R-E2E-7.13-MISSING` (5 event_type) | QA | E2E coverage | 6 | medium |
| 9 | `S7R-E2E-7.14-MISSING` (TG callbacks) | QA | E2E coverage | 3 | medium |
| 10 | `S7R-E2E-7.16-MISSING` (analytics) | QA | E2E coverage | 4 | medium |
| 11 | `S7R-E2E-7.17-MISSING` (bg backtest) | QA | E2E coverage | 3 | medium |
| 12 | `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` | BACK2 + FRONT2 | Dashboard | 4 | medium |
| 13 | `S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE` | BACK2 + FRONT2 | Dashboard | 3 | medium |
| 14 | `S7R-WIDGET-SPARKLINE-24H` | BACK2 + FRONT2 | Dashboard | 4 | medium |
| 15 | `S7R-WIZARD-TELEGRAM-TEST-BUTTON` | BACK2 + FRONT2 | Wizard | 3 | medium |
| 16 | `S7R-DRAWING-INTRADAY-COORDS` | FRONT1 | Charts editing | 6 | medium |
| 17 | `S7R-GRID-HEATMAP-ENTRYPOINT` | FRONT2 | Grid Search | 2 | medium |
| 18 | `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE` | BACK1 | Coverage | 3 | medium |
| 19 | `S7R-WIDGETS-UNIT-COVERAGE` | FRONT2 | Coverage | 4 | medium ↑ от low (нужен S8 80%) |
| 20 | `S7R-CI-NODE24-MIGRATION` | OPS | CI maintenance | 2 | low |
| 21 | `S7R-FE-LINT-WARNINGS-CLEANUP` | FRONT1 + FRONT2 | CI maintenance | 4 | low |
| 22 | `S7R-HEALTH-WS-MIGRATION` | BACK2 + FRONT2 | Dashboard | 4 | low |
| 23 | `S7R-MULTICURRENCY-TOGGLE` | BACK2 + FRONT2 | Dashboard | 6 | low |
| 24 | `S7R-BG-BACKTEST-AUTOCOLLAPSE` | FRONT2 | Background tasks UX | 2 | low |
| 25 | `S7R-HISTOGRAM-MANTINE-TOOLTIP` | FRONT1 | Charts polish | 2 | low |
| 26 | `S7R-CONNECTION-EVENTS-MARKET-CLOSED` | BACK2 | Notification filter | 3 | low |
| 27 | `S7R-STRATEGY-STATUS-PAUSED-FILTER` | FRONT2 | Strategy status | 1 | low (зависит от #2) |
| 28 | `S7R-STRATEGY-STATUS-ENUM-DRIFT` | BACK1 migration | Strategy status | 4 | low |
| 29 | `S6R-AICHAT-APPLY-MOCK` | QA | Pre-existing skip | 2 | low (decide) |
| 30 | `S5R-BLOCKLY-MODE-B-MODAL/CHECK` | FRONT2 | Pre-existing skip | ⚠️ TODO | ⚠️ TODO |

**Итого часов:** ≈130 часов = ≈16 рабочих дней на 1 DEV. С 4 параллельными DEV-ролями + QA + OPS ≈ 4 рабочих дня нетто. + W0 (1 день) + W3 (2 дня) = **7 рабочих дней спринта**. Это укладывается в обычную длительность спринта (10-14 рабочих дней) с запасом на perfromance/security аудиты.

### 1.3 Эпики (группировка для DEV-промптов)

- **Эпик A — Charts editing** (FRONT1, 22ч): #1 + #16 + #25 + #21 (часть)
- **Эпик B — Strategy status** (FRONT2 + BACK1, 13ч): #2 + #27 + #28
- **Эпик C — API contract + ErrorBoundary** (FRONT2 + BACK, 10ч): #3 + #5
- **Эпик D — Broker stability** (BACK1, 4ч): #4
- **Эпик E — Dashboard widgets** (BACK2 + FRONT2, 21ч): #12 + #13 + #14 + #22 + #23
- **Эпик F — Wizard polish** (BACK2 + FRONT2, 3ч): #15
- **Эпик G — Grid Search polish** (FRONT2, 2ч): #17
- **Эпик H — Coverage gaps + perf** (BACK1 + BACK2 + FRONT2, 11ч): #18 + #19 + см. секцию 2
- **Эпик I — E2E missing 6 spec'ов** (QA, 23ч): #6–#11
- **Эпик J — CI maintenance** (OPS + FRONT, 6ч): #20 + #21
- **Эпик K — Pre-existing skips decision** (⚠️ TODO): #29 + #30
- **Эпик L — Notification filter** (BACK2, 3ч): #26
- **Эпик M — UX финальный юзабилити + Docs + 8.R** (W3, 16ч)

### 1.4 ⚠️ TODO для заказчика

- **#30 `S5R-BLOCKLY-MODE-B`** — реализовать mode B (template) или удалить spec? Зависит от UX-roadmap.
- **#29 `S6R-AICHAT-APPLY-MOCK`** — дополнить мок реалистичным `block_xml` или удалить skip?

---

## 2. Coverage план

### 2.1 Текущее состояние по слоям

**TOTAL: 71%**. Цель: 80%. Gap: ≈1140 строк.

#### Критические пути (M3 trading core) — все ≥ 70%, кроме одного:

| Модуль | Coverage | Строк не покрыто | Приоритет |
|--------|---------:|----------------:|-----------|
| `trading/engine.py` | 75% | 137 / 546 | +5% до 80% |
| `trading/runtime.py` | 73% | 114 / 416 | +7% до 80% |
| `trading/service.py` | **51%** | **162 / 334** | **+29% — приоритет 1** |
| `trading/paper_engine.py` | 74% | 28 / 109 | +6% до 80% |
| `trading/risk_monitor.py` | 91% | 16 / 181 | ✅ |
| `trading/ws_sessions.py` | 71% | 45 / 154 | +9% до 80% |
| `circuit_breaker/engine.py` | 89% | 26 / 232 | ✅ |
| `circuit_breaker/service.py` | 81% | 15 / 77 | ✅ (на грани) |
| `circuit_breaker/router.py` | 60% | 14 / 35 | router-тесты |
| `broker/tinvest/adapter.py` | **24%** | **299 / 394** | **+56% — приоритет 1** |
| `broker/tinvest/multiplexer.py` | 87% | 26 / 201 | ✅ |
| `broker/moex_iss/client.py` | 68% | 43 / 134 | +12% до 80% |
| `broker/router.py` | 37% | 80 / 127 | router-тесты |
| `broker/service.py` | 67% | 52 / 156 | +13% до 80% |
| `sandbox/executor.py` | 84% | 17 / 106 | ✅ |
| `sandbox/ast_analyzer.py` | 93% | 4 / 57 | ✅ |
| `market_data/service.py` | **50%** | **200 / 398** | **+30% — приоритет 1** |
| `market_data/router.py` | 62% | 46 / 121 | router-тесты |
| `market_data/bond_service.py` | 39% | 85 / 140 | +41% до 80% |
| `backtest/router.py` | **25%** | **314 / 416** | **+55% — приоритет 1** |
| `backtest/engine.py` | 55% | 105 / 234 | +25% до 80% |
| `backtest/service.py` | 71% | 33 / 113 | +9% до 80% |
| `backtest/ws.py` | 65% | 31 / 88 | +15% до 80% |
| `notification/dispatchers.py` | **0%** | **33 / 33** | **тест 0 → 80% — приоритет 0** |
| `notification/service.py` | 86% | 28 / 197 | ✅ |
| `notification/router.py` | 51% | 69 / 141 | +29% до 80% |
| `notification/telegram_webhook.py` | 74% | 110 / 424 | +6% до 80% |
| `auth/service.py` | 91% | 8 / 89 | ✅ |
| `auth/router.py` | 67% | 28 / 85 | +13% до 80% |
| `ai/service.py` | 55% | 70 / 155 | +25% до 80% |
| `ai/router.py` | 51% | 47 / 96 | +29% до 80% |
| `strategy/service.py` | **52%** | **103 / 215** | **+28% — приоритет 1** |
| `strategy/router.py` | 52% | 64 / 134 | +28% до 80% |
| `tax/service.py` | 76% | 50 / 210 | +4% до 80% |
| `scheduler/service.py` | 44% | 92 / 165 | +36% до 80% |

### 2.2 План дозакрытия (приоритет 0 → 1 → 2)

**Приоритет 0 — единственный модуль 0% coverage:**
- `notification/dispatchers.py` — 33 строки, написать unit-тесты для in-app / telegram / email dispatcher entrypoint. ≈ 4 часа.

**Приоритет 1 — критические пути (impact на M3 SLA):**
- `broker/tinvest/adapter.py` — 24% (299 не покрыто). Преобладание `get_balance`/`get_positions`/`get_operations`/`place_order`/`cancel_order` без unit-моков. ≈ 16 часов (моки tinkoff API + happy path / 4 error path для каждого метода).
- `trading/service.py` — 51% (162 не покрыто). `start_session`/`stop_session`/`pause`/`resume`/`get_session`/`get_dashboard`/`get_stats` (test_service.py покрыл только часть). ≈ 12 часов.
- `market_data/service.py` — 50% (200 не покрыто). OHLCV cache, prefetch, ISS+TInvest fallback. ≈ 12 часов.
- `backtest/router.py` — 25% (314 не покрыто!). FastAPI endpoint тесты (`POST /backtest`, `GET /:id/results`, `POST /grid`, `GET /list`, `POST /:id/rerun`, `POST /:id/export`, etc.). ≈ 12 часов.
- `strategy/service.py` — 52% (103 не покрыто). CRUD + versioning. ≈ 8 часов.
- `backtest/engine.py` — 55% (105 не покрыто). Backtrader integration + metrics computation paths. ≈ 8 часов.

**Приоритет 2 — secondary modules (помогут добрать 80% total):**
- `auth/router.py` 67% → 80% (≈ 3ч)
- `notification/router.py` 51% → 80% (≈ 4ч)
- `notification/telegram_webhook.py` 74% → 80% (≈ 3ч)
- `ai/service.py` 55% → 80% (≈ 5ч)
- `ai/router.py` 51% → 80% (≈ 5ч)
- `strategy/router.py` 52% → 80% (≈ 5ч)
- `circuit_breaker/router.py` 60% → 80% (≈ 3ч)
- `broker/router.py` 37% → 80% (≈ 6ч)
- `broker/service.py` 67% → 80% (≈ 4ч)
- `market_data/router.py` 62% → 80% (≈ 4ч)
- `scheduler/service.py` 44% → 80% (≈ 6ч)
- `tax/service.py` 76% → 80% (≈ 2ч)

**Итого часов:** 4 (P0) + 68 (P1) + 50 (P2) ≈ **122 часа** на coverage. Распределение DEV: BACK1 (≈60ч), BACK2 (≈40ч), 1 человек-неделя ≈ 22ч.

### 2.3 Методология

- **Unit-тесты** для service-методов через `pytest-asyncio` + sqlite memory DB + `unittest.mock.AsyncMock` для внешних адаптеров.
- **Integration-тесты** для router-endpoint'ов через `httpx.AsyncClient` + JWT-fixture (уже есть в `tests/conftest.py`).
- **Mock-стратегия для tinvest:** не реальный gRPC, а fixture-based responses (как сейчас в `tests/test_broker_tinvest/`).
- **CI gate:** добавить `pytest --cov=app --cov-fail-under=80` в `.github/workflows/ci.yml` после стабилизации.

### 2.4 ⚠️ TODO для заказчика

- **Coverage gate в CI:** активировать `--cov-fail-under=80` в S8 (после довода) или отложить до S9? Активация раньше срывает merge — рекомендую включить **в W3** S8.

---

## 3. Security audit план

### 3.1 Crypto (AES-256-GCM для broker keys + JWT)

**Цитата из ТЗ (см. `technical_specification.md` раздел Security):** ключи API брокеров хранятся зашифрованными AES-256-GCM с уникальным IV per encryption.

Чек-лист:
- [ ] **IV uniqueness:** `app/common/crypto.py` использует `secrets.token_bytes(12)` для IV — проверить, что нет переиспользования.
- [ ] **Key rotation:** определить процедуру ротации master-key (есть ли в коде? нужен ли CLI `python -m app.cli.rotate_master_key`?).
- [ ] **JWT secret length ≥ 32 bytes:** текущий warning в pytest «23 bytes long, below recommended». Поднять до 32+ в `.env.example` и `config.py`. Production .env — отдельный коммит без push (см. CLAUDE.md правило).
- [ ] **Argon2id parameters:** memory_cost / time_cost / parallelism соответствуют OWASP recommendations 2023 (≥ 19 MiB, ≥ 2 iters, parallelism ≥ 1).
- [ ] **Refresh token storage:** plain в БД? Hash? Если plain — задокументировать угрозу.

**Инструмент:** ручной аудит + pytest custom-тест на `crypto.encrypt(); crypto.encrypt(); IV_1 != IV_2`.

### 3.2 Sandbox escape (RestrictedPython)

Чек-лист:
- [ ] **`_safe_import` whitelist:** `app/sandbox/executor.py` — проверить, что не разрешён `os`/`subprocess`/`socket`/`ctypes`/`importlib` напрямую.
- [ ] **`__builtins__` доступ:** попытка `__builtins__["__import__"]("os").system("rm -rf /")` блокируется?
- [ ] **`object.__subclasses__()`:** атака `().__class__.__bases__[0].__subclasses__()` ищет subprocess.Popen → блокируется?
- [ ] **`compile()` / `exec()` / `eval()`:** запрещены?
- [ ] **Resource limits:** timeout на execution, лимит памяти? (текущая реализация в `sandbox/executor.py`).

**Инструмент:** pytest + hypothesis для fuzzing exploit-payloads. Целевой spec: `tests/security/test_sandbox_escape.py` с ≥ 10 attack vectors.

### 3.3 CSRF + Headers

Чек-лист CSRF:
- [ ] **Double-submit cookie:** `app/middleware/csrf.py` — pattern активен на всех POST/PUT/DELETE?
- [ ] **SameSite:** `Strict` или `Lax`? Strict ломает OAuth-redirects, но Lax даёт CSRF-vulnerability на GET с side-effects.
- [ ] **Token rotation:** на каждый logout?

Чек-лист Headers:
- [ ] **CSP** (Content-Security-Policy): default-src 'self'; script-src 'self' 'unsafe-inline' (если Mantine inline-styles); img-src https://ratesvy.t-investments.ru (T-Invest CDN logos).
- [ ] **HSTS:** `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`.
- [ ] **X-Frame-Options:** `DENY`.
- [ ] **X-Content-Type-Options:** `nosniff`.
- [ ] **Referrer-Policy:** `strict-origin-when-cross-origin`.
- [ ] **Permissions-Policy:** запрет camera/microphone/geolocation.

**Инструмент:** pytest на `httpx.AsyncClient` + assertion на наличие headers в response.

### 3.4 Brute-force

Чек-лист:
- [ ] **Rate limit `/auth/login`:** `app/middleware/rate_limit.py` — лимит 3-5 попыток/мин? Persistent через Redis или in-memory?
- [ ] **Account lockout:** после N неудач — temporary lock?
- [ ] **CAPTCHA / 2FA:** есть ли trigger при подозрительной активности?

**Инструмент:** pytest с 10 параллельными неверными login → проверка 429 Too Many Requests.

### 3.5 SQL Injection + XSS

Чек-лист:
- [ ] **SQL injection:** все запросы через SQLAlchemy ORM (нет raw SQL без параметризации). Поиск через `grep -rn 'text(' app/` + `grep -rn '.execute(' app/`.
- [ ] **XSS в Telegram-сообщениях:** user-input (например `strategy_name`) экранируется при формировании HTML-сообщений?
- [ ] **XSS в email-шаблонах:** аналогично.

### 3.6 ⚠️ TODO для заказчика

- **Security audit instrument choice:** ручной аудит + pytest или подключить `bandit` (статический анализ Python security) и `safety` (CVE-сканер зависимостей) в CI? Рекомендую: оба в S8 как W2 поток (4ч setup + анализ).

---

## 4. Performance план

### 4.1 Метрики из ТЗ (дословно)

**Цитата из `technical_specification.md` §Производительность:**

> Целевые показатели:
> - Время загрузки дашборда (первый paint): < 2 секунд
> - Время от сигнала стратегии до выставления ордера через broker: p95 < 500 мс
> - Время отклика Telegram-команды (от webhook до reply): < 3 секунд

### 4.2 Методология измерения

#### Дашборд (Frontend)
- **Инструмент:** Chrome DevTools Performance + Lighthouse CI в Playwright.
- **Метрика:** Largest Contentful Paint (LCP), Time to Interactive (TTI).
- **Сценарий:** залогиненный пользователь с ≥ 5 активными сессиями (моки в `api_mocks.ts`) открывает `/dashboard`.
- **Baseline:** собрать на текущем `develop`.
- **CI gate:** Lighthouse score performance ≥ 80.

#### Signal → place_order (Backend)
- **Инструмент:** `structlog` event с `duration_ms` на критических точках:
  - `MarketDataService.on_candle()` → start_timer
  - `SignalProcessor.process()` → mid_check
  - `OrderManager.place_order()` → finish_timer
- **Метрика:** p95 < 500мс по 1000 итерациям в нагрузочном тесте.
- **Инструмент:** `pytest-benchmark` + сценарий «1000 искусственных свечей подряд».
- **Baseline:** собрать в W1.

#### Telegram-команда (Backend)
- **Инструмент:** `structlog` timing в `TelegramWebhookHandler._handle_*`.
- **Метрика:** время от приёма webhook до отправки reply через bot API. p95 < 3000мс.
- **Сценарий:** 5 команд (/status, /positions, /balance, /close, /closeall) — каждая 100 раз с mock-T-Invest.

### 4.3 Инструментация

Добавить decorator `@timed_event("event_name")` в `app/common/observability.py` (новый файл):

```python
@timed_event("signal.process")
async def process_candle(self, candle: CandleData) -> Signal | None:
    ...
```

Decorator пишет в structlog с `duration_ms` после `await`. В W3 — экспорт в Prometheus/Grafana опционально (если будет инфраструктура).

### 4.4 Регрессионная защита

После сбора baseline в W1 — добавить assertion в `pytest-benchmark`:

```python
@pytest.mark.benchmark(group="signal_to_order")
def test_signal_to_order_p95_under_500ms(benchmark, ...):
    result = benchmark(...)
    assert result.stats.percentiles[95] < 0.5  # seconds
```

В CI: если новый PR увеличивает p95 > 10% от baseline → fail.

### 4.5 ⚠️ TODO для заказчика

- **Lighthouse CI:** подключить в `playwright-nightly.yml`? Это +2 минуты к workflow, но даёт автоматический monitoring frontend perf.
- **Prometheus/Grafana export:** scope S8 или S9? Сейчас рекомендую только structlog logs, без внешних сервисов.

---

## 5. 6 missing E2E spec'ов

Каждый из 6 spec'ов основывается на e2e_test_plan_s7.md. План QA-агенту:

### 5.1 `s7-export.spec.ts` (S7R-E2E-7.3)
- **Сценарии:** download CSV (assert content-type + содержит «Тикер,»); download PDF (assert `%PDF-` magic + size ≥ 5 KB).
- **Моки:** `mockBacktestResults({id: 1, ticker: 'SBER', metrics: ...})`.
- **Использует:** `page.waitForEvent('download')`.
- **Edge case:** click на disabled-кнопку (если бэктест в статусе running) → нет download.

### 5.2 `s7-backup.spec.ts` (S7R-E2E-7.9)
- **Сценарии:** spawn child_process `python -m app.cli.backup create` → проверка файла в `data/backups/`; `python -m app.cli.backup restore <file>` → DB restored.
- **Tricky:** Playwright не подходит для backend CLI; перенести в `tests/integration/test_backup_cli.py` (pytest, не E2E).
- **⚠️ TODO:** заказчик подтверждает — оставить в Playwright (child_process) или перенести в pytest?

### 5.3 `s7-events.spec.ts` (S7R-E2E-7.13)
- **Сценарии:** через mock-WS (или endpoint `_test/emit-event` если есть) эмулировать 5 event_type → проверка рендера в `[data-testid="notification-bell"]`:
  1. `trade.opened` → badge показывает «Позиция открыта»
  2. `order.partial_fill` → «Частичное исполнение»
  3. `order.error` → «Ошибка выставления» (severity=warning)
  4. `positions.closed_all` → «Все позиции закрыты»
  5. `connection.lost`/`connection.restored` → «Соединение потеряно/восстановлено»
- **Моки:** `mockWSChannel('notifications', [...frames])`.
- **⚠️ TODO:** реализовать `_test/emit-event` endpoint в `app/notification/router.py` (только в DEBUG-режиме) или использовать прямой mock-WS из Playwright?

### 5.4 `s7-tg-callbacks.spec.ts` (S7R-E2E-7.14)
- **Сценарии:** симуляция callback `{callback_data: "view_session:42"}` → редирект на `/sessions/42`. Аналогично `view_chart:SBER:5m`.
- **Моки:** `mockTelegramCallback({...})`.
- **Tricky:** callback приходит через webhook, не от UI. Spec симулирует `page.goto('/sessions/42?from=tg')` и проверяет рендер.

### 5.5 `s7-backtest-analytics.spec.ts` (S7R-E2E-7.16)
- **Сценарии:**
  1. Hover зоны на equity-curve → tooltip с trade detail.
  2. Click зоны → панель `[data-testid="trade-detail-panel"]` показывает сделку.
  3. Гистограмма `[data-testid="pnl-histogram"]` рендерится (≥ 1 bar).
  4. Donut `[data-testid="win-loss-donut"]` рендерится (2 сегмента).
- **Моки:** `mockBacktestWithTrades([{...}])`.

### 5.6 `s7-bg-backtest.spec.ts` (S7R-E2E-7.17)
- **Сценарии:**
  1. POST /backtest/run в фоне → toast «Запущен в фоне».
  2. Badge `[data-testid="bg-backtest-badge"]` показывает счётчик 1.
  3. Mock WS frame `{event: "completed"}` → badge декремент.
  4. Cap=3 параллельных → 4-й запуск → toast «Превышен лимит».
- **Моки:** `mockWSChannel('backtest:N', frames)`.

### 5.7 Общие требования

- Использовать `e2e/fixtures/api_mocks.ts` — расширить новыми helpers.
- Каждый spec ≤ 200 строк, без real-backend (CI=true).
- Использовать `data-testid` (не CSS-классы).
- Добавить в `playwright-nightly.yml` после стабилизации.

---

## 6. 13 event_type верификация

> **Цитата из `project_state.md:105` (дословно):**
> «Все 13 event_type из NotificationSettingsPage реально генерируют уведомления при соответствующих runtime-событиях. Для каждого event_type: включить Telegram + Email в настройках → вызвать событие → проверить доставку во все 3 канала.»

### 6.1 EVENT_MAP в `app/notification/service.py:32-107` — **12 event_type** (не 13)

| # | channel/event_name | notification.event_type | severity | Publisher (factual grep) |
|---|--------------------|-------------------------|----------|--------------------------|
| 1 | `session.started` | `session_started` | info | `trading/runtime.py:333` |
| 2 | `session.stopped` | `session_stopped` | info | `trading/runtime.py:380` |
| 3 | `order.placed` | `order_placed` | info | `trading/runtime.py:1009` |
| 4 | `trade.filled` | `trade_filled` | success | `trading/runtime.py:1030` |
| 5 | `trade.closed` | `trade_closed` | success | `trading/runtime.py:1050` + `risk_monitor.py:390` |
| 6 | `cb.triggered` | `cb_triggered` | critical | `trading/runtime.py:957` |
| 7 | `positions.closed_all` | `all_positions_closed` | warning | `trading/engine.py:1152` |
| 8 | `trade.opened` | `trade_opened` | info | `trading/engine.py:879, 1382` |
| 9 | `order.partial_fill` | `partial_fill` | info | `trading/engine.py:1352` |
| 10 | `order.error` | `order_error` | warning | `trading/engine.py:979` |
| 11 | `connection.lost` | `connection_lost` | warning | `broker/tinvest/multiplexer.py:271` |
| 12 | `connection.restored` | `connection_restored` | info | `broker/tinvest/multiplexer.py:237` |

### 6.2 ⚠️ Discrepancy: 12 в EVENT_MAP vs 13 в NotificationSettingsPage

Найти 13-й тип в frontend (`NotificationSettingsPage.tsx`) — либо удалить из UI, либо добавить в EVENT_MAP. **⚠️ TODO:** провести аудит `frontend/src/pages/NotificationSettingsPage.tsx` и `frontend/src/api/notificationApi.ts` в W0/W1.

### 6.3 Plan верификации (W3 8.R)

Для каждого из 12 event_type написать интеграционный тест в `tests/integration/test_notification_e2e.py`:

```python
async def test_trade_opened_delivers_to_3_channels(...):
    # 1. user enables telegram + email + in-app for event_type=trade_opened
    # 2. publish event_bus.publish("trade.opened", {strategy_name="X", ticker="SBER", ...})
    # 3. assert: in-app Notification создана, telegram_client.send_message вызван,
    #            email_client.send вызван — все три с правильно подставленным template
```

12 тестов × ≈30 минут = 6 часов.

### 6.4 ⚠️ TODO для заказчика

- **13-й event_type:** найти, удалить или добавить. Решение принять в W0.

---

## 7. Documentation

### 7.1 Файлы для обновления / создания

| Файл | Действие | Содержание | Часы |
|------|----------|-----------|-----:|
| `README.md` (корневой) | Update | Описание проекта, getting started (clone + setup_macos.sh), ссылка на deployment_guide | 2 |
| `Develop/INSTALL.md` | Update | Системные зависимости (ta-lib, pango, cairo), Python 3.11+ venv, T-Invest SDK patched install (как в ci.yml) | 1 |
| `Документация по проекту/deployment_guide.md` | **CREATE** | Docker compose (backend + frontend + nginx + sqlite volume), systemd unit, SSL через certbot, backup CLI cron | 6 |
| `Sprint_8/changelog.md` | Update по ходу | Финальная сводка спринта | (ongoing) |
| `Спринты/project_state.md` | Final mark | M4 ✅ Production-ready | 1 |
| `Документация по проекту/functional_requirements.md` | Update | Финальная версия v2.5 (отметка production-ready) | 2 |
| `Документация по проекту/technical_specification.md` | Update | v1.5 с реальными performance метриками из секции 4 | 2 |
| `Документация по проекту/development_plan.md` | Update | M4 ✅, roadmap S9+ | 1 |
| `Develop/CLAUDE.md` | Polish | Уточнить правила плагинов после S7-эксперимента | 1 |
| `Develop/stack_gotchas/INDEX.md` | Update | Добавить новые gotchas из S7 closeout (lightweight-charts few-points, paginated type mismatch) | 1 |

**Итого:** ≈17 часов на documentation в W3.

### 7.2 ⚠️ TODO для заказчика

- **Deployment target:** Docker + systemd на VPS? Kubernetes? Bare-metal? От этого зависит deployment_guide.md.

---

## 8. Wave breakdown + Cross-DEV contracts

### 8.1 Финальный план волн

| Wave | Длительность | Фокус | Параллельные потоки |
|------|--------------|-------|---------------------|
| **W0** | 1 день | ARCH-design (этот файл) + QA пишет e2e_test_plan_s8.md + создание prompt_DEV-N.md | ARCH + QA |
| **W1** | 4 дня | Medium-high закрытие + начало coverage + security audit + 6 missing E2E | 5 потоков параллельно |
| **W2** | 4 дня | Medium закрытие + performance testing + coverage довод | 4 потока параллельно |
| **W3** | 3 дня | Low карточки + UX тест + documentation + 8.R | 4 потока параллельно |

**Итого:** 12 рабочих дней = 2.4 рабочих недели.

### 8.2 W1 — Параллельные потоки (4 дня, 4-5 DEV-ролей)

#### Поток A (BACK1, ~30ч): Coverage P0 + P1 для критических путей
- `notification/dispatchers.py` 0% → 80%
- `broker/tinvest/adapter.py` 24% → 80% (моки tinkoff API)
- `trading/service.py` 51% → 80%

#### Поток B (BACK2, ~22ч): Security audit + S7R-MULTIPLEXER-SINGLETON
- Security audit отчёт (crypto / CSRF / headers / brute-force) — отдельный документ `security_audit_s8.md`
- `S7R-MULTIPLEXER-SINGLETON` — `app.state.tinvest_multiplexer`

#### Поток C (FRONT1, ~22ч): Charts editing эпик
- `S7R-DRAWING-EDITING` — drag/перенос/изменение углов
- `S7R-DRAWING-INTRADAY-COORDS` — sequential mode координаты

#### Поток D (FRONT2, ~18ч): API contract + ErrorBoundary + Strategy status UI
- `S7R-API-PAGINATED-TYPE-MISMATCH` audit всех `api/*.ts` + правка типов
- `S7R-FRONTEND-ERROR-BOUNDARY-MISSING` — ErrorBoundary в App.tsx + per-widget
- `S7R-STRATEGY-STATUS-CHANGE-UI` — контекстное меню + Select

#### Поток E (QA, ~23ч): 6 missing E2E
- 6 spec'ов из секции 5

**Gate W1 → W2:** все medium-high закрыты, security audit отчёт готов, 6 missing E2E зелёные, coverage P0 + P1 advanced до 80% хотя бы по 4 модулям из 6.

### 8.3 W2 — Параллельные потоки (4 дня)

#### Поток A (BACK1, ~20ч): Performance + Coverage P1 закрытие
- Performance baseline + instrumentation `@timed_event`
- Coverage P1 (`market_data/service.py`, `backtest/router.py`, `strategy/service.py`, `backtest/engine.py`)

#### Поток B (BACK2, ~18ч): Dashboard widgets backend + Notification filter
- `S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS` — `/health` extended
- `S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE` — отрезать leading zeros
- `S7R-WIDGET-SPARKLINE-24H` — новый endpoint
- `S7R-WIZARD-TELEGRAM-TEST-BUTTON` — endpoint `/notifications/telegram/test`
- `S7R-CONNECTION-EVENTS-MARKET-CLOSED` — фильтр MOEX calendar
- `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE` — paper+real параметризация

#### Поток C (FRONT2, ~16ч): Dashboard widgets frontend + Grid Heatmap + Strategy status follow-up
- 4 widget'а из эпика E (frontend интеграция endpoint'ов из потока B)
- `S7R-GRID-HEATMAP-ENTRYPOINT`
- `S7R-WIDGETS-UNIT-COVERAGE`

#### Поток D (BACK1, ~10ч): Coverage P2 (router-тесты)
- `auth/router`, `notification/router`, `broker/router`, `market_data/router`, `strategy/router`, `circuit_breaker/router`

**Gate W2 → W3:** coverage TOTAL ≥ 80%, performance метрики baseline'ed и в норме, ≥ 80% medium-карточек закрыто.

### 8.4 W3 — Финализация (3 дня)

#### Поток A (FRONT, ~10ч): Low карточки
- `S7R-CI-NODE24-MIGRATION`, `S7R-FE-LINT-WARNINGS-CLEANUP`, `S7R-HEALTH-WS-MIGRATION`, `S7R-MULTICURRENCY-TOGGLE`, `S7R-BG-BACKTEST-AUTOCOLLAPSE`, `S7R-HISTOGRAM-MANTINE-TOOLTIP`, `S7R-STRATEGY-STATUS-PAUSED-FILTER`, `S7R-STRATEGY-STATUS-ENUM-DRIFT`

#### Поток B (UX, ~8ч): Финальный юзабилити-тест
- Сценарии новый пользователь от регистрации до сделки
- Обновить `ui_checklist_s7.md` → `ui_checklist_s8.md`
- UX-баги фиксить или в S9-backlog

#### Поток C (OPS/BACK1, ~17ч): Documentation
- См. секцию 7 — 9 файлов

#### Поток D (ARCH, ~8ч): 8.R ARCH-ревью
- Code review (8 секций по образцу Sprint_6_Review)
- Метрики финальные
- 12-13 event_type интеграционные тесты
- Вердикт PASS / PASS WITH NOTES / NEED FIXES

### 8.5 Cross-DEV contracts

| # | Поставщик | Потребитель | Контракт | Формат / сигнатура |
|---|-----------|-------------|----------|--------------------|
| C-S8-1 | BACK2 (W2) | FRONT2 (W2) | Extended `GET /api/v1/health` | `{status, version, database, cb_state: 'ok'\|'warn'\|'triggered', tinvest_connected: bool, scheduler_running: bool, scheduler_jobs: int}` |
| C-S8-2 | BACK2 (W2) | FRONT2 (W2) | `GET /api/v1/market-data/sparkline?ticker=X&hours=24` | `{points: [{t: timestamp, p: number}], current: number}` |
| C-S8-3 | BACK2 (W2) | FRONT2 (W2) | Extended `GET /api/v1/account/balance/history?since_first_activity=true` | существующий формат + параметр |
| C-S8-4 | BACK2 (W2) | FRONT2 (W2) | `POST /api/v1/notifications/telegram/test` | request: `{bot_token: str, chat_id: str}`, response: `{ok: bool, message: str}` |
| C-S8-5 | BACK2 (W2) | FRONT2 (W2) | `S7R-API-PAGINATED-TYPE-MISMATCH` audit results | Список endpoint'ов с `response_model=PaginatedResponse` (известны 2: `/trading/sessions`, `/trading/sessions/{id}/trades`) + соответствие на frontend |
| C-S8-6 | BACK1 (W1) | (внутри backend) | `app.state.tinvest_multiplexer` singleton | `lifespan` создаёт один экземпляр, все `TInvestAdapter` его share'ят |

### 8.6 Stack Gotchas — кандидаты на старте S8

- `gotcha-24-lightweight-charts-few-points-rightbar.md` — из S7R-EQUITY-BY-INDEX changelog
- `gotcha-25-api-paginated-type-mismatch.md` — из S7R-API-PAGINATED-TYPE-MISMATCH (создаётся при работе над эпиком C)

---

## 9. Что НЕ делать в S8 (feature freeze)

**Запрещено** во время S8 (только стабилизация M3 → M4):

- ❌ Новые фичи трейдинга (новые типы ордеров, новые брокеры, новые типы стратегий)
- ❌ Новые AI-модели или провайдеры (Claude/OpenAI/custom остаются как есть)
- ❌ Новые drawing tools (drag editing для существующих — да, см. эпик A)
- ❌ Новые widget'ы дашборда (полировка существующих 3 — да)
- ❌ Position-aware strategies (план развития 001 — после S8)
- ❌ Realtime candle streaming в backtest (план развития 004 — после S8)
- ❌ Mode B Blockly (template) — оставить decision на S9 (см. `S5R-BLOCKLY-MODE-B-MODAL`)

Если в W1/W2 обнаружится bug, который требует архитектурного изменения — поднимать в issue, не править в S8.

---

## 10. Критерии приёмки W0 (этого документа)

- [x] Все 8 секций заполнены конкретикой (не «обсудим позже»)
- [x] 25+ карточек backlog'а получили роль / часы / эпик
- [x] 12 event_type publishers сверены с EVENT_MAP (12 ≠ 13 — TODO)
- [x] Coverage gap по каждому модулю с приоритетом (P0/P1/P2)
- [x] Security audit чек-листы по 5 направлениям
- [x] Performance метрики из ТЗ дословно + методология
- [x] 6 missing E2E с конкретными сценариями
- [x] Wave breakdown W1/W2/W3 + 6 Cross-DEV contracts
- [x] Список «Что НЕ делать в S8»
- [ ] **Заказчик утвердил документ (gate W0 → W1)**

## 11. ⚠️ TODO summary — нужны решения заказчика перед W1

### Batch 1 — ✅ принято 2026-05-12

1. **#30 `S5R-BLOCKLY-MODE-B`** → ✅ **удалить 2 spec'а** (`mode B modal opens`, `check button is disabled`). Фича удалена из UI в S5/S6, spec'ы зомби.
2. **#29 `S6R-AICHAT-APPLY-MOCK`** → ✅ **дополнить мок в W2 (~2ч)**. QA добавляет реалистичный `block_xml` в мок AI-ответа, snimaет skip.
3. **§6 13-й event_type** → ✅ **полная синхронизация UI и EVENT_MAP в W2 (новый эпик, ≈12ч)**.
   - 4 типа в EVENT_MAP, но не в UI: `session_started`, `session_stopped`, `order_placed`, `trade_filled` → добавить в `EVENT_TYPE_LABELS` (`NotificationSettingsPage.tsx:24`).
   - 5 типов в UI, но не в EVENT_MAP: `session_recovered`, `backtest_completed`, `daily_stats`, `corporate_action`, `price_alert` → подключить publish-сайты:
     - `session_recovered` — после graceful restart NS восстанавливает live-сессии (S6, нужен publish)
     - `backtest_completed` — `app/backtest/jobs.py:226` (есть `done` publish, добавить EVENT_MAP entry)
     - `daily_stats` — нужно определить когда публикуется (конец торгового дня?)
     - `corporate_action` — `app/corporate_actions/` detect job
     - `price_alert` — `app/market_data/price_alert_monitor.py`
   - **Новый эпик L1 в W2:** Event type sync. BACK2 (publishers) + FRONT2 (labels).

### Batch 2 — ✅ принято 2026-05-12

4. **§2.4 Coverage gate в CI** → ✅ **в W3 S8 после довода** до 80% (P0+P1+P2 в W1-W2). Добавить `--cov-fail-under=80` в `.github/workflows/ci.yml` backend job. Защита от регрессии.
5. **§3.6 Security audit instrument** → ✅ **`bandit` + `safety` в W1**. Setup в ci.yml (~30 мин), default-policy: medium+ блокирует PR. Возможные исключения через `.banditignore` / `safety policy`.
6. **§4.5 Lighthouse CI** → ✅ **нет, performance вручную**. В W1 — структурированный baseline (Chrome DevTools + structlog timing), в W2 — pytest-benchmark на критических путях. Без +2 мин к nightly workflow.
7. **§4.5 Prometheus/Grafana export** → ✅ **в S8 — structlog + Plotly Dash страница `/admin/metrics`** (~4ч в W2). Mac mini single-user сценарий: внутри приложения, без отдельных Docker контейнеров. Prometheus + Grafana отложить на S9 если объёмы вырастут.

### Новый эпик из batch 2 — ✅ принят 2026-05-12

**Эпик N — Admin role + admin panel (W1, ~11ч)**

- BACK1: миграция БД `is_admin: bool = False` (alembic ≈50 строк, ~2ч)
- BACK1: dependency `require_admin` в `app/auth/dependencies.py` + новый module `app/admin/router.py` (~3ч)
- FRONT2: `useAuthStore.user.is_admin`, `Sidebar` conditional пункт, `ProtectedAdminRoute` (~2ч)
- BACK1: CLI `python -m app.cli.users grant_admin <username>` (~1ч)
- Bootstrap первого админа: FirstRunWizard → `is_admin=True` для первого зарегистрированного (как `needs_setup` сейчас)
- Тесты: 1 unit + 2 integration (грант, blocking non-admin, FirstRunWizard) (~3ч)

**Блокирует другие задачи S8:**
- TODO #6 → `/admin/metrics` Plotly Dash (W2)
- TODO #4 → security audit smoke-проверка `require_admin` на admin-endpoints (W1)
- Будущие admin-функции (rotate master key, view all users) → S9

### Batch 3 — ⬜ ожидает решения

8. **§5.2 `s7-backup.spec.ts`** — Playwright (child_process) или pytest integration?
9. **§5.3 `s7-events.spec.ts`** — реализовать `_test/emit-event` endpoint?
10. **§7.2 Deployment target** — Docker + systemd / Kubernetes / Bare-metal?

### Batch 3 — ✅ принято 2026-05-12

8. **§5.2 `s7-backup.spec.ts`** → ✅ **pytest integration test**. Создать `tests/integration/test_backup_cli.py` с `subprocess.run()` вместо Playwright spec. Backup — backend CLI, не UI. Удалить упоминание `s7-backup.spec.ts` из QA плана.
9. **§5.3 `s7-events.spec.ts`** → ✅ **Mock WS frame из Playwright**. Использовать `page.route` для WS endpoint и подсовывать frames из fixture. Без backend изменений. Уже знакомый паттерн в `api_mocks.ts`. Не вводить `_test/emit-event` endpoint.
10. **§7.2 Deployment target** → ✅ **Docker compose на Mac mini**. `docker-compose.yml` (backend uvicorn + frontend nginx + sqlite volume) + launchd plist для auto-start. SSL через Cloudflare Tunnel (или self-signed). Deployment guide для Mac mini сценария.

---

## 12. ✅ Все TODO разрешены — готовность к W1

Все 10 TODO + новый эпик Admin role приняты заказчиком 2026-05-12.

**Финальный scope S8:**
- 30 backlog карточек + новые эпики:
  - **L1 — Event type sync** (W2, ~12ч): 4 backend в UI + 5 UI publish-sites
  - **N — Admin role + admin panel** (W1, ~11ч): is_admin + require_admin + /admin/metrics
- 6 E2E spec'ов (один из них вынесен в pytest integration): `s7-export`, **`tests/integration/test_backup_cli.py`**, `s7-events`, `s7-tg-callbacks`, `s7-backtest-analytics`, `s7-bg-backtest`
- Coverage план P0+P1+P2 → CI gate в W3
- Security аудит + bandit/safety в CI с W1
- Performance: structlog + Plotly Dash `/admin/metrics` (W2)
- Deployment: Docker compose + Mac mini guide (W3)

**Финальный объём:** ≈155ч с эпиками admin + event sync (vs 130ч изначально). Уложимся в 12-13 рабочих дней.

### Gate W0 → W1 ✅ ПРОЙДЕН

Следующий шаг: создание `prompt_DEV-1..N.md`, `prompt_QA.md`, `e2e_test_plan_s8.md`, обновление `execution_order.md`.
