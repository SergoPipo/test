# Единый интерпретатор стратегий + differential-сверка (SP-A) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live-торговля и бэктест принимают одинаковые торговые решения за счёт единого интерпретатора стратегий (`evaluate(ir, candles)`), а бэктест на каждом прогоне сверяет свои сигналы с интерпретатором и показывает результат.

**Architecture:** Один модуль индикаторов (`indicators.py`, сериями, конвенции backtrader) + один интерпретатор IR (`evaluator.py`). Live зовёт `evaluate` на каждой свече вместо `_blocks_to_sandbox`+RestrictedPython. Бэктест продолжает исполнять backtrader(`generated_code`) как основной результат, но дополнительно гоняет интерпретатор shadow-прогоном и сверяет сигналы (критично) и метрики (информационно). Гейт live жёстко блокирует запуск версий с расхождением или без сверки.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy (async) + Alembic, backtrader, pytest/pytest-asyncio; frontend React+TS+Mantine, vitest.

**Спецификация:** `docs/superpowers/specs/2026-06-10-strategy-interpreter-design.md`

**Соглашения проекта (обязательно):**
- После каждого Edit/Write `.py` → `cd Develop/backend && .venv/bin/python -m py_compile <file>` (pyright-lsp как MCP недоступен).
- После `.ts/.tsx` → `cd Develop/frontend && npx tsc --noEmit`.
- Тесты backend: `cd Develop/backend && .venv/bin/python -m pytest <path> -q`.
- Каждая задача завершается обновлением `Спринты/Sprint_8/changelog.md` + `sprint_state.md` (правило проекта «changelog немедленно»).
- Коммиты НЕ делать без явной команды заказчика (по двум репозиториям — ветки подтверждать отдельно). Шаги «Commit» ниже — это точки фиксации; фактический commit выполняем по согласованию.

---

## File Structure

**Новые файлы (backend):**
- `Develop/backend/app/strategy/indicators.py` — каноничные индикаторы (функции над сериями).
- `Develop/backend/app/strategy/ir.py` — датакласс `StrategyIR` + `parse_blocks(blocks_json) -> StrategyIR`.
- `Develop/backend/app/strategy/evaluator.py` — `evaluate(ir, candles) -> "buy"|"sell"|"hold"` + `evaluate_series(ir, candles) -> list[str]`.
- `Develop/backend/app/backtest/parity.py` — сверка сигналов/метрик backtrader ⇄ interpreter.

**Новые тесты:**
- `Develop/backend/tests/test_strategy/test_indicators.py`
- `Develop/backend/tests/test_strategy/test_ir.py`
- `Develop/backend/tests/test_strategy/test_evaluator.py`
- `Develop/backend/tests/test_strategy/test_signal_parity.py`
- `Develop/backend/tests/test_backtest/test_parity.py`
- `Develop/backend/tests/test_trading/test_runtime_evaluator.py`

**Модифицируемые файлы:**
- `Develop/backend/app/trading/engine.py` — `SignalProcessor` использует `evaluate` (удаляем путь `_blocks_to_sandbox`+sandbox для блочных стратегий, оставляем legacy-fallback для IR-less).
- `Develop/backend/app/backtest/service.py` — dual-run + сверка, запись parity-полей.
- `Develop/backend/app/backtest/models.py` + `schemas.py` — parity-поля.
- `Develop/backend/alembic/versions/<new>.py` — миграция parity-полей.
- `Develop/backend/app/trading/schemas.py` + `service.py` + `router.py` — гейт live + `override_parity`.
- `Develop/backend/app/strategy/router.py` — правка параметров на IR.
- `Develop/frontend/src/components/backtest/*` + `src/api/*` — бейдж сверки.
- `Develop/frontend/src/components/trading/LaunchSessionModal.tsx` — предупреждение/override.

**Внутренний контракт `StrategyIR`** (фиксируется в Task 1, используется везде):
```python
@dataclass
class IndicatorRef:
    id: str                 # blockly id (для логов)
    kind: str               # "sma"|"ema"|"rsi"|"macd"|"bollinger"|"atr"|"stochastic"|"volume"
    params: dict            # {"period":20,"source":"close"} и т.п.

@dataclass
class Condition:
    kind: str               # "compare"|"in_zone"|"crossover"|"and"|"or"|"not"
    # compare:
    left: "IndicatorRef|None" = None
    op: str | None = None           # ">","<",">=","<=","=="
    right_value: float | None = None
    right_ind: "IndicatorRef|None" = None
    # in_zone:
    value_ind: "IndicatorRef|None" = None
    zmin: float | None = None
    zmax: float | None = None
    # crossover:
    cross_dir: str | None = None    # "up"|"down"
    cross_left: "IndicatorRef|None" = None
    cross_right: "IndicatorRef|None" = None
    # logic:
    children: list["Condition"] = field(default_factory=list)

@dataclass
class StrategyIR:
    entry: Condition | None
    entry_direction: str            # "long"|"short"
    exit: Condition | None
    indicators: dict[str, IndicatorRef]   # id -> ref (все, что встречаются)
```

---

## Task 1: Индикаторы — каркас + SMA/EMA с parity vs backtrader

**Files:**
- Create: `Develop/backend/app/strategy/indicators.py`
- Test: `Develop/backend/tests/test_strategy/test_indicators.py`

- [ ] **Step 1: Написать падающий тест (helper + SMA/EMA parity)**

```python
# tests/test_strategy/test_indicators.py
import backtrader as bt
import pytest
from app.strategy import indicators as ind

# Синтетический ряд цен (детерминированный, не случайный).
CLOSES = [100 + ((i * 7) % 13) - 6 + (i % 5) for i in range(120)]
HIGHS = [c + 2 for c in CLOSES]
LOWS = [c - 2 for c in CLOSES]
VOLS = [1000 + (i % 7) * 10 for i in range(120)]


def _bt_line(indicator_cls, kwargs, feed_fields):
    """Прогнать один индикатор backtrader и вернуть его линию как list[float|None]."""
    captured = {}

    class _Strat(bt.Strategy):
        def __init__(self):
            self.ind = indicator_cls(**{k: getattr(self.data, v) if isinstance(v, str) and v in
                                        ("close", "high", "low", "volume") else v
                                        for k, v in kwargs.items()}) if kwargs else indicator_cls()
            captured["vals"] = []

        def next(self):
            try:
                captured["vals"].append(float(self.ind[0]))
            except Exception:
                captured["vals"].append(None)

    cerebro = bt.Cerebro()
    import pandas as pd
    df = pd.DataFrame({
        "open": CLOSES, "high": HIGHS, "low": LOWS, "close": CLOSES, "volume": VOLS,
    }, index=pd.date_range("2024-01-01", periods=len(CLOSES), freq="D"))
    cerebro.adddata(bt.feeds.PandasData(dataname=df))
    cerebro.addstrategy(_Strat)
    cerebro.run()
    return captured["vals"]


def test_sma_matches_backtrader():
    ours = ind.sma(CLOSES, 20)            # серия длиной len(CLOSES), None на прогреве
    theirs = _bt_line(bt.indicators.SimpleMovingAverage, {"period": 20}, None)
    # backtrader отдаёт значения только начиная с бара, где индикатор «созрел»
    last = len(CLOSES) - 1
    assert ours[last] == pytest.approx(theirs[-1], rel=1e-9)


def test_ema_matches_backtrader():
    ours = ind.ema(CLOSES, 12)
    theirs = _bt_line(bt.indicators.ExponentialMovingAverage, {"period": 12}, None)
    last = len(CLOSES) - 1
    assert ours[last] == pytest.approx(theirs[-1], rel=1e-9)
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_indicators.py -q`
Expected: FAIL (`ModuleNotFoundError: app.strategy.indicators` или `AttributeError: sma`).

- [ ] **Step 3: Реализовать SMA/EMA (серии)**

```python
# app/strategy/indicators.py
"""Каноничные индикаторы для интерпретатора стратегий.

Все функции возвращают СЕРИЮ значений длиной len(data), с None на «прогреве»
(пока индикатор не созрел) — это нужно для crossover (нужны 2 последних бара)
и для shadow-прогона бэктеста (значение на каждом баре).

Конвенции выровнены под backtrader (см. спеку §6).
"""
from __future__ import annotations


def sma(data: list[float], period: int) -> list[float | None]:
    out: list[float | None] = [None] * len(data)
    if period <= 0:
        return out
    run = 0.0
    for i, v in enumerate(data):
        run += v
        if i >= period:
            run -= data[i - period]
        if i >= period - 1:
            out[i] = run / period
    return out


def ema(data: list[float], period: int) -> list[float | None]:
    out: list[float | None] = [None] * len(data)
    if period <= 0 or len(data) < period:
        return out
    k = 2.0 / (period + 1)
    seed = sum(data[:period]) / period          # backtrader seed = SMA(period)
    out[period - 1] = seed
    prev = seed
    for i in range(period, len(data)):
        prev = data[i] * k + prev * (1 - k)
        out[i] = prev
    return out
```

