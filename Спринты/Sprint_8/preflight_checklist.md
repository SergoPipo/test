# Sprint 8 — Preflight checklist

> Чек окружения перед стартом W0. Все пункты должны быть ✅ до запуска ARCH-агента.

## Окружение

- [ ] Python 3.11 активен в `Develop/backend/.venv` (`.venv/bin/python --version`)
- [ ] Node 20+ и pnpm 9+ установлены (`node -v`, `pnpm -v`)
- [ ] Playwright Chromium установлен (`npx playwright --version`)
- [ ] T-Invest SDK 0.2.0-beta117 установлен (см. Develop/CLAUDE.md «Системные зависимости»)
- [ ] Системные зависимости для WeasyPrint (pango/cairo/gdk-pixbuf) на месте (`brew list pango cairo`)

## Репозиторий

- [ ] Текущая ветка Develop: `develop` или ветка `s8/sprint-8`, синхронизирована с origin
- [ ] Текущая ветка Test (внешний): `docs/sprint-8` или `docs/sprint-7-plan`, синхронизирована
- [ ] Working tree обоих репо чистый (`git status` пустой)

## Тестовый baseline

- [ ] `cd Develop/backend && .venv/bin/pytest tests/` — 0 failed
- [ ] `cd Develop/backend && .venv/bin/ruff check .` — All checks passed
- [ ] `cd Develop/backend && .venv/bin/mypy app/ --ignore-missing-imports` — 0 errors
- [ ] `cd Develop/frontend && pnpm vitest run` — 0 failed
- [ ] `cd Develop/frontend && pnpm tsc --noEmit` — 0 errors
- [ ] `cd Develop/frontend && pnpm lint` — 0 errors (warnings допустимы, фиксятся S8 backlog'ом)

## CI

- [ ] Последний CI на `develop` — зелёный (`gh run list --workflow=ci.yml --limit 1`)
- [ ] Последний Playwright nightly на `develop` — зелёный (`gh run list --workflow=playwright-nightly.yml --limit 1`)

## Документация

- [ ] `Спринты/project_state.md` обновлён до 2026-05-12 (Sprint 7 финал, Sprint 8 started)
- [ ] `Sprint_7/changelog.md` имеет финальную запись «Sprint 7 final closeout»
- [ ] `Sprint_7/sprint_state.md` отмечает final closeout 2026-05-12
- [ ] `Sprint_8_Review/backlog.md` прочитан целиком — все 25+ карточек понятны

## Прочее

- [ ] Заказчик подтвердил готовность к S8 (feature freeze: новые фичи отложены, фокус на стабилизации)
- [ ] Доступ к T-Invest sandbox + production API настроен для security audit
- [ ] План на «Проверки будущих спринтов» из `project_state.md` секция «S8 Review» прочитан — 13 event_type верификация запланирована
