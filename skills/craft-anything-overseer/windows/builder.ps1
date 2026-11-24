# Shared builder rule (library: dot-source it; it has no param block so it cannot clobber the caller).
# Builder = claude.exe that descends from a craft-anything.exe process (ParentProcessId chain),
# OR whose command line contains the normalised project dir (full path, backslashes, no trailing slash,
# case-insensitive, followed by backslash, quote, space or end, so "my-app" does not match "my-app-2").
# CLI use: powershell -Command ". builder.ps1; Show-Builders <dir>"  (prints count; with -Show the cmd line and parent chain)

function Get-ParentChain($Processes, $Proc) {
    $byId = @{}; foreach ($p in $Processes) { $byId[[int]$p.ProcessId] = $p }
    $chain = @(); $cur = $Proc; $guard = 0
    while ($cur -and $guard++ -lt 30) {
        $pp = [int]$cur.ParentProcessId
        if (-not $byId.ContainsKey($pp)) { break }
        $cur = $byId[$pp]; $chain += $cur
    }
    $chain
}

function Get-Builders {
    param($Processes, [string]$ProjectDir)
    $Processes = @($Processes)
    $re = $null
    if ($ProjectDir) { $re = [regex]::Escape($ProjectDir.Replace('/', '\').TrimEnd('\')) + '(?=[\\"\s]|$)' }
    foreach ($p in $Processes) {
        if ($p.Name -ne 'claude.exe') { continue }
        $byPath = $re -and $p.CommandLine -and ($p.CommandLine.Replace('/', '\') -match "(?i)$re")
        $byParent = @(Get-ParentChain $Processes $p | Where-Object { $_.Name -eq 'craft-anything.exe' }).Count -gt 0
        if ($byPath -or $byParent) { $p }
    }
}

function Show-Builders([string]$ProjectDir, [switch]$Show) {
    $all = @(Get-CimInstance Win32_Process)
    $b = @(Get-Builders -Processes $all -ProjectDir $ProjectDir)
    if ($Show) {
        foreach ($p in $b) {
            "builder pid=$($p.ProcessId) cmd=$($p.CommandLine)"
            "  parents: " + ((Get-ParentChain $all $p | ForEach-Object { "$($_.Name)($($_.ProcessId))" }) -join ' <- ')
        }
    }
    $b.Count
}
