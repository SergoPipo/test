# Хэндофф: P1 Волна 3 (frontend) — промпт для новой сессии

> Скопируй блок «ПРОМПТ» ниже в новую сессию Claude Code (Opus 4.8) в корне репозитория `Test`.
> Всё необходимое — в `Спринты/Code_Review_Full_2026-07/` и `Develop/CLAUDE.md`.

---

## Состояние на момент хэндоффа (2026-07-07)

- **Develop** (`git@github.com:SergoPipo/moex-terminal.git`): P0 + P1 Волна 1 + **P1 Волна 2 (backend)** запушены в ветку **`p1/wave2-backend`**, HEAD **`9cd44aa`**. Remote `s8r/bug-31-unified-codegen` оставлен на `a936e1a` (Волна 2 на отдельной ветке для ревью/мержа). База Волны 3 = **`p1/wave2-backend @ 9cd44aa`** (в ней весь бэкенд-фикс, а фронтенд от него не зависит).
- **Test** (внешний, `git@github.com:SergoPipo/test.git`): доки на ветке `docs/backlog-006-strategy-builder`, HEAD `3f5efba`.
- Осталось по P1: **Волна 3** (frontend, 6 веток). Backend полностью закрыт (Волны 1+2).

## Ветки Волны 3 — frontend (номера строк в `tdd_tasks_P1.md`)

| Ветка | Пункты (строки) | Примечания |
|---|---|---|
| `fix/fe-security` | CFG-FE-01 (401), CFG-FE-02 (407), FE-STOR-12 (413), FE-STOR-13 (419) | **⚠️ КРУПНЫЙ, cross-cutting.** CFG-FE-01 (токены из localStorage → HttpOnly cookie) требует СОГЛАСОВАННЫХ правок backend (выдача cookie в be-auth). Связан с backlog `P1W2-REFRESH-GRACE`. **Рекомендую brainstorm + отдельное согласование scope перед кодом** — возможно, координированный backend+frontend фикс, а не чисто фронт. CFG-FE-02 (токен в WS query-string) — можно закрыть nginx-стороной (`access_log off` для `/ws/`) как переходный минимум. |
| `fix/fe-network` | FE-NET-01 (434), FE-NET-02 (440), FE-NET-03 (446), FE-NET-04 (452) | FE-NET-04 — **подтверждён реальным** (WS фонового бэктеста без reconnect; соседний `useBacktestJobWS` с backoff — мёртвый код). Fix: добавить exponential backoff в `onclose` или переиспользовать `useBacktestJobWS`. |
| `fix/fe-charts` | FE-CHART-01 (467), FE-CHART-02 (473), FE-CHART-03 (479) | FE-CHART-01 — **подтверждён реальным** (VlinePrimitive рисует по unix-времени, а intraday-серия в sequential mode индексирована 0..N → линия не видна/не там). Fix: `pointToCoord({t, logical})` вместо `timeToX`, сохранять `logical` при создании. **context7 по lightweight-charts.** |
| `fix/fe-backtest-ui` | FE-BTST-13 (494), FE-BTST-14 (500), FE-BTST-15 (506), FE-BTST-16 (512) | FE-BTST-15 — **подтверждён реальным** (rAF-цикл перерисовки зон крутится на скрытом компоненте, `display:none`). Fix: стоп rAF при `document.hidden`/`IntersectionObserver` или перерисовка по `subscribeVisibleTimeRangeChange`. |
| `fix/fe-core-refactor` | FE-PAGE-01 (528), FE-PAGE-02 (534), FE-PAGE-03 (540), FE-CORE-01 (546), FE-CORE-02 (552), FE-CORE-06 (558), FE-CORE-07 (564), FE-CORE-08 (570) | Крупный рефактор god-компонентов (StrategyEditPage) + дубли форматтеров/guard. Аккуратно с регрессиями. |
| `fix/fe-ui-misc` | FE-STRAT-01 (585), FE-TRAD-01 (591), FE-TRAD-02 (597), FE-UI-01 (603) | **FE-TRAD-02 — это BACKEND** (`backend/app/trading/schemas.py:110`), не фронт. Blockly load-валидация (FE-STRAT-01) — context7 по Blockly. |

**❓-пункты (FE-NET-04 / FE-CHART-01 / FE-BTST-15)** в `tdd_tasks_P1.md` помечены «уточнить», но их спеки полны и сценарии реальны (см. рекомендации выше) — можно делать по спеке; быструю sanity-проверку сценария сделать перед фиксом.

## Метод (адаптация метода Волны 1/2 под frontend)

Стек: React + TS + Vite + Mantine (dark) + Zustand + lightweight-charts + Blockly. Менеджер — **pnpm**. Тесты — **vitest** (`pnpm test` = `vitest run`), E2E — **Playwright**. Type-check — `tsc -b` (в составе `pnpm build`) или `npx tsc --noEmit`.

