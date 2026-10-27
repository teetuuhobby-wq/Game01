extends "res://world/errand_sites.gd"
## THE WORLD, layer 6 of 10: the town's places with a purpose, the ones you can walk into.
## The adventurers' guild, the tavern, the general store and the bathhouse (outer ring,
## round the foot of the stairs on the homes side), plus the inside of Bram's workshop.
## Each has a sign, an open doorway, a furnished, lamplit inside and things to use.
## This layer only builds them and notes where things are:
##   facilities    - each building's outline, its door and a point inside (for tests)
##   interact_spots - things you can use with E (boards, seats, the hearth...)
##   cast_spots    - where each named resident stands (town_data.gd says who they are)
##   extras        - unnamed regulars (sitting at tables, soaking in the pool)
##   fac_lights    - lamps inside, as real lights
## All numbers are blocks (5 per metre) unless they say metres.

const GUILD := Rect2i(-70, -165, 58, 50)     # stone hall, door on the street side (east)
const TAVERN := Rect2i(16, -160, 50, 42)     # timber-framed, door on the street side (west)
const STORE := Rect2i(-135, -150, 46, 36)    # door toward the city's middle
const BATH := Rect2i(80, -165, 60, 47)       # domed, door toward the city's middle
const FAC_DOOR_HALF := 3                     # doorways are 7 blocks (1.4 m) wide
const FAC_DOOR_TOP := 13                     # and 13 blocks (2.6 m) tall

var facilities := {}      # kind -> {"name", "rect", "door_out", "door_in", "inside", "level"}
var interact_spots := []  # {"id", "kind" (read/look/sit), "pos", "label", "face", "stand", "where"}
var cast_spots := {}      # cast id -> {"pos", "face", "loop" (points, metres), "where"}
var extras := []          # {"pos", "face", "pose" ("sit"/"soak"/"stand"), "where"}
var fac_lights := []      # [position (metres), colour, energy, range]
var fac_particles := []   # [position (metres), kind ("steam")]
var fac_signs := []       # [position (metres), outward direction, text]


func _build_facilities() -> void:
	for r: Rect2i in [GUILD, TAVERN, STORE, BATH]:
		_fac_reserve(r)
	_seed("guild")
	_build_guild()
	_seed("tavern")
	_build_tavern()
	_seed("store")
	_build_store()
	_seed("bath")
	_build_bath()
	_seed("workshop inside")
	_furnish_workshop()
	_seed("lookout")
	_build_lookout()
	_place_pip()


## Keeps houses and trees off a building and a 3 m apron in front of every side.
func _fac_reserve(r: Rect2i) -> void:
	for x in range(_cell(r.position.x) - 3, _cell(r.end.x) + 4):
		for z in range(_cell(r.position.y) - 3, _cell(r.end.y) + 4):
			occ[Vector2i(x, z)] = true


# ---------------------------------------------------------------- shared pieces

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
		svv(fp(o, a, n, uc + du, 11, 1), P.IRON)
		svv(fp(o, a, n, uc + du, 12, 1), P.GLOW)
		svv(fp(o, a, n, uc + du, 13, 1), P.IRON)
	var c := fp(o, a, n, uc, 0, 0)
	var nn := Vector3(n)
	var at := Vector3(c.x, 0, c.z)
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
func _fac_windows(side: Array, y0: int, every: int, skip_from: int, skip_to: int, shutter: int) -> void:
	var L: int = side[3]
	var k := 5
	while k + 3 <= L - 5:
		if k + 3 < skip_from or k > skip_to:
			_window(side[0], side[1], side[2], k, y0, shutter, false)
		k += every


func _fac_light(x: float, y: float, z: float, col := Color(1.0, 0.72, 0.42), energy := 1.6, rng_m := 9.0) -> void:
	fac_lights.append([Vector3(x, y, z) * VS, col, energy, rng_m])


## A lantern hanging from the ceiling on a chain, with a real light.
func _fac_lantern(x: int, z: int, top: int, low: int) -> void:
	for y in range(low + 2, top):
		sv(x, y, z, P.IRON)
	box3(x - 1, low + 1, z - 1, x + 1, low + 1, z + 1, P.IRON)    # a small iron cage round a flame
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		box3(x + d.x, low - 1, z + d.y, x + d.x, low, z + d.y, P.IRON)
	box3(x, low - 1, z, x, low, z, P.GLOW)
	box3(x - 1, low - 2, z - 1, x + 1, low - 2, z + 1, P.IRON)
	_fac_light(x, low - 1, z)


