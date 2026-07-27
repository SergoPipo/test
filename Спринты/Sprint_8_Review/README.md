# Финальное ревью после Sprint 8

> ## ✅ ЗАКРЫТО 2026-07-26 — вердикт **PASS WITH NOTES**
>
> Приёмка выполнена на консолидированной ветке `s8r/bug-31-unified-codegen` (P0 + P1 + auth-hardening + BE-TRAD-06), на изолированном стенде (worktree `s8r-acceptance`, копия рабочей БД, backend :8100 / frontend :5173). UI-секции S8.1–S8.12 пройдены через Playwright со скриншотами-evidence.
>
> **Технический гейт (после фиксов цикла):** backend pytest **2186 passed, 1 xfailed, 0 failed** · frontend vitest **765 passed** · `tsc --noEmit` **0** · `eslint --max-warnings 0` **0** · bandit **0 medium+**.
>
> **Исправлено прямо в цикле приёмки (TDD):** `BUG-32` (HIGH — AI-помощник не работал: SSE-клиент не слал `X-CSRF-Token` → 403), `FIND-06` (MEDIUM — Alembic игнорировал `DATABASE_URL`, миграции уходили не в ту БД; грабля деплоя S9), `FIND-01` (LOW — капитал не переносился из бэктеста в модалку запуска торговли).
>
> **Открытых багов severity ≥ medium нет.** Остаток — 6 косметических замечаний (кандидаты в S9-backlog) и 2 пункта, требующие живых условий: resize фигуры на графике глазами и живые p50/p95 «сигнал→ордер» под нагрузкой.
>
> Артефакты: [acceptance_checklist.md](acceptance_checklist.md) (вердикт внизу) · [s8r_acceptance_run_2026-07-26.md](s8r_acceptance_run_2026-07-26.md) (лог прогона) · [acceptance_execution_plan.md](acceptance_execution_plan.md) (план) · [screenshots/](screenshots/) (evidence).
>
> **Следующий шаг:** старт **Sprint 9 «Перевод в продуктив»**.

> **Milestone M4: Production-ready (по коду)**
> Охватывает: Sprint 7 (Should-фичи + Полировка) + Sprint 8 (Стабилизация)
>
> **Решение от 2026-05-14:** ревью = ручная приёмка реализации на текущем dev-окружении. Перевод в продуктив (Mac mini Docker, canary, watchdog, deploy.sh) вынесен в отдельный **Sprint 9 "Перевод в продуктив"**, стартующий после Gate Sprint_8_Review.

## Цель

Проверить корректность всей реализации S7+S8 (M4 Production-ready по коду) живым кликом на dev-окружении (`./scripts/start.sh`, localhost). Найденные баги фиксятся в `s8/sprint-8` ветке (как в W4/W5). Gate ревью — вердикт PASS / PASS WITH NOTES / NEED FIXES — открывает старт Sprint 9.

**Не в scope ревью:**
- Развёртывание на Mac mini (Docker, LAN, backup, launchd) → Sprint 9.
- Canary-инстанс, deploy.sh, watchdog → Sprint 9.
- Перенос БД из dev-окружения в Docker volume → Sprint 9.

## Что реализовано к этому моменту

### Sprints 1-6 (M1-M3)
_См. Sprint_6_Review/README.md — полный список реализованного до S7._

### Sprint 7 (Should-фичи + Полировка)
_Заполняется после завершения Sprint 7._
_Запланировано: интерактивные зоны сделок, аналитика P&L, фоновый запуск бэктестов._

### Sprint 8 (Стабилизация)
_Заполняется после завершения Sprint 8._

**Статистика:** _обновить после завершения S8_

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
