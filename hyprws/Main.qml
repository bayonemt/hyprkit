import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// hyprws - workspace overview with drag-and-drop for Hyprland, built with Quickshell.
// Runs as a daemon; toggle with:
//   quickshell ipc -p ~/.config/quickshell/hyprkit/hyprws/Main.qml call hyprws toggle
ShellRoot {
    id: root

    property bool overviewVisible: false

    IpcHandler {
        target: "hyprws"
        function toggle(): void { root.overviewVisible = !root.overviewVisible }
        function open(): void { root.overviewVisible = true }
        function close(): void { root.overviewVisible = false }
    }

    // Drag state shared by every monitor's overlay, in global (layout) coordinates.
    // While the button is held the compositor keeps sending motion to the overlay where
    // the drag started, so that overlay publishes the pointer position here and each
    // overlay hit-tests it against its own cards.
    QtObject {
        id: dragState
        property bool active: false
        property var win: null          // window model being dragged
        property int fromWs: -1
        property real gx: 0             // ghost top-left, global coordinates
        property real gy: 0
        property real gw: 0
        property real gh: 0
        property int targetWs: -1       // workspace id under the pointer, -1 = none
        property string targetMon: ""   // monitor that owns the target card
        property bool targetIsNew: false
        function cancel() { active = false; win = null; fromWs = -1; targetWs = -1; targetMon = ""; targetIsNew = false; }
    }

    // One overlay per monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            visible: root.overviewVisible
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprws"
            WlrLayershell.keyboardFocus: root.overviewVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Overview {
                anchors.fill: parent
                shown: root.overviewVisible
                monitorName: win.modelData.name
                dnd: dragState
                onRequestClose: root.overviewVisible = false
            }
        }
    }
}
