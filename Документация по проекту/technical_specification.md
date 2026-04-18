---

# ТЕХНИЧЕСКОЕ ЗАДАНИЕ (ТЗ)
## Торговый терминал для рынка ценных бумаг РФ (MOEX)

**Версия:** 1.1  
**Дата:** 2026-04-07  
**Основание:** Функциональные требования v2.1 от 2026-04-07  
**Статус:** Актуализирован по результатам Sprint 4 Review

---

## СОДЕРЖАНИЕ

- Глоссарий
1. Стек технологий
2. Системная архитектура
3. Схема базы данных
4. API-контракты
5. Backend-модули
6. Frontend-модули
7. Реализация безопасности
8. Развёртывание и эксплуатация
9. Стратегия тестирования
10. Фазы разработки

---

## ГЛОССАРИЙ

| Термин | Определение |
|---|---|
| Circuit Breaker | Механизм автоматического ограничения торговли при превышении лимитов риска |
| Paper Trading | Виртуальная торговля на реальных рыночных данных без реальных денежных средств |
| Equity Curve | Кривая изменения капитала стратегии во времени |
| Slippage (проскальзывание) | Разница между ожидаемой и фактической ценой исполнения ордера |
| НКД | Накопленный купонный доход по облигации |
| OHLCV | Open, High, Low, Close, Volume — стандартный формат свечных данных |
| Cooldown | Минимальный интервал между двумя сигналами входа одной стратегии |
| Drawdown (просадка) | Снижение капитала от пикового значения (в % или абсолютном выражении) |
| T+1 | Режим расчётов на MOEX: поставка ценных бумаг на следующий торговый день |
| Profit Factor | Отношение суммы прибылей к сумме убытков по всем сделкам |
| Sharpe Ratio | Коэффициент Шарпа — мера доходности с поправкой на риск |
| Win Rate | Доля прибыльных сделок от общего числа сделок (в %) |
| MOEX ISS | Информационно-статистический сервер Московской биржи (публичное API) |

---

## 1. СТЕК ТЕХНОЛОГИЙ

**Ответственный: OPS + все специалисты (ревью)**

### 1.1 Backend

| Компонент | Технология | Версия | Обоснование |
|---|---|---|---|
| Язык | Python | 3.11+ | Минимум 3.10 (ФТ), рекомендуется 3.11+ для `asyncio.TaskGroup` и улучшенной производительности. CI тестирует на 3.10 и 3.11+ |
| Web-фреймворк | FastAPI | 0.110+ | Async-native, авто-генерация OpenAPI, WebSocket поддержка, высокая производительность |
| ASGI-сервер | Uvicorn | 0.29+ | Стандарт для FastAPI, поддержка HTTP/WS |
| ORM | SQLAlchemy | 2.0+ | Зрелая ORM с поддержкой SQLite и PostgreSQL; async через asyncio extension |
| Миграции | Alembic | 1.13+ | Стандарт для SQLAlchemy, обратимые миграции, авто-генерация |
| СУБД (фаза 1) | SQLite | 3.40+ | Нулевая конфигурация для локального deploy; WAL-режим для конкурентного чтения |
| Бэктестинг | Backtrader | 1.9.78+ | Требование ФТ; зрелая библиотека стратегий |
| Технические индикаторы | TA-Lib (обёртка: ta-lib python) | 0.4.28+ | Широкий набор индикаторов, C-оптимизация |
| Брокер gRPC | grpcio + tinkoff-investments | 0.2.0+ (tinkoff SDK) | Официальный SDK T-Invest API |
| Задачи по расписанию | APScheduler | 3.10+ | In-process планировщик, не требует внешних зависимостей |
| Хеширование паролей | Argon2id (argon2-cffi) | 23.1+ | Рекомендация OWASP, winner PHC |
| Шифрование | cryptography (Fernet / AES-256-GCM) | 42.0+ | AES-256-GCM для API-ключей |
| JWT | PyJWT | 2.8+ | Компактный, проверенный |
| Sandbox | RestrictedPython | 7.0+ | Ограничение исполнения пользовательского кода |
| Telegram | python-telegram-bot | 21.0+ | Async, поддержка inline-кнопок, webhook |
| HTTP-клиент | httpx | 0.27+ | Async, для MOEX ISS и AI-провайдеров |
| Валидация | Pydantic | 2.6+ | Нативная интеграция с FastAPI |
| Логирование | structlog | 24.1+ | Структурированные логи (JSON), контекстное логирование |
| Данные | pandas | 2.2+ | Манипуляция OHLCV, интеграция с Backtrader |
| Научные вычисления | numpy | 1.26+ | Зависимость pandas/Backtrader/TA-Lib |
| PDF-отчёты | WeasyPrint | 62.0+ | Генерация PDF из HTML-шаблонов (бэктест-отчёт) |
| Excel-экспорт | openpyxl | 3.1+ | Генерация xlsx (налоговый отчёт, журнал сделок) |

### 1.2 Frontend

| Компонент | Технология | Версия | Обоснование |
|---|---|---|---|
| Фреймворк | React | 18.3+ | Обширная экосистема, совместимость с Blockly |
| Язык | TypeScript | 5.4+ | Типизация снижает баги в сложном UI |
| Сборщик | Vite | 5.4+ | Скорость HMR, ESM-native |
| UI-библиотека | Mantine | 7.8+ | Готовые dark-theme компоненты, таблицы, формы; русская локализация |
| Графики | TradingView Lightweight Charts | 4.1+ | Требование ФТ; MIT, canvas, производительность |
| Блочный редактор | Google Blockly | 11.0+ | Требование ФТ; drag-and-drop, кастомные блоки |
| Состояние | Zustand | 4.5+ | Минималистичный, без boilerplate |
| Маршрутизация | React Router | 6.22+ | Стандарт для React SPA |
| HTTP-клиент | Axios | 1.7+ | Интерцепторы для JWT, отмена запросов |
| WebSocket | Нативный WebSocket + reconnecting-websocket | 4.4+ | Авто-переподключение |
| Таблицы | TanStack Table | 8.15+ | Виртуализация, сортировка, фильтрация |
| Код (отображение) | Monaco Editor (read-only) или react-syntax-highlighter | latest | Подсветка Python-кода стратегии |
| Иконки | Tabler Icons | 3.1+ | Бесплатные, SVG |
| Уведомления (toast) | Mantine Notifications | 7.8+ | Интеграция с Mantine |

### 1.3 Инфраструктура

| Компонент | Технология | Версия | Обоснование |
|---|---|---|---|
| Менеджер зависимостей (Python) | pip + venv (или Poetry) | — | Стандартный Python workflow, без внешних зависимостей |
| Менеджер зависимостей (Frontend) | pnpm | 9.0+ | Быстрый, экономит дисковое пространство |
| Запуск приложения | Скрипт `start.sh` / `start.bat` | — | Единый скрипт запуска backend + frontend (build → serve) |
| Process manager (опционально) | Honcho / Foreman | — | Запуск backend + frontend в одном терминале через Procfile |
| CI (рекомендация) | GitHub Actions | — | Стандарт для open-source workflow |

> **Примечание:** Docker **не используется** в фазе 1. Приложение устанавливается и запускается нативно на машине пользователя через Python venv + pip и pnpm. Это упрощает установку для нетехнического пользователя и снижает системные требования. При необходимости Docker может быть добавлен в фазе 2 для упрощения развёртывания в продакшн.

---

## 2. СИСТЕМНАЯ АРХИТЕКТУРА

**Ответственный: ARCH (определяет), все специалисты (реализация)**

### 2.1 Общая архитектура — монолит с модульным разделением

Фаза 1 реализуется как монолитное приложение с чётким модульным разделением. Каждый модуль — отдельный Python-пакет с определённым public API. Границы модулей проектируются так, чтобы в фазе 2 при необходимости можно было выделить их в микросервисы без переписывания бизнес-логики.

```
moex-terminal/
├── backend/
│   ├── app/
│   │   ├── main.py                  # FastAPI application factory
│   │   ├── config.py                # Pydantic Settings (env)
│   │   ├── dependencies.py          # FastAPI dependency injection
│   │   ├── middleware/
│   │   │   ├── auth.py              # JWT verification middleware
│   │   │   ├── rate_limit.py        # Rate limiter
│   │   │   └── csrf.py              # CSRF protection
│   │   ├── auth/                    # Модуль аутентификации
│   │   │   ├── router.py
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   └── models.py
│   │   ├── strategy/                # Модуль стратегий
│   │   │   ├── router.py
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   ├── models.py
│   │   │   ├── block_parser.py      # Шаблон → блоки (режим B)
│   │   │   └── code_generator.py    # Блоки → Python/Backtrader
│   │   ├── backtest/                # Модуль бэктестинга
│   │   │   ├── router.py
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   ├── models.py
│   │   │   └── engine.py            # Backtrader wrapper
│   │   ├── trading/                 # Модуль торговли
│   │   │   ├── router.py
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   ├── models.py
│   │   │   ├── order_manager.py
│   │   │   ├── position_tracker.py
│   │   │   └── paper_engine.py      # Paper trading
│   │   ├── broker/                  # Брокерский адаптер
│   │   │   ├── base.py              # Абстрактный интерфейс
│   │   │   ├── factory.py           # Фабрика адаптеров
│   │   │   ├── tinvest/             # T-Invest реализация
│   │   │   │   ├── adapter.py
│   │   │   │   ├── grpc_client.py
│   │   │   │   ├── stream_manager.py
│   │   │   │   └── mappers.py
│   │   │   └── moex_iss/            # MOEX ISS fallback
│   │   │       ├── client.py
│   │   │       └── mappers.py
│   │   ├── market_data/             # Сервис рыночных данных
│   │   │   ├── router.py
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   ├── models.py
│   │   │   ├── cache.py             # OHLCV cache logic
│   │   │   ├── bond_service.py      # Расчёт НКД, параметры облигационных выпусков
│   │   │   └── validator.py         # Валидация OHLCV
│   │   ├── notification/            # Сервис уведомлений
│   │   │   ├── router.py
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   ├── models.py
│   │   │   ├── telegram_bot.py
│   │   │   └── email_sender.py
│   │   ├── corporate_actions/       # Обработка корпоративных действий
│   │   │   ├── service.py           # CorporateActionHandler
│   │   │   ├── models.py
│   │   │   └── schemas.py
│   │   ├── circuit_breaker/         # Circuit Breaker
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   └── models.py
│   │   ├── scheduler/               # Планировщик
│   │   │   ├── service.py
│   │   │   ├── moex_calendar.py
│   │   │   └── jobs.py
│   │   ├── ai/                      # AI-интеграция
│   │   │   ├── router.py
│   │   │   ├── service.py
│   │   │   ├── schemas.py
│   │   │   ├── providers/
│   │   │   │   ├── base.py          # Абстрактный LLM provider
│   │   │   │   ├── claude.py
│   │   │   │   └── openai.py
│   │   │   └── prompts.py           # Системные промпты
│   │   ├── sandbox/                 # Песочница кода
│   │   │   ├── executor.py
│   │   │   ├── ast_analyzer.py
│   │   │   └── whitelist.py
│   │   └── common/                  # Общие утилиты
│   │       ├── database.py          # SQLAlchemy engine/session
│   │       ├── exceptions.py
│   │       ├── pagination.py
│   │       └── crypto.py            # AES-256-GCM helpers
│   ├── alembic/                     # Миграции
│   │   ├── alembic.ini
│   │   └── versions/
│   ├── tests/
│   │   ├── unit/
│   │   ├── integration/
│   │   └── e2e/
│   ├── pyproject.toml
│   └── scripts/
│       └── start_backend.sh       # Запуск uvicorn + alembic migrate
├── frontend/
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── api/                     # API-клиент, типы
│   │   ├── stores/                  # Zustand stores
│   │   ├── hooks/                   # Кастомные React-хуки
│   │   ├── components/
│   │   │   ├── layout/              # Shell, Sidebar, Header
│   │   │   ├── dashboard/
│   │   │   ├── strategy/
│   │   │   ├── backtest/
│   │   │   ├── trading/
│   │   │   ├── charts/
│   │   │   ├── account/
│   │   │   ├── settings/
│   │   │   └── notifications/
│   │   ├── pages/                   # Route pages
│   │   └── utils/
│   ├── public/
│   ├── index.html
│   ├── vite.config.ts
│   ├── tsconfig.json
│   └── package.json
├── scripts/
│   ├── start.sh                   # Запуск backend + frontend (dev)
│   ├── start.bat                  # Windows-версия
│   ├── install.sh                 # Установка зависимостей (venv + pip + pnpm)
│   └── install.bat                # Windows-версия
├── Procfile                        # Для Honcho/Foreman (опционально)
├── .env.example
└── README.md
```

### 2.2 Диаграмма потоков данных

```
                     ┌──────────────┐
                     │   Frontend   │
                     │   (React)    │
                     └──────┬───────┘
                            │ REST + WebSocket
                            ▼
                     ┌──────────────┐
                     │   FastAPI    │
                     │  (Backend)   │
                     └──┬───┬───┬───┘
                        │   │   │
          ┌─────────────┘   │   └─────────────┐
          ▼                 ▼                  ▼
   ┌─────────────┐  ┌─────────────┐   ┌──────────────┐
   │   SQLite    │  │  T-Invest   │   │  LLM API     │
   │   (ORM)     │  │  (gRPC)     │   │  (Claude/    │
   │             │  │             │   │   GPT-4)      │
   └─────────────┘  └──────┬──────┘   └──────────────┘
                           │
                    ┌──────┴──────┐
                    │  MOEX ISS   │
                    │  (fallback) │
                    └─────────────┘
                           │
                    ┌──────┴──────┐
                    │  Telegram   │
                    │  Bot API    │
                    └─────────────┘
```

### 2.3 WebSocket-каналы

Backend поддерживает мультиплексированное WebSocket-соединение на одном endpoint `/ws`. Клиент подписывается на каналы через JSON-сообщения:

```
Канал "market:{ticker}:{timeframe}" — свечи и цены в реальном времени
Канал "trades:{session_id}"        — сделки стратегии
Канал "notifications"              — in-app уведомления
Канал "health"                     — статус компонентов системы
Канал "backtest:{backtest_id}"     — прогресс бэктеста
```

### 2.4 Принцип внутреннего взаимодействия модулей

Модули взаимодействуют через dependency injection (FastAPI `Depends`) и вызов сервисных слоёв напрямую (не через HTTP). Каждый модуль экспортирует `service` — единственную точку входа для других модулей. Модели (SQLAlchemy) могут иметь foreign keys на модели других модулей — это допустимо в монолите.

Для асинхронного взаимодействия (уведомления, срабатывания circuit breaker) используется in-process event bus на основе Python `asyncio.Queue` с pub/sub паттерном:

```python
# common/event_bus.py
class EventBus:
    async def publish(self, event_type: str, payload: dict) -> None: ...
    async def subscribe(self, event_type: str, handler: Callable) -> None: ...
```

События:
- `order.placed`, `order.filled`, `order.rejected`
- `position.opened`, `position.closed`
- `circuit_breaker.triggered`
- `connection.lost`, `connection.restored`
- `strategy.started`, `strategy.stopped`, `strategy.paused`
- `backtest.completed`, `backtest.failed`

**Гарантия доставки критических событий:**
Для событий `order.placed`, `order.filled`, `circuit_breaker.triggered`, `connection.lost` — перед publish в event bus создаётся запись в таблице `pending_events` (см. раздел 3.20). После успешной обработки всеми подписчиками — проставляется `processed_at`. При старте системы — повторная обработка записей с `processed_at IS NULL` для предотвращения потери событий при крэше.

---

## 3. СХЕМА БАЗЫ ДАННЫХ

**Ответственный: BACK2 (схема БД, модели, миграции)**

Все таблицы ниже определяются как SQLAlchemy ORM-модели. Типы указаны в нотации SQLAlchemy. Все временные метки хранятся в UTC.

