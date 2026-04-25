---
sprint: 7
agent: DEV-4
role: Frontend (FRONT2) — Dashboard + Strategy editor + Settings + Wizard
wave: 2
depends_on: [ARCH W0, UX W0, BACK2 (для C4, C6), BACK1 (для C5)]
---

# Роль

Ты — Frontend-разработчик #2. Зона ответственности по RACI: Dashboard = R, Settings UI = R, AI chat frontend = коллаборация с FRONT1.

На W2 реализуешь UI версионирования стратегий, дашборд-виджеты, first-run wizard, Grid Search UI. На W1 не задействован (нет debt-задач для FRONT2).

# Предварительная проверка

```
1. Окружение: Node.js ≥ 18, pnpm установлен.
2. Зависимости (W2): UX опубликовал dashboard_widgets.md, wizard_5steps.md.
3. Зависимости backend (W2): BACK2 опубликовал C4 (versions endpoints + миграция applied), C6 (wizard endpoints), BACK1 опубликовал C5 (grid endpoint + WS C2).
4. Существующие файлы: Develop/frontend/src/{components,pages,stores,api}.
5. Тесты baseline: cd Develop/frontend && pnpm test → 0 failures.
6. Type-check: npx tsc --noEmit → 0 errors.
```

# Обязательные плагины

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| typescript-lsp | **да** (после каждого Edit/Write) | `npx tsc --noEmit` |
| context7 | **да** — Mantine компоненты (Stepper, Modal, Card), lightweight-charts (для sparklines) | WebSearch |
| playwright | **да** (mandatory скриншот после блока в `components/`) | Заказчик |
| frontend-design | да (опционально) — для дашборд-виджетов и Grid Search heatmap | — |
| pyright-lsp | нет | — |
| code-review | нет | — |

# Обязательное чтение

1. **`Develop/CLAUDE.md`** полностью.
2. **`Develop/stack_gotchas/INDEX.md`** — особенно: Mantine modal lifecycle, lightweight-charts series cleanup, 401 cleanup+guard.
3. **`Спринты/Sprint_7/execution_order.md`** Cross-DEV contracts:
   - **Потребитель:** C4 (от BACK2), C5 (от BACK1), C6 (от BACK2).
4. **UX-макеты** в `Sprint_7/ux/`:
   - `dashboard_widgets.md` — для 7.7.
   - `wizard_5steps.md` — для 7.8-fe.
5. **`Спринты/Sprint_7/arch_design_s7.md`** секции 1 (versioning), 2 (Grid Search).
6. **Память:** `feedback_ui_checklist_update.md` — после спринта обновить ui_checklist.

# Рабочая директория

`Develop/frontend/`

# Контекст существующего кода

- `src/pages/StrategyEditPage.tsx` — текущий редактор стратегий (935 строк, монолит — задача S8 рефактора). Расширить для версий.
- `src/pages/DashboardPage.tsx` — главный дашборд. Расширить виджетами 7.7.
- `src/components/charts/` — chart-обёртка (для sparklines в виджетах).
- `src/api/strategies.ts` — API клиент стратегий (расширить методами versions).
- `src/api/users.ts` — API клиент юзеров (расширить wizard).
- `src/api/backtest.ts` — API клиент бэктестов (расширить grid).
- `src/components/AppShell` — оболочка с рутингом (показ wizard на первом логине).

# Задачи

## Задача 7.1-fe: Версионирование стратегий UI (W2)

**Контракт C4 (потребитель).**

Расширение `StrategyEditPage.tsx`:

### 7.1.1 — Кнопка «История» рядом с «Сохранить»

```tsx
<Button onClick={openVersionsHistory}>История</Button>
```

При клике — Drawer/Modal с историей версий.

### 7.1.2 — Компонент `VersionsHistoryDrawer`

```tsx
// src/components/strategy/VersionsHistoryDrawer.tsx
export function VersionsHistoryDrawer({ strategyId, opened, onClose }: Props) {
  const { data: versions } = useQuery(['versions', strategyId], () =>
    api.strategies.listVersions(strategyId)
  );

  return (
    <Drawer opened={opened} onClose={onClose} title="История версий" size="lg">
      {versions?.map(v => (
        <VersionRow
          key={v.id}
          version={v}
          onRestore={() => handleRestore(v.id)}
          onDiff={() => openDiff(v)}
        />
      ))}
    </Drawer>
  );
}
```

