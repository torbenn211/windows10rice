# Windows verification checklist (do these on the target PC)

- [ ] Install finished; `%LOCALAPPDATA%\tva-rice\install.log` has no errors
- [ ] `komorebic state` works; windows glide smoothly when you move/retile
- [ ] Win+Enter opens a terminal (Arch if WSL works); Win key alone still opens Start
- [ ] Win+Shift+F opens Explorer; Win+Arrows focus; Win+1..9 switch workspaces
- [ ] Win+Tab / Win+Space / Win+E did not trigger Windows' own behaviour (else use -AltKeys)
- [ ] File pickers and dialogs float correctly (applications.json downloaded)
- [ ] YASB bar loads: workspaces, layout, window title, clock, net/cpu/mem/volume
- [ ] Taskbar auto-hides; Ctrl+Shift+Esc works; Win+Ctrl+Shift+Q stops the WM
- [ ] Monocraft shows in Terminal and the bar; "TVA Linux" profile opens WSL in ~
- [ ] `scripts\setup-wsl.ps1` installs Arch; `sudo pacman -Syu`, `code .` and `explorer.exe .` work from Arch
- [ ] Title bars are amber, desktop icons hidden, no transparency
- [ ] Idle CPU/RAM acceptable (`scripts\diagnose.ps1`)
- [ ] uninstall.bat restores taskbar, wallpaper, settings
