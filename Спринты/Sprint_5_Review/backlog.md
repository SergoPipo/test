# Sprint_5_Review — Backlog

> 9 задач: 6 изначальных + 3 closeout после ARCH-ревью.
> Статус ревью: **завершено 2026-04-14, PASS WITH NOTES** (кроме closeout-фазы).
> Детальные планы задач 1-4 — в отдельных `PENDING_S5R_*.md` файлах в этой папке.

## Сводная таблица

| # | Задача | Тип | Приоритет | Блокирует | Статус | Документ |
|---|--------|-----|-----------|-----------|--------|----------|
| 1 | CI cleanup (backend ruff + frontend eslint) | Fix | 🔴 Блокер | 2, 3, 4 | ✅ Готово (DEV-1 волна 1+1b) | `PENDING_S5R_ci_cleanup.md` |
| 2 | Live Runtime Loop (SessionRuntime + timeframe в сессии) | Feature + Arch | 🔴 Блокер | S6 целиком | ✅ Готово (DEV-2) | `PENDING_S5R_live_runtime_loop.md` |
| 3 | Реальные позиции и операции T-Invest | Feature | 🟡 Важно | — | ✅ Готово с замечанием (DEV-3, source-правило отличается) | `PENDING_S5R_real_account_positions_operations.md` |
| 4 | E2E S4 fix (30+ падающих тестов) | Fix | 🔴 Блокер | 2 (интеграционная валидация) | ✅ Готово (DEV-1 волна 2, 101 passed / 8 skipped) | `PENDING_S5R_e2e_s4_fix.md` |
| 5 | Обкатка нового процесса работы DEV-субагентов | Process | 🔴 Критично | S6 | ✅ Проведена, findings в `arch_review_s5r.md` секция 4 | этот файл + arch_review_s5r.md |
| 6 | Актуализация ФТ/ТЗ за S5 + S5R | Docs | 🟡 Обязательно | — | ✅ Готово (ФТ/ТЗ/план + новый `ui_checklist_s5r.md`) | `arch_review_s5r.md` секция 6 |
| 7 | **FAVORITES input — поиск внутри списка избранного** | Fix | 🟢 Closeout | 4 E2E skip | ✅ Готово (DEV-1 closeout wave 1) | секция Closeout ниже |
| 8 | **E2E PAPER-REAL-MODE fixture** | Fix | 🟢 Closeout | 1 E2E skip | ✅ Готово (DEV-1 closeout wave 1) | секция Closeout ниже |
| 9 | **MODEL-FIGI: FIGI в LiveTrade + source-правило через FIGI** | Feature | 🟢 Closeout | Замечание C8 | ✅ Готово (DEV-1 closeout wave 1) | секция Closeout ниже |
| 10 | **E2E: 2 pre-existing failing через моки API** | Fix | 🟢 Closeout wave 2 | Неожиданность из wave 1 | ✅ Готово (DEV-1 closeout wave 2) | секция Closeout ниже |
| 11 | **Alembic drift санитайзер-миграция** | Fix (БД) | 🟢 Closeout wave 2 | Неожиданность из wave 1 | ✅ Готово (DEV-1 closeout wave 2) | секция Closeout ниже |
| 12 | **BacktestResultsPage: `Запустить торговлю` без обработчика** | Fix (Frontend) | 🟢 Closeout wave 3 | Обнаружен при ручном тесте 2026-04-15 | ✅ Готово (DEV-1 closeout wave 3) | секция Closeout wave 3 ниже |
| 13 | **Bug: tinvest_stream `.candles` AttributeError (бесконечный reconnect)** | Bug (Backend) | 🟢 Closeout wave 3 | Обнаружен в логах 2026-04-15 | ✅ Готово (DEV-1 closeout wave 3 + CI stub fix) | секция Closeout wave 3 ниже |
| 14 | **Bug: iss_tail_fetch `offset-naive vs offset-aware datetimes`** | Bug (Backend) | 🟢 Closeout wave 3 | Обнаружен в логах 2026-04-15 | ✅ Готово (DEV-1 closeout wave 3) | секция Closeout wave 3 ниже |

**Условные обозначения:**
- ⬜ TODO / 🔄 в работе / ✅ готово / ⚠️ готово с замечаниями
- 🔴 Блокер = без этого Sprint 6 не может корректно начаться
- 🟡 Важно = без этого S6 стартует, но с ограничениями или техдолгом
- 🔧 Process = не код, а процессное правило

---

## Задача 1 — CI cleanup

**Тип:** Fix
**Приоритет:** 🔴 Блокер
**Исполнитель:** DEV-агент (будет определён при создании `prompt_DEV-1.md`)

### Корень проблемы

CI (`.github/workflows/ci.yml`) падает **с 2026-04-03** (коммит `a73d902` Sprint 4) на обоих jobs:

- **Backend `Lint (ruff)`** → все ошибки `F401 imported but unused` в `alembic/env.py`. Это ложные срабатывания: импорты моделей нужны для side-effect регистрации в `Base.metadata` (для `alembic revision --autogenerate`), но ruff этого не понимает.
- **Frontend `Lint (eslint)`** → десятки ошибок:
  - Новые правила `eslint-plugin-react-hooks@7.x` для React 19: `react-hooks/refs`, `react-hooks/set-state-in-effect`, `react-hooks/incompatible-library` (TanStack Table vs React Compiler)
  - Старый долг: `@typescript-eslint/no-unused-vars` и `@typescript-eslint/no-explicit-any` в e2e-файлах и компонентах

Из-за `bash -e` в actions ни `mypy`, ни `pytest`, ни `tsc --noEmit`, ни `vitest` **до сих пор ни разу не запускались в CI** после 3 апреля. Мы не знаем, проходят ли они.

### Почему блокер для остальных задач S5R

- Без зелёного CI Integration Verification Checklist из `prompt_template.md` превращается в декларацию: «проверка, что класс вызывается в runtime» невозможна, если CI не гоняет тесты.
- Любой pull request с фиксами Live Runtime Loop / реальных позиций / E2E будет показывать «All jobs failed» — отличить новые проблемы от старых невозможно.
- Письма от GitHub со spam'ом failure-уведомлений продолжают копиться — пользователь не видит реальных новых падений в шуме.

### Ориентировочный объём работ

