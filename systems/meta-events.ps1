function Update-Chapter {
    switch ($G.ChapIdx) {
        2 { Update-Ch2 }
        5 { Update-Ch5 }
        6 { Update-Ch6 }
    }
}

function Invoke-Interact {
    $cells = @(
        @(($G.PX + $G.FX), ($G.PY + $G.FY)), @($G.PX, ($G.PY - 1)), @($G.PX, ($G.PY + 1)), @(($G.PX - 1), $G.PY), @(($G.PX + 1), $G.PY)
    )
    foreach ($cell in $cells) {
        $x = $cell[0]; $y = $cell[1]
        $npc = Get-NpcAt $x $y
        if ($null -ne $npc) { Event-Npc $npc; return }
        $t = Get-Tile $x $y
        if ($t -eq 84) { Event-Device; return }
        if ($t -eq 98) { Event-Bench; return }
        if ($t -eq 71) { Event-Gate; return }
        if ($t -eq 68) { $G.LockedTries++; Set-Hint 'Locked.' 40; return }
        if ($t -eq 111) { Event-Clock; return }
    }
}

function Event-Device {
    switch ($G.ChapIdx) {
        1 { Event-Ch1Device }
        4 { Event-Archive }
        7 { Event-EndingComputer }
    }
}

function Event-Ch1Device {
    if ($G.Flags.ch1_signal) { Set-Hint 'The device is quiet now.' 50; return }
    Play-Signal 'ch1_msg1'
    Set-Flag 'ch1_signal'
}

function Update-Ch2 {
    if ($G.FogOn -and $G.WinW -ge 100) { Lift-Fog }
    if ($G.Boss -and -not $G.Boss.Alive -and -not $G.Flags.ch2_boss) {
        $G.Bullets.Clear(); $G.Tele.Clear()
        Play-Signal 'ch2_msg'
        Set-Flag 'ch2_boss'
    }
}

function Event-Npc {
    param($Npc)
    if ($Npc.Talks -eq 0) {
        $now = Read-Clock
        $id = 'ch3_npc1'
        if ($null -ne $now -and $now.Hour -ge 5 -and $now.Hour -lt 22) { $id = 'ch3_npc1_day' }
        Play-Dialog $id
    } else { Play-Dialog 'ch3_npc2' }
    $Npc.Talks++
}

function Event-Bench {
    $i = Show-Choice -Lines @('Sit for a minute?') -Options @('SIT', 'NOT NOW') -Color $Pal.Npc
    if ($i -ne 0) { return }
    Run-Rest
}

function Run-Rest {
    $minSec = 10.0; $maxSec = 60.0
    if ($G.Headless) { Set-Flag 'ch3_rested'; return }
    if ($G.InWorld) { Render-World }
    Save-Frame; Clear-Keys
    $G.DimColor = 0x777777
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $t = $sw.Elapsed.TotalSeconds
        $G.Dim = [math]::Min(0.75, $t / 20.0)
        Restore-Frame
        if ($t -ge $minSec) {
            $msg = 'If you want, you could stand up for a moment too. Water, maybe. No rush.'
            Put-Text ([int](($G.FW - $msg.Length) / 2)) ($G.FH - 4) $msg $Pal.Npc $G.Chap.Bg
            Put-Text ([int](($G.FW - 22) / 2)) ($G.FH - 3) '(press E to stand up)' $Pal.Dim $G.Chap.Bg
        }
        Flush-Frame
        $k = Get-Key
        if ($t -ge $minSec -and $null -ne $k) { break }
        if ($t -ge $maxSec) { break }
        Start-Sleep -Milliseconds 80
    }
    Reset-Dim
    Set-Flag 'ch3_rested'
    End-Modal
}

function Prepare-Receiver {
    if (-not $G.Freq) {
        $v = (Get-Random -Minimum 880 -Maximum 1080) / 10.0
        $G.Freq = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.0}', $v)
    }
    if (-not $G.Headless) { try { [void](Write-RuntimeFile 'receiver.txt' @($G.Freq)) } catch { } }
}

function Test-ReceiverAlive { return ($null -ne $G.ReceiverProc -and -not $G.ReceiverProc.HasExited) }