1. **⚠️ node_modules в worktree'ах НЕТ** (gitignored) → `tsc`/`vitest`/Playwright в git-worktree не пройдут. Варианты: **(а)** работать в живом `Develop/frontend` на ветке (аккуратно с HMR — Vite dev-сервер держит state; см. memory про checkout); **(б)** симлинк `node_modules` в worktree (`ln -s ../../../frontend/node_modules <wt>/frontend/node_modules`). tsc/vitest-гейт гнать в живой копии.
2. **DEV-агенты (Opus, test-first)** — по одному на ветку. Промпт: точные пункты из `tdd_tasks_P1.md` (номера строк), Red→Green, читать `Develop/stack_gotchas/INDEX.md` по симптому, отчёт ≤400 слов по 8 секциям. Frontend TDD: логику (форматтеры, guard, reconnect, stores) покрывать vitest-тестами; для чисто визуального — Playwright-скриншот.
3. **typescript-lsp** diagnostic после КАЖДОГО Edit/Write .ts/.tsx (fallback: `npx tsc --noEmit`). **0 errors** — критерий.
4. **context7** ПЕРЕД кодом по: lightweight-charts (fe-charts), Blockly (fe-ui-misc), Mantine (если новые компоненты).
5. **Playwright-скриншоты** затронутых экранов — матрица «компонент → URL» в `Develop/CLAUDE.md` (charts → `/chart/SBER?session=1`, backtest → соответствующие, и т.д.). Поднять backend+frontend перед E2E.
6. **Мерж:** непересекающиеся файлы → clean merge каждой ветки. Пересечения (`authStore.ts` в fe-security ∩ fe-network; `useWebSocket.ts` в fe-security ∩ fe-network) — мержить по очереди, разрешать вручную.
7. **Гейт на объединённом:** `pnpm test` (vitest, вся сюита) + `npx tsc --noEmit` (0 errors) + Playwright по затронутым экранам. Сверить число vitest-тестов с baseline.
8. **`/code-review`** обязателен по security-чувствительным правкам (fe-security — хранение токенов) и по `api/*`+рефактору god-компонентов (fe-core-refactor). Быть готовым к раунду фиксов (Волны 1 и 2 показали: ревью находит реальные дефекты в свежих фиксах — по 8-9 каждая).
9. **Push:** после зелёного гейта + ревью — в отдельную ветку (напр. `p1/wave3-frontend`), remote `s8r/bug-31` не трогать. **Спрашивать ветки для обоих репо отдельно (правило двух репо).**
10. **Доки (репо Test):** `P1_WAVE3_LOG.md` (по образцу `P1_WAVE2_LOG.md`), обновить `project_state.md`, `ui_checklist` + `e2e/ui-checks/` (правило E2E-цикла). Закоммитить+запушить по подтверждению.

## Ссылки
- Спеки пунктов: `Спринты/Code_Review_Full_2026-07/tdd_tasks_P1.md` (frontend с строки 394).
- Как делались Волны 1/2 + уроки ревью: `P1_WAVE1_LOG.md`, `P1_WAVE2_LOG.md`. Backend-хэндофф: `P1_WAVE2_HANDOFF.md`.
- Backlog P1W2 (для контекста, часть — фронт): раздел «Осталось» в `P1_WAVE2_LOG.md` (P1W2-REFRESH-GRACE, P1W2-SSRF-PINNING, P1W2-AI-LOCAL-PROVIDER-UPGRADE).
- Правила плагинов/стека: `Develop/CLAUDE.md`; ловушки — `Develop/stack_gotchas/INDEX.md`.

---

## ПРОМПТ (копировать в новую сессию)

```
Продолжаем P1 из код-ревью MOEX-терминала — Волна 3 (frontend). Прочитай сначала:
- Спринты/Code_Review_Full_2026-07/P1_WAVE3_HANDOFF.md (состояние, ветки, метод, ссылки)
- Спринты/Code_Review_Full_2026-07/P1_WAVE2_LOG.md (как сделаны Волны 1/2 + уроки /code-review, backlog)
- Спринты/project_state.md (последние записи 2026-07-07)

Затем запусти P1 Волну 3 (frontend, 6 веток: fe-security, fe-network, fe-charts,
fe-backtest-ui, fe-core-refactor, fe-ui-misc) по методу из HANDOFF: DEV-агенты Opus
test-first, база p1/wave2-backend (@9cd44aa). Frontend-специфика: node_modules в
worktree'ах НЕТ (gitignored) — гейт tsc/vitest/Playwright гнать в живой копии
Develop/frontend (аккуратно с HMR) или через симлинк node_modules; typescript-lsp
diagnostic после каждого Edit; context7 по lightweight-charts/Blockly/Mantine ПЕРЕД
кодом; Playwright-скриншоты затронутых экранов (матрица в Develop/CLAUDE.md).
Спеки — в tdd_tasks_P1.md (frontend с строки 394; номера строк в таблице HANDOFF).

ВНИМАНИЕ:
- fix/fe-security (CFG-FE-01 — токены localStorage→HttpOnly cookie) КРУПНЫЙ и
  cross-cutting: требует согласованных backend-правок (be-auth) и связан с backlog
  P1W2-REFRESH-GRACE. Сделай brainstorm и согласуй scope со мной ПЕРЕД кодом
  (возможно, координированный backend+frontend фикс).
- FE-TRAD-02 — это backend (trading/schemas.py), не фронт.
- ❓-пункты FE-NET-04/FE-CHART-01/FE-BTST-15 — подтверждены реальными, делать по
  спеке (быстрая sanity-проверка сценария перед фиксом).

После сборки веток: мерж + гейт (pnpm test + npx tsc --noEmit 0 errors + Playwright)
+ /code-review по fe-security (хранение токенов) и fe-core-refactor + фиксы находок +
push в отдельную ветку p1/wave3-frontend. Модель Opus 4.8, коммиты/push — только по
подтверждению, ветки для обоих репо (Develop + Test) спрашивать отдельно. Если увидишь
приближение лимита сессии — остановись и спроси. После Волны 3 — свести P1-итог
(Волны 1+2+3) и предложить мерж p1/wave*-веток в s8r/bug-31.
```
