---
sprint: 7
agent: ARCH
wave: 0 (pre-sprint design)
depends_on: [Sprint_7/sprint_design.md, project_state.md, technical_specification.md, functional_requirements.md, Develop/stack_gotchas/INDEX.md]
created: 2026-04-25
---

# Sprint 7 — ARCH Design Document

> Документ создан на этапе W0 ДО запуска DEV-агентов. Цель — закрыть архитектурные неопределённости по 6 крупным/межмодульным задачам, чтобы DEV-агенты в W1/W2 шли по готовым решениям.
>
> **Метод:** для каждой подзадачи — короткий внутренний brainstorm (вопросы → варианты → решение → обоснование), затем финальная схема.
>
> **Skill:** работа выполнена в духе `superpowers:brainstorming` — открытые вопросы зафиксированы и закрыты до перехода к DEV.

---

## 0. Обязательные предусловия

- `Спринты/Sprint_7/sprint_design.md` (особенно §2, §3.1.2, Приложения C, D) — прочитан.
- `Спринты/project_state.md:79–101` (MR.5: 5 event_type → runtime) — прочитан и процитирован в §3 ниже дословно.
- `Develop/CLAUDE.md` (правила плагинов, конвенции, gotchas-redirect) — прочитан.
- `Develop/stack_gotchas/INDEX.md` (18 ловушек) — прочитан целиком; релевантные S7 ловушки выписаны в §7.
- `Sprint_6/changelog.md:623–664` (фикс EVENT_MAP шаблонов) — изучен; §3 опирается на этот же контракт «полный data-dict в publish».
- `Sprint_6_Review/code_review.md` — формат повторяется в 7.R.
- UX-макеты `Sprint_7/ux/*.md` (6 файлов) — присутствуют; §8 проверяет архитектурные стыки.

---

## 1. Версионирование стратегий (Задача 7.1)

### 1.1 Цитаты ТЗ/ФТ

**ТЗ §3.4 — `strategy_versions` (существует):**
> ```
> strategy_versions
> ├── id: Integer, PK, autoincrement
> ├── strategy_id: Integer, FK(strategies.id), NOT NULL
> ├── version_number: Integer, NOT NULL
> ├── text_description: Text, NULLABLE
> ├── blocks_json: Text, NOT NULL                   -- JSON блочной схемы (Blockly XML/JSON)
> ├── generated_code: Text, NOT NULL                -- Python-код для Backtrader
> ├── parameters_json: Text, NULLABLE
> ├── ai_chat_history: Text, NULLABLE
> ├── created_at: DateTime, NOT NULL
> ├── UNIQUE: uq_strategy_version (strategy_id, version_number)
> └── INDEX: idx_sv_strategy (strategy_id)
> ```

**ТЗ §1300:**
> «Версионирование формата: JSON блочной схемы содержит корневое поле `"schema_version": 1`. При изменении формата блоков в будущих версиях приложения — добавляется миграция в Alembic, которая обновляет `blocks_json` всех записей `strategy_versions` до нового формата.»

**ФТ §17 (Should-фичи):** «Версионирование стратегий, оптимизация параметров...»

**ER ТЗ §3.23:**
> `strategies 1──* strategy_versions`
> `strategies *──1 strategy_versions (current_version_id)`
> `strategy_versions 1──* backtests`
> `strategy_versions 1──* trading_sessions`

### 1.2 Brainstorm — вопросы и решения

**Q1. Таблица уже есть (см. `Develop/backend/app/strategy/models.py:50`). Создавать новую или расширить?**
→ Расширяем существующую: добавляем колонки `created_by` (FK users), `comment` (Text). Это не ломает обратную совместимость (NULLABLE).

**Q2. Хранить полный snapshot или diff?**
→ **Полный snapshot.** Стратегии — небольшие (Blockly JSON редко > 50 КБ, generated_code < 30 КБ). Diff усложняет восстановление и подвержен порче. SQLite WAL отлично жмёт текст. Историй обычно < 50 на стратегию → итог < 5 МБ на самую активную стратегию.

**Q3. Политика создания версий — на каждый Save? явный «Сохранить версию»? авто каждые N минут?**
→ **Гибрид:**
- Авто-снимок при каждом Save через `POST /api/v1/strategies/{id}` (текущее поведение): создаётся новый `strategy_versions` row, `current_version_id` обновляется.
- Защита от спама: если последняя версия моложе **5 минут** И `blocks_json + generated_code` идентичны последней — не создавать новую, просто обновить `updated_at` стратегии (idempotency).
- Явная кнопка «Сохранить как именованную версию» в UI: добавляет `comment` к версии (заполняется пользователем).
→ Никакого авто-каждые-N-минут (это спам).

**Q4. Откат — перезаписать текущую или создать новую?**
→ **Создать новую.** History-preserving: `POST /strategies/{id}/versions/{ver_id}/restore` копирует выбранную версию как новую с `comment="Откат к v{N}"`, `current_version_id` указывает на неё. Старая версия остаётся в истории. Это безопаснее (нельзя случайно потерять текущую) и проще для аудита.

**Q5. Совместимость с redis-кэшем стратегий.**
→ **Не применимо.** В `Develop/backend/app/strategy/` нет redis-кэша — стратегии читаются напрямую из БД через SQLAlchemy `selectin`. Bypass-инвалидация не нужна.

