---
sprint: 3
agent: DEV-6
role: Frontend (FRONT1 + FRONT2) — Strategy Editor + Mode B
wave: 2
depends_on: [DEV-1, DEV-2, UX]
---

# Роль

Ты — Frontend-разработчик. Реализуй страницу редактора стратегий с тремя вкладками (Description, Blockly, Code), модальное окно Mode B, список стратегий на дашборде, Zustand store и API-интеграцию.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node >= 18, pnpm >= 9
2. ui_spec_s3.md существует в Sprint_3/ — UI утверждён заказчиком
3. Blockly блоки реализованы: src/components/blockly/ содержит BlockDefinitions.ts, BlocklyToolbox.ts, BlocklyTheme.ts
4. Backend Strategy API работает: GET /api/v1/strategy возвращает 200 (с авторизацией)
5. pnpm test проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-6 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст

## Утверждённый UI

Смотри `Test/Спринты/Sprint_3/ui_spec_s3.md` — все решения по дизайну там. Следуй спецификации точно.

## Существующие Blockly-компоненты (DEV-2)

```
src/components/blockly/
├── BlockDefinitions.ts       # 20 кастомных блоков (SMA, RSI, crossover, etc.)
├── BlockGenerators.ts        # JSON-генераторы для блоков
├── BlocklyToolbox.ts         # Конфигурация toolbox с 6 категориями
├── BlocklyTheme.ts           # Тёмная тема для workspace
└── index.ts                  # Re-exports
```

## Backend API (DEV-1 + DEV-5)

```
POST   /api/v1/strategy              → создать стратегию
GET    /api/v1/strategy              → список стратегий
GET    /api/v1/strategy/{id}         → детали + versions
PUT    /api/v1/strategy/{id}         → обновить name/status
DELETE /api/v1/strategy/{id}         → удалить (204)
POST   /api/v1/strategy/{id}/versions → создать версию
GET    /api/v1/strategy/{id}/versions/{n} → получить версию
POST   /api/v1/strategy/{id}/generate-code → блоки → Python код
POST   /api/v1/strategy/parse-template     → шаблон → блоки JSON
```

## Существующие паттерны фронтенда

- **State management:** Zustand stores (`authStore.ts`, `marketDataStore.ts`, `settingsStore.ts`)
- **API client:** `src/api/client.ts` (Axios с JWT + CSRF interceptors)
- **Routing:** React Router в `App.tsx`
- **UI:** Mantine 7.8+ (dark theme), Tabler Icons
- **Pages:** `DashboardPage.tsx`, `ChartPage.tsx`, `BrokerSettingsPage.tsx`

# Задачи

## 1. API-модуль (src/api/strategyApi.ts)

```typescript
import apiClient from './client';

export interface Strategy {
  id: number;
  name: string;
  status: string;
  current_version_id: number | null;
  created_at: string;
  updated_at: string;
}

export interface StrategyVersion {
  id: number;
  version_number: number;
  text_description: string | null;
  blocks_json: string;
  generated_code: string;
  parameters_json: string | null;
  created_at: string;
}

export interface StrategyDetail extends Strategy {
  versions: StrategyVersion[];
  text_description: string | null;
}

export const strategyApi = {
  list: () => apiClient.get<{ strategies: Strategy[]; total: number }>('/strategy'),
  getById: (id: number) => apiClient.get<StrategyDetail>(`/strategy/${id}`),
  create: (data: { name: string; description?: string }) =>
    apiClient.post<Strategy>('/strategy', data),
  update: (id: number, data: { name?: string; status?: string; description?: string }) =>
    apiClient.put<Strategy>(`/strategy/${id}`, data),
  delete: (id: number) => apiClient.delete(`/strategy/${id}`),
  createVersion: (id: number, data: {
    text_description?: string;
    blocks_json: string;
    generated_code: string;
    parameters_json?: string;
  }) => apiClient.post<StrategyVersion>(`/strategy/${id}/versions`, data),
  getVersion: (id: number, versionNumber: number) =>
    apiClient.get<StrategyVersion>(`/strategy/${id}/versions/${versionNumber}`),
  generateCode: (id: number, blocksJson: object) =>
    apiClient.post<{ code: string; errors: string[] }>(`/strategy/${id}/generate-code`, { blocks_json: blocksJson }),
  parseTemplate: (templateText: string) =>
    apiClient.post<{ blocks_json: object; warnings: string[] }>('/strategy/parse-template', { template_text: templateText }),
};
```

