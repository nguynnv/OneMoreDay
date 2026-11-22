#requires -Version 7.0
[CmdletBinding()]
param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
$global:Root = $PSScriptRoot
$global:G = @{}


foreach ($f in 'engine/palette.ps1', 'engine/renderer.ps1', 'engine/input.ps1', 'engine/world.ps1', 'engine/dialogue.ps1',
               'engine/save-system.ps1', 'engine/game-loop.ps1',
               'systems/combat.ps1', 'systems/enemy-ai.ps1', 'systems/boss-ai.ps1', 'systems/consent.ps1', 'systems/meta-events.ps1') {
    . (Join-Path $Root $f)
}

function Initialize-Game {
    $cfg = Import-PowerShellDataFile (Join-Path $Root 'config.psd1')

    $G.TickMs = [int]$cfg.TickMs; $G.ColorMode = $cfg.ColorMode; $G.ConsentMode = $cfg.ConsentMode
    $G.MaxHp = [int]$cfg.MaxHp; $G.Cps = [double]$cfg.TypeCps
    $G.RuntimeDir = Join-Path $Root 'runtime'
    if (-not (Test-Path $G.RuntimeDir)) { [void](New-Item -ItemType Directory -Path $G.RuntimeDir) }
    $G.SavePath = Join-Path $G.RuntimeDir 'save.json'
    $G.SettingsPath = Join-Path $G.RuntimeDir 'settings.json'
    $G.CmdPath = Join-Path $G.RuntimeDir 'command.txt'
    $G.ManifestPath = Join-Path $G.RuntimeDir 'MANIFEST.txt'
    $G.Flags = @{}; $G.Freq = ''; $G.PlayerName = ''
    $G.CmdQ = [Collections.Queue]::new(); $G.CmdPos = 0
    $G.Children = [Collections.ArrayList]::new()
    $G.Inject = [Collections.Queue]::new()
    $G.Dim = 0.0; $G.DimColor = 0x777777
    $G.Tick = 0; $G.InWorld = $false; $G.Running = $false; $G.Headless = $false
    $G.Hp = $G.MaxHp; $G.Inv = 0; $G.Cd = 0; $G.PFlash = 0; $G.Hint = ''; $G.HintT = 0
    $G.PhysMiss = 0; $G.MacroHits = 0; $G.PhysAttacks = 0; $G.Seen = @{}
    $G.ClockOk = $null; $G.ReceiverProc = $null; $G.Glitch = $false; $G.FogOn = $false
    $G.CamX = 0; $G.CamY = 0; $G.TooSmall = $false; $G.LastWin = -1000
    $G.Clock = [Diagnostics.Stopwatch]::StartNew()
    $G.BaseTitle = 'ONE MORE DAY'
    $enc = 'utf8'
    $global:Dlg = Get-Content -LiteralPath (Join-Path $Root 'story/dialogues.json') -Raw -Encoding $enc | ConvertFrom-Json
    $global:End = Get-Content -LiteralPath (Join-Path $Root 'story/endings.json') -Raw -Encoding $enc | ConvertFrom-Json
    $global:Evt = Get-Content -LiteralPath (Join-Path $Root 'story/events.json') -Raw -Encoding $enc | ConvertFrom-Json
    $G.FirstRunDone = Load-Settings
    $G.WinW = 120; $G.WinH = 34
    Initialize-Frame 120 34
}

function Enter-Terminal {
    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
    try { $G.OrigTitle = $Host.UI.RawUI.WindowTitle } catch { $G.OrigTitle = 'PowerShell' }
    Set-Title $G.BaseTitle
    Write-Out "`e[?1049h`e[?25l`e[0m"

    try { $ws = $Host.UI.RawUI.WindowSize; $G.WinW = [int]$ws.Width; $G.WinH = [int]$ws.Height } catch { }
    $G.TooSmall = ($G.WinW -lt 80 -or $G.WinH -lt 26)
    Initialize-Frame ([math]::Min($G.WinW, 120)) ([math]::Min($G.WinH, 34))
    Set-TerminalBg $Pal.Bg
    $G.LastWin = $G.Clock.ElapsedMilliseconds
}

function Exit-Terminal {
    Stop-Children
    Write-Out "`e[0m`e[?25h`e[?1049l"
    try { $Host.UI.RawUI.WindowTitle = $G.OrigTitle } catch { }
}