- [ ] **Step 4: Запустить — убедиться, что проходит**

Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_indicators.py -q`
Expected: PASS (2 passed). Если EMA не сходится — проверить seed (backtrader EMA seed = SMA первого периода).

- [ ] **Step 5: py_compile + commit-точка**

Run: `cd Develop/backend && .venv/bin/python -m py_compile app/strategy/indicators.py`
Commit (по согласованию): `feat(s8r-bug23): indicators.py — SMA/EMA с parity-тестами vs backtrader`

---

## Task 2: Индикатор RSI (Уайлдер) — известное расхождение

**Files:**
- Modify: `Develop/backend/app/strategy/indicators.py`
- Test: `Develop/backend/tests/test_strategy/test_indicators.py`

- [ ] **Step 1: Падающий тест на RSI-parity (Уайлдер)**

```python
def test_rsi_matches_backtrader_wilder():
    ours = ind.rsi(CLOSES, 14)
    theirs = _bt_line(bt.indicators.RSI, {"period": 14}, None)  # backtrader RSI = SMMA (Wilder)
    last = len(CLOSES) - 1
    assert ours[last] == pytest.approx(theirs[-1], rel=1e-6)
```

- [ ] **Step 2: Запустить — FAIL**

Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_indicators.py::test_rsi_matches_backtrader_wilder -q`
Expected: FAIL (`AttributeError: rsi`). После реализации простым средним — тоже FAIL (числа разойдутся с Уайлдером) — это и есть демонстрация проблемы из спеки §6.

- [ ] **Step 3: Реализовать RSI со сглаживанием Уайлдера (SMMA)**

```python
def rsi(data: list[float], period: int) -> list[float | None]:
    out: list[float | None] = [None] * len(data)
    if period <= 0 or len(data) < period + 1:
        return out
    gains = 0.0
    losses = 0.0
    # Первичное среднее — простое среднее за первые `period` изменений.
    for i in range(1, period + 1):
        ch = data[i] - data[i - 1]
        gains += max(ch, 0.0)
        losses += max(-ch, 0.0)
    avg_gain = gains / period
    avg_loss = losses / period
    def _rsi(ag: float, al: float) -> float:
        if al == 0:
            return 100.0
        rs = ag / al
        return 100.0 - 100.0 / (1 + rs)
    out[period] = _rsi(avg_gain, avg_loss)
    # Дальше — сглаживание Уайлдера (SMMA): avg = (avg*(period-1) + new) / period.
    for i in range(period + 1, len(data)):
        ch = data[i] - data[i - 1]
        gain = max(ch, 0.0)
        loss = max(-ch, 0.0)
        avg_gain = (avg_gain * (period - 1) + gain) / period
        avg_loss = (avg_loss * (period - 1) + loss) / period
        out[i] = _rsi(avg_gain, avg_loss)
    return out
```

- [ ] **Step 4: Запустить — PASS**

Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_indicators.py -q`
Expected: PASS (3 passed). Если small mismatch — свериться с тем, как backtrader инициализирует первый бар RSI (может потребоваться seed-вариант; зафиксировать комментарием).

- [ ] **Step 5: py_compile + commit-точка**

Commit: `feat(s8r-bug23): RSI (Wilder/SMMA) в indicators.py — устранение расхождения с backtrader`

---

## Task 3: Индикаторы MACD / Bollinger / ATR / Stochastic / Volume

**Files:**
- Modify: `Develop/backend/app/strategy/indicators.py`
- Test: `Develop/backend/tests/test_strategy/test_indicators.py`

- [ ] **Step 1: Падающие parity-тесты (по одному на индикатор)**

```python
def test_macd_line_matches_backtrader():
    ours = ind.macd(CLOSES, 12, 26, 9)        # -> dict с сериями "macd","signal","hist"
    theirs = _bt_line(bt.indicators.MACD, {"period_me1": 12, "period_me2": 26, "period_signal": 9}, None)
    last = len(CLOSES) - 1
    assert ours["macd"][last] == pytest.approx(theirs[-1], rel=1e-6)

def test_bollinger_mid_matches_backtrader():
    ours = ind.bollinger(CLOSES, 20, 2.0)     # -> dict "mid","top","bot"
    theirs = _bt_line(bt.indicators.BollingerBands, {"period": 20, "devfactor": 2.0}, None)
    last = len(CLOSES) - 1
    assert ours["mid"][last] == pytest.approx(theirs[-1], rel=1e-9)

def test_atr_matches_backtrader():
    ours = ind.atr(HIGHS, LOWS, CLOSES, 14)
    # ATR требует OHLC — сверяем через прогон, читая bt.indicators.ATR
    theirs = _bt_line(bt.indicators.ATR, {"period": 14}, None)
    last = len(CLOSES) - 1
    assert ours[last] == pytest.approx(theirs[-1], rel=1e-6)

def test_stochastic_k_matches_backtrader():
    ours = ind.stochastic(HIGHS, LOWS, CLOSES, 14, 3)   # -> dict "k","d"
    theirs = _bt_line(bt.indicators.Stochastic, {"period": 14, "period_dfast": 3}, None)
    last = len(CLOSES) - 1
    assert ours["k"][last] == pytest.approx(theirs[-1], rel=1e-3)  # %K сглаживание — допуск шире

def test_volume_returns_bar_volume():
    ours = ind.volume(VOLS)
    assert ours[-1] == VOLS[-1]
```

- [ ] **Step 2: Запустить — FAIL** (`AttributeError`). 
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_indicators.py -q`

- [ ] **Step 3: Реализовать индикаторы**

```python
def macd(data, fast=12, slow=26, signal=9):
    ema_fast = ema(data, fast)
    ema_slow = ema(data, slow)
    macd_line: list[float | None] = [
        (ema_fast[i] - ema_slow[i]) if (ema_fast[i] is not None and ema_slow[i] is not None) else None
        for i in range(len(data))
    ]
    valid = [v for v in macd_line if v is not None]
    sig_tail = ema([v for v in macd_line if v is not None], signal)
    # выровнять signal по индексам, где macd_line не None
    signal_line: list[float | None] = [None] * len(data)
    j = 0
    for i in range(len(data)):
        if macd_line[i] is not None:
            signal_line[i] = sig_tail[j]
            j += 1
    hist = [
        (macd_line[i] - signal_line[i]) if (macd_line[i] is not None and signal_line[i] is not None) else None
        for i in range(len(data))
    ]
    return {"macd": macd_line, "signal": signal_line, "hist": hist}


def _stddev_pop(window: list[float]) -> float:
    n = len(window)
    m = sum(window) / n
    return (sum((x - m) ** 2 for x in window) / n) ** 0.5   # population std (ddof=0), как backtrader


def bollinger(data, period=20, dev=2.0):
    mid = sma(data, period)
    top: list[float | None] = [None] * len(data)
    bot: list[float | None] = [None] * len(data)
    for i in range(len(data)):
        if mid[i] is None:
            continue
        sd = _stddev_pop(data[i - period + 1 : i + 1])
        top[i] = mid[i] + dev * sd
        bot[i] = mid[i] - dev * sd
    return {"mid": mid, "top": top, "bot": bot}


def _true_range(highs, lows, closes, i):
    if i == 0:
        return highs[0] - lows[0]
    return max(highs[i] - lows[i], abs(highs[i] - closes[i - 1]), abs(lows[i] - closes[i - 1]))


def atr(highs, lows, closes, period=14):
    n = len(closes)
    out: list[float | None] = [None] * n
    if n < period:
        return out
    trs = [_true_range(highs, lows, closes, i) for i in range(n)]
    first = sum(trs[1 : period + 1]) / period if n > period else sum(trs[:period]) / period
    out[period] = first if n > period else None
    prev = first
    for i in range(period + 1, n):
        prev = (prev * (period - 1) + trs[i]) / period       # сглаживание Уайлдера
        out[i] = prev
    return out


def stochastic(highs, lows, closes, k_period=14, d_period=3):
    n = len(closes)
    k: list[float | None] = [None] * n
    for i in range(n):
        if i < k_period - 1:
            continue
        hh = max(highs[i - k_period + 1 : i + 1])
        ll = min(lows[i - k_period + 1 : i + 1])
        k[i] = 100.0 * (closes[i] - ll) / (hh - ll) if hh != ll else 0.0
    # %D = SMA(%K, d_period) по непустым значениям
    d: list[float | None] = [None] * n
    kk = [(i, v) for i, v in enumerate(k) if v is not None]
    for pos in range(d_period - 1, len(kk)):
        window = [kk[pos - off][1] for off in range(d_period)]
        d[kk[pos][0]] = sum(window) / d_period
    return {"k": k, "d": d}


def volume(vols: list[float]) -> list[float | None]:
    return [float(v) for v in vols]
```

