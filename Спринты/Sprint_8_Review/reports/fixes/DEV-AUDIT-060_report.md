## DEV-AUDIT-060 отчёт (ревью, раунд 5) — S8R fixes, LOW
Статус: ✅ готово к коммиту. Worktree `wt-s8r-fixes`, detached `d62ad0d`, ничего не закоммичено.

### Пункты 1–4
1. **`logout()` ждёт refresh в полёте** (не дольше 10 с), затем сбрасывает сессию, закрывает WS и отправляет POST. RED: `['refresh:start','logout:post']`. GREEN: порядок `refresh:start → refresh:end → logout:post`.
2. **`doRefresh(epoch)` проверяет эпоху и закрытую сессию перед каждой попыткой** (после лока и после паузы 429). RED: `expected 3 to be 1`. GREEN: второго POST нет, исход `stale`.
3. **WS на `rejected` выходит из системы** — `logout()` и `/login`, как HTTP-интерцептор; один раз на сессию, флаг снимается входом. RED: `called 1 times, but got 0`. GREEN.
4. **Вход не будит контроллеры, закрытые намеренно.** RED: `called 1 times, but got 2`. GREEN; добавлен тест «Повторить» против намеренного закрытия.

### Развилка
Из п.4 следует: `auth_error` синглтона теперь обрабатывается как 4401 (refresh и повтор), а не как намеренное закрытие. Иначе мультиплексор оставался бы мёртвым до перезагрузки страницы.

### Тесты
- Мутации (откачены, md5 сверены):
  - п.1 без ожидания → `['refresh:start','logout:post'] ≠ ['refresh:start']`;
  - п.2 без проверки эпохи → `expected 3 to be 1`.
- В моке `client` в `authStore.test` добавлен `getCSRFToken`.

### Гейты
pytest 4835 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (195); bandit M0/H0; typecheck 0; lint 0; build ok; vitest 1108 passed.
