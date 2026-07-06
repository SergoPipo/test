# TDD-задачи P0 — критические (блокеры сдачи)

Первый блок работ по итогам код-ревью. **7 различных критических проблем** (C1–C7), сгруппированы в 4 независимые ветки. Каждая задача выполняется **test-first** (Red → Green → Refactor) — это обязательное требование проекта для `trading`/`circuit_breaker`/`sandbox`/`broker` и здравый смысл для остальных: тест обязан **упасть на текущем коде** до фикса и **позеленеть** после.

> Полные описания и трассы — в [code_review_full_report.md](code_review_full_report.md), раздел 3. Статусы и остальные приоритеты — в [backlog_fixes.md](backlog_fixes.md).

## Общие правила (для всех задач ниже)

- **Обязательное чтение перед кодом:** `Develop/CLAUDE.md`, `Develop/stack_gotchas/INDEX.md` (по совпавшему симптому — конкретный `gotcha-NN`). Релевантно здесь: naive-UTC/MSK, Decimal-как-строка, `MissingGreenlet` (ленивые связи в async), паттерн `AdminAuthASGIMiddleware` (Gotcha 31).
- **Проверка типов после каждого Edit:** `.py` → pyright-lsp (fallback `python -m py_compile`); границы модулей — не тянуть чужие модели в роутер.
- **DoD каждой задачи:** Red-тест написан и падал → фикс → тест зелёный → `pytest --cov-fail-under=80` зелёный → `bandit`/`safety` без новых Medium+ (для security) → существующие тесты модуля зелёные → запись в `changelog.md`.
- **Отчёт DEV** — по формату из `Спринты/prompt_template.md` (что реализовано / файлы / тесты / integration points / проблемы / gotchas).

---

## Ветка `fix/security-config` — C3, C4, C5

**Роль:** Backend/DevSecOps. Файлы: `app/config.py`, `app/auth/router.py`, `backend/assets/telegram_bot_setup.md`, CI/pre-commit.
**Предпроверка:** `pytest tests/ -q` зелёный (baseline); есть доступ к `.env`/окружению; есть права на настройки бота (для ротации C5).

### C3 — Дефолтные `SECRET_KEY`/`ENCRYPTION_KEY` не должны пускать production
**Файл:** `app/config.py:13,78` · подтверждено.
**Причина:** валидатор `@model_validator(mode="after")` на дефолтные ключи вызывает `warnings.warn`, а не блокирует старт.
- **🔴 Red:** тест `test_config_production_rejects_default_keys` — инстанцировать `Settings(ENVIRONMENT="production", SECRET_KEY="dev-secret-key-change-in-production", ENCRYPTION_KEY="<любой валидный>")` → ожидать `ValueError` (или `pytest.raises`). Второй кейс — дефолтный `ENCRYPTION_KEY`. Третий — dev-окружение с дефолтами → исключения НЕТ (обратная совместимость). Все три сейчас проваливаются (исключения нет).
- **🟢 Green:** в валидаторе при `self.ENVIRONMENT == "production"` и совпадении с дефолтом — `raise ValueError(...)`; в dev — оставить `warnings.warn`.
- **♻️ Refactor:** вынести список «запрещённых в prod дефолтов» в константу; добавить проверку минимальной длины `ENCRYPTION_KEY` (32 байта).
- **DoD:** тест зелёный; приложение с дефолтными ключами и `ENVIRONMENT=production` не стартует; deployment_guide.md обновлён, если менялся контракт запуска.

### C4 — Cookie `access_token`/`csrf_token` с `secure=False`
**Файл:** `app/auth/router.py:53` · подтверждено дважды.
**Причина:** `secure=False` захардкожен.
- **🔴 Red:** тест логина через TestClient при `ENVIRONMENT=production` → в ответе `Set-Cookie` содержит атрибут `Secure` и корректный `SameSite`. Падает сейчас.
- **🟢 Green:** вычислять `secure` из окружения (`settings.ENVIRONMENT == "production"` или схема https); применить ко всем `set_cookie` (access и csrf).
- **♻️ Refactor:** единый хелпер `_set_auth_cookie(...)`, чтобы флаги задавались в одном месте.
- **DoD:** тест зелёный; в dev cookie по-прежнему работают по http (не ломаем локалку).

