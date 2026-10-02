## DEV-AUDIT-048 отчёт (код-ревью, раунд 4) — S8R fixes, LOW
Статус: ✅ готово к коммиту

### Правки
1. **Сверка при «счёт уже переоткрыл сосед или кнопка».** Ветка `UNCHANGED` с другим счётом теперь тоже вызывает `_reconcile_positions_after_reopen`. Сверка решает по фактическим позициям текущего счёта: `_live_position_figis` читает портфель без справочника, а `keep_figis` (`_not_live_on_account`) исключает сделки, чей FIGI есть в портфеле. Поэтому повторная сверка идемпотентна. Сделка без FIGI (старые записи) закрывается, как и раньше. Если портфель не прочитан, сверка пропускается с WARNING: закрыть реальную позицию хуже, чем оставить фантом до периодической сверки.
2. **Потолок ожидания квоты — 10 с и только для отправки** (PostOrder и Cancel). Чтения ждут квоту без потолка. `read_worst_case_sec` и докстринг `runtime` возвращены (38 с).
   - Путь выхода: `QuotaNotAcquiredError` — подкласс `OrderNotSentError`. `is_definitive_rejection` считает его отказом, `_resolve_lost_exit_response` снимает пометку `exit_order_placed_at` и пробрасывает `BrokerError`, а не `OrderInFlightError`. Следующий тик SL/TP или клик отправляет ордер заново.
   - Тест: первый выход падает, второй закрывает сделку.
3. In-flight: ждущий не наследует ошибку владельца, а делает своё чтение.
4. Хелпер `assert_caller_session_clean` вызывается в начале `_recover_stale_sandbox_account` и `_account_rub_cash`, до их первого запроса. В recovery проверка оставлена как защита.
5. Сверка `runtime` читает позиции с `fetch_instrument_info=False` — тикер берётся только из кэша. Следствие: при холодном кэше информационная пометка «куплено вручную» не выводится — тикер равен FIGI, сверка идёт по FIGI.
6. `get_sandbox_balance` повторяет запрос на новом счёте; `reopen_sandbox_account` отвечает `reopened=True` с новым id.
7. Агрегация WARNING о свечах без времени: счётчик + до 5 FIGI за окно. Сброс по таймеру окна, при закрытии потока и при `stop()`. Очередь умершего стрима сразу перестаёт быть текущей.
8. `_operation_sort_key` переведён на `mapper._broker_time`.
9. Выбор: `_reset_instrument_cache_for_tests`, только для тестов. Справочник не зависит от токена, поэтому сбрасывать его при смене ключа бессмысленно.

### Тесты
- RED: например `'filled' == 'closed'` (фантом не закрыт), `0 == 2` (сверка не шла), `assert 27.0 == 21.0`, `reopened=False`.
- GREEN: 78 passed.
- Мутации (откат через бэкап, md5 совпал):
  - п.1 «сосед — без сверки» → `assert 1 == 2` и `'filled' == 'closed'`;
  - п.2 «потолок на всё» → `QuotaNotAcquiredError … (operations)`.

### Гейты
- pytest: 4759 passed / 1 xfailed / 0 failed (`faulthandler_timeout=240`).
- ruff 0; mypy Success (194); bandit 0 Issue.
- typecheck 0; lint 0; build ok; vitest 1058 passed.
- Coverage `rate_limiter.py` — 100 %.

Integration: NOT CONNECTED нет. Ничего не закоммичено.
