# T-Invest API — Описание сервисов

> Полный перечень всех 11 сервисов и их методов.
> Источник: [developer.tbank.ru/invest/api](https://developer.tbank.ru/invest/api)
>
> Дата фиксации: 2026-03-26 | Раздел «Приложение: enum-значения» обновлён 2026-05-15 (W8i)

---

## 1. InstrumentsService (42 метода)

Основной сервис для получения справочной информации об инструментах.

### Акции
| Метод | Описание |
|-------|----------|
| Shares | Получение списка всех акций |
| ShareBy | Получение акции по идентификатору |

### Облигации
| Метод | Описание |
|-------|----------|
| Bonds | Получение списка всех облигаций |
| BondBy | Получение облигации по идентификатору |
| GetBondCoupons | Расписание купонных платежей |
| GetBondEvents | События, связанные с облигацией |
| GetAccruedInterests | Накопленный купонный доход (НКД) |

### Валюты
| Метод | Описание |
|-------|----------|
| Currencies | Список доступных валют |
| CurrencyBy | Валюта по идентификатору |

### ETF / Фонды
| Метод | Описание |
|-------|----------|
| Etfs | Список инвестиционных фондов |
| EtfBy | Фонд по идентификатору |

### Фьючерсы
| Метод | Описание |
|-------|----------|
| Futures | Список фьючерсов |
| FutureBy | Фьючерс по идентификатору |
| GetFuturesMargin | Размер гарантийного обеспечения |

### Опционы
| Метод | Описание |
|-------|----------|
| Options | Список опционов (устаревший) |
| OptionsBy | Список опционов (новый) |
| OptionBy | Опцион по идентификатору |

### Цифровые активы (DFA)
| Метод | Описание |
|-------|----------|
| Dfas | Список цифровых активов |
| DfaBy | Цифровой актив по идентификатору |

### Структурные ноты
| Метод | Описание |
|-------|----------|
| StructuredNotes | Список структурных нот |
| StructuredNoteBy | Структурная нота по идентификатору |

### Индикативные инструменты
| Метод | Описание |
|-------|----------|
| Indicatives | Индексы, товары и другие индикативные инструменты |

### Поиск и информация
| Метод | Описание |
|-------|----------|
| FindInstrument | Поиск по position_uid, uid, figi, isin, ticker, name |
| GetInstrumentBy | Основная информация об инструменте |

### Активы и фундаментальные данные
| Метод | Описание |
|-------|----------|
| GetAssets | Список активов |
| GetAssetBy | Актив по идентификатору |
| GetAssetFundamentals | Фундаментальные показатели |
| GetAssetReports | Расписание выхода отчётностей эмитентов |

### Бренды
| Метод | Описание |
|-------|----------|
| GetBrands | Список брендов |
| GetBrandBy | Бренд по идентификатору |

### Аналитика
| Метод | Описание |
|-------|----------|
| GetConsensusForecasts | Мнения и прогнозы аналитиков |
| GetDividends | События выплаты дивидендов |
| GetForecastBy | Прогнозы инвестиционных домов |
| GetInsiderDeals | Сделки инсайдеров |
| GetRiskRates | Ставки риска по инструменту |

### Страны
| Метод | Описание |
|-------|----------|
| GetCountries | Список стран |

### Избранное
| Метод | Описание |
|-------|----------|
| GetFavorites | Список избранных инструментов |
| EditFavorites | Редактирование избранного |
| CreateFavoriteGroup | Создание группы избранных |
| DeleteFavoriteGroup | Удаление группы |
| GetFavoriteGroups | Список групп избранных |

### Расписания
| Метод | Описание |
|-------|----------|
| TradingSchedules | Расписания торговых площадок (макс. 1 неделя от текущей даты) |

---

## 2. MarketDataService (9 методов)

Сервис котировок — биржевая информация, включая исторические данные.

| Метод | Описание |
|-------|----------|
| GetCandles | Исторические свечи (макс. 1 календарный год за запрос) |
| GetLastPrices | Цены последних сделок |
| GetOrderBook | Биржевой стакан (глубины: 1, 10, 20, 30, 40, 50) |
| GetClosePrices | Цены закрытия торговой сессии |
| GetLastTrades | Обезличенные сделки |
| GetMarketValues | Рыночные данные по инструментам |
| GetTechAnalysis | Технические индикаторы |
| GetTradingStatus | Статус торгов по инструменту |
| GetTradingStatuses | Статус торгов по нескольким инструментам |

### Особенности расчёта цен

- **Облигации**: цена в пунктах (% от номинала). Формула: `price / 100 * nominal`
- **Фьючерсы**: `price / min_price_increment * min_price_increment_amount`
- **Акции**: `price * lot`
- **Валюта**: `price * lot / nominal`

---

## 3. MarketDataStreamService (2 метода)

Real-time рыночные данные с минимальными задержками.

| Метод | Описание |
|-------|----------|
| MarketDataStream | Bidirectional stream — подписка на рыночные данные |
| MarketDataServerSideStream | Server-side stream — для gRPC-web (браузерные клиенты) |

### Типы подписок (в одном соединении)

- Стаканы (разные глубины)
- Свечи
- Обезличенные сделки
- Статусы торговли
- Цены последних сделок
- GetMySubscriptions — текущие подписки

### Ограничения

- Макс. 300 подписок на соединение
- 100 запросов подписки в минуту
- Свечи: не чаще 1 раза в 300мс
- Стакан: интервал 100мс

---

## 4. OperationsService (7 методов)

Портфель, позиции и история операций.

| Метод | Описание |
|-------|----------|
| GetOperations | Список операций (макс. 1000, без опционов) |
| GetOperationsByCursor | Операции с пагинацией (рекомендуемый) |
| GetPortfolio | Портфель: доходности, стоимость активов |
| GetPositions | Позиции: типы инструментов, заблокированные средства |
| GetWithdrawLimits | Доступный остаток для вывода |
| GetBrokerReport | Брокерский отчёт |
| GetDividendsForeignIssuer | Отчёт о доходах за пределами РФ |

---

## 5. OperationsStreamService (3 метода)

Real-time изменения портфеля и позиций.

| Метод | Описание |
|-------|----------|
| PortfolioStream | Изменения портфеля (полная статистика в валюте инструмента) |
| PositionsStream | Изменения позиций (деньги, бумаги, фьючерсы, опционы) |
| OperationsStream | Поток операций (сделки, зачисления, списания) |

---

## 6. OrdersService (8 методов)

Управление торговыми заявками.

| Метод | Описание |
|-------|----------|
| PostOrder | Выставить заявку (лимитная, рыночная) |
| PostOrderAsync | Выставить заявку асинхронно |
| ReplaceOrder | Изменить выставленную заявку (отмена + новая) |
| CancelOrder | Отменить заявку |
| GetOrders | Список активных заявок (не возвращает исполненные) |
| GetOrderState | Статус и стадии выполнения поручения |
| GetMaxLots | Расчёт доступных для покупки/продажи лотов |
| GetOrderPrice | Предварительная стоимость для лимитной заявки |

### Особенности

- **Идемпотентность**: `order_id` — ключ идемпотентности (уникальность 1 месяц)
- **Облигации**: учитывается НКД через `aci_value`
- **Опционы**: только лимитные заявки
- **Ограничение**: заявки > 30 млн ₽ требуют СМС-подтверждения

---

## 7. OrdersStreamService (2 метода)

Real-time события исполнения торговых поручений.

| Метод | Описание |
|-------|----------|
| TradesStream | Server-side stream — события исполнения |
| OrderStateStream | Поток состояний заявок |

Трансляция всех совершённых сделок по счетам пользователя.

---

## 8. StopOrdersService (3 метода)

Стоп-заявки — условные поручения, которые превращаются в биржевые при достижении условия.

| Метод | Описание |
|-------|----------|
| PostStopOrder | Выставить стоп-заявку |
| GetStopOrders | Список активных стоп-заявок (не конвертированных) |
| CancelStopOrder | Отменить стоп-заявку |

### Период действия (`expiration_type`)

- `GoodTillCancel` — до отмены
- `GoodTillDate` — до указанной даты

---

## 9. UsersService (8 методов)

Информация об аккаунтах и пользователе.

| Метод | Описание |
|-------|----------|
| GetAccounts | Список счетов пользователя (доступные для токена) |
| GetInfo | Информация: квал. инвестор, премиум, доступные типы инструментов |
| GetUserTariff | Тариф: лимиты по методам и stream-соединениям |
| GetMarginAttributes | Маржинальные показатели: ликвидность, маржа, достаточность средств |
| GetAccountValues | Дополнительные показатели счетов |
| GetBankAccounts | Банковские счета пользователя |
| CurrencyTransfer | Переводы между счетами |
| PayIn | Пополнение брокерского счёта |

### Типы аккаунтов

- **Брокерский** (brokerage)
- **ИИС** (individual investment account)
- **Инвесткопилка** (savings/accumulation)

### Статусы аккаунтов

- `ACCOUNT_STATUS_NEW`
- `ACCOUNT_STATUS_OPEN`
- `ACCOUNT_STATUS_CLOSED`

---

## 10. SandboxService (20 методов)

Тестирование торговых алгоритмов в песочнице. Подробнее: [tinvest_api_sandbox.md](tinvest_api_sandbox.md)

| Метод | Описание |
|-------|----------|
| OpenSandboxAccount | Создать sandbox-счёт |
| CloseSandboxAccount | Закрыть sandbox-счёт |
| SandboxPayIn | Пополнить виртуальный баланс |
| GetSandboxAccounts | Список sandbox-счетов |
| PostSandboxOrder | Разместить заявку |
| PostSandboxOrderAsync | Разместить заявку асинхронно |
| ReplaceSandboxOrder | Изменить заявку |
| CancelSandboxOrder | Отменить заявку |
| GetSandboxOrders | Список активных заявок |
| GetSandboxOrderState | Статус заявки |
| GetSandboxOrderPrice | Предварительная стоимость заявки |
| PostSandboxStopOrder | Выставить стоп-заявку |
| GetSandboxStopOrders | Список стоп-заявок |
| CancelSandboxStopOrder | Отменить стоп-заявку |
| GetSandboxPortfolio | Портфель |
| GetSandboxPositions | Позиции |
| GetSandboxOperations | История операций |
| GetSandboxOperationsByCursor | Операции с пагинацией |
| GetSandboxWithdrawLimits | Доступный остаток |
| GetSandboxMaxLots | Расчёт доступных лотов |

---

## 11. SignalService (2 метода)

Сигналы и прогнозы (информация ограничена в публичной документации).

| Метод | Описание |
|-------|----------|
| GetSignals | Получение торговых сигналов |
| GetStrategies | Получение стратегий |

---

## Приложение: enum-значения protobuf (актуально 2026-05-15, после W8i)

Источник цитат: [investAPI/src/docs/contracts/](https://github.com/RussianInvestments/investAPI/tree/main/src/docs/contracts) — официальные `.proto`-файлы.

Внутренний маппинг в `app/broker/tinvest/mapper.py` сверен с этими enum'ами; регрессионный тест в `tests/unit/test_broker/test_mapper.py::TestProtoEnumAlignmentW8i` ловит будущий дрейф.

### OrderExecutionReportStatus (orders.proto)

⚠ **Критично**: значения сдвинуты относительно интуиции. Из-за неверного маппинга в коде Sprint 1–8 (W8i фикс) sandbox-сделки никогда не получали `entry_price` — T-Invest возвращал `FILL=1`, наш код интерпретировал как `"new"`.

| int | proto | Наш `ORDER_STATUS_MAP` | simple-status (OrderResponse) |
|-----|-------|------------------------|-------------------------------|
| 0 | UNSPECIFIED | `"unspecified"` | `"placed"` (default) |
| **1** | **FILL** *(Исполнена)* | **`"filled"`** | `"filled"` |
| **2** | **REJECTED** | **`"rejected"`** | `"rejected"` |
| **3** | **CANCELLED** | **`"cancelled"`** | `"rejected"` (по семантике «не исполнен») |
| **4** | **NEW** *(в book'е)* | **`"new"`** | `"placed"` |
| **5** | **PARTIALLYFILL** | **`"partially_filled"`** | `"partially_filled"` |

### OrderType (orders.proto)

| int | proto | Использование |
|-----|-------|---------------|
| 1 | ORDER_TYPE_LIMIT | `LiveTrade.order_type = "market"` всегда (S8 W7 — мы используем только market). Limit передаётся SDK-enum напрямую (без mapping). |
| 2 | ORDER_TYPE_MARKET | то же |
| 3 | ORDER_TYPE_BESTPRICE | не используется |

### OrderDirection (orders.proto)

| int | proto | Наш `direction` |
|-----|-------|-----------------|
| 1 | ORDER_DIRECTION_BUY | `"buy"` |
| 2 | ORDER_DIRECTION_SELL | `"sell"` |

### AccountStatus (users.proto)

| int | proto | Наш `ACCOUNT_STATUS_MAP` |
|-----|-------|--------------------------|
| 0 | UNSPECIFIED | `"unspecified"` |
| 1 | NEW | `"new"` |
| 2 | OPEN | **`"active"`** (внутренний перевод S5) |
| 3 | CLOSED | `"closed"` |
| 4 | ALL | `"all"` (мета-значение для фильтров запросов) |

### AccountType (users.proto)

| int | proto | Наш `ACCOUNT_TYPE_MAP` |
|-----|-------|------------------------|
| 0 | UNSPECIFIED | `"unspecified"` |
| 1 | TINKOFF | **`"broker"`** (внутренний перевод) |
| 2 | TINKOFF_IIS | `"iis"` |
| 3 | INVEST_BOX | `"invest_box"` |
| 4 | INVEST_FUND | `"invest_fund"` |
| 5 | DEBIT | `"debit"` (добавлено W8i) |
| 6 | SAVING | `"saving"` (добавлено W8i) |

### SecurityTradingStatus (common.proto)

17 значений (0–16). Полный mapping в `TRADING_STATUS_MAP`. Используется для `InstrumentInfo.trading_status` в адаптере.

Ключевые:
- `0`: `unspecified`
- `5`: `normal_trading` — нормальная торговая фаза (можно отправлять market)
- `13`: `session_open` — старт сессии
- `12`: `session_close` — конец сессии
- `1`: `not_available_for_trading` — приостановка / выходной

### OperationType / OperationState (operations.proto)

Маппинг — **по имени enum** (не по int), поскольку значения могут отличаться между версиями SDK. См. `OPERATION_TYPE_NAME_MAP` и `OPERATION_STATE_NAME_MAP` в `app/broker/tinvest/mapper.py`. Используется в `OperationsService.GetOperations` для импорта истории операций (S5R.3, налоговый экспорт).
