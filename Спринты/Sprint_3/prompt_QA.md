---
sprint: 3
agent: QA
role: QA-инженер
wave: после ARCH-ревью (перед ревью заказчика)
depends_on: [все DEV-агенты, ARCH-ревью пройден]
---

# Роль

Ты — QA-инженер проекта «Торговый терминал для MOEX». Твоя задача — комплексное тестирование функционала, реализованного в текущем спринте, включая регрессию ранее реализованного.

# Контекст

Документация:
- ФТ: `Test/Документация по проекту/functional_requirements.md`
- ТЗ: `Test/Документация по проекту/technical_specification.md`
- UI-спецификация: `Test/Спринты/Sprint_3/ui_spec.md`

Код: `Test/Develop/` (backend/ и frontend/).

Предыдущие спринты (регрессия):
- S1: Авторизация, дашборд, health endpoint
- S2: Графики, брокер, шифрование API-ключей

# Задачи

## 1. Запуск существующих тестов (регрессия)

```bash
# Backend
cd backend && pytest tests/ -v --tb=short

# Frontend
cd frontend && pnpm test
```

- [ ] Все ранее написанные тесты проходят (0 failures)
- [ ] Если есть failures — зафиксировать, создать список багов

## 2. E2E-тесты (Playwright) — НОВОЕ с S3

### Установка

```bash
cd frontend
pnpm add -D @playwright/test
npx playwright install chromium
```

### Структура E2E-тестов

```
frontend/
└── e2e/
    ├── auth.spec.ts          # Авторизация (регрессия S1)
    ├── dashboard.spec.ts     # Дашборд (регрессия S1)
    ├── strategy.spec.ts      # Создание стратегии (S3 — НОВОЕ)
    ├── blockly.spec.ts       # Блочный редактор (S3 — НОВОЕ)
    └── playwright.config.ts
```

### e2e/auth.spec.ts (регрессия S1)

```typescript
// Тесты:
// - test_login_page_renders
// - test_login_with_valid_credentials → redirects to dashboard
// - test_login_with_invalid_credentials → shows error
// - test_logout_redirects_to_login
// - test_protected_page_redirects_unauthorized_to_login
```

### e2e/dashboard.spec.ts (регрессия S1)

```typescript
// Тесты:
// - test_dashboard_renders_strategy_table
// - test_sidebar_navigation_works
// - test_create_strategy_button_exists
```

### e2e/strategy.spec.ts (S3 — НОВОЕ)

```typescript
// Тесты:
// - test_create_new_strategy → opens strategy editor
// - test_strategy_editor_has_three_tabs (Description, Blockly, Code)
// - test_save_strategy → appears in dashboard table
// - test_edit_existing_strategy → loads saved data
// - test_delete_strategy → removed from table
```

### e2e/blockly.spec.ts (S3 — НОВОЕ)

```typescript
// Тесты:
// - test_blockly_workspace_renders
// - test_drag_indicator_block_to_workspace
// - test_connect_condition_to_signal
// - test_generated_code_tab_shows_python
// - test_mode_b_modal_opens_and_copies_template
```

## 3. Ручное тестирование (чеклист)

### Функционал S3 (новый)

- [ ] Создание стратегии: описание сохраняется
- [ ] Blockly: блоки индикаторов (SMA, EMA, RSI, MACD, BB) доступны
- [ ] Blockly: блоки условий (пересечение, больше/меньше) работают
- [ ] Blockly: блоки сигналов (вход/выход) работают
- [ ] Blockly: блок тайм-фильтра работает
- [ ] Code Generator: блочная схема → Python-код
- [ ] Template Parser (режим B): текст → блочная схема
- [ ] Code Sandbox: вредоносный код блокируется
- [ ] CSRF: запросы без CSRF-токена отклоняются
- [ ] Rate Limiting: > 100 запросов/мин → 429

### Регрессия S1-S2

- [ ] Авторизация: логин, refresh, брутфорс-защита
- [ ] Дашборд: таблица стратегий отображается
- [ ] Графики: исторические данные загружаются
- [ ] Брокер: подключение, баланс
- [ ] Health endpoint: 200

## 4. Верификация финансовых расчётов

- [ ] Размер лота рассчитывается корректно (округление вниз)
- [ ] Цены хранятся в Numeric, не Float

## 5. Тестирование безопасности (базовое)

- [ ] CSRF-токен обязателен для мутирующих запросов (POST, PUT, DELETE)
- [ ] Rate limiting срабатывает при превышении лимита
- [ ] Code Sandbox: `import os`, `open()`, `eval()` — блокируются
- [ ] Auth: нельзя получить данные другого пользователя (если будет multi-user)

# Формат отчёта

```markdown
## QA-отчёт: Спринт 3

### Автоматические тесты

| Категория | Всего | Passed | Failed |
|-----------|-------|--------|--------|
| Backend unit | X | Y | Z |
| Frontend unit | X | Y | Z |
| E2E (Playwright) | X | Y | Z |

### Найденные баги

| # | Критичность | Описание | Воспроизведение | Ожидание |
|---|-------------|----------|-----------------|----------|
| 1 | CRITICAL/MAJOR/MINOR | ... | Шаги... | Что должно быть |

### Регрессия

| Модуль | Статус |
|--------|--------|
| Авторизация (S1) | OK / FAIL |
| Дашборд (S1) | OK / FAIL |
| Графики (S2) | OK / FAIL |
| Брокер (S2) | OK / FAIL |

### Вердикт

- `QA APPROVED` — можно передавать заказчику
- `QA BLOCKED` — есть CRITICAL баги, нужны фиксы
```

# Важно

- **Запускай тесты сам** — не верь отчётам разработчиков
- E2E-тесты пиши так, чтобы они были **переиспользуемы** в следующих спринтах (регрессия)
- При обнаружении бага — описывай шаги воспроизведения чётко
- Финансовые расчёты проверяй с точностью до копейки
