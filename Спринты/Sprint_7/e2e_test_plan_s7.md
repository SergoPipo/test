# E2E Test Plan — Sprint 7

> Заполнен QA-агентом на W0 ДО написания тестов (правило памяти `feedback_e2e_testing.md`).
> Версия: 2026-04-25 (W0 финал).

## Источники

- `Спринты/ui_checklist_s5r.md` — текущий UI-чеклист (база регрессии).
- `Sprint_7/sprint_design.md` — функциональность задач S7.
- `Sprint_7/ux/*.md` — UX-макеты W0 (источник истины для UI-проверок; финальные селекторы фиксируются UX в W0 → переиспользуются в тестах W1/W2).
- `Sprint_7/execution_order.md` секция 4 — Cross-DEV contracts C1–C8.
- `Sprint_7/changelog.md` — статус готовности контрактов.

## Тестовый аккаунт

`sergopipo` (правило памяти `user_test_credentials.md`; пароль у заказчика).
Подтверждено: запись `id=1, username='sergopipo'` присутствует в `Develop/backend/data/terminal.db`.

В моках (`Develop/frontend/e2e/fixtures/api_mocks.ts`) используется `injectFakeAuth(page)` с `user.id=1, username='e2e-user'` — для UI-only сценариев (без реального backend). Сценарии WS/Telegram/Email используют реальный backend + sergopipo.

## Регрессия

Baseline после Sprint_6_Review: **119 passed / 0 failed / 3 skipped**.
Цель S7: **≥ 119 + ≥ 15 новых = ≥ 134 passed / 0 failed**. Реалистичный план: ≥ 156 (debt 17 + features 20).

## Расположение тестов

`Develop/frontend/e2e/sprint-7/<feature>.spec.ts`. Один файл на задачу 7.X. Конвенции — как в `Develop/frontend/e2e/s6-*.spec.ts` (моки через `page.route`, fakeAuth для UI).

## Фикстуры

- `e2e/fixtures/api_mocks.ts` — `injectFakeAuth`, `mockAuthEndpoints`, mock brokerage data.
- `e2e/fixtures/moex_iss_mock.ts` — для MOEX-зависимых сценариев.
- Новые в S7 (создаются в W1):
  - `mockNotificationsWS(page, events[])` — для 7.13, 7.15, 7.17.
  - `mockBacktestWS(page, jobId, frames[])` — для 7.17.
  - `mockStrategyVersions(page, versions[])` — для 7.1.
  - `mockGridSearchResult(page, matrix)` — для 7.2.

---

## Сценарии по задачам

### 7.1 Версионирование стратегий (BACK2 + FRONT2) — контракт C4

#### S7.1.1 Создание версии вручную (happy path)
- **Предусловия:** sergopipo авторизован, есть стратегия `id=1` с пустым списком версий.
- **Шаги:**
  1. Открыть `/strategies/1/edit`.
  2. Изменить блок (например, RSI threshold с 30 на 25).
  3. Кликнуть «Сохранить версию» (комментарий: «снизил порог RSI»).
  4. Открыть таб «История версий».
- **Ожидаемый результат:** в списке появляется запись `v2`, поля: `created_at` (сегодня), `created_by=sergopipo`, `comment='снизил порог RSI'`. Бейдж «текущая» на `v2`.
- **Селекторы:** `[data-testid="strategy-save-version-btn"]`, `[data-testid="version-comment-input"]`, `[data-testid="versions-history-tab"]`, `[data-testid="version-row-{id}"]`.

#### S7.1.2 Откат к предыдущей версии
- **Предусловия:** в стратегии `id=1` существуют `v1` и `v2`, текущая = `v2`.
- **Шаги:**
  1. Открыть «История версий».
  2. Кликнуть «Восстановить» на `v1`.
  3. Подтвердить в модалке.
