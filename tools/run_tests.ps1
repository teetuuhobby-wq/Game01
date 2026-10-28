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
  panels          the wheel scrolls panels, one panel at a time, Esc closes one and gives the mouse back
  buildings       doors lead in, everything and everyone can be reached and used with E,
                  nobody can be talked to through a wall, nobody sits on a seat you can use,
                  a bot tours all 5 buildings (guild, tavern, store, bathhouse, workshop)
  using edges     one press of E does one thing; sitting down while walking doesn't
                  stand you straight back up; sitting lowers your eyes and keeps the
                  valve in hand; residents near the camera are hidden
  quality         low quality (F6, run_low.bat) turns costly effects off; high restores them
  walkabout       a bot walks between random spots all over the city for 1 minute of game
                  time: no stuck spots, height glitches or stranded spots (about 30 s; for
                  the full bug hunt run it on its own with --minutes 60, see soak_test.gd)
  dusk            the dusk scene plays to the end, and replays (--loop and R) start the city
                  exactly where the first run did (about a minute)
  day             the day clock and T, the light over the day and the mood panel's pin, the
                  places' hours, the market by the hour, every resident's routine walked,
                  the end of the day (stop, kneel, "Day 1 done", morning) with you safe on
                  the deck, and nobody popping in or out in view (about a minute)
  make way        a walking resident slows when you step in front, squeezes past after
                  3 s, and slows again the next time you're in the way
Tests that need everyone at their place (the market's full crowd, the residents at
work) start at 14:00 with the clock stopped (-- --hour 14 --freeze-clock); the
mood test starts at 16:00, when the day's light is golden hour.
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
	@{ Name = "market"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/market_test.tscn", "--", "--no-record", "--hour", "14", "--freeze-clock") },
	@{ Name = "sound"; Args = @("--headless", "--path", $game, "res://tests/sound_test.tscn", "--", "--no-record") },
	@{ Name = "mood"; Args = @("--headless", "--path", $game, "res://tests/mood_test.tscn", "--", "--no-record", "--hour", "16", "--freeze-clock") },
	@{ Name = "panels"; Args = @("--headless", "--path", $game, "res://tests/panel_test.tscn", "--", "--no-record") },
	@{ Name = "buildings"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/facilities_test.tscn", "--", "--no-record", "--hour", "14", "--freeze-clock") },
	@{ Name = "using edges"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/use_edge_test.tscn", "--", "--no-record", "--hour", "14", "--freeze-clock") },
	@{ Name = "quality"; Args = @("--headless", "--path", $game, "res://tests/quality_test.tscn", "--", "--no-record", "--hour", "14", "--freeze-clock") },
	@{ Name = "walkabout"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/soak_test.tscn", "--", "--no-record", "--minutes", "1") },
	@{ Name = "dusk"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/dusk_test.tscn", "--", "--no-record", "--loop") },
	@{ Name = "day"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/day_test.tscn", "--", "--no-record") },
	@{ Name = "make way"; Args = @("--headless", "--fixed-fps", "20", "--path", $game, "res://tests/make_way_test.tscn", "--", "--no-record", "--hour", "14", "--freeze-clock") }
)
$failed = 0
foreach ($r in $runs) {
	Write-Output "=== $($r.Name)"
	$out = & $godot @($r.Args) 2>&1 | ForEach-Object { "$_" }
	$code = $LASTEXITCODE
	# PROBLEM lines are the walkabout's problem spots, so a failure says where
	$out | Where-Object { $_ -match "^(PASS|FAIL|PROBLEM)|BOT: (errand|stuck|no|still)|SOAK: stranded|SCRIPT ERROR|Parse Error" } | ForEach-Object { Write-Output "  $_" }
	$ok = ($code -eq 0) -and -not ($out -match "SCRIPT ERROR|Parse Error")
	if ($r.Pass) { $ok = $ok -and ($out -match [regex]::Escape($r.Pass)) }
	if (-not $ok) { $failed += 1; Write-Output "  -> FAILED (exit code $code)" }
}
Write-Output ""
if ($failed -eq 0) { Write-Output "ALL TESTS PASSED" } else { Write-Output "$failed TEST GROUP(S) FAILED" }
exit $failed
