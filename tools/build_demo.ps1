param(
    [string]$Godot = 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root '.tools/demo-stage'
$out = Join-Path $root 'exports/Icefront-Demo-Windows'
New-Item -ItemType Directory -Force $stage,$out | Out-Null
foreach ($folder in @('assets','resources','scenes','scripts')) {
    & robocopy (Join-Path $root $folder) (Join-Path $stage $folder) /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copy failed: $folder" }
}
$config = Get-Content (Join-Path $root 'project.godot') -Raw
$config = $config -replace '(?m)^MCPRuntimeServer=.*\r?\n','' -replace '(?m)^_mcp_game_helper=.*\r?\n',''
$config = $config -replace '(?m)^enabled=PackedStringArray\(.*\)','enabled=PackedStringArray()'
$config = $config -replace '(?m)^config/custom_user_dir_name=.*', 'config/custom_user_dir_name="Godot/app_userdata/Icefront-Demo"'
Set-Content (Join-Path $stage 'project.godot') $config -Encoding utf8
Copy-Item (Join-Path $root 'export_presets.cfg') $stage
& $Godot --headless --path $stage --editor --import --log-file (Join-Path $root '.tools/demo-import.log') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $Godot --headless --path $stage --export-release 'Windows Demo' (Join-Path $out 'Icefront-Demo.exe') --log-file (Join-Path $root '.tools/demo-export.log') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
Copy-Item (Join-Path $root 'docs/DEMO_README.txt') (Join-Path $out '试玩说明.txt')
Compress-Archive -Path $out -DestinationPath (Join-Path $root 'exports/Icefront-Demo-Windows.zip') -Force


