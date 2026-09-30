## DEV-AUDIT-077 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `metrics.sharpe_params(tf) -> (bt.TimeFrame, compression, factor)`: D→Days/252, W→Weeks/52, M→Months/12. Внутридневные ТФ → Minutes с compression = минут в баре, фактор = 805×252/мин ТФ (1h = 3381). 805 мин берётся из констант `trading_hours`: окно 10:00–23:50 минус перерыв 18:40–19:05. Неизвестный ТФ → прежнее поведение (Days/252).
- `sharpe_analyzer_kwargs(tf)`: `riskfreerate=0.0` (годовой), `convertrate=True`, `annualize=True`, явный `factor`. Семантику сверил по исходнику `backtrader/analyzers/sharpe.py`: при заданном factor ставка переводится и для внутридневных ТФ.
- engine: ТФ проходит путь `run → _run_isolated → payload → _backtest_child_main → _setup_cerebro`. Параметр по умолчанию `"D"`, поэтому старые вызывающие не затронуты.
- grid: воркер берёт `payload["timeframe"]` (по умолчанию D), `_prepare_grid_workload` кладёт его в payload.
- `metrics.py` сам Sharpe не считает, только читает анализатор, поэтому формула одна.
- Подписи: «Коэфф. Шарпа (годовой)» (MetricsGrid), «Sharpe (год.)» (heatmap), «Коэф. Шарпа (годовой)» (экспорт CSV).

### 2. Файлы
Новый: `backend/tests/unit/test_backtest/test_sharpe_timeframe.py`.
Изменённые: `backend/app/backtest/{metrics,engine,grid,router,export}.py`, `frontend/src/components/backtest/{MetricsGrid,GridSearchHeatmap}.tsx`.

### 3. Тесты
- RED: `AssertionError: (Decimal('7.0623'), Decimal('7.0623'))` / `assert 7.0623 == 3.208097534365188 ± 0.0032081` (D и W дали одинаковый Sharpe). Итог: 14 failed, 2 passed. Два прошедших — регресс D (эталон 7.0623 снят с кода до фикса).
- GREEN: 16 passed.
- Мутация `sharpe_params(timeframe)` → `sharpe_params("D")` в `sharpe_analyzer_kwargs`: `assert 7.0623 == 3.208097534365188 ± 0.0032081`, 1h `assert 26.4271 == 25.868…`. Откат через бэкап, md5 совпал.
- Гейты: pytest 4408 passed / 3 xfailed / 0 failed; ruff 0; mypy Success (194); bandit 0; typecheck 0; lint 0; build ok; vitest 1005 passed (142 файла).

### 4. Integration points
✅ `engine.py:594`, `engine.py:315/447/825`; `grid.py:382,448`; `router.py:1447`.

### 5. Контракты
Payload grid-воркера и дочернего процесса получил поле `timeframe` (опциональное). API и схемы не менялись, миграции нет.

### 6. Проблемы / предлагаемые правки
- ФТ §4.5, строка «Коэффициент Шарпа»: «По дневным доходностям» → «Годовой, по доходностям таймфрейма бэктеста: D ×√252, W ×√52, M ×√12, внутридневные ×√(баров ТФ в торговом году MOEX = 805 мин × 252 / мин ТФ); безрисковая ставка 0».
- ТЗ §5.3.1 п.7: добавить «`SharpeRatio` настраивается `metrics.sharpe_params(timeframe)` (единый для бэктеста и Grid Search), `convertrate=True, annualize=True`». ТЗ стр. ~2248: «(по дневным доходностям)» → «(годовой, по ТФ бэктеста)».
- Grid-строки, посчитанные до правки, остались с «дневной» аннуализацией. Бэктесты W/M/intraday в БД тоже хранят старый Sharpe, пересчёта нет.
- Самопроверка: пункты 1, 2, 4, 6 неприменимы (нет БД-записей, уведомлений, таймаутов, клиентских ресурсов). Пункт 3: тест идёт через реальный `BacktestEngine.run` с дочерним процессом, путь без ТФ покрыт отдельно. Пункт 5: `_setup_cerebro`/`_run_isolated` вызываются только из engine, default сохраняет поведение.

### 7. Применённые Stack Gotchas
21 (pickle-friendly payload, ТФ строкой), 30 (патч inline-импорта `MarketDataService`), 60 (`tsc -b`).

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile по всем .py; pnpm typecheck; context7 не понадобился — сверка по исходнику backtrader в venv; tdd — скилл `mattpocock-skills:tdd`.