function Select-Menu {
    param([string[]]$Options, [int]$Sel = 0, [string]$Footer = 'W/S move    ENTER select')
    $G.InWorld = $false

    while ($true) {
        Update-Window
        if ($G.TooSmall) { Show-TooSmall; Start-Sleep -Milliseconds 200; continue }
        Clear-Frame $Pal.Bg

        $y0 = [math]::Max(1, [int]($G.FH / 2) - 7)
        $title = 'O N E   M O R E   D A Y'
        Put-Text ([int](($G.FW - $title.Length) / 2)) $y0 $title $Pal.Catherine
        $sub = 'a small game about giving yourself one more day'
        Put-Text ([int](($G.FW - $sub.Length) / 2)) ($y0 + 2) $sub $Pal.Dim

        for ($i = 0; $i -lt $Options.Count; $i++) {
            $txt = if ($i -eq $Sel) { "> $($Options[$i]) <" } else { $Options[$i] }
            $col = if ($i -eq $Sel) { $Pal.Catherine } else { $Pal.Text }
            Put-Text ([int](($G.FW - $txt.Length) / 2)) ($y0 + 5 + $i * 2) $txt $col
        }
        Put-Text ([int](($G.FW - $Footer.Length) / 2)) ($G.FH - 2) $Footer 0x4A5362
        Flush-Frame
        $k = $null

        while ($null -eq $k) { $k = Get-Key; if ($null -eq $k) { Start-Sleep -Milliseconds 30; Update-Window; if ($G.TooSmall) { break } } }
        if ($null -eq $k) { continue }
        $a = Get-KeyAction $k
        if ($a -eq 'Up') { $Sel = ($Sel + $Options.Count - 1) % $Options.Count }
        elseif ($a -eq 'Down') { $Sel = ($Sel + 1) % $Options.Count }
        elseif ($a -in 'Enter', 'Interact', 'Attack') { return $Sel }
    }
}

function Get-ConsentLabel {
    switch ($G.ConsentMode) { 'Allow' { 'ALLOW' } 'Inside' { 'KEEP IT ALL INSIDE THE GAME' } default { 'ASK EACH TIME' } }
}

function Show-Settings {
    $sel = 0
    while ($true) {
        $opts = @("COLORS: $($G.ColorMode)", "OUTSIDE THE WINDOW: $(Get-ConsentLabel)", 'BACK')
        $sel = Select-Menu $opts $sel 'ENTER changes the selected setting'
        if ($sel -eq 0) {
            $modes = @('TrueColor', '256', '16', 'Off')
            $G.ColorMode = $modes[(([array]::IndexOf($modes, $G.ColorMode)) + 1) % 4]
            Save-Settings
        }
        elseif ($sel -eq 1) {
            $modes = @('Ask', 'Allow', 'Inside')
            $G.ConsentMode = $modes[(([array]::IndexOf($modes, $G.ConsentMode)) + 1) % 3]
            Save-Settings
        }
        else { return }
    }
}

function Show-FirstRun {
    $G.InWorld = $false
    Clear-Frame $Pal.Bg
    $i = Show-Choice -Center -Color $Pal.Signal -Default 1 -Lines @(
        'ONE MORE DAY would like to step outside this window a few times.', '',
        'It will always ask first.',
        'It only opens windows you can see,',
        'and only touches files inside its own folder',
        '(plus one letter on your Desktop, if you want it).', '',
        'Some messages later on will look like warnings.',
        "They're part of the story. Nothing is being hacked.") -Options @('ALLOW', 'ASK EACH TIME', 'KEEP IT ALL INSIDE THE GAME')
    $G.ConsentMode = @('Allow', 'Ask', 'Inside')[$i]
    Save-Settings
    $G.FirstRunDone = $true
}

function Show-Menu {
    if (-not $G.FirstRunDone) { Show-FirstRun }
    $sel = 0
    while ($true) {
        $hasSave = [IO.File]::Exists($G.SavePath)
        $opts = @(); if ($hasSave) { $opts += 'CONTINUE' }
        $opts += 'NEW GAME', 'SETTINGS', 'CLEAN UP', 'QUIT'
        $sel = Select-Menu $opts 0
        switch ($opts[$sel]) {
            'CONTINUE' { [void](Continue-Game) }
            'NEW GAME' {
                $go = $true
                if ($hasSave) { $go = ((Show-Choice -Lines @('Start over?', 'Your saved progress will be replaced.') -Options @('START OVER', 'CANCEL') -Color $Pal.Catherine -Default 1) -eq 0) }
                if ($go) {
                    $nm = Read-TextOverlay -Lines @('What should I call you?', '(Press Enter to skip)') -Label '> ' -MaxLen 20 -Color $Pal.Catherine
                    $G.PlayerName = if ($nm) { $nm.Trim() } else { '' }
                    Start-NewGame
                }
            }
            'SETTINGS' { Show-Settings }
            'CLEAN UP' {
                $yes = ((Show-Choice -Lines @('Remove everything ONE MORE DAY created outside its', 'save file: the letter on your Desktop, temporary', 'text files, and the command queue?') -Options @('REMOVE', 'CANCEL') -Color $Pal.Signal -Default 1) -eq 0)
                if ($yes) { $n = Invoke-Cleanup; Show-Dialog -Lines @("Removed $n file(s).") -Color $Pal.Text }
            }
            'QUIT' { return }
        }
        Stop-Children
        Reset-Title; Reset-Dim
        Set-TerminalBg $Pal.Bg
    }
}

