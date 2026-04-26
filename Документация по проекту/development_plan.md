---

# ПЛАН РАБОТ КОМАНДЫ РАЗРАБОТЧИКОВ
## Торговый терминал для рынка ценных бумаг РФ (MOEX)

**Версия:** 2.0
**Дата:** 2026-03-23
**Основание:** Техническое задание v1.0 от 2026-03-23
**Статус:** Утверждён (после ревью PM)

> **Изменения относительно v1.0:** реорганизация состава команды (9 человек вместо 7), добавлены UX/UI-дизайнер и QA-инженер, объединены роли DB и AI в Backend #2, добавлен Frontend #2. Исправлена последовательность задач (CSRF/Rate Limiting перенесены в S3, Must-задачи убраны из Should-спринта). Тестирование встроено в каждый спринт.

---

## СОДЕРЖАНИЕ

1. Команда проекта и роли
2. Общая диаграмма спринтов и зависимости
3. Детальный план по спринтам
4. Матрица ответственности RACI
5. Контрольные точки (milestones)
6. Управление рисками

---

## 1. КОМАНДА ПРОЕКТА И РОЛИ

### 1.1 Состав команды

| # | Роль | Кол-во | Сокращение | Изменение (v2) |
|---|---|---|---|---|
| 1 | Технический архитектор | 1 | **ARCH** | Без изменений; делегирует часть ревью senior-разработчикам |
| 2 | Backend-разработчик #1 (senior) | 1 | **BACK1** | Переименован из BACK |
| 3 | Backend-разработчик #2 | 1 | **BACK2** | **Новый** — объединяет бывшие роли DB + AI |
| 4 | Frontend-разработчик #1 (senior) | 1 | **FRONT1** | Переименован из FRONT; фокус на Blockly, Charts, Trading |
| 5 | Frontend-разработчик #2 | 1 | **FRONT2** | **Новый** — формы, настройки, дашборд, простые экраны |
| 6 | UX/UI-дизайнер | 1 | **UX** | **Новый** — wireframes, UI-kit, юзабилити |
| 7 | QA-инженер | 1 | **QA** | **Новый** — тестирование в каждом спринте |
| 8 | DevOps-специалист | 1 | **OPS** | Без изменений |
| 9 | Специалист по безопасности | 1 | **SEC** | Без изменений |

**Итого: 9 человек** (было 7, добавлено 4 новых, убрано 2 выделенных)

### 1.2 Зоны ответственности

**Технический архитектор (ARCH):**
- Принятие ключевых архитектурных решений и разрешение технических споров
- Code review **межмодульных интерфейсов, API-контрактов, схемы БД, безопасности**
- Senior-разработчики (BACK1, FRONT1) самостоятельно аппрувят MR в своих модулях
- Проведение архитектурного ревью по итогам каждого спринта
- Контроль технического долга и соответствия ТЗ

**Backend-разработчик #1, senior (BACK1):**
- Trading Engine, Broker Adapter, Market Data Service
- Backtest Engine, Signal Processor, Order Manager
- WebSocket, Event Bus
- Аппрувит MR backend-модулей (кроме security и межмодульных)

**Backend-разработчик #2 (BACK2):**
- Схема БД, SQLAlchemy-модели, Alembic-миграции (бывш. DB)
- AI Service: pluggable providers, промпты, контекстное сжатие (бывш. AI)
- Strategy Engine (parser, code generator)
- Notification Service, Telegram Bot, экспорт

**Frontend-разработчик #1, senior (FRONT1):**
- Blockly-редактор стратегий (кастомные блоки, drag-and-drop)
- Графический модуль (TradingView Lightweight Charts, индикаторы, рисование)
- Trading Panel (real-time позиции, P&L)
- Аппрувит MR frontend-модулей

**Frontend-разработчик #2 (FRONT2):**
- Дашборд, экраны настроек, профиль, брокерские аккаунты
- AI sidebar chat, Notification Center
- Формы запуска (бэктест, торговая сессия)
- Экран результатов бэктеста

**UX/UI-дизайнер (UX):**
- Wireframes и интерактивные прототипы всех экранов
- UI-kit на базе Mantine (dark theme, цветовая система: Paper=жёлтый, Real=красный)
- Юзабилити-тестирование с целевой аудиторией после каждого спринта
- Дизайн Telegram-уведомлений, first-run wizard
- Контроль консистентности интерфейса

**QA-инженер (QA):**
- Написание тест-кейсов параллельно с разработкой (с S2)
- Ручное тестирование функционала по завершении каждого спринта
- Автоматизация E2E-тестов (Playwright) начиная с S3
- Верификация финансовых расчётов (P&L, комиссии, лотность, НКД)
- Регрессионное тестирование, security-тестирование (совм. с SEC)

**DevOps-специалист (OPS):**
- Скрипты установки и запуска, CI/CD (GitHub Actions)
- Логирование, мониторинг, health-check, backup
- Graceful shutdown, автозапуск, документация

**Специалист по безопасности (SEC):**
- Модуль аутентификации, JWT, защита от брутфорса
- Шифрование (AES-256-GCM), хеширование (Argon2id)
- Code Sandbox, Circuit Breaker
- CSRF, Rate Limiting, HTTP-заголовки, Security audit

---

## 2. ОБЩАЯ ДИАГРАММА СПРИНТОВ И ЗАВИСИМОСТИ

### 2.1 Временная шкала

```
Неделя:  1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16
         ├───────┤───────┤───────┤───────┤───────┤───────┤───────┤───────┤
Sprint:  │   S1  │   S2  │   S3  │   S4  │   S5  │   S6  │   S7  │   S8  │
         │Фундам.│ Данные│Стратег│AI+Бэк │Торговл│Уведомл│Полиров│ Тесты │
         ├───────┤───────┤───────┤───────┤───────┤───────┤───────┤───────┤
UX:      │wirefrm│charts │blockly│AI+bt  │trade  │notif  │should │polish │
QA:      │кейсы  │тесты  │E2E    │E2E    │E2E    │E2E    │E2E    │регресс│
```

**Общая длительность:** 16 недель (8 спринтов по 2 недели)

### 2.2 Граф зависимостей

```
S1 (Фундамент)
 │
 ▼
S2 (Данные + Графики)             Зависит от: S1 (auth, DB-модели)
 │
 ▼
S3 (Стратегии + Редактор + CSRF)  Зависит от: S2 (market data)
 │
 ▼
S4 (AI + Бэктестинг)              Зависит от: S3 (стратегии, sandbox)
 │
 ▼
S5 (Торговля + Bond/Corp.Actions) Зависит от: S4 (backtest engine), S2 (broker)
 │
 ├──────────────────┐
 ▼                  ▼
S6 (Уведомления)   S7 (Полировка — только Should)
 │                  │
 ├──────────────────┘
 ▼
S8 (Регрессия + Стабилизация)     Зависит от: S6 + S7 (feature freeze)
```

