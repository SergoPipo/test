# BE-TRAD-06 — Согласованный денежный учёт paper-портфеля (Model A)

**Дата:** 2026-07-09
**Автор:** Claude (Opus 4.8) + заказчик (brainstorm)
**Статус находки:** P1, единственная открытая по итогам полного код-ревью 2026-07 (`Спринты/Code_Review_Full_2026-07/backlog_fixes.md`, запись BE-TRAD-06).
**Исполняемая спецификация (стартовый репро):** `Develop/backend/tests/test_trading/test_paper_accounting_be_trad_06.py`
**Ветка:** `p1/be-trad-06` от `s8r/bug-31-unified-codegen` **после** мержа PR #7 (git worktree, не живой чекаут Develop).

---

## 1. Контекст и первопричина

Денежный учёт бумажного (paper) портфеля сломан в трёх точках, а глубинная причина — **два несовместимых прочтения полей `PaperPortfolio.balance` / `blocked_amount`**, размазанных по коду.

### 1.1. Три сломанные точки (подтверждены по коду)

| # | Точка | Файл | Дефект |
|---|---|---|---|
| 1 | paper buy-fill | `app/trading/engine.py:1123-1149` | ставит `status='filled'` / `entry_price` / `filled_lots`, но **не трогает `PaperPortfolio`** — покупка «бесплатна» (средства не списываются и не блокируются). |
| 2 | manual / all-close | `app/trading/engine.py:1732-1746` | кредитует выручку через `place_order(sell, quantity=filled_lots)` — **quantity в ЛОТАХ без `×lot_size`** → выручка занижена в `lot_size` раз (для SBER/GAZP это ×10). |
| 3 | SL/TP-close | `app/trading/risk_monitor.py:391-459` (`_apply_close`) | считает PnL сделки, но **портфель не трогает вообще** — закрытие по стопу/тейку «бесплатно». |

### 1.2. Первопричина: два прочтения одних полей

| Потребитель | Формула | Неявный смысл `balance` |
|---|---|---|
| `PaperBrokerAdapter.get_balance.available` (`paper_engine.py:74`) | `balance − blocked_amount` | `balance` = ВСЁ (свободное + заблокированное) |
| CB `_check_max_drawdown` (`circuit_breaker/engine.py:292`), CB-статус (`circuit_breaker/service.py:161`), AI-контекст (`ai/slash_context.py:212,265`) | `balance + blocked_amount` | `balance` = только СВОБОДНОЕ |

Обе формулы одновременно верными быть не могут. Пока покупка не трогает портфель, это неважно (значения — фикция). Но `PaperPortfolio.balance/blocked_amount/peak_equity` — вход для расчёта equity/drawdown в Circuit Breaker (`equity = balance + blocked_amount`), поэтому **защита по просадке на paper фактически не работает** (equity не двигается — просадки не видно).

### 1.3. Статус T+1

- `scheduler.schedule_t1_unlock` / `_execute_t1_unlock` — **мёртвый код**: `schedule_t1_unlock(` нигде не вызывается (подтверждено grep; совпадает с находкой BE-RT-11).
- `unblock_settled_funds` / `_auto_unblock_if_settled` срабатывают только внутри `get_balance` / `place_order` по порогу «прошло ≥24ч от `updated_at`». Но `PaperPortfolio.updated_at` имеет `onupdate=func.now()` и обновляется на **каждой** записи портфеля, поэтому при активной торговле порог практически не наступает.
- `paper_engine.py:284` `balance -= blocked_amount` (в `unblock_settled_funds`) — часть этой (инертной) T+1-механики.
- Фронтенд `blocked_amount` / `peak_equity` **не отображает** (проверено grep по `Develop/frontend/src`) — переосмысление `blocked_amount` не ломает UI-семантику.

### 1.4. Связанные инертные механизмы

- `TradingSession.consecutive_fund_skips` + CB `_check_insufficient_funds_streak` (пауза сессии при `≥3` подряд) существуют, но поле **нигде не инкрементируется** — механизм инертен. Фикс buy-fill естественно его активирует (см. §4.1).
- `PositionTracker.on_order_filled` (`engine.py:2108`) содержит «правильную по духу» мутацию портфеля (`balance-=cost; blocked+=cost`), но это **мёртвый код** (находка BE-TRAD-13) и он тоже без `×lot_size`. Не используем как источник; переносим корректную логику в единый accountant.

---

## 2. Решение: Model A (упрощённая когерентная)

