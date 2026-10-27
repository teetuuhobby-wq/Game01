extends "res://main.gd"
# Mood test (headless): F5 opens the mood panel with a slider per setting, presets
# change the light, a slider change reaches the world, and the default look is golden hour.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --path game res://tests/mood_test.tscn -- --no-record

func _ready() -> void:
	super()
	var results := []
	var mood: Node = null
	var panel: Node = null
	for c in get_children():
		if c.get_script() == preload("res://mood.gd"):
			mood = c
	for p in get_tree().get_nodes_in_group("game_panels"):
		if p.toggle_action == "mood":
			panel = p
	results.append(["the mood and its panel exist", mood != null and panel != null, ""])
	if mood == null or panel == null:
		_finish(results)
		return
	# The sky starts with a sun colour of its own; only the mood gives it the warmth from
	# its values, so this shows the mood really was put on the world at start-up.
	var want_colour: Color = mood._sun_colour(mood.values["sun_warmth"])
	var applied: bool = world.sun.light_color.is_equal_approx(want_colour) and is_equal_approx(world.sun.light_energy, mood.values["sun_brightness"])
	var golden: bool = FileAccess.file_exists(mood.SAVED) or mood.values == mood.PRESETS["Golden hour"]
	results.append(["the game starts golden hour (unless a saved look exists), put on by the mood",
			applied and golden, "sun %.2f, colour %s" % [world.sun.light_energy, world.sun.light_color]])
	var ev := InputEventAction.new()
	ev.action = "mood"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 3:
		await get_tree().process_frame
	results.append(["F5 opens the mood panel", panel.is_open() and controls.menu_open, ""])
	results.append(["it has a slider per setting", panel._sliders.size() == mood.SLIDERS.size(), "%d" % panel._sliders.size()])
	panel._preset("Night")
	results.append(["the Night preset darkens the sun and sky", world.sun.light_energy < 0.5 and world.sky_mat.energy_multiplier < 0.1,
			"sun %.2f, sky %.2f" % [world.sun.light_energy, world.sky_mat.energy_multiplier]])
	panel._sliders["haze"].value = 0.005
	results.append(["dragging a slider changes the world", is_equal_approx(world.env.fog_density, 0.005), "haze %.4f" % world.env.fog_density])
	panel.set_open(false)
	results.append(["closing it hands the mouse back", not controls.menu_open, ""])
	_finish(results)


func _finish(results: Array) -> void:
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
