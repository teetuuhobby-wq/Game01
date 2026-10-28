extends "res://world/sky_and_ground.gd"
## THE WORLD, layer 3 of 15: things built on the deck, as templates.
## Paving and stone patterns, houses (walls, windows, shutters, doors, balconies,
## ivy, three kinds of roof, chimneys), lamps, parasols and trees.

var house_doors := []   # every house's front door: [where to stand (metres, on the city), outward direction]


func _stone(x: int, y: int, z: int) -> int:
	if posmod(y, 3) == 0:
		return P.MORTAR
	return P.STONE if _h(floori(x / 5.0), floori(y / 3.0), floori(z / 5.0)) < 0.55 else P.STONE2


## Street paving; with plaza on, rings round the plaza fountain.
func _paving(x: int, z: int, plaza := false) -> int:
	var px := x - PLAZA_X
	var d := sqrt(float(px * px + z * z))
	if plaza and d < 40.0:
		if fmod(d, 3.0) < 0.6:
			return P.MORTAR
		return P.PLAZA if int(d / 3.0) % 2 == 0 else P.PAVE
	var row := floori(z / 3.0)
	var xo := x + posmod(row, 2) * 2
	if posmod(z, 3) == 0 or posmod(xo, 5) == 0:
		return P.MORTAR
	return P.PAVE if _h(floori(xo / 5.0), 0, row) < 0.6 else P.PAVE2


func _lamp(lx: int, lz: int) -> void:
	box3(lx, 1, lz, lx, 12, lz, P.IRON)
	box3(lx - 1, 13, lz - 1, lx + 1, 13, lz + 1, P.IRON)
	box3(lx, 14, lz, lx, 15, lz, P.GLOW)
	box3(lx - 1, 16, lz - 1, lx + 1, 16, lz + 1, P.IRON)


func _parasol(px: int, pz: int, col: int) -> void:
	box3(px, 1, pz, px, 12, pz, P.WOOD_DARK)
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			var r := sqrt(float(dx * dx + dz * dz))
			if r > 8.0:
				continue
			var y := 12 + int((8.0 - r) * 0.4)
			var stripe := int((atan2(float(dz), float(dx)) + PI) / (TAU / 12.0)) % 2
			sv(px + dx, y, pz + dz, col if stripe == 0 else P.WHITE)
	box3(px - 2, 4, pz - 2, px + 2, 4, pz + 2, P.WOOD)
	for side in [-4, 4]:
		box3(px + side, 1, pz - 1, px + side, 2, pz, P.WOOD_DARK)
		box3(px + side + signi(side), 3, pz - 1, px + side + signi(side), 4, pz, P.WOOD_DARK)


