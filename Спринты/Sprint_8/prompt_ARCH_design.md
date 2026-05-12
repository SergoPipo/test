---
sprint: 8
agent: ARCH
role: Архитектурное design-ревью на W0 (pre-sprint M4 Production-ready)
wave: 0
depends_on: []
---

# Роль

Ты — архитектор проекта на этапе W0 Sprint 8 (M4 Production-ready). Твоя задача — провести аудит backlog'а из `Sprint_8_Review/backlog.md`, приоритезировать задачи, разбить на DEV-роли, выработать архитектурные решения для крупных пунктов и подготовить scope для каждой волны.

В отличие от feature-спринтов S1-S7, S8 — это **спринт стабилизации**. Новые крупные фичи **запрещены** (feature freeze). Фокус: coverage, security, performance, regression, документация, закрытие технического долга из 25+ S8-backlog карточек.

# Предварительная проверка

1. `Спринты/Sprint_8/sprint_state.md` прочитан.
2. `Спринты/Sprint_8/execution_order.md` прочитан целиком (включая список приоритезированного backlog).
3. `Спринты/Sprint_8_Review/backlog.md` прочитан **полностью** (все 25+ карточек).
4. `Спринты/project_state.md` прочитан. Особо: разделы «S8» (цели M4) и «S8 Review — обязательный чеклист» (13 event_type верификация).
5. `Спринты/Sprint_7/arch_review_s7.md` прочитан — понять что закрыто в S7 и что отложено.
6. `Develop/CLAUDE.md` целиком.
7. `Develop/stack_gotchas/INDEX.md` — все 23 ловушки. Обращай внимание на те, что могут пересечься с S8 задачами.
8. Preflight checklist (`Sprint_8/preflight_checklist.md`) пройден.

# Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| pyright-lsp | нет (design only) | — |
| typescript-lsp | нет | — |
| context7 | да — для pytest-cov, hypothesis (security), playwright performance APIs | WebSearch |
| playwright | нет (на W0 — план, на W1 — да) | — |
| code-review | нет (на W0 — design; на W3 — да) | — |
| frontend-design | нет (нет новых фич) | — |
| superpowers (brainstorming) | **да, для каждой большой категории** | — |

# Обязательное чтение (BEFORE design)

1. **`Sprint_8_Review/backlog.md`** — 25+ карточек, каждая с источником и приоритетом.
2. **`Спринты/project_state.md:105`** — раздел «S8 Review — обязательный чеклист: верификация всех обработчиков событий». 13 event_type **обязаны** реально публиковать уведомления.
3. **`Sprint_7/arch_review_s7.md`** — что закрыто в S7, что отложено в S8 (раздел DEFERRED-S8).
4. **`Sprint_7/changelog.md`** — записи 2026-04-27 → 2026-05-12 (post-S7 closeout) — понять масштаб технического долга и характер регрессий.
5. **`Документация по проекту/technical_specification.md`** — раздел про NFR (Non-Functional Requirements): performance targets (signal→order 500мс, dashboard 2с, Telegram 3с), security claims.
6. **`Документация по проекту/functional_requirements.md`** — раздел про security/privacy.
7. **Цитаты из ТЗ/ФТ** дословно — найти и зафиксировать в `arch_design_s8.md` для каждой категории.

# Рабочая директория

`Спринты/Sprint_8/` (создаёшь `arch_design_s8.md`).

# Контекст существующего кода

Что есть на старте S8 (после всех post-S7 closeout):

- **Backend:**
  - `app/auth/` — JWT + Argon2id (для security audit)
  - `app/sandbox/` — RestrictedPython executor + `_safe_import` whitelist (для escape-теста)
  - `app/common/crypto.py` — AES-256-GCM для broker keys (для crypto audit)
  - `app/middleware/csrf.py`, `rate_limit.py` — для headers/CSRF/brute-force audit
  - `app/trading/`, `app/circuit_breaker/`, `app/broker/tinvest/` — критические пути (приоритет coverage)
  - `app/notification/service.py` + EVENT_MAP — 13 event_type (приоритет верификация)
  - `app/broker/tinvest/multiplexer.py` — кандидат на singleton (`S7R-MULTIPLEXER-SINGLETON`)

