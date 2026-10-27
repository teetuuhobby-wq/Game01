extends "res://world/facilities.gd"
## THE WORLD, layer 7 of 10: the market street (north half of the outer ring).
## A U-shaped shopping street: up the east side, along the north, down the west side,
## from stairs to stairs. Shops on both sides with open fronts, awnings, hanging signs
## and goods outside; lanterns, bunting and washing strung across; stalls on little
## squares. All numbers are blocks (5 per metre). The south half stays homes.


const MK_N_INNER := Vector2i(115, 144)    # north side: shops toward the city's middle (z range)


const MK_N_STREET := Vector2i(145, 184)   # the street (8 m wide)


const MK_N_OUTER := Vector2i(185, 208)    # shops backing onto the city wall


const MK_S_INNER := Vector2i(154, 183)    # east side (mirrored for west): x ranges


const MK_S_STREET := Vector2i(184, 223)


const MK_S_OUTER := Vector2i(224, 259)


const MK_SQUARE_N := Vector2i(-30, 30)    # a square in the north outer row, across from the stairs (x range)


const MK_SQUARE_S := Vector2i(45, 95)     # and one in each side's outer row (z range)


## Shop kinds: awning colour, goods colours (the first two also paint the sign's icon).
const SHOPS := [
	["baker", P.AWN1, [P.AWN1, P.WOOD, P.WHITE]],
	["greengrocer", P.LEAF, [P.RED, P.LEAF, P.AWN1, P.LEAF2]],
	["cloth", P.PURPLE, [P.CLOTH1, P.CLOTH2, P.PURPLE, P.PINK]],
	["smith", P.IRON, [P.IRON, P.BRASS, P.HULL2]],
	["potter", P.TERRA, [P.TERRA, P.TERRA2, P.WHITE]],
	["spices", P.AWN0, [P.AWN0, P.AWN1, P.TERRA, P.GOLD]],
	["fishmonger", P.AWN2, [P.WATER, P.WHITE, P.STONE]],
	["florist", P.PINK, [P.PINK, P.RED, P.PURPLE, P.LEAF]],
	["tavern", P.AWN0, [P.WOOD_DARK, P.GOLD, P.WOOD]],
	["lamps", P.AWN1, [P.GOLD, P.BRASS, P.GLOW]],
]


var market_path := PackedVector3Array()   # street centre line (metres, on the city), every 0.5 m


var market_dir := PackedVector3Array()    # direction along the street at each point


var shopkeepers := []                     # [position on the city (metres), facing (unit vector)]


var shoppers := []                        # customers standing at the stalls, same format


var _mk_taken := {}                       # blocks used by market shops and stalls


func _build_market() -> void:
	# Keep houses and trees out of the whole market half of the outer ring
	for x in range(-RXV, RXV + 1, 5):
		for z in range(MARKET_Z0, RZV + 1, 5):
			if level_at(x, z) == 0:
				occ[Vector2i(_cell(x), _cell(z))] = true
	# Street paving: big flagstones with a gutter down the middle
	for x in range(-MK_S_STREET.y, MK_S_STREET.y + 1):
		for z in range(MK_N_STREET.x, MK_N_STREET.y + 1):
			_market_pave(x, z, z - (MK_N_STREET.x + MK_N_STREET.y) / 2)
	for sx in [-1, 1]:
		for ax in range(MK_S_STREET.x, MK_S_STREET.y + 1):
			for z in range(0, MK_N_STREET.x):
				_market_pave(ax * sx, z, ax - (MK_S_STREET.x + MK_S_STREET.y) / 2)
	# Stalls on the little squares first, so the shop rows leave room for them
	for sx in [-12, 12]:
		_stall(sx, 197, Vector2i(0, -1))
	for side in [-1, 1]:
		for z in [58, 82]:
			_stall(side * 242, z, Vector2i(-side, 0))
	# Shop rows
	_shop_row(true, -MK_S_INNER.y, MK_S_INNER.y, MK_N_INNER, 1)
	_shop_row(true, -MK_S_STREET.y, MK_S_STREET.y, MK_N_OUTER, -1)
	for side in [-1, 1]:
		_shop_row(false, MARKET_Z0, MK_N_INNER.x - 1, _mk_mirror(MK_S_INNER, side), side)
		_shop_row(false, MARKET_Z0, MK_N_OUTER.y, _mk_mirror(MK_S_OUTER, side), -side)
	_market_overhead()
	_build_market_path()
	print("market: %d shops and stalls, street %.0f m" % [shopkeepers.size(), market_path.size() * 0.5])


