# Changelog — Sprint 4: AI-интеграция + Бэктестинг

> Фиксирует все замечания и изменения, выявленные при проверке результатов спринта.
> Обязательный файл каждого спринта.

<!-- Записи добавляются по мере работы -->

---

## 2026-04-01 — Ревью заказчика: исправление замечаний по секциям 1 и 2

### Критический баг: несовпадение имён полей frontend ↔ backend (2.4)

**Причина:** фронтенд отправлял поля `name`, `model`, `base_url`, а бэкенд (Pydantic) ожидал `display_name`, `model_id`, `api_base_url` → ошибка 422 при сохранении провайдера.

**Исправлено в файлах:**
- `frontend/src/api/aiSettingsApi.ts` — интерфейсы `AIProvider`, `AIProviderCreateParams` приведены к snake_case бэкенда
- `frontend/src/api/aiApi.ts` — интерфейсы `AIProvider`, `AIStatus` приведены к snake_case
- `frontend/src/pages/AISettingsPage.tsx` — все ссылки на поля формы и таблицы обновлены
- `frontend/src/stores/aiChatStore.ts` — ссылки `isActive` → `is_active`, fallback status
- `frontend/src/components/ai/AIChat.tsx` — `displayName` → `display_name`, `modelId` → `model_id`, `usageToday` → `usage_today`, `limitToday` → `daily_limit`

**Результат:** провайдеры (включая Custom/DeepSeek) сохраняются без ошибок.

---

### AI-провайдеры — вкладка в Настройках вместо отдельной страницы (2.1)

**Было:** кнопка «AI-провайдеры» на странице настроек, ведёт на `/settings/ai`.
**Стало:** вкладка «AI-провайдеры» рядом с «Брокер» на `/settings?tab=ai`. Старый URL `/settings/ai` делает redirect.

**Файлы:**
- `frontend/src/pages/SettingsPage.tsx` — добавлена вкладка `ai` с `<AIProvidersContent />`
- `frontend/src/pages/AISettingsPage.tsx` — вынесен `AIProvidersContent` (экспортируемый компонент), `AISettingsPage` стал redirect
- `frontend/src/components/ai/AIChat.tsx` — ссылка «Перейти в настройки» → `/settings?tab=ai`

---

### 5 популярных преднастроенных AI-моделей (2.2)

Добавлены 7 типов провайдеров (вместо 3):

| Тип | Модели | Base URL |
|-----|--------|----------|
| Anthropic Claude | sonnet-4-6, opus-4-6, haiku-4-5 | — (SDK) |
| OpenAI | gpt-4o, gpt-4.1, gpt-4o-mini | — (SDK) |
| DeepSeek | deepseek-chat, deepseek-reasoner | https://api.deepseek.com/v1 |
| Google Gemini | 2.5-pro, 2.5-flash, 2.0-flash | https://generativelanguage.googleapis.com/v1beta/openai |
| Mistral AI | large, medium, small | https://api.mistral.ai/v1 |
| Groq (Llama/Mixtral) | llama-3.3-70b, llama-3.1-8b, mixtral-8x7b | https://api.groq.com/openai/v1 |
| Alibaba Qwen | plus, turbo, max | https://dashscope.aliyuncs.com/compatible-mode/v1 |

**Файлы:**
- `frontend/src/api/aiSettingsApi.ts` — тип `ProviderType` расширен
- `frontend/src/pages/AISettingsPage.tsx` — `MODELS_BY_TYPE`, `PROVIDER_LABELS`, `NEEDS_BASE_URL`, `DEFAULT_BASE_URLS`
- `backend/app/ai/schemas.py` — regex `provider_type` расширен
- `backend/app/ai/providers/factory.py` — `ProviderFactory.create()` поддерживает новые типы через `CustomProvider`

---

### Неограниченные лимиты для free моделей (2.5)

**Было:** `daily_limit` и `monthly_limit` — минимум 1 (ge=1). Лимит 0 невозможен.
**Стало:** минимум 0 (ge=0). Значение 0 = без ограничений.

**Файлы:**
- `backend/app/ai/schemas.py` — `ge=0` для `daily_limit` и `monthly_limit`
- `backend/app/ai/service.py` — `check_budget()`: `daily_limit == 0` → unlimited
- `frontend/src/pages/AISettingsPage.tsx` — показ «∞» при лимите 0, подсказка «0 = без ограничений»
- `frontend/src/components/ai/AIChat.tsx` — badge «∞» при daily_limit=0

---

### Маскированный ключ в таблице провайдеров (2.5)

**Было:** ключ полностью скрыт, не виден в таблице.
**Стало:** колонка «Ключ» в таблице, формат `sk-ab...xyz1` (первые 4 + последние 4).

**Файлы:**
- `frontend/src/pages/AISettingsPage.tsx` — колонка «Ключ» с `p.masked_api_key`
- `frontend/src/api/aiSettingsApi.ts` — поле `masked_api_key` + `is_verified`

---

### Редизайн Strategy Editor — общая панель описания (1.5)

**Было:** два отдельных компонента — `TemplatePanel` (для Blockly) и `StrategyDescription` (для AI), bottom toolbar с кнопками, top bar в AI-режиме.
**Стало:** единый `SharedDescriptionPanel`, используемый и в режиме Blockly (справа), и в AI-режиме (слева).

**Изменения:**
- Новый файл `frontend/src/components/strategy/SharedDescriptionPanel.tsx`
- Заголовок: «Описание стратегии»
- Кнопка «AI-помощник» в header (меняется на «Вернуться к редактору» в AI-режиме)
- «Пустой шаблон» — копирует в буфер + вставляет в textarea
- «Проверить и сформировать блоки» → **«Применить на схеме»** (из AI-режима переключается на схему)
- «Сформировать на основании схемы» → **«Заполнить по схеме»**
- Обе кнопки видны всегда (и в Blockly, и в AI)
- **Убран bottom toolbar** со страницы «Редактор»
- **Убран top bar** AI-режима (AIModePanel)
- Описание синхронизировано через `useAIChatStore` (единый source of truth)

**Файлы:**
- `frontend/src/components/strategy/SharedDescriptionPanel.tsx` — **новый**
- `frontend/src/pages/StrategyEditPage.tsx` — переработан Editor Tab, убраны TemplatePanel и AIModePanel

---

### Вылет на страницу логина при сохранении провайдера

**Проблема:** при POST-запросе с просроченным JWT фронтенд interceptor делал `logout()` + redirect на `/login`. Пользователь терял все введённые данные без пояснения.

