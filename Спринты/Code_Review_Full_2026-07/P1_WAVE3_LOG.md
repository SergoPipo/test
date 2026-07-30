# Лог P1 — Волна 3 (frontend: security / network / charts / backtest-ui / core-refactor / ui-misc)

**Дата:** 2026-07-07
**Ветка:** `p1/wave3-frontend` (Develop/, база — `p1/wave2-backend @ 9cd44aa`; remote `s8r/bug-31` НЕ тронут — волна на отдельной ветке для финального сведения).
**Модель фиксов:** Opus 4.8 (DEV-агенты, + оркестрация после исчерпания лимита Fable 5 на фазе ревью). Строго test-first (Red→Green→Refactor).
**Метод:** 6 DEV-агентов в изолированных git-worktree'ах (base = `9cd44aa`, симлинки `node_modules`/`.venv` — их в worktree нет, gitignored) → integration-мерж (clean, без конфликтов) → полный gate → `/code-review` (xhigh, 10→5 углов + верификация) по WS-security/рефакторам/критпутям → отдельный test-first раунд фиксов найденных дефектов + повторный gate.

## Реализовано (по веткам)

| Ветка | Пункты | Тесты (в worktree) |
|---|---|---|
| `fix/fe-security` | **CFG-FE-02 + FE-NET-01 + FE-STOR-12** (единый WS-кластер: JWT из query-string → auth-handshake первым сообщением `{action:'auth',token}`→`auth_ok`, общий хелпер `wsAuth.ts`, backend `ws.py`, nginx `access_log off` для `/ws/`), **FE-STOR-13** (убран срез токена из `console.debug`) | 639 passed + backend 394 |
| `fix/fe-network` | **FE-NET-03** (нормализатор Decimal-строк на границе `backtestApi`), **FE-NET-04** (exponential backoff reconnect WS фоновых бэктестов) | 642 passed |
| `fix/fe-charts` | **FE-CHART-01** (vline в sequential mode: `pointToX` + сохранение `logical`), **FE-CHART-02** (рефактор `CandlestickChart` 907→702: `useTradeMarkers`/`useChartLiveData`), **FE-CHART-03** (единый `utils/mskTime.ts`) | 653 passed |
| `fix/fe-backtest-ui` | **FE-BTST-13** (id-guard автонавигации), **FE-BTST-14** (cleanup подписки), **FE-BTST-15** (rAF-гейт видимости `visibleRafLoop`), **FE-BTST-16** (cap бакетов гистограммы) | 641 passed |
| `fix/fe-core-refactor` | **FE-PAGE-01** (рефактор `StrategyEditPage` 1101→783: `useStrategyBlocks`/`useStrategySave`/`StrategyBacktestsTable`), **FE-PAGE-02** (`Promise.allSettled` при массовом delete), **FE-CORE-01** (break-fix `computeChartZones`), **FE-CORE-02/06** (`formatDate`→`parseBackendDate`), **FE-CORE-07** (`React.lazy` 8 страниц), **FE-CORE-08** (`useRequireAuth`) | 672 passed |
| `fix/fe-ui-misc` | **FE-STRAT-01** (allow-list типов блоков: фронт `workspaceLoadValidation.ts` + backend `block_allowlist.py`→422 + IDOR-тесты), **FE-TRAD-01** (race-guard `tradingStore`), **FE-TRAD-02** (backend `SessionResponse` Z-суффикс + фронт `parseBackendDate`), **FE-UI-01** (deadline-таймеры `CriticalBanner`) | 648 passed + backend 613 |

**Дубли CFG-FE-01 (не делались — вынесены в auth-мини-волну решением заказчика):** FE-NET-02 и FE-PAGE-03 = тот же `authStore.ts:145` (токены localStorage→HttpOnly cookie). Модель хранения нельзя менять «наполовину» → `P1_AUTH_HARDENING_HANDOFF.md`.

## Интеграционный мерж

6 веток слились в `p1/wave3-frontend` **без конфликтов**. Ожидавшиеся хэндоффом ручные конфликты по `useWebSocket.ts`/`authStore.ts` (fe-security ∩ fe-network) не возникли — WS-кластер был объединён в одну ветку `fe-security`, а fe-network не трогал эти файлы.