**Q6. Индексация — что добавить?**
→ Существующий `idx_version_strategy(strategy_id)` достаточен для list-запроса. Добавляем композитный `idx_sv_history(strategy_id, version_number DESC)` для быстрой пагинации истории. (UNIQUE `uq_strategy_version(strategy_id, version_number)` уже есть.)

**Q7. FK на trading_sessions/backtests при удалении версии — что с ними?**
→ Удаление версий запрещено (нет endpoint DELETE). Это упрощает FK: `RESTRICT/NO ACTION` остаётся; история неизменяема.

### 1.3 Финальный DDL миграции (для DEV-2 в W2)

```sql
-- Alembic op.batch_alter_table (gotcha-12: SQLite требует batch_alter_table для server_default'ов)
ALTER TABLE strategy_versions ADD COLUMN created_by INTEGER NULL REFERENCES users(id);
ALTER TABLE strategy_versions ADD COLUMN comment TEXT NULL;
CREATE INDEX idx_sv_history ON strategy_versions (strategy_id, version_number DESC);
```

Backfill: для существующих row'ов `created_by = strategies.user_id` (через subquery в данных-миграции). `comment` остаётся NULL.

### 1.4 Endpoints (контракт C4)

| Метод | URL | Body | Response |
|-------|-----|------|----------|
| GET | `/api/v1/strategies/{id}/versions` | — | `{items: [{id, version_number, comment, created_by, created_at, is_current}]}` |
| GET | `/api/v1/strategies/{id}/versions/{ver_id}` | — | `{id, version_number, blocks_json, generated_code, parameters_json, comment, ...}` |
| POST | `/api/v1/strategies/{id}/versions` | `{comment?: str}` | `{id, version_number, ...}` (создание именованной версии вручную) |
| POST | `/api/v1/strategies/{id}/versions/{ver_id}/restore` | — | `{new_version: {...}, current_version_id}` |
| GET | `/api/v1/strategies/{id}/versions/diff?from={a}&to={b}` | — | `{blocks_diff: str, code_diff: str}` (unified diff) |

**Авторизация:** все endpoints требуют JWT + проверку `strategies.user_id == current_user.id`.

### 1.5 Политика версии «is_current»

Поле `strategies.current_version_id` (уже есть). Любой endpoint, который читает «текущую» — JOIN'ит на `current_version_id`. List-страница `versions` возвращает каждой записи флаг `is_current = (id == strategies.current_version_id)`.

---

## 2. Grid Search оптимизация (Задача 7.2)

### 2.1 Цитаты ТЗ/ФТ

**ТЗ §5.3.4 (дословно):**
> «Для каждой комбинации параметров — отдельный запуск `cerebro.run()`. Используется `multiprocessing.Pool` для параллелизации. Максимум workers = `os.cpu_count() - 1`. Результаты агрегируются в таблицу. Overfitting-предупреждение: если топ-5 результатов имеют разброс метрик > 50% от лучшего.»

**ФТ §17 (Should):** «оптимизация параметров (grid search)».

### 2.2 Brainstorm

**Q1. multiprocessing.Pool vs ProcessPoolExecutor vs asyncio+Semaphore vs Celery.**
→ **`multiprocessing.Pool`** — соответствует ТЗ §5.3.4 дословно. Backtrader cerebro — CPU-bound, Pool оптимален. asyncio не подходит (CPU). Celery — over-engineering для in-process монолита (не подключён). ProcessPoolExecutor — альтернатива, но в ТЗ конкретно `Pool`.
→ **Решение:** `multiprocessing.Pool` с `processes=max(1, os.cpu_count()-1)`. Worker запускает уже изолированную функцию (никаких глобальных stateful AsyncSession; каждая worker создаёт свою sync sqlite-сессию для чтения OHLCV-кэша).

**Q2. Лимит N комбинаций — hard cap.**
→ **Hard cap 1000** комбинаций на один Grid job. UI показывает `count = product(len(values_per_param))` ДО отправки + warning при > 200, blocking error при > 1000. Защита от 10⁶.

**Q3. Shape матрицы результата.**
→ Список объектов:
```json
[
  {"params": {"sma_fast": 10, "sma_slow": 30}, "sharpe": 1.32, "pnl": 1854.2, "pnl_pct": 18.5, "win_rate": 0.62, "max_drawdown_pct": 8.4, "trades_count": 42},
  ...
]
```
Сортировка по убыванию `sharpe` по умолчанию; сортировка переключается клиентом.

**Q4. Heatmap-визуализация (UI).**
→ Поддерживается до 2D (2 параметра). Если параметров 3+ — показываем top-N таблицу + heatmap по 2 первым (третий фиксируется в фильтре). Это решение для FRONT2.

**Q5. WS-канал.**
→ **Переиспользуем `/ws/backtest/{job_id}`** (контракт C2). Поле `result.matrix` добавляется при `status='done'` для grid-job'а. Поле `progress` агрегатное по всем комбинациям: `progress = completed/total*100`.

**Q6. Где размещать grid-engine.**
→ Новый модуль `app/backtest/grid.py`: `GridSearchEngine.run(strategy_id, ranges, user_id) -> job_id`. Использует существующий `BacktestEngine` per-комбинация. Запуск Pool в `loop.run_in_executor(None, partial(_pool.map, ...))` (asyncio-friendly wrap).