**Исправление:**
- `frontend/src/api/client.ts` — interceptor больше не перенаправляет на логин при мутирующих запросах (POST/PATCH/DELETE). Ошибка передаётся компоненту для обработки.
- `frontend/src/pages/AISettingsPage.tsx` — `handleSave` ловит 401 и показывает «Сессия истекла», 422 показывает детали валидации.

---

### API-ключ полностью скрыт + браузер предлагает сохранить как пароль

**Проблема:** `PasswordInput` маскировал весь ключ точками. Браузер считал поля формы за логин/пароль.

**Исправление:**
- `PasswordInput` заменён на `TextInput` с `autoComplete="off"`, `data-1p-ignore`, `data-lpignore`, `data-form-type="other"`
- При редактировании показывается подсказка с маскированным ключом (`sk-ab...xyz1`)
- Placeholder: «Оставьте пустым, чтобы не менять» при редактировании
- Форма обёрнута в `<form autoComplete="off">` для подавления менеджера паролей
- Поле «Название» тоже получило `autoComplete="off"`

**Файлы:**
- `frontend/src/pages/AISettingsPage.tsx`
- `frontend/src/api/client.ts`

---

### Ошибка 500 при загрузке провайдеров — устаревшая схема таблицы

**Причина:** таблица `ai_provider_configs` в БД имела старую схему из Sprint 3 (колонки `provider`, `model_name`, `is_default`), а модель ORM ожидала новую (`provider_type`, `display_name`, `model_id`, `daily_limit`, `monthly_limit`, и т.д.). SQLite → `OperationalError: no such column: provider_type`.

**Исправление:** пересоздание таблицы с 17 колонками по актуальной ORM-модели. Старых данных не было (0 строк).

---

### Фронтенд не парсил ответ GET /providers (массив vs объект)

**Причина:** бэкенд возвращал `[...]` (массив), а фронтенд обращался к `response.data.providers` (ожидал `{providers: [...]}`).

**Исправление:**
- `frontend/src/pages/AISettingsPage.tsx` — `Array.isArray(data) ? data : data.providers`
- `frontend/src/stores/aiChatStore.ts` — аналогично

---

### API-ключ: видимость и менеджер паролей

**Исправление:**
- Возвращён `PasswordInput` (маскирует ввод, есть кнопка «показать»)
- `autoComplete="new-password"` — подавляет предложение «сохранить пароль»
- Форма обёрнута в `<form autoComplete="off">`
- При редактировании: подсказка с маскированным ключом, placeholder «Оставьте пустым, чтобы не менять»

---

### Ошибка валидации api_key при редактировании провайдера

**Причина:** при редактировании `api_key` отправлялся как пустая строка → бэкенд Pydantic отклонял (`min_length=1`).

**Исправление:** `frontend/src/pages/AISettingsPage.tsx` — при update не включаем `api_key` в payload если поле пустое.

---

### Статус провайдера ✗ вместо ⚠ + лишние лимиты 0/100

**Причина 1:** бэкенд не возвращал поле `status` → фронтенд показывал ✗ (fallback на error).
**Исправление:** `backend/app/ai/router.py` — `_to_response()` добавляет `status: "ok"|"warning"` на основе `is_verified`.

**Причина 2:** endpoint `/usage` при отсутствии активного провайдера возвращал дефолты из .env (100/3000).
**Исправление:** если провайдеры есть но не активны — возвращаем нули. Фронтенд скрывает usage stats при нулевых лимитах.

---

### Лимиты по каждому провайдеру + убран общий блок лимитов

**Было:** общий блок «Использование сегодня: 0/100» ниже таблицы. В таблице — только дневной лимит.
**Стало:** общий блок убран. В колонке «Исп/Лим» — две строки: `День: ∞` и `Мес: ∞` (или `usage/limit`) для каждого провайдера.

---

### API-ключ показывается при вводе

API-ключ теперь вводится в обычный `TextInput` (не маскируется при вводе). При редактировании показывается маскированный текущий ключ в подсказке.

**Файл:** `frontend/src/pages/AISettingsPage.tsx`

---

### Добавлен OpenRouter как преднастроенный провайдер

