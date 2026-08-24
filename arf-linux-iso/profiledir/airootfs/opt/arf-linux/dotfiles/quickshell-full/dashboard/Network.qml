import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Bluetooth

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  // ======== WiFi ========
  property bool scanning: false
  property var wifiNetworks: []
  property string wifiIface: ""
  property bool showPassword: false
  property var pendingNetwork: null

  function refreshScan() {
    root.scanning = true
    wifiScanProc.running = true
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
          nets.push({ connected: connected, ssid: ssid, signal: signal, security: security })
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

  function connectWifi(ssid) {
    wifiConnectProc.command = ["sh", "-c", "nmcli device wifi connect \"" + ssid + "\" ifname " + root.wifiIface + " 2>&1"]
    wifiConnectProc.running = true
  }

  function connectWifiPsk(ssid, password) {
    wifiConnectProc.command = ["sh", "-c", "nmcli device wifi connect \"" + ssid + "\" ifname " + root.wifiIface + " password \"" + password + "\" 2>&1"]
    wifiConnectProc.running = true
  }

  Process {
    id: wifiConnectProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.showPassword = false
        root.pendingNetwork = null
        root.refreshScan()
      }
    }
  }

  function disconnectWifi() {
    wifiDisconnectProc.running = true
  }

  Process {
    id: wifiDisconnectProc
    command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ':wifi$' | cut -d: -f1 | head -1 | xargs -I{} nmcli connection down \"{}\" 2>&1"]
    stdout: StdioCollector {
      onStreamFinished: { root.refreshScan() }
    }
  }

  // ======== Hotspot ========
  property bool hotspotActive: false
  property string hotspotSsid: ""
  property int hotspotClients: 0
  property bool showHotspotCreate: false

  function refreshHotspot() { hotspotStatusProc.running = true }

  function startHotspot(ssid, password) {
    const iface = root.wifiIface || "wlan0"
    hotspotStartProc.command = ["bash", "-c", "nmcli dev wifi hotspot ifname " + iface + " ssid \"" + ssid + "\" password \"" + password + "\" 2>&1"]
    hotspotStartProc.running = true
  }

  function stopHotspot() { hotspotStopProc.running = true }

  Process {
    id: hotspotStatusProc
    command: ["bash", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep wireless || true"]
    stdout: SplitParser {
      onRead: data => {
        if (data.length > 0) {
          root.hotspotActive = true
          root.hotspotSsid = data.split(":")[0]
        } else {
          root.hotspotActive = false
          root.hotspotSsid = ""
        }
      }
    }
    onRunningChanged: {
      if (!running && !root.hotspotActive) {
        root.hotspotSsid = ""
        root.hotspotClients = 0
      }
    }
  }

  Process {
    id: hotspotStartProc
    stdout: SplitParser {
      onRead: data => {
        if (data.includes("successfully")) {
          root.hotspotActive = true
          root.showHotspotCreate = false
        }
        root.hotspotStatusProc.running = true
      }
    }
  }

  Process {
    id: hotspotStopProc
    command: ["nmcli", "connection", "down", "Hotspot"]
    onRunningChanged: {
      if (!running) {
        root.hotspotActive = false
        root.hotspotSsid = ""
        root.hotspotClients = 0
      }
    }
  }

  Timer {
    id: hotspotClientTimer
    interval: 5000
    running: root.hotspotActive
    repeat: true
    onTriggered: { if (root.hotspotActive) hotspotClientCountProc.running = true }
  }

  Process {
    id: hotspotClientCountProc
    command: ["sh", "-c", "nmcli device wifi list ifname " + (root.wifiIface || "wlan0") + " 2>/dev/null | grep -c 'In-Range' || echo 0"]
    stdout: SplitParser {
      onRead: data => {
        const n = parseInt(data)
        if (!isNaN(n)) root.hotspotClients = n
      }
    }
  }

  // ======== Wired ========
  property string wiredIface: ""
  property bool wiredConnected: false
  property string wiredIp: ""

  Process {
    id: wiredInfoProc
    command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | grep ethernet"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].split(":")
          if (parts.length >= 3 && parts[2] === "connected") {
            root.wiredIface = parts[0]
            root.wiredConnected = true
            wiredIpProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS", "dev", "show", parts[0]]
            wiredIpProc.running = true
            return
          }
        }
        root.wiredIface = ""
        root.wiredConnected = false
        root.wiredIp = ""
      }
    }
  }

  Process {
    id: wiredIpProc
    stdout: SplitParser {
      onRead: data => { if (data.includes("/")) root.wiredIp = data.split("/")[0] }
    }
  }

  // ======== Bluetooth ========
  property var btAdapter: Bluetooth.defaultAdapter
  property bool btEnabled: btAdapter ? btAdapter.enabled : false
  property bool btScanning: btAdapter ? btAdapter.discovering : false

  property var btConnectedDevices: {
    if (!btAdapter) return []
    return btAdapter.devices.values.filter(d => d && d.connected)
  }

  property var btAvailableDevices: {
    if (!btAdapter) return []
    return btAdapter.devices.values.filter(d => d && !d.connected)
  }

  Component.onCompleted: { refreshHotspot(); wiredInfoProc.running = true; refreshScan() }

  Timer {
    interval: 10000; running: true; repeat: true
    onTriggered: { wiredInfoProc.running = true }
  }

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: 0

    // Scrollable content
    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentHeight: scrollCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      ColumnLayout {
        id: scrollCol
        width: parent.width
        spacing: 0

        // ======== WIRED SECTION ========
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 4; Layout.rightMargin: 4
          Layout.topMargin: 4; Layout.bottomMargin: 8
          spacing: 8

          Text {
            text: "󰈀"
            color: root.wiredConnected ? root.theme.accentGreen : root.theme.textMuted
            font.pixelSize: 16
            font.family: root.font
          }

          Text {
            text: "Wired"
            color: root.theme.accentPrimary
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
            Layout.fillWidth: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: 8; Layout.rightMargin: 8
          Layout.preferredHeight: root.wiredConnected ? 44 : 32
          radius: 8
          color: "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 10

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: root.wiredIface || "eth0"
                color: root.wiredConnected ? root.theme.accentGreen : root.theme.textSecondary
                font.pixelSize: 12
                font.family: root.font
                font.bold: root.wiredConnected
              }

              Text {
                text: root.wiredConnected ? "Connected" + (root.wiredIp ? " • " + root.wiredIp : "") : "Not connected"
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
            }
          }
        }

        // Separator
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: 4; Layout.rightMargin: 4
          Layout.topMargin: 8; Layout.bottomMargin: 8
          height: 1
          color: root.theme.bgBorder
          visible: root.wiredConnected
        }

        // ======== HOTSPOT SECTION ========
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 4; Layout.rightMargin: 4
          Layout.bottomMargin: 8
          spacing: 8

          Text {
            text: "󰈀"
            color: root.hotspotActive ? root.theme.accentOrange : root.theme.textMuted
            font.pixelSize: 16
            font.family: root.font
          }

          Text {
            text: "Hotspot"
            color: root.theme.accentPrimary
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
            Layout.fillWidth: true
          }

          // Toggle hotspot
          Rectangle {
            width: 36; height: 20; radius: 10
            color: root.hotspotActive ? root.theme.accentOrange : root.theme.bgSurface
            border.color: root.theme.bgBorder; border.width: 1
            visible: root.hotspotActive

            Rectangle {
              x: 18
              width: 16; height: 16; radius: 8
              color: root.hotspotActive ? root.theme.bgBase : root.theme.textMuted
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.stopHotspot()
            }
          }

          // Create button
          Rectangle {
            width: createLabel.implicitWidth + 12; height: 24; radius: 6
            color: createArea.containsMouse ? root.theme.accentOrange : "transparent"
            border.color: root.theme.accentOrange; border.width: 1
            visible: !root.hotspotActive

            Text {
              id: createLabel
              anchors.centerIn: parent
              text: "Create"
              color: createArea.containsMouse ? root.theme.bgBase : root.theme.accentOrange
              font.pixelSize: 10
              font.family: root.font
              font.bold: true
            }

            MouseArea {
              id: createArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.showHotspotCreate = !root.showHotspotCreate
                hotspotSsidInput.text = "Quickshell-Hotspot"
                hotspotPassInput.text = ""
              }
            }
          }
        }

        // Active hotspot info
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: 8; Layout.rightMargin: 8
          Layout.preferredHeight: root.hotspotActive ? 44 : 0
          radius: 8
          color: "transparent"
          visible: root.hotspotActive
          clip: true

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: root.hotspotSsid || "Hotspot"
                color: root.theme.accentOrange
                font.pixelSize: 12
                font.family: root.font
                font.bold: true
              }

              Text {
                text: root.hotspotClients + " client" + (root.hotspotClients !== 1 ? "s" : "")
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
            }

            Rectangle {
              width: 24; height: 24; radius: 6
              color: hotspotStopArea.containsMouse ? root.theme.bgHover : "transparent"

              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: root.theme.textSecondary
                font.pixelSize: 12
                font.family: root.font
              }

              MouseArea {
                id: hotspotStopArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.stopHotspot()
              }
            }
          }
        }

        // Create hotspot form
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: 8; Layout.rightMargin: 8
          Layout.preferredHeight: root.showHotspotCreate ? createFormCol.implicitHeight + 16 : 0
          radius: 8
          color: root.theme.bgSurface
          visible: root.showHotspotCreate
          border.color: root.theme.accentOrange
          border.width: 1
          clip: true

          Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }

          ColumnLayout {
            id: createFormCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Text {
              text: "Create Hotspot"
              color: root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
              font.bold: true
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Text {
                text: "SSID"
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
                Layout.preferredWidth: 36
              }

              Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 6
                color: root.theme.bgBase
                border.color: hotspotSsidInput.activeFocus ? root.theme.accentOrange : root.theme.bgBorder
                border.width: 1

                TextInput {
                  id: hotspotSsidInput
                  anchors.fill: parent
                  anchors.margins: 6
                  color: root.theme.textPrimary
                  font.pixelSize: 11
                  font.family: root.font
                  clip: true
                  text: "Quickshell-Hotspot"
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Text {
                text: "Pass"
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
                Layout.preferredWidth: 36
              }

              Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 6
                color: root.theme.bgBase
                border.color: hotspotPassInput.activeFocus ? root.theme.accentOrange : root.theme.bgBorder
                border.width: 1

                TextInput {
                  id: hotspotPassInput
                  anchors.fill: parent
                  anchors.margins: 6
                  color: root.theme.textPrimary
                  font.pixelSize: 11
                  font.family: root.font
                  echoMode: TextInput.Password
                  clip: true

                  Keys.onReturnPressed: {
                    if (hotspotSsidInput.text.length > 0 && hotspotPassInput.text.length >= 8)
                      root.startHotspot(hotspotSsidInput.text, hotspotPassInput.text)
                  }
                }
              }
            }

            Text {
              text: "Minimum 8 characters"
              color: root.theme.textMuted
              font.pixelSize: 9
              font.family: root.font
              visible: hotspotPassInput.text.length > 0 && hotspotPassInput.text.length < 8
            }

            RowLayout {
              spacing: 6
              Item { Layout.fillWidth: true }

              Rectangle {
                width: cancelHotspotLabel.implicitWidth + 12; height: 24; radius: 6
                color: cancelHotspotArea.containsMouse ? root.theme.bgHover : "transparent"
                border.color: root.theme.bgBorder; border.width: 1

                Text {
                  id: cancelHotspotLabel
                  anchors.centerIn: parent
                  text: "Cancel"
                  color: root.theme.textSecondary
                  font.pixelSize: 10
                  font.family: root.font
                }

                MouseArea {
                  id: cancelHotspotArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.showHotspotCreate = false
                }
              }

              Rectangle {
                width: startHotspotLabel.implicitWidth + 12; height: 24; radius: 6
                color: (startHotspotArea.containsMouse && hotspotPassInput.text.length >= 8) ? root.theme.accentOrange : "transparent"
                border.color: root.theme.accentOrange; border.width: 1

                Text {
                  id: startHotspotLabel
                  anchors.centerIn: parent
                  text: "Start"
                  color: (startHotspotArea.containsMouse && hotspotPassInput.text.length >= 8) ? root.theme.bgBase : root.theme.accentOrange
                  font.pixelSize: 10
                  font.family: root.font
                  font.bold: true
                }

                MouseArea {
                  id: startHotspotArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (hotspotSsidInput.text.length > 0 && hotspotPassInput.text.length >= 8)
                      root.startHotspot(hotspotSsidInput.text, hotspotPassInput.text)
                  }
                }
              }
            }
          }
        }

        // Separator
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: 4; Layout.rightMargin: 4
          Layout.topMargin: 8; Layout.bottomMargin: 8
          height: 1
          color: root.theme.bgBorder
        }

        // ======== WIFI SECTION ========
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 4; Layout.rightMargin: 4
          Layout.bottomMargin: 8
          spacing: 8

          Text {
            text: "󰖩"
            color: root.theme.accentGreen
            font.pixelSize: 16
            font.family: root.font
          }

          Text {
            text: "Wi-Fi"
            color: root.theme.accentPrimary
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
            Layout.fillWidth: true
          }

          // Scan button
          Rectangle {
            width: 24; height: 24; radius: 6
            color: scanArea.containsMouse ? root.theme.bgHover : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰑐"
              color: root.theme.textSecondary
              font.pixelSize: 14
              font.family: root.font
              NumberAnimation on rotation {
                running: root.scanning
                loops: Animation.Infinite
                duration: 1000
                from: 0; to: 360
              }
            }

            MouseArea {
              id: scanArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.refreshScan()
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
            Layout.leftMargin: 8; Layout.rightMargin: 8
            Layout.preferredHeight: 44
            radius: 8
            color: netArea.containsMouse ? root.theme.bgHover :
                   modelData.connected ? root.theme.bgSelected : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10; anchors.rightMargin: 10
              spacing: 8

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
                font.pixelSize: 16
                font.family: root.font
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  text: modelData.ssid || "Hidden Network"
                  color: modelData.connected ? root.theme.accentGreen : root.theme.textPrimary
                  font.pixelSize: 12
                  font.family: root.font
                  font.bold: modelData.connected
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: {
                    if (modelData.connected) return "Connected"
                    if (modelData.security && modelData.security.length > 0 && modelData.security !== "--") return "Secured"
                    return "Open"
                  }
                  color: root.theme.textMuted
                  font.pixelSize: 10
                  font.family: root.font
                }
              }

              Row {
                spacing: 2
                layoutDirection: Qt.RightToLeft
                Repeater {
                  model: 4
                  Rectangle {
                    width: 3
                    height: 6 + index * 3
                    radius: 1
                    anchors.bottom: parent.bottom
                    color: {
                      const s = (netDelegate.modelData.signal || 0) / 100
                      const filled = (4 - index) / 4 <= s
                      return filled ? (netDelegate.modelData.connected ? root.theme.accentGreen : root.theme.accentPrimary) : root.theme.bgBorder
                    }
                  }
                }
              }
            }

            // Disconnect button (outside RowLayout, above netArea)
            Rectangle {
              width: 24; height: 24; radius: 6
              anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
              z: 3
              color: netDisconnectArea.containsMouse ? root.theme.bgHover : "transparent"
              visible: modelData.connected

              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: root.theme.textSecondary
                font.pixelSize: 12
                font.family: root.font
              }

              MouseArea {
                id: netDisconnectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.disconnectWifi()
              }
            }

            MouseArea {
              id: netArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                const net = netDelegate.modelData
                if (net.connected) {
                  root.disconnectWifi()
                } else if (net.security && net.security.length > 0 && net.security !== "--") {
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
          Layout.leftMargin: 8; Layout.rightMargin: 8
          Layout.preferredHeight: 40
          radius: 8
          color: "transparent"
          visible: root.wifiNetworks.length === 0

          Text {
            anchors.centerIn: parent
            text: root.scanning ? "Scanning..." : "No networks found"
            color: root.theme.textMuted
            font.pixelSize: 12
            font.family: root.font
          }
        }

        // Password prompt
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: 8; Layout.rightMargin: 8
          Layout.preferredHeight: root.showPassword ? showPwCol.implicitHeight + 16 : 0
          radius: 8
          color: root.theme.bgSurface
          visible: root.showPassword
          border.color: root.theme.accentPrimary
          border.width: 1
          clip: true

          Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }

          ColumnLayout {
            id: showPwCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Text {
              text: "Password for " + (root.pendingNetwork ? root.pendingNetwork.ssid : "")
              color: root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Rectangle {
              Layout.fillWidth: true
              height: 32
              radius: 6
              color: root.theme.bgBase
              border.color: passwordInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
              border.width: 1

              TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.margins: 8
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.family: root.font
                echoMode: TextInput.Password
                clip: true

                Keys.onReturnPressed: submitPassword()
                Keys.onEscapePressed: { root.showPassword = false; root.pendingNetwork = null }
              }
            }

            RowLayout {
              spacing: 6
              Item { Layout.fillWidth: true }

              Rectangle {
                width: cancelPwLabel.implicitWidth + 12; height: 24; radius: 6
                color: cancelPwArea.containsMouse ? root.theme.bgHover : "transparent"
                border.color: root.theme.bgBorder; border.width: 1

                Text {
                  id: cancelPwLabel
                  anchors.centerIn: parent
                  text: "Cancel"
                  color: root.theme.textSecondary
                  font.pixelSize: 10
                  font.family: root.font
                }

                MouseArea {
                  id: cancelPwArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.showPassword = false; root.pendingNetwork = null }
                }
              }

              Rectangle {
                width: connectPwLabel.implicitWidth + 12; height: 24; radius: 6
                color: connectPwArea.containsMouse ? root.theme.accentPrimary : "transparent"
                border.color: root.theme.accentPrimary; border.width: 1

                Text {
                  id: connectPwLabel
                  anchors.centerIn: parent
                  text: "Connect"
                  color: connectPwArea.containsMouse ? root.theme.bgBase : root.theme.accentPrimary
                  font.pixelSize: 10
                  font.family: root.font
                  font.bold: true
                }

                MouseArea {
                  id: connectPwArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: submitPassword()
                }
              }
            }
          }
        }

        // Separator
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: 4; Layout.rightMargin: 4
          Layout.topMargin: 8; Layout.bottomMargin: 8
          height: 1
          color: root.theme.bgBorder
        }

        // ======== BLUETOOTH SECTION ========
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: 4; Layout.rightMargin: 4
          Layout.bottomMargin: 8
          spacing: 8

          Text {
            text: "󰂯"
            color: root.btEnabled ? root.theme.accentCyan : root.theme.textMuted
            font.pixelSize: 16
            font.family: root.font
          }

          Text {
            text: "Bluetooth"
            color: root.theme.accentPrimary
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
            Layout.fillWidth: true
          }

          // Scan button
          Rectangle {
            width: 24; height: 24; radius: 6
            color: btScanArea.containsMouse ? root.theme.bgHover : "transparent"
            visible: root.btEnabled

            Text {
              anchors.centerIn: parent
              text: root.btScanning ? "󰅗" : "󰈈"
              color: root.btScanning ? root.theme.accentCyan : root.theme.textSecondary
              font.pixelSize: 12
              font.family: root.font
            }

            MouseArea {
              id: btScanArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { if (root.btAdapter) root.btAdapter.discovering = !root.btScanning }
            }
          }

          // Toggle bluetooth
          Rectangle {
            width: 36; height: 20; radius: 10
            color: root.btEnabled ? root.theme.accentCyan : root.theme.bgSurface
            border.color: root.theme.bgBorder; border.width: 1

            Rectangle {
              x: root.btEnabled ? 18 : 2
              width: 16; height: 16; radius: 8
              color: root.btEnabled ? root.theme.bgBase : root.theme.textMuted
              Behavior on x { NumberAnimation { duration: 150 } }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { if (root.btAdapter) root.btAdapter.enabled = !root.btEnabled }
            }
          }
        }

        // Connected BT devices
        Text {
          text: "Connected"
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
          font.bold: true
          Layout.leftMargin: 4
          Layout.bottomMargin: 4
          visible: root.btConnectedDevices.length > 0
        }

        Repeater {
          model: root.btConnectedDevices

          Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 8
            Layout.preferredHeight: 44
            radius: 8
            color: btItemArea.containsMouse ? root.theme.bgHover : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10; anchors.rightMargin: 10
              spacing: 8

              Text {
                text: {
                  const devName = (modelData.name || "").toLowerCase()
                  if (devName.includes("headphone") || devName.includes("headset") || devName.includes("earbuds") || devName.includes("airpods")) return "󰋋"
                  if (devName.includes("mouse")) return "󰍹"
                  if (devName.includes("keyboard")) return "󰌌"
                  if (devName.includes("controller") || devName.includes("gamepad")) return "󰊴"
                  if (devName.includes("speaker")) return "󰝟"
                  return "󰂯"
                }
                color: root.theme.accentCyan
                font.pixelSize: 16
                font.family: root.font
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  text: modelData.name || modelData.deviceName || "Unknown Device"
                  color: root.theme.textPrimary
                  font.pixelSize: 12
                  font.family: root.font
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: {
                    let status = "Connected"
                    if (modelData.batteryAvailable)
                      status += " \u2022 " + Math.round(modelData.battery * 100) + "%"
                    return status
                  }
                  color: root.theme.accentCyan
                  font.pixelSize: 10
                  font.family: root.font
                }
              }

              Rectangle {
                width: 24; height: 24; radius: 6
                color: btDisconnectArea.containsMouse ? root.theme.bgHover : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "󰅖"
                  color: root.theme.textSecondary
                  font.pixelSize: 12
                  font.family: root.font
                }

                MouseArea {
                  id: btDisconnectArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: modelData.disconnect()
                }
              }
            }

            MouseArea {
              id: btItemArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }
        }

        // Available / discovered devices
        Text {
          text: root.btScanning ? "Scanning..." : "Available"
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
          font.bold: true
          Layout.leftMargin: 4
          Layout.topMargin: 4
          Layout.bottomMargin: 4
          visible: root.btEnabled
        }

        Repeater {
          model: root.btAvailableDevices

          Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 8
            Layout.preferredHeight: 44
            radius: 8
            color: btAvailArea.containsMouse ? root.theme.bgHover : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10; anchors.rightMargin: 10
              spacing: 8

              Text {
                text: {
                  const devName = (modelData.name || "").toLowerCase()
                  if (devName.includes("headphone") || devName.includes("headset") || devName.includes("earbuds") || devName.includes("airpods")) return "󰋋"
                  if (devName.includes("mouse")) return "󰍹"
                  if (devName.includes("keyboard")) return "󰌌"
                  if (devName.includes("controller") || devName.includes("gamepad")) return "󰊴"
                  if (devName.includes("speaker")) return "󰝟"
                  return "󰂯"
                }
                color: root.theme.textMuted
                font.pixelSize: 16
                font.family: root.font
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  text: modelData.name || modelData.deviceName || "Unknown Device"
                  color: root.theme.textPrimary
                  font.pixelSize: 12
                  font.family: root.font
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: modelData.paired ? "Paired" : (modelData.pairing ? "Pairing..." : "Not paired")
                  color: modelData.pairing ? root.theme.accentCyan : root.theme.textMuted
                  font.pixelSize: 10
                  font.family: root.font
                }
              }

              // Connect / Pair button
              Rectangle {
                width: 24; height: 24; radius: 6
                color: btConnectArea.containsMouse ? root.theme.bgHover : "transparent"
                visible: !modelData.pairing

                Text {
                  anchors.centerIn: parent
                  text: (modelData.paired || modelData.trusted) ? "󰅸" : "󰌁"
                  color: root.theme.accentCyan
                  font.pixelSize: 12
                  font.family: root.font
                }

                MouseArea {
                  id: btConnectArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.paired || modelData.trusted) {
                      modelData.connect()
                    } else {
                      modelData.pair()
                    }
                  }
                }
              }
            }

            MouseArea {
              id: btAvailArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }
        }

        // No devices message
        Text {
          text: root.btScanning ? "Looking for devices..." : "No devices found"
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
          visible: root.btEnabled && root.btAvailableDevices.length === 0 && root.btConnectedDevices.length === 0
          Layout.leftMargin: 4
        }

        // Bottom spacer
        Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
      }
    }
  }

  function submitPassword() {
    if (root.pendingNetwork && passwordInput.text.length > 0) {
      root.connectWifiPsk(root.pendingNetwork.ssid, passwordInput.text)
    }
    root.showPassword = false
    root.pendingNetwork = null
  }
}
