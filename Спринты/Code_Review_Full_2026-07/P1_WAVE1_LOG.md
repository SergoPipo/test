# Лог P1 — Волна 1 (backend: trading / market-data / backtest / strategy)

**Дата:** 2026-07-06
**Ветка:** `s8r/bug-31-unified-codegen` (Develop/, → origin `moex-terminal`, push `1107ec3..a936e1a`)
**Модель фиксов:** Opus 4.8, оркестрация — Fable 5. Строго test-first (Red→Green→Refactor).
**Метод:** 4 DEV-агента в изолированных git-worktree'ах (base = P0-ветка), затем integration-мерж + полный gate + `/code-review` по trading + фикс найденных дефектов + повторный gate.

## Реализовано (18 High)

| Ветка | Пункты | Тесты |
|---|---|---|
| `be-trading` | BE-TRAD-03, 04, 05, 07, 08, 09 | 220 passed |
| `be-market-data` | BE-MKT-01, 02, 03, 04, 05 | 160 passed |
| `be-backtest` | BE-BTST-01, 02, 04 + AUTHZ-04/BE-BTST-03 (WS-authz) | 315 passed |
| `be-strategy` | BE-STRAT-03, 04, BE-STRAT-02 (частично) | 322 passed |

**Дубли P0 (не делались):** BE-TRAD-10=AUTHZ-02, BE-TRAD-11=AUTHZ-03 (=C2), AUTHZ-05 (=C1), AUTHZ-06/CFG-BE-02 (=C3).

## `/code-review` по trading (xhigh, 5 углов A–E + верификация)

Выявил **9 находок в свежих фиксах**; 2 High были money-критичны и означали, что фикс работает не так, как заявлено. Все исправлены отдельным test-first проходом (`review-followup`, commit `a936e1a`):

- **FIX-1** (BE-TRAD-09 был неэффективен: `ensure_lot_size` никогда не бросает → try/except мёртв → ×10 оставался): добавлен `ensure_lot_size_strict` (бросает `LotSizeUnavailableError` при неавторитетном lot_size); `process_signal` на entry-sizing использует строгий → сигнал пропускается, а не торгует на lot_size=1.
- **FIX-2** (фантомное закрытие real-позиции при `figi=None` в reconcile): reconcile пропускает figi-пустые сделки (warning), не закрывает и не паузит; хардкод `exit_price=0` убран.
- **FIX-3** (cooldown глушил exit): exit-детект поднят выше cooldown-гейта; cooldown только для entry; exit не бумпит `last_signal_at`.
- **FIX-4** (lot_size=1 на выходах → ×10 занижение PnL): множитель закрытия деривируется из сохранённого `volume_rub` входа (`derive_lot_size`), без ре-фетча; молчаливый `except: lot_size=1` заменён логированием.
- **FIX-5** (`_apply_close` при entry≤0 ставил 'closed'): теперь 'cancelled', исключён из DailyStat.trades_closed.
- **FIX-7/8** (закрывалась одна встречная позиция при max_concurrent>1; pending не отменялась): закрывается ВСЯ встречная экспозиция (filled+pending) через close_position.
- **FIX-9**: алиасы `_is_exit_signal` выровнены с engine (buy↔[sell,short]).
- **#6** (BE-TRAD-03 «встречный = выход»): подтверждено КОРРЕКТНЫМ для нетто-позиционной модели (long-only/short-only; разворот через две свечи). Мульти-позиционный хедж (long+short одновременно) — **отдельный эпик**, в текущей архитектуре неверен. Задокументировано в коде.

## Верификация (объединённый результат a936e1a)

- **pytest** (trading + market_data + backtest + strategy + sandbox + security + routers + circuit_breaker): **1329 passed, 2 xfailed, 0 failed**.
- **pyright** по всем изменённым prod-файлам: **0 errors** (Backtrader-stub шум в `backtest/engine.py` — предсуществующий, не наш).
- Диффы trading/market_data прочитаны и верифицированы вручную (money-путь).

## Осталось / заведено (для backlog + следующих волн)

**NEEDS-REVIEW (вынесено на ARCH, отдельные задачи):**
- **BE-TRAD-06** — учёт paper-портфеля: требует согласованных изменений buy-fill/close/SL-TP + связки с T+1 `blocked_amount` и Circuit Breaker equity. Оставлен `xfail(strict)`-тест как спецификация.
- **BE-STRAT-02** (частично) — детектор формата blocks_json + защита generated_code сделаны; полная миграция `params.py`/`params_sync.py` на StrategyIR и `text_description`-sync для Blockly-версий — нет.
- **BE-MKT-02** (частично) — `_save_to_cache`/`_purge_iss_cache` намеренно не тронуты (их сессии выделенные, не shared trading-транзакция); подтвердить границу.

**Дизайн-находки ревью (низкий приоритет, backlog):**
- #6-related: мульти-позиционный хедж (long+short) — отдельный эпик.
- Частичное закрытие: `close_position` ордер по `filled_lots or volume_lots`, PnL по `volume_lots` (FUP-02 из P0-follow-up) — рассинхрон при частичном филле, всё ещё открыт.

**Следующие волны:** Волна 2 (be-auth-session, be-broker, be-notification, be-ai, be-runtime, be-misc), Волна 3 (frontend: fe-security, fe-network, fe-charts, fe-backtest-ui, fe-core-refactor, fe-ui-misc).
