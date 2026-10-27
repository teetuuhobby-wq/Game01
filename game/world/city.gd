extends "res://world/buildings.gd"
## THE WORLD, layer 4 of 13: the city's layout.
## The deck and its hull, the wall round the edge, the raised terraces and their
## stairs, the plaza and the bell tower, the homes and trees, and what's underneath
## (the boiler, lanterns, and the struts holding the legs).


func _build_deck() -> void:
	for x in range(-RXV, RXV + 1):
		for z in range(-RZV, RZV + 1):
			if _e(x, z) > 1.0:
				continue
			sv(x, 0, z, _paving(x, z))
			var b := _hull_bottom(x, z)
			var hi := b + 1
			var edge := false
			for nb in [_hull_bottom(x + 1, z), _hull_bottom(x - 1, z), _hull_bottom(x, z + 1), _hull_bottom(x, z - 1)]:
				if nb == 1:
					edge = true
				else:
					hi = maxi(hi, nb)
			if edge:
				hi = -1
			for y in range(b, hi + 1):
				var p := P.HULL
				if y >= -3:
					p = P.WOOD_DARK if y != -3 else P.WOOD
				elif y == -8 and posmod(x + z, 4) == 0:
					p = P.BRASS
				elif posmod(floori(x / 20.0) + floori(z / 20.0) + floori(y / 8.0), 2) == 0:
					p = P.HULL2
				sv(x, y, z, p)


func _build_wall_ring() -> void:
	for x in range(-RXV, RXV + 1):
		for z in range(-RZV, RZV + 1):
			var e := _e(x, z)
			if e > 1.0 or e < 0.92:
				continue
			for y in range(1, 8):
				sv(x, y, z, _stone(x, y, z))
			var seg := int((atan2(float(z), float(x) * RZV / RXV) + PI) / TAU * 240.0)
			if seg % 2 == 0:
				for y in range(8, 11):
					sv(x, y, z, _stone(x, y, z))
	# Lamps along the inside of the wall
	for i in 32:
		var a := TAU * (i + 0.5) / 32.0   # between the main streets, not on them
		var lp := _round_rect(RXV * 0.9, RZV * 0.9, a)
		var lx := int(lp.x)
		var lz := int(lp.y)
		if lz >= MARKET_Z0:
			continue
		_lamp(lx, lz)
		occ[Vector2i(_cell(lx), _cell(lz))] = true


## Raised terraces: a paved floor on a stone retaining wall, with a balustrade
## along the edge, vines hanging down the wall here and there, and lamps.
func _build_terraces() -> void:
	for l in range(1, LEVELS.size()):
		var h: int = LEVELS[l][1]
		var below: int = LEVELS[l - 1][1]
		var reach: float = LEVELS[l][0]
		var rx := ceili(RXV * reach) + 1
		var rz := ceili(RZV * reach) + 1
		for x in range(-rx, rx + 1):
			for z in range(-rz, rz + 1):
				if level_at(x, z) != l:
					continue
				sv(x, h, z, _paving(x, z, l == LEVELS.size() - 1))
				var outer := 0   # 1 = on the edge, 2 = one block in: the wall is two blocks thick
				for d in [1, 2]:
					if outer == 0 and (level_at(x + d, z) < l or level_at(x - d, z) < l \
							or level_at(x, z + d) < l or level_at(x, z - d) < l):
						outer = d
				if outer == 0:
					continue
				var vine := _h(floori(x / 4.0), l, floori(z / 4.0)) > 0.72
				var vine_end := h - 4 - int(_h(x, l, z) * 14.0)
				for y in range(1, h):
					var p := P.STONE2 if y <= below + 2 else _stone(x, y, z)
					if vine and outer == 1 and y > vine_end and _h(x, y, z) > 0.15:
						p = P.IVY if _h(x, y + 7, z) > 0.4 else P.LEAF2
					sv(x, y, z, p)
				if outer == 1:
					# A stone ledge sticking out just under the top, for a crisp shadow line
					for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if level_at(x + n.x, z + n.y) < l:
							sv(x + n.x, h - 1, z + n.y, P.STONE)
					# Balustrade: a post every third block under a stone rail.
					if posmod(x + z, 3) == 0:
						box3(x, h + 1, z, x, h + 3, z, P.STONE2)
					sv(x, h + 4, z, P.STONE)
		# Lamps just inside the balustrade, clear of the stairs on the main streets
		origin = Vector3i(0, h, 0)
		for i in 16:
			var a := TAU * (i + 0.5) / 16.0
			var lp := _round_rect(RXV * reach - 3, RZV * reach - 3, a)
			var lx := int(lp.x)
			var lz := int(lp.y)
			if level_at(lx, lz) == l:
				_lamp(lx, lz)
		origin = Vector3i.ZERO


