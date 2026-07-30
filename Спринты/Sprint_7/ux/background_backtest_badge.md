# UX-макет: Бейдж фоновых бэктестов в шапке (для задачи 7.17)

> **Статус:** заполнен UX-агентом на W0 (2026-04-25).
> **Источники:** `Sprint_7/sprint_design.md` Приложение D, `Sprint_7/prompt_UX.md` задача 5, память `project_s7_background_backtest.md`, контракт C2 (Приложение A).
> **Связь с задачей S7:** 7.17 «Фоновые бэктесты — параллельные запуски + индикатор» (перенос из S6).

---

## 1. Описание сценария

Из `BacktestLaunchModal` пользователь может запустить бэктест:
1. **«Запустить»** (existing) — модалка закрывается, переход на `/backtest/{id}`.
2. **«Запустить в фоне»** (новое) — POST на backend, получение `job_id`, добавление в `backgroundBacktestsStore`, **модалка остаётся открытой** (можно поменять параметры и запустить ещё). Toast «Бэктест запущен в фоне».

В шапке справа от user-меню — бейдж с числом активных бэктестов. Click → dropdown со списком прогресса. По завершении (`status === 'done'`) — кнопка «Открыть результат», после клика результат открывается в новой вкладке/таб (или текущей по выбору).

---

## 2. Кнопка «Запустить в фоне» в `BacktestLaunchModal`

```
┌─ Запуск бэктеста ──────────────────────────── × ──┐
│  Стратегия: [Импульс RSI 14 ▾]                     │
│  Тикер:     [SBER ▾]                               │
│  Период:    [01.01.2025 — 31.12.2025]              │
│  Таймфрейм: [1H ▾]                                 │
│  Параметры: [...]                                  │
│                                                     │
│   Отмена   [Запустить в фоне]   [Запустить ▶]      │
└─────────────────────────────────────────────────────┘
```

- Две основные кнопки: `Запустить в фоне` (default variant) + `Запустить` (filled, primary).
- `Запустить в фоне`: вызывает `POST /api/v1/backtest` с флагом `background: true` (либо без флага — поведение «не редиректить» определяется на frontend; backend отдает job_id одинаково), записывает в `backgroundBacktestsStore` (Zustand или Mantine `useStore`), показывает toast.
- **Модалка не закрывается** — пользователь может поменять параметры, запустить новый.
- Toast: `Mantine notifications.show({ title: 'Бэктест запущен в фоне', message: 'Прогресс — в шапке справа', color: 'blue' })`.

---

## 3. Бейдж в шапке

```
... [Search]  [🧪 3]  [👤 sergopipo ▾]
        ↑↑↑
       Mantine <Indicator inline label={count} color="red">
```

- При `count === 0` — бейдж скрыт (`Indicator disabled`).
- При `count > 0` — кружок с числом, цвет:
  - `blue` (по умолчанию, идёт прогресс).
  - `green` (есть `done`-таски, доступно «Открыть»).
  - `red` (есть `error`-таски).
- Hover — tooltip «3 бэктеста в фоне» (если есть errors — «3 в фоне, 1 ошибка»).
- Click — открыть Mantine `<Popover position="bottom-end">` или `<Menu>`.

---

## 4. Dropdown по клику

```
┌─ Фоновые бэктесты (3) ───────────────────────── × ──┐
│                                                       │
│  Импульс RSI 14 · SBER · 1H            [▶ 47%]   ×   │
│  ▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱   2 мин назад                     │
│                                                       │
│  Mean Reversion · GAZP · 1D            [▶ 82%]   ×   │
│  ▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱   5 мин назад                     │
│                                                       │
│  MACD Cross · LKOH · 4H                [✔ done]      │
│  ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰   только что  [Открыть результат]   │
│                                                       │
│  ──────────────────────────────────────────────────  │
│  Mean Reversion 2 · ROSN · 1H          [✖ error]     │
│  «Insufficient market data for period»  [×]          │
│                                                       │
│                                  [Очистить завершённые]│
└───────────────────────────────────────────────────────┘
```

Per-row структура:
- Строка 1: имя стратегии · тикер · timeframe — справа: статус-чип + (для running) кнопка `×` отмены.
- Строка 2: progress bar (Mantine `<Progress>` height 4px, color по статусу) + relative time + (для done) кнопка «Открыть результат» / (для error) текст ошибки.

Status визуализация:
- `queued` — серый чип, прогресс 0%, label «В очереди».
- `running` — синий чип, прогресс 0–99%, label «Идёт».
- `done` — зелёный чип ✔, прогресс 100%, кнопка «Открыть результат» (primary subtle).
- `error` — красный чип ✖, текст с reason, кнопка «×» убирает из списка.

Footer:
- Кнопка `Очистить завершённые` — удаляет все `done`/`error` записи из store.

---

## 5. States dropdown

| State | Визуал |
|-------|--------|
| Закрыт (default) | Бейдж в шапке, dropdown скрыт |
| `count === 0` | Бейдж не виден, dropdown недоступен |
| Loading per-row | Skeleton прогресс-бара (при subscribe на WS) |
| Empty (после очистки всё) | «Нет активных бэктестов» (нейтральный текст) |
| Error WS | Чип «Ошибка подключения, retry...» поверх записи; ретрай авто (exponential backoff) |

