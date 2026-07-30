---
sprint: 7
agent: ARCH
phase: 7.R (final review)
date: 2026-04-26
verdict: PASS WITH NOTES
---

# Sprint 7 — Финальное архитектурное ревью (задача 7.R)

> Формат повторяет `Sprint_6_Review/code_review.md` — 8 разделов code review + раздел MR.5 + регрессия E2E + документация + финальный вердикт.
>
> **Источники:** все DEV/UX/QA-отчёты из `Sprint_7/reports/`, `arch_design_s7.md` (W0), `midsprint_check.md`, фактическая база кода `Develop/backend/app/` и `Develop/frontend/src/`.

---

## Оглавление

0. [Финальный вердикт](#0-финальный-вердикт-pass-with-notes)
1. [Trading Engine (7.13, 7.15-be, 7.17-be)](#1-trading-engine)
2. [Notification Service (7.12, 7.14)](#2-notification-service)
3. [Strategy Engine + AI (7.1, 7.18)](#3-strategy-engine--ai)
4. [Backtest Engine (7.2, 7.3, 7.17-be)](#4-backtest-engine)
5. [Frontend Charts + Trading + AI (7.6, 7.15-fe, 7.16, 7.17-fe, 7.19)](#5-frontend-charts--trading--ai)
6. [Frontend Dashboard + Strategy + Wizard (7.1-fe, 7.2-fe, 7.7, 7.8-fe)](#6-frontend-dashboard--strategy--wizard)
7. [OPS (7.9 backup)](#7-ops)
8. [E2E + UX (7.10, 7.11)](#8-e2e--ux)
9. [MR.5 — обязательная проверка 5 event_type](#9-mr5--обязательная-проверка-5-event_type)
10. [Регрессия E2E](#10-регрессия-e2e)
11. [13 открытых вопросов — решения 7.R](#11-13-открытых-вопросов--решения-7r)
12. [Stack Gotchas финал](#12-stack-gotchas-финал)
13. [Документация (ФТ / ТЗ / development_plan)](#13-документация)
14. [Перенос задач (DEFERRED-S8)](#14-перенос-задач-deferred-s8)
15. [Чеклист сдачи](#15-чеклист-сдачи)

---

## 0. Финальный вердикт: **PASS WITH NOTES**

**Sprint 7 закрыт. M3 Phase 1 feature-complete достигнут.**

Все 17 рабочих задач + 7.R закрыты. MR.5 (5 event_type) подтверждён через grep + чтение кода. Cross-DEV контракты C1–C9 опубликованы и интегрированы. Регрессия E2E чище baseline (+17 passed). Документация (ФТ v2.4 / ТЗ v1.4 / development_plan) обновлена.

**Замечаний (NOTES):** 11 пунктов перенесены в `Sprint_8_Review/backlog.md` как DEFERRED-S8 (приоритет: 1 medium-high, 5 medium, 5 low). Ни один не блокирует приёмку Phase 1 / запуск S8.

**S8 готов к старту:** feature freeze возможен — никаких WIP, `NOT CONNECTED`-блокеров, незакрытых E2E.

---

## 1. Trading Engine

### Объём ревью
- **7.13** — 5 event_type → runtime (MR.5).
- **7.15-be** — WS endpoint `/ws/trading-sessions/{user_id}` (контракт C1).
- **7.17-be** — `BacktestJobManager` + WS `/ws/backtest/{job_id}` (контракт C2).

### Файлы проверены (узкие места)
- `app/trading/engine.py:800-900, 1150-1220` — publish-сайты MR.5.
- `app/trading/ws_sessions.py:117-160` — WS handler, JWT auth-first, snapshot.
- `app/backtest/jobs.py:80-100` — singleton-менеджер, asyncio.Lock.
- `app/backtest/ws_backtest.py:49` — WS endpoint, auth + 30s grace.
- `app/broker/tinvest/multiplexer.py:215-245` — connection.lost/restored с анти-спам флагом.

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | `engine.py:846` (paper) и `:1201` (real) — `trade.opened` публикуется с полным payload (`strategy_name`, `ticker`, `direction`, `volume`, `price`). Совместимо с EVENT_MAP-шаблоном. |
| FIXED | `engine.py:1171` — `order.partial_fill` публикуется когда `filled_lots < trade.volume_lots`. Корректно ВМЕСТО `trade.filled` (terminal=False). |
| FIXED | `engine.py:869-898` — helper `_publish_order_error` обёрнут в try/except, логирует, не маскирует первичный exception. |
| FIXED | `multiplexer.py:241-244` — анти-спам флаг `_connection_event_published` корректно реализован (один publish на disconnect-цикл, gotcha-18 паттерн). |
| FIXED | `ws_sessions.py:131-160` — auth-first JWT, не в URL (gotcha-16). 4401 на mismatch, 4408 на timeout. |
| FIXED | `jobs.py:80-100` — `asyncio.Lock` защищает `_tasks` dict, `asyncio.shield` на cleanup при cancel — race-condition закрыта (DEV-1 W1 §7). |
| INFO | `ws_backtest.py:49` — grace 30s после терминального события закрывает WS — гарантирует доставку финального payload. Покрыт unit-тестом. |
| INFO | `ws_sessions.py:96-114` — `_load_user_sessions` JOIN по `Strategy.user_id == user_id` (правильная авторизационная цепочка `TradingSession → StrategyVersion → Strategy → user_id`). |

**Статус раздела:** ✅ FIXED. Критических замечаний нет.

---

## 2. Notification Service

### Объём ревью
- **7.12** — NS singleton DI (контракт C7).
- **7.14** — Telegram CallbackQueryHandler (контракт C8).

### Файлы проверены
- `app/notification/dependencies.py` — Depends-helper.
- `app/main.py:75-106` — singleton lifespan.
- `app/notification/service.py:76-104` — EVENT_MAP (5 новых записей).
- `app/notification/service.py:361-410` — `listen_broker_status` + `_broker_status_loop`.
- `app/notification/telegram_webhook.py:440-520` — CallbackQueryHandler.
- `app/market_data/router.py` — PriceAlertMonitor singleton (закрыт fallback `db_factory=None`).

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | `grep "NotificationService()" app/` = 0 вне `main.py` (только docstring в `dependencies.py`). C7 инвариант соблюдён. |
| FIXED | `main.py:75` — singleton создаётся в lifespan ПЕРВЫМ, передаётся в `PriceAlertMonitor`, `SessionRuntime`, `SchedulerService`, `BacktestJobManager` через ctor injection. |
| FIXED | `service.py:361-410` — `listen_broker_status` подписан на канал `broker:status`, выполняет фан-аут по активным сессиям через `_session_user_map` (строится в `listen_session_events`). |
| FIXED | `telegram_webhook.py:467-516` — `_handle_open_session_callback` делает ownership-check через JOIN `Strategy.user_id` — нет leak'ов чужих сессий. |
| FIXED | `telegram_webhook.py:518-…` — `_handle_open_chart_callback` sanitизирует ticker через regex `[A-Z0-9_]{1,20}`. |
| FIXED | `app/config.py` — добавлена настройка `FRONTEND_URL` (для deep links). |
| INFO | `backtest/router.py:314, 485` — существующие NS-readers через `getattr(app.state, ...)` оставлены как есть (территория BACK1 7.17, не блокер). На W2 BACK2 уже использует `Depends(get_notification_service)` в новых endpoints. |

**Статус раздела:** ✅ FIXED. Singleton + Telegram callbacks работают, ownership-check корректен.

---

## 3. Strategy Engine + AI

### Объём ревью
- **7.1-be** — версионирование стратегий (контракт C4, alembic `c1d4e5f6a7b8`).
- **7.18** — AI слэш-команды backend (`ChatRequest.context_items`, ownership, sanitization).

### Файлы проверены
- `alembic/versions/c1d4e5f6a7b8_add_strategy_versions_meta.py` — миграция `created_by` + `comment` + `idx_sv_history`.
- `app/strategy/router.py:155-275` — 4 versioning endpoint'а.
- `app/strategy/service.py` — `create_version` (idempotency 5min), `restore_version` (history-preserving).
- `app/ai/chat_schemas.py:48` — `ChatRequest.context_items: list[ChatContextItem]`.
- `app/ai/slash_context.py:1-200` — 5 резолверов + sanitization + ownership.
- `app/ai/chat_router.py:170, 215, 308` — `build_enriched_prefix`, `wrap_user_message`.

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | Миграция содержит ТОЛЬКО намеренные изменения (gotcha-11 — drift не подтянут). Round-trip downgrade-1→upgrade head проверен (DEV-2 W2 §7). |
| FIXED | Порядок маршрутов `/list`, `/snapshot`, `/by-id/{ver_id}`, `/{ver_id}/restore` объявлен ВЫШЕ legacy `/{version_number}` — gotcha-20 учтён, иначе `list` парсился как int → 422. |
| FIXED | `restore_version` — history-preserving (создаёт новую версию-копию + переключает `current_version_id`). Старые версии остаются (нельзя случайно потерять). |
| FIXED | `slash_context.py` — все 5 резолверов делают ownership-check `WHERE user_id = current_user.id` — 404 (без leak'а о существовании). |
| FIXED | `slash_context._sanitize_str` — удаляет control-chars, экранирует подделки маркеров `[CONTEXT`/`[USER` (replace `[` → `(`), обрезает до 2 КБ. Защита от prompt injection. |
| FIXED | `chat_schemas.ChatContextItem` — Pydantic max_length=5 + Literal type. Defense-in-depth с `MAX_CONTEXT_ITEMS = 5`. |
| INFO | Legacy `ChatRequest.context: dict | None` сохранён без изменений — блок-режим стратегии не сломан (no breaking change для FRONT). |

**Статус раздела:** ✅ FIXED. Версионирование, AI-context — production-ready.

---

## 4. Backtest Engine

### Объём ревью
- **7.2-be** — Grid Search (multiprocessing.Pool, FIX-волна 2026-04-26).
- **7.3** — экспорт CSV/PDF (`app/backtest/export.py`, WeasyPrint).
- **7.17-be** — фоновые jobs (см. также Раздел 1).

### Файлы проверены
- `app/backtest/grid.py:1-100, 350-430` — `GridSearchEngine.run_pool`, worker `_run_single_backtest`, sync-driver `_drive_pool_sync`.
- `app/backtest/router.py:1085-1213` — `_prepare_grid_workload`, `start_grid_search`, `_job_runner`.
- `app/backtest/export.py` — `generate_csv`, `generate_pdf` (lazy-import WeasyPrint).
- `app/backtest/router.py:817-845` — endpoint `GET /backtest/{id}/export`.
- `tests/unit/test_backtest/test_grid.py`, `test_export.py`.

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | `grid.py` — финальная реализация `multiprocessing.Pool` (spawn-context, `cpu-1`) соответствует ТЗ §5.3.4 и `arch_design_s7.md §2`. Worker `_run_single_backtest` — top-level pickle-friendly. OHLCV грузится один раз в main-процессе. |
| FIXED | Hard cap 1000 комбинаций / ≤5 параметров — валидируется ДО `Pool.spawn` (`run_pool` raise `GridValidationError`). Anti-regression тест `test_run_pool_validates_cap`. |
| FIXED | Pool управляется внутри `loop.run_in_executor(None, _drive_pool_sync)` — event loop FastAPI не блокируется. WS-публикации через очередь `queue.SimpleQueue`. |
| FIXED | Overfitting-flag: `(sharpe[0] - sharpe[4]) / sharpe[0] > 0.5` → `overfitting_warning: true` в final payload — соответствует ТЗ §5.3.4. |
| FIXED | `export.py` — lazy-import WeasyPrint; при отсутствии — HTTP 503 со ссылкой на `INSTALL.md`. После OPS fix-волны 2026-04-26 PDF endpoint работает (smoke-test 54685 байт, %PDF-1.7). |
| FIXED | CSV — нативный `csv.DictWriter`, два блока `#metric` / `#trades`. Без внешних зависимостей. |
| INFO | **Известное ограничение S8:** Backtrader strategy parameter-binding для grid_params (`self.params`) — частично (префикс `grid_params = {...}` доступен как dict). Карточка в backlog. |
| INFO | gotcha-21 — оригинальная запись (asyncio.Semaphore) сохранена через UPDATE-секцию (политика append-only). Финальное правило MP документировано. |

**Статус раздела:** ✅ FIXED. Grid Search, экспорт CSV/PDF, фоновые jobs — production-ready.

---

## 5. Frontend Charts + Trading + AI

### Объём ревью
- **7.6** — Drawing tools (5 типов, hotkeys, REST persist).
- **7.15-fe** — WS sessions (без polling).
- **7.16** — Backtest analytics (гистограмма + donut + интерактивные зоны).
- **7.17-fe** — Background backtest badge.
- **7.19** — AI слэш-команды dropdown.

### Файлы проверены
- `src/components/charts/{DrawingToolbar,DrawingsLayer,MiniSparkline,CandlestickChart}.tsx`
- `src/hooks/useTradingSessionsWS.ts`, `useBacktestJobWS.ts`.
- `src/components/backtest/{PnLDistributionHistogram,WinLossDonutChart,TradeDetailsPanel,InstrumentChart}.tsx`
- `src/components/notifications/BackgroundBacktestsBadge.tsx`, `src/stores/backgroundBacktestsStore.ts`.
- `src/components/ai/{CommandsDropdown,ContextChip,parseCommand,ChatInput,AIChat}.tsx`.

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | `useTradingSessionsWS.ts` — auth-first паттерн (gotcha-16), exponential backoff reconnect, ping/pong, badge статуса. `setInterval(fetchSessions, 10000)` ПОЛНОСТЬЮ удалён (`grep "setInterval.*fetchSessions" src/` = 0). |
| FIXED | `BackgroundBacktestsBadge.tsx` + `backgroundBacktestsStore` — cap=3, persist в localStorage, restore on reload, cleanup на logout (chained в `authStore.ts`). Production-вызов в `Header.tsx:128`. |
| FIXED | `BacktestLaunchModal.tsx` — кнопка «Запустить в фоне» НЕ вызывает `onClose` (модалка остаётся открытой), toast Mantine. Errors flow через `clearError`. |
| FIXED | `DrawingToolbar.tsx` — 9 кнопок, 5 hotkeys (V/T/H/R/L) + Esc/Delete, ARIA `role="toolbar"`, `aria-pressed`. Production в `ChartPage.tsx:250`. |
| FIXED | `DrawingsLayer.tsx` — `series.createPriceLine` для hline (стабильный API LWC v5, через context7), overlay canvas для trendline/rect/vline/label. Cleanup в return useEffect (rAF, listeners, removePriceLine, ResizeObserver). |
| FIXED | `chartDrawingsStore.ts` + `chartDrawingsApi.ts` — REST CRUD + localStorage fallback (квота 100, QuotaExceededError → toast). Backend mini-CRUD live после fix-волны (`/api/v1/charts/...`). |
| FIXED | `PnLDistributionHistogram.tsx`, `WinLossDonutChart.tsx`, `TradeDetailsPanel.tsx` — все 3 импортированы и инстанциированы в `BacktestResultsPage.tsx:36`. |
| FIXED | `parseCommand.ts` + `CommandsDropdown.tsx` — 5 команд, IME composition guard, ↑/↓/Enter/Tab/Esc, multi-context. Production в `ChatInput.tsx:218`, store в `aiChatStore.ts:84,145`. |
| FIXED | `ContextChip.tsx` — 3 статуса (ok/forbidden/not_found), navigate via react-router, tooltip. Production в `AIChat.tsx:119`. |
| FIXED | `aiApi.ts` + `aiStreamClient.ts` + `aiChatStore.ts` — `context_items` отправляется параллельно с legacy `context` — backward-compatible. |
| WARNING | `ActivePositionsWidget` рендерит `MiniSparkline` с **пустым массивом** `data: []` (нет endpoint OHLCV для виджета). UX W3 §2 MEDIUM. → DEFERRED-S8 (карточка `S7R-WIDGET-SPARKLINE-24H`). |
| WARNING | Drawing tools — drag/перенос/изменение углов (UX §4 «editing») — НЕ реализовано (требует hit-test на canvas). HIGH UX delta. → DEFERRED-S8 (`S7R-DRAWING-EDITING`). |
| WARNING | Drawing tools intraday TF (sequential mode) — координаты time→x могут «уезжать». MEDIUM. → DEFERRED-S8 (`S7R-DRAWING-INTRADAY-COORDS`). |
| INFO | gotcha-22 (Mantine Combobox.Target testid clone) — создан ARCH в 7.R (см. Раздел 12). |

**Статус раздела:** ✅ FIXED с замечаниями (3 WARNING → DEFERRED-S8, не блокеры).

---

## 6. Frontend Dashboard + Strategy + Wizard

### Объём ревью
- **7.1-fe** — VersionsHistoryDrawer.
- **7.2-fe** — GridSearchForm + GridSearchHeatmap.
- **7.7** — Dashboard widgets (Balance / Health / ActivePositions).
- **7.8-fe** — FirstRunWizard + Gate.

### Файлы проверены
- `src/components/strategy/VersionsHistoryDrawer.tsx`
- `src/components/backtest/{GridSearchForm,GridSearchModal,GridSearchHeatmap}.tsx`
- `src/components/dashboard/{Balance,Health,ActivePositions}Widget.tsx`
- `src/components/wizard/{FirstRunWizard,FirstRunWizardGate}.tsx`
- `src/App.tsx:22, 43` — Gate монтирован внутри `<ProtectedRoute>`.

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | `FirstRunWizardGate` смонтирован в `App.tsx:43` внутри `<ProtectedRoute>`. Читает `wizard_completed_at` из `/users/me`, монтирует модалку при null. |
| FIXED | `FirstRunWizard.tsx` — Mantine Stepper, шаг 2 — gate-checkbox (без галки disabled), шаг 5 — `POST /api/v1/users/me/wizard/complete` (C6 после fix-волны). Esc/click outside заблокированы. |
| FIXED | `VersionsHistoryDrawer` смонтирован в `StrategyEditPage.tsx:685`. Использует C4-endpoints 1:1 (DEV-4 W2 §5). Diff на фронте без новых зависимостей. Restore через `modals.openConfirmModal`. |
| FIXED | `GridSearchModal` смонтирован в `StrategyEditPage.tsx:695`. Динамический список 1–5 параметров, real-time `total = product(len(values))`, цветовой feedback ≤200/≤1000/>1000. |
| FIXED | `BalanceWidget` использует C9 endpoint `/account/balance/history?days=30`, MiniSparkline 240×56 от FRONT1 без дублирования. |
| FIXED | `HealthWidget` — graceful degrade на yellow «нет данных» при отсутствии расширенных полей (backend возвращает только status/version/database). |
| WARNING | `GridSearchHeatmap` — компонент готов, unit-тестирован, НО НЕ имеет точки вызова в production-коде (`grep "GridSearchHeatmap" src/` показывает только определение). PARTIALLY CONNECTED. → DEFERRED-S8 (`S7R-GRID-HEATMAP-ENTRYPOINT`). |
| WARNING | `HealthWidget`, `ActivePositionsWidget` — без unit-тестов (только E2E через `s7-front2.spec.ts` smoke). → DEFERRED-S8 (`S7R-WIDGETS-UNIT-COVERAGE`). |
| INFO | `BalanceWidget.tsx:13-14` — комментарий «MiniSparkline без LWC cleanup, чистый SVG» — координация с FRONT1 успешна. |

**Статус раздела:** ✅ FIXED с замечаниями (2 WARNING → DEFERRED-S8). Phase 1 функционал полностью работает.

---

## 7. OPS

### Объём ревью
- **7.9** — Backup/restore (CLI + APScheduler + WAL-aware SQLite).

### Файлы проверены
- `app/backup/service.py` — `BackupService` (snapshot/rotate/restore).
- `app/cli/backup.py` — argparse CLI (4 подкоманды).
- `app/scheduler/service.py:49, 362` — singleton + `backup_db_daily` job.
- `tests/test_backup/` — 27 тестов.

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | WAL-aware SQLite copy: `BEGIN IMMEDIATE` → `PRAGMA wal_checkpoint(FULL)` → `copy2` + копирование `*.db-wal`/`*.db-shm`. Закрывает gotcha-19. |
| FIXED | Postgres-ветка готова (`pg_dump --no-owner --format=custom` + `pg_restore --single-transaction`) — активируется по схеме URL. |
| FIXED | APScheduler-job `backup_db_daily` зарегистрирован в `SchedulerService` через паттерн `add_job(replace_existing=True)` ДО `_scheduler.start()`. Cron из `settings.BACKUP_CRON` (default 03:00 UTC). |
| FIXED | CLI на argparse (без typer — без новой зависимости): `python -m app.cli.backup {create,list,restore,rotate}` с `--help`. |
| FIXED | `restore` опционально запускает `alembic upgrade head` (схема в backup может быть старее). |
| FIXED | `BackupService(...)` — production calls в `scheduler/service.py:49` и `cli/backup.py:156`, не только в тестах. |
| FIXED | `.gitignore` обновлён (`backups/`, `*.sqlite`, `*.dump`). |
| INFO | После OPS fix-волны 2026-04-26 — WeasyPrint 68.1 установлен в `.venv`, зафиксирован в `pyproject.toml`. PDF endpoint протестирован (54685 байт, %PDF-1.7). `INSTALL.md` создан. |

**Статус раздела:** ✅ FIXED. Backup, ротация, restore, CLI — production-ready.

---

## 8. E2E + UX

### Объём ревью
- **7.10** — UX финальная полировка (UX W3, аудит 6 макетов vs реализация).
- **7.11** — Финальный E2E регресс (QA W3).

### Файлы проверены
- `Спринты/Sprint_7/reports/UX_W3_polish.md` — 11 deltas (6 medium / 5 low).
- `Спринты/Sprint_7/reports/QA_W3_final.md` — 136/0/3.
- `Спринты/ui_checklist_s7.md` — 9 секций + общие проверки.
- `Develop/frontend/e2e/s7-{drawing-tools,ai-commands,front2}.spec.ts` — 3 новых spec'а.

### Найдено

| Тип | Описание |
|-----|----------|
| FIXED | UX-аудит соответствие макетам W0: 7.7 — 95%, 7.8 — 95%, 7.6 — 80%, 7.16 — 90%, 7.17 — 95%, 7.19 — 100%. Ни одного блокера. |
| FIXED | `ui_checklist_s7.md` создан UX W3 (193 строки), 9 секций по задачам S7 + общие проверки. Все ⚠️ deltas задокументированы прямо в чеклисте. |
| FIXED | E2E финальный регресс: 136 passed / 0 failed / 3 skipped (3 spec'а добавлены: drawing-tools 8 + ai-commands 5 + front2 4 = 17 новых; failing legacy `ai-chat.spec.ts:81` починен в pre-7.R fix-волне 2026-04-26). |
| FIXED | 3 skipped — все pre-existing baseline, карточки в `Sprint_8_Review/backlog.md` (`S6R-AICHAT-APPLY-MOCK`, `S5R-BLOCKLY-MODE-B-MODAL`, `S5R-BLOCKLY-MODE-B-CHECK`). |
| WARNING | 6 задач без E2E spec'ов (7.3 export, 7.9 backup, 7.13 events, 7.14 Telegram, 7.16 zones, 7.17 background). Backend-задачи покрыты pytest. → DEFERRED-S8 (карточки `S7R-E2E-7.{3,9,13,14,16,17}-MISSING` уже в backlog). |
| INFO | UX W3 deltas — 7.16 data-testid drift `backtest-pnl-histogram` vs `pnl-histogram` — закрыт ARCH в 7.R: UX-макет приведён к коду (см. Раздел 11 #10). |

**Статус раздела:** ✅ FIXED с замечаниями. UX-аудит и E2E регресс пройдены.

---

## 9. MR.5 — Обязательная проверка 5 event_type

> **Источник:** `Спринты/project_state.md:79-101`. Эта проверка — критерий приёмки 7.R.

### EVENT_MAP — все 5 типов

`grep` подтверждает в `app/notification/service.py:76-104`:

| EventBus key | event_type | Severity | Title-шаблон |
|--------------|-----------|----------|--------------|
| `trade.opened` | trade_opened | info | "Позиция открыта" |
| `order.partial_fill` | partial_fill | info | "Частичное исполнение" |
| `order.error` | order_error | warning | "Ошибка выставления ордера" |
| `connection.lost` | connection_lost | warning | "Соединение с T-Invest потеряно" |
| `connection.restored` | connection_restored | info | "Соединение с T-Invest восстановлено" |

### Production publish-сайты

`grep '"trade\.opened"\|"order\.partial_fill"\|"order\.error"\|"connection\.lost"\|"connection\.restored"' app/`:

| event_type | file:line | Контекст |
|------------|-----------|----------|
| `trade.opened` | `app/trading/engine.py:846` | paper-mode после instant fill (внутри `process_signal`) |
| `trade.opened` | `app/trading/engine.py:1201` | real-mode параллельно с `trade.filled` (внутри `on_order_filled`) |
| `order.partial_fill` | `app/trading/engine.py:1171` | `on_order_filled` если `filled_lots < volume_lots` |
| `order.error` | `app/trading/engine.py:885` | внутри helper `_publish_order_error` (вызовы из `process_signal:812` и потенциально `on_order_filled` rejected) |
| `connection.lost` | `app/broker/tinvest/multiplexer.py:244` | `_run_stream` при exception, под флагом `_connection_event_published` (анти-спам) |
| `connection.restored` | `app/broker/tinvest/multiplexer.py:221` | после первого успешного response, если ранее был disconnect |

### NotificationService подписан на каналы

`grep "subscribe" app/notification/service.py`:
- `trades:{session_id}` — для каждой активной сессии (`listen_session_events`).
- `broker:status` — глобальный listener (`listen_broker_status`, `service.py:372`).

`main.py:81` — `await notification_service.listen_broker_status()` подключён в lifespan; `main.py:168` — `stop_broker_listener` в reverse shutdown.

### Доставка

Механизм доставки (in-app + Telegram + Email) для всех 13 типов уведомлений работает — подтверждено `test_dispatch_all_events.py` (14 passed) ещё в S6.

### Вердикт MR.5: ✅ FIXED

Все 5 event_type подключены к runtime через `create_notification`. NotificationService подписан на нужные каналы. Lifecycle (start/stop) корректный. **Не блокер.**

---

## 10. Регрессия E2E

### Финальные цифры (зафиксировано оркестратором)

- **Backend pytest:** 885 passed / 0 failed (baseline midsprint 771 → +114 за W2).
- **Frontend vitest:** 394 passed / 0 failed (baseline 287 → +107 за W1+W2).
- **TypeScript:** `npx tsc --noEmit` → 0 errors.
- **Frontend Playwright (полный регресс):** 136 passed / 0 failed / 3 skipped.

### Diff vs baseline 119 (S6 Review)

| Метрика | S6 Review | S7 final | Δ |
|---------|----------:|---------:|--:|
| passed | 119 | 136 | **+17** |
| failed | 0 | 0 | 0 |
| skipped | 3 | 3 | 0 |
| total | 122 | 139 | +17 |

**Прирост +17:** 3 новых spec'а — `s7-drawing-tools.spec.ts` (8) + `s7-ai-commands.spec.ts` (5) + `s7-front2.spec.ts` (4) = 17.

**Failing legacy `ai-chat.spec.ts:81`** (gotcha-22) — починен оркестратором в pre-7.R fix-волне 2026-04-26 одной строкой селектора (production-код не тронут).

### Критерий приёмки

- ≥ 119 + ≥ 15 новых = ≥ 134 passed → **136 passed ✅**
- 0 failed → ✅
- 3 skipped (все pre-existing с карточками в backlog) → ✅

**Регрессия пройдена.**

---

## 11. 13 открытых вопросов — решения 7.R

| # | Вопрос | Решение | Обоснование |
|---|--------|---------|-------------|
| 1 | gotcha-22 (Mantine Combobox testid clone) | **FIXED-NOW** | Создан `gotcha-22-mantine-combobox-target-testid-clone.md` + строка в INDEX.md (v5). Production-код не трогаем — текущая реализация работает, тесты адаптированы, e2e-фикс одной строкой уже сделан. |
| 2 | GridSearchHeatmap entry point — PARTIALLY CONNECTED | **DEFERRED-S8** | Карточка `S7R-GRID-HEATMAP-ENTRYPOINT`. Не блокер: Grid Search backend полностью функционален, FRONT2 модалка запуска работает. ≤1 час работы для добавления страницы результата. |
| 3 | 6 pre-existing frontend lint errors | **DEFERRED-S8** | Карточка `S7R-FE-LINT-PRE-EXISTING-6`. Не вызваны кодом S7. `pnpm lint --fix` мини-волна на S8. |
| 4 | Health/ActivePositions widgets без unit-тестов | **DEFERRED-S8** | Карточка `S7R-WIDGETS-UNIT-COVERAGE`. Покрыты E2E через `s7-front2.spec.ts`. Не блокер. |
| 5 | Real-mode coverage `test_order_manager` | **DEFERRED-S8** | Карточка `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE`. Paper-mode достаточно для S7 feature-complete. |
| 6 | Drawing tools editing/drag (UX §4) | **DEFERRED-S8** | Карточка `S7R-DRAWING-EDITING`. Требует hit-test на canvas, выходит за scope feature-complete S7 (≥1 день работы). |
| 7 | Drawing tools sequential mode координаты | **DEFERRED-S8** | Карточка `S7R-DRAWING-INTRADAY-COORDS`. Кандидат на новый Stack Gotcha (`MSK_OFFSET_SEC + sequentialIndex`). |
| 8 | ActivePositionsWidget sparkline 24h `data: []` | **DEFERRED-S8** | Карточка `S7R-WIDGET-SPARKLINE-24H`. Требует новый endpoint `/market-data/sparkline?ticker=X&hours=24`. |
| 9 | Wizard Telegram test-кнопка | **DEFERRED-S8** | Карточка `S7R-WIZARD-TELEGRAM-TEST-BUTTON`. Требует backend endpoint + UI. |
| 10 | 7.16 data-testid drift `backtest-pnl-histogram` vs `pnl-histogram` | **FIXED-NOW** | Обновлён UX-макет `Sprint_7/ux/backtest_overview_analytics.md` §13 — код становится source of truth (`pnl-histogram`, `win-loss-donut`, `trade-detail-panel`). E2E уже использует код, переименование не требуется. |
| 11 | 6 NOT COVERED E2E (7.3, 7.9, 7.13, 7.14, 7.16, 7.17) | **DEFERRED-S8** | Карточки `S7R-E2E-7.{3,9,13,14,16,17}-MISSING` уже в backlog (UX W3 + QA W3). Backend-задачи (7.3, 7.9, 7.13, 7.14) покрыты pytest. Frontend (7.16, 7.17) — реализация работает, но E2E spec'ов нет. |
| 12 | MR.5 — 5 event_type | **✅ FIXED** | Подтверждено через grep + чтение кода (см. Раздел 9). Не DEFERRED, не ACCEPT — все 5 publish-сайтов в production. |
| 13 | Документация ФТ v2.4 / ТЗ v1.4 / development_plan | **FIXED-NOW** | Обновлено в 7.R (см. Раздел 13). |

**Итог:** 3 FIXED-NOW (вопросы 1, 10, 12 + 13), 10 DEFERRED-S8 (карточки в backlog).

---

## 12. Stack Gotchas финал

### Существующие Stack Gotchas, применённые в S7

| # | Gotcha | Где применили |
|---|--------|---------------|
| 4 | T-Invest streaming reconnect | 7.13 `multiplexer.py` — publish обёрнут в try/except, не ломает backoff |
| 8 | AsyncSession.get_bind в pytest | 7.17 `BacktestJobManager` тесты — отдельный engine + StaticPool |
| 11 | Alembic drift | 7.1 (strategy_versions), 7.8 (wizard_completed_at), 7.17 (backtest_jobs) — миграции содержат только намеренные изменения |
| 12 | SQLite batch_alter | 7.1 миграция через `naming_convention` для FK + явное `name=` |
| 16 | 401 race relogin | 7.15, 7.17 WS — auth первым сообщением, не в URL |
| 17 | Telegram bot frozen | 7.14 `test_telegram_callbacks.py` — stub-объекты для query, не `patch.object(bot)` |
| 18 (аналог) | CB-уведомления спам | 7.13 multiplexer — анти-спам флаг `_connection_event_published` |

### Новые Stack Gotchas, созданные в S7

| # | Gotcha | Когда создан |
|---|--------|--------------|
| 19 | SQLite WAL backup без checkpoint | OPS W2 (7.9), 2026-04-25 |
| 20 | FastAPI route ordering — статика после `/{int_param}` → 422 | BACK2 W2 (7.1), 2026-04-25 |
| 21 | Grid Search: `multiprocessing.Pool` (spawn-context) — финал | BACK1 W2 sub-wave 1 + fix-волна (UPDATE), 2026-04-25 → 2026-04-26 |
| **22** | **Mantine `<Combobox.Target>` через `cloneElement` переписывает `data-testid` дочернего input/textarea** | **ARCH 7.R, 2026-04-26** ⬅ финал |

`INDEX.md` обновлён до v5 (last_updated 2026-04-26).

### Решение по gotcha-22

Создан `Develop/stack_gotchas/gotcha-22-mantine-combobox-target-testid-clone.md` (157 строк), строка добавлена в `INDEX.md`. Production-код не трогаем — текущая реализация ChatInput с Combobox работает, тесты адаптированы (DEV-3 PHASE2), e2e legacy spec уже починен в pre-7.R fix-волне.

---

## 13. Документация

### ФТ v2.4 (`Документация по проекту/functional_requirements.md`)

- Версия: 2.3 → **2.4** (2026-04-26).
- Добавлен **раздел §19 «Sprint 7 — Should-фичи и завершение Phase 1»** с 13 подсекциями (19.1–19.13):
  - Версионирование стратегий (история, snapshots, history-preserving откат)
  - Grid Search оптимизация
  - Экспорт CSV/PDF
  - Drawing tools (5 типов + hotkeys)
  - Дашборд-виджеты
  - First-run wizard (5 шагов)
  - Backup/restore
  - AI слэш-команды
  - Аналитика бэктеста (гистограмма + donut + интерактивные зоны)
  - Фоновые бэктесты
  - WS обновление карточек сессий
  - 5 новых event_type (MR.5)
  - Telegram inline-кнопки
- Запись в «Истории изменений».

### ТЗ v1.4 (`Документация по проекту/technical_specification.md`)

- Версия: 1.2 → **1.4** (2026-04-26, перешагнули v1.3 которой не было — добавлены оба).
- Добавлен **раздел §11 «Sprint 7 — реализация Should-фич»** с 16 подразделами:
  - 11.1 Модель `strategy_versions` — DDL расширения
  - 11.2 Endpoints версионирования (контракт C4)
  - 11.3 Модель `backtest_jobs` (DDL)
  - 11.4 BacktestJobManager singleton
  - 11.5 GridSearchEngine multiprocessing.Pool
  - 11.6 WS endpoints `/ws/trading-sessions/{user_id}` + `/ws/backtest/{job_id}`
  - 11.7 BackupService архитектура (WAL-aware + Postgres)
  - 11.8 ChatRequest.context_items (контракт C3)
  - 11.9 slash_context резолверы (sanitization + ownership)
  - 11.10 Модель `chart_drawings` mini-CRUD
  - 11.11 users.wizard_completed_at + endpoint (C6)
  - 11.12 Account balance/history (C9)
  - 11.13 NotificationService DI singleton (C7)
  - 11.14 EVENT_MAP — 5 новых записей (MR.5)
  - 11.15 Telegram CallbackQueryHandler (C8)
  - 11.16 Cross-DEV контракты Sprint 7 (C1–C9 формализованы)
- Запись в «Истории изменений».

### development_plan.md

- Спринт 7 → **✅ ЗАВЕРШЁН (2026-04-26)**.
- Добавлены задачи **7.18 / 7.19** (AI слэш-команды) — отсутствовали в v2.
- Все задачи 7.1–7.19 + 7.R → ✅.
- RACI-корректировка: 7.1 / 7.12 → BACK2 (фактически).
- Указаны финальные тесты: backend 885/0, frontend 394/0, Playwright 136/0/3.
- Указаны Stack Gotchas созданные в S7 (#19, #20, #21, #22).

---

## 14. Перенос задач (DEFERRED-S8)

В `Спринты/Sprint_8_Review/backlog.md` ARCH 7.R добавил 11 карточек:

| ID | Приоритет | Описание |
|----|-----------|----------|
| `S7R-GRID-HEATMAP-ENTRYPOINT` | medium | GridSearchHeatmap PARTIALLY CONNECTED, ≤1 час |
| `S7R-FE-LINT-PRE-EXISTING-6` | low | 6 lint errors в legacy-файлах |
| `S7R-WIDGETS-UNIT-COVERAGE` | low | Health / ActivePositions widgets unit-тесты |
| `S7R-ORDER-MANAGER-REAL-MODE-COVERAGE` | medium | parametrize paper/real в `test_order_manager` |
| `S7R-DRAWING-EDITING` | medium-high | drag/перенос/изменение углов фигуры (UX §4) |
| `S7R-DRAWING-INTRADAY-COORDS` | medium | sequential mode координаты (gotcha-кандидат) |
| `S7R-WIDGET-SPARKLINE-24H` | medium | новый endpoint OHLCV для sparkline |
| `S7R-WIZARD-TELEGRAM-TEST-BUTTON` | medium | smoke-тест Telegram + кнопка в wizard'е |
| `S7R-HEALTH-WS-MIGRATION` | low | HealthWidget polling 30s → WS |
| `S7R-MULTICURRENCY-TOGGLE` | low | переключатель валют RUB/USD/EUR |
| `S7R-BG-BACKTEST-AUTOCOLLAPSE` | low | auto-collapse done через 10s |
| `S7R-HISTOGRAM-MANTINE-TOOLTIP` | low | Mantine `<Tooltip>` вместо нативного `title` |

Карточки QA W3 (6 NOT COVERED E2E) уже были добавлены ранее (`S7R-E2E-7.{3,9,13,14,16,17}-MISSING`), pre-existing skip-карточки (`S6R-AICHAT-APPLY-MOCK`, `S5R-BLOCKLY-MODE-B-*`) тоже на месте.

Скрытых блокеров **не найдено**.

---

## 15. Чеклист сдачи

- [x] Code review всех 8 разделов проведён
- [x] Integration verification для каждой новой сущности подтверждён (grep'ы пройдены)
- [x] MR.5 проверка пройдена (5 event_type подключены через `create_notification`)
- [x] 13 открытых вопросов разрешены (3 FIXED-NOW + 10 DEFERRED-S8)
- [x] Stack Gotchas финал: gotcha-22 создан + INDEX.md обновлён до v5
- [x] Регрессия E2E ≥ 134 passed (фактически 136 / 0 / 3) — соответствует
- [x] ФТ v2.4 обновлены за S7 (раздел §19)
- [x] ТЗ v1.4 обновлено за S7 (раздел §11)
- [x] development_plan.md обновлён (S7 ✅, 7.18/7.19 добавлены)
- [x] `ui_checklist_s7.md` верифицирован (создан UX W3, 9 секций + общие, 193 строки)
- [x] Перенос задач (11 новых DEFERRED-S8) в `Sprint_8_Review/backlog.md`
- [x] Финальный вердикт зафиксирован: **PASS WITH NOTES**
- [x] `Спринты/project_state.md` обновлён (см. отдельную правку)
- [x] `Sprint_7/changelog.md` обновлён последней записью «7.R PASS WITH NOTES»
- [x] `Sprint_7/sprint_state.md` отражает «✅ завершён»
- [x] `arch_review_s7.md` сохранён (этот файл)
- [x] `reports/ARCH_S7_review.md` сохранён (8-секционная сводка)
- [x] Git: НЕ коммитил, НЕ пушил (правило `feedback_two_repos.md`)

---

**Конец финального ревью Sprint 7. Вердикт PASS WITH NOTES — ARCH (2026-04-26).**
