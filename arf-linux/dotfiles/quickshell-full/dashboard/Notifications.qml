import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  property var hiddenSeqIds: []
  property var notifications: []

  FileView {
    path: "/tmp/quickshell-notifs.json"
    watchChanges: true
    onFileChanged: refreshNotifs()
  }

  function refreshNotifs() { readFileProc.running = true }

  Process {
    id: readFileProc
    command: ["cat", "/tmp/quickshell-notifs.json"]
    stdout: SplitParser {
      onRead: data => {
        try {
          var parsed = JSON.parse(data)
          root.notifications = parsed
        } catch(e) {}
      }
    }
  }

  function getVisibleNotifs() {
    return root.notifications.filter(function(n) {
      return !root.hiddenSeqIds.includes(n.seqId)
    })
  }

  function hideNotif(seqId) {
    root.hiddenSeqIds = [...root.hiddenSeqIds, seqId]
  }

  Component.onCompleted: refreshNotifs()

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: 0

    // Header
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4; Layout.rightMargin: 4
      Layout.topMargin: 4; Layout.bottomMargin: 8
      spacing: 8

      Text {
        text: "󰂜"
        color: root.theme.accentPrimary
        font.pixelSize: 18
        font.family: root.font
      }

      Text {
        text: "Notifications"
        color: root.theme.accentPrimary
        font.pixelSize: 14
        font.family: root.font
        font.bold: true
        Layout.fillWidth: true
      }

      // Count badge
      Rectangle {
        width: Math.max(20, countLabel.implicitWidth + 10)
        height: 20
        radius: 10
        color: root.theme.bgSurface
        visible: root.getVisibleNotifs().length > 0

        Text {
          id: countLabel
          anchors.centerIn: parent
          text: root.getVisibleNotifs().length
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: root.font
        }
      }

      // Clear all button
      Rectangle {
        width: 24; height: 24; radius: 6
        color: clearAllArea.containsMouse ? root.theme.bgHover : "transparent"
        visible: root.getVisibleNotifs().length > 0

        Text {
          anchors.centerIn: parent
          text: "󰅖"
          color: clearAllArea.containsMouse ? root.theme.accentRed : root.theme.textSecondary
          font.pixelSize: 12
          font.family: root.font
        }

        MouseArea {
          id: clearAllArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: clearAllProc.running = true
        }

        Process {
          id: clearAllProc
          command: ["qs", "ipc", "call", "notifications", "dismiss-all"]
          onRunningChanged: { if (!running) root.refreshNotifs() }
        }
      }
    }

    // Count text
    Text {
      text: {
        var count = root.getVisibleNotifs().length
        return count === 0 ? "No notifications" : count + " notification" + (count !== 1 ? "s" : "")
      }
      color: root.theme.textMuted
      font.pixelSize: 11
      font.family: root.font
      Layout.leftMargin: 4
      Layout.bottomMargin: 8
    }

    // Separator
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: 4; Layout.rightMargin: 4
      Layout.bottomMargin: 8
      height: 1
      color: root.theme.bgBorder
    }

    // Notification list
    ListView {
      id: notifList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: 6
      boundsBehavior: Flickable.StopAtBounds

      model: root.getVisibleNotifs()

      delegate: Rectangle {
        id: notifCard
        required property var modelData
        required property int index

        width: notifList.width
        height: cardCol.implicitHeight + 16
        radius: 10
        color: notifCardArea.containsMouse ? root.theme.bgHover : root.theme.bgSurface
        border.color: root.theme.bgBorder
        border.width: 1
        clip: true

        // Left accent bar
        Rectangle {
          width: 3
          height: parent.height - 12
          radius: 2
          anchors.left: parent.left
          anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          color: root.theme.urgencyNormal
        }

        ColumnLayout {
          id: cardCol
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 10
          anchors.topMargin: 10
          anchors.bottomMargin: 10
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
              text: {
                const name = (modelData.appName || "").toLowerCase()
                if (name.includes("discord")) return "󰙯"
                if (name.includes("firefox")) return "󰈹"
                if (name.includes("spotify")) return "󰓇"
                return "󰂚"
              }
              color: root.theme.urgencyNormal
              font.pixelSize: 12
              font.family: root.font
            }

            Text {
              text: modelData.appName || "Notification"
              color: root.theme.textMuted
              font.pixelSize: 10
              font.family: root.font
              Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: 18; height: 18; radius: 9
              color: dismissHover.containsMouse ? root.theme.bgBorder : "transparent"
              Layout.alignment: Qt.AlignVCenter

              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: dismissHover.containsMouse ? root.theme.accentRed : root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }

              MouseArea {
                id: dismissHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.hideNotif(modelData.seqId)
              }
            }
          }

          Text {
            text: modelData.summary || ""
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: text !== ""
          }

          Text {
            text: modelData.body || ""
            color: root.theme.textSecondary
            font.pixelSize: 11
            font.family: root.font
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: text !== ""
            textFormat: Text.PlainText
          }
        }

        MouseArea {
          id: notifCardArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          z: -1
          onClicked: root.hideNotif(modelData.seqId)
        }
      }

      // Empty state
      Text {
        anchors.centerIn: parent
        text: "󰂜 No notifications"
        color: root.theme.textMuted
        font.pixelSize: 13
        font.family: root.font
        visible: notifList.count === 0
      }
    }
  }
}
