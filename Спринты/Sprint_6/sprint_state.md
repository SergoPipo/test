# Sprint 6 — Sprint State

> Текущее состояние спринта. Обновляется после каждой волны.

## Общий прогресс

| Волна | Статус | DEV-агенты | Результат |
|-------|--------|------------|-----------|
| 0 (Preflight + багфикс) | ✅ завершена | DEV-0 | 207 passed, 0 failed; blocker устранён |
| 1 (Backend ядро) | ✅ завершена | DEV-1, DEV-2, DEV-3 | 654 passed, 0 failed; ruff 0 errors |
| 2 (Frontend + Infra) | ✅ завершена | DEV-4, DEV-5, DEV-6 | pytest 662=0f, vitest 250=0f, ruff 0 errors |
| 3 (E2E + ARCH) | ✅ завершена | DEV-7 ✅, ARCH ✅ | 10 E2E + 23 security = 33 passed |

**Легенда:** ⬜ не начата · 🔄 в процессе · ✅ завершена · ⚠️ завершена с замечаниями

## Детализация по DEV-агентам

| DEV | Задачи | Волна | Статус | Отчёт |
|-----|--------|-------|--------|-------|
| DEV-0 | S6-STRATEGY-UNDERSCORE-NAMES | 0 | ✅ | reports/DEV-0_report.md |
| DEV-1 | 6.3 In-app WS + 6.4 Recovery + 6.5 Shutdown | 1 | ✅ | reports/DEV-1_report.md |
| DEV-2 | 6.1 Telegram + 6.2 Email | 1 | ✅ | reports/DEV-2_report.md |
| DEV-3 | S6-TINVEST-SDK-UPGRADE | 1 | ✅ | reports/DEV-3_report.md |
| DEV-4 | 6.7 Notification Center + 6.8 Trading Panel | 2 | ✅ | reports/DEV-4_report.md |
| DEV-5 | S6-TINVEST-STREAM-MULTIPLEX | 2 | ✅ | reports/DEV-5_report.md |
| DEV-6 | PLAYWRIGHT-NIGHTLY + E2E-MOCK-ISS + MOCKS | 2 | ✅ | reports/DEV-6_report.md |
| DEV-7 | 6.9 E2E S6 + 6.10 Security | 3 | ✅ | reports/DEV-7_report.md |
| ARCH | Финальное ревью | 3 | ✅ | arch_review_s6.md |

## Merge Gates

| Гейт | Условие | Статус |
|-------|---------|--------|
| Волна 0 → 1 | DEV-0 merged, pytest=0, pnpm test=0 | ✅ (pytest 623=0f, vitest 238=0f) |
| Волна 1 → 2 | DEV-1,2,3 merged (порядок: 1→2→3), pytest=0, pnpm test=0 | ✅ (pytest 654=0f, ruff 0 errors) |
| Волна 2 → 3 | DEV-4,5,6 merged, pytest=0, pnpm test=0 | ✅ (pytest 662=0f, vitest 250=0f) |

## Открытые вопросы

_(пусто — заполняется по ходу спринта)_

## Блокеры

| Блокер | Описание | Статус |
|--------|----------|--------|
| S6-STRATEGY-UNDERSCORE-NAMES | code_generator.py генерирует `_`-имена → RestrictedPython отбрасывает → живая торговля не работает | ✅ DEV-0 (2026-04-17) |
