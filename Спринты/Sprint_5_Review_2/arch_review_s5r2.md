# ARCH-ревью Sprint_5_Review_2

**Дата:** 2026-04-17  
**Ревьюер:** ARCH (Claude Opus 4.6)  
**Статус:** ✅ ПРИНЯТО  

---

## 1. Сводка треков

| # | Трек | Тип | Файлы (new/mod) | Тесты | Вердикт |
|---|------|-----|-----------------|-------|---------|
| 4 | 401 после релогина | Bug fix (frontend) | 2/8 | vitest 226 + E2E | ✅ |
| 5 | TF-aware upsertLiveCandle | Fix (frontend) | 0/3 | vitest +3 | ✅ |
| 3 | Sequential-index intraday | Feature (frontend) | 2/2 | vitest +9 | ✅ |
| 1 | Prefetch при логине | Feature (backend) | 2/1 | pytest +4 | ✅ |
| 2 | Верификация агрегации | Verification (backend) | 2/0 | pytest +12 | ✅ |

**Итого:** 8 новых файлов, 14 изменённых. Frontend: 238/238 vitest. Backend: 623/623 pytest.

---

## 2. Архитектурная проверка (15 пунктов)

| # | Проверка | Вердикт |
|---|----------|---------|
| 1 | authStore cleanup order (closeWS→abort→set→clear) | ✅ OK |
| 2 | client.ts token guard (!token → ECANCELED) | ✅ OK |
| 3 | ChartPage token в useEffect deps | ✅ OK |
| 4 | upsertLiveCandle обратная совместимость | ✅ OK |
| 5 | channelTf извлечение split(':')[2] | ⚠️ см. ниже |
| 6 | sequentialIndex MSK-offset | ✅ OK |
| 7 | sequentialMappingRef — нет утечки памяти | ✅ OK |
| 8 | Toggle sequential — сброс при D/W/M | ✅ OK |
| 9 | prefetch.py Semaphore(3) + JOIN path | ✅ OK |
| 10 | auth/router.py create_task (не блокирует login) | ✅ OK |
| 11 | test_stream_aggregation 12 тестов | ✅ OK |
| 12 | _AggregatingCandle не модифицирован | ✅ OK |
| 13 | Нет конфликтов между треками 3 и 5 | ✅ OK |
| 14 | Все integration points подключены | ✅ OK |
| 15 | Gotcha 16 документация = код | ✅ OK |

### Критические проблемы: 0

### Замечание (не блокирующее)

**⚠️ #5 — `CandlestickChart.tsx:571`:** `wsChannel?.split(':')[2]` уязвимо к malformed channel string. Рекомендация: валидировать `split(':').length === 3` перед индексацией. Не блокирует — guard в `upsertLiveCandle` (store) отбросит невалидный тик. Можно исправить в S6.

---

## 3. Cross-DEV контракты

| Поставщик | Потребитель | Контракт | Статус |
|-----------|-------------|----------|--------|
| Трек 5 | Трек 2 (будущий) | `upsertLiveCandle(candle, sourceTf?)` | ✅ Реализован, обратно совместим |
| Трек 3 | ChartPage | `sequentialMode: boolean` prop | ✅ Реализован |
| Трек 4 | Все | `closeWS()`, `clearCandlesCache()`, `abortAllInflight()` | ✅ Реализован |
| Трек 1 | auth/router | `prefetch_active_sessions(user_id, db_factory)` | ✅ Реализован |

---

## 4. Stack Gotchas

### Применённые
- **Gotcha 4** (T-Invest rate limits) — Semaphore(3) в prefetch.py
- **Gotcha 15** (naive datetime UTC-offset) — timezone-тесты в трек 2
- **Gotcha 16** (relogin race) — применён в треках 3, 4, 5

### Новые
- **Gotcha 16** (`gotcha-16-relogin-race.md`) — создана треком 4, INDEX.md обновлён. Описание точное, соответствует коду.
- Других новых gotcha не обнаружено.

---

## 5. Оценка применения prompt_template.md

Все 5 промптов (`prompt_DEV-track1..5.md`) созданы по `Спринты/prompt_template.md`.

| Критерий | Track 1 | Track 2 | Track 3 | Track 4 | Track 5 |
|----------|---------|---------|---------|---------|---------|
| 11 секций заполнены | ✅ | ✅ | ✅ | ✅ | ✅ |
| Цитаты из кода (не ссылки) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Integration checklist | ✅ | ✅ | ✅ | ✅ | ✅ |
| 8-секционный отчёт | ✅ | ✅ | ✅ | ✅ | ✅ |
| Отчёт сохранён в reports/ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stack Gotchas читались | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cross-DEV контракты | ✅ | ✅ | ✅ | ✅ | ✅ |

**Вывод:** Шаблон промптов работает — все DEV-агенты:
- Читали обязательные документы перед кодом
- Проверяли integration points (grep)
- Возвращали структурированные отчёты
- Не пропускали Stack Gotchas

**Улучшение для S6:** Добавить в шаблон секцию «Потенциальный баг» с описанием заранее известных рисков (как было сделано в track2 — потенциальный баг midnight UTC vs MOEX).

---

## 6. Рекомендации для S6

1. **channelTf валидация** — добавить `split(':').length === 3` проверку (minor, ~1 строка)
2. **prefetch при refresh** — сейчас prefetch только при login. При F5 кеш ohlcv_cache на месте (SQLite), но zustand candlesCache пуст. Рассмотреть localStorage-prefetch для frontend
3. **_AggregatingCandle — warm-up при restart** — при перезапуске backend агрегатор теряет in-memory state. Нужен warm-up из последнего бара ohlcv_cache. Не критично для фазы 1, но важно для production

---

## Вердикт

**Sprint_5_Review_2 — ПРИНЯТ ✅**

5 треков выполнены, 0 критических проблем, 1 minor замечание (не блокирует). Тесты: 238 frontend + 623 backend = 861 total, 0 failures. Готов к закрытию (фаза 5).
