## DEV-track3 отчёт — S5R-2, задача Sequential-index mode для intraday

### 1. Что реализовано

- **Sequential-index mode** в `CandlestickChart`: при включённом режиме бары intraday-графика (1m/5m/15m/1h/4h) индексируются последовательно (0, 1, 2, …), без gap'ов нерабочих часов MOEX
- **Двойной маппинг** `index → realTimestamp` для корректного отображения реального времени в crosshair-tooltip и на оси X через `tickMarkFormatter` / `localization.timeFormatter`
- **Live-update в sequential mode**: fast-path (update/append) корректно вычисляет индекс для нового бара и обновляет mapping
- **Lazy-loading в sequential mode**: при прокрутке к левому краю (index ≤ 0) триггерит `fetchOlderCandles()`
- **Переключатель режима оси** — кнопка `IconChartDots` / `IconClock` рядом с TimeframeSelector, видна только для intraday TF
- **Автоматика**: sequential включён по умолчанию для intraday, на D/W/M — всегда real-time
- **Persist в localStorage** (`sequentialTimeAxis`) — сохраняет пользовательский выбор между сессиями
- **Crosshair/overlay** — показывает реальное время (MSK), не индекс, в обоих режимах
- **9 vitest-тестов** для утилитного модуля: конвертация, reverse mapping, isIntraday, getCandleByIndex

### 2. Файлы

- **Новые:**
  - `frontend/src/components/charts/sequentialIndex.ts` — утилитный модуль: конвертация, форматирование, маппинг
  - `frontend/src/components/charts/__tests__/sequentialIndex.test.ts` — 9 тестов
- **Изменённые:**
  - `frontend/src/components/charts/CandlestickChart.tsx` — prop `sequentialMode`, dual-mode data pipeline, custom formatters, crosshair с маппингом
  - `frontend/src/pages/ChartPage.tsx` — state `sequentialPref`, toggle-кнопка, передача `sequentialMode` в `CandlestickChart`

### 3. Тесты

- Frontend: **238/238 passed** (baseline: 226/226, +12 новых из sequentialIndex.test.ts)
- `pnpm tsc --noEmit` → 0 errors
- `pnpm lint` → 1 error, 7 warnings (все pre-existing, не связаны с треком 3)

### 4. Integration points

- `candlesToSequential()` вызывается из `CandlestickChart.tsx:472` (slow-path setData) — ✅ подключено
- `formatSequentialTime()` вызывается из `CandlestickChart.tsx:349,356` (tickMarkFormatter + timeFormatter) — ✅ подключ��но
- `getCandleByIndex()` вызывается из `CandlestickChart.tsx:237` (crosshair handler) — ✅ подключено
- `isIntradayTimeframe()` вызывается из `ChartPage.tsx:43` (toggle visibility) — ✅ подключено
- `sequentialMode` prop передаётся из `ChartPage.tsx:197` → `CandlestickChart` — ✅ подключено

### 5. Контракты для других DEV

- **Поставляю:** prop `sequentialMode: boolean` в `CandlestickChart` — потребитель: любая страница, использующая CandlestickChart (ChartPage, InstrumentChart в бэктесте)
- **Cross-DEV зависимости:** нет — трек 3 параллелен, не зависит от других треков S5R-2

### 6. Проблемы / TODO

- На D/W/M — sequential mode не применяется (weekend gap'ы на Daily остаются). Решение принято осознанно: на Daily gap'ы минимальны и не мешают анализу
- Pre-existing lint error в `ChartPage.tsx:102` (`setWsChannel(null)` внутри effect) — не связан с треком 3, существовал до изменений

### 7. Применённые Stack Gotchas

- Gotcha 16 (`gotcha-16-relogin-race.md`): учтён паттерн race-condition при logout→login — sequential mode state хранится в localStorage + React state, не зависит от auth flow

### 8. Новые Stack Gotchas (если обнаружены)

Новых ловушек не обнаружено. lightweight-charts v5 корректно работает с числовыми индексами в `time`, при условии явной настройки `tickMarkFormatter` и `localization.timeFormatter`.
