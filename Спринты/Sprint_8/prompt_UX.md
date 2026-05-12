---
sprint: 8
agent: UX
role: UX финальный юзабилити-тест M4 + ui_checklist_s8.md
wave: 3
depends_on: [ARCH W0, DEV-3 W1 (Drawing editing + intraday coords), DEV-4 W1+W2 (Admin role, ErrorBoundary, Strategy status UI, Dashboard widgets, Wizard test-button, Event sync labels, Plotly Dash)]
---

# Роль

Ты — UX-дизайнер MOEX-терминала + ручной QA-инженер (senior). Зона ответственности на W3 Sprint 8:

1. Провести **финальный юзабилити-тест M4** по 6 сценариям «новый пользователь от регистрации до первой сделки + бэктест + bg-backtest + admin + drawing tools».
2. Обновить `ui_checklist_s7.md` → `ui_checklist_s8.md` — дополнить проверками за S8 (≥ 50 новых пунктов).
3. Зафиксировать UX-баги: тривиальные (text/spacing/margin) — фиксить немедленно, архитектурные — заносить в `Sprint_8_Review/backlog.md` (или `Sprint_9_Review/backlog.md` если уже создан).
4. Собрать скриншоты до/после каждого фикса; финальный отчёт `reports/UX_W3_report.md` по 9-секционному шаблону.

Источник истины для UI-стандартов проекта — `Спринты/ui_checklist_s7.md` (база) + UX-макеты `Sprint_7/ux/` (если применимо для существующих фич). Стек: Mantine v7 + lightweight-charts + Plotly (для admin/metrics).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы убедись, что все условия выполнены. Если хотя бы одно не выполнено — **НЕ начинай** тестирование, верни `БЛОКЕР: <описание>`.

```
1. Окружение: Node >= 18, pnpm, Python 3.11+, Playwright установлен (`npx playwright --version`).
2. Зависимости предыдущих DEV:
   - DEV-3 W1 завершён: drawing editing (drag/угол/sequential coords) — `S7R-DRAWING-EDITING`, `S7R-DRAWING-INTRADAY-COORDS`.
   - DEV-4 W1 завершён: Admin Sidebar пункт, ProtectedAdminRoute, ErrorBoundary, Strategy status UI.
   - DEV-4 W2 завершён: 3 dashboard widget'а (sparkline 24h, health extended, balance history range), Wizard Telegram test button, 4 event_type labels.
   - BACK1 W2 завершён: Plotly Dash `/admin/metrics` страница.
3. Существующие файлы: ui_checklist_s7.md в `Спринты/` (база).
4. База данных: миграция `users.is_admin` применена, тестовый пользователь `sergopipo` доступен (пароль спросить у заказчика).
5. Внешние сервисы: backend uvicorn запущен, frontend dev-сервер запущен (либо CI-billed e2e mocks).
6. Baseline для скриншотов: запустить app, залогиниться, убедиться, что нет 500-ошибок на основных страницах.
```

Реальная проверка перед запуском (правило S5R.5):
- Запустить backend (`cd Develop/backend && uvicorn app.main:app --reload`) и frontend (`cd Develop/frontend && pnpm dev`).
- Проверить, что DEV-отчёты W1+W2 содержат подтверждение «✅ подключено» по контрактам C-S8-1..C-S8-9.
- Если хотя бы один компонент не задеплоен — `БЛОКЕР: <DEV-X> не завершил <задача Y>`.

# Обязательные плагины для этой задачи

| Плагин | Нужен? | Fallback (если MCP недоступен) |
|--------|--------|-------------------------------|
| pyright-lsp | нет | — |
| typescript-lsp | нет (мелкие text-фиксы достаточно `npx tsc --noEmit` ручкой) | `cd Develop/frontend && npx tsc --noEmit` |
| context7 | иногда (для документации Mantine при рекомендациях по фиксу) | WebSearch |
| **playwright** | **ДА** — для скриншотов каждого экрана из 6 сценариев + визуальная регрессия | Скриншот руками через Chrome DevTools |
| **frontend-design** | **ДА** — для проверки визуальной консистентности + при найденных багах через `/frontend-design` (рекомендация фикса) | — |
| code-review | нет | — |
| superpowers (TDD) | нет | — |

**Правило:** UX не пишет код для production (max — text-strings, spacing, Mantine props). Если требуется логический фикс — заносить в S9-backlog, не патчить логику в обход DEV.

