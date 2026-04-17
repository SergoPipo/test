## DEV-track5 отчёт — S5R-2, задача TF-aware upsertLiveCandle

### 1. Что реализовано
- Расширена сигнатура `upsertLiveCandle(candle, sourceTf?)` — новый опциональный параметр `sourceTf?: string | null`
- Добавлен TF-aware guard в теле `upsertLiveCandle`: если `sourceTf` задан и не совпадает с `currentTimeframe`, тик отбрасывается
- Debug-лог в DEV-режиме при отброшенном тике (`console.debug` за `import.meta.env.DEV` guard)
- В `CandlestickChart.tsx` `marketWsCallback` — извлечение TF из `wsChannel` prop (формат `market:{ticker}:{tf}`, берём 3-й сегмент)
- Передача `channelTf` вторым аргументом в `upsertLiveCandle(liveCandle, channelTf)`
- `wsChannel` добавлен в deps `useCallback` для корректного пересоздания callback при смене канала
- 3 новых Vitest-теста: отброс чужого TF, приём своего TF, обратная совместимость (без sourceTf)

### 2. Файлы
- **Новые:** нет
- **Изменённые:**
  - `Develop/frontend/src/stores/marketDataStore.ts` — сигнатура + guard в `upsertLiveCandle`
  - `Develop/frontend/src/components/charts/CandlestickChart.tsx` — извлечение TF, передача в store
  - `Develop/frontend/src/stores/__tests__/marketDataStore.test.ts` — 3 новых теста
- **Удалённые:** нет

### 3. Тесты
- Frontend: **229/229 passed** (226 baseline + 3 новых), 47 файлов, 0 failures
- `pnpm tsc --noEmit` — 0 errors
- `pnpm lint` — 2 errors (оба pre-existing, не от данного трека: `candlesToSequential` unused import от трека 3 + `setState synchronously` в другом файле)

### 4. Integration points
- `upsertLiveCandle(candle, sourceTf?)` вызывается из `CandlestickChart.tsx:493` (подключено)
- `channelTf` извлекается из `wsChannel` prop в `marketWsCallback` (подключено)

### 5. Контракты для других DEV
- **Поставляю:** `upsertLiveCandle(candle: Candle, sourceTf?: string | null)` — потребитель DEV-track2 (live-агрегация)
- Сигнатура обратно совместима: вызов без `sourceTf` работает как раньше (тик проходит без фильтрации)

### 6. Проблемы / TODO
- `ChartPage.tsx` **не модифицирован** — cleanup `setWsChannel(null)` уже корректен после трека 4
- Lint: 2 pre-existing errors не от данного трека; `candlesToSequential` unused import — артефакт трека 3
- E2E stress-тест (переключение TF 10 раз) — не реализован в рамках unit-тестов, рекомендуется для ARCH-ревью

### 7. Применённые Stack Gotchas
- `Gotcha 16` (`gotcha-16-relogin-race.md`): учтён механизм singleton WS + async unsubscribe при смене TF; guard на уровне store устойчивее WS-уровня, т.к. не зависит от сетевой задержки unsubscribe

### 8. Новые Stack Gotchas (если обнаружены)
Новых ловушек не обнаружено. Проблема покрыта Gotcha 16 (relogin-race) по смежному механизму: singleton WS + микро-окно при async unsubscribe — тот же паттерн, решённый store-level guard вместо WS-level фильтра.
