. "$PSScriptRoot\..\skills\craft-anything-overseer\windows\find-hangs.ps1"
$now = [datetime]'2026-11-24 12:00:00'
$dir = 'C:\fix ture\proj'
function P($id, $ppid, $name, $cmd, $ageMin) {
    [pscustomobject]@{ ProcessId = $id; ParentProcessId = $ppid; Name = $name; CommandLine = $cmd; CreationDate = $now.AddMinutes(-$ageMin) }
}
function Tree($leafName, $leafCmd, $leafAge, $builderDir = $dir) {
    @(
        (P 10 1 'claude.exe' "C:\x\claude.exe --add-dir `"$builderDir`"" 120),
        (P 11 10 'bash.exe' 'bash -c run' 120),
        (P 12 11 $leafName $leafCmd $leafAge)
    )
}
Describe 'Get-Hangs' {
    It 'reports an old find.exe under the builder (path with a space)' {
        $r = @(Get-Hangs -Processes (Tree 'find.exe' 'find / -name x' 30) -ProjectDir $dir -MinMinutes 10 -Now $now)
        $r.Count | Should Be 1
        $r[0].ProcessId | Should Be 12
    }
    It 'ignores a young find.exe' {
        @(Get-Hangs -Processes (Tree 'find.exe' 'find / -name x' 3) -ProjectDir $dir -MinMinutes 10 -Now $now).Count | Should Be 0
    }
    It 'reports ffmpeg with tpad stop=-1' {
        $r = @(Get-Hangs -Processes (Tree 'ffmpeg.exe' 'ffmpeg -vf tpad=stop=-1 x.mp4' 15) -ProjectDir $dir -MinMinutes 10 -Now $now)
        $r.Count | Should Be 1
    }
    It 'reports a sleep loop in bash' {
        $r = @(Get-Hangs -Processes (Tree 'bash.exe' 'bash -c "until [ -f x ]; do sleep 5; done"' 25) -ProjectDir $dir -MinMinutes 10 -Now $now)
        $r.Count | Should Be 1
    }
    It 'ignores a bash without sleep' {
        @(Get-Hangs -Processes (Tree 'bash.exe' 'bash -c ls' 25) -ProjectDir $dir -MinMinutes 10 -Now $now).Count | Should Be 0
    }
    It 'ignores find.exe under another project builder' {
        @(Get-Hangs -Processes (Tree 'find.exe' 'find / -name x' 30 'C:\other\proj') -ProjectDir $dir -MinMinutes 10 -Now $now).Count | Should Be 0
    }
}
Describe 'Assert-KillAllowed' {
    It 'throws for a non-suspect pid' {
        $s = @(Get-Hangs -Processes (Tree 'find.exe' 'find /' 30) -ProjectDir $dir -MinMinutes 10 -Now $now)
        # Pester 3.4 'Should Throw' is broken on pwsh 7.6, so catch by hand.
        $msg = try { Assert-KillAllowed -Pid 99 -Suspects $s; '' } catch { $_.Exception.Message }
        $msg | Should Match 'REFUSED pid 99'
    }
    It 'allows a suspect pid' {
        $s = @(Get-Hangs -Processes (Tree 'find.exe' 'find /' 30) -ProjectDir $dir -MinMinutes 10 -Now $now)
        $msg = try { Assert-KillAllowed -Pid 12 -Suspects $s; '' } catch { $_.Exception.Message }
        $msg | Should Be ''
    }
}
Describe 'Get-Hangs builder by parent chain' {
    It 'finds a hang under a claude.exe started by craft-anything.exe (no path in command line)' {
        $t = @(
            (P 5 1 'craft-anything.exe' 'x' 200),
            (P 10 5 'claude.exe' 'claude -p' 120),
            (P 11 10 'bash.exe' 'bash -c run' 120),
            (P 12 11 'find.exe' 'find /' 30)
        )
        @(Get-Hangs -Processes $t -ProjectDir 'C:\nowhere' -MinMinutes 10 -Now $now).Count | Should Be 1
    }
    It 'adopts no child older than its parent (pid reuse)' {
        $t = @((P 10 1 'claude.exe' "claude --add-dir `"$dir`"" 5), (P 12 10 'find.exe' 'find /' 60))
        @(Get-Hangs -Processes $t -ProjectDir $dir -MinMinutes 10 -Now $now).Count | Should Be 0
    }
}
