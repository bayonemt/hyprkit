import QtQuick
import Quickshell
import Quickshell.Io

FocusScope {
    id: book

    property bool shown: false
    signal requestClose()

    // ---- where pages live: one .md file per page ----
    // Override with the HYPRNOTE_DIR environment variable.
    readonly property string dir: Quickshell.env("HYPRNOTE_DIR") || (Quickshell.env("HOME") + "/Documents/hyprnote")

    // ---- strings (pt-BR when LANG starts with "pt", English otherwise) ----
    readonly property bool pt: String(Quickshell.env("LANG") || "").toLowerCase().indexOf("pt") === 0
    readonly property var tr: pt
        ? { title: "Caderno", placeholder: "Escreva aqui...", newPage: "Nova página", newBtn: "Nova página  (Ctrl+N)",
            save: "Salvar  (Ctrl+S)", saved: "Salvo ✓", pages: "Páginas", of: "de",
            hint: "Esc fecha e salva  ·  PageUp / PageDown viram a página  ·  arquivos em " }
        : { title: "Notebook", placeholder: "Write here...", newPage: "New page", newBtn: "New page  (Ctrl+N)",
            save: "Save  (Ctrl+S)", saved: "Saved ✓", pages: "Pages", of: "of",
            hint: "Esc closes and saves  ·  PageUp / PageDown turn the page  ·  files in " }

    // ---- scale (base 1920px) ----
    readonly property real sc: Math.max(0.6, Math.pow(width / 1920, 0.85))
    function s(v) { return Math.round(v * sc) }

    readonly property color paper: "#f4ecd8"
    readonly property color ink: "#2b2418"
    readonly property color ruled: "#d9ccae"
    // Real line height of the editor (TextEdit has no lineHeight, so measure a hidden Text with the same font)
    readonly property real lineH: Math.max(1, lineProbe.height / 2)
    Text { id: lineProbe; visible: false; text: "Ag\nAg"; font.family: "Noto Serif"; font.pixelSize: book.s(17) }

    // ---- pages ----
    // The file list is managed here and only refreshed on open, new page and save.
    // (A FolderListModel resets on every directory change, which shuffled which
    // file each editor was showing and could overwrite pages with wrong content.)
    property var pages: []
    readonly property int pageCount: pages.length
    property int spread: 0   // which pair of pages is open (left page = spread*2)
    readonly property int spreadCount: Math.max(1, Math.ceil(pageCount / 2))
    property bool gotoLastAfterList: false
    property bool creating: false

    Process {
        id: lister
        command: ["bash", "-c", "ls -1 -- \"$0\" 2>/dev/null | grep -E '^page-[0-9]+\\.md$' | sort", book.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const tx = String(text).trim();
                book.pages = tx === "" ? [] : tx.split("\n");
                book.onListed();
            }
        }
    }
    function refreshList() { lister.running = false; lister.running = true; }

    function onListed() {
        if (book.spread > book.spreadCount - 1) book.spread = book.spreadCount - 1;
        if (book.gotoLastAfterList) { book.gotoLastAfterList = false; book.spread = book.spreadCount - 1; }
        leftPage.reloadIfClean();
        rightPage.reloadIfClean();
        if (book.pageCount === 0 && book.shown && !book.creating) book.newPage();
        else if (book.shown && !leftPage.hasFocus() && !rightPage.hasFocus()) leftPage.focusEditor();
    }

    function fileAt(i) {
        if (i < 0 || i >= pages.length) return "";
        return book.dir + "/" + pages[i];
    }

    function nextName() {
        let max = 0;
        for (let i = 0; i < pages.length; i++) {
            const m = /page-(\d+)\.md/.exec(pages[i]);
            if (m) max = Math.max(max, parseInt(m[1]));
        }
        const n = max + 1;
        return "page-" + (n < 100 ? ("00" + n).slice(-3) : String(n)) + ".md";
    }

    Process { id: mkdir; command: ["mkdir", "-p", book.dir] }
    Process {
        id: touch
        property string target: ""
        command: ["touch", "--", target]
        onExited: { book.creating = false; book.gotoLastAfterList = true; book.refreshList(); }
    }

    function newPage() {
        if (book.creating) return;
        saveAll();
        book.creating = true;
        touch.target = book.dir + "/" + nextName();
        touch.running = true;
    }

    function saveAll() {
        leftPage.save();
        rightPage.save();
    }

    function flip(delta) {
        const n = Math.max(0, Math.min(book.spreadCount - 1, book.spread + delta));
        if (n === book.spread) return;
        saveAll();
        book.spread = n;
        leftPage.focusEditor();
    }

    property bool savedFlash: false
    Timer { id: savedTimer; interval: 1400; onTriggered: book.savedFlash = false }
    function flashSaved() { book.savedFlash = true; savedTimer.restart(); }

    Component.onCompleted: mkdir.running = true

    onShownChanged: {
        if (shown) refreshList();
        else saveAll();
    }

    // ---- backdrop (the blur comes from Hyprland's layer rule on the "hyprnote" namespace) ----
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.05, 0.07, 0.62)
        opacity: book.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: book.requestClose() }
    }

    // ---- global keys ----
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_Escape) { book.requestClose(); ev.accepted = true; return; }
        if (ev.key === Qt.Key_PageDown) { book.flip(1); ev.accepted = true; return; }
        if (ev.key === Qt.Key_PageUp) { book.flip(-1); ev.accepted = true; return; }
        if (ev.modifiers & Qt.ControlModifier) {
            if (ev.key === Qt.Key_S) { book.saveAll(); book.flashSaved(); ev.accepted = true; }
            else if (ev.key === Qt.Key_N) { book.newPage(); ev.accepted = true; }
            else if (ev.key === Qt.Key_Right) { book.flip(1); ev.accepted = true; }
            else if (ev.key === Qt.Key_Left) { book.flip(-1); ev.accepted = true; }
        }
    }

    // ---- one page of the book ----
    component Page: Item {
        id: pg
        property int pageIndex: 0
        property bool isLeft: true
        readonly property string path: book.fileAt(pageIndex)
        readonly property bool exists: path !== ""
        property bool dirty: false
        property string loadedPath: ""

        FileView {
            id: fv
            path: pg.path
            blockLoading: true
            blockAllReads: true   // synchronous reads: text() always returns the file at the current path
            printErrors: false
        }

        property bool loading: false
        function reload() {
            pg.loading = true;
            editor.text = pg.exists ? fv.text() : "";
            pg.loading = false;
            pg.loadedPath = pg.path;
            pg.dirty = false;
        }
        // Reload from disk unless there are unsaved edits for this same file
        function reloadIfClean() {
            if (pg.dirty && pg.loadedPath === pg.path) return;
            reload();
        }
        function save() {
            if (!pg.exists || !pg.dirty || pg.loadedPath !== pg.path) return;
            fv.setText(editor.text);
            pg.dirty = false;
        }
        function focusEditor() { if (pg.exists) editor.forceActiveFocus(); }
        function hasFocus() { return editor.activeFocus; }
        onPathChanged: reload()

        Rectangle {
            anchors.fill: parent
            color: book.paper
            // soft shadow next to the spine
            Rectangle {
                width: book.s(40); height: parent.height
                anchors.left: pg.isLeft ? undefined : parent.left
                anchors.right: pg.isLeft ? parent.right : undefined
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: pg.isLeft ? "transparent" : Qt.rgba(0,0,0,0.13) }
                    GradientStop { position: 1.0; color: pg.isLeft ? Qt.rgba(0,0,0,0.13) : "transparent" }
                }
            }
        }

        // ruled lines
        Column {
            x: book.s(44); y: book.s(58) + book.lineH - 1
            width: parent.width - book.s(88)
            spacing: book.lineH - 1
            Repeater {
                model: Math.max(0, Math.floor((pg.height - book.s(120)) / book.lineH))
                Rectangle { width: parent.width; height: 1; color: book.ruled }
            }
        }
        // red margin line
        Rectangle {
            x: book.s(36); y: book.s(30); width: 1; height: parent.height - book.s(60)
            color: "#e0a8a0"; opacity: 0.8
        }

        Flickable {
            id: flick
            x: book.s(48); y: book.s(58)
            width: parent.width - book.s(96)
            height: parent.height - book.s(120)
            clip: true
            contentHeight: editor.paintedHeight + book.lineH
            boundsBehavior: Flickable.StopAtBounds
            function ensureVisible(r) {
                if (contentY >= r.y) contentY = r.y;
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: editor
                width: flick.width
                color: book.ink
                selectionColor: "#c9b98a"
                selectedTextColor: book.ink
                font.family: "Noto Serif"
                font.pixelSize: book.s(17)
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                enabled: pg.exists
                cursorVisible: activeFocus
                onTextChanged: if (!pg.loading && pg.exists) pg.dirty = true
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                Keys.forwardTo: [book]
                Text {
                    visible: pg.exists && editor.text.length === 0 && !editor.activeFocus
                    text: book.tr.placeholder
                    color: book.ink; opacity: 0.35
                    font: editor.font
                }
            }
        }

        // page that does not exist yet
        Item {
            anchors.fill: parent
            visible: !pg.exists
            Column {
                anchors.centerIn: parent
                spacing: book.s(10)
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "+"; color: book.ink; opacity: 0.35; font.pixelSize: book.s(40) }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: book.tr.newPage; color: book.ink; opacity: 0.45; font.pixelSize: book.s(15); font.family: "Noto Serif" }
            }
            MouseArea { anchors.fill: parent; onClicked: book.newPage() }
        }

        // page number
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: book.s(22)
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pg.exists
            text: (pg.pageIndex + 1) + (pg.dirty ? " •" : "")
            color: book.ink; opacity: 0.55
            font.family: "Noto Serif"; font.pixelSize: book.s(13)
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: editor.forceActiveFocus()
        }
    }

    // ---- content ----
    Item {
        id: content
        anchors.fill: parent
        opacity: book.shown ? 1 : 0
        scale: book.shown ? 1 : 1.04
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: book.s(60)
            text: book.tr.title
            color: "white"
            font.pixelSize: book.s(24)
            font.bold: true
        }

        // the book
        Item {
            id: bookBody
            anchors.centerIn: parent
            anchors.verticalCenterOffset: book.s(14)
            width: book.s(1180)
            height: book.s(720)

            // clicks on the cover/spine must not close the overlay
            MouseArea { anchors.fill: parent; anchors.margins: -book.s(8); onClicked: {} }

            // shadow
            Rectangle {
                anchors.fill: parent
                anchors.margins: -book.s(6)
                radius: book.s(14)
                color: Qt.rgba(0, 0, 0, 0.35)
                y: book.s(8)
            }
            // cover
            Rectangle {
                anchors.fill: parent
                anchors.margins: -book.s(8)
                radius: book.s(12)
                color: "#3a2a22"
            }

            Page {
                id: leftPage
                isLeft: true
                pageIndex: book.spread * 2
                x: 0; y: 0
                width: parent.width / 2 - book.s(3)
                height: parent.height
            }
            Page {
                id: rightPage
                isLeft: false
                pageIndex: book.spread * 2 + 1
                x: parent.width / 2 + book.s(3); y: 0
                width: parent.width / 2 - book.s(3)
                height: parent.height
            }
            // spine
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: book.s(6); height: parent.height
                color: "#2a1d17"
            }

            // side arrows
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    readonly property bool prev: index === 0
                    readonly property bool can: prev ? book.spread > 0 : book.spread < book.spreadCount - 1
                    anchors.verticalCenter: parent.verticalCenter
                    x: prev ? -book.s(70) : parent.width + book.s(70) - width
                    width: book.s(46); height: book.s(46); radius: width / 2
                    color: Qt.rgba(1, 1, 1, arrowMa.containsMouse ? 0.22 : 0.12)
                    opacity: can ? 1 : 0.25
                    Text { anchors.centerIn: parent; text: parent.prev ? "‹" : "›"; color: "white"; font.pixelSize: book.s(28); anchors.verticalCenterOffset: -book.s(2) }
                    MouseArea { id: arrowMa; anchors.fill: parent; hoverEnabled: true; onClicked: book.flip(parent.prev ? -1 : 1) }
                }
            }
        }

        // action bar
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: bookBody.y + bookBody.height + book.s(34)
            spacing: book.s(12)

            component Btn: Rectangle {
                property string label: ""
                property bool primary: false
                signal clicked()
                width: t.implicitWidth + book.s(32); height: book.s(40); radius: height / 2
                color: primary ? Qt.rgba(1, 1, 1, ma.containsMouse ? 1.0 : 0.92) : Qt.rgba(1, 1, 1, ma.containsMouse ? 0.22 : 0.13)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { id: t; anchors.centerIn: parent; text: parent.label; color: parent.primary ? "#1a1a1a" : "white"; font.pixelSize: book.s(14); font.bold: parent.primary }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
            }

            Btn { label: book.tr.newBtn; onClicked: book.newPage() }
            Btn {
                primary: true
                label: book.savedFlash ? book.tr.saved : book.tr.save
                onClicked: { book.saveAll(); book.flashSaved(); }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: book.s(10)
                text: book.tr.pages + " " + (book.spread * 2 + 1) + (book.spread * 2 + 2 <= book.pageCount ? "–" + (book.spread * 2 + 2) : "") + " " + book.tr.of + " " + book.pageCount
                color: Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: book.s(13)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: book.s(28)
            text: book.tr.hint + book.dir
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: book.s(12)
        }
    }
}
