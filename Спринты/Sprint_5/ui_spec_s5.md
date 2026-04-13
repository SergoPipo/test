# UI-спецификация -- Sprint 5: Trading Panel, Account, Favorites, RT-графики

> Версия: 1.0
> Дизайн-система: Mantine 7.8+, Dark theme, Tabler Icons
> Наследует принципы: ui_spec_s4.md

---

## Общие принципы (наследуемые из S4)

| Параметр | Значение |
|----------|----------|
| Фон приложения | `#1A1B1E` |
| Карточки | `#25262B` |
| Тема | Dark theme обязателен |
| Формат чисел | `1 234 567,89 Р` (`Intl.NumberFormat('ru-RU')`) |
| Формат дат | `ДД.ММ.ГГГГ` |
| Иконки | Tabler Icons |
| Графики | TradingView Lightweight Charts 4.1+ |
| UI kit | Mantine 7.8+ |

### Цветовые константы S5

| Назначение | Цвет | Mantine-токен |
|------------|-------|---------------|
| PAPER badge | `#fab005` | `yellow.6` |
| REAL badge | `#fa5252` | `red.6` |
| P&L положительный | `#69db7c` | `green.4` |
| P&L отрицательный | `#ff8787` | `red.4` |
| Фон карточки "хорошо" | `#1a2e1a` | -- |
| Фон карточки "плохо" | `#2e1a1a` | -- |
| Нейтральный текст | `#C1C2C5` | dimmed |
| Индикатор WS connected | `#69db7c` | `green.4` |
| Индикатор WS disconnected | `#ff8787` | `red.4` |
| Покупка (маркер) | `#69db7c` зеленый треугольник вверх | `green.4` |
| Продажа (маркер) | `#ff8787` красный треугольник вниз | `red.4` |

---

## 1. Trading Panel (`/trading`)

### 1.1 Список активных сессий

**Маршрут:** `/trading`

**Mantine-компоненты:**
- `Title` order={2} -- заголовок страницы
- `Button` variant="filled" color="blue" -- "Запустить сессию"
- `SimpleGrid` cols={{ base: 1, sm: 2, lg: 3 }} -- сетка карточек
- `Card` shadow="sm" radius="md" -- карточка сессии
- `Badge` -- режим PAPER / REAL
- `Text` -- тикер, стратегия, P&L
- `Group` -- кнопки действий
- `ActionIcon` -- Пауза, Стоп, График
- `Sparkline` (кастомный, SVG или Lightweight Charts mini) -- мини-график equity

```
+---------------------------------------------------------------------+
| Торговля                                      [+ Запустить сессию]   |
+---------------------------------------------------------------------+
|                                                                      |
|  +--------------------+  +--------------------+  +----------------+  |
|  | [PAPER]            |  | [REAL]             |  | [PAPER]        |  |
|  | Badge yellow.6     |  | Badge red.6        |  | Badge yellow.6 |  |
|  |                    |  |                    |  |                |  |
|  | SBER               |  | GAZP               |  | LKOH           |  |
|  | SMA Crossover      |  | RSI Bounce         |  | MACD Div       |  |
|  |                    |  |                    |  |                |  |
|  | P&L: +12 450 Р     |  | P&L: -3 200 Р     |  | P&L: 0 Р       |  |
|  |  green.4           |  |  red.4             |  |  dimmed        |  |
|  |                    |  |                    |  |                |  |
|  | __/\  /\___ spark  |  | \__/\__/ spark     |  | _______ flat   |  |
|  |                    |  |                    |  |                |  |
|  | [Pause] [Stop] [>] |  | [Pause] [Stop] [>] |  | [Pause][Stop]  |  |
|  | ActionIcon x3      |  | ActionIcon x3      |  | [>]            |  |
|  +--------------------+  +--------------------+  +----------------+  |
|                                                                      |
+---------------------------------------------------------------------+
```

**Детали карточки:**

```
+--------------------------------------+
|  [PAPER]  Badge variant="filled"     |   <- yellow.6 или red.6
|           color="yellow"/"red"       |
|                                      |
|  SBER         Text size="lg" fw={700}|
|  SMA Crossover  Text size="sm" c="dimmed"
|                                      |
|  P&L: +12 450 Р                     |   <- green.4 / red.4
|  Text size="md" fw={600}            |
|                                      |
|  [sparkline: SVG 150x40]            |   <- equity последние 24ч
|                                      |
|  [IconPlayerPause] [IconPlayerStop]  |   <- ActionIcon variant="subtle"
|  [IconChartCandle]                   |   <- переход к графику
+--------------------------------------+
```

