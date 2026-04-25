# Sprint 7 — Preflight Checklist

> Чеклист выполняется ДО старта W0. Любая красная строка — стоп.

## 1. Системное окружение

- [ ] Python ≥ 3.11: `python3 --version`
- [ ] Node.js ≥ 18: `node --version`
- [ ] pnpm установлен: `pnpm --version`
- [ ] git clean: `git status` → working tree clean
- [ ] Текущая ветка корневого репо: `docs/sprint-7-plan` (или согласованная)

## 2. Backend (Develop/backend/)

- [ ] Виртуальное окружение активировано: `source .venv/bin/activate`
- [ ] Зависимости установлены: `pip install -r requirements.txt -r requirements-dev.txt` без ошибок
- [ ] Alembic в актуальной версии: `alembic upgrade head`
- [ ] Baseline тесты зелёные: `pytest tests/ -q` → 0 failures (число тестов сохранить в отчёте)
- [ ] Линтер чистый: `ruff check app/` → no issues
- [ ] Type-check чистый: `pyright app/` → 0 errors (или fallback `python -m py_compile`)

## 3. Frontend (Develop/frontend/)

- [ ] Зависимости установлены: `pnpm install` без ошибок
- [ ] Type-check: `npx tsc --noEmit` → 0 errors
- [ ] Линтер: `pnpm lint` → no issues
- [ ] Юнит-тесты: `pnpm test` → 0 failures

## 4. E2E инфраструктура

> Правило памяти `feedback_e2e_testing.md`: 5 шагов цикла — описание → инфра → написание → запуск → верификация. Этот раздел отвечает за «инфра».

- [ ] Playwright установлен: `npx playwright --version`
- [ ] Браузеры установлены: `npx playwright install` (chromium минимум)
- [ ] Конфиг существует: `playwright.config.ts` доступен
- [ ] Backend поднимается: `cd Develop/backend && uvicorn app.main:app` запускается без ошибок
- [ ] Frontend поднимается: `cd Develop/frontend && pnpm dev` запускается без ошибок
- [ ] Тестовый аккаунт `sergopipo` доступен (правило памяти `user_test_credentials.md`; пароль у заказчика)
- [ ] Baseline E2E прогон зелёный: `npx playwright test` → 119 passed / 0 failed / 3 skipped (S6 Review baseline)

## 5. Документация и память

- [ ] `Спринты/project_state.md` прочитан
- [ ] `Sprint_7/sprint_design.md` прочитан полностью
- [ ] `Sprint_7/sprint_state.md` отражает текущее состояние
- [ ] `Develop/CLAUDE.md` прочитан (правила плагинов, Stack Gotchas)
- [ ] `Develop/stack_gotchas/INDEX.md` пройден (15+ ловушек на момент старта S7)

## 6. Внешние сервисы

- [ ] T-Invest sandbox доступен (для проверок 7.13 connection_lost/restored)
- [ ] MOEX ISS отвечает: `curl https://iss.moex.com/iss/index.json`
- [ ] SMTP настроен в `.env` (для 7.13 email-уведомлений на partial_fill, order_error)
- [ ] Telegram bot токен настроен в `.env` (для 7.14 callback handler)

## 7. Two-repo branching

> Правило памяти `feedback_two_repos.md`: Develop/ — отдельный репозиторий (private moex-terminal). Корневой Test — public.
> При коммитах нужно подтверждать ветки **отдельно** для каждого.

- [ ] Корневой репо ветка: `docs/sprint-7-plan` (подтверждена заказчиком)
- [ ] Develop/ ветка: согласовать перед стартом DEV-агентов (не делать commit в Develop/ без подтверждения)

## Финиш

Все строки выше — ✅ → можно стартовать W0 (запустить ARCH design, UX макеты, QA test plan параллельно).
