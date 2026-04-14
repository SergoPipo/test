# [Sprint_5_Review] Реальные позиции и операции брокерского счёта T-Invest

> Задача перенесена из Sprint 6 → Sprint_5_Review при открытии внепланового ревью 2026-04-14.
> **Исходно:** техдолг #3 Medium из S5, перенесён в S6 как задача 6.9, теперь перенесён в S5R.
> **Приоритет:** 🟡 Важно.

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
5. **Integration Verification (из `prompt_template.md`):**
   - `grep -rn "get_portfolio(" app/broker/` → результат показывает вызов из `service.py` / `router.py` (production), не только тесты
   - `grep -rn "portfolio_position_to_broker_position" app/broker/tinvest/mapper.py` → функция определена
   - `grep -rn "portfolio_position_to_broker_position" app/broker/` → функция вызывается в `service.py` или `router.py`

### Frontend

6. `PositionsTable` и `OperationsTable` уже есть — нужно только убедиться, что они корректно рендерят реальные данные (поля `source`, типы операций, валюты).
7. Учесть **множественные валюты** в позициях (USD/EUR/HKD/CNY у клиентов T-Invest бывают): балансы уже multi-currency, позиции тоже надо.
8. E2E тест: открыть «Счёт» с подключённым реальным ключом → видны позиции и история.

### Документация

9. Обновить ФТ/ТЗ — раздел «Счёт» теперь полноценный (в рамках задачи 6 S5R).
10. Удалить заглушки и комментарий «реальная интеграция в будущем» из роутов.

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
| `Develop/frontend/e2e/s5r-real-account.spec.ts` | Новый E2E |

## Связь с другими задачами

### Внутри Sprint_5_Review

| Задача | Связь |
|--------|-------|
| **Задача 1** CI cleanup | Предусловие для валидации тестов |
| **Задача 2** Live Runtime Loop | Независима по файлам, параллелится |
| **Задача 4** E2E S4 fix | Предусловие для работающего Playwright |
| **Задача 6** Актуализация ФТ/ТЗ | Финальная — раздел 7.3 обновляется |

### Cross-DEV contracts (из `execution_order.md`)

- **C8** — поставляет `GET /api/v1/broker/accounts/{id}/positions` реальную имплементацию
- **C9** — поставляет `GET /api/v1/broker/accounts/{id}/operations` реальную имплементацию

## Критерии готовности

- [ ] При подключённом production ключе T-Invest на странице «Счёт» отображаются реальные открытые позиции.
- [ ] При подключённом production ключе T-Invest на странице «Счёт» отображается реальная история операций с фильтром по датам и пагинацией.
- [ ] Позиции, открытые нашими торговыми сессиями, помечаются как `source=strategy`, остальные — `external`.
- [ ] Все unit/integration/E2E тесты проходят.
- [ ] **Integration Verification:** mapper functions вызываются из production-кода (не только из тестов)
- [ ] **Cross-DEV contracts C8, C9** подтверждены в отчёте DEV
- [ ] Документация ФТ/ТЗ обновлена (в рамках задачи 6 S5R).

## Ссылки

- Техдолг: `Спринты/project_state.md` пункт #3
- T-Invest API: `Документация по проекту/tinvest_api_services.md` раздел OperationsService
- Stack Gotchas: `Develop/CLAUDE.md` раздел «⚠️ Stack Gotchas» — особенно Gotcha 4 (T-Invest gRPC streaming, хотя здесь unary, а не streaming)
- Процессные правила: корневой `CLAUDE.md` раздел «Работа с DEV-субагентами в спринтах»