**Q7. Overfitting-предупреждение.**
→ Реализуем по ТЗ: если `(sharpe[0] - sharpe[4]) / sharpe[0] > 0.5` → флаг `overfitting_warning: true` в final payload.

**Q8. Cancel job.**
→ `POST /api/v1/backtest/grid/{job_id}/cancel` → закрывает Pool через `pool.terminate()` + помечает job как `cancelled`. Для процессов это работает с asyncio через wrap.

### 2.3 Endpoints (контракт C5)

```
POST /api/v1/backtest/grid
  Body: {
    strategy_id: int,
    strategy_version_id: int,
    ticker: str,
    timeframe: str,
    date_from: date,
    date_to: date,
    ranges: { "sma_fast": [5, 10, 15], "sma_slow": [20, 30, 50] },
    initial_capital: Decimal
  }
  Response 202: { job_id: str }      # uuid hex

GET  /api/v1/backtest/grid/{job_id}            # снапшот статуса (alt to WS)
POST /api/v1/backtest/grid/{job_id}/cancel
WS   /ws/backtest/{job_id}                     # see C2
```

### 2.4 Лимиты безопасности

- `len(ranges) ≤ 5` параметров.
- `product(len(values)) ≤ 1000` комбинаций.
- Per-user конкурентный лимит: 2 grid-job одновременно (см. §5 ниже — общий лимит фоновых).

---

## 3. 5 event_type → runtime (Задача 7.13, MR.5)

### 3.1 Цитата project_state.md (дословно, MR.5)

> ### S7 — ARCH-задача: подключение оставшихся event_type к runtime
>
> После завершения всех DEV-задач S7 архитектор **обязан** проверить, что следующие 5 типов уведомлений подключены к реальным runtime-событиям через `create_notification`:
>
> | event_type | Что нужно | Источник события |
> |------------|-----------|-----------------|
> | `trade_opened` | EVENT_MAP: маппинг на открытие позиции | `trading/runtime.py` или `engine.py` |
> | `partial_fill` | Частичное исполнение ордера | `trading/engine.py` → OrderManager |
> | `order_error` | Ошибка выставления ордера | `trading/engine.py` → OrderManager |
> | `all_positions_closed` | Все позиции закрыты | `trading/engine.py:681` (event уже есть, нет `create_notification`) |
> | `connection_lost` / `connection_restored` | Потеря/восстановление gRPC-соединения | `broker/tinvest/multiplexer.py` (reconnect loop) |
>
> Механизм доставки (in-app + Telegram + Email) работает для всех 13 типов — подтверждено тестом `test_dispatch_all_events.py` (14 passed). Нужно только подключить источники.

### 3.2 Текущее состояние EVENT_MAP

`Develop/backend/app/notification/service.py:31–74` — содержит 7 маппингов: `session.started`, `session.stopped`, `order.placed`, `trade.filled`, `trade.closed`, `cb.triggered`, `positions.closed_all`. **Нужно добавить 5 новых маппингов** (см. §3.4) + 5 publish-сайтов (см. §3.5).

### 3.3 Brainstorm

**Q1. `trade_opened` — это новое событие или alias к существующему `order.placed`/`trade.filled`?**
→ **Новое event_type.** Семантика: позиция реально открылась (paper: после `order.placed` мгновенно; real: после `trade.filled`). Различие с `trade.filled` — `trade_opened` срабатывает только когда ранее открытых позиций по ticker не было (это «новая позиция», а не «ещё одна сделка»). Для простоты S7 — пускаем на каждом успешном open (после filled), без дедупликации; в S8 уточним если нужно.

**Q2. Где публиковать `trade_opened`?**
→ В `engine.py:on_order_filled()` после успешного fill — публикуется параллельно с `trade.filled`. Это паттерн «cловный» уведомлений: `trade.filled` — event для UI, `trade_opened` — event для notification только.

**Q3. `partial_fill` — нужна ли отдельная схема?**
→ Да. В paper это не актуально (мгновенный fill всего объёма). В real — `on_order_filled(filled_lots < volume_lots)`. Условие: `filled_lots < trade.volume_lots`.

**Q4. `order_error` — где ловить?**
→ В `OrderManager.process_signal()` — единая точка вызова broker. Try/except вокруг создания LiveTrade и paper-fill. Также в `on_order_filled` если broker возвращает rejected. **Решение:** один общий хелпер `_publish_order_error(session, signal, error)` — вызывается из catch'ей.

**Q5. `all_positions_closed` — событие уже публикуется (`engine.py:908`), но нет EVENT_MAP-маппинга для notification?**
→ В EVENT_MAP **есть** маппинг `positions.closed_all → all_positions_closed` (`service.py:68`). MR.5 указывает «event уже есть, нет create_notification» — это недоразумение в `project_state.md`. Реальная проверка: `notification_service` должен подписаться на канал `trades:{session_id}` и видеть `positions.closed_all`. Сейчас — подписан только в `engine.py:close_all_positions()`. **Действие:** проверить, что NotificationService listener-loop ловит этот канал. Если нет (а он не подписывается на каждую сессию automaticly) — добавить subscribe в `start_session` через NotificationService (см. 7.12 + связка). Дополнительно: убедиться, что dispatcher для всех 13 типов реально доставляет (`test_dispatch_all_events.py` это покрывает).

