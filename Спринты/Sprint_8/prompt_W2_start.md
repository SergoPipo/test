# Старт-промпт для Sprint 8 Wave 2

> Скопируй текст ниже как первое сообщение в новой Claude-сессии в этом проекте.
> Сессия должна работать в `/Users/sergopipo/Documents/Claude_Code/Test`.

---

Привет. Запускаем Sprint 8 Wave 2 (M4 Production-ready).

Контекст:
- Sprint 7 закрыт окончательно 2026-05-12.
- Sprint 8 W0 ARCH-design завершён, W1 ЗАВЕРШЁН 2026-05-12.
- W1 коммиты: `169cbf9` в test-репо (docs/sprint-8), `9f1c741` в Develop-репо (s8/sprint-8).
- Gate W1 → W2 пройден (1 критерий частично deferred — 4 P1 модуля coverage переходят
  в W2 Поток A по архитектурной зависимости от MULTIPLEXER-SINGLETON).
- Ветки готовы (обе clean после W1 коммитов).

Шаги (читай в указанном порядке):

1. Прочитай Спринты/project_state.md — пойми текущий статус.
2. Прочитай Спринты/Sprint_8/sprint_state.md — раздел «W1 ЗАВЕРШЁН» с
   фактическими метриками + 5 секций потоков (BACK1+BACK2+FRONT1+FRONT2+QA).
3. Прочитай Спринты/Sprint_8/arch_design_s8.md целиком (8 секций + §11-12).
4. Прочитай Спринты/Sprint_8/execution_order.md — потоки W2 (A/B/C/D) +
   9 Cross-DEV contracts (C-S8-1..C-S8-9).
5. Прочитай Спринты/Sprint_8/e2e_test_plan_s8.md — раздел про AIChat W2 +
   acceptance criteria.
6. Прочитай Спринты/Sprint_8/changelog.md — последние записи W1 (для контекста).
7. Прочитай Спринты/Sprint_8/security_audit_s8.md — 3 high findings, которые
   нужно закрыть в W2 (S8R-SEC-HEADERS / S8R-SEC-TELEGRAM-XSS / S8R-SEC-EMAIL-XSS).
8. По желанию прочитай Спринты/Sprint_8/reports/DEV-*_W1.md и QA_W1.md (5 отчётов)
   — там точные детали что было сделано, файлы и tested баги.

Что запустить в W2 (4 параллельных потока + AIChat mock от QA):

Поток A — BACK1 (DEV-1, ~24ч) — prompt_DEV-1.md (W2 часть)
  Coverage P1 закрытие (4 модуля):
    - broker/tinvest/adapter.py 24% → 80% (моки tinkoff API, ≈16ч —
      теперь разрешено, MULTIPLEXER-SINGLETON contract готов с W1 BACK2)
    - market_data/service.py 50% → 80% (≈12ч → возможно частично)
    - backtest/router.py 25% → 80% (FastAPI endpoint тесты, ≈12ч)
    - backtest/engine.py 55% → 80% (≈8ч)
  + AIChat mock block_xml (e2e fixture, ~2ч) — координация с QA
  + Performance instrumentation @timed_event в app/common/observability.py (~4ч)

Поток B — BACK2 (DEV-2, ~25ч) — prompt_DEV-2.md (W2 часть)
  Event type sync (новый эпик L1, ~12ч):
    - Подключить publish-сайты: session_recovered (после graceful restart NS),
      backtest_completed (app/backtest/jobs.py:226), daily_stats (scheduler),
      corporate_action (app/corporate_actions/), price_alert
      (app/market_data/price_alert_monitor.py)
    - Расширить EVENT_MAP в app/notification/service.py
    - C-S8-9 контракт для FRONT2 (EVENT_TYPE_LABELS sync)
  Dashboard widgets backend (~13ч):
    - C-S8-1 — extended /api/v1/health (cb_state, tinvest_connected,
      scheduler_running, scheduler_jobs)
    - C-S8-2 — /api/v1/market-data/sparkline?ticker=X&hours=24
    - C-S8-3 — /api/v1/account/balance/history?since_first_activity=true
    - C-S8-4 — /api/v1/notifications/telegram/test
    - S7R-CONNECTION-EVENTS-MARKET-CLOSED — фильтр MOEX calendar
  3 high security fixes из security_audit_s8.md:
    - S8R-SEC-HEADERS — SecurityHeadersMiddleware (~30 LoC), активирует
      6 xfail тестов из W1
    - S8R-SEC-TELEGRAM-XSS — _safe_format helper в notification/dispatchers
    - S8R-SEC-EMAIL-XSS — аналогично для email templates

Поток C — FRONT2 (DEV-4, ~22ч) — prompt_DEV-4.md (W2 часть)
  Dashboard widgets frontend (потребитель C-S8-1..4 от BACK2, ~10ч)
  Event sync UI labels (потребитель C-S8-9 от BACK2):
    - 4 backend event_types в EVENT_TYPE_LABELS (NotificationSettingsPage.tsx:24)
  S7R-GRID-HEATMAP-ENTRYPOINT (~2ч) — точка вызова из BG-badge
  S7R-WIDGETS-UNIT-COVERAGE (~4ч)
  Plotly Dash /admin/metrics (~4ч) — app/admin/metrics_dash.py + WSGIMiddleware
    mount в app/admin/router.py. Использует is_admin (BACK1 W1, C-S8-8)
  S8R-ANALYTICS-EQUITY-ZONES-TESTID — DOM overlay для canvas зон equity-curve
    (разблокирует s7-backtest-analytics 2 skipped теста)
  S8R-ANALYTICS-TRADE-ROW-CLICK — onClick на rows в BacktestTrades.tsx
  S7R-ORDER-MANAGER-REAL-MODE-COVERAGE (если успеет — иначе W3)

