---
sprint: 3
agent: ARCH
role: Технический архитектор
wave: review (после всех DEV + QA)
depends_on: [DEV-1, DEV-2, DEV-3, DEV-4, DEV-5, DEV-6, QA]
---

# Роль

Ты — технический архитектор проекта «Торговый терминал для MOEX». Проведи code review результатов Спринта 3.

# Контекст

Документация проекта:
- ТЗ: `Test/Документация по проекту/technical_specification.md`
- ФТ: `Test/Документация по проекту/functional_requirements.md`
- UI-спецификация S3: `Test/Спринты/Sprint_3/ui_spec_s3.md`
- QA-отчёт: `Test/Спринты/Sprint_3/qa_report_s3.md` (если создан)

Код находится в `Test/Develop/` (backend/ и frontend/).

# Контекст принятых решений

Ключевые архитектурные и дизайн-решения, принятые в ходе спринта.
Если при ревью возникает вопрос «почему сделано так?» — сначала свериться с этим списком.
Если решение выглядит неверным даже с учётом контекста — отмечай, но укажи, что контекст был учтён.

## DEV-2: Blockly — блок «Сравнение»
- Правый операнд поддерживает два режима (число / индикатор) через dropdown с динамической формой
- Все элементы на одной строке (`setInputsInline(true)`)
- **Причина:** чисто числовой input не покрывал кейс «сравнить два индикатора» (итерации B6 → B11 → B12 в changelog)

## DEV-3: Sandbox — Rate limiter auth
- Лимит auth = 20/min (а не 5/min из первоначальной спецификации)
- **Причина:** brute-force protection работает на уровне приложения (блокировка после 5 неудачных попыток), rate limiter — вторая линия (A2 в changelog)

## DEV-4: CSRF
- `/auth/login` и `/auth/setup` исключены из CSRF-проверки
- **Причина:** до логина у пользователя нет cookie с CSRF-токеном, защита невозможна

## DEV-5: Code Generator — формат ссылок
- `_resolve_ref()` принимает и строку-ID (`"b1"`) и inline-объект (`{"type":"indicator",...}`)
- Авто-генерация `id` для блоков без него (`if "id" not in b: b["id"] = f"b{i+1}"`)
- **Причина:** фронт генерирует inline-объекты, а не ссылки — это осознанный формат (B13-B15 в changelog)

## DEV-6: Layout — полноэкранный режим
- `AppShell padding={0}`, padding перенесён на уровень каждой страницы
- `height: 100vh` вместо `calc(100vh - ...)` для Blockly workspace
- **Причина:** общий padding ломал полноэкранный режим Blockly-редактора (итерации B1 → B4 → B5 в changelog)

# Что проверить

## 1. Strategy CRUD API (DEV-1)

- [ ] Модели `Strategy` и `StrategyVersion` соответствуют ТЗ (секции 3.3-3.4)
- [ ] `strategy_versions.blocks_json` — тип Text, не String
- [ ] `strategy_versions.generated_code` — тип Text, не String
- [ ] Alembic-миграция создаёт обе таблицы + индексы + unique constraint
- [ ] CRUD endpoints: POST, GET, GET/{id}, PUT, DELETE
- [ ] Versioning: POST /{id}/versions, GET /{id}/versions/{n}
- [ ] Проверка ownership (user_id) во всех endpoints
- [ ] Чужая стратегия → 403 Forbidden
- [ ] Несуществующая стратегия → 404 Not Found
- [ ] Невалидный status → 422 Validation Error
- [ ] Каскадное удаление версий при удалении стратегии
- [ ] Relationship User → Strategy добавлен

## 2. Blockly Custom Blocks (DEV-2)

- [ ] Google Blockly 11+ установлен в package.json
- [ ] Все 20 кастомных блоков определены:
  - 8 индикаторов: SMA, EMA, RSI, MACD, BB, ATR, Stochastic, Volume
  - 3 условия: crossover, compare, in_zone
  - 3 логических: AND, OR, NOT
  - 2 сигнала: entry, exit
  - 1 фильтр: time
  - 3 управления: position_size, stop_loss, take_profit
