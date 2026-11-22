function Boss-Attack {
    param($E)
    $pat = $E.Step % 4; $E.Step++
    $a = Get-Aim $E
    switch ($pat) {
        0 {
            foreach ($off in -1, 0, 1) {
                if ($a[0] -ne 0) { Add-LineTele ($E.X + $a[0]) ($E.Y + $off) $a[0] 0 8 2 10 }
                else { Add-LineTele ($E.X + $off) ($E.Y + $a[1]) 0 $a[1] 8 2 10 }
            }
        }
        1 { foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) { Add-LineTele ($E.X + $d[0]) ($E.Y + $d[1]) $d[0] $d[1] 7 2 10 } }
        2 { Add-RainTele $G.PX 5 }
        3 {
            Add-Tele ($E.X + $a[0]) ($E.Y + $a[1]) 8 @{ Dx = $a[0]; Dy = $a[1]; Speed = 3; Homing = $true; Life = 26 }
            Add-Tele $E.X ($E.Y - 1) 14 @{ Dx = 0; Dy = -1; Speed = 3; Homing = $true; Life = 26 }
        }
    }
}

function Update-Boss {
    $e = $G.Boss
    if ($null -eq $e -or -not $e.Alive) { return }
    if ($e.Flash -gt 0) { $e.Flash-- }
    $dist = [math]::Abs($G.PX - $e.X) + [math]::Abs($G.PY - $e.Y)
    if ($G.ChapIdx -eq 6 -and -not $G.DevStarted) { return }
    if ($dist -gt 30) { return }
    $e.Cd--
    if ($e.Cd -le 0) {
        Boss-Attack $e
        $e.Cd = if ($G.ChapIdx -eq 6) { 30 } else { 44 }
    }
}

function Dev-Dodge {
    param($E)
    for ($try = 0; $try -lt 40; $try++) {
        $x = Get-Random -Minimum 2 -Maximum ($G.MW - 2)
        $y = Get-Random -Minimum 2 -Maximum ($G.MH - 2)
        if ((Test-Blocked $x $y) -or ($x -eq $G.PX -and $y -eq $G.PY)) { continue }
        if ([math]::Abs($x - $G.PX) + [math]::Abs($y - $G.PY) -lt 6) { continue }
        $E.X = $x; $E.Y = $y; $E.Flash = 6
        break
    }
}
