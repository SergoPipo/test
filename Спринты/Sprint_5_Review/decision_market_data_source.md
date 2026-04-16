# Decision Record — Источник рыночных данных

**Дата:** 2026-04-15
**Статус:** принято
**Контекст:** Sprint 5 Review, диагностика графиков (см. `chart_diagnostics.md`, `changelog.md`)

## Решение

**T-Invest — единственный источник рыночных данных для всех production-функций.** MOEX ISS используется **только** как viewer-fallback, и только когда T-Invest вообще не подключён.

### Матрица «режим × подключение T-Invest → источник»

| T-Invest подключён | Режим       | Источник      | При отсутствии данных           |
|:------------------:|:------------|:--------------|:---------------------------------|
| Да                 | viewer      | T-Invest only | Пустой график + ошибка «Инструмент недоступен в T-Invest» |
| Да                 | backtest    | T-Invest only | HTTP 409 + UI-модалка «Не удалось загрузить данные T-Invest» |
| Да                 | trading     | T-Invest only | HTTP 409 + UI-модалка «Не удалось загрузить данные T-Invest» |
| Нет                | viewer      | MOEX ISS      | Badge «Данные MOEX (для просмотра)» |
| Нет                | backtest    | **БЛОК**      | HTTP 409 + UI-модалка «Подключите T-Invest для запуска бэктеста» |
| Нет                | trading     | **БЛОК**      | HTTP 409 + UI-модалка «Подключите T-Invest для запуска торговой сессии» |

**Ключевое:** если T-Invest подключён, ISS не вызывается **никогда** — даже при пустом ответе T-Invest по конкретному тикеру. Fallback на ISS разрешён исключительно в viewer-режиме при отсутствии T-Invest-аккаунта.

## Обоснование

1. **T-Invest — broker API, который фактически исполняет сделки.** Бэктест и торговля обязаны работать на тех же котировках, которые увидит `PaperBroker` / `TInvestAdapter` при реальном исполнении. Иначе — divergence между бэктестом и live-торговлей.
2. **MOEX ISS исторически содержит неточности:** extended-hours свечи, которые T-Invest не публикует; задержка публикации; и у нас в парсере был баг сдвига на −3h, который существовал месяцами без детекции. Любой третий источник — потенциальная дивергенция.
3. **Один источник = одна TZ-политика = одна точка отладки.** Merge из двух источников (текущая реализация `_fetch_candles` с объединением `tinvest + iss`) — главная причина сложностей в диагностике chart-багов.
4. **Viewer-fallback на ISS сохраняется** ради сценария «пользователь просто хочет посмотреть график, T-Invest ещё не подключён» (первый запуск, onboarding, demo). Это edge-case, не production path.

## Что это НЕ отменяет

- MOEX ISS остаётся для **metadata-эндпоинтов**: поиск инструментов (`/instruments?query=`), получение info по тикеру (`/instruments/{ticker}`), календарь торгов, облигации (bond_service). Там ISS — нормальный источник, решение касается **только OHLCV-свечей**.
- `stream_manager` для WebSocket-стриминга live-свечей — уже работает через T-Invest gRPC. Не меняется.
- Fallback `_build_current_candle` (агрегация 1m → 1h/4h) — остаётся, но переходит с T-Invest 1m данных (не ISS).

## План реализации (Фазы 2–7)

**Фаза 2 — Parser fix (backend)**
- `Develop/backend/app/broker/moex_iss/parser.py:38-40` — заменить `replace(tzinfo=MOSCOW_TZ).astimezone(UTC)` на `replace(tzinfo=timezone.utc)`, убрать неверный комментарий «MOEX ISS возвращает время в МСК».
- Обновить unit-тест `tests/unit/test_broker/test_moex_iss_parser.py` (если есть) — зафиксировать, что `"2026-04-15 07:00:00"` → `datetime(2026, 4, 15, 7, 0, tzinfo=UTC)`.

**Фаза 3 — Mode-guard в MarketDataService (backend)**
- Добавить `DataSourceMode = Literal["viewer", "backtest", "trading"]`.
- `MarketDataService.get_candles(...)` — новый обязательный параметр `mode: DataSourceMode`.
- Новое исключение: `app.common.exceptions.TInvestRequiredError(detail: str)` → HTTP 409.
- Логика выбора источника:
  ```python
  has_tinvest = bool(user_id) and await self._has_active_tinvest_account(user_id)
  if has_tinvest:
      # Только T-Invest, без fallback
      candles = await self._fetch_via_broker(...)
      return candles, "tinvest"
  else:
      if mode != "viewer":
          raise TInvestRequiredError(f"Режим {mode} требует подключения T-Invest")
      # Viewer без T-Invest — только ISS
      candles = await self._fetch_via_iss(...)
      return candles, "moex_iss"
  ```
