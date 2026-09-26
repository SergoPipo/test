## DEV-AUDIT-057 отчёт — S8R fixes, MEDIUM (после ревью)
Статус: ✅ готово к коммиту. Ревью оркестратора: исправлено 1–9.

### 1. Что реализовано
- **nginx: заголовки.** Security-заголовки и `Cache-Control` задаются на уровне `server` (`add_header … always`). Значения идут через `map $upstream_http_*`: если backend прислал свой заголовок, nginx свой не добавляет — дублей нет, CSP Dash не тронут. Своих `add_header`/`expires` нет ни у одной location (п.2).
- **nginx: кэш (п.3).** Ключ map — `"$status:$uri"`:
  - `/assets/` при 200/304 — `public, max-age=2592000, immutable`;
  - всё остальное — `no-cache`: index.html, SPA-fallback, `/favicon.svg`, `/icons.svg`, `/blockly-media/*`, а также 404 по несуществующему хешу.
- **CSP (п.1, 4, 8).**
  - `img-src 'self' data: blob: https://invest-brands.cdn-tinkoff.ru`. Других внешних img/шрифтов/скриптов во фронте нет; URL AI-провайдеров вызывает backend.
  - `media-src 'self'`.
  - `connect-src 'self' ws://$http_host wss://$http_host`. `$http_host` — с портом; cloudflared Host не меняет (гайд §5.3). Подставляется Host только этого же запроса, на других пользователей не влияет.
  - `blockly-demo.appspot.com` из CSP убран.
- **Blockly (п.4).** Медиа грузится с `media: '/blockly-media/'`. Плагин `blocklyMedia` в `vite.config.ts` при build кладёт `node_modules/blockly/media` в `dist/`, в dev отдаёт через middleware (только имена из каталога). В репо ничего не копируется. context7 подтверждает опцию `media` для self-host; грузятся `sprites.png`, 3 mp3, 3 svg. `strategy.spec.ts` на внешний хост не ссылается.
- **Mantine (п.9, context7).** `style=` с CSS-переменными и `<style>` провайдера — nonce не покрывает атрибут `style=`, поэтому `'unsafe-inline'` в `style-src` нужен.
- **Middleware.** У ответа с `ETag` — `no-cache`, у остальных — `no-store`; свой `Cache-Control` эндпоинта сохраняется (п.5). Значения XFO/nosniff вынесены в константы, есть тест паритета с nginx (п.6).
- **CI (п.7).**
  - Новый job `nginx-config`: `nginx -t` на образе `nginx:alpine` с `conf.d/default.conf` и `--add-host backend:127.0.0.1`.
  - Curl-проба: все заголовки ровно по одному на `/`, fallback, `/assets`, 502 `/api`; проверяются кэш и отсутствие `Expires`.
  - Smoke `dist/blockly-media`.

### 2. Файлы
`nginx.conf`, `.github/workflows/ci.yml`, `backend/app/middleware/security_headers.py`, `backend/app/{tax,backtest}/router.py`, `backend/tests/unit/test_nginx_conf.py`, `backend/tests/unit/test_middleware/test_security_headers.py` (новый), `frontend/vite.config.ts`, `frontend/src/components/strategy/BlocklyWorkspace.tsx`, `frontend/src/components/strategy/__tests__/BlocklyWorkspace.test.tsx`.

### 3. Тесты
- **RED:**
  - `assert set() == {'content-sec...'}`;
  - `tax_download assert None == 'no-store'`;
  - `'no-store' == 'no-cache'` (ETag);
  - `AttributeError … _DEFAULT_X_FRAME_OPTIONS`;
  - vitest `expected "vi.fn()" to be called with … ObjectContaining`.
- **Мутация:** вернул `add_header Cache-Control` в location статики → `assert 'add_header' not in …` и `add_header cache-control без always`; откат по md5.
- **Гейты:** pytest 3477 passed / 8 xfailed / 0 failed; ruff 0; mypy Success (187); bandit 0; typecheck 0; lint 0; build ok.
- **vitest:** 964/965. Упал `StrategyEditPageDelete` по таймауту 5000 мс при load average 15 — это флейк S8R-FIX-005, в одиночку 2/2 passed. Прошу перепрогнать на тихой машине.

### 4. Integration points
✅ `main.py:371` (middleware); ✅ плагин в `plugins` vite; ✅ опция `media` в `Blockly.inject`.

### 5. Контракты
API и миграции не менялись.

### 6. Документы / TODO / находки
- **ТЗ §7.6** — заменить блок (устарели `X-XSS-Protection` и `ws://localhost`):
  - Backend: 6 заголовков + `Cache-Control` (`no-store`, при `ETag` — `no-cache`); файлы — `no-store` явно.
  - nginx: тот же набор на все ответы, если backend не прислал свой; CSP SPA — как в п.1; кэш — как в п.1; `add_header` только на уровне server.
- **ФТ §12.6** — добавить: «Интерфейс нельзя встроить в чужой сайт; отчёты и данные не сохраняются в кэше браузера».
- **Гайд §5** — smoke после деплоя: `curl -sI https://<host>/ | grep -i -E 'content-security|x-frame|strict-transport|cache-control'`; в конструкторе проверить кнопки масштаба и консоль (`Refused to…`).
- **Не проверено вживую:**
  - dev-middleware Vite (запускать Vite нельзя);
  - `nginx -t` — проверит CI.
- **Самопроверка:** 1, 2, 4 — не применимо; 3 — тесты идут через настоящие роутеры и middleware; 5 — все вызывающие проверены; 6 — middleware отдаёт только файлы из списка.

### 7. Stack Gotchas
Применены: 30, 31, 48, 60.

### 8. Новая Stack Gotcha (кандидат)
`add_header`/`expires` в location отменяют набор server, а CSP от nginx и от backend пересекаются. Правило: map по `$upstream_http_*`, `add_header` только в server.

### 9. Плагины
py_compile ✅, typecheck ✅, context7 (Blockly, Mantine) ✅, WebSearch (nginx: пустой `add_header` не выводится) ✅, tdd ✅.
