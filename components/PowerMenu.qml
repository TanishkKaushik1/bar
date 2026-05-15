import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    id: powerMenuVariants
    model: Quickshell.screens

    property bool   powerMenuOpen: false
    property color  accentColor:   "#9fd49b"
    property color  fgColor:       "#e0e4db"
    property color  errorColor:    "#ffb4ab"
    property string activeFont:    "Inter Nerd Font"

    signal requestClose()

    // ── Recording state lives HERE (outside PanelWindow) ─────────────────────
    // This means closing/hiding the menu cannot kill these processes.
    property bool   isRecording: false
    property int    recSeconds:  0

    // Elapsed timer — ticks while recording, persists across menu open/close
    Timer {
        id: recTimer
        interval: 1000
        repeat: true
        running: powerMenuVariants.isRecording
        onTriggered: powerMenuVariants.recSeconds += 1
    }

    function recTimeStr() {
        var s = powerMenuVariants.recSeconds
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        if (h > 0)
            return h + ":" + String(m).padStart(2,"0") + ":" + String(sec).padStart(2,"0")
        return String(m).padStart(2,"0") + ":" + String(sec).padStart(2,"0")
    }

    // Poll actual recording state (runs when menu opens, and every 2s while recording)
    Process {
        id: checkRecording
        command: ["sh", "-c",
            "if [ -f /tmp/wf-recorder.pid ] && kill -0 $(cat /tmp/wf-recorder.pid) 2>/dev/null; then echo 1; else echo 0; fi"]
        onExited: (c,s) => { running = false }
        stdout: SplitParser {
            onRead: data => {
                var nowRecording = (data.trim() === "1")
                if (!nowRecording && powerMenuVariants.isRecording) {
                    // stopped externally — reset timer
                    powerMenuVariants.recSeconds = 0
                }
                powerMenuVariants.isRecording = nowRecording
            }
        }
    }

    // Poll when menu opens
    onPowerMenuOpenChanged: {
        if (powerMenuOpen) {
            checkRecording.running = false
            checkRecording.running = true
        }
    }

    // Also poll every 2s while recording so state stays accurate
    Timer {
        interval: 2000
        repeat: true
        running: powerMenuVariants.isRecording
        onTriggered: {
            checkRecording.running = false
            checkRecording.running = true
        }
    }

    // Start recording — script detaches wf-recorder so closing menu is safe
    Process {
        id: startRecord
        command: ["/home/tanishk/.config/niri-rice/scripts/toggle-record.sh", "start"]
        onExited: (c,s) => { running = false }
    }

    // Stop recording
    Process {
        id: stopRecord
        command: ["/home/tanishk/.config/niri-rice/scripts/toggle-record.sh", "stop"]
        onExited: (c,s) => { running = false }
    }

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

        // ── Per-window state (non-recording) ─────────────────────────────────
        property string powerMode: "balanced"
        property int    volume:    50

        // Poll power mode on open
        Process {
            id: getPowerMode
            command: ["sh", "-c", "powerprofilesctl get"]
            running: powerMenuVariants.powerMenuOpen
            onExited: (c,s) => { running = false }
            stdout: SplitParser {
                onRead: data => { powerWin.powerMode = data.trim() }
            }
        }

        // Get volume on open
        Process {
            id: getVolume
            command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d\", $2*100}'"]
            running: powerMenuVariants.powerMenuOpen
            onExited: (c,s) => { running = false }
            stdout: SplitParser {
                onRead: data => {
                    var v = parseInt(data.trim())
                    if (!isNaN(v)) powerWin.volume = Math.min(100, v)
                }
            }
        }

        Process {
            id: setVolume
            property int targetVol: 50
            command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + targetVol + "%"]
            onExited: (c,s) => { running = false }
        }

        Process { id: setSaver;    command: ["powerprofilesctl", "set", "power-saver"];  onExited: (c,s) => { running = false } }
        Process { id: setBalanced; command: ["powerprofilesctl", "set", "balanced"];     onExited: (c,s) => { running = false } }
        Process { id: setPerf;     command: ["powerprofilesctl", "set", "performance"];  onExited: (c,s) => { running = false } }

        Process { id: lockCmd;     command: ["swaylock"] }
        Process { id: logoutCmd;   command: ["sh", "-c", "loginctl terminate-session $XDG_SESSION_ID"] }
        Process { id: rebootCmd;   command: ["systemctl", "reboot"] }
        Process { id: shutdownCmd; command: ["systemctl", "poweroff"] }

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            onClicked: powerMenuVariants.requestClose()
        }

        // ── Menu box ──────────────────────────────────────────────────────────
        Rectangle {
            width: 340
            height: menuCol.implicitHeight + 40
            anchors.top:         parent.top
            anchors.right:       parent.right
            anchors.topMargin:   56
            anchors.rightMargin: 5

            color: "#ee0d0d0d"
            border.color: Qt.rgba(1,1,1,0.08)
            radius: 14

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: menuCol
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.top:     parent.top
                anchors.margins: 20
                spacing: 14

                // ── 1. Profile ────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Rectangle {
                        width: 52; height: 52; radius: 26
                        color: Qt.rgba(1,1,1,0.1)
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: powerMenuVariants.accentColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 26
                        }
                    }
                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        Text {
                            text: "Tanishk"
                            color: powerMenuVariants.fgColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 17; font.weight: Font.Bold
                        }
                        Row {
                            spacing: 6
                            Text {
                                text: powerMenuVariants.isRecording ? "🔴" : "●"
                                color: powerMenuVariants.isRecording
                                    ? powerMenuVariants.errorColor
                                    : Qt.rgba(1,1,1,0.25)
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: powerMenuVariants.isRecording
                                    ? "Recording  " + powerMenuVariants.recTimeStr()
                                    : "Ready"
                                color: powerMenuVariants.isRecording
                                    ? powerMenuVariants.errorColor
                                    : Qt.rgba(1,1,1,0.45)
                                font.family: powerMenuVariants.activeFont
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                // ── 2. Screen Recording ───────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        Text {
                            text: "Screen Recording"
                            color: powerMenuVariants.fgColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 14
                        }
                        Text {
                            visible: powerMenuVariants.isRecording
                            text: powerMenuVariants.recTimeStr()
                            color: powerMenuVariants.errorColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 11
                        }
                    }

                    // Stop button
                    Rectangle {
                        visible: powerMenuVariants.isRecording
                        width: 68; height: 32; radius: 8
                        color: powerMenuVariants.errorColor
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰓛"
                                color: "#1a1a1a"
                                font.family: powerMenuVariants.activeFont
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Stop"
                                color: "#1a1a1a"
                                font.family: powerMenuVariants.activeFont
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                stopRecord.running = false
                                stopRecord.running = true
                                powerMenuVariants.isRecording = false
                                powerMenuVariants.recSeconds = 0
                            }
                        }
                    }

                    // Start button
                    Rectangle {
                        visible: !powerMenuVariants.isRecording
                        width: 40; height: 40; radius: 20
                        color: Qt.rgba(1,1,1,0.1)
                        Text {
                            anchors.centerIn: parent
                            text: "󰻃"
                            color: powerMenuVariants.fgColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                startRecord.running = false
                                startRecord.running = true
                                powerMenuVariants.isRecording = true
                                powerMenuVariants.recSeconds = 0
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                // ── 3. Volume Slider ──────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: powerWin.volume === 0 ? "󰝟"
                                : powerWin.volume < 40  ? "󰕿"
                                : powerWin.volume < 75  ? "󰖀"
                                :                         "󰕾"
                            color: powerMenuVariants.accentColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 16
                        }
                        Text {
                            text: "Volume"
                            color: powerMenuVariants.fgColor
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            leftPadding: 6
                        }
                        Text {
                            text: powerWin.volume + "%"
                            color: Qt.rgba(1,1,1,0.5)
                            font.family: powerMenuVariants.activeFont
                            font.pixelSize: 12
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 28

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 5; radius: 3
                            color: Qt.rgba(1,1,1,0.12)
                            Rectangle {
                                width: parent.width * (powerWin.volume / 100)
                                height: parent.height
                                radius: parent.radius
                                color: powerMenuVariants.accentColor
                            }
                        }

                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: powerMenuVariants.accentColor
                            border.color: Qt.rgba(0,0,0,0.3)
                            border.width: 1
                            anchors.verticalCenter: track.verticalCenter
                            x: (track.width - width) * (powerWin.volume / 100)
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            function updateVol(mx) {
                                var vol = Math.round(Math.max(0, Math.min(1, mx / width)) * 100)
                                powerWin.volume = vol
                                setVolume.targetVol = vol
                                setVolume.running = false
                                setVolume.running = true
                            }
                            onClicked: (mouse) => updateVol(mouse.x)
                            onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x) }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                // ── 4. Power Mode ─────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Power Mode"
                        color: powerMenuVariants.fgColor
                        font.family: powerMenuVariants.activeFont
                        font.pixelSize: 14
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [
                                { label: "Saver",   mode: "power-saver",  icon: "󰌪" },
                                { label: "Balance", mode: "balanced",      icon: "󰾆" },
                                { label: "Perf",    mode: "performance",   icon: "󰓅" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 44; radius: 10
                                color: powerWin.powerMode === modelData.mode
                                    ? powerMenuVariants.accentColor
                                    : Qt.rgba(1,1,1,0.08)
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        color: powerWin.powerMode === modelData.mode ? "#1a1a1a" : powerMenuVariants.fgColor
                                        font.family: powerMenuVariants.activeFont
                                        font.pixelSize: 15
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: powerWin.powerMode === modelData.mode ? "#1a1a1a" : Qt.rgba(1,1,1,0.5)
                                        font.family: powerMenuVariants.activeFont
                                        font.pixelSize: 9
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        powerWin.powerMode = modelData.mode
                                        var proc = modelData.mode === "power-saver" ? setSaver
                                                 : modelData.mode === "balanced"    ? setBalanced
                                                 : setPerf
                                        proc.running = false
                                        proc.running = true
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 2 }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                // ── 5. Power Actions ──────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { icon: "󰌾", label: "Lock",   accent: false, action: "lock"     },
                            { icon: "󰍃", label: "Logout", accent: false, action: "logout"   },
                            { icon: "󰜉", label: "Reboot", accent: false, action: "reboot"   },
                            { icon: "󰐥", label: "Off",    accent: true,  action: "shutdown" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 52; radius: 12
                            color: modelData.accent ? powerMenuVariants.errorColor : Qt.rgba(1,1,1,0.05)
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    color: modelData.accent ? "#1a1a1a" : powerMenuVariants.fgColor
                                    font.family: powerMenuVariants.activeFont
                                    font.pixelSize: 17
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: modelData.accent ? "#1a1a1a" : Qt.rgba(1,1,1,0.45)
                                    font.family: powerMenuVariants.activeFont
                                    font.pixelSize: 9
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if      (modelData.action === "lock")     lockCmd.running     = true
                                    else if (modelData.action === "logout")   logoutCmd.running   = true
                                    else if (modelData.action === "reboot")   rebootCmd.running   = true
                                    else if (modelData.action === "shutdown") shutdownCmd.running = true
                                    powerMenuVariants.requestClose()
                                }
                            }
                        }
                    }
                }

                Item { height: 4 }
            }
        }
    }
}
