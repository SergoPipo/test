---
sprint: 1
agent: ARCH
role: Технический архитектор
wave: review (после всех DEV)
depends_on: [DEV-1, DEV-2, DEV-3, DEV-4, DEV-5]
---

# Роль

Ты — технический архитектор проекта «Торговый терминал для MOEX». Проведи code review результатов Спринта 1.

# Контекст

Документация проекта:
- ТЗ: `Test/Документация по проекту/technical_specification.md`
- ФТ: `Test/Документация по проекту/functional_requirements.md`
- UI-спецификация: `Test/Спринты/Sprint_1/ui_spec.md`

Код находится в `Test/Develop/` (backend/ и frontend/).

# Что проверить

## 1. Структура проекта (DEV-1)

- [ ] Структура `backend/app/` соответствует ТЗ раздел 2.1
- [ ] Все модули имеют `__init__.py`, `router.py`, `service.py`, `schemas.py`
- [ ] `main.py` — application factory с подключением всех роутеров
- [ ] `config.py` — все переменные окружения из `.env.example`
- [ ] `common/database.py` — async SQLAlchemy, WAL-режим
- [ ] Health endpoint работает: `GET /api/v1/health → 200`
- [ ] CORS настроен для `http://localhost:5173`

## 2. Модели БД (DEV-2)

- [ ] Все 25+ таблиц из ТЗ раздел 3 реализованы (включая `revoked_tokens` и `daily_stats`)
- [ ] Финансовые данные: `Numeric(18,8)` цены, `Numeric(18,2)` деньги, `Numeric(10,4)` проценты — **НЕ Float!**
- [ ] Все индексы из ТЗ на месте
- [ ] UNIQUE-ограничения: `uq_ohlcv`, `uq_strategy_version`, `uq_active_session`
- [ ] Foreign keys с правильными `ondelete` (CASCADE только для backtest_trades)
- [ ] `audit_log` — append-only (нет update/delete в ORM; триггеры SQLite)
- [ ] `pending_events` — таблица для гарантии доставки событий
- [ ] Alembic миграция создаётся и применяется без ошибок
- [ ] Все DateTime в UTC
- [ ] Шифрованные поля (encrypted_api_key, encryption_iv) — LargeBinary

## 3. Frontend (DEV-3)

- [ ] Соответствие UI-спецификации (`ui_spec.md`):
  - Sidebar: компоненты, иконки, поведение (collapse если указано)
  - Header: элементы, расположение
  - Цветовая схема: dark theme, Paper=жёлтый, Real=красный
- [ ] Mantine dark theme настроен в MantineProvider
- [ ] Routing: `/`, `/login`, 404
- [ ] Защищённые маршруты проверяют токен
- [ ] Zustand stores: authStore, uiStore
- [ ] Axios interceptor для JWT
- [ ] Форматирование ru-RU: числа (`1 234 567,89 ₽`), даты (`ДД.ММ.ГГГГ`)
- [ ] TypeScript strict mode
- [ ] Все тексты на русском

## 4. Инфраструктура (DEV-4)

- [ ] `scripts/install.sh` — устанавливает backend + frontend зависимости
- [ ] `scripts/start.sh` — запускает оба сервиса
- [ ] `.env.example` — все переменные
- [ ] `.github/workflows/ci.yml` — lint + type check + tests
- [ ] `.gitignore` — корректный (исключает .venv, node_modules, data/, .env)

## 5. Аутентификация (DEV-5)

- [ ] Argon2id хеширование (не bcrypt, не SHA)
- [ ] JWT: access (30 мин) + refresh (7 дней), HS256, payload с **sub/type/jti/iat/exp**
- [ ] **jti** (JWT ID) присутствует в каждом токене — уникальный UUID
- [ ] Revocation через таблицу **revoked_tokens** — logout добавляет jti
- [ ] Брутфорс-защита: блокировка после 5 попыток, HTTP **423** (Locked) + `retry_after: 900`
- [ ] Ошибки auth — generic "Неверный логин или пароль"
- [ ] `POST /api/v1/auth/setup` — создание первого пользователя (403 если уже есть)
- [ ] `POST /api/v1/auth/logout` — 204, revoke jti
- [ ] `PATCH /api/v1/auth/password` — (не POST /change-password)
- [ ] `GET /api/v1/auth/setup-status` — без JWT при users=0, 403 если пользователь есть
- [ ] TokenResponse содержит **expires_in** (секунды)
- [ ] Логирование попыток входа в audit_log
- [ ] Пароли нигде не логируются

