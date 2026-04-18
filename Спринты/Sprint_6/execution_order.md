# Sprint 6 — Execution Order

> Волновая параллелизация DEV-агентов (как S3–S5).
> Внутри волны — агенты запускаются параллельно через `Agent(run_in_background, isolation: "worktree")`.
> Между волнами — мерж в develop + тесты = 0 failures.

## Статус

- **Спринт:** ⚠️ почти завершён (DEV-7 pending)
- **Активная фаза:** Волна 3 — ARCH ✅, DEV-7 ⬜ pending
- **Следующая фаза:** приёмка DEV-7 → закрытие S6

---

## Визуализация параллелизма

```
Волна 0 ─── DEV-0 (багфикс _underscore) ──────────────────────── мерж + тесты
              │
Волна 1 ─┬── DEV-1 (In-app + Recovery + Shutdown) ─────────┐
          ├── DEV-2 (Telegram + Email) ─────────────────────┤── мерж + тесты
          └── DEV-3 (T-Invest SDK upgrade) ─────────────────┘
              │
Волна 2 ─┬── DEV-4 (Frontend Notification Center) ─────────┐
          ├── DEV-5 (T-Invest Stream Multiplex) ────────────┤── мерж + тесты
          └── DEV-6 (E2E инфраструктура) ───────────────────┘
              │
Волна 3 ─┬── DEV-7 (E2E S6 + Security) ───────────────────┐
          └── ARCH (финальное ревью) ───────────────────────┘── закрытие S6
```

---

## Волна 0: Preflight + Критический багфикс (serial, blocker)

| Шаг | Задача | Prompt | Зависит от |
|-----|--------|--------|------------|
| 0.1 | Preflight: baseline тесты (pytest + pnpm test + lint) | — | — |
| 0.2 | S6-STRATEGY-UNDERSCORE-NAMES — переименование `_`-переменных в code_generator.py | prompt_DEV-0.md | 0.1 |

**ПРАВИЛО 0:** Волна 1 НЕ ЗАПУСКАЕТСЯ пока:
- ✓ DEV-0 смержен в develop
- ✓ `pytest tests/` = 0 failures
- ✓ `pnpm test` = 0 failures

---

## Волна 1: Backend ядро (3 параллельных DEV-агента)

| Шаг | Задача | Prompt | Зависит от | Режим |
|-----|--------|--------|------------|-------|
| 1.1 | 6.3 In-app WS + 6.4 Recovery + 6.5 Graceful Shutdown | prompt_DEV-1.md | Волна 0 | background, worktree |
| 1.2 | 6.1 Telegram + 6.2 Email | prompt_DEV-2.md | Волна 0 | background, worktree |
| 1.3 | S6-TINVEST-SDK-UPGRADE (beta117+) | prompt_DEV-3.md | Волна 0 | background, worktree |

**ПРАВИЛО 1:** DEV-1 и DEV-2 координируются через контракт `NotificationService`.
При мерже: DEV-1 первый, DEV-2 вторым (DEV-2 расширяет service, созданный DEV-1).

**ПРАВИЛО 2:** Волна 2 НЕ ЗАПУСКАЕТСЯ пока:
- ✓ Все DEV волны 1 смержены в develop (порядок: DEV-1 → DEV-2 → DEV-3)
- ✓ `pytest tests/` = 0 failures
- ✓ `pnpm test` = 0 failures

---

## Волна 2: Frontend + Stream Multiplex + E2E infra (3 параллельных DEV-агента)

| Шаг | Задача | Prompt | Зависит от | Режим |
|-----|--------|--------|------------|-------|
| 2.1 | 6.7 Notification Center + 6.8 Trading Panel fixes | prompt_DEV-4.md | DEV-1 (API + WS) | background, worktree |
| 2.2 | S6-TINVEST-STREAM-MULTIPLEX (persistent gRPC) | prompt_DEV-5.md | DEV-3 (SDK upgrade) | background, worktree |
| 2.3 | PLAYWRIGHT-NIGHTLY + E2E-CHART-MOCK-ISS + MOCKS-EXPANSION | prompt_DEV-6.md | Волна 1 | background, worktree |

**ПРАВИЛО 3:** Волна 3 НЕ ЗАПУСКАЕТСЯ пока:
- ✓ Все DEV волны 2 смержены в develop
- ✓ `pytest tests/` = 0 failures
- ✓ `pnpm test` = 0 failures

---

## Волна 3: E2E тесты S6 + Security + ARCH (2 параллельных)

| Шаг | Задача | Prompt | Зависит от | Режим |
|-----|--------|--------|------------|-------|
| 3.1 | 6.9 E2E тесты S6 + 6.10 Security | prompt_DEV-7.md | Волна 2 | background, worktree |
| 3.2 | ARCH ревью + закрытие S6 | prompt_ARCH_review.md | Волна 2 | foreground |

---

## ⚠️ Cross-DEV Contracts

### Контракты Волна 1

| Поставщик | Потребитель | Контракт | Формат/сигнатура |
|-----------|-------------|----------|------------------|
| DEV-1 | DEV-2 (волна 1), DEV-4 (волна 2) | `NotificationService.create_notification()` | `async (db, user_id: int, event_type: str, title: str, body: str, severity: str) → Notification` |
| DEV-1 | DEV-4 (волна 2) | REST API `/api/v1/notifications/*` | GET /notifications, GET /unread-count, PATCH /{id}/read, PUT /settings |
| DEV-1 | DEV-4 (волна 2) | WS канал `notifications:{user_id}` | JSON: `{id, event_type, title, body, severity, created_at}` |
| DEV-2 | DEV-1 (волна 1) | Telegram/Email dispatch | `service.dispatch_external(notification, settings) → channels_sent: list[str]` |

### Контракты Волна 1 → Волна 2

| Поставщик | Потребитель | Контракт | Формат/сигнатура |
|-----------|-------------|----------|------------------|
| DEV-3 | DEV-5 (волна 2) | Обновлённый SDK beta117+ | `from tinkoff.invest import AsyncClient, ...` — 9 классов |
| DEV-1 | DEV-4 (волна 2) | Notification schemas | `NotificationResponse(id, event_type, title, body, severity, is_read, created_at)` |

---

## Задачи, исключённые из S6 (закрыты в S5R)

| Задача | Закрыта в | Причина исключения |
|--------|-----------|-------------------|
| 6.0 Live Runtime Loop | S5R.2 | SessionRuntime полностью реализован |
| 6.9 (старая) Реальные позиции | S5R.3 | get_real_positions() + FIGI source |
| 6.11 FIGI в LiveTrade | S5R closeout #9 | source через FIGI |

---

## Чек-лист планирования

- [x] execution_order.md создан
- [x] sprint_state.md создан
- [x] preflight_checklist.md создан
- [x] prompt_DEV-0.md создан (волна 0)
- [x] prompt_DEV-1.md создан (волна 1) — 2026-04-17
- [x] prompt_DEV-2.md создан (волна 1) — 2026-04-17
- [x] prompt_DEV-3.md создан (волна 1) — 2026-04-17
- [x] prompt_DEV-4.md создан (волна 2) — 2026-04-17
- [x] prompt_DEV-5.md создан (волна 2) — 2026-04-17
- [x] prompt_DEV-6.md создан (волна 2) — 2026-04-17
- [x] prompt_DEV-7.md создан (волна 3) — 2026-04-17
- [x] prompt_ARCH_review.md создан (волна 3) — 2026-04-17
- [x] project_state.md обновлён — S6 🔄 — 2026-04-17