**Q6. `connection_lost / connection_restored` — где ловить?**
→ `multiplexer.py:_run_stream()`:
- **`connection_restored`:** после первого успешного `response` (line 207, где `_reconnect_delay = _INITIAL_RECONNECT_DELAY`). Условие: ранее `self._connected == False` и теперь стало `True`. Публикуется один раз.
- **`connection_lost`:** в `except Exception` (line 213-218), уже есть `self._connected = False`. Публикуется один раз при первом disconnect (не на каждой попытке reconnect — иначе спам).

**Q7. Анти-спам connection_lost.**
→ Флаг `_connection_event_published` в multiplexer: True после publish lost; сбрасывается в False при успешном connect. Это аналогично gotcha-18 (CB-уведомления спамили на каждой свече).

### 3.4 EVENT_MAP — новые записи (для DEV-1 W1)

```python
# app/notification/service.py — append to EVENT_MAP
"trade.opened": (
    "trade_opened",
    "info",
    "Позиция открыта",
    "{strategy_name}: {ticker} {direction} {volume} лот(ов) по {price} ₽",
),
"order.partial_fill": (
    "partial_fill",
    "info",
    "Частичное исполнение",
    "{ticker}: {direction} {filled_lots}/{total_lots} лот(ов) по {avg_price} ₽",
),
"order.error": (
    "order_error",
    "warning",
    "Ошибка выставления ордера",
    "{ticker}: {direction} — {reason}",
),
"connection.lost": (
    "connection_lost",
    "warning",
    "Соединение с T-Invest потеряно",
    "{broker_name}: {reason}",
),
"connection.restored": (
    "connection_restored",
    "info",
    "Соединение с T-Invest восстановлено",
    "{broker_name}",
),
```

> **Комментарий:** существующая запись `positions.closed_all → all_positions_closed` остаётся как есть. Поле `count` уже передаётся в payload (engine.py:913). Дополнительно: при подсчёте total_pnl (если потребуется в шаблоне) — это отдельная задача по обогащению payload.

### 3.5 Publish-сайты (file:line, для DEV-1 W1)

| event_type | Файл | Точка | Контекст для payload |
|------------|------|-------|----------------------|
| `trade.opened` | `app/trading/engine.py` | в `on_order_filled()` после `await self.db.commit()` (~line 1102) — параллельно с `trade.filled` publish | `strategy_name` (через JOIN strategies), `ticker` (session.ticker), `direction`, `volume` (filled_lots), `price` (fill_price str) |
| `order.partial_fill` | `app/trading/engine.py` | в `on_order_filled()` если `filled_lots < trade.volume_lots` — публикуется ВМЕСТО `trade.filled` (terminal=False) | `ticker`, `direction`, `filled_lots`, `total_lots` (volume_lots), `avg_price` |
| `order.error` | `app/trading/engine.py` | новый хелпер `_publish_order_error()` вызывается из 2 мест: `OrderManager.process_signal()` (try/except вокруг `db.commit()` + paper fill, ~line 800–820) и `on_order_filled()` если broker вернул rejected | `ticker`, `direction`, `reason` (str(exc)), `error_code` (если есть) |
| `connection.lost` | `app/broker/tinvest/multiplexer.py` | в `except Exception` (~line 213–218) при переходе `_connected=True→False`. Под флагом `_connection_event_published` (анти-спам). | `broker_name="T-Invest"`, `reason=str(e)` |
| `connection.restored` | `app/broker/tinvest/multiplexer.py` | в `_run_stream` после первого успешного `response` (~line 207), если предыдущее состояние было `disconnected`. | `broker_name="T-Invest"` |
| `positions.closed_all` (already wired) | `app/trading/engine.py:908` | существующее событие. Проверить в midsprint: NotificationService подписан на `trades:{session_id}` и реально создаёт notification. | `session_id`, `count`, опционально `total_pnl` (нужно SELECT SUM(pnl)) |

### 3.6 Контракт publish ↔ EVENT_MAP

После Sprint_6_Review (см. changelog 2026-04-24:623) **обязательно** передавать ВСЕ поля плейсхолдеров в payload. DEV-1 пишет unit-тест: для каждого event_type сравнить `set(format_keys(template))` ⊆ `set(payload.keys())`. Это блок-тест на регрессию gotcha-19 (см. §7).

### 3.7 Verification (для midsprint и 7.R)

```bash
# 1. Каждый из 5 новых event_type имеет publish и EVENT_MAP-маппинг:
grep -rn "trade\.opened\|order\.partial_fill\|order\.error\|connection\.lost\|connection\.restored" \
  Develop/backend/app/trading/ Develop/backend/app/broker/

# 2. EVENT_MAP содержит все 12 ключей (7 старых + 5 новых):
grep -A1 "EVENT_MAP" Develop/backend/app/notification/service.py | head -50

# 3. NotificationService подписан на все нужные каналы:
grep -n "event_bus.subscribe" Develop/backend/app/notification/service.py
```

---

## 4. WS канал торговых сессий (Задача 7.15)

### 4.1 Цитаты ТЗ

**ТЗ §2.3 (каналы):**
> «Канал `trades:{session_id}` — сделки стратегии»

**ТЗ §4.12 (WebSocket Protocol):**
> «Авторизация: после установки соединения клиент отправляет первое сообщение `{"action": "auth", "token": "<jwt_token>"}`. Сервер верифицирует токен. До авторизации любые subscribe-запросы отклоняются. Это предотвращает утечку JWT через URL (серверные логи, history).»

