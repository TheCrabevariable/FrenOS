#!/usr/bin/env bash
set -euo pipefail

# ── FrenOS ──────────────────────────────────────────────────
# Opinionated Arch Linux installer — like Omarchy, but mine
# Usage: bash install.sh
# ────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { printf "${CYAN}::${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}==>${NC} %s\n" "$*"; }
err()   { printf "${RED}==>${NC} %s\n" "$*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────
# If running inside the ISO-automated flow, these come from /etc/arf-linux.env.
# If running manually, they default to the current user.
USERNAME="${USERNAME:-$USER}"

# ── Stage 1: Live ISO ──────────────────────────────────────────
stage1() {
  clear
  echo "============================================"
  echo "  FrenOS Stage 1 — Base install"
  echo "============================================"
  echo ""
  echo "If booted from the FrenOS ISO, the"
  echo "automated installer will run. This manual"
  echo "mode is for advanced users only."
  echo ""
  echo "You must manually:"
  echo "  1. Partition and format your disk"
  echo "  2. Mount to /mnt (with /mnt/boot)"
  echo "  3. Run 'bash install.sh --stage2'"
  echo ""
  echo "See the Arch Wiki for partitioning help."
  echo "============================================"
  echo ""
  ok "Stage 1 manual — base install must be done manually"
}

# ── Stage 2: First boot (pkg install) ──────────────────────────
stage2() {
  info "Stage 2: Installing packages"

  # Tweak pacman.conf
  local PARALLEL="${PARALLEL_DL:-1}"
  sed -i "s/^#Color/Color/; s|^#ParallelDownloads = 5|ParallelDownloads = ${PARALLEL}|" /etc/pacman.conf
  grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
  grep -q '^VerbosePkgLists' /etc/pacman.conf || sed -i '/^Color/a VerbosePkgLists' /etc/pacman.conf

  # Enable multilib
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo '[multilib]' >> /etc/pacman.conf
    echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
  fi

  # Refresh mirrorlist with fastest mirrors
  if command -v reflector &>/dev/null; then
    info "Optimizing mirrorlist..."
    reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist 2>&1 || true
  fi

  pacman -Syu --noconfirm

  # ── Brand as FrenOS ────────────────────────────────────────
  info "Branding system as FrenOS..."
  sed -i 's/^NAME="Arch Linux"/NAME="FrenOS"/' /etc/os-release 2>/dev/null || true
  sed -i 's/^PRETTY_NAME="Arch Linux"/PRETTY_NAME="FrenOS (Arch Linux)"/' /etc/os-release 2>/dev/null || true

  # ── Graphics drivers (before Steam so no prompt) ──────────────
  info "Detecting GPU and installing drivers..."
  GPU_VENDOR=$(lspci -k | grep -E "(VGA|3D)" | grep -iEo "(nvidia|amd|intel)" | head -1 | tr '[:upper:]' '[:lower:]')
  DRIVERS=()

  case "$GPU_VENDOR" in
    nvidia)
      DRIVERS+=(nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings)
      ok "NVIDIA GPU detected — installing proprietary drivers"
      ;;
    amd)
      DRIVERS+=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu)
      ok "AMD GPU detected — installing Mesa + Vulkan"
      ;;
    intel)
      DRIVERS+=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel xf86-video-intel)
      ok "Intel GPU detected — installing Mesa + Vulkan"
      ;;
    *)
      DRIVERS+=(mesa lib32-mesa)
      ok "No discrete GPU detected — installing Mesa (fallback)"
      ;;
  esac

  pacman -S --noconfirm --needed "${DRIVERS[@]}"
  ok "Graphics drivers installed"

  # Official packages
  OFFICIAL=(
    hyprland hypridle hyprlock hyprpaper hyprshot hyprpolkitagent hyprpicker
    zed steam kitty fastfetch chafa imagemagick rmpc mpd mpd-mpris networkmanager zsh python
    quickshell ttf-hack-nerd ttf-nerd-fonts-symbols noto-fonts-emoji sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg opencode gnome-disk-utility imv mpv pavucontrol yt-dlp
    bluetui bluez bluez-utils playerctl brightnessctl lm_sensors breeze-cursors cliphist
    pipewire pipewire-pulse wireplumber power-profiles-daemon inotify-tools rsync
    xdg-desktop-portal xdg-desktop-portal-hyprland udiskie wlr-randr bazaar grub-btrfs flatpak flatpak-xdg-utils gvfs udisks2 btop xdg-user-dirs libreoffice-fresh firefox
  )

  pacman -S --noconfirm --needed "${OFFICIAL[@]}" os-prober

  # Install yay + AUR packages
  # (needs NOPASSWD sudo since this runs in chroot with no TTY)
  echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-arf

  if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)"
    sudo -u "$USERNAME" bash -c "
      cd /tmp
      git clone --depth 1 https://aur.archlinux.org/yay-bin.git
      cd yay-bin && makepkg -si --noconfirm
    "
  fi

  AUR=(
    animu-bin
    fren-bin
    heroic-games-launcher-bin
    vesktop
    wlogout
  )

  for aur_pkg in "${AUR[@]}"; do
    info "Installing AUR package: $aur_pkg"
    sudo -u "$USERNAME" yay -S --noconfirm --needed "$aur_pkg" || {
      info "Clean-building $aur_pkg after failure..."
      sudo -u "$USERNAME" yay -S --noconfirm --needed --cleanbuild "$aur_pkg" || {
        info "AUR package failed (non-fatal): $aur_pkg"
      }
    }
  done

  rm -f /etc/sudoers.d/99-arf

  # Regenerate initramfs now that GPU drivers are installed
  mkinitcpio -P

  # Enable services
  systemctl enable sddm
  systemctl enable bluetooth
  systemctl enable power-profiles-daemon
  systemctl enable NetworkManager
  sudo -u "$USERNAME" bash -c "
    mkdir -p ~/.config/systemd/user/default.target.wants
    ln -sf /usr/lib/systemd/user/pipewire.service ~/.config/systemd/user/default.target.wants/
    ln -sf /usr/lib/systemd/user/pipewire-pulse.service ~/.config/systemd/user/default.target.wants/
    ln -sf /usr/lib/systemd/user/wireplumber.service ~/.config/systemd/user/default.target.wants/
    ln -sf /usr/lib/systemd/user/xdg-desktop-portal-hyprland.service ~/.config/systemd/user/default.target.wants/
    ln -sf /usr/lib/systemd/user/mpd-mpris.service ~/.config/systemd/user/default.target.wants/
  "

  # Enable mpd
  systemctl enable mpd 2>/dev/null || true

  # ── Dotfiles ──────────────────────────────────────────────────
  info "Applying dotfiles..."

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DOTFILES="$SCRIPT_DIR/dotfiles"
  USER_HOME=$(eval echo "~$USERNAME")

  for dir in "$DOTFILES"/*/; do
    app="$(basename "$dir")"
    case "$app" in
      quickshell-patch|dunst|firefox|frenos) continue ;;
      quickshell-full) app="quickshell" ;;
    esac
    target="$USER_HOME/.config/$app"
    mkdir -p "$target"
    cp -r "$dir"/* "$target"/ 2>/dev/null || true
    chown -R "$USERNAME:" "$target" 2>/dev/null || true
    ok "Applied config for $app"
  done

  if [ -f "$DOTFILES/zsh/.zshrc" ]; then
    cp "$DOTFILES/zsh/.zshrc" "$USER_HOME/.zshrc"
    chown "$USERNAME:" "$USER_HOME/.zshrc" 2>/dev/null || true
    chsh -s "$(which zsh)" "$USERNAME"
    ok "Applied config for zsh and set as default shell"
  fi

  mkdir -p "$USER_HOME/.config/mpd/playlists"
  touch "$USER_HOME/.config/mpd/database"

  # Install update-fos script
  if [ -f "$DOTFILES/frenos/update-fos" ]; then
    cp "$DOTFILES/frenos/update-fos" /usr/local/bin/update-fos
    chmod +x /usr/local/bin/update-fos
    ok "Installed update-fos (run 'update-fos' to update FrenOS)"
  fi
  chown -R "$USERNAME:" "$USER_HOME/.config/mpd" 2>/dev/null || true

  xdg-user-dirs-update 2>/dev/null || true

  # Note: quickshell config is bundled pre-patched via build.sh

  # ── Wallpapers ──────────────────────────────────────────────────
  info "Setting up wallpapers..."
  WALLPAPER_DIR="$USER_HOME/.config/hypr/wallpaper"
  mkdir -p "$WALLPAPER_DIR" /usr/share/sddm/themes/arf 2>/dev/null || true
  if git clone --depth 1 https://github.com/TheCrabevariable/Wallpaper.git "$WALLPAPER_DIR-tmp" 2>/dev/null; then
    cp "$WALLPAPER_DIR-tmp/fren/sddm.png" /usr/share/sddm/themes/arf/background.jpg 2>/dev/null || true
    cp "$WALLPAPER_DIR-tmp/fren/hyprlock.png" "$WALLPAPER_DIR/hyprlock.png" 2>/dev/null || true
    cp "$WALLPAPER_DIR-tmp/fren/fren1.png" "$WALLPAPER_DIR/fren1.png" 2>/dev/null || true
    rm -rf "$WALLPAPER_DIR-tmp"
    ok "Wallpapers downloaded from GitHub"
  else
    # Fall back to bundled dotfiles
    rm -rf "$WALLPAPER_DIR-tmp" 2>/dev/null || true
    cp "$DOTFILES/wallpapers/fren1.png" "$WALLPAPER_DIR/fren1.png" 2>/dev/null || true
    cp "$DOTFILES/hypr/hyprlock.png" "$WALLPAPER_DIR/hyprlock.png" 2>/dev/null || true
    cp "$DOTFILES/sddm/sddm.png" /usr/share/sddm/themes/arf/background.jpg 2>/dev/null || true
    info "Wallpapers set up from bundled files"
  fi

  # ── SDDM theme ──────────────────────────────────────────────────
  local SDDM_THEME="elarun"
  if [ -d /usr/share/sddm/themes/sddm-flower-theme ]; then
    SDDM_THEME="sddm-flower-theme"
  else
    sudo git clone --depth 1 https://github.com/keyitdev/sddm-flower-theme.git /usr/share/sddm/themes/sddm-flower-theme 2>/dev/null && SDDM_THEME="sddm-flower-theme" || info "SDDM theme download failed, using $SDDM_THEME"
  fi
  if [ "$SDDM_THEME" = "sddm-flower-theme" ]; then
    # Apply Tokyo Night colors (always, regardless of wallpaper)
    sudo sed -i \
      -e 's/^MainColor=.*/MainColor="#c0caf5"/' \
      -e 's/^AccentColor=.*/AccentColor="#7aa2f7"/' \
      -e 's/^BackgroundColor=.*/BackgroundColor="#1a1b26"/' \
      /usr/share/sddm/themes/sddm-flower-theme/theme.conf 2>/dev/null || true
    # Copy wallpaper if available
    if [ -f /usr/share/sddm/themes/arf/background.jpg ]; then
      sudo cp /usr/share/sddm/themes/arf/background.jpg /usr/share/sddm/themes/sddm-flower-theme/Backgrounds/background.png 2>/dev/null || true
    fi
  fi
  # Fallback: use a built-in theme if flower theme wasn't installed
  if [ ! -f "/usr/share/sddm/themes/$SDDM_THEME/theme.conf" ]; then
    if [ -d /usr/share/sddm/themes/maldives ]; then
      SDDM_THEME="maldives"
    elif [ -d /usr/share/sddm/themes/maya ]; then
      SDDM_THEME="maya"
    fi
    info "Falling back to SDDM theme: $SDDM_THEME"
  fi
  sudo mkdir -p /etc/sddm.conf.d
  sudo tee /etc/sddm.conf.d/arf.conf > /dev/null << SDDM
