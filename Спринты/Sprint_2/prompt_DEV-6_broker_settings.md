---
sprint: 2
agent: DEV-6
role: Frontend #2 (FRONT2) — Broker Settings
wave: 3
depends_on: [UX (ui_spec_s2.md), DEV-3 (crypto), DEV-4 (market data)]
---

# Роль

Ты — Frontend-разработчик #2. Реализуй экран настроек брокера: добавление, просмотр и удаление брокерских аккаунтов.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node >= 18 (node --version)
2. pnpm >= 9 (pnpm --version)
3. Файл Sprint_2/ui_spec_s2.md существует и утверждён
4. Backend endpoints работают:
   - POST /api/v1/broker-accounts
   - GET  /api/v1/broker-accounts
   - GET  /api/v1/broker-accounts/{id}
   - PATCH /api/v1/broker-accounts/{id}
   - DELETE /api/v1/broker-accounts/{id}
   - POST /api/v1/broker-accounts/discover
5. pnpm test проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-6 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

## App.tsx — Роутинг

```typescript
// Нужно добавить маршрут для настроек:
// <Route path="settings" element={<SettingsPage />} />
// или
// <Route path="settings/broker" element={<BrokerSettingsPage />} />
```

## Sidebar

```typescript
// Уже есть пункт "Настройки" (IconSettings, path: '/settings')
// — нужно создать страницу, на которую он ведёт
```

## API client

```typescript
// api/client.ts — Axios с JWT interceptors
```

# Задачи

## 1. Broker API Client (`src/api/brokerApi.ts`)

```typescript
import apiClient from './client';

export interface BrokerAccountCreate {
  broker_type: string;
  name: string;
  api_key: string;
  api_secret?: string;
}

export interface BrokerAccountUpdate {
  name?: string;
  is_active?: boolean;
}

export interface BrokerAccountResponse {
  id: number;
  broker_type: string;
  name: string;
  account_id: string | null;
  account_type: string | null;  // "broker" | "iis"
  is_active: boolean;
  balance?: number;
  currency?: string;
}

export interface DiscoveredAccount {
  account_id: string;
  name: string;
  type: string;
  status: string;
}

export const brokerApi = {
  createAccount: (data: BrokerAccountCreate) =>
    apiClient.post<BrokerAccountResponse>('/broker-accounts', data),

  getAccounts: () =>
    apiClient.get<BrokerAccountResponse[]>('/broker-accounts'),

  getAccount: (id: number) =>
    apiClient.get<BrokerAccountResponse>(`/broker-accounts/${id}`),

  updateAccount: (id: number, data: BrokerAccountUpdate) =>
    apiClient.patch<BrokerAccountResponse>(`/broker-accounts/${id}`, data),

  deleteAccount: (id: number) =>
    apiClient.delete(`/broker-accounts/${id}`),

  discoverAccounts: (data: { broker_type: string; api_key: string; api_secret?: string }) =>
    apiClient.post<DiscoveredAccount[]>('/broker-accounts/discover', data),
};
```

## 2. Settings Store (`src/stores/settingsStore.ts`)

```typescript
import { create } from 'zustand';

interface SettingsState {
  brokerAccounts: BrokerAccountResponse[];
  loading: boolean;
  error: string | null;

  fetchAccounts: () => Promise<void>;
  addAccount: (data: BrokerAccountCreate) => Promise<void>;
  updateAccount: (id: number, data: BrokerAccountUpdate) => Promise<void>;
  deleteAccount: (id: number) => Promise<void>;
  discoverAccounts: (data: DiscoverRequest) => Promise<DiscoveredAccount[]>;
}
```

## 3. AddBrokerForm (`src/components/settings/AddBrokerForm.tsx`)

Форма добавления брокерского аккаунта:

```typescript
// Поля:
// - Тип брокера: Select (options: [{value: 'tinvest', label: 'T-Invest (Тинькофф)'}])
// - Название: TextInput (placeholder: "Мой брокерский счёт")
// - API-ключ: PasswordInput (с кнопкой show/hide)
// - API-секрет: PasswordInput (optional, с подсказкой "Необязательно для T-Invest")
//
// Кнопки:
// - "Обнаружить счета" (variant="outline") → POST /broker-accounts/discover
//   → показать список обнаруженных счетов (account_id, name, type)
// - "Сохранить" (variant="filled") → POST /broker-accounts
//
// Состояния:
// - Loading: кнопки disabled, Loader рядом с кнопкой
// - Success: Mantine Notification ("Аккаунт добавлен"), форма очищается
// - Error: Mantine Notification с ошибкой
//
// Валидация:
// - broker_type обязателен
// - name обязателен, 1-100 символов
// - api_key обязателен, минимум 10 символов
```

## 4. BrokerAccountList (`src/components/settings/BrokerAccountList.tsx`)

Список подключённых аккаунтов:

```typescript
// Таблица или список карточек:
//
// | Имя            | Брокер   | Тип    | Баланс        | Статус   | Действия |
// |----------------|----------|--------|---------------|----------|----------|
// | Мой брокерский | T-Invest | Брокер | 1 234 567 ₽  | Активен  | ✏️ 🗑️  |
// | ИИС            | T-Invest | ИИС    | 500 000 ₽    | Активен  | ✏️ 🗑️  |
//
// Действия:
// - Редактировать: модальное окно с TextInput (name) и Switch (is_active)
// - Удалить: модальное окно подтверждения ("Вы уверены? Это действие необратимо.")
//
// Empty state:
// - Center с IconWallet + "Нет подключённых брокеров"
// - Кнопка "Добавить брокера"
//
// Формат баланса: "1 234 567,89 ₽" (ru-RU)
//
// Mantine компоненты:
// - Table или Card для списка
// - Modal для редактирования и удаления
// - ActionIcon для кнопок действий
// - Badge для статуса (green=Активен, gray=Неактивен)
// - Switch для toggle is_active
```

## 5. BrokerSettingsPage (`src/pages/BrokerSettingsPage.tsx`)

```typescript
// Страница настроек брокера:
// - Title: "Настройки брокера"
// - Карточка: AddBrokerForm
// - Разделитель
// - Карточка: BrokerAccountList
//
// По дизайну из ui_spec_s2.md
```

## 6. SettingsPage (`src/pages/SettingsPage.tsx`)

```typescript
// Если ui_spec_s2.md определяет настройки как tabs:
// - Tabs: "Брокер" | "Профиль" (заглушка) | "Уведомления" (заглушка)
// - Вкладка "Брокер" → BrokerSettingsPage content
//
// Если ui_spec_s2.md определяет отдельную страницу:
// - Простая страница с навигацией к подразделам
```

## 7. Обновление роутинга

В App.tsx добавь маршруты:
```typescript
<Route path="settings" element={<SettingsPage />} />
// или
<Route path="settings/broker" element={<BrokerSettingsPage />} />
```

## 8. Тесты

### `src/components/settings/__tests__/AddBrokerForm.test.tsx`
- test_renders_all_fields (select, inputs, buttons)
- test_submit_button_disabled_when_empty
- test_api_key_field_is_password_type
- test_discover_button_exists

### `src/components/settings/__tests__/BrokerAccountList.test.tsx`
- test_renders_empty_state
- test_renders_accounts_list (mock data)
- test_delete_shows_confirmation
- test_balance_formatted_ru

### `src/stores/__tests__/settingsStore.test.ts`
- test_initial_state (empty accounts)
- test_fetch_accounts_updates_state
- test_loading_state

### `src/pages/__tests__/BrokerSettingsPage.test.tsx`
- test_renders_form_and_list

**Запусти тесты:**
```bash
pnpm test
```

# Конвенции

- TypeScript strict mode
- Функциональные компоненты
- Zustand для state management
- Mantine компоненты для UI
- Русский язык интерфейса
- Числа: `1 234 567,89 ₽` (ru-RU)
- Dark theme
- API-ключ в формах: PasswordInput (маскировка по умолчанию)

# Критерий завершения

- Форма добавления брокера работает (все поля, валидация, discover)
- Список аккаунтов отображается (с балансом, действиями)
- Редактирование и удаление через модальные окна
- Empty state для пустого списка
- Страница настроек доступна по роуту
- **Все тесты проходят: `pnpm test` — 0 failures**
- **~8-10 новых тестов**
