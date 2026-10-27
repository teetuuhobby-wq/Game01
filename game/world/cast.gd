extends "res://world/people.gd"
## THE WORLD, layer 12 of 13: the town's named residents.
## Each one from town_data.gd, built in their spot from the buildings with the things
## they carry (a ledger, a mug, goggles...), their little habits, and the regulars
## sitting at tables or soaking in the bath. Also hides anyone right in front of the
## camera, so nobody fills the screen.

## Something a character carries, as its own small mesh (person faces +x, feet at 0).
## Half-size blocks, so props can be finer than people.
func _item_mesh(kind: String, top: float) -> MeshInstance3D:
	var pts := []
	var cols := []
	var h := VS * 0.5
	var add := func(x: float, y: float, z: float, c: Color) -> void:
		pts.append(Vector3(x, y, z) * h)
		cols.append(c)
	var hand_y := top / h * 0.36          # roughly hand height, in half-blocks
	match kind:
		"ledger":      # a fat book held against the chest
			for x in range(2, 4):
				for y in range(0, 4):
					for z in range(-2, 2):
						add.call(x, hand_y + y + 2, z, Color(0.55, 0.22, 0.18) if x == 3 or z == -2 else Color(0.95, 0.92, 0.82))
		"mug":         # a frothy mug in the right hand
			for y in range(0, 3):
				add.call(2, hand_y + y, 4, Color(0.62, 0.42, 0.22))
			add.call(2, hand_y + 3, 4, Color(0.98, 0.95, 0.85))
			add.call(3, hand_y + 1, 4, Color(0.62, 0.42, 0.22))
		"goggles":     # brass goggles pushed up on the forehead
			var gy := top / h - 2.0
			for z in range(-3, 4):
				add.call(1.6, gy, z, Color(0.80, 0.62, 0.30))
			for z in [-2, 2]:
				add.call(2.4, gy, z, Color(0.45, 0.75, 0.85))
		"feather_hat": # a wide straw hat with a red feather
			var ty := top / h + 0.5
			for x in range(-3, 5):
				for z in range(-4, 5):
					add.call(x, ty, z, Color(0.94, 0.82, 0.50))
			for x in range(-1, 3):
				for z in range(-2, 3):
					add.call(x, ty + 1, z, Color(0.88, 0.76, 0.44))
			for i in 4:
				add.call(-1 - i * 0.5, ty + 2 + i, -2, Color(0.85, 0.22, 0.20))
		"towels":      # a stack of folded towels in both arms
			for y in range(0, 4):
				for x in range(2, 4):
					for z in range(-2, 2):
						add.call(x, hand_y + 1 + y, z, Color(0.95, 0.95, 0.92) if y % 2 == 0 else Color(0.40, 0.65, 0.78))
		"watering_can":   # a bright green can with a long spout
			var can := Color(0.20, 0.66, 0.50)
			for y in range(0, 3):
				for x in range(0, 3):
					for z in range(5, 7):
						add.call(x, hand_y - 2 + y, z, can)
			for i in 3:
				add.call(3 + i, hand_y - 1 + i, 5.5, can)
			add.call(1, hand_y + 1, 6, can.darkened(0.3))
		"spyglass":    # a long brass spyglass raised to the eye
			var eye_y := top / h - 3.0
			for i in 8:
				for d in [0.0, 1.0]:
					add.call(2 + i, eye_y + d + i * 0.15, 1.0, Color(0.80, 0.62, 0.30) if i < 7 else Color(0.45, 0.75, 0.85))
		"satchel":     # a bag on your right hip, strap across the chest
			for y in range(0, 3):
				for x in range(-1, 2):
					add.call(x, hand_y - 1 + y, 5, Color(0.78, 0.42, 0.20))
			for i in 7:
				add.call(2, hand_y + 1 + i, 4 - i * 1.3, Color(0.92, 0.80, 0.30))
		"spectacles":  # little gold-rimmed glasses over the eyes
			var ey := top / h - 3.5
			for z in [-3, -2, -1, 1, 2, 3]:
				add.call(2.3, ey + (0.5 if absi(z) == 2 else 0.0), z, Color(0.95, 0.80, 0.35))
			add.call(2.3, ey, 0, Color(0.95, 0.80, 0.35))
		"tall_bun":    # a big bun on top of the head
			var by := top / h
			for y in range(0, 3):
				for x in range(-1, 1):
					for z in range(-1, 1):
						add.call(x, by + y, z + 0.5, Color(0.70, 0.68, 0.66))
		"brim_hat":    # a wide, battered hat
			var hy := top / h + 0.3
			for x in range(-4, 5):
				for z in range(-4, 5):
					add.call(x, hy, z, Color(0.42, 0.32, 0.22))
			for x in range(-2, 3):
				for z in range(-2, 3):
					add.call(x, hy + 1, z, Color(0.36, 0.27, 0.18))
					add.call(x, hy + 2, z, Color(0.36, 0.27, 0.18))
		"head_towel":  # a white towel wrapped up on the head
			var wy := top / h
			for y in range(0, 2):
				for x in range(-2, 3):
					for z in range(-3, 4):
						if absi(x) + absi(z) < 5:
							add.call(x, wy + y, z, Color(0.97, 0.97, 0.95))
		"cap":         # a bright red cap with a peak
			var cy := top / h + 0.3
			for x in range(-2, 3):
				for z in range(-2, 3):
					add.call(x, cy, z, Color(0.88, 0.20, 0.18))
			for x in range(3, 5):
				for z in range(-2, 3):
					add.call(x, cy - 0.5, z, Color(0.88, 0.20, 0.18))
	var mesh := _cubes(PackedVector3Array(pts), PackedColorArray(cols), h, false)
	return _mi(mesh)


