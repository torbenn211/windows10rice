TVA RICE - Windows 10, Omarchy-style keys, '90s Unix workstation look
=====================================================================

What you get
------------
- Komorebi tiling with smooth glide animations (EaseInOutSine, 450 ms, 60 fps),
  square 2px amber borders, 9 workspaces, community per-app rules for dialogs.
- Omarchy-style keys on the Windows key (SUPER). Alt fallback included.
- YASB top bar: workspaces, layout, active window title | clock | net, cpu, mem, volume
  (+ battery on laptops). Native taskbar auto-hides.
- Windows Terminal + Monocraft, amber-on-black, block cursor, user@host:path$ prompt.
- Arch Linux on WSL2 (official image): Win+Enter opens it, 'TVA Linux' Terminal profile,
  Red Hat-style [user@host dir]$ prompt, retro CRT effect in the terminal.
- Windows Explorer stays the file manager (Win+Shift+F), set to a classic look: status bar,
  icons not thumbnails, ribbon collapsed.
- 90s panel look: beveled keys, caps labels, thick amber rule, dithered wallpaper.
- Reversible Windows polish + optimization (see below). Wallpaper has no clock.

Install
-------
1. Extract the whole ZIP to a normal folder. Run install.bat. Read the warnings.
2. Sign out and back in once (title-bar colors, hidden icons, input settings).
3. Arch Linux: run  powershell -ExecutionPolicy Bypass -File .\scripts\setup-wsl.ps1
   It installs the official Arch WSL image (admin, maybe a restart), updates it, creates
   your user with sudo, enables systemd, and sets up nvim/mc/btop. Then run install.bat
   again so Win+Enter points at Arch.
Options (run install.ps1 directly): -AltKeys  -KeepTaskbar  -NoPolish  -NoOptimize  -SkipWallpaper

Keys (SUPER = Windows key)
--------------------------
Super+Enter            Terminal (Arch if WSL works)
Super+Shift+Enter      PowerShell
Super+Shift+F          File manager (Windows Explorer)
Super+Shift+B          Browser (Edge; edit whkdrc for another)
Super+Shift+N          Neovim (Arch) / VS Code
Super+Shift+T          btop (Arch) / Task Manager
Super+K                Show this key list (opens whkdrc)
Super+W                Close window
Super+F                Fullscreen (monocle)       Super+T  Toggle floating
Super+J                Cycle layout               Super+P  Pause tiling
Super+Arrows           Focus                      Super+Shift+Arrows  Move window
Super+- / Super+=      Resize width               Super+Shift+- / +   Resize height
Super+1..9             Workspace                  Super+Shift+1..9    Send window there
Super+Tab / +Shift     Next / previous workspace
Super+Shift+R          Reload Komorebi config
Super+Ctrl+L           Lock (Win+L also works)    Super+Ctrl+Shift+Q  Stop WM (emergency)
Launcher: Flow Launcher, Alt+Space (change it in Flow's settings if you want Win+Space).
If a Win combo conflicts with Windows, reinstall with -AltKeys (Alt+hjkl style).

Windows polish (reversible, current user only)
----------------------------------------------
Amber title bars/borders, transparency off, desktop icons hidden, Task View/Search/
Cortana/News removed from the taskbar, Explorer opens This PC with full path in the
title, Aero Shake/Snap off (they fight a tiler), Alt+Tab shows windows only, no system
sounds. Skip with -NoPolish.

Windows optimization (reversible, current user only)
----------------------------------------------------
Fast key repeat, no mouse acceleration, no sticky-key popups, background apps off,
no web results in Start search, no Game DVR, no Start/lock-screen suggestions or ads,
no tailored-ads ID, no Explorer sync nags, no Explorer startup delay, High performance
power plan on desktops (laptops keep theirs). No services are disabled and no security
features are touched. Skip with -NoOptimize.
Extras: scripts\cleanup.ps1 (dry run; add -Run to delete old temp files),
scripts\diagnose.ps1 (shows rice RAM/CPU and your startup programs).

Honest limitations
------------------
- Not tested on a real Windows PC by the author. Use TEST-CHECKLIST.md.
- Komorebi animations are experimental upstream; they only animate moves within one
  workspace on one monitor. If your Komorebi rejects the "animation" block, delete it.
- Win-key overrides need whkd 0.2.4+. Win+L cannot be rebound without a registry change.
- Taskbar auto-hide is applied live; if it does not stick, sign out and back in.
- Windows reserves/handles some keys itself; test bindings one at a time.

Recovery / uninstall
--------------------
Ctrl+Shift+Esc = Task Manager. Win+Ctrl+Shift+Q stops the WM. If the bar or WM
misbehaves: komorebic stop --whkd. Run uninstall.bat to restore configs, taskbar,
registry values, power plan and wallpaper. Logs: %LOCALAPPDATA%\tva-rice\install.log
