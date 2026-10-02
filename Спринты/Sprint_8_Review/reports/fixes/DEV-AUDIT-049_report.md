## DEV-AUDIT-049 отчёт — S8R fixes, LOW
Статус: ✅ готово к коммиту (кодовая часть; команды удаления веток/worktree — заказчику)
### 1. Что реализовано
- `permissions: contents: read` на уровне обоих workflow; `actions: write` не добавлен: cache/upload-artifact ходят через `ACTIONS_RUNTIME_TOKEN`, не через `GITHUB_TOKEN`.
- `concurrency` с группой `${{ github.workflow }}-${{ github.ref }}`. В ci.yml `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`: прогоны push в develop/main и в рабочие ветки не отменяются. В nightly `false`: следующий прогон ждёт в очереди, плановый и ручной не обрывают друг друга.
- Все 15 `uses:` закреплены 40-hex SHA через `git ls-remote` с комментарием тега. SHA равны тому, на что сейчас указывают `@v7`/`@v6`, поэтому поведение не меняется: checkout v7.0.1, setup-python v7.0.0, setup-node v7.0.0, pnpm/action-setup v6.0.10 (взят коммит после `^{}`, тег аннотированный), cache v6.1.0, upload-artifact v7.0.1.
- `.github/dependabot.yml`: pip `/backend` (исключён `tinkoff-investments`: git-зависимость, патчится в CI), npm `/frontend` (pnpm), github-actions `/`, docker `/` + `/frontend` (Dockerfile.backend подхватывается: Dependabot берёт имена, содержащие «dockerfile»). Проверка еженедельная (пн 06:00 MSK), не больше 5 открытых PR, minor и patch сгруппированы.
### 2. Файлы
Новые: `.github/dependabot.yml`, `backend/tests/unit/test_ci_workflows.py`. Изменены: `.github/workflows/ci.yml`, `.github/workflows/playwright-nightly.yml`.
### 3. Тесты
RED: 10 failed / 1 passed, `AssertionError: ci.yml: нет `permissions:` на уровне workflow`, `… action не закреплён SHA: ['actions/checkout@v7', …]`, `нет .github/dependabot.yml`. GREEN: 11 passed. Мутация: убрал `permissions` из ci.yml (через бэкап, md5 после отката сошёлся) → `AssertionError: ci.yml: нет `permissions:` на уровне workflow`. Гейты: pytest 5116 passed / 1 skipped / 0 xfailed / 0 failed (rc=0); ruff 0; mypy Success (198); bandit без находок; typecheck 0; lint 0; build ok; vitest: фронт не менялся — на уровне пакета. Маркеров `S8R-AUDIT-049` нет.
### 4. Integration points
Новых функций нет. Конфигурация действует сама по себе (GitHub читает `.github/`); тест входит в `tests/unit/`, CI его прогоняет.
### 5. Контракты
API, схемы и миграции не менялись.
### 6. Проблемы / TODO / находки
- Локально workflows не исполнить (actionlint не установлен). Финальная проверка — первый CI на PR и появление первых PR от Dependabot (п. 4 «Готово, когда»).
- Lock из 050 в дереве пока нет. Когда появится, Dependabot pip подхватит его в том же каталоге `/backend`. Риск: резолв pyproject с git-зависимостью может падать — смотреть журнал Dependabot.
- Образы `FROM` без digest (это 050), значит Dependabot docker будет обновлять теги.
- ФТ/ТЗ/гайд не затронуты.
- Самопроверка: пункты 1–6 неприменимы (БД, уведомления, асинхронность, ресурсы не затронуты; изменённых вызывающих нет).
### 7. Применённые Stack Gotchas
60 (`tsc -b` как гейт), 50 (работа только в worktree).
### 8. Новые Stack Gotchas
Нет.
### 9. Плагины
py_compile + ruff; typecheck `tsc -b`; context7 (документация GitHub по dependabot.yml и dependabot-core: имена Dockerfile); tdd (`mattpocock-skills:tdd`).

---
## Раунд 2 (код-ревью)
Статус: ✅ готово к коммиту.
1. ci.yml concurrency: группа `${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.ref || github.run_id }}`, `cancel-in-progress` только для PR. Тесты проверяют инвариант через мини-вычислитель `${{ }}`: у push группа содержит run_id и уникальна, у PR — ref, отмена включена.
2. ci.yml `on.push.branches: [develop, main]`, `pull_request` без изменений.
3. dependabot docker: python — ignore major и minor, node — ignore major, nginx — как есть.
4. dependabot pip: `exclude-patterns: [fastapi, starlette, anyio, pydantic]`.
5. Тест: если `.github` не найден, модуль пропускается (поиск вверх по родительским каталогам; проверено переименованием каталога: 11 skipped, затем каталог возвращён). Отбор `uses:` — единый `_third_party_uses`.
6. `pyyaml==6.0.3` добавлен в dev extras `backend/pyproject.toml`.

RED: `AssertionError: assert ('201' in 'CI-refs/heads/develop')`, `on=['push', 'pull_request']` (4 failed) → GREEN 15 passed. Мутация: группа возвращена на `-${{ github.ref }}` → та же строка падения; откат через бэкап, md5 совпал. ruff 0, mypy Success (198).

**Заказчику:** после мержа открыть Insights → Dependency graph → Dependabot и проверить, что разбор `backend/pyproject.toml` с git-зависимостью SDK проходит без ошибки.
