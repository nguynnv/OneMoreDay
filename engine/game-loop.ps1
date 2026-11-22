function Set-Hint { param([string]$Text, [int]$Ticks = 50) $G.Hint = $Text; $G.HintT = $Ticks }

function Refresh-ExitReady {
    $flag = switch ($G.ChapIdx) { 1 { 'ch1_signal' } 2 { 'ch2_boss' } 3 { 'ch3_rested' } 4 { 'ch4_archive' } 5 { 'ch5_unlocked' } default { '' } }
    $G.ExitReady = [bool]($flag -and $G.Flags[$flag])
}
function Set-Flag { param([string]$Name) $G.Flags[$Name] = $true; Refresh-ExitReady; Save-Game }

function Put-World {
    param([int]$Mx, [int]$My, [char]$C, [int]$Fg)
    $sx = $Mx - $G.CamX; $sy = $My - $G.CamY + 1
    if ($sx -lt 0 -or $sx -ge $G.FW -or $sy -lt 1 -or $sy -ge ($G.FH - 2)) { return }
    $i = $sy * $G.FW + $sx
    $G.Ch[$i] = $C; $G.Fg[$i] = $Fg
}

function Render-World {
    $w = $G.FW; $h = $G.FH
    $c = $G.Chap
    Clear-Frame $c.Bg
    $ch = $G.Ch; $fgA = $G.Fg
    $vw = $w; $vh = $h - 3
    $mw = $G.MW; $mh = $G.MH; $map = $G.Map
    $camX = 0; $camY = 0; $offX = 0; $offY = 0
    if ($mw -le $vw) { $offX = [int](($vw - $mw) / 2) } else { $camX = [math]::Max(0, [math]::Min($mw - $vw, $G.PX - [int]($vw / 2))) }
    if ($mh -le $vh) { $offY = [int](($vh - $mh) / 2) } else { $camY = [math]::Max(0, [math]::Min($mh - $vh, $G.PY - [int]($vh / 2))) }
    $G.CamX = $camX - $offX; $G.CamY = $camY - $offY
    $tg = $G.TGlyph; $tf = $G.TFg; $alt = $G.FloorAlt
    $sw = [math]::Min($vw, $mw); $sh = [math]::Min($vh, $mh)
    for ($sy = 0; $sy -lt $sh; $sy++) {
        $my = $camY + $sy
        $row = ($sy + $offY + 1) * $w + $offX
        $mrow = $my * $mw + $camX
        for ($sx = 0; $sx -lt $sw; $sx++) {
            $t = [int]$map[$mrow + $sx]
            $i = $row + $sx
            if ($t -eq 46 -and ((($camX + $sx) * 31 + $my * 17) % 9) -eq 0) { $ch[$i] = $alt } else { $ch[$i] = $tg[$t] }
            $fgA[$i] = $tf[$t]
        }
    }
    $blink = (([int]($G.Tick / 3)) % 2) -eq 0
    foreach ($t in $G.Tele) { Put-World $t.X $t.Y $(if ($blink) { [char]'!' } else { $Gl.Light }) $Pal.Warn }
    foreach ($b in $G.Bullets) {
        $col = if ($b.Owner -eq 'p') { $Pal.Catherine } elseif ($G.ChapIdx -eq 6) { $Pal.Dev } else { $Pal.Warn }
        Put-World $b.X $b.Y $Gl.Bullet $col
    }
    foreach ($e in $G.Enemies) {
        if (-not $e.Alive) { continue }
        if ($e.Boss) {
            if ($e.IsDev) {
                $col = Blend-Color $Pal.Dev 0x777777 (1.0 - $e.Hp / $e.MaxHp)
                if ($e.Flash -gt 0) { $col = $Pal.DevWhite }
            } else { $col = if ($e.Flash -gt 0) { $Pal.DevWhite } else { $c.Accent } }
            Put-World $e.X $e.Y $Gl.Boss $col
        } else {
            $col = if ($e.Flash -gt 0) { $Pal.DevWhite } else { $Pal.Enemy }
            Put-World $e.X $e.Y $Gl.Enemy $col
        }
    }
    foreach ($n in $G.Npcs) { Put-World $n.X $n.Y ([char]'&') $Pal.Npc }
    $pc = if ($G.PFlash -gt 0 -and ($G.Tick % 2) -eq 0) { $Pal.Warn } else { $Pal.Catherine }
    Put-World $G.PX $G.PY ([char]'@') $pc
    Draw-Hud
    if ($G.Glitch) { Apply-Glitch }
}

