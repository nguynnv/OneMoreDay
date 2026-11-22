#requires -Version 7.0
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [int]$ParentPid = 0
)
$ErrorActionPreference = 'SilentlyContinue'
$cmdPath = Join-Path $Root 'runtime/command.txt'
$null = New-Item -ItemType Directory -Force -Path (Split-Path $cmdPath)
$green = "`e[38;2;57;255;20m"; $dim = "`e[38;2;40;140;20m"; $mag = "`e[38;2;255;43;214m"; $off = "`e[0m"
$Host.UI.RawUI.WindowTitle = 'HELPER'
$log = [Collections.Generic.List[string]]::new()

function Send-Command([string]$Word) {
    for ($try = 0; $try -lt 5; $try++) {
        try {
            $fs = [IO.FileStream]::new($cmdPath, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
            $bytes = [Text.Encoding]::ASCII.GetBytes("$Word`n")
            $fs.Write($bytes, 0, $bytes.Length); $fs.Dispose()
            return $true
        } catch { Start-Sleep -Milliseconds 20 }
    }
    return $false
}

function Draw {
    [Console]::Write("`e[2J`e[H`e[?25l")
    [Console]::Write("$green  HELPER  $dim- local command channel$off`r`n`r`n")
    [Console]::Write("$green  Arrows / WASD$off   move Catherine`r`n")
    [Console]::Write("$green  Space$off            attack`r`n")
    [Console]::Write("$green  1$off                UNLOCK doors`r`n")
    [Console]::Write("$green  2$off                PULSE (clear bullets)`r`n")
    [Console]::Write("$green  Q / Esc$off          close`r`n`r`n")
    [Console]::Write("$dim  Keep this window focused while you use it.$off`r`n")
    [Console]::Write("$dim  Writes only to: runtime/command.txt$off`r`n`r`n")
    $start = [math]::Max(0, $log.Count - 8)
    for ($i = $start; $i -lt $log.Count; $i++) { [Console]::Write("$mag  > $($log[$i])$off`r`n") }
}

Draw
try {
    while ($true) {
        if ($ParentPid -gt 0 -and -not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) { break }
        if (-not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 15; continue }
        $k = [Console]::ReadKey($true)
        $word = $null
        switch ($k.Key) {
            { $_ -in 'W', 'UpArrow' }    { $word = 'MOVE_U' }
            { $_ -in 'S', 'DownArrow' }  { $word = 'MOVE_D' }
            { $_ -in 'A', 'LeftArrow' }  { $word = 'MOVE_L' }
            { $_ -in 'D', 'RightArrow' } { $word = 'MOVE_R' }
            'Spacebar' { $word = 'ATTACK' }
            'D1' { $word = 'UNLOCK' } 'NumPad1' { $word = 'UNLOCK' }
            'D2' { $word = 'PULSE' }  'NumPad2' { $word = 'PULSE' }
            { $_ -in 'Q', 'Escape' } { break }
        }
        if ($k.Key -in 'Q', 'Escape') { break }
        if ($word) {
            if (Send-Command $word) { $log.Add($word) } else { $log.Add("$word (failed)") }
            Draw
        }
    }
} finally { [Console]::Write("`e[0m`e[?25h`e[2J`e[H") }
