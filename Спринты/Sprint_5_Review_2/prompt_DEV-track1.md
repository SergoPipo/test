---
sprint: S5R-2
agent: DEV-track1
role: "Backend — prefetch свечей при логине"
wave: 3
depends_on: []
---

# Роль

Ты — Backend-разработчик (senior), специалист по async Python и data pipelines. Твоя задача: реализовать фоновый прогрев `ohlcv_cache` при логине пользователя для тикеров активных/приостановленных торговых сессий. После логина пользователь открывает графики — свечи для его активных сессий уже должны лежать в кеше и отдаваться мгновенно. Работаешь в `Develop/backend/`.

**Ключевое ограничение:** frontend НЕ меняется. Prefetch — чистый backend fire-and-forget. Никакого нового REST-эндпоинта.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python >= 3.11
2. Зависимости предыдущих DEV: нет (трек 1 параллелен треку 2)
3. Существующие файлы:
   - app/auth/router.py          — login endpoint (строки 39–61)
   - app/trading/models.py       — TradingSession модель (строки 20–54)
   - app/market_data/service.py  — MarketDataService.get_candles() (строки 51–72)
   - app/main.py                 — lifespan, AsyncSessionLocal, SessionRuntime
   - app/common/database.py      — AsyncSessionLocal factory
4. База данных: модель TradingSession должна существовать с полями status, ticker, timeframe, user_id
5. Внешние сервисы: T-Invest API (через MarketDataService) — при недоступности prefetch не должен падать
6. Тесты baseline: `pytest tests/` → 0 failures
```

> **Правило S5R.5:** выполни реальный запуск `pytest tests/` и `ruff check .` при предпроверке и зафиксируй фактические результаты в отчёте.

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — ищи gotcha по слоям: `auth`, `market-data`, `database`, `async`. Обрати особое внимание на:
   - **Gotcha-04** (T-Invest rate limits) — ограничение параллелизма обязательно
   - **Gotcha-15** (naive datetime) — все datetime в UTC с tzinfo
   - **Gotcha-08** (если есть, про AsyncSession в background tasks) — передача db_factory, не живой сессии

3. **`Спринты/Sprint_5_Review_2/execution_order.md`** — раздел **«Cross-DEV contracts»**. Трек 1 — **поставщик** прогретого кеша (implicit contract: `ohlcv_cache` заполнен для active/paused сессий). Трек 2 (live-агрегация) и frontend — **потребители** кеша, но через существующий `MarketDataService.get_candles()`, не через новый API.

4. **`Спринты/Sprint_5_Review_2/PENDING_S5R2_track1_backend_prefetch.md`** — полный план, 3 варианта решения. **Решение пользователя: вариант 1 (warm cache в фоне, fire-and-forget).**

5. **Цитаты из кода (по состоянию на 2026-04-17):**

   > **auth/router.py** (login endpoint, строки 39–61):
   > ```python
   > @router.post("/login", response_model=TokenResponse)
   > async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
   >     service = AuthService(db)
   >     try:
   >         token_response = await service.login(data.username, data.password)
   >     except PermissionError:
   >         raise AccountLockedError()
   >     except ValueError:
   >         raise AuthenticationError("Неверный логин или пароль")
   >     csrf_token = secrets.token_urlsafe(32)
   >     response = JSONResponse(content=token_response.model_dump())
   >     response.set_cookie(...)
   >     return response
   > ```
   > Fire-and-forget задачу добавить **после** успешного `token_response` (строка 43), **перед** формированием response. Ошибка prefetch НЕ должна блокировать login.

   > **trading/models.py** (TradingSession, строки 20–54):
   > - `user_id: Mapped[int]` — FK на users
   > - `ticker: Mapped[str]` (строка 33)
   > - `timeframe: Mapped[str | None]` (строка 34) — **может быть None!** Fallback → `'D'`
   > - `status: Mapped[str]` (строка 37) — значения: `"active"`, `"paused"`, `"stopped"`, `"error"`
   > - Индекс `idx_ts_active` по (status, ticker)

   > **market_data/service.py** (MarketDataService.get_candles, строки 51–72):
   > ```python
   > async def get_candles(
   >     self, ticker: str, timeframe: str, from_dt: datetime, to_dt: datetime,
   >     user_id: int | None = None, mode: DataSourceMode = "viewer",
   > ) -> tuple[list[CandleData], str]:
   > ```
   > Этот метод уже реализует gap-detection + кеширование в `ohlcv_cache`. Prefetch просто вызывает его — кеш прогреется автоматически. Не нужно изобретать свой механизм кеширования.

   > **main.py** (lifespan, строки 46–91):
   > - `AsyncSessionLocal` доступен после `init_db()`
   > - `fastapi_app.state.session_runtime` — SessionRuntime singleton
   > - Restore active sessions уже делается в lifespan (строки 70–80) — **похожий паттерн** для prefetch (фоновая задача с собственной db-сессией)

   > **INITIAL_PERIOD_DAYS** (маппинг TF → дней для запроса свечей):
   > ```python
   > INITIAL_PERIOD_DAYS = {
   >     "1m": 1, "5m": 3, "15m": 7, "1h": 30,
   >     "4h": 90, "D": 365, "W": 730, "M": 1825
   > }
   > ```
   > Определить в `prefetch.py` как константу. Frontend использует такой же маппинг — кеш прогреется на тот же период, что запросит фронт.

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

```
- app/auth/router.py            — login endpoint. РАСШИРЯЕМ: добавляем fire-and-forget вызов prefetch.
- app/trading/models.py         — TradingSession модель. ЧИТАЕМ: SELECT по user_id + status. НЕ модифицировать.
- app/market_data/service.py    — MarketDataService.get_candles(). ВЫЗЫВАЕМ из prefetch. НЕ модифицировать.
- app/market_data/prefetch.py   — НОВЫЙ файл. Основная логика прогрева кеша.
- app/main.py                   — lifespan, AsyncSessionLocal. ЧИТАЕМ для паттерна db_factory. НЕ модифицировать.
- app/common/database.py        — AsyncSessionLocal. ИСПОЛЬЗУЕМ как db_factory в background task.
- tests/test_market_data/test_prefetch.py — НОВЫЙ файл. 4 теста.
```

# Задачи

## Задача 1.1: Модуль prefetch — `app/market_data/prefetch.py`

Создать новый модуль с основной функцией прогрева кеша:

```python
import asyncio
from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.market_data.service import MarketDataService
from app.trading.models import TradingSession

