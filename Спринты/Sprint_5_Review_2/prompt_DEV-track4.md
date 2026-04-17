---
sprint: S5R-2
agent: DEV-track4
role: "Frontend Diagnostics + Fix — 401 Unauthorized после релогина"
wave: 1
depends_on: []
---

# Роль

Ты — Frontend-разработчик (senior), специалист по диагностике auth-race-conditions. Твоя задача: найти root-cause бага «401 Unauthorized после logout → login» и устранить его через cleanup-хуки + guard в interceptor. Работаешь в `Develop/frontend/`.

Баг неконсистентный: воспроизводится в Safari, в Chrome воспроизведён не был. HAR-записи (Chrome + Safari) не содержат 401 — баг не сработал при записи. Поэтому стратегия: **превентивный фикс** объективных проблем в коде (отсутствие cleanup при logout, отсутствие guard в interceptor) + **диагностическая трассировка** для отлова бага при следующем проявлении.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Node >= 18, pnpm >= 9
2. Зависимости предыдущих DEV: нет (трек 4 — первый в S5R-2)
3. Существующие файлы:
   - Develop/frontend/src/stores/authStore.ts
   - Develop/frontend/src/api/client.ts
   - Develop/frontend/src/stores/marketDataStore.ts
   - Develop/frontend/src/hooks/useWebSocket.ts
   - Develop/frontend/src/pages/ChartPage.tsx
   - Develop/frontend/e2e/auth.spec.ts
4. База данных: backend запущен, /auth/login возвращает 200
5. Внешние сервисы: нет
6. Тесты baseline: `pnpm lint` → 0 errors, `pnpm tsc --noEmit` → 0 errors,
   `pnpm test` → 0 failures, `npx playwright test` → 109+ passed
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — ищи gotcha по слоям: `Auth`, `Zustand`, `Axios`, `WebSocket`. Если есть gotcha-15 (T-Invest naive→aware) — учти при работе с tokenами (timezone-зависимость `exp`).

3. **`Спринты/Sprint_5_Review_2/execution_order.md`** раздел «Cross-DEV contracts» — трек 4 не имеет зависимостей, но читай ради контекста.

4. **`Спринты/Sprint_5_Review_2/PENDING_S5R2_track4_401_unauthorized.md`** — полный план с 3 гипотезами root-cause, 7-шаговым планом диагностики, 4 вариантами решения. **Решение пользователя:** localStorage + cleanup-хуки (не менять хранилище, фиксить через cleanup).

5. **Цитаты из кода (по состоянию на 2026-04-16):**

   > **authStore.ts** (Zustand + persist):
   > - `persist`-middleware с ключом `auth-storage` в localStorage.
   > - `logout()` очищает `token`, `refreshToken`, `user` — но **нет side-effect cleanup** (нет закрытия WS, нет очистки candlesCache, нет abort inflight запросов).

   > **client.ts** (axios interceptor):
   > - Request interceptor (строки 14–29): `const token = useAuthStore.getState().token;` — синхронно в момент запроса. Если token ещё не обновлён после login → улетает пустой/старый.
   > - Response interceptor (строки 56–95): на 401 → `doRefresh()` → retry. При неудаче → `logout()` + `window.location.href = '/login'` (hard reload). **Нет guard'а** на `!token` (пропускает запрос без Authorization).

   > **marketDataStore.ts**:
   > - `candlesCache` в localStorage (TTL 24h) + in-memory.
   > - **Нет подписки на authStore**, нет cleanup при logout.

   > **useWebSocket.ts** (строки 20–24):
   > - `getWsUrl()`: token в URL `?token=${token}` через `useAuthStore.getState().token`.
   > - Singleton WS, **не закрывается при logout**.
   > - `connectWS()` проверяет `if (!token) return;` — только при явном вызове, не при reconnect.

   > **ChartPage.tsx** (строки 103–110):
   > - `useEffect` → `setTicker(ticker)` → `setTimeout(() => fetchCandles(), 0)`.
   > - **Нет зависимости от token** — стреляет fetchCandles сразу, даже если token ещё не обновлён.

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

```
- src/stores/authStore.ts          — Zustand auth store, persist middleware. Расширяем logout().
- src/api/client.ts                — Axios instance + interceptors. Добавляем guard.
- src/stores/marketDataStore.ts    — Zustand store для свечей, candlesCache. Добавляем cleanup.
- src/hooks/useWebSocket.ts        — Singleton WS client. Добавляем closeWS при logout.
- src/pages/ChartPage.tsx          — График инструмента. Добавляем зависимость от token.
- e2e/auth.spec.ts                 — E2E тесты auth flow. Добавляем logout→login→chart сценарий.
```

