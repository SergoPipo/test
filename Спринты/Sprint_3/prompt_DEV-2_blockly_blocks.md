---
sprint: 3
agent: DEV-2
role: Frontend Core (FRONT1) — Blockly Custom Blocks
wave: 1
depends_on: []
---

# Роль

Ты — Frontend-разработчик #1 (senior). Реализуй интеграцию Google Blockly в проект и создай кастомные блоки для торговых стратегий: индикаторы, условия, сигналы, фильтры, управление капиталом.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Node >= 18 (node --version)
2. pnpm >= 9 (pnpm --version)
3. Директория frontend/src/ существует
4. pnpm test проходит (0 failures)
5. Blockly ещё не установлен: проверь package.json
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-2 не может начать работу."

# Рабочая директория

`Test/Develop/frontend/`

# Контекст

## Стек frontend
- React 18.3+ с TypeScript 5.4+
- Vite 5.4+ (сборка)
- Mantine 7.8+ (UI-библиотека, dark theme)
- Zustand 4.5+ (state management)
- Vitest (тесты)

## Существующая структура

```
frontend/src/
├── components/
│   ├── layout/        # Shell, Sidebar, Header
│   ├── charts/        # TradingView charts
│   ├── dashboard/     # Dashboard widgets
│   └── settings/      # Settings forms
├── pages/             # Route pages
├── stores/            # Zustand stores
├── api/               # API client
└── utils/             # Helpers
```

# Задачи

## 1. Установка Blockly

```bash
pnpm add blockly
```

## 2. Структура файлов

Создай следующую структуру:

```
frontend/src/components/blockly/
├── index.ts                  # Re-exports
├── BlockDefinitions.ts       # Определения всех кастомных блоков
├── BlockGenerators.ts        # Генераторы JSON для каждого блока
├── BlocklyToolbox.ts         # Конфигурация toolbox (категории)
├── BlocklyTheme.ts           # Тёмная тема для Blockly workspace
└── __tests__/
    ├── BlockDefinitions.test.ts
    └── BlocklyToolbox.test.ts
```

## 3. Тёмная тема Blockly (BlocklyTheme.ts)

Blockly workspace должен визуально соответствовать dark theme приложения.

```typescript
import * as Blockly from 'blockly';

export const darkTheme = Blockly.Theme.defineTheme('moex_dark', {
  name: 'moex_dark',
  base: Blockly.Themes.Classic,
  componentStyles: {
    workspaceBackgroundColour: '#1A1B1E',
    toolboxBackgroundColour: '#25262B',
    toolboxForegroundColour: '#C1C2C5',
    flyoutBackgroundColour: '#2C2E33',
    flyoutForegroundColour: '#C1C2C5',
    flyoutOpacity: 0.9,
    scrollbarColour: '#4A4D55',
    scrollbarOpacity: 0.6,
  },
  blockStyles: {
    indicator_blocks: { colourPrimary: '#339AF0' },     // blue — индикаторы
    condition_blocks: { colourPrimary: '#FD7E14' },     // orange — условия
    logic_blocks: { colourPrimary: '#845EF7' },         // violet — логика
    signal_blocks: { colourPrimary: '#40C057' },        // green — сигналы
    filter_blocks: { colourPrimary: '#FAB005' },        // yellow — фильтры
    management_blocks: { colourPrimary: '#E64980' },    // pink — управление
  },
  categoryStyles: {
    indicator_category: { colour: '#339AF0' },
    condition_category: { colour: '#FD7E14' },
    logic_category: { colour: '#845EF7' },
    signal_category: { colour: '#40C057' },
    filter_category: { colour: '#FAB005' },
    management_category: { colour: '#E64980' },
  },
});
```

## 4. Определения блоков (BlockDefinitions.ts)

### 4.1 Индикаторы (indicator_blocks)

Каждый блок-индикатор имеет:
- **Output**: connection type `"Indicator"` (чтобы подключаться к условиям)
- **Параметры**: период, источник данных (close/open/high/low)

Создай блоки:

| Блок | Параметры | Описание |
|------|-----------|----------|
| `indicator_sma` | period: Number (default 20), source: Dropdown (close/open/high/low) | Simple Moving Average |
| `indicator_ema` | period: Number (default 12), source: Dropdown | Exponential Moving Average |
| `indicator_rsi` | period: Number (default 14) | Relative Strength Index |
| `indicator_macd` | fast: Number (12), slow: Number (26), signal: Number (9) | MACD |
| `indicator_bollinger` | period: Number (20), std_dev: Number (2) | Bollinger Bands |
| `indicator_atr` | period: Number (14) | Average True Range |
| `indicator_stochastic` | k_period: Number (14), d_period: Number (3) | Stochastic Oscillator |
| `indicator_volume` | — | Volume (текущий бар) |

