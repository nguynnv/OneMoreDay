$global:Chapters = @(
    @{ N = 1; Title = 'The Beginning';    Map = 'chapter-01.map'; Bg = 0x1B222C; Wall = 0x4A5A6E; Floor = 0x2E3A48; Accent = 0xFFB86B; Alt = '.' }
    @{ N = 2; Title = 'The Forest';       Map = 'chapter-02.map'; Bg = 0x14261B; Wall = 0x3E7B4F; Floor = 0x27503A; Accent = 0xC6E36B; Alt = ',' }
    @{ N = 3; Title = 'The Empty Town';   Map = 'chapter-03.map'; Bg = 0x2A2238; Wall = 0x5B4A75; Floor = 0x3D3252; Accent = 0xE39A6E; Alt = '.' }
    @{ N = 4; Title = 'The Signal';       Map = 'chapter-04.map'; Bg = 0x08222B; Wall = 0x1C6B78; Floor = 0x0F3C47; Accent = 0x2EC4B6; Alt = ':' }
    @{ N = 5; Title = 'The Impossible';   Map = 'chapter-05.map'; Bg = 0x050505; Wall = 0x4A4A4A; Floor = 0x1E2E1E; Accent = 0x39FF14; Alt = '.' }
    @{ N = 6; Title = 'The Developer';    Map = 'chapter-06.map'; Bg = 0x0A0A0A; Wall = 0xBDBDBD; Floor = 0x2A2A2A; Accent = 0xFF4D4D; Alt = '.' }
    @{ N = 7; Title = 'One More Day';     Map = 'chapter-07.map'; Bg = 0x2B1D12; Wall = 0x7A5A3A; Floor = 0x4A3422; Accent = 0xF2E6D0; Alt = '.' }
)


function Build-Tiles {
    $c = $G.Chap
    $tg = New-Object 'char[]' 128
    $tf = New-Object 'int[]' 128
    for ($i = 0; $i -lt 128; $i++) { $tg[$i] = $Gl.Floor; $tf[$i] = $c.Floor }
    $tg[35] = $Gl.Wall;   $tf[35] = $c.Wall
    $tg[46] = $Gl.Floor;  $tf[46] = $c.Floor
    $tg[126] = $Gl.Water; $tf[126] = $Pal.Water
    $tg[68] = $Gl.Door;   $tf[68] = $Pal.Door
    $tg[71] = $Gl.Door;   $tf[71] = $Pal.Signal
    $tg[75] = $Gl.Check;  $tf[75] = $Pal.Gold
    $tg[69] = $Gl.Exit;   $tf[69] = $c.Accent
    $tg[84] = $Gl.Device; $tf[84] = $(if ($G.ChapIdx -eq 7) { $Pal.Catherine } else { $Pal.Signal })
    $tg[98] = $Gl.Bench;  $tf[98] = 0xA0785A
    $tg[102] = $Gl.Fog;   $tf[102] = $Pal.Fog
    $tg[111] = $Gl.Clock; $tf[111] = $Pal.WarmWhite
    $G.TGlyph = $tg; $G.TFg = $tf
    $G.FloorAlt = [char]($c.Alt)
    $solid = New-Object 'bool[]' 128
    foreach ($code in 35, 126, 68, 71, 84, 98, 102, 111) { $solid[$code] = $true }
    $G.Solid = $solid
}

function Load-Map {
    param([string]$File)
    $lines = [IO.File]::ReadAllLines((Join-Path $Root "chapters/$File"))
    $mh = $lines.Count; $mw = 0
    foreach ($l in $lines) { if ($l.Length -gt $mw) { $mw = $l.Length } }
    $map = New-Object 'char[]' ($mw * $mh)
    $G.Enemies = [Collections.ArrayList]::new()
    $G.Npcs = [Collections.ArrayList]::new()
    $G.Spawns = [Collections.ArrayList]::new()
    $G.Bullets = [Collections.ArrayList]::new()
    $G.Tele = [Collections.ArrayList]::new()
    $G.Dev = $null; $G.Boss = $null
    for ($y = 0; $y -lt $mh; $y++) {
        $row = $lines[$y]
        for ($x = 0; $x -lt $mw; $x++) {
            $c = if ($x -lt $row.Length) { $row[$x] } else { [char]'#' }
            $code = [int]$c
            $out = $c
            if ($code -eq 64) { $G.StartX = $x; $G.StartY = $y; $out = [char]'.' }
            elseif ($code -ge 49 -and $code -le 52) {
                $hp = if ($code -eq 49) { 2 } else { 3 }
                [void]$G.Enemies.Add(@{ Type = [string]$c; X = $x; Y = $y; Hp = $hp; MaxHp = $hp; Cd = (20 + ($x * 7 + $y * 3) % 30); Alive = $true; Flash = 0; Step = 0; Boss = $false; IsDev = $false; Move = 0 })
                $out = [char]'.'
            }
            elseif ($code -eq 66) {
                $isDev = ($G.ChapIdx -eq 6)
                $hp = if ($isDev) { 14 } else { 10 }
                $b = @{ Type = 'B'; X = $x; Y = $y; Hp = $hp; MaxHp = $hp; Cd = 40; Alive = $true; Flash = 0; Step = 0; Boss = $true; IsDev = $isDev; Move = 0 }
                [void]$G.Enemies.Add($b); $G.Boss = $b
                if ($isDev) { $G.Dev = $b }
                $out = [char]'.'
            }
            elseif ($code -eq 38) { [void]$G.Npcs.Add(@{ X = $x; Y = $y; Talks = 0 }); $out = [char]'.' }
            elseif ($code -eq 115) { [void]$G.Spawns.Add(@($x, $y)); $out = [char]'.' }
            $map[$y * $mw + $x] = $out
        }
    }
    $G.Map = $map; $G.MW = $mw; $G.MH = $mh
}

function Get-Tile {
    param([int]$X, [int]$Y)
    if ($X -lt 0 -or $Y -lt 0 -or $X -ge $G.MW -or $Y -ge $G.MH) { return 35 }
    return [int]$G.Map[$Y * $G.MW + $X]
}
function Set-TileAt { param([int]$X, [int]$Y, [char]$C) $G.Map[$Y * $G.MW + $X] = $C }

function Test-Wall {
    param([int]$X, [int]$Y)
    $t = Get-Tile $X $Y
    if ($G.Solid[$t]) { return $true }
    if ($t -eq 69 -and -not $G.ExitReady) { return $true }
    return $false
}
function Get-EnemyAt {
    param([int]$X, [int]$Y)
    foreach ($e in $G.Enemies) { if ($e.Alive -and $e.X -eq $X -and $e.Y -eq $Y) { return $e } }
    return $null
}
function Get-NpcAt {
    param([int]$X, [int]$Y)
    foreach ($n in $G.Npcs) { if ($n.X -eq $X -and $n.Y -eq $Y) { return $n } }
    return $null
}
function Test-Blocked {
    param([int]$X, [int]$Y)
    if (Test-Wall $X $Y) { return $true }
    if ($null -ne (Get-EnemyAt $X $Y)) { return $true }
    if ($null -ne (Get-NpcAt $X $Y)) { return $true }
    return $false
}
function Convert-Tiles {
    param([int]$From, [char]$To)
    for ($i = 0; $i -lt $G.Map.Length; $i++) { if ([int]$G.Map[$i] -eq $From) { $G.Map[$i] = $To } }
}
function Count-Alive {
    $n = 0
    foreach ($e in $G.Enemies) { if ($e.Alive -and -not $e.Boss) { $n++ } }
    return $n
}
