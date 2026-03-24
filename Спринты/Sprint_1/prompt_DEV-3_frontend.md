---
sprint: 1
agent: DEV-3
role: Frontend (FRONT1 + FRONT2)
wave: 2 (после утверждения UX)
depends_on: [UX утверждённая ui_spec.md]
---

# Роль

Ты — Frontend-разработчик. Инициализируй React-приложение и создай shell layout по утверждённой UI-спецификации.

# Рабочая директория

`Test/Develop/frontend/`

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы **обязательно** проверь:

```
1. Файл Test/Спринты/Sprint_1/ui_spec.md СУЩЕСТВУЕТ
2. Файл НЕ ПУСТОЙ и содержит утверждённую UI-спецификацию
3. Node.js >= 18 установлен (node --version)
4. pnpm >= 9 установлен (pnpm --version)
```

**Если `ui_spec.md` не найден или пуст — НЕМЕДЛЕННО ОСТАНОВИ работу** и сообщи:
"БЛОКЕР: ui_spec.md отсутствует. DEV-3 не может начать работу без утверждённой UI-спецификации."

Не начинай писать код, не используй fallback-значения — дождись файла.

# Контекст

UI-спецификация находится в файле `Test/Спринты/Sprint_1/ui_spec.md`. Реализуй layout **строго по этой спецификации** — компоненты, размеры, цвета, поведение.

# Задачи

## 1. Инициализация проекта

```bash
pnpm create vite frontend --template react-ts
cd frontend
pnpm add @mantine/core@^7.8 @mantine/hooks@^7.8 @mantine/notifications@^7.8 @mantine/dates@^7.8
pnpm add @tabler/icons-react@^3.1
pnpm add zustand@^4.5
pnpm add react-router-dom@^6.22
pnpm add axios@^1.7
pnpm add -D @types/react @types/react-dom
```

## 2. Структура проекта

```
src/
├── main.tsx                    # Entry point, MantineProvider
├── App.tsx                     # Router setup
├── api/
│   ├── client.ts               # Axios instance с JWT interceptor
│   └── types.ts                # Общие TypeScript типы
├── stores/
│   ├── authStore.ts            # Zustand: user, tokens, login/logout
│   └── uiStore.ts              # Zustand: sidebar collapsed, theme
├── hooks/
│   └── useAuth.ts              # Хук авторизации
├── components/
│   ├── layout/
│   │   ├── AppShell.tsx        # Mantine AppShell wrapper
│   │   ├── Sidebar.tsx         # Навигация (по ui_spec.md)
│   │   └── Header.tsx          # Header (по ui_spec.md)
│   └── dashboard/
│       └── StrategyTable.tsx   # Таблица стратегий (заглушка с моковыми данными)
├── pages/
│   ├── DashboardPage.tsx       # Главная — дашборд
│   ├── LoginPage.tsx           # Авторизация
│   └── NotFoundPage.tsx        # 404
└── utils/
    └── formatters.ts           # Форматирование чисел (1 234 567,89 ₽), дат (ДД.ММ.ГГГГ)
```

## 3. MantineProvider (main.tsx)

```tsx
// Dark theme обязательно
// Цветовая схема (primaryColor определяется в ui_spec.md от UX):
//   Кастомные цвета для статусов:
//     paper: yellow (#FAB005 / Mantine yellow)
//     real: red (#FA5252 / Mantine red)
//     profit: green (#40C057 / Mantine green)
//     loss: red (#FA5252 / Mantine red)
// Русская локализация дат (dayjs)
// ВАЖНО: primaryColor берётся из ui_spec.md, НЕ выбирай самостоятельно
```

## 4. Routing (App.tsx)

```
/           → DashboardPage (защищённый)
/login      → LoginPage (публичный)
*           → NotFoundPage
```

Защищённые маршруты проверяют наличие токена в authStore.

## 5. AppShell + Sidebar + Header

