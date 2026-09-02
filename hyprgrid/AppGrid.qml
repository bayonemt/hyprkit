import QtQuick
import QtQuick.Controls
import Quickshell

FocusScope {
    id: menu

    property bool shown: false
    signal requestClose()

    // ---- strings (pt-BR when LANG starts with "pt", English otherwise) ----
    readonly property bool pt: String(Quickshell.env("LANG") || "").toLowerCase().indexOf("pt") === 0
    readonly property var tr: pt
        ? { search: "Pesquisar aplicativos", apps: "Aplicativos", none: "Nenhum resultado", results: "Resultados" }
        : { search: "Search applications", apps: "Applications", none: "No results", results: "Results" }

    // ---- scale (base 1920px) ----
    readonly property real sc: Math.max(0.6, Math.pow(width / 1920, 0.85))
    function s(v) { return Math.round(v * sc) }

    // ---- grid layout ----
    readonly property int cols: 6
    readonly property int rows: 4
    readonly property int pageSize: cols * rows
    readonly property int cellW: s(150)
    readonly property int cellH: s(140)
    readonly property int iconSize: s(72)
    readonly property int gridW: cols * cellW
    readonly property int gridH: rows * cellH

    // ---- application model ----
    property var allApps: []
    property var apps: []
    property string query: ""
    property int selected: 0

    function rebuild() {
        const list = [];
        const entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e || e.noDisplay) continue;
            list.push(e);
        }
        list.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
        menu.allApps = list;
        menu.applyFilter();
    }

    // lowercase + strip accents so "musica" matches "Música"
    function norm(t) {
        return String(t || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    function applyFilter() {
        const q = norm(menu.query).trim();
        if (q === "") {
            menu.apps = menu.allApps;
        } else {
            const starts = [], contains = [];
            for (let i = 0; i < menu.allApps.length; i++) {
                const e = menu.allApps[i];
                const n = norm(e.name);
                if (n.startsWith(q)) starts.push(e);
                else if (n.indexOf(q) !== -1 || norm(e.genericName).indexOf(q) !== -1 || norm(e.comment).indexOf(q) !== -1) contains.push(e);
            }
            menu.apps = starts.concat(contains);
        }
        menu.selected = 0;
        pages.currentIndex = 0;
    }

    readonly property int pageCount: Math.max(1, Math.ceil(apps.length / pageSize))

    function launch(idx) {
        if (idx < 0 || idx >= menu.apps.length) return;
        const e = menu.apps[idx];
        menu.requestClose();
        e.execute();
    }

    function move(delta) {
        if (menu.apps.length === 0) return;
        let n = menu.selected + delta;
        n = Math.max(0, Math.min(menu.apps.length - 1, n));
        menu.selected = n;
        pages.currentIndex = Math.floor(n / menu.pageSize);
    }

    function gotoPage(p) {
        p = Math.max(0, Math.min(menu.pageCount - 1, p));
        pages.currentIndex = p;
        if (Math.floor(menu.selected / menu.pageSize) !== p) {
            menu.selected = p * menu.pageSize + (menu.selected % menu.pageSize);
            if (menu.selected >= menu.apps.length) menu.selected = menu.apps.length - 1;
        }
    }

    Component.onCompleted: rebuild()
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { menu.rebuild() }
    }

    onShownChanged: {
        if (shown) {
            searchField.text = "";
            menu.query = "";
            menu.applyFilter();
            searchField.forceActiveFocus();
        }
    }

    // ---- backdrop ----
    // The blur itself comes from Hyprland (layer rule on the "hyprgrid" namespace)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.05, 0.07, 0.62)
        opacity: menu.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: menu.requestClose()
        }
    }

    // ---- keyboard ----
    Keys.onPressed: (ev) => {
        switch (ev.key) {
        case Qt.Key_Escape: menu.requestClose(); ev.accepted = true; break;
        case Qt.Key_Return:
        case Qt.Key_Enter: menu.launch(menu.selected); ev.accepted = true; break;
        case Qt.Key_Left: menu.move(-1); ev.accepted = true; break;
        case Qt.Key_Right: menu.move(1); ev.accepted = true; break;
        case Qt.Key_Up: menu.move(-menu.cols); ev.accepted = true; break;
        case Qt.Key_Down: menu.move(menu.cols); ev.accepted = true; break;
        case Qt.Key_PageUp: menu.gotoPage(pages.currentIndex - 1); ev.accepted = true; break;
        case Qt.Key_PageDown: menu.gotoPage(pages.currentIndex + 1); ev.accepted = true; break;
        case Qt.Key_Tab: menu.move(1); ev.accepted = true; break;
        case Qt.Key_Backtab: menu.move(-1); ev.accepted = true; break;
        }
    }

    // ---- content ----
    Item {
        id: content
        anchors.fill: parent
        opacity: menu.shown ? 1 : 0
        scale: menu.shown ? 1 : 1.06
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // Search box
        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: menu.s(70)
            width: menu.s(420)
            height: menu.s(44)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, searchField.activeFocus ? 0.16 : 0.11)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: menu.s(16)
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: menu.s(18)
            }

            TextInput {
                id: searchField
                anchors.left: searchIcon.right
                anchors.leftMargin: menu.s(10)
                anchors.right: parent.right
                anchors.rightMargin: menu.s(16)
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                font.pixelSize: menu.s(16)
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                clip: true
                focus: true
                onTextChanged: { menu.query = text; menu.applyFilter(); }
                Keys.forwardTo: [menu]

                Text {
                    anchors.fill: parent
                    text: menu.tr.search
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: parent.font.pixelSize
                    visible: !searchField.text
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Title
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: searchBox.y + searchBox.height + menu.s(36)
            text: menu.query.trim() === "" ? menu.tr.apps : (menu.apps.length === 0 ? menu.tr.none : menu.tr.results)
            color: "white"
            font.pixelSize: menu.s(22)
            font.bold: true
        }

        // Pages
        ListView {
            id: pages
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: menu.s(30)
            width: menu.gridW
            height: menu.gridH
            clip: true
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 260
            highlightMoveVelocity: -1
            boundsBehavior: Flickable.StopAtBounds
            model: menu.pageCount

            onCurrentIndexChanged: {
                if (Math.floor(menu.selected / menu.pageSize) !== currentIndex) {
                    menu.selected = Math.min(menu.apps.length - 1, currentIndex * menu.pageSize);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (w) => {
                    if (w.angleDelta.y < 0 || w.angleDelta.x < 0) menu.gotoPage(pages.currentIndex + 1);
                    else menu.gotoPage(pages.currentIndex - 1);
                    w.accepted = true;
                }
            }

            delegate: Item {
                id: page
                required property int index
                width: pages.width
                height: pages.height

                Grid {
                    columns: menu.cols
                    rows: menu.rows
                    Repeater {
                        model: Math.max(0, Math.min(menu.pageSize, menu.apps.length - page.index * menu.pageSize))
                        delegate: Item {
                            id: cell
                            required property int index
                            readonly property int globalIndex: page.index * menu.pageSize + index
                            readonly property var entry: menu.apps[globalIndex]
                            readonly property bool isSelected: menu.selected === globalIndex
                            width: menu.cellW
                            height: menu.cellH

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: menu.s(6)
                                radius: menu.s(16)
                                color: Qt.rgba(1, 1, 1, cell.isSelected ? 0.16 : 0)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: menu.s(10)
                                Item {
                                    id: iconBox
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: menu.iconSize
                                    height: menu.iconSize
                                    scale: mouse.pressed ? 0.9 : 1
                                    Behavior on scale { NumberAnimation { duration: 90 } }

                                    readonly property string path: cell.entry ? Quickshell.iconPath(cell.entry.icon, true) : ""

                                    Image {
                                        id: icon
                                        anchors.fill: parent
                                        sourceSize: Qt.size(menu.iconSize, menu.iconSize)
                                        source: iconBox.path
                                        asynchronous: true
                                        smooth: true
                                        visible: status === Image.Ready
                                    }

                                    // Fallback when the icon theme has nothing: colored tile with the app's initial
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: menu.s(6)
                                        radius: width * 0.24
                                        visible: iconBox.path === "" || icon.status === Image.Error
                                        color: Qt.hsla((cell.globalIndex * 0.137) % 1.0, 0.45, 0.42, 1)
                                        Text {
                                            anchors.centerIn: parent
                                            text: cell.entry && cell.entry.name.length > 0 ? cell.entry.name.charAt(0).toUpperCase() : "?"
                                            color: "white"
                                            font.pixelSize: parent.height * 0.5
                                            font.bold: true
                                        }
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: menu.cellW - menu.s(24)
                                    text: cell.entry ? cell.entry.name : ""
                                    color: "white"
                                    font.pixelSize: menu.s(13)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            // Hover follows the keyboard selection (a single highlight, GNOME-style)
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                onClicked: menu.launch(cell.globalIndex)
                                hoverEnabled: true
                                onPositionChanged: menu.selected = cell.globalIndex
                            }
                        }
                    }
                }
            }
        }

        // Page dots
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: pages.y + pages.height + menu.s(28)
            spacing: menu.s(10)
            visible: menu.pageCount > 1
            Repeater {
                model: menu.pageCount
                delegate: Rectangle {
                    required property int index
                    width: menu.s(8); height: menu.s(8); radius: width / 2
                    color: Qt.rgba(1, 1, 1, pages.currentIndex === index ? 0.95 : 0.35)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { anchors.fill: parent; onClicked: menu.gotoPage(parent.index) }
                }
            }
        }
    }
}
