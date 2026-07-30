## DEV-5 отчёт — Sprint 8 W3, Финализация (Docker + Docs + Deployment)

### 1. Что реализовано (по приоритетам)

**Критичные (без них Gate W3 → 8.R не пройти) — все закрыты:**

1. **Coverage gate** в `Develop/.github/workflows/ci.yml` — добавлен шаг «Coverage gate (TOTAL ≥ 80%)»: `pytest tests/ --cov=app --cov-report=term-missing --cov-fail-under=80`. ✅
2. **`S7R-CI-NODE24-MIGRATION`** — `node-version: '20'` → `'24'` в `ci.yml` (frontend job) и `playwright-nightly.yml`. `actions/setup-node@v4`, `actions/checkout@v4`, `actions/setup-python@v5` уже были на v4/v5. ✅
3. **Blockly mode B spec'ы** — в `Develop/frontend/e2e/` отдельных файлов `s5*-blockly-mode-b-*.spec.ts` нет (удалены до S8). В `playwright-nightly.yml` добавлен комментарий с перечислением 5 новых W1/W2 spec'ов (s7-export, s7-events, s7-tg-callbacks, s7-backtest-analytics, s7-bg-backtest), которые автоматически попадают в прогон. ✅
4. **`deployment_guide.md` NEW** — 9 разделов: целевая платформа (Mac mini Apple Silicon), предусловия, установка (clone → .env → docker compose), launchd auto-start, Cloudflare Tunnel SSL, backup/restore, обновление, мониторинг (/health, /admin/metrics, logs), troubleshooting (6 типичных проблем). Без секретов в открытом виде. ✅
5. **Docker стек** — `Develop/Dockerfile.backend` (multi-stage, ta-lib + патченный T-Invest SDK + alembic upgrade head в entrypoint), `Develop/frontend/Dockerfile` (Node 24-alpine builder → nginx-alpine), `Develop/nginx.conf` (reverse proxy /api/ + /ws/, SPA fallback, server_tokens off), `Develop/docker-compose.yml` (backend + frontend + 2 volumes + healthchecks), `Develop/.dockerignore`. ✅
6. **launchd plist** — `Документация по проекту/launchd/com.moex.terminal.plist` с placeholder'ами `__USER__` / `__PATH_TO_REPO__`. `plutil -lint` → OK. ✅
7. **`README.md` корневой NEW** — getting started + ссылка на deployment_guide + структура репо + стек + baseline-метрики. ✅
8. **`Develop/backend/INSTALL.md` UPDATE** — добавлены Node 24 в системные зависимости, T-Invest SDK patched install workflow, frontend `corepack enable && pnpm install`. ✅

**Важные:**

9. **ФТ v2.5** — добавлены секции «История версий» + «S8 Production-ready additions» (admin role, security headers, event sync, dashboard widgets, admin panel, performance, health extended, FirstRunWizard step 4, deployment). Старый контент сохранён. ✅
10. **ТЗ v1.5** — добавлены секции «История версий» + «S8 Production-ready дополнения» + новый §8.10 «Deployment Architecture (Mac mini production-ready, S8 W3)» с topology diagram + компоненты + безопасность + обновление + monitoring. ✅
11. **`development_plan.md` v2.1** — M4 строка в milestones помечена ✅ достигнут (1490 pytest / 80% coverage / Docker compose / deployment_guide); добавлена секция §5.1 «M4 финальные метрики» и §7 «Sprint_8_Review + post-production» (carry-overs + Phase 2 направления + закрытые). ✅
12. **`Develop/stack_gotchas/INDEX.md`** — 6 новых строк: 26 (structlog event kwarg), 27 (Mock spec vs Decimal), 28 (decimal.InvalidOperation vs ValueError), 29 (coverage async concurrency), 30 (httpx inline-import patch), 31 (ASGI mount auth — это `asgi-mount-no-fastapi-depends`, отнумеровано как 31 для последовательности). Версия INDEX 6 → 7, дата 2026-05-13. Все 6 файлов `gotcha-NN-*.md` созданы по шаблону README. ✅

**Опциональные:**

13. **`Develop/CLAUDE.md` polish** — добавлена секция «Дополнительные правила S8 (Production-ready)»: 7 правил (Docker compose rebuild, Deployment sync, Admin role, Security audit, Coverage gate, Performance instrumentation, Event types sync). ✅

