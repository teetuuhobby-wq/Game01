<#
Runs the combat toys' tests headless (no window, no sound) and prints a summary.
From the repo root:
  powershell -NoProfile -ExecutionPolicy Bypass -File prototypes/combat_toys/run_tests.ps1
Tests (in tests/):
  action smart     a bot reads the warnings, steps just off the red, rolls through bites: must win
  action idle      standing still: must lose (the beetle is a real challenge)
  action checks    each red warning mark hits exactly where it's drawn; presses during the
                   hit-freeze or a stagger aren't lost; a KO doesn't show "STUCK!"
  turns balance    300 fights each: a smart bot wins most, random play loses most
  turns rules      Sand Sweep with one hero down, Double Snap, the burrowed beetle, the bot's picks
  turns screen     the smart bot plays the real screen to a win (all animations)
  turns losing     a random bot plays the real screen to a loss (the losing screen works)
  menu             held Esc doesn't quit; Esc/R mid-animation doesn't cause errors
A test group fails if Godot exits with an error code, prints no PASS line, prints any FAIL
line, or prints any script or engine error (SCRIPT ERROR, Parse Error, or a line starting ERROR:).
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
	@{ Name = "action checks"; Args = @("--headless", "--path", $p, "--script", "res://tests/action_checks.gd") },
	@{ Name = "turns balance"; Args = @("--headless", "--path", $p, "--script", "res://tests/turns_balance.gd") },
	@{ Name = "turns rules"; Args = @("--headless", "--path", $p, "--script", "res://tests/turns_rules_test.gd") },
	@{ Name = "turns screen"; Args = @("--headless", "--fixed-fps", "60", "--path", $p, "res://tests/turns_test.tscn", "--", "--seed", "1001") },
	@{ Name = "turns losing"; Args = @("--headless", "--fixed-fps", "60", "--path", $p, "res://tests/turns_test.tscn", "--", "--seed", "1005", "--bot", "random") },
	@{ Name = "menu"; Args = @("--headless", "--fixed-fps", "60", "--path", $p, "res://tests/menu_test.tscn") }
)
$errors = "SCRIPT ERROR|Parse Error|^\s*ERROR:"
$failed = 0
foreach ($r in $runs) {
	Write-Output "=== $($r.Name)"
	$out = & $godot @($r.Args) 2>&1 | ForEach-Object { "$_" }
	$code = $LASTEXITCODE
	$out | Where-Object { $_ -match "^(PASS|FAIL)|bot:|$errors" } | ForEach-Object { Write-Output "  $_" }
	$passes = @($out | Where-Object { $_ -match "^PASS" }).Count
	$fails = @($out | Where-Object { $_ -match "^FAIL" }).Count
	$errs = @($out | Where-Object { $_ -match $errors }).Count
	$ok = ($code -eq 0) -and ($passes -gt 0) -and ($fails -eq 0) -and ($errs -eq 0)
	if (-not $ok) { $failed += 1; Write-Output "  -> FAILED (exit code $code, $passes passed, $fails failed, $errs error line(s))" }
}
Write-Output ""
if ($failed -eq 0) { Write-Output "ALL TESTS PASSED" } else { Write-Output "$failed TEST GROUP(S) FAILED" }
exit $failed
