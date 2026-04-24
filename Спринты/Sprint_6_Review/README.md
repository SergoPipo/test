# Промежуточное ревью после Sprint 5 + Sprint 6

> **Milestone M3: Торговля (Paper + Real)**
> Охватывает: Sprint 5 (Trading Engine) + Sprint 5 Review + Sprint 5 Review 2 + Sprint 6 (Уведомления + Security)

## Цель

Ревью кода и бэклог доработок по итогам реализации торгового движка, paper trading, circuit breaker, уведомлений (Telegram/Email/In-app), восстановления сессий и graceful shutdown.

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
- Code Generator (блоки -> Python-код для Backtrader)
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

### Sprint 5 (Торговля) + S5R + S5R-2
- Trading Engine: SessionManager, SignalProcessor, OrderManager, PositionTracker
- Paper Trading: PaperBrokerAdapter (instant fill, PaperPortfolio)
- Circuit Breaker: 9 проверок, per-user asyncio.Lock
- Bond НКД + Tax FIFO + 3-НДФЛ экспорт
- Live Runtime Loop: стрим свечей -> сигнал -> ордер (замкнут в S5R)
- Реальные позиции T-Invest (source через FIGI, S5R closeout)
- 15 Stack Gotchas, 109 Playwright E2E (все на моках)
- Chart hardening: prefetch, sequential-index, 401 fix, TF-aware upsertLiveCandle

### Sprint 6 (Уведомления + Security)
- NotificationService: create_notification, dispatch_external, EventBus bridge
- Telegram Bot: привязка 6-digit token, /positions /status /help /balance /close /closeall
- Email: SMTP через aiosmtplib, авто-TLS (465 SSL / 587 STARTTLS)
- In-app: NotificationBell (badge, WS), NotificationDrawer, CriticalBanner
- NotificationSettingsPage: event_type x канал (Telegram/Email/In-app)
- Recovery: paper + real-сессии (сверка позиций с брокером)
- Graceful Shutdown: sessions -> "suspended", pending orders 30s, notification
- T-Invest SDK upgrade: beta59 -> beta117+, sys.modules stub удалён
- Stream Multiplex: persistent gRPC multiplexer (один стрим на все подписки)
- E2E инфраструктура: playwright-nightly CI, ISS-моки, 105 тестов без backend
- Security тесты: CSRF, rate limiting, sandbox escape, notification ACL/XSS
- Scheduler Service: APScheduler 3.x (sync_moex_calendar, detect_corporate_actions, daily_stats, T+1 unlock)
- Расширенные карточки сессий: позиция, P&L + unrealized, сделки W/L, маркеры на графике
- CB fixes: trading_hours вечерняя сессия, commit после trigger (Gotcha 18), temporary блокировки
- PauseConfirmModal: предупреждение при паузе с открытой позицией
- 18 Stack Gotchas

**Статистика:** 685 backend + 250 frontend + 10 E2E = 945 тестов (0 failures)

## Порядок работы

1. **UI-проверки (Playwright)** -- Автоматические проверки + визуальная верификация
   - Новый функционал S6: уведомления, CriticalBanner, настройки каналов
   - Торговые карточки: P&L, позиции, маркеры на графике
   - При обнаружении проблем -- исправление -- повторный прогон

2. **Актуализация ФТ/ТЗ** -- `Документация по проекту/`
   - Собрать все изменения за S5+S6 (changelog, sprint_report, решения заказчика)
   - Обновить `functional_requirements.md` -- новые фичи S5+S6
   - Обновить `technical_specification.md` -- новые компоненты, API
   - Обновить `development_plan.md` -- статусы задач

3. **Ревью кода** -- [code_review.md](code_review.md)
   - Пройти чеклист по разделам (архитектура, trading engine, notifications, market data, frontend, безопасность, тесты)
   - Включает проверку S5 + S6 компонентов
   - Зафиксировать замечания

4. **Бэклог доработок** -- [backlog.md](backlog.md)
   - Замечания из code_review (критические + средние)
   - Незакрытые задачи из Sprint_4_Review/backlog.md
   - Технический долг, обнаруженный при чтении кода
   - Рекомендации для S7

5. **Выполнение** -- последовательное устранение критических замечаний

## Файлы

| Файл | Описание |
|------|----------|
| [code_review.md](code_review.md) | Чеклист ревью кода S5+S6 |
| [backlog.md](backlog.md) | Бэклог доработок |

## Предыдущие ревью

- Sprint_2_Review/ -- после Sprint 1 + Sprint 2
- Sprint_4_Review/ -- после Sprint 3 + Sprint 4
- Sprint_5_Review/ -- внеплановое ревью S5 (стабилизация)
- Sprint_5_Review_2/ -- chart hardening (5 треков)
