extends Node3D
## THE WORLD, layer 1 of 15: the block grid everything is built from.
## Shared numbers and state, the colour palette, materials, turning blocks into
## meshes (only the faces you can see), placing blocks (sv, gv, box3, fp...), and
## the deck's shape (its edge, the terraces, where the legs attach).
## Each layer extends the one before; see docs/ARCHITECTURE.md.


## THE WORLD of the first toy: the desert, the walking city on its legs, and its people.
## Built from code at start-up (the terraced look test, turned into a place you can walk).
## Also knows where people can stand (the walk map) and where the errand happens.

signal stomped(at: Vector3)  ## a giant foot just landed (global position)


const T := preload("res://tuning.gd")


# --- Tuning (safe to tweak) ---
const CITY_SPEED: float = T.CITY_SPEED   # how fast the city walks (set in tuning.gd)


const STEP_LENGTH := 18.0    # how far each foot moves per step


const STEP_LIFT := 6.0       # how high feet lift


const CITY_HEIGHT := 30.0    # deck height above the ground


const THIGH_LEN := 16.0


const SHIN_LEN := 36.0


const LEG_REACH := 30.0      # how far out to the side the feet land


const WALKERS := 18          # residents strolling round the plaza


const PROMENADE_WALKERS := [0, 22, 10]   # residents walking along each terrace's edge (deck, middle, top)


const SEED := 7


const LOOP_STRIDES := 6      # the desert repeats after this many strides, so the walk never ends


const LOOP := LOOP_STRIDES * 2.0 * STEP_LENGTH


const NOTICE: float = T.NOTICE_DISTANCE


# --- Block grid for the city (all in blocks, 5 per metre) ---
const RES := 5


const VS := 1.0 / RES


const RXV := 300             # deck half-length (60 m)


const RZV := 220             # deck half-width (44 m)


const GX0 := -330


const GZ0 := -255


const GY0 := -60


const NX := 661


const NZ := 511


const NY := 290


# --- Terraces: [how far out the terrace reaches (1 = deck edge), floor height in blocks] ---
# The top and middle terraces keep their old size in metres; the outer ring is wide enough for the market.
const LEVELS := [[1.0, 0], [0.462, 30], [0.252, 60]]


const EDGE_GAP := 8          # blocks kept clear inside and outside each terrace edge (walkways)


# --- Plaza layout (on the top terrace) ---
const PLAZA_X := 20          # plaza centre, blocks along x from the city centre


const PARASOL_A0 := 0.3      # angle of the first of six parasols round the fountain


const YOUR_GAP := 4          # the gap between parasols where you stand


enum P { EMPTY, PAVE, PAVE2, PLAZA, MORTAR, STONE, STONE2, HULL, HULL2, BRASS, WOOD, WOOD_DARK,
		TERRA, TERRA2, TERRA3, WALL0, WALL1, WALL2, WALL3, WALL4, SHUTTER0, SHUTTER1, GLASS,
		LEAF, LEAF2, CYPRESS, TRUNK, WATER, RED, PINK, PURPLE, AWN0, AWN1, AWN2, WHITE,
		IVY, GOLD, FLAG, IRON, CLOTH0, CLOTH1, CLOTH2, GLOW, WIN_GLOW }


const C_GLOW := Color(1.0, 0.66, 0.36)


const MARKET_Z0 := 10                     # the market fills the outer ring north of this


var PAL := []


var grid := PackedByteArray()


var filled := PackedInt32Array()


var occ := {}               # metre cells already used on the deck


var lvl := PackedByteArray()  # terrace number of each deck column (255 = off the deck)


var origin := Vector3i.ZERO   # added to everything sv/gv/clv place (set while building on a terrace)


var plaza_c := Vector3.ZERO   # plaza centre in metres, on the city


var promenaders := []


var streets := {}            # metre cells kept clear for the main streets and stairs


var mat_voxel: StandardMaterial3D


var mat_glow: StandardMaterial3D


var rng := RandomNumberGenerator.new()


var noise := FastNoiseLite.new()


var city: Node3D


var player: Node3D            # you (set by main.gd); neighbours stop to look at you


var camera: Camera3D          # set by main.gd: people right in front of it are hidden


var env: Environment          # the light and colour settings (changed by mood.gd)


var sun: DirectionalLight3D


var sky_mat: ProceduralSkyMaterial