Lifecycle:
- `done` событие → запись остаётся ещё `10s` (для UX-зрения), затем auto-collapse в «свернутый список». Можно настроить `keep until cleared` — лучше дать пользователю явно очистить (UX-выбор: оставляем, пока user не нажмёт «Очистить завершённые» или не закроет вручную каждую через ×).
- `error` → остаётся до явного закрытия пользователем.
- При reload страницы — `backgroundBacktestsStore` сериализуется в `localStorage`; on mount — переподписка WS на каждый `running` job_id.

---

## 6. ASCII-mockup шапки + dropdown

```
┌─ Header ─────────────────────────────────────────────────────────────────┐
│ MOEX Terminal     [Search ____]              [🧪 3]   [sergopipo ▾]      │
└──────────────────────────────────────────────┴───┴───────────────────────┘
                                              click ↓
                                              ┌─ Popover ────────────────────────┐
                                              │ Фоновые бэктесты (3)             │
                                              │  ...список выше...               │
                                              └──────────────────────────────────┘
```

---

## 7. Поведение

| Событие | Реакция |
|---------|---------|
| Click «Запустить в фоне» в Modal | POST + add to store + toast + модалка остаётся |
| Click бейдж | Toggle Popover |
| Click row при `done` → «Открыть результат» | Navigate `/backtest/{id}` (тот же tab) |
| Cmd/Ctrl+Click | Открыть в новой вкладке |
| Click `×` в running row | Confirm dialog «Отменить бэктест?» → `DELETE /api/v1/backtest/{id}` (если поддерживается) или просто убрать из UI и не подписываться больше |
| Click `Очистить завершённые` | Удалить done/error из store |
| WS message progress | Update progress bar |
| WS message done | Update status, toast «Бэктест #42 готов» (опц.) |
| WS message error | Update status, toast «Бэктест #42 — ошибка», красный |
| Reload страницы | Re-subscribe to all running jobs |
| Logout | Очистить store |

---

## 8. Связь с другими экранами

- `BacktestLaunchModal` — точка запуска.
- `/backtest/{id}` — открытие результата.
- `/dashboard` (виджет 7.7) — опционально, если в S7 будет «последние бэктесты».

---

## 9. Контракт с backend (C2)

> **ARCH-подтверждение (2026-04-25, `arch_design_s7.md` §5/§8):** добавлена таблица `backtest_jobs` (DDL в §5.3), per-user cap = **3** (НЕ 5–10), executor = `asyncio.create_task` + `BacktestJobManager` в `app.state`. WS канал закрывается через 30s после терминального состояния.

**Поставщик:** BACK1. **Потребитель:** FRONT1.

- `POST /api/v1/backtest` body: `{strategy_id, ticker, timeframe, period_start, period_end, params, ...}` → `{job_id}`. Существует с S5.
- `GET /api/v1/backtest/jobs?status=running` — bootstrap при reload страницы (восстанавливает store).
- `WS /ws/backtest/{job_id}` (контракт C2) → `{progress: 0..100, status: 'queued'|'running'|'done'|'error', result?}`. **Отдельное соединение на каждый job**. Канал закрывается сервером через 30s после `done|error`.
- `DELETE /api/v1/backtest/jobs/{id}` — отмена (по решению ARCH §5 — реализуется).

Limits:
- Per-user concurrency cap = **3** (ARCH §5). При попытке запустить 4-й — backend возвращает 429 с сообщением «Превышен лимит параллельных бэктестов (3)»; UI показывает toast.

---

## 10. Доступность

- Indicator с `aria-label="3 фоновых бэктеста, нажмите для деталей"`.
- Popover — `role="dialog"`, фокус первый row.
- Каждая строка фокусируется Tab; `Enter` на done-row открывает результат.
- Progress bar — `role="progressbar" aria-valuenow="47" aria-valuemin="0" aria-valuemax="100"`.
- Toast — `role="status"`.
- Цветовая семантика дублирована иконками (✔ ▶ ✖).

---

## 11. Тестовые сценарии для QA

(в `e2e_test_plan_s7.md`, секция 7.17)

1. Запустить через «в фоне» → toast виден, модалка не закрылась, бейдж = 1.
2. Запустить ещё раз с другими параметрами → бейдж = 2.
3. Click бейдж → dropdown с 2 строками, прогресс-бары обновляются.
4. Дождаться завершения → status `done`, кнопка «Открыть результат».
5. Click «Открыть результат» → переход на `/backtest/{id}`.
6. Запустить бэктест с заведомой ошибкой → status `error`, текст reason.
7. Reload страницы → subscriptions восстанавливаются (running продолжают идти).
8. Logout → store очищен.
9. 5+ параллельных бэктестов — все в dropdown, без падения.
10. `count === 0` (после Очистить завершённые) → бейдж скрыт.

`data-testid`:
- `backtest-launch-button-foreground`, `backtest-launch-button-background`.
- `header-bg-backtests-badge`, `header-bg-backtests-popover`.
- `bg-backtest-row-{job_id}`, `bg-backtest-progress-{job_id}`, `bg-backtest-open-{job_id}`.
- `bg-backtest-clear-completed`.

---

## 12. Stack Gotchas

- **WS reconnect storm**: при reload страницы FE ре-подписывается на N job — бек должен идемпотентно обрабатывать повторные подписки (или возвращать last state). Кандидат на новый gotcha.
- **Memory leak from non-closed WS**: при unmount Popover — НЕ отписываемся (subscriptions живут в store). При удалении job из store — обязательное `socket.close()`.
- **localStorage sync** между табами — если пользователь открыт в 2 табах, оба видят одинаковый store. Запускать в обоих — допускается, store merge through `BroadcastChannel` (опционально, S8).