logger = structlog.get_logger(__name__)

# Период запроса свечей по таймфрейму (совпадает с frontend INITIAL_PERIOD_DAYS)
INITIAL_PERIOD_DAYS: dict[str, int] = {
    "1m": 1, "5m": 3, "15m": 7, "1h": 30,
    "4h": 90, "D": 365, "W": 730, "M": 1825,
}

# Ограничение параллелизма — не более 3 одновременных запросов к T-Invest (gotcha-04)
_PREFETCH_SEMAPHORE_LIMIT = 3

# Таймфрейм по умолчанию, если TradingSession.timeframe is None
_DEFAULT_TIMEFRAME = "D"


async def prefetch_active_sessions(user_id: int, db_factory) -> None:
    """Фоновый прогрев ohlcv_cache для тикеров активных/приостановленных сессий.

    Вызывается как fire-and-forget asyncio.create_task из login endpoint.
    Ошибки отдельных тикеров логируются и НЕ пробрасываются.

    Args:
        user_id: ID пользователя, который только что залогинился.
        db_factory: Callable, возвращающий async context manager для AsyncSession
                    (AsyncSessionLocal из common/database.py).
                    НЕ передавать живую db-сессию из request scope —
                    она будет закрыта после завершения login response.
    """
    # 1. Получить список сессий (active + paused)
    # 2. Для каждой уникальной пары (ticker, timeframe) → вызвать get_candles
    # 3. Semaphore(3) для параллелизма
    # 4. Каждая ошибка — logger.warning, НЕ raise
