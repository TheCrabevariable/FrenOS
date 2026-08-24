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
        text: DashboardInfo.weatherIcon || "󰖨"
        color: root.theme.accentCyan
        font.pixelSize: 18
        font.family: root.font
      }

      Text {
        text: "Weather"
        color: root.theme.accentCyan
        font.pixelSize: 14
        font.family: root.font
        font.bold: true
      }

      Item { Layout.fillWidth: true }
    }

    // Weather card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 200
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: DashboardInfo.weatherLoaded

      RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // Main temp
        ColumnLayout {
          spacing: 4

          Text {
            text: DashboardInfo.weatherIcon || "󰖨"
            color: root.theme.accentCyan
            font.pixelSize: 48
            font.family: root.font
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: DashboardInfo.weatherTemp
            color: root.theme.textPrimary
            font.pixelSize: 28
            font.family: root.font
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: DashboardInfo.weatherDesc
            color: root.theme.textSecondary
            font.pixelSize: 12
            font.family: root.font
            Layout.alignment: Qt.AlignHCenter
          }
        }

        // Details
        ColumnLayout {
          spacing: 12

          RowLayout {
            spacing: 8

            Text {
              text: "󰖕"
              color: root.theme.textMuted
              font.pixelSize: 14
              font.family: root.font
            }

            ColumnLayout {
              spacing: 0
              Text {
                text: "Feels like"
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
              Text {
                text: DashboardInfo.weatherFeelsLike
                color: root.theme.textPrimary
                font.pixelSize: 13
                font.family: root.font
              }
            }
          }

          RowLayout {
            spacing: 8

            Text {
              text: "󰖗"
              color: root.theme.textMuted
              font.pixelSize: 14
              font.family: root.font
            }

            ColumnLayout {
              spacing: 0
              Text {
                text: "Humidity"
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
              Text {
                text: DashboardInfo.weatherHumidity
                color: root.theme.textPrimary
                font.pixelSize: 13
                font.family: root.font
              }
            }
          }

          RowLayout {
            spacing: 8

            Text {
              text: "󰖝"
              color: root.theme.textMuted
              font.pixelSize: 14
              font.family: root.font
            }

            ColumnLayout {
              spacing: 0
              Text {
                text: "Wind"
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }
              Text {
                text: DashboardInfo.weatherWind
                color: root.theme.textPrimary
                font.pixelSize: 13
                font.family: root.font
              }
            }
          }
        }
      }
    }

    // Loading / error state
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: !DashboardInfo.weatherLoaded

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        Text {
          text: "󰖨"
          color: root.theme.textMuted
          font.pixelSize: 28
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }

        Text {
          text: "Loading weather..."
          color: root.theme.textMuted
          font.pixelSize: 12
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }
  }
}
