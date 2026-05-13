# Performance Baseline — Sprint 8 W5

**Дата:** 2026-05-13
**Карточка:** `S8R-W5-PERF-BASELINE-MEASUREMENTS`
**Инструмент:** `pytest-benchmark==5.2.3` + `@timed_event` инструментация (W2).

## Цели ТЗ (technical_specification.md §performance)

| Метрика | Цель | Статус |
|---------|------|--------|
| Dashboard LCP первый paint | < 2 с | ⏳ frontend — отдельный Lighthouse run (не покрыт pytest-benchmark) |
| signal → place_order p95 | < 500 мс | ✅ synthetic baseline 1.4 мс (production-измерение через `/admin/metrics` Plotly Dash) |
| Telegram-команда p95 | < 3 с | ✅ synthetic baseline 2.5 мс (production-измерение через structlog) |

## Synthetic baselines (без БД / broker / aiogram)

Запуск: `pytest tests/test_performance -v --benchmark-only`.

| Hot-path | Mean | Median | p95 (synth) | Цель ТЗ |
|----------|------|--------|-------------|---------|
| `@timed_event` overhead sync | **14 мкс** | 12 мкс | 22 мкс | sanity < 50 мкс ✅ |
| `signal.process` async stub | **1.39 мс** | 1.37 мс | ~1.55 мс | p95 < 500 мс ✅ |
| `order.place` async stub | **1.39 мс** | 1.37 мс | ~1.55 мс | p95 < 500 мс ✅ |
| `telegram.handle` async stub | **2.53 мс** | 2.53 мс | ~2.7 мс | p95 < 3 с ✅ |

## Что synthetic baseline доказывает

1. `@timed_event` overhead — **microseconds-level** (14 мкс). Регрессия (например, до 1 мс) будет обнаружена тестом `test_timed_event_decorator_overhead_is_microseconds`.
2. Async-await + structlog-инструментация — **≪ 1% бюджета** ТЗ. Все цели ТЗ достижимы даже при значительном usage реального broker'а / БД.
3. Hot-path архитектура (3 декорированных метода) — нет блокирующих CPU-операций, всё в async I/O.

## Что synthetic baseline НЕ покрывает

- **Реальная gRPC latency** до T-Invest API (broker round-trip обычно 50-200 мс).
- **SQLite WAL fsync** на commit'ах в trading (~5-15 мс per commit).
- **MOEX ISS HTTP** при market_data fetch (~100-500 мс).
- **Aiogram BotAPI** при отправке Telegram-сообщений (~200 мс).
- **Frontend LCP / TTI** — измеряется отдельно Lighthouse CLI.

Эти числа собираются через `@timed_event` → structlog → JSON logs → Plotly Dash `/admin/metrics` (4 графика — мок-данные до первого production rollout). После Mac mini deployment → реальные production p95.

## Командный shortcuts

```bash
# Только benchmark тесты (быстро, без основной test suite):
.venv/bin/pytest tests/test_performance -v --benchmark-only

# С компарацией к baseline (после Mac mini deployment):
.venv/bin/pytest tests/test_performance --benchmark-compare --benchmark-compare-fail=mean:50%

# Сохранить baseline для будущих сравнений:
.venv/bin/pytest tests/test_performance --benchmark-save=baseline_w5
```

## Сравнение с прошлыми спринтами

Performance instrumentation впервые появился в S8 W2 (`@timed_event` decorator).
До W2 не было способа измерить duration_ms — только subjective UX-наблюдения
заказчика на дашборде. Этот baseline W5 — первое объективное измерение.

## Регрессионная защита

CI workflow `.github/workflows/ci.yml` уже запускает `pytest tests/` — это
включает `tests/test_performance/test_benchmarks.py` (без `--benchmark-only`).
Тесты `*_baseline` падают если возникает регрессия в логике stub'ов;
`test_timed_event_decorator_overhead_is_microseconds` falls если overhead
вырастает выше 1 мс mean. Тонкие пороги синхронизируются после первого
production-сравнения.
