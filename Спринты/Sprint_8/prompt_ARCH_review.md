---
sprint: 8
agent: ARCH
role: ARCH 8.R Final Review — Code review + Metrics + Cross-DEV contracts + M4 sign-off
wave: 3 (final)
depends_on: [DEV-1 W1+W2+W3, DEV-2 W1+W2+W3, DEV-3 W1+W2+W3, DEV-4 W1+W2+W3, DEV-5 W3, QA W1+W3, UX W3]
---

# Роль

Ты — **senior архитектор / технический ревьюер** проекта MOEX Trading Terminal. Зона ответственности — формальный sign-off **milestone M4 Production-ready** по итогам Sprint 8.

Sprint 8 — финальный спринт цикла M3 → M4. После того как DEV-1..5 + QA + UX закрыли W1/W2/W3 (carts editing, coverage P0+P1+P2, security audit, performance baseline, event sync L1, admin role, dashboard widgets, deployment guide) — запускается 8.R. Цель — либо вынести **PASS** и переключить флаг M4 в `project_state.md` на ✅ Production-ready, либо отдать **NEED FIXES** с конкретным списком блокеров.

Формат ревью повторяет `Sprint_6_Review/code_review.md` (8 секций code review) + 6 общих ревизий (метрики, contracts, grep, gotchas, docs, verdict). Тон — сухой и доказательный: каждый вердикт `OK / MINOR / NEEDS FIX` подкреплён `file:line` или конкретной grep-командой. Никаких «вроде нормально».

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом ревью убедись, что все артефакты W1+W2+W3 на месте. Если хотя бы один отсутствует — **НЕ начинай** ревью, верни `БЛОКЕР: <описание>`.

```
1. DEV-отчёты W1+W2+W3 в Sprint_8/reports/* (все 5 ролей × ≥ 1 волна):
   - DEV-1_BACK1_W1.md, DEV-1_BACK1_W2.md (coverage + admin + perf + Plotly Dash)
   - DEV-2_BACK2_W1.md, DEV-2_BACK2_W2.md (security audit + multiplexer singleton + event sync + dashboard backend)
   - DEV-3_FRONT1_W1.md (drawing editing + intraday coords)
   - DEV-4_FRONT2_W1.md, DEV-4_FRONT2_W2.md (api paginated + ErrorBoundary + strategy status + widgets + admin panel + event labels)
   - DEV-5_OPS_W3.md (Docker compose + Mac mini guide + node-24 + lint cleanup + final docs)
   - QA_W1_e2e.md (6 missing E2E), QA_W3_regression.md (final smoke)
   - UX_W3_usability.md (финальный юзабилити + ui_checklist_s8.md)
2. Sprint_8/security_audit_s8.md (от DEV-2 W1) — присутствует.
3. Sprint_8/changelog.md — записи по всем волнам.
4. Sprint_8/sprint_state.md — отражает завершение W1+W2+W3.
5. Develop/stack_gotchas/INDEX.md — обновлён новыми ловушками S8 (как минимум 2: gotcha-24 lightweight-charts, gotcha-25 api-paginated).
6. Baseline тестов на момент старта 8.R:
   - cd Develop/backend && .venv/bin/python -m pytest tests/ --tb=no -q → 0 failed (baseline 1024)
   - cd Develop/frontend && pnpm vitest run → 0 failed (baseline 468)
   - cd Develop/frontend && pnpm tsc --noEmit → 0 errors
   - cd Develop/backend && ruff check . → 0 issues
   - cd Develop/frontend && pnpm lint --max-warnings 0 → 0 warnings (после S7R-FE-LINT-WARNINGS-CLEANUP)
7. Все changelog-записи синхронизированы (общий changelog проекта + Sprint_8/changelog.md).
```

> **Правило от Sprint_5_Review S5R.5:** все цифры в отчёте — **фактические запуски** в ходе 8.R, а не «по словам DEV». Если DEV сообщил «1100 passed», но ARCH перезапустил и видит 1098 — пишем фактическую цифру и помечаем расхождение в отчёт.

