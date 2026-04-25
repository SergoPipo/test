---
sprint: 7
agent: DEV-2
role: Backend Core (BACK2) — Strategy + Notification + AI + Telegram
wave: 1+2
depends_on: [ARCH W0]
---

# Роль

Ты — Backend-разработчик #2 (senior). Зона ответственности по RACI: Strategy Engine = R, AI Service = R, Notification Service = R, Telegram Bot = R, Bond Service = R, Tax Report Generator = R.

На W1 закрываешь долг S6 (NS singleton DI, Telegram inline-кнопки). На W2 реализуешь версионирование стратегий, экспорт CSV/PDF, wizard backend, AI слэш-команды.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Python ≥ 3.11, .venv активирован.
2. Зависимости: ARCH design завершён (arch_design_s7.md опубликован) — DDL для strategy_versions готов.
3. Существующие файлы: app/notification/service.py, app/notification/telegram/, app/strategy/, app/ai/, app/main.py.
4. База данных: alembic upgrade head — baseline схема.
5. Тесты baseline: pytest tests/ -q → 0 failures (число зафиксировано в отчёте).
```

# Обязательные плагины

| Плагин | Нужен? | Fallback |
|--------|--------|----------|
| pyright-lsp | **да** (mandatory после каждого Edit/Write) | `python -m py_compile` |
| context7 | **да** — Aiogram (callback handlers), WeasyPrint, openpyxl, SQLAlchemy, FastAPI Depends | WebSearch |
| superpowers TDD | **да, для 7.12** (DI-рефакторинг) | — |
| code-review | **да** после блока изменений в `app/notification/`, `app/ai/`, `app/strategy/` | — |
| typescript-lsp | нет | — |
| playwright | нет | — |
| frontend-design | нет | — |

# Обязательное чтение

1. **`Develop/CLAUDE.md`** полностью.
2. **`Develop/stack_gotchas/INDEX.md`** — пройти ловушки слоёв `notification/`, `strategy/`, `ai/`, `telegram/`.
3. **`Спринты/Sprint_7/execution_order.md`** Cross-DEV contracts:
   - **Поставщик:** C3 (для FRONT1), C4 (для FRONT2), C6 (для FRONT2), C7 (для BACK1, OPS), C8 (deep link).
4. **`Спринты/Sprint_7/arch_design_s7.md`** — секции 1 (versioning), 6 (AI commands), цитаты ТЗ/ФТ.
5. **`Sprint_6_Review/backlog.md`** — задачи #3, #6, #7 (NS singleton, EVENT_MAP, inline-кнопки) — это перенесённые в S7 задачи.
6. **`.claude/plans/purring-herding-badger.md`** — план AI-команд (для 7.18).
7. **Цитаты ТЗ/ФТ** — копировать из `arch_design_s7.md`.

# Рабочая директория

`Develop/backend/`

# Контекст существующего кода

- `app/notification/service.py` — `NotificationService`, `EVENT_MAP`. Singleton инстанс уже создан в `app/main.py:68`, но НЕ используется в остальных модулях (9 мест создают свой инстанс).
- `app/notification/telegram/bot.py` (или аналог) — Aiogram bot, отправка сообщений. Inline-кнопки уже шлются (например, при `trade_filled`), но `CallbackQueryHandler` не подключен.
- `app/strategy/models.py` — `Strategy` модель. Нужно добавить `StrategyVersion`.
- `app/ai/router.py` или `app/ai/service.py` — `ChatRequest` Pydantic схема. Расширить `context` поле.
- `app/users/models.py` — `User` модель. Добавить `wizard_completed_at: datetime|null`.
- `app/backtest/` — для 7.3 экспорта (получение `BacktestResult` для генерации CSV/PDF).

# Задачи

## Задача 7.12: NotificationService singleton через DI (W1, debt, TDD обязателен)

**Цель:** Убрать 9 инстансов `NotificationService()` в коде. Использовать singleton из `app/main.py:68` через FastAPI Depends.

**Подход:**

1. Создать `get_notification_service` dependency:
   ```python
   # app/notification/deps.py
   def get_notification_service(request: Request) -> NotificationService:
       return request.app.state.notification_service
   ```
2. В `app/main.py` после создания singleton:
   ```python
   app.state.notification_service = NotificationService(...)
   ```
3. Все 9 мест с `NotificationService()` заменить:
   - В endpoints/services через `Depends(get_notification_service)`.
   - В background tasks/runtime — через `app.state.notification_service` напрямую.

**Контракт C7 (поставщик):**
- Финальная проверка: `grep -rn "NotificationService()" app/` = 0 вне `main.py`.

**TDD:**
- Failing test: «два endpoints используют тот же инстанс» (assert id(svc1) == id(svc2)).
- Реализация — единая точка через DI.
- Green.

## Задача 7.14: Telegram CallbackQueryHandler (W1, debt)

**Контракт C8 (поставщик):**

CallbackData схема:
- `open_session:{session_id}` — кнопка «Открыть сессию» в уведомлении о новой сделке.
- `open_chart:{ticker}` — кнопка «Открыть график» в ценовом алерте.

```python
# app/notification/telegram/handlers.py (новый файл)

