# Changelog — Sprint 3: Стратегии + редактор

> Фиксирует все замечания и изменения, выявленные при проверке результатов спринта.
> Обязательный файл каждого спринта (добавлен по итогам Sprint_2_Review, задача #3).

## Исправления при интеграции Wave 1 (2026-03-27)

| # | Проблема | Причина | Исправление |
|---|----------|---------|-------------|
| F1 | Тест `AddBrokerForm` падал — проверял удалённый Sandbox-чекбокс | Чекбокс удалён в Sprint_2_Review (F3), тест не обновлён | Убрана строка проверки Sandbox-чекбокса |
| F2 | Тест `test_setup_endpoint_returns_403` падал | Sprint_2_Review (F10) разрешил многопользовательский режим, тест устарел | Тест обновлён: ожидает 201 вместо 403 |
| F3 | Тесты `test_market_data` (3 шт) падали — `len(result) == 3` | `get_candles()` теперь возвращает кортеж `(candles, source)`, тесты не распаковывали | Тесты обновлены: `candles, source = result` |
| F4 | `react-resizable-panels` v4.7.6 — `PanelGroup` и `PanelResizeHandle` не экспортируются | API v4.x: `Group`, `Panel`, `Separator` | Импорт: `Group as PanelGroup`, `Separator as PanelResizeHandle` |
| F5 | Playwright E2E файлы подхвачены Vitest — 4 test file failures | Vitest не исключал `e2e/` директорию | `vite.config.ts`: добавлен `exclude: ['e2e/**']` |
| F6 | `import { Strategy }` из strategyApi ломал runtime (белый экран) | TypeScript interface — type-only export, стирается при компиляции | Заменён на `import type { Strategy }` |

## Исправления ARCH ревью (2026-03-27)

| # | Проблема | Критичность | Исправление |
|---|----------|-------------|-------------|
| A1 | AST analyzer: dunder-атрибуты через `ast.Attribute` не проверялись (`().__class__.__subclasses__()` проходил) | MAJOR | Добавлена проверка `ast.Attribute` для dunder-атрибутов в `ast_analyzer.py` |
| A2 | Rate limiter auth limit = 10/min вместо спецификации | MAJOR | Изменён на 20/min (brute-force protection на уровне приложения блокирует на 5 неудачных попытках) |
| A3 | Volume индикатор отсутствовал в `INDICATOR_MAP` Code Generator | MAJOR | Добавлен `"Volume": None` + обработка `self.volume = self.data.volume` |

## Исправления при тестировании Rate Limiter (2026-03-27)

| # | Проблема | Причина | Исправление |
|---|----------|---------|-------------|
| R1 | Auth тесты падали — 429 вместо ожидаемых статусов | Rate Limiter shared state между тестами, лимит исчерпывался | Добавлен `reset()` метод + autouse fixture в `tests/conftest.py` |
| R2 | Brute-force тест (423) получал 429 | 6 запросов к `/auth/login` при лимите auth=5 | `/auth/setup` исключён из auth rate limiting, лимит auth увеличен до 20/min |

## Исправления при ревью заказчика (2026-03-27)

| # | Проблема | Причина | Исправление |
|---|----------|---------|-------------|
| B1 | Белый экран при fullscreen → обычный режим | `height: calc(100vh - 60px)` не адаптировался, нет `overflow: hidden` | `AppShell.Main`: `display: flex, overflow: hidden`. StrategyEditPage: `flex: 1, minHeight: 0` |
| B2 | Двойной клик на блоках переставал работать после resize | `workspaceRef` (ref) не вызывал rerender CustomToolbox при смене workspace | Заменён `useRef` на `useState` — workspace как state, CustomToolbox перерендеривается |
| B3 | Drag & drop блоков из Toolbox в workspace не работал | Blockly SVG canvas не слушает HTML drag events | Добавлены `onDragOver`/`onDrop` на контейнер workspace + `pageToWorkspaceCoords()` для точного позиционирования |

| B4 | Workspace и блоки не занимают всю высоту экрана — пустое пространство снизу | `AppShell` имел `padding="md"` + `Main` использовал `min-height` вместо `height` | `AppShell`: `padding={0}`, `Main`: `height: 100vh` (Mantine auto-padding учитывает header/footer). Padding перенесён на уровень каждой страницы |
| B5 | Высота всё ещё не занимала весь экран после B4 | `calc(100vh - header - footer)` не учитывал внутренний padding Mantine Main | Заменён на `height: 100vh` — Mantine Main имеет `padding-top/bottom` = header/footer, `box-sizing: border-box` делает content area = viewport минус paddings |

| B6 | Блок «Сравнение»: правый вход (число) невозможно заполнить | `RIGHT` был `appendValueInput` с check `['Indicator', 'Number']`, но блока `Number` в проекте нет | Заменён на `FieldNumber(70)` прямо в блоке — пользователь вводит число в поле. Формат: «Если [индикатор] > значение [70]» |

| B7 | Скроллинг в панели блоков (Toolbox) не работал | Контейнер Toolbox не имел `overflow: hidden` и `maxHeight`, `ScrollArea` не имел `minHeight: 0` (необходимо для flex-скролла) | Добавлены `overflow: hidden`, `maxHeight: 100%` на контейнер; `minHeight: 0` на `ScrollArea` |

| B8 | Блоки не восстанавливаются при повторном открытии стратегии | `initialBlocksXml` читался только при создании workspace (init useEffect), а API-данные приходили позже — блоки не загружались | Добавлен отдельный `useEffect([initialBlocksXml])` — при изменении props загружает блоки в существующий workspace через `Blockly.serialization.workspaces.load()` |

| B9 | Блоки не восстанавливаются при повторном открытии (несмотря на fix B8) | `handleSave` использовал `blocksJson` state, который мог быть null если пользователь не менял блоки. Сохранялось `'{}'` вместо реального состояния | `getCurrentBlocksJson()` — при сохранении всегда сериализует текущий workspace через `Blockly.serialization.workspaces.save()` |
| B10 | Раскрытие категории в Toolbox увеличивало высоту всей страницы | `Tabs` и `Tabs.Panel` не имели `minHeight: 0` и `overflow: hidden` — flex children выходили за пределы контейнера | Добавлены `minHeight: 0, overflow: hidden` на Tabs и Editor panel |

| B11 | Блок «Сравнение» позволял только число, нельзя было сравнить с индикатором | Fix B6 убрал value input RIGHT и оставил только FieldNumber | Добавлен dropdown «число / индикатор» с динамической формой: при «число» — FieldNumber, при «индикатор» — пазл-вход для подключения блока |

| B12 | Блок «Сравнение» увеличивался в высоту при выборе «число» | Threshold был на отдельной строке (отдельный `appendDummyInput`) | Все элементы (оператор + тип + число) на одной строке через `setInputsInline(true)`. Threshold добавляется/удаляется как field на той же строке |
| B13 | Кнопка «Генерировать» — ошибка бэкенда | Фронт отправлял Blockly workspace state (внутренний формат), а бэкенд ожидал наш JSON формат `{version, blocks: [...]}` | Добавлена `getBlocksForBackend()` — конвертирует workspace через `jsonGenerator.workspaceToCode()` в формат бэкенда перед отправкой |

| B14 | Генерация кода — ошибка 500 на бэкенде | `code_generator.py` требовал `"id"` в каждом блоке (`block_map = {b["id"]: b}`), а фронтовый JSON generator не всегда добавлял id | Добавлена авто-генерация id: `if "id" not in b: b["id"] = f"b{i+1}"` перед построением block_map |

| B15 | Генерация 500 — code_generator падал на вложенных объектах вместо строк-ссылок | Фронт шлёт `"left": {"type":"indicator","name":"EMA",...}` (inline), а бэкенд ожидал `"left": "b1"` (string ID) | Добавлен `_resolve_ref()` — принимает и строку-ID и inline-объект. Обновлены все `_generate_next` ссылки. Добавлена поддержка операторов `gt`/`lt` (фронт-формат) |

| B16 | Сгенерированный код не соответствовал блокам (пустые params, unknown condition) | Фронтовые JSON-генераторы использовали типы (`filter`, `management`) не совместимые с бэкендом (`time_filter`, `stop_loss`, `position_size`) | Исправлены типы в BlockGenerators.ts: `filter` → `time_filter`, `management/stop_loss` → `stop_loss`, `management/position_size` → `position_size`. Формат `in_zone` приведён к `left/low/high` |
| B17 | Нет предупреждения при сохранении с устаревшим кодом | Пользователь мог изменить блоки, сохранить, а код оставался от предыдущей генерации | Добавлен флаг `codeOutdated`. При изменении блоков → true, при генерации → false. Оранжевое предупреждение в CodePanel: «Блоки изменены — код устарел. Нажмите Генерировать» |

| B18 | Код по-прежнему `params=()`, `if True` — блоки не распознавались бэкендом | `getTopBlocks()` возвращал 1 корневой блок (entry_signal) со всеми остальными внутри как вложенные объекты. Бэкенд ожидал плоский список | `getBlocksForBackend()` переписан: `getAllBlocks()` → сериализация каждого блока → flat list с ID → замена inline-объектов на строковые ссылки |

| B19 | Предупреждение «код устарел» сразу при открытии стратегии и после генерации+сохранения | 1) Blockly fire change events при загрузке блоков → `codeOutdated=true`. 2) `setCodeOutdated(false)` не вызывался при загрузке существующего кода | Добавлен `loadingBlocksRef` — подавляет dirty/outdated флаги первые 500мс после загрузки блоков. При загрузке `generated_code` из версии → `setCodeOutdated(false)` |

