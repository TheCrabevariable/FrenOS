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
        text: "󰋊"
        color: root.theme.accentOrange
        font.pixelSize: 18
        font.family: root.font
      }

      Text {
        text: "Storage"
        color: root.theme.accentOrange
        font.pixelSize: 14
        font.family: root.font
        font.bold: true
      }

      Item { Layout.fillWidth: true }
    }

    // Storage devices
    Repeater {
      model: DashboardInfo.storageDevices

      Rectangle {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        Layout.preferredHeight: 90
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
              text: "󰋊"
              color: root.theme.accentOrange
              font.pixelSize: 14
              font.family: root.font
            }

            Text {
              text: modelData.mount
              color: root.theme.textPrimary
              font.pixelSize: 13
              font.family: root.font
              font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
              text: modelData.device
              color: root.theme.textMuted
              font.pixelSize: 10
              font.family: root.font
            }
          }

          // Usage bar
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
                width: parent.width * modelData.percent / 100
                color: modelData.percent > 90 ? root.theme.accentRed :
                       modelData.percent > 70 ? root.theme.accentOrange :
                       root.theme.accentGreen
              }
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.percent + "%"
              color: root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
              font.bold: true
            }
          }

          // Size info
          RowLayout {
            spacing: 16

            Text {
              text: modelData.used + " / " + modelData.size
              color: root.theme.textSecondary
              font.pixelSize: 11
              font.family: root.font
            }

            Item { Layout.fillWidth: true }

            Text {
              text: modelData.avail + " free"
              color: root.theme.textMuted
              font.pixelSize: 11
              font.family: root.font
            }
          }
        }
      }
    }

    // No storage
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 80
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: DashboardInfo.storageDevices.length === 0

      Text {
        anchors.centerIn: parent
        text: "No storage devices found"
        color: root.theme.textMuted
        font.pixelSize: 12
        font.family: root.font
      }
    }
  }
}
