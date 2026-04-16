# [Sprint_5_Review_2] Трек 4 — 401 Unauthorized после релогина

> **Источник:** ручной тест 2026-04-15. Сценарий воспроизводится **неконсистентно**.
> **Приоритет:** 🔴 UX-блокер (пользователь вынужден перезагружать страницу).
> **Статус:** 🔄 План детализирован 2026-04-16 на основе изучения реального кода frontend. Диагностика — первый шаг DEV-сессии.

## Контекст

Сценарий: пользователь `logout` → `login` → открывает `ChartPage` / `BacktestPage` → запросы свечей (`GET /api/v1/market-data/candles`) возвращают `401 Unauthorized`. Иногда проходит без ошибок, иногда стабильно 401 до полной перезагрузки вкладки (`window.location.reload()`).

Архитектура auth/данных во frontend (по состоянию на 2026-04-16):

- **Auth store:** Zustand + `persist`-middleware (localStorage, ключ `auth-storage`) — `Develop/frontend/src/stores/authStore.ts:1-30`. Поля: `token`, `refreshToken`, `user`. Actions: `login`, `logout` (очищает три поля), `setToken` (вызывается refresh-interceptor). **Нет `expiryTime`, нет side-effect cleanup при `logout`.**
- **API client:** axios в `Develop/frontend/src/api/client.ts`. Request interceptor (строки 14–29) берёт `token` синхронно через `useAuthStore.getState().token` **в момент отправки запроса**. Response interceptor на 401 (строки 56–95) пробует refresh через `doRefresh()`, на неудаче — `logout()` + `window.location.href = '/login'` (hard-reload).
- **Market-data store:** `Develop/frontend/src/stores/marketDataStore.ts` — кеширует свечи в in-memory `candlesCache` + localStorage (TTL 24h). **Нет подписки на authStore, нет cleanup при logout.**
- **ChartPage:** `Develop/frontend/src/pages/ChartPage.tsx:103-110` — `useEffect` при открытии вызывает `setTicker(ticker)` (подставляет cached candles) → `fetchInstrumentInfo(ticker)` → `setTimeout(() => fetchCandles(), 0)`.
- **WebSocket:** `Develop/frontend/src/hooks/useWebSocket.ts:20-24` — singleton WS, токен в URL `?token=${token}` через `getWsUrl()`. При `logout()` соединение **не закрывается автоматически**, reconnect использует свежий token только если `subscriptions.size > 0`.

## Корень проблемы (гипотезы)

Диагностический отчёт выявил **3 кандидата на root cause**, порядок — от наиболее к наименее вероятному. Все требуют подтверждения в DEV-сессии через логи сети/консоли:

1. **Request interceptor race** (`client.ts:14-29`) — interceptor вычитывает `token` из store синхронно при каждом запросе. Если `fetchCandles()` стартовал **до** того, как `login()` обновил store, в заголовок попадает `undefined` или старый token из persist.
2. **localStorage persist vs in-memory state** — persist-middleware восстанавливает старый `token` при hydrate на «чистом» открытии вкладки, но между `logout` и `login` новый `token` приходит в store через pending-промис `login()`. Окно рассинхронизации: hydrate успел вернуть старое, `login()` ещё не дошёл до `setToken`.
3. **Отсутствие cleanup pending-запросов при 401→refresh→retry** — `client.ts` retry'ит только один запрос, который поймал 401. Но запросы, вставшие в очередь между logout и login (ChartPage → fetchCandles), уходят со старым/пустым token и 401-reply обрабатывается индивидуально; при этом `marketDataStore` не инвалидирует cache и не триггерит `mutate`.

Побочные наблюдения (не root cause, но смежные):
- `marketDataStore.candlesCache` (localStorage) сохраняется после logout — чужой пользователь после релогина увидит чужие тикеры (отдельный security-nit).
- WebSocket не пересоздаётся на logout → активный stream на старом токене до первого `onclose`.

## План диагностики (ДО написания фикса)

1. **Воспроизведение локально** — Chrome DevTools Network + Console. Логин пользователем `sergopipo` (креды — `user_test_credentials.md`), открыть `ChartPage` → `logout` через меню → `login` повторно → открыть `ChartPage` того же тикера.
2. **Зафиксировать 401-запрос** — скопировать заголовок `Authorization` из failed-запроса. Сравнить с `useAuthStore.getState().token` в консоли **в момент 401**.
3. **Проверить timing** — добавить `console.debug` в: `authStore.login` (`[auth] login set token`), `client.ts` request interceptor (`[api] send ${url} token=${token?.slice(0,8)}`), `marketDataStore.fetchCandles` (`[md] fetch start`). Собрать трассу и найти окно рассинхронизации.
4. **Проверить localStorage** — `localStorage.getItem('auth-storage')` сразу после logout и сразу после login. Должно ли persist очищаться синхронно?
5. **Backend-side** — достать из backend-логов JWT упавшего 401-запроса, декодировать (`jwt.io`). Старый токен или новый невалидный?
6. **Воспроизведение у другого пользователя / вкладки в incognito** — нужна ли persist-коллизия или проблема повторяется на чистом старте.
7. Root cause зафиксировать в этом файле → перейти к решению.