**Гейт мержа:** vitest **740 passed / 106 files / 0 failed** (+109 к baseline 631), tsc `--noEmit` **0 errors**, backend pytest **2152 passed, 2 xfailed** (2 «failed» — worktree-артефакт: `test_backup_cli` форкает подпроцесс без `.env` → `config.check_production_secrets` fail-closed на dev-`SECRET_KEY` при `DEBUG=False`; на живой копии с `.env` — 3 passed. Не регрессия волны 3).

## `/code-review` (xhigh, 5 углов Opus + верификация)

Первый запуск (10 углов Fable 5) исчерпал лимит модели → перезапуск консолидированно на **5 углах Opus 4.8**: WS-security корректность / нейтральность рефакторов / корректность прочих фиксов / cross-file+removed-behavior / cleanup+altitude+conventions. **Найдено 6 реальных дефектов в свежих фиксах** (как в Волнах 1/2) — исправлены test-first (коммит `0e039be`):

### WS-auth контракт (3 угла независимо) — главный
Мультиплексор `/ws` закрывал auth-fail кодом **4001 без `{type:'auth_error'}`** → фронт-ветка `isAuthError` мёртвая, `onclose` не смотрел код → **бесконечный reconnect-шторм** (≤30с) на протухшем токене (соседние WS-хуки корректно стопаются на 4401/4403). Комментарий в `ws.py` сам это признавал. Унифицировано:
- `ws.py`: `_WS_AUTH_FAIL` 4001 → **4401** (как `ws_backtest.py`/`ws_sessions.py`), таймаут 5с → **10с** (консистентность), guard бинарного первого кадра (`receive_text()` кидает `RuntimeError`/`KeyError` на bytes → close 4401, не падение хендлера).
- `useWebSocket.ts` `onclose(event)`: при **4401/4403 не планировать reconnect** (паттерн `useBacktestJobWS`/`useTradingSessionsWS`).
- `e2e/fixtures/api_mocks.ts`: `mockWSChannel` отвечает `{type:'auth_ok'}` на handshake — иначе после миграции клиент `wsAuthed=false` и **молча дропает все fixture frames** (e2e маскировали бы фичи).

### visibleRafLoop (2 угла)
Цикл возобновлялся только по `visibilitychange` (document.hidden), но засыпал и по нулевому размеру контейнера (`display:none` на неактивной Mantine-вкладке) → при возврате CSS-видимости без смены вкладки браузера **не просыпался никогда** (латентно: Mantine по умолчанию размонтирует панель, проявится при `keepMounted`). → добавлен **ResizeObserver** (пробуждение при 0→>0), инъекция `makeResizeObserver` для тестов.

### StrategyBacktestsTable (2 угла)
Новый извлечённый компонент рендерил `created_at` сырым `new Date(...).toLocaleDateString` вместо `formatDate`/`parseBackendDate` → **сдвиг дня near-midnight-UTC** (реинтродукция BUG-3/4, ровно того, что FE-CORE-02/06 фиксил в этой же волне). → `formatDate`.

### backtestStore.fetchBacktest (1 угол, altitude)
`currentBacktest` — единственный слот; `fetchBacktest` без guard → поздний ответ бэктеста A перетирал открытый B (тот же класс, что FE-TRAD-01, но в соседнем сторе). → **request-token guard** (`latestBacktestRequestId`).

**Верификация фиксов (Red→Green):** +5 vitest (visibleRafLoop resize, useWebSocket 4401/1006, StrategyBacktestsTable date, backtestStore race) + 1 backend (binary-frame 4401) + усилены ассерты кода закрытия в `test_ws_authz`.

## Верификация (объединённый результат после фиксов)

- **vitest** (весь фронт): **745 passed / 107 files / 0 failed** (baseline 631 → +114).
- **tsc `--noEmit`**: **0 errors**.
- **backend pytest** (backtest+trading+strategy — затронутые волной модули): **860 passed, 2 xfailed, 0 failed** (полный сьют на мерже — 2152 passed при живом `.env`).

## Прочищено ревью (проверено, дефектов нет)

Нейтральность рефакторов StrategyEditPage/CandlestickChart (Gotcha 35 сохранена — две сериализации Blockly раздельны; deps/cleanup/порядок BUG-28 на месте; React.lazy-экспорты корректны); `normalizeBacktest` без двойной нормализации; `validate_blocks_json` покрывает ВСЕ пути записи blocks_json; **IDOR безопасен** (`_get_version_by_id` фильтрует по version_id И strategy_id); guard-дедуп `useRequireAuth` настоящий; vline falsy-zero (logical 0) сохранён; allow-list рекурсия полная; CriticalBanner deadline корректен; `parseBackendDate` идемпотентен к Z; SessionResponse `iso_utc(None)→None`; нет мёртвого кода/потери мемоизации; histogram cap закрыл O(N²); UI-тексты русские.

