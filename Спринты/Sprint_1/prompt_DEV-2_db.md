---
sprint: 1
agent: DEV-2
role: Backend Data (BACK2)
wave: 1
depends_on: []
---

# Роль

Ты — Backend-разработчик #2. Создай все SQLAlchemy-модели и настрой Alembic.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы **обязательно** проверь:

```
1. Python >= 3.11 установлен (python3 --version)
2. pip доступен (python3 -m pip --version)
3. Директория backend/app/ существует
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-2 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст

Схема БД определена в ТЗ (раздел 3). Все 23+ таблиц нужно реализовать как SQLAlchemy ORM-модели. Используй async SQLAlchemy 2.0+ с aiosqlite.

# Задачи

## 1. Модели (разместить в соответствующих модулях)

### app/auth/models.py
- `User` — таблица `users` (id, username, password_hash, email, risk_*, disclaimer_accepted_at, failed_login_count, locked_until, created_at, updated_at, is_active)

### app/strategy/models.py
- `Strategy` — таблица `strategies` (id, user_id FK, name, status, current_version_id FK, created_at, updated_at)
- `StrategyVersion` — таблица `strategy_versions` (id, strategy_id FK, version_number, text_description, blocks_json, generated_code, parameters_json, ai_chat_history, created_at). UNIQUE(strategy_id, version_number)

### app/market_data/models.py
- `Instrument` — таблица `instruments` (id, ticker, figi, isin, name, type, currency, lot_size, min_price_increment, exchange, sector, is_active, updated_at)
- `OHLCVCache` — таблица `ohlcv_cache` (id, ticker, timeframe, timestamp, open, high, low, close, volume, source). UNIQUE(ticker, timeframe, timestamp)

### app/backtest/models.py
- `Backtest` — таблица `backtests` (id, strategy_version_id FK, ticker, timeframe, date_from, date_to, initial_capital, commission_pct, slippage_value, slippage_mode, params_json, status, net_profit, net_profit_pct, total_trades, winning_trades, losing_trades, win_rate, profit_factor, max_drawdown_pct, sharpe_ratio, avg_profit_per_trade, avg_loss_per_trade, avg_trade_duration_bars, avg_trade_duration_seconds, benchmark_buy_hold_pct, benchmark_imoex_pct, equity_curve_json, error_message, started_at, completed_at)
- `BacktestTrade` — таблица `backtest_trades` (id, backtest_id FK CASCADE, direction, entry_date, entry_price, exit_date, exit_price, volume_lots, volume_rub, pnl, pnl_pct, commission, duration_bars, duration_seconds)

### app/trading/models.py
- `TradingSession` — таблица `trading_sessions` (id, strategy_version_id FK, broker_account_id FK, ticker, mode, status, position_sizing_mode, position_sizing_value, max_concurrent_positions, cooldown_seconds, initial_capital, consecutive_fund_skips, started_at, stopped_at, last_signal_at)
- `LiveTrade` — таблица `live_trades` (id, session_id FK, broker_order_id, direction, order_type, status, entry_signal_price, entry_price, exit_signal_price, exit_price, volume_lots, filled_lots, volume_rub, stop_loss, take_profit, pnl, pnl_pct, commission, slippage, nkd_entry, nkd_exit, opened_at, closed_at)
- `PaperPortfolio` — таблица `paper_portfolios` (id, session_id FK UNIQUE, balance, blocked_amount, peak_equity, updated_at)

### app/broker/models.py (новый файл)
- `BrokerAccount` — таблица `broker_accounts` (id, user_id FK, broker_type, name, encrypted_api_key, encrypted_api_secret, encryption_iv, account_id, account_type, is_active, has_withdrawal_rights, created_at, updated_at)

### app/notification/models.py
- `Notification` — таблица `notifications` (id, user_id FK, event_type, title, body, severity, is_read, channels_sent, related_entity_type, related_entity_id, created_at)
- `TelegramLink` — таблица `telegram_links` (id, user_id FK UNIQUE, chat_id, linked_at, is_active)
- `UserNotificationSetting` — таблица `user_notification_settings` (id, user_id FK, event_type, telegram_enabled, email_enabled, in_app_enabled)

### app/circuit_breaker/models.py (новый файл)
- `CircuitBreakerEvent` — таблица `circuit_breaker_events` (id, user_id FK, event_type, trigger_value, limit_value, action_taken, session_id FK nullable, details, created_at)

### app/corporate_actions/models.py (новый файл)
- `CorporateAction` — таблица `corporate_actions` (id, ticker, action_type, ex_date, record_date, amount, currency, description, created_at)

### app/auth/models.py (дополнение)
- `RevokedToken` — таблица `revoked_tokens` (id, jti String(64) UNIQUE NOT NULL, user_id FK, revoked_at DateTime NOT NULL, expires_at DateTime NOT NULL). INDEX: idx_revoked_jti (jti). Используется для JWT revocation при logout/смене пароля. Ежедневная очистка записей с expires_at < utcnow.

### app/trading/models.py (дополнение)
- `DailyStat` — таблица `daily_stats` (id, session_id FK NOT NULL, date Date NOT NULL, trades_opened Integer DEFAULT 0, trades_closed Integer DEFAULT 0, pnl Numeric(18,2) DEFAULT 0, realized_pnl Numeric(18,2) DEFAULT 0, unrealized_pnl Numeric(18,2) DEFAULT 0, peak_equity Numeric(18,2) NULLABLE). UNIQUE(session_id, date). INDEX: idx_ds_session_date (session_id, date).

### app/common/models.py (новый файл)
- `AuditLog` — таблица `audit_log` (id, user_id FK nullable, action, entity_type, entity_id, details, source, ip_address, created_at). Append-only.
- `PendingEvent` — таблица `pending_events` (id, event_type, payload, created_at, processed_at)
- `ChartDrawing` — таблица `chart_drawings` (id, user_id FK, ticker, timeframe, type, data_json, style_json, created_at, updated_at)
- `PriceAlert` — таблица `price_alerts` (id, user_id FK, ticker, price_level, direction, is_active, triggered_at, created_at)
- `AIProviderConfig` — таблица `ai_provider_configs` (id, user_id FK, provider, encrypted_api_key, encryption_iv, model_name, is_default, created_at)

## 2. Типы данных

**ОБЯЗАТЕЛЬНО:**
- Цены: `Numeric(18, 8)`
- Денежные суммы: `Numeric(18, 2)`
- Проценты: `Numeric(10, 4)`
- НЕ использовать Float для финансовых данных!
- Все DateTime в UTC с `server_default=func.now()`
- Шифрованные поля: `LargeBinary`

## 3. Индексы

Создай все индексы из ТЗ:
- `idx_broker_user`, `idx_strategy_user`, `idx_ohlcv_lookup`, `idx_bt_sv`, `idx_bt_ticker`
- `idx_ts_active`, `idx_lt_session`, `idx_lt_status`, `idx_lt_opened`
- `idx_audit_created`, `idx_audit_user`, `idx_notif_user_unread`
- `idx_alert_active`, `idx_drawing_lookup`
- `idx_revoked_jti`, `idx_ds_session_date`

## 4. Alembic

- Инициализация: `alembic init alembic`
- Настройка `alembic.ini` и `env.py` для async SQLAlchemy
- Первая миграция: `alembic revision --autogenerate -m "initial_schema"`
- SQLite triggers для audit_log (prevent DELETE/UPDATE)

## 5. common/database.py

Если файл уже создан DEV-1, дополни его. Если нет — создай:
- `Base = declarative_base()` с общими миксинами (TimestampMixin: created_at, updated_at)
- Async engine для aiosqlite
- WAL-режим

# Конвенции

- Все модели наследуют `Base`
- Именование таблиц: snake_case, множественное число (users, strategies, etc.)
- Foreign keys: `ondelete="CASCADE"` только для backtest_trades. Остальные — `"SET NULL"` или default
- Relationships: lazy="selectin" для async

## 6. Тесты

Ты отвечаешь за тестирование своего кода. Создай тесты в `tests/unit/test_models.py`.

### tests/unit/test_models.py

```python
# Тесты:
# - test_user_model_creation — создать User, проверить все поля
# - test_user_default_values — risk_daily_loss_pct=5.0, is_active=True и т.д.
# - test_strategy_model_creation — создать Strategy с FK на User
# - test_strategy_version_unique_constraint — проверить UNIQUE(strategy_id, version_number)
# - test_ohlcv_unique_constraint — проверить UNIQUE(ticker, timeframe, timestamp)
# - test_broker_account_encrypted_fields — проверить что encrypted_api_key = LargeBinary
# - test_financial_fields_are_numeric — проверить что цены/суммы НЕ Float
#   (introspect column type, assert isinstance Numeric)
# - test_audit_log_is_append_only — попытка delete/update должна вызвать ошибку (SQLite trigger)
# - test_all_models_have_correct_table_names — проверить __tablename__ для каждой модели
# - test_foreign_key_relationships — проверить что FK связи корректны
```

### tests/unit/test_migration.py

```python
# Тесты:
# - test_alembic_upgrade_head — применить миграцию к пустой БД, проверить что все таблицы созданы
# - test_all_tables_exist — после миграции проверить список таблиц через inspect
# - test_indexes_exist — проверить наличие ключевых индексов
```

**Запусти тесты и убедись, что все проходят:**
```bash
cd backend && pytest tests/unit/test_models.py tests/unit/test_migration.py -v
```

# Критерий завершения

- Все 23+ моделей созданы в соответствующих модулях
- `alembic upgrade head` создаёт все таблицы без ошибок
- Индексы и UNIQUE-ограничения на месте
- Триггеры audit_log работают
- **Все тесты проходят: `pytest tests/unit/test_models.py tests/unit/test_migration.py -v` — 0 failures**
- **Тесты покрывают: создание моделей, типы данных (Numeric, не Float), уникальные ограничения, FK, триггеры audit_log**