## door_side: which wall gets the door (see _sides); -1 = the wall facing the middle of the city.
func _add_house(x0: int, z0: int, w: int, d: int, floors: int, door_side := -1) -> void:
	var r := rng.randf()
	var wall: int = [P.WALL0, P.WALL1, P.WALL2, P.WALL3, P.WALL4][0 if r < 0.35 else 1 if r < 0.6 else 2 if r < 0.8 else 3 if r < 0.92 else 4]
	var shutter: int = P.SHUTTER0 if rng.randf() < 0.6 else P.SHUTTER1
	var x1 := x0 + w - 1
	var z1 := z0 + d - 1
	var top := floors * 15
	for y in range(1, top + 1):
		var p := wall if y > 3 else P.STONE2
		for x in range(x0, x1 + 1):
			sv(x, y, z0, p)
			sv(x, y, z1, p)
		for z in range(z0 + 1, z1):
			sv(x0, y, z, p)
			sv(x1, y, z, p)
	# Cornices between floors and under the roof
	for f in range(1, floors + 1):
		var yb := f * 15
		for x in range(x0 - 1, x1 + 2):
			sv(x, yb, z0 - 1, P.STONE)
			sv(x, yb, z1 + 1, P.STONE)
		for z in range(z0, z1 + 1):
			sv(x0 - 1, yb, z, P.STONE)
			sv(x1 + 1, yb, z, P.STONE)
	# Door faces the middle of the city
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	if door_side < 0:
		if absf(cx) / RXV > absf(cz) / RZV:
			door_side = 2 if cx > 0 else 3
		else:
			door_side = 1 if cz < 0 else 0
	var sides := _sides(x0, z0, x1, z1)
	for si in 4:
		var o: Vector3i = sides[si][0]
		var a: Vector3i = sides[si][1]
		var n: Vector3i = sides[si][2]
		var L: int = sides[si][3]
		var door_at := L / 2 if si == door_side else -100
		var slots := []
		var k := 4
		while k + 3 <= L - 4:
			slots.append(k)
			k += 8
		for f in floors:
			for sx in slots:
				if f == 0 and absi(sx + 1 - door_at) < 7:
					continue
				_window(o, a, n, sx, f * 15 + 5, shutter, f > 0 and rng.randf() < 0.4)
		if door_at >= 0:
			_door(o, a, n, door_at)
			# Where someone stands to go in (metres, on the city), and the way out of the door
			house_doors.append([_m(fp(o, a, n, door_at, 0, 4) + origin), Vector3(n)])
			if floors >= 2 and rng.randf() < 0.6:
				_balcony(o, a, n, door_at, 15)
		if rng.randf() < 0.15:
			_ivy(o, a, n, L, top)
	var rr := rng.randf()
	if rr < 0.3:
		_flat_roof(x0, z0, x1, z1, top, wall)
	elif rr < 0.65:
		_hip_roof(x0, z0, x1, z1, top)
	else:
		_gable_roof(x0, z0, x1, z1, top, w >= d, wall)


func _window(o: Vector3i, a: Vector3i, n: Vector3i, u0: int, y0: int, shutter: int, flowers: bool) -> void:
	var lit := rng.randf() < 0.3
	for u in range(u0, u0 + 3):
		for y in range(y0, y0 + 5):
			clv(fp(o, a, n, u, y, 0))
			var glass := P.WIN_GLOW if lit else P.GLASS
			svv(fp(o, a, n, u, y, -1), P.WOOD_DARK if y == y0 + 2 else glass)
		svv(fp(o, a, n, u, y0 + 5, 0), P.STONE)
		svv(fp(o, a, n, u, y0 - 1, 1), P.WOOD if flowers else P.STONE)
		if flowers:
			svv(fp(o, a, n, u, y0, 1), [P.RED, P.PINK, P.PURPLE, P.LEAF][rng.randi_range(0, 3)])
	for y in range(y0, y0 + 5):
		for u in [u0 - 2, u0 - 1, u0 + 3, u0 + 4]:
			svv(fp(o, a, n, u, y, 0), shutter)


## A door 2.4 m tall and 1 m wide (people are 1.8 m), with a rounded top, a stone
## frame, a step, and a lamp above.
func _door(o: Vector3i, a: Vector3i, n: Vector3i, uc: int) -> void:
	for u in range(uc - 2, uc + 3):
		for y in range(1, 13):
			if y == 12 and (u == uc - 2 or u == uc + 2):
				continue
			clv(fp(o, a, n, u, y, 0))
			svv(fp(o, a, n, u, y, -1), P.WOOD)
	for y in range(1, 14):
		svv(fp(o, a, n, uc - 3, y, 0), P.STONE)
		svv(fp(o, a, n, uc + 3, y, 0), P.STONE)
	for u in range(uc - 3, uc + 4):
		svv(fp(o, a, n, u, 13, 0), P.STONE)
		svv(fp(o, a, n, u, 1, 1), P.STONE2)
	svv(fp(o, a, n, uc, 14, 1), P.GLOW)