> **Важное примечание о типах для финансовых данных:** Для всех денежных сумм, цен и процентов используется `Numeric` вместо `Float` для предотвращения ошибок округления IEEE 754. Типы: `Numeric(18, 8)` — цены, `Numeric(18, 2)` — денежные суммы, `Numeric(10, 4)` — проценты. В Python-коде для финансовых расчётов использовать `decimal.Decimal`.

### 3.1 Таблица `users`

```
users
├── id: Integer, PK, autoincrement
├── username: String(50), UNIQUE, NOT NULL
├── password_hash: String(255), NOT NULL          -- Argon2id hash
├── email: String(255), NULLABLE
├── risk_daily_loss_pct: Numeric(10, 4), DEFAULT 5.0       -- % от баланса
├── risk_daily_loss_fixed: Numeric(18, 2), NULLABLE        -- фикс. сумма ₽
├── risk_max_drawdown_pct: Numeric(10, 4), DEFAULT 20.0    -- % от пика equity
├── risk_max_position_size: Numeric(18, 2), NULLABLE       -- макс. сумма позиции ₽
├── risk_daily_trade_limit: Integer, DEFAULT 50   -- макс. сделок/день
├── disclaimer_accepted_at: DateTime, NULLABLE
├── failed_login_count: Integer, DEFAULT 0       -- Счётчик неудачных попыток входа
├── locked_until: DateTime, NULLABLE              -- Блокировка до (при brute-force)
├── created_at: DateTime, NOT NULL, DEFAULT utcnow
├── updated_at: DateTime, NOT NULL, DEFAULT utcnow, onupdate utcnow
└── is_active: Boolean, DEFAULT True
```

### 3.2 Таблица `broker_accounts`

```
broker_accounts
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NOT NULL
├── broker_type: String(20), NOT NULL             -- 'tinvest', 'alor', ...
├── name: String(100), NOT NULL                   -- Человекочитаемое имя
├── encrypted_api_key: LargeBinary, NOT NULL      -- AES-256-GCM
├── encrypted_api_secret: LargeBinary, NULLABLE   -- Если требуется
├── encryption_iv: LargeBinary, NOT NULL          -- IV для AES-GCM
├── account_id: String(50), NOT NULL              -- ID счёта у брокера
├── account_type: String(20), NOT NULL            -- 'broker', 'iis'
├── is_active: Boolean, DEFAULT True
├── has_withdrawal_rights: Boolean, DEFAULT False  -- Предупреждение
├── created_at: DateTime, NOT NULL
├── updated_at: DateTime, NOT NULL
└── INDEX: idx_broker_user (user_id)
```

### 3.3 Таблица `strategies`

```
strategies
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NOT NULL
├── name: String(200), NOT NULL
├── status: String(20), NOT NULL, DEFAULT 'draft'
│         -- 'draft','tested','paper','live','paused','archived'
├── current_version_id: Integer, FK(strategy_versions.id), NULLABLE
├── created_at: DateTime, NOT NULL
├── updated_at: DateTime, NOT NULL
└── INDEX: idx_strategy_user (user_id)
```

### 3.4 Таблица `strategy_versions`

```
strategy_versions
├── id: Integer, PK, autoincrement
├── strategy_id: Integer, FK(strategies.id), NOT NULL
├── version_number: Integer, NOT NULL
├── text_description: Text, NULLABLE
├── blocks_json: Text, NOT NULL                   -- JSON блочной схемы (Blockly XML/JSON)
├── generated_code: Text, NOT NULL                -- Python-код для Backtrader
├── parameters_json: Text, NULLABLE               -- JSON с параметрами стратегии
├── ai_chat_history: Text, NULLABLE               -- JSON истории диалога с AI
├── created_at: DateTime, NOT NULL
├── UNIQUE: uq_strategy_version (strategy_id, version_number)
└── INDEX: idx_sv_strategy (strategy_id)
```

### 3.5 Таблица `ohlcv_cache`

```
ohlcv_cache
├── id: Integer, PK, autoincrement
├── ticker: String(20), NOT NULL
├── timeframe: String(5), NOT NULL                -- '1m','5m','15m','1h','4h','D','W','M'
├── timestamp: DateTime, NOT NULL                 -- Время открытия свечи (UTC)
├── open: Numeric(18, 8), NOT NULL
├── high: Numeric(18, 8), NOT NULL
├── low: Numeric(18, 8), NOT NULL
├── close: Numeric(18, 8), NOT NULL
├── volume: BigInteger, NOT NULL
├── source: String(10), DEFAULT 'tinvest'         -- 'tinvest', 'moex_iss'
├── UNIQUE: uq_ohlcv (ticker, timeframe, timestamp)
└── INDEX: idx_ohlcv_lookup (ticker, timeframe, timestamp)
```

**Примечание по производительности:** Для OHLCV-кеша при 5 годах дневных данных ~1250 записей на инструмент — вполне подъёмно для SQLite. При минутном таймфрейме за 5 лет — ~600 000 записей на инструмент. Индекс `idx_ohlcv_lookup` обеспечивает O(log n) поиск. При переходе на PostgreSQL рекомендуется партиционирование по `ticker`.

### 3.6 Таблица `backtests`

```
backtests
├── id: Integer, PK, autoincrement
├── strategy_version_id: Integer, FK(strategy_versions.id), NOT NULL
├── ticker: String(20), NOT NULL
├── timeframe: String(5), NOT NULL
├── date_from: DateTime, NOT NULL
├── date_to: DateTime, NOT NULL
├── initial_capital: Numeric(18, 2), NOT NULL
├── commission_pct: Numeric(10, 4), NOT NULL
├── slippage_value: Numeric(10, 4), NOT NULL      -- Значение проскальзывания
├── slippage_mode: String(10), NOT NULL, DEFAULT 'pct'  -- 'pct' | 'points'
├── params_json: Text, NULLABLE                   -- Доп. параметры запуска
├── status: String(20), NOT NULL                  -- 'running','completed','failed'
├── net_profit: Numeric(18, 2), NULLABLE
├── net_profit_pct: Numeric(10, 4), NULLABLE
├── total_trades: Integer, NULLABLE
├── winning_trades: Integer, NULLABLE
├── losing_trades: Integer, NULLABLE
├── win_rate: Numeric(10, 4), NULLABLE
├── profit_factor: Numeric(10, 4), NULLABLE
├── max_drawdown_pct: Numeric(10, 4), NULLABLE
├── sharpe_ratio: Numeric(10, 4), NULLABLE
├── avg_profit_per_trade: Numeric(18, 2), NULLABLE
├── avg_loss_per_trade: Numeric(18, 2), NULLABLE
├── avg_trade_duration_bars: Numeric(10, 2), NULLABLE
├── avg_trade_duration_seconds: Numeric(12, 2), NULLABLE
├── benchmark_buy_hold_pct: Numeric(10, 4), NULLABLE
├── benchmark_imoex_pct: Numeric(10, 4), NULLABLE
├── equity_curve_json: Text, NULLABLE             -- JSON массив точек equity
├── error_message: Text, NULLABLE
├── started_at: DateTime, NOT NULL
├── completed_at: DateTime, NULLABLE
├── INDEX: idx_bt_sv (strategy_version_id)
└── INDEX: idx_bt_ticker (ticker, timeframe)
```

### 3.7 Таблица `backtest_trades`

```
backtest_trades
├── id: Integer, PK, autoincrement
├── backtest_id: Integer, FK(backtests.id, ondelete=CASCADE), NOT NULL
├── direction: String(5), NOT NULL                -- 'long'
├── entry_date: DateTime, NOT NULL
├── entry_price: Numeric(18, 8), NOT NULL
├── exit_date: DateTime, NULLABLE
├── exit_price: Numeric(18, 8), NULLABLE
├── volume_lots: Integer, NOT NULL
├── volume_rub: Numeric(18, 2), NOT NULL
├── pnl: Numeric(18, 2), NULLABLE
├── pnl_pct: Numeric(10, 4), NULLABLE
├── commission: Numeric(18, 2), NULLABLE
├── duration_bars: Integer, NULLABLE
├── duration_seconds: Integer, NULLABLE
└── INDEX: idx_btt_backtest (backtest_id)
```

### 3.8 Таблица `trading_sessions`

```
trading_sessions
├── id: Integer, PK, autoincrement
├── strategy_version_id: Integer, FK(strategy_versions.id), NOT NULL
├── broker_account_id: Integer, FK(broker_accounts.id), NOT NULL
├── ticker: String(20), NOT NULL
├── mode: String(10), NOT NULL                    -- 'paper', 'real'
├── status: String(20), NOT NULL
│         -- 'active','paused','stopped','suspended','error'
├── position_sizing_mode: String(20), NOT NULL    -- 'pct_deposit', 'fixed_amount'
├── position_sizing_value: Numeric(18, 2), NOT NULL
├── max_concurrent_positions: Integer, DEFAULT 1
├── cooldown_seconds: Integer, DEFAULT 0
├── initial_capital: Numeric(18, 2), NULLABLE     -- Для paper trading
├── consecutive_fund_skips: Integer, DEFAULT 0    -- Пропуски из-за нехватки средств (пауза при ≥3)
├── started_at: DateTime, NOT NULL
├── stopped_at: DateTime, NULLABLE
├── last_signal_at: DateTime, NULLABLE
├── UNIQUE: uq_active_session (broker_account_id, ticker, mode, status)
│         -- Partial unique: WHERE status = 'active'
└── INDEX: idx_ts_active (status)
```

### 3.9 Таблица `live_trades`

```
live_trades
├── id: Integer, PK, autoincrement
├── session_id: Integer, FK(trading_sessions.id), NOT NULL
├── broker_order_id: String(100), NULLABLE        -- ID ордера у брокера
├── direction: String(5), NOT NULL                -- 'long'
├── order_type: String(20), NOT NULL              -- 'market','limit','stop_market','stop_limit'
├── status: String(20), NOT NULL
│         -- 'pending','partial','filled','cancelled','rejected'
├── entry_signal_price: Numeric(18, 8), NOT NULL  -- Цена на момент сигнала
├── entry_price: Numeric(18, 8), NULLABLE         -- Фактическая цена исполнения
├── exit_signal_price: Numeric(18, 8), NULLABLE
├── exit_price: Numeric(18, 8), NULLABLE
├── volume_lots: Integer, NOT NULL
├── filled_lots: Integer, DEFAULT 0
├── volume_rub: Numeric(18, 2), NOT NULL
├── stop_loss: Numeric(18, 8), NULLABLE
├── take_profit: Numeric(18, 8), NULLABLE
├── pnl: Numeric(18, 2), NULLABLE
├── pnl_pct: Numeric(10, 4), NULLABLE
├── commission: Numeric(18, 2), NULLABLE
├── slippage: Numeric(18, 8), NULLABLE            -- entry_price - entry_signal_price
├── nkd_entry: Numeric(18, 2), NULLABLE           -- НКД при покупке (для облигаций)
├── nkd_exit: Numeric(18, 2), NULLABLE            -- НКД при продаже
├── opened_at: DateTime, NOT NULL
├── closed_at: DateTime, NULLABLE
├── INDEX: idx_lt_session (session_id)
├── INDEX: idx_lt_status (status)
└── INDEX: idx_lt_opened (opened_at)
```

### 3.10 Таблица `paper_portfolios`

```
paper_portfolios
├── id: Integer, PK, autoincrement
├── session_id: Integer, FK(trading_sessions.id), UNIQUE, NOT NULL
├── balance: Numeric(18, 2), NOT NULL
├── blocked_amount: Numeric(18, 2), DEFAULT 0.0   -- Для эмуляции T+1
├── peak_equity: Numeric(18, 2), NOT NULL
├── updated_at: DateTime, NOT NULL
```

### 3.11 Таблица `audit_log`

```
audit_log
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NULLABLE      -- NULLABLE для системных событий
├── action: String(50), NOT NULL                  -- 'login','order.placed','cb.triggered',...
├── entity_type: String(30), NULLABLE             -- 'strategy','order','session',...
├── entity_id: Integer, NULLABLE
├── details: Text, NULLABLE                       -- JSON с деталями
├── source: String(20), NOT NULL                  -- 'web','telegram','scheduler','system'
├── ip_address: String(45), NULLABLE
├── created_at: DateTime, NOT NULL, DEFAULT utcnow
├── INDEX: idx_audit_created (created_at)
└── INDEX: idx_audit_user (user_id, created_at)
```

**Ограничение:** Эта таблица — append-only. На уровне приложения `AuditLogService` предоставляет только метод `create()`. ORM-модель не имеет методов `update` / `delete`. Дополнительно: SQLite trigger на DELETE для защиты:

```sql
CREATE TRIGGER prevent_audit_delete BEFORE DELETE ON audit_log
BEGIN SELECT RAISE(ABORT, 'Deletion from audit_log is prohibited'); END;

CREATE TRIGGER prevent_audit_update BEFORE UPDATE ON audit_log
BEGIN SELECT RAISE(ABORT, 'Update of audit_log is prohibited'); END;
```

### 3.12 Таблица `notifications`

```
notifications
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NOT NULL
├── event_type: String(50), NOT NULL              -- 'trade.opened','cb.triggered',...
├── title: String(200), NOT NULL
├── body: Text, NOT NULL
├── severity: String(10), NOT NULL                -- 'info','warning','critical'
├── is_read: Boolean, DEFAULT False
├── channels_sent: String(100), NULLABLE          -- JSON: ['telegram','email']
├── related_entity_type: String(30), NULLABLE
├── related_entity_id: Integer, NULLABLE
├── created_at: DateTime, NOT NULL
├── INDEX: idx_notif_user_unread (user_id, is_read, created_at)
```

### 3.13 Таблица `price_alerts`

```
price_alerts
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NOT NULL
├── ticker: String(20), NOT NULL
├── price_level: Numeric(18, 8), NOT NULL
├── direction: String(10), NOT NULL               -- 'above','below'
├── is_active: Boolean, DEFAULT True
├── triggered_at: DateTime, NULLABLE
├── created_at: DateTime, NOT NULL
└── INDEX: idx_alert_active (ticker, is_active)
```

### 3.14 Таблица `chart_drawings`

```
chart_drawings
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NOT NULL
├── ticker: String(20), NOT NULL
├── timeframe: String(5), NOT NULL
├── type: String(20), NOT NULL                    -- 'trendline','horizontal','rectangle'
├── data_json: Text, NOT NULL                     -- JSON с координатами
├── style_json: Text, NULLABLE                    -- JSON с цветом, толщиной
├── created_at: DateTime, NOT NULL
├── updated_at: DateTime, NOT NULL
└── INDEX: idx_drawing_lookup (user_id, ticker, timeframe)
```

### 3.15 Таблица `telegram_links`

```
telegram_links
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), UNIQUE, NOT NULL
├── chat_id: BigInteger, NOT NULL
├── linked_at: DateTime, NOT NULL
├── is_active: Boolean, DEFAULT True
```

### 3.16 Таблица `user_notification_settings`

```
user_notification_settings
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NOT NULL
├── event_type: String(50), NOT NULL
├── telegram_enabled: Boolean, DEFAULT True
├── email_enabled: Boolean, DEFAULT False
├── inapp_enabled: Boolean, DEFAULT True
├── UNIQUE: uq_notif_setting (user_id, event_type)
```

### 3.17 Таблица `daily_stats`

```
daily_stats
├── id: Integer, PK, autoincrement
├── session_id: Integer, FK(trading_sessions.id), NOT NULL
├── date: Date, NOT NULL
├── trades_opened: Integer, DEFAULT 0
├── trades_closed: Integer, DEFAULT 0
├── pnl: Numeric(18, 2), DEFAULT 0.0
├── realized_pnl: Numeric(18, 2), DEFAULT 0.0
├── unrealized_pnl: Numeric(18, 2), DEFAULT 0.0
├── peak_equity: Numeric(18, 2), NULLABLE
├── UNIQUE: uq_daily_stat (session_id, date)
```

### 3.18 Таблица `bond_info_cache`