- Удалить логику объединения `_fetch_via_broker + _fetch_via_iss` (сейчас в `_fetch_candles:346-407`) — больше не нужна.
- Обновить вызовы `get_candles` во всех местах:
  - `app/backtest/engine.py` — передать `mode="backtest"`.
  - `app/trading/service.py` / `app/trading/session_runtime.py` — передать `mode="trading"`.
  - `app/market_data/router.py` — `mode` из query-параметра, default `"viewer"`.

**Фаза 4 — Alembic data-миграция: полная очистка кэша**
- Новая revision `wipe_ohlcv_cache_tz_fix`:
  ```python
  def upgrade() -> None:
      op.execute("DELETE FROM ohlcv_cache")
  def downgrade() -> None:
      pass  # откатывать нечего, кэш перезапросится
  ```
- Применяется автоматически при `alembic upgrade head` после git pull.

**Фаза 5 — Frontend error handling (409 T-Invest required)**
- В `api/client.ts` axios interceptor на response.status === 409 с типом ошибки `TInvestRequired` → глобальный event / toast / модалка.
- Новый компонент `TInvestRequiredModal` с текстом и кнопкой «В настройки брокера» → `navigate('/settings/broker')`.
- Показывается при:
  - Запуске бэктеста без T-Invest.
  - Запуске торговой сессии без T-Invest.
- На ChartPage — badge «Данные MOEX (нет подключения T-Invest)» когда `dataSource === 'moex_iss'`. Уже почти реализовано через существующий индикатор источника — только сменить текст.

**Фаза 6 — Очистка кода (необязательно, но желательно)**
- Удалить константу `"tinvest+iss"` из возможных значений `source` (больше не используется).
- Удалить блок `iss_tail merge` в `_fetch_candles:346-379`.
- Упростить `_save_to_cache` — source всегда либо `"tinvest"`, либо `"moex_iss"`.

**Фаза 7 — E2E проверка**
- Playwright-сценарии:
  1. T-Invest подключён → SBER 1h → последняя свеча в текущий торговый час MSK. Повтор для 5m/15m/4h/D.
  2. T-Invest подключён → GAZP/LKOH → то же самое.
  3. T-Invest отключён → ChartPage SBER → работает, показан badge «Данные MOEX».
  4. T-Invest отключён → запуск бэктеста → появляется модалка «Подключите T-Invest».
  5. T-Invest отключён → запуск сессии → та же модалка.
- Визуальная верификация: скриншот SBER 1h в середине торгового дня — последняя свеча должна быть на XX:00 текущего часа MSK, не на XX−3:00.

## Влияние на другие модули

| Модуль                              | Влияние                                                                      |
|:------------------------------------|:-----------------------------------------------------------------------------|
| `app/backtest/engine.py`            | Передавать `mode="backtest"` в get_candles. 409 → UI-модалка.                |
| `app/trading/service.py`            | Передавать `mode="trading"`. Создание сессии без T-Invest — блокируется.     |
| `app/trading/session_runtime.py`    | Live-runtime уже использует T-Invest stream. Historical запросы — тоже.      |
| `app/market_data/router.py`         | `GET /candles` — добавить query-param `mode`, default `"viewer"`.            |
| `app/market_data/stream_manager.py` | Без изменений — уже только T-Invest.                                          |
| `frontend/backtestStore.ts`         | Обработать 409 → показать модалку.                                           |
| `frontend/tradingStore.ts`          | То же.                                                                       |
| `frontend/marketDataStore.ts`       | При `dataSource === 'moex_iss'` показать warning-badge.                      |

## Риски и митигации

1. **Риск: после DELETE кэша — всплеск запросов к T-Invest при первом открытии.** Митигация: запросы лениво, только по факту открытия графика пользователем. T-Invest rate limit = 300 req/min, кэш наполнится за минуты.
2. **Риск: после фикса parser.py, свежие ISS-данные правильные, но кэш удалён → viewer-режим будет перезапрашивать ISS.** Митигация: это и есть ожидаемое поведение. ISS-запросы редкие (только для пользователей без T-Invest).
3. **Риск: существующие бэктесты, созданные на старых (сдвинутых) данных, теперь покажут другие результаты при re-run.** Митигация: это правильная замена некорректных данных на корректные. Уже сохранённые `BacktestResult` остаются как исторические записи, их не пересчитываем.
4. **Риск: тикеры, которых нет на T-Invest (редкие облигации), станут недоступны пользователям с подключённым T-Invest (по решению вариант A).** Митигация: принимаем. Если таких тикеров окажется много — откатить на вариант B (viewer-fallback на ISS при пустом T-Invest) без ломки API.

## Что решение НЕ включает (out of scope)

- Offline-режим / long-term кэширование для обучения / backtest-reproducibility — отдельная задача для Sprint 6+.
- Альтернативные источники (Finam, Quik, etc.) — не рассматриваются.
- Кэш-инвалидация по сигналу от T-Invest при split/dividend — отдельный issue в corporate_actions.
