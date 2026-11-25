import QtQuick
import QtTest
import "../config" as Cfg

TestCase {
    name: "gruvbox"
    Cfg.GruvboxMaterial { id: g }

    function test_core_roles_are_gruvbox_material_dark() {
        compare(g.background.toString(), "#1d2021")
        compare(g.foreground.toString(), "#d4be98")
        compare(g.accent.toString(), "#7daea3")
        compare(g.urgent.toString(), "#ea6962")
    }
}