### 4.2 Brainstorm

**Q1. Авторизация — JWT в query string vs первое сообщение vs cookie?**
→ ТЗ §4.12 уже зафиксировал паттерн «первое сообщение `{action: 'auth', token: ...}`» для существующего endpoint `/api/v1/ws`. Для нового endpoint `/ws/trading-sessions/{user_id}` следуем тому же паттерну (consistency + не утекаем JWT в URL/логи). Альтернатива (cookie) сложнее с CORS и не нужна.
→ **Решение:** `/ws/trading-sessions/{user_id}` — первая команда от клиента `{action: 'auth', token: '<jwt>'}`. Backend проверяет: `decoded.user_id == path user_id`. Несовпадение → close 4401 (custom code).

**Q2. Содержание — snapshot vs delta-events?**
→ **Гибрид:**
- Сразу после auth_ok backend шлёт `{event: 'snapshot', sessions: [{session_id, status, pnl, positions_count, last_trade, ...}]}` — состояние всех активных сессий пользователя.
- Далее delta-events через подписку на `trades:{session_id}` для каждой активной сессии:
  - `position_update` — изменение количества позиций (открыта/закрыта).
  - `trade_filled` — сделка исполнена.
  - `pnl_update` — обновление P&L (по факту price tick / закрытию позиции).
  - `session_state` — статус (active/paused/stopped).

**Q3. Reconnect.**
→ Frontend использует `reconnecting-websocket` (заявлен в ТЗ §1.93). При reconnect — повторно auth + ждём snapshot. Backend при close-соединения отписывается от `trades:{session_id}` каналов автоматически (cleanup в WS-handler через `try/finally`).

**Q4. Подписка на новые сессии (запущенные после WS-открытия).**
→ Backend WS-handler также подписан на `system:{user_id}` (новый канал) — туда `runtime.start()` публикует `session.added(session_id)`. Получив, handler динамически подписывается на новый `trades:{session_id}`.

**Q5. Удаление polling 10s.**
→ В одном PR: добавляется WS-клиент во frontend (TradingPage / SessionList) + удаляется `setInterval(fetchSessions, 10000)`. **Условие**: фоллбек на REST-запрос остаётся для первого load до auth_ok (избежать пустого экрана при ws-init).

**Q6. Мёртвые соединения.**
→ Сервер шлёт ping каждые 20 сек (FastAPI WebSocket: `await websocket.send_text('{"type":"ping"}')` или nativeой ping frame через uvicorn `ws_ping_interval=20`). Клиент отвечает `{"type":"pong"}`. Если 2 ping подряд без pong — closе 4408 (timeout).

### 4.3 Endpoint (контракт C1)

```
WS /ws/trading-sessions/{user_id}
   Step 1 (client → server): {"action":"auth","token":"<jwt>"}
   Step 2 (server → client): {"type":"auth_ok"} | close(4401)
   Step 3 (server → client): {"event":"snapshot","sessions":[{session_id, ticker, status, pnl, positions, last_trade_at, mode}, ...]}
   Step N (server → client, deltas):
     {"event":"position_update", "session_id":42, "payload":{...}}
     {"event":"trade_filled",    "session_id":42, "payload":{trade_id, price, ...}}
     {"event":"pnl_update",      "session_id":42, "payload":{realized, unrealized}}
     {"event":"session_state",   "session_id":42, "payload":{status:"paused"}}
```

### 4.4 Backend handler (схема)

```python
# app/trading/ws_router.py (новый файл)
@router.websocket("/ws/trading-sessions/{user_id}")
async def trading_sessions_ws(websocket: WebSocket, user_id: int):
    await websocket.accept()
    # 1. JWT auth (custom close codes 4401/4403)
    auth_msg = await websocket.receive_json()
    user = decode_and_check(auth_msg["token"], user_id)
    if not user: await websocket.close(4401); return
    await websocket.send_json({"type":"auth_ok"})

    # 2. Snapshot
    sessions = await load_active_sessions(user_id)
    await websocket.send_json({"event":"snapshot","sessions":[serialize(s) for s in sessions]})

    # 3. Subscribe per-session
    subs = []
    try:
        for s in sessions:
            sub_id, queue = event_bus.subscribe(f"trades:{s.id}")
            subs.append((s.id, sub_id, queue))
        # дополнительно subscribe на system:{user_id} для новых сессий
        sys_sub_id, sys_queue = event_bus.subscribe(f"system:{user_id}")
        # main loop: select из всех очередей через asyncio.wait + ping/pong
        ...
    finally:
        for _, sub_id, _ in subs: event_bus.unsubscribe(...)
        event_bus.unsubscribe(f"system:{user_id}", sys_sub_id)
```

---

## 5. Фоновый бэктест и очередь (Задача 7.17)

### 5.1 Цитаты ФТ

**ФТ §17 + UX-макет `Sprint_7/ux/background_backtest_badge.md`:**
> Бэйдж в шапке справа: число активных + dropdown с прогрессом. Toast «бэктест запущен в фоне». Модалка `BacktestLaunchModal` остаётся открытой.

### 5.2 Brainstorm