### 2.3 Критический путь

**S1 → S2 → S3 → S4 → S5 → S6 → S8** — 16 недель (без изменений).

**Ключевые изменения v2:**
- CSRF и Rate Limiting перенесены из S6 в S3 (SEC свободен)
- Bond Service и Corporate Actions перенесены из S7 в S5 (Must-приоритет)
- Тестирование встроено в каждый спринт (QA)
- UX-дизайн начинается с S1, wireframes готовы до начала frontend-кода

---

## 3. ДЕТАЛЬНЫЙ ПЛАН ПО СПРИНТАМ

### Обозначения

- **Исполнитель** — основной разработчик задачи
- **Ревьюер** — code review (ARCH для межмодульных; senior для внутримодульных)
- **Зависит от** — блокирующая зависимость
- **||** — задачи, выполняемые параллельно

---

### СПРИНТ 1: Фундамент (недели 1–2)

**Цель:** каркас приложения, инфраструктура, аутентификация, UI-kit.

| # | Задача | Исполнитель | Ревьюер | Зависит от | || |
|---|---|---|---|---|---|
| 1.1 | Wireframes ключевых экранов (дашборд, стратегия, бэктест, торговля, настройки, графики) | UX | ARCH, FRONT1 | — | 1.2, 1.3, 1.4 |
| 1.2 | UI-kit Mantine: dark theme, цветовая система, типографика, компоненты | UX | FRONT1 | 1.1 (частично) | 1.6 |
| 1.3 | Инициализация backend: FastAPI + SQLAlchemy, структура проекта | BACK1 | ARCH | — | 1.4, 1.5, 1.6 |
| 1.4 | Все SQLAlchemy-модели (23+ таблицы), Alembic init + первая миграция | BACK2 | ARCH, SEC | — | 1.3, 1.5 |
| 1.5 | Инициализация frontend: React + Vite + Mantine, структура проекта | FRONT1 | ARCH | — | 1.3, 1.4 |
| 1.6 | Auth module: регистрация, логин, JWT, refresh, защита от брутфорса | SEC | ARCH, BACK1 | 1.3, 1.4 | 1.7 |
| 1.7 | Frontend shell: layout, sidebar, header, routing, тёмная тема (по wireframes 1.1) | FRONT1 + FRONT2 | UX, ARCH | 1.2, 1.5 | 1.6 |
| 1.8 | Скрипты установки/запуска (install.sh, start.sh, .env.example) | OPS | ARCH | — | 1.3, 1.5 |
| 1.9 | CI/CD pipeline: GitHub Actions (lint + type check + unit tests) | OPS | ARCH | 1.3, 1.5 | 1.6, 1.7 |
| 1.10 | Health endpoint (/api/v1/health) | BACK1 | ARCH | 1.3 | 1.6, 1.7 |
| 1.11 | Подготовка тест-кейсов: авторизация, первый запуск, shell UI | QA | ARCH | 1.1 | 1.6, 1.7 |
| **1.R** | **Архитектурное ревью S1 + QA-приёмка:** структура, auth, БД, CI, wireframes | **ARCH + QA** | — | всё | — |

**Критерий завершения:** авторизация работает, дашборд отображается по wireframes, CI проходит, wireframes всех ключевых экранов утверждены. QA подтвердил тест-кейсы авторизации.

**Параллельность:**
```
Неделя 1:
  UX ───── 1.1 (wireframes) ──────── 1.2 (UI-kit) ─────────────────▶
  BACK1 ── 1.3 (init backend) ────── 1.10 (health) ────────────────▶
  BACK2 ── 1.4 (модели + миграции) ─────────────────────────────────▶
  FRONT1 ─ 1.5 (init frontend) ─────────────────────────────────────▶
  FRONT2 ─ [ожидание UI-kit] ───────────────────────────────────────▶
  SEC ──── [ожидание 1.3+1.4] ──── 1.6 (auth) ─────────────────────▶
  OPS ──── 1.8 (скрипты) ──────────────────────────────────────────▶
  QA ───── 1.11 (тест-кейсы по wireframes) ─────────────────────────▶

Неделя 2:
  UX ───── 1.2 (UI-kit, продолжение) ──────────────────────────────▶
  BACK1 ── помощь SEC с auth, ревью ────────────────────────────────▶
  BACK2 ── 1.4 (завершение), помощь SEC ────────────────────────────▶
  FRONT1 ─ 1.7 (shell по wireframes, совм. с FRONT2) ──────────────▶
  FRONT2 ─ 1.7 (layout, sidebar, header) ──────────────────────────▶
  SEC ──── 1.6 (auth, продолжение) ─────────────────────────────────▶
  OPS ──── 1.9 (CI/CD) ────────────────────────────────────────────▶
  QA ───── 1.11 → ручное тестирование auth ─────────────────────────▶
  ARCH ─── ревью по мере готовности → 1.R ──────────────────────────▶
```

---

### СПРИНТ 2: Данные и графики (недели 3–4)

**Цель:** подключить брокера, загрузить рыночные данные, отобразить графики.

| # | Задача | Исполнитель | Ревьюер | Зависит от | || |
|---|---|---|---|---|---|
| 2.1 | Broker Adapter: T-Invest — подключение, get_accounts, get_balance, get_historical_candles | BACK1 | ARCH, SEC | S1 | 2.2, 2.3 |
| 2.2 | MOEX ISS клиент (fallback для свечей + календарь) + MOEX Calendar Service | BACK2 | ARCH | S1 | 2.1, 2.3 |
| 2.3 | Market Data Service: кеш OHLCV, загрузка, валидация данных | BACK1 + BACK2 | ARCH | S1 | 2.1, 2.2 |
| 2.4 | Crypto Service (AES-256-GCM) для шифрования API-ключей | SEC | ARCH | S1 | 2.1, 2.5 |
| 2.5 | UX: детальный дизайн экранов графиков и настроек брокера | UX | FRONT1 | S1 (1.1) | 2.1, 2.4 |
| 2.6 | Frontend: Графики (TradingView LW Charts), выбор таймфрейма, volume (по дизайну 2.5) | FRONT1 | UX, ARCH | 2.5 | 2.7 |
| 2.7 | Frontend: Настройки аккаунта/брокера, добавление API-ключа | FRONT2 | UX, SEC | 2.4, 2.5 | 2.6 |
| 2.8 | Тест-кейсы S2 + ручное тестирование: графики, подключение брокера, шифрование | QA | ARCH | 2.1, 2.6, 2.7 | — |
| **2.R** | **Архитектурное ревью S2 + QA-приёмка:** BrokerAdapter interface, market data, crypto | **ARCH + QA** | — | всё | — |

**Критерий завершения:** брокер подключён, графики с историческими данными отображаются. API-ключи зашифрованы. QA прошёл тест-кейсы. UX утвердил дизайн графиков.

