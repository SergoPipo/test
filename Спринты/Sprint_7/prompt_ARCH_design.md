---
sprint: 7
agent: ARCH
role: Архитектурное design-ревью на W0 (pre-sprint)
wave: 0
depends_on: []
---

# Роль

Ты — архитектор проекта на этапе W0 (pre-sprint design). Твоя задача — подготовить архитектурные решения для крупных задач S7 ДО запуска DEV-агентов, чтобы избежать переделок в W1/W2. Без качественного W0 субагенты повторят ошибки S5/S6 (см. ретроспективу `Sprint_5_Review/changelog.md`).

# Предварительная проверка

1. `Спринты/Sprint_7/sprint_design.md` прочитан полностью (особенно §2, §3.1.2, Приложение C, Приложение D).
2. `Develop/CLAUDE.md` прочитан целиком.
3. `Develop/stack_gotchas/INDEX.md` прочитан целиком.
4. `Sprint_7/preflight_checklist.md` пройден.
5. `Спринты/project_state.md:79–90` прочитан (раздел про MR.5 — обязательная проверка S7).

# Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| pyright-lsp | нет (design only) | — |
| typescript-lsp | нет | — |
| context7 | да — для SQLAlchemy, FastAPI WebSocket, multiprocessing, APScheduler | WebSearch |
| playwright | нет | — |
| code-review | нет (W0 — design) | — |
| frontend-design | нет (UX отвечает за макеты) | — |
| superpowers (brainstorming) | **да, для каждой подзадачи** | — |

# Обязательное чтение (BEFORE design)

1. **`Спринты/Sprint_7/sprint_design.md`** полностью.
2. **`Спринты/project_state.md:79–90`** — MR.5 «5 event_type подключение к runtime» (дословно).
3. **`Develop/stack_gotchas/INDEX.md`** — выбрать 5–7 ловушек, релевантных S7.
4. **`.claude/plans/purring-herding-badger.md`** — план AI-команд (источник для 7.18 design).
5. **`Sprint_6/changelog.md`** — записи 2026-04-24 про EVENT_MAP фикс (база для 7.13).
6. **Sprint_6_Review/code_review.md** — формат code-ревью, который повторим в 7.R.
7. **Цитаты из ТЗ/ФТ** — найти и зафиксировать в `arch_design_s7.md`:
   - ТЗ раздел про версионирование стратегий (для 7.1).
   - ТЗ раздел про Grid Search/оптимизацию (для 7.2).
   - ТЗ раздел про WebSocket-каналы (для 7.15, 7.17).
   - ТЗ/ФТ раздел про AI-чат и контекст (для 7.18).
   - ФТ разделы про backup, wizard, инструменты рисования (для DEV-промптов).

# Рабочая директория

`Спринты/Sprint_7/` (создаём `arch_design_s7.md`).

# Контекст существующего кода

- `app/notification/service.py` + `EVENT_MAP` — текущая система уведомлений (S6).
- `app/trading/runtime.py`, `app/trading/engine.py` — источник publish-сайтов для 7.13.
- `app/broker/tinvest/multiplexer.py` — gRPC reconnect loop (для `connection_lost/restored`).
- `app/main.py:68` — singleton NotificationService (использовать в 7.12 DI).
- `app/backtest/` — Backtest Engine (для 7.2 Grid Search и 7.17 фоновых).
- `app/strategy/` — Strategy Engine (для 7.1 версионирования).
- `app/ai/` — AI Service (для 7.18 расширения context).

# Задачи

## 1. Brainstorm 7.1 «Версионирование стратегий»

Через skill `superpowers:brainstorming` спроектировать:

- **Модель `strategy_versions`** — поля, индексы, FK на strategies. Минимум: `id, strategy_id, blocks_xml, code, created_at, created_by, comment`. Решить: хранить полный snapshot или diff'ы?
- **Политика создания версий** — на каждый Save? явный «Сохранить версию»? авто каждые N минут?
- **Откат** — создаём новую версию из старой (history-preserving) или перезаписываем текущую?
- **Совместимость с redis-кэшем** стратегий (если есть).
- **Alembic-миграция** — конкретный набор операций.

В `arch_design_s7.md` секция «1. Версионирование стратегий»:
- Окончательное решение по каждому пункту.
- Готовый DDL для миграции.
- Цитаты ТЗ дословно.

## 2. Brainstorm 7.2 «Grid Search»

- **Параллелизация** — `multiprocessing.Pool` vs `asyncio + Semaphore` vs Celery. Сравнить, выбрать.
- **Лимит N комбинаций** — hard cap (рекомендую 1000), warning UI пользователю при превышении.
- **Shape матрицы результата** — `[{params: {p1: v1, p2: v2}, sharpe: float, pnl: float, win_rate: float, drawdown: float}]`.
- **WS канал** — переиспользуем `/ws/backtest/{job_id}` (контракт C2) с расширенным `result.matrix`.

## 3. Brainstorm 7.13 «5 event_type → runtime»

Для каждого из 5 event_type — точный publish-сайт `<file:line>` и контекст:

| event_type | Файл | Что подставлять в EVENT_MAP |
|------------|------|------------------------------|
| `trade_opened` | `app/trading/engine.py` или `runtime.py` | strategy_name, ticker, direction, volume, price |
| `partial_fill` | `app/trading/engine.py` (OrderManager) | strategy_name, ticker, filled_qty, total_qty, avg_price |
| `order_error` | `app/trading/engine.py` (OrderManager) | strategy_name, ticker, reason, error_code |
| `all_positions_closed` | `app/trading/engine.py:681` (event уже есть) | strategy_name, total_pnl |
| `connection_lost / connection_restored` | `app/broker/tinvest/multiplexer.py` (reconnect loop) | broker_name, reason |

