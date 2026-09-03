import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

FocusScope {
    id: ov

    property bool shown: false
    property string monitorName: ""
    signal requestClose()

    readonly property bool pt: String(Quickshell.env("LANG") || "").toLowerCase().indexOf("pt") === 0
    readonly property var tr: pt
        ? { title: "Áreas de trabalho", newWs: "Nova", hint: "Arraste uma janela para outra área  ·  clique para trocar  ·  botão do meio fecha a janela  ·  1–9 troca  ·  Esc fecha" }
        : { title: "Workspaces", newWs: "New", hint: "Drag a window to another workspace  ·  click to switch  ·  middle-click closes a window  ·  1–9 switch  ·  Esc closes" }

    readonly property real sc: Math.max(0.6, Math.pow(width / 1920, 0.85))
    function s(v) { return Math.round(v * sc) }

    // ---- state from hyprctl ----
    property var mon: null          // { x, y, w, h } logical geometry of this monitor
    property int activeWs: -1
    property var workspaces: []     // [{ id, name, isNew, windows: [{ address, cls, title, x, y, w, h, floating }] }]
    property int selectedWs: 0
    property bool busy: false

    Process {
        id: query
        command: ["bash", "-c", "printf '{\"monitors\":%s,\"workspaces\":%s,\"clients\":%s}' \"$(hyprctl -j monitors)\" \"$(hyprctl -j workspaces)\" \"$(hyprctl -j clients)\""]
        stdout: StdioCollector { onStreamFinished: ov.apply(String(text)) }
    }
    function refresh() { query.running = false; query.running = true; }

    function apply(json) {
        let d;
        try { d = JSON.parse(json); } catch (e) { return; }
        let m = null;
        for (const mm of d.monitors) if (mm.name === ov.monitorName) m = mm;
        if (!m) m = d.monitors.find(mm => mm.focused) || d.monitors[0];
        if (!m) return;
        const scale = m.scale > 0 ? m.scale : 1;
        ov.mon = { x: m.x, y: m.y, w: m.width / scale, h: m.height / scale };
        ov.activeWs = m.activeWorkspace ? m.activeWorkspace.id : -1;

        const list = [];
        let maxId = 0;
        for (const w of d.workspaces) {
            if (w.id <= 0 || w.monitor !== m.name) continue;   // skip special workspaces and other monitors
            list.push({ id: w.id, name: String(w.name), isNew: false, windows: [] });
            maxId = Math.max(maxId, w.id);
        }
        list.sort((a, b) => a.id - b.id);
        for (const c of d.clients) {
            if (!c.mapped || c.hidden || !c.workspace || c.workspace.id <= 0) continue;
            const ws = list.find(w => w.id === c.workspace.id);
            if (!ws) continue;
            ws.windows.push({ address: c.address, cls: c.class, title: c.title,
                              x: c.at[0] - m.x, y: c.at[1] - m.y, w: c.size[0], h: c.size[1],
                              floating: c.floating, fullscreen: c.fullscreen > 0 });
        }
        // floating windows drawn on top
        for (const ws of list) ws.windows.sort((a, b) => (a.floating ? 1 : 0) - (b.floating ? 1 : 0));
        list.push({ id: maxId + 1, name: ov.tr.newWs, isNew: true, windows: [] });
        ov.workspaces = list;
        if (ov.selectedWs >= list.length) ov.selectedWs = list.length - 1;
        ov.busy = false;
    }

    // ---- dispatch through the Lua API (hyprctl dispatch needs Lua syntax on 0.55+) ----
    Process {
        id: disp
        property string code: ""
        command: ["hyprctl", "eval", code]
        onExited: refreshTimer.restart()
    }
    function dispatch(dsp) { disp.running = false; disp.code = "return hl.dispatch(" + dsp + ")"; disp.running = true; }
    function lua(str) { return "\"" + String(str).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""; }

    function switchTo(ws) { ov.dispatch("hl.dsp.focus({ workspace = " + lua(String(ws.id)) + " })"); ov.requestClose(); }
    function focusWindow(address) { ov.dispatch("hl.dsp.focus({ window = " + lua("address:" + address) + " })"); ov.requestClose(); }
    function closeWindow(address) { ov.busy = true; ov.dispatch("hl.dsp.window.close({ window = " + lua("address:" + address) + " })"); }
    function moveWindow(address, wsId) {
        ov.busy = true;
        ov.dispatch("hl.dsp.window.move({ window = " + lua("address:" + address) + ", workspace = " + lua(String(wsId)) + ", follow = false })");
    }

    Timer { id: refreshTimer; interval: 120; onTriggered: ov.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ov.shown) refreshTimer.restart(); }
    }

    // live previews: find the wayland toplevel for a hyprland window address
    function toplevelFor(address) {
        const want = String(address).replace(/^0x/, "").toLowerCase();
        const tls = Hyprland.toplevels.values;
        for (let i = 0; i < tls.length; i++) {
            const a = String(tls[i].address).replace(/^0x/, "").toLowerCase();
            if (a === want) return tls[i].wayland || null;
        }
        return null;
    }

    onShownChanged: {
        if (shown) { ov.selectedWs = 0; refresh(); ov.forceActiveFocus(); }
        else dnd.cancel();
    }

    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_Escape) { ov.requestClose(); ev.accepted = true; return; }
        if (ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) {
            const n = ev.key - Qt.Key_0;
            ov.dispatch("hl.dsp.focus({ workspace = " + lua(String(n)) + " })"); ov.requestClose(); ev.accepted = true; return;
        }
        if (ev.key === Qt.Key_Left) { ov.selectedWs = Math.max(0, ov.selectedWs - 1); ev.accepted = true; }
        else if (ev.key === Qt.Key_Right) { ov.selectedWs = Math.min(ov.workspaces.length - 1, ov.selectedWs + 1); ev.accepted = true; }
        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { if (ov.workspaces[ov.selectedWs]) ov.switchTo(ov.workspaces[ov.selectedWs]); ev.accepted = true; }
    }

    // ---- backdrop ----
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.05, 0.07, 0.62)
        opacity: ov.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: ov.requestClose() }
    }

    // ---- drag state (manual: a ghost follows the pointer, drop target is hit-tested on release) ----
    QtObject {
        id: dnd
        property bool active: false
        property var win: null          // window model being dragged
        property int fromWs: -1
        property real gx: 0             // ghost position in overlay coordinates
        property real gy: 0
        property real gw: 0
        property real gh: 0
        property int overWs: -1         // index of the card under the pointer
        function cancel() { active = false; win = null; fromWs = -1; overWs = -1; }
        function updateTarget() {
            overWs = -1;
            for (let i = 0; i < cards.count; i++) {
                const c = cards.itemAt(i);
                if (!c) continue;
                const p = c.mapFromItem(ov, gx + gw / 2, gy + gh / 2);
                if (p.x >= 0 && p.y >= 0 && p.x <= c.width && p.y <= c.height) { overWs = i; return; }
            }
        }
    }

    // ---- content ----
    Item {
        id: content
        anchors.fill: parent
        opacity: ov.shown ? 1 : 0
        scale: ov.shown ? 1 : 1.04
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: ov.s(64)
            text: ov.tr.title
            color: "white"; font.pixelSize: ov.s(24); font.bold: true
        }

        // card size keeps the monitor aspect ratio; shrink when there are many workspaces
        readonly property real aspect: ov.mon ? ov.mon.h / ov.mon.w : 9 / 16
        // few workspaces: big cards (up to 560px); many: shrink so they fit in one row, then wrap
        readonly property int maxCardW: ov.s(560)
        readonly property int minCardW: ov.s(300)
        readonly property int perRow: Math.max(1, Math.min(ov.workspaces.length, Math.floor((ov.width - ov.s(120) + ov.s(28)) / (minCardW + ov.s(28)))))
        readonly property int cardW: Math.max(minCardW, Math.min(maxCardW, Math.floor((ov.width - ov.s(120) - (perRow - 1) * ov.s(28)) / perRow)))
        readonly property int cardH: Math.round(cardW * aspect)
        readonly property real k: ov.mon ? cardW / ov.mon.w : 0.15

        Flow {
            id: flow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: ov.s(10)
            width: content.perRow * content.cardW + (content.perRow - 1) * ov.s(28)
            spacing: ov.s(28)

            Repeater {
                id: cards
                model: ov.workspaces

                delegate: Item {
                    id: card
                    required property int index
                    required property var modelData
                    readonly property bool isActive: modelData.id === ov.activeWs
                    readonly property bool isSelected: ov.selectedWs === index
                    readonly property bool isDropTarget: dnd.active && dnd.overWs === index && dnd.fromWs !== modelData.id
                    width: content.cardW
                    height: content.cardH + ov.s(30)

                    // the monitor miniature
                    Rectangle {
                        id: frame
                        width: content.cardW; height: content.cardH
                        radius: ov.s(12)
                        color: Qt.rgba(1, 1, 1, card.isDropTarget ? 0.16 : (cardMa.containsMouse || card.isSelected ? 0.10 : 0.06))
                        border.width: card.isActive || card.isDropTarget ? 2 : 1
                        border.color: card.isDropTarget ? Qt.rgba(0.55, 0.75, 1, 0.9) : (card.isActive ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.12))
                        clip: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        scale: card.isDropTarget ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: ov.switchTo(card.modelData)
                            onEntered: ov.selectedWs = card.index
                        }

                        // empty "new workspace" card
                        Text {
                            anchors.centerIn: parent
                            visible: card.modelData.isNew
                            text: "+"
                            color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: ov.s(40)
                        }

                        // windows
                        Repeater {
                            model: card.modelData.windows
                            delegate: Item {
                                id: win
                                required property var modelData
                                readonly property bool beingDragged: dnd.active && dnd.win && dnd.win.address === modelData.address
                                x: Math.round(modelData.x * content.k)
                                y: Math.round(modelData.y * content.k)
                                width: Math.max(ov.s(24), Math.round(modelData.w * content.k))
                                height: Math.max(ov.s(18), Math.round(modelData.h * content.k))
                                opacity: beingDragged ? 0.25 : 1
                                readonly property var toplevel: ov.toplevelFor(modelData.address)

                                Rectangle {
                                    id: winBox
                                    anchors.fill: parent
                                    radius: ov.s(5)
                                    color: Qt.rgba(0.12, 0.12, 0.15, 0.95)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, winMa.containsMouse ? 0.7 : 0.25)
                                    clip: true

                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: win.toplevel
                                        live: true
                                        paintCursor: false
                                        visible: hasContent
                                    }
                                    // fallback: app icon + title
                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - ov.s(8)
                                        spacing: ov.s(4)
                                        visible: !shot.hasContent
                                        Image {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            readonly property int sz: Math.max(ov.s(14), Math.min(ov.s(40), Math.round(Math.min(win.width, win.height) * 0.4)))
                                            width: sz; height: sz
                                            sourceSize: Qt.size(sz, sz)
                                            source: Quickshell.iconPath(win.modelData.cls, true) || Quickshell.iconPath(String(win.modelData.cls).toLowerCase(), true)
                                            asynchronous: true
                                        }
                                        Text {
                                            width: parent.width
                                            visible: win.height > ov.s(40)
                                            text: win.modelData.title
                                            color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: ov.s(10)
                                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 1
                                        }
                                    }
                                    // hover veil with the title (also over live previews)
                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                        height: ov.s(16)
                                        visible: winMa.containsMouse && shot.hasContent
                                        color: Qt.rgba(0, 0, 0, 0.6)
                                        Text { anchors.fill: parent; anchors.leftMargin: ov.s(5); anchors.rightMargin: ov.s(5); text: win.modelData.title; color: "white"; font.pixelSize: ov.s(9); verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                                    }
                                }

                                MouseArea {
                                    id: winMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool moved: false
                                    onPressed: (m) => { pressX = m.x; pressY = m.y; moved = false; }
                                    onPositionChanged: (m) => {
                                        if (!pressed || (m.buttons & Qt.LeftButton) === 0) return;
                                        if (!moved && Math.hypot(m.x - pressX, m.y - pressY) < ov.s(6)) return;
                                        if (!moved) {
                                            moved = true;
                                            dnd.win = win.modelData; dnd.fromWs = card.modelData.id;
                                            dnd.gw = win.width; dnd.gh = win.height; dnd.active = true;
                                        }
                                        const p = win.mapToItem(ov, m.x, m.y);
                                        dnd.gx = p.x - pressX; dnd.gy = p.y - pressY;
                                        dnd.updateTarget();
                                    }
                                    onReleased: (m) => {
                                        if (m.button === Qt.MiddleButton) { ov.closeWindow(win.modelData.address); return; }
                                        if (!moved) { ov.focusWindow(win.modelData.address); return; }
                                        const target = dnd.overWs >= 0 ? ov.workspaces[dnd.overWs] : null;
                                        const addr = win.modelData.address, from = dnd.fromWs;
                                        dnd.cancel();
                                        if (target && target.id !== from) ov.moveWindow(addr, target.id);
                                    }
                                    onCanceled: dnd.cancel()
                                }
                            }
                        }
                    }

                    // label
                    Text {
                        anchors.top: frame.bottom; anchors.topMargin: ov.s(8)
                        anchors.horizontalCenter: frame.horizontalCenter
                        text: card.modelData.isNew ? card.modelData.name : (card.modelData.name === String(card.modelData.id) ? card.modelData.name : card.modelData.id + " · " + card.modelData.name)
                        color: Qt.rgba(1, 1, 1, card.isActive ? 1 : 0.6)
                        font.pixelSize: ov.s(13); font.bold: card.isActive
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ov.s(28)
            text: ov.tr.hint
            color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: ov.s(12)
        }
    }

    // ---- drag ghost ----
    Rectangle {
        visible: dnd.active
        x: dnd.gx; y: dnd.gy; width: dnd.gw; height: dnd.gh
        radius: ov.s(5)
        color: Qt.rgba(0.2, 0.2, 0.25, 0.9)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.8)
        z: 100
        Text {
            anchors.centerIn: parent; width: parent.width - ov.s(8)
            text: dnd.win ? dnd.win.title : ""
            color: "white"; font.pixelSize: ov.s(10); elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        }
    }
}