function Event-Gate {
    if ($G.Flags.ch4_gate) { return }
    $window = $false
    if ($G.ConsentMode -ne 'Inside') {
        if (Test-ReceiverAlive) { $window = $true }
        else {
            $ok = Request-Outside -Action 'open_receiver' -Lines @('A second window is about to open. It is a receiver.', 'Look for the numbers in it, then come back here.') -Yes 'OPEN' -No 'SHOW IT HERE'
            if ($ok) { $G.ReceiverProc = Start-ToolWindow 'receiver.ps1'; $window = (Test-ReceiverAlive) }
        }
    }
    if (Run-FrequencyPanel (-not $window)) {
        Convert-Tiles 71 ([char]'.')
        Set-Flag 'ch4_gate'
        Set-Hint 'The gate opens.' 60
    }
}

function Compare-Freq {
    param([string]$A, [string]$B)
    $normalize = {
        param([string]$Value)
        if ($null -eq $Value) { return $null }
        $text = $Value.Trim().Replace(',', '.')
        if ($text -notmatch '^\d+(?:\.\d+)?$') { return $null }
        $number = 0.0
        if (-not [double]::TryParse(
                $text,
                [Globalization.NumberStyles]::AllowDecimalPoint,
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$number)) { return $null }
        return $number
    }
    $left = & $normalize $A
    $right = & $normalize $B
    return ($null -ne $left -and $null -ne $right -and $left -eq $right)
}

function Run-FrequencyPanel {
    param([bool]$Inside)
    if ($G.Headless) { return $false }
    Begin-Modal
    $rng = [Random]::new()
    $noise = [char[]]@($Gl.Light, $Gl.Mid, $Gl.Dark, [char]':', $Gl.Floor)
    $buf = ''; $msg = ''; $ok = $false
    $bw = 52; $bh = if ($Inside) { 12 } else { 8 }
    $bx = [int](($G.FW - $bw) / 2); $by = [int](($G.FH - $bh) / 2)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        Restore-Frame
        Draw-Box $bx $by $bw $bh $Pal.Signal $Pal.BoxBg
        Put-Text ($bx + 3) ($by + 1) 'SIGNAL GATE' $Pal.Signal $Pal.BoxBg
        $y = $by + 3
        if ($Inside) {
            $showCode = (($sw.Elapsed.TotalSeconds % 3.0) -lt 1.8)
            for ($r = 0; $r -lt 3; $r++) {
                $row = New-Object 'char[]' ($bw - 6)
                for ($i = 0; $i -lt $row.Length; $i++) { $row[$i] = $noise[$rng.Next($noise.Length)] }
                $txt = -join $row
                if ($r -eq 1 -and $showCode) { $code = "  FREQ $($G.Freq) MHz  "; $s0 = [int](($txt.Length - $code.Length) / 2); $txt = $txt.Substring(0, $s0) + $code + $txt.Substring($s0 + $code.Length) }
                Put-Text ($bx + 3) $y $txt $Pal.Signal $Pal.BoxBg
                $y++
            }
            $y++
        }
        Put-Text ($bx + 3) $y ('FREQUENCY: ' + $buf + '_') $Pal.WarmWhite $Pal.BoxBg
        if ($msg) { Put-Text ($bx + 3) ($y + 1) $msg $Pal.Warn $Pal.BoxBg }
        Put-Text ($bx + 3) ($by + $bh - 2) 'ENTER: tune    ESC: step away' $Pal.Dim $Pal.BoxBg
        Flush-Frame
        $k = Get-Key
        if ($null -ne $k) {
            if ($k.Key -eq 'Enter') {
                if (Compare-Freq $buf $G.Freq) { $ok = $true; break } else { $msg = 'Only static.'; $buf = '' }
            }
            elseif ($k.Key -eq 'Escape') { break }
            elseif ($k.Key -eq 'Backspace') { if ($buf.Length -gt 0) { $buf = $buf.Substring(0, $buf.Length - 1) } }
            elseif (($k.KeyChar -ge [char]'0' -and $k.KeyChar -le [char]'9') -or $k.KeyChar -eq [char]'.' -or $k.KeyChar -eq [char]',') { if ($buf.Length -lt 8) { $buf += $k.KeyChar } }
        }
        Start-Sleep -Milliseconds 70
    }
    End-Modal
    return $ok
}

