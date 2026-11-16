## KidPlay

macOS-only full-screen kid-lock play mode (Swift / AppKit / SpriteKit).

### Preferences

- Exit is **Touch ID only** (no session password).
- Do not re-prompt Accessibility / Input Monitoring on every Start — only from an explicit **«Разрешения…»** UI action.
- No Windows/Linux port for now.
- Pointer trails and letter effects use **ink/blots**, not bubbles or plain circles.
- Combo / streak HUD should read **vivid and colorful** on each streak.
- Setup checkbox **«использовать цвета»** — when on, on-field symbols are multicolored.

### Facts

- Repo root: `~/KidPlay` (sibling of `pets` / `linkshot`, not inside the pets monorepo).
- Unlock offer after **30 s** idle → Touch ID; each offer **fully resets** unlock state (cancel prior LAContext / hold / epoch) so exit cannot get stuck.
- Alternate exit: small **⏏** control by the corner indicator — **hold 10 s**.
- Unlock-ready affordance is a **gradual timer/clock fill** (green when unlockable).
- Ink / letter residue lifetime **15 s**, then fade off the field.
- Letter keys show their own glyph with RU/EN ± case variants; modifiers show names; digits shown; spawn near keyboard-layout position ± radius (not at the cursor).
- Combo HUD sits below the notch (`safeAreaInsets` + padding).
- Auto-update from GitHub Releases on setup launch (`AppUpdater`, in-place binary swap).
- While locked, swallow media / brightness / volume (and similar) keys so background apps (e.g. browser video) cannot receive them. Start **hard-fails** unless a swallowing `CGEventTap` installs (no listen-only fallback).
- Launch / install: `./scripts/run-app.sh` updates `~/Applications/KidPlay.app` **in place** (do not delete/recreate the bundle) for stable TCC.
- Desktop alias: `~/Desktop/KidPlay` → `~/Applications/KidPlay.app`.
- Open-source: PRs welcome, only owner merges; donate via Telegram `@klarseq`.
