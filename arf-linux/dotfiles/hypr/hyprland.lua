-- Apply monitors (exec wlr-randr works at top level on both startup and reload)
local mons = os.getenv("HOME") .. "/.config/hypr/monitors.lua"
local f = io.open(mons, "r")
if f then
  f:close()
  local ok, err = pcall(dofile, mons)
  if not ok then
    hl.exec_cmd("notify-send 'Monitor config error' '" .. err .. "'")
  end
end

-- Autostart
hl.on("hyprland.start", function()
  -- Also apply on fresh startup (Wayland socket is ready here)
  local mons2 = os.getenv("HOME") .. "/.config/hypr/monitors.lua"
  local f2 = io.open(mons2, "r")
  if f2 then
    f2:close()
    pcall(dofile, mons2)
  end
  hl.exec_cmd("qs")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY")
  hl.exec_cmd("systemctl --user start opentabletdriver")
  hl.exec_cmd("hyprctl setcursor breeze 24")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("udiskie -t")
  hl.exec_cmd("wl-paste -t image/png --watch cliphist store")
  -- First-boot welcome
  hl.exec_cmd("test -f ~/.config/frenos/.welcome-seen || fren-welcome &")
  -- Input config (hl.config uses native Lua — no legacy parser needed)
  hl.config({
    input = {
      kb_layout = "us",
      follow_mouse = 1,
      sensitivity = 0,
      touchpad = { natural_scroll = false }
    }
  })
end)

-- Environment variables
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("PATH", os.getenv("PATH") .. ":" .. os.getenv("HOME") .. "/.local/bin")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XCURSOR_THEME", "breeze")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "breeze")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_NO_ANIMATION", "1")
hl.env("TERMINAL", "kitty")

-- General settings
hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 20,
    border_size = 2,
    col = {
      active_border = "rgb(7aa2f7)",
      inactive_border = "rgb(32364a)",
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
  },
  decoration = {
    rounding = 5,
    blur = {
      enabled = false,
      size = 3,
      passes = 1,
      vibrancy = 0.15,
    },
  },
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
  },
  misc = {
    force_default_wallpaper = -1,
    disable_hyprland_logo = true,
    mouse_move_focuses_monitor = true,
    vrr = 1,
  },

})

-- Bezier curves
hl.curve("easeOutQuint",     { type = "bezier", points = {{0.23, 1},     {0.32, 1}} })
hl.curve("easeInOutCubic",   { type = "bezier", points = {{0.65, 0.05},  {0.36, 1}} })
hl.curve("linear",           { type = "bezier", points = {{0, 0},        {1, 1}} })
hl.curve("almostLinear",     { type = "bezier", points = {{0.5, 0.5},    {0.75, 1.0}} })
hl.curve("quick",            { type = "bezier", points = {{0.15, 0},     {0.1, 1}} })

-- Animations
hl.animation({ leaf = "global",        enabled = true, speed = 10,    bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39,  bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79,  bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,   bezier = "easeOutQuint", style = "slide bottom" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49,  bezier = "linear",       style = "slide bottom" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1,     bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1,     bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03,  bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,     bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,   bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79,  bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39,  bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2,     bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 2,     bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2,     bezier = "almostLinear", style = "slide" })

-- Keybindings
local mainMod = "SUPER"

-- Program launchers
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("kitty -e env TERM=xterm-kitty fren"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("/usr/bin/qs ipc call launcher toggle"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("/usr/bin/qs ipc call theme toggle"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("/usr/bin/qs ipc call monitors toggle"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("wlogout -b 3"))
hl.bind(mainMod .. " + SLASH", hl.dsp.exec_cmd("fren-welcome"))

-- Window management
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.layout("pseudo"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Screenshots
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("hyprshot -m region --output-filename ~/Pictures/Screenshots/Screenshot_$(date +%Y%m%d_%H%M%S).png"))
hl.bind(mainMod .. " + CTRL + Z", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))

-- Focus movement
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspace switching
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move window to workspace
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse bindings (move/resize windows)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Media keys
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Window rules: float kitty
hl.window_rule({ match = { class = "kitty" }, float = true })
