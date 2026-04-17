---
sprint: S5R-2
agent: DEV-track3
role: "Frontend UX — Sequential-index mode для intraday (визуальные «дыры» нерабочих часов)"
wave: 2
depends_on: []
---

# Роль

Ты — Frontend-разработчик (senior), специалист по визуализации финансовых данных. Твоя задача: устранить визуальные «дыры» на intraday-графиках (1m/5m/15m/1h/4h), вызванные нерабочими часами MOEX. Решение: переключатель «sequential-index» / «real-time» на оси X. Работаешь в `Develop/frontend/`.

## Суть проблемы

MOEX торгуется не круглосуточно (основная сессия ~10:00–18:45 MSK, вечерняя до 23:50). На TF < D ось времени `lightweight-charts` линейная по реальному времени — в нерабочие часы на графике образуются пустые интервалы («дыры»). Для пользователя это выглядит как обрыв графика и затрудняет анализ.

## Решение

lightweight-charts v5 поддерживает два формата `time`:
- **UTCTimestamp** (число) — реальное время, линейная ось (текущее поведение)
- **Порядковый индекс** — бары идут подряд без gap'ов

Реализовать **переключатель** в UI: «Последовательные бары» (по умолчанию для intraday) / «Реальное время». На TF D/W/M — всегда реальное время (там дыр нет).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Node >= 18, pnpm >= 9
2. Зависимости предыдущих DEV: нет (трек 3 параллелен треку 5)
3. Существующие файлы:
   - Develop/frontend/src/components/charts/CandlestickChart.tsx — основной график
   - Develop/frontend/src/pages/ChartPage.tsx — страница графика
   - Develop/frontend/src/stores/marketDataStore.ts — candles, currentTimeframe
   - Develop/frontend/package.json — lightweight-charts ^5.1.0
4. База данных: не применимо
5. Внешние сервисы: нет
6. Тесты baseline: `pnpm lint` → 0 errors, `pnpm tsc --noEmit` → 0 errors, `pnpm test` → 0 failures
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.
2. **`Develop/stack_gotchas/INDEX.md`** — ищи gotcha по слоям: `lightweight-charts`, `market-data`.
3. **`Спринты/Sprint_5_Review_2/execution_order.md`** — Cross-DEV contracts.
4. **`Спринты/Sprint_5_Review_2/PENDING_S5R2_track3_sequential_index.md`** — полный план.

5. **Цитаты из кода (по состоянию на 2026-04-17):**

   > **CandlestickChart.tsx** (передача данных):
   > - `candleToChartData()` (строка 35): `time: parseUtcTimestamp(candle.timestamp) as Time`
   > - `parseUtcTimestamp()` (строка 30): конвертирует ISO → unix-секунды + MSK_OFFSET_SEC (3*3600). Результат — UTCTimestamp для lightweight-charts.
   > - Создание графика (строка ~188): `timeScale: { borderColor: '#2C2E33', timeVisible: true, secondsVisible: false }`
   > - Переключение TF (строка ~318): `timeScale: { timeVisible: !isDailyOrLarger }` для D/W/M скрывает часы.
   > - Scroll/zoom event (строка ~242): `chart.timeScale().subscribeVisibleTimeRangeChange(…)` — используется для дозагрузки старых свечей.

   > **lightweight-charts v5 API:**
   > - `time` в данных может быть: `UTCTimestamp` (число, секунды), `BusinessDay` (`{ year, month, day }`), или просто `string` (ISO-date).
   > - Для sequential-index: можно использовать обычный `number` (порядковый) как `time`, но **crosshair tooltip** будет показывать число, а не дату. Нужен `localization.timeFormatter` для отображения реальной даты.
   > - Либо использовать `tickMarkFormatter` и `timeFormatter` в `timeScale` options.

   > **marketDataStore.ts:**
   > - `currentTimeframe` — текущий TF пользователя.
   > - `candles: Candle[]` — ISO timestamps. Индексация: `candles[0]` — самая старая.

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