# Обязательное чтение (BEFORE any testing)

Прочитай **все** перечисленные ниже документы перед запуском первого сценария. Без контекста промахи неминуемы.

1. **`Спринты/Sprint_8/arch_design_s8.md`** — секция 8.4 «W3 Поток B — UX финальный юзабилити», секция 8.5 «Cross-DEV contracts» (C-S8-1..C-S8-9).
2. **`Спринты/Sprint_8/execution_order.md`** — раздел «W3 Поток B».
3. **`Спринты/ui_checklist_s7.md`** — база для расширения. Скопировать целиком как старт `ui_checklist_s8.md`, затем дополнить.
4. **`Спринты/Sprint_7/reports/UX_W3_polish.md`** — отчёт UX за S7 (если есть) — формат и тон.
5. **`Спринты/Sprint_8/changelog.md`** — что уже реализовано в W1-W2 (фактический scope).
6. **Память:**
   - `feedback_ui_checklist_update.md` — обновлять чеклист после КАЖДОГО спринта.
   - `feedback_e2e_testing.md` — полный цикл E2E.
   - `user_test_credentials.md` — пользователь `sergopipo`, пароль спросить у заказчика.
7. **Цитаты из CLAUDE.md проекта (дословно):**
   > «Обновлять UI-чеклист после каждого спринта — дополнять e2e/ui-checks/ и ui_checklist новыми проверками»
8. **Цитата из arch_design_s8.md §8.4 (дословно):**
   > «UX финальный юзабилити-тест: Сценарии новый пользователь от регистрации до сделки. Обновить `ui_checklist_s7.md` → `ui_checklist_s8.md`. UX-баги фиксить или в S9-backlog.»

# Рабочая директория

`Спринты/Sprint_8/` (создаём файлы в `Sprint_8/` + `Sprint_8/reports/` + `Sprint_8/ux_screenshots/`).

# Контекст существующего кода

Файлы, которые UX **читает** (контекст, не модифицирует):
- `Develop/frontend/src/pages/DashboardPage.tsx` — 3 widget'а из S7 (балланс, health, активные позиции) + новые после S8 (sparkline 24h, health extended, balance range).
- `Develop/frontend/src/pages/StrategyListPage.tsx` — таблица стратегий + новый Strategy status UI (контекстное меню).
- `Develop/frontend/src/pages/BacktestResultsPage.tsx` — графики, гистограмма P&L, donut Win/Loss, кнопка «Запустить торговлю» (LaunchSessionModal).
- `Develop/frontend/src/pages/ChartPage.tsx` — drawing tools + sequential coords intraday.
- `Develop/frontend/src/pages/NotificationSettingsPage.tsx` — 12-13 event_type labels (S8 синхронизация UI ↔ EVENT_MAP).
- `Develop/frontend/src/components/FirstRunWizard/` — 4-шаговый wizard + Telegram test button (S8).
- `Develop/frontend/src/pages/AdminPage.tsx` (новая в S8) — Sidebar пункт для is_admin=true.
- `Develop/frontend/src/components/ErrorBoundary/` (новый в S8) — fallback UI.
- `Develop/backend/app/admin/router.py` (новый в S8) — Plotly Dash mount на `/admin/metrics`.

Файлы, которые UX **может изменять** (мелкие фиксы, без логики):
- `Develop/frontend/src/pages/*.tsx` — text-strings, spacing margin/padding, Mantine props (`size`, `mt`, `mb`, `color`).
- `Develop/frontend/src/locales/ru.json` (если есть) — переводы строк.
- `Develop/frontend/src/components/*/styles.module.css` — отступы, gap, alignment.

**Запрещено** UX-агенту:
- Менять props, передающие данные (`value`, `onChange`, `onClick` handlers).
- Менять API-вызовы, типы, импорты.
- Менять условную логику рендера.

Если найден баг логики — фиксируй в backlog, не патчь.

# Задачи

## Задача 1: Юзабилити-сценарии — 6 сквозных flow (~3ч)

Прогнать **каждый** сценарий ниже **вручную**, делая Playwright-скриншот на каждом ключевом шаге (≥ 5 скриншотов на сценарий). Скриншоты сохранять в `Спринты/Sprint_8/ux_screenshots/scenario_<N>_<step>.png`.

