extends "res://world/city.gd"
## THE WORLD, layer 5 of 10: the places Mira's errand uses.
## Bram's workshop (with the spare valve) and the rain-catcher.


const WORKSHOP := Rect2i(95, 12, 20, 16)    # blocks: Bram's workshop, middle terrace, east


const CATCHER := Rect2i(-235, -30, 16, 16)  # blocks: the rain-catcher, outer ring, far west (homes side)


func _build_errand_sites() -> void:
	# Keep houses and trees off both sites
	for r: Rect2i in [WORKSHOP, CATCHER]:
		for x in range(_cell(r.position.x) - 1, _cell(r.end.x) + 2):
			for z in range(_cell(r.position.y) - 1, _cell(r.end.y) + 2):
				occ[Vector2i(x, z)] = true
	_build_workshop()
	_build_catcher()


## Bram's workshop: an open-fronted timber shed with a workbench, tools and crates.
## The spare valve sits on the bench as its own mesh, so it can be picked up.
func _build_workshop() -> void:
	var x0 := WORKSHOP.position.x
	var z0 := WORKSHOP.position.y
	var x1 := WORKSHOP.end.x - 1
	var z1 := WORKSHOP.end.y - 1
	var cx := (x0 + x1) / 2
	var h: int = LEVELS[level_at(cx, (z0 + z1) / 2)][1]
	origin = Vector3i(0, h, 0)
	for y in range(1, 15):
		var p := P.STONE2 if y <= 2 else (P.WOOD_DARK if posmod(y, 4) == 0 else P.WOOD)
		for x in range(x0, x1 + 1):
			sv(x, y, z1, p)
		for z in range(z0, z1):
			sv(x0, y, z, p)
			sv(x1, y, z, p)
	# Lean-to tiled roof, high at the back, hanging out over the open front
	for z in range(z0 - 3, z1 + 2):
		var y := 14 + int((z - (z0 - 3)) * 4 / float(z1 - z0 + 5))
		for x in range(x0 - 1, x1 + 2):
			sv(x, y, z, P.TERRA if posmod(z, 2) == 0 else P.TERRA2)
	# A yellow sign board over the front, with an iron cog (above head height: 2.2 m up)
	box3(cx - 4, 11, z0 - 1, cx + 3, 13, z0 - 1, P.AWN1)
	box3(cx - 1, 11, z0 - 2, cx, 13, z0 - 2, P.IRON)
	# Workbench along the back, tools on the wall, crates, a lantern
	box3(x0 + 3, 1, z1 - 4, x1 - 3, 3, z1 - 1, P.WOOD_DARK)
	box3(x0 + 2, 4, z1 - 5, x1 - 2, 4, z1 - 1, P.WOOD)
	for i in 5:
		box3(x0 + 4 + i * 3, 7, z1 - 1, x0 + 4 + i * 3, 9 + i % 2, z1 - 1, P.IRON)
	box3(x1 - 4, 1, z0 + 1, x1 - 2, 3, z0 + 3, P.WOOD_DARK)
	box3(x1 - 4, 4, z0 + 1, x1 - 3, 5, z0 + 2, P.WOOD)
	sv(cx, 12, z1 - 3, P.GLOW)
	origin = Vector3i.ZERO
	valve = _mi(_valve_mesh())
	valve.position = Vector3(cx, h + 5.5, z1 - 3) * VS
	city.add_child(valve)
	workshop_use = valve.position
	workshop_stand = Vector3(cx, h, z1 - 8) * VS


## The rain-catcher: a copper funnel on timber legs, piped down into a barrel.
## The pipe has a gap where the jammed valve was taken out.
func _build_catcher() -> void:
	var cx := CATCHER.position.x + CATCHER.size.x / 2
	var cz := CATCHER.position.y + CATCHER.size.y / 2
	for d: Vector2i in [Vector2i(-5, -5), Vector2i(5, -5), Vector2i(-5, 5), Vector2i(5, 5)]:
		box3(cx + d.x, 1, cz + d.y, cx + d.x, 19, cz + d.y, P.WOOD_DARK)
	for y in range(18, 27):
		var r := 2.5 + (y - 18) * 0.9
		for dx in range(-11, 12):
			for dz in range(-11, 12):
				var d := sqrt(float(dx * dx + dz * dz))
				if d <= r and d > r - 1.3:
					sv(cx + dx, y, cz + dz, P.GOLD if y == 26 else P.BRASS)
	for y in range(5, 18):
		if y < 10 or y > 12:
			sv(cx, y, cz, P.IRON)
	box3(cx - 1, 9, cz, cx + 1, 9, cz, P.IRON)
	box3(cx - 1, 13, cz, cx + 1, 13, cz, P.IRON)
	for x in range(cx, cx + 6):
		sv(x, 5, cz, P.IRON)
	for y in range(1, 8):
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				if dx * dx + dz * dz <= 10:
					sv(cx + 8 + dx, y, cz + dz, P.IRON if y == 2 or y == 6 else P.WOOD)
	catcher_use = Vector3(cx, 11, cz) * VS
	catcher_splash = Vector3(cx + 8, 8, cz) * VS
	catcher_stand = Vector3(cx - 2, 0, cz - 3) * VS
	var wp := PackedVector3Array()
	var wc := PackedColorArray()
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			if dx * dx + dz * dz <= 56:
				wp.append(Vector3(dx, 0, dz) * VS)
				wc.append(PAL[P.WATER] * (0.95 + 0.1 * _h(dx, 3, dz)))
	catcher_water = _mi(_cubes(wp, wc, VS, true))
	catcher_water.position = Vector3(cx, 25, cz) * VS
	catcher_water.visible = false
	city.add_child(catcher_water)


## A brass valve with a gold hand-wheel on top (about 0.6 m across).
func _valve_mesh() -> ArrayMesh:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for x in 2:
		for y in 2:
			for z in 2:
				pts.append(Vector3(x - 0.5, y - 0.5, z - 0.5) * VS)
				cols.append(PAL[P.BRASS])
	for x in 4:
		for z in 4:
			if x == 0 or x == 3 or z == 0 or z == 3:
				pts.append(Vector3(x - 1.5, 1.5, z - 1.5) * VS)
				cols.append(PAL[P.GOLD])
	return _cubes(pts, cols, VS, true)