const HABIT_SPEEDS := {"run": 2.6, "stroll": 0.7, "pace": 0.6}   # metres per second
const NOTICE_YOU := 2.6           # metres: residents turn to you (and walkers stop) this close

var _cast_rng := RandomNumberGenerator.new()   # the cast's own, so it never reshuffles the crowd
var cast_nodes := {}    # cast id -> Node3D (the named residents)
var _cast := []         # [{"id", "node", "spot", "habit", "base_yaw", "k", "wait", "phase"}]
var _extra_nodes := []


## The named residents (town_data.gd), each in their spot from the buildings, plus the
## unnamed regulars sitting at tables and soaking in the bath. Mira is made by the errand.
func _add_cast() -> void:
	var Town := preload("res://town_data.gd")
	_cast_rng.seed = hash("%d:cast habits" % SEED)
	for id in Town.CAST:
		if id == "mira" or not cast_spots.has(id):
			continue
		var c: Dictionary = Town.CAST[id]
		var node := _make_character(c)
		var spot: Dictionary = cast_spots[id]
		node.position = spot["pos"]
		var f: Vector3 = spot["face"]
		node.rotation.y = atan2(-f.z, f.x)
		city.add_child(node)
		cast_nodes[id] = node
		_cast.append({"id": id, "node": node, "spot": spot, "habit": c["habit"], "base_yaw": node.rotation.y,
				"k": 0, "wait": _cast_rng.randf_range(0.5, 2.0), "phase": _cast_rng.randf() * TAU})
	for e in extras:
		var node := Node3D.new()
		var mi := _random_person_sitting()
		node.add_child(mi)
		node.position = e["pos"] + (Vector3(0, -0.36, 0) if e["pose"] == "soak" else Vector3.ZERO)
		var f: Vector3 = e["face"]
		node.rotation.y = atan2(-f.z, f.x)
		city.add_child(node)
		_extra_nodes.append({"node": node, "phase": _cast_rng.randf() * TAU, "yaw": node.rotation.y})