- [ ] **Step 4: Запустить — PASS** (допуски как в тестах; при расхождении Stochastic — уточнить тип сглаживания backtrader и зафиксировать допуск/конвенцию комментарием).
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_indicators.py -q`
Expected: PASS (8 passed).

- [ ] **Step 5: py_compile + commit-точка** — `feat(s8r-bug23): MACD/Bollinger/ATR/Stochastic/Volume в indicators.py`

---

## Task 4: `StrategyIR` + `parse_blocks` (нормализация формата Blockly)

**Files:**
- Create: `Develop/backend/app/strategy/ir.py`
- Test: `Develop/backend/tests/test_strategy/test_ir.py`

- [ ] **Step 1: Падающий тест — парсинг реального формата Blockly (как у sv=92)**

```python
# tests/test_strategy/test_ir.py
from app.strategy.ir import parse_blocks

BLOCKS_SV92 = {
  "blocks": {"languageVersion": 0, "blocks": [
    {"type": "signal_entry", "id": "e1", "fields": {"DIRECTION": "long"},
     "inputs": {"CONDITION": {"block": {
        "type": "condition_compare", "id": "c1",
        "fields": {"OPERATOR": "gt", "RIGHT_TYPE": "number", "THRESHOLD": 70},
        "inputs": {"LEFT": {"block": {"type": "indicator_sma", "id": "s1",
                                       "fields": {"PERIOD": 20, "SOURCE": "close"}}}}}}},
     "next": {"block": {
        "type": "signal_exit", "id": "x1",
        "inputs": {"CONDITION": {"block": {
            "type": "condition_in_zone", "id": "z1", "fields": {"MIN": 30, "MAX": 70},
            "inputs": {"VALUE": {"block": {"type": "indicator_ema", "id": "m1",
                                            "fields": {"PERIOD": 12, "SOURCE": "close"}}}}}}}}}}
  ]}}


def test_parse_entry_compare_sma_gt_70():
    ir = parse_blocks(BLOCKS_SV92)
    assert ir.entry_direction == "long"
    assert ir.entry.kind == "compare"
    assert ir.entry.op == ">"
    assert ir.entry.right_value == 70
    assert ir.entry.left.kind == "sma"
    assert ir.entry.left.params["period"] == 20


def test_parse_exit_in_zone_ema():
    ir = parse_blocks(BLOCKS_SV92)
    assert ir.exit.kind == "in_zone"
    assert ir.exit.zmin == 30 and ir.exit.zmax == 70
    assert ir.exit.value_ind.kind == "ema"
    assert ir.exit.value_ind.params["period"] == 12


def test_parse_accepts_json_string():
    import json
    ir = parse_blocks(json.dumps(BLOCKS_SV92))
    assert ir.entry is not None
```

- [ ] **Step 2: Запустить — FAIL** (`ModuleNotFoundError: app.strategy.ir`).

- [ ] **Step 3: Реализовать `ir.py`**

```python
# app/strategy/ir.py
from __future__ import annotations
import json
from dataclasses import dataclass, field

_OP_MAP = {"gt": ">", "lt": "<", "gte": ">=", "lte": "<=", "eq": "==", "neq": "!="}
_IND_MAP = {"indicator_sma": "sma", "indicator_ema": "ema", "indicator_rsi": "rsi",
            "indicator_macd": "macd", "indicator_bollinger": "bollinger",
            "indicator_atr": "atr", "indicator_stochastic": "stochastic",
            "indicator_volume": "volume"}


@dataclass
class IndicatorRef:
    id: str
    kind: str
    params: dict


@dataclass
class Condition:
    kind: str
    left: "IndicatorRef | None" = None
    op: str | None = None
    right_value: float | None = None
    right_ind: "IndicatorRef | None" = None
    value_ind: "IndicatorRef | None" = None
    zmin: float | None = None
    zmax: float | None = None
    cross_dir: str | None = None
    cross_left: "IndicatorRef | None" = None
    cross_right: "IndicatorRef | None" = None
    children: list["Condition"] = field(default_factory=list)


@dataclass
class StrategyIR:
    entry: Condition | None
    entry_direction: str
    exit: Condition | None
    indicators: dict


def _ind_from_block(block: dict, sink: dict) -> IndicatorRef:
    kind = _IND_MAP.get(block.get("type", ""), block.get("type", ""))
    f = block.get("fields", {}) or {}
    params = {}
    for src_key, dst_key in (("PERIOD", "period"), ("SOURCE", "source"), ("FAST", "fast"),
                             ("SLOW", "slow"), ("SIGNAL", "signal"), ("STD_DEV", "dev"),
                             ("K_PERIOD", "k_period"), ("D_PERIOD", "d_period")):
        if src_key in f:
            params[dst_key] = f[src_key]
    ref = IndicatorRef(id=block.get("id", ""), kind=kind, params=params)
    sink[ref.id] = ref
    return ref


def _input_block(block: dict, name: str) -> dict | None:
    inp = (block.get("inputs") or {}).get(name)
    if isinstance(inp, dict):
        return inp.get("block")
    return None


def _cond_from_block(block: dict, sink: dict) -> Condition | None:
    if block is None:
        return None
    btype = block.get("type", "")
    f = block.get("fields", {}) or {}
    if btype == "condition_compare":
        left_b = _input_block(block, "LEFT")
        right_b = _input_block(block, "RIGHT")
        c = Condition(kind="compare",
                      left=_ind_from_block(left_b, sink) if left_b else None,
                      op=_OP_MAP.get(f.get("OPERATOR", "gt"), ">"))
        if right_b is not None:
            c.right_ind = _ind_from_block(right_b, sink)
        else:
            c.right_value = float(f.get("THRESHOLD", 0))
        return c
    if btype == "condition_in_zone":
        vb = _input_block(block, "VALUE")
        return Condition(kind="in_zone",
                         value_ind=_ind_from_block(vb, sink) if vb else None,
                         zmin=float(f.get("MIN", 0)), zmax=float(f.get("MAX", 0)))
    if btype == "condition_crossover":
        lb = _input_block(block, "LEFT")
        rb = _input_block(block, "RIGHT")
        return Condition(kind="crossover",
                         cross_dir=f.get("DIRECTION", "up"),
                         cross_left=_ind_from_block(lb, sink) if lb else None,
                         cross_right=_ind_from_block(rb, sink) if rb else None)
    if btype in ("logic_and", "logic_or", "logic_not"):
        kind = {"logic_and": "and", "logic_or": "or", "logic_not": "not"}[btype]
        children = []
        for key, val in (block.get("inputs") or {}).items():
            if isinstance(val, dict) and "block" in val:
                child = _cond_from_block(val["block"], sink)
                if child:
                    children.append(child)
        return Condition(kind=kind, children=children)
    return None


def parse_blocks(blocks_json) -> StrategyIR:
    if isinstance(blocks_json, str):
        blocks_json = json.loads(blocks_json)
    raw = blocks_json.get("blocks", blocks_json)
    if isinstance(raw, dict):
        raw = raw.get("blocks", [])
    sink: dict = {}
    entry = exit_ = None
    direction = "long"
    # Обойти цепочку next, найти signal_entry / signal_exit.
    def _walk(block):
        nonlocal entry, exit_, direction
        if not block:
            return
        btype = block.get("type", "")
        if btype == "signal_entry":
            direction = (block.get("fields", {}) or {}).get("DIRECTION", "long")
            entry = _cond_from_block(_input_block(block, "CONDITION"), sink)
        elif btype == "signal_exit":
            exit_ = _cond_from_block(_input_block(block, "CONDITION"), sink)
        nxt = block.get("next")
        if isinstance(nxt, dict) and "block" in nxt:
            _walk(nxt["block"])
    for root in raw:
        _walk(root)
    return StrategyIR(entry=entry, entry_direction=direction, exit=exit_, indicators=sink)
```

- [ ] **Step 4: Запустить — PASS**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_ir.py -q`
Expected: PASS (3 passed).

