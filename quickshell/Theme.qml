pragma Singleton

import QtQuick

QtObject {
    // Visual palette and spacing inspired by ags/style.css. No AGS dependencies.
    readonly property color surface: "#313244"
    readonly property color base: "#1e1e2e"
    readonly property color muted: "#6c7086"
    readonly property color hover: "#45475a"
    readonly property color border: "#585b70"
    readonly property color text: "#cdd6f4"
    readonly property color subtext: "#a6adc8"
    readonly property color accent: "#cba6f7"
    readonly property color attention: "#f9e2af"
    readonly property color warning: "#fab387"
    readonly property color critical: "#f38ba8"
    readonly property color positive: "#a6e3a1"
    readonly property color running: "#89b4fa"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int iconSize: 18
    readonly property int buttonSize: 28
    readonly property int panelHeight: 44
}
