# Sprint_5_Review_2 — Changelog

> Хронологический журнал выполнения треков S5R-2.
> Формат: дата → что изменено → файлы → результат.

---

## 2026-04-16 — Создание скелета S5R-2

**Контекст:** закрыт S5R wave 4 (фазы 3.3–3.7). Крупные треки chart-hardening вынесены в отдельный патч-цикл `Sprint_5_Review_2/` согласно handoff в `project_state.md`.

**Что сделано:**
- Создана папка `Спринты/Sprint_5_Review_2/`.
- Созданы базовые файлы (скелеты):
  - `README.md` — контекст патч-цикла, отличие от S5R, состав 5 треков.
  - `backlog.md` — сводная таблица, детализация в PENDING-файлах.
  - `execution_order.md` — порядок 4 → 5/3 → 1/2 → ARCH, шаблон Cross-DEV contracts.
  - `preflight_checklist.md` — чеклист перед каждой DEV-сессией.
  - `PENDING_S5R2_track1_backend_prefetch.md` — скелет плана трека 1.
  - `PENDING_S5R2_track2_live_aggregation.md` — скелет плана трека 2.
  - `PENDING_S5R2_track3_sequential_index.md` — скелет плана трека 3.
  - `PENDING_S5R2_track4_401_unauthorized.md` — скелет плана трека 4.
  - `PENDING_S5R2_track5_tf_aware_upsert.md` — скелет плана трека 5.
  - `changelog.md` — этот файл.

**Что НЕ сделано (на следующих итерациях этапа A):**
- Детализация каждого `PENDING_S5R2_track*.md`: root cause, решение, критерии готовности.
- Заполнение Cross-DEV contracts в `execution_order.md`.
- `arch_review_s5r2.md` — создаётся после финального ревью.

**Следующее действие:** согласовать с пользователем приоритет детализации PENDING-файлов (начать с трека 4 как UX-блокера?) и имя ветки для коммита скелета в корневом репо.

---

## 2026-04-16 — Трек 4: детализация плана (diagnose-first)

**Контекст:** пользователь утвердил начало S5R-2 с трека 4 (401 Unauthorized после релогина) как UX-блокера. Ветка: `docs/s5r2-skeleton-track4`.

**Что сделано:**
- Explore-агент изучил реальный код frontend (authStore, api client, marketDataStore, useWebSocket, e2e) и выдал карту архитектуры + 3 гипотезы root cause.
- `PENDING_S5R2_track4_401_unauthorized.md` переписан со скелета в полный план:
  - Секция «Контекст» — реальная архитектура (Zustand persist + axios interceptor + Zustand market store + singleton WS) с конкретными путями файлов и диапазонами строк.
  - Секция «Корень проблемы» — 3 пронумерованные гипотезы + побочные наблюдения (candlesCache не чистится, WS на старом токене).
  - Секция «План диагностики» — 7 шагов (воспроизведение → фиксация 401 → timing-трейс console.debug → localStorage-инспекция → backend JWT-декод → incognito → root cause).
  - Секция «Предлагаемое решение» — 4 варианта (cleanup hook / subscribe pattern / interceptor guard / ChartPage defer).
  - Секция «Затрагиваемые файлы» — 7 файлов (5 src + 2 test) + опциональный backend.
  - Секция «Критерии готовности» — 7 пунктов, обязательный новый `gotcha-16-relogin-race.md`.
  - Секция «Риски» — 4 пункта (persist coupling, AbortController UX, persist-архитектура, Dev vs prod).
  - Секция «Открытые вопросы к пользователю» — 5 пунктов.
- Оценка: 1–2 DEV-сессии, один промпт по `prompt_template.md`.

**Файлы:** `Спринты/Sprint_5_Review_2/PENDING_S5R2_track4_401_unauthorized.md`, этот changelog.

**Тесты:** не применимо (документация).

**Что НЕ сделано (следующий шаг):** создать `prompt_DEV-track4.md` по `prompt_template.md` — уже на этапе B, когда ответим на 5 открытых вопросов пользователю и получим подтверждение.

