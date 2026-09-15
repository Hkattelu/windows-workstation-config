[CmdletBinding()]
param(
    [switch]$InstallApps,
    [switch]$ArchiveDesktopShortcuts,
    [switch]$NoRestart,
    [string]$CodePath = (Join-Path $env:USERPROFILE 'code'),
    [string]$EditingLibraryPath = (Join-Path $env:USERPROFILE 'Videos\Editing')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Backup-File {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.backup-$stamp"
        Copy-Item -LiteralPath $Path -Destination $backup -Force
        Write-Host "Backed up: $backup"
    }
}

function Write-TemplatedFile {
    param(
        [string]$Source,
        [string]$Destination,
        [hashtable]$Replacements = @{}
    )

    $content = [System.IO.File]::ReadAllText($Source)
    foreach ($key in $Replacements.Keys) {
        $content = $content.Replace($key, [string]$Replacements[$key])
    }
    if ($content -match '__[A-Z0-9_]+__') {
        throw "Unresolved placeholder in $Source"
    }

    Ensure-Directory (Split-Path -Parent $Destination)
    Backup-File $Destination
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Destination, $content, $utf8)
    Write-Host "Applied: $Destination"
}

function Resolve-Executable {
    param(
        [string]$CommandName,
        [string[]]$Candidates = @()
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and $command.Source) { return $command.Source }
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function New-PortableShortcut {
    param(
        [string]$Path,
        [string]$Target,
        [string]$Arguments = '',
        [string]$WorkingDirectory = ''
    )

    Ensure-Directory (Split-Path -Parent $Path)
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $Target
    $shortcut.Arguments = $Arguments
    if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
    $shortcut.Save()
    Write-Host "Shortcut: $Path"
}

function Install-WorkstationApps {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $winget) {
        throw 'WinGet is not available. Install App Installer from Microsoft Store, then run this script again.'
    }

    $packages = @(
        'glzr-io.glazewm',
        'AmN.yasb',
        'Microsoft.PowerToys',
        'AutoHotkey.AutoHotkey',
        'OneCommander'
    )

    foreach ($package in $packages) {
        Write-Host "Installing/updating $package ..."
        & $winget.Source install --id $package --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "WinGet did not complete $package. Continue after installing it manually if needed."
        }
    }
}

function Archive-VisibleDesktopShortcuts {
    $desktopPaths = @([Environment]::GetFolderPath('Desktop'))
    if ($env:OneDrive) { $desktopPaths += (Join-Path $env:OneDrive 'Desktop') }
    $desktopPaths = $desktopPaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    $archiveRoot = Join-Path $env:USERPROFILE ".desktop-shortcut-archive\$stamp"
    $moved = 0

    foreach ($desktop in $desktopPaths) {
        $shortcuts = Get-ChildItem -LiteralPath $desktop -Force -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.lnk', '.url' }
        foreach ($shortcut in $shortcuts) {
            Ensure-Directory $archiveRoot
            $destination = Join-Path $archiveRoot $shortcut.Name
            if (Test-Path -LiteralPath $destination) {
                $destination = Join-Path $archiveRoot ("{0}-{1}{2}" -f $shortcut.BaseName, $moved, $shortcut.Extension)
            }
            Move-Item -LiteralPath $shortcut.FullName -Destination $destination
            $moved++
        }
    }

    if ($moved) {
        Write-Host "Archived $moved desktop shortcuts to $archiveRoot"
    } else {
        Write-Host 'No visible desktop shortcuts found.'
    }
}

if ($InstallApps) {
    Write-Step 'Installing workstation apps'
    Install-WorkstationApps
}