**Параллельность:**
```
  UX ───── 2.5 (дизайн графиков + настроек) ────────────────────────▶
  BACK1 ── 2.1 (T-Invest) ── 2.3 (Market Data Service) ────────────▶
  BACK2 ── 2.2 (MOEX ISS + Calendar) ── 2.3 (совм.) ───────────────▶
  FRONT1 ─ 2.6 (графики по дизайну) ────────────────────────────────▶
  FRONT2 ─ 2.7 (настройки брокера) ─────────────────────────────────▶
  SEC ──── 2.4 (CryptoService) ─────────────────────────────────────▶
  OPS ──── [помощь с CI, деплой-скрипты для dev-среды] ─────────────▶
  QA ───── тест-кейсы → 2.8 (ручное тестирование) ──────────────────▶
  ARCH ─── ревью → 2.R ─────────────────────────────────────────────▶
```

---

### СПРИНТ 3: Стратегии + Блочный редактор + Защита API (недели 5–6)

**Цель:** создание стратегий, генерация кода, CSRF/Rate Limiting.

| # | Задача | Исполнитель | Ревьюер | Зависит от | || |
|---|---|---|---|---|---|
| 3.1 | Strategy CRUD API + модели | BACK1 | ARCH | S2 | 3.2, 3.4, 3.5 |
| 3.2 | Blockly: кастомные блоки (индикаторы, условия, сигналы, фильтры) | FRONT1 | UX, ARCH | S2 | 3.1, 3.3 |
| 3.3 | UX: дизайн Strategy Editor (Blockly workspace, AI chat sidebar, code tab) | UX | FRONT1, ARCH | S1 | 3.2 |
| 3.4 | Code Generator: блоки → Python/Backtrader код | BACK2 | ARCH, BACK1 | 3.1 | 3.2, 3.5 |
| 3.5 | Template Parser (режим B): текст шаблона → блочная схема | BACK2 | ARCH | 3.1 | 3.4, 3.6 |
| 3.6 | Code Sandbox: AST-анализ + RestrictedPython + ограничение ресурсов | SEC | ARCH, BACK1 | S1 | 3.1, 3.7 |
| 3.7 | **CSRF protection (middleware, токены)** | SEC | ARCH, BACK1 | S1 | 3.6, 3.8 |
| 3.8 | **Rate limiting внутреннего API (sliding window, 100/10 req/min)** | SEC | ARCH, BACK1 | S1 | 3.7 |
| 3.9 | Frontend: Strategy Editor page (Blockly + Code + Description tabs, по дизайну 3.3) | FRONT1 | UX, ARCH | 3.2, 3.3 | 3.10 |
| 3.10 | Frontend: режим B — модальное окно, кнопка «Скопировать шаблон» | FRONT2 | UX | 3.9 | — |
| 3.11 | E2E-тесты S3: создание стратегии, Blockly, mode B | QA | ARCH | 3.9, 3.10 | — |
| **3.R** | **Архитектурное ревью S3 + QA-приёмка:** блочная схема JSON, sandbox, CSRF, rate limiting | **ARCH + QA** | — | всё | — |

**Критерий завершения:** стратегия создаётся в блочном редакторе или через шаблон. Sandbox блокирует вредоносный код. **API защищён CSRF и rate limiting.** QA прошёл E2E.

**Параллельность:**
```
  UX ───── 3.3 (дизайн Strategy Editor) ────────────────────────────▶
  BACK1 ── 3.1 (Strategy API) ──────────────────────────────────────▶
  BACK2 ── 3.4 (codegen) ── 3.5 (parser) ───────────────────────────▶
  FRONT1 ─ 3.2 (Blockly блоки) ── 3.9 (editor page) ───────────────▶
  FRONT2 ─ [доработки S2] ── 3.10 (mode B) ─────────────────────────▶
  SEC ──── 3.6 (sandbox) ── 3.7 (CSRF) ── 3.8 (rate limiting) ─────▶
  OPS ──── [помощь с CI, мониторинг] ────────────────────────────────▶
  QA ───── тест-кейсы → 3.11 (E2E) ─────────────────────────────────▶
  ARCH ─── ревью → 3.R ─────────────────────────────────────────────▶
```

---

### СПРИНТ 4: AI-интеграция + бэктестинг (недели 7–8)

**Цель:** AI-ассистент, движок бэктестинга, результаты.

| # | Задача | Исполнитель | Ревьюер | Зависит от | || |
|---|---|---|---|---|---|
| 4.1 | AI Service: pluggable providers (Claude, OpenAI, Custom), хранение ключей в БД | BACK2 | ARCH, SEC | S1 | 4.4 |
| 4.2 | AI chat API + SSE streaming | BACK2 + BACK1 | ARCH | 4.1 | 4.4 |
| 4.3 | UX: дизайн экранов бэктеста (3 вкладки) + AI sidebar chat | UX | FRONT1, FRONT2 | S3 (3.3) | 4.1, 4.4 |
| 4.4 | Backtest Engine: Backtrader wrapper, метрики, equity curve, benchmark | BACK1 | ARCH | S3 (3.4, 3.6) | 4.1 |
| 4.5 | Backtest API + прогресс через WebSocket | BACK1 | ARCH | 4.4 | 4.6, 4.7 |
| 4.6 | Frontend: AI sidebar chat в Strategy Editor | FRONT2 | UX, ARCH | S3 (3.9), 4.2 | 4.7 |
| 4.7 | Frontend: Backtest Results (3 вкладки: обзор, график, сделки, по дизайну 4.3) | FRONT1 | UX, ARCH | 4.3, 4.5 | 4.6, 4.8 |
| 4.8 | Frontend: форма запуска бэктеста + Настройки AI-провайдеров | FRONT2 | UX | 4.1, 4.5 | 4.7 |
| 4.9 | E2E-тесты S4: полный цикл бэктеста, AI chat (mock), результаты | QA | ARCH | 4.7, 4.8 | — |
| **4.R** | **Архитектурное ревью S4 + QA-приёмка:** AI interface, backtest engine, WebSocket | **ARCH + QA** | — | всё | — |

**Критерий завершения:** полный цикл: стратегия (с AI или без) → бэктест → результаты. AI-ключи настраиваются через UI. QA подтвердил E2E.

**Параллельность:**
```
  UX ───── 4.3 (дизайн бэктеста + AI chat) ─────────────────────────▶
  BACK1 ── 4.4 (Backtest Engine) ── 4.5 (API + WS) ─────────────────▶
  BACK2 ── 4.1 (AI Service) ── 4.2 (chat API, совм. с BACK1) ──────▶
  FRONT1 ─ 4.7 (Backtest Results по дизайну) ────────────────────────▶
  FRONT2 ─ 4.8 (форма + AI settings) ── 4.6 (AI chat sidebar) ─────▶
  SEC ──── ревью 4.1 (шифрование ключей) ────────────────────────────▶
  OPS ──── [мониторинг, помощь с WebSocket deploy] ──────────────────▶
  QA ───── тест-кейсы → 4.9 (E2E) ──────────────────────────────────▶
  ARCH ─── ревью → 4.R ─────────────────────────────────────────────▶
```

