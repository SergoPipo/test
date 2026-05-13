# MOEX Trading Terminal

> **Статус:** M4 ✅ Production-ready (Sprint 8 закрыт 2026-05-13).
> **Версия документации:** ФТ v2.5 · ТЗ v1.5 · Deployment Guide v1.0.

Веб-приложение — торговый терминал для рынка ценных бумаг Московской биржи (MOEX). Позволяет создавать торговые стратегии (AI-чат или Blockly-редактор), тестировать на исторических данных и запускать в реальную или paper-торговлю через брокерский API Тинькофф Инвестиций (T-Invest).

---

## Quick Start (для разработки)

```bash
# 1. Клонировать репозиторий
git clone <REPO_URL> moex-terminal && cd moex-terminal

# 2. Установить системные зависимости (macOS, Apple Silicon или Intel)
./setup_macos.sh         # ta-lib + pango + cairo + Python 3.11 + Node 24

# 3. Запустить локально (backend + frontend в dev-режиме)
./restart_dev.sh         # bash скрипт стартует uvicorn + vite через Procfile
# либо вручную:
cd Develop/backend && source .venv/bin/activate && uvicorn app.main:app --reload &
cd Develop/frontend && pnpm dev
```

Открыть `http://localhost:5173` в браузере → FirstRunWizard для первого входа.

Подробнее по установке для разработки — см. [`Develop/backend/INSTALL.md`](Develop/backend/INSTALL.md).

---

## Production deployment

Для развёртывания на Mac mini с auto-start, Cloudflare Tunnel SSL и автоматическими бэкапами:

➜ **[Документация по проекту/deployment_guide.md](Документация%20по%20проекту/deployment_guide.md)** (Docker compose + launchd + Cloudflare Tunnel).

```bash
cd Develop
docker compose build
docker compose up -d
```

---

## Структура репозитория

```
Test/                                  ← public монорепо (документация + спринты)
├── README.md                          ← этот файл
├── setup_macos.sh                     ← bootstrap-скрипт для macOS dev
├── restart_dev.sh                     ← перезапуск dev-окружения
├── Документация по проекту/           ← ТЗ, ФТ, API-документация, deployment guide
│   ├── functional_requirements.md     ← ФТ v2.5
│   ├── technical_specification.md     ← ТЗ v1.5
│   ├── development_plan.md            ← дорожная карта (M1..M4)
│   ├── deployment_guide.md            ← НОВОЕ S8 W3: Mac mini + Docker + launchd + CF Tunnel
│   ├── launchd/                       ← com.moex.terminal.plist
│   └── tinvest_api_*.md               ← T-Invest API референсы
├── Спринты/                           ← планирование и трекинг
│   ├── project_state.md               ← главная точка входа: текущий статус проекта
│   ├── Sprint_N/                      ← файлы спринта (planning, prompts, changelog, state)
│   └── Sprint_N_Review/               ← ревью после каждых 2 спринтов
└── Develop/                           ← вложенное private репо с кодом (свой git)
    ├── docker-compose.yml             ← НОВОЕ S8 W3
    ├── Dockerfile.backend             ← НОВОЕ S8 W3
    ├── nginx.conf                     ← НОВОЕ S8 W3
    ├── CLAUDE.md                      ← конвенции и плагины
    ├── stack_gotchas/                 ← реестр стековых ловушек (30 шт. на 2026-05-13)
    ├── backend/                       ← FastAPI + SQLAlchemy + APScheduler
    └── frontend/                      ← React 19 + Vite + Mantine + Blockly + Lightweight Charts
```

---

## Технологический стек

### Backend
- **Python 3.11** + FastAPI + Uvicorn — async REST API + WebSocket
- **SQLAlchemy (async)** + Alembic + SQLite (WAL-режим)
- **Pydantic** — валидация и сериализация
- **PyJWT** + Argon2id + AES-256-GCM (cryptography) — auth и хранение broker-токенов
- **RestrictedPython** — Code Sandbox для пользовательских стратегий
- **APScheduler** — MOEX-календарь, корп. действия, T+1 unblock, backup_job
- **tinkoff-investments** (gRPC) — broker T-Invest
- **structlog** — структурированное логирование с `@timed_event` декоратором

### Frontend
- **React 19** + TypeScript + Vite — SPA
- **Mantine 7** (UI, dark theme) + Tabler Icons
- **Zustand** — state management
- **TradingView Lightweight Charts** — свечные графики + drawing tools
- **Google Blockly** — блочный редактор стратегий
- **TanStack Table, Axios, React Router, dayjs**
- **Vitest + Playwright** — unit + E2E тесты
- **pnpm** — менеджер пакетов

### DevOps (S8 W3)
- **Docker Compose v2** — production stack
- **nginx-alpine** — reverse proxy + SPA static
- **launchd** — auto-start на Mac mini
- **Cloudflare Tunnel** — TLS termination + публичный домен
- **GitHub Actions** — CI (Node 24, Python 3.11, coverage gate ≥ 80%, bandit, safety)

---

## Тестовый baseline (Sprint 8 W2 финал — 2026-05-13)

| Слой | Метрика | Статус |
|------|---------|--------|
| Backend pytest | 1490 passed / 0 failed / 0 xfailed | ✅ |
| Backend coverage TOTAL | 80% (CI gate `--cov-fail-under=80` активен) | ✅ |
| Backend ruff | 0 issues | ✅ |
| Backend mypy | 0 errors | ✅ |
| Backend bandit | 0 medium+ severity | ✅ |
| Backend safety | 1 documented CVE (protobuf транзитив, принят) | ✅ |
| Frontend vitest | 544 passed / 2 pre-existing flaky | ✅ |
| Frontend tsc | 0 errors | ✅ |
| Frontend lint | 0 errors / 9 warnings (W3 cleanup в работе) | ⚠️ |
| Playwright nightly | 158 passed / 1 pre-existing flaky / 5 skipped | ✅ |

---

## Ссылки

- **[Функциональные требования (ФТ v2.5)](Документация%20по%20проекту/functional_requirements.md)** — все фичи и сценарии.
- **[Техническое задание (ТЗ v1.5)](Документация%20по%20проекту/technical_specification.md)** — архитектура, schema, deployment.
- **[План разработки](Документация%20по%20проекту/development_plan.md)** — дорожная карта M1 → M4 → W4 roadmap.
- **[Deployment Guide](Документация%20по%20проекту/deployment_guide.md)** — Mac mini installation.
- **[Состояние проекта](Спринты/project_state.md)** — единая точка входа для статуса.
- **[Stack Gotchas Index](Develop/stack_gotchas/INDEX.md)** — реестр стековых ловушек (30 шт.).
- **[Develop/CLAUDE.md](Develop/CLAUDE.md)** — конвенции, правила плагинов, структура кода.

---

## Контакты

Контакты заказчика: nazarychev.s@gmail.com (по согласованию).

Лицензия: проприетарная.
