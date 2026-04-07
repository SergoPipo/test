# Лог выполнения — Sprint 4 Review

> Фиксирует выполнение задач из бэклога.
> Каждая запись: дата, задача из бэклога, что сделано, результат.

---

## 2026-04-07 — Critical #1-7

### #1 chat_router.py: undefined `response_text` ✅
**Файл:** `backend/app/ai/chat_router.py`
**Изменение:** Перемещено `response_text = result.get("response", "")` выше строки 203, где эта переменная использовалась до определения.
**Результат:** Endpoint `/chat` больше не падает с NameError.

### #2 backtest/engine.py: bare `exec()` → hardened namespace ✅
**Файл:** `backend/app/backtest/engine.py`
**Изменение:** Заменён пустой namespace на hardened: убраны опасные builtins (`eval`, `exec`, `compile`, `__import__`, `open`, `globals`, `locals`, `getattr`, `setattr`, `delattr` и др.), добавлены только безопасные (`abs`, `len`, `range`, `int`, `float`, `str`, `list`, `dict`, `print`, `type`, `super` и др.) + `bt`, `math`, `Decimal`.
**Результат:** Даже если AST-анализатор обойдён, namespace не содержит опасных функций.

### #3 sandbox/executor.py: blocking `exec()` → `run_in_executor` ✅
**Файл:** `backend/app/sandbox/executor.py`
**Изменение:** `exec(compiled, restricted_globals)` обёрнут в `loop.run_in_executor(None, _run_sandboxed)` + `asyncio.wait_for(timeout)`. Импортирован `asyncio`.
**Результат:** Выполнение кода больше не блокирует event loop.

### #4 rate_limit.py: thread-safe sliding window ✅
**Файл:** `backend/app/middleware/rate_limit.py`
**Изменение:** Добавлен `threading.Lock()`. Вся секция чтения/записи `timestamps` обёрнута в `with self._lock:`. Исправлен `retry_after` — добавлен `max(1, ...)` для исключения отрицательных значений.
**Результат:** Race condition при одновременных запросах устранён.

### #5 StrategyTesterPanel.tsx: event listener leak ✅
**Файл:** `frontend/src/components/backtest/StrategyTesterPanel.tsx`
**Изменение:** Обработчики `mousedown`/`mouseup` сохраняются в именованные функции `onMouseDown`/`onMouseUp`, хранятся через `chart.__cleanupListeners`. В cleanup useEffect вызывается `removeEventListener` для обоих.
**Результат:** Утечка памяти при пересоздании графика устранена.

### #6 backtestStore.ts: global WS → Map per backtest ✅
**Файл:** `frontend/src/stores/backtestStore.ts`
**Изменение:** Заменены глобальные `ws` и `pollIntervalId` на `Map<number, WebSocket>` (wsMap) и `Map<number, setInterval>` (pollMap). Все обращения обновлены для работы с конкретным `backtestId`. `unsubscribeProgress` принимает опциональный `backtestId` — без аргумента чистит всё.
**Результат:** Параллельные бэктесты не конфликтуют.

### #7 aiChatStore.ts: global abortController → Map per strategy ✅
**Файл:** `frontend/src/stores/aiChatStore.ts`
**Изменение:** Заменён глобальный `abortController` на `Map<number, AbortController>` (abortControllers). `sendMessageStream` создаёт controller per strategyId. `stopStreaming` абортит все контроллеры. `isStreaming` устанавливается сразу (до async операций) — исправлен race condition.
**Результат:** Несколько чатов не конфликтуют, race condition устранён.
