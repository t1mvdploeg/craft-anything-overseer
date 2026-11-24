# Closes Windows Terminal windows whose title ends with one of the given suffixes (e.g. leftover ffmpeg error windows).
# Usage: close-console-windows.ps1 -TitleSuffix '\ffmpeg.exe','\ffprobe.exe' [-IntervalSeconds 30] [-Once]
param([string[]]$TitleSuffix, [int]$IntervalSeconds = 30, [switch]$Once)

# Under pwsh -File a comma list arrives as ONE string ('a,b'); split it and strip quotes.
function ConvertTo-Suffixes([string[]]$Raw) {
    @($Raw -split ',' | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ })
}
$TitleSuffix = ConvertTo-Suffixes $TitleSuffix

function Test-TitleMatches([string]$Title, [string[]]$Suffixes) {
    foreach ($s in $Suffixes) { if ($Title.EndsWith($s, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

# Dot-sourcing only defines the function; the window code is not even compiled then.
if ($MyInvocation.InvocationName -ne '.') {
    Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class CcW { public delegate bool CB(IntPtr h, IntPtr l);
[DllImport("user32.dll")] static extern bool EnumWindows(CB cb, IntPtr l);
[DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
public static List<KeyValuePair<IntPtr,string>> Terminals(){ var r=new List<KeyValuePair<IntPtr,string>>();
  EnumWindows((h,l)=>{ var c=new StringBuilder(256); GetClassName(h,c,256);
    if(c.ToString()=="CASCADIA_HOSTING_WINDOW_CLASS"){ var t=new StringBuilder(512); GetWindowText(h,t,512); r.Add(new KeyValuePair<IntPtr,string>(h,t.ToString())); }
    return true; }, IntPtr.Zero); return r; } }
"@
    function Close-Matching {
        $n = 0
        foreach ($w in [CcW]::Terminals()) {
            if (Test-TitleMatches $w.Value $TitleSuffix) { [void][CcW]::PostMessage($w.Key, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); $n++ }
        }
        $n
    }
    if ($Once) { "closed $(Close-Matching)"; exit 0 }
    while ($true) { [void](Close-Matching); Start-Sleep $IntervalSeconds }
}
