## DEV-2 отчёт — Sprint 8, W1: Security audit + bandit/safety + Multiplexer singleton contract + Admin smoke

### 1. Что реализовано
- **8B.1 (bandit/safety в CI):** новый job `security-scan` в
  `.github/workflows/ci.yml` (bandit `-ll` + safety `--policy-file`).
  Конфиги `.bandit` + `safety_policy.yml` с документированными suppression'ами.
- **8B.2 (security audit):** `Sprint_8/security_audit_s8.md` — 6 секций,
  все checkbox'ы заполнены конкретикой (file:line + pytest evidence).
  Verdict: 0 critical / 3 high (HEADERS, TELEGRAM-XSS, EMAIL-XSS) /
  7 medium / 2 low.
- **8B.3 (S7R-MULTIPLEXER-SINGLETON contract):** singleton-инфраструктура
  была реализована в S7 hotfix; BACK2 закрепил контракт 6 новыми тестами
  `tests/unit/test_broker/test_multiplexer_singleton.py`.
- **8B.4 (require_admin smoke):** структурный whitelist-тест
  `tests/test_admin/test_admin_routes_protection.py` — итерация по
  `app.routes`, проверка `require_admin` в DI-цепочке.
- bandit findings 3 medium suppressed `# nosec B102` с reason inline в
  `engine.py:492`, `executor.py:118`, `executor.py:169`.
- safety: 1 CVE-2026-0994 (protobuf 4.25.9) принят в `safety_policy.yml`
  с reason + expires 2026-12-31.

### 2. Файлы
- **Новые:** `Спринты/Sprint_8/security_audit_s8.md`;
  `Develop/backend/.bandit`; `Develop/backend/safety_policy.yml`;
  `Develop/backend/tests/unit/test_broker/test_multiplexer_singleton.py`;
  `Develop/backend/tests/test_admin/test_admin_routes_protection.py`;
  `Develop/backend/tests/test_security/test_security_headers.py`.
- **Изменённые:** `Develop/.github/workflows/ci.yml`;
  `Develop/backend/app/backtest/engine.py` (1 строка `# nosec`);
  `Develop/backend/app/sandbox/executor.py` (2 строки `# nosec`);
  `Спринты/Sprint_8/changelog.md`; `Спринты/Sprint_8/sprint_state.md`.
- **Удалённые:** нет.

### 3. Тесты
- Backend: **1098 passed / 6 xfailed / 0 failed** в 189s. Baseline до BACK2
  был 1087 (после BACK1 W1), мой чистый прирост — **+11 passed +6 xfailed**.
  6 xfailed — контракт-тесты для будущего SecurityHeadersMiddleware (xfail
  с reason, не блокируют CI; станут green после внедрения middleware).
- ruff: 0 issues. mypy: 0 errors на 147 файлах.
- bandit `-r app/ -ll`: 0 medium+ (после suppression'ов).
- safety: 1 ignored CVE (документирована в `safety_policy.yml`).

### 4. Integration points
- `get_or_create_multiplexer` вызывается из
  `app/broker/tinvest/adapter.py:741-746` (ленивая инициализация в
  `_ensure_multiplexer()`) — singleton-контракт реальный, не только в тестах.
- `shutdown_multiplexers` вызывается из `app/main.py:196-202` lifespan
  shutdown — graceful close gRPC streams.
- `grep -rn "TInvestStreamMultiplexer(" app/` → **1 hit** (в фабрике
  `get_or_create_multiplexer`, строка 485). Контракт C-S8-6 выполнен.
- `require_admin` подключён в `app/admin/router.py:21-23` (router-level);
  мой smoke-тест итерирует `app.routes` и проверяет каждый
  `/api/v1/admin/*` — runtime guarantee, не только статика.

### 5. Контракты
- **Поставляю C-S8-6** (multiplexer singleton, внутри backend) — реальная
  реализация была в S7 hotfix; контракт BACK2 зафиксирован тестами. Готов.
- **Поставляю C-S8-5** (paginated audit, совместно с BACK1) — backend
  endpoint'ы с `PaginatedResponse` существуют (`account/router.py`,
  `broker/router.py`); полный audit front+back — на оркестраторе.
- **Использую `require_admin`** (от BACK1, C-S8-7) — контракт соблюдён,
  smoke-тест прошёл (2/2).

### 6. Проблемы / TODO
- 3 high findings (`S8R-SEC-HEADERS`, `S8R-SEC-TELEGRAM-XSS`,
  `S8R-SEC-EMAIL-XSS`) рекомендованы к фиксу в W2 (внедрение middleware
  + общий `_safe_format_event_text()` helper). xfail-тесты для headers уже
  написаны — станут green автоматически после внедрения.
- 7 medium + 2 low findings отложены в S9-backlog с конкретными ID
  (HKDF salt, key rotation CLI, JWT min-length validator, CSRF samesite
  explicit, sandbox memory limit, auth rate tighten, …).
- В `Sprint_8_Review/backlog.md` карточки не добавлял — следую паттерну S7,
  оркестратор/ARCH сформирует по итогам W1.

### 7. Применённые Stack Gotchas
- **Gotcha 4** (`gotcha-04-tinvest-stream.md`): T-Invest streaming 429 —
  тесты `test_multiplexer_singleton.py` защищают именно от регрессии этой
  ловушки (несколько adapters → несколько streams → 429).
- **Gotcha 14** (`gotcha-14-sdk-sys-modules-stub.md`): bandit/safety
  выбраны как чистые tools без зависимости от tinkoff-investments SDK —
  CI security-scan job независим от patched-install шагов backend job.

### 8. Новые Stack Gotchas
Нет. Все security findings — стандартные web-security паттерны (HSTS, XSS
в HTML parse_mode), не специфичные ловушки нашего стека.

### 9. Использование плагинов
- pyright-lsp: fallback `python -m py_compile` после каждого Edit
  (engine.py, executor.py — OK).
- context7: не использован (bandit/safety документация — стандартная,
  CLI флаги общеизвестны).
- WebSearch: не использован (OWASP Argon2id params 2023 — известны
  из training data; verified actual params via `tests/test_admin/conftest.py`
  hash format).
- code-review: не запускал — финальный code-review всего W1 за оркестратором.
- superpowers TDD: контракт-тесты multiplexer и admin smoke написаны до
  верификации singleton кода (singleton уже существовал — тесты подтверждают
  contract, не TDD в строгом смысле).