func _mk_mirror(r: Vector2i, side: int) -> Vector2i:
	return r if side > 0 else Vector2i(-r.y, -r.x)


## True if the column is on the outer ring, inside the city wall.
func _mk_ground(x: int, z: int) -> bool:
	return level_at(x, z) == 0 and _tq(x, z) < 0.957   # the wall ring starts at 0.959


func _market_pave(x: int, z: int, across: int) -> void:
	if not _mk_ground(x, z):
		return
	var p := P.PAVE if _h(floori(x / 5.0), 1, floori(z / 5.0)) < 0.5 else P.PAVE2
	if across == 0 or across == -1:
		p = P.STONE2
	elif posmod(x, 5) == 0 or posmod(z, 5) == 0:
		p = P.MORTAR
	sv(x, 0, z, p)


## A row of shops filling `across` (a block range across the row), from a0 to a1 along
## it (along x if along_x, else along z). front = +1 or -1: the side the street is on.
func _shop_row(along_x: bool, a0: int, a1: int, across: Vector2i, front: int) -> void:
	var u := a0
	while u <= a1 - 15:
		var w := mini(rng.randi_range(20, 32), a1 - u + 1)
		if w < 15:
			break
		var x0 := u if along_x else across.x
		var z0 := across.x if along_x else u
		var wx := w if along_x else across.y - across.x + 1
		var wz := across.y - across.x + 1 if along_x else w
		if not _plot_ok(x0, z0, wx, wz):
			u += 5
			continue
		for x in range(x0, x0 + wx):
			for z in range(z0, z0 + wz):
				_mk_taken[Vector2i(x, z)] = true
		var door_side := (1 if front > 0 else 0) if along_x else (3 if front > 0 else 2)
		_add_shop(x0, z0, wx, wz, door_side)
		u += w
		if rng.randf() < 0.22:
			u += 8   # a narrow alley between two shops


## A plot is fine if it (and a block around it) is on the outer ring, clear of the
## main streets and stairs, and not already used by another shop or stall.
func _plot_ok(x0: int, z0: int, wx: int, wz: int) -> bool:
	for x in range(x0 - 1, x0 + wx + 1):
		for z in range(z0 - 1, z0 + wz + 1):
			if not _mk_ground(x, z) or streets.has(Vector2i(_cell(x), _cell(z))) or stair_top.has(Vector2i(x, z)):
				return false
	for x in range(x0, x0 + wx):
		for z in range(z0, z0 + wz):
			if _mk_taken.has(Vector2i(x, z)):
				return false
	# The little squares (north, and one on each side) stay open
	if z0 >= MK_N_OUTER.x and x0 < MK_SQUARE_N.y and x0 + wx > MK_SQUARE_N.x:
		return false
	if mini(absi(x0), absi(x0 + wx - 1)) >= MK_S_OUTER.x and z0 < MK_SQUARE_S.y and z0 + wz > MK_SQUARE_S.x:
		return false
	return true


