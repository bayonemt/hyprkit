import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// hyprnote - a notebook overlay for Hyprland, built with Quickshell.
// Runs as a daemon; toggle it with:
//   quickshell ipc -p ~/.config/quickshell/hyprnote/Main.qml call hyprnote toggle
ShellRoot {
    id: root

    property bool bookVisible: false

    IpcHandler {
        target: "hyprnote"
        function toggle(): void { root.bookVisible = !root.bookVisible }
        function open(): void { root.bookVisible = true }
        function close(): void { root.bookVisible = false }
        function newPage(): void { nb.newPage() }
        function save(): void { nb.saveAll() }
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
        visible: root.bookVisible
        screen: root.pickScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprnote"
        WlrLayershell.keyboardFocus: root.bookVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Notebook {
            id: nb
            anchors.fill: parent
            shown: root.bookVisible
            onRequestClose: root.bookVisible = false
        }
    }
}