| B20 | Сохранение с устаревшим кодом молча сохраняло рассинхронизированные данные | Нет проверки при сохранении | Модал подтверждения: «Сгенерировать и сохранить» / «Сохранить без генерации» / «Отмена». Решение заказчика: бэктест нельзя запустить с устаревшим/ошибочным кодом (пометка на S4-S5) |

| B21 | При открытии стратегии с устаревшим кодом — показывалась зелёная плашка вместо оранжевой. Повторное сохранение не показывало предупреждение | `codeOutdated` не сохранялся в БД — при загрузке всегда был `false` | Флаг `code_outdated` сохраняется в `parameters_json` версии. При загрузке — восстанавливается. При «Сохранить без генерации» → `code_outdated: true`. При «Сгенерировать и сохранить» → `code_outdated: false` |

| B22 | «Сгенерировать и сохранить» оставляло оранжевую плашку | `handleGenerate` ставит `setCodeOutdated(false)`, но React state не обновился до `doSave()`, который читал старый `codeOutdated=true` | `doSave(forceOutdated)` — явный параметр. `handleGenerateAndSave` → `doSave(false)`, `handleSaveWithoutGenerate` → `doSave(true)` |
| B23 | Категории блоков раскрыты при открытии редактора | `defaultValue={['indicators']}` в Accordion | Заменено на `defaultValue={[]}` — все свёрнуты |