function Event-Archive {
    if ($G.Flags.ch4_archive) { Set-Hint 'Nothing more to hear.' 50; return }
    $opened = $false
    if ($G.ConsentMode -ne 'Inside') {
        $ok = Request-Outside -Action 'open_notepad' -Lines @('The device stored your old messages.', '', 'Open them in a separate window?') -Yes 'OPEN' -No 'SHOW IT HERE'
        if ($ok) {
            $p = Write-RuntimeFile 'signal_archive.txt' ([string[]]$global:Evt.archive_file)
            $opened = Open-InNotepad $p
        }
    }
    if ($opened) { Play-Dialog 'ch4_playing' } else { Play-Signal 'ch4_msg' }
    Set-Flag 'ch4_archive'
}

function Update-Ch5 {
    $G.C5T++
    if (-not $G.Flags.ch5_unlocked -and ($G.C5T % 90) -eq 0 -and (Count-Alive) -lt 7) { Spawn-Enemy }
    if (-not $G.Flags.ch5_hacker -and ($G.C5T -ge 750 -or $G.LockedTries -ge 2)) { Event-Hacker }
}

function Event-Hacker {
    Set-Flag 'ch5_hacker'
    $G.HackerAt = $G.C5T; $G.Glitch = $true
    [void](Write-RuntimeFile 'READ_ME.txt' ([string[]]$global:Evt.readme) -Dir $Root)
    Set-Title 'NULL'
    Play-Dialog 'ch5_warn' -Instant -Hold 0.7
    Play-Dialog 'ch5_null'
    if ($G.ConsentMode -eq 'Inside') { Play-Dialog 'ch5_null_inside' }
    Reset-Title
}

function Event-Hint {
    if ($G.ChapIdx -ne 5 -or -not $G.Flags.ch5_hacker -or $G.ConsentMode -eq 'Inside') { return }
    if (($G.C5T - $G.HackerAt) -lt 1500) { return }
    $ok = Request-Outside -Action 'open_explorer' -Lines @('Open the game folder in File Explorer?') -Yes 'OPEN' -No 'NOT NOW'
    if ($ok) { [void](Open-InExplorer (Join-Path $Root 'READ_ME.txt')) }
}

function Update-Ch6 {
    if (-not $G.DevStarted) {
        $G.DevStarted = $true; $G.DevStartTick = $G.Tick
        Play-Dialog 'ch6_start'
        if ($G.ConsentMode -ne 'Inside') {
            $helperUp = ($G.Children | Where-Object { -not $_.HasExited }).Count -gt 0
            if (-not $helperUp) {
                $ok = Request-Outside -Action 'open_helper' -Lines @('Open the helper in a second window?', '', 'Tip: Win + Left and Win + Right put two windows side by side.') -Yes 'OPEN HELPER' -No 'I HAVE IT'
                if ($ok) { $p = Start-ToolWindow 'helper.ps1' }
            }
        }
        return
    }
    $dev = $G.Dev
    if ($G.PhysAttacks -ge 1 -and -not $G.Seen.slow) { $G.Seen.slow = $true; Play-Dialog 'ch6_slow' }
    if ($G.PhysAttacks -ge 5 -and -not $G.Seen.system) { $G.Seen.system = $true; Play-Dialog 'ch6_system' }
    if ($G.MacroHits -ge 1 -and -not $G.Seen.m1) { $G.Seen.m1 = $true; Play-Dialog 'ch6_firstmacro' }
    if ($G.MacroHits -ge 3 -and -not $G.Seen.m3) { $G.Seen.m3 = $true; Play-Dialog 'ch6_realize' }
    if (-not $G.Seen.hint -and $G.MacroHits -eq 0 -and ($G.Tick - $G.DevStartTick) -gt 2000) {
        $G.Seen.hint = $true
        if ($G.ConsentMode -eq 'Inside') { Play-Dialog 'ch6_hint_inside' } else { Play-Dialog 'ch6_hint' }
    }
    if ($dev -and -not $dev.Alive) { Event-DevDefeat }
}

function Event-DevDefeat {
    $G.Bullets.Clear(); $G.Tele.Clear()
    Play-Dialog 'ch6_end'
    Fade-Out 1.5
    if (-not $G.Headless) { Start-Sleep -Seconds 2 }
    Reset-Dim
    Enter-Chapter 7 -NoCard
}