- `backend/pyproject.toml` — добавить `[tool.ruff.lint.per-file-ignores]` для `alembic/env.py` (одна строка)
- `frontend/eslint.config.js` — понизить `react-hooks/set-state-in-effect`, `react-hooks/refs`, `react-hooks/incompatible-library` до `warn` **или** исправить конкретные 6 мест (`InstrumentChart.tsx` refs, `TickerLogo.tsx` setState-in-effect, `BacktestLaunchModal.tsx` setState-in-effect, `PositionsTable.tsx` + `BacktestTrades.tsx` tanstack eslint-disable, `Sidebar.tsx` разделить экспорты)
- `frontend/src/**` + `frontend/e2e/**` — массовый фикс `no-unused-vars` / `no-explicit-any` (часть через `eslint --fix`, часть вручную в e2e)
- После локального фикса — проверить, что backend `mypy` + `pytest` + frontend `tsc --noEmit` + `vitest` **действительно** проходят. Если нет — это новые проблемы, которые мы раньше не видели, их тоже чинить в рамках этой задачи

### Критерии готовности

- [ ] `cd backend && ruff check .` → exit 0
- [ ] `cd backend && mypy app/` → exit 0 (или warn-only)
- [ ] `cd backend && pytest tests/unit/` → 0 failures
- [ ] `cd frontend && pnpm lint` → exit 0 (или только warnings)
- [ ] `cd frontend && pnpm tsc --noEmit` → 0 errors
- [ ] `cd frontend && pnpm test` → 0 failures
- [ ] Push в тестовую ветку → CI зелёный
- [ ] Письма `Run failed: CI` прекратились

---

## Задача 2 — Live Runtime Loop

**Тип:** Feature + Architecture
**Приоритет:** 🔴 Блокер
**Исполнитель:** DEV-агент (senior)

Полный план: **`PENDING_S5R_live_runtime_loop.md`** (перемещён из `Sprint_6/`, переименован, ссылки обновлены).

### Резюме

`SignalProcessor.process_candle()` реализован в S5 и принят ARCH-ревью, но в production-коде нигде не вызывается. Цикл «стрим свечей → стратегия → сигнал → ордер» физически не замкнут. Задача замыкает цикл и добавляет `TradingSession.timeframe`.

### Зависимости

- Задача 1 (CI cleanup) — обязательно до, чтобы тесты runtime-loop валидировались автоматически
- Параллельно с задачей 3 (реальные позиции) — независимы
- Блокирует все задачи S6 (6.3 in-app, 6.4 recovery, 6.5 graceful shutdown, 6.8 Trading Panel, 6.10 E2E)

### Критерии готовности

(Детально — в `PENDING_S5R_live_runtime_loop.md`. Краткий список:)

- [ ] Поле `TradingSession.timeframe` + миграция Alembic
- [ ] Форма запуска сессии требует выбор таймфрейма
- [ ] Вывод таймфрейма на карточке сессии в списке
- [ ] Новый модуль `app/trading/runtime.py` — `SessionRuntime` с listener на `market:{ticker}:{tf}`
- [ ] `SignalProcessor.process_candle()` вызывается из `SessionRuntime` с историей свечей (не одной)
- [ ] `OrderManager.process_signal()` вызывается из `SessionRuntime` после CB-проверки
- [ ] Восстановление `SessionRuntime` при рестарте backend (интеграция с 6.4 Recovery)
- [ ] Integration verification: `grep -rn "process_candle(" app/` → не только тесты, есть production
- [ ] E2E тест: fake market publisher → session → LiveTrade в БД
- [ ] Latency < 500ms от свечи до `place_order()` залогировано
- [ ] ТЗ раздел 5.4.2 — фактически описывает реализацию

---

## Задача 3 — Реальные позиции и операции T-Invest

**Тип:** Feature
**Приоритет:** 🟡 Важно
**Исполнитель:** DEV-агент

Полный план: **`PENDING_S5R_real_account_positions_operations.md`** (перемещён из `Sprint_6/`, переименован, ссылки обновлены).

### Резюме

В S5 раздел «Счёт» был перестроен под реальные брокерские счета T-Invest: балансы реализованы через `OperationsService.GetPortfolio`. Но позиции и операции остались **заглушками** в `broker/router.py:113-134`:

```python
return []                         # GET /broker/accounts/{id}/positions
return {"items": [], "total": 0}  # GET /broker/accounts/{id}/operations
```

Задача — реализовать реальные позиции и операции через уже существующие методы `client.operations.get_portfolio` и `client.operations.get_operations`.

### Зависимости

- Задача 1 (CI) — для возможности валидировать через тесты
- Независима от задач 2 и 4 — можно параллелить

### Критерии готовности

(Детально — в `PENDING_S5R_real_account_positions_operations.md`. Краткий список:)

- [ ] `GET /broker/accounts/{id}/positions` возвращает реальные позиции T-Invest с полями `{ticker, quantity, avg_price, current_price, unrealized_pnl, source}`
- [ ] `GET /broker/accounts/{id}/operations` возвращает реальные операции с фильтром `from`/`to` и пагинацией
- [ ] Различение `source: 'strategy' | 'external'` по наличию связанных `Order` в нашей БД
- [ ] Поддержка multi-currency (позиции в USD/EUR/HKD/CNY)
- [ ] Frontend `PositionsTable.tsx` и `OperationsTable.tsx` корректно рендерят реальные данные
- [ ] E2E: при подключённом production ключе T-Invest видны реальные позиции и история
- [ ] Unit + integration тесты на маппер и роуты

---

## Задача 4 — E2E S4 fix (30+ падающих тестов)

**Тип:** Fix
**Приоритет:** 🔴 Блокер
**Исполнитель:** DEV-агент

Полный план: **`PENDING_S5R_e2e_s4_fix.md`** (новый файл в этой папке).

### Резюме

Техдолг #2 Medium из S5: в Sprint 4 написаны E2E тесты для AI Chat, Backtest-workflow и Blockly-редактора (~30+ тестов, файлы `s4-review-*.spec.ts`), но они **падают** со Sprint 4. В S5 эти тесты не чинились, долг перенесён. На ARCH-ревью S5 зафиксировано, но не исправлено.

Причин падений несколько:
- Изменения селекторов после обновления Mantine / Blockly / Lightweight Charts
- Изменения роутов / URL-структуры (введение `?tab=description`, `/rerun` endpoints и т.п.)
- Изменения состояний stores (новые методы `rerunBacktest`, `recentInstruments` и т.п.)
- Возможные flaky-тесты от async-операций без явных `waitFor`

### Почему блокер

Интеграционная валидация задачи 2 (Live Runtime Loop) требует E2E-теста «fake-стрим → сессия → ордер». Если существующие E2E S4 сломаны и не чинятся, новый E2E для S5R тоже повиснет в общем хаосе. Надо сначала вернуть baseline «Playwright test запускается, зелёные тесты зелёные».