**P&L-логика цвета:**
- `> 0` -- `color="green.4"` (`#69db7c`)
- `< 0` -- `color="red.4"` (`#ff8787`)
- `= 0` -- `c="dimmed"` (`#C1C2C5`)

**Sparkline:** SVG-полилиния 150x40px, stroke=2, цвет совпадает с P&L.

### 1.2 Детальный дашборд сессии (`/trading/sessions/:id`)

**Mantine-компоненты:**
- `Breadcrumbs` -- навигация назад
- `Title` order={3} -- "SBER . SMA Crossover"
- `Badge` -- режим (PAPER/REAL)
- `Badge` -- статус (Активна green / Пауза yellow / Остановлена gray)
- `ActionIcon` -- Пауза, Стоп
- `Tabs` -- Позиции | Сделки | Статистика
- `Table` (TanStack) -- таблицы позиций и сделок
- Lightweight Charts -- equity curve сессии
- `SimpleGrid` cols={4} -- карточки статистики

```
+---------------------------------------------------------------------+
| <- Назад   SBER . SMA Crossover   [PAPER]  . Активна   [Pause][Stop]|
|  Breadcrumbs  Title               Badge x2  ActionIcon x2            |
+----------+----------+------------------------------------------------+
| Позиции  |  Сделки  |  Статистика                  Tabs              |
+----------+----------+------------------------------------------------+
|                                                                      |
|  === Открытые позиции ===                     Table (TanStack)       |
|  +-------+------+--------+----------+---------+--------+-----------+ |
|  |Тикер  |Напр. |Вход    |Текущая   |P&L      |Время   |Действие   | |
|  +-------+------+--------+----------+---------+--------+-----------+ |
|  |SBER   |LONG  |280,50 Р|285,20 Р  |+4 700 Р |2ч 15м  |[Закрыть]  | |
|  |       | ^grn |        |          | green.4 |        |ActionIcon | |
|  +-------+------+--------+----------+---------+--------+-----------+ |
|                                                                      |
|  === Equity Curve сессии ===          Lightweight Charts              |
|  +------------------------------------------------------------------+|
|  |                                                                   ||
|  |  LineSeries green.4 -- equity curve                               ||
|  |  Markers: green ^ (buy), red v (sell)                             ||
|  |                                                                   ||
|  |  Высота: 300px                                                    ||
|  +------------------------------------------------------------------+|
|                                                                      |
|  === Статистика ===                   SimpleGrid cols={4}            |
|  +---------------+ +---------------+ +---------------+ +-----------+ |
|  |Дневной P&L    | |Суммарный P&L  | |Win Rate       | |Сделок     | |
|  |+4 700 Р       | |+12 450 Р      | |67%            | |12         | |
|  | green.4       | | green.4       | | green.4       | | dimmed    | |
|  +---------------+ +---------------+ +---------------+ +-----------+ |
|                                                                      |
+---------------------------------------------------------------------+
```

**Вкладка "Позиции" -- колонки:**

| Колонка | Формат | Цвет |
|---------|--------|------|
| Тикер | `SBER` | стандартный |
| Направление | `LONG ^` / `SHORT v` | green.4 / red.4 |
| Цена входа | `280,50 Р` | dimmed |
| Текущая цена | `285,20 Р` | стандартный |
| P&L | `+4 700 Р` | green.4 / red.4 |
| Время удержания | `2ч 15м` | dimmed |
| Действие | ActionIcon `IconX` | кнопка "Закрыть" |

**Вкладка "Сделки" -- колонки:**

| Колонка | Формат | Сортировка |
|---------|--------|-----------|
| # | Порядковый | -- |
| Тикер | `SBER` | -- |
| Направление | `LONG` / `SHORT` | -- |
| Вход | Дата + цена | По дате |
| Выход | Дата + цена | По дате |
| P&L | `+2 340 Р` / `+1,2%` | По сумме |
| P&L% | `+1,2%` | По % |
| Комиссия | `56 Р` | -- |
| Slippage | `12 Р` | -- |
| Длительность | `3ч 20м` | По длительности |

**Вкладка "Статистика":** SimpleGrid cols={4} из Card-метрик (как в бэктесте S4). Цвета по порогам из S4.

