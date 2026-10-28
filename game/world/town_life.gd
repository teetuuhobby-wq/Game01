extends "res://world/routes.gd"
## THE WORLD, layer 15 of 15: the town following the day. (The clock itself is day.gd;
## day_view.gd tells the world the time with set_town_hour.)
##   - The named residents keep their daily routines (ROUTINES in town_data.gd): they
##     walk between home and their places along the walk map, each at their own pace.
##   - The market fills up in the morning and empties in the evening; the regulars come
##     and go with each place's opening hours, more of them when it's busy.
##   - Each place has an OPEN / CLOSED plaque by its door; the lamps burn brighter at dusk.
## Nobody appears or vanishes in front of you: people only come and go out of the
## camera's sight (out of view, behind a wall, or far away). A route is searched once
## per trip, a little each frame (routes.gd), never every frame.

const DayRules := preload("res://day.gd")
const TownData := preload("res://town_data.gd")

const PRESENCE_CHECKS_PER_FRAME := 20  # market-goers and regulars checked each frame: should they be here?
const SIGHT_CHECKS_PER_FRAME := 4      # at most this many "is a wall in the way?" checks each frame (they cost the most)
const SEEN_DISTANCE: float = T.COME_AND_GO_DISTANCE
const MAKE_WAY := 0.9                  # metres: a walking resident slows right down when you're this close in front

var town_hour := 8.0       # the time the town is living at (day_view.gd sets it)
var market_share := 1.0    # how full the market street is right now (0..1): its sound follows it
var visit_spots := {}      # place -> [{"pos", "face", "where", "by"}]: where visitors stand
var home_doors := {}       # cast id -> {"pos", "face", "home": true}: their front door
var life := {}             # cast id -> {"place", "dest", "state", "path", "k", "pace", "at", "wait"}
var _cast_by_id := {}      # cast id -> their entry in _cast (cast.gd)
var _crowd := []           # market-goers and regulars: {"d": their entry, "kind", ...}
var _crowd_i := 0
var _walkers_here := 0
var _signs := {}           # place -> [OPEN/CLOSED Label3D, was it open, hours Label3D, board material]
var _lamps := []           # [OmniLight3D, its daytime brightness, outside a door?]
var _keep_clear := []      # spots nobody stands on: doorways, seats, boards, everyone's places
var _evening := -1.0
var _life_rng := RandomNumberGenerator.new()
var _sight_left := 0       # "is a wall in the way?" checks left this frame


func _build_town_life() -> void:
	_life_rng.seed = hash("%d:town life" % SEED)
	for c in _cast:
		_cast_by_id[c["id"]] = c
		life[c["id"]] = {"place": "", "dest": {}, "state": "at", "path": PackedVector3Array(), "k": 0,
				"pace": float(TownData.WALK_PACE.get(c["id"], TownData.WALK_PACE["default"])),
				"at": c["node"].position, "wait": 0.0}
	_list_keep_clear()
	_find_home_doors()
	for id in _cast_by_id:
		for step in TownData.ROUTINES.get(id, []):
			_dest(id, step[1])     # find every visitor's spot now, not in the middle of the day
	_add_crowd()
	_make_open_signs()
	for n in city.get_children():
		if n is OmniLight3D:
			_lamps.append([n, n.light_energy, n.get_meta("outdoor", false)])   # the buildings' lamps (the only lights so far)


## The day's clock moved on. snap: everyone goes straight to where they'd be at this
## hour (only when nobody can see: the game starting, the screen dark between days).
func set_town_hour(h: float, snap := false) -> void:
	town_hour = h
	if snap:
		_snap_town()


## The lamps in and outside the buildings glow brighter in the evening (0 = day, 1 = evening).
func set_evening_lamps(k: float) -> void:
	if absf(k - _evening) < 0.01:
		return
	_evening = k
	# Only the lamps outside the doors: the lights inside reach through the walls onto
	# the street (they cast no shadows), so turning them up would light the street too.
	for l in _lamps:
		if l[2]:
			l[0].light_energy = l[1] * lerpf(1.0, T.EVENING_LAMPS, k)


