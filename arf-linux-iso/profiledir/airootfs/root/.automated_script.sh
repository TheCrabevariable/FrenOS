#!/usr/bin/env bash

# arf-linux automated installer launcher
# Runs once when booting the live ISO

FLAG="/tmp/.arf-installer-ran"
[ -f "$FLAG" ] && exit 0
touch "$FLAG"

sleep 2

if [ -f /usr/local/bin/arf-installer ]; then
  clear
  echo "============================================"
  echo "  arf-linux — press Enter to install"
  echo "  or wait 10 seconds for auto-start"
  echo "============================================"
  read -t 10 -r || true

  /usr/local/bin/arf-installer
fi

# Safety net: if installer didn't reboot (crash or reboot failed), reboot now
sync
sleep 2
reboot -f
