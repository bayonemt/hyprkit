import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// hyprrec - screen recorder and instant replay panel for Hyprland (gpu-screen-recorder front-end).
// Runs as a daemon; toggle the panel with:
//   quickshell ipc -p ~/.config/quickshell/hyprkit/hyprrec/Main.qml call hyprrec toggle
ShellRoot {
    id: root

    property bool panelVisible: false
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/hyprkit/hyprrec/scripts/hyprrec.sh"

    // ---- recorder state (from hyprrec.sh status) ----
    property bool replayOn: false
    property bool recording: false
    property real recordStart: 0
    property int replaySeconds: 30
    property string videosDir: ""
    property string lastSaved: ""
    property string monitor: ""

    Process {
        id: statusProc
        command: [root.scriptPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(String(text));
                    root.replayOn = !!s.replay; root.recording = !!s.recording;
                    root.recordStart = Number(s.start) || 0; root.replaySeconds = Number(s.replaySeconds) || 30;
                    root.videosDir = s.dir || ""; root.lastSaved = s.last || ""; root.monitor = s.monitor || "";
                } catch (e) {}
            }
        }
    }
    function refresh() { statusProc.running = false; statusProc.running = true; }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()

    Process { id: action; property var args: []; command: [root.scriptPath].concat(args); onExited: root.refresh() }
    function run(args) { action.running = false; action.args = args; action.running = true; }

    IpcHandler {
        target: "hyprrec"
        function toggle(): void { root.panelVisible = !root.panelVisible }
        function open(): void { root.panelVisible = true }
        function close(): void { root.panelVisible = false }
        function refresh(): void { root.refresh() }
    }

    readonly property var focusedMon: Hyprland.focusedMonitor
    function pickScreen() {
        const name = root.focusedMon ? root.focusedMon.name : "";
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    // ---- the panel (full-screen transparent layer, card at the cursor) ----
    PanelWindow {
        visible: root.panelVisible
        screen: root.pickScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprrec"
        WlrLayershell.keyboardFocus: root.panelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        RecPanel {
            anchors.fill: parent
            shown: root.panelVisible
            state: root
            monX: root.focusedMon ? root.focusedMon.x : 0
            monY: root.focusedMon ? root.focusedMon.y : 0
            monScale: root.focusedMon && root.focusedMon.scale > 0 ? root.focusedMon.scale : 1
            onRequestClose: root.panelVisible = false
        }
    }

    // ---- recording indicator: small pill at the top of the recorded monitor ----
    PanelWindow {
        id: pill
        visible: root.recording
        screen: root.pickScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true }
        margins { top: 46 }
        implicitWidth: indicator.width
        implicitHeight: indicator.height
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprrec-indicator"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        RecIndicator {
            id: indicator
            state: root
            onStopRequested: root.run(["record", "stop"])
        }
    }
}