function Draw-Hud {
    $w = $G.FW; $h = $G.FH; $c = $G.Chap
    Put-Text 1 0 'CATHERINE' $Pal.Catherine
    for ($i = 0; $i -lt $G.MaxHp; $i++) {
        Put-Char (11 + $i) 0 $Gl.Heart $(if ($i -lt $G.Hp) { $Pal.Warn } else { 0x3A3F4A })
    }
    $label = if ($G.ChapIdx -lt 7) { 'CHAPTER {0:00} - {1}' -f $G.ChapIdx, $c.Title.ToUpper() } else { 'ONE MORE DAY' }
    Put-Text ($w - $label.Length - 1) 0 $label $c.Accent
    $b = $G.Boss
    if ($null -ne $b -and $b.Alive -and ($G.ChapIdx -eq 2 -or ($G.ChapIdx -eq 6 -and $G.DevStarted))) {
        $name = if ($b.IsDev) { 'DEVELOPER' } else { 'GUARDIAN' }
        $filled = [int][math]::Ceiling(10.0 * $b.Hp / $b.MaxHp)
        $bar = ([string]$Gl.Full * $filled) + ([string]$Gl.Light * (10 - $filled))
        $col = if ($b.IsDev) { $Pal.Dev } else { $c.Accent }
        Put-Text ([int](($w - 24) / 2)) 0 "$name $bar" $col
    }
    $hint = ''
    if ($G.HintT -gt 0) { $hint = $G.Hint }
    elseif ($G.FogOn -and $G.WinW -lt 100) { $hint = 'This place is bigger than this window.  (TAB: look closer)' }
    elseif ($G.ChapIdx -eq 5 -and $G.Flags.ch5_hacker -and $G.ConsentMode -ne 'Inside' -and ($G.C5T - $G.HackerAt) -ge 1500 -and -not $G.Flags.ch5_unlocked) { $hint = '[H] show me the folder' }
    if ($hint) { Put-Text 1 ($h - 2) $hint $Pal.Dim }
    $help = 'WASD/arrows move   E interact   SPACE attack   ESC pause'
    Put-Text 1 ($h - 1) $help 0x4A5362
}

function Apply-Glitch {
    $n = 6 + (Get-Random -Maximum 8)
    $glyphs = @($Gl.Light, $Gl.Mid, $Gl.Dark, [char]'%', [char]'/', [char]'0', [char]'1')
    for ($k = 0; $k -lt $n; $k++) {
        $x = Get-Random -Maximum $G.FW; $y = 1 + (Get-Random -Maximum ($G.FH - 4))
        $col = if ((Get-Random -Maximum 2) -eq 0) { $Pal.Neon } else { $Pal.Magenta }
        Put-Char $x $y $glyphs[(Get-Random -Maximum $glyphs.Count)] $col
    }
    if (($G.Tick % 50) -lt 3) {
        $y = 1 + (Get-Random -Maximum ($G.FH - 4))
        for ($x = 0; $x -lt $G.FW; $x++) { $G.Fg[$y * $G.FW + $x] = $Pal.Magenta }
    }
}

function Update-Window {
    if ($G.Headless) { return }
    $now = $G.Clock.ElapsedMilliseconds
    if ($now - $G.LastWin -lt 500) { return }
    $G.LastWin = $now
    try { $ws = $Host.UI.RawUI.WindowSize; $ww = [int]$ws.Width; $wh = [int]$ws.Height } catch { return }
    if ($ww -ne $G.WinW -or $wh -ne $G.WinH) {
        $G.WinW = $ww; $G.WinH = $wh
        $G.TooSmall = ($ww -lt 80 -or $wh -lt 26)
        Initialize-Frame ([math]::Min($ww, 120)) ([math]::Min($wh, 34))
        if ($G.Chap) { Set-TerminalBg $G.Chap.Bg }
    }
}

function Show-TooSmall {
    Write-Out ("`e[0m`e[2J`e[1;1HPlease make this window at least 80 x 26.`e[2;1H(Current: $($G.WinW) x $($G.WinH))")
}

function Try-Move {
    param([int]$Dx, [int]$Dy)
    $G.FX = $Dx; $G.FY = $Dy
    $nx = $G.PX + $Dx; $ny = $G.PY + $Dy
    if (Test-Blocked $nx $ny) {
        if ((Get-Tile $nx $ny) -eq 69 -and -not $G.ExitReady) { Set-Hint 'Not yet.' 30 }
        return $false
    }
    $G.PX = $nx; $G.PY = $ny
    $t = Get-Tile $nx $ny
    if ($t -eq 75 -and ($G.CkX -ne $nx -or $G.CkY -ne $ny)) {
        $G.CkX = $nx; $G.CkY = $ny; $G.Hp = $G.MaxHp
        Save-Game; Set-Hint 'Checkpoint.' 40
    }
    elseif ($t -eq 69) { Complete-Chapter }
    return $true
}