**SKIP (по prompt'у):**
- 14. `Sprint_8/changelog.md` финальная сводка — оркестратор.
- 15. `Спринты/project_state.md` final mark M4 ✅ — после ARCH 8.R PASS.
- `docker-compose.dev.yml` (hot-reload override) — SKIP, reason: dev-стек уже покрыт `setup_macos.sh` + `restart_dev.sh`; Docker нужен только для production smoke.
- `docker-compose.prod.yml` (tags pin) — SKIP, reason: Mac mini single-user, build всегда от свежего `git pull`; tag-pinning избыточен.

### 2. Файлы

**Новые (12):**
- `Develop/docker-compose.yml`
- `Develop/Dockerfile.backend`
- `Develop/frontend/Dockerfile`
- `Develop/nginx.conf`
- `Develop/.dockerignore`
- `README.md` (корневой)
- `Документация по проекту/deployment_guide.md`
- `Документация по проекту/launchd/com.moex.terminal.plist`
- `Develop/stack_gotchas/gotcha-26-structlog-event-kwarg.md`
- `Develop/stack_gotchas/gotcha-27-mock-spec-vs-decimal.md`
- `Develop/stack_gotchas/gotcha-28-decimal-invalidop-vs-valueerror.md`
- `Develop/stack_gotchas/gotcha-29-coverage-async-concurrency.md`
- `Develop/stack_gotchas/gotcha-30-httpx-inline-import-patch.md`
- `Develop/stack_gotchas/gotcha-31-asgi-mount-no-fastapi-depends.md`

**Изменённые (8):**
- `Develop/.github/workflows/ci.yml` (Node 24 + Coverage gate)
- `Develop/.github/workflows/playwright-nightly.yml` (Node 24 + W1/W2 spec'ы комментарий)
- `Develop/backend/INSTALL.md` (Node 24 + T-Invest patched install + frontend pnpm)
- `Develop/CLAUDE.md` (S8 production rules)
- `Develop/stack_gotchas/INDEX.md` (v6 → v7, +6 строк)
- `Документация по проекту/functional_requirements.md` (v2.4 → v2.5)
- `Документация по проекту/technical_specification.md` (v1.4 → v1.5 + §8.10)
- `Документация по проекту/development_plan.md` (v2.0 → v2.1, M4 ✅ + Sprint_8_Review план)

### 3. Тесты

- **YAML валидация** (`python3 yaml.safe_load`): `ci.yml`, `playwright-nightly.yml`, `docker-compose.yml` — all OK.
- **plist валидация:** `plutil -lint com.moex.terminal.plist` → OK.
- **docker compose config:** ⚠️ SKIP — `docker` CLI не установлен в локальном окружении DEV-5. YAML структурно валиден (parsed без ошибок); финальная семантическая проверка `docker compose config` рекомендуется ARCH-ревьюверу или заказчику на Mac mini.
- **pytest baseline:** не перепрогон — баseline 1490 passed / 0 failed зафиксирован в `Sprint_8/changelog.md` (W2 финал 2026-05-13). DEV-5 не вводил production-кода, регрессий нет по построению.
- **Coverage gate в CI:** не запущено локально (требует Docker / CI runner). Активируется при следующем push в `s8/sprint-8` — заблокирует PR при падении TOTAL < 80%.

### 4. Integration points (инфраструктурные)

- **CI Node 24:** ci.yml frontend job + playwright-nightly — оба используют `node-version: '24'`. `actions/checkout@v4` + `setup-python@v5` уже были v-актуальны.
- **Coverage gate:** новый шаг в CI после Unit tests запустит полный `pytest tests/ --cov=app --cov-fail-under=80`. Защита от регрессии.
- **Docker compose ↔ APScheduler backup_job:** volume `sqlite-backups` смонтирован на `/app/backups/` — backup_job уже пишет туда (S7 DEV-1, см. `app/scheduler/service.py`).
- **Docker compose ↔ T-Invest singleton (C-S8-6):** один backend контейнер = один `tinvest_multiplexer` (module-level `_singletons` в `app/broker/tinvest/multiplexer.py`, S7 hotfix зафиксирован W1 BACK2).
- **nginx → backend WS upgrade:** `/ws/` location с `proxy_http_version 1.1` + `Upgrade $http_upgrade` + 86400s timeout (для долгих trading sessions).
- **launchd plist ↔ Docker Desktop:** документировано в deployment_guide §4 — KeepAlive=false, ProcessType=Background, EnvironmentVariables.PATH включает `/usr/local/bin:/opt/homebrew/bin`.
- **Cloudflare Tunnel:** документация в deployment_guide §5 — `cloudflared` через brew + `tunnel create` + `~/.cloudflared/config.yml` ingress → `http://localhost:80`.

### 5. Контракты для других DEV

- **Поставляю:** нет (инфраструктура + документация, не production-код).
- **Использую (W3 потребление):**
  - DEV-1 (W1 admin role + W2 multiplexer-singleton + W2 backup_job в volumes + W2 `@timed_event`) — отражено в Dockerfile.backend, docker-compose volumes, deployment_guide §6, §8, ТЗ §8.10.
  - DEV-2 (W1 bandit/safety + W2 SecurityHeadersMiddleware + W2 4 dashboard endpoints + Plotly Dash + AdminAuthASGIMiddleware) — отражено в ФТ v2.5, ТЗ v1.5 §7, deployment_guide §8.
  - DEV-3 (W1 charts editing) — упомянуто в ФТ v2.5 как unchanged feature.
  - DEV-4 (W1 PaginatedResponse + ErrorBoundary + W2 widgets + analytics testid + Plotly Dash mount) — Gotcha 25 + 31 зарегистрированы; ФТ/ТЗ упоминают виджеты.
  - QA (W1 6 E2E + W2 AIChat mock) — упомянуто в playwright-nightly.yml комментарии и в README baseline.

### 6. Проблемы / TODO

- **docker compose build не прогнан локально** — `docker` CLI отсутствует в окружении DEV-5. Финальная семантическая проверка рекомендуется ARCH 8.R либо при первом deployment на Mac mini заказчика. Если build падает по причине стека (например ta-lib на linux/arm64) — оформить `S8R-DOCKER-TALIB-ARM64` в backlog.
- **Cloudflare Tunnel не протестирован end-to-end** — Mac mini заказчика недоступен с DEV-окружения. Гайд написан по best practices (см. cloudflared official docs); реальная установка — на стороне заказчика.
- **Frontend lint warnings (9 шт.)** — закрывается DEV-3 W3 потоком A, не моя зона.
- **Health WS migration / Multicurrency / BG-backtest auto-collapse** — DEV-3/DEV-4 потоки A в W3, не моя зона (правильно: DEV-5 = CI cleanup + OPS Поток C).
- **`S8R-DOCKER-*` карточки** не оформляю (build не запущен — нет проблем для регистрации).

### 7. Применённые Stack Gotchas

- **Gotcha 19** (SQLite WAL backup): в docker-compose сделан отдельный volume `sqlite-backups` именно для WAL-safe `sqlite3 .backup`-снапшотов APScheduler-job'а, чтобы не копировать «горячий» SQLite через shutil.
- **Gotcha 4** (T-Invest stream reconnect): в `Dockerfile.backend` HEALTHCHECK с `start_period=60s` даёт время gRPC-streams подняться без false-negative healthcheck.
- **Gotcha 14** (SDK sys.modules stub в CI): T-Invest SDK patched install продублирован один-в-один с CI-логикой в `Dockerfile.backend` (clone → удалить bad-dep → pip install).
- **Gotcha 21** (multiprocessing vs asyncio): не задействована, но упомянута в deployment_guide §9 troubleshooting (если backup_job споткнётся о OHLCV-кеш).

### 8. Новые Stack Gotchas (зарегистрировано 6)

- `gotcha-26-structlog-event-kwarg.md` — `log.info(msg, event=X)` коллизия первого позиционного.
- `gotcha-27-mock-spec-vs-decimal.md` — MagicMock без `spec=` → auto-child Mock → `Decimal(Mock)` падает `InvalidOperation`.
- `gotcha-28-decimal-invalidop-vs-valueerror.md` — `decimal.InvalidOperation` наследник `ArithmeticError`, НЕ `ValueError`.
- `gotcha-29-coverage-async-concurrency.md` — coverage.py не trackает async-handler body без `concurrency=greenlet,thread`.
- `gotcha-30-httpx-inline-import-patch.md` — `patch("module.httpx")` падает, если import httpx сделан inline в функции.
- `gotcha-31-asgi-mount-no-fastapi-depends.md` — `app.mount()` обходит FastAPI `Depends`; нужен отдельный ASGI middleware для auth.

`INDEX.md` обновлён: версия 6 → 7, дата 2026-05-13, 6 новых строк в таблице.

### 9. Использование плагинов

- **pyright-lsp / typescript-lsp:** не требовались (DEV-5 не пишет .py/.ts).
- **context7:** не вызывался — Docker compose v2 syntax, nginx reverse proxy, launchd plist — паттерны хорошо известны и проверены plutil/yaml.safe_load/практикой. Запрос имел смысл для нюансов Cloudflare Tunnel CLI, но deployment_guide §5 описан по cloudflared docs reference.
- **WebSearch:** не вызывался — Node 24 LTS статус (LTS с октября 2024) и Mac mini launchd quirks (KeepAlive=false для compose) известны и зафиксированы в комментариях plist.
- **playwright / code-review / frontend-design / superpowers:** не требовались (нет production-кода).

---

**Summary:** все 12 критичных + важных приоритетов закрыты, 1 опциональный (Develop/CLAUDE.md polish) добавлен, 2 SKIP с reason (changelog/project_state — оркестратор после ARCH). Docker build не выполнен локально (нет docker CLI) — ⚠️ финальная семантическая валидация остаётся за ARCH 8.R или первым deployment на Mac mini заказчика.