## Stairs down from every terrace edge, along the four main streets.
func _build_stairs() -> void:
	for l in range(1, LEVELS.size()):
		var h: int = LEVELS[l][1]
		var below: int = LEVELS[l - 1][1]
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var across := Vector2i(dir.y, dir.x)
			var k := 0   # last block of the terrace along this street
			while level_at(dir.x * (k + 1), dir.y * (k + 1)) >= l:
				k += 1
			for s in range(1, h - below):
				var top := h - s
				for w in range(-5, 5):
					var c := dir * (k + s) + across * w
					var side := w == -5 or w == 4
					for y in range(below + 1, top + (3 if side else 1)):
						sv(c.x, y, c.y, P.STONE if side else (P.PAVE if y == top else P.STONE2))
					if not side:
						stair_top[c] = top
			# A gap in the balustrade at the top
			for d in range(-2, 1):
				for w in range(-4, 4):
					var c := dir * (k + d) + across * w
					for y in range(h + 1, h + 5):
						clv(Vector3i(c.x, y, c.y))


func _build_plaza() -> void:
	for x in range(-9, 10):
		for z in range(-9, 10):
			if x * x + z * z < 81:
				occ[Vector2i(x, z)] = true
	# Fountain
	for x in range(-13, 14):
		for z in range(-13, 14):
			var d := sqrt(float(x * x + z * z))
			if d <= 13.0 and d > 11.0:
				for y in range(1, 5):
					sv(x, y, z, P.STONE if y < 4 else P.STONE2)
			elif d <= 11.0:
				sv(x, 1, z, P.STONE2)
				sv(x, 2, z, P.WATER)
	for x in range(-6, 7):
		for z in range(-6, 7):
			var d := sqrt(float(x * x + z * z))
			if d <= 2.0:
				box3(x, 1, z, x, 12, z, P.STONE)
			if d <= 6.0 and d > 4.8:
				box3(x, 12, z, x, 14, z, P.STONE)
			elif d <= 4.8:
				sv(x, 12, z, P.STONE2)
				sv(x, 13, z, P.WATER)
	box3(0, 13, 0, 0, 16, 0, P.STONE2)
	# Parasols, tables and chairs round the plaza
	var cols := [P.AWN0, P.AWN1, P.AWN2]
	for i in 6:
		var a := PARASOL_A0 + TAU * i / 6.0
		_parasol(int(cos(a) * 27.0), int(sin(a) * 27.0), cols[i % 3])
	# Flower beds round the plaza edge. Knee-high, so you can wade through them
	# (playtest 3: they worked like an invisible fence, especially in first person).
	for i in 90:
		var a := TAU * i / 90.0
		if posmod(i, 15) < 3:
			continue
		var fx := int(cos(a) * 39.0)
		var fz := int(sin(a) * 39.0)
		sv(fx, 1, fz, P.LEAF2)
		sv(fx, 2, fz, [P.PURPLE, P.PINK, P.RED, P.PURPLE][i % 4] if _h(fx, 2, fz) < 0.6 else P.LEAF)
		for y in [1, 2]:
			soft[Vector3i(fx, y, fz) + origin] = true