**Результат:** ✅ план трека 4 готов к обсуждению с пользователем.

---

## 2026-04-17 — Трек 4: решения пользователя + prompt_DEV + JWT blacklist анализ

**Контекст:** пользователь ответил на 5 открытых вопросов. HAR-файлы (Chrome + Safari) не содержат 401 — баг не воспроизвёлся при записи. Стратегия изменена на «превентивный фикс + диагностическая трассировка».

**Решения пользователя:**
- Persist token: **localStorage** + cleanup-хуки (не менять хранилище).
- Backend JWT blacklist: **Вариант Б** — реализовать как отдельную задачу.
- Браузер: Safari (основной). Chrome — для HAR-записи.
- Другой пользователь: не обязателен сейчас.
- HAR: не коммитить (в Chrome HAR лежит пароль!).

**Что сделано:**
- `JWT_blacklist_analysis.md` — развёрнутый анализ 5 вариантов backend JWT invalidation (PG таблица / token versioning / Redis / short-lived access + DB refresh / гибрид). Сравнительная таблица, рекомендация: вариант 5 (гибрид). Ожидает выбора пользователя.
- `prompt_DEV-track4.md` — полный промпт по `prompt_template.md` (11 секций):
  - 6 задач + 1 опциональная: diagnostic tracing, cleanup hook в logout, guard в interceptor, ChartPage defer, E2E тест, Stack Gotcha 16.
  - Integration Verification Checklist: 7 grep-проверок.
  - Тесты: 3+ vitest + 1 E2E Playwright.
- `PENDING_S5R2_track4_401_unauthorized.md` — обновлён: зафиксировано решение пользователя.
- `changelog.md` — эта запись.

**Файлы:**
- `Спринты/Sprint_5_Review_2/JWT_blacklist_analysis.md`
- `Спринты/Sprint_5_Review_2/prompt_DEV-track4.md`
- `Спринты/Sprint_5_Review_2/PENDING_S5R2_track4_401_unauthorized.md`
- `Спринты/Sprint_5_Review_2/changelog.md`

**Следующее действие:** пользователь ревьюирует JWT_blacklist_analysis.md (выбирает вариант). Параллельно можно запускать DEV-сессию по prompt_DEV-track4.md.

**Результат:** ✅ этап B для трека 4 завершён, промпт готов к запуску.

---

## 2026-04-17 — Трек 4: DEV-сессия — 401 Unauthorized после релогина (фикс)

**Контекст:** UX-блокер — после logout → login запросы свечей могли уходить с пустым/старым token. Стратегия: превентивный фикс (cleanup + guard + ChartPage defer) + диагностическая трассировка (console.debug в DEV-режиме).

**Что сделано:**
- **4.1 Diagnostic tracing:** console.debug в authStore (login/logout) и client.ts (request interceptor + 401 response). Только `import.meta.env.DEV`, не попадает в production.
- **4.2 Cleanup hook в logout():** порядок — closeWS → abortAllInflight → set(null) → localStorage.removeItem('auth-storage') → clearCandlesCache.
  - `useWebSocket.ts`: экспортирована `closeWS()` — закрывает singleton WS, очищает subscriptions, отменяет reconnect.
  - `marketDataStore.ts`: экспортирована `clearCandlesCache()` — сбрасывает in-memory + localStorage candlesCache.
  - `client.ts`: глобальный `AbortController` (`abortAllInflight` / `renewAbortController`) привязывается к каждому запросу; ECANCELED подавляется в response interceptor.
- **4.3 Guard в request interceptor:** `!token && !url.startsWith('/auth/')` → `AxiosError('ECANCELED')`. Предотвращает отправку запросов без Authorization.
- **4.4 ChartPage defer:** `useEffect` deps теперь включают `token`; убран `setTimeout(() => fetchCandles(), 0)`. Если token=null → effect не стреляет.
- **4.5 E2E тест:** `auth.spec.ts` — новый сценарий «logout → login → chart loads without 401» с трекингом 401 responses.
- **4.6 Stack Gotcha 16:** `gotcha-16-relogin-race.md` создан, INDEX.md обновлён (строка 16).

