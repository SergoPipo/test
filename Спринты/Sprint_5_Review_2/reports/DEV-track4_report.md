# DEV-track4 Report: 401 Unauthorized после релогина

**Sprint:** S5R-2 | **Agent:** DEV-track4 | **Date:** 2026-04-17

---

## 1. Реализовано

Превентивный фикс 401-race при logout → login: cleanup-хуки в `authStore.logout()`, guard в axios request interceptor, зависимость ChartPage от token, диагностическая трассировка (DEV-only). E2E сценарий logout→login→chart. Stack Gotcha 16.

## 2. Файлы (изменённые / созданные)

| Файл | Действие |
|---|---|
| `src/stores/authStore.ts` | Изменён — cleanup hook в logout(), tracing в login()/logout() |
| `src/api/client.ts` | Изменён — AbortController, guard `!token`, tracing, ECANCELED suppress |
| `src/stores/marketDataStore.ts` | Изменён — экспорт `clearCandlesCache()` |
| `src/hooks/useWebSocket.ts` | Изменён — экспорт `closeWS()` |
| `src/pages/ChartPage.tsx` | Изменён — `token` в useEffect deps, убран `setTimeout` |
| `e2e/auth.spec.ts` | Изменён — новый E2E сценарий |
| `src/stores/__tests__/authStore.test.ts` | Переписан — 10 тестов (включая cleanup order) |
| `src/api/__tests__/client.test.ts` | Создан — 3 теста (guard) |
| `stack_gotchas/gotcha-16-relogin-race.md` | Создан |
| `stack_gotchas/INDEX.md` | Изменён — строка 16 |

## 3. Тесты

- **tsc --noEmit:** 0 errors
- **Vitest:** 226 passed / 0 failed (47 файлов), включая 13 новых тестов
- **Lint:** 0 новых errors (1 pre-existing warning в ChartPage WS effect — `setWsChannel(null)` в effect body, не связан с треком 4)
- **E2E:** сценарий `logout → login → chart loads without 401` написан (требует запущенный backend для исполнения)

## 4. Integration Points

- `authStore.logout()` → `closeWS()` (useWebSocket.ts) — подтверждено grep
- `authStore.logout()` → `clearCandlesCache()` (marketDataStore.ts) — подтверждено grep
- `authStore.logout()` → `abortAllInflight()` (client.ts) — подтверждено grep
- `authStore.login()` → `renewAbortController()` (client.ts) — подтверждено grep
- `client.ts` request interceptor → guard `!token` → ECANCELED — подтверждено grep
- `ChartPage.tsx` useEffect deps включают `token` — подтверждено grep

## 5. Контракты

Трек 4 не имеет cross-DEV контрактов (первый трек S5R-2, frontend-only).

## 6. Проблемы

- **Pre-existing lint error:** `ChartPage.tsx:89` — `setWsChannel(null)` вызывается синхронно в body effect. Это код из S5R wave 4 (фаза 3.5, race-guard WS subscription). Не блокирует, не связан с треком 4.
- **4.7 (Safari GUI):** SKIP — нет доступа к Safari GUI из CLI-агента. Reason: DEV-агент работает в терминале без GUI.

## 7. Применённые Stack Gotchas

Нет — трек 4 представляет новый класс проблемы (auth race), ранее не зафиксированный.

## 8. Новые Stack Gotchas

**Gotcha 16: Logout → Login race (Zustand persist + Axios interceptor)**
- Симптом: 401 на запросы после logout → login (неконсистентный, чаще в Safari)
- Причина: отсутствие cleanup при logout (WS, cache, inflight) + guard + defer
- Файл: `stack_gotchas/gotcha-16-relogin-race.md`, INDEX.md обновлён
