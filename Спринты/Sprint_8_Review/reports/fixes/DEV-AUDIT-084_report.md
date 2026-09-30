## DEV-AUDIT-084 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `POST /telegram/test` принимает только пустое тело. Любые поля (`bot_token`, `chat_id`) дают 422 (`TelegramTestRequest`, `extra=forbid`): старый клиент получит отказ, а не отправку в чужой чат.
- Новый метод `NotificationService.send_test_telegram(user_id)` отправляет через нотификатор сервера (`TELEGRAM_BOT_TOKEN`) в `chat_id` активной `TelegramLink`. Привязку ищет тем же `_get_telegram_link`, что и боевая доставка, поэтому неактивному пользователю ничего не уходит.
- Ответы: нет привязки → 409 «Сначала привяжите Telegram…»; бот не настроен → 503; отправлено → 200 `{ok:true}`; Telegram отказал → 200 `{ok:false}`.
- DEV_MODE проверяется одним предикатом `external_delivery_suppressed()`. Его используют `dispatch_external`, `send_test_telegram` и `/test-email`. В DEV_MODE `/telegram/test` отвечает 200 `{ok:false, dev_mode:true, message:"DEV_MODE — не отправлено…"}`, а `/test-email` — 200 `{status:"dev_mode", sent:false, detail}`.
- В лимитере новая категория `notifications_test`: 3 запроса в минуту на пользователя, одна корзина на обе ручки. Порог задаёт `NOTIFICATIONS_TEST_RATE_LIMIT_PER_MINUTE`, строка добавлена в `docs/env_vars.md`. Остальные категории не менялись.
- Фронт: `sendTelegramTest()` вызывается без аргументов. В мастере убран блок «Свой бот» (поля Bot token и Chat ID), кнопка теста теперь в блоке привязанного чата, ошибки выводятся через `getApiErrorMessage`. Признак готовности `tgLinked || tgTestPassed` и авто-включение `telegram_enabled` не трогал — это 085.
- Страница настроек показывает жёлтое уведомление «DEV_MODE — не отправлено» вместо «письмо отправлено».

### 2. Файлы
Новый: `backend/tests/test_notification/test_test_endpoints_guard.py`.
Изменены: `backend/app/{config.py, middleware/rate_limit.py, notification/router.py, notification/schemas.py, notification/service.py}`, `docs/env_vars.md`; тесты `test_notification/test_telegram_test_endpoint.py` (переписан под новый контракт), `test_routers/test_notification_router.py`, `unit/test_profile_and_test_email.py` (закреплён `DEV_MODE=False`); фронт `api/notificationApi.ts`, `wizard/FirstRunWizard.tsx` и его тест, `pages/NotificationSettingsPage.tsx` и его тест.

### 3. Тесты
- RED, все три теста падали:
  - `assert 400 == 409` — `{"ok":false,"message":"Некорректный body: Expecting value…"}`;
  - `assert 400 == 200`;
  - `assert 503 == 429` — `{"detail":"SMTP не настроен"}`.
- GREEN: 3/3.
- Мутация «принять поля тела» (`extra="ignore"`) → `assert 200 == 422` (`{"ok":true,"message":"Сообщение отправлено в привязанный чат"}`), откачена, md5 совпадает.
- Гейты:
  - pytest 4392 passed / 3 xfailed / 1 failed. Упал `test_env_vars_doc_covers_all_settings`: новая настройка не была описана в `env_vars.md`. Описал, `test_config.py` 90 passed. Итого 4393 passed / 0 failed.
  - ruff 0; mypy Success (192); bandit Medium 0 / High 0.
  - typecheck 0; lint 0; build ok; vitest 1004 passed.

### 4. Integration points
✅ `service.py:498` (гейт в `dispatch_external`), `:570`; `router.py:293` (`/test-email`), `:451` (`send_test_telegram`); `rate_limit.py:73,92-93`; `FirstRunWizard.tsx` → `sendTelegramTest()`.

### 5. Контракты
API: `/telegram/test` — без тела, коды 409/503/422, признак `dev_mode`; `/test-email` — `status:"dev_mode"`. Типы `TelegramTestResponse`/`TestEmailResponse` в `notificationApi.ts` совпадают с бэкендом. Миграции нет.

### 6. Проблемы / TODO / правки ФТ-ТЗ
- ФТ §9.1, добавить пункт: «Тестовое сообщение (`POST /notifications/telegram/test`, без тела) уходит серверным ботом только в привязанный чат; нет привязки — 409; в DEV_MODE не отправляется».
- ФТ §10.1: «Тестовые отправки (Email/Telegram) подчиняются DEV_MODE и лимиту 3/мин на пользователя».
- Строку ФТ v-таблицы (стр. 61) «Шаг 4 — „Свой бот“ (bot_token + chat_id)» пометить: блок снят (S8R-AUDIT-084).
- ТЗ §4 API — новый контракт. CLAUDE.md (инвариант «категории auth/trading/ai/general») дополнить категорией `notifications_test`.
- UI-чеклисты с «Свой бот» — обновить.
- Для 085: `tgTestPassed` не сбрасывается при отвязке.
- Новая находка: `TelegramNotifier.send` делает повторы до 3 попыток, а при 429 ждёт до 30 с. HTTP-ответ теста может занять десятки секунд вместо прежних 3 с.
- Самопроверка: 1 — новых записей в БД нет; 2 — строк Notification тест не создаёт; 3 — путь HTTP → настоящий сервис → настоящий поиск привязки, мок только на нотификаторе; 4 — `wait_for` не добавлял; 5 — `dispatch_external` ведёт себя как раньше; 6 — лишние поля тела отклоняются.

### 7. Применённые Stack Gotchas
17 (мок нотификатора целиком по `spec`, а не патч `Bot` на инстансе), 51 (DEV_MODE закреплён в тестах), 60 (`tsc -b`).

### 8. Новые Stack Gotchas
Нет.

### 9. Использование плагинов
py_compile/прогон — да; typecheck — да; context7 (FastAPI `extra=forbid`) — да; tdd — да.
