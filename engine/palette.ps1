$global:Pal = @{
    Bg        = 0x0B0D12
    Text      = 0xD9DEE7
    Dim       = 0x6B7686
    Catherine = 0xFFB86B
    Signal    = 0x7FDBCA
    Npc       = 0xC3A6FF
    Enemy     = 0xE5735C
    Gold      = 0xFFD166
    Warn      = 0xFF6B6B
    Neon      = 0x39FF14
    Magenta   = 0xFF2BD6
    Dev       = 0xFF4D4D
    DevWhite  = 0xF5F5F5
    Water     = 0x3A6EA5
    WarmWhite = 0xF2E6D0
    Fog       = 0x9AA7B4
    BoxBg     = 0x0A0C10
}

$global:Gl = @{
    Floor = [char]0x00B7; Wall = [char]'#'; Water = [char]0x2248; Door = [char]0x25A3
    Check = [char]0x25C6; Exit = [char]0x00BB; Device = [char]0x00A4; Bench = [char]0x2550
    Fog = [char]0x2591; Clock = [char]0x0398; Enemy = [char]0x03A9; Boss = [char]0x03A8
    Heart = [char]0x2665; Cue = [char]0x25BC; Bullet = [char]0x2022; Full = [char]0x2588
    Light = [char]0x2591; Mid = [char]0x2592; Dark = [char]0x2593
}

function Blend-Color {
    param([int]$A, [int]$B, [double]$T)
    $ar = ($A -shr 16) -band 255; $ag = ($A -shr 8) -band 255; $ab = $A -band 255
    $br = ($B -shr 16) -band 255; $bgn = ($B -shr 8) -band 255; $bb = $B -band 255
    $rr = [int]($ar + ($br - $ar) * $T); $gg = [int]($ag + ($bgn - $ag) * $T); $bl = [int]($ab + ($bb - $ab) * $T)
    return (($rr -shl 16) -bor ($gg -shl 8) -bor $bl)
}

$global:EscCache = @{}
function Get-Esc {
    param([int]$Rgb, [bool]$IsBg)
    $lvl = [int]([math]::Round($G.Dim * 8))
    $key = "$Rgb/$([int]$IsBg)/$lvl/$($G.DimColor)/$($G.ColorMode)"
    $hit = $EscCache[$key]
    if ($null -ne $hit) { return $hit }
    $c = $Rgb
    if ($lvl -gt 0) { $c = Blend-Color $c $G.DimColor ($lvl / 8.0) }
    $cr = ($c -shr 16) -band 255; $cg = ($c -shr 8) -band 255; $cb = $c -band 255
    $esc = ''
    switch ($G.ColorMode) {
        'Off' { $esc = '' }
        '256' {
            $ri = [int][math]::Round($cr / 255.0 * 5); $gi = [int][math]::Round($cg / 255.0 * 5); $bi = [int][math]::Round($cb / 255.0 * 5)
            $idx = 16 + 36 * $ri + 6 * $gi + $bi
            $pre = if ($IsBg) { 48 } else { 38 }
            $esc = "`e[$pre;5;${idx}m"
        }
        '16' {
            $idx = 0
            if ($cr -gt 110) { $idx += 1 }
            if ($cg -gt 110) { $idx += 2 }
            if ($cb -gt 110) { $idx += 4 }
            $lum = 0.3 * $cr + 0.59 * $cg + 0.11 * $cb
            $code = (if_bg $IsBg) + $idx
            if ($lum -gt 170) { $code += 60 }
            $esc = "`e[${code}m"
        }
        default {
            $pre = if ($IsBg) { 48 } else { 38 }
            $esc = "`e[$pre;2;$cr;$cg;${cb}m"
        }
    }
    $EscCache[$key] = $esc
    return $esc
}
function if_bg { param([bool]$IsBg) if ($IsBg) { return 40 } else { return 30 } }
