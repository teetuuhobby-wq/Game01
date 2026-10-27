extends "res://world/legs.gd"
## THE WORLD, layer 8 of 9: the city's people.
## How a person is built from blocks, the neighbours round the plaza and along the
## terraces (they stop to look at you), and the market crowd: strollers keeping to
## the right, browsers, kids, people carrying crates, chatting groups, shopkeepers.


func _make_person(shirt: Color, pants: Color, hair: Color, skin: Color) -> MeshInstance3D:
	var pts := []    # plain Arrays: lambdas would copy packed arrays
	var cols := []
	var add := func(x: int, y: int, z: int, c: Color) -> void:
		pts.append(Vector3((x - 0.5) * VS, (y + 0.5) * VS, z * VS))
		cols.append(c)
	for y in 3:
		for x in 2:
			add.call(x, y, -1, pants)
			add.call(x, y, 1, pants)
	for y in range(3, 6):
		for x in 2:
			for z in range(-1, 2):
				add.call(x, y, z, shirt)
		add.call(1 if y == 3 else 0, y, -2, skin if y == 3 else shirt)
		add.call(1 if y == 3 else 0, y, 2, skin if y == 3 else shirt)
	for y in range(6, 9):
		for x in 2:
			for z in range(-1, 2):
				var c := skin
				if y == 8 or x == 0:
					c = hair
				elif y == 7 and x == 1 and z != 0:
					c = Color(0.15, 0.12, 0.10)
				add.call(x, y, z, c)
	return _mi(_cubes(PackedVector3Array(pts), PackedColorArray(cols), VS, true))


func _random_person() -> MeshInstance3D:
	var shirts := [Color(0.16, 0.55, 0.58), Color(0.82, 0.30, 0.26), Color(0.94, 0.80, 0.40),
			Color(0.96, 0.95, 0.90), Color(0.40, 0.52, 0.78), Color(0.55, 0.70, 0.40)]
	var pants := [Color(0.30, 0.24, 0.20), Color(0.24, 0.28, 0.38), Color(0.55, 0.48, 0.38)]
	var hairs := [Color(0.20, 0.13, 0.08), Color(0.45, 0.30, 0.15), Color(0.10, 0.09, 0.08), Color(0.80, 0.70, 0.45)]
	var skins := [Color(0.92, 0.75, 0.62), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.26)]
	return _make_person(shirts[rng.randi() % shirts.size()], pants[rng.randi() % pants.size()],
			hairs[rng.randi() % hairs.size()], skins[rng.randi() % skins.size()])


func _ring_radius() -> float:
	# Two walking rings in the plaza (metres): inside the parasols, or outside them.
	return rng.randf_range(3.1, 3.6) if rng.randf() < 0.5 else rng.randf_range(6.8, 7.4)


## Where to cross between the two rings: the gap between parasols nearest to
## angle a (leaving out your gap). Returned close to a, so walkers take the short way.
func _crossing_near(a: float) -> float:
	var best := INF
	for g in 6:
		if g == YOUR_GAP:
			continue
		var d := wrapf(PARASOL_A0 + TAU * (g + 0.5) / 6.0 - a, -PI, PI)
		if absf(d) < absf(best):
			best = d
	return a + best


func _add_residents() -> void:
	# Where you start: between two parasols, facing out from the fountain toward the houses.
	# Mira, who asks you for help, stands just beside you.
	var ra := PARASOL_A0 + TAU * (YOUR_GAP + 0.5) / 6.0
	you_spot = plaza_c + Vector3(cos(ra) * 5.0, VS * 0.5, sin(ra) * 5.0)
	you_yaw = -ra
	mira_spot = plaza_c + Vector3(cos(ra + 0.16) * 5.0, VS * 0.5, sin(ra + 0.16) * 5.0)
	for i in WALKERS:
		var node := Node3D.new()
		node.add_child(_random_person())
		city.add_child(node)
		var r := _ring_radius()
		var a := rng.randf() * TAU
		node.position = plaza_c + Vector3(cos(a) * r, VS * 0.5, sin(a) * r)
		node.rotation.y = -a - PI * 0.5
		walkers.append({"node": node, "a": a, "r": r, "ta": rng.randf() * TAU,
				"tr": r, "wait": rng.randf() * 3.0, "speed": rng.randf_range(0.9, 1.4)})
	# Residents strolling along each terrace's edge, just inside the balustrade
	for l in LEVELS.size():
		var reach: float = LEVELS[l][0]
		for i in PROMENADE_WALKERS[l]:
			var node := Node3D.new()
			node.add_child(_random_person())
			city.add_child(node)
			var a := rng.randf() * TAU
			var pw := {"node": node, "a": a, "ta": a, "wait": rng.randf() * 4.0, "speed": rng.randf_range(0.8, 1.3),
					"rx": (RXV * reach - 6) * VS, "rz": (RZV * reach - 6) * VS, "y": (LEVELS[l][1] + 0.5) * VS}
			node.position = _promenade_point(pw, a)
			node.rotation.y = -a - PI * 0.5
			promenaders.append(pw)
	_add_market_crowd()