## Предлагаемое решение (post-diagnose)

Выбор применяется после шага 7 диагностики. Варианты (один или комбинация):

1. **Cleanup hook в `authStore.logout`** — при logout: `localStorage.removeItem('auth-storage')` **синхронно**, закрыть WS (`closeWS()`), сбросить `marketDataStore` (`clearCandlesCache()`), abort всех inflight через общий `AbortController`.
2. **Subscribe-паттерн** — `marketDataStore` + `useWebSocket` подписываются на `authStore` через `useAuthStore.subscribe((s, prev) => { if (prev.token && !s.token) cleanup(); })`. Cleanup = инвалидация кеша + отписка WS.
3. **Interceptor guard** — в `client.ts` request interceptor: если `!token`, отбросить запрос с `return Promise.reject(new AxiosError('no token', 'ECANCELED'))` вместо отправки без Authorization. Предотвращает race-запросы во время релогина.
4. **ChartPage defer** — `useEffect` ждёт `useAuthStore(s => s.token)` как зависимость, не стреляет `fetchCandles` пока токена нет. Убирает `setTimeout(…, 0)`.

Рекомендация по результатам диагностики — минимальный набор, закрывающий подтверждённую гипотезу, без over-engineering.

## Затрагиваемые файлы

- `Develop/frontend/src/stores/authStore.ts` — logout cleanup hook
- `Develop/frontend/src/api/client.ts` — опционально guard в request interceptor
- `Develop/frontend/src/stores/marketDataStore.ts` — subscribe на authStore, cleanup
- `Develop/frontend/src/hooks/useWebSocket.ts` — `closeWS()` на logout
- `Develop/frontend/src/pages/ChartPage.tsx` — убрать `setTimeout(…, 0)`, сделать зависимость от token
- `Develop/frontend/e2e/auth.spec.ts` — новый E2E-сценарий «logout → login → ChartPage → нет 401»
- `Develop/frontend/src/stores/__tests__/authStore.test.ts` — vitest на logout cleanup
- (возможно) `Develop/backend/app/auth/dependencies.py` — если backend-сторонняя session-invalidation понадобится

## Критерии готовности

- [ ] Root cause задокументирован в этом файле — одна из 3 гипотез подтверждена (или новая с обоснованием)
- [ ] Фикс применён. Повтор сценария `logout → login → ChartPage` 20 раз подряд в Chrome → 0 × 401
- [ ] То же в incognito (без persist) — 0 × 401
- [ ] Новый E2E-тест Playwright `auth.spec.ts`: `logout → login → open ChartPage для тикера SBER → свечи отрисованы, 0 запросов с 401`
- [ ] Новый vitest-тест на `authStore.logout` cleanup: после logout `marketDataStore.candlesCache` пуст, WS `closeWS()` вызван, localStorage `auth-storage` очищен
- [ ] Stack Gotcha — **обязательно** `Develop/stack_gotchas/gotcha-16-relogin-race.md` (или следующий номер) + строка в `INDEX.md`. Гонка persist/in-memory/inflight-requests — классика, стоит отдельной записи
- [ ] CI зелёный на ветке фикса
- [ ] Регрессия не сломала happy-path login (без logout) — существующие тесты `auth.spec.ts` passed

## Риски

- Агрессивный `localStorage.removeItem` на logout может сломать сценарий «запомнить меня» если когда-то добавим — тогда чистить только `token`/`refreshToken`, не весь store.
- `AbortController` на inflight запросах может обрушить корректные in-flight запросы в момент logout (сообщения пользователю типа «network error»). Мягко подавлять ECANCELED в error-reporting.
- Если гипотеза 2 (persist vs in-memory) подтвердится, решение может потребовать отказа от persist для `token` (только session-storage или только in-memory) — это архитектурное решение, согласовать с пользователем.
- Баг может проявляться только в Dev-сборке / только в prod-сборке — проверить в обеих.

## Оценка

- Диагностика: 0.5–1 сессия (6 шагов плана, основная трата — воспроизведение + сбор трасс).
- Фикс + тесты: 0.5–1 сессия в зависимости от выбранного варианта.
- Итого: **1–2 DEV-сессии**, один промпт по `prompt_template.md`.

## Открытые вопросы к пользователю

- На каком браузере / ОС воспроизводится? (в отчёте — DevTools Chrome, но у пользователя мог быть Safari / Firefox)
- Есть ли видео / HAR-файл сессии с ошибкой? (если да — ускорит шаг 1 диагностики)
- Повторяется ли сценарий при login **другим** пользователем после logout? (не тем же)
- Persist для `token` в localStorage — требование или можно переключить на sessionStorage / in-memory? (влияет на выбор решения 1)
- Нужен ли backend-side session invalidate (JWT blacklist на logout) или достаточно frontend-only?
