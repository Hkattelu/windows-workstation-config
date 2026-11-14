param([Parameter(Mandatory)][long]$WindowHandle)

$ErrorActionPreference = 'Stop'
$cli = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\cli\glazewm.exe'
if (-not (Test-Path -LiteralPath $cli)) { exit 1 }

# Fail closed if GlazeWM isn't available, is paused, or the handle is no
# longer a managed, maximized Discord window.
$paused = (& $cli query paused | ConvertFrom-Json)
if (-not $paused.success -or $paused.data -isnot [bool] -or $paused.data) { exit 0 }
$result = (& $cli query windows | ConvertFrom-Json)
if (-not $result.success) { exit 1 }
$matches = @($result.data.windows | Where-Object {
    $_.handle -eq $WindowHandle -and $_.processName -ieq 'Discord' -and
    $_.state.type -eq 'fullscreen' -and $_.state.maximized -eq $true -and
    $_.hasFocus -eq $true
})
if ($matches.Count -ne 1) { exit 0 }
$target = $matches[0]
$workspaces = (& $cli query workspaces | ConvertFrom-Json)
if (-not $workspaces.success) { exit 1 }
$matches = @($workspaces.data.workspaces | Where-Object { $_.id -eq $target.parentId })
if ($matches.Count -ne 1) { exit 0 }
$workspace = $matches[0]
if ($workspace.width -lt 250 -or $workspace.height -lt 140) { exit 1 }

$change = (& $cli command --id $target.id set-floating --centered=false --shown-on-top=false `
    --x-pos $workspace.x --y-pos $workspace.y --width "$($workspace.width)px" --height "$($workspace.height)px" | ConvertFrom-Json)
if (-not $change.success) { exit 1 }