Выбрана заказчиком из двух вариантов (альтернатива — реалистичная T+1 + рыночная переоценка в CB — отклонена как крупная и рискованная для критического CB-пути; см. §8).

### 2.1. Инвариант модели

| Поле | Смысл после фикса |
|---|---|
| `balance` | **свободный кэш** — доступен под новые ордера немедленно |
| `blocked_amount` | **капитал в открытых позициях по цене входа** = Σ (`entry_price × lots × lot_size`) по открытым сделкам сессии |
| `equity` (для CB / AI) | `balance + blocked_amount` — оценка портфеля по **цене входа** (cost basis) |
| `available` (`get_balance`) | `balance` (свободный кэш) |
| `peak_equity` | максимум `equity` за жизнь портфеля; растёт при закрытии в плюс |

### 2.2. Ключевые следствия

- **Покупка не создаёт просадку.** BUY: `balance−=cost`, `blocked+=cost` → `equity` неизменно. Корректно: кэш конвертирован в позицию по той же стоимости.
- **Просадка = реализованный убыток.** При закрытии (ручном / SL / TP): `balance+=proceeds`, `blocked−=cost_basis` → `Δequity = proceeds − cost_basis = realized PnL`. Убыток опускает equity ниже peak → CB ловит просадку.
- **Нереализованная просадка НЕ отслеживается** (позиции оцениваются по входу, не по рынку). Это сознательное упрощение Model A; для paper приемлемо, т.к. SL/TP реализуют убыток при срабатывании, и накопленная реализованная просадка триггерит CB.
- **CB `_check_max_drawdown`, CB-статус и AI-контекст НЕ меняются** — они уже читают `balance + blocked_amount`, что под Model A корректно. Восстановление CB-drawdown достигается тем, что поля перестают быть фикцией и реально двигаются.

---

## 3. Единая точка мутации — `PaperPortfolioAccountant`

Чтобы три точки не разошлись, вся денежная мутация идёт через один хелпер (модуль `app/trading/paper_engine.py` — рядом с портфелем; финальное размещение/имя уточняется в плане, инвариант неизменен).

```
apply_open(portfolio, cost):
    portfolio.balance        -= cost
    portfolio.blocked_amount += cost

apply_close(portfolio, proceeds, cost_basis):
    portfolio.balance        += proceeds
    portfolio.blocked_amount -= cost_basis
    if portfolio.blocked_amount < 0:          # рассинхрон — не должно случаться
        log.error(...); portfolio.blocked_amount = 0
    equity = portfolio.balance + portfolio.blocked_amount
    if equity > portfolio.peak_equity:
        portfolio.peak_equity = equity
```

**Согласованность величин (критично для инварианта `Δequity == realized PnL`):**
- `cost` при открытии и `cost_basis` при закрытии — это **одно и то же** `trade.volume_rub` (= `entry_signal_price × volume_lots × lot_size`, пишется в `process_signal` на строке `engine.py:1089`). Использование одного источника гарантирует, что `blocked` вернётся ровно к прежнему уровню.
- `proceeds = exit_price × lots × lot_size` — вычисляется теми же `exit_price` и `lot_size`, что `RiskMonitor._apply_close` использует для PnL, чтобы `Δequity` совпало с `trade.pnl` копейка-в-копейку.
- `lot_size` при закрытии деривируется так же, как в `_apply_close`: `RiskMonitor.derive_lot_size(trade, fallback=lot_size)` (авторитетный множитель из `volume_rub`, без ре-фетча).
- **Slippage не вводим на denежном пути.** Δequity привязан к `trade.pnl` (без slippage). Существующий slippage в `place_order` не переиспользуется, т.к. `place_order` на денежном пути закрытия заменяется прямым `apply_close` (см. §4.2).

**Легаси-гард:** если `trade.volume_rub` = NULL (старые записи), `cost_basis` пересчитывается как `entry_price × lots × derived_lot_size`; при невозможности — 0 с `log.warning` (портфель не корёжим).

---

## 4. Изменения по трём точкам

### 4.1. Точка 1 — buy-fill (`engine.py:1123`, ветка `session.mode == "paper"`)

После установки `filled` / `entry_price` / `filled_lots` (перед финальным commit блока):

