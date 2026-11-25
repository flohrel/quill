# quill — Quickshell status bar for Niri

QtQuick/QML status bar (Quickshell 0.3.2) for the Niri compositor. Root is
`shell.qml` (one `Bar` per screen). Personal, machine-specific notes go in a
git-ignored `CLAUDE.local.md` next to this file.

## Layout

- `bar/` — `Bar.qml` (the panel), `OverlayController.qml` (popup open/dismiss
  state), `pills/` (bar widgets), `overlays/` (popups: wifi, bluetooth,
  battery, power, …), `notifications/` (popup cards).
- `services/` — singleton services (`NetworkService`, `BluetoothService`,
  `BatteryService`, …) plus pure-logic `.js` helpers (`nmcli.js`,
  `bluetooth.js`, `power.js`, `mixer.js`, `notifications.js`) that the tests
  exercise directly.
- `config/` — `Theme.qml`, `GruvboxMaterial.qml` palette, `Config.qml`.
- `lib/format.js` — shared formatting helpers.
- `tests/` — QtTest suites (`tst_*.qml`). Logic lives in the pure QML/JS
  layer precisely so these run without Quickshell or a compositor.
- `vendor/qml-niri` — C++ QML plugin for Niri IPC (git submodule). Build with
  `make plugin` (emits `build/qml/Niri`); `quill-launch.sh` puts `build/qml`
  on `QML_IMPORT_PATH`. `services/NiriService.qml` is the ONLY file that may
  `import Niri` — keep the backend swappable behind it.

## Workflow

- Branch names: `feat/<issue#>-slug`, `fix/<issue#>-slug`.
- Every change lands through a PR whose body includes `Closes #<issue>`.

## Run, test, lint

- Launch: `./quill-launch.sh` (wraps `qs -c <repo>`). Never let a stale copy of the
  `qs.*` source modules exist under `build/qml/qs` — it silently shadows the
  live source (the launch script deletes it).
- Tests: `make test` (all suites, aggregated exit code — a single failing
  suite fails the run). One suite: `make test TESTS=tests/tst_network.qml`.
- Lint: `make lint` (all tracked QML) or `make lint-file FILE=<file>` (what
  the PostToolUse hook runs on every QML edit). Policy: qmllint errors fail;
  the large `[unqualified]` warning baseline from `qs.*` singleton imports
  does not. Qt tools are auto-detected; override with `QT_BIN=`.
- qmlls lives in the Qt6 bin dir (`$QT_BIN/qmlls`); use
  `import qs.services`-style imports so it resolves, and
  `// qmllint disable import` for its known qs.* import false positive.

## Live testing — hot-reload is not trustworthy

Quickshell hot-reloads on file writes but can miss rapid write sequences
(observed: `git stash` reloaded old code, `git stash pop` triggered no second
reload — the live scene ran stale code while disk held the fix). Before any
live checkpoint:

1. Don't mutate the working tree (stash/pop, checkout) while someone is
   live-testing.
2. Restart outright: `kill $(pgrep -x qs); setsid ./quill-launch.sh`.
3. Confirm which code is live via a line-number signature of a known warning
   in `qs log` (pre-existing warnings move with edits above them).

## Live-testing safety protocol (lockup prevention)

A keyboard-exclusive or fullscreen surface with a bug can lock the whole
session. Two rails:

1. **Fused launcher — MANDATORY for risky checkpoints.** Any live checkpoint
   that touches keyboard-exclusive focus, fullscreen/top-layer surfaces, or
   input grabs MUST use `./quill-test.sh [seconds]` (default 120) instead of
   `quill-launch.sh`. It auto-kills qs when the fuse expires unless disarmed
   with ENTER in the launching terminal. Worst case is a short wait, never a
   reboot. (It needs an attached terminal: from a non-interactive session,
   `timeout N ./quill-launch.sh` is the bounded equivalent.)
2. **Panic bind (recommended).** A niri bind that kills qs at the compositor
   level bypasses client grabs, e.g.
   `Mod+Shift+Escape { spawn "pkill" "-x" "qs"; }`. Verify it once before a
   risky checkpoint.

## QML conventions (hard-won)

- **Nerd Font PUA glyphs: write `\u{...}` escapes in `.qml`, never literal
  characters.** Some editing tools silently drop literal PUA chars, producing
  `text: ""` that passes qmllint and tests and only surfaces as an invisible
  icon in the live GUI. After adding a glyph, grep for empty `text: ""` and
  verify it renders.
- Radio-style NM properties bounce: NetworkManager re-emits a stale
  `WirelessEnabled: false` ~1 ms before the `true` when enabling the radio,
  so `Networking.wifiEnabled` blinks true→false→true. Don't bind UI straight
  to `Networking.*` during a local toggle — latch through
  `services/RadioLatch.qml` (see `tests/tst_radio_latch.qml`).
- Bluetooth pairing: Quickshell 0.3.x (checked 0.3.2) has no BlueZ `Agent1`, so native
  `pair()` creates keyless bonds that fail A2DP with
  `br-connection-key-missing`. `BluetoothService.pair()` shells out to a
  one-shot `bluetoothctl --timeout 30 pair`, then sets `trusted = true` and
  connects. Re-resolve the device by address after pairing.
- Idle inhibition (caffeine): native `Quickshell.Wayland.IdleInhibitor`
  anchored to the bar PanelWindow, bound to `CaffeineService.active`. Niri
  inhibits `ext-idle-notify-v1` for any scanned-out inhibiting surface, which
  pauses idle daemons like swayidle. Don't reintroduce process-signal hacks.
- PipeWire properties need a `PwObjectTracker` to be valid; prefer
  `MouseArea { hoverEnabled: true }` over `WheelHandler` for layer-shell
  scroll events.
- Per-app mixer: `MixerService` groups PipeWire playback streams by
  `application.process.binary` via pure `services/mixer.js`; group order is
  first-seen, kept in a mutated-in-place `_state` (never reassign it —
  binding loop). UI binds only to `MixerService`. `groups` is a fresh array
  on every volume change, so list models use a key-signature string, not
  the array (a new array recreates delegates and kills an in-progress drag).
- Mixer look: `Config.mixer.layout` `"cards"` (default) | `"rows"`;
  `MixerPage` picks `AppCard`/`AppRow` per entry through a `Loader`, both
  with the same `group`/`expanded`/`toggleExpanded` interface. Dragging any
  slider unmutes it — that lives in the service setters
  (`MixerService.setStreamVolume`, `AudioService.setVolume`), not the views.
- `//@ pragma UseQApplication` (needed for DBusMenu/tray menus) requires a
  full qs process restart, not a hot reload.
- Airplane mode: `AirplaneService` exposes `qs ipc call airplane toggle`;
  bind it to a key in niri.
- Notifications: quill takes `org.freedesktop.Notifications` when the name
  is free. If another daemon owns it, quill logs a warning and leaves it
  alone (`N.reclaimAction` never kills anything).
  `Config.notifications.enabled: false` + a full qs restart turns quill's
  daemon off. A duplicate notification re-points the existing card's
  `popupModel` row (`N.takeoverOps`) instead of remove + insert, so the card
  survives the bump.
- Popup countdown: `Config.notifications.countdown` is `"bar"` |
  `"border"` | `"none"`. Competing looks ship as Config options, not
  A/B-then-delete. The indicator components
  (`bar/notifications/Countdown*.qml`) stay pure QtQuick so
  `tests/tst_countdown.qml` can load them.
- Mutating a binding's inputs from its own `onChanged` handler → "Binding
  loop detected" and the update is silently dropped; defer with
  `Qt.callLater`.
