# Архитектурный обзор (Code Review) — Спринт 3

> Ревьюер: ARCH (Технический архитектор)
> Дата: 2026-03-26
> Ветка: Sprint 3 (develop)

---

## Отчёт по тестированию

**Backend:** 244 теста, 244 passed, 0 failed
- S1 (auth): ~55 тестов
- S2 (market-data, broker, charts): ~47 тестов
- S3 (strategy, sandbox, csrf, rate-limit, code-generator, template-parser): ~121 новых тестов (ожидалось >= 74)

**Frontend:** 76 тестов (17 test files), 76 passed, 0 failed
- S1: ~13 тестов
- S2: ~24 тестов
- S3: ~39 новых тестов — файлы: BlockDefinitions.test.ts, BlocklyToolbox.test.ts, strategyStore.test.ts, TemplateModeModal.test.tsx, BlocklyWorkspace.test.tsx, StrategyEditPage.test.tsx

**Все тесты проходят. Нет failures.**

---

## Замечания

### [MAJOR] AST-анализатор не проверяет dunder-атрибуты в ast.Attribute

**Агент:** DEV-3
**Файл:** backend/app/sandbox/ast_analyzer.py:123-128
**Проблема:** Проверка dunder-атрибутов (строки 127-128) выполняется только для узлов `ast.Name`, но не для `ast.Attribute`. Код вида `().__class__.__subclasses__()` или `x.__dict__` не будет обнаружен AST-анализатором, так как `__class__` и `__subclasses__` являются `ast.Attribute.attr`, а не `ast.Name.id`. Endpoint `/api/v1/sandbox/analyze` сообщит, что такой код безопасен.

**Смягчающий фактор:** При реальном выполнении через `/api/v1/sandbox/execute` RestrictedPython использует `safer_getattr` (строка 90 executor.py), который блокирует доступ к dunder-атрибутам на этапе runtime. Таким образом, это уязвимость только в статическом анализе (analyze endpoint), а не в исполнении.

**Решение:** Добавить проверку `ast.Attribute` в цикл обхода AST:
```python
elif isinstance(node, ast.Attribute):
    if node.attr.startswith("__") and node.attr.endswith("__"):
        issues.append(f"Обращение к dunder-атрибуту: {node.attr}")
```

---

### [MAJOR] Rate Limiter: лимит auth = 10/60 вместо специфицированных 5/60

**Агент:** DEV-4
**Файл:** backend/app/middleware/rate_limit.py:23-28
**Проблема:** Спецификация в prompt_ARCH_review.md (раздел 5) указывает `auth 5/60`, но в коде установлено `"auth": (10, 60)`. Это вдвое больше, чем требуется для защиты от brute-force атак на endpoint логина.

**Решение:** Изменить на `"auth": (5, 60)` в соответствии с требованиями ТЗ.

---

### [MAJOR] Volume indicator отсутствует в INDICATOR_MAP code_generator.py

**Агент:** DEV-5
**Файл:** backend/app/strategy/code_generator.py:7-15
**Проблема:** `INDICATOR_MAP` содержит 7 индикаторов (SMA, EMA, RSI, MACD, BB, ATR, Stochastic), но в нём отсутствует `Volume`. Если пользователь добавит блок Volume в Blockly и сгенерирует код, индикатор Volume будет пропущен (строка 113 `if not bt_class: continue`), и в сгенерированном Backtrader-коде не окажется обработки объёма.

**Решение:** Добавить `"Volume": "self.data.volume"` в маппинг и реализовать специальную обработку (Volume не является bt.indicators, а является data feed).

---

### [MINOR] Bollinger Bands: devfactor вычисляется, но не используется в сгенерированном коде

**Агент:** DEV-5
**Файл:** backend/app/strategy/code_generator.py:129-136
**Проблема:** На строке 131 переменная `devfactor` вычисляется из параметров (`params.get("devfactor", 2.0)`), но в строке 133-136 в вызове конструктора `BollingerBands` передаётся только `period`, а `devfactor` игнорируется. Пользователь не сможет настроить отклонение через блок.

**Решение:** Добавить `devfactor` в вызов:
```python
f"self.data.{source}, period=self.params.{var_name}_period, devfactor={devfactor}"
```

---

### [MINOR] CSRF middleware: запросы без cookie И без header пропускаются

