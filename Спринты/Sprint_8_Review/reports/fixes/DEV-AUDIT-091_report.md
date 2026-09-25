## DEV-AUDIT-091 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту

### 1. Что реализовано
1. `detect_corporate_actions(tickers, today=None)`: добавлены **сплиты** — `GET /iss/statistics/engines/stock/splits.json` (общий список, фильтр по `secid`) и **купоны** — `GET /iss/securities/{secid}/bondization.json?iss.only=coupons&limit=100&start=N` (пагинация ≤10 стр.).
2. Формат подтверждён живым read-only GET 24.09 (`splits`: `tradedate/secid/before/after`; `coupons`: `coupondate/recorddate/value/value_rub/faceunit`); фрагменты — фикстурами.
3. gotcha-70: разбор по блоку и колонкам; нет — warning `iss_*_block_missing`, действий нет. Сбой источника не глушит остальные.
4. Сплит: `before→ratio_from`, `after→ratio_to` (GMKN 1:100 → объём ×100; формула не тронута). `ex_date = record_date = tradedate` — первый день в новом масштабе, `process_pending` (090) проводит сплит в этот день. Сплит с `tradedate < today` пишется `processed=True`: позиции после него уже в новом масштабе, строка нужна предупреждению бэктеста.
5. Купон: `ex_date = coupondate` (всегда есть, уникален — ключ дедупа), `record_date = recorddate` ISS (момент начисления по 090; fallback `coupondate`). Сумма `value_rub`, иначе `value`; без суммы — пропуск. Горизонт `today ≤ coupondate ≤ today+366` — иначе весь график до погашения и десятки уведомлений.
6. Купоны — только для облигаций с открытой сделкой: тип из кэша `Instrument`, для `unknown` — эвристика тикера SU/RU/XS/OFZ (как `tax/service`).
7. Предупреждение бэктеста: `corporate_action_warning()` в `backtest/service` по таблице `corporate_actions`, подключено в `_build_backtest_response` в существующее поле `warning` (фронт уже рендерит Alert): «В периоде был сплит 08.04.2024 (1:100): цены до сплита не скорректированы.»

### 2. Файлы
Новый: `backend/tests/unit/test_corporate_actions/test_audit_s8r_detect_sources.py`. Изменены: `backend/app/corporate_actions/service.py`, `backend/app/backtest/service.py`, `backend/app/backtest/router.py`, `backend/tests/unit/test_backtest/test_api.py`, `backend/tests/unit/test_corporate_actions/test_split_value_preservation.py` (фикстура `opened_at`).

### 3. Тесты
RED (чистый код, повторно через patch→checkout→apply): `ImportError: cannot import name 'corporate_action_warning' from 'app.backtest.service'`; detect-тесты после первого среза: `TypeError: detect_corporate_actions() got an unexpected keyword argument 'today'`. GREEN: 6 тестов нового файла + `test_get_backtest_warns_about_split_in_period`. Мутация `ratio_from=int(after), ratio_to=int(before)` → `assert (100, 1) == (1, 100)` → откат → 6 passed.
Гейты: pytest 2781 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.

### 4. Integration points
✅ `corporate_action_warning` — `app/backtest/router.py:913`; ✅ `_detect_splits/_detect_coupons/_bond_tickers_with_open_positions/_action_exists` — `corporate_actions/service.py:715–723` внутри `detect_corporate_actions` (scheduler `service.py:231`, `POST /detect`). Новых эндпоинтов/event_type нет.

### 5. Контракты
Схемы без изменений (`warning` уже в `backtestApi.ts:110`). Миграций нет.

### 6. Проблемы / правки документов / находки
- ФТ §6.4: «Сплиты и купоны детектируются из MOEX ISS (`splits.json`, `bondization.json`); купоны — по облигациям в открытых позициях, на год вперёд; сплит, применённый до обнаружения, позиции не пересчитывает (S8R-AUDIT-091)». ФТ §4.2 (стр. 318): «предупреждение о сплитах — реализовано; крупные дивиденды — нет».
- Уведомление «дата отсечки {ex_date}» для купона — дата выплаты. Back-adjust свечей — Sprint 9.

### 7. Применённые Stack Gotchas
70, 28, 30 (патч на границе `_get_client`), 15 (`today` в МСК).

### 8. Новые Stack Gotchas
Нет. Кандидат: `bondization` — 20 строк по умолчанию, `limit` ≤ 100.

### 9. Плагины
py_compile после правок `.py`; `tsc -b`/lint/build; context7 не нужен (живой GET ISS); скилл `mattpocock-skills:tdd`.

### Доработки по /code-review
Тесты первыми (три новых в `test_audit_s8r_detect_sources.py`, раздел «Доработки по /code-review»), RED на коде до правок:
- #1 `test_past_split_with_old_position_stays_pending` → `assert True is False` (`processed`);
- #2 `test_process_split_rescales_only_positions_opened_before_trade_date` → `assert (1000, Decimal('1.50000000')) == (10, Decimal('150'))`;
- #3 `test_backtest_warning_for_ticker_without_session` → `assert None == 'В периоде был сплит 08.04.2024 (1:100): …'`.

Правки (`corporate_actions/service.py`):
1. Прошлый сплит: `processed=True` только если по тикеру нет `filled/open` позиций с `opened_at` < 00:00 МСК `tradedate` (`_has_positions_opened_before`); иначе `processed=False` и в «новых» — `process_pending` пересчитает старые позиции.
2. `process_split`: условие `LiveTrade.opened_at < split_opened_before(action.ex_date)` (новый хелпер, 00:00 МСК → naive UTC, как `accrual_opened_before`). Формула `SplitAdjustment` не тронута. Фикстура C7-тестов (`test_split_value_preservation.py`) получила `opened_at=2026-05-01` — позиции «держались на сплите» 12.05, семантика прежняя.
3. Выбран вариант «хранить сплиты по всем `secid`»: запрос и так один и общий (57 строк с 2018), дедуп тот же, без сети и таймаутов в момент запроса бэктеста. `new_actions` (уведомления, `detected_count`) — только по переданным тикерам; чужой прошлый сплит без позиций — `processed=True`, будущий — `processed=False` и станет no-op в `process_pending` (или пересчитает позиции, если сессия появится до `tradedate`, — корректно). Уведомления scheduler и так фильтруются по сессиям с тикером.

GREEN: 9 passed (файл карточки) + 68 в корп. действиях/бэктесте/scheduler/роутере. Мутация: снят фильтр `opened_at` в `process_split` → `assert (1000, Decimal('1.50000000')) == (10, Decimal('150'))` → откат → 9 passed.
Гейты: pytest 2784 passed / 16 xfailed / 0 failed; ruff 0; mypy Success (179); bandit rc 0; фронт не менялся.
