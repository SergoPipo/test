## DEV-AUDIT-058 отчёт — S8R fixes, MEDIUM (итерация 3)
Статус: ✅ готово к коммиту. Ревью-2: исправлено 1–10 (ревью-1: 1–10 — ранее).
### 1. Что реализовано
- **Реестр** (`app/common/ws_registry.py`):
  - лимит 30 на пользователя (диапазон [10, 50], выше не пускает валидатор, т.к. nginx держит 60/IP); отказ — accept + 4429;
  - `close_session` — logout, только своя пара токенов;
  - `rebind_session` — ротация refresh и смена пароля;
  - `close_user` — отзыв семейства: смена пароля закрывает всё, кроме текущей пары; кража refresh (`RefreshReuseDetectedError`) закрывает все WS до выброса 401;
  - память недавних отзывов и переносов (TTL 120 с, ≤ 10 000 записей): регистрация отозванной сессии или сессии, аутентифицированной до отзыва семейства (`WsIdentity.authenticated_at`), получает accept + 4401; перенесённая сессия регистрируется под новой;
  - закрытие соединений идёт параллельно (`gather`), не дольше 2 с на соединение.
- Logout закрывает WS только по проверенному токену: валидный access или refresh, которого нет в `revoked_tokens`.
- `/ws`: не больше 50 подписок; `market:` проверяется через `parse_market_channel` (таймфрейм из `Timeframe`, тикер той же функцией, что REST); сообщение не-объект → ошибка, соединение живо.
- `/ws/backtest`: после terminal ждёт закрытия клиентом, но не дольше 30 с.
- AI-стрим: слот занимается первым действием, освобождается в `__call__` ответа.
- `ws_authenticate` удалён — в production не вызывался; тест `test_auth_service` переведён на `ws_authenticate_session`.
- **Фронт** (`wsAuth.ts`):
  - общие `reconnectDelayForClose` / `backoffDelay` / `wsCooldownRemaining` для всех четырёх хуков;
  - пауза после 4429 общая для модуля, её не обходят ни subscribe, ни mount;
  - поздний `onclose` вытесненного сокета игнорируется (bootstrap и `useBacktestJobWS`);
  - `useBacktestJobWS` сам закрывает сокет на terminal-событие и на snapshot с терминальным статусом.
- nginx: `location ^~ /ws`, `limit_conn` 60 на IP. **Отдельно: это чинит мультиплексор `/ws` в проде** (раньше уходил в SPA-fallback).
### 2. Файлы
- Новые: `app/common/ws_registry.py`, `tests/unit/test_backtest/test_ws_limits.py`, `tests/unit/test_ai/test_stream_limit_atomic.py`, `frontend/src/hooks/__tests__/useBacktestJobWS.test.ts`.
- Изменены backend: `ai/chat_router.py`, `ai/providers/openai_provider.py`, `auth/router.py`, `auth/service.py`, `backtest/ws.py`, `backtest/ws_backtest.py`, `common/ws_auth.py`, `config.py`, `market_data/router.py`, `market_data/schemas.py`, `middleware/auth.py` (только докстринг), `trading/ws_sessions.py`, `tests/unit/test_auth_service.py`.
- Изменены фронт и конфиг: `wsAuth.ts`, `useWebSocket.ts`, `useTradingSessionsWS.ts`, `useBacktestJobWS.ts`, тесты этих хуков, `nginx.conf`.
### 3. Тесты
- **RED (исходный):** `DID NOT RAISE WebSocketDisconnect`; `assert 'subscribed' == 'forbidden'`; `assert [200,200,200,200,403] == [200,200,200,403,403]`.
- **Мутация ревью-2:** `try_register` без проверки отзыва → `assert {'frame': {'type': 'auth_ok'}} == {'code': 4401}` (оба сценария гонки). Откат через бэкап, md5 совпал.
- **Проверка новых vitest:** снял guard, закрытие по snapshot и проверку паузы — упали 4 новых теста; откат, md5 совпал.
- **Гейты:** pytest 3426 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (187); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 964 passed.
### 4. Integration points
- ✅ `ws_admit` — `ws.py:191`, `ws_sessions.py:131`, `ws_backtest.py:76`.
- ✅ `close_session`, `rebind_session`, `close_user` — `auth/router.py` (logout, refresh `:251`, смена пароля `:430`).
- ✅ `is_valid_ticker` — `market_data/router.py`.
- ✅ Хелперы `wsAuth.ts` — во всех четырёх хуках.
### 5. Контракты
- WS close 4429 и 4401 — после accept.
- Статус подписки `limit_exceeded`.
- `/candles/subscribe` → 422 на недопустимый тикер.
- `RefreshReuseDetectedError` — подкласс `ValueError`, прежние вызывающие не затронуты.
- Миграции нет.
### 6. Правки документов / замечания
- **ТЗ §4.12, абзац «Лимиты»:** «≤ 30 WS на пользователя (настройка, диапазон 10–50), сверх — accept + close 4429; клиент выдерживает общую паузу 60 с. ≤ 50 подписок (`limit_exceeded`); `market:<TICKER>:<TF>` проверяется как в REST; JSON не-объект → `error`. WS закрываются кодом 4401: при logout — только своя сессия; при смене пароля — все, кроме текущей; при повторном refresh (кража) — все; отзыв во время upgrade тоже даёт 4401. `/ws/backtest` после terminal закрывает клиент». Описание auth первым сообщением в этом разделе устарело.
- **ТЗ §7.5:** «AI SSE ≤ 3 на пользователя, слот до любой работы (403); nginx `limit_conn` 60 WS/IP (429), выше потолка на пользователя».
- **Гайд §3.3:** nginx `location ^~ /ws` (мультиплексор в проде); `WS_MAX_CONNECTIONS_PER_USER` ∈ [10, 50], менять синхронно с `limit_conn`.
- **Новая находка:** `useBacktestJobWS` (одиночная job) не подключён ни в одном компоненте — используется только bootstrap.
- `nginx -t` не выполнялся: nginx на машине нет.
- **Самопроверка:**
  1. БД — только чтение `revoked_tokens`.
  2. Уведомлений нет.
  3. Реальные роутеры и `app.main`, рандеву через поток; токен без `rjti` → `jti`.
  4. Под таймаутом только сеть (`receive`, `close`).
  5. Все вызывающие проверены: `refresh_token` бросает подкласс `ValueError`, `ws_authenticate` удалён, его вызывающие переведены.
  6. Ресурсы от клиента ограничены: 30/50 соединений, 50 подписок, 64 символа канала, 20 символов тикера, 10 000 записей памяти отзывов.
### 7. Stack Gotchas
48, 52 (guard идентичности сокета), 59 (рандеву до регистрации), 71, 74/75.
### 8. Новые
Кандидат: TestClient отменяет хендлер при выходе из `websocket_connect`, поэтому «слот освобождён» проверять после `ws.close()` внутри контекста. Второй: модульная пауза (`cooldownUntil`) переживает `useRealTimers` — сбрасывать в `afterEach`.
### 9. Плагины
py_compile/ruff/mypy, typecheck, tdd; context7 — нет (API сверены по установленным пакетам).
