## DEV-AUDIT-093 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (vitest — нагрузочный флейк, см. §3/§6)

### 1. Что реализовано
1. `MOEXISSClient.get_trading_calendar` → GET `/iss/engines/stock.json?iss.only=dailytable` (прежний `…/markets/shares/dates.json` — ISS отвечал 200 описанием рынка, блока `dates` нет; в `/iss/history/…` он есть, но это `from/till` доступности истории). `year` не фильтруем: 1 января до публикации нового года кэш остался бы пустым.
2. `MOEXISSParser.parse_calendar` — разбор по имени блока `dailytable` и обязательным колонкам `date`, `is_work_day`; иначе `[]`.
3. `MOEXCalendarService`: модель `dict[date, bool]` исключений; `is_trading_day` — приоритет ISS, вне таблицы Пн–Пт (сб/вс неторговые — политика заказчика), `RUSSIAN_HOLIDAYS` только пока ISS не загружен. `load_calendar()` → `bool`, `asyncio.wait_for(…, 15 с)`; нет клиента / таймаут / пусто → `warning` (`moex_calendar_no_client` / `_load_failed` / `_empty`), кэш не сбрасывается; успех → `moex_calendar_loaded count=N`.
4. Единый экземпляр: `set_calendar_service` / `get_calendar_service` в `moex_calendar.py` (модуль без `app.*`-импортов — циклов нет); lifespan создаёт `MOEXISSClient(settings.MOEX_ISS_BASE_URL)` + сервис, регистрирует, кладёт в `app.state.calendar_service`, грузит на старте; shutdown закрывает httpx-клиент и снимает регистрацию.
5. `SchedulerService(calendar_service=…)` (DI; без DI — общий экземпляр); джоба логирует `moex_calendar_synced` только при реальном обновлении, иначе `moex_calendar_sync_fallback`.
6. `market_data/router` и `multiplexer._is_moex_open_now` читают общий экземпляр (модульная копия и `MOEXCalendarService()` на каждый вызов удалены). Часы сессий и 072 не тронуты.

### 2. Файлы
Новый: `backend/tests/unit/test_scheduler/test_audit_s8r_calendar_wiring.py`. Изменены: `app/scheduler/moex_calendar.py`, `app/scheduler/service.py`, `app/broker/moex_iss/client.py`, `app/broker/moex_iss/parser.py`, `app/market_data/router.py`, `app/broker/tinvest/multiplexer.py`, `app/main.py`. Frontend не менялся (`git diff -- frontend` пуст).

### 3. Тесты
RED: 7 failed, `AttributeError: module 'app.scheduler.moex_calendar' has no attribute 'set_calendar_service'`; `assert None is True` (load_calendar). GREEN: 7 passed (`test_scheduler_calendar_has_iss_client`, `test_transferred_holiday_from_iss_overrides_fallback`, `test_router_and_multiplexer_use_shared_instance`, `test_missing_dailytable_block_falls_back_with_warning`, `test_no_iss_client_warns_and_keeps_fallback`, `test_iss_timeout_does_not_block_start`, `test_parse_calendar_reads_dailytable_by_block_name`). Мутация: `return override` → `pass` в `is_trading_day` → `assert False is True where False = is_trading_day(date(2024, 4, 27))`, откачена. Гейты: pytest 2718 passed / 21 xfailed / 0 failed; ruff 0; mypy Success (178); bandit 0; typecheck 0; lint 0; build ok; vitest 924 passed / 2 failed — таймауты 5000 мс `StrategyEditPageDelete.test.tsx` при load average 13–15 (соседние субагенты); файл в одиночку 2 passed; третий прогон под нагрузкой — 4 таймаута в трёх модальных файлах. Прошу повтор на тихой машине.

### 4. Integration points
✅ `app/main.py:173,176,186,305`; `app/scheduler/service.py:64,177`; `app/market_data/router.py:302,333`; `app/broker/tinvest/multiplexer.py:44`.

### 5. Контракты
API/схемы без изменений; миграций нет. Лог старта: `moex_calendar_loaded count=N`.

### 6. Правки документов / вопрос заказчику / находки
- ФТ §1.7: «Источник — MOEX ISS `/iss/engines/stock.json` (`dailytable`: праздники и рабочие дни по переносу); загрузка при старте (таймаут 15 с, недоступность ISS не блокирует запуск) и ежедневно 00:05 MSK; при недоступности — статичный список праздников с предупреждением в логе. Суббота и воскресенье — неторговые.»
- ФТ §1.6: без изменений часов; добавить «торговый день определяется календарём §1.7».
- ТЗ §5.9: `update_moex_calendar 06:00` → `sync_moex_calendar 00:05 MSK`; сигнатуры `MOEXCalendarService` — синхронные `is_trading_day/get_market_status/time_until_close`, `async load_calendar() -> bool`; один экземпляр (`app.state.calendar_service`, `get_calendar_service()`); fallback — `RUSSIAN_HOLIDAYS`.
- Гайд §3.3: строка старта `moex_calendar_loaded`; §8.1 job `sync_moex_calendar`.
- Вопрос заказчику: с 2025 MOEX проводит торги выходного дня (`timetable` ISS помечает все 7 дней рабочими). Считать ли сб/вс торговыми днями терминала (стримы, CB, уведомления, `/market-status`) и по какому расписанию? Сейчас — нет.
- Находка: fallback `RUSSIAN_HOLIDAYS` закрывает 3–8.01, 23.02, 8.03, где биржа торгует (по решению — не трогал).
- vitest-флейк модальных тестов под нагрузкой — кандидат в карточку.

### 7. Применённые Stack Gotchas
30 (импорт `get_calendar_service` на уровне модуля), 50 (проверки из cwd worktree), 26 (structlog без `event=`), 04/34 — прочитаны.

### 8. Новые Stack Gotchas
Симптом: ISS отвечает HTTP 200 на несуществующий ресурс (`…/markets/shares/dates.json`) описанием рынка; парсер по «ожидаемому» блоку молча даёт `[]`, а при чужих колонках — пустой кэш («все дни неторговые»). Причина: ISS игнорирует неизвестный сегмент пути. Правило: разбирать по имени блока и обязательным колонкам, пустой результат — warning и fallback, не замена кэша; формат проверять живым GET. Файлы: `app/broker/moex_iss/parser.py`, `app/scheduler/moex_calendar.py`.

### 9. Плагины
tdd — загружен, цикл RED→GREEN→мутация; pyright недоступен в worktree → `py_compile` 7/7 OK; typecheck `tsc -b` 0; context7 не потребовался (stdlib `asyncio.wait_for`, httpx-клиент существующий); WebSearch + живой GET — формат `engines/stock.json`.
