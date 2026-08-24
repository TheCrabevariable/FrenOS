import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"
  property string _imgSrc: "0"

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  property var activePlayer: {
    const players = Mpris.players.values
    if (!players || players.length === 0) return null
    for (const p of players) {
      if (p.playbackState === MprisPlaybackState.Playing) return p
    }
    return players[0]
  }

  Process {
    id: filePickerProc
    command: ["zenity", "--file-selection", "--title=Choose Profile Picture", "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp"]
    stdout: SplitParser {
      onRead: data => {
        const path = data.trim()
        if (path.length > 0) {
          copyImgProc.command = ["bash", "-c", "cp '" + path + "' /home/catboy/.face"]
          copyImgProc.running = true
        }
      }
    }
  }

  Process {
    id: copyImgProc
    onRunningChanged: {
      if (!running) {
        root._imgSrc = Date.now().toString()
      }
    }
  }

  GridLayout {
    id: grid
    anchors.fill: parent
    columns: 2
    rowSpacing: 12
    columnSpacing: 12

    // ======== PROFILE + SYSTEM INFO (spans 2 cols) ========
    Rectangle {
      Layout.fillWidth: true
      Layout.columnSpan: 2
      Layout.preferredHeight: 180
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // Large round profile picture
        Item {
          width: 120
          height: 120

          Image {
            id: profileImage
            anchors.fill: parent
            source: "file:///home/catboy/.face?" + root._imgSrc
            fillMode: Image.PreserveAspectCrop
            visible: false
          }

          OpacityMask {
            anchors.fill: parent
            source: profileImage
            maskSource: Rectangle {
              width: 120
              height: 120
              radius: 60
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: 60
            color: "transparent"
            border.color: profilePicArea.containsMouse ? root.theme.accentCyan : root.theme.accentPrimary
            border.width: 2
          }

          Text {
            anchors.centerIn: parent
            text: "󰀉"
            color: root.theme.textMuted
            font.pixelSize: 32
            font.family: root.font
            visible: profileImage.status !== Image.Ready
          }

          Rectangle {
            anchors.fill: parent
            radius: 60
            color: root.theme.bgOverlay
            opacity: profilePicArea.containsMouse ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent
              text: "󰏒"
              color: root.theme.textPrimary
              font.pixelSize: 16
              font.family: root.font
            }
          }

          MouseArea {
            id: profilePicArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: filePickerProc.running = true
          }
        }

        // System info
        ColumnLayout {
          spacing: 6

          Text {
            text: DashboardInfo.userName || "user"
            color: root.theme.textPrimary
            font.pixelSize: 20
            font.family: root.font
            font.bold: true
          }

          Text {
            text: DashboardInfo.distroName || "Linux"
            color: root.theme.textSecondary
            font.pixelSize: 12
            font.family: root.font
          }

          RowLayout { spacing: 6
            Text { text: "󰌢"; color: root.theme.accentCyan; font.pixelSize: 12; font.family: root.font }
            Text { text: DashboardInfo.wmName; color: root.theme.textMuted; font.pixelSize: 12; font.family: root.font }
          }

          RowLayout { spacing: 6
            Text { text: "󰅐"; color: root.theme.accentGreen; font.pixelSize: 12; font.family: root.font }
            Text { text: DashboardInfo.uptime ? "Uptime: " + DashboardInfo.uptime : ""; color: root.theme.textMuted; font.pixelSize: 12; font.family: root.font }
          }

          RowLayout { spacing: 6
            Text { text: "󰊾"; color: root.theme.accentOrange; font.pixelSize: 12; font.family: root.font }
            Text { text: DashboardInfo.cpuName; color: root.theme.textMuted; font.pixelSize: 12; font.family: root.font; elide: Text.ElideRight; Layout.maximumWidth: 280 }
          }

          RowLayout { spacing: 6
            Text { text: "󰍹"; color: root.theme.accentCyan; font.pixelSize: 12; font.family: root.font }
            Text { text: DashboardInfo.gpuName; color: root.theme.textMuted; font.pixelSize: 12; font.family: root.font; elide: Text.ElideRight; Layout.maximumWidth: 280 }
          }
        }
      }
    }

    // ======== WEATHER ========
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Text {
          text: "Weather"
          color: root.theme.textSecondary
          font.pixelSize: 11
          font.family: root.font
          font.bold: true
        }

        RowLayout {
          spacing: 12

          Text {
            text: DashboardInfo.weatherIcon
            color: root.theme.accentCyan
            font.pixelSize: 36
            font.family: root.font
          }

          ColumnLayout {
            spacing: 2

            Text {
              text: DashboardInfo.weatherTemp || "N/A"
              color: root.theme.textPrimary
              font.pixelSize: 22
              font.family: root.font
              font.bold: true
            }

            Text {
              text: DashboardInfo.weatherDesc || "No data"
              color: root.theme.textMuted
              font.pixelSize: 11
              font.family: root.font
            }

            Text {
              text: DashboardInfo.weatherHumidity ? "💧 " + DashboardInfo.weatherHumidity : ""
              color: root.theme.textMuted
              font.pixelSize: 10
              font.family: root.font
            }
          }
        }

        Item { Layout.fillHeight: true }
      }
    }

    // ======== CALENDAR ========
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 120
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Text {
          text: "Calendar"
          color: root.theme.textSecondary
          font.pixelSize: 11
          font.family: root.font
          font.bold: true
        }

        Text {
          id: dateText
          color: root.theme.textPrimary
          font.pixelSize: 16
          font.family: root.font
          font.bold: true
        }

        Text {
          id: timeText
          color: root.theme.accentPrimary
          font.pixelSize: 28
          font.family: root.font
          font.bold: true
        }

        Timer {
          interval: 1000
          running: true
          repeat: true
          triggeredOnStart: true
          onTriggered: {
            var now = new Date()
            var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            dateText.text = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()
            timeText.text = Qt.formatTime(now, "HH:mm:ss")
          }
        }
      }
    }

    // ======== MINI MEDIA ========
    Rectangle {
      Layout.fillWidth: true
      Layout.columnSpan: 2
      Layout.preferredHeight: 72
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: root.activePlayer !== null

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Album art placeholder
        Rectangle {
          width: 48
          height: 48
          radius: 8
          color: root.theme.bgOverlay
          clip: true

          Image {
            anchors.fill: parent
            source: (root.activePlayer && root.activePlayer.coverArt) ? root.activePlayer.coverArt : ""
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            text: "󰎈"
            color: root.theme.textMuted
            font.pixelSize: 18
            font.family: root.font
            visible: root.activePlayer && !root.activePlayer.coverArt
          }
        }

        // Track info
        ColumnLayout {
          spacing: 2
          Layout.fillWidth: true

          Text {
            text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown Title") : ""
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: root.activePlayer ? (root.activePlayer.trackArtist || "Unknown Artist") : ""
            color: root.theme.textMuted
            font.pixelSize: 10
            font.family: root.font
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        // Controls
        Row { spacing: 8
          Rectangle {
            width: 28; height: 28; radius: 14
            color: prevArea.containsMouse ? root.theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: "󰒮"; color: root.theme.textSecondary; font.pixelSize: 12; font.family: root.font }
            MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activePlayer.previous() }
          }

          Rectangle {
            width: 32; height: 32; radius: 16
            color: playArea.containsMouse ? root.theme.bgHover : root.theme.accentPrimary
            Text { anchors.centerIn: parent; text: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"; color: root.theme.bgBase; font.pixelSize: 14; font.family: root.font }
            MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activePlayer.togglePlaying() }
          }

          Rectangle {
            width: 28; height: 28; radius: 14
            color: nextArea.containsMouse ? root.theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: "󰒭"; color: root.theme.textSecondary; font.pixelSize: 12; font.family: root.font }
            MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activePlayer.next() }
          }
        }
      }
    }
  }
}
