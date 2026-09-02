import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// hyprclip - a small floating clipboard history panel (cliphist front-end).
// Runs as a daemon; toggle with:
//   quickshell ipc -p ~/.config/quickshell/hyprclip/Main.qml call hyprclip toggle
ShellRoot {
    id: root

    property bool panelVisible: false

    IpcHandler {
        target: "hyprclip"
        function toggle(): void { root.panelVisible = !root.panelVisible }
        function open(): void { root.panelVisible = true }
        function close(): void { root.panelVisible = false }
    }

    readonly property var focusedMon: Hyprland.focusedMonitor
    function pickScreen() {
        const name = root.focusedMon ? root.focusedMon.name : "";
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    // Full-screen transparent layer so a click outside the card closes it.
    // Only the card has alpha, so Hyprland's blur (ignore_alpha) applies to it alone.
    PanelWindow {
        id: win
        visible: root.panelVisible
        screen: root.pickScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprclip"
        WlrLayershell.keyboardFocus: root.panelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        ClipPanel {
            anchors.fill: parent
            shown: root.panelVisible
            monX: root.focusedMon ? root.focusedMon.x : 0
            monY: root.focusedMon ? root.focusedMon.y : 0
            monScale: root.focusedMon && root.focusedMon.scale > 0 ? root.focusedMon.scale : 1
            onRequestClose: root.panelVisible = false
        }
    }
}
