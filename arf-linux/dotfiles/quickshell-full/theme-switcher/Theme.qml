pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int currentIndex: 0
    property int previewIndex: -1
    property bool wallpaperFeatureEnabled: false
    property bool wallpaperMode: false
    property var wallpaperTheme: ({})
    onPreviewIndexChanged: {
        if (previewIndex >= 0 && previewIndex < themes.length) {
            applyKittyTheme(themes[previewIndex]);
        } else {
            applyKittyTheme(current);
        }
    }
    readonly property var current: {
        if (previewIndex >= 0 && previewIndex < themes.length)
            return themes[previewIndex];
        if (wallpaperMode && wallpaperTheme && wallpaperTheme.bgBase)
            return wallpaperTheme;
        return themes[currentIndex];
    }
    readonly property int count: themes.length
    readonly property string currentName: current.name
    readonly property string currentFamily: current.family
    readonly property bool isDark: !isLightColor(current.bgBase)

    function isLightColor(hex) {
        hex = hex.toString().replace("#", "");
        var r = parseInt(hex.substr(0, 2), 16);
        var g = parseInt(hex.substr(2, 2), 16);
        var b = parseInt(hex.substr(4, 2), 16);
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5;
    }

    function applySystemColorScheme(dark) {
        colorSchemeProc.command = ["gsettings", "set",
            "org.gnome.desktop.interface", "color-scheme",
            dark ? "prefer-dark" : "prefer-light"];
        colorSchemeProc.running = true;
    }

    // Reactive color properties — same API as before
    readonly property color bgBase:       current.bgBase
    readonly property color bgSurface:    current.bgSurface
    readonly property color bgHover:      current.bgHover
    readonly property color bgSelected:   current.bgSelected
    readonly property color bgBorder:     current.bgBorder
    readonly property color bgOverlay:    "#88000000"

    readonly property color textPrimary:   current.textPrimary
    readonly property color textSecondary: current.textSecondary
    readonly property color textMuted:     current.textMuted

    readonly property color accentPrimary: current.accentPrimary
    readonly property color accentCyan:    current.accentCyan
    readonly property color accentGreen:   current.accentGreen
    readonly property color accentOrange:  current.accentOrange
    readonly property color accentRed:     current.accentRed

    // Semantic aliases
    readonly property color urgencyLow:      textMuted
    readonly property color urgencyNormal:   accentPrimary
    readonly property color urgencyCritical: accentRed
    readonly property color batteryGood:     accentGreen
    readonly property color batteryWarning:  accentOrange
    readonly property color batteryCritical: accentRed

    function hexToRgba(hex) {
        return "rgba(" + hex.toString().replace("#", "") + "ff)";
    }

    function applyHyprlandBorders(t) {
        var active = hexToRgba(t.accentPrimary);
        var inactive = hexToRgba(t.bgBorder);
        hyprlandProc.command = ["sh", "-c",
            'hyprctl eval \'hl.config({ general = { col = { active_border = "' + active + '", inactive_border = "' + inactive + '" } } })\''
        ];
        hyprlandProc.running = true;
    }

    function applyTheme(t) {
        applyKittyTheme(t);
        applyFrenTheme(t);
        applySystemColorScheme(!isLightColor(t.bgBase));
        applyHyprlandBorders(t);
    }

    function setTheme(index) {
        if (index >= 0 && index < themes.length) {
            wallpaperMode = false;
            currentIndex = index;
            saveProc.command = ["sh", "-c", 'printf "%s" "$1" > "$HOME/.config/quickshell/theme.conf"', "sh", String(index)];
            saveProc.running = true;
            applyTheme(themes[index]);
            propagateWallpapers(themes[index]);
            applyQtGtkTheme(themes[index]);
        }
    }

    function propagateWallpapers(t) {
        if (!t.wallpapers) return;
        var wp = t.wallpapers;
        var home = Quickshell.env("HOME");

        // Hyprlock wallpaper + colors
        if (wp.hyprlock) {
            var hyprlockSrc = wp.hyprlock.replace("~", home);
            var hlConf = "";
            if (t.hyprlock) {
                var hl = t.hyprlock;
                var oc = hl.outer_color.replace("#","");
                var ic = hl.inner_color.replace("#","");
                var fc = hl.font_color.replace("#","");
                var cc = hl.clock_color.replace("#","");
                var dc = hl.date_color.replace("#","");
                var uc = hl.user_color.replace("#","");
                hlConf = 'general {\n    grace = 0\n    hide_cursor = true\n}\n\n' +
                    'background {\n    monitor =\n    path = $HOME/.config/hypr/wallpaper/hyprlock.png\n' +
                    '    blur_size = 5\n    blur_passes = 2\n    noise = 0.01\n    contrast = 1.2\n' +
                    '    brightness = 0.8\n    vibrancy = 0.2\n    vibrancy_darkness = 0.0\n}\n\n' +
                    'input-field {\n    monitor =\n    size = 250, 50\n    outline_thickness = 3\n' +
                    '    dots_size = 0.33\n    dots_spacing = 0.15\n    dots_center = true\n' +
                    '    outer_color = rgb(' + oc + ')\n    inner_color = rgb(' + ic + ')\n' +
                    '    font_color = rgb(' + fc + ')\n    placeholder_text = <i>Password...</i>\n' +
                    '    hide_input = false\n    position = 0, 200\n    halign = center\n    valign = bottom\n}\n\n' +
                    'label {\n    monitor =\n    text = cmd[update:1000] echo "<b><big> $(date +\\"%H:%M:%S\\") </big></b>"\n' +
                    '    color = rgb(' + cc + ')\n    font_size = 94\n    font_family = Hack Nerd Font\n' +
                    '    position = 0, 0\n    halign = center\n    valign = center\n}\n\n' +
                    'label {\n    monitor =\n    text = cmd[update:18000000] echo "<b> $(date +\'%A, %-d %B %Y\') </b>"\n' +
                    '    color = rgb(' + dc + ')\n    font_size = 28\n    font_family = Hack Nerd Font\n' +
                    '    position = 0, -120\n    halign = center\n    valign = top\n}\n\n' +
                    'label {\n    monitor =\n    text = "\ $USER"\n    color = rgb(' + uc + ')\n' +
                    '    font_size = 18\n    font_family = Hack Nerd Font\n    position = 0, 100\n    halign = center\n    valign = bottom\n}\n';
            }
            wallpaperHyprlockProc.command = ["sh", "-c",
                'cp "' + hyprlockSrc + '" "$HOME/.config/hypr/wallpaper/hyprlock.png"' +
                (hlConf ? '; printf "%s" \'' + hlConf.replace(/'/g, "'\\''") + '\' > "$HOME/.config/hypr/hyprlock.conf"' : '')
            ];
            wallpaperHyprlockProc.running = true;
        }

        // Desktop wallpaper via hyprpaper
        if (wp.desktop) {
            var desktopSrc = wp.desktop.replace("~", home);
            wallpaperDesktopProc.command = ["sh", "-c",
                'printf "wallpaper {\\n    monitor = *\\n    path = %s\\n    fit_mode = cover\\n}\\n" "' + desktopSrc + '" > "$HOME/.config/hypr/hyprpaper.conf"; ' +
                'killall hyprpaper 2>/dev/null; sleep 0.3; setsid hyprpaper >/dev/null 2>&1 &'
            ];
            wallpaperDesktopProc.running = true;
        }

        // SDDM + GRUB (wallpapers + colors, need pkexec)
        var cmds = [];
        if (wp.sddm) {
            var sddmSrc = wp.sddm.replace("~", home);
            cmds.push('cp "' + sddmSrc + '" /usr/share/sddm/themes/sddm-flower-theme/Backgrounds/background.png');
        }
        if (t.sddm) {
            var sd = t.sddm;
            var sddmConf = '[General]\n\nBackground="Backgrounds/background.png"\n\n' +
                'DimBackgroundImage="0.0"\nScaleImageCropped="true"\nScreenWidth="1920"\nScreenHeight="1080"\n\n' +
                'FullBlur="false"\nPartialBlur="true"\nBlurRadius="0"\n\n' +
                'HaveFormBackground="false"\nFormPosition="center"\n' +
                'BackgroundImageHAlignment="center"\nBackgroundImageVAlignment="center"\n\n' +
                'MainColor="' + sd.main_color + '"\nAccentColor="' + sd.accent_color + '"\nBackgroundColor="' + sd.background_color + '"\n\n' +
                'InterfaceShadowSize="6"\nInterfaceShadowOpacity="0.6"\nRoundCorners="20"\nScreenPadding="0"\n' +
                'Font="Roboto mono"\n\nForceRightToLeft="false"\nForceLastUser="true"\nForcePasswordFocus="true"\n' +
                'ForceHideCompletePassword="true"\nForceHideVirtualKeyboardButton="false"\nForceHideSystemButtons="false"\n' +
                'AllowEmptyPassword="false"\nAllowBadUsernames="false"\n\n' +
                'HourFormat="HH:mm"\nDateFormat="dddd, d of MMMM"\n\nHeaderText="Welcome!"\n';
            cmds.push('printf "%s" \'' + sddmConf.replace(/'/g, "'\\''") + '\' > /usr/share/sddm/themes/sddm-flower-theme/theme.conf');
        }
        if (wp.grub) {
            var grubSrc = wp.grub.replace("~", home);
            cmds.push('cp "' + grubSrc + '" /boot/grub/fgrub.png');
        }
        if (t.grub_theme) {
            var gt = t.grub_theme;
            var grubConf = '# Theme\n' +
                'title-text: ""\n' +
                'title-font: "Hack Regular 12"\n' +
                'title-color: "' + gt.title_color + '"\n' +
                'desktop-image: "fgrub.png"\n' +
                'desktop-color: "' + gt.desktop_color + '"\n' +
                'terminal-font: "Hack Regular 12"\n\n' +
                '+ boot_menu {\n  left = 50%\n  top = 20%\n  width = 45%\n  height = 60%\n' +
                '  item_color = "' + gt.item_color + '"\n' +
                '  selected_item_color = "' + gt.selected_item_color + '"\n' +
                '  item_height = 32\n  item_padding = 8\n  item_spacing = 4\n' +
                '  item_font = "Hack Regular 12"\n  selected_item_font = "Hack Bold 12"\n  scrollbar = false\n}\n';
            cmds.push('printf "%s" \'' + grubConf.replace(/'/g, "'\\''") + '\' > /boot/grub/theme.txt');
        }
        if (cmds.length > 0) {
            wallpaperSystemProc.command = ["pkexec", "sh", "-c", cmds.join(" && ")];
            wallpaperSystemProc.running = true;
        }
    }

    function applyQtGtkTheme(t) {
        if (!t.qt && !t.gtk) return;
        var home = Quickshell.env("HOME");
        var cmds = [];

        // Qt: write qt5ct.conf and qt6ct.conf
        if (t.qt) {
            var qtConf = '[Appearance]\nstyle=' + t.qt.style + '\nicon_theme=' + t.qt.iconTheme + '\n\n[Fonts]\nfont="Sans,11,-1,5,400,0,0,0,0,0,Regular"\n';
            cmds.push('printf "%s" "' + qtConf.replace(/\n/g, '\\n').replace(/"/g, '\\"') + '" > "$HOME/.config/qt5ct/qt5ct.conf"');
            cmds.push('printf "%s" "' + qtConf.replace(/\n/g, '\\n').replace(/"/g, '\\"') + '" > "$HOME/.config/qt6ct/qt6ct.conf"');

            // Activate Kvantum theme
            if (t.qt.kvantum) {
                cmds.push('mkdir -p "$HOME/.config/Kvantum" && printf "[General]\ntheme=%s\\n" "' + t.qt.kvantum + '" > "$HOME/.config/Kvantum/kvantum.conf"');
            }
        }

        // GTK: write gtk-3.0/settings.ini and gtk-4.0/settings.ini
        if (t.gtk) {
            var gtkConf = '[Settings]\ngtk-theme-name=' + t.gtk.theme + '\ngtk-icon-theme-name=' + t.gtk.iconTheme + '\ngtk-cursor-theme-name=breeze\n';
            cmds.push('printf "%s" "' + gtkConf.replace(/\n/g, '\\n').replace(/"/g, '\\"') + '" > "$HOME/.config/gtk-3.0/settings.ini"');
            cmds.push('printf "%s" "' + gtkConf.replace(/\n/g, '\\n').replace(/"/g, '\\"') + '" > "$HOME/.config/gtk-4.0/settings.ini"');
        }

        if (cmds.length > 0) {
            qtGtkProc.command = ["sh", "-c", cmds.join(" && ")];
            qtGtkProc.running = true;
        }
    }

    function setWallpaperMode() {
        if (!wallpaperFeatureEnabled)
            return;
        wallpaperMode = true;
        saveProc.command = ["sh", "-c", 'printf "%s" wallpaper > "$HOME/.config/quickshell/theme.conf"'];
        saveProc.running = true;
        if (wallpaperTheme && wallpaperTheme.bgBase)
            applyTheme(wallpaperTheme);
    }

    // Regenerate the wallpaper palette from a given image, then switch to wallpaper
    // mode. set.sh writes wallpaper-theme.json, which the FileView below live-reloads
    // and applies. Without an image this is equivalent to setWallpaperMode().
    function setWallpaperFromImage(img) {
        if (!wallpaperFeatureEnabled)
            return;
        if (img && img.length > 0) {
            generateProc.command = ["sh", Quickshell.env("HOME") + "/.config/quickshell/theme-switcher/wallpaper-theme/set.sh", img];
            generateProc.running = true;
        }
        setWallpaperMode();
    }

    function applyFrenTheme(t) {
        if (!t.fren) return;
        var f = t.fren;
        var conf = 'background = "' + f.background + '"\n' +
            'foreground = "' + f.foreground + '"\n\n' +
            'border = "' + f.border + '"\n' +
            'focus_border = "' + f.focus_border + '"\n' +
            'muted = "' + f.muted + '"\n\n' +
            'directory = "' + f.directory + '"\n\n' +
            'status_bg = "' + f.status_bg + '"\n' +
            'status_fg = "' + f.status_fg + '"\n';
        frenProc.command = ["sh", "-c", 'printf "%s" "' + conf.replace(/\n/g, '\\n').replace(/"/g, '\\"') + '" > "$HOME/.config/fren/theme.toml"'];
        frenProc.running = true;
    }

    function applyKittyTheme(t) {
        var colorsConf = [
            "foreground " + t.textPrimary,
            "background " + t.bgBase,
            "cursor " + t.accentPrimary,
            "cursor_text_color " + t.bgBase,
            "selection_foreground " + t.textPrimary,
            "selection_background " + t.bgSelected,
            "active_tab_foreground " + t.textPrimary,
            "active_tab_background " + t.bgSurface,
            "inactive_tab_foreground " + t.textMuted,
            "inactive_tab_background " + t.bgBase,
            "color0 " + t.bgSurface,
            "color1 " + t.accentRed,
            "color2 " + t.accentGreen,
            "color3 " + t.accentOrange,
            "color4 " + t.accentPrimary,
            "color5 " + t.accentPrimary,
            "color6 " + t.accentCyan,
            "color7 " + t.textSecondary,
            "color8 " + t.textMuted,
            "color9 " + t.accentRed,
            "color10 " + t.accentGreen,
            "color11 " + t.accentOrange,
            "color12 " + t.accentPrimary,
            "color13 " + t.accentPrimary,
            "color14 " + t.accentCyan,
            "color15 " + t.textPrimary
        ].join("\n");
        var colorsArgs = [
            "foreground=" + t.textPrimary,
            "background=" + t.bgBase,
            "cursor=" + t.accentPrimary,
            "cursor_text_color=" + t.bgBase,
            "selection_foreground=" + t.textPrimary,
            "selection_background=" + t.bgSelected,
            "active_tab_foreground=" + t.textPrimary,
            "active_tab_background=" + t.bgSurface,
            "inactive_tab_foreground=" + t.textMuted,
            "inactive_tab_background=" + t.bgBase,
            "color0=" + t.bgSurface,
            "color1=" + t.accentRed,
            "color2=" + t.accentGreen,
            "color3=" + t.accentOrange,
            "color4=" + t.accentPrimary,
            "color5=" + t.accentPrimary,
            "color6=" + t.accentCyan,
            "color7=" + t.textSecondary,
            "color8=" + t.textMuted,
            "color9=" + t.accentRed,
            "color10=" + t.accentGreen,
            "color11=" + t.accentOrange,
            "color12=" + t.accentPrimary,
            "color13=" + t.accentPrimary,
            "color14=" + t.accentCyan,
            "color15=" + t.textPrimary
        ].join(" ");
        kittyProc.command = ["sh", "-c",
            "printf '%s\\n' '" + colorsConf + "' > $HOME/.config/kitty/theme-colors.conf; " +
            "for sock in /tmp/kitty-*; do " +
            "[ -S \"$sock\" ] && kitty @ --to \"unix:$sock\" set-colors --all --configured " + colorsArgs + "; " +
            "done"
        ];
        kittyProc.running = true;
    }

    Process { id: saveProc; running: false }
    Process { id: generateProc; running: false }
    Process { id: kittyProc; running: false }
    Process { id: frenProc; running: false }
    Process { id: colorSchemeProc; running: false }
    Process { id: hyprlandProc; running: false }
    Process { id: wallpaperHyprlockProc; running: false }
    Process { id: wallpaperDesktopProc; running: false }
    Process { id: wallpaperSystemProc; running: false }
    Process { id: qtGtkProc; running: false }

    Process {
        id: loadProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/theme.conf 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (raw === "wallpaper" && root.wallpaperFeatureEnabled) {
                    root.wallpaperMode = true;
                    if (root.wallpaperTheme && root.wallpaperTheme.bgBase)
                        root.applyTheme(root.wallpaperTheme);
                    else
                        // wallpaper-theme.json missing/empty yet — show a visible
                        // default until a wallpaper hook regenerates it (the FileView
                        // re-applies once wallpaperTheme populates).
                        root.applyTheme(root.themes[0]);
                    return;
                }
                const idx = parseInt(raw);
                if (!isNaN(idx) && idx >= 0 && idx < root.themes.length) {
                    root.wallpaperMode = false;
                    root.currentIndex = idx;
                    root.applyTheme(root.themes[idx]);
                } else if (raw === "wallpaper") {
                    // Persisted wallpaper choice but the feature is disabled —
                    // fall back to the curated default.
                    root.wallpaperMode = false;
                    root.applyTheme(root.themes[root.currentIndex]);
                }
            }
        }
    }

    FileView {
        id: themesFile
        path: Quickshell.env("HOME") + "/.config/quickshell/theme-switcher/themes.json"
        onTextChanged: {
            const raw = themesFile.text();
            if (!raw) return;
            try {
                root.themes = JSON.parse(raw);
                loadProc.running = true;
            } catch (e) {
                console.error("Failed to parse themes.json:", e);
            }
        }
    }

    property var themes: [
        {
            name: "Night", family: "Tokyo Night",
            wallpapers: {
                desktop: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-night/desktop.png",
                hyprlock: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-night/hyprlock.png",
                sddm: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-night/sddm.png",
                grub: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-night/grub.png"
            },
            qt: { kvantum: "Kvantum-Tokyo-Night", style: "kvantum-dark", iconTheme: "Tokyonight-Dark" },
            gtk: { theme: "Tokyonight-Dark", iconTheme: "Tokyonight-Dark" },
            fren: { background: "#1a1b26", foreground: "#c0caf5", border: "#32364a", focus_border: "#7aa2f7", muted: "#565f89", directory: "#7dcfff", status_bg: "#1a1b26", status_fg: "#7aa2f7" },
            bgBase: "#1a1b26", bgSurface: "#24283b", bgHover: "#1e2235",
            bgSelected: "#283457", bgBorder: "#32364a",
            textPrimary: "#c0caf5", textSecondary: "#a9b1d6", textMuted: "#565f89",
            accentPrimary: "#7aa2f7", accentCyan: "#7dcfff",
            accentGreen: "#9ece6a", accentOrange: "#ff9e64", accentRed: "#f7768e",
            hyprlock: { outer_color: "#7aa2f7", inner_color: "#1a1b26", font_color: "#c0caf5", clock_color: "#c0caf5", date_color: "#7aa2f7", user_color: "#7dcfff" },
            sddm: { main_color: "#c0caf5", accent_color: "#7aa2f7", background_color: "#1a1b26" },
            grub_theme: { title_color: "#7aa2f7", desktop_color: "#1a1b26", item_color: "#a9b1d6", selected_item_color: "#7aa2f7" }
        },
        {
            name: "Light", family: "Tokyo Light",
            wallpapers: {
                desktop: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-light/desktop.png",
                hyprlock: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-light/hyprlock.png",
                sddm: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-light/sddm.png",
                grub: "~/.config/quickshell/theme-switcher/wallpapers/tokyo-light/grub.png"
            },
            qt: { kvantum: "Kvantum-Tokyo-Light", style: "kvantum", iconTheme: "Tokyonight-Light" },
            gtk: { theme: "Tokyonight-Light", iconTheme: "Tokyonight-Light" },
            fren: { background: "#f5f5f5", foreground: "#404040", border: "#d8d8d8", focus_border: "#607080", muted: "#999999", directory: "#607080", status_bg: "#eaeaea", status_fg: "#607080" },
            bgBase: "#f5f5f5", bgSurface: "#eaeaea", bgHover: "#e2e2e2",
            bgSelected: "#d0d0d0", bgBorder: "#d8d8d8",
            textPrimary: "#404040", textSecondary: "#606060", textMuted: "#999999",
            accentPrimary: "#607080", accentCyan: "#607080",
            accentGreen: "#6a8a6a", accentOrange: "#9a7050", accentRed: "#9a5555",
            hyprlock: { outer_color: "#607080", inner_color: "#f5f5f5", font_color: "#404040", clock_color: "#404040", date_color: "#607080", user_color: "#607080" },
            sddm: { main_color: "#404040", accent_color: "#607080", background_color: "#f5f5f5" },
            grub_theme: { title_color: "#607080", desktop_color: "#f5f5f5", item_color: "#606060", selected_item_color: "#607080" }
        }
    ]
}