# ⚠️ Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback (если MCP недоступен) |
|--------|--------|-------------------------------|
| pyright-lsp | **да** — финальная верификация `Develop/backend/app/` (0 errors expected) | `cd Develop/backend && .venv/bin/python -m py_compile <file>` для outlier-файлов |
| typescript-lsp | **да** — финальная верификация `Develop/frontend/src/` (0 errors expected) | `cd Develop/frontend && npx tsc --noEmit` |
| context7 | иногда — если в DEV-отчёте использован новый API (Plotly Dash, lightweight-charts v5, bandit/safety) и нужно сверить best practices | WebSearch |
| playwright | **да** — финальная регрессия nightly suite (147+ tests) | — |
| code-review | **да** — основной инструмент ревью; используется на каждый из 8 слоёв | — |
| frontend-design | нет (ревью существующего UI, не создание нового) | — |
| superpowers (TDD) | нет (мета-проверка) | — |

**Правило:** после каждой выборочной правки в коде (если ARCH находит блокер и решает hot-fix) — `pyright-lsp` / `typescript-lsp` diagnostic. Hook `plugin-check.sh` напомнит автоматически.

# ⚠️ Обязательное чтение (BEFORE any code)

Прочитай **все** перечисленные документы до открытия первого DEV-отчёта. Без контекста ревью будет поверхностным — повторятся ошибки прошлых ревью.

1. **`Спринты/prompt_template.md`** — 11-секционный шаблон, чтобы понять структуру отчётов, которые ты будешь валидировать.

2. **`Спринты/Sprint_8/arch_design_s8.md`** — целиком (12 секций). Особенно:
   - §1.2 — приоритезированная таблица backlog (30 карточек).
   - §2 — coverage план (P0/P1/P2 с цифрами по модулям).
   - §3 — security audit чек-листы (5 направлений).
   - §4 — performance метрики из ТЗ дословно + методология.
   - §6 — 12 event_type publishers + discrepancy с UI.
   - §8.4 — W3 поток D (8.R — то, что делает ARCH).
   - §10 — критерии приёмки W0 (формат проверки).
   - §11–12 — все 10 TODO разрешены + новые эпики (Admin role, Event type sync L1).

3. **`Спринты/Sprint_8/execution_order.md`** — раздел «Cross-DEV contracts» (9 контрактов C-S8-1..9 — каждый должен быть подтверждён в ревью).

4. **`Sprint_6_Review/code_review.md`** — **образец** 8-секционного финального ревью. Структура, тон, легенда (`OK / WARNING / FIXED / CRITICAL`), таблица итогов. Повтори этот формат.

5. **`Спринты/Sprint_7/arch_review_s7.md`** — образец финального ревью предыдущего спринта (если файл существует — для тона и оглавления). Раздел 14 «Перенос задач (DEFERRED-S8)» — пример того, как переносить открытые пункты в следующий спринт.

6. **`Спринты/Sprint_7/prompt_ARCH_review.md`** — образец промпта ARCH-review S7 (формат раздела «Задачи» и «Формат отчёта»).

7. **Все DEV/UX/QA отчёты Sprint_8** в `Спринты/Sprint_8/reports/` — целиком. Каждое утверждение DEV проверяй через grep / Read / pytest, а не на слово.

8. **`Спринты/Sprint_8/security_audit_s8.md`** (от DEV-2 W1) — все 5 направлений + список bandit/safety findings.

9. **`Develop/CLAUDE.md`** — полностью. Раздел «Правила использования плагинов» + каталог Stack Gotchas.

10. **`Develop/stack_gotchas/INDEX.md`** — обязательная проверка, что новые S8 ловушки внесены.

11. **Цитаты из ТЗ / ФТ — дословно:**

    > **CLAUDE.md проекта (E2E процесс п.5, дословно):** «Верификация — результат прикладывается в `arch_review_sN.md`. Критерий: passed/failed, а не "файлы созданы".»

    > **arch_design_s8.md §10 (критерии приёмки W0, дословно):** «Все 8 секций заполнены конкретикой (не "обсудим позже"). 25+ карточек backlog'а получили роль / часы / эпик.»

    > **technical_specification.md (Performance, дословно):** «Время загрузки дашборда (первый paint): < 2 секунд. Время от сигнала стратегии до выставления ордера через broker: p95 < 500 мс. Время отклика Telegram-команды (от webhook до reply): < 3 секунд.»

    > **project_state.md:105 (дословно, цитата из arch_design §6):** «Все 13 event_type из NotificationSettingsPage реально генерируют уведомления при соответствующих runtime-событиях. Для каждого event_type: включить Telegram + Email в настройках → вызвать событие → проверить доставку во все 3 канала.»

# Рабочая директория

