# Предполётная проверка — Спринт 4

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
| 2.1 | Ветка develop активна | `git branch --show-current` в Develop/ | develop | [ ] |
| 2.2 | Рабочая директория чистая | `git status --porcelain` | Пусто | [ ] |
| 2.3 | CLAUDE.md существует | Проверка файла | Файл есть | [ ] |

## 3. Sprint 1 + Sprint 2 + Sprint 3 завершены

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 3.1 | Backend тесты проходят | `cd backend && pytest tests/ -v` | 0 failures, ≥244 tests | [ ] |
| 3.2 | Frontend тесты проходят | `cd frontend && pnpm test` | 0 failures, ≥76 tests | [ ] |
| 3.3 | Auth работает | `GET /api/v1/health` → 200 | status: ok | [ ] |
| 3.4 | Broker adapter работает | Модуль `app.broker` импортируется | OK | [ ] |
| 3.5 | Market data работает | Модуль `app.market_data` импортируется | OK | [ ] |
| 3.6 | Strategy API работает | Модуль `app.strategy` импортируется | OK | [ ] |
| 3.7 | Code Generator работает | Модуль `app.strategy.code_generator` импортируется | OK | [ ] |
| 3.8 | Code Sandbox работает | Модуль `app.sandbox` импортируется | OK | [ ] |
| 3.9 | CSRF middleware активен | CSRF middleware в `app.main` | OK | [ ] |
| 3.10 | Rate Limiting активен | Rate Limiting middleware в `app.main` | OK | [ ] |

## 4. Зависимости S4 устанавливаются

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 4.1 | Backtrader доступен | `pip install backtrader --dry-run` | OK (no errors) | [ ] |
| 4.2 | anthropic SDK доступен | `pip install anthropic --dry-run` | OK | [ ] |
| 4.3 | openai SDK доступен | `pip install openai --dry-run` | OK | [ ] |
| 4.4 | httpx-sse доступен | `pip install httpx-sse --dry-run` | OK | [ ] |
| 4.5 | sse-starlette доступен | `pip install sse-starlette --dry-run` | OK | [ ] |
| 4.6 | websockets доступен | `pip install websockets --dry-run` | OK | [ ] |
| 4.7 | @tanstack/react-table (npm) | `pnpm add @tanstack/react-table --dry-run` в frontend/ | OK | [ ] |
| 4.8 | lightweight-charts (npm) | Уже установлен (S2) | OK | [ ] |

## 5. Промпты на месте

| # | Файл | Нужен для | Статус |
|---|------|-----------|--------|
| 5.1 | prompt_UX.md | UX-агент | [ ] |
| 5.2 | prompt_DEV-1_ai_service.md | DEV-1 | [ ] |
| 5.3 | prompt_DEV-2_ai_chat_api.md | DEV-2 | [ ] |
| 5.4 | prompt_DEV-3_backtest_engine.md | DEV-3 | [ ] |
| 5.5 | prompt_DEV-4_backtest_api.md | DEV-4 | [ ] |
| 5.6 | prompt_DEV-5_ai_sidebar.md | DEV-5 | [ ] |
| 5.7 | prompt_DEV-6_backtest_ui.md | DEV-6 | [ ] |
| 5.8 | prompt_QA.md | QA | [ ] |
| 5.9 | prompt_ARCH_review.md | ARCH | [ ] |
| 5.10 | README.md | Описание спринта | [ ] |
| 5.11 | execution_order.md | Порядок выполнения | [ ] |
| 5.12 | preflight_checklist.md | Этот файл | [ ] |
| 5.13 | sprint_state.md | Трекер прогресса | [ ] |
| 5.14 | sprint_report_template.md | Шаблон отчёта | [ ] |

## 6. Зависимости МЕЖДУ агентами внутри спринта

| Агент | Волна | Зависимости | Файлы-артефакты | Проверка перед запуском |
|-------|-------|-------------|-----------------|------------------------|
| **UX** | 0 | Нет | prompt_UX.md | Промпт на месте |
| **DEV-1** | 1 | Нет | prompt_DEV-1_ai_service.md | Промпт на месте |
| **DEV-3** | 1 | Нет | prompt_DEV-3_backtest_engine.md | Промпт на месте |
| **DEV-2** | 2 | **DEV-1 (AI Service смержен)** | prompt_DEV-2_ai_chat_api.md | DEV-1 в develop, pytest проходит |
| **DEV-4** | 2 | **DEV-3 (Backtest Engine смержен)** | prompt_DEV-4_backtest_api.md | DEV-3 в develop, pytest проходит |
| **DEV-5** | 2 | **UX (ui_spec_s4.md) + DEV-1 (AI Service смержен)** | prompt_DEV-5_ai_sidebar.md | ui_spec_s4.md утверждён, DEV-1 в develop |
| **DEV-6** | 2 | **UX (ui_spec_s4.md) + DEV-3 (Backtest Engine смержен)** | prompt_DEV-6_backtest_ui.md | ui_spec_s4.md утверждён, DEV-3 в develop |

### Блокирующие правила

```
ПРАВИЛО 1: DEV-2 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ Код DEV-1 (AI Service) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 2: DEV-4 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ Код DEV-3 (Backtest Engine) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 3: DEV-5 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ ui_spec_s4.md существует в Sprint_4/
  ✓ Заказчик явно утвердил ui_spec_s4.md
  ✓ Код DEV-1 (AI Service) смержен в develop

ПРАВИЛО 4: DEV-6 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ ui_spec_s4.md существует в Sprint_4/
  ✓ Заказчик явно утвердил ui_spec_s4.md
  ✓ Код DEV-3 (Backtest Engine) смержен в develop
  ✓ pnpm test = 0 failures на develop

ПРАВИЛО 5: QA НЕ ЗАПУСКАЕТСЯ пока:
  ✓ ВСЕ DEV-агенты завершили работу и смержены в develop

ПРАВИЛО 6: ARCH НЕ ЗАПУСКАЕТСЯ пока:
  ✓ QA завершил E2E-тесты
  ✓ Весь код доступен для чтения
```

---

## Процедура выполнения preflight

1. Оркестратор (Claude) **автоматически** выполняет проверки 1-5
2. Результат выводится в формате:

```
═══════════════════════════════════════════
  PREFLIGHT CHECK — Sprint 4
═══════════════════════════════════════════

  [✓] Python 3.11.x
  [✓] Node 20.x.x
  [✓] pnpm 9.x.x
  [✓] Git 2.x.x
  [✓] Git repo OK (develop branch, clean)
  [✓] Sprint 1+2+3 tests: 320+ passed, 0 failed
  [✓] Strategy API, CodeGen, Sandbox — OK
  [✓] Backtrader installable
  [✓] anthropic SDK installable
  [✓] openai SDK installable
  [✓] All 14 prompt/doc files present

  RESULT: ALL CHECKS PASSED — Sprint 4 ready to launch

═══════════════════════════════════════════
```

3. Заказчик видит результат и даёт команду на запуск (или устраняет блокеры).