- **Ожидаемый результат:** создаётся новая версия `v3` (копия `v1`), помечена «текущая». `v1` и `v2` сохранены. Редактор показывает blocks_xml из `v1`.
- **Гарантия:** `v2` НЕ удалена (правило C4: откат = новая версия).

#### S7.1.3 Diff между версиями
- **Предусловия:** в стратегии есть `v1` и `v2` с разными blocks_xml.
- **Шаги:**
  1. В истории кликнуть «Сравнить с v1» на `v2`.
- **Ожидаемый результат:** открывается панель diff; добавленные/удалённые блоки подсвечены.

#### S7.1.4 Edge: пустой комментарий
- **Шаги:** кликнуть «Сохранить версию» без комментария.
- **Ожидаемый результат:** версия создаётся с `comment=null`, в истории отображается «—».

---

### 7.2 Grid Search (BACK1 + FRONT2) — контракт C5

#### S7.2.1 Запуск Grid Search и отображение heatmap
- **Предусловия:** стратегия `id=1` с двумя параметрами (`rsi_period`, `rsi_threshold`).
- **Шаги:**
  1. Открыть `/backtest/launch?strategy_id=1`.
  2. Активировать «Grid Search».
  3. Задать ranges: `rsi_period=[10,14,20]`, `rsi_threshold=[25,30,35]` → 9 комбинаций.
  4. Нажать «Запустить».
  5. Дождаться WS-сообщений (`/ws/backtest/{job_id}`) до `status='done'`.
- **Ожидаемый результат:** прогресс 0→100, по завершении — heatmap 3×3, каждая ячейка показывает Sharpe, цвет по градиенту. Клик на ячейку открывает детали.
- **Селекторы:** `[data-testid="grid-search-toggle"]`, `[data-testid="grid-range-{param}"]`, `[data-testid="grid-heatmap"]`, `[data-testid="grid-cell-{i}-{j}"]`.

#### S7.2.2 Hard cap N комбинаций (edge)
- **Шаги:** задать ranges, дающие > 1000 комбинаций (например 100×100).
- **Ожидаемый результат:** клиент показывает предупреждение «слишком много комбинаций», кнопка «Запустить» дизаблится. Backend (если запрос пройдёт) вернёт 400 с сообщением о лимите.

---

### 7.3 Экспорт CSV/PDF (BACK2)

#### S7.3.1 Экспорт CSV
- **Предусловия:** успешный бэктест `id=42` (мок).
- **Шаги:** на странице результатов клик «Экспорт → CSV».
- **Ожидаемый результат:** скачивается файл `backtest_42_<date>.csv`, открывается, содержит колонки `entry_time, exit_time, ticker, side, qty, entry_price, exit_price, pnl`. Заголовки на русском или согласованы.
- **Селекторы:** `[data-testid="export-menu"]`, `[data-testid="export-csv"]`. Использовать `page.waitForEvent('download')`.

#### S7.3.2 Экспорт PDF
- **Шаги:** клик «Экспорт → PDF».
- **Ожидаемый результат:** скачивается `backtest_42_<date>.pdf` ≥ 5 KB, открывается без ошибок. Содержит метрики (Sharpe, P&L, Win Rate), таблицу сделок, equity curve.

---

### 7.6 Инструменты рисования (FRONT1)

#### S7.6.1 Трендовая линия persist
- **Предусловия:** график SBER, 1H.
- **Шаги:**
  1. Активировать тулбар → «Трендовая линия».
  2. Кликнуть две точки на графике.
  3. Перезагрузить страницу.
- **Ожидаемый результат:** линия восстановлена в тех же координатах. Persist в `localStorage` ключ `drawings:{user_id}:{ticker}:{tf}`.
- **Селекторы:** `[data-testid="drawing-tool-trend"]`, `[data-testid="drawing-canvas"]`.

#### S7.6.2 Drag горизонтального уровня
- **Шаги:** добавить горизонтальный уровень → перетащить мышью на новое значение.
- **Ожидаемый результат:** уровень обновился; на refresh — сохранён.