```
bond_info_cache
├── id: Integer, PK, autoincrement
├── ticker: String(20), UNIQUE, NOT NULL
├── isin: String(20), NOT NULL
├── nominal: Numeric(18, 2), NOT NULL            -- Номинал облигации
├── coupon_rate: Numeric(10, 4), NULLABLE        -- Ставка купона (% годовых)
├── coupon_frequency: Integer, NULLABLE           -- Количество выплат в год
├── maturity_date: Date, NULLABLE                 -- Дата погашения
├── coupon_dates_json: Text, NULLABLE             -- JSON массив дат ближайших купонов
├── updated_at: DateTime, NOT NULL
```

### 3.19 Таблица `corporate_actions`

```
corporate_actions
├── id: Integer, PK, autoincrement
├── ticker: String(20), NOT NULL
├── action_type: String(20), NOT NULL             -- 'split', 'dividend', 'coupon'
├── ex_date: Date, NOT NULL                       -- Дата отсечки
├── ratio_from: Integer, NULLABLE                 -- Для сплита: было
├── ratio_to: Integer, NULLABLE                   -- Для сплита: стало
├── amount_per_share: Numeric(18, 8), NULLABLE    -- Дивиденд/купон на акцию/облигацию
├── currency: String(3), DEFAULT 'RUB'
├── detected_at: DateTime, NOT NULL
├── processed: Boolean, DEFAULT False
├── UNIQUE: uq_corp_action (ticker, action_type, ex_date)
└── INDEX: idx_corp_ticker (ticker, ex_date)
```

### 3.20 Таблица `pending_events`

```
pending_events
├── id: Integer, PK, autoincrement
├── event_type: String(50), NOT NULL              -- 'order.placed', 'circuit_breaker.triggered', ...
├── payload_json: Text, NOT NULL
├── created_at: DateTime, NOT NULL, DEFAULT utcnow
├── processed_at: DateTime, NULLABLE
└── INDEX: idx_pending_unprocessed (processed_at)  -- WHERE processed_at IS NULL
```

### 3.21 Таблица `ai_provider_configs`

```
ai_provider_configs
├── id: Integer, PK, autoincrement
├── user_id: Integer, FK(users.id), NOT NULL
├── provider_type: String(20), NOT NULL           -- 'claude', 'openai', 'custom'
├── display_name: String(100), NOT NULL           -- Человекочитаемое имя ("Claude Sonnet", "GPT-4o")
├── encrypted_api_key: LargeBinary, NOT NULL      -- AES-256-GCM (тот же CryptoService, что и для брокеров)
├── encryption_iv: LargeBinary, NOT NULL          -- IV для AES-GCM
├── model_id: String(100), NOT NULL               -- 'claude-sonnet-4-6-20250514', 'gpt-4o', ...
├── api_base_url: String(255), NULLABLE           -- Для custom-провайдеров (Ollama, LM Studio и др.)
├── daily_limit: Integer, DEFAULT 100             -- Лимит запросов в сутки
├── monthly_limit: Integer, DEFAULT 3000          -- Лимит запросов в месяц
├── usage_today: Integer, DEFAULT 0               -- Счётчик использования (сбрасывается ежедневно)
├── usage_month: Integer, DEFAULT 0               -- Счётчик использования (сбрасывается ежемесячно)
├── is_active: Boolean, DEFAULT True              -- Активный провайдер (только один может быть активным)
├── is_verified: Boolean, DEFAULT False           -- Ключ проверен тестовым запросом
├── last_used_at: DateTime, NULLABLE
├── created_at: DateTime, NOT NULL
├── updated_at: DateTime, NOT NULL
└── INDEX: idx_ai_provider_user (user_id, is_active)
```

### 3.22 Таблица `revoked_tokens`

```
revoked_tokens
├── id: Integer, PK, autoincrement
├── jti: String(64), UNIQUE, NOT NULL            -- JWT ID из payload
├── user_id: Integer, FK(users.id), NOT NULL
├── revoked_at: DateTime, NOT NULL, DEFAULT utcnow
├── expires_at: DateTime, NOT NULL               -- Для cleanup: удаляется после истечения
└── INDEX: idx_revoked_jti (jti)
```

### 3.23 ER-диаграмма (текстовое описание ключевых связей)

```
users 1──* broker_accounts
users 1──* strategies
users 1──1 telegram_links
users 1──* notifications
users 1──* price_alerts
users 1──* audit_log
users 1──* chart_drawings
users 1──* user_notification_settings
users 1──* revoked_tokens
users 1──* ai_provider_configs

strategies 1──* strategy_versions
strategies *──1 strategy_versions (current_version_id)

strategy_versions 1──* backtests
strategy_versions 1──* trading_sessions

backtests 1──* backtest_trades

trading_sessions 1──* live_trades
trading_sessions 1──1 paper_portfolios
trading_sessions 1──* daily_stats
trading_sessions *──1 broker_accounts

(standalone — без FK к user)
ohlcv_cache
bond_info_cache
corporate_actions
pending_events
```

---

## 4. API-КОНТРАКТЫ

**Ответственный: BACK1 (определяет), FRONT1 + FRONT2 (ревью), UX (ревью UI-контрактов)**

Все endpoints имеют префикс `/api/v1`. Формат ответов — JSON. Аутентификация — через Bearer JWT в заголовке `Authorization`. CSRF-токен передаётся в заголовке `X-CSRF-Token` для мутирующих запросов.

### 4.1 Auth API

```
POST   /api/v1/auth/setup          -- Первоначальная настройка (создание пользователя)
       Body: { username, password }
       Response: 201 { user_id, access_token, refresh_token }

POST   /api/v1/auth/login
       Body: { username, password }
       Response: 200 { access_token, refresh_token, expires_in }
       Error 401: { detail: "Неверный логин или пароль" }
       Error 423: { detail: "Аккаунт заблокирован", retry_after: 900 }

POST   /api/v1/auth/refresh
       Body: { refresh_token }
       Response: 200 { access_token, refresh_token, expires_in }

POST   /api/v1/auth/logout
       Response: 204

GET    /api/v1/auth/me
       Response: 200 { user profile }

PATCH  /api/v1/auth/password
       Body: { current_password, new_password }
       Response: 200

GET    /api/v1/auth/setup-status
       Response: 200 { is_configured: bool }
       -- Возвращает true если в таблице users есть хотя бы один пользователь.
       -- Используется frontend для автоматического редиректа на /setup при первом запуске.
       -- Доступен без JWT.
```

### 4.2 Strategy API

```
GET    /api/v1/strategies
       Query: ?status=&page=&per_page=
       Response: 200 { items: [...], total, page, per_page }

POST   /api/v1/strategies
       Body: { name }
       Response: 201 { strategy }

GET    /api/v1/strategies/{id}
       Response: 200 { strategy with current_version }

PATCH  /api/v1/strategies/{id}
       Body: { name?, status? }
       Response: 200 { strategy }

DELETE /api/v1/strategies/{id}
       Response: 204

GET    /api/v1/strategies/{id}/versions
       Response: 200 { items: [...] }

POST   /api/v1/strategies/{id}/versions
       Body: { text_description?, blocks_json, generated_code, parameters_json? }
       Response: 201 { version }

GET    /api/v1/strategies/{id}/versions/{version_id}
       Response: 200 { version }

POST   /api/v1/strategies/{id}/generate-code
       Body: { blocks_json }
       Response: 200 { generated_code, validation_errors? }

POST   /api/v1/strategies/{id}/parse-template
       Body: { template_text }
       Response: 200 { blocks_json, warnings? }
       Error 422: { detail: "Шаблон не распознан", errors: [...] }
```

### 4.3 Backtest API

```
POST   /api/v1/backtests
       Body: {
           strategy_version_id,
           ticker,
           timeframe,
           date_from,             -- "2021-01-01"
           date_to,               -- "2026-01-01"
           initial_capital,
           commission_pct,
           slippage_value,
           slippage_mode,          -- "pct" | "points"
           params_overrides?: {}   -- для grid search
       }
       Response: 202 { backtest_id, status: "running" }

GET    /api/v1/backtests/{id}
       Response: 200 { backtest with metrics }

GET    /api/v1/backtests/{id}/trades
       Query: ?page=&per_page=&sort_by=&order=
       Response: 200 { items: [...], total }

GET    /api/v1/backtests/{id}/equity-curve
       Response: 200 { points: [{timestamp, equity, drawdown}] }

DELETE /api/v1/backtests/{id}
       Response: 204

POST   /api/v1/backtests/optimize
       Body: {
           strategy_version_id, ticker, timeframe, date_from, date_to,
           initial_capital, commission_pct, slippage_pct,
           param_ranges: { "ema_period": { min: 10, max: 50, step: 5 } }
       }
       Response: 202 { optimization_id }

GET    /api/v1/backtests/optimize/{id}
       Response: 200 { status, results: [{params, metrics}], overfitting_warning? }
```

### 4.4 Trading API

```
POST   /api/v1/trading/sessions
       Body: {
           strategy_version_id,
           broker_account_id,
           ticker,
           mode,                  -- "paper" | "real"
           position_sizing_mode,  -- "pct_deposit" | "fixed_amount"
           position_sizing_value,
           max_concurrent_positions?,
           cooldown_seconds?,
           initial_capital?       -- Для paper
       }
       Response: 201 { session }

GET    /api/v1/trading/sessions
       Query: ?status=&mode=
       Response: 200 { items: [...] }

GET    /api/v1/trading/sessions/{id}
       Response: 200 { session with stats }

PATCH  /api/v1/trading/sessions/{id}
       Body: { status: "paused" | "active" | "stopped" }
       Response: 200 { session }

GET    /api/v1/trading/sessions/{id}/trades
       Query: ?status=&page=&per_page=
       Response: 200 { items: [...], total }

POST   /api/v1/trading/sessions/{id}/close-position/{trade_id}
       Response: 200 { trade }

POST   /api/v1/trading/sessions/{id}/close-all
       Response: 200 { closed_count, trades: [...] }

GET    /api/v1/trading/sessions/{id}/stats
       Response: 200 { daily_pnl, total_pnl, open_positions, ... }
```

### 4.5 Market Data API

```
GET    /api/v1/market/instruments/search
       Query: ?q=SBER
       Response: 200 { items: [{ticker, name, type, lot_size, ...}] }

GET    /api/v1/market/instruments/{ticker}
       Response: 200 { instrument details }

GET    /api/v1/market/candles/{ticker}
       Query: ?timeframe=D&from=2024-01-01&to=2024-12-31
       Response: 200 { candles: [{t, o, h, l, c, v}] }

GET    /api/v1/market/calendar
       Query: ?year=2026
       Response: 200 { holidays: [...], sessions: {...} }

GET    /api/v1/market/status/{ticker}
       Response: 200 { is_trading, session_open, session_close, is_holiday }
```

### 4.6 Broker Account API

```
GET    /api/v1/broker-accounts
       Response: 200 { items: [...] }

POST   /api/v1/broker-accounts
       Body: { broker_type, name, api_key, api_secret?, account_id, account_type }
       Response: 201 { account (key masked) }

GET    /api/v1/broker-accounts/{id}
       Response: 200 { account with balance }

PATCH  /api/v1/broker-accounts/{id}
       Body: { name?, api_key?, is_active? }
       Response: 200

DELETE /api/v1/broker-accounts/{id}
       Response: 204

GET    /api/v1/broker-accounts/{id}/positions
       Response: 200 { positions from broker }

GET    /api/v1/broker-accounts/{id}/operations
       Query: ?from=&to=
       Response: 200 { items: [...] }

POST   /api/v1/broker-accounts/discover
       Body: { broker_type, api_key, api_secret? }
       Response: 200 { accounts: [{account_id, type, name}] }
```

### 4.7 AI API

```
POST   /api/v1/ai/chat
       Body: { strategy_id, message, history?: [...] }
       Response: 200 { response, suggested_blocks?, updated_code? }
       (Streaming: SSE endpoint альтернативно)

GET    /api/v1/ai/status
       Response: 200 { available: true, provider: "claude", usage_today: 15, limit_today: 100 }

POST   /api/v1/ai/explain
       Body: { code_snippet }
       Response: 200 { explanation }
```

### 4.8 Notification API

```
GET    /api/v1/notifications
       Query: ?unread_only=true&page=&per_page=
       Response: 200 { items: [...], unread_count }

PATCH  /api/v1/notifications/{id}/read
       Response: 200

POST   /api/v1/notifications/read-all
       Response: 200

GET    /api/v1/notifications/settings
       Response: 200 { settings per event type }

PATCH  /api/v1/notifications/settings
       Body: [{ event_type, telegram_enabled, email_enabled, inapp_enabled }]
       Response: 200
```

### 4.9 Settings / Profile API

```
GET    /api/v1/settings/profile
       Response: 200 { user profile + risk settings }

PATCH  /api/v1/settings/profile
       Body: { email?, risk_daily_loss_pct?, ... }
       Response: 200

POST   /api/v1/settings/telegram/link
       Response: 200 { token, expires_at }     -- 6-значный токен, TTL 5 мин

DELETE /api/v1/settings/telegram/unlink
       Response: 204

GET    /api/v1/settings/telegram/status
       Response: 200 { linked: true, chat_id_masked: "***1234" }

-- AI Provider Settings --

GET    /api/v1/settings/ai/providers
       Response: 200 { items: [{id, provider_type, display_name, model_id, api_base_url,
                        daily_limit, monthly_limit, usage_today, usage_month,
                        is_active, is_verified, api_key_masked, last_used_at}] }

POST   /api/v1/settings/ai/providers
       Body: { provider_type, display_name, api_key, model_id, api_base_url?,
               daily_limit?, monthly_limit? }
       Response: 201 { provider (key masked) }

PATCH  /api/v1/settings/ai/providers/{id}
       Body: { display_name?, api_key?, model_id?, api_base_url?,
               daily_limit?, monthly_limit?, is_active? }
       Response: 200

DELETE /api/v1/settings/ai/providers/{id}
       Response: 204

POST   /api/v1/settings/ai/providers/{id}/verify
       -- Тестовый запрос к провайдеру для проверки ключа
       Response: 200 { verified: true, model: "claude-sonnet-4-6-...", latency_ms: 340 }
       Error 422: { verified: false, error: "Invalid API key" }

POST   /api/v1/settings/ai/providers/{id}/activate
       -- Делает указанного провайдера активным (деактивирует остальных)
       Response: 200

GET    /api/v1/settings/ai/usage
       Response: 200 { provider, usage_today, limit_today, usage_month, limit_month }
```

### 4.10 Health API

```
GET    /api/v1/health
       Response: 200 {
           status: "healthy" | "degraded" | "critical",
           components: {
               database: { status, latency_ms },
               broker_tinvest: { status, connected_accounts },
               ai_provider: { status, provider },
               telegram_bot: { status }
           },
           uptime_seconds,
           version
       }
```

### 4.11 Export API

```
GET    /api/v1/export/backtest/{id}/csv
       Response: 200 (file download, Content-Type: text/csv)

GET    /api/v1/export/backtest/{id}/pdf
       Response: 200 (file download, Content-Type: application/pdf)

GET    /api/v1/export/trades
       Query: ?session_id=&from=&to=&format=csv|xlsx
       Response: 200 (file download)

GET    /api/v1/export/tax-report
       Query: ?year=2025&format=xlsx|csv
       Response: 200 (file download)
```

### 4.12 WebSocket Protocol

**Endpoint:** `ws://localhost:8000/api/v1/ws`

**Авторизация:** после установки соединения клиент отправляет первое сообщение:
```json
{
    "action": "auth",
    "token": "<jwt_token>"
}
```
Сервер верифицирует токен. При успехе: `{"type": "auth_ok"}`. При ошибке: `{"type": "auth_error", "detail": "..."}` + закрытие соединения. До авторизации любые subscribe-запросы отклоняются. Это предотвращает утечку JWT через URL (серверные логи, history).

**Клиент -> Сервер (подписка):**
```json
{
    "action": "subscribe",
    "channel": "market:SBER:D"
}
```

**Клиент -> Сервер (отписка):**
```json
{
    "action": "unsubscribe",
    "channel": "market:SBER:D"
}
```

**Сервер -> Клиент (свечи):**
```json
{
    "channel": "market:SBER:D",
    "type": "candle",
    "data": { "t": 1711929600, "o": 285.40, "h": 286.10, "l": 284.90, "c": 285.80, "v": 12340000 }
}
```

