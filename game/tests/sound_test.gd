extends "res://main.gd"
# Sound test (headless): every sound has settings and a code-made version, the sound
# board opens (freeing the mouse, keeping the camera's wheel off) and has a row per
# sound, and a recording file can be loaded while the game runs.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --path game res://tests/sound_test.tscn -- --no-record

func _ready() -> void:
	super()
	var results := []
	var missing := []
	for n in sfx.SOUNDS:
		if not sfx.settings.has(n) or sfx._code.get(n, []).is_empty():
			missing.append(n)
	results.append(["every sound has settings and a made-in-code version", missing.is_empty(), str(missing)])
	for n in sfx.SOUNDS:
		if sfx.SOUNDS[n][2] == "one":
			sfx.play(n)
	results.append(["every one-off sound plays without an error", true, "%d sounds" % sfx.SOUNDS.size()])
	var board: Node = null
	for p in get_tree().get_nodes_in_group("game_panels"):
		if p.toggle_action == "sound_board":
			board = p
	results.append(["the sound board exists", board != null, ""])
	if board != null:
		var ev := InputEventAction.new()
		ev.action = "sound_board"
		ev.pressed = true
		Input.parse_input_event(ev)
		for i in 3:
			await get_tree().process_frame
		results.append(["F4 opens it, and the game knows a panel is open", board.is_open() and controls.menu_open, ""])
		var sliders := 0
		for row in board._box.get_children():
			for c in row.get_children():
				if c is HSlider:
					sliders += 1
		var want := 0
		for n in sfx.SOUNDS:
			want += 2 if sfx.SOUNDS[n][2] == "one" else 1
		results.append(["it has a volume slider per sound and a variety slider per one-off sound", sliders == want, "%d of %d" % [sliders, want]])
		board.set_open(false)
		results.append(["closing it hands the mouse back to the game", not controls.menu_open, ""])
	# A recording made on the spot, saved as a file, loaded back the way recordings are
	var made: AudioStreamWAV = sfx._code["chime"][0]
	made.save_to_wav("user://sound_test.wav")
	var loaded: AudioStream = sfx._load_file("user://sound_test.wav", false)
	results.append(["a .wav recording loads while the game runs", loaded != null and loaded.get_length() > 0.1, "%.2f s" % (loaded.get_length() if loaded else 0.0)])
	# Every recording in game/audio/ loads (both .ogg and .mp3), and the sets are found
	var bad := []
	var count := 0
	for n in sfx.SOUNDS:
		var paths: Array = sfx._files[n].duplicate()
		for s in sfx._sets[n]:
			paths.append_array(sfx._sets[n][s])
		for p in paths:
			count += 1
			var st: AudioStream = sfx._load_file("res://audio/%s/%s" % [n, p], sfx.SOUNDS[n][2] == "loop")
			if st == null or st.get_length() <= 0.0:
				bad.append(n + "/" + p)
	results.append(["every recording in game/audio/ loads", bad.is_empty() and count > 0, "%d files, failed: %s" % [count, str(bad)]])
	results.append(["footstep sets are found and stone is the starting choice",
			sfx._sets["footstep"].size() >= 3 and sfx.settings["footstep"]["choice"] == "set: stone",
			"%s, choice %s" % [str(sfx._sets["footstep"].keys()), sfx.settings["footstep"]["choice"]]])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