#### S7.6.3 Удаление прямоугольной зоны через контекстное меню
- **Шаги:** добавить зону → ПКМ → «Удалить».
- **Ожидаемый результат:** зона удалена; refresh подтверждает удаление в localStorage.

#### S7.6.4 Edge: переключение тикера
- **Шаги:** нарисовать линию на SBER → переключить на GAZP → вернуться на SBER.
- **Ожидаемый результат:** линия SBER восстановлена; на GAZP — пусто.

---

### 7.7 Дашборд-виджеты (FRONT1 + FRONT2)

#### S7.7.1 Виджет «Баланс» (значение + sparkline + дельта)
- **Предусловия:** мок `/api/v1/account/balance` возвращает значение и series последних 24h.
- **Шаги:** открыть `/dashboard`.
- **Ожидаемый результат:** виджет показывает значение в формате `1 234 567,89 ₽`, sparkline отрисован (SVG/canvas), стрелка ↑/↓ цветом (зелёный/красный) и значение дельты.
- **Селекторы:** `[data-testid="widget-balance"]`, `[data-testid="balance-sparkline"]`, `[data-testid="balance-delta"]`.

#### S7.7.2 Health indicator реагирует на CB-state
- **Предусловия:** мок `/api/v1/health` сначала `circuit_breaker:'ok'`, затем `'tripped'`.
- **Шаги:**
  1. Открыть `/dashboard`, проверить зелёный индикатор CB.
  2. Эмитировать WS-событие `health_changed` с `circuit_breaker:'tripped'`.
- **Ожидаемый результат:** индикатор CB становится красным, рядом текст «CB сработал».
- **Селекторы:** `[data-testid="widget-health"]`, `[data-testid="health-cb"]`, `[data-testid="health-tinvest"]`, `[data-testid="health-scheduler"]`.

#### S7.7.3 Мини-график активной позиции
- **Предусловия:** мок `/api/v1/positions` возвращает позицию SBER 100 шт.
- **Ожидаемый результат:** карточка с тикером, кол-вом, текущей ценой, P&L, мини-графиком цены за день.

---

### 7.8 First-run wizard (FRONT2 + BACK2) — контракт C6

#### S7.8.1 Новый юзер — wizard показывается, 5 шагов, complete
- **Предусловия:** `/api/v1/users/me` возвращает `wizard_completed_at: null`.
- **Шаги:**
  1. Войти → wizard открывается автоматически.
  2. Шаг 1 «Приветствие» → Далее.
  3. Шаг 2 «Дисклеймер» → отметить чекбокс «Принимаю» → Далее.
  4. Шаг 3 «Брокер» → выбрать paper → Далее.
  5. Шаг 4 «Уведомления» → переключить in-app on, email off → Далее.
  6. Шаг 5 «Финиш» → Готово.
- **Ожидаемый результат:** `POST /api/v1/users/me/wizard/complete` отправлен; модалка закрывается; пользователь на `/dashboard`. `GET /me` возвращает `wizard_completed_at != null`.
- **Селекторы:** `[data-testid="wizard-modal"]`, `[data-testid="wizard-step-{1..5}"]`, `[data-testid="wizard-next"]`, `[data-testid="wizard-finish"]`, `[data-testid="wizard-disclaimer-checkbox"]`.

#### S7.8.2 Повторный заход — wizard НЕ показывается
- **Предусловия:** `wizard_completed_at != null`.
- **Ожидаемый результат:** wizard не открывается; `/dashboard` сразу.

#### S7.8.3 Edge: нельзя пропустить дисклеймер без галки
- **Шаги:** на шаге 2 не отмечать чекбокс → нажать «Далее».
- **Ожидаемый результат:** кнопка «Далее» дизаблена либо клик показывает inline-ошибку «отметьте принятие рисков».

---

