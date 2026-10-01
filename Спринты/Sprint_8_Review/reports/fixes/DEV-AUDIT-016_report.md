## DEV-AUDIT-016 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту
### 1. Что реализовано
- Helper `app/common/ownership.py`: `owned_select(...)` и `get_owned_or_404(db, Model, id, user_id, *, detail, owner=, joins=, options=)` — владелец в `WHERE` того же запроса, чужой и несуществующий id дают один `NotFoundError`.
- `StrategyService.get_by_id`: фильтр владельца в SQL, `selectinload(versions)` — только для своей записи. Через него идут все 11 путей `strategy/`.
- `backtest/router`: `_get_version_for_user` и `_get_backtest_for_user` фильтруют по владельцу JOIN'ом `version → strategy` с явным ON (между таблицами два FK). `rerun`: страховочная сверка теперь даёт 404, а не 403.
- `jobs.get(job_id, user_id=)` и `jobs.cancel` — владелец в SQL; `GET /jobs/{id}` передаёт `user_id`.
- `DELETE /price-alerts/{id}` и `chart_drawings._get_owned_or_404` переведены на helper.
- Найдено grep'ом сверх «Где»: `BacktestService._get_strategy_version/_verify_ownership` (get/delete/create; в проде используется только `_save_result`). Тоже на helper, `_verify_ownership` удалён.
- Admin-эндпоинты не тронуты. `ForbiddenError` осталась только в `ai/chat_router` (это лимиты, не владение).
### 2. Файлы
Новые: `backend/app/common/ownership.py`, `backend/tests/test_security/test_idor_oracle.py`.
Изменены: `app/{strategy/service,backtest/router,backtest/service,backtest/jobs,market_data/price_alert_router,chart_drawings/router}.py`. 11 тестов переведены с 403/ForbiddenError на 404/NotFoundError: test_block_allowlist, strategy/test_router, strategy/test_service, test_versioning, backtest/test_api, test_export, test_grid_endpoint, test_router_full, backtest/test_service, test_strategy_router, test_price_alert_router.
### 3. Тесты
RED: 6 failed / 2 passed (jobs и drawings уже были без оракула) — `AssertionError: чужой id → 403 {"detail":"Нет доступа к этой стратегии"}; несуществующий → 404 {"detail":"Стратегия 987654 не найдена"}`. Так же падали бэктест, версия и алерт.
GREEN: `test_foreign_id_and_missing_id_are_indistinguishable` — 8 параметров (strategy, versions/list, backtest trades/equity-curve, strategy-params, jobs, price-alerts, drawings), 8 passed.
Мутация: в `get_by_id` возвращён post-check с `ForbiddenError` → `assert (403, 404) == (404, 404)`. Откат через бэкап, md5 `b4db13a6…` совпал.
Гейты: pytest 4579 passed / 2 xfailed / 0 failed; маркеров 016 нет; ruff 0; mypy Success (197); bandit M0/H0; typecheck 0; lint 0; build ok; vitest: фронт не менялся — снимается на уровне пакета.
### 4. Integration points
✅ `get_owned_or_404`: strategy/service.py:369, backtest/router.py:193/260, backtest/service.py:303/315, price_alert_router.py:79, chart_drawings/router.py:79. ✅ `owned_select`: backtest/jobs.py:376. NOT CONNECTED нет.
### 5. Контракты
Чужой id: 403 → 404 с телом как у несуществующего. Схемы не менялись, миграции нет. Фронт 403 на этих ресурсах не различает (проверен grep `src/`), правок фронта нет.
### 6. Проблемы / предложения
- Предлагаю добавить в ТЗ §7 новый пункт «7.9 Изоляция данных пользователей»: «Записи пользователя (стратегии, версии, бэктесты, фоновые jobs, ценовые оповещения, разметка графиков) выбираются по id с фильтром владельца в том же SQL-запросе (`app/common/ownership.py`). Чужой и несуществующий id → одинаковый 404, оракула существования нет (S8R-AUDIT-016). 403 — только admin-доступ, CSRF/Origin и лимиты.» ФТ §3.5/§12.8 правок не требуют.
- Новая находка (info): `ws_backtest.py:61-72` сверяет владельца после выборки, но оракула нет — в обоих случаях close 4403. Не трогал.
- Самопроверка: 1) только чтения, коммит-путей нет; 2) уведомлений нет; 3) тест идёт через HTTP и реальный SQL; 4) таймаутов нет; 5) все вызывающие проверены — чужой id теперь 404 везде; 6) n/a.
### 7. Применённые Stack Gotchas
gotcha-60 (`tsc -b`), gotcha-58 (без `populate_existing`), gotcha-20 (порядок путей).
### 8. Новые Stack Gotchas
Нет. JOIN `strategies↔strategy_versions` без ON неоднозначен — это зафиксировано комментарием в коде.
### 9. Плагины
py_compile по всем .py; typecheck 0; context7 (`Select.join` onclause + `selectinload`); TDD — `mattpocock-skills:tdd`.
