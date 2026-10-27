extends "res://world/outer_places.gd"
## THE WORLD, layer 8 of 13: the town's places with a purpose, the ones you can walk into.
## The adventurers' guild, the tavern, the general store and the bathhouse (outer ring,
## round the foot of the stairs on the homes side), plus the inside of Bram's workshop.
## Each has a sign, an open doorway, a furnished, lamplit inside and things to use.
## Built from the pieces in facility_kit.gd, which also holds the lists of where
## things and people are. All numbers are blocks (5 per metre) unless they say metres.

const GUILD := Rect2i(-70, -165, 58, 50)     # stone hall, door on the street side (east)
const TAVERN := Rect2i(16, -160, 50, 42)     # timber-framed, door on the street side (west)
const STORE := Rect2i(-135, -150, 46, 36)    # door toward the city's middle
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
	# A pale stone roof, and a little tower with a tiled roof and the guild's flag
	box3(x0, top + 1, z0, x1, top + 1, z1, P.PAVE)
	var wx0 := x0 + 4
	var wz0 := z1 - 16
	var wx1 := x0 + 17
	var wz1 := z1 - 3
	for y in range(top + 2, top + 15):
		for x in range(wx0, wx1 + 1):
			for z in [wz0, wz1]:
				sv(x, y, z, P.WALL2 if posmod(y, 4) != 0 else P.STONE)
		for z in range(wz0, wz1 + 1):
			for x in [wx0, wx1]:
				sv(x, y, z, P.WALL2 if posmod(y, 4) != 0 else P.STONE)
	for k in [wx0 + 5, wx0 + 8]:
		box3(k, top + 8, wz1, k + 1, top + 11, wz1, P.WIN_GLOW)
		box3(wx1, top + 8, k + (wz0 - wx0), wx1, top + 11, k + 1 + (wz0 - wx0), P.WIN_GLOW)
	_hip_roof(wx0, wz0, wx1, wz1, top + 14)
	var px := (wx0 + wx1) / 2
	var pz := (wz0 + wz1) / 2
	box3(px, top + 20, pz, px, top + 44, pz, P.IRON)
	for fx in range(1, 21):
		for fy in range(0, 11):
			sv(px + fx, top + 43 - fy, pz, P.AWN2 if fy >= 3 and fy <= 7 else P.GOLD)
	var sides := _sides(x0, z0, x1, z1)
	var front: Array = sides[3]                  # the east wall, facing the street
	var uc: int = front[3] / 2
	var door := _fac_doorway(front, uc, P.STONE)
	_fac_sign(front, uc, 16, 9, P.AWN2, P.GOLD, "ADVENTURERS' GUILD")
	_fac_hanging_sign(front, uc + 20, P.AWN2, [
		"s.....s",
		".s...s.",
		"..s.s..",
		"...s...",
		"..g.g..",
		".g...g.",
	], {"s": P.WHITE, "g": P.GOLD})
	# A notice board and a rack of spears outside, beside the door
	var fo: Vector3i = front[0]
	var fa: Vector3i = front[1]
	var fn: Vector3i = front[2]
	for k in [-13, -8]:
		for yy in range(1, 11):
			svv(fp(fo, fa, fn, uc + k, yy, 2), P.WOOD_DARK)
	for k in range(-13, -7):
		for yy in range(6, 11):
			svv(fp(fo, fa, fn, uc + k, yy, 2), P.WOOD)
	for k in [-12, -10]:
		svv(fp(fo, fa, fn, uc + k, 8, 3), P.WHITE)
		svv(fp(fo, fa, fn, uc + k + 1, 9, 3), P.CLOTH0)
	for k in range(8, 13, 2):
		for yy in range(1, 12):
			svv(fp(fo, fa, fn, uc + k, yy, 1), P.WOOD_DARK if yy < 11 else P.IRON)
	for k in range(8, 13):
		svv(fp(fo, fa, fn, uc + k, 4, 1), P.WOOD)
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
	_fac_glow_windows(x0, z0, x1, z1, top)
	_fac_beams(x0, z0, x1, z1, 26, 8, false)
	# A red runner with gold edges down the middle aisle
	for x in range(x0 + 12, x1 - 1):
		for z in range(zc - 2, zc + 3):
			sv(x, 0, z, P.GOLD if absi(z - zc) == 2 else P.CLOTH1)
	# Maps and notes pinned to the side walls, near the door
	for wz in [z1 - 1, z0 + 1]:
		box3(x1 - 14, 7, wz, x1 - 6, 13, wz, P.WALL2)
		for i in 5:
			sv(x1 - 13 + i * 2, 9 + posmod(i, 2) * 2, wz, P.AWN2 if i % 2 == 0 else P.TERRA)
		box3(x1 - 12, 8, wz, x1 - 8, 8, wz, P.WOOD_DARK)
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
	interact_spots.append({"id": "guild_trophy", "kind": "look", "pos": _mp(x0 + 22, 0, zc),
			"label": "look at the horn on the wall", "where": "guild", "reach": 2.6})
	# The request board on the north wall, the members' list on the south wall
	var bx := x0 + 30
	box3(bx - 8, 6, z1 - 1, bx + 8, 15, z1 - 1, P.WOOD)
	for i in 9:
		var nx := bx - 6 + (i % 3) * 5
		var ny := 7 + (i / 3) * 3
		box3(nx, ny, z1 - 2, nx + 2, ny + 1, z1 - 2, P.WHITE if i % 4 != 1 else P.CLOTH0)
	interact_spots.append({"id": "guild_board", "kind": "read", "pos": _mp(bx, 0, z1 - 6),
			"label": "read the request board", "where": "guild"})
	box3(bx - 7, 6, z0 + 1, bx + 7, 16, z0 + 1, P.BRASS)
	box3(bx - 6, 7, z0 + 2, bx + 6, 15, z0 + 2, P.WOOD_DARK)
	for row in 4:
		box3(bx - 5, 8 + row * 2, z0 + 3, bx + 2 - row, 8 + row * 2, z0 + 3, P.GOLD)
	interact_spots.append({"id": "guild_ranks", "kind": "read", "pos": _mp(bx, 0, z0 + 4),
			"label": "read the guild notices", "where": "guild"})
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
		# Mugs, plates, scrolls and the odd helmet on the tables
		for x in range(x0 + 21, x1 - 14, 3):
			var k := posmod(x * 7 + side_z, 5)
			if k == 0:
				box3(x, 5, side_z - 1, x, 6, side_z - 1, P.WOOD)
			elif k == 1:
				sv(x, 5, side_z + 1, P.STONE)
			elif k == 2:
				box3(x, 5, side_z, x + 1, 5, side_z, P.WHITE)
			elif k == 3:
				box3(x, 5, side_z - 1, x, 6, side_z, P.STONE2)     # a helmet
			else:
				box3(x, 5, side_z, x + 1, 6, side_z + 1, P.TERRA3)  # a leather pack
	# Regulars at the tables, each exactly on a stool (every 4 blocks from x0 + 20), so that seat is taken
	for e in [[x0 + 24, zc + 15, -1], [x0 + 32, zc + 15, -1], [x0 + 28, zc - 15, 1], [x0 + 40, zc - 15, 1]]:
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
	_fac_hanging_sign(front, uc - 13, P.AWN1, [
		".wwww..",
		".mmmm.m",
		".mmmm.m",
		".mmmm.m",
		".mmmmm.",
		".mmmm..",
	], {"w": P.WHITE, "m": P.WOOD_DARK})
	for si in 4:
		_fac_windows(sides[si], 5, 8, uc - 9 if si == 2 else -1, uc + 9 if si == 2 else -1, P.SHUTTER1, si == 2)
	_fac_glow_windows(x0, z0, x1, z1, top)
	# A barrel and mugs outside the door
	_fac_barrel(fp(o, a, n, uc - 17, 0, 3).x, fp(o, a, n, uc - 17, 0, 3).z)
	var mb := fp(o, a, n, uc - 17, 6, 3)
	sv(mb.x, 6, mb.z, P.GOLD)
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
	# Barrels along the back wall and in a corner, shelves of bottles above
	for z in range(zc - 12, zc + 13, 5):
		_fac_barrel(x1 - 2, z)
	_fac_barrel(x0 + 4, z0 + 3)
	_fac_barrel(x0 + 8, z0 + 3)
	# Hams and strings of garlic hanging from the beams
	for hz in [zc - 15, zc + 15]:
		for k in range(4):
			var hxx := x0 + 10 + k * 9
			box3(hxx, 15, hz, hxx, 17, hz, P.IRON if k % 2 == 0 else P.WHITE)
			box3(hxx, 13, hz, hxx, 14, hz, P.TERRA2 if k % 2 == 0 else P.WHITE)
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
	# Round tables with stools (the one by the hearth leaves the fire some room)
	var tables := [Vector2i(x0 + 14, zc - 8), Vector2i(x0 + 26, zc - 12), Vector2i(x0 + 26, zc + 6), Vector2i(x0 + 14, zc + 8)]
	for t: Vector2i in tables:
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				if dx * dx + dz * dz <= 10:
					sv(t.x + dx, 0, t.y + dz, P.TERRA2 if (dx + dz) % 3 != 0 else P.AWN1)   # a rug under it
		sv(t.x, 1, t.y, P.WOOD_DARK)
		box3(t.x, 2, t.y, t.x, 3, t.y, P.WOOD_DARK)
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if dx * dx + dz * dz <= 5:
					sv(t.x + dx, 4, t.y + dz, P.WOOD)
		sv(t.x, 5, t.y, P.WHITE)       # a candle
		sv(t.x, 6, t.y, P.GLOW)
		box3(t.x + 1, 5, t.y, t.x + 1, 6, t.y, P.WOOD)     # a tankard
		sv(t.x - 1, 5, t.y + 1, P.STONE)                    # a plate
		for d: Vector2i in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
			if t == tables[3] and d.y > 0:
				continue   # no stool with its back to the fire
			if t == tables[0] and d.x < 0:
				continue   # nor right inside the door
			_fac_stool(t.x + d.x, t.y + d.y, -Vector3(d.x, 0, d.y).normalized(), "tavern", "sit at the table")
	# Stools along the bar, leaving the way from the door to the barkeep open
	for z in [zc - 8, zc - 4, zc + 4, zc + 8]:
		_fac_stool(bar_x - 2, z, Vector3(1, 0, 0), "tavern", "sit at the bar")
	# Regulars: three at tables, one at the bar
	for e in [[x0 + 18, zc - 8, Vector3(-1, 0, 0)], [x0 + 26, zc + 2, Vector3(0, 0, 1)],
			[x0 + 10, zc + 8, Vector3(1, 0, 0)], [bar_x - 2, zc + 4, Vector3(1, 0, 0)]]:
		extras.append({"pos": _mp(e[0], 0, e[1]), "face": e[2], "pose": "sit", "where": "tavern"})
		_remove_spot("tavern_seat_%d_%d" % [e[0], e[1]])
	for l: Vector2i in [Vector2i(x0 + 14, zc), Vector2i(x0 + 28, zc - 4), Vector2i(bar_x - 6, zc)]:
		_fac_lantern(l.x, l.y, top - 1, 14)
	cast_spots["dorran"] = {"pos": _mp(bar_x + 3, 0, zc), "face": Vector3(-1, 0, 0), "where": "tavern",
			"talk_from": _mp(bar_x - 3, 0, zc)}
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
			var stripe := P.AWN2 if posmod(u / 2, 2) == 0 else P.WALL2   # cream, not bright white (it bloomed)
			svv(fp(o, a, n, u, 14 - out / 2, out), stripe)
			if out == 5 and posmod(u, 2) == 0:
				svv(fp(o, a, n, u, 11, out), stripe)    # a scalloped edge
	# Crates of colourful goods and sacks outside, beside the door
	for du in [-14, -11, 11, 14]:
		var c := fp(o, a, n, uc + du, 0, 3)
		box3(c.x - 1, 1, c.z - 1, c.x + 1, 3, c.z + 1, P.WOOD if du < 0 else P.CLOTH0)
		if du < 0:
			box3(c.x - 1, 4, c.z - 1, c.x + 1, 4, c.z + 1, P.RED if du == -14 else P.AWN1)
	_fac_hanging_sign(front, uc + 16, P.WHITE, [
		"...k...",
		"..sss..",
		".sssss.",
		".sssss.",
		".sssss.",
		"..sss..",
	], {"k": P.WOOD_DARK, "s": P.CLOTH0})
	for si in 4:
		_fac_windows(sides[si], 5, 9, uc - 10 if si == 1 else -1, uc + 10 if si == 1 else -1, P.SHUTTER0, si == 1)
	_fac_glow_windows(x0, z0, x1, z1, top)
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
					var good: int = [P.TERRA, P.BRASS, P.CLOTH2, P.LEAF2, P.AWN1, P.WHITE, P.RED][posmod(z + y * 2, 7)]
					box3(sx + 1, y + 1, z, sx + 1, y + 1 + posmod(z * 5 + y, 3), z, good)   # jars, tins and rolls of different sizes
	for y in [6, 11]:
		box3(xc - 14, y, z0 + 1, xc + 14, y, z0 + 2, P.WOOD)
		for x in range(xc - 13, xc + 14, 2):
			sv(x, y + 1, z0 + 1, [P.GLOW, P.BRASS, P.IRON][posmod(x, 3)])   # lanterns for sale
	box3(xc, 13, z0 + 1, xc, 14, z0 + 1, P.BRASS)   # Pell's first lantern, not for sale
	# Bunches of herbs and garlic hanging under the ceiling
	for hx2 in range(x0 + 6, x1 - 5, 5):
		box3(hx2, top - 2, z1 - 5, hx2, top - 1, z1 - 5, P.LEAF2 if hx2 % 2 == 0 else P.WHITE)
	# Sacks and a barrel at the ends of the counter, a till on top
	box3(xc - 17, 1, z0 + 9, xc - 16, 3, z0 + 10, P.CLOTH0)
	_fac_barrel(xc + 17, z0 + 9)
	box3(xc + 1, 6, z0 + 9, xc + 2, 7, z0 + 9, P.WOOD_DARK)
	# Sacks of grain in a corner, a rug in front of the counter
	for i in 5:
		var sx2 := x0 + 6 + (i % 3) * 3
		var sz2 := z1 - 6 - (i / 3) * 3
		box3(sx2, 1, sz2, sx2 + 1, 2 + i % 2, sz2 + 1, P.CLOTH0)
	for x in range(xc - 8, xc + 9):
		for z in range(z0 + 13, z0 + 22):
			sv(x, 0, z, P.TERRA2 if (x + z) % 4 != 0 else P.WALL2)
	interact_spots.append({"id": "store_shelves", "kind": "look", "pos": _mp(x0 + 7, 0, (z0 + z1) / 2),
			"label": "look over the shelves", "where": "store"})
	for l: Vector2i in [Vector2i(xc, z0 + 18), Vector2i(xc - 10, z1 - 8), Vector2i(xc + 10, z1 - 8)]:
		_fac_lantern(l.x, l.y, top, 13)
	cast_spots["pell"] = {"pos": _mp(xc, 0, z0 + 5), "face": Vector3(0, 0, 1), "where": "store",
			"loop": [_mp(xc - 4, 0, z0 + 5), _mp(xc + 4, 0, z0 + 5)], "talk_from": _mp(xc, 0, z0 + 14)}
	_fac_record("store", "Pell's Provisions", STORE, door, 0)


func _guild_wall(x: int, y: int, z: int) -> int:
	if y <= 3:
		return P.STONE2
	if posmod(y, 4) == 0:
		return P.STONE
	return P.WALL2 if _h(x, y, z) < 0.8 else P.PLAZA


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
	return P.STONE2 if y <= 3 else P.WALL0
