extends "res://main.gd"
# The morning round (welcome.gd), played start to finish by a bot (headless):
#   - it starts with Mira asking, the clock standing still at ROUND_HOUR, Mira's errand waiting
#   - the bot walks to every stop (the walk map finds the way) and uses it with E;
#     each resident at their stop says their round line, and the tea goes from Dorran to Wendel
#   - Bram's stop hands over to Mira's errand: the valve is fetched and fitted
#   - then the clock jumps to evening behind a fade and runs: the bell, "Day 1 done",
#     Day 2, and the round is over
# Tests start without the round, so this one starts it itself (start_round()).
# Run: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/round_test.tscn -- --no-record

const Town := preload("res://town_data.gd")
const T := preload("res://tuning.gd")
const W := preload("res://welcome.gd")

var results := []
var _log := []
var _stage := "start"
var _path := PackedVector3Array()
var _k := 0
var _goal := Vector3.ZERO
var _wait := 0.0
var _leg_t := 0.0
var _t := 0.0
var _lines_ok := 0
var _talks := 0
var _tea_ok := true
var _clock_still := true
var _events := []
var _bell := false
var _tries := 0
var _shot_card := false


func _ready() -> void:
	super()
	start_round()
	player.bot_mode = true
	day_view.happened.connect(func(what: String) -> void: _events.append(what))
	results.append(["it starts with Mira asking, the clock still at %s and Mira's errand waiting" % preload("res://day.gd").clock_text(T.ROUND_HOUR),
			absf(day_view.day.hour - T.ROUND_HOUR) < 0.001 and day_view.day.frozen and not errand.active
			and hud._say.text.begins_with(Town.ROUND_START["who"]), "%.2f, errand active %s" % [day_view.day.hour, errand.active]])


## A standable spot within reach of `at`, in the same room, that a route from you gets to.
func _spot_near(at: Vector3, reach: float, max_dy: float) -> Variant:
	var room: String = world.facility_at(at)
	var cands := []
	var r := int(reach / world.VS)
	var cx := roundi(at.x / world.VS)
	var cz := roundi(at.z / world.VS)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var p := Vector3((cx + dx) * world.VS, 0, (cz + dz) * world.VS)
			var d := Vector2(p.x - at.x, p.z - at.z).length()
			var i: int = world._col(p)
			if d > reach or i < 0 or not world._roomy(i):
				continue
			p.y = (world.walk_floor[i] + 0.5) * world.VS
			if absf(p.y - at.y) <= max_dy and world.facility_at(p) == room:
				cands.append([d, p])
	cands.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for k in mini(cands.size(), 40):
		if not world.find_path(player.position, cands[k][1]).is_empty():
			return cands[k][1]
	return null


func _walk_to(at: Variant, what: String) -> bool:
	if at == null:
		_log.append("nowhere to stand near " + what)
		return false
	_goal = at
	_path = world.find_path(player.position, _goal)
	_k = 0
	_leg_t = 0.0
	return true


## Walks along the path; true when there.
func _walking(delta: float, what: String) -> bool:
	_leg_t += delta
	var here := Vector2(player.position.x, player.position.z)
	if here.distance_to(Vector2(_goal.x, _goal.z)) < 0.25 or _path.is_empty():
		player.bot_input = Vector2.ZERO
		return true
	for j in range(_k, mini(_k + 10, _path.size())):
		if here.distance_to(Vector2(_path[j].x, _path[j].z)) < here.distance_to(Vector2(_path[_k].x, _path[_k].z)):
			_k = j
	var aim: Vector3 = _path[mini(_k + 3, _path.size() - 1)]
	player.bot_input = (Vector2(aim.x, aim.z) - here).normalized()
	if _leg_t > 120.0:
		_log.append("stuck going to " + what)
		_finish()
	return false


