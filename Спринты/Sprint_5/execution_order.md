# Sprint 5: Порядок выполнения задач

> **Цель:** Paper Trading, Circuit Breaker, Bond Service, налоговый экспорт
> **Milestone:** M3 — Paper Trading

---

## Фаза 0: Подготовка

| Шаг | Задача | Зависит от | Prompt |
|-----|--------|------------|--------|
| 0.0 | Предполётная проверка (ПО, зависимости, модули, файлы) | — | preflight_checklist.md |
| 0.1 | Закрыть отложенные задачи из S4 Review (#15, #16, #23, #24, #28) | 0.0 | — |

## Фаза 1: UX + Backend — ядро торговли (параллельные потоки)

Три независимых потока работ (Волна 1):

### Поток UX: Дизайн

| Шаг | Задача | Зависит от | Prompt |
|-----|--------|------------|--------|
| 1.0 | UX: дизайн Trading Panel, Account, Favorites, RT-графики | 0.0 | prompt_UX.md |

### Поток A: Trading Engine

| Шаг | Задача | Зависит от | Prompt |
|-----|--------|------------|--------|
| 1.1 | Trading Engine: session manager, signal processor, order manager, position tracker | 0.0 | prompt_DEV-1.md |
| 1.2 | Paper Trading Engine (виртуальный портфель, эмуляция T+1) | 1.1 | prompt_DEV-1.md |
| 1.4 | Broker Adapter: place_order, cancel_order, subscribe_candles (streaming) | 0.0 | prompt_DEV-1.md |
| 1.5 | Rate limiter для брокерского API (token bucket + персистентность) | 1.4 | prompt_DEV-1.md |

### Поток B: Bond + Налоги

| Шаг | Задача | Зависит от | Prompt |
|-----|--------|------------|--------|
| 1.6 | Bond Service (расчёт НКД) + Corporate Action Handler | 0.0 | prompt_DEV-3.md |
| 1.7 | Налоговый экспорт (Tax Report Generator, FIFO, 3-НДФЛ) | 1.6 | prompt_DEV-3.md |

## Фаза 1.5: Circuit Breaker (Волна 2)

| Шаг | Задача | Зависит от | Prompt |
|-----|--------|------------|--------|
| 1.3 | Circuit Breaker (daily loss, drawdown, position size, trade count, cooldown) | 1.1 | prompt_DEV-2.md |

## Фаза 2: Frontend (Волна 3)

| Шаг | Задача | Зависит от | Prompt |
|-----|--------|------------|--------|
| 2.2 | Trading Panel (карточки сессий, форма запуска, позиции, P&L) | 1.1, 1.0 | prompt_DEV-4.md |
| 2.3 | Real-time обновление графиков через WebSocket + индикаторы | 1.4, 1.0 | prompt_DEV-4.md |
| 2.4 | Экран «Счёт» (баланс, позиции, операции, налоговый отчёт) | 1.6, 1.0 | prompt_DEV-5.md |
| 2.5 | Панель «Избранные инструменты» (★ справа от графика) | 1.0 | prompt_DEV-5.md |

## Фаза 3: Тестирование и ревью (Волна 4)

| Шаг | Задача | Зависит от | Prompt |
|-----|--------|------------|--------|
| 3.1 | E2E-тесты: Paper Trading, Circuit Breaker, Bond P&L | Фаза 1 + 2 | prompt_ARCH_review.md |
| 3.2 | Архитектурное ревью S5 + QA-приёмка | всё | prompt_ARCH_review.md |

---

## Граф выполнения по волнам

```
Волна 0:  [0.0 Preflight] → [0.1 Отложенные задачи S4 Review]
              │
Волна 1:  ┌───┴─────────────────────────┐
          │ Поток UX                     │
          │ 1.0 UX дизайн               │
          ├─────────────────────────────┤
          │ Поток A                      │ Поток B
          │ 1.1 Trading Engine           │ 1.6 Bond Service
          │   └─ 1.2 Paper Trading       │   └─ 1.7 Налоги
          │ 1.4 Broker Adapter           │
          │   └─ 1.5 Rate Limiter        │
          └───┬─────────────────────────┘
              │
Волна 2:  1.3 Circuit Breaker (зависит от 1.1)
              │
Волна 3:  ┌───┴─────────────────────────┐
          │ 2.2 Trading Panel            │ 2.4 Экран «Счёт»
          │ 2.3 Real-time графики        │ 2.5 Избранные ★
          └───┬─────────────────────────┘
              │
Волна 4:  3.1 E2E тесты
          3.2 ARCH ревью
```

## Блокирующие правила

```
ПРАВИЛО 0: НИЧЕГО не запускается до Preflight (0.0)
  ✓ preflight_checklist.md — все пункты PASSED

ПРАВИЛО 1: DEV-2 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ DEV-1 (Trading Engine) завершён
  ✓ pytest tests/ = 0 failures

ПРАВИЛО 2: DEV-4 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ DEV-1 (Trading API endpoints) завершён
  ✓ UX: ui_spec_s5.md утверждён заказчиком
  ✓ pytest tests/ = 0 failures

ПРАВИЛО 3: DEV-5 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ DEV-3 (Bond + Tax API) завершён
  ✓ UX: ui_spec_s5.md утверждён заказчиком

ПРАВИЛО 4: ARCH НЕ ЗАПУСКАЕТСЯ пока:
  ✓ ВСЕ DEV-агенты завершили работу
  ✓ pytest + pnpm test = 0 failures
  ✓ Все миграции применены
```

## Критерий завершения Sprint 5

- Paper Trading запущен, сделки видны в реальном времени
- Circuit Breaker активен (все лимиты)
- Расчёт НКД и корп. действия работают
- Налоговый экспорт (FIFO, 3-НДФЛ) функционирует
- E2E-тесты пройдены
- Latency < 500ms