## Осталось / заведено в backlog

**NEEDS-REVIEW / backlog (altitude / техдолг / латентное — не блокеры):**
- **P1W3-WS-AUTH-CONSOLIDATE** — `useBacktestJobWS.ts` держит 2 инлайн-копии handshake (`getWsBase`/`sendAuth`/`isAuthOk`/`isAuthError`) мимо общего `wsAuth.ts` (файл правился в волне, но не мигрирован) → ТРИ живых реализации WS-auth. Рефактор без изменения поведения — отдельной задачей (риск регресса reconnect).
- **P1W3-DRAWINGS-MSK-CONSOLIDATE** — `DrawingsLayer.buildPositionPayload` содержит 4-ю копию `3*3600` MSK-offset и `new Date(pt.t)` без Z-guard мимо `mskTime` (docstring `mskTime.ts` обещает, что копий не осталось). Латентно (offset-пара `+3ч…−3ч` математически сокращается; сдвиг возможен между entry.t naive и end.t с Z в regular mode). Требует аккуратной унификации + теста согласованности entry/end.
- **P1W3-BACKTESTAPI-DECIMAL-CONVENTION** — `normalizeBacktest` вводит конвенцию Decimal→`number` на границе API, расходящуюся с established (`api/types.ts:82-87`: Decimal остаются `string` + `Number()`). `toNum` fallback → `0` глушит невалидный Decimal (маскирует регресс backend, который типы должны были ловить). Решить: единая конвенция Decimal-at-boundary по всем API-модулям.
- **P1W3-MULTIPLEX-WS-REFRESH** — `client.ts` refresh токена не переподключает мультиплекс-WS; живой сокет продолжает стримить с уже истёкшим токеном (валидация только при handshake). Предсуществующее ограничение, усугублённое миграцией. Low.
- **P1W3-BACKTESTSTORE-RACE** — ✅ **закрыто** (request-token guard, коммит `0e039be`).

**E2E (Playwright) — выполнено (отдельный инстанс из worktree, решение заказчика):**
- Поднят отдельный Vite из интеграционного worktree на порту 5273 (живая копия на 5173/`p1/wave2-backend` НЕ тронута, HMR сохранён), mock-режим (`CI=1`, spec'и self-contained через `page.route`/`routeWebSocket`).
- **Затронутые зоны зелёные:** `s6-critical-banner` (FE-UI-01) ✓, `s5-chart-timeframes` (FE-CHART) ✓, часть `s6-notifications` (WS-handshake мок с `auth_ok` — прямая проверка фикса) ✓, часть `backtest-results` ✓.
- **Часть спеков (notifications drawer-клики, backtest tabs/export) падает — предсуществующий окруженческий флейк ad-hoc mock-инстанса, НЕ регрессия волны 3.** Строго подтверждено сравнением с базой `9cd44aa` (живой 5173): notifications — база 4 failed vs worktree 3; backtest-results — база 5 failed vs worktree 4. Волна 3 не вносит регрессий; worktree даже чуть стабильнее базы. Причина падений — ad-hoc отдельный инстанс не идентичен проектной nightly-инфре (`S7R-NIGHTLY-CI-MOCKS`: seed/localStorage/порядок webServer). Полная зелёная Playwright-регрессия — в проектной nightly CI.
- e2e-мок `/ws` исправлен под handshake (иначе после миграции клиент `wsAuthed=false` дропал бы все fixture frames).

**Правило E2E-цикла:** `ui_checklist` + `e2e/ui-checks/` дополнить проверками волны 3 (WS-handshake, vline sequential, критический баннер, race-guard'ы) — после Playwright-верификации.

**Осталось по P1 в целом:** auth-hardening мини-волна (CFG-FE-01/FE-NET-02/FE-PAGE-03 + P1W2-REFRESH-GRACE, `P1_AUTH_HARDENING_HANDOFF.md`). Backend Волны 1+2 закрыты. Финальное сведение всех `p1/wave*` в `s8r/bug-31` — одним PR/мержем с финальным ревью ПОСЛЕ всех волн (решение заказчика).
