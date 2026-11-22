function New-FakeKey {
    param([ConsoleKey]$Key, [char]$Char = [char]0)
    return [ConsoleKeyInfo]::new($Char, $Key, $false, $false, $false)
}

function Get-Key {
    if ($G.Inject -and $G.Inject.Count -gt 0) { return $G.Inject.Dequeue() }
    if ($G.Headless) { return $null }
    try { if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) } } catch { }
    return $null
}

function Clear-Keys { while ($null -ne (Get-Key)) { } }

function Wait-Key {
    if ($G.Headless) { return (New-FakeKey Enter) }
    while ($true) {
        $k = Get-Key
        if ($null -ne $k) { return $k }
        Start-Sleep -Milliseconds 15
    }
}

function Get-KeyAction {
    param($K)
    switch ($K.Key) {
        'W' { return 'Up' } 'UpArrow' { return 'Up' }
        'S' { return 'Down' } 'DownArrow' { return 'Down' }
        'A' { return 'Left' } 'LeftArrow' { return 'Left' }
        'D' { return 'Right' } 'RightArrow' { return 'Right' }
        'E' { return 'Interact' } 'Spacebar' { return 'Attack' }
        'Escape' { return 'Pause' } 'Tab' { return 'Tab' }
        'Enter' { return 'Enter' } 'H' { return 'Hint' }
    }
    if ($K.KeyChar -eq [char]96) { return 'Console' }
    return $null
}

$global:CmdWhitelist = @('MOVE_L', 'MOVE_R', 'MOVE_U', 'MOVE_D', 'ATTACK', 'UNLOCK', 'PULSE')

function Reset-CommandFile {
    try { [IO.File]::WriteAllText($G.CmdPath, ''); $G.CmdPos = 0 } catch { }
}

function Read-CommandFile {
    try {
        if (-not [IO.File]::Exists($G.CmdPath)) { return }
        $fs = [IO.FileStream]::new($G.CmdPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            if ($fs.Length -lt $G.CmdPos) { $G.CmdPos = 0 }
            if ($fs.Length -eq $G.CmdPos) { return }
            [void]$fs.Seek($G.CmdPos, [IO.SeekOrigin]::Begin)
            $sr = [IO.StreamReader]::new($fs)
            $txt = $sr.ReadToEnd()
            $G.CmdPos = $fs.Length
        } finally { $fs.Dispose() }
        foreach ($line in ($txt -split "`n")) {
            $c = $line.Trim().ToUpperInvariant()
            if ($CmdWhitelist -contains $c) { $G.CmdQ.Enqueue($c) }
        }
    } catch { }
}
