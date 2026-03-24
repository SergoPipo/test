# Порядок выполнения — Спринт 1

> Единый файл: кто, когда, от чего зависит, какой промпт читать.
>
> **Сессия прервалась?** → Читай [sprint_state.md](sprint_state.md) — там текущий прогресс и следующее действие.

---

## Диаграмма

```
  PREFLIGHT ──────────────────────────────────────────────────────────
  │ Проверка: Python, Node, pnpm, Git, промпты, git repo
  │ Файл: preflight_checklist.md
  ▼
  ┌─────────────────┐   ┌─────────────┐   ┌─────────────┐
  │ ① UX            │   │ ② DEV-1     │   │ ③ DEV-2     │
  │ UI/UX-дизайн    │   │ Backend     │   │ DB-модели   │
  │ [foreground]    │   │ [background]│   │ [background]│
  │ prompt_UX.md    │   │ prompt_DEV- │   │ prompt_DEV- │
  │                 │   │ 1_backend.md│   │ 2_db.md     │
  │ Диалог с вами.  │   └──────┬──────┘   └──────┬──────┘
  │ Результат:      │          │                  │
  │ → ui_spec.md    │   ┌──────┴──────┐           │
  └────────┬────────┘   │ ④ DEV-4     │           │
           │            │ Infra/CI    │           │
           │            │ [background]│           │
           │            │ prompt_DEV- │           │
           │            │ 4_infra.md  │           │
           │            └──────┬──────┘           │
           │                   │                  │
           │      ┌────────────┴──────────────────┘
           │      │
  ─────────▼──────▼───── МЕРЖ backend в develop ─────────────────────
  │                      + проверка: pytest = 0 failures
  │
  │  БЛОКЕР: ui_spec.md должен существовать
  ▼
  ┌─────────────────┐
  │ ⑤ DEV-3         │
  │ Frontend        │
  │ [background]    │
  │ prompt_DEV-3_   │
  │ frontend.md     │
  │                 │
  │ Реализует UI    │
  │ по ui_spec.md   │
  └────────┬────────┘
           │
  ─────────▼───────── МЕРЖ frontend в develop ───────────────────────
  │                   + проверка: pnpm test = 0 failures
  │
  │  БЛОКЕР: DEV-1 + DEV-2 должны быть в develop
  ▼
  ┌─────────────────┐
  │ ⑥ DEV-5         │
  │ Auth (Security) │
  │ [background]    │
  │ prompt_DEV-5_   │
  │ auth.md         │
  └────────┬────────┘
           │
  ─────────▼───────── МЕРЖ auth в develop ───────────────────────────
  │
  ▼
  ┌─────────────────┐
  │ ⑦ ARCH          │
  │ Техархитектор   │
  │ [foreground]    │
  │ prompt_ARCH_    │
  │ review.md       │
  │                 │
  │ Ревью всего     │
  │ кода + тесты    │
  └────────┬────────┘
           │
           ├── Замечания? → FIX-агенты → повторное ревью ARCH
           │
  ─────────▼───────── ВАШ РЕВЬЮ ─────────────────────────────────────
  │
  │  Вы задаёте вопросы ARCH, запрашиваете доработки
  │
  ─────────▼───────── ФИНАЛЬНЫЙ МЕРЖ в develop ──────────────────────
  │
  ▼
  sprint_report.md ← итоговый отчёт по спринту
```

---

## Таблица выполнения

| Шаг | Агент | Промпт | Волна | Зависимости | Создаёт артефакт | Режим |
|-----|-------|--------|-------|-------------|------------------|-------|
| 0 | — | preflight_checklist.md | — | Нет | Отчёт preflight | Автоматически |
| 1 | **UX** | [prompt_UX.md](prompt_UX.md) | 0 | Нет | **ui_spec.md** | foreground (диалог с вами) |
| 2 | **DEV-1** | [prompt_DEV-1_backend.md](prompt_DEV-1_backend.md) | 1 | Нет | Код backend + тесты | background, worktree |
| 3 | **DEV-2** | [prompt_DEV-2_db.md](prompt_DEV-2_db.md) | 1 | Нет | Модели + миграции + тесты | background, worktree |
| 4 | **DEV-4** | [prompt_DEV-4_infra.md](prompt_DEV-4_infra.md) | 1 | Нет | CI/CD + скрипты | background, worktree |
| — | — | — | — | МЕРЖ волны 1 в develop | — | — |
| 5 | **DEV-3** | [prompt_DEV-3_frontend.md](prompt_DEV-3_frontend.md) | 2 | **ui_spec.md** утверждён | Код frontend + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 2 в develop | — | — |
| 6 | **DEV-5** | [prompt_DEV-5_auth.md](prompt_DEV-5_auth.md) | 3 | DEV-1 + DEV-2 в develop | Auth module + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 3 в develop | — | — |
| 7 | **ARCH** | [prompt_ARCH_review.md](prompt_ARCH_review.md) | review | Все DEV завершили | Отчёт ревью + тесты | foreground |
| 8 | **ВЫ** | — | review | ARCH одобрил | Решение о мерже → МЕРЖ в develop | — |
| 9 | — | sprint_report_template.md | — | Всё смержено | **sprint_report.md** | Автоматически |

---

## Блокирующие правила

```
ПРАВИЛО 1 — Preflight
  Спринт НЕ начинается, пока preflight_checklist.md не пройден.

ПРАВИЛО 2 — UX → Frontend
  DEV-3 НЕ запускается, пока:
  ✓ Файл ui_spec.md существует
  ✓ Заказчик явно утвердил UI-спецификацию

ПРАВИЛО 3 — Backend → Auth
  DEV-5 НЕ запускается, пока:
  ✓ Код DEV-1 смержен в develop
  ✓ Код DEV-2 смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 4 — DEV → ARCH
  ARCH НЕ запускается, пока все DEV текущей волны не завершили работу.

ПРАВИЛО 5 — ARCH → Заказчик
  Результаты НЕ передаются заказчику, пока ARCH не дал вердикт
  (APPROVED / APPROVED WITH MINOR / CHANGES REQUESTED).
```

---

## Параллельность

Шаги **1, 2, 3, 4** выполняются **одновременно**:
- UX работает с вами в foreground
- DEV-1, DEV-2, DEV-4 работают в фоне

Остальные шаги — **последовательно** (каждый зависит от предыдущего).