**Q1. N одновременных jobs на пользователя.**
→ **Cap = 3** (компромисс: CPU-нагрузка vs UX). Grid-job считается за 1 (но внутри сам имеет multiprocessing pool — суммарный cap workers всё равно `os.cpu_count()-1`).

**Q2. Очередь — in-memory (asyncio.Queue) vs Redis vs БД?**
→ **In-memory + persistence в БД.** Создаётся новая таблица `backtest_jobs(id, user_id, strategy_id, status, progress, params_json, result_json, created_at, updated_at)`. При старте backend запущенные jobs (status `running`) переводятся в `failed` (recovery — пользователь перезапускает руками; полное возобновление в S8).

**Q3. BackgroundTasks vs custom executor.**
→ **Custom executor.** FastAPI BackgroundTasks плох для долгих jobs (исполняется в response lifecycle). Используем `asyncio.create_task` + `BacktestJobManager` (singleton в `app.state`), который держит `dict[job_id, asyncio.Task]`. Cancel — `task.cancel()`.

**Q4. Жизненный цикл WS `/ws/backtest/{job_id}`.**
→ Активен пока `job.status in ('queued','running')` + 30 секунд буфера после `done|error|cancelled` (гарантия доставки финального события). После — server закрывает (1000 normal close).

**Q5. Гонки при параллельных jobs одного пользователя.**
→ Каждый job — отдельный `BacktestEngine` instance + sqlite-сессия per-task. Никакой shared state, кроме `BacktestJobManager.jobs` (защищён asyncio.Lock).

**Q6. Лимиты ресурсов.**
→ Per-user cap 3 jobs (выше). Per-job — для grid: cap 1000 комбинаций, max workers `os.cpu_count()-1`. Для одиночного бэктеста — без ограничения времени (но WS таймаут полезный 1 час → cancel).

### 5.3 Схема `backtest_jobs` (для DEV-1 W1)

```sql
CREATE TABLE backtest_jobs (
  id TEXT PRIMARY KEY,                    -- uuid hex
  user_id INTEGER NOT NULL REFERENCES users(id),
  strategy_id INTEGER NOT NULL REFERENCES strategies(id),
  strategy_version_id INTEGER NULL REFERENCES strategy_versions(id),
  job_type TEXT NOT NULL,                 -- 'single' | 'grid'
  status TEXT NOT NULL,                   -- 'queued' | 'running' | 'done' | 'error' | 'cancelled'
  progress INTEGER NOT NULL DEFAULT 0,    -- 0..100
  params_json TEXT NOT NULL,              -- {ticker, timeframe, date_from, date_to, ranges?}
  result_json TEXT NULL,                  -- финальный snapshot (BacktestResult / GridMatrix)
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT (datetime('now')),
  updated_at DATETIME NOT NULL DEFAULT (datetime('now')),
  finished_at DATETIME NULL
);
CREATE INDEX idx_bj_user_active ON backtest_jobs (user_id, status);
```

### 5.4 WS-канал /ws/backtest/{job_id} (контракт C2)

```json
// Сообщения:
{"event":"queued",   "job_id":"abc","progress":0}
{"event":"started",  "job_id":"abc","progress":0}
{"event":"progress", "job_id":"abc","progress":42}
{"event":"done",     "job_id":"abc","progress":100,"result":{...BacktestResult... or {"matrix":[...]} for grid}}
{"event":"error",    "job_id":"abc","message":"..."}
{"event":"cancelled","job_id":"abc"}
```

Авторизация — тот же паттерн «первое сообщение auth» (см. §4.2 Q1).

### 5.5 Endpoints

```
POST /api/v1/backtest/run-async        # body как у обычного /run, но создаёт job_id
  → 202 {job_id}
POST /api/v1/backtest/grid             # см. §2.3
GET  /api/v1/backtest/jobs?status=...  # список jobs пользователя для бейджа в шапке
POST /api/v1/backtest/jobs/{id}/cancel
WS   /ws/backtest/{job_id}
```

---

## 6. AI слэш-команды и расширение ChatRequest (Задача 7.18)

### 6.1 Цитаты ТЗ/ФТ

**ТЗ §4.7:**
> ```
> POST /api/v1/ai/chat
>   Body: { strategy_id, message, history?: [...] }
>   Response: 200 { response, suggested_blocks?, updated_code? }
> ```

**ТЗ §1810:** «AI-ассистент в торговом терминале для рынка MOEX. Помогаешь трейдерам создавать и оптимизировать торговые стратегии.»

**Источник плана команд:** `Sprint_7/sprint_design.md` Приложение D / ux/ai_commands_dropdown.md → 5 команд: `/chart`, `/backtest`, `/strategy`, `/session`, `/portfolio`. (Файл `.claude/plans/purring-herding-badger.md` отсутствует в репозитории — план перенесён в `sprint_design.md`.)

### 6.2 Brainstorm

**Q1. Расширение `ChatRequest.context`.**
→ Добавить опциональное поле `context: list[ContextItem]` с явной валидацией:
```python
ContextType = Literal['chart', 'backtest', 'strategy', 'session', 'portfolio']
class ContextItem(BaseModel):
    type: ContextType
    id: int | str | None = None  # str для tickers (chart), int для остальных, None для portfolio
```

