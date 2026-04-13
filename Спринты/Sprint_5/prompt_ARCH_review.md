---
sprint: 5
agent: ARCH
role: Technical Architect — Review + QA
wave: 4
depends_on: [DEV-1, DEV-2, DEV-3, DEV-4, DEV-5]
---

# Роль

Ты — технический архитектор. Проведи полное ревью Sprint 5: проверь корректность реализации, безопасность, производительность. Запусти все тесты. Составь E2E-тесты для новой функциональности. Результат: `arch_review_s5.md`.

# Предварительная проверка

```
1. Все DEV-задачи завершены (DEV-1..5, UX)
2. pytest tests/ проходит
3. pnpm test проходит
4. Все миграции применены: alembic upgrade head
```

**Если тесты падают — сообщи:** "БЛОКЕР: [N] тестов упало. ARCH ревью невозможно до исправления."

# Рабочие директории

- `Test/Develop/backend/` — бэкенд
- `Test/Develop/frontend/` — фронтенд

# Ревью: Backend

## 1. Trading Engine (app/trading/)

Проверить:
- [ ] `engine.py`: SessionManager корректно обрабатывает жизненный цикл (start → pause → resume → stop)
- [ ] `engine.py`: restore_sessions — восстановление при перезапуске, сверка позиций для Real
- [ ] `engine.py`: SignalProcessor.process_candle — latency < 500ms (проверить с профилированием)
- [ ] `engine.py`: OrderManager — integration с CircuitBreaker (check_before_order вызывается)
- [ ] `engine.py`: PositionTracker — P&L расчёт (long и short позиции)
- [ ] `paper_engine.py`: PaperBrokerAdapter — T+1 эмуляция корректна, MOEX-календарь используется
- [ ] `paper_engine.py`: слippage эмуляция, проверка средств, blocked_amount
- [ ] `schemas.py`: все Pydantic v2, ConfigDict(from_attributes=True)
- [ ] `router.py`: CSRF на мутирующих endpoints
- [ ] `router.py`: авторизация (current_user dependency) на всех endpoints
- [ ] `service.py`: DI через Depends, не синглтоны

**Финансовые расчёты:**
- [ ] Все денежные операции через `decimal.Decimal`, не float
- [ ] P&L = (exit_price - entry_price) × volume_lots × lot_size - commission (для long)
- [ ] Лотность учитывается (размер лота из InstrumentInfo)
- [ ] Slippage фиксируется: signal_price vs fill_price

## 2. Circuit Breaker (app/circuit_breaker/)

Проверить:
- [ ] `engine.py`: все 9 проверок реализованы
- [ ] `engine.py`: asyncio.Lock для race conditions
- [ ] Дневной убыток: правильный расчёт (realized + unrealized), начало дня 10:00 MSK
- [ ] Max drawdown: peak_equity обновляется при закрытии позиции
- [ ] Short block: все Short-ордера блокируются (фаза 1)
- [ ] Cooldown: session.last_signal_at корректно обновляется
- [ ] Insufficient funds streak: consecutive_fund_skips >= 3 → пауза
- [ ] _trigger: запись CircuitBreakerEvent + пауза сессии/всех сессий + EventBus
- [ ] daily_loss и max_drawdown: паузят ВСЕ стратегии пользователя, не только текущую

## 3. Bond Service (app/market_data/bond_service.py)

Проверить:
- [ ] Формула НКД: `(Номинал × Ставка / 100) × (Дни / Дней_в_периоде)` — корректна
- [ ] Граничные случаи: день купона (НКД = 0), день перед купоном, облигация без купонов
- [ ] Кеш bond_info_cache: обновление раз в сутки
- [ ] MOEX ISS парсинг: корректная обработка ответа API

## 4. Tax Export (app/tax/)

Проверить:
- [ ] FIFO matching: правильный порядок (первый купленный → первый проданный)
- [ ] Partial fills: лот разделяется корректно
- [ ] Облигации: НКД отдельной строкой
- [ ] Комиссии: уменьшают налогооблагаемую базу
- [ ] xlsx: openpyxl генерирует валидный файл, открывается в Excel
- [ ] csv: корректная кодировка (UTF-8 BOM для Excel)
- [ ] Группировка по типам инструментов

## 5. Corporate Actions (app/corporate_actions/)

Проверить:
- [ ] Split: цена входа и объём корректируются пропорционально
- [ ] Dividend: начисляется в P&L, Paper баланс увеличивается
- [ ] Coupon: учитывает НКД через BondService

## 6. Broker Adapter (app/broker/)