var you_spot := Vector3.ZERO  # where you start, on the city


var you_yaw := 0.0


var mira_spot := Vector3.ZERO


var stair_top := {}           # deck column -> height of the stair step there


var soft := {}                # blocks people can wade through (plaza flower beds)


var walk_floor := PackedInt32Array()  # floor height (blocks) of each deck column


var walk_ok := PackedByteArray()      # 1 if a person can stand there


var valve: MeshInstance3D     # the spare valve on Bram's bench


var workshop_use := Vector3.ZERO      # where the valve is (on the city, metres)


var workshop_stand := Vector3.ZERO    # a good spot to stand to pick it up


var catcher_use := Vector3.ZERO       # the empty valve slot on the rain-catcher


var catcher_stand := Vector3.ZERO


var catcher_water: MeshInstance3D     # water in the funnel, shown once it's fixed


var catcher_splash := Vector3.ZERO     # top of the rain barrel, where the water splashes


var walkers := []


var legs := []


var t := 2.0


var life_t := 0.0   # the people's own clock, for their bobbing and fidgeting: unlike t, it never jumps back when the walk loops


var paused := false


var people_view := INF   # metres: people further from the camera are hidden (quality.gd sets it on low)


var walk_rate := 1.0   # how fast the city walks (1 = normal, 0 = stopped); dusk eases it down


var kneel := 0.0       # 0 = standing tall, 1 = knelt down for the night


const KNEEL_DROP := 0.5   # how much lower the deck sits when fully knelt (share of its height)


## Starts the shared random numbers afresh for one part of the build (houses, market,
## people...), so changing one part never reshuffles another.
func _seed(part: String) -> void:
	rng.seed = hash("%d:%s" % [SEED, part])


func _init_palette() -> void:
	PAL.resize(P.size())
	PAL[P.EMPTY] = Color.BLACK
	PAL[P.PAVE] = Color(0.80, 0.76, 0.68)
	PAL[P.PAVE2] = Color(0.73, 0.68, 0.59)
	PAL[P.PLAZA] = Color(0.87, 0.81, 0.69)
	PAL[P.MORTAR] = Color(0.64, 0.60, 0.53)
	PAL[P.STONE] = Color(0.80, 0.72, 0.60)
	PAL[P.STONE2] = Color(0.66, 0.59, 0.50)
	PAL[P.HULL] = Color(0.27, 0.24, 0.22)
	PAL[P.HULL2] = Color(0.34, 0.30, 0.27)
	PAL[P.BRASS] = Color(0.80, 0.62, 0.30)
	PAL[P.WOOD] = Color(0.52, 0.34, 0.20)
	PAL[P.WOOD_DARK] = Color(0.36, 0.24, 0.15)
	PAL[P.TERRA] = Color(0.80, 0.40, 0.23)
	PAL[P.TERRA2] = Color(0.71, 0.32, 0.19)
	PAL[P.TERRA3] = Color(0.58, 0.26, 0.16)
	PAL[P.WALL0] = Color(0.95, 0.92, 0.85)
	PAL[P.WALL1] = Color(0.97, 0.96, 0.93)
	PAL[P.WALL2] = Color(0.95, 0.84, 0.63)
	PAL[P.WALL3] = Color(0.94, 0.79, 0.73)
	PAL[P.WALL4] = Color(0.80, 0.87, 0.93)
	PAL[P.SHUTTER0] = Color(0.20, 0.42, 0.70)
	PAL[P.SHUTTER1] = Color(0.18, 0.56, 0.56)
	PAL[P.GLASS] = Color(0.22, 0.26, 0.32)
	PAL[P.LEAF] = Color(0.44, 0.58, 0.29)
	PAL[P.LEAF2] = Color(0.32, 0.47, 0.22)
	PAL[P.CYPRESS] = Color(0.20, 0.36, 0.22)
	PAL[P.TRUNK] = Color(0.40, 0.28, 0.18)
	PAL[P.WATER] = Color(0.38, 0.66, 0.82)
	PAL[P.RED] = Color(0.88, 0.22, 0.25)
	PAL[P.PINK] = Color(0.94, 0.54, 0.68)
	PAL[P.PURPLE] = Color(0.58, 0.44, 0.82)
	PAL[P.AWN0] = Color(0.82, 0.26, 0.22)
	PAL[P.AWN1] = Color(0.94, 0.74, 0.26)
	PAL[P.AWN2] = Color(0.26, 0.52, 0.76)
	PAL[P.WHITE] = Color(0.97, 0.95, 0.89)
	PAL[P.IVY] = Color(0.30, 0.50, 0.24)
	PAL[P.GOLD] = Color(0.96, 0.78, 0.30)
	PAL[P.FLAG] = Color(0.84, 0.18, 0.16)
	PAL[P.IRON] = Color(0.20, 0.19, 0.18)
	PAL[P.CLOTH0] = Color(0.96, 0.96, 0.93)
	PAL[P.CLOTH1] = Color(0.88, 0.42, 0.36)
	PAL[P.CLOTH2] = Color(0.42, 0.62, 0.84)
	PAL[P.GLOW] = C_GLOW
	PAL[P.WIN_GLOW] = Color(1.0, 0.80, 0.52)


