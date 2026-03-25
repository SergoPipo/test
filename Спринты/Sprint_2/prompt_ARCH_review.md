---
sprint: 2
agent: ARCH
role: Технический архитектор
wave: review (после всех DEV + QA)
depends_on: [DEV-1, DEV-2, DEV-3, DEV-4, DEV-5, DEV-6, QA]
---

# Роль

Ты — технический архитектор проекта «Торговый терминал для MOEX». Проведи code review результатов Спринта 2.

# Контекст

Документация проекта:
- ТЗ: `Test/Документация по проекту/technical_specification.md`
- ФТ: `Test/Документация по проекту/functional_requirements.md`
- UI-спецификация S2: `Test/Спринты/Sprint_2/ui_spec_s2.md`
- QA-отчёт: `Test/Спринты/Sprint_2/qa_report_s2.md`

Код находится в `Test/Develop/` (backend/ и frontend/).

# Что проверить

## 1. BrokerAdapter Interface (DEV-1)

- [ ] `BaseBrokerAdapter` — абстрактный класс с полным интерфейсом
- [ ] Dataclass-ы: `BrokerAccountInfo`, `AccountBalance`, `CandleData` — корректные типы
- [ ] Все финансовые поля: `Decimal`, не `float`
- [ ] Методы S2 реализованы: `connect`, `get_accounts`, `get_balance`, `get_historical_candles`
- [ ] Методы будущих спринтов: `raise NotImplementedError`

## 2. T-Invest Adapter (DEV-1)

- [ ] Использует `tinkoff.invest.AsyncClient`
- [ ] Sandbox-режим через `config.TINVEST_SANDBOX`
- [ ] Rate limiter: 300 req/min, token bucket
- [ ] Historical candles: чанки по 1 году (daily) / 1 дню (minute)
- [ ] `TInvestMapper`: Protobuf → domain models (MoneyValue → Decimal корректно)
- [ ] Ошибки SDK → `BrokerError`
- [ ] API-ключи **не логируются**

## 3. MOEX ISS Client (DEV-2)

- [ ] `httpx.AsyncClient` с правильными таймаутами
- [ ] Парсинг ISS JSON: columns + data → dict
- [ ] Пагинация: загрузка >500 свечей
- [ ] Retry на 5xx с backoff
- [ ] Raise на 4xx
- [ ] Пустой ответ → пустой список (не ошибка)

## 4. MOEX Calendar Service (DEV-2)

- [ ] `is_trading_day()`, `time_until_close()`, `get_market_status()`
- [ ] Fallback-расписание (пн-пт, праздники РФ)
- [ ] Timezone: Europe/Moscow (zoneinfo)
- [ ] Основная сессия: 10:00–18:50, вечерняя: 19:05–23:50

## 5. CryptoService (DEV-3)

- [ ] AES-256-GCM (библиотека `cryptography`)
- [ ] HKDF(SHA256) деривация ключа
- [ ] IV: 12 байт, `os.urandom()`
- [ ] GCM-тег включён в ciphertext
- [ ] **Encrypt/decrypt roundtrip работает**
- [ ] Разные plaintext → разные ciphertext
- [ ] Одинаковый plaintext → разные ciphertext (разный IV)
- [ ] Неверный ключ → `InvalidTag` (не silent fail)
- [ ] Sub-IV подход для пары key/secret (если один IV в модели) — безопасность оценить
- [ ] Мастер-ключ **НЕ** хардкодится (берётся из config)
- [ ] Plaintext **НЕ** логируется

## 6. Market Data Service (DEV-4)

- [ ] Кеш: проверка → определение пропусков → загрузка → сохранение
- [ ] Fallback: T-Invest → MOEX ISS
- [ ] INSERT OR IGNORE для дубликатов в кеше
- [ ] Валидация OHLCV: high >= max(O,C), low <= min(O,C), volume >= 0
- [ ] Timeframe enum: 1m, 5m, 15m, 1h, 4h, D, W, M
- [ ] Endpoint `/market-data/candles` требует auth
- [ ] Endpoint `/market-data/market-status` **публичный** (для footer)

## 7. Frontend — Charts (DEV-5)

- [ ] TradingView Lightweight Charts интегрирован
- [ ] Dark theme: фон `#1A1B1E`, свечи зелёные/красные
- [ ] Volume histogram (toggle on/off)
- [ ] Crosshair с tooltip
- [ ] **chart.remove() на unmount** (утечки памяти!)
- [ ] **ResizeObserver** для автоматического resize
- [ ] TimeframeSelector с русскими подписями
- [ ] ChartPage: `/chart/:ticker`, empty state без тикера
- [ ] Поиск в Header: Autocomplete, debounce, navigate to chart

## 8. Frontend — Broker Settings (DEV-6)

