import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../dashboard"

Scope {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"
  property bool barVisible: true

  property var activePlayer: {
    const players = Mpris.players.values;
    if (!players || players.length === 0) return null;
    for (const p of players) {
      if (p.playbackState === MprisPlaybackState.Playing) return p;
    }
    return players[0];
  }

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barVisible = !root.barVisible; }
  }

  IpcHandler {
    target: "dashboard"
    function toggle(): void { root.toggleDashboard() }
  }

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  property real brightnessValue: 0
  property real brightnessMax: 1
  property bool hasBrightness: false
  property string brightnessMethod: ""
  property var ddcMonitors: []
  property int selectedMonitorBus: -1

  function parseDdcDetect(text) {
    const monitors = []
    const blocks = text.split("Display ")
    for (let i = 1; i < blocks.length; i++) {
      const block = blocks[i]
      const busMatch = block.match(/I2C bus:\s+\/dev\/i2c-(\d+)/)
      const modelMatch = block.match(/Model:\s+(.+)/)
      const mfgMatch = block.match(/Mfg id:\s+(.+)/)
      const vcpMatch = block.match(/VCP version:\s+(.+)/)
      if (busMatch) {
        const bus = parseInt(busMatch[1])
        const model = modelMatch ? modelMatch[1].trim() : "Unknown"
        const mfg = mfgMatch ? mfgMatch[1].trim() : ""
        const vcpOk = vcpMatch && !vcpMatch[1].includes("Detection failed")
        monitors.push({ bus: bus, model: model, mfg: mfg, vcpOk: vcpOk, label: mfg + " " + model })
      }
    }
    return monitors
  }

  Process {
    id: ddcDetectProc
    command: ["ddcutil", "detect"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.ddcMonitors = root.parseDdcDetect(text)
        if (root.ddcMonitors.length > 0 && root.selectedMonitorBus === -1) {
          for (let i = 0; i < root.ddcMonitors.length; i++) {
            if (root.ddcMonitors[i].vcpOk) {
              root.selectedMonitorBus = root.ddcMonitors[i].bus
              break
            }
          }
          if (root.selectedMonitorBus === -1) {
            root.selectedMonitorBus = root.ddcMonitors[0].bus
          }
          updateBrightnessPoll()
          brightnessPollProc.running = true
        }
      }
    }
  }

  Process {
    id: brightnessReadProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length >= 2) {
          const cur = parseInt(lines[0]);
          const max = parseInt(lines[1]);
          if (!isNaN(cur) && !isNaN(max) && max > 0) {
            root.brightnessMax = max;
            root.brightnessValue = cur / max;
            root.hasBrightness = true;
          }
        }
      }
    }
  }

  Process { id: brightnessSetProc; running: false }

  property bool dashShown: false

  function showDashboard() {
    dashHideTimer.stop()
    dashboardPopup.visible = true
    root.dashShown = true
  }

  function hideDashboard() {
    root.dashShown = false
    dashHideTimer.restart()
  }

  function toggleDashboard() {
    if (root.dashShown) root.hideDashboard()
    else root.showDashboard()
  }

  Timer {
    id: dashHideTimer
    interval: 350
    onTriggered: dashboardPopup.visible = false
  }

  Process {
    id: brightnessDiscover
    command: ["sh", "-c", "bc_max=$(brightnessctl max 2>/dev/null); if [ -n \"$bc_max\" ] && [ \"$bc_max\" -gt 1 ] 2>/dev/null; then echo 'brightnessctl'; brightnessctl get; echo \"$bc_max\"; elif ddcutil getvcp 10 2>/dev/null | grep -q 'current'; then echo 'ddcutil'; ddcutil getvcp 10 2>/dev/null | awk '/current/{for(i=1;i<=NF;i++)if($i ~ /^[0-9]+$/){print $i; exit}}'; ddcutil getvcp 10 2>/dev/null | awk '/max/{for(i=NF;i>0;i--)if($i ~ /^[0-9]+$/){print $i; exit}}'; else echo 'none'; fi"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines[0] === "brightnessctl" && lines.length >= 3) {
          root.brightnessMethod = "brightnessctl";
          const cur = parseInt(lines[1]);
          const max = parseInt(lines[2]);
          if (!isNaN(cur) && !isNaN(max) && max > 0) {
            root.brightnessMax = max;
            root.brightnessValue = cur / max;
            root.hasBrightness = true;
          }
        } else if (lines[0] === "ddcutil" && lines.length >= 3) {
          root.brightnessMethod = "ddcutil";
          const cur = parseInt(lines[1]);
          const max = parseInt(lines[2]);
          if (!isNaN(cur) && !isNaN(max) && max > 0) {
            root.brightnessMax = max;
            root.brightnessValue = cur / max;
            root.hasBrightness = true;
          }
        } else {
          root.hasBrightness = false;
        }
      }
    }
  }

  Timer {
    interval: 10000; running: true; repeat: true
    onTriggered: {
      updateBrightnessPoll();
      brightnessPollProc.running = true;
    }
  }

  Process {
    id: brightnessPollProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length >= 2) {
          const cur = parseInt(lines[0]);
          const max = parseInt(lines[1]);
          if (!isNaN(cur) && !isNaN(max) && max > 0) {
            root.brightnessMax = max;
            root.brightnessValue = cur / max;
          }
        }
      }
    }
  }

  Component.onCompleted: {
    brightnessDiscover.running = true;
    ddcDetectProc.running = true;
    updateVolumeDisplay();
  }

  property string volumeIconChar: "\uf026"
  property string volumePercent: ""
  property bool volumeMuted: false

  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: updateVolumeDisplay()
  }

  function updateVolumeDisplay() {
    const sink = Pipewire.defaultAudioSink;
    if (!sink) {
      volumeIconChar = "\uf026";
      volumePercent = "";
      volumeMuted = false;
      return;
    }
    volumeMuted = !!sink.muted;
    if (sink.muted) {
      volumeIconChar = "\uf6a9";
    } else {
      const vol = sink.volume;
      if (isNaN(vol) || vol < 0) volumeIconChar = "\uf026";
      else if (vol > 0.66) volumeIconChar = "\uf028";
      else if (vol > 0.33) volumeIconChar = "\uf027";
      else volumeIconChar = "\uf026";
    }
    const vol = sink.volume;
    if (!isNaN(vol)) volumePercent = Math.round(vol * 100) + "%";
    else volumePercent = "";
  }

  function updateBrightnessPoll() {
    if (root.brightnessMethod === "brightnessctl") {
      brightnessPollProc.command = ["sh", "-c", "echo \"$(brightnessctl get)\"; echo \"$(brightnessctl max)\""];
    } else if (root.brightnessMethod === "ddcutil" && root.selectedMonitorBus > 0) {
      brightnessPollProc.command = ["sh", "-c", "ddcutil -b " + root.selectedMonitorBus + " getvcp 10 2>/dev/null | awk '/current/{for(i=1;i<=NF;i++)if($i ~ /^[0-9]+$/){print $i; exit}}'; ddcutil -b " + root.selectedMonitorBus + " getvcp 10 2>/dev/null | awk '/max/{for(i=NF;i>0;i--)if($i ~ /^[0-9]+$/){print $i; exit}}'"];
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.barVisible

      anchors { top: true; left: true; right: true }

      implicitHeight: 32
      color: Qt.rgba(root.theme.bgBase.r, root.theme.bgBase.g, root.theme.bgBase.b, 0.75)

      Item {
        id: barContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: 32

        // ==================== LEFT: Arch + Workspaces ====================
        RowLayout {
          id: leftSection
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10

          Text {
            id: archIcon
            text: "\uf303"
            color: archArea.containsMouse ? root.theme.accentCyan : root.theme.textSecondary
            font.pixelSize: 16
            font.family: root.font

            MouseArea {
              id: archArea
              anchors.fill: parent
              anchors.margins: -4
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleDashboard()
            }
          }

          Repeater {
            model: Hyprland.workspaces

            Rectangle {
              id: wsPill
              required property var modelData
              property bool urgentBlink: false

              Layout.preferredWidth: modelData.focused ? 32 : 24
              Layout.preferredHeight: 24
              Layout.alignment: Qt.AlignVCenter
              radius: 12
              color: modelData.focused ? root.theme.accentPrimary :
                     modelData.urgent && urgentBlink ? root.theme.accentRed : "transparent"
              border.color: modelData.focused ? "transparent" : root.theme.bgBorder
              border.width: 1

              Behavior on color { ColorAnimation { duration: 150 } }

              SequentialAnimation {
                loops: Animation.Infinite
                running: wsPill.modelData.urgent && !wsPill.modelData.focused
                PropertyAction { target: wsPill; property: "urgentBlink"; value: true }
                PauseAnimation { duration: 500 }
                PropertyAction { target: wsPill; property: "urgentBlink"; value: false }
                PauseAnimation { duration: 500 }
                onStopped: wsPill.urgentBlink = false
              }

              Text {
                anchors.centerIn: parent
                text: wsPill.modelData.id
                color: wsPill.modelData.focused ? root.theme.bgBase : root.theme.textPrimary
                font.pixelSize: 11
                font.family: root.font
                font.bold: wsPill.modelData.focused
              }

              MouseArea {
                anchors.fill: parent
                onClicked: wsPill.modelData.activate()
              }

              Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 150 }
              }
            }
          }
        }

        // ==================== CENTER: Time + Date ====================
        Row {
          anchors.centerIn: parent
          spacing: 8

          Text {
            text: Time.timeString
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.font

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleDashboard()
            }
          }

          Text {
            text: Time.dateString
            color: root.theme.textSecondary
            font.pixelSize: 12
            font.family: root.font

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleDashboard()
            }
          }
        }

        // ==================== RIGHT: Quick Menu + Battery + Tray ====================
        RowLayout {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          // Battery
          RowLayout {
            spacing: 4
            visible: SystemInfo.hasBattery

            Text {
              text: SystemInfo.batteryIcon
              color: root.theme.textPrimary
              font.pixelSize: 14
              font.family: root.font
            }

            Text {
              text: SystemInfo.batteryLevel
              color: root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
            }
          }

          // System Tray
          RowLayout {
            id: trayIcons
            spacing: 4
            visible: SystemTray.items.values && SystemTray.items.values.length > 0

            Repeater {
              model: SystemTray.items

              MouseArea {
                id: trayDelegate
                required property SystemTrayItem modelData

                Layout.preferredWidth: 24
                Layout.preferredHeight: 24

                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: (mouse) => {
                  if (mouse.button === Qt.LeftButton) {
                    modelData.activate()
                  } else if (mouse.button === Qt.RightButton) {
                    if (modelData.hasMenu) menuAnchor.open()
                  } else if (mouse.button === Qt.MiddleButton) {
                    modelData.secondaryActivate()
                  }
                }

                IconImage {
                  anchors.centerIn: parent
                  source: trayDelegate.modelData.icon
                  implicitSize: 16
                }

                QsMenuAnchor {
                  id: menuAnchor
                  menu: trayDelegate.modelData.menu
                  anchor.window: trayDelegate.QsWindow.window
                  anchor.adjustment: PopupAdjustment.Flip
                  anchor.onAnchoring: {
                    const window = trayDelegate.QsWindow.window;
                    const widgetRect = window.contentItem.mapFromItem(
                      trayDelegate, 0, trayDelegate.height,
                      trayDelegate.width, trayDelegate.height);
                    menuAnchor.anchor.rect = widgetRect;
                  }
                }
              }
            }
          }
        }
      }

    }
  }

  // ==================== Dashboard Overlay ====================
  PanelWindow {
    id: dashboardPopup
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-dashboard"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; left: true; right: true }
    exclusiveZone: 0
    implicitHeight: 612
    color: "transparent"

    MouseArea {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.hideDashboard()
      onClicked: root.hideDashboard()
    }

    Rectangle {
      id: dashCard
      width: 720
      height: 580
      radius: 12
      color: Qt.rgba(root.theme.bgBase.r, root.theme.bgBase.g, root.theme.bgBase.b, 0.95)
      border.color: Qt.rgba(root.theme.accentPrimary.r, root.theme.accentPrimary.g, root.theme.accentPrimary.b, 0.3)
      border.width: 1
      x: (parent.width - width) / 2
      y: root.dashShown ? 32 : -(height + 60)
      opacity: root.dashShown ? 1 : 0

      Behavior on y {
        NumberAnimation {
          duration: root.dashShown ? 420 : 300
          easing.type: root.dashShown ? Easing.OutBack : Easing.InCubic
          easing.overshoot: 0.7
        }
      }

      Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
      }

      Dashboard {
        anchors.fill: parent
        anchors.margins: 12
        theme: root.theme
        font: root.font
        onClose: root.hideDashboard()
      }
    }
  }
}