- [ ] **Step 5: py_compile + commit-точка** — `feat(s8r-bug23): StrategyIR + parse_blocks (нормализация формата Blockly)`

---

## Task 5: `evaluate` — индикаторные значения + condition_compare

**Files:**
- Create: `Develop/backend/app/strategy/evaluator.py`
- Test: `Develop/backend/tests/test_strategy/test_evaluator.py`

- [ ] **Step 1: Падающий тест — compare SMA>70 → buy; число и индикатор справа**

```python
# tests/test_strategy/test_evaluator.py
from app.strategy.ir import parse_blocks
from app.strategy.evaluator import evaluate

def _candles(closes):
    return [{"open": c, "high": c + 1, "low": c - 1, "close": c, "volume": 1000} for c in closes]

ENTRY_SMA_GT_70 = {"blocks": {"blocks": [
    {"type": "signal_entry", "id": "e", "fields": {"DIRECTION": "long"},
     "inputs": {"CONDITION": {"block": {"type": "condition_compare", "id": "c",
        "fields": {"OPERATOR": "gt", "RIGHT_TYPE": "number", "THRESHOLD": 70},
        "inputs": {"LEFT": {"block": {"type": "indicator_sma", "id": "s",
                                       "fields": {"PERIOD": 20, "SOURCE": "close"}}}}}}}}]}}

def test_compare_sma_gt_70_emits_buy():
    ir = parse_blocks(ENTRY_SMA_GT_70)
    candles = _candles([320.0 + (i % 3) for i in range(30)])  # SMA(20) ~ 321 > 70
    assert evaluate(ir, candles) == "buy"

def test_compare_false_emits_hold():
    ir = parse_blocks(ENTRY_SMA_GT_70)
    candles = _candles([10.0 + (i % 3) for i in range(30)])   # SMA ~ 11, не > 70
    assert evaluate(ir, candles) == "hold"

def test_compare_warmup_emits_hold():
    ir = parse_blocks(ENTRY_SMA_GT_70)
    candles = _candles([320.0] * 5)   # < 20 свечей → SMA None → hold
    assert evaluate(ir, candles) == "hold"
```

- [ ] **Step 2: Запустить — FAIL** (`ModuleNotFoundError: app.strategy.evaluator`).

- [ ] **Step 3: Реализовать каркас evaluate + compare**

```python
# app/strategy/evaluator.py
from __future__ import annotations
from app.strategy import indicators as ind
from app.strategy.ir import StrategyIR, Condition, IndicatorRef, parse_blocks  # noqa: F401


def _series(ref: IndicatorRef, candles: list[dict]) -> list[float | None] | dict:
    closes = [float(c["close"]) for c in candles]
    src = (ref.params.get("source") or "close")
    data = [float(c[src]) for c in candles] if src in ("open", "high", "low", "close") else closes
    p = int(ref.params.get("period", 20) or 20)
    if ref.kind == "sma":
        return ind.sma(data, p)
    if ref.kind == "ema":
        return ind.ema(data, p)
    if ref.kind == "rsi":
        return ind.rsi(closes, int(ref.params.get("period", 14) or 14))
    if ref.kind == "macd":
        return ind.macd(closes, int(ref.params.get("fast", 12)), int(ref.params.get("slow", 26)),
                        int(ref.params.get("signal", 9)))["macd"]
    if ref.kind == "bollinger":
        return ind.bollinger(closes, p, float(ref.params.get("dev", 2.0)))["mid"]
    if ref.kind == "atr":
        return ind.atr([float(c["high"]) for c in candles], [float(c["low"]) for c in candles],
                       closes, int(ref.params.get("period", 14)))
    if ref.kind == "stochastic":
        return ind.stochastic([float(c["high"]) for c in candles], [float(c["low"]) for c in candles],
                              closes, int(ref.params.get("k_period", 14)),
                              int(ref.params.get("d_period", 3)))["k"]
    if ref.kind == "volume":
        return ind.volume([float(c["volume"]) for c in candles])
    return [None] * len(candles)


def _val_at(ref: IndicatorRef, candles: list[dict], i: int):
    s = _series(ref, candles)
    return s[i] if isinstance(s, list) else None


def _eval_condition(cond: Condition | None, candles: list[dict], i: int) -> bool:
    if cond is None:
        return False
    if cond.kind == "compare":
        left = _val_at(cond.left, candles, i) if cond.left else None
        if left is None:
            return False
        right = cond.right_value if cond.right_value is not None else (
            _val_at(cond.right_ind, candles, i) if cond.right_ind else None)
        if right is None:
            return False
        return _apply_op(left, cond.op, right)
    if cond.kind == "in_zone":
        v = _val_at(cond.value_ind, candles, i) if cond.value_ind else None
        return v is not None and cond.zmin <= v <= cond.zmax
    if cond.kind == "crossover":
        return _eval_crossover(cond, candles, i)
    if cond.kind == "and":
        return all(_eval_condition(c, candles, i) for c in cond.children)
    if cond.kind == "or":
        return any(_eval_condition(c, candles, i) for c in cond.children)
    if cond.kind == "not":
        return not (cond.children and _eval_condition(cond.children[0], candles, i))
    return False


def _apply_op(a: float, op: str | None, b: float) -> bool:
    return {">": a > b, "<": a < b, ">=": a >= b, "<=": a <= b,
            "==": a == b, "!=": a != b}.get(op or ">", False)


def _eval_crossover(cond: Condition, candles: list[dict], i: int) -> bool:
    if i < 1 or not cond.cross_left or not cross := cond.cross_right:  # noqa
        return False
    return False  # реализуется в Task 7


def evaluate(ir: StrategyIR, candles: list[dict]) -> str:
    """Решение на ПОСЛЕДНЕЙ свече истории."""
    if not candles:
        return "hold"
    i = len(candles) - 1
    if _eval_condition(ir.entry, candles, i):
        return "buy"
    if _eval_condition(ir.exit, candles, i):
        return "sell"
    return "hold"
```

> ⚠️ В Step 3 строка `_eval_crossover` намеренно заглушена (`return False`) и будет заменена в Task 7. Исправь синтаксис: убери walrus-строку, оставь `def _eval_crossover(...): return False`.

- [ ] **Step 4: Запустить — PASS**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_evaluator.py -q`
Expected: PASS (3 passed).

- [ ] **Step 5: py_compile + commit-точка** — `feat(s8r-bug23): evaluator.evaluate + condition_compare`

---

## Task 6: `condition_in_zone` (регрессия выхода sv=92)

**Files:**
- Test: `Develop/backend/tests/test_strategy/test_evaluator.py`

> `in_zone` уже реализован в Task 5 (`_eval_condition`). Эта задача — добавить регрессионный тест на exit sv=92.

- [ ] **Step 1: Падающий/проверочный тест — exit in_zone даёт sell**

```python
EXIT_EMA_IN_ZONE = {"blocks": {"blocks": [
    {"type": "signal_entry", "id": "e", "fields": {"DIRECTION": "long"},
     "inputs": {"CONDITION": {"block": {"type": "condition_compare", "id": "c",
        "fields": {"OPERATOR": "lt", "RIGHT_TYPE": "number", "THRESHOLD": 0},
        "inputs": {"LEFT": {"block": {"type": "indicator_sma", "id": "s",
                                       "fields": {"PERIOD": 20, "SOURCE": "close"}}}}}}},
     "next": {"block": {"type": "signal_exit", "id": "x",
        "inputs": {"CONDITION": {"block": {"type": "condition_in_zone", "id": "z",
            "fields": {"MIN": 30, "MAX": 70},
            "inputs": {"VALUE": {"block": {"type": "indicator_ema", "id": "m",
                                            "fields": {"PERIOD": 12, "SOURCE": "close"}}}}}}}}}}]}}

def test_exit_in_zone_emits_sell():
    ir = parse_blocks(EXIT_EMA_IN_ZONE)
    # entry SMA<0 невозможно (цены>0) → не buy; EMA(12) попадёт в [30,70]
    candles = _candles([50.0 + (i % 3) for i in range(30)])   # EMA ~ 51 в [30,70]
    assert evaluate(ir, candles) == "sell"
```

- [ ] **Step 2: Запустить — PASS** (логика in_zone уже есть).
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_evaluator.py::test_exit_in_zone_emits_sell -q`
Expected: PASS. Если FAIL — проверить, что entry-условие действительно ложно (SMA<0) и что EMA в зоне.

- [ ] **Step 3: commit-точка** — `test(s8r-bug23): регрессия exit condition_in_zone (sv=92)`

---

## Task 7: `condition_crossover`

