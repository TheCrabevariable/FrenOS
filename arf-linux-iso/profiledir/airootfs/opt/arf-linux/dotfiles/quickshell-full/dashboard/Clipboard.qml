import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  property var entries: []
  property string searchText: ""

  property var filteredEntries: {
    if (searchText.length === 0) return entries
    return entries.filter(e => e.text.toLowerCase().includes(searchText.toLowerCase()))
  }

  function loadEntries() {
    entries = []
    decodeAllProc.running = true
  }

  function copyEntry(entryId, entryText) {
    copyProc.command = ["bash", "-c", "printf '%s' '" + entryId + "' | cliphist decode | wl-copy"]
    copyProc.running = true
  }

  function deleteEntry(entryId) {
    delProc.command = ["cliphist", "delete", entryId]
    delProc.running = true
    loadEntries()
  }

  Process {
    id: decodeAllProc
    command: ["bash", "-c", "rm -f /tmp/cliphist-preview-*.png 2>/dev/null; cliphist list | while IFS= read -r line; do id=$(echo \"$line\" | cut -f1); printf '%s' \"$id\" | cliphist decode > /tmp/cliphist-preview-$id.png 2>/dev/null; done; cliphist list"]
    stdout: SplitParser {
      onRead: data => {
        var idx = data.indexOf("\t")
        if (idx < 0) return
        var id = data.substring(0, idx).trim()
        var text = data.substring(idx + 1).trim()
        var isImage = text.includes("binary data")
        var e = root.entries.slice()
        e.push({
          id: id,
          text: text,
          imagePath: isImage ? "file:///tmp/cliphist-preview-" + id + ".png" : ""
        })
        root.entries = e
      }
    }
  }

  Process {
    id: copyProc
    command: ["bash", "-c", "echo hi | cliphist decode | wl-copy"]
  }

  Process {
    id: delProc
    command: ["bash", "-c", "echo hi | cliphist delete"]
  }

  Process {
    id: wipeProc
    command: ["cliphist", "wipe"]
    onRunningChanged: { if (!running) root.loadEntries() }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: root.loadEntries()
  }

  Component.onCompleted: loadEntries()

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
        text: "󰅗"
        color: root.theme.accentOrange
        font.pixelSize: 18
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
        color: clearAllArea.containsMouse ? root.theme.bgHover : "transparent"

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
          onClicked: wipeProc.running = true
        }
      }
    }

    // Search bar
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: 4; Layout.rightMargin: 4
      Layout.bottomMargin: 8
      height: 32
      radius: 8
      color: root.theme.bgBase
      border.color: searchInput.activeFocus ? root.theme.accentOrange : root.theme.bgBorder
      border.width: 1

      TextInput {
        id: searchInput
        anchors.fill: parent
        anchors.margins: 8
        color: root.theme.textPrimary
        font.pixelSize: 12
        font.family: root.font
        clip: true
        onTextChanged: root.searchText = text

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "󰍩 Search..."
          color: root.theme.textMuted
          font.pixelSize: 12
          font.family: root.font
          visible: searchInput.text.length === 0 && !searchInput.activeFocus
        }
      }
    }

    // Separator
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: 4; Layout.rightMargin: 4
      Layout.bottomMargin: 8
      height: 1
      color: root.theme.bgBorder
    }

    // Clipboard list
    ListView {
      id: clipList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: 4
      boundsBehavior: Flickable.StopAtBounds

      model: root.filteredEntries

      delegate: Rectangle {
        id: clipItem
        required property var modelData
        required property int index

        width: clipList.width
        height: modelData.imagePath !== "" ? 64 : 36
        radius: 8
        color: clipArea.containsMouse ? root.theme.bgHover : "transparent"

        // Image preview
        Image {
          id: thumbImage
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          width: 44
          height: 44
          source: modelData.imagePath || ""
          fillMode: Image.PreserveAspectFit
          visible: modelData.imagePath !== "" && status === Image.Ready
          asynchronous: true
          cache: false
        }

        // Text entry
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: modelData.imagePath !== "" ? 60 : 8
          anchors.rightMargin: 8
          spacing: 8
          visible: modelData.imagePath === ""

          Text {
            text: "󰅗"
            color: root.theme.accentOrange
            font.pixelSize: 12
            font.family: root.font
          }

          Text {
            Layout.fillWidth: true
            text: modelData.text
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            elide: Text.ElideRight
          }
        }

        // Image entry text overlay
        ColumnLayout {
          anchors.left: thumbImage.visible ? thumbImage.right : parent.left
          anchors.leftMargin: thumbImage.visible ? 8 : 8
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          visible: modelData.imagePath !== ""

          Text {
            Layout.fillWidth: true
            text: "Screenshot"
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            Layout.fillWidth: true
            text: modelData.text
            color: root.theme.textMuted
            font.pixelSize: 10
            font.family: root.font
            elide: Text.ElideRight
          }
        }

        // Delete button
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          width: 22; height: 22; radius: 6
          color: delArea.containsMouse ? root.theme.bgHover : "transparent"
          visible: clipArea.containsMouse

          Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: root.theme.textMuted
            font.pixelSize: 11
            font.family: root.font
          }

          MouseArea {
            id: delArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.deleteEntry(modelData.id)
          }
        }

        MouseArea {
          id: clipArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.copyEntry(modelData.id, modelData.text)
        }
      }

      // Empty state
      Text {
        anchors.centerIn: parent
        text: "󰅗 Clipboard is empty"
        color: root.theme.textMuted
        font.pixelSize: 13
        font.family: root.font
        visible: clipList.count === 0
      }
    }
  }
}