### 1.3 Форма запуска сессии (модалка)

**Mantine-компоненты:**
- `Modal` size="lg" centered title="Запуск торговой сессии"
- `Select` -- стратегия (dropdown)
- `Select` -- версия стратегии
- `Autocomplete` -- поиск тикера (переиспользовать из S2)
- `Radio.Group` -- режим Paper / Real
- `NumberInput` -- начальный капитал, размер позиции, макс. позиций, cooldown
- `Select` -- тип размера позиции (Фикс. сумма / % от депозита / Фикс. лоты)
- `Divider` label="Брокер (только для Real)" -- разделитель
- `Select` -- брокерский аккаунт
- `Select` -- счёт
- `Button` variant="default" -- Отмена
- `Button` variant="filled" color="blue" -- Запустить

```
+-------------------------------------------------------+
| Запуск торговой сессии                          [X]    |
|  Modal size="lg" centered                              |
+-------------------------------------------------------+
|                                                        |
|  Стратегия:    [  SMA Crossover           v ]  Select  |
|  Версия:       [  v3 (текущая)            v ]  Select  |
|                                                        |
|  Инструмент:   [  search ticker...          ]  Autocomp|
|                                                        |
|  Режим:                              Radio.Group       |
|    ( ) Paper (бумажная)              Radio yellow       |
|    ( ) Real (боевая)                 Radio red          |
|                                                        |
|  --- Параметры ---                   Divider           |
|  Начальный капитал:  [ 1 000 000 ] Р    NumberInput    |
|  Размер позиции:     [ Фикс. сумма  v ] Select         |
|                      [ 100 000       ]   NumberInput    |
|  Макс. позиций:      [ 1            ]   NumberInput    |
|  Cooldown (сек):     [ 60           ]   NumberInput    |
|                                                        |
|  --- Брокер (только для Real) ---   Divider            |
|  Брокерский аккаунт: [ T-Invest (Основной) v ] Select  |
|  Счёт:               [ Брокерский          v ] Select  |
|                                                        |
|           [ Отмена ]    [ Запустить ]                   |
|           Button default  Button filled blue            |
+-------------------------------------------------------+
```

**Секция "Брокер":** отображается только при выборе режима Real. Использовать `Collapse` или условный рендеринг.

**При выборе Real -- confirm-диалог:**

```
+-------------------------------------------------------+
|  !! Внимание: Боевая торговля                          |
|  Alert color="red" variant="light"                     |
|                                                        |
|  Стратегия будет торговать реальными деньгами.          |
|                                                        |
|  Инструмент:  SBER                                     |
|  Размер:      100 000 Р                                |
|  Счёт:        Брокерский (T-Invest)                    |
|                                                        |
|  [ Отмена ]         [ Подтверждаю запуск ]             |
|  Button default     Button color="red" variant="filled"|
+-------------------------------------------------------+
```

**Mantine-компоненты confirm:**
- `Modal` size="sm" centered
- `Alert` color="red" variant="light" icon={IconAlertTriangle}
- `Text` -- детали (инструмент, размер, счёт)
- `Button` variant="default" -- Отмена
- `Button` variant="filled" color="red" -- Подтверждаю запуск

### 1.4 Состояния Trading Panel

**Loading:**
```
+---------------------------------------------------------------------+
| Торговля                                      [ Skeleton Button ]    |
+---------------------------------------------------------------------+
|  +--------------------+  +--------------------+  +----------------+  |
|  | Skeleton h=200     |  | Skeleton h=200     |  | Skeleton h=200 |  |
|  | radius="md"        |  | radius="md"        |  | radius="md"    |  |
|  +--------------------+  +--------------------+  +----------------+  |
+---------------------------------------------------------------------+
```
Mantine: `Skeleton` height={200} radius="md" -- 3 штуки в SimpleGrid.

**Empty:**
```
+---------------------------------------------------------------------+
|                                                                      |
|              IconTrendingUp size=64 color="#909296"                   |
|                                                                      |
|          Нет активных торговых сессий                                 |
|          Text size="lg" fw={500}                                     |
|                                                                      |
|          Запустите первую стратегию в бумажном                        |
|          или боевом режиме                                            |
|          Text size="sm" c="dimmed"                                    |
|                                                                      |
|              [+ Запустить сессию]                                     |
|              Button variant="filled" color="blue"                     |
|                                                                      |
+---------------------------------------------------------------------+
```
Mantine: `Center` h="60vh", `Stack` align="center", `Text`, `Button`.

