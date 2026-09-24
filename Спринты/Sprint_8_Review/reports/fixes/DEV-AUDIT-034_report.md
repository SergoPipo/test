## DEV-AUDIT-034 отчёт — S8R fixes, HIGH
Статус: ✅ готово к коммиту (worktree `wt-s8r-fixes-b`, база 47bf073, не закоммичено)

### 1. Что реализовано
1. `config.py`: `_weak_secret_reason()` — единый гейт `SECRET_KEY`/`ENCRYPTION_KEY` при `DEBUG=false`: префикс `dev-` → маркер `change-me/change_me/changeme` без учёта регистра (оба плейсхолдера `.env.example` по `git log -S`) → ≥ 32 байт UTF-8 → ≥ 8 различных символов. Пороги импортированы из `CryptoService` (одна точка истины).
2. `check_production_secrets` применяет его к обоим полям; сообщение называет поле, причину, команду генерации.
3. `main.py` lifespan: при `DEBUG=false` первым действием `get_crypto_service()` (strict) до `init_db()` — слабый мастер-ключ роняет старт, а не первый брокер/AI-запрос.
4. `check_production_env.sh`: те же четыре правила на POSIX sh (`wc -c`, `fold|sort -u`, `tr`); кириллический ключ считается в байтах как в Python.
5. Dev-дефолты при `DEBUG=true` не тронуты (отдельный тест).
6. Ключи CI/nightly/E2E/compose (33–43 байта) проходят — покрыто тестами, править не пришлось. `.env.example` не редактировался.

### 2. Файлы
Изменённые: `backend/app/config.py`, `backend/app/main.py`, `scripts/check_production_env.sh`, `backend/tests/unit/test_config.py` (+13 тестов, sync sh через subprocess; константы `"a"*32` и `SECRET_KEY="test"` заменены — новые правила их не пропускают), `backend/tests/unit/test_audit_s8r_auth_setup.py` (xfail снят, докстринг обновлён, `match="SECRET_KEY"`, валидный `ENCRYPTION_KEY` вместо `"x"*40`). Новых/удалённых нет.

### 3. Тесты
RED: `Failed: DID NOT RAISE <class 'RuntimeError'>` (18 failed / 10 passed); lifespan-тест: `RuntimeError: AsyncSessionLocal is None после init_db()` (main.py:88). GREEN: 39 passed. Мутация `reason = _weak_secret_reason(...)` → `reason = None` → 13 failed `DID NOT RAISE <class 'RuntimeError'>`; откачена. Гейты: pytest 2692 passed / 21 xfailed / 0 failed; ruff 0; mypy Success (178); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 926 passed / 2 expected fail.

### 4. Integration points
✅ `_weak_secret_reason` → `app/config.py:182`; ✅ `get_crypto_service()` → `app/main.py:88` в `lifespan` (`lifespan=lifespan`, :320); ✅ sh → `docker-compose.yml:55`. Маркеров `S8R-AUDIT-034` нет.

### 5. Контракты
API/схемы/миграции не менялись.

### 6. Правки документов / находки
- Гайд §3.2, `SECRET_KEY`: «≥ 32 байт, ≥ 8 различных символов, без `dev-` и `change-me`/`CHANGE_ME` — плейсхолдер шаблона отбраковывают preflight и config-валидатор»; `ENCRYPTION_KEY`: «проверяется на старте (lifespan)».
- Гайд §9.1: строка preflight — причина «`dev-*`, плейсхолдер `change-me`, < 32 байт или < 8 различных символов»; строка `master_key too short` — «при старте контейнера, healthcheck не поднимается»; новая строка «`RuntimeError: SECRET_KEY is a placeholder copied from .env.example with DEBUG=False`» → см. §3.2.
- ТЗ §7.8: вместо `warnings.warn`/префикса — «при `DEBUG=False` старт падает `RuntimeError`, если ключ начинается с `dev-`, содержит `change-me` (любой регистр), короче 32 байт или < 8 различных символов; `ENCRYPTION_KEY` дополнительно — в lifespan до `yield`».
- Расхождение: ТЗ §7.3 требует 64 символа для JWT-ключа, карточка/гайд — 32; реализовано 32 по рецепту. Решение заказчика: порог 64 или правка ТЗ.
- Находка: `test_users_cli.py` стартует CLI без ключей — падает на импорте config, тест проходит вакуумно.
- Ограничение sh: энтропия по байтам (`fold -w1`); для `token_urlsafe` паритет с Python.

### 7. Применённые Stack Gotchas
30 (module-level импорт `get_crypto_service` — патчится в тесте), 50 (прогоны из `backend` worktree), 60 (`tsc -b`), 41 — контекст.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
pyright недоступен → `py_compile` OK; `pnpm typecheck`; context7 не требовался (новых API нет); `mattpocock-skills:tdd` — RED→GREEN→мутация.