function Process-Keys {
    param($Keys)
    $move = $null; $attack = $false; $interact = $false; $heard = $false
    $pause = $false; $console = $false; $hint = $false; $tab = $false
    foreach ($k in $Keys) {
        $a = Get-KeyAction $k
        if ($a -in 'Up', 'Down', 'Left', 'Right') { $move = $a; $heard = $true }
        elseif ($a -eq 'Attack') { $attack = $true; $heard = $true }
        elseif ($a -eq 'Interact') { $interact = $true; $heard = $true }
        elseif ($a -eq 'Pause') { $pause = $true }
        elseif ($a -eq 'Console') { $console = $true }
        elseif ($a -eq 'Hint') { $hint = $true }
        elseif ($a -eq 'Tab') { $tab = $true }
    }
    if ($pause) { Show-Pause; return }
    if ($console) { Open-Console; return }
    if ($tab -and $G.FogOn) { Lift-Fog }
    if ($hint) { Event-Hint }
    if ($heard -and $G.ChapIdx -eq 6 -and $G.DevStarted -and $G.Dev -and $G.Dev.Alive) { Dev-Dodge $G.Dev }
    if ($move) {
        switch ($move) {
            'Up' { [void](Try-Move 0 -1) } 'Down' { [void](Try-Move 0 1) }
            'Left' { [void](Try-Move -1 0) } 'Right' { [void](Try-Move 1 0) }
        }
    }
    if ($attack) {
        if ($G.ChapIdx -eq 6 -and $G.DevStarted) { $G.PhysAttacks++ }
        Fire-Player 'phys'
    }
    if ($interact) { Invoke-Interact }
}

function Process-Command {
    if ($G.CmdQ.Count -eq 0) { return }
    $c = $G.CmdQ.Dequeue()
    switch ($c) {
        'MOVE_L' { [void](Try-Move -1 0) }
        'MOVE_R' { [void](Try-Move 1 0) }
        'MOVE_U' { [void](Try-Move 0 -1) }
        'MOVE_D' { [void](Try-Move 0 1) }
        'ATTACK' { Fire-Player 'cmd' -IgnoreCd }
        'UNLOCK' { Unlock-Doors }
        'PULSE'  { Pulse-Clear }
    }
}

function Unlock-Doors {
    $had = $false
    foreach ($v in $G.Map) { if ([int]$v -eq 68) { $had = $true; break } }
    if (-not $had) { return }
    Convert-Tiles 68 ([char]'.')
    Set-Flag 'ch5_unlocked'
    Set-Hint 'UNLOCKED' 50
}

function Open-Console {
    if ($G.ConsentMode -ne 'Inside') { Set-Hint 'No console here.' 30; return }
    if ($G.ChapIdx -lt 5) { return }
    $txt = Read-TextOverlay -Lines @('CONSOLE', 'type: help') -Label '> ' -MaxLen 24 -Color $Pal.Neon
    if ([string]::IsNullOrWhiteSpace($txt)) { return }
    $tok = $txt.Trim().ToLowerInvariant() -split '\s+'
    $n = 1
    if ($tok.Count -gt 1) { $parsed = 0; if ([int]::TryParse($tok[1], [ref]$parsed)) { $n = [math]::Max(1, [math]::Min(30, $parsed)) } }
    switch ($tok[0]) {
        'help'   { Show-Dialog -Lines @('unlock', 'pulse', 'attack [n]', 'left | right | up | down [n]') -Color $Pal.Neon }
        'unlock' { $G.CmdQ.Enqueue('UNLOCK') }
        'pulse'  { $G.CmdQ.Enqueue('PULSE') }
        'attack' { 1..$n | ForEach-Object { $G.CmdQ.Enqueue('ATTACK') } }
        'left'   { 1..$n | ForEach-Object { $G.CmdQ.Enqueue('MOVE_L') } }
        'right'  { 1..$n | ForEach-Object { $G.CmdQ.Enqueue('MOVE_R') } }
        'up'     { 1..$n | ForEach-Object { $G.CmdQ.Enqueue('MOVE_U') } }
        'down'   { 1..$n | ForEach-Object { $G.CmdQ.Enqueue('MOVE_D') } }
        default  { Set-Hint 'Unknown command.' 30 }
    }
}

