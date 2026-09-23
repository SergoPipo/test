---
цикл: Sprint_8_Review — исполнение находок аудита 2026-09 (`audit_2026-09.md`)
дата подготовки: 2026-09-23
режим: исполнитель (более младшая модель) + три оси ревью на каждый пакет
характер цикла: ФИКСЫ по карточкам S8R-AUDIT-NNN, строго по рецептам; ничего сверх карточек
источник: `Спринты/Sprint_8_Review/audit_2026-09.md` (полный текст карточек — там; здесь только порядок и правила)
---

# 0. Правила исполнения (читать перед каждым пакетом)

1. **Код только в worktree** от `origin/develop`: `git worktree add ../wt-s8r-fixes -b s8r/audit-fixes origin/develop`; первая команда — `git log --oneline -1`. Симлинк `frontend/node_modules` → основной чекаут; `.env` не симлинковать.
2. **Сначала снять маркер, потом чинить.** По Q11 в `develop` (после мержа PR из `s8r/audit`) лежат доказательные тесты с `xfail(strict=True, reason="S8R-AUDIT-NNN")` / vitest `it.fails`. Порядок для карточки: убрать маркер → прогон RED с фактическим выводом в лог → правка по рецепту → GREEN → мутация «сломать фикс → тест красный» → полный гейт. Карточки без готового теста — тест пишется первым по п.1 рецепта (`mattpocock-skills:tdd`).
3. **Гейты после каждой карточки** (baseline 24.08 + xfail аудита): backend `pytest` 0 failed, число passed не ниже предыдущего; `ruff`, `mypy`, `bandit -ll`; `pnpm typecheck && pnpm build && pnpm lint && pnpm test`. E2E одним прогоном — после каждого пакета (`CI=1 npx playwright test --reporter=list > run.log 2>&1`, gotcha-49; стенд на чистой БД, gotcha-47).
4. **`/code-review` после каждой карточки**, затрагивающей `app/trading/`, `app/broker/`, `app/circuit_breaker/`, `app/sandbox/`, `app/strategy/ir*.py`, `app/auth/`, `app/middleware/` — находки чинить в той же карточке.
5. **Не трогать**: решения заказчика (paper без ограничений по инструменту; sandbox/real — одна сессия на пару «счёт+тикер»; рабочая БД `Develop/backend/data/terminal.db`; правка `.env.example` заказчика); всё, что в карточке помечено «Чего НЕ трогать».
6. **Миграции**: только новые ревизии, id — уникальный (`alembic heads` = 1 после, gotcha-53), `batch_alter_table` (gotcha-12), обратимый `downgrade`, round-trip тест на чистой БД; запись в `deployment_guide.md` §7. Рабочую БД не мигрировать.
7. **Логи проекта после каждой карточки**: `Sprint_8_Review/backlog.md` (раздел «Аудит 2026-09 — исполнение»), `project_state.md`; ФТ/ТЗ — только там, где карточка меняет поведение (шапка версии + таблица истории синхронно); `ui_checklist_s8.md` — обе копии побайтово.
8. **Контрольные точки**: файл `Спринты/Sprint_8_Review/fixes_progress.md` — таблица «карточка → статус (⬜/🔄/✅/⏸) → коммит → гейты → ревью по трём осям»; коммит и push **после каждой закрытой карточки**; остановка только на границе карточки с записью «Следующий шаг». Сессия, оборванная без записи, — дефект процесса.
9. **Секреты**: `.env`, токены — не читать, не логировать, не коммитить; любой засветившийся ключ — перевыпуск (карточка 036 требует ревизии `logs/dev.log` заказчиком).
10. **Ревью пакета** (после закрытия всех карточек пакета) — три независимых оси, каждая отдельным субагентом: (а) *требование* — сделано ли то, что в «Что не так»/«Чем грозит»; (б) *рецепт* — сделано ли так, как предписано, без самодеятельности; (в) *качество кода* — пригодно ли строить дальше. Ревьюер качества — **один на весь цикл** (SendMessage с тем же агентом), чтобы видеть противоречия между пакетами. Находка ревью — одно предложение условием, с `файл:строка`, без кода.
11. **Решения заказчика, которые нужны до старта пакета**, перечислены в шапке пакета — не додумывать, спросить одним блоком до начала пакета.

# 1. Пакет BLOCKER

Решения заказчика до старта: (а) 001 — оставить ли режим code-only (`generated_code` без блоков) вообще; если нет — путь `runtime_backtrader_code` fallback и `_execute_strategy` удаляются, и 019/028 закрываются попутно; (б) 033 — нужна ли регистрация второго пользователя (по ФТ — нет; если да — только admin через `/admin/users`).