## Where a resident is right now (a place like "guild"), or "" while walking or away.
func resident_place(id: String) -> String:
	var L: Dictionary = life.get(id, {})
	if L.is_empty() or L["state"] != "at" or cast_away.has(id):
		return ""
	return L["place"]


## True if nobody would see a person at p (on the city) appear or vanish: out of the
## camera's view, far from it, or behind a wall. (Only a few wall checks a frame: when
## they've run out, someone in view counts as seen, and waits for the next frame.)
func unseen(p: Vector3) -> bool:
	if camera == null:
		return true
	var head := p + Vector3(0, 1.5, 0)
	var g := city.to_global(head)
	var cam := camera.global_position
	if g.distance_to(cam) > SEEN_DISTANCE or not camera.is_position_in_frustum(g):
		return true
	if _sight_left <= 0:
		return false
	_sight_left -= 1
	return first_hit(city.to_local(cam), head) < 0.97


func _update_town_life(delta: float) -> void:
	_sight_left = SIGHT_CHECKS_PER_FRAME
	_update_crowd(PRESENCE_CHECKS_PER_FRAME)
	for c in _cast:
		_update_resident(c, delta)
	_route_work()
	_update_signs()


func _snap_town() -> void:
	var share := DayRules.crowd_share(town_hour)
	_walkers_here = 0
	for e in _crowd:
		e["d"]["here"] = _wanted(e, share)
		if e["kind"] == "walker" and e["d"]["here"]:
			_walkers_here += 1
	market_share = float(_walkers_here) / maxf(1.0, market_people.size())
	_rq.clear()
	_r_id = ""
	for c in _cast:
		_snap_resident(c)
	_update_signs()


# ---------------------------------------------------------------- the market and the regulars

## Everyone who comes and goes with the day: the market's walkers (each with a place in
## the queue, so the crowd fills up and thins out gradually), the market's standing
## people (each with their own arrival and leaving time) and the regulars in the places.
func _add_crowd() -> void:
	var n := market_people.size()
	var order := range(n)
	for i in range(n - 1, 0, -1):   # shuffled, so the people who come first are spread along the street
		var j := _life_rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	for i in n:
		_crowd.append({"d": market_people[i], "kind": "walker", "rank": (order[i] + 0.5) / n})
	var groups := {}
	for idl in market_idlers:
		var keeper: bool = idl.get("kind", "") == "keeper"
		var times: Dictionary = TownData.MARKET_KEEPERS if keeper else TownData.MARKET_STANDERS
		var g = idl.get("group", -1)
		if g == -1 or not groups.has(g):
			var arrive := _life_rng.randf_range(times["arrive"][0], times["arrive"][1])
			var leave := _life_rng.randf_range(times["leave"][0], times["leave"][1])
			if g != -1:
				groups[g] = [arrive, leave]   # a chatting group comes and goes together
			_crowd.append({"d": idl, "kind": "stander", "arrive": arrive, "leave": leave})
		else:
			_crowd.append({"d": idl, "kind": "stander", "arrive": groups[g][0], "leave": groups[g][1]})
	var count := {}
	for e in _extra_nodes:
		var w: String = e["where"]
		count[w] = count.get(w, 0) + 1
		# Half the regulars (the 1st, 3rd...) come in whenever it's open, the rest when it's busy
		_crowd.append({"d": e, "kind": "regular", "where": w, "always": count[w] % 2 == 1})


func _wanted(e: Dictionary, share: float) -> bool:
	match e["kind"]:
		"walker":
			return e["rank"] < share
		"stander":
			return town_hour >= e["arrive"] and town_hour < e["leave"]
		"regular":
			var w: String = e["where"]
			if not DayRules.is_open(w, town_hour):
				return false
			return e["always"] or not DayRules.has_busy_hours(w) or DayRules.is_busy(w, town_hour)
	return true


