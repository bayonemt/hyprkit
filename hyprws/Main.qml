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

    readonly property var focusedMon: Hyprland.focusedMonitor
    function pickScreen() {
        const name = root.focusedMon ? root.focusedMon.name : "";
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    PanelWindow {
        id: win
        visible: root.overviewVisible
        screen: root.pickScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprws"
        WlrLayershell.keyboardFocus: root.overviewVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Overview {
            anchors.fill: parent
            shown: root.overviewVisible
            monitorName: root.focusedMon ? root.focusedMon.name : ""
            onRequestClose: root.overviewVisible = false
        }
    }
}
