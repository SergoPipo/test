## DEV-AUDIT-025 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (с доработками по /code-review)

### 1. Что реализовано
- `live_trades.lot_size` пишется в `process_signal`. `derive_lot_size`: сначала колонка, деривация — только для NULL-строк; налоги и корп. действия идут через неё.
- `RiskMonitor.position_lots`: одно количество для ордера, P&L и комиссии выхода.
- Активный `partially_filled` (вход и выход) → опрос до терминала.
- Частичный выход — только терминальный `rejected`/`cancelled` с `0 < исполнено < заявлено`. P&L и комиссия считаются по исполненной части; пометка и пауза пишутся в транзакции закрытия; уведомление `recovery_mismatch` (critical), как у recovery.
- Контракт paper `volume_rub` не изменён.

### 2. Файлы
Новые: миграция `e9e5c919fbbf_live_trades_lot_size.py`, `test_partial_fill.py`, `test_derive_lot_size_after_fill.py`.
Изменённые: `trading/{engine,risk_monitor,runtime,models}.py`, `notification/service.py` (EVENT_MAP), `tax/service.py` и `corporate_actions/service.py` (докстринги), `frontend/.../NotificationSettingsPage.tsx` (метка), тесты `test_engine_sandbox_flow.py`, `test_migration.py`, `test_event_sync_publishers.py`, `test_event_delivery_e2e.py` (счётчик EVENT_MAP 18→19).

### 3. Тесты
RED карточки: `filled_lots=6`, `P&L …: 700.00`, `множитель …: 7`.
GREEN: 14/14.
Мутации карточки: `volume_lots` в P&L → `1000.00`; выход из опроса → `'pending' == 'filled'`.
Гейты: pytest 2927 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit rc 0; typecheck 0; lint 0; build ok; vitest 934 passed.

### 4. Integration points
✅ `engine.py:2705, 3513, 3992–3996, 3866`; `risk_monitor.py:877`; `notification/service.py:115` ↔ `EVENT_TYPE_LABELS.recovery_mismatch`, sync-тест зелёный.

### 5. Контракты
Миграция `e9e5c919fbbf` (down `b8e4d17c9a52`): одна голова; round-trip up→down→up на чистой БД прошёл (1/0/1). Добавлено событие EVENT_MAP `position.mismatch` → `recovery_mismatch`.

### Доработки по /code-review
1. Синхронный `partially_filled` на выход → опрос. RED `assert 1 == 2` (await_count). Мутация «сразу учитывать» → `1 == 2`.
2. P&L и комиссия по исполненным лотам выхода, `filled_lots` = закрытое, `lot_size` закрепляется. RED `P&L … 600.00 == 400.00`. Мутация `exit_lots=None` → `600.00 == 400.00`.
3. Деривация для NULL-строк: `volume_rub / (entry_price × filled_lots)` (до fill — сигнал × `volume_lots`); у pending-строк `lot_size` закрепляется до fill. RED `7 == 10`, `420.00 == 600.00`.
4. Пометка и пауза — тем же commit, что закрытие. RED `пометка расхождения потеряна … None is not None`.
5. `_partial_exit_lots` смотрит только терминал с `0<x<N`. RED: ложные «0 из 6» и «6 из 6».
6. `position.mismatch` → `recovery_mismatch`/critical вместо `order.partial_fill`. Докстринг `_order_status_as_response` исправлен.

### Контрольный проход (поверх `1bba46b`, не закоммичено)
- **Правка:** recovery (`runtime._recover_orphan_exit_orders`) определяет частичный выход тем же `_partial_exit_lots(state, position_lots)`, что и движок. Пара считается до `finalize_exit_order`, в `_flag_partial_exit` передаётся `(исполнено, заявлено)`.
- **Развилка, решил сам:** убрано исключение «активный `partially_filled` = исполнен».
  - Без этого recovery закрывал бы сделку на полный объём без пометки, и остаток не отслеживался бы.
  - Теперь как у движка: свежий активный ордер ждёт; после `STALE_PENDING_CANCEL_THRESHOLD_SEC` остаток отменяется, терминал учитывается по факту.
  - Второй встречный ордер блокирует пометка «в полёте».
- **Тесты** (`test_reconcile_review_fixes.py::TestPartialFillIsVisible`). RED (4 failed):
  - `… 10 из 10 … остаток не закрыт' is None`;
  - `'6 из 10' in '… 6 из 0 лот(ов) …'`;
  - `assert 'closed' == 'filled'`;
  - `cancel_order … Awaited 0 times`.
- `test_partial_fill_flags_mismatch` переписан под устаревший ордер: отмена → `cancelled` 3/10 → P&L на 3 лота, «3 из 10», пауза.
- GREEN: 24/24.
- **Мутация** «флаг при status ≠ filled с парой из state» → `10 из 10 … is None`, `6 из 0`; откачена, md5 совпал.
- **Гейт:** pytest 2930 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit rc 0. Фронт в этом проходе не менялся.
- **ТЗ §5.4:** «recovery закрывающего ордера: активный `partially_filled` ждёт порога, затем отмена остатка; частичный выход — по тому же правилу, что движок».

### 6. Документы / находки
- Гайд §7: head `e9e5c919fbbf`; «колонка `live_trades.lot_size`, старые строки — деривация, действий не требуется».
- ТЗ §5.4 — пп. 1 выше.
- ФТ §19.12: добавить в EVENT_MAP `recovery_mismatch` — движок публикует `position.mismatch`, в настройках появилась строка «Расхождение позиций с брокером».
- Находки, не исправлял:
  - (а) закрыта контрольным проходом;
  - (б) событие шины теряется, если слушатель сессии снят (сессия остановлена);
  - (в) полноценное частичное закрытие (разделение сделки) не реализовано.

### 7. Gotchas: 12, 27, 33, 37, 53, 57, 71.
### 8. Новые — нет.
### 9. Плагины: py_compile + mypy; tdd (skill); context7 не требовался.