## A few people each frame: anyone who should come or go does, if nobody's looking.
func _update_crowd(budget: int) -> void:
	if _crowd.is_empty():
		return
	var share := DayRules.crowd_share(town_hour)
	for n in mini(budget, _crowd.size()):
		_crowd_i = (_crowd_i + 1) % _crowd.size()
		var e: Dictionary = _crowd[_crowd_i]
		var d: Dictionary = e["d"]
		var want := _wanted(e, share)
		if d["here"] != want and unseen(d["node"].position):
			d["here"] = want
			if e["kind"] == "walker":
				_walkers_here += 1 if want else -1
	market_share = float(_walkers_here) / maxf(1.0, market_people.size())


# ---------------------------------------------------------------- OPEN / CLOSED plaques

## A small board beside each place's door: OPEN (green, softly lit) or CLOSED (dark), and the hours.
func _make_open_signs() -> void:
	var board := BoxMesh.new()
	board.size = Vector3(0.66, 0.3, 0.05)
	var post := BoxMesh.new()
	post.size = Vector3(0.08, 1.4, 0.08)
	for k in facilities:
		if not DayRules.has_hours(k):
			continue
		var f: Dictionary = facilities[k]
		var out: Vector3 = f["door_out"] - f["door_in"]
		out.y = 0.0
		out = out.normalized()
		var side := Vector3(-out.z, 0.0, out.x)
		var at: Vector3
		var on_post: bool = f.get("open", false)
		if on_post:
			# Bram's open-fronted shed: on a post by the corner of its front
			var r: Rect2i = f["rect"]
			at = Vector3((r.end.x + 1) * VS, f["door_out"].y + 1.45, (r.position.y + 4) * VS)
		else:
			# On the wall beside the doorway, at eye height (clear of the door frame,
			# the lamps above and the things standing outside)
			var wall: Vector3 = f["door_in"].lerp(f["door_out"], 8.0 / 18.0)
			at = wall + side * 1.25 + out * 0.17 + Vector3(0, 1.45, 0)
		var holder := Node3D.new()
		holder.position = at
		holder.rotation.y = atan2(out.x, out.z)
		city.add_child(holder)
		var mat := StandardMaterial3D.new()   # its own: open, the board turns green and glows a little
		mat.albedo_color = PAL[P.WOOD_DARK].darkened(0.25)
		mat.emission_enabled = true   # always on (switching it would rebuild the shader): open sets its strength
		mat.emission = Color(0.3, 0.75, 0.4)
		var mi := MeshInstance3D.new()
		mi.mesh = board
		mi.material_override = mat
		holder.add_child(mi)
		if on_post:
			var pm := MeshInstance3D.new()
			pm.mesh = post
			pm.material_override = mat
			pm.position = Vector3(0, -0.75, -0.05)
			holder.add_child(pm)
		var word := _sign_label(46, Vector3(0, 0.045, 0.03))   # OPEN / CLOSED, big
		var hours := _sign_label(26, Vector3(0, -0.095, 0.03))  # "8:00 - 17:00", small
		holder.add_child(word)
		holder.add_child(hours)
		_signs[k] = [word, null, hours, mat]


func _sign_label(size: int, at: Vector3) -> Label3D:
	var lb := Label3D.new()
	lb.font_size = size
	lb.outline_size = 6
	lb.pixel_size = 0.003
	lb.position = at
	return lb


func _update_signs() -> void:
	for k in _signs:
		var s: Array = _signs[k]
		var open := DayRules.is_open(k, town_hour)
		if s[1] == open:
			continue
		s[1] = open
		var o: Dictionary = TownData.OPEN_HOURS[k]
		var word: Label3D = s[0]
		var hours: Label3D = s[2]
		var mat: StandardMaterial3D = s[3]
		word.text = "OPEN" if open else "CLOSED"
		hours.text = "%s - %s" % [DayRules.clock_text(o["open"]), DayRules.clock_text(o["close"])]
		# Open: warm cream letters on a green board with a soft glow (stands out on the
		# cream and white walls). Closed: dim red on dark wood.
		var ink := Color(1.0, 0.93, 0.72) if open else Color(0.85, 0.38, 0.32)
		for lb in [word, hours]:
			lb.modulate = ink
			lb.outline_modulate = Color(0.05, 0.12, 0.06) if open else Color(0.08, 0.05, 0.03)
		mat.albedo_color = Color(0.16, 0.42, 0.24) if open else PAL[P.WOOD_DARK].darkened(0.25)
		mat.emission_energy_multiplier = 0.25 if open else 0.0


