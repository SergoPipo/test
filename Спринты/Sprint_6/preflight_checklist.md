# Sprint 6 — Preflight Checklist

> Выполнить перед КАЖДОЙ DEV-сессией и на каждом merge gate.
> Зафиксировать **реальные результаты** (не «ожидается ~N»).

## Backend

```bash
cd Develop/backend

# 1. Python version
python --version                    # >= 3.11

# 2. Зависимости
pip list | grep -E "fastapi|sqlalchemy|pyjwt|argon2"

# 3. Миграции
alembic upgrade head                # должно пройти без ошибок
alembic check                       # "No new upgrade operations detected" (или список)

# 4. Lint
ruff check .                        # Зафиксировать: N errors / N warnings

# 5. Type check
mypy app/ --ignore-missing-imports  # Зафиксировать: N errors

# 6. Unit тесты
pytest tests/ -x -q                 # Зафиксировать: X passed, Y failed, Z skipped

# 7. T-Invest SDK (проверка наличия)
python -c "import tinkoff.invest; print('OK')" 2>&1  # OK или ModuleNotFoundError
```

## Frontend

```bash
cd Develop/frontend

# 1. Node version
node --version                      # >= 18

# 2. Зависимости
pnpm install --frozen-lockfile      # должно пройти

# 3. Lint
pnpm lint                           # Зафиксировать: N errors / N warnings

# 4. Type check
pnpm tsc --noEmit                   # Зафиксировать: 0 errors или N errors

# 5. Unit тесты
pnpm test -- --run                  # Зафиксировать: X passed / Y failed (Z files)

# 6. Playwright (опционально, при наличии запущенного backend)
npx playwright test --project=chromium  # Зафиксировать: X passed / Y failed / Z skipped
```

## Результаты Preflight (заполнить при запуске)

| Проверка | Результат | Дата |
|----------|-----------|------|
| Python version | | |
| alembic upgrade head | | |
| ruff check | | |
| mypy | | |
| pytest | | |
| T-Invest SDK | | |
| Node version | | |
| pnpm lint | | |
| tsc --noEmit | | |
| pnpm test (vitest) | | |
| Playwright | | |

## Критерий прохождения

- **pytest:** 0 failed (skipped допустимы с тикетом)
- **pnpm test:** 0 failed
- **ruff:** 0 errors (warnings допустимы)
- **tsc:** 0 errors
- **lint:** 0 errors (warnings допустимы)

Если preflight не проходит — **НЕ начинать** DEV-сессию. Исправить baseline первым.
