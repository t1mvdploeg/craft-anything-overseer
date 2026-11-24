. "$PSScriptRoot\..\skills\craft-anything-overseer\windows\builder.ps1"
function P($id, $ppid, $name, $cmd) { [pscustomobject]@{ ProcessId = $id; ParentProcessId = $ppid; Name = $name; CommandLine = $cmd } }
$dir = 'C:\Work\Craft Anything\my-app'
Describe 'Get-Builders' {
    It 'matches claude.exe by project dir in the command line' {
        @(Get-Builders -Processes @((P 1 0 'claude.exe' "claude.exe --add-dir `"$dir`"")) -ProjectDir $dir).Count | Should Be 1
    }
    It 'is case-insensitive, accepts forward slashes and a trailing backslash' {
        $p = @((P 1 0 'claude.exe' 'claude.exe C:/WORK/CRAFT ANYTHING/MY-APP/app'))
        @(Get-Builders -Processes $p -ProjectDir ($dir + '\')).Count | Should Be 1
    }
    It 'does not let my-app match my-app-2' {
        $p = @((P 1 0 'claude.exe' 'claude.exe C:\Work\Craft Anything\my-app-2\app'))
        @(Get-Builders -Processes $p -ProjectDir $dir).Count | Should Be 0
    }
    It 'matches a claude.exe that descends from craft-anything.exe even without the path' {
        $p = @((P 5 0 'craft-anything.exe' 'x'), (P 6 5 'cmd.exe' 'cmd'), (P 7 6 'claude.exe' 'claude -p'))
        @(Get-Builders -Processes $p -ProjectDir $dir).Count | Should Be 1
    }
    It 'ignores a watcher claude.exe that merely mentions Craft Anything' {
        $p = @((P 1 0 'claude.exe' 'claude "watch Craft Anything"'))
        @(Get-Builders -Processes $p -ProjectDir $dir).Count | Should Be 0
    }
    It 'ignores non-claude processes' {
        @(Get-Builders -Processes @((P 5 0 'craft-anything.exe' 'x')) -ProjectDir $dir).Count | Should Be 0
    }
}
