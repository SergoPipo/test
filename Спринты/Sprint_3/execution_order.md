# Порядок выполнения — Спринт 3

> Единый файл: кто, когда, от чего зависит, какой промпт читать.
>
> **Сессия прервалась?** → Читай [sprint_state.md](sprint_state.md) — там текущий прогресс и следующее действие.

---

## Диаграмма

```
  PREFLIGHT ──────────────────────────────────────────────────────────
  │ Проверка: S2 завершён, 139+ тестов ОК, зависимости S3, промпты
  │ Файл: preflight_checklist.md
  ▼
  ┌─────────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
  │ ① UX            │   │ ② DEV-1     │   │ ③ DEV-2     │   │ ④ DEV-3     │
  │ Дизайн Strategy │   │ Strategy    │   │ Blockly     │   │ Code        │
  │ Editor          │   │ CRUD API    │   │ блоки       │   │ Sandbox     │
  │ [foreground]    │   │ (BACK1)     │   │ (FRONT1)    │   │ (SEC)       │
  │ prompt_UX.md    │   │ [background]│   │ [background]│   │ [background]│
  │                 │   │ prompt_DEV- │   │ prompt_DEV- │   │ prompt_DEV- │
  │ Диалог с вами.  │   │ 1_strategy_ │   │ 2_blockly_  │   │ 3_sandbox   │
  │ Результат:      │   │ api.md      │   │ blocks.md   │   │ .md         │
  │ → ui_spec_s3.md │   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
  └────────┬────────┘          │                  │                  │
           │            ┌──────┴──────┐                              │
           │            │ ⑤ DEV-4     │                              │
           │            │ CSRF +      │                              │
           │            │ Rate Limit  │                              │
           │            │ (SEC)       │                              │
           │            │ [background]│                              │
           │            │ prompt_DEV- │                              │
           │            │ 4_csrf_     │                              │
           │            │ ratelimit   │                              │
           │            │ .md         │                              │
           │            └──────┬──────┘                              │
           │                   │                                     │
  ─────────▼───────────────────▼─────────────────────────────────────▼── МЕРЖ волны 1
  │                      + проверка: pytest = 0 failures
  │
  │  БЛОКЕР: DEV-1 + DEV-2 + DEV-3 + DEV-4 смержены в develop
  │  БЛОКЕР: ui_spec_s3.md утверждён заказчиком
  ▼
  ┌─────────────────┐   ┌─────────────┐
  │ ⑥ DEV-5         │   │ ⑦ DEV-6     │
  │ Code Generator  │   │ Strategy    │
  │ + Template      │   │ Editor page │
  │ Parser          │   │ + Mode B    │
  │ (BACK2)         │   │ (FRONT1+2)  │
  │ [background]    │   │ [background]│
  │ prompt_DEV-5_   │   │ prompt_DEV- │
  │ codegen.md      │   │ 6_strategy_ │
  │                 │   │ editor.md   │
  └────────┬────────┘   └──────┬──────┘
           │                   │
  ─────────▼───────────────────▼── МЕРЖ волны 2 ────────────────────
  │
  │  БЛОКЕР: все DEV смержены
  ▼
  ┌─────────────────┐
  │ ⑧ QA            │
  │ E2E + ручное    │
  │ тестирование    │
  │ [background]    │
  │ prompt_QA.md    │
  └────────┬────────┘
           │
  ┌────────▼─────────┐
  │ ⑨ ARCH           │
  │ Техархитектор    │
  │ [foreground]     │
  │ prompt_ARCH_     │
  │ review.md        │
  └────────┬─────────┘
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
| 1 | **UX** | [prompt_UX.md](prompt_UX.md) | 0 | Нет | **ui_spec_s3.md** | foreground (диалог с вами) |
| 2 | **DEV-1** | [prompt_DEV-1_strategy_api.md](prompt_DEV-1_strategy_api.md) | 1 | Нет | Strategy API + models + тесты | background, worktree |
| 3 | **DEV-2** | [prompt_DEV-2_blockly_blocks.md](prompt_DEV-2_blockly_blocks.md) | 1 | Нет | Blockly блоки + тесты | background, worktree |
| 4 | **DEV-3** | [prompt_DEV-3_sandbox.md](prompt_DEV-3_sandbox.md) | 1 | Нет | Code Sandbox + тесты | background, worktree |
| 5 | **DEV-4** | [prompt_DEV-4_csrf_ratelimit.md](prompt_DEV-4_csrf_ratelimit.md) | 1 | Нет | CSRF + Rate Limiting + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 1 в develop | — | — |
| 6 | **DEV-5** | [prompt_DEV-5_codegen.md](prompt_DEV-5_codegen.md) | 2 | DEV-1 (Strategy API) в develop | Code Generator + Parser + тесты | background, worktree |
| 7 | **DEV-6** | [prompt_DEV-6_strategy_editor.md](prompt_DEV-6_strategy_editor.md) | 2 | **ui_spec_s3.md** утверждён + DEV-2 в develop | Strategy Editor + Mode B + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 2 в develop | — | — |
| 8 | **QA** | [prompt_QA.md](prompt_QA.md) | 3 | Все DEV смержены | E2E тесты + QA-отчёт | background |
| 9 | **ARCH** | [prompt_ARCH_review.md](prompt_ARCH_review.md) | review | Все DEV + QA завершены | Отчёт ревью + тесты | foreground |
| 10 | **ВЫ** | — | review | ARCH одобрил | Решение о мерже | — |
| 11 | — | sprint_report_template.md | — | Всё смержено | **sprint_report.md** | Автоматически |

---

## Блокирующие правила

```
ПРАВИЛО 1 — Preflight
  Спринт НЕ начинается, пока preflight_checklist.md не пройден.

ПРАВИЛО 2 — Волна 1 → Волна 2
  DEV-5 НЕ запускается, пока:
  ✓ Код DEV-1 (Strategy API) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 3 — UX → Frontend Editor
  DEV-6 НЕ запускается, пока:
  ✓ Файл ui_spec_s3.md существует в Sprint_3/
  ✓ Заказчик явно утвердил UI-спецификацию
  ✓ Код DEV-2 (Blockly блоки) смержен в develop

ПРАВИЛО 4 — DEV → QA → ARCH
  QA НЕ запускается, пока все DEV не завершили работу.
  ARCH НЕ запускается, пока QA не завершил E2E-тесты.

ПРАВИЛО 5 — ARCH → Заказчик
  Результаты НЕ передаются заказчику, пока ARCH не дал вердикт
  (APPROVED / APPROVED WITH MINOR / CHANGES REQUESTED).
```

---

## Параллельность

Шаги **1, 2, 3, 4, 5** выполняются **одновременно**:
- UX работает с вами в foreground
- DEV-1, DEV-2, DEV-3, DEV-4 работают в фоне

Шаги **6, 7** выполняются **одновременно** (после мержа волны 1 и утверждения UX).

Остальные шаги — **последовательно** (каждый зависит от предыдущего).