# ---------------------------------------------------------------- the residents' days

## Each resident who goes home gets a front door: the nearest free house door to their
## usual place, with room to stand in front of it.
func _find_home_doors() -> void:
	var taken := {}
	for id in _cast_by_id:
		var needs := false
		for step in TownData.ROUTINES.get(id, []):
			needs = needs or step[1] == "home"
		if not needs:
			continue
		var anchor: Vector3 = cast_spots[id]["pos"]
		var best := -1
		var best_d := INF
		for i in house_doors.size():
			if taken.has(i):
				continue
			var p: Vector3 = house_doors[i][0]
			var d := Vector2(p.x - anchor.x, p.z - anchor.z).length() + absf(p.y - anchor.y) * 4.0
			if d < best_d and _good_stand(p):
				best = i
				best_d = d
		if best >= 0:
			taken[best] = true
			var p: Vector3 = house_doors[best][0]
			var at := Vector3(p.x, (floor_at(p) + 0.5) * VS, p.z)
			home_doors[id] = {"pos": at, "face": -house_doors[best][1], "home": true, "where": ""}
			_keep_clear.append(at)


## A spot a person can stand at for a while: room around it, not on the stairs, not in
## a doorway, and not on anything you use (seats, boards) or anyone's spot.
func _good_stand(p: Vector3) -> bool:
	var i := _col(p)
	if i < 0 or not _roomy(i) or stair_top.has(Vector2i(roundi(p.x / VS), roundi(p.z / VS))):
		return false
	for q: Vector3 in _keep_clear:
		if absf(q.x - p.x) < 1.1 and absf(q.z - p.z) < 1.1 and absf(q.y - p.y) < 2.0 				and Vector2(q.x - p.x, q.z - p.z).length() < 1.1:
			return false
	return true


## Everything a standing spot must keep clear of (made once).
func _list_keep_clear() -> void:
	for k in facilities:
		_keep_clear.append(facilities[k]["door_in"])
		_keep_clear.append(facilities[k]["door_out"])
	for s in interact_spots:
		_keep_clear.append(s["pos"])
	for e in extras:
		_keep_clear.append(e["pos"])
	for id in cast_spots:
		_keep_clear.append(cast_spots[id]["pos"])
		_keep_clear.append_array(cast_spots[id].get("loop", []))
		if cast_spots[id].has("talk_from"):
			_keep_clear.append(cast_spots[id]["talk_from"])
	_keep_clear.append(mira_spot)
	_keep_clear.append(you_spot)


## Where a resident goes for a place: their front door, their usual spot, or a spot
## inside as a visitor. Empty if there's nowhere (no front door found).
func _dest(id: String, place: String) -> Dictionary:
	if place == "home":
		return home_doors.get(id, {})
	if place == TownData.CAST[id]["where"] and cast_spots.has(id):
		return cast_spots[id]
	return _visit_spot(place, id)


