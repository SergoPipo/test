## DEV-AUDIT-095 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (правка в `market_data/service.py` — см. §6, /code-review)
### 1. Что реализовано
- `_calculate_tax_base`: единая база обращающихся ЦБ, `max(0, Σ share+bond+etf)` (Q6-095 = a, ст. 214.1 НК РФ); NEEDS-REVIEW снят; `by_type` — справочная разбивка. Ставки 13/15 %, порог 5 млн, MSK-границы, дисклеймер sandbox не тронуты; купоны/НКД/дивиденды — как были.
- `_resolve_instrument_types`: тип из справочника `instruments.type` одним запросом на отчёт, без сети; `_tax_category` нормализует T-Invest/ISS-значения (share/`*_bond`/etf/`*_ppif`); `unknown`, currency, futures… → не распознан.
- `_build_lots(..., type_by_ticker=)`: справочник → иначе эвристика `_detect_instrument_type` (fallback).
- Пометка в файле (xlsx и csv): «Тип инструмента определён по тикеру (нет в справочнике инструментов): A, B…».
- Источник типа: `_fetch_figi_from_tinvest` берёт `InstrumentShort.instrument_type`, `FigiLookup.instrument_type` (default None), `ensure_figi_lookup` пишет `type` в кэш вместе с FIGI.
### 2. Файлы
Новый: `tests/unit/test_tax/test_audit_s8r_instrument_type.py`. Изменены: `app/tax/service.py`, `app/market_data/service.py`, `tests/unit/test_tax/test_fifo.py` (тест раздельной базы → сальдирование), `test_audit_s8r_lots.py` (парсер CSV не считает строки-пометки лотами).
### 3. Тесты
RED: `{'MYFUND': 'share'} != {'MYFUND': 'etf'}`, `assert Decimal('100000.00') == Decimal('60000.00')`, `('BBG000FUND01', 'unknown') == ('BBG000FUND01', 'etf')` — 8 failed. GREEN: 8 passed. Мутация «вернуть раздельную базу» → `assert Decimal('100000.00') == Decimal('60000.00')` (4 failed), откат через бэкап, md5 совпал.
Гейты: pytest 4527 passed / 3 xfailed / 0 failed (первый прогон повис на `test_ws_sessions.py::test_auth_via_cookie` под параллельной нагрузкой — faulthandler; файл отдельно 6/6, повтор полного зелёный); ruff 0; mypy Success (196); bandit rc 0; typecheck/lint/build 0; vitest: фронт не менялся — на уровне пакета.
### 4. Integration points
✅ `tax/service.py:199` `_resolve_instrument_types`; `:404` `_tax_category`; `:684/:767` `heuristic_type_note`; `market_data/service.py:1842` запись `type`; `ensure_figi_lookup` вызывается `engine.py:2841`, `runtime.py:1397`.
### 5. Контракты
API/схемы/миграции — без изменений. `FigiLookup` +поле с дефолтом.
### 6. Проблемы / правки ФТ-ТЗ / находки
- Тикеры, чей FIGI уже в кэше, в T-Invest не ходят → `type` остаётся `unknown` → эвристика с пометкой. Предложение: разовый бэкфилл типов (решение оркестратора).
- Futures/валюта/опционы (ПФИ — отдельная база) идут эвристикой в «share» с пометкой, как раньше — вопрос заказчику.
- Купоны, НКД, дивиденды в базе — вопрос заказчику/бухгалтеру.
- ФТ §18.2, заменить «Раздельный учёт…»: «Единая налоговая база по операциям с обращающимися ЦБ (ст. 214.1 НК РФ; решение заказчика S8R-AUDIT-095): результаты акций, облигаций и ETF/БПИФ сальдируются в пределах года; разбивка по типам — справочная. Тип инструмента — из справочника (T-Invest), при его отсутствии — по тикеру с пометкой в отчёте. Учёт купонов, НКД и дивидендов не менялся.» ТЗ §5.13 — аналогично + «`instruments.type` пишется при резолве FIGI».
- Самопроверка: 1 — запись типа в отдельной сессии кэша (сбой → warning, как FIGI); 2 — н/п; 3 — реальный `_fetch_figi_from_tinvest` и `generate_report`; 4 — под `wait_for` только сеть; 5 — `_build_lots`/экспорт: старые вызовы — дефолты; 6 — тип усечён до 20.
### 7. Stack Gotchas
30, 37, 48.
### 8. Новые — нет.
### 9. Плагины
py_compile/mypy; `tsc -b`; context7 заменён сверкой со схемой установленного SDK (`InstrumentShort.instrument_type: str`); tdd — скилл загружен.
