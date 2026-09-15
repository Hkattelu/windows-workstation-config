#Requires AutoHotkey v2.0
#SingleInstance Force

; A tap of either Windows key opens PowerToys Command Palette.
; Windows-key chords pass through, including Windows+E and Windows+L.
; Stop this helper from its tray menu to restore the normal Windows-key tap.
if A_Args.Length && A_Args[1] = "--check"
    ExitApp 0

A_IconTip := "Windows key - Command Palette"
A_MenuMaskKey := "vkE8"
InstallMouseHook ; Include mouse clicks when deciding whether Win was used alone.
WinPresses := Map()

~*LWin::BeginWinTap("LWin")
~*RWin::BeginWinTap("RWin")
~*LWin Up::EndWinTap("LWin", A_PriorKey)
~*RWin Up::EndWinTap("RWin", A_PriorKey)

BeginWinTap(key) {
    global WinPresses
    if !WinPresses.Has(key) {
        WinPresses[key] := {
            Started: A_TickCount,
            Eligible: !OtherModifiersDown(key)
        }
    }
    ; AutoHotkey's documented menu-mask technique keeps native Win chords
    ; available while preventing the Start menu on an otherwise bare release.
    Send "{Blind}{vkE8}"
}

EndWinTap(key, priorKey) {
    global WinPresses
    if !WinPresses.Has(key)
        return
    press := WinPresses[key]
    WinPresses.Delete(key)
    ; Long holds are excluded so releasing the Shortcut Guide does not launch.
    if press.Eligible && priorKey = key
        && A_TickCount - press.Started < 700 && !OtherModifiersDown(key) {
        ; Keep PowerToys' existing activation shortcut and fullscreen behavior.
        Send "#!{Space}"
    }
}

OtherModifiersDown(key) {
    return GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P")
        || GetKeyState("Shift", "P")
        || GetKeyState(key = "LWin" ? "RWin" : "LWin", "P")
}
