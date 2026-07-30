# RESUME PROMPT — завершение приёмки Sprint_8_Review (S8R) на s8r

> Скопируй всё, что ниже разделителя, в новую сессию Claude Code (Opus 4.8) как первый промпт.

---

Задача: **завершить приёмку Sprint_8_Review (S8R)** торгового терминала MOEX — доделать оставшиеся UI-секции чеклиста через Playwright, оттриажить найденное и вынести вердикт Gate. Модель Opus 4.8. Предыдущая сессия закрыла P1-находку BE-TRAD-06 (смёржена, PR #7/#8 в `s8r/bug-31-unified-codegen`), спланировала приёмку и выполнила Ф0/Ф1 + половину Ф2. Ничего не переоткрывай — иди по готовому плану.

## Что прочитать ПЕРВЫМ (источники истины, в этом порядке)
1. `Спринты/Sprint_8_Review/s8r_acceptance_run_2026-07-26.md` — ЛОГ прогона: что уже проверено, что осталось, состояние стенда, наблюдения.
2. `Спринты/Sprint_8_Review/acceptance_execution_plan.md` — план приёмки (6 фаз) + решения заказчика.
3. `Спринты/Sprint_8_Review/acceptance_checklist.md` — сам чеклист (136 пунктов, отмечать `[x]`/`[!]`/`[-]`).
4. `Спринты/project_state.md` — общий статус (BE-TRAD-06 закрыт, открытых P1 нет; далее Gate S8R → Sprint 9).

## Решения заказчика (НЕ пересматривать)
- Кодовая база приёмки — **s8r/bug-31-unified-codegen** (консолидированный, P0+P1+auth-hardening+BE-TRAD-06).
- UI-секции S8.1–S8.12 — **полностью через Playwright** (+ скриншоты-evidence).
- P1-затронутое — **перепроверять выборочно** (auth-cookie/WS + BE-TRAD-06 деньги/CB).
- Креды AI/Telegram — **сидированы из копии рабочей БД** (уже в стенде).

## Стенд (уже настроен на диске; в новой сессии — ПРОВЕРИТЬ и при необходимости перезапустить)
- Worktree: `Develop/.claude/worktrees/s8r-acceptance` (ветка `s8r-acceptance`, HEAD `eba6427`). НЕ трогать живой чекаут `Develop/` (там p1/wave2-backend).
- Изолированная БД: `<worktree>/backend/data/acceptance.db` (снапшот live, миграции до s8r-head, торговые сессии → `stopped`, пароли сброшены). T-Invest придержан (сессии stopped → авто-стримов нет).
- Backend :8100, Frontend :5173. Логин: **sergopipo** (admin) / **testuser1** (non-admin), пароль обоих `S8Raccept2026!`.
- ⚠️ Открывать фронт ТОЛЬКО через `http://localhost:5173` (НЕ 127.0.0.1 — CORS backend разрешает origin `localhost:5173`).
- Evidence-скриншоты: `s8r-evidence/` в корне репо Test (ASCII-путь; в финале перенести в `Спринты/Sprint_8_Review/screenshots/`).

**Проверка стенда:** `curl -s http://127.0.0.1:8100/api/v1/health` (ждём `status:ok`) и `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5173/` (200). Если не отвечают — перезапустить:

```bash
DEV=/Users/sergopipo/Documents/Claude_Code/Test/Develop
WT="$DEV/.claude/worktrees/s8r-acceptance"; PY="$DEV/backend/.venv/bin/python"
# BACKEND (фон):
cd "$WT/backend" && DATABASE_URL='sqlite+aiosqlite:///./data/acceptance.db' SQL_ECHO=false LOG_LEVEL=INFO \
  "$PY" -m uvicorn app.main:app --host 127.0.0.1 --port 8100   # run_in_background
# FRONTEND (фон):
cd "$WT/frontend" && VITE_API_BASE_URL='http://localhost:8100/api/v1' VITE_WS_URL='ws://localhost:8100' \
  node_modules/.bin/vite --port 5173 --host 127.0.0.1 --strictPort   # run_in_background
```
(node_modules во worktree — symlink на live; venv — общий из основного чекаута, cwd=worktree резолвит код worktree.)

## Уже СДЕЛАНО (не переделывать — детали в run-log)
- **Ф1 тех-гейт на s8r ✅:** backend pytest **2185 passed, 1 xfailed, 0 failed**; vitest **761 passed**; tsc 0; eslint 0; bandit 0 medium+. → покрывает S8.10/13/16/17 (кроме dark-theme визуала), S8.14 (инструментовка). Coverage не мерян (ранее 85%; при желании `pytest --cov=app --cov-fail-under=80`).
- **Ф2b auth ✅ (частично):** cookie-логин (3 HttpOnly, контракт DESIGN §3); require_admin `/api/v1/admin/ping` = 401(no-auth)/200(admin)/403(non-admin).
- **Ф2 UI ✅ (частично):** S8.1 (меню+/admin+require_admin), S8.2 (Dash-метрики: `http://127.0.0.1:8100/api/v1/admin/metrics/`, 4 Plotly-графика, тёмная тема), S8.4 (фильтр «Пауза»+бейдж — dropdown осталось), S8.5 (4 виджета), S8.7 (14 типов уведомлений). Креды сидированы: AI `deepseek-v4-pro` (openrouter), Broker Prod+Sandbox.

## ОСТАЛОСЬ доделать
**Ф2 (Playwright, на стенде):**
- S8.1 — non-admin UI: под `testuser1` в меню НЕТ «Администрирование» (условный Sidebar).
- S8.3 — error-boundary: плашки «Повторить» при сбое блока (дашборд/график) — сложно триггерить; допустимо подтвердить наличие `ErrorBoundary` в коде + отметить.
- S8.4 — клик по бейджу статуса стратегии → dropdown переходов (недоступные серые) + фильтр «Пауза».
- S8.6 — Telegram: мастер (шаг 4 «Свой бот») или Настройки → кнопка «проверить Telegram» → **реальная отправка** (креды в стенде). Если wizard недоступен (completed) — искать в Настройках→Уведомления.
- S8.8 — рисование на графике (линии/прямоугольники/подписи) — интерактив; часть может не покрыться Playwright достоверно → отметить наблюдением.
- S8.9 — AI-описание стратегии → блоки: редактор стратегии → AI-панель → **реальный AI-вызов** (провайдер `deepseek-v4-pro` настроен; держать в 1 минимальный запрос).
- S8.11 — панель фоновых бэктестов (значок в шапке, список, лимит 3, автосворачивание).
- S8.12 — вкладки результата бэктеста (Обзор/График/Показатели/Сделки, зоны сделок, клик по сделке, «Запустить торговлю из бэктеста»).
- S8.14 — живой perf (сейчас mock; SLA-графики в Dash есть) — отметить как «инструментовка ✓, live=mock» (PASS WITH NOTES).
- S8.17 — dark-theme contrast (визуальная проверка виджетов/новых блоков — скриншот).
- S8.15 — roll-up: 6 сквозных сценариев уже `[x]` (Шаг 2) → отметить.

**Ф2b остаток:** WS `auth_ok` (открыть страницу с WS — Торговля/Графики, проверить коннект) + BE-TRAD-06 на UI (виджет баланса + paper P&L в сессии + CB в health-виджете двигаются корректно).

**Ф3 — триаж:** найденные `[!]` по severity. critical/medium → фикс **test-first в текущем цикле приёмки** (правило проекта: фиксы в цикле, не в S9); low/косметика → S9-backlog по согласованию с заказчиком. После фиксов — повтор затронутого гейта.
- Уже найдено (минор): SPA-роут `/admin/metrics` рендерит пустой экран без 404 (реальные метрики по backend-ссылке работают) — косметика, кандидат в S9-backlog.

**Ф4 — вердикт Gate:**
1. Отметить все проверенные пункты в `acceptance_checklist.md` (`[x]`/`[!]`), перенести evidence в `Спринты/Sprint_8_Review/screenshots/`.
2. Заполнить «Финальный вердикт» (строки ~530): **PASS** (0 багов ≥ medium) или **PASS WITH NOTES** (баги ≤ medium → в цикл или S9-backlog) + краткий итог.
3. Обновить `README.md` S8R + `project_state.md` (S8R закрыт → готов к Sprint 9).
4. Коммит доков в репо Test (ветка `docs/backlog-006-strategy-builder` — активная docs-линия; **main устарел на 139 коммитов, НЕ базировать на нём**). Коммиты — на русском, ТОЛЬКО по подтверждению заказчика.

## Правила проекта (обязательны)
- Плагин-гейты: после Edit `.py` — pyright-lsp (fallback `py_compile`); после Edit `.ts/.tsx` — typescript-lsp (fallback `tsc --noEmit`); фиксы в `app/trading|circuit_breaker|broker` → `/code-review`. Playwright для UI.
- Два репо: `Develop/` (код, remote moex-terminal) + корень Test (доки/спринты, remote test). Коммиты/push — по явной команде, ветки для обоих репо спрашивать отдельно. Авто-commit/push нельзя.
- Все фиксы — в текущем цикле приёмки, НЕ в S9 (S9 = только развитие после сдачи).
- E2E пользователь sergopipo (пароль стенда `S8Raccept2026!`; реальный пароль — у заказчика).
- Changelog/логи фиксировать сразу; run-log `s8r_acceptance_run_2026-07-26.md` — продолжать вести.
- При приближении лимита сессии — остановиться и спросить.

## Финальная уборка (в конце приёмки, после вердикта)
- Погасить стенд: `pkill -f "uvicorn app.main:app --host 127.0.0.1 --port 8100"` и `pkill -f "vite --port 5173"`.
- Удалить worktree: `cd Develop && git worktree remove --force .claude/worktrees/s8r-acceptance` (в нём gitignored `.env`/копия БД).
- Удалить временный `s8r-evidence/` из корня Test после переноса нужных скриншотов в `screenshots/`.
