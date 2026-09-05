import QtQuick
import Quickshell
import Quickshell.Io

FocusScope {
    id: panel

    property bool shown: false
    property var state: null
    signal requestClose()

    readonly property bool pt: String(Quickshell.env("LANG") || "").toLowerCase().indexOf("pt") === 0
    readonly property var tr: pt
        ? { title: "Gravador", replay: "Replay dos últimos", secs: "s", replayOff: "desligado", replayOn: "armado",
            rec: "Gravar tela", stop: "Parar gravação", area: "Gravar área", clip: "Salvar últimos", folder: "Abrir pasta",
            last: "Último arquivo", none: "nenhum ainda", hint: "R grava  ·  C salva clipe  ·  A área  ·  Esc fecha", needReplay: "ligue o replay para salvar clipes" }
        : { title: "Recorder", replay: "Replay of the last", secs: "s", replayOff: "off", replayOn: "armed",
            rec: "Record screen", stop: "Stop recording", area: "Record area", clip: "Save last", folder: "Open folder",
            last: "Last file", none: "nothing yet", hint: "R record  ·  C save clip  ·  A area  ·  Esc close", needReplay: "turn replay on to save clips" }

    readonly property real sc: Math.max(0.6, Math.pow(width / 1920, 0.85))
    function s(v) { return Math.round(v * sc) }

    // ---- open at the cursor (same approach as hyprclip) ----
    property real monX: 0
    property real monY: 0
    property real monScale: 1
    property real cursorX: -1
    property real cursorY: -1
    Process {
        id: cursorQuery
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const o = JSON.parse(String(text)); panel.cursorX = (o.x - panel.monX) / panel.monScale; panel.cursorY = (o.y - panel.monY) / panel.monScale; }
                catch (e) { panel.cursorX = -1; panel.cursorY = -1; }
            }
        }
    }

    function run(args) { if (state) state.run(args) }
    function toggleReplay() { run(["replay", "toggle"]) }
    function toggleRecord() { run(["record", "toggle"]) }
    function recordArea() { panel.requestClose(); run(["record", "region"]) }
    function saveClip() { if (state && state.replayOn) run(["clip"]) }
    function openFolder() { run(["open"]); panel.requestClose() }

    onShownChanged: {
        if (shown) { cursorQuery.running = false; cursorQuery.running = true; if (state) state.refresh(); panel.forceActiveFocus(); }
    }

    Keys.onPressed: (ev) => {
        switch (ev.key) {
        case Qt.Key_Escape: panel.requestClose(); ev.accepted = true; break;
        case Qt.Key_R: panel.toggleRecord(); ev.accepted = true; break;
        case Qt.Key_C: panel.saveClip(); ev.accepted = true; break;
        case Qt.Key_A: panel.recordArea(); ev.accepted = true; break;
        case Qt.Key_Space: panel.toggleReplay(); ev.accepted = true; break;
        }
    }

    MouseArea { anchors.fill: parent; onClicked: panel.requestClose() }

    Rectangle {
        id: card
        width: panel.s(360)
        height: col.implicitHeight + panel.s(28)
        readonly property real margin: panel.s(12)
        x: {
            if (panel.cursorX < 0) return (panel.width - width) / 2;
            let px = panel.cursorX + panel.s(4);
            if (px + width + margin > panel.width) px = panel.cursorX - width - panel.s(4);
            return Math.max(margin, Math.min(panel.width - width - margin, px));
        }
        y: {
            if (panel.cursorY < 0) return (panel.height - height) / 2;
            let py = panel.cursorY + panel.s(4);
            if (py + height + margin > panel.height) py = panel.cursorY - height - panel.s(4);
            return Math.max(margin, Math.min(panel.height - height - margin, py));
        }
        radius: panel.s(18)
        color: Qt.rgba(0.09, 0.09, 0.11, 0.88)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        opacity: panel.shown ? 1 : 0
        scale: panel.shown ? 1 : 0.96
        transformOrigin: Item.TopLeft
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: {} }

        component Btn: Rectangle {
            property string label: ""
            property string icon: ""
            property bool primary: false
            property bool danger: false
            property bool enabledBtn: true
            signal clicked()
            width: parent.width; height: panel.s(44); radius: panel.s(12)
            opacity: enabledBtn ? 1 : 0.4
            color: danger ? Qt.rgba(0.85, 0.23, 0.19, ma.containsMouse ? 1 : 0.9)
                 : primary ? Qt.rgba(1, 1, 1, ma.containsMouse ? 1.0 : 0.92)
                 : Qt.rgba(1, 1, 1, ma.containsMouse ? 0.16 : 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
                anchors.left: parent.left; anchors.leftMargin: panel.s(16); anchors.verticalCenter: parent.verticalCenter
                spacing: panel.s(10)
                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.icon; color: parent.parent.primary ? "#1a1a1a" : "white"; font.pixelSize: panel.s(15) }
                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.label; color: parent.parent.primary ? "#1a1a1a" : "white"; font.pixelSize: panel.s(14); font.bold: parent.parent.primary || parent.parent.danger }
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: parent.enabledBtn; onClicked: parent.clicked() }
        }

        Column {
            id: col
            x: panel.s(14); y: panel.s(14)
            width: parent.width - panel.s(28)
            spacing: panel.s(8)

            // header
            Item {
                width: parent.width; height: panel.s(30)
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: panel.tr.title; color: "white"; font.pixelSize: panel.s(15); font.bold: true }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: panel.s(6)
                    visible: panel.state && panel.state.recording
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: panel.s(8); height: panel.s(8); radius: width / 2; color: "#ff3b30" }
                    Text { text: "REC"; color: "#ff3b30"; font.pixelSize: panel.s(11); font.bold: true }
                }
            }

            // replay toggle row
            Rectangle {
                width: parent.width; height: panel.s(52); radius: panel.s(12)
                color: Qt.rgba(1, 1, 1, 0.06)
                Column {
                    anchors.left: parent.left; anchors.leftMargin: panel.s(14); anchors.verticalCenter: parent.verticalCenter
                    spacing: panel.s(2)
                    Text { text: panel.tr.replay + " " + (panel.state ? panel.state.replaySeconds : 30) + " " + panel.tr.secs; color: "white"; font.pixelSize: panel.s(13) }
                    Text { text: panel.state && panel.state.replayOn ? panel.tr.replayOn + (panel.state.monitor ? "  ·  " + panel.state.monitor : "") : panel.tr.replayOff; color: panel.state && panel.state.replayOn ? "#7bd88f" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: panel.s(11) }
                }
                // switch
                Rectangle {
                    id: sw
                    anchors.right: parent.right; anchors.rightMargin: panel.s(14); anchors.verticalCenter: parent.verticalCenter
                    readonly property bool on: panel.state && panel.state.replayOn
                    width: panel.s(44); height: panel.s(24); radius: height / 2
                    color: on ? "#4cd964" : Qt.rgba(1, 1, 1, 0.18)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle {
                        width: panel.s(20); height: panel.s(20); radius: width / 2; y: panel.s(2)
                        x: sw.on ? sw.width - width - panel.s(2) : panel.s(2)
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: panel.toggleReplay() }
                }
            }

            Btn {
                readonly property bool rec: panel.state && panel.state.recording
                icon: rec ? "■" : "●"; label: rec ? panel.tr.stop : panel.tr.rec
                danger: rec; primary: !rec
                onClicked: panel.toggleRecord()
            }
            Btn { icon: "⬚"; label: panel.tr.area; enabledBtn: !(panel.state && panel.state.recording); onClicked: panel.recordArea() }
            Btn {
                icon: "⟲"; label: panel.tr.clip + " " + (panel.state ? panel.state.replaySeconds : 30) + " " + panel.tr.secs
                enabledBtn: panel.state && panel.state.replayOn
                onClicked: panel.saveClip()
            }

            // footer: last saved + open folder
            Item {
                width: parent.width; height: panel.s(34)
                Column {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: panel.s(1)
                    width: parent.width - folderBtn.width - panel.s(10)
                    Text { text: panel.tr.last; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: panel.s(10) }
                    Text {
                        width: parent.width
                        text: panel.state && panel.state.lastSaved !== "" ? String(panel.state.lastSaved).split("/").pop() : panel.tr.none
                        color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: panel.s(11); elide: Text.ElideMiddle
                    }
                }
                Rectangle {
                    id: folderBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: fbt.implicitWidth + panel.s(20); height: panel.s(28); radius: height / 2
                    color: Qt.rgba(1, 1, 1, fma.containsMouse ? 0.18 : 0.08)
                    Text { id: fbt; anchors.centerIn: parent; text: panel.tr.folder; color: "white"; font.pixelSize: panel.s(11) }
                    MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; onClicked: panel.openFolder() }
                }
            }
            Text {
                width: parent.width
                text: panel.state && !panel.state.replayOn ? panel.tr.needReplay + "  ·  " + panel.tr.hint : panel.tr.hint
                color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: panel.s(10); wrapMode: Text.Wrap
            }
        }
    }
}
