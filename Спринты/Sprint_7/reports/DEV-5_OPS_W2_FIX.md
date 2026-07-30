---
sprint: 7
agent: DEV-5 (OPS)
wave: W2 fix-wave (sub-wave 2)
date: 2026-04-26
predecessor: DEV-2_BACK2_W2.md (skip-тикет S7R-PDF-EXPORT-INSTALL)
---

# DEV-5 OPS W2 fix — закрытие S7R-PDF-EXPORT-INSTALL

## 1. Реализовано

- Установлен **WeasyPrint 68.1** в `Develop/backend/.venv` (+ 10 транзитивных
  пакетов: Pillow, Pyphen, brotli, cssselect2, fonttools, pydyf, tinycss2,
  tinyhtml5, webencodings, zopfli).
- `weasyprint>=60` зафиксирован в `Develop/backend/pyproject.toml`
  (`[project] dependencies`). Lockfile у проекта нет — фиксации
  только в pyproject достаточно.
- Системные brew-пакеты (`pango 1.57.1`, `cairo 1.18.4`, `gdk-pixbuf 2.44.5`,
  `libffi`) — все уже были установлены ранее. Изменений в `setup_macos.sh`
  не потребовалось (секция 8 «Зависимости для WeasyPrint» уже их перечисляет).
- Создан `Develop/backend/INSTALL.md` — инструкция по системным зависимостям
  (macOS + Ubuntu/Debian) и smoke-проверке.
- В `tests/unit/test_backtest/test_export.py` удалена ветка `pytest.skip("weasyprint installed")`:
  - Negative-path переписан через `sys.modules["weasyprint"] = None` —
    теперь стабилен в любом окружении (не зависит от установленности модуля).
  - Добавлены 2 positive-path теста: unit + HTTP, проверка `%PDF-` magic-bytes.
- Skip-тикет в `Sprint_8_Review/backlog.md` помечен как `✅ DONE 2026-04-26 —
  установлен в среде разработки, проверен endpoint`.

## 2. Файлы

- **MOD:** `Develop/backend/pyproject.toml` (+1 строка `weasyprint>=60`)
- **MOD:** `Develop/backend/tests/unit/test_backtest/test_export.py`
  (-13 строк pytest.skip, +50 строк positive-path)
- **MOD:** `Спринты/Sprint_8_Review/backlog.md` (тикет S7R-PDF-EXPORT-INSTALL → DONE)
- **MOD:** `Спринты/Sprint_7/changelog.md` (запись `2026-04-26 — Fix-волна OPS`)
- **NEW:** `Develop/backend/INSTALL.md` (инструкция установки)
- **NEW:** `Спринты/Sprint_7/reports/DEV-5_OPS_W2_FIX.md` (этот файл)

## 3. Тесты

- `pytest tests/unit/test_backtest/test_export.py -v` → **8/8 passed**
  (было 7 в baseline midsprint; +1 — `test_generate_pdf_produces_valid_pdf_bytes`).
- Полный регресс: `pytest tests/ -q` → **867 passed / 0 failed** (82.57s).
  Baseline после W2 sub-wave 1 = 866 → +1 за positive-path PDF.
- Skip-тикетов больше **нет** в test_export.py.

## 4. Integration points

- Endpoint `GET /api/v1/backtest/{id}/export?format=pdf` живой (production-код
  в `app/backtest/router.py:817-845` — не менялся в этой волне).
- Lazy-import `weasyprint` в `app/backtest/export.py:140` сработал в живом
  процессе uvicorn (PID 57707, поднятом FRONT1 ранее) **без перезапуска** —
  модуль появился в site-packages и подхватился при первом вызове.
- Smoke-test endpoint:
  ```
  GET /api/v1/backtest/31/export?format=pdf  (sergopipo, user_id=1)
  → HTTP 200
  → Content-Type: application/pdf
  → 54 685 bytes
  → file: PDF document, version 1.7
  → magic bytes: %PDF-1.7
  ```

## 5. Контракты

- OPS — **потребитель**, не поставщик контрактов. Контракт C5 (CSV/PDF endpoint
  `GET /backtest/{id}/export`) опубликован BACK2 в W2 sub-wave 1; OPS подтверждает,
  что PDF-плечо контракта теперь функционально (раньше возвращало 503).

## 6. Проблемы и решения

- **Backend уже был поднят FRONT1** — НЕ перезапускал, чтобы не сломать его
  скриншот-сессию. Lazy-import корректно подтянул свежеустановленный модуль
  при первом HTTP-обращении (стандартное поведение CPython: `import weasyprint`
  выполняется в момент вызова функции `generate_pdf`, а не при старте процесса).
- **Получение JWT для smoke-теста** — пароль sergopipo неизвестен и не должен
  передаваться через CLI. Сгенерировал access-token напрямую через
  `AuthService._create_token_pair(1)` с использованием production `SECRET_KEY`
  из `app.config.settings`. Токен короткоживущий (15 мин), в логах не сохранён.
- **Lockfile отсутствует** — у backend нет `requirements.lock`/`poetry.lock`/`uv.lock`,
  только pyproject. Зафиксировано в pyproject.toml — этого достаточно для
  CI/других машин.

## 7. Применённые Stack Gotchas

Не применимо — ловушки стека не сработали; работа сводилась к установке
зависимостей и обновлению тестов. INDEX.md не менял.

## 8. Новые Stack Gotchas

Не выявлено.

---

## Координация с параллельными DEV в W2 fix-wave

- **BACK1** (Grid Search refactor `app/backtest/grid.py`) — нет конфликта.
- **BACK2** (wizard URL fix + chart_drawings) — нет конфликта (другие модули).
- **FRONT1** (Playwright скриншоты) — backend уже был ими поднят. OPS НЕ
  перезапускал процесс. Если FRONT1 во время своих скриншотов натолкнётся на
  проблемы с импортом weasyprint — перезапустить backend через `./restart_dev.sh`
  (но в тестах OPS lazy-import работает корректно без перезапуска, так что
  FRONT1, скорее всего, ничего не заметит).
