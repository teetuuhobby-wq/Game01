<#
Runs all the game's tests headless (no window, no sound, nothing on screen) and prints
a summary. Use after every change to game/. From the repo root:
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1
Tests (in game/tests/ unless noted):
  bot             the test bot plays Mira's errand start to finish (game/bot.gd, --autoplay)
  keys            walking, running, zoom, turning, the fountain blocks you
  stairs          walk and run up and down stairs at a low frame rate (20 FPS)
  first person    switching in and out, walking where you look, camera never in a wall
  flowers         the plaza's flower ring doesn't trap you (playtest 3)
  market          the market street is walkable end to end, busy, and walkers stay on it
  sound           every sound works, the sound board (F4) opens, recordings load
  mood            the mood panel (F5) opens, presets and sliders change the light
  buildings       doors lead in, everything and everyone can be reached and used with E,
                  a bot tours all 5 buildings (guild, tavern, store, bathhouse, workshop)
Exit code 0 = everything passed. Set GODOT to use a different Godot console .exe.
#>
# "Continue": Windows PowerShell treats anything Godot prints to stderr (even harmless
# warnings) as an error, and "Stop" would end the run there.
$ErrorActionPreference = "Continue"
$godot = $env:GODOT
if (-not $godot) {
	$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
}
$game = Join-Path $PSScriptRoot "..\game"
$runs = @(
	@{ Name = "bot"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "--", "--autoplay"); Pass = "BOT: errand done" },
	@{ Name = "keys"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/key_test.tscn", "--", "--no-record") },
	@{ Name = "stairs"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/stair_test.tscn", "--", "--no-record") },
	@{ Name = "first person"; Args = @("--headless", "--fixed-fps", "30", "--path", $game, "res://tests/first_person_test.tscn", "--", "--no-record") },
	@{ Name = "flowers"; Args = @("--headless", "--fixed-fps", "30", "--path", $game, "res://tests/flower_test.tscn", "--", "--no-record") },
	@{ Name = "market"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/market_test.tscn", "--", "--no-record") },
	@{ Name = "sound"; Args = @("--headless", "--path", $game, "res://tests/sound_test.tscn", "--", "--no-record") },
	@{ Name = "mood"; Args = @("--headless", "--path", $game, "res://tests/mood_test.tscn", "--", "--no-record") },
	@{ Name = "buildings"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/facilities_test.tscn", "--", "--no-record") }
)
$failed = 0
foreach ($r in $runs) {
	Write-Output "=== $($r.Name)"
	$out = & $godot @($r.Args) 2>&1 | ForEach-Object { "$_" }
	$code = $LASTEXITCODE
	$out | Where-Object { $_ -match "^(PASS|FAIL)|BOT: (errand|stuck|no|still)|SCRIPT ERROR|Parse Error" } | ForEach-Object { Write-Output "  $_" }
	$ok = ($code -eq 0) -and -not ($out -match "SCRIPT ERROR|Parse Error")
	if ($r.Pass) { $ok = $ok -and ($out -match [regex]::Escape($r.Pass)) }
	if (-not $ok) { $failed += 1; Write-Output "  -> FAILED (exit code $code)" }
}
Write-Output ""
if ($failed -eq 0) { Write-Output "ALL TESTS PASSED" } else { Write-Output "$failed TEST GROUP(S) FAILED" }
exit $failed