**Error:**
```
+---------------------------------------------------------------------+
|  Alert color="red" variant="light" icon={IconAlertCircle}            |
|                                                                      |
|  Ошибка загрузки торговых сессий                                     |
|  Текст ошибки: Connection refused                                    |
|                                                                      |
|  [Повторить]  Button variant="outline" color="red"                   |
+---------------------------------------------------------------------+
```
Mantine: `Alert` color="red" variant="light" с `Button` внутри.

**Filled:** основной mockup (секция 1.1).

---

## 2. Экран "Счёт" (`/account`)

### 2.1 Основной экран

**Маршрут:** `/account`

**Mantine-компоненты:**
- `Title` order={2} -- "Счёт"
- `Select` -- выбор брокерского аккаунта (если несколько)
- `SimpleGrid` cols={3} -- карточки баланса
- `Card` -- каждая карточка баланса
- `Text` size="xl" fw={700} -- сумма
- `Text` size="sm" c="dimmed" -- подпись
- `Table` (TanStack) -- позиции у брокера
- `DatePickerInput` type="range" -- фильтр дат для истории
- `Table` (TanStack) -- история операций
- `Pagination` -- пагинация истории
- `Button` variant="outline" leftSection={IconFileText} -- "Налоговый отчёт"

```
+---------------------------------------------------------------------+
| Счёт                     Брокер: [ T-Invest (Основной) v ]   Select  |
+---------------------------------------------------------------------+
|                                                                      |
|  +-- Баланс ----------+  +-- Доступно -------+  +-- В позициях ---+ |
|  |   Card             |  |   Card             |  |   Card          | |
|  |   1 234 567 Р      |  |   987 654 Р        |  |   246 913 Р     | |
|  |   Text xl fw=700   |  |   Text xl fw=700   |  |   Text xl fw=700| |
|  |   Всего             |  |   Свободные        |  |   Заблокировано | |
|  |   Text sm dimmed    |  |   Text sm dimmed   |  |   Text sm dimmed| |
|  +--------------------+  +--------------------+  +-----------------+ |
|                                                                      |
|  === Позиции у брокера ===                        Title order={4}    |
|  +-------+-------+---------+----------+---------+------------------+ |
|  |Тикер  |Кол-во |Ср. цена |Текущая   |P&L      |Источник          | |
|  +-------+-------+---------+----------+---------+------------------+ |
|  |SBER   |100    |280,50 Р |285,20 Р  |+470 Р   |Badge "Стратегия" | |
|  |       |       |         |          |green.4  |color="blue"      | |
|  |GAZP   |50     |165,00 Р |163,80 Р  |-60 Р    |Badge "Внешняя"   | |
|  |       |       |         |          |red.4    |color="gray"      | |
|  +-------+-------+---------+----------+---------+------------------+ |
|                                                                      |
|  === История операций ===             Title order={4}                |
|  Период: [ 01.04.2026 ] -- [ 07.04.2026 ]   DatePickerInput range   |
|                                                                      |
|  +----------+-------+--------+--------+--------+-------------------+ |
|  |Дата      |Тикер  |Тип     |Объём   |Цена    |Сумма              | |
|  +----------+-------+--------+--------+--------+-------------------+ |
|  |07.04     |SBER   |Покупка |100 шт  |280,50 Р|28 050 Р           | |
|  |14:30     |       |Bdg grn |        |        |                   | |
|  |06.04     |GAZP   |Продажа |50 шт   |165,00 Р|8 250 Р            | |
|  |11:15     |       |Bdg red |        |        |                   | |
|  +----------+-------+--------+--------+--------+-------------------+ |
|                                                                      |
|  < 1  2  3  4  5 ... 13  >        Показано 1-10 из 127   Pagination  |
|                                                                      |
|  [Налоговый отчёт]   Button variant="outline" leftSection=IconFile   |
|                                                                      |
+---------------------------------------------------------------------+
```

**Колонка "Источник":**
- `Badge` color="blue" variant="light" -- "Стратегия" (позиция открыта стратегией)
- `Badge` color="gray" variant="light" -- "Внешняя" (куплено вне системы)

**Колонка "Тип" в истории:**
- `Badge` color="green" variant="light" size="sm" -- "Покупка"
- `Badge` color="red" variant="light" size="sm" -- "Продажа"