### Сценарий 1: Новый пользователь от регистрации до завершения wizard

**Шаги:**
1. `GET /register` — заполнить email, password, submit. **Expected:** редирект на confirmation, email пришёл (или mock).
2. Подтвердить email (клик по ссылке из mock-inbox или dev-link). **Expected:** редирект на `/login`.
3. Войти под новым пользователем. **Expected:** редирект на FirstRunWizard (т.к. `wizard_completed_at IS NULL`).
4. **Шаг 1 wizard** «Брокер ключи» — ввести T-Invest token (тестовый sandbox). **Expected:** валидация OK, кнопка Далее активна.
5. **Шаг 2 wizard** «AI настройки» — выбрать Claude/OpenAI provider, ввести API key. **Expected:** валидация OK.
6. **Шаг 3 wizard** «Watchlist» — добавить ≥ 1 тикер (например, SBER). **Expected:** в watchlist отображается.
7. **Шаг 4 wizard** «Notifications» — включить Telegram, ввести bot_token + chat_id, нажать кнопку **«Проверить подключение»** (новинка S8). **Expected:** toast «✅ Тестовое сообщение отправлено» или «❌ Ошибка с описанием».
8. Завершить wizard. **Expected:** редирект на `/dashboard`, `wizard_completed_at` записан, повторный логин не показывает wizard.

**Чем подтверждается S8 функционал:** Telegram test button (контракт C-S8-4), сохранение Telegram-настроек в `notification_settings` (правило памяти `project_wizard_notifications_save.md`).

### Сценарий 2: Создание стратегии → бэктест → запуск торговли

**Шаги:**
1. На `/dashboard` нажать «Создать стратегию». **Expected:** редирект на `/strategies/new` (Blockly editor).
2. В Blockly собрать стратегию (например, EMA crossover) + сохранить. **Expected:** strategy создан, видится в `/strategies`.
3. На `/strategies` нажать **новое контекстное меню** (S8) → проверить пункты «Active / Paused / Archived». **Expected:** клик меняет статус, бэйдж обновляется без перезагрузки.
4. Запустить бэктест: «Бэктест» → ввести параметры → submit. **Expected:** бэктест выполняется, прогресс отображается.
5. На `/backtests/:id/results` — проверить: график equity, маркеры сделок, **гистограмма P&L**, **donut Win/Loss**. **Expected:** все 4 секции рендерятся, hover/click зон работает.
6. Кнопка «Запустить торговлю из бэктеста» → **LaunchSessionModal** с предзаполненными параметрами. **Expected:** ticker, timeframe, initial_capital, strategy_id заполнены автоматически.
7. Запустить торговлю (paper-режим). **Expected:** редирект на `/trading/sessions/:id`, сессия активна.

**Чем подтверждается S8 функционал:** Strategy status change (контракт C-S8-2 / S7R-STRATEGY-STATUS-CHANGE-UI), LaunchSessionModal предзаполнение, backtest analytics (S7R-E2E-7.16).

### Сценарий 3: Live торговля → мониторинг → закрытие

**Шаги:**
1. На странице сессии: **карточка позиции** показывает ticker, qty, entry_price, текущая цена, P&L (dual % — daily + total). **Expected:** все поля заполнены.
2. **Маркеры сделок** на графике видны (зелёный треугольник вверх — BUY, красный вниз — SELL). **Expected:** маркеры в правильных координатах.
3. Sparkline 24h в виджете «Активные позиции» на дашборде. **Expected:** мини-график с данными за 24h (новинка S8 — S7R-WIDGET-SPARKLINE-24H).
4. **Health badge** в шапке: проверить цвет `cb_state` (зелёный/жёлтый/красный). **Expected:** соответствует backend `/health.cb_state` (новинка S8 — S7R-DASHBOARD-HEALTH-EXTENDED-FIELDS).
5. Через Telegram-бота отправить `/status`. **Expected:** reply с актуальными позициями.
6. Закрыть позицию вручную (кнопка «Закрыть»). **Expected:** ордер выставлен, P&L зафиксирован, маркер закрытия на графике.

**Чем подтверждается S8 функционал:** dashboard widgets (контракты C-S8-1, C-S8-2, C-S8-3), event_type labels синхронизированы (C-S8-9).

### Сценарий 4: Bg-backtest параллельные