# Задачи

## Задача 4.1: Diagnostic tracing (console.debug)

Добавить временную трассировку для отлова бага при следующем проявлении.

В **`authStore.ts`**:
```typescript
// В actions login() и logout() — после изменения state:
if (import.meta.env.DEV) {
  console.debug('[auth] login — token set:', token?.slice(0, 12) + '...');
  // или
  console.debug('[auth] logout — token cleared');
}
```

В **`client.ts`** request interceptor:
```typescript
if (import.meta.env.DEV) {
  console.debug(`[api] ${config.method?.toUpperCase()} ${config.url} token=${token ? token.slice(0, 12) + '...' : 'NONE'}`);
}
```

В **`client.ts`** response interceptor при 401:
```typescript
if (import.meta.env.DEV) {
  console.debug('[api] 401 received', {
    url: originalRequest.url,
    hadToken: !!originalRequest.headers?.Authorization,
    storeToken: useAuthStore.getState().token?.slice(0, 12),
  });
}
```

> **Примечание:** все трассировки — только в `import.meta.env.DEV`, не попадают в production build.

## Задача 4.2: Cleanup hook в authStore.logout()

**Это основной превентивный фикс.** Расширить `logout()` в `authStore.ts`:

1. **Закрыть WebSocket:** вызвать `closeWS()` из `useWebSocket.ts` (экспортировать функцию, если ещё не экспортирована).
2. **Очистить candlesCache:** вызвать `clearCandlesCache()` из `marketDataStore.ts` (создать метод, если нет — очистить `candlesCache` из in-memory и `localStorage.removeItem('candles-cache')` или аналогичный ключ).
3. **Abort inflight запросов:** создать глобальный `AbortController` в `client.ts`, который abort'ится при logout и пересоздаётся при login. Подавить `ECANCELED` ошибки в error-reporting.
4. **Очистить persist синхронно:** после очистки полей state — `localStorage.removeItem('auth-storage')` (форсируем синхронное удаление, не ждём persist-middleware).

Порядок в `logout()`:
```
1. closeWS()                          — закрыть соединение
2. abortController.abort()            — прервать inflight
3. set({ token: null, refreshToken: null, user: null })  — очистить state
4. localStorage.removeItem('auth-storage')               — форс-очистка persist
5. clearCandlesCache()                                   — очистить market data
```

## Задача 4.3: Guard в request interceptor (client.ts)

Добавить guard в request interceptor: если `!token` и URL — не `/auth/*` → отбросить запрос:

```typescript
const token = useAuthStore.getState().token;
if (!token && !config.url?.startsWith('/auth/')) {
  return Promise.reject(new axios.AxiosError(
    'No auth token — request blocked',
    'ECANCELED',
    config
  ));
}
```

Это предотвращает отправку запросов без Authorization в окне рассинхронизации logout→login.

## Задача 4.4: ChartPage — зависимость от token

Изменить `useEffect` в `ChartPage.tsx` так, чтобы `fetchCandles()` не вызывался при отсутствии token:

```typescript
const token = useAuthStore((s) => s.token);

useEffect(() => {
  if (!ticker || !token) return;
  setTicker(ticker);
  fetchInstrumentInfo(ticker);
  fetchCandles();
}, [ticker, token]);
```

Убрать `setTimeout(() => fetchCandles(), 0)` — он был костылём для race, теперь `token` в зависимостях гарантирует правильный порядок.

## Задача 4.5: E2E тест — logout → login → chart

Добавить в `e2e/auth.spec.ts` новый сценарий:

```typescript
test('logout → login → chart loads without 401', async ({ page }) => {
  // 1. Login
  await page.goto('/login');
  await page.fill('[placeholder="username"]', 'sergopipo');
  await page.fill('[placeholder="••••••••"]', process.env.TEST_PASSWORD!);
  await page.click('button:has-text("Войти")');
  await page.waitForURL('/');

  // 2. Open chart
  await page.goto('/chart/SBER');
  await page.waitForSelector('canvas', { timeout: 10000 });

  // 3. Logout
  // ... navigate to logout (sidebar / menu)

  // 4. Login again
  await page.goto('/login');
  await page.fill('[placeholder="username"]', 'sergopipo');
  await page.fill('[placeholder="••••••••"]', process.env.TEST_PASSWORD!);
  await page.click('button:has-text("Войти")');
  await page.waitForURL('/');

  // 5. Open chart again — no 401
  await page.goto('/chart/SBER');
  await page.waitForSelector('canvas', { timeout: 10000 });

  // 6. Verify no 401 in console errors
  const errors: string[] = [];
  page.on('response', (resp) => {
    if (resp.status() === 401) errors.push(resp.url());
  });
  await page.waitForTimeout(3000);
  expect(errors).toHaveLength(0);
});
```