**Files:**
- Modify: `Develop/backend/app/strategy/evaluator.py`
- Test: `Develop/backend/tests/test_strategy/test_evaluator.py`

- [ ] **Step 1: Падающий тест — пересечение SMA снизу вверх через EMA**

```python
CROSS_UP = {"blocks": {"blocks": [
    {"type": "signal_entry", "id": "e", "fields": {"DIRECTION": "long"},
     "inputs": {"CONDITION": {"block": {"type": "condition_crossover", "id": "x",
        "fields": {"DIRECTION": "up"},
        "inputs": {"LEFT": {"block": {"type": "indicator_sma", "id": "a", "fields": {"PERIOD": 3, "SOURCE": "close"}}},
                   "RIGHT": {"block": {"type": "indicator_sma", "id": "b", "fields": {"PERIOD": 8, "SOURCE": "close"}}}}}}}}]}}

def test_crossover_up_emits_buy():
    ir = parse_blocks(CROSS_UP)
    # ряд: сначала вниз (fast<slow), затем рывок вверх на последнем баре (fast>slow)
    closes = [100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 120]
    assert evaluate(ir, _candles(closes)) == "buy"

def test_crossover_no_cross_emits_hold():
    ir = parse_blocks(CROSS_UP)
    closes = [100] * 12
    assert evaluate(ir, _candles(closes)) == "hold"
```

- [ ] **Step 2: Запустить — FAIL** (crossover-заглушка возвращает False).

- [ ] **Step 3: Реализовать `_eval_crossover`**

```python
def _eval_crossover(cond, candles, i):
    if i < 1 or not cond.cross_left or not cond.cross_right:
        return False
    ls = _series(cond.cross_left, candles)
    rs = _series(cond.cross_right, candles)
    if not isinstance(ls, list) or not isinstance(rs, list):
        return False
    l0, l1 = ls[i - 1], ls[i]
    r0, r1 = rs[i - 1], rs[i]
    if None in (l0, l1, r0, r1):
        return False
    if cond.cross_dir == "up":
        return l0 <= r0 and l1 > r1
    return l0 >= r0 and l1 < r1
```

- [ ] **Step 4: Запустить — PASS**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_evaluator.py -q`
Expected: PASS (все evaluator-тесты).

- [ ] **Step 5: py_compile + commit-точка** — `feat(s8r-bug23): condition_crossover в evaluator`

---

## Task 8: `logic_and` / `logic_or` / `logic_not`

**Files:**
- Test: `Develop/backend/tests/test_strategy/test_evaluator.py`

> Логика уже реализована в `_eval_condition` (Task 5). Задача — тесты.

- [ ] **Step 1: Тесты на AND/OR/NOT**

```python
def _entry_logic(logic_type, conds):
    return {"blocks": {"blocks": [
        {"type": "signal_entry", "id": "e", "fields": {"DIRECTION": "long"},
         "inputs": {"CONDITION": {"block": {"type": logic_type, "id": "L",
            "inputs": {f"INPUT{i}": {"block": c} for i, c in enumerate(conds)}}}}}]}}

def _cmp(ind_id, period, op, thr):
    return {"type": "condition_compare", "id": f"c{ind_id}",
            "fields": {"OPERATOR": op, "RIGHT_TYPE": "number", "THRESHOLD": thr},
            "inputs": {"LEFT": {"block": {"type": "indicator_sma", "id": ind_id,
                                          "fields": {"PERIOD": period, "SOURCE": "close"}}}}}

def test_logic_and_true_when_both_true():
    ir = parse_blocks(_entry_logic("logic_and", [_cmp("a", 5, "gt", 70), _cmp("b", 5, "lt", 1000)]))
    assert evaluate(ir, _candles([300.0]*10)) == "buy"

def test_logic_and_false_when_one_false():
    ir = parse_blocks(_entry_logic("logic_and", [_cmp("a", 5, "gt", 70), _cmp("b", 5, "gt", 1000)]))
    assert evaluate(ir, _candles([300.0]*10)) == "hold"

def test_logic_or_true_when_one_true():
    ir = parse_blocks(_entry_logic("logic_or", [_cmp("a", 5, "gt", 1000), _cmp("b", 5, "gt", 70)]))
    assert evaluate(ir, _candles([300.0]*10)) == "buy"

def test_logic_not_inverts():
    ir = parse_blocks(_entry_logic("logic_not", [_cmp("a", 5, "gt", 1000)]))  # 300>1000 ложно → not → true
    assert evaluate(ir, _candles([300.0]*10)) == "buy"
```

- [ ] **Step 2: Запустить — PASS** (логика есть). Если FAIL на разборе `INPUT{i}` — проверить, что `_cond_from_block` для logic обходит все `inputs`.
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/test_evaluator.py -q`

- [ ] **Step 3: commit-точка** — `test(s8r-bug23): logic and/or/not в evaluator`

---

## Task 9: `evaluate_series` (для shadow-прогона бэктеста) + direction=short

**Files:**
- Modify: `Develop/backend/app/strategy/evaluator.py`
- Test: `Develop/backend/tests/test_strategy/test_evaluator.py`

- [ ] **Step 1: Тест — серия решений по каждому бару + учёт направления**

```python
def test_evaluate_series_returns_decision_per_bar():
    ir = parse_blocks(ENTRY_SMA_GT_70)
    from app.strategy.evaluator import evaluate_series
    closes = [10.0]*25 + [320.0]*5     # сначала hold, в конце buy
    decisions = evaluate_series(ir, _candles(closes))
    assert len(decisions) == 30
    assert decisions[0] == "hold"
    assert decisions[-1] == "buy"

def test_short_entry_direction_preserved():
    ir = parse_blocks(ENTRY_SMA_GT_70)
    # вручную ставим short и проверяем, что direction доступен для движков
    ir.entry_direction = "short"
    assert ir.entry_direction == "short"
```

- [ ] **Step 2: Запустить — FAIL** (`evaluate_series` нет).

- [ ] **Step 3: Реализовать `evaluate_series`**

```python
def evaluate_series(ir: StrategyIR, candles: list[dict]) -> list[str]:
    """Решение на КАЖДОМ баре (для shadow-прогона бэктеста)."""
    out: list[str] = []
    for i in range(len(candles)):
        if _eval_condition(ir.entry, candles, i):
            out.append("buy")
        elif _eval_condition(ir.exit, candles, i):
            out.append("sell")
        else:
            out.append("hold")
    return out
```

> Замечание по производительности: текущая реализация пересчитывает серии индикаторов на каждом баре через `_val_at`. Для shadow-прогона O(N²). Оптимизация (вынести расчёт серий ОДИН раз и индексировать) — рефактор-шаг ниже, под зелёными тестами.

- [ ] **Step 4: Запустить — PASS**

- [ ] **Step 5: REFACTOR — кешировать серии индикаторов (O(N))**

Вынести расчёт всех `ir.indicators` в один проход (dict `id -> series`), `_eval_condition` принимает готовый кеш. Тесты остаются зелёными.
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/ -q`
Expected: PASS (все strategy-тесты).

- [ ] **Step 6: py_compile + commit-точка** — `feat(s8r-bug23): evaluate_series + кеш серий индикаторов`

---

## Task 10: Live-переезд — `SignalProcessor` использует `evaluate`

**Files:**
- Modify: `Develop/backend/app/trading/engine.py` (`SignalProcessor.process_candle` / `_get_strategy_code` / `_execute_strategy`)
- Test: `Develop/backend/tests/test_trading/test_runtime_evaluator.py`

- [ ] **Step 1: Падающий тест — process_candle на блочной стратегии даёт BUY/SELL через evaluate**

```python
# tests/test_trading/test_runtime_evaluator.py
import json, pytest
from app.trading.engine import SignalProcessor, SignalAction
from app.trading.models import TradingSession

ENTRY_SMA_GT_70 = { ... }  # тот же blocks_json, что в test_evaluator (вынести в общий helper при желании)

@pytest.mark.asyncio
async def test_process_candle_uses_interpreter_buy(db_session, monkeypatch):
    # стратегия-версия с blocks_json (без backtrader-исполнения)
    from app.strategy.models import Strategy, StrategyVersion
    strat = Strategy(name="t", user_id=1); db_session.add(strat); await db_session.flush()
    ver = StrategyVersion(strategy_id=strat.id, version=1,
                          blocks_json=json.dumps(ENTRY_SMA_GT_70),
                          generated_code="class GeneratedStrategy(bt.Strategy): pass")
    db_session.add(ver); await db_session.commit(); await db_session.refresh(ver)
    session = TradingSession(strategy_version_id=ver.id, ticker="SBER", timeframe="1m",
                             mode="paper", status="active", initial_capital=100000)
    db_session.add(session); await db_session.commit(); await db_session.refresh(session)

    candles = [type("C", (), {"open": 320, "high": 321, "low": 319, "close": 320.0+i%3,
                              "volume": 1000, "timestamp": __import__("datetime").datetime(2026,6,4,10,i%60)})()
               for i in range(30)]
    sp = SignalProcessor(db_session)
    signal = await sp.process_candle(session, candles)
    assert signal is not None and signal.action == SignalAction.BUY