### C5 — Утёкший `TELEGRAM_WEBHOOK_SECRET` в git *(частично вне кода)*
**Файл:** `backend/assets/telegram_bot_setup.md:56` · подтверждено (файл отслеживается git, значение реальное).
**Действия (по порядку):**
1. **Ротировать** секрет (перевыпустить webhook secret у бота, обновить в инфраструктуре/`.env`) — до любых git-операций, т.к. старое значение уже скомпрометировано.
2. Заменить значение в `.md` плейсхолдером `<ваш_webhook_secret>`.
3. Вычистить из истории: `git filter-repo --path backend/assets/telegram_bot_setup.md --invert-paths` (или `--replace-text`), затем форс-пуш согласованно с командой.
4. **Предохранитель:** добавить `gitleaks`/`detect-secrets` в pre-commit и CI-шаг secret-scan.
- **DoD:** `git grep -iE '90f0fa|<паттерны секретов>'` по отслеживаемым файлам пусто; `git log -p -- backend/assets/*.md` не содержит реального секрета; CI secret-scan зелёный. *(Тест здесь — CI-проверка, не unit.)*

---

## Ветка `fix/telegram-webhook-auth` — C1

**Роль:** Backend (notification/security). Файлы: `app/notification/router.py`, `app/notification/telegram_webhook.py`, `app/config.py`.
**Предпроверка:** baseline зелёный; тесты notification изолированы (см. записи об изоляции notification-тестов в acceptance-чеклисте).

### C1 — Telegram-webhook fail-open → неаутентифицированное закрытие чужих позиций
**Файл:** `app/notification/router.py:428` (+ `config.py:23`, `telegram_webhook.py`) · подтверждено.
**Причина:** пустой `TELEGRAM_WEBHOOK_SECRET` (дефолт `''`) → `secret_header('') != webhook_secret('')` == False → `process_update` вызывается без аутентификации; авторизация по `chat_id` из тела (управляем атакующим).
- **🔴 Red:** три теста.
  1. `test_webhook_rejects_without_secret` — при заданном секрете `POST /api/v1/notifications/telegram/webhook` без заголовка → **403**, `process_update` (мок) не вызван.
  2. `test_webhook_fails_closed_on_empty_secret` — при `TELEGRAM_BOT_TOKEN` задан, `TELEGRAM_WEBHOOK_SECRET=''` → запрос отклонён (**503**) или приложение не стартовало (см. п.3), `process_update` не вызван.
  3. `test_config_requires_webhook_secret_when_bot_enabled` — `Settings(TELEGRAM_BOT_TOKEN="x", TELEGRAM_WEBHOOK_SECRET="")` в production → `ValueError`.
  Все падают сейчас (fail-open пропускает).
- **🟢 Green:** (а) если `webhook_secret` пуст — **fail-closed**: 503 и не обрабатывать; (б) сравнение `hmac.compare_digest`; (в) в валидаторе конфигурации требовать непустой `TELEGRAM_WEBHOOK_SECRET`, если задан `TELEGRAM_BOT_TOKEN`.
- **♻️ Refactor:** вынести проверку секрета в одну функцию-guard, переиспользуемую всеми webhook-роутами.
- **DoD:** три теста зелёные; `bandit` не ругается на сравнение; связка с C6 проверена (даже валидный `/closeall` закрывает корректно).
- **Integration:** убедиться, что легитимный Telegram (с корректным secret header) по-прежнему проходит — тест happy-path.

---

## Ветка `fix/trading-authz-integrity` — C2, C6

**Роль:** Backend Core (trading). Файлы: `app/trading/router.py`, `app/trading/service.py`, `app/trading/engine.py`, `app/trading/paper_engine.py`.
**Предпроверка:** baseline зелёный; **TDD обязателен** (модуль `trading`); прочитать gotchas по async-сессиям и Decimal.
**Порядок:** сначала C6 (корректное закрытие), затем C2 (ограничение доступа), т.к. C2-тест на `stop` опирается на корректный C6.

