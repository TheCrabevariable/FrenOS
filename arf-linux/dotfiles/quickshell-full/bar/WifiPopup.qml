import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"
  property var anchorWindow: null
  property var anchorItem: null

  property var wifiNetworks: []
  property bool scanning: false
  property string wifiIface: ""
  property bool showPassword: false
  property var pendingNetwork: null

  implicitWidth: 280
  implicitHeight: Math.min(Math.max(contentCol.implicitHeight + 16, 60), 400)

  function refreshScan() {
    root.scanning = true
    wifiScanProc.running = true
  }

  function connectWifi(ssid) {
    wifiConnectProc.command = ["sh", "-c", "nmcli device wifi connect \"" + ssid + "\" ifname " + root.wifiIface + " 2>&1"]
    wifiConnectProc.running = true
  }

  function connectWifiPsk(ssid, password) {
    wifiConnectProc.command = ["sh", "-c", "nmcli device wifi connect \"" + ssid + "\" ifname " + root.wifiIface + " password \"" + password + "\" 2>&1"]
    wifiConnectProc.running = true
  }

  function disconnectWifi() {
    wifiDisconnectProc.running = true
  }

  function toggleWifi() {
    wifiToggleProc.running = true
  }

  property bool wifiEnabled: true
  property string wiredName: ""
  property bool wiredConnected: false

  Process {
    id: wifiEnabledProc
    command: ["sh", "-c", "nmcli -t -f WIFI general 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: { root.wifiEnabled = text.trim() === "enabled" }
    }
  }

  Process {
    id: wiredInfoProc
    command: ["sh", "-c", "nmcli -t -f ACTIVE,NAME,TYPE device status 2>/dev/null | grep ethernet | head -1"]
    stdout: StdioCollector {
      onStreamFinished: {
        const line = text.trim()
        if (line.length > 0) {
          const parts = line.split(":")
          root.wiredConnected = parts[0] === "connected"
          root.wiredName = parts[1] || ""
        } else {
          root.wiredConnected = false
          root.wiredName = ""
        }
      }
    }
  }

  Process {
    id: wifiToggleProc
    command: ["sh", "-c", "nmcli radio wifi 2>/dev/null | grep -q 'enabled' && nmcli radio wifi off || nmcli radio wifi on"]
    stdout: SplitParser {
      onRead: data => {}
    }
    onRunningChanged: {
      if (!running) {
        wifiEnabledProc.running = true
        Qt.callLater(() => root.refreshScan())
      }
    }
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
        } else {
          root.scanning = false
          root.wifiNetworks = []
        }
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
          const connected = parts[0] === "*"
          const ssid = parts[1]
          if (ssid.length === 0) continue
          const signal = parseInt(parts[2]) || 0
          const security = parts[3]
          nets.push({ connected, ssid, signal, security })
        }
        nets.sort((a, b) => {
          if (a.connected && !b.connected) return -1
          if (!a.connected && b.connected) return 1
          return b.signal - a.signal
        })
        root.wifiNetworks = nets
      }
    }
  }

  Process {
    id: wifiConnectProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.showPassword = false
        root.pendingNetwork = null
        Qt.callLater(() => root.refreshScan())
      }
    }
  }

  Process {
    id: wifiDisconnectProc
    command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':wifi$' | cut -d: -f1 | head -1 | xargs -I{} nmcli connection down \"{}\" 2>&1"]
    stdout: StdioCollector {
      onStreamFinished: { Qt.callLater(() => root.refreshScan()) }
    }
  }

  Component.onCompleted: { refreshScan(); wifiEnabledProc.running = true; wiredInfoProc.running = true }

  Timer {
    interval: 15000; running: true; repeat: true
    onTriggered: { wifiEnabledProc.running = true; wiredInfoProc.running = true; root.refreshScan() }
  }

  function submitPassword() {
    if (root.pendingNetwork && passwordInput.text.length > 0) {
      root.connectWifiPsk(root.pendingNetwork.ssid, passwordInput.text)
    }
    root.showPassword = false
    root.pendingNetwork = null
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
    border.color: Qt.rgba(root.theme.accentPrimary.r, root.theme.accentPrimary.g, root.theme.accentPrimary.b, 0.3)
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
          text: "󰖩"
          color: root.theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
        }

        Text {
          text: "Wi-Fi"
          color: root.theme.accentPrimary
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
            onClicked: root.refreshScan()
          }
        }

        // Toggle
        Rectangle {
          width: 32; height: 18; radius: 9
          color: root.wifiEnabled ? root.theme.accentGreen : root.theme.bgSurface
          border.color: root.theme.bgBorder; border.width: 1

          Rectangle {
            x: root.wifiEnabled ? 15 : 2
            width: 14; height: 14; radius: 7
            color: root.wifiEnabled ? root.theme.bgBase : root.theme.textMuted
            Behavior on x { NumberAnimation { duration: 120 } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleWifi()
          }
        }
      }

      // Separator
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.theme.bgBorder
      }

      // Wired connection
      Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 4; Layout.rightMargin: 4
        Layout.preferredHeight: root.wiredConnected ? 40 : 0
        radius: 6
        color: "transparent"
        visible: root.wiredConnected

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8; anchors.rightMargin: 8
          spacing: 6

          Text {
            text: "\uf0ec"
            color: root.theme.accentGreen
            font.pixelSize: 14
            font.family: root.font
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              text: root.wiredName || "Wired"
              color: root.theme.accentGreen
              font.pixelSize: 11
              font.family: root.font
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: "Connected"
              color: root.theme.textMuted
              font.pixelSize: 9
              font.family: root.font
            }
          }
        }
      }

      // Network list
      Repeater {
        model: root.wifiNetworks

        Rectangle {
          id: netDelegate
          required property var modelData
          required property int index

          Layout.fillWidth: true
          Layout.preferredHeight: 36
          radius: 6
          color: netArea.containsMouse ? root.theme.bgHover :
                 modelData.connected ? root.theme.bgSelected : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 6

            Text {
              text: {
                if (modelData.connected) return "󰤨"
                const s = modelData.signal / 100
                if (s > 0.75) return "󰤨"
                if (s > 0.5) return "󰤢"
                if (s > 0.25) return "󰤦"
                return "󰤯"
              }
              color: modelData.connected ? root.theme.accentGreen :
                     netArea.containsMouse ? root.theme.accentPrimary : root.theme.textSecondary
              font.pixelSize: 14
              font.family: root.font
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                text: modelData.ssid
                color: modelData.connected ? root.theme.accentGreen : root.theme.textPrimary
                font.pixelSize: 11
                font.family: root.font
                font.bold: modelData.connected
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: modelData.connected ? "Connected" : (modelData.security.length > 0 && modelData.security !== "--" ? "Secured" : "Open")
                color: root.theme.textMuted
                font.pixelSize: 9
                font.family: root.font
              }
            }

            Text {
              text: modelData.connected ? "󰅖" : ""
              color: root.theme.textSecondary
              font.pixelSize: 12
              font.family: root.font
              visible: modelData.connected

              MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.disconnectWifi()
              }
            }
          }

          MouseArea {
            id: netArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const net = netDelegate.modelData
              if (net.connected) return
              if (net.security && net.security.length > 0 && net.security !== "--") {
                root.pendingNetwork = net
                root.showPassword = true
                passwordInput.text = ""
                passwordInput.forceActiveFocus()
              } else {
                root.connectWifi(net.ssid)
              }
            }
          }
        }
      }

      // Empty state
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 6
        color: "transparent"
        visible: root.wifiNetworks.length === 0

        Text {
          anchors.centerIn: parent
          text: root.scanning ? "Scanning..." : "No networks found"
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: root.font
        }
      }

      // Password prompt
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.showPassword ? pwCol.implicitHeight + 12 : 0
        radius: 6
        color: root.theme.bgSurface
        border.color: root.theme.accentPrimary
        border.width: 1
        clip: true
        visible: root.showPassword

        Behavior on Layout.preferredHeight { NumberAnimation { duration: 120 } }

        ColumnLayout {
          id: pwCol
          anchors.fill: parent
          anchors.margins: 6
          spacing: 4

          Text {
            text: "Password for " + (root.pendingNetwork ? root.pendingNetwork.ssid : "")
            color: root.theme.textPrimary
            font.pixelSize: 10
            font.family: root.font
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Rectangle {
            Layout.fillWidth: true
            height: 26
            radius: 4
            color: root.theme.bgBase
            border.color: passwordInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
            border.width: 1

            TextInput {
              id: passwordInput
              anchors.fill: parent
              anchors.margins: 6
              color: root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
              echoMode: TextInput.Password
              clip: true
              Keys.onReturnPressed: root.submitPassword()
              Keys.onEscapePressed: { root.showPassword = false; root.pendingNetwork = null }
            }
          }

          RowLayout {
            spacing: 4
            Item { Layout.fillWidth: true }

            Rectangle {
              width: 44; height: 20; radius: 4
              color: cancelPwArea.containsMouse ? root.theme.bgHover : "transparent"
              border.color: root.theme.bgBorder; border.width: 1
              Text {
                anchors.centerIn: parent; text: "Cancel"; color: root.theme.textSecondary
                font.pixelSize: 9; font.family: root.font
              }
              MouseArea {
                id: cancelPwArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { root.showPassword = false; root.pendingNetwork = null }
              }
            }

            Rectangle {
              width: 52; height: 20; radius: 4
              color: connPwArea.containsMouse ? root.theme.accentPrimary : "transparent"
              border.color: root.theme.accentPrimary; border.width: 1
              Text {
                anchors.centerIn: parent; text: "Connect"
                color: connPwArea.containsMouse ? root.theme.bgBase : root.theme.accentPrimary
                font.pixelSize: 9; font.family: root.font; font.bold: true
              }
              MouseArea {
                id: connPwArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.submitPassword()
              }
            }
          }
        }
      }
    }
  }
}
