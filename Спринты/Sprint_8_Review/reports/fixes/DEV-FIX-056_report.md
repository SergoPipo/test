## DEV-FIX-056 отчёт — S8R fixes, FIX
Статус: ✅ готово к коммиту (wt-s8r-fixes, база `2d460cf`, не закоммичено)
### 1. Что реализовано
- Новый хелпер `canonical_ticker(db, value, user_id)` в `app/market_data/ticker_resolver.py`. Порядок: кэш процесса (24 ч, запасной ответ 5 мин) → справочник `instruments` без учёта регистра → T-Invest → ISS SECID → upper с записью `ticker_canonical_unresolved` в журнал. Ответ источника выравнивает справочник отдельной сессией: `SIZ6` переименовывается в `SiZ6`.
- `Ticker` теперь только проверяет формат (`[A-Za-z0-9._-]`), регистр не меняет.
- Канонизация подключена в точках входа: свечи, sparkline, subscribe, инструмент, лого, облигации ×3, бэктест ×3, сессии (`TradingService.start_session`, до локов), алерты, избранное, detect.
- Сервисы лота, FIGI и лого больше не вызывают `.upper()`. Справочник ищется без учёта регистра, `_persist_instrument_cache` не создаёт дублей в другом регистре.
- Свечи ISS для фьючерсов идут через `engines/futures/markets/forts`, тип берётся из справочника.
- Фронт регистр не меняет: `normalizeTicker`, `BacktestLaunchModal`, `GridSearchForm`.
### 2. Файлы
Новые: `ticker_resolver.py`, `tests/test_market_data/test_audit_s8r_ticker_canonical.py`, `frontend/.../__tests__/tickerCase.fix056.test.tsx`. Изменены 14 файлов backend и 4 файла фронта (`git status`).
### 3. Тесты
- RED: `AssertionError: assert 'SIZ6' == 'SiZ6'`, `'market:sber:1m' != 'market:SBER:1m'`; vitest — `expected 'SIZ6' to be 'SiZ6'`.
- GREEN: 15 backend-тестов + 4 vitest.
- Мутация: убрал канонизацию в `start_session` → упал тест `test_one_instrument_one_session_catches_lower_case` (`assert 200 == 422`, создана сессия `sber`). Мутация откачена, md5 совпал.
- Гейты: pytest 5190 passed / 0 xfailed / 0 failed; ruff 0; mypy Success (200); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 1139 passed.
### 4. Integration points
✅ `market_data/router.py:106,154,206,304,339,408,422,436`; `backtest/router.py:492,1277,1525`; `trading/service.py:213`; `price_alert_router.py:35`; `user_favorites/service.py:105`; `corporate_actions/router.py:102`.
### 5. Контракты
- Миграции нет.
- API принимает тикер в любом регистре и возвращает канонический. Pydantic-схемы регистр не меняют.
- В ISS-парсер добавлены поля `iss_type` и `group`.
### 6. Проблемы / ФТ-ТЗ / находки
- Существующие данные: в справочник всё писалось в верхнем регистре, сидов в миграциях нет. Фьючерс там может лежать как `SIZ6`. Такой строке хелпер не верит (верхний регистр + тип futures или unknown), спрашивает источник и переименовывает строку. Старые сессии `SIZ6` (если они есть) рядом с новой `SiZ6` не конфликтуют: сравнение строгое, так решил оркестратор.
- ФТ §14.1: «Тикер … приводится к верхнему регистру» заменить на «…регистр приводится к каноническому написанию инструмента (SBER, SiZ6)».
- ТЗ §5.6: добавить абзац «Канонический тикер (S8R-FIX-056)» с порядком резолва (см. п.1); свечи фьючерсов ISS — `engines/futures/markets/forts`.
- Находки вне карточки:
  - `TInvestAdapter._resolve_figi` вызывает `.upper()`;
  - `get_lot_size` ISS ходит только в `stock`;
  - `ChartPage.tsx:94` (алерты) и `recentInstruments`/Sparkline/parseCommand на фронте вызывают `toUpperCase`;
  - поиск `/instruments` фьючерсы отфильтровывает.
- Самопроверка:
  1. статусов нет; сбой записи справочника — только warning.
  2. уведомлений нет.
  3. тесты идут через HTTP и мокают источники (`_find_tradable_instrument`, `_request`).
  4. ISS вызывается под `wait_for` (только сеть), сеть — до локов.
  5. вызывающие `ensure_figi`/`ensure_lot_size` получают те же значения.
  6. detect — до 50 тикеров, только для админа.
