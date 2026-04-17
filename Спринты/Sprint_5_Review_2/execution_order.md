# Sprint_5_Review_2 — Execution Order

> Порядок выполнения треков + Cross-DEV contracts. Детальные планы в `PENDING_S5R2_track*.md`, затем (этап B) в `prompt_DEV-*.md`.

## Статус

- **Патч-цикл:** 🔄 в процессе — фазы 1–2 завершены, фаза 3 далее
- **Активная фаза:** фаза 3 — backend-треки 1 и 2 (детализация + DEV-сессии)
- **Завершено:** фаза 1 (трек 4), фаза 2 (треки 3+5)

## Последовательность выполнения

```
Фаза 0: Планирование ✅
├── этап A ✅ — скелеты + детализация PENDING-файлов (треки 3–5)
└── этап B ✅ (треки 3–5) — prompt_DEV-track3/4/5.md созданы и выполнены

Фаза 1: UX-блокер ✅
└── Трек 4 (401 после релогина) — коммит 67c29fa
    cleanup + guard + ChartPage defer + gotcha-16

Фаза 2: Быстрые фиксы ✅
├── Трек 5 (TF-aware upsertLiveCandle) — отчёт: reports/DEV-track5_report.md
└── Трек 3 (sequential-index mode) — отчёт: reports/DEV-track3_report.md

Фаза 3: Крупные backend-треки (параллельно) ← ТЕКУЩАЯ
├── DEV (сессия) → Трек 1 (backend prefetch) — требует детализации + prompt
└── DEV (сессия) → Трек 2 (backend live-агрегация 1m→D/1h/4h) — требует детализации + prompt

Фаза 4: Финальное ревью ✅
└── ARCH → arch_review_s5r2.md — ПРИНЯТ (0 критических, 1 minor)

Фаза 5: Закрытие S5R-2
├── Коммиты+push в оба репо
├── project_state.md — S5R-2 ✅
└── S5R-2 закрыт
```

### Почему трек 4 — первым

- 401 после релогина — UX-блокер: пользователь не может корректно продолжить работу после перезахода без полного перезапуска приложения/вкладки.
- Без понимания root-cause высок риск повторения регрессии в любом другом треке, который трогает authenticated-запросы свечей.

### Почему треки 3 и 5 — параллельно после трека 4

- Оба — короткие frontend-only задачи (~0.5 сессии каждая).
- Работают в разных файлах: трек 3 — `ChartPage.tsx`/`InstrumentChart.tsx` конфиг `lightweight-charts`, трек 5 — `stream/store.ts`/`upsertLiveCandle.ts`. Конфликты минимальны.

### Почему треки 1 и 2 — параллельно в последней фазе

- Треки 1 (prefetch) и 2 (live-агрегация) — backend-heavy, не пересекаются по файлам:
  - Трек 1 — `app/auth/router.py` (hook на логин), новый `app/market_data/prefetch.py`, фронтовый bootstrap store.
  - Трек 2 — `app/market_data/stream_manager.py`, новый `app/market_data/aggregator.py`, миграция для буферов 1m.
- Могут работать в изолированных git worktree без конфликтов.

---

## ⚠️ Cross-DEV Contracts

> **Обязательный раздел** начиная с Sprint 6 (и применяется в S5R / S5R-2).
>
> Правила:
> - Если DEV указан как **поставщик** — в отчёте явно подтверждает реализацию.
> - Если DEV указан как **потребитель** — в отчёте явно подтверждает использование.
> - Несоответствие контракта — **блокирующая ошибка** для оркестратора.

### Контракты Sprint_5_Review_2

TODO: заполнить после детализации PENDING-файлов. Ожидаемые точки соприкосновения:

| Поставщик | Потребитель | Контракт | Формат/сигнатура |
|-----------|-------------|----------|------------------|
| TODO (трек 1, backend) | TODO (трек 1, frontend bootstrap) | REST-эндпоинт prefetch свечей активных сессий | TODO |
| TODO (трек 2, backend aggregator) | TODO (существующий WS-клиент на фронте) | WS-сообщения с derived-TF | TODO |
| TODO (трек 5, store layer) | TODO (`ChartPage` subscribe) | фильтр тика по активному TF | TODO |

Контракты finalized **до** запуска DEV-сессий (конец этапа A / начало этапа B).

---

## Чек-лист этапа A

- [x] `README.md` создан
- [x] `backlog.md` создан (скелет, детализация TODO)
- [x] `execution_order.md` создан (скелет)
- [x] `PENDING_S5R2_track1_backend_prefetch.md` создан (скелет)
- [x] `PENDING_S5R2_track2_live_aggregation.md` создан (скелет)
- [x] `PENDING_S5R2_track3_sequential_index.md` создан (скелет)
- [x] `PENDING_S5R2_track4_401_unauthorized.md` создан (скелет)
- [x] `PENDING_S5R2_track5_tf_aware_upsert.md` создан (скелет)
- [ ] Все PENDING-файлы детализированы (root cause, решение, критерии готовности)
- [ ] Cross-DEV contracts заполнены
- [ ] Коммит скелета S5R-2 (спросить ветку у пользователя)