## 5.5 UX-дизайн

- [ ] `ui_spec.md` создан и утверждён заказчиком
- [ ] Описаны все 3 экрана: layout (sidebar+header), дашборд, авторизация
- [ ] Указаны конкретные Mantine-компоненты, цвета, размеры
- [ ] Dark theme, цветовая система Paper/Real соответствует ФТ

## 6. Межмодульная интеграция

- [ ] Frontend API client baseURL совпадает с backend port (8000)
- [ ] CORS разрешает frontend origin (localhost:5173)
- [ ] Auth middleware подключён к защищённым endpoints
- [ ] Модели из разных модулей корректно ссылаются друг на друга (FK)

## 7. Тестирование (ФИНАЛЬНАЯ ПРОВЕРКА)

На Спринтах 1-2 тестирование — ответственность самих разработчиков. Ты проверяешь, что они это сделали качественно.

### 7.1 Запуск всех тестов

Выполни и проверь результат:
```bash
# Backend
cd backend && pip install -e .[dev] && pytest tests/ -v --tb=short

# Frontend
cd frontend && pnpm test
```

- [ ] **Backend: все тесты проходят (0 failures)**
- [ ] **Frontend: все тесты проходят (0 failures)**

### 7.2 Качество тестов (DEV-1: Backend Core)

- [ ] Тесты health endpoint: существуют, проверяют статус 200, содержимое ответа
- [ ] Тесты config: проверяют default values и чтение из env
- [ ] Тесты exceptions: проверяют HTTP-коды для каждого типа ошибки

### 7.3 Качество тестов (DEV-2: DB Models)

- [ ] Тесты моделей: создание записей, проверка полей
- [ ] Тест на Numeric для финансовых данных — **CRITICAL если отсутствует**
- [ ] Тест UNIQUE-ограничений (ohlcv, strategy_version)
- [ ] Тест audit_log триггеров (append-only)
- [ ] Тест миграции: alembic upgrade head → все таблицы созданы

### 7.4 Качество тестов (DEV-3: Frontend)

- [ ] Тесты форматирования: ru-RU числа и даты
- [ ] Тесты authStore: login/logout/isAuthenticated
- [ ] Тесты Sidebar: навигация рендерится

### 7.5 Качество тестов (DEV-5: Auth)

- [ ] Тесты регистрации: пользователь создаётся, хеш Argon2id
- [ ] Тесты логина: успех/неудача, generic error message
- [ ] Тесты JWT: создание, проверка, expiration
- [ ] Тесты брутфорс-защиты: блокировка после 5 попыток, 429
- [ ] Тесты API endpoints: register, login, refresh, me, setup-status

### 7.6 Интеграционная проверка

- [ ] `./scripts/install.sh` выполняется без ошибок
- [ ] `./scripts/start.sh` запускает backend + frontend
- [ ] Health endpoint отвечает 200
- [ ] Frontend открывается в браузере

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
- `APPROVED` — замечаний нет, можно мержить
- `APPROVED WITH MINOR` — мелкие замечания, можно мержить с фиксами
- `CHANGES REQUESTED` — есть CRITICAL/MAJOR, нужны исправления

Также предоставь **отчёт по тестам**:
```
### Отчёт по тестированию

**Backend:** X тестов, Y passed, Z failed
**Frontend:** X тестов, Y passed, Z failed

**Непокрытые области:** [если есть]
```

# Важно

- Будь строг к финансовым типам данных — Float для денег = CRITICAL
- Будь строг к безопасности — хардкод секретов, логирование паролей = CRITICAL
- Проверяй соответствие ТЗ, а не только "работает ли код"
- Frontend должен соответствовать ui_spec.md — отклонения = MAJOR
- **Отсутствие тестов у разработчика = MAJOR. Непроходящие тесты = CRITICAL**
- **ARCH запускает тесты сам и проверяет результат — не верь на слово разработчикам**
