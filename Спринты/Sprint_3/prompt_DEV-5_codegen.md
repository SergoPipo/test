---
sprint: 3
agent: DEV-5
role: Backend #2 (BACK2) — Code Generator + Template Parser
wave: 2
depends_on: [DEV-1]
---

# Роль

Ты — Backend-разработчик #2. Реализуй два модуля: Code Generator (блочная схема → Python/Backtrader код) и Template Parser (текстовый шаблон → блочная схема JSON).

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Модуль app/strategy/ реализован (models, service, router) — результат DEV-1
3. Таблицы strategies и strategy_versions существуют в БД
4. pytest tests/ проходит на develop (0 failures)
5. backtrader установлен: python3 -c "import backtrader"
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-5 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст

## Формат блочной схемы JSON (из ТЗ)

Это JSON, который генерируется Blockly на фронтенде и передаётся на бэкенд:

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
      "type": "indicator",
      "name": "EMA",
      "params": { "period": 50, "source": "close" }
    },
    {
      "id": "b3",
      "type": "condition",
      "operator": "crossover_up",
      "left": "b1",
      "right": "b2"
    },
    {
      "id": "b4",
      "type": "entry_signal",
      "direction": "long",
      "condition": "b3"
    },
    {
      "id": "b5",
      "type": "condition",
      "operator": "crossover_down",
      "left": "b1",
      "right": "b2"
    },
    {
      "id": "b6",
      "type": "exit_signal",
      "condition": "b5"
    }
  ]
}
```

## Формат шаблона (Приложение А из ФТ)

```
1. НАЗВАНИЕ
Стратегия SMA Crossover

2. ИНСТРУМЕНТЫ
SBER, GAZP

3. ТАЙМФРЕЙМ
Дневной (D)

4. ИНДИКАТОРЫ
- SMA(period=20, source=close)
- EMA(period=50, source=close)

5. УСЛОВИЯ ВХОДА
- Когда SMA(20) пересекает EMA(50) снизу вверх → Long

6. УСЛОВИЯ ВЫХОДА
- Когда SMA(20) пересекает EMA(50) сверху вниз → Закрыть

7. СТОП-ЛОСС
2% от цены входа

8. ТЕЙК-ПРОФИТ
5% от цены входа

9. УПРАВЛЕНИЕ КАПИТАЛОМ
10% от депозита на сделку

10. ФИЛЬТРЫ
Торговля только с 10:00 до 18:00 MSK
```

## Существующие API-эндпоинты стратегий (DEV-1)

```
POST   /api/v1/strategy              → create
GET    /api/v1/strategy              → list
GET    /api/v1/strategy/{id}         → detail
PUT    /api/v1/strategy/{id}         → update
DELETE /api/v1/strategy/{id}         → delete
POST   /api/v1/strategy/{id}/versions → create version
GET    /api/v1/strategy/{id}/versions/{number} → get version
```

# Задачи

## 1. Code Generator (app/strategy/code_generator.py)

Принимает JSON блочной схемы, генерирует Python-класс для Backtrader.

```python
class CodeGenerator:
    """Генерирует Python/Backtrader код из блочной схемы JSON."""

    # Маппинг индикаторов на Backtrader-классы
    INDICATOR_MAP = {
        'SMA': 'bt.indicators.SimpleMovingAverage',
        'EMA': 'bt.indicators.ExponentialMovingAverage',
        'RSI': 'bt.indicators.RSI',
        'MACD': 'bt.indicators.MACD',
        'BB': 'bt.indicators.BollingerBands',
        'ATR': 'bt.indicators.ATR',
        'Stochastic': 'bt.indicators.Stochastic',
    }

    def generate(self, blocks_json: dict) -> str:
        """Генерирует Python-код из блочной схемы."""
        blocks = blocks_json.get('blocks', [])
        if not blocks:
            return self._empty_strategy()

        # 1. Собрать индикаторы
        indicators = [b for b in blocks if b['type'] == 'indicator']
        # 2. Собрать условия
        conditions = [b for b in blocks if b['type'] == 'condition']
        # 3. Собрать сигналы
        entry_signals = [b for b in blocks if b['type'] == 'entry_signal']
        exit_signals = [b for b in blocks if b['type'] == 'exit_signal']
        # 4. Собрать фильтры и управление
        filters = [b for b in blocks if b['type'] == 'time_filter']
        management = [b for b in blocks if b['type'] == 'position_size']

        # Генерация кода
        code_lines = [
            'import backtrader as bt',
            '',
            '',
            'class GeneratedStrategy(bt.Strategy):',
        ]

        # params
        code_lines.append(self._generate_params(indicators, management))

        # __init__
        code_lines.append(self._generate_init(indicators))

        # next
        code_lines.append(self._generate_next(conditions, entry_signals, exit_signals, filters))

        return '\n'.join(code_lines)

    def _generate_params(self, indicators, management) -> str:
        # Генерирует секцию params = {...}
        ...

    def _generate_init(self, indicators) -> str:
        # Генерирует __init__ с bt.indicators.*
        ...

    def _generate_next(self, conditions, entry_signals, exit_signals, filters) -> str:
        # Генерирует next() с условиями входа/выхода
        ...

    def _empty_strategy(self) -> str:
        return '''import backtrader as bt


class GeneratedStrategy(bt.Strategy):
    """Пустая стратегия. Добавьте блоки в редакторе."""

    def next(self):
        pass
'''
```

**Пример выходного кода для SMA Crossover:**

```python
import backtrader as bt