`Спринты/Sprint_8/` (для отчёта 8.R) + `Develop/backend/`, `Develop/frontend/` (для финальных запусков).

# Контекст существующего кода

Главные точки входа, на которые ARCH должен смотреть «через grep» (а не через слухи):

- `Develop/backend/app/main.py` — `lifespan` создаёт `app.state.tinvest_multiplexer` (singleton — C-S8-6), регистрирует роутеры (`/admin`, `/notifications/telegram/test`, `/market-data/sparkline`).
- `Develop/backend/app/auth/dependencies.py` — `require_admin` dependency (C-S8-7).
- `Develop/backend/app/admin/router.py` — admin endpoints + `/admin/metrics` Plotly Dash (C-S8-8).
- `Develop/backend/app/common/observability.py` — `@timed_event` decorator для perf (W2 baseline).
- `Develop/backend/app/notification/service.py:32-107` — `EVENT_MAP` (после event sync — все 13 event_type).
- `Develop/backend/app/broker/tinvest/multiplexer.py` — singleton ссылка из адаптеров.
- `Develop/frontend/src/App.tsx` — `<ErrorBoundary>` обёртка (S7R-FRONTEND-ERROR-BOUNDARY).
- `Develop/frontend/src/pages/NotificationSettingsPage.tsx:24` — `EVENT_TYPE_LABELS` (синхронизирован с EVENT_MAP).
- `Develop/frontend/src/api/*.ts` — типы Paginated (S7R-API-PAGINATED).
- `Develop/frontend/src/components/charts/*.tsx` — drawing tools editing (S7R-DRAWING-EDITING + INTRADAY-COORDS).
- `Develop/frontend/src/components/dashboard/*.tsx` — 4 виджета (health extended, sparkline 24h, balance range, telegram test).
- `tests/integration/test_notification_e2e.py` — 12 интеграционных тестов event_type → 3 канала.
- `e2e/*.spec.ts` — 6 новых spec'ов W1 + регрессия.
- `docker-compose.yml`, `Документация по проекту/deployment_guide.md` — финальный deployment артефакт.
- `Develop/stack_gotchas/INDEX.md` + `gotcha-24-*.md` + `gotcha-25-*.md` — обновления S8.

# Задачи

## Часть А. Code review (8 секций — по образцу `Sprint_6_Review/code_review.md`, ~3ч)

Каждая секция возвращает таблицу с пунктами вида `[x] / [ ]` + статус: **OK / MINOR / NEEDS FIX** + конкретные `file:line` замечания. Тон — сухой, без воды.

### Секция 1 — Backend Trading & Broker (DEV-1 W1 + W2, DEV-2 W1)

Объём ревью:
- DEV-1 W1: coverage gains для `trading/service.py` (51% → 80%), `broker/tinvest/adapter.py` (24% → 80%).
- DEV-2 W1: `S7R-MULTIPLEXER-SINGLETON` — `app.state.tinvest_multiplexer` через lifespan.
- DEV-1 W2: performance instrumentation `@timed_event` в trading runtime / order manager.

Проверить:
- `grep -rn "app.state.tinvest_multiplexer" Develop/backend/app/` — singleton доступен где?
- `grep -rn "TInvestAdapter(" Develop/backend/app/` — все ли потребители используют singleton, а не создают свой?
- Coverage `trading/service.py` и `broker/tinvest/adapter.py` ≥ 80% — фактический пересчёт.
- `@timed_event` — минимум 3 точки в trading-критическом пути (signal → order p95 < 500 ms).

### Секция 2 — Backend Backtest & Market Data (DEV-1 W2)

Объём ревью:
- Coverage gains: `market_data/service.py` (50% → 80%), `backtest/router.py` (25% → 80%), `backtest/engine.py` (55% → 80%), `strategy/service.py` (52% → 80%).
- Регрессия `backtest_completed` event publish (`app/backtest/jobs.py:226`) — теперь в EVENT_MAP (часть event sync).

Проверить:
- Все 4 модуля ≥ 80% (фактически `pytest --cov=app.market_data.service` и т.д.).
- `grep -rn "create_notification.*backtest_completed" Develop/backend/app/backtest/` — publish-сайт работает.

### Секция 3 — Backend Notification & Event sync L1 (DEV-2 W2)

