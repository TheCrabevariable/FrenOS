# FrenOS

Arch Linux automated installer ISO with Hyprland, Quickshell Tokyo Night bar, and single-reboot post-install configuration.

- **BTRFS** — working
- **SUBVOLUMES** — working
- **EXT4** — working
- **SWAP** — working
- **LUKS** — working
- **ZRAM** — working
- **SNAPPER** — working
- **WELCOME & KEYBINDS APP** — working
- **CLEARING OF CACHE** — working (weekly paccache)
- **SSD TRIM** — working (weekly fstrim, LUKS-aware)
- **EXTRA DISK AUTOMOUNT** — working (optional prompt during install)

## Known Issues

- None currently known — RMPC database errors were fixed by switching MPD to socket activation

## Features

- **Automated install** — interactive stage1 with keyboard layout, disk selection, swap size, kernel choice, user setup, timezone
- **Single reboot** — stage2 can run in chroot during install, or on first boot via systemd oneshot
- **Tokyo Night theme** — dark theme across bar, kitty, fastfetch, fren, btop, zed, hyprlock, SDDM, GRUB + GTK3/GTK4 and Qt (Kvantum) apps
- **Quickshell bar** — app launcher (SUPER+R), theme switcher (SUPER+T), monitor manager (SUPER+D), dashboard (SUPER+B), power menu (SUPER+ESC), clickable WiFi/BT/brightness/power pills with popups, color-coded CPU, clipboard manager, media player (mpd-mpris), calendar, audio mixer, notification center, network popup, OSD for volume/brightness keys
- **Welcome app** — keybinds cheat sheet + GitHub link, opens on first login or with SUPER+/ 
- **Gaming ready** — Steam, Lutris, Heroic, gamemode (`gamemoderun`), ProtonPlus to install Proton/Wine/DXVK tools, Flatseal for sandbox permissions
- **Maintenance** — weekly paccache (keeps 2 versions), journald capped at 500M (+100M runtime), old logs vacuumed after 14 days
- **Extra disk automount** — installer can add other disks to fstab: nofail, shows in file manager, user-writable NTFS/FAT
- **zram** — compressed swap in RAM (half of RAM, zstd), big win on low-RAM machines
- **BTRFS snapshots** — snapper timeline/cleanup, grub-btrfs boot entries, btrfs-assistant GUI
- **zsh** — custom prompt (user@host dir + exec time), completion, aliases, fastfetch on launch
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
3. Follow prompts: keyboard layout → disk → swap (none/4GB/8GB) → WiFi (optional) → kernel → hostname/user/password/timezone → extra disks to automount (optional) → confirm wipe
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

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/2efcb061-0d66-4ef7-89d7-7b19233fdac6" />

## Keybinds

| Key | Action |
|---|---|
| SUPER + Q | Terminal (kitty) |
| SUPER + E | File manager (fren) |
| SUPER + R | App launcher (Quickshell) |
| SUPER + T | Theme switcher (Quickshell) |
| SUPER + D | Monitor manager (Quickshell) |
| SUPER + B | Dashboard (Quickshell) |
| SUPER + / | Welcome app (keybinds + GitHub) |
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
- **Official packages:** Hyprland suite, Quickshell, kitty, zed, steam, lutris, discord, mpd/rmpc, firefox, libreoffice, flatpak/bazaar, zram-generator, kvantum + qt6ct, ddcutil, gamemode, pacman-contrib, and more
- **AUR packages:** animu-bin, fren-bin, heroic-games-launcher-bin, tokyonight-gtk-theme-git
- **Flathub apps:** ProtonPlus (Proton/Wine tool manager) + Flatseal (sandbox permission editor), Flathub remote added automatically
- **zsh:** custom two-line prompt with command timing, set as default shell
- **Tokyo Night GTK/Qt theming:** Kvantum-Tokyo-Night theme, GTK3 settings.ini (Tokyonight-Dark), GTK4 symlinks into the theme package
- **zram:** ram/2 zstd compressed swap via zram-generator
- **Maintenance:** paccache.timer weekly (keeps 2 versions per package), journald capped at 500M system / 100M runtime, fstrim.timer on SSDs (TRIM passes through LUKS)
- **Firefox:** pre-configured with uBlock Origin and Tokyo Night V3 (xMdb) theme via policies.json
- **Dotfiles:** hyprland, quickshell (bar/dashboard/OSD/theme switcher), kitty, btop, fastfetch, fren, zed, zsh, rmpc, mpd (socket-activated user service)
- **BTRFS only:** snapper configs, grub-btrfsd, btrfs-assistant, initial "Clean install" snapshot
- **Wallpapers:** cloned from [TheCrabevariable/Wallpaper](https://github.com/TheCrabevariable/Wallpaper)
- **SDDM theme:** flower theme with Tokyo Night colors
- **fren-welcome:** installed to /usr/local/bin — keybinds cheat sheet on first login or SUPER+/
