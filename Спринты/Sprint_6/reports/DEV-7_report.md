# DEV-7 Report — QA + Security (S6)

## 1. Реализовано

- **E2E тесты (Playwright):** 9 тестов в 3 файлах — Notification Bell/Drawer, Critical Banner, Notification Settings
- **Security тесты (pytest):** 23 теста в 4 файлах — CSRF, Rate Limiting, Sandbox Escape, Notification Security (XSS, ACL, webhook)
- **Итого:** 32 теста (9 E2E + 23 security), все зелёные

## 2. Файлы

| Файл | Тестов | Статус |
|------|--------|--------|
| `frontend/e2e/s6-notifications.spec.ts` | 4 | PASSED |
| `frontend/e2e/s6-critical-banner.spec.ts` | 2 | PASSED |
| `frontend/e2e/s6-notification-settings.spec.ts` | 3 | PASSED |
| `backend/tests/test_security/test_csrf.py` | 3 | PASSED |
| `backend/tests/test_security/test_rate_limiting.py` | 3 | PASSED |
| `backend/tests/test_security/test_sandbox_escape.py` | 14 (7 AST + 7 sandbox) | PASSED |
| `backend/tests/test_security/test_notification_security.py` | 3 | PASSED |

## 3. Тесты

- `npx playwright test s6-*.spec.ts` → 9 passed, 0 failed
- `pytest tests/test_security/ -v` → 23 passed, 0 failed
- `ruff check tests/test_security/` → 0 errors

## 4. Integration Points

- E2E: `injectFakeAuth` + `mockCatchAllApi` + dedicated notification mocks
- Security: httpx AsyncClient + ASGITransport для изолированных тестов middleware
- Notification ACL: полный цикл через реальный app (login → JWT → filtered GET)

## 5. Контракты

| Поставщик | Потребитель | Контракт | Статус |
|-----------|-----------|----------|--------|
| DEV-1 (notification router) | DEV-7 (security) | GET/PATCH/PUT /notification/* | Verified |
| DEV-1 (CSRF middleware) | DEV-7 (security) | CSRFMiddleware double-submit | Verified |
| DEV-1 (rate limiter) | DEV-7 (security) | RateLimitMiddleware sliding window | Verified |
| DEV-4 (NotificationBell/Drawer) | DEV-7 (E2E) | data-testid bell/drawer/banner | Verified |
| DEV-0 (sandbox executor) | DEV-7 (security) | CodeSandbox + ASTAnalyzer | Verified |

## 6. Проблемы

- **Frontend API prefix mismatch:** `notificationApi.ts` использует `/notifications` (с s), а backend зарегистрирован как `/api/v1/notification` (без s). E2E тесты это скрывают через моки, но real integration сломана. Нужен фикс в `main.py` (prefix → `/api/v1/notifications`) или в `notificationApi.ts`.
- **CriticalBanner не отображается при первой загрузке:** notifications загружаются в store только при открытии drawer, а не при наличии unread. Critical события должны загружаться автоматически.
- **Mantine Switch input hidden:** Playwright не может кликнуть `<input>` Mantine Switch (visually hidden). Решение — клик по `.mantine-Switch-track`.

## 7. Применённые Stack Gotchas

- **Gotcha 9** (Playwright strict): scoped locators через `data-testid` для избежания strict mode violation (Circuit Breaker text в banner + drawer)
- **Gotcha 10** (MOEX E2E): все тесты через API-моки, 0 зависимости от MOEX ISS

## 8. Новые Stack Gotchas (кандидаты)

- **Gotcha N+1 (Mantine Switch E2E):** `<input role="switch">` в Mantine Switch имеет `display: none` / 0-size. Playwright `getByLabel().click()` и `.locator('input').click()` падают с "not visible" / "outside viewport". Решение: кликать по `.mantine-Switch-track`.
- **Gotcha N+2 (Mantine Drawer visibility):** `data-testid` на корневом `<div>` Mantine Drawer разрешается как hidden даже когда drawer открыт. Для проверки содержимого — scope через `.mantine-Drawer-content` или проверять текст внутри drawer.