func _balcony(o: Vector3i, a: Vector3i, n: Vector3i, uc: int, y: int) -> void:
	for u in range(uc - 5, uc + 5):
		for out in range(1, 4):
			svv(fp(o, a, n, u, y, out), P.STONE)
		svv(fp(o, a, n, u, y + 3, 3), P.IRON)
		if posmod(u - uc, 2) == 0:
			for yy in range(y + 1, y + 3):
				svv(fp(o, a, n, u, yy, 3), P.IRON)
	for out in range(1, 3):
		svv(fp(o, a, n, uc - 5, y + 3, out), P.IRON)
		svv(fp(o, a, n, uc + 4, y + 3, out), P.IRON)
	for u in [uc - 4, uc + 3]:
		svv(fp(o, a, n, u, y + 1, 1), P.TERRA)
		svv(fp(o, a, n, u, y + 2, 1), [P.RED, P.PINK][rng.randi_range(0, 1)])
	for u in range(uc - 1, uc + 2):
		for yy in range(y + 1, y + 9):
			clv(fp(o, a, n, u, yy, 0))
			svv(fp(o, a, n, u, yy, -1), P.GLASS)


func _ivy(o: Vector3i, a: Vector3i, n: Vector3i, length: int, top: int) -> void:
	var u0 := rng.randi_range(0, maxi(0, length - 8))
	var w := rng.randi_range(4, 9)
	var tall := rng.randi_range(8, top)
	for u in range(u0, mini(length, u0 + w)):
		var colh := tall - rng.randi_range(0, 6)
		for y in range(1, colh):
			var v := fp(o, a, n, u, y, 1)
			if _h(v.x, y, v.z) > 0.35:
				svv(v, P.IVY if _h(v.x, y + 9, v.z) > 0.5 else P.LEAF2)


func _hip_roof(x0: int, z0: int, x1: int, z1: int, top: int) -> void:
	var xa := x0 - 2
	var xb := x1 + 2
	var za := z0 - 2
	var zb := z1 + 2
	var layer := 0
	while xa <= xb and za <= zb:
		var y := top + 1 + layer
		var p := P.TERRA if layer % 2 == 0 else P.TERRA2
		var last := xb - xa < 2 or zb - za < 2
		for x in range(xa, xb + 1):
			for z in range(za, zb + 1):
				if last or x == xa or x == xb or z == za or z == zb:
					sv(x, y, z, P.TERRA3 if last else p)
		xa += 1
		xb -= 1
		za += 1
		zb -= 1
		layer += 1
	if rng.randf() < 0.5:
		_chimney(x1 - 4, z1 - 4, top, layer)


func _gable_roof(x0: int, z0: int, x1: int, z1: int, top: int, ridge_x: bool, wall: int) -> void:
	# Ridge runs along the longer side; the short ends get triangular walls.
	var a0 := (z0 if ridge_x else x0) - 2
	var a1 := (z1 if ridge_x else x1) + 2
	var b0 := (x0 if ridge_x else z0) - 2
	var b1 := (x1 if ridge_x else z1) + 2
	var e0 := x0 if ridge_x else z0
	var e1 := x1 if ridge_x else z1
	var layer := 0
	while a0 <= a1:
		var y := top + 1 + layer
		var p := P.TERRA if layer % 2 == 0 else P.TERRA2
		var last := a1 - a0 < 2
		for b in range(b0, b1 + 1):
			for aa in [a0, a1]:
				if ridge_x:
					sv(b, y, aa, P.TERRA3 if last else p)
				else:
					sv(aa, y, b, P.TERRA3 if last else p)
			if last and a1 - a0 == 2:
				if ridge_x:
					sv(b, y, a0 + 1, P.TERRA3)
				else:
					sv(a0 + 1, y, b, P.TERRA3)
		for aa in range(a0 + 1, a1):
			for e in [e0, e1]:
				if ridge_x:
					sv(e, y, aa, wall)
				else:
					sv(aa, y, e, wall)
		a0 += 1
		a1 -= 1
		layer += 1
	if rng.randf() < 0.5:
		_chimney(x1 - 4, z1 - 4, top, layer)


