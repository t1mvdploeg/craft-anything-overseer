# Fresh Craft Anything conversation: close the app, back up craft.json, null agent_session, restart the app.
# Usage: fresh-session.ps1 -ProjectDir <path> -Label <[a-z0-9-]+> [-WhatIf]
# Dot-source to get Set-AgentSessionNull and Get-AgentSession only.
param(
    [string]$ProjectDir,
    [string]$Label,
    [switch]$WhatIf,
    [object[]]$Processes,     # test hook: fake process list (ProcessId, ParentProcessId, Name, CommandLine)
    [object[]]$AppProcesses,  # test hook: fake craft-anything processes (Path)
    [string]$FallbackExe = (Join-Path $env:ProgramFiles 'Craft Anything\craft-anything.exe')
)
. "$PSScriptRoot\builder.ps1"

function Set-AgentSessionNull([string]$Json) {
    $re = '"agent_session"\s*:\s*("(?:[^"\\]|\\.)*"|null)'
    if ($Json -notmatch $re) { Write-Warning 'agent_session key not found; craft.json unchanged'; return $Json }
    [regex]::Replace($Json, $re, '"agent_session": null')
}

function Get-AgentSession([string]$Json) {
    if ($Json -match '"agent_session"\s*:\s*"((?:[^"\\]|\\.)*)"') { $Matches[1] } else { 'null' }
}

if ($MyInvocation.InvocationName -eq '.') { return }

function Refuse([string]$Why) {
    if ($WhatIf) { Write-Output "REFUSED (whatif): $Why" } else { Write-Output "REFUSED: $Why" }
    exit 4
}

if (-not $ProjectDir -or -not $Label) { Write-Output 'REFUSED: -ProjectDir and -Label are required'; exit 4 }
if ($Label -notmatch '^[a-z0-9-]+$') { Refuse '-Label must match [a-z0-9-]+' }
$craft = Join-Path $ProjectDir 'craft.json'
$bak = "$craft.bak-$Label"
if (-not (Test-Path -LiteralPath $craft)) { Refuse "craft.json missing in $ProjectDir" }
if (Test-Path -LiteralPath $bak) { Refuse "backup already exists: $bak" }

if ($null -eq $Processes) {
    try { $Processes = @(Get-CimInstance Win32_Process -ErrorAction Stop) } catch { Refuse 'cannot list processes' }
}
$n = @(Get-Builders -Processes $Processes -ProjectDir $ProjectDir).Count
if ($n -gt 0) { Refuse "$n builder claude.exe running (a Craft Anything builder)" }

if ($null -eq $AppProcesses) { $AppProcesses = @(Get-Process -Name 'craft-anything' -ErrorAction SilentlyContinue) }
$exe = ($AppProcesses | Where-Object { $_.Path } | Select-Object -First 1).Path
if (-not $exe -and (Test-Path -LiteralPath $FallbackExe)) { $exe = $FallbackExe }
if (-not $exe) { Refuse "craft-anything.exe not found (not running, and not at $FallbackExe)" }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = [IO.File]::ReadAllText($craft, $utf8)
Write-Output "old agent_session: $(Get-AgentSession $text)"
Write-Output "backup -> craft.json.bak-$Label"
Write-Output 'agent_session -> null'
if ($WhatIf) {
    Write-Output "would close craft-anything, write craft.json, start $exe"
    Write-Output 'FRESH OK (whatif)'
    exit 0
}

# 1. Close the app FIRST: it rewrites craft.json while it runs and on exit, which would undo the null.
$AppProcesses | ForEach-Object { [void]$_.CloseMainWindow() }
$deadline = (Get-Date).AddSeconds(15)
while ((Get-Date) -lt $deadline -and (Get-Process -Name 'craft-anything' -ErrorAction SilentlyContinue)) { Start-Sleep -Milliseconds 500 }
Get-Process -Name 'craft-anything' -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Output 'closed craft-anything'

# 2. Only now touch craft.json (re-read: the app may have written it on exit).
$text = [IO.File]::ReadAllText($craft, $utf8)
Write-Output "old agent_session (after close): $(Get-AgentSession $text)"
[IO.File]::WriteAllText($bak, $text, $utf8)
[IO.File]::WriteAllText($craft, (Set-AgentSessionNull $text), $utf8)

# 3. Start the app without the watcher's Claude Code session variables.
Get-ChildItem env: | Where-Object Name -match '^(CLAUDECODE|CLAUDE_CODE_|CLAUDE_PID)' | ForEach-Object { Remove-Item "env:$($_.Name)" }
Start-Process -FilePath $exe
Write-Output "started $exe"
Write-Output 'NOTE: the app may reopen another project (last_project): check the window shows the right project name.'
Write-Output 'FRESH OK'
