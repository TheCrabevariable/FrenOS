import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Bluetooth

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  property string volumeIconChar: "\uf026"
  property string volumePercent: ""
  property real volumeValue: 0
  property bool volumeMuted: false

  property real brightnessValue: 0
  property string brightnessMethod: ""
  property var ddcMonitors: []
  property int selectedMonitorBus: -1

  property var wifiNetworks: []
  property bool scanning: false
  property string wifiIface: ""
  property bool showPassword: false
  property var pendingNetwork: null

  property bool btEnabled: false
  property bool btScanning: false
  property var btPairedDevices: []
  property var btAvailableDevices: []

  signal volumeSet(real value)
  signal volumeToggleMute()
  signal brightnessSet(string command, real value)
  signal monitorChanged(int bus)

  function busPrefix() {
    if (root.brightnessMethod === "ddcutil" && root.selectedMonitorBus > 0)
      return "ddcutil -b " + root.selectedMonitorBus + " "
    return ""
  }

  function setBrightness(val) {
    const c = Math.max(0, Math.min(1, val))
    if (root.brightnessMethod === "ddcutil")
      root.brightnessSet(busPrefix() + "setvcp 10 " + Math.round(c * 100), c)
    else
      root.brightnessSet("brightnessctl set " + Math.round(c * 100) + "%", c)
  }

  function refreshScan() { root.scanning = true; wifiScanProc.running = true }
  function disconnectWifi() { wifiDisconnectProc.running = true }

  function submitPassword() {
    if (root.pendingNetwork && passwordInput.text.length > 0) {
      wifiConnectProc.command = ["sh", "-c", "nmcli device wifi connect \"" + root.pendingNetwork.ssid + "\" ifname " + root.wifiIface + " password \"" + passwordInput.text + "\" 2>&1"]
      wifiConnectProc.running = true
    }
    root.showPassword = false
    root.pendingNetwork = null
  }

  function refreshBtDevices() { btListProc.running = true }

  function btAction(cmd) {
    btActionProc.command = ["sh", "-c", cmd]
    btActionProc.running = true
  }

  Process {
    id: wifiScanProc
    command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep wifi | head -1 | cut -d: -f1"]
    stdout: StdioCollector {
      onStreamFinished: {
        const iface = text.trim()
        if (iface.length > 0) {
          root.wifiIface = iface
          wifiRescanProc.running = true
        } else { root.scanning = false; root.wifiNetworks = [] }
      }
    }
  }

  Process {
    id: wifiRescanProc
    command: ["sh", "-c", "nmcli device wifi rescan ifname " + root.wifiIface + " 2>/dev/null; sleep 1"]
    stdout: SplitParser { onRead: data => {} }
    onRunningChanged: {
      if (!running) {
        wifiListProc.command = ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list ifname " + root.wifiIface + " 2>/dev/null"]
        wifiListProc.running = true
      }
    }
  }

  Process {
    id: wifiListProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.scanning = false
        const lines = text.trim().split("\n")
        const nets = []
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].split(":")
          if (parts.length < 4) continue
          const ssid = parts[1]
          if (ssid.length === 0) continue
          nets.push({ connected: parts[0] === "*", ssid: ssid, signal: parseInt(parts[2]) || 0, security: parts[3] })
        }
        nets.sort((a, b) => { if (a.connected !== b.connected) return a.connected ? -1 : 1; return b.signal - a.signal })
        root.wifiNetworks = nets
      }
    }
  }

  Process {
    id: wifiConnectProc
    stdout: StdioCollector { onStreamFinished: { root.showPassword = false; root.pendingNetwork = null; Qt.callLater(() => root.refreshScan()) } }
  }

  Process {
    id: wifiDisconnectProc
    command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':wifi$' | cut -d: -f1 | head -1 | xargs -I{} nmcli connection down \"{}\" 2>&1"]
    stdout: StdioCollector { onStreamFinished: { Qt.callLater(() => root.refreshScan()) } }
  }

  Process {
    id: btListProc
    command: ["sh", "-c", "bluetoothctl devices 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        const paired = [], available = []
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim()
          if (line.length === 0) continue
          const m = line.match(/^Device\s+([A-Fa-f0-9:]{17})\s+(.*)$/)
          if (!m) continue
          const dev = { mac: m[1], name: m[2] || m[1], connected: line.includes("[Connected]"), paired: line.includes("[Paired]") || line.includes("[Trusted]"), blocked: line.includes("[Blocked]") }
          if (dev.paired) paired.push(dev); else available.push(dev)
        }
        root.btPairedDevices = paired
        root.btAvailableDevices = available
      }
    }
  }

  Process {
    id: btStatusProc
    command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 'on' || echo 'off'"]
    stdout: SplitParser { onRead: data => { root.btEnabled = data.trim() === "on" } }
  }

  Process {
    id: btToggleProc
    command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"]
    onRunningChanged: { if (!running) Qt.callLater(() => { btStatusProc.running = true; root.refreshBtDevices() }) }
  }

  Process {
    id: btScanProc
    command: ["sh", "-c", "echo -e 'scan on\nquit' | bluetoothctl 2>/dev/null"]
    onRunningChanged: { if (!running) { root.btScanning = false; Qt.callLater(() => root.refreshBtDevices()) } }
  }

  Process {
    id: btActionProc
    onRunningChanged: { if (!running) Qt.callLater(() => root.refreshBtDevices()) }
  }

  function btIconFor(name) {
    const n = name.toLowerCase()
    if (n.includes("headphone") || n.includes("headset") || n.includes("earbuds")) return "\uf001"
    if (n.includes("speaker")) return "\uf028"
    if (n.includes("keyboard")) return "\uf11c"
    if (n.includes("mouse")) return "\uf245"
    if (n.includes("phone")) return "\uf095"
    return "\uf293"
  }

  Component.onCompleted: {
    refreshScan()
    btStatusProc.running = true
    refreshBtDevices()
  }

  Timer { interval: 15000; running: true; repeat: true; onTriggered: { root.refreshScan(); btStatusProc.running = true; root.refreshBtDevices() } }

  Rectangle {
    anchors.fill: parent
    radius: 10
    color: Qt.rgba(root.theme.bgBase.r, root.theme.bgBase.g, root.theme.bgBase.b, 0.95)
    border.color: Qt.rgba(root.theme.accentPrimary.r, root.theme.accentPrimary.g, root.theme.accentPrimary.b, 0.3)
    border.width: 1

    Flickable {
      anchors.fill: parent
      anchors.margins: 8
      contentHeight: mainCol.implicitHeight
      clip: true
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: mainCol
        width: parent.width
        spacing: 8

        // === VOLUME ===
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text {
            text: root.volumeIconChar; color: root.theme.accentPrimary; font.pixelSize: 14; font.family: root.font
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.volumeToggleMute() }
          }
          Text { text: "Volume"; color: root.theme.accentPrimary; font.pixelSize: 11; font.family: root.font; font.bold: true; Layout.fillWidth: true }
          Text { text: root.volumePercent; color: root.theme.textPrimary; font.pixelSize: 11; font.family: root.font }
        }

        Rectangle {
          Layout.fillWidth: true; height: 20; radius: 10; color: root.theme.bgSurface
          border.color: root.theme.bgBorder; border.width: 1

          Rectangle {
            x: 1; y: 1
            width: Math.max(0, (root.volumeMuted ? 0 : root.volumeValue) * (parent.width - 2))
            height: parent.height - 2; radius: 9; color: root.theme.accentPrimary
            Behavior on width { NumberAnimation { duration: 80 } }
          }

          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onWheel: (w) => root.volumeSet(Math.max(0, Math.min(1, root.volumeValue + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
            onClicked: (m) => root.volumeSet(Math.max(0, Math.min(1, m.x / width)))
            onPositionChanged: (m) => { if (pressed) root.volumeSet(Math.max(0, Math.min(1, m.x / width))) }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.bgBorder }

        // === BRIGHTNESS ===
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text { text: "\uf185"; color: root.theme.accentPrimary; font.pixelSize: 14; font.family: root.font }
          Text { text: "Brightness"; color: root.theme.accentPrimary; font.pixelSize: 11; font.family: root.font; font.bold: true; Layout.fillWidth: true }
          Text { text: Math.round(root.brightnessValue * 100) + "%"; color: root.theme.textPrimary; font.pixelSize: 11; font.family: root.font }
        }

        // Monitor selector
        RowLayout {
          Layout.fillWidth: true
          spacing: 4
          visible: root.ddcMonitors.length > 1

          Repeater {
            model: root.ddcMonitors
            Rectangle {
              Layout.fillWidth: true; height: 20; radius: 4
              color: monArea.containsMouse ? root.theme.bgHover : modelData.bus === root.selectedMonitorBus ? root.theme.accentPrimary : "transparent"
              border.color: modelData.bus === root.selectedMonitorBus ? root.theme.accentPrimary : root.theme.bgBorder; border.width: 1
              Text { anchors.centerIn: parent; text: modelData.label; color: modelData.bus === root.selectedMonitorBus ? root.theme.bgBase : root.theme.textSecondary; font.pixelSize: 8; font.family: root.font; elide: Text.ElideRight }
              MouseArea { id: monArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.monitorChanged(modelData.bus) }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true; height: 20; radius: 10; color: root.theme.bgSurface
          border.color: root.theme.bgBorder; border.width: 1

          Rectangle {
            x: 1; y: 1
            width: Math.max(0, root.brightnessValue * (parent.width - 2))
            height: parent.height - 2; radius: 9; color: root.theme.accentPrimary
            Behavior on width { NumberAnimation { duration: 80 } }
          }

          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onWheel: (w) => root.setBrightness(root.brightnessValue + (w.angleDelta.y > 0 ? 0.05 : -0.05))
            onClicked: (m) => root.setBrightness(m.x / width)
            onPositionChanged: (m) => { if (pressed) root.setBrightness(m.x / width) }
          }
        }

        RowLayout {
          Layout.fillWidth: true; spacing: 4
          Repeater {
            model: [25, 50, 75, 100]
            Rectangle {
              Layout.fillWidth: true; height: 18; radius: 4
              color: pArea.containsMouse ? root.theme.bgHover : Math.round(root.brightnessValue * 100) === modelData ? root.theme.accentPrimary : "transparent"
              border.color: Math.round(root.brightnessValue * 100) === modelData ? root.theme.accentPrimary : root.theme.bgBorder; border.width: 1
              Text { anchors.centerIn: parent; text: modelData + "%"; color: Math.round(root.brightnessValue * 100) === modelData ? root.theme.bgBase : root.theme.textSecondary; font.pixelSize: 8; font.family: root.font }
              MouseArea { id: pArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setBrightness(modelData / 100) }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.bgBorder }

        // === WIFI ===
        RowLayout {
          Layout.fillWidth: true; spacing: 8

          Text { text: "\uf1eb"; color: root.theme.accentGreen; font.pixelSize: 14; font.family: root.font }
          Text { text: "Wi-Fi"; color: root.theme.accentGreen; font.pixelSize: 11; font.family: root.font; font.bold: true; Layout.fillWidth: true }

          Rectangle {
            width: 20; height: 20; radius: 6; color: scanWifiArea.containsMouse ? root.theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: "\uf021"; color: root.theme.textSecondary; font.pixelSize: 10; font.family: root.font
              NumberAnimation on rotation { running: root.scanning; loops: Animation.Infinite; duration: 1000; from: 0; to: 360 }
            }
            MouseArea { id: scanWifiArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshScan() }
          }
        }

        Repeater {
          model: root.wifiNetworks
          Rectangle {
            id: netD
            required property var modelData
            Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 6
            color: netArea.containsMouse ? root.theme.bgHover : modelData.connected ? root.theme.bgSelected : "transparent"
            RowLayout { anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
              Text { text: modelData.connected ? "\uf1eb" : (modelData.signal > 75 ? "\uf1eb" : modelData.signal > 50 ? "\uf1eb" : "\uf1eb"); color: modelData.connected ? root.theme.accentGreen : root.theme.textSecondary; font.pixelSize: 12; font.family: root.font }
              ColumnLayout { Layout.fillWidth: true; spacing: 0
                Text { text: modelData.ssid; color: modelData.connected ? root.theme.accentGreen : root.theme.textPrimary; font.pixelSize: 10; font.family: root.font; font.bold: modelData.connected; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: modelData.connected ? "Connected" : (modelData.security.length > 0 && modelData.security !== "--" ? "Secured" : "Open"); color: root.theme.textMuted; font.pixelSize: 8; font.family: root.font }
              }
              Text { text: modelData.connected ? "\uf00d" : ""; color: root.theme.textSecondary; font.pixelSize: 10; font.family: root.font; visible: modelData.connected
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.disconnectWifi() }
              }
            }
            MouseArea {
              id: netArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (netD.modelData.connected) return
                if (netD.modelData.security && netD.modelData.security.length > 0 && netD.modelData.security !== "--") {
                  root.pendingNetwork = netD.modelData; root.showPassword = true; passwordInput.text = ""; passwordInput.forceActiveFocus()
                } else {
                  wifiConnectProc.command = ["sh", "-c", "nmcli device wifi connect \"" + netD.modelData.ssid + "\" ifname " + root.wifiIface + " 2>&1"]
                  wifiConnectProc.running = true
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true; Layout.preferredHeight: root.wifiNetworks.length === 0 ? 24 : 0
          radius: 6; color: "transparent"; visible: root.wifiNetworks.length === 0
          Text { anchors.centerIn: parent; text: root.scanning ? "Scanning..." : "No networks"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
        }

        // Password prompt
        Rectangle {
          Layout.fillWidth: true; Layout.preferredHeight: root.showPassword ? pwCol.implicitHeight + 10 : 0
          radius: 6; color: root.theme.bgSurface; border.color: root.theme.accentPrimary; border.width: 1; clip: true; visible: root.showPassword
          Behavior on Layout.preferredHeight { NumberAnimation { duration: 120 } }
          ColumnLayout { id: pwCol; anchors.fill: parent; anchors.margins: 5; spacing: 3
            Text { text: "Password for " + (root.pendingNetwork ? root.pendingNetwork.ssid : ""); color: root.theme.textPrimary; font.pixelSize: 9; font.family: root.font; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            Rectangle { Layout.fillWidth: true; height: 24; radius: 4; color: root.theme.bgBase; border.color: passwordInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder; border.width: 1
              TextInput { id: passwordInput; anchors.fill: parent; anchors.margins: 4; color: root.theme.textPrimary; font.pixelSize: 10; font.family: root.font; echoMode: TextInput.Password; clip: true
                Keys.onReturnPressed: root.submitPassword()
                Keys.onEscapePressed: { root.showPassword = false; root.pendingNetwork = null }
              }
            }
            RowLayout { spacing: 4
              Item { Layout.fillWidth: true }
              Rectangle { width: 40; height: 18; radius: 4; color: cpwArea.containsMouse ? root.theme.bgHover : "transparent"; border.color: root.theme.bgBorder; border.width: 1
                Text { anchors.centerIn: parent; text: "Cancel"; color: root.theme.textSecondary; font.pixelSize: 8; font.family: root.font }
                MouseArea { id: cpwArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.showPassword = false; root.pendingNetwork = null } }
              }
              Rectangle { width: 50; height: 18; radius: 4; color: cnPwArea.containsMouse ? root.theme.accentPrimary : "transparent"; border.color: root.theme.accentPrimary; border.width: 1
                Text { anchors.centerIn: parent; text: "Connect"; color: cnPwArea.containsMouse ? root.theme.bgBase : root.theme.accentPrimary; font.pixelSize: 8; font.family: root.font; font.bold: true }
                MouseArea { id: cnPwArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submitPassword() }
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.bgBorder }

        // === BLUETOOTH ===
        RowLayout {
          Layout.fillWidth: true; spacing: 8

          Text { text: "\u{eb72}"; color: root.theme.accentCyan; font.pixelSize: 14; font.family: root.font }
          Text { text: "Bluetooth"; color: root.theme.accentCyan; font.pixelSize: 11; font.family: root.font; font.bold: true; Layout.fillWidth: true }

          Rectangle {
            width: 20; height: 20; radius: 6; color: scanBtArea.containsMouse ? root.theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: "\uf021"; color: root.theme.textSecondary; font.pixelSize: 10; font.family: root.font
              NumberAnimation on rotation { running: root.btScanning; loops: Animation.Infinite; duration: 1000; from: 0; to: 360 }
            }
            MouseArea { id: scanBtArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { if (root.btScanning) return; root.btScanning = true; btScanProc.running = true }
            }
          }

          Rectangle {
            width: 30; height: 16; radius: 8; color: root.btEnabled ? root.theme.accentGreen : root.theme.bgSurface; border.color: root.theme.bgBorder; border.width: 1
            Rectangle { x: root.btEnabled ? 15 : 2; width: 12; height: 12; radius: 6; color: root.btEnabled ? root.theme.bgBase : root.theme.textMuted; Behavior on x { NumberAnimation { duration: 120 } } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.btScanning = false; btToggleProc.running = true } }
          }
        }

        Repeater {
          model: root.btPairedDevices
          Rectangle {
            required property var modelData
            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 6
            color: btPairArea.containsMouse ? root.theme.bgHover : modelData.connected ? root.theme.bgSelected : "transparent"
            RowLayout { anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
              Text { text: root.btIconFor(modelData.name); color: modelData.connected ? root.theme.accentCyan : root.theme.textSecondary; font.pixelSize: 12; font.family: root.font }
              ColumnLayout { Layout.fillWidth: true; spacing: 0
                Text { text: modelData.name; color: modelData.connected ? root.theme.accentCyan : root.theme.textPrimary; font.pixelSize: 10; font.family: root.font; font.bold: modelData.connected; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: modelData.connected ? "Connected" : "Paired"; color: root.theme.textMuted; font.pixelSize: 8; font.family: root.font }
              }
              Text { text: modelData.connected ? "\uf00d" : "\uf069"; color: root.theme.textSecondary; font.pixelSize: 10; font.family: root.font
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                  onClicked: root.btAction(modelData.connected ? "echo -e 'disconnect " + modelData.mac + "\nquit' | bluetoothctl" : "echo -e 'connect " + modelData.mac + "\nquit' | bluetoothctl")
                }
              }
            }
            MouseArea { id: btPairArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.btAction(modelData.connected ? "echo -e 'disconnect " + modelData.mac + "\nquit' | bluetoothctl" : "echo -e 'connect " + modelData.mac + "\nquit' | bluetoothctl")
            }
          }
        }

        Repeater {
          model: root.btAvailableDevices
          Rectangle {
            required property var modelData
            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 6; color: btAvailArea.containsMouse ? root.theme.bgHover : "transparent"
            RowLayout { anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
              Text { text: root.btIconFor(modelData.name); color: root.theme.textSecondary; font.pixelSize: 12; font.family: root.font }
              ColumnLayout { Layout.fillWidth: true; spacing: 0
                Text { text: modelData.name; color: root.theme.textPrimary; font.pixelSize: 10; font.family: root.font; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: modelData.mac; color: root.theme.textMuted; font.pixelSize: 7; font.family: root.font }
              }
            }
            MouseArea { id: btAvailArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.btAction("echo -e 'pair " + modelData.mac + "\nconnect " + modelData.mac + "\nquit' | bluetoothctl")
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true; Layout.preferredHeight: (root.btPairedDevices.length === 0 && root.btAvailableDevices.length === 0) ? 24 : 0
          radius: 6; color: "transparent"; visible: root.btPairedDevices.length === 0 && root.btAvailableDevices.length === 0
          Text { anchors.centerIn: parent; text: root.btScanning ? "Scanning..." : (root.btEnabled ? "No devices" : "Bluetooth off"); color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
        }
      }
    }
  }
}
