# Real Bizarre Windows workstation

A portable version of the current desktop: GlazeWM work modes, a custom YASB taskbar, OneCommander’s dark dual-pane preferences, PowerToys Command Palette, and the tap-the-Windows-key launcher.

The repository contains configuration only. It deliberately excludes credentials, Codex authentication, recent commands, file-manager favorites and tabs, thumbnails, logs, databases, and application binaries.

## What this sets up

| Workspace | Purpose | Automatically routed apps |
| --- | --- | --- |
| `1 GAME` | game development and build testing | Godot, ChatGPT, Death by Deadline windows |
| `2 VIDEO` | editing, recording, and encoding | DaVinci Resolve, OBS, HandBrake, Shutter Encoder |
| `3 CREATE` | art, 3D, and audio | Krita, Blender, FL Studio, Audacity, REAPER, Inkscape, Lively |
| `4 BIZ` | planning and studio operations | Linear, Notion, Slack, Discord, Zoom |

Workspace shortcuts use left Alt so right Alt/AltGr remains available:

- `Alt+Shift+1–4`: switch workspaces
- `Ctrl+Alt+Shift+1–4`: move the focused window and follow it
- `Alt+Shift+Space`: float/tile a window
- `Alt+Shift+F`: fullscreen
- `Alt+Shift+P`: pause tiling
- `Alt+Shift+R`: reload GlazeWM

The YASB bar replaces the visible Windows taskbar. Its two workflow widgets are:

- `CODEX`: remaining allowance at a glance. Left-click opens details, middle-click refreshes, and right-click switches limit windows.
- `FOCUS`: Windows Do Not Disturb. Left-click toggles it, middle-click reveals the state name, and right-click cycles Off → Priority → Alarms.

## Put it on another Windows PC

Clone the private repository, open PowerShell in it, and run:

```powershell
gh repo clone Hkattelu/windows-workstation-config
Set-Location windows-workstation-config
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1 -InstallApps -ArchiveDesktopShortcuts
```

`-InstallApps` installs or updates GlazeWM, YASB, PowerToys, AutoHotkey v2, and OneCommander with WinGet. Omit it if they are already installed.

`-ArchiveDesktopShortcuts` moves `.lnk` and `.url` files from your personal Desktop into a dated folder under `~\.desktop-shortcut-archive`. It is recoverable and never touches ordinary desktop files. The setup creates only Startup and Start menu shortcuts—never desktop shortcuts.

Useful optional parameters:

```powershell
.\setup.ps1 -CodePath D:\Code -EditingLibraryPath D:\Video\Editing
.\setup.ps1 -NoRestart
```

The script backs up every overwritten settings file beside the original, resolves installed application paths for the current account, replaces machine-specific placeholders, and recreates the startup launchers.

## Codex widget requirement

The Codex widget uses the installed Codex CLI and its existing ChatGPT login. No authentication file is stored here. If the widget displays `--` on the laptop, install/open Codex, sign in once, then middle-click the widget to refresh.

## What is intentionally not copied

- `~\.codex` and all authentication material
- OneCommander Favorites, Tabs, folder-view and thumbnail databases
- Command Palette `state.json` and recent-command history
- AutoHotkey binaries or any other installers
- Monitor coordinates and window positions
- logs, caches, crash dumps, or license data

## Layout

```text
glazewm/                         workspace and routing rules
onecommander/                    sanitized portable preferences
powertoys/settings.json          enabled/disabled PowerToys modules
powertoys/command-palette/       palette preferences and aliases
powertoys/windows-key-launcher/  Windows-key tap helper
yasb/                            bar layout, widgets, and theme
setup.ps1                        idempotent laptop installer
```