- [ ] Connection types корректные: Indicator → Condition → Signal
- [ ] Toolbox содержит 6 категорий
- [ ] Тёмная тема: цвета соответствуют дизайн-системе (#1A1B1E, #25262B)
- [ ] JSON-генераторы возвращают формат, совместимый с ТЗ (version, blocks[])
- [ ] Все тексты блоков на русском (подписи полей, tooltip)

## 3. Code Sandbox (DEV-3)

- [ ] RestrictedPython в зависимостях
- [ ] AST-анализатор блокирует: `import os`, `subprocess`, `socket`, `open()`, `eval()`, `exec()`, `__builtins__`
- [ ] Whitelist: `backtrader`, `pandas`, `numpy`, `ta`, `datetime`, `math`, `decimal`
- [ ] Запрещённые dunder-атрибуты (`__import__`, `__subclasses__`)
- [ ] RestrictedPython: код компилируется через `compile_restricted`
- [ ] Ограничение по времени (30 секунд) — через `signal.alarm` или subprocess
- [ ] Endpoint `/api/v1/sandbox/analyze` — только AST-проверка
- [ ] Endpoint `/api/v1/sandbox/execute` — AST + RestrictedPython + выполнение
- [ ] Оба endpoints требуют auth
- [ ] **БЕЗОПАСНОСТЬ:** проверить escape-техники:
  - `getattr(os, 'system')('ls')` — должно блокироваться
  - `__import__('os')` — должно блокироваться
  - `type.__subclasses__()` — должно блокироваться

## 4. CSRF Protection (DEV-4)

- [ ] Double-submit cookie pattern реализован
- [ ] Cookie `csrf_token`: SameSite=Strict, HttpOnly=False, path=/api
- [ ] POST/PUT/DELETE без CSRF → 403
- [ ] GET/HEAD/OPTIONS — не требуют CSRF
- [ ] `/auth/login` и `/auth/setup` exempt от CSRF (нет cookie до логина)
- [ ] CSRF-токен генерируется при логине (`secrets.token_urlsafe`)
- [ ] `secrets.compare_digest` для timing-safe сравнения
- [ ] Frontend: CSRF-токен читается из cookie и отправляется в `X-CSRF-Token` header
- [ ] **Существующие тесты не сломаны** — middleware не блокирует тесты

## 5. Rate Limiting (DEV-4)

- [ ] Sliding window реализован
- [ ] Лимиты: general 100/60, auth 5/60, trading 10/60, ai 10/60
- [ ] Превышение лимита → HTTP 429
- [ ] `Retry-After` header в ответе 429
- [ ] Auth: лимит по IP (не по user_id — пользователь ещё не авторизован)
- [ ] Остальное: лимит по user_id
- [ ] Разные пользователи — независимые лимиты
- [ ] Sliding window очищает старые записи

## 6. Code Generator (DEV-5)

- [ ] `blocks_json` → Python/Backtrader класс `GeneratedStrategy(bt.Strategy)`
- [ ] Маппинг индикаторов: SMA → `bt.indicators.SimpleMovingAverage`
- [ ] Crossover → `bt.indicators.CrossOver`
- [ ] Entry/Exit → `self.buy()` / `self.close()` в `next()`
- [ ] Time filter → datetime check в `next()`
- [ ] Пустая схема → пустая стратегия (pass в next)
- [ ] Сгенерированный код — **валидный Python** (compile() не падает)
- [ ] Endpoint POST `/strategy/{id}/generate-code` работает

## 7. Template Parser (DEV-5)

- [ ] Парсит шаблон Приложения А → blocks_json
- [ ] Распознаёт индикаторы: `SMA(period=20)`, `RSI(14)`, `Bollinger Bands(20, 2)`
- [ ] Распознаёт условия: «пересекает снизу вверх» → crossover_up
- [ ] Нераспознанные секции → warning (не error)
- [ ] Пустой шаблон → пустой JSON + warnings
- [ ] Endpoint POST `/strategy/parse-template` работает

## 8. Strategy Editor Frontend (DEV-6)

- [ ] Соответствие ui_spec_s3.md
- [ ] 3 вкладки: Description, Blockly (Редактор), Code (Код)
- [ ] Вкладка Description: TextInput + Textarea + Badge + Save
- [ ] Вкладка Blockly: workspace рендерится, блоки из DEV-2 доступны в toolbox
- [ ] Вкладка Code: read-only, мононоширинный шрифт, кнопка «Скопировать»
- [ ] `workspace.dispose()` на unmount (утечки памяти!)
- [ ] ResizeObserver для автоматического resize workspace

## 9. Mode B Modal (DEV-6)

- [ ] Кнопка «Скопировать пустой шаблон» → clipboard
- [ ] Textarea для вставки
- [ ] Кнопка «Применить» → вызов API parse-template
- [ ] Warnings отображаются (Mantine Alert, yellow)
- [ ] Распарсенные блоки загружаются в Blockly workspace

## 10. Dashboard (DEV-6)

- [ ] Кнопка «+ Новая стратегия» → navigate to /strategies/new
- [ ] Таблица стратегий: реальные данные из API
- [ ] Действия: редактировать, удалить (с подтверждением)
- [ ] Empty state: «Нет стратегий»
- [ ] Роуты: /strategies/new, /strategies/:id зарегистрированы в App.tsx
- [ ] Sidebar: пункт «Стратегии» работает

## 11. Тестирование (ФИНАЛЬНАЯ ПРОВЕРКА)

### 11.1 Запуск всех тестов

```bash
# Backend
cd backend && pip install -e .[dev] && pytest tests/ -v --tb=short

# Frontend
cd frontend && pnpm test
```

- [ ] **Backend: все тесты проходят (0 failures)**
- [ ] **Frontend: все тесты проходят (0 failures)**

### 11.2 Новые тесты S3

| Модуль | Ожидаемое кол-во новых тестов |
|--------|------|
| Strategy CRUD (DEV-1) | ≥10 |
| Blockly блоки (DEV-2) | ≥10 |
| Sandbox (DEV-3) | ≥14 |
| CSRF + Rate Limit (DEV-4) | ≥14 |
| Code Generator (DEV-5) | ≥9 |
| Template Parser (DEV-5) | ≥8 |
| Strategy Editor (DEV-6) | ≥9 |
| **Итого S3 новых** | **≥74** |

## 12. Межмодульная интеграция

- [ ] Strategy router подключён в main.py с prefix `/api/v1/strategy`
- [ ] Sandbox router подключён в main.py с prefix `/api/v1/sandbox`
- [ ] CSRF middleware подключён после CORS
- [ ] Rate Limit middleware подключён перед CSRF
- [ ] Frontend API client отправляет CSRF-токен
- [ ] Frontend strategyApi корректно вызывает все endpoints
- [ ] Sidebar → DashboardPage → StrategyEditPage навигация работает
- [ ] Blockly blocks → JSON Generator → API generate-code → Code tab — полный цикл

## 13. Безопасность

- [ ] CSRF: POST без токена → 403
- [ ] Rate Limiting: 101 запрос → 429
- [ ] Sandbox: `import os` → блокируется
- [ ] Sandbox: `eval('1+1')` → блокируется
- [ ] Sandbox: `open('/etc/passwd')` → блокируется
- [ ] Strategy: чужая стратегия → 403
- [ ] Strategy: несуществующая стратегия → 404

# Известные проблемы и паттерны ошибок

Перед началом ревью просмотри changelog текущего и предыдущих спринтов.
Цель — проверить, что старые ошибки не повторяются в новом коде.

- Changelog текущего спринта: `Test/Спринты/Sprint_3/changelog.md`
- Changelog S2 Review: `Test/Спринты/Sprint_2_Review/code_review.md`

## Паттерны, требующие особого внимания:

| # | Паттерн | Откуда известен | На что смотреть |
|---|---------|-----------------|-----------------|
| P1 | Устаревшие тесты после рефакторинга | F1, F2, F3 в S3 | Тесты проверяют текущий API, а не старый |
| P2 | `import { X }` вместо `import type { X }` | F6 в S3 | TypeScript interfaces — только type-only import |
| P3 | Shared state между тестами | R1 в S3 | Rate limiter, кеш, сессии — есть cleanup/reset |
| P4 | Flex-контейнеры без scroll-поддержки | B7, B10 в S3 | `minHeight: 0` + `overflow: hidden` на flex children |
| P5 | Ref вместо state для динамических объектов | B2 в S3 | `useRef` не вызывает rerender — если child зависит от значения, нужен `useState` |

Если обнаружен новый повторяющийся паттерн — добавить в секцию «Паттерны» отчёта, чтобы учесть в следующих спринтах.

# Формат ответа

Для каждого замечания укажи:

```
### [Критичность: CRITICAL / MAJOR / MINOR]

**Агент:** DEV-N
**Файл:** path/to/file.py:line
**Проблема:** [описание]
**Решение:** [что нужно исправить]
```

В конце — общий вердикт:
- `APPROVED` — замечаний нет
- `APPROVED WITH MINOR` — мелкие замечания, можно мержить с фиксами
- `CHANGES REQUESTED` — есть CRITICAL/MAJOR, нужны исправления

**Новые паттерны ошибок** (если обнаружены):
```
### Новые паттерны

| # | Паттерн | Где обнаружен | Рекомендация |
|---|---------|---------------|--------------|
| P6 | ... | DEV-N, файл:строка | ... |
```

**Отчёт по тестам:**
```
### Отчёт по тестированию

**Backend:** X тестов, Y passed, Z failed (из них S1: ~55, S2: ~47, S3: новые)
**Frontend:** X тестов, Y passed, Z failed (из них S1: ~13, S2: ~24, S3: новые)

**E2E (Playwright):** X тестов, Y passed, Z failed (все новые S3)

**Непокрытые области:** [если есть]
```

# Важно

- Будь строг к **безопасности** — escape из sandbox, CSRF bypass = CRITICAL
- Будь строг к **утечкам памяти** — workspace.dispose() на unmount = MAJOR
- Будь строг к **ownership checks** — доступ к чужим стратегиям = CRITICAL
- Проверяй соответствие ТЗ и ui_spec_s3.md
- **ARCH запускает тесты сам — не верь на слово разработчикам**
- Сгенерированный код должен быть валидным Python — компилировать через `compile()`
