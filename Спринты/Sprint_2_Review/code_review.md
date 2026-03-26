# Ревью кода — после Sprint 1 + Sprint 2

> Чеклист проверки реализованного кода.
> Статус: ✅ Проведено 2026-03-26

---

## 1. Архитектура и модули

- [x] **Разделение на слои:** ✅ service.py / models.py / router.py / React components — корректно разделены
- [x] **Когезия модулей:** ✅ каждый пакет отвечает за одну зону, «божественных» модулей нет
- [x] **Нет циклических зависимостей:** ✅ граф импортов ацикличен; lazy imports в `market_data/service.py` (строки 212, 230, 238) — допустимы
- [ ] **Конфигурация вынесена:** ⚠️ Два хардкода: CORS origin `main.py:46`, API base URL `frontend/src/api/client.ts:5` — вынести в .env
- [x] **Соответствие структуре из CLAUDE.md:** ✅ файловая структура совпадает; нереализованные модули (strategy, trading, ai и др.) — заглушки по плану

## 2. Backend — API-слой

- [x] **Эндпоинты соответствуют ТЗ:** ✅ URL, HTTP-методы (POST 201, GET 200, DELETE 204), JSON-схемы корректны
- [x] **Валидация входных данных:** ✅ Pydantic v2 с `Field(min_length, max_length, pattern)` на всех схемах
- [ ] **Ошибки формируются явно:** ⚠️ auth/router.py (строки 30, 41-43, 46, 55, 67, 88) использует HTTPException вместо кастомных исключений; нет AccountLockedError для 423
- [x] **CORS настроен корректно:** ✅ `allow_origins=["http://localhost:5173"]` — конкретный origin, не wildcard (но хардкод — см. п.1)
- [x] **Версионирование API:** ✅ все endpoints под `/api/v1/`

## 3. Backend — Бизнес-логика

- [x] **Логика в сервисах:** ✅ все роутеры тонкие, делегируют в service.py
- [ ] **Функции компактны и читаемы:** ⚠️ `market_data/service.py` — 5 методов превышают 50 строк: `get_candles` (51), `_fetch_via_broker` (53), `_save_to_cache` (54), `_fetch_via_iss` (57), `_validate_candles` (65)
- [x] **Dependency Injection:** ✅ `Depends(get_db)`, `Depends(get_current_user)` — корректно

## 4. Backend — Работа с базой данных

- [x] **ORM-запросы:** ✅ 100% SQLAlchemy ORM; 2 safe raw SQL (WAL pragma в database.py:39, health check в main.py:69)
- [x] **Миграции согласованы:** ✅ единственная миграция `3d3e4e3036a6` полностью соответствует моделям
- [x] **Индексы на месте:** ✅ 17 индексов на критических запросах (ohlcv_lookup, broker_user, notif_user_unread и др.)
- [x] **Async I/O:** ✅ все запросы через AsyncSession, async/await

## 5. Backend — Ошибки и логирование

- [ ] **Middleware перехватывает исключения:** ⚠️ Обработчики для 5 кастомных исключений есть, но нет generic Exception handler — необработанные ошибки (SQLAlchemy и др.) могут вернуть stack trace
- [x] **Структурированные логи:** ✅ structlog с контекстными полями, INFO/WARNING уровни
- [x] **Нет логирования секретов:** ✅ API-ключи, пароли, токены не логируются

## 6. Финансовые данные ⚠️

- [x] **Decimal для денег и цен:** ✅ `Numeric(18,8)` для цен, `Numeric(18,2)` для денег во всех моделях; парсинг через `Decimal(str(val))`
- [ ] **Корректная сериализация:** ⚠️ КРИТИЧНО — `CandleResponse` в `schemas.py:20-23` объявляет цены как `float`, теряя точность Decimal при сериализации в JSON
- [x] **Форматирование ru-RU:** ✅ `formatters.ts` — `toLocaleString('ru-RU')`, `1 234 567,89 ₽`, `ДД.ММ.ГГГГ`
- [ ] **Часовые пояса:** ⚠️ UTC в БД ✅, MSK в router ✅, но: `market_data/service.py:64-67` стрипает timezone info; `moex_iss/parser.py:35,63` создаёт naive datetime без TZ; `tinvest/mapper.py:80-84` — непоследовательная обработка

## 7. Frontend — Структура и компоненты

- [x] **Разделение ответственности:** ✅ компоненты делегируют в stores/api; мелкое замечание: `BrokerSettingsPage.tsx:29` и `StatusFooter.tsx:33` вызывают API напрямую, минуя store
- [x] **Состояние централизовано:** ✅ Zustand stores (auth, marketData, settings, ui)
- [x] **Формы:** ✅ клиентская валидация + обработка серверных ошибок (включая 423 lockout)
- [ ] **Cleanup:** ⚠️ chart.remove() ✅; ResizeObserver ✅; но `ChartPage.tsx:31` — eslint-disable для exhaustive-deps; `Header.tsx` — нет cleanup для debounce timeout
- [x] **Соответствие ui_spec:** ✅ (UI-спецификация в Sprint_2/ui_spec_s2.md)
- [x] **Тексты на русском:** ✅ 100% русский текст в интерфейсе

