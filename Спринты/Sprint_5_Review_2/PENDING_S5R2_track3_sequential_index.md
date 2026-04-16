# [Sprint_5_Review_2] Трек 3 — Sequential-index mode для intraday

> **Источник:** UX-замечание, всплыло при ручном тесте 2026-04-15.
> **Приоритет:** 🟢 UX-улучшение.
> **Статус:** ⬜ TODO — скелет создан 2026-04-16, детализация нужна.

## Контекст

TODO детализировать. Краткая суть:
- На TF < 1D (1m/5m/15m/1h/4h) ось времени в `lightweight-charts` линейная по реальному времени.
- MOEX торгуется не круглосуточно (основная сессия 10:00–18:45 MSK, + вечерняя). В нерабочие часы на графике образуются «дыры» — пустые интервалы.
- Для пользователя это выглядит как обрыв графика / непонятные скачки.
- Решение: включить **sequential-index mode** — ось индексирует бары подряд, игнорируя реальные gap'ы между ними.

## Корень проблемы

TODO:
- Библиотека `lightweight-charts` поддерживает `TimeScaleOptions.fixLeftEdge`, `barSpacing` и настройку времени. Нужно проверить актуальный API (v4+ vs v5).
- Наш `InstrumentChart.tsx` передаёт данные с реальными timestamps — значит либо передавать индекс-тип `time: number` (business-day), либо включать `ticksVisible: false` + custom formatter.
- У lightweight-charts есть [business days mode](https://tradingview.github.io/lightweight-charts/) — именно он и есть sequential-index mode.

## Предлагаемое решение

TODO — варианты:
1. Переключить `time` в сериях на `BusinessDay`-like индексацию (для intraday — порядковые номера минут рабочей сессии).
2. Оставить timestamps, но применить `customFormatter` + `rightOffset` так, чтобы gap'ы выглядели минимально.
3. Два режима переключаемых пользователем: «Реальное время» / «Последовательные бары».

Рекомендуемый вариант: **3 (переключатель)** — для trading понятнее sequential, для backtesting иногда нужен real-time.

## Затрагиваемые файлы

TODO:
- `frontend/src/features/chart/InstrumentChart.tsx` — конфиг `timeScale`
- `frontend/src/features/chart/ChartPage.tsx` — возможный переключатель режима
- `frontend/src/features/chart/useChartOptions.ts` — **новый** hook если вынести настройки
- Тесты Vitest на конвертацию timestamp → sequential index

## Критерии готовности

TODO:
- [ ] На TF 1m/5m/15m/1h/4h нет визуальных gap'ов за нерабочие часы
- [ ] На TF D — режим не применяется (Daily не страдает от внутридневных дыр)
- [ ] Переключатель режима (если реализуем) — сохраняется в localStorage
- [ ] Vitest-тесты на конвертацию
- [ ] Визуальный regression-тест (Playwright screenshot) на intraday графике
- [ ] Документирован Stack Gotcha если всплывёт что-то в API lightweight-charts

## Риски

TODO:
- API lightweight-charts мог поменяться между версиями. Проверить `package.json`.
- Live-тик должен корректно попасть на последний sequential-index (нельзя жёстко завязываться на реальное время).
- Watermark / crosshair formatter должен показывать **реальное** время, не индекс.

## Оценка

TODO (черновая): ~0.5–1 сессия DEV.

## Открытые вопросы к пользователю

- Нужен ли переключатель режимов или по умолчанию sequential на intraday?
- Применять ли sequential на Daily для скрытия выходных / праздников биржи?