| B24 | Размер позиции в лотах принимал дробные значения (0.1) | `FieldNumber(10, 0.1, 100)` без учёта режима. На MOEX лоты только целые | Динамический `updateValueField_`: при «фикс. лоты» → min=1, step=1; при «%» → min=0.1, step=0.1 |
| B25 | Нет предупреждений при пустых входах блоков (например, Сравнение без индикатора) | Blockly не валидировал подключение обязательных входов | Добавлена `validateBlocks()` — проверяет обязательные value inputs при каждом изменении workspace. Жёлтый треугольник ⚠ на блоке с текстом «Не подключено: ...» |

| B26 | Валидация блоков не работала — жёлтый треугольник не появлялся | `Blockly.inputTypes` = undefined в Blockly 12. Проверка `input.type === Blockly.inputTypes.VALUE` всегда false | Заменено на `Blockly.INPUT_VALUE ?? 1` — корректная константа для Blockly 12 |

| B27 | Валидация блоков всё ещё не показывала ⚠ (B26 не помог полностью) | Validation listener внутри `useCallback` с closure на `onBlocksChange` мог быть устаревшим. Также вызывался синхронно до завершения Blockly event processing | Отдельный validation listener зарегистрирован в `useEffect` (без closure), debounced через `requestAnimationFrame` |

| B28 | При генерации кода с ошибочными блоками — нет предупреждений в панели кода | Валидация показывала ⚠ на блоках, но не влияла на генерацию и CodePanel | `getBlockWarnings()` собирает все warning-и блоков + структурные проверки (нет ВХОД/ВЫХОД/индикаторов). Показываются как жёлтые warnings в CodePanel после генерации |

| B29 | Warnings не появлялись в CodePanel при генерации с ошибочными блоками (B28 не помог) | `block.warning?.getText?.()` = undefined в Blockly 12 (warning icon не имеет getText в runtime). Полагался на внутренний API | Полностью переписана `getBlockWarnings()` — проверяет inputs напрямую через `block.getInput().connection?.targetBlock()`, без обращения к Blockly warning API. Свои проверки + структурные (нет ВХОД/ВЫХОД/индикаторов) |

| B30 | Ложное «код устарел» через несколько секунд после открытия стратегии без изменений | Таймер 500мс в `loadingBlocksRef` — ненадёжен, Blockly шлёт change events с задержкой | Заменён на snapshot-подход: `savedBlocksSnapshotRef` хранит JSON-состояние блоков. Первый event = baseline. Последующие сравниваются — dirty/outdated только при реальном отличии. Snapshot обновляется при save. |

