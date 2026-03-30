---
sprint: 3
agent: DEV-3
role: Security (SEC) — Code Sandbox
wave: 1
depends_on: []
---

# Роль

Ты — специалист по безопасности. Реализуй песочницу (Code Sandbox) для безопасного выполнения Python-кода стратегий: AST-анализ, RestrictedPython, ограничение ресурсов.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Директория backend/app/sandbox/ существует (может быть пустой или со стабами)
3. pip install RestrictedPython — устанавливается без ошибок
4. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-3 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Паттерны проекта

- Исключения: `app/common/exceptions.py` (NotFoundError, ValidationError, etc.)
- Роутеры: `APIRouter`, `Depends(get_db)`, `Depends(get_current_user)`
- Конфиг: `app/config.py` (Pydantic Settings)
- Логирование: `structlog`

## Регистрация роутера

Sandbox-роутер нужно будет подключить в `app/main.py`. Если стаб уже есть — замени. Если нет — добавь:

```python
from app.sandbox.router import router as sandbox_router
app.include_router(sandbox_router, prefix="/api/v1/sandbox", tags=["sandbox"])
```

# Задачи

## 1. Зависимость

Добавь `RestrictedPython` в `pyproject.toml`:

```toml
[project]
dependencies = [
    # ... existing
    "RestrictedPython>=7.0",
]
```

## 2. AST-анализатор (app/sandbox/ast_analyzer.py)

Статический анализ кода **до** выполнения. Отсекает заведомо опасные конструкции.

```python
import ast
from dataclasses import dataclass, field

@dataclass
class AnalysisResult:
    is_safe: bool
    issues: list[str] = field(default_factory=list)

class ASTAnalyzer:
    """Статический анализ Python-кода на безопасность."""

    FORBIDDEN_NAMES: set[str] = {
        'eval', 'exec', 'compile', '__import__',
        'getattr', 'setattr', 'delattr',
        'globals', 'locals', 'vars',
        'type', 'object.__subclasses__',
        '__builtins__', '__loader__', '__spec__',
        'breakpoint', 'exit', 'quit',
    }

    FORBIDDEN_MODULES: set[str] = {
        'os', 'sys', 'subprocess', 'shutil',
        'socket', 'http', 'urllib', 'requests',
        'ctypes', 'importlib', 'pickle', 'shelve',
        'tempfile', 'pathlib', 'glob',
        'signal', 'threading', 'multiprocessing',
        'code', 'codeop', 'compileall',
    }

    WHITELIST_MODULES: set[str] = {
        'backtrader', 'bt',
        'pandas', 'pd',
        'numpy', 'np',
        'ta',
        'datetime', 'math', 'decimal',
        'dataclasses', 'typing', 'enum',
        'collections', 'itertools', 'functools',
    }

    def analyze(self, code: str) -> AnalysisResult:
        """Анализирует код и возвращает результат."""
        issues: list[str] = []

        # 1. Парсинг AST
        try:
            tree = ast.parse(code)
        except SyntaxError as e:
            return AnalysisResult(is_safe=False, issues=[f"Синтаксическая ошибка: {e}"])

        # 2. Обход дерева
        for node in ast.walk(tree):
            # Проверка import
            if isinstance(node, ast.Import):
                for alias in node.names:
                    module = alias.name.split('.')[0]
                    if module in self.FORBIDDEN_MODULES:
                        issues.append(f"Запрещённый модуль: {alias.name}")
                    elif module not in self.WHITELIST_MODULES:
                        issues.append(f"Неразрешённый модуль: {alias.name}")

            # Проверка from X import Y
            elif isinstance(node, ast.ImportFrom):
                if node.module:
                    module = node.module.split('.')[0]
                    if module in self.FORBIDDEN_MODULES:
                        issues.append(f"Запрещённый модуль: {node.module}")
                    elif module not in self.WHITELIST_MODULES:
                        issues.append(f"Неразрешённый модуль: {node.module}")

            # Проверка вызовов запрещённых функций
            elif isinstance(node, ast.Call):
                func_name = self._get_call_name(node)
                if func_name in self.FORBIDDEN_NAMES:
                    issues.append(f"Запрещённая функция: {func_name}")

            # Проверка обращений к запрещённым атрибутам
            elif isinstance(node, ast.Name):
                if node.id in self.FORBIDDEN_NAMES:
                    issues.append(f"Запрещённое имя: {node.id}")
                if node.id.startswith('__') and node.id.endswith('__'):
                    issues.append(f"Обращение к dunder-атрибуту: {node.id}")

            # Проверка open()
            elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id == 'open':
                    issues.append("Запрещённая функция: open() (файловые операции)")

        return AnalysisResult(is_safe=len(issues) == 0, issues=issues)

    def _get_call_name(self, node: ast.Call) -> str:
        """Извлекает имя вызываемой функции."""
        if isinstance(node.func, ast.Name):
            return node.func.id
        elif isinstance(node.func, ast.Attribute):
            return node.func.attr
        return ""
```

