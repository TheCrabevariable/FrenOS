# FrenOS

Arch Linux automated installer ISO with Hyprland, Quickshell Tokyo Night bar, and single-reboot post-install configuration.

- **BTRFS** — not working
- **EXT4** — working
- **SWAP** — working
- **LUKS** — being fixed

i am working to make everything good

## Features

- **Automated install** — interactive stage1 with keyboard layout, disk selection, swap size, kernel choice, user setup, timezone
- **Single reboot** — stage2 can run in chroot during install, or on first boot via systemd oneshot
- **Tokyo Night theme** — dark theme across bar, kitty, fastfetch, fren, btop, zed, hyprlock, SDDM, GRUB
- **Quickshell bar** — app launcher (SUPER+R), theme switcher (SUPER+T), monitor manager (SUPER+D), power menu (SUPER+ESC), clickable WiFi/BT/power profile pills, color-coded CPU, clipboard manager, media player (mpd-mpris), calendar, audio mixer, notification center, network popup
- **Hyprland** with Lua config (hyprland.lua) + minimal legacy parser (hyprland.conf)
- **BTRFS** filesystem with zstd compression (ext4 also available)
- **WiFi config** — prompted during install, persisted to installed system
- **Stage2 auto-config** — dotfiles, AUR packages, flatpaks, wallpapers run on first boot

## Repository Structure

```
arf-linux/               # Installer scripts, dotfiles, patches
  install.sh             # Stage2 post-install script (copied to installed system)
  packages.txt           # Official + AUR package list
  dotfiles/              # Default configs for hypr, kitty, btop, fastfetch, zsh, etc.
    quickshell-full/     # Full Quickshell config (menu, cliphist, mpd-mpris, etc.)
    firefox/             # Firefox policies (uBlock Origin + Tokyo Night V3)
    frenos/              # FrenOS updater script (update-fos)
arf-linux-iso/           # ISO build profile
  build.sh               # Builds the bootable ISO with archiso
  profiledir/            # archiso config, airootfs overlay, arf-installer
    airootfs/opt/arf-linux/     # Bundled copy of arf-linux/ (copied at build time)
    airootfs/usr/local/bin/arf-installer  # Stage1 installer (auto-launched on boot)
```

## Download

Pre-built ISOs are available from the [releases page](https://github.com/TheCrabevariable/FrenOS/releases) (recommended).

## Build from source

```sh
cd arf-linux-iso
sudo ./build.sh
```

Requires `archiso` on an Arch Linux system. Output: `out/frenos-<YYYY.MM>-x86_64.iso`.

## Install

1. Write ISO to USB: `sudo dd if=frenos-<YYYY.MM>-x86_64.iso of=/dev/sdX bs=4M status=progress && sync`
2. Boot from USB — `arf-installer` auto-launches
3. Follow prompts: keyboard layout → disk → swap (none/4GB/8GB) → WiFi (optional) → kernel → hostname/user/password/timezone → confirm wipe
4. Reboot → SDDM → Hyprland + Quickshell bar (stage2 runs as systemd oneshot on first boot)

## Custom Commands

| Alias | Command | Description |
|---|---|---|
| `install` | `sudo pacman -S` | Install a package |
| `update` | `sudo pacman -Syu` | Update all packages |
| `remove` | `sudo pacman -Rns` | Remove a package and its unused dependencies |
| `clean` | `sudo pacman -Scc` | Clear pacman cache |
| `ff` | `fastfetch` | Quick system info |
| `music-dl` | `yt-dlp ...` | Download audio from a URL (mp3 with metadata + thumbnail) |
| `fren` | TUI file manager | Navigate, copy, move, rename files with vi-style keys |
| `rmpc` | TUI music player | MPD client with album art, playlist, keybinds |
| `update-fos` | `git pull` | Pull latest FrenOS dotfiles and configs from GitHub |

## Screenshots

![FrenOS](arf.png)

## Keybinds

| Key | Action |
|---|---|
| SUPER + Q | Terminal (kitty) |
| SUPER + E | File manager (fren) |
| SUPER + R | App launcher (Quickshell) |
| SUPER + T | Theme switcher (Quickshell) |
| SUPER + D | Monitor manager (Quickshell) |
| SUPER + ESC | Power menu |
| SUPER + C | Close window |
| SUPER + M | Exit Hyprland |
| SUPER + V | Toggle window float |
| SUPER + P | Pseudo-tile layout |
| SUPER + J | Toggle split layout |
| SUPER + F | Fullscreen window |
| SUPER + Z | Region screenshot (clipboard) |
| SUPER + SHIFT + Z | Region screenshot (file) |
| SUPER + CTRL + Z | Fullscreen screenshot (clipboard) |
| SUPER + arrows | Move focus directionally |
| SUPER + 1-0 | Switch workspace |
| SUPER + SHIFT + 1-0 | Move window to workspace |
| SUPER + S | Toggle scratchpad |
| SUPER + SHIFT + S | Move window to scratchpad |
| SUPER + mouse drag | Move window |
| SUPER + right-click drag | Resize window |
| SUPER + scroll | Scroll workspaces |
| XF86Audio (vol/bright) | Media & hardware keys |

## Post-Install

Stage2 installs:
- **AUR packages:** animu-bin, fren-bin, heroic-games-launcher-bin, vesktop, wlogout
- **Firefox:** pre-configured with uBlock Origin and Tokyo Night V3 (xMdb) theme via policies.json
- **Flatpaks:** Heroic Game Launcher
- **Dotfiles:** hyprland, kitty, btop, fastfetch, fren, zed, zsh, rmpc
- **Wallpapers:** cloned from [TheCrabevariable/Wallpaper](https://github.com/TheCrabevariable/Wallpaper)
- **SDDM theme:** flower theme with Tokyo Night colors
- **Customizations:** kitty with inline Tokyo Night colors, QS with /proc/stat CPU, disk-cached image previews, session remember, wifi/bt/power profile toggles, cliphist clipboard manager, mpd-mpris media bridge
