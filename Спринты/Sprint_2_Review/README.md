# Промежуточное ревью после Sprint 2

> **Milestone M1: Каркас**
> Охватывает: Sprint 1 (Фундамент) + Sprint 2 (Данные и графики)

## Цель

Провести ревью реализованного кода, собрать бэклог улучшений и доработок, выявленных заказчиком при проверке готового результата.

## Что реализовано к этому моменту

- Auth (регистрация, JWT, брутфорс-защита)
- DB (23+ моделей, Alembic миграции)
- Layout (header, sidebar, footer, dark theme)
- T-Invest Broker Adapter (gRPC, rate limiter)
- MOEX ISS Client (REST, calendar, fallback)
- CryptoService (AES-256-GCM для API-ключей)
- Market Data Service (кеш, fallback, валидация OHLCV)
- Графики (TradingView Lightweight Charts)
- Настройки брокера (формы, список аккаунтов, sandbox)
- Динамический footer (статус MOEX, брокер, время МСК)
- CI/CD pipeline (GitHub Actions)
- 175 тестов (138 backend + 37 frontend), 0 failures

## Порядок работы

1. **Ревью кода** → [code_review.md](code_review.md)
   - Пройти чеклист по 10 разделам
   - Зафиксировать замечания
   - Запустить автоматические проверки

2. **Бэклог доработок** → [backlog.md](backlog.md)
   - Улучшения уже реализованного
   - Модификации по результатам проверки заказчиком
   - Баги

3. **Выполнение** → [execution_log.md](execution_log.md)
   - Последовательно выполнять задачи из бэклога
   - Фиксировать результат каждой задачи

## Следующее ревью

Sprint_4_Review/ — после Sprint 3 (Стратегии) + Sprint 4 (AI + Бэктестинг)