## A stool (2 blocks high) that you can sit on. face: the way a sitter looks.
## stand_front: you get up in front of the seat (benches against a wall), not behind it.
func _fac_stool(x: int, z: int, face: Vector3, where: String, label := "sit down", p := P.WOOD_DARK, stand_front := false) -> void:
	box3(x, 1, z, x, 2, z, p)
	var stand := _mp(x, 0, z) + face * (0.6 if stand_front else -0.6)
	interact_spots.append({"id": "%s_seat_%d_%d" % [where, x, z], "kind": "sit", "pos": _mp(x, 2, z),
			"label": label, "face": face, "stand": stand, "where": where})


func _fac_record(kind: String, name: String, r: Rect2i, door: Array, level: int) -> void:
	var inward: Vector3 = door[1] - door[0]
	inward.y = 0.0
	facilities[kind] = {"name": name, "rect": r, "door_out": door[0], "door_in": door[1],
			"inside": door[1] + inward.normalized() * 1.2, "level": level}


# ---------------------------------------------------------------- the guild hall

## A tall stone hall: banners down the front, battlements, the guild's flag on top.
## Inside: the clerk's counter at the far end under a mounted beetle horn, the request
## board and the members' list on the side walls, two long tables with benches.
func _build_guild() -> void:
	var x0 := GUILD.position.x
	var z0 := GUILD.position.y
	var x1 := GUILD.end.x - 1
	var z1 := GUILD.end.y - 1
	var top := 32
	var zc := (z0 + z1) / 2
	_fac_walls(x0, z0, x1, z1, top, _guild_wall)
	_fac_floor(x0, z0, x1, z1, _guild_floor, top, P.WOOD_DARK)
	# Battlements and corner piers
	for x in range(x0 - 1, x1 + 2):
		for z in [z0 - 1, z1 + 1]:
			sv(x, top, z, P.STONE)
			if posmod(x, 4) < 2:
				box3(x, top + 1, z, x, top + 3, z, P.STONE)
	for z in range(z0, z1 + 1):
		for x in [x0 - 1, x1 + 1]:
			sv(x, top, z, P.STONE)
			if posmod(z, 4) < 2:
				box3(x, top + 1, z, x, top + 3, z, P.STONE)
	for cx in [x0, x1]:
		for cz in [z0, z1]:
			box3(cx - 1, 1, cz - 1, cx + 1, top + 5, cz + 1, P.STONE)
	# The guild flag on a pole
	box3(x0 + 6, top + 1, z0 + 6, x0 + 6, top + 22, z0 + 6, P.IRON)
	for fx in range(1, 11):
		for fy in range(0, 6):
			sv(x0 + 6 + fx, top + 21 - fy, z0 + 6, P.AWN2 if fy == 2 or fy == 3 else P.GOLD)
	var sides := _sides(x0, z0, x1, z1)
	var front: Array = sides[3]                  # the east wall, facing the street
	var uc: int = front[3] / 2
	var door := _fac_doorway(front, uc, P.STONE)
	_fac_sign(front, uc, 16, 9, P.AWN2, P.GOLD, "ADVENTURERS' GUILD")
	# Long blue-and-gold banners down the front
	for du in [-14, 14]:
		for yy in range(8, 29):
			for w in range(-2, 3):
				var p := P.AWN2 if absi(w) < 2 else P.GOLD
				if yy < 10 and absi(w) == 2:
					continue
				svv(fp(front[0], front[1], front[2], uc + du + w, yy, 1), p)
	for si in 4:
		var s: Array = sides[si]
		_fac_windows(s, 18, 9, uc - 18 if si == 3 else -1, uc + 18 if si == 3 else -1, P.SHUTTER0)
	_fac_beams(x0, z0, x1, z1, 26, 8, false)
	# The clerk's counter across the far (west) end
	box3(x0 + 8, 1, zc - 12, x0 + 10, 4, zc + 12, P.WOOD_DARK)
	box3(x0 + 8, 5, zc - 13, x0 + 11, 5, zc + 13, P.WOOD)
	box3(x0 + 9, 6, zc + 3, x0 + 10, 6, zc + 6, P.CLOTH1)   # a closed ledger
	box3(x0 + 9, 6, zc - 8, x0 + 10, 7, zc - 6, P.WHITE)    # a stack of forms
	sv(x0 + 9, 6, zc - 3, P.BRASS)                           # a bell for service
	# Shelves of ledgers behind the clerk
	for z in range(zc - 10, zc + 11):
		for y in [6, 11, 16]:
			sv(x0 + 1, y, z, P.WOOD)
			if posmod(z * 7 + y, 5) != 0:
				sv(x0 + 1, y + 1, z, [P.CLOTH1, P.AWN2, P.LEAF2, P.TERRA][posmod(z + y, 4)])
				sv(x0 + 1, y + 2, z, [P.CLOTH1, P.AWN2, P.LEAF2, P.TERRA][posmod(z + y + 1, 4)])
	# A dune beetle's horn over two crossed spears, high on the back wall
	for i in 14:
		var hz := zc - 7 + i
		var hy := 22 + int(4.0 * sin(PI * i / 13.0))
		box3(x0 + 1, hy, hz, x0 + 2, hy + 1, hz, P.WHITE if i > 2 else P.STONE)
	for i in 13:
		sv(x0 + 1, 19 + i, zc - 6 + i, P.WOOD_DARK)
		sv(x0 + 1, 19 + i, zc + 6 - i, P.WOOD_DARK)
	sv(x0 + 1, 31, zc + 6, P.IRON)
	sv(x0 + 1, 31, zc - 6, P.IRON)
	interact_spots.append({"id": "guild_trophy", "kind": "look", "pos": _mp(x0 + 13, 0, zc + 1),
			"label": "look at the horn on the wall", "where": "guild", "reach": 2.2})
	# The request board on the north wall, the members' list on the south wall
	var bx := x0 + 30
	box3(bx - 8, 6, z1 - 1, bx + 8, 15, z1 - 1, P.WOOD)
	for i in 9:
		var nx := bx - 6 + (i % 3) * 5
		var ny := 7 + (i / 3) * 3
		box3(nx, ny, z1 - 2, nx + 2, ny + 1, z1 - 2, P.WHITE if i % 4 != 1 else P.CLOTH0)
	interact_spots.append({"id": "guild_board", "kind": "read", "pos": _mp(bx, 0, z1 - 4),
			"label": "read the request board", "where": "guild"})
	box3(bx - 7, 6, z0 + 1, bx + 7, 16, z0 + 1, P.BRASS)
	box3(bx - 6, 7, z0 + 2, bx + 6, 15, z0 + 2, P.WOOD_DARK)
	for row in 4:
		box3(bx - 5, 8 + row * 2, z0 + 3, bx + 2 - row, 8 + row * 2, z0 + 3, P.GOLD)
	interact_spots.append({"id": "guild_ranks", "kind": "read", "pos": _mp(bx, 0, z0 + 4),
			"label": "read the members' list", "where": "guild"})
	# Two long tables with benches, either side of the middle aisle
	for side_z in [zc + 10, zc - 10]:
		var tz0: int = side_z - 2
		var tz1: int = side_z + 2
		box3(x0 + 20, 1, tz0, x0 + 20, 3, tz0, P.WOOD_DARK)
		box3(x0 + 20, 1, tz1, x0 + 20, 3, tz1, P.WOOD_DARK)
		box3(x1 - 14, 1, tz0, x1 - 14, 3, tz0, P.WOOD_DARK)
		box3(x1 - 14, 1, tz1, x1 - 14, 3, tz1, P.WOOD_DARK)
		box3(x0 + 19, 4, tz0 - 1, x1 - 13, 4, tz1 + 1, P.WOOD)
		var outer: int = 1 if side_z > zc else -1
		var bench_z: int = side_z + outer * 5
		box3(x0 + 19, 1, bench_z, x1 - 13, 2, bench_z, P.WOOD_DARK)
		for x in range(x0 + 20, x1 - 13, 4):
			_fac_stool(x, bench_z, Vector3(0, 0, -outer), "guild", "sit at the table")
		# Mugs and maps on the tables
		for x in range(x0 + 22, x1 - 15, 6):
			sv(x, 5, side_z, P.WOOD if posmod(x, 12) < 6 else P.WHITE)
	# Regulars at the tables
	for e in [[x0 + 24, zc + 15, -1], [x0 + 32, zc + 15, -1], [x0 + 28, zc - 15, 1], [x1 - 18, zc - 15, 1]]:
		extras.append({"pos": _mp(e[0], 0, e[1]), "face": Vector3(0, 0, e[2]), "pose": "sit", "where": "guild"})
		_remove_spot("guild_seat_%d_%d" % [e[0], e[1]])
	for lx in [x0 + 16, x0 + 32, x1 - 10]:
		_fac_lantern(lx, zc, top, 20)
	_fac_light(x0 + 6, 10, zc, Color(1.0, 0.75, 0.45), 1.2, 7.0)
	cast_spots["sabeth"] = {"pos": _mp(x0 + 5, 0, zc), "face": Vector3(1, 0, 0), "where": "guild",
			"talk_from": _mp(x0 + 13, 0, zc)}
	_fac_record("guild", "the Adventurers' Guild", GUILD, door, 0)


