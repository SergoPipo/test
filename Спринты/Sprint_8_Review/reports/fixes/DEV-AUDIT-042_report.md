## DEV-AUDIT-042 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту
### 1. Что реализовано
- AAD: `CryptoService.encrypt/decrypt(..., context=)`, AAD = заголовок + `|<context>`, формат (MAGIC+key_id, IV) не менялся. decrypt: контекст → header-only → легаси.
- Брокер: каждая запись шифруется своим iv с `broker_account:<id>` (`_store_credentials`); новая запись — после flush, в той же транзакции. Все 11 мест расшифровки передают `account_id`; в память `_TokenReader` добавлен id.
- AI: `ai_provider:<id>`. До flush NOT NULL-колонка получает временный шифртекст `ai_provider:user:<uid>`, до commit он заменяется привязанным к id; в БД попадает только последний.
- CLI ротации: перешифровка с контекстом записи.
- Маски: AI — `…abcd`; мультиплексор — `token_fingerprint` (sha256[:16]) вместо `token[:8]`.
- Реестры `_singletons`/`_global_limiters` ключуются отпечатком. При удалении или деактивации счёта (после commit, если токен не держит другая активная запись) лимитер снимается, простаивающий мультиплексор тоже (`release_token`; с подписчиками не трогаем, terminal-пометку не ставим).
- `httpx`/`httpcore` → WARNING в `configure_logging`; `mask_secrets` вычищает `<id>:<secret>` бот-токена из строк событий.
- Бэкапы: каталог 0700 (chmod при старте сервиса, ошибка → warning), снимок/before_restore/восстановленная БД/`.lock` — 0600.
### 2. Файлы
Новый: `tests/unit/test_common/test_secret_masks.py`. Изменены: `app/common/{crypto,logging_config}.py`, `app/broker/{crypto_helpers,service,router}.py`, `app/broker/tinvest/{multiplexer,rate_limiter}.py`, `app/ai/service.py`, `app/backup/service.py`, `app/cli/secrets_rotation.py`, `app/{market_data/service,notification/telegram_webhook,trading/engine,trading/runtime}.py`; тесты `test_ai/test_{router,service}`, `test_broker/test_{account_token_rotation,multiplexer_reconnect_queue,multiplexer_singleton}`, `test_cli_rotate_key` (ключи-отпечатки, `account_id`, новая маска).
### 3. Тесты
RED: 13 failed — `TypeError: CryptoService.encrypt() got an unexpected keyword argument 'context'`, `assert 'sk-a...WXYZ' == '…WXYZ'`, `AssertionError: ключ реестра — открытый токен`, `assert (16877 & 63) == 0`, `assert 0 >= 30` (httpx). GREEN 14/14. Мутация: в `encrypt_with_iv` AAD → `self._header` → 4 failed, `Failed: DID NOT RAISE <class 'cryptography.exceptions.InvalidTag'>`; откат, md5 совпал. Гейты: pytest 4590 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (193); bandit 0 issues; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета.
### 4. Integration points
✅ `release_token` → `broker/service.py:865`; `_store_credentials` → `:426,:478`; `_store_config_key`/`_decrypt_config_key` → `ai/service.py`; `token_fingerprint` → multiplexer, rate_limiter.
### 5. Контракты
API/схемы не менялись (меняется только значение `masked_api_key`). Миграций нет.
### 6. Проблемы / правки документов / находки
- ТЗ §7.2: «Новые записи: AAD = заголовок + `|broker_account:<id>` / `|ai_provider:<id>`; decrypt — контекст → header-only → легаси (только для записей до 042); переставленный шифртекст не читается. Откат кода ниже 042 → повторный ввод ключей».
- ТЗ §7.7: «`httpx`/`httpcore` — WARNING; бот-токен вычищается из строк событий; токен T-Invest в логах — `token_fingerprint`; маска AI-ключа — `…abcd`».
- Гайд, раздел бэкапов: «каталог 0700, файлы 0600; после restore рабочая БД — 0600».
- Находка: записи с header-only AAD, уже помеченные новым key_id, CLI не перепривязывает (`already_current`).
- Самопроверка: 1 — ключ привязывается в транзакции записи, очистка реестров только после commit; 2 — уведомлений нет; 3 — тесты проходят через `create_account`/`delete_account`/`update_account`/`AIService`/`create_backup`; 4 — таймаутов нет; 5 — все вызывающие decrypt получили `account_id`; 6 — н/п.
### 7. Применённые Stack Gotchas
19 (Online Backup не тронут), 37 (токен читается до commit), 67 (маскирование в процессоре).
### 8. Новые Stack Gotchas
Кандидат: проверка `X not in registry` после смены схемы ключей проходит всегда, и тест молча перестаёт проверять (так случилось в 3 тестах 062/061). То же с `getEffectiveLevel()` логгера при root=WARNING: смотреть `logger.level`.
### 9. Плагины
py_compile после каждой правки; tdd (скилл); context7 не нужен (`AESGCM`-AAD — стандартный API); typecheck/lint/build — как гейт.