## A shop: a house with an open ground-floor front, an awning, a hanging sign,
## goods outside and inside, a counter, shelves and a lantern.
func _add_shop(x0: int, z0: int, w: int, d: int, door_side: int) -> void:
	var floors := 3 if rng.randf() < 0.6 else 4   # taller than the homes: a proper street canyon
	_add_house(x0, z0, w, d, floors, door_side)
	var sd: Array = _sides(x0, z0, x0 + w - 1, z0 + d - 1)[door_side]
	var o: Vector3i = sd[0]
	var a: Vector3i = sd[1]
	var n: Vector3i = sd[2]
	var L: int = sd[3]
	var depth := d if door_side < 2 else w
	var shop: Array = SHOPS[rng.randi() % SHOPS.size()]
	var awn: int = shop[1]
	var goods: Array = shop[2]
	# Open shopfront between the corner pillars, under a dark timber beam
	for u in range(2, L - 2):
		for y in range(1, 11):
			for out in [-1, 0, 1]:
				clv(fp(o, a, n, u, y, out))
	for u in range(L):
		svv(fp(o, a, n, u, 11, 0), P.WOOD_DARK)
	# A ceiling inside (so you don't see up into the roof) with a lantern under it
	box3(x0 + 1, 12, z0 + 1, x0 + w - 2, 12, z0 + d - 2, P.WOOD_DARK)
	svv(fp(o, a, n, L / 2, 11, -depth / 2), P.GLOW)
	# Counter, with goods on it; shelves on the back wall
	for u in range(4, L - 4):
		for y in range(1, 4):
			svv(fp(o, a, n, u, y, -5), P.WOOD)
		svv(fp(o, a, n, u, 4, -5), P.WOOD_DARK if posmod(u, 3) != 0 else goods[u % goods.size()])
	for u in range(2, L - 2):
		for y in [3, 6, 9]:
			svv(fp(o, a, n, u, y, -(depth - 2)), P.WOOD)
			if rng.randf() < 0.75:
				svv(fp(o, a, n, u, y + 1, -(depth - 2)), goods[rng.randi() % goods.size()])
	shopkeepers.append([_m(fp(o, a, n, L / 2, 0, -7)), Vector3(n)])
	# Awning: striped, sloping down from the beam over the street (above head height)
	for u in range(2, L - 2):
		for out in range(1, 6):
			var y := 13 - (out - 1) / 2
			svv(fp(o, a, n, u, y, out), awn if (u / 3) % 2 == 0 else P.WHITE)
	# Goods outside: crates of produce either side of the way in
	var uc := L / 2
	var u := 3
	while u + 2 < L - 3:
		if absi(u + 1 - uc) > 4:
			for du in 3:
				for out in [1, 2]:
					svv(fp(o, a, n, u + du, 1, out), P.WOOD)
					svv(fp(o, a, n, u + du, 2, out), goods[(u + du + out) % goods.size()])
		u += 4
	# A big hanging sign on an iron bracket at one corner, sticking out over the
	# street: a dark frame, the shop's colour, and its icon (3x3) in the middle
	var su := 0 if rng.randf() < 0.5 else L - 1
	var face_col: int = awn if awn != P.IRON else P.GOLD
	for out in range(1, 8):
		svv(fp(o, a, n, su, 19, out), P.IRON)
	for out in range(2, 8):
		for y in range(12, 18):
			var edge := out == 2 or out == 7 or y == 12 or y == 17
			var icon := out in [4, 5] and y in [14, 15]
			var p: int = P.WOOD_DARK if edge else face_col
			if icon:
				p = goods[(out + y) % 2]
			svv(fp(o, a, n, su, y, out), p)
	svv(fp(o, a, n, su, 18, 2), P.IRON)
	svv(fp(o, a, n, su, 18, 7), P.IRON)
	# Most shops also hang a tall banner down the front, Tokyo style: the shop's
	# colour with pale marks like a column of lettering
	if rng.randf() < 0.65:
		var bu := L - 5 if su == 0 else 2
		var banner: int = [P.AWN0, P.AWN2, P.CLOTH1, P.PURPLE, P.AWN1][rng.randi() % 5]
		for du in 3:
			for y in range(17, 30):
				var mark := du == 1 and y > 17 and y < 29 and posmod(y, 3) != 0 and _h(su, y, x0 + z0) < 0.8
				svv(fp(o, a, n, bu + du, y, 1), P.WHITE if mark else banner)


## A market stall: four posts, a striped canopy, a table of goods facing `face`.
func _stall(cx: int, cz: int, face: Vector2i) -> void:
	var shop: Array = SHOPS[rng.randi() % SHOPS.size()]
	var col: int = shop[1]
	var goods: Array = shop[2]
	var along := Vector2i(face.y, face.x)
	for i in range(-7, 8):
		for j in range(-5, 6):
			var c: Vector2i = Vector2i(cx, cz) + along * i + face * j
			_mk_taken[c] = true
	for i in [-6, 6]:
		for j in [-4, 4]:
			var c: Vector2i = Vector2i(cx, cz) + along * i + face * j
			box3(c.x, 1, c.y, c.x, 12, c.y, P.WOOD_DARK)
	for i in range(-7, 8):
		for j in range(-5, 6):
			var c: Vector2i = Vector2i(cx, cz) + along * i + face * j
			sv(c.x, 13, c.y, col if posmod(i + 7, 4) < 2 else P.WHITE)
	for i in range(-5, 6):
		for j in [3, 4]:
			var c: Vector2i = Vector2i(cx, cz) + along * i + face * j
			box3(c.x, 1, c.y, c.x, 3, c.y, P.WOOD)
			sv(c.x, 4, c.y, goods[posmod(i + j, goods.size())])
	shopkeepers.append([_m(Vector3i(cx, 0, cz) - Vector3i(face.x, 0, face.y) * 1), Vector3(face.x, 0, face.y)])
	for k in rng.randi_range(2, 3):
		var spot := Vector2i(cx, cz) + face * rng.randi_range(8, 10) + along * rng.randi_range(-6, 6)
		shoppers.append([_m(Vector3i(spot.x, 0, spot.y)), -Vector3(face.x, 0, face.y)])