func _build_tower(x0: int, z0: int) -> void:
	var s := 26
	var h := 110
	var x1 := x0 + s - 1
	var z1 := z0 + s - 1
	for x in range(_cell(x0) - 2, _cell(x1) + 2):
		for z in range(_cell(z0) - 2, _cell(z1) + 2):
			occ[Vector2i(x, z)] = true
	for y in range(1, h + 1):
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				var on_x := x == x0 or x == x1
				var on_z := z == z0 or z == z1
				if not (on_x or on_z):
					continue
				var corner := (x - x0 < 3 or x1 - x < 3) and (z - z0 < 3 or z1 - z < 3)
				var p := P.WALL0
				if y <= 4:
					p = P.STONE2
				elif corner and posmod(y, 6) < 3:
					p = P.STONE
				sv(x, y, z, p)
	for yb in [40, 75, h - 18, h]:
		for x in range(x0 - 1, x1 + 2):
			sv(x, yb, z0 - 1, P.STONE)
			sv(x, yb, z1 + 1, P.STONE)
		for z in range(z0 - 1, z1 + 2):
			sv(x0 - 1, yb, z, P.STONE)
			sv(x1 + 1, yb, z, P.STONE)
	var sides := _sides(x0, z0, x1, z1)
	for sd in sides:
		var o: Vector3i = sd[0]
		var a: Vector3i = sd[1]
		var n: Vector3i = sd[2]
		var uc: int = sd[3] / 2
		# Belfry arches
		for u in range(uc - 5, uc + 5):
			for y in range(h - 15, h - 3):
				if y >= h - 5 and (u == uc - 5 or u == uc + 4):
					continue
				clv(fp(o, a, n, u, y, 0))
		# Narrow lit windows lower down
		for yy in [14, 28, 48, 62]:
			for u in range(uc - 1, uc + 1):
				for y in range(yy, yy + 7):
					clv(fp(o, a, n, u, y, 0))
					svv(fp(o, a, n, u, y, -1), P.WIN_GLOW)
	box3(x0 + 1, h - 16, z0 + 1, x1 - 1, h - 16, z1 - 1, P.WOOD_DARK)
	var bcx := (x0 + x1) / 2
	var bcz := (z0 + z1) / 2
	for y in range(h - 14, h - 6):
		var r := 2.0 + (h - 7 - y) * 0.45
		for dx in range(-6, 7):
			for dz in range(-6, 7):
				var d := sqrt(float(dx * dx + dz * dz))
				if d <= r and d > r - 1.5:
					sv(bcx + dx, y, bcz + dz, P.GOLD)
	box3(bcx, h - 6, bcz, bcx, h - 4, bcz, P.IRON)
	# Clock face on the front
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var d := sqrt(float(dx * dx + dy * dy))
			if d <= 6.0:
				sv(bcx + dx, h - 26 + dy, z0 - 1, P.GOLD if d > 5.0 else P.WHITE)
	for i in 5:
		sv(bcx, h - 26 + i, z0 - 2, P.IRON)
	for i in 4:
		sv(bcx + i, h - 26, z0 - 2, P.IRON)
	var front: Array = sides[0]
	_door(front[0], front[1], front[2], s / 2)
	# Steep tiled roof
	var lo := -3
	var hi := s + 2
	var y := h + 1
	var layer := 0
	while lo <= hi:
		for x in range(x0 + lo, x0 + hi + 1):
			for z in range(z0 + lo, z0 + hi + 1):
				var rim := x == x0 + lo or x == x0 + hi or z == z0 + lo or z == z0 + hi
				if rim or hi - lo < 2:
					sv(x, y, z, P.TERRA if posmod(y, 2) == 0 else P.TERRA2)
		y += 1
		layer += 1
		if layer % 2 == 0:
			lo += 1
			hi -= 1
	box3(bcx, y, bcz, bcx, y + 8, bcz, P.GOLD)
	for fx in range(1, 9):
		for fy in range(0, 5):
			sv(bcx + fx, y + 8 - fy, bcz, P.FLAG)


## Keeps the two main streets clear (along x and along z, edge to edge; the stairs
## are on them). Done before the market and the homes, so nothing is built on them
## (session 03: a market shop had been built over the north stairs).
func _reserve_streets() -> void:
	for i in range(-RXV / RES - 1, RXV / RES + 2):
		for k in range(-1, 2):
			streets[Vector2i(i, k)] = true
			streets[Vector2i(k, i)] = true


func _place_houses() -> void:
	# Pack houses tightly on each terrace, clear of the main streets; neighbours may
	# share walls like an old Mediterranean town. The top terrace is kept for the
	# plaza and the tower.
	var placed := 0
	for attempt in 30000:
		if placed >= 320:
			break
		var w := rng.randi_range(3, 6)
		var d := rng.randi_range(3, 5)
		var x0 := rng.randi_range(-RXV / RES + 2, RXV / RES - 8)
		var z0 := rng.randi_range(-RZV / RES + 2, RZV / RES - 7)
		var ok := true
		for x in range(x0, x0 + w):
			for z in range(z0, z0 + d):
				if _e(x * RES, z * RES) > 0.82 or occ.has(Vector2i(x, z)) or streets.has(Vector2i(x, z)):
					ok = false
		# A metre's gap to the main streets, so roof overhangs stay off them (session 03:
		# eaves hung over the east stairs at head height)
		for x in range(x0 - 1, x0 + w + 1):
			for z in range(z0 - 1, z0 + d + 1):
				if streets.has(Vector2i(x, z)):
					ok = false
		if not ok:
			continue
		var l := level_of_area(x0 * RES, z0 * RES, (x0 + w) * RES - 1, (z0 + d) * RES - 1)
		if l < 0 or l == LEVELS.size() - 1:
			continue
		for x in range(x0, x0 + w):
			for z in range(z0, z0 + d):
				occ[Vector2i(x, z)] = true
		var floors := 1
		if rng.randf() < 0.55:
			floors += 1
		if rng.randf() < 0.12:
			floors += 1
		floors = mini(floors, 2)  # keep roofs low enough that the terrace walls show
		origin = Vector3i(0, LEVELS[l][1], 0)
		_add_house(x0 * RES, z0 * RES, w * RES, d * RES, floors)
		origin = Vector3i.ZERO
		placed += 1
	print("houses: ", placed)


