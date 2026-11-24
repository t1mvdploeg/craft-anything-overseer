. "$PSScriptRoot\..\skills\craft-anything-overseer\windows\close-console-windows.ps1" -TitleSuffix 'x'

Describe 'Test-TitleMatches' {
    $s = @('\ffmpeg.exe', '\ffprobe.exe')
    It 'matches a title ending in a suffix' { Test-TitleMatches 'C:\x\ffmpeg.exe' $s | Should Be $true }
    It 'does not match when the suffix is not at the end' { Test-TitleMatches 'ffmpeg.exe - notes.txt' $s | Should Be $false }
    It 'is case-insensitive' { Test-TitleMatches 'C:\x\FFMPEG.EXE' $s | Should Be $true }
}
Describe 'ConvertTo-Suffixes' {
    It 'splits the single comma string that pwsh -File produces' {
        $r = @(ConvertTo-Suffixes '\ffmpeg.exe,\ffprobe.exe')
        $r.Count | Should Be 2
        $r[1] | Should Be '\ffprobe.exe'
    }
    It 'keeps a proper array and strips quotes' {
        @(ConvertTo-Suffixes @("'\a'", '\b')).Count | Should Be 2
    }
}
Describe 'ConvertTo-Suffixes' {
    It 'splits the single comma string that pwsh -File produces' {
        $r = @(ConvertTo-Suffixes '\ffmpeg.exe,\ffprobe.exe')
        $r.Count | Should Be 2
        $r[1] | Should Be '\ffprobe.exe'
    }
    It 'keeps a proper array and strips quotes' {
        @(ConvertTo-Suffixes @("'\a'", '\b')).Count | Should Be 2
    }
}