Пользователь использует OpenRouter (https://openrouter.ai) как прокси к DeepSeek и другим моделям. Модель `deepseek/deepseek-r1:free` устарела, актуальная: `deepseek/deepseek-r1`.

**Изменения:**
- `frontend/src/api/aiSettingsApi.ts` — тип `openrouter` добавлен в `ProviderType`
- `frontend/src/pages/AISettingsPage.tsx` — OpenRouter в списке провайдеров с 7 моделями (DeepSeek, Gemma, Qwen, Nemotron, GPT-OSS), base_url `https://openrouter.ai/api/v1`
- `backend/app/ai/schemas.py` — `openrouter` в regex
- `backend/app/ai/providers/factory.py` — `openrouter` в `_openai_compatible`
- БД: обновлены 2 провайдера (тип `openrouter`, модель `deepseek/deepseek-r1`, base_url OpenRouter)

### Обновлён список моделей OpenRouter

`deepseek/deepseek-r1:free` убрана с OpenRouter — такой модели больше нет. `deepseek/deepseek-r1` — платная ($0.70/$2.50 за 1M токенов). Обновлён список: 9 моделей, из них 7 бесплатных (Llama, Qwen, Nemotron, Gemma, GPT-OSS, Hermes).

---

### Модель — свободный ввод с подсказками вместо жёсткого списка

**Было:** `Select` (только выбор из списка) или `TextInput` (только ручной ввод, для custom).
**Стало:** `Autocomplete` для всех типов — можно выбрать из подсказок или ввести любое название вручную. Для OpenRouter список подсказок пустой — пользователь указывает модель самостоятельно (модели на OpenRouter постоянно обновляются).

**Файл:** `frontend/src/pages/AISettingsPage.tsx`

---

### Кнопка «Проверить ключ» без сохранения

**Было:** кнопка видна только при редактировании; при добавлении — нужно сначала сохранить.
**Стало:** кнопка видна всегда. Проверка происходит **без сохранения** — через новый endpoint `POST /providers/verify-credentials`, который принимает credentials напрямую и проверяет тестовым запросом к API провайдера.

**Файлы:**
- `backend/app/ai/schemas.py` — новая схема `AIProviderVerifyRequest`
- `backend/app/ai/router.py` — endpoint `verify_credentials`
- `frontend/src/api/aiSettingsApi.ts` — метод `verifyCredentials`
- `frontend/src/pages/AISettingsPage.tsx` — кнопка вызывает `verifyCredentials` для новых, `verifyProvider` для существующих без смены ключа

---

### Проверка ключа всегда показывала «Ключ невалиден»

**Причина:** бэкенд возвращает поле `verified`, а фронтенд читал `valid` → всегда `undefined` → всегда ошибка.

**Исправление:** `frontend/src/api/aiSettingsApi.ts` — `valid` → `verified` в `VerifyResult`. Все ссылки в `AISettingsPage.tsx` обновлены.

---

### Статус провайдера не обновляется + «Проверить ключ» из меню без обратной связи

**Проблема 1:** после сохранения нового провайдера `is_verified=false` → статус красный, хотя credentials уже были проверены.
**Исправление:** после сохранения нового провайдера — автоматически вызывается `verifyProvider`, бэкенд ставит `is_verified=true`.

**Проблема 2:** «Проверить ключ» из меню (три точки) не показывал результат.
**Исправление:** `handleVerify` теперь показывает toast-уведомление с результатом и обновляет таблицу через `fetchProviders()`.

**Проблема 3:** поле `status` добавлено в `_to_response()`, но не в Pydantic `AIProviderResponse` → Pydantic отфильтровывал → фронтенд получал `undefined` → fallback на error (красный).
**Исправление:** `backend/app/ai/schemas.py` — добавлено `status: str` в `AIProviderResponse`.

---

### Счётчик запросов AI не обновляется после сообщений

**Причина:** после получения ответа от AI не вызывался `fetchStatus()`.
**Исправление:** `frontend/src/stores/aiChatStore.ts` — добавлен `get().fetchStatus()` после завершения стриминга.

---

### Кнопки в панели описания стратегии сделаны крупнее и выразительнее

**Было:** `variant="subtle"`, `size="compact-xs"` — выглядели как текст, а не кнопки.
**Стало:** `variant="light"`, `size="compact-sm"` / `size="sm"` — с фоновой заливкой, как «Генерировать» и «Сохранить».

Иконки заменены на стрелки направления:
- **«Применить на схеме»** — `IconArrowBadgeRight` (→ из описания в схему)
- **«Заполнить по схеме»** — `IconArrowBadgeLeft` (← из схемы в описание)

**«Очистить историю»** — `variant="light"`, `color="red"`, `size="compact-sm"`.

**Файлы:** `SharedDescriptionPanel.tsx`, `AIChat.tsx`

---

### JWT auto-refresh — сессия больше не истекает через 30 минут

**Было:** access token жил 30 минут, refresh_token не использовался → 401 → logout.
**Стало:**
- `authStore.ts` — хранит `refreshToken` рядом с `token`
- `LoginPage.tsx`, `SetupPage.tsx` — сохраняют `refresh_token` при логине
- `client.ts` — interceptor при 401 автоматически обновляет токен через `POST /auth/refresh`, повторяет исходный запрос. Logout только если refresh тоже протух.

---

### Счётчик в AI-чате: только для платных, день + месяц

**Было:** Badge `2 / ∞ запросов` — показывался всегда, считал запросы, не токены.
**Стало:** строка `Провайдер: День X/Y | Мес X/Y` — показывается **только** если лимиты > 0 (платные провайдеры). Для бесплатных (лимит=0) — скрыта.

---

### В чате вместо «AI» показывается имя провайдера

**Было:** дублирование — заголовок «AI» + текст «AI думает» в пузыре ожидания. В ответах — всегда «AI».
**Стало:** «НВидиа думает ...» (одна строка, имя из настроек провайдера). В ответах — тоже имя провайдера. В сообщениях пользователя — «Вы».

**Файл:** `frontend/src/components/ai/AIChat.tsx`

---

### AI-помощник: 7-секционный шаблон + контекст схемы + пользовательские инструкции

**Проблема 1:** AI выдавал свой формат шаблона (6 секций, другие названия) вместо проектного 7-секционного.
**Исправление:** обновлён системный промпт в `backend/app/ai/prompts.py` — добавлен `STRATEGY_TEMPLATE_FORMAT` с точным форматом, примером и правилами. `chat_router.py` использует его.

**Проблема 2:** AI не видел блоки на схеме — не мог описать текущую стратегию.
**Исправление:** `ChatRequest` получил поле `context: dict | None`. Фронтенд уже передавал контекст (`buildAIContext()` в `StrategyEditPage.tsx`), но бэкенд его игнорировал. Теперь `_build_messages()` включает блоки, описание и код стратегии в контекст LLM.

**Новая функция:** пользовательские инструкции для AI-помощника.
- Таблица `user_ai_settings` с полем `custom_instructions`
- Endpoints `GET/PUT /settings/ai/instructions`
- UI: textarea «Инструкции для AI-помощника» на вкладке AI-провайдеры (Настройки)
- Инструкции добавляются к системному промпту при каждом запросе

**Чеклист:** добавлены пункты 1.13, 1.14, 1.15 в `owner_checklist_s4.md`.

**Файлы:**
- `backend/app/ai/prompts.py` — `STRATEGY_TEMPLATE_FORMAT`
- `backend/app/ai/chat_router.py` — контекст + инструкции в промпт
- `backend/app/ai/chat_schemas.py` — `context` в `ChatRequest`
- `backend/app/ai/router.py` — endpoints для инструкций
- `backend/app/common/models.py` — модель `UserAISettings`
- `frontend/src/api/aiSettingsApi.ts` — `getInstructions`, `updateInstructions`
- `frontend/src/pages/AISettingsPage.tsx` — UI для инструкций

---

### Краш страницы при отправке сообщения с вложением

**Причина 1:** `ReferenceError: Can't find variable: Badge` — удалён импорт `Badge` из `AIChat.tsx`, но он используется для отображения вложений в `MessageBubble`.
**Исправление:** возвращён импорт `Badge` в `AIChat.tsx`.

**Причина 2:** `422 Unprocessable Entity` на `/ai/chat/stream` — фронтенд отправлял `provider_id` и `context`, но `ChatRequest` не принимал лишние поля (Pydantic 2 строгий по умолчанию).
**Исправление:** добавлено `provider_id: int | None = None` в `ChatRequest`, плюс `model_config = {"extra": "ignore"}` для безопасного игнорирования других лишних полей.

**Файлы:** `frontend/src/components/ai/AIChat.tsx`, `backend/app/ai/chat_schemas.py`

---

### Ошибка 422 при отправке вложения (скриншота) в чат

**Причина:** фронтенд отправляет `{name, type, data}`, бэкенд `AttachmentItem` ожидал `{filename, content_type, data_base64}`.
**Исправление:** `backend/app/ai/chat_schemas.py` — поля `AttachmentItem` приведены к `name`, `type`, `data`.

---

### «Невалидный токен» в AI-чате — streaming обходил auto-refresh

**Причина:** AI-чат использует `fetch` (SSE streaming), а не Axios. Interceptor с auto-refresh работал только для Axios-запросов.
**Исправление:** `frontend/src/services/aiStreamClient.ts` — при 401 вызывается `refreshTokenIfNeeded()`, повторяется запрос с новым токеном. Если refresh тоже протух — logout.

---

### Запланировано на Sprint 7: AI слэш-команды

Утверждён план по добавлению `/команд` в AI-чат для контекстной подгрузки данных (`/backtest`, `/chart`, `/strategy`, `/session`, `/portfolio`, `/help`). Реализация в S7 (после S5 торговля и S6 уведомления). Также запланировано обновление ФТ, ТЗ и плана разработки.

Подробный план: `.claude/plans/purring-herding-badger.md`

---

### Переключение модели прямо в чате

**Было:** dropdown в чате был косметическим — бэкенд всегда использовал активный провайдер из настроек. Формат отображения различался: 1 провайдер → текст, >1 → Select.
**Стало:**
- Select всегда отображается в едином формате `Имя (модель)` — и при одном, и при нескольких провайдерах
- Бэкенд учитывает `provider_id` из запроса: если передан — использует указанный провайдер, если нет — активный из настроек
- Переключатель в настройках = модель по умолчанию при открытии чата. В чате можно сменить для конкретного разговора.

**Файлы:**
- `backend/app/ai/service.py` — новый метод `get_provider_by_id()`
- `backend/app/ai/chat_router.py` — оба endpoint (chat, stream) учитывают `provider_id`
- `frontend/src/components/ai/AIChat.tsx` — единый Select вместо условного Text/Select

---

### Счётчик лимитов привязан к выбранному в чате провайдеру

**Было:** счётчик брал данные из `/ai/status` (активный провайдер из настроек). Если активный — безлимитный, счётчик скрывался, даже при выборе платного провайдера в чате.
**Стало:** счётчик берёт `daily_limit`/`monthly_limit`/`usage_today`/`usage_month` из выбранного в чате провайдера (`selectedProvider`). Показывается если хотя бы один лимит > 0.

**Файлы:** `frontend/src/components/ai/AIChat.tsx`, `frontend/src/api/aiApi.ts` (добавлены `usage_month`, `monthly_limit`)

---

### Модель сбрасывалась после каждого сообщения + счётчик не обновлялся

**Проблема 1:** `fetchProviders()` после каждого сообщения переключал выбранный провайдер обратно на активный из настроек.
**Исправление:** `aiChatStore.fetchProviders()` — auto-select только если `selectedProviderId` ещё не установлен или провайдер удалён.

**Проблема 2:** `increment_usage` на бэкенде увеличивал счётчик активного провайдера из настроек, а не выбранного в чате.
**Исправление:** `service.py` — `increment_usage` принимает `provider_id`, обновляет именно его. `chat_router.py` передаёт `request.provider_id`.

**Проблема 3:** Лимиты на второй строке вместо одной.
**Исправление:** Select и лимиты в одной `Group` на одной строке.

**Файлы:** `aiChatStore.ts`, `AIChat.tsx`, `service.py`, `chat_router.py`

---

### Учёт входящих/исходящих токенов вместо дневных/месячных лимитов

**Было:** счётчик запросов (+1 за сообщение) с `daily_limit`/`monthly_limit`.
**Стало:** раздельный учёт `prompt_tokens` (↑входящие) и `completion_tokens` (↓исходящие) из реального ответа API.

Изменения:
- **БД:** убраны `daily_limit`, `monthly_limit`, `usage_today`, `usage_month`. Добавлены `prompt_tokens_limit`, `completion_tokens_limit`, `prompt_tokens_used`, `completion_tokens_used`, `price_per_1m_prompt`, `price_per_1m_completion`
- **OpenAI provider:** `stream_options={"include_usage": True}` + `get_last_usage()` для реальных токенов из streaming
- **Fallback:** если provider не вернул usage — оценка `len(text) / 4`
- **Настройки:** форма с лимитами ↑/↓ токенов + цена за 1M. Кнопка «Сбросить счётчик» в меню провайдера
- **Чат:** `↑12 450 / 827 000 | ↓8 200 / ∞`

**Файлы:** `models.py`, `schemas.py`, `service.py`, `chat_router.py`, `router.py`, `openai_provider.py`, `aiSettingsApi.ts`, `aiApi.ts`, `AISettingsPage.tsx`, `AIChat.tsx`

---

### Страница списка бэктестов

**Было:** ссылка «Бэктесты» в сайдбаре вела на `/backtests` → 404 (маршрут не зарегистрирован).
**Стало:** новая страница `BacktestListPage` — таблица со всеми бэктестами (ID, стратегия, инструмент, статус, прибыль, сделки, дата). При клике → страница результатов. Если бэктестов нет — сообщение «Ни одного бэктеста ещё не выполнено».

**Файлы:**
- `frontend/src/pages/BacktestListPage.tsx` — **новый**
- `frontend/src/App.tsx` — маршрут `/backtests`

---

### Бэкенд: endpoint для списка бэктестов + исправлен URL

**Проблема:** фронтенд обращался к `/backtests`, бэкенд слушал на `/backtest` (разные). Также отсутствовал endpoint `GET /` для списка.
**Исправление:**
- `frontend/src/api/backtestApi.ts` — URL приведены к `/backtest` (единственное число, как на бэкенде)
- `backend/app/backtest/router.py` — добавлен `GET /` (список бэктестов пользователя с именем стратегии)
- `frontend/src/stores/backtestStore.ts` — парсинг массива из ответа

---

### Разделены поля описания: «Содержание» и «Редактор»

**Было:** описание стратегии на вкладке «Содержание» (свободный текст) было привязано к `useAIChatStore.description` (7-секционный шаблон). Изменение одного меняло другое.
**Стало:** два отдельных поля:
- `description` (локальный state) — свободный текст на вкладке «Содержание»
- `storeDescription` (aiChatStore) — 7-секционный шаблон на вкладке «Редактор» (описание параметров)

При загрузке стратегии оба заполняются из `text_description`. При сохранении — берётся локальный `description`.

**Файл:** `frontend/src/pages/StrategyEditPage.tsx`

---

### Вкладка «Содержание»: автокомплит инструментов + период бэктеста

**Инструменты:** `TextInput` заменён на `Autocomplete` с поиском по MOEX API. Debounce 300ms, поиск по последнему тикеру после запятой, подсказки с тикерами из базы. При выборе — добавляется к списку через запятую.

**Период:** `DateInput` с маской — набираете 01042026 → отображается 01.04.2026. Точки ставятся автоматически. Рядом иконка календаря для выбора мышью.

**Инструмент:** один (не несколько) — Autocomplete с поиском по MOEX, подсказки `SBER — Сбербанк`. При выборе подставляется тикер.

**Решение:** один инструмент на бэктест — стандартная модель Backtrader. Портфельный бэктест (несколько инструментов с распределением капитала) — задача для будущих спринтов.

---

### Вкладка «Содержание» — таблица бэктестов вместо полей запуска

**Было:** поля инструмент, таймфрейм, период (дублировали модалку).
**Стало:** компактная таблица бэктестов стратегии (инструмент, ТФ, статус, результат, сделки, дата). Кликабельные строки → переход к результатам. Если нет бэктестов — сообщение «Ещё не запускали».

**Модалка бэктеста:**
- `TextInput` → `Autocomplete` с поиском по MOEX (как в Header)
- `DatePickerInput` (огромный) → `DateInput` с компактным popover, маска ДД.ММ.ГГГГ
- `\u20BD` → `₽` в суффиксе начального капитала

**Бэкенд:** `GET /api/v1/backtest/?strategy_id=X` — фильтр бэктестов по стратегии.

**Файлы:** `StrategyEditPage.tsx`, `BacktestLaunchModal.tsx`, `backtestApi.ts`, `backtest/router.py`

---

### Ошибка 422 при запуске бэктеста + компактный календарь

**Причина 422:** фронтенд отправлял `strategy_id` + `strategy_version`, бэкенд ожидал `strategy_version_id`. Также `slippage_mode: 'percent'` vs `'pct'`, и тикер не обрезался (`SBER — Сбербанк...` вместо `SBER`).

**Исправления:**
- `BacktestLaunchModal` принимает `strategyVersionId` и отправляет `strategy_version_id`
- Тикер обрезается до первого `—`
- `percent` → `pct`

**Календарь:** добавлены `popoverProps` и `styles` для уменьшения размера (280px, ячейки 28×28, шрифт 12px).

**Layout «Содержание»:** возвращён двухколоночный — слева описание + бэктесты + кнопка, справа код Python.

---

### Бэктест падал: ATR генерировался с self.data.close вместо self.data

**Ошибка:** `'Lines_LineSeries_LineSeriesStub' object has no attribute 'high'`
**Причина:** генератор кода передавал `self.data.close` для ATR, а ATR требует полные OHLC данные (`self.data`). Backtrader не находил `.high` на одной линии close.
**Исправление:** `backend/app/strategy/code_generator.py` — ATR обрабатывается отдельным случаем, передаёт `self.data` вместо `self.data.close`.

Также установлен `pandas` (отсутствовал, из-за чего Backtrader не инициализировался).

---

### Ошибка 500 на странице бэктестов: `created_at` → `started_at`

**Причина:** модель `Backtest` не имеет поля `created_at` (есть `started_at`). Endpoint `list_backtests` обращался к несуществующему полю.
**Исправление:** `backend/app/backtest/router.py` — `bt.created_at` → `bt.started_at`.

---

### Версия стратегии в списке бэктестов + удаление бэктестов

- Список бэктестов показывает `Тестовая (v61)` — имя стратегии с номером версии
- Бэкенд: `version_number` добавлен в ответ `list_backtests`
- Бэкенд: `DELETE /api/v1/backtest/{id}` — удаление бэктеста с связанными сделками
- Фронтенд: иконка корзинки в таблице бэктестов (и на странице списка, и на вкладке «Содержание» стратегии)

**Файлы:** `backtest/router.py`, `backtestApi.ts`, `BacktestListPage.tsx`, `StrategyEditPage.tsx`

---

### Бэктест не запускался: backtrader/pandas + несовпадение полей

**Причина 1:** `backtrader is not installed` — на самом деле отсутствовал `pandas` (catch ImportError ловил оба). Установлен `pandas`.

**Причина 2:** фронтенд отправлял `strategy_id` + `strategy_version`, бэкенд ожидал `strategy_version_id`. Бэкенд возвращал `backtest_id`, фронт ожидал `id`.
**Исправление:** `backtestStore.ts` — `response.data.backtest_id || response.data.id`. `BacktestLaunchModal` — отправляет `strategy_version_id`.

---

### Кастомный DateMaskInput: маска ДД.ММ.ГГГГ + компактный календарь

Установлен `react-imask`. Создан компонент `DateMaskInput`:
- Текстовое поле с маской `00.00.0000` — после 2 цифр автоточка
- Рядом иконка календаря → компактный popover (~220px)
- Навигация: стрелки ← → и «Апрель 2026» по центру
- Ячейки 26×26px, шрифт 12px

**Файлы:**
- `frontend/src/components/common/DateMaskInput.tsx` — **новый**
- `frontend/src/components/backtest/BacktestLaunchModal.tsx` — использует DateMaskInput

---

### История чата загружается с сервера (не теряется при обновлении страницы)

**Было:** история хранилась только в памяти браузера (Zustand). При обновлении страницы — терялась.
**Стало:** при открытии AI-чата история загружается из БД (`strategy_versions.ai_chat_history`).

**Файлы:**
- `backend/app/ai/chat_router.py` — endpoint `GET /ai/chat/history/{strategy_id}`
- `frontend/src/api/aiApi.ts` — метод `getHistory(strategyId)`
- `frontend/src/stores/aiChatStore.ts` — `loadHistory()` конвертирует серверные сообщения в ChatMessage[]
- `frontend/src/components/ai/AIChat.tsx` — вызов `loadHistory` при монтировании (если messages пуст)

**Файл:** `frontend/src/pages/AISettingsPage.tsx`, `backend/app/ai/schemas.py`

---

### Лимиты в таблице: день + месяц для каждого провайдера

**Было:** одна строка дневного лимита + общий блок снизу.
**Стало:** две строки (`День: ∞` / `Мес: ∞`) в колонке каждого провайдера. Общий блок убран.

---

## 2026-04-03 — Ревью заказчика: продолжение

### Таймфреймы кириллицей в списках бэктестов

**Было:** в колонке ТФ выводилось сырое значение (`D`, `1h`, `W`).
**Стало:** кириллические метки (`Д`, `1ч`, `Н`) — как в селекторе таймфрейма при запуске бэктеста.

**Файлы:**
- `frontend/src/pages/BacktestListPage.tsx` — добавлен маппинг `TIMEFRAME_LABELS`
- `frontend/src/pages/StrategyEditPage.tsx` — добавлен маппинг `TIMEFRAME_LABELS`

---

### Playwright: автоматическое тестирование UI

Установлен Playwright + Chromium для автоматической проверки UI через headless-браузер.
Скрипт e2e/screenshot.ts: логин, навигация, скриншоты.

**Файлы:**
- `frontend/e2e/screenshot.ts` — скрипт скриншотов (в .gitignore)
- `frontend/.gitignore` — добавлена папка `e2e/`

---

### Структурированный ответ GET /backtest/{id}

**Было:** бэкенд возвращал плоские поля (net_profit, total_trades, etc.).
Фронтенд ожидал вложенные объекты (metrics, benchmark, trades, equity_curve).
Header показывал «• SBER • D» без имени стратегии.

**Стало:**
- Добавлен `_build_backtest_response()` — собирает вложенную структуру
- `strategy_name` и `version_number` через JOIN к Strategy/StrategyVersion
- `metrics` — dict с ключами, совпадающими с фронтовым `BacktestMetrics`
- `benchmark` — dict с `strategy_return`, `buy_hold_return`, `index_return`
- `equity_curve` — массив с `time` (unix timestamp), `equity`, `drawdown`
- `trades` — массив TradeRecord
- Header: «Тестовая • SBER • Д» (кириллический ТФ)

**Также исправлен баг:** `net_profit_pct=0` в list_backtests показывался как null
(Decimal("0.0000") — falsy в Python). Исправлено: `is not None`.

**Файлы:**
- `backend/app/backtest/router.py` — `_build_backtest_response()`, исправлен `get_backtest`
- `backend/app/backtest/schemas.py` — добавлены `BacktestBenchmark`, обновлён `BacktestResponse`
- `frontend/src/pages/BacktestResultsPage.tsx` — добавлен `TIMEFRAME_LABELS`

---

### Авто-верификация провайдера после редактирования

**Было:** при редактировании провайдера (смена модели, URL) и нажатии «Сохранить» —
статус в таблице становился жёлтым (⚠), хотя ключ был проверен в модалке.
Причина: верификация в модалке вызывает `verify-credentials` (без сохранения),
а «Сохранить» вызывает `update_provider` (без верификации). Результат не связан.

**Стало:**
1. Бэкенд: `is_verified` сбрасывается при смене `model_id` или `api_base_url`
   (раньше — только при смене `api_key`).
2. Фронтенд: после успешного PATCH `update_provider` автоматически запускается
   `handleVerify(id)` — как и при создании нового провайдера.
   Пользователь видит зелёный статус сразу.

**Файлы:**
- `backend/app/ai/service.py` — сброс `is_verified` при смене model_id/api_base_url
- `frontend/src/pages/AISettingsPage.tsx` — авто-верификация после save при редактировании

---

### WebSocket: добавлен JWT-токен при подключении

**Было:** фронтенд подключался к `ws://localhost:8000/ws` без JWT-токена.
Бэкенд отклонял соединение (HTTP 403), пользователь видел «Ошибка WebSocket соединения».

**Стало:** WebSocket URL включает `?token=<JWT>` из authStore.
`useAuthStore.getState().token` — берёт текущий JWT из Zustand persist storage.

**Файл:** `frontend/src/stores/backtestStore.ts`

---

### IMOEX benchmark: исправлен URL MOEX ISS

**Было:** ISS клиент запрашивал свечи IMOEX по URL
`/iss/engines/stock/markets/shares/securities/IMOEX/candles.json` — но IMOEX это индекс,
а не акция. Возвращал 0 свечей → benchmark_imoex_pct = NULL → отображалось 0%.

**Стало:** клиент определяет market по тикеру: INDEX_TICKERS → `market=index`, остальные → `shares`.
IMOEX, RGBI, RTSI и другие индексы теперь загружаются корректно.

**Файл:** `backend/app/broker/moex_iss/client.py` — `get_candles()`, строка с URL

---

### Принудительное закрытие позиций в конце бэктеста

**Было:** если стратегия открывала позицию, но не закрывала до конца периода,
Backtrader не считал это завершённой сделкой. Результат: прибыль +738 ₽ при 0 сделках.

**Стало:** `_compile_strategy()` оборачивает пользовательский класс в `WrappedStrategy`,
который в методе `stop()` вызывает `self.close()` для всех открытых позиций.
Нереализованный P&L превращается в завершённую сделку с корректными метриками.

**Файл:** `backend/app/backtest/engine.py` — `_compile_strategy()`

---

### Кнопка «Стоп» при стриминге AI

**Было:** во время вывода ответа AI кнопка «Отправить» была disabled, прервать генерацию нельзя.

**Стало:** при `isStreaming=true` кнопка отправки заменяется на красную кнопку ■ (Стоп).
Нажатие вызывает `stopStreaming()` — прерывает SSE поток через AbortController,
сообщение сохраняется с пометкой `[Прервано]`. Кнопка возвращается к ▶ (Отправить).

**Файлы:**
- `frontend/src/components/ai/ChatInput.tsx` — prop `isStreaming`/`onStop`, переключение иконки
- `frontend/src/components/ai/AIChat.tsx` — передача `stopStreaming` и `isStreaming`

---

### Динамические условия И/ИЛИ (N входов вместо 2)

**Было:** блоки «И» и «ИЛИ» имели ровно 2 входа (A, B). Для 3+ условий
нужно вкладывать один блок в другой — неудобно.

**Стало:** блоки имеют кнопку «⊕» (+ условие), добавляющую новый вход.
INPUT0, INPUT1 — обязательные, INPUT2, INPUT3, ... — по кнопке.
Текстовый формат: `(усл1) И (усл2) И (усл3)`, JSON: `conditions: [c1, c2, c3]`.

Вся цепочка обновлена:
- Blockly: динамические входы с saveExtraState/loadExtraState
- JSON-генератор: массив `conditions` произвольной длины
- Блоки → текст: `(A) И (B) И (C)` через join
- Текст → блоки: восстановление N входов через `extraState`
- Бэкенд парсер: `conditions: [ref1, ref2, ...]` вместо `left`/`right`
- Генератор Python: уже поддерживал `conditions` массив
- AI промпт: обновлён — AI знает про цепочки условий

**Файлы:**
- `frontend/src/components/blockly/BlockDefinitions.ts`
- `frontend/src/components/blockly/BlockGenerators.ts`
- `frontend/src/utils/blocksToTemplate.ts`
- `frontend/src/utils/flatBlocksToWorkspace.ts`
- `frontend/src/components/strategy/BlocklyWorkspace.tsx`
- `frontend/src/pages/StrategyEditPage.tsx`
- `backend/app/strategy/block_parser.py`
- `backend/app/ai/prompts.py`

---

### Исправление: «Применить на схему» не связывало блоки при 3+ условиях

**Было:** при тексте `(усл1) И (усл2) И (усл3)` блоки разъезжались — условия
не подключались к сигналу входа/выхода. Три проблемы:
1. `conditions` содержал `__local_N` ссылки, не резолвившиеся в реальные ID блоков
2. `entry_signal.condition` указывал на последнее условие, а не на logic-блок
3. Фронтенд не обрабатывал `type: "logic"` (только `type: "condition"`)

**Стало:**
- `_resolve_local_refs` и финальный resolve теперь обрабатывают массив `conditions`
- Поиск condition-блока для signal теперь включает `type == "logic"`
- Фронтенд `flatBlocksToWorkspace.ts` обрабатывает `type: "logic"` + нормализует регистр оператора

**Файлы:**
- `backend/app/strategy/block_parser.py` — 5 точек исправления
- `frontend/src/utils/flatBlocksToWorkspace.ts` — обработка `type: "logic"`, case-insensitive operator

---

### Исправление: ошибка при завершении бэктеста + 0 сделок при закрытии позиции

**Проблема 1:** после завершения бэктеста фронтенд показывал ошибку (нужно было нажать «Повторить»).
Причина: WebSocket event `backtest.completed` содержит только summary `{backtest_id, net_profit_pct, ...}`,
а фронтенд пытался использовать `data.backtest` как полный объект → `undefined` → ошибка.
Также данные event_bus обёрнуты в `data.data`, а фронтенд читал `data.progress` напрямую.

Исправлено: при `backtest.completed` вызывается `fetchBacktest(id)` — загружает полные данные через API.
Все обращения к полям event-данных обновлены для формата `data.data.xxx`.

**Проблема 2:** `self.close()` в методе `stop()` не срабатывал — Backtrader уже завершил обработку баров.
Исправлено: закрытие позиции теперь происходит в `next()` на предпоследнем баре (`len == buflen - 1`).

**Файлы:**
- `frontend/src/stores/backtestStore.ts` — fetchBacktest при completed, корректный парсинг WS events
- `backend/app/backtest/engine.py` — закрытие позиции в next() вместо stop()

---

### WebSocket fallback: polling через REST при ошибке соединения

**Было:** если WS не подключался (onerror) — показывалось «Ошибка WebSocket соединения»,
бэктест реально выполнялся, но пользователь видел только ошибку.

**Стало:** при `ws.onerror` — автоматический fallback на polling через `backtestApi.getById()`
каждые 2 сек. При `ws.onclose` во время isRunning — одноразовая проверка через 1 сек.
Пользователь не видит ошибку — результат подгружается автоматически.

**Файл:** `frontend/src/stores/backtestStore.ts`

---

### Разделение «Описание стратегии» и «Параметры стратегии»

**Было:** одно поле `text_description` хранило и свободный текст, и параметры (7-секционный шаблон).
При редактировании в AI-панели → перезаписывало свободное описание на «Содержание».

**Стало:** два независимых поля:
- **Описание стратегии** (вкладка «Содержание») → `Strategy.description` (новая колонка в БД).
  Свободный текст, вводит пользователь. Не передаётся в AI, не связан с блоками/кодом.
- **Параметры стратегии** (AI-панель на «Редакторе») → `StrategyVersion.text_description`.
  7-секционный шаблон, связан с блок-схемой и генерацией кода.

**Файлы:**
- `backend/app/strategy/models.py` — добавлено поле `Strategy.description`
- `backend/app/strategy/service.py` — `description` сохраняется в Strategy, не в version
- `backend/app/strategy/router.py` — возвращает `description` в StrategyDetailResponse
- `backend/app/strategy/schemas.py` — добавлено `description` в StrategyDetailResponse
- `frontend/src/pages/StrategyEditPage.tsx` — раздельная загрузка/сохранение
- `frontend/src/components/strategy/SharedDescriptionPanel.tsx` — переименовано в «Параметры стратегии»

---

### Прогресс бэктеста: реальное отображение процентов

**Было:** прогресс-бар всегда показывал 100%. Причина: Backtrader работал синхронно в event loop,
блокируя его. Progress callback (async) не мог выполниться до завершения бэктеста.

**Стало:**
- `cerebro.run()` выполняется в `loop.run_in_executor(None, ...)` (отдельный поток)
- Progress callback — sync-функция, вызывает `asyncio.run_coroutine_threadsafe()` для
  публикации в EventBus из потока executor
- Event loop свободен — прогресс-события доходят через WebSocket в реальном времени

**Файлы:**
- `backend/app/backtest/engine.py` — `run_in_executor`, упрощённый ProgressAnalyzer
- `backend/app/backtest/router.py` — sync callback с `run_coroutine_threadsafe`, этап «Загрузка данных»
- `frontend/src/stores/backtestStore.ts` — subscribeProgress сразу после launch (до mount компонента)
- `frontend/src/components/backtest/BacktestProgress.tsx` — этапы: «Загрузка данных» → «Выполнение: N%»,
  подсказка «можно перейти на другую страницу»

---

## 2026-04-07 — Ревью заказчика: секции 3–6, исправления графиков и метрик

---

### Маркеры сделок на графике: увеличенные стрелки + фиксированный шрифт

**Было:** маркеры (стрелки + текст с количеством лотов) мелкие, текст масштабировался при зуме.

**Стало:**
- Стрелки маркеров увеличены в 2 раза (`size: 2` в SeriesMarker)
- Текст с количеством лотов рисуется на canvas overlay (`bold 16px sans-serif`),
  не масштабируется при зуме графика
- Позиционирование текста через `priceToCoordinate()` — привязка к high/low свечи
- Canvas overlay перерисовывается через `requestAnimationFrame` loop
  (корректное отображение при первой загрузке, вертикальном drag, горизонтальном скролле)

**Файлы:**
- `frontend/src/components/backtest/InstrumentChart.tsx` — canvas overlay для текста маркеров,
  rAF-цикл вместо `subscribeVisibleTimeRangeChange`, `size: 2` для стрелок

---

### Вкладка «Обзор»: русификация названий метрик

**Было:** Win Rate, Profit Factor, Max Drawdown, Sharpe Ratio (английские названия).

**Стало:** Доля прибыльных, Фактор прибыли, Макс. просадка, Коэфф. Шарпа.

**Файлы:**
- `frontend/src/components/backtest/MetricsGrid.tsx` — `METRIC_LABELS`

---

### Метрика «Ср. P&L на сделку»: корректный расчёт

**Было:** карточка «Ср. прибыль/убыток» показывала среднюю прибыль **только по выигрышным** сделкам
(`won_info.pnl.average`). При убыточной стратегии значение было положительным — вводило в заблуждение.

**Стало:**
- Расчёт: `net_profit / total_trades` — среднее по ВСЕМ сделкам
- Название: «Ср. P&L на сделку»
- При убыточной стратегии значение отрицательное (красная карточка)

**Файлы:**
- `backend/app/backtest/metrics.py` — `avg_profit = net_profit / total_trades`
- `frontend/src/components/backtest/MetricsGrid.tsx` — переименование карточки

---

### Макс. просадка: исправлен цвет карточки

**Было:** Max Drawdown < 10% окрашивался зелёным (good). Просадка — это всегда негативный показатель,
зелёный цвет вводит в заблуждение.

**Стало:** Макс. просадка всегда нейтральная (серая) при значении ≤ 25%, красная при > 25%.

**Файлы:**
- `frontend/src/components/backtest/MetricsGrid.tsx` — `getLevel('max_drawdown_pct')`

---

### Средняя длительность: пересчёт баров в часы/дни по таймфрейму

**Было:** `avg_trade_duration_bars` показывалось напрямую как дни. Для 1h таймфрейма
15 баров = 15 часов, но отображалось «15 дн».

**Стало:**
- Backend пересчитывает бары в дни через таймфрейм:
  `бары × часов_на_бар / 24` (1m=1/60, 5m=5/60, 15m=1/4, 1h=1, 4h=4, D=24, W=168, M=720)
- Frontend: если результат < 1 дня → отображение в часах («14 ч»), иначе в днях («2,1 дн»)

**Файлы:**
- `backend/app/backtest/router.py` — `_tf_hours` словарь, пересчёт баров
- `frontend/src/components/backtest/MetricsGrid.tsx` — формат часы/дни

---

### Коэффициент Шарпа: исправлен расчёт (был всегда 0)

**Было:** Backtrader `SharpeRatio` по умолчанию группировал данные по годам (`timeframe=Years`).
За 3-месячный бэктест получалась 1 точка — невозможно вычислить стандартное отклонение → `None` → 0.

**Стало:**
- `timeframe=bt.TimeFrame.Days` — группировка по дням (~60–75 точек за 3 месяца)
- `annualize=True` — приведение к годовому значению (× √252)
- Для убыточной стратегии: Sharpe = -0.91 (ранее показывал 0)

**Файлы:**
- `backend/app/backtest/engine.py` — параметры `SharpeRatio` анализатора

---

### Вкладка «Показатели»: метрики перенесены в левую панель

**Было:** метрики (Общие ПР/УБ, Макс. просадка, Всего сделок, Прибыльные, Фактор прибыли)
располагались в правой панели шириной 150px, сужая область графика.

**Стало:**
- Метрики перенесены в левую панель под переключатели серий (разделены горизонтальной линией)
- Правая панель метрик удалена
- График equity занимает всё пространство справа от левой панели

**Файлы:**
- `frontend/src/components/backtest/StrategyTesterPanel.tsx` — перенос метрик, удаление правой панели

---

### Таблица сделок: исправлена цена выхода (была равна цене входа)

**Было:** `exit_price` совпадала с `entry_price` у всех сделок. Причина: в Backtrader
`trade.price` — это средняя цена открытия, одинаковая при open и close.

**Стало:** exit_price вычисляется из P&L:
- Long: `exit = entry + pnl / size`
- Short: `exit = entry - pnl / size`

**Файлы:**
- `backend/app/backtest/engine.py` — `TradeRecorder.notify_trade()`, расчёт exit_price

---

### Таблица сделок: добавлена колонка «Тип» (Long/Short)

**Было:** нет информации о направлении сделки в таблице (поле `direction` было в API, но не отображалось).

**Стало:** колонка «Тип» между # и «Вход», зелёный Long / красный Short. Добавлено в CSV-экспорт.

**Файлы:**
- `frontend/src/api/backtestApi.ts` — добавлено поле `direction` в `BacktestTrade`
- `frontend/src/components/backtest/BacktestTrades.tsx` — колонка + CSV

---

### Таблица сделок: длительность в часах/днях (как на вкладке «Обзор»)

**Было:** длительность всегда «1 дн» — в роутере стоял минимум 1 день (`if < 1: duration_days = 1`).

**Стало:** реальная дробная длительность. Формат как в MetricsGrid:
- < 1 дня → часы (`3 ч`, `21 ч`)
- ≥ 1 дня → дни (`2,1 дн`)

**Файлы:**
- `backend/app/backtest/router.py` — убран минимум 1 день, точность до 0.01
- `frontend/src/components/backtest/BacktestTrades.tsx` — формат часы/дни

---

### Таблица сделок: добавлена колонка «Комиссия»

**Было:** информация о комиссии не отображалась.

**Стало:** новая колонка «Комиссия» — рассчитывается как `объём × комиссия% / 100 × 2`
(вход + выход). P&L в Backtrader уже включает комиссию, колонка — для информации.

**Файлы:**
- `backend/app/backtest/router.py` — расчёт `commission` из `commission_pct` бэктеста
- `frontend/src/api/backtestApi.ts` — поле `commission` в `BacktestTrade`
- `frontend/src/components/backtest/BacktestTrades.tsx` — колонка + CSV