### 2.2 Модалка налогового отчёта

**Mantine-компоненты:**
- `Modal` size="md" centered title="Налоговый отчёт (3-НДФЛ)"
- `Select` -- год (2025, 2024, ...)
- `Radio.Group` -- формат (Excel / CSV)
- `Checkbox.Group` -- включить типы бумаг
- `Button` variant="default" -- Отмена
- `Button` variant="filled" color="blue" leftSection={IconDownload} -- "Скачать отчёт"

```
+-------------------------------------------+
| Налоговый отчёт (3-НДФЛ)           [X]    |
|  Modal size="md" centered                  |
+-------------------------------------------+
|                                            |
|  Период:  [ 2025       v ]   Select        |
|           (календарный год)                |
|                                            |
|  Формат:                    Radio.Group    |
|    ( ) Excel (.xlsx)        Radio          |
|    (*) CSV (.csv)           Radio          |
|                                            |
|  Включить:                  Checkbox.Group |
|  [x] Акции                  Checkbox       |
|  [x] Облигации (+ купонный доход)          |
|  [x] ETF / БПИФ            Checkbox       |
|                                            |
|       [ Отмена ]  [ Скачать отчёт ]        |
|       Btn default  Btn filled blue         |
+-------------------------------------------+
```

### 2.3 Состояния Account

**Loading:**
```
+---------------------------------------------------------------------+
| Счёт                                                                 |
+---------------------------------------------------------------------+
|  +-- Skeleton h=90 --+  +-- Skeleton h=90 --+  +-- Skeleton h=90 -+ |
|  +--------------------+  +--------------------+  +-----------------+ |
|                                                                      |
|  Skeleton h=200 -- таблица позиций                                   |
|  Skeleton h=200 -- таблица истории                                   |
+---------------------------------------------------------------------+
```
Mantine: `Skeleton` height={90} radius="md" x3 + `Skeleton` height={200} x2.

**Empty:**
```
+---------------------------------------------------------------------+
|                                                                      |
|              IconWallet size=64 color="#909296"                       |
|                                                                      |
|          Нет подключённых брокерских счетов                           |
|          Text size="lg" fw={500}                                     |
|                                                                      |
|          Подключите брокера в настройках                              |
|          для просмотра баланса и позиций                              |
|          Text size="sm" c="dimmed"                                    |
|                                                                      |
|              [Перейти в настройки]                                    |
|              Button variant="filled" -> /settings/brokers             |
|                                                                      |
+---------------------------------------------------------------------+
```

**Error:**
```
+---------------------------------------------------------------------+
|  Alert color="red" variant="light" icon={IconAlertCircle}            |
|                                                                      |
|  Ошибка загрузки данных счёта                                        |
|  Не удалось подключиться к брокеру. Проверьте API-ключ.              |
|                                                                      |
|  [Повторить]  Button variant="outline" color="red"                   |
+---------------------------------------------------------------------+
```

**Filled:** основной mockup (секция 2.1).

---

## 3. Панель "Избранные инструменты" (FavoritesPanel)

### 3.1 Расположение и layout

Панель располагается **справа от графика** на странице ChartPage. Ширина: 220px. Сворачиваемая по кнопке в toolbar графика.

**Mantine-компоненты:**
- `Box` w={220} -- контейнер панели
- `Group` -- header панели
- `ActionIcon` -- toggle (звезда `IconStar`)
- `Title` order={5} -- "Избранные"
- `ScrollArea` -- скроллируемый список
- `UnstyledButton` -- элемент списка (кликабельный)
- `Text` -- тикер, статистика
- `CloseButton` size="xs" -- удаление при hover
- `Button` variant="subtle" -- "+ Добавить"
- `Autocomplete` -- поиск тикера (появляется по кнопке)

### 3.2 Mockup -- панель развёрнута