Порядок (зависимости): **033 → 002 → 001**. 033 закрывает вход анониму (без него 001/002 эксплуатируемы из интернета); 002 — узкая валидация полей блоков (S, без архитектурных решений); 001 — allow-list песочницы (M) с решением (а).

| Карточка | Severity | Объём | Готовый тест (xfail) |
|---|---|---|---|
| S8R-AUDIT-033 | blocker | S | `tests/unit/test_audit_s8r_auth_setup.py::test_setup_is_closed_after_first_user` |
| S8R-AUDIT-002 | blocker | S | `tests/unit/test_strategy/test_audit_s8r_source_injection.py` (2) |
| S8R-AUDIT-001 | blocker | M | `tests/unit/test_sandbox/test_audit_s8r_escape.py` (3) + написать `test_module_attribute_chain_blocked` |

После пакета: E2E полный прогон; `/code-review` по `app/sandbox/`, `app/strategy/ir*.py`, `app/auth/`.

# 2. Пакет HIGH

Решения заказчика до старта: 032 — блокировать short (по ФТ §1.3) или чинить учёт под short; 030/024 — допустимый дедлайн унарных вызовов (10–15 с).

Порядок: **034 → 035 → 036 → 007 → 024 → 030 → 074 → 075 → 061 → 025 → 026 → 032 → 068 → 069 → 055**; затем блок K2 (независим от торгового контура): **093 → 089 → 090 → 091 → 092**. Гонки J2 (после 015 — FK, и вместе с 029/076): **101 → 099** (101 — миграция UNIQUE на `broker_accounts` + лок в `create_account`; 099 — тот же `session_start_account` лок в `delete_account`, S).
(093 — календарь MOEX с ISS-клиентом, первым — на него опираются 072 и мультиплексор; 089 — множитель `lot_size` в дивидендах/купонах, S; 090 — начисление по `ex_date` + `rollback()` в `process_pending`, S; 091 — источники сплитов/купонов в ISS, M, back-adjust свечей — только после решения заказчика; 092 — backup/restore: `Connection.backup`, атомарная подмена, межпроцессный лок, M.)
(074 — shield отправки и порядок shutdown, сразу после 024/030 — тот же принцип «нет ответа ≠ нет ордера»; 075 — SL/TP уведомление и синхронизация реестра с `exit_broker_order_id`; 068 — CB по просадке для sandbox/real, после 025 — использует `lot_size` в equity; 069 — запрет удаления стратегии с живой сессией, S.)
Обоснование: 034/035/036 — секреты и сессии (независимы, S); 007 и 024 — один принцип «нет ответа ≠ нет ордера» (recovery, затем путь ордера); 030 — дедлайны, на которые опирается 024; 061 — стрим (очередь команд, ack, терминальные ошибки, refcount подписок — M; после 030, т.к. использует тот же классификатор ошибок); 025 — количества/`lot_size` (миграция!); 026 — сайзинг (S); 032 — short (S, после решения); 055 — фронт/деплой (S).