### Критерии готовности

- [ ] `cd frontend && npx playwright test` → 0 failures или явный список `test.skip()` с аннотацией и тикетом
- [ ] `s4-review-ai-chat.spec.ts` проходит или обоснованно скипается
- [ ] `s4-review-blockly-backtest.spec.ts` проходит или обоснованно скипается
- [ ] `s4-review-full.spec.ts` проходит
- [ ] `s4-review.spec.ts` проходит
- [ ] `test-backtest-fixes.ts` и `test-backtest-flow.ts` — если не тесты, переименовать или удалить (сейчас ESLint ругается)
- [ ] CI `pnpm test` (vitest) и `playwright test` запускаются и зелёные

---

## Задача 5 — Обкатка нового процесса работы DEV-субагентов

**Тип:** Process (не код!)
**Приоритет:** 🔴 Критично
**Исполнитель:** Оркестратор + все DEV-агенты задач 1-4 + ARCH

### Что это значит

Это **не отдельная задача**, а **правило выполнения задач 1-4**. Каждая задача 1-4 в S5R:

1. **Prompt создаётся по `Спринты/prompt_template.md`** — все 11 обязательных секций заполнены, цитаты из ТЗ/ФТ вставлены дословно, явная ссылка на `Develop/CLAUDE.md` раздел «Stack Gotchas»
2. **Cross-DEV contracts в `execution_order.md`** заполняются до запуска субагента — каждый контракт явно указывает поставщика, потребителя, endpoint/класс, формат
3. **DEV-агент прочитывает `Develop/CLAUDE.md`** целиком, особенно Stack Gotchas (автоматически подгружается в контекст)
4. **Integration Verification Checklist** выполняется DEV-агентом перед сдачей (`grep -rn "<ClassName>(" app/`, проверка подключения к runtime)
5. **Отчёт субагента по формату** до 400 слов с 8 обязательными секциями — включая «Integration points» (NOT CONNECTED если gap), «Контракты» и «Применённые Stack Gotchas»
6. **ARCH-ревью** после каждой задачи проверяет: integration verification пройден? контракты подтверждены? какие Stack Gotchas применялись?

### Почему критично

Это **первое практическое применение** всех правил, принятых 2026-04-14 в retro-s5. До этого правила существовали только как документация. Если обкатка покажет, что шаблон/чеклисты/формат работают — S6 стартует с ними уверенно. Если что-то не работает — дорабатываем до S6.

### Критерии готовности

- [ ] Все 4 DEV-задачи S5R выполнены с `prompt_template.md` как основой
- [ ] Все 4 отчёта субагентов соответствуют формату (до 400 слов, 8 секций, без полного кода)
- [ ] Integration Verification пройден для каждого нового класса / метода
- [ ] Cross-DEV contracts в `execution_order.md` подтверждены всеми DEV
- [ ] В `arch_review_s5r.md` есть раздел «Оценка эффективности нового процесса» с findings и рекомендациями

### Выходы для S6

- Обновлённый `Спринты/prompt_template.md` если шаблон нужно доработать
- Обновлённый `Develop/CLAUDE.md` секция Stack Gotchas с новыми ловушками, найденными при выполнении задач 1-4
- Обновлённый корневой `CLAUDE.md` если правила работы с DEV-агентами нужно скорректировать

---

## Задача 6 — Актуализация ФТ/ТЗ за S5 + S5R

**Тип:** Documentation
**Приоритет:** 🟡 Обязательно (правило проекта: на каждом ревью обновлять)
**Исполнитель:** ARCH (выполняется в рамках финального ревью S5R)

### Что обновить

**`Документация по проекту/functional_requirements.md`:**
- Раздел 6 (Торговля) — отразить реальную модель: выбор таймфрейма при запуске сессии, что стратегия работает по закрытию бара таймфрейма
- Раздел 7.3 (Экран «Счёт») — документировать реальные позиции и операции T-Invest, multi-currency
- Раздел 12.4 (Circuit Breaker) — уточнить, что daily_loss считается на закрытии свечи TF, не на каждом тике
- Новые фичи S5: bond НКД, налоговый экспорт FIFO, Избранные инструменты, TickerLogo — все должны быть в ФТ

**`Документация по проекту/technical_specification.md`:**
- Раздел 5.4 (Trading Engine) — описать `SessionRuntime`, listener-модель, скользящее окно истории свечей, обработку обрывов стрима
- Раздел 5.6.5 (BondService) — подтвердить реализацию S5
- Раздел 5.13 (Tax Report) — подтвердить реализацию S5
- Раздел 6.6 (Trading Panel) — обновить UI-описание под реальные компоненты
- Раздел 6.7 (Account Screen) — добавить multi-currency, source badge
- Новые технические решения из S5: `TickerLogo` с CDN, `StreamManager` с reconnect, `recentInstruments` утилита, `toNum` helper — все в соответствующих разделах

**`Документация по проекту/development_plan.md`:**
- Отразить факт проведения `Sprint_5_Review` между S5 и S6
- Убрать задачи 6.0 и 6.9 из раздела S6 (они перенесены в S5R)
- Обновить зависимости S6 → S5R

### Критерии готовности

- [ ] `functional_requirements.md` — актуален на 2026-04-N (дата завершения S5R)
- [ ] `technical_specification.md` — актуален, все реализованные компоненты S5+S5R описаны
- [ ] `development_plan.md` — актуален, S5R отражён, S6 откорректирован
- [ ] `ui_checklist_s4_review.md` — дополнен проверками S5R, если появились новые UI-элементы

---

## Преmемкты / сборка задач в prompt_DEV

На этапе B (в отдельной сессии планирования) задачи будут сгруппированы в prompt-файлы по DEV-агентам:

- **`prompt_DEV-1.md`** — Задача 1 (CI cleanup) + Задача 4 (E2E S4 fix) — родственные, обе про инфраструктуру тестов
- **`prompt_DEV-2.md`** — Задача 2 (Live Runtime Loop) — одна самая большая архитектурная задача
- **`prompt_DEV-3.md`** — Задача 3 (Реальные позиции T-Invest) — независимая backend+frontend

Задачи 5 (обкатка процесса) и 6 (актуализация ФТ/ТЗ) не имеют отдельного `prompt_DEV-*.md`:
- Задача 5 — процессное правило, применяется в DEV-1/2/3
- Задача 6 — выполняется ARCH в финальном ревью

