import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    id: powerMenuVariants
    model: Quickshell.screens

    // Props passed in from shell.qml
    property bool   powerMenuOpen: false
    property color  accentColor:   "#9fd49b"
    property color  fgColor:       "#e0e4db"
    property color  errorColor:    "#ffb4ab"
    property string activeFont:    "Inter Nerd Font"

    signal requestClose()

    PanelWindow {
        id: powerWin
        required property var modelData
        screen: modelData

        anchors { top: true; bottom: true; left: true; right: true }
        visible: powerMenuVariants.powerMenuOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: powerMenuVariants.powerMenuOpen
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None

        // ── State lives inside PanelWindow ───────────────────────────────────
        property bool   isRecording: false
        property string powerMode:   "balanced"

        // ── Processes live inside PanelWindow ────────────────────────────────
        Process {
            id: getPowerMode
            command: ["sh", "-c", "powerprofilesctl get"]
            running: powerMenuVariants.powerMenuOpen   // refresh each time menu opens
            stdout: SplitParser {
                onRead: data => { powerWin.powerMode = data.trim() }
            }
        }

        Process {
            id: toggleRecordScript
            command: ["/home/tanishk/.config/niri-rice/scripts/toggle-record.sh"]
        }

        Process { id: setSaver;    command: ["powerprofilesctl", "set", "power-saver"] }
        Process { id: setBalanced; command: ["powerprofilesctl", "set", "balanced"] }
        Process { id: setPerf;     command: ["powerprofilesctl", "set", "performance"] }

        Process { id: lockCmd;     command: ["swaylock"] }
        Process { id: rebootCmd;   command: ["systemctl", "reboot"] }
        Process { id: shutdownCmd; command: ["systemctl", "poweroff"] }

        // ── Click outside to close ────────────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            onClicked: powerMenuVariants.requestClose()
        }

        // ── Menu box ──────────────────────────────────────────────────────────
        Rectangle {
            width: 340
            height: 350
            anchors.top:        parent.top
            anchors.right:      parent.right
            anchors.topMargin:  56
            anchors.rightMargin: 5

            color: "#ee0d0d0d"
            border.color: Qt.rgba(1,1,1,0.1)
            radius: 14

            MouseArea { anchors.fill: parent }  // block click-through

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                // 1. Profile
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Rectangle {
                        width: 56; height: 56; radius: 28
                        color: Qt.rgba(1,1,1,0.1)
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: powerMenuVariants.accentColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 28
                        }
                    }
                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: "Tanishk"
                            color: powerMenuVariants.fgColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 18; font.weight: Font.Bold
                        }
                        Text {
                            text: powerWin.isRecording ? "🔴 Recording" : "Ready"
                            color: powerWin.isRecording
                                ? powerMenuVariants.errorColor
                                : Qt.rgba(1,1,1,0.5)
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.1) }

                // 2. Screen Recording
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Screen Recording"
                        color: powerMenuVariants.fgColor
                        font.family: powerMenuVariants.activeFont
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: powerWin.isRecording
                            ? powerMenuVariants.errorColor
                            : Qt.rgba(1,1,1,0.1)
                        Text {
                            anchors.centerIn: parent
                            text: powerWin.isRecording ? "󰑮" : "󰻃"
                            color: powerWin.isRecording ? "#1a1a1a" : powerMenuVariants.fgColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                toggleRecordScript.running = true
                                powerWin.isRecording = !powerWin.isRecording
                                powerMenuVariants.requestClose()
                            }
                        }
                    }
                }

                // 3. Power Mode
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "Power Mode"
                        color: powerMenuVariants.fgColor
                        font.family: powerMenuVariants.activeFont
                        font.pixelSize: 14
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Power Saver
                        Rectangle {
                            Layout.fillWidth: true; height: 38; radius: 10
                            color: powerWin.powerMode === "power-saver"
                                ? powerMenuVariants.accentColor
                                : Qt.rgba(1,1,1,0.1)
                            Text {
                                anchors.centerIn: parent; text: "󰌪"
                                color: powerWin.powerMode === "power-saver"
                                    ? "#1a1a1a" : powerMenuVariants.fgColor
                                font.family: powerMenuVariants.activeFont
                                font.pixelSize: 16
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    setSaver.running = true
                                    powerWin.powerMode = "power-saver"
                                }
                            }
                        }

                        // Balanced
                        Rectangle {
                            Layout.fillWidth: true; height: 38; radius: 10
                            color: powerWin.powerMode === "balanced"
                                ? powerMenuVariants.accentColor
                                : Qt.rgba(1,1,1,0.1)
                            Text {
                                anchors.centerIn: parent; text: "󰾆"
                                color: powerWin.powerMode === "balanced"
                                    ? "#1a1a1a" : powerMenuVariants.fgColor
                                font.family: powerMenuVariants.activeFont
                                font.pixelSize: 16
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    setBalanced.running = true
                                    powerWin.powerMode = "balanced"
                                }
                            }
                        }

                        // Performance
                        Rectangle {
                            Layout.fillWidth: true; height: 38; radius: 10
                            color: powerWin.powerMode === "performance"
                                ? powerMenuVariants.accentColor
                                : Qt.rgba(1,1,1,0.1)
                            Text {
                                anchors.centerIn: parent; text: "󰓅"
                                color: powerWin.powerMode === "performance"
                                    ? "#1a1a1a" : powerMenuVariants.fgColor
                                font.family: powerMenuVariants.activeFont
                                font.pixelSize: 16
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    setPerf.running = true
                                    powerWin.powerMode = "performance"
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.1) }

                // 4. Power Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true; height: 46; radius: 12
                        color: Qt.rgba(1,1,1,0.05)
                        Text { anchors.centerIn: parent; text: "󰌾"; color: powerMenuVariants.fgColor; font.family: powerMenuVariants.activeFont; font.pixelSize: 18 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { lockCmd.running = true; powerMenuVariants.requestClose() }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 46; radius: 12
                        color: Qt.rgba(1,1,1,0.05)
                        Text { anchors.centerIn: parent; text: "󰜉"; color: powerMenuVariants.fgColor; font.family: powerMenuVariants.activeFont; font.pixelSize: 18 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { rebootCmd.running = true; powerMenuVariants.requestClose() }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 46; radius: 12
                        color: powerMenuVariants.errorColor
                        Text { anchors.centerIn: parent; text: "󰐥"; color: "#1a1a1a"; font.family: powerMenuVariants.activeFont; font.pixelSize: 18 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { shutdownCmd.running = true; powerMenuVariants.requestClose() }
                        }
                    }
                }
            }
        }
    }
}