**Q2. Защита от prompt injection / cross-user access.**
→ Многоступенчатая:
1. **Pydantic** валидация типа и формы.
2. **Ownership check (БД):** для каждого ContextItem backend делает SELECT ... WHERE id = ? AND user_id = current_user.id. Если не нашлось — 404 (НЕ leaks информацию о существовании).
3. **Sanitization данных:** перед склейкой в системный prompt — удаление управляющих символов, маркдаун-эскейп `{}`, обрезка длинных строк (max 2 КБ на ContextItem).
4. **System-prompt prefix:** контекст всегда подаётся как `[CONTEXT]\n...\n[/CONTEXT]\n[USER]\n...\n[/USER]` чтобы модель отделяла factual data от инструкций пользователя. Это стандартная защита от индирект-инжекшна.
5. **Rate-limit:** 10 enriched-запросов / минуту на user (для дорогих контекстов).

**Q3. Формат enriched prompt — что именно подгружается?**
| type | id | Что подгружается из БД |
|------|----|------------------------|
| `chart` | ticker (str) | Текущий timeframe, последняя цена, % за день. Источник — `market_data` |
| `backtest` | int (backtest_id) | strategy_name, ticker, period, P&L%, sharpe, win_rate, max_drawdown, trades_count |
| `strategy` | int (strategy_id) | name, status, current_version_number, описание (text_description), индикаторы (parsed из blocks_json — топ-3) |
| `session` | int (trading_session_id) | ticker, mode, status, total_pnl, open_positions_count, last_trade_at |
| `portfolio` | None | Сводка: total_balance (сумма paper+real), активные сессии (count), общий unrealized P&L |

**Q4. Кэширование context.**
→ **Не кэшируем** на уровне backend в S7. Каждый запрос — fresh data (важно: цены и P&L меняются). Frontend может кэшировать UI-индикатор «привязанного контекста» в чат-store, но enriched prompt всегда строится заново.

**Q5. Rate-limit на context-resolve.**
→ Используем существующий middleware `app/middleware/rate_limit.py`. Конфиг: 10 enriched/min per user. Без context — стандартные лимиты AI-чата.

### 6.3 Контракт C3 (расширение endpoint)

```python
# app/ai/schemas.py (изменение)
class ChatRequest(BaseModel):
    strategy_id: int | None = None
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatMessage] = []
    context: list[ContextItem] = []  # NEW
```

```python
# app/ai/service.py — пайплайн enrichment
async def chat(req: ChatRequest, user_id: int, db: AsyncSession) -> ChatResponse:
    enriched_prefix = ""
    if req.context:
        for item in req.context:
            data = await _resolve_context_item(item, user_id, db)  # ownership check inside
            if data:
                enriched_prefix += f"[CONTEXT type={item.type} id={item.id}]\n{data}\n[/CONTEXT]\n"
    full_prompt = enriched_prefix + req.message
    return await llm_provider.send(full_prompt, history=req.history)
```

### 6.4 Frontend ↔ Backend контракт (для FRONT1 7.19)

Frontend парсит `/команда [id]` локально → формирует `context: [{type:'backtest', id: 42}]` + `message: 'остаток сообщения'`. Сервер не парсит slash-синтаксис, frontend это делает. Это упрощает backend и позволяет UI показывать «контекстную чипу» в сообщении.

---

## 7. Stack Gotchas pre-read

> Источник: `Develop/stack_gotchas/INDEX.md` (18 ловушек). Ниже — 7 наиболее релевантных S7. DEV-агенты адресно читают только нужный файл (правило CLAUDE.md).

| # | Gotcha | Файл | Какие задачи S7 затронуты |
|---|--------|------|---------------------------|
| 1 | **#04** T-Invest streaming 429/reconnect | `gotcha-04-tinvest-stream.md` | 7.13 connection_lost/restored: publish-сайты в `multiplexer.py` уже имеют exponential backoff; нельзя ломать backoff при добавлении notification publish |
| 2 | **#11** Alembic autogenerate drift | `gotcha-11-alembic-drift.md` | 7.1 (strategy_versions ALTER), 7.8 (users.wizard_completed_at), 7.17 (backtest_jobs CREATE) — обязательно `--autogenerate` сравнить с моделями, не положиться на чистый diff |
| 3 | **#12** SQLite batch_alter_table | `gotcha-12-sqlite-batch-alter.md` | 7.1 — ALTER COLUMN с server_default требует op.batch_alter_table; 7.8 — добавление wizard_completed_at в users |
| 4 | **#15** T-Invest tz-naive datetime | `gotcha-15-tinvest-naive-datetime.md` | 7.13 connection_lost: payload `reason` может содержать `last_recieved_at` (datetime) — обязательно tz-aware |
| 5 | **#16** 401 race relogin | `gotcha-16-relogin-race.md` | 7.15 (новый WS endpoint), 7.17 (новый WS endpoint) — JWT auth должен учитывать persist+interceptor race |
| 6 | **#08** AsyncSession.get_bind() в pytest | `gotcha-08-asyncsession-get-bind.md` | 7.1 (versioning unit-tests), 7.2 (grid worker создаёт sync sqlite-сессию — фикстуры pytest-async чувствительны) |
| 7 | **#17** patch.object(bot) frozen | `gotcha-17-telegram-bot-frozen-attrs.md` | 7.14 (Telegram CallbackQueryHandler) — мокать через monkeypatch.setattr, не patch.object |

### 7.1 Кандидат на новый gotcha (по итогам S7)