---

### СПРИНТ 5: Торговля + Bond/Corporate Actions (недели 9–10) — ✅ завершено

**Цель:** Paper Trading, Circuit Breaker, Must-функционал облигаций и корп. действий.

| # | Задача | Исполнитель | Ревьюер | Зависит от | Статус |
|---|---|---|---|---|---|
| 5.1 | Trading Engine: session manager, signal processor, order manager, position tracker | BACK1 | ARCH, SEC | S4, S2 | ✅ S5 |
| 5.2 | Paper Trading Engine (виртуальный портфель, эмуляция T+1) | BACK1 | ARCH | 5.1 | ✅ S5 |
| 5.3 | Circuit Breaker (все лимиты: daily loss, drawdown, position size, trade count, cooldown, funds streak) | SEC | ARCH, BACK1 | 5.1 | ✅ S5 |
| 5.4 | Broker Adapter: place_order, cancel_order, subscribe_candles (streaming) | BACK1 | ARCH, SEC | S2 (2.1) | ✅ S5 |
| 5.5 | Rate limiter для брокерского API (token bucket + персистентность) | BACK1 | ARCH | 5.4 | ✅ S5 |
| 5.6 | UX: дизайн Trading Panel (карточки сессий, Paper vs Real визуализация) | UX | FRONT1 | S4 | ✅ S5 |
| 5.7 | Frontend: Trading Panel (карточки сессий, форма запуска, позиции, P&L, по дизайну 5.6) | FRONT1 | UX, ARCH | 5.1, 5.6 | ✅ S5 |
| 5.8 | Frontend: Real-time обновление графиков через WebSocket + индикаторы | FRONT1 | ARCH | S2 (2.6), 5.4 | ✅ S5 |
| 5.9 | **Bond Service (расчёт НКД) + Corporate Action Handler** | BACK2 | ARCH | S2 | ✅ S5 |
| 5.10 | **Налоговый экспорт (Tax Report Generator, FIFO, 3-НДФЛ)** | BACK2 | ARCH | 5.9 | ✅ S5 |
| 5.11 | Frontend: экран «Счёт» (баланс, позиции, операции, налоговый отчёт) | FRONT2 | UX | S2 (2.7), 5.9 | ✅ S5 |
| 5.12 | E2E-тесты S5: Paper Trading, Circuit Breaker, Bond P&L | QA | ARCH | 5.2, 5.3, 5.7 | ✅ S5 (23 E2E) |
| **5.R** | **Архитектурное ревью S5 + QA-приёмка:** Trading Engine, CB, Bond, latency < 500ms | **ARCH + QA** | — | всё | ✅ PASS |

**Критерий завершения:** ✅ Paper Trading запущен, сделки видны в реальном времени. Circuit Breaker активен. Расчёт НКД и корп. действия работают (Must). QA подтвердил E2E. 548 backend tests + 23 E2E. **Продолжено в S5R / S5R-2 (Live Runtime Loop, chart hardening).**

**Параллельность:**
```
  UX ───── 5.6 (дизайн Trading Panel) ──────────────────────────────▶
  BACK1 ── 5.1 (Trading Engine) ── 5.2 (Paper) ── 5.4 (orders) ── 5.5 (rate limit) ▶
  BACK2 ── 5.9 (Bond+Corp Actions) ── 5.10 (налоговый экспорт) ────▶
  FRONT1 ─ 5.8 (real-time + индикаторы) ── 5.7 (Trading Panel) ────▶
  FRONT2 ─ 5.11 (экран Счёт) ───────────────────────────────────────▶
  SEC ──── 5.3 (Circuit Breaker) ────────────────────────────────────▶
  OPS ──── [мониторинг, помощь с streaming] ─────────────────────────▶
  QA ───── тест-кейсы → 5.12 (E2E) ─────────────────────────────────▶
  ARCH ─── ревью → 5.R ─────────────────────────────────────────────▶
```

---

### SPRINT 5 REVIEW: Внеплановое промежуточное ревью (стабилизация перед S6)

**Когда:** между S5 и S6, открыто 2026-04-14, **закрыто 2026-04-14** (в тот же день).
**Цель:** устранить накопленный технический и процессный долг, который блокирует корректный запуск Sprint 6.
**Причина созыва:** ретроспектива S5 выявила 5 слабостей промптов DEV-субагентов (привели к 41 замечанию ручного тестирования и двум техдолгам), плюс Gmail MCP обнаружил, что CI красный 11+ дней и никто не смотрел на failed-уведомления.
**Статус:** ✅ **завершён** — все 6 задач сданы, финальный вердикт ARCH: **PASS WITH NOTES**. Техдолг High закрыт (4 → 0). Ветки: `s5r/ci-cleanup`, `s5r/e2e-s4-fix`, `s5r/live-runtime-loop`, `s5r/real-positions` — готовы к мержу в `develop`.
**Файлы:** `Спринты/Sprint_5_Review/` — `README.md`, `backlog.md`, `execution_order.md` (с Cross-DEV contracts C1-C11), 4× `PENDING_S5R_*.md`, `arch_review_s5r.md`, `changelog.md`, `preflight_checklist.md`, 4× `prompt_*.md`.

| # | Задача | Исполнитель | Ревьюер | Зависит от | Блокирует |
|---|---|---|---|---|---|
| **S5R.1** | **CI cleanup** (backend ruff per-file-ignores для alembic/env.py; frontend адаптация React 19 правил `react-hooks/refs`, `set-state-in-effect`, `incompatible-library`; массовый фикс `no-unused-vars`/`no-explicit-any`) — зелёный baseline CI | DEV-1 | ARCH | — | S5R.2, S5R.3, S5R.4 |
| **S5R.2** | **Live Runtime Loop** (`SessionRuntime` в `app/trading/runtime.py`, поле `TradingSession.timeframe` + миграция, новый sandbox-контракт с `candles: list[dict]`, UI-селектор TF, вывод TF в списке сессий) — **блокер всего S6** | DEV-2 (senior) | ARCH | S5R.1 | S6 полностью |
| **S5R.3** | **Реальные позиции и операции T-Invest** (`broker/router.py` заглушки → реальный `OperationsService.GetPortfolio`/`GetOperations`, маппер `portfolio_position_to_broker_position`, multi-currency) | DEV-3 | ARCH | S5R.1 | — |
| **S5R.4** | **E2E S4 fix** (30+ падающих тестов AI Chat / Backtest / Blockly: обновление селекторов, URL с `?tab=description`, моков API, flaky → waitFor, не-spec файлы → helpers/) | DEV-1 | ARCH | S5R.1 | S5R.2 (валидация) |
| **S5R.5** | **Обкатка нового процесса работы DEV-субагентов** — процессная задача, применяется в S5R.1-4. Каждый prompt по `prompt_template.md`, Stack Gotchas из `Develop/CLAUDE.md`, Integration Verification, отчёт до 400 слов, Cross-DEV contracts в `execution_order.md`. Первое практическое применение. | Оркестратор + все DEV + ARCH | ARCH | S5R.1-4 | S6 (с validated process) |
| **S5R.6** | **Актуализация ФТ/ТЗ** за S5 + S5R (разделы 5.4 Trading Engine, 6.6-6.7 UI, 7.3 Счёт, 12.4 Circuit Breaker) + обновление `development_plan.md` | ARCH | — | S5R.1-5 | — |
| **S5R.R** | **Финальное ARCH-ревью S5R** — сводка по 6 задачам, полный тестовый прогон (pytest + vitest + Playwright), проверка integration verification для Live Runtime Loop, **обязательная оценка эффективности нового процесса работы DEV-субагентов** (что сработало, что доработать в `prompt_template.md` / Stack Gotchas перед S6) | ARCH + QA | — | всё | Запуск S6 |