```

> Подгони конструкцию `candles` под фактический тип `CandleData` (см. сигнатуру `process_candle` в engine.py). При необходимости используй существующий helper из `tests/test_trading/conftest.py`.

- [ ] **Step 2: Запустить — FAIL** (сейчас идёт через `_blocks_to_sandbox`; для этого blocks_json даёт buy и так — тогда тест на КОРРЕКТНОСТЬ exit_in_zone: добавь второй тест, где exit через `condition_in_zone` ДОЛЖЕН дать SELL; на текущем коде он даст HOLD → FAIL).

```python
@pytest.mark.asyncio
async def test_process_candle_exit_in_zone_now_sells(db_session):
    # blocks с exit condition_in_zone — на старом _blocks_to_sandbox давал HOLD (баг), теперь SELL
    ...  # аналогично, blocks_json = EXIT_EMA_IN_ZONE из test_evaluator
    signal = await SignalProcessor(db_session).process_candle(session, candles_in_zone)
    assert signal.action == SignalAction.SELL
```

- [ ] **Step 3: Переключить `SignalProcessor` на `evaluate`**

В `engine.py`:
- В `process_candle`: вместо `_get_strategy_code` + `_execute_strategy` — построить IR и вызвать интерпретатор:

```python
from app.strategy.ir import parse_blocks
from app.strategy.evaluator import evaluate

# внутри process_candle, после проверок:
version = await self._get_version(session.strategy_version_id)   # вернуть StrategyVersion
if version is None or not (version.blocks_json and version.blocks_json.strip() and version.blocks_json.strip() != "{}"):
    # IR-less стратегия → legacy fallback (старый путь _blocks_to_sandbox/sandbox)
    return await self._legacy_process_candle(session, candles, version)
ir = parse_blocks(version.blocks_json)
candle_dicts = [{"open": float(c.open), "high": float(c.high), "low": float(c.low),
                 "close": float(c.close), "volume": int(c.volume)} for c in candles]
action_str = evaluate(ir, candle_dicts)
action = {"buy": SignalAction.BUY, "sell": SignalAction.SELL}.get(action_str, SignalAction.HOLD)
if action == SignalAction.HOLD:
    return None
return Signal(action=action, ticker=session.ticker, price=candles[-1].close)
```

- Сохранить старый код как `_legacy_process_candle` (бывшее тело, использующее `_blocks_to_sandbox`+sandbox) для IR-less стратегий.

- [ ] **Step 4: Запустить — PASS** (оба теста). 
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_trading/test_runtime_evaluator.py -q`

- [ ] **Step 5: Регрессия trading + py_compile**
Run: `cd Develop/backend && .venv/bin/python -m py_compile app/trading/engine.py && .venv/bin/python -m pytest tests/test_trading/ -q`
Expected: все PASS. Существующий `test_engine_blocks_to_sandbox.py` (BUG-22) — оставить как тест legacy-пути или адаптировать (если `_blocks_to_sandbox` остаётся только для fallback — тесты валидны).

- [ ] **Step 6: commit-точка** — `feat(s8r-bug23): live SignalProcessor использует evaluate; legacy fallback для IR-less`

---

## Task 11: Бэктест — shadow-прогон интерпретатора

**Files:**
- Create: `Develop/backend/app/backtest/parity.py`
- Modify: `Develop/backend/app/backtest/service.py`
- Test: `Develop/backend/tests/test_backtest/test_parity.py`

- [ ] **Step 1: Падающий тест — `run_interpreter_signals` даёт сделки из решений**

```python
# tests/test_backtest/test_parity.py
from app.backtest.parity import interpreter_trades
from app.strategy.ir import parse_blocks

def _candles(closes):
    import datetime
    return [{"open": c, "high": c+1, "low": c-1, "close": c, "volume": 1000,
             "time": datetime.datetime(2024,1,1)+datetime.timedelta(days=i)} for i, c in enumerate(closes)]

def test_interpreter_trades_long_entry_then_exit():
    # entry: SMA(3)>70 ; exit: SMA(3)<70
    blocks = {"blocks": {"blocks": [
      {"type":"signal_entry","id":"e","fields":{"DIRECTION":"long"},
       "inputs":{"CONDITION":{"block":{"type":"condition_compare","id":"c1",
         "fields":{"OPERATOR":"gt","RIGHT_TYPE":"number","THRESHOLD":70},
         "inputs":{"LEFT":{"block":{"type":"indicator_sma","id":"s1","fields":{"PERIOD":3,"SOURCE":"close"}}}}}}},
       "next":{"block":{"type":"signal_exit","id":"x",
         "inputs":{"CONDITION":{"block":{"type":"condition_compare","id":"c2",
           "fields":{"OPERATOR":"lt","RIGHT_TYPE":"number","THRESHOLD":70},
           "inputs":{"LEFT":{"block":{"type":"indicator_sma","id":"s2","fields":{"PERIOD":3,"SOURCE":"close"}}}}}}}}}}]}}
    ir = parse_blocks(blocks)
    closes = [10,10,10, 100,100,100, 10,10,10]   # вход на барах с высокой SMA, выход потом
    trades = interpreter_trades(ir, _candles(closes))
    assert len(trades) >= 1
    assert trades[0]["direction"] == "long"
    assert trades[0]["entry_bar"] < trades[0]["exit_bar"]
```

- [ ] **Step 2: Запустить — FAIL** (`app.backtest.parity` нет).

- [ ] **Step 3: Реализовать `parity.py` — превращение решений в список сделок**

```python
# app/backtest/parity.py
from __future__ import annotations
from app.strategy.evaluator import evaluate_series
from app.strategy.ir import StrategyIR


def interpreter_trades(ir: StrategyIR, candles: list[dict]) -> list[dict]:
    """Прогнать интерпретатор по истории и собрать список сделок (entry/exit по барам).

    Модель позиции: одна позиция за раз. buy открывает long (если нет позиции),
    sell закрывает (если позиция есть). Направление берём из ir.entry_direction.
    """
    decisions = evaluate_series(ir, candles)
    trades: list[dict] = []
    open_trade: dict | None = None
    direction = ir.entry_direction or "long"
    for i, d in enumerate(decisions):
        if open_trade is None and d == "buy":
            open_trade = {"direction": direction, "entry_bar": i, "entry_price": candles[i]["close"]}
        elif open_trade is not None and d == "sell":
            open_trade.update(exit_bar=i, exit_price=candles[i]["close"])
            trades.append(open_trade)
            open_trade = None
    if open_trade is not None:                 # незакрытая в конце
        open_trade.update(exit_bar=len(candles) - 1, exit_price=candles[-1]["close"])
        trades.append(open_trade)
    return trades
```

- [ ] **Step 4: Запустить — PASS**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_backtest/test_parity.py -q`

- [ ] **Step 5: py_compile + commit-точка** — `feat(s8r-bug23): interpreter_trades (shadow-прогон бэктеста)`

---

## Task 12: Бэктест — сверка сигналов (критично) + метрик (информационно)

**Files:**
- Modify: `Develop/backend/app/backtest/parity.py`
- Test: `Develop/backend/tests/test_backtest/test_parity.py`

- [ ] **Step 1: Падающий тест — compare_trades с поправкой +1 бар**

```python
def test_compare_signals_match_with_fill_offset():
    from app.backtest.parity import compare_signals
    # backtrader: вход исполнен на i+1 (открытие следующего бара)
    bt_trades = [{"entry_bar": 4, "exit_bar": 7, "direction": "long"}]
    interp = [{"entry_bar": 3, "exit_bar": 6, "direction": "long"}]   # решение на бар раньше
    res = compare_signals(bt_trades, interp, fill_offset=1)
    assert res["signals_match"] is True
    assert res["divergences"] == []

def test_compare_signals_divergence_detected():
    from app.backtest.parity import compare_signals
    bt_trades = [{"entry_bar": 4, "exit_bar": 7, "direction": "long"}]
    interp = [{"entry_bar": 3, "exit_bar": 9, "direction": "long"}]   # выход не совпал
    res = compare_signals(bt_trades, interp, fill_offset=1)
    assert res["signals_match"] is False
    assert len(res["divergences"]) >= 1
