---
sprint: S5R-2
agent: DEV-track5
role: "Frontend Fix — TF-aware upsertLiveCandle (остаточное Daily-мигание)"
wave: 2
depends_on: [DEV-track4]
---

# Роль

Ты — Frontend-разработчик (senior), специалист по real-time data pipelines. Твоя задача: добавить TF-фильтр в `upsertLiveCandle`, чтобы тики чужого таймфрейма (например, 1m-свеча при активном TF=D) не попадали в store и не вызывали мигание графика. Работаешь в `Develop/frontend/`.

## Суть проблемы

WebSocket-канал `market:{ticker}:{tf}` доставляет live-свечи в `CandlestickChart.tsx` → `upsertLiveCandle()`. При **переключении TF** (например, 1m→D):
1. `ChartPage.tsx` вызывает `setWsChannel(null)` (синхронный cleanup старого канала)
2. Затем async `subscribeCandleStream(ticker, newTF)` → новый канал
3. **Микро-окно:** между `setWsChannel(null)` и `useWebSocket(newChannel, cb)` — reconnect уже невозможен, НО если backend ещё не обработал unsubscribe, последние тики старого TF могут прийти в callback. `upsertLiveCandle` не проверяет TF тика — кладёт его в текущий массив candles, вызывая мигание (1m-свеча появляется в D-серии, затем перезатирается fetch'ем).

> **Примечание:** S5R wave 4 фаза 3.7 частично закрыла это окно (race-guard в ChartPage + `setWsChannel(null)` перед async подпиской), но singleton WS может доставить тик в оставшийся микро-интервал.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Node >= 18, pnpm >= 9
2. Зависимости предыдущих DEV: DEV-track4 (cleanup при logout, guard в interceptor) — закрыт
3. Существующие файлы:
   - Develop/frontend/src/stores/marketDataStore.ts  — upsertLiveCandle (строка ~392)
   - Develop/frontend/src/components/charts/CandlestickChart.tsx — WS callback (строка ~443)
   - Develop/frontend/src/pages/ChartPage.tsx — WS subscription effect (строка ~78)
4. База данных: не применимо (frontend-only)
5. Внешние сервисы: нет
6. Тесты baseline: `pnpm lint` → 0 errors, `pnpm tsc --noEmit` → 0 errors, `pnpm test` → 0 failures
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.
2. **`Develop/stack_gotchas/INDEX.md`** — ищи gotcha по слоям: `market-data`, `lightweight-charts`, `Zustand`. Gotcha 16 (relogin-race) — смежная тема, учти при работе с store.
3. **`Спринты/Sprint_5_Review_2/execution_order.md`** — Cross-DEV contracts: трек 5 — **поставщик** сигнатуры `upsertLiveCandle(candle, tf?)` для трека 2.
4. **`Спринты/Sprint_5_Review_2/PENDING_S5R2_track5_tf_aware_upsert.md`** — полный план, 3 варианта решения. Решение: **вариант 1 (store-level TF-aware фильтр)**.

5. **Цитаты из кода (по состоянию на 2026-04-17):**

   > **marketDataStore.ts** (`upsertLiveCandle`, строки ~392–410):
   > - Принимает `(candle: Candle)` — **без параметра TF**.
   > - Сравнивает `timestamp` с последней свечой через `toUtcUnix()`.
   > - Если `newTs === lastTs` → обновляет последнюю; `newTs > lastTs` → push.
   > - Обновляет `candlesCache[currentTicker:currentTimeframe]`.
   > - **Нет проверки, совпадает ли TF тика с `currentTimeframe`.**

   > **CandlestickChart.tsx** (`marketWsCallback`, строки 443–477):
   > - Callback получает `event: 'candle.update' | 'candle.new'` + payload.
   > - Создаёт `liveCandle: Candle` из payload.
   > - Вызывает `useMarketDataStore.getState().upsertLiveCandle(liveCandle)` — **без передачи TF**.
   > - Props: `wsChannel?: string | null` — формат `'market:SBER:1h'` (содержит TF!).

   > **ChartPage.tsx** (WS subscription effect, строки 78–101):
   > - `setWsChannel(null)` — синхронный cleanup.
   > - `subscribeCandleStream(ticker, currentTimeframe)` → async → `setWsChannel(resp.data.channel)`.
   > - Зависимости: `[ticker, currentTimeframe]`.

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

```
- src/stores/marketDataStore.ts    — upsertLiveCandle, currentTimeframe. РАСШИРЯЕМ фильтром.
- src/components/charts/CandlestickChart.tsx — WS callback. РАСШИРЯЕМ передачей TF.
- src/pages/ChartPage.tsx          — WS subscription. НЕ МОДИФИЦИРУЕМ (cleanup уже корректен).
- src/stores/__tests__/marketDataStore.test.ts — тесты store. РАСШИРЯЕМ.
```

# Задачи

## Задача 5.1: Извлечение TF из wsChannel в CandlestickChart

В `CandlestickChart.tsx`, `marketWsCallback`: извлечь TF из `wsChannel` prop (формат `market:{ticker}:{tf}`) и передать его при вызове `upsertLiveCandle`:

```typescript
// В marketWsCallback:
const channelTf = wsChannel?.split(':')[2] ?? null;
// ...
useMarketDataStore.getState().upsertLiveCandle(liveCandle, channelTf);
```

## Задача 5.2: TF-фильтр в `upsertLiveCandle`

Изменить сигнатуру `upsertLiveCandle` в `marketDataStore.ts`:

```typescript
upsertLiveCandle: (candle: Candle, sourceTf?: string | null) => void;
```

В теле метода **перед** обработкой — добавить guard:

```typescript
upsertLiveCandle: (candle: Candle, sourceTf?: string | null) => {
  const { candles, currentTicker, currentTimeframe } = get();

  // TF-aware фильтр: игнорировать тики чужого TF (Gotcha 16 + trace)
  if (sourceTf && sourceTf !== currentTimeframe) {
    if (import.meta.env.DEV) {
      console.debug(`[md] upsertLiveCandle: skip tf=${sourceTf}, active=${currentTimeframe}`);
    }
    return;
  }

  if (candles.length === 0) return;
  // ... остальной код без изменений
```

## Задача 5.3: Vitest тесты

Добавить в `src/stores/__tests__/marketDataStore.test.ts`:

1. **activeTf=D, dispatch(tf='1m') → store unchanged**: установить `currentTimeframe='D'`, `candles=[…]`, вызвать `upsertLiveCandle(newCandle, '1m')` → `candles.length` не изменился.
2. **activeTf=D, dispatch(tf='D') → store updated**: то же, но `sourceTf='D'` → свеча обновлена/добавлена.
3. **sourceTf=null (legacy) → store updated**: обратная совместимость — если sourceTf не передан, тик проходит.

## Задача 5.4: Stack Gotcha (если новая ловушка обнаружена)

Если в ходе работы обнаружишь новую ловушку — опиши в секции 8 отчёта. Иначе: «Новых ловушек не обнаружено, проблема покрыта Gotcha 16 (relogin-race) по смежному механизму.»

# Тесты

```
Develop/frontend/
├── src/stores/__tests__/
│   └── marketDataStore.test.ts    # Vitest: TF-фильтр в upsertLiveCandle (3+ новых теста)
```

**Минимум:** 3 новых vitest-теста (задача 5.3).

# ⚠️ Integration Verification Checklist

- [ ] **upsertLiveCandle** принимает `sourceTf`: `grep -rn "upsertLiveCandle" src/stores/marketDataStore.ts` → сигнатура содержит `sourceTf`
- [ ] **CandlestickChart передаёт TF**: `grep -rn "upsertLiveCandle" src/components/charts/CandlestickChart.tsx` → вызов содержит второй аргумент
- [ ] **Обратная совместимость**: `grep -rn "upsertLiveCandle" src/` → все вызовы компилируются (sourceTf optional)
- [ ] **Тесты зелёные**: `pnpm test` → 0 failures

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.

Сохрани отчёт как файл: `Спринты/Sprint_5_Review_2/reports/DEV-track5_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 5.1–5.4 реализованы
- [ ] `pnpm lint` → 0 errors
- [ ] `pnpm tsc --noEmit` → 0 errors
- [ ] `pnpm test` → 0 failures (включая 3+ новых)
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_5_Review_2/reports/DEV-track5_report.md`
- [ ] Cross-DEV contract: подтверждена новая сигнатура `upsertLiveCandle(candle, sourceTf?)` как поставщик для трека 2
