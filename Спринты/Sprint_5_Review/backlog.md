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
| 7 | **FAVORITES input — поиск внутри списка избранного** | Fix | 🟢 Closeout | 4 E2E skip | ⬜ TODO | секция Closeout ниже |
| 8 | **E2E PAPER-REAL-MODE fixture** | Fix | 🟢 Closeout | 1 E2E skip | ⬜ TODO | секция Closeout ниже |
| 9 | **MODEL-FIGI: FIGI в LiveTrade + source-правило через FIGI** | Feature | 🟢 Closeout | Замечание C8 | ⬜ TODO | секция Closeout ниже |

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

### Ветка и порядок работы

**Ветка:** `s5r/closeout` от `develop` (актуальное состояние после 4 мержей S5R).

**Порядок выполнения DEV-1 closeout:**
1. Задача 8 (PAPER-REAL-MODE fixture) — самая маленькая, разогрев. Коммит отдельный.
2. Задача 7 (FAVORITES filter-input) — frontend + 4 e2e теста. Коммит отдельный.
3. Задача 9 (MODEL-FIGI) — backend + миграция + unit-тесты. Коммит отдельный.

После всех 3 коммитов — push, CI должен быть зелёный, мерж `s5r/closeout → develop` через `--no-ff`.