```
+-----------------------------------+---------------------+
|                                   | * Избранные         |
|    Свечной график                 | Title order={5}     |
|    (Lightweight Charts)           |                     |
|                                   | +-- UnstyledButton -|
|                                   | | SBER  Text fw=700 |
|                                   | | 3 бэкт . 2 стр   |
|                                   | | P&L: +5,2% grn.4  |
|                                   | +-- [X on hover] ---+
|                                   | Divider             |
|    Chart занимает                 | +-- UnstyledButton -|
|    оставшееся пространство        | | GAZP  Text fw=700 |
|    flex: 1                        | | 1 бэкт . 1 стр   |
|                                   | | P&L: -1,8% red.4  |
|                                   | +-- [X on hover] ---+
|                                   | Divider             |
|                                   | +-- UnstyledButton -|
|                                   | | LKOH  Text fw=700 |
|                                   | | 5 бэкт . 3 стр   |
|                                   | | P&L: +12,1% grn.4 |
|                                   | +-- [X on hover] ---+
|                                   |                     |
|                                   | [+ Добавить]        |
|                                   | Button variant=     |
|                                   |  "subtle" fullWidth |
+-----------------------------------+---------------------+
      flex: 1                          w={220}
```

### 3.3 Mockup -- панель свёрнута

```
+-----------------------------------------------------------+--+
|                                                            |* |
|    Свечной график (Lightweight Charts)                     |  |
|    Занимает всю ширину                                     |  |
|                                                            |  |
+-----------------------------------------------------------+--+
                                                         ActionIcon
                                                         IconStar
                                                         w=40
```

Кнопка `IconStar` в toolbar графика:
- Заполненная звезда (`IconStarFilled`) -- панель развёрнута
- Пустая звезда (`IconStar`) -- панель свёрнута

### 3.4 Элемент списка -- детали

```
+---------------------------------------+
|  SBER                         [X]     |   <- CloseButton, видна при hover
|  Text size="md" fw={700}      xs      |
|                                       |
|  3 бэкт . 2 стр                      |   <- Text size="xs" c="dimmed"
|                                       |      кол-во бэктестов / стратегий
|  P&L: +5,2%                          |   <- Text size="sm" color="green.4"
|                                       |      средний P&L по всем бэктестам
+---------------------------------------+
```

**Клик:** переключает график на выбранный тикер (вызов `setTicker` + `fetchCandles`).

**Hover:** фон карточки `#2C2E33`, появляется `CloseButton` в правом верхнем углу.

**Кнопка "+ Добавить":** открывает `Popover` с `Autocomplete` для поиска тикера. После выбора тикер добавляется в избранное (Zustand `favoritesStore`).

### 3.5 Данные элемента

| Поле | Источник | Формат |
|------|----------|--------|
| Тикер | favoritesStore | `SBER` |
| Кол-во бэктестов | API: /api/v1/backtests?ticker=X count | `3 бэкт` |
| Кол-во стратегий | API: /api/v1/strategies?ticker=X count | `2 стр` |
| Средний P&L | API: avg(backtest.net_profit_pct) | `+5,2%` / `-1,8%` |

### 3.6 Состояния FavoritesPanel

**Loading:** 3x `Skeleton` height={60} внутри панели.

**Empty:**
```
+---------------------+
| * Избранные         |
|                     |
| IconStarOff size=40 |
| color="#909296"     |
|                     |
| Нет избранных       |
| Text size="sm"      |
| c="dimmed"          |
|                     |
| Добавьте тикеры     |
| для быстрого        |
| доступа             |
|                     |
| [+ Добавить]        |
+---------------------+
```

**Error:** `Alert` size="xs" color="red" внутри панели: "Ошибка загрузки". Не блокирует график.

**Filled:** основной mockup (секция 3.2).

---

## 4. Улучшения графика (Real-time)

### 4.1 Real-time свечи через WebSocket

Подключение: канал `market:{ticker}:{tf}` через мультиплексированный WebSocket `/ws`.

Обновление свечи: вызов `candleSeries.update(bar)` при каждом тике. Последняя свеча обновляется in-place (цвет зависит от open/close).

### 4.2 Маркеры сделок

При наличии активной торговой сессии на текущем инструменте -- на графике отображаются маркеры.

```
                     Marker API (Lightweight Charts)
   |                                                     |
   |          v red.4 (продажа)                          |
   |     _____|____                                      |
   |    |     |    |                                     |
   |    |  O  |    |                                     |
   |    |_____|____|    ____                              |
   |         |         |    |                             |
   |         |    _____|    |                             |
   |         |   |     |   |                              |
   |              |____|___|                              |
   |                   |                                  |
   |              ^ green.4 (покупка)                    |
   |___________________________________________________ |
```

**Параметры маркеров:**

| Тип | shape | position | color | text |
|-----|-------|----------|-------|------|
| Покупка | `arrowUp` | `belowBar` | `#69db7c` | `BUY 280,50` |
| Продажа | `arrowDown` | `aboveBar` | `#ff8787` | `SELL 285,20` |

