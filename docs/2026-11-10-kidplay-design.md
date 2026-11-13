# KidPlay — Design Spec

macOS-only детский «развлекательный лок»: перехватывает ввод, рисует Ink Flow-эффекты, выходит по паролю или Touch ID после 10 с простоя.

## Goals

- Ребёнок может жать клавиши и водить трекпадом без риска отправить сообщение или сменить настройки.
- Визуально приятная игрушка (Ink Flow): чернила, крупные буквы, мягкие звуки.
- Родитель выходит комбинацией (пароль сессии) или Touch ID, только после 10 с без действий.
- Пароль сравнивается независимо от раскладки (`gfhjkm` ≡ `пароль`).

## Non-goals (MVP)

- Windows / Linux / кроссплатформенный порт.
- Сохранение пароля, профили, настройки темы.
- MDM / supervised kiosk / гарантия блокировки hardware power button.
- CI deploy, semantic-release, карточка на Site.

## Stack

- Swift + AppKit kiosk window + CGEventTap (`InputGuard`).
- Visuals: Metal или SpriteKit для Ink Flow.
- Touch ID: `LocalAuthentication`.
- Location: `KidPlay/` в monorepo `pets`, **не** в `Pets.sln`.

## Architecture

```
Setup → PlayMode (fullscreen) → InputGuard (CGEventTap)
                              → IdleGate (10s) + breathing dot
                              → PasswordMatcher / Touch ID → Quit
                              → InkFlow + Audio
```

### Modules

| Module | Responsibility |
|--------|----------------|
| Setup | Session password (RAM only); Accessibility permission gate |
| InputGuard | System event tap; swallow keys/trackpad/media where possible; feed events to play/matcher |
| IdleGate | Reset on any activity; after 10s idle → unlock armed |
| PasswordMatcher | Layout-agnostic match via physical key codes / QWERTY↔ЙЦУКЕН map |
| InkFlow | Near-black canvas, ink blooms from pointer, flying letters on key |
| Audio | Soft key sounds (throttled); quieter trackpad cues |
| AuthExit | When armed: password buffer match or Touch ID → tear down tap and quit |

## Flows

### Launch

1. Setup window: enter session password → Start.
2. If Accessibility missing: prompt with link to System Settings; block Play until granted.
3. Enter Play: borderless fullscreen on available displays, install event tap, hide chrome.

### Play

- Key / trackpad → visual + optional sound; reset IdleGate; clear password buffer.
- Breathing dot (corner): dim while active → breathe during idle → steady glow at 10s (armed).
- No on-screen password hints in Play.

### Unlock

- Only when IdleGate armed:
  - Typed sequence matches session password (layout-agnostic, contiguous after arm) → exit.
  - Or successful Touch ID → exit.
- Failed password / declined Touch ID → disarm; require another 10s idle.
- Exit: remove tap, close windows, terminate.

## Visual / UX

- Style: **Ink Flow** — near-black, low-opacity ink waves, thin large letters, minimal noise.
- Idle indicator: **breathing dot** (subtle, corner).
- Letters for display may use current layout glyph; matching uses key identity, not glyph.

## Password matching

- At Setup, store password as sequence of layout-independent key identities (or normalize both sides through the same map).
- During unlock, append key identities to a buffer only while armed; compare prefix/exact to stored sequence.
- Non-character keys (modifiers alone, arrows, etc.) reset or ignore per matcher rules (ignore pure modifiers; other keys reset buffer).

## Known limitations

- Some firmware-level controls (power button, certain brightness/volume paths) may bypass user-space taps.
- Force Quit / another user session are out of scope.
- Document gaps in `KidPlay/README.md`.

## Project layout

```
KidPlay/
  Sources/KidPlay/
    App/
    Setup/
    Guard/
    Play/
    Audio/
    Auth/
  Resources/
  README.md
```

## Success criteria

- With Accessibility granted, typing/trackpad in Play does not reach other apps for ordinary keyboard/mouse/media events the tap can see.
- Ink + letters + soft sounds respond to input.
- Exit only after 10s idle + correct password (layout-independent) or Touch ID.
- App builds and runs on the developer MacBook (Apple Silicon).
