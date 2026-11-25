<#
.SYNOPSIS
Builds the 3 merged weapon sprite sheets for Nameless Clash:
  1. assets/sprites/weapons_selection_sheet.png  (16x3, 256x128/cell) - All selectable loadout guns
  2. assets/sprites/weapons_floor_sheet.png      (6x1,  256x128/cell) - All floor & treasure-box pickup guns
  3. assets/sprites/weapons_agent_sheet.png      (10x1, 256x128/cell) - All agent signature weapons
Run this script whenever you add or update a weapon sprite!
#>
Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sprDir = Join-Path $root 'assets\sprites'
$wepDir = Join-Path $sprDir 'weapons'
$selOut = Join-Path $sprDir 'weapons_selection_sheet.png'
$baseSelPath = $selOut

function New-Canvas([int]$w, [int]$h) {
  $b = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  return @($b, $g)
}

function Draw-FitCell([System.Drawing.Graphics]$g, [string]$imgPath, [int]$col, [int]$row, [int]$padX = 8, [int]$padY = 6) {
  if (-not (Test-Path $imgPath)) {
    Write-Warning "Missing sprite: $imgPath"
    return
  }
  $bytes = [System.IO.File]::ReadAllBytes($imgPath)
  $ms = [System.IO.MemoryStream]::new($bytes)
  $src = [System.Drawing.Bitmap]::new($ms)
  $maxW = 256 - ($padX * 2)
  $maxH = 128 - ($padY * 2)
  $sc = [Math]::Min($maxW / [double]$src.Width, $maxH / [double]$src.Height)
  $tw = [int][Math]::Round($src.Width * $sc)
  $th = [int][Math]::Round($src.Height * $sc)
  $dx = ($col * 256) + [int][Math]::Round((256 - $tw) * 0.5)
  $dy = ($row * 128) + [int][Math]::Round((128 - $th) * 0.5)
  $g.DrawImage($src, [System.Drawing.Rectangle]::new($dx, $dy, $tw, $th))
  $src.Dispose(); $ms.Dispose()
}

# 1. SELECTION WEAPONS SHEET (16 cols x 3 rows = 4096x384)
# Cols 0..10 preserved from existing weapons_selection_sheet.png (all 3 skin rows)
# Cols 11..15: Nade Gun (18), Stun Gun (19), Suppressed Pistol (20), Black Shotgun (21), M416 (23)
$selExtras = @(
  'nade_gun.png',
  'stun_gun.png',
  'suppressed_pistol.png',
  'black_shotgun.png',
  'm416.png'
)
$selCols = 11 + $selExtras.Count
$res = New-Canvas ($selCols * 256) (3 * 128)
$selBmp = $res[0]; $selG = $res[1]
if (Test-Path $baseSelPath) {
  $oldBytes = [System.IO.File]::ReadAllBytes($baseSelPath)
  $oldMs = [System.IO.MemoryStream]::new($oldBytes)
  $oldBmp = [System.Drawing.Bitmap]::new($oldMs)
  $copyW = [Math]::Min($oldBmp.Width, $selCols * 256)
  $copyH = [Math]::Min($oldBmp.Height, 3 * 128)
  $selG.DrawImage($oldBmp, [System.Drawing.Rectangle]::new(0, 0, $copyW, $copyH), [System.Drawing.Rectangle]::new(0, 0, $copyW, $copyH), [System.Drawing.GraphicsUnit]::Pixel)
  $oldBmp.Dispose(); $oldMs.Dispose()
}
for ($i = 0; $i -lt $selExtras.Count; $i++) {
  $fp = Join-Path $wepDir $selExtras[$i]
  if (Test-Path $fp) {
    for ($r = 0; $r -lt 3; $r++) {
      Draw-FitCell $selG $fp (11 + $i) $r 0 0
    }
  }
}
$selG.Dispose()
$selBmp.Save($selOut, [System.Drawing.Imaging.ImageFormat]::Png)
$selBmp.Dispose()
Write-Output "Built weapons_selection_sheet.png (${selCols}x3 = $($selCols * 256)x384)"

# 2. FLOOR & TREASURE PICKUP WEAPONS SHEET (6 cols x 1 row = 1536x128)
# Col 0: Flamethrower (11), Col 1: Plasma Cannon (13), Col 2: Hook Gun (15),
# Col 3: Bubble Gun (16), Col 4: Machine Gun (17), Col 5: OTs-14 Groza (22)
$floorList = @(
  'flamethrower.png',
  'plasma_cannon.png',
  'hook_gun.png',
  'bubble_gun.png',
  'machine_gun.png',
  'groza.png'
)
$res = New-Canvas ($floorList.Count * 256) 128
$flBmp = $res[0]; $flG = $res[1]
for ($i = 0; $i -lt $floorList.Count; $i++) {
  Draw-FitCell $flG (Join-Path $wepDir $floorList[$i]) $i 0 4 4
}
$flG.Dispose()
$flOut = Join-Path $sprDir 'weapons_floor_sheet.png'
$flBmp.Save($flOut, [System.Drawing.Imaging.ImageFormat]::Png)
$flBmp.Dispose()
Write-Output "Built weapons_floor_sheet.png ($($floorList.Count)x1 = $($floorList.Count * 256)x128)"

# 3. AGENT SIGNATURE WEAPONS SHEET (10 cols x 1 row = 2560x128)
# Col 0: reaper_scythe, Col 1: magma_hammer, Col 2: raven_shadow_bow, Col 3: orc_skull_crusher,
# Col 4: jackson_boxing_glove, Col 5: yagami_katana, Col 6: rook_frost_blade,
# Col 7: afera_tribal_spear, Col 8: bruski_revolver, Col 9: stone_hammer
$agentList = @(
  'reaper_scythe.png',
  'magma_hammer.png',
  'raven_shadow_bow.png',
  'orc_skull_crusher.png',
  'jackson_boxing_glove.png',
  'yagami_katana.png',
  'rook_frost_blade.png',
  'afera_tribal_spear.png',
  'bruski_revolver.png',
  'stone_hammer.png'
)
$res = New-Canvas ($agentList.Count * 256) 128
$agBmp = $res[0]; $agG = $res[1]
for ($i = 0; $i -lt $agentList.Count; $i++) {
  Draw-FitCell $agG (Join-Path $wepDir $agentList[$i]) $i 0 4 4
}
$agG.Dispose()
$agOut = Join-Path $sprDir 'weapons_agent_sheet.png'
$agBmp.Save($agOut, [System.Drawing.Imaging.ImageFormat]::Png)
$agBmp.Dispose()
Write-Output "Built weapons_agent_sheet.png ($($agentList.Count)x1 = $($agentList.Count * 256)x128)"