**Файлы:**
- `Develop/frontend/src/stores/authStore.ts` — cleanup hook, tracing
- `Develop/frontend/src/api/client.ts` — AbortController, guard, tracing
- `Develop/frontend/src/stores/marketDataStore.ts` — clearCandlesCache()
- `Develop/frontend/src/hooks/useWebSocket.ts` — closeWS()
- `Develop/frontend/src/pages/ChartPage.tsx` — token dep в useEffect
- `Develop/frontend/e2e/auth.spec.ts` — E2E сценарий logout→login→chart
- `Develop/frontend/src/stores/__tests__/authStore.test.ts` — 10 тестов (logout cleanup)
- `Develop/frontend/src/api/__tests__/client.test.ts` — 3 теста (guard)
- `Develop/stack_gotchas/gotcha-16-relogin-race.md` + INDEX.md

**Тесты:** tsc --noEmit: 0 errors, vitest: 226 passed (47 файлов), lint: 0 новых errors (1 pre-existing в ChartPage WS effect).

**Stack Gotchas применённые:** нет (трек 4 — новый класс проблемы).

**Stack Gotchas новые:** `gotcha-16-relogin-race.md` (Auth/Zustand/Axios race)

**Результат:** ✅ задачи 4.1–4.6 реализованы. 4.7 (Safari GUI тест) — SKIP (нет доступа к Safari GUI из CLI-агента).

---

## 2026-04-17 — Треки 5 и 3: создание prompt_DEV

**Контекст:** после DEV-сессии трека 4. Подготовка промптов для фазы 2 (параллельные сессии).

**Что сделано:**
- `prompt_DEV-track5.md` — TF-aware upsertLiveCandle. 4 задачи: извлечение TF из wsChannel, guard в upsertLiveCandle, vitest тесты, gotcha. Cross-DEV contract: поставщик сигнатуры для трека 2.
- `prompt_DEV-track3.md` — Sequential-index mode для intraday. 4 задачи: dual-mode mapping + formatters, переключатель в UI, vitest, gotcha. lightweight-charts v5, порядковые индексы + custom timeFormatter.
- Оба промпта: по `prompt_template.md` (11 секций), с цитатами из реального кода, integration checklist.

**Файлы:** `prompt_DEV-track5.md`, `prompt_DEV-track3.md`, этот changelog.

**Результат:** ✅ промпты фазы 2 готовы к запуску в отдельных Claude-сессиях.

---

## 2026-04-17 — Трек 5: DEV-сессия — TF-aware upsertLiveCandle

**Контекст:** при смене ТФ на графике, живые тики от предыдущего WS-канала успевали попасть в store до отписки. Результат: «мигание» графика чужими свечами на 100–200ms.

**Что сделано:**
- **marketDataStore.ts:** расширена сигнатура `upsertLiveCandle(candle, sourceTf?)` — TF-aware guard: тики чужого TF отбрасываются; debug-лог в DEV-режиме
- **CandlestickChart.tsx:** извлечение TF из `wsChannel` (формат `market:{ticker}:{tf}`, 3-й сегмент), передача `channelTf` в `upsertLiveCandle`
- **marketDataStore.test.ts:** 3 новых теста — отброс чужого TF, приём своего, обратная совместимость

**Файлы:**
- `Develop/frontend/src/stores/marketDataStore.ts`
- `Develop/frontend/src/components/charts/CandlestickChart.tsx`
- `Develop/frontend/src/stores/__tests__/marketDataStore.test.ts`

**Тесты:** tsc 0 errors, vitest 229/229 passed (+3 новых), lint 0 новых.

**Stack Gotchas применённые:** Gotcha 16 (singleton WS race).

**Stack Gotchas новые:** нет.

**Результат:** ✅ все задачи реализованы. Контракт для трека 2: `upsertLiveCandle(candle, sourceTf?)` обратно совместим.