function Invoke-SelfTest {
    $G.Headless = $true; $G.ConsentMode = 'Inside'; $G.WinW = 120; $G.WinH = 34
    Initialize-Frame 120 34
    $G.Headless = $true; $G.ConsentMode = 'Inside'
    $global:SelfFail = 0; $G.Running = $true
    function Assert { param([bool]$Cond, [string]$Msg) if ($Cond) { Write-Host "  ok   $Msg" } else { Write-Host "  FAIL $Msg" -ForegroundColor Red; $global:SelfFail++ } }
    function Dump-Frame {
        $rows = for ($y = 0; $y -lt $G.FH; $y++) { (-join $G.Ch[($y * $G.FW)..(($y + 1) * $G.FW - 1)]).TrimEnd() }
        ($rows | Where-Object { $_ }) -join "`n"
    }
    Assert ($Dlg.ch1_msg1.pages.Count -eq 3) 'dialogues.json loads'
    Assert (@($End.logs).Count -eq 7) 'endings.json logs'
    Assert (@($End.letter).Count -eq 7) 'endings.json letter pages'
    $keysets = @('W', 'A', 'S', 'D', 'Spacebar', 'E')
    $rnd = [Random]::new(5)
    foreach ($n in 1..7) {
        $G.Flags = @{}
        Enter-Chapter $n -NoCard
        $G.InWorld = $true
        try {
            for ($t = 0; $t -lt 250; $t++) {
                $k = New-FakeKey ([ConsoleKey]$keysets[$rnd.Next($keysets.Count)])
                Step-Game @($k)
                if ($t % 25 -eq 0) { Flush-Frame }
            }
            Assert $true "chapter $n runs 250 ticks"
        } catch { Assert $false "chapter $n threw: $($_.Exception.Message) @ $($_.InvocationInfo.PositionMessage)" }
        if ($n -in 1, 2, 4, 6) { Write-Host (Dump-Frame) }
    }
    $G.Flags = @{}; Enter-Chapter 6 -NoCard; $G.InWorld = $true
    Step-Game @()
    $dev = $G.Dev
    $G.Bullets.Clear(); $G.Tele.Clear()
    $dev.X = 37; $dev.Y = 7; $G.PX = 33; $G.PY = 7; $G.FX = 1; $G.FY = 0; $hp0 = $dev.Hp
    foreach ($i in 1..3) { Step-Game @((New-FakeKey Spacebar)); $G.Tele.Clear() }
    for ($i = 0; $i -lt 6; $i++) { Step-Game @() }
    Assert ($dev.Hp -eq $hp0) 'physical attacks never damage the Developer'
    $dev.X = 37; $dev.Y = 7; $G.PX = 33; $G.PY = 7; $G.FX = 1; $G.FY = 0; $G.Bullets.Clear(); $G.Hp = 5; $G.Inv = 999
    1..3 | ForEach-Object { $G.CmdQ.Enqueue('ATTACK') }
    for ($i = 0; $i -lt 10; $i++) { Step-Game @(); $G.Tele.Clear() }
    Assert ($dev.Hp -lt $hp0) 'command attacks damage the Developer'
    $G.Flags = @{}; Enter-Chapter 5 -NoCard; $G.InWorld = $true
    $G.CmdQ.Enqueue('UNLOCK'); Step-Game @()
    Assert ($G.Flags.ch5_unlocked -eq $true -and $G.ExitReady) 'UNLOCK opens the doors and the exit'
    Assert (Compare-Freq '98,4' '98.4') 'frequency compare accepts comma'
    Assert (-not (Compare-Freq '98.5' '98.4')) 'frequency compare rejects wrong value'
    Assert (-not (Compare-Freq '984' '98.4')) 'frequency compare rejects missing decimal separator'
    Assert (-not (Compare-Freq '98.4.0' '98.4')) 'frequency compare rejects malformed value'
    Assert (-not (Request-Outside -Action 'open_notepad' -Lines @('x'))) 'INSIDE mode refuses outside actions'
    Assert (-not (Request-Outside -Action 'delete_everything' -Lines @('x'))) 'actions outside the whitelist are refused'
    $G.Flags = @{}; Enter-Chapter 7 -NoCard; $G.InWorld = $true
    try { Event-EndingComputer; Assert $true 'ending sequence runs' } catch { Assert $false "ending threw: $($_.Exception.Message)" }
    Write-Host ''
    if ($global:SelfFail -eq 0) { Write-Host 'SELFTEST OK' -ForegroundColor Green } else { Write-Host "SELFTEST FAILED ($($global:SelfFail))" -ForegroundColor Red; exit 1 }
}

Initialize-Game
if ($SelfTest) { Invoke-SelfTest; return }
if (-not $IsWindows) { Write-Host 'ONE MORE DAY is written for Windows Terminal. It will try to run anyway.' }
try {
    Enter-Terminal
    Show-Menu
} finally {
    Exit-Terminal
}