**Критерий завершения S5R:** CI зелёный (включая `pytest`, `vitest`, опционально `playwright`). Live Runtime Loop замкнут и подтверждён E2E-тестом «fake-стрим → ордер в БД». Реальные позиции T-Invest работают в разделе «Счёт». E2E S4 зелёные. ФТ/ТЗ актуальны. `Develop/CLAUDE.md` секция Stack Gotchas дополнена новыми ловушками. `prompt_template.md` доработан по итогам обкатки (если нужно). `arch_review_s5r.md` создан.

**После S5R (факт):** Sprint 6 стартует с зелёным CI, замкнутым runtime (`SessionRuntime.process_candle` вызывается из `runtime.py:374`, создаётся в `main.py:61`), реальными позициями T-Invest в разделе «Счёт», Playwright baseline 101 passed / 8 skipped и обкатанным процессом работы DEV-субагентов (10 Stack Gotchas, Cross-DEV contracts C1-C11 подтверждены).

**Новые задачи в backlog Sprint 6 по итогам S5R (создать при открытии S6):**
- `S6-MODEL-FIGI` — расширить `LiveTrade` полем `figi`, перевести source-правило позиций на match по FIGI (вместо ticker+account).
- `S6-PLAYWRIGHT-NIGHTLY` — отдельный workflow `playwright-nightly.yml` с cron в рабочие часы MSK, только стабильные specs.
- `S6-E2E-FAVORITES-INPUT` — вернуть text-input поиска в FavoritesPanel, снять 4 E2E skip-тикетов `S5R-FAVORITES-INPUT`.
- `S6-E2E-PAPER-REAL-MODE` — non-sandbox fixture для Real-mode switcher теста, снять skip `S5R-PAPER-REAL-MODE`.
- `S6-E2E-CHART-MOCK-ISS` — моки ISS для нерабочих часов (Gotcha 10), снять 3 skip-тикета `S5R-CHART-FRESHNESS`.

---

### СПРИНТ 6: Уведомления + восстановление (недели 11–12)

**Цель:** система уведомлений (Telegram + Email + In-app), восстановление после перезапуска backend, graceful shutdown.

**⚠️ Предусловие:** Sprint_5_Review полностью завершён. Задачи 6.0 (Live Runtime Loop) и 6.9 (реальные позиции T-Invest) из предыдущей версии плана **перенесены в Sprint_5_Review** и **удалены из S6**.

| # | Задача | Исполнитель | Ревьюер | Зависит от | Статус |
|---|---|---|---|---|---|
| 6.1 | Telegram-бот: привязка, уведомления, команды (/positions, /status, /help) | BACK2 (DEV-2) | ARCH, SEC | S5R | ✅ S6 |
| 6.2 | Email-уведомления (SMTP через aiosmtplib) | BACK2 (DEV-2) | ARCH | S5R | ✅ S6 |
| 6.3 | In-app уведомления (WebSocket) + Event Bus + NotificationService | BACK1 (DEV-1) | ARCH | S5R | ✅ S6 |
| 6.4 | Восстановление после перезапуска: real-сессии (сверка позиций) | BACK1 (DEV-1) | ARCH, SEC | S5R | ✅ S6 |
| 6.5 | Graceful Shutdown (suspend + pending 30s + notify) | BACK1 (DEV-1) | ARCH | 6.4 | ✅ S6 |
| 6.6 | UX: дизайн Notification Center + Telegram-сообщений | — | — | — | ⏭️ skip (inline design) |
| 6.7 | Frontend: Notification Center (Bell, Drawer, Banner, Settings, /notifications) | FRONT2 (DEV-4) | UX, ARCH | 6.3 | ✅ S6 |
| 6.8 | Frontend: доработки Trading Panel по результатам QA S5R | FRONT1 (DEV-4) | UX | S5R | ⏭️ skip (нет замечаний) |
| 6.9 | E2E-тесты S6: уведомления, Telegram (mock), восстановление, graceful shutdown | QA (DEV-7) | ARCH | 6.1-6.7 | ✅ S6 (10 E2E) |
| 6.10 | Security-тестирование: CSRF, rate limiting, sandbox escape | QA + SEC (DEV-7) | ARCH | S3 | ✅ S6 (23 тест) |
| **6.R** | **Архитектурное ревью S6 + QA-приёмка** | **ARCH** | — | всё | ✅ **PASS** (чистый, 4 замечания ARCH исправлены) |

**Дополнительные задачи S6 (не в исходном плане):**

| # | Задача | DEV | Статус |
|---|---|---|---|
| 6.0 | S6-STRATEGY-UNDERSCORE-NAMES — багфикс code_generator.py | DEV-0 | ✅ |
| 6.S3 | T-Invest SDK upgrade beta59→beta117 | DEV-3 | ✅ |
| 6.S5 | T-Invest Stream Multiplex (persistent gRPC) | DEV-5 | ✅ |
| 6.S6 | E2E Infrastructure (playwright-nightly, ISS moки, mocks expansion) | DEV-6 | ✅ |
| 6.ARCH-1 | API prefix mismatch fix (notification → notifications) | BACK1 | ✅ |
| 6.ARCH-2 | CriticalBanner — fetchNotifications при mount | FRONT2 | ✅ |
| 6.ARCH-3 | SchedulerService (APScheduler 3.x, 3 cron + T+1 unlock) | BACK1 | ✅ |
| 6.ARCH-4 | Telegram Should-команды /balance, /close, /closeall | BACK2 | ✅ |
| 6.X1 | Расширенные карточки сессий (P&L + unrealized, W/L, маркеры графика) | BACK1 + FRONT1 | ✅ (2026-04-22) |
| 6.X2 | CB fixes: trading_hours до 23:50 MSK, commit after trigger, temporary блокировки | BACK1 | ✅ (2026-04-22/23) |
| 6.X3 | PauseConfirmModal (предупреждение при паузе с открытой позицией) | FRONT1 | ✅ (2026-04-22) |
| 6.X4 | Маркеры сделок на графике (3-уровневый дизайн, sequential mode) | FRONT1 | ✅ (2026-04-22/24) |
| 6.X5 | Price alerts: PriceAlertMonitor + deletion UI + MSK timestamps | BACK1 + FRONT1 | ✅ (2026-04-21) |
| 6.X6 | Фикс downtime calculation в восстановлении session_recovered | BACK1 | ✅ (2026-04-23) |

