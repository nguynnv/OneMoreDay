function Get-StyleColor {
    param([string]$Style)
    switch ($Style) {
        'signal' { return $Pal.Signal }
        'npc'    { return $Pal.Npc }
        'dev'    { return $Pal.Dev }
        'null'   { return $Pal.Neon }
        'warn'   { return $Pal.Warn }
        'catherine' { return $Pal.Catherine }
        default  { return $Pal.Text }
    }
}

function Begin-Modal {
    if ($G.InWorld) { Render-World }
    Save-Frame
    Clear-Keys
}
function End-Modal { Restore-Frame; Flush-Frame }

function Get-BoxLayout {
    param([string[]]$Lines, [int]$MinW = 40, [int]$ExtraH = 4, [switch]$Center)
    $maxLen = 0
    foreach ($l in $Lines) { if ($l.Length -gt $maxLen) { $maxLen = $l.Length } }
    $bw = [math]::Min($G.FW - 2, [math]::Max($MinW, $maxLen + 8))
    $bh = $Lines.Count + $ExtraH
    $bx = [int](($G.FW - $bw) / 2)
    $by = if ($Center) { [math]::Max(1, [int](($G.FH - $bh) / 2)) } else { [math]::Max(1, $G.FH - $bh - 3) }
    return @{ X = $bx; Y = $by; W = $bw; H = $bh }
}

function Show-Dialog {
    param([string]$Speaker = '', [string[]]$Lines, [int]$Color = 0, [switch]$Instant, [double]$Hold = 0, [switch]$Center, [switch]$NoBox)
    if ($Color -eq 0) { $Color = $Pal.Text }
    Begin-Modal
    $all = @($Lines); if ($Speaker) { $all += $Speaker }
    $extra = if ($Speaker) { 6 } else { 4 }
    $Lay = Get-BoxLayout -Lines $all -ExtraH $extra -Center:$Center
    $total = 0; foreach ($l in $Lines) { $total += $l.Length }
    $reveal = 0.0; $last = 0.0; $doneAt = -1.0
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $now = $sw.Elapsed.TotalSeconds
        if ($Instant -or $G.Headless) { $reveal = $total } else { $reveal += ($now - $last) * $G.Cps }
        $last = $now
        $n = [int][math]::Min($total, $reveal)
        Restore-Frame
        if (-not $NoBox) { Draw-Box $Lay.X $Lay.Y $Lay.W $Lay.H $Color $Pal.BoxBg }
        $y = $Lay.Y + 1
        if ($Speaker) { Put-Text ($Lay.X + 3) $y $Speaker $Color $Pal.BoxBg; $y += 2 }
        $left = $n
        foreach ($l in $Lines) {
            $take = [math]::Min([math]::Max($left, 0), $l.Length)
            if ($take -gt 0) { Put-Text ($Lay.X + 3) $y $l.Substring(0, $take) $Color $Pal.BoxBg }
            $left -= $take; $y++
        }
        $complete = ($n -ge $total)
        if ($complete -and $doneAt -lt 0) { $doneAt = $now }
        if ($complete -and $Hold -le 0 -and -not $Instant) {
            if ([int]($now * 2) % 2 -eq 0) { Put-Char ($Lay.X + $Lay.W - 3) ($Lay.Y + $Lay.H - 2) $Gl.Cue $Color $Pal.BoxBg }
        }
        Flush-Frame
        if ($G.Headless) { break }
        if ($complete -and $Hold -gt 0 -and ($now - $doneAt) -ge $Hold) { break }
        if ($complete -and $Instant -and $Hold -le 0) { break }
        $k = Get-Key
        if ($null -ne $k -and $Hold -le 0) {
            if (-not $complete) { $reveal = $total } else { break }
        }
        Start-Sleep -Milliseconds 16
    }
    End-Modal
}

function Play-Dialog {
    param([string]$Id, [switch]$Instant, [double]$Hold = 0)
    $dd = $global:Dlg.$Id
    $col = Get-StyleColor $dd.style
    foreach ($pg in $dd.pages) {
        Show-Dialog -Speaker $dd.speaker -Lines ([string[]]@($pg)) -Color $col -Instant:$Instant -Hold $Hold
    }
}

function Play-Signal {
    param([string]$Id)
    Set-Title '[UNKNOWN SIGNAL]'
    Play-Dialog $Id
    Reset-Title
}