**Сервер -> Клиент (сделка стратегии):**
```json
{
    "channel": "trades:42",
    "type": "trade_update",
    "data": { "trade_id": 123, "status": "filled", "price": 285.40, ... }
}
```

**Сервер -> Клиент (уведомление):**
```json
{
    "channel": "notifications",
    "type": "notification",
    "data": { "id": 456, "title": "...", "severity": "critical", ... }
}
```

**Сервер -> Клиент (прогресс бэктеста):**
```json
{
    "channel": "backtest:789",
    "type": "progress",
    "data": { "percent": 45, "current_date": "2023-06-15" }
}
```

**Сервер -> Клиент (health):**
```json
{
    "channel": "health",
    "type": "status_change",
    "data": { "component": "broker_tinvest", "status": "disconnected" }
}
```

**Heartbeat:** Сервер отправляет `{"type": "ping"}` каждые 30 секунд. Клиент отвечает `{"type": "pong"}`. При отсутствии pong в течение 90 секунд — соединение закрывается.

---

## 5. BACKEND-МОДУЛИ: ДЕТАЛЬНАЯ СПЕЦИФИКАЦИЯ

### 5.1 Auth Module

**Ответственный: SEC (реализация) + BACK1 (интеграция)**

**Хеширование паролей:** Argon2id — параметры и детали см. раздел 7.1.

**JWT-токены:** HS256, access/refresh с ротацией — детали см. раздел 7.3. Revoked tokens хранятся в таблице `revoked_tokens` (см. раздел 3.21). Проверка `jti` при каждом запросе. Cleanup истёкших токенов — ежедневно по cron (см. раздел 5.9, job `cleanup_revoked_tokens`).

**Защита от брутфорса:**
- Поля `failed_login_count` и `locked_until` в таблице `users` (персистентное хранение — не теряется при рестарте)
- При неудачном логине — инкремент `failed_login_count` в БД
- После 5 неудачных попыток — установка `locked_until = now + 15 min`, блокировка аккаунта
- При блокировке — запись в audit_log
- Успешный вход — сброс `failed_login_count = 0` и `locked_until = NULL`

**Мастер первого запуска:**
- При старте: проверка `SELECT COUNT(*) FROM users`. Если 0 — endpoint `/api/v1/auth/setup` доступен без JWT. После создания первого пользователя — endpoint становится недоступен (возвращает 403).
- Frontend UX flow: при загрузке `LoginPage` вызывается `GET /api/v1/auth/setup-status`. Если `is_configured: false` — автоматический редирект на `/setup` (страница регистрации первого пользователя). На странице логина отображается ссылка «Первый запуск? Создать аккаунт» → `/setup`. На странице Setup — ссылка «Уже есть аккаунт? Войти» → `/login`.
- При недоступности backend — LoginPage показывает Alert «Backend недоступен» и ссылку на Setup.

**Подготовка к 2FA (фаза 2):**
- Таблица `users` проектируется с учётом будущих полей (добавляются миграцией в фазе 2): `totp_secret: String(32), NULLABLE`, `totp_enabled: Boolean, DEFAULT False`.
- Логин-flow содержит extension point: после проверки пароля — вызов `verify_second_factor(user)`, который в фазе 1 всегда возвращает `True`. В фазе 2 — проверка TOTP-кода.

### 5.2 Strategy Engine (text -> blocks -> code pipeline)

**Ответственный: BACK2 (AI-часть + парсер + генератор), BACK1 (ревью)**

**5.2.1 Блочная схема — внутренний формат:**

Блоки хранятся в JSON. Каждый блок имеет тип, параметры и связи:

```json
{
    "blocks": [
        {
            "id": "b1",
            "type": "indicator",
            "name": "EMA",
            "params": { "period": 20, "source": "close" },
            "output": "ema_20"
        },
        {
            "id": "b2",
            "type": "condition",
            "name": "crossover",
            "inputs": ["ema_20", "ema_50"],
            "params": { "direction": "up" },
            "output": "cross_signal"
        },
        {
            "id": "b3",
            "type": "entry_signal",
            "name": "long_entry",
            "conditions": ["cross_signal", "rsi_above_30"],
            "logic": "AND"
        },
        {
            "id": "b4",
            "type": "exit_signal",
            "name": "long_exit",
            "conditions": ["cross_down"],
            "stop_loss_pct": 2.0,
            "take_profit_pct": 5.0
        },
        {
            "id": "b5",
            "type": "money_management",
            "sizing": "pct_deposit",
            "value": 10.0,
            "max_positions": 1
        },
        {
            "id": "b6",
            "type": "time_filter",
            "start": "10:00",
            "end": "18:00",
            "timezone": "Europe/Moscow"
        }
    ]
}
```

**Версионирование формата:** JSON блочной схемы содержит корневое поле `"schema_version": 1`. При изменении формата блоков в будущих версиях приложения — добавляется миграция в Alembic, которая обновляет `blocks_json` всех записей `strategy_versions` до нового формата. Это гарантирует обратную совместимость при обновлении приложения.

**5.2.2 Режим B — парсер шаблона:**

`block_parser.py` реализует regex-based парсер для шаблона из Приложения A. Логика:
1. Разбить текст по секциям (1. НАЗВАНИЕ, 2. ИНСТРУМЕНТЫ, ...).
2. Для каждой секции — набор правил парсинга.
3. Распознать индикаторы по паттернам: `EMA(period=20)`, `RSI(14)`, `Bollinger Bands(20, 2)`.
4. Распознать условия: "пересекает снизу вверх" -> crossover up.
5. При ошибке парсинга — возврат `warnings` с указанием непонятных секций.

**5.2.3 Генератор кода:**

`code_generator.py` принимает JSON блочной схемы и генерирует Python-класс для Backtrader:

```python
# Шаблон генерации
class GeneratedStrategy(bt.Strategy):
    params = (
        ('ema_period', 20),
        ('rsi_period', 14),
        ...
    )

    def __init__(self):
        self.ema = bt.indicators.EMA(period=self.p.ema_period)
        ...

    def next(self):
        # Условия входа/выхода
        ...
```

Маппинг блоков на код:
- `indicator` -> `bt.indicators.XXX` или `talib.XXX`
- `condition` -> Python-выражение в `next()`
- `entry_signal` -> `self.buy()` с условиями
- `exit_signal` -> `self.sell()` / `self.close()`
- `money_management` -> `bt.sizers.PercentSizer` или кастомный sizer
- `time_filter` -> проверка `self.data.datetime.time()` в `next()`

### 5.3 Backtest Engine

**Ответственный: BACK1**

**5.3.1 Архитектура:**

`BacktestEngine` — обёртка над `backtrader.Cerebro`. Процесс:

1. Получить OHLCV-данные из `MarketDataService.get_candles()` (кеш или загрузка).
2. Валидировать данные через `OHLCVValidator`.
3. Создать `bt.Cerebro()`.
4. Загрузить стратегию в sandbox (`SandboxExecutor.load_strategy(code)`).
5. Добавить data feed через `bt.feeds.PandasData`.
6. Установить broker params: commission, slippage, initial_capital.
7. Добавить analyzers: `bt.analyzers.SharpeRatio`, `bt.analyzers.DrawDown`, `bt.analyzers.TradeAnalyzer`, custom `EquityCurveAnalyzer`.
8. Запустить `cerebro.run()` в отдельном процессе (multiprocessing) с таймаутом 30 секунд для CPU-limit.
9. Собрать метрики из analyzers.
10. Рассчитать benchmark (Buy & Hold, IMOEX).
11. Сохранить результат в БД.
12. Отправить событие `backtest.completed` в event bus.

**5.3.2 Прогресс бэктеста:**

Custom analyzer `ProgressAnalyzer` вызывает callback каждые N баров, передавая текущую дату и процент завершения. Backend пушит это через WebSocket.

**5.3.3 Валидация OHLCV:**

```python
class OHLCVValidator:
    def validate(self, df: pd.DataFrame, ticker: str, timeframe: str) -> ValidationResult:
        errors = []
        warnings = []
        # 1. High >= Low
        # 2. OHLC в пределах ±50% от предыдущего Close
        # 3. Нет дубликатов по timestamp
        # 4. Нет пропусков (с учётом торгового календаря)
        return ValidationResult(errors=errors, warnings=warnings, is_valid=len(errors)==0)
```

**5.3.4 Оптимизация (Grid Search):**

Для каждой комбинации параметров — отдельный запуск `cerebro.run()`. Используется `multiprocessing.Pool` для параллелизации. Максимум workers = `os.cpu_count() - 1`. Результаты агрегируются в таблицу. Overfitting-предупреждение: если топ-5 результатов имеют разброс метрик > 50% от лучшего.

### 5.4 Trading Engine

**Ответственный: BACK1**

**5.4.1 Компоненты:**

- `TradingSessionManager` — управление жизненным циклом сессий (start, pause, stop, resume). Делегирует `SessionRuntime.start/stop` для live-части.
- `SessionRuntime` *(введён в S5R.2, `app/trading/runtime.py`)* — **единственная production-точка вызова** `SignalProcessor.process_candle()`. Держит per-session listener'ы на каналах EventBus `market:{ticker}:{timeframe}`, загружает скользящее окно истории свечей при старте, реагирует на closed-свечи, публикует события в канал `trades:{session_id}`. Создаётся один раз в `main.py lifespan`, вызывает `restore_all(active_sessions)` при старте backend, `shutdown()` при остановке.
- `SignalProcessor` — получает от runtime скользящее окно свечей (`candles: list[dict]`, по умолчанию N=200), прогоняет через стратегию в sandbox, генерирует сигналы. Сохранены алиасы `candle_open/candle_high/candle_low/candle_close/candle_volume` для обратной совместимости со старыми сгенерированными стратегиями.
- `OrderManager` — конвертирует сигналы в ордера, проверяет circuit breaker, отправляет в брокер.
- `PositionTracker` — отслеживает открытые позиции, P&L, slippage.
- `PaperTradingEngine` — эмуляция исполнения ордеров для paper trading.

**5.4.2 Поток обработки сигнала (Real, после S5R):**

```
StreamManager (T-Invest gRPC) / MOEX publisher
    ↓ publish в EventBus канал market:{ticker}:{timeframe}
SessionRuntime._SessionListener  (подписан один на сессию)
    ↓ candle close detected, обновляет скользящее окно
    ↓
SignalProcessor.process_candle(session, candles=history + [candle])
    ↓ (стратегия в sandbox, расчёт индикаторов, генерация сигнала)
signal: BUY / SELL / HOLD
    ↓ (если BUY или SELL)
CircuitBreakerEngine.check_before_order(session, signal)
    ↓ (под per-user asyncio.Lock — см. Gotcha 5 в Develop/CLAUDE.md)
OrderManager.place_order(session, signal)
    ↓
BrokerAdapter.place_order(order)
    ↓
PositionTracker.register_order(order)
    ↓
EventBus.publish(f"trades:{session.id}", {"type": "order.placed", "latency_ms": ...})
```

Канал `trades:{session_id}` публикует 6 типов событий: `session.started`, `session.stopped`, `order.placed` (с `latency_ms`), `trade.filled`, `trade.closed`, `cb.triggered`. Все Decimal-поля в payload'ах сериализуются строкой (Gotcha 1).

**Требование по latency:** Весь путь от получения свечи до `BrokerAdapter.place_order()` < 500ms. Для этого: стратегия предзагружена в RAM, индикаторы обновляются инкрементально, история свечей хранится в памяти runtime, listener не тянет её каждый раз заново.

**5.4.3 Восстановление при перезапуске:**

При старте `main.py lifespan`:
1. Создаётся единственный экземпляр `SessionRuntime(AsyncSessionLocal)`.
2. `SELECT * FROM trading_sessions WHERE status IN ('active', 'paused')`.
3. `await runtime.restore_all(sessions)`:
   - Для каждой сессии — если `timeframe` задан, создаётся listener на `market:{ticker}:{timeframe}`, предзагружается история. Legacy-сессии без `timeframe` пропускаются с warning.
   - **Paper-часть** реализована в S5R.2: подписка на EventBus, возобновление мониторинга.
   - **Real-часть** (сверка позиций с брокером для `mode=real` + подписка `StreamManager.subscribe`) — задача Sprint 6 **6.4 Recovery**.
4. При расхождении позиций с брокером — пауза + уведомление (6.4).
5. При остановке backend — `await runtime.shutdown()` отписывает все listener'ы и отменяет background-tasks (задел для 6.5 Graceful Shutdown).

**5.4.5 StreamManager (Market Data gRPC):**

- `app/market_data/stream_manager.py` поддерживает **одно** persistent gRPC `MarketDataStream` к T-Invest.
- Мультиплексирует подписки по ключу `(ticker, timeframe)`. Map `_TIMEFRAME_TO_INTERVAL` транслирует таймфреймы системы в T-Invest enum.
- Auto-reconnect с exponential backoff при разрыве.
- Rate limiting через `TokenBucketRateLimiter` (см. Gotcha 4 в `Develop/CLAUDE.md`).

**5.4.4 Paper Trading Engine:**

- Отдельная реализация `PaperBrokerAdapter`, совместимая с интерфейсом `BaseBrokerAdapter`.
- Исполнение ордеров по текущей рыночной цене + slippage (настроенный).
- Эмуляция T+1: блокировка средств на 1 день.
- Баланс и позиции хранятся в `paper_portfolios` и `live_trades`.

### 5.5 Broker Adapter

**Ответственный: BACK1**

**5.5.1 Абстрактный интерфейс:**

```python
class BaseBrokerAdapter(ABC):
    @abstractmethod
    async def connect(self) -> None: ...

    @abstractmethod
    async def disconnect(self) -> None: ...

    @abstractmethod
    async def get_accounts(self) -> list[BrokerAccount]: ...

    @abstractmethod
    async def get_balance(self, account_id: str) -> AccountBalance: ...

    @abstractmethod
    async def get_positions(self, account_id: str) -> list[Position]: ...

    @abstractmethod
    async def place_order(self, order: OrderRequest) -> OrderResponse: ...

    @abstractmethod
    async def cancel_order(self, order_id: str, account_id: str) -> None: ...

    @abstractmethod
    async def get_order_status(self, order_id: str, account_id: str) -> OrderStatus: ...

    @abstractmethod
    async def get_historical_candles(
        self, ticker: str, timeframe: str,
        from_dt: datetime, to_dt: datetime
    ) -> list[Candle]: ...

    @abstractmethod
    async def subscribe_candles(
        self, ticker: str, timeframe: str,
        callback: Callable[[Candle], Awaitable[None]]
    ) -> SubscriptionHandle: ...

    @abstractmethod
    async def subscribe_orderbook(
        self, ticker: str, depth: int,
        callback: Callable
    ) -> SubscriptionHandle: ...

    @abstractmethod
    async def subscribe_trades(
        self, ticker: str, callback: Callable
    ) -> SubscriptionHandle: ...

    @abstractmethod
    async def search_instruments(self, query: str) -> list[InstrumentInfo]: ...

    @abstractmethod
    async def get_instrument_info(self, ticker: str) -> InstrumentInfo: ...

    @abstractmethod
    async def get_operations(
        self, account_id: str, from_dt: datetime, to_dt: datetime
    ) -> list[Operation]: ...
```

**5.5.2 T-Invest реализация:**

- gRPC-клиент через `tinkoff.invest.AsyncClient`.
- `StreamManager` — управление gRPC-стримами (candles, orderbook, trades). Одно gRPC-соединение, мультиплексирование подписок.
- Rate limiter: token bucket, 300 req/min (unary). Отдельная очередь для market data и trade operations.
- Автоматическое переподключение: exponential backoff 1s -> 2s -> 4s -> ... -> 60s, до 10 попыток.
- Token bucket state сохраняется в файл `data/.rate_limit_state` при graceful shutdown и восстанавливается при старте — для предотвращения превышения лимитов брокера при быстром рестарте.
- Маппер `TInvestMapper` — конвертирует Protobuf-объекты в доменные модели.
- **Sandbox vs Production (per-account):** Поле `BrokerAccount.is_sandbox` определяет, к какому эндпоинту подключается адаптер (`sandbox-invest-public-api.tbank.ru` или `invest-public-api.tbank.ru`). Тип токена определяется автоматически при подключении через пробный вызов `get_accounts()` / `get_sandbox_accounts()`. Sandbox-аккаунты доступны только при `DEBUG=true`.

