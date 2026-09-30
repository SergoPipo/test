## DEV-FIX-028 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Функция `money_class(mode)` теперь возвращает сам режим: `paper` / `sandbox` / `real`. Класса `broker` больше нет, вместо `MONEY_CLASS_BROKER` введены `MONEY_CLASS_SANDBOX` и `MONEY_CLASS_REAL`.
- `_day_sessions_of_class` отбирает сессии фильтром `TradingSession.mode == cls`. Поэтому у каждого класса своя база порога (Σ `initial_capital`) и своя пауза (`scope=money_class`).
- Подписи классов: «бумажная торговля» / «песочница» / «реальный счёт». Они попадают в `reason` события CB.
- `get_status` и `CheckStatusResponse` отдают поля `daily_pnl_{paper,sandbox,real}` и `daily_loss_limit_{paper,sandbox,real}`. Поле `daily_pnl` — сумма трёх классов. Поля `_broker` удалены: потребителей нет ни во фронте (grep `frontend/src` пуст), ни в Telegram.
- Override сессии (`scope=own`) и остальные проверки CB не менялись.

### 2. Файлы
Изменены:
- `backend/app/circuit_breaker/{engine,service,schemas}.py`
- `backend/tests/test_circuit_breaker/test_daily_loss_base.py`: 4 теста переведены на три класса, тест `test_mixed_broker_base_sandbox_and_real` удалён — он закреплял прежнее решение Q5-070.

Новый: `backend/tests/test_circuit_breaker/test_daily_loss_three_money_classes.py` (5 тестов).

### 3. Тесты
- **RED:** `AssertionError: assert ['paper', 'broker', 'broker'] == ['paper', 'sandbox', 'real']`; `assert [False, False] == [True, False]` (порог real); `KeyError: 'daily_pnl_sandbox'`.
- **GREEN:** 5/5 тестов карточки, каталог `test_circuit_breaker` — 134 passed.
- **Мутация:** в `_day_sessions_of_class` вернул фильтр `mode != "paper"` для не-paper классов, то есть снова объединил sandbox и real. Результат — `assert [False, False] == [True, False]` и `position_size_limit == daily_loss_limit` (блока по дневному лимиту нет). Мутация откачена через бэкап, md5 совпал.
- **Гейты:** pytest 4241 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (192); bandit 0 находок; typecheck 0; lint 0; build ok; grep по маркерам ничего не нашёл (0).
- **vitest:** фронт не менялся — снимается на уровне пакета.

### 4. Integration points
✅ `engine.py:442` `_sessions_of_class`, `:532` `_check_daily_loss_limit`, `:1130` `_trigger` (в `money_class` payload `cb.triggered` теперь `sandbox`/`real`); `service.py:180-182` — `router.py:98` `GET /status`.

### 5. Контракты
В ответе `GET /circuit-breaker/status` поля `_broker` заменены на `_sandbox` и `_real`; во фронте их никто не читает. Значение `money_class` в `cb.triggered` — `sandbox`/`real` вместо `broker`. Миграции нет.

### 6. Проблемы / правки ФТ-ТЗ / находки
- **ФТ §12.4, п. «Дневной лимит убытков».** Заменить «раздельно для бумажной торговли и для песочницы вместе с реальным счётом … *Вопрос заказчику:* … разделить ли их.» на: «считается **раздельно для трёх классов денег — бумажная торговля, песочница, реальный счёт** (S8R-AUDIT-070; с 2026-09-30 песочница и реальный счёт разделены, S8R-FIX-028): убыток — …; порог — фиксированная сумма либо % от суммы стартовых капиталов сессий класса. При превышении на паузу встают стратегии только этого класса: убыток песочницы не останавливает реальный счёт, а капитал песочницы не увеличивает порог реального счёта.»
- **ТЗ шапка 3.0 / §5.x.** Заменить `money_class (paper / broker = sandbox+real)` на `money_class = mode (paper / sandbox / real, S8R-FIX-028)`. В `get_status` поля `daily_pnl_{paper,sandbox,real}` и `daily_loss_limit_{…}`.
- **Новые находки:**
  - (a) В `reason` порог выводится без округления: «лимит -500.000000», `engine.py` `_check_daily_loss_limit`.
  - (b) В статусе у класса без сессий порог равен `0`, а не `None`. Так было и до правки.
- **Самопроверка:**
  1. Новых путей записи нет.
  2. Уведомление по-прежнему одно; изменилась только подпись класса.
  3. Тесты идут реальным путём `check_before_order` → `_trigger`.
  4. Таймаутов не касался.
  5. Все вызывающие перечислены в п. 4, поведение осознанное.
  6. Не применимо.

### 7. Применённые Stack Gotchas
18 и 37 — контекст `_trigger`, не менялся. 78 — не затронут.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
- pyright/py_compile: да, 3 файла.
- typecheck: да.
- context7: не требовался (сторонние API не менялись).
- tdd: `mattpocock-skills:tdd`.