func _chimney(x: int, z: int, top: int, roof_h: int) -> void:
	var ch := top + roof_h + 3
	box3(x, top + 1, z, x + 2, ch, z + 2, P.STONE)
	box3(x - 1, ch + 1, z - 1, x + 3, ch + 1, z + 3, P.STONE2)


func _flat_roof(x0: int, z0: int, x1: int, z1: int, top: int, wall: int) -> void:
	box3(x0, top + 1, z0, x1, top + 1, z1, P.STONE2)
	for x in range(x0, x1 + 1):
		for z in [z0, z1]:
			sv(x, top + 2, z, wall)
			if posmod(x, 3) != 0:
				sv(x, top + 3, z, wall)
	for z in range(z0, z1 + 1):
		for x in [x0, x1]:
			sv(x, top + 2, z, wall)
			if posmod(z, 3) != 0:
				sv(x, top + 3, z, wall)
	for i in 3:
		var px := rng.randi_range(x0 + 2, x1 - 3)
		var pz := rng.randi_range(z0 + 2, z1 - 3)
		box3(px, top + 2, pz, px + 1, top + 2, pz + 1, P.TERRA)
		box3(px - 1, top + 3, pz - 1, px + 2, top + 4, pz + 2, P.LEAF)
	if rng.randf() < 0.6:
		# Washing line between two posts
		var lz := z0 + 3
		box3(x0 + 2, top + 2, lz, x0 + 2, top + 9, lz, P.IRON)
		box3(x1 - 2, top + 2, lz, x1 - 2, top + 9, lz, P.IRON)
		for x in range(x0 + 3, x1 - 2):
			sv(x, top + 9, lz, P.IRON)
			if posmod(x, 4) < 2:
				var cloth: int = [P.CLOTH0, P.CLOTH1, P.CLOTH2][posmod(x / 4, 3)]
				box3(x, top + 6, lz, x, top + 8, lz, cloth)
	elif rng.randf() < 0.5:
		# Pergola with vines
		for px in [x0 + 2, x1 - 2]:
			for pz in [z0 + 2, z1 - 2]:
				box3(px, top + 2, pz, px, top + 10, pz, P.WOOD)
		for x in range(x0 + 2, x1 - 1, 2):
			box3(x, top + 11, z0 + 2, x, top + 11, z1 - 2, P.WOOD)
		for i in 30:
			sv(rng.randi_range(x0 + 2, x1 - 2), top + 12, rng.randi_range(z0 + 2, z1 - 2), P.LEAF)


func _cypress(x: int, z: int) -> void:
	var h := rng.randi_range(28, 40)
	box3(x, 1, z, x + 1, 4, z + 1, P.TRUNK)
	for y in range(4, h):
		var tt := float(y - 4) / float(h - 4)
		var r := 3.3 * pow(1.0 - tt, 0.6) * minf(1.0, tt * 4.0 + 0.4)
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				var fx := dx - 0.5
				var fz := dz - 0.5
				if fx * fx + fz * fz <= r * r and _h(x + dx, y, z + dz) > 0.08:
					sv(x + dx, y, z + dz, P.CYPRESS if _h(x + dx, y + 3, z + dz) < 0.75 else P.LEAF2)


func _olive(x: int, z: int) -> void:
	box3(x, 1, z, x + 1, 9, z + 1, P.TRUNK)
	box3(x + 1, 7, z, x + 2, 10, z, P.TRUNK)
	var rx := rng.randf_range(7.0, 9.5)
	var ry := rng.randf_range(4.5, 6.0)
	for dx in range(-10, 11):
		for dy in range(-6, 7):
			for dz in range(-10, 11):
				var dd := pow(dx / rx, 2) + pow(dy / ry, 2) + pow(dz / rx, 2)
				if dd > 1.0:
					continue
				if _h(x + dx, 12 + dy, z + dz) > 0.15 + 0.6 * maxf(0.0, dd - 0.6):
					sv(x + dx, 12 + dy, z + dz, P.LEAF if _h(x + dx, dy + 40, z + dz) > 0.45 else P.LEAF2)
