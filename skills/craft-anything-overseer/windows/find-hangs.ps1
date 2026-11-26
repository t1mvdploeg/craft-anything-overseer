param([string]$ProjectDir, [int]$MinMinutes = 10, [int]$Kill, [switch]$Count)
. "$PSScriptRoot\builder.ps1"

function Get-Hangs {
    param($Processes, [string]$ProjectDir, [int]$MinMinutes = 10, [datetime]$Now = (Get-Date))
    $Processes = @($Processes)
    # Builder rule: see builder.ps1.
    $queue = [System.Collections.Generic.Queue[object]]::new()
    $byId = @{}; foreach ($p in $Processes) { $byId[[int]$p.ProcessId] = $p }
    Get-Builders -Processes $Processes -ProjectDir $ProjectDir | ForEach-Object { $queue.Enqueue($_.ProcessId) }
    $seen = @{}
    while ($queue.Count) {
        $id = $queue.Dequeue()
        foreach ($c in ($Processes | Where-Object { $_.ParentProcessId -eq $id })) {
            # pid reuse: a real child is never older than its parent
            if ($seen.ContainsKey($c.ProcessId) -or ($byId[[int]$id].CreationDate -and $c.CreationDate -lt $byId[[int]$id].CreationDate)) { continue }
            $seen[$c.ProcessId] = $c
            $queue.Enqueue($c.ProcessId)
        }
    }
    $seen.Values | Where-Object {
        $n = $_.Name.ToLower()
        # the built app itself (a GUI app started to "test" it never exits on its own)
        $isSuspect = $n -in 'find.exe', 'ffmpeg.exe', 'ffprobe.exe' -or ($n -in 'bash.exe', 'sh.exe' -and $_.CommandLine -match 'sleep') -or ($_.ExecutablePath -match '\\target\\(debug|release)\\')
        $isSuspect -and (($Now - $_.CreationDate).TotalMinutes -ge $MinMinutes)
    }
}

function Assert-KillAllowed {
    param([Alias('Pid')][int]$ProcessId, $Suspects)
    if (-not (@($Suspects) | Where-Object { $_.ProcessId -eq $ProcessId })) { throw "REFUSED pid $ProcessId is not a suspect" }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $ProjectDir) { Write-Error 'ProjectDir is required'; exit 2 }
    $now = Get-Date
    if ($Count) { Write-Output "BUILDERS $(Show-Builders $ProjectDir)"; exit 0 }
    $suspects = @(Get-Hangs -Processes (Get-CimInstance Win32_Process) -ProjectDir $ProjectDir -MinMinutes $MinMinutes -Now $now)
    if ($PSBoundParameters.ContainsKey('Kill')) {
        try { Assert-KillAllowed -Pid $Kill -Suspects $suspects } catch { Write-Output $_.Exception.Message; exit 3 }
        Stop-Process -Id $Kill -Force
        Write-Output "KILLED pid $Kill"
        exit 0
    }
    if (-not $suspects) { Write-Output 'NO HANGS'; exit 0 }
    foreach ($s in $suspects) {
        $cmd = "$($s.CommandLine)"; if ($cmd.Length -gt 200) { $cmd = $cmd.Substring(0, 200) }
        Write-Output ("HANG pid={0} age={1}m name={2} cmd={3}" -f $s.ProcessId, [int](($now - $s.CreationDate).TotalMinutes), $s.Name, $cmd)
    }
}