- [ ] Соответствие ui_spec_s2.md
- [ ] AddBrokerForm: все поля, валидация, discover
- [ ] PasswordInput для API-ключа (маскировка по умолчанию)
- [ ] BrokerAccountList: таблица/карточки, баланс в ru-RU формате
- [ ] Удаление: модальное окно подтверждения
- [ ] Empty state: "Нет подключённых брокеров"
- [ ] Mantine Notifications для success/error

## 9. Footer (DEV-5)

- [ ] Динамические данные из `/market-data/market-status`
- [ ] Автообновление каждые 60 секунд
- [ ] Цвета: green=online, yellow=evening, orange=auction, red=offline, gray=weekend
- [ ] Режим торговли (Paper/Real/нет)
- [ ] Время до закрытия

## 10. Тестирование (ФИНАЛЬНАЯ ПРОВЕРКА)

### 10.1 Запуск всех тестов

```bash
# Backend
cd backend && pip install -e .[dev] && pytest tests/ -v --tb=short

# Frontend
cd frontend && pnpm test
```

- [ ] **Backend: все тесты проходят (0 failures)**
- [ ] **Frontend: все тесты проходят (0 failures)**

### 10.2 Качество тестов (DEV-1: Broker Adapter)
- [ ] Mock gRPC — не реальные подключения
- [ ] Rate limiter тестирован
- [ ] Mapper тестирован (MoneyValue → Decimal)
- [ ] Router тестирован (mock service)

### 10.3 Качество тестов (DEV-2: MOEX ISS)
- [ ] Mock httpx — не реальные запросы к MOEX
- [ ] ISS парсер тестирован с фикстурами JSON
- [ ] Calendar: торговые/нерабочие дни, праздники

### 10.4 Качество тестов (DEV-3: Crypto)
- [ ] Roundtrip encrypt/decrypt
- [ ] Разные IV для одного plaintext
- [ ] Неверный ключ → ошибка
- [ ] Спецсимволы в API-ключе

### 10.5 Качество тестов (DEV-4: Market Data)
- [ ] Cache hit vs miss
- [ ] Fallback T-Invest → ISS
- [ ] OHLCV валидация
- [ ] Endpoints с mock service

### 10.6 Качество тестов (DEV-5: Charts)
- [ ] TimeframeSelector рендерится
- [ ] MarketDataStore управление состоянием
- [ ] StatusFooter рендерится

### 10.7 Качество тестов (DEV-6: Broker Settings)
- [ ] AddBrokerForm рендерится
- [ ] BrokerAccountList empty state
- [ ] SettingsStore управление состоянием

## 11. Межмодульная интеграция

- [ ] Broker router подключён в main.py
- [ ] Market data router подключён в main.py
- [ ] Frontend API client baseURL совпадает с backend (localhost:8000)
- [ ] Sidebar содержит "Графики" и "Настройки" с корректными путями
- [ ] Роуты `/chart/:ticker` и `/settings` зарегистрированы в App.tsx
- [ ] CryptoService используется в BrokerService для шифрования ключей
- [ ] MarketDataService использует BrokerAdapter и MOEXISSClient

## 12. Безопасность

- [ ] API-ключи **не логируются** (structlog)
- [ ] API-ключи **не возвращаются** в API-ответах (BrokerAccountResponse не содержит api_key)
- [ ] API-ключи **зашифрованы** в БД (не plaintext)
- [ ] ENCRYPTION_KEY не хардкодится (config → .env)
- [ ] PasswordInput в frontend (маскировка)
- [ ] Auth middleware на всех endpoints кроме market-status

# Формат ответа

Для каждого замечания укажи:

```
### [Критичность: CRITICAL / MAJOR / MINOR]

**Агент:** DEV-N
**Файл:** path/to/file.py:line
**Проблема:** [описание]
**Решение:** [что нужно исправить]
```

В конце — общий вердикт:
- `APPROVED` — замечаний нет
- `APPROVED WITH MINOR` — мелкие замечания, можно мержить с фиксами
- `CHANGES REQUESTED` — есть CRITICAL/MAJOR, нужны исправления

**Отчёт по тестам:**
```
### Отчёт по тестированию

**Backend:** X тестов, Y passed, Z failed (из них S1: 55, S2: новые)
**Frontend:** X тестов, Y passed, Z failed (из них S1: 13, S2: новые)

**Непокрытые области:** [если есть]
```

# Важно

- Будь строг к **финансовым типам** — Float для денег = CRITICAL
- Будь строг к **безопасности** — plaintext ключи, логирование секретов = CRITICAL
- Будь строг к **утечкам памяти** — chart.remove() на unmount = MAJOR если отсутствует
- Будь строг к **шифрованию** — неправильный IV, отсутствие GCM-тега = CRITICAL
- Проверяй соответствие ТЗ и ui_spec_s2.md
- **ARCH запускает тесты сам — не верь на слово разработчикам**
