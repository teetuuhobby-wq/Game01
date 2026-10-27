extends "res://world/cast.gd"
## THE WORLD, layer 12 of 12: where people can stand.
## The walk map (floor height and head room for every deck column), standing checks,
## the camera's line-of-sight test, and route finding for the test bot.


## For every deck column: the floor height people stand on (blocks; stairs use their
## step height) and whether there's head room above it (nothing in the next 10 blocks,
## 2 m: a person is 1.8 m, plus a hat).
func _build_walk_map() -> void:
	walk_floor.resize(NX * NZ)
	walk_ok.resize(NX * NZ)
	walk_ok.fill(0)
	for x in range(-RXV, RXV + 1):
		for z in range(-RZV, RZV + 1):
			var l := level_at(x, z)
			if l < 0:
				continue
			var f: int = stair_top.get(Vector2i(x, z), LEVELS[l][1])
			var ok := gv(x, f, z) != 0
			if ok:
				for y in range(f + 1, f + 11):
					if gv(x, y, z) != 0 and not soft.has(Vector3i(x, y, z)):
						ok = false
						break
			var i := (z - GZ0) * NX + (x - GX0)
			walk_floor[i] = f
			walk_ok[i] = 1 if ok else 0


func _col(p: Vector3) -> int:
	var x := roundi(p.x / VS)
	var z := roundi(p.z / VS)
	if x < GX0 or x >= GX0 + NX or z < GZ0 or z >= GZ0 + NZ:
		return -1
	return (z - GZ0) * NX + (x - GX0)


## Floor height (blocks) under a point on the city (metres), or -1 if nobody can stand there.
func floor_at(p: Vector3) -> int:
	var i := _col(p)
	if i < 0 or walk_ok[i] == 0:
		return -1
	return walk_floor[i]


## True if a person fits here with room to spare: every column within 2 blocks
## (0.4 m) is standable, with no step of more than 2 blocks from this one.
## (A person is about 0.5 m wide, so their corners can touch columns 2 blocks away.)
func _roomy(i: int) -> bool:
	if walk_ok[i] == 0:
		return false
	var f := walk_floor[i]
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var j := i + dz * NX + dx
			if walk_ok[j] == 0 or absi(walk_floor[j] - f) > 2:
				return false
	return true


## How far along the line from a to b (on the city, metres) you get before hitting a
## block: 0..1, where 1 means the way is clear. The camera uses it to avoid walls.
func first_hit(a: Vector3, b: Vector3) -> float:
	var n := int(a.distance_to(b) / (VS * 0.5))
	if n < 4:
		return 1.0
	for i in range(3, n + 1):
		var p := a.lerp(b, float(i) / n)
		if gv(roundi(p.x / VS), roundi(p.y / VS), roundi(p.z / VS)) != 0:
			return float(i - 1) / n
	return 1.0


## Shortest walkable route between two points on the city (metres), for the test bot.
## Empty if there is none.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := _col(from)
	var goal := _col(to)
	var pts := PackedVector3Array()
	if start < 0 or goal < 0:
		return pts
	var prev := PackedInt32Array()
	prev.resize(NX * NZ)
	prev.fill(-1)
	prev[start] = start
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		if i == goal:
			break
		for d in [1, -1, NX, -NX]:
			var j: int = i + d
			if prev[j] != -1 or not _roomy(j) or absi(walk_floor[j] - walk_floor[i]) > 2:
				continue
			prev[j] = i
			queue.append(j)
	if prev[goal] == -1:
		return pts
	var i := goal
	while i != start:
		pts.append(Vector3((i % NX + GX0) * VS, (walk_floor[i] + 0.5) * VS, (i / NX + GZ0) * VS))
		i = prev[i]
	pts.reverse()
	return pts
