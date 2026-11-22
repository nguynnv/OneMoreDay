function Add-Bullet {
    param([int]$X, [int]$Y, [int]$Dx, [int]$Dy, [int]$Speed = 2, [string]$Owner = 'e', [bool]$Homing = $false, [int]$Life = 40, [string]$Src = 'cmd')
    [void]$G.Bullets.Add(@{ X = $X; Y = $Y; Dx = $Dx; Dy = $Dy; Speed = $Speed; T = 0; Owner = $Owner; Homing = $Homing; Life = $Life; Src = $Src })
}

function Add-Tele {
    param([int]$X, [int]$Y, [int]$Left, $Payload = $null)
    if (Test-Wall $X $Y) { return }
    [void]$G.Tele.Add(@{ X = $X; Y = $Y; Left = $Left; Payload = $Payload })
}

function Add-LineTele {
    param([int]$Sx, [int]$Sy, [int]$Dx, [int]$Dy, [int]$Len = 5, [int]$Speed = 2, [int]$Left = 10, [int]$Life = 40)
    if (Test-Wall $Sx $Sy) { return }
    Add-Tele $Sx $Sy $Left @{ Dx = $Dx; Dy = $Dy; Speed = $Speed; Homing = $false; Life = $Life }
    for ($i = 1; $i -lt $Len; $i++) {
        $cx = $Sx + $Dx * $i; $cy = $Sy + $Dy * $i
        if (Test-Wall $cx $cy) { break }
        Add-Tele $cx $cy $Left $null
    }
}

function Update-Telegraphs {
    for ($i = $G.Tele.Count - 1; $i -ge 0; $i--) {
        $t = $G.Tele[$i]
        $t.Left--
        if ($t.Left -le 0) {
            if ($null -ne $t.Payload) {
                $p = $t.Payload
                Add-Bullet $t.X $t.Y $p.Dx $p.Dy $p.Speed 'e' $p.Homing $p.Life 'cmd'
                if ($t.X -eq $G.PX -and $t.Y -eq $G.PY) { Hit-Player }
            }
            $G.Tele.RemoveAt($i)
        }
    }
}

function Update-Bullets {
    for ($i = $G.Bullets.Count - 1; $i -ge 0; $i--) {
        $b = $G.Bullets[$i]
        $b.T++
        if ($b.T -lt $b.Speed) { continue }
        $b.T = 0; $b.Life--
        if ($b.Homing) {
            $ddx = $G.PX - $b.X; $ddy = $G.PY - $b.Y
            if ([math]::Abs($ddx) -ge [math]::Abs($ddy)) { $b.Dx = [math]::Sign($ddx); $b.Dy = 0 } else { $b.Dx = 0; $b.Dy = [math]::Sign($ddy) }
        }
        $nx = $b.X + $b.Dx; $ny = $b.Y + $b.Dy
        if (Test-Wall $nx $ny) { $G.Bullets.RemoveAt($i); continue }
        if ($b.Owner -eq 'p') {
            $e = Get-EnemyAt $nx $ny
            if ($null -ne $e) { Damage-Enemy $e 1 $b.Src; $G.Bullets.RemoveAt($i); continue }
        } else {
            if ($nx -eq $G.PX -and $ny -eq $G.PY) { Hit-Player; $G.Bullets.RemoveAt($i); continue }
        }
        $b.X = $nx; $b.Y = $ny
        if ($b.Life -le 0) { $G.Bullets.RemoveAt($i) }
    }
    if ($G.Inv -gt 0) { $G.Inv-- }
    if ($G.Cd -gt 0) { $G.Cd-- }
}

function Fire-Player {
    param([string]$Src = 'phys', [switch]$IgnoreCd)
    if ($G.Cd -gt 0 -and -not $IgnoreCd) { return }
    $G.Cd = 3
    $sx = $G.PX + $G.FX; $sy = $G.PY + $G.FY
    if (Test-Wall $sx $sy) { return }
    $e = Get-EnemyAt $sx $sy
    if ($null -ne $e) { Damage-Enemy $e 1 $Src; return }
    Add-Bullet $sx $sy $G.FX $G.FY 1 'p' $false 30 $Src
}

function Damage-Enemy {
    param($E, [int]$N, [string]$Src)
    if ($E.IsDev -and $Src -eq 'phys') { Dev-Dodge $E; $G.PhysMiss++; return }
    $E.Hp -= $N; $E.Flash = 4
    if ($E.IsDev) { $G.MacroHits++ }
    if ($E.Hp -le 0) { $E.Alive = $false }
}

function Hit-Player {
    if ($G.Inv -gt 0) { return }
    $G.Hp--; $G.Inv = 18; $G.PFlash = 6
    if ($G.Hp -le 0) { Die-Player }
}

function Die-Player {
    $G.Bullets.Clear(); $G.Tele.Clear()
    $G.PX = $G.CkX; $G.PY = $G.CkY
    $G.Hp = $G.MaxHp; $G.Inv = 30
    if ($G.Boss -and $G.Boss.Alive -and $G.ChapIdx -eq 2) { $G.Boss.Hp = $G.Boss.MaxHp }
    Set-Hint 'Nothing is lost. Try again.' 60

    
}

function Pulse-Clear {
    $G.Bullets.Clear(); $G.Tele.Clear()
    Set-Hint 'PULSE' 20
}