| B31 | При открытии стратегии с ошибочными блоками — ⚠ не видны, warnings не показаны до генерации | Warnings не сохранялись в БД и не вычислялись при загрузке | 1) `validateBlocks()` вызывается сразу после загрузки блоков — ⚠ на блоках видны сразу. 2) `has_warnings` + `warnings[]` сохраняются в `parameters_json`. 3) При загрузке стратегии warnings восстанавливаются в CodePanel |

| B32 | Ложный warning «правый индикатор» при сохранении блока «Сравнение» в режиме «число» | После загрузки из БД `updateShape_` не вызывается — блок имеет `RIGHT_TYPE='number'` в field, но input `RIGHT` остаётся от десериализации | Валидация теперь проверяет `getField('THRESHOLD')` наличие + если `RIGHT_TYPE='number'` но нет threshold — вызывает `updateShape_('number')` для приведения блока в корректное состояние |

| B33 | Ложный warning «правый индикатор» сохранялся даже после переключения на «число» (B32 не помог) | Blockly при десериализации восстанавливает поля но не вызывает `updateShape_` — input `RIGHT` остаётся, `THRESHOLD` не создаётся. Костыль с ручным вызовом `updateShape_` в валидации не работал надёжно | Добавлены `saveExtraState`/`loadExtraState` в блок `condition_compare` — Blockly 12 нативный механизм сохранения/восстановления динамической формы блока. При загрузке `loadExtraState` → `updateShape_(rightType)` |

| B34 | «Сгенерировать и сохранить» писало ложный warning в БД (B33 не помог) | `doSave` пересчитывал `getBlockWarnings()` — находил «призрачный» блок condition_compare от предыдущего состояния workspace. React state warnings ещё не обновился | `doSave` больше не пересчитывает warnings — принимает их явным параметром. `handleGenerateAndSave` → `doSave(false, [])`, `handleSaveWithoutGenerate` → `doSave(true, warnings)` |

| B35 | Ложный warning показывался при открытии стратегии — загружался из предыдущих версий в БД | Warnings из `parameters_json` загружались как есть, даже если блоки с тех пор изменились | Warnings из БД больше не загружаются в CodePanel. Warnings показываются только: 1) ⚠ на блоках (визуально, сразу при загрузке через `validateBlocks`), 2) в CodePanel только после нажатия «Генерировать» |

| B36 | При открытии стратегии с ошибками — warnings не видны в CodePanel (после fix B35 убрали загрузку из БД) | Warnings убрали из загрузки БД но не добавили пересчёт из блоков | Добавлен callback `onBlocksLoaded` в BlocklyWorkspace → вызывается после загрузки блоков → StrategyEditPage пересчитывает `getBlockWarnings(ws)` из реальных блоков и показывает в CodePanel |

| B37 | Матрица тестирования Code Generator: проверено 58 кейсов | 12 ✅, 46 ❌ | `codegen_test_matrix.md` — полные результаты + приоритеты исправлений P1/P2/P3 |

| B38 | Полный рефакторинг Code Generator — исправлены все 46 багов из матрицы тестирования | Генератор полностью переписан | **P1:** AND/OR/NOT (рекурсивный `_build_condition_expr`), position size (fixed lots `self.buy(size=N)` + percent расчёт), все операторы (>=, <=, ==), сравнение с индикатором (`self.sma[0] > self.ema[0]`). **P2:** SL/TP через ордера (`bt.Order.Stop/Limit`), `import datetime` вверху, дедупликация индикаторов, уникальные имена (`sma`, `sma_2`), crossover не дублируется. **P3:** MACD/BB/Stochastic корректные params, `def next: pass` при пустой стратегии |

| B39 | Round-trip тесты (шаблон → парсер → блоки → генератор → код): 5 из 8 падали | TemplateParser: 1) `__idx_N` ссылки не конвертировались в block IDs. 2) Сигналы не получали ссылку на condition. 3) Операторы >=/<=/== маппились неверно. 4) Compare-условия не генерировали сигналы. 5) «17 лотов» не парсилось | Исправлено: ссылки резолвятся после присвоения ID, сигналы привязываются к ближайшему condition, операторы → gt/lt/gte/lte/eq, сигналы для compare, LOTS_PATTERN для фикс. лотов. 8/8 round-trip ✅ |

## Замечания ревью заказчика — UI-рефакторинг редактора стратегий (2026-03-30)

