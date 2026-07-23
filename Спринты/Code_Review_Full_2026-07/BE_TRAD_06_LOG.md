# BE-TRAD-06 — Денежный учёт paper-портфеля (Model A) — LOG

**Дата:** 2026-07-22 · **Модель:** Opus 4.8 · **Метод:** superpowers subagent-driven-development (implementer+reviewer per task, финальное whole-branch ревью), TDD Red→Green.

**Ветка (Develop / moex-terminal):** `p1/be-trad-06` от `s8r/bug-31-unified-codegen` **после мержа PR #7** (worktree, живой чекаут не тронут).
**Артефакты:** спека `docs/superpowers/specs/2026-07-09-be-trad-06-design.md`, план `docs/superpowers/plans/2026-07-22-be-trad-06.md`, репро `backend/tests/test_trading/test_paper_accounting_be_trad_06.py`.

## Контекст находки

BE-TRAD-06 — **последняя открытая P1** полного код-ревью 2026-07. Денежный учёт бумажного портфеля был сломан в трёх точках, из-за чего Circuit Breaker не ловил просадку на paper (equity не двигался):
1. paper BUY-fill не трогал `PaperPortfolio` — покупка «бесплатна»;
2. ручное/all-закрытие кредитовало выручку через `place_order(sell, quantity=лоты)` **без ×lot_size** (занижение в lot_size раз);
3. SL/TP-закрытие (`_apply_close`) портфель не трогало вообще.
Первопричина — два несовместимых прочтения `balance`/`blocked_amount` (`get_balance` считал `balance−blocked`, а CB — `balance+blocked`).

## Решение — Model A (заказчик)

`balance` = свободный кэш; `blocked_amount` = капитал открытых позиций по цене входа; `equity = balance + blocked_amount`; `available(get_balance) = balance`. BUY списывает, любое закрытие возвращает — всё с ×lot_size, через **единую точку мутации** `PaperPortfolioAccountant`. CB/AI не менялись (уже читали `balance+blocked`). Инертный T+1 нейтрализован. Альтернатива (реалистичный T+1 + mark-to-market в CB) отклонена как крупная/рискованная для CB-пути → S9.

## Реализация (7 задач + review-fixes)

| # | Что | Файлы | Коммит |
|---|---|---|---|
| 1 | `PaperPortfolioAccountant` (apply_open/apply_close, clamp underflow, peak) | `paper_engine.py` + тест | `035f817` |
| 2 | T+1 no-op (`unblock_settled_funds`), `available=balance`, удалён `_auto_unblock_if_settled` | `paper_engine.py` | `e7035eb` |
| 3 | buy-fill списывает кэш + reject при нехватке (`consecutive_fund_skips++`, откат `trades_opened`) | `engine.py` | `158caae` |
| 4 | ручное/all-закрытие: удалён paper `place_order`, кредит ×lot_size через `apply_close` | `engine.py` | `faffbbd` |
| 5 | SL/TP-закрытие: симметричный кредит портфеля в `check_sl_tp` (`_apply_close` остаётся чистым) | `risk_monitor.py` | `44db0c4` |
| 6 | капстоун-тесты: CB-drawdown реально срабатывает на paper + equity-conservation | тест | `5cc1b0e`, `c047254` |
| RF | review-fixes: quantize proceeds/cost_basis до копеек (test-first); docstring `close_all_positions`; marker dead-path `place_order` | `paper_engine.py`, `engine.py` + тест | `50f3335` |

**Согласованность (инвариант):** `cost(open) == cost_basis(close) == trade.volume_rub`; `proceeds = exit_price × volume_lots × lot_mult`, `lot_mult = RiskMonitor.derive_lot_size(trade, lot_size)` ⇒ `Δequity == trade.pnl` (после quantize — копейка-в-копейку и для облигаций).

## Ревью

- Двухстадийное task-ревью после каждой задачи (spec-compliance + code-quality) — все ✅ Approved, только Minor.
- **Финальное whole-branch ревью (Opus, `94721e8..50f3335`): вердикт «With fixes», 0 Critical.** Инвариант Δequity==pnl подтверждён трассировкой 3 файлов; place_order **мёртв для paper** (grep: только sandbox/real 1340/1799); схемных миграций нет; дублирование зачисления §4.3 — приемлемо (plan-mandated). Все actionable-Minor закрыты коммитом `50f3335`.

## Важно для деплоя (Important #1, не код-баг)

Позиции, открытые **до** деплоя BE-TRAD-06, при закрытии **после** → двойной кредит (apply_close без парного apply_open) → underflow (clamp+log.error), equity временно завышен. Paper-only, транзиентно, само-исцеляется. **Митигация:** перед деплоем закрыть/сбросить открытые paper-сессии — см. `Документация по проекту/deployment_guide.md` §7 (разовая процедура). Underflow-clamp+`log.error("paper_blocked_amount_underflow")` — страховочный сигнал.

## Гейт приёмки (Definition of Done) — ✅

- `test_paper_buy_debits_free_cash`: xfail → обычный **passed** (xfail снят).
- `pytest tests/test_trading` — **0 failed**; регресс `tests/test_circuit_breaker + tests/test_trading` = **327 passed, 0 failed**.
- `ruff check` + `py_compile` по 3 прод-файлам — чисто; 0 новых pyright-ошибок (одна `Decimal|None` в тесте закрыта narrowing'ом).
- **CB-drawdown на paper реально срабатывает** (equity отражает списанный balance) — `test_cb_drawdown_triggers_on_paper`.
- Финальное whole-branch ревью пройдено, actionable-находки закрыты test-first.

## Backlog (defer → S9 / техдолг)

- `order.placed` публикуется до reject-проверки → rejected buy шлёт `order.placed` потом `order.error` (косметика UI-фида).
- `portfolio is None` в обеих close-точках молча пропускает кредит без log (pre-existing pattern).
- `_check_max_drawdown` не проверяет ownership по `user_id` (pre-existing prod).
- Мёртвый `PaperBrokerAdapter.place_order` (формула `balance−blocked`) и мёртвый `scheduler.schedule_t1_unlock` — помечены, удаление отдельным техдолгом (спека §8).
- Реалистичная T+1-модель + mark-to-market drawdown в CB — S9 (out of scope Model A).