function Show-Choice {
    param([string[]]$Lines, [string[]]$Options, [int]$Color = 0, [int]$Default = 0, [switch]$Center)
    if ($Color -eq 0) { $Color = $Pal.Text }
    if ($G.Headless) { return $Default }
    Begin-Modal
    $optText = ($Options | ForEach-Object { "[ $_ ]" }) -join '   '
    $all = @($Lines) + @($optText)
    $Lay = Get-BoxLayout -Lines $all -ExtraH 5 -Center:$Center
    $sel = $Default
    while ($true) {
        Restore-Frame
        Draw-Box $Lay.X $Lay.Y $Lay.W $Lay.H $Color $Pal.BoxBg
        $y = $Lay.Y + 1
        foreach ($l in $Lines) { Put-Text ($Lay.X + 3) $y $l $Color $Pal.BoxBg; $y++ }
        $y += 1
        $x = $Lay.X + 3
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $txt = "[ $($Options[$i]) ]"
            if ($i -eq $sel) { Put-Text $x $y $txt $Pal.BoxBg $Color } else { Put-Text $x $y $txt $Color $Pal.BoxBg }
            $x += $txt.Length + 3
        }
        Flush-Frame
        $k = Wait-Key
        $a = Get-KeyAction $k
        if ($a -eq 'Left' -or $a -eq 'Up') { $sel = ($sel + $Options.Count - 1) % $Options.Count }
        elseif ($a -eq 'Right' -or $a -eq 'Down' -or $a -eq 'Tab') { $sel = ($sel + 1) % $Options.Count }
        elseif ($a -eq 'Enter' -or $a -eq 'Interact' -or $a -eq 'Attack') { break }
    }
    End-Modal
    return $sel
}

function Read-TextOverlay {
    param([string[]]$Lines, [string]$Label = '> ', [int]$MaxLen = 16, [int]$Color = 0)
    if ($Color -eq 0) { $Color = $Pal.Text }
    if ($G.Headless) { return '' }
    Begin-Modal
    $Lay = Get-BoxLayout -Lines (@($Lines) + @('x' * ($MaxLen + $Label.Length))) -ExtraH 5
    $buf = ''
    $result = $null
    while ($true) {
        Restore-Frame
        Draw-Box $Lay.X $Lay.Y $Lay.W $Lay.H $Color $Pal.BoxBg
        $y = $Lay.Y + 1
        foreach ($l in $Lines) { Put-Text ($Lay.X + 3) $y $l $Color $Pal.BoxBg; $y++ }
        $y += 1
        Put-Text ($Lay.X + 3) $y ($Label + $buf + '_') $Pal.WarmWhite $Pal.BoxBg
        Flush-Frame
        $k = Wait-Key
        if ($k.Key -eq 'Enter') { $result = $buf; break }
        elseif ($k.Key -eq 'Escape') { $result = $null; break }
        elseif ($k.Key -eq 'Backspace') { if ($buf.Length -gt 0) { $buf = $buf.Substring(0, $buf.Length - 1) } }
        elseif ($k.KeyChar -ge [char]32 -and $buf.Length -lt $MaxLen) { $buf += $k.KeyChar }
    }
    End-Modal
    return $result
}

function Show-Card {
    param([string]$Top, [string]$Bottom, [int]$Accent, [int]$Bg, [double]$Seconds = 2.2)
    Clear-Frame $Bg
    $y = [int]($G.FH / 2) - 1
    Put-Text ([int](($G.FW - $Top.Length) / 2)) $y $Top $Pal.Dim $Bg
    Put-Text ([int](($G.FW - $Bottom.Length) / 2)) ($y + 2) $Bottom $Accent $Bg
    Flush-Frame
    if ($G.Headless) { return }
    Clear-Keys
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if ($null -ne (Get-Key)) { break }
        Start-Sleep -Milliseconds 20
    }
}

function Fade-Out {
    param([double]$Seconds = 1.5)
    if ($G.Headless) { return }
    Save-Frame
    $G.DimColor = 0x000000
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $G.Dim = [math]::Min(1.0, $sw.Elapsed.TotalSeconds / $Seconds)
        Flush-Frame
        Start-Sleep -Milliseconds 60
    }
    $G.Dim = 1.0; Flush-Frame
}
function Reset-Dim { $G.Dim = 0.0; $G.DimColor = 0x777777 }
