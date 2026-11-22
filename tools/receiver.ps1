#requires -Version 7.0
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [int]$ParentPid = 0
)
$ErrorActionPreference = 'SilentlyContinue'
$file = Join-Path $Root 'runtime/receiver.txt'
$Host.UI.RawUI.WindowTitle = 'SIGNAL RECEIVER'
$rng = [Random]::new()
$noise = [char[]]@([char]0x2591, [char]0x2592, [char]0x2593, [char]':', [char]0x00B7, [char]' ')
$sw = [Diagnostics.Stopwatch]::StartNew()
[Console]::Write("`e[48;2;8;34;43m`e[2J`e[?25l")
try {
    while ($true) {
        if ($ParentPid -gt 0 -and -not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) { break }
        if ([Console]::KeyAvailable) { $k = [Console]::ReadKey($true); if ($k.Key -in 'Q', 'Escape') { break } }
        $w = [Console]::WindowWidth; $h = [Console]::WindowHeight
        $freq = ''
        if (Test-Path -LiteralPath $file) { $freq = (Get-Content -LiteralPath $file -TotalCount 1).Trim() }
        $show = (($sw.Elapsed.TotalSeconds % 3.0) -lt 1.8)
        $sb = [Text.StringBuilder]::new()
        [void]$sb.Append("`e[H`e[48;2;8;34;43m")
        for ($y = 0; $y -lt $h - 1; $y++) {
            $row = New-Object 'char[]' $w
            for ($x = 0; $x -lt $w; $x++) { $row[$x] = $noise[$rng.Next($noise.Length)] }
            [void]$sb.Append("`e[38;2;46;196;182m").Append((-join $row)).Append("`r`n")
        }
        $mid = [int]($h / 2)
        $label = if ($freq) { "   FREQ  $freq  MHz   " } else { '   ...   ' }
        if (-not $show) { $label = '   ' + ($label.Trim() -replace '\d', '#') + '   ' }
        $x0 = [math]::Max(0, [int](($w - $label.Length) / 2))
        [void]$sb.Append("`e[$($mid + 1);$($x0 + 1)H`e[1m`e[38;2;242;230;208m`e[48;2;8;34;43m$label`e[0m")
        [void]$sb.Append("`e[$($h);1H`e[38;2;60;130;130m`e[48;2;8;34;43m Q / Esc: close   (read the number, then go back to the game)`e[0m")
        [Console]::Write($sb.ToString())
        Start-Sleep -Milliseconds 120
    }
} finally { [Console]::Write("`e[0m`e[?25h`e[2J`e[H") }
