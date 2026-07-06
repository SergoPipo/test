# Лог исправления критических находок (P0) код-ревью

**Дата:** 2026-07-06
**Ветка:** `s8r/bug-31-unified-codegen` (репозиторий `Develop/` → `origin` `git@github.com:SergoPipo/moex-terminal.git`)
**Модель-исполнитель фиксов:** Opus 4.8 (оркестрация — Fable 5), строго test-first (Red→Green→Refactor).
**Итог:** все **7 различных критических** проблем из [code_review_full_report.md](code_review_full_report.md) (раздел 3) исправлены, покрыты тестами, смёржены в `s8r/bug-31-unified-codegen` и **запушены**.

## Что исправлено

| ID | Проблема | Файлы | Тесты |
|----|----------|-------|-------|
| C1 | Telegram-webhook fail-open → неаутентифицированное закрытие чужих позиций | `notification/router.py`, `config.py` | `test_telegram_webhook_fail_open.py` (6) |
| C2 | IDOR: управление/чтение чужой торговой сессии | `trading/router.py`, `trading/service.py` | `test_router_idor_c2.py` (6) |
| C3 | Дефолтные `SECRET_KEY`/`ENCRYPTION_KEY` не блокируют production | `config.py` | `test_config.py` (6) |
| C4 | Cookie `access_token`/`csrf_token` с `secure=False` | `auth/router.py` | `test_auth_cookie_secure.py` (4) |
| C5 | Реальный `TELEGRAM_WEBHOOK_SECRET` в git | `assets/telegram_bot_setup.md` | grep-проверка |
| C6 | `close_all_positions` без exit_price/PnL/ордера/возврата средств | `trading/engine.py`, `trading/service.py` | `test_engine_close_all_positions_c6.py` (3), `test_stop_session_best_effort_c6.py` (6) |
| C7 | Реверс-сплит обнуляет позицию через `int()` | `corporate_actions/service.py` | `test_split_value_preservation.py` (8) |

## Коммиты (в порядке слияния)

- `84f04b2` — C3/C4/C5 (security-config)
- `3d5ee2d` — C1 (telegram-webhook fail-closed + constant-time + требование секрета в prod)
- `033aa8f` — C2/C6 (реальное закрытие + проверка владельца)
- `9956a6e` — C6 доработка (best-effort + stop→stopped + уведомление; закрывает находки код-ревью)
- `1550407` — C7 (floor + cash-in-lieu)
- merge-коммиты `16cc257`, `c74da71`, `1107ec3` → `s8r/bug-31-unified-codegen` (push `e4aad3d..1107ec3`)

## Верификация

- **Merged-ветка (integration/p0):** тесты всех фиксов — **38 passed**; широкая регрессия (trading + notification + routers + corporate_actions) — **566 passed**.
- **pyright:** 0 errors на изменённых `.py`. **tsc --noEmit** (весь фронт) — **0 errors**.
- `config.py` после мержа: оба валидатора (`check_production_secrets`, `check_telegram_webhook_secret`) с `raise`, `import warnings` убран — конфликта не было (правки в разных участках).

## `/code-review` по trading (C6+C2)

Проведён (xhigh, 3 finder-агента + верификация). C2 (IDOR) — чисто и полно. Изменённые строки C6 — чисто. Найдены 2 замечания по дизайну fail-loud → **закрыты доработкой C6** (`9956a6e`):
- `close_all_positions` → **best-effort** (закрывает что может, не падает на первой ошибке);
- `stop_session` → всегда доводит сессию до **`stopped`** (не `suspended` — его runtime авто-восстанавливает в `active`), незакрытые позиции остаются honest-open + пользователю шлётся уведомление `positions.close_failed` (добавлен в `EVENT_MAP` + frontend `EVENT_TYPE_LABELS`).

## ⚠️ Ручные действия оператора (по C5 — вне кода)

1. **Ротировать** `TELEGRAM_WEBHOOK_SECRET` — значение `90f0fac…5100` скомпрометировано (было в git). Сгенерировать новый, обновить `.env` на сервере, переустановить webhook через `setWebhook`.
2. **Вычистить историю git** (`git filter-repo`/BFG по `backend/assets/telegram_bot_setup.md`) + форс-пуш с координацией — правка файла убрала секрет только из рабочего дерева, не из истории.

## Follow-up (обнаружено при исправлении / ревью — заведено в backlog)

См. [backlog_fixes.md](backlog_fixes.md) раздел «Follow-up (обнаружено при исправлении P0)»:
- Пустая позиция (`volume_lots=0`, `status='open'`) после полного реверс-сплита — авто-закрывать/помечать.
- `close_position`: ордер по `filled_lots or volume_lots`, а PnL по `volume_lots` — рассинхрон при частичном филле.
- `delete_session` для `stopped`-сессии с открытыми real-позициями удаляет записи из БД → фантом у брокера (предсуществующее).