```

**Алгоритм внутри `prefetch_active_sessions`:**

1. **SELECT сессий:** открыть свою db-сессию через `db_factory()`, выполнить:
   ```python
   stmt = select(TradingSession.ticker, TradingSession.timeframe).where(
       TradingSession.user_id == user_id,
       TradingSession.status.in_(["active", "paused"]),
   ).distinct()
   ```
   Сразу закрыть db-сессию после SELECT (не держать её на время всего prefetch).

2. **Дедупликация:** несколько сессий на одном тикере с одним TF — один запрос свечей.

3. **Параллельный прогрев с Semaphore:**
   ```python
   sem = asyncio.Semaphore(_PREFETCH_SEMAPHORE_LIMIT)

   async def _fetch_one(ticker: str, timeframe: str) -> None:
       async with sem:
           try:
               period = INITIAL_PERIOD_DAYS.get(timeframe, INITIAL_PERIOD_DAYS["D"])
               now = datetime.now(timezone.utc)
               from_dt = now - timedelta(days=period)
               async with db_factory() as db:
                   svc = MarketDataService(db)
                   await svc.get_candles(
                       ticker=ticker,
                       timeframe=timeframe,
                       from_dt=from_dt,
                       to_dt=now,
                       user_id=user_id,
                       mode="viewer",
                   )
               logger.info("prefetch.ok", ticker=ticker, tf=timeframe, days=period)
           except Exception:
               logger.warning("prefetch.failed", ticker=ticker, tf=timeframe, exc_info=True)

   tasks_list = []
   for ticker, tf_raw in pairs:
       tf = tf_raw or _DEFAULT_TIMEFRAME
       tasks_list.append(_fetch_one(ticker, tf))

   await asyncio.gather(*tasks_list)
   logger.info("prefetch.done", user_id=user_id, count=len(tasks_list))
   ```

4. **Обёртка верхнего уровня:** весь `prefetch_active_sessions` обёрнут в `try/except Exception` — при любом сбое (даже получения списка сессий) только логируем, не крашим.

## Задача 1.2: Интеграция в login — `app/auth/router.py`

В `auth/router.py` после строки 43 (`token_response = await service.login(...)`) добавить fire-and-forget prefetch:

```python
# --- Prefetch: прогрев кеша свечей для активных сессий ---
try:
    from app.market_data.prefetch import prefetch_active_sessions
    from app.common.database import AsyncSessionLocal
    # user_id из JWT payload (sub)
    user_id = token_response.user_id  # или извлечь из token_response как нужно
    asyncio.create_task(
        prefetch_active_sessions(user_id, AsyncSessionLocal),
        name=f"prefetch-user-{user_id}",
    )
except Exception:
    # Prefetch — best-effort, ошибка НЕ блокирует login
    import structlog
    structlog.get_logger(__name__).warning("prefetch.schedule_failed", exc_info=True)
# --- /Prefetch ---
```

**Критичные моменты:**
- Использовать `asyncio.create_task`, НЕ `await` — login не должен ждать завершения prefetch.
- Передавать `AsyncSessionLocal` (db_factory), НЕ `db` из Depends — request-scoped сессия будет закрыта.
- Import `asyncio` в начало файла, если ещё не импортирован.
- Извлечь `user_id` из `token_response` — проверить, какое поле содержит id (может быть `token_response.user_id`, `token_response.sub`, или нужно декодировать JWT). Посмотри на модель `TokenResponse` и метод `AuthService.login()`.

## Задача 1.3: Тесты — `tests/test_market_data/test_prefetch.py`

Создать файл с 4 тестами:

### test_prefetch_warms_cache

```python
async def test_prefetch_warms_cache(test_db, test_user):
    """Создать 2 сессии (active + paused), вызвать prefetch,
    проверить что get_candles вызывался для обеих."""
    # 1. Создать TradingSession(user_id=test_user.id, ticker="SBER", timeframe="D", status="active")
    # 2. Создать TradingSession(user_id=test_user.id, ticker="GAZP", timeframe="1h", status="paused")
    # 3. await prefetch_active_sessions(test_user.id, AsyncSessionLocal)
    # 4. Assert: MarketDataService.get_candles вызван 2 раза (mock или spy)
    #    Либо: проверить source="cache" при повторном запросе
```

### test_prefetch_skips_stopped

```python
async def test_prefetch_skips_stopped(test_db, test_user):
    """Создать stopped-сессию, убедиться что для неё НЕ запрашиваются свечи."""
    # 1. Создать TradingSession(status="stopped")
    # 2. Mock MarketDataService.get_candles
    # 3. await prefetch_active_sessions(...)
    # 4. Assert: get_candles НЕ вызван
```

### test_prefetch_handles_errors

```python
async def test_prefetch_handles_errors(test_db, test_user):
    """T-Invest недоступен — prefetch не падает, логирует warning."""
    # 1. Создать active-сессию
    # 2. Mock get_candles → raise ConnectionError
    # 3. await prefetch_active_sessions(...) — НЕ должен бросить исключение
    # 4. Assert: logger.warning вызван
```

### test_prefetch_null_timeframe

```python
async def test_prefetch_null_timeframe(test_db, test_user):
    """Сессия без timeframe — fallback на 'D'."""
    # 1. Создать TradingSession(timeframe=None, status="active")
    # 2. Mock get_candles
    # 3. await prefetch_active_sessions(...)
    # 4. Assert: get_candles вызван с timeframe="D"
