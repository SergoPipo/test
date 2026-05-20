# S8 Acceptance Checklist (Sprint_8_Review)

> **Цель:** проверить текущую реализацию Sprint 8 на dev-окружении (start.sh, localhost). Это **главный артефакт Sprint_8_Review**.
>
> **Решение от 2026-05-14:** перевод в продуктив (Mac mini Docker, canary, watchdog) вынесен в отдельный **Sprint 9 "Перевод в продуктив"**, стартующий после Gate Sprint_8_Review.
>
> **Как пользоваться:**
> - Каждый пункт = чекбокс `[ ]`. Отметить выполнение: `[x]` (OK), `[!]` (баг), `[-]` (N/A).
> - Под пунктом — место для заметки. Описывай что увидел, чем не понравилось, какой шаг не работает.
> - Найденные баги собираются в секции «Найденные баги» внизу.
> - Когда всё пройдено — секция «Финальный вердикт» подписывается.
>
> **Окружение:**
> - `cd Develop && ./scripts/start.sh`
> - Backend: http://localhost:8000
> - Frontend: http://localhost:5173
> - Логин: `sergopipo` (пароль у заказчика)

**Дата старта:** _(заполни при старте)_
**Дата завершения:** _(заполни в конце)_
**Тестер:** sergopipo

---

## Шаг 0 — Pre-flight (5–10 минут)

- [x] `cd Develop && ./scripts/start.sh` — обе строчки `Backend: http://localhost:8000` и `Frontend: http://localhost:5173` появились, ошибок в терминале нет.
  > Заметка:

- [x] `http://localhost:5173` открылся в браузере.
  > Заметка:

- [x] DevTools (Cmd+Opt+I) → Console: **нет красных ошибок** (warnings ОК).
  > Заметка: в Console 4 ошибки, но 3 из 4 — dev-only артефакты, не баги продукта:
  > - `WebSocket ... closed before established` (×2, `/ws` и `/ws/trading-sessions/1`) — поведение React 18 StrictMode в dev: первый `useEffect` отменяется на unmount, второй коннект устанавливается стабильно. Backend log это подтверждает (`ws_connected` → `ws_subscribed channel=notifications:1,health`, держится). В production-сборке отсутствует.
  > - `T-Invest CDN 403` для `RU000A10DS74x160.png` (логотип облигации Сибур-Холдинг 001P-08) — у CDN нет логотипа для этой бумаги, фронт должен показать дефолтную плашку (UX-минорная вещь).
  > - **Реальный баг — sparkline 500** (SQLite `database is locked` при startup-конкуренции), вынесен в BUG-2. Симптом «CORS error / Status code: 500» на запросе sparkline — производный от 500 (CORSMiddleware не отдаёт заголовки в exception path).

- [x] Логин как `sergopipo` прошёл, попадаю на Dashboard.
  > Заметка:

- [x] DevTools → Network → запрос `/api/v1/health` ответил 200, в теле есть `tinvest_connected`, `scheduler_running`.
  > Заметка: проверено через `curl http://localhost:8000/api/v1/health` — `{"status":"ok","version":"0.1.0","database":"connected","cb_state":"ok","tinvest_connected":true,"scheduler_running":true,"scheduler_jobs":4}`. Все 4 ключевых поля присутствуют (status, database, tinvest_connected, scheduler_running).

**Если хоть один пункт Шага 0 не прошёл — стоп, сообщи мне.**

---

## Шаг 1 — Smoke по основным страницам (15–20 минут)

Открыть каждую страницу. Проверка: загружается без 500/JS-ошибок, видны данные (или понятное пустое состояние).

- [ ] **Dashboard** — виджеты Health, Balance, Active Positions, Sparkline рендерятся.
  > Заметка:

- [ ] **Strategy (список)** — список стратегий, кнопка «Создать» работает.
  > Заметка:

- [ ] **Backtest** — страница запуска, выбор стратегии работает.
  > Заметка:

- [ ] **Trading (paper/live сессии)** — список сессий загружается.
  > Заметка:

- [ ] **Chart (график)** — открывается, свечки рендерятся, можно сменить таймфрейм.
  > Заметка:

- [ ] **Account** — баланс, позиции, операции, налоги отображаются.
  > Заметка:

- [ ] **AI Chat** — окно открывается, можно отправить сообщение.
  > Заметка:

- [ ] **Settings** — настройки уведомлений + broker settings грузятся.
  > Заметка:

- [ ] **Admin Landing** (если ты admin) — открывается, есть ссылка на Plotly Dash.
  > Заметка:

---

## Шаг 2 — 6 сквозных сценариев (1 день)

Полные тексты сценариев — в [ui_checklist_s8.md секция S8.15](../ui_checklist_s8.md). Здесь — краткая шапка.

### Сценарий 1 — Новый пользователь → Wizard → стратегия → бэктест → paper → закрытие

- [ ] Регистрация нового тестового пользователя (логин типа `test_acceptance_001`).
  > Заметка:

- [ ] FirstRunWizard 4 шага проходятся: учётка → broker token → notifications → финиш.
  > Заметка:

- [ ] Создаётся стратегия (Blockly или AI Chat).
  > Заметка:

- [ ] Запускается бэктест, дожидаюсь результатов, метрики корректны.
  > Заметка:

- [ ] Запускается paper-сессия на результате бэктеста.
  > Заметка:

- [ ] Paper-сессия закрывается через UI, статус меняется на `closed`.
  > Заметка:

### Сценарий 2 — Live торговля → мониторинг → закрытие

⚠️ **ВАЖНО:** Использовать SANDBOX-токен T-Invest, а не реальный счёт, пока не пройдёт W6b с TRADING_ENABLED guard.

- [ ] Стратегия переведена в режим `live`.
  > Заметка:

- [ ] Live-сессия запускается через UI.
  > Заметка:

- [ ] Дожидаюсь хотя бы одного сигнала / ордера.
  > Заметка:

- [ ] В Trading-странице видно открытую позицию / ордер.
  > Заметка:

- [ ] Live-сессия закрывается вручную, позиции корректно отображаются как закрытые.
  > Заметка:

### Сценарий 3 — Background backtest (параллельные jobs)

- [ ] Запускаю 2–3 бэктеста в фоне.
  > Заметка:

- [ ] `BackgroundBacktestsBadge` в шапке показывает корректный счётчик.
  > Заметка:

- [ ] После завершения панель auto-collapse через ~10 секунд.
  > Заметка:

- [ ] Открываются результаты любого из них.
  > Заметка:

### Сценарий 4 — Grid Search heatmap

- [ ] Запускается Grid Search (вариация параметров стратегии).
  > Заметка:

- [ ] Дожидаюсь завершения, статус `done`.
  > Заметка:

- [ ] Клик на `BackgroundBacktestsBadge` → modal с `GridSearchHeatmap` открывается.
  > Заметка:

- [ ] Видны ячейки с цветовой шкалой P&L, hover показывает значения.
  > Заметка:

### Сценарий 5 — Admin + Plotly Dash /admin/metrics

- [ ] `cd Develop/backend && .venv/bin/python -m app.cli grant_admin sergopipo` (выдать себе admin, если ещё нет).
  > Заметка:

- [ ] Перезайти. В Sidebar появилась иконка щита (Shield).
  > Заметка:

- [ ] AdminLandingPage открывается, ссылка на Plotly Dash присутствует.
  > Заметка:

- [ ] `/api/v1/admin/metrics/` открывается, 4 графика рендерятся (signal→order, dashboard LCP, Telegram latency, backtest jobs rate).
  > Заметка:

### Сценарий 6 — Interactive zones + trade-row click

- [ ] Открываются результаты закрытого бэктеста.
  > Заметка:

- [ ] Переход на вкладку «Аналитика».
  > Заметка:

- [ ] Hover на зоны equity-curve — tooltip появляется.
  > Заметка:

- [ ] Клик на строку в таблице трейдов — открывается `TradeDetailsPanel`.
  > Заметка:

---

## Шаг 3 — ui_checklist_s8.md (17 секций, 1–2 дня)

Полный список 136 пунктов — в [ui_checklist_s8.md](../ui_checklist_s8.md). Иди сверху вниз, отмечай каждый пункт. Заметки и баги пиши прямо в этом файле в секции ниже.

**Прогресс по секциям:**

- [ ] S8.1 Admin role frontend (~6 пунктов, 10 мин)
  > Заметки/баги:

- [ ] S8.2 Plotly Dash /admin/metrics (~5 пунктов, 10 мин)
  > Заметки/баги:

- [ ] S8.3 ErrorBoundary (~6 пунктов, 5 мин)
  > Заметки/баги:

- [ ] S8.4 Strategy status change UI (~6 пунктов, 15 мин)
  > Заметки/баги:

