# Sprint 5: Changelog

> Лог всех изменений Sprint 5

---

## 2026-04-13 — Фиксация кода S5-замечаний 33-41 и работ 13.04 в репо moex-terminal

**Контекст:** Обнаружено при закрытии S5, что репозиторий кода `Develop/` (moex-terminal, private) отстаёт от документации — весь код замечаний 33-41 и работ 13.04 (bugfix SL/TP, UI-фиксы) был **в рабочей копии, но не закоммичен**. Причина: при оформлении закрытия S5 я (ассистент) ошибочно решил, что `Develop/` находится вне git (увидел его в `.gitignore` главного репо `test`, но не заметил, что внутри `Develop/` есть свой вложенный `.git` с remote `github.com:SergoPipo/moex-terminal.git`). В результате 19 modified-файлов и 1 новый файл висели без коммита.

**Исправлено:** 6 атомарных коммитов в ветку `develop` репо `moex-terminal`:

| # | Коммит | Хеш | Замечания |
|---|--------|-----|-----------|
| 1 | `chore(gitignore): игнорировать test-results/ от playwright и pytest` | `40d611d` | — (уборка) |
| 2 | `feat(frontend): единая история последних инструментов + чистка ошибок модалки` | `9781ac0` | 34, 36 |
| 3 | `fix(backtest): __import__ not found + safe whitelist + SL/TP от цены исполнения` | `23674ca` | 33, 35, bugfix SL/TP 13.04 |
| 4 | `feat(backtest): перезапуск + навигация из результатов в стратегию` | `24ec462` | 37, 38, 39, 40 |
| 5 | `fix(strategy): «Применить на схеме» — блоки сигналов не отображались` | `82953b3` | 41 |
| 6 | `fix(ui): подписи лотов масштабируются с зумом + переименование «Просадка»` | `9697b47` | UI-фиксы 13.04 |

Все 6 коммитов запушены в `origin/develop` репо `moex-terminal`. Мердж `develop → main` не делался (в этом репо принята модель git-flow: `main` обновляется только по релизам, сейчас отстаёт от `develop` на 19 коммитов — это соответствует общему стилю работы).

**Дополнение к `.gitignore`**: в коммите `40d611d` добавлены правила для `test-results/`, `backend/test-results/`, `frontend/test-results/` — артефакты Playwright traces и pytest junit-репортов больше не засоряют git status.

**Урок для будущих спринтов**: при коммите всегда проверять оба репозитория (public `test` и private `moex-terminal`), спрашивать имена веток отдельно для каждого. Правило зафиксировано в memory: `feedback_two_repos.md`.

---

## 2026-04-13 — Bugfix: SL/TP рассчитывались от цены сигнала, а не от цены исполнения

**Проблема**: Стратегия с SL=2% и TP=4% показывала в бэктесте сделки с убытком >2% и прибылью >4%. Три бага в `code_generator.py`:
1. SL/TP выставлялись от `self.data.close[0]` (цена закрытия сигнальной свечи), а вход исполнялся на открытии следующей — SL/TP уровни не соответствовали реальному входу
2. Нет OCO-логики: при срабатывании SL тейк-профит оставался активным, и наоборот
3. Для short-позиций SL/TP использовали `self.sell()` вместо `self.buy()` (неправильное направление закрытия)

**Решение**: Переделана генерация SL/TP в `code_generator.py`:
- Добавлен метод `notify_order` — SL/TP выставляются после фактического заполнения входного ордера, от `order.executed.price`
- OCO: при срабатывании одного ордера парный автоматически отменяется
- Корректное направление для long/short: SL/TP для short используют `self.buy()`
- В `next()` при exit signal — отмена висящих SL/TP перед `self.close()`

**Файлы**:
- `backend/app/strategy/code_generator.py`: `_gen_init` (трекинг-переменные), `_gen_notify_order` (новый метод), `_gen_next` (убраны прямые SL/TP, добавлен трекинг entry_order, отмена SL/TP при exit)
- `backend/tests/unit/test_strategy/test_code_generator.py`: обновлены assertions (убран устаревший import-чек, адаптированы проверки под новую структуру next())

**Тесты**: 12/12 passed

**Дополнение 1**: SL/TP ордера не указывали `size` — Backtrader закрывал только 1 лот вместо всей позиции. Добавлен `size=pos_size` (`pos_size = abs(self.position.size)`) во все SL/TP ордера в `notify_order`.

**Дополнение 2 (корневая причина)**: Backtrader **клонирует** объект ордера в `notify_order` — `order is self._entry_order` всегда `False` (разные id объектов при одинаковом `ref`). Заменено на сравнение по `order.ref == self._entry_order.ref`. Подтверждено прямым тестом с Backtrader: TP/SL теперь корректно срабатывают. Тесты: 12/12 passed.

## 2026-04-13 — UI: подписи лотов на графике не масштабировались со стрелками

**Проблема**: При зуме графика стрелки входа/выхода масштабировались (маркеры lightweight-charts), а текст с количеством лотов оставался фиксированным (16px) — наезжал на стрелки или терялся.

**Решение**: Убрана ручная отрисовка текста на canvas overlay. Вместо этого количество лотов передаётся в свойство `text` маркера lightweight-charts (`SeriesMarker.text`). Библиотека сама рисует текст и масштабирует его вместе со стрелкой.

**Файлы**: `frontend/src/components/backtest/InstrumentChart.tsx` — убрана ручная отрисовка в `drawBgZones()`, добавлено `text: m.text` в создание маркеров

**Тесты**: E2E backtest-results 5/5 passed, TypeScript — без ошибок

## 2026-04-13 — UI: показатель «Рост / Просадка» показывал только просадку

**Проблема**: Серия «Рост / Просадка» вводила в заблуждение названием — показывала только просадку от пика (underwater equity curve, всегда ≤ 0), но называлась «Рост / Просадка».

**Решение**: Переименована в «Просадка». Формула оставлена стандартная (underwater equity — падение от пика), как в TradingView Strategy Tester и MetaTrader.

**Файлы**: `frontend/src/components/backtest/StrategyTesterPanel.tsx` — переименование label

**Тесты**: E2E backtest-results 5/5 passed, TypeScript — без ошибок

---

## 2026-04-08 — Замечания по ручному тестированию

**Замечание 1: Скроллинг на странице торговли**
- `components/layout/AppShell.tsx`: `overflow: 'hidden'` → `overflowY: 'auto'` в AppShell.Main
- Причина: контент за пределами viewport обрезался, список сессий не прокручивался

**Замечание 2: Несоответствие mode/status между списком и деталями сессии**
- `backend/app/trading/schemas.py`: добавлены поля `strategy_name` и `current_pnl` в `SessionResponse`
- `backend/app/trading/service.py`: добавлены методы `_get_strategy_name()` и `_get_session_pnl()`, заполняют новые поля в `get_sessions()` и `get_session()`
- `frontend/stores/tradingStore.ts`: `fetchSession` теперь извлекает `raw.session` из вложенного `SessionDetailResponse`
- Причина: API деталей возвращал `{ session: {...} }`, а store записывал весь объект как `activeSession` — поля mode/status были undefined

**Замечание 3: Кнопка «Назад» на странице деталей сессии**
- `components/trading/SessionDashboard.tsx`: добавлен `IconArrowLeft` с навигацией на `/trading`
- Добавлены импорты `useNavigate`, `IconArrowLeft`

**Замечание 4: Тестовые сессии**
- Проверено: 23 сессии в БД, все от E2E тестов (TEST*, LNC* — мусорные тикеры; SBER/GAZP/LKOH — тестовые без реальных данных)
- Стратегия «Тестовая» (id=1) — пустой код, все сессии привязаны к ней
- Решение: не баг, следствие E2E тестирования. Очистка по запросу

**Замечание 6: Красные чёрточки P&L и кнопка удаления**
- `components/trading/SessionCard.tsx`: P&L=0 и null теперь отображаются серым (dimmed), а не красным
- `components/trading/SessionDashboard.tsx`: аналогичный фикс цвета P&L
- `components/trading/SessionCard.tsx`: добавлена кнопка удаления (IconTrash), активна только для остановленных сессий
- `backend/app/trading/router.py`: новый endpoint `DELETE /sessions/{id}` (204, только stopped)
- `backend/app/trading/service.py`: метод `delete_session()` — удаляет сессию + связанные LiveTrade, DailyStat, PaperPortfolio
- `frontend/api/tradingApi.ts`: добавлен `deleteSession(id)`
- `frontend/stores/tradingStore.ts`: добавлен `deleteSession(id)` — удаляет из списка и сбрасывает activeSession

**Замечание 9: Маркеры сделок на графике**
- `pages/ChartPage.tsx`: подключён `useTradingStore`, находит активную/paused сессию для текущего тикера
- Передаёт `sessionId={activeSessionId}` в `CandlestickChart`
- Компонент уже поддерживает маркеры (▲ Buy / ▼ Sell) через WebSocket `trades:{sessionId}`
- Ранее не работало из-за отсутствия передачи sessionId

**Замечание 8+: Стриминг свечей в реальном времени (РЕАЛИЗОВАНО)**
- `backend/app/market_data/stream_manager.py`: новый `MarketDataStreamManager` — подписка на T-Invest gRPC стрим, публикация через Event Bus → WebSocket
- `backend/app/market_data/router.py`: новый endpoint `POST /candles/subscribe` — возвращает WebSocket channel для подписки
- `frontend/api/marketDataApi.ts`: добавлен `subscribeCandleStream(ticker, timeframe)`
- `frontend/pages/ChartPage.tsx`: при загрузке графика подписывается на стрим, передаёт `wsChannel` в CandlestickChart
- CandlestickChart уже поддерживал wsChannel и обновление свечей через `candle.update` — теперь подключён

**Замечание 24: График в московском времени**
- `components/charts/CandlestickChart.tsx`: `parseUtcTimestamp()` сдвигает unix timestamp на +3 часа (MSK)
- Lightweight-charts не поддерживает опцию `timeZone` — оси всегда в UTC
- Решение: смещение таймштампов на +3 часа перед передачей в график, теперь ось X показывает МСК
- Соответствует отображению времени в футере (Europe/Moscow)

**Замечание 23: Хвост T-Invest устарел → дозапрос MOEX ISS**
- `backend/app/market_data/service.py`: новый метод `_tail_tolerance(timeframe)` — общая логика допустимого отставания хвоста
- `_fetch_candles()`: если T-Invest вернул данные, но последняя свеча старше `tail_tolerance` от `to_dt` — дозапрашивается MOEX ISS для хвоста и объединяется
- Источник в логе: `tinvest+iss` при объединении
- Причина: для некоторых тикеров (LKOH, GAZP) T-Invest GetCandles может отставать на 1-3 часа, а MOEX ISS отдаёт актуальные данные через свой публичный API
- Это решает пропуск свечей в середине дня для часового и других ТФ

