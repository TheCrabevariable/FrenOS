#!/usr/bin/env bash
set -euo pipefail

# ── FrenOS ISO builder ─────────────────────────────────────
# Builds a custom Arch Linux live ISO with automated installer.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="$SCRIPT_DIR/profiledir"
WORK_DIR="/tmp/arf-linux-iso-work"
OUT_DIR="$SCRIPT_DIR/out"

# Ensure archiso is installed
if ! command -v mkarchiso &>/dev/null; then
  echo ":: Installing archiso..."
  sudo pacman -S --noconfirm archiso
fi

# Bundle arf-linux into the airootfs
echo ":: Bundling arf-linux into ISO..."
ARF_DEST="$PROFILE/airootfs/opt/arf-linux"
sudo rm -rf "$ARF_DEST" 2>/dev/null || true
mkdir -p "$ARF_DEST"
cp -r --no-preserve=mode,ownership,xattr "$SCRIPT_DIR/../arf-linux"/* "$ARF_DEST/" 2>/dev/null || {
  echo "!! arf-linux source not found at ../arf-linux"
  echo "   Place the arf-linux directory next to arf-linux-iso/"
  exit 1
}
# Bundle SDDM theme so install doesn't need GitHub
echo ":: Bundling SDDM theme..."
SDDM_DEST="$PROFILE/airootfs/usr/share/sddm/themes"
if git clone --depth 1 https://github.com/keyitdev/sddm-flower-theme.git "$SDDM_DEST/sddm-flower-theme" 2>/dev/null; then
  rm -rf "$SDDM_DEST/sddm-flower-theme/.git"
  echo ":: SDDM theme bundled"
else
  echo "!! Warning: could not clone SDDM theme (no internet?)"
  echo "   Install will fall back to built-in theme"
  rm -rf "$SDDM_DEST/sddm-flower-theme" 2>/dev/null || true
fi

# Bundle quickshell config from dotfiles
echo ":: Bundling Quickshell config..."
QS_SRC="$SCRIPT_DIR/../arf-linux/dotfiles/quickshell-full"
if [ -d "$QS_SRC" ]; then
  sudo rm -rf "$ARF_DEST/dotfiles/quickshell" 2>/dev/null || true
  cp -r "$QS_SRC" "$ARF_DEST/dotfiles/quickshell"
  # Disable wallpaper manager (not bundled)
  sed -i 's/import "wallpaper"/\/\/import "wallpaper"/' "$ARF_DEST/dotfiles/quickshell/shell.qml" 2>/dev/null || true
  sed -i 's/WallpaperManager {/\/\/WallpaperManager {/' "$ARF_DEST/dotfiles/quickshell/shell.qml" 2>/dev/null || true
  echo ":: Quickshell config bundled"
else
  echo "!! Warning: quickshell-full not found at $QS_SRC"
  echo "   Quickshell bar will fall back to patches only"
fi

# Clean previous build
sudo rm -rf "$WORK_DIR" "$OUT_DIR" 2>/dev/null || true
mkdir -p "$OUT_DIR"

# Build the ISO
echo ":: Building ISO (this may take a while)..."
sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE"

# Fix ownership
sudo chown -R "$(whoami):$(whoami)" "$OUT_DIR" 2>/dev/null || true

echo ""
echo "✅ ISO built: $OUT_DIR/FrenOS-*.iso"
echo "   Write to USB: sudo dd if=$OUT_DIR/FrenOS-*.iso of=/dev/sdX bs=4M status=progress && sync"
