import QtQuick
import QtQuick.Layouts

Item {
    property color accentColor: "#9fd49b"
    property color fgColor:     "#e0e4db"
    property string activeFont: "Inter Nerd Font"
    property string musicTitle: ""
    property var visualizerData: []

    signal prevClicked
    signal playPauseClicked
    signal nextClicked

    Layout.preferredHeight: 40
    Layout.preferredWidth: 340
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.fill: parent
        color: "#66000000"
        radius: 12
        border.color: Qt.rgba(1,1,1,0.08)
    }

    Row {
        anchors.fill: parent
        spacing: 0

        MouseArea {
            width: parent.width * 0.15
            height: parent.height
            onClicked: prevClicked()
            Text {
                anchors.centerIn: parent
                text: "󰒮"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 14
            }
        }

        Rectangle {
            width: 1
            height: parent.height * 0.6
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1,1,1,0.3)
        }

        MouseArea {
            width: parent.width * 0.7
            height: parent.height
            onClicked: playPauseClicked()

            Column {
                anchors.fill: parent

                Text {
                    text: musicTitle || "No Music"
                    color: fgColor
                    font.family: activeFont
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    width: parent.width * 0.9
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    spacing: 2
                    height: parent.height * 0.5
                    width: visualizerData.length * 4

                    Repeater {
                        model: visualizerData.length
                        Rectangle {
                            width: 2
                            height: Math.max(2, visualizerData[index] * parent.height)
                            anchors.bottom: parent.bottom
                            radius: 2
                            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.9)
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: parent.height * 0.6
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1,1,1,0.3)
        }

        MouseArea {
            width: parent.width * 0.15
            height: parent.height
            onClicked: nextClicked()
            Text {
                anchors.centerIn: parent
                text: "󰒭"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 14
            }
        }
    }
}
