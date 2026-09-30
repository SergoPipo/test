## DEV-AUDIT-094 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- Все 5 джоб получили окно на запоздавший запуск через `job_defaults` планировщика (единый источник: `MISFIRE_GRACE_DAILY_SECONDS=3600`, `coalesce=True`). Раньше у 4 джоб было 1 с.
- `refresh_backtest_jobs_rate` (раз в 5 мин) переопределяет окно на `MISFIRE_GRACE_FREQUENT_SECONDS=600`. Развилка: правило «окно не больше периода» (300 с) противоречит нижней границе 600. Выбрана граница 600: при `coalesce`+`max_instances=1` запоздание всё равно даёт один запуск.
- Удалены `schedule_t1_unlock`, `_execute_t1_unlock`, импорт `DateTrigger`, а также `PaperBrokerAdapter.unblock_settled_funds` (no-op); вызовов в production не было.
- Jobstore оставлен в памяти. Докстринг модуля обновлён: только cron/interval, одноразовые задачи не используются, джобы восстанавливаются из кода.
- Часовые пояса джоб не менялись.

### 2. Файлы
Новый: `backend/tests/unit/test_scheduler/test_audit_s8r_misfire.py`.
Изменены: `backend/app/scheduler/service.py`, `backend/app/trading/paper_engine.py`, `tests/unit/test_scheduler/test_service.py` (−2 теста), `tests/test_routers/test_scheduler_service.py` (−1), `tests/test_trading/test_paper_accounting_be_trad_06.py` (−1).

### 3. Тесты
RED: `AssertionError: misfire_grace_time вне [600, 3600] с: {'refresh_backtest_jobs_rate': 1, 'detect_corporate_actions': 1, 'send_daily_stats': 1, 'sync_moex_calendar': 1}`; `assert not hasattr(SchedulerService, 'schedule_t1_unlock')`.
GREEN: 2 passed.
Мутации:
- удалить `misfire_grace_time` из `job_defaults` → `...{'backup_db_daily': 1, 'detect_corporate_actions': 1, 'send_daily_stats': 1, 'sync_moex_calendar': 1}`;
- удалить переопределение у частой джобы → `окно шире периода interval-джобы: {'refresh_backtest_jobs_rate': (3600, 300.0)}`.
Обе откачены, md5 совпадает.
Гейты: pytest 4514 passed / 3 xfailed / 1 skipped / 0 failed (4516 − 4 удалённых теста T+1 + 2 новых); ruff 0; mypy Success (196); bandit без находок; typecheck 0; lint 0; build ok; vitest: фронт не менялся, запуск на уровне пакета. `grep schedule_t1_unlock app tests`: совпадения только в утверждениях `hasattr` нового теста.

### 4. Integration points
✅ `SchedulerService.__init__` (job_defaults) и `start()`: `add_job` у refresh. Новых функций нет.

### 5. Контракты
API и схемы не менялись, миграции нет.

### 6. Проблемы / предлагаемые правки документов
- **ФТ §17.8**: убрать строку «One-shot: `schedule_t1_unlock` …». Добавить: «Все задачи — cron/interval; jobstore в памяти, при рестарте задачи восстанавливаются из кода. Окно на запоздавший запуск — 1 ч (для 5-минутной задачи — 10 мин), пропуски схлопываются в один запуск. Слоты, пришедшиеся на время остановки процесса, не догоняются (персистентный jobstore — Sprint 9)». Строку истории 2.3 не трогать.
- **ТЗ шапка §3/§5**: убрать «`unblock_settled_funds` → no-op», оставить «инертный T+1 для paper удалён (S8R-AUDIT-094)». **ТЗ ~2669**: «T+1 unblock» → «корп. действия, дневная статистика».
- Новые находки:
  - `misfire_grace_time` не спасает деплой, при котором процесс лежит в момент 00:05/19:00: memory-jobstore при старте считает следующий слот от текущего момента. Это ограничение Sprint 9, в документацию внесено.
  - Устаревшие упоминания T+1: комментарий в `main.py:208` и мёртвый `place_order` в `paper_engine.py:319,353`. Вне карточки.
  - ТЗ §5.9: таблица джоб не совпадает с кодом (там есть `update_moex_sessions`, `cleanup_revoked_tokens` и др.).
- Самопроверка: 1 — записей в БД нет; 2 — уведомлений нет; 3 — тест идёт через реальный `start()`; 4 — не применимо; 5 — вызывающих у удалённых функций нет; 6 — не применимо.

### 7. Применённые Stack Gotchas
—; мутации делал через бэкап файла.

### 8. Новые Stack Gotchas
Кандидат: «APScheduler 3.x `misfire_grace_time` по умолчанию 1 с: запуск молча пропускается, если event loop занят» — `service.py`.

### 9. Плагины
py_compile ok; typecheck — гейт; context7 (APScheduler; в выдаче была v4, дефолты 3.11.2 сверены по исходнику `base.py:909`); TDD — `mattpocock-skills:tdd`.