Пример определения блока:

```typescript
Blockly.Blocks['indicator_sma'] = {
  init: function() {
    this.appendDummyInput()
      .appendField('SMA')
      .appendField('период')
      .appendField(new Blockly.FieldNumber(20, 1, 500), 'PERIOD')
      .appendField('источник')
      .appendField(new Blockly.FieldDropdown([
        ['Close', 'close'], ['Open', 'open'],
        ['High', 'high'], ['Low', 'low']
      ]), 'SOURCE');
    this.setOutput(true, 'Indicator');
    this.setStyle('indicator_blocks');
    this.setTooltip('Simple Moving Average — скользящая средняя');
  }
};
```

### 4.2 Условия (condition_blocks)

| Блок | Inputs | Описание |
|------|--------|----------|
| `condition_crossover` | left: Indicator, right: Indicator, direction: Dropdown (вверх/вниз) | Пересечение |
| `condition_compare` | left: Indicator, operator: Dropdown (>/</>=/<=/==), right: Indicator OR Number | Сравнение |
| `condition_in_zone` | value: Indicator, min: Number, max: Number | Попадание в зону (для RSI) |

```typescript
Blockly.Blocks['condition_crossover'] = {
  init: function() {
    this.appendValueInput('LEFT').setCheck('Indicator').appendField('Когда');
    this.appendDummyInput()
      .appendField('пересекает')
      .appendField(new Blockly.FieldDropdown([
        ['снизу вверх', 'up'], ['сверху вниз', 'down']
      ]), 'DIRECTION');
    this.appendValueInput('RIGHT').setCheck('Indicator');
    this.setOutput(true, 'Condition');
    this.setStyle('condition_blocks');
    this.setTooltip('Пересечение двух индикаторов');
  }
};
```

### 4.3 Логические операторы (logic_blocks)

| Блок | Inputs | Описание |
|------|--------|----------|
| `logic_and` | A: Condition, B: Condition | Логическое И |
| `logic_or` | A: Condition, B: Condition | Логическое ИЛИ |
| `logic_not` | A: Condition | Логическое НЕ |

### 4.4 Сигналы (signal_blocks)

| Блок | Inputs | Описание |
|------|--------|----------|
| `signal_entry` | condition: Condition, direction: Dropdown (long/short) | Вход в позицию |
| `signal_exit` | condition: Condition | Выход из позиции |

```typescript
Blockly.Blocks['signal_entry'] = {
  init: function() {
    this.appendValueInput('CONDITION').setCheck('Condition')
      .appendField('ВХОД')
      .appendField(new Blockly.FieldDropdown([
        ['Long', 'long'], ['Short', 'short']
      ]), 'DIRECTION')
      .appendField('когда');
    this.setPreviousStatement(true, 'Signal');
    this.setNextStatement(true, 'Signal');
    this.setStyle('signal_blocks');
    this.setTooltip('Сигнал на вход в позицию');
  }
};
```

### 4.5 Фильтры (filter_blocks)

| Блок | Inputs | Описание |
|------|--------|----------|
| `filter_time` | start_hour: Number, start_min: Number, end_hour: Number, end_min: Number | Фильтр по времени торговой сессии |

### 4.6 Управление капиталом (management_blocks)

| Блок | Inputs | Описание |
|------|--------|----------|
| `management_position_size` | mode: Dropdown (percent/fixed), value: Number | Размер позиции |
| `management_stop_loss` | value: Number, type: Dropdown (%/пункты) | Стоп-лосс |
| `management_take_profit` | value: Number, type: Dropdown (%/пункты) | Тейк-профит |

## 5. Генераторы JSON (BlockGenerators.ts)

Каждый блок должен генерировать JSON-фрагмент для сохранения и передачи на бэкенд.

```typescript
import * as Blockly from 'blockly';

// Создаём JSON-генератор
export const jsonGenerator = new Blockly.Generator('JSON');

jsonGenerator.forBlock['indicator_sma'] = function(block: Blockly.Block) {
  const period = block.getFieldValue('PERIOD');
  const source = block.getFieldValue('SOURCE');
  return [JSON.stringify({
    type: 'indicator',
    name: 'SMA',
    params: { period: Number(period), source }
  }), 0]; // 0 = precedence
};

// ... аналогично для всех блоков
```

**Формат JSON (соответствует ТЗ):**