class GeneratedStrategy(bt.Strategy):
    params = {
        'sma_period': 20,
        'ema_period': 50,
    }

    def __init__(self):
        self.sma = bt.indicators.SimpleMovingAverage(
            self.data.close, period=self.params.sma_period
        )
        self.ema = bt.indicators.ExponentialMovingAverage(
            self.data.close, period=self.params.ema_period
        )
        self.crossover = bt.indicators.CrossOver(self.sma, self.ema)

    def next(self):
        if self.crossover > 0:  # SMA пересекает EMA снизу вверх
            if not self.position:
                self.buy()
        elif self.crossover < 0:  # SMA пересекает EMA сверху вниз
            if self.position:
                self.close()
```

## 2. Template Parser (app/strategy/block_parser.py)

Regex-парсер текстового шаблона → JSON блочная схема.

```python
import re
from dataclasses import dataclass, field

@dataclass
class ParseResult:
    blocks_json: dict
    warnings: list[str] = field(default_factory=list)

class TemplateParser:
    """Парсит текстовый шаблон стратегии в блочную схему JSON."""

    # Regex для индикаторов
    INDICATOR_PATTERN = re.compile(
        r'(SMA|EMA|RSI|MACD|Bollinger\s*Bands?|BB|ATR|Stochastic|Volume)'
        r'\s*\(([^)]*)\)',
        re.IGNORECASE
    )

    # Regex для условий
    CROSSOVER_PATTERN = re.compile(
        r'(?:когда\s+)?(\w+(?:\(\d+\))?)\s+пересекает\s+(\w+(?:\(\d+\))?)\s+'
        r'(снизу\s+вверх|сверху\s+вниз)',
        re.IGNORECASE
    )

    COMPARE_PATTERN = re.compile(
        r'(\w+(?:\(\d+\))?)\s*(>|<|>=|<=|==)\s*(\d+(?:\.\d+)?)',
        re.IGNORECASE
    )

    SECTIONS = {
        '1': 'name',
        '2': 'instruments',
        '3': 'timeframe',
        '4': 'indicators',
        '5': 'entry_conditions',
        '6': 'exit_conditions',
        '7': 'stop_loss',
        '8': 'take_profit',
        '9': 'position_sizing',
        '10': 'filters',
    }

    def parse(self, template_text: str) -> ParseResult:
        """Парсит шаблон и возвращает блочную схему + предупреждения."""
        warnings: list[str] = []
        blocks: list[dict] = []
        block_id = 0

        # Разбить текст на секции
        sections = self._split_sections(template_text)

        # Парсить каждую секцию
        for section_num, content in sections.items():
            section_type = self.SECTIONS.get(section_num)
            if not section_type:
                warnings.append(f"Неизвестная секция: {section_num}")
                continue

            try:
                if section_type == 'indicators':
                    new_blocks = self._parse_indicators(content)
                    blocks.extend(new_blocks)
                elif section_type == 'entry_conditions':
                    new_blocks = self._parse_conditions(content, 'entry', blocks)
                    blocks.extend(new_blocks)
                elif section_type == 'exit_conditions':
                    new_blocks = self._parse_conditions(content, 'exit', blocks)
                    blocks.extend(new_blocks)
                elif section_type == 'stop_loss':
                    new_blocks = self._parse_stop_loss(content)
                    blocks.extend(new_blocks)
                elif section_type == 'take_profit':
                    new_blocks = self._parse_take_profit(content)
                    blocks.extend(new_blocks)
                elif section_type == 'position_sizing':
                    new_blocks = self._parse_position_sizing(content)
                    blocks.extend(new_blocks)
                elif section_type == 'filters':
                    new_blocks = self._parse_filters(content)
                    blocks.extend(new_blocks)
            except Exception as e:
                warnings.append(f"Ошибка парсинга секции '{section_type}': {e}")

        # Присвоить ID
        for i, block in enumerate(blocks):
            block['id'] = f'b{i + 1}'

        return ParseResult(
            blocks_json={'version': '1.0', 'blocks': blocks},
            warnings=warnings
        )

    def _split_sections(self, text: str) -> dict[str, str]:
        """Разбивает текст по секциям (1. НАЗВАНИЕ, 2. ИНСТРУМЕНТЫ, ...)"""
        ...

    def _parse_indicators(self, text: str) -> list[dict]:
        """Извлекает индикаторы из текста."""
        ...

    def _parse_conditions(self, text: str, signal_type: str, existing_blocks: list) -> list[dict]:
        """Извлекает условия и сигналы."""
        ...

    def _parse_stop_loss(self, text: str) -> list[dict]: ...
    def _parse_take_profit(self, text: str) -> list[dict]: ...
    def _parse_position_sizing(self, text: str) -> list[dict]: ...
    def _parse_filters(self, text: str) -> list[dict]: ...