**Симптом:** EVENT_MAP и publish-payload рассинхронизированы → шаблон `{strategy_name}: {ticker}` рендерится буквально (Sprint_6 Review fix).
**Файл-кандидат:** `gotcha-19-event-map-payload-contract.md` — будет создан DEV-1 (или ARCH в midsprint) если в S7 повторится подобная ошибка. **Превентивно:** в DEV-1 промпте обязательный unit-тест `test_event_map_payload_keys()`.

---

## 8. UX-стыки (проверка совместимости с архитектурой)

> 6 макетов в `Sprint_7/ux/` опубликованы. Ниже — delta'ы и подтверждения.

| Макет | Архитектурная стыковка | Статус |
|-------|------------------------|--------|
| `dashboard_widgets.md` (7.7) | Данные: `/api/v1/account/balance` (есть), `/api/v1/health` (есть), `/api/v1/trading/sessions` (есть). Sparkline баланса — нужен endpoint `/api/v1/account/balance/history?days=30` (новый, легковесный — простая агрегация per-day из `daily_stats`). | ✅ DELTA: добавить endpoint balance/history. DEV-1 backend |
| `wizard_5steps.md` (7.8) | Backend: одна колонка `users.wizard_completed_at: DateTime, NULL`. Endpoint `POST /api/v1/users/me/wizard/complete`. GET `/api/v1/users/me` уже возвращает user — добавить wizard_completed_at в response schema. | ✅ Достаточно |
| `drawing_tools.md` (7.6) | ТЗ §3.14 — таблица `chart_drawings` уже описана. Persist в БД, не localStorage (ТЗ конфликтует с UX-замечанием «localStorage достаточен» — оставляем БД, как в ТЗ). DEV-3 frontend + опционально backend сохранения. | ⚠️ DELTA: либо обновляем ТЗ (localStorage MVP), либо реализуем БД-таблицу. **Решение:** S7 — БД (ТЗ-каноничный). |
| `backtest_overview_analytics.md` (7.16) | Данные: `BacktestResult.trades` (есть, in-memory). Гистограмма P&L и donut Win/Loss считаются на frontend из existing trades[]. | ✅ Достаточно |
| `background_backtest_badge.md` (7.17) | Бейдж читает GET `/api/v1/backtest/jobs?status=running` (см. §5.5). WS `/ws/backtest/{job_id}` для real-time прогресса. Модалка остаётся открытой — это frontend-паттерн (state в React; backend просто принимает закрытие WS клиентом). | ✅ Достаточно |
| `ai_commands_dropdown.md` (7.19) | Фронт парсит slash-команды локально, отправляет `context[]` (см. §6). Backend не делает text-parsing. | ✅ Достаточно |

**Итог §8:** delta'ы — 1 новый endpoint (balance/history) + явное решение по drawing_tools (БД, не localStorage). Передаётся UX/DEV в W1/W2.

---

## 9. Контракты Cross-DEV (сводка для execution_order.md)

| # | Поставщик | Потребитель | Контракт | Документация |
|---|-----------|-------------|----------|--------------|
| C1 | BACK1 | FRONT1 | WS `/ws/trading-sessions/{user_id}` | §4 |
| C2 | BACK1 | FRONT1, FRONT2 | WS `/ws/backtest/{job_id}` | §5 |
| C3 | BACK2 | FRONT1 | `ChatRequest.context: list[ContextItem]` | §6 |
| C4 | BACK2 | FRONT2 | `/api/v1/strategies/{id}/versions*` + alembic | §1 |
| C5 | BACK1 | FRONT2 | `POST /api/v1/backtest/grid` | §2 |
| C6 | BACK2 | FRONT2 | `users.wizard_completed_at` + endpoint | §8 |
| C7 | BACK2 | BACK1, OPS | `request.app.state.notification_service` | sprint_design Приложение A |
| C8 | BACK2 | (deep link) | Telegram CallbackData scheme | sprint_design Приложение A |
| C9 (NEW) | BACK1 | FRONT2 | `GET /api/v1/account/balance/history?days=30` | §8 (delta from UX) |

---

## 10. Чеклист готовности W0 (ARCH часть)

- [x] §1 strategy_versions — DDL + endpoints + политика
- [x] §2 Grid Search — параллелизация + матрица + cap
- [x] §3 5 event_type — file:line + EVENT_MAP записи + verification
- [x] §4 WS /ws/trading-sessions — auth + snapshot + delta
- [x] §5 фоновые бэктесты — таблица + cap + executor
- [x] §6 AI context — schema + защита + enrichment
- [x] §7 Stack Gotchas — 7 ключевых ловушек выписаны
- [x] §8 UX-стыки — проверены, 1 delta зафиксирована (balance/history endpoint)
- [x] §9 контракты — C1–C9 синхронизированы со sprint_design
- [x] Дословные цитаты ТЗ/ФТ — присутствуют в каждой секции
- [ ] Alembic-миграции — проектируются в W2 (DEV-2/DEV-1) на основе DDL §1.3 и §5.3 (W0 не пишет миграции)
- [ ] reports/ARCH_W0_design.md — сохранён отдельно (см. соответствующий файл)

**Готовность гейта W0 → W1: ✅** для ARCH-части. UX 6 макетов опубликованы. QA test plan — отдельная зона ответственности (e2e_test_plan_s7.md).

---

**Конец документа.**
