# Backend JWT Blacklist — анализ вариантов

> **Контекст:** решение пользователя от 2026-04-17: реализовать backend-side invalidation токенов при logout.
> **Связь с треком 4:** это **отдельная задача**, не входящая в трек 4 (frontend 401 race). Трек 4 решает гонку на фронте через cleanup-хуки. JWT blacklist — дополнительный слой безопасности.
> **Когда реализовать:** после трека 4, как отдельный трек S5R-2 (трек 6) или задача в Sprint 6/Sprint 8.
> **Статус:** ⬜ анализ, ожидает решения пользователя по выбору варианта.

---

## Зачем нужен JWT blacklist

JWT — stateless токен. Backend подписывает его при выдаче и ставит срок действия (`exp`). При каждом запросе проверяется только подпись и `exp` — **без обращения к БД**. Это быстро и масштабируемо, но имеет фундаментальный недостаток:

**Токен невозможно отозвать до истечения `exp`.**

Это значит:
- После logout старый access-токен **остаётся валидным** до expiry (сейчас — 30 минут).
- Если токен украден (XSS, утечка логов, MITM на HTTP) — злоумышленник пользуется им до expiry.
- Нет возможности «выгнать» пользователя с устройства (например, при смене пароля или подозрении на взлом).

JWT blacklist решает эту проблему, добавляя проверку «этот токен не отозван?» при каждом запросе.

---

## Текущая архитектура (без blacklist)

```
┌─ Frontend ─────────────────────────────────────┐
│                                                 │
│  authStore (Zustand + localStorage persist)     │
│  ├── token: "eyJ..."      (access, 30 min)     │
│  ├── refreshToken: "eyJ..." (refresh, 7 days)   │
│  └── user: { id, username }                     │
│                                                 │
│  client.ts interceptor:                         │
│  request → headers.Authorization = Bearer token │
│  response 401 → doRefresh() → retry             │
│                                                 │
└────────────────────┬────────────────────────────┘
                     │ HTTP
┌────────────────────▼────────────────────────────┐
│  Backend (FastAPI)                               │
│                                                  │
│  POST /auth/login  → выдаёт access + refresh     │
│  POST /auth/refresh → выдаёт новый access        │
│  Depends(get_current_user) → decode JWT,         │
│     проверяет exp + signature, возвращает user    │
│  POST /auth/logout → ??? (ЗАГЛУШКА / НЕТ)       │
│                                                  │
│  БД: SQLite (aiosqlite) — ./data/terminal.db     │
│  Нет таблицы revoked_tokens                      │
│  Нет Redis                                       │
│  Нет token_version в User                        │
└──────────────────────────────────────────────────┘
```

**Проблема:** `POST /auth/logout` на backend'е либо отсутствует, либо ничего не делает кроме ответа 200. Фронт просто удаляет токен из localStorage. Старый токен продолжает работать.

---

## Варианты реализации

### Вариант 1 — SQLite таблица `revoked_tokens`

**Суть:** при logout backend записывает `jti` (JWT ID) отозванного токена в таблицу. Middleware проверяет каждый входящий JWT: «его `jti` не в таблице?»

```
┌─────────────────────────────────┐
│  revoked_tokens (SQLite)    │
├─────────────────────────────────┤
│  id         SERIAL PRIMARY KEY  │
│  jti        VARCHAR(64) UNIQUE  │
│  user_id    INTEGER FK users    │
│  revoked_at TIMESTAMP           │
│  expires_at TIMESTAMP           │  ← для автоочистки
└─────────────────────────────────┘
```

**Flow logout:**
1. Frontend → `POST /auth/logout` с текущим access-token в Authorization.
2. Backend декодирует JWT, извлекает `jti`.
3. `INSERT INTO revoked_tokens (jti, user_id, revoked_at, expires_at)`.
4. Ответ 200.
5. (Опционально) Также revoke refresh-token, если хранится.

**Flow каждого запроса:**
1. Middleware декодирует JWT → получает `jti`.
2. `SELECT 1 FROM revoked_tokens WHERE jti = ?` — если найден → 401.
3. Иначе — пропускает.

**Автоочистка:** cron-job / periodic task удаляет строки, где `expires_at < NOW()` (токен и так уже мёртв).

**Плюсы:**
- ✅ Не нужен Redis — используем существующую SQLite.
- ✅ Надёжно — данные персистентны, переживают перезагрузку backend.
- ✅ Простая миграция (одна таблица).
- ✅ Можно revoke все токены пользователя: `INSERT ... SELECT jti FROM ... WHERE user_id = ?` (при смене пароля).

**Минусы:**
- ❌ **+1 SQL-запрос на каждый API-вызов.** Для нашего масштаба (1 пользователь, локальный сервер) — незаметно. Для production с 1000+ RPS — ощутимо.
- ❌ Таблица растёт (хотя автоочистка по `expires_at` решает).
- ❌ Нет индекса — медленный поиск. С индексом на `jti` — быстрый (B-tree, O(log N)).

**Оценка трудоёмкости:** ~0.5 сессии. Миграция + middleware + endpoint + тесты.