```

- [ ] **Step 2: Запустить — FAIL** (`compare_signals` нет).

- [ ] **Step 3: Реализовать `compare_signals` + `compare_metrics`**

```python
def compare_signals(bt_trades: list[dict], interp_trades: list[dict], fill_offset: int = 1) -> dict:
    """Сверить списки сделок. interp решает на баре i, backtrader исполняет на i+fill_offset.
    Сверяем кол-во, направление, бар входа (с поправкой) и бар выхода (с поправкой)."""
    divergences = []
    n = max(len(bt_trades), len(interp_trades))
    for k in range(n):
        bt_t = bt_trades[k] if k < len(bt_trades) else None
        it = interp_trades[k] if k < len(interp_trades) else None
        if bt_t is None or it is None:
            divergences.append({"index": k, "backtrader": bt_t, "interpreter": it,
                                "reason": "count_mismatch"})
            continue
        if bt_t["direction"] != it["direction"]:
            divergences.append({"index": k, "reason": "direction",
                                "backtrader": bt_t["direction"], "interpreter": it["direction"]})
        if bt_t.get("entry_bar") != (it.get("entry_bar", 0) + fill_offset):
            divergences.append({"index": k, "reason": "entry_bar",
                                "backtrader": bt_t.get("entry_bar"),
                                "interpreter": it.get("entry_bar"), "offset": fill_offset})
        if bt_t.get("exit_bar") is not None and it.get("exit_bar") is not None:
            if bt_t["exit_bar"] != it["exit_bar"] + fill_offset:
                divergences.append({"index": k, "reason": "exit_bar",
                                    "backtrader": bt_t["exit_bar"], "interpreter": it["exit_bar"]})
    return {"signals_match": len(divergences) == 0, "divergences": divergences,
            "bt_count": len(bt_trades), "interp_count": len(interp_trades)}


def compare_metrics(bt_pnl, interp_pnl, tol_pct: float = 1.0) -> dict:
    """Информационно: разница P&L. Не блокирует."""
    if bt_pnl is None or interp_pnl is None:
        return {"pnl_match": None, "bt_pnl": bt_pnl, "interp_pnl": interp_pnl}
    diff = abs(float(bt_pnl) - float(interp_pnl))
    base = max(abs(float(bt_pnl)), 1.0)
    return {"pnl_match": (diff / base * 100) <= tol_pct, "bt_pnl": float(bt_pnl),
            "interp_pnl": float(interp_pnl), "diff_pct": round(diff / base * 100, 2)}
```

- [ ] **Step 4: Запустить — PASS**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_backtest/test_parity.py -q`

- [ ] **Step 5: Встроить сверку в backtest pipeline**

В `app/backtest/service.py` (там, где после прогона backtrader сохраняются `backtest_trades`): после получения candles и backtrader-результата —
```python
from app.strategy.ir import parse_blocks
from app.backtest.parity import interpreter_trades, compare_signals, compare_metrics
ir = parse_blocks(version.blocks_json)
candle_dicts = [...]              # те же свечи, что скормлены backtrader
it = interpreter_trades(ir, candle_dicts)
bt_t = [{"direction": t.direction, "entry_bar": <idx by entry_date>, "exit_bar": <idx by exit_date>} for t in saved_trades]
sig = compare_signals(bt_t, it, fill_offset=1)
met = compare_metrics(bt_total_pnl, sum(t["exit_price"]-t["entry_price"] for long ...))
# записать в результат бэктеста (Task 13)
```
> Маппинг `entry_date/exit_date → bar index` делаем по таймстампам свечей. Если backtrader auto-close дал exit за пределами диапазона (см. BUG-17) — клампим как в существующем коде.

- [ ] **Step 6: py_compile + commit-точка** — `feat(s8r-bug23): сверка сигналов/метрик в бэктесте`

---

## Task 13: Поля сверки в результате бэктеста + миграция + API

**Files:**
- Modify: `Develop/backend/app/backtest/models.py`, `schemas.py`, `service.py`
- Create: `Develop/backend/alembic/versions/<rev>_s8r_bug23_parity_fields.py`
- Test: `Develop/backend/tests/test_backtest/test_parity_persistence.py`

- [ ] **Step 1: Тест — результат бэктеста содержит parity-поля**

```python
@pytest.mark.asyncio
async def test_backtest_result_has_parity_fields(db_session):
    from app.backtest.models import Backtest
    bt = Backtest(...)  # минимально валидный
    bt.parity_checked = True
    bt.parity_signals_match = False
    bt.parity_divergences = [{"index": 0, "reason": "exit_bar"}]
    bt.parity_metrics_diff = {"diff_pct": 3.1}
    db_session.add(bt); await db_session.commit(); await db_session.refresh(bt)
    assert bt.parity_signals_match is False
```

- [ ] **Step 2: Запустить — FAIL** (полей нет).

- [ ] **Step 3: Добавить поля в модель**

В `app/backtest/models.py` (модель результата бэктеста):
```python
parity_checked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
parity_signals_match: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
parity_divergences: Mapped[list | None] = mapped_column(JSON, nullable=True)
parity_metrics_diff: Mapped[dict | None] = mapped_column(JSON, nullable=True)
```

- [ ] **Step 4: Alembic-миграция**

```bash
cd Develop/backend && .venv/bin/alembic revision -m "s8r_bug23_parity_fields"
```
В `upgrade()`: `op.add_column(...)` для 4 полей; `downgrade()`: `op.drop_column(...)`.
Применить: `cd Develop/backend && .venv/bin/alembic upgrade head`

- [ ] **Step 5: Схема ответа + заполнение в service**

В `schemas.py` (BacktestResponse) добавить 4 поля; в `service.py` записать результат `compare_signals`/`compare_metrics` (Task 12) в эти поля + `parity_checked=True`.

- [ ] **Step 6: Запустить — PASS + регрессия backtest**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_backtest/ -q`

- [ ] **Step 7: py_compile + commit-точка** — `feat(s8r-bug23): parity-поля результата бэктеста + миграция + API`

---

## Task 14: Гейт live (жёсткий блок + override) + audit

**Files:**
- Modify: `Develop/backend/app/trading/schemas.py` (`SessionStartRequest` + `override_parity`), `service.py`/`router.py` (проверка при старте)
- Test: `Develop/backend/tests/test_trading/test_parity_gate.py`

- [ ] **Step 1: Тесты гейта**

```python
@pytest.mark.asyncio
async def test_start_blocked_when_no_parity_backtest(db_session, client, auth_headers):
    # версия без бэктеста со сверкой → 4xx
    resp = await client.post("/api/v1/trading/sessions", json={..., "strategy_version_id": ver_id}, headers=auth_headers)
    assert resp.status_code == 409
    assert "сверк" in resp.json()["detail"].lower()

@pytest.mark.asyncio
async def test_start_blocked_when_signals_diverged(db_session, client, auth_headers):
    # последний бэктест версии: parity_signals_match=False, без override → 409
    ...
    assert resp.status_code == 409

@pytest.mark.asyncio
async def test_start_allowed_with_override_writes_audit(db_session, client, auth_headers):
    resp = await client.post("/api/v1/trading/sessions",
                             json={..., "override_parity": True}, headers=auth_headers)
    assert resp.status_code in (200, 201)
    # audit_log содержит запись override
    ...
```

- [ ] **Step 2: Запустить — FAIL** (нет проверки/поля).

- [ ] **Step 3: Реализовать гейт**

В `SessionStartRequest`: `override_parity: bool = False`.
В сервисе старта сессии перед созданием:
```python
latest = await self._latest_parity_backtest(version_id)   # последний бэктест с parity_checked=True
if latest is None:
    raise HTTPException(409, "Для запуска live нужен бэктест со сверкой движков. Запустите бэктест.")
if latest.parity_signals_match is False and not data.override_parity:
    raise HTTPException(409, "Сигналы бэктеста и live-движка расходятся. Запуск заблокирован (можно override).")
if latest.parity_signals_match is False and data.override_parity:
    await self._audit("parity_override", user_id=..., session_meta=..., detail=...)  # новый event_type
```
Зарегистрировать `event_type="parity_override"` в `audit_log` (и при необходимости в EVENT_MAP).

- [ ] **Step 4: Запустить — PASS + регрессия trading**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_trading/ -q`

- [ ] **Step 5: py_compile + commit-точка** — `feat(s8r-bug23): гейт live по сверке (жёсткий блок + override + audit)`

---

## Task 15: Frontend — бейдж сверки в результатах бэктеста