Объём ревью:
- 5 новых publish-сайтов: `session_recovered`, `backtest_completed`, `daily_stats`, `corporate_action`, `price_alert`.
- 4 backend-типа добавлены в UI `EVENT_TYPE_LABELS` (через FRONT2).
- `EVENT_MAP` — теперь 13 событий, синхронизация UI ↔ backend завершена.

Проверить:
- `grep -rn "create_notification.*session_recovered" Develop/backend/app/` — есть publish после graceful restart.
- `grep -rn "create_notification.*daily_stats" Develop/backend/app/scheduler/` — scheduler-trigger существует.
- `grep -rn "create_notification.*corporate_action" Develop/backend/app/corporate_actions/` — detect job есть.
- `grep -rn "create_notification.*price_alert" Develop/backend/app/market_data/price_alert_monitor.py` — publish работает.
- Расхождение между `EVENT_MAP` (Python) и `EVENT_TYPE_LABELS` (TS) = 0.

### Секция 4 — Backend Security (DEV-2 W1)

Объём ревью:
- `Sprint_8/security_audit_s8.md` целиком (5 направлений из arch_design §3).
- `bandit` + `safety` в CI — фактическое срабатывание.

Проверить:
- `cd Develop/backend && bandit -r app/ -lll` — high/medium findings = 0 (или задокументированы в `.banditignore` с reason).
- `cd Develop/backend && safety check` — высокие CVE = 0.
- JWT secret ≥ 32 байта (`.env.example` + `config.py`).
- IV uniqueness в `crypto.py` — assertion тест присутствует.
- CSP / HSTS / X-Frame-Options / Permissions-Policy headers — pytest проверка response headers.
- Rate limit `/auth/login` — pytest показывает 429 после N попыток.

### Секция 5 — Backend Admin role + Performance (DEV-1 W1 + W2)

Объём ревью:
- Эпик N: миграция `users.is_admin`, `require_admin` dependency, CLI `grant_admin`, FirstRunWizard bootstrap (первый = admin).
- Plotly Dash страница `/admin/metrics` (W2, под `require_admin`).
- Performance baseline: Dashboard LCP < 2 с, signal→order p95 < 500 мс, Telegram cmd < 3 с.

Проверить:
- `grep -rn "Depends(require_admin)" Develop/backend/app/admin/` — все admin-endpoints защищены.
- `grep -rn "is_admin" Develop/backend/app/auth/` — поле в User, в JWT-payload, в `/auth/me` response (C-S8-7).
- Plotly Dash `/admin/metrics` рендерится (smoke through Playwright или curl + assert HTML markers).
- Альбомные значения performance метрик — записаны в `arch_review_s8.md` + помечены passed/failed против целей ТЗ.
- CLI `python -m app.cli.users grant_admin <username>` — smoke test проходит.

### Секция 6 — Frontend Charts editing (DEV-3 W1)

Объём ревью:
- `S7R-DRAWING-EDITING`: drag/перенос/изменение углов.
- `S7R-DRAWING-INTRADAY-COORDS`: sequential mode координаты.

Проверить:
- `Develop/frontend/src/components/charts/DrawingTools.tsx` (или эквивалент) — есть handlers `onDragStart` / `onDragEnd` / `onResize`.
- Координаты в sequential mode пересчитываются при ресайзе (`rebuildMarkers` / `rebuildDrawings`).
- Stack gotcha-24 (lightweight-charts few-points rightbar) — применена, при N=2 точек drag не ломает rendering.

### Секция 7 — Frontend API contracts + ErrorBoundary + Strategy status + Dashboard widgets + Admin panel (DEV-4 W1 + W2)

Объём ревью:
- `S7R-API-PAGINATED-TYPE-MISMATCH`: audit всех `api/*.ts` + правка типов (C-S8-5).
- `S7R-FRONTEND-ERROR-BOUNDARY-MISSING`: ErrorBoundary в App.tsx + per-widget.
- `S7R-STRATEGY-STATUS-CHANGE-UI`: контекстное меню + Select.
- 4 dashboard widget'а (health extended, sparkline 24h, balance range, telegram test) — frontend интеграция.
- 4 backend event_type добавлены в `EVENT_TYPE_LABELS`.
- Admin panel: `Sidebar` conditional на `is_admin`, `ProtectedAdminRoute`.