# ---------------------------------------------------------------- the tavern

## The Kneeling Strider: timber frame on cream plaster, a steep roof, a hanging sign.
## Inside: the bar along the back, barrels and bottles behind it, a big hearth, round
## tables with stools, regulars, warm low lamps.
func _build_tavern() -> void:
	var x0 := TAVERN.position.x
	var z0 := TAVERN.position.y
	var x1 := TAVERN.end.x - 1
	var z1 := TAVERN.end.y - 1
	var top := 26
	var zc := (z0 + z1) / 2
	_fac_walls(x0, z0, x1, z1, top, _tavern_wall.bind(x0, z0, x1, z1, top))
	_fac_floor(x0, z0, x1, z1, _planks_z, top - 1, P.WOOD_DARK)
	_gable_roof(x0, z0, x1, z1, top, false, P.WALL2)
	var sides := _sides(x0, z0, x1, z1)
	var front: Array = sides[2]                  # the west wall, facing the street
	var uc: int = front[3] / 2
	var door := _fac_doorway(front, uc, P.WOOD_DARK)
	_fac_sign(front, uc, 15, 8, P.WOOD, P.GOLD, "THE KNEELING STRIDER")
	# A hanging sign on an iron arm: a little walking city
	var o: Vector3i = front[0]
	var a: Vector3i = front[1]
	var n: Vector3i = front[2]
	for out in range(1, 6):
		svv(fp(o, a, n, uc - 12, 16, out), P.IRON)
	for out in range(2, 6):
		for yy in range(11, 16):
			svv(fp(o, a, n, uc - 12, yy, out), P.WOOD if yy == 11 or yy == 15 or out == 2 or out == 5 else P.AWN1)
	svv(fp(o, a, n, uc - 12, 13, 3), P.TERRA)
	svv(fp(o, a, n, uc - 12, 13, 4), P.TERRA)
	svv(fp(o, a, n, uc - 12, 12, 3), P.HULL)
	svv(fp(o, a, n, uc - 12, 12, 4), P.HULL)
	for si in 4:
		_fac_windows(sides[si], 5, 8, uc - 9 if si == 2 else -1, uc + 9 if si == 2 else -1, P.SHUTTER1)
	# A bench outside by the door
	for du in [-11, 7]:
		for k in 5:
			var b := fp(o, a, n, uc + du + k, 2, 3)
			sv(b.x, 2, b.z, P.WOOD)
			if k == 0 or k == 4:
				sv(b.x, 1, b.z, P.WOOD_DARK)
	_fac_beams(x0, z0, x1, z1, 18, 6, true)
	# The bar along the east wall, the barkeep behind it
	var bar_x := x1 - 9
	box3(bar_x, 1, zc - 11, bar_x + 1, 4, zc + 11, P.WOOD_DARK)
	box3(bar_x - 1, 5, zc - 12, bar_x + 1, 5, zc + 12, P.WOOD)
	for z in range(zc - 9, zc + 10, 3):
		sv(bar_x, 6, z, [P.GOLD, P.GLASS, P.WOOD, P.RED][posmod(z, 4)])
	# Barrels along the back wall, shelves of bottles above
	for z in range(zc - 12, zc + 13, 5):
		for y in range(1, 6):
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					sv(x1 - 2 + dx, y, z + dz, P.IRON if y == 2 or y == 4 else P.WOOD)
	for y in [9, 13]:
		box3(x1 - 1, y, zc - 12, x1 - 1, y, zc + 12, P.WOOD)
		for z in range(zc - 11, zc + 12, 2):
			box3(x1 - 1, y + 1, z, x1 - 1, y + 2, z, [P.LEAF2, P.GLASS, P.RED, P.GOLD][posmod(z + y, 4)])
	# The hearth on the north wall
	var hx := x0 + 18
	box3(hx - 6, 1, z1 - 3, hx + 6, 14, z1 - 1, P.STONE)
	box3(hx - 4, 1, z1 - 3, hx + 4, 7, z1 - 2, P.HULL)      # the firebox (dark)
	box3(hx - 3, 1, z1 - 3, hx + 3, 2, z1 - 3, P.GLOW)      # embers
	box3(hx - 2, 3, z1 - 3, hx + 2, 3, z1 - 3, P.WOOD_DARK) # a log on the fire
	box3(hx - 7, 15, z1 - 4, hx + 7, 15, z1 - 1, P.WOOD)    # mantel
	for i in 4:
		sv(hx - 5 + i * 3, 16, z1 - 2, [P.BRASS, P.TERRA, P.GOLD, P.BRASS][i])
	box3(hx - 2, 16, z1 - 2, hx + 2, top - 1, z1 - 1, P.STONE)
	_fac_light(hx, 4, z1 - 6, Color(1.0, 0.55, 0.25), 2.4, 8.0)
	interact_spots.append({"id": "tavern_hearth", "kind": "look", "pos": _mp(hx, 0, z1 - 7),
			"label": "warm your hands at the fire", "where": "tavern"})
	# Round tables with stools
	var tables := [Vector2i(x0 + 14, zc - 8), Vector2i(x0 + 26, zc - 12), Vector2i(x0 + 26, zc + 6), Vector2i(x0 + 14, zc + 10)]
	for t: Vector2i in tables:
		sv(t.x, 1, t.y, P.WOOD_DARK)
		box3(t.x, 2, t.y, t.x, 3, t.y, P.WOOD_DARK)
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if dx * dx + dz * dz <= 5:
					sv(t.x + dx, 4, t.y + dz, P.WOOD)
		sv(t.x, 5, t.y, P.WHITE)       # a candle
		sv(t.x, 6, t.y, P.GLOW)
		for d: Vector2i in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
			_fac_stool(t.x + d.x, t.y + d.y, -Vector3(d.x, 0, d.y).normalized(), "tavern", "sit at the table")
	# Stools along the bar
	for z in range(zc - 9, zc + 10, 4):
		_fac_stool(bar_x - 4, z, Vector3(1, 0, 0), "tavern", "sit at the bar")
	# Regulars: three at tables, one at the bar
	for e in [[x0 + 18, zc - 8, Vector3(-1, 0, 0)], [x0 + 26, zc + 2, Vector3(0, 0, 1)],
			[x0 + 10, zc + 10, Vector3(1, 0, 0)], [bar_x - 4, zc + 3, Vector3(1, 0, 0)]]:
		extras.append({"pos": _mp(e[0], 0, e[1]), "face": e[2], "pose": "sit", "where": "tavern"})
		_remove_spot("tavern_seat_%d_%d" % [e[0], e[1]])
	for l: Vector2i in [Vector2i(x0 + 14, zc), Vector2i(x0 + 28, zc - 4), Vector2i(bar_x - 6, zc)]:
		_fac_lantern(l.x, l.y, top - 1, 14)
	cast_spots["dorran"] = {"pos": _mp(bar_x + 3, 0, zc), "face": Vector3(-1, 0, 0), "where": "tavern",
			"talk_from": _mp(bar_x - 3, 0, zc - 2)}
	_fac_record("tavern", "the Kneeling Strider", TAVERN, door, 0)


