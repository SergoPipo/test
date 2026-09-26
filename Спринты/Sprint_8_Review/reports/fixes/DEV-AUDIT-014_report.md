## DEV-AUDIT-014 отчёт — S8R fixes, MEDIUM
Статус: ✅ готово к коммиту (worktree B, 112da39, не закоммичено)
### 1. Что реализовано
- Таблица `ai_usage_daily(date PK, prompt_tokens, completion_tokens)`: одна строка на UTC-сутки на инстанс. Суточный потолок считается по строке за сегодня, месячный — по сумме строк месяца. Сброс происходит по дате ключа, отдельная джоба не нужна.
- Настройки `AI_GLOBAL_DAILY_TOKEN_LIMIT=1_000_000` и `AI_GLOBAL_MONTHLY_TOKEN_LIMIT=20_000_000` (0 = выкл.). Обоснование: 1 млн ≈ 100–200 запросов чата, на Sonnet это ≈ $5–15 в сутки; месячный расход не больше ~$60–300.
- `check_budget`: per-user лимиты не менялись. Общий потолок действует только когда запрос идёт на серверный ключ: нет своего конфига, нет `provider_id`, `AI_API_KEY` задан. Добавлены поля `global_*`.
- `increment_usage`: при fallback пишет атомарный upsert `used = used + :n`. Per-user инкремент тоже переведён на атомарный `UPDATE` вместо ORM read-modify-write.
- `/chat`, `/chat/stream`, `/explain`: отказ по общему потолку — 429 с понятным текстом, per-user — прежний 403 (`_ensure_budget`). `/explain` теперь учитывает токены так же, как `/chat`.
- `GET /ai/status`: для серверного ключа возвращает только `available=true`, provider и model = null.
- Контракт `/settings/ai/usage` (находка 004): тип `UsageStats` на фронте приведён к `AIUsageResponse`.
### 2. Файлы
Новые: `backend/alembic/versions/1d92db59f28d_ai_usage_daily.py`, `backend/tests/unit/test_ai/test_budget_ceiling.py`.
Изменённые: `app/ai/{service,chat_router,router}.py`, `app/common/models.py`, `app/config.py`, `tests/test_routers/test_ai_router.py` (status больше не раскрывает provider), `tests/unit/test_migration.py`, `frontend/src/api/aiSettingsApi.ts`, `AISettingsPage.test.tsx` (обновлён мок).
### 3. Тесты
- RED: сначала `AttributeError: Settings(...) has no attribute 'AI_GLOBAL_DAILY_TOKEN_LIMIT'`. После добавления полей настроек: `assert [200, 200, 200, 200] == [200, 200, 200, 429]`.
- GREEN: `test_budget_ceiling.py` 10/10 и `test_ai_usage_daily_round_trip`.
- Мутация «return перед upsert при fallback» → 6 тестов красные, `assert [200,200,200,200] == [...429]`. Откат через bak, md5 совпал. Дополнительно проверено: ORM read-modify-write валит тест на гонку.
- Гейты:
  - pytest: 3589 passed / 6 xfailed / 0 failed
  - ruff 0; mypy Success (188); bandit M0/H0
  - typecheck 0; lint 0; build ok; vitest 965 passed
### 4. Integration points
✅ `chat_router.py:274,389,492` (`_ensure_budget`), `:324,445,520` (`increment_usage`); `service.py:145,217`; `router.py:218`.
### 5. Контракты
- Миграция `1d92db59f28d` (после `6128b9c52d8a`): `heads` = 1; round-trip на чистой БД в scratch (upgrade → downgrade -1 → upgrade) прошёл.
- 429 `{"detail": "Исчерпан общий лимит AI на сервере…"}`.
- `/ai/status`: provider и model = null при серверном ключе.
### 6. Проблемы / правки документов
- Гайд §7: заменить `6128b9c52d8a` на `1d92db59f28d`. Добавить в §3/.env: «`AI_GLOBAL_DAILY_TOKEN_LIMIT=1000000`, `AI_GLOBAL_MONTHLY_TOKEN_LIMIT=20000000` — потолок токенов серверного `AI_API_KEY` на инстанс (UTC-сутки/месяц), 0 = выкл.»
- ФТ §8.3, в «Rate limits и бюджет» добавить: «Расход серверного ключа (.env) ограничен общим потолком инстанса в сутки/месяц; при исчерпании — 429 "Исчерпан общий лимит AI…"; `/ai/status` не раскрывает провайдера серверного ключа.» ТЗ §5.10.4: то же плюс таблица `ai_usage_daily`.
- Находки:
  - Потолок мягкий: проверка идёт до запроса, поэтому параллельные запросы могут превысить его на размер одного запроса каждый.
  - Нет квоты на пользователя внутри серверного ключа: один пользователь может исчерпать сутки для всех.
  - `AI_DAILY_LIMIT/AI_MONTHLY_LIMIT` в конфиге мёртвые. Джоб `reset_ai_*_usage` из ТЗ нет.
- Самопроверка:
  1) если commit инкремента упадёт, недосчитан будет один запрос, статусов и листенеров это не касается;
  2) уведомлений нет;
  3) реальный путь через HTTP, подменены только `ProviderFactory` и стратегия;
  4) таймаутов нет;
  5) все вызывающие (3+3) проверены;
  6) новых входных данных от клиента нет.
### 7. Gotchas
48 (файл БД + NullPool), 53 (случайный id, проверен), 12 (литеральные server_default), 79 (не касается: таблица новая, batch не используется).
### 8. Новые gotchas
Кандидат: атрибут `date: Mapped[date]` в теле класса затеняет тип в аннотации. Обошёл через `usage_date` с `mapped_column("date")`.
### 9. Плагины
py_compile по всем .py; typecheck (`tsc -b`); context7 (SQLAlchemy sqlite upsert); скилл tdd.
