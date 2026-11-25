pragma Singleton
import Quickshell
import QtQuick

// Event-source seam. Spec 2 (CalDAV + Google, read-only) plugs a provider in
// here; spec 1 returns no events. Event shape (for spec 2): { id, title, start
// (Date), end (Date), allDay (bool), source (string) }.
Singleton {
    id: root
    property bool hasProvider: false
    function eventsFor(startDate, endDate) { return [] }
}
