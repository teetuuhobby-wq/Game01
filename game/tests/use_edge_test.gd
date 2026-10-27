extends "res://main.gd"
# Edge cases of pressing E (headless), from the code review:
#   - one press at the valve picks it up and does nothing else (not also talk to Bram)
#   - sitting down while holding a walk key doesn't stand you straight back up;
#     you stand when you let go and walk again
# Run: <godot_console.exe> --headless --path game res://tests/use_edge_test.tscn -- --no-record

var _interact: Node
var _frame := 0
var _results := []
var _seat := {}


func _ready() -> void:
	super()
	for c in get_children():
		if c.get_script() == preload("res://interact.gd"):
			_interact = c
	player.position = world.workshop_stand
	for s in world.interact_spots:
		if s["where"] == "tavern" and s["kind"] == "sit":
			_seat = s
			break


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		5:
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
			player.bot_input = Vector2.ZERO   # let go
		24:
			player.bot_input = Vector2(1, 0)   # walk again
		27:
			_results.append(["letting go and walking again stands you up, somewhere you can stand",
					not player.seated and world.floor_at(player.position) >= 0, ""])
			player.bot_input = Vector2.ZERO
			var ok := true
			for r in _results:
				print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
				ok = ok and r[1]
			get_tree().quit(0 if ok else 1)