Это предварительное деление, может измениться на этапе B при детальном планировании.

---

## Closeout-задачи (добавлены 2026-04-14 после ARCH-ревью)

> Три задачи, которые ARCH изначально рекомендовал перенести в Sprint 6 backlog, но заказчик решил закрыть их в рамках S5R, чтобы Sprint 6 стартовал максимально чистым.
>
> Исполнитель: один DEV-агент (DEV-1 closeout), одна ветка `s5r/closeout`, три подзадачи **последовательно**.
> Запуск: 2026-04-14, после финального ARCH-ревью.

### Задача 7 — FAVORITES input: поиск внутри списка избранного

**Тип:** Fix (UX + E2E)
**Приоритет:** 🟢 Closeout
**Исполнитель:** DEV-1 closeout

#### Продуктовое решение (заказчик 2026-04-14)

> «Поиск надо оставить только для поиска в избранном. То есть надо вернуть поле для поиска в рамках списка избранного, но не для добавления нового элемента в избранное. Соответственно надо переписать UX тесты в соответствии с этим.»

Добавление новых элементов в избранное остаётся через кнопку `+` в шапке графика (текущее поведение), **НЕ** через текстовое поле ввода. Текстовое поле — **только для фильтрации уже существующих элементов списка** (filter-as-you-type).

#### Что делать

**Frontend:**
- `src/components/charts/FavoritesPanel.tsx` — вернуть `<TextInput placeholder="Поиск по избранному" />` **над** списком избранных тикеров. При вводе — фильтровать `filteredFavorites = favorites.filter(f => f.ticker.includes(query))`.
- **Не** вводить логику `addFavoriteByQuery` / `onSubmit` / обработчик `Enter` — поле **только** для фильтрации.
- Сохранить кнопку `+ Добавить из графика` (текущее поведение добавления через `currentTicker`).
- `data-testid="favorites-filter-input"` на поле поиска (чтобы e2e мог его найти).

**E2E:**
- Переписать 4 теста в `frontend/e2e/s5-favorites.spec.ts` (те что сейчас `test.skip("S5R-FAVORITES-INPUT")`):
  1. Ввод в filter-input фильтрует список (видно отфильтрованное, скрыто остальное)
  2. Очистка filter-input возвращает полный список
  3. Filter-input **не добавляет** новый тикер при нажатии Enter (проверка что behaviour НЕ такой как раньше)
  4. Добавление нового тикера идёт через кнопку `+` в шапке графика (текущий flow через `currentTicker`)
- Снять `test.skip` со всех 4 тестов.

#### Критерии готовности

- [ ] `FavoritesPanel.tsx` содержит `TextInput` с фильтрацией (без логики добавления)
- [ ] 4 e2e теста `s5-favorites.spec.ts` переписаны и зелёные
- [ ] `grep -rn "S5R-FAVORITES-INPUT" frontend/e2e/` → пусто (skip-ов не осталось)
- [ ] `pnpm test` + `pnpm lint` + `pnpm tsc --noEmit` + `npx playwright test` → все зелёные
- [ ] Ручная проверка UX в браузере: печать в filter-input даёт live-фильтр, кнопка `+` добавляет из currentTicker

### Задача 8 — E2E PAPER-REAL-MODE fixture

**Тип:** Fix (E2E fixture)
**Приоритет:** 🟢 Closeout
**Исполнитель:** DEV-1 closeout

#### Суть

Тест `s5-paper-trading.spec.ts` «confirm dialog for Real mode» был пропущен (`test.skip("S5R-PAPER-REAL-MODE")`) потому что кнопка переключения в Real mode в `LaunchSessionModal` рендерится conditionally — только если у пользователя есть active non-sandbox broker account. Тест не мокал такой аккаунт, кнопка не появлялась.

#### Что делать

- В `frontend/e2e/fixtures/` (или где хранятся моки `brokerApi.getAccounts`) добавить фикстуру `hasRealAccount: true` с non-sandbox `BrokerAccount`.
- В `s5-paper-trading.spec.ts` `beforeEach` теста использовать эту фикстуру: `await page.route('**/broker/accounts*', ...)` с response `[{is_sandbox: false, ...}, ...]`.
- Снять `test.skip("S5R-PAPER-REAL-MODE")`.
- Проверить, что confirm-dialog появляется и кликается; after-confirm проверка перехода в Real mode.

#### Критерии готовности

- [ ] Фикстура с non-sandbox аккаунтом добавлена в `e2e/fixtures/` или inline в тесте
- [ ] Тест «confirm dialog for Real mode» зелёный (проходит Polk-тест с диалогом)
- [ ] `grep -rn "S5R-PAPER-REAL-MODE" frontend/e2e/` → пусто
- [ ] `npx playwright test` → 0 failures

### Задача 9 — MODEL-FIGI: FIGI в LiveTrade + source-правило через FIGI

**Тип:** Feature (backend + миграция)
**Приоритет:** 🟢 Closeout
**Исполнитель:** DEV-1 closeout

#### Контекст

DEV-3 в S5R.3 реализовал определение `source: strategy | external` через match `ticker + TradingSession.broker_account_id` (через `LiveTrade.session_id → TradingSession.ticker`) — потому что в модели нет поля FIGI. Это семантически эквивалентно в 95% случаев, но есть коллизия: при одновременной ручной покупке того же тикера на том же счёте, где работает стратегия, ручная позиция ошибочно помечается как `strategy`.

Контракт C8 в `execution_order.md` описывал правило через FIGI (это более строгая семантика).

#### Что делать

**Backend:**
- `backend/app/trading/models.py` — добавить поле `LiveTrade.figi: Mapped[str | None] = mapped_column(String(12), nullable=True)` (nullable, т.к. старые записи не имеют).
- Миграция Alembic `add_figi_to_live_trades.py` — `ADD COLUMN figi VARCHAR(12)`, nullable без default. Round-trip `upgrade → downgrade → upgrade` должен быть чистым.
- `backend/app/trading/engine.py` — `OrderManager.process_signal` / создание `LiveTrade` — заполнять `figi` из `place_order` response или `BrokerAdapter.get_instrument_by_ticker`.
- `backend/app/broker/service.py::get_positions` — переписать определение `source`: собирать `figi_strategy_set = {lt.figi for lt in LiveTrade where session.user_id == user.id and lt.figi is not None}`, затем `position.source = "strategy" if position.figi in figi_strategy_set else "external"`. Для обратной совместимости при `figi is None` в старых `LiveTrade` — fallback на текущий ticker-based match.
- Unit-тесты: `tests/unit/test_broker/test_broker_service.py::test_get_positions_source_by_figi` — два сценария (совпадает FIGI → strategy, не совпадает → external).