**Цитировать MR.5** из `project_state.md:79–90` дословно. Шаблоны заполняются по аналогии с фиксом из Sprint_6_Review (8 publish-сайтов).

В `arch_design_s7.md` секция «3. 5 event_type» — список с file:line для каждого + готовая EVENT_MAP-запись.

## 4. Brainstorm 7.15 «WS канал торговых сессий»

- **Авторизация** — JWT в query string (`?token=...`) или cookie. Решить с учётом совместимости с frontend.
- **Содержание** — `snapshot` (вся карточка) на subscribe + `delta` events далее? Или всегда `snapshot`?
- **Reconnect** — client-side отвечает frontend, backend просто принимает повторное подключение.
- **Двойной источник правды** — polling 10s удаляется в одном PR с введением WS (контракт C1).
- **Подписка на event_bus** — один WS-handler подписывается на `trades:{session_id}` для каждой сессии user'а.

## 5. Brainstorm 7.17 «Фоновый бэктест»

- **N одновременных jobs на пользователя** — рекомендую cap 5 (защита от перегрузки CPU).
- **Очередь** — in-memory (asyncio.Queue) или Redis? Решить с учётом restart backend.
- **Жизненный цикл WS-канала** `/ws/backtest/{job_id}` — пока job жив + N секунд после `done` для гарантии получения финального события.
- **BackgroundTasks vs custom executor** — FastAPI BackgroundTasks может оказаться слабым для долгих jobs; рассмотреть кастомный executor.

## 6. Brainstorm 7.18 «AI слэш-команды»

- **Расширение `ChatRequest.context = [{type, id}]`** — где `type ∈ {'chart', 'backtest', 'strategy', 'session', 'portfolio'}`.
- **Защита** — backend валидирует `id` принадлежит current_user (запрос в БД по таблицам `strategies`, `backtests`, `trading_sessions`).
- **Формат enriched prompt** — backend подгружает данные (тикер, период, метрики бэктеста и т.д.) и склеивает с user prompt в системный prefix.
- **Кэширование** — context подгружается каждый запрос или кэшируется в session?
- **Источник плана:** `.claude/plans/purring-herding-badger.md` — цитировать ключевые блоки.

## 7. Stack Gotchas pre-read

Из `Develop/stack_gotchas/INDEX.md` выбрать 5–7 ловушек, релевантных S7. Кандидаты:

- WebSocket reconnect и cleanup (для C1, C2, 7.15, 7.17).
- Alembic auto-generate gotchas (для 7.1, 7.8 миграций).
- T-Invest tz-naive→aware (для 7.13 connection events) — gotcha-15.
- lightweight-charts series cleanup (для 7.6 инструментов рисования).
- Mantine modal lifecycle (для 7.8 wizard).
- SQLAlchemy session per-request (для 7.1 versioning).
- 401 cleanup+guard (для всех новых endpoint'ов) — gotcha-16.

В `arch_design_s7.md` секция «7. Stack Gotchas pre-read» — список с одной строкой описания каждой ловушки и какая задача S7 её затрагивает.

## 8. Согласование с UX-макетами

После публикации UX 6 макетов в `Sprint_7/ux/` — проверить совместимость с архитектурой:

- `dashboard_widgets.md` — данные доступны через существующие endpoints?
- `wizard_5steps.md` — `wizard_completed_at` колонка достаточна?
- `drawing_tools.md` — localStorage достаточен или нужен backend persist?
- `backtest_overview_analytics.md` — данные `trades[]` уже в `BacktestResult`?
- `background_backtest_badge.md` — модалка остаётся открытой — frontend паттерн (нужны изменения backend)?
- `ai_commands_dropdown.md` — формат context из плана `.claude/plans/purring-herding-badger.md`.

В `arch_design_s7.md` секция «8. UX-стыки» — список delta (если найдены).

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Не применимо (W0 — design без кода).

# Тесты

Не применимо (design ревью).

# Integration Verification Checklist

Не применимо (design ревью). Чеклист включается в DEV-промпты W1/W2.

# Формат отчёта

Сохранить **2 файла**:

1. **`Спринты/Sprint_7/arch_design_s7.md`** — полный design-документ:
   - 8 секций по подзадачам выше.
   - Каждая секция: решение + обоснование + конкретика (DDL, схема WS, file:line для publish-сайтов).
   - Дословные цитаты ТЗ/ФТ.
   - Stack Gotchas pre-read список.

2. **`Спринты/Sprint_7/reports/ARCH_W0_design.md`** — краткая 8-секционная сводка до 400 слов по шаблону `prompt_template.md` (что реализовано, файлы, проблемы, применённые Stack Gotchas, использование плагинов и т.д.).

# Alembic-миграция

Не применимо (W0 — design без миграций).

# Чеклист перед сдачей

- [ ] `arch_design_s7.md` опубликован, все 8 секций заполнены.
- [ ] DDL для `strategy_versions` готов (для DEV-2 в W2).
- [ ] DDL для `users.wizard_completed_at` готов (для DEV-2 в W2).
- [ ] 5 publish-сайтов для 7.13 указаны с `<file:line>` (для DEV-1 в W1).
- [ ] Контракты C1, C2, C3 подтверждены формой JSON-схемы.
- [ ] Stack Gotchas pre-read готов (5–7 ловушек).
- [ ] Дословные цитаты ТЗ/ФТ выписаны.
- [ ] UX-стыки проверены (после публикации UX макетов).
- [ ] `reports/ARCH_W0_design.md` сохранён.
- [ ] `Sprint_7/changelog.md` обновлён немедленно.
- [ ] `Sprint_7/sprint_state.md` отражает «W0 ARCH ✅».
