# Sprint_5_Review_2 — Changelog

> Хронологический журнал выполнения треков S5R-2.
> Формат: дата → что изменено → файлы → результат.

---

## 2026-04-16 — Создание скелета S5R-2

**Контекст:** закрыт S5R wave 4 (фазы 3.3–3.7). Крупные треки chart-hardening вынесены в отдельный патч-цикл `Sprint_5_Review_2/` согласно handoff в `project_state.md`.

**Что сделано:**
- Создана папка `Спринты/Sprint_5_Review_2/`.
- Созданы базовые файлы (скелеты):
  - `README.md` — контекст патч-цикла, отличие от S5R, состав 5 треков.
  - `backlog.md` — сводная таблица, детализация в PENDING-файлах.
  - `execution_order.md` — порядок 4 → 5/3 → 1/2 → ARCH, шаблон Cross-DEV contracts.
  - `preflight_checklist.md` — чеклист перед каждой DEV-сессией.
  - `PENDING_S5R2_track1_backend_prefetch.md` — скелет плана трека 1.
  - `PENDING_S5R2_track2_live_aggregation.md` — скелет плана трека 2.
  - `PENDING_S5R2_track3_sequential_index.md` — скелет плана трека 3.
  - `PENDING_S5R2_track4_401_unauthorized.md` — скелет плана трека 4.
  - `PENDING_S5R2_track5_tf_aware_upsert.md` — скелет плана трека 5.
  - `changelog.md` — этот файл.

**Что НЕ сделано (на следующих итерациях этапа A):**
- Детализация каждого `PENDING_S5R2_track*.md`: root cause, решение, критерии готовности.
- Заполнение Cross-DEV contracts в `execution_order.md`.
- `arch_review_s5r2.md` — создаётся после финального ревью.

**Следующее действие:** согласовать с пользователем приоритет детализации PENDING-файлов (начать с трека 4 как UX-блокера?) и имя ветки для коммита скелета в корневом репо.

---

## 2026-04-16 — Трек 4: детализация плана (diagnose-first)

**Контекст:** пользователь утвердил начало S5R-2 с трека 4 (401 Unauthorized после релогина) как UX-блокера. Ветка: `docs/s5r2-skeleton-track4`.

**Что сделано:**
- Explore-агент изучил реальный код frontend (authStore, api client, marketDataStore, useWebSocket, e2e) и выдал карту архитектуры + 3 гипотезы root cause.
- `PENDING_S5R2_track4_401_unauthorized.md` переписан со скелета в полный план:
  - Секция «Контекст» — реальная архитектура (Zustand persist + axios interceptor + Zustand market store + singleton WS) с конкретными путями файлов и диапазонами строк.
  - Секция «Корень проблемы» — 3 пронумерованные гипотезы + побочные наблюдения (candlesCache не чистится, WS на старом токене).
  - Секция «План диагностики» — 7 шагов (воспроизведение → фиксация 401 → timing-трейс console.debug → localStorage-инспекция → backend JWT-декод → incognito → root cause).
  - Секция «Предлагаемое решение» — 4 варианта (cleanup hook / subscribe pattern / interceptor guard / ChartPage defer).
  - Секция «Затрагиваемые файлы» — 7 файлов (5 src + 2 test) + опциональный backend.
  - Секция «Критерии готовности» — 7 пунктов, обязательный новый `gotcha-16-relogin-race.md`.
  - Секция «Риски» — 4 пункта (persist coupling, AbortController UX, persist-архитектура, Dev vs prod).
  - Секция «Открытые вопросы к пользователю» — 5 пунктов.
- Оценка: 1–2 DEV-сессии, один промпт по `prompt_template.md`.

**Файлы:** `Спринты/Sprint_5_Review_2/PENDING_S5R2_track4_401_unauthorized.md`, этот changelog.

**Тесты:** не применимо (документация).

**Что НЕ сделано (следующий шаг):** создать `prompt_DEV-track4.md` по `prompt_template.md` — уже на этапе B, когда ответим на 5 открытых вопросов пользователю и получим подтверждение.

**Результат:** ✅ план трека 4 готов к обсуждению с пользователем.

---

## 2026-04-17 — Трек 4: решения пользователя + prompt_DEV + JWT blacklist анализ

**Контекст:** пользователь ответил на 5 открытых вопросов. HAR-файлы (Chrome + Safari) не содержат 401 — баг не воспроизвёлся при записи. Стратегия изменена на «превентивный фикс + диагностическая трассировка».

**Решения пользователя:**
- Persist token: **localStorage** + cleanup-хуки (не менять хранилище).
- Backend JWT blacklist: **Вариант Б** — реализовать как отдельную задачу.
- Браузер: Safari (основной). Chrome — для HAR-записи.
- Другой пользователь: не обязателен сейчас.
- HAR: не коммитить (в Chrome HAR лежит пароль!).

**Что сделано:**
- `JWT_blacklist_analysis.md` — развёрнутый анализ 5 вариантов backend JWT invalidation (PG таблица / token versioning / Redis / short-lived access + DB refresh / гибрид). Сравнительная таблица, рекомендация: вариант 5 (гибрид). Ожидает выбора пользователя.
- `prompt_DEV-track4.md` — полный промпт по `prompt_template.md` (11 секций):
  - 6 задач + 1 опциональная: diagnostic tracing, cleanup hook в logout, guard в interceptor, ChartPage defer, E2E тест, Stack Gotcha 16.
  - Integration Verification Checklist: 7 grep-проверок.
  - Тесты: 3+ vitest + 1 E2E Playwright.
- `PENDING_S5R2_track4_401_unauthorized.md` — обновлён: зафиксировано решение пользователя.
- `changelog.md` — эта запись.

**Файлы:**
- `Спринты/Sprint_5_Review_2/JWT_blacklist_analysis.md`
- `Спринты/Sprint_5_Review_2/prompt_DEV-track4.md`
- `Спринты/Sprint_5_Review_2/PENDING_S5R2_track4_401_unauthorized.md`
- `Спринты/Sprint_5_Review_2/changelog.md`

**Следующее действие:** пользователь ревьюирует JWT_blacklist_analysis.md (выбирает вариант). Параллельно можно запускать DEV-сессию по prompt_DEV-track4.md.

**Результат:** ✅ этап B для трека 4 завершён, промпт готов к запуску.

---

## Шаблон для будущих записей

```
## YYYY-MM-DD — Трек N: <название>

**Контекст:** ...
**Что сделано:**
- ...
**Файлы:** ...
**Тесты:** ...
**Stack Gotchas применённые:** ...
**Stack Gotchas новые:** `gotcha-NN-*.md` (если есть)
**Результат:** ✅/⚠️/❌
```