- **Frontend:**
  - `Develop/frontend/src/api/*.ts` — type drift с `PaginatedResponse` (`S7R-API-PAGINATED-TYPE-MISMATCH`)
  - `Develop/frontend/src/App.tsx` — нет ErrorBoundary (`S7R-FRONTEND-ERROR-BOUNDARY-MISSING`)
  - `pages/DashboardPage.tsx` + `components/strategy/StrategyTable.tsx` — нет UI смены статуса (`S7R-STRATEGY-STATUS-CHANGE-UI`)
  - `components/charts/DrawingsLayer.tsx` — нет drag фигур (`S7R-DRAWING-EDITING`)

- **CI:**
  - `.github/workflows/ci.yml` — backend + frontend jobs
  - `.github/workflows/playwright-nightly.yml` — после S7R-NIGHTLY-CI-MOCKS работает только на frontend (mocks)
  - `actions/*` на Node 20 (deprecation до 2026-09-16, `S7R-CI-NODE24-MIGRATION`)

# Задачи

## 1. Аудит backlog + приоритезация

Через skill `superpowers:brainstorming` пройти по всем 25+ карточкам `Sprint_8_Review/backlog.md` и:

- Подтвердить приоритет каждой (medium-high / medium / low) или скорректировать.
- Разбить на DEV-роли: BACK1 (trading/security), BACK2 (notifications/CI), FRONT1 (charts/widgets), FRONT2 (dashboard/strategy/wizard), QA (E2E), OPS (perf/docs).
- Оценить чел.часы каждой карточки (1ч / полдня / 1 день / 1+ дней).
- Группировать связанные карточки в эпики (например, dashboard-related: `BALANCE-SPARKLINE-RANGE` + `HEALTH-EXTENDED-FIELDS` + `WIDGET-SPARKLINE-24H` + `HEALTH-WS-MIGRATION`).

В `arch_design_s8.md` секция «1. Backlog приоритезация» — итоговая таблица с роль/часы/группа.

## 2. Brainstorm Coverage стратегии

- Прогон `pytest --cov=app --cov-report=html` на текущем main → таблица модулей < 80%.
- Решить порядок дозаказа coverage: critical path (trading/CB/broker/sandbox) → secondary (notification/AI/backtest) → low (utils).
- Какие типы тестов добавлять: unit (нет dep) vs integration (с реальной БД через `pytest-asyncio` + sqlite memory).
- Целевой формат отчёта: html + markdown (`coverage_report.md`) для приёмки заказчиком.

В `arch_design_s8.md` секция «2. Coverage план» — таблица модулей с текущим % и целевым.

## 3. Brainstorm Security audit

Чек-листы по 5 направлениям:

### Crypto (AES-256-GCM для broker keys)
- IV uniqueness (per-encryption random 12 bytes)
- Key rotation план (есть ли механизм? нужен ли в S8?)
- JWT secret length ≥ 32 bytes (см. warning в pytest logs: «23 bytes long, below recommended»)

### Sandbox escape
- `_safe_import` whitelist актуален? Можно ли импортировать `os` / `subprocess` через `importlib`?
- `__builtins__` доступ через `object.__subclasses__()`? Известный обход RestrictedPython.
- Атаки на `eval`/`compile`/`exec` (запрещены?)

### CSRF
- Double-submit cookie pattern актуален в `middleware/csrf.py`?
- `samesite=Strict` или `Lax`? Lax достаточно для POST?

### Headers
- CSP — есть ли реальный header? Какой content-security-policy?
- HSTS — `Strict-Transport-Security` с `max-age` + `includeSubDomains`?
- X-Frame-Options: `DENY`
- X-Content-Type-Options: `nosniff`

### Brute-force
- Rate limit на `/auth/login` — текущая конфигурация? 3-5 попыток/мин подтверждено?
- Argon2id параметры: memory_cost / time_cost / parallelism — соответствуют OWASP recommendations?

В `arch_design_s8.md` секция «3. Security audit план» — для каждого из 5 направлений: что проверять, как, какой инструмент (pytest custom + hypothesis для fuzzing).

