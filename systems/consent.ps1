$global:Whitelist = @('set_title', 'read_window_size', 'read_clock', 'open_notepad', 'open_explorer', 'open_helper', 'open_receiver', 'write_desktop_letter')

function Request-Outside {
    param([string]$Action, [string[]]$Lines, [string]$Yes = 'OPEN', [string]$No = 'NOT NOW', [switch]$AlwaysAsk)
    if ($Whitelist -notcontains $Action) { return $false }
    if ($G.ConsentMode -eq 'Inside') { return $false }
    if ($G.ConsentMode -eq 'Allow' -and -not $AlwaysAsk) { return $true }
    $i = Show-Choice -Lines $Lines -Options @($Yes, $No) -Color $Pal.Signal
    return ($i -eq 0)
}

function Add-Manifest {
    param([string]$Path)
    try { Add-Content -LiteralPath $G.ManifestPath -Value $Path -Encoding utf8 } catch { }
}

function Write-RuntimeFile {
    param([string]$Name, [string[]]$Lines, [string]$Dir = '')
    if (-not $Dir) { $Dir = $G.RuntimeDir }
    $p = Join-Path $Dir $Name
    [IO.File]::WriteAllLines($p, $Lines, [Text.UTF8Encoding]::new($false))
    Add-Manifest $p
    return $p
}

function Test-InsideGame {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    return $full.StartsWith([IO.Path]::GetFullPath($Root), [StringComparison]::OrdinalIgnoreCase)
}

function Open-InNotepad {
    param([string]$Path)
    if (-not (Test-InsideGame $Path) -or -not $IsWindows) { return $false }
    try { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $Path) | Out-Null; return $true } catch { return $false }
}

function Open-InExplorer {
    param([string]$Path)
    if (-not (Test-InsideGame $Path) -or -not $IsWindows) { return $false }
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"{0}"' -f $Path) | Out-Null; return $true } catch { return $false }
}

function Start-ToolWindow {
    param([string]$Script)
    if (-not $IsWindows) { return $null }
    $path = Join-Path $Root "tools/$Script"
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        $exe = Join-Path $PSHOME 'pwsh.exe'
        $psi = [Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $exe
        $psi.UseShellExecute = $true
        foreach ($arg in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path, '-Root', $Root, '-ParentPid', [string]$PID)) {
            [void]$psi.ArgumentList.Add($arg)
        }
        $p = [Diagnostics.Process]::Start($psi)
        [void]$G.Children.Add($p)
        return $p
    } catch { return $null }
}

function Stop-Children {
    foreach ($p in $G.Children) { try { if (-not $p.HasExited) { $p.CloseMainWindow() | Out-Null; Start-Sleep -Milliseconds 150; if (-not $p.HasExited) { $p.Kill() } } } catch { } }
    $G.Children.Clear()
}

function Set-Title { param([string]$Text) try { $Host.UI.RawUI.WindowTitle = $Text } catch { } }
function Reset-Title { Set-Title $G.BaseTitle }

function Read-Clock {
    if ($G.ConsentMode -eq 'Inside') { return $null }
    if ($G.ConsentMode -eq 'Ask') {
        if ($null -eq $G.ClockOk) {
            $i = Show-Choice -Lines @('ONE MORE DAY would like to read the time on your computer.', '', 'It is only shown here and never saved.') -Options @('ALLOW', 'NOT NOW') -Color $Pal.Signal
            $G.ClockOk = ($i -eq 0)
        }
        if (-not $G.ClockOk) { return $null }
    }
    return (Get-Date)
}

function Invoke-Cleanup {
    $n = 0
    if ([IO.File]::Exists($G.ManifestPath)) {
        foreach ($line in [IO.File]::ReadAllLines($G.ManifestPath)) {
            $p = $line.Trim()
            if (-not $p) { continue }
            $deskOk = $p.StartsWith([Environment]::GetFolderPath('Desktop'), [StringComparison]::OrdinalIgnoreCase) -and ([IO.Path]::GetFileName($p) -eq 'To Whoever Is Reading This.txt')
            if ((Test-InsideGame $p) -or $deskOk) {
                try { if ([IO.File]::Exists($p)) { Remove-Item -LiteralPath $p -Force; $n++ } } catch { }
            }
        }
        try { Remove-Item -LiteralPath $G.ManifestPath -Force } catch { }
    }
    foreach ($f in 'command.txt', 'receiver.txt') {
        $p = Join-Path $G.RuntimeDir $f
        try { if ([IO.File]::Exists($p)) { Remove-Item -LiteralPath $p -Force; $n++ } } catch { }
    }
    return $n
}