1. Загрузить `PaperPortfolio` сессии.
2. `cost = trade.volume_rub`.
3. **Проверка достаточности:** если `cost > portfolio.balance` (свободного кэша не хватает):
   - **не** ставить `filled`; на уже существующей (созданной выше как `pending`) сделке выставить `status='rejected'`, `closed_at=now` — строку сохраняем как audit-след, портфель не трогаем;
   - откатить преждевременный учёт открытия: `DailyStat.trades_opened` инкрементируется на строке `engine.py:1095` **до** этой ветки, поэтому отклонённый fill не должен считаться открытым — либо декрементировать `trades_opened`, либо перенести инкремент `trades_opened` за проверку достаточности (выбор — в плане; инвариант: rejected-fill не увеличивает `trades_opened`);
   - опубликовать `order.error` с причиной «недостаточно свободных средств»;
   - `session.consecutive_fund_skips += 1` (активирует существующую CB-проверку `_check_insufficient_funds_streak` → пауза при 3 подряд);
   - вернуть не открытую (`rejected`) сделку.
4. Иначе — `apply_open(portfolio, cost)` и **сбросить** `session.consecutive_fund_skips = 0`.

> Обработка нехватки средств обязательна: без неё, как только buy начинает списывать, `balance` может уйти в минус. Инкремент `consecutive_fund_skips` — переиспользование существующего поля и CB-проверки, не новая сущность.

### 4.2. Точка 2 — manual / all-close (`engine.py:1732`, paper-ветка `close_position`)

- **Удалить** вызов `broker.place_order(account_id="paper", direction=close_direction, quantity=trade.filled_lots or trade.volume_lots, price=exit_price)` — источник бага #2 (лоты без `×lot_size` + чужая денежная модель + двойной slippage).
- Вместо него, после `RiskMonitor._apply_close(trade, exit_price, reason, lot_size)` (который уже посчитал `trade.pnl` и деривировал множитель), для paper-сессии:
  - `lot_mult = RiskMonitor.derive_lot_size(trade, lot_size)`
  - `proceeds = exit_price × trade.volume_lots × lot_mult`
  - `cost_basis = trade.volume_rub` (легаси-гард по §3)
  - `apply_close(portfolio, proceeds, cost_basis)`
- `close_all_positions` (`engine.py:1891`) идёт через `close_position` для каждой позиции — **чинится автоматически**, отдельных правок не требует.

### 4.3. Точка 3 — SL/TP-close (`risk_monitor.py`, `check_sl_tp`)

- `RiskMonitor._apply_close` остаётся **чистым** (мутирует только поля `trade`, без денег) — он общий для SL/TP и ручного закрытия, дублировать мутацию портфеля в нём нельзя.
- Денежное зачисление добавляется на уровне вызывающего `check_sl_tp` (симметрично тому, что делает `close_position`): для каждой **реально закрытой** (`status='closed'`) сделки paper-сессии после `_apply_close` вызвать `apply_close(portfolio, proceeds, cost_basis)` теми же формулами, что §4.2 (внутри уже известны `session`, `lot_size`, `trade.exit_price`, `trade.volume_rub`).
- `cancelled`-сделки (pending без реального входа, `entry<=0`) портфель **не трогают** — для них не было `apply_open` (`cost_basis=0`). В paper fill мгновенный, поэтому в норме таких нет; гард — на всякий случай.
- Зачисление — до `self.db.commit()` в `check_sl_tp`, в той же транзакции, что и закрытие сделок.

---

## 5. T+1 — нейтрализация (§ решения заказчика)

Под Model A `blocked_amount` = капитал позиции, поэтому старая T+1-разблокировка (`balance -= blocked_amount`) **уничтожила бы капитал открытой позиции**. Поскольку T+1-планировщик и так мёртв (§1.3):

- `PaperBrokerAdapter.unblock_settled_funds` → **no-op с `log.warning("paper_t1_unblock_deprecated")`** (не трогает `balance` / `blocked_amount`). Защита от воскрешения мёртвого `scheduler._execute_t1_unlock`.
- Убрать вызовы `_auto_unblock_if_settled(portfolio)` из `get_balance` (`paper_engine.py:73`) и `place_order` (`paper_engine.py:140`). Сам `_auto_unblock_if_settled` может быть удалён или оставлен неиспользуемым (уточняется в плане; поведение — не мутировать портфель).
- `get_balance.available`: `max(0, balance − blocked_amount)` → `max(0, balance)` (свободный кэш под Model A).

`scheduler.schedule_t1_unlock` / `_execute_t1_unlock` (вне `app/trading/`) остаются мёртвыми; трогать их в рамках этого фикса не обязательно (no-op `unblock_settled_funds` делает их безвредными). Явно out-of-scope — см. §8.

