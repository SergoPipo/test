# Sprint 6 — Sprint State

> Текущее состояние спринта. Обновляется после каждой волны.

## Общий прогресс

| Волна | Статус | DEV-агенты | Результат |
|-------|--------|------------|-----------|
| 0 (Preflight + багфикс) | ⬜ не начата | DEV-0 | — |
| 1 (Backend ядро) | ⬜ не начата | DEV-1, DEV-2, DEV-3 | — |
| 2 (Frontend + Infra) | ⬜ не начата | DEV-4, DEV-5, DEV-6 | — |
| 3 (E2E + ARCH) | ⬜ не начата | DEV-7, ARCH | — |

**Легенда:** ⬜ не начата · 🔄 в процессе · ✅ завершена · ⚠️ завершена с замечаниями

## Детализация по DEV-агентам

| DEV | Задачи | Волна | Статус | Отчёт |
|-----|--------|-------|--------|-------|
| DEV-0 | S6-STRATEGY-UNDERSCORE-NAMES | 0 | ⬜ | — |
| DEV-1 | 6.3 In-app WS + 6.4 Recovery + 6.5 Shutdown | 1 | ⬜ | — |
| DEV-2 | 6.1 Telegram + 6.2 Email | 1 | ⬜ | — |
| DEV-3 | S6-TINVEST-SDK-UPGRADE | 1 | ⬜ | — |
| DEV-4 | 6.7 Notification Center + 6.8 Trading Panel | 2 | ⬜ | — |
| DEV-5 | S6-TINVEST-STREAM-MULTIPLEX | 2 | ⬜ | — |
| DEV-6 | PLAYWRIGHT-NIGHTLY + E2E-MOCK-ISS + MOCKS | 2 | ⬜ | — |
| DEV-7 | 6.9 E2E S6 + 6.10 Security | 3 | ⬜ | — |
| ARCH | Финальное ревью | 3 | ⬜ | — |

## Merge Gates

| Гейт | Условие | Статус |
|-------|---------|--------|
| Волна 0 → 1 | DEV-0 merged, pytest=0, pnpm test=0 | ⬜ |
| Волна 1 → 2 | DEV-1,2,3 merged (порядок: 1→2→3), pytest=0, pnpm test=0 | ⬜ |
| Волна 2 → 3 | DEV-4,5,6 merged, pytest=0, pnpm test=0 | ⬜ |

## Открытые вопросы

_(пусто — заполняется по ходу спринта)_

## Блокеры

| Блокер | Описание | Статус |
|--------|----------|--------|
| S6-STRATEGY-UNDERSCORE-NAMES | code_generator.py генерирует `_`-имена → RestrictedPython отбрасывает → живая торговля не работает | ⬜ DEV-0 |
