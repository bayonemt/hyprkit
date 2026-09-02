import QtQuick
import Quickshell
import Quickshell.Io

FocusScope {
    id: panel

    property bool shown: false
    signal requestClose()

    readonly property bool pt: String(Quickshell.env("LANG") || "").toLowerCase().indexOf("pt") === 0
    readonly property var tr: pt
        ? { title: "Área de Transferência", clear: "Limpar tudo", confirm: "Apagar tudo?", yes: "Sim", empty: "Nada copiado ainda",
            items: "itens", item: "item", image: "Imagem", hint: "Enter copia  ·  Del apaga  ·  Esc fecha" }
        : { title: "Clipboard", clear: "Clear all", confirm: "Delete everything?", yes: "Yes", empty: "Nothing copied yet",
            items: "items", item: "item", image: "Image", hint: "Enter copies  ·  Del deletes  ·  Esc closes" }

    readonly property real sc: Math.max(0.6, Math.pow(width / 1920, 0.85))
    function s(v) { return Math.round(v * sc) }

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/hyprclip"
    // Optional: HYPRCLIP_DB points cliphist at another database (handy for demos)
    readonly property string db: Quickshell.env("HYPRCLIP_DB") || ""
    readonly property string ch: db !== "" ? ("cliphist -db-path " + db) : "cliphist"
    property var entries: []      // [{ id, line, text, isImage, meta }]

    // ---- cursor position: the card opens where the mouse is ----
    property real monX: 0         // offset of the focused monitor (set by Main.qml)
    property real monY: 0
    property real monScale: 1
    property real cursorX: -1     // screen-local, -1 = unknown
    property real cursorY: -1
    Process {
        id: cursorQuery
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(String(text));
                    panel.cursorX = (o.x - panel.monX) / panel.monScale;
                    panel.cursorY = (o.y - panel.monY) / panel.monScale;
                } catch (e) { panel.cursorX = -1; panel.cursorY = -1; }
            }
        }
    }
    property int selected: 0
    property bool confirmClear: false

    // ---- cliphist ----
    Process {
        id: lister
        command: ["bash", "-c", panel.ch + " list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = String(text).split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const ln = lines[i];
                    if (ln === "") continue;
                    const tab = ln.indexOf("\t");
                    if (tab < 0) continue;
                    const id = ln.substring(0, tab);
                    const preview = ln.substring(tab + 1);
                    const img = /^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/.exec(preview);
                    out.push({ id: id, line: ln, text: preview, isImage: img !== null,
                               meta: img ? (img[2].toUpperCase() + " · " + img[3] + " · " + img[1]) : "" });
                }
                panel.entries = out;
                if (panel.selected >= out.length) panel.selected = Math.max(0, out.length - 1);
            }
        }
    }
    function refresh() { lister.running = false; lister.running = true; }

    Process { id: copier; property string cid: ""; command: ["bash", "-c", panel.ch + " decode \"$0\" | wl-copy", cid] }
    Process { id: deleter; property string line: ""; command: ["bash", "-c", "printf '%s\\n' \"$0\" | " + panel.ch + " delete", line]; onExited: panel.refresh() }
    Process { id: wiper; command: ["bash", "-c", panel.ch + " wipe"]; onExited: panel.refresh() }
    Process { id: mkcache; command: ["mkdir", "-p", panel.cacheDir] }

    function copyEntry(i) {
        if (i < 0 || i >= panel.entries.length) return;
        copier.cid = panel.entries[i].id;
        copier.running = true;
        panel.requestClose();
    }
    function deleteEntry(i) {
        if (i < 0 || i >= panel.entries.length) return;
        deleter.line = panel.entries[i].line;
        deleter.running = true;
    }
    function clearAll() { panel.confirmClear = false; wiper.running = true; }
    function move(d) {
        if (panel.entries.length === 0) return;
        panel.selected = Math.max(0, Math.min(panel.entries.length - 1, panel.selected + d));
        list.positionViewAtIndex(panel.selected, ListView.Contain);
    }

    Component.onCompleted: mkcache.running = true
    onShownChanged: {
        if (shown) {
            panel.selected = 0; panel.confirmClear = false;
            cursorQuery.running = false; cursorQuery.running = true;
            refresh(); panel.forceActiveFocus();
        }
    }

    Keys.onPressed: (ev) => {
        switch (ev.key) {
        case Qt.Key_Escape: if (panel.confirmClear) panel.confirmClear = false; else panel.requestClose(); ev.accepted = true; break;
        case Qt.Key_Return:
        case Qt.Key_Enter: panel.copyEntry(panel.selected); ev.accepted = true; break;
        case Qt.Key_Delete: panel.deleteEntry(panel.selected); ev.accepted = true; break;
        case Qt.Key_Up: panel.move(-1); ev.accepted = true; break;
        case Qt.Key_Down: panel.move(1); ev.accepted = true; break;
        case Qt.Key_PageUp: panel.move(-5); ev.accepted = true; break;
        case Qt.Key_PageDown: panel.move(5); ev.accepted = true; break;
        case Qt.Key_Home: panel.move(-1e9); ev.accepted = true; break;
        case Qt.Key_End: panel.move(1e9); ev.accepted = true; break;
        }
    }

    // click outside closes
    MouseArea { anchors.fill: parent; onClicked: panel.requestClose() }

    // ---- the card (bottom-right, like the Windows clipboard panel) ----
    Rectangle {
        id: card
        width: panel.s(380)
        height: Math.min(panel.s(560), header.height + panel.s(16) + Math.max(panel.s(120), list.contentHeight + panel.s(16)) + footer.height)
        // top-left corner at the cursor, kept inside the screen; bottom-right when unknown
        readonly property real margin: panel.s(12)
        // like a context menu: opens to the bottom-right of the cursor, flips to the
        // left/top when it would not fit, and is always kept inside the screen
        x: {
            if (panel.cursorX < 0) return panel.width - width - margin;
            let px = panel.cursorX + panel.s(4);
            if (px + width + margin > panel.width) px = panel.cursorX - width - panel.s(4);
            return Math.max(margin, Math.min(panel.width - width - margin, px));
        }
        y: {
            if (panel.cursorY < 0) return panel.height - height - margin;
            let py = panel.cursorY + panel.s(4);
            if (py + height + margin > panel.height) py = panel.cursorY - height - panel.s(4);
            return Math.max(margin, Math.min(panel.height - height - margin, py));
        }
        radius: panel.s(18)
        color: Qt.rgba(0.09, 0.09, 0.11, 0.86)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        clip: true

        opacity: panel.shown ? 1 : 0
        scale: panel.shown ? 1 : 0.96
        transformOrigin: Item.TopLeft
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: {} }   // swallow clicks inside the card

        // header
        Item {
            id: header
            width: parent.width
            height: panel.s(54)
            Text {
                anchors.left: parent.left; anchors.leftMargin: panel.s(18)
                anchors.verticalCenter: parent.verticalCenter
                text: panel.tr.title
                color: "white"; font.pixelSize: panel.s(15); font.bold: true
            }
            // Clear all / confirm
            Row {
                anchors.right: parent.right; anchors.rightMargin: panel.s(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: panel.s(6)
                Rectangle {
                    visible: panel.entries.length > 0
                    width: clearText.implicitWidth + panel.s(20); height: panel.s(30); radius: height / 2
                    color: panel.confirmClear ? Qt.rgba(0.85, 0.25, 0.25, clearMa.containsMouse ? 1 : 0.85) : Qt.rgba(1, 1, 1, clearMa.containsMouse ? 0.16 : 0.08)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { id: clearText; anchors.centerIn: parent; text: panel.confirmClear ? panel.tr.yes + " · " + panel.tr.confirm : panel.tr.clear; color: "white"; font.pixelSize: panel.s(12) }
                    MouseArea { id: clearMa; anchors.fill: parent; hoverEnabled: true; onClicked: panel.confirmClear ? panel.clearAll() : (panel.confirmClear = true) }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
        }

        // empty state
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: panel.s(10)
            visible: panel.entries.length === 0
            spacing: panel.s(6)
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📋"; font.pixelSize: panel.s(28) }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: panel.tr.empty; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: panel.s(13) }
        }

        // list
        ListView {
            id: list
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: panel.s(8)
            clip: true
            spacing: panel.s(6)
            model: panel.entries
            cacheBuffer: panel.s(400)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                readonly property bool isSelected: panel.selected === index
                width: list.width
                height: content.height + panel.s(20)
                radius: panel.s(12)
                color: Qt.rgba(1, 1, 1, isSelected ? 0.14 : (rowMa.containsMouse ? 0.10 : 0.06))
                Behavior on color { ColorAnimation { duration: 100 } }

                // lazily decode images to the cache for the thumbnail
                readonly property string thumbPath: panel.cacheDir + "/" + modelData.id
                property bool thumbReady: false
                Process {
                    id: decoder
                    running: row.modelData.isImage
                    command: ["bash", "-c", "[ -s \"$1\" ] || " + panel.ch + " decode \"$0\" > \"$1\"", row.modelData.id, row.thumbPath]
                    onExited: row.thumbReady = true
                }

                Column {
                    id: content
                    x: panel.s(14); y: panel.s(10)
                    width: parent.width - panel.s(28) - panel.s(24)
                    spacing: panel.s(6)

                    Rectangle {
                        visible: row.modelData.isImage
                        width: parent.width; height: panel.s(96)
                        radius: panel.s(8); color: Qt.rgba(0, 0, 0, 0.35); clip: true
                        Image {
                            anchors.fill: parent
                            source: row.thumbReady ? "file://" + row.thumbPath : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.height: panel.s(200)
                        }
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.isImage ? (panel.tr.image + "  ·  " + row.modelData.meta) : row.modelData.text
                        color: row.modelData.isImage ? Qt.rgba(1, 1, 1, 0.6) : "white"
                        font.pixelSize: panel.s(13)
                        font.family: row.modelData.isImage ? "sans-serif" : "sans-serif"
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                // delete button (hover / selected)
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: panel.s(8)
                    width: panel.s(22); height: panel.s(22); radius: width / 2
                    color: Qt.rgba(1, 1, 1, delMa.containsMouse ? 0.25 : 0.10)
                    opacity: (row.isSelected || rowMa.containsMouse) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: panel.s(14); anchors.verticalCenterOffset: -1 }
                    MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true; onClicked: panel.deleteEntry(row.index) }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    z: -1
                    hoverEnabled: true
                    onPositionChanged: panel.selected = row.index
                    onClicked: panel.copyEntry(row.index)
                }
            }
        }

        // footer
        Item {
            id: footer
            width: parent.width
            height: panel.s(34)
            anchors.bottom: parent.bottom
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
            Text {
                anchors.left: parent.left; anchors.leftMargin: panel.s(18)
                anchors.verticalCenter: parent.verticalCenter
                text: panel.entries.length + " " + (panel.entries.length === 1 ? panel.tr.item : panel.tr.items)
                color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: panel.s(11)
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: panel.s(18)
                anchors.verticalCenter: parent.verticalCenter
                text: panel.tr.hint
                color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: panel.s(11)
            }
        }
    }
}
