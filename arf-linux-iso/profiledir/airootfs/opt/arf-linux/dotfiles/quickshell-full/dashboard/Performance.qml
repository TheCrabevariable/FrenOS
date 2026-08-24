import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  property string currentProfile: DashboardInfo.powerProfile

  function setProfile(profile) {
    setProfileProc.command = ["powerprofilesctl", "set", profile]
    setProfileProc.running = true
    root.currentProfile = profile
  }

  Process {
    id: setProfileProc
    running: false
  }

  Process {
    id: getProfileProc
    command: ["powerprofilesctl", "get"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: { root.currentProfile = text.trim() }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: getProfileProc.running = true
  }

  GridLayout {
    id: grid
    anchors.fill: parent
    columns: 2
    rowSpacing: 12
    columnSpacing: 12

    // ======== CPU CARD ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
          spacing: 8

          Text {
            text: "󰻠"
            color: root.theme.accentPrimary
            font.pixelSize: 18
            font.family: root.font
          }

          Text {
            text: "CPU"
            color: root.theme.accentPrimary
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          Text {
            text: DashboardInfo.cpuTemp
            color: root.theme.accentRed
            font.pixelSize: 11
            font.family: root.font
          }
        }

        Text {
          text: DashboardInfo.cpuName || "Unknown CPU"
          color: root.theme.textSecondary
          font.pixelSize: 11
          font.family: root.font
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        // Usage bar
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 20

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 8
            radius: 4
            color: root.theme.bgBase

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              height: 8
              radius: 4
              width: parent.width * DashboardInfo.cpuUsage / 100
              color: DashboardInfo.cpuUsage > 80 ? root.theme.accentRed :
                     DashboardInfo.cpuUsage > 50 ? root.theme.accentOrange :
                     root.theme.accentPrimary
              Behavior on width { NumberAnimation { duration: 300 } }
            }
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: DashboardInfo.cpuUsage + "%"
            color: root.theme.textPrimary
            font.pixelSize: 11
            font.family: root.font
            font.bold: true
          }
        }

        // Core indicators
        RowLayout {
          spacing: 4
          Repeater {
            model: DashboardInfo.coreCount
            Rectangle {
              required property int index
              Layout.fillWidth: true
              height: 4
              radius: 2
              color: root.theme.bgBase

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * DashboardInfo.cpuUsage / 100
                radius: 2
                color: DashboardInfo.cpuUsage > 80 ? root.theme.accentRed :
                       DashboardInfo.cpuUsage > 50 ? root.theme.accentOrange :
                       root.theme.accentGreen
              }
            }
          }
        }

        Text {
          text: DashboardInfo.uptime
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }

    // ======== GPU CARD ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
          spacing: 8

          Text {
            text: "󰍹"
            color: root.theme.accentCyan
            font.pixelSize: 18
            font.family: root.font
          }

          Text {
            text: "GPU"
            color: root.theme.accentCyan
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          Text {
            text: DashboardInfo.gpuTemp
            color: root.theme.accentRed
            font.pixelSize: 11
            font.family: root.font
          }
        }

        Text {
          text: DashboardInfo.gpuName || "No GPU detected"
          color: root.theme.textSecondary
          font.pixelSize: 11
          font.family: root.font
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        // GPU temp big display
        ColumnLayout {
          spacing: 2

          Text {
            text: DashboardInfo.gpuTemp
            color: root.theme.textPrimary
            font.pixelSize: 28
            font.family: root.font
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: "Temperature"
            color: root.theme.textMuted
            font.pixelSize: 10
            font.family: root.font
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }

    // ======== MEMORY CARD ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
          spacing: 8

          Text {
            text: "󰍛"
            color: root.theme.accentGreen
            font.pixelSize: 18
            font.family: root.font
          }

          Text {
            text: "Memory"
            color: root.theme.accentGreen
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
          }
        }

        Text {
          text: DashboardInfo.memUsed.toFixed(1) + " / " + DashboardInfo.memTotal.toFixed(1) + " GB"
          color: root.theme.textPrimary
          font.pixelSize: 18
          font.family: root.font
          font.bold: true
        }

        // Memory bar
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 16

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 8
            radius: 4
            color: root.theme.bgBase

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              height: 8
              radius: 4
              width: parent.width * DashboardInfo.memPercent / 100
              color: DashboardInfo.memPercent > 80 ? root.theme.accentRed :
                     DashboardInfo.memPercent > 60 ? root.theme.accentOrange :
                     root.theme.accentGreen
              Behavior on width { NumberAnimation { duration: 300 } }
            }
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: DashboardInfo.memPercent + "%"
            color: root.theme.textPrimary
            font.pixelSize: 11
            font.family: root.font
            font.bold: true
          }
        }

        Text {
          text: DashboardInfo.memAvailable.toFixed(1) + " GB available"
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
        }
      }
    }

    // ======== POWER PROFILE CARD ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 180
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
          spacing: 8

          Text {
            text: {
              if (root.currentProfile === "power-saver") return "󰾆"
              if (root.currentProfile === "performance") return "󰀠"
              return "󰓅"
            }
            color: {
              if (root.currentProfile === "power-saver") return root.theme.accentGreen
              if (root.currentProfile === "performance") return root.theme.accentRed
              return root.theme.accentPrimary
            }
            font.pixelSize: 18
            font.family: root.font
          }

          Text {
            text: "Power Profile"
            color: root.theme.textPrimary
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 8
          color: saverArea.containsMouse ? root.theme.bgHover :
                 root.currentProfile === "power-saver" ? root.theme.bgSelected : "transparent"
          border.color: root.currentProfile === "power-saver" ? root.theme.accentGreen : "transparent"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text { text: "󰾆"; color: root.currentProfile === "power-saver" ? root.theme.accentGreen : root.theme.textMuted; font.pixelSize: 14; font.family: root.font }
            Text { text: "Power Saver"; color: root.currentProfile === "power-saver" ? root.theme.accentGreen : root.theme.textSecondary; font.pixelSize: 12; font.family: root.font; font.bold: root.currentProfile === "power-saver"; Layout.fillWidth: true }
            Text { text: "󰄬"; color: root.theme.accentGreen; font.pixelSize: 12; font.family: root.font; visible: root.currentProfile === "power-saver" }
          }

          MouseArea { id: saverArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setProfile("power-saver") }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 8
          color: balancedArea.containsMouse ? root.theme.bgHover :
                 root.currentProfile === "balanced" ? root.theme.bgSelected : "transparent"
          border.color: root.currentProfile === "balanced" ? root.theme.accentPrimary : "transparent"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text { text: "󰓅"; color: root.currentProfile === "balanced" ? root.theme.accentPrimary : root.theme.textMuted; font.pixelSize: 14; font.family: root.font }
            Text { text: "Balanced"; color: root.currentProfile === "balanced" ? root.theme.accentPrimary : root.theme.textSecondary; font.pixelSize: 12; font.family: root.font; font.bold: root.currentProfile === "balanced"; Layout.fillWidth: true }
            Text { text: "󰄬"; color: root.theme.accentPrimary; font.pixelSize: 12; font.family: root.font; visible: root.currentProfile === "balanced" }
          }

          MouseArea { id: balancedArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setProfile("balanced") }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 8
          color: perfArea.containsMouse ? root.theme.bgHover :
                 root.currentProfile === "performance" ? root.theme.bgSelected : "transparent"
          border.color: root.currentProfile === "performance" ? root.theme.accentRed : "transparent"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text { text: "󰀠"; color: root.currentProfile === "performance" ? root.theme.accentRed : root.theme.textMuted; font.pixelSize: 14; font.family: root.font }
            Text { text: "Performance"; color: root.currentProfile === "performance" ? root.theme.accentRed : root.theme.textSecondary; font.pixelSize: 12; font.family: root.font; font.bold: root.currentProfile === "performance"; Layout.fillWidth: true }
            Text { text: "󰄬"; color: root.theme.accentRed; font.pixelSize: 12; font.family: root.font; visible: root.currentProfile === "performance" }
          }

          MouseArea { id: perfArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setProfile("performance") }
        }
      }
    }

    // ======== BATTERY CARD ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
          spacing: 8

          Text {
            text: {
              if (!DashboardInfo.hasBattery) return "󰁹"
              const lvl = DashboardInfo.batteryLevel
              if (DashboardInfo.batteryCharging) return ""
              if (lvl >= 90) return "󰁹"
              if (lvl >= 70) return "󰂁"
              if (lvl >= 50) return "󰁿"
              if (lvl >= 30) return "󰁽"
              if (lvl >= 10) return "󰁻"
              return "󰁺"
            }
            color: {
              if (!DashboardInfo.hasBattery) return root.theme.textMuted
              if (DashboardInfo.batteryCharging) return root.theme.accentGreen
              if (DashboardInfo.batteryLevel > 20) return root.theme.accentGreen
              return root.theme.accentRed
            }
            font.pixelSize: 18
            font.family: root.font
          }

          Text {
            text: "Battery"
            color: root.theme.accentGreen
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          Text {
            text: DashboardInfo.hasBattery ? DashboardInfo.batteryLevel + "%" : "N/A"
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            font.bold: true
          }
        }

        Text {
          text: "No battery detected"
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: root.font
          visible: !DashboardInfo.hasBattery
          Layout.alignment: Qt.AlignHCenter
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 16
          visible: DashboardInfo.hasBattery

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 8
            radius: 4
            color: root.theme.bgBase

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              height: 8
              radius: 4
              width: parent.width * DashboardInfo.batteryLevel / 100
              color: DashboardInfo.batteryCharging ? root.theme.accentGreen :
                     DashboardInfo.batteryLevel > 20 ? root.theme.accentGreen :
                     DashboardInfo.batteryLevel > 10 ? root.theme.accentOrange :
                     root.theme.accentRed
              Behavior on width { NumberAnimation { duration: 300 } }
            }
          }
        }

        Text {
          text: DashboardInfo.hasBattery ? DashboardInfo.batteryStatus : ""
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
          visible: DashboardInfo.hasBattery
        }
      }
    }
  }
}
