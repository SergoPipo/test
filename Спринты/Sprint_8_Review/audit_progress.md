# Прогресс аудита — 2026-09-17

## Среда
worktree: /Users/sergopipo/Documents/Claude_Code/wt-s8r-audit (база eb769cc = origin/develop) | ветка кода: s8r/audit (создана: да, запушена: да — b2a95a8, 3 коммита, 14 xfail-тестов по карточкам 001/002/004/005/007/013/015/026/033/034/054 — 4 коммита до 555fde8; CI на ветке зелёный: 3 run success, backend 2625 passed / 15 xfailed; PR ещё не открыт)
стенд: backend :8000 запущен ДА (PID в s8r-evidence/audit/backend.pid, uvicorn из worktree) | vite :5173 ДА (vite.pid) | БД стенда: wt-s8r-audit/backend/data/e2e_local.db | симлинк .env: снят (не ставился)
основной чекаут Develop/: переключён на develop да (eb769cc); правка .env.example заказчика сохранена в рабочем дереве (stash pop дал конфликт → взята версия заказчика; stash@{0} оставлен как страховка). Стенд из Develop/ не запускался, alembic на рабочей БД не выполнялся.
счёт #3: исходное состояние снято нет → s8r-evidence/audit/S-account-before.md

## Аспекты
| Аспект | Статус | Ревьюер отработал | Верифицировано | Файл сырых находок |
|---|---|---|---|---|
| T | ✅ | — | — | s8r-evidence/audit/T-gates.md (все гейты = baseline; E2E 171/1/0) |
| A | ✅ | да (3-й запуск, 418 строк, A-01…54: 1 blocker, 1 high, 9 medium, 18 low, 20 info) | ключевые (A-12, 03, 04, 07, 15, 21, 22, 26, 31, 33, 45, 47) — да, карточки 033, 035, 037–040, 043, 013 | s8r-evidence/audit/A.findings.md |
| B | 🔄 | да: B1 ✅ (443 строки, B1-01…16), B2 ✅ (292 строки, B2-01…12; список НЕ ПРОВЕРЕНО — хвосты в G/E) | B1-01,02; B2-01,02,03 — да; остальные в работе | s8r-evidence/audit/B1.findings.md, B2.findings.md |
| C | ✅ | да (3-й запуск, 243 строки, C-01…21: 2 high, 2 medium, 10 low, 7 info; история git обоих репо — реальных секретов нет, перевыпуск не требуется) | C-14, 15, 20, 03 — да (карточки 034, 036, 041, 042); C-12 = 021; C-16 → E | s8r-evidence/audit/C.findings.md |
| D | ✅ | D1 ✅ (D1-01…07 + репро); D2 ✅ (D2-01…14, разделы 1–7 + ПРОВЕРЕНО: загрузок нет, SQL ок, DOM-XSS нет, вебхук fail-closed, callback-ownership ок) | D1-01…04 — прогоном; D2-05/08/09/12/13 — по коду оркестратором; карточки 001/002/006/018/019/028/053/065/066/067; D2-14→046; D2-10/11 info | s8r-evidence/audit/D1.findings.md, D2.findings.md |
| E | ✅ | да (два ревьюера, 400+ строк, E-01…18 + ПРОВЕРЕНО по 6 вопросам) | E-02/10/11 — по коду оркестратором; остальные — по пробам ревьюера; карточки 055–060, E-01→040, E-05/07→037, E-16 info | s8r-evidence/audit/E.findings.md |
| F | 🔄 | ревьюер упал дважды (файл 5 строк); самопроверка оркестратора 20:05: generic-handler → «Внутренняя ошибка сервера» без stack/SQL ✅, OperationalError → 500 «Ошибка базы данных» ✅; logout сбрасывает candles-cache, background-backtests, favorites, WS ✅ (authStore.ts:95-118); drawings persist по userId ✅; `recentInstruments` (localStorage) не чистится при logout — info; WS-broadcast/кэши/AI-данные — B2-05/006, 003, 014; уведомления per-user — не проверено (K1) | частично | s8r-evidence/audit/F.findings.md |
| G | 🔄 | G1 ✅ (G1-01…18); G2 частично (G2-01…11, runtime.py до ~1100; risk_monitor/paper_engine/daily_stats не читаны); G3 ✅ (393 строки, G3-01…67, ПРОВЕРЕНО по 10 вопросам); G4 ✅ (517 строк, G4-01…18, sonnet 23.09); G2 ✅ (G2-01…17 + таблица переходов + ПРОВЕРЕНО, sonnet 23.09) | G1 — да (024–032, 007); G2 — да (007–012, 019); G3 — да (030, 044–048, 061–064); G4 — да по коду (G4-01/02/03/06/16 → 068–073; G4-11 = 067; G4-05/12/14/17/18 info/ок) | s8r-evidence/audit/G1..G4.findings.md |
| H | 🔄 | H2 ✅ (sonnet 23.09: H2-01…07 + ПРОВЕРЕНО по 9 вопросам: look-ahead/warm-up/комиссия/паритет — ок с доказательствами по исходнику backtrader; гипотеза gotcha-38 об отравлении сессии после wait_for опровергнута репро); H1 — ревьюер не запускался; самопроверка 18.09: агрегация `_candle_period_start` считает бакеты в зоне входящей свечи (T-Invest — UTC): D = 00:00 UTC (сессия MOEX целиком внутри ✅), **4h = 00/04/08/12/16/20 UTC** (= 03/07/11/15/19/23 MSK) — выравнивание против исторических 4h-свечей T-Invest/ISS не подтверждено (⏸ требует живой сверки, S-7/H1); объём — по последнему снапшоту минуты ✅ (BE-MKT-05); backtest look-ahead/warm-up/grid/jobs — не проверено (H2) | частично | — |
| I | 🔄 | I1 ✅ (sonnet 23.09: I1-01…14 + ПРОВЕРЕНО по 6 вопросам; версионирование — ок, сессия читает код версии); I2 — ревьюер не запускался; самопроверка 18.09: системный промпт фиксирован (prompts.py), пользовательские поля санитизируются и оборачиваются (`slash_context._sanitize_str`, `wrap_user_message` — маркеры `[/...]` нейтрализуются), AI предлагает блоки в ```json_blocks``` — применение через UI по действию пользователя (chat_router.py:82-91, 252-265); лимиты/общий потолок — 014; SSE+CSRF ✅ (A-43); версионирование/статусы стратегий (I1) — не проверено | частично | — |
| J | ✅ | alembic — оркестратор 18.09 (heads=1; downgrade base падает на idx_ai_user; alembic check красный) → J-alembic.log; J2 ✅ (sonnet 23.09, 348 строк: 5 обязательных сценариев + 2 доп. прогнаны тестами с рандеву до лока, 6–9 повторов каждый; идемпотентны: старт сессии, стоп/возобновить, close_position, close_all_positions, backtest cap, /telegram/test; гонки J2-01/02/03; временный каталог tests/_audit_j2_tmp удалён, worktree чист); J1 (database/scheduler/shutdown) — ревьюер не запускался: database/scheduler закрыты K2 (092–094, 097), shutdown — самопроверка M (074) | J2-01/02/03 — по коду оркестратором (карточки 099, 100, 101); alembic — прогоном | s8r-evidence/audit/J-alembic.log, J2.findings.md |
| K | ✅ | K1 ✅ (sonnet 23.09: K1-01…20 + ПРОВЕРЕНО по 9 вопросам); K2 ✅ (sonnet 23.09, 284 строки, K2-01…32: 11 high, 8 medium, 12 low, 1 ссылка; все 19 файлов периметра прочитаны целиком) | K1-02…11/17/19/20 — по коду (карточки 083–085, 073, 019); K2-21/22/23/24/14/04/05/06/12/16/19/31/32 — по коду оркестратором (карточки 089–098; K2-30 = 015; K2-26 → 098; severity 094/095 ниже оценки ревьюера — см. §5) | s8r-evidence/audit/K1.findings.md, K2.findings.md |
| L | 🔄 | L1–L7 не запускались; самопроверка 20:05: enum-контракт `SessionStartRequest` (timeframe/mode/sizing) совпадает с `api/types.ts`; `direction` во фронте — объединение `buy/sell/long/short` (бэк отдаёт строку без enum) ✅; сторы при logout — см. F; из ревью A/B: A-45/47 (039), A-51 (043), B2-05 (020) | частично | s8r-evidence/audit/L*.findings.md. Ручная проверка трёх сценариев `S9-CHART-DRAWING-EDIT-OBSERVATIONS` в этой сессии НЕВЫПОЛНИМА: доступен только синтетический ввод Playwright, из-за которого наблюдения и признаны неустойчивыми 24.08; нужна настоящая мышь → владелец: заказчик |
| M | 🔄 | лёгкая самопроверка оркестратора 19:58: ротации логов в приложении нет (start.sh `tee -a logs/dev.log` — в 051), VACUUM нет, джобов очистки revoked_tokens/notifications нет (043), shutdown: suspended + ожидание pending 30 с (по докстрингу); /health всегда ok/200 → карточка 054; сценарии отказа/kill -9 — покрыты G2/007–012; ревьюер M не запускался | частично | — |
| N | 🔄 | synthetic-замер повторён оркестратором 20:45: signal.process 1.45 мс, order.place 1.45 мс, telegram.handle 2.67 мс, overhead 2.1 мкс (baseline W5: 1.39/1.39/2.53 мс/14 мкс) → s8r-evidence/audit/N-benchmark.log; самопроверка 19:58: индексы — `live_trades` без композитных `(session_id, status)`/`(session_id, closed_at)` (три одиночных), `trading_sessions` без `user_id` (владелец через JOIN — B2-01), `backtest_jobs (user_id,status)` ✅, `notifications (user_id,is_read)` ✅; `get_sessions` — один запрос; event_bus — очередь 256 на подписчика; N+1 `GetInstrumentBy` в портфеле — в 048; бандл: StrategyEditPage 846 kB (Blockly) — info. Ревьюер N не запускался | частично | s8r-evidence/audit/N-benchmark.log |
| O | 🔄 | статика снята оркестратором 19:50 (O-static.md): xfail 1 (parity), skipif 2, E2E skip 1 (chart-drawings-fix, CI); подавления noqa 60 / type-ignore 38 / nosec 6 / no-cover 30 / eslint-disable 18 / ts-expect-error 2 — bare `# noqa` нет; safety_policy 1 CVE с обоснованием и сроком; TODO — 2; сетевых тестов нет (autouse-фикстура); USD_RUB_MOCK_RATE удалён. O1 мутации оркестратором 19:55 (O1-mutations.md): M1 комиссия, M2 paper-учёт, M3 пароль, M4 CB-просадка, M5 CB-лимит сделок — пойманы; **M6 getattr в денилисте — не поймана** → карточка 053. Не сделано: выборка 20 тестов по качеству утверждений, CI push вручную | частично | s8r-evidence/audit/O-static.md, O1-mutations.md |
| P | ✅ (оркестратор, 19:50) | сам: матрица config.py ↔ .env.example ↔ compose ↔ guide ↔ ТЗ (P-config-matrix.md), compose/Dockerfile*/.dockerignore/start.sh/preflight прочитаны; не покрыто: launchd plist, Cloudflare Access (только по гайду), nginx — в E | карточка 051 (+037/040/034/050) | s8r-evidence/audit/P-config-matrix.md |
| Q | ✅ | Q1 ✅ (sonnet 23.09: 62 требования ФТ трассированы, ТЗ §3/§4/§7/§8 ↔ код, T-Invest enum ↔ mapper — чисто; Q1-01…33) + Q2 статика оркестратора 18.09 (Q2-static.md) | Q1-16/29 — по коду (grep писателей); остальные — по таблице ревьюера; карточки 086–088, 052; Q1-15→006, Q1-26→041 | s8r-evidence/audit/Q1.findings.md, Q2-static.md |
| R | ✅ (оркестратор, 19:50) | сам: ветки/merged/объекты/gitignore/workflows/dependabot обоих репо, лицензии (venv + pnpm), пины зависимостей; не делалось: даты релизов через PyPI/npm (сеть) | карточки 049, 050 | s8r-evidence/audit/R-code-repo.md, R-docs-repo.md, R-licenses-deps.md |
| S | ⬜ | — | — | s8r-evidence/audit/S-account-*.md |

