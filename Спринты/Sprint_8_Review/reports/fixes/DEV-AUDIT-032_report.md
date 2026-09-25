## DEV-AUDIT-032 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (итерация 3, после двух проходов код-ревью)

### 1. Что реализовано
Карта: уже учитывали направление `ir_codegen`, parity-shadow, SL/TP, P&L `_apply_close`, `unrealized.py`, CB equity 068, налоги, сторона выхода. Работали только для long: сторона ордера в live, paper `apply_close`, сверка с брокером, CB `short_block`.
- `Signal.entry_direction` + `opens_position`. `SignalProcessor` выбирает сторону по `ir.entry_direction`. Раньше short-стратегия в live открывала long.
- `process_signal`:
  - встречные сделки (filled + pending) выбираются один раз до CB;
  - CB вызывается, только если есть `user_id`, сигнал может открыть позицию и встречных сделок нет;
  - сигнал против направления стратегии без позиции → HOLD, лог на DEBUG.
- Рантайм: CB пропускается для выхода и для сигнала против направления. Проверка выхода — `engine.is_exit_signal`, как раньше только по `filled`; обёртка в runtime удалена. Раньше `short_block` ставил long-сессию на паузу.
- `short_block`: не-SELL и заявленный short проходят без запроса в БД.
- `apply_close(*, direction)` — параметр обязательный. У short Δequity = pnl − комиссия.
- `models.is_long_direction` используют `apply_close`, сверка и `PaperBrokerAdapter.get_positions`.
- Сверка с брокером, штуки со знаком:
  - пауза, если позиция у брокера меньше нашей по модулю или противоположного знака;
  - нетто 0 при нуле у брокера — не расхождение, если у работающих сессий тоже 0;
  - если у работающих сессий позиция есть — расхождение с текстом «0 шт нетто, у работающих сессий N шт» и пауза;
  - в текстах short помечен «short N шт», long — прежним текстом (дедупликация уведомлений).

### 2. Файлы
Изменены: `app/trading/{engine,runtime,paper_engine,risk_monitor,models}.py`, `app/circuit_breaker/engine.py`.
Тесты: новый `tests/test_trading/test_paper_short_blocked_or_accounted.py` (27 тестов). Поправлены `test_order_manager`, `test_engine_sandbox_flow`, `test_close_position_concurrency`, `test_sltp_review_fixes`, `test_paper_accounting_be_trad_06`, `test_fix9_is_exit_signal_aliases`.

### 3. Тесты
- RED: `assert <app.trading.models.LiveTrade object at 0x114559750> is None`.
- GREEN: 27/27.
- Мутации:
  - `apply_close` без ветки short → `assert Decimal('999900.00') == Decimal('1000100')`;
  - снят HOLD-guard → `assert <LiveTrade …> is None`;
  - ревью-2 п.1: гейт CB без `not exit_trades` → `Expected mock to not have been awaited. Awaited 1 times.` (2 теста).

  Все мутации откатаны из cp-бэкапа, md5 совпал.
- Гейты: pytest 3035 passed / 10 xfailed / 0 failed; ruff 0; mypy Success (180); bandit M0/H0.
- Фронт не менялся. Первая итерация: typecheck 0, lint 0, build ok; vitest — на уровне пакета.

### 4. Integration points
✅ `engine.py:1538`, `:1658`, `:1714`, `:732` (из `runtime.py:2857`); `runtime.py:2119`, `:2169`; `paper_engine.py:102`, `:200`; `circuit_breaker/engine.py:726`; `apply_close` — `engine.py:4308`, `risk_monitor.py:330`.

### 5. Контракты
API, схемы и `block_shorts` не менялись; миграции нет. Внутренний контракт: у `apply_close` параметр `direction` обязательный (keyword-only).

### 6. Правки ФТ-ТЗ / находки
- **ФТ §1.3, §16 п.4, строка Won't в таблице приоритетов:** «Позиции long и short. Направление задаёт стратегия (блок «Вход»). Сигнал выхода без открытой позиции пропускается. В paper по short резервируется обеспечение, равное стоимости входа; результат = (вход − выход) × штуки − комиссия. В sandbox/real short без маржинального доступа брокер отклоняет — это обычный отказ ордера.»
- **ФТ §12.4:** «short, не заданный стратегией, блокируется».
- **ТЗ §5.4, §5.8** — то же; в промпте AI (стр. 1961) стоит «Только long».
- **Вопрос заказчику:** что делать с флагом `block_shorts` — штатно он не срабатывает.
- **Ревью-1:** исправлено 1–5, тесты 6.
- **Ревью-2:** исправлено 1–6.
- **Находки:**
  - inline-копии проверки направления (`risk_monitor` 128/236/640/780, `unrealized` 120, `service` 479/714, `engine` 3958);
  - архитектура: намерение ENTRY/EXIT лучше передавать в `Signal`, а не выводить из `entry_direction` в нескольких местах;
  - `_apply_close_and_settle` считает выручку по `volume_lots`, а не по `position_lots`;
  - paper-просадка не учитывает нереализованный P&L.

### 7. Gotchas
03, 05, 18, 23, 35, 57.

### 8. Новые gotcha
- Кандидат: «`evaluate` возвращает условие (вход/выход), а не сторону ордера».
- Кандидат: «заглушка `apply_close` со старой сигнатурой вешает тест конкурентного закрытия».

### 9. Плагины
py_compile (fallback), tdd (скилл), typecheck; context7 не нужен (backtrader читался по исходнику).