> **Примечание:** пароль берётся из `process.env.TEST_PASSWORD` — не хардкодить. Если E2E запускаются на моках — mock login endpoint.

## Задача 4.6: Stack Gotcha — `gotcha-16-relogin-race.md`

Создать `Develop/stack_gotchas/gotcha-16-relogin-race.md`:

```markdown
# Gotcha 16: Logout → Login race (Zustand persist + Axios interceptor)

## Симптом
401 Unauthorized на запросы свечей / WS после logout → login. Неконсистентный.

## Причина
Zustand persist + localStorage обновляется асинхронно. Между logout() и login()
запросы, инициированные компонентами (useEffect), могут уйти с пустым/старым token.
WebSocket не закрывается при logout. candlesCache хранит данные предыдущей сессии.

## Правило
logout() ОБЯЗАН: closeWS(), abort inflight, очистить state, форс-очистить localStorage,
очистить candlesCache. Request interceptor ОБЯЗАН блокировать запросы без token
(кроме /auth/*). Компоненты (ChartPage) ОБЯЗАНЫ зависеть от token в useEffect deps.

## Related files
- src/stores/authStore.ts
- src/api/client.ts
- src/stores/marketDataStore.ts
- src/hooks/useWebSocket.ts
- src/pages/ChartPage.tsx
```

Добавить строку в `Develop/stack_gotchas/INDEX.md`:

| 16 | Auth/Zustand/Axios | 401 после logout→login (race) | gotcha-16-relogin-race.md |

# Опциональные задачи

- **4.7 (опциональная):** Повторить сценарий logout→login 10 раз в Safari Web Inspector с открытой Console. Зафиксировать: воспроизвёлся ли 401 после фикса, что показала трассировка из задачи 4.1.
  - PASS — если выполнено, результат в отчёте.
  - SKIP — если Safari недоступен DEV-агенту, reason: «нет доступа к Safari GUI».

# Тесты

```
Develop/frontend/
├── src/stores/__tests__/
│   └── authStore.test.ts           # Vitest: logout cleanup (WS closed, cache cleared, localStorage removed)
├── src/api/__tests__/
│   └── client.test.ts              # Vitest: guard блокирует запрос без token, пропускает /auth/*
├── e2e/
│   └── auth.spec.ts                # Playwright: logout→login→chart (задача 4.5)
```

**Минимум:**
- Vitest: 3+ тестов (logout cleanup, interceptor guard, ChartPage token dependency)
- Playwright: 1 новый E2E (logout→login→chart)

**Фикстуры:** если есть `vi.mock` для `useWebSocket` / `marketDataStore` — использовать их.

# ⚠️ Integration Verification Checklist

- [ ] **cleanup hook подключён:** `authStore.logout()` вызывает `closeWS()` — `grep -rn "closeWS" src/stores/authStore.ts` → найдено
- [ ] **cleanup hook подключён:** `authStore.logout()` вызывает `clearCandlesCache()` — `grep -rn "clearCandlesCache" src/stores/authStore.ts` → найдено
- [ ] **guard подключён:** `client.ts` request interceptor содержит `if (!token` — `grep -rn "!token" src/api/client.ts` → найдено
- [ ] **ChartPage зависит от token:** `useEffect` deps содержат `token` — `grep -rn "token" src/pages/ChartPage.tsx` → найдено в useEffect deps
- [ ] **E2E тест запускается:** `npx playwright test auth.spec.ts` → включает новый сценарий, passed
- [ ] **Stack Gotcha создан:** `ls Develop/stack_gotchas/gotcha-16-relogin-race.md` → найдено
- [ ] **INDEX.md обновлён:** `grep "16" Develop/stack_gotchas/INDEX.md` → найдено

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.

Сохрани отчёт как файл: `Спринты/Sprint_5_Review_2/reports/DEV-track4_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 4.1–4.6 реализованы
- [ ] Опциональная задача 4.7 — PASS или SKIP + reason
- [ ] `pnpm lint` → 0 errors
- [ ] `pnpm tsc --noEmit` → 0 errors
- [ ] `pnpm test` → 0 failures
- [ ] `npx playwright test auth.spec.ts` → 0 failures (включая новый сценарий)
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_5_Review_2/reports/DEV-track4_report.md`
- [ ] **Stack Gotcha 16 создан** + INDEX.md обновлён
- [ ] Диагностическая трассировка (задача 4.1) присутствует и видна в консоли при DEV-режиме
