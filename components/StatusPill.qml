import QtQuick
import QtQuick.Layouts

Rectangle {
    property color pillBg:      "#99000000"
    property color fgColor:     "#e0e4db"
    property color accentColor: "#9fd49b"
    property color errorColor:  "#ffb4ab"
    property color btColor:     "#a1ced5"
    property string activeFont: "Inter Nerd Font"
    
    property string ethVal:     ""
    property string wifiVal:    ""
    property string btVal:      ""
    property string battStatus: ""
    property string clockStr:   ""
    property bool calendarOpen: false
    property string battVal: ""

    signal ethClicked
    signal wifiClicked
    signal btClicked
    signal clockClicked
    signal powerClicked

    Layout.preferredHeight: 32
    Layout.preferredWidth: rightRow.implicitWidth + 26
    Layout.alignment: Qt.AlignVCenter
    color: pillBg
    radius: 16
    border.color: Qt.rgba(1,1,1,0.06)

    Row {
        id: rightRow
        anchors.centerIn: parent
        spacing: 13

        // ── ETHERNET (Disappears completely when empty) ──────
        Item {
            visible: ethVal !== ""
            height: 22
            width: ethLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: ethLabel
                text: "󰈀  " + ethVal
                color: accentColor
                font.family: activeFont
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            TapHandler { onTapped: ethClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            visible: ethVal !== ""
            width: 1; height: 14
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── WIFI (Shows "Off" when empty) ────────────────────
        Item {
            height: 22
            width: wifiLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: wifiLabel
                text: wifiVal !== "" ? "󰖩  " + wifiVal : "󰖪  Off"
                color: wifiVal !== "" ? accentColor : errorColor
                font.family: activeFont
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            TapHandler { onTapped: wifiClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── BLUETOOTH (Shows "Off" when empty) ───────────────
        Item {
            height: 22
            width: btLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: btLabel
                text: btVal !== "" ? "󰂯  " + btVal : "󰂲  Off"
                color: btVal !== "" ? btColor : errorColor
                font.family: activeFont
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            TapHandler { onTapped: btClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── CLOCK ────────────────────────────────────────────
        Item {
            height: 22
            width: clockLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: clockLabel
                text: clockStr
                color: calendarOpen ? accentColor : fgColor
                font.family: activeFont
                font.pixelSize: 12
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            TapHandler { onTapped: clockClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        // After line 58
Rectangle {
    width: 1; height: 14
    color: Qt.rgba(1,1,1,0.15)
    anchors.verticalCenter: parent.verticalCenter
}

Item {
            visible: battVal !== ""
            height: 22
            width: battLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: battLabel
                text: {
                    // Clean up the string so it matches perfectly
                    let stat = battStatus.trim().toLowerCase();
                    let icon = "󰁹"; // Default (Discharging)

                    if (stat === "charging") {
                        icon = "󰂄"; // Charging
                    } else if (stat === "full" || stat === "not charging") {
                        icon = "󰚥"; // Plugged in / Full
                    }

                    return icon + "  " + battVal + "%";
                }
                
                // Highlight color if it's charging
                color: battStatus.trim().toLowerCase() === "charging" ? accentColor : fgColor
                font.family: activeFont
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        // ── DIVIDER ──────────────────────────────────────────
        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── POWER BUTTON ─────────────────────────────────────
        Item {
            height: 22
            width: powerLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            
            Text {
                id: powerLabel
                text: "󰕮" 
                color: errorColor // Makes it stand out nicely (red/accent)
                font.family: activeFont
                font.pixelSize: 14 
                anchors.verticalCenter: parent.verticalCenter
            }
            
            TapHandler { onTapped: powerClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}