---
## DEV-AUDIT-042 — правки по код-ревью оркестратора (р.2)
Статус: ✅ готово к коммиту
1. `scripts/diag_sandbox_orders.py`: decrypt с `account_id`, печать — `token_fingerprint`. AST-гард по app/ и scripts/: helper'ы без `account_id`, `.encrypt/.decrypt` без `context`, срезы `api_key[:N]` — пусто.
2. `scrub_secret_text` (`\d+:[A-Za-z0-9_-]{30,}` + `api.telegram.org/bot…`) работает на итоговой строке: structlog — `_ScrubbingRenderer` поверх ConsoleRenderer (repr исключения в поле, вложенные структуры, traceback); stdlib — фабрика `LogRecord` (msg, args с сохранением структуры, `exc_text`). Вместо фильтра на хендлерах выбрана фабрика: она покрывает и хендлеры, добавленные позже, и `lastResort`. Прежняя маска в `mask_secrets` снята.
3. Каталог бэкапов: 0700 (mkdir + chmod) только для созданного сервисом; у существующего каталога права не меняются, при открытых group/other-битах — warning `backup_dir_permissions_open`.
4. `_release_token_state`: лимитер не трогается (комментарий: общий бюджет 300 req/min, ключ — отпечаток); снимается только простаивающий мультиплексор.
5. `_create_private_file` (`O_CREAT|O_EXCL`, 0600) до `sqlite3.connect`: снимок, restore_tmp, before_restore; для pg_dump — `_create_postgres_dump` (имя под локом; при сбое файл удаляется); `.lock` — 0600.
6. CLI: запись на новом ключе без привязки (`CryptoService.is_bound` / `broker_credentials_bound` = False) перешифровывается с контекстом («rebound»). Новая команда `rebind-encrypted-secrets` работает текущим ENCRYPTION_KEY, идемпотентна: если менять нечего, не делает ни снимка, ни записи.
7. `account_id` в `encrypt_broker_credentials/encrypt_broker_key` — обязательный keyword-only (у decrypt-helper'ов параметр остался опциональным).
8. Память `_TokenReader` удалена, вместо класса — функция `_read_token`; комментарии исправлены.
9. AI create: плейсхолдер `b""` → flush → `_store_config_key`; контекст `ai_provider:user:` удалён.
10. `cast(bytes, …)` в telegram_webhook.

Тесты: RED — 12 failed + 3 (CLI). Примеры: `assert 'AAHfakeBotT...0123456789-x' not in '...'`, `assert 448 == 493`, `файл открыт до chmod (mode=None)`, `'ai_provider:user:1' != 'ai_provider:1'`, `argument command: invalid choice: 'rebind-encrypted-secrets'`. GREEN: 25 + 49. Мутации: (п.2) убран `_install_record_scrubber()` → `assert 'AAHfakeBotT…' not in 'telegram.ext ERROR The token…'`; рендерер без scrub → токен в `error=RuntimeError('…bot123456789:AAH…')`; (п.5) убран `_create_private_file(dst)` → `файл открыт до chmod (mode=420)`; откат, md5 совпал. Фикстуры 5 тестовых файлов переведены на формат до 042 (`get_crypto_service().encrypt`). В тестах логов `logger.disabled=False`: alembic `fileConfig` в тестах миграций выключает существующие логгеры.
Гейты: pytest 4604 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (193); bandit 0; typecheck 0; lint 0; build ok; vitest — фронт не менялся.

Гайд (§7, после обновления): «Остановить backend → `docker compose run --rm backend python -m app.cli rebind-encrypted-secrets` (локально: `cd backend && python -m app.cli rebind-encrypted-secrets --server-stopped`) — привязывает ключи брокера и AI, сохранённые до S8R-AUDIT-042, к их записям; перед записью делает снимок в BACKUP_DIR; повтор безопасен („nothing to rebind“). ENCRYPTION_KEY не меняется. Откат кода ниже 042 после команды требует повторного ввода ключей».

---
## DEV-AUDIT-042 — итерация 3 код-ревью
Статус: ✅ готово к коммиту
1. `rebind-encrypted-secrets` по завершении печатает WARNING: снимок перед rebind и старые снимки содержат непривязанные шифртексты; полностью закрывает только `rotate-encryption-key` после rebind либо перенос старых снимков в офлайн. Fallback не выключался.
2. `_tighten_own_files` при создании `BackupService` (старт приложения и любая команда CLI бэкапа) ставит 0600 своим файлам: `backup_*.sqlite`, `backup_*.dump`, `.lock`, `<db>.before_restore_*`. Только обычные файлы своего uid, не симлинки. Каталог и чужие файлы не трогаются.
3. `_restore_sqlite`: `before` при сбое удаляется, только если его создал этот вызов (`before_created`).
4+6+7. Фабрика LogRecord: проверка по `getMessage()` и по traceback, отформатированному один раз в `exc_text`. Предфильтр — один regex `search`. Если секрет найден: `msg` = замаскированный текст, `args = ()`; если нет — запись не меняется. Ошибка `getMessage` (кривые args) → запись как есть.
5. Перед `os.replace` права старой рабочей БД переносятся на восстановленный файл.
8. Regex: `(?<![A-Za-z0-9])\d{5,12}:[A-Za-z0-9_-]{35}(?![A-Za-z0-9_-])` + URL `api.telegram.org/(file/)bot…`.
9. Идемпотентность — по маркеру в цепочке `__wrapped__`; autouse-фикстура восстанавливает фабрику LogRecord и уровни httpx/httpcore.
10. Общий helper `_active_tokens(exclude_account_id=, exclude_user_id=)`; комментарий про ключи реестров исправлен.

RED: 13 failed — non-str/split → токен в выводе; `'sha***' == 'sha256:…'`; `args is args`; `assert 2 == 1` (фабрика); `420 == 384`; `384 == 416`; `FileNotFoundError …before_restore_foreign`; нет WARNING rebind. GREEN: 40 + 50.
Мутации (откат, md5 совпал): (4) проверка по `record.msg` вместо `getMessage()` → 3 failed, токен в выводе `request https://api.telegram.org/bot123456789:AAH…`; (8) прежний regex `[0-9]+:[A-Za-z0-9_-]{30,}` → 5 failed (`'sha***' == 'sha256:…'`, `'***' == '1234567:550e…'`); (9) проверка маркера только у верхней фабрики → `наша фабрика в цепочке — не оборачиваем`.
Гейты: pytest 4619 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (193); bandit 0; typecheck 0; lint 0; build ok; vitest — фронт не менялся.

Гайд (§7, к шагу rebind): «После `rebind-encrypted-secrets` снимок перед ним и все более старые снимки в BACKUP_DIR содержат ключи без привязки к записи; восстановление такого снимка возвращает записи, которые приложение читает через совместимый fallback. Чтобы закрыть это полностью, после rebind выполните ротацию ключа `rotate-encryption-key` (старые снимки после этого читаются только старым ключом — храните его вместе с ними или удалите снимки), либо перенесите старые снимки в офлайн-хранилище. При старте сервис приводит права своих снимков к 0600; права каталога бэкапов не меняет — при открытых правах в лог пишется warning `backup_dir_permissions_open`, выполните `chmod 700 <BACKUP_DIR>`. После restore восстановленная БД получает права прежней рабочей БД».

---
## DEV-AUDIT-042 — итерация 4 код-ревью
Статус: ✅ готово к коммиту
1. Фабрика LogRecord: `msg` и `args` маскируются поэлементно (tuple/Mapping, `str()` не-примитивов; структура, длина и идентичность без секрета сохраняются). Затем повторная проверка `getMessage()`: схлопывание `msg=…, args=()` — только если секрет остался (токен разрезан между msg и аргументом).
2. Процессор `scrub_event_values` до рендерера: рекурсия по dict/list/tuple/set, `str()` не-примитивов, `exc_info` не трогается. Обёртка рендерера оставлена. URL `/bot<id>:<…>` маскируется на любом хосте; для api.telegram.org — любой хвост после `bot`.
3. Если `getMessage` бросает: `msg`, `args` и traceback уже замаскированы, схлопывания нет.
4. В `_own_files` добавлен `<db>.restore_tmp_*`.
5. `_tighten_own_files`: `os.open(O_RDONLY|O_NOFOLLOW|O_NONBLOCK)` + `fstat` (обычный файл, свой uid) + `fchmod`; ошибки — пропуск с debug.
6. `exc_text` записывается только при найденном секрете.
7. Двойной `getMessage` — обоснование в докстринге.
8. httpx/httpcore → WARNING только при `level == NOTSET`.
9. Докстринг: оговорка про `logging.makeLogRecord`.
10. Restore переносит группу: `os.chown(tmp, -1, gid)`, best-effort, при ошибке — warning.

RED: 8 failed — `assert 30 == 10` (httpx), токен в access-строке uvicorn, токен в выводе handleError, `exc_text … is None`, токен в event dict до рендерера и в цветном выводе, `restore_tmp 420 == 384`, `chown` не вызван. GREEN: 48/48.
Мутация п.1 (откат, md5 совпал): убрано поэлементное маскирование `args` → `ValueError: not enough values to unpack (expected 5, got 0)` в AccessFormatter.
Гейты: pytest 4627 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (193); bandit 0; typecheck 0; lint 0; build ok; vitest — фронт не менялся.
