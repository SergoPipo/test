# [Sprint_5_Review_2] Трек 1 — Backend prefetch свечей при логине

> **Источник:** идея пользователя в handoff S5R wave 4 (2026-04-16).
> **Приоритет:** 🟡 Важно (UX-ускорение для активных торговых сессий).
> **Статус:** 🔄 В работе — решение утверждено 2026-04-17, prompt создан.

## Контекст

TODO детализировать. Краткая суть:
- При логине frontend постепенно догружает свечи через REST по мере открытия пользователем инструментов. Для активных торговых сессий (из `TradingSession` со статусом RUNNING) это означает паузу «график пустой → заполняется».
- Идея пользователя: backend при логине формирует список активных сессий, предзагружает свежие свечи (последние N за последний рабочий интервал) и отдаёт их одним запросом либо прогревает кеш, чтобы первый запрос фронта прошёл моментально.

## Корень проблемы

TODO:
- Как сейчас устроен flow «login → ChartPage»: какие запросы идут, в каком порядке, куда кладутся.
- Где именно «пауза»: REST к MOEX ISS или к T-Invest historical? Холодный кеш `candlesCache`?
- Почему это болит именно на активных сессиях.

## Утверждённое решение (2026-04-17)

**Вариант:** Warm cache on login (fire-and-forget asyncio.create_task).

После успешного login, backend в фоновой задаче:
1. Запрашивает active + paused TradingSessions пользователя
2. Для каждой (ticker, timeframe) вызывает `MarketDataService.get_candles()` — кеш прогревается автоматически
3. Frontend НЕ меняется — `GET /candles` просто быстрее отвечает из ohlcv_cache
4. Параллелизм ограничен `asyncio.Semaphore(3)` (gotcha-04: rate limits T-Invest)
5. Ошибки отдельных тикеров логируются и не блокируют login

## Затрагиваемые файлы

TODO:
- `backend/app/auth/router.py` — хук на login (или событие через сигнал)
- `backend/app/market_data/prefetch.py` — **новый** модуль
- `backend/app/market_data/router.py` — возможный новый endpoint
- `backend/alembic/versions/*.py` — если нужен буфер в БД (вряд ли)
- `frontend/src/features/chart/stream/store.ts` — bootstrap после логина
- `frontend/src/features/auth/hooks.ts` — trigger bootstrap

## Критерии готовности

TODO:
- [ ] После логина при открытии `ChartPage` для тикера активной сессии свечи появляются в течение < 100ms
- [ ] Нет регрессии при логине без активных сессий (prefetch не блокирует login)
- [ ] Unit-тест prefetch-логики (сколько сессий → сколько вызовов T-Invest/ISS)
- [ ] E2E-тест «логин → открыть ChartPage активной сессии → график виден без loading spinner»
- [ ] Документирован Stack Gotcha если что-то неочевидное (rate limits T-Invest при массовом prefetch?)

## Риски

TODO:
- Massive prefetch при логине может затормозить login-запрос. Решение — async/background.
- T-Invest rate limits (см. gotcha-04 по SDK) — ограничить параллелизм.
- Что если активных сессий 20+? Нужен кеп.

## Оценка

TODO (черновая): ~1 сессия DEV, 1 промпт по `prompt_template.md`.

## Открытые вопросы к пользователю

- Какой TF предзагружать? Основной таймфрейм сессии? Все?
- Сколько свечей в prefetch: последние 100? 500? 1D?
- Prefetch только активных (RUNNING) или также PAUSED?
