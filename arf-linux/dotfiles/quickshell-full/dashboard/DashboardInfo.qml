pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string cpuName: ""
  property real cpuUsage: 0
  property string cpuTemp: "N/A"
  property int coreCount: 0

  property string gpuName: ""
  property string gpuTemp: "N/A"

  property real memTotal: 0
  property real memUsed: 0
  property real memAvailable: 0
  property real memPercent: 0

  property var storageDevices: []

  property bool hasBattery: false
  property int batteryLevel: 0
  property bool batteryCharging: false
  property string batteryStatus: "Discharging"

  property string activeIface: ""
  property string ipAddress: ""
  property string downloadSpeed: "0 KB/s"
  property string uploadSpeed: "0 KB/s"

  // All network interfaces
  property var allInterfaces: []

  // Power profile
  property string powerProfile: "balanced"

  property string weatherTemp: ""
  property string weatherDesc: ""
  property string weatherIcon: "󰖨"
  property string weatherHumidity: ""
  property string weatherWind: ""
  property string weatherFeelsLike: ""
  property bool weatherLoaded: false

  property string uptime: ""
  property string userName: ""
  property string distroName: ""
  property string wmName: "Hyprland"

  // ===== CPU usage (pre-parsed by shell) =====
  Process {
    id: cpuProc
    command: ["sh", "-c", "awk '{u=$2+$3+$4+$5+$6+$7+$8; i=$5+$6} NR==1{n=u; j=i} END{d=u-n; k=i-j; if(d>0) printf \"%.0f\\n\",((d-k)/d)*100; else print 0}' <(head -1 /proc/stat; sleep 0.5; head -1 /proc/stat)"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.cpuUsage = parseInt(text.trim()) || 0 }
    }
  }

  Process {
    id: cpuNameProc
    command: ["sh", "-c", "grep 'model name' /proc/cpuinfo | head -1 | sed 's/.*: //'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.cpuName = text.trim() }
    }
  }

  Process {
    id: cpuTempProc
    command: ["sh", "-c", "sensors 2>/dev/null | grep -E 'Package id 0|Tctl' | head -1 | awk '{print $2}' | sed 's/+//'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.cpuTemp = text.trim() || "N/A" }
    }
  }

  Process {
    id: coreCountProc
    command: ["sh", "-c", "nproc"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.coreCount = parseInt(text.trim()) || 1 }
    }
  }

  // ===== GPU =====
  Process {
    id: gpuNameProc
    command: ["sh", "-c", "lspci 2>/dev/null | grep -i vga | head -1 | awk -F'[][]' '{print $4}' | xargs"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.gpuName = text.trim() || "Unknown" }
    }
  }

  Process {
    id: gpuTempProc
    command: ["sh", "-c", "for f in /sys/class/hwmon/hwmon*/name; do n=$(cat \"$f\" 2>/dev/null); case \"$n\" in amdgpu|nvidia|i915|nouveau) t=$(dirname \"$f\")/temp1_input; [ -f \"$t\" ] && awk '{printf \"%.0f°C\", $1/1000}' \"$t\" && exit 0;; esac; done; echo \"N/A\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.gpuTemp = text.trim() || "N/A" }
    }
  }

  // ===== Memory =====
  Process {
    id: memProc
    command: ["sh", "-c", "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%d %d %d\", t, a, t-a}' /proc/meminfo"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.trim().split(" ")
        if (parts.length >= 3) {
          root.memTotal = Math.round(parseInt(parts[0]) / 1048576 * 10) / 10
          root.memAvailable = Math.round(parseInt(parts[1]) / 1048576 * 10) / 10
          root.memUsed = Math.round(parseInt(parts[2]) / 1048576 * 10) / 10
          root.memPercent = root.memTotal > 0 ? Math.round((root.memUsed / root.memTotal) * 100) : 0
        }
      }
    }
  }

  // ===== Storage (pre-formatted by shell) =====
  Process {
    id: storageProc
    command: ["sh", "-c", "df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2 | awk '{printf \"%s|%s|%s|%s|%s|%s\\n\", $1,$2,$3,$4,$5,$6}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        var devices = []
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].split("|")
          if (p.length >= 6) {
            devices.push({
              device: p[0],
              size: p[1],
              used: p[2],
              avail: p[3],
              percent: parseInt(p[4]) || 0,
              mount: p[5]
            })
          }
        }
        root.storageDevices = devices
      }
    }
  }

  // ===== Battery =====
  Process {
    id: batteryProc
    command: ["sh", "-c", "bats=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null); if [ -z \"$bats\" ]; then echo none; else bat=$(echo \"$bats\" | head -1); enow=$(cat \"$bat/energy_now\" 2>/dev/null || cat \"$bat/charge_now\" 2>/dev/null || echo 0); efull=$(cat \"$bat/energy_full\" 2>/dev/null || cat \"$bat/charge_full\" 2>/dev/null || echo 1); status=$(cat \"$bat/status\" 2>/dev/null || echo Unknown); pct=$((enow * 100 / efull)); echo \"$pct:$status\"; fi"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = text.trim()
        if (raw === "none") { root.hasBattery = false; return }
        root.hasBattery = true
        var idx = raw.indexOf(":")
        root.batteryLevel = parseInt(raw.substring(0, idx)) || 0
        root.batteryStatus = raw.substring(idx + 1).trim()
        root.batteryCharging = root.batteryStatus === "Charging"
      }
    }
  }

  // ===== Network =====
  Process {
    id: netProc
    command: ["sh", "-c", "ip -brief addr show 2>/dev/null | grep -v DOWN | awk '{print $1\"|\"$3}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        var ifaces = []
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].split("|")
          if (p.length >= 2 && p[0]) {
            ifaces.push({ name: p[0], addr: p[1] || "N/A" })
          }
        }
        root.allInterfaces = ifaces
        if (ifaces.length > 0) {
          root.activeIface = ifaces[0].name
          root.ipAddress = ifaces[0].addr
        }
      }
    }
  }

  Process {
    id: netSpeedProc
    command: ["sh", "-c", "awk 'NR>2{print $1, $2, $10}' /proc/net/dev | head -5"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        var rx = 0, tx = 0
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].trim().split(" ")
          if (p.length >= 3) {
            rx += parseInt(p[1]) || 0
            tx += parseInt(p[2]) || 0
          }
        }
        if (root._prevRx > 0) {
          var drx = (rx - root._prevRx) / 1024
          var dtx = (tx - root._prevTx) / 1024
          root.downloadSpeed = drx > 1024 ? (drx / 1024).toFixed(1) + " MB/s" : drx.toFixed(1) + " KB/s"
          root.uploadSpeed = dtx > 1024 ? (dtx / 1024).toFixed(1) + " MB/s" : dtx.toFixed(1) + " KB/s"
        }
        root._prevRx = rx
        root._prevTx = tx
      }
    }
  }

  property real _prevRx: 0
  property real _prevTx: 0

  // ===== Power Profile =====
  Process {
    id: powerProfileProc
    command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.powerProfile = text.trim() || "balanced" }
    }
  }

  // ===== Weather =====
  Process {
    id: weatherProc
    command: ["sh", "-c", "curl -sf 'wttr.in/?format=%t|%C|%h|%w|%f|%t' 2>/dev/null || echo ERR"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = text.trim()
        if (raw === "ERR" || !raw) { root.weatherLoaded = false; return }
        var p = raw.split("|")
        if (p.length >= 5) {
          root.weatherTemp = p[0]
          root.weatherDesc = p[1]
          root.weatherHumidity = p[2]
          root.weatherWind = p[3]
          root.weatherFeelsLike = p[4]
          root.weatherIcon = root.weatherIconFromDesc(p[1])
          root.weatherLoaded = true
        }
      }
    }
  }

  function weatherIconFromDesc(desc) {
    var d = desc.toLowerCase()
    if (d.indexOf("sun") >= 0 || d.indexOf("clear") >= 0) return "󰖨"
    if (d.indexOf("cloud") >= 0 || d.indexOf("overcast") >= 0) return "󰖕"
    if (d.indexOf("rain") >= 0 || d.indexOf("drizzle") >= 0 || d.indexOf("shower") >= 0) return "󰖗"
    if (d.indexOf("thunder") >= 0 || d.indexOf("storm") >= 0) return "󰖓"
    if (d.indexOf("snow") >= 0 || d.indexOf("sleet") >= 0 || d.indexOf("blizzard") >= 0) return "󰖘"
    if (d.indexOf("fog") >= 0 || d.indexOf("mist") >= 0 || d.indexOf("haze") >= 0) return "󰖐"
    return "󰖨"
  }

  // ===== Uptime =====
  Process {
    id: uptimeProc
    command: ["sh", "-c", "awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); printf \"%dd %dh %dm\", d, h, m}' /proc/uptime"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: { root.uptime = text.trim() }
    }
  }

  // ===== Username =====
  Process {
    id: userProc
    command: ["sh", "-c", "whoami"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.userName = text.trim() }
    }
  }

  // ===== Distro =====
  Process {
    id: distroProc
    command: ["sh", "-c", "grep -oP '(?<=PRETTY_NAME=).*' /etc/os-release 2>/dev/null || cat /etc/issue 2>/dev/null | head -1"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.distroName = text.trim().replace(/"/g, "") }
    }
  }

  // Fast updates (2s)
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      cpuProc.running = true
      cpuTempProc.running = true
      gpuTempProc.running = true
      memProc.running = true
      netSpeedProc.running = true
    }
  }

  // Slow updates (10s)
  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: {
      storageProc.running = true
      batteryProc.running = true
      netProc.running = true
      powerProfileProc.running = true
      uptimeProc.running = true
    }
  }

  // Weather refresh (5 min)
  Timer {
    interval: 300000
    running: true
    repeat: true
    onTriggered: { weatherProc.running = true }
  }

  // Init
  Component.onCompleted: {
    cpuNameProc.running = true
    coreCountProc.running = true
    gpuNameProc.running = true
    storageProc.running = true
    batteryProc.running = true
    netProc.running = true
    weatherProc.running = true
    uptimeProc.running = true
    powerProfileProc.running = true
    userProc.running = true
    distroProc.running = true
  }
}
