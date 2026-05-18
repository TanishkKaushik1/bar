import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

QtObject {
    id: root

    property bool   powerMenuOpen: false
    property color  accentColor:   "#9fd49b"
    property color  fgColor:       "#e0e4db"
    property color  errorColor:    "#ffb4ab"
    property color  gamingColor:   "#cba6f7"   // purple accent for gaming mode
    property string activeFont:    "Inter Nerd Font"

    signal requestClose()

    // ── Recording state ───────────────────────────────────────────────────────
    property bool isRecording: false
    property int  recSeconds:  0

    function recTimeStr() {
        var s = recSeconds
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        if (h > 0)
            return h + ":" + String(m).padStart(2,"0") + ":" + String(sec).padStart(2,"0")
        return String(m).padStart(2,"0") + ":" + String(sec).padStart(2,"0")
    }

    property var _recTimer: Timer {
        interval: 1000; repeat: true
        running: root.isRecording
        onTriggered: root.recSeconds += 1
    }

    property var _pollTimer: Timer {
        interval: 2000; repeat: true
        running: root.isRecording
        onTriggered: { _checkRec.running = false; _checkRec.running = true }
    }

    property var _checkRec: Process {
        id: _checkRec
        command: ["sh", "-c", "[ -f /tmp/.wf-recorder-running ] && echo 1 || echo 0"]
        onExited: (c,s) => { running = false }
        stdout: SplitParser {
            onRead: data => {
                var rec = data.trim() === "1"
                if (!rec && root.isRecording) root.recSeconds = 0
                root.isRecording = rec
            }
        }
    }

    property var _startRec: Process {
        id: _startRec
        command: ["bash", "/home/tanishk/.config/niri-rice/scripts/toggle-record.sh", "start"]
        onExited: (c,s) => { running = false; _verifyTimer.restart() }
    }

    property var _stopRec: Process {
        id: _stopRec
        command: ["bash", "/home/tanishk/.config/niri-rice/scripts/toggle-record.sh", "stop"]
        onExited: (c,s) => { running = false }
    }

    property var _verifyTimer: Timer {
        id: _verifyTimer
        interval: 600; repeat: false
        onTriggered: { _checkRec.running = false; _checkRec.running = true }
    }

    // ── Gaming mode state ─────────────────────────────────────────────────────
    // Checked by polling the flag file the Rust backend writes
    property bool isGamingMode: false

    property var _checkGaming: Process {
        id: _checkGaming
        command: ["sh", "-c", "[ -f /tmp/.wallpaper-gamemode ] && echo 1 || echo 0"]
        onExited: (c,s) => { running = false }
        stdout: SplitParser {
            onRead: data => { root.isGamingMode = data.trim() === "1" }
        }
    }

    // Pause wallpaper (gaming on)
    property var _gamingOn: Process {
        id: _gamingOn
        command: ["/home/tanishk/.config/niri-rice/Wallpaper-switcher/backend/target/release/wallpaper-switcher", "pause"]
        onExited: (c,s) => {
            running = false
            // Also lower quickshell process priority while gaming
            _lowerQS.running = false; _lowerQS.running = true
            _checkGaming.running = false; _checkGaming.running = true
        }
    }

    // Resume wallpaper (gaming off)
    property var _gamingOff: Process {
        id: _gamingOff
        command: ["/home/tanishk/.config/niri-rice/Wallpaper-switcher/backend/target/release/wallpaper-switcher", "resume"]
        onExited: (c,s) => {
            running = false
            _restoreQS.running = false; _restoreQS.running = true
            _checkGaming.running = false; _checkGaming.running = true
        }
    }

    // Renice quickshell to +10 when gaming (less CPU stolen from game)
    property var _lowerQS: Process {
        id: _lowerQS
        command: ["sh", "-c", "renice +10 $(pgrep -x quickshell) 2>/dev/null; ionice -c 3 -p $(pgrep -x quickshell) 2>/dev/null"]
        onExited: (c,s) => { running = false }
    }

    // Restore quickshell priority on exit
    property var _restoreQS: Process {
        id: _restoreQS
        command: ["sh", "-c", "renice 0 $(pgrep -x quickshell) 2>/dev/null"]
        onExited: (c,s) => { running = false }
    }

    onPowerMenuOpenChanged: {
        if (powerMenuOpen) {
            _checkRec.running = false; _checkRec.running = true
            _checkGaming.running = false; _checkGaming.running = true
        }
    }

    // ── Per-screen windows ────────────────────────────────────────────────────
    property var _variants: Variants {
        id: powerMenuVariants
        model: Quickshell.screens

        PanelWindow {
            id: powerWin
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.powerMenuOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.powerMenuOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            property string powerMode: "balanced"
            property int    volume:    50

            Process {
                id: getPowerMode
                command: ["sh", "-c", "powerprofilesctl get"]
                running: root.powerMenuOpen
                onExited: (c,s) => { running = false }
                stdout: SplitParser { onRead: data => { powerWin.powerMode = data.trim() } }
            }

            Process {
                id: getVolume
                command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{v=$2*100; if(v>150)v=150; printf \"%d\",v}'"]
                running: root.powerMenuOpen
                onExited: (c,s) => { running = false }
                stdout: SplitParser {
                    onRead: data => {
                        var v = parseInt(data.trim())
                        if (!isNaN(v)) powerWin.volume = v
                    }
                }
            }

            Process {
                id: setVolume
                property int targetVol: 50
                command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (targetVol / 100).toFixed(2)]
                onExited: (c,s) => { running = false }
            }

            Process { id: setSaver;    command: ["powerprofilesctl", "set", "power-saver"];  onExited: (c,s) => { running = false } }
            Process { id: setBalanced; command: ["powerprofilesctl", "set", "balanced"];     onExited: (c,s) => { running = false } }
            Process { id: setPerf;     command: ["powerprofilesctl", "set", "performance"];  onExited: (c,s) => { running = false } }

            Process { id: lockCmd;     command: ["swaylock"] }
            Process { id: logoutCmd;   command: ["sh", "-c", "loginctl terminate-session $XDG_SESSION_ID"] }
            Process { id: rebootCmd;   command: ["systemctl", "reboot"] }
            Process { id: shutdownCmd; command: ["systemctl", "poweroff"] }

            MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
            }

            Rectangle {
                width: 340
                height: menuCol.implicitHeight + 40
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 56; anchors.rightMargin: 5
                color: "#ee0d0d0d"
                border.color: Qt.rgba(1,1,1,0.08)
                radius: 14

                // Purple glow behind card when gaming mode is active
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: root.isGamingMode ? Qt.rgba(0.8, 0.65, 0.97, 0.5) : "transparent"
                    border.width: root.isGamingMode ? 2 : 0
                    Behavior on border.color { ColorAnimation { duration: 300 } }
                    Behavior on border.width { NumberAnimation { duration: 300 } }
                }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: menuCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 20
                    spacing: 14

                    // 1. Profile
                    RowLayout {
                        Layout.fillWidth: true; spacing: 14
                        Rectangle {
                            width: 52; height: 52; radius: 26
                            color: Qt.rgba(1,1,1,0.1)
                            Text {
                                anchors.centerIn: parent; text: ""
                                color: root.isGamingMode ? root.gamingColor : root.accentColor
                                font.family: root.activeFont; font.pixelSize: 26
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }
                        Column {
                            Layout.alignment: Qt.AlignVCenter; spacing: 2
                            Text {
                                text: "Tanishk"; color: root.fgColor
                                font.family: root.activeFont
                                font.pixelSize: 17; font.weight: Font.Bold
                            }
                            // Gaming mode badge under name
                            Row {
                                visible: root.isGamingMode; spacing: 5
                                Text { text: "󰊗"; font.family: root.activeFont; font.pixelSize: 10; color: root.gamingColor; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "Gaming Mode  ON"
                                    color: root.gamingColor
                                    font.family: root.activeFont; font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Row {
                                visible: root.isRecording && !root.isGamingMode; spacing: 5
                                Text { text: "🔴"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "Recording  " + root.recTimeStr()
                                    color: root.errorColor
                                    font.family: root.activeFont; font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 2. Screen Recording
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Column {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 2
                            Text {
                                text: "Screen Recording"; color: root.fgColor
                                font.family: root.activeFont; font.pixelSize: 14
                            }
                            Text {
                                visible: root.isRecording
                                text: root.recTimeStr(); color: root.errorColor
                                font.family: root.activeFont; font.pixelSize: 11
                            }
                        }
                        Rectangle {
                            visible: root.isRecording
                            width: 68; height: 32; radius: 8; color: root.errorColor
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: "󰓛"; color: "#1a1a1a"; font.family: root.activeFont; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Stop"; color: "#1a1a1a"; font.family: root.activeFont; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    _stopRec.running = false; _stopRec.running = true
                                    root.isRecording = false; root.recSeconds = 0
                                }
                            }
                        }
                        Rectangle {
                            visible: !root.isRecording
                            width: 40; height: 40; radius: 20; color: Qt.rgba(1,1,1,0.1)
                            Text { anchors.centerIn: parent; text: "󰻃"; color: root.fgColor; font.family: root.activeFont; font.pixelSize: 16 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    _startRec.running = false; _startRec.running = true
                                    root.isRecording = true; root.recSeconds = 0
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 3. Volume 0-150%
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: powerWin.volume === 0 ? "󰝟" : powerWin.volume < 40 ? "󰕿" : powerWin.volume < 100 ? "󰖀" : "󰕾"
                                color: root.accentColor; font.family: root.activeFont; font.pixelSize: 16
                            }
                            Text { text: "Volume"; color: root.fgColor; font.family: root.activeFont; font.pixelSize: 14; Layout.fillWidth: true; leftPadding: 6 }
                            Text { text: powerWin.volume + "%"; color: Qt.rgba(1,1,1,0.5); font.family: root.activeFont; font.pixelSize: 12 }
                        }
                        Item {
                            Layout.fillWidth: true; height: 28
                            Rectangle {
                                id: track
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.right: parent.right
                                height: 5; radius: 3; color: Qt.rgba(1,1,1,0.12)
                                Rectangle { x: parent.width*(100/150)-1; width: 2; height: parent.height; color: Qt.rgba(1,1,1,0.3); radius: 1 }
                                Rectangle {
                                    width: parent.width*(powerWin.volume/150); height: parent.height; radius: parent.radius
                                    color: powerWin.volume > 100 ? "#f0c040" : root.accentColor
                                }
                            }
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: powerWin.volume > 100 ? "#f0c040" : root.accentColor
                                border.color: Qt.rgba(0,0,0,0.3); border.width: 1
                                anchors.verticalCenter: track.verticalCenter
                                x: (track.width-width)*(powerWin.volume/150)
                            }
                            MouseArea {
                                anchors.fill: parent; preventStealing: true; cursorShape: Qt.PointingHandCursor
                                function updateVol(mx) {
                                    var vol = Math.round(Math.max(0,Math.min(1,mx/width))*150)
                                    powerWin.volume = vol
                                    setVolume.targetVol = vol
                                    setVolume.running = false; setVolume.running = true
                                }
                                onClicked: (m) => updateVol(m.x)
                                onPositionChanged: (m) => { if(pressed) updateVol(m.x) }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 4. Power Mode
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "Power Mode"; color: root.fgColor; font.family: root.activeFont; font.pixelSize: 14 }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: [
                                    { label: "Saver",   mode: "power-saver",  icon: "󰌪" },
                                    { label: "Balance", mode: "balanced",      icon: "󰾆" },
                                    { label: "Perf",    mode: "performance",   icon: "󰓅" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; height: 44; radius: 10
                                    color: powerWin.powerMode === modelData.mode ? root.accentColor : Qt.rgba(1,1,1,0.08)
                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: powerWin.powerMode === modelData.mode ? "#1a1a1a" : root.fgColor; font.family: root.activeFont; font.pixelSize: 15 }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: powerWin.powerMode === modelData.mode ? "#1a1a1a" : Qt.rgba(1,1,1,0.5); font.family: root.activeFont; font.pixelSize: 9 }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            powerWin.powerMode = modelData.mode
                                            var p = modelData.mode === "power-saver" ? setSaver : modelData.mode === "balanced" ? setBalanced : setPerf
                                            p.running = false; p.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 5. ── GAMING MODE ─────────────────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰊗"
                                color: root.isGamingMode ? root.gamingColor : Qt.rgba(1,1,1,0.5)
                                font.family: root.activeFont; font.pixelSize: 16
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Text {
                                text: "Gaming Mode"
                                color: root.fgColor
                                font.family: root.activeFont; font.pixelSize: 14
                                leftPadding: 6
                                Layout.fillWidth: true
                            }
                            // Status pill
                            Rectangle {
                                width: statusLabel.implicitWidth + 14
                                height: 20; radius: 10
                                color: root.isGamingMode ? Qt.rgba(0.8,0.65,0.97,0.2) : Qt.rgba(1,1,1,0.07)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Text {
                                    id: statusLabel
                                    anchors.centerIn: parent
                                    text: root.isGamingMode ? "ON" : "OFF"
                                    color: root.isGamingMode ? root.gamingColor : Qt.rgba(1,1,1,0.35)
                                    font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        // Toggle row — OFF / ON buttons like Power Mode
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            // OFF button
                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: !root.isGamingMode ? root.accentColor : Qt.rgba(1,1,1,0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰌾"
                                        color: !root.isGamingMode ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 15
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Normal"
                                        color: !root.isGamingMode ? "#1a1a1a" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.isGamingMode) {
                                            _gamingOff.running = false; _gamingOff.running = true
                                            root.isGamingMode = false
                                        }
                                    }
                                }
                            }

                            // ON button (purple, like "Perf" is highlighted in your screenshot)
                            Rectangle {
                                Layout.fillWidth: true; height: 44; radius: 10
                                color: root.isGamingMode ? root.gamingColor : Qt.rgba(1,1,1,0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰊗"
                                        color: root.isGamingMode ? "#1a1a1a" : root.fgColor
                                        font.family: root.activeFont; font.pixelSize: 15
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Gaming"
                                        color: root.isGamingMode ? "#1a1a1a" : Qt.rgba(1,1,1,0.5)
                                        font.family: root.activeFont; font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.isGamingMode) {
                                            _gamingOn.running = false; _gamingOn.running = true
                                            root.isGamingMode = true
                                        }
                                    }
                                }
                            }
                        }

                        // Helper text
                        Text {
                            Layout.fillWidth: true
                            text: root.isGamingMode
                                ? "Wallpaper paused · Quickshell deprioritized"
                                : "Pauses animated wallpaper for max FPS"
                            color: Qt.rgba(1,1,1,0.3)
                            font.family: root.activeFont; font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Item { height: 2 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

                    // 6. Power Actions
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [
                                { icon: "󰌾", label: "Lock",   accent: false, action: "lock"     },
                                { icon: "󰍃", label: "Logout", accent: false, action: "logout"   },
                                { icon: "󰜉", label: "Reboot", accent: false, action: "reboot"   },
                                { icon: "󰐥", label: "Off",    accent: true,  action: "shutdown" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; height: 52; radius: 12
                                color: modelData.accent ? root.errorColor : Qt.rgba(1,1,1,0.05)
                                Column {
                                    anchors.centerIn: parent; spacing: 3
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: modelData.accent ? "#1a1a1a" : root.fgColor; font.family: root.activeFont; font.pixelSize: 17 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: modelData.accent ? "#1a1a1a" : Qt.rgba(1,1,1,0.45); font.family: root.activeFont; font.pixelSize: 9 }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if      (modelData.action === "lock")     lockCmd.running     = true
                                        else if (modelData.action === "logout")   logoutCmd.running   = true
                                        else if (modelData.action === "reboot")   rebootCmd.running   = true
                                        else if (modelData.action === "shutdown") shutdownCmd.running = true
                                        root.requestClose()
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
}
