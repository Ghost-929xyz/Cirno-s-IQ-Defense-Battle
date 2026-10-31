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
& $Godot --headless --path $root --script res://tools/export_windows_icon.gd --log-file (Join-Path $root '.tools/icon-export.log') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Icon encoding failed' }
Copy-Item (Join-Path $root 'assets/ui/cirno_avatar.ico') (Join-Path $stage 'assets/ui/cirno_avatar.ico')
$engineVersion = [regex]::Match((& $Godot --version | Out-String), '\d+\.\d+(?:\.\d+)?\.stable').Value
$templateRoots = @((Join-Path (Split-Path $Godot -Parent) 'editor_data/export_templates'), (Join-Path $env:APPDATA 'Godot/export_templates'))
$templateSource = $templateRoots | ForEach-Object { Join-Path $_ "$engineVersion/windows_release_x86_64.exe" } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $templateSource) { throw "Missing Windows export template for $engineVersion" }
$iconTemplate = Join-Path $root '.tools/demo-icon-template.exe'
& (Join-Path $PSScriptRoot 'prepare_windows_icon.ps1') -Template $templateSource -Icon (Join-Path $root 'assets/ui/cirno_avatar.ico') -Destination $iconTemplate
$presets = Get-Content (Join-Path $root 'export_presets.cfg') -Raw
$presets = $presets.Replace('custom_template/release=""', 'custom_template/release="' + $iconTemplate.Replace('\','/') + '"')
Set-Content (Join-Path $stage 'export_presets.cfg') $presets -Encoding utf8
& $Godot --headless --path $stage --editor --import --log-file (Join-Path $root '.tools/demo-import.log') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $Godot --headless --path $stage --export-release 'Windows Demo' (Join-Path $out 'Icefront-Demo.exe') --log-file (Join-Path $root '.tools/demo-export.log') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
Copy-Item (Join-Path $root 'docs/DEMO_README.txt') (Join-Path $out '试玩说明.txt')
Copy-Item (Join-Path $root 'assets/audio/CREDITS.txt') (Join-Path $out '音频素材说明.txt')
Copy-Item (Join-Path $root 'assets/audio/WARSONG_TERMS.txt') (Join-Path $out 'Warsong音频授权条款.txt')
Compress-Archive -Path $out -DestinationPath (Join-Path $root 'exports/Icefront-Demo-Windows.zip') -Force


