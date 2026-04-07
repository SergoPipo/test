# Ревью кода — после Sprint 3 + Sprint 4

> Чеклист проверки реализованного кода S3 (Стратегии + Редактор) + S4 (AI + Бэктестинг).
> Статус: ✅ Проведено 2026-04-07

---

## 1. Архитектура и модули

- [x] **Разделение на слои:** ✅ router.py / service.py / models.py / schemas.py — корректно для всех модулей S3+S4
- [x] **Когезия модулей:** ✅ strategy, sandbox, ai, backtest — каждый пакет отвечает за свою зону
- [x] **Нет циклических зависимостей:** ✅ граф импортов ацикличен
- [x] **Соответствие структуре из CLAUDE.md:** ✅ файловая структура совпадает
- [ ] **Монолитные компоненты:** ⚠️ StrategyEditPage.tsx — 935 строк, 14 useState хуков, множество ответственностей (форма, код, Blockly, AI, бэктест). Требует рефакторинга

## 2. Backend — API-слой (S3+S4)

- [x] **Эндпоинты соответствуют ТЗ:** ✅ strategy CRUD, sandbox analyze/execute, AI providers CRUD + chat/stream, backtest CRUD + WS
- [x] **Валидация входных данных:** ✅ Pydantic v2 на всех схемах
- [x] **Версионирование API:** ✅ все endpoints под `/api/v1/`
- [ ] **Глобальные синглтоны в chat_router.py:** ⚠️ `_ai_service`, `_history_manager` — не подходят для тестирования, нужна DI через FastAPI Depends

## 3. Backend — Бизнес-логика

### 3.1 Strategy (S3)

- [x] **Service чистый:** ✅ CRUD + версионирование, ownership через user_id
- [ ] **block_parser.py:** ⚠️ Множественные `float()` для финансовых значений (стоп-лосс, тейк-профит, RSI-зоны) — нужен Decimal или int
- [ ] **block_parser.py:** ⚠️ `blocks.index(block)` — O(n) поиск в циклах (строки 221, 388), нужен enumerate
- [ ] **code_generator.py:** ⚠️ Интерполяция пользовательских параметров в Python-код без `repr()` — если параметр содержит кавычки, синтаксическая ошибка
- [ ] **block_parser.py:** ⚠️ Нет ограничения длины входного текста — потенциальный DoS-вектор

### 3.2 Sandbox (S3)

- [x] **Двухуровневая валидация:** ✅ AST-анализ + RestrictedPython
- [ ] **executor.py:** ⛔ `exec()` блокирующий — выполняется в event loop без `run_in_executor()`. При сложном коде блокирует все HTTP-запросы
- [ ] **executor.py:** ⚠️ `signal.SIGALRM` не работает на Windows — timeout неактивен
- [ ] **ast_analyzer.py:** ⚠️ Не предотвращает косвенный доступ: `().__class__.__bases__[0].__subclasses__()` обходит проверку dunder

### 3.3 AI Service (S4)

- [x] **Pluggable providers:** ✅ Factory pattern, шифрование ключей AES-256-GCM
- [ ] **chat_router.py:203:** ⛔ **КРИТИЧНО** — переменная `response_text` не определена. Не-streaming endpoint `/chat` упадёт с NameError
- [ ] **chat_router.py:36-37:** ⚠️ Счётчик `_active_streams` не потокобезопасен — race condition при конкурентных запросах
- [ ] **service.py:** ⚠️ `is_active == True` (E712) — если is_active nullable, `NULL == True` вернёт NULL, неактивные конфиги могут быть возвращены

### 3.4 Backtest Engine (S4)

- [x] **Backtrader wrapper:** ✅ async execution через `run_in_executor()`
- [ ] **engine.py:431:** ⛔ Используется bare `exec()` вместо RestrictedPython. AST-анализатор — первый барьер, но если обойти — произвольный код
- [ ] **engine.py:138:** ⚠️ `except Exception: pass` в TradeRecorder — если запись сделок упадёт, исключение проглочено молча, сделки потеряны
- [ ] **engine.py:279:** ⚠️ `except Exception: pass` при загрузке индекса — бенчмарк IMOEX молча пропускается
- [ ] **metrics.py:** ✅ Decimal для всех финансовых значений, правильные edge cases (0 сделок, 0 убытков)

## 4. Backend — Безопасность

### 4.1 CSRF (S3)

- [x] **Double-submit cookie:** ✅ `secrets.compare_digest()` для предотвращения timing attacks
- [ ] **csrf.py:44-45:** ⚠️ Пропускает валидацию если нет ни cookie, ни header — неаутентифицированные запросы проходят без CSRF. Fail-open вместо fail-secure

### 4.2 Rate Limiting (S3)

- [ ] **rate_limit.py:** ⛔ In-memory storage не разделяется между workers. При N workers лимит = N × limit
- [ ] **rate_limit.py:52:** ⚠️ Race condition: два одновременных запроса могут оба пройти проверку лимита
- [ ] **rate_limit.py:80:** ⚠️ IP из `request.client.host` без учёта proxy headers — можно обойти через прокси

### 4.3 WebSocket (S4)

- [x] **JWT при handshake:** ✅ токен из query параметра
- [ ] **ws.py:29:** ⚠️ JWT в query string логируется в access logs и browser history. Приемлемо для short-lived токенов
- [ ] **ws.py:32:** ⚠️ `int(payload.get("sub", 0))` — если "sub" отсутствует, user_id=0 может дать доступ к чужим потокам

### 4.4 Code Injection