**Шаги:**
1. Из BacktestLaunchModal нажать «В фоне» 3 раза (3 разные стратегии или 3 тикера). **Expected:** badge `bg-backtest-badge` в шапке = 3.
2. Дождаться завершения первого. **Expected:** badge декремент до 2, toast «Бэктест X завершён».
3. Клик по badge → dropdown с прогресс-барами + кнопками «Открыть результат» для завершённых. **Expected:** dropdown открывается, переход на результаты работает.
4. Попытка запустить 4-й параллельный (cap=3). **Expected:** toast «Превышен лимит параллельных бэктестов».

### Сценарий 5: Admin role (только если is_admin=true)

**Шаги:**
1. Через CLI (или БД) выставить `users.is_admin = True` для `sergopipo`. **Alternative:** проверить bootstrap — первый зарегистрированный пользователь получает is_admin=True.
2. Перелогиниться. **Expected:** в Sidebar появился пункт «Admin» (для обычного user — отсутствует).
3. Кликнуть «Admin» → редирект на `/admin/metrics`. **Expected:** ProtectedAdminRoute пропускает, обычный user получает 403.
4. Страница `/admin/metrics` (Plotly Dash, новинка S8) — графики рендерятся. **Expected:** ≥ 2 chart'а из structlog метрик (signal-to-order p95, Telegram p95).

**Чем подтверждается S8 функционал:** Admin role + Plotly Dash (контракты C-S8-7, C-S8-8 / эпик N).

### Сценарий 6: Drawing tools editing

**Шаги:**
1. На `/chart/:ticker` (timeframe — день) нарисовать трендовую линию. **Expected:** линия отображается.
2. **Перетащить** линию мышью (drag, новинка S8 — S7R-DRAWING-EDITING). **Expected:** линия перемещается плавно, persist в localStorage.
3. **Изменить угол** через handle на конце. **Expected:** угол меняется.
4. Перейти на **intraday timeframe** (5m или 15m) и нарисовать новую линию. **Expected:** sequential-index координаты сохраняются корректно (новинка S8 — S7R-DRAWING-INTRADAY-COORDS).
5. Backspace для удаления выделенной фигуры. **Expected:** фигура исчезает.
6. Cmd+Z для отмены. **Expected:** фигура восстанавливается.

**Чем подтверждается S8 функционал:** Drawing editing (S7R-DRAWING-EDITING + S7R-DRAWING-INTRADAY-COORDS).

### Дополнительная проверка: ErrorBoundary

- На любой странице искусственно вызвать ошибку компонента (через React DevTools: `throw new Error("test")` в state, или через mock неуспешного API). **Expected:** ErrorBoundary показывает fallback UI с кнопкой «Перезагрузить» + не падает вся страница (новинка S8 — S7R-FRONTEND-ERROR-BOUNDARY-MISSING).

## Задача 2: Обновить `ui_checklist_s8.md` (~3ч)

1. **Скопировать** `Спринты/ui_checklist_s7.md` → `Спринты/ui_checklist_s8.md`. В header написать:
   > «Расширяет `ui_checklist_s7.md` — все проверки оттуда продолжают применяться. Применяется при приёмке S8 и QA-прогонах перед production rollout M4.»

2. **Добавить новые секции** (≥ 50 пунктов, по 1 строке проверки = 1 пункт):

### S8.1 Admin role (~8 пунктов)
- [ ] Sidebar показывает пункт «Admin» только если `useAuthStore.user.is_admin === true`.
- [ ] Обычный пользователь (`is_admin=false`) при попытке открыть `/admin/metrics` получает редирект на `/dashboard` (ProtectedAdminRoute).
- [ ] Backend `/admin/*` endpoints отдают 403 без `is_admin=true`.
- [ ] Bootstrap: первый зарегистрированный пользователь автоматически получает `is_admin=true`.
- [ ] CLI `python -m app.cli.users grant_admin <username>` работает и логирует действие.
- [ ] `/auth/me` response содержит поле `is_admin: bool`.
- [ ] (далее по контрактам C-S8-7, C-S8-8)

### S8.2 Plotly Dash /admin/metrics (~5 пунктов)
- [ ] Страница `/admin/metrics` рендерится без 500-ошибок.
- [ ] Отображены ≥ 2 chart'а (signal-to-order p95, Telegram webhook p95).
- [ ] Графики обновляются при reload.
- [ ] data-testid="admin-metrics-page" присутствует.
- [ ] Без is_admin — 403 / редирект.