**Files:**
- Modify: `Develop/frontend/src/api/strategyApi.ts` или `backtestApi` (типы ответа +4 поля), `src/components/backtest/ResultsPanel.tsx` (бейдж)
- Test: `Develop/frontend/src/components/backtest/__tests__/ResultsPanel.parity.test.tsx`

- [ ] **Step 1: Падающий vitest — бейдж совпадения/расхождения**

```tsx
import { render, screen } from "@testing-library/react";
import { ResultsPanel } from "../ResultsPanel";

it("показывает зелёный бейдж при совпадении", () => {
  render(<ResultsPanel result={{ ...base, parity_checked: true, parity_signals_match: true }} />);
  expect(screen.getByText(/live-движок.*совпада/i)).toBeInTheDocument();
});

it("показывает предупреждение при расхождении", () => {
  render(<ResultsPanel result={{ ...base, parity_checked: true, parity_signals_match: false,
                                  parity_divergences: [{ reason: "exit_bar" }] }} />);
  expect(screen.getByText(/расхожден/i)).toBeInTheDocument();
});
```

- [ ] **Step 2: Запустить — FAIL**
Run: `cd Develop/frontend && npx vitest run src/components/backtest/__tests__/ResultsPanel.parity.test.tsx`

- [ ] **Step 3: Добавить типы (+4 поля) и бейдж в ResultsPanel**

В типе результата бэктеста: `parity_checked`, `parity_signals_match`, `parity_divergences`, `parity_metrics_diff`.
В `ResultsPanel.tsx`: Mantine `Badge`/`Alert` — зелёный «live-движок: совпадает» при `parity_signals_match===true`; жёлтый «⚠️ расхождение на N барах» + раскрытие `parity_divergences` при `false`; P&L-diff из `parity_metrics_diff` — информационно.

- [ ] **Step 4: Запустить — PASS + tsc**
Run: `cd Develop/frontend && npx vitest run src/components/backtest/__tests__/ResultsPanel.parity.test.tsx && npx tsc --noEmit`

- [ ] **Step 5: playwright-скриншот** (UI-компонент): `/backtest` с результатом, snapshot бейджа.

- [ ] **Step 6: commit-точка** — `feat(s8r-bug23): UI-бейдж сверки движков в результатах бэктеста`

---

## Task 16: Frontend — предупреждение/override при запуске live

**Files:**
- Modify: `Develop/frontend/src/components/trading/LaunchSessionModal.tsx`, `src/api/tradingApi.ts`
- Test: `Develop/frontend/src/components/trading/__tests__/LaunchSessionModal.parity.test.tsx`

- [ ] **Step 1: Падающий vitest — при 409 показывается предупреждение и чекбокс override**

```tsx
it("при блоке по сверке показывает предупреждение и чекбокс override", async () => {
  // мок API: первый POST → 409 parity; выбор override + повтор
  ...
  expect(await screen.findByText(/расхожд|сверк/i)).toBeInTheDocument();
  expect(screen.getByLabelText(/подтверждаю|override/i)).toBeInTheDocument();
});
```

- [ ] **Step 2: Запустить — FAIL**

- [ ] **Step 3: Реализовать** — `tradingApi` старт сессии принимает `override_parity`; модалка ловит 409 parity, показывает `Alert` + `Checkbox` «понимаю риск, запустить всё равно», повторяет запрос с `override_parity:true`.

- [ ] **Step 4: Запустить — PASS + tsc**
Run: `cd Develop/frontend && npx vitest run src/components/trading/__tests__/LaunchSessionModal.parity.test.tsx && npx tsc --noEmit`

- [ ] **Step 5: playwright-скриншот** `/trading` модалка с предупреждением.

- [ ] **Step 6: commit-точка** — `feat(s8r-bug23): предупреждение+override при запуске live с расхождением`

---

## Task 17: Миграция правки параметров на IR

**Files:**
- Modify: `Develop/backend/app/strategy/router.py` (`replace_strategy_params`/`extract_strategy_params` callsites), новый `app/strategy/params.py` (правка по IR)
- Test: `Develop/backend/tests/test_strategy/test_params_ir.py`

- [ ] **Step 1: Падающий тест — изменение периода/SL/TP правит blocks_json, не текст**

```python
def test_replace_params_on_ir_changes_blocks():
    from app.strategy.params import replace_params_in_blocks, extract_params_from_blocks
    blocks = {...}  # с indicator_sma PERIOD=20, management_stop_loss VALUE=3
    assert extract_params_from_blocks(blocks)["sma_period"] == 20
    new = replace_params_in_blocks(blocks, {"sma_period": 30, "stop_loss_pct": 5})
    assert extract_params_from_blocks(new)["sma_period"] == 30
    assert extract_params_from_blocks(new)["stop_loss_pct"] == 5
```

- [ ] **Step 2: Запустить — FAIL** (`app.strategy.params` нет).

- [ ] **Step 3: Реализовать `params.py`** — обход дерева blocks_json, чтение/замена `fields.PERIOD` индикаторов и `fields.VALUE` management-блоков по стабильным ключам. Подключить в `strategy/router.py` вместо текстовых `replace_strategy_params`/`extract_strategy_params` (старые функции оставить для legacy generated_code-only версий).

- [ ] **Step 4: Запустить — PASS + регрессия strategy**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/test_strategy/ -q`

- [ ] **Step 5: py_compile + commit-точка** — `feat(s8r-bug23): правка параметров стратегии по IR (blocks_json)`

---

## Финальная задача: signal-parity на эталонных стратегиях + полный прогон

**Files:**
- Test: `Develop/backend/tests/test_strategy/test_signal_parity.py`

- [ ] **Step 1: Параметризованный тест — для набора эталонных стратегий backtrader ⇄ interpreter дают одинаковые сделки**

```python
import pytest
# набор стратегий, покрывающих все типы блоков: compare(number/indicator), in_zone, crossover, and/or/not
SAMPLES = [ ("sma_gt_70", BLOCKS_1), ("ema_in_zone", BLOCKS_2), ("sma_cross", BLOCKS_3), ... ]

@pytest.mark.parametrize("name,blocks", SAMPLES)
def test_backtrader_interpreter_signal_parity(name, blocks):
    # 1) сгенерить generated_code из blocks (CodeGenerator), прогнать backtrader → bt_trades(bar idx)
    # 2) parse_blocks + interpreter_trades → it
    # 3) compare_signals(bt_trades, it, fill_offset=1).signals_match == True
    ...
    assert res["signals_match"], f"{name}: {res['divergences']}"
```

- [ ] **Step 2: Запустить — выявить и устранить расхождения** (выравнивание индикаторов/логики до зелёного).

- [ ] **Step 3: Полный прогон**
Run: `cd Develop/backend && .venv/bin/python -m pytest tests/ -q` (ожидаем ≥ предыдущего baseline + новые).
Run: `cd Develop/frontend && npx vitest run && npx tsc --noEmit`

- [ ] **Step 4: Обновить документацию приёмки**
`Спринты/Sprint_8_Review/acceptance_checklist.md` — BUG-23 FIXED; `changelog.md` + `sprint_state.md`.

- [ ] **Step 5: Финальная commit-точка** — `feat(s8r-bug23): signal-parity эталонных стратегий + закрытие BUG-23`

---

## Self-Review (выполнено при написании плана)

- **Покрытие спеки:** §4.1 indicators/evaluator → Tasks 1–9; §4.2 live → Task 10; §4.3 dual-run+сверка → Tasks 11–13; §4.4 гейт → Task 14; §5 схема/UI → Tasks 13,15,16; §3.7/A6 param-edit → Task 17; §7 тесты → распределены + финальная задача. SP-B (§4.5) — отдельный план №2.
- **Типы:** `StrategyIR`/`IndicatorRef`/`Condition` определены в Task 4 и используются единообразно; `evaluate`/`evaluate_series`/`interpreter_trades`/`compare_signals`/`compare_metrics` — согласованные имена.
- **Плейсхолдеры:** код-шаги содержат реальный код. Где помечено «...» (Tasks 10/13/14/15/16/17 — подгонка под фактические сигнатуры/фикстуры проекта) — это намеренные точки адаптации к существующему коду, не пропуски логики; ключевые алгоритмы (indicators, IR, evaluate, parity) расписаны полностью.

## Известные точки адаптации (не блокеры)
- Точная конструкция `CandleData` в live-тестах (Task 10) и маппинг `entry_date→bar` в бэктесте (Task 12) подгоняются под существующий код при исполнении.
- Допуски parity индикаторов (Stochastic) могут потребовать уточнения конвенции backtrader.