| Карточка | Severity | Объём | Готовый тест |
|---|---|---|---|
| S8R-AUDIT-034 | high | S | `tests/unit/test_audit_s8r_auth_setup.py::test_placeholder_secret_key_rejected_in_production` |
| S8R-AUDIT-035 | high | M | — (написать по п.1 рецепта; миграция `users.token_version`) |
| S8R-AUDIT-036 | high | S | — |
| S8R-AUDIT-007 | high | S | `tests/test_trading/test_audit_s8r_orphan_recovery_errors.py` (2) |
| S8R-AUDIT-024 | high | M | — |
| S8R-AUDIT-030 | high | S | — |
| S8R-AUDIT-074 | high | S | — |
| S8R-AUDIT-075 | high | S | — |
| S8R-AUDIT-061 | high | M | — (офлайн-репро в `G3.findings.md` G3-47 — перенести в тест) |
| S8R-AUDIT-025 | high | M | — (миграция `live_trades.lot_size`) |
| S8R-AUDIT-026 | high | S | `tests/unit/test_audit_s8r_health_and_sizing.py` (2) |
| S8R-AUDIT-032 | high | S | — |
| S8R-AUDIT-068 | high | M | `tests/test_circuit_breaker/test_audit_s8r_drawdown_sandbox.py` (+ миграция `trading_sessions.peak_equity` или equity по сделкам) |
| S8R-AUDIT-069 | high | S | `tests/unit/test_strategy/test_audit_s8r_delete_live_session.py` |
| S8R-AUDIT-055 | high | S | `frontend/src/api/__tests__/audit_s8r_baseurl.test.ts` (it.fails ×2) |
| S8R-AUDIT-078 | high | M | — (репро отмены Pool — в `H2.findings.md` H2-02; в конце пакета, независимо от торгового контура) |
| S8R-AUDIT-093 | high | S | — (тест `test_scheduler_calendar_has_iss_client`, п.1 рецепта) |
| S8R-AUDIT-089 | high | S | — (5 лотов × lot_size 10 × 20 ₽ → 1000 ₽) |
| S8R-AUDIT-090 | high | S | — |
| S8R-AUDIT-091 | high | M | — (мок ISS `splits.json`/`bondization.json`) |
| S8R-AUDIT-092 | high | M | — (restore только на копии БД через `Connection.backup`, рабочую БД не трогать) |
| S8R-AUDIT-101 | high | S | — (тест с `asyncio.gather` по образцу `TestConcurrentStartRace`; миграция UNIQUE — сначала проверка дублей) |
| S8R-AUDIT-099 | high | S | — (рандеву до лока, gotcha-59) |
| S8R-AUDIT-080 | high | S | `tests/test_trading/test_audit_s8r_risk_params_bounds.py` (2; сразу после 026 — общая схема риск-параметров) |

После пакета: E2E; `/code-review` по `app/trading/`, `app/broker/`, `app/corporate_actions/`, `app/backup/`; для 099/101 — 10 прогонов подряд каждого race-теста; живой прогон на счёте #3 по сценариям S-1/S-2/S-7 из `prompt_s8r_audit.md` §3.S (симлинк `.env` только на время, снять сразу; каждый ордер — в отчёт; счёт вернуть в исходное).

# 3. Пакет MEDIUM

Порядок группами (внутри группы — любой): 
- **Рантайм/сверка/CB**: 008 → 009 → 010 → 011 → 012 → 029 → 076 → 027 → 070 → 071 → 072.
- **Брокер/бэктест**: 044 → 045 → 046 → 047 → 062 → 063 → 006 → 077.
- **Auth/периметр**: 013 → 037 → 038 → 039 → 040 → 041 → 021 → 058 → 057 → 056.
- **Данные/платформа**: 015 → 004 → 003 → 014 → 020 → 028 → 054 → 051 → 053 → 065 → 066 → 097 (пул и `persist_with_retry` — после 015/004, с замером гейта N).
- **Планировщик/налоги (K2)**: 094 → 096 → 095 (095 — категоризация сразу, база — после решения заказчика).
- **Конструктор стратегий/UI**: 081 → 082 (после 002 — allow-list 422 должен показываться пользователю).
- **Гонки (J2)**: 100 — вместе с 069 (тот же `StrategyService.delete`).
- **Уведомления**: 073 → 083 → 084 → 085 (073 переведена в medium: имя события CB вне `EVENT_MAP`).
- **Документация/аудит**: 086 (после 083 — `pending_events` через тот же диспетчер) → 087 (только после решений заказчика по пунктам).