### S8.3 ErrorBoundary (~4 пунктов)
- [ ] При throw в любом widget — рендерится fallback UI (не белый экран).
- [ ] Кнопка «Перезагрузить страницу» работает.
- [ ] data-testid="error-boundary-fallback".
- [ ] Per-widget ErrorBoundary локализует ошибку (соседние widget'ы рендерятся).

### S8.4 Strategy status change UI (~4 пунктов)
- [ ] Контекстное меню (правый клик / 3-точки) на строке стратегии — пункты Active / Paused / Archived.
- [ ] Клик меняет статус через PATCH `/strategies/{id}` без перезагрузки страницы.
- [ ] Badge цвет меняется (green/yellow/grey).
- [ ] Toast уведомление «Статус обновлён».

### S8.5 Dashboard widgets новые (~8 пунктов)
- [ ] Sparkline 24h в виджете «Активные позиции» — мини-график с реальными OHLCV-точками (контракт C-S8-2).
- [ ] Виджет «Health» расширен полями: `cb_state`, `tinvest_connected`, `scheduler_running` (контракт C-S8-1).
- [ ] Health badge цвета: зелёный (ok), жёлтый (warn), красный (triggered).
- [ ] Виджет «Баланс» — sparkline история обрезается с момента первой активности (контракт C-S8-3, S7R-DASHBOARD-BALANCE-SPARKLINE-RANGE).
- [ ] Polling 30s для /health (или WS если S7R-HEALTH-WS-MIGRATION закрыт в W3).
- [ ] States: loading skeleton, error retry, empty — все 3 widget'а.
- [ ] data-testid="dashboard-widget-sparkline24h|health-extended|balance-range".

### S8.6 Wizard Telegram test button (~3 пунктов)
- [ ] На шаге 4 wizard есть кнопка `data-testid="wizard-telegram-test"`.
- [ ] Клик отправляет `POST /notifications/telegram/test` (контракт C-S8-4).
- [ ] Toast «✅ Сообщение отправлено» / «❌ Ошибка: <message>».

### S8.7 Event type labels синхронизация (~6 пунктов)
- [ ] NotificationSettingsPage содержит 12 (или 13) event_type, синхронных с backend EVENT_MAP.
- [ ] 4 новых backend-типа (S8): `session_started`, `session_stopped`, `order_placed`, `trade_filled` — лейблы добавлены.
- [ ] 5 UI-only типов (`session_recovered`, `backtest_completed`, `daily_stats`, `corporate_action`, `price_alert`) — publish-сайты подключены.
- [ ] Включить Telegram + Email для типа `trade_filled` → реальная сделка → доставка в 3 канала.
- [ ] data-testid="event-type-row-<event_name>" для каждого.
- [ ] (Расширение через контракт C-S8-9.)

### S8.8 Drawing tools editing (~6 пунктов)
- [ ] Drag фигуры мышью — плавное перемещение, persist в localStorage.
- [ ] Изменение углов через handle.
- [ ] Sequential-index координаты на intraday (5m/15m) — корректные.
- [ ] Backspace удаляет выделенную фигуру.
- [ ] Cmd+Z (undo) восстанавливает.
- [ ] Контекстное меню «Удалить» работает.

### S8.9 API contract / paginated types (~3 пунктов)
- [ ] Все API-вызовы с `response_model=PaginatedResponse` корректно типизированы на frontend (нет runtime crash «cannot read items of undefined»).
- [ ] data-testid="loading-paginated" присутствует при загрузке.
- [ ] Empty state «Нет данных» рендерится при `items.length === 0`.

### S8.10 Performance / Observability (~3 пунктов)
- [ ] `/admin/metrics` показывает p95 signal-to-order < 500ms (целевая ТЗ).
- [ ] `/admin/metrics` показывает p95 Telegram webhook < 3000ms.
- [ ] Dashboard LCP < 2s (chrome devtools manual measurement).

**Итого:** ≥ 50 новых пунктов. Можно дополнить дополнительными edge-cases по факту тестирования.

3. В конец `ui_checklist_s8.md` добавить раздел «Известные DELTA vs макет / S9-backlog» — список несовпадений UI с UX-макетами S7 (если есть) и архитектурные баги для S9.

## Задача 3: UX-баги фиксить или фиксировать в backlog (~2ч)

Для каждого обнаруженного бага:

### 3.1 Тривиальные баги (фиксить немедленно)

Допустимые правки UX-агентом:
- Опечатки в text-strings (russian).
- Неправильный spacing (`mt={4}` → `mt="md"`, gap, padding).
- Mantine props стилизации: `c="dimmed"`, `size`, `radius`.
- ARIA-атрибуты (`aria-label`, `role`).
- data-testid для будущих E2E.

Процесс:
1. Скриншот **до** фикса → `ux_screenshots/bug_<N>_before.png`.
2. Сделать Edit с минимальным изменением.
3. Запустить `cd Develop/frontend && npx tsc --noEmit` — убедиться, что нет ошибок.
4. Скриншот **после** фикса → `ux_screenshots/bug_<N>_after.png`.
5. Записать в отчёт: «BUG-<N>: <описание> — FIXED inline».

### 3.2 Архитектурные баги (в backlog)

Если правка требует:
- Изменения props/state/handlers.
- Изменения API.
- Новых компонентов или routing.
- Изменения backend.

→ **не патчить**, занести карточку в `Sprint_8_Review/backlog.md` (или `Sprint_9_Review/backlog.md` если уже создан). Формат:

```markdown
## S8R-UX-<SHORT-NAME>
- **Severity:** medium-high / medium / low
- **Симптом:** <что увидел UX>
- **Repro:** <шаги>
- **Скриншот:** `Sprint_8/ux_screenshots/bug_<N>_before.png`
- **Гипотеза:** <причина>
- **Часы:** ~Xч
- **Роль:** FRONT2 / BACK1 / ...
```

Пометить severity (medium-high = блокирует release, medium = должно быть в S9 первым, low = nice-to-have).

# Опциональные задачи

- **PASS** или **SKIP — reason:** для каждой ниже:
  1. **frontend-design / `/frontend-design` для рекомендации фиксов** — вызвать если найден ≥ 1 серьёзный визуальный баг и нужна рекомендация по компоненту-замене.
  2. **Visual regression diff** через `@playwright/test --update-snapshots` — обновить snapshot-файлы для изменённых компонентов (если уже есть screenshot-tests).

Пропустить только с явным **SKIP — reason: <причина>**.

# Skip-тикеты в тестах

Не применимо — UX не пишет автоматические тесты. Если UX вручную пропускает сценарий (например, sandbox T-Invest недоступен) — указать **SKIP — reason** в отчёте + создать карточку `S8R-UX-SKIP-<NAME>` в backlog.

# Тесты

Не применимо (manual usability testing). Каждый сценарий должен оставить:
- ≥ 5 скриншотов в `Sprint_8/ux_screenshots/scenario_<N>_*.png`.
- Запись «PASS / FAIL / PARTIAL» в отчёте + краткий диагноз.

# Integration Verification Checklist

Для UX-агента integration verification означает:

- [ ] **Скриншоты собраны** для всех 6 сценариев — ≥ 5 на сценарий = ≥ 30 скриншотов.
- [ ] **ui_checklist_s8.md создан** в `Спринты/` (корневой уровень, рядом с `ui_checklist_s7.md`) — содержит ≥ 50 новых пунктов S8.
- [ ] **Найденные баги классифицированы:**
  - Тривиальные — зафиксены inline (Edit + до/после скриншоты).
  - Архитектурные — занесены в `Sprint_8_Review/backlog.md` или `Sprint_9_Review/backlog.md` с severity.
- [ ] **Cross-DEV contracts проверены:** UX как **потребитель** подтверждает, что C-S8-1..C-S8-9 реально работают в UI:
  - C-S8-1 (health extended): widget показывает cb_state цвет.
  - C-S8-2 (sparkline 24h): мини-график рендерится с реальными точками.
  - C-S8-3 (balance history range): sparkline обрезается с первой активности.
  - C-S8-4 (Telegram test): кнопка работает.
  - C-S8-5 (paginated types): нет runtime-crash на API-вызовах.
  - C-S8-6 (multiplexer singleton): не визуальное (skip).
  - C-S8-7 (is_admin field): Sidebar пункт условный.
  - C-S8-8 (/admin/metrics): страница рендерится.
  - C-S8-9 (event sync): NotificationSettingsPage содержит ожидаемые лейблы.
- [ ] **Если хотя бы один контракт не подтверждён** — явно пометить `⚠️ <C-S8-X> NOT VERIFIED — <причина>` в отчёте и в `Sprint_8_Review/backlog.md` как блокер.

# Формат отчёта (МАНДАТНЫЙ)

Сохранить отчёт в `Спринты/Sprint_8/reports/UX_W3_report.md` по 9-секционному шаблону, **до 400 слов**:

```markdown
## UX отчёт — Sprint 8 W3, финальный юзабилити-тест M4

### 1. Что реализовано
- 6 сквозных сценариев прогнаны (PASS/FAIL/PARTIAL по каждому)
- ui_checklist_s8.md создан с N новых пунктов
- M тривиальных багов зафиксено inline, K архитектурных в backlog
- ≥ 30 скриншотов собраны

### 2. Файлы
- **Новые:** `Спринты/ui_checklist_s8.md`, `Спринты/Sprint_8/reports/UX_W3_report.md`, `Спринты/Sprint_8/ux_screenshots/*.png`
- **Изменённые:** `Develop/frontend/src/pages/<file>.tsx` (только мелкие text/spacing фиксы — список)
- **Backlog cards:** N карточек в `Sprint_8_Review/backlog.md` или `Sprint_9_Review/backlog.md`

### 3. Тесты
- Manual usability: 6/6 сценариев прогнаны
- TypeScript check после inline-фиксов: 0 errors (`npx tsc --noEmit`)

### 4. Integration points
Cross-DEV contracts (потребитель UX):
- C-S8-1 health extended: ✅ работает в Dashboard
- C-S8-2 sparkline 24h: ✅ рендерится
- C-S8-3 balance range: ⚠️ <если есть проблема> или ✅
- ... (все 9 контрактов)

### 5. Контракты для других DEV
- Поставляю: нет (UX не пишет production-код)
- Использую: C-S8-1..9 — все подтверждены / <X> не подтверждён, см. backlog

### 6. Проблемы / TODO
- BUG-1: <короткое описание> — FIXED inline
- BUG-2: <короткое описание> — S8R-UX-XXXX в backlog (severity medium-high)
- ...

### 7. Применённые Stack Gotchas
- Если применимо (например, `gotcha-24-lightweight-charts-few-points` при тестировании sparkline)

### 8. Новые Stack Gotchas (если обнаружены)
- Если найдена новая ловушка стека при тестировании — описать симптом/причину/правило для ARCH

### 9. Использование плагинов
- playwright: использован — N скриншотов для скриншотинга экранов
- frontend-design: использован для <X> / не требовался
- context7: запрошена документация Mantine для <Y> / не требовался
- pyright-lsp / typescript-lsp / code-review / superpowers: не требовались
```

# Alembic-миграция

Не применимо.

# Чеклист перед сдачей

- [ ] Все 6 сценариев прогнаны, скриншоты в `Sprint_8/ux_screenshots/` собраны (≥ 30 файлов)
- [ ] `Спринты/ui_checklist_s8.md` создан, содержит ≥ 50 новых пунктов S8
- [ ] Тривиальные UX-баги зафиксены inline (до/после скриншоты приложены)
- [ ] Архитектурные UX-баги занесены в `Sprint_8_Review/backlog.md` или `Sprint_9_Review/backlog.md` с severity и часами
- [ ] **Integration Verification:** все 9 Cross-DEV contracts проверены (или явно помечены `⚠️ NOT VERIFIED`)
- [ ] **Формат отчёта соблюдён** — 9 секций заполнены, ≤ 400 слов
- [ ] **Отчёт сохранён** как файл `Спринты/Sprint_8/reports/UX_W3_report.md`
- [ ] **Cross-DEV contracts подтверждены** — секция 4 отчёта содержит явные подтверждения
- [ ] **Плагины использованы** — секция 9 отчёта заполнена, playwright вызван для всех 6 сценариев
- [ ] **TypeScript build чистый** после inline-фиксов: `cd Develop/frontend && npx tsc --noEmit` — 0 errors
- [ ] `Спринты/Sprint_8/changelog.md` обновлён (правило памяти `feedback_changelog_immediate.md`)
- [ ] `Спринты/Sprint_8/sprint_state.md` отражает «W3 Поток B (UX) ✅»
