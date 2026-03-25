# Предполётная проверка — Спринт 2

> Этот чеклист выполняется **ДО** запуска любого агента в спринте.
> Если хотя бы один пункт не выполнен — спринт НЕ НАЧИНАЕТСЯ.
> Оркестратор (Claude) выполняет проверки автоматически и сообщает результат.

---

## 1. Системные требования (проверяет оркестратор автоматически)

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 1.1 | Python установлен | `python3 --version` | >= 3.11 | [ ] |
| 1.2 | Node.js установлен | `node --version` | >= 18 | [ ] |
| 1.3 | pnpm установлен | `pnpm --version` | >= 9 | [ ] |
| 1.4 | Git установлен | `git --version` | any | [ ] |
| 1.5 | pip доступен | `python3 -m pip --version` | any | [ ] |

## 2. Состояние репозитория

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 2.1 | Ветка develop активна | `git branch --show-current` в Develop/ | develop | [ ] |
| 2.2 | Рабочая директория чистая | `git status --porcelain` | Пусто | [ ] |
| 2.3 | CLAUDE.md существует | Проверка файла | Файл есть | [ ] |

## 3. Sprint 1 завершён

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 3.1 | Backend тесты проходят | `cd backend && pytest tests/ -v` | 0 failures, ≥55 tests | [ ] |
| 3.2 | Frontend тесты проходят | `cd frontend && pnpm test` | 0 failures, ≥13 tests | [ ] |
| 3.3 | Auth работает | `GET /api/v1/health` → 200 | status: ok | [ ] |

## 4. Зависимости S2 устанавливаются

| # | Проверка | Команда | Ожидание | Статус |
|---|----------|---------|----------|--------|
| 4.1 | grpcio устанавливается | `pip install grpcio --dry-run` | OK (no errors) | [ ] |
| 4.2 | tinkoff-investments доступен | `pip install tinkoff-investments --dry-run` | OK (no errors) | [ ] |

> **Если grpcio не устанавливается:** проверить Xcode Command Line Tools (`xcode-select --install`), убедиться что wheel для текущей архитектуры доступен.

## 5. Промпты на месте

| # | Файл | Нужен для | Статус |
|---|------|-----------|--------|
| 5.1 | prompt_UX.md | UX-агент | [ ] |
| 5.2 | prompt_DEV-1_broker.md | DEV-1 | [ ] |
| 5.3 | prompt_DEV-2_moex_iss.md | DEV-2 | [ ] |
| 5.4 | prompt_DEV-3_crypto.md | DEV-3 | [ ] |
| 5.5 | prompt_DEV-4_market_data.md | DEV-4 | [ ] |
| 5.6 | prompt_DEV-5_charts.md | DEV-5 | [ ] |
| 5.7 | prompt_DEV-6_broker_settings.md | DEV-6 | [ ] |
| 5.8 | prompt_QA.md | QA | [ ] |
| 5.9 | prompt_ARCH_review.md | ARCH | [ ] |
| 5.10 | README.md | Описание спринта | [ ] |
| 5.11 | execution_order.md | Порядок выполнения | [ ] |

## 6. Зависимости МЕЖДУ агентами внутри спринта

| Агент | Волна | Зависимости | Файлы-артефакты | Проверка перед запуском |
|-------|-------|-------------|-----------------|------------------------|
| **UX** | 0 | Нет | prompt_UX.md | Промпт на месте |
| **DEV-1** | 1 | Нет | prompt_DEV-1_broker.md | Промпт на месте |
| **DEV-2** | 1 | Нет | prompt_DEV-2_moex_iss.md | Промпт на месте |
| **DEV-3** | 1 | Нет | prompt_DEV-3_crypto.md | Промпт на месте |
| **DEV-4** | 2 | **DEV-1 + DEV-2 + DEV-3 (смержены)** | prompt_DEV-4_market_data.md | Код волны 1 в develop, pytest проходит |
| **DEV-5** | 3 | **UX (ui_spec_s2.md) + DEV-4 (смержен)** | prompt_DEV-5_charts.md | ui_spec_s2.md утверждён, DEV-4 в develop |
| **DEV-6** | 3 | **UX (ui_spec_s2.md) + DEV-3 + DEV-4 (смержены)** | prompt_DEV-6_broker_settings.md | ui_spec_s2.md утверждён, DEV-3+DEV-4 в develop |

### Блокирующие правила

```
ПРАВИЛО 1: DEV-4 НЕ ЗАПУСКАЕТСЯ пока:
  ✓ Код DEV-1 (broker adapter) смержен в develop
  ✓ Код DEV-2 (MOEX ISS) смержен в develop
  ✓ Код DEV-3 (crypto) смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 2: DEV-5 и DEV-6 НЕ ЗАПУСКАЮТСЯ пока:
  ✓ ui_spec_s2.md существует в Sprint_2/
  ✓ Заказчик явно утвердил ui_spec_s2.md
  ✓ Код DEV-4 смержен в develop
  ✓ pytest tests/ = 0 failures на develop

ПРАВИЛО 3: QA НЕ ЗАПУСКАЕТСЯ пока:
  ✓ ВСЕ DEV-агенты завершили работу и смержены в develop

ПРАВИЛО 4: ARCH НЕ ЗАПУСКАЕТСЯ пока:
  ✓ QA завершил тест-кейсы
  ✓ Весь код доступен для чтения
```

---

## Процедура выполнения preflight

1. Оркестратор (Claude) **автоматически** выполняет проверки 1-5
2. Результат выводится в формате:

```
═══════════════════════════════════════════
  PREFLIGHT CHECK — Sprint 2
═══════════════════════════════════════════

  [✓] Python 3.11.x
  [✓] Node 20.x.x
  [✓] pnpm 9.x.x
  [✓] Git 2.x.x
  [✓] Git repo OK (develop branch, clean)
  [✓] Sprint 1 tests: 68 passed, 0 failed
  [✓] grpcio installable
  [✓] tinkoff-investments installable
  [✓] All 11 prompt/doc files present

  RESULT: ALL CHECKS PASSED — Sprint 2 ready to launch

═══════════════════════════════════════════
```

3. Заказчик видит результат и даёт команду на запуск (или устраняет блокеры).
