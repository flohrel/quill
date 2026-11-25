pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property QtObject bar: QtObject {
        readonly property int height: 38
        readonly property string position: "top"
    }
    readonly property QtObject shape: QtObject {
        readonly property int barHeight: 38       // pill height
        readonly property int edgeGap: 8          // gap from screen top edge to pills
        readonly property int pillRadius: 18
        readonly property int pillPaddingH: 12     // horizontal inner padding in a pill
        readonly property int dotSize: 16          // workspace dot
        readonly property int iconSize: 18         // right-pill glyphs
        readonly property int iconSpacing: 16
        readonly property int overlayRadius: 16
        readonly property int overlayMargin: 4     // gap below the bar to a dropdown
        readonly property int overlayPadding: 14   // inner padding of overlay content
        readonly property int animDuration: 130    // overlay open/close, ms
    }
    // Notification center (#12). enabled=false turns quill's daemon off:
    // no NotificationServer, so another daemon can own the name.
    readonly property QtObject notifications: QtObject {
        readonly property bool enabled: true
        readonly property int maxVisible: 5
        readonly property int width: 380
        readonly property int iconSize: 48
        readonly property int maxBodyHeight: 120
        readonly property int spacing: 8
        readonly property int padding: 12
        readonly property int reclaimMaxAttempts: 5
        readonly property int reclaimIntervalMs: 400
        // Popup countdown look (#67): "bar" | "border" | "none". All are
        // first-class options for the future Configuration Center (#28).
        readonly property string countdown: "bar"
    }
    readonly property QtObject workspaceChips: QtObject {
        readonly property int radius: 12
        readonly property int paddingH: 10
        readonly property int paddingV: 4
        readonly property int fontSize: 16
        readonly property int spacing: 8
        readonly property int pillPaddingH: 12   // capsules carry their own padding
        // workspace name -> Nerd Font glyph for named role workspaces
        readonly property var glyphs: ({
            "games": "\u{F1B6}",   // nf-fa-steam
            "web":   "\u{F0AC}",   // nf-fa-globe
            "code":  "\u{F121}"    // nf-fa-code
        })
        // niri appId (lowercase) -> glyph for dynamic workspaces
        readonly property var appGlyphs: ({
            "foot":          "\u{F489}",  // nf-oct-terminal
            "footclient":    "\u{F489}",
            "kitty":         "\u{F489}",
            "alacritty":     "\u{F489}",
            "firefox":       "\u{F269}",  // nf-fa-firefox
            "chromium":      "\u{F268}",  // nf-fa-chrome
            "google-chrome": "\u{F268}",
            "spotify":       "\u{F1BC}"   // nf-fa-spotify
        })
    }
    // Tray click routing (lib/tray.js). All keys lowercase.
    readonly property QtObject tray: QtObject {
        // tray item id -> niri appId, when they differ
        readonly property var aliases: ({
            "spotify-client": "Spotify"
        })
        // appId (lowercase) -> spawn argv for a scratchpad helper, e.g.
        //   "spotify": ["niri-scratchpad", "--size", "70x75", "--pos", "center", "Spotify", "spotify"]
        // Empty by default; mirror your own niri scratchpad binds here.
        readonly property var scratchpads: ({})
        // tray item id -> DBusMenu entry label that reopens a closed-to-tray app
        readonly property var reopenMenu: ({
            "spotify-client": "Show Spotify"
        })
        // tray item ids that keep default behaviour
        readonly property var excluded: []
    }
    readonly property QtObject power: QtObject {
        readonly property int cardSize: 132       // square card edge
        readonly property int cardRadius: 16
        readonly property int gridSpacing: 22      // between cards and between rows
        readonly property int ringWidth: 2         // accent ring on the active card
        readonly property real dimOpacity: 0.60    // backdrop dim over the blur
    }
    readonly property QtObject controlcenter: QtObject {
        readonly property int width: 300
        readonly property int padding: 14
        readonly property int sectionSpacing: 14
        readonly property int toggleSize: 80        // square toggle card
        readonly property int toggleRadius: 12
        readonly property int toggleGap: 10
        readonly property int toggleIconSize: 20
        readonly property int sliderHeight: 28
        readonly property int sliderTrackHeight: 6
        readonly property int sliderIconWidth: 26
        readonly property int sliderIconSize: 15
    }
    readonly property QtObject mixer: QtObject {   // Control Center mixer page (#18)
        readonly property int cardPadding: 10
        readonly property int cardRadius: 10
        readonly property int cardGap: 8
        readonly property int iconSize: 22
        readonly property int iconRadius: 6
        readonly property int childLabelWidth: 96
        readonly property int maxVisibleCards: 5   // list scrolls past this
        // Mixer app look (#72): "cards" (two-line cards, default) |
        // "rows" (MacMix-style single lines). Edit + reload to switch.
        readonly property string layout: "cards"
    }
    readonly property QtObject wifi: QtObject {
        readonly property int popupWidth: 330
        readonly property int padding: 16
        readonly property int listHeight: 220   // ~5-6 rows, then scroll
        readonly property int sectionGap: 8
        readonly property int gearHitSize: 26
        readonly property int detailAnimDuration: 180
    }
    readonly property QtObject vpn: QtObject {
        readonly property var backends: ["NetworkManagerBackend"]  // file basenames in services/vpn/
        readonly property int switchTimeoutMs: 25000               // spec call 8; > nmWaitSeconds so a slow `down` finishes first
        readonly property int nmWaitSeconds: 20                    // nmcli --wait bound
        readonly property int refreshDebounceMs: 300
    }
    readonly property QtObject bluetooth: QtObject {
        readonly property int popupWidth: 330
        readonly property int padding: 16
        readonly property int listHeight: 220   // ~5-6 rows, then scroll
        readonly property int sectionGap: 8
        readonly property int chevronHitSize: 26
        readonly property int expandAnimDuration: 150
    }
    readonly property QtObject battery: QtObject {
        readonly property int popupWidth: 330
        readonly property int padding: 16
        readonly property int sectionGap: 8
        readonly property int profileAnimDuration: 200   // page-2 slide, ms
        readonly property int lowThreshold: 20           // % low-battery warning
    }
    readonly property QtObject intervals: QtObject {
        readonly property int brightness: 2000
        readonly property int clock: 1000
    }
    readonly property var modules: ({
        "calendar": true, "powerMenu": true, "media": true, "sliders": true,
        "quickToggles": true, "notifications": true, "powerProfile": true,
        "weather": true
    })
}