function Event-Clock {
    $now = Read-Clock
    if ($null -eq $now) { Show-Dialog -Lines @('The clock has stopped.', '', 'That seems fine.') -Color $Pal.WarmWhite; return }
    Show-Dialog -Lines @("It's $($now.ToString('HH:mm')).") -Color $Pal.WarmWhite
    if ($now.Hour -ge 22 -or $now.Hour -lt 5) {
        Show-Dialog -Speaker '[UNKNOWN SIGNAL]' -Lines @("It's late, I think.", '', 'You can stay, or sleep.', 'Either is okay.') -Color $Pal.Signal
    }
}

function Event-EndingComputer {
    $en = $global:End
    $i = Show-Choice -Lines ([string[]]$en.archive_prompt) -Options @('OPEN', 'NOT YET') -Color $Pal.Signal
    if ($i -ne 0) { return }
    Show-Dialog -Lines ([string[]]$en.archive_note) -Color $Pal.Dim
    $n = @($en.logs).Count
    for ($k = 0; $k -lt $n; $k++) {
        $lg = $en.logs[$k]
        $col = Blend-Color $Pal.Signal $Pal.WarmWhite ($k / [double]$n)
        Show-Dialog -Speaker ("LOG #" + $lg.id) -Lines ([string[]]@($lg.lines)) -Color $col -Center
    }
    Run-Letter
    Run-Farewell
}

function Run-Letter {
    $en = $global:End
    $text = @()
    foreach ($pg in $en.letter) { $text += [string[]]@($pg); $text += '' }
    $path = $null; $opened = $false
    if ($G.ConsentMode -ne 'Inside') {
        $ok = Request-Outside -Action 'open_notepad' -Lines @('This last message was written for you.', '', 'Open it in its own window?') -Yes 'OPEN' -No 'READ IT HERE'
        if ($ok) {
            $path = Write-RuntimeFile 'letter.txt' ([string[]]$text)
            $opened = Open-InNotepad $path
        }
    }
    if ($opened) {
        Show-Dialog -Lines @('The letter is open in another window.', '', 'Take your time.', 'Press any key here when you are ready.') -Color $Pal.WarmWhite -Center
    } else {
        $total = @($en.letter).Count
        for ($k = 0; $k -lt $total; $k++) {
            $last = ($k -eq $total - 1)
            if ($last) { Show-Dialog -Speaker 'LOG #100' -Lines ([string[]]@($en.letter[$k])) -Color $Pal.WarmWhite -Center -Hold 7 }
            else { Show-Dialog -Speaker 'LOG #100' -Lines ([string[]]@($en.letter[$k])) -Color $Pal.WarmWhite -Center }
        }
    }
    if ($G.ConsentMode -ne 'Inside') {
        $keep = Request-Outside -Action 'write_desktop_letter' -Lines @('Would you like to keep this letter?', '', 'It would be saved to your Desktop.', 'You can delete it any time.') -Yes 'KEEP' -No 'NO THANKS' -AlwaysAsk
        if ($keep) {
            if (-not $path) { $path = Write-RuntimeFile 'letter.txt' ([string[]]$text) }
            try {
                $dest = Join-Path ([Environment]::GetFolderPath('Desktop')) 'To Whoever Is Reading This.txt'
                Copy-Item -LiteralPath $path -Destination $dest -Force
                Add-Manifest $dest
                Set-Hint 'Saved to your Desktop.' 80
            } catch { Set-Hint 'Could not save the letter.' 80 }
        }
    }
    if ($opened) { Show-Dialog -Lines @(' ') -NoBox -Hold 6 }
}

function Run-Farewell {
    $en = $global:End
    Show-Dialog -Lines ([string[]]$en.still_there) -Color $Pal.WarmWhite -Center
    $i = Show-Choice -Lines ([string[]]$en.stay_prompt) -Options @('STAY', 'LEAVE') -Color $Pal.WarmWhite -Center
    if ($i -eq 0) {
        Show-Dialog -Lines ([string[]]$en.stay) -Color $Pal.WarmWhite -Center
        Set-Title 'ONE MORE DAY - take your time'
        Set-Flag 'ending_stay'
    } else {
        $lines = [string[]]$en.leave
        if ($G.PlayerName) { $lines = $lines | ForEach-Object { if ($_ -eq 'Take care of yourself.') { "Take care of yourself, $($G.PlayerName)." } else { $_ } } }
        Show-Dialog -Lines ([string[]]$lines) -Color $Pal.WarmWhite -Center
        Set-Flag 'ending_leave'
        $G.Running = $false
    }
}