Реализуй **строго по ui_spec.md**. Если ui_spec.md ещё не создан, используй эти defaults:
- Mantine `AppShell` с `navbar` и `header`
- Sidebar: `AppShell.Navbar`, `NavLink` с иконками Tabler
- Header: `AppShell.Header`, логотип слева, иконки справа
- Dark theme

## 6. StrategyTable (заглушка)

Таблица с моковыми данными (5-7 строк), отображающая:
- Название стратегии
- Статус (Badge с цветом по ui_spec)
- Инструменты
- Последний бэктест (дата + PF + DD)
- Режим (Paper/Real + P&L)

Использовать Mantine `Table` или TanStack Table.

## 7. LoginPage (заглушка)

Форма логин + пароль (Mantine `TextInput`, `PasswordInput`, `Button`). При сабмите — заглушка (сохраняет мок-токен в authStore).

## 8. API Client (api/client.ts)

```typescript
// Axios instance:
// - baseURL: "http://localhost:8000/api/v1"
// - Request interceptor: добавляет Authorization: Bearer {token}
// - Response interceptor: при 401 — redirect на /login
```

## 9. Форматирование (utils/formatters.ts)

```typescript
// formatCurrency(value: number): string → "1 234 567,89 ₽"
// formatPercent(value: number): string → "12,45%"
// formatDate(date: Date | string): string → "24.03.2026"
// formatDateTime(date: Date | string): string → "24.03.2026 15:30"
```

# Конвенции

- TypeScript strict mode
- Функциональные компоненты
- Все тексты интерфейса на русском языке
- Mantine компоненты — не кастомный CSS (кроме мелких доработок)
- Zustand stores: каждый в отдельном файле

## 10. Тесты

Ты отвечаешь за тестирование своего кода. Создай тесты.

### Установка тестовых зависимостей

```bash
pnpm add -D vitest @testing-library/react @testing-library/jest-dom jsdom
```

Добавь в `vite.config.ts`:
```typescript
/// <reference types="vitest" />
// test: { globals: true, environment: 'jsdom', setupFiles: './src/test/setup.ts' }
```

### src/test/setup.ts

```typescript
import '@testing-library/jest-dom';
```

### src/utils/__tests__/formatters.test.ts

```typescript
// Тесты:
// - test formatCurrency(1234567.89) → "1 234 567,89 ₽"
// - test formatCurrency(0) → "0,00 ₽"
// - test formatCurrency(-500.5) → "-500,50 ₽"
// - test formatPercent(12.45) → "12,45%"
// - test formatPercent(0) → "0,00%"
// - test formatDate("2026-03-24") → "24.03.2026"
// - test formatDateTime("2026-03-24T15:30:00") → "24.03.2026 15:30"
```

### src/stores/__tests__/authStore.test.ts

```typescript
// Тесты:
// - test initial state: user is null, token is null
// - test login sets token and user
// - test logout clears token and user
// - test isAuthenticated returns true when token exists
```

### src/components/layout/__tests__/Sidebar.test.tsx

```typescript
// Тесты:
// - test sidebar renders all navigation items
// - test navigation items have correct labels (Стратегии, Бэктесты, etc.)
```

**Запусти тесты:**
```bash
pnpm test
```

Добавь скрипт в `package.json`:
```json
{ "scripts": { "test": "vitest run", "test:watch": "vitest" } }
```

# Конвенции

- TypeScript strict mode
- Функциональные компоненты
- Все тексты интерфейса на русском языке
- Mantine компоненты — не кастомный CSS (кроме мелких доработок)
- Zustand stores: каждый в отдельном файле

# Критерий завершения

- `pnpm dev` запускается, открывается http://localhost:5173
- Dark theme работает
- Sidebar с навигацией отображается (по ui_spec.md)
- Header с элементами отображается (по ui_spec.md)
- Дашборд с моковой таблицей стратегий работает
- Страница логина отображается
- Routing работает (/, /login, 404)
- Форматирование: числа и даты в русском формате
- **Все тесты проходят: `pnpm test` — 0 failures**
- **Тесты покрывают: форматирование ru-RU, authStore, навигация в Sidebar**