**Замечание 22: Пропуск предыдущей свечи на часовом ТФ**
- `backend/app/market_data/service.py`:
  - `_build_current_candle()` переработан: возвращает 1–2 свечи (предыдущую + текущую)
  - Причина: T-Invest `GetCandles` запаздывает с публикацией только что закрытых свечей на 5–30 минут
  - Решение: всегда перестраивать последние 2 свечи из 1m агрегации, заменяя значения в кеш-результате
  - Новые вспомогательные методы: `_period_start()`, `_aggregate_candles()`

**Замечание 21: Скрытие недоступных режимов запуска сессии**
- `components/trading/LaunchSessionModal.tsx`: SegmentedControl теперь динамически формирует список режимов
  - `Paper` — всегда доступен
  - `Sandbox` — только если есть активный sandbox-аккаунт T-Invest
  - `Real` — только если есть активный production-аккаунт с `has_trading_rights=true`
- Автопереключение на `Paper` если выбранный ранее режим стал недоступным (например, аккаунт удалён)

**Замечание 20: Выбор брокерского аккаунта + режим Sandbox**

Backend:
- `backend/app/broker/tinvest/adapter.py`: новый `detect_trading_rights()` — проверяет `unary_limits` токена через `get_user_tariff()`, определяет доступ к `OrdersService.PostOrder`
- `backend/app/broker/models.py`: добавлено поле `has_trading_rights` в `BrokerAccount`
- `backend/app/broker/schemas.py`: поле `has_trading_rights` в `BrokerAccountResponse`
- `backend/app/broker/service.py`: `create_account()` автоматически определяет права торговли
- `backend/app/trading/schemas.py`: режим `sandbox` добавлен в `VALID_MODES` и `Literal`
- `backend/app/trading/service.py`: `start_session()` валидирует при real/sandbox:
  - Брокерский аккаунт существует и принадлежит пользователю
  - `mode=sandbox` → `is_sandbox=True`, `mode=real` → `is_sandbox=False`
  - `has_trading_rights=True` обязательно
- БД: колонка `has_trading_rights` добавлена, аккаунты заполнены (Сэндбокс=True, «Только для чтения»=False)

Frontend:
- `frontend/src/api/brokerApi.ts`: `has_trading_rights` в `BrokerAccountResponse`
- `frontend/src/components/trading/LaunchSessionModal.tsx`:
  - SegmentedControl теперь 3 варианта: Paper / Sandbox / Real
  - Загрузка реальных брокерских аккаунтов через `brokerApi.getAccounts()` (было: хардкод фейковых)
  - Фильтрация: sandbox → только sandbox, real → только production с правами торговли
  - Сброс выбранного аккаунта при смене режима
  - Отдельные Alert для каждого режима (paper/sandbox/real)
  - Подсказка когда нет подходящих аккаунтов

**Замечание 19: Убрано поле «Макс. одновременных позиций» из модалки запуска сессии**
- `components/trading/LaunchSessionModal.tsx`: удалён `NumberInput` для `maxPositions`
- Причина: Blockly-стратегии не поддерживают множественные позиции (обсуждено ранее)
- Значение по умолчанию изменено с 3 на 1, передаётся в API скрыто

**Замечание 18: Номер сессии на странице деталей**
- `components/trading/SessionDashboard.tsx`: добавлен `#{session.id}` между тикером и названием стратегии
- Также `strategy_name` показывает «(удалённая стратегия)» если пусто

**Замечание 17: Выравнивание карточек сессий в списке + стратегия всегда видна**
- `components/trading/SessionCard.tsx`: карточки теперь фиксированной минимальной высоты (180px)
  - `Stack justify="space-between"` — кнопки всегда внизу карточки
  - `strategy_name` отображается всегда: если стратегия удалена → «(удалённая стратегия)»
  - `lineClamp={1}` — длинные названия обрезаются
- `components/trading/SessionDashboard.tsx`: откачены изменения (кнопки остались раздельные для active/stopped)
- `backend/app/trading/models.py`: добавлено поле `strategy_name` в модель TradingSession (VARCHAR 200)
- `backend/app/trading/service.py`: `_get_strategy_name()` возвращает «(удалённая стратегия)» если JOIN не нашёл запись
- БД: колонка добавлена, существующие 8 сессий заполнены через UPDATE

**E2E тест: Актуальность данных на всех таймфреймах**
- `frontend/e2e/s5-chart-timeframes.spec.ts`: 5 тестов (D, 4h, 1h, 15m, 5m)
- Каждый тест: переключает ТФ → запрашивает API → проверяет что последняя свеча не старше порога
- Пороги: D=24ч, 4h=4ч, 1h=1ч, 15m=30мин, 5m=12мин

**Замечание 16: Текущая формирующаяся свеча через агрегацию 1m**
- `backend/app/market_data/service.py`: новый метод `_build_current_candle()`
  - T-Invest GetCandles возвращает только завершённые свечи
  - Для текущей незакрытой свечи: запрашиваем 1m свечи за текущий период и агрегируем OHLCV
  - Работает для 5m, 15m, 1h, 4h, D, W
  - Результат добавляется/обновляется в конце массива свечей
- `components/charts/CandlestickChart.tsx`: `parseUtcTimestamp()` — таймштампы без Z парсятся как UTC

**Замечание 15: Номер сессии на карточке в списке**
- `components/trading/SessionCard.tsx`: добавлен `#{session.id}` рядом с тикером

**Замечание 14: Стриминг не работал (500 ошибка)**
- `backend/app/market_data/router.py`: добавлен `from sqlalchemy import select` — отсутствовал, вызывал NameError при подписке на стрим
- `backend/app/market_data/router.py`: выбор аккаунта `ORDER BY is_sandbox ASC` — production первым
- После исправления: `POST /candles/subscribe?ticker=SBER&timeframe=1h` → `{"channel": "market:SBER:1h", "source": "tinvest"}`

**Замечание 13: Баннер сессии в строку таймфреймов, свежие данные на всех ТФ, избранное**
- `pages/ChartPage.tsx`: баннер сессии перенесён в строку таймфреймов (справа, компактно)
- `backend/app/market_data/service.py`: tail_tolerance теперь точно соответствует таймфрейму:
  D=6ч, 4h=4ч, 1h=1ч, 5m/15m=duration×2 — данные всегда актуальны при смене ТФ
- `components/charts/FavoritesPanel.tsx`: убран вводящий в заблуждение процент (avg_pnl_pct=0)
- `components/charts/CandlestickChart.tsx`: `parseUtcTimestamp()` — таймштампы без Z интерпретируются как UTC

**Замечание 12: Кнопка графика внутри торговой сессии**
- `components/trading/SessionDashboard.tsx`: добавлена кнопка графика (IconChartLine) — видна всегда, переходит на `/chart/{ticker}`
- Кнопка «Назад» на графике использует `navigate(-1)` — вернёт обратно внутрь сессии

**Замечание 10: Кнопка «Назад» на странице графика**
- `pages/ChartPage.tsx`: добавлена кнопка ← (IconArrowLeft) с `navigate(-1)` — возвращает на предыдущую страницу (торговля, бэктесты и т.д.)

**Замечание 11: Агрегация минутных свечей для старших таймфреймов**
- `backend/app/market_data/stream_manager.py`: T-Invest gRPC поддерживает подписку только на 1m и 5m
- Для 15m, 1h, 4h, D, W, M — подписка на 1m с агрегацией через `_AggregatingCandle`
- Агрегатор: определяет начало периода (`_candle_period_start`), аккумулирует OHLCV минутных свечей в текущую формирующуюся свечу нужного ТФ

**Замечание 8++: Исправление timezone MOEX ISS**
- `backend/app/broker/moex_iss/parser.py`: MOEX ISS возвращает время в МСК → теперь явно конвертируется в UTC через `.astimezone(timezone.utc)`
- Ранее: `.replace(tzinfo=MOSCOW_TZ)` — привязывал таймзону, но не конвертировал, вызывая сдвиг при сравнении с UTC-данными T-Invest

**Замечание 8: График не показывает данные до текущего момента**
- `backend/app/market_data/service.py`: разделён tolerance на два уровня:
  - `mid_tolerance` — для промежуточных gap'ов (выходные/праздники): D=5 дней, W=14, M=45, интрадей=3 дня
  - `tail_tolerance` — для правого края (актуальность данных): D/W/M=2 дня, интрадей=2 часа
- Причина: единый tolerance=5 дней для D приводил к тому, что кеш с данными от 06.04 считался актуальным 08.04 и не дозапрашивал свежие свечи
- После исправления: tail_tolerance учитывает что T-Invest и MOEX поддерживают торги в выходные для ряда инструментов
  - M: 2 дня, W: 1 день, D: 18 часов, интрадей: duration×3 (мин. 30 мин)
  - Промежуточные gap'ы (mid_tolerance) оставлены с запасом на выходные/праздники

**Замечание 7: Удаление и перезапуск в деталях сессии**
- `components/trading/SessionDashboard.tsx`: для остановленных сессий показываются 2 кнопки:
  - «Запустить заново» (IconRestore) — создаёт новую сессию с теми же параметрами и переходит на неё
  - «Удалить» (IconTrash) — удаляет сессию и возвращает к списку
- `api/types.ts`: расширен `TradingSession` — добавлены `strategy_version_id`, `broker_account_id`, `position_sizing_mode`, `position_sizing_value`, `max_concurrent_positions`, `cooldown_seconds`

**Замечание 5: Autocomplete тикера в модалке запуска сессии + мин. 1 символ**
- `components/trading/LaunchSessionModal.tsx`: `TextInput` → `Autocomplete` с поиском через `marketDataApi.searchInstruments()`, debounce 300мс
- `components/backtest/BacktestLaunchModal.tsx`: `query.length < 2` → `< 1`
- `components/layout/Header.tsx`: `query.length < 2` → `< 1`
- Поиск инструментов теперь начинается с 1 символа во всех 3 компонентах

---

## 2026-04-07

### Фаза 0: Отложенные задачи S4 Review

**#15 — float→Decimal в block_parser.py** (Medium, M)
- `block_parser.py`: добавлен `from decimal import Decimal, InvalidOperation`
- Все финансовые параметры переведены на `Decimal`: zone bounds, indicator thresholds, stop_loss (percent/points), take_profit (percent/points), position_size (percent), generic params
- `code_generator.py`: добавлен `from decimal import Decimal`, обновлён `isinstance` check для поддержки `Decimal`

**#16 — code_generator.py параметры** (Medium, S) → закрыто в рамках #15
- `isinstance(right_ref, (int, float, Decimal))` — поддержка всех числовых типов

**#23 — фильтрация поиска по instrument_type** (Low, S)
- `market_data/router.py`: добавлен query-параметр `instrument_type: str | None`
- `frontend/api/marketDataApi.ts`: добавлен параметр `instrumentType?` в `searchInstruments()`

