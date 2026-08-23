import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  property bool btEnabled: false
  property bool scanning: false
  property var pairedDevices: []
  property var availableDevices: []

  implicitWidth: 280
  implicitHeight: Math.min(Math.max(contentCol.implicitHeight + 16, 60), 400)

  function refreshStatus() { btStatusProc.running = true }

  function refreshDevices() { btListProc.running = true }

  function toggleBt() { btToggleProc.running = true }

  function startScan() {
    root.scanning = true
    btScanProc.running = true
  }

  function stopScan() {
    btStopScanProc.running = true
  }

  function connectDevice(mac) {
    btActionProc.command = ["sh", "-c", "echo -e 'connect " + mac + "\\nquit' | bluetoothctl 2>/dev/null"]
    btActionProc.running = true
  }

  function disconnectDevice(mac) {
    btActionProc.command = ["sh", "-c", "echo -e 'disconnect " + mac + "\\nquit' | bluetoothctl 2>/dev/null"]
    btActionProc.running = true
  }

  function pairDevice(mac) {
    btActionProc.command = ["sh", "-c", "echo -e 'pair " + mac + "\\nquit' | bluetoothctl 2>/dev/null"]
    btActionProc.running = true
  }

  function removeDevice(mac) {
    btActionProc.command = ["sh", "-c", "echo -e 'remove " + mac + "\\nquit' | bluetoothctl 2>/dev/null"]
    btActionProc.running = true
  }

  Process {
    id: btStatusProc
    command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 'on' || echo 'off'"]
    stdout: SplitParser {
      onRead: data => { root.btEnabled = data.trim() === "on" }
    }
  }

  Process {
    id: btToggleProc
    command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"]
    stdout: SplitParser {
      onRead: data => {}
    }
    onRunningChanged: {
      if (!running) {
        Qt.callLater(() => {
          root.refreshStatus()
          root.refreshDevices()
        })
      }
    }
  }

  Process {
    id: btScanProc
    command: ["sh", "-c", "echo -e 'scan on\\nquit' | bluetoothctl 2>/dev/null"]
    onRunningChanged: {
      if (!running) {
        root.scanning = false
        Qt.callLater(() => root.refreshDevices())
      }
    }
  }

  Timer {
    id: scanFinishTimer
    interval: 10000
    onTriggered: {
      if (root.scanning) {
        root.stopScan()
        root.scanning = false
        Qt.callLater(() => root.refreshDevices())
      }
    }
  }

  onScanningChanged: {
    if (scanning) scanFinishTimer.start()
    else scanFinishTimer.stop()
  }

  Process {
    id: btStopScanProc
    command: ["sh", "-c", "echo -e 'scan off\\nquit' | bluetoothctl 2>/dev/null"]
  }

  Process {
    id: btActionProc
    stdout: SplitParser {
      onRead: data => {}
    }
    onRunningChanged: {
      if (!running) {
        Qt.callLater(() => root.refreshDevices())
      }
    }
  }

  Process {
    id: btListProc
    command: ["sh", "-c", "bluetoothctl devices 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        const paired = []
        const available = []

        // Get connected devices
        const connectedProc = ["sh", "-c", "echo 'info' | bluetoothctl 2>/dev/null | grep -i 'device' | head -1 || true"]

        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim()
          if (line.length === 0) continue
          const match = line.match(/^Device\s+([A-Fa-f0-9:]{17})\s+(.*)$/)
          if (!match) continue
          const mac = match[1]
          const name = match[2]
          const isPaired = line.includes("[Paired]")
          const isTrusted = line.includes("[Trusted]")
          const isBlocked = line.includes("[Blocked]")
          const isConnected = line.includes("[Connected]")
          const dev = {
            mac: mac,
            name: name || mac,
            connected: isConnected,
            paired: isPaired || isTrusted,
            blocked: isBlocked
          }
          if (dev.paired) {
            paired.push(dev)
          } else {
            available.push(dev)
          }
        }
        root.pairedDevices = paired
        root.availableDevices = available
      }
    }
  }

  Component.onCompleted: {
    refreshStatus()
    refreshDevices()
  }

  Timer {
    interval: 12000; running: true; repeat: true
    onTriggered: { root.refreshStatus(); root.refreshDevices() }
  }

  function deviceIcon(name) {
    const n = name.toLowerCase()
    if (n.includes("headphone") || n.includes("headset") || n.includes("earbuds") || n.includes("airpods")) return "󰋋"
    if (n.includes("speaker") || n.includes("sound")) return "󰝟"
    if (n.includes("keyboard")) return "󰌌"
    if (n.includes("mouse") || n.includes("trackpad")) return "󰍽"
    if (n.includes("phone") || n.includes("iphone") || n.includes("galaxy")) return "󰏲"
    if (n.includes("controller") || n.includes("gamepad")) return "󰊴"
    if (n.includes("tv") || n.includes("monitor")) return "󰍹"
    return "󰂯"
  }

  // Shadow
  Rectangle {
    anchors.fill: bg
    anchors.margins: -2
    radius: bg.radius + 2
    color: Qt.rgba(0, 0, 0, 0.35)
    z: -1
  }

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: 10
    color: Qt.rgba(root.theme.bgBase.r, root.theme.bgBase.g, root.theme.bgBase.b, 0.95)
    border.color: Qt.rgba(root.theme.accentCyan.r, root.theme.accentCyan.g, root.theme.accentCyan.b, 0.3)
    border.width: 1

    ColumnLayout {
      id: contentCol
      anchors.fill: parent
      anchors.margins: 8
      spacing: 4

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: "󰂯"
          color: root.theme.accentCyan
          font.pixelSize: 14
          font.family: root.font
        }

        Text {
          text: "Bluetooth"
          color: root.theme.accentCyan
          font.pixelSize: 12
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        // Scan button
        Rectangle {
          width: 22; height: 22; radius: 6
          color: scanBtnArea.containsMouse ? root.theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰑐"
            color: root.theme.textSecondary
            font.pixelSize: 12
            font.family: root.font
            NumberAnimation on rotation {
              running: root.scanning
              loops: Animation.Infinite
              duration: 1000
              from: 0; to: 360
            }
          }

          MouseArea {
            id: scanBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.scanning) root.stopScan()
              else root.startScan()
            }
          }
        }

        // Toggle
        Rectangle {
          width: 32; height: 18; radius: 9
          color: root.btEnabled ? root.theme.accentGreen : root.theme.bgSurface
          border.color: root.theme.bgBorder; border.width: 1

          Rectangle {
            x: root.btEnabled ? 15 : 2
            width: 14; height: 14; radius: 7
            color: root.btEnabled ? root.theme.bgBase : root.theme.textMuted
            Behavior on x { NumberAnimation { duration: 120 } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleBt()
          }
        }
      }

      // Separator
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.theme.bgBorder
      }

      // Paired devices
      Repeater {
        model: root.pairedDevices

        Rectangle {
          id: pairedDelegate
          required property var modelData
          required property int index

          Layout.fillWidth: true
          Layout.preferredHeight: 36
          radius: 6
          color: pairedArea.containsMouse ? root.theme.bgHover :
                 modelData.connected ? root.theme.bgSelected : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 6

            Text {
              text: root.deviceIcon(modelData.name)
              color: modelData.connected ? root.theme.accentCyan : root.theme.textSecondary
              font.pixelSize: 14
              font.family: root.font
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                text: pairedDelegate.modelData.name
                color: modelData.connected ? root.theme.accentCyan : root.theme.textPrimary
                font.pixelSize: 11
                font.family: root.font
                font.bold: modelData.connected
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: modelData.connected ? "Connected" : (modelData.blocked ? "Blocked" : "Paired")
                color: modelData.blocked ? root.theme.accentRed : root.theme.textMuted
                font.pixelSize: 9
                font.family: root.font
              }
            }

            Text {
              text: modelData.connected ? "󰅖" : "󰐊"
              color: root.theme.textSecondary
              font.pixelSize: 12
              font.family: root.font

              MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (pairedDelegate.modelData.connected)
                    root.disconnectDevice(pairedDelegate.modelData.mac)
                  else
                    root.connectDevice(pairedDelegate.modelData.mac)
                }
              }
            }
          }

          MouseArea {
            id: pairedArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
              if (mouse.button === Qt.LeftButton) {
                if (pairedDelegate.modelData.connected)
                  root.disconnectDevice(pairedDelegate.modelData.mac)
                else
                  root.connectDevice(pairedDelegate.modelData.mac)
              }
            }
          }
        }
      }

      // Available devices header
      Text {
        text: root.availableDevices.length > 0 ? "Available" : ""
        color: root.theme.textMuted
        font.pixelSize: 10
        font.family: root.font
        font.bold: true
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: root.availableDevices.length > 0
      }

      // Available devices
      Repeater {
        model: root.availableDevices

        Rectangle {
          id: availDelegate
          required property var modelData
          required property int index

          Layout.fillWidth: true
          Layout.preferredHeight: 36
          radius: 6
          color: availArea.containsMouse ? root.theme.bgHover : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 6

            Text {
              text: root.deviceIcon(availDelegate.modelData.name)
              color: root.theme.textSecondary
              font.pixelSize: 14
              font.family: root.font
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                text: availDelegate.modelData.name
                color: root.theme.textPrimary
                font.pixelSize: 11
                font.family: root.font
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: availDelegate.modelData.mac
                color: root.theme.textMuted
                font.pixelSize: 8
                font.family: root.font
              }
            }

            Rectangle {
              width: 36; height: 18; radius: 4
              color: pairBtnArea.containsMouse ? root.theme.accentCyan : "transparent"
              border.color: root.theme.accentCyan; border.width: 1

              Text {
                anchors.centerIn: parent
                text: "Pair"
                color: pairBtnArea.containsMouse ? root.theme.bgBase : root.theme.accentCyan
                font.pixelSize: 8
                font.family: root.font
                font.bold: true
              }

              MouseArea {
                id: pairBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pairDevice(availDelegate.modelData.mac)
              }
            }
          }

          MouseArea {
            id: availArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.connectDevice(availDelegate.modelData.mac)
          }
        }
      }

      // Empty state
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 6
        color: "transparent"
        visible: root.pairedDevices.length === 0 && root.availableDevices.length === 0

        Text {
          anchors.centerIn: parent
          text: root.scanning ? "Scanning..." : (root.btEnabled ? "No devices found" : "Bluetooth is off")
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: root.font
        }
      }
    }
  }
}
