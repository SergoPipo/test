## DEV-AUDIT-023 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту

### 1. Что реализовано
- `POST /corporate-actions/detect` теперь под `Depends(require_admin)`: без токена 401, обычный пользователь 403, администратор 200.
- `DetectRequest.tickers: list[Ticker] = Field(max_length=50)`. Тип `Ticker` взят из 065 (`^[A-Z0-9._-]{1,20}$`, регистр приводится к верхнему), а не regex рецепта `^[A-Z0-9]{1,12}$`: так формат тикера в проекте один. Плюс в том, что проходят облигации и валютные пары `_TOM`. Константа `DETECT_MAX_TICKERS`.
- Лимитер: `/api/v1/corporate-actions/detect` отнесён к категории `trading` (60/мин на user_id). Отдельную категорию не заводил: для неё понадобился бы новый ключ в `config.py`/`.env` и правка гайда, а при admin-only хватает существующего порога.
- Джоба планировщика не тронута, сигнатура `service.detect_corporate_actions` не менялась.
- UI: кнопки «Обнаружить» для корпоративных действий во фронте нет (`grep -rni corporate frontend/src` находит только подпись события), так что на фронте менять нечего.

### 2. Файлы
Изменены: `backend/app/corporate_actions/router.py`, `backend/app/middleware/rate_limit.py`, `backend/tests/test_routers/test_corporate_actions_router.py` (существующий тест детекта переведён на admin).
Новый: `backend/tests/test_routers/test_corporate_actions_detect.py`.

### 3. Тесты
RED: `assert 200 == 403` (не-admin) и `AssertionError: assert 'general' == 'trading'`.
GREEN: `test_detect_requires_admin_and_limits_tickers`, `test_detect_rate_limit_category_is_trading`, вместе с router- и rate_limit-тестами 38 passed.
Мутация: `Depends(require_admin)` заменён обратно на `Depends(get_current_user)` → тест падает с `assert 200 == 403`; откат через бэкап, md5 совпал.
Гейты: pytest 4566 passed / 1 skipped / 1 xfailed / 0 failed; ruff 0; mypy Success (192); bandit M0/H0; typecheck 0; lint 0; build ok; vitest не запускал — фронт не менялся, его снимают на уровне пакета. Маркеров `S8R-AUDIT-023` нет.

### 4. Integration points
✅ `router.py:89` `Depends(require_admin)`; роутер подключён в `main.py:442`; `rate_limit.py:93`.

### 5. Контракты
API: новые ответы 403 (не-admin) и 422 (больше 50 тикеров или тикер не по формату). Миграции нет.

### 6. Проблемы / предложения
- ТЗ §7.5 — добавить строку: «`POST /corporate-actions/detect` — только администратор (`require_admin`), ≤ 50 тикеров формата `Ticker`, категория лимитера `trading` (S8R-AUDIT-023)».
- ФТ §6.4 — по желанию: «Ручной запуск обнаружения корпоративных действий доступен только администратору».
- Новая находка (low): `Ticker` пропускает `..`, а тикер подставляется в путь ISS `/iss/securities/{ticker}/dividends.json`. Сейчас это доступно только администратору и ведёт на публичный хост; стоит ли запрещать `..` в `Ticker`, решать оркестратору.
- Самопроверка: п.1, 2, 4 не применимы (нет записи в БД, уведомлений и таймаутов); п.3 — реальные `require_admin` и pydantic-валидация, замокан только сервис, то есть сеть ISS; п.5 — вызывающие: router и scheduler, scheduler не менялся; п.6 — предел размера списка и длины тикера есть.

### 7. Применённые Stack Gotchas
31 — обычный роутер, не mount, поэтому `Depends` работает.

### 8. Новые Stack Gotchas
Нет.

### 9. Плагины
py_compile ок; typecheck (`tsc -b`) ок; context7 не нужен — стандартный `Field(max_length)` pydantic v2; tdd — скилл `mattpocock-skills:tdd`.