func _process(delta: float) -> void:
	if _stage == "done":
		return
	_t += delta
	if _t > 1500.0:
		_log.append("took too long (%s)" % _stage)
		_finish()
		return
	if welcome.phase == W.Phase.ROUND and absf(day_view.day.hour - T.ROUND_HOUR) > 0.001:
		_clock_still = false
	if _shots and _t > 1.5 and _t - delta <= 1.5:
		camera.snap_zoom(0.15)
		_save_shot("round_start")
	match _stage:
		"start":
			if welcome.phase != W.Phase.ROUND:
				_stage = "valve"
				_walk_to(_spot_near(world.workshop_use, T.USE_DISTANCE - 0.3, 2.5), "the valve")
				return
			var s: Dictionary = Town.ROUND[welcome.stop]
			var reach: float = interact.TALK_REACH if s["do"] == "talk" else interact.THING_REACH
			if not _walk_to(_spot_near(welcome.target(), reach - 0.2, 3.0 if s["do"] == "talk" else 2.0), s["goal"]):
				_finish()
				return
			_stage = "walk"
		"walk":
			var s: Dictionary = Town.ROUND[welcome.stop]
			if _walking(delta, s["goal"]):
				_stage = "use"
				_wait = 0.3
		"use":
			_wait -= delta
			if _wait > 0.0:
				return
			var s: Dictionary = Town.ROUND[welcome.stop]
			player.face(welcome.target() - player.position)
			var t: Dictionary = interact.find_target()
			var want: bool = (s["do"] == "talk" and t.get("id", "") == s["id"]) or welcome._is_stop_spot(t, s)
			if not want:
				# Someone who paces (Pell behind her counter) may have walked off: try again
				_tries += 1
				if _tries <= 4:
					_stage = "start"
					return
				_log.append("%s: E would use %s instead" % [s["goal"], t.get("id", "nothing")])
				_finish()
				return
			_tries = 0
			controls.use_pressed = true
			_stage = "check"
			_wait = 0.15
		"check":
			_wait -= delta
			if _wait > 0.0:
				return
			var done_stop: Dictionary = Town.ROUND[welcome.stop - 1] if welcome.stop > 0 else {}
			if _shots and not player.seated:
				_save_shot("round_stop%02d" % welcome.stop)   # with --shots (hidden, real GPU): each stop's panel
			if done_stop.get("do", "") == "talk":
				_talks += 1
				if interact.last_text == done_stop["line"]:
					_lines_ok += 1
			# The tea: in your hand from Dorran until Wendel
			var holding: bool = player.hand.get_child_count() > 0
			var should: bool = welcome.stop > 5 and welcome.stop <= 9
			if holding != should and welcome.phase == W.Phase.ROUND:
				_tea_ok = false
			if player.seated:
				controls.use_pressed = true   # stand up again
				_wait = 0.3
				return
			_stage = "start"
		"valve":
			if _walking(delta, "the valve"):
				errand.bot_use = true
				_stage = "pick"
		"pick":
			if errand.step == errand.Step.FIT_VALVE:
				errand.bot_use = false
				results.append(["Bram's stop hands over to Mira's errand: the bot picks up the valve", true, ""])
				_stage = "catcher"
				_walk_to(_spot_near(world.catcher_use, T.USE_DISTANCE - 0.3, 2.5), "the rain-catcher")
		"catcher":
			if _walking(delta, "the rain-catcher"):
				errand.bot_use = true
				_stage = "fit"
		"fit":
			if errand.step == errand.Step.DONE:
				errand.bot_use = false
				_stage = "evening"
		"evening":
			if _shots and not _bell and "evening_bell" in _events:
				_save_shot("round_evening_bell")
			if _shots and _events.size() == 2 and _shot_card == false and day_view.day.darkness() >= 1.0:
				_shot_card = true
				_save_shot("round_day_done")
			_bell = _bell or "evening_bell" in _events
			if welcome.phase == W.Phase.OVER:
				_finish()


func _finish() -> void:
	_stage = "done"
	player.bot_input = Vector2.ZERO
	if _shots:
		_save_shot("round_over")
	var n: int = Town.ROUND.size()
	results.append(["a bot walks the whole round and uses every stop with E (%d stops)" % n,
			welcome.stop == n, "reached stop %d in %.0f s; %s" % [welcome.stop, _t, str(_log)]])
	results.append(["each resident at their stop says their round line", _talks > 0 and _lines_ok == _talks, "%d of %d" % [_lines_ok, _talks]])
	results.append(["the tea goes from Dorran's hand to Wendel's (in yours in between, then gone)", _tea_ok and player.hand.get_child_count() == 0, ""])
	results.append(["the clock stands still the whole round", _clock_still, ""])
	results.append(["after the valve: evening behind a fade, the bell, 'Day 1 done', Day 2, and the round is over (no leftover prompt)",
			welcome.phase == W.Phase.OVER and _bell and day_view.day.day == 2 and hud._goal.text == Town.ROUND_OVER
			and hud._prompt.text == "",
			"phase %d, day %d, events %s" % [welcome.phase, day_view.day.day, str(_events)]])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
