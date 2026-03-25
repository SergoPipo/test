# Порядок выполнения — Спринт 2

> Единый файл: кто, когда, от чего зависит, какой промпт читать.
>
> **Сессия прервалась?** → Читай [sprint_state.md](sprint_state.md) — там текущий прогресс и следующее действие.

---

## Диаграмма

```
  PREFLIGHT ──────────────────────────────────────────────────────────
  │ Проверка: S1 в develop, 68 тестов ОК, grpcio, промпты
  │ Файл: preflight_checklist.md
  ▼
  ┌─────────────────┐   ┌─────────────┐   ┌─────────────┐
  │ ① UX            │   │ ② DEV-1     │   │ ③ DEV-2     │
  │ Дизайн графиков │   │ T-Invest    │   │ MOEX ISS +  │
  │ + настроек      │   │ Broker      │   │ Calendar    │
  │ [foreground]    │   │ Adapter     │   │ [background]│
  │ prompt_UX.md    │   │ [background]│   │ prompt_DEV- │
  │                 │   │ prompt_DEV- │   │ 2_moex_iss  │
  │ Диалог с вами.  │   │ 1_broker.md │   │ .md         │
  │ Результат:      │   └──────┬──────┘   └──────┬──────┘
  │ → ui_spec_s2.md │          │                  │
  └────────┬────────┘   ┌──────┴──────┐           │
           │            │ ④ DEV-3     │           │
           │            │ CryptoSvc   │           │
           │            │ (SEC)       │           │
           │            │ [background]│           │
           │            │ prompt_DEV- │           │
           │            │ 3_crypto.md │           │
           │            └──────┬──────┘           │
           │                   │                  │
  ─────────▼───────────────────▼──────────────────▼── МЕРЖ волны 1 ──
  │                      + проверка: pytest = 0 failures
  │
  │  БЛОКЕР: DEV-1 + DEV-2 + DEV-3 смержены в develop
  ▼
  ┌─────────────────┐
  │ ⑤ DEV-4         │
  │ Market Data     │
  │ Service         │
  │ [background]    │
  │ prompt_DEV-4_   │
  │ market_data.md  │
  └────────┬────────┘
           │
  ─────────▼───────── МЕРЖ волны 2 ─────────────────────────────────
  │                  + проверка: pytest = 0 failures
  │
  │  БЛОКЕР: ui_spec_s2.md утверждён заказчиком
  │  БЛОКЕР: DEV-4 в develop
  ▼
  ┌─────────────────┐   ┌─────────────┐
  │ ⑥ DEV-5         │   │ ⑦ DEV-6     │
  │ Charts          │   │ Broker      │
  │ Frontend        │   │ Settings    │
  │ (FRONT1)        │   │ Frontend    │
  │ [background]    │   │ (FRONT2)    │
  │ prompt_DEV-5_   │   │ [background]│
  │ charts.md       │   │ prompt_DEV- │
  │                 │   │ 6_broker_   │
  │                 │   │ settings.md │
  └────────┬────────┘   └──────┬──────┘
           │                   │
  ─────────▼───────────────────▼── МЕРЖ волны 3 ────────────────────
  │
  │  БЛОКЕР: все DEV смержены
  ▼
  ┌─────────────────┐
  │ ⑧ QA            │
  │ Тест-кейсы +    │
  │ ручное тестир.  │
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
| 1 | **UX** | [prompt_UX.md](prompt_UX.md) | 0 | Нет | **ui_spec_s2.md** | foreground (диалог с вами) |
| 2 | **DEV-1** | [prompt_DEV-1_broker.md](prompt_DEV-1_broker.md) | 1 | Нет | Broker adapter + тесты | background, worktree |
| 3 | **DEV-2** | [prompt_DEV-2_moex_iss.md](prompt_DEV-2_moex_iss.md) | 1 | Нет | MOEX ISS client + тесты | background, worktree |
| 4 | **DEV-3** | [prompt_DEV-3_crypto.md](prompt_DEV-3_crypto.md) | 1 | Нет | CryptoService + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 1 в develop | — | — |
| 5 | **DEV-4** | [prompt_DEV-4_market_data.md](prompt_DEV-4_market_data.md) | 2 | DEV-1 + DEV-2 + DEV-3 в develop | Market Data Service + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 2 в develop | — | — |
| 6 | **DEV-5** | [prompt_DEV-5_charts.md](prompt_DEV-5_charts.md) | 3 | **ui_spec_s2.md** утверждён + DEV-4 в develop | Charts frontend + тесты | background, worktree |
| 7 | **DEV-6** | [prompt_DEV-6_broker_settings.md](prompt_DEV-6_broker_settings.md) | 3 | **ui_spec_s2.md** утверждён + DEV-3 + DEV-4 в develop | Broker settings UI + тесты | background, worktree |
| — | — | — | — | МЕРЖ волны 3 в develop | — | — |
| 8 | **QA** | [prompt_QA.md](prompt_QA.md) | 4 | Все DEV смержены | Тест-кейсы + отчёт | background |
| 9 | **ARCH** | [prompt_ARCH_review.md](prompt_ARCH_review.md) | review | Все DEV + QA завершены | Отчёт ревью + тесты | foreground |
| 10 | **ВЫ** | — | review | ARCH одобрил | Решение о мерже | — |
| 11 | — | sprint_report_template.md | — | Всё смержено | **sprint_report.md** | Автоматически |

---

## Блокирующие правила

```
ПРАВИЛО 1 — Preflight
  Спринт НЕ начинается, пока preflight_checklist.md не пройден.

ПРАВИЛО 2 — Backend → Market Data
  DEV-4 НЕ запускается, пока:
  ✓ Код DEV-1 (broker) смержен в develop
  ✓ Код DEV-2 (MOEX ISS) смержен в develop
  ✓ Код DEV-3 (crypto) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 3 — UX → Frontend
  DEV-5 и DEV-6 НЕ запускаются, пока:
  ✓ Файл ui_spec_s2.md существует в Sprint_2/
  ✓ Заказчик явно утвердил UI-спецификацию

ПРАВИЛО 4 — Market Data → Frontend
  DEV-5 и DEV-6 НЕ запускаются, пока:
  ✓ Код DEV-4 (Market Data) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 5 — DEV → QA → ARCH
  QA НЕ запускается, пока все DEV не завершили работу.
  ARCH НЕ запускается, пока QA не завершил тест-кейсы.

ПРАВИЛО 6 — ARCH → Заказчик
  Результаты НЕ передаются заказчику, пока ARCH не дал вердикт
  (APPROVED / APPROVED WITH MINOR / CHANGES REQUESTED).
```

---

## Параллельность

Шаги **1, 2, 3, 4** выполняются **одновременно**:
- UX работает с вами в foreground
- DEV-1, DEV-2, DEV-3 работают в фоне

Шаги **6, 7** выполняются **одновременно** (после мержа волн 1+2 и утверждения UX).

Остальные шаги — **последовательно** (каждый зависит от предыдущего).
