# Хэндофф: Auth-hardening мини-волна (backend + frontend, координированно)

> Отдельная координированная волна, вынесенная из P1 Волны 3 по решению заказчика
> (2026-07-07): перевод токенов на HttpOnly-cookie и устранение принудительного
> разлогина при ротации — это единый backend+frontend фикс, его нельзя делать
> «наполовину» в чисто фронтовой волне.

---

## Зачем отдельно

Два пункта, которые архитектурно неразделимы (оба — про модель хранения и жизненный цикл JWT):

1. **CFG-FE-01** (`tdd_tasks_P1.md:401`) — access/refresh токены лежат в `localStorage` (zustand persist, ключ `auth-storage`), доступны любому JS/XSS. Нужен перевод на **HttpOnly + Secure + SameSite=Strict cookie**.
2. **P1W2-REFRESH-GRACE** (из backlog Волны 2, `P1_WAVE2_LOG.md`) — ротация refresh без grace-окна + два независимых refresh-клиента фронта (`client.ts` `doRefresh` + `aiStreamClient.ts`) без общего single-flight + нет cross-tab-синхронизации → при двух вкладках / активном AI-чате пользователя **принудительно разлогинивает ~каждые 30 минут** (второй конкурентный refresh получает «Token отозван» → `logout()`, а `logout` ещё и стирает `auth-storage` первой вкладки). Атомарность отзыва (backend) уже сделана в Волне 2 (`ee98302`), но grace-окна и фронт-координации нет.

Если сделать только CFG-FE-01 без grace/single-flight — cookie-based flow унаследует ту же гонку ротации. Если сделать только grace — токены останутся в localStorage. Поэтому — вместе.

## Состояние на входе

- **База — последняя завершённая `p1/wave*` ветка.** Если Волна 3 (frontend) уже сделана — базироваться на **`p1/wave3-frontend`** (auth трогает `authStore.ts`/`useWebSocket.ts`/`client.ts`, которые Волна 3 тоже правит в `fe-security`/`fe-network`; базирование поверх Волны 3 делает финальный мерж линейным и без конфликтов). Если auth-hardening запускается ДО Волны 3 — база **`p1/wave2-backend` @ `9cd44aa`**.
- В базе уже есть (Волна 2): атомарный `_revoke_jti` (ON CONFLICT), CSRF-exempt `/auth/refresh`, ротация refresh, `_set_access_token_cookie` для access-токена (частично cookie-based — см. `backend/app/auth/router.py`).
- Существующая инфраструктура cookie: access-token cookie + CSRF-token cookie уже ставятся (login/refresh). Admin/Plotly Dash уже на HttpOnly-cookie (`api/client.ts:7-13`). То есть паттерн в проекте есть — нужно распространить на основной auth-flow и добавить refresh в HttpOnly-cookie.

## Скоуп (что сделать)

### Backend (`app/auth/`)
- Выдавать **refresh-токен в HttpOnly + Secure + SameSite=Strict cookie** (не в JSON-теле), по аналогии с access-cookie. `/auth/refresh` читает refresh из cookie, а не из тела (`RefreshRequest`).
- **Grace-окно ротации:** при обмене старый refresh-jti остаётся валидным ещё N секунд (напр. 30–60с) — в БД поле `rotated_at`/`grace_until` или отдельная трактовка `RevokedToken`. Повторное предъявление в пределах grace → идемпотентно вернуть/переиздать пару, а не «Token отозван». Закрывает и гонку двух вкладок, и обрыв сети на ответе (refresh не сжигается безвозвратно).
- CSRF: расширить `X-CSRF-Token`-защиту на весь cookie-based auth-flow (double-submit).
- **Alembic-миграция** если добавляется колонка для grace.
- **superpowers TDD обязателен** (auth критпуть). `/code-review` по auth обязателен.

### Frontend (`src/stores/`, `src/api/`, `src/services/`, `src/hooks/`)
- Убрать токены из `localStorage`/zustand `persist` (`authStore.ts` — `partialize` только несекретные UI-поля: `user.username`, `is_admin`). Токены живут в HttpOnly-cookie (JS их не видит).
- `client.ts` `doRefresh` и `aiStreamClient.ts` — **общий single-flight** (один in-flight refresh на приложение), а не две независимые реализации.
- **Cross-tab sync:** storage-listener или Web Locks API — вкладки не гонятся за refresh; при «Token отозван» — один retry со свежеперечитанным состоянием вместо немедленного `logout`.
- Убрать `localStorage.removeItem('auth-storage')` из logout-пути, вызванного неудачным refresh (не убивать сессию соседней вкладки).

