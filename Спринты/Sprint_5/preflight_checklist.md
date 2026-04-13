# Предполётная проверка — Спринт 5

> Этот чеклист выполняется **ДО** запуска любого агента в спринте.
> Если хотя бы один пункт не выполнен — спринт НЕ НАЧИНАЕТСЯ.
> Оркестратор (Claude) выполняет проверки автоматически и сообщает результат.

---

## 1. Системные требования (проверяет оркестратор автоматически)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 1.1 | Python установлен | `python3 --version` | >= 3.11 | [ ] |
| 1.2 | Node.js установлен | `node --version` | >= 18 | [ ] |
| 1.3 | pnpm установлен | `pnpm --version` | >= 9 | [ ] |
| 1.4 | Git установлен | `git --version` | any | [ ] |
| 1.5 | pip доступен | `python3 -m pip --version` | any | [ ] |

## 2. Состояние репозитория

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 2.1 | Ветка s5/trading активна | `git branch --show-current` | s5/trading | [ ] |
| 2.2 | Рабочая директория чистая | `git status --porcelain` в Develop/ | Пусто или только новые файлы | [ ] |
| 2.3 | CLAUDE.md существует | Проверка Develop/CLAUDE.md | Файл есть | [ ] |

## 3. Sprint 1–4 завершены

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 3.1 | Backend тесты проходят | `cd backend && pytest tests/ -v` | 0 failures, ≥577 tests | [ ] |
| 3.2 | Frontend тесты проходят | `cd frontend && pnpm test` | 0 failures | [ ] |
| 3.3 | Auth работает | Модуль `app.auth` импортируется | OK | [ ] |
| 3.4 | Broker adapter работает | Модуль `app.broker` импортируется | OK | [ ] |
| 3.5 | Market Data работает | Модуль `app.market_data` импортируется | OK | [ ] |
| 3.6 | Strategy + CodeGen работает | Модуль `app.strategy.code_generator` импортируется | OK | [ ] |
| 3.7 | Code Sandbox работает | Модуль `app.sandbox` импортируется | OK | [ ] |
| 3.8 | Backtest Engine работает | Модуль `app.backtest` импортируется | OK | [ ] |
| 3.9 | AI Service работает | Модуль `app.ai` импортируется | OK | [ ] |
| 3.10 | CSRF middleware активен | Проверка `app.middleware` | OK | [ ] |
| 3.11 | WebSocket /ws работает | Модуль `app.backtest.ws` импортируется | OK | [ ] |
| 3.12 | Event Bus работает | Модуль `app.common.event_bus` импортируется | OK | [ ] |

## 4. Зависимости S5 — новое ПО

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 4.1 | tinkoff-investments SDK | `python3 -c "import tinkoff.invest"` | OK (уже установлен из S2) | [ ] |
| 4.2 | grpcio (для streaming) | `python3 -c "import grpc"` | OK (зависимость tinkoff SDK) | [ ] |
| 4.3 | openpyxl (xlsx экспорт) | `python3 -c "import openpyxl"` | OK (установить если нет) | [ ] |
| 4.4 | APScheduler (scheduler) | `python3 -c "import apscheduler"` | OK (для MOEX-календаря) | [ ] |
| 4.5 | Backtrader | `python3 -c "import backtrader"` | OK (уже из S4) | [ ] |
| 4.6 | lightweight-charts (npm) | Уже установлен (S2) | OK | [ ] |
| 4.7 | @tanstack/react-table | Уже установлен (S4) | OK | [ ] |

## 5. Существующие модели и заглушки S5

| # | Проверка | Файл | Ожидание | Статус |
|---|----------|------|----------|--------|
| 5.1 | Trading модели | `app/trading/models.py` | TradingSession, LiveTrade, PaperPortfolio, DailyStat | [ ] |
| 5.2 | Trading заглушки | `app/trading/router.py`, `service.py`, `schemas.py` | Файлы существуют (пустые/заглушки) | [ ] |
| 5.3 | CircuitBreaker модель | `app/circuit_breaker/models.py` | CircuitBreakerEvent | [ ] |
| 5.4 | Broker base | `app/broker/base.py` | BaseBrokerAdapter (ABC) | [ ] |
| 5.5 | T-Invest adapter | `app/broker/tinvest/adapter.py` | 6 stub-методов (NotImplementedError) | [ ] |
| 5.6 | Rate limiter | `app/broker/tinvest/rate_limiter.py` | TokenBucketRateLimiter (in-memory) | [ ] |
| 5.7 | CorporateAction | `app/corporate_actions/models.py` | Модель существует | [ ] |
| 5.8 | Event Bus | `app/common/event_bus.py` | EventBus singleton | [ ] |

