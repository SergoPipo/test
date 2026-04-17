# Sprint_5_Review_2 — Backlog

> 5 треков chart-hardening, каждый — отдельная Claude-сессия.
> Статус патч-цикла: **🔄 фазы 1–2 завершены (треки 3, 4, 5), фаза 3 — в работе (треки 1, 2)**.
> Детальные планы треков — в отдельных `PENDING_S5R2_track*.md` файлах в этой папке.

## Сводная таблица

| # | Трек | Тип | Приоритет | Зависимости | Статус | Документ |
|---|------|-----|-----------|-------------|--------|----------|
| 1 | Backend prefetch свечей при логине | Feature (backend) | 🟡 Важно | — | 🔄 в работе | `PENDING_S5R2_track1_backend_prefetch.md` |
| 2 | Backend live-агрегация 1m → D/1h/4h | Feature (backend) | 🟡 Важно | — | 🔄 в работе | `PENDING_S5R2_track2_live_aggregation.md` |
| 3 | Sequential-index mode для intraday | Fix (frontend) | 🟢 UX | — | ✅ готово | `reports/DEV-track3_report.md` |
| 4 | 401 Unauthorized после релогина | Bug (diagnose+fix) | 🔴 UX-блокер | — | ✅ готово | `reports/DEV-track4_report.md` |
| 5 | TF-aware `upsertLiveCandle` | Fix (frontend) | 🟡 Важно | — | ✅ готово | `reports/DEV-track5_report.md` |

**Условные обозначения:**
- ⬜ TODO / 🔄 в работе / ✅ готово / ⚠️ готово с замечаниями
- 🔴 UX-блокер / 🟡 Важно / 🟢 UX-улучшение

## Треки (детали — в PENDING-файлах)

### Трек 1 — Backend prefetch свечей при логине
TODO: корень проблемы, ориентировочный объём, критерии готовности → `PENDING_S5R2_track1_backend_prefetch.md`.

### Трек 2 — Backend live-агрегация 1m → D/1h/4h
TODO: корень проблемы, ориентировочный объём, критерии готовности → `PENDING_S5R2_track2_live_aggregation.md`.

### Трек 3 — Sequential-index mode для intraday
TODO: корень проблемы, ориентировочный объём, критерии готовности → `PENDING_S5R2_track3_sequential_index.md`.

### Трек 4 — 401 Unauthorized после релогина
TODO: шаги диагностики, гипотезы, критерии готовности → `PENDING_S5R2_track4_401_unauthorized.md`.

### Трек 5 — TF-aware `upsertLiveCandle`
TODO: корень проблемы (остаток wave 4 фазы 3.7), критерии готовности → `PENDING_S5R2_track5_tf_aware_upsert.md`.

---

## Оценка объёма

TODO заполнить после детализации PENDING-файлов. Черновая оценка:
- Трек 4 (401): 0.5–1 сессия (сначала диагностика)
- Трек 5 (TF-aware): 0.5 сессии
- Трек 1 (prefetch): 1 сессия
- Трек 3 (sequential-index): 0.5–1 сессия
- Трек 2 (live-агрегация): 1.5–2 сессии