```
- src/components/charts/CandlestickChart.tsx — основной график. РАСШИРЯЕМ: dual-mode time mapping + custom formatters.
- src/pages/ChartPage.tsx — страница. ДОБАВЛЯЕМ: переключатель режима оси (или в TimeframeSelector).
- src/stores/marketDataStore.ts — candles, currentTimeframe. НЕ МОДИФИЦИРУЕМ.
- src/components/charts/TimeframeSelector.tsx — селектор TF. ВОЗМОЖНО расширяем переключателем.
```

# Задачи

## Задача 3.1: Настройка sequential-index mode в CandlestickChart

Добавить prop `sequentialMode: boolean` в `CandlestickChartProps`.

Когда `sequentialMode=true` **и** TF — intraday (не D/W/M):
1. Передавать в серии `time` как **порядковый номер** (0, 1, 2, …) вместо UTCTimestamp.
2. Хранить mapping `index → realTimestamp` для tooltips.
3. Настроить `localization.timeFormatter` (или `timeScale.tickMarkFormatter`) чтобы показывать реальную дату/время из mapping.

Когда `sequentialMode=false` или TF = D/W/M — текущее поведение (UTCTimestamp).

**Ключевые моменты:**
- `crosshairMove` callback должен показывать **реальное время**, не индекс.
- `subscribeVisibleTimeRangeChange` для дозагрузки старых свечей — `getVisibleRange()` вернёт индексы, нужно маппить обратно в timestamp для `fetchOlderCandles`.
- Live-тик через `series.update()` — нужно вычислить правильный индекс (последний + 1 для нового бара, последний для обновления).

## Задача 3.2: Переключатель режима оси

Добавить кнопку/toggle рядом с `TimeframeSelector` (или встроить в него):
- Иконка: `IconChartDots` (Tabler) или аналогичная для sequential, `IconClock` для real-time.
- По умолчанию: sequential для intraday, real-time для D/W/M.
- Сохранять выбор в localStorage (`sequentialTimeAxis`).
- Автоматически сбрасывать в real-time при переключении на D/W/M (но сохранять пользовательский выбор для intraday).

## Задача 3.3: Vitest тесты

1. **Конвертация timestamp → sequential index:** массив с gap'ом → индексы 0,1,2 без gap.
2. **Reverse mapping:** индекс → реальный timestamp для tooltip.
3. **Переключение TF D→1h:** sequentialMode автоматически включается.
4. **D/W/M → sequentialMode всегда false:** даже если пользователь включил.

## Задача 3.4: Stack Gotcha (если новая ловушка обнаружена)

Если lightweight-charts v5 API ведёт себя неочевидно при порядковых индексах — создай gotcha. Иначе — «Новых ловушек не обнаружено.»

# Тесты

```
Develop/frontend/
├── src/components/charts/__tests__/
│   └── sequentialIndex.test.ts    # Vitest: конвертация, reverse mapping, auto-mode
```

**Минимум:** 4 vitest-теста (задача 3.3).

# ⚠️ Integration Verification Checklist

- [ ] **sequentialMode prop**: `grep -rn "sequentialMode" src/components/charts/CandlestickChart.tsx` → найдено
- [ ] **Переключатель в UI**: `grep -rn "sequentialTimeAxis\|sequential" src/pages/ChartPage.tsx` → найдено
- [ ] **localStorage persist**: `grep -rn "sequentialTimeAxis" src/` → сохраняется/читается
- [ ] **timeFormatter**: `grep -rn "timeFormatter\|tickMarkFormatter" src/components/charts/CandlestickChart.tsx` → настроен для sequential mode
- [ ] **Тесты зелёные**: `pnpm test` → 0 failures

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.

Сохрани отчёт как файл: `Спринты/Sprint_5_Review_2/reports/DEV-track3_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 3.1–3.4 реализованы
- [ ] `pnpm lint` → 0 errors
- [ ] `pnpm tsc --noEmit` → 0 errors
- [ ] `pnpm test` → 0 failures (включая 4+ новых)
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_5_Review_2/reports/DEV-track3_report.md`
- [ ] На intraday (1m/5m/15m/1h/4h) нет визуальных gap'ов при включённом sequential mode
- [ ] На D/W/M — sequential mode не применяется
- [ ] Crosshair / tooltip показывает реальное время, не индекс
