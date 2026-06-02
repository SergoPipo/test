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

- [x] **Dashboard** — виджеты Health, Balance, Active Positions, Sparkline рендерятся.
  > Заметка:

- [x] **Strategy (список)** — список стратегий, кнопка «Создать» работает.
  > Заметка:

- [x] **Backtest** — страница запуска, выбор стратегии работает.
  > Заметка:

- [x] **Trading (paper/live сессии)** — список сессий загружается.
  > Заметка:

- [x] **Chart (график)** — открывается, свечки рендерятся, можно сменить таймфрейм.
  > Заметка:

- [x] **Account** — баланс, позиции, операции, налоги отображаются.
  > Заметка: 

- [x] **AI Chat** — окно открывается, можно отправить сообщение.
  > Заметка:

- [x] **Settings** — настройки уведомлений + broker settings грузятся.
  > Заметка:

- [x] **Admin Landing** (если ты admin) — открывается, есть ссылка на Plotly Dash.
  > Заметка:

---

## Шаг 2 — 6 сквозных сценариев (1 день)

Полные тексты сценариев — в [ui_checklist_s8.md секция S8.15](../ui_checklist_s8.md). Здесь — краткая шапка.

### Сценарий 1 — Новый пользователь → Wizard → стратегия → бэктест → paper → закрытие

- [x] Регистрация нового тестового пользователя (логин типа `test_acceptance_001`).
  > Заметка: Есть ошибка при вводе нового пользователя. Пишет просто ошибка создания пользователя.
  > 2026-05-29: BUG-12 заведён и зафиксирован — попытка создать `testuser` падала с 500 (UNIQUE constraint на username, уже сидел в БД от прежней сессии). Фикс: backend отдаёт 409, frontend показывает «Имя пользователя уже занято». Ожидается перепроверка с новым username (например, `test_acceptance_002`).

- [x] FirstRunWizard 4 шага проходятся: учётка → broker token → notifications → финиш.
  > Заметка:

- [x] Создаётся стратегия (Blockly или AI Chat).
  > Заметка: После создания стратегии блоков и переноса ее в текстовое значение, при нажатии на кнопку «Генерировать» я получил пайтинг от стратегии, но все блоки на схеме удалились. Текстовое представление стратегии тоже очистилось.

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

- [x] `cd Develop/backend && .venv/bin/python -m app.cli.users grant_admin sergopipo` (выдать себе admin, если ещё нет). Исправлен путь модуля: `app.cli` → `app.cli.users` (см. BUG-7).
  > Заметка: выполнено 2026-05-27, SQL UPDATE прошёл, в логе: `User 'sergopipo' is now admin`.

- [x] Перезайти. В Sidebar появилась иконка щита (Shield).
  > Заметка: 2026-05-27 — после logout/login Sidebar показывает раздел «Администрирование».

- [x] AdminLandingPage открывается, ссылка на Plotly Dash присутствует.
  > Заметка: 2026-05-27 — открывается, в карточке «Активные торговые сессии» появилась колонка User (BUG-10 фикс).

- [x] `/api/v1/admin/metrics/` открывается, 4 графика рендерятся (signal→order, dashboard LCP, Telegram latency, backtest jobs rate).
  > Заметка: 2026-05-27 — все 4 графика рендерятся после фикса BUG-9 (path-based CSP для Plotly Dash). Cookie `access_token` выставляется на login (BUG-8).

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

