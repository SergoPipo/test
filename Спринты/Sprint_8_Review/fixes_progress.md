# Прогресс фиксов аудита — 2026-09-24

Промпт цикла: `prompt_s8r_fixes.md` (локальный). Порядок карточек — `prompt_s8r_audit_fixes.md` §1–§4, полный текст карточек — `audit_2026-09.md` §3.

## Ответы заказчика (Такт 1, 2026-09-24)
Q1=d (всё подряд до исчерпания ресурса, остановка на границе пакета) · Q2=a (PR #27 мержит исполнитель) · Q3=a (ветка на пакет `s8r/fix-blocker|high|medium|low`, коммит+пуш после карточки, PR после гейтов, **мерж — по команде заказчика**) · Q4: 001=a (исполняется только код из IR; fallback `generated_code` удаляется), 033=a (`/auth/setup` закрыт после первого пользователя, новые — только admin) · Q5: 032=**b** (чинить учёт денег под short, ФТ менять), 024/030=a (10 с), 027=a (свободный кэш / доступные средства), 070=a (paper и sandbox/real раздельно), 091=a (ISS-источники сплитов/купонов + предупреждение, без back-adjust) · Q6: 081=a (запуск только `active`) + **автоперевод статуса при запуске — да**; 087 — по рекомендации: (а) делистинг → понизить до Could, (б) валидация OHLCV → реализовать, (в) автопауза после N ошибок → реализовать, (г) частичное исполнение → реализовать (таймаут/отмена остатка/уведомление поверх 025), (д) §12.8 → актуализировать ФТ, (е) §4.2 → актуализировать ФТ; 095=a (единая база обращающихся ЦБ, ст. 214.1 НК РФ) · Q7=a (S-1/S-2/S-7 на счёте #3 после HIGH) · Q8=**b** (DEV-субагенты по `prompt_template.md`, ≤ 2 одновременно) · Q9=a (:8000/:5173) · Q10=a · Q11=**b** (F/H1/I2 ревьюерами sonnet после пакетов) · Q12: проверка `backend/logs/dev.log` поручена исполнителю «только числа» — **токена нет** (см. ниже) · Q13=b (команды — текстом в отчёте).

### Q12 — проверка `Develop/backend/logs/dev.log` (2026-09-24, только счётчики, значения не выводились)
Файл 25 МБ, последняя запись 08.07, права `rw-r--r--`. `api_key = '` → 0; рамки rich-traceback `│` → 0; токеноподобные `t.[A-Za-z0-9_-]{30,}` → 0; `api_key` → 20 — все в тексте исходника внутри traceback (`api_key, api_secret = …(` из `service.py:605`), значений нет. Вывод: перевыпуск токена не требуется; гигиена по желанию — `chmod 600`.

## Среда
worktree A: `/Users/sergopipo/Documents/Claude_Code/wt-s8r-fixes` | ветка: `s8r/fix-blocker` (от `origin/develop` 7ddb970, запушена: `9f676aa`) | PR: #28 | develop на входе: `eb769cc` → после мержа PR #27 `7ddb970`
worktree B (параллельный DEV, detached HEAD, без веток): `/Users/sergopipo/Documents/Claude_Code/wt-s8r-fixes-b`
стенд: поднимался для E2E BLOCKER (PID 63943/63944), остановлен; БД стенда удалена; кэш Vite `wt-s8r-fixes/frontend/node_modules/.vite*` — уйдёт с worktree | симлинк .env: нет
гейты BLOCKER «после» (9f676aa): pytest **2711 / 19 xfailed / 0**, coverage **87 %**, ruff 0, mypy Success (179), bandit M0/H0, typecheck/lint/build 0, vitest 925 + 1 флейк под нагрузкой (S8R-FIX-005), E2E 171/1/0.
гейты «до» (worktree A, 7ddb970): pytest **2625 passed / 25 xfailed / 0 failed** (193 с), coverage **87 %** | ruff 0 | mypy Success (178) | bandit Medium 0 / High 0 (Low 46) | alembic heads `a7b8c9d0e1f2` | typecheck 0 | lint 0 | build ok | vitest 924 passed + 2 expected fail / 132 файла | E2E — после пакета | gotcha: 60, INDEX v24

## Карточки
| Карточка | Пакет | Статус | RED (фактическая строка) | GREEN | Мутация | Гейты | Коммит | Ревью треб./рецепт/качество | Примечание |
|---|---|---|---|---|---|---|---|---|---|
| S8R-AUDIT-033 | BLOCKER | ✅ | `assert 201 == 403`; гонка `[201, 201] == [201, 403]`; admin `404 == 422`; лимитер `'general' == 'auth'` | 3 новых файла тестов + доказательный | setup без гейта → 3 failed; setup-status→auth → 1 failed | 2633/24xf/0; ruff 0; mypy ok; bandit 0; tsc 0; lint 0; build ok; vitest 926 | `967fe10` | — / — / — (после пакета) | /code-review: setup-status попадал в лимит auth — исправлено |
| S8R-AUDIT-002 | BLOCKER | ✅ | `DID NOT RAISE (ValidationError, ValueError)` ×2 | 2 доказательных + 15 новых + grid 422 | `_INDICATOR_COMMON = {}` → 12 failed; grid без проверки / OverflowError → red | 2662/23xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт без изменений | `47bf073` (cherry-pick `856d05f`) | — / — / — | /code-review: grid обходил проверку, int-переполнение → 500 — исправлено |
| S8R-AUDIT-001 | BLOCKER | ✅ | `AnalysisResult(is_safe=True, issues=[])`; `ExecutionResult(success=True, output='S8R_AUDIT_001_CWD=…')`; `DID NOT RAISE` (engine, bt.sys); `assert 202 == 422` (D1-04) | escape 30 + no_legacy 3 + restore/resume + router 404 | «голый datetime в namespace» → граница красная; `kind` из сырого type → red | 2711/19xf/0; ruff 0; mypy ok (179); bandit 0; tsc 0; lint 0; build ok; vitest 926 | `c6bf111` | — | /code-review ×2 (9+3 находки) исправлены; 028 закрыта целиком, 019 частично; gotcha-61 |
| S8R-AUDIT-034 | HIGH | ✅ | `DID NOT RAISE <class 'RuntimeError'>` (18 failed); lifespan без проверки ключа | 39 passed | `reason = None` → 13 failed | 2692/21xf/0; ruff 0; mypy ok; bandit 0; tsc 0; lint 0; build ok; vitest 926 | `b02f784` | — | /code-review не требуется (config/main/scripts) |
| S8R-AUDIT-035 | HIGH | ✅ | `DID NOT RAISE <class 'ValueError'>` ×2; `DID NOT RAISE AuthenticationError`; ws `TypeError … await`; ревизии нет (6 failed) | 6 passed + round-trip | «не инкрементировать версию» → 3 failed | 2698/21xf/0; ruff 0; mypy ok; bandit 0; tsc 0; lint 0; build ok; vitest 926 | `c7c3775` | — | миграция `c5e8b2a7f913` (down `a7b8c9d0e1f2`); /code-review: 2 находки — риск рецепта, принят |
| S8R-AUDIT-036 | HIGH | ✅ | «локал api_key утёк в traceback»; `api_key=SENTINEL…` в выводе (12 failed) | 13 passed | «убрать plain_traceback» → red | 2711/21xf/0; ruff 0; mypy ok; bandit 0; tsc 0; lint 0; build ok; vitest 926 | `2414d59` | — | /code-review: чисто; **gotcha-67** записан (INDEX v25) |
| S8R-AUDIT-007 | HIGH | ✅ | `assert 'failed' == 'pending'` (×2) | 16 passed | «вернуть failed в except» → 3 failed | 2765/16xf/0; ruff 0; mypy ok; bandit 0; tsc/lint/build 0; vitest 925+1 флейк | `a5f5c5b` | — | /code-review чисто |
| S8R-AUDIT-024 | HIGH | ✅ | `18 failed, 1 passed` (`AttributeError: client_order_id`); круги ревью: `17`/`11`/`2 failed` | 46 тестов `test_order_path_unknown_outcome.py` | «без запроса статуса», «без порога», «recovery без лока», «повтор внутри except» → red | 2820/16xf/0; ruff 0; mypy ok; bandit 0; tsc/lint/build 0; фронт не менялся | `9eb05c2` | — | миграция `d4f1a9c2b7e0` (down `c5e8b2a7f913`); /code-review ×3; gotcha-71 |
| S8R-AUDIT-030 | HIGH | ✅ | `E TimeoutError` (9 failed / 1 passed); ревью: `DID NOT RAISE BrokerError` ×2, `__cause__ = None` | 14 + 119 смежных | «без scope», «проглотить таймаут», «return False» → red | 2871/16xf/0; ruff 0; mypy ok; bandit 0; tsc/lint/build 0; фронт не менялся | `c04379b` | — | Q5=10 с; /code-review: 3 находки исправлены; gotcha-74 |
| S8R-AUDIT-074 | HIGH | ✅ | `assert None == 'sb-stop-1'` (broker_order_id потерян); `recovery не прогнан при shutdown … assert []`; ревью: `10.01s`, `3.24s` для 6 сессий | 5 тестов | «без shield», «без commit после отправки» → red | 2885/16xf/0; ruff 0; mypy ok; bandit 0; tsc/lint/build 0; фронт не менялся | `c4965e7` | — | + `stop_grace_period: 60s`; /code-review: 3 находки исправлены; gotcha-75 | | | | | | | |
| S8R-AUDIT-075 | HIGH | ✅ | `ордер в полёте должен дойти до пользователя / assert 0 == 1`; гонка: лишнее «не выполнено»; ревью: `OperationalError` выходит из check_sl_tp; кэш не чистится | 7 тестов | «вернуть таймер», «raise вместо None», «без prune» → red | 2894/16xf/0; ruff 0; mypy ok; bandit 0; фронт не менялся | `698d0e7` | — | /code-review: 2 находки исправлены | | | | | | | |
| S8R-AUDIT-061 | HIGH | ✅ | `assert 'FIGI-B' in ['FIGI-A']` (команда съедена); `unexpected keyword argument 'on_error'`; `singleton не снят`; `release 0 == 1` + 7 RED по кругам ревью | тесты reconnect/ack/терминала/держателей | «общая очередь», «игнорировать ack», «terminal=None», «без перепроверки listener» → red | 2834/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `54e88dc` | — | /code-review ×2 (4+3); gotcha-76 |
| S8R-AUDIT-025 | HIGH | ✅ (+ контрольная правка `fdfbb5c`) | `filled_lots=6`; `P&L … 700.00`; `множитель … 7` | 14 тестов | «volume_lots в P&L», «выход из опроса на partially_filled» → red | 2927/16xf/0; ruff 0; mypy ok; bandit 0; tsc/lint/build 0; vitest 934 | `1bba46b` | — | миграция `e9e5c919fbbf`; /code-review 6 находок исправлены; DEV на Opus |
| S8R-AUDIT-026 | HIGH | ✅ | `assert 1 == 0` (бюджет < лота); CB `размер 6000 > 5000`; `после resume нет уведомления` | test_position_sizing_budget + CB + 2 доказательных | «max(1)» → 7 failed | 2951/13xf/0; ruff 0; mypy ok; bandit 0; tsc/lint/build 0; vitest 937 | `cbd6541` | — | /code-review 4 находки; фронт-предупреждение убрано (S8R-FIX-014) |
| S8R-AUDIT-080 | HIGH | ✅ | `assert 201 == 422`; `DID NOT RAISE ValueError`; live `Decimal('50') == Decimal('98')` (SL из generated_code) | 53 backend + 4 vitest | «снять gt=0», «без проверки диапазона при сохранении» → red | 2998/12xf/0 (wt B); ruff 0; mypy ok (180); bandit 0; tsc/lint/build 0; vitest 940 + флейк | `10c1504` | — | TP ≤ 100 % (решение DEV, принято); /code-review 3 находки |
| S8R-AUDIT-032 | HIGH | ✅ | `assert <LiveTrade …> is None` (13 из 15) | 27 backend | «apply_close без ветки short» → `999900.00 == 1000100`; «снят HOLD-guard»; «гейт CB без exit_trades» → red | 3035/10xf/0; ruff 0; mypy ok (180); bandit 0; tsc/lint/build 0 (итерация 1); vitest — пакет | `c29aa23` | — | Q5=b; /code-review 3 прохода (5 + 6 находок исправлены); DEV на Opus |
| S8R-AUDIT-068 | HIGH | ✅ | `CheckResult(blocked=False, …)` ×2; статус `Decimal('0') == Decimal('12')`; ревью: ложный `Drawdown 9.09%` по устаревшей цене, пик `1000000 == 1100000` | 9 тестов | «paper-only», «без свежести», «без commit», «pnl IS NOT NULL» → red | 2854/14xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `6fbe378` | — | миграция `f6a2c8e41d93` (down `e9e5c919fbbf`); /code-review: 3 находки исправлены |
| S8R-AUDIT-069 | HIGH | ✅ | `DID NOT RAISE ValidationError` ×4; гонка ×4 | тесты 069/100/гонки 10/10 + фронт 3 | «снять проверку», «без лока», «аудит до лока» → red | 2845/15xf/0 (wt B); ruff 0; mypy ok; bandit 0; tsc/lint/build 0; vitest 937 | `25e95f9` | — | вместе со 100; stopped — вопрос заказчику |
| S8R-AUDIT-100 | HIGH | ✅ в составе 069 (`25e95f9`) | `StaleDataError … 0 were matched` | см. 069 | «без лока и перехвата» → red | см. 069 | `25e95f9` | — | | | | | | | | |
| S8R-AUDIT-055 | HIGH | ✅ | `expected 'http://localhost:8000/api/v1' to be '/api/v1'`; `'ws://localhost:8000' not to contain 'localhost:8000'`; preflight `'CORS_ORIGINS' in ''` | 8 vitest + 14 preflight | «абсолютный дефолт» → red | 2800/16xf/0; ruff 0; mypy ok; bandit 0; tsc 0; lint 0; build ok (0× localhost:8000); vitest 934 | `c93e1ad` | — | dev-proxy Vite добавлен (его не было) | | | | | | | |
| S8R-AUDIT-078 | HIGH | ✅ | `воркеры живы после cancel: pids=[…]`; `4 > лимита 2`; `job осталась в реестре _tasks` | 6 passed ≈ 3 с | «terminate только при отмене» → red | 2806/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `a3bb857` | — | /code-review: 2 находки исправлены; gotcha-73 | | | | | | | |
| S8R-AUDIT-093 | HIGH | ✅ | `AttributeError: … no attribute 'set_calendar_service'`; `assert None is True` (7 failed) | 7 passed | исключение ISS не применяется → `is_trading_day(2024-04-27)` False; без сброса календаря в conftest → 1 failed | 2718/21xf/0 (wt B); ruff 0; mypy ok; bandit 0 | `bca0cec` | — | ⏸→решение оркестратора: источник `engines/stock.json` dailytable; Сб/Вс неторговые (вопрос заказчику); /code-review: изоляция тестов исправлена; gotcha-70 |
| S8R-AUDIT-089 | HIGH | ✅ | `Decimal('100.00') == Decimal('1000.00')`; купон `137.50 == 875.00` | 4 passed | «без множителя» → red | 2722/21xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `6012089` | — | /code-review чисто |
| S8R-AUDIT-090 | HIGH | ✅ | `assert True is False` (processed); `Decimal('1000.00') == Decimal('0.00')` | 5 passed | «без фильтра даты», «rollback → pass» → red | 2774/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `04fb5cb` | — | /code-review: 2 находки исправлены |
| S8R-AUDIT-091 | HIGH | ✅ | `ImportError: cannot import name 'corporate_action_warning'`; `(1000, Decimal('1.5')) == (10, Decimal('150'))`; `processed True is False` | 9 passed + 68 смежных | «ratio перепутан», «без фильтра opened_at» → red | 2784/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `d138ef1` | — | /code-review: 3 находки исправлены | | | | | | | |
| S8R-AUDIT-092 | HIGH | ✅ | `restore не использует os.replace`; `DID NOT RAISE BackupError` ×2; `--server-port` не распознан; нет `BACKUP_DIR` | tests/test_backup 42 passed | «без файлового лока», «WAL до подмены» → red | 2794/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `464b8cd` | — | /code-review: 4 находки исправлены; gotcha-72, ретро gotcha-19 | | | | | | | |
| S8R-AUDIT-101 | HIGH | ✅ | `AssertionError: вызовы вернули разные записи: 1 и 2`; topup `пополнений: 2, ожидалось 1`; выжившая `{1: False} == {2: True}` | 9 тестов, гонка 10/10 | «без лока и без UNIQUE» → red | 2815/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `2ee8f06` | — | миграция `b8e4d17c9a52` (down переставлен на `d4f1a9c2b7e0`); /code-review: 2 находки исправлены | | | | | | | |
| S8R-AUDIT-099 | HIGH | ✅ | `активная сессия [1] ссылается на удалённый счёт №1: старт=TradingSession, удаление=NoneType` (10/10) | 2 теста, 10/10 подряд | «без лока в delete_account» → red | 2817/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `82b2a2a` | — | развилка DEV: перепроверка счёта в `_create_session_locked` (порядок «удаление первым»); /code-review чисто | | | | | | | |
| S8R-AUDIT-008 | MEDIUM | ✅ | `assert 'active' in {'paused','suspended'}`; `DID NOT RAISE NotFoundError`; `['active'] == ['suspended']` | 14 + 2 backend | «ранний commit active», «временный сбой → paused», «освобождать пару» → red | 3050/10xf/1 (FIX-016); ветка после переноса 013: 3104/8xf/0; ruff 0; mypy ok (180); bandit 0 | `a374468` | — | временный сбой → suspended (развилка рецепта, решение оркестратора); /code-review 3 прохода; хвосты → S8R-FIX-018 |
| S8R-AUDIT-009 | MEDIUM | ✅ | `AssertionError: несверенную сессию подняли`; `TimeoutError` (restore висит) | 11 backend | «без повтора при BrokerTimeoutError» → red | 3115/8xf/0; ветка после переноса 037: 3134/8xf/0; ruff 0; mypy ok (181); bandit 0 | `706c183` | — | молчание брокера (030) → paused, а не старт без сверки (решение оркестратора); /code-review 3 прохода; хвосты → S8R-FIX-019 |
| S8R-AUDIT-010 | MEDIUM | ✅ | `поднято: [] / assert [] == [2]` | 11 backend | «убрать suspended из тира 1», «проигравший в paused до исхода победителя» → red | 3145/8xf/0; ruff 0; mypy ok (181); bandit 0 | `025f929` | — | UI-чеклист S8.30; /code-review 2 прохода |
| S8R-AUDIT-011 | MEDIUM | ✅ | `неполный ответ песочницы принят за расхождение / assert True is False` | 20 backend | «вернуть список», «не сбрасывать счётчик», «любая отсутствующая бумага = неполный» → red | 3166/8xf/0 (2:46); ветка после переноса 038/039: 3250/8xf/0; ruff 0; mypy ok (182); tsc 0 | `abb6e07` | — | развилка ФТ v3.6 п.(2): sandbox-only + подтверждение за 3 прохода (решение оркестратора); /code-review 3 прохода; S8R-FIX-020 |
| S8R-AUDIT-012 | MEDIUM | ✅ | `бар, переживший обрыв, отдан стратегии / assert 1 == 0` | 29 backend | «буферизовать», «не учитывать интервал обрыва», «не дозагружать», «listener игнорирует флаги» → red | 3279/8xf/0; ветка после переноса 040/041: 3378/8xf/0; ruff 0; mypy ok (186) | `e55d0aa` | — | модель — интервал обрыва (решение оркестратора после 2 ревью); S8R-FIX-022 |
| S8R-AUDIT-029 | MEDIUM | ✅ | `после «Стоп» открыто позиций: 1 (entry_price=['301.00000000'])` | 13 backend | «снять лок», «без shield», «однократный перехват отмены» → red | 3391/8xf/0; A после переноса 021: 3407/8xf/0 | `0ec78a5` | — | gotcha-77 `89ded45`; /code-review 3 прохода |
| S8R-AUDIT-076 | MEDIUM | ✅ | `blocked_amount 0.00 ≠ стоимость открытых позиций 9000.00` | 6 backend (5 прогонов без флейка) | «снять лок» по 4 путям, «лок после flush» → red | 3413/8xf/0; A после переноса 058/056: 3454/8xf/0 | `3e27737` | — | CB: commit паузы до закрытий (решение оркестратора); gotcha-78 `a799b52`; /code-review 2 прохода |
| S8R-AUDIT-027 | MEDIUM | ✅ | `percent считается от initial_capital: 100 лотов вместо 50` | 29 backend | «база = initial_capital», «лимит CB от initial_capital», «без поколения», «без резерва», «без освобождения адаптера» → red | 3483/8xf/0; A после переноса 057: 3512/8xf/0 | `47a2ce6` | — | модель «капитал сессии ∧ RUB счёта» — решение оркестратора в рамках Q5=a; /code-review 3 прохода |
| S8R-AUDIT-070 | MEDIUM | ✅ | `вердикты (большая, маленькая) = [False, True]` | 14 backend | «порог от капитала одной сессии», «override на класс» → red | 3526/8xf/0 | `b770a1e` | — | вопрос заказчику: sandbox+real одним классом; /code-review 2 прохода |
| S8R-AUDIT-071 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-072 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-044 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-045 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-046 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-047 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-062 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-063 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-006 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-077 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-013 | MEDIUM | ✅ | `DID NOT RAISE WebSocketDisconnect`; `assert 200 == 401` (login); `['telegram','email'] == []` | 18 + 21 backend | «проверку jti → pass» → 6 red | 3087/8xf/1 (FIX-016, wt B); ruff 0; mypy ok (180); bandit 0; tsc/lint/build 0 | `e2ecb03` | — | разрыв открытых WS ⏸ → S8R-FIX-017; /code-review 3 прохода |
| S8R-AUDIT-037 | MEDIUM | ✅ | `ValueError: Аккаунт заблокирован`; 5× `assert 429 == 200`; п.2 ревью `assert 6 == 1` | 2 + 18 backend | «lockout в refresh», «убрать IP-потолок», «не сбрасывать счётчик» → red | 3107/8xf/0 (wt B); ruff 0; mypy ok (181); bandit 0 | `25143f8` (wt B, перенос в A — позже) | — | 127.0.0.1:80:80, доверие только nginx 172.28.0.10; Docker не запускался; /code-review 3 прохода |
| S8R-AUDIT-038 | MEDIUM | ✅ | `E assert 200 == 403` (8 failed) | 88 CSRF + 22 preflight | «fail-open», «Origin и без cookie», «refresh с double-submit» → red | 3174/8xf/0 (wt B); ruff 0; mypy ok (182); bandit 0; tsc/lint/build 0 | `16daf82` (wt B) | — | Dash-mount POST без X-CSRF-Token — проверить на стенде пакета; /code-review 3 прохода |
| S8R-AUDIT-039 | MEDIUM | ✅ | `assert 401 == 204`; фронт `expected false to be 'unavailable'` | backend + vitest (session/client/aiStream) | «logout требует access», «повтор и на 5xx» → red | 3191/8xf/0 (wt B); ruff 0; mypy ok (182); bandit 0; tsc/lint/build 0; vitest 952 | `1247c46` (wt B) | — | path refresh-cookie /api/v1/auth; E2E auth-hardening — на уровне пакета; /code-review 2 прохода |
| S8R-AUDIT-040 | MEDIUM | ✅ | `AttributeError: … 'COOKIE_SECURE'`; `{'access_token': {False}} != {True}` | 46 + 77 backend | «secure = not DEBUG», «дефолт auto в проде» → red | 3244/8xf/0 (wt B); ruff 0; mypy ok (183); bandit 0; tsc/lint/build 0 | `e914a72` (wt B) | — | fail-closed дефолт (решение оркестратора, см. 33); /code-review 2 прохода |
| S8R-AUDIT-041 | MEDIUM | ✅ | `ImportError: cannot import name 'secrets_rotation'` | 46 backend | «не перешифровывать AI», «is_current → False», «без _weak_secret_reason», «роль при импорте» → red | 3290/8xf/0 (wt B); ruff 0; mypy ok (186); bandit 0 | `5fc4fa9` (wt B) | — | гайд §6а «Ротация секретов»; /code-review 3 прохода |
| S8R-AUDIT-021 | MEDIUM | ✅ | `AssertionError: ✅ Telegram привязан…` (6-я попытка) | 16 backend | «снять лимит», «сброс при успехе» → red | 3306/8xf/0; B после синхронизации с A: 3394/8xf/0 | `b24e1ab` (wt B) | — | /code-review 2 прохода |
| S8R-AUDIT-058 | MEDIUM | ✅ | `DID NOT RAISE WebSocketDisconnect`; `'subscribed' == 'forbidden'`; AI `[200,200,200,200,403]` | backend + vitest | «снять лимит», «close_user вместо close_session», «без проверки отзыва» → red | 3426/8xf/0; vitest 964; B после синхронизации: 3439/8xf/0 | `35c3ba8` (wt B) | — | nginx `^~ /ws` чинит мультиплексор в проде; /code-review 3 прохода |
| S8R-AUDIT-057 | MEDIUM | ✅ | `assert set() == {'content-sec…'}`; `tax_download None == 'no-store'` | backend + vitest | «add_header в location статики» → red | 3477/8xf/0; vitest 964/965 (флейк S8R-FIX-005); B после синхр.: 3483 | `dcbcc12` (wt B) | — | CI nginx-config; /code-review 2 прохода |
| S8R-AUDIT-056 | MEDIUM | ✅ | `_favicon.ico` → location статики (5 failed) | 13 (test_nginx_conf) | «убрать ^~» → red | 3448/8xf/0 (wt B) | `64f114b` (wt B) | — | правка в одну строку; /code-review не требовался (nginx вне списка), smoke после деплоя |
| S8R-AUDIT-015 | MEDIUM | ✅ | `DID NOT RAISE IntegrityError`; `DROP TABLE trading_sessions — FOREIGN KEY constraint failed` | pragmas + delete FK + CB router | «убрать FK=ON», «убрать FK OFF в env», «удалять и running» → red | 3503/7xf/0 (wt B) | `f8bb8e5` (wt B) | — | консервативный 422 по stopped-истории (вопрос заказчика 069); gotcha-79; S8R-FIX-023 |
| S8R-AUDIT-004 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-003 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-014 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-020 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-028 | MEDIUM | ✅ попутно с 001 (`c6bf111`): legacy-путь удалён | | | | | | | |
| S8R-AUDIT-054 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-051 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-053 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-065 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-066 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-097 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-094 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-096 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-095 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-081 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-082 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-073 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-083 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-084 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-085 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-086 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-087 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-005 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-016 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-017 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-018 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-019 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-022 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-023 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-031 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-042 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-043 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-048 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-064 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-049 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-050 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-052 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-059 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-060 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-098 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-067 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-079 | LOW | ⬜ | | | | | | | |
| S8R-AUDIT-088 | LOW | ⬜ | | | | | | | |

## Пакеты
| Пакет | Карточек ✅/⏸ | E2E | /code-review | Три оси | S-сценарии | PR | Мерж |
|---|---|---|---|---|---|---|---|
| BLOCKER | 3/0 из 3 | 171/1/0 (9,0 мин) | ✅ по карточкам (001 — два прохода) | треб. 0 / рецепт 0 / качество 1 low → `9f676aa` | — | [#28](https://github.com/SergoPipo/moex-terminal/pull/28), CI ✅ (backend 2711/19xf = локально; frontend, security-scan) | ждёт команды заказчика |
| HIGH | 25/0 из 25 (+ 028 в BLOCKER) | 172/0/0 (5,8 мин), свой стенд | ✅ по карточкам (024, 025, 032 — 3 прохода) | треб. 0 / рецепт 1 low (докстринг 080 → `3417a70`) / качество 0; гонки 10× по 46 — зелёные; pytest 3035/10xf/0, покрытие 88,46 %; vitest 941 | S-1/S-2/S-7 — 28.09 в торговые часы | [#29](https://github.com/SergoPipo/moex-terminal/pull/29) (база `s8r/fix-blocker`, стек) | ждёт команды заказчика |
| MEDIUM | 0/0 из 52 | | | | — | | |
| LOW | 0/0 из 21 | | | | — | | |

## Живой счёт #3
(не начинался)

## Решения, принятые самостоятельно
1. Worktree вынесены за пределы docs-репо (`../wt-s8r-fixes` от `Develop/` попадал внутрь `Test/`) — `git worktree move` в `/Users/sergopipo/Documents/Claude_Code/`.
2. Параллельный DEV (Q8=b) работает во втором worktree на detached HEAD; его коммит переносится `cherry-pick` в ветку пакета — лишних веток не создаётся (`branch -D` заблокирована).
3. S8R-AUDIT-100 перенесена в пакет HIGH к 069: рецепт требует «в одном коммите с 069».
4. Карточки 067/079/088 отсутствуют в строке порядка LOW (`prompt_s8r_audit_fixes.md` §4), но есть в таблице — поставлены в конец пакета LOW.
5. S8R-AUDIT-080 — в HIGH сразу после 026 (таблица §2: «сразу после 026 — общая схема риск-параметров»), хотя в строке порядка `prompt_s8r_fixes.md` §3 её нет.

6. Ветка `s8r/fix-high` ведётся **стеком от `s8r/fix-blocker`** (не от `develop` после мержа): Q1=d «всё подряд» несовместимо с ожиданием мержа по команде (Q3=a). Работа по HIGH (034) идёт параллельно с 001 во втором worktree; PR `s8r/fix-high` → `develop` будет показывать и коммиты BLOCKER до его мержа.
7. Футер коммитов: оба соавтора — `Claude Fable 5.1` (DEV-субагенты, как в промпте) и `Claude Opus 5.5` (оркестратор: приёмка, правки по /code-review, интеграция).
9. 034: порог длины `SECRET_KEY` — 32 байт по рецепту (ТЗ §7.3 обещал 64 символа, в коде это не проверялось никогда); ТЗ приведено к рецепту. ⚠️ Риск для стенда заказчика: при `DEBUG=false` и слабом ключе в `.env` backend теперь не стартует — `.env` исполнитель не читает, проверка за заказчиком.
8. Вне рецепта 002 по находке /code-review: Grid Search теперь вызывает `_validate_strategy_for_backtest` (раньше обходил проверку блоков).

10. /code-review 001, находка «риск-монитор live берёт SL/TP из сохранённого `generated_code`» (`trading/engine.py:~2295`) — дефект существовал до 001; передана в карточку S8R-AUDIT-080 (единая точка `RiskParams` для всех путей), в 001 не чинится.
11. /code-review 001: эндпоинт `POST /api/v1/sandbox/execute` (исполнение произвольного кода, UI не использует) снимается с регистрации — прямое следствие решения Q4-001=(a) «исполняется только код из IR».

12. Номера Stack Gotchas для подтверждённых кандидатов аудита берутся из резерва audit §6 (61–69), а не «следующий свободный» из `stack_gotchas/README.md`: промпт и аудит ссылаются на эти номера. Неподтверждённые номера останутся пропусками — перечень в итоговом отчёте.

13. 093: `get_trading_calendar` бил в `/iss/engines/stock/markets/shares/dates.json` — там нет календаря (DEV ⏸, проверено живым GET к ISS). Источник заменён на `/iss/engines/stock.json` `dailytable` (исключения `is_work_day`) — техническая часть рецепта. **Политика выходных не меняется** (Сб/Вс — неторговые): `timetable` ISS помечает все 7 дней рабочими из-за торгов выходного дня с 2025 — **вопрос заказчику** (ФТ §1.6/1.7, карточка 072).

14. Vitest в карточке снимается только при изменении `frontend/`; иначе — один раз на уровне пакета на тихой машине. Причина: два DEV параллельно гоняют полный vitest при load 18–25 → 1–8 таймаутов (S8R-FIX-005). typecheck/lint/build — по-прежнему в каждой карточке.
15. Находка DEV-007 «входной ордер с NOT_FOUND у брокера остаётся pending бессрочно» передана в карточку 024 (поиск ордера по клиентскому ключу, подтверждённое отсутствие → failed).

16. /code-review 091: отсечка `process_split` по `opened_at` (была записана как находка S8R-FIX-008 от DEV-090) чинится в 091 — эта карточка впервые делает путь сплита рабочим, без отсечки позиции пересчитывались бы повторно.
17. /code-review 024, п. 6: сделка, не ушедшая брокеру, при удалённом/деактивированном счёте → `failed` (брокерской правды больше не будет); при временной недоступности адаптера — остаётся `pending`.

18. Передаётся в карточку 025: движок при частичном исполнении встречного ордера закрывает сделку целиком без `_flag_partial_exit` (runtime-recovery флаг ставит) — учёт частичного закрытия как такового не реализован (контрольный /code-review 024).
19. 024: «ответ потерян» ≠ «ордера нет» подтверждается только спустя `UNKNOWN_OUTCOME_CONFIRM_AGE_SEC = 120 с` от последней отправки; детерминированный gRPC-отказ (INVALID_ARGUMENT и т. п.) = «не принят» сразу (иначе «недостаточно средств» занимал бы слот); активный частично исполненный ордер входа ждёт терминала, остаток отменяется recovery через 30 мин — решения DEV, приняты оркестратором.

20. 24–25.09: DEV-024 и DEV-078 дважды обрывались на лимите сессии модели Fable (HTTP 429); возобновлены с сохранённым контекстом, потерь работы нет.

21. 074: в `docker-compose.yml` добавлен `stop_grace_period: 60s` для backend — без него Docker убивает процесс через 10 с, и исправленный graceful shutdown (45 с) не успевает; Docker локально не запускался (как и раньше).

22. 069: удаление стратегии при живых сессиях → 409; судьба ОСТАНОВЛЕННЫХ сессий при удалении стратегии (запрет или отвязка истории через SET NULL + PRAGMA foreign_keys, карточка 015) — **вопрос заказчику**, текущее поведение не меняется.

23. 25.09: исчерпан лимит модели Fable для субагентов (HTTP 429 «You've reached your Fable limit»). Дальше DEV-субагенты — на **Opus 5.5**; футер коммитов таких карточек — только `Claude Opus 5.5`. Ревьюеры по-прежнему sonnet.

24. 080: предел тейк-профита 100 % вместо 500 % из рецепта — прежний предел редактора; для short (Q5-032=b) TP выше 100 % даёт цену ≤ 0. Принято.

25. 032 (Q5=b): лог HOLD «сигнал против направления без позиции» — DEBUG, а не warning из рецепта: warning был для варианта «только long» (`short_not_supported`), при short-варианте выход без позиции — штатное состояние после каждого закрытия. Флаг CB `block_shorts` (есть только в API, в UI нет) оставлен без изменения схемы: при значении по умолчанию `True` он запретил бы все short, что противоречит Q5=b; проверка стала защитным инвариантом — **вопрос заказчику**: удалить флаг или сделать его запретом short для real-режима.

26. Пакет HIGH, отступления от процедуры: (а) три оси ревью запущены одновременно (процедура — ≤ 2), ревьюеры сами дробили работу на под-агентов — нагрузка на машину в пределах, тесты под ревью не флейкали; (б) ось качества — новый ревьюер вместо продолжения прежнего (контекст прежнего устарел после 20+ карточек); с MEDIUM — продолжать ревьюера качества HIGH через SendMessage; (в) PR #29 открыт в `s8r/fix-blocker`, а не в `develop`: ветка стоит стеком на неcмёрженном #28, PR в develop показал бы и BLOCKER — после мержа #28 базу переключить.

27. CI PR #29 красный (DEBUG=false, прогон в 00:15 МСК): S8R-FIX-016 и 2 теста гонок 101 (sandbox без `DEBUG=True`). Блокирует гейт «CI зелёный» → исправлено `03398cf` во временном worktree `wt-s8r-fixes-c` на `s8r/fix-high` (A и B заняты DEV); в `s8r/fix-medium` — cherry-pick после DEV-008. Локальный прогон в режиме CI (фиктивные ключи из `ci.yml` в окружении) отклонён правилами разрешений — режим DEBUG=false проверяет только CI; впредь сверять CI до объявления пакета закрытым.

28. 008: развилка рецепта «статус при сбое start()» — временный сбой → `suspended` (пара сохраняется, повтор при следующем старте), постоянная причина (`NotFoundError`) → `paused`; внутри restore `suspended` считается торговавшей. MEDIUM идёт двумя потоками: A (`s8r/fix-medium`) — рантайм/CB, B (detached) — auth/периметр; коммиты B переносятся cherry-pick в A.

29. Паттерн: 008, 009, 013, 037 — по три раунда /code-review, находки одних классов (сбой записи в БД и инвариант active⇔listener, лишние/потерянные уведомления и их severity, тест в обход реального пути `_unary`, таймаут поверх commit, ресурсы от клиента без предела). Системная мера: в шаблон DEV (`dev_base.md`) добавлена обязательная «Самопроверка по типовым находкам код-ревью» (6 пунктов) — действует с 010/038. Сообщено заказчику в отчёте.
30. 037: nginx опубликован на `127.0.0.1:80:80` (cloudflared на хосте ходит в localhost по гайду §5.3; LAN-доступа гайд не предусматривает) — иначе клиент LAN подделывает `CF-Connecting-IP`. В гайде `service: http://127.0.0.1:80`.

31. Инцидент DEV-009: первая версия двух новых тестов не подменяла SDK-клиента для `start()` — возможна попытка gRPC к T-Invest с фиктивным токеном `fake_key` (не токен заказчика, ордеров нет); тест упал по страховке 1,3 с, исправлено в той же карточке. Правило: тесты restore/start глушат SDK-клиента.

32. 011: рецепт «неполный портфель → без паузы» отменял ФТ v3.6 п.(2) (закрытие позиции у брокера днём не ловилось бы, а у real-счёта — никогда). Решение оркестратора: только sandbox; сигнатура сбоя — «только деньги» (gotcha-56); фон подтверждает расхождение после 3 подряд неполных проходов (~45 мин); real — без повторов. ФТ v3.6 п.(2) сохранён с задержкой для песочницы.
33. 040: дефолт `COOKIE_SECURE=auto` ослаблял прод (Secure зависел от цепочки прокси) — решение оркестратора: без настройки прод всегда Secure, `auto` — только при DEBUG=true или явно.

34. 012: модель давности бара — по интервалу обрыва стрима, а не по часам (отсечка по часам ломала торговлю последнего бара каждого дня) и не по голому номеру поколения (штатные RST_STREAM теряли сигналы). Свечи публикуются сразу, бар переопубликуется после дозагрузки.
35. Перенос коммитов между потоками: B (auth) → A cherry-pick; конфликты `config.py` (011 ↔ 040 ↔ 041) — «обе стороны», гейт A после переноса 3378/8xf/0. Дальше B синхронизируется с вершиной A перед каждой новой карточкой.

## Новые находки (заведены в backlog, не чинились)
- S8R-FIX-024 — флейки полного прогона: SIGABRT fork+gRPC в preflight-тестах, разовое зависание гейта (medium).
- S8R-FIX-023 — хвосты 015: тесты без FK (162 падения при включении), audit_log SET NULL vs append-only (low).
- S8R-FIX-022 — хвосты 012: график не исправляет не-последний бар, бары в обрыве не публикуются (low).
- S8R-FIX-021 — хвосты 041: AAD без привязки к строке, alembic-путь от cwd, живой сервер по двум адресам (low).
- S8R-FIX-020 — фоновая сверка счетов последовательно, держит watchdog (medium, не регресс).
- S8R-FIX-019 — хвосты 009: `start()` в сети до yield, фоновая сверка на wait_for поверх записей (low).
- S8R-FIX-018 — хвосты 008: shutdown-доучёт частичного выхода без паузы, осиротевшая paused держит пару, три копии кода уведомлений (low).
- S8R-FIX-017 — хвосты 013: открытые WS не рвутся при logout, «Аккаунт деактивирован» не виден на экране входа, дубли кода аутентификации (low).
- S8R-FIX-016 — ✅ `03398cf` — `test_same_commission_and_net_pnl` падает после 23:50 МСК (реальное время vs проверка торговых часов закрытия; low; ревью HIGH).
- S8R-FIX-015 — направление сделки: inline-копии `in ("buy","long")` в 8 местах; paper-выручка по `volume_lots`; paper-просадка без unrealized (low; DEV-032).
- S8R-FIX-014 — нет эндпоинта корректного лота для формы запуска (low).
- S8R-FIX-013 — CB: пик только на входах; `DailyStat.peak_equity` мёртвая; дневной лимит без проверки свежести цены (low).
- S8R-FIX-012 — recovery частичного выхода: P&L на всю позицию при активном partially_filled; события после снятия слушателя теряются (low).
- S8R-FIX-011 — фронт не повторяет REST-подписку графика после reconnect WS; ключ стрима без токена (low).
- S8R-FIX-010 — лок `sandbox_recovery_user` вне «Порядка захвата»; `find_instrument` в `market_data` мимо дедлайна адаптера (low).
- S8R-FIX-009 — `shutdown()` job-менеджера без таймаута; grid в ожидании слотов без статуса (low).
- S8R-FIX-008 — корп. действия: «дата отсечки» = дата реестра в уведомлении; сплит без отсечки; расписание джобы ≠ ФТ (low).
- S8R-FIX-007 — UI не подписывает `LiveTrade.status='pending'` (low).
- S8R-FIX-006 — `nkd_entry/nkd_exit`: писателя нет, tax и корп. действия трактуют по-разному (low).
- S8R-FIX-005 — vitest `StrategyEditPageDelete` таймаутит в полном прогоне под нагрузкой машины (low).
- S8R-FIX-004 — Grid Search: имена параметров Bollinger `bollinger_*` vs `bb_*` (low; /code-review 001, было до фикса).
- S8R-FIX-003 — ТЗ §8.4: JSON-логи с ротацией не существуют; `dev.log` без ротации и с правами 644 (low).
- S8R-FIX-002 — `test_users_cli.py` вакуумен: CLI без ключей падает на импорте настроек (low; найдено DEV-034).
- S8R-FIX-001 — `SOURCE=volume`: live-интерпретатор считает по close, backtrader по volume (low; найдено DEV-002).

## Следующий шаг
Цикл идёт, пакет **MEDIUM**. Ветка `s8r/fix-medium` (A = `wt-s8r-fixes`, вершина `450e74c`, 3512/8xf/0), B = `wt-s8r-fixes-b` (detached, синхронизируется с вершиной A перед новой карточкой; коммиты B → cherry-pick в A).
Закрыто MEDIUM (18 из 51): 008, 009, 010, 011, 012, 013, 021, 027, 029, 037, 038, 039, 040, 041, 056, 057, 058, 076 (+ 013/021/037…057 перенесены в A). В работе: 070 (A), 015 (B, второй раунд ревью: IDOR CB-конфига, фильтр бэктестов).
Очередь A: 071 (миграция данных sizing) → 072 (календарь в часах торгов) → группа «Брокер/бэктест»: 044 → 045 → 046 → 047 → 062 → 063 → 006 → 077. Очередь B: 004 (миграция — только после переноса 071 в B, иначе две головы alembic) → 003 → 014 → 020 → 054 → 051 → 053 → 065 → 066 → 097. Далее: 094 → 096 → 095 (K2), 081 → 082, 073 → 083 → 084 → 085, 086 → 087. Конфиги готовы: cfg_071, cfg_072.
HIGH: PR #29 (CI зелёный), S-1/S-2/S-7 — пн 28.09 с 10:00 МСК. BLOCKER: PR #28. Мерж — по команде заказчика.
Инструменты: scratchpad сессии + копия в `s8r-evidence/fixes/tools/` (dev_base.md с самопроверкой).