func _update_walkers(delta: float) -> void:
	for w in walkers:
		var node: Node3D = w["node"]
		if _notice(w, node):
			continue
		if w["wait"] > 0.0:
			w["wait"] -= delta
			node.position.y = plaza_c.y + VS * 0.5
			continue
		var da := wrapf(w["ta"] - w["a"], -PI, PI)
		var dr: float = w["tr"] - w["r"]
		var r: float = w["r"]
		var step: float = w["speed"] * delta / maxf(r, 1.0)
		if absf(da) < 0.02 and absf(dr) < 0.05:
			w["wait"] = rng.randf_range(1.0, 5.0)
			var new_r := _ring_radius() if rng.randf() < 0.3 else r
			if (new_r < 5.0) != (r < 5.0):
				# Changing ring: walk round to a gap between parasols first.
				w["ta"] = _crossing_near(w["a"])
			else:
				w["ta"] = w["a"] + rng.randf_range(-1.6, 1.6)
			w["tr"] = new_r
			continue
		w["a"] += clampf(da, -step, step)
		# Only step across between the rings once at the gap, so nobody walks through the tables.
		var crossing: bool = (w["tr"] < 5.0) != (r < 5.0)
		if not crossing or absf(da) < 0.05:
			w["r"] += clampf(dr, -0.6 * delta, 0.6 * delta)
		var a: float = w["a"]
		r = w["r"]
		var pos := plaza_c + Vector3(cos(a) * r, VS * 0.5 + absf(sin(life_t * 9.0 + a * 5.0)) * 0.05, sin(a) * r)
		var move := Vector3(pos.x - node.position.x, 0, pos.z - node.position.z)
		node.position = pos
		# Face the way they walk (person mesh faces +x)
		if move.length_squared() > 1e-10:
			node.rotation.y = atan2(-move.z, move.x)


## Neighbours stop for a moment and turn to look at you when you walk past.
func _notice(w: Dictionary, node: Node3D) -> bool:
	if player == null:
		return false
	var d: Vector3 = player.position - node.position
	if d.x * d.x + d.z * d.z > NOTICE * NOTICE:
		return false
	w["wait"] = maxf(w["wait"], 0.8)
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-d.z, d.x), 0.2)
	return true


## A point on a promenade (just inside a terrace's edge), with a little walking bob.
func _promenade_point(pw: Dictionary, a: float) -> Vector3:
	var p := _round_rect(pw["rx"], pw["rz"], a)
	return Vector3(p.x, pw["y"] + absf(sin(life_t * 9.0 + a * 37.0)) * 0.05, p.y)


func _update_promenaders(delta: float) -> void:
	for pw in promenaders:
		var node: Node3D = pw["node"]
		if _notice(pw, node):
			continue
		if pw["wait"] > 0.0:
			pw["wait"] -= delta
			continue
		var a: float = pw["a"]
		var da: float = pw["ta"] - a
		if absf(da) < 0.002:
			pw["wait"] = rng.randf_range(0.5, 4.0)
			pw["ta"] = a + rng.randf_range(0.3, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0)
			continue
		# Turn walking speed into an angle step (the path is longer per radian on its long sides).
		var per_rad := (_round_rect(pw["rx"], pw["rz"], a + 0.001) - _round_rect(pw["rx"], pw["rz"], a)).length() / 0.001
		var step: float = pw["speed"] * delta / maxf(per_rad, 0.5)
		pw["a"] = a + clampf(da, -step, step)
		var pos := _promenade_point(pw, pw["a"])
		var move := pos - node.position
		node.position = pos
		if Vector2(move.x, move.z).length_squared() > 1e-10:
			node.rotation.y = atan2(-move.z, move.x)


