extends "res://main.gd"
# Playtest 4's quick fixes (headless):
#   - a walking neighbour keeps walking past you (no stopping to stare), and only waits
#     when you're right in their way
#   - a conversation ends: after someone's last line the hint says goodbye, the next E
#     closes it, and talking again starts from the top
#   - Esc opens the menu and pauses the game; Esc again carries on; the volume slider
#     changes the game's loudness and is remembered
# Run: <godot_console.exe> --headless --path game res://tests/quick_fixes_test.tscn -- --no-record

const Dialogue := preload("res://dialogue.gd")

var results := []


func _ready() -> void:
	super()
	_check_walkers()
	_check_goodbye()
	await _check_menu()
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)


## Moves one plaza walker on for a while, you standing at `offset` from them (in their
## own frame: x ahead, z to the side). Gives back how far they walked.
func _walk_past(w: Dictionary, ahead: float, side: float) -> float:
	var node: Node3D = w["node"]
	w["wait"] = 0.0
	w["ta"] = w["a"] + 1.5   # somewhere to go
	var start := node.position
	for i in 20:
		var f := Vector3(cos(node.rotation.y), 0.0, -sin(node.rotation.y))
		var s := Vector3(-f.z, 0.0, f.x)
		player.position = node.position + f * ahead + s * side
		world._update_walkers(0.05)
	return Vector2(node.position.x - start.x, node.position.z - start.z).length()


func _check_walkers() -> void:
	var w: Dictionary = world.walkers[0]
	w["wait"] = 0.0
	w["ta"] = w["a"] + 1.5
	world._update_walkers(0.05)   # face the way they walk
	var beside := _walk_past(w, 0.0, 1.6)
	results.append(["a walking neighbour keeps walking past you (no stopping to stare)", beside > 0.3, "walked %.2f m with you beside them" % beside])
	var blocked := _walk_past(w, 0.6, 0.0)
	results.append(["but waits when you're right in their way", blocked < 0.1, "walked %.2f m with you in front" % blocked])


func _check_goodbye() -> void:
	var n: int = Dialogue.new().lines_for("dorran", false).size()
	var t := {"kind": "talk", "id": "dorran", "pos": world.cast_nodes["dorran"].position}
	var seen := []
	for i in n:
		interact.use(t)
		seen.append(interact.last_text)
	var last_open: bool = interact.showing == "dorran" and interact._talk_end
	interact.use(t)   # one more E after the last line
	var closed: bool = interact.showing == ""
	interact.use(t)   # and talking again
	var again: bool = interact.showing == "dorran" and interact.last_text == seen[0]
	results.append(["after someone's last line, E says goodbye (the conversation ends)", last_open and closed, "%d lines" % n])
	results.append(["talking to them again starts from the top", again, "'%s'" % interact.last_text.left(40)])
	interact._close()


func _check_menu() -> void:
	# Keep the player's own saved volume: put it back afterwards
	var had := FileAccess.file_exists(menu.OPTIONS)
	var before := FileAccess.get_file_as_string(menu.OPTIONS) if had else ""
	var esc := InputEventAction.new()
	esc.action = "quit"
	esc.pressed = true
	menu._unhandled_input(esc)
	results.append(["Esc opens the menu and pauses the game", menu.is_open() and get_tree().paused and controls.menu_open, ""])
	if _shots:   # hidden, on a real GPU: what the menu looks like
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir()))
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot("esc_menu")
	menu._on_volume(50.0)
	var db := AudioServer.get_bus_volume_db(0)
	var cfg := ConfigFile.new()
	cfg.load(menu.OPTIONS)
	results.append(["the volume slider makes the game quieter, and it's remembered",
			absf(db - linear_to_db(0.5)) < 0.1 and absf(float(cfg.get_value("sound", "volume", -1.0)) - 0.5) < 0.01, "%.1f dB" % db])
	menu._on_volume(0.0)
	results.append(["volume at 0 mutes it", AudioServer.is_bus_mute(0), ""])
	menu._on_volume(100.0)
	menu._unhandled_input(esc)
	results.append(["Esc again closes it and the game carries on", not menu.is_open() and not get_tree().paused and not controls.menu_open, ""])
	if had:
		var f := FileAccess.open(menu.OPTIONS, FileAccess.WRITE)
		f.store_string(before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.OPTIONS))
