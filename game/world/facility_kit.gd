extends "res://world/errand_sites.gd"
## THE WORLD, layer 6 of 13: the building kit for the town's places with a purpose.
## Shared pieces the buildings in facilities.gd are made of: walls, floors and beams,
## open doorways, signs (name boards and hanging picture signs), windows, lanterns,
## barrels, seats you can sit on; and the lists the rest of the game reads:
##   facilities     - each building's outline, its door and a point inside (for tests)
##   interact_spots - things you can use with E (boards, seats, the hearth...)
##   cast_spots     - where each named resident stands (town_data.gd says who they are)
##   extras         - unnamed regulars (sitting at tables, soaking in the pool)
##   fac_lights / fac_particles / fac_signs - lights, steam and name signs, made into
##                    nodes once the blocks are built (_add_facility_nodes)
## All numbers are blocks (5 per metre) unless they say metres.

const FAC_DOOR_HALF := 3                     # doorways are 7 blocks (1.4 m) wide
const FAC_DOOR_TOP := 13                     # and 13 blocks (2.6 m) tall

var facilities := {}      # kind -> {"name", "rect", "door_out", "door_in", "inside", "level", "open" (front, if true)}
var interact_spots := []  # {"id", "kind" (read/look/sit), "pos", "label", "face", "where"}
var cast_spots := {}      # cast id -> {"pos", "face", "loop" (points, metres), "where"}
var extras := []          # {"pos", "face", "pose" ("sit"/"soak"/"stand"), "where"}
var fac_lights := []      # [position (metres), colour, energy, range]
var fac_particles := []   # [position (metres), kind ("steam")]
var fac_signs := []       # [position (metres), outward direction, text]


## Metres on the city for a block position (people stand half a block above the floor block).
func _mp(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y + 0.5, z) * VS


## Outer walls, one block thick, from the floor to `top`. wall(x, y, z) picks each block.
func _fac_walls(x0: int, z0: int, x1: int, z1: int, top: int, wall: Callable) -> void:
	for y in range(1, top + 1):
		for x in range(x0, x1 + 1):
			sv(x, y, z0, wall.call(x, y, z0))
			sv(x, y, z1, wall.call(x, y, z1))
		for z in range(z0 + 1, z1):
			sv(x0, y, z, wall.call(x0, y, z))
			sv(x1, y, z, wall.call(x1, y, z))


## The inside floor (replacing the street paving) and a ceiling just under the roof.
func _fac_floor(x0: int, z0: int, x1: int, z1: int, floor_p: Callable, ceiling_y: int, ceiling_p: int) -> void:
	for x in range(x0 + 1, x1):
		for z in range(z0 + 1, z1):
			sv(x, 0, z, floor_p.call(x, z))
			sv(x, ceiling_y, z, ceiling_p)


## Wooden beams across the room, every `every` blocks, at height y.
func _fac_beams(x0: int, z0: int, x1: int, z1: int, y: int, every: int, along_x: bool) -> void:
	if along_x:
		for z in range(z0 + every, z1, every):
			box3(x0 + 1, y, z, x1 - 1, y + 1, z, P.WOOD_DARK)
	else:
		for x in range(x0 + every, x1, every):
			box3(x, y, z0 + 1, x, y + 1, z1 - 1, P.WOOD_DARK)