enum Mk { WALK, BROWSE_IN, BROWSE, TURN }


var market_people := []


var market_idlers := []   # shopkeepers and chatting groups: they stand and fidget


var _mk_len := 0.0


func _add_market_crowd() -> void:
	if market_path.size() < 2:
		return
	_mk_len = (market_path.size() - 1) * 0.5
	var looks := []
	for i in 16:
		looks.append(_random_person().mesh)
	var crates := []
	for c in [P.WOOD, P.RED, P.AWN1, P.LEAF]:
		var m := BoxMesh.new()
		m.size = Vector3(0.4, 0.25, 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PAL[c]
		m.material = mat
		crates.append(m)
	var hats := []
	for h in [[Vector3(0.55, 0.08, 0.55), Color(0.94, 0.82, 0.50)], [Vector3(0.42, 0.16, 0.42), Color(0.80, 0.22, 0.20)],
			[Vector3(0.42, 0.16, 0.42), Color(0.22, 0.36, 0.62)], [Vector3(0.45, 0.22, 0.45), Color(0.96, 0.95, 0.90)],
			[Vector3(0.55, 0.08, 0.55), Color(0.40, 0.30, 0.20)]]:
		var hm := BoxMesh.new()
		hm.size = h[0]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = h[1]
		hm.material = mat
		hats.append(hm)
	for i in T.MARKET_WALKERS:
		var kid := rng.randf() < T.MARKET_KIDS
		var node := _mk_person(looks, kid)
		_mk_hat(node, hats)
		if not kid and rng.randf() < T.MARKET_CARRY:
			var crate := MeshInstance3D.new()
			crate.mesh = crates[rng.randi() % crates.size()]
			crate.position = Vector3(0.0, 1.95, 0.0)
			node.add_child(crate)
		var dir := 1 if rng.randf() < 0.5 else -1
		var lane := _mk_lane(dir)
		var s := rng.randf_range(1.0, _mk_len - 1.0)
		node.position = _mk_point(s, lane)
		market_people.append({"node": node, "s": s, "dir": dir, "lane": lane, "goal": lane,
				"speed": rng.randf_range(2.0, 2.8) if kid else rng.randf_range(0.8, 1.35),
				"state": Mk.WALK, "timer": 0.0, "kid": kid})
	for g in T.MARKET_GROUPS:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var c := _mk_point(rng.randf_range(6.0, _mk_len - 6.0), side * 2.6)
		var n := rng.randi_range(2, 4)
		for k in n:
			var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
			var node := _mk_person(looks, false)
			_mk_hat(node, hats)
			node.position = c + Vector3(cos(a), 0.0, sin(a)) * 0.6
			var to_c := c - node.position
			node.rotation.y = atan2(-to_c.z, to_c.x)
			market_idlers.append({"node": node, "yaw": node.rotation.y, "phase": rng.randf() * TAU})
	for sk in shopkeepers + shoppers:
		var node := _mk_person(looks, false)
		node.position = sk[0]
		var f: Vector3 = sk[1]
		node.rotation.y = atan2(-f.z, f.x)
		market_idlers.append({"node": node, "yaw": node.rotation.y, "phase": rng.randf() * TAU})
	print("market crowd: %d walking, %d standing" % [market_people.size(), market_idlers.size()])


## A resident sharing one of a few ready-made looks (kids are smaller).
func _mk_person(looks: Array, kid: bool) -> Node3D:
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = looks[rng.randi() % looks.size()]
	node.add_child(mi)
	if kid:
		node.scale = Vector3.ONE * 0.72
	city.add_child(node)
	return node


## Some people wear a hat or a headscarf (a small box on the head).
func _mk_hat(node: Node3D, hats: Array) -> void:
	if rng.randf() < 0.45:
		var hat := MeshInstance3D.new()
		hat.mesh = hats[rng.randi() % hats.size()]
		hat.position = Vector3(0.0, 1.8 + hat.mesh.size.y * 0.5, 0.0)
		node.add_child(hat)


## A lane on your right-hand side of the street for the way you're walking.
func _mk_lane(dir: int) -> float:
	return -dir * rng.randf_range(0.4, 3.0)


func _mk_index(s: float) -> Vector2:
	var f := clampf(s / 0.5, 0.0, market_path.size() - 1.001)
	return Vector2(floorf(f), f - floorf(f))


## Direction along the street at s (metres from the east end).
func _mk_tangent(s: float) -> Vector3:
	var k := _mk_index(s)
	return market_dir[int(k.x)].lerp(market_dir[int(k.x) + 1], k.y).normalized()


## Sideways direction at s, toward the city's middle.
func _mk_normal(s: float) -> Vector3:
	var d := _mk_tangent(s)
	return Vector3(-d.z, 0.0, d.x)


## A point on the street, s metres along and `lane` metres across (on the city).
func _mk_point(s: float, lane: float) -> Vector3:
	var k := _mk_index(s)
	return market_path[int(k.x)].lerp(market_path[int(k.x) + 1], k.y) + _mk_normal(s) * lane


## People closer than 0.9 m to the camera are hidden, so nobody's head fills the screen.
func _mk_clear_of_camera(p: Vector3, cam: Vector3) -> bool:
	return (p + Vector3(0.0, 1.0, 0.0)).distance_to(cam) > 0.9


func _update_market(delta: float) -> void:
	var you := Vector2(INF, INF)
	if player != null:
		you = Vector2(player.position.x, player.position.z)
	var cam := Vector3(INF, INF, INF)
	if camera != null:
		cam = city.to_local(camera.global_position)
	for pp in market_people:
		var node: Node3D = pp["node"]
		var s: float = pp["s"]
		var lane: float = pp["lane"]
		var dir: int = pp["dir"]
		var st: int = pp["state"]
		var kid: bool = pp["kid"]
		var face := Vector3.ZERO
		if st == Mk.TURN or st == Mk.BROWSE:
			pp["timer"] -= delta
			if st == Mk.BROWSE:
				face = _mk_normal(s) * (1.0 if lane >= 0.0 else -1.0)
			if pp["timer"] <= 0.0:
				if st == Mk.TURN:
					dir = -dir
					pp["dir"] = dir
				pp["state"] = Mk.WALK
				pp["goal"] = _mk_lane(dir)
		else:
			var goal: float = pp["goal"]
			var spd: float = pp["speed"]
			# Step aside (and slow down) when you're in the way
			var here := _mk_point(s, lane)
			var off := Vector2(here.x - you.x, here.z - you.y)
			if off.length() < 1.0:
				var nrm := _mk_normal(s)
				spd *= 0.4
				lane += (1.0 if off.dot(Vector2(nrm.x, nrm.z)) >= 0.0 else -1.0) * 1.5 * delta
			lane = clampf(move_toward(lane, goal, (1.2 if st == Mk.BROWSE_IN else 0.5) * delta), -3.1, 3.1)
			if st == Mk.BROWSE_IN:
				s += dir * spd * 0.3 * delta
				if absf(lane - goal) < 0.05:
					pp["state"] = Mk.BROWSE
					pp["timer"] = rng.randf_range(3.0, 9.0)
			else:
				s += dir * spd * delta
				if rng.randf() < delta * (0.3 if kid else 0.05):
					pp["goal"] = _mk_lane(dir)
				elif not kid and rng.randf() < delta * 0.035:
					pp["state"] = Mk.BROWSE_IN
					pp["goal"] = 3.1 if lane >= 0.0 else -3.1
				if s < 0.5 or s > _mk_len - 0.5:
					s = clampf(s, 0.5, _mk_len - 0.5)
					pp["state"] = Mk.TURN
					pp["timer"] = rng.randf_range(0.5, 3.0)
			face = _mk_tangent(s) * dir + _mk_normal(s) * clampf(float(pp["goal"]) - lane, -1.0, 1.0) * 0.4
		pp["s"] = s
		pp["lane"] = lane
		var p := _mk_point(s, lane)
		var moving: bool = pp["state"] == Mk.WALK or pp["state"] == Mk.BROWSE_IN
		var bob := absf(sin(life_t * (13.0 if kid else 9.0) + s * 3.0)) * 0.05 if moving else 0.0
		node.position = Vector3(p.x, VS * 0.5 + bob, p.z)
		node.visible = _mk_clear_of_camera(node.position, cam)
		if face.length_squared() > 0.0001:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-face.z, face.x), minf(1.0, 8.0 * delta))
	for idl in market_idlers:
		var node: Node3D = idl["node"]
		node.visible = _mk_clear_of_camera(node.position, cam)
		node.rotation.y = float(idl["yaw"]) + sin(life_t * 0.6 + float(idl["phase"])) * 0.35