func _make_materials() -> void:
	mat_voxel = StandardMaterial3D.new()
	mat_voxel.vertex_color_use_as_albedo = true
	mat_voxel.vertex_color_is_srgb = true
	mat_voxel.roughness = 0.85
	mat_glow = mat_voxel.duplicate()
	mat_glow.emission_enabled = true
	mat_glow.emission = C_GLOW
	mat_glow.emission_energy_multiplier = 1.2


func jitter(c: Color, amt := 0.04) -> Color:
	var j := rng.randf_range(-amt, amt)
	return Color(clampf(c.r + j, 0, 1), clampf(c.g + j, 0, 1), clampf(c.b + j, 0, 1))


## Cheap repeatable 0..1 noise per block, so colours vary without randomness drift.
func _h(x: int, y: int, z: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 1023) / 1023.0


## Collects square faces for one mesh surface. Blocks are drawn as meshes holding
## only the faces you can see, which is far fewer triangles than a box per block.
class Faces:
	## Face directions: +x, -x, +y, -y, +z, -z.
	const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
			Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	## Corners of each face of a unit box centred on zero, clockwise seen from outside.
	static var corners := _make_corners()
	static var indices := PackedInt32Array()

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()

	static func _make_corners() -> Array[PackedVector3Array]:
		var out: Array[PackedVector3Array] = []
		for n in DIRS:
			var nv := Vector3(n)
			var u := Vector3(0, 1, 0) if n.x != 0 else Vector3(1, 0, 0)
			var v := Vector3(0, 1, 0) if n.z != 0 else Vector3(0, 0, 1)
			var q := PackedVector3Array([(nv - u - v) * 0.5, (nv - u + v) * 0.5, (nv + u + v) * 0.5, (nv + u - v) * 0.5])
			if (q[1] - q[0]).cross(q[2] - q[0]).dot(nv) > 0.0:
				q.reverse()  # Godot draws the clockwise side
			out.append(q)
		return out

	## One face (direction d) of a box with centre c and the given size.
	func box_face(c: Vector3, size: Vector3, d: int, col: Color) -> void:
		var q := corners[d]
		var n := Vector3(DIRS[d])
		for k in 4:
			verts.append(c + q[k] * size)
			norms.append(n)
			cols.append(col)

	func count() -> int:
		return verts.size() / 4

	## Adds the collected faces to a mesh as one surface with the given material.
	func add_to(mesh: ArrayMesh, mat: Material) -> void:
		var n := count()
		if n == 0:
			return
		if indices.size() < n * 6:
			var have := indices.size() / 6
			indices.resize(n * 6)
			for f in range(have, n):
				var k := f * 4
				var j := f * 6
				indices[j] = k
				indices[j + 1] = k + 1
				indices[j + 2] = k + 2
				indices[j + 3] = k
				indices[j + 4] = k + 2
				indices[j + 5] = k + 3
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = indices.slice(0, n * 6)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## A mesh from a list of equal cubes (centres and colours). With cull on, faces
## pressed against a neighbouring cube are left out; only use that when the cubes
## sit on a grid of their own size.
func _cubes(pts: PackedVector3Array, cols: PackedColorArray, size: float, cull := false) -> ArrayMesh:
	var cells := {}
	if cull:
		for p in pts:
			cells[Vector3i((p * (2.0 / size)).round())] = true
	var f := Faces.new()
	var sz := Vector3.ONE * size
	for i in pts.size():
		var key := Vector3i((pts[i] * (2.0 / size)).round())
		for d in 6:
			if not (cull and cells.has(key + Faces.DIRS[d] * 2)):
				f.box_face(pts[i], sz, d, cols[i])
	var mesh := ArrayMesh.new()
	f.add_to(mesh, mat_voxel)
	return mesh