### 7.9 Backup/restore (OPS + BACK1)

#### S7.9.1 Smoke: ручной бэкап через CLI
- **Шаги:**
  1. В терминале (с реальным backend): `cd Develop/backend && .venv/bin/python -m app.cli.backup`.
- **Ожидаемый результат:** в `Develop/backend/backups/` появился файл `backup_<timestamp>.db.gz`. Размер > 0. Не падает.
- **Тип теста:** spawn subprocess из Playwright (`test.beforeAll`) или отдельный pytest. Если CLI ещё не готов в момент написания теста — `test.skip` с тикетом `S7R-BACKUP-CLI`.

#### S7.9.2 Восстановление через CLI
- **Шаги:** `python -m app.cli.restore --from backups/backup_<latest>.db.gz --target /tmp/restored.db`.
- **Ожидаемый результат:** файл `/tmp/restored.db` создан, sqlite-валиден, в нём есть таблица `users` с записью `sergopipo`.

#### S7.9.3 Ротация (keep 7)
- **Шаги:** создать 10 фейковых бэкапов с разными датами → запустить ротацию.
- **Ожидаемый результат:** в директории остаются 7 свежих по `mtime`, старые удалены.

> Замечание: `7.9` — преимущественно backend/CLI. UI-теста нет; smoke может быть pytest, но в плане E2E фиксируем как Playwright spec, который вызывает subprocess.

---

### 7.12 NotificationService singleton (BACK2) — контракт C7

#### S7.12.1 Регресс 13 типов уведомлений после DI-рефакторинга
- **Предусловия:** реальный backend, sergopipo, in-app + email + Telegram моки.
- **Шаги:** для каждого из 13 event_type триггерить событие через тестовый эндпоинт `/api/v1/_test/emit-event` (или прямой fixture в pytest, обёрнутый E2E).
- **Ожидаемый результат:** в UI колокольчик `[data-testid="notification-bell"]` показывает unread count = 13; список содержит все 13 типов; ни одно событие не теряется.
- **Покрытие:** регрессия `s6-notifications.spec.ts` остаётся зелёной.

---

### 7.13 5 event_type → runtime (BACK1) — MR.5

> Источник: `sprint_design.md` Приложение C.

#### S7.13.1 `trade_opened` → notification
- **Предусловия:** session активна, мок paper-broker возвращает успешное открытие позиции.
- **Шаги:**
  1. Открыть `/trading`, запустить session.
  2. Триггерить сигнал на BUY (через `_test` endpoint или мок-стратегию).
- **Ожидаемый результат:** в колокольчике появляется уведомление `Открыта позиция: SBER, 100 шт`. В Telegram-моке — сообщение. В email-моке — письмо (если включено).

#### S7.13.2 `partial_fill`
- **Шаги:** триггерить событие `partial_fill` от broker (мок).
- **Ожидаемый результат:** уведомление `Частичное исполнение: SBER 50 из 100`.

#### S7.13.3 `order_error`
- **Шаги:** мок broker возвращает ошибку выставления.
- **Ожидаемый результат:** уведомление `Ошибка ордера: ...`. Severity = error.

#### S7.13.4 `all_positions_closed`
- **Шаги:** закрыть последнюю активную позицию.
- **Ожидаемый результат:** уведомление `Все позиции закрыты`.

#### S7.13.5 `connection_lost` / `connection_restored`
- **Шаги:** в моке T-Invest gRPC симулировать reconnect loop.
- **Ожидаемый результат:** два последовательных уведомления — потеря и восстановление.

> **Verification:** `grep -rn "create_notification" Develop/backend/app/trading/ Develop/backend/app/broker/` — должно встречаться для каждого из 5 типов. Это backend-проверка, фиксируется ARCH в midsprint.

---

### 7.14 Telegram inline-кнопки (BACK2) — контракт C8

