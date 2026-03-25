# Спринт 2: Данные и графики (недели 3-4)

## Цель

Подключить брокера (T-Invest), загрузить рыночные данные, отобразить графики, зашифровать API-ключи.

## Критерии завершения

- [ ] T-Invest Broker Adapter работает: подключение, get_accounts, get_balance, get_historical_candles
- [ ] MOEX ISS клиент работает как fallback-источник данных
- [ ] Market Data Service: загрузка, кеширование, валидация OHLCV
- [ ] API-ключи брокера зашифрованы AES-256-GCM
- [ ] Графики (TradingView LW Charts) отображают исторические свечи
- [ ] Экран настроек брокера: добавление/удаление/просмотр аккаунтов
- [ ] Динамический footer: статус MOEX, режим торговли, время до закрытия
- [ ] **Все backend-тесты проходят (`pytest tests/ -v` — 0 failures)**
- [ ] **Все frontend-тесты проходят (`pnpm test` — 0 failures)**

## Подход к тестированию (S1-S2)

На спринтах 1 и 2 **тестирование — ответственность разработчиков**:
- Каждый DEV-агент пишет unit-тесты для своего кода
- ARCH при ревью **запускает все тесты** и проверяет их качество
- Отдельный QA-агент готовит тест-кейсы, но E2E появляется с S3

| Агент | Что тестирует |
|-------|--------------|
| DEV-1 | BrokerAdapter, TInvestAdapter (mock gRPC), rate limiter, broker router |
| DEV-2 | MOEX ISS client (mock httpx), Calendar Service, fallback schedule |
| DEV-3 | CryptoService: encrypt/decrypt roundtrip, IV uniqueness, key derivation |
| DEV-4 | MarketDataService: кеш, fallback, валидация OHLCV, endpoints |
| DEV-5 | Charts компоненты, TimeframeSelector, marketDataStore |
| DEV-6 | AddBrokerForm, BrokerAccountList, settingsStore |
| **QA** | **Тест-кейсы для ручного тестирования** |
| **ARCH** | **Запуск ВСЕХ тестов, проверка coverage, интеграционная проверка** |

## Порядок выполнения

**[execution_order.md](execution_order.md)** — полная схема: кто, когда, от чего зависит, какой промпт, какие артефакты. Начните с этого файла.

## Предполётная проверка

**Перед стартом выполняется [preflight_checklist.md](preflight_checklist.md)** — автоматическая проверка:
- Sprint 1 смержен в develop, 68 тестов проходят
- grpcio и tinkoff-investments устанавливаются
- Все промпты на месте (11 файлов)
- Зависимости между волнами

Спринт **НЕ НАЧИНАЕТСЯ**, пока preflight не пройден.

## Волны

### Фаза UX (foreground, диалог с заказчиком)
- Экран графика: TradingView chart, таймфреймы, volume
- Экран настроек брокера: добавление, список, маскировка ключей
- Динамический footer

### Волна 1 (параллельно с UX)
| Агент | Файл промпта | Задачи |
|-------|-------------|--------|
| DEV-1 | prompt_DEV-1_broker.md | T-Invest adapter + broker router + **тесты** |
| DEV-2 | prompt_DEV-2_moex_iss.md | MOEX ISS client + Calendar Service + **тесты** |
| DEV-3 | prompt_DEV-3_crypto.md | CryptoService AES-256-GCM + **тесты** |

### Волна 2 (после мержа волны 1)
| Агент | Файл промпта | Задачи |
|-------|-------------|--------|
| DEV-4 | prompt_DEV-4_market_data.md | Market Data Service + кеш + **тесты** |

### Волна 3 (после мержа волны 2 + утверждения UX)
| Агент | Файл промпта | Задачи |
|-------|-------------|--------|
| DEV-5 | prompt_DEV-5_charts.md | TradingView charts + footer + **тесты** |
| DEV-6 | prompt_DEV-6_broker_settings.md | Broker settings UI + **тесты** |

### Ревью (финальная проверка)
| Агент | Файл промпта |
|-------|-------------|
| QA | prompt_QA.md — тест-кейсы + ручное тестирование |
| ARCH | prompt_ARCH_review.md — **включает запуск тестов и отчёт** |

## Зависимости от предыдущих спринтов

- Sprint 1 полностью завершён и смержен в develop (68 тестов)
- Auth, DB-модели, layout, CI/CD — всё на месте

## Состояние спринта (при прерывании)

**[sprint_state.md](sprint_state.md)** — живой файл, обновляется после каждого шага. Если сессия прервалась — новая сессия читает только его, чтобы продолжить работу.

## Результаты (артефакты спринта)

- `ui_spec_s2.md` — утверждённая UI-спецификация S2 (создаётся после UX-фазы)
- `sprint_report.md` — итоговый отчёт (шаблон: `sprint_report_template.md`)
- `sprint_state.md` — финальное состояние (все шаги ✅)
