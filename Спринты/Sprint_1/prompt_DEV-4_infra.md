---
sprint: 1
agent: DEV-4
role: DevOps / Infra (OPS)
wave: 1
depends_on: []
---

# Роль

Ты — DevOps-специалист. Создай скрипты установки, запуска и CI/CD pipeline.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

Перед началом работы **обязательно** проверь:

```
1. Python >= 3.11 установлен (python3 --version)
2. Node.js >= 18 установлен (node --version)
3. pnpm >= 9 установлен (pnpm --version)
4. Git установлен (git --version)
5. Директории backend/ и frontend/ существуют
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-4 не может начать работу."

# Рабочая директория

`Test/Develop/`

# Задачи

## 1. Скрипт установки (scripts/install.sh)

```bash
#!/bin/bash
# Проверяет: Python >= 3.11, Node >= 18, pnpm
# Backend:
#   - Создаёт venv в backend/.venv
#   - pip install -e backend/[dev]
#   - Применяет миграции: alembic upgrade head
# Frontend:
#   - cd frontend && pnpm install
# Создаёт .env из .env.example если не существует
# Создаёт директорию data/ для SQLite
```

## 2. Скрипт запуска (scripts/start.sh)

```bash
#!/bin/bash
# Запускает backend + frontend параллельно:
# Backend: cd backend && .venv/bin/uvicorn app.main:app --reload --port 8000
# Frontend: cd frontend && pnpm dev --port 5173
# Использует trap для graceful shutdown обоих процессов
# Альтернатива: Procfile для Honcho
```

## 3. .env.example

```env
# Database
DATABASE_URL=sqlite+aiosqlite:///./data/terminal.db

# Security
SECRET_KEY=change-me-in-production
ENCRYPTION_KEY=CHANGE_ME_must_be_exactly_32_b!

# JWT
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# AI Provider
AI_PROVIDER=claude
AI_API_KEY=

# Telegram
TELEGRAM_BOT_TOKEN=

# MOEX
MOEX_ISS_BASE_URL=https://iss.moex.com

# Debug
DEBUG=true
```

## 4. Procfile (опционально)

```
backend: cd backend && .venv/bin/uvicorn app.main:app --reload --port 8000
frontend: cd frontend && pnpm dev --port 5173
```

## 5. CI/CD — GitHub Actions (.github/workflows/ci.yml)

```yaml
name: CI
on: [push, pull_request]
jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          cd backend
          pip install -e .[dev]
      - name: Lint (ruff)
        run: cd backend && ruff check .
      - name: Type check (mypy)
        run: cd backend && mypy app/ --ignore-missing-imports
      - name: Unit tests
        run: cd backend && pytest tests/unit/ -v

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'
          cache-dependency-path: frontend/pnpm-lock.yaml
      - name: Install dependencies
        run: cd frontend && pnpm install
      - name: Lint (eslint)
        run: cd frontend && pnpm lint
      - name: Type check (tsc)
        run: cd frontend && pnpm tsc --noEmit
      - name: Unit tests
        run: cd frontend && pnpm test
```

## 6. Dev-зависимости в backend/pyproject.toml

Добавь секцию `[project.optional-dependencies]`:

```toml
[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "pytest-cov>=5.0",
    "ruff>=0.3",
    "mypy>=1.9",
    "httpx>=0.27",  # для TestClient
]
```

## 7. Frontend lint config

- `frontend/.eslintrc.cjs` — базовый ESLint для React + TypeScript
- Обновить `frontend/package.json` scripts:
  ```json
  {
    "scripts": {
      "dev": "vite",
      "build": "tsc && vite build",
      "lint": "eslint src/ --ext .ts,.tsx",
      "preview": "vite preview"
    }
  }
  ```

## 8. .gitignore

```gitignore
# Python
__pycache__/
*.pyc
.venv/
*.egg-info/
dist/

# Frontend
node_modules/
frontend/dist/

# Data
data/
*.db

# Env
.env

# IDE
.vscode/
.idea/

# OS
.DS_Store
```

## 9. Тесты

Ты отвечаешь за тестирование своих скриптов. Проведи самопроверку:

### Ручная верификация (выполни и убедись)

```bash
# 1. install.sh — проверка
chmod +x scripts/install.sh
./scripts/install.sh
# Ожидание: backend venv создан, pip install ok, frontend pnpm install ok

# 2. start.sh — проверка
chmod +x scripts/start.sh
./scripts/start.sh &
sleep 5
curl http://localhost:8000/api/v1/health  # Ожидание: 200
curl http://localhost:5173                  # Ожидание: HTML страница
kill %1

# 3. CI — валидация YAML
# Проверь: корректный YAML синтаксис, все шаги присутствуют
```

### Добавь в CI запуск frontend-тестов

Обнови `.github/workflows/ci.yml` — добавь шаг `pnpm test` в секцию frontend:

```yaml
      - name: Unit tests
        run: cd frontend && pnpm test
```

# Критерий завершения

- `./scripts/install.sh` выполняется без ошибок (при наличии Python 3.11+, Node 18+, pnpm)
- `./scripts/start.sh` запускает backend + frontend
- `.env.example` содержит все переменные
- `.github/workflows/ci.yml` корректен (lint + type check + **tests** для обоих)
- `.gitignore` на месте
- **Ручная верификация: install.sh + start.sh + health check пройдены**