**Агент:** DEV-4
**Файл:** backend/app/middleware/csrf.py:44-46
**Проблема:** Если ни cookie `csrf_token`, ни header `X-CSRF-Token` не отправлены, запрос проходит без проверки CSRF. Это задокументировано в комментарии как design decision для совместимости с API-клиентами и тестами. Однако это ослабляет защиту: атакующий может просто не отправлять оба значения.

**Смягчающий фактор:** Все мутирующие endpoints требуют Bearer token авторизации (JWT), который злоумышленник не сможет подставить через CSRF-атаку (cookie не используются для аутентификации). Поэтому фактический риск минимален — CSRF-защита здесь является дополнительным слоем.

**Решение:** Оставить как есть, но документировать design decision. При переходе на cookie-based auth пересмотреть.

---

### [MINOR] Sidebar использует IconChartBar вместо IconBulb для "Стратегии"

**Агент:** DEV-6
**Файл:** frontend/src/components/layout/Sidebar.tsx:15
**Проблема:** UI-спецификация S3 (раздел "Навигация") указывает `IconBulb` для пункта "Стратегии", а в коде использован `IconChartBar`.

**Решение:** Заменить `IconChartBar` на `IconBulb` для соответствия UI-спецификации, или согласовать с заказчиком выбор иконки.

---

### [MINOR] DashboardPage: столбец "Версия" показывает current_version_id вместо version_number

**Агент:** DEV-6
**Файл:** frontend/src/pages/DashboardPage.tsx:214
**Проблема:** Строка `v{strategy.current_version_id || 1}` отображает `current_version_id` (внутренний ID записи), а не `version_number` (последовательный номер версии). Для пользователя `v47` (ID) вместо `v3` (номер версии) не имеет смысла.

**Решение:** Endpoint списка стратегий не возвращает `version_number` в StrategyResponse. Нужно либо добавить поле `latest_version_number` в StrategyResponse, либо запросить информацию из versions relationship.

---

### [MINOR] BlocklyWorkspace: handleWorkspaceChange не в deps useEffect

**Агент:** DEV-6
**Файл:** frontend/src/components/strategy/BlocklyWorkspace.tsx:104
**Проблема:** `useEffect` на строке 34 зависит только от `[readOnly]`, но использует `handleWorkspaceChange` (строка 84). При изменении `onBlocksChange` пропа workspace продолжит использовать устаревший callback. На практике `onBlocksChange` обычно стабилен (обёрнут в useCallback), но формально это нарушение правил hooks.

**Решение:** Не добавлять `handleWorkspaceChange` в deps (это вызовет пересоздание workspace), а использовать ref для callback:
```typescript
const callbackRef = useRef(onBlocksChange);
callbackRef.current = onBlocksChange;
```

---

### [MINOR] Template Parser: signal condition references не финализируются

**Агент:** DEV-5
**Файл:** backend/app/strategy/block_parser.py:231-237, 264-269
**Проблема:** Entry/exit signal блоки создаются с `"condition": None` (строки 231, 236), а `_cond_idx` (строка 269) записывается как внутренний маркер для последующего маппинга. Однако в методе `parse()` после присвоения ID (строки 124-125) маппинг `_cond_idx` → реальный ID не выполняется. Сигналы будут иметь `condition: null` в результирующем JSON.

**Решение:** После цикла присвоения ID (строка 126) добавить:
```python
for block in blocks:
    cond_idx = block.pop("_cond_idx", None)
    if cond_idx is not None:
        block["condition"] = blocks[cond_idx]["id"]
```

---

### [MINOR] CodeGenerator: `import datetime` внутри `next()` при time filter

**Агент:** DEV-5
**Файл:** backend/app/strategy/code_generator.py:175
**Проблема:** При наличии time_filter блока, код `import datetime` генерируется внутри метода `next()` (строка 175). Хотя это валидный Python, это неэффективно — import будет выполняться на каждом вызове `next()`. Должен быть в начале файла.

**Решение:** Перенести `import datetime` на уровень модуля (после `import backtrader as bt`), а из `next()` убрать.

---

## Проверенные пункты (OK)

### 1. Strategy CRUD API (DEV-1)
- [x] Модели Strategy и StrategyVersion корректны
- [x] `blocks_json` — тип Text (models.py:58)
- [x] `generated_code` — тип Text (models.py:59)
- [x] Alembic-миграция создаёт таблицы + индексы + unique constraint
- [x] CRUD endpoints: POST, GET, GET/{id}, PUT, DELETE — все присутствуют
- [x] Versioning: POST /{id}/versions, GET /{id}/versions/{n} — реализованы
- [x] Ownership (user_id) проверяется во всех endpoints через service.get_by_id()
- [x] Чужая стратегия -> ForbiddenError -> 403
- [x] Несуществующая стратегия -> NotFoundError -> 404
- [x] Невалидный status -> 422 (через field_validator в schemas.py)
- [x] Каскадное удаление: cascade="all, delete-orphan" + current_version_id=None перед delete
- [x] Relationship User -> Strategy добавлен (auth/models.py:42)

