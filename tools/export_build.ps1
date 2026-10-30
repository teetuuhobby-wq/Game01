<#
Builds the game for a friend: a Windows zip they unzip and double-click.
From the repo root, in PowerShell:
  & .\tools\export_build.ps1
Makes builds/Strider Home/ (Strider Home.exe, "Play (low quality).bat", README.txt)
and builds/Strider Home.zip to send. builds/ is git-ignored.
What it does:
  1. Marks every recording in game/audio/ as "keep" (a .import file next to it), so the
     export packs the files as they are: the game reads them itself (sfx.gd), and a
     normal import would leave them out of the build.
  2. Exports with the "Windows Desktop" preset (game/export_presets.cfg). Needs Godot's
     export templates for this version (Editor > Manage Export Templates; on the home PC
     they're in %APPDATA%\Godot\export_templates\4.7.2.stable).
  3. Adds the low-quality starter and the README for your friend, then zips it all.
A shared build (OS feature "template") doesn't record playtests, hides F2/F3, shows an
"F6 if it's slow" tip, and saves F4/F5 settings to the player's own folder.
Set GODOT to use a different Godot console .exe.
#>
$ErrorActionPreference = "Stop"
$godot = $env:GODOT
if (-not $godot) {
	$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
}
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$game = Join-Path $root "game"
$out = Join-Path $root "builds\Strider Home"
$zip = Join-Path $root "builds\Strider Home.zip"

# 1. Recordings exported as they are
$keep = "[remap]`n`nimporter=`"keep`"`n"
Get-ChildItem (Join-Path $game "audio") -Recurse -Include *.ogg, *.wav, *.mp3 | ForEach-Object {
	$imp = $_.FullName + ".import"
	if (-not (Test-Path $imp) -or -not ((Get-Content $imp -Raw) -match 'importer="keep"')) {
		[System.IO.File]::WriteAllText($imp, $keep)
	}
}

# 2. Export
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
$exe = Join-Path $out "Strider Home.exe"
# "Continue": Windows PowerShell treats anything Godot prints to stderr (even harmless
# warnings) as an error, and "Stop" would end the build there.
$ErrorActionPreference = "Continue"
& $godot --headless --path $game --export-release "Windows Desktop" $exe 2>&1 | ForEach-Object { "$_" } |
	Where-Object { $_ -match "ERROR|error" -and $_ -notmatch "leaked|Pages in use|RID alloc" }
$ErrorActionPreference = "Stop"
if (-not (Test-Path $exe)) { throw "The export made no .exe (see the errors above)" }

# 3. Extras for your friend, then the zip
[System.IO.File]::WriteAllText((Join-Path $out "Play (low quality).bat"),
	"@echo off`r`nrem For slower computers and laptops: starts in low quality (F6 switches back).`r`nstart `"`" `"%~dp0Strider Home.exe`" -- --quality low`r`n")
Copy-Item (Join-Path $root "tools\friend_readme.txt") (Join-Path $out "README.txt")
Copy-Item (Join-Path $game "audio\CREDITS.md") (Join-Path $out "Sound credits.txt")
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $out -DestinationPath $zip
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
"Built: $zip ($mb MB)"
