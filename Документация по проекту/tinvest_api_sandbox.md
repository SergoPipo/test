# T-Invest API — Sandbox (Песочница)

> Источник: [GitHub: RussianInvestments/investAPI](https://github.com/RussianInvestments/investAPI/blob/main/src/docs/sandbox.md), FAQ
>
> Дата фиксации: 2026-03-26

---

## Что такое Sandbox

Эмулятор торгов, в котором можно проверить торговый алгоритм, **не выводя поручения на биржу и не рискуя реальными деньгами**. Использует **реальные биржевые данные** (котировки, свечи, стаканы).

---

## Ключевые отличия от Production

| Аспект | Production | Sandbox |
|--------|-----------|---------|
| **Эндпоинт** | `invest-public-api.tbank.ru:443` | `sandbox-invest-public-api.tbank.ru:443` |
| **Токен** | Выпускается отдельно (readonly / full-access) | Выпускается отдельно как «токен для песочницы» |
| **Деньги** | Реальные | Виртуальные (через `SandboxPayIn`) |
| **Рыночные данные** | Реальные | Реальные (те же данные) |
| **Исполнение ордеров** | Биржевое | Эмулированное (по данным последних сделок) |
| **Средняя цена покупки** | Рассчитывается | **Не рассчитывается** |
| **Шорты** | Полноценные (маржа, блокировки) | Эмулированные (баланс просто уходит в минус) |
| **Маржинальные показатели** | Рассчитываются | **Не рассчитываются** |
| **Маржинколл** | Срабатывает | **Нет** |
| **Отрицательный баланс** | Недопустим | **Допускается** без последствий |
| **Хранение данных** | Постоянное | **Не гарантируется** (счёт может пропасть) |
| **Лимит запросов** | По сервисам (см. overview) | **200 запросов/минуту** (общий) |

---

## Токены: Sandbox vs Production

**Sandbox-токен и production-токен — это РАЗНЫЕ токены**, выпускаемые отдельно:

- При создании токена в личном кабинете Т-Инвестиций выбирается тип: «для биржи» или «для песочницы»
- **Один токен НЕ может использоваться для обоих режимов**
- Формат токенов одинаковый (непрозрачная строка), различить визуально невозможно

### Программная детекция типа токена

Прямого API-метода для определения типа токена **нет**. Подход:

```
1. Попытка вызова GetAccounts() через production-эндпоинт
   ├── Успех → production-токен
   └── Ошибка авторизации →
       2. Попытка вызова GetSandboxAccounts() через sandbox-эндпоинт
          ├── Успех → sandbox-токен
          └── Ошибка → невалидный токен
```

---

## Работа с Sandbox

### Создание счёта

```
OpenSandboxAccount → возвращает account_id
```

Можно создать несколько sandbox-счетов.

### Пополнение виртуального баланса

```
SandboxPayIn(account_id, amount: MoneyValue)
```

`MoneyValue` содержит: ISO-код валюты, целую часть (units), дробную часть (nano).

### Исполнение заявок

Система базируется на данных последних биржевых сделок:
- **Лимитные ордера**: не исполняются при отсутствии цены
- **Рыночные ордера**: не исполняются при низкой ликвидности

### Закрытие счёта

```
CloseSandboxAccount(account_id)
```

---

## Доступные методы SandboxService (20)

### Управление счётом
| Метод | Аналог в Production |
|-------|---------------------|
| OpenSandboxAccount | — (нет аналога) |
| CloseSandboxAccount | — (нет аналога) |
| SandboxPayIn | PayIn (UsersService) |
| GetSandboxAccounts | GetAccounts (UsersService) |

### Торговые заявки
| Метод | Аналог в Production |
|-------|---------------------|
| PostSandboxOrder | PostOrder (OrdersService) |
| PostSandboxOrderAsync | PostOrderAsync (OrdersService) |
| ReplaceSandboxOrder | ReplaceOrder (OrdersService) |
| CancelSandboxOrder | CancelOrder (OrdersService) |
| GetSandboxOrders | GetOrders (OrdersService) |
| GetSandboxOrderState | GetOrderState (OrdersService) |
| GetSandboxOrderPrice | GetOrderPrice (OrdersService) |
| GetSandboxMaxLots | GetMaxLots (OrdersService) |

### Стоп-заявки
| Метод | Аналог в Production |
|-------|---------------------|
| PostSandboxStopOrder | PostStopOrder (StopOrdersService) |
| GetSandboxStopOrders | GetStopOrders (StopOrdersService) |
| CancelSandboxStopOrder | CancelStopOrder (StopOrdersService) |

### Портфель и операции
| Метод | Аналог в Production |
|-------|---------------------|
| GetSandboxPortfolio | GetPortfolio (OperationsService) |
| GetSandboxPositions | GetPositions (OperationsService) |
| GetSandboxOperations | GetOperations (OperationsService) |
| GetSandboxOperationsByCursor | GetOperationsByCursor (OperationsService) |
| GetSandboxWithdrawLimits | GetWithdrawLimits (OperationsService) |

---

## Что НЕ доступно в Sandbox

Следующие сервисы работают **только через production-эндпоинт**:

- **MarketDataService** — котировки и история (sandbox не имеет своих методов для этого; рыночные данные берутся через production-эндпоинт или SDK автоматически маршрутизирует)
- **MarketDataStreamService** — стримы котировок
- **InstrumentsService** — справочник инструментов
- **OperationsStreamService** — стримы портфеля/позиций
- **OrdersStreamService** — стримы исполнения
- **SignalService** — сигналы

> **Важно для реализации**: при работе в sandbox-режиме для получения рыночных данных (свечи, стаканы, котировки) необходимо обращаться к production-эндпоинту или использовать MOEX ISS как fallback.

---

## FAQ

**Счёт пропал?**
Создайте новый. Долгосрочное хранение sandbox-счетов не гарантируется.

**Как узнать доступный остаток?**
Метод `GetSandboxWithdrawLimits`.

**Как изменить заявку?**
Метод `ReplaceSandboxOrder` — отменяет старую и создаёт новую.

**Можно ли торговать в шорт?**
Шорты эмулируются, но без учёта затрат на маржинальное кредитование — баланс просто уходит в минус.

---

## Использование в MOEX Terminal

### Текущая реализация (Sprint 1-2)
- Глобальная настройка `TINVEST_SANDBOX` в config.py
- Один режим на всё приложение

### Целевая реализация (задача #4)
- `is_sandbox` на уровне `BrokerAccount` (per-account)
- Автодетекция типа токена при подключении
- Адаптер подключается к нужному эндпоинту автоматически
- Для рыночных данных: приоритет production-аккаунта, fallback на MOEX ISS
