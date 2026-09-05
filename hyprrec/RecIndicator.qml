import QtQuick

// Red pill with a pulsing dot, the elapsed time and a stop button.
Rectangle {
    id: ind
    property var state: null
    signal stopRequested()

    readonly property bool pt: String(Qt.locale().name).toLowerCase().indexOf("pt") === 0
    readonly property real now: clock.now
    readonly property int elapsed: state && state.recordStart > 0 ? Math.max(0, Math.floor(now / 1000 - state.recordStart)) : 0
    function two(n) { return (n < 10 ? "0" : "") + n }
    readonly property string timeText: elapsed >= 3600 ? Math.floor(elapsed / 3600) + ":" + two(Math.floor(elapsed % 3600 / 60)) + ":" + two(elapsed % 60)
                                                        : two(Math.floor(elapsed / 60)) + ":" + two(elapsed % 60)

    QtObject { id: clock; property real now: Date.now() }
    Timer { interval: 500; running: ind.visible; repeat: true; onTriggered: clock.now = Date.now() }

    width: row.implicitWidth + 28
    height: 34
    radius: height / 2
    color: Qt.rgba(0.10, 0.10, 0.12, 0.92)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.12)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5
            color: "#ff3b30"
            SequentialAnimation on opacity {
                loops: Animation.Infinite; running: ind.visible
                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ind.timeText
            color: "white"; font.pixelSize: 13; font.bold: true
            font.features: { "tnum": 1 }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 11
            color: Qt.rgba(1, 1, 1, stopMa.containsMouse ? 0.25 : 0.12)
            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 1.5; color: "white" }
            MouseArea { id: stopMa; anchors.fill: parent; hoverEnabled: true; onClicked: ind.stopRequested() }
        }
    }
}