#### S7.14.1 Callback `open_session:{id}` → deep link
- **Предусловия:** in-app stub Telegram бота (mock CallbackQueryHandler).
- **Шаги:**
  1. Эмитировать callback `open_session:42`.
  2. Через бот вернуть deep link `/sessions/42`.
  3. В тесте перейти по этому URL.
- **Ожидаемый результат:** открывается `/sessions/42`, страница SessionDetail рендерится без ошибок.

#### S7.14.2 Callback `open_chart:SBER` → deep link
- **Шаги:** эмитировать callback `open_chart:SBER`.
- **Ожидаемый результат:** deep link `/chart?ticker=SBER`, график SBER загружается.

> Параллельно — pytest на backend проверяет, что `CallbackQueryHandler` валидирует origin (chat_id принадлежит user). E2E-чек — frontend часть.

---

### 7.15 WS карточки сессий (BACK1 + FRONT1) — контракт C1

#### S7.15.1 Real-time обновление без polling
- **Предусловия:** sergopipo, открыта `/trading`.
- **Шаги:**
  1. Подключиться к `/ws/trading-sessions/{user_id}` (мок WS-сервер в Playwright).
  2. Эмитировать событие `{event:'trade_filled', session_id:1, payload:{ticker:'SBER', qty:100}}`.
- **Ожидаемый результат:** карточка сессии 1 обновляется без перезагрузки страницы (последняя сделка SBER 100). Количество HTTP-запросов `/api/v1/trading/sessions` НЕ растёт после WS-сообщения (проверка через `page.on('request')`).
- **Регресс:** старый polling (10s) больше не делается.

#### S7.15.2 Reconnect при разрыве WS
- **Шаги:** открыть `/trading` → закрыть WS на сервере → подождать 3s → проверить попытку реконнекта.
- **Ожидаемый результат:** клиент пытается реконнектиться (видно в WS log); UI показывает индикатор «переподключение»; после восстановления — индикатор пропадает, события снова доходят.

---

### 7.16 Интерактивные зоны + аналитика (FRONT1)

#### S7.16.1 Hover на зону сделки → выделение
- **Предусловия:** бэктест `id=42`, на графике 5 зон сделок.
- **Шаги:** mouse-hover на первую зону.
- **Ожидаемый результат:** контур зоны меняется на белый/яркий; tooltip показывает entry/exit/pnl.

#### S7.16.2 Клик на зону → панель деталей сделки
- **Шаги:** клик на зону.
- **Ожидаемый результат:** открывается боковая панель `[data-testid="trade-detail-panel"]` с полями: тикер, время входа/выхода, цены, P&L, причина выхода.

#### S7.16.3 Гистограмма P&L на вкладке «Обзор»
- **Шаги:** перейти на вкладку «Обзор» результатов бэктеста.
- **Ожидаемый результат:** гистограмма с бакетами P&L (цвета: зелёный для прибыльных, красный для убыточных), линия среднего, легенда. Селектор `[data-testid="pnl-histogram"]`.

#### S7.16.4 Donut Win/Loss/BE
- **Ожидаемый результат:** donut-диаграмма с тремя сегментами Win/Loss/Break-Even, числа в центре (например `60% Win`), легенда с долями. Селектор `[data-testid="win-loss-donut"]`.

---

### 7.17 Фоновый бэктест (BACK1 + FRONT1) — контракт C2

#### S7.17.1 Toast «бэктест запущен в фоне»
- **Предусловия:** открыта модалка `BacktestLaunchModal`.
- **Шаги:** клик `Запустить в фоне`.
- **Ожидаемый результат:** появляется toast-нотификация Mantine `Бэктест запущен в фоне`. Бейдж в шапке `[data-testid="bg-backtest-badge"]` инкрементируется (`0`→`1`).

#### S7.17.2 Модалка остаётся открытой
- **Ожидаемый результат:** после клика «в фоне» `BacktestLaunchModal` НЕ закрывается; пользователь может запустить ещё.