## 6. Prompt-файлы на месте

| # | Файл | Нужен для | Статус |
|---|------|-----------|--------|
| 6.1 | prompt_UX.md | UX-агент | [ ] |
| 6.2 | prompt_DEV-1.md | DEV-1 (Trading Engine + Broker) | [ ] |
| 6.3 | prompt_DEV-2.md | DEV-2 (Circuit Breaker) | [ ] |
| 6.4 | prompt_DEV-3.md | DEV-3 (Bond + Tax) | [ ] |
| 6.5 | prompt_DEV-4.md | DEV-4 (Trading Panel UI) | [ ] |
| 6.6 | prompt_DEV-5.md | DEV-5 (Account + Favorites) | [ ] |
| 6.7 | prompt_ARCH_review.md | ARCH ревью | [ ] |
| 6.8 | execution_order.md | Порядок выполнения | [ ] |
| 6.9 | preflight_checklist.md | Этот файл | [ ] |
| 6.10 | sprint_state.md | Трекер прогресса | [ ] |
| 6.11 | changelog.md | Лог изменений | [ ] |

## 7. Зависимости МЕЖДУ агентами внутри спринта

| Агент | Волна | Зависимости | Проверка перед запуском |
|-------|-------|-------------|------------------------|
| **UX** | 1 | Нет | Промпт на месте |
| **DEV-1** | 1 | Нет | Промпт на месте |
| **DEV-3** | 1 | Нет | Промпт на месте |
| **DEV-2** | 2 | **DEV-1 завершён** | Trading Engine в коде, pytest = 0 failures |
| **DEV-4** | 3 | **DEV-1 + UX завершены** | API endpoints работают, ui_spec_s5.md утверждён |
| **DEV-5** | 3 | **DEV-3 + UX завершены** | Tax/Bond API работают, ui_spec_s5.md утверждён |
| **ARCH** | 4 | **Все DEV завершены** | Весь код смержен, все тесты проходят |

### Блокирующие правила

```
ПРАВИЛО 1: DEV-2 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ Код DEV-1 (Trading Engine) готов
  ✓ pytest tests/ = 0 failures

ПРАВИЛО 2: DEV-4 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ Код DEV-1 (Trading API endpoints) готов
  ✓ UX: ui_spec_s5.md утверждён заказчиком
  ✓ pytest tests/ = 0 failures

ПРАВИЛО 3: DEV-5 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ Код DEV-3 (Bond + Tax API) готов
  ✓ UX: ui_spec_s5.md утверждён заказчиком
  ✓ pnpm test = 0 failures

ПРАВИЛО 4: ARCH НЕ ЗАПУСКАЕТСЯ пока:
  ✓ ВСЕ DEV-агенты завершили работу
  ✓ pytest + pnpm test = 0 failures
  ✓ Все миграции применены (alembic upgrade head)
```

---

## Процедура выполнения preflight

1. Оркестратор (Claude) **автоматически** выполняет проверки 1–6
2. Результат выводится в формате:

```
═══════════════════════════════════════════
  PREFLIGHT CHECK — Sprint 5
═══════════════════════════════════════════

  [✓] Python 3.11.x
  [✓] Node 20.x.x
  [✓] pnpm 9.x.x
  [✓] Git 2.x.x
  [✓] Git repo OK (s5/trading branch)
  [✓] Sprint 1-4 tests: 577+ passed, 0 failed
  [✓] All modules importable (auth, broker, strategy, backtest, ai, sandbox)
  [✓] tinkoff-investments SDK installed
  [✓] openpyxl installed
  [✓] Trading models present (4 models)
  [✓] All 11 sprint files present

  RESULT: ALL CHECKS PASSED — Sprint 5 ready to launch

═══════════════════════════════════════════
```

3. Заказчик видит результат и даёт команду на запуск (или устраняет блокеры).