### 7. Применённые Stack Gotchas
37, 60, 70, 74, 81.
### 8. Новые Stack Gotchas
Нет.
### 9. Плагины
py_compile/mypy; `pnpm typecheck` (tsc -b); живой GET ISS для формата `description` и пути `futures`; context7 не понадобился (новых API нет); скилл `mattpocock-skills:tdd`.

---
## DEV-FIX-056 — раунд 2 код-ревью
Статус: ✅ готово к коммиту (не закоммичено)
1. Добавлены `ticker_eq`/`ticker_in` (`app/common/ticker.py`): тикеры в БД теперь сравниваются без учёта регистра. Где применено:
   - конфликт сессий (старт и возобновление);
   - фильтр списка сессий;
   - налоговые типы — ключ ответа = тикер сессии;
   - корп. действия: сессии по `action.ticker`, join, `_bond_tickers`, список;
   - `splits_in_period`, планировщик;
   - избранное: только инструмент, таймфрейм сравнивается строго (`1m`≠`1M`);
   - алерты.

   **Отступление для `ohlcv_cache`:** вместо `upper()` используется `ticker IN (канон, канон.upper())`. `upper()` выключил бы индекс и вёл бы к полному просмотру кэша на каждом чтении графика и CB. Канон берётся без сети через `known_canonical` (кэш или доверенная строка справочника), им же пишет `get_candles`.
2. Фолбэк: в кэш не пишется. Смешанный регистр остаётся как есть, иначе тикер переводится в верхний регистр. Ненадёжная строка справочника каноном не считается.
3. Одновременные запросы по одному тикеру делают один резолв (будущее регистрируется до первого `await`, ожидающие защищены `shield`). Сетевой путь помечен `@timed_event("ticker.canonical_resolve")`. `_persist_instrument_cache` записывает тип из ответа T-Invest (лот, лого).
4. Detect работает с `network=False`: берёт тикер из кэша или справочника, иначе upper.
5. ISS-клиент резолвера создаётся на каждый запрос и закрывается в `finally`.
6. Фронт: `sameTicker` (`utils/tickerMatch.ts`) в ChartPage и recentInstruments; Sparkline и parseCommand не меняют регистр. На бэке так же: `slash_context._ticker_id_or_none` не меняет регистр.
7. `_resolve_figi` больше не вызывает `.upper()`, только `strip()`. **⏸ Лот ISS фьючерса — отступление:** у `engines/futures/markets/forts` нет LOTSIZE. `LOTVOLUME` там — объём базового актива (Si = 1000 USD), а не лот: подстановка дала бы ошибку sizing ×1000. Поэтому для futures ISS возвращает `None` без запроса, лот берётся только от T-Invest. Предложение: если нужен ISS-лот фьючерса, принять 1 контракт — это решение по деньгам, оно за заказчиком.

RED: `assert 200 == 422` (legacy `SIZ6` при старте и возобновлении); `[] == ['ABCD']`; `'SIZ6' == 'SiZ6'`; `{'SBER': _Entry…} == {}`; `concurrent operations are not permitted`; `['/iss/securities/gazp.json'] == []`; `probed ['SIZ6']`; vitest `id 'SIZ6'`, `getSparkline('SIZ6')`.

Мутации, обе откачены, md5 совпали:
- п.1: в `engine.py` возвращено `TradingSession.ticker == ticker` → 2 failed `assert 200 == 422`;
- п.2: фолбэк `value.upper()` → `'SIZ6' == 'SiZ6'`.

Тесты под новый контракт: `test_current_candle_merge` (мок `known_canonical`), `test_fallback_normalizes_ticker` (теперь только strip).

Гейты: pytest 5204 passed / 0 xfailed / 0 failed; ruff 0; mypy Success (200); bandit M0/H0; typecheck/lint/build 0; vitest 1143 passed.

Находки:
- `runtime.py:3296` сравнивает `position.ticker == session.ticker` с учётом регистра; `runtime.py` не трогал, там нужен test-first;
- ключ `drawingsPersistence` хранится в upper.