#### S7.17.3 Несколько параллельных в dropdown
- **Шаги:** запустить 3 бэктеста подряд «в фоне».
- **Ожидаемый результат:** бейдж = 3; dropdown открывается по клику и показывает 3 строки с прогрессом каждого (`progress` из WS C2).

#### S7.17.4 Завершение → бейдж декрементируется
- **Шаги:** через WS отправить `{job_id, status:'done'}`.
- **Ожидаемый результат:** бейдж `3`→`2`. В dropdown строка job отображается как «готово» с ссылкой на результат.

---

### 7.18 / 7.19 AI слэш-команды (BACK2 + FRONT1) — контракт C3

#### S7.18-19.1 Dropdown по `/`
- **Шаги:** открыть `/ai-chat`, в инпуте ввести `/`.
- **Ожидаемый результат:** появляется dropdown с 5 командами: `/chart`, `/backtest`, `/strategy`, `/session`, `/portfolio`. Стрелки/Enter работают. Селектор `[data-testid="ai-commands-dropdown"]`.

#### S7.18-19.2 `/chart EURUSD` → enriched prompt
- **Шаги:** ввести `/chart SBER` → Enter.
- **Ожидаемый результат:** в чат уходит `POST /api/v1/ai/chat` body `{message:'...', context:[{type:'chart', id:'SBER'}]}`. AI-ответ цитирует тикер. В чате рендерится «контекстный блок» SBER с превью графика.

#### S7.18-19.3 Edge: чужой `/strategy 999` → 403
- **Предусловия:** стратегия `id=999` принадлежит другому юзеру.
- **Шаги:** ввести `/strategy 999`.
- **Ожидаемый результат:** backend возвращает 403 «доступ запрещён»; в чате toast/inline ошибка. AI prompt НЕ отправлен.

---

### 7.R ARCH-приёмка

Не требует отдельных E2E. Сводный регрессионный прогон фиксируется в `arch_review_s7.md`.

---

## Регрессии — какие ui-checks должны остаться зелёными

> База: `Спринты/ui_checklist_s5r.md`. Все 119 baseline тестов после S6 Review должны продолжать проходить. Критичные группы:

| Группа | Файлы | Что проверяет | Связь с S7 |
|--------|-------|---------------|------------|
| Auth | `auth.spec.ts` | login/logout/refresh, ProtectedRoute | 7.8 wizard не должен ломать redirect |
| Dashboard | `dashboard.spec.ts` | таблица стратегий, тикеры | 7.7 виджеты не должны ломать раскрытие |
| Backtest launch | `backtest-launch.spec.ts`, `s5r-backtest-launch-trading.spec.ts` | модалка запуска | 7.17 «в фоне» — добавляет кнопку, но «Запустить» остаётся |
| Backtest results | `backtest-results.spec.ts` | результаты, метрики | 7.16 — добавляет вкладки, не ломает существующие |
| Blockly | `blockly.spec.ts`, `s4-review-blockly-backtest.spec.ts` | редактор стратегий | 7.1 версионирование — добавляет кнопку «Сохранить версию» |
| Strategy | `strategy.spec.ts` | CRUD стратегий | 7.1 — таб «История версий» |
| Charts | `s5-chart-timeframes.spec.ts`, `s6-chart-stability.spec.ts` | графики, TF, WS | 7.6 рисование — overlay поверх графика, не должен ломать свечи; 7.16 зоны бэктеста — на отдельной странице |
| Trading | `s5-paper-trading.spec.ts` | paper-сессии | 7.15 WS — заменяет polling, карточки должны обновляться |
| Notifications | `s6-notifications.spec.ts`, `s6-notification-settings.spec.ts`, `s6-critical-banner.spec.ts` | колокольчик, settings, баннер | 7.12 DI-рефакторинг — все 13 типов продолжают приходить; 7.13 — добавляет 5 новых сайтов publish |
| AI | `ai-chat.spec.ts`, `ai-settings.spec.ts`, `s4-review-ai-chat.spec.ts` | чат, провайдеры | 7.18/7.19 — расширяет request schema, обратная совместимость |
| Account | `s5-account.spec.ts` | balance, positions | 7.7 виджеты используют тот же endpoint |
| Favorites | `s5-favorites.spec.ts` | избранные тикеры | 7.6 рисование привязывается к ticker — не должно ломать favorites |
| Circuit Breaker | `s5-circuit-breaker.spec.ts` | CB-state | 7.7 health-индикатор использует ту же информацию |
| Navigation | `s5-navigation.spec.ts` | sidebar, header | 7.17 бейдж — новый элемент в шапке, не должен ломать nav |
| Ticker logos | `s5-ticker-logos.spec.ts` | T-Invest CDN | без изменений |
| S4/S5R review | `s4-review-*.spec.ts`, `s4-review.spec.ts` | сводные | без изменений |