---

### Вариант 2 — Token versioning (поле `token_version` в User)

**Суть:** в таблице `users` добавляется поле `token_version: int` (по умолчанию 1). При выдаче JWT в payload пишется `tv: user.token_version`. При logout — `UPDATE users SET token_version = token_version + 1`. Middleware проверяет: `jwt.tv == user.token_version`.

```
┌───────────────────────────────────┐
│  users (SQLite)               │
├───────────────────────────────────┤
│  ...                              │
│  token_version  INTEGER DEFAULT 1 │  ← новое поле
└───────────────────────────────────┘
```

**Flow logout:**
1. Frontend → `POST /auth/logout`.
2. Backend: `UPDATE users SET token_version = token_version + 1 WHERE id = ?`.
3. Ответ 200.
4. Все ранее выданные JWT мгновенно инвалидированы (их `tv` < нового `token_version`).

**Flow каждого запроса:**
1. Middleware декодирует JWT → `user_id`, `tv`.
2. `SELECT token_version FROM users WHERE id = ?`.
3. Если `tv != token_version` → 401.
4. Иначе — пропускает.

**Плюсы:**
- ✅ **Нет отдельной таблицы.** Одно поле в `users`.
- ✅ **Мгновенная инвалидация ВСЕХ токенов** одного пользователя одним UPDATE.
- ✅ Подходит для сценариев «сменил пароль → все сессии вылетают».
- ✅ Таблица `users` и так читается в `get_current_user` → можно совместить в один запрос (нет дополнительного SQL).

**Минусы:**
- ❌ **Нельзя отозвать один конкретный токен** — только все сразу. Для нашего проекта (один пользователь, одно устройство) — не проблема.
- ❌ Если `get_current_user` сейчас НЕ читает из БД (только декодирует JWT) — придётся добавить SQL-запрос. **Это ключевое изменение:** из stateless auth превращается в stateful.
- ❌ Миграция: добавить поле + обновить все `encode_jwt()` / `decode_jwt()`.

**Оценка трудоёмкости:** ~0.5 сессии. Миграция + изменение `encode_jwt` + `get_current_user` + endpoint + тесты.

---

### Вариант 3 — Redis JTI blacklist

**Суть:** при logout backend записывает `jti` в Redis с TTL = оставшееся время жизни токена. Middleware проверяет: `EXISTS jti` в Redis.

```
Redis key:   revoked:<jti>
Redis value: "1"
Redis TTL:   (jwt.exp - now) секунд
```

**Flow logout:**
1. `SET revoked:<jti> "1" EX <ttl>`.
2. Ответ 200.

**Flow каждого запроса:**
1. `EXISTS revoked:<jti>` — O(1), ~0.1ms.
2. Если 1 → 401. Иначе → пропускает.

**Плюсы:**
- ✅ **Самый быстрый вариант** — Redis O(1) lookup, ~0.1ms. Идеален для high-RPS.
- ✅ Автоочистка бесплатная — Redis TTL.
- ✅ Можно revoke конкретный токен, не трогая другие.

**Минусы:**
- ❌ **Redis не в стеке проекта.** Нужно: установить Redis, добавить зависимость `redis` / `aioredis`, конфигурировать connection pool, Docker-compose для dev-среды.
- ❌ Ещё один point of failure: если Redis упал — blacklist не работает (fallback: пропускать или блокировать?).
- ❌ Redis не персистентный по умолчанию — при рестарте Redis blacklist теряется (RDB/AOF решают, но это доп. конфигурация).
- ❌ Для одного пользователя / dev-сервера — over-engineering.

**Оценка трудоёмкости:** ~1.5 сессии. Redis setup + connection pool + middleware + fallback + endpoint + тесты + Docker-compose обновление.

---

### Вариант 4 — Short-lived access + DB-stored refresh

**Суть:** кардинально сократить время жизни access-token (с 30 мин до 5 мин). Refresh-token хранить в БД (не только в JWT). При logout — удалить refresh-token из БД. Access-token «умрёт сам» через 5 мин, blacklist не нужен.

```
┌───────────────────────────────────┐
│  refresh_tokens (SQLite)      │
├───────────────────────────────────┤
│  id         SERIAL PRIMARY KEY   │
│  user_id    INTEGER FK users     │
│  token_hash VARCHAR(128) UNIQUE  │  ← SHA256 от refresh-token
│  expires_at TIMESTAMP            │
│  revoked    BOOLEAN DEFAULT FALSE│
│  created_at TIMESTAMP            │
└───────────────────────────────────┘
```

**Flow logout:**
1. Backend: `UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = ? AND revoked = FALSE`.
2. Ответ 200.
3. Access-token «протухнет» максимум через 5 мин.

**Flow refresh:**
1. Frontend шлёт refresh-token → backend проверяет: `SELECT ... WHERE token_hash = ? AND revoked = FALSE AND expires_at > NOW()`.
2. Если не найден / revoked → 401 (фронт делает logout).
3. Если OK → выдаёт новый access (5 мин) + опционально ротирует refresh.