| # | Описание | Тип | Статус |
|---|----------|-----|--------|
| B40 | Убраны параметры стратегии (стоп-лосс, тейк-профит, размер позиции, макс. позиций) со страницы «Описание» — не были связаны с блоками | Модификация | ✅ |
| B41 | Python-код перенесён на вкладку «Содержание» (бывшее «Описание»). Layout: слева описание + параметры запуска (инструменты, таймфрейм) + бэктест-кнопка, справа — код стратегии. Новый компонент `CodeDisplay.tsx` | Модификация | ✅ |
| B42 | Уведомления заменены на toast (Mantine Notifications). Авто-исчезновение 5 сек, по клику — мгновенно. Показываются при генерации/сохранении | Модификация | ✅ |
| B43 | Кнопка «Режим B» и модальное окно убраны. Правая панель редактора: `TemplatePanel` — inline-шаблон (7 секций) + «Проверить» + «Сформировать на основании схемы» (`blocksToTemplate.ts`). Backend парсер обновлён: поддержка 7-секционного формата (без Названия/Инструментов/Таймфрейма) | Модификация | ✅ |
| B44 | «Проверить и сформировать блоки» стирало существующую схему | Парсер возвращал flat-формат `{version, blocks:[]}`, а Blockly ожидал свой state-формат `{blocks:{languageVersion,blocks:[]}}`. При загрузке workspace очищался, а новые блоки не создавались | Добавлен конвертер `flatBlocksToWorkspace.ts`: преобразует flat-формат парсера в Blockly workspace state с корректными типами блоков, полями и позициями |
| B46 | `blocksToTemplate` генерировал неверный порядок слов для crossover | `[I1] пересекает снизу вверх [I2]` — парсер ожидал `[I1] пересекает [I2] снизу вверх` | Исправлен порядок: `${left} пересекает ${right} ${dirLabel}` |
| B47 | Фильтр времени не присоединялся к цепочке блоков | `flatBlocksToWorkspace` создавал фильтры как отдельные top-level | Фильтры включены в общую цепочку `signalIds + managementIds + filterIds` |
| B48 | useEffect перезаписывал шаблонные блоки сохранённой версией | При apply template → setInitialBlocksXml, затем useEffect(currentStrategy) снова ставил старые блоки | Добавлен `templateAppliedRef` — блокирует перезапись из useEffect после apply |
| B51 | Code Generator: дубликат crossover + неверное условие выхода + ложный toast ошибки | 1) `_gen_init` искал crossover линейно — находил дубликаты из top-level и logic. 2) `result` был в scope if/else — ReferenceError при подсчёте строк для toast, хотя код генерировался успешно | 1) Рекурсивный `_collect_crossovers` с дедупликацией по `id()`. 2) `generatedResult` поднят в общий scope. 3) `_extract_inline_indicators` промотирует inline индикаторы из nested conditions |
| B50 | Code Generator не поддерживал `operator: 'or'/'and'/'not'` и новый формат params | 1) `type: "logic"` вместо `type: "condition", operator: "or"`. 2) `right` = `{type:"value",value:70}` вместо числа `70`. 3) `position_size` с `lots` вместо `{mode:"fixed", value:N}` | Исправлен `_build_condition_expr`: поддержка and/or/not с left/right ссылками. Поддержка `right` как числа. Поддержка `params: {lots: N}` и `params: {percent: N}` |
| B49 | Round-trip тесты: 44 backend + 24 frontend = 68 автоматических тестов | Покрытие: 8 типов индикаторов, 8 условий входа, 3 выхода, 4 логики (И/ИЛИ/НЕ/вложенная), 6 управления, 2 фильтра, 4 полные стратегии, 7 edge cases | `test_round_trip.py` (44 теста) + `flatBlocksToWorkspace.test.ts` (24 теста) |
| B45 | Строгий формат шаблона с `[I{N}]` ссылками и round-trip совместимость | Блоки создавались без связей, индикаторы дублировались, отсутствовал детерминированный формат | **blocksToTemplate.ts** переписан: дедупликация индикаторов, `[I1]`/`[I2]` ссылки, формат `ВХОД Long КОГДА ...`, `%` = проценты / число = пункты/лоты. **flatBlocksToWorkspace.ts** переписан: рекурсивное разрешение ссылок, вложенные `inputs` для connections, `next`-цепочки, `extraState`. **template_format_rules.py** создан: все правила формата (regex, маппинги, описание для AI). **block_parser.py** переписан: поддержка `[I{N}]` формата, рекурсивный парсер условий с И/ИЛИ/НЕ, обратная совместимость со старым форматом |

**Легенда:**
- Тип: Несоответствие ТЗ / Баг / Улучшение / Модификация
- Соответствие ТЗ: ✅ / ⚠️ / ❌
- Статус: ⬜ / 🔄 / ✅
