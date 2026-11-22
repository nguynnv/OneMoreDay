function Initialize-Frame {
    param([int]$W, [int]$H)
    $G.FW = $W; $G.FH = $H
    $n = $W * $H
    $G.Ch = New-Object 'char[]' $n
    $G.Fg = New-Object 'int[]' $n
    $G.Bg = New-Object 'int[]' $n
    if (-not $G.SB) { $G.SB = New-Object System.Text.StringBuilder 65536 }
    Clear-Frame $Pal.Bg
}

function Clear-Frame {
    param([int]$Bg = 0x0B0D12)
    [Array]::Fill($G.Ch, [char]' ')
    [Array]::Fill($G.Fg, [int]$Pal.Text)
    [Array]::Fill($G.Bg, [int]$Bg)
}

function Put-Text {
    param([int]$X, [int]$Y, [string]$Text, [int]$Fg, [int]$Bg = -1)
    if ($Y -lt 0 -or $Y -ge $G.FH) { return }
    $w = $G.FW; $ch = $G.Ch; $fgA = $G.Fg; $bgA = $G.Bg
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $cx = $X + $i
        if ($cx -lt 0 -or $cx -ge $w) { continue }
        $idx = $Y * $w + $cx
        $ch[$idx] = $Text[$i]; $fgA[$idx] = $Fg
        if ($Bg -ge 0) { $bgA[$idx] = $Bg }
    }
}

function Put-Char {
    param([int]$X, [int]$Y, [char]$C, [int]$Fg, [int]$Bg = -1)
    if ($X -lt 0 -or $Y -lt 0 -or $X -ge $G.FW -or $Y -ge $G.FH) { return }
    $idx = $Y * $G.FW + $X
    $G.Ch[$idx] = $C; $G.Fg[$idx] = $Fg
    if ($Bg -ge 0) { $G.Bg[$idx] = $Bg }
}

function Fill-Rect {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [int]$Bg)
    for ($yy = $Y; $yy -lt $Y + $H; $yy++) {
        if ($yy -lt 0 -or $yy -ge $G.FH) { continue }
        for ($xx = $X; $xx -lt $X + $W; $xx++) {
            if ($xx -lt 0 -or $xx -ge $G.FW) { continue }
            $idx = $yy * $G.FW + $xx
            $G.Ch[$idx] = [char]' '; $G.Bg[$idx] = $Bg
        }
    }
}

function Draw-Box {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [int]$Fg, [int]$Bg, [switch]$Double)
    Fill-Rect $X $Y $W $H $Bg
    if ($Double) { $tl = 0x2554; $tr = 0x2557; $bl = 0x255A; $br = 0x255D; $hz = 0x2550; $vt = 0x2551 }
    else { $tl = 0x250C; $tr = 0x2510; $bl = 0x2514; $br = 0x2518; $hz = 0x2500; $vt = 0x2502 }
    for ($i = 1; $i -lt $W - 1; $i++) { Put-Char ($X + $i) $Y ([char]$hz) $Fg; Put-Char ($X + $i) ($Y + $H - 1) ([char]$hz) $Fg }
    for ($j = 1; $j -lt $H - 1; $j++) { Put-Char $X ($Y + $j) ([char]$vt) $Fg; Put-Char ($X + $W - 1) ($Y + $j) ([char]$vt) $Fg }
    Put-Char $X $Y ([char]$tl) $Fg; Put-Char ($X + $W - 1) $Y ([char]$tr) $Fg
    Put-Char $X ($Y + $H - 1) ([char]$bl) $Fg; Put-Char ($X + $W - 1) ($Y + $H - 1) ([char]$br) $Fg
}

function Save-Frame { $G.SaveCh = $G.Ch.Clone(); $G.SaveFg = $G.Fg.Clone(); $G.SaveBg = $G.Bg.Clone() }
function Restore-Frame {
    [Array]::Copy($G.SaveCh, $G.Ch, $G.Ch.Length)
    [Array]::Copy($G.SaveFg, $G.Fg, $G.Fg.Length)
    [Array]::Copy($G.SaveBg, $G.Bg, $G.Bg.Length)
}

function Write-Out {
    param([string]$S)
    if ($G.Headless) { $G.LastOut = $S } else { [Console]::Out.Write($S) }
}

function Flush-Frame {
    $sb = $G.SB; [void]$sb.Clear()
    $w = $G.FW; $h = $G.FH
    $ch = $G.Ch; $fgA = $G.Fg; $bgA = $G.Bg
    $lastFg = -2; $lastBg = -2
    for ($y = 0; $y -lt $h; $y++) {
        [void]$sb.Append("`e[$($y + 1);1H")
        $row = $y * $w
        for ($x = 0; $x -lt $w; $x++) {
            $i = $row + $x
            $bg = $bgA[$i]; $fg = $fgA[$i]
            if ($bg -ne $lastBg) { [void]$sb.Append((Get-Esc $bg $true)); $lastBg = $bg }
            if ($fg -ne $lastFg) { [void]$sb.Append((Get-Esc $fg $false)); $lastFg = $fg }
            [void]$sb.Append($ch[$i])
        }
    }
    [void]$sb.Append("`e[0m")
    Write-Out $sb.ToString()
}

function Set-TerminalBg {
    param([int]$Rgb)
    if ($G.Headless -or $G.ColorMode -eq 'Off') { return }
    Write-Out ((Get-Esc $Rgb $true) + "`e[2J")
}
