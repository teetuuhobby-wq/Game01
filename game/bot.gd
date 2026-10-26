extends Node
## TEST BOT: plays the errand by itself, steering you along the shortest walkable
## route and pressing "E" at each stop. Used by tests (run with "-- --autoplay"),
## never in normal play. Prints what it does and quits with a code:
## 0 = errand done, 2 = got stuck, 3 = no route found, 4 = took too long.

signal finished(code: int)

var world: Node3D
var player: Node3D
var errand: Node

var _path := PackedVector3Array()
var _k := 0
var _for_step := -1
var _t := 0.0
var _last_pos := Vector3.ZERO
var _still := 0.0
var _done := false


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if errand.step == errand.Step.DONE:
		_finish(0, "errand done after %.0f s of play" % _t)
		return
	if _t > 600.0:
		_finish(4, "still not done after 600 s")
		return
	var goal: Vector3 = world.workshop_stand if errand.step == errand.Step.GET_VALVE else world.catcher_stand
	if _for_step != errand.step:
		_for_step = errand.step
		_path = world.find_path(player.position, goal)
		_k = 0
		print("BOT: route to %s: %d steps (%.0f m)" % ["the workshop" if errand.step == errand.Step.GET_VALVE else "the rain-catcher", _path.size(), _path.size() * 0.2])
		if _path.is_empty():
			_finish(3, "no walkable route")
			return
	var flat := func(v: Vector3) -> Vector2: return Vector2(v.x, v.z)
	var here: Vector2 = flat.call(player.position)
	# Follow the route: lock on to the nearest route point a little ahead, aim a few past it
	for j in range(_k, mini(_k + 10, _path.size())):
		if here.distance_to(flat.call(_path[j])) < here.distance_to(flat.call(_path[_k])):
			_k = j
	var at_goal := here.distance_to(flat.call(goal)) < 0.3
	errand.bot_use = at_goal
	if int(_t / 5.0) != int((_t - delta) / 5.0):
		print("BOT: t=%.0f at %s, step %d/%d, %.1f m from goal%s" % [_t, str(player.position.snapped(Vector3.ONE * 0.1)),
				_k, _path.size(), here.distance_to(flat.call(goal)), ", using" if at_goal else ""])
	if at_goal:
		player.bot_input = Vector2.ZERO
		_still = 0.0
		_last_pos = player.position
		return
	var aim: Vector2 = flat.call(_path[mini(_k + 3, _path.size() - 1)]) - here
	player.bot_input = aim.normalized()
	# Stuck = moved less than 30 cm in 3 seconds (wobbling on the spot counts as stuck)
	_still += delta
	if _still >= 3.0:
		if here.distance_to(flat.call(_last_pos)) < 0.3:
			_finish(2, "stuck at %s" % str(player.position.snapped(Vector3.ONE * 0.1)))
		_still = 0.0
		_last_pos = player.position


func _finish(code: int, why: String) -> void:
	_done = true
	player.bot_input = Vector2.ZERO
	errand.bot_use = false
	print("BOT: %s (code %d)" % [why, code])
	finished.emit(code)
