import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// hyprgrid - GNOME-style application grid for Hyprland, built with Quickshell.
// Runs as a daemon; toggle it with:
//   quickshell ipc -p ~/.config/quickshell/hyprgrid/Main.qml call hyprgrid toggle
ShellRoot {
    id: root

    property bool menuVisible: false

    IpcHandler {
        target: "hyprgrid"
        function toggle(): void { root.menuVisible = !root.menuVisible }
        function open(): void { root.menuVisible = true }
        function close(): void { root.menuVisible = false }
    }

    // Open on the monitor Hyprland currently has focused
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
        visible: root.menuVisible
        screen: root.pickScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprgrid"
        WlrLayershell.keyboardFocus: root.menuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        AppGrid {
            anchors.fill: parent
            shown: root.menuVisible
            onRequestClose: root.menuVisible = false
        }
    }
}
