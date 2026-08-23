import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Hack Nerd Font"

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

  // Brightness state
  property real brightnessValue: 50
  property bool brightnessAvailable: false
  property bool _brightnessReady: false
  property var ddcBuses: []

  function ddcLoop(inner) {
    return "for b in " + root.ddcBuses.join(" ") + "; do " + inner + "; done"
  }

  function refreshDdcBrightness() {
    ddcutilReadProc.command = ["sh", "-c", root.ddcLoop("ddcutil -b $b getvcp 10 2>/dev/null | awk '/current value/{print $9}'") + " | awk '{s+=$1;n++}END{if(n)printf \"%d\",s/n}'"]
    ddcutilReadProc.running = true
  }

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  // Detect ddcutil + enumerate all DDC-capable displays
  Process {
    id: ddcutilDetect
    command: ["sh", "-c", "command -v ddcutil >/dev/null 2>&1 && ddcutil detect 2>/dev/null | awk -F'i2c-' '/I2C bus/{print $2}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const buses = text.trim().split("\n").map(Number).filter(n => !isNaN(n) && n > 0)
        root.ddcBuses = buses
        root.brightnessAvailable = buses.length > 0
        if (root.brightnessAvailable) root.refreshDdcBrightness()
        else bcReadProc.running = true
      }
    }
  }

  Process {
    id: ddcutilReadProc
    command: []
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const val = parseFloat(text.trim());
        if (!isNaN(val)) root.brightnessValue = val;
      }
    }
  }

  Process {
    id: bcReadProc
    command: ["sh", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%[,max]'"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const val = parseFloat(text.trim());
        if (!isNaN(val)) root.brightnessValue = val;
      }
    }
  }

  Process {
    id: brightnessSetProc
    command: []
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.brightnessAvailable) root.refreshDdcBrightness();
        else bcReadProc.running = true;
      }
    }
  }

  GridLayout {
    id: grid
    anchors.fill: parent
    columns: 2
    rowSpacing: 12
    columnSpacing: 12

    // ======== NOW PLAYING CARD (spans 2 cols) ========
    Rectangle {
      Layout.fillWidth: true
      Layout.columnSpan: 2
      Layout.preferredHeight: root.activePlayer ? 160 : 80
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 8
        visible: !root.activePlayer

        Text {
          text: "󰎈"
          color: root.theme.textMuted
          font.pixelSize: 32
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }

        Text {
          text: "No media playing"
          color: root.theme.textMuted
          font.pixelSize: 13
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        visible: root.activePlayer !== null

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4

          Text {
            text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown Title") : ""
            color: root.theme.textPrimary
            font.pixelSize: 16
            font.family: root.font
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: root.activePlayer ? (root.activePlayer.trackArtist || "Unknown Artist") : ""
            color: root.theme.textSecondary
            font.pixelSize: 13
            font.family: root.font
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: root.activePlayer ? (root.activePlayer.trackAlbum || "") : ""
            color: root.theme.textMuted
            font.pixelSize: 11
            font.family: root.font
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: text !== ""
          }

          Item { Layout.fillHeight: true }

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 16

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              height: 4
              radius: 2
              color: root.theme.bgBase

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                height: 4
                radius: 2
                width: {
                  if (!root.activePlayer || !root.activePlayer.length) return 0
                  return parent.width * (root.activePlayer.position / root.activePlayer.length)
                }
                color: root.theme.accentOrange
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (!root.activePlayer || !root.activePlayer.length) return
                const ratio = Math.max(0, Math.min(1, mouse.x / width))
                root.activePlayer.position = ratio * root.activePlayer.length
              }
            }
          }
        }

        ColumnLayout {
          spacing: 12
          Item { Layout.fillHeight: true }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Rectangle {
              width: 36; height: 36; radius: 18
              color: prevArea.containsMouse ? root.theme.bgHover : "transparent"

              Text {
                anchors.centerIn: parent
                text: "󰒫"
                color: root.theme.textSecondary
                font.pixelSize: 16
                font.family: root.font
              }

              MouseArea {
                id: prevArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.activePlayer) root.activePlayer.previous() }
              }
            }

            Rectangle {
              width: 44; height: 44; radius: 22
              color: playArea.containsMouse ? root.theme.bgHover : root.theme.accentPrimary

              Text {
                anchors.centerIn: parent
                text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
                color: root.theme.bgBase
                font.pixelSize: 18
                font.family: root.font
              }

              MouseArea {
                id: playArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.activePlayer) root.activePlayer.togglePlaying() }
              }
            }

            Rectangle {
              width: 36; height: 36; radius: 18
              color: nextArea.containsMouse ? root.theme.bgHover : "transparent"

              Text {
                anchors.centerIn: parent
                text: "󰒭"
                color: root.theme.textSecondary
                font.pixelSize: 16
                font.family: root.font
              }

              MouseArea {
                id: nextArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.activePlayer) root.activePlayer.next() }
              }
            }
          }

          Item { Layout.fillHeight: true }
        }
      }
    }

    // ======== PLAYER LIST CARD ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 70
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
          spacing: 8

          Text {
            text: "󰎈"
            color: root.theme.accentOrange
            font.pixelSize: 13
            font.family: root.font
          }

          Text {
            text: "Players"
            color: root.theme.accentOrange
            font.pixelSize: 11
            font.family: root.font
            font.bold: true
          }
        }

        Repeater {
          model: Mpris.players.values

          Rectangle {
            required property var modelData
            required property int index
            property bool isActive: root.activePlayer === modelData

            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 8
            color: playerArea.containsMouse ? root.theme.bgHover :
                   isActive ? root.theme.bgSelected : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8; anchors.rightMargin: 8
              spacing: 6

              Text {
                text: modelData.isPlaying ? "󰐊" : "󰏤"
                color: isActive ? root.theme.accentOrange : root.theme.textMuted
                font.pixelSize: 11
                font.family: root.font
              }

              Text {
                text: modelData.identity || modelData.dbusName || "Player"
                color: isActive ? root.theme.textPrimary : root.theme.textSecondary
                font.pixelSize: 10
                font.family: root.font
                font.bold: isActive
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            MouseArea {
              id: playerArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: modelData.togglePlaying()
            }
          }
        }

        Text {
          text: "No players"
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
          visible: Mpris.players.values.length === 0
        }
      }
    }

    // ======== TRACK DETAILS CARD ========
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 70
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: root.activePlayer !== null

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
          spacing: 8

          Text {
            text: "󰋋"
            color: root.theme.accentCyan
            font.pixelSize: 13
            font.family: root.font
          }

          Text {
            text: "Details"
            color: root.theme.accentCyan
            font.pixelSize: 11
            font.family: root.font
            font.bold: true
          }
        }

        RowLayout { Layout.fillWidth: true; spacing: 6
          Text { text: "Pos"; color: root.theme.textMuted; font.pixelSize: 9; font.family: root.font; Layout.preferredWidth: 30 }
          Text { text: root.activePlayer ? formatTime(root.activePlayer.position) : "0:00"; color: root.theme.textPrimary; font.pixelSize: 10; font.family: root.font }
        }

        RowLayout { Layout.fillWidth: true; spacing: 6
          Text { text: "Len"; color: root.theme.textMuted; font.pixelSize: 9; font.family: root.font; Layout.preferredWidth: 30 }
          Text { text: root.activePlayer ? formatTime(root.activePlayer.length) : "0:00"; color: root.theme.textPrimary; font.pixelSize: 10; font.family: root.font }
        }

        RowLayout { Layout.fillWidth: true; spacing: 6
          Text { text: "Rate"; color: root.theme.textMuted; font.pixelSize: 9; font.family: root.font; Layout.preferredWidth: 30 }
          Text { text: root.activePlayer && root.activePlayer.playbackRate != null ? root.activePlayer.playbackRate.toFixed(1) + "x" : "1.0x"; color: root.theme.textPrimary; font.pixelSize: 10; font.family: root.font }
        }

        Item { Layout.fillHeight: true }
      }
    }

    // Empty details when no player
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 70
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1
      visible: root.activePlayer === null

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 6

        Text {
          text: "󰋋"
          color: root.theme.textMuted
          font.pixelSize: 20
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }

        Text {
          text: "No track info"
          color: root.theme.textMuted
          font.pixelSize: 10
          font.family: root.font
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }

    // ======== AUDIO & DISPLAY CARD (spans 2 cols) ========
    Rectangle {
      Layout.fillWidth: true
      Layout.columnSpan: 2
      Layout.preferredHeight: 160
      radius: 12
      color: root.theme.bgSurface
      border.color: root.theme.bgBorder
      border.width: 1

      GridLayout {
        anchors.fill: parent
        anchors.margins: 16
        columns: 2
        columnSpacing: 24
        rowSpacing: 12

        // === Volume column ===
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 8

          RowLayout {
            spacing: 6
            Text {
              text: "󰕾"
              color: root.theme.accentPrimary
              font.pixelSize: 13
              font.family: root.font
            }
            Text {
              text: "Volume"
              color: root.theme.accentPrimary
              font.pixelSize: 11
              font.family: root.font
              font.bold: true
            }
          }

          // Volume slider row
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: {
                const sink = Pipewire.defaultAudioSink;
                if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
                if (sink.audio.volume < 0.33) return "󰕿";
                if (sink.audio.volume < 0.66) return "󰖀";
                return "󰕾";
              }
              color: {
                const sink = Pipewire.defaultAudioSink;
                if (!sink || !sink.audio || sink.audio.muted) return root.theme.textMuted;
                return root.theme.accentPrimary;
              }
              font.pixelSize: 14
              font.family: root.font
            }

            // Slider track
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 20

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                radius: 3
                color: root.theme.bgBase

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  height: 6
                  radius: 3
                  width: {
                    const sink = Pipewire.defaultAudioSink;
                    if (!sink || !sink.audio) return 0;
                    return parent.width * Math.min(1, sink.audio.muted ? 0 : sink.audio.volume);
                  }
                  color: root.theme.accentPrimary
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  const sink = Pipewire.defaultAudioSink;
                  if (!sink || !sink.audio) return;
                  const ratio = Math.max(0, Math.min(1.5, mouse.x / width));
                  sink.audio.volume = ratio;
                }
                onWheel: (wheel) => {
                  const sink = Pipewire.defaultAudioSink;
                  if (!sink || !sink.audio) return;
                  const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                  sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta));
                }
              }
            }

            Text {
              text: {
                const sink = Pipewire.defaultAudioSink;
                if (!sink || !sink.audio) return "--";
                if (sink.audio.muted) return "Mute";
                return Math.round(sink.audio.volume * 100) + "%";
              }
              color: root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
              Layout.preferredWidth: 36
              horizontalAlignment: Text.AlignRight
            }
          }

          // Mute button
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 8
            color: muteArea.containsMouse ? root.theme.bgHover : root.theme.bgBase

            Text {
              anchors.centerIn: parent
              text: {
                const sink = Pipewire.defaultAudioSink;
                if (!sink || !sink.audio) return "󰖁 Mute";
                return sink.audio.muted ? "󰖁 Unmute" : "󰖁 Mute";
              }
              color: root.theme.textSecondary
              font.pixelSize: 10
              font.family: root.font
            }

            MouseArea {
              id: muteArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                const sink = Pipewire.defaultAudioSink;
                if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
              }
            }
          }

          Item { Layout.fillHeight: true }
        }

        // === Brightness column ===
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 8

          RowLayout {
            spacing: 6
            Text {
              text: "󰃠"
              color: root.theme.accentOrange
              font.pixelSize: 13
              font.family: root.font
            }
            Text {
              text: "Brightness" + (root.brightnessAvailable ? "" : " (software)")
              color: root.theme.accentOrange
              font.pixelSize: 11
              font.family: root.font
              font.bold: true
            }
          }

          // Brightness slider row
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "󰃠"
              color: root.theme.accentOrange
              font.pixelSize: 14
              font.family: root.font
            }

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: 20

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                radius: 3
                color: root.theme.bgBase

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  height: 6
                  radius: 3
                  width: parent.width * Math.min(1, root.brightnessValue / 100)
                  color: root.theme.accentOrange
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  const val = Math.max(0, Math.min(100, (mouse.x / width) * 100));
                  if (root.brightnessAvailable) {
                    brightnessSetProc.command = ["sh", "-c", root.ddcLoop("ddcutil -b $b setvcp 10 " + Math.round(val) + " 2>/dev/null")];
                  } else {
                    brightnessSetProc.command = ["sh", "-c", "brightnessctl set " + Math.round(val) + "% 2>/dev/null"];
                  }
                  brightnessSetProc.running = true;
                  root.brightnessValue = val;
                }
              }
            }

            Text {
              text: Math.round(root.brightnessValue) + "%"
              color: root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
              Layout.preferredWidth: 36
              horizontalAlignment: Text.AlignRight
            }
          }

          // Brightness buttons
          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 28
              radius: 8
              color: bcDownArea.containsMouse ? root.theme.bgHover : root.theme.bgBase

              Text {
                anchors.centerIn: parent
                text: "󰃞 -"
                color: root.theme.textSecondary
                font.pixelSize: 10
                font.family: root.font
              }

              MouseArea {
                id: bcDownArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.brightnessAvailable) {
                    brightnessSetProc.command = ["sh", "-c", root.ddcLoop("ddcutil -b $b setvcp 10 - 5 2>/dev/null")];
                  } else {
                    brightnessSetProc.command = ["sh", "-c", "brightnessctl set 5%- 2>/dev/null"];
                  }
                  brightnessSetProc.running = true;
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 28
              radius: 8
              color: bcUpArea.containsMouse ? root.theme.bgHover : root.theme.bgBase

              Text {
                anchors.centerIn: parent
                text: "󰃟 +"
                color: root.theme.textSecondary
                font.pixelSize: 10
                font.family: root.font
              }

              MouseArea {
                id: bcUpArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.brightnessAvailable) {
                    brightnessSetProc.command = ["sh", "-c", root.ddcLoop("ddcutil -b $b setvcp 10 + 5 2>/dev/null")];
                  } else {
                    brightnessSetProc.command = ["sh", "-c", "brightnessctl set 5%+ 2>/dev/null"];
                  }
                  brightnessSetProc.running = true;
                }
              }
            }
          }

          Item { Layout.fillHeight: true }
        }
      }
    }
  }

  function formatTime(seconds) {
    if (!seconds || seconds < 0) return "0:00"
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }
}