### 7.1.3 — Diff-просмотр

Показ blocks_xml ДО/ПОСЛЕ через `react-diff-viewer-continued` или аналог.

### 7.1.4 — Восстановить (с подтверждением)

```tsx
const handleRestore = async (versionId: number) => {
  const confirmed = await modals.openConfirmModal({
    title: 'Восстановить версию',
    children: 'Текущая версия будет автоматически сохранена. Продолжить?',
  });
  if (confirmed) {
    await api.strategies.restoreVersion(strategyId, versionId);
    refetchStrategy();
    notifications.show({ message: 'Версия восстановлена' });
  }
};
```

## Задача 7.7: Дашборд-виджеты (W2, с FRONT1 саппорт sparklines)

Источник: `Sprint_7/ux/dashboard_widgets.md`.

### 7.7.1 — Виджет «Баланс»

```tsx
// src/components/dashboard/BalanceWidget.tsx
export function BalanceWidget() {
  const { balance, dailyChange, sparklineData } = useBalance();

  return (
    <Card>
      <Text size="sm" c="dimmed">Баланс</Text>
      <Title>{formatCurrency(balance)}</Title>
      <Group>
        <Text c={dailyChange >= 0 ? 'green' : 'red'}>
          {dailyChange >= 0 ? '↑' : '↓'} {formatPercent(dailyChange)}
        </Text>
      </Group>
      <MiniSparkline data={sparklineData} color={dailyChange >= 0 ? 'green' : 'red'} />
    </Card>
  );
}
```

### 7.7.2 — Виджет «Health»

```tsx
// src/components/dashboard/HealthWidget.tsx
// Светофор: CB (зелёный/жёлтый/красный), T-Invest connection, Scheduler
```

### 7.7.3 — Виджет «Активные позиции»

```tsx
// src/components/dashboard/ActivePositionsWidget.tsx
// Список тикеров с мини-графиком и текущим P&L
```

### 7.7.4 — Размещение на DashboardPage

3 колонки на desktop, 1 колонка mobile.

`<MiniSparkline>` — компонент от FRONT1 (саппорт).

## Задача 7.8-fe: First-run wizard (W2)

**Контракт C6 (потребитель).**

Источник: `Sprint_7/ux/wizard_5steps.md`.

### 7.8.1 — Модалка с 5 шагами через Mantine Stepper

```tsx
// src/components/wizard/FirstRunWizard.tsx
export function FirstRunWizard() {
  const [step, setStep] = useState(0);
  const [agreed, setAgreed] = useState(false);

  return (
    <Modal opened={!user.wizard_completed_at} onClose={() => {}} closeOnClickOutside={false}>
      <Stepper active={step} onStepClick={setStep}>
        <Stepper.Step label="Приветствие">...</Stepper.Step>
        <Stepper.Step label="Дисклеймер">
          {/* Текст рисков + Checkbox обязательный */}
          <Checkbox checked={agreed} onChange={(e) => setAgreed(e.currentTarget.checked)} label="Я прочитал и понимаю риски" />
        </Stepper.Step>
        <Stepper.Step label="Брокер" disabled={!agreed}>...</Stepper.Step>
        <Stepper.Step label="Уведомления">...</Stepper.Step>
        <Stepper.Step label="Финиш">
          <Button onClick={handleComplete}>Готово, начать работу</Button>
        </Stepper.Step>
      </Stepper>
    </Modal>
  );
}

const handleComplete = async () => {
  await api.users.completeWizard();
  refetchUser();
};
```

### 7.8.2 — Показ только при `wizard_completed_at == null`

В `AppShell` (или верхнем компоненте) проверка `user.wizard_completed_at`. Если `null` — wizard модалка открыта поверх контента (с overlay, нельзя закрыть).

### 7.8.3 — Stack Gotcha: Mantine modal lifecycle

Соблюсти правило из `Develop/stack_gotchas/INDEX.md` про Mantine modal — не использовать side effects в render body, всё в `useEffect`.