@dp.callback_query(F.data.startswith("open_session:"))
async def handle_open_session(callback: CallbackQuery):
    session_id = int(callback.data.split(":", 1)[1])
    # Deep link на /sessions/{id}
    deep_link = f"{settings.FRONTEND_URL}/sessions/{session_id}"
    await callback.message.answer(f"Открыть в браузере: {deep_link}")
    await callback.answer()

@dp.callback_query(F.data.startswith("open_chart:"))
async def handle_open_chart(callback: CallbackQuery):
    ticker = callback.data.split(":", 1)[1]
    deep_link = f"{settings.FRONTEND_URL}/chart?ticker={ticker}"
    await callback.message.answer(f"Открыть в браузере: {deep_link}")
    await callback.answer()
```

**SEC ревью:** валидация `session_id` принадлежит current_user (Telegram user → mapping на User в БД).

**Регистрация:** включить router в основной dispatcher в `app/notification/telegram/bot.py`.

## Задача 7.1-be: Версионирование стратегий backend (W2)

**Шаг 1 — Alembic миграция (ПЕРВЫЙ В ТРЕКЕ, FRONT2 ждёт):**

```python
# alembic/versions/<rev>_add_strategy_versions.py

def upgrade():
    op.create_table(
        'strategy_versions',
        sa.Column('id', sa.Integer, primary_key=True),
        sa.Column('strategy_id', sa.Integer, sa.ForeignKey('strategies.id', ondelete='CASCADE'), nullable=False),
        sa.Column('blocks_xml', sa.Text, nullable=False),
        sa.Column('code', sa.Text, nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('created_by', sa.Integer, sa.ForeignKey('users.id'), nullable=False),
        sa.Column('comment', sa.Text, nullable=True),
        sa.Index('ix_strategy_versions_strategy_id', 'strategy_id'),
    )
```

(Точная схема — из `arch_design_s7.md` секция 1.)

**Шаг 2 — Endpoints (контракт C4 поставщик для FRONT2):**

```python
# app/strategy/versions_router.py

@router.get("/api/v1/strategies/{id}/versions", response_model=list[StrategyVersionOut])
async def list_versions(id: int, current_user: User = Depends(get_current_user)):
    # Проверка ownership, возврат списка с метаданными

@router.post("/api/v1/strategies/{id}/versions", response_model=StrategyVersionOut)
async def create_version(id: int, payload: VersionCreate, current_user: User = Depends(get_current_user)):
    # Snapshot текущей strategy → новая запись в strategy_versions

@router.post("/api/v1/strategies/{id}/versions/{ver_id}/restore", response_model=StrategyOut)
async def restore_version(id: int, ver_id: int, current_user: User = Depends(get_current_user)):
    # Применить ver_id к текущей strategy + создать новую версию из текущей перед откатом (history-preserving)
```

Политика автоверсий — по итогу `arch_design_s7.md`.

## Задача 7.3: Экспорт CSV/PDF бэктеста (W2)

```python
# app/backtest/export.py (новый файл)

@router.get("/api/v1/backtests/{id}/export")
async def export_backtest(id: int, format: Literal["csv", "pdf"], current_user: User = Depends(get_current_user)):
    backtest = get_backtest(id, current_user)
    if format == "csv":
        return StreamingResponse(generate_csv(backtest), media_type="text/csv", headers={...})
    elif format == "pdf":
        return StreamingResponse(generate_pdf(backtest), media_type="application/pdf", headers={...})
```

**Библиотеки:** WeasyPrint (PDF) + `pandas.DataFrame.to_csv` или `csv.DictWriter` (CSV). Использовать context7 для WeasyPrint.

**Содержание PDF:** заголовок, параметры стратегии, метрики (Sharpe, drawdown, win rate, P&L), список сделок, графики (опционально).

## Задача 7.8-be: Wizard backend (W2)

**Шаг 1 — Alembic миграция:**

```python
def upgrade():
    op.add_column('users', sa.Column('wizard_completed_at', sa.DateTime(timezone=True), nullable=True))
```

**Шаг 2 — Endpoints (контракт C6 поставщик):**

```python
@router.post("/api/v1/users/me/wizard/complete")
async def complete_wizard(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    current_user.wizard_completed_at = datetime.utcnow()
    db.commit()
    return {"ok": True}

# В существующем GET /api/v1/users/me — добавить wizard_completed_at в response.
```

## Задача 7.18: AI слэш-команды backend (W2)

**Контракт C3 (поставщик):**

Расширить `ChatRequest`:

```python
# app/ai/schemas.py
class ChatContextItem(BaseModel):
    type: Literal["chart", "backtest", "strategy", "session", "portfolio"]
    id: int | str  # int для backtest/strategy/session, str (ticker) для chart, None для portfolio

class ChatRequest(BaseModel):
    message: str
    context: list[ChatContextItem] = []
```

В `app/ai/service.py`:

```python
async def chat(request: ChatRequest, current_user: User) -> ChatResponse:
    enriched_prompt = await build_enriched_prompt(request.context, request.message, current_user)
    return await llm_provider.complete(enriched_prompt)

async def build_enriched_prompt(context: list[ChatContextItem], user_msg: str, user: User) -> str:
    # Для каждого item в context:
    # 1. Валидация: id принадлежит current_user (запрос в БД).
    # 2. Подгрузка данных (chart → последние свечи, backtest → метрики, strategy → код, session → P&L, portfolio → баланс).
    # 3. Склейка в системный prefix:
    #    "Контекст: \n[Chart EURUSD 1H: ..., Backtest #42: Sharpe 1.5, ...] \n\nПользователь спрашивает: {user_msg}"
```

**SEC:** prompt injection защита — context-данные экранировать (не вставлять как `f""` без проверки).

**Источник:** `.claude/plans/purring-herding-badger.md` — план дизайна (если доступен).

# Опциональные задачи

Нет.

# Skip-тикеты в тестах

Если ввёл `@pytest.mark.skip` — карточка в `Sprint_8_Review/backlog.md` с тикетом `S7R-<NAME>`.

# Тесты

```
tests/
├── test_notification/
│   ├── test_singleton_di.py          # 7.12: один инстанс через DI
│   └── test_telegram_callbacks.py    # 7.14: open_session, open_chart handlers
├── test_strategy/
│   └── test_versioning.py            # 7.1-be: list/create/restore + ownership
├── test_backtest/
│   └── test_export.py                # 7.3: CSV/PDF generation
├── test_users/
│   └── test_wizard.py                # 7.8-be: complete + wizard_completed_at
├── test_ai/
│   └── test_chat_context.py          # 7.18: enriched prompt + ownership validation + injection защита
```

**Фикстуры:** `db_session`, `test_user`, `test_strategy`, `mock_llm`, `mock_telegram_bot`.

# Integration Verification Checklist

- [ ] **7.12 (CRITICAL):** `grep -rn "NotificationService()" app/` → 0 вне `main.py`.
- [ ] **7.12:** `app.state.notification_service` создан в `main.py` lifespan.
- [ ] **7.14:** `grep -rn "CallbackQueryHandler\|callback_query" app/notification/telegram/` показывает регистрацию.
- [ ] **7.14:** Router включен в основной dispatcher.
- [ ] **7.1-be:** `grep -rn "strategy_versions" app/` показывает модель.
- [ ] **7.1-be:** `grep -rn '"/api/v1/strategies/.*/versions"' app/` показывает 3 endpoints.
- [ ] **7.1-be:** `app.include_router(versions_router)` в `main.py`.
- [ ] **7.3:** `grep -rn '"/api/v1/backtests/.*/export"' app/` показывает endpoint.
- [ ] **7.8-be:** `grep -rn "wizard_completed_at" app/` показывает колонку и использование.
- [ ] **7.18:** `grep -rn "ChatContextItem\|build_enriched_prompt" app/` показывает реализацию.
- [ ] **7.18:** Ownership validation присутствует (тест с чужим id → 403).
- [ ] **Все endpoints:** `Depends(get_current_user)`, CSRF для POST.

# Формат отчёта

**2 файла:**

1. **`reports/DEV-2_BACK2_W1.md`** — после 7.12, 7.14.
2. **`reports/DEV-2_BACK2_W2.md`** — после 7.1-be, 7.3, 7.8-be, 7.18.

8 секций до 400 слов каждый.

# Alembic-миграция

**2 миграции:**

1. `add_strategy_versions` (для 7.1-be).
2. `add_users_wizard_completed_at` (для 7.8-be).

```bash
alembic revision --autogenerate -m "add_strategy_versions"
alembic upgrade head
alembic downgrade -1  # проверка обратимости
alembic upgrade head
```

# Чеклист перед сдачей

- [ ] Все задачи реализованы.
- [ ] Тесты зелёные.
- [ ] Линтер чистый.
- [ ] pyright чист.
- [ ] Integration verification пройден.
- [ ] Контракты C3, C4, C6, C7, C8 как поставщик подтверждены.
- [ ] Stack Gotchas применены и описаны в отчёте.
- [ ] Плагины использованы (TDD для 7.12, code-review для notification/AI).
- [ ] Skip-тикеты с карточками.
- [ ] Миграции применены и обратимы.
- [ ] `Sprint_7/changelog.md` обновлён.
- [ ] `Sprint_7/sprint_state.md` отражает прогресс.
- [ ] Отчёт сохранён файлом.