## Находки (подтверждённые) — по одной строке
S8R-AUDIT-001 | blocker | D | побег из песочницы через datetime.sys (executor + backtest engine); воспроизведено оркестратором | рецепт: написан | xfail-тест: tests/unit/test_sandbox/test_audit_s8r_escape.py (3 xfailed)
S8R-AUDIT-002 | blocker | D | инъекция кода через поле SOURCE в кодогене IR; воспроизведено оркестратором | рецепт: написан | xfail-тест: tests/unit/test_strategy/test_audit_s8r_source_injection.py (2 xfailed)
S8R-AUDIT-003 | medium | B | служебные T-Invest-вызовы чужим токеном (lot_size/ISIN/FIGI без счёта); подтверждено чтением | рецепт: написан | xfail-тест: нет
S8R-AUDIT-004 | medium | J | alembic check красный: user_favorites не в metadata env.py; 4 колонки ai_provider_configs без модели; воспроизведено на чистой БД | рецепт: написан | xfail-тест: tests/unit/test_audit_s8r_alembic.py::test_alembic_check_is_clean_on_fresh_db
S8R-AUDIT-005 | low | J | downgrade base падает на idx_ai_user (санитайзер vs a1b2c3d4e5f6); воспроизведено | рецепт: написан | xfail-тест: tests/unit/test_audit_s8r_alembic.py::test_full_round_trip_upgrade_downgrade_upgrade
S8R-AUDIT-006 | medium | D | нет лимита времени/памяти исполнения стратегии в бэктесте/grid (D1-05/06) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-007 | high | G | orphan-recovery: сбой опроса/отмены у брокера → сделка failed (G2-01/02) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-008 | medium | G | restore_all: suspended→active до старта listener'а (G2-04) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-009 | medium | G | сверка при старте без таймаута блокирует запуск HTTP (G2-03) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-010 | medium | G | suspended проигрывает пару paused-дубликату и застревает (G2-10) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-011 | medium | G | неполный портфель после ретраев = «позиции нет» → ложная пауза (G2-06) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-012 | medium | G/H | возобновление стрима: устаревший бар как сигнал, агрегатор с середины периода (G2-07/08) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-013 | medium | A/B | WS-auth без проверки отзыва jti/is_active (B2-04, B1-07) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-014 | medium | I/B | AI fallback на серверный ключ без лимита/учёта, нет общего потолка (B1-08, B1-09) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-015 | medium | J | PRAGMA foreign_keys не включён — FK/ondelete не действуют | рецепт: написан | xfail-тест: tests/unit/test_audit_s8r_foreign_keys.py
S8R-AUDIT-016 | low | B | ownership после выборки + оракул 403/404 (B1-01/03/11/12) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-017 | low | B | мутирующие эндпоинты принимают чужой id без проверки (B2-03, B1-04) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-018 | low | D | SSRF-барьер: TOCTOU, 100.64/10, сырой str(e) (D2-01..04) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-019 | low | G/D/B | мёртвый/дублирующий код: restore_sessions, code_generator, _blocks_to_sandbox, BacktestService (G2-11, D1-07, B1-05, B1-02) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-020 | medium | F/L | session.added никто не публикует — новая сессия не стримится в открытый WS (B2-05) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-021 | medium | D/A | код привязки Telegram 6 цифр без лимита попыток (B2-11; ревьюер — low) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-022 | low | K | налоговый отчёт: повторная генерация перезаписывает файл (B1-13) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-023 | low | K/B | POST /corporate-actions/detect без require_admin и лимитов (B1-16) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-024 | high | G | путь ордера: сбой/нет ответа = «не ушёл» на входе, отмене, выходе (G1-05/07/15) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-025 | high | G | частичное исполнение терминально; три количества при закрытии; деривация lot_size после fill (G1-06/02/13) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-026 | high | G | сайзинг max(1,…) заказывает лот сверх бюджета (G1-10) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-027 | medium | G/H | percent-сайзинг от initial_capital vs бэктест от кэша (G1-11) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-028 | medium | G/D | legacy-сигнал по подстроке "buy"/"sell" (G1-01) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-029 | medium | G/J | стоп сессии: закрытие позиций вне session_lifecycle (G1-03) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-030 | medium | G/J | унарные gRPC под close_trade без дедлайна (G1-14) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-031 | low | G | мелкие несоответствия учёта (G1-04/09/16/17) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-032 | high | G | paper-short: учёт денег зеркален; ФТ §1.3 обещает блокировку short (G1-12) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-033 | blocker | A | POST /auth/setup открыт всегда — аноним создаёт учётку (A-12, A-27, B1-15); ФТ §2.1 — единственный пользователь | рецепт: написан | xfail-тест: нет
S8R-AUDIT-034 | high | C/A | SECRET_KEY/ENCRYPTION_KEY: только префикс dev-, плейсхолдеры проходят, валидация ленивая (C-14, C-15, A-33) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-035 | high | A | смена пароля не отзывает другие сессии; reuse refresh не гасит семейство (A-03, A-04) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-036 | high | C | traceback с локалами печатает токен брокера в лог (C-20) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-037 | medium | A/E | lockout ломает refresh; auth-лимитер по client.host за прокси (A-07, A-26, A-28) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-038 | medium | A/E | CSRF fail-open; login/setup без Origin-check (A-21, A-22) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-039 | medium | A/L | logout при истёкшем access не стирает refresh; 429 на refresh = logout (A-45, A-47) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-040 | medium | A/P | Secure-cookie от DEBUG, :80 без TLS (A-15) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-041 | medium | C/Q | нет ротации ENCRYPTION_KEY, ТЗ §8.8 обещает (C-03) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-042 | low | C | маски > 4 символов, httpx-URL с bot-token, plaintext в реестрах, AAD, права бэкапов (C-01/05/06/10/19/21) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-043 | low | A | политика паролей, enumeration 423/время, revoked_tokens без очистки, дисклеймер (A-01/06/08/39/51/52) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-044 | medium | G/M | ретраи чтений только 70001; сетевые ошибки как «ключ отклонён»/«не найден»; сырой gRPC наружу (G3-10/14/19/29/43) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-045 | medium | G/H | два резолвера FIGI, адаптер только TQBR, классовый кэш без TTL (G3-01/13/30) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-046 | medium | G/L | available = total в балансе (G3-12/28) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-047 | medium | G | адаптер/маппер: направление по умолчанию SELL, LIMIT без цены, unspecified→placed, lot_size=1 в поиске (G3-20/21/31/36/37) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-048 | low | G/N | брокерский слой: мёртвая персистентность лимитера, общий bucket, ключ=токен, N+1 GetInstrumentBy и др. (G3-04…08/11/17/23–25/32/33/39/40/42/45/46) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-049 | low | R | гигиена: 25+26 слитых веток, workflows без permissions, нет Dependabot, prompt-файлы в main, чужой worktree в репо документации | рецепт: команды заказчику | xfail-тест: н/п
S8R-AUDIT-050 | low | R/P | зависимости: git-тег SDK, нет lock backend, GPL-инвентаризация (backtrader GPLv3+), base-образы без digest | рецепт: написан | xfail-тест: н/п
S8R-AUDIT-051 | medium | P/Q | deployment_guide v1.0 расходится с config.py (TINVEST_TOKEN/TELEGRAM_CHAT_ID не существуют, 14 настроек вне шаблона, ревизии/версии устарели), compose без proxy/graceful/log-limits, start.sh без preflight/ротации | рецепт: написан | xfail-тест: нет
S8R-AUDIT-086 | medium | Q/A/K | audit_log (ФТ §12.7 Must) — 1 писатель; pending_events (ТЗ §2.4) — 0 писателей (Q1-16/29) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-087 | medium | Q | ФТ-требования не реализованы/расходятся: делистинг, OHLCV-валидация, автопауза после N ошибок, частичное исполнение, §12.8, §4.2 (Q1-08/09/10/11/13/17) | рецепт: решения заказчика | xfail-тест: нет
S8R-AUDIT-088 | low | Q | ТЗ §4 контракты устарели, §3 схема vs модели, перекрёстные ссылки версий (Q1-31/32/33, задачи 2/4) | рецепт: написан | xfail-тест: н/п
S8R-AUDIT-089 | high | K/G | корп. действия: дивиденды/купоны по лотам без lot_size (K2-21) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-090 | high | K/J | корп. действия: начисление до ex_date; process_pending без rollback (K2-23/24) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-091 | high | K/Q/H | сплиты/купоны никогда не детектируются; сплит не трогает кэш свечей/бэктест (K2-22/25) | рецепт: написан (back-adjust — решение заказчика) | xfail-тест: нет
S8R-AUDIT-092 | high | K/M | backup/restore: не атомарен, лок только in-process, без integrity_check после create, без Connection.backup (K2-01/03/04/05/06/07/08/09) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-093 | high | K/G | MOEXCalendarService без iss_client везде — синхронизация no-op; fallback-праздники без года (K2-14/15) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-094 | medium | K/M | misfire_grace_time 1 с у 4 джоб; MemoryJobStore; T+1-unlock мёртв (K2-12/13/16; ревьюер — high) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-095 | medium | K/Q | тип инструмента эвристикой по тикеру; раздельная база NEEDS-REVIEW (K2-19; ревьюер — high) | рецепт: написан + решение заказчика | xfail-тест: нет
S8R-AUDIT-096 | medium | K | TaxLot без report_id растёт при регенерации, коммит при ошибке; файл общий на год; FIFO только в названии (K2-17/18/20) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-097 | medium | J/K/M | дефолтный AsyncAdaptedQueuePool 5+10 для SQLite; persist_with_retry только в backtest (K2-31/32) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-098 | low | K/B | мелочи K2: нет revoke_admin, CLI без обработки ошибок БД, нет лимита избранного, initial_capital_total, tickers без валидации (K2-02/07/10/11/26/27/28/29) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-099 | high | J/G/B | delete_account без лока: параллельный start_session оставляет active-сессию на удалённый счёт (J2-01, 6/6 репро) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-100 | medium | J/D | двойное удаление стратегии → StaleDataError → 500 вместо 404 (J2-02, 6/6) | рецепт: написан (вместе с 069) | xfail-тест: нет
S8R-AUDIT-101 | high | J/G/B | create_account: SELECT-then-INSERT без лока и UNIQUE → дубль BrokerAccount на один счёт брокера (J2-03, 6/6) | рецепт: написан (миграция UNIQUE) | xfail-тест: нет
S8R-AUDIT-083 | medium | K/M | доставка без ретраев/таймаутов, каналы не изолированы, EventBus теряет события при переполнении (K1-02…05) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-084 | medium | K/E/I | /telegram/test — relay произвольного bot_token/chat_id, тесты игнорируют DEV_MODE, лимит general (K1-09/10/11) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-085 | medium | K/L | мастер: чужой бот = «Telegram готов»; «Очистить все» без подтверждения; оптимистичный патч без отката (K1-17/19/20/18) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-073 повышена до medium (K1-06/07/08: CB публикует имя вне EVENT_MAP, доставка держится на дубле в runtime); K1-01 (мёртвый dispatchers.py) → 019; K1-16 = 021; K1-12/13/14/15 info/ок
S8R-AUDIT-080 | high | I/G | риск-параметры без валидации: отрицательный SL инвертирует защиту, строка молча отключает SL/TP (I1-03/04/05) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-081 | medium | I | статус стратегии не связан с сессиями, переходы только во фронте, enum не в OpenAPI (I1-02/08/09/10) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-082 | medium | I/L | редактор: ошибки сохранения не показываются/хардкод; Режим B глотает неизвестную секцию/индикатор; мёртвая кнопка (I1-06/07/11–14) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-077 | medium | H | Sharpe аннуализирован как Days/252 для любого таймфрейма (H2-01) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-078 | high | H/M | отмена grid не останавливает Pool (репро ревьюера), нет общего лимита процессов, утечка реестра (H2-02/03/04) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-079 | low | H | прореживание equity, Decimal до прореживания, entry vs exit на одном баре (H2-05/06/07) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-074 | high | G/M | stop/shutdown: cancel посреди place_order без shield; ожидание pending после отмены recovery/listener'ов (G2-12/13) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-075 | high | G | SL/TP: OrderInFlightError без уведомления; _EXIT_IN_FLIGHT (15 мин) не синхронизирован с exit_broker_order_id (G2-14/15/16) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-076 | medium | G/J | paper-портфель: open без лока, close по ключу сделки — lost update (G2-17) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-068 | high | G | CB по просадке не работает для sandbox/real (только PaperPortfolio); статус 0 % (G4-01/10) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-069 | high | G/B/J | удаление стратегии с живой сессией не запрещено — сессия невидима и торгует (G4-16, B2-01) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-070 | medium | G | дневной лимит %: убыток по всем сессиям, порог от initial_capital одной (G4-02) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-071 | medium | G | position_sizing_mode=NULL обходит lot_size в CB и даёт 1 лот (G4-03) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-072 | medium | G/M | часы торгов без календаря MOEX, три копии логики, календарь не подключён (G4-06/15) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-073 | low | G | CB: trigger/limit=0, двойной publish, мёртвая ветка, лок вне locks.py (G4-04/07/09/13) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-065 | medium | D | ticker без формата → CSV/XLSX formula injection (openpyxl data_type='f'), подмена Content-Disposition (D2-05/06/07/08/12) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-066 | medium | D/K | Telegram HTML без html.escape для username/ticker/strategy_name (D2-09) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-067 | low | D/G | конфиг CB без диапазонов значений (D2-13) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-061 | high | G/M | мультиплексор: мёртвый итератор съедает SUBSCRIBE после реконнекта, ack игнорируется, UNAUTHENTICATED → бесконечный reconnect, подписки не снимаются (G3-47/48/49/53; офлайн-репро ревьюера на grpcio) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-062 | medium | G/A | смена токена брокера невозможна (повторное добавление молча оставляет старый ключ); test-connection создаёт sandbox-счёт (G3-55/57) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-063 | medium | H/G | ISS-время помечается UTC без сдвига (MSK) — свечи ISS в кэше +3 ч; ISS — источник lot_size для сайзинга (G3-62/63); ⏸ живой GET к ISS не выполнялся | рецепт: написан | xfail-тест: нет
S8R-AUDIT-064 | low | G/H | стрим/ISS/сервис счетов — мелочи (G3-52/56/58/64–67) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-055 | high | E/P/L | прод-бандл SPA зашивает localhost:8000 (нет VITE_* при сборке образа) — за Tunnel API недостижим (E-11) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-056 | medium | E/P | nginx regex-location статики перехватывает JS Dash под /api/… → метрики за nginx не грузятся (E-10) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-057 | medium | E | security-заголовки только на JSON backend; статика/500/preflight без; файлы без no-store (E-04/09/18) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-058 | medium | E/J | WS/SSE без лимитов соединений/подписок, лимитер WS не видит, рост словаря, гонка MAX_CONCURRENT_STREAMS (E-06/08/13/14) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-059 | low | E | Swagger безусловно, /health публично раскрывает состояние, CORS */* и CORS_ORIGINS=* (E-02/03/17, C-16) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-060 | low | E/L | 4401 до accept → 403/1006 и бесконечный reconnect; nginx index.html без Cache-Control, gzip, keepalive (E-12/15) | рецепт: написан | xfail-тест: нет
S8R-AUDIT-054 | medium | M/P | /health всегда ok/200 при недоступной БД (liveness как readiness); tinvest_connected по флагу connected (gotcha-34); version захардкожен | рецепт: написан | xfail-тест: нет
S8R-AUDIT-053 | medium | O/D | мутация «убрать getattr из денилиста песочницы» не поймана тестами (O1 M6); M1–M5 пойманы | рецепт: написан | xfail-тест: нет
S8R-AUDIT-052 | low | Q | project_state/README S8R устарели («старт S9», плейсхолдеры, tsc --noEmit), чеклист 267 vs 268 | рецепт: написан | xfail-тест: н/п
S8R-AUDIT-030 повышена до high по G3-09 (ни один унарный gRPC без дедлайна; SDK таймаут не принимает). G3-22 (клиентский order_id) — в 024; G3-34/35/38/26/27 — ок (info).
S8R-AUDIT-033 / -034: xfail-тесты — tests/unit/test_audit_s8r_auth_setup.py (b2a95a8, запушен)
S8R-AUDIT-026 / -054: xfail-тесты — tests/unit/test_audit_s8r_health_and_sizing.py (3 xfailed; 555fde8)
S8R-AUDIT-055: vitest it.fails — frontend/src/api/__tests__/audit_s8r_baseurl.test.ts (2 expected fail; eslint 0; 3b4c4a6)
S8R-AUDIT-065 / -067: xfail-тесты — tests/unit/test_audit_s8r_schema_bounds.py (17fde34)
S8R-AUDIT-069: xfail-тест — tests/unit/test_strategy/test_audit_s8r_delete_live_session.py (падает на DID NOT RAISE; bd3e117)
S8R-AUDIT-068: xfail-тест — tests/test_circuit_breaker/test_audit_s8r_drawdown_sandbox.py (blocked=False при убытке 20 %; 9940504)
S8R-AUDIT-072: xfail-тест — tests/unit/test_common/test_audit_s8r_trading_hours_calendar.py (суббота 12:00 = торговое время; e951f64)
S8R-AUDIT-080: xfail-тесты — tests/test_trading/test_audit_s8r_risk_params_bounds.py (SL long = 105 при входе 100; коммит после e951f64)
S8R-AUDIT-007 / -013: xfail-тесты добавлены — tests/test_trading/test_audit_s8r_orphan_recovery_errors.py, tests/unit/test_backtest/test_audit_s8r_ws_revocation.py (коммит 7cc98e2, запушен)
(info, без карточек: B1-02, B1-05, B1-06 N+1 без пагинации, B1-07→013, B1-10 dict-тело, B1-14 нет extra=forbid, B2-08 publish в литеральный канал, B2-12 user_id=0 по умолчанию, D2-03/04; B1-15 bootstrap-гонка — ждёт A Q7)

## Вердикты по сырым находкам ревьюеров (до оформления карточек)
B1-01 low — подтверждено чтением `strategy/service.py:335-346` (ownership после выборки, 403≠404) → карточка low после завершения B
B1-02 info — подтверждено (неиспользуемый `user_id` в `get_instruments_summary`) → в info-список
B2-01 low — подтверждено по коду (`TradingSession` без `user_id`, 10 копий JOIN); следствие «стратегия удалена → сессия неуправляема» проверить в G4/I1 (блокируется ли delete при живых сессиях)
B2-02 medium — подтверждено → S8R-AUDIT-003
B2-03 low — подтверждено чтением `circuit_breaker/service.py:40-63` + `router.py:47-58` (upsert на любой session_id без проверки сессии) → карточка low
D1-01/D1-03 blocker/high — подтверждено прогоном → S8R-AUDIT-001 (D1-03 — тот же корень)
D1-02 blocker — подтверждено прогоном → S8R-AUDIT-002
D2-01 low — подтверждено (`url_validator.py:18-19` заявляет защиту от rebinding, фактически резолв отдельный от запроса SDK) → карточка low «SSRF-барьер: TOCTOU + 100.64/10 + сырой str(e) в verify»
D2-02 low — подтверждено (`_is_forbidden_ip` без 100.64.0.0/10, опора на `is_private`)
D2-03 info — подтверждено (`openai_provider.py:129-137`, `ai/router.py:112-124` — `str(e)` наружу)
D2-04 info — подтверждено (флаг глобальный, задокументирован как NEEDS-REVIEW)

G2-01…11 — все подтверждены чтением runtime.py/stream_manager.py/engine.py (карточки 007–012, 019); G2-09 → отсеяно (см. ниже)
B2-04 medium — подтверждено (ws_auth.py без RevokedToken/is_active; HTTP auth.py:46-58 проверяет) → 013
B1-08 medium — подтверждено (ai/service.py:67-73, 107-153) → 014
B1-04 low — подтверждено + выявлено отсутствие PRAGMA foreign_keys → 015, 017

## Отсеяно — по одной строке с причиной
G2-09 (SL/TP только по закрытым локальным барам, стоп-заявок у брокера нет; предложен high) — не новая находка: задокументированное проектное ограничение (ФТ v3.4/«Архитектурное ограничение»: «пока терминал не запущен, стоп не сработает — серверных стоп-заявок у брокера нет»); переносится в таблицу «что открыто» как решение заказчика для `real`.

## Текущий шаг
2026-09-17 16:08–16:14: запущены 24 ревьюера — ВСЕ упали на лимите сессии API (429, сброс 19:50). 20:30–20:50: волна 1 (A, B1, B2, C, D1, D2) + G1, G2, G3 (9 агентов) — **второй обрыв по лимиту ~20:50 (сброс 01:20)**: завершились только B1 (443 строки, ✅) и D1 (✅, D1-04…07); B2 дописан до ПРОВЕРЕНО/НЕ ПРОВЕРЕНО (второй ревьюер, ✅ с остатком); G2 — 11 находок без итога; A, C, G1, G3, D2 — файлов нет/не дописаны.
2026-09-18 18:30: продолжение. Волна A, C, G1 — все ✅ (18:30–19:05). Затем G3, D2, G2c, E — **третий обрыв по лимиту ~19:08 (сброс 19:10)**: G3 записал 267 строк (G3-01…46), E — 125 строк, D2 — раздел 2 (SQL), G2c — ничего.
2026-09-18 19:45: продолжение. Правило: **не более 2 ревьюеров одновременно**; малые аспекты (R, части P/E) оркестратор закрывает сам; docs/frontend-аспекты — модель sonnet. 19:45–20:10: E ✅ (второй ревьюер), R/P/O-статика/Q2-статика/M/N/K/F/H/I/L-лёгкие самопроверки — оркестратор; G3d и G4 упали с «Fable limit reached» (~20:10) — **лимит Fable для субагентов исчерпан**.
2026-09-23 20:25: продолжение. Среда цела (worktree 555fde8 = origin, симлинков нет, стенд 8000/5173 мой ещё жив). Все оставшиеся ревьюеры — на модели **sonnet**, по 2 одновременно: волна G3e (multiplexer/service/ISS) + D2d (разделы 3–7).

2026-09-23 ~20:00: K2 ✅ (sonnet) → карточки 089–098. ~20:35: J2 ✅ (sonnet) → карточки 099–101; `tests/_audit_j2_tmp/` удалён ревьюером, `git status` в worktree пуст. Далее — финализация отчёта и уборка.

## Следующий шаг
нет — аудит завершён 2026-09-23. Итог: 101 карточка (3 blocker / 24 high / 53 medium / 21 low), 26 доказательных тестов на `s8r/audit` (26d65ca, CI зелёный). Отчёт — `audit_2026-09.md` (§1–§9), задание исполнителю — `prompt_s8r_audit_fixes.md`. Не пройдены (⏸, причины — `audit_2026-09.md` §9): F (частично), H1, I2, J1 (частично), L2–L7, M, N, O-выборка, S. Финализация: backlog.md + project_state.md, коммит docs → main (`--no-ff`), PR `s8r/audit` → `develop`, уборка стенда/worktree — см. §7 отчёта.

## Живой брокер (аспект S)
не начинался — ни одного ордера на счёте #3 не отправлялось; симлинк `.env` не создавался; счёт в исходном состоянии (не трогался). Причина и план — `audit_2026-09.md` §5 п. 4, §9.
