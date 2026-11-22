function Save-Game {
    if ($G.Headless -and -not $G.SaveInTest) { return }
    $o = @{
        Chapter = $G.ChapIdx; X = $G.PX; Y = $G.PY; Hp = $G.Hp; CkX = $G.CkX; CkY = $G.CkY
        Flags = $G.Flags; Freq = $G.Freq; Name = $G.PlayerName
    }
    try { $o | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $G.SavePath -Encoding utf8 } catch { }
}

function Load-Save {
    if (-not [IO.File]::Exists($G.SavePath)) { return $null }
    try { return (Get-Content -LiteralPath $G.SavePath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable) } catch { return $null }
}

function Save-Settings {
    $o = @{ ColorMode = $G.ColorMode; ConsentMode = $G.ConsentMode; FirstRun = $true }
    try { $o | ConvertTo-Json | Set-Content -LiteralPath $G.SettingsPath -Encoding utf8 } catch { }
}

function Load-Settings {
    if (-not [IO.File]::Exists($G.SettingsPath)) { return $false }
    try {
        $s = Get-Content -LiteralPath $G.SettingsPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        if ($s.ColorMode) { $G.ColorMode = $s.ColorMode }
        if ($s.ConsentMode) { $G.ConsentMode = $s.ConsentMode }
        return $true
    } catch { return $false }
}