## Lantern strings and bunting across the streets, attached to the shopfronts.
func _market_overhead() -> void:
	var k := 0
	for x in range(-205, 206, 22):
		_overhead_line(Vector2i(x, MK_N_STREET.x - 1), Vector2i(x, MK_N_STREET.y + 1), k)
		k += 1
	for side in [-1, 1]:
		for z in range(16, MK_N_STREET.x - 10, 22):
			_overhead_line(Vector2i(side * (MK_S_STREET.x - 1), z), Vector2i(side * (MK_S_STREET.y + 1), z), k)
			k += 1
	# Washing hung out between the upper floors
	for x in range(-194, 195, 33):
		_laundry_line(Vector2i(x, MK_N_STREET.x - 1), Vector2i(x, MK_N_STREET.y + 1))
	for side in [-1, 1]:
		for z in range(27, MK_N_STREET.x - 10, 33):
			_laundry_line(Vector2i(side * (MK_S_STREET.x - 1), z), Vector2i(side * (MK_S_STREET.y + 1), z))


func _overhead_line(a: Vector2i, b: Vector2i, k: int) -> void:
	var lanterns := k % 2 == 0
	var flags := [P.AWN0, P.AWN1, P.AWN2, P.CLOTH0, P.PINK]
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(n + 1):
		var t := float(i) / n
		var x := roundi(lerpf(a.x, b.x, t))
		var z := roundi(lerpf(a.y, b.y, t))
		var y := 26 - roundi(4.0 * sin(PI * t))
		sv(x, y, z, P.IRON)
		if i % 4 == 2 and i > 2 and i < n - 2:
			if lanterns:
				sv(x, y - 1, z, [P.AWN0, P.AWN1][(i / 4) % 2])
				sv(x, y - 2, z, P.GLOW)
				sv(x, y - 3, z, [P.AWN0, P.AWN1][(i / 4) % 2])
			else:
				var f: int = flags[(i / 4 + k) % flags.size()]
				sv(x, y - 1, z, f)
				sv(x, y - 2, z, f)


func _laundry_line(a: Vector2i, b: Vector2i) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	var cloth := [P.CLOTH0, P.CLOTH1, P.CLOTH2, P.WHITE, P.AWN1]
	for i in range(n + 1):
		var t := float(i) / n
		var x := roundi(lerpf(a.x, b.x, t))
		var z := roundi(lerpf(a.y, b.y, t))
		var y := 40 - roundi(3.0 * sin(PI * t))
		sv(x, y, z, P.WOOD_DARK)
		if i > 3 and i < n - 3 and posmod(i, 6) < 4:
			var c: int = cloth[(i / 6 + a.x + a.y) % cloth.size()]
			for dy in range(1, 3 + (i / 6) % 2):
				sv(x, y - dy, z, c)


## The street's centre line for the crowd, with rounded corners, sampled every 0.5 m.
func _build_market_path() -> void:
	var xs := (MK_S_STREET.x + MK_S_STREET.y) * 0.5 * VS
	var zn := (MK_N_STREET.x + MK_N_STREET.y) * 0.5 * VS
	var r := 4.5
	var pts: Array[Vector2] = []
	var line := func(p: Vector2, q: Vector2) -> void:
		var steps := maxi(1, int(p.distance_to(q) / 0.5))
		for i in steps:
			pts.append(p.lerp(q, float(i) / steps))
	var arc := func(c: Vector2, a0: float, a1: float) -> void:
		var steps := int(absf(a1 - a0) * r / 0.5)
		for i in steps:
			var a := lerpf(a0, a1, float(i) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	line.call(Vector2(xs, 1.5), Vector2(xs, zn - r))
	arc.call(Vector2(xs - r, zn - r), 0.0, PI * 0.5)
	line.call(Vector2(xs - r, zn), Vector2(-xs + r, zn))
	arc.call(Vector2(-xs + r, zn - r), PI * 0.5, PI)
	line.call(Vector2(-xs, zn - r), Vector2(-xs, 1.5))
	pts.append(Vector2(-xs, 1.5))
	for i in pts.size():
		market_path.append(Vector3(pts[i].x, VS * 0.5, pts[i].y))
		var d := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
		d = d.normalized()
		market_dir.append(Vector3(d.x, 0, d.y))


## How far a point on the city (metres) is from the market street's centre line.
func market_distance(p: Vector3) -> float:
	var best := INF
	for i in range(0, market_path.size(), 4):
		var q := market_path[i]
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best