## An open doorway in one wall (side: an entry of _sides), centred at uc along it, with
## a stone frame and lamps either side above head height. Nothing on the floor, so you
## walk straight in. Returns [outside point, inside point] in metres.
func _fac_doorway(side: Array, uc: int, frame: int) -> Array:
	var o: Vector3i = side[0]
	var a: Vector3i = side[1]
	var n: Vector3i = side[2]
	for u in range(uc - FAC_DOOR_HALF, uc + FAC_DOOR_HALF + 1):
		for y in range(1, FAC_DOOR_TOP + 1):
			if y == FAC_DOOR_TOP and absi(u - uc) == FAC_DOOR_HALF:
				continue   # rounded corners
			clv(fp(o, a, n, u, y, 0))
	for y in range(1, FAC_DOOR_TOP + 2):
		svv(fp(o, a, n, uc - FAC_DOOR_HALF - 1, y, 0), frame)
		svv(fp(o, a, n, uc + FAC_DOOR_HALF + 1, y, 0), frame)
		svv(fp(o, a, n, uc - FAC_DOOR_HALF - 1, y, 1), frame)
		svv(fp(o, a, n, uc + FAC_DOOR_HALF + 1, y, 1), frame)
	for u in range(uc - FAC_DOOR_HALF - 1, uc + FAC_DOOR_HALF + 2):
		svv(fp(o, a, n, u, FAC_DOOR_TOP + 1, 0), frame)
		svv(fp(o, a, n, u, FAC_DOOR_TOP + 1, 1), frame)
	for du in [-FAC_DOOR_HALF - 3, FAC_DOOR_HALF + 3]:
		svv(fp(o, a, n, uc + du, 10, 1), P.BRASS)
		svv(fp(o, a, n, uc + du, 11, 1), P.IRON)
		svv(fp(o, a, n, uc + du, 12, 1), P.GLOW)
		svv(fp(o, a, n, uc + du, 13, 1), P.IRON)
	var c := fp(o, a, n, uc, 0, 0)
	var nn := Vector3(n)
	var at := Vector3(c.x, 0, c.z)
	_fac_light(c.x + nn.x * 6, c.y + 9, c.z + nn.z * 6, Color(1.0, 0.72, 0.42), 0.35, 3.5)
	return [_mp(at.x + nn.x * 10, 0, at.z + nn.z * 10), _mp(at.x - nn.x * 8, 0, at.z - nn.z * 8)]


## A sign board over the door: coloured blocks with a border, and the name in letters
## that face the street (so you can read it from across the way).
func _fac_sign(side: Array, uc: int, y: int, half: int, board: int, edge: int, text: String) -> void:
	var o: Vector3i = side[0]
	var a: Vector3i = side[1]
	var n: Vector3i = side[2]
	for u in range(uc - half, uc + half + 1):
		for yy in range(y, y + 5):
			var rim := absi(u - uc) == half or yy == y or yy == y + 4
			svv(fp(o, a, n, u, yy, 1), edge if rim else board)
	var c := fp(o, a, n, uc, y + 2, 2)
	fac_signs.append([Vector3(c.x, c.y, c.z) * VS + Vector3(n) * 0.02, Vector3(n), text])


## Windows (from the house template) along one wall, skipping the doorway.
func _fac_windows(side: Array, y0: int, every: int, skip_from: int, skip_to: int, shutter: int, flowers := false) -> void:
	var L: int = side[3]
	var k := 5
	while k + 3 <= L - 5:
		if k + 3 < skip_from or k > skip_to:
			_window(side[0], side[1], side[2], k, y0, shutter, flowers)
		k += every


## A sign hanging out over the street on an iron arm, with a picture that shows the
## trade (so you can tell what a place is while walking along, before you can read it).
## icon: 7 rows of 7 characters; "." is the board, letters pick from colours.
func _fac_hanging_sign(side: Array, u: int, board: int, icon: Array, colours: Dictionary) -> void:
	var o: Vector3i = side[0]
	var a: Vector3i = side[1]
	var n: Vector3i = side[2]
	for out in range(1, 10):
		svv(fp(o, a, n, u, 19, out), P.IRON)
	for out in [2, 8]:
		svv(fp(o, a, n, u, 18, out), P.IRON)
	for yy in range(10, 18):
		for out in range(1, 10):
			var rim := yy == 10 or yy == 17 or out == 1 or out == 9
			svv(fp(o, a, n, u, yy, out), P.WOOD_DARK if rim else board)
	for row in 6:
		var line: String = icon[row]
		for col in 7:
			var ch := line[col]
			if ch != ".":
				svv(fp(o, a, n, u, 16 - row, 2 + col), colours[ch])


## Windows seen from inside glow warm, like lit glass, instead of dark holes.
func _fac_glow_windows(x0: int, z0: int, x1: int, z1: int, top: int) -> void:
	for y in range(1, top):
		for x in range(x0 + 1, x1):
			for z in [z0 + 1, z1 - 1]:
				if gv(x, y, z) == P.GLASS:
					sv(x, y, z, P.WIN_GLOW)
		for z in range(z0 + 1, z1):
			for x in [x0 + 1, x1 - 1]:
				if gv(x, y, z) == P.GLASS:
					sv(x, y, z, P.WIN_GLOW)


## A barrel (3x3, 5 high) with iron hoops.
func _fac_barrel(x: int, z: int) -> void:
	for y in range(1, 6):
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if absi(dx) + absi(dz) < 2 or y in [2, 4]:
					sv(x + dx, y, z + dz, P.IRON if y == 2 or y == 4 else P.WOOD)


