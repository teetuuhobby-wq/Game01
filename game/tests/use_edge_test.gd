extends "res://main.gd"
# Edge cases of pressing E (headless), from the code review:
#   - one press at the valve picks it up and does nothing else, standing where the
#     workshop's side bench is in reach too (so a second thing really could happen)
#   - sitting down while holding a walk key doesn't stand you straight back up;
#     you stand when you let go and walk again
#   - sitting lowers your first-person eyes, and the valve you carry stays in your hand
#   - a named resident (Dorran) right in front of the camera is hidden, like everyone else,
#     but not in first person when you're just talking to him across the bar
# Run: <godot_console.exe> --headless --path game res://tests/use_edge_test.tscn -- --no-record

const T := preload("res://tuning.gd")

var _interact: Node
var _frame := 0
var _results := []
var _seat := {}


func _ready() -> void:
	super()
	for c in get_children():
		if c.get_script() == preload("res://interact.gd"):
			_interact = c
	# Beside the valve, with the side bench (and its "tinker with the pump") in reach too
	player.position = Vector3(108 * world.VS, world.workshop_stand.y, 19 * world.VS)
	player.face(world.workshop_use - player.position)
	for s in world.interact_spots:
		if s["where"] == "tavern" and s["kind"] == "sit":
			_seat = s
			break


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		5:
			# Both really are in reach here, or the check below couldn't fail
			var other: String = _interact.find_target().get("id", "")
			_results.append(["the valve and something else (%s) are both in reach" % other,
					errand._near() and other != "" and world.floor_at(player.position) >= 0, ""])
			controls.use_pressed = true   # one press of E, standing at the valve
		7:
			_results.append(["one press at the valve picks it up and does nothing else",
					errand.step == errand.Step.FIT_VALVE and _interact.showing == "" and not player.seated,
					"step %d, panel '%s'" % [errand.step, _interact.showing]])
			# Sit down at the tavern, holding a walk key the whole time
			player.position = _seat["pos"] - _seat["face"] * 0.7
			player.position.y = world.VS * 0.5
			player.bot_input = Vector2(1, 0)
			_interact.use(_seat)
		20:
			_results.append(["holding a walk key while sitting down doesn't stand you up", player.seated, ""])
			_results.append(["sitting lowers your eyes (first person)", player.eye_height() < T.EYE_HEIGHT - 0.2,
					"%.2f m" % player.eye_height()])
			_results.append(["the valve you carry stays in your hand while you sit", world.valve.is_visible_in_tree(), ""])
			player.bot_input = Vector2.ZERO   # let go
		24:
			player.bot_input = Vector2(1, 0)   # walk again
		27:
			_results.append(["letting go and walking again stands you up, somewhere you can stand",
					not player.seated and world.floor_at(player.position) >= 0, ""])
			player.bot_input = Vector2.ZERO
			_results.append(["standing up again, your eyes are back up and the valve is still in your hand",
					absf(player.eye_height() - T.EYE_HEIGHT) < 0.1 and world.valve.is_visible_in_tree(), ""])
			# The camera right in front of Dorran's face: he's hidden, so he doesn't fill the screen
			var dorran: Node3D = world.cast_nodes["dorran"]
			camera.global_position = world.city.to_global(dorran.position + Vector3(0.6, 1.4, 0))
			world._hide_close_residents()
			var hidden := not dorran.visible
			camera.global_position = world.city.to_global(dorran.position + Vector3(4.0, 1.4, 0))
			world._hide_close_residents()
			_results.append(["a named resident right in front of the camera is hidden (and shown again)",
					hidden and dorran.visible, ""])
			# Through your own eyes, pressed up against the bar to talk, he stays in view;
			# only standing right inside him hides him
			var fp: float = camera.first_person
			camera.first_person = 1.0
			camera.global_position = world.city.to_global(dorran.position + Vector3(-1.1, T.EYE_HEIGHT, 0))
			world._hide_close_residents()
			var seen := dorran.visible
			camera.global_position = world.city.to_global(dorran.position + Vector3(-0.2, T.EYE_HEIGHT, 0))
			world._hide_close_residents()
			_results.append(["in first person, a resident you talk to across the bar stays in view (hidden only from inside him)",
					seen and not dorran.visible, ""])
			camera.first_person = fp
			var ok := true
			for r in _results:
				print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
				ok = ok and r[1]
			get_tree().quit(0 if ok else 1)