**Mantine/LWC API:**
```typescript
chart.addMarkers([
  {
    time: timestamp,
    position: 'belowBar',
    shape: 'arrowUp',
    color: '#69db7c',
    text: 'BUY 280,50',
  },
  {
    time: timestamp,
    position: 'aboveBar',
    shape: 'arrowDown',
    color: '#ff8787',
    text: 'SELL 285,20',
  },
]);
```

### 4.3 Индикатор подключения WebSocket

Расположение: правый верхний угол графика (overlay, position absolute).

```
+------------------------------------------------------------+
|                                          [. WS]   indicator |
|                                          green/red dot      |
|   Candlestick Chart                      + tooltip          |
|                                                             |
+------------------------------------------------------------+
```

**Состояния индикатора:**

| Состояние | Вид | Tooltip |
|-----------|-----|---------|
| Connected | Зелёная точка (пульсирующая CSS-анимация) | "Подключено к market:SBER:D" |
| Disconnected | Красная точка (статичная) | "Отключено. Переподключение..." |
| Reconnecting | Жёлтая точка (мигающая) | "Переподключение (попытка 3/5)..." |

**Mantine-компоненты:**
- `Box` -- контейнер, position absolute, top=8, right=8
- `Indicator` или кастомный div -- цветная точка 8x8px
- `Tooltip` -- статус при hover
- CSS `@keyframes pulse` -- анимация пульсации для connected

```css
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}
```

### 4.4 Обновлённый toolbar графика

```
+------------------------------------------------------------+
| SBER - 285,20 Р (+1,2%)     [1м][5м][15м][1ч][4ч][Д][Н][М]|
| Text + TimeframeSelector                                    |
|                                                             |
|            ... candlestick chart ...                        |
|                                                             |
| [+] [-] [Fit]                          [. WS]  [*]         |
| Zoom btns                              indicator  Favorites |
+------------------------------------------------------------+
```

**Новые элементы в toolbar:**
- Индикатор WS (правый верхний) -- описан в 4.3
- Кнопка Favorites toggle `IconStar` / `IconStarFilled` (правый нижний) -- разворачивает/сворачивает панель избранных

### 4.5 Состояния графика RT

**Loading:** `Skeleton` height={400} -- заменяет весь chart.

**Disconnected overlay:**
```
+------------------------------------------------------------+
|                                                             |
|   Candlestick Chart (последние данные)                      |
|                                                             |
|   +-- Overlay полупрозрачный #1A1B1E/80% ----------------+ |
|   |                                                       | |
|   |   IconWifiOff size=48 color="#909296"                  | |
|   |   Нет подключения к серверу                            | |
|   |   Text c="dimmed"                                      | |
|   |   [Переподключить]  Button variant="outline"           | |
|   |                                                       | |
|   +-------------------------------------------------------+ |
|                                                             |
+------------------------------------------------------------+
```

**Error:** `Alert` color="red" над графиком: "Ошибка загрузки данных для SBER".

---

## 5. Навигация -- обновлённый Sidebar

### 5.1 Структура

Текущий Sidebar (`Sidebar.tsx`) уже содержит элементы "Торговля" и "Счёт". Иконки Tabler уже подключены.

```
+------------------+
|  Стратегии   [=]  |   IconChartBar
|  Графики     [~]  |   IconChartCandle
|  Бэктесты    [/]  |   IconChartLine
|  Торговля    [^]  |   IconTrendingUp      <- S5
|  Счёт        [$]  |   IconWallet          <- S5
|  Уведомления [!]  |   IconBell
|  Настройки   [*]  |   IconSettings
+------------------+
```

### 5.2 Активная подсветка

Текущая реализация использует `location.pathname === item.path` для точного совпадения.

Для S5 необходимо расширить -- вложенные маршруты должны подсвечивать родительский пункт:
- `/trading` и `/trading/sessions/:id` -- подсвечивать "Торговля"
- `/account` -- подсвечивать "Счёт"

Логика: `location.pathname.startsWith(item.path)` (с учётом `/` для корня).

### 5.3 Badge уведомлений

На элементе "Торговля" может отображаться `Badge` с количеством активных сессий:

```
  Торговля  [3]    <- Badge size="xs" color="blue" variant="filled"
```

Источник: `tradingStore.sessions.length`.

---