func _mi(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func sv(x: int, y: int, z: int, p: int) -> void:
	x += origin.x
	y += origin.y
	z += origin.z
	if x < GX0 or x >= GX0 + NX or z < GZ0 or z >= GZ0 + NZ or y < GY0 or y >= GY0 + NY:
		return
	var i := ((y - GY0) * NZ + (z - GZ0)) * NX + (x - GX0)
	if grid[i] == 0:
		filled.append(i)
	grid[i] = p


func gv(x: int, y: int, z: int) -> int:
	x += origin.x
	y += origin.y
	z += origin.z
	if x < GX0 or x >= GX0 + NX or z < GZ0 or z >= GZ0 + NZ or y < GY0 or y >= GY0 + NY:
		return 0
	return grid[((y - GY0) * NZ + (z - GZ0)) * NX + (x - GX0)]


## Terrace number of the deck column at block x, z (-1 = off the deck).
func level_at(x: int, z: int) -> int:
	if x < GX0 or x >= GX0 + NX or z < GZ0 or z >= GZ0 + NZ:
		return -1
	var l := lvl[(z - GZ0) * NX + (x - GX0)]
	return -1 if l == 255 else l


## True if the whole rectangle (blocks), widened by EDGE_GAP, sits on one terrace;
## returns that terrace, or -1.
func level_of_area(x0: int, z0: int, x1: int, z1: int) -> int:
	var l := level_at(x0 - EDGE_GAP, z0 - EDGE_GAP)
	for c in [Vector2i(x1 + EDGE_GAP, z0 - EDGE_GAP), Vector2i(x0 - EDGE_GAP, z1 + EDGE_GAP),
			Vector2i(x1 + EDGE_GAP, z1 + EDGE_GAP), Vector2i((x0 + x1) / 2, (z0 + z1) / 2)]:
		if level_at(c.x, c.y) != l:
			return -1
	return l


func box3(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, p: int) -> void:
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				sv(x, y, z, p)


## The metre cell (as used by occ) holding block coordinate b. Rounds down, so
## negative coordinates land in the right cell too (plain / rounds toward zero).
func _cell(b: int) -> int:
	return floori(b / float(RES))


func svv(v: Vector3i, p: int) -> void:
	sv(v.x, v.y, v.z, p)


func clv(v: Vector3i) -> void:
	if gv(v.x, v.y, v.z) != 0:
		var w := v + origin
		grid[((w.y - GY0) * NZ + (w.z - GZ0)) * NX + (w.x - GX0)] = 0


## A point on a facade: u along the wall, y up, out away from the wall.
func fp(o: Vector3i, a: Vector3i, n: Vector3i, u: int, y: int, out: int) -> Vector3i:
	return o + a * u + n * out + Vector3i(0, y, 0)


## The four walls of a rectangle as [origin, along, outward, length], front (-z) first.
func _sides(x0: int, z0: int, x1: int, z1: int) -> Array:
	return [
		[Vector3i(x0, 0, z0), Vector3i(1, 0, 0), Vector3i(0, 0, -1), x1 - x0 + 1],
		[Vector3i(x1, 0, z1), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), x1 - x0 + 1],
		[Vector3i(x0, 0, z1), Vector3i(0, 0, -1), Vector3i(-1, 0, 0), z1 - z0 + 1],
		[Vector3i(x1, 0, z0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), z1 - z0 + 1],
	]