| Карточка | Severity | Объём | Готовый тест |
|---|---|---|---|
| S8R-AUDIT-003 | medium | S | — |
| S8R-AUDIT-004 | medium | S | `tests/unit/test_audit_s8r_alembic.py::test_alembic_check_is_clean_on_fresh_db` |
| S8R-AUDIT-006 | medium | M | — |
| S8R-AUDIT-008 | medium | S | — |
| S8R-AUDIT-009 | medium | S | — |
| S8R-AUDIT-010 | medium | S | — |
| S8R-AUDIT-011 | medium | S | — |
| S8R-AUDIT-012 | medium | M | — |
| S8R-AUDIT-013 | medium | S | `tests/unit/test_backtest/test_audit_s8r_ws_revocation.py` (2) |
| S8R-AUDIT-014 | medium | S | — |
| S8R-AUDIT-015 | medium | S | `tests/unit/test_audit_s8r_foreign_keys.py` |
| S8R-AUDIT-020 | medium | S | — |
| S8R-AUDIT-021 | medium | S | — |
| S8R-AUDIT-027 | medium | S | — (решение заказчика: база percent) |
| S8R-AUDIT-028 | medium | S | — |
| S8R-AUDIT-029 | medium | S | — (тест с рандеву до лока, gotcha-59) |
| S8R-AUDIT-037 | medium | S | — |
| S8R-AUDIT-038 | medium | S | — |
| S8R-AUDIT-039 | medium | S | — |
| S8R-AUDIT-040 | medium | S | — |
| S8R-AUDIT-041 | medium | M | — |
| S8R-AUDIT-044 | medium | S | — |
| S8R-AUDIT-045 | medium | S | — |
| S8R-AUDIT-046 | medium | S | — |
| S8R-AUDIT-047 | medium | S | — |
| S8R-AUDIT-051 | medium | S | — (тест `test_env_example_covers_all_settings`) |
| S8R-AUDIT-053 | medium | S | — (только тесты) |
| S8R-AUDIT-054 | medium | S | `tests/unit/test_audit_s8r_health_and_sizing.py::test_health_is_not_ok_when_database_unavailable` |
| S8R-AUDIT-056 | medium | S | — |
| S8R-AUDIT-057 | medium | S | — |
| S8R-AUDIT-058 | medium | M | — |
| S8R-AUDIT-062 | medium | S | — |
| S8R-AUDIT-063 | medium | S | — (⏸ живой GET к ISS для подтверждения таймзоны — заказчик/исполнитель) |
| S8R-AUDIT-065 | medium | S | `tests/unit/test_audit_s8r_schema_bounds.py::test_ticker_with_formula_prefix_is_rejected` |
| S8R-AUDIT-066 | medium | S | — |
| S8R-AUDIT-070 | medium | S | — |
| S8R-AUDIT-071 | medium | S | — (миграция данных `position_sizing_mode NULL → fixed_lots`) |
| S8R-AUDIT-072 | medium | S | `tests/unit/test_common/test_audit_s8r_trading_hours_calendar.py` |
| S8R-AUDIT-076 | medium | S | — (тест с рандеву до лока, gotcha-59) |
| S8R-AUDIT-077 | medium | S | — |
| S8R-AUDIT-081 | medium | S | — (решение заказчика: какие статусы допускают запуск сессии, автоперевод) |
| S8R-AUDIT-082 | medium | S | — |
| S8R-AUDIT-073 | medium | S | — (перенесена из low) |
| S8R-AUDIT-083 | medium | S | — |
| S8R-AUDIT-084 | medium | S | — |
| S8R-AUDIT-085 | medium | S | — |
| S8R-AUDIT-086 | medium | M | — |
| S8R-AUDIT-087 | medium | L | — (по каждому пункту — решение заказчика: реализовать или править ФТ) |
| S8R-AUDIT-094 | medium | S | — |
| S8R-AUDIT-095 | medium | S | — (база — решение заказчика) |
| S8R-AUDIT-096 | medium | S | — (миграция `tax_lots.report_id`) |
| S8R-AUDIT-097 | medium | S | — (гейт N после правки пула) |
| S8R-AUDIT-100 | medium | S | — (делать в одном коммите с 069) |

После пакета: E2E; `/code-review` по затронутым каталогам; `deployment_guide.md` — версия шапки и §3.2/§3.3/§7/§8 (051, 054, 056, 057).

# 4. Пакет LOW

Порядок: 005 → 016 → 017 → 018 → 019 → 022 → 023 → 031 → 042 → 043 → 048 → 064 → 049 (команды заказчику) → 050 → 052 → 059 → 060 → 098 (после 065 — общий `TICKER_RE`).

| Карточка | Severity | Готовый тест |
|---|---|---|
| S8R-AUDIT-005 | low | `tests/unit/test_audit_s8r_alembic.py::test_full_round_trip_upgrade_downgrade_upgrade` |
| S8R-AUDIT-067 | low | `tests/unit/test_audit_s8r_schema_bounds.py::test_negative_drawdown_and_zero_trade_limit_are_rejected` |
| S8R-AUDIT-016, 017, 018, 019, 022, 023, 031, 042, 043, 048, 050, 052, 059, 060, 064, 079, 088, 098 | low | — |
| S8R-AUDIT-049 | low | н/п — команды выполняет заказчик |

# 5. Что не входит в задание исполнителя

- Решения заказчика (владелец «заказчик» в сводной таблице `audit_2026-09.md` §8): code-only режим, регистрация второго пользователя, short, база percent-сайзинга, SL/TP у брокера vs локально (G2-09), Cloudflare Access, GPL-инвентаризация, back-adjust свечей при сплите (091), единая vs раздельная налоговая база (095).
- Аспекты, не пройденные аудитом (⏸ в `audit_progress.md`): их находки появятся после дозакрытия аудита, не изобретать.
- Sprint 9 — не стартовать.