## 2. Zustand Store (src/stores/strategyStore.ts)

```typescript
import { create } from 'zustand';
import { strategyApi, Strategy, StrategyDetail } from '../api/strategyApi';

interface StrategyState {
  strategies: Strategy[];
  currentStrategy: StrategyDetail | null;
  loading: boolean;
  error: string | null;

  // Actions
  fetchStrategies: () => Promise<void>;
  fetchStrategy: (id: number) => Promise<void>;
  createStrategy: (name: string, description?: string) => Promise<Strategy>;
  updateStrategy: (id: number, data: { name?: string; status?: string }) => Promise<void>;
  deleteStrategy: (id: number) => Promise<void>;
  saveVersion: (id: number, data: {
    text_description?: string;
    blocks_json: string;
    generated_code: string;
  }) => Promise<void>;
  generateCode: (id: number, blocksJson: object) => Promise<string>;
  parseTemplate: (templateText: string) => Promise<{ blocks_json: object; warnings: string[] }>;
  clearError: () => void;
}
```

## 3. Blockly Workspace React-компонент (src/components/strategy/BlocklyWorkspace.tsx)

```typescript
interface BlocklyWorkspaceProps {
  initialBlocksXml?: string;          // Сериализованный XML workspace
  onBlocksChange?: (blocksJson: object) => void;  // Callback при изменении
  readOnly?: boolean;
}
```

Реализация:
- Создать div-контейнер для Blockly
- Инициализировать `Blockly.inject()` с toolbox, theme из DEV-2
- Подписаться на `workspace.addChangeListener()` → при изменении вызвать генератор JSON → `onBlocksChange()`
- При unmount: `workspace.dispose()` (предотвращение утечек памяти!)
- ResizeObserver для автоматического resize
- Загрузка существующих блоков из `initialBlocksXml`
- Сериализация workspace в XML для сохранения

## 4. Страница редактора стратегии (src/pages/StrategyEditPage.tsx)

3 вкладки (Mantine Tabs):

**Вкладка «Описание»:**
- TextInput: название стратегии
- Textarea: описание
- Badge: статус (draft/tested/paper/live/paused/archived)
- Кнопка «Режим B» → открывает TemplateModeModal
- Кнопка «Сохранить»

**Вкладка «Редактор» (Blockly):**
- `<BlocklyWorkspace />` — занимает всё доступное пространство
- Toolbar: Zoom In/Out, Undo/Redo, Clear
- При изменении блоков → автоматическая генерация кода через API

**Вкладка «Код»:**
- Read-only отображение сгенерированного Python-кода
- Мононоширинный шрифт, тёмный фон
- Кнопка «Скопировать код»
- Кнопка «Запустить бэктест» (disabled, активируется в S4)

**Общее:**
- Заголовок: «← Назад к списку» + название стратегии + Badge статуса
- Автосохранение: при уходе со страницы предупредить о несохранённых изменениях
- URL: `/strategies/:id`
- Создание новой: `/strategies/new`

## 5. Модальное окно Mode B (src/components/strategy/TemplateModeModal.tsx)

```typescript
interface TemplateModeModalProps {
  opened: boolean;
  onClose: () => void;
  onApply: (blocksJson: object) => void;  // Callback с распарсенными блоками
}
```

Реализация:
- Mantine Modal
- Кнопка «Скопировать пустой шаблон» → копирует шаблон Приложения А в буфер обмена
- Textarea для вставки заполненного шаблона
- Кнопка «Применить» → вызывает API `/parse-template` → передаёт результат в `onApply`
- Показ warnings от парсера (Mantine Alert, color="yellow")
- Кнопка «Отмена»

