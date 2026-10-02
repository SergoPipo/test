## DEV-REV-CI отчёт — раунд 2 (код-ревью оркестратора)
Статус: ✅ готово к коммиту по п.1/3/4 | ⏸ п.2 (`uncancel`) не внесён: ломает различение своей и чужой отмены, нужно решение оркестратора

### 1. Что сделано
- **п.1.** Один `with anyio.CancelScope(shield=True):` вокруг всего `while` в `_wait_through_cancels`. Нативная `CancelledError` ловится внутри экрана (`continue`).
- **п.3.** Тесты в `test_wait_through_cancels.py`, всего 6:
  - (а) флаг `caller_cancelled` в обоих anyio-тестах;
  - (б) проверка `1 <= calls <= 5`;
  - (в) подменяется атрибут `engine.asyncio` (объект `_AsyncioInEngine`, всё настоящее, кроме `wait`). `app.trading.engine.asyncio.wait` — это тот же объект, что глобальный `asyncio.wait`, поэтому патч по строке остался бы глобальным;
  - (г) тело 1,0 с, grace 0,2 с: elapsed < 0,5 с, отмена проброшена, тело отменено.
- **п.4.** Формулировка «тысячи вызовов за доли секунды» одинакова в тесте, engine и gotcha. Правило в gotcha-77 сформулировано на публичном контракте anyio; приватные имена вынесены в пояснение для anyio 4.13.

### 2. Почему п.2 не внесён
Проверил на модели (`scratchpad/uncancel_repro.py`), что меняет `uncancel()`, когда вызывающий стоит под `asyncio.timeout`:

| Сценарий | Без `uncancel` | С `uncancel` |
|---|---|---|
| A: только свой таймаут | TimeoutError | TimeoutError |
| B: чужой cancel, затем таймаут | CancelledError | **TimeoutError** |
| C: таймаут, затем чужой cancel | CancelledError | **TimeoutError** |

В B и C чужая отмена (например, shutdown) превращается в `TimeoutError`, и вызывающий продолжает работу. Рост `cancelling()` при этом корректен: это настоящие запросы отмены. Вместо `uncancel()` поведение A/B/C закреплено параметризованным тестом, причина описана в докстринге и в gotcha-77.

### 3. Тесты
Мутации (откат из бэкапа, md5 совпал):
- убрать экран → `ожидание вращалось: 8813 вызовов asyncio.wait за 0.4 с`;
- `raise` → `return None` → `отмена anyio не дошла до вызывающего` и `DID NOT RAISE` (4 теста);
- добавить `uncancel()` → `TimeoutError` в B и C.

Гейты:
- pytest 4621 passed / 1 skipped / 3 xfailed / 0 failed;
- ruff 0; mypy Success (197); bandit 0;
- typecheck / lint / build — ok;
- `test_stop_session_race.py` под `--cov=app` ×3: 13 passed (5,7–6,3 с);
- vitest: фронт не менялся — на уровне пакета.

### 4. Файлы
- `backend/app/trading/engine.py`
- `backend/tests/test_trading/test_wait_through_cancels.py` (новый)
- `stack_gotchas/gotcha-77-anyio-recancels-http-handler.md`
- `stack_gotchas/INDEX.md` (v41)

Integration: вызовы `engine.py:1375,1378` из `run_shielded_from_cancel`, сам он используется в 6 местах. ФТ/ТЗ правок не требуют.
