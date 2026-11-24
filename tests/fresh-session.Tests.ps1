$script = Join-Path $PSScriptRoot '..\skills\craft-anything-overseer\windows\fresh-session.ps1'
. $script

Describe 'Set-AgentSessionNull' {
    It 'nulls a string value, rest identical' {
        Set-AgentSessionNull '{"a":1,"agent_session": "c95-x","b":2}' | Should Be '{"a":1,"agent_session": null,"b":2}'
    }
    It 'leaves null unchanged' {
        $j = '{"a":1,"agent_session": null}'
        Set-AgentSessionNull $j | Should Be $j
    }
    It 'leaves missing key unchanged' {
        $j = '{"a":1}'
        Set-AgentSessionNull $j 3>$null | Should Be $j
    }
}

Describe 'Get-AgentSession' {
    It 'returns the id, or null' {
        Get-AgentSession '{"agent_session": "abc-1"}' | Should Be 'abc-1'
        Get-AgentSession '{"agent_session": null}' | Should Be 'null'
    }
}

Describe 'fresh-session.ps1 run' {
    $dir = Join-Path $TestDrive 'Craft Anything\p one'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $craft = Join-Path $dir 'craft.json'
    Set-Content $craft '{"agent_session": "abc"}'
    $fakeExe = Join-Path $TestDrive 'craft-anything.exe'
    Set-Content $fakeExe 'x'
    $app = @([pscustomobject]@{ Path = $fakeExe })
    $none = @()
    $running = @(
        [pscustomobject]@{ ProcessId = 5; ParentProcessId = 0; Name = 'craft-anything.exe'; CommandLine = 'x' },
        [pscustomobject]@{ ProcessId = 6; ParentProcessId = 5; Name = 'claude.exe'; CommandLine = 'claude -p' })
    It '-WhatIf changes no file and prints the old id' {
        $h = (Get-FileHash $craft).Hash
        $out = & $script -ProjectDir $dir -Label t1 -WhatIf -Processes $none -AppProcesses $app
        ($out -join "`n") | Should Match 'FRESH OK \(whatif\)'
        ($out -join "`n") | Should Match 'old agent_session: abc'
        (Get-FileHash $craft).Hash | Should Be $h
        Test-Path "$craft.bak-t1" | Should Be $false
    }
    It 'refuses when a builder runs (descendant of craft-anything.exe)' {
        $out = & $script -ProjectDir $dir -Label t2 -Processes $running -AppProcesses $app
        ($out -join "`n") | Should Match 'REFUSED'
        $LASTEXITCODE | Should Be 4
    }
    It 'does not refuse for a watcher session that mentions Craft Anything' {
        $fake = @([pscustomobject]@{ ProcessId = 6; ParentProcessId = 0; Name = 'claude.exe'; CommandLine = 'claude "watch Craft Anything"' })
        $out = & $script -ProjectDir $dir -Label t2b -WhatIf -Processes $fake -AppProcesses $app
        ($out -join "`n") | Should Match 'FRESH OK \(whatif\)'
    }
    It '-WhatIf says REFUSED (whatif) when it would refuse' {
        $out = & $script -ProjectDir $dir -Label t2c -WhatIf -Processes $running -AppProcesses $app
        ($out -join "`n") | Should Match 'REFUSED \(whatif\)'
        ($out -join "`n") | Should Not Match 'FRESH OK'
    }
    It 'refuses when no craft-anything.exe is found anywhere (craft.json untouched)' {
        $h = (Get-FileHash $craft).Hash
        $out = & $script -ProjectDir $dir -Label t5 -Processes $none -AppProcesses @() -FallbackExe (Join-Path $TestDrive 'missing.exe')
        ($out -join "`n") | Should Match 'REFUSED: craft-anything.exe not found'
        (Get-FileHash $craft).Hash | Should Be $h
    }
    It 'uses the fallback exe when the app is not running' {
        $out = & $script -ProjectDir $dir -Label t6 -WhatIf -Processes $none -AppProcesses @() -FallbackExe $fakeExe
        ($out -join "`n") | Should Match 'FRESH OK \(whatif\)'
    }
    It 'refuses when backup exists' {
        Set-Content "$craft.bak-t3" 'x'
        $out = & $script -ProjectDir $dir -Label t3 -Processes $none -AppProcesses $app
        ($out -join "`n") | Should Match 'REFUSED: backup'
    }
    It 'refuses when craft.json missing' {
        $out = & $script -ProjectDir (Join-Path $TestDrive 'nope') -Label t4 -Processes $none -AppProcesses $app
        ($out -join "`n") | Should Match 'REFUSED: craft.json'
    }
    It 'closes the app BEFORE it writes craft.json (C2)' {
        $src = Get-Content $script -Raw
        $close = $src.IndexOf('CloseMainWindow')
        $write = $src.IndexOf('WriteAllText($craft')
        ($close -gt 0 -and $write -gt $close) | Should Be $true
    }
}
