---
sprint: 7
agent: ARCH
wave: 0
date: 2026-04-25
report_type: W0 design
---

# ARCH W0 Design — Sprint 7

## 1. Реализовано

W0 design ревью закрыто 6 архитектурных пробелов перед стартом DEV-агентов:

- **7.1 Версионирование стратегий.** Используем существующую `strategy_versions` (`Develop/backend/app/strategy/models.py:50`); расширение колонками `created_by`, `comment`. Политика — авто-снимок на Save (с idempotency 5 мин), явная «именованная версия», history-preserving restore.
- **7.2 Grid Search.** `multiprocessing.Pool` (workers = `os.cpu_count()-1`) per-комбинация. Hard cap 1000 комбинаций, ≤ 5 параметров. WS — переиспользуем `/ws/backtest/{job_id}` с `result.matrix`. Overfitting-предупреждение ((sharpe[0]-sharpe[4])/sharpe[0] > 0.5).
- **7.13 5 event_type → runtime.** Добавлены 5 EVENT_MAP-записей (`trade.opened`, `order.partial_fill`, `order.error`, `connection.lost`, `connection.restored`); указаны file:line для publish (engine.py on_order_filled, OrderManager.process_signal helper, multiplexer.py:207/213). Анти-спам флаг для connection_lost.
- **7.15 WS /ws/trading-sessions/{user_id}.** Auth через первое сообщение `{action:'auth',token}` (паттерн ТЗ §4.12). Snapshot+delta. Подписка на `system:{user_id}` для динамических сессий. Удаление polling 10s одним PR.
- **7.17 Фоновые бэктесты.** Новая таблица `backtest_jobs`. Cap 3/user. Custom executor (asyncio.create_task + BacktestJobManager singleton, не FastAPI BackgroundTasks). WS закрывается через 30 сек после терминала.
- **7.18 AI context.** `context: list[ContextItem]` с типами {chart, backtest, strategy, session, portfolio}. Многоступенчатая защита: Pydantic + ownership-check в БД + sanitization + system-prompt prefix `[CONTEXT]...[/CONTEXT]` + rate-limit 10/min.

## 2. Файлы

- `Спринты/Sprint_7/arch_design_s7.md` — полный design (~600 строк, 10 секций)
- `Спринты/Sprint_7/reports/ARCH_W0_design.md` — этот отчёт

## 3. Применённые Stack Gotchas

#04 (T-Invest stream reconnect), #08 (AsyncSession.get_bind в pytest), #11 (alembic drift), #12 (SQLite batch_alter_table), #15 (T-Invest tz-naive), #16 (401 race), #17 (telegram bot frozen) — выписаны с привязкой к задачам S7 в §7.

## 4. Новые Stack Gotchas

Кандидат: **gotcha-19-event-map-payload-contract.md** (рассинхрон EVENT_MAP ↔ publish-payload). Не создаю превентивно — только если в S7 повторится. DEV-1 обязан написать unit-тест `test_event_map_payload_keys()` (§3.6 design).

## 5. Точки риска для DEV W1/W2

- **DEV-1 (BACK1) 7.13:** анти-спам connection_lost — флаг `_connection_event_published`, иначе спам как gotcha-18.
- **DEV-1 7.17:** очередь — in-memory + persistence в БД (`backtest_jobs`); восстановление при рестарте → status=failed.
- **DEV-2 (BACK2) 7.1:** alembic batch_alter_table обязательно (gotcha-12); backfill `created_by` через subquery.
- **DEV-2 7.18:** ownership-check возвращает 404 (не 403) — не утекать существование чужих id.
- **FRONT2 7.1:** не стартует пока migration не commit'нута (контракт C4).
- **DEV-3 (FRONT1) 7.15:** reconnecting-websocket с REST-fallback на первый load.

## 6. Использованные плагины

- **WebSearch** (правило `feedback_websearch_api.md`): FastAPI WebSocket JWT (подтвердил «первое сообщение auth» паттерн), `multiprocessing.Pool` vs ProcessPoolExecutor (подтвердил Pool для CPU-bound grid).
- **superpowers:brainstorming** (in-line): каждая из 6 секций design — 5–8 итераций «вопрос → варианты → решение → обоснование».
- **context7** не вызывал — задачи не требовали свежей документации сторонних API в design-фазе (FastAPI/SQLAlchemy паттерны стабильные, проверены в коде проекта).

## 7. Цитаты ТЗ/ФТ

Дословные цитаты в `arch_design_s7.md`: §1 (ТЗ §3.4 strategy_versions, §1300 schema_version), §2 (ТЗ §5.3.4 Grid Search), §3 (project_state.md:79–101 MR.5), §4 (ТЗ §2.3, §4.12 WebSocket), §5 (ФТ §17 + UX макет), §6 (ТЗ §4.7 AI API, §1810 system prompt). Для всех 6 brainstorm-задач цитаты приложены.

## 8. Готовность гейта W0 → W1

**ARCH часть: ✅ ГОТОВО.**
Не закрыто (вне scope ARCH W0): Alembic-миграции (W2 DEV-1/DEV-2), QA `e2e_test_plan_s7.md` (отдельная зона QA W0). UX 6 макетов уже в `Sprint_7/ux/` — стыки проверены в §8 design.