# ---------------------------------------------------------------- the general store

## Pell's Provisions: white plaster, a striped awning, crates and sacks outside.
## Inside: a counter, tall shelves of goods down both sides, sacks, a rug.
func _build_store() -> void:
	var x0 := STORE.position.x
	var z0 := STORE.position.y
	var x1 := STORE.end.x - 1
	var z1 := STORE.end.y - 1
	var top := 18
	var xc := (x0 + x1) / 2
	_fac_walls(x0, z0, x1, z1, top, _store_wall)
	_fac_floor(x0, z0, x1, z1, _planks_x, top, P.WOOD)
	_hip_roof(x0, z0, x1, z1, top)
	var sides := _sides(x0, z0, x1, z1)
	var front: Array = sides[1]                  # the +z wall, toward the city's middle
	var uc: int = front[3] / 2
	var door := _fac_doorway(front, uc, P.WOOD_DARK)
	_fac_sign(front, uc, 15, 8, P.AWN2, P.WHITE, "PELL'S PROVISIONS")
	# A striped awning over the front (above head height)
	var o: Vector3i = front[0]
	var a: Vector3i = front[1]
	var n: Vector3i = front[2]
	for u in range(2, front[3] - 2):
		for out in range(1, 6):
			if absi(u - uc) <= 9 and out < 2:
				continue
			svv(fp(o, a, n, u, 14 - out / 2, out), P.AWN2 if posmod(u / 3, 2) == 0 else P.WHITE)
	# Crates and sacks outside, beside the door
	for du in [-14, -11, 11, 14]:
		var c := fp(o, a, n, uc + du, 0, 3)
		box3(c.x - 1, 1, c.z - 1, c.x + 1, 3, c.z + 1, P.WOOD if du < 0 else P.CLOTH0)
	for si in 4:
		_fac_windows(sides[si], 5, 9, uc - 10 if si == 1 else -1, uc + 10 if si == 1 else -1, P.SHUTTER0)
	# The counter, across the room facing the door
	box3(xc - 12, 1, z0 + 9, xc + 12, 4, z0 + 10, P.WOOD_DARK)
	box3(xc - 13, 5, z0 + 8, xc + 13, 5, z0 + 11, P.WOOD)
	box3(xc + 6, 6, z0 + 9, xc + 7, 7, z0 + 10, P.BRASS)      # scales
	box3(xc - 8, 6, z0 + 9, xc - 6, 6, z0 + 10, P.AWN1)       # a dish of figs
	# Tall shelves down both side walls and along the back, full of goods
	for sx in [x0 + 1, x1 - 3]:
		for y in [1, 5, 9, 13]:
			box3(sx, y, z0 + 2, sx + 2, y, z1 - 4, P.WOOD)
			for z in range(z0 + 3, z1 - 4):
				if y < 13 and posmod(z * 3 + y, 4) != 0:
					var good: int = [P.TERRA, P.BRASS, P.CLOTH2, P.LEAF2, P.AWN1, P.GLASS, P.RED][posmod(z + y * 2, 7)]
					box3(sx + 1, y + 1, z, sx + 1, y + 2, z, good)
	for y in [6, 11]:
		box3(xc - 14, y, z0 + 1, xc + 14, y, z0 + 2, P.WOOD)
		for x in range(xc - 13, xc + 14, 2):
			sv(x, y + 1, z0 + 1, [P.GLOW, P.BRASS, P.IRON][posmod(x, 3)])   # lanterns for sale
	sv(xc, 13, z0 + 1, P.GOLD)   # the lucky compass, not for sale
	# Sacks of grain in a corner, a rug in front of the counter
	for i in 5:
		var sx2 := x0 + 6 + (i % 3) * 3
		var sz2 := z1 - 6 - (i / 3) * 3
		box3(sx2, 1, sz2, sx2 + 1, 2 + i % 2, sz2 + 1, P.CLOTH0)
	for x in range(xc - 8, xc + 9):
		for z in range(z0 + 13, z0 + 22):
			sv(x, 0, z, P.RED if (x + z) % 4 != 0 else P.AWN1)
	interact_spots.append({"id": "store_shelves", "kind": "look", "pos": _mp(x0 + 7, 0, (z0 + z1) / 2),
			"label": "look over the shelves", "where": "store"})
	for l: Vector2i in [Vector2i(xc, z0 + 18), Vector2i(xc - 10, z1 - 8), Vector2i(xc + 10, z1 - 8)]:
		_fac_lantern(l.x, l.y, top, 13)
	cast_spots["pell"] = {"pos": _mp(xc, 0, z0 + 5), "face": Vector3(0, 0, 1), "where": "store",
			"loop": [_mp(xc - 4, 0, z0 + 5), _mp(xc + 4, 0, z0 + 5)], "talk_from": _mp(xc, 0, z0 + 14)}
	_fac_record("store", "Pell's Provisions", STORE, door, 0)


