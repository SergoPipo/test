---
sprint: 4
agent: DEV-5
role: Frontend (FRONT2) — AI Chat Mode в Strategy Editor
wave: 2
depends_on: [UX (ui_spec_s4.md), DEV-1 (AI Service)]
---

# Роль

Ты — Frontend-разработчик #5 (senior). Реализуй полноэкранный AI-режим в Strategy Editor: свайп-анимация, split-панель (описание + чат), SSE streaming, интеграция с Blockly через Template Parser.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node >= 18, pnpm >= 9
2. UI-спецификация: Sprint_4/ui_spec_s4.md существует и утверждена (ОБЯЗАТЕЛЬНО ПРОЧИТАЙ)
3. StrategyEditPage (S3) работает: frontend/src/pages/StrategyEditPage.tsx
4. AI API endpoints доступны: POST /ai/chat, POST /ai/chat/stream, GET /ai/status
5. Template Parser API (S3): POST /strategies/{id}/parse-template
6. pnpm test проходит (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-5 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст существующего кода

## Паттерны проекта

- **React 18** + **TypeScript**
- **Mantine 7.8+** (dark theme)
- **Zustand** для state management
- **React Query (TanStack Query)** для серверного состояния
- **Axios** для HTTP
- **react-resizable-panels** (уже установлен) — PanelGroup, Panel, PanelResizeHandle

## StrategyEditPage (S3)

```
frontend/src/pages/StrategyEditPage.tsx
  - Tabs: Содержание | Редактор | Код       ← ВКЛАДКА «КОД» УБИРАЕТСЯ
  - Blockly workspace (центр)
  - Toolbar (zoom, undo, redo)
```

# КЛЮЧЕВЫЕ РЕШЕНИЯ ЗАКАЗЧИКА (обязательно к выполнению)

1. **AI-чат — НЕ sidebar.** Это отдельный полноэкранный режим внутри вкладки «Редактор».
2. **Вкладка «Код» убирается.** Остаётся 2 вкладки: Содержание | Редактор.
3. **AI формирует текстовое описание стратегии**, не блоки напрямую. Через Template Parser.
4. **Split 40/60** (описание | чат) с resizable разделителем.
5. **«Применить к блокам»** → парсить описание → загрузить в Blockly → закрыть AI-режим, вернуть к Blockly.
6. **Описание — редактируемое** вручную пользователем.
7. **Вложения** в чате: файлы, картинки (📎).
8. **Выбор модели** LLM + название в header чата (dropdown если несколько).
9. **Свайп-анимация** при переключении Blockly ↔ AI (slide left/right, 300ms).

# Задачи

## 1. Убрать вкладку «Код» из StrategyEditPage

В `StrategyEditPage.tsx`:
- Убрать Tab «Код» и его содержимое
- Оставить 2 вкладки: **Содержание** | **Редактор**
- Код стратегии теперь можно посмотреть на вкладке «Содержание» (если он там отображается) или убрать совсем

## 2. Два состояния вкладки «Редактор»

Вкладка «Редактор» переключается между двумя состояниями:

**Состояние A — Blockly (по умолчанию):**
- Blockly workspace + Toolbox + Toolbar
- Кнопка `[🤖 AI-помощник]` в toolbar (внизу, рядом с Zoom/Undo/Redo)
- Кнопка `[▶ Запустить бэктест]` в toolbar

**Состояние B — AI-режим:**
- Split-панель: описание (40%) | чат (60%)
- Resizable разделитель (PanelGroup)
- Кнопка `[← Вернуться к редактору]` вверху

Переключение — свайп-анимация.

## 3. Свайп-анимация (src/components/ai/AnimatedSwitch.tsx)

```typescript
// CSS transitions:
// Blockly → AI: Blockly translateX(0→-100%), AI translateX(100%→0)
// AI → Blockly: AI translateX(0→100%), Blockly translateX(-100%→0)
// Duration: 300ms, ease-in-out

interface AnimatedSwitchProps {
  showAI: boolean;
  blocklyContent: React.ReactNode;
  aiContent: React.ReactNode;
}
```

## 4. Левая панель: описание стратегии (src/components/ai/StrategyDescription.tsx)

```
┌─ ОПИСАНИЕ (редактируемое) ─────────────┐
│                                         │
│ 1. НАЗВАНИЕ                             │
│ SMA Crossover                           │
│                                         │
│ 3. ИНДИКАТОРЫ                           │
│ - SMA(period=20)                        │
│ - SMA(period=50)                        │
│ ...                                     │
│                                         │
│ ⚠ Секция "Стоп-лосс" не распознана     │
│                                         │
│           [Применить к блокам ▶]        │
└─────────────────────────────────────────┘
```

**Компоненты Mantine:**
- `Textarea` — monospace шрифт, autosize, editable
- `Button` variant="filled" color="blue" — «Применить к блокам»
- `Alert` variant="light" color="yellow" — предупреждения парсера

**Поведение кнопки «Применить к блокам»:**
1. Отправить описание на `POST /strategies/{id}/parse-template`
2. Получить `blocks_json` + `warnings`
3. Показать warnings (если есть) в Alert
4. Загрузить блоки в Blockly workspace
5. Перегенерировать код (`POST /strategies/{id}/generate-code`)
6. Закрыть AI-режим (анимация → Blockly)
7. Toast notification: «Блоки обновлены»

## 5. Правая панель: AI-чат (src/components/ai/AIChat.tsx)

### 5.1 Header чата

```
┌────────────────────────────────────────┐
│ Claude Sonnet 4  [▾ выбор модели]      │
│ 🟢 15/100 запросов    [Очистить ист.]  │
└────────────────────────────────────────┘
```

**Компоненты:**
- `Select` size="sm" — выбор модели/провайдера (данные из `GET /settings/ai/providers`)
- `Badge` — статус (🟢 доступен, 🟡 >80% лимита, ⚪ не настроен)
- `Text` size="xs" c="dimmed" — счётчик `usage_today / daily_limit`
- `Button` variant="subtle" size="xs" — «Очистить историю»

### 5.2 Список сообщений

- `ScrollArea` с автопрокруткой к последнему сообщению
- Сообщения пользователя: фон `#2C2E33`, справа
- Сообщения AI: фон `#25262B`, слева
- Streaming: текст появляется потоково, `Loader` dots перед первым чанком
- «AI думает · · ·» — анимация 3 точки

### 5.3 Поле ввода

```
┌────────────────────────────────────────┐
│ [📎]  Опишите стратегию...         [▶] │
└────────────────────────────────────────┘
```

- `Textarea` autosize, minRows=1, maxRows=4
- Enter = отправить, Shift+Enter = новая строка
- `ActionIcon` 📎 — прикрепить файл/картинку (`FileButton`)
- `ActionIcon` ▶ — отправить
- Disabled во время streaming

### 5.4 Вложения

- Кнопка 📎 открывает `FileButton` (Mantine)
- Поддерживаемые форматы: .png, .jpg, .jpeg, .gif, .txt, .md, .pdf
- Превью перед отправкой: миниатюра для картинок, имя файла для текста
- Вложение отправляется как base64 в теле запроса к AI API

## 6. AI Chat Store (src/stores/aiChatStore.ts)

```typescript
interface AIChatStore {
  messages: ChatMessage[];
  isStreaming: boolean;
  streamingContent: string;
  aiStatus: AIStatus | null;
  providers: AIProvider[];
  selectedProviderId: number | null;
  showAIMode: boolean;           // переключение Blockly ↔ AI
  description: string;            // текстовое описание стратегии

  toggleAIMode: () => void;
  sendMessage: (strategyId: number, message: string, attachments?: File[]) => Promise<void>;
  sendMessageStream: (strategyId: number, message: string, attachments?: File[]) => void;
  clearHistory: (strategyId: number) => Promise<void>;
  fetchStatus: () => Promise<void>;
  fetchProviders: () => Promise<void>;
  selectProvider: (id: number) => void;
  setDescription: (text: string) => void;
  applyToBlocks: (strategyId: number) => Promise<void>;
}

interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  attachments?: { name: string; type: string; preview?: string }[];
  timestamp: Date;
}

interface AIStatus {
  available: boolean;
  provider: string;
  usageToday: number;
  limitToday: number;
}

interface AIProvider {
  id: number;
  displayName: string;
  providerType: string;
  modelId: string;
  isActive: boolean;
  usageToday: number;
  dailyLimit: number;
}
```

## 7. SSE Client (src/services/aiStreamClient.ts)

```typescript
export async function streamChat(
  strategyId: number,
  message: string,
  history: ChatMessage[],
  onChunk: (content: string) => void,
  onDone: (result: { tokensUsed: number }) => void,
  onError: (error: string) => void,
  signal?: AbortSignal,
): Promise<void> {
  const response = await fetch('/api/v1/ai/chat/stream', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ strategy_id: strategyId, message, history }),
    signal,
  });

  const reader = response.body?.getReader();
  const decoder = new TextDecoder();
  // Parse SSE: data: {"type":"chunk","content":"..."} / data: {"type":"done",...}
}
```

## 8. Контекст блоков для AI

При открытии AI-режима собирается контекст и отправляется с первым (или каждым) запросом:

```typescript
function buildAIContext(workspace: Blockly.Workspace, strategy: Strategy) {
  return {
    currentBlocks: workspace ? serializeWorkspace(workspace) : null,
    currentDescription: strategy.description,
    generatedCode: strategy.generated_code,
    availableBlocks: AVAILABLE_BLOCK_TYPES, // константа: индикаторы, условия, сигналы и т.д.
  };
}
```

## 9. AI Unavailable State

```
┌────────────────────────────────────────┐
│  ⚠ AI-помощник недоступен              │
│                                        │
│  Настройте API-ключ в разделе          │
│  Настройки → AI-провайдеры.            │
│                                        │
│  [Перейти в настройки]                 │
│                                        │
│  Вы можете редактировать описание      │
│  вручную в левой панели.               │
└────────────────────────────────────────┘
```

Левая панель (описание) остаётся рабочей даже без AI.

# Тесты (src/__tests__/ai/)

Минимум **18 тестов**:

1. **AnimatedSwitch** (3): renders blockly by default, switches to AI on toggle, switches back
2. **StrategyDescription** (3): renders editable textarea, apply button calls parse-template, shows warnings
3. **AIChat** (4): renders messages, shows streaming indicator, shows unavailable state, model selector
4. **ChatInput** (3): send message on Enter, disabled during streaming, attach file button
5. **aiChatStore** (3): toggleAIMode, sendMessage updates messages, fetchProviders
6. **SSE client** (2): stream chunks, handle error

Для SSE — mock fetch с ReadableStream.

# Ветка

```
git checkout -b s4/ai-sidebar develop
```

# Критерии приёмки

- [ ] Вкладка «Код» убрана, осталось 2 вкладки (Содержание | Редактор)
- [ ] Кнопка [🤖 AI-помощник] в toolbar вкладки «Редактор»
- [ ] Свайп-анимация Blockly ↔ AI (300ms, slide left/right)
- [ ] Split 40/60 (описание | чат) с resizable разделителем
- [ ] Описание — редактируемое вручную
- [ ] «Применить к блокам» → parse-template → load blocks → закрыть AI → toast
- [ ] SSE streaming работает (текст появляется потоково)
- [ ] «AI думает · · ·» анимация
- [ ] Выбор модели LLM в header чата (dropdown)
- [ ] Кнопка 📎 для вложений (файлы, картинки)
- [ ] Кнопка «Очистить историю»
- [ ] AI unavailable state с ссылкой на настройки
- [ ] Контекст блоков передаётся AI при запросе
- [ ] ≥18 тестов, 0 failures
- [ ] Регрессия: все существующие тесты проходят