## Задача 7.2-fe: Grid Search UI (W2)

**Контракт C5 (потребитель), C2 (через WS — общий с фоновым бэктестом).**

### 7.2.1 — Расширение `BacktestLaunchModal` или новая модалка

```tsx
// src/components/backtest/GridSearchForm.tsx
export function GridSearchForm({ strategyId, params }: Props) {
  // Для каждого параметра — поле «диапазон значений» (например, 10..20 step 1)
  // Расчёт N комбинаций в реальном времени, warning если превышает hard cap
  // Кнопка «Запустить Grid Search»
}
```

### 7.2.2 — Запуск + WS подписка

```tsx
const { job_id } = await api.backtest.startGridSearch({ strategy_id, ranges });
// Подписка на /ws/backtest/{job_id} (через FRONT1 backgroundBacktestsStore или собственный hook)
// По завершению — отображение matrix
```

### 7.2.3 — Heatmap результата

```tsx
// src/components/backtest/GridSearchHeatmap.tsx
// 2D heatmap: ось X — параметр 1, ось Y — параметр 2, цвет — Sharpe (или выбранная метрика)
// Если параметров > 2 — табличный вид с сортировкой
```

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Если ввёл `test.skip` — карточка в backlog обязательна.

# Тесты

```
Develop/frontend/src/
├── components/strategy/VersionsHistoryDrawer.test.tsx  # 7.1-fe: список, restore confirm
├── components/dashboard/BalanceWidget.test.tsx         # 7.7
├── components/dashboard/HealthWidget.test.tsx          # 7.7
├── components/dashboard/ActivePositionsWidget.test.tsx # 7.7
├── components/wizard/FirstRunWizard.test.tsx           # 7.8-fe: 5 шагов, дисклеймер обязателен
├── components/backtest/GridSearchForm.test.tsx         # 7.2-fe: расчёт N
├── components/backtest/GridSearchHeatmap.test.tsx      # 7.2-fe: рендер
```

# Integration Verification Checklist

- [ ] **7.1-fe:** `grep -rn 'VersionsHistoryDrawer\|listVersions' Develop/frontend/src/` показывает использование.
- [ ] **7.1-fe:** `Restore` подтверждение перед действием (modals.openConfirmModal).
- [ ] **7.7:** `grep -rn 'BalanceWidget\|HealthWidget\|ActivePositionsWidget' Develop/frontend/src/pages/DashboardPage` показывает подключение.
- [ ] **7.8-fe:** `grep -rn 'FirstRunWizard' Develop/frontend/src/` показывает использование в `AppShell`.
- [ ] **7.8-fe:** Wizard не показывается повторно после `completeWizard` (тест: refetch user → `wizard_completed_at != null`).
- [ ] **7.2-fe:** `grep -rn 'GridSearchForm\|GridSearchHeatmap' Develop/frontend/src/` показывает компоненты.
- [ ] **7.2-fe:** Hard cap warning в UI работает (тест: ввести параметры на 1500 комбинаций → красный).
- [ ] **Playwright скриншоты:** для каждого блока — приложить в отчёт.
- [ ] **Mantine modal lifecycle gotcha:** соблюдён для FirstRunWizard.

# Формат отчёта

**1 файл:** `reports/DEV-4_FRONT2_W2.md` — после 7.1-fe, 7.7, 7.8-fe, 7.2-fe.

8 секций до 400 слов.

# Alembic-миграция

Не применимо (frontend).

# Чеклист перед сдачей

- [ ] Все задачи реализованы.
- [ ] `npx tsc --noEmit` → 0 errors.
- [ ] `pnpm test` → 0 failures.
- [ ] `pnpm lint` → no issues.
- [ ] Playwright скриншоты приложены.
- [ ] Integration verification пройден.
- [ ] Контракты C4, C5, C6 как потребитель подтверждены.
- [ ] Stack Gotchas применены (Mantine modal lifecycle, lightweight-charts cleanup для sparklines).
- [ ] Skip-тикеты с карточками.
- [ ] `Sprint_7/changelog.md` обновлён.
- [ ] Отчёт сохранён файлом.