**Flow обычного запроса:**
1. Middleware декодирует JWT — **только** проверяет `exp` + signature. **Без обращения к БД.**
2. Всё как сейчас. Токен валиден, пока не протух.

**Плюсы:**
- ✅ **Обычные запросы остаются stateless** — нет дополнительного SQL на каждый вызов!
- ✅ Окно уязвимости минимально (5 мин вместо 30 мин).
- ✅ Refresh-token хранится в БД → можно отозвать, можно видеть активные сессии.
- ✅ Не нужен Redis.
- ✅ Стандартный паттерн (Google, GitHub, Auth0 используют аналогичный подход).

**Минусы:**
- ❌ Между logout и реальной инвалидацией — до 5 минут. Для критичного финансового приложения может быть неприемлемо.
- ❌ Чаще вызывается refresh (каждые 5 мин) — больше нагрузка на `/auth/refresh`.
- ❌ Миграция: новая таблица + переработка `doRefresh` на фронте + сокращение `exp`.
- ❌ Если пользователь offline 5 минут и возвращается — нужен бесперебойный refresh.

**Оценка трудоёмкости:** ~1 сессия. Миграция + backend refresh логика + frontend адаптация `client.ts` + тесты.

---

### Вариант 5 — Гибрид: Token versioning + Short-lived access

**Суть:** комбинация вариантов 2 и 4. Access-token — 5 мин. В JWT — `tv` (token_version). При logout — `token_version++`. Обычные запросы — stateless (проверяют только `exp`). Refresh — проверяет `tv` vs БД.

**Flow обычного запроса:**
- Stateless: только `exp` + signature. Нет SQL.

**Flow refresh:**
- `SELECT token_version FROM users WHERE id = ?`. Если `jwt.tv != db.token_version` → 401.

**Flow logout:**
- `UPDATE users SET token_version = token_version + 1`. Все refresh-вызовы отвергнуты. Access-токены протухнут через 5 мин.

**Плюсы:**
- ✅ Обычные запросы полностью stateless.
- ✅ Нет отдельной таблицы.
- ✅ Инвалидация — мгновенная для refresh, 5 мин для access.
- ✅ Минимум кода.

**Минусы:**
- ❌ Те же 5 минут окна, что у варианта 4.
- ❌ Нельзя отозвать один конкретный токен.

**Оценка трудоёмкости:** ~0.5 сессии.

---

## Сравнительная таблица

| Критерий | 1. PG таблица | 2. Token version | 3. Redis | 4. Short access + DB refresh | 5. Гибрид (2+4) |
|----------|:---:|:---:|:---:|:---:|:---:|
| **SQL на каждый запрос** | +1 SELECT | +1 SELECT (или 0, если совместить с get_user) | 0 (Redis) | 0 | 0 |
| **Redis нужен** | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Новая таблица** | ✅ `revoked_tokens` | ❌ (поле в `users`) | ❌ | ✅ `refresh_tokens` | ❌ (поле в `users`) |
| **Мгновенная инвалидация** | ✅ конкретного токена | ✅ всех токенов | ✅ конкретного | ⚠️ до 5 мин окно | ⚠️ до 5 мин окно |
| **Сложность** | Низкая | Низкая | Средняя | Средняя | Низкая |
| **Трудоёмкость** | 0.5 сессии | 0.5 сессии | 1.5 сессии | 1 сессия | 0.5 сессии |
| **Масштабируемость** | Средняя | Высокая | Высокая | Высокая | Высокая |

---

## Рекомендация

Для MOEX Terminal (1 пользователь, dev-сервер, финансовое приложение) я бы рекомендовал **Вариант 5 (гибрид: token versioning + short-lived access)** как баланс простоты и безопасности:

- Минимум кода (одно поле в `users`, изменение `exp` с 30 мин → 5 мин).
- Обычные запросы остаются stateless.
- Logout реально работает (через 5 мин max).
- Нет Redis, нет новых таблиц.
- При необходимости можно дорастить до варианта 1 или 4, добавив таблицу.

**Альтернативная рекомендация** для максимальной безопасности (мгновенная инвалидация): **Вариант 2 (token versioning)** — тоже минимум кода, но `get_current_user` делает один SQL-запрос на каждый вызов. Для 1 пользователя — незаметно.

---

## Решение пользователя

> TODO: после ревью этого файла пользователь выбирает вариант.
> Выбранный вариант оформляется как отдельный трек S5R-2 (трек 6) или задача в Sprint 6/Sprint 8.

**Выбор:** Вариант 4 — Short-lived access (5 мин) + DB-stored refresh tokens

**Комментарии пользователя (2026-04-17):**
- Проект планирует масштабирование до 1000+ пользователей → нужен вариант, готовый к росту.
- Вариант 4 выбран как баланс: обычные запросы stateless (0 SQL), refresh редкий (~1 раз в 5 мин), можно отозвать конкретную сессию.
- UX не меняется: пользователь логинится один раз, refresh прозрачный (уже реализован в `client.ts`). Перелогин только через 7 дней бездействия или после явного logout.
- Реализация: отдельный трек S5R-2 (трек 6) или задача Sprint 6/Sprint 8.