- [ ] S8.5 Dashboard widgets (~8 пунктов, 15 мин)
  > Заметки/баги:

- [ ] S8.6 Wizard Telegram test button (~6 пунктов, 10 мин)
  > Заметки/баги:

- [ ] S8.7 Event type labels sync (~5 пунктов, 10 мин)
  > Заметки/баги:

- [ ] S8.8 Drawing tools editing (~6 пунктов, 30 мин)
  > Заметки/баги:

- [ ] S8.9 AIChat apply (~5 пунктов, 15 мин)
  > Заметки/баги:

- [ ] S8.10 SecurityHeadersMiddleware (~4 пункта, 5 мин — DevTools Network → Response Headers)
  > Заметки/баги:

- [ ] S8.11 BG-backtest panel (~5 пунктов, 15 мин)
  > Заметки/баги:

- [ ] S8.12 Backtest analytics tabs (~6 пунктов, 20 мин)
  > Заметки/баги:

- [ ] S8.13 Paginated types (~4 пункта, 10 мин)
  > Заметки/баги:

- [ ] S8.14 Performance / Observability (~7 пунктов, 15 мин — DevTools Performance tab)
  > Заметки/баги:

- [ ] S8.15 6 сценариев (покрыто Шагом 2 выше)
  > Заметки/баги:

- [ ] S8.16 Cross-DEV contracts verification (~7 пунктов, 15 мин)
  > Заметки/баги:

- [ ] S8.17 Общие проверки (~10 пунктов, 30 мин)
  > Заметки/баги:

---

## Найденные баги

> Формат: `BUG-N | severity: lethal/critical/medium/low | где | что | приоритет фикса`

- **BUG-1 ✅ FIXED 2026-05-14 (Sprint 8 W7) | severity: lethal | `app/trading/engine.py`, `app/trading/runtime.py` | Sandbox/real торговля не была реализована в `engine.process_signal`. Trade создавался со `status=pending`, `TInvestAdapter.place_order` никем не вызывался. Реализовано в W7 (Вариант C++): `_submit_order_to_broker` отправляет market-order и резолвит trade по `OrderResponse.status`; `_recover_orphan_pending_trades` зачищает orphan'ы при старте backend. 13 новых тестов (8 sandbox-flow + 5 orphan-recovery), backend regression 1560/0 passed. ФТ v2.5 → v2.6.** Ожидается live-test заказчиком для финального подтверждения.

- **BUG-3 ✅ FIXED 2026-05-20 (S8R-ACCEPTANCE-FIX-BUG-3 + followup) | severity: medium | `app/account/service.py`, `app/account/schemas.py`, `BalanceWidget.tsx`, `accountApi.ts` | «За день» в виджете Balance показывал фейковый -27% / -80 961 ₽ из-за методологической рассинхронизации формул.** Корневая причина: today считался через `sum(PaperPortfolio.balance)` (только cash, без sandbox, без позиций), прошлые дни — через `initial_capital + cumulative_realized_pnl`. **Фикс**: (a) снят today-special-case в `get_balance_history` — единая формула на все дни; (b) добавлено поле `trading_pnl: float` в `BalanceHistoryPoint` schema = `cumulative_realized_pnl(<=d)` без `initial_capital`; (c) `BalanceWidget` теперь использует `trading_pnl` для sparkline и дневной дельты (а `total_value` — только для большой цифры), чтобы открытие новой сессии не выглядело как «торговый рост»; (d) UX-полировка: при ровно 0 дневной дельте — нейтральный state (`IconMinus`, dimmed-текст, без стрелки); цвет sparkline теперь трёхзначный (green/red/`gray-5`). **Тесты**: +1 новый regression-тест `test_balance_history_today_and_yesterday_use_same_formula_bug3` + 1 для `trading_pnl` separation; 13/13 backend GREEN, 6/6 frontend BalanceWidget GREEN, `npx tsc --noEmit` 0 errors. **Trade-off**: sparkline теперь — «P&L curve», а не «balance over time»; реальная equity-кривая с market value позиций — задача Sprint 9 (`S9-EQUITY-DAILY-SNAPSHOT`). См. `Спринты/Sprint_8/changelog.md` запись `2026-05-20`. UI-верификация заказчиком: 299 891 ₽ + «+0 ₽ серым» + красная sparkline со ступенькой -109.16 (закрытие LKOH на 2026-05-08).

