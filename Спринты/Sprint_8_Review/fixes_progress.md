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
| S8R-AUDIT-030 | HIGH | 🔄 DEV (wt A, a3bb857) | | | | | | | |
| S8R-AUDIT-074 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-075 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-061 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-025 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-026 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-080 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-032 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-068 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-069 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-100 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-055 | HIGH | ✅ | `expected 'http://localhost:8000/api/v1' to be '/api/v1'`; `'ws://localhost:8000' not to contain 'localhost:8000'`; preflight `'CORS_ORIGINS' in ''` | 8 vitest + 14 preflight | «абсолютный дефолт» → red | 2800/16xf/0; ruff 0; mypy ok; bandit 0; tsc 0; lint 0; build ok (0× localhost:8000); vitest 934 | `c93e1ad` | — | dev-proxy Vite добавлен (его не было) | | | | | | | |
| S8R-AUDIT-078 | HIGH | ✅ | `воркеры живы после cancel: pids=[…]`; `4 > лимита 2`; `job осталась в реестре _tasks` | 6 passed ≈ 3 с | «terminate только при отмене» → red | 2806/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `a3bb857` | — | /code-review: 2 находки исправлены; gotcha-73 | | | | | | | |
| S8R-AUDIT-093 | HIGH | ✅ | `AttributeError: … no attribute 'set_calendar_service'`; `assert None is True` (7 failed) | 7 passed | исключение ISS не применяется → `is_trading_day(2024-04-27)` False; без сброса календаря в conftest → 1 failed | 2718/21xf/0 (wt B); ruff 0; mypy ok; bandit 0 | `bca0cec` | — | ⏸→решение оркестратора: источник `engines/stock.json` dailytable; Сб/Вс неторговые (вопрос заказчику); /code-review: изоляция тестов исправлена; gotcha-70 |
| S8R-AUDIT-089 | HIGH | ✅ | `Decimal('100.00') == Decimal('1000.00')`; купон `137.50 == 875.00` | 4 passed | «без множителя» → red | 2722/21xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `6012089` | — | /code-review чисто |
| S8R-AUDIT-090 | HIGH | ✅ | `assert True is False` (processed); `Decimal('1000.00') == Decimal('0.00')` | 5 passed | «без фильтра даты», «rollback → pass» → red | 2774/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `04fb5cb` | — | /code-review: 2 находки исправлены |
| S8R-AUDIT-091 | HIGH | ✅ | `ImportError: cannot import name 'corporate_action_warning'`; `(1000, Decimal('1.5')) == (10, Decimal('150'))`; `processed True is False` | 9 passed + 68 смежных | «ratio перепутан», «без фильтра opened_at» → red | 2784/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `d138ef1` | — | /code-review: 3 находки исправлены | | | | | | | |
| S8R-AUDIT-092 | HIGH | ✅ | `restore не использует os.replace`; `DID NOT RAISE BackupError` ×2; `--server-port` не распознан; нет `BACKUP_DIR` | tests/test_backup 42 passed | «без файлового лока», «WAL до подмены» → red | 2794/16xf/0 (wt B); ruff 0; mypy ok; bandit 0; фронт не менялся | `464b8cd` | — | /code-review: 4 находки исправлены; gotcha-72, ретро gotcha-19 | | | | | | | |
| S8R-AUDIT-101 | HIGH | 🔄 DEV (wt B, cc7345f; миграция — перестановка down_revision при интеграции) | | | | | | | |
| S8R-AUDIT-099 | HIGH | ⬜ | | | | | | | |
| S8R-AUDIT-008 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-009 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-010 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-011 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-012 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-029 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-076 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-027 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-070 | MEDIUM | ⬜ | | | | | | | |
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
| S8R-AUDIT-013 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-037 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-038 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-039 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-040 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-041 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-021 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-058 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-057 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-056 | MEDIUM | ⬜ | | | | | | | |
| S8R-AUDIT-015 | MEDIUM | ⬜ | | | | | | | |
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
| HIGH | 5/0 из 25 (034, 035, 036, 093 + 100 с 069 впереди) | | | | | ветка `s8r/fix-high` (стек от fix-blocker), `bca0cec` | |
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

## Новые находки (заведены в backlog, не чинились)
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
Цикл идёт (возобновлён после паузы 24.09). Ветка `s8r/fix-high` запушена до `a3bb857` (гейт объединения: 2857 passed / 16 xfailed / 0 failed, head `d4f1a9c2b7e0`). HIGH закрыто 14 из 25: 034, 035, 036, 093, 007, 089, 024, 090, 091, 092, 055, 078 (+ из BLOCKER попутно 028).
В работе: 030 (DEV, wt A, ветка) ∥ 101 (DEV, wt B detached cc7345f — миграция от `c5e8b2a7f913`, при переносе переставить `down_revision` на `d4f1a9c2b7e0`).
Далее трек A: 074 → 075 → 061 → 025 (миграция) → 026 → 080 (+ SL/TP из generated_code) → 032 (Q5=b) → 068 (миграция) → 069+100; трек B: 099 (после 101). Затем процедура пакета HIGH (E2E, три оси, S-1/S-2/S-7 на счёте #3, vitest в тишине, PR). BLOCKER: PR #28 ждёт команды заказчика на мерж.
Шаблоны и скрипты — scratchpad текущей сессии и копия в `s8r-evidence/fixes/tools/` (при новой сессии — копия).