func _fac_light(x: float, y: float, z: float, col := Color(1.0, 0.72, 0.42), energy := 1.6, rng_m := 9.0) -> void:
	fac_lights.append([Vector3(x, y, z) * VS, col, energy, rng_m])


## A lantern hanging from the ceiling on a chain, with a real light.
func _fac_lantern(x: int, z: int, top: int, low: int) -> void:
	for y in range(low + 2, top):
		sv(x, y, z, P.IRON)
	sv(x, low + 1, z, P.BRASS)          # a slim brass lantern round a flame
	box3(x, low - 1, z, x, low, z, P.GLOW)
	sv(x, low - 2, z, P.BRASS)
	_fac_light(x, low - 1, z)


## A stool (2 blocks high) that you can sit on. face: the way a sitter looks.
## (You get up again where you stood when you sat down.)
func _fac_stool(x: int, z: int, face: Vector3, where: String, label := "sit down", p := P.WOOD_DARK) -> void:
	box3(x, 1, z, x, 2, z, p)
	interact_spots.append({"id": "%s_seat_%d_%d" % [where, x, z], "kind": "sit", "pos": _mp(x, 2, z),
			"label": label, "face": face, "where": where})


func _fac_record(kind: String, name: String, r: Rect2i, door: Array, level: int) -> void:
	var inward: Vector3 = door[1] - door[0]
	inward.y = 0.0
	facilities[kind] = {"name": name, "rect": r, "door_out": door[0], "door_in": door[1],
			"inside": door[1] + inward.normalized() * 1.2, "level": level}


func _remove_spot(id: String) -> void:
	for i in range(interact_spots.size() - 1, -1, -1):
		if interact_spots[i]["id"] == id:
			interact_spots.remove_at(i)


func _planks_z(_x: int, z: int) -> int:
	return P.WOOD if posmod(z, 3) != 0 else P.WOOD_DARK


func _planks_x(x: int, _z: int) -> int:
	return P.WOOD if posmod(x, 3) != 0 else P.WOOD_DARK


## Lights, signs and steam: real nodes on the city, added once the blocks are built.
func _add_facility_nodes() -> void:
	for l in fac_lights:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = l[2]
		o.omni_range = l[3]
		o.omni_attenuation = 1.4
		city.add_child(o)
	for s in fac_signs:
		var lb := Label3D.new()
		lb.text = s[2]
		lb.font_size = 64
		lb.outline_size = 10
		lb.pixel_size = 0.0035
		lb.modulate = Color(1.0, 0.95, 0.82)
		lb.outline_modulate = Color(0.12, 0.08, 0.05)
		lb.position = s[0]
		var out: Vector3 = s[1]
		lb.rotation.y = atan2(out.x, out.z)
		city.add_child(lb)
	for f in fac_particles:
		var p := CPUParticles3D.new()
		p.local_coords = true   # the steam moves with the walking city, not left behind
		p.position = f[0]
		var box := BoxMesh.new()
		box.size = Vector3.ONE * (0.07 if f[1] == "fountain" else 0.14)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 1, 1, 0.13) if f[1] != "fountain" else Color(0.6, 0.85, 1.0, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = m
		p.mesh = box
		p.direction = Vector3.UP
		p.spread = 20.0
		p.gravity = Vector3(0, 0.15, 0)
		p.initial_velocity_min = 0.15
		p.initial_velocity_max = 0.4
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
		if f[1] == "steam_pool":
			p.amount = 36
			p.lifetime = 4.0
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(3.0, 0.1, 1.8)
		elif f[1] == "fountain":
			p.amount = 30
			p.lifetime = 0.8
			p.spread = 25.0
			p.gravity = Vector3(0, -6.0, 0)
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 1.8
		else:
			p.amount = 16
			p.lifetime = 4.0
			p.initial_velocity_max = 0.8
		p.preprocess = 4.0
		city.add_child(p)


## Which building a point (metres, on the city) is inside, or "".
func facility_at(p: Vector3) -> String:
	var b := Vector2i(roundi(p.x / VS), roundi(p.z / VS))
	for k in facilities:
		var r: Rect2i = facilities[k]["rect"]
		if r.has_point(b) and absf(p.y - LEVELS[facilities[k]["level"]][1] * VS) < 3.0:
			return k
	return ""
