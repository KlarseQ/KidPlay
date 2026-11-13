## KidPlay

macOS-only full-screen kid-lock play mode (Swift / AppKit / SpriteKit).

### Preferences

- Exit is **Touch ID only** (no session password).
- Do not re-prompt Accessibility / Input Monitoring on every Start — only from an explicit **«Разрешения…»** UI action.
- No Windows/Linux port for now.

### Facts

- Repo root: `~/KidPlay` (sibling of `pets` / `linkshot`, not inside the pets monorepo).
- Unlock offer after **30 s** idle → Touch ID; each offer **fully resets** unlock state (cancel prior LAContext / hold / epoch) so exit cannot get stuck.
- Alternate exit: small **⏏** control by the corner indicator — **hold 10 s**.
- Intercept media / brightness / volume (and similar) keys while locked when a swallowing `CGEventTap` is available.
- Launch / install: `./scripts/run-app.sh` updates `~/Applications/KidPlay.app` **in place** (do not delete/recreate the bundle) for stable TCC.
- Desktop alias: `~/Desktop/KidPlay` → `~/Applications/KidPlay.app`.