```

## 3. API Endpoints

Добавь два новых эндпоинта в `app/strategy/router.py`:

```python
@router.post("/{strategy_id}/generate-code")
async def generate_code(
    strategy_id: int,
    request: GenerateCodeRequest,  # { blocks_json: dict }
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Генерирует Python-код из блочной схемы."""
    # Проверить ownership стратегии
    strategy = await strategy_service.get_by_id(current_user.id, strategy_id)

    generator = CodeGenerator()
    code = generator.generate(request.blocks_json)
    return {"code": code, "errors": []}


@router.post("/parse-template")
async def parse_template(
    request: ParseTemplateRequest,  # { template_text: str }
    current_user = Depends(get_current_user),
):
    """Парсит текстовый шаблон в блочную схему JSON."""
    parser = TemplateParser()
    result = parser.parse(request.template_text)
    return {"blocks_json": result.blocks_json, "warnings": result.warnings}
```

## 4. Схемы (добавить в app/strategy/schemas.py)

```python
class GenerateCodeRequest(BaseModel):
    blocks_json: dict

class GenerateCodeResponse(BaseModel):
    code: str
    errors: list[str]

class ParseTemplateRequest(BaseModel):
    template_text: str

class ParseTemplateResponse(BaseModel):
    blocks_json: dict
    warnings: list[str]
```

## 5. Тесты

```
tests/unit/test_strategy/
├── test_code_generator.py
└── test_block_parser.py
```

### test_code_generator.py
- `test_empty_blocks_generates_empty_strategy` — пустой JSON → пустая стратегия
- `test_sma_crossover_generates_valid_code` — SMA+EMA+crossover → корректный Backtrader
- `test_rsi_with_zone_condition` — RSI + in_zone → if/else в next()
- `test_macd_indicator` — MACD → bt.indicators.MACD с параметрами
- `test_bollinger_indicator` — BB → bt.indicators.BollingerBands
- `test_entry_and_exit_signals` — entry + exit → buy/close в next()
- `test_time_filter` — time_filter → datetime check в next()
- `test_position_sizing` — position_size → params + sizer
- `test_generated_code_is_valid_python` — результат компилируется `compile(code, '<test>', 'exec')`

### test_block_parser.py
- `test_parse_full_template` — полный шаблон → корректный JSON
- `test_parse_sma_indicator` — "SMA(period=20)" → indicator block
- `test_parse_crossover_condition` — "пересекает снизу вверх" → crossover_up
- `test_parse_missing_section_warning` — отсутствующая секция → warning
- `test_parse_invalid_indicator_warning` — нераспознанный индикатор → warning
- `test_parse_empty_template` — пустой текст → пустой JSON + warnings
- `test_parse_stop_loss_percent` — "2% от цены входа" → stop_loss block
- `test_parse_time_filter` — "10:00 до 18:00" → time_filter block

# Что НЕ делать

- **НЕ** модифицируй модели Strategy/StrategyVersion — это сделал DEV-1
- **НЕ** трогай Sandbox — это DEV-3
- **НЕ** трогай CSRF/Rate Limiting — это DEV-4
- **НЕ** трогай frontend — это DEV-2 и DEV-6

# Артефакты

По завершении:
1. `app/strategy/code_generator.py` — Code Generator
2. `app/strategy/block_parser.py` — Template Parser
3. Обновлён `app/strategy/router.py` — два новых эндпоинта
4. Обновлён `app/strategy/schemas.py` — новые схемы
5. `tests/unit/test_strategy/test_code_generator.py` — ≥9 тестов
6. `tests/unit/test_strategy/test_block_parser.py` — ≥8 тестов
7. **Все тесты проходят:** `pytest tests/ -v` → 0 failures
