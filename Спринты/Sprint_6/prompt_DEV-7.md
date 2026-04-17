---
sprint: S6
agent: DEV-7
role: "QA + Security — E2E тесты S6 + Security Testing"
wave: 3
depends_on: [DEV-4, DEV-5, DEV-6]
---

# Роль

Ты — QA-инженер + Security-специалист (senior). Твоя задача:

1. **E2E тесты S6** — написать и прогнать Playwright-тесты на новый функционал Sprint 6 (уведомления, Notification Center, Telegram mock, Recovery, Graceful Shutdown).
2. **Security-тестирование** — CSRF, rate limiting, sandbox escape, auth brute-force, notification injection.

Работаешь в `Develop/frontend/e2e/` (E2E) и `Develop/backend/tests/` (Security).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Node >= 18, pnpm, Playwright, Python >= 3.11
2. Зависимости волны 2: DEV-4 (Notification Center), DEV-5 (Stream Multiplex), DEV-6 (E2E infra) смержены
3. Текущий baseline:
   - npx playwright test --reporter=list 2>&1 | tail -5 → X passed / Y failed / Z skipped
   - pytest tests/ 2>&1 | tail -5 → X passed / Y failed
4. Существующие E2E фикстуры:
   - e2e/fixtures/api_mocks.ts        — полный набор (после DEV-6)
   - e2e/fixtures/moex_iss_mock.ts    — моки ISS (после DEV-6)
5. Backend endpoints (после DEV-1):
   - GET /api/v1/notifications
   - GET /api/v1/notifications/unread-count
   - PATCH /api/v1/notifications/{id}/read
   - PUT /api/v1/notifications/read-all
   - GET/PUT /api/v1/notifications/settings/*
   - POST /api/v1/notifications/telegram/link-token
   - POST /api/v1/notifications/telegram/webhook
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью.

2. **`Develop/stack_gotchas/INDEX.md`** — особенно:
   - **Gotcha 9** (`gotcha-09-playwright-strict.md`) — `data-testid` для элементов.
   - **Gotcha 10** (`gotcha-10-moex-e2e-session.md`) — E2E vs MOEX live data.

3. **`Спринты/Sprint_6/execution_order.md`** — понять полную картину S6.

4. **Цитаты из ТЗ / ФТ:**

   > **ФТ 10.2 In-app notifications (для E2E):**
   > «Иконка колокольчика с счётчиком непрочитанных. Лента событий (выдвижная панель). Критические события — красный баннер.»

   > **ТЗ 8.3 Security Requirements (для security-тестов):**
   > «CSRF: SameSite=Strict + X-CSRF-Token для POST/PUT/DELETE. Rate limiting: 100 req/min на auth endpoints, 1000 req/min общий. Sandbox: RestrictedPython с запретом __import__, exec, eval, open, os, sys. Auth: JWT с blacklist, brute-force protection (5 попыток, 15 минут lockout).»

# Рабочая директория

`Test/Develop/frontend/` (E2E) + `Test/Develop/backend/` (Security)

# Контекст существующего кода

```
- e2e/fixtures/api_mocks.ts       — Полный набор моков (после DEV-6)
- e2e/*.spec.ts                    — Существующие E2E тесты
- backend/app/auth/router.py       — Login endpoint с rate limiting
- backend/app/sandbox/executor.py  — RestrictedPython sandbox
- backend/app/common/csrf.py       — CSRF middleware (если есть)
- backend/tests/                   — Существующие тесты
```

# Задачи

## Задача 7.1: E2E — Notification Bell + Drawer

Создай `e2e/s6-notifications.spec.ts`:

```typescript
import { test, expect } from '@playwright/test';
import { injectFakeAuth, mockDefaultEmptyApis } from './fixtures/api_mocks';

test.describe('S6: Notification Center', () => {
  test.beforeEach(async ({ page }) => {
    await injectFakeAuth(page);
    await mockDefaultEmptyApis(page);
    // Mock notifications endpoint
    await page.route('**/api/v1/notifications?*', async route => {
      await route.fulfill({
        status: 200,
        body: JSON.stringify([
          {
            id: 1, event_type: 'trade_filled', title: 'Сделка исполнена',
            body: 'SBER: покупка по 265.30 ₽', severity: 'success',
            is_read: false, created_at: new Date().toISOString(),
            related_entity_type: 'session', related_entity_id: 1,
          },
          {
            id: 2, event_type: 'cb_triggered', title: 'Circuit Breaker',
            body: 'Превышен дневной лимит убытков', severity: 'critical',
            is_read: false, created_at: new Date().toISOString(),
            related_entity_type: null, related_entity_id: null,
          },
        ]),
      });
    });
    await page.route('**/api/v1/notifications/unread-count', async route => {
      await route.fulfill({ status: 200, body: JSON.stringify({ count: 2 }) });
    });
  });

  test('колокольчик показывает счётчик непрочитанных', async ({ page }) => {
    await page.goto('/');
    const bell = page.getByTestId('notification-bell');
    await expect(bell).toBeVisible();
    await expect(bell).toContainText('2');
  });

  test('клик по колокольчику открывает drawer', async ({ page }) => {
    await page.goto('/');
    await page.getByTestId('notification-bell').click();
    const drawer = page.getByTestId('notification-drawer');
    await expect(drawer).toBeVisible();
    await expect(drawer).toContainText('Сделка исполнена');
    await expect(drawer).toContainText('Circuit Breaker');
  });

  test('клик по уведомлению помечает как прочитанное', async ({ page }) => {
    let markReadCalled = false;
    await page.route('**/api/v1/notifications/1/read', async route => {
      markReadCalled = true;
      await route.fulfill({ status: 200, body: '{}' });
    });
    await page.goto('/');
    await page.getByTestId('notification-bell').click();
    // Клик по первому уведомлению
    await page.getByText('Сделка исполнена').click();
    expect(markReadCalled).toBe(true);
  });

  test('"Прочитать все" помечает все уведомления', async ({ page }) => {
    let readAllCalled = false;
    await page.route('**/api/v1/notifications/read-all', async route => {
      readAllCalled = true;
      await route.fulfill({ status: 200, body: '{}' });
    });
    await page.goto('/');
    await page.getByTestId('notification-bell').click();
    await page.getByText('Прочитать все').click();
    expect(readAllCalled).toBe(true);
  });
});
```

## Задача 7.2: E2E — Critical Banner

```typescript
test.describe('S6: Critical Banner', () => {
  test('критическое уведомление показывает красный баннер', async ({ page }) => {
    // ... mock WS или inject критическое уведомление
    // Проверить: data-testid="critical-banner" visible
    // Проверить: красный фон, текст "Circuit Breaker"
    // Клик dismiss → баннер скрывается
  });
});
```

## Задача 7.3: E2E — Notification Settings

```typescript
test.describe('S6: Notification Settings', () => {
  test('страница настроек отображает таблицу каналов', async ({ page }) => {
    // Mock GET /notifications/settings
    // Goto /notifications или /settings
    // Проверить: таблица с event_type × канал
    // Проверить: переключатели Telegram/Email/In-app
  });

  test('переключение канала вызывает PUT', async ({ page }) => {
    // Mock PUT /notifications/settings/{event_type}
    // Toggle Telegram switch
    // Verify PUT called with correct body
  });
});
```

## Задача 7.4: Security — CSRF Protection

В `backend/tests/test_security/test_csrf.py`:

```python
async def test_post_without_csrf_token_rejected():
    """POST/PUT/DELETE без CSRF-токена → 403."""