**5.5.3 MOEX ISS fallback:**

- HTTP REST-клиент через `httpx.AsyncClient`.
- Используется только для исторических данных (OHLCV), торгового календаря и информации об инструментах.
- Не поддерживает торговые операции.
- Endpoint: `https://iss.moex.com/iss/`

**5.5.4 Фабрика:**

```python
class BrokerFactory:
    _adapters = {"tinvest": TInvestAdapter}

    @classmethod
    def create(cls, broker_type: str, credentials: dict) -> BaseBrokerAdapter:
        adapter_class = cls._adapters.get(broker_type)
        if not adapter_class:
            raise UnsupportedBrokerError(broker_type)
        return adapter_class(**credentials)
```

### 5.6 Market Data Service

**Ответственный: BACK1**

**Функции:**
1. `get_candles(ticker, timeframe, from_dt, to_dt)` — проверяет кеш в `ohlcv_cache`, дозагружает отсутствующее через брокер, сохраняет в кеш, возвращает DataFrame.
2. `subscribe_realtime(ticker, timeframe, callback)` — создаёт подписку через `BrokerAdapter.subscribe_candles()`.
3. `validate_data(df, ticker, timeframe)` — вызов `OHLCVValidator`.
4. `check_cache_coverage(ticker, timeframe, from_dt, to_dt)` — определяет, какие участки нужно загрузить.

**Алгоритм загрузки с учётом rate limits:**

Для T-Invest: данные загружаются порциями не более 1 года за запрос (для дневного ТФ). Для минутного ТФ — порции по 1 день. Между запросами — пауза, рассчитанная по token bucket.

**Алгоритм выбора источника рыночных данных:**

```
Приоритет:
1. Production-аккаунт T-Invest (is_sandbox=false, is_active=true)
   → MarketDataService, 600 req/min, точные данные
2. MOEX ISS (бесплатный публичный API, без токена)
   → Fallback, менее точные данные

Sandbox-аккаунт НИКОГДА не используется для получения рыночных данных:
- MarketDataService недоступен через sandbox-эндпоинт T-Invest
- Sandbox-эндпоинт содержит только SandboxService (эмуляция торговли)

При конфликте в ohlcv_cache:
- Данные T-Invest перезаписывают данные MOEX ISS (более точные)
- Данные MOEX ISS не перезаписывают данные T-Invest (ON CONFLICT DO NOTHING)
```

**Sandbox T-Invest — режим разработки:**

Sandbox-аккаунты доступны только при `DEBUG=true`. Используются для тестирования интеграции с API T-Invest (отправка ордеров в sandbox-среду). Обычному пользователю в production sandbox-токен добавить нельзя — система автоматически определяет тип токена и отклоняет sandbox в non-DEBUG режиме.

Подробная документация по T-Invest API: `tinvest_api_overview.md`, `tinvest_api_services.md`, `tinvest_api_sandbox.md`.

**Реал-тайм данные:**

`RealtimeDataManager` ведёт словарь активных подписок `{(ticker, timeframe): [callbacks]}`. При первой подписке на пару — создаёт подписку у брокера. При последней отписке — отменяет. Свечи агрегируются из tick-данных, если брокер не предоставляет свечной стрим нужного ТФ.

**5.6.5 Bond Service (расчёт НКД для облигаций):**

```python
class BondService:
    async def get_bond_info(self, ticker: str) -> BondInfo:
        """Получает параметры выпуска: номинал, ставка купона, даты купонов, периодичность.
        Источник: MOEX ISS API /iss/securities/{ticker}.json
        Кеширование: таблица bond_info_cache, обновление раз в сутки."""
        ...

    def calculate_nkd(self, bond: BondInfo, date: date) -> Decimal:
        """НКД = (Номинал × Ставка купона / 100) × (Дней с последнего купона / Дней в купонном периоде)
        Используется при расчёте P&L в бэктесте и боевой торговле облигациями."""
        ...

    async def get_nkd_at_date(self, ticker: str, date: date) -> Decimal:
        """Обёртка: получить BondInfo + рассчитать НКД на указанную дату."""
        ...
```

### 5.7 Notification Service — ✅ реализовано S6

**Ответственный: BACK2 (core) + OPS (deploy)**

**Архитектура (реализация S6):**
- `NotificationService` (`app/notification/service.py`) — ядро маршрутизации: `create_notification()`, `listen_session_events()`, `stop_listening()`, `dispatch_external()`.
- Инстанциируется в `main.py` lifespan как `app.state.notification_service`.
- `listen_session_events()` вызывается при старте каждой торговой сессии через `engine.py`.
- EVENT_MAP: 6 типов событий (session_started/stopped, order_placed, trade_filled/closed, cb_triggered).
- Lazy-init нотификаторов: `TelegramNotifier` и `EmailNotifier` создаются только при наличии соответствующих env-переменных.
- Маршрутизация на основе `user_notification_settings`.

**TelegramNotifier** (`app/notification/telegram.py`):
- Библиотека: `python-telegram-bot` v20+ в webhook-режиме.
- Webhook endpoint: `POST /api/v1/notification/telegram/webhook`.
- Верификация webhook через `X-Telegram-Bot-Api-Secret-Token`.
- HTML parse_mode, severity→emoji маппинг, inline-кнопки для session/trade.
- **Привязка:** `POST /api/v1/notification/telegram/link-token` → 6-значный токен (TTL 5 мин, in-memory store). Пользователь отправляет `/start <токен>` боту.
- **Webhook handler** (`app/notification/telegram_webhook.py`): команды `/start` (привязка), `/positions`, `/status`, `/help` + callback queries.
- ⚠️ Stack Gotcha 17: `patch.object(bot_instance, ...)` невозможен из-за frozen attrs v20+. Мокировать через `patch.object(type(bot), ...)`.

**EmailNotifier** (`app/notification/email.py`):
- SMTP через `aiosmtplib`, HTML-шаблон, severity-маппинг цветов.
- Используется только для критических событий (circuit breaker, потеря связи, дневная статистика, восстановление).
- Настраивается в `.env`: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`.

**InAppNotifier:**
- `create_notification()` создаёт запись в `notifications`.
- EventBus publish → WS канал `notifications:{user_id}`.

**REST API** (`app/notification/router.py`): 6 + 2 endpoints:
- `GET /api/v1/notifications` — лента с пагинацией
- `GET /api/v1/notifications/unread-count` — счётчик
- `PATCH /api/v1/notifications/{id}/read` — пометить прочитанным
- `PUT /api/v1/notifications/read-all` — прочитать все
- `GET /api/v1/notifications/settings` — настройки каналов
- `PUT /api/v1/notifications/settings/{event_type}` — обновить настройку
- `POST /api/v1/notification/telegram/link-token` — генерация токена привязки
- `POST /api/v1/notification/telegram/webhook` — Telegram webhook

**dispatch_external** (`app/notification/dispatchers.py`):
- Реальная реализация: поиск TelegramLink/User.email в БД, вызов `TelegramNotifier.send()` и `EmailNotifier.send()`.
- Возвращает `list[str]` каналов, куда отправлено.

### 5.8 Circuit Breaker

**Ответственный: SEC (логика) + BACK1 (интеграция)**

```python
class CircuitBreakerService:
    async def check_before_order(self, session: TradingSession, signal: Signal) -> CheckResult:
        """Вызывается перед каждым ордером. Возвращает ALLOW или BLOCK с причиной."""
        checks = [
            self._check_daily_loss_limit(session),
            self._check_max_drawdown(session),
            self._check_position_size_limit(signal),
            self._check_daily_trade_limit(session),
            self._check_duplicate_instrument(session, signal),
            self._check_cooldown(session),
            self._check_trading_hours(signal),
            self._check_short_block(signal),
            self._check_insufficient_funds_streak(session),
        ]
        for check in checks:
            result = await check
            if result.blocked:
                await self._trigger(session, result.reason)
                return result
        return CheckResult(blocked=False)

    async def _trigger(self, session, reason):
        """Ставит стратегию/все стратегии на паузу, отправляет уведомления."""
        ...
```

**Расчёт дневных убытков:**
- Агрегация `SUM(pnl)` по `live_trades` за текущий торговый день. Начало торгового дня определяется по рынку инструмента: фондовый/долговой — 10:00 MSK, валютный — 10:00 MSK (несмотря на продлённую сессию до 23:50). Сброс дневных счётчиков — в 10:00 MSK следующего торгового дня по календарю MOEX.
- Плюс unrealized P&L открытых позиций (текущая цена - цена входа).
- Сравнение с `user.risk_daily_loss_pct * account_balance` или `user.risk_daily_loss_fixed`.

**Max drawdown:**
- `peak_equity` обновляется при каждом закрытии позиции.
- `current_drawdown = (peak_equity - current_equity) / peak_equity * 100`.
- При `current_drawdown >= user.risk_max_drawdown_pct` -> trigger.

**Нехватка средств (insufficient funds streak):**
- Поле `trading_sessions.consecutive_fund_skips` (Integer, DEFAULT 0).
- При пропуске сигнала из-за нехватки средств — инкремент `consecutive_fund_skips`.
- При успешном размещении ордера — сброс в 0.
- При `consecutive_fund_skips >= 3` — автоматическая пауза стратегии + уведомление во все каналы.

### 5.9 Scheduler

**Ответственный: BACK1**

Реализация на `APScheduler` (AsyncIOScheduler). Jobs:

| Job | Расписание | Описание |
|---|---|---|
| `update_moex_calendar` | Ежедневно 06:00 MSK | Загрузка торгового календаря и расписания сессий из MOEX ISS |
| `update_moex_sessions` | Ежедневно 06:00 MSK | Обновление расписания торговых сессий |
| `daily_backup` | Ежедневно 01:00 MSK | Бэкап SQLite (через `sqlite3 .backup`) |
| `cleanup_revoked_tokens` | Ежедневно 03:00 MSK | Удаление истёкших revoked JWT |
| `send_daily_stats` | Ежедневно 19:00 MSK (после закрытия фондового) | Дневная статистика в Telegram и email |
| `refresh_instrument_info` | Еженедельно вс 12:00 | Обновление данных об инструментах (лотность, шаг цены) |
| `check_corporate_actions` | Ежедневно 08:00 MSK | Проверка дивидендов/сплитов через MOEX ISS |
| `reset_ai_daily_usage` | Ежедневно 00:00 MSK | Сброс `usage_today` в `ai_provider_configs` |
| `reset_ai_monthly_usage` | 1-е число месяца 00:00 MSK | Сброс `usage_month` в `ai_provider_configs` |

**MOEX Calendar Service:**

```python
class MOEXCalendarService:
    async def is_trading_day(self, date: date, market: str = 'stock') -> bool: ...
    async def get_session_times(self, market: str) -> SessionTimes: ...
    async def is_trading_hours(self, dt: datetime, market: str) -> bool: ...
    async def next_trading_day(self, date: date) -> date: ...
```

Fallback-значения (если MOEX ISS недоступен) захардкожены в config.

### 5.10 AI Service

**Ответственный: BACK2 (AI-интеграция)**

**5.10.1 Pluggable Provider Architecture:**

```python
class BaseLLMProvider(ABC):
    @abstractmethod
    async def chat(self, messages: list[Message], system_prompt: str) -> LLMResponse: ...

    @abstractmethod
    async def stream_chat(self, messages: list[Message], system_prompt: str) -> AsyncGenerator[str, None]: ...

    @abstractmethod
    def count_tokens(self, text: str) -> int: ...

class ClaudeProvider(BaseLLMProvider):
    def __init__(self, api_key: str, model: str = "claude-sonnet-4-6-20250514"):
        ...

class OpenAIProvider(BaseLLMProvider):
    def __init__(self, api_key: str, model: str = "gpt-4o"):
        ...
```

**Конфигурация AI — двойной источник (БД + .env):**

Приоритет: **БД > .env**. Если в БД есть активный `ai_provider_configs` с `is_active=True` — используется он. Если нет — fallback на переменные `.env`. Это позволяет:
- Настроить AI-провайдера через UI (основной сценарий для пользователя)
- Использовать `.env` как fallback для автоматизированных/серверных сценариев

**Хранение API-ключей в БД:**
- Ключ шифруется тем же `CryptoService` (AES-256-GCM), что используется для брокерских ключей.
- В UI ключ отображается маскированным (первые 4 + последние 4 символа).
- При добавлении нового провайдера — рекомендация выполнить verify (тестовый запрос).
- Сброс `usage_today` — ежедневно через scheduler (новый job `reset_ai_daily_usage`). Сброс `usage_month` — первого числа каждого месяца.

**Логика выбора провайдера при запросе к AI:**
```python
async def get_active_provider(self, user_id: int) -> BaseLLMProvider:
    # 1. Проверить БД: ai_provider_configs WHERE user_id=X AND is_active=True
    db_config = await self.repo.get_active(user_id)
    if db_config:
        api_key = self.crypto.decrypt(db_config.encrypted_api_key, db_config.encryption_iv)
        return self.create_provider(db_config.provider_type, api_key, db_config.model_id, db_config.api_base_url)
    # 2. Fallback на .env
    if settings.AI_API_KEY:
        return self.create_provider(settings.AI_PROVIDER, settings.AI_API_KEY, settings.AI_MODEL)
    # 3. AI недоступен
    raise AIProviderNotConfiguredError("AI-провайдер не настроен. Настройте в разделе Настройки → AI.")
```

**Fallback-конфигурация в `.env`:**
```
AI_PROVIDER=claude            # 'claude' | 'openai' — используется только если в БД нет активного провайдера
AI_API_KEY=                   # Используется только если в БД нет активного провайдера
AI_MODEL=claude-sonnet-4-6-20250514
AI_DAILY_LIMIT=100
AI_MONTHLY_LIMIT=3000
```

**Поддерживаемые провайдеры:**

| provider_type | API | Примечание |
|---|---|---|
| `claude` | Anthropic Messages API | Модели Claude Sonnet / Opus |
| `openai` | OpenAI Chat Completions API | Модели GPT-4o / GPT-4.1 |
| `deepseek` | OpenAI-совместимый | deepseek-chat, deepseek-reasoner. Base URL: `https://api.deepseek.com/v1` |
| `gemini` | OpenAI-совместимый | Gemini 2.5-pro, 2.5-flash. Base URL: `https://generativelanguage.googleapis.com/v1beta/openai` |
| `mistral` | OpenAI-совместимый | Mistral large, medium, small. Base URL: `https://api.mistral.ai/v1` |
| `groq` | OpenAI-совместимый | Llama 3.3-70b, Mixtral 8x7b. Base URL: `https://api.groq.com/openai/v1` |
| `qwen` | OpenAI-совместимый | Qwen plus, turbo, max. Base URL: `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| `openrouter` | OpenAI-совместимый | Любая модель через OpenRouter. Base URL: `https://openrouter.ai/api/v1` |
| `custom` | OpenAI-совместимый API | Для локальных LLM (Ollama, LM Studio и др.). Указывается `api_base_url` |

**5.10.2 Системный промпт:**

```
Ты — AI-ассистент в торговом терминале для рынка MOEX. Помогаешь трейдерам создавать и оптимизировать торговые стратегии.

КОНТЕКСТ РЫНКА:
- Московская биржа (MOEX): акции, облигации, ETF/БПИФ, валютные пары
- Основная сессия фондового рынка: 10:00–18:40 MSK
- Лотность: акции торгуются лотами (например, SBER = 10 акций в лоте)
- Валюта: рубль (₽)
- Только длинные позиции (long). Short недоступен.
- Фьючерсы не поддерживаются.

ДОСТУПНЫЕ ИНДИКАТОРЫ:
SMA, EMA, Bollinger Bands, RSI, MACD, Stochastic, ATR, Volume MA, и другие из TA-Lib.

ТВОЯ ЗАДАЧА:
1. Помочь пользователю сформулировать торговую стратегию.
2. Задать уточняющие вопросы для полноты описания.
3. Предложить блочную схему стратегии в формате JSON.
4. Объяснить преимущества и риски предложенных решений.

ФОРМАТ БЛОЧНОЙ СХЕМЫ:
{JSON schema описание}

Отвечай на русском языке. Будь конкретен и прагматичен.
```