---

## 2026-04-17 — Трек 3: DEV-сессия — Sequential-index mode для intraday

**Контекст:** на TF < D (1m/5m/15m/1h/4h) ось времени линейная — нерабочие часы MOEX создают визуальные «дыры» на графике.

**Что сделано:**
- **sequentialIndex.ts:** (новый) утилитный модуль — конвертация candles → sequential indices, reverse mapping index→timestamp, форматирование MSK-времени, `isIntradayTimeframe()`
- **CandlestickChart.tsx:** prop `sequentialMode`, dual-mode data pipeline (UTCTimestamp / sequential index), custom `tickMarkFormatter` + `localization.timeFormatter`, crosshair с маппингом, live-update в sequential mode
- **ChartPage.tsx:** state `sequentialPref`, toggle-кнопка `IconChartDots`/`IconClock` (видна только для intraday), localStorage persist `sequentialTimeAxis`, автосброс в real-time для D/W/M
- **sequentialIndex.test.ts:** (новый) 9 vitest-тестов — конвертация с gap, reverse mapping, isIntraday, getCandleByIndex

**Файлы:**
- `Develop/frontend/src/components/charts/sequentialIndex.ts` (новый)
- `Develop/frontend/src/components/charts/__tests__/sequentialIndex.test.ts` (новый)
- `Develop/frontend/src/components/charts/CandlestickChart.tsx`
- `Develop/frontend/src/pages/ChartPage.tsx`

**Тесты (объединённый результат треков 3+5):** tsc 0 errors, vitest 238/238 passed (+12 суммарно), lint 1 pre-existing error (не от S5R-2).

**Stack Gotchas применённые:** Gotcha 16 (localStorage state + auth flow).

**Stack Gotchas новые:** нет.

**Результат:** ✅ все задачи реализованы. Переключатель в UI, crosshair показывает реальное MSK-время.

---

## 2026-04-17 — Фаза 3: подготовка промптов треков 1 и 2 (backend)

**Контекст:** фазы 1–2 завершены и закоммичены. Исследование backend-кода выявило, что `stream_manager.py` уже содержит `_AggregatingCandle` для live-агрегации (трек 2 — верификация, а не новая реализация).

**Решения пользователя:**
- Трек 1: warm cache в фоне (fire-and-forget), active + paused сессии
- Трек 2: верифицировать существующую агрегацию + тесты + фикс багов
- Оба трека параллельны

**Что сделано:**
- Исследованы backend-модули: `market_data/stream_manager.py`, `service.py`, `router.py`, `auth/router.py`, `trading/models.py`, `common/event_bus.py`, `broker/base.py`, `main.py`
- `PENDING_S5R2_track1_backend_prefetch.md` — обновлён с утверждённым решением
- `PENDING_S5R2_track2_live_aggregation.md` — обновлён: ключевое открытие (агрегация уже есть)
- `prompt_DEV-track1.md` — создан (11 секций по шаблону, 4 задачи, 4 теста)
- `prompt_DEV-track2.md` — создан (11 секций по шаблону, 6 задач, 12 тестов)

**Файлы:**
- `Спринты/Sprint_5_Review_2/prompt_DEV-track1.md` (новый)
- `Спринты/Sprint_5_Review_2/prompt_DEV-track2.md` (новый)
- `Спринты/Sprint_5_Review_2/PENDING_S5R2_track1_backend_prefetch.md` (обновлён)
- `Спринты/Sprint_5_Review_2/PENDING_S5R2_track2_live_aggregation.md` (обновлён)
- `Спринты/Sprint_5_Review_2/changelog.md` (эта запись)

**Результат:** ✅ промпты фазы 3 готовы к запуску в параллельных Claude-сессиях.

---

## 2026-04-17 — Трек 2: DEV-сессия — Верификация live-агрегации 1m->D/1h/4h

**Контекст:** `stream_manager.py` содержит `_candle_period_start()` и `_AggregatingCandle` для агрегации 1m-свечей в D/1h/4h. Тесты отсутствовали, end-to-end не проверялось.

