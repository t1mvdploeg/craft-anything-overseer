# Scans files for private paths and, optionally, private terms (one per line in $TermsFile, case-insensitive).
function Find-Leaks {
    param([string[]]$Files, [string]$Root, [string]$TermsFile)
    $patterns = @('[A-Z]:\\Users\\', '[A-Z]:/Users/', '/c/Users/', '/Users/[a-z]', '/home/[a-z]')
    if ($TermsFile -and -not (Test-Path $TermsFile)) { throw "terms file not found: $TermsFile" }
    $terms = @()
    if ($TermsFile -and (Test-Path $TermsFile)) {
        $terms = @(Get-Content $TermsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    $hits = @()
    foreach ($f in $Files) {
        $p = Join-Path $Root $f
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($p)
        if ($bytes -contains 0) { continue } # binary
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        foreach ($re in $patterns) { if ($text -imatch $re) { $hits += "${f}: path pattern $re" } }
        foreach ($t in $terms) { if ($text.IndexOf($t, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits += "${f}: private term" } }
    }
    $hits
}
