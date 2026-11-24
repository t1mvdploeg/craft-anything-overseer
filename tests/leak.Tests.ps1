# Fails on private paths in any tracked or untracked-not-ignored file; with env CAO_PRIVATE_TERMS (a file, one term per line) also on those terms.
Describe 'leak scan' {
    It 'finds no private paths or terms in the repo' {
        . "$PSScriptRoot\leak-scan.ps1"
        $root = (Resolve-Path "$PSScriptRoot\..").Path
        $files = @(git -C $root ls-files --cached --others --exclude-standard) |
            Where-Object { $_ -and $_ -ne 'tests/leak.Tests.ps1' -and $_ -ne 'tests/leak-scan.ps1' }
        $hits = Find-Leaks -Files $files -Root $root -TermsFile $env:CAO_PRIVATE_TERMS
        ($hits -join "`n") | Should Be ''
    }
    It 'detects a planted path and passes once it is removed' {
        . "$PSScriptRoot\leak-scan.ps1"
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("leak-" + [guid]::NewGuid())
        New-Item -ItemType Directory $tmp | Out-Null
        try {
            Set-Content -Path "$tmp\a.txt" -Value ('see C:' + '\Users\x\file')
            @(Find-Leaks -Files @('a.txt') -Root $tmp).Count | Should Be 1
            Remove-Item "$tmp\a.txt"
            @(Find-Leaks -Files @('a.txt') -Root $tmp).Count | Should Be 0
        } finally { Remove-Item $tmp -Recurse -Force }
    }
    It 'detects a private term case-insensitively' {
        . "$PSScriptRoot\leak-scan.ps1"
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("leak-" + [guid]::NewGuid())
        New-Item -ItemType Directory $tmp | Out-Null
        try {
            Set-Content -Path "$tmp\a.txt" -Value 'hello SeCrEt'
            Set-Content -Path "$tmp\terms.txt" -Value 'secret'
            @(Find-Leaks -Files @('a.txt') -Root $tmp -TermsFile "$tmp\terms.txt").Count | Should Be 1
        } finally { Remove-Item $tmp -Recurse -Force }
    }
}

Describe 'example settings' {
    It 'is valid JSON' {
        $f = "$PSScriptRoot\..\skills\craft-anything-overseer\craft-overseer.example.json"
        { Get-Content -Raw $f | ConvertFrom-Json } | Should Not Throw
    }
}