func _place_trees() -> void:
	var n := 0
	for attempt in 3000:
		if n >= 70:
			break
		var x := rng.randi_range(-RXV / RES + 3, RXV / RES - 3)
		var z := rng.randi_range(-RZV / RES + 3, RZV / RES - 3)
		if _e(x * RES, z * RES) > 0.82:
			continue
		# Canopies are wide: keep trees well back from the terrace edges.
		var l := level_of_area(x * RES - 10, z * RES - 10, x * RES + 10, z * RES + 10)
		if l < 0 or l == LEVELS.size() - 1:
			continue
		var free := true
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				if occ.has(Vector2i(x + ox, z + oz)) or streets.has(Vector2i(x + ox, z + oz)):
					free = false
		if not free:
			continue
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				occ[Vector2i(x + ox, z + oz)] = true
		origin = Vector3i(0, LEVELS[l][1], 0)
		if rng.randf() < 0.35:
			_cypress(x * RES, z * RES)
		else:
			_olive(x * RES, z * RES)
		origin = Vector3i.ZERO
		n += 1
	# Bushes and flowers along the inside of the wall
	for i in 160:
		var a := rng.randf() * TAU
		var bp := _round_rect(RXV * 0.88, RZV * 0.88, a)
		var bx := int(bp.x)
		var bz := int(bp.y)
		if occ.has(Vector2i(_cell(bx), _cell(bz))):
			continue
		for dx in range(-3, 4):
			for dy in range(0, 4):
				for dz in range(-3, 4):
					if dx * dx + dy * dy * 2 + dz * dz <= 10 and _h(bx + dx, dy, bz + dz) > 0.2:
						var p := P.LEAF if _h(bx + dx, dy + 5, bz + dz) > 0.4 else P.LEAF2
						if dy >= 2 and _h(bx + dx, dy + 11, bz + dz) > 0.8:
							p = [P.PINK, P.RED, P.PURPLE][i % 3]
						sv(bx + dx, 1 + dy, bz + dz, p)


func _build_underside() -> void:
	var x0 := -45
	var x1 := 45
	var z0 := -30
	var z1 := 30
	var y0 := -56
	var y1 := -14
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				var face_x := x == x0 or x == x1
				var face_z := z == z0 or z == z1
				if not (face_x or face_z or y == y0):
					continue
				var p := P.HULL2 if posmod(y, 8) == 0 else P.HULL
				if (face_x or face_z) and y >= -42 and y <= -40 and posmod(x + z, 6) < 2:
					p = P.GLOW
				sv(x, y, z, p)
	# Lanterns hanging under the hull
	for i in 18:
		var a := TAU * i / 18.0
		var lx := int(cos(a) * RXV * 0.6)
		var lz := int(sin(a) * RZV * 0.6)
		var b := _hull_bottom(lx, lz)
		box3(lx, b - 6, lz, lx, b - 1, lz, P.IRON)
		box3(lx, b - 8, lz, lx, b - 7, lz, P.GLOW)


## A thick beam under the deck from each hip in toward the middle, holding the leg on.
func _build_struts() -> void:
	for hip in _hip_positions():
		var h := Vector3(hip) * RES
		var dir := -Vector3(h.x, 0, h.z).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var t := 0
		while _e(h.x + dir.x * t, h.z + dir.z * t) > 0.75:
			var c := h + dir * t
			for a in range(-4, 5):
				for b in range(-4, 5):
					var p := c + side * a + Vector3(0, b, 0)
					var band := posmod(t, 12) < 2
					sv(roundi(p.x), roundi(p.y), roundi(p.z), P.BRASS if band and absi(b) == 4 else P.HULL)
			t += 1