**5.10.3 Контекстное сжатие:**

При превышении 80% лимита контекстного окна модели:
1. Суммаризировать предыдущие сообщения в один блок.
2. Сохранить последние 3 сообщения и финальное решение.
3. Уведомить пользователя.

**5.10.4 Rate Limiting / Budget:**

`AIBudgetTracker` хранит количество использованных запросов в `daily_stats` (или in-memory counter, который flush-ится в БД). При достижении лимита -> возврат ошибки, UI переключается на режим B.

### 5.11 Code Sandbox

**Ответственный: SEC**

**5.11.1 AST-анализ (pre-execution):**

```python
class ASTAnalyzer:
    FORBIDDEN_NAMES = {
        'eval', 'exec', 'compile', '__import__', 'getattr', 'setattr',
        'delattr', 'globals', 'locals', 'vars', 'dir', 'type',
        'open', 'input', 'breakpoint', '__builtins__', '__subclasses__',
    }

    ALLOWED_IMPORTS = {
        'backtrader', 'bt', 'pandas', 'pd', 'numpy', 'np',
        'talib', 'ta', 'datetime', 'math',
    }

    def analyze(self, code: str) -> AnalysisResult:
        tree = ast.parse(code)
        violations = []
        for node in ast.walk(tree):
            # Check imports (итерация по всем именам — import os, sys)
            if isinstance(node, ast.Import):
                for alias in node.names:
                    root_module = alias.name.split('.')[0]
                    if root_module not in self.ALLOWED_IMPORTS:
                        violations.append(f"Запрещённый импорт: {alias.name}")
            elif isinstance(node, ast.ImportFrom):
                root_module = node.module.split('.')[0] if node.module else ''
                if root_module not in self.ALLOWED_IMPORTS:
                    violations.append(f"Запрещённый импорт: {node.module}")

            # Check forbidden calls
            if isinstance(node, ast.Call):
                name = self._get_call_name(node)
                if name in self.FORBIDDEN_NAMES:
                    violations.append(f"Запрещённый вызов: {name}")

            # Check attribute access to __dunder__
            if isinstance(node, ast.Attribute):
                if node.attr.startswith('__') and node.attr.endswith('__'):
                    if node.attr not in ('__init__', '__next__'):
                        violations.append(f"Запрещённый доступ: {node.attr}")

        return AnalysisResult(is_safe=len(violations)==0, violations=violations)
```

**5.11.2 Исполнение:**

```python
class SandboxExecutor:
    CPU_LIMIT_SECONDS = 30
    MEMORY_LIMIT_MB = 512

    def execute_backtest(self, code: str, data: pd.DataFrame, params: dict) -> BacktestResult:
        # 1. AST анализ
        analysis = self.ast_analyzer.analyze(code)
        if not analysis.is_safe:
            raise UnsafeCodeError(analysis.violations)

        # 2. Compile через RestrictedPython
        byte_code = compile_restricted(code, '<strategy>', 'exec')

        # 3. Запуск в subprocess с ограничениями
        # Используем multiprocessing.Process с resource.setrlimit
        result = self._run_in_subprocess(byte_code, data, params)
        return result

    def _run_in_subprocess(self, byte_code, data, params):
        """Запуск в отдельном процессе с лимитами CPU и RAM."""
        # resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
        # resource.setrlimit(resource.RLIMIT_AS, (512*1024*1024, 512*1024*1024))
        ...
```

**Ограничение ресурсов по платформам:**
- **Linux:** `resource.setrlimit(RLIMIT_CPU)` + `resource.setrlimit(RLIMIT_AS)` — полноценная поддержка.
- **macOS:** `resource.setrlimit(RLIMIT_CPU)` работает; `RLIMIT_AS` игнорируется ядром — использовать мониторинг через `psutil.Process().memory_info().rss` каждые 0.5 сек в отдельном потоке с принудительным `Process.kill()` при превышении лимита 512 МБ.
- **Windows:** `psutil` для мониторинга CPU-времени и RAM + `Process.kill()` при превышении лимитов.

### 5.12 Corporate Action Handler

**Ответственный: BACK1**

Модуль обработки корпоративных действий (сплиты, дивиденды, купоны).

**Источник данных:** MOEX ISS API (`/iss/securities/{ticker}/dividends.json`, `/iss/statistics/engines/stock/markets/shares/securities/{ticker}`). Проверка ежедневно в 08:00 MSK через scheduler job `check_corporate_actions`.

**Логика обработки:**

```python
class CorporateActionHandler:
    async def process_split(self, action: CorporateAction) -> None:
        """Сплит: для всех open live_trades по тикеру — пересчёт
        entry_price (÷ ratio) и volume_lots (× ratio).
        Запись в audit_log. Уведомление пользователю."""
        ...

    async def process_dividend(self, action: CorporateAction) -> None:
        """Дивиденд: создание записи в daily_stats с учётом суммы
        (amount_per_share × volume). Уведомление пользователю."""
        ...

    async def process_coupon(self, action: CorporateAction) -> None:
        """Купон по облигации: аналогично дивиденду, с учётом НКД
        через BondService.calculate_nkd()."""
        ...
```

### 5.13 Tax Report Generator

**Ответственный: BACK1**

Модуль: `export/tax_report.py`

**Логика формирования налогового отчёта для 3-НДФЛ:**
- Метод **FIFO** для определения финансового результата по закрытым сделкам.
- Раздельный учёт: акции, облигации (+ купонный доход отдельной строкой), ETF/БПИФ.
- Группировка по налоговым периодам (календарный год).
- Учёт комиссий брокера (уменьшают налогооблагаемую базу).
- Для облигаций: разделение ценовой составляющей и НКД.
- Колонки экспорта: дата сделки, тикер, ISIN, направление, цена покупки, цена продажи, объём (лоты / штуки), комиссия, финансовый результат.
- Форматы: xlsx (`openpyxl`), csv.

---

## 6. FRONTEND-МОДУЛИ: ДЕТАЛЬНАЯ СПЕЦИФИКАЦИЯ

**Ответственный: FRONT1 + FRONT2 (реализация), UX (дизайн, ревью)**

### 6.1 Layout / Shell

- Тёмная тема: CSS-переменные `--bg-primary: #1a1a2e`, `--bg-secondary: #16213e`, `--text-primary: #e0e0e0`, `--accent: #0f3460`, `--green: #00b894`, `--red: #e74c3c`.
- Left Sidebar (ширина 60px свёрнутая, 240px развёрнутая): иконки + текст для разделов (Дашборд, Стратегии, Бэктесты, Торговля, Счёт, Настройки).
- Header (48px): логотип, виджет баланса (компактный), индикатор здоровья (цветной кружок), колокольчик уведомлений (с badge), username.
- Content area: занимает оставшееся пространство.
- Минимальная поддерживаемая ширина: 1280px.
- Русский язык всюду. Формат чисел: `Intl.NumberFormat('ru-RU')`. Формат дат: `DD.MM.YYYY`.

### 6.2 Dashboard (Главный дашборд)

**Маршрут:** `/`

**Компоненты:**
- `StrategyTable` — таблица стратегий с колонками из ФТ 3.1. TanStack Table с сортировкой по любой колонке. Цветная плашка статуса. Для каждой строки — dropdown с действиями (Открыть, Бэктест, Запустить торговлю, Архивировать).
- `BalanceWidget` — карточка справа: баланс Real + баланс Paper (раздельно). Суммарный unrealized P&L всех активных стратегий. Обновление через WebSocket.
- `QuickActions` — кнопки "Новая стратегия", "Быстрый бэктест".
- `ActiveStrategiesCards` — горизонтальная лента карточек активных стратегий (Real и Paper): тикер, P&L, мини-sparkline.

### 6.3 Strategy Editor

**Маршрут:** `/strategies/:id`

**Две вкладки:** «Содержание» и «Редактор».

**Вкладка «Содержание»:** Описание стратегии (textarea) + параметры (стоп-лосс, тейк-профит, размер позиции).

**Вкладка «Редактор» — два режима:**

**Режим Blockly (по умолчанию):**
- **Слева:** Blockly workspace с кастомным toolbox (Mantine Accordion, сворачиваемый 240→0px).
- **Справа:** SharedDescriptionPanel — описание стратегии + кнопки «AI-помощник», «Пустой шаблон», «Применить на схеме», «Заполнить по схеме».
- **Внизу:** toolbar (Zoom+/-, Undo, Redo, Очистить, Генерировать, Запустить бэктест).

**Режим AI-помощник (свайп-анимация 300ms):**
- **Слева (40%):** описание стратегии (редактируемый textarea).
- **Справа (60%):** AI-чат (SSE streaming). Header: выбор провайдера (dropdown), счётчик запросов. Кнопки: «Очистить историю», «Вернуться к редактору».
- Resizable разделитель (PanelGroup).

**Blockly-конфигурация — кастомные категории:**
- **Индикаторы:** SMA, EMA, RSI, MACD, Bollinger, ATR, Stochastic, CCI, Volume. Каждый — блок с параметрами (период, source, описание).
- **Условия:** Crossover, CrossUnder, GreaterThan, LessThan, InZone, Timeframe.
- **Логика:** AND, OR, NOT.
- **Сигналы:** EntryLong, ExitLong. Динамическое количество условий И/ИЛИ (N входов).
- **Фильтры:** TimeFilter, DayOfWeekFilter.
- **Управление капиталом:** PositionSizer (%), StopLoss (%), TakeProfit (%).

Кнопка «Генерировать» запускает генерацию Python-кода по блочной схеме. Код отображается в панели. Кнопка disabled без блоков на workspace.

Кнопка «Запустить бэктест» → BacktestLaunchModal. Disabled если код устарел (блоки ≠ код) или содержит ошибки.
- Modal с textarea для вставки + кнопка "Скопировать шаблон" (копирует Приложение A в clipboard).
- При нажатии "Распознать" -> `POST /api/v1/strategies/{id}/parse-template` -> блоки загружаются в Blockly workspace.

### 6.4 Charts (Графический модуль)

**Маршрут:** `/charts/:ticker` (standalone) или встроен в другие экраны.

**Компоненты:**
- `CandlestickChart` — TradingView Lightweight Charts. `createChart()` с dark theme config.
- `VolumePane` — отдельная панель внизу (histogram).
- `IndicatorPanel` — dropdown сверху для добавления индикаторов. Каждый индикатор — отдельная LineSeries/HistogramSeries. Настройки: период, цвет (ColorPicker), толщина.
- `TimeframeSelector` — кнопки 1м | 5м | 15м | 1ч | 4ч | Д | Н | М.
- `TradeMarkers` — маркеры на графике (треугольник вверх = вход, треугольник вниз = выход) через `chart.addMarkers()`.
- `DrawingTools` (Should) — toolbar справа: Trendline, Horizontal, Rectangle. Координаты сохраняются через API.
- `OrderBookPanel` (Could) — выдвижная панель справа с уровнями bid/ask.
- `TradesStreamPanel` (Could) — лента сделок внизу.

**Real-time:**
При открытии графика: `ws.send({action: "subscribe", channel: "market:SBER:D"})`. При получении candle — `series.update(candle)`. При закрытии — `ws.send({action: "unsubscribe", ...})`.

### 6.5 Backtest Results

**Маршрут:** `/backtests/:id`

**Четыре вкладки:**

