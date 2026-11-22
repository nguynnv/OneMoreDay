function Get-Aim {
    param($E)
    $dx = $G.PX - $E.X; $dy = $G.PY - $E.Y
    if ([math]::Abs($dx) -ge [math]::Abs($dy)) { return @([math]::Max(-1, [math]::Min(1, $dx)), 0) }
    return @(0, [math]::Max(-1, [math]::Min(1, $dy)))
}

function Enemy-Attack {
    param($E)
    switch ($E.Type) {
        '1' { $a = Get-Aim $E; if ($a[0] -ne 0 -or $a[1] -ne 0) { Add-LineTele ($E.X + $a[0]) ($E.Y + $a[1]) $a[0] $a[1] 6 2 10 } }
        '2' { foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) { Add-LineTele ($E.X + $d[0]) ($E.Y + $d[1]) $d[0] $d[1] 4 2 10 } }
        '3' { Add-RainTele $G.PX 3 }
        '4' { $a = Get-Aim $E; Add-Tele ($E.X + $a[0]) ($E.Y + $a[1]) 8 @{ Dx = $a[0]; Dy = $a[1]; Speed = 3; Homing = $true; Life = 22 } }
    }
}

function Add-RainTele {
    param([int]$Cx, [int]$Count = 3)
    $y0 = [math]::Max(1, $G.PY - 6)
    $offs = if ($Count -ge 5) { @(-4, -2, 0, 2, 4) } else { @(-2, 0, 2) }
    foreach ($o in $offs) {
        $x = $Cx + $o
        $yy = $y0
        while ($yy -lt $G.PY -and (Test-Wall $x $yy)) { $yy++ }
        if (Test-Wall $x $yy) { continue }
        Add-Tele $x $yy 10 @{ Dx = 0; Dy = 1; Speed = 2; Homing = $false; Life = 18 }
        for ($k = 1; $k -lt 7; $k++) { if (-not (Test-Wall $x ($yy + $k))) { Add-Tele $x ($yy + $k) 10 $null } }
    }
}

function Update-Enemies {
    foreach ($e in $G.Enemies) {
        if (-not $e.Alive) { continue }
        if ($e.Flash -gt 0) { $e.Flash-- }
        if ($e.Boss) { continue }
        $e.Cd--
        $dist = [math]::Abs($G.PX - $e.X) + [math]::Abs($G.PY - $e.Y)
        if ($dist -gt 18) { continue }
        if ($e.Type -eq '4') {
            $e.Move++
            if ($e.Move -ge 8 -and $dist -gt 4) {
                $e.Move = 0
                $a = Get-Aim $e
                if (-not (Test-Blocked ($e.X + $a[0]) ($e.Y + $a[1])) -and -not (($e.X + $a[0]) -eq $G.PX -and ($e.Y + $a[1]) -eq $G.PY)) { $e.X += $a[0]; $e.Y += $a[1] }
            }
        }
        if ($e.Cd -le 0) {
            Enemy-Attack $e
            $e.Cd = switch ($e.Type) { '1' { 36 } '2' { 50 } '3' { 56 } default { 70 } }
        }
    }
}

function Spawn-Enemy {
    if ($G.Spawns.Count -eq 0) { return }
    $sp = $G.Spawns[(Get-Random -Maximum $G.Spawns.Count)]
    if ([math]::Abs($sp[0] - $G.PX) + [math]::Abs($sp[1] - $G.PY) -lt 6) { return }
    if (Test-Blocked $sp[0] $sp[1]) { return }
    $t = if ((Get-Random -Maximum 2) -eq 0) { '1' } else { '4' }
    [void]$G.Enemies.Add(@{ Type = $t; X = $sp[0]; Y = $sp[1]; Hp = 2; MaxHp = 2; Cd = 30; Alive = $true; Flash = 0; Step = 0; Boss = $false; IsDev = $false; Move = 0 })
}