- **BUG-2 | severity: medium | `app/market_data/service.py:168-188` (`_purge_iss_cache`) → `router.py:79` (`get_sparkline`) | Transient HTTP 500 при первом обращении к `/api/v1/market-data/sparkline` на холодном старте backend.** Trace в backend.log: `sqlite3.OperationalError: database is locked`. Корневая причина — конкуренция за SQLite writer-lock между lifespan startup prefill (DELETE из `ohlcv_cache` для прогрева SBER, политика S5R «T-Invest — единственный источник») и параллельным API-запросом с frontend, который через `_purge_iss_cache` запускает аналогичный DELETE. Существующий retry на 3 попытки (S5R hotfix) не всегда спасает при startup-конкуренции. После прогрева — все запросы 200 OK (подтверждено логом `12:46:59 ... 200 OK`). **Симптом в DevTools**: красная строка `Origin http://localhost:5173 is not allowed by Access-Control-Allow-Origin. Status code: 500` — это маскировка от браузера; реальная причина 500, не CORS. **Приоритет фикса**: medium — не блокирует UX (sparkline появится при перезагрузке страницы), но шумит в Console и портит впечатление. Варианты фикса: (a) WAL `busy_timeout` повысить, (b) ретраи увеличить с 3 до 5-7 + экспоненциальный backoff, (c) отложить prefill до окончания startup через `lifespan` deferred-task.

---

## Общие замечания

> Сюда пиши любые мысли, идеи, неудобства UX, странности поведения, которые не тянут на «баг», но требуют обсуждения.

- **DevTools-шум на dev-сборке (некритично, но мешает приёмке):**
  - `WebSocket ... closed before the connection is established` — артефакт React 18 StrictMode (двойной mount компонента в dev → отмена первого WS-соединения). В production-сборке `pnpm build && pnpm preview` отсутствует. Если хочется чистый Console при приёмке — можно либо отключить StrictMode в `main.tsx` на время review, либо договориться, что dev-only ошибки игнорируются.
  - **React HTML-warning**: `<p> cannot contain a nested <div>` (frontend log) — Mantine `Text` (рендерится в `<p>`) содержит вложенный `Group` (`<div>`). Невалидный HTML, но без визуального дефекта. Завести задачу на починку (`component="div"` или `span="true"` для `Text`-обёртки) в S9 backlog.
  - React Router v7 future-flag warnings (`v7_startTransition`, `v7_relativeSplatPath`) — желательно опт-ин до миграции на v7.
- **T-Invest CDN logo gracefully fallback**: для облигации `RU000A10DS74` (Сибур-Холдинг 001P-08) Tinkoff CDN отдаёт 403. Фронту стоит подавлять Console-ошибку через `<img onError>` и показывать дефолтную плашку (буква/иконка). Не баг функциональности, но шум в Console.

---

## Что показалось хорошим

> Сюда — фичи, которые работают как ожидалось или приятно удивили. Не пропусти этот раздел — он важен, чтобы не потерять то, что уже хорошо.

-

---

## Финальный вердикт

После прохождения всех шагов выбери один:

- [ ] **PASS** — все 136 пунктов зелёные, 0 багов severity ≥ medium. Sprint_8_Review закрыт, готов к старту Sprint 9 "Перевод в продуктив".
- [ ] **PASS WITH NOTES** — есть N багов severity ≤ medium, либо закрываем их в Sprint 8 (как W4/W5), либо переносим в Sprint 9 backlog. Sprint_8_Review закрыт.
- [ ] **NEED FIXES** — ≥1 lethal/critical баг. Стоп до фикса. Список багов передан, ждём моей реализации фиксов в `s8/sprint-8` ветке, после фикса возвращаемся к acceptance.

**Краткий итог (1–2 предложения):**

>

**Дата подписи:** _(заполни в конце)_

---

## Что дальше после Acceptance

1. Сохрани файл с заполненными чекбоксами и заметками.
2. Скажи мне «Acceptance закончен, посмотри файл» — я прочитаю.
3. По багам severity lethal/critical → фиксим сразу в `s8/sprint-8` ветке (тэг `S8R-ACCEPTANCE-FIX-*`).
4. По багам severity medium/low → решаем вместе: закрыть в S8 или перенести в Sprint 9 backlog.
5. Когда вердикт PASS или PASS WITH NOTES → закрываем Sprint_8_Review, стартуем **Sprint 9 "Перевод в продуктив"** (Mac mini Docker prod → canary → автоматизация).
