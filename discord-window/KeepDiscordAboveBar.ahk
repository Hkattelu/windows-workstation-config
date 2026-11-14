#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; Only react to an active Discord window that Windows reports as maximized.
; The companion script verifies GlazeWM's state before changing anything.
global lastAttempt := 0
SetTimer(CheckDiscord, 1000)

CheckDiscord() {
    global lastAttempt
    try {
        hwnd := WinActive("ahk_exe Discord.exe")
        if !hwnd || WinGetClass("ahk_id " hwnd) != "Chrome_WidgetWin_1"
            return
        if WinGetMinMax("ahk_id " hwnd) != 1 || A_TickCount - lastAttempt < 5000
            return
        lastAttempt := A_TickCount
        script := A_ScriptDir "\RestoreDiscordBounds.ps1"
        powershell := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
        Run('"' powershell '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' script '" -WindowHandle ' hwnd, , "Hide")
    } catch {
        ; Discord may close while being inspected. Retry on a later timer tick.
    }
}