## Turns the grid into meshes holding only the faces you can see (a face pressed
## against another block is left out), cut into chunks the camera can skip.
func _emit_grid() -> void:
	const CHUNK := 64
	var nzc := ceili(NZ / float(CHUNK))
	var solid := {}   # chunk number -> Faces
	var glow := {}
	var sz := NX
	var sy := NX * NZ
	var size := Vector3.ONE * VS
	# A block that was cleared and filled again is listed twice; sorting puts the copies together.
	filled.sort()
	var prev := -1
	for i in filled:
		var p: int = grid[i]
		if p == 0 or i == prev:
			continue
		prev = i
		var x := i % NX
		var r := i / NX
		var z := r % NZ
		var y := r / NZ
		var bx := x + GX0
		var by := y + GY0
		var bz := z + GZ0
		var c: Color = PAL[p]
		var s := 0.93 + 0.12 * _h(bx, by, bz)
		c = Color(c.r * s, c.g * s, c.b * s)
		var o := Vector3(bx * VS, by * VS, bz * VS)
		var bucket := glow if p >= P.GLOW else solid
		var key := (x / CHUNK) * nzc + z / CHUNK
		if not bucket.has(key):
			bucket[key] = Faces.new()
		var f: Faces = bucket[key]
		if x == NX - 1 or grid[i + 1] == 0: f.box_face(o, size, 0, c)
		if x == 0 or grid[i - 1] == 0: f.box_face(o, size, 1, c)
		if y == NY - 1 or grid[i + sy] == 0: f.box_face(o, size, 2, c)
		if y == 0 or grid[i - sy] == 0: f.box_face(o, size, 3, c)
		if z == NZ - 1 or grid[i + sz] == 0: f.box_face(o, size, 4, c)
		if z == 0 or grid[i - sz] == 0: f.box_face(o, size, 5, c)
	var keys := solid.keys()
	for k in glow.keys():
		if not solid.has(k):
			keys.append(k)
	var faces := 0
	for k in keys:
		var mesh := ArrayMesh.new()
		for pair in [[solid, mat_voxel], [glow, mat_glow]]:
			if pair[0].has(k):
				var f: Faces = pair[0][k]
				f.add_to(mesh, pair[1])
				faces += f.count()
		city.add_child(_mi(mesh))
	print("city faces drawn: ", faces, " in ", keys.size(), " chunks")


## How far out a deck column is, squared: 1 on the deck's edge (a rounded rectangle, like the terraces).
func _e(x: float, z: float) -> float:
	return pow(_tq(x, z), 2.0)


func _hull_bottom(x: int, z: int) -> int:
	var e := _e(x, z)
	if e > 1.0:
		return 1
	return -6 - int(22.0 * sqrt(1.0 - e))


## How far out a point is for the terraces: 1 on a rounded rectangle the size of the deck.
func _tq(x: float, z: float) -> float:
	return pow(pow(absf(x) / RXV, 4.0) + pow(absf(z) / RZV, 4.0), 0.25)


## A point on a terrace-shaped rounded rectangle with half-sizes rx, rz, at angle a.
func _round_rect(rx: float, rz: float, a: float) -> Vector2:
	return Vector2(rx * signf(cos(a)) * sqrt(absf(cos(a))), rz * signf(sin(a)) * sqrt(absf(sin(a))))


## Which terrace each deck column belongs to, by how far out from the centre it is.
func _map_levels() -> void:
	lvl.resize(NX * NZ)
	lvl.fill(255)
	for x in range(-RXV, RXV + 1):
		for z in range(-RZV, RZV + 1):
			var e := _e(x, z)
			if e > 1.0:
				continue
			var q := _tq(x, z)
			var l := 0
			for i in range(1, LEVELS.size()):
				if q < LEVELS[i][0]:
					l = i
			lvl[(z - GZ0) * NX + (x - GX0)] = l


func _sphere(cx: int, cy: int, cz: int, r: float, p_main: int, p_band: int) -> void:
	var ri := int(ceil(r))
	for dx in range(-ri, ri + 1):
		for dy in range(-ri, ri + 1):
			for dz in range(-ri, ri + 1):
				var d := sqrt(float(dx * dx + dy * dy + dz * dz))
				if d <= r and d > r - 2.0:
					sv(cx + dx, cy + dy, cz + dz, p_band if absi(dy) <= 1 else p_main)


func _hip_positions() -> Array:
	# Just outside the deck's edge, so a leg swinging up to its knee never passes
	# through the streets (playtest 2: "the city legs clip through the walls")
	return [Vector3(43, -2, 46), Vector3(0, -2, 48.4), Vector3(-43, -2, 46),
			Vector3(43, -2, -46), Vector3(0, -2, -48.4), Vector3(-43, -2, -46)]


## Metres on the city for a block position (the centre of the block's top).
func _m(b: Vector3i) -> Vector3:
	return Vector3(b.x * VS, (b.y + 0.5) * VS, b.z * VS)
