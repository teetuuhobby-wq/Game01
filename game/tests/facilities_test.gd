extends "res://main.gd"
# The town's buildings and people (headless):
#   - every doorway leads inside, and every building can be reached from where you start
#   - everything you can use (boards, seats, the hearth...) and everyone you can talk to
#     has a spot in reach that you can walk to
#   - nobody stands in a doorway or on the stairs
#   - every resident has enough to say, and the talk changes after Mira's errand
#   - a bot walks into each building and uses everything there with E, then sits
#     down and gets up again, without getting stuck
# Run: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/facilities_test.tscn -- --no-record

const Town := preload("res://town_data.gd")
const Dialogue := preload("res://dialogue.gd")

var results := []
var _interact: Node
var _tour := []          # [{"goal": Vector3, "use": Dictionary or {}, "what": String}]
var _i := 0
var _path := PackedVector3Array()
var _k := 0
var _t := 0.0
var _leg_t := 0.0
var _used := 0
var _sat := 0
var _wanted_uses := 0
var _press_next := false
var _stage := ""         # "walk", "use", "sitting"
var _wait := 0.0
var _done := false
var _log := []


func _ready() -> void:
	super()
	for c in get_children():
		if c.get_script() == preload("res://interact.gd"):
			_interact = c
	_static_checks()
	_plan_tour()
	player.bot_mode = true


## A standable spot within `reach` of `at` that a route from `from` gets to, or null.
func _reachable_near(at: Vector3, reach: float, from: Vector3, max_dy := 2.0):
	var cands := []
	var r := int(reach / world.VS)
	var cx := roundi(at.x / world.VS)
	var cz := roundi(at.z / world.VS)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var p := Vector3((cx + dx) * world.VS, 0, (cz + dz) * world.VS)
			var d := Vector2(p.x - at.x, p.z - at.z).length()
			if d > reach - 0.15:
				continue
			var i: int = world._col(p)
			if i < 0 or not world._roomy(i):
				continue
			p.y = (world.walk_floor[i] + 0.5) * world.VS
			if absf(p.y - at.y) > max_dy:
				continue
			cands.append([d, p])
	cands.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for k in mini(cands.size(), 6):
		if not world.find_path(from, cands[k][1]).is_empty() or Vector2(from.x - cands[k][1].x, from.z - cands[k][1].z).length() < 0.3:
			return cands[k][1]
	return null


func _static_checks() -> void:
	var bad := []
	for k in world.facilities:
		var f: Dictionary = world.facilities[k]
		if world.find_path(f["door_out"], f["inside"]).is_empty():
			bad.append(k)
	results.append(["every doorway leads inside (5 buildings)", bad.is_empty() and world.facilities.size() == 5, str(bad)])
	bad = []
	for k in world.facilities:
		if world.find_path(world.you_spot, world.facilities[k]["door_out"]).is_empty():
			bad.append(k)
	results.append(["every building can be walked to from where you start", bad.is_empty(), str(bad)])
	bad = []
	for s in world.interact_spots:
		var f: Dictionary = world.facilities.get(s["where"], {})
		var from: Vector3 = f.get("door_in", world.you_spot)
		if _reachable_near(s["pos"], s.get("reach", _interact.THING_REACH), from) == null:
			bad.append(s["id"])
	results.append(["everything you can use can be reached (%d things)" % world.interact_spots.size(), bad.is_empty(), str(bad)])
	bad = []
	for id in world.cast_nodes:
		var n: Node3D = world.cast_nodes[id]
		var f: Dictionary = world.facilities.get(world.cast_spots.get(id, {}).get("where", ""), {})
		var from: Vector3 = f.get("door_in", world.you_spot)
		if _reachable_near(n.position, _interact.TALK_REACH, from, 3.0) == null:
			bad.append(id)
	results.append(["everyone can be talked to (%d people)" % world.cast_nodes.size(), bad.is_empty() and world.cast_nodes.size() == 8, str(bad)])
	bad = []
	for id in world.cast_spots:
		var spot: Dictionary = world.cast_spots[id]
		var pts: Array = [spot["pos"]]
		pts.append_array(spot.get("loop", []))
		for p: Vector3 in pts:
			var b := Vector2i(roundi(p.x / world.VS), roundi(p.z / world.VS))
			if world.stair_top.has(b):
				bad.append(id + " on stairs")
			for k in world.facilities:
				var dd: Vector3 = p - world.facilities[k]["door_in"]
				var de: Vector3 = p - world.facilities[k]["door_out"]
				if Vector2(dd.x, dd.z).length() < 0.8 or (id != "pip" and Vector2(de.x, de.z).length() < 0.8):
					bad.append(id + " in the " + k + " doorway")
	results.append(["nobody stands in a doorway or on the stairs", bad.is_empty(), str(bad)])
	bad = []
	for id in Town.CAST:
		var c: Dictionary = Town.CAST[id]
		var n: int = c["lines"].size() + c.get("after", []).size()
		if n < 4 or n > 7 or c.get("after", []).is_empty():
			bad.append("%s (%d lines)" % [id, n])
	results.append(["every resident has 4-7 lines, including one for after the errand", bad.is_empty(), str(bad)])
	var d := Dialogue.new()
	var first := d.next_line("dorran", false)
	var second := d.next_line("dorran", false)
	var after := d.next_line("dorran", true)
	results.append(["talking goes through the lines, then starts with the news once the errand is done",
			first == Town.CAST["dorran"]["lines"][0] and second == Town.CAST["dorran"]["lines"][1]
			and after == Town.CAST["dorran"]["after"][0], ""])


