import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"
  property real brightnessValue: 0
  property string brightnessMethod: ""
  property var ddcMonitors: []
  property int selectedMonitorBus: -1

  signal brightnessSet(string command, real value)
  signal monitorChanged(int bus)

  function busPrefix() {
    if (root.brightnessMethod === "ddcutil" && root.selectedMonitorBus > 0)
      return "ddcutil -b " + root.selectedMonitorBus + " "
    return ""
  }

  function setBrightness(val) {
    const clamped = Math.max(0, Math.min(1, val))
    if (root.brightnessMethod === "ddcutil") {
      root.brightnessSet(busPrefix() + "setvcp 10 " + Math.round(clamped * 100), clamped)
    } else {
      root.brightnessSet("brightnessctl set " + Math.round(clamped * 100) + "%", clamped)
    }
  }

  property bool showMonitors: false

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
      anchors.fill: parent
      anchors.margins: 10
      spacing: 6

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: "\uf185"
          color: root.theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
        }

        Text {
          text: "Brightness"
          color: root.theme.accentPrimary
          font.pixelSize: 12
          font.family: root.font
          font.bold: true
          Layout.fillWidth: true
        }

        Text {
          text: Math.round(root.brightnessValue * 100) + "%"
          color: root.theme.textPrimary
          font.pixelSize: 12
          font.family: root.font
          font.bold: true
        }
      }

      // Monitor selector (only for ddcutil with multiple monitors)
      Rectangle {
        Layout.fillWidth: true
        height: root.ddcMonitors.length > 1 ? 28 : 0
        radius: 6
        color: root.theme.bgSurface
        border.color: root.theme.bgBorder
        border.width: 1
        visible: root.ddcMonitors.length > 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8; anchors.rightMargin: 8
          spacing: 4

          Repeater {
            model: root.ddcMonitors

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.margins: 2
              radius: 4
              color: monitorArea.containsMouse ? root.theme.bgHover :
                     modelData.bus === root.selectedMonitorBus ? root.theme.accentPrimary : "transparent"

              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: modelData.bus === root.selectedMonitorBus ? root.theme.bgBase : root.theme.textSecondary
                font.pixelSize: 9
                font.family: root.font
                font.bold: modelData.bus === root.selectedMonitorBus
                elide: Text.ElideRight
              }

              MouseArea {
                id: monitorArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.monitorChanged(modelData.bus)
              }
            }
          }
        }
      }

      // Slider track
      Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        height: 24
        radius: 12
        color: root.theme.bgSurface
        border.color: root.theme.bgBorder
        border.width: 1

        Rectangle {
          x: 1; y: 1
          width: Math.max(0, root.brightnessValue * (parent.width - 2))
          height: parent.height - 2
          radius: 11
          color: root.theme.accentPrimary
          Behavior on width { NumberAnimation { duration: 80 } }
        }

        Rectangle {
          x: Math.max(0, root.brightnessValue * (parent.width - 16))
          y: parent.height / 2 - 10
          width: 20; height: 20; radius: 10
          color: root.theme.bgBase
          border.color: root.theme.accentPrimary
          border.width: 2
          Behavior on x { NumberAnimation { duration: 80 } }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onWheel: (wheel) => {
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.setBrightness(root.brightnessValue + delta)
          }
          onClicked: (mouse) => {
            root.setBrightness(mouse.x / width)
          }
          onPositionChanged: (mouse) => {
            if (pressed) {
              root.setBrightness(mouse.x / width)
            }
          }
        }
      }

      // Quick presets
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 4

        Repeater {
          model: [25, 50, 75, 100]

          Rectangle {
            Layout.fillWidth: true
            height: 24
            radius: 6
            color: presetArea.containsMouse ? root.theme.bgHover :
                   Math.round(root.brightnessValue * 100) === modelData ? root.theme.accentPrimary : "transparent"
            border.color: Math.round(root.brightnessValue * 100) === modelData ? root.theme.accentPrimary : root.theme.bgBorder
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData + "%"
              color: Math.round(root.brightnessValue * 100) === modelData ? root.theme.bgBase : root.theme.textSecondary
              font.pixelSize: 10
              font.family: root.font
              font.bold: Math.round(root.brightnessValue * 100) === modelData
            }

            MouseArea {
              id: presetArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setBrightness(modelData / 100)
            }
          }
        }
      }
    }
  }
}
