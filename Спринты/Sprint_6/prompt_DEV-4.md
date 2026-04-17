---
sprint: S6
agent: DEV-4
role: "Frontend (FRONT2) — Notification Center + Trading Panel fixes"
wave: 2
depends_on: [DEV-1]
---

# Роль

Ты — Frontend-разработчик (senior), специалист по React + Mantine. Твоя задача — реализовать:

1. **Notification Center** — колокольчик в навигации с счётчиком, выдвижная панель с лентой уведомлений, критические баннеры.
2. **Страница настроек уведомлений** — управление каналами (telegram, email, in-app) по типам событий.
3. **Trading Panel fixes** — доработки по результатам QA Sprint_5_Review (если есть).

Работаешь в `Develop/frontend/`.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Окружение: Node >= 18, pnpm
2. Зависимости DEV-1 (волна 1): REST API /api/v1/notifications/* + WS канал notifications:{user_id} готовы
3. Существующие файлы:
   - src/main.tsx              — Mantine Notifications уже подключён (position="top-right", autoClose=5000)
   - src/hooks/useWebSocket.ts — singleton WS, каналы market/trades/backtest/health/notifications
   - src/stores/              — Zustand stores (tradingStore, authStore, uiStore, etc.)
   - src/api/types.ts          — TypeScript типы (НЕТ Notification типа)
   - src/components/layout/sidebarItems.ts — { label: 'Уведомления', icon: IconBell, path: '/notifications' } — уже есть, но маршрут НЕ создан
   - src/App.tsx               — роутер, /notifications НЕ зарегистрирован
4. Пакеты: @mantine/core@7.8, @mantine/notifications@7.8, @tabler/icons-react@3.1, zustand@4.5
5. Тесты baseline: `pnpm test` → 0 failures
```

# ⚠️ Обязательное чтение (BEFORE any code)

1. **`Develop/CLAUDE.md`** — полностью. Особенно: frontend conventions (Mantine dark theme, русский интерфейс, формат чисел `1 234 567,89 ₽`).

2. **`Develop/stack_gotchas/INDEX.md`** — особенно:
   - **Gotcha 9** (`gotcha-09-playwright-strict.md`) — Playwright strict mode. Используй `data-testid` для кнопок, не `getByRole`.
   - **Gotcha 16** (`gotcha-16-relogin-race.md`) — 401 race после logout→login. Не кешируй `user_id` в closure.

3. **`Спринты/Sprint_6/execution_order.md`** раздел **«Cross-DEV contracts»**:
   - Ты **потребитель** контрактов от DEV-1:
     - REST API `/api/v1/notifications/*` (GET, PATCH, PUT)
     - WS канал `notifications:{user_id}` (event: `notification.new`)
     - Notification schemas: `NotificationResponse(id, event_type, title, body, severity, is_read, created_at)`

4. **Цитаты из ТЗ / ФТ:**

   > **ФТ 10.2 In-app notifications (дословно):**
   > «Иконка колокольчика в навигационной панели с счётчиком непрочитанных. Лента событий (выдвижная панель): событие, время, инструмент, краткое описание. Критические события (circuit breaker, потеря связи) — красный баннер на весь экран с dismiss-кнопкой.»

   > **ФТ 10.1 Таблица каналов — event_type (для настроек):**
   > trade_opened, trade_closed, partial_fill, cb_triggered, price_alert, connection_lost, connection_restored, all_positions_closed, daily_stats, backtest_completed, order_error, session_recovered, fund_skip, corporate_action.

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

```
- src/main.tsx                        — Mantine Notifications уже подключены. НЕ дублировать <Notifications/>.
- src/hooks/useWebSocket.ts           — useWebSocket(channel, callback). Каналы: market, trades, backtest, health, notifications. Сообщения: {channel, event, data}. Переиспользуй для notifications:{user_id}.
- src/stores/tradingStore.ts          — Zustand store с WS-update методами. Паттерн для notificationStore.
- src/stores/authStore.ts             — user: {id, username, email}. Для получения user_id.
- src/api/types.ts                    — Типы. ДОБАВИШЬ Notification, NotificationSetting.
- src/components/layout/Sidebar.tsx   — Sidebar с навигацией. sidebarItems.ts — пункт «Уведомления» уже есть.
- src/components/layout/Header.tsx    — Header (если есть). Колокольчик добавляется ЗДЕСЬ.
- src/App.tsx                         — Роутер. Добавишь маршрут /notifications.
- src/components/trading/SessionDashboard.tsx — Слушает trades:{sessionId}. Паттерн для notification WS.
```

# Задачи

## Задача 4.1: TypeScript типы

В `src/api/types.ts` добавь:

```typescript
// Notifications
export interface Notification {
  id: number;
  event_type: string;
  title: string;
  body: string | null;
  severity: 'info' | 'success' | 'warning' | 'critical';
  is_read: boolean;
  created_at: string;  // ISO datetime
  related_entity_type: string | null;
  related_entity_id: number | null;
}

export interface NotificationSetting {
  event_type: string;
  telegram_enabled: boolean;
  email_enabled: boolean;
  in_app_enabled: boolean;
}

export interface UnreadCount {
  count: number;
}
```

## Задача 4.2: Notification Store (Zustand)

Создай `src/stores/notificationStore.ts`:

```typescript
import { create } from 'zustand';
import type { Notification, NotificationSetting } from '../api/types';

interface NotificationState {
  notifications: Notification[];
  unreadCount: number;
  settings: NotificationSetting[];
  isDrawerOpen: boolean;
  
  // Actions
  fetchNotifications: (offset?: number, limit?: number) => Promise<void>;
  fetchUnreadCount: () => Promise<void>;
  fetchSettings: () => Promise<void>;
  markAsRead: (id: number) => Promise<void>;
  markAllRead: () => Promise<void>;
  updateSetting: (eventType: string, patch: Partial<NotificationSetting>) => Promise<void>;
  addFromWS: (notification: Notification) => void;  // real-time push
  toggleDrawer: () => void;
}
```

**API вызовы** (через `api/client.ts` с interceptors):
- `GET /api/v1/notifications?offset=0&limit=50` → `notifications`
- `GET /api/v1/notifications/unread-count` → `unreadCount`
- `GET /api/v1/notifications/settings` → `settings`
- `PATCH /api/v1/notifications/{id}/read`
- `PUT /api/v1/notifications/read-all`
- `PUT /api/v1/notifications/settings/{event_type}`

## Задача 4.3: Компонент NotificationBell (колокольчик)

Создай `src/components/notifications/NotificationBell.tsx`:

```tsx
/**
 * Колокольчик в Header с badge-счётчиком непрочитанных.
 * 
 * Поведение:
 * - Badge с числом (красный, если > 0). Если > 99 → "99+".
 * - Клик → toggleDrawer() в notificationStore.
 * - При монтировании → fetchUnreadCount().
 * - WS подписка: useWebSocket(`notifications`, (msg) => {
 *     if (msg.event === "notification.new") {
 *       store.addFromWS(msg.data);
 *       // Показать toast через Mantine notifications.show()
 *     }
 *   })
 * 
 * data-testid="notification-bell"
 */