## A spot for a visitor in a place (Pell at the tavern after work): the nearest good
## standing spot to the middle of the room, facing whoever works there.
func _visit_spot(place: String, id: String) -> Dictionary:
	if not visit_spots.has(place):
		visit_spots[place] = []
	for v in visit_spots[place]:
		if v["by"] == id:
			return v
	var centre := Vector3.ZERO
	var look_at_p := Vector3.ZERO
	if facilities.has(place):
		var r: Rect2i = facilities[place]["rect"]
		centre = Vector3((r.position.x + r.size.x * 0.5) * VS, facilities[place]["inside"].y, (r.position.y + r.size.y * 0.5) * VS)
	elif place == "plaza":
		centre = plaza_c + Vector3(0, VS * 0.5, 0)
	else:
		for other in cast_spots:
			if cast_spots[other].get("where", "") == place:
				centre = cast_spots[other].get("talk_from", cast_spots[other]["pos"])
	look_at_p = centre
	for other in cast_spots:
		if cast_spots[other].get("where", "") == place and other != id:
			look_at_p = cast_spots[other]["pos"]
	var cx := roundi(centre.x / VS)
	var cz := roundi(centre.z / VS)
	for r in range(0, 60):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var i := _col(Vector3((cx + dx) * VS, 0, (cz + dz) * VS))
				if i < 0 or walk_ok[i] == 0:
					continue
				var p := Vector3((cx + dx) * VS, (walk_floor[i] + 0.5) * VS, (cz + dz) * VS)
				if absf(p.y - centre.y) > 1.0 or (facilities.has(place) and facility_at(p) != place):
					continue
				if _good_stand(p):
					var face := look_at_p - p
					face.y = 0.0
					var v := {"pos": p, "face": face.normalized() if face.length() > 0.1 else Vector3(1, 0, 0), "where": place, "by": id}
					visit_spots[place].append(v)
					_keep_clear.append(p)
					return v
	push_warning("TOWN: no spot for %s at '%s' (a place in town_data.gd ROUTINES?)" % [id, place])
	return {}


## Everyone straight to where they'd be at this hour (nobody can see it happen).
func _snap_resident(c: Dictionary) -> void:
	var id: String = c["id"]
	var L: Dictionary = life[id]
	L["place"] = DayRules.heading(id, town_hour)
	L["dest"] = _dest(id, L["place"])
	L["state"] = "at"
	c["busy"] = false
	cast_away.erase(id)
	var dest: Dictionary = L["dest"]
	if dest.is_empty() or dest.get("home", false):
		cast_away[id] = true   # at home, indoors
	if not dest.is_empty():
		_settle(c, L, dest)


## Puts a resident at a spot: their habits (pacing, polishing...) carry on from there.
func _settle(c: Dictionary, L: Dictionary, dest: Dictionary) -> void:
	var node: Node3D = c["node"]
	node.position = dest["pos"]
	L["at"] = dest["pos"]
	var f: Vector3 = dest["face"]
	c["spot"] = dest
	c["base_yaw"] = atan2(-f.z, f.x)
	c["k"] = 0
	c["wait"] = 1.0
	node.rotation.y = c["base_yaw"]


## What each resident is doing: staying put, waiting for a route, walking, going in at
## their front door, or coming out of it.
func _update_resident(c: Dictionary, delta: float) -> void:
	var id: String = c["id"]
	var L: Dictionary = life[id]
	var want := DayRules.heading(id, town_hour)
	if want != L["place"]:
		_set_off(c, L, want)
	var node: Node3D = c["node"]
	match L["state"]:
		"walk":
			_walk(c, L, delta)
		"in":
			# At their front door: they go inside when nobody's looking
			if unseen(node.position):
				cast_away[id] = true
				L["state"] = "at"
		"out":
			# Indoors, with somewhere to be: they come out when nobody's looking at the door
			if unseen(node.position):
				cast_away.erase(id)
				L["state"] = "walk"
		"vanish":
			# No way there (a clever fake): they slip away when nobody's looking...
			if unseen(node.position):
				cast_away[id] = true
				L["state"] = "appear"
		"appear":
			# ...and turn up there when nobody's looking at that spot
			var dest: Dictionary = L["dest"]
			if dest.is_empty() or dest.get("home", false):
				L["state"] = "at"
				if not dest.is_empty():
					_settle(c, L, dest)
				c["busy"] = false
			elif unseen(dest["pos"]):
				cast_away.erase(id)
				_settle(c, L, dest)
				L["state"] = "at"
				c["busy"] = false