**Не менять** frontend — response формат тот же (`source: str`), только правило определения изменилось.

#### Критерии готовности

- [ ] `LiveTrade.figi` — новое поле в модели + миграция
- [ ] Миграция round-trip чистая (`upgrade → downgrade → upgrade`)
- [ ] `OrderManager.process_signal` заполняет `LiveTrade.figi` при создании trade'а
- [ ] `broker.service.get_positions` определяет `source` через `figi`, с fallback на `ticker` для `figi IS NULL`
- [ ] Новые unit-тесты покрывают оба case'а
- [ ] `ruff` / `mypy` / `pytest` — все зелёные
- [ ] **Integration verification grep'ы** (обязательно в отчёте):
  ```bash
  grep -n "figi" backend/app/trading/models.py          # new Mapped
  grep -rn "lt\.figi\|live_trade\.figi" backend/app/    # заполнение + чтение
  grep -rn "figi_strategy_set\|figi in " backend/app/broker/  # новое правило
  ```

### Ветка и порядок работы — wave 1 (задачи 7-9)

**Ветка:** `s5r/closeout` от `develop` (актуальное состояние после 4 мержей S5R).

**Порядок выполнения DEV-1 closeout wave 1:**
1. Задача 8 (PAPER-REAL-MODE fixture) — самая маленькая, разогрев. Коммит отдельный.
2. Задача 7 (FAVORITES filter-input) — frontend + 4 e2e теста. Коммит отдельный.
3. Задача 9 (MODEL-FIGI) — backend + миграция + unit-тесты. Коммит отдельный.

**Статус wave 1 (2026-04-14):** ✅ завершён. CI run `24423480163` зелёный, 3 коммита `be7b5ea / 0ff166d / 4521b12` запушены. Но при локальном прогоне обнаружены две неожиданности — см. wave 2 ниже.

---

### Closeout wave 2 — неожиданности из wave 1 (задачи 10-11)

DEV-1 closeout wave 1 при финальном `npx playwright test` локально увидел:
- **100 passed / 8 skipped / 2 failed** — где 2 failed это `s5-account.spec.ts::"balance cards"` и `s5-ticker-logos.spec.ts::"Тестовая"`.
- DEV проверил через `git stash`: эти тесты падают и на голом `develop` коммите `a9b69ea` (до его правок) — **это pre-existing environmental**, не регрессия.
- Причина: оба теста зависят от seed-данных в БД — реальный T-Invest broker account для user `sergopipo` и стратегия с именем «Тестовая». На локальном окружении wave 1 таких данных не было.

Плюс при `alembic revision --autogenerate` DEV-1 обнаружил **кумулятивный drift схемы БД**: NOT NULL изменения на `ai_provider_configs.id`, `user_ai_settings.id`, `broker_accounts.has_trading_rights`, `trading_sessions.strategy_name` и индекс `idx_ai_user`. Это накопленные ручные правки, не отражённые в истории миграций. DEV-1 wave 1 **вычистил** drift из миграции figi вручную (правильно — не вышел за scope задачи), но сам drift существует и требует санитайзер-миграции.

Заказчик 2026-04-15 решил **закрыть обе проблемы сейчас**, а не переносить в S6.

### Задача 10 — E2E: 2 pre-existing failing через моки API

**Тип:** Fix (E2E фикстуры)
**Приоритет:** 🟢 Closeout wave 2
**Исполнитель:** DEV-1 closeout wave 2

#### Что чинить

**Test A:** `frontend/e2e/s5-account.spec.ts::"balance cards"` — при заходе на страницу «Счёт» ожидается отрисовка balance cards с суммами. Тест падает потому что нет замоканного broker account.

**Test B:** `frontend/e2e/s5-ticker-logos.spec.ts::"Тестовая"` — тест ожидает раскрытие раздела стратегии с именем «Тестовая» и проверяет ticker logos в её раскрытом списке. Тест падает потому что такой стратегии нет в БД тестового пользователя.

#### Подход

Использовать `page.route('**/api/v1/...', ...)` моки, как уже сделано в задаче 8 (PAPER-REAL-MODE). **НЕ** использовать seed-данные БД — моки более надёжны, не зависят от состояния окружения, прогон 24/7.

**Для Test A — s5-account balance cards:**
- Замокать `GET /api/v1/broker/accounts` → возвращает минимум один active non-sandbox BrokerAccount (используй такой же мок, как в задаче 8 PAPER-REAL-MODE — возможно можно вынести в общую фикстуру).
- Замокать `GET /api/v1/broker/accounts/{id}/portfolio` (или тот endpoint, который возвращает балансы — посмотри в `backend/app/broker/router.py`) → вернуть фиксированный набор балансов в `RUB` (например `[{"currency": "RUB", "balance": "100000.00", "blocked": "0"}]`).
- Проверить, что тест проходит: balance cards отрисованы с ожидаемыми суммами.

**Для Test B — s5-ticker-logos «Тестовая»:**
- Замокать `GET /api/v1/strategies` (или тот endpoint, который возвращает список стратегий) → вернуть массив со стратегией `{id: 1, name: "Тестовая", ticker: "SBER", is_active: true, ...}`. Минимальные поля, достаточные для рендера раскрывающегося раздела.
- Замокать связанные endpoints (если тест раскрывает стратегию и ожидает backtests/trades — тоже мок).
- Снять зависимость от реальной БД.

#### Выносимые фикстуры

Если в задаче 8 мок `broker/accounts` inline в тесте — **вынести в общую фикстуру** `frontend/e2e/fixtures/api_mocks.ts` (создать файл) с helper-функциями:
- `mockBrokerAccounts(page, accounts)` — передаёт массив аккаунтов, регистрирует route.
- `mockBrokerPortfolio(page, accountId, portfolio)` — для Test A.
- `mockStrategies(page, strategies)` — для Test B.

Это позволит переиспользовать в будущих тестах (и снизит дублирование).

**Не обязательно** делать всё через общий файл, если это сложно — можно inline в тестах. Приоритет — закрыть 2 failing, а не идеальный рефакторинг.

#### Критерии готовности

- [ ] `npx playwright test s5-account.spec.ts::"balance cards"` → passed
- [ ] `npx playwright test s5-ticker-logos.spec.ts` (все тесты, включая «Тестовая») → passed
- [ ] **Полный прогон** `npx playwright test` → **0 failures** (допустимы уже существующие 8 skipped с TODO-тикетами)
- [ ] Тесты проходят **независимо от состояния БД** — можно запустить на пустой БД, прогон всё равно зелёный.
- [ ] Моки не используют хардкод пароля/токена (только мок broker API response).

