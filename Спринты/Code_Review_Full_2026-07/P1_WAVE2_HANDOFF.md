# Хэндофф: P1 Волна 2 (+ Волна 3) — промпт для новой сессии

> Скопируй блок «ПРОМПТ» ниже в новую сессию Claude Code (Opus 4.8) в корне репозитория `Test`.
> Всё необходимое — в `Спринты/Code_Review_Full_2026-07/` и `Develop/CLAUDE.md`.

---

## Состояние на момент хэндоффа (2026-07-06)

- **Develop** (`git@github.com:SergoPipo/moex-terminal.git`) на ветке `s8r/bug-31-unified-codegen`, HEAD `a936e1a`, **запушено**. Содержит: P0 (C1–C7) + P1 Волна 1 (18 High: trading/market-data/backtest/strategy) + review-followup (FIX-1..9).
- **Test** (внешний, `git@github.com:SergoPipo/test.git`) на ветке `docs/backlog-006-strategy-builder`, HEAD `d4b52c6`, запушено. Доки ревью в `Спринты/Code_Review_Full_2026-07/`.
- Осталось по P1: **Волна 2** (backend, 6 веток) и **Волна 3** (frontend, 6 веток).

## Оставшиеся ветки P1

### Волна 2 — backend (реальные пункты, дубли P0 исключены)
| Ветка | Пункты (строки в `tdd_tasks_P1.md`) | Примечания |
|---|---|---|
| `fix/be-auth-session` | BE-AUTH-02 (95), BE-AUTH-03 (101) | CFG-BE-02 = дубль C3 (сделано); можно доделать doc-часть: `deployment_guide.md` MASTER_KEY→ENCRYPTION_KEY + docker-compose проверка `.env.production`. BE-AUTH-03 = отзыв refresh/ротация — **alembic не нужен, но проверить RevokedToken**. |
| `fix/be-broker` | BE-BROK-01 (117), BE-BROK-02 крипто-часть (123) | BE-BROK-02 config-часть = дубль C3 (сделано); остаётся валидация длины/энтропии master_key + фикс-соль HKDF в CryptoService. **context7 по tinkoff-investments. `/code-review` обязателен (критпуть).** |
| `fix/be-notification` | BE-NOTIF-02 (304), BE-NOTIF-03 (310) | AUTHZ-05 = дубль C1 (сделано). BE-NOTIF-03 (UniqueConstraint user_id,event_type) — **нужна alembic-миграция**. При правках уведомлений — синхронизировать EVENT_MAP ↔ EVENT_TYPE_LABELS (тест `test_event_map_sync.py`). |
| `fix/be-ai` | BE-AI-01 (325), BE-AI-02 (331) | BE-AI-02: messages[0].role=assistant → 400 у Anthropic. |
| `fix/be-runtime` | BE-RT-01 (346), BE-RT-02 (352), BE-RT-03 (358) | circuit_breaker/sandbox/scheduler. **`/code-review` по circuit_breaker (критпуть). superpowers TDD обязателен.** |
| `fix/be-misc` | BE-MISC-17 (373), BE-MISC-18 (379), BE-MISC-19 (385) | BE-MISC-17: AdminAuth ASGI не проверяет отзыв токена. BE-MISC-19: налог неттит типы инструментов вопреки ст.214.1 НК. |

### Волна 3 — frontend (нужны tsc + Playwright)
| Ветка | Пункты | Примечания |
|---|---|---|
| `fix/fe-security` | CFG-FE-01, CFG-FE-02, FE-STOR-12, FE-STOR-13 | токены в localStorage/URL. |
| `fix/fe-network` | FE-NET-01, 02, 03, **FE-NET-04 (❓ уточнить)** | FE-NET-04 — см. `verification_P1.md`: нужен ли явный backoff. |
| `fix/fe-charts` | **FE-CHART-01 (❓ уточнить)**, FE-CHART-02, FE-CHART-03 | FE-CHART-01 — проверить, применяется ли VlinePrimitive для intraday. context7 по lightweight-charts. |
| `fix/fe-backtest-ui` | FE-BTST-13, 14, **FE-BTST-15 (❓)**, 16 | FE-BTST-15 — уточнить сценарий скрытия (unmount vs display:none). |
| `fix/fe-core-refactor` | FE-PAGE-01/02/03, FE-CORE-01/02/06/07/08 | god-компоненты + дубли форматтеров/guard. Крупный рефактор. |
| `fix/fe-ui-misc` | FE-STRAT-01, FE-TRAD-01, FE-TRAD-02, FE-UI-01 | Blockly load-валидация и пр. |

**❓-пункты** (FE-NET-04, FE-CHART-01, FE-BTST-15) — в `verification_P1.md` помечены «уточнить перед фиксом». Спросить заказчика или проверить точки вызова до реализации.

## Метод (проверен на Волне 1 — соблюдать точно)

1. **Worktree на каждую ветку** от `s8r/bug-31-unified-codegen` (НЕ checkout — в Develop живут Vite+uvicorn):
   `cd Develop && git worktree add -b fix/<name> .claude/worktrees/fix-<name> s8r/bug-31-unified-codegen`