## 3. Executor (app/sandbox/executor.py)

Выполнение кода через RestrictedPython с ограничением ресурсов.

```python
import resource
import signal
from RestrictedPython import compile_restricted, safe_globals
from RestrictedPython.Eval import default_guarded_getiter, default_guarded_getitem
from RestrictedPython.Guards import guarded_unpack_sequence, safer_getattr

@dataclass
class ExecutionResult:
    success: bool
    output: str = ""
    error: str = ""

class CodeSandbox:
    """Безопасное выполнение Python-кода стратегий."""

    MAX_EXECUTION_TIME: int = 30   # секунд
    MAX_MEMORY: int = 512 * 1024 * 1024  # 512 MB

    def __init__(self):
        self.analyzer = ASTAnalyzer()

    async def validate(self, code: str) -> AnalysisResult:
        """Только AST-анализ, без выполнения."""
        return self.analyzer.analyze(code)

    async def execute(self, code: str, timeout: int | None = None) -> ExecutionResult:
        """AST-анализ + компиляция RestrictedPython + выполнение."""
        timeout = timeout or self.MAX_EXECUTION_TIME

        # Шаг 1: AST-анализ
        analysis = self.analyzer.analyze(code)
        if not analysis.is_safe:
            return ExecutionResult(
                success=False,
                error=f"Код не прошёл проверку безопасности: {'; '.join(analysis.issues)}"
            )

        # Шаг 2: Компиляция через RestrictedPython
        try:
            compiled = compile_restricted(code, '<strategy>', 'exec')
            if compiled.errors:
                return ExecutionResult(
                    success=False,
                    error=f"Ошибка компиляции: {'; '.join(compiled.errors)}"
                )
        except Exception as e:
            return ExecutionResult(success=False, error=f"Ошибка компиляции: {e}")

        # Шаг 3: Подготовка безопасного окружения
        restricted_globals = safe_globals.copy()
        restricted_globals['_getiter_'] = default_guarded_getiter
        restricted_globals['_getitem_'] = default_guarded_getitem
        restricted_globals['_unpack_sequence_'] = guarded_unpack_sequence
        restricted_globals['_getattr_'] = safer_getattr

        # Разрешённые модули
        import math, decimal, datetime
        restricted_globals['math'] = math
        restricted_globals['Decimal'] = decimal.Decimal
        restricted_globals['datetime'] = datetime

        # Шаг 4: Выполнение с ограничениями
        output_lines: list[str] = []
        restricted_globals['_print_'] = lambda: lambda *args: output_lines.append(' '.join(str(a) for a in args))

        try:
            # Ограничение ресурсов (только Unix)
            old_handler = signal.signal(signal.SIGALRM, self._timeout_handler)
            signal.alarm(timeout)

            exec(compiled, restricted_globals)

            signal.alarm(0)  # отменить alarm
            signal.signal(signal.SIGALRM, old_handler)

            return ExecutionResult(success=True, output='\n'.join(output_lines))

        except TimeoutError:
            return ExecutionResult(
                success=False,
                error=f"Превышено время выполнения ({timeout}с)"
            )
        except Exception as e:
            return ExecutionResult(success=False, error=f"Ошибка выполнения: {e}")

    @staticmethod
    def _timeout_handler(signum, frame):
        raise TimeoutError("Execution timed out")
```