**#24 — иконки сортировки в таблице сделок** (Low, S)
- `BacktestTrades.tsx`: добавлен `color="var(--mantine-color-blue-4)"` для `IconArrowUp`/`IconArrowDown`

**#28 — DI для синглтонов chat_router.py** (Low, M)
- Добавлены DI-фабрики: `get_ai_service()`, `get_history_manager()`, `get_context_compressor()`
- Endpoint'ы `chat`, `chat/stream`, `explain`, `history`, `clear` переведены на `Depends()`
- Модульные синглтоны сохранены для обратной совместимости тестов
- Тест-mock: добавлен `get_last_usage` в `_mock_provider` — исправлены 2 ранее падавших теста

### Планирование
- Создан `execution_order.md` — порядок выполнения задач
- Создан `sprint_state.md` — начальное состояние
- Создан `changelog.md`
- Ветка: `s5/trading` от main (6cafadb)

### Prompt-файлы (7 штук)
- `prompt_UX.md` — дизайн Trading Panel, Account, Favorites, RT-графики
- `prompt_DEV-1.md` — Trading Engine, Paper Trading, Broker Adapter (6 методов + streaming), Rate Limiter
- `prompt_DEV-2.md` — Circuit Breaker (9 проверок, asyncio.Lock, интеграция с OrderManager)
- `prompt_DEV-3.md` — Bond Service (НКД), Corporate Actions, Tax Export (FIFO, 3-НДФЛ, xlsx/csv)
- `prompt_DEV-4.md` — Frontend Trading Panel, SessionCard, LaunchModal, WS real-time, маркеры сделок
- `prompt_DEV-5.md` — Frontend Account Screen, BalanceCards, TaxReportModal, FavoritesPanel ★
- `prompt_ARCH_review.md` — ревью всех модулей, E2E тесты (4 сценария), проверка latency
- `preflight_checklist.md` — предполётная проверка ПО и зависимостей (7 секций)

### Preflight: установка зависимостей
- Установлены `openpyxl 3.1.5` (xlsx-экспорт для налогового отчёта) и `APScheduler 3.11.2` (MOEX-календарь)

### DEV-1: Trading Engine + Broker Adapter (Волна 1)

**Задача 1 — Trading Engine (`app/trading/engine.py`)** — СОЗДАН
- `TradingSessionManager`: start_session (конфликт-проверка, PaperPortfolio), pause, resume, stop, restore_sessions
- `SignalProcessor`: process_candle → Signal (BUY/SELL/HOLD), кеширование стратегий, sandbox execution
- `OrderManager`: process_signal (cooldown, max positions, position sizing), close_position, close_all_positions, DailyStat
- `PositionTracker`: update_position, calculate_unrealized_pnl, on_order_filled (portfolio update, peak equity)
- Классы: `Signal`, `SignalAction` (enum), `SessionStartParams` (dataclass)
- EventBus-события: session.started/paused/resumed/stopped, order.placed, trade.filled/closed, positions.closed_all

**Задача 2 — Paper Trading Engine (`app/trading/paper_engine.py`)** — СОЗДАН
- `PaperBrokerAdapter(BaseBrokerAdapter)`: полная реализация интерфейса брокера для бумажной торговли
- Виртуальное исполнение с slippage (0.05%), проверка достаточности средств
- T+1 settlement: blocked_amount в PaperPortfolio
- Методы: place_order, get_positions, get_balance, subscribe_candles, get_operations

**Задача 3 — Broker Adapter** — МОДИФИЦИРОВАН
- `app/broker/base.py`: добавлены dataclasses (PositionInfo, OrderResponse, OrderStatus, InstrumentInfo)
- Добавлены абстрактные методы: subscribe_candles, unsubscribe, get_operations
- Обновлены return types стабов: get_positions→list[PositionInfo], place_order→OrderResponse и др.
- `app/broker/tinvest/adapter.py`: реализованы 6 stub-методов + 3 новых (subscribe_candles, unsubscribe, get_operations)
- subscribe_candles: gRPC streaming с auto-reconnect через asyncio.Task
- `app/broker/tinvest/mapper.py`: 4 новых метода маппинга (portfolio_position, order_response, order_state, instrument)
- `app/broker/__init__.py`: экспортированы новые dataclasses

**Задача 4 — Rate Limiter** — МОДИФИЦИРОВАН
- `app/broker/tinvest/rate_limiter.py`: добавлены get_state/restore_state в TokenBucketRateLimiter
- Новый класс `PersistentTokenBucketRateLimiter`: load/save JSON-файл (data/rate_limiter_state.json)
- Функции `save_all_limiters()`, `load_all_limiters()` для shutdown/startup

**Задача 5 — Trading Schemas (`app/trading/schemas.py`)** — ЗАПОЛНЕН
- Pydantic v2: SessionStartRequest (model_validator для real mode), SessionResponse, TradeResponse
- PositionResponse, DailyStatResponse, PaperPortfolioResponse, SessionDetailResponse
- DashboardResponse, PaginatedResponse, ClosePositionRequest, SessionFilterParams, TradeFilterParams

**Задача 6 — Trading Router (`app/trading/router.py`)** — ЗАПОЛНЕН
- POST/GET /sessions, GET /sessions/{id}, PATCH pause/resume/stop
- GET /sessions/{id}/positions, POST close position, POST close-all
- GET /sessions/{id}/trades (пагинация), GET /sessions/{id}/stats
- GET /positions (все), GET /dashboard

**Задача 7 — Trading Service (`app/trading/service.py`)** — ЗАПОЛНЕН
- `TradingService`: оркестрация Router ↔ Engine через DI (get_db → TradingService)
- CRUD сессий, позиций, сделок + stats + dashboard
- get_all_positions — кросс-сессионный запрос через JOIN

