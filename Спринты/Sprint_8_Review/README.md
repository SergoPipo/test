# Финальное ревью после Sprint 8

> ## ✅ ЗАКРЫТО 2026-07-26 — вердикт **PASS WITH NOTES**
>
> Приёмка выполнена на консолидированной ветке `s8r/bug-31-unified-codegen` (P0 + P1 + auth-hardening + BE-TRAD-06), на изолированном стенде (worktree `s8r-acceptance`, копия рабочей БД, backend :8100 / frontend :5173). UI-секции S8.1–S8.12 пройдены через Playwright со скриншотами-evidence.
>
> **Технический гейт (после фиксов цикла):** backend pytest **2186 passed, 1 xfailed, 0 failed** · frontend vitest **765 passed** · typecheck **0** (тогда проверялось командой без учёта project references, которая ничего не проверяет; актуальный гейт — `pnpm typecheck` = `tsc -b`, gotcha-60) · `eslint --max-warnings 0` **0** · bandit **0 medium+**.
>
> **Исправлено прямо в цикле приёмки (TDD):** `BUG-32` (HIGH — AI-помощник не работал: SSE-клиент не слал `X-CSRF-Token` → 403), `FIND-06` (MEDIUM — Alembic игнорировал `DATABASE_URL`, миграции уходили не в ту БД; грабля деплоя S9), `FIND-01` (LOW — капитал не переносился из бэктеста в модалку запуска торговли).
>
> **Дозакрытие 2026-07-27** (визуальная проверка заказчиком пункта S8.8 «Изменение формы»): `BUG-33` (HIGH — после `attachPrimitive` не запрашивалась перерисовка, фигуры разметки не рисовались до первого движения мыши и «исчезали» после F5), `BUG-34` (MEDIUM — перетаскивание точки работало только у уже выделенной фигуры, иначе захват уходил в панорамирование графика). Оба исправлены и перепроверены; гейты после фиксов: vitest **772 passed**, typecheck 0, eslint 0.
>
> **Открытых багов severity ≥ medium нет.** Остаток — 6 косметических замечаний (кандидаты в S9-backlog) и 2 пункта, требующие прод-условий: живые p50/p95 «сигнал→ордер» под нагрузкой и повтор S8.7 «реальная сделка → 3 канала» в торговые часы.
>
> Артефакты: [acceptance_checklist.md](acceptance_checklist.md) (вердикт внизу) · [s8r_acceptance_run_2026-07-26.md](s8r_acceptance_run_2026-07-26.md) (лог прогона) · [acceptance_execution_plan.md](acceptance_execution_plan.md) (план) · [screenshots/](screenshots/) (evidence).
>
> **Следующий шаг (обновлено 2026-10-01, S8R-AUDIT-052):** Sprint 9 **не стартует** — по решению заказчика (2026-06-11) S9 только развитие после сдачи; все фиксы и доводки до деплоя идут циклами S8R. Текущий цикл — фиксы аудита 2026-09 (`audit_2026-09.md`): BLOCKER, HIGH, MEDIUM смёржены в develop (PR #28–#31), идёт пакет LOW; состояние — [fixes_progress.md](fixes_progress.md), остаток до деплоя — [pre_deploy_checklist.md](pre_deploy_checklist.md), точка входа проекта — `Спринты/project_state.md`.

> **Milestone M4: Production-ready (по коду)**
> Охватывает: Sprint 7 (Should-фичи + Полировка) + Sprint 8 (Стабилизация)
>
> **Решение от 2026-05-14:** ревью = ручная приёмка реализации на текущем dev-окружении. ~~Перевод в продуктив вынесен в Sprint 9~~ — **изменено 2026-06-11:** доведение до деплоя (Docker, backup, гайд по деплою) выполняется в циклах S8R; Sprint 9 — только развитие после сдачи.

## Цель

Проверить корректность всей реализации S7+S8 (M4 Production-ready по коду) живым кликом на dev-окружении (`./scripts/start.sh`, localhost). Найденные баги фиксятся в `s8/sprint-8` ветке (как в W4/W5). Gate ревью — вердикт PASS / PASS WITH NOTES / NEED FIXES (получен 2026-07-26: PASS WITH NOTES); дальше — циклы доведения S8R.

**Не в scope приёмки 2026-07-26** (закрывается циклами S8R до деплоя, см. `pre_deploy_checklist.md`):
- Развёртывание на Mac mini (Docker, LAN, backup, launchd) — `deployment_guide.md`.
- Canary-инстанс, deploy.sh, watchdog.
- Перенос БД из dev-окружения в Docker volume.

## Что реализовано к этому моменту

### Sprints 1-6 (M1-M3)
_См. Sprint_6_Review/README.md — полный список реализованного до S7._

### Sprint 7 (Should-фичи + Полировка)
Интерактивные зоны сделок и аналитика P&L, фоновые и параллельные бэктесты, версионирование стратегий, grid-search, AI слэш-команды, мастер первого запуска — `Спринты/Sprint_7/`, ФТ §19.

### Sprint 8 (Стабилизация)
Ресурсы и наблюдаемость, health-виджеты, admin-раздел, гигиена безопасности, UI-чеклист S8 — `Спринты/Sprint_8/`, `ui_checklist_s8.md`.

**Статистика** (develop `7b2eaf3`, 2026-10-01): backend pytest 4622 passed / 3 xfailed / 0 failed (CI), coverage-гейт ≥ 80 %; frontend vitest 1017 passed; E2E Playwright 172/0/0; UI-чеклист S8 — 300 пунктов. Аудит 2026-09: 101 карточка (BLOCKER/HIGH/MEDIUM закрыты, LOW — в работе) + находки цикла S8R-FIX-001…049.

## Порядок работы

1. **Ручная приёмка** → [acceptance_checklist.md](acceptance_checklist.md) — главный артефакт ревью.
   - Шаг 0: Pre-flight (запускается ли dev-окружение).
   - Шаг 1: Smoke по основным страницам.
   - Шаг 2: 6 сквозных сценариев (S8.15 из ui_checklist_s8).
   - Шаг 3: 17 секций / 136 пунктов ui_checklist_s8.
   - Шаг 4: Финальный отчёт в `acceptance_report.md`.

2. **Реактивные багфиксы** при находках lethal/critical → коммит в `s8/sprint-8` ветку (тэг `S8R-ACCEPTANCE-FIX-*`).

3. **Backlog находок** medium/low → накапливается в [backlog.md](backlog.md) и либо закрывается в текущем S8 (как W4/W5), либо переносится в Sprint 9.

4. **Подпись отчёта** [acceptance_report.md](acceptance_report.md) — вердикт PASS / PASS WITH NOTES / NEED FIXES. Это gate перед Sprint 9.

## Файлы

| Файл | Описание |
|------|----------|
| [acceptance_checklist.md](acceptance_checklist.md) | **Главный артефакт.** Чек-лист приёмки с местом для заметок/багов. Заказчик заполняет вручную. |
| [acceptance_report.md](acceptance_report.md) | Финальный отчёт с вердиктом (создаётся в конце). |
| [backlog.md](backlog.md) | Накопительный backlog: что закрылось в W4/W5 + новые находки. |
| [ui_checklist_s8_review.md](ui_checklist_s8_review.md) | (старая структура; новый смысл переехал в acceptance_checklist.md) |
| [code_review.md](code_review.md) | (старая структура; не используется в новом подходе) |
| [execution_log.md](execution_log.md) | (старая структура) |

## Предыдущее ревью

Sprint_6_Review/ — после Sprint 5 + Sprint 6