## 4. Схемы (app/sandbox/schemas.py)

```python
from pydantic import BaseModel

class CodeAnalyzeRequest(BaseModel):
    code: str

class AnalyzeResponse(BaseModel):
    is_valid: bool
    issues: list[str]

class CodeExecuteRequest(BaseModel):
    code: str
    timeout: int | None = None  # секунд, max 30

class ExecuteResponse(BaseModel):
    success: bool
    output: str = ""
    error: str = ""
```

## 5. Роутер (app/sandbox/router.py)

```python
router = APIRouter()

@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_code(
    request: CodeAnalyzeRequest,
    current_user = Depends(get_current_user),
):
    """AST-анализ кода без выполнения."""
    sandbox = CodeSandbox()
    result = await sandbox.validate(request.code)
    return AnalyzeResponse(is_valid=result.is_safe, issues=result.issues)

@router.post("/execute", response_model=ExecuteResponse)
async def execute_code(
    request: CodeExecuteRequest,
    current_user = Depends(get_current_user),
):
    """Выполнение кода в песочнице."""
    sandbox = CodeSandbox()
    result = await sandbox.execute(request.code, request.timeout)
    return ExecuteResponse(
        success=result.success,
        output=result.output,
        error=result.error
    )
```

## 6. Тесты (tests/unit/test_sandbox/)

```
tests/unit/test_sandbox/
├── __init__.py
├── test_ast_analyzer.py
├── test_executor.py
└── test_router.py
```

**Минимальные тест-кейсы:**

### test_ast_analyzer.py
- `test_safe_code_passes` — чистый код со стратегией Backtrader проходит
- `test_import_os_blocked` — `import os` → is_safe=False
- `test_import_subprocess_blocked` — `import subprocess` → blocked
- `test_open_file_blocked` — `open('file.txt')` → blocked
- `test_eval_blocked` — `eval('1+1')` → blocked
- `test_exec_blocked` — `exec('print(1)')` → blocked
- `test_dunder_blocked` — `__builtins__` → blocked
- `test_allowed_imports` — `import backtrader`, `import pandas`, `import numpy` → OK
- `test_syntax_error` — невалидный Python → is_safe=False с описанием ошибки
- `test_multiple_issues` — код с несколькими проблемами → все issues перечислены

### test_executor.py
- `test_safe_code_executes` — простой код выполняется успешно
- `test_unsafe_code_rejected` — код с `import os` не выполняется
- `test_output_captured` — print() внутри sandbox → output содержит текст
- `test_timeout` — бесконечный цикл прерывается по таймауту

### test_router.py
- `test_analyze_safe_code_200` — POST /sandbox/analyze с чистым кодом → 200
- `test_analyze_unsafe_code_200` — POST /sandbox/analyze с import os → 200, is_valid=false
- `test_analyze_requires_auth` — POST без токена → 401
- `test_execute_safe_code_200` — POST /sandbox/execute → 200, success=true

# Что НЕ делать

- **НЕ** реализуй CSRF или Rate Limiting — это задача DEV-4
- **НЕ** реализуй Code Generator — это задача DEV-5
- **НЕ** трогай frontend — это задачи DEV-2 и DEV-6
- **НЕ** трогай модуль стратегий — это задача DEV-1

# Артефакты

По завершении:
1. `app/sandbox/ast_analyzer.py` — AST-анализатор
2. `app/sandbox/executor.py` — CodeSandbox с RestrictedPython
3. `app/sandbox/schemas.py` — Pydantic-схемы
4. `app/sandbox/router.py` — API endpoints (/analyze, /execute)
5. `app/sandbox/__init__.py`
6. RestrictedPython в pyproject.toml
7. Sandbox router подключён в main.py
8. `tests/unit/test_sandbox/` — ≥14 тестов
9. **Все тесты проходят:** `pytest tests/ -v` → 0 failures
