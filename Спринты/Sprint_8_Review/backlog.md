# Sprint 8 Review — Backlog

> Карточки переносов из Sprint 7 (skip-тикеты, deferred-задачи).

---

## S7R-PDF-EXPORT-INSTALL — ✅ DONE 2026-04-26 — установлен в среде разработки, проверен endpoint

- **Источник:** Sprint 7, BACK2 W2, задача 7.3 (CSV/PDF export бэктеста).
- **Закрыто:** Sprint 7, OPS W2 fix-волна (2026-04-26).
- **Что было сделано (фактически):**
  1. ✅ `weasyprint>=60` добавлен в `Develop/backend/pyproject.toml` (`[project] dependencies`).
     Установлено в `.venv`: weasyprint 68.1 (+ Pillow 12.2.0, Pyphen 0.17.2, brotli, cssselect2,
     fonttools, pydyf, tinycss2, tinyhtml5, webencodings, zopfli).
  2. ✅ Системные зависимости (pango 1.57.1, cairo 1.18.4, gdk-pixbuf 2.44.5, libffi)
     уже установлены через brew; в `setup_macos.sh` секция 8 «Зависимости для WeasyPrint»
     корректно их перечисляет (изменений не потребовалось).
  3. ✅ В `tests/unit/test_backtest/test_export.py` ветка `pytest.skip("weasyprint installed")`
     удалена. Negative-path переписан через monkey-patch `sys.modules["weasyprint"] = None`
     (стабилен в любом окружении). Добавлены 2 positive-path теста:
     - `test_generate_pdf_produces_valid_pdf_bytes` (unit, проверка `%PDF-` magic-bytes).
     - `test_export_pdf_endpoint_returns_pdf_bytes` (HTTP, проверка 200 + content-type + magic).
  4. ✅ Endpoint `GET /api/v1/backtest/31/export?format=pdf` локально вернул `HTTP 200`,
     `Content-Type: application/pdf`, 54685 байт, `file → PDF document, version 1.7`.
- **Тесты:** baseline 866 → **867 passed / 0 failed** (+1 positive-path).
- **Файлы изменены:** `Develop/backend/pyproject.toml`,
  `Develop/backend/tests/unit/test_backtest/test_export.py`,
  `Develop/backend/INSTALL.md` (NEW — инструкция по установке системных зависимостей).
- **Файлы НЕ изменены (не потребовалось):** `app/backtest/export.py`, `app/backtest/router.py`,
  `setup_macos.sh` (системные зависимости там уже учтены).
