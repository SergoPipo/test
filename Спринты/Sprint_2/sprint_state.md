# Состояние Спринта 2

> **Этот файл — точка входа для продолжения работы.**
> Обновляется автоматически после каждого шага.
> Последнее обновление: _ещё не начат_

---

## Текущий статус: ⬜ НЕ НАЧАТ

## Следующее действие

```
СЛЕДУЮЩЕЕ ДЕЙСТВИЕ: Выполнить PREFLIGHT
ФАЙЛ: preflight_checklist.md
```

## Прогресс по шагам

| Шаг | Агент | Статус | Ветка / артефакт | Примечания |
|-----|-------|--------|------------------|------------|
| 0 | PREFLIGHT | ⬜ ожидает | — | Проверка окружения |
| 1 | UX | ⬜ ожидает | → ui_spec_s2.md | Дизайн графиков, настроек, footer |
| 2 | DEV-1 (broker) | ⬜ ожидает | → s2/broker-adapter | T-Invest adapter |
| 3 | DEV-2 (moex_iss) | ⬜ ожидает | → s2/moex-iss | MOEX ISS + Calendar |
| 4 | DEV-3 (crypto) | ⬜ ожидает | → s2/crypto-service | CryptoService AES-256-GCM |
| М1 | МЕРЖ волны 1 | ⬜ ожидает | → develop | pytest = 0 failures |
| 5 | DEV-4 (market_data) | ⬜ ожидает | → s2/market-data | Market Data Service |
| М2 | МЕРЖ волны 2 | ⬜ ожидает | → develop | pytest = 0 failures |
| 6 | DEV-5 (charts) | ⬜ ожидает | → s2/charts | TradingView LW Charts + footer |
| 7 | DEV-6 (broker_settings) | ⬜ ожидает | → s2/broker-settings | Broker settings UI |
| М3 | МЕРЖ волны 3 | ⬜ ожидает | → develop | all tests = 0 failures |
| 8 | QA | ⬜ ожидает | — | Тест-кейсы + ручное тестирование |
| 9 | ARCH ревью | ⬜ ожидает | — | Техревью всего кода S2 |
| 10 | Ревью заказчика | ⬜ ожидает | — | Ваши замечания |
| 11 | Отчёт | ⬜ ожидает | — | sprint_report.md |

## Решения заказчика

| # | Решение | Контекст | Влияет на |
|---|---------|----------|-----------|
| — | — | — | — |

## Ветки

```
develop (S1 завершён, 68 тестов)
├── s2/broker-adapter      (DEV-1, волна 1)
├── s2/moex-iss            (DEV-2, волна 1)
├── s2/crypto-service      (DEV-3, волна 1)
├── s2/market-data         (DEV-4, волна 2)
├── s2/charts              (DEV-5, волна 3)
├── s2/broker-settings     (DEV-6, волна 3)
└── s2/arch-fixes          (ARCH, если нужно)
```
