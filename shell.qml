import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"

ShellRoot {
    id: root
    property var visualizerData: new Array(32).fill(0)

    // ── MATUGEN COLORS ──────────────────────────────────────────────────────
    property color pillBg:      "#99000000"
    property color fgColor:     "#e0e4db"
    property color accentColor: "#9fd49b"
    property color errorColor:  "#ffb4ab"
    property color btColor:     "#a1ced5"

    property string activeFont: "Inter Nerd Font"
    property bool   calendarOpen: false

    property string musicTitle:  ""
    property string musicArtist: ""
    property bool   isPlaying:   false

    property int    cpuVal:     0
    property int    ramVal:     0
    property string wifiVal:    ""
    property string ethVal:     ""
    property string btVal:      ""
    property string battVal: ""
    property string battStatus: ""
    property string clockStr: Qt.formatDateTime(new Date(), "HH:mm")
    property bool powerMenuOpen: false

    // ── MATUGEN ─────────────────────────────────────────────────────────────
    Process {
        id: matugenProc
        command: ["sh", "-c", "jq -c . /home/tanishk/.config/niri-rice/matugen/colors.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim().split("\n").pop())
                    if (parsed.colors) {
                        let c = parsed.colors
                        if (c.on_surface)  root.fgColor     = c.on_surface
                        if (c.primary)     root.accentColor = c.primary
                        if (c.error)       root.errorColor  = c.error
                        if (c.tertiary)    root.btColor     = c.tertiary
                    }
                } catch(e) { console.log("Matugen parse error:", e) }
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: false; triggeredOnStart: true; onTriggered: matugenProc.running = true }
    Process {
        id: matugenWatcher
        command: ["sh", "-c", "inotifywait -m -e modify /home/tanishk/.config/niri-rice/matugen/colors.json 2>/dev/null"]
        running: true
        stdout: SplitParser { onRead: data => { matugenProc.running = true } }
    }

    // ── CLOCK ────────────────────────────────────────────────────────────────
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.clockStr = Qt.formatDateTime(new Date(), "HH:mm") }

    // ── MUSIC ────────────────────────────────────────────────────────────────
    Process {
        id: musicMeta
        command: ["playerctl", "metadata", "--format", "{{title}};;{{artist}}"]
        running: false
        stdout: SplitParser { onRead: data => {
            let p = data.trim().split(";;")
            root.musicTitle = p[0] || ""; root.musicArtist = p[1] || ""
        }}
    }
    Process {
        id: musicStatus; command: ["playerctl", "status"]; running: false
        stdout: SplitParser { onRead: data => { root.isPlaying = data.trim() === "Playing" } }
    }
    Process {
        id: battProc
        command: ["sh", "-c", "echo \"$(cat /sys/class/power_supply/BAT1/capacity);$(cat /sys/class/power_supply/BAT1/status)\""]
        running: false
        stdout: SplitParser { onRead: data => { 
            let parts = data.trim().split(";");
            if (parts.length === 2) {
                root.battVal = parts[0];
                root.battStatus = parts[1];
            }
        }}
    }

    // ── SYSTEM INFO ──────────────────────────────────────────────────────────
    Process {
        id: wifiProc
        command: ["sh", "-c", "ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | cut -d: -f2-); echo \"$ssid\""]
        running: false
        stdout: SplitParser { onRead: data => { root.wifiVal = data.trim() } }
    }
    Process {
        id: btProc
        command: ["sh", "-c", "bt=$(bluetoothctl devices Connected | head -n1 | cut -d' ' -f3-); echo \"$bt\""]
        running: false
        stdout: SplitParser { onRead: data => { root.btVal = data.trim() } }
    }
    Process {
        id: ethProc
        command: ["sh", "-c", "dev=$(nmcli -t -f TYPE,STATE,DEVICE device | awk -F: '$1==\"ethernet\" && $2==\"connected\"{print $3; exit}'); echo \"$dev\""]
        running: false
        stdout: SplitParser { onRead: data => { root.ethVal = data.trim() } }
    }
    Process {
        id: cpuProc
        command: ["sh", "-c",
            "cat /proc/stat | awk 'NR==1{u=$2+$3+$4+$6+$7+$8; i=$5; print u,i}' > /tmp/.qs_cpu1; " +
            "sleep 0.5; " +
            "cat /proc/stat | awk 'NR==1{u=$2+$3+$4+$6+$7+$8; i=$5; print u,i}' | " +
            "awk '{getline l < \"/tmp/.qs_cpu1\"; split(l,a); du=$1-a[1]; di=$2-a[2]; dt=du+di; print (dt>0?int(100*du/dt):0)}'"]
        running: false
        stdout: SplitParser { onRead: data => { let v = parseInt(data); if (!isNaN(v)) root.cpuVal = v } }
    }
    Process {
        id: ramProc; command: ["sh", "-c", "free | awk '/Mem:/{print int($3/$2*100)}'"];  running: false
        stdout: SplitParser { onRead: data => { let v = parseInt(data); if (!isNaN(v)) root.ramVal = v } }
    }

    // ── VISUALIZER ───────────────────────────────────────────────────────────
    Process {
        id: rustViz
        command: ["/home/tanishk/.config/niri-rice/qs-visualizer/target/release/qs-visualizer"]
        running: true
        stdout: SplitParser { onRead: data => {
            try {
                let p = JSON.parse(data.trim())
                if (p.length === 32) root.visualizerData = p
            } catch(e) {}
        }}
    }

    // ── ACTIONS ──────────────────────────────────────────────────────────────
    Process { id: wifiAction;     command: ["sh", "-c", "alacritty -e nmtui &"] }
    Process { id: btAction;       command: ["sh", "-c", "blueman-manager &"] }
    Process { id: musicPlayPause; command: ["playerctl", "play-pause"] }
    Process { id: musicNext;      command: ["playerctl", "next"] }
    Process { id: musicPrev;      command: ["playerctl", "previous"] }

    // ── POLL TIMERS ──────────────────────────────────────────────────────────
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { cpuProc.running = true; ramProc.running = true; wifiProc.running = true; ethProc.running = true; btProc.running = true;battProc.running = true; } }
    Timer { interval: 1000; running: true; repeat: true
        onTriggered: { musicMeta.running = true; musicStatus.running = true } }

    // ── BAR ──────────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 50
            color: "transparent"

            Item {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                // 1. Left Aligned
                RowLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    
                    SystemPill {
                        pillBg: root.pillBg; fgColor: root.fgColor
                        accentColor: root.accentColor; errorColor: root.errorColor
                        activeFont: root.activeFont
                        cpuVal: root.cpuVal; ramVal: root.ramVal
                    }
                }

                // 2. Center Aligned (Strictly Centered)
                RowLayout {
                    anchors.centerIn: parent
                    
                    MusicPill {
                        accentColor: root.accentColor; fgColor: root.fgColor
                        activeFont: root.activeFont
                        musicTitle: root.musicTitle
                        visualizerData: root.visualizerData
                        onPrevClicked:      musicPrev.running      = true
                        onPlayPauseClicked: musicPlayPause.running = true
                        onNextClicked:      musicNext.running      = true
                    }
                }

                // 3. Right Aligned
                RowLayout {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    
                    StatusPill {
                        pillBg: root.pillBg; fgColor: root.fgColor
                        accentColor: root.accentColor; errorColor: root.errorColor
                        btColor: root.btColor; activeFont: root.activeFont
                        
                        ethVal: root.ethVal
                        wifiVal: root.wifiVal; btVal: root.btVal
                        clockStr: root.clockStr; calendarOpen: root.calendarOpen
                        
                        battVal: root.battVal
                        battStatus: root.battStatus

                        onEthClicked:      wifiAction.running = true 
                        onWifiClicked:     wifiAction.running = true
                        onBtClicked:       btAction.running   = true
                        onClockClicked:    root.calendarOpen  = !root.calendarOpen
                        onPowerClicked:    root.powerMenuOpen = !root.powerMenuOpen // <--- Wired up here!
                    }
                }
            }
        }
    }
    // ── CALENDAR ─────────────────────────────────────────────────────────────
    CalendarPopup {
        calendarOpen: root.calendarOpen
        accentColor:  root.accentColor
        fgColor:      root.fgColor
        activeFont:   root.activeFont
    }
    // ── POWER MENU ───────────────────────────────────────────────────────────
   // ── POWER MENU ───────────────────────────────────────────────────────────
    PowerMenu {
        powerMenuOpen: root.powerMenuOpen
        accentColor:   root.accentColor
        fgColor:       root.fgColor
        errorColor:    root.errorColor
        activeFont:    root.activeFont
        
        // Safely resets the state in the parent without breaking the binding!
        onRequestClose: root.powerMenuOpen = false
    }
}