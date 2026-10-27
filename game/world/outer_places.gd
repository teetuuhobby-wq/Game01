extends "res://world/facility_kit.gd"
## THE WORLD, layer 7 of 13: the places a little further out.
## The domed bathhouse (a pool you wade into and sit in), the inside of Bram's workshop,
## Old Wendel's lookout by the outer wall, and the street Pip runs along. The guild hall,
## the tavern and the store are in facilities.gd, which also builds all of them in order.

const BATH := Rect2i(80, -165, 60, 47)       # domed, door toward the city's middle


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
	# A flat roof, and on it a round drum holding up a tall white dome with a blue band,
	# a gold finial and a steam vent: you can see it over the rooftops
	box3(x0, top + 1, z0, x1, top + 1, z1, P.STONE2)
	var R := minf((x1 - x0) / 2.0, (z1 - z0) / 2.0) - 3.0
	var drum := 5
	for x in range(xc - int(R) - 1, xc + int(R) + 2):
		for z in range(zc - int(R) - 1, zc + int(R) + 2):
			var d := sqrt(float((x - xc) * (x - xc) + (z - zc) * (z - zc)))
			if d <= R and d > R - 1.5:
				for y in range(top + 2, top + 2 + drum):
					sv(x, y, z, P.WALL4 if y == top + 2 + drum - 1 else P.WALL1)
	var dome_h := R * 0.9
	for x in range(xc - int(R), xc + int(R) + 1):
		for z in range(zc - int(R), zc + int(R) + 1):
			var d := sqrt(float((x - xc) * (x - xc) + (z - zc) * (z - zc))) / R
			if d > 1.0:
				continue
			var hh := int(sqrt(1.0 - d * d) * dome_h)
			var y0 := top + 2 + drum
			for y in range(maxi(y0, y0 + hh - 3), y0 + hh + 1):
				var band := absi(y - (y0 + int(dome_h * 0.35))) <= 1
				sv(x, y, z, P.WALL4 if band else P.WALL1)
	var ftop := top + 2 + drum + int(dome_h)
	box3(xc, ftop, zc, xc, ftop + 5, zc, P.GOLD)
	fac_particles.append([Vector3(xc + 4, ftop, zc) * VS, "steam_vent"])
	var sides := _sides(x0, z0, x1, z1)
	var front: Array = sides[1]
	var uc: int = front[3] / 2
	var door := _fac_doorway(front, uc, P.WALL4)
	_fac_sign(front, uc, 15, 7, P.WALL4, P.WHITE, "BATHHOUSE")
	_fac_hanging_sign(front, uc + 16, P.WHITE, [
		".w..w..",
		"..w..w.",
		".w..w..",
		"bbbbbbb",
		".bbbbb.",
		"..bbb..",
	], {"w": P.WALL4, "b": P.SHUTTER0})
	for si in 4:
		_fac_windows(sides[si], 6, 10, uc - 10 if si == 1 else -1, uc + 10 if si == 1 else -1, P.SHUTTER1)
	_fac_glow_windows(x0, z0, x1, z1, top)
	# Folded towels and buckets outside the door
	var bo: Vector3i = front[0]
	var ba: Vector3i = front[1]
	var bn: Vector3i = front[2]
	for k in range(9, 13):
		var tw := fp(bo, ba, bn, uc + k, 0, 2)
		box3(tw.x, 1, tw.z, tw.x, 2 + posmod(k, 2), tw.z, [P.WHITE, P.WALL4][posmod(k, 2)])
	var bk := fp(bo, ba, bn, uc - 11, 0, 2)
	box3(bk.x, 1, bk.z, bk.x + 1, 2, bk.z + 1, P.WOOD)
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
					"label": "sit in the warm water", "face": face,
					"where": "bath", "soak": true})
	for e in [[px0 + 10, pz0 + 2, Vector3(0, 0, 1)], [px1 - 8, pz1 - 2, Vector3(0, 0, -1)]]:
		extras.append({"pos": _mp(e[0], 0, e[1]), "face": e[2], "pose": "soak", "where": "bath"})
		_remove_spot("bath_seat_%d_%d" % [e[0], e[1]])
	fac_particles.append([_mp(xc, 2, zc), "steam_pool"])
	interact_spots.append({"id": "bath_steam", "kind": "look", "pos": _mp(xc, 0, pz1),
			"label": "breathe in the steam", "where": "bath"})
	# A little fountain in the middle of the pool
	box3(xc - 1, 1, zc - 1, xc + 1, 3, zc + 1, P.WHITE)
	box3(xc, 4, zc, xc, 5, zc, P.WALL4)
	sv(xc, 6, zc, P.WATER)
	fac_particles.append([_mp(xc, 6, zc), "fountain"])
	# Columns on the pool's corners (on the rim, out of the way), benches along the
	# walls, towels, plants
	for cx in [px0, px1]:
		for cz in [pz0, pz1]:
			box3(cx - 1, 1, cz - 1, cx + 1, top - 1, cz + 1, P.WALL0)
			box3(cx - 2, top - 2, cz - 2, cx + 2, top - 1, cz + 2, P.STONE)
	for z in range(z0 + 6, z1 - 5, 6):
		for bx in [x0 + 2, x1 - 2]:
			var face := Vector3(1, 0, 0) if bx < xc else Vector3(-1, 0, 0)
			_fac_stool(bx, z, face, "bath", "sit on the bench", P.WOOD)
			box3(bx, 1, z - 1, bx, 2, z + 1, P.WOOD)
	for x in range(x0 + 8, x1 - 7, 10):
		box3(x, 1, z0 + 1, x + 3, 6, z0 + 2, P.WOOD)
		for y in [2, 4, 6]:
			box3(x, y, z0 + 1, x + 3, y, z0 + 1, [P.WHITE, P.WALL4, P.CLOTH1, P.AWN1][posmod(x + y, 4)])
		box3(x + 5, 1, z0 + 2, x + 6, 2, z0 + 3, P.WOOD)          # a bucket
		sv(x + 5, 2, z0 + 2, P.IRON)
	for pl in [Vector2i(x0 + 3, z1 - 3), Vector2i(x1 - 3, z1 - 3), Vector2i(x0 + 3, z0 + 3), Vector2i(x1 - 3, z0 + 3)]:
		box3(pl.x - 1, 1, pl.y - 1, pl.x + 1, 2, pl.y + 1, P.TERRA)
		box3(pl.x - 2, 3, pl.y - 2, pl.x + 2, 6, pl.y + 2, P.LEAF)
	for l: Vector2i in [Vector2i(xc - 12, zc), Vector2i(xc + 12, zc), Vector2i(xc, z1 - 6)]:
		_fac_lantern(l.x, l.y, top, 15)
	# Tamsin keeps to the towel shelves, so she's easy to find
	var loop := [_mp(x0 + 12, 0, z0 + 5), _mp(x0 + 30, 0, z0 + 5)]
	cast_spots["tamsin"] = {"pos": loop[0], "face": Vector3(0, 0, 1), "where": "bath", "loop": loop}
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
	# Round brass gears and a pipe on the side wall
	for i in 2:
		var gz := z0 + 5 + i * 6
		for dz in range(-2, 3):
			for dy in range(-2, 3):
				var r2 := dz * dz + dy * dy
				if r2 >= 3 and r2 <= 6 or r2 == 0:
					sv(x1 - 1, 9 + dy, gz + dz, P.BRASS)
	box3(x1 - 1, 13, z0 + 1, x1 - 1, 13, z1 - 1, P.IRON)
	# Hammers and spanners hanging on the other wall
	for k in range(4):
		var tz := z0 + 7 + k * 2
		box3(x0 + 1, 8, tz, x0 + 1, 11, tz, P.WOOD_DARK)
		box3(x0 + 1, 11, tz - (k % 2), x0 + 1, 11, tz + 1 - (k % 2), P.IRON)
	# An anvil against the wall by the forge, and a side bench with a pump in pieces
	# (the shed is small: everything keeps to the walls)
	box3(x0 + 1, 1, z0 + 7, x0 + 2, 2, z0 + 7, P.IRON)
	box3(x0 + 1, 3, z0 + 6, x0 + 2, 3, z0 + 8, P.IRON)
	box3(x1 - 3, 1, z0 + 1, x1 - 1, 3, z0 + 4, P.WOOD_DARK)
	box3(x1 - 3, 4, z0 + 2, x1 - 2, 4, z0 + 3, P.BRASS)
	origin = Vector3i.ZERO
	_fac_light(x0 + 3, h + 6, z0 + 4, Color(1.0, 0.5, 0.2), 0.8, 3.5)
	_fac_light(cx, h + 11, z1 - 4, Color(1.0, 0.85, 0.65), 1.0, 6.0)
	# His name over the front, so you know whose shed it is
	fac_signs.append([Vector3(cx, h + 16.5, z0 - 3.2) * VS, Vector3(0, 0, -1), "BRAM'S WORKSHOP"])
	interact_spots.append({"id": "workshop_bench", "kind": "look", "pos": _mp(x1 - 2, h, z0 + 2),
			"label": "tinker with the pump on the side bench", "where": "workshop"})
	cast_spots["bram"] = {"pos": _mp(x0 + 2, h, z0 - 4), "face": Vector3(0, 0, -1), "where": "workshop"}
	# Its front is open, so the space just in front counts as inside it too
	facilities["workshop"] = {"name": "Bram's workshop", "rect": Rect2i(x0, z0 - 6, x1 - x0 + 1, z1 - z0 + 7), "door_out": _mp(cx, h, z0 - 2),
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
	var a: Vector3 = g["door_out"] + Vector3(0.4, 0, -1.8)
	var b: Vector3 = t["door_out"] + Vector3(-0.4, 0, -1.8)
	cast_spots["pip"] = {"pos": a, "face": Vector3(1, 0, 0), "where": "south_street",
			"loop": [a, a.lerp(b, 0.5) + Vector3(0, 0, -0.7), b, a.lerp(b, 0.5) + Vector3(0, 0, -2.0)]}


## Pale sandstone in courses, darker at the foot.
func _bath_wall(x: int, y: int, z: int) -> int:
	if y <= 3:
		return P.STONE2
	if y == 16 or y == 17:
		return P.WALL4 if posmod(x + z + y, 2) == 0 else P.SHUTTER0   # a two-row checker of blues
	return P.WALL1


func _bath_floor(x: int, z: int) -> int:
	return P.WHITE if posmod(x + z, 2) == 0 else P.WALL4
