# Лог выполнения — Sprint_2_Review

> Фиксирует выполнение задач из backlog.md.
> Заполняется по ходу работы.

## Выполненные задачи

| # | Задача | Дата | Результат | Тесты |
|---|--------|------|-----------|-------|
| 9 | Интеграция шифрования API-ключей брокера | 2026-03-26 | `broker/service.py`: подключён `encrypt_broker_credentials()`, убрана заглушка plain text. Теперь API-ключи шифруются AES-256-GCM с уникальным IV при создании аккаунта | 139 passed, 0 failed |
| 10 | CandleResponse: float → Decimal | 2026-03-26 | `market_data/schemas.py`: тип цен `Decimal` с `PlainSerializer(float)` для JSON-совместимости. Внутри Python — Decimal (точность), в JSON — число (не строка). Обновлён тест | 139 passed, 0 failed |
| 3 | changelog.md в шаблоны спринтов | 2026-03-26 | Создан `Sprint_3/changelog.md`. Sprint_1 и Sprint_2 уже содержали changelog | — |
| 8 | Фильтрация поиска инструментов | 2026-03-26 | `market_data/router.py`: добавлен `ALLOWED_TYPES` — показываются только акции, облигации, ETF. Валюты, индексы, фьючерсы отфильтрованы | 139 passed |
| 11 | Generic Exception handler | 2026-03-26 | `common/exceptions.py`: добавлен handler для `Exception` — логирует ошибку structlog, возвращает 500 без stack trace. Добавлен `AccountLockedError` (423) | 139 passed |
| 12 | CORS/API URL → .env | 2026-03-26 | Backend: `CORS_ORIGINS` в config.py + main.py парсит через split. Frontend: `VITE_API_BASE_URL` через `import.meta.env`. Обновлён `.env.example` | 139 passed |
| 13 | auth/router.py → кастомные исключения | 2026-03-26 | Убран `HTTPException`, все ошибки через `ForbiddenError`, `AuthenticationError`, `ValidationError`, `AccountLockedError`. Обновлён тест (400→422) | 139 passed |
| 14 | Timezone consistency | 2026-03-26 | `service.py`: UTC-конвертация вместо strip. `parser.py`: MSK timezone при парсинге ISS. `mapper.py`: гарантированный UTC для T-Invest | 139 passed |
| 15 | Frontend cleanup | 2026-03-26 | ChartPage: убран eslint-disable, добавлены зависимости. Header: добавлен useEffect cleanup для debounce. BrokerSettingsPage/StatusFooter: API-вызовы перенесены в settingsStore | — |
| 17 | Зависимости | 2026-03-26 | Убран дубль `httpx>=0.27` из `[dev]` секции pyproject.toml | — |
| 18 | Coverage в CI | 2026-03-26 | Backend: `--cov=app --cov-fail-under=60`. Frontend: `--coverage` | — |
| 2 | Начальный период по таймфрейму | 2026-03-26 | `marketDataStore.ts`: `INITIAL_PERIOD_DAYS` — 1m→1d, 5m→3d, 15m→7d, 1h→30d, 4h→90d, D→365d, W→730d, M→1825d | — |
| 6 | Volume panel: динамическая высота | 2026-03-26 | `CandlestickChart.tsx`: `computeVolumePercent()` — линейная интерполяция от высоты контейнера (400px→30%, 900px→12%). Пересчёт в ResizeObserver. Убран проп `volumeHeightPercent` | — |
| 7 | Иконки тикеров в поиске | 2026-03-26 | `Header.tsx`: цветной круг с первой буквой тикера перед каждым результатом. Цвет привязан к типу инструмента (акции — синий, облигации — оранжевый, ETF — grape) | — |
| 16 | Рефакторинг market_data/service.py | 2026-03-26 | Выделены `_raw_to_candle()` (ISS→CandleData) и `_is_valid_candle()` (проверка одной свечи). Методы `_fetch_via_iss` и `_validate_candles` теперь компактны | 139 passed |
| 4 | Sandbox T-Invest: автодетекция + per-account | 2026-03-26 | **Документация**: 3 файла в `Документация по проекту/` (overview, services, sandbox). **Код**: `is_sandbox` в BrokerAccount; автодетекция токена; sandbox только при DEBUG=true; market_data исключает sandbox-аккаунты. **ТЗ обновлено**: алгоритм выбора источника данных (production→ISS, sandbox не участвует), sandbox per-account. | 139 passed |

## Исправления при тестировании (2026-03-26)