## Time to go somewhere else: ask for a route there.
func _set_off(c: Dictionary, L: Dictionary, place: String) -> void:
	var id: String = c["id"]
	L["place"] = place
	L["dest"] = _dest(id, place)
	var dest: Dictionary = L["dest"]
	if dest.is_empty():
		c["busy"] = true
		L["state"] = "appear" if cast_away.has(id) else "vanish"
		return
	var node: Node3D = c["node"]
	if Vector2(node.position.x - dest["pos"].x, node.position.z - dest["pos"].z).length() < 0.3:
		_arrive(c, L)
		return
	# Someone walking stops while the new route is found; someone at a place carries on
	# with their habit meanwhile
	c["busy"] = L["state"] == "walk"
	L["state"] = "plan"
	if not id in _rq:
		_rq.append(id)


## A route was found (or not): off they go.
func _route_found(id: String, place: String, path: PackedVector3Array) -> void:
	var c: Dictionary = _cast_by_id[id]
	var L: Dictionary = life[id]
	if L["state"] != "plan" or L["place"] != place:
		return   # they've changed their mind since: a new search is on its way
	c["busy"] = true
	if path.is_empty():
		L["state"] = "appear" if cast_away.has(id) else "vanish"
		return
	path.append(L["dest"]["pos"])
	L["path"] = path
	L["k"] = 0
	L["at"] = c["node"].position
	L["wait"] = 0.0
	L["state"] = "out" if cast_away.has(id) else "walk"


func _walk(c: Dictionary, L: Dictionary, delta: float) -> void:
	var node: Node3D = c["node"]
	var path: PackedVector3Array = L["path"]
	var k: int = L["k"]
	var at: Vector3 = L["at"]
	var speed: float = L["pace"]
	# Make way: slow right down when you're just in front of them (for a few seconds at most)
	if player != null and k < path.size():
		var to_you: Vector3 = player.position - at
		to_you.y = 0.0
		var ahead: Vector3 = path[k] - at
		ahead.y = 0.0
		if to_you.length() < MAKE_WAY and to_you.dot(ahead) > 0.0 and L["wait"] < 3.0:
			L["wait"] += delta
			speed *= 0.15
	var step := speed * delta
	while step > 0.0 and k < path.size():
		var to: Vector3 = path[k] - at
		var dist := to.length()
		if dist <= step:
			at = path[k]
			step -= dist
			k += 1
		else:
			at += to / dist * step
			step = 0.0
	L["k"] = k
	L["at"] = at
	node.position = at + Vector3(0, absf(sin(life_t * (12.0 if speed > 2.0 else 8.0) + float(c["phase"]))) * 0.04, 0)
	if k >= path.size():
		_arrive(c, L)
		return
	# Face the way they're going, looking a little ahead so turns are smooth
	var look: Vector3 = path[mini(k + 1, path.size() - 1)] - at
	if look.x * look.x + look.z * look.z > 0.0004:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-look.z, look.x), minf(1.0, 8.0 * delta))


func _arrive(c: Dictionary, L: Dictionary) -> void:
	var dest: Dictionary = L["dest"]
	_settle(c, L, dest)
	if dest.get("home", false):
		L["state"] = "in"        # at the front door: in they go, when nobody's looking
		c["busy"] = true
	else:
		L["state"] = "at"
		c["busy"] = false


# ---------------------------------------------------------------- the route queue
# One route search at a time (routes.gd); residents queue for it.

var _rq := []                       # residents waiting for a route, first come first served
var _r_id := ""                     # whose route is being searched ("" = nobody's)
var _r_for := ""                    # the place that search is for


func _route_work() -> void:
	if _r_id == "":
		while not _rq.is_empty():
			var id: String = _rq.pop_front()
			if life[id]["state"] == "plan":
				var c: Dictionary = _cast_by_id[id]
				route_begin(c["node"].position, life[id]["dest"]["pos"])
				_r_id = id
				_r_for = life[id]["place"]
				break
	if _r_id == "":
		return
	var r := route_step(ROUTE_CELLS_PER_FRAME)
	if r != 0:
		var id := _r_id
		_r_id = ""
		_route_found(id, _r_for, route_points() if r > 0 else PackedVector3Array())