#### Коммит

Отдельный коммит: `fix(e2e): pre-existing failing через API-моки (S5R closeout #10)`

### Задача 11 — Alembic drift санитайзер-миграция

**Тип:** Fix (БД)
**Приоритет:** 🟢 Closeout wave 2
**Исполнитель:** DEV-1 closeout wave 2

#### Контекст

При задаче 9 DEV-1 wave 1 запустил `alembic revision --autogenerate -m "add figi to live_trades"` и обнаружил, что автогенерация показала **не только** ожидаемое `ADD COLUMN figi`, но и кумулятивный дрейф схемы:

- `ai_provider_configs.id` — `NOT NULL` изменение (вероятно колонка уже `NOT NULL` в БД, но не в модели)
- `user_ai_settings.id` — то же самое
- `broker_accounts.has_trading_rights` — изменение NOT NULL / default
- `trading_sessions.strategy_name` — изменение NOT NULL / default
- Индекс `idx_ai_user` — неожиданно отсутствует или добавляется

Это означает: в какой-то момент в БД локально (и возможно на проде) применялись ручные правки, которые **не отражены** в истории миграций Alembic. Если не исправить сейчас, каждая новая миграция в S6 будет тянуть этот drift как noise.

#### Что делать

1. **Проанализировать drift.** В `s5r/closeout` ветке заново запусти `alembic revision --autogenerate -m "drift sanitizer"` (или аналог). Посмотри, что именно autogenerate предлагает как drift.

2. **Сверить с моделями.** Для каждого drift-изменения (колонка, constraint, индекс) — проверь в соответствующей `models.py`:
   - Если модель уже содержит `nullable=False` / `index=True` / `server_default=...`, но БД не содержит — это **forward drift** (модель впереди БД), санитайзер просто синхронизирует БД.
   - Если модель **тоже** не содержит — это означает, что drift в БД был применён вручную, и модель надо либо обновить, либо отбросить drift.

3. **Создать миграцию санитайзер.** Имя: `<hash>_schema_drift_sanitizer.py`. Содержимое `upgrade()`:
   - `op.alter_column(...)` для NOT NULL колонок
   - `op.create_index(...)` / `op.drop_index(...)` для индексов
   - `op.alter_column(...)` для `server_default`
   Каждое изменение — с явным комментарием, к какой модели оно относится.

4. **Проверить round-trip.** `downgrade()` должен откатывать то же самое, что `upgrade()` применил. Проверь:
   ```bash
   alembic upgrade head
   alembic downgrade -1
   alembic upgrade head
   ```
5. **Регрессионный прогон.** После миграции запусти `pytest tests/unit/` + `pytest tests/test_broker/` + `pytest tests/test_trading/` — убедись, что существующие тесты не сломались (они используют модели, которые теперь должны совпадать с БД).

6. **НЕ расширять scope.** Если в процессе обнаружишь, что какие-то колонки реально проблемные (например, дублирующиеся данные) — зафиксируй в отчёте как «найденный баг», но **не пытайся починить** в рамках этой задачи. Цель — убрать drift, не перепроектировать схему.

#### Критерии готовности

- [ ] Новая миграция `alembic/versions/<hash>_schema_drift_sanitizer.py`
- [ ] `alembic revision --autogenerate -m "test"` **после** санитайзера возвращает **пустой** upgrade()/downgrade() (нет остатков drift)
- [ ] Round-trip `upgrade → downgrade → upgrade` чистый
- [ ] `pytest tests/unit/` + `tests/test_broker/` + `tests/test_trading/` — все зелёные (без регрессии)
- [ ] `ruff` + `mypy` — зелёные (новый файл миграции не ломает базлайн)

#### Коммит

Отдельный коммит: `fix(db): санитайзер накопленного schema drift (S5R closeout #11)`

### Ветка wave 2 — та же `s5r/closeout`

- **Не создавать** новую ветку. wave 2 продолжает `s5r/closeout`, в которой уже есть 3 коммита wave 1.
- После задач 10 и 11 — push, gh run watch, зелёный CI, **затем** мерж `s5r/closeout → develop` через `--no-ff` (делает оркестратор).

### Gotcha 11 — Alembic autogenerate detects drift

Независимо от задач 10/11, оркестратор добавляет в `Develop/CLAUDE.md` новую ловушку **Gotcha 11** (кандидат от DEV-1 wave 1):

> **Симптом:** `alembic revision --autogenerate` показывает не только ожидаемое изменение, но и кумулятивный drift схемы — NOT NULL / index / server_default — которого DEV не планировал.
> **Причина:** в БД локально (и возможно на проде) применялись ручные правки, не отражённые в истории миграций.
> **Правило:** всегда визуально ревьюить `upgrade()`/`downgrade()` после autogenerate. Неожиданный drift **вычищать** из миграции с текущей задачей и выносить в отдельную санитайзер-миграцию. Никогда не коммитить миграцию, которая смешивает ожидаемую логику задачи с неожиданным drift.

Это добавит в `Develop/CLAUDE.md` **коммитом оркестратора** перед запуском DEV-1 wave 2, чтобы субагент уже видел правило.

---

### Closeout wave 3 — обнаружены при ручном тестировании 2026-04-15 (задачи 12-14)

После закрытия wave 2 заказчик залогинился в UI и попытался запустить торговую сессию из результата бэктеста. Три проблемы:

1. **Frontend-регрессия/заглушка:** кнопка `Запустить торговлю` на `BacktestResultsPage` (строка 175-177) **не имеет `onClick`** — чистая заглушка из Sprint 3/4, никогда не была подключена. Клик не делает ничего. E2E тесты не покрывали этот flow (всё тестировалось через `TradingPage + LaunchSessionModal`). Это **продолжение паттерна «класс есть, но не подключён к UI»**, только на слое frontend.
2. **Backend bug в логах** — `tinvest_stream_reconnecting error="'MarketDataStreamService' object has no attribute 'candles'"` в бесконечном цикле для каждой подписки. Код в `broker/tinvest/adapter.py:725` использует устаревший API tinvest SDK (`client.market_data_stream.candles(...)` — такого метода нет).
3. **Backend warning в логах** — `iss_tail_fetch_failed error="can't compare offset-naive and offset-aware datetimes"` при попытке backend дозапросить хвост свечей через MOEX ISS. Не блокирует, но каждая попытка тонет в warning'ах.

