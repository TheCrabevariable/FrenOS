import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  // ======== CLIPBOARD STATE ========
  property var clipEntries: []
  property string clipSearch: ""

  property var filteredClipEntries: {
    if (clipSearch.length === 0) return clipEntries
    return clipEntries.filter(e => e.text.toLowerCase().includes(clipSearch.toLowerCase()))
  }

  function loadClipEntries() {
    clipEntries = []
    clipDecodeProc.running = true
  }

  function copyClipEntry(entryId, entryText) {
    clipCopyProc.command = ["bash", "-c", "printf '%s' '" + entryId + "' | cliphist decode | wl-copy"]
    clipCopyProc.running = true
  }

  function deleteClipEntry(entryId) {
    clipDelProc.command = ["cliphist", "delete", entryId]
    clipDelProc.running = true
    loadClipEntries()
  }

  Process {
    id: clipDecodeProc
    command: ["bash", "-c", "rm -f /tmp/cliphist-preview-*.png 2>/dev/null; cliphist list | while IFS= read -r line; do id=$(echo \"$line\" | cut -f1); printf '%s' \"$id\" | cliphist decode > /tmp/cliphist-preview-$id.png 2>/dev/null; done; cliphist list"]
    stdout: SplitParser {
      onRead: data => {
        var idx = data.indexOf("\t")
        if (idx < 0) return
        var id = data.substring(0, idx).trim()
        var text = data.substring(idx + 1).trim()
        var isImage = text.includes("binary data")
        var e = root.clipEntries.slice()
        e.push({
          id: id,
          text: text,
          imagePath: isImage ? "file:///tmp/cliphist-preview-" + id + ".png" : ""
        })
        root.clipEntries = e
      }
    }
  }

  Process {
    id: clipCopyProc
    command: ["bash", "-c", "echo hi | cliphist decode | wl-copy"]
  }

  Process {
    id: clipDelProc
    command: ["bash", "-c", "echo hi | cliphist delete"]
  }

  Process {
    id: clipWipeProc
    command: ["cliphist", "wipe"]
    onRunningChanged: { if (!running) root.loadClipEntries() }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: root.loadClipEntries()
  }

  // ======== NOTIFICATIONS STATE ========
  property var hiddenSeqIds: []
  property var notifications: []

  FileView {
    path: "/tmp/quickshell-notifs.json"
    watchChanges: true
    onFileChanged: refreshNotifs()
  }

  function refreshNotifs() { notifReadProc.running = true }

  Process {
    id: notifReadProc
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

  Process {
    id: notifClearAllProc
    command: ["qs", "ipc", "call", "notifications", "dismiss-all"]
    onRunningChanged: { if (!running) root.refreshNotifs() }
  }

  Component.onCompleted: { loadClipEntries(); refreshNotifs() }

  GridLayout {
    id: grid
    anchors.fill: parent
    columns: 2
    rowSpacing: 12
    columnSpacing: 12

    // ======== CLIPBOARD (left column) ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 300
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        // Header
        RowLayout {
          spacing: 8

          Text {
            text: "󰅗"
            color: root.theme.accentOrange
            font.pixelSize: 16
            font.family: root.font
          }

          Text {
            text: "Clipboard"
            color: root.theme.accentOrange
            font.pixelSize: 14
            font.family: root.font
            font.bold: true
            Layout.fillWidth: true
          }

          Rectangle {
            width: 24; height: 24; radius: 6
            color: clipClearArea.containsMouse ? root.theme.bgHover : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: clipClearArea.containsMouse ? root.theme.accentRed : root.theme.textSecondary
              font.pixelSize: 12
              font.family: root.font
            }

            MouseArea {
              id: clipClearArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: clipWipeProc.running = true
            }
          }
        }

        // Search bar
        Rectangle {
          Layout.fillWidth: true
          height: 28
          radius: 6
          color: root.theme.bgBase
          border.color: clipSearchInput.activeFocus ? root.theme.accentOrange : root.theme.bgBorder
          border.width: 1

          TextInput {
            id: clipSearchInput
            anchors.fill: parent
            anchors.margins: 6
            color: root.theme.textPrimary
            font.pixelSize: 11
            font.family: root.font
            clip: true
            onTextChanged: root.clipSearch = text

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍩 Search..."
              color: root.theme.textMuted
              font.pixelSize: 11
              font.family: root.font
              visible: clipSearchInput.text.length === 0 && !clipSearchInput.activeFocus
            }
          }
        }

        // Clipboard list
        ListView {
          id: clipList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 4
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick

          model: root.filteredClipEntries

          delegate: Rectangle {
            id: clipItem
            required property var modelData
            required property int index

            width: clipList.width
            height: modelData.imagePath !== "" ? 56 : 32
            radius: 6
            color: clipItemArea.containsMouse ? root.theme.bgHover : "transparent"

            Image {
              id: clipThumb
              anchors.left: parent.left
              anchors.leftMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              width: 36; height: 36
              source: modelData.imagePath || ""
              fillMode: Image.PreserveAspectFit
              visible: modelData.imagePath !== "" && status === Image.Ready
              asynchronous: true
              cache: false
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: modelData.imagePath !== "" ? 48 : 8
              anchors.rightMargin: 8
              spacing: 6
              visible: modelData.imagePath === ""

              Text {
                text: "󰅗"
                color: root.theme.accentOrange
                font.pixelSize: 11
                font.family: root.font
              }

              Text {
                Layout.fillWidth: true
                text: modelData.text
                color: root.theme.textPrimary
                font.pixelSize: 11
                font.family: root.font
                elide: Text.ElideRight
              }
            }

            ColumnLayout {
              anchors.left: clipThumb.visible ? clipThumb.right : parent.left
              anchors.leftMargin: clipThumb.visible ? 6 : 8
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1
              visible: modelData.imagePath !== ""

              Text {
                Layout.fillWidth: true
                text: "Screenshot"
                color: root.theme.textPrimary
                font.pixelSize: 11
                font.family: root.font
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: modelData.text
                color: root.theme.textMuted
                font.pixelSize: 9
                font.family: root.font
                elide: Text.ElideRight
              }
            }

            Rectangle {
              anchors.right: parent.right
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              width: 20; height: 20; radius: 5
              color: clipDelArea.containsMouse ? root.theme.bgHover : "transparent"
              visible: clipItemArea.containsMouse

              Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
              }

              MouseArea {
                id: clipDelArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deleteClipEntry(modelData.id)
              }
            }

            MouseArea {
              id: clipItemArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyClipEntry(modelData.id, modelData.text)
            }
          }

          Text {
            anchors.centerIn: parent
            text: "󰅗 Clipboard is empty"
            color: root.theme.textMuted
            font.pixelSize: 12
            font.family: root.font
            visible: clipList.count === 0
          }
        }
      }
    }

    // ======== NOTIFICATIONS (right column) ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 300
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        // Header
        RowLayout {
          spacing: 8

          Text {
            text: "󰂜"
            color: root.theme.accentPrimary
            font.pixelSize: 16
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
            width: Math.max(20, notifCountLabel.implicitWidth + 10)
            height: 20
            radius: 10
            color: root.theme.bgBase
            visible: root.getVisibleNotifs().length > 0

            Text {
              id: notifCountLabel
              anchors.centerIn: parent
              text: root.getVisibleNotifs().length
              color: root.theme.textMuted
              font.pixelSize: 10
              font.family: root.font
            }
          }

          Rectangle {
            width: 24; height: 24; radius: 6
            color: notifClearArea.containsMouse ? root.theme.bgHover : "transparent"
            visible: root.getVisibleNotifs().length > 0

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: notifClearArea.containsMouse ? root.theme.accentRed : root.theme.textSecondary
              font.pixelSize: 12
              font.family: root.font
            }

            MouseArea {
              id: notifClearArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: notifClearAllProc.running = true
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
          font.pixelSize: 10
          font.family: root.font
        }

        // Notification list
        ListView {
          id: notifList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 6
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick

          model: root.getVisibleNotifs()

          delegate: Rectangle {
            id: notifCard
            required property var modelData
            required property int index

            width: notifList.width
            height: notifCardCol.implicitHeight + 16
            radius: 10
            color: notifCardArea.containsMouse ? root.theme.bgHover : root.theme.bgBase
            border.color: root.theme.bgBorder
            border.width: 1
            clip: true

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
              id: notifCardCol
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
                  color: notifDismissArea.containsMouse ? root.theme.bgBorder : "transparent"
                  Layout.alignment: Qt.AlignVCenter

                  Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: notifDismissArea.containsMouse ? root.theme.accentRed : root.theme.textMuted
                    font.pixelSize: 10
                    font.family: root.font
                  }

                  MouseArea {
                    id: notifDismissArea
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

          Text {
            anchors.centerIn: parent
            text: "󰂜 No notifications"
            color: root.theme.textMuted
            font.pixelSize: 12
            font.family: root.font
            visible: notifList.count === 0
          }
        }
      }
    }
  }
}