---
## DEV-FIX-056 — раунд 3 (две находки)
Статус: ✅ готово к коммиту (не закоммичено)
1. Добавлен `same_ticker` в `app/common/ticker.py`. Он используется в `runtime.py` (сверка позиций, оба сравнения) и в `TInvestMapper` (`source` по `strategy_tickers`). Других сравнений тикера в runtime/engine/broker grep не нашёл. Тесты в `test_audit_s8r_ticker_case_reconcile.py`, RED:
   - `'external' == 'strategy'` — legacy-сессия `SIZ6`, позиция брокера `SiZ6`;
   - `False is True` — бумага `SiZ6` без нашей сделки теперь показывается как «куплено вручную», без паузы.

   Совпадение по FIGI не считается расхождением.
2. `drawingsPersistence`: ключ строится по тикеру как пришёл. Старый ключ в верхнем регистре читается и переносится под канонический. vitest RED: `expected null not to be null`.

Гейты:
- ruff 0, mypy Success (200);
- pytest: файл карточки + `test_trading` + `unit/test_broker` — 1325 passed;
- typecheck 0, lint 0, vitest 1145 passed.

---
## DEV-FIX-056 — раунд 4 (ревью по 7bbf291)
Статус: ✅ готово к коммиту (правки поверх 7bbf291, не закоммичено)

1. **ohlcv_cache.** `_one_row_per_bar`: одна строка на бар, канон в приоритете (порядок `timestamp, ticker==канон DESC`). Та же схема в `last_cached_bar`. `_find_gaps` считается уже по дедуплицированному ряду.
2. **Single-flight.**
   - Ключ — (тикер, есть ли у пользователя T-Invest).
   - Лидер — отдельная задача в своей сессии БД (`AsyncSession(bind=db.bind)`), к ней `shield`.
   - Любая ошибка даёт фолбэк, функция не бросает.
3. **Негативный кэш** — 60 с на тикер.
4. **Доверие справочнику и фолбэк.**
   - Строке доверяем только при известном виде инструмента. Без вида это заглушка или написание вызывающего (`Sber`).
   - Фолбэк — upper.
   - `_persist_instrument_cache` пишет тикер и вид из ответа T-Invest (FIGI, лот, лого).
5. **`network=False`.** Отдаёт известный канон, иначе upper.
6. **Пропущенные сравнения:**
   - `chart_drawings` list/clear — `ticker_eq`;
   - сводка стратегии — ключ по upper, отображается тикер бэктеста;
   - фронт: `OpenPositionsLayer` и `FavoritesPanel` — `sameTicker`.
7. **Каналы стрима.** `SessionRuntime.start` строит канал и стрим по `known_canonical(session.ticker)`; `listener.ticker` тоже канон.
8. **Миграция `fb26c08f99c8`** (обратимая): индекс `ix_instruments_ticker_upper ON instruments(upper(ticker))`. Он же объявлен в модели. `alembic check` чист, SQLAlchemy при этом пишет предупреждение «expression index не отражается». План запроса индекс использует.

RED (фактические строки):
- `(21, 1) != (21, 2)` (дубль бара);
- `'SIZ6' == 'SiZ6'` (отмена лидера);
- `OperationalError database is locked` (ошибка БД);
- лишний `/iss/securities/XYZ1.json` (негативный кэш);
- `'Sber' == 'SBER'`;
- `[('SIZ6','futures')] == [('SiZ6','futures')]`;
- detect `['SIZ6'] == ['SiZ6']`;
- рисунки 0 вместо 1;
- сводка: 2 строки вместо 1;
- канал `market:SIZ6:1h`;
- индекса нет;
- vitest: `attachPrimitive 0 times`, кнопка «добавить» видна.

Мутации, откачены, md5 совпали:
- п.1: без дедупликации → `(21, 1) != (21, 2)`;
- п.2: `await task` без `shield` → `CancelledError` у ожидающего.

Гейты:
- pytest 5219 passed / 0 xfailed / 0 failed;
- ruff 0; mypy Success (200); bandit M0/H0;
- alembic heads = `fb26c08f99c8`, round-trip пройден на временной БД;
- typecheck, lint, build — 0; vitest 1147 passed.

**Гайд §7, текст для вставки:** «`fb26c08f99c8` — индекс `ix_instruments_ticker_upper` по выражению `upper(ticker)` (S8R-FIX-056): поиск справочника без учёта регистра. Создаётся мгновенно, данные не меняются; откат `alembic downgrade -1` удаляет индекс.»
