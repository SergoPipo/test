# Changelog — Sprint 2

> Журнал замечаний и исправлений, найденных в ходе ревью.

---

## Замечания ARCH (APPROVED WITH MINOR)

| # | Критичность | Описание | Файл | Статус |
|---|-------------|----------|------|--------|
| 1 | MINOR | Calendar Service без ISS-клиента (fallback) | `market_data/router.py:27` | Отложено на S3 |

## Замечания заказчика

| # | Описание | Файл | Статус |
|---|----------|------|--------|
| 1 | Footer: "Загрузка" вместо статуса MOEX — URL prefix `market_data` → `market-data` | `main.py:58` | ✅ Исправлено |
| 2 | Footer: нет статуса подключения брокера | `StatusFooter.tsx` | ✅ Исправлено |
| 3 | Footer: "Paper Trading" захардкожен → "Нет активных сессий" | `StatusFooter.tsx:48` | ✅ Исправлено |
| 4 | Footer: "Торги завершены" во время вечерней сессии | `StatusFooter.tsx` | ✅ Исправлено |
| 5 | Заглушки StrategyDetail/BacktestDetail: "Sprint 2" → Sprint 3/4 | `StrategyDetailPage.tsx`, `BacktestDetailPage.tsx` | ✅ Исправлено |
| 6 | График SBER: тёмный экран — таймфрейм `"Д"` вместо `"D"` | `marketDataStore.ts`, `TimeframeSelector.tsx` | ✅ Исправлено |
| 7 | График SBER: ISS ответ с `iss.json=extended` возвращает list вместо dict | `moex_iss/client.py:104` | ✅ Исправлено |
| 8 | ISS: нет маппинга для таймфреймов 5m, 15m, 4h | `moex_iss/client.py:13-20` | ✅ Исправлено |
| 9 | Кеш: source захардкожен "moex_iss" даже для T-Invest данных | `market_data/service.py:294` | ✅ Исправлено |
| 10 | Кеш: ISS-данные не перезаписываются T-Invest (INSERT OR IGNORE) | `market_data/service.py:275-300` | ✅ Исправлено |
| 11 | Два активных аккаунта: `scalar_one_or_none()` → ошибка | `market_data/service.py:210` | ✅ Исправлено |
| 12 | Парсинг дат ISS: строка не конвертируется в datetime | `market_data/service.py:258` | ✅ Исправлено |
| 13 | `fetchCandles` не вызывается повторно при re-login | `ChartPage.tsx:25-36` | ✅ Исправлено |
| 14 | Backend router test URLs: `market_data` → `market-data` | `test_router.py` | ✅ Исправлено |
| 15 | Frontend test: "Paper Trading" → "Нет активных сессий" | `StatusFooter.test.tsx` | ✅ Исправлено |
| 16 | Backend 500: offset-naive vs offset-aware datetime comparison | `market_data/service.py:64` | ✅ Исправлено |
| 17 | CandlestickChart: assertion failed при height=0, unreachable code | `CandlestickChart.tsx` | ✅ Исправлено |
| 18 | CandleResponse: Decimal сериализуется как строка → chart assertion failed | `market_data/schemas.py` | ✅ Исправлено (float в response) |
| 19 | Убрана кнопка скрытия OHLCV (по решению заказчика) | `ChartPage.tsx`, `ui_spec_s2.md` | ✅ Исправлено |
| 20 | Sandbox-индикатор: добавлен endpoint и запрос статуса | `broker/router.py`, `BrokerSettingsPage.tsx` | ✅ Исправлено |
| 21 | Цвета badge по типу инструмента в поиске Header | `Header.tsx` | ✅ Исправлено |

## Вопросы заказчика (разъяснения)

| # | Вопрос | Ответ |
|---|--------|-------|
| 1 | Какие данные нужны для графиков? | Автоматически через MOEX ISS (без брокера) или T-Invest (с брокером) |
| 2 | Возможности при подключении брокера? | S2: свечи, счета, баланс. S5: торговля |
| 3 | Sandbox-ключ T-Invest? | Чекбокс в форме, жёлтый Alert-индикатор |
| 4 | Два профиля (sandbox + real)? | Берётся первый активный. Полная приоритезация в S5 |
| 5 | Кеш ISS vs T-Invest? | T-Invest перезаписывает ISS (ON CONFLICT DO UPDATE) |
| 6 | Режим торговли при разных стратегиях? | Приоритет: Real > Paper > нет сессий. Реализация в S5 |
