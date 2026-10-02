## DEV-AUDIT-059 отчёт (р.3, финальный) — S8R fixes, LOW
Статус: ✅ готово к коммиту (wt-s8r-fixes, detached 413fe47, ничего не закоммичено)

### Сделано (п.1–10)
1. БД недоступна — в БД не ходим, решает только подпись токена (`access_token_signature_valid`, срок не проверяется). Наш токен → расширенный ответ, чужой → минимальный, не 401.
2. Readiness теперь `SELECT 1 FROM users LIMIT 1`. `SQLAlchemyError` при проверке пользователя → решение по подписи, без 500. Поле `database` остаётся по readiness, поэтому код ответа у анонима и пользователя совпадает.
3. При disconnected — только readiness-запрос, `cb_state=unknown`.
4. Health проверяет только первый кандидат, ровно как `get_current_user` (общий `user_from_access_token`). Перебор кандидатов остался только у logout (`first_authenticated`).
5. Shell режет `CORS_ORIGINS` только по запятым, края записей обрезает. Запись с пробелом внутри считается некорректной.
6. Logout берёт токены через `access_token_candidates(request, token_hdr)`.
7. `get_access_token` и health разбирают Bearer только через `Depends(oauth2_scheme)`, без повторного разбора.
8. Config использует `origin_entries`/`parse_origins`/`dropped_origin_entries`/`is_public_http_origin` из `origin_syntax.py`.
9. Добавлен тест logout: отозванный Bearer + валидная cookie → cookie-сессия отозвана. Он сразу зелёный: перебор уже был в р.2, тест — страховка от регресса.
10. `get_optional_current_user` удалён, вместо него обычная функция `user_from_access_token`.

### Тесты
RED (12 упавших), среди них `test_expired_token_with_db_down_is_extended`, `test_missing_schema_is_disconnected`, `test_db_error_in_user_check_is_not_500`, `test_preflight_inner_space_only_entry_has_no_valid_origin`.
Мутации:
- A: убрано решение по подписи — 7 failed;
- B: не ловится `SQLAlchemyError` — 1 failed (`test_db_error_in_user_check_is_not_500`).
Обе откачены, md5 сверен.
Гейты: pytest 4787 passed / 1 xfailed / 0 failed; ruff 0; mypy Success (195); bandit 0; typecheck/lint/build ok. vitest не запускал: фронт не менялся.

### Изменения тестов прошлого раунда
Неинициализированная БД теперь решается по подписи (по п.1), а не даёт 500. Битый Bearer + валидная cookie на health → 401, как у `/auth/me`.

### ТЗ §8.5 (предлагаемый текст)
«Без токена — `{status}`; при доступной БД отвергнутый токен — 401; при недоступной — расширенный ответ только по подписи токена, `cb_state=unknown`; readiness — запрос к `users`».
