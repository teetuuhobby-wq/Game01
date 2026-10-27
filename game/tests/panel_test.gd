extends "res://main.gd"
# Panel test (headless): the sound board (F4) and mood panel (F5) behave. The mouse wheel
# scrolls a panel instead of changing a slider, only one panel is open at a time, Esc
# closes a panel and hands the mouse back the way it was, and Esc goes to the F2 note box
# while you're typing a note.
# Headless Godot doesn't pass pretend key presses on to the game, so this hands each key
# straight to the panels, the way the game would.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --path game res://tests/panel_test.tscn -- --no-record

var panels := {}   # key action -> panel


func _ready() -> void:
	process_priority = -200   # press keys before the controls read them
	super()
	var results := []
	for p in get_tree().get_nodes_in_group("game_panels"):
		panels[p.toggle_action] = p
	results.append(["both panels exist", panels.has("sound_board") and panels.has("mood"), str(panels.keys())])
	if results[0][1]:
		_check(results)
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)


func _check(results: Array) -> void:
	var board: Node = panels["sound_board"]
	var mood: Node = panels["mood"]
	# The mouse wheel: no slider takes it, so it scrolls the panel (playtest bug M1)
	var wheel_sliders := 0
	var sliders := 0
	for p in [board, mood]:
		for row in p._box.get_children():
			for c in row.get_children():
				if c is HSlider:
					sliders += 1
					if c.scrollable:
						wheel_sliders += 1
	results.append(["the mouse wheel never changes a slider", sliders > 0 and wheel_sliders == 0, "%d of %d sliders take the wheel" % [wheel_sliders, sliders]])

	# One panel at a time (M4)
	controls.mouse_was_captured = true   # left over from before: opening a panel must look again
	_press("sound_board")
	results.append(["F4 opens the sound board", board.is_open() and controls.menu_open, ""])
	results.append(["opening it remembers whether the game had the mouse (here it didn't: a headless run never has it)",
			not controls.mouse_was_captured, ""])
	controls.mouse_was_captured = true   # now pretend the game had the mouse
	_press("mood")
	results.append(["F5 while the sound board is open shows the mood panel, and closes the board",
			mood.is_open() and not board.is_open() and controls.menu_open, "board %s, mood %s" % [board.is_open(), mood.is_open()]])
	results.append(["switching panels still remembers the game had the mouse", controls.mouse_was_captured, ""])
	_press("sound_board")
	results.append(["and F4 back again swaps them back", board.is_open() and not mood.is_open(), ""])

	# Esc closes the panel and hands the game back as it was (M2)
	_press("quit")
	results.append(["Esc closes the panel and hands the game back", not board.is_open() and not mood.is_open() and not controls.menu_open, ""])
	controls.mouse_was_captured = false
	_press("mood")
	_press("mood")
	results.append(["a panel's own key closes it too", not mood.is_open() and not controls.menu_open, ""])

	# Typing an F2 note with a panel open: Esc is for the note box, not the panel
	_press("sound_board")
	controls.typing = true
	_press("quit")
	results.append(["Esc while typing a note leaves the panel open (the note box gets it)", board.is_open(), ""])
	controls.typing = false
	_press("quit")
	results.append(["after the note, Esc closes the panel again", not board.is_open() and not controls.menu_open, ""])


## A key press handed to every panel, as the game would.
func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	for p in get_tree().get_nodes_in_group("game_panels"):
		p._input(ev)