- **BUG-17 ✅ FIXED 2026-06-02 (S8R-ACCEPTANCE-FIX-BUG-17) | severity: medium (UX cosmetic + CSV/PDF data integrity) | `backend/app/backtest/service.py:_save_result` | На графике аналитики бэктеста последняя сделка (#422 в backtest #38: long, entry 2025-11-10 10:00, exit 2026-06-02 14:00) не подсвечена цветной зоной между entry/exit маркерами. Все остальные сделки имеют корректные profit/loss-зоны.** Корневая причина: Backtrader auto-closes открытые позиции в конце прогона; `bt.num2date(trade.dtclose)` возвращает значение за пределами `date_to` бэктеста (`2026-05-31`). В БД `backtest_trades.exit_date='2026-06-02 14:00'` — после `date_to`. Frontend `computeChartZones` ([tradeMarkerUtils.ts:99](Develop/frontend/src/utils/tradeMarkerUtils.ts#L99)) сматчивает entry/exit маркеры по таймстампам, но exit-маркер вне видимого диапазона свечей не имеет координаты → зона между entry и exit не отрисовывается. **Фикс**: `_save_result` clamp `exit_date` к `backtest.date_to`, если `exit_date > date_to`. Это гарантирует корректность для UI (зона рисуется до конца графика), CSV-экспорта и PDF-отчёта. **Тесты**: `TestSaveResultClampsExitDateBug17` × 2 (exit_date_after_date_to → clamped, exit_date_within_period → unchanged). Полный regression backtest module **215/215 GREEN**. **UI-верификация**: после фикса заказчик должен **повторно запустить** бэктест (rerun #38 или новый), и зона последней сделки появится. Существующий backtest #38 с `exit_date='2026-06-02'` ретроактивно не лечится — но новые сделки будут корректны.

- **BUG-16 ✅ FIXED 2026-06-02 (S8R-ACCEPTANCE-FIX-BUG-16) | severity: high (блокер acceptance Сценария 1 для sandbox) | `backend/app/market_data/service.py` (4 callsites: `_has_active_tinvest_account`, `_fetch_via_broker`, `_get_tinvest_token_for_X` × 2) | Запуск бэктеста на T-Invest **sandbox**-токене падал с `TInvestRequiredError("Подключите T-Invest для запуска бэктеста")`, хотя sandbox корректно добавлен (`tinvest_connected sandbox=True` в логе).** Корневая причина: фильтр `BrokerAccount.is_sandbox == False` в 4 местах `market_data/service.py` исключал sandbox-аккаунты — что неверно, т.к. T-Invest sandbox имеет полный доступ к `MarketDataService` (GetCandles, GetLastPrices, GetTradingStatus). Sandbox отличается только в OrdersService (для live-торговли). **Фикс**: убран `is_sandbox == False` из всех 4 фильтров; добавлен `ORDER BY is_sandbox.asc()` чтобы production-токен предпочитался при наличии обоих (production=0 < sandbox=1). Обновлены misleading-комментарии («sandbox не имеет MarketDataService» → «sandbox даёт MarketDataService»). **Тесты**: `TestHasActiveTInvestSandboxBug16` × 3 (sandbox→True, production→True, no account→False). Полный regression: backend pytest **343/343 GREEN** (auth + backtest + market_data + xss + exceptions). **UI-верификация**: testuser1 после добавления sandbox-токена должен успешно запустить бэктест #36 rerun → метрики появятся.

- **BUG-14 ✅ FIXED 2026-06-02 (S8R-ACCEPTANCE-FIX-BUG-14) | severity: high (UX-блокер + маскировка причины) | `backend/app/common/exceptions.py` (все 7 framework-исключений), `backend/app/backtest/service.py:create_backtest` | На /backtests/36 (SBER, 1ч, кап. 300000) бэктест за 6 мс получил статус «ОШИБКА» с пустым `error_message`. UI показал «ОШИБКА» без пояснения — пользователь не понимает что делать.** Корневая причина: `testuser1` (id=4) не подключил T-Invest. `MarketDataService.get_candles` корректно кидает `TInvestRequiredError(detail="Подключите T-Invest...")`. НО `TInvestRequiredError.__init__` (как и другие 6 классов в `exceptions.py`) сохранял `self.detail`, не вызывая `super().__init__(detail)` — `str(e)` возвращал пустую строку. `BacktestService.create_backtest` ловил всё через `except Exception as e: error_message = str(e)` → в БД писалась пустая строка. Дополнительно: TInvestRequiredError глоталась generic'ом, FastAPI-handler 409 не срабатывал, frontend получал 200 + failed-orphan вместо модалки «Подключите T-Invest». **Фикс**: (1) во ВСЕ 7 классов `exceptions.py` добавлен `super().__init__(detail)` — `str(e)` теперь возвращает detail; (2) `create_backtest` ловит `TInvestRequiredError` отдельно ДО generic except — помечает backtest как failed с осмысленным detail и `raise` пробрасывает наружу → FastAPI handler возвращает 409 + JSON `{detail, error_code: tinvest_required, mode: backtest}`. **Тесты**: 7 новых в `TestExceptionStrBug14` (str(e) == detail для всех 7 классов) + 1 в `TestRunBacktestTInvestRequiredBug14`. Backend pytest 259/259 GREEN (auth + backtest + security regression). **UI-верификация**: после фикса testuser1 при попытке запустить бэктест должен увидеть модалку «Подключите T-Invest для запуска бэктеста» с переходом в настройки брокера.

- **BUG-13 ✅ FIXED 2026-06-02 (S8R-ACCEPTANCE-FIX-BUG-13) | severity: high (потеря работы пользователя) | `frontend/src/pages/StrategyEditPage.tsx:handleGenerate`, `frontend/src/App.tsx:52-53` | На `/strategies/new` после сборки блоков + наполнения описания нажатие «Генерировать» возвращает Python-код, но Blockly workspace и текстовое описание визуально стираются.** Корневая причина: `App.tsx` объявляет ДВА разных Route с одним и тем же элементом — `strategies/new` и `strategies/:id`. React Router при переходе с одного на другой делает unmount → mount; все `useState`/`useRef` сбрасываются. В `handleGenerate` else-ветке (новая стратегия) последовательность была: `createStrategy(name, description)` → `generateCode(id, apiBlocks)` → `setCode(code)` → `navigate(/strategies/${id})`. Но `createStrategy` НЕ пишет blocks_json/generated_code в БД, `generateCode` тоже не пишет — после navigate новая instance читает пустую v1 из БД (`blocks_json='{}'`, `text_description=''`), useEffect перезаписывает workspace пустотой. **Фикс**: в else-ветке `handleGenerate` после `generateCode` и ДО `navigate` вызывается `saveVersion(newStrategy.id, { text_description, blocks_json, generated_code, parameters_json })` — тот же паттерн, что в `doSave` для `isNew`. После remount данные подтягиваются из БД целые. **Тесты**: vitest 8/8 GREEN (existing StrategyEditPage suite), tsc 0 errors. Manual smoke-проверка ожидается заказчиком. **Trade-off**: альтернатива «объединить две Route» отброшена — инвазивнее, риск других регрессий.

- **BUG-12 ✅ FIXED 2026-05-29 (S8R-ACCEPTANCE-FIX-BUG-12) | severity: high (functional blocker для Сценария 1) | `backend/app/auth/service.py:register`, `backend/app/auth/router.py:setup`, `frontend/src/pages/SetupPage.tsx` | POST /auth/setup с уже существующим username возвращает 500 + сломанные CORS-заголовки, UI показывает «Ошибка при создании аккаунта» + DevTools — «Origin not allowed by Access-Control-Allow-Origin».** Корневая причина: `service.register()` делал `await self.db.commit()` без try/except, SQLAlchemy кидал `sqlite3.IntegrityError: UNIQUE constraint failed: users.username`, exception доходил до глобального handler → 500. CORSMiddleware не вешает заголовки в exception path (тот же класс, что у BUG-2 sparkline) → браузер маскирует ответ как CORS error. **Фикс**: (1) `service.register` ловит `IntegrityError` и кидает `ValueError("username_taken")`; (2) `router.setup` ловит `ValueError("username_taken")` и кидает `HTTPException(409, "Имя пользователя уже занято")`; (3) `SetupPage` различает status 409 и показывает осмысленное сообщение из `data.detail`. **Тесты**: 2 новых regression (`test_register_duplicate_username_raises_value_error_bug12`, `TestSetupConflict.test_setup_duplicate_username_returns_409_bug12`). Backend 37/37 GREEN (auth/service + router + xss + cli), tsc 0 errors. **Smoke**: `curl POST /auth/setup` с занятым именем → `HTTP/1.1 409 Conflict` + `access-control-allow-origin: http://localhost:5173` (CORS headers на месте, browser больше не маскирует).

- **BUG-11 ✅ FIXED 2026-05-29 (S8R-ACCEPTANCE-FIX-BUG-11) | severity: low (cosmetic, ложный alarm) | `frontend/src/stores/authStore.ts:logout`, эффект на `frontend/src/pages/LoginPage.tsx:34-44` | После logout LoginPage показывает «Backend недоступен. Убедитесь, что сервер запущен на порту 8000.», хотя backend работает. Перезагрузка страницы убирает сообщение.** Корневая причина: `authStore.logout()` вызывает `abortAllInflight()` (отменяет глобальный module-level `AbortController` в `api/client.ts`), но НЕ пересоздаёт контроллер (в отличие от `login()`, где `renewAbortController()` есть). Router редиректит на `/login`, LoginPage `useEffect` запускает `apiClient.get('/auth/setup-status')`, request interceptor (`client.ts:55-57`) привязывает запрос к уже abort'нутому `inflightController.signal` → запрос мгновенно отменяется `ECANCELED` → `.catch(() => setBackendError(true))`. F5 фиксит, потому что модуль `client.ts` перезагружается с новым неабортнутым контроллером. **Фикс**: одна строка — `renewAbortController()` после `abortAllInflight()` в `logout()` (симметрия с `login()`). Глобальный эффект: все запросы после logout (не только LoginPage) получают свежий signal. **Тесты**: 1 новый regression `renews AbortController on logout (BUG-11)`, обновлён cleanup-order тест (closeWS → abort → **renew** → state → clearCache). vitest 13/13 GREEN, tsc 0 errors. **UI-верификация**: ожидается после Cmd+R.

- **BUG-10 ✅ FIXED 2026-05-27 (S8R-ACCEPTANCE-FIX-BUG-10) | severity: medium (multi-user readiness) | `backend/app/trading/router.py:list_sessions`, `backend/app/trading/service.py:get_sessions`, `backend/app/trading/schemas.py:SessionResponse`, `frontend/src/pages/admin/AdminLandingPage.tsx`, `frontend/src/api/tradingApi.ts`, `frontend/src/api/types.ts` | Карточка «Активные торговые сессии» в Admin Landing показывает сессии только текущего пользователя, а не всех (что ожидается от admin-карточки).** Endpoint `GET /api/v1/trading/sessions` фильтрует через `user_id=current_user.id`. **Фикс**: добавлен query-флаг `?all_users=true` с admin-gate (`HTTPException(403)` для не-админа); service делает batch-JOIN через StrategyVersion+Strategy и возвращает `user_id` в каждом item'е; `SessionResponse.user_id: int | None = None`; AdminLandingPage вызывает `tradingApi.getSessions({ status: 'active', all_users: true })` и показывает колонку User (`#${user_id}`). **Тесты**: 4 новых HTTP-теста (`test_list_sessions_default_filters_by_current_user_bug10`, `test_list_sessions_all_users_requires_admin_bug10`, `test_list_sessions_all_users_admin_sees_everyone_bug10`, проверка наличия `user_id` в response). **UI-верификация**: 2026-05-27 — колонка User видна, значения `#1` для текущего пользователя.

- **BUG-9 ✅ FIXED 2026-05-27 (S8R-ACCEPTANCE-FIX-BUG-9) | severity: high (functional blocker) | `backend/app/middleware/security_headers.py`, путь `/api/v1/admin/metrics/*` | Plotly Dash рендерит только статичный «Loading…» из-за CSP, блокирующей inline-скрипты Dash.** Глобальный `SecurityHeadersMiddleware` выставлял `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`. **Фикс**: path-based exception в middleware — для `request.url.path.startswith('/api/v1/admin/metrics')` отдаётся `_PLOTLY_DASH_CSP = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'"`. Остальные эндпоинты остаются под строгим `_DEFAULT_CSP`. **Тесты**: 3 новых regression — `test_admin_metrics_returns_relaxed_csp`, `test_admin_metrics_subpath_returns_relaxed_csp`, `test_default_csp_still_strict_for_other_paths`. Все 9/9 GREEN. **UI-верификация**: 2026-05-27 — 4 графика Plotly Dash рендерятся, console clean.

- **BUG-8 ✅ FIXED 2026-05-27 (S8R-ACCEPTANCE-FIX-BUG-8) | severity: high (functional gap + security design) | `backend/app/auth/router.py`, `frontend/src/pages/admin/AdminLandingPage.tsx`, `frontend/src/api/client.ts` | Ссылка на Plotly Dash `/api/v1/admin/metrics` в Admin Landing открывает SPA-404, при попытке прямого доступа backend возвращает 401.** Два слоя: (8a) href относительный → Vite SPA отдаёт index.html (нет proxy для `/api`), React Router показывает 404. (8b) Даже с абсолютным href на `:8000` backend возвращает 401: `AdminAuthASGIMiddleware` ждёт cookie `access_token`, но login сетит только `csrf_token`. **Фикс**: backend `_set_access_token_cookie()` helper выставляет `access_token` как HttpOnly cookie (`samesite='lax'`, `path='/api'`, `max_age=JWT_ACCESS_TOKEN_EXPIRE_MINUTES*60`) на `/setup`, `/login`, `/refresh`; `/logout` чистит cookie. Frontend axios с `withCredentials: true`. AdminLanding `PLOTLY_DASH_URL` строится через `VITE_API_BASE_URL` + trailing slash. **UI-верификация**: 2026-05-27 — ссылка открывает Plotly Dash в новой вкладке без 401/404.

- **BUG-7 ✅ FIXED 2026-05-27 (S8R-ACCEPTANCE-FIX-BUG-7) | severity: low | `backend/app/cli/users.py` | CLI `grant_admin` падал с `sqlalchemy.exc.InvalidRequestError: expression 'Strategy' failed to locate a name` ещё до выдачи прав.** Корневая причина: модуль импортировал только `User`, но у `User` есть relationship на `Strategy` через `relationship('Strategy', ...)` — SQLAlchemy mapper на init не мог разрешить ссылку, потому что `Strategy` ещё не зарегистрирован. **Фикс**: скопирован паттерн «register all models» из `app/main.py` — добавлены `from app.{auth,strategy,backtest,trading,broker,market_data,notification,circuit_breaker,corporate_actions,tax,common} import models as _* # noqa: F401` перед `from app.auth.models import User`. **Дополнительно**: в чеклисте (`Сценарий 5`) была неточная команда `python -m app.cli grant_admin ...` — поправлено на корректную `python -m app.cli.users grant_admin ...` (модуль `app.cli` — package без `__main__.py`, исполняется именно `app.cli.users`). **Верификация**: `python -m app.cli.users grant_admin sergopipo` → `User 'sergopipo' is now admin`, SQL UPDATE проверен. Тэг: `S8R-ACCEPTANCE-FIX-BUG-7`.

- **BUG-1 ✅ FIXED 2026-05-14 (Sprint 8 W7) | severity: lethal | `app/trading/engine.py`, `app/trading/runtime.py` | Sandbox/real торговля не была реализована в `engine.process_signal`. Trade создавался со `status=pending`, `TInvestAdapter.place_order` никем не вызывался. Реализовано в W7 (Вариант C++): `_submit_order_to_broker` отправляет market-order и резолвит trade по `OrderResponse.status`; `_recover_orphan_pending_trades` зачищает orphan'ы при старте backend. 13 новых тестов (8 sandbox-flow + 5 orphan-recovery), backend regression 1560/0 passed. ФТ v2.5 → v2.6.** Ожидается live-test заказчиком для финального подтверждения.

- **BUG-6 ✅ FIXED 2026-05-25 (S8R-ACCEPTANCE-FIX-BUG-5+6, в одном коммите с BUG-5) | severity: high (security) | `backend/app/tax/service.py:103-119` (`_load_trades`) | `GET /api/v1/tax/reports/{id}/download` НЕ фильтровал сделки по `user_id`.** В запросе `select(LiveTrade).join(TradingSession).where(LiveTrade.status == "closed", ...)` отсутствует `Strategy.user_id == user_id` (LiveTrade → TradingSession → StrategyVersion → Strategy → user_id). При появлении второго пользователя его сделки попадут в чужие налоговые отчёты. Single-tenant сейчас не страдает (один юзер), но это data-isolation дефект, обязательный к фиксу до production. **Тэг**: `S8R-ACCEPTANCE-FIX-BUG-6` (фиксится вместе с BUG-5).

- **BUG-5 ✅ FIXED 2026-05-25 (S8R-ACCEPTANCE-FIX-BUG-5+6) | severity: high | `backend/app/tax/service.py:121-225` (`_build_fifo_queue`) | Содержимое xlsx/csv налогового отчёта всегда было пустое — все агрегаты (total_profit, total_loss, taxable_base) = 0, в лотах exit_price/realized_pnl = NULL.** Корневая причина: алгоритм FIFO matching рассчитан на модель «отдельные buy- и sell-leg'и» (для каждой sell-сделки найти самый ранний открытый buy-лот). В этом коде LiveTrade — другая модель: одна строка = **уже закрытая пара entry+exit** (поля `entry_price`, `exit_price`, `opened_at`, `closed_at`, `pnl` — всё в одной записи). Поле `direction` хранит направление позиции (long/short), а не buy/sell-leg. В БД у заказчика 7 closed `live_trades` с `direction='buy'` (long), 0 с `direction='sell'`. Алгоритм: → buys.append(×7), sells.append(×0) → 7 open_lots, 0 sells для matching → ни один лот не закрыт → `realized_pnl=NULL` у всех 14 tax_lots → агрегаты 0. Воспроизведение: любой закрытый paper-трейд → POST `/tax/reports` → GET `/tax/reports/{id}/download` → файл с шапкой, без строк. **Фикс**: переписать `_build_fifo_queue` под closed-pair модель — для каждой LiveTrade.status='closed' создать TaxLot с rebuilt из entry+exit полей PnL = `(exit_price - entry_price) * filled_lots` (для long) или обратно (для short), минус commission. Заодно — фикс BUG-6 в одном коммите. **Тэг**: `S8R-ACCEPTANCE-FIX-BUG-5`. **UI-верификация заказчика 2026-05-25**: перегенерирован отчёт 2026 → в xlsx 7 строк с реальными ценами и PnL (SBER + LKOH paper-сделки), агрегаты total_profit/loss/taxable_base заполнены корректно. См. `Спринты/Sprint_8/changelog.md` запись `2026-05-25` для деталей рефакторинга + 9 новых тестов.

- **BUG-4 ✅ FIXED 2026-05-23 (S8R-ACCEPTANCE-FIX-BUG-4) | severity: medium | `frontend/src/components/account/TaxReportModal.tsx`, `frontend/src/stores/accountStore.ts`, `frontend/src/pages/AccountPage.tsx` | Кнопка «Сгенерировать отчёт» создавала файл на бэкенде, но в UI ничего не происходило — файл не скачивался и не отображался.** Корневая причина: `downloadTaxReport` action и `taxApi.downloadReport` существовали, но **нигде в UI не вызывались** (grep по всем .tsx — 0 хитов). Список `taxReports` тоже нигде не отрисовывался. **Фикс**: (a) `generateTaxReport` теперь возвращает `Promise<TaxReport>` (раньше void) — чтобы UI знал id новой записи; (b) `downloadTaxReport(id, filename?)` — опциональный кастомный filename; (c) на `AccountPage` добавлена обёртка `handleGenerateAndDownload`, которая после `generateTaxReport` сразу запускает `downloadTaxReport(id, "tax_report_${year}.${format}")`; (d) на mount `AccountPage` тянет `fetchTaxReports` и отрисовывает новую секцию «Налоговые отчёты» — таблица с колонками год/статус/дата/налоговая база и кнопкой-иконкой `IconDownload` на каждой строке. **Тесты**: 9/9 AccountPage GREEN, 7/7 accountStore GREEN (+2 новых для BUG-4), 2/2 TaxReportModal GREEN, `npx tsc --noEmit` 0 errors. **UI-верификация заказчика 2026-05-23**: список отчётов отображается, генерация → авто-скачивание работает, кнопка «Скачать» на существующих строках срабатывает. Корневая причина: пропущена интеграция UI. Backend работает (POST `/tax/reports` → файл `data/tax_reports/tax_report_1_2026.xlsx` создаётся, status=ready; GET `/tax/reports/{id}/download` отдаёт blob корректно). На фронте есть `taxApi.downloadReport` и `accountStore.downloadTaxReport` (Blob → click), но **`downloadTaxReport` нигде в UI не вызывается** (grep по всем .tsx — 0 хитов). Модалка после `onGenerate` сразу закрывается (`onClose()`), а отрисовки списка `taxReports` на AccountPage нет. Воспроизведение: Account → «Налоговый отчёт» → выбрать год 2026 → «Сгенерировать отчёт» → модалка закрылась, файл не скачался. Подтверждено в логе backend: POST 200 + GET 200 (список), но **нет** GET `/download`. **Тэг для фикс-ветки**: `S8R-ACCEPTANCE-FIX-BUG-4`.

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
