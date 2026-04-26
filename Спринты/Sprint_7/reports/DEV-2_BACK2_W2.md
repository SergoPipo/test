---
sprint: 7
agent: DEV-2 (BACK2)
wave: W2 sub-wave 1
date: 2026-04-25
---

# DEV-2 BACK2 W2 — отчёт

## 1. Реализовано

- **7.1-be Версионирование стратегий (C4):** alembic-миграция `c1d4e5f6a7b8` (+`created_by`, +`comment`, индекс `idx_sv_history`); 4 endpoint'а: `GET .../versions/list`, `GET .../versions/by-id/{ver_id}`, `POST .../versions/snapshot`, `POST .../versions/{ver_id}/restore`. Политика «авто-снимок c idempotency 5 мин» в `StrategyService.create_version` + history-preserving `restore_version`.
- **7.3 Экспорт CSV/PDF бэктеста:** `GET /api/v1/backtest/{id}/export?format=csv|pdf`. CSV — нативно (`csv.DictWriter`, два блока `#metric` / `#trades`). PDF — lazy-import WeasyPrint, при отсутствии — HTTP 503 со ссылкой на skip-тикет.
- **7.8-be Wizard (C6):** alembic-миграция `d2e3f4a5b6c7` (+`users.wizard_completed_at`); endpoint `POST /api/v1/auth/me/wizard/complete`; поле `wizard_completed_at` добавлено в `UserResponse` (отдаётся в `GET /api/v1/auth/me`). Замечание по URL — см. секцию 6.
- **7.18 AI слэш-команды (C3):** новый модуль `app/ai/slash_context.py` (резолверы chart/backtest/strategy/session/portfolio + sanitization + ownership + prompt-injection wrapper). Расширение `ChatRequest.context_items: list[ChatContextItem]`. Подключено в обоих `/chat` и `/chat/stream`.

## 2. Файлы

- Миграции: `alembic/versions/c1d4e5f6a7b8_add_strategy_versions_meta.py`, `d2e3f4a5b6c7_add_users_wizard_completed_at.py`.
- Strategy: `app/strategy/{models,schemas,service,router}.py` (изменены).
- Auth: `app/auth/{models,schemas,router}.py` (изменены).
- AI: `app/ai/slash_context.py` (NEW); `app/ai/{chat_schemas,chat_router}.py` (изменены).
- Backtest: `app/backtest/export.py` (NEW); `app/backtest/router.py` (+ endpoint).
- Stack Gotcha: `Develop/stack_gotchas/gotcha-20-fastapi-static-vs-int-path.md` (NEW) + `INDEX.md`.
- Backlog: `Спринты/Sprint_8_Review/backlog.md` (NEW, S7R-PDF-EXPORT-INSTALL).

## 3. Тесты

- 29 новых: `tests/unit/test_strategy/test_versioning.py` (6), `tests/unit/test_auth/test_wizard.py` (3), `tests/unit/test_ai/test_slash_context.py` (13), `tests/unit/test_backtest/test_export.py` (7).
- Полный suite: `pytest tests/ -q` → **866 passed / 0 failed** (102s). Baseline midsprint = 771; +95 за W2 sub-wave 1 (29 моих + остальные у параллельных DEV).
- Покрытие: ownership-403, idempotency, history-preserving restore, sanitization (control-chars, marker-forgery), wrap_user_message, CSV format, PDF 503 fallback.
- Skip-тикеты: 1 ветка `pytest.skip` в `test_export.py` (PDF positive-path активируется после установки WeasyPrint, тикет S7R-PDF-EXPORT-INSTALL).

## 4. Integration points

Все verifications пройдены через `grep -rn` в `app/`:
- `ChatContextItem`, `build_enriched_prefix`, `wrap_user_message` → используются в `app/ai/chat_router.py:170,215,308`.
- `wizard_completed_at` → `app/auth/{models,schemas,router}.py`.
- 4 strategy_versions endpoint'а → `app/strategy/router.py:164,194,213,253`.
- `generate_csv`/`generate_pdf` → `app/backtest/router.py:817-845`.

## 5. Контракты (поставщик)

| # | Артефакт | Момент публикации |
|---|----------|-------------------|
| **C4** | alembic `c1d4e5f6a7b8` + 4 endpoint'а strategy versions | первым в сессии (миграция 19:00, endpoints 19:30) — FRONT2 разблокирован |
| **C6** | alembic `d2e3f4a5b6c7` + `wizard_completed_at` field + `POST /auth/me/wizard/complete` | сразу после C4 (FRONT2 wizard разблокирован) |
| **C3** | `ChatContextItem` + `context_items` field + `app/ai/slash_context.py` | после C6 (FRONT1 sub-wave 2 разблокирован) |

## 6. Проблемы и решения

- **URL `/users/me`:** промпт C6 указывает `/api/v1/users/me`, но в репозитории нет модуля `users/`, фронт уже использует `/api/v1/auth/me`. Принято решение монтировать `wizard/complete` под существующий `auth_router` → итоговый URL `POST /api/v1/auth/me/wizard/complete`. FRONT2 при потреблении контракта C6 должен ориентироваться на это.
- **WeasyPrint не установлен в окружении** → PDF endpoint реализован с lazy-import + возвращает 503 со ссылкой на skip-тикет. CSV полностью функционален.
- **Routing collision** (см. секцию 7) — найден на `pytest`, исправлен переносом статических сегментов выше динамических.
- **`legacy ChatRequest.context: dict | None`** оставлен (используется фронтом для текущих блоков стратегии); новое поле `context_items` добавлено отдельно — без breaking change.

## 7. Применённые Stack Gotchas

- **#11 Alembic drift:** обе миграции содержат ТОЛЬКО намеренные изменения; round-trip `downgrade -2 → upgrade head` успешен.
- **#12 SQLite batch_alter_table:** в `c1d4e5f6a7b8` использован `naming_convention` для FK + явное `name=` (иначе `ValueError: Constraint must have a name`). Для `wizard_completed_at` — `nullable=True` без server_default'а.

## 8. Новые Stack Gotchas

- **#20 FastAPI: статический сегмент после `/{int_param}` → 422.** Файл `gotcha-20-fastapi-static-vs-int-path.md` создан, индекс обновлён. Ретро: `GET /strategy/1/versions/list` возвращал 422, тест `test_versions_ownership_other_user_403` упал. Исправлено перестановкой 3 новых маршрутов выше legacy `/{strategy_id}/versions/{version_number}`.