function Show-Pause {
    $i = Show-Choice -Lines @('PAUSED') -Options @('RESUME', 'SAVE AND LEAVE') -Color $Pal.Catherine
    if ($i -eq 1) { Save-Game; $G.Running = $false }
}

function Lift-Fog {
    if (-not $G.FogOn) { return }
    Convert-Tiles 102 ([char]'.')
    $G.FogOn = $false
    Set-Hint 'The fog thins out.' 60
}

function Step-Game {
    param($Keys)
    $G.Tick++
    Process-Keys $Keys
    if (-not $G.Running) { return }
    if (-not $G.Headless) { Read-CommandFile }
    Process-Command
    Update-Telegraphs
    Update-Bullets
    Update-Enemies
    Update-Boss
    Update-Chapter
    if ($G.PFlash -gt 0) { $G.PFlash-- }
    if ($G.HintT -gt 0) { $G.HintT-- }
    Render-World
}

function Run-Game {
    $G.Running = $true; $G.InWorld = $true
    Clear-Keys
    while ($G.Running) {
        $t0 = $G.Clock.ElapsedMilliseconds
        Update-Window
        if ($G.TooSmall) { Show-TooSmall; Start-Sleep -Milliseconds 200; continue }
        $keys = @()
        while ($keys.Count -lt 12) { $k = Get-Key; if ($null -eq $k) { break }; $keys += $k }
        Step-Game $keys
        if ($G.Running) { Flush-Frame }
        $spent = $G.Clock.ElapsedMilliseconds - $t0
        $wait = $G.TickMs - $spent
        if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
    }
    $G.InWorld = $false
}

function Enter-Chapter {
    param([int]$Index, $Resume = $null, [switch]$NoCard)
    $G.ChapIdx = $Index; $G.Chap = $Chapters[$Index - 1]
    Reset-Dim; Reset-Title
    Load-Map $G.Chap.Map
    Build-Tiles
    $G.PX = $G.StartX; $G.PY = $G.StartY; $G.CkX = $G.StartX; $G.CkY = $G.StartY
    $G.FX = 1; $G.FY = 0; $G.Hp = $G.MaxHp; $G.Inv = 0; $G.Cd = 0; $G.Tick = 0; $G.PFlash = 0
    $G.Hint = ''; $G.HintT = 0; $G.Glitch = $false; $G.CmdQ.Clear()
    $G.C5T = 0; $G.LockedTries = 0; $G.HackerAt = 0
    $G.DevStarted = $false; $G.PhysAttacks = 0; $G.MacroHits = 0; $G.PhysMiss = 0; $G.Seen = @{}
    $G.FogOn = ($Index -eq 2)
    if ($Resume) {
        $G.PX = [int]$Resume.X; $G.PY = [int]$Resume.Y; $G.Hp = [int]$Resume.Hp
        $G.CkX = [int]$Resume.CkX; $G.CkY = [int]$Resume.CkY
    }
    if ($G.Flags.ch2_boss -and $G.Boss) { $G.Boss.Alive = $false }
    if ($G.Flags.ch4_gate) { Convert-Tiles 71 ([char]'.') }
    if ($G.Flags.ch5_unlocked) { Convert-Tiles 68 ([char]'.') }
    if ($G.Flags.ch5_hacker -and $Index -eq 5) { $G.Glitch = $true }
    if ($Index -eq 4) { Prepare-Receiver }
    Refresh-ExitReady
    if ($G.ChapIdx -ne 5 -or -not $G.Flags.ch5_hacker) { }
    Set-TerminalBg $G.Chap.Bg
    if (-not $NoCard -and $Index -lt 7) {
        Show-Card ('CHAPTER {0:00}' -f $Index) $G.Chap.Title.ToUpper() $G.Chap.Accent $G.Chap.Bg
    }
    Save-Game
}

function Complete-Chapter {
    switch ($G.ChapIdx) {
        3 { Play-Signal 'ch3_msg' }
        5 { Play-Signal 'ch5_msg' }
    }
    $next = $G.ChapIdx + 1
    if ($next -le 7) { Enter-Chapter $next }
}

function Start-NewGame {
    $G.Flags = @{}; $G.Freq = ''
    Reset-CommandFile
    Enter-Chapter 1
    Run-Game
}

function Continue-Game {
    $s = Load-Save
    if ($null -eq $s) { return $false }
    $G.Flags = if ($s.Flags) { $s.Flags } else { @{} }
    $G.Freq = [string]$s.Freq; $G.PlayerName = [string]$s.Name
    Reset-CommandFile
    Enter-Chapter ([int]$s.Chapter) $s -NoCard
    Run-Game
    return $true
}
