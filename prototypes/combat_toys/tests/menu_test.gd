extends "res://main.gd"
## MENU TEST: leaving a toy at awkward moments doesn't break anything.
##   - Holding Esc (key repeat) on the menu doesn't quit the program.
##   - Esc while the turn-based cards are still animating, and R right as a fight is won
##     (the toy is freed while its animations are still waiting on timers).
##   - Esc right after winning the action fight.
## Any engine error printed along the way fails the run (run_tests.ps1 checks for them).
## Run:  <godot_console.exe> --headless --path prototypes/combat_toys res://tests/menu_test.tscn

var _ok := true


func _ready() -> void:
	super()
	await _wait(0.2)
	# 1. A held Esc: the first press leaves the toy, the repeats land on the menu
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	e.echo = true
	_unhandled_input(e)
	await _wait(0.2)
	_check("a repeated (held) Esc on the menu doesn't quit", _menu != null)
	# 2. Turn-based: Esc while a card is still being shown (at a few different moments of it)
	for d in [0.1, 0.3, 0.5, 0.7]:
		start("turns")
		await _wait(1.0)
		_play_first_attack()
		await _wait(d)
		var busy: bool = current.busy
		current.back_to_menu.emit()
		await _wait(1.5)
		_check("turn-based: Esc %.1f s into a card (still animating: %s), back on the menu" % [d, busy], busy and _menu != null)
	# 3. Turn-based: R straight away when the beetle is beaten (the win is still animating)
	for d in [0.6, 0.9, 1.3]:
		start("turns")
		await _wait(1.0)
		current.rules.hp[2] = 1
		current.rules.shell = 0
		_play_first_attack()
		await _wait(d)
		var won: bool = current.rules.result == "win"
		current.restart.emit()
		await _wait(1.5)
		_check("turn-based: R %.1f s after the winning card, a new fight starts" % d, won and current != null and current.rules.result == "")
	# 4. Action: Esc right after the winning hit
	start("action")
	await _wait(0.5)
	current.b_hp = 1
	current._hurt_beetle(5, current.b_pos)
	await _wait(0.1)
	_check("action: the fight is won", current.won)
	current.back_to_menu.emit()
	await _wait(2.0)
	_check("action: back on the menu", _menu != null)
	get_tree().quit(0 if _ok else 1)


## Plays a Strike (put into the first slot of the hand, so it doesn't depend on the shuffle).
func _play_first_attack() -> void:
	current.rules.hand[0] = "strike"
	current._click_card(0)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	_ok = _ok and ok