**Что сделано:**
- Написаны 12 тестов (задачи 2.1-2.4): `_candle_period_start()` (5 TF), `_AggregatingCandle` (60m->1h, period transition, daily, dict format), timezone (Daily midnight vs MOEX, 4h блоки), event_bus integration
- Верификация timezone: Daily period = midnight UTC совпадает с T-Invest GetCandles API (gotcha-15 учтена)
- Баги не обнаружены, production-код **не модифицирован**
- Integration Verification Checklist пройден (4/4 пункта)

**Файлы:**
- `Develop/backend/tests/test_market_data/__init__.py` (новый)
- `Develop/backend/tests/test_market_data/test_stream_aggregation.py` (новый, 12 тестов)
- `Спринты/Sprint_5_Review_2/reports/DEV-track2_report.md` (новый)

**Тесты:** pytest tests/test_market_data/ 12/12 passed, pytest tests/ 619/619 passed (baseline 607 + 12 новых), ruff: 0 новых errors.

**Stack Gotchas применённые:** gotcha-15 (naive datetime UTC-offset), gotcha-04 (T-Invest stream reconnect).

**Stack Gotchas новые:** нет.

**Результат:** ✅ агрегация верифицирована, багов не обнаружено. Контракт WS-сообщений с derived-TF подтверждён.

---

## 2026-04-17 — Трек 1: DEV-сессия — Backend prefetch свечей при логине

**Контекст:** при логине frontend постепенно догружает свечи через REST по мере открытия инструментов. Для активных торговых сессий это означает паузу «график пустой -> заполняется». Решение: backend при логине в фоне прогревает ohlcv_cache для тикеров активных/приостановленных сессий.

**Что сделано:**
- **1.1 prefetch.py** (новый): `prefetch_active_sessions(user_id, db_factory)` — фоновый прогрев кеша. JOIN через StrategyVersion -> Strategy для резолва user_id (TradingSession не хранит user_id). Дедупликация (ticker, timeframe). Semaphore(3) для T-Invest rate limits. Fallback timeframe="D" для NULL. Двухуровневая обработка ошибок.
- **1.2 auth/router.py**: fire-and-forget `asyncio.create_task(prefetch_active_sessions(...))` после успешного login. user_id извлекается из JWT access_token. Ошибка prefetch НЕ блокирует login.
- **1.3 test_prefetch.py** (новый): 4 теста — warms_cache (2 сессии active+paused), skips_stopped, handles_errors (ConnectionError не пробрасывается), null_timeframe (fallback на "D").
- **1.4 Stack Gotcha**: новых ловушек не обнаружено, применены gotcha-04, gotcha-15, gotcha-08.

**Файлы:**
- `Develop/backend/app/market_data/prefetch.py` (новый)
- `Develop/backend/app/auth/router.py` (изменён: +asyncio, +structlog, +prefetch блок)
- `Develop/backend/tests/test_market_data/__init__.py` (новый)
- `Develop/backend/tests/test_market_data/test_prefetch.py` (новый, 4 теста)
- `Спринты/Sprint_5_Review_2/reports/DEV-track1_report.md` (новый)

**Тесты:** pytest tests/test_market_data/test_prefetch.py 4/4 passed, pytest tests/ 623/623 passed (baseline 607 + 16), ruff: 0 новых errors.

**Stack Gotchas применённые:** gotcha-04 (Semaphore 3), gotcha-15 (aware UTC datetime), gotcha-08 (db_factory, не живая сессия).

**Stack Gotchas новые:** нет.

**Результат:** ✅ задачи 1.1-1.4 реализованы. Integration verification пройдена.

---

## Шаблон для будущих записей

```
## YYYY-MM-DD — Трек N: <название>

**Контекст:** ...
**Что сделано:**
- ...
**Файлы:** ...
**Тесты:** ...
**Stack Gotchas применённые:** ...
**Stack Gotchas новые:** `gotcha-NN-*.md` (если есть)
**Результат:** ✅/⚠️/❌
```
