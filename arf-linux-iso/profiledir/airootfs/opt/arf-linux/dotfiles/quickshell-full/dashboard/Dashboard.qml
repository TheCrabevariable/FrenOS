import QtQuick
import QtQuick.Layouts

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"
  property int activeTab: 0

  signal close()

  property var tabs: [
    { icon: "󰋑", label: "Overview" },
    { icon: "󰻠", label: "Performance" },
    { icon: "󰎈", label: "Media" },
    { icon: "󰖩", label: "Network" },
    { icon: "󰂜", label: "Notifs" }
  ]

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: theme.bgBase
    border.color: Qt.rgba(theme.accentPrimary.r, theme.accentPrimary.g, theme.accentPrimary.b, 0.3)
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 0

      // ======== HEADER ========
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 12

        ColumnLayout {
          spacing: 0

          Text {
            text: DashboardInfo.userName || "user"
            color: theme.textPrimary
            font.pixelSize: 13
            font.family: root.font
            font.bold: true
          }

          Text {
            text: DashboardInfo.uptime ? "Uptime: " + DashboardInfo.uptime : ""
            color: theme.textMuted
            font.pixelSize: 10
            font.family: root.font
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: 24; height: 24; radius: 12
          color: closeArea.containsMouse ? theme.bgHover : "transparent"

          Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: closeArea.containsMouse ? theme.textPrimary : theme.textMuted
            font.pixelSize: 12
            font.family: root.font
          }

          MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }
      }

      // ======== TAB BAR ========
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 36

        Row {
          id: tabRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: 32
          spacing: 0

          Repeater {
            model: root.tabs

            Rectangle {
              required property var modelData
              required property int index
              property bool isActive: root.activeTab === index

              width: tabRow.width / root.tabs.length
              height: 32
              color: isActive ? theme.accentPrimary :
                     tabArea.containsMouse ? theme.bgHover : "transparent"
              radius: 6

              Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.icon
                  color: parent.parent.isActive ? theme.bgBase : theme.textSecondary
                  font.pixelSize: 14
                  font.family: root.font
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.label
                  color: parent.parent.isActive ? theme.bgBase : theme.textSecondary
                  font.pixelSize: 11
                  font.family: root.font
                  font.bold: parent.parent.isActive
                  visible: root.width > 550
                }
              }

              MouseArea {
                id: tabArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = index
              }
            }
          }
        }

        Rectangle {
          id: tabIndicator
          width: tabRow.width / root.tabs.length
          height: 3
          radius: 2
          color: theme.accentPrimary
          y: 32
          x: root.activeTab * width

          Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
          }
        }
      }

      // ======== SEPARATOR ========
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.bottomMargin: 8
        color: theme.bgBorder
      }

      // ======== SWIPEABLE CONTENT ========
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        property real _startX: 0
        property real _startY: 0
        property bool _decided: false
        property bool _isHorizontal: false

        MouseArea {
          id: swipeArea
          anchors.fill: parent
          hoverEnabled: false
          propagateComposedEvents: true

          onPressed: {
            swipeArea.parent._startX = mouse.x
            swipeArea.parent._startY = mouse.y
            swipeArea.parent._decided = false
            swipeArea.parent._isHorizontal = false
          }

          onPositionChanged: {
            if (!pressed) return
            const p = swipeArea.parent
            if (!p._decided) {
              const dx = Math.abs(mouse.x - p._startX)
              const dy = Math.abs(mouse.y - p._startY)
              if (dx > 10 || dy > 10) {
                p._decided = true
                p._isHorizontal = dx > dy
                if (!p._isHorizontal) mouse.accepted = false
              }
            }
          }

          onReleased: {
            if (!swipeArea.parent._isHorizontal) return
            const dx = mouse.x - swipeArea.parent._startX
            if (dx < -60 && root.activeTab < root.tabs.length - 1) root.activeTab++
            else if (dx > 60 && root.activeTab > 0) root.activeTab--
          }
        }

        Row {
          id: contentRow
          x: -root.activeTab * (width / root.tabs.length)
          height: parent.height
          spacing: 0

          Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
          }

          Overview {
            width: swipeArea.parent.width
            height: swipeArea.parent.height
            theme: root.theme
            font: root.font
          }

          Performance {
            width: swipeArea.parent.width
            height: swipeArea.parent.height
            theme: root.theme
            font: root.font
          }

          Media {
            width: swipeArea.parent.width
            height: swipeArea.parent.height
            theme: root.theme
            font: root.font
          }

          Network {
            width: swipeArea.parent.width
            height: swipeArea.parent.height
            theme: root.theme
            font: root.font
          }

          ClipboardNotifications {
            width: swipeArea.parent.width
            height: swipeArea.parent.height
            theme: root.theme
            font: root.font
          }
        }
      }
    }
  }
}