## 4. Brainstorm Performance testing

Метрики из ТЗ (цитировать дословно):
- Dashboard первый paint < 2с
- Signal → place_order p95 < 500мс
- Telegram-команда → reply < 3с

Для каждой метрики:
- Как измерять (chrome devtools / pytest-benchmark / custom timing logs)
- Baseline (текущие значения) → нужно собрать в W0
- Целевые показатели + alerts при регрессии
- Инструментация: добавить ли `structlog` event с `duration_ms` в критические точки?

В `arch_design_s8.md` секция «4. Performance план» — таблица метрик + методология.

## 5. Brainstorm 6 missing E2E

Каждый из 6 spec'ов (`s7-export.spec.ts`, `s7-backup.spec.ts`, `s7-events.spec.ts`, `s7-tg-callbacks.spec.ts`, `s7-backtest-analytics.spec.ts`, `s7-bg-backtest.spec.ts`):

- Какие моки нужны (расширить `fixtures/api_mocks.ts`?).
- Какие data-testid должны быть на странице (проверить наличие в коде S7).
- Какие edge cases покрыть (graceful degrade, race conditions).

В `arch_design_s8.md` секция «5. E2E план» — таблица spec'ов с покрываемыми сценариями.

## 6. Brainstorm 13 event_type верификация

> **Цитата из `project_state.md:105` (дословно):**
> «Все 13 event_type из NotificationSettingsPage реально генерируют уведомления при соответствующих runtime-событиях. Для каждого event_type: включить Telegram + Email в настройках → вызвать событие → проверить доставку во все 3 канала.»

- Какие event_type реально публикуются runtime'ом сейчас (grep по `event_bus.publish`).
- Какие подключены к `EVENT_MAP` (`app/notification/service.py`).
- Какие отсутствуют. Какие неверно подставляют контекст ({strategy_name}/{ticker}/...).
- Интеграционный тест: реальный сценарий бэктест → notification → Telegram-mock + Email-mock.

В `arch_design_s8.md` секция «6. 13 event_type верификация» — таблица 13 × 3 канала.

## 7. Brainstorm Documentation

- `README.md` — что обновить (deployment, требования, getting started)
- `Документация по проекту/deployment_guide.md` — новый файл (Docker/systemd/nginx/SSL/backup-restore)
- `Sprint_8/changelog.md` — финальная сводка спринта
- Итоговый `project_state.md` отметка M4 ✅

## 8. Wave breakdown + Cross-DEV contracts

По итогам аудита backlog'а:

- W1 потоков: 5 параллельных (см. `execution_order.md`). Уточнить точную разбивку задач по DEV-ролям.
- W2 потоков: 4 параллельных. Уточнить.
- W3 потоков: 4 потока (low fixes / UX / docs / 8.R).
- Cross-DEV contracts: какие API/типы передаются между BACK и FRONT (новые endpoint'ы, новые поля в response). Минимум: `/health` extended, sparkline endpoint, /notifications/telegram/test endpoint.

В `arch_design_s8.md` секция «8. Wave breakdown + contracts» — финальная таблица.

# Формат отчёта (создаваемого arch_design_s8.md)

Структурированный документ, разделы 1-8 как выше. В каждом — конкретные решения (не «обсудим позже»), оценки часов, цитаты из ТЗ дословно.

В конце — раздел «Что НЕ делать в S8» (явный список фичей, которые **запрещены** из-за feature freeze).

# Критерии приёмки W0

- `arch_design_s8.md` создан и охватывает все 8 секций.
- Все 25+ карточек backlog'а получили роль / часы / волну.
- 13 event_type таблица заполнена с пометкой PUBLISHED / NEEDS_WIRING.
- Цитаты из ТЗ для performance / security / coverage — дословно.
- `execution_order.md` обновлён с финальной разбивкой потоков W1/W2/W3.
- Cross-DEV contracts таблица в `execution_order.md` заполнена.
- DEV-промпты (`prompt_DEV-1.md` ... `prompt_DEV-N.md`) и `prompt_QA.md` созданы.
- Заказчик утвердил `arch_design_s8.md` (gate W0 → W1).
