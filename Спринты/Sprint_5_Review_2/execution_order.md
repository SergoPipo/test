# Sprint_5_Review_2 — Execution Order

> Порядок выполнения треков + Cross-DEV contracts. Детальные планы в `PENDING_S5R2_track*.md`, затем (этап B) в `prompt_DEV-*.md`.

## Статус

- **Патч-цикл:** 🔄 в процессе — этап A (скелет создан 2026-04-16)
- **Активная фаза:** этап A — детализация `PENDING_S5R2_track*.md` файлов
- **Следующая фаза:** этап B — создание `preflight_checklist.md` + `prompt_DEV-*.md` по `Спринты/prompt_template.md`

## Последовательность выполнения

```
Фаза 0: Планирование (до запуска DEV-сессий)
├── этап A (ТЕКУЩИЙ)
│   ├── README.md, backlog.md, execution_order.md — созданы (скелеты)
│   ├── PENDING_S5R2_track*.md файлы — созданы (скелеты, детализация TODO)
│   ├── project_state.md — уже отмечен S5R-2 в предыдущей сессии
│   └── Cross-DEV contracts (ниже) — заполнить при детализации треков
└── этап B
    ├── preflight_checklist.md — создать
    ├── prompt_DEV-*.md (по одному на трек) — по `Спринты/prompt_template.md`
    └── prompt_ARCH_review.md — финальное ревью S5R-2

Фаза 1: UX-блокер
└── DEV (сессия) → Трек 4 (401 после релогина)
    Вывод: пользователь может перезайти без ошибок

Фаза 2: Быстрые фиксы (параллельно)
├── DEV (сессия) → Трек 5 (TF-aware upsertLiveCandle)
└── DEV (сессия) → Трек 3 (sequential-index mode)

Фаза 3: Крупные backend-треки (параллельно)
├── DEV (сессия) → Трек 1 (backend prefetch)
└── DEV (сессия) → Трек 2 (backend live-агрегация 1m→D/1h/4h)

Фаза 4: Финальное ревью
└── ARCH → arch_review_s5r2.md + оценка применения prompt_template.md на 5 сессиях

Фаза 5: Закрытие S5R-2
├── Коммиты+push в оба репо (по трекам отдельными ветками)
├── project_state.md — S5R-2 ✅
└── S5R-2 закрыт, S6 продолжает независимо
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