# ---------------------------------------------------------------- the bathhouse

## A white bathhouse with a blue tiled band and a dome. Inside: a big warm pool you can
## wade into and sit in, steam, columns, benches, towels, plants.
func _build_bath() -> void:
	var x0 := BATH.position.x
	var z0 := BATH.position.y
	var x1 := BATH.end.x - 1
	var z1 := BATH.end.y - 1
	var top := 22
	var xc := (x0 + x1) / 2
	var zc := (z0 + z1) / 2
	_fac_walls(x0, z0, x1, z1, top, _bath_wall)
	_fac_floor(x0, z0, x1, z1, _bath_floor, top, P.WALL0)
	# The dome, with a gold finial and a steam vent
	var rx := (x1 - x0) / 2.0 + 1.0
	var rz := (z1 - z0) / 2.0 + 1.0
	for x in range(x0 - 1, x1 + 2):
		for z in range(z0 - 1, z1 + 2):
			var dx := (x - xc) / rx
			var dz := (z - zc) / rz
			var d := dx * dx + dz * dz
			if d > 1.0:
				continue
			var h := int(sqrt(1.0 - d) * 14.0)
			for y in range(top + 1, top + 1 + h):
				var dd := sqrt(d + pow((y - top) / 14.0, 2))
				if dd > 0.82:
					sv(x, y, z, P.WALL0 if posmod(y, 4) != 0 else P.WALL4)
	box3(xc, top + 15, zc, xc, top + 19, zc, P.GOLD)
	fac_particles.append([Vector3(xc, top + 15, zc) * VS, "steam_vent"])
	var sides := _sides(x0, z0, x1, z1)
	var front: Array = sides[1]
	var uc: int = front[3] / 2
	var door := _fac_doorway(front, uc, P.WALL4)
	_fac_sign(front, uc, 15, 7, P.WALL4, P.WHITE, "BATHHOUSE")
	for si in 4:
		_fac_windows(sides[si], 6, 10, uc - 10 if si == 1 else -1, uc + 10 if si == 1 else -1, P.SHUTTER1)
	# The pool: tiled floor, a low rim with two ways in, water you can wade through
	var px0 := x0 + 12
	var px1 := x1 - 12
	var pz0 := z0 + 9
	var pz1 := z1 - 13
	for x in range(px0, px1 + 1):
		for z in range(pz0, pz1 + 1):
			var rim := x == px0 or x == px1 or z == pz0 or z == pz1
			var gap := (x >= xc - 3 and x <= xc + 3) and (z == pz1 or z == pz0)
			sv(x, 0, z, P.WALL4 if posmod(x / 2 + z / 2, 2) == 0 else P.SHUTTER0)
			if rim and not gap:
				sv(x, 1, z, P.WHITE)
				sv(x, 2, z, P.WHITE)
			else:
				sv(x, 1, z, P.WATER)
				soft[Vector3i(x, 1, z) + origin] = true
	# Seats on a ledge inside the pool (you sit in the water)
	for x in range(px0 + 4, px1 - 3, 6):
		for z in [pz0 + 2, pz1 - 2]:
			var face := Vector3(0, 0, 1) if z < zc else Vector3(0, 0, -1)
			interact_spots.append({"id": "bath_seat_%d_%d" % [x, z], "kind": "sit", "pos": _mp(x, 0, z),
					"label": "sit in the warm water", "face": face, "stand": _mp(x, 0, z) + face * 0.6,
					"where": "bath", "soak": true})
	for e in [[px0 + 10, pz0 + 2, Vector3(0, 0, 1)], [px1 - 8, pz1 - 2, Vector3(0, 0, -1)]]:
		extras.append({"pos": _mp(e[0], 0, e[1]), "face": e[2], "pose": "soak", "where": "bath"})
		_remove_spot("bath_seat_%d_%d" % [e[0], e[1]])
	fac_particles.append([_mp(xc, 2, zc), "steam_pool"])
	interact_spots.append({"id": "bath_steam", "kind": "look", "pos": _mp(xc, 0, pz1 + 4),
			"label": "breathe in the steam", "where": "bath"})
	# Columns on the pool's corners (on the rim, out of the way), benches along the
	# walls, towels, plants
	for cx in [px0, px1]:
		for cz in [pz0, pz1]:
			box3(cx - 1, 1, cz - 1, cx + 1, top - 1, cz + 1, P.WALL0)
			box3(cx - 2, top - 2, cz - 2, cx + 2, top - 1, cz + 2, P.STONE)
	for z in range(z0 + 6, z1 - 5, 6):
		for bx in [x0 + 2, x1 - 2]:
			var face := Vector3(1, 0, 0) if bx < xc else Vector3(-1, 0, 0)
			_fac_stool(bx, z, face, "bath", "sit on the bench", P.WOOD, true)
			box3(bx, 1, z - 1, bx, 2, z + 1, P.WOOD)
	for x in range(x0 + 8, x1 - 7, 10):
		box3(x, 1, z0 + 1, x + 3, 6, z0 + 2, P.WOOD)
		for y in [3, 5]:
			box3(x, y, z0 + 1, x + 3, y, z0 + 1, [P.WHITE, P.WALL4][posmod(x + y, 2)])
	for pl in [Vector2i(x0 + 3, z1 - 3), Vector2i(x1 - 3, z1 - 3), Vector2i(x0 + 3, z0 + 3), Vector2i(x1 - 3, z0 + 3)]:
		box3(pl.x - 1, 1, pl.y - 1, pl.x + 1, 2, pl.y + 1, P.TERRA)
		box3(pl.x - 2, 3, pl.y - 2, pl.x + 2, 6, pl.y + 2, P.LEAF)
	for l: Vector2i in [Vector2i(xc - 12, zc), Vector2i(xc + 12, zc), Vector2i(xc, z1 - 6)]:
		_fac_lantern(l.x, l.y, top, 15)
	var loop := [_mp(px0 - 5, 0, pz1 + 4), _mp(px1 + 5, 0, pz1 + 4), _mp(px1 + 5, 0, pz0 - 4), _mp(px0 - 5, 0, pz0 - 4)]
	cast_spots["tamsin"] = {"pos": loop[0], "face": Vector3(1, 0, 0), "where": "bath", "loop": loop}
	_fac_record("bath", "the Bathhouse", BATH, door, 0)