## 6. Компонентная карта S5

### Новые компоненты

| Компонент | Путь | Описание |
|-----------|------|----------|
| `ActiveSessionsList` | `components/trading/ActiveSessionsList.tsx` | Сетка карточек сессий |
| `SessionCard` | `components/trading/SessionCard.tsx` | Одна карточка сессии |
| `SessionDashboard` | `components/trading/SessionDashboard.tsx` | Детальный дашборд сессии |
| `LaunchSessionModal` | `components/trading/LaunchSessionModal.tsx` | Модалка запуска |
| `ConfirmRealModal` | `components/trading/ConfirmRealModal.tsx` | Подтверждение Real |
| `PositionsTable` | `components/trading/PositionsTable.tsx` | Таблица позиций |
| `TradesTable` | `components/trading/TradesTable.tsx` | Таблица сделок |
| `SessionEquityChart` | `components/trading/SessionEquityChart.tsx` | Equity curve сессии |
| `SessionStats` | `components/trading/SessionStats.tsx` | Карточки статистики |
| `AccountBalance` | `components/account/AccountBalance.tsx` | 3 карточки баланса |
| `BrokerPositions` | `components/account/BrokerPositions.tsx` | Позиции у брокера |
| `OperationsHistory` | `components/account/OperationsHistory.tsx` | История операций |
| `TaxReportModal` | `components/account/TaxReportModal.tsx` | Модалка налогового отчёта |
| `FavoritesPanel` | `components/charts/FavoritesPanel.tsx` | Панель избранных |
| `FavoriteItem` | `components/charts/FavoriteItem.tsx` | Элемент списка |
| `WsIndicator` | `components/charts/WsIndicator.tsx` | Индикатор WS |
| `TradeMarkers` | `components/charts/TradeMarkers.tsx` | Маркеры сделок (логика) |

### Новые страницы

| Страница | Путь | Маршрут |
|----------|------|---------|
| `TradingPage` | `pages/TradingPage.tsx` | `/trading` |
| `SessionDetailPage` | `pages/SessionDetailPage.tsx` | `/trading/sessions/:id` |
| `AccountPage` | `pages/AccountPage.tsx` | `/account` |

### Новые/расширенные Zustand stores

| Store | Ключевые поля |
|-------|--------------|
| `tradingStore` | `sessions`, `activeSession`, `positions`, `launch()`, `pause()`, `stop()` |
| `accountStore` | `balance`, `positions`, `operations`, `fetchBalance()`, `fetchOperations()` |
| `favoritesStore` | `items[]`, `add()`, `remove()`, `fetchStats()` |
| `marketStore` | расширение: `wsConnected`, `subscribe()`, `unsubscribe()` |

---

## 7. Сводка решений

| # | Решение | Контекст |
|---|---------|----------|
| 1 | PAPER -- жёлтый badge (`yellow.6`), REAL -- красный badge (`red.6`) | Единообразно на всех экранах |
| 2 | P&L: зелёный (`green.4`) / красный (`red.4`) / dimmed (= 0) | Наследуется из S4 |
| 3 | Favorites Panel справа от графика, 220px, сворачиваемая | По требованиям S5 |
| 4 | Клик по избранному тикеру переключает график | Быстрый доступ |
| 5 | Маркеры сделок через LWC markers API | arrowUp/arrowDown |
| 6 | WS-индикатор -- пульсирующая точка в углу графика | 3 состояния |
| 7 | Confirm-диалог для Real-торговли -- отдельная модалка | Безопасность |
| 8 | Налоговый отчёт -- модалка с выбором года, формата, типов бумаг | ФТ 18.2 |
| 9 | Sidebar: подсветка вложенных маршрутов через startsWith | Навигация |
| 10 | Секция "Брокер" в форме запуска -- только для Real | Условный рендеринг |

---

## Чеклист

- [x] Все 4 экрана с ASCII-mockups (Trading Panel, Account, Favorites, RT-графики)
- [x] Состояния: loading / empty / error / filled -- для каждого экрана
- [x] Цвета PAPER (жёлтый `yellow.6`) и REAL (красный `red.6`) -- единообразно
- [x] Формат чисел: `1 234 567,89 Р`
- [x] Mantine-компоненты указаны для каждого элемента
- [x] Навигация обновлена (Sidebar с маршрутами)
- [x] Консистентность с ui_spec_s4.md (цвета, принципы, формат)
