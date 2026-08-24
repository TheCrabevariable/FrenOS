//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import Quickshell.Io
import QtQuick
import "bar"
import "app-launcher"
import "notifications"
import "theme-switcher"
//import "wallpaper"
import "osd"
import "monitor-manager"
import "network"
import "power-profiles"
import "audio"
import "calendar"
import "media"
import "notification-center"
import "clipboard"
import "dashboard"
import "session"

Scope {
  ThemeSwitcher { id: ts }
  Bar { theme: ts.theme }
  AppLauncher { theme: ts.theme }
  NotificationPopup { theme: ts.theme }
  // WallpaperManager { theme: ts.theme }
  OSD { theme: ts.theme }
  MonitorManager { theme: ts.theme }
  ConnectivityPopup { theme: ts.theme }
  PowerProfilePopup { theme: ts.theme }
  AudioPopup { theme: ts.theme }
  CalendarPopup { theme: ts.theme }
  MediaPopup { theme: ts.theme }
  NotificationCenter { theme: ts.theme }
  ClipboardPopup { theme: ts.theme }
  SessionMenu { theme: ts.theme }
}