2. **DEV-агенты (Opus, test-first)** — по одному на ветку, каждый в своём worktree. Промпт: точные пункты из `tdd_tasks_P1.md` (дать номера строк), TDD Red→Green→Refactor, читать `Develop/stack_gotchas/INDEX.md` по симптому, integration-grep вызова в проде, «деньги = Decimal», при рискованной правке — `⚠️ NEEDS-REVIEW`, отчёт ≤400 слов по 8 секциям. Push/merge агентам запрещены.
3. **Запуск pytest в worktree (КРИТИЧНО):** из backend САМОГО worktree, с DEBUG:
   `cd <wt>/backend && DEBUG=true /Users/sergopipo/Documents/Claude_Code/Test/Develop/backend/.venv/bin/python -m pytest <targets> -q`
   (cwd worktree затеняет editable-install живой копии; `DEBUG=true` обязателен — иначе config fail-fast на дефолтном SECRET_KEY). Проверка: `python -c "import app; print(app.__file__)"` → путь worktree.
4. **Мерж:** непересекающиеся директории → ff-merge/clean merge каждой ветки в `s8r/bug-31`. Если пересечения (напр. config.py, notification/service.py) — мержить по очереди, разрешать вручную. Мержить/гейтить в отдельном integration-worktree ИЛИ ff в главном Develop-дире.
5. **Гейт на объединённом результате (после ff в s8r/bug-31 — канон):**
   - `pytest` по всем затронутым модулям (Волна 1 давала 1329 passed);
   - `pyright --venvpath . <изменённые prod .py>` из backend (глобальный pyright 1.1.410). Baseline-шум Backtrader в `backtest/engine.py` — предсуществующий, сверять число ошибок с baseline @HEAD.
6. **`/code-review`** по broker и circuit_breaker (критпути) — обязательно. **Волна 1 показала: ревью находит реальные дефекты в свежих фиксах** (BE-TRAD-09 не работал, фантом-close). Быть готовым к отдельному test-first раунду фиксов (как FIX-1..9).
7. **Frontend (Волна 3):** worktree'ы Develop НЕ содержат node_modules (gitignore) → `tsc --noEmit`/Playwright там не пройдут. Варианты: (а) работать в живом `Develop/frontend` на ветке (аккуратно с HMR), (б) симлинк `node_modules` в worktree. tsc-гейт гнать после мержа в живой копии. Playwright-скриншот затронутых экранов (см. матрицу в `Develop/CLAUDE.md`).
8. **Push:** после зелёного гейта + ревью — `git push origin s8r/bug-31-unified-codegen`. Убрать worktree'ы и смёрженные ветки.
9. **Доки (репо Test, ветка `docs/backlog-006-strategy-builder`):** после волны — `P1_WAVE2_LOG.md` (по образцу `P1_WAVE1_LOG.md`), обновить `project_state.md`, закоммитить+запушить. **Спрашивать ветки для обоих репо отдельно (правило двух репо).**

## Ссылки
- Спеки пунктов: `Спринты/Code_Review_Full_2026-07/tdd_tasks_P1.md` (дословные Проблема/Fix).
- Вердикты верификации: `verification_P1.md`. Приоритеты/полный список: `backlog_fixes.md`.
- Как делалась Волна 1 + уроки ревью: `P1_WAVE1_LOG.md`, P0 — `P0_FIXES_LOG.md`.
- Правила плагинов/стека: `Develop/CLAUDE.md`; ловушки — `Develop/stack_gotchas/INDEX.md`.

---

## ПРОМПТ (копировать в новую сессию)

```
Продолжаем P1 из код-ревью MOEX-терминала. Прочитай сначала:
- Спринты/Code_Review_Full_2026-07/P1_WAVE2_HANDOFF.md (состояние, оставшиеся ветки, метод, ссылки)
- Спринты/Code_Review_Full_2026-07/P1_WAVE1_LOG.md (как сделана Волна 1 + уроки /code-review)
- Спринты/project_state.md (последние записи 2026-07-06)

Затем запусти P1 Волну 2 (backend, 6 веток: be-auth-session, be-broker, be-notification,
be-ai, be-runtime, be-misc) строго по методу из HANDOFF: DEV-агенты Opus test-first в
изолированных git-worktree'ах от s8r/bug-31-unified-codegen (@a936e1a), затем мерж +
полный pytest/pyright-гейт + /code-review по broker и circuit_breaker + push. Спеки
пунктов — в tdd_tasks_P1.md (номера строк в таблице HANDOFF). Дубли P0 (CFG-BE-02 core,
BE-BROK-02 config-часть, AUTHZ-05) не делать. BE-NOTIF-03 требует alembic-миграцию.
Работаем с моделью Opus 4.8, коммиты/push — только по подтверждению, ветки для обоих
репо (Develop + Test) спрашивать отдельно. Если увидишь приближение лимита сессии —
остановись и спроси. После Волны 2 предложи Волну 3 (frontend).
```