---

## 6. Тесты (TDD, Red→Green)

Расширяем `Develop/backend/tests/test_trading/test_paper_accounting_be_trad_06.py`. `lot_size` в тестах — через монкипатч `MarketDataService.ensure_lot_size` / `ensure_lot_size_strict` → `10` (реальный лот SBER), чтобы `×lot_size` действительно проверялся.

| Тест | Проверяет | Репро дефекта |
|---|---|---|
| `test_paper_buy_debits_free_cash` | снять `@pytest.mark.xfail` → **XPASS**: после BUY `balance` уменьшился на `cost` | #1 |
| `test_paper_buy_blocks_capital` | `blocked_amount == entry×lots×lot_size`; `equity` (balance+blocked) == initial; `available == balance` | #1 |
| `test_manual_close_credits_with_lot_size` | после close: `balance += exit×lots×lot_size`; `blocked→0`; `Δequity == trade.pnl` (именно `×lot_size`) | #2 |
| `test_sltp_close_credits_portfolio` | `RiskMonitor.check_sl_tp` закрыл по SL → портфель кредитован, `blocked→0`, `equity` упало на убыток | #3 |
| `test_close_all_positions_accounting` | несколько позиций → close_all → `balance`/`blocked` согласованы | #2 |
| `test_cb_drawdown_triggers_on_paper` | открыть+закрыть в убыток так, что `equity < peak − limit` → `CircuitBreakerEngine._check_max_drawdown` возвращает `blocked=True` | CB |
| `test_equity_conservation` | `equity == initial + Σ realized_pnl(closed)`; `blocked == Σ cost(open)` | инвариант |
| `test_insufficient_funds_rejects_and_skips` | BUY при `cost > balance` → сделка не открыта, `order.error`, `consecutive_fund_skips += 1` | §4.1 |
| `test_t1_unblock_is_noop` | `unblock_settled_funds()` не меняет `balance`/`blocked_amount` | §5 |

---

## 7. Гейты приёмки (Definition of Done)

- `test_paper_buy_debits_free_cash`: `xfail` → **XPASS**; новые тесты 3 точек + T+1 + CB — **зелёные**.
- `cd Develop/backend && .venv/bin/python -m pytest tests/test_trading -q` — **0 failed** (+ регресс модуля не сломан).
- `pyright` (pyright-lsp diagnostic после каждого Edit; fallback `py_compile`) — **0 новых** ошибок в затронутых файлах.
- **CB-drawdown на paper реально срабатывает** (equity отражает списанный `balance`).
- `/code-review` по `app/trading/` (критический путь) — пройден, найденные дефекты закрыты test-first.
- Запись в `changelog.md` текущего цикла приёмки + обновление `Спринты/project_state.md` (BE-TRAD-06 закрыт).

---

## 8. Границы (out of scope)

- **Реалистичная T+1-модель** (реальная блокировка средств на день + рыночная переоценка позиций в CB) — отклонена; фиксируем упрощённую Model A. При необходимости — отдельная задача развития (S9), но НЕ в этом цикле.
- **Нереализованная (mark-to-market) просадка** в CB — вне Model A.
- Мёртвый `scheduler.schedule_t1_unlock` / `_execute_t1_unlock` и мёртвый `PositionTracker` (BE-TRAD-13) — не удаляем в рамках этого фикса (отдельный техдолг); `unblock_settled_funds`=no-op делает первый безвредным.
- Ре-архитектура `place_order` под общий контракт брокера — не трогаем сверх необходимого (только уводим денежный путь закрытия с него).

## 9. Затрагиваемые файлы

| Файл | Изменение |
|---|---|
| `Develop/backend/app/trading/paper_engine.py` | `PaperPortfolioAccountant` (apply_open/apply_close); `get_balance.available=balance`; `unblock_settled_funds`→no-op; убрать `_auto_unblock` из hot-path |
| `Develop/backend/app/trading/engine.py` | `process_signal` paper buy-fill (§4.1); `close_position` paper (§4.2) |
| `Develop/backend/app/trading/risk_monitor.py` | `check_sl_tp` — денежное зачисление для paper (§4.3) |
| `Develop/backend/tests/test_trading/test_paper_accounting_be_trad_06.py` | расширение до полной спецификации (§6) |

CB (`circuit_breaker/engine.py`, `service.py`) и AI (`ai/slash_context.py`) — **без изменений** (уже читают `balance + blocked_amount`).
