## DEV-AUDIT-045 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (не закоммичено). **Ревью р.3: исправлено 1–8** (р.2: 1–6 — ранее).
### 1. Что реализовано (р.3)
1. На выходе резолв FIGI и пометка «в полёте» перенесены в `try/finally`, который освобождает свой адаптер (`engine.py:4779`). Заодно закрыта прежняя утечка при сбое commit'а пометки.
2. `select_tradable_instrument`: сначала `MOEX_BOARD_PRIORITY` (TQBR, TQTF, TQCB, TQOB, TQIR, TQPI, TQIF), прочие классы — только если основных нет, при равенстве — стабильный ключ `(class_code, figi)`. `pool[0]` больше не используется.
3. `ensure_figi_lookup` возвращает `FigiLookup`. В `_fetch_via_broker`: источник ответил «нет» → `NotFoundBrokerError`; источник молчит → `figi=None`, адаптер резолвит сам.
4. Запасной резолв движка кэшируется в `_FALLBACK_FIGI_CACHE` по `(broker_account_id, тикер)`, TTL = `FIGI_NEGATIVE_TTL` (15 мин). Хранит и найденный FIGI, и «не найдено» брокера; сбой связи не кэшируется; не больше 512 записей.
5. Старт стрима: если справочник промолчал или ответил «нет», запасной резолв адаптера не запускается. На старт — одно сетевое ожидание; повторит watchdog.
6. `/candles/subscribe` вызывает `ensure_figi`, только если стрима ещё нет (`needs_subscription`). Исключение из `ensure_figi` даёт `figi=None`, а не `source: error`.
7. `_resolve_stream_source` возвращает счёт, токен и FIGI; `ensure_figi_lookup` вызывается с id того же счёта в той же сессии БД. `_resolve_broker_credentials` стал обёрткой над ним.
8. Одна нормализация `broker_figi()` рядом с `is_paper_figi`; её вызывают `order_figi`, адаптерный `_broker_figi` и `resolve_trade_figi`.
### 2. Файлы
- app: `broker/{base,tinvest/adapter}.py`, `market_data/{service,router,stream_manager}.py`, `trading/{engine,runtime,paper_engine}.py`.
- Новые тесты: `test_adapter_figi_class_code.py` (16), `test_order_figi_from_ensure_figi.py` (11), `test_stream_figi_from_ensure_figi.py` (2).
- Правки тестов в р.3:
  - `test_e2_lot_size_instrument_choice.py` — плюс 2 теста;
  - `test_service_full.py`, `test_market_data_router.py` — плюс 2 теста;
  - `test_runtime_recovery.py` — подмена переведена на `_resolve_stream_source`;
  - `test_token_selection.py` — фейковый `find_instrument` отвечает по запрошенному тикеру;
  - `tests/conftest.py` — сброс кэша запасного резолва.
### 3. Тесты
- Мутация р.3: вернуть `pool[0]` → `AssertionError: assert _Inst(…'SPBRU'…) is _Inst(…'TQTF'…)`, плюс ещё 2 теста красные. Откат из бэкапа, md5 совпал.
- Гейты: pytest 3725 passed / 4 xfailed / 0 failed; ruff 0; mypy Success (189); bandit M0/H0.
- Прогон со сторожем `AsyncClient` (плагин в scratch): реальных клиентов 0.
### 4. Integration points
✅ `engine.py:1044` (вход и выход); `runtime.py:1307`, `runtime.py:1362`, watchdog `:1709`; `router.py:195`; `service.py:891`, `service.py:207`.
### 5. Контракты
API и миграции не менялись.
### 6. Проблемы / TODO
- **п.4, почему резолв не вынесен до `close_trade`.** Адаптер берётся внутри критической секции (lease `S8R-AUDIT-027`, `_resolve_broker_adapter`). Вынести резолв — значит построить адаптер до лока и поменять владение lease. Лок — только на свою сделку: у свежей сделки входа он никем не занят, у выхода сериализует повторное закрытие, так и задумано. С кэшем сеть уходит не чаще раза в 15 мин на `(счёт, тикер)`, время ограничено 3 × `TINVEST_UNARY_TIMEOUT_SEC`.
- **п.5, худший случай restore (молчащий брокер).** N сессий с разными тикерами без FIGI в `instruments` → N × `FIGI_LOOKUP_TIMEOUT_SEC` (10 с). До 045 было так же: `share_by` под дедлайном 10 с. Сессии с уже открытым стримом справочник не спрашивают. В тесте одно ожидание 0,2 с на старт, проб 0. Бюджет 009 (предзагрузка портфелей) это не затрагивает.
- **Самопроверка:**
  - п.1: `trade.figi` на входе — отдельный commit до отправки; на выходе — тот же commit, что пометка;
  - п.5: все вызывающие перечислены в разделе 4.
- **Не чиним:**
  - (а) выход старых сделок по сохранённому FIGI — пункт гайда;
  - (б) кэш промахов адаптерного перебора — частично закрыт п.4.
- **ТЗ §5.6, предлагаемый текст:** «Выбор инструмента из ответа `find_instrument` (`select_tradable_instrument`) — один для FIGI, лотности и ордеров: точное совпадение тикера; среди торгуемых через API (`api_trade_available_flag`, иначе среди всех) — режим по приоритету TQBR → TQTF → TQCB → TQOB → TQIR → TQPI → TQIF; прочие класс-коды — только при отсутствии основных; при равенстве — наименьший `(class_code, figi)`. Порядок ответа брокера на выбор не влияет».
### 7–8. Gotchas
Применены 57, 30, 48, 74. Новых нет.
### 9. Плагины
py_compile, tdd. Не чинили: (а) и (б) из раздела 6.
