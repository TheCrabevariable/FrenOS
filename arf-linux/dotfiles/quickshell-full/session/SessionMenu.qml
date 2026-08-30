import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: root
  visible: false
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"
  property bool shown: false

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.namespace: "quickshell-session-menu"
  exclusionMode: ExclusionMode.Ignore

  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"

  IpcHandler {
    target: "session"
    function toggle(): void {
      if (root.shown) root.close()
      else root.open()
    }
  }

  function open() {
    closeTimer.stop()
    root.visible = true
    root.shown = true
  }

  function close() {
    root.shown = false
    closeTimer.restart()
  }

  function doAction(cmd) {
    root.close()
    actionProc.command = cmd
    actionProc.running = true
  }

  Timer {
    id: closeTimer
    interval: 300
    onTriggered: root.visible = false
  }

  Process {
    id: actionProc
    running: false
  }

  readonly property var actions: [
    { icon: "\uf023", label: "Lock",     cmd: ["hyprlock"],                     hoverColor: theme.accentCyan },
    { icon: "\uf08b", label: "Logout",   cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"],  hoverColor: theme.accentPrimary },
    { icon: "\uf186", label: "Suspend",  cmd: ["systemctl", "suspend"],         hoverColor: theme.accentOrange },
    { icon: "\uf021", label: "Reboot",   cmd: ["systemctl", "reboot"],          hoverColor: theme.accentGreen },
    { icon: "\uf011", label: "Shutdown", cmd: ["systemctl", "poweroff"],        hoverColor: theme.accentRed }
  ]

  // ======== Backdrop scrim ========
  Rectangle {
    anchors.fill: parent
    color: root.theme.bgOverlay
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  // ======== Right-side panel ========
  Rectangle {
    id: panel
    width: sessionRow.implicitWidth + 28
    height: sessionRow.implicitHeight + 28
    radius: 18
    color: root.theme.bgBase
    border.color: root.theme.bgBorder
    border.width: 1
    focus: true
    Keys.onEscapePressed: root.close()

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.shown ? 24 : -(height + 60)
    opacity: root.shown ? 1 : 0

    Behavior on anchors.bottomMargin {
      NumberAnimation {
        duration: root.shown ? 420 : 260
        easing.type: root.shown ? Easing.OutBack : Easing.InCubic
        easing.overshoot: 0.7
      }
    }

    Behavior on opacity {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    RowLayout {
      id: sessionRow
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      Repeater {
        model: root.actions

        delegate: Rectangle {
          id: actionButton
          required property var modelData
          property bool hovered: btnArea.containsMouse

          Layout.preferredWidth: 108
          Layout.preferredHeight: 88
          radius: 16
          color: hovered ? modelData.hoverColor : root.theme.bgSurface
          border.color: hovered ? modelData.hoverColor : root.theme.bgBorder
          border.width: 1

          Behavior on color { ColorAnimation { duration: 150 } }
          Behavior on border.color { ColorAnimation { duration: 150 } }

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: actionButton.modelData.icon
              color: actionButton.hovered ? root.theme.bgBase : root.theme.textPrimary
              font.pixelSize: 30
              font.family: root.font

              Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: actionButton.modelData.label
              color: actionButton.hovered ? root.theme.bgBase : root.theme.textSecondary
              font.pixelSize: 11
              font.family: root.font
              font.bold: actionButton.hovered

              Behavior on color { ColorAnimation { duration: 150 } }
            }
          }

          MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.doAction(actionButton.modelData.cmd)
          }
        }
      }
    }
  }
}
