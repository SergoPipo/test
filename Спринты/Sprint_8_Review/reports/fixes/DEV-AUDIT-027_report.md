## DEV-AUDIT-027 отчёт — S8R fixes, MEDIUM (итерация 3, ревью-2)
Статус: ✅ готово к коммиту

### 1. Что реализовано
- **База `percent`** — свободный капитал сессии (`session_capital`, только БД):
  - paper — свежий `balance` в `paper_portfolio_section`;
  - sandbox/real — `min(free, свободные рубли счёта из GetPositions.money RUB)`;
  - в обоих режимах — не больше базы, проверенной CB (`Signal.cb_percent_base`).
- **CB без сети.** Проекция ордера считается от `free`. Лимит `risk_max_position_pct` для `percent` — от `equity` сессии; для `fixed_sum`/`fixed_lots` — от `initial_capital`, как до карточки.
- **Ревью-2: исправлено 1–8.**
  1. `NOT_FOUND 50004` при чтении рублей → `_recover_stale_sandbox_account` и повторное чтение по новому счёту; ордер уходит на новый счёт.
  2. Лимит от `equity` применяется только к `percent`.
  3. Владение адаптером — через `_AdapterLease`:
     - `process_signal` держит аренду в `try/finally` → `_open_entry`;
     - `_submit_order_locked` забирает адаптер до первого `await`;
     - единый `_release_adapter` используется на входе, в обоих `finally` пути закрытия и при чтении рублей.
  4. Пропуск «рублей нет / не получены» — одно `order.error` на серию (`_ACCOUNT_CASH_SKIP_STREAK`, сброс в `forget_below_lot_series` и при полученных рублях).
  5. CB записывает проверенную базу в `signal.cb_percent_base`, движок берёт минимум из своей базы и этой.
  6. После сайзинга — `reserve_available_cash` под поколением чтения, до `place_order`. Комментарий «счёт не уходит в минус» заменён честным.
  7. `cancel_order` сбрасывает кэш рублей.
  8. Открытая сделка без `volume_rub` → стоимость = цена входа (или сигнала) × `position_lots` × `derive_lot_size`.

### 2. Файлы
- Новые: `backend/app/broker/cash_cache.py`, `backend/tests/test_trading/test_position_sizing_percent_base.py`.
- Изменённые: `backend/app/trading/engine.py`, `backend/app/circuit_breaker/engine.py`, `backend/app/broker/tinvest/adapter.py`.

### 3. Тесты
- RED (итерация 1): `AssertionError: percent считается от initial_capital: 100 лотов вместо 50`.
- GREEN: 29/29 в файле карточки. Новые тесты:
  - переоткрытие счёта;
  - fixed_sum после убытка — CB не блокирует;
  - база CB ограничивает ордер движка;
  - серия пропусков — одно уведомление;
  - резерв на две сессии счёта;
  - `cancel_order` сбрасывает кэш;
  - сделка без `volume_rub`;
  - отмена во время чтения рублей и во время ожидания лока сделки.
- Новая мутация «без резерва» → `test_second_session_same_account_sees_reserved_cash`: `200 == 100`.
- Контрольная мутация «без release в finally» → падают оба теста на отмену.
- Все мутации откачены через бэкап, md5 сверен.
- Гейты: pytest 3483 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (188); bandit M0/H0. Фронт не менялся, vitest — на уровне пакета.

### 4. Integration points
✅ `engine.py:2306` (`_open_entry`), `:2345` (`_account_rub_cash`), `:2348` (`_skip_account_cash`), `:2356/2391` (`cb_percent_base`), `:2468` (резерв), `:3274/3322` (lease/release на отправке), `:4462/4632` (закрытие), `circuit_breaker/engine.py:555`, `adapter.py` (`forget` в `place_order`/`cancel_order`/`sandbox_pay_in`).

### 5. Контракты
API, схемы и миграции не менялись. В `Signal` добавлено поле `cb_percent_base` (по умолчанию `None`).

### 6. Документы и находки
- **ФТ §3.4**, первый пункт: «**% от свободного капитала сессии** (с 2026-09-26, S8R-AUDIT-027): paper — свободный кэш виртуального портфеля; sandbox/real — стартовый капитал сессии + реализованный результат − комиссии − открытые позиции сессии, но не больше свободных рублей счёта. Раньше считалось от начального капитала. Рублей нет или их не удалось получить — сигнал пропускается, одно уведомление на серию. Лимит размера позиции для % — от капитала сессии, для фиксированных режимов — от стартового.»
- **ТЗ §5.4 / §5.8** (история версии 3.0): «`S8R-AUDIT-027`: `session_capital` (free/equity, БД); база `percent` — paper `balance` в секции, sandbox/real `min(free, GetPositions.money RUB)`, не больше `Signal.cb_percent_base`; кэш рублей 30 с на счёт: поколения, резерв после сайзинга, сброс на `place_order`/`cancel_order`/`sandbox_pay_in`, проверка до построения адаптера, `_AdapterLease` — один адаптер на сигнал; переоткрытие sandbox-счёта при `50004`; CB без сети: проекция от `free`, лимит `risk_max_position_pct` от `equity` только для `percent`.»
- **Ограничение:** резерв работает только внутри процесса и пока значение в кэше. Ордера вне терминала между чтением и исполнением не учтены — при нехватке ордер отвергнет брокер.
- **Самопроверка:**
  1. Новые записи в БД есть только у переоткрытия счёта — существующий механизм, выполняется до записей входа и без локов входа.
  2. Одно `order.error` на серию; тип — как у пропуска «меньше лота».
  3. Тесты проходят через реальный адаптер, секцию и лок `close_trade`.
  4. Сети под локом CB нет; отмена освобождает адаптер.
  5. Проверены все вызывающие: `calculate_position_lots`, `_submit_order_*`, путь закрытия.
  6. Неприменимо.

### 7. Применённые Stack Gotchas
05, 30, 56, 57, 58 (колонки вместо ORM в `session_capital`), 59, 74, 78.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile — ok; context7 (`PositionsResponse`) — в итерации 2; tdd — `mattpocock-skills:tdd`.
