extends "res://main.gd"
# BUG HUNT (headless): a bot walks from one random spot to another all over the city,
# up and down every terrace, for a long time, and logs anything that goes wrong:
#   stuck     - it barely moved for 3 s while following a route the walk map says is fine
#   height    - it stayed more than 0.3 m above or below the floor under its feet for
#               over half a second (floating, sinking, or stuck halfway up a step)
#   no route  - from where it stands, none of 20 random spots can be reached: it's
#               stranded (the bot is then put back on a random spot and carries on)
#   leg too long - one trip took over 4 minutes (walking in circles)
# (There's no "standing where nobody can stand" check: player.gd refuses every step onto
# such a spot, so it can't happen. Being stranded is what "no route" catches.)
# Run: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/soak_test.tscn -- --no-record --minutes 60
# (the full bug hunt, about 7 minutes of real time; run_tests.ps1 does --minutes 1, about 30 s,
# and --minutes 5 takes about a minute.)
# Passes when nothing went wrong. Prints every problem spot (metres, on the city).

const HEIGHT_SLACK := 0.3     # metres off the floor before it counts as a height glitch
const HEIGHT_TIME := 0.5      # ...for this many seconds (stairs settle in under 0.1 s)
const ROUTE_TRIES := 20       # random spots tried before calling a place "no route from here"
const STRANDED_LIMIT := 3     # stranded this many times in a row: the map is broken, stop

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
var _off_floor_t := 0.0     # how long its height has been away from the floor
var _legs := 0
var _arrived := 0
var _no_route := 0          # random spots picked that couldn't be reached (another is tried)
var _stranded := 0          # times in a row it found no route at all
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
	_last_pos = player.position
	_next_leg()


## Picks a new random spot and a route to it. If none of ROUTE_TRIES spots can be
## reached from here, the bot is stranded: that's a problem, noted at this spot, and the
## bot is put down on a random spot to carry on (or, stranded again and again, it stops).
func _next_leg() -> void:
	_path = PackedVector3Array()
	for attempt in ROUTE_TRIES:
		_goal = _targets[_rng.randi() % _targets.size()]
		_path = world.find_path(player.position, _goal)
		if not _path.is_empty():
			break
		_no_route += 1
	_k = 0
	_leg_t = 0.0
	_check_t = 0.0
	if _path.is_empty():
		_note("no route from here")
		_stranded += 1
		if _stranded >= STRANDED_LIMIT:
			print("SOAK: stranded %d times in a row, stopping early" % _stranded)
			_finish()
			return
		player.position = _targets[_rng.randi() % _targets.size()]
		_last_pos = player.position
		_off_floor_t = 0.0
	else:
		_stranded = 0
		_legs += 1
	_check_pos = player.position


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
	_check_height(delta)
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


## Your feet should rest on the floor under you: player.gd glides your height to
## (floor + 0.5) blocks, so after a step it settles in a frame or two. Height that stays
## off for longer is a glitch (no floor at all counts as off, too). Noted once each time.
func _check_height(delta: float) -> void:
	var f: int = world.floor_at(player.position)
	var gap := INF if f < 0 else absf(player.position.y - (f + 0.5) * world.VS)
	if gap <= HEIGHT_SLACK:
		_off_floor_t = 0.0
		return
	_off_floor_t += delta
	if _off_floor_t > HEIGHT_TIME and _off_floor_t - delta <= HEIGHT_TIME:
		_note("height")


func _finish() -> void:
	_done = true
	player.bot_input = Vector2.ZERO
	print("SOAK: walked %.0f m in %.1f min: %d routes, %d finished, %d picked spots had no route (another was tried)" % [
			_metres, _t / 60.0, _legs, _arrived, _no_route])
	var keys: Array = _problems.keys()
	keys.sort()
	for k in keys:
		print("PROBLEM  %s  (x%d)" % [k, _problems[k]])
	var ok := _problems.is_empty()
	print("%s  a %.0f-minute walk all over the city with no stuck spots, falls or glitches  (%d problem spots)" % [
			"PASS" if ok else "FAIL", minutes, _problems.size()])
	get_tree().quit(0 if ok else 1)
