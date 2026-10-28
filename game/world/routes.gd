extends "res://world/walk_map.gd"
## THE WORLD, layer 14 of 15: routes for the residents (town_life.gd sends them along).
## A route search that does a little each frame (ROUTE_CELLS_PER_FRAME columns of the
## walk map), so the game never stutters while someone works out their way. It heads
## for the goal first and only goes round when it must, so most routes take a frame
## or two. Residents are slimmer than you (find_path in walk_map.gd is for your size):
## they fit behind the bar and between the stalls, and near where a trip starts or
## ends they squeeze through tight gaps (behind a counter).

const ROUTE_CELLS_PER_FRAME := 2500    # how much of the walk map the route search looks at each frame
const SQUEEZE := 20                    # blocks: this close to where a trip starts or ends (behind a counter, a bar),
                                       # residents squeeze through tight gaps; elsewhere they keep to roomy streets

var _r_start := -1
var _r_goal := -1
var _r_prev := PackedInt32Array()   # for each column, the one the search came from (-1 = not reached)
var _r_near := []                   # columns to look at next (heading toward the goal)
var _r_far := []                    # columns one detour further round


## Starts a route search from one point on the city to another (metres).
func route_begin(from: Vector3, to: Vector3) -> void:
	_r_start = _col(from)
	_r_goal = _col(to)
	if _r_prev.size() != NX * NZ:
		_r_prev.resize(NX * NZ)
	_r_prev.fill(-1)
	_r_near = []
	_r_far = []
	if _r_start >= 0 and _r_goal >= 0:
		_r_prev[_r_start] = _r_start
		_r_near.append(_r_start)


## Looks at up to `budget` more columns: 1 = found the way, -1 = there's none, 0 = not yet.
func route_step(budget: int) -> int:
	if _r_start < 0 or _r_goal < 0:
		return -1
	var gx := _r_goal % NX
	var gz := _r_goal / NX
	while budget > 0:
		if _r_near.is_empty():
			if _r_far.is_empty():
				return -1
			var swap := _r_near
			_r_near = _r_far
			_r_far = swap
		var i: int = _r_near.pop_back()
		if i == _r_goal:
			return 1
		budget -= 1
		var x := i % NX
		var z := i / NX
		# (Never off the map's edge: the column "past" the last one is the next row's first)
		if x < NX - 1:
			_route_try(i, i + 1, x < gx)
		if x > 0:
			_route_try(i, i - 1, x > gx)
		if z < NZ - 1:
			_route_try(i, i + NX, z < gz)
		if z > 0:
			_route_try(i, i - NX, z > gz)
	return 0


## The whole search in one go (tests, and checking routes when the town is built).
func route_now(from: Vector3, to: Vector3) -> PackedVector3Array:
	route_begin(from, to)
	var r := route_step(NX * NZ)
	return route_points() if r > 0 else PackedVector3Array()


func _route_try(i: int, j: int, closer: bool) -> void:
	if _r_prev[j] != -1 or walk_ok[j] == 0 or absi(walk_floor[j] - walk_floor[i]) > 2:
		return
	if not _snug(j) and not _cols_near(j, _r_goal) and not _cols_near(j, _r_start):
		return
	_r_prev[j] = i
	if closer:
		_r_near.append(j)
	else:
		_r_far.append(j)


## True if a slim person (a resident) fits here: every column right round it is
## standable, with no big step. (Never on the map's edge row or column.)
func _snug(i: int) -> bool:
	var x := i % NX
	var z := i / NX
	if x == 0 or x == NX - 1 or z == 0 or z == NZ - 1:
		return false
	var f := walk_floor[i]
	for dz in range(-1, 2):
		var row := i + dz * NX
		for dx in range(-1, 2):
			if walk_ok[row + dx] == 0 or absi(walk_floor[row + dx] - f) > 2:
				return false
	return true


## Within SQUEEZE columns of each other (near the start and the end, a tight spot is fine).
func _cols_near(a: int, b: int) -> bool:
	return absi(a % NX - b % NX) <= SQUEEZE and absi(a / NX - b / NX) <= SQUEEZE


func _col_pos(i: int) -> Vector3:
	return Vector3((i % NX + GX0) * VS, (walk_floor[i] + 0.5) * VS, (i / NX + GZ0) * VS)


## The route just found, as points to walk between: only where it turns, so people
## walk in smooth straight lines, not tiny zig-zags along the grid.
func route_points() -> PackedVector3Array:
	var cells := PackedInt32Array()
	var i := _r_goal
	while i != _r_start:
		cells.append(i)
		i = _r_prev[i]
	cells.append(_r_start)
	cells.reverse()
	var pts := PackedVector3Array()
	pts.append(_col_pos(cells[0]))
	var a := 0
	while a < cells.size() - 1:
		var b := mini(a + 12, cells.size() - 1)
		while b > a + 1 and not _straight(cells[a], cells[b]):
			b -= 1
		pts.append(_col_pos(cells[b]))
		a = b
	return pts


## True if a slim person walking straight from column a to column b stays on good ground.
func _straight(a: int, b: int) -> bool:
	var ax := a % NX
	var az := a / NX
	var bx := b % NX
	var bz := b / NX
	var n := maxi(absi(bx - ax), absi(bz - az)) * 2
	for s in range(1, n):
		var t := float(s) / n
		var j := roundi(lerpf(az, bz, t)) * NX + roundi(lerpf(ax, bx, t))
		if walk_ok[j] == 0 or absi(walk_floor[j] - roundi(lerpf(walk_floor[a], walk_floor[b], t))) > 2:
			return false
		if not _snug(j) and not _cols_near(j, _r_goal) and not _cols_near(j, _r_start):
			return false
	return true