Проверить:
- [ ] base.py: новые dataclasses (PositionInfo, OrderResponse, OrderStatus, InstrumentInfo)
- [ ] tinvest/adapter.py: все 6 бывших stub-методов реализованы
- [ ] subscribe_candles: gRPC streaming с reconnect
- [ ] rate_limiter.py: персистентность при restart
- [ ] Sandbox mode: все методы работают в sandbox

## 7. Безопасность

- [ ] Нет plaintext секретов в коде
- [ ] CSRF на всех мутирующих endpoints (trading, circuit-breaker, tax)
- [ ] JWT авторизация на всех endpoints
- [ ] Нет SQL injection (все запросы через ORM / параметризованные)
- [ ] Rate limiting на торговых endpoints (10 req/min по ФТ)
- [ ] Аудит-лог: ордера, CB срабатывания записываются

# Ревью: Frontend

## 8. Trading UI (components/trading/)

Проверить:
- [ ] PAPER = жёлтый, REAL = красный — единообразно
- [ ] P&L форматирование: зелёный/красный, `Intl.NumberFormat('ru-RU')`, ₽
- [ ] LaunchSessionModal: валидация, confirm для Real
- [ ] WebSocket: подписка при монтировании, отписка при unmount (нет утечек)
- [ ] Маркеры сделок на графике
- [ ] Responsive: минимум 1280px

## 9. Account UI (components/account/)

Проверить:
- [ ] Balance cards: 3 карточки, корректное форматирование
- [ ] Tax report: скачивание работает (blob → download)
- [ ] FavoritesPanel: добавление/удаление, клик переключает график
- [ ] DateRangePicker: корректная работа

## 10. State Management

Проверить:
- [ ] tradingStore: WS updates не вызывают лишних ре-рендеров
- [ ] accountStore: корректный error handling
- [ ] Нет memory leaks (WS отписка, cleanup)

# E2E тесты (Playwright)

Создать файлы в `frontend/e2e/` или `tests/e2e/`:

## E2E-1: Paper Trading Flow
```
1. Login
2. Открыть /trading
3. Нажать «Запустить сессию»
4. Заполнить форму: стратегия, тикер SBER, Paper, 1 000 000 ₽
5. Нажать «Запустить»
6. Проверить: карточка сессии появилась, PAPER жёлтый
7. Перейти в детали сессии
8. Проверить: позиции, P&L отображаются
```

## E2E-2: Circuit Breaker
```
1. Login
2. Настроить CB: daily loss limit = 1%
3. Запустить Paper сессию
4. Имитировать убыточные сделки (через API)
5. Проверить: сессия на паузе, уведомление показано
```

## E2E-3: Account Screen
```
1. Login (с подключённым брокером)
2. Открыть /account
3. Проверить: баланс отображается, 3 карточки
4. Проверить: позиции в таблице
5. Нажать «Налоговый отчёт»
6. Заполнить форму, скачать
7. Проверить: файл скачался
```

## E2E-4: Favorites Panel
```
1. Login
2. Открыть график (/chart)
3. Нажать ★ → открыть панель избранных
4. Добавить SBER
5. Проверить: SBER в списке с статистикой
6. Кликнуть SBER → график переключился
```

# Миграции

```bash
# Проверить, что все миграции корректны
alembic upgrade head   # применить
alembic downgrade -1   # откатить последнюю
alembic upgrade head   # применить заново
# Не должно быть ошибок
```

# Производительность

- [ ] Trading Engine: candle → order < 500ms (профилирование)
- [ ] API responses: < 200ms для GET endpoints
- [ ] WebSocket: < 100ms latency для real-time обновлений
- [ ] Frontend: FCP < 2s, bundle size не вырос более чем на 20%

# Выходной артефакт

Файл: `Test/Спринты/Sprint_5/arch_review_s5.md`

Формат:
```markdown
# Архитектурное ревью Sprint 5

## Сводка
- Статус: PASS / PASS WITH NOTES / FAIL
- Тесты: N backend + M frontend + K E2E
- Критические замечания: N

## Детали по модулям
(каждый чеклист-пункт с ✅ / ⚠️ / ❌)

## Найденные проблемы
(severity: critical / medium / low)

## Рекомендации
(что улучшить в будущих спринтах)
```

# Чеклист

- [ ] Backend ревью: все 7 секций
- [ ] Frontend ревью: все 3 секции
- [ ] E2E тесты: 4 сценария написаны и пройдены
- [ ] Миграции: up + down + up
- [ ] Производительность: latency проверена
- [ ] arch_review_s5.md создан
- [ ] Критические проблемы: 0