```

**Место вставки:** в Header/Sidebar рядом с аватаром пользователя. Найди существующий компонент навигации и добавь туда.

## Задача 4.4: Компонент NotificationDrawer (выдвижная панель)

Создай `src/components/notifications/NotificationDrawer.tsx`:

```tsx
/**
 * Выдвижная панель справа (Mantine Drawer).
 * 
 * Содержит:
 * - Заголовок: "Уведомления" + кнопка "Прочитать все"
 * - Список уведомлений (виртуализированный если > 50):
 *   - Иконка severity (info→ℹ️, success→✅, warning→⚠️, critical→🚨)
 *   - Title (жирный)
 *   - Body (серый текст)
 *   - Время (relative: "2 мин. назад", "вчера 14:30")
 *   - Непрочитанные — с цветной полоской слева (синяя)
 *   - Клик → markAsRead() + навигация к related_entity
 * - Пагинация: "Загрузить ещё" внизу (offset-based)
 * - Пустое состояние: "Нет уведомлений"
 * 
 * data-testid="notification-drawer"
 */
```

## Задача 4.5: Критические баннеры

Создай `src/components/notifications/CriticalBanner.tsx`:

```tsx
/**
 * Красный баннер на весь экран для критических событий.
 * 
 * Показывается при severity === "critical":
 * - cb_triggered (Circuit Breaker сработал)
 * - connection_lost (потеря соединения с брокером)
 * 
 * Дизайн:
 * - Fixed position, top: 0, z-index: 1000
 * - Красный фон, белый текст
 * - Иконка 🚨 + title + body
 * - Кнопка dismiss (×) справа
 * - Автоскрытие через 30 секунд (для critical)
 * 
 * Монтируется в App.tsx (глобально), слушает notificationStore.
 * data-testid="critical-banner"
 */
