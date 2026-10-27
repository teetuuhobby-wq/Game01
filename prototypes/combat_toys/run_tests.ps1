<#
Runs the combat toys' tests headless (no window, no sound) and prints a summary.
From the repo root:
  powershell -NoProfile -ExecutionPolicy Bypass -File prototypes/combat_toys/run_tests.ps1
Tests (in tests/):
  action smart     a bot reads the warnings, rolls, hits it while stuck: must win
  action idle      standing still: must lose (the beetle is a real challenge)
  turns balance    300 fights each: a smart bot wins most, random play loses most
  turns screen     the smart bot plays the real screen to a win (all animations)
  turns losing     a random bot plays the real screen to the end (the losing screen works)
Exit code 0 = everything passed. Set GODOT to use a different Godot console .exe.
#>
$ErrorActionPreference = "Continue"
$godot = $env:GODOT
if (-not $godot) {
	$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
}
$p = $PSScriptRoot
$runs = @(
	@{ Name = "action smart"; Args = @("--headless", "--fixed-fps", "60", "--path", $p, "res://tests/action_test.tscn", "--", "--bot", "smart") },
	@{ Name = "action idle"; Args = @("--headless", "--fixed-fps", "60", "--path", $p, "res://tests/action_test.tscn", "--", "--bot", "idle") },
	@{ Name = "turns balance"; Args = @("--headless", "--path", $p, "--script", "res://tests/turns_balance.gd") },
	@{ Name = "turns screen"; Args = @("--headless", "--fixed-fps", "60", "--path", $p, "res://tests/turns_test.tscn", "--", "--seed", "1001") },
	@{ Name = "turns losing"; Args = @("--headless", "--fixed-fps", "60", "--path", $p, "res://tests/turns_test.tscn", "--", "--seed", "1005", "--bot", "random") }
)
$failed = 0
foreach ($r in $runs) {
	Write-Output "=== $($r.Name)"
	$out = & $godot @($r.Args) 2>&1 | ForEach-Object { "$_" }
	$code = $LASTEXITCODE
	$out | Where-Object { $_ -match "^(PASS|FAIL)|bot:|SCRIPT ERROR|Parse Error" } | ForEach-Object { Write-Output "  $_" }
	$ok = ($code -eq 0) -and -not ($out -match "SCRIPT ERROR|Parse Error")
	if (-not $ok) { $failed += 1; Write-Output "  -> FAILED (exit code $code)" }
}
Write-Output ""
if ($failed -eq 0) { Write-Output "ALL TESTS PASSED" } else { Write-Output "$failed TEST GROUP(S) FAILED" }
exit $failed