**Tab "Обзор":**
- Сетка метрик (SimpleGrid 4×2): Чистая прибыль (₽ + %), Кол-во сделок, Доля прибыльных (Win Rate), Профит-фактор, Макс. просадка, Коэффициент Шарпа (по дневным доходностям), Ср. P&L на сделку (среднее по ВСЕМ), Ср. длительность (часы/дни по ТФ).
- Цветовая кодировка: хорошо (#1a2e1a/#69db7c), нейтрально (#25262B/#C1C2C5), плохо (#2e1a1a/#ff8787). Макс. просадка — всегда нейтральный.
- Benchmark-сравнение: горизонтальные бары (Стратегия / Buy & Hold / IMOEX).
- Кнопки CSV и PDF в header.

**Tab "График":**
- Свечной график с маркерами: вход ▲ зелёный (low свечи, 2x), выход ▼ красный (high свечи, 2x). Текст — лоты (фиксированный шрифт, canvas overlay).
- Зоны сделок: цветные полосы между входом и выходом (зелёная = прибыль, красная = убыток).

**Tab "Показатели":**
- Equity curve (LineSeries зелёная #69db7c) + drawdown (AreaSeries красная #ff8787) + Buy & Hold (серая #868E96) + IMOEX (синяя #74C0FC).
- Toggle ₽ / % для переключения шкалы. Метрики в левой панели. Легенда.

**Tab "Сделки":**
- `TanStack Table`: #, Тип (Long/Short), Вход (дата+цена, двустрочная ячейка), Выход, Объём, P&L (зелёный/красный), Длительность, Комиссия.
- Фильтр SegmentedControl: Все (N) / Прибыльные (N) / Убыточные (N).
- Сортировка, пагинация (10 записей/страница). Кнопка "Экспорт CSV".

**Прогресс бэктеста:**
Во время выполнения — progress bar + текущая дата через WebSocket `backtest:{id}`.

### 6.6 Trading Panel

**Маршрут:** `/trading`

**Компоненты:**
- `ActiveSessionsList` — карточки всех активных сессий. Каждая карточка: тикер, стратегия, **badge таймфрейма** (`1m`/`5m`/.../`D`/`W`/`M`, прочерк для legacy), режим (PAPER жёлтый / REAL красный), unrealized P&L, sparkline, кнопки (Пауза, Стоп, График).
- `SessionDashboard` (`/trading/sessions/:id`) — детальный дашборд сессии:
  - Открытые позиции (таблица): тикер, направление, цена входа, текущая цена, unrealized P&L, время удержания, кнопки (Закрыть, График).
  - Закрытые сделки (таблица).
  - Статистика: дневной P&L, суммарный P&L, Win Rate, количество сделок.
  - Equity curve сессии.
- `LaunchSessionModal` — модалка: выбор стратегии (dropdown), брокерский аккаунт (dropdown), счёт (dropdown), инструмент (search), **селектор таймфрейма** (`<Select data-testid="session-timeframe-select">`, 8 значений, `D` по умолчанию, required), режим (Paper/Real toggle), sizing settings. Для Real — confirm-диалог с предупреждением.

### 6.7 Account / Settings

**Маршрут:** `/account` и `/settings`

**Account (раздел «Счёт»):**
- `BalanceCards` — баланс по каждому брокерскому счёту + валюте (таблица). Мульти-валютность: `RUB`/`USD`/`EUR`/`HKD`/`CNY` без автоконвертации в рубли.
- `PositionsTable` — позиции у брокера (включая внесистемные), колонки: тикер, название, instrument_type, quantity, avg_price, current_price, unrealized_pnl, currency, **badge `source`** (`Стратегия` / `Внешняя`), blocked.
  - Все Decimal-поля приходят с backend как строки (см. Gotcha 1 в `Develop/CLAUDE.md`) и парсятся на фронте через `toNum()`.
- `OperationsTable` — история операций с фильтром по дате (`from`/`to`) и пагинацией (`offset`/`limit` ≤ 500). Типы: `BUY`/`SELL`/`DIVIDEND`/`COUPON`/`COMMISSION`/`TAX`/`OTHER`, состояния: `EXECUTED`/`CANCELED`/`PROGRESS`. Иконки для типов.
- Кнопка «Налоговый отчёт» (экспорт).

**Settings:**
- **Профиль:** смена пароля, email.
- **Брокеры:** список подключённых, добавление нового (форма: тип, API-ключ, discover → выбор счетов), удаление. Ключ отображается маскированным.
- **Telegram:** привязка (показ токена, QR-код), статус привязки, отвязка.
- **Уведомления:** матрица event_type × channel (чекбоксы).
- **Риск-менеджмент:** поля из профиля пользователя (daily loss, max drawdown, position size, trade limit).
- **AI-провайдеры:** список подключённых провайдеров (таблица: имя, тип, модель, статус, использование). Добавление нового (форма: тип провайдера [Claude/OpenAI/Custom], API-ключ, модель, base URL для custom). Кнопка «Проверить ключ» (тестовый запрос). Переключение активного провайдера. Ключ отображается маскированным. Счётчик использования (сегодня/месяц) и лимиты.
- **Система:** директория для бэкапов, ротация, ручной бэкап, логи.

### 6.8 Notification Center

**Компоненты:**
- `NotificationBell` (в Header) — иконка колокольчика с badge (unread_count). При клике — выдвижная панель справа.
- `NotificationPanel` — список уведомлений (бесконечный скролл). Каждое: иконка severity, заголовок, время (relative: "5 мин назад"), клик → детали / навигация.
- `CriticalBanner` — красный баннер на полную ширину для severity = critical. Отображается поверх контента. Кнопка "Закрыть".
- WebSocket `notifications` канал для push в реальном времени.

### 6.9 Zustand Stores

```
authStore:      { user, token, isAuthenticated, login(), logout(), refresh() }
strategyStore:  { strategies, current, versions, fetch(), create(), update() }
backtestStore:  { backtests, current, progress, run(), fetchResults() }
tradingStore:   { sessions, activeSession, positions, launch(), pause(), stop(), closePosition() }
marketStore:    { subscriptions, candles, orderbook, subscribe(), unsubscribe() }
notificationStore: { notifications, unreadCount, fetch(), markRead(), markAllRead() }
healthStore:    { status, components, subscribe() }
settingsStore:  { profile, brokerAccounts, notifSettings, fetch(), update() }
```

---

## 7. РЕАЛИЗАЦИЯ БЕЗОПАСНОСТИ

**Ответственный: SEC**

### 7.1 Пароли

- Алгоритм: Argon2id (библиотека `argon2-cffi`)
- Параметры: `memory_cost=65536, time_cost=3, parallelism=4, hash_len=32, salt_len=16`
- Валидация нового пароля: минимум 8 символов, минимум 1 буква + 1 цифра.

### 7.2 Шифрование API-ключей брокеров

- Алгоритм: AES-256-GCM
- Ключ шифрования: из `ENCRYPTION_KEY` в `.env` (32 байта base64-encoded)
- IV: 12 байт, генерируется `os.urandom(12)` для каждого ключа, хранится в `encryption_iv`
- Tag: 16 байт, аппендится к ciphertext

```python
# common/crypto.py
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

class CryptoService:
    def __init__(self, key: bytes):  # 32 bytes from env
        self._aesgcm = AESGCM(key)

    def encrypt(self, plaintext: str) -> tuple[bytes, bytes]:
        iv = os.urandom(12)
        ct = self._aesgcm.encrypt(iv, plaintext.encode(), None)
        return ct, iv

    def decrypt(self, ciphertext: bytes, iv: bytes) -> str:
        return self._aesgcm.decrypt(iv, ciphertext, None).decode()
```

### 7.3 JWT

- Алгоритм: HS256
- Access Token TTL: 30 минут
- Refresh Token TTL: 7 дней
- Refresh Token: одноразовый; при каждом refresh — старый инвалидируется, выдаётся новый
- При logout: access + refresh → в `revoked_tokens`
- Секрет: `JWT_SECRET_KEY` в `.env`, минимум 64 символа

> **Примечание для фазы 2:** при переходе к мультипользовательскому режиму рекомендуется миграция на RS256 (асимметричные ключи) для минимизации последствий компрометации ключа. При HS256 компрометация секрета позволяет подделать токены всех пользователей.

### 7.4 CSRF

- Backend генерирует CSRF-токен при логине, возвращает в cookie `csrf_token` (SameSite=Strict, HttpOnly=False чтобы JS мог читать).
- Frontend отправляет этот токен в заголовке `X-CSRF-Token` для всех POST/PATCH/DELETE запросов.
- Backend проверяет совпадение cookie и заголовка.
- Для WebSocket: двухэтапная авторизация (см. раздел 4.12).

### 7.5 Rate Limiting

Реализация: in-memory sliding window (через `asyncio` + `dict`).

```
Общий лимит API:        100 req/min per user
Торговые операции:       10 req/min per user
Auth (login):            5 req/min per IP
AI chat:                 10 req/min per user
```

При превышении: HTTP 429 с заголовком `Retry-After`.

### 7.6 HTTP Security Headers

```python
# middleware
response.headers["X-Content-Type-Options"] = "nosniff"
response.headers["X-Frame-Options"] = "DENY"
response.headers["X-XSS-Protection"] = "0"  # CSP вместо XSS Protection
response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self' ws://localhost:*"
response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
```

### 7.7 Маскирование секретов в логах

Middleware для structlog: фильтрует поля `api_key`, `token`, `password`, `secret` — заменяет на `****` + последние 4 символа.

### 7.8 Проверка .env при старте

```python
# config.py
class Settings(BaseSettings):
    JWT_SECRET_KEY: str     # min 64 chars
    ENCRYPTION_KEY: str     # base64, 32 bytes decoded
    AI_API_KEY: str = ""
    TELEGRAM_BOT_TOKEN: str = ""
    ...

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def jwt_key_length(cls, v: str) -> str:
        if len(v) < 64:
            raise ValueError("JWT_SECRET_KEY must be at least 64 characters")
        return v
```

При старте: проверка `os.stat('.env').st_mode` — если файл readable others, выводится WARNING.

**Защита от dev-секретов в production:**
При `DEBUG=False` — `model_validator` проверяет, что `SECRET_KEY` и `ENCRYPTION_KEY` не содержат префикс `dev-`. Если содержат — выводится `warnings.warn` с требованием задать безопасные значения в `.env`.

---

## 8. РАЗВЁРТЫВАНИЕ И ЭКСПЛУАТАЦИЯ

**Ответственный: OPS**

### 8.1 Установка и запуск (нативный, без Docker)

**Системные предусловия:**
- Python 3.11+ с pip
- Node.js 20+ с pnpm (или npm)
- Системные библиотеки: TA-Lib C library (libta-lib), компилятор C (gcc/clang)

**Конфигурация сборки (`backend/pyproject.toml`):**
- В `[tool.setuptools.packages.find]` указать `include = ["app*"]`, чтобы setuptools не включал директории `data/`, `alembic/` как пакеты (flat-layout error).

**Скрипт установки (`scripts/install.sh`):**

```bash
#!/bin/bash
set -e

echo "=== Установка MOEX Terminal ==="

# 1. Создание Python venv
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e ".[dev]"

# 2. Инициализация БД
alembic upgrade head

# 3. Установка frontend-зависимостей
cd ../frontend
pnpm install

# 4. Сборка frontend (production)
pnpm build

echo "=== Установка завершена ==="
echo "Скопируйте .env.example в .env и заполните настройки."
echo "Запуск: ./scripts/start.sh"
```

**Скрипт запуска (`scripts/start.sh`):**

```bash
#!/bin/bash
set -e

# Проверка .env
if [ ! -f .env ]; then
    echo "ОШИБКА: Файл .env не найден. Скопируйте .env.example в .env и заполните настройки."
    exit 1
fi

set -a
source .env
set +a

# Запуск backend
cd backend
source .venv/bin/activate
alembic upgrade head  # Применить новые миграции при обновлении
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload &
BACKEND_PID=$!

# Запуск frontend (dev mode) или раздача статики
cd ../frontend
pnpm dev --port 3000 &
FRONTEND_PID=$!

echo "Backend: http://127.0.0.1:8000"
echo "Frontend: http://127.0.0.1:3000"

# Graceful shutdown
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" SIGINT SIGTERM
wait
```

**Procfile (для Honcho — опциональный удобный запуск):**

```
backend: cd backend && source .venv/bin/activate && uvicorn app.main:app --host 127.0.0.1 --port 8000
frontend: cd frontend && pnpm dev --port 3000
```

**Production-режим (для финальной установки):**
- Frontend собирается через `pnpm build`, статика раздаётся через FastAPI `StaticFiles` middleware или отдельный Uvicorn static mount.
- Один процесс Uvicorn обслуживает и API, и статику frontend.
- Для автозапуска на macOS — LaunchAgent plist, на Linux — systemd unit.

### 8.2 .env.example

```
# === SECURITY ===
JWT_SECRET_KEY=CHANGE_ME_min_64_characters_long_random_string_here_please
ENCRYPTION_KEY=CHANGE_ME_base64_encoded_32_bytes

# === AI ===
AI_PROVIDER=claude
AI_API_KEY=
AI_MODEL=claude-sonnet-4-6-20250514
AI_DAILY_LIMIT=100
AI_MONTHLY_LIMIT=3000

# === TELEGRAM ===
TELEGRAM_BOT_TOKEN=

# === EMAIL (optional) ===
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
EMAIL_FROM=

# === DATABASE ===
DATABASE_URL=sqlite+aiosqlite:///./data/terminal.db

# === GENERAL ===
LOG_LEVEL=INFO
BACKUP_DIR=./backups
BACKUP_RETENTION=7
```

### 8.3 Backup

- `sqlite3 .backup` в отдельный файл с timestamp.
- Ротация: удаление файлов старше `BACKUP_RETENTION` дней.
- CLI-утилита `python -m app.cli restore --backup /path/to/backup.db`.

### 8.4 Логирование

- structlog с JSON-формато для файлов, human-readable для stdout.
- Файлы: `logs/app.log`, `logs/broker.log`, `logs/audit.log`.
- Ротация: `RotatingFileHandler`, 50 MB на файл, 5 бэкапов.
- Broker-лог: каждый gRPC/HTTP вызов с таймингом, request/response body (секреты маскированы).

### 8.5 Health Check

Endpoint `/api/v1/health` проверяет:
1. Database: `SELECT 1` с таймаутом 5с.
2. Broker connections: статус gRPC-канала для каждого активного аккаунта.
3. AI provider: последний успешный вызов < 10 мин назад → OK; иначе → probe запрос.
4. Telegram bot: проверка `getMe()`.

### 8.6 Graceful Shutdown — ✅ реализовано S6

При получении SIGTERM/SIGINT (`app/trading/runtime.py:shutdown()`):
1. Установить флаг `shutting_down = True`.
2. Прекратить приём новых HTTP-запросов.
3. Для каждой активной trading session: сохранить состояние в БД (status → 'suspended').
4. Дождаться завершения pending orders (timeout 30s) — ордера, находящиеся в процессе исполнения у брокера.
5. `stream_manager.unsubscribe_all()` — отписка от всех gRPC streaming подписок.
6. Закрыть gRPC-каналы, WebSocket-соединения.
7. Отправить `create_notification(event_type="system_shutdown", title="Система остановлена", severity="warning")` — доставляется во все 3 канала (Telegram, Email, In-app).
8. Закрыть БД-соединения.

**Recovery при следующем старте** (реализован в S5R + S6):
- `restore_all()` в `runtime.py` находит сессии со статусом `active`/`suspended`.
- Real-сессии: сверка позиций через `get_real_positions()`, расхождения → pause + critical notification.
- Paper-сессии: восстановление виртуального баланса из БД, notification `session_recovered`.
- Возобновление подписок и мониторинга через `SessionRuntime.start()`.

### 8.7 Целевые метрики производительности

| Метрика | Целевое значение | Методика замера |
|---|---|---|
| Загрузка главного дашборда | < 2 сек | От HTTP-запроса до полного ответа API (DOMContentLoaded на frontend) |
| Запуск бэктеста (5 лет, Д-таймфрейм) | < 30 сек | От `POST /backtests` до `status=completed` |
| Получение свечи → расчёт индикаторов | < 2 сек | Лог `SignalProcessor.process_candle()` |
| Генерация сигнала → отправка ордера | < 500 мс | От signal до `BrokerAdapter.place_order()` |
| Отображение сделки на графике | < 1 сек | От генерации сигнала до WS push клиенту |
| Telegram-уведомление от сделки | < 3 сек | От события до callback Telegram API |
| Доступность (локальный режим) | Best effort | Graceful shutdown при остановке |

> **Примечание:** Метрика «генерация сигнала → отправка ордера» измеряется от момента, когда стратегия сгенерировала сигнал (после расчёта индикаторов), до момента отправки ордера в API брокера. Время получения и обработки свечи учитывается отдельно (метрика «получение свечи → расчёт индикаторов»).

### 8.8 Ротация секретов

**CLI-утилиты:**

- `python -m app.cli rotate-encryption-key --old-key <base64> --new-key <base64>` — расшифровывает все API-ключи брокеров старым ключом, шифрует новым, обновляет БД в транзакции. После выполнения необходимо обновить `ENCRYPTION_KEY` в `.env`.
- `python -m app.cli rotate-jwt-secret` — добавляет все активные токены в `revoked_tokens`. Все пользователи должны перелогиниться. Перед запуском обновить `JWT_SECRET_KEY` в `.env`.

### 8.9 Стратегия миграции SQLite → PostgreSQL (фаза 2)

SQLite-специфичные решения, требующие замены при миграции:
- Триггеры `prevent_audit_delete` / `prevent_audit_update` → PostgreSQL triggers (синтаксис `CREATE FUNCTION` + `CREATE TRIGGER`).
- Partial unique `uq_active_session (WHERE status = 'active')` → PostgreSQL partial unique index (нативная поддержка).
- `sqlite3 .backup` → `pg_dump`.
- WAL mode → стандартная конфигурация PostgreSQL.
- OHLCV-кеш: добавить партиционирование по `ticker` при > 1M записей.

**Инструмент миграции:** Alembic (уже в стеке) с отдельным `env.py` для PostgreSQL.
**Скрипт:** `python -m app.cli migrate-to-postgres --source sqlite:///data/terminal.db --target postgresql://...`

---

## 9. СТРАТЕГИЯ ТЕСТИРОВАНИЯ

**Ответственный: QA (координация, E2E, ручное тестирование), все специалисты (unit-тесты своих модулей)**

### 9.1 Unit-тесты (pytest)

**Coverage target: >= 80%**

| Модуль | Ключевые тест-кейсы |
|---|---|
| **auth** | Хеширование/верификация пароля; JWT генерация/валидация/отзыв; блокировка после 5 неудачных попыток; разблокировка через 15 мин |
| **strategy/code_generator** | Генерация кода для каждого типа блока; edge-case: пустая стратегия; невалидные параметры |
| **strategy/block_parser** | Парсинг валидного шаблона; отсутствующие секции; некорректный формат индикаторов |
| **backtest/engine** | Расчёт P&L (long); учёт комиссии и проскальзывания; расчёт метрик (Sharpe, drawdown, profit factor); корректность equity curve; учёт лотности; учёт НКД для облигаций |
| **trading/order_manager** | Создание market/limit/stop ордеров; валидация шага цены; округление до лотности |
| **trading/position_tracker** | Открытие/закрытие позиции; расчёт unrealized P&L; частичное исполнение; расчёт slippage |
| **circuit_breaker** | Каждый вид лимита: daily loss, max drawdown, position size, trade count; cooldown; блокировка short; блокировка дубликатов |
| **market_data/validator** | High < Low detection; gap detection с учётом календаря; аномальные значения; дубликаты |
| **sandbox/ast_analyzer** | Все запрещённые конструкции; валидный код проходит; edge-case escape-техники |
| **common/crypto** | Encrypt/decrypt round-trip; различные IV; невалидный ключ |

### 9.2 Интеграционные тесты

| Тест | Описание |
|---|---|
| **Broker adapter (mock)** | Mock gRPC-сервер, эмулирующий T-Invest API: place order, get positions, candle stream. Проверка маппинга, rate limiting, reconnect |
| **Database operations** | Полный CRUD для каждой таблицы; каскадное удаление; unique constraints; audit_log append-only |
| **AI service (mock)** | Mock LLM-провайдер: проверка prompt construction, context compression, budget tracking |
| **Sandbox execution** | Запуск безопасного кода → success; запуск вредоносного кода → block; CPU timeout; memory limit |
| **Template parser → code generator** | End-to-end: шаблон текст → блоки → код → валидация кода (компилируется без ошибок) |
| **WebSocket** | Подписка/отписка; получение обновлений; heartbeat; авторизация |

### 9.3 E2E-тесты (Playwright)

| Сценарий | Шаги |
|---|---|
| **Полный цикл бэктеста** | Login → Создать стратегию (блоки) → Сгенерировать код → Запустить бэктест → Дождаться результатов → Проверить метрики и график |
| **Paper trading** | Login → Выбрать стратегию → Запустить Paper → Проверить появление карточки → Подождать сигнала (mock market data) → Проверить сделку в таблице |
| **Circuit breaker** | Login → Запустить стратегию → Имитировать серию убыточных сделок → Проверить срабатывание CB → Проверить уведомление → Стратегия на паузе |
| **Восстановление после перезапуска** | Запустить стратегию → Имитировать остановку backend → Перезапустить → Проверить: сессия восстановлена, уведомление пришло |
| **First run wizard** | Открыть пустое приложение → Пройти мастер настройки → Проверить: пользователь создан, можно логиниться |

### 9.4 Инструменты

- **Backend:** pytest + pytest-asyncio + pytest-cov + httpx (TestClient)
- **Frontend:** Vitest + React Testing Library + MSW (Mock Service Worker)
- **E2E:** Playwright
- **CI:** GitHub Actions → lint (ruff + eslint) → type check (mypy + tsc) → unit tests → integration tests → E2E (при наличии)

### 9.5 Роль QA-инженера в процессе тестирования

QA-инженер встроен в процесс разработки с первого спринта, а не только в финальную фазу:

| Спринт | Задачи QA |
|---|---|
| S1 | Подготовка тест-кейсов по wireframes. Ручное тестирование авторизации |
| S2 | Тест-кейсы для графиков и брокерского подключения. Ручная проверка |
| S3 | Первые E2E-тесты (Playwright): создание стратегии, Blockly, mode B |
| S4 | E2E: полный цикл бэктеста, AI chat (mock). Верификация метрик |
| S5 | E2E: Paper Trading, Circuit Breaker. **Верификация финансовых расчётов** (P&L, лотность, НКД) |
| S6 | E2E: уведомления, восстановление. **Security-тестирование** (совм. с SEC): CSRF, sandbox, brute-force |
| S7 | E2E: Should-фичи (версионирование, экспорт, алерты) |
| S8 | Регрессионный прогон всех E2E. Дополнение пропущенных сценариев. Performance-тестирование (совм.) |

**Принцип:** каждый спринт завершается QA-приёмкой. Баги фиксируются в текущем спринте, а не копятся до S8.

---

## 10. ФАЗЫ РАЗРАБОТКИ

> **Примечание:** Детальное распределение задач по исполнителям, ревьюерам, зависимостям и параллельности — см. **План работ команды (development_plan.md v2.0)**. Ниже приведено краткое описание спринтов, их целей и результатов.

### Состав команды (9 человек)

| # | Роль | Сокращение |
|---|---|---|
| 1 | Технический архитектор | ARCH |
| 2 | Backend-разработчик #1 (senior) | BACK1 |
| 3 | Backend-разработчик #2 | BACK2 (объединяет бывш. DB + AI) |
| 4 | Frontend-разработчик #1 (senior) | FRONT1 (Blockly, Charts, Trading) |
| 5 | Frontend-разработчик #2 | FRONT2 (формы, настройки, дашборд) |
| 6 | UX/UI-дизайнер | UX |
| 7 | QA-инженер | QA |
| 8 | DevOps-специалист | OPS |
| 9 | Специалист по безопасности | SEC |

### Спринт 1 (2 недели): Фундамент

**Все специалисты параллельно. UX начинает wireframes с первого дня.**

| Задача | Ответственный |
|---|---|
| Wireframes ключевых экранов + UI-kit Mantine (dark theme) | UX |
| Инициализация проекта: backend (FastAPI + SQLAlchemy), frontend (React + Vite + Mantine) | OPS + BACK1 + FRONT1 |
| Скрипты установки/запуска (install.sh, start.sh, .env) | OPS |
| БД: все модели SQLAlchemy, Alembic init + первая миграция | BACK2 |
| Auth module: регистрация, логин, JWT, refresh, brute-force protection | SEC |
| Frontend shell: layout, sidebar, header, routing, dark theme (по wireframes UX) | FRONT1 + FRONT2 |
| Health endpoint | BACK1 |
| CI/CD pipeline (GitHub Actions) | OPS |
| Тест-кейсы авторизации + ручное тестирование | QA |

**Результат:** Можно залогиниться, увидеть дашборд по wireframes, health endpoint работает. Wireframes утверждены. QA подтвердил auth.

### Спринт 2 (2 недели): Данные и графики

| Задача | Ответственный |
|---|---|
| UX: дизайн экранов графиков и настроек брокера | UX |
| Broker Adapter: T-Invest — подключение, get_accounts, get_balance, get_historical_candles | BACK1 |
| MOEX ISS клиент (fallback) + MOEX Calendar Service | BACK2 |
| Market Data Service: кеш OHLCV, загрузка, валидация | BACK1 + BACK2 |
| Crypto Service (AES-256-GCM) для API-ключей | SEC |
| Frontend: Графики (TradingView LW Charts), таймфрейм, volume (по дизайну UX) | FRONT1 |
| Frontend: Настройки брокера, добавление API-ключа | FRONT2 |
| Тест-кейсы + ручное тестирование: графики, брокер, шифрование | QA |

**Результат:** Подключён брокер, можно просматривать графики. API-ключи зашифрованы. QA подтвердил.

### Спринт 3 (2 недели): Стратегии + Блочный редактор + Защита API

| Задача | Ответственный |
|---|---|
| UX: дизайн Strategy Editor (Blockly workspace, AI chat sidebar) | UX |
| Strategy CRUD API + модели | BACK1 |
| Code Generator: блоки → Python/Backtrader | BACK2 |
| Template Parser (режим B) | BACK2 |
| Code Sandbox: AST-анализ + RestrictedPython | SEC |
| **CSRF protection (middleware, токены)** | SEC |
| **Rate limiting внутреннего API** | SEC |
| Blockly: кастомные блоки (индикаторы, условия, сигналы) | FRONT1 |
| Frontend: Strategy Editor page (по дизайну UX) | FRONT1 |
| Frontend: режим B — модальное окно | FRONT2 |
| E2E-тесты: создание стратегии, Blockly, mode B | QA |

**Результат:** Стратегия создаётся в блочном редакторе или через шаблон. Sandbox блокирует вредоносный код. **API защищён CSRF и rate limiting.** QA E2E пройден.

### Спринт 4 (2 недели): AI-интеграция + бэктестинг

| Задача | Ответственный |
|---|---|
| UX: дизайн экранов бэктеста + AI sidebar chat | UX |
| AI Service: pluggable providers, хранение ключей в БД | BACK2 |
| AI chat API + SSE streaming | BACK2 + BACK1 |
| Backtest Engine: Backtrader wrapper, метрики, equity curve, benchmark | BACK1 |
| Backtest API + прогресс через WebSocket | BACK1 |
| Frontend: AI sidebar chat | FRONT2 |
| Frontend: Backtest Results (3 вкладки, по дизайну UX) | FRONT1 |
| Frontend: форма запуска бэктеста + Настройки AI-провайдеров | FRONT2 |
| E2E-тесты: полный цикл бэктеста, AI chat (mock) | QA |

**Результат:** Полный цикл: стратегия → бэктест → результаты. AI-ключи через UI. QA E2E пройден.

### Спринт 5 (2 недели): Торговля + Bond/Corporate Actions

| Задача | Ответственный |
|---|---|
| UX: дизайн Trading Panel (Paper vs Real визуализация) | UX |
| Trading Engine: session manager, signal processor, order manager, position tracker | BACK1 |
| Paper Trading Engine (виртуальный портфель, T+1) | BACK1 |
| Broker Adapter: place_order, cancel_order, subscribe_candles (streaming) | BACK1 |
| Rate limiter для брокерского API | BACK1 |
| Circuit Breaker (все виды лимитов) | SEC |
| **Bond Service (расчёт НКД) + Corporate Action Handler** | BACK2 |
| **Налоговый экспорт (Tax Report Generator, FIFO, 3-НДФЛ)** | BACK2 |
| Frontend: Trading Panel (по дизайну UX) | FRONT1 |
| Frontend: Real-time графики через WS + индикаторы | FRONT1 |
| Frontend: экран «Счёт» (баланс, позиции, налоговый отчёт) | FRONT2 |
| E2E-тесты: Paper Trading, Circuit Breaker, Bond P&L | QA |

**Результат:** Paper Trading + Circuit Breaker + НКД + корп. действия. QA E2E пройден.

### Спринт 6 (2 недели): Уведомления + восстановление

| Задача | Ответственный |
|---|---|
| UX: дизайн Notification Center + Telegram-сообщений | UX |
| Telegram-бот: привязка, уведомления, команды | BACK2 |
| Email-уведомления (SMTP) | BACK2 |
| In-app уведомления (WebSocket) + Event Bus + pending_events | BACK1 |
| Восстановление после перезапуска | BACK1 |
| Graceful Shutdown | OPS + BACK1 |
| Frontend: Notification Center (по дизайну UX) | FRONT2 |
| Frontend: доработки Trading Panel по результатам QA | FRONT1 |
| E2E-тесты: уведомления, восстановление + Security-тестирование (CSRF, sandbox, auth) | QA + SEC |

**Результат:** Полная система уведомлений. Восстановление после рестарта. Security-тесты пройдены.

### Спринт 7 (2 недели): Полировка + Should-фичи

> **Примечание:** Must-задачи (Bond, Corporate Actions, налоговый экспорт) перенесены в S5. Здесь — только Should-фичи, приоритизированные по ценности.

| Задача | Ответственный |
|---|---|
| UX: финальная полировка UI, консистентность, юзабилити-тест | UX |
| Версионирование стратегий (Should) | BACK1 + FRONT2 |
| Grid Search оптимизация (Should) | BACK1 + FRONT2 |
| Экспорт CSV/PDF (Should) | BACK2 |
| Telegram-команды /close, /closeall, /balance (Should) | BACK2 |
| Ценовые алерты (Should) | BACK1 + FRONT2 |
| Инструменты рисования на графике (Should) | FRONT1 |
| Дашборд: виджет баланса, health indicator, sparklines | FRONT1 + FRONT2 |
| Дисклеймер (first-run wizard) | FRONT2 + BACK2 |
| Backup/restore | OPS + BACK1 |
| E2E-тесты S7 | QA |

**Результат:** Phase 1 feature-complete. UX утвердил финальный вид интерфейса.

### Спринт 8 (2 недели): Регрессия + стабилизация

> **Примечание:** Основной объём тестов написан в S2–S7 (QA встроен в каждый спринт). S8 — регрессия, performance, security audit, юзабилити-тест.

| Задача | Ответственный |
|---|---|
| Регрессионный прогон всех E2E-тестов | QA |
| Дополнение unit-тестов: coverage ≥ 80% | BACK1 + BACK2 + SEC |
| Frontend unit-тесты (ru-RU, Blockly, WS reconnect) | FRONT1 + FRONT2 |
| Performance testing: целевые метрики | BACK1 |
| Security audit: crypto, sandbox, CSRF, headers | SEC + QA |
| UX: финальный юзабилити-тест с пользователем | UX |
| Bug fixing по результатам тестов | Все |
| Исправление UX-багов по юзабилити-тесту | FRONT1 + FRONT2 |
| Документация: README, deployment guide | OPS |

**Результат:** Production-ready Phase 1. Sign-off: ARCH + QA + UX.

### Зависимости между спринтами

```
Спринт 1 (фундамент + wireframes)
    ↓
Спринт 2 (данные + графики)     ← зависит от auth и DB
    ↓
Спринт 3 (стратегии + CSRF)     ← зависит от market data
    ↓
Спринт 4 (AI + бэктест)         ← зависит от стратегий и sandbox
    ↓
Спринт 5 (торговля + Bond)      ← зависит от бэктест engine и broker
    │
    ├──────────────────┐
    ▼                  ▼
Спринт 6 (уведомления)   Спринт 7 (Should — параллельно)
    │                  │
    ├──────────────────┘
    ▼
Спринт 8 (регрессия)            ← после feature freeze
```

---

## СВОДНАЯ МАТРИЦА ОТВЕТСТВЕННОСТИ

> **Примечание v2:** Матрица обновлена под 9 ролей. Полная RACI-матрица — см. development_plan.md v2.0.

| Модуль / Задача | ARCH | BACK1 | BACK2 | FRONT1 | FRONT2 | UX | QA | OPS | SEC |
|---|---|---|---|---|---|---|---|---|---|
| Архитектурные решения | **P** | R | R | R | | R | | R | R |
| Code review (межмодульные) | **P** | | | | | | | | |
| Code review (backend) | | **P** | | | | | | | |
| Code review (frontend) | | | | **P** | | R | | | |
| Схема БД, миграции | | R | **P** | | | | | | R |
| FastAPI app, middleware | | **P** | R | | | | | | R |
| Auth module (JWT, Argon2) | | R | | | | | | | **P** |
| Strategy Engine (parser, codegen) | | R | **P** | | | | | | |
| Blockly editor | | | | **P** | | R | | | |
| AI Service (providers, prompts) | | R | **P** | | | | | | R |
| AI chat frontend | | | | | **P** | R | | | |
| Backtest Engine | | **P** | | | | | | | |
| Trading Engine | | **P** | | | | | | | R |
| Broker Adapter (T-Invest) | | **P** | | | | | | | |
| Market Data Service | | **P** | R | | | | | | |
| Charts (TradingView) | | | | **P** | | R | | | |
| Notification Service | | | **P** | | R | | | | |
| Telegram Bot | | | **P** | | | | | R | R |
| Circuit Breaker | | R | | | | | | | **P** |
| Code Sandbox | | R | | | | | | | **P** |
| Crypto, CSRF, Rate Limiting | | | | | | | | | **P** |
| Bond Service, Corp. Actions | | | **P** | | | | | | |
| Tax Report Generator | | | **P** | | R | | | | |
| Wireframes, UI-kit | | | | R | R | **P** | | | |
| Юзабилити-тестирование | | | | | | **P** | R | | |
| Dashboard, Settings UI | | | | | **P** | R | | | |
| Trading Panel | | | | **P** | | R | | | |
| Deploy scripts, CI/CD | | | | | | | | **P** | |
| Backup, Logs, Health | | R | | | | | | **P** | |
| E2E-тесты (Playwright) | | | | R | R | | **P** | | |
| Ручное тестирование | | | | | | | **P** | | |
| Unit/Integration-тесты | | **P** | **P** | R | R | | R | | **P** |
| Security audit | | | | | | | R | | **P** |
| Performance testing | | **P** | | R | | | R | | |
| Документация | | R | R | | | | | **P** | |

**P** = Primary (основной исполнитель), **R** = Reviewer (ревью / консультация)

---

## История изменений

| Версия | Дата | Автор | Описание |
|--------|------|-------|----------|
| 1.0 | 2026-03-23 | ARCH | Первая версия на основе ФТ v2.0 |
| 1.1 | 2026-04-07 | Sprint_4_Review | §5.10: AI providers — добавлены DeepSeek, Gemini, Mistral, Groq, Qwen, OpenRouter. §6.3: Strategy Editor — 2 вкладки, два режима (Blockly + AI), SharedDescriptionPanel, toolbar. §6.5: Backtest Results — 4 вкладки с полным описанием |
| 1.2 | 2026-04-17 | Sprint_6_ARCH | §5.7: NotificationService — полная реализация (service, telegram, email, dispatchers, REST API 8 endpoints, WS bridge). §8.6: Graceful Shutdown — реальная последовательность с pending orders 30s и multi-channel notification + recovery |