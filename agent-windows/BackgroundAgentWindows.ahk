#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; GlazeWM skips WS_EX_NOACTIVATE windows, including quiet Godot agent runs.
; Lower only explicitly marked, unfocusable Engine windows, without activation.
IsAgentRun(commandLine) {
    normalized := StrReplace(commandLine, "\", "/")
    return InStr(normalized, "--agent-background", false)
        || InStr(normalized, "addons/agent_background/launch.tscn", false)
}

if A_Args.Length && A_Args[1] = "--self-test" {
    cases := [
        ["Godot.exe --editor", false],
        ["Godot.exe --path project --scene res://addons/agent_background/launch.tscn", true],
        ["Godot.exe --path project -- --agent-background", true],
        ["Godot.exe --path project res://main.tscn", false]
    ]
    for item in cases {
        if (!!IsAgentRun(item[1])) != item[2]
            ExitApp 1
    }
    ownPid := DllCall("GetCurrentProcessId", "uint")
    if !InStr(GetProcessCommandLine(ownPid), "--self-test", false)
        ExitApp 2
    ExitApp 0
}

global checkedWindows := Map()
SetTimer(InspectWindows, 1000)
InspectWindows()

InspectWindows() {
    global checkedWindows
    liveWindows := Map()
    for hwnd in WinGetList("ahk_class Engine") {
        try {
            pid := WinGetPID("ahk_id " hwnd)
            liveWindows[hwnd] := pid
            if checkedWindows.Has(hwnd) && checkedWindows[hwnd] = pid
                continue
            if !(WinGetExStyle("ahk_id " hwnd) & 0x08000000)
                continue
            if DllCall("GetForegroundWindow", "ptr") = hwnd
                continue
            commandLine := GetProcessCommandLine(pid)
            if commandLine = ""
                continue
            if IsAgentRun(commandLine) {
                ; HWND_BOTTOM; async, no move, resize, activation or owner reordering.
                ok := DllCall("SetWindowPos", "ptr", hwnd, "ptr", 1,
                    "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x4213, "int")
                if !ok
                    continue
            }
            checkedWindows[hwnd] := pid
        } catch {
            ; A window or process can disappear while being examined. Retry later.
        }
    }
    stale := []
    for hwnd, pid in checkedWindows {
        if !liveWindows.Has(hwnd) || liveWindows[hwnd] != pid
            stale.Push(hwnd)
    }
    for hwnd in stale
        checkedWindows.Delete(hwnd)
}

GetProcessCommandLine(pid) {
    try {
        wmi := ComObjGet("winmgmts:\\.\root\cimv2")
        for process in wmi.ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId=" pid)
            return process.CommandLine
    } catch {
        return ""
    }
    return ""
}