Поток D — BACK1 (~10ч) — prompt_DEV-1.md (W2 часть, продолжение)
  Coverage P2 router-тесты:
    - auth/router 67% → 80% (≈3ч)
    - notification/router 51% → 80% (≈4ч)
    - broker/router 37% → 80% (≈6ч)
    - market_data/router 62% → 80% (≈4ч)
    - strategy/router 52% → 80% (≈5ч)
    - circuit_breaker/router 60% → 80% (≈3ч)

QA — AIChat mock + регрессия (~3ч) — prompt_QA.md (W2 часть)
  - mockAiChat: добавить реалистичный block_xml с ≥3 блоками
    (condition + indicator + action) — координация с BACK1 формат
  - Снять test.skip 'S6R-AICHAT-APPLY-MOCK'
  - Запустить полную регрессию Playwright + frontend vitest

Cross-DEV contracts критичные для W2:
  - C-S8-1 (extended /health, BACK2 → FRONT2)
  - C-S8-2 (sparkline endpoint, BACK2 → FRONT2)
  - C-S8-3 (balance history since_first_activity, BACK2 → FRONT2)
  - C-S8-4 (telegram test endpoint, BACK2 → FRONT2)
  - C-S8-8 (admin metrics, BACK1+FRONT2)
  - C-S8-9 (event type sync, BACK2 → FRONT2)

Порядок запуска агентов:
  1. Сначала BACK2 (Поток B) — поставщик C-S8-1..4 + C-S8-9.
     FRONT2 (Поток C) на него ссылается для dashboard widgets и event sync.
  2. После того, как BACK2 закроет 4 dashboard endpoints + event publishers →
     запустить параллельно: BACK1 Поток A (coverage P1 + performance + AIChat
     mock backend), FRONT2 Поток C, QA W2.
  3. После закрытия Потока A → BACK1 Поток D (coverage P2 router-тесты),
     можно параллельно с FRONT2 если оба ещё работают.

Рабочие ветки:
  - test-репо (документация, отчёты): docs/sprint-8 (HEAD = 169cbf9 после W1)
  - Develop-репо (код): s8/sprint-8 (HEAD = 9f1c741 после W1)

Тестовый baseline на старте W2 (зафиксировать факт перед стартом):
  - Backend pytest: 1098 passed / 6 xfailed / 0 failed
  - Frontend vitest: 528 passed / 0 failed
  - Playwright nightly: 157 passed / 1 pre-existing flaky / 6 skipped
  - Backend coverage TOTAL: ≈74% (после +3% от W1 за счёт dispatchers + trading/service)
  - CI develop: ✅ зелёный (предполагается)
  - Frontend lint: 0 errors / 9 warnings (baseline, W3 cleanup)

Gate W2 → W3:
  - Coverage TOTAL ≥ 80% (4 P1 модуля + 6 P2 router-тестов)
  - Performance метрики baseline'ed и в норме:
    - дашборд первый paint < 2с (Chrome DevTools)
    - signal → place_order p95 < 500мс (pytest-benchmark)
    - Telegram-команда < 3с (structlog timing)
  - Event type sync завершён (UI ↔ EVENT_MAP консистентны)
  - 3 high security fixes сделаны (HEADERS xfail → green, TELEGRAM-XSS, EMAIL-XSS)
  - ≥ 80% medium-карточек закрыто
  - Plotly Dash /admin/metrics работает под require_admin
  - AIChat mock дополнен, test.skip 'S6R-AICHAT-APPLY-MOCK' снят

Запреты:
  - Не запускать W3 пока не закрыт W2
  - Не вводить новые фичи (только стабилизация M3 → M4)
  - Не делать UX финальный юзабилити-тест (это W3, поток B UX)
  - Не писать deployment_guide.md (это W3, поток C OPS/BACK1)
  - Не активировать --cov-fail-under=80 в CI (это W3, после довода)
  - Не удалять 2 spec'а Blockly mode B (это W3 cleanup)

После завершения W2:
  1. Каждый DEV сохраняет отчёт в Sprint_8/reports/DEV-N_W2.md
     (9-секционный формат, до 400 слов)
  2. QA сохраняет Sprint_8/reports/QA_W2.md (AIChat mock + регрессия)
  3. Обновить Sprint_8/changelog.md записями каждого DEV
  4. Обновить Sprint_8/sprint_state.md → «✅ W2 ЗАВЕРШЁН» с фактическими
     метриками (тесты, coverage, время по потокам)
  5. Коммит в обе ветки (docs/sprint-8 + s8/sprint-8), мне на подтверждение

Не переходи к W3 без моей команды. Закончи на «W2 done, ожидаю старт W3».