## 8. Безопасность

**Аутентификация и авторизация:**
- [x] Защищённые endpoints проверяют JWT ✅ через `Depends(get_current_user)`
- [x] Публичные endpoints (health, market-status, calendar, setup-status) — явно без auth ✅
- [x] JWT: access (30 мин) + refresh (7 дней), Argon2id для паролей ✅ (уникальный JTI для отзыва)
- [x] Брутфорс-защита: блокировка после 5 попыток на 15 мин ✅

**Шифрование:**
- [ ] API-ключи брокера зашифрованы AES-256-GCM в БД — ⛔ КРИТИЧНО: `broker/service.py:36-40` сохраняет ключи БЕЗ шифрования (комментарий «Временно»). CryptoService и crypto_helpers.py готовы, но НЕ интегрированы
- [x] API-ключи **не возвращаются** в API-ответах ✅ (schemas.py явно исключает)
- [x] PasswordInput на frontend для полей с ключами ✅ (Mantine PasswordInput)

**Секреты:**
- [x] `.env` в `.gitignore` ✅, `.env.example` с плейсхолдерами
- [x] Dev-ключи вызывают предупреждения в production ✅ (`config.py:22-35` — model_validator)

## 9. Качество кода и инфраструктура

- [x] **Стиль кода:** ✅ ruff (py311, line 100) + eslint v9 (flat config) — оба в CI
- [x] **Типизация:** ✅ TypeScript `strict: true` + 4 доп. проверки; Python type hints + mypy ≥1.9 в CI
- [x] **Тесты:** ✅ 21 тест-файл backend (pytest-asyncio), 11 тест-файлов frontend (vitest)
- [ ] **Покрытие:** ⚠️ Не покрыты тестами: strategy, backtest, trading, scheduler, sandbox, AI, notification, circuit_breaker, corporate_actions; frontend: CandlestickChart, API layer, Header search. Coverage не настроен в CI
- [ ] **Зависимости:** ⚠️ Backend: `>=` без верхних границ; `httpx>=0.27` дублируется; `tinkoff-investments` не в pyproject.toml (ручная установка)
- [x] **Скрипты:** ✅ `install.sh` (проверки Python 3.11+, Node 18+, pnpm), `start.sh` (оба сервиса + trap SIGINT)
- [x] **CI/CD:** ✅ GitHub Actions: lint → typecheck → tests для обоих стеков

## 10. Производительность

- [x] **Кеширование данных:** ✅ DB-кеш с gap detection, fallback broker→ISS, source tracking, conflict resolution
- [x] **Размер ответов API:** ✅ `MAX_REQUEST_SPAN = 365 дней` с logger.warning при превышении
- [x] **Frontend chart:** ✅ chart.remove(), resizeObserver.disconnect(), unsubscribeCrosshairMove(), null refs
- [x] **Debounce на поиске:** ✅ 300ms debounce, min 2 символа, кеш результатов

---

## Автоматические проверки

```bash
# Backend: тесты
cd backend && source .venv/bin/activate && pytest tests/ -v --tb=short

# Frontend: тесты
cd frontend && pnpm test

# Проверка финансовых типов (float в финансовых модулях)
grep -rn "float" app/ --include="*.py" | grep -v "test\|rate_limiter\|__pycache__"

# Проверка секретов
grep -r "SECRET_KEY\|ENCRYPTION_KEY\|api_key" --include="*.py" app/ | grep -v "config\|test\|schema\|\.pyc"
```

## Результат ревью

| Раздел | Статус | Замечания |
|--------|--------|-----------|
| 1. Архитектура | ✅ | 1 замечание: хардкод CORS + API URL |
| 2. API-слой | ⚠️ | auth/router.py: HTTPException вместо кастомных; нет AccountLockedError |
| 3. Бизнес-логика | ⚠️ | market_data/service.py: 5 методов > 50 строк |
| 4. База данных | ✅ | Без замечаний |
| 5. Ошибки и логи | ⚠️ | Нет generic Exception handler — возможна утечка stack trace |
| 6. Финансовые данные | ⛔ | CandleResponse: float вместо Decimal; timezone inconsistency |
| 7. Frontend | ⚠️ | 2 прямых вызова API минуя store; eslint-disable в ChartPage |
| 8. Безопасность | ⛔ | API-ключи брокера хранятся БЕЗ шифрования (crypto готов, не интегрирован) |
| 9. Качество кода | ⚠️ | Coverage не настроен; зависимости без верхних границ; модули S3-S8 не покрыты |
| 10. Производительность | ✅ | Без замечаний |

**Легенда:** ✅ OK · ⚠️ Есть замечания · ⛔ Критично
