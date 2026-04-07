# Промежуточное ревью после Sprint 4

> **Milestone M2: Бэктест**
> Охватывает: Sprint 3 (Стратегии + Редактор) + Sprint 4 (AI + Бэктестинг)

## Цель

Ревью кода и бэклог доработок по итогам реализации стратегий, Blockly-редактора, AI-ассистента и движка бэктестинга.

## Что реализовано к этому моменту

### Sprint 1 (Фундамент)
- Auth (регистрация, JWT, брутфорс-защита)
- DB (23+ моделей, Alembic миграции)
- Layout (header, sidebar, footer, dark theme)

### Sprint 2 (Данные и графики)
- T-Invest Broker Adapter (gRPC, rate limiter)
- MOEX ISS Client (REST, calendar, fallback)
- CryptoService (AES-256-GCM для API-ключей)
- Market Data Service (кеш, OHLCV)
- Графики (TradingView Lightweight Charts)
- Настройки брокера, динамический footer

### Sprint 3 (Стратегии + Редактор)
- Strategy CRUD (API + UI)
- Blockly-редактор стратегий (блочный визуальный конструктор)
- Code Generator (блоки → Python-код для Backtrader)
- RestrictedPython Sandbox (безопасное исполнение пользовательского кода)
- CSRF + Rate Limiting middleware

### Sprint 4 (AI + Бэктестинг)
- AI Service: pluggable providers (Anthropic, OpenAI, DeepSeek, Gemini, Mistral, Groq, Qwen, OpenRouter)
- AI Chat API + SSE streaming + бюджет токенов
- AI Sidebar в Strategy Editor (split 40/60, свайп-анимация)
- Backtest Engine (Backtrader wrapper, metrics, equity, benchmarks)
- Backtest API + WebSocket прогресс
- Backtest UI: 4 вкладки (Обзор, График, Показатели, Сделки)
- Форма запуска бэктеста (модалка с валидацией)
- AI Settings (вкладка в настройках)

**Статистика:** 577 unit-тестов + 18 E2E (0 failures)

## Порядок работы

1. **UI-проверки (Playwright)** → [ui_checklist_s4_review.md](ui_checklist_s4_review.md)
   - Запуск автоматических UI-проверок на реальном приложении
   - 98 проверок: навигация, графики, метрики, таблицы, формы, AI-чат
   - Скриншоты сохраняются в `e2e/screenshots/s4-review/`
   - При обнаружении ❌ → исправление → повторный прогон

2. **Актуализация ФТ/ТЗ** → `Документация по проекту/`
   - Собрать все изменения за S3+S4 (changelog, sprint_report, решения заказчика)
   - **Также проверить изменения S1+S2** — на Sprint_2_Review документация могла быть обновлена не полностью
   - Обновить `functional_requirements.md` — новые фичи, изменённые сценарии
   - Обновить `technical_specification.md` — новые компоненты, API, архитектурные решения
   - Обновить `development_plan.md` — если добавились/изменились задачи

3. **Ревью кода** → [code_review.md](code_review.md)
   - Пройти чеклист по разделам (архитектура, API, БД, безопасность, финансы, frontend)
   - Включает проверку S3 + S4 компонентов
   - Зафиксировать замечания

4. **Бэклог доработок** → [backlog.md](backlog.md)
   - Улучшения уже реализованного
   - Модификации по результатам проверки заказчиком
   - Баги, обнаруженные при UI-проверках

5. **Выполнение** → [execution_log.md](execution_log.md)
   - Последовательно выполнять задачи из бэклога
   - Фиксировать результат каждой задачи

## Файлы

| Файл | Описание |
|------|----------|
| [ui_checklist_s4_review.md](ui_checklist_s4_review.md) | UI-чеклист: 98 проверок Playwright на реальном приложении |
| [code_review.md](code_review.md) | Чеклист ревью кода S3+S4 |
| [backlog.md](backlog.md) | Бэклог доработок |
| [execution_log.md](execution_log.md) | Лог выполнения |

## Предыдущее ревью

Sprint_2_Review/ — после Sprint 1 + Sprint 2
