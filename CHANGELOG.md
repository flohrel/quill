# Changelog

## v1.0 — first public release

What you get in quill v1.0, a Quickshell status bar and desktop shell for
niri.

### Bar
- Three floating pills: niri workspaces (per output, click to switch), a
  centered clock that opens a calendar, and a right pill with status icons.
- Workspace chips with app-aware glyphs for the focused window.
- Click any bar icon to switch straight from one open popup to another;
  click empty bar space or press Esc to dismiss.

### Control center
- Toggles: Wi-Fi, Bluetooth, airplane mode, caffeine (idle inhibitor via
  the Wayland idle-inhibit protocol), do-not-disturb.
- Brightness (udev-driven, no polling) and volume sliders with draggable
  knobs; mic mute.

### Network
- One hub for wired and Wi-Fi: scan, connect with passwords, details,
  settings, forget; signal bars; robust against NetworkManager's
  stale radio-state notifications.
- VPN status and connect/disconnect for NetworkManager VPN profiles, behind
  a pluggable backend interface.
- Airplane mode that remembers which radios you kept on, restores the rest
  when you leave it, and exposes `qs ipc call airplane toggle`.

### Bluetooth
- Device manager popup: pair (with a real bond, so audio profiles work),
  trust, connect, disconnect; disabled look when there is no adapter.

### Power
- Battery popup with stats and a power-profile selector.
- Fullscreen power menu (sleep, restart, shut down, log out) with keyboard
  shortcuts and a blurred-wallpaper backdrop.

### Audio
- Per-app volume mixer in the control center: one card per app with its
  icon, a subtitle with the track or tab title, per-stream sliders, and
  dedicated mute buttons. Dragging a muted slider unmutes it.
- Two layouts: two-line `cards` (default) or MacMix-style `rows`
  (`Config.mixer.layout`).

### Notifications
- quill as the notification daemon: popup cards with app icons, actions and
  a countdown (`bar`, `border` or `none`), paused while hovered.
- Duplicate notifications collapse into one card with a counter, without
  the card flickering.
- Do-not-disturb with a bar indicator and `qs ipc call notifications
  toggleDnd`. If another daemon already owns the notification name, quill
  leaves it alone.

### Tray
- StatusNotifierItem host with themed context menus (including submenus),
  niri-aware left-click (focus or open the app's window).
