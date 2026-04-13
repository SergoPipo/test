# [Sprint 6] Реальные позиции и операции брокерского счёта T-Invest

> Задача перенесена из Sprint 5 (правка раздела «Счёт»). В Sprint 5 реализованы только балансы реального счёта; позиции и операции остались как заглушки и должны быть доделаны в Sprint 6.

## Контекст

В Sprint 5 раздел «Счёт» был перестроен под работу с **реальными** брокерскими счетами T-Invest:
- модель данных «один счёт T-Invest = одна запись `BrokerAccount`» с заполненным `account_id`;
- селектор счёта в `AccountPage` (если у пользователя их несколько внутри одного API-ключа);
- балансы (`GET /broker/accounts/balances`) реализованы через `OperationsService.GetPortfolio` (адаптер `TInvestAdapter.get_balance`).

Позиции и операции на этот момент **остались заглушками** в [broker/router.py:113-134](../../Develop/backend/app/broker/router.py#L113-L134):
- `GET /broker/accounts/{id}/positions` → `return []`
- `GET /broker/accounts/{id}/operations` → `return {"items": [], "total": 0}`

Адаптер T-Invest уже умеет получать портфель и операции (`OperationsService.GetPortfolio` / `GetOperations`), но маппинг и роуты не подключены.

## Что нужно сделать

### Backend
1. Реализовать **реальные позиции** через `client.operations.get_portfolio(account_id)`:
   - распарсить `positions` (FIGI → ticker, текущая цена, средняя, количество, накопленный P&L);
   - различить `source: 'strategy' | 'external'` (по наличию связанных `Order` в нашей БД для данного `account_id` + `ticker`);
   - вернуть в формате `BrokerPosition[]`.
2. Реализовать **реальные операции** через `client.operations.get_operations(account_id, from, to)`:
   - маппинг типов: `BUY/SELL/DIVIDEND/COUPON/COMMISSION/TAX`;
   - фильтр по `from`/`to`;
   - пагинация (`offset`/`limit`) на стороне сервиса (T-Invest возвращает массив целиком — режем в Python);
   - вернуть `{ items: BrokerOperation[], total: number }`.
3. Расширить `TInvestMapper` функциями `portfolio_position_to_broker_position` и `operation_to_broker_operation`.
4. Тесты: unit на маппер + интеграционный на роуты с моком адаптера.

### Frontend
5. `PositionsTable` и `OperationsTable` уже есть — нужно только убедиться, что они корректно рендерят реальные данные (поля `source`, типы операций, валюты).
6. Учесть **множественные валюты** в позициях (USD/EUR/HKD/CNY у клиентов T-Invest бывают): балансы уже multi-currency, позиции тоже надо.
7. E2E тест: открыть «Счёт» с подключённым реальным ключом → видны позиции и история.

### Документация
8. Обновить ФТ/ТЗ — раздел «Счёт» теперь полноценный.
9. Удалить заглушки и комментарий «реальная интеграция в будущем» из роутов.

## Файлы, которые затронет задача

| Файл | Изменение |
|------|-----------|
| `Develop/backend/app/broker/router.py` | Реальные позиции и операции вместо заглушек |
| `Develop/backend/app/broker/service.py` | Методы `get_positions(account_id, user_id)`, `get_operations(...)` |
| `Develop/backend/app/broker/tinvest/adapter.py` | Использовать существующий `client.operations.*` |
| `Develop/backend/app/broker/tinvest/mapper.py` | Новые функции маппинга |
| `Develop/backend/tests/broker/...` | Unit + интеграция |
| `Develop/frontend/src/components/account/PositionsTable.tsx` | Проверить рендер реальных полей |
| `Develop/frontend/src/components/account/OperationsTable.tsx` | Поддержка типов операций T-Invest |
| `Develop/frontend/e2e/s6-real-account.spec.ts` | Новый E2E |

## Критерии готовности

- [ ] При подключённом production ключе T-Invest на странице «Счёт» отображаются реальные открытые позиции.
- [ ] При подключённом production ключе T-Invest на странице «Счёт» отображается реальная история операций с фильтром по датам и пагинацией.
- [ ] Позиции, открытые нашими торговыми сессиями, помечаются как `source=strategy`, остальные — `external`.
- [ ] Все unit/integration/E2E тесты проходят.
- [ ] Документация ФТ/ТЗ обновлена.
