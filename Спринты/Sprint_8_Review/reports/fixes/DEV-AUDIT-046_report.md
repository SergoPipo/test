## DEV-AUDIT-046 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (worktree `s8r/fix-medium` @ 9b06c0a, ничего не закоммичено). Ревью р.2: исправлены пункты 1–4.

### 1. Что реализовано
- `get_balance`: `GetPortfolio` и `GetPositions` читаются параллельно (`asyncio.gather`), у каждого свой `_read_with_retry` (р.2 п.2).
- Разбор денег один — `TInvestMapper.rub_money_sum`. Его используют и `get_available_cash` (сайзинг 027), и баланс. Баланс читает позиции свежим запросом: кэш 027 и резерв под ордер он не читает и не пишет (р.2 п.1).
- Сбой только `GetPositions` не обнуляет баланс: `total` и `in_positions` остаются, а `available` и `blocked` = `None`. Во фронте это «—», в Telegram — «нет данных» (р.2 п.3).
- Новое поле `in_positions` = `max(total_amount_portfolio − total_amount_currencies, 0)`, считает его одна функция `TInvestMapper.portfolio_in_positions`. `blocked` снова означает рубли, заблокированные под заявки (`GetPositions.blocked`). `BalanceCards` и Telegram `/balance` берут `in_positions` из адаптера, `total − available` больше нигде не считается. testid карточки → `balance-in-positions`, e2e `s5-account.spec.ts:70` и `api_mocks.ts` обновлены (р.2 п.4).
- `BrokerBalance`/`AccountBalance`: суммы `Decimal` (в JSON — строки), `available`/`blocked`/`in_positions` могут быть `None`.

### 2. Файлы
- Новый: `backend/tests/unit/test_broker/test_balance_available.py`.
- Изменённые: `backend/app/broker/{base.py, schemas.py, router.py, tinvest/adapter.py, tinvest/mapper.py}`, `backend/app/notification/telegram_webhook.py`; `frontend/src/api/types.ts`, `frontend/src/components/account/BalanceCards.tsx`, `frontend/e2e/{s5-account.spec.ts, fixtures/api_mocks.ts}`.
- Тесты под новый контракт: `test_adapter_full.py`, `test_sandbox_flaky_70001.py`, два `test_broker_router.py`, `test_telegram_webhook.py` (+2 теста), `BalanceCards.test.tsx`, `AccountPage.test.tsx`.

### 3. Тесты
- RED (р.1): `AssertionError: assert Decimal('1000000') == Decimal('100000')`; `('total', 12345678.12345679)` — пришёл float.
- GREEN: 10/10 в `test_balance_available.py`: свободный кэш, blocked, общий разбор, резерв игнорируется, параллельность, частичный сбой, USD без бумаг → `in_positions` 0, шорт без минуса, HTTP с Decimal-строками, HTTP с `null`. Telegram 2/2 (шорт, нет данных). vitest своих файлов 30/30.
- Мутация р.2 «баланс из кэша с резервом» → `AssertionError: assert Decimal('40000') == Decimal('100000')`. Откат через бэкап, md5 совпал.
- Гейты: pytest **4189 passed / 3 xfailed / 1 failed**. Упал `test_runtime.py::TestSignalToOrderFullMetric::test_existing_metric_is_blind_to_cb_wait` — тайминг `301 мс < 150`, под нагрузкой параллельного прогона; отдельно 3×3 passed. ruff 0; mypy Success (191); bandit без находок; typecheck 0; lint 0; build ok; e2e-файлы проходят проверку типов `tsc --strict`.

### 4. Integration points
✅ `router.py` `/balances` и `telegram_webhook.py` `_handle_balance` получают баланс через `get_balance`; `get_available_cash` → `rub_money_sum`. NOT CONNECTED нет.

### 5. Контракты
`BrokerBalance`: `total: string`, `available/blocked/in_positions: string | null` (типы в `api/types.ts` сходятся со схемой). При полном сбое брокера — нули, как было. Миграции нет.

### 6. Проблемы / предложения / находки
- **ФТ §7.3**, первый пункт «Экрана «Счёт»», предлагаю заменить на: «Текущий баланс по каждому подключённому брокерскому счёту: *всего* — оценка портфеля (бумаги + деньги); *доступно* — свободные рубли счёта без заблокированного под заявки; *в позициях* — стоимость бумаг без денежных позиций (не отрицательна). Если брокер не отдал денежные позиции, «доступно» показывается как «—» («нет данных»), остальное — как есть. Валютные деньги (USD/CNY) в «доступно» и «в позициях» не входят.» Та же разбивка — для Telegram `/balance`.
- **ТЗ**: контракт `GET /broker/accounts/balances` — суммы строками Decimal, `available/blocked` могут быть `null`, добавлено `in_positions`.
- Поле `blocked` отдаётся, но отдельной карточкой не показано (в ФТ есть «заблокированные») — нужно решение, добавлять ли четвёртую карточку.
- У шорта `in_positions` = 0: стоимость короткой позиции нигде не видна.
- Dashboard `BalanceWidget` показывает историю `total_value`, а не брокерский баланс — вне карточки.
- Самопроверка: 1–2 н/п; 3 — через `_read_with_retry`/`_unary`, мокается только SDK, путь сайзинга 027 — тестом; 4 — отмена не глотается (не-`Exception` пробрасывается); 5 — оба вызывающих проверены; 6 н/п.

### 7. Применённые Stack Gotchas
01, 56, 48 (диагностика зависания в р.1).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile + mypy; `pnpm typecheck` (`tsc -b`); поля `PortfolioResponse`/`PositionsResponse` сверены по SDK `schemas.py` (context7 не понадобился); скилл `mattpocock-skills:tdd`.
