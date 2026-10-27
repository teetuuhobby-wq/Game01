extends "res://main.gd"
# BUG HUNT (headless): a bot walks from one random spot to another all over the city,
# up and down every terrace, for a long time, and logs anything that goes wrong:
#   stuck  - it barely moved for 3 s while following a route the walk map says is fine
#   off    - it ended up standing where nobody can stand
#   jump   - its height jumped more than 0.6 m in one frame (a glitch on stairs or an edge)
# Run: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/soak_test.tscn -- --no-record --minutes 60
# Passes when nothing went wrong. Prints every problem spot (metres, on the city).

var minutes := 60.0
var _rng := RandomNumberGenerator.new()
var _targets := []          # standable, roomy spots all over the deck
var _path := PackedVector3Array()
var _k := 0
var _goal := Vector3.ZERO
var _t := 0.0
var _leg_t := 0.0
var _check_t := 0.0
var _check_pos := Vector3.ZERO
var _last_y := 0.0
var _legs := 0
var _arrived := 0
var _no_route := 0
var _problems := {}         # "kind @ x,z" -> count
var _metres := 0.0
var _last_pos := Vector3.ZERO
var _done := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mi := args.find("--minutes")
	if mi >= 0 and mi + 1 < args.size():
		minutes = float(args[mi + 1])
	super()
	_rng.seed = 2027
	player.bot_mode = true
	# Every 2 m across the deck, keep the spots a person fits with room to spare
	for x in range(-world.RXV, world.RXV + 1, 10):
		for z in range(-world.RZV, world.RZV + 1, 10):
			var i: int = (z - world.GZ0) * world.NX + (x - world.GX0)
			if world.level_at(x, z) >= 0 and world._roomy(i):
				_targets.append(Vector3(x * world.VS, (world.walk_floor[i] + 0.5) * world.VS, z * world.VS))
	print("SOAK: %d target spots, walking for %.0f minutes of game time" % [_targets.size(), minutes])
	_last_y = player.position.y
	_last_pos = player.position
	_next_leg()


func _next_leg() -> void:
	for attempt in 20:
		_goal = _targets[_rng.randi() % _targets.size()]
		_path = world.find_path(player.position, _goal)
		if not _path.is_empty():
			break
		_no_route += 1
	_k = 0
	_leg_t = 0.0
	_check_t = 0.0
	_check_pos = player.position
	_legs += 1


func _note(kind: String) -> void:
	var p: Vector3 = player.position
	var key := "%s @ %.0f, %.0f (floor %d)" % [kind, p.x, p.z, world.floor_at(p)]
	_problems[key] = _problems.get(key, 0) + 1


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_leg_t += delta
	_metres += Vector2(player.position.x - _last_pos.x, player.position.z - _last_pos.z).length()
	_last_pos = player.position
	if absf(player.position.y - _last_y) > 0.6:
		_note("jump")
	_last_y = player.position.y
	if world.floor_at(player.position) < 0:
		_note("off")
	if _t > minutes * 60.0:
		_finish()
		return
	var here := Vector2(player.position.x, player.position.z)
	if _path.is_empty() or here.distance_to(Vector2(_goal.x, _goal.z)) < 0.3:
		if not _path.is_empty():
			_arrived += 1
		_next_leg()
		return
	for j in range(_k, mini(_k + 10, _path.size())):
		if here.distance_to(Vector2(_path[j].x, _path[j].z)) < here.distance_to(Vector2(_path[_k].x, _path[_k].z)):
			_k = j
	var aim: Vector3 = _path[mini(_k + 3, _path.size() - 1)]
	player.bot_input = (Vector2(aim.x, aim.z) - here).normalized()
	_check_t += delta
	if _check_t >= 3.0:
		if Vector2(player.position.x - _check_pos.x, player.position.z - _check_pos.z).length() < 0.3:
			_note("stuck")
			_next_leg()
			return
		_check_t = 0.0
		_check_pos = player.position
	if _leg_t > 240.0:
		_note("leg too long")
		_next_leg()


func _finish() -> void:
	_done = true
	player.bot_input = Vector2.ZERO
	print("SOAK: walked %.0f m in %.0f min: %d routes, %d finished, %d spots with no route" % [
			_metres, _t / 60.0, _legs, _arrived, _no_route])
	var keys: Array = _problems.keys()
	keys.sort()
	for k in keys:
		print("PROBLEM  %s  (x%d)" % [k, _problems[k]])
	var ok := _problems.is_empty()
	print("%s  an hour's walk all over the city with no stuck spots, falls or glitches  (%d problem spots)" % [
			"PASS" if ok else "FAIL", _problems.size()])
	get_tree().quit(0 if ok else 1)
