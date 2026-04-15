import QtQuick
import QtQuick.Layouts

Rectangle {
    property color pillBg:     "#99000000"
    property color fgColor:    "#e0e4db"
    property color accentColor:"#9fd49b"
    property color errorColor: "#ffb4ab"
    property string activeFont:"Inter Nerd Font"
    property int cpuVal: 0
    property int ramVal: 0

    Layout.preferredHeight: 32
    Layout.preferredWidth: healthRow.implicitWidth + 28
    Layout.alignment: Qt.AlignVCenter
    color: pillBg
    radius: 16
    border.color: Qt.rgba(1,1,1,0.06)

    Row {
        id: healthRow
        anchors.centerIn: parent
        spacing: 12

        Row {
            spacing: 5
            Text {
                text: "󰻠"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: cpuVal + "%"
                color: cpuVal > 80 ? errorColor : fgColor
                font.family: activeFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 5
            Text {
                text: "󰍛"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: ramVal + "%"
                color: ramVal > 85 ? errorColor : fgColor
                font.family: activeFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