Заказчик 2026-04-15 решил закрыть все три в S5R closeout wave 3 (та же логика: Sprint 6 должен стартовать с минимальным шумом в логах и полностью работающим UI).

Про кнопки `CSV`/`PDF` рядом с `Запустить торговлю`: они тоже заглушки, но **по плану Sprint 7 задача 7.3** (см. `development_plan.md:434` — `Экспорт CSV/PDF бэктеста (WeasyPrint + openpyxl)`). Оставляем заглушки, но помечаем `disabled` с tooltip «Будет реализовано в Sprint 7».

### Задача 12 — BacktestResultsPage: `Запустить торговлю` → `LaunchSessionModal`

**Тип:** Fix (Frontend + E2E)
**Приоритет:** 🟢 Closeout wave 3
**Исполнитель:** DEV-1 closeout wave 3
**Размер:** S–M (~1 час)

#### Контекст

Файл `frontend/src/pages/BacktestResultsPage.tsx` строки 150-178 содержит toolbar с тремя кнопками: `CSV`, `PDF`, `Запустить торговлю`. Все три **без `onClick`**. Данные бэктеста доступны в локальной переменной `bt` (тип `BacktestResult` из api/types), в том числе `bt.ticker`, `bt.timeframe`, `bt.strategy_id`, `bt.strategy_name`, `bt.strategy_version_id`.

Компонент `LaunchSessionModal` существует в `frontend/src/components/trading/LaunchSessionModal.tsx`. После S5R.2 он принимает обязательный `timeframe` из `Literal["1m","5m","15m","1h","4h","D","W","M"]`. Нужно проверить, какие props он уже принимает и какие требуется добавить для предзаполнения.

#### Что делать

1. **Проверить текущие props `LaunchSessionModal`.** Прочитай его целиком, определи:
   - Какие props для предзаполнения уже есть (`initialTicker`? `initialTimeframe`? `initialStrategyId`?)
   - Как модалка открывается сейчас из `TradingPage`
2. **Если props для предзаполнения нет** — добавить:
   ```tsx
   interface LaunchSessionModalProps {
     opened: boolean;
     onClose: () => void;
     initialTicker?: string;
     initialTimeframe?: Timeframe;
     initialStrategyId?: number;
     initialStrategyVersionId?: number;
   }
   ```
   И в `useState` модалки инициализировать значения из `initialX` props. При смене props или `opened=true` — синхронизировать форму. **Внимание Gotcha 9** (Playwright strict mode) — если добавляешь новый `data-testid`, убедись что он уникален.
3. **В `BacktestResultsPage`:**
   - Импортировать `LaunchSessionModal` из `@/components/trading/LaunchSessionModal` (или `@/components/trading`).
   - Добавить `const [launchOpen, setLaunchOpen] = useState(false);`
   - Кнопка `Запустить торговлю` — добавить `onClick={() => setLaunchOpen(true)}` + `data-testid="launch-trading-from-backtest-btn"`.
   - Кнопки `CSV` и `PDF` — пометить `disabled` + обернуть в `<Tooltip label="Будет реализовано в Sprint 7 (задача 7.3 — экспорт CSV/PDF через WeasyPrint + openpyxl)">...</Tooltip>`. Также добавить `data-testid="export-csv-disabled-btn"` и `"export-pdf-disabled-btn"` для будущих тестов.
   - После `<Tabs>`/остального содержимого рендерить:
     ```tsx
     <LaunchSessionModal
       opened={launchOpen}
       onClose={() => setLaunchOpen(false)}
       initialTicker={bt.ticker}
       initialTimeframe={bt.timeframe}
       initialStrategyId={bt.strategy_id}
       initialStrategyVersionId={bt.strategy_version_id}
     />
     ```
4. **Новый E2E тест** `frontend/e2e/s5r-backtest-launch-trading.spec.ts`:
   - Использовать фикстуру `api_mocks.ts` (из wave 2) — `injectFakeAuth`, `mockBrokerAccounts` с non-sandbox, `mockStrategies`.
   - Мокнуть `GET /api/v1/backtest/{id}` через `page.route('**/api/v1/backtest/*', ...)` с response типа `BacktestResult` (минимальные поля + `strategy_id`, `ticker="SBER"`, `timeframe="1h"`).
   - Мокнуть `POST /api/v1/trading/sessions/start` с response 200 + id новой сессии.
   - Шаги:
     1. Открыть `/backtests/1` (или каким путь страницы)
     2. Проверить, что кнопка `launch-trading-from-backtest-btn` видна
     3. Клик → проверить открытие `LaunchSessionModal` (через `data-testid="session-timeframe-select"` из S5R.2)
     4. Проверить предзаполнение: `session-timeframe-select` содержит `"1h"`, поле тикера — `"SBER"`
     5. Клик на Submit модалки → проверить POST к `/api/v1/trading/sessions/start` (через `page.waitForRequest`)
     6. Проверить закрытие модалки
   - Отдельный тест «CSV/PDF disabled with tooltip»: hover на кнопку → появляется tooltip с текстом «Sprint 7».

#### Критерии готовности

- [ ] Кнопка `Запустить торговлю` имеет `onClick`, открывает `LaunchSessionModal` с предзаполненными данными бэктеста
- [ ] `LaunchSessionModal` поддерживает props `initialTicker/initialTimeframe/initialStrategyId/initialStrategyVersionId`
- [ ] Кнопки `CSV`/`PDF` — `disabled` + Tooltip с отсылкой на Sprint 7
- [ ] Новый E2E тест `s5r-backtest-launch-trading.spec.ts` — зелёный через моки
- [ ] Полный локальный `npx playwright test` — **0 failures** (могут быть те же 8 skipped)
- [ ] `pnpm lint && pnpm tsc --noEmit && pnpm test` — зелёные

#### Коммит

`fix(backtest): подключить LaunchSessionModal к кнопке "Запустить торговлю" + disabled CSV/PDF (S5R closeout #12)`

### Задача 13 — Backend bug: tinvest_stream `.candles` AttributeError

**Тип:** Bug (Backend)
**Приоритет:** 🟢 Closeout wave 3
**Исполнитель:** DEV-1 closeout wave 3
**Размер:** M (~2 часа)

#### Симптом

В логах backend (при работающем backend после логина):
```
tinvest_stream_reconnecting  error="'MarketDataStreamService' object has no attribute 'candles'"
  subscription_id=...  ticker=SBER
```
Повторяется **каждые 5 секунд** в бесконечном цикле для каждой активной подписки на свечи. Перезагрузка backend не помогает.

