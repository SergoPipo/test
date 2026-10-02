## DEV-AUDIT-050 отчёт (часть 2) — S8R fixes, LOW
Статус: ✅ готово к коммиту (HEAD 66511e9, не закоммичено)
### 1. Что реализовано (п.1–10)
1. `scripts/verify_install.py` проверяет то, чего не видит `pip check`. Каждая строка lock должна стоять своей версией. Пакеты extras (uvicorn[standard], sqlalchemy[asyncio], fonttools[woff] → greenlet, uvloop, httptools, websockets, watchfiles, python-dotenv, pyyaml, brotli, zopfli) должны быть в lock, установлены и импортироваться. Вызывается в Dockerfile, ci.yml и nightly.
2. poetry-core 2.5.0 и setuptools 84.0.0 теперь в lock. SDK и `-e .` ставятся с `--no-build-isolation`.
3. В lock у каждой PyPI-строки есть sha256, установка идёт с `--no-deps --require-hashes`. `--generate-hashes` у pip-tools за прокси выкачивал все файлы (за 25 мин так и не закончил), поэтому хэши берутся из JSON API PyPI — это те же хэши всех файлов релиза.
4. `--from-venv` берёт ограничения из `pip freeze --all`, кроме pip и setuptools. Для setuptools в lock стоит пол `>=83.0.0`: **в общем venv 82.0.0 (CVE-2026-59890), в lock 84.0.0 — расхождение для заказчика.**
5. Заголовки pip-compile больше не приклеиваются к пакету. Пути аргументов переводятся в абсолютные до `cd`. Кэши — во временном каталоге.
6. `scripts/install_tinvest_sdk.sh` — единственный клон SDK: sha берёт из pyproject, тег отвергает. Полный sha есть только в pyproject и lock.
7. pnpm `9.15.9+sha512` в `packageManager`, в Dockerfile `corepack prepare --activate`, в action-setup `9.15.9`.
8. Установка в ci.yml и nightly — из lock. В nginx-config тот же digest, что во frontend/Dockerfile.
9. RestrictedPython: скан всего backend/ — импортов нет. В `.bandit` описан единственный exec — engine.py, `# nosec B102` по-прежнему нужен.
10. Оба lock перегенерированы, повторная генерация побайтово совпала.

Тест первым не для всего: verify_install.py и install_tinvest_sdk.sh написаны до RED-прогона. RED упирался в lock, Dockerfile, CI и pnpm.
### 3. Тесты
- RED: 9 failed (`строки без --hash=sha256: ['a2wsgi', …]`, `SDK клонируется мимо скрипта`, `packageManager=''`).
- GREEN: 23 passed, вместе с CI-тестом 38 passed.
- Мутация п.1 (убрал greenlet): `пакетов extras нет в requirements.lock: ['greenlet']`, verify_install rc=1.
- Мутация п.3 (снял хэши a2wsgi): `строки без --hash=sha256: ['a2wsgi']`.
- Гейты: pytest 5143 passed / 1 skipped / 0 xfailed / 0 failed; ruff 0; mypy Success (198); bandit 0; typecheck, lint, build 0; vitest 1136 passed.
- Чистый venv (scratchpad), установка как в CI с `--require-hashes`: `pip check` OK, verify_install OK, полный pytest 5143 passed.
### 6. Прочее
- `~/Library/Caches/pip-tools` (1.2 ГБ) оставили мои первые запуски, удалить: `rm -rf ~/Library/Caches/pip-tools`.
- PR Dependabot по pip меняют только pyproject — lock придётся перегенерировать. Красный тест на этом PR — так и задумано, пометка добавлена в dependabot.yml.
- Не закреплены pip (без хэша) и apt-пакеты.
- `docker compose build` должен проверить заказчик.