$yasbc = Resolve-Executable 'yasbc.exe' @(
    (Join-Path $env:LOCALAPPDATA 'Programs\YASB\yasbc.exe'),
    (Join-Path $env:ProgramFiles 'YASB\yasbc.exe')
)
$glazewm = Resolve-Executable 'glazewm.exe' @(
    (Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\glazewm.exe')
)
$oneCommander = Resolve-Executable 'OneCommander.exe' @(
    (Join-Path $env:ProgramFiles 'OneCommander\OneCommander.exe')
)
$powerToys = Resolve-Executable 'PowerToys.exe' @(
    (Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe'),
    (Join-Path $env:LOCALAPPDATA 'PowerToys\PowerToys.exe')
)
$autoHotkey = Resolve-Executable 'AutoHotkey64.exe' @(
    (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe'),
    (Join-Path $env:LOCALAPPDATA 'Minimal Desktop\WindowsKeyLauncher\Runtime\AutoHotkey64.exe')
)

$codex = Resolve-Executable 'codex.exe'
if (-not $codex) {
    $codexRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $codexRoot) {
        $codex = Get-ChildItem -LiteralPath $codexRoot -Filter codex.exe -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $codex) {
    $codex = 'codex'
    Write-Warning 'Codex CLI was not found. The usage widget will show -- until Codex is installed and signed in.'
}

$yasbcTemplateValue = if ($yasbc) { $yasbc.Replace('\', '/') } else { 'yasbc.exe' }
$codexTemplateValue = $codex.Replace('\', '/')

Write-Step 'Applying YASB and GlazeWM'
$yasbConfigDir = Join-Path $env:USERPROFILE '.config\yasb'
$glazeConfigDir = Join-Path $env:USERPROFILE '.glzr\glazewm'
$yasbConfig = Join-Path $yasbConfigDir 'config.yaml'
$glazeConfig = Join-Path $glazeConfigDir 'config.yaml'

Write-TemplatedFile (Join-Path $repoRoot 'yasb\config.yaml') $yasbConfig @{
    '__CODEX_CLI__' = $codexTemplateValue
}
Write-TemplatedFile (Join-Path $repoRoot 'yasb\styles.css') (Join-Path $yasbConfigDir 'styles.css')
Write-TemplatedFile (Join-Path $repoRoot 'glazewm\config.yaml') $glazeConfig @{
    '__YASBC__' = $yasbcTemplateValue
}

Write-Step 'Applying OneCommander preferences'
$oneCommanderSettings = Join-Path $env:LOCALAPPDATA 'OneCommander\Settings\OneCommanderV3.json'
$oneCommanderWasRunning = [bool](Get-Process -Name OneCommander -ErrorAction SilentlyContinue)
if ($oneCommanderWasRunning) {
    Stop-Process -Name OneCommander -Force
    Start-Sleep -Milliseconds 500
}
Write-TemplatedFile (Join-Path $repoRoot 'onecommander\OneCommanderV3.portable.json') $oneCommanderSettings @{
    '__COMPUTERNAME__' = $env:COMPUTERNAME
}

Write-Step 'Applying PowerToys and Command Palette preferences'
$powerToysWasRunning = [bool](Get-Process -Name PowerToys -ErrorAction SilentlyContinue)
Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -like 'PowerToys*' -or $_.ProcessName -like '*CommandPalette*' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

Write-TemplatedFile (Join-Path $repoRoot 'powertoys\settings.json') (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\settings.json')
$commandPaletteState = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.CommandPalette_8wekyb3d8bbwe\LocalState\settings.json'
Write-TemplatedFile (Join-Path $repoRoot 'powertoys\command-palette\settings.json') $commandPaletteState

$launcherDir = Join-Path $env:LOCALAPPDATA 'Minimal Desktop\WindowsKeyLauncher'
$launcherScript = Join-Path $launcherDir 'WindowsKeyLauncher.ahk'
Write-TemplatedFile (Join-Path $repoRoot 'powertoys\windows-key-launcher\WindowsKeyLauncher.ahk') $launcherScript

Write-Step 'Creating Startup and Start menu shortcuts'
$startup = [Environment]::GetFolderPath('Startup')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Minimal Desktop'

if ($glazewm) {
    New-PortableShortcut (Join-Path $startup 'GlazeWM.lnk') $glazewm "start --config=`"$glazeConfig`"" (Split-Path -Parent $glazewm)
    New-PortableShortcut (Join-Path $startMenu 'Start minimal desktop.lnk') $glazewm 'start' (Split-Path -Parent $glazewm)
    New-PortableShortcut (Join-Path $startMenu 'Stop minimal desktop.lnk') $glazewm 'command wm-exit' (Split-Path -Parent $glazewm)
} else {
    Write-Warning 'GlazeWM was not found; its shortcuts were not created.'
}

if ($oneCommander) {
    Ensure-Directory $CodePath
    Ensure-Directory $EditingLibraryPath
    New-PortableShortcut (Join-Path $startup 'OneCommander.lnk') $oneCommander "`"$EditingLibraryPath`"" (Split-Path -Parent $oneCommander)
    New-PortableShortcut (Join-Path $startMenu 'OneCommander - Code.lnk') $oneCommander "`"$CodePath`"" (Split-Path -Parent $oneCommander)
    New-PortableShortcut (Join-Path $startMenu 'OneCommander - Editing Library.lnk') $oneCommander "`"$EditingLibraryPath`"" (Split-Path -Parent $oneCommander)
} else {
    Write-Warning 'OneCommander was not found; its shortcuts were not created.'
}

if ($autoHotkey) {
    New-PortableShortcut (Join-Path $startup 'Windows key - Command Palette.lnk') $autoHotkey "`"$launcherScript`"" $launcherDir
} else {
    Write-Warning 'AutoHotkey v2 was not found; the Windows-key Command Palette shortcut was not created.'
}

if ($ArchiveDesktopShortcuts) {
    Write-Step 'Archiving visible desktop shortcuts'
    Archive-VisibleDesktopShortcuts
}

if (-not $NoRestart) {
    Write-Step 'Reloading the desktop tools'
    if ($powerToysWasRunning -and $powerToys) {
        Start-Process -FilePath $powerToys -WindowStyle Hidden
    }
    if ($oneCommanderWasRunning -and $oneCommander) {
        Start-Process -FilePath $oneCommander -ArgumentList "`"$EditingLibraryPath`""
    }
    if ($yasbc) {
        & $yasbc reload --silent
        if ($LASTEXITCODE -ne 0) { & $yasbc start --silent }
    }
    if ($glazewm) {
        if (Get-Process -Name glazewm -ErrorAction SilentlyContinue) {
            & $glazewm command wm-reload-config
        } else {
            Start-Process -FilePath $glazewm -ArgumentList @('start', "--config=`"$glazeConfig`"") -WindowStyle Hidden
        }
    }
}

Write-Step 'Done'
Write-Host 'No desktop shortcuts were created. Existing files were backed up beside their originals.' -ForegroundColor Green
Write-Host 'If Codex usage shows --, open Codex once, sign in, and middle-click the CODEX widget.'