- [ ] **Цепочка block_parser → code_generator → exec:** ⚠️ Если параметры блоков содержат код (напр. `period: "20; import os"`), генерируется невалидный Python. Нет санитизации типов параметров

## 5. Frontend — Компоненты (S3+S4)

### 5.1 Критичные проблемы

- [ ] **StrategyTesterPanel.tsx:127-128:** ⛔ Event listeners (mousedown/mouseup) добавляются, но **никогда не удаляются**. При каждом пересоздании графика — утечка
- [ ] **InstrumentChart.tsx:163-167:** ⛔ requestAnimationFrame ID хранится в свойстве объекта `__rafId` вместо ref — может быть перезаписан
- [ ] **backtestStore.ts:27-28:** ⛔ Глобальные `ws` и `pollIntervalId` — при нескольких бэктестах одновременно конфликтуют
- [ ] **aiChatStore.ts:37-38:** ⛔ Глобальный `abortController` — при нескольких чатах конфликтуют

### 5.2 Высокий приоритет

- [ ] **StrategyEditPage.tsx:** ⚠️ 935 строк, монолит. Race condition в save flow: быстрый двойной клик → два параллельных сохранения
- [ ] **aiChatStore.ts:119:** ⚠️ `isStreaming` устанавливается слишком поздно — можно запустить несколько потоков одновременно
- [ ] **aiStreamClient.ts:103:** ⚠️ Баг парсинга SSE: при буфере, заканчивающемся `\n`, последняя строка может потеряться

### 5.3 Средний приоритет

- [ ] **AISettingsPage.tsx:** ⚠️ 8 useState для формы — нужен useReducer
- [ ] **client.ts:76-77:** ⚠️ При ошибке refresh `isRefreshing` не сбрасывается перед logout
- [ ] **BacktestLaunchModal.tsx:77:** ⚠️ searchDebounceRef timeout не очищается при unmount
- [ ] **MetricsGrid.tsx:45-46:** ⚠️ `maximumFractionDigits: 2` может округлить 0,5 ₽ до 1 ₽
- [ ] **console.log в production:** ⚠️ StrategyEditPage.tsx:517 — отладочные логи

## 6. Frontend — State Management

- [ ] **strategyStore.ts:** ⚠️ `generateCode()` не устанавливает loading state — возможны конкурентные запросы
- [ ] **backtestStore.ts:** ⚠️ Глобальный WebSocket — только один бэктест может отслеживаться одновременно
- [x] **aiChatStore.ts:** ✅ Правильный AbortController cleanup
- [x] **Zustand stores:** ✅ Чистый дизайн, нет циклических зависимостей

## 7. Финансовые данные

- [x] **Decimal на бэкенде:** ✅ metrics.py использует Decimal для всех расчётов
- [x] **ru-RU форматирование:** ✅ Intl.NumberFormat('ru-RU') на фронтенде
- [ ] **float в block_parser:** ⚠️ Все финансовые параметры (стоп-лосс, тейк-профит) парсятся как float, не Decimal
- [ ] **float↔Decimal конвертация:** ⚠️ Backtrader работает только с float. При 10k+ сделок накопительная погрешность
- [x] **Часовые пояса:** ✅ UTC в БД, MSK в UI-отображении

## 8. Тестирование и инфраструктура

- [x] **577 unit-тестов + 18 E2E:** ✅ 0 failures
- [ ] **Playwright:** ⚠️ Конфликт версий `playwright` (1.59.1) vs `@playwright/test` (1.58.2) — тесты не запускаются без fix
- [x] **Coverage:** ✅ Настроен в CI (из Sprint_2_Review backlog)
- [ ] **CORS:** ⚠️ CORS_ORIGINS хардкод `:5173` в `.env` — при другом порту бэкенд недоступен

---

## Результат ревью

| Раздел | Статус | Замечания |
|--------|--------|-----------|
| 1. Архитектура | ⚠️ | StrategyEditPage.tsx монолит (935 строк) |
| 2. API-слой | ✅ | 1 замечание: глобальные синглтоны в chat_router |
| 3. Бизнес-логика | ⛔ | chat_router undefined variable; bare exec(); float в финансах |
| 4. Безопасность | ⛔ | Rate limiter не shared; CSRF fail-open; exec() без sandbox |
| 5. Frontend компоненты | ⛔ | Event listener leak; глобальный WS state; SSE parsing bug |
| 6. State Management | ⚠️ | Глобальные переменные, race conditions |
| 7. Финансовые данные | ⚠️ | float в block_parser; float↔Decimal конвертации |
| 8. Инфраструктура | ⚠️ | Playwright конфликт; CORS хардкод |

**Легенда:** ✅ OK · ⚠️ Есть замечания · ⛔ Критично

---

## Сводка критичных проблем (⛔)

| # | Файл | Описание | Влияние |
|---|------|----------|---------|
| 1 | `ai/chat_router.py:203` | Переменная `response_text` не определена | Endpoint `/chat` падает с NameError |
| 2 | `backtest/engine.py:431` | Bare `exec()` без RestrictedPython | Code injection если AST-анализатор обойдён |
| 3 | `sandbox/executor.py:110` | `exec()` блокирует event loop | Зависание всех HTTP-запросов при сложном коде |
| 4 | `middleware/rate_limit.py` | In-memory state per-worker | Лимит обходится при N workers |
| 5 | `StrategyTesterPanel.tsx:127` | Event listeners не удаляются | Утечка памяти, накопление обработчиков |
| 6 | `backtestStore.ts:27` | Глобальный WebSocket | Конфликт при параллельных бэктестах |
| 7 | `aiChatStore.ts:37` | Глобальный abortController | Конфликт при нескольких чатах |