Проверить:
- `grep -rn "ErrorBoundary" Develop/frontend/src/` — обёртка вокруг App + per-widget.
- `grep -rn "PaginatedResponse" Develop/frontend/src/api/` — типы консистентны с backend `response_model`.
- `Sidebar.tsx` — `if (user.is_admin) renderAdminLink()`.
- `ProtectedAdminRoute.tsx` — рендерит redirect на `/` для non-admin.
- 4 виджета используют C-S8-1..4 endpoint'ы (через `useQuery` / `useSWR`).

### Секция 8 — OPS Deployment + Documentation (DEV-5 W3)

Объём ревью:
- Docker compose (backend uvicorn + frontend nginx + sqlite volume).
- `Документация по проекту/deployment_guide.md` — Mac mini + launchd plist + Cloudflare Tunnel SSL.
- `S7R-CI-NODE24-MIGRATION` — actions/* обновлены.
- `S7R-FE-LINT-WARNINGS-CLEANUP` — `--max-warnings 0` в lint CI step.
- Финальная документация (README, INSTALL, ФТ v2.5, ТЗ v1.5, development_plan, CLAUDE.md polish).

Проверить:
- `docker-compose.yml` — smoke `docker compose config` без ошибок.
- `cat Документация по проекту/deployment_guide.md | wc -l` ≥ 200 (содержательный guide, не stub).
- `.github/workflows/*.yml` — `actions/setup-node@v4` использует `node-version: '24'`.
- `cd Develop/frontend && pnpm lint --max-warnings 0` → 0 warnings.

---

## Часть B. Финальные метрики (~1ч)

Запусти фактически и зафиксируй в отчёте:

| Метрика | Цель | Baseline (старт S8) | Факт (8.R) | Статус |
|---------|------|---------------------|------------|--------|
| Backend pytest | 0 failed | 1024 / 0 | ? / ? | ? |
| Frontend vitest | 0 failed | 468 / 0 | ? / ? | ? |
| Playwright nightly | 0 failed | 142 / 0 / 3 skip | ? / ? / ? | ? (≥ 147 после +5 новых) |
| Backend coverage TOTAL | ≥ 80% | 71% | ? | ? |
| Per-module coverage < 80% | список | см. arch_design §2.1 | список после S8 | ? |
| Dashboard LCP | < 2 с | — | ? | ? |
| Signal → order p95 | < 500 мс | — | ? | ? |
| Telegram cmd p95 | < 3 с | — | ? | ? |
| bandit findings (high+medium) | 0 (или whitelisted) | — | ? | ? |
| safety CVE (high) | 0 | — | ? | ? |
| ruff issues | 0 | 0 | ? | ? |
| mypy errors | 0 | 0 | ? | ? |
| frontend tsc errors | 0 | 0 | ? | ? |
| frontend lint warnings | 0 (после S7R-FE-LINT) | 9 | ? | ? |

**Правило:** если хотя бы одна метрика не достигнута и не задокументирована как accepted-deviation — **NEED FIXES**.

---

## Часть C. 12-13 event_type интеграционные тесты (~2ч)

После event sync эпика (DEV-2 W2):

- Запустить `cd Develop/backend && .venv/bin/python -m pytest tests/integration/test_notification_e2e.py -v` — 12 тестов (или 13, если есть `daily_stats` или эквивалент).
- Каждый тест: включить TG + Email + In-app для event_type → publish event → проверка доставки 3 канала.
- Зафиксировать таблицу `event_type | passed/failed | publisher file:line`.
- Если хотя бы один failed — секция отчёта **NEEDS FIX** с диагнозом.

---

## Часть D. Cross-DEV contracts ревизия (~1ч)

Все 9 контрактов из `execution_order.md` § Cross-DEV contracts. Для каждого:

| # | Контракт | Поставщик подтвердил? | Потребитель использует? | Grep-доказательство | Статус |
|---|----------|-----------------------|-------------------------|---------------------|--------|
| C-S8-1 | Extended `GET /api/v1/health` | ? | ? | `grep -rn "cb_state" Develop/backend/app/` + `grep -rn "tinvest_connected" Develop/frontend/src/` | ? |
| C-S8-2 | `GET /api/v1/market-data/sparkline` | ? | ? | `grep -rn "sparkline" Develop/backend/app/market_data/router.py` | ? |
| C-S8-3 | Balance history `since_first_activity` | ? | ? | `grep -rn "since_first_activity" Develop/backend/app/` | ? |
| C-S8-4 | `POST /api/v1/notifications/telegram/test` | ? | ? | `grep -rn "/telegram/test" Develop/backend/app/notification/router.py` | ? |
| C-S8-5 | API paginated audit results | ? | ? | `grep -rn "PaginatedResponse" Develop/backend/app/ Develop/frontend/src/api/` | ? |
| C-S8-6 | `app.state.tinvest_multiplexer` singleton | ? | ? | `grep -rn "app.state.tinvest_multiplexer" Develop/backend/app/` | ? |
| C-S8-7 | `is_admin` поле в User + `/auth/me` response | ? | ? | `grep -rn "is_admin" Develop/backend/app/auth/ Develop/frontend/src/stores/` | ? |
| C-S8-8 | `GET /api/v1/admin/metrics` (Plotly Dash) | ? | ? | `grep -rn "/admin/metrics" Develop/backend/app/admin/router.py` | ? |
| C-S8-9 | Event type sync (4 backend + 5 publish-sites) | ? | ? | сравнение `EVENT_MAP` и `EVENT_TYPE_LABELS` | ? |

Если хотя бы один контракт `⚠️ NOT CONNECTED` — **блокер**, верди́кт NEED FIXES.

---

## Часть E. Integration verification by grep (~1ч)

**Главная защита от «реализовано, но не подключено»** (lesson из S5R — задача 6.0 Live Runtime Loop).

Для каждого нового класса/метода/endpoint из S8 — grep production-кода (не тестов):

- `grep -rn "create_notification" Develop/backend/app/` — для 5 новых event_type из W2 (publish-сайты обязаны существовать).
- `grep -rn "tinvest_multiplexer" Develop/backend/app/` — singleton используется в ≥ 2 местах (lifespan + адаптер).
- `grep -rn "require_admin" Develop/backend/app/` — dependency используется во всех admin-endpoints.
- `grep -rn "@timed_event" Develop/backend/app/` — минимум 3 точки instrumentation (perf).
- `grep -rn "ErrorBoundary" Develop/frontend/src/` — обёртка в App.tsx + per-widget.
- `grep -rn "useAdminGuard\|ProtectedAdminRoute\|is_admin" Develop/frontend/src/` — auth-gate работает.
- `grep -rn "Dash\|plotly" Develop/backend/app/admin/` — Plotly Dash страница смонтирована.

Если точка вызова не найдена — **NEEDS FIX** с конкретной задачей-фоллоу-апом.

---

## Часть F. Stack Gotchas ревизия (~30 мин)

Проверить:
- `Develop/stack_gotchas/INDEX.md` — минимум 2 новые ловушки из S8 внесены:
  - `gotcha-24-lightweight-charts-few-points-rightbar.md` (из S7 closeout).
  - `gotcha-25-api-paginated-type-mismatch.md` (создан DEV-4 W1).
- Каждый DEV-отчёт раздел 8 (новые Stack Gotchas) — если кто-то нашёл новую — соответствующий файл `gotcha-NN-*.md` создан в каталоге.
- Каждый DEV-отчёт раздел 7 (применённые Stack Gotchas) — минимум 2 ловушки на отчёт. Если нет — пометить как INFO (но не блокер).
- `Develop/stack_gotchas/README.md` — чеклист соблюдён (slug правильный, симптом/причина/правило/related_files заполнены).

---

## Часть G. Documentation completeness (~30 мин)

Проверить каждый файл (читать первые 50-100 строк + дату последнего обновления):

- [ ] `README.md` (корневой) — актуальный, ссылка на deployment_guide.
- [ ] `Develop/INSTALL.md` — обновлён, T-Invest SDK patched install шаг присутствует.
- [ ] `Документация по проекту/deployment_guide.md` — **создан** (Docker compose + Mac mini + launchd + Cloudflare Tunnel).
- [ ] `Документация по проекту/functional_requirements.md` — версия v2.5, S8-фичи добавлены.
- [ ] `Документация по проекту/technical_specification.md` — версия v1.5 с **реальными performance метриками** из части B.
- [ ] `Документация по проекту/development_plan.md` — M4 ✅, roadmap S9+ намечен.
- [ ] `Спринты/project_state.md` — финальная отметка M4 ✅ Production-ready.
- [ ] `Sprint_8/changelog.md` — финальная запись «8.R PASS / NEEDS FIX».
- [ ] `Sprint_8/sprint_state.md` — отражает завершение всех 3 волн.
- [ ] `Develop/CLAUDE.md` — polish (правила плагинов после S8-эксперимента).
- [ ] `Спринты/ui_checklist_s8.md` — создан UX-агентом, содержит S8-фичи.

---

## Часть H. Вердикт (~30 мин)

Один из трёх:

- **PASS** — все 8 секций OK, ни один контракт `NOT CONNECTED`, все метрики достигнуты, документация полная. → M4 ✅ Production-ready, флаг в `project_state.md`.
- **PASS WITH NOTES** — цели M4 достигнуты, но есть minor замечания → перенос в `Sprint_9_Review/backlog.md` как DEFERRED-S9. M4 ✅ закрыт, но с notes.
- **NEED FIXES** — критические блокеры (failed tests, NOT CONNECTED контракты, security high findings, performance метрики не в норме). M4 НЕ закрывается. ARCH формирует список fixes и отдаёт обратно DEV-агентам.

Финальный отчёт сохраняется в `Спринты/Sprint_8/arch_review_s8.md`.

# Опциональные задачи

Нет. Все 8 частей (A-H) — обязательные.

# Skip-тикеты в тестах

Не применимо (ARCH не пишет тесты). Однако ARCH **проверяет** все skip-тикеты других ролей:
- Каждый `pytest @pytest.mark.skip` / `test.skip` в S8 → имеет ли карточку в `Sprint_9_Review/backlog.md`?
- Skip без карточки — **блокер** приёмки, обязать DEV завести тикет до закрытия 8.R.

# Тесты

Не применимо (мета-проверка). Однако ARCH **прогоняет** полную регрессию:

```
cd Develop/backend && .venv/bin/python -m pytest tests/ --cov=app --cov-fail-under=80 -q
cd Develop/frontend && pnpm vitest run
cd Develop/frontend && pnpm playwright test --reporter=line
```

Фактические цифры — в часть B (метрики).

# ⚠️ Integration Verification Checklist

Для ARCH 8.R «integration verification» = вся часть E (grep production-кода) + часть D (Cross-DEV contracts) + часть C (event_type интеграционные тесты) + часть F (Stack Gotchas обновлены) + часть G (документация полная).

Если хотя бы один пункт не пройден:

- Контракт `NOT CONNECTED` → **NEED FIXES**.
- Метрика не достигнута без accepted-deviation → **NEED FIXES**.
- Skip без карточки в backlog → **NEED FIXES**.
- Документация не обновлена за S8 → **NEED FIXES** (правило памяти `feedback_review_docs.md` — синхронизация ФТ/ТЗ обязательна).

`PASS WITH NOTES` допустим только для minor (LOW priority) замечаний, перенесённых в Sprint_9 backlog.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

**2 файла:**

## 1. `Спринты/Sprint_8/arch_review_s8.md` — полный отчёт

Структура (повтор `Sprint_6_Review/code_review.md` + расширения):

```markdown
---
sprint: 8
agent: ARCH
phase: 8.R (final review)
date: 2026-05-<DD>
verdict: <PASS | PASS WITH NOTES | NEED FIXES>
---

# Sprint 8 — Финальное архитектурное ревью (задача 8.R)

> Формат повторяет Sprint_6_Review/code_review.md + Sprint_7/arch_review_s7.md.
> Источники: все DEV/UX/QA-отчёты Sprint_8/reports/, arch_design_s8.md (W0),
> Sprint_8/security_audit_s8.md, фактическая база кода Develop/backend/app/ и
> Develop/frontend/src/.

## Оглавление

0. Финальный вердикт
1. Backend Trading & Broker
2. Backend Backtest & Market Data
3. Backend Notification & Event sync L1
4. Backend Security
5. Backend Admin role + Performance
6. Frontend Charts editing
7. Frontend API contracts + ErrorBoundary + Strategy status + Dashboard + Admin panel
8. OPS Deployment + Documentation
9. Финальные метрики
10. 12-13 event_type интеграционные тесты
11. Cross-DEV contracts ревизия (C-S8-1..9)
12. Integration verification by grep
13. Stack Gotchas финал
14. Documentation completeness
15. Перенос задач (DEFERRED-S9)
16. Чеклист сдачи

## 0. Финальный вердикт: <PASS / PASS WITH NOTES / NEED FIXES>

<1-2 абзаца обоснования + ключевые цифры>

## 1-8. <Code review секции>

В каждой:
- Объём ревью (что проверено).
- Файлы (узкие места, file:line).
- Чеклист (OK / WARNING / NEEDS FIX).
- Результат секции.

## 9. Финальные метрики

<таблица из части B + интерпретация>

## 10. event_type интеграционные тесты

<таблица 12-13 строк>

## 11-15. <общие ревизии — части D, E, F, G, H>

## 16. Чеклист сдачи

- [ ] Все 8 секций code review проведены
- [ ] Integration verification (grep + contracts + events) пройден
- [ ] Stack Gotchas обновлены
- [ ] Финальные метрики записаны
- [ ] Документация обновлена (README/INSTALL/ФТ/ТЗ/development_plan/deployment_guide)
- [ ] Финальный вердикт зафиксирован
- [ ] project_state.md обновлён (M4 ✅ или причина задержки)
- [ ] Sprint_8/changelog.md обновлён («8.R PASS / NEEDS FIX»)
- [ ] Sprint_8/sprint_state.md отражает «✅ завершён»
- [ ] arch_review_s8.md сохранён
- [ ] reports/ARCH_S8_review.md сохранён (сводка до 400 слов)
```

## 2. `Спринты/Sprint_8/reports/ARCH_S8_review.md` — краткая 8-секционная сводка (до 400 слов)

Формат — стандартный 8-секционный отчёт DEV-агента (см. `prompt_template.md`):

```markdown
## ARCH отчёт — Sprint 8, задача 8.R Final Review

### 1. Что реализовано (ARCH-аспект)
### 2. Файлы (создан arch_review_s8.md + апдейты project_state.md / changelog)
### 3. Тесты (актуальные цифры pytest/vitest/playwright)
### 4. Integration points (контракты C-S8-1..9 статус)
### 5. Контракты для других DEV (для S9 — DEFERRED-S9 список)
### 6. Проблемы / TODO (если PASS WITH NOTES — minor; если NEED FIXES — список блокеров)
### 7. Применённые Stack Gotchas (какие ARCH использовал для верификации)
### 8. Новые Stack Gotchas (если ARCH обнаружил при ревью — описать)
### 9. Использование плагинов (pyright/typescript/playwright/code-review статус)
```

# Alembic-миграция (если применимо)

Не применимо в фазе ревью. Однако ARCH проверяет миграции, выполненные DEV-1 W1 (`users.is_admin`):

```bash
cd Develop/backend
alembic current  # должна быть применённая миграция add_users_is_admin
alembic downgrade -1 && alembic upgrade head  # smoke
```

Если миграция не применяется чисто → блокер.

# Чеклист перед сдачей

- [ ] Все 8 секций code review проведены (часть A).
- [ ] Финальные метрики собраны через **фактический запуск** (часть B), не «по словам DEV».
- [ ] 12-13 event_type интеграционные тесты прогнаны (часть C).
- [ ] Все 9 Cross-DEV контрактов C-S8-1..9 подтверждены grep'ом (часть D).
- [ ] Integration verification by grep — все ключевые точки подключены (часть E).
- [ ] Stack Gotchas INDEX.md + новые `gotcha-NN-*.md` проверены (часть F).
- [ ] Документация полная: README, INSTALL, ФТ v2.5, ТЗ v1.5 с реальными perf-метриками, development_plan, deployment_guide, project_state, changelog (часть G).
- [ ] Финальный вердикт PASS / PASS WITH NOTES / NEED FIXES зафиксирован (часть H).
- [ ] `Спринты/Sprint_8/arch_review_s8.md` сохранён (полный 16-разделённый отчёт).
- [ ] `Спринты/Sprint_8/reports/ARCH_S8_review.md` сохранён (краткая 9-секционная сводка до 400 слов).
- [ ] `Спринты/project_state.md` обновлён — M4 ✅ Production-ready (если PASS) или причина задержки (если NEED FIXES).
- [ ] `Sprint_8/changelog.md` финальная запись «8.R <вердикт>».
- [ ] `Sprint_8/sprint_state.md` отражает завершение.
- [ ] Если PASS WITH NOTES — список minor замечаний перенесён в `Sprint_9_Review/backlog.md` (создать если ещё не существует).
- [ ] Если NEED FIXES — список блокеров с file:line + назначенным DEV-агентом для hotfix-волны.
- [ ] Все плагины из секции «Обязательные плагины» использованы (pyright-lsp, typescript-lsp, playwright, code-review — обязательно); статус каждого — в секции 9 краткого отчёта.