**Критерий регрессии:** при midsprint и в W3 — все 119 baseline остаются passed. Любое падение из-за изменения контракта/UI — блокирующая ошибка.

---

## Performance / non-functional

| Сценарий | Метрика | Лимит |
|----------|---------|-------|
| 7.15 WS latency | время от backend `publish` до UI update | < 500 ms (p95 в локальном моке) |
| 7.17 параллельные бэктесты | макс N одновременных jobs | проверить ARCH-design (предположительно 5–10) |
| 7.2 Grid Search | hard cap N комбинаций | 1000 (или согласовано в `arch_design_s7.md`) |
| 7.6 рисование | persist в localStorage | < 50 ms на сохранение, не блокирует UI |

> Performance-метрики измеряются через `page.evaluate(() => performance.now())` в локальной среде. Они индикативные, не блокирующие приёмку S7. Полноценный perf-аудит — задача S8.

---

## Skip-тикеты (предварительно)

При написании тестов W1/W2 любой `test.skip` оформляется как `S7R-<NAME>` + карточка в `Спринты/Sprint_8_Review/backlog.md`.

Возможные кандидаты на skip (известные риски — фиксируются по факту в W1):

| Кандидат | Причина возможного skip |
|----------|--------------------------|
| `S7R-BACKUP-CLI` | если 7.9 CLI восстановление не успеет в W2 |
| `S7R-WIZARD-MOCK` | если 7.8 backend `wizard_completed_at` не успеет в W2 |
| `S7R-AI-CONTEXT-RENDER` | если 7.19 рендер контекстного блока вынесен за пределы S7 |

---

## Шаги верификации

> Правило памяти `feedback_e2e_testing.md`:
>
> 1. Описание (ВЫШЕ — заполнено QA на W0). ✅
> 2. Инфраструктура — `preflight_checklist.md` пройден на W0 (см. отчёт `reports/QA_W0_test_plan.md`).
> 3. Написание тестов — `Develop/frontend/e2e/sprint-7/*.spec.ts` (W1 для debt 7.13–7.17, W2 для фич).
> 4. Запуск — `cd Develop/frontend && npx playwright test`.
> 5. Верификация — passed/failed зафиксирован в `Sprint_7/arch_review_s7.md`.
>
> QA не отчитывается «тесты написаны» без раздела «тесты прогнаны» с цифрами.

## Критерий приёмки 7.11

- ≥ 119 baseline тестов passed (S6 Review baseline).
- ≥ 15 новых тестов passed (по 1+ на feature-задачу из 7.1, 7.2, 7.3, 7.6, 7.7, 7.8, 7.9, 7.12, 7.13, 7.14, 7.15, 7.16, 7.17, 7.18, 7.19).
- 0 failed.
- skipped — только с указанием тикета `S7R-<SHORT-NAME>` и карточкой в `Спринты/Sprint_8_Review/backlog.md`.