## A tour: into each building, then to each thing and person inside, using each one.
func _plan_tour() -> void:
	for k in ["guild", "tavern", "store", "bath", "workshop"]:
		var f: Dictionary = world.facilities[k]
		_tour.append({"goal": f["door_in"], "use": {}, "what": "into the " + k})
		var sat := false
		for s in world.interact_spots:
			if s["where"] != k:
				continue
			if s["kind"] == "sit":
				if sat:
					continue   # one seat per building is enough for the walk
				sat = true
			var at = _reachable_near(s["pos"], s.get("reach", _interact.THING_REACH) - 0.15, f["door_in"])
			if at != null:
				_tour.append({"goal": at, "use": s, "what": s["id"]})
		for id in world.cast_nodes:
			if world.cast_spots.get(id, {}).get("where", "") == k:
				_tour.append({"goal": null, "use": {"kind": "talk", "id": id}, "what": "talk to " + id})
	_wanted_uses = 0
	for t in _tour:
		if not t["use"].is_empty():
			_wanted_uses += 1
	_start_leg()


func _start_leg() -> void:
	if _i >= _tour.size():
		_finish()
		return
	var leg: Dictionary = _tour[_i]
	if leg["goal"] == null:
		var n: Node3D = world.cast_nodes[leg["use"]["id"]]
		leg["goal"] = _reachable_near(n.position, _interact.TALK_REACH - 0.15, player.position, 3.0)
		if leg["goal"] == null:
			_log.append("no spot near " + leg["use"]["id"])
			_i += 1
			_start_leg()
			return
	_path = world.find_path(player.position, leg["goal"])
	_k = 0
	_leg_t = 0.0
	_stage = "walk"


func _process(delta: float) -> void:
	if _done or _tour.is_empty():
		return
	_t += delta
	_leg_t += delta
	if _t > 900.0:
		_log.append("took too long")
		_finish()
		return
	var leg: Dictionary = _tour[_i]
	match _stage:
		"walk":
			var here := Vector2(player.position.x, player.position.z)
			var goal: Vector3 = leg["goal"]
			if here.distance_to(Vector2(goal.x, goal.z)) < 0.25 or _path.is_empty():
				player.bot_input = Vector2.ZERO
				if leg["use"].is_empty():
					_i += 1
					_start_leg()
				else:
					_stage = "use"
					_wait = 0.3
				return
			for j in range(_k, mini(_k + 10, _path.size())):
				if here.distance_to(Vector2(_path[j].x, _path[j].z)) < here.distance_to(Vector2(_path[_k].x, _path[_k].z)):
					_k = j
			var aim: Vector3 = _path[mini(_k + 3, _path.size() - 1)]
			player.bot_input = (Vector2(aim.x, aim.z) - here).normalized()
			if _leg_t > 60.0:
				_log.append("stuck going to " + leg["what"])
				player.bot_input = Vector2.ZERO
				_i += 1
				_start_leg()
		"use":
			_wait -= delta
			if _wait > 0.0:
				return
			# Face the thing, as a player would, then press E
			var u: Dictionary = leg["use"]
			var at: Vector3 = world.cast_nodes[u["id"]].position if u["kind"] == "talk" else u["pos"]
			player.face(at - player.position)
			var t: Dictionary = _interact.find_target()
			var want_id: String = u["id"]
			if t.get("id", "") == want_id:
				controls.use_pressed = true
				_used += 1
				if u["kind"] == "sit":
					_stage = "sitting"
					_wait = 1.0
					return
			else:
				_log.append("%s: E would use %s instead" % [want_id, t.get("id", "nothing")])
			_i += 1
			_start_leg()
		"sitting":
			_wait -= delta
			if _wait > 0.0:
				return
			if player.seated:
				_sat += 1
				controls.use_pressed = true   # stand up
				_wait = 0.3
				return
			if world.floor_at(player.position) < 0:
				_log.append("stood up somewhere you can't stand")
			_i += 1
			_start_leg()


func _finish() -> void:
	_done = true
	player.bot_input = Vector2.ZERO
	results.append(["a bot walks into all 5 buildings and uses everything there (%d of %d)" % [_used, _wanted_uses],
			_used == _wanted_uses, "%.0f s; %s" % [_t, str(_log)]])
	var with_seats := {}
	for s in world.interact_spots:
		if s["kind"] == "sit":
			with_seats[s["where"]] = true
	results.append(["it sits down and stands up again in each building with seats (%d)" % with_seats.size(),
			_sat == with_seats.size(), "%d times" % _sat])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
