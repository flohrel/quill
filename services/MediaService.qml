pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool hasPlayer: player !== null
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property bool playing: player ? player.isPlaying : false

    function playPause() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next()      { if (player && player.canGoNext) player.next() }
    function previous()  { if (player && player.canGoPrevious) player.previous() }
}