#### Корень проблемы

`backend/app/broker/tinvest/adapter.py:725`:
```python
async for candle in client.market_data_stream.candles(
    instruments=[CandleInstrument(figi=figi, interval=sub_interval)],
):
```

**У `MarketDataStreamService` нет метода `.candles`.** Проверено оркестратором через `dir(MarketDataStreamService)` — есть только `market_data_stream` и `market_data_server_side_stream`. Код написан под несуществующий API — вероятно, это был autocomplete-галлюцинация или остаток от старой версии SDK.

#### Правильный API tinkoff-investments (актуальная версия в venv)

```python
from tinkoff.invest import (
    MarketDataRequest,
    SubscribeCandlesRequest,
    SubscriptionAction,
    CandleInstrument,
    SubscriptionInterval,
)

async def _subscribe():
    async def request_iterator():
        # Подписаться при первом yield
        yield MarketDataRequest(
            subscribe_candles_request=SubscribeCandlesRequest(
                subscription_action=SubscriptionAction.SUBSCRIPTION_ACTION_SUBSCRIBE,
                instruments=[
                    CandleInstrument(figi=figi, interval=sub_interval),
                ],
            )
        )
        # Держать соединение открытым — await forever
        while True:
            await asyncio.sleep(3600)

    async with self._create_client() as client:
        async for response in client.market_data_stream.market_data_stream(request_iterator()):
            if response.candle:
                candle_data = TInvestMapper.candle_to_candle_data(response.candle)
                await callback(candle_data)
            # subscribe_candles_response — подтверждение, не надо ничего делать
```

**Проверь в SDK** через `python -c "from tinkoff.invest import MarketDataRequest; help(MarketDataRequest)"`, какие именно поля в `MarketDataRequest` — возможно `subscribe_candles_request` vs `subscribe_candles_request` отличается по имени.

#### Что делать

1. **Проверить точный API** в текущей версии tinkoff-investments SDK через `inspect.signature` / `help()` / чтение `site-packages/tinkoff/invest/...`.
2. **Переписать `subscribe_candles`** в `adapter.py:688-748` (или где там метод целиком) под правильный API через `market_data_stream()` с async request iterator.
3. **Сохранить паттерн Gotcha 4** (T-Invest gRPC persistent connection) — **одно** соединение на все подписки, мультиплексирование через `StreamManager`. НЕ создавать отдельный stream для каждой подписки.
4. **Тест:** unit-тест с моком `client.market_data_stream.market_data_stream` (async generator), проверка что `callback` вызывается с правильным `CandleData`.
5. **Живая проверка:** после фикса перезапустить backend (убить PID backend, запустить заново) и убедиться, что в логах **нет** `tinvest_stream_reconnecting ... .candles` ошибок в течение 30 секунд.

Если столкнёшься с более глубокими проблемами SDK (например, gRPC auth фейлится) — зафиксируй в отчёте как «найденный подбаг» и реши, можно ли обойти (например, через mock для paper-сессий), не выходя за scope.

#### Критерии готовности

- [ ] Код `adapter.subscribe_candles` использует правильный API `market_data_stream.market_data_stream()` с async request iterator
- [ ] Паттерн persistent connection сохранён (Gotcha 4)
- [ ] Unit-тест с моком SDK — зелёный
- [ ] Локальный перезапуск backend → `grep "tinvest_stream_reconnecting.*candles" logs` → 0 матчей за 30 секунд после старта
- [ ] `ruff` + `mypy` + `pytest tests/unit/` — зелёные

#### Коммит

`fix(tinvest): исправить API market_data_stream — устранить .candles AttributeError (S5R closeout #13)`

### Задача 14 — Backend warning: iss_tail_fetch timezone compare

**Тип:** Bug (Backend, warning-level)
**Приоритет:** 🟢 Closeout wave 3
**Исполнитель:** DEV-1 closeout wave 3
**Размер:** XS (~15-30 минут)

#### Симптом

```
iss_tail_fetch_failed  error="can't compare offset-naive and offset-aware datetimes"  ticker=SBER
```

Встречается часто при работе `MarketDataService._fetch_candles` — когда backend решает дозапросить хвост свечей у MOEX ISS (по условию `to_dt - last_ts > tail_gap_threshold`). Сама проверка условия уже корректна (через нормализацию `to_naive`, `last_naive` в `service.py:353-354`). **Warning** исходит от исключения внутри `_fetch_via_iss`, которое ловится на строке 379.

#### Что делать

1. **Найти `_fetch_via_iss`** в `backend/app/market_data/service.py` или соседних модулях.
2. **Включить детальное логирование** (на время диагностики) — где именно внутри функции бросается `TypeError: can't compare offset-naive and offset-aware datetimes`. Варианты:
   - Сравнение timestamp свечей ISS с `last_naive` / `to_naive`
   - Сравнение в `_validate_candles` или `_normalize_candles`
   - Сравнение в фильтре `c.timestamp > last_naive` (строка 369)
3. **Привести все datetime к консистентному формату.** Правильный подход: **хранить и сравнивать всегда naive UTC** (проект уже использует `.replace(tzinfo=None)`). Если ISS возвращает tz-aware — нормализовать сразу при парсинге в `broker/moex_iss/parser.py` (или где там маппинг).
4. **Unit-тест** с фикстурой, где ISS возвращает tz-aware свечи и `last_ts` — naive. Без фикса тест падает, с фиксом — зелёный.

#### Критерии готовности

- [ ] `grep "iss_tail_fetch_failed.*offset-naive" logs` → 0 за 60 секунд работы backend
- [ ] Новый unit-тест для tz-консистентности свечей ISS
- [ ] `ruff` + `mypy` + `pytest` — зелёные

#### Коммит

`fix(market-data): привести timestamps ISS к naive UTC — устранить tz compare warning (S5R closeout #14)`

### Ветка wave 3 — `s5r/closeout-wave3`

- Создаётся **новая** ветка от актуального `develop` (после wave 2 мержа, commit `a79432f`). **Не** переиспользовать `s5r/closeout` (она удалена).
- 3 коммита (по одному на задачу).
- После push и зелёного CI — мерж в develop через `--no-ff`.
- Затем удалить ветку локально, обновить итоговый changelog + arch_review + project_state.

### Итоговый план закрытия S5R

После wave 3 Sprint_5_Review считается **полностью закрытым без хвостов**. Техдолг = 0. Все known issues устранены. Sprint 6 стартует с чистого листа.