| # | Проблема | Причина | Исправление |
|---|----------|---------|-------------|
| F1 | `.env` не читался бэкендом | `config.py` искал `.env` в `backend/`, а файл лежит в корне `moex-terminal/` | `config.py`: путь к `.env` через `Path(__file__).parents[2]` |
| F2 | tinkoff SDK не импортировался | Установлен с `--no-deps`, не хватало `deprecation` и `python-dateutil` | Доустановлены `deprecation`, `python-dateutil` |
| F3 | Чекбокс Sandbox в форме брокера | Не был убран при реализации автодетекции | `AddBrokerForm.tsx`: удалён чекбокс, `is_sandbox` убран из формы |
| F4 | Ошибки при добавлении брокера молча игнорировались | Фронтенд показывал notification (легко пропустить), не показывал ошибку в форме | `AddBrokerForm.tsx`: ошибка сервера отображается как Alert прямо в форме |
| F5 | Кнопка «Отмена» не закрывала модальное окно | `resetForm()` сбрасывал поля, но не закрывал модал | Добавлен `onCancel` prop, BrokerSettingsPage передаёт `setAddModalOpened(false)` |
| F6 | «Создать аккаунт» на LoginPage не работала | SetupPage проверяет `is_configured` и редиректит обратно на Login | Ссылка «Создать аккаунт» скрывается если пользователь уже создан |
| F7 | Старый дубль `.env.example` в `Develop/` | Осталась старая копия вне git-репозитория | Удалён `Develop/.env.example`, актуальный — `moex-terminal/.env.example` |
| F8 | `.env.example` содержал `DEBUG=true` | Небезопасный default для production | Изменён на `DEBUG=false` |
| F9 | Alembic миграция для `is_sandbox` | Новое поле в модели не было в БД | Создана миграция `fcf92e7ec48c_add_is_sandbox_to_broker_accounts` |
| F10 | Многопользовательский режим | `/auth/setup` блокировал создание второго пользователя (403) | Убрана проверка `count > 0` в `auth/router.py`. SetupPage доступна всегда. LoginPage всегда показывает ссылку «Создать аккаунт» |
| F11 | Sandbox `get_accounts()` вызывал production API | `TInvestAdapter.get_accounts()` всегда использовал `client.users.get_accounts()` | Добавлена ветвь `if self._sandbox: client.sandbox.get_sandbox_accounts()`. Аналогично для `get_balance()` → `get_sandbox_portfolio()` |
| F12 | Sandbox без счетов — пустой ответ | T-Invest sandbox требует явного создания счёта через `OpenSandboxAccount` | Автоматическое создание sandbox-счёта если `get_sandbox_accounts()` вернул пустой список |
| F13 | Техническая ошибка gRPC в UI при невалидном токене | `detect_token_mode` пробрасывал сырое исключение gRPC | Понятное сообщение: «API-ключ отклонён T-Invest. Проверьте срок действия...» |
| F14 | Ошибки формы брокера не отображались в форме | Фронтенд показывал notification (легко пропустить) | `AddBrokerForm.tsx`: ошибки сервера показываются как Alert внутри формы |
| F15 | Кнопка «Отмена» не закрывала модал | `resetForm()` сбрасывала поля, не закрывала окно | Добавлен `onCancel` prop, передаётся `setAddModalOpened(false)` |
| F16 | `settings.local.json` — дополнение разрешений | Разрешения запрашивались повторно в каждой сессии | Добавлены: `rm`, `mv`, `mkdir`, `ls`, `which`, `ps`, `find`, `chmod`, `bash`, `.venv/bin/*`, `WebFetch(*)` |
| F17 | Sandbox-аккаунт не отличается от production в таблице | Нет визуального отличия sandbox от production аккаунтов | `BrokerAccountList.tsx`: добавлена колонка «Режим» с бейджами Sandbox (жёлтый) / Production (синий) |

## Задача #5: Оформление графика (2026-03-26)

| # | Изменение | Файл | Описание |
|---|-----------|------|----------|
| G1 | Инфо + OHLCV overlay на графике | `CandlestickChart.tsx` | Тикер, название, ОТКР/МАКС/МИН/ЗАКР + изменение + Объём — одна строка поверх графика. Цвет по направлению свечи. «V:» → «Объём», объём также раскрашен. При выходе курсора за график — все поля показывают N/A |
| G2 | Убран инфо-блок и OHLCV из ChartPage | `ChartPage.tsx` | Убраны отдельные блоки над графиком. Данные передаются через `overlayInfo` prop. График занимает больше места |
| G3 | Таймфрейм — серо-белый стиль | `TimeframeSelector.tsx` | Кнопки `color="gray"`, активный с `bg="#373A40"`. Убран синий цвет. Текущий таймфрейм в dropdown-кнопке. В списке текущий подсвечен |
| G4 | Drag графика не работал | `CandlestickChart.tsx` | Полный рефакторинг: chart создаётся один раз (useEffect с `[showVolume]`), данные обновляются отдельным useEffect (`[candles]`). Crosshair callback через ref вместо useCallback. `fitContent()` + `setVisibleRange()` снимает auto-fit lock. Контейнер `width/height: 100%` вместо `position: absolute` |
| G5 | Авторизация теряется при обновлении страницы (F5) | `authStore.ts` | Добавлен Zustand `persist` middleware — token и user сохраняются в `localStorage` (ключ `auth-storage`). При logout — очищается |