**Тесты — 55 тестов в tests/test_trading/**
- test_engine.py: 12 тестов (start, pause, resume, stop, restore, конфликты)
- test_order_manager.py: 8 тестов (signals, sizing, close, close_all)
- test_position_tracker.py: 5 тестов (update, P&L, on_order_filled, portfolio)
- test_paper_engine.py: 7 тестов (connect, balance, place_order, slippage, insufficient_funds)
- test_schemas.py: 10 тестов (валидация, defaults, real mode validation)
- test_service.py: 6 тестов (start, list, detail, lifecycle, dashboard)
- test_router.py: 4 теста (HTTP endpoints: dashboard, list, detail, 404)
- conftest.py: фикстуры (db_session, test_user, test_strategy_version, test_session, test_trade)
- Итого: 512 passed, 0 failed (включая 457 существующих)

### DEV-2: Circuit Breaker (Волна 2)

**Задача 1 — CircuitBreakerConfig модель (`app/circuit_breaker/models.py`)** — ДОБАВЛЕНА
- `CircuitBreakerConfig`: per-user + per-session override конфигурация
- Поля: daily_loss_limit_pct/fixed, max_drawdown_pct, max_position_size, daily_trade_limit, cooldown_seconds, trading_hours_start/end, block_shorts
- UniqueConstraint(user_id, session_id), Index(user_id)

**Задача 2 — CircuitBreakerEngine (`app/circuit_breaker/engine.py`)** — СОЗДАН
- 9 проверок: daily_loss_limit, max_drawdown, position_size_limit, daily_trade_limit, duplicate_instrument, cooldown, trading_hours, short_block, insufficient_funds_streak
- asyncio.Lock per user_id для race conditions
- `_trigger()`: запись CircuitBreakerEvent + пауза сессии(й) + EventBus publish (notifications + trades:{session_id})
- daily_loss и max_drawdown → пауза ВСЕХ сессий пользователя
- Торговый день с 10:00 MSK (UTC+3)
- Ленивый вызов проверок (lambda) для корректного управления корутинами

**Задача 3 — Schemas (`app/circuit_breaker/schemas.py`)** — СОЗДАН
- Pydantic v2: CircuitBreakerConfigRequest/Response, CircuitBreakerEventResponse, CheckStatusResponse

**Задача 4 — Router (`app/circuit_breaker/router.py`)** — СОЗДАН
- GET/PUT /config, PUT /config/session/{id}, GET /events, GET /events/session/{id}, GET /status
- НЕ зарегистрирован в main.py (по требованию задачи)

**Задача 5 — Service (`app/circuit_breaker/service.py`)** — ЗАПОЛНЕН
- CRUD конфигурации (upsert глобальная + session override)
- Получение событий (пагинация, фильтр по сессии)
- get_status: trades_today, daily_pnl, current_drawdown, лимиты

**Задача 6 — Интеграция с OrderManager** — ДОБАВЛЕНА
- `app/trading/engine.py`: OrderManager.process_signal() принимает опциональный user_id
- При наличии user_id — вызов CircuitBreakerEngine.check_before_order() перед ордером
- Обратная совместимость: без user_id CB не вызывается

**Alembic миграция** — СОЗДАНА
- `b5f6c7d8e9f0_add_circuit_breaker_configs.py`: CREATE TABLE circuit_breaker_configs

**Тесты — 36 тестов в tests/test_circuit_breaker/**
- test_engine.py: 18 тестов (каждая из 9 проверок: pass + block, trigger, daily_loss pauses all, race condition lock)
- test_config.py: 4 теста (create, update/upsert, session override, get_config None)
- test_router.py: 8 тестов (логика endpoints через service: config CRUD, events, status)
- test_integration.py: 4 теста (CB + OrderManager: short block, passes, skip CB without user_id, insufficient_funds)
- conftest.py: фикстуры (db_session, test_user, test_strategy/version, test_session, test_config)
- Итого: 548 passed, 0 failed (включая 512 существующих)

### Preflight: исправление 47 падающих тестов → 422 passed, 0 failed
- `block_parser.py:385` — `block_idx` не определён → добавлен `enumerate(blocks)`
- `test_round_trip.py` — 5 тестов: логические блоки OR/AND/NOT имеют type `"logic"`, не `"condition"`
- `test_ai/` (13 тестов) — модель `AIProviderConfig` изменилась: `daily_limit` → `prompt_tokens_limit` и др.
- `test_ai/test_providers.py` — `"gemini"` теперь поддерживается, заменён на `"unknown_provider"`
- `sandbox/executor.py` — `signal.alarm()` не работает вне main thread → добавлен fallback через threading
- `auth/service.py` — `max_attempts=50` в DEBUG-режиме ломал тесты → `getattr(settings, "LOGIN_MAX_ATTEMPTS", 5)`
- `test_backtest/test_api.py` — метрики во вложенном объекте `data["metrics"]["total_trades"]`
- `test_backtest/test_engine.py` — `callback in all_args` → `any(arg is callback for arg in all_args)` (pandas)

### DEV-4: Trading Panel + Real-time Charts (Волна 3)

**Задача 1 — TypeScript типы (`src/api/types.ts`)** — ДОБАВЛЕНЫ
- TradingSession, LiveTrade, Position, SessionStartRequest, TradingDashboard, SessionStats
- Все типы соответствуют Backend API из DEV-1

**Задача 2 — Trading API (`src/api/tradingApi.ts`)** — СОЗДАН
- startSession, getSessions, getSession, pauseSession, resumeSession, stopSession
- getPositions, closePosition, closeAllPositions, getTrades, getStats, getDashboard
- Типизированные ответы через generics Axios

**Задача 3 — Trading Store (`src/stores/tradingStore.ts`)** — СОЗДАН
- Zustand store: sessions, activeSession, positions, trades, stats, dashboard
- Все CRUD actions + WS update методы: updateSessionFromWS, addTradeFromWS, updatePositionFromWS
- Паттерн аналогичен backtestStore (loading, error, clearError)

**Задача 4 — WebSocket Hook (`src/hooks/useWebSocket.ts`)** — СОЗДАН
- Generic мультиплексированный singleton WebSocket
- subscribe/unsubscribe по каналам, auto-reconnect с exponential backoff (до 30с)
- Re-subscribe всех каналов при reconnect
- getWSConnectionState() для индикатора подключения

**Задача 5 — TradingPage (`src/pages/TradingPage.tsx`)** — СОЗДАН
- Маршрут `/trading`: заголовок «Торговля» + кнопка «Запустить сессию»
- SessionList + LaunchSessionModal
- Состояния: loading, error с Alert

**Задача 6 — Trading Components (`src/components/trading/`)** — СОЗДАНЫ
- `SessionCard.tsx`: Badge PAPER (yellow.6) / REAL (red.6), P&L с цветом, кнопки Пауза/Стоп/График
- `SessionList.tsx`: SegmentedControl фильтр (все/active/paused/stopped), Select сортировка (дата/P&L), пустое состояние
- `LaunchSessionModal.tsx`: Modal с SegmentedControl Paper/Real, Select стратегия, TextInput тикер, NumberInput капитал/sizing/cooldown, Alert для Real mode, confirm-диалог
- `SessionDashboard.tsx`: маршрут `/trading/sessions/:id`, header с тикер/стратегия/режим/статус/P&L, Tabs Позиции|Сделки|Статистика, WS подписка на trades:{session_id}
- `PositionsTable.tsx`: Table с тикер/направление(▲/▼)/цена/P&L/время, кнопка «Закрыть»
- `TradesTable.tsx`: Table с дата/направление/вход/выход/P&L/P&L%/комиссия/slippage, пагинация «Загрузить ещё»
- `PnLSummary.tsx`: MetricCard (P&L, Win Rate, сделки, Profit Factor) + Equity Curve (Lightweight Charts LineSeries)

**Задача 7 — Real-time графики (`CandlestickChart.tsx`)** — ОБНОВЛЁН
- WS streaming: подписка на канал `market:{ticker}:{tf}`, real-time update свечей через chart.update()
- Маркеры сделок: ▲ зелёный (long) / ▼ красный (short) при получении trade.filled
- Индикатор подключения: кружок в правом верхнем углу (зелёный = connected, красный = disconnected)
- Props: wsChannel, sessionId — опциональные для обратной совместимости

**Задача 8 — Навигация**
- `App.tsx`: Route `/trading` → TradingPage, Route `/trading/sessions/:id` → SessionDashboard
- `Sidebar.tsx`: пункт «Торговля» (IconTrendingUp) уже присутствовал

**Тесты — 36 тестов в 7 файлах**
- SessionCard.test.tsx: 7 тестов (PAPER/REAL badge, P&L цвета, кнопки pause/resume)
- LaunchSessionModal.test.tsx: 5 тестов (рендер, Paper/Real switch, Real warning)
- PositionsTable.test.tsx: 4 теста (пустое состояние, строки, close callback)
- TradesTable.test.tsx: 4 теста (пустое состояние, строки, load more)
- PnLSummary.test.tsx: 4 теста (null stats, metric cards, total trades, win rate)
- TradingPage.test.tsx: 4 теста (заголовок, кнопка, empty state, fetchSessions)
- tradingStore.test.ts: 8 тестов (initial, fetchSessions, fetchSession, startSession, WS updates, clearError, dashboard)
- Все 36 тестов DEV-4 проходят (0 failures)

### DEV-5: Account Screen + Favorites Panel (Волна 3)

**Задача 1 — TypeScript типы (`src/api/types.ts`)** — ДОБАВЛЕНЫ
- BrokerBalance, BrokerPosition, BrokerOperation (Account)
- TaxReport, TaxReportRequest (Tax)
- FavoriteInstrument (Favorites)
- Существующие типы DEV-4 (Trading) сохранены без изменений

**Задача 2 — Account API (`src/api/accountApi.ts`)** — СОЗДАН
- getBalances, getPositions(accountId), getOperations(accountId, params)

**Задача 3 — Tax API (`src/api/taxApi.ts`)** — СОЗДАН
- generateReport(data), getReports(), downloadReport(id) с responseType: 'blob'

**Задача 4 — Account Store (`src/stores/accountStore.ts`)** — СОЗДАН
- Zustand store: balances, positions, operations, operationsTotal, taxReports
- Actions: fetchBalances, fetchPositions, fetchOperations, fetchTaxReports, generateTaxReport, downloadTaxReport
- downloadTaxReport: создаёт Blob → скачивание через link.click()

**Задача 5 — AccountPage (`src/pages/AccountPage.tsx`)** — СОЗДАН
- Маршрут `/account`: заголовок «Счёт» + кнопка «Налоговый отчёт»
- 3 секции: BalanceCards, PositionsTable (Paper), OperationsTable (Paper)
- Интеграция с settingsStore для activeAccountId
- Состояния: loading, error, пагинация операций, фильтр по датам

**Задача 6 — Account Components (`src/components/account/`)** — СОЗДАНЫ
- `BalanceCards.tsx`: SimpleGrid cols={3}, Paper карточки (Всего/Доступно/Заблокировано), P&L-цвета
- `PositionsTable.tsx`: TanStack Table с сортировкой, Badge «Стратегия» (blue) / «Внешняя» (gray), пустое состояние
- `OperationsTable.tsx`: DatePickerInput type="range", пагинация Pagination, локализованные типы операций
- `TaxReportModal.tsx`: Modal с Select (год), Radio (xlsx/csv), Checkbox (акции/облигации/ETF), loading state

**Задача 7 — FavoritesPanel (`src/components/charts/FavoritesPanel.tsx`)** — СОЗДАН
- Панель 220px справа от графика с toggle по кнопке ★
- localStorage для хранения (key: 'user_favorites')
- Добавление через TextInput + Enter, удаление по hover → ✕
- Каждый элемент: тикер (bold), статистика «N бэкт · M стр», P&L с цветом
- Клик → onSelectTicker → navigate

**Задача 8 — Навигация**
- `App.tsx`: Route `/account` → AccountPage (добавлен рядом с существующими)
- `Sidebar.tsx`: пункт «Счёт» (IconWallet) уже присутствовал
- `ChartPage.tsx`: интеграция FavoritesPanel (Flex layout, ActionIcon ★ toggle)

**Тесты — 24 теста в 7 файлах**
- BalanceCards.test.tsx: 3 теста (рендер карточек, форматирование, пустой массив)
- PositionsTable.test.tsx: 3 теста (рендер, badges, пустое состояние)
- OperationsTable.test.tsx: 3 теста (рендер, типы операций, date picker)
- TaxReportModal.test.tsx: 2 теста (форма, submit с данными)
- FavoritesPanel.test.tsx: 4 теста (пустое состояние, добавление, клик, localStorage)
- AccountPage.test.tsx: 4 теста (рендер, балансы, кнопка отчёта, error state)
- accountStore.test.ts: 5 тестов (initial, fetchBalances, fetchPositions, fetchOperations, fetchTaxReports)
- Все 24 теста DEV-5 проходят, существующие тесты (ChartPage, Sidebar) не сломаны

### ARCH: Архитектурное ревью + E2E тесты (Волна 4)

**Исправление CRIT-1 — Двойной prefix в Trading Router**
- `app/trading/router.py`: убран `prefix="/api/v1/trading"` из APIRouter (дублировался с main.py)
- Routes в production были бы `/api/v1/trading/api/v1/trading/sessions` (недоступны)
- Тесты маскировали баг: fixture добавляла router отдельно

**Исправление CRIT-2 — JWT авторизация на Trading endpoints**
- `app/trading/router.py`: добавлен `current_user: User = Depends(get_current_user)` ко всем 12 endpoints
- `tests/test_trading/test_router.py`: обновлен fixture с override_get_current_user
- Итого: 548 passed, 0 failed

**E2E тесты (4 сценария, 19 тестов)**
- `e2e/s5-paper-trading.spec.ts` (3 теста): запуск Paper-сессии, детали, pause/resume
- `e2e/s5-circuit-breaker.spec.ts` (5 тестов): CB config, events API, status, update, UI
- `e2e/s5-account.spec.ts` (4 теста): balance cards, formatting, tax modal, download
- `e2e/s5-favorites.spec.ts` (7 тестов): add, remove, multiple, persist, click, duplicate

**Архитектурное ревью**
- `arch_review_s5.md`: статус PASS WITH NOTES
- 2 critical (исправлены), 5 medium (документированы), 4 low (документированы)
- Все модули проверены: Trading Engine, Circuit Breaker, Bond Service, Tax Export, Corporate Actions, Broker Adapter, Security, Frontend UI

---

### Замечание 25: Раздел «Счёт» — реальные брокерские счета T-Invest (backend)

**Файлы:**
- `Develop/backend/app/broker/schemas.py` — `BrokerAccountCreate` без `name`, добавлено `selected_account_ids: list[str]`; новая модель `BrokerBalance` (account_id, account_name, is_sandbox, total, available, blocked, currency).
- `Develop/backend/app/broker/service.py` — `BrokerService.create_account` теперь возвращает `list[BrokerAccount]`: подключается к T-Invest через `BrokerFactory.create` + `adapter.get_accounts()`, фильтрует по `selected_account_ids` (если задан), создаёт отдельную запись на каждый счёт T-Invest с реальными `account_id`/`account_type`/`name`. Идемпотентность по `(user_id, broker_type, account_id)` — дубликаты пропускаются.
- `Develop/backend/app/broker/router.py` — `POST /api/v1/broker-accounts` возвращает `list[BrokerAccountResponse]`. `GET /api/v1/broker/accounts/balances` переписан с нуля: расшифровывает ключ, создаёт адаптер, дёргает `adapter.get_balance(acc.account_id)` для каждого активного аккаунта с заполненным `account_id`; ошибки по одному счёту НЕ валят endpoint (логируются, возвращается `total=0/available=0`). Убрано обращение к мёртвому полю `BrokerAccount.balance`.
- `Develop/backend/tests/unit/test_broker/test_broker_service.py` — **новый файл**, 3 unit-теста: создание на все счета, фильтрация по `selected_account_ids`, идемпотентность повторного вызова.
- `Develop/backend/tests/unit/test_broker/test_broker_router.py` — обновлены фикстуры (mock `detect_trading_rights` + `BrokerFactory.create` с двумя счетами), обновлены все существующие тесты под новый формат ответа (массив). Добавлен класс `TestBalances`: проверка реальных данных из адаптера + graceful-fallback при падении `get_balance`.

**Причина:**
- Запись `BrokerAccount` соответствовала одному API-ключу, а не реальному счёту T-Invest. Поле `account_id` никогда не заполнялось, поэтому `/positions`, `/operations` и `/balances` не могли работать по конкретному счёту. У одного ключа может быть несколько счетов (брокерский, ИИС) — нужно различать их в БД.
- Endpoint `/balances` читал несуществующее поле `BrokerAccount.balance` через `hasattr`, который всегда False → всегда возвращал 0 RUB.

**Решение:**
- Двухфазный флоу для фронта: (1) `POST /api/v1/broker-accounts/discover` → пользователь видит список счетов и выбирает; (2) `POST /api/v1/broker-accounts` с `selected_account_ids` → backend создаёт отдельную запись на каждый выбранный счёт. Бэкап: если `selected_account_ids` пуст — создаются записи на все найденные счета.
- Балансы в реальном времени: backend расшифровывает ключ, подключает адаптер, вызывает `get_balance(account_id)`, формирует `BrokerBalance`. Sandbox работает через `client.sandbox.get_sandbox_portfolio` (уже в адаптере).

**Тесты:**
- Новые: 3 теста `test_broker_service.py` + 2 теста `TestBalances` + 3 обновлённых теста `TestCreateAccount` → всего 8 новых/переработанных.
- Запуск: `pytest tests/unit/test_broker/ -x -v` → **35 passed, 0 failed** (все, включая существующие тесты mapper/factory/base_adapter/rate_limiter).
- ruff: `ruff check app/broker/schemas.py app/broker/service.py app/broker/router.py` → All checks passed.
- mypy: в изменённых файлах ошибок нет; существующие 16 ошибок в `config.py`/`middleware/auth.py`/`broker/tinvest/adapter.py`/`broker/factory.py` не связаны с изменениями.

**Перенос в Sprint 6:**
- Реальные `/positions` и `/operations` остались заглушками (`return []` и `return {"items": [], "total": 0}`) — перенесены в Sprint 6, файл `Спринты/Sprint_6/PENDING_S6_real_account_positions_operations.md`.

**Контракт API для frontend-агента:**
- `POST /api/v1/broker-accounts`: запрос `{ broker_type, api_key, api_secret?, selected_account_ids: string[] }`, ответ `BrokerAccountResponse[]` (по одной записи на каждый выбранный T-Invest счёт).
- `GET /api/v1/broker/accounts/balances`: ответ `BrokerBalance[]` — поля `account_id` (id записи в БД), `account_name`, `is_sandbox`, `total`, `available`, `blocked`, `currency`.

---

## 2026-04-09 — Замечание 25: Раздел «Счёт» — реальные брокерские счета T-Invest (frontend)

**Файлы:**
- `Develop/frontend/src/api/types.ts` — в `BrokerBalance` добавлено поле `is_sandbox: boolean` (синхронизация с новым контрактом backend).
- `Develop/frontend/src/api/brokerApi.ts` — `BrokerAccountCreate` переработан: убрано `name`, добавлено `selected_account_ids: string[]`; `createAccount` возвращает `BrokerAccountResponse[]` (массив).
- `Develop/frontend/src/stores/settingsStore.ts` — `addAccount` принимает новую сигнатуру, обрабатывает массив ответа (добавляет все созданные записи в стор), пересчитывает `hasBrokerConnection`/`hasSandboxAccounts`, возвращает созданные записи наружу.
- `Develop/frontend/src/components/settings/AddBrokerForm.tsx` — удалено поле «Название аккаунта»; кнопка «Сохранить» заблокирована, пока пользователь не нажал «Обнаружить счета» и не выбрал хотя бы один счёт; при сохранении отправляется `selected_account_ids`; toast-уведомление «Подключены счета: …» (имена из T-Invest через запятую).
- `Develop/frontend/src/pages/AccountPage.tsx` — добавлен Mantine `Select` для выбора брокерского счёта (опции: `name [Sandbox]`); балансы фильтруются на фронте по `account_id` выбранного счёта; под заголовком подсказка «Сводка по реальным брокерским счетам. Paper-сессии отображаются в разделе „Торговля“.»; пустое состояние с иконкой, текстом «Реальные брокерские счета не подключены. Добавьте API-ключ T-Invest в Настройках → Брокеры.» и кнопкой «Перейти в настройки» (navigate `/settings`); выбранный счёт вычисляется через `useMemo` (эффективный id = ручной выбор пользователя или первый доступный), без `setState` в эффекте.
- `Develop/frontend/src/components/settings/__tests__/AddBrokerForm.test.tsx` — удалён кейс с полем «Название аккаунта», добавлен кейс «save button is disabled until accounts are discovered».
- `Develop/frontend/src/stores/__tests__/settingsStore.test.ts` — мок `createAccount` возвращает массив (`[BrokerAccountResponse]`) с новыми полями `is_sandbox`, `has_trading_rights`.
- `Develop/frontend/src/components/account/__tests__/BalanceCards.test.tsx` — в mock `BrokerBalance` добавлено `is_sandbox: false`.
- `Develop/frontend/src/pages/__tests__/AccountPage.test.tsx` — добавлены поля `is_sandbox`/`has_trading_rights` в моках; добавлены кейсы «shows account selector» и «shows empty state when no broker accounts connected»; error-тест поднимает brokerAccount, чтобы рендерился error-блок, а не empty state.

**Причина:**
Ранее форма добавления брокера сохраняла произвольное имя и не использовала результат discover — в БД создавалась одна запись с `account_id = NULL`, поэтому раздел «Счёт» и `LaunchSessionModal` показывали это произвольное имя вместо реальных T-Invest счетов (брокерский/ИИС/Sandbox).

**Решение:**
Frontend полностью перешёл на новый контракт API от backend-агента (`selected_account_ids` + массив в ответе). Имена счетов берутся напрямую из T-Invest при discover, а «Счёт» теперь показывает только реальные брокерские счета с селектором по каждому аккаунту. Пустое состояние уводит пользователя в настройки для подключения ключа.

**Тесты:** passed
- `npx tsc --noEmit` — 0 ошибок.
- `npx eslint` по затронутым файлам — 0 ошибок (исправлена ошибка `react-hooks/set-state-in-effect` через `useMemo`-вычисление эффективного `selectedAccountId` вместо `setState` в effect).
- `npx vitest run` по затронутым файлам: **26/26 passed** (AddBrokerForm 5, AccountPage 6, settingsStore 3, accountStore 5, BalanceCards 3, BrokerAccountList 4).
- Полный прогон `vitest run` показывает 22 фейла в несвязанных файлах (LaunchSessionModal, AIChat, AISettingsPage, BacktestProgress, flatBlocksToWorkspace, authStore, aiChatStore, FavoritesPanel, StrategyEditPage, BacktestResultsPage) — все они **pre-existing** (не зависят от затронутых файлов, специфика их моков и тест-сетапов).

**Инструкция для пользователя (что увидит после совместных правок с backend-агентом):**
1. В разделе «Настройки → Брокеры» удалить старый аккаунт T-Invest (у которого `account_id = NULL`).
2. Нажать «+ Добавить брокера», выбрать «T-Invest», ввести API-ключ, нажать «Обнаружить счета» — увидеть список реальных счетов (брокерский, ИИС, Sandbox) с галочками и бейджем `sandbox`.
3. Снять/поставить галочки, нажать «Сохранить» (кнопка активна только после discover). Toast: «Подключены счета: Брокерский счёт, ИИС».
4. В разделе «Счёт» сверху появится `Select` «Брокерский счёт» с опциями `Брокерский счёт`, `ИИС`, `Sandbox Account [Sandbox]`. При переключении — карточки «Всего/Доступно/Заблокировано» показывают баланс только выбранного счёта.
5. Если нет ни одного реального счёта — на странице «Счёт» вместо таблиц показывается пустое состояние с кнопкой «Перейти в настройки».

---

## 2026-04-10 — Замечание 41: «Применить на схеме» — entry/exit/management блоки не отображались (Decimal → строка → крах FieldNumber)

**Файлы:**
- `Develop/backend/app/strategy/block_parser.py` — все числовые значения, возвращаемые парсером шаблона, изменены с `Decimal` на `float` (для целых — `int`):
  - `_parse_atomic_condition` → `THRESHOLD` сравнения с числом (`[I3] > 70` → `right=70.0`)
  - `_parse_atomic_condition` → `condition_in_zone.low/high` (`в зоне 30–70` → `30.0/70.0`)
  - `_parse_stop_loss`, `_parse_take_profit`, `_parse_position_sizing` → поля `params.percent`, `params.points`, `params.lots`
- `Develop/frontend/src/utils/flatBlocksToWorkspace.ts` — добавлена утилита `toNum(value, fallback)` с явным приведением к числу через `Number()`. Применена ко всем числовым полям в `buildIndicatorBlock` (PERIOD, FAST, SLOW, SIGNAL, STD_DEV, K_PERIOD, D_PERIOD), `buildConditionBlock` (THRESHOLD, MIN/MAX), `buildManagementBlock` (VALUE), `buildFilterBlock` (START_HOUR/MIN, END_HOUR/MIN). Раньше эти значения подставлялись в Blockly state как-есть — для строки `"50"` это вызывало тихое падение `FieldNumber.fromJson` в Blockly при загрузке, и связанные с ним блоки просто не отображались на схеме (entry_signal / exit_signal содержали в иерархии condition_compare с битым THRESHOLD → вся подцепочка отбрасывалась).

**Причина:**
Заказчик нажимал «Применить на схеме» — на схеме появлялись только индикатор и position_size, а блоки сигналов входа и выхода не появлялись.

Корень: `TemplateParser` в backend хранил все числовые поля как `Decimal` (точные финансовые числа). При сериализации Pydantic v2 в JSON `Decimal` всегда превращается в **строку** (`Decimal('50')` → `"50"`). На фронте `flatBlocksToWorkspace` подставлял эти строки прямо в Blockly state (`fields.THRESHOLD = "50"`, `fields.VALUE = "50"`). Blockly `FieldNumber` ожидает число — на строку реагирует тихим падением (`TypeError: undefined is not an object`, видно в консоли пользователя как `evaluating 'a'` из минифицированного билда). При падении на одном вложенном блоке Blockly отбрасывает весь его родительский блок — поэтому сигналы входа/выхода (содержавшие condition_compare с битым THRESHOLD) не попадали на схему.

**Решение:**
Двусторонний фикс:
1. **Backend** — все числовые значения парсера теперь сразу `float`/`int`, а не `Decimal`. JSON-сериализация выдаёт настоящие числа.
2. **Frontend** — `toNum(value, fallback)` принимает любое значение и возвращает число (`Number(value)` с фолбеком на дефолт). Это страховка на случай старых сохранённых блоков и любых будущих регрессий.

**Тесты:**
- Прямой запуск парсера на тестовом шаблоне: все числовые поля теперь `float` (`50.0` вместо `"50"`).
- `npx tsc --noEmit` — 0 ошибок.
- Backend перезапущен, Application startup complete.

---

## 2026-04-10 — Замечание 40: Перезапуск бэктеста — UI «зависал» на 100% Загрузка

**Файлы:**
- `Develop/frontend/src/stores/backtestStore.ts` — добавлен метод `rerunBacktest(oldId)`. Сбрасывает локальное состояние стора (`isRunning=true`, `progress=0`, `currentDate=''`, `currentBacktest=null`), вызывает `backtestApi.rerun(oldId)` и **обязательно** подписывается на прогресс нового бэктеста через `subscribeProgress(newId)`. Возвращает `newId`.
- `Develop/frontend/src/pages/BacktestListPage.tsx` — `handleRerun` теперь использует `rerunBacktest` из стора вместо прямого `backtestApi.rerun`.
- `Develop/frontend/src/pages/StrategyEditPage.tsx` — кнопка «Перезапустить» в таблице бэктестов стратегии теперь идёт через `useBacktestStore.getState().rerunBacktest`. Добавлен импорт `useBacktestStore`.
- `Develop/frontend/src/pages/BacktestResultsPage.tsx` — добавлен «страховочный» `useEffect`: если страница показывает running-бэктест, но `isRunning === false` в сторе (например, открыли URL напрямую или после refresh) — создаётся подписка через `subscribeProgress(backtestId)`. Без этого UI «зависал» в состоянии 100% / Загрузка.

**Причина:**
В замечании 39 я сделал перезапуск через прямой `backtestApi.rerun` + `navigate('/backtests/NEW')`. Но никто не подписывался на WebSocket / polling нового бэктеста: `launchBacktest` (где есть `subscribeProgress`) при rerun не вызывался. В результате:
1. Страница `/backtests/NEW` загружала бэктест → видела `status='running'` → показывала `BacktestProgress`.
2. `BacktestProgress` рендерил `progress=0 && !currentDate` → визуально «100% — Загрузка рыночных данных…» (см. `BacktestProgress.tsx:79-89`).
3. WebSocket/polling не подключены → обновления нет.
4. Бэктест на бэкенде завершался, но фронтенд об этом не узнавал — UI зависал.
5. В списке `/backtests` бэктест отображался как `completed`, потому что `BacktestListPage` делает свежий fetch. При клике пользователь снова попадал на «зависший» прогресс-экран — у того же `id`.

**Решение:**
1. Метод `rerunBacktest` в сторе делает всё то же, что `launchBacktest`: сбрасывает состояние, вызывает API, **подписывается на прогресс**.
2. На странице результатов добавлен страховочный effect — если открыли running-бэктест без подписки, она создаётся автоматически.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.

---

## 2026-04-10 — Замечание 39: Перезапуск бэктеста с текущей версией стратегии

**Файлы:**
- `Develop/backend/app/backtest/router.py` — добавлен endpoint `POST /api/v1/backtest/{id}/rerun`. Логика: загружает старый бэктест → находит стратегию → берёт её `current_version_id` → валидирует код этой версии → создаёт **новую запись `Backtest`** с теми же параметрами (ticker, timeframe, dates, capital, commission, slippage, params_json), но с актуальным `strategy_version_id` → запускает background task `_run_backtest_task`. Старый бэктест НЕ удаляется (остаётся в истории). Возвращает `{ backtest_id, status: 'running' }`.
- `Develop/frontend/src/api/backtestApi.ts` — добавлен метод `backtestApi.rerun(id)`.
- `Develop/frontend/src/pages/BacktestListPage.tsx` — рядом с кнопкой «Удалить» добавлена кнопка «Перезапустить» (`IconRefresh`, синяя, в `Tooltip`). По клику дёргает `rerun` и навигирует на новый бэктест (`/backtests/{new_id}`), чтобы пользователь сразу видел прогресс.
- `Develop/frontend/src/pages/StrategyEditPage.tsx` — в таблице «Бэктесты стратегии» (вкладка «Содержание») — то же самое: кнопка «Перезапустить» рядом с «Удалить», импорт `IconRefresh` и `Tooltip`. Колонка действий расширена с `w={30}` до `w={60}`.

**Причина:**
Заказчик попросил кнопку перезапуска бэктеста с теми же настройками, но с учётом изменений в стратегии — чтобы можно было быстро прогнать ту же конфигурацию (тикер/период/капитал/комиссия) после правки блочной схемы.

**Решение:**
Перезапуск делается через **отдельный endpoint** на бэкенде, чтобы не тащить кучу полей с фронта и не дублировать логику валидации. Подмена `strategy_version_id` на `current_version_id` стратегии — ключевой момент: новый бэктест запускается на самой свежей версии, а не на той, на которой был исходный. Старый бэктест сохраняется в истории — это позволяет потом сравнить старую и новую версии.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.
- `ruff check app/backtest/router.py` — без новых ошибок (5 pre-existing неиспользуемых импортов в файле — не от моих правок).
- Backend перезапущен, Application startup complete.

---

## 2026-04-10 — Замечание 38: Возврат из бэктеста в стратегию открывает вкладку «Содержание»

**Файлы:**
- `Develop/frontend/src/pages/StrategyEditPage.tsx` — `Tabs` стал управляемым (`value`/`onChange`). Активная вкладка читается из query-параметра `?tab=description` при первом рендере, если параметра нет — по умолчанию открывается «Редактор» (как было). После переключения вкладки query-параметр удаляется через `setSearchParams(..., {replace: true})`, чтобы навигация не залипала.
- `Develop/frontend/src/pages/BacktestResultsPage.tsx` — обе навигации обратно к стратегии (кнопка «← К стратегии» и breadcrumb «{strategy_name}») теперь добавляют `?tab=description` к URL.

**Причина:**
Заказчик попросил, чтобы при возврате со страницы результатов бэктеста в стратегию открывалась вкладка «Содержание», а не «Редактор» (чтобы пользователь сразу видел описание стратегии и список её бэктестов, а не Blockly-холст).

**Решение:**
Параметр `?tab=description` в URL — простой и переиспользуемый механизм. По умолчанию страница стратегии по-прежнему открывается в «Редакторе» (например, при клике по названию стратегии в дашборде), но конкретные точки входа могут запросить «Содержание» через query-параметр.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.

---

## 2026-04-10 — Замечание 37: На странице бэктеста — кнопка «К стратегии» и кликабельный breadcrumb

**Файлы:**
- `Develop/backend/app/backtest/router.py` — `_build_backtest_response` теперь возвращает `strategy_id` (раньше его не было в ответе, хотя в TS-типе `Backtest.strategy_id` был объявлен — фронт получал undefined). В SELECT-join добавлен `Strategy.id`.
- `Develop/frontend/src/pages/BacktestResultsPage.tsx` — в шапку добавлена кнопка «← К стратегии» (`IconArrowLeft`, `variant="subtle"`), которая навигирует на `/strategies/{bt.strategy_id}`. Если по какой-то причине `strategy_id` пуст — fallback на `navigate(-1)`. Также breadcrumb «{strategy_name}» теперь кликабельный (`<Anchor>` → `/strategies/{id}`).

**Причина:**
Заказчик попросил предусмотреть команду «назад», чтобы со страницы результатов бэктеста можно было вернуться в окно стратегии, из которой бэктест был запущен.

**Решение:**
Кнопка «← К стратегии» — самый явный путь, всегда видна в шапке слева от заголовка. Дополнительно сделан кликабельным breadcrumb с именем стратегии. Backend-фикс был обязательным: ответ `/api/v1/backtest/{id}` не содержал `strategy_id`, хотя TS-тип его уже декларировал.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.
- Backend перезапущен, Application startup complete.

---

## 2026-04-10 — Замечание 36: BacktestLaunchModal — старая ошибка показывалась при повторном открытии

**Файлы:**
- `Develop/frontend/src/components/backtest/BacktestLaunchModal.tsx` — при открытии модалки вызываются `clearError()` из `useBacktestStore` и `setErrors({})` для локальных ошибок валидации.

**Причина:**
После замечания 35 я починил backend, но пользователь увидел старую ошибку `__import__ not found` сразу при открытии модалки запуска бэктеста — даже до нажатия кнопки. Корень: `useBacktestStore` хранит поле `error` после неудачной попытки запуска (Zustand persist между навигациями), и `BacktestLaunchModal` рендерит этот `error` в `Alert`. При закрытии и повторном открытии модалки `error` оставался — и пользователю казалось, что ошибка возникает заново.

**Решение:**
В `useEffect`, который срабатывает при открытии модалки (`opened === true`), теперь дополнительно вызываются `clearError()` (чистит `error` в store) и `setErrors({})` (чистит локальные ошибки валидации). Это гарантирует, что модалка всегда открывается в чистом состоянии.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.

---

## 2026-04-10 — Замечание 35: Бэктест продолжал падать на старых версиях стратегий — добавлен safe `__import__`

**Файлы:**
- `Develop/backend/app/backtest/engine.py` — в `_compile_strategy` добавлен whitelist-`__import__`. Разрешает `import backtrader`, `import datetime`, `import math`, `import decimal` — все эти модули уже подгружены в процесс backend, поэтому импорт просто возвращает существующий объект, а не делает реальный disk I/O. Любой другой импорт по-прежнему падает с `ImportError`.

**Причина:**
В замечании 33 я убрал `import` из генерируемого кода, но **сохранённые в БД старые версии стратегий** (включая текущую версию «Тестовая», в которой 78 версий) продолжают содержать `import backtrader as bt` в поле `generated_code`. Чтобы их перегенерировать, пользователь должен открыть стратегию в редакторе и нажать «Сгенерировать код» — это сложный путь для каждой версии. Перегенерация со стороны backend невозможна, потому что blocks_json в БД хранится в формате Blockly serialization, а конвертация в плоский формат для CodeGenerator делается на фронтенде через `jsonGenerator.blockToCode`.

**Решение:**
Добавить в namespace стратегии безопасный `__import__`, разрешающий только белый список модулей. Это даёт обратную совместимость со старыми версиями (их `import backtrader as bt` теперь работает) и сохраняет безопасность (любой `import os` / `import subprocess` / etc. продолжает падать с ImportError).

Whitelist:
- `backtrader` → объект `bt`, уже импортированный в backend
- `datetime`, `math`, `decimal` → стандартные модули, уже в namespace

Это паттерн из `app/sandbox/executor.py` (`_safe_import`), просто перенесён в backtest engine.

**Тесты:**
- Backend перезапущен, Application startup complete.

---

## 2026-04-10 — Замечание 34: История последних инструментов в формах запуска бэктеста и торговой сессии

**Файлы:**
- `Develop/frontend/src/utils/recentInstruments.ts` — новый общий модуль с функциями `getRecentInstruments()` / `addRecentInstrument(ticker)`. Хранит до 5 последних тикеров в `localStorage` под единым ключом `recentInstruments`. Один список на всё приложение, с дедупликацией и нормализацией к верхнему регистру.
- `Develop/frontend/src/components/layout/Header.tsx` — локальные функции `getRecentInstruments` / `addRecentInstrument` удалены, импортируются из общего модуля. Логика глобального поиска не меняется.
- `Develop/frontend/src/components/backtest/BacktestLaunchModal.tsx` — при открытии модалки и при пустом вводе `Autocomplete` показывает недавние инструменты как подсказки. После успешного запуска бэктеста выбранный тикер записывается в историю через `addRecentInstrument`.
- `Develop/frontend/src/components/trading/LaunchSessionModal.tsx` — аналогичная логика: подсказки при открытии и пустом вводе, запись в историю после успешного запуска торговой сессии.

**Причина:**
Заказчик попросил подтянуть в форму запуска бэктеста ту же историю последних 5 инструментов, что используется в глобальном поиске в шапке. Сделал заодно и для модалки запуска торговой сессии — там тот же UX.

**Решение:**
История уже существовала в `Header.tsx` (хранилась в `localStorage` под ключом `recentInstruments`), но утилиты были private. Вынес их в `utils/recentInstruments.ts` как единый источник истины. Глобальный список — все три места (поиск в шапке, модалка бэктеста, модалка торговой сессии) делят одну историю: запустил бэктест на SBER → сразу видишь SBER в подсказках при следующем поиске или запуске сессии.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.

---

## 2026-04-10 — Замечание 33: Бэктест падает с `__import__ not found`

**Файлы:**
- `Develop/backend/app/strategy/code_generator.py` — из сгенерированного кода удалены строки `import backtrader as bt` и `import datetime` (включая `_empty_strategy()`).
- `Develop/backend/app/backtest/engine.py` — в namespace `_compile_strategy` добавлен `'datetime': datetime`.

**Причина:**
При запуске бэктеста стратегии «Тестовая» (SBER, 1h, 6 месяцев) в UI приходила ошибка `__import__ not found`. Корень: `_compile_strategy` в [backtest/engine.py:432-447](Develop/backend/app/backtest/engine.py#L432-L447) специально вырезает `__import__` из safe_builtins (в целях безопасности — sandbox), а сгенерированный CodeGenerator код начинался с `import backtrader as bt`. Любой `import` в Python вызывает `__builtins__.__import__`, которого в namespace нет → ImportError.

**Решение:**
Импорты в сгенерированный код больше не добавляются. `bt`, `math`, `Decimal`, `datetime` подставляются напрямую в namespace в `_compile_strategy` — генерируемый код использует их как глобальные имена без `import`. Это согласуется с архитектурой sandbox: код исполняется в подготовленном namespace, а не в обычном Python-окружении.

**Что нужно сделать пользователю:**
Старые версии стратегий (включая текущую версию «Тестовая» в БД) содержат `import backtrader as bt` в сохранённом `generated_code` и **продолжат падать**. Чтобы их починить, нужно открыть стратегию в редакторе и нажать «Сгенерировать код» (или «Сохранить», если кнопка перегенерирует автоматически) — фронтенд отправит блоки в `/generate-code`, и в БД сохранится новый код без `import`.

**Тесты:**
- Backend перезапущен, Application startup complete.
- TS-сборка не затронута.

**Известные побочные проблемы (на скриншоте), не входят в это замечание:**
- `<button> cannot contain a nested <button>` в `FavoritesPanel` после добавления `TickerLogo` — нужно отдельно поправить (заменить наружний UnstyledButton на div + onClick).
- 403 на `https://invest-brands.cdn-tinkoff.ru/<ISIN>x160.png` для нескольких ISIN — у некоторых тикеров CDN T-Invest действительно отсутствует, нужен fallback.
- `BlocklyWorkspace Load error: TypeError: undefined is not an object (evaluating 'a')` — нужно отдельно отлаживать.

---

## 2026-04-10 — Замечание 32: TickerLogo на странице графика, в избранном и в поиске инструментов

**Файлы:**
- `Develop/frontend/src/components/charts/CandlestickChart.tsx` — в overlay-блок графика (`ChartOverlay`) добавлен `<TickerLogo ticker={info.ticker} size={20} />` слева от тикера. Видно в верхнем-левом углу графика рядом с названием инструмента.
- `Develop/frontend/src/components/charts/FavoritesPanel.tsx` — в карточку каждого избранного тикера добавлен `<TickerLogo size={20} />` слева от названия. Используется в правой панели страницы графика.
- `Develop/frontend/src/components/layout/Header.tsx` — глобальный поиск инструментов в шапке: локальный `getTickerIcon` (буквенный fallback) полностью удалён, `renderOption` теперь использует `<TickerLogo size={24} />`. При вводе тикера в поиск выпадающий список сразу показывает реальные логотипы.
- `Develop/frontend/src/components/backtest/BacktestLaunchModal.tsx` — в `Autocomplete` инструмента добавлен `renderOption` с `<TickerLogo size={20} />` для каждой подсказки.
- `Develop/frontend/src/components/trading/LaunchSessionModal.tsx` — аналогично, `renderOption` с `<TickerLogo size={20} />` в подсказках тикера при запуске торговой сессии.

**Причина:**
В замечании 31 был сделан компонент `TickerLogo` (T-Invest CDN, кеш на бэке + модульный кеш на фронте), но использовался только в дашборде «Стратегии». Заказчик попросил вывести реальные логотипы во всех местах, где упоминается финансовый инструмент: страница графика, окошко избранного, поиск в шапке, выпадающие подсказки тикера в формах запуска бэктеста и торговой сессии.

**Решение:**
Подключил единый компонент `<TickerLogo>` во все 5 точек. Кеш в `instruments.logo_name` и in-flight-дедупликация на фронте автоматически предотвращают лишние запросы — повторное появление того же тикера не дёргает API. Для тикеров, которые ещё не закешированы, делается один HTTP-запрос → backend идёт в T-Invest `find_instrument`, кладёт ISIN в БД → следующие фронтенд-вызовы мгновенные.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.

---

## 2026-04-09 — Замечание 31: Логотипы T-Invest — переход на ISIN-схему

**Файлы:**
- `Develop/backend/app/market_data/service.py` — метод `get_or_fetch_logo_name` переименован в `get_or_fetch_logo_isin`. Внутренний `_fetch_logo_name_from_tinvest` → `_fetch_isin_from_tinvest`. Логика драматически упростилась: вместо `share_by/bond_by/etf_by` теперь только `find_instrument(query=ticker)` → берётся точное совпадение по тикеру → возвращается поле `isin`. Поле `Instrument.logo_name` в БД фактически хранит ISIN (схема не меняется).
- `Develop/backend/app/market_data/router.py` — endpoint `/instruments/{ticker}/logo` теперь формирует URL как `https://invest-brands.cdn-tinkoff.ru/<ISIN>x160.png`.
- `Develop/frontend/e2e/s5-ticker-logos.spec.ts` — новый E2E-тест: проверяет, что при раскрытии «Тестовая» приходят ответы `/logo` с реальным URL и CDN T-Invest отдаёт 200.

**Причина:**
В замечании 30 я перешёл на `find_instrument` + getter с FIGI. Это нашло инструмент, но `share_by` НЕ возвращает поле `brand` в текущей версии Python SDK T-Invest (`tinkoff-investments`) — отдельная попытка через `get_brand_by` тоже падает с `NOT_FOUND 50010`. Поле `instrument.brand.logo_name` в SDK недоступно.

**Решение:**
Логотипы T-Invest CDN на самом деле адресуются по **ISIN**, а не по `brand.logo_name`. Я экспериментально проверил три URL для SBER (ISIN `RU0009029540`):
- `https://invest-brands.cdn-tinkoff.ru/RU0009029540x160.png` → **200 OK**
- `https://static.tinkoff.ru/brands/traiding/RU0009029540x160.png` → 200 OK
- `https://static.tinkoff.ru/brands/traiding/RU0009029540x640.png` → 200 OK

ISIN T-Invest возвращает прямо в `find_instrument` (в объекте `InstrumentShort.isin`), без необходимости второго запроса `share_by`. Это **проще, быстрее и работает универсально** для всех инструментов (акции, облигации, ETF — у всех есть ISIN).

**Проверка:**
Запустил `MarketDataService.get_or_fetch_logo_isin("SBER"/"GAZP"/"LKOH")` напрямую через standalone Python:
```
SBER: ISIN='RU0009029540' URL=https://invest-brands.cdn-tinkoff.ru/RU0009029540x160.png  → 200
GAZP: ISIN='RU0007661625' URL=https://invest-brands.cdn-tinkoff.ru/RU0007661625x160.png  → 200
LKOH: ISIN='RU0009024277' URL=https://invest-brands.cdn-tinkoff.ru/RU0009024277x160.png  → 200
```
Все три ISIN'а закешированы в `instruments.logo_name`. Backend перезапущен, Application startup complete.

**Тесты:**
- Standalone smoke test через `MarketDataService.get_or_fetch_logo_isin` — passed для SBER/GAZP/LKOH.
- CDN HEAD-проверка — все три URL возвращают `HTTP/2 200`.
- Playwright E2E `s5-ticker-logos.spec.ts` создан, требует `E2E_PASSWORD` env-переменной для пользователя `sergopipo`.

---

## 2026-04-09 — Замечание 30: Логотипы T-Invest — поиск по FIGI вместо TICKER+TQBR

**Файлы:**
- `Develop/backend/app/market_data/service.py` — переписан `_fetch_logo_name_from_tinvest`. Теперь сначала вызывается `instruments.find_instrument(query=ticker)`, который возвращает список инструментов вместе с их `figi` и `instrument_type`. Затем по `instrument_type` (`share`/`bond`/`etf`/`currency`/`futures`) выбирается соответствующий getter (`share_by`/`bond_by`/`etf_by`/`currency_by`/`future_by`), который дёргается уже с `id_type=FIGI` (а не `TICKER`).

**Причина:**
В замечании 29 я использовал `share_by(id_type=TICKER, class_code="TQBR", id="SBER")`. По логам это не находило инструмент и возвращало `tinvest_logo_not_found`. Проблема: T-Invest требует точное совпадение `class_code` для поиска по тикеру, а у разных инструментов классы разные (`TQBR` для акций, `TQOB` для облигаций и т.п.). Перебор getters по очереди тоже не работал — каждый getter падал на «неподходящем» классе.

**Решение:**
`find_instrument(query=ticker)` ищет по всем типам и классам без знания этой специфики и возвращает FIGI (уникальный идентификатор инструмента) + тип. Поиск по FIGI работает универсально, без `class_code`. Берём первое точное совпадение по тикеру (если есть) — иначе первый результат.

**Тесты:**
- Backend перезапущен, Application startup complete.
- Проверка на пользователе: для SBER/LKOH ожидается `tinvest_logo_found` в логах.

---

## 2026-04-09 — Замечание 29: Реальные логотипы инструментов через T-Invest CDN

**Файлы:**
- `Develop/backend/app/market_data/models.py` — в модель `Instrument` добавлено поле `logo_name: str | None`. SQLite-колонка добавлена через `ALTER TABLE` (миграции у нас руками).
- `Develop/backend/app/market_data/service.py` — добавлены два метода:
  - `get_or_fetch_logo_name(ticker)` — кеш + ленивая подгрузка из T-Invest, апсертит запись `Instrument` с заполненным `logo_name`.
  - `_fetch_logo_name_from_tinvest(ticker)` — берёт первый активный production-токен T-Invest пользователя, перебирает `client.instruments.share_by/bond_by/etf_by/currency_by/future_by` (с `id_type=TICKER`, `class_code=TQBR`), достаёт `instrument.brand.logo_name`.
- `Develop/backend/app/market_data/router.py` — новый endpoint `GET /api/v1/market-data/instruments/{ticker}/logo`, возвращает `{ ticker, logo_url }`. URL формируется как `https://invest-brands.cdn-tinkoff.ru/<base>x160.png` (где `<base>` — `logo_name` без расширения `.png`). Если логотип не найден — `logo_url: null`.
- `Develop/frontend/src/api/marketDataApi.ts` — добавлен метод `getInstrumentLogo(ticker)`.
- `Develop/frontend/src/components/common/TickerLogo.tsx` — новый компонент `<TickerLogo ticker="SBER" size={24} />`. Подгружает логотип лениво с модульным кешем (`Map<ticker, url|null>`) и in-flight дедупликацией. Если ответ `null` или `<img>` упал на загрузке — fallback на буквенную плашку (стабильный цвет по char-code из палитры). Один компонент на всё приложение, чтобы потом использовать и в форме запуска бэктеста, и в графике, и в селекторе брокерского счёта.
- `Develop/frontend/src/pages/DashboardPage.tsx` — локальный `TickerIcon` удалён, тикеры в раскрывающихся строках теперь рендерятся через `<TickerLogo>`.

**Причина:**
В замечании 28 я сделал буквенный fallback, но пользователь попросил настоящие логотипы. Самый простой источник для российских инструментов — публичный T-Invest CDN, для которого нужно знать поле `instrument.brand.logo_name` из их `InstrumentsService` (бесплатный gRPC API).

**Решение:**
1. Backend лениво подтягивает `logo_name` через первый активный production-токен T-Invest пользователя и кеширует в нашей таблице `instruments` — повторные запросы уже не дёргают T-Invest. Sandbox-токены не используются (у них нет доступа к InstrumentsService по таким параметрам).
2. Frontend — единый компонент `TickerLogo` с двойным кешированием (модульный + в БД на бэкенде), in-flight дедупликацией, graceful fallback на буквенную плашку.
3. Для `<class_code>` используется `TQBR` (основной режим торгов акциями MOEX). Для облигаций T-Invest сам разрулит через `bond_by`.

**Что не работает:**
- Если у пользователя **нет ни одного активного production-токена T-Invest** — endpoint вернёт `logo_url: null`, везде будет fallback. Это нормально: у paper-only пользователя реальных логотипов не будет, но fallback выглядит аккуратно.
- Если T-Invest по тикеру не нашёл инструмент (например, иностранный) — тоже fallback.

**Тесты:**
- `ruff check app/market_data/service.py app/market_data/router.py app/market_data/models.py` — без новых ошибок.
- `npx tsc --noEmit` — 0 ошибок.
- Backend перезапущен, Application startup complete.

---

## 2026-04-09 — Замечание 28: Дашборд «Стратегии» — фикс роутов тикеров, белый цвет, иконка инструмента

**Файлы:**
- `Develop/frontend/src/pages/DashboardPage.tsx` — клик по тикеру вёл на несуществующий `/charts?ticker=X` (правильный роут — `/chart/:ticker`), клик по позиции — на `/trading/:id` (правильный — `/trading/sessions/:id`). Оба роута исправлены, 404 больше не возникает. Цвет ссылки тикера изменён с `blue.4` на `white` + `fw={600}`. Заменён `Avatar` на компонент `TickerIcon` — круглая 24×24 цветная плашка с первой буквой тикера, цвет стабильно вычисляется по char-code из палитры (стиль из `AppHeader.getTickerIcon`).
- БД: удалены все стратегии, кроме «Тестовая» (id=1), вместе с зависимыми `strategy_versions` и `backtests` (с каскадным удалением `backtest_trades`). Перед удалением сделан бэкап `data/terminal.db.backup_<ts>`.

**Причина:**
В замечании 27 я задал клики на несуществующие пути роутера — пользователь получал 404 при попытке перейти к графику или сессии. Также Avatar из Mantine давал низкоконтрастный цвет на тёмном фоне.

**Решение:**
Сверился с фактическими роутами в `App.tsx` (`chart/:ticker?`, `trading/sessions/:id`, `backtests/:id`) и поправил все навигации. Локальный компонент `TickerIcon` повторяет стиль из шапки приложения для единообразия.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.

---

## 2026-04-09 — Замечание 27: Дашборд «Стратегии» — возврат к исходному дизайну с раскрывающимися строками

**Файлы:**
- `Develop/backend/app/strategy/schemas.py` — добавлены модели `InstrumentBacktest`, `InstrumentPosition`, `StrategyInstrumentSummary`. В `StrategyResponse` добавлены поля `instruments`, `total_position_rub`, `total_abs_pnl`, `total_pct_pnl`.
- `Develop/backend/app/strategy/service.py` — `get_list` теперь сортирует по `created_at DESC` (раньше — по `updated_at`). Добавлен метод `get_instruments_summary(user_id, strategy_id)`: собирает уникальные тикеры из бэктестов и активных торговых сессий, для каждого вычисляет статус (paper/real/tested/draft), последний бэктест (PF, max DD), позицию из paper-портфеля (equity = balance + blocked, abs_pnl, pct_pnl). Тикеры сортируются лексикографически. Агрегаты по стратегии: `total_position_rub`, `total_abs_pnl`, `total_pct_pnl`.
- `Develop/backend/app/strategy/router.py` — `GET /strategy` теперь обогащает каждую стратегию сводкой `instruments` через `get_instruments_summary`.
- `Develop/backend/app/backtest/router.py` — в ответ списка бэктестов добавлены `profit_factor` и `max_drawdown_pct` (раньше возвращался только `net_profit_pct`).
- `Develop/frontend/src/api/strategyApi.ts` — добавлены типы `InstrumentBacktest`, `InstrumentPosition`, `InstrumentStatus`, `StrategyInstrumentSummary`. В `Strategy` — необязательные поля `instruments`, `total_position_rub`, `total_abs_pnl`, `total_pct_pnl`.
- `Develop/frontend/src/pages/DashboardPage.tsx` — таблица переписана по исходной спецификации Sprint 1 ([Sprint_1/ui_spec.md:93-178](../Sprint_1/ui_spec.md)). 5 колонок (Название/Инструмент, Статус, Бэктест, Позиция, P&L) вместо 4. Раскрывающиеся строки `▼/▶` показывают тикеры стратегии: иконка-аватар, кликабельный тикер → `/charts?ticker=X`, бэктест → `/backtests/:id`, позиция → `/trading/:session_id`. Цветовая кодировка P&L (green/red/dimmed). Контекстное меню расширено: «Запустить бэктест», «Запустить Paper» (жёлтая), «Запустить Real» (красная). Стратегии без тикеров — раскрытие отключено (точка вместо стрелки), в колонках бэктеста/позиции/P&L прочерки.

**Причина:**
Текущая реализация дашборда показывала только 4 базовые колонки (Название/Статус/Версия/Дата) и раскрывающуюся строку с текстом «Стратегия создана …». Это расходилось с дизайном, утверждённым в Sprint 1 и зафиксированным в UI-спецификации. После добавления реального CRUD стратегий в Sprint 3 расширенный вид с инструментами/бэктестами/позициями был утерян.

**Решение:**
Backend дополнен агрегатом по тикерам внутри каждой стратегии. Тикеры собираются как объединение `Backtest.ticker` всех версий стратегии и `TradingSession.ticker` активных сессий. По каждому тикеру вычисляются: статус, последний бэктест (PF, Max DD), позиция (equity текущего paper-портфеля минус initial_capital). Sandbox-сессии маппятся как paper для отображения. Real/sandbox-позиции по реальному T-Invest перенесены в Sprint 6 (вместе с реальными позициями счёта). Frontend полностью перерисован под исходный дизайн с раскрывающимися строками и кликабельными элементами.

**Решения по согласованию с заказчиком:**
1. «Инструмент стратегии» = объединение тикеров из её бэктестов и активных сессий.
2. Если по тикеру нет активной сессии, но есть бэктест → колонки Позиция/P&L показывают `—`.
3. В колонке «Бэктест» — самый последний бэктест по дате с кликом на `/backtests/:id`.
4. Сортировка стратегий — по `created_at DESC` (дата добавления). Сортировка тикеров внутри стратегии — лексикографическая.

**Тесты:**
- `ruff check app/strategy/` — **All checks passed**.
- Backend smoke import — ok.
- `npx tsc --noEmit` — **0 ошибок**.
- Backend перезапущен, Application startup complete.

---

## 2026-04-09 — Замечание 26: Раздел «Счёт» — единый календарь для фильтра операций

**Файлы:**
- `Develop/frontend/src/components/account/OperationsTable.tsx` — заменён `DatePickerInput` (из `@mantine/dates`) на пару `DateMaskInput` («С» / «По»), такой же, какой используется в модалке запуска бэктеста (`BacktestLaunchModal`). Добавлена кнопка «Сбросить» для очистки фильтра.

**Причина:**
В разделе «Счёт» при выборе периода открывался стандартный `DatePickerInput`, который визуально расходится с календарём из формы запуска бэктеста (`DateMaskInput` — кастомный popover с маской ввода `ДД.ММ.ГГГГ`). Пользователь попросил унифицировать.

**Решение:**
Перешли на тот же `DateMaskInput`, что и в `BacktestLaunchModal`. Два независимых поля «С» и «По» вместо range-пикера; колбэк `onDateRangeChange` вызывается, когда обе даты заданы или обе очищены. Кнопка «Сбросить» появляется, если хотя бы одно поле заполнено.

**Тесты:**
- `npx tsc --noEmit` — 0 ошибок.
