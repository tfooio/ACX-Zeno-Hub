# Mirror acx.luau into the executor workspace (readfile cannot reach this folder). autoexec\acx.lua loads that copy.
$src = Split-Path $PSScriptRoot -Parent
$dst = Join-Path $env:LOCALAPPDATA "Potassium\workspace\AnimeChampionsX"
New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item (Join-Path $src "acx.luau") $dst -Force
Write-Output "synced to $dst"