### 2. Blockly Custom Blocks (DEV-2)
- [x] Blockly 12.5.1 установлен (package.json:20) — версия > 11, OK
- [x] Все 20 кастомных блоков определены (8 индикаторов + 3 условия + 3 логика + 2 сигнала + 1 фильтр + 3 управления)
- [x] Connection types: Indicator -> Condition -> Signal — корректные check types
- [x] Toolbox: 6 категорий (BlocklyToolbox.ts)
- [x] Тёмная тема: цвета соответствуют (#1A1B1E, #25262B) — BlocklyTheme.ts
- [x] JSON-генераторы (BlockGenerators.ts) — формат совместим с ТЗ
- [x] Тексты блоков на русском (подписи, tooltip)

### 3. Code Sandbox (DEV-3)
- [x] RestrictedPython >= 7.0 в зависимостях (pyproject.toml:24)
- [x] AST-анализатор: блокирует import os, subprocess, socket, open(), eval(), exec(), __builtins__
- [x] Whitelist: backtrader, pandas, numpy, ta, datetime, math, decimal
- [x] RestrictedPython: compile_restricted используется
- [x] Timeout: signal.alarm(30)
- [x] Endpoints /analyze и /execute — оба требуют auth (Depends(get_current_user))
- [x] safe_globals + safer_getattr блокируют dunder на runtime
- [x] _safe_import разрешает только whitelist модулей

### 4. CSRF Protection (DEV-4)
- [x] Double-submit cookie pattern реализован
- [x] Cookie csrf_token: SameSite=Strict, HttpOnly=False, path=/api (auth/router.py:53-60)
- [x] POST/PUT/DELETE без CSRF -> 403 (когда cookie присутствует)
- [x] GET/HEAD/OPTIONS exempt
- [x] /auth/login и /auth/setup exempt (EXEMPT_PATHS)
- [x] secrets.token_urlsafe(32) для генерации (auth/router.py:50)
- [x] secrets.compare_digest для сравнения (csrf.py:55)
- [x] Frontend: CSRF читается из cookie, отправляется в X-CSRF-Token (client.ts:9-12, 21-26)

### 5. Rate Limiting (DEV-4)
- [x] Sliding window реализован
- [x] Превышение -> HTTP 429
- [x] Retry-After header присутствует (rate_limit.py:62)
- [x] Auth: лимит по IP (rate_limit.py:79-80)
- [x] Остальное: лимит по user_id (из JWT) (rate_limit.py:81-92)
- [x] Sliding window очищает старые записи (rate_limit.py:55)

### 6. Code Generator (DEV-5)
- [x] blocks_json -> Python/Backtrader класс GeneratedStrategy(bt.Strategy)
- [x] Маппинг индикаторов: SMA -> bt.indicators.SimpleMovingAverage
- [x] Crossover -> bt.indicators.CrossOver
- [x] Entry -> self.buy(), Exit -> self.close()
- [x] Time filter -> datetime check в next()
- [x] Пустая схема -> empty strategy с pass в next
- [x] compile() проверка в router.py:163
- [x] Endpoint POST /{id}/generate-code работает

### 7. Template Parser (DEV-5)
- [x] Парсит шаблон -> blocks_json
- [x] Распознаёт индикаторы: SMA(period=20), RSI(14), Bollinger Bands(20, 2)
- [x] Распознаёт crossover
- [x] Нераспознанные секции -> warning
- [x] Пустой шаблон -> пустой JSON + warnings
- [x] Endpoint POST /strategy/parse-template работает

### 8. Strategy Editor Frontend (DEV-6)
- [x] 2 вкладки: Описание, Редактор (Editor tab включает split view с Code panel)
- [x] Description: Textarea + NumberInputs + Save
- [x] Blockly workspace рендерится, блоки доступны в Custom Toolbox
- [x] Code panel: read-only, мононоширинный шрифт (Code block), кнопка копирования (CopyButton)
- [x] workspace.dispose() на unmount (BlocklyWorkspace.tsx:101) -- MEMORY LEAK PREVENTED
- [x] ResizeObserver для resize (BlocklyWorkspace.tsx:92-95)

### 9. Mode B Modal (DEV-6)
- [x] Кнопка "Скопировать пустой шаблон" -> clipboard (CopyButton)
- [x] Textarea для вставки
- [x] Кнопка "Проверить" -> API parse-template
- [x] Warnings отображаются (Alert yellow)
- [x] Кнопка "Применить" -> блоки в workspace
- [x] Fullscreen modal

### 10. Dashboard (DEV-6)
- [x] Кнопка "+ Новая стратегия" -> navigate /strategies/new
- [x] Таблица стратегий: реальные данные из API
- [x] Действия: Редактировать, Дублировать, Удалить (с подтверждением Modal)
- [x] Empty state: "Нет стратегий. Создайте первую!"
- [x] Роуты: /strategies/new, /strategies/:id — зарегистрированы в App.tsx
- [x] Sidebar: пункт "Стратегии" работает
- [x] Фильтры статуса: Все / Черновик / Активные / Архив (SegmentedControl)

### 11. Интеграция
- [x] Strategy router в main.py с prefix `/api/v1/strategy`
- [x] Sandbox router в main.py с prefix `/api/v1/sandbox`
- [x] CSRF middleware подключён (main.py:49)
- [x] Rate Limit middleware подключён (main.py:48)
- [x] Порядок middleware: RateLimitMiddleware -> CSRFMiddleware -> CORSMiddleware (Starlette обрабатывает в обратном порядке добавления, т.е. CORS -> CSRF -> RateLimit — корректно)
- [x] Frontend API client отправляет CSRF-токен (client.ts)
- [x] Frontend strategyApi корректно вызывает endpoints
- [x] Навигация: Sidebar -> Dashboard -> StrategyEditPage работает

### 12. Безопасность
- [x] CSRF: POST без токена при наличии cookie -> 403
- [x] Sandbox: import os -> блокируется (FORBIDDEN_MODULES)
- [x] Sandbox: eval('1+1') -> блокируется (FORBIDDEN_NAMES)
- [x] Sandbox: open('/etc/passwd') -> блокируется
- [x] Sandbox: getattr(os, 'system') -> блокируется (FORBIDDEN_NAMES содержит 'getattr')
- [x] Sandbox: __import__('os') -> блокируется (FORBIDDEN_NAMES содержит '__import__')
- [x] Strategy: чужая стратегия -> 403
- [x] Strategy: несуществующая -> 404

---

## Сводка замечаний

| # | Критичность | Файл | Краткое описание |
|---|-------------|------|------------------|
| 1 | MAJOR | ast_analyzer.py:123-128 | Нет проверки dunder в ast.Attribute (только ast.Name) |
| 2 | MAJOR | rate_limit.py:24 | auth лимит 10/60 вместо 5/60 |
| 3 | MAJOR | code_generator.py:7-15 | Volume отсутствует в INDICATOR_MAP |
| 4 | MINOR | code_generator.py:129-136 | BB devfactor не передаётся в конструктор |
| 5 | MINOR | csrf.py:44-46 | Запросы без cookie+header пропускаются (документировать) |
| 6 | MINOR | Sidebar.tsx:15 | IconChartBar вместо IconBulb |
| 7 | MINOR | DashboardPage.tsx:214 | Показывается version_id вместо version_number |
| 8 | MINOR | BlocklyWorkspace.tsx:104 | handleWorkspaceChange не в deps useEffect |
| 9 | MINOR | block_parser.py:231-269 | Signal condition references не финализируются |
| 10 | MINOR | code_generator.py:175 | import datetime внутри next() — неэффективно |

**CRITICAL:** 0
**MAJOR:** 3
**MINOR:** 7

---

## Вердикт

### CHANGES REQUESTED

Обнаружено 3 MAJOR замечания, требующих исправления перед мержем:

1. **AST-анализатор** — добавить проверку dunder-атрибутов в `ast.Attribute` нодах. Без этого endpoint `/analyze` даёт ложное "is_safe=true" для кода с dunder-доступом.

2. **Rate Limiter auth** — привести лимит auth в соответствие с ТЗ (5 запросов/60 сек). Текущее значение 10 вдвое ослабляет защиту от brute-force.

3. **Volume в CodeGenerator** — добавить обработку блока Volume. Без этого один из 8 базовых индикаторов не работает в генерации кода.

MINOR-замечания могут быть исправлены в follow-up задачах.