### C6 — `close_all_positions` закрывает без exit_price/PnL, ордера брокеру и возврата средств
**Файл:** `app/trading/engine.py:1673` · подтверждено.
- **🔴 Red:** `test_close_all_positions_realizes_pnl_and_funds` — сессия с открытой позицией и замоканным брокером/ценой → после `close_all_positions`: у позиции задан `exit_price` (Decimal), реализованный PnL посчитан, баланс изменён на сумму закрытия, брокеру отправлен рыночный ордер (для real). Второй тест: при ошибке брокера позиция **не** помечается закрытой (остаётся open, ошибка залогирована). Падают сейчас.
- **🟢 Green:** закрывать через реальный ордер (real/sandbox) либо по текущей рыночной цене (paper); фиксировать `exit_price`/PnL из исполнения, возвращать средства; на ошибке брокера — не закрывать.
- **♻️ Refactor:** переиспользовать существующий путь закрытия одиночной позиции (OrderManager), не дублировать логику.
- **Watch-outs:** деньги — только `Decimal`; не смешивать с `float`; закрытие в нерабочие часы — согласовать с circuit_breaker pre-check.

### C2 — IDOR: управление чужой торговой сессией
**Файл:** `app/trading/router.py:101,122` → `service.py:516,526` · подтверждено.
- **🔴 Red:** `test_stop_session_forbidden_for_non_owner` — сессия под пользователем B; из-под A вызвать `PATCH /sessions/{B}/stop` → **404**, сессия B не изменилась и позиции B не закрыты. Аналогично `pause`, `resume`, и чтения (`AUTHZ-03`: история/статистика). Падают сейчас.
- **🟢 Green:** пробросить `current_user.id` в `pause_session/resume_session/stop_session` (и связанные чтения), фильтровать выборку по владельцу; при чужом/несуществующем `session_id` — 404.
- **♻️ Refactor:** общий приватный `_get_owned_session(session_id, user_id)` в сервисе, используемый всеми методами.
- **Integration:** проверить, что WS-каналы `trades:{session_id}` тоже проверяют владельца (пересекается с `AUTHZ-04`).

---

## Ветка `fix/corp-actions-split` — C7

**Роль:** Backend (corporate_actions). Файлы: `app/corporate_actions/service.py`.
**Предпроверка:** baseline зелёный; деньги — Decimal.

### C7 — Реверс-сплит обнуляет позицию из-за усечения `int()`
**Файл:** `app/corporate_actions/service.py:52` · подтверждено.
- **🔴 Red:** `test_reverse_split_preserves_position_value` — позиция 5 лотов, сплит `ratio_from=10, ratio_to=1` → объём **не 0**; инвариант стоимости: `volume_before*price_before ≈ volume_after*price_after + cash_in_lieu`. Второй тест — прямой сплит 1:10 без потери дробных. Падают сейчас (`int(0.5)=0`).
- **🟢 Green:** считать объём с корректным округлением по правилам биржи; дробную часть компенсировать деньгами (cash-in-lieu) в баланс/PnL; либо блокировать сплит с уведомлением при неделимом объёме. `entry_price` корректировать согласованно с объёмом.
- **♻️ Refactor:** вынести пересчёт (volume, price, cash) в чистую функцию с юнит-тестами на граничные ratio.
- **Watch-outs:** `process_split`/`process_dividend`/`process_coupon` затрагивают позиции всех пользователей и коммитят по одному — при доработке рассмотреть транзакционность (см. `BE-MISC-P2` в бэклоге).

---

## Порядок и зависимости веток

```
fix/security-config       (C3,C4,C5) ──┐  независима
fix/telegram-webhook-auth (C1)        ──┤  зависит по смыслу от C6 (закрытие)
fix/trading-authz-integrity (C6→C2)   ──┤  C6 перед C2
fix/corp-actions-split    (C7)        ──┘  независима
```

Рекомендуемая последовательность мержа: `security-config` → `trading-authz-integrity` → `telegram-webhook-auth` → `corp-actions-split`. Каждая ветка мержится только после зелёного DoD и точечного ре-ревью изменённых файлов (`/code-review` для trading/broker/circuit_breaker).