```

## Задача 4.6: Страница настроек уведомлений

Создай `src/pages/NotificationSettingsPage.tsx` (или секция в существующих Settings):

```tsx
/**
 * Таблица настроек: event_type × канал (Telegram, Email, In-app).
 * 
 * Каждая строка — event_type с переключателями (Switch).
 * Columns: Событие | Telegram | Email | In-app
 * 
 * Event types (русские названия):
 * - trade_opened → "Открытие сделки"
 * - trade_closed → "Закрытие сделки"
 * - cb_triggered → "Circuit Breaker"
 * - connection_lost → "Потеря соединения"
 * - daily_stats → "Дневная статистика"
 * - session_recovered → "Восстановление сессии"
 * - order_placed → "Ордер выставлен"
 * - ... (все из ФТ 10.1)
 * 
 * Привязка Telegram:
 * - Если TelegramLink нет → кнопка "Привязать Telegram" → модал с QR/токеном
 * - Если привязан → бэдж "✅ Привязан" + кнопка "Отвязать"
 * 
 * data-testid="notification-settings"
 */
```

## Задача 4.7: Маршрут /notifications + интеграция

В `src/App.tsx`:
```tsx
<Route path="/notifications" element={<ProtectedRoute><NotificationsPage /></ProtectedRoute>} />
```

`NotificationsPage` — полностраничный вид с лентой уведомлений + настройками (два таба или две секции).

## Задача 4.8: Trading Panel fixes (если есть)

Проверь `Sprint_5_Review/arch_review_s5r.md` раздел 8 (рекомендации для S6) — есть ли замечания по Trading Panel. Если есть — исправь. Если нет — явно укажи в отчёте: «SKIP — нет замечаний по Trading Panel из S5R ARCH-ревью».

# Тесты

```
src/__tests__/
├── notificationStore.test.ts     # fetchNotifications, addFromWS, markAsRead, toggleDrawer
└── NotificationBell.test.tsx     # render, badge count, click → drawer open

e2e/ (Playwright, опционально)
└── s6-notifications.spec.ts      # Bell click → drawer, mock notifications list
```

**Минимум:** 6 тестов (vitest):
- 3 на notificationStore (fetch, addFromWS, markAsRead)
- 2 на NotificationBell (render with count, click opens drawer)
- 1 на CriticalBanner (render on critical event)

# ⚠️ Integration Verification Checklist

- [ ] `grep -rn "notificationStore" src/` — store используется в Bell, Drawer, Banner, Settings
- [ ] `grep -rn "useWebSocket.*notifications" src/` — WS подписка в Bell или App-уровне
- [ ] `grep -rn "/notifications" src/App.tsx` — маршрут зарегистрирован
- [ ] `grep -rn "notification-bell" src/` — data-testid присутствует
- [ ] `grep -rn "notification-drawer" src/` — data-testid присутствует
- [ ] `grep -rn "critical-banner" src/` — data-testid присутствует
- [ ] `pnpm tsc --noEmit` → 0 errors
- [ ] `pnpm lint` → 0 errors (warnings допустимы)

# ⚠️ Формат отчёта (МАНДАТНЫЙ)

Верни структурированную сводку **до 400 слов** с 8 секциями по шаблону `Спринты/prompt_template.md`.
Сохрани отчёт как файл: `Спринты/Sprint_6/reports/DEV-4_report.md`.

# Чеклист перед сдачей

- [ ] Все задачи 4.1–4.8 реализованы (4.8 — PASS или SKIP + reason)
- [ ] `pnpm lint` → 0 errors
- [ ] `pnpm tsc --noEmit` → 0 errors
- [ ] `pnpm test` → 0 failures
- [ ] **Integration verification checklist полностью пройден**
- [ ] **Формат отчёта соблюдён** — все 8 секций заполнены
- [ ] **Отчёт сохранён** в `Спринты/Sprint_6/reports/DEV-4_report.md`
- [ ] **Cross-DEV contracts подтверждены:** использую REST API и WS от DEV-1
- [ ] Колокольчик + drawer + критические баннеры работают
- [ ] Настройки уведомлений — таблица event_type × канал
- [ ] Русский интерфейс, Mantine dark theme, формат чисел `1 234 567,89 ₽`