[Theme]
Current=$SDDM_THEME
[Users]
MaximumUid=60000
SDDM
  ok "SDDM configured (theme: $SDDM_THEME)"

  # ── GRUB config ──────────────────────────────────────────────────
  info "Configuring GRUB..."
  cp "$SCRIPT_DIR/dotfiles/grub/fgrub.png" /boot/grub/
  cp "$SCRIPT_DIR/dotfiles/grub/theme.txt" /boot/grub/
  sed -i 's|^#\?GRUB_BACKGROUND=.*|GRUB_BACKGROUND=/boot/grub/fgrub.png|' /etc/default/grub
  sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME=/boot/grub/theme.txt|' /etc/default/grub
  grep -q '^GRUB_GFXMODE=' /etc/default/grub || echo 'GRUB_GFXMODE=1920x1080,auto' >> /etc/default/grub
  local CMDLINE="loglevel=3"
  if [ "$GPU_VENDOR" = "nvidia" ]; then
    CMDLINE="$CMDLINE nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
  fi
  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"$CMDLINE\"|" /etc/default/grub
  sed -i 's|^#GRUB_DISABLE_OS_PROBER=false|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub || true
  grub-mkconfig -o /boot/grub/grub.cfg
  systemctl enable grub-btrfsd 2>/dev/null || true
  ok "GRUB configured"

  # ── Firefox policies ──────────────────────────────────────────────
  info "Installing Firefox policies..."
  mkdir -p /usr/lib/firefox/distribution
  cp "$DOTFILES/firefox/policies.json" /usr/lib/firefox/distribution/policies.json
  ok "Firefox policies installed (uBlock Origin + Tokyo Night V3)"

  # Fix any root-owned files in $USER_HOME (mkdir/cp as root in chroot)
  chown -R "$USERNAME:" "$USER_HOME" 2>/dev/null || true

  ok "Stage 2 complete!"

  # If running via the ISO automated flow, reboot automatically
  if [ -f /etc/arf-linux.env ]; then
    info "Rebooting in 5 seconds..."
    sleep 5
    systemctl reboot
  else
    echo "  Reboot to start SDDM and enjoy FrenOS!"
  fi
}

# ── Main ───────────────────────────────────────────────────────
main() {
  case "${1:-}" in
    --stage2) stage2 ;;
    *)        stage1 ;;
  esac
}

main "$@"