# ---------------------------------------------------------------- Bram's workshop

## The workshop already exists (errand_sites.gd); this adds Bram, a forge glow,
## shelves of parts and the workbench you can use.
func _furnish_workshop() -> void:
	var x0 := WORKSHOP.position.x
	var z0 := WORKSHOP.position.y
	var x1 := WORKSHOP.end.x - 1
	var z1 := WORKSHOP.end.y - 1
	var cx := (x0 + x1) / 2
	var h: int = LEVELS[level_at(cx, (z0 + z1) / 2)][1]
	origin = Vector3i(0, h, 0)
	# A small forge in the corner, glowing
	box3(x0 + 1, 1, z0 + 2, x0 + 4, 4, z0 + 5, P.STONE)
	box3(x0 + 2, 5, z0 + 3, x0 + 3, 5, z0 + 4, P.GLOW)
	box3(x0 + 2, 6, z0 + 3, x0 + 2, 13, z0 + 3, P.IRON)
	# Gears and pipes on the side wall
	for i in 3:
		var gz := z0 + 3 + i * 4
		for d in range(-1, 2):
			sv(x1 - 1, 8 + d, gz, P.BRASS)
			sv(x1 - 1, 8, gz + d, P.BRASS)
	box3(x1 - 1, 11, z0 + 1, x1 - 1, 11, z1 - 1, P.IRON)
	origin = Vector3i.ZERO
	_fac_light(x0 + 3, h + 6, z0 + 4, Color(1.0, 0.5, 0.2), 1.6, 5.0)
	_fac_light(cx, h + 11, z1 - 4, Color(1.0, 0.75, 0.45), 1.2, 6.0)
	interact_spots.append({"id": "workshop_bench", "kind": "look", "pos": _mp(x0 + 5, h, z1 - 8),
			"label": "tinker at the workbench", "where": "workshop"})
	cast_spots["bram"] = {"pos": _mp(x1 - 4, h, z1 - 7), "face": Vector3(-1, 0, 0), "where": "workshop"}
	facilities["workshop"] = {"name": "Bram's workshop", "rect": WORKSHOP, "door_out": _mp(cx, h, z0 - 2),
			"door_in": _mp(cx, h, z0 + 4), "inside": _mp(cx, h, z1 - 9), "level": level_at(cx, z1 - 9)}


