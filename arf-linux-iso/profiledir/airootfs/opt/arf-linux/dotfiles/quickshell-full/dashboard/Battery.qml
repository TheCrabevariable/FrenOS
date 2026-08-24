import QtQuick
import QtQuick.Layouts

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: 12

    // Header
    RowLayout {
      spacing: 8

      Text {
        text: "󰁹"
        color: root.theme.accentGreen
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
    }

    // No battery
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: !DashboardInfo.hasBattery

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        Text {
          text: "󰁹"
          color: root.theme.textMuted
          font.pixelSize: 28
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }

        Text {
          text: "No battery detected"
          color: root.theme.textMuted
          font.pixelSize: 12
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }

    // Battery card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 180
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: DashboardInfo.hasBattery

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Level + status
        RowLayout {
          spacing: 12

          // Large battery icon
          Text {
            text: {
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
              const lvl = DashboardInfo.batteryLevel
              if (DashboardInfo.batteryCharging) return root.theme.accentGreen
              if (lvl > 20) return root.theme.accentGreen
              if (lvl > 10) return root.theme.accentOrange
              return root.theme.accentRed
            }
            font.pixelSize: 36
            font.family: root.font
          }

          ColumnLayout {
            spacing: 2

            Text {
              text: DashboardInfo.batteryLevel + "%"
              color: root.theme.textPrimary
              font.pixelSize: 28
              font.family: root.font
              font.bold: true
            }

            Text {
              text: DashboardInfo.batteryStatus
              color: root.theme.textSecondary
              font.pixelSize: 12
              font.family: root.font
            }
          }
        }

        // Battery bar
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 16

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 10
            radius: 5
            color: root.theme.bgBase

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              height: 10
              radius: 5
              width: parent.width * DashboardInfo.batteryLevel / 100
              color: DashboardInfo.batteryCharging ? root.theme.accentGreen :
                     DashboardInfo.batteryLevel > 20 ? root.theme.accentGreen :
                     DashboardInfo.batteryLevel > 10 ? root.theme.accentOrange :
                     root.theme.accentRed

              Behavior on width { NumberAnimation { duration: 300 } }
            }
          }
        }

        // Stats
        RowLayout {
          Layout.fillWidth: true

          ColumnLayout {
            spacing: 0
            Text {
              text: "Status"
              color: root.theme.textMuted
              font.pixelSize: 10
              font.family: root.font
            }
            Text {
              text: DashboardInfo.batteryCharging ? "Charging" : "Discharging"
              color: root.theme.textPrimary
              font.pixelSize: 12
              font.family: root.font
            }
          }

          Item { Layout.fillWidth: true }
        }
      }
    }
  }
}