async def test_post_with_valid_csrf_token_accepted():
    """POST с валидным CSRF-токеном → 200."""

async def test_csrf_token_rotation():
    """CSRF-токен меняется при каждом запросе."""
```

## Задача 7.5: Security — Rate Limiting

```python
async def test_auth_rate_limit():
    """> 5 неудачных логинов → 429 Too Many Requests."""

async def test_auth_lockout_duration():
    """После lockout → ждём 15 минут → логин снова работает."""

async def test_general_rate_limit():
    """> 1000 req/min на обычные endpoints → 429."""
```

## Задача 7.6: Security — Sandbox Escape

```python
async def test_sandbox_rejects_import():
    """compile_restricted с __import__ → SyntaxError."""

async def test_sandbox_rejects_exec():
    """compile_restricted с exec() → SyntaxError."""

async def test_sandbox_rejects_os_access():
    """compile_restricted с os.system → SyntaxError."""

async def test_sandbox_rejects_file_access():
    """compile_restricted с open() → SyntaxError."""

async def test_sandbox_rejects_underscore_attrs():
    """compile_restricted с self._private → SyntaxError (DEV-0 fix)."""
```

## Задача 7.7: Security — Notification Injection

```python
async def test_notification_xss_prevention():
    """HTML в title/body экранируется, не исполняется."""

async def test_notification_access_control():
    """User A не может читать уведомления User B."""

async def test_telegram_webhook_secret_validation():
    """Webhook без X-Telegram-Bot-Api-Secret-Token → 401/403."""
```

# Тесты

```
frontend/e2e/
├── s6-notifications.spec.ts      # 4+ тестов: bell, drawer, mark-read, read-all
├── s6-critical-banner.spec.ts    # 1+ тест: баннер для critical events
└── s6-notification-settings.spec.ts  # 2+ тестов: таблица, toggle

backend/tests/test_security/
├── test_csrf.py                  # 3 теста
├── test_rate_limiting.py         # 3 теста
├── test_sandbox_escape.py        # 5 тестов
└── test_notification_security.py # 3 тестов
```

**Минимум:** 7 E2E + 14 security = 21 тест.

# ⚠️ Integration Verification Checklist

- [ ] `npx playwright test s6-*.spec.ts` → 0 failures
- [ ] `pytest tests/test_security/ -v` → 0 failures
- [ ] Все E2E используют `data-testid` (Gotcha 9)
- [ ] E2E не зависят от живых данных MOEX (моки)
- [ ] Security тесты покрывают: CSRF, rate limiting, sandbox, notification ACL

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.
Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-7_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 7.1–7.7 реализованы
- [ ] `npx playwright test` → 0 failures на новых S6 тестах
- [ ] `pytest tests/test_security/` → 0 failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-7_report.md`
- [ ] E2E покрывают: колокольчик, drawer, mark-read, critical banner, settings
- [ ] Security покрывает: CSRF, rate limit, sandbox escape, notification ACL, webhook auth