# ---------------------------------------------------------------- the lookout and Pip

## A small timber lookout platform against the outer wall, beyond the bathhouse,
## where Old Wendel keeps watch. You talk to him from the foot of it.
func _build_lookout() -> void:
	var lx := 40
	var lz := -197
	for d: Vector2i in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)]:
		box3(lx + d.x, 1, lz + d.y, lx + d.x, 11, lz + d.y, P.WOOD_DARK)
	box3(lx - 4, 12, lz - 4, lx + 4, 12, lz + 4, P.WOOD)
	for x in range(lx - 4, lx + 5):
		for z in [lz - 4, lz + 4]:
			if posmod(x, 2) == 0:
				box3(x, 13, z, x, 15, z, P.WOOD_DARK)
	for z in range(lz - 4, lz + 5):
		if posmod(z, 2) == 0:
			box3(lx - 4, 13, z, lx - 4, 15, z, P.WOOD_DARK)
	for y in range(1, 12):   # a ladder up the side
		if posmod(y, 2) == 0:
			box3(lx + 4, y, lz + 1, lx + 4, y, lz + 2, P.WOOD)
	for x in range(lx - 3, lx + 4):
		for z in range(lz - 3, lz + 4):
			occ[Vector2i(_cell(x), _cell(z))] = true
	cast_spots["wendel"] = {"pos": _mp(lx, 12, lz), "face": Vector3(0, 0, -1), "where": "lookout",
			"talk_from": _mp(lx, 0, lz + 7)}


