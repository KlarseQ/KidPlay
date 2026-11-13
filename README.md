# KidPlay

macOS-only «детский режим»: полноэкранный kiosk, системный перехват ввода, Ink Flow-эффекты.

Выход: **Touch ID** после **30 с** тишины, либо зажми **⏏** у индикатора на **10 с**. Индикатор — часы-таймер, кольцо заполняется за 30 с. Чернила и буквы живут **15 с**, затем уходят. При запуске приложение само проверяет [Releases](https://github.com/KlarseQ/KidPlay/releases) и ставит новую версию.

## Установка для друга (без Xcode)

1. Скачай **KidPlay-*-macos.zip** из [Releases](https://github.com/KlarseQ/KidPlay/releases).
2. Распакуй → перетащи `KidPlay.app` в **Программы** (или `~/Applications`).
3. Первый запуск: **ПКМ по приложению → Открыть** (обход Gatekeeper для неподписанной сборки).
4. В **Системные настройки → Конфиденциальность и безопасность** выдай KidPlay:
   - **Универсальный доступ** (Accessibility)
   - **Мониторинг ввода** (Input Monitoring)
5. Полностью закрой приложение и открой снова.

Дальше можно держать ярлык на рабочем столе.

## Сборка из исходников

macOS 13+, Xcode / Swift 5.9+.

```bash
./scripts/run-app.sh
```

Скрипт обновляет `~/Applications/KidPlay.app` **на месте** (не удаляет бандл — так стабильнее TCC).

Релизный zip:

```bash
./scripts/package-release.sh 1.0.0
```

## Как пользоваться

1. **Старт** (после выдачи Accessibility + Input Monitoring).
2. Ребёнок жмёт клавиши / водит трекпадом — чернила и буквы.
3. В углу: часы (30 с до Touch ID) и **⏏** (удержание 10 с = выход).
4. Каждое предложение выхода сбрасывает unlock-состояние заново.
5. Отмена Touch ID → снова ждать 30 с тишины.

## Известные ограничения

- Кнопка питания и часть firmware-медиа/яркости могут обходить user-space event tap.
- Системные трекпад-жесты иногда пробиваются.
- Force Quit / жёсткий power — вне scope.
- Это не MDM-киоск.
- Windows / Linux не поддерживаются.

## Структура

```
Sources/KidPlay/
  App/     — lifecycle
  Setup/   — старт + Accessibility
  Guard/   — CGEventTap, IdleGate
  Play/    — kiosk, SpriteKit Ink Flow, unlock corner (clock + hold)
  Audio/   — мягкие системные звуки
  Auth/    — Touch ID
```
