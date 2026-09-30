## DEV-AUDIT-085 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Мастер считает Telegram готовым только при `tgLinked === true`, то есть при статусе `linked` из `GET /telegram/status`. Успешный тест готовность не ставит. Состояние `tgTestPassed` удалено целиком: читать его больше некому, а неиспользуемое состояние ловит TS6133. После отвязки `tgLinked=false`, поэтому авто-включения нет.
- Авто-включение `telegram_enabled` для 4 критичных событий при реальной привязке не трогал, оно покрыто тестом. Сохранение настроек из мастера по-прежнему идёт через `notificationApi`.
- `notificationStore.updateSetting`: снимок строки до патча. При ошибке откатываются только поля этого патча и только если их не перезаписал более поздний патч; новая строка удаляется. Текст ошибки пишется в `settingsError` через `getApiErrorMessage`. Экшен ничего не бросает (gotcha-45). Добавлен `clearSettingsError`.
- `NotificationSettingsPage` показывает `settingsError` в закрываемом Alert. Комментарий «13 типов» заменён на «все типы EVENT_TYPE_LABELS (= EVENT_MAP)». Строки «17 типов» в файле уже не было.
- «Очистить все» открывает модалку подтверждения с кнопками «Отмена» / «Удалить все» (паттерн `VersionsHistoryDrawer`). `@mantine/modals` в проекте нет.
- Хвост 084: у `TelegramNotifier.send` появился параметр `retry` (по умолчанию `True`). `send_test_telegram` передаёт `retry=False`: одна попытка, без повторов и без ожидания `RetryAfter`.

### 2. Файлы
Новый: `frontend/src/components/notifications/__tests__/NotificationList.test.tsx`.
Изменены:
- бэкенд: `backend/app/notification/{telegram.py, service.py}`, `backend/tests/test_notification/test_telegram_test_endpoint.py`;
- фронт: `FirstRunWizard.tsx` и его тест, `NotificationList.tsx`, `notificationStore.ts` и его тест, `NotificationSettingsPage.tsx` и его тест.

### 3. Тесты
- RED:
  - мастер: `expected [ [ 'trade_opened', …(1) ], …(3) ] to deeply equal []`;
  - стор: `expected [] to deeply equal [ Array(1) ]`, `expected null to be 'Не удалось сохранить настройку уведом…'`;
  - список: `expected "vi.fn()" to not be called at all, but actually been called 1 times`;
  - бэкенд, 3 кейса TimedOut / 5xx / RetryAfter: `assert 'sent' == 'failed'`.
- GREEN: все.
- Мутации:
  - мастер со старой логикой из HEAD (готовность по `tgTestPassed`) → `expected [ [ 'trade_opened', …(1) ], …(3) ] to deeply equal []`;
  - `retry=True` → `assert 'sent' == 'failed'`.
  - Обе откачены из бэкапа, md5 совпадают.
- Гейты: pytest 4396 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (192); bandit Medium 0 / High 0; typecheck 0; lint 0; build ok; vitest 1012 passed.

### 4. Integration points
✅ `service.py:578` (`retry=False`). Боевые вызывающие без изменений: `service.py:544` и `dispatchers.py:50` используют `retry` по умолчанию, то есть с повторами. ✅ `NotificationSettingsPage` → `settingsError`/`clearSettingsError`; `NotificationList` → модалка → `deleteAll`.

### 5. Контракты
API не менялся. Миграции нет.

### 6. Проблемы / TODO / правки ФТ-ТЗ
- ФТ §19.6 («Мастер первого запуска»), добавить: «Telegram считается подключённым только после привязки через `/start <код>`; тестовое сообщение — проверка связи, не условие. Уведомления Telegram для 4 критичных событий включаются только при привязке».
- ФТ §10: «Если сервер не сохранил настройку, тумблер возвращается в прежнее положение и показывается текст ошибки сервера»; «„Очистить все“ — с подтверждением».
- Решение заказчика «сбрасывать `tgTestPassed` при отвязке» выполнено удалением состояния. Если нужен индикатор «тест пройден», его можно вернуть как чисто визуальный.
- Самопроверка:
  1. БД не трогал.
  2. Уведомлений не добавлял.
  3. Бэкенд-тест идёт через настоящий `TelegramNotifier`, `Bot.send_message` патчится на классе; путь по умолчанию покрыт тестами 083.
  4. Таймаутов не добавлял.
  5. Все вызывающие `send` проверены.
  6. —

### 7. Применённые Stack Gotchas
17, 40 (`userEvent`), 45 (экшен не бросает), 60.

### 8. Новые Stack Gotchas
Нет.

### 9. Использование плагинов
py_compile/прогон, typecheck (`tsc -b`), tdd — да. context7 не нужен: Mantine `Modal` уже используется в проекте тем же паттерном.