## Pip runs back and forth along the street between the guild and the tavern doors.
func _place_pip() -> void:
	var g: Dictionary = facilities["guild"]
	var t: Dictionary = facilities["tavern"]
	var a: Vector3 = g["door_out"] + Vector3(0.6, 0, 0.0)
	var b: Vector3 = t["door_out"] + Vector3(-0.6, 0, 0.0)
	cast_spots["pip"] = {"pos": a, "face": Vector3(1, 0, 0), "where": "south_street",
			"loop": [a, a.lerp(b, 0.5) + Vector3(0, 0, -1.0), b, a.lerp(b, 0.5) + Vector3(0, 0, -3.0)]}


func _remove_spot(id: String) -> void:
	for i in range(interact_spots.size() - 1, -1, -1):
		if interact_spots[i]["id"] == id:
			interact_spots.remove_at(i)


func _guild_wall(x: int, y: int, z: int) -> int:
	return P.STONE2 if y <= 3 else _stone(x, y, z)


func _guild_floor(x: int, z: int) -> int:
	return P.PLAZA if posmod(x / 4 + z / 4, 2) == 0 else P.PAVE2


## Timber frame: dark posts and beams on cream plaster, braces on the upper floor.
func _tavern_wall(x: int, y: int, z: int, x0: int, z0: int, x1: int, z1: int, top: int) -> int:
	if y <= 3:
		return P.STONE2
	var on_corner := (x == x0 or x == x1) and (z == z0 or z == z1)
	if on_corner or posmod(x + z, 8) == 0 or y == 14 or y == top:
		return P.WOOD_DARK
	if y > 14 and posmod(x + z + y, 8) == 0:
		return P.WOOD_DARK
	return P.WALL2


func _store_wall(_x: int, y: int, _z: int) -> int:
	return P.STONE2 if y <= 3 else P.WALL1


func _bath_wall(x: int, y: int, z: int) -> int:
	if y <= 3:
		return P.STONE2
	if y >= 16 and y <= 18:
		return P.WALL4 if posmod(x + z, 2) == 0 else P.SHUTTER0
	return P.WALL0


func _bath_floor(x: int, z: int) -> int:
	return P.WHITE if posmod(x + z, 2) == 0 else P.WALL4


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
		box.size = Vector3.ONE * 0.25
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 1, 1, 0.22)
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
			p.amount = 50
			p.lifetime = 5.0
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(3.0, 0.1, 1.8)
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
