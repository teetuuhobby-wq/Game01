extends "res://main.gd"
# Sound test (headless): every sound has settings and a code-made version, every one-off
# sound plays, the sound board opens (freeing the mouse, keeping the camera's wheel off)
# and has a row per sound, recordings load, a looping sound only restarts when you pick
# something new, and the city creaks now and then but never twice within the gap.
# Starting choices are checked against your saved ones once you've pressed Save on the board.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --path game res://tests/sound_test.tscn -- --no-record

const Tuning := preload("res://tuning.gd")


func _ready() -> void:
	super()
	var results := []
	var missing := []
	for n in sfx.SOUNDS:
		var code_ok: bool = n in ["creak", "town"] or not sfx._code.get(n, []).is_empty()
		if not sfx.settings.has(n) or not code_ok:
			missing.append(n)
	results.append(["every sound has settings, and a made-in-code version unless it's recordings-only", missing.is_empty(), str(missing)])
	# Each one-off sound starts a player with a sound in it (or nothing, if it's set to "off")
	var silent := []
	var played := 0
	for n in sfx.SOUNDS:
		if sfx.SOUNDS[n][2] == "one":
			var p: AudioStreamPlayer = sfx.play(n)
			if sfx.settings[n]["choice"] == "off":
				if p != null:
					silent.append(n + " (is off, but played)")
			elif p == null or p.stream == null or not p.playing:
				silent.append(n)
			else:
				played += 1
	results.append(["every one-off sound plays", silent.is_empty() and played > 0, "%d played, didn't: %s" % [played, str(silent)]])
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
	results.append(["footstep sets are found and stone is the starting choice (or your saved one)",
			sfx._sets["footstep"].size() >= 3 and sfx.settings["footstep"]["choice"] == _starts_on("footstep", "set: stone"),
			"%s, choice %s" % [str(sfx._sets["footstep"].keys()), sfx.settings["footstep"]["choice"]]])
	var want_rec := {"wind": "825860_vrymaa_dune_loop.wav", "bell": "378799_kgeshev_bell.wav",
			"town": "818390_sounds_from_palestine_village_loop.wav", "creak": "all"}
	var wrong := []
	for n in want_rec:
		if sfx.settings[n]["choice"] != _starts_on(n, want_rec[n]):
			wrong.append("%s = %s" % [n, sfx.settings[n]["choice"]])
	results.append(["wind, bell, town and creak start on the Freesound recordings (or your saved ones)", wrong.is_empty(), str(wrong)])
	results.append(["the city has 4 creaks to pick from", sfx._files["creak"].size() == 4, str(sfx._files["creak"].size())])
	var town: AudioStreamPlayer = sfx._loops["town"]
	results.append(["town life is playing, as a seamless loop", town.playing and town.stream is AudioStreamWAV
			and town.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, ""])
	# A looping sound set to "all" picks a random recording; moving its volume slider
	# mustn't pick again (it used to restart on a different recording at every step)
	var crowd: AudioStreamPlayer = sfx._loops["crowd"]
	var keep: Dictionary = sfx.settings["crowd"].duplicate()
	sfx.settings["crowd"]["choice"] = "all"
	sfx.refresh_loop("crowd")
	var first: AudioStream = crowd.stream
	var changed := 0
	for i in 12:
		sfx.settings["crowd"]["db"] = -20.0 + i
		sfx.refresh_loop("crowd")
		if crowd.stream != first or not crowd.playing:
			changed += 1
	results.append(["moving a looping sound's volume doesn't restart it on another recording", first != null and changed == 0,
			"restarted %d of 12 times" % changed])
	for f in sfx._files["crowd"]:
		if sfx._load_file("res://audio/crowd/" + f, true) != first:
			sfx.settings["crowd"]["choice"] = f
			break
	sfx.refresh_loop("crowd")
	results.append(["picking another recording does switch it", crowd.stream != first and crowd.playing, sfx.settings["crowd"]["choice"]])
	sfx.settings["crowd"] = keep
	sfx.refresh_loop("crowd")
	# Creaks: a giant step makes the city creak now and then, but never twice within the gap
	sfx.settings["creak"]["choice"] = "all"
	var creaks := []
	for f in sfx._files["creak"]:
		creaks.append(sfx._load_file("res://audio/creak/" + f, false))
	var want_creak := 1 if Tuning.CREAK_CHANCE > 0.0 else 0
	sfx._creak_wait = 0.0
	var got: int = await _creaks_after_stomps(creaks)
	results.append(["giant steps make the city creak, once (the gap stops the rest)", got == want_creak, "%d creaks from 40 steps" % got])
	got = await _creaks_after_stomps(creaks)
	results.append(["no creak again until the gap has passed", got == 0, "%d creaks, %.1f s of the gap left" % [got, sfx._creak_wait]])
	var waited := 0.0
	while sfx._creak_wait > 0.0 and waited < Tuning.CREAK_GAP + 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	got = await _creaks_after_stomps(creaks)
	results.append(["after the gap it can creak again", got == want_creak, "%d creaks after waiting %.1f s" % [got, waited]])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)


## The choice a sound should start on: the expected one, unless you saved another
## on the sound board (and its recording is still there).
func _starts_on(n: String, expected: String) -> String:
	if not FileAccess.file_exists(sfx.SETTINGS):
		return expected
	var saved = JSON.parse_string(FileAccess.get_file_as_string(sfx.SETTINGS))
	if saved is Dictionary and saved.get(n) is Dictionary and saved[n].has("choice"):
		var c := str(saved[n]["choice"])
		if c in sfx.choices(n):
			return c
	return expected


## Stomps 40 times at once, waits for the creaks to start, and counts the new ones.
func _creaks_after_stomps(creaks: Array) -> int:
	var before := sfx.get_children()
	for i in 40:
		sfx.stomp()
	await get_tree().create_timer(0.6).timeout
	var n := 0
	for c in sfx.get_children():
		if c is AudioStreamPlayer and not c in before and c.stream in creaks:
			n += 1
	return n
