import QtQuick
import QtQuick.Layouts

Item {
    property color  accentColor: "#9fd49b"
    property color  fgColor:     "#e0e4db"
    property string activeFont:  "Inter Nerd Font"
    property string musicTitle:  ""
    property var    visualizerData: []
    property bool   isPlaying:   false

    signal prevClicked
    signal playPauseClicked
    signal nextClicked

    Layout.preferredHeight: 48
    Layout.preferredWidth:  380
    Layout.alignment: Qt.AlignVCenter

    // ── outer pill ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#8c000000"
        radius: 999
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)
        border.width: 0.5

        // top shimmer line
        Rectangle {
            anchors.top:              parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width:  parent.width - 32
            height: 0.5
            radius: 999
            color:  Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
        }
    }

    Row {
        anchors.fill:    parent
        anchors.margins: 6
        spacing: 2

        // ── prev ────────────────────────────────────────────────────────────
        Rectangle {
            width: 36; height: 36; radius: 18
            color: prevMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "󰒮"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 14
            }
            MouseArea {
                id: prevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: prevClicked()
            }
        }

        // divider
        Rectangle {
            width: 0.5; height: 20
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── center: title + visualizer bars ─────────────────────────────────
        Item {
            width: parent.width - 36 - 36 - 4 - 4  // subtract btns + dividers
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: playPauseClicked()
            }

            Column {
                anchors.centerIn: parent
                spacing: 3

                // track title
                Text {
                    text: musicTitle || "No Music"
                    color: fgColor
                    font.family: activeFont
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    opacity: 0.92
                }

                // visualizer bars
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    height: 14

                    Repeater {
                        model: visualizerData.length

                        Rectangle {
                            width:  2.5
                            height: Math.max(2, visualizerData[index] * 14)
                            radius: 2
                            color:  accentColor
                            opacity: 0.85
                            anchors.bottom: parent.bottom
                        }
                    }
                }
            }
        }

        // divider
        Rectangle {
            width: 0.5; height: 20
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── next ────────────────────────────────────────────────────────────
        Rectangle {
            width: 36; height: 36; radius: 18
            color: nextMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "󰒭"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 14
            }
            MouseArea {
                id: nextMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: nextClicked()
            }
        }
    }
}
