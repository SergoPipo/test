# Бэклог доработок — после Sprint 3 + Sprint 4

> Задачи, выявленные при UI-проверках и ревью кода.
> Выполняются последовательно перед началом Sprint 5.

## Задачи

| # | Описание | Тип | Приоритет | Сложность | Статус |
|---|----------|-----|-----------|-----------|--------|
| 1 | ⛔ `ai/chat_router.py:203` — переменная `response_text` не определена. Не-streaming endpoint `/chat` падает с NameError | Баг | Critical | S | ✅ |
| 2 | ⛔ `backtest/engine.py:431` — bare `exec()` без RestrictedPython. Если AST-анализатор обойдён → произвольный код | Безопасность | Critical | M | ✅ |
| 3 | ⛔ `sandbox/executor.py:110` — `exec()` блокирует event loop. Перевести на `loop.run_in_executor()` | Баг | Critical | S | ✅ |
| 4 | ⛔ `middleware/rate_limit.py` — in-memory state per-worker. При N workers лимит = N × limit. Добавить Lock или Redis-backend | Безопасность | Critical | M | ✅ |
| 5 | ⛔ `StrategyTesterPanel.tsx:127-128` — event listeners (mousedown/mouseup) добавляются, но никогда не удаляются → утечка памяти | Баг | Critical | S | ✅ |
| 6 | ⛔ `backtestStore.ts:27-28` — глобальные `ws` и `pollIntervalId`. При параллельных бэктестах конфликтуют. Перенести в Map<backtestId, state> | Баг | Critical | M | ✅ |
| 7 | ⛔ `aiChatStore.ts:37-38` — глобальный `abortController`. При нескольких чатах конфликтуют | Баг | Critical | S | ✅ |
| 8 | CORS_ORIGINS в `.env` содержит только `:5173`. При другом порту frontend бэкенд недоступен | Баг | High | S | ✅ |
| 9 | `aiChatStore.ts:119` — `isStreaming` устанавливается слишком поздно → race condition | Баг | High | S | ✅ |
| 10 | `aiStreamClient.ts:103` — SSE buffer: остаток буфера после конца потока не обрабатывался | Баг | High | S | ✅ |
| 11 | `csrf.py:44-45` — CSRF fail-open для API-клиентов (оставлено, улучшен комментарий) | Безопасность | High | S | ✅ |
| 12 | `ws.py:32` — `payload.get("sub", 0)` → возвращает None если "sub" отсутствует | Безопасность | High | S | ✅ |
| 13 | Конфликт Playwright: `@playwright/test` обновлён до 1.59.1 | Баг | Medium | S | ✅ |
| 14 | Brute-force: в dev-режиме (DEBUG=true) лимит 50 попыток / 1 мин вместо 5 / 15 мин | Улучшение | Medium | S | ✅ |
| 15 | `block_parser.py` — float→Decimal для финансовых параметров. Исправлено в S5 | Баг | Medium | M | ✅ |
| 16 | `code_generator.py` — добавлена поддержка Decimal. Исправлено в S5 | Баг | Medium | S | ✅ |
| 17 | `chat_router.py` — `_active_streams` обёрнут в `threading.Lock()` | Баг | Medium | S | ✅ |
| 18 | `client.ts` — `isRefreshing` сбрасывается в `finally` блоке (не только при успехе) | Баг | Medium | S | ✅ |
| 19 | `StrategyEditPage.tsx` — 935 строк, монолит. Отложено — L-задача, требует рефакторинга | Улучшение | Medium | L | ⬜ |
| 20 | `MetricsGrid.tsx` — пороги корректны (>55 good, <40 bad), НЕ баг | — | — | — | ✅ |
| 21 | `ast_analyzer.py` — уже блокирует dunder-атрибуты (.__class__, .__bases__), НЕ баг | — | — | — | ✅ |
| 22 | `executor.py` — SIGALRM Unix-only. Отложено — проект на macOS, не Windows | Улучшение | Medium | S | ⬜ |
| 23 | Поиск — добавлен фильтр `instrument_type`. Исправлено в S5 | Улучшение | Low | S | ✅ |
| 24 | Иконки сортировки — добавлен цвет blue-4. Исправлено в S5 | Улучшение | Low | S | ✅ |
| 25 | `console.log` удалён из StrategyEditPage.tsx:517 | Улучшение | Low | S | ✅ |
| 26 | `block_parser.py` — `blocks.index(block)` заменён на `enumerate` | Улучшение | Low | S | ✅ |
| 27 | `engine.py` — silent `except: pass` заменён на `logger.warning()` в TradeRecorder и IMOEX loader | Улучшение | Low | S | ✅ |
| 28 | `chat_router.py` — рефакторинг на DI (Depends). Исправлено в S5 | Улучшение | Low | M | ✅ |

**Легенда:**
- Тип: Баг / Безопасность / Улучшение
- Приоритет: Critical / High / Medium / Low
- Сложность: S (часы) / M (1 день) / L (2+ дней)
- Статус: ⬜ / 🔄 / ✅

## Статистика

| Приоритет | Всего | ✅ Исправлено | ⬜ Отложено |
|-----------|-------|--------------|------------|
| Critical | 7 | 7 | 0 |
| High | 5 | 5 | 0 |
| Medium | 10 | 6 | 4 |
| Low | 6 | 3 | 3 |
| **Итого** | **28** | **21** | **7** |

**Отложенные задачи (7):** перенесены в Sprint 5 или S7
- #15 float→Decimal в block_parser (M, рефакторинг)
- #19 StrategyEditPage рефакторинг (L)
- #22 SIGALRM Windows (не актуально для macOS)
- #23 Фильтрация поиска по instrument_type
- #24 Иконки сортировки в таблице сделок
- #28 DI для синглтонов chat_router (M)