**Критерий завершения:** Уведомления работают (Telegram + email + in-app). Восстановление после рестарта подтверждено (сессии поднимают свои listener'ы заново через `SessionRuntime.start()`). Graceful shutdown корректно останавливает все runtime. Security-тесты пройдены. QA подтвердил E2E.

**Факт (2026-04-17):** ARCH Review: **PASS WITH NOTES**. 6.1–6.7 ✅, 6.9–6.10 pending (DEV-7). Backend 662 passed (+39), Frontend 250 passed (+12). 3 канала уведомлений. Recovery для Real-сессий. Graceful Shutdown с pending orders 30s. SDK beta117. Persistent gRPC multiplexer. E2E полностью на моках. Stack Gotcha 17 (telegram frozen attrs).

**Факт (2026-04-24, Sprint 6 closeout):** ARCH Review notes исправлены (4/4). DEV-7 завершён (10 E2E + 23 security). Доп. работы 22-24.04: карточки сессий (Decimal→Number, unrealized P&L), CB fixes (commit, trading hours 23:50, downtime), маркеры графика (3-level), правила плагинов в CLAUDE.md, Playwright автологин, gotcha-18. **Итог:** 685 backend + 250 frontend + 10 E2E = **945 тестов, 0 failures**. 18 Stack Gotchas. **PASS (чистый)**.

**Параллельность:**
```
  UX ───── 6.6 (дизайн уведомлений) ── [начало дизайна S7] ─▶
  BACK1 ── 6.3 (in-app + event bus) ── 6.4 (recovery) ─────▶
  BACK2 ── 6.1 (Telegram) ── 6.2 (email) ───────────────────▶
  FRONT1 ─ 6.8 (доработки Trading Panel) ───────────────────▶
  FRONT2 ─ 6.7 (Notification Center) ───────────────────────▶
  SEC ──── 6.10 (security-тестирование, совм. с QA) ────────▶
  OPS ──── 6.5 (graceful shutdown) ──────────────────────────▶
  QA ───── 6.9 (E2E) ── 6.10 (security tests) ──────────────▶
  ARCH ─── ревью → 6.R ──────────────────────────────────────▶
```

---

### SPRINT 6 REVIEW: Промежуточное ревью M3 (после S5 + S5R + S5R-2 + S6)

**Когда:** 2026-04-24, между S6 и S7.
**Цель:** итоговая проверка Milestone M3 (Торговля + Уведомления) перед переходом к M4 (Production).
**Статус:** ✅ завершено 2026-04-24.
**Файлы:** `Спринты/Sprint_6_Review/` — `README.md`, `code_review.md`, `backlog.md`.

| # | Задача | Исполнитель | Статус |
|---|---|---|---|
| SR6.1 | Code review 8 разделов (архитектура, Trading Engine, CB, Notifications, Market Data, Frontend, Security, Tests) | ARCH | ✅ |
| SR6.2 | Применение 6 фиксов code review (EMAIL_ALLOWED_EVENTS, PauseConfirmModal useEffect, dead SELECT, docstring CB, console.error/log) | DEV + ARCH | ✅ |
| SR6.3 | E2E Playwright полный прогон + исправление pre-existing падений (12 тестов) | ARCH + DEV | ✅ (107→119 passed) |
| SR6.4 | Визуальная верификация нового S6-функционала через Playwright MCP (Notification Drawer/Settings, Trading cards, Feed, AI, Chart markers) | ARCH | ✅ |
| SR6.5 | 3 code fixes, обнаруженных при E2E/визуальной верификации (AISettingsPage crash providers/toLocaleString, marketDataStore crash candles=undefined) | DEV + ARCH | ✅ |
| SR6.6 | Фикс EVENT_MAP шаблонов (8 publish-сайтов в runtime.py/engine.py — добавлены strategy_name, ticker, direction, volume, pnl для 5 event_type) | ARCH | ✅ |
| SR6.7 | Актуализация ФТ/ТЗ/development_plan за S5+S6 | ARCH | ✅ |
| **SR6.R** | **Финальный вердикт ревью** | ARCH | ✅ **PASS** |

**Статистика:** 11 FIXED, 1 FP (CRITICAL → FP), 3 WARNING перенесены в S7, 1 INFO перенесён в S8.

**Перенесено в Sprint 7:**
- NotificationService 9 инстансов → singleton через DI
- 5 event_type подключить к runtime (`trade_opened`, `partial_fill`, `order_error`, `all_positions_closed`, `connection_lost/restored`)
- Telegram inline-кнопки без CallbackQueryHandler

**Критерий завершения Sprint_6_Review:** ✅ E2E зелёные (119/0/3), визуальная верификация пройдена (6/6), все CRITICAL закрыты, ФТ/ТЗ/development_plan актуализированы.

---

### СПРИНТ 7: Полировка + Should-фичи + AI слэш-команды (недели 13–14) — ✅ ЗАВЕРШЁН (2026-04-26)

**Цель:** Should-функции, переносы из S6, AI-команды и финальная полировка UI. **Phase 1 feature-complete.**

> **Примечание v2:** Must-задачи (Bond Service, Corporate Actions, налоговый экспорт) перенесены в S5. В S7 остаются только Should-фичи, приоритизированные по ценности.
> **Примечание v3 (Sprint_7_ARCH 7.R):** в S7 фактически реализовано 17 рабочих задач + 7.R = 18 задач. Добавлены 7.18 / 7.19 (AI слэш-команды) — отсутствовали в плане v2, добавлены по решению заказчика 2026-04-25.
> **Корректировка RACI:** 7.1 и 7.12 переназначены с BACK1 на BACK2 (соответствие RACI: Strategy Engine = BACK2 R, Notification Service = BACK2 R).

| # | Задача | Исполнитель (факт) | Ревьюер | Статус |
|---|--------|--------------------|---------|--------|
| 7.1 | Версионирование стратегий (история, snapshot, history-preserving откат) | BACK2 + FRONT2 | ARCH | ✅ |
| 7.2 | Grid Search (multiprocessing.Pool, hard cap 1000, heatmap) | BACK1 + FRONT2 | ARCH | ✅ |
| 7.3 | Экспорт CSV/PDF бэктеста (WeasyPrint) | BACK2 + OPS | ARCH | ✅ |
| ~~7.4~~ | ~~Telegram-команды~~ → ✅ сделано в S6 | — | — | — |
| ~~7.5~~ | ~~Ценовые алерты~~ → ✅ сделано в S6 | — | — | — |
| 7.6 | Инструменты рисования (5 типов, hotkeys, REST persist) | FRONT1 | UX, ARCH | ✅ |
| 7.7 | Дашборд-виджеты (Balance + sparkline / Health / ActivePositions) | FRONT2 (+ FRONT1 MiniSparkline, BACK1 C9) | UX, ARCH | ✅ |
| 7.8 | First-run wizard (5 шагов, gate на дисклеймере) | FRONT2 + BACK2 | UX, ARCH | ✅ |
| 7.9 | Backup/restore (CLI + APScheduler 03:00 UTC, WAL-aware SQLite) | OPS | ARCH | ✅ |
| 7.10 | UX финальная полировка + ui_checklist_s7.md | UX | ARCH | ✅ |
| 7.11 | E2E финальный регресс (136 passed / 0 failed / 3 skipped) | QA | ARCH | ✅ |
| **7.12** | **NotificationService singleton через DI** (перенос из S6) | BACK2 | ARCH | ✅ |
| **7.13** | **Подключение 5 event_type к runtime** (MR.5): trade_opened, partial_fill, order_error, connection_lost/restored | BACK1 | ARCH, SEC | ✅ |
| **7.14** | **Telegram inline-кнопки** (CallbackQueryHandler) | BACK2 | ARCH, SEC | ✅ |
| **7.15** | **WS-обновление карточек сессий** (`/ws/trading-sessions/{user_id}`) | BACK1 + FRONT1 | ARCH | ✅ |
| **7.16** | **Интерактивные зоны бэктеста + аналитика** (гистограмма P&L + donut Win/Loss) | FRONT1 | ARCH, UX | ✅ |
| **7.17** | **Фоновый запуск бэктеста** (cap=3, бейдж, dropdown, WS) | BACK1 + FRONT1 | ARCH | ✅ |
| **7.18** | **AI слэш-команды backend** (расширение `ChatRequest.context_items`, защита от prompt injection) | BACK2 | ARCH, SEC | ✅ |
| **7.19** | **AI слэш-команды frontend** (Mantine Combobox dropdown, 5 команд, ContextChip) | FRONT1 | UX, ARCH | ✅ |
| **7.R** | **Архитектурное ревью S7 + QA-приёмка + UX-приёмка** | **ARCH + QA + UX** | — | ✅ PASS WITH NOTES (2026-04-26) |

**Критерий завершения:** Phase 1 feature-complete. Все Must + реализованные Should функции работают. **M3 Phase 1 достигнут.**

**Финальные тесты S7 (2026-04-26):**
- Backend pytest: **885 passed / 0 failed**
- Frontend vitest: **394 passed / 0 failed**, tsc 0 errors
- Frontend Playwright: **136 passed / 0 failed / 3 skipped** (baseline 119 + 17 новых)

**Stack Gotchas созданы в S7:** #19 (SQLite WAL backup), #20 (FastAPI route ordering), #21 (Grid Search multiprocessing.Pool — UPDATE финальный), #22 (Mantine Combobox.Target testid clone).

> **Приоритизация Should-фич (при нехватке времени отбрасывать снизу):**
> 1. Версионирование стратегий (7.1)
> 2. Экспорт CSV/PDF (7.3)
> 3. Дашборд виджеты (7.7)
> 4. Ценовые алерты (7.5)
> 5. Grid Search (7.2)
> 6. Telegram-команды (7.4)
> 7. Инструменты рисования (7.6)

---

### СПРИНТ 8: Регрессия + стабилизация (недели 15–16)

**Цель:** production-ready: регрессионные тесты, performance, security audit, документация.

> **Изменение v2:** основной объём unit/integration-тестов написан в S2–S7 (каждый спринт). S8 — регрессия, performance, финальный аудит.

| # | Задача | Исполнитель | Ревьюер | Зависит от | || |
|---|---|---|---|---|---|
| 8.1 | Регрессионный прогон всех E2E-тестов + доработка пропущенных | QA | ARCH | S7 | 8.2, 8.3 |
| 8.2 | Дополнение unit-тестов: coverage до ≥ 80% по каждому модулю | BACK1 + BACK2 + SEC | ARCH | S7 | 8.1, 8.3 |
| 8.3 | Frontend unit-тесты: форматирование ru-RU, Blockly, WebSocket reconnect | FRONT1 + FRONT2 | ARCH | S7 | 8.1, 8.2 |
| 8.4 | Performance testing: дашборд < 2с, сигнал→ордер < 500мс, Telegram < 3с | BACK1 | ARCH | S7 | 8.5 |
| 8.5 | Security audit: crypto, sandbox escape, CSRF, headers, brute-force | SEC + QA | ARCH | S7 | 8.4 |
| 8.6 | Bug fixing (все участники по своим модулям) | ВСЕ | ARCH | 8.1–8.5 | — |
| 8.7 | UX: финальный юзабилити-тест с пользователем, список UX-багов | UX | FRONT1, FRONT2 | 8.6 | 8.8 |
| 8.8 | Исправление UX-багов по результатам юзабилити-теста | FRONT1 + FRONT2 | UX | 8.7 | 8.9 |
| 8.9 | Документация: README, deployment guide, changelog | OPS | ARCH | 8.6 | 8.8 |
| **8.R** | **Финальное архитектурное ревью + QA sign-off + UX sign-off** | **ARCH + QA + UX** | — | всё | — |

**Критерий завершения:** test coverage ≥ 80%, E2E регрессия пройдена, security audit пройден, performance targets достигнуты, юзабилити-тест пройден. **Production-ready Phase 1.**

---

## 4. МАТРИЦА ОТВЕТСТВЕННОСТИ RACI

**R** = Responsible, **A** = Accountable, **C** = Consulted, **I** = Informed

| Модуль / Задача | ARCH | BACK1 | BACK2 | FRONT1 | FRONT2 | UX | QA | OPS | SEC |
|---|---|---|---|---|---|---|---|---|---|
| **Архитектурные решения** | **R/A** | C | C | C | | C | | C | C |
| **Code review (межмодульные)** | **R/A** | I | I | I | I | | | | I |
| **Code review (backend)** | A | **R** | I | | | | | | |
| **Code review (frontend)** | A | | | **R** | I | C | | | |
| Схема БД, миграции | A | C | **R** | | | | | | C |
| FastAPI app, middleware | A | **R** | C | | | | | | C |
| Auth module | A | C | | | | | | | **R** |
| Strategy Engine (parser, codegen) | A | C | **R** | | | | | | |
| Blockly editor | A | | | **R** | | C | | | |
| AI Service (providers, prompts) | A | C | **R** | | | | | | C |
| AI chat frontend | A | | | | **R** | C | | | |
| Backtest Engine | A | **R** | | | | | | | |
| Trading Engine | A | **R** | | | | | | | C |
| Broker Adapter | A | **R** | | | | | | | |
| Market Data Service | A | **R** | C | | | | | | |
| Charts (TradingView) | A | | | **R** | | C | | | |
| Notification Service | A | | **R** | | C | | | | |
| Telegram Bot | A | | **R** | | | | | C | C |
| Circuit Breaker | A | C | | | | | | | **R** |
| Code Sandbox | A | C | | | | | | | **R** |
| Crypto, CSRF, Rate Limiting | A | | | | | | | | **R** |
| Bond Service, Corp. Actions | A | | **R** | | | | | | |
| Tax Report Generator | A | | **R** | | C | | | | |
| Deploy scripts, CI/CD | A | | | | | | | **R** | |
| Backup, Logs, Health | A | C | | | | | | **R** | |
| Dashboard, Settings UI | A | | | | **R** | C | | | |
| Trading Panel | A | | | **R** | | C | | | |
| Wireframes, UI-kit | A | | | C | C | **R** | | | |
| Юзабилити-тестирование | A | | | I | I | **R** | C | | |
| E2E-тесты (Playwright) | A | | | C | C | | **R** | | |
| Ручное тестирование | A | | | | | | **R** | | |
| Unit/Integration-тесты | A | **R** | **R** | C | C | | C | | **R** |
| Security audit | A | I | I | I | I | | C | | **R** |
| Performance testing | A | **R** | | C | | | C | | |
| Документация | A | C | C | | | | | **R** | |

---

## 5. КОНТРОЛЬНЫЕ ТОЧКИ (MILESTONES)

| # | Milestone | Неделя | Критерии прохождения | Статус |
|---|---|---|---|---|
| **M1** | **Каркас + wireframes** | 2 (S1) | Auth работает, дашборд по wireframes, CI проходит, wireframes утверждены UX. QA подтвердил тест-кейсы auth | ✅ завершён |
| **M2** | **Полный цикл бэктеста** | 8 (S4) | Стратегия → бэктест → результаты. AI через UI. CSRF+Rate Limiting активны. QA прошёл E2E | ✅ завершён |
| **M3** | **Paper Trading + Notifications** | 12 (S5+S6) | Paper+Real Trading + Circuit Breaker + НКД + корп. действия + Notifications (Telegram/Email/In-app) + Recovery + Graceful Shutdown. 945 тестов. QA E2E пройден (119/0/3) | ✅ завершён (Sprint_6_Review, 2026-04-24) |
| **M4** | **Production-ready** | 16 (S8) | Coverage ≥ 80%, регрессия, security audit, performance, юзабилити-тест. Все sign-off (ARCH + QA + UX) | ⬜ не начат |

```
Неделя:  2        8        10       16
         │        │        │        │
         ▼        ▼        ▼        ▼
────●────────●────────●────────────●────
    M1       M2       M3           M4
  Каркас  Бэктест  Paper+Bond  Production
  +UX     +CSRF    +CB         Ready
```

---

## 6. УПРАВЛЕНИЕ РИСКАМИ

| # | Риск | Вероятность | Влияние | Митигация |
|---|---|---|---|---|
| R1 | TA-Lib не компилируется на Apple Silicon | Низкая | Высокое | Тест в день 1. Fallback: `pandas-ta` |
| R2 | T-Invest API меняет gRPC-контракт | Средняя | Среднее | Абстрактный BrokerAdapter. Pinning версии SDK |
| R3 | Backtrader несовместим с Python 3.12+ | Низкая | Высокое | Pinning Python 3.11. Fallback: `zipline-reloaded` |
| R4 | Blockly не покрывает все паттерны | Средняя | Среднее | Режим B (ручной ввод) — fallback |
| R5 | AI rate limits задерживают S4 | Средняя | Низкое | Режим B полностью работает без AI |
| R6 | Sandbox пропускает escape | Низкая | Критическое | Security audit в S6+S8. Subprocess + psutil |
| R7 | S7 (Should) не укладывается | Высокая | Низкое | Приоритизирован. Must уже в S5. Остаток → фаза 2 |
| R8 | Уход участника | Средняя | Высокое | 2 backend + 2 frontend = bus factor 2. Документация в ТЗ |
| R9 | **UX-баги обнаружены поздно** | Средняя | Среднее | **UX-дизайнер в каждом спринте + юзабилити-тест в S8** |
| R10 | **Баги копятся к S8** | Высокая | Высокое | **QA встроен в каждый спринт. S8 = регрессия, не первичное тестирование** |

---

## ПРИЛОЖЕНИЕ: СВОДКА ЗАГРУЗКИ УЧАСТНИКОВ ПО СПРИНТАМ (v2)

```
Участник   S1    S2    S3    S4    S5    S6    S7    S8
─────────────────────────────────────────────────────────
ARCH       ██░   ██░   ██░   ██░   ██░   ██░   ██░   ███
BACK1      ██░   ███   ██░   ███   ███   ███   ██░   ██░
BACK2      ███   ███   ███   ███   ███   ███   ██░   ██░
FRONT1     ██░   ███   ███   ███   ███   ██░   ███   ██░
FRONT2     ██░   ██░   ██░   ███   ██░   ███   ███   ██░
UX         ███   ███   ██░   ██░   ██░   ██░   ███   ██░
QA         ██░   ██░   ███   ███   ███   ███   ███   ███
OPS        ███   ░░░   ░░░   ░░░   ░░░   ██░   ██░   ██░
SEC        ███   ██░   ███   ░░░   ███   ██░   ░░░   ███
─────────────────────────────────────────────────────────
███ = высокая   ██░ = средняя   ░░░ = низкая
```

**Сравнение с v1:**

| Участник | v1 (простой) | v2 (простой) | Изменение |
|---|---|---|---|
| AI (убран) | 7 из 8 спринтов | — | Задачи → BACK2 |
| DB (убран) | 5 из 8 спринтов | — | Задачи → BACK2 |
| BACK2 (новый) | — | 0 спринтов | Загружен полностью |
| FRONT2 (новый) | — | 0 спринтов | Загружен равномерно |
| UX (новый) | — | 0 спринтов | Загружен с S1 |
| QA (новый) | — | 0 спринтов | Загружен с S1 |
| OPS | 4 спринта | 4 спринта | Без изменений (специфика роли) |

> **Примечание по OPS:** низкая загрузка в S2–S5 — нормально для DevOps в фазе разработки. В эти периоды OPS выполняет мониторинг CI/CD, помогает с dev-средой, готовит production-конфигурации. При ограниченном бюджете OPS может быть привлечён на part-time (0.5 FTE).

---

*Документ v2.0 подготовлен по результатам PM-ревью. Основание: техническое задание v1.0 от 2026-03-23.*