```json
{
  "version": "1.0",
  "blocks": [
    {
      "id": "b1",
      "type": "indicator",
      "name": "SMA",
      "params": { "period": 20, "source": "close" }
    },
    {
      "id": "b2",
      "type": "condition",
      "operator": "crossover_up",
      "left": "b1",
      "right": { "type": "indicator", "name": "EMA", "params": { "period": 50 } }
    },
    {
      "id": "b3",
      "type": "entry_signal",
      "direction": "long",
      "condition": "b2"
    }
  ]
}
```

## 6. Конфигурация Toolbox (BlocklyToolbox.ts)

```typescript
export const toolboxConfig = {
  kind: 'categoryToolbox',
  contents: [
    {
      kind: 'category',
      name: 'Индикаторы',
      categoryStyle: 'indicator_category',
      contents: [
        { kind: 'block', type: 'indicator_sma' },
        { kind: 'block', type: 'indicator_ema' },
        { kind: 'block', type: 'indicator_rsi' },
        { kind: 'block', type: 'indicator_macd' },
        { kind: 'block', type: 'indicator_bollinger' },
        { kind: 'block', type: 'indicator_atr' },
        { kind: 'block', type: 'indicator_stochastic' },
        { kind: 'block', type: 'indicator_volume' },
      ],
    },
    {
      kind: 'category',
      name: 'Условия',
      categoryStyle: 'condition_category',
      contents: [
        { kind: 'block', type: 'condition_crossover' },
        { kind: 'block', type: 'condition_compare' },
        { kind: 'block', type: 'condition_in_zone' },
      ],
    },
    {
      kind: 'category',
      name: 'Логика',
      categoryStyle: 'logic_category',
      contents: [
        { kind: 'block', type: 'logic_and' },
        { kind: 'block', type: 'logic_or' },
        { kind: 'block', type: 'logic_not' },
      ],
    },
    {
      kind: 'category',
      name: 'Сигналы',
      categoryStyle: 'signal_category',
      contents: [
        { kind: 'block', type: 'signal_entry' },
        { kind: 'block', type: 'signal_exit' },
      ],
    },
    {
      kind: 'category',
      name: 'Фильтры',
      categoryStyle: 'filter_category',
      contents: [
        { kind: 'block', type: 'filter_time' },
      ],
    },
    {
      kind: 'category',
      name: 'Управление',
      categoryStyle: 'management_category',
      contents: [
        { kind: 'block', type: 'management_position_size' },
        { kind: 'block', type: 'management_stop_loss' },
        { kind: 'block', type: 'management_take_profit' },
      ],
    },
  ],
};
```

## 7. Тесты

```
frontend/src/components/blockly/__tests__/
├── BlockDefinitions.test.ts
└── BlocklyToolbox.test.ts
```

**Минимальные тест-кейсы:**
- `test_all_indicator_blocks_defined` — все 8 блоков-индикаторов зарегистрированы в Blockly.Blocks
- `test_all_condition_blocks_defined` — 3 блока условий
- `test_all_signal_blocks_defined` — 2 блока сигналов
- `test_all_filter_blocks_defined` — 1 блок фильтра
- `test_all_management_blocks_defined` — 3 блока управления
- `test_toolbox_has_all_categories` — toolbox содержит 6 категорий
- `test_toolbox_category_block_count` — каждая категория содержит правильное количество блоков
- `test_json_generator_sma` — генератор для SMA возвращает корректный JSON
- `test_json_generator_crossover` — генератор для crossover возвращает корректный JSON
- `test_dark_theme_defined` — тёмная тема создана и содержит правильные стили

# Что НЕ делать

- **НЕ** создавай React-компонент BlocklyWorkspace — это задача DEV-6
- **НЕ** создавай страницу Strategy Editor — это задача DEV-6
- **НЕ** подключай Blockly к API стратегий — это задача DEV-6
- **НЕ** трогай backend — это задачи DEV-1, DEV-3, DEV-4, DEV-5

Твоя задача — **определения блоков, генераторы, тема и toolbox**. Это кирпичики, из которых DEV-6 соберёт редактор.

# Артефакты

По завершении:
1. `src/components/blockly/BlockDefinitions.ts` — 20 кастомных блоков
2. `src/components/blockly/BlockGenerators.ts` — JSON-генераторы
3. `src/components/blockly/BlocklyToolbox.ts` — конфигурация toolbox
4. `src/components/blockly/BlocklyTheme.ts` — тёмная тема
5. `src/components/blockly/index.ts` — re-exports
6. `src/components/blockly/__tests__/` — ≥10 тестов
7. **Все тесты проходят:** `pnpm test` → 0 failures
