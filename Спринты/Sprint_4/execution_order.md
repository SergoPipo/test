# Порядок выполнения — Спринт 4

> Единый файл: кто, когда, от чего зависит, какой промпт читать.
>
> **Сессия прервалась?** → Читай [sprint_state.md](sprint_state.md) — там текущий прогресс и следующее действие.

---

## Диаграмма

```
  PREFLIGHT ──────────────────────────────────────────────────────────
  │ Проверка: S3 завершён, 320+ тестов ОК, зависимости S4, промпты
  │ Файл: preflight_checklist.md
  ▼
  ┌─────────────────┐   ┌─────────────┐   ┌─────────────┐
  │ ① UX            │   │ ② DEV-1     │   │ ③ DEV-3     │
  │ Дизайн бэктест  │   │ AI Service  │   │ Backtest    │
  │ + AI chat       │   │ Providers   │   │ Engine      │
  │ [foreground]    │   │ (BACK2)     │   │ (BACK1)     │
  │ prompt_UX.md    │   │ [background]│   │ [background]│
  │                 │   │ prompt_DEV- │   │ prompt_DEV- │
  │ Диалог с вами.  │   │ 1_ai_       │   │ 3_backtest_ │
  │ Результат:      │   │ service.md  │   │ engine.md   │
  │ → ui_spec_s4.md │   └──────┬──────┘   └──────┬──────┘
  └────────┬────────┘          │                  │
           │                   │                  │
  ─────────▼───────────────────▼──────────────────▼── МЕРЖ волны 1
  │                      + проверка: pytest = 0 failures
  │
  │  БЛОКЕР: DEV-1 + DEV-3 смержены в develop
  │  БЛОКЕР: ui_spec_s4.md утверждён заказчиком
  ▼
  ┌─────────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
  │ ④ DEV-2         │   │ ⑤ DEV-4     │   │ ⑥ DEV-5     │   │ ⑦ DEV-6     │
  │ AI Chat API     │   │ Backtest    │   │ AI Sidebar  │   │ Backtest UI │
  │ + SSE           │   │ API + WS    │   │ Chat        │   │ + Форма     │
  │ (BACK2+BACK1)   │   │ (BACK1)     │   │ (FRONT2)    │   │ + AI Settings│
  │ [background]    │   │ [background]│   │ [background]│   │ (FRONT1+2)  │
  │ prompt_DEV-2_   │   │ prompt_DEV- │   │ prompt_DEV- │   │ [background]│
  │ ai_chat_api.md  │   │ 4_backtest_ │   │ 5_ai_       │   │ prompt_DEV- │
  │                 │   │ api.md      │   │ sidebar.md  │   │ 6_backtest_ │
  │                 │   │             │   │             │   │ ui.md       │
  └────────┬────────┘   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
           │                   │                  │                  │
  ─────────▼───────────────────▼──────────────────▼──────────────────▼── МЕРЖ волны 2
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
| 1 | **UX** | [prompt_UX.md](prompt_UX.md) | 0 | Нет | **ui_spec_s4.md** | foreground (диалог с вами) |
| 2 | **DEV-1** | [prompt_DEV-1_ai_service.md](prompt_DEV-1_ai_service.md) | 1 | Нет | AI Service + providers + тесты | background, worktree |
| 3 | **DEV-3** | [prompt_DEV-3_backtest_engine.md](prompt_DEV-3_backtest_engine.md) | 1 | Нет | Backtest Engine + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 1 в develop | — | — |
| 4 | **DEV-2** | [prompt_DEV-2_ai_chat_api.md](prompt_DEV-2_ai_chat_api.md) | 2 | DEV-1 (AI Service) в develop | AI Chat API + SSE + тесты | background, worktree |
| 5 | **DEV-4** | [prompt_DEV-4_backtest_api.md](prompt_DEV-4_backtest_api.md) | 2 | DEV-3 (Backtest Engine) в develop | Backtest API + WS progress + тесты | background, worktree |
| 6 | **DEV-5** | [prompt_DEV-5_ai_sidebar.md](prompt_DEV-5_ai_sidebar.md) | 2 | **ui_spec_s4.md** утверждён + DEV-1 в develop | AI Sidebar Chat + тесты | background, worktree |
| 7 | **DEV-6** | [prompt_DEV-6_backtest_ui.md](prompt_DEV-6_backtest_ui.md) | 2 | **ui_spec_s4.md** утверждён + DEV-3 в develop | Backtest UI + форма + AI settings + тесты | background, worktree |
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
  DEV-2 НЕ запускается, пока:
  ✓ Код DEV-1 (AI Service) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

  DEV-4 НЕ запускается, пока:
  ✓ Код DEV-3 (Backtest Engine) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 3 — UX → Frontend
  DEV-5 НЕ запускается, пока:
  ✓ Файл ui_spec_s4.md существует в Sprint_4/
  ✓ Заказчик явно утвердил UI-спецификацию
  ✓ Код DEV-1 (AI Service) смержен в develop

  DEV-6 НЕ запускается, пока:
  ✓ Файл ui_spec_s4.md существует в Sprint_4/
  ✓ Заказчик явно утвердил UI-спецификацию
  ✓ Код DEV-3 (Backtest Engine) смержен в develop

ПРАВИЛО 4 — DEV → QA → ARCH
  QA НЕ запускается, пока все DEV не завершили работу.
  ARCH НЕ запускается, пока QA не завершил E2E-тесты.

ПРАВИЛО 5 — ARCH → Заказчик
  Результаты НЕ передаются заказчику, пока ARCH не дал вердикт
  (APPROVED / APPROVED WITH MINOR / CHANGES REQUESTED).
```

---

## Параллельность

Шаги **1, 2, 3** выполняются **одновременно**:
- UX работает с вами в foreground
- DEV-1, DEV-3 работают в фоне

Шаги **4, 5, 6, 7** выполняются **одновременно** (после мержа волны 1 и утверждения UX).

Остальные шаги — **последовательно** (каждый зависит от предыдущего).
