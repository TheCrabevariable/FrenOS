pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string cpuUsage: "0%"
  property string memoryUsage: "0%"
  property string networkInfo: "Disconnected"
  property string networkType: "disconnected"
  property int batteryLevelRaw: 0
  property string batteryLevel: "0%"
  property string batteryIcon: "󰂎"
  property bool batteryCharging: false
  property bool hasBattery: false
  property string temperature: "0°C"
  property string powerProfile: "balanced"

  // CPU Usage
  Process {
    id: cpuProc
    command: ["sh", "-c", "top -bn1 2>/dev/null | head -5 | grep '%Cpu' | awk '{u=$2+$4; printf \"%.0f%%\", u}' || echo \"0%%\""]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.cpuUsage = text.trim()
      }
    }
  }

  // Memory Usage
  Process {
    id: memProc
    command: ["sh", "-c", "free | grep Mem | awk '{printf \"%.1f%%\", ($3/$2) * 100.0}'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.memoryUsage = text.trim()
      }
    }
  }

  // Network Info (ethernet takes priority over wifi)
  Process {
    id: netProc
    command: ["sh", "-c", "eth=$(nmcli -t -f type,state dev 2>/dev/null | grep '^ethernet:connected'); if [ -n \"$eth\" ]; then echo 'ethernet:Network'; else wifi=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2); if [ -n \"$wifi\" ]; then echo \"wifi:$wifi\"; else echo 'disconnected:'; fi; fi"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const result = text.trim()
        const colonIdx = result.indexOf(':')
        const type = result.substring(0, colonIdx)
        const info = result.substring(colonIdx + 1)
        root.networkType = type
        root.networkInfo = info || "Disconnected"
      }
    }
  }

  // Battery
  Process {
    id: batteryProc
    command: ["sh", "-c", "bats=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null); if [ -z \"$bats\" ]; then echo 'none'; else for bat in $bats; do enow=$(cat \"$bat/energy_now\" 2>/dev/null || cat \"$bat/charge_now\" 2>/dev/null || echo 0); efull=$(cat \"$bat/energy_full\" 2>/dev/null || cat \"$bat/charge_full\" 2>/dev/null || echo 0); total=$((total + enow)); max=$((max + efull)); done; charging=$(cat \"$(echo \"$bats\" | head -1)/status\" 2>/dev/null); [ \"$max\" -gt 0 ] && echo \"$((total * 100 / max)):$charging\" || echo 'none'; fi"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const raw = text.trim()
        if (raw === "none") {
          root.hasBattery = false
          return
        }
        root.hasBattery = true
        const parts = raw.split(":")
        const level = parseInt(parts[0]) || 0
        const status = (parts[1] || "Discharging").trim()

        root.batteryLevelRaw = level
        root.batteryLevel = level + "%"
        root.batteryCharging = status === "Charging"

        if (root.batteryCharging) root.batteryIcon = ""
        else if (level >= 90) root.batteryIcon = "󰁹"
        else if (level >= 80) root.batteryIcon = "󰂂"
        else if (level >= 70) root.batteryIcon = "󰂁"
        else if (level >= 60) root.batteryIcon = "󰂀"
        else if (level >= 50) root.batteryIcon = "󰁿"
        else if (level >= 40) root.batteryIcon = "󰁾"
        else if (level >= 30) root.batteryIcon = "󰁽"
        else if (level >= 20) root.batteryIcon = "󰁼"
        else if (level >= 10) root.batteryIcon = "󰁻"
        else root.batteryIcon = "󰁺"
      }
    }
  }

  // Power Profile
  Process {
    id: powerProfileProc
    command: ["sh", "-c", "busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null | cut -d'\"' -f2 || echo 'balanced'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.powerProfile = text.trim()
      }
    }
  }

  // Temperature
  Process {
    id: tempProc
    command: ["sh", "-c", "val=$(sensors 2>/dev/null | grep -oP '\\+[0-9.]+[°]?C' | head -1 | tr -d '+'); [ -n \"$val\" ] && echo \"$val\" || { val=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1); [ -n \"$val\" ] && [ \"$val\" -gt 0 ] 2>/dev/null && echo \"$((val/1000))°C\" || echo \"N/A\"; }"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.temperature = text.trim() || "N/A"
      }
    }
  }

  // Update timer (5s for CPU/mem/temp/power, 10s for network/bt/battery)
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
      cpuProc.running = true
      memProc.running = true
      tempProc.running = true
      powerProfileProc.running = true
    }
  }
  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: {
      netProc.running = true
      batteryProc.running = true
    }
  }
}