## Метод
- База — `p1/wave2-backend @ 9cd44aa`. Отдельная ветка (напр. `p1/auth-hardening`).
- **superpowers brainstorm ПЕРЕД кодом** (критпуть + cross-cutting контракт cookie↔frontend).
- Backend: test-first (pytest), pyright 0. Frontend: vitest на single-flight/cross-tab логику, typescript-lsp 0, Playwright на login/refresh/logout-сценарии (в т.ч. две вкладки).
- **Контракт cookie↔frontend** зафиксировать до кода: какие cookie ставит backend (имена, flags, TTL), как фронт триггерит refresh (без тела, полагаясь на cookie), CSRF-поток.
- `/code-review` обязателен по auth (backend) и по api/stores (frontend).
- Тесты гонки ротации: воспроизвести две вкладки / два refresh-клиента (см. `verification_P1` ver-6 suggested_fix — там разобран сценарий и рекомендация).
- Push в `p1/auth-hardening`, remote `s8r/bug-31` не трогать. Доки — `P1_AUTH_HARDENING_LOG.md`, обновить `project_state.md`. Правило двух репо — ветки спрашивать отдельно.

## Ссылки
- Спеки: `tdd_tasks_P1.md` — CFG-FE-01 (401), плюс backend BE-AUTH-02/03 (95, 101) как контекст уже сделанного.
- Гонка ротации разобрана: `P1_WAVE2_LOG.md` (раздел auth + backlog P1W2-REFRESH-GRACE), вердикт верификатора ver-6.
- Существующий cookie-паттерн: `backend/app/auth/router.py` (`_set_access_token_cookie`), `frontend/src/api/client.ts:7-13`.

## Когда делать
Порядок с Волной 3 — на усмотрение заказчика. **Рекомендация: ПОСЛЕ Волны 3** (базироваться на `p1/wave3-frontend`) — тогда фронт-правки auth ложатся поверх Волны 3, финальный мерж всех `p1/wave*` в `s8r/bug-31` остаётся линейным без конфликтов. Можно и до/параллельно, но тогда координировать мерж `authStore.ts`/`useWebSocket.ts`/`client.ts` (пересекаются с `fix/fe-security` и `fix/fe-network`).

---

## ПРОМПТ (копировать в новую сессию — запускать ПОСЛЕ Волны 3)

```
Запускаем auth-hardening мини-волну (backend+frontend, координированно) из P1
код-ревью MOEX-терминала. Прочитай сначала:
- Спринты/Code_Review_Full_2026-07/P1_AUTH_HARDENING_HANDOFF.md (скоуп, метод, контракт)
- Спринты/Code_Review_Full_2026-07/P1_WAVE2_LOG.md (что уже сделано по auth в Волне 2 +
  разбор гонки ротации; backlog)
- Спринты/project_state.md (последние записи 2026-07-07)

Это ОТДЕЛЬНАЯ координированная волна (вынесена из Волны 3): CFG-FE-01 (токены
localStorage → HttpOnly cookie) + P1W2-REFRESH-GRACE (grace-окно ротации + общий
single-flight refresh + cross-tab sync) — устраняет принудительный разлогин при двух
вкладках/AI-чате. Делать backend и frontend вместе; модель хранения токенов нельзя
менять «наполовину».

База — последняя завершённая p1/wave* ветка: если Волна 3 сделана — p1/wave3-frontend,
иначе p1/wave2-backend (@9cd44aa). Отдельная ветка p1/auth-hardening.

Метод: superpowers brainstorm ПЕРЕД кодом (критпуть + cross-cutting контракт
cookie↔frontend — зафиксировать имена/flags/TTL cookie, как фронт триггерит refresh
без тела, CSRF-поток ДО кода). Backend test-first (pytest, pyright 0, alembic если новая
колонка для grace, superpowers TDD обязателен для auth). Frontend: vitest на
single-flight/cross-tab логику, typescript-lsp 0, Playwright на login/refresh/logout +
сценарий ДВУХ вкладок. /code-review обязателен по auth (backend) и api/stores (frontend).
Тест гонки ротации: воспроизвести два конкурентных refresh (см. verification ver-6).

После: гейт (pytest + pnpm test + tsc 0 errors + Playwright) + /code-review + фиксы +
push в p1/auth-hardening (remote s8r/bug-31 не трогать). Доки — P1_AUTH_HARDENING_LOG.md,
обновить project_state. Модель Opus 4.8, коммиты/push — только по подтверждению, ветки
для обоих репо (Develop + Test) спрашивать отдельно. Если увидишь приближение лимита
сессии — остановись и спроси. После этой волны + Волны 3 — предложить финальное сведение
всех p1/wave* в s8r/bug-31 одним PR.
```
