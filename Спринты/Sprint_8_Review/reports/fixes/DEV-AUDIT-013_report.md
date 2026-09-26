## DEV-AUDIT-013 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (закрытие открытых WS при logout — ⏸: реестра нет)
### 1. Что реализовано
- `authenticate_access_payload` (`middleware/auth.py`) — единый предикат (sub, jti, существование/`is_active`, `ver`) для HTTP, WS, dash-mount; `_send_error` — `json.dumps`.
- `ws_authenticate` → предикат; 4401 до accept на трёх WS.
- `login`: деактивированному (после проверки пароля) — 401 «Аккаунт деактивирован», пары нет, счётчик не сбрасывается.
- Telegram: все команды/callback'и, /help, /start без кода — `_INACTIVE_USER_TEXT`; непривязанному — прежние тексты. `_link_account`: отказ неактивному и несуществующему; прежние активные привязки чата к другим пользователям гасятся в той же транзакции.
- Исходящие Telegram/email — только активному (`service.py`, `dispatchers.py`).
- Реестр WS — ⏸: `ws_registry` + `close_user(uid, 4401)` из logout/деактивации.
### 2. Файлы
Изм.: `app/middleware/auth.py`, `app/common/ws_auth.py`, `app/admin/dash_mount.py`, `app/auth/{service,router}.py`, `app/notification/{telegram_webhook,service,dispatchers}.py`; тесты `test_audit_s8r_ws_revocation.py` (xfail снят, 3 WS), `test_ws_backtest.py`, `test_auth_service.py`, `test_auth_router.py`. Нов.: `tests/test_notification/test_telegram_inactive_user.py`. Удалён `tests/test_security/test_ws_auth_revocation.py`.
### 3. Тесты
RED: WS `DID NOT RAISE <class 'starlette.websockets.WebSocketDisconnect'>`; sub `ValueError: invalid literal for int() with base 10: 'abc'`; Telegram `Actual: '✅ Telegram привязан…'`, `assert [1, 2] == [2]`; login `assert 200 == 401`; dispatch `['telegram', 'email'] == []` → GREEN. Мутация «jti → pass» → 6 failed (`DID NOT RAISE`, `4403 == 4401`); откат по md5. Гейты: pytest 3087 passed / 8 xfailed / 1 failed (S8R-FIX-016, допустимо); ruff 0; mypy Success (180); bandit 0; typecheck 0 / lint 0 / build ok (фронт не менялся); vitest — на уровне пакета.
### 4. Integration points
✅ `middleware/auth.py:90`, `ws_auth.py:57`, `dash_mount.py:141`, `auth/router.py` (login), `telegram_webhook.py`, `service.py:527/538`.
### 5. Контракты
Миграции нет. Новое: `POST /auth/login` деактивированного — 401 `detail="Аккаунт деактивирован"`.
### 6. Проблемы / правки документов / находки
- Ревью: исправлено 1–7. Ревью-2: исправлено 1–5.
- ТЗ §7.3, после «При logout»: «Субъект, отзыв `jti`, `is_active` и версия токенов проверяются единым предикатом `authenticate_access_payload` в HTTP, на WS-upgrade (close 4401 до accept) и в dash-mount `/api/v1/admin/metrics`. Уже открытые WS при logout/деактивации не разрываются до переподключения. Деактивированный: логин — 401 «Аккаунт деактивирован»; Telegram/email-уведомления не уходят; бот на любую команду и привязку отвечает „Учётная запись отключена администратором“ (S8R-AUDIT-013).»
- Находки (не делал): `LoginPage.tsx` на любой не-423 показывает «Неверный логин или пароль» — текст «Аккаунт деактивирован» до UI не доходит; общий `authenticate_access_token` (decode+type); мёртвый `dispatchers.dispatch_external` и дубли `_get_telegram_link/_get_user`; 8 копий `if not user: reply(_denied_text…)`; dash-тест на подстроку «sub»; два запроса вместо одного; ТЗ §4.12/§7.4 — устаревший `{action:"auth"}`; в существующих БД дубли активных `TelegramLink` по chat_id не чистятся.
### 7. Применённые Stack Gotchas
48, 46, 37.
### 8. Новые Stack Gotchas
Нет.
### 9. Плагины
py_compile; `tsc -b`; context7 не нужен; tdd — `mattpocock-skills:tdd`.