**Текст пустого шаблона для копирования:**

```
1. НАЗВАНИЕ
[Название стратегии]

2. ИНСТРУМЕНТЫ
[Тикеры через запятую, напр: SBER, GAZP]

3. ТАЙМФРЕЙМ
[1m / 5m / 15m / 1h / 4h / D / W / M]

4. ИНДИКАТОРЫ
- [Индикатор(параметры), напр: SMA(period=20, source=close)]

5. УСЛОВИЯ ВХОДА
- [Описание условия → Long/Short]

6. УСЛОВИЯ ВЫХОДА
- [Описание условия → Закрыть]

7. СТОП-ЛОСС
[% от цены входа или пункты]

8. ТЕЙК-ПРОФИТ
[% от цены входа или пункты]

9. УПРАВЛЕНИЕ КАПИТАЛОМ
[% от депозита или фиксированная сумма]

10. ФИЛЬТРЫ
[Временные фильтры, напр: 10:00-18:00 MSK]
```

## 6. Обновление DashboardPage (src/pages/DashboardPage.tsx)

Обнови таблицу стратегий:
- Кнопка «+ Новая стратегия» → navigate to `/strategies/new`
- Данные из `strategyStore.fetchStrategies()`
- Колонки: Название (ссылка), Статус (Badge), Версия, Дата изменения, Действия
- Действия: Редактировать (→ /strategies/:id), Удалить (confirm dialog)
- Empty state: «Нет стратегий. Создайте первую!»
- Раскрываемые строки с описанием (как в S1)

## 7. Роутинг

В `App.tsx` добавь роуты:

```typescript
<Route path="/strategies/new" element={<StrategyEditPage />} />
<Route path="/strategies/:id" element={<StrategyEditPage />} />
```

В `Sidebar` обнови пункт «Стратегии» → navigate to `/` (дашборд) или `/strategies`.

## 8. Тесты

```
src/components/strategy/__tests__/
├── BlocklyWorkspace.test.tsx
├── TemplateModeModal.test.tsx
└── StrategyEditPage.test.tsx

src/stores/__tests__/
└── strategyStore.test.ts
```

**Минимальные тест-кейсы:**
- `test_strategy_store_fetch` — fetchStrategies обновляет state
- `test_strategy_store_create` — createStrategy добавляет стратегию
- `test_strategy_store_delete` — deleteStrategy удаляет из списка
- `test_edit_page_renders_tabs` — 3 вкладки рендерятся
- `test_edit_page_description_tab` — TextInput и Textarea на месте
- `test_edit_page_code_tab` — code viewer рендерится
- `test_template_modal_opens` — модальное окно открывается
- `test_template_modal_copy_button` — кнопка «Скопировать шаблон» доступна
- `test_blockly_workspace_renders` — Blockly workspace создаётся

# Что НЕ делать

- **НЕ** модифицируй определения Blockly-блоков — это сделал DEV-2
- **НЕ** трогай backend — это задачи DEV-1, DEV-3, DEV-4, DEV-5
- **НЕ** реализуй AI chat sidebar — это Sprint 4
- **НЕ** реализуй запуск бэктеста — это Sprint 4 (кнопка disabled)

# Артефакты

По завершении:
1. `src/api/strategyApi.ts` — API-модуль
2. `src/stores/strategyStore.ts` — Zustand store
3. `src/components/strategy/BlocklyWorkspace.tsx` — React-компонент Blockly
4. `src/components/strategy/TemplateModeModal.tsx` — Mode B modal
5. `src/pages/StrategyEditPage.tsx` — страница редактора (3 вкладки)
6. Обновлён `src/pages/DashboardPage.tsx` — реальные данные стратегий
7. Обновлён `App.tsx` — новые роуты
8. Тесты: ≥9 тестов
9. **Все тесты проходят:** `pnpm test` → 0 failures