func _make_character(c: Dictionary) -> Node3D:
	var node := Node3D.new()
	var mi := _make_person(c["shirt"], c["bottom"], c["hair"], c["skin"], c["look"])
	node.add_child(mi)
	var top: float = mi.mesh.get_meta("top", 1.8)
	for item in c.get("items", []):
		node.add_child(_item_mesh(item, top))
	if c.get("kid", false):
		node.scale = Vector3.ONE * 0.72
	return node


## A random regular, sitting down (same variety as everyone else).
func _random_person_sitting() -> MeshInstance3D:
	var mi := _random_person()
	var look: Dictionary = mi.get_meta("look", {})
	look["sitting"] = true
	look["legs"] = 3
	return _make_person(mi.get_meta("shirt"), mi.get_meta("bottom"), mi.get_meta("hair"), mi.get_meta("skin"), look)


## Little habits: the clerk writes, the barkeep polishes and glances round, Bram hammers,
## Pell paces behind the counter, Tamsin strolls round the pool, Wendel scans the
## horizon, Pip runs errands. Anyone turns to face you when you come close.
func _update_cast(delta: float) -> void:
	var you := Vector3(INF, INF, INF)
	if player != null:
		you = player.position
	for c in _cast:
		var node: Node3D = c["node"]
		c["phase"] += delta
		var ph: float = c["phase"]
		var to_you: Vector3 = you - node.position
		to_you.y = 0.0
		var near := to_you.length() < NOTICE_YOU
		var loop: Array = c["spot"].get("loop", [])
		if not loop.is_empty() and not near:
			var speed := HABIT_SPEEDS.get(c["habit"], 0.8) as float
			if c["wait"] > 0.0:
				c["wait"] -= delta
			else:
				var goal: Vector3 = loop[c["k"]]
				var d := goal - node.position
				d.y = 0.0
				if d.length() < 0.1:
					c["k"] = (c["k"] + 1) % loop.size()
					c["wait"] = _cast_rng.randf_range(0.3, 1.2) if c["habit"] == "run" else _cast_rng.randf_range(1.0, 3.5)
				else:
					var step := d.normalized() * minf(speed * delta, d.length())
					node.position += step
					node.rotation.y = lerp_angle(node.rotation.y, atan2(-step.z, step.x), minf(1.0, 10.0 * delta))
					node.position.y = loop[0].y + absf(sin(ph * speed * 6.0)) * 0.04
			continue
		var yaw: float = c["base_yaw"]
		if near and to_you.length() > 0.2:
			yaw = atan2(-to_you.z, to_you.x)
		match c["habit"]:
			"write":
				node.position.y = c["spot"]["pos"].y - absf(sin(ph * 1.7)) * 0.03
			"polish":
				if not near:
					yaw += sin(ph * 0.6) * 0.35
			"hammer":
				node.position.y = c["spot"]["pos"].y + (absf(sin(ph * 9.0)) * 0.05 if fmod(ph, 4.0) < 1.6 else 0.0)
			"scan":
				if not near:
					yaw += sin(ph * 0.25) * 0.9
		node.rotation.y = lerp_angle(node.rotation.y, yaw, minf(1.0, 4.0 * delta))
	for e in _extra_nodes:
		e["phase"] += delta
		var n: Node3D = e["node"]
		n.rotation.y = e["yaw"] + sin(e["phase"] * 0.4) * 0.25


## Nobody's body fills the screen: anyone close to the camera is hidden (see people.gd),
## the neighbours round the plaza and on the terraces, the regulars and the named residents.
func _hide_close_residents() -> void:
	if camera == null:
		return
	var cam := city.to_local(camera.global_position)
	for w in walkers:
		w["node"].visible = _mk_clear_of_camera(w["node"].position, cam)
	for pw in promenaders:
		pw["node"].visible = _mk_clear_of_camera(pw["node"].position, cam)
	for e in _extra_nodes:
		e["node"].visible = _mk_clear_of_camera(e["node"].position, cam)
	# The named residents and Mira too, or walking into the barkeep fills the screen
	for id in cast_nodes:
		var n: Node3D = cast_nodes[id]
		n.visible = _mk_clear_of_camera(n.position, cam)