```

**Фикстуры:** используй существующие из `conftest.py`: `test_db`, `test_user`, `async_client`. Если нужна фикстура для `AsyncSessionLocal` — посмотри как это сделано в других тестах проекта.

## Задача 1.4: Stack Gotcha (если обнаружена)

Если `AsyncSessionLocal` в фоновой задаче ведёт себя неочевидно (например, нужен особый паттерн создания/закрытия сессии в `asyncio.create_task`) — создай `Develop/stack_gotchas/gotcha-<N+1>-async-session-background-task.md` и добавь строку в `INDEX.md`.

Если ловушка уже описана (gotcha-08 или другая) — укажи в секции 7 отчёта, что применил.

Если новой ловушки нет — явно укажи: «Новых ловушек не обнаружено».

# Тесты

```
tests/test_market_data/
└── test_prefetch.py    # 4 теста (задача 1.3):
                        #   - test_prefetch_warms_cache
                        #   - test_prefetch_skips_stopped
                        #   - test_prefetch_handles_errors
                        #   - test_prefetch_null_timeframe
```

**Фикстуры:** `test_db`, `test_user`, `async_client` из `conftest.py`.

**Запуск:** `pytest tests/test_market_data/test_prefetch.py -v`

# ⚠️ Integration Verification Checklist

- [ ] **`prefetch_active_sessions()` вызывается из `auth/router.py`:**
  `grep -rn "prefetch_active_sessions" app/auth/router.py` → найден вызов через `asyncio.create_task`

- [ ] **`asyncio.create_task` используется (НЕ await):**
  `grep -rn "create_task.*prefetch" app/auth/router.py` → fire-and-forget, login не блокируется

- [ ] **`asyncio.Semaphore` ограничивает параллелизм:**
  `grep -rn "Semaphore" app/market_data/prefetch.py` → лимит 3 (gotcha-04)

- [ ] **`structlog` для логирования:**
  `grep -rn "structlog" app/market_data/prefetch.py` → используется (не print, не logging)

- [ ] **Тесты зелёные:**
  `pytest tests/test_market_data/test_prefetch.py -v` → 4/4 passed

- [ ] **Если точка вызова не найдена** — пометить `⚠️ NOT CONNECTED` в отчёте. Такая пометка блокирует приёмку.

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.

**НЕ возвращай:** полный код файлов, полный лог tool-вызовов, подробные объяснения решений.

**Верни:**

```markdown
## DEV-track1 отчёт — S5R-2, Backend prefetch свечей при логине

### 1. Что реализовано
- <bullet list — 5-10 пунктов>

### 2. Файлы
- **Новые:** ...
- **Изменённые:** ...

### 3. Тесты
- Backend: `X/Y passed`

### 4. Integration points
- `prefetch_active_sessions()` вызывается из `app/auth/router.py:XX` (✅ подключено)

### 5. Контракты для других DEV
- **Поставляю:** прогретый ohlcv_cache для active/paused сессий — потребители: frontend (через существующий GET /candles), трек 2 (live-агрегация)
- **Использую:** MarketDataService.get_candles() — контракт соблюдён

### 6. Проблемы / TODO

### 7. Применённые Stack Gotchas

### 8. Новые Stack Gotchas (если обнаружены)
```

Сохрани отчёт как файл: **`Спринты/Sprint_5_Review_2/reports/DEV-track1_report.md`**.

# Alembic-миграция

Не требуется. Трек 1 не добавляет и не изменяет модели БД — работает с существующей `TradingSession` и существующей таблицей `ohlcv_cache`.

# Чеклист перед сдачей

- [ ] Задачи 1.1–1.4 реализованы
- [ ] `pytest tests/` → 0 failures
- [ ] `ruff check .` → 0 errors
- [ ] **Integration verification checklist полностью пройден** — `prefetch_active_sessions` вызывается из `auth/router.py` через `create_task`
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_5_Review_2/reports/DEV-track1_report.md`
- [ ] **Cross-DEV contracts подтверждены** — секция 5 отчёта содержит явные подтверждения
- [ ] **Stack Gotchas применены** — секция 7 отчёта содержит применённые ловушки (gotcha-04, gotcha-15, и др.)
- [ ] Login НЕ замедлился — prefetch запущен как fire-and-forget (`asyncio.create_task`), не `await`
- [ ] При отсутствии T-Invest аккаунта / при ошибке API — prefetch не падает, логирует warning
- [ ] При 0 активных сессий — prefetch завершается мгновенно, без ошибок
- [ ] НЕ модифицирован frontend-код (никакой `marketDataStore.ts`, `ChartPage.tsx` и т.д.)
