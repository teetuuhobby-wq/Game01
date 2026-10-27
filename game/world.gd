extends Node3D
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
var paused := false


func _ready() -> void:
	rng.seed = SEED
	noise.seed = SEED
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	_init_palette()
	_make_materials()
	_make_world()
	_build_ground()
	_build_city()
	_build_legs()
	_add_residents()
	_build_walk_map()


# ---------- Setup ----------

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


func _make_world() -> void:
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.45, 0.66, 0.74)
	psm.sky_horizon_color = Color(0.98, 0.80, 0.62)
	psm.ground_horizon_color = Color(0.85, 0.64, 0.46)
	psm.ground_bottom_color = Color(0.40, 0.30, 0.25)
	var sky := Sky.new()
	sky.sky_material = psm

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.48, 0.40)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.96, 0.82, 0.66)
	env.fog_density = 0.001
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Low golden-hour sun from the camera's left, for long shadows.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -30, 0)
	sun.light_color = Color(1.0, 0.77, 0.54)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)



# ---------- Mesh helpers ----------

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


# ---------- Block grid ----------

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


# ---------- Ground ----------

## Noise that repeats every LOOP metres along x, so the desert tiles seamlessly.
func _pnoise(x: float, z: float, scale := 1.0) -> float:
	var a := TAU * x / LOOP
	var r := LOOP / TAU * scale
	return noise.get_noise_3d(cos(a) * r, sin(a) * r, z * scale)


func ground_hf(x: float, z: float) -> float:
	var h := 2.0 + _pnoise(x, z) * 1.5
	var az := absf(z)
	if az > 100.0:
		var m := smoothstep(100.0, 140.0, az)
		h += m * (6.0 + 12.0 * maxf(0.0, _pnoise(x, z + 600.0, 0.5)))
	return maxf(0.5, h)


## Ground surface height, matching how the one-metre ground blocks are built.
func ground_at(x: float, z: float) -> float:
	return maxf(1.0, roundf(ground_hf(roundf(x), roundf(z))))


func _ground_color(h: float) -> Color:
	if h <= 2.0:
		return Color(0.82, 0.70, 0.52)
	elif h <= 4.0:
		return Color(0.75, 0.60, 0.42)
	elif h <= 10.0:
		return Color(0.66, 0.47, 0.33) if int(h) % 2 == 0 else Color(0.71, 0.53, 0.37)
	return Color(0.48, 0.40, 0.34)


## A ground column's colour: banded by height, with a little noise.
func _ground_tone(x: float, z: float, h: float) -> Color:
	var c := _ground_color(h)
	var tint := _pnoise(x, z + 450.0, 2.0) * 0.05
	var k := 0.96 + 0.08 * _h(posmod(int(x), int(LOOP)), 0, int(z))
	return Color((c.r + tint) * k, (c.g + tint) * k, (c.b + tint) * k)


## Ground columns of one size on a regular grid: heights (0 = no column) and colours.
class Columns:
	var x0: float
	var z0: float
	var s: float
	var nx: int
	var nz: int
	var h := PackedFloat32Array()
	var col := PackedColorArray()

	func _init(x_start: float, z_start: float, size: float, count_x: int, count_z: int) -> void:
		x0 = x_start
		z0 = z_start
		s = size
		nx = count_x
		nz = count_z
		h.resize(nx * nz)
		col.resize(nx * nz)

	func height(ix: int, iz: int) -> float:
		if ix < 0 or ix >= nx or iz < 0 or iz >= nz:
			return 0.0
		return h[ix * nz + iz]

	## Top face plus the parts of each side that stand above the neighbour.
	## Bottoms are left out: the camera never looks up at the ground.
	func add_faces(chunks: Array, chunk_len: float) -> void:
		var sides := [[0, 1, 0], [1, -1, 0], [4, 0, 1], [5, 0, -1]]
		for ix in nx:
			var x := x0 + ix * s
			var f: Faces = chunks[int((x - x0) / chunk_len)]
			for iz in nz:
				var top := h[ix * nz + iz]
				if top <= 0.0:
					continue
				var z := z0 + iz * s
				var c := col[ix * nz + iz]
				f.box_face(Vector3(x, top * 0.5, z), Vector3(s, top, s), 2, c)
				for sd in sides:
					var nh := height(ix + sd[1], iz + sd[2])
					if nh < top:
						f.box_face(Vector3(x, (top + nh) * 0.5, z), Vector3(s, top - nh, s), sd[0], c)


func _build_ground() -> void:
	# One-metre columns. Everything here repeats every LOOP metres along x.
	var ground := Columns.new(-160.0, -170.0, 1.0, 561, 341)
	var deco_p := PackedVector3Array()
	var deco_c := PackedColorArray()
	for ix in ground.nx:
		for iz in ground.nz:
			var x := ground.x0 + ix
			var z := ground.z0 + iz
			var h := maxf(1.0, roundf(ground_hf(x, z)))
			ground.h[ix * ground.nz + iz] = h
			ground.col[ix * ground.nz + iz] = _ground_tone(x, z, h)
			var px := posmod(int(x), int(LOOP))
			if absf(z) < 98.0 and _h(px, 7, int(z)) < 0.02:
				deco_p.append(Vector3(x, h + 0.2, z))
				var k := 0.95 + 0.1 * _h(px, 9, int(z))
				var dc := Color(0.55, 0.62, 0.45) if _h(px, 8, int(z)) < 0.7 else Color(0.36, 0.31, 0.28)
				deco_c.append(Color(dc.r * k, dc.g * k, dc.b * k))
	var chunks := []
	for i in 15:
		chunks.append(Faces.new())
	ground.add_faces(chunks, 40.0)
	for f: Faces in chunks:
		var mesh := ArrayMesh.new()
		f.add_to(mesh, mat_voxel)
		add_child(_mi(mesh))
	add_child(_mi(_cubes(deco_p, deco_c, 0.4)))

	# Story props hinting at danger, repeated with the desert: a giant ribcage and a dead walker's leg.
	var pp := PackedVector3Array()
	var pc := PackedColorArray()
	for k in [-1, 0, 1]:
		var off: float = k * LOOP
		_ribcage(pp, pc, 60.0 + off, -94.0)
		_dead_leg(pp, pc, 120.0 + off, 90.0)
	add_child(_mi(_cubes(pp, pc, 0.5)))


func _ribcage(pp: PackedVector3Array, pc: PackedColorArray, bx: float, bz: float) -> void:
	if bx < -150.0 or bx > 380.0:
		return
	var bone := Color(0.90, 0.87, 0.78)
	var by := ground_at(bx, bz)
	for i in 44:
		pp.append(Vector3(bx - 4.0 + i * 0.5, by + 0.75, bz))
		pc.append(bone * (0.96 + 0.06 * _h(i, 1, 0)))
	for rib in 6:
		var rad := 7.0 - rib * 0.6
		for a in 40:
			var ang := PI * a / 39.0
			pp.append(Vector3(bx + rib * 3.0, by + rad * sin(ang), bz + rad * cos(ang)))
			pc.append(bone * (0.96 + 0.06 * _h(rib, a, 2)))


func _dead_leg(pp: PackedVector3Array, pc: PackedColorArray, lx: float, lz: float) -> void:
	if lx < -150.0 or lx > 360.0:
		return
	var a0 := Vector3(lx, ground_at(lx, lz) + 1, lz)
	var a1 := Vector3(lx + 22, ground_at(lx, lz) + 9, lz + 8)
	for s in 80:
		var c := a0.lerp(a1, s / 79.0)
		for ox in range(-2, 3):
			for oz in range(-2, 3):
				pp.append(c + Vector3(ox * 0.5, 0, oz * 0.5))
				pc.append(Color(0.45, 0.25, 0.15) * (0.92 + 0.12 * _h(s, ox, oz)))


# ---------- City ----------

## How far out a deck column is, squared: 1 on the deck's edge (a rounded rectangle, like the terraces).
func _e(x: float, z: float) -> float:
	return pow(_tq(x, z), 2.0)


func _hull_bottom(x: int, z: int) -> int:
	var e := _e(x, z)
	if e > 1.0:
		return 1
	return -6 - int(22.0 * sqrt(1.0 - e))


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


func _build_city() -> void:
	city = Node3D.new()
	add_child(city)
	grid.resize(NX * NY * NZ)
	_map_levels()
	_build_deck()
	_build_wall_ring()
	_build_terraces()
	_build_stairs()
	var top: int = LEVELS[LEVELS.size() - 1][1]
	origin = Vector3i(PLAZA_X, top, 0)
	_build_plaza()
	origin = Vector3i(0, top, 0)
	_build_tower(-62, -13)
	origin = Vector3i.ZERO
	plaza_c = Vector3(PLAZA_X, top, 0) * VS
	_build_errand_sites()
	_build_market()
	_place_houses()
	_place_trees()
	_build_underside()
	for hip in _hip_positions():
		var hb := Vector3i(hip * RES)
		_sphere(hb.x, hb.y, hb.z, 11.0, P.HULL, P.BRASS)
	_build_struts()
	_emit_grid()


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


func _lamp(lx: int, lz: int) -> void:
	box3(lx, 1, lz, lx, 12, lz, P.IRON)
	box3(lx - 1, 13, lz - 1, lx + 1, 13, lz + 1, P.IRON)
	box3(lx, 14, lz, lx, 15, lz, P.GLOW)
	box3(lx - 1, 16, lz - 1, lx + 1, 16, lz + 1, P.IRON)


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


func _sphere(cx: int, cy: int, cz: int, r: float, p_main: int, p_band: int) -> void:
	var ri := int(ceil(r))
	for dx in range(-ri, ri + 1):
		for dy in range(-ri, ri + 1):
			for dz in range(-ri, ri + 1):
				var d := sqrt(float(dx * dx + dy * dy + dz * dz))
				if d <= r and d > r - 2.0:
					sv(cx + dx, cy + dy, cz + dz, p_band if absi(dy) <= 1 else p_main)


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


func _place_houses() -> void:
	# Keep two main streets clear (along x and along z; the stairs are on them), then
	# pack houses tightly on each terrace; neighbours may share walls like an old
	# Mediterranean town. The top terrace is kept for the plaza and the tower.
	for i in range(-45, 46):
		for k in range(-1, 2):
			streets[Vector2i(i, k)] = true
			streets[Vector2i(k, i)] = true
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


# ---------- Legs ----------

func _hip_positions() -> Array:
	# Just outside the deck's edge, so a leg swinging up to its knee never passes
	# through the streets (playtest 2: "the city legs clip through the walls")
	return [Vector3(43, -2, 46), Vector3(0, -2, 48.4), Vector3(-43, -2, 46),
			Vector3(43, -2, -46), Vector3(0, -2, -48.4), Vector3(-43, -2, -46)]


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


## A hollow square leg segment built along local -Y, with brass bands and rivets.
func _segment_mesh(length_m: float, thick: int, base: Color, piston: bool) -> ArrayMesh:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	var L := int(length_m * RES)
	var half := (thick - 1) * 0.5
	for i in L:
		var band := i < 4 or i > L - 5 or posmod(i, 40) in [18, 19, 20]
		for a in thick:
			for b in thick:
				var ea := a == 0 or a == thick - 1
				var eb := b == 0 or b == thick - 1
				if ea and eb:
					continue
				if not (ea or eb) and i != 0 and i != L - 1:
					continue
				var c: Color = PAL[P.BRASS] if band else base
				if (a == 2 or b == 2) and i % 5 == 0 and not band:
					c = PAL[P.HULL2]
				pts.append(Vector3((a - half) * VS, -(i + 0.5) * VS, (b - half) * VS))
				cols.append(jitter(c, 0.02))
		if piston and i > L * 0.15 and i < L * 0.7:
			for a in 2:
				for b in 2:
					pts.append(Vector3((thick * 0.5 + 1 + a) * VS, -(i + 0.5) * VS, (b - 0.5) * VS))
					cols.append(PAL[P.BRASS] if i % 12 < 2 else Color(0.62, 0.62, 0.60))
	return _cubes(pts, cols, VS, true)


func _build_legs() -> void:
	var thigh_mesh := _segment_mesh(THIGH_LEN, 20, Color(0.28, 0.25, 0.24), false)
	var shin_mesh := _segment_mesh(SHIN_LEN, 15, Color(0.24, 0.22, 0.21), true)
	var jp := PackedVector3Array()
	var jc := PackedColorArray()
	for dx in range(-16, 17):
		for dy in range(-16, 17):
			for dz in range(-16, 17):
				var d := sqrt(float(dx * dx + dy * dy + dz * dz))
				if d <= 16.0 and d > 14.0:
					jp.append(Vector3(dx, dy, dz) * VS)
					jc.append(jitter(PAL[P.BRASS] if absi(dy) <= 1 else PAL[P.HULL], 0.02))
	var joint_mesh := _cubes(jp, jc, VS, true)
	var fp_ := PackedVector3Array()
	var fc := PackedColorArray()
	for dx in range(-18, 19):
		for dz in range(-18, 19):
			var r := sqrt(float(dx * dx + dz * dz))
			if r <= 18.0:
				for dy in 4:
					if dy == 3 or r > 16.5:
						fp_.append(Vector3(dx, dy + 0.5, dz) * VS)
						fc.append(jitter(Color(0.20, 0.18, 0.17) if dy < 3 else PAL[P.HULL], 0.02))
			if r <= 11.0:
				for dy in range(4, 10):
					if r > 9.5 or dy == 9:
						fp_.append(Vector3(dx, dy + 0.5, dz) * VS)
						fc.append(jitter(PAL[P.HULL], 0.02))
	var foot_mesh := _cubes(fp_, fc, VS, true)

	var dust_mat := StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.80, 0.68, 0.52)
	dust_mat.roughness = 1.0
	var dust_mesh := BoxMesh.new()
	dust_mesh.size = Vector3.ONE * 0.5
	dust_mesh.material = dust_mat

	var hips := _hip_positions()
	var tripod := [0.0, 0.5, 0.0, 0.5, 0.0, 0.5]
	for i in hips.size():
		var leg := {
			"hip": hips[i],
			"offset": tripod[i],
			"side": signf(hips[i].z),
			"thigh": _mi(thigh_mesh),
			"shin": _mi(shin_mesh),
			"knee": _mi(joint_mesh),
			"foot": _mi(foot_mesh),
			"dust": _make_dust(dust_mesh),
			"prev_p": 0.0,
		}
		for k in ["thigh", "shin", "knee", "foot", "dust"]:
			add_child(leg[k])
		legs.append(leg)


func _make_dust(mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 40
	p.lifetime = 1.8
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -1.5, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var cu := Curve.new()
	cu.add_point(Vector2(0, 1))
	cu.add_point(Vector2(1, 0))
	p.scale_amount_curve = cu
	return p


# ---------- Residents ----------

func _make_person(shirt: Color, pants: Color, hair: Color, skin: Color) -> MeshInstance3D:
	var pts := []    # plain Arrays: lambdas would copy packed arrays
	var cols := []
	var add := func(x: int, y: int, z: int, c: Color) -> void:
		pts.append(Vector3((x - 0.5) * VS, (y + 0.5) * VS, z * VS))
		cols.append(c)
	for y in 3:
		for x in 2:
			add.call(x, y, -1, pants)
			add.call(x, y, 1, pants)
	for y in range(3, 6):
		for x in 2:
			for z in range(-1, 2):
				add.call(x, y, z, shirt)
		add.call(1 if y == 3 else 0, y, -2, skin if y == 3 else shirt)
		add.call(1 if y == 3 else 0, y, 2, skin if y == 3 else shirt)
	for y in range(6, 9):
		for x in 2:
			for z in range(-1, 2):
				var c := skin
				if y == 8 or x == 0:
					c = hair
				elif y == 7 and x == 1 and z != 0:
					c = Color(0.15, 0.12, 0.10)
				add.call(x, y, z, c)
	return _mi(_cubes(PackedVector3Array(pts), PackedColorArray(cols), VS, true))


func _random_person() -> MeshInstance3D:
	var shirts := [Color(0.16, 0.55, 0.58), Color(0.82, 0.30, 0.26), Color(0.94, 0.80, 0.40),
			Color(0.96, 0.95, 0.90), Color(0.40, 0.52, 0.78), Color(0.55, 0.70, 0.40)]
	var pants := [Color(0.30, 0.24, 0.20), Color(0.24, 0.28, 0.38), Color(0.55, 0.48, 0.38)]
	var hairs := [Color(0.20, 0.13, 0.08), Color(0.45, 0.30, 0.15), Color(0.10, 0.09, 0.08), Color(0.80, 0.70, 0.45)]
	var skins := [Color(0.92, 0.75, 0.62), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.26)]
	return _make_person(shirts[rng.randi() % shirts.size()], pants[rng.randi() % pants.size()],
			hairs[rng.randi() % hairs.size()], skins[rng.randi() % skins.size()])


func _ring_radius() -> float:
	# Two walking rings in the plaza (metres): inside the parasols, or outside them.
	return rng.randf_range(3.1, 3.6) if rng.randf() < 0.5 else rng.randf_range(6.8, 7.4)


## Where to cross between the two rings: the gap between parasols nearest to
## angle a (leaving out your gap). Returned close to a, so walkers take the short way.
func _crossing_near(a: float) -> float:
	var best := INF
	for g in 6:
		if g == YOUR_GAP:
			continue
		var d := wrapf(PARASOL_A0 + TAU * (g + 0.5) / 6.0 - a, -PI, PI)
		if absf(d) < absf(best):
			best = d
	return a + best


func _add_residents() -> void:
	# Where you start: between two parasols, facing out from the fountain toward the houses.
	# Mira, who asks you for help, stands just beside you.
	var ra := PARASOL_A0 + TAU * (YOUR_GAP + 0.5) / 6.0
	you_spot = plaza_c + Vector3(cos(ra) * 5.0, VS * 0.5, sin(ra) * 5.0)
	you_yaw = -ra
	mira_spot = plaza_c + Vector3(cos(ra + 0.16) * 5.0, VS * 0.5, sin(ra + 0.16) * 5.0)
	for i in WALKERS:
		var node := Node3D.new()
		node.add_child(_random_person())
		city.add_child(node)
		var r := _ring_radius()
		var a := rng.randf() * TAU
		node.position = plaza_c + Vector3(cos(a) * r, VS * 0.5, sin(a) * r)
		node.rotation.y = -a - PI * 0.5
		walkers.append({"node": node, "a": a, "r": r, "ta": rng.randf() * TAU,
				"tr": r, "wait": rng.randf() * 3.0, "speed": rng.randf_range(0.9, 1.4)})
	# Residents strolling along each terrace's edge, just inside the balustrade
	for l in LEVELS.size():
		var reach: float = LEVELS[l][0]
		for i in PROMENADE_WALKERS[l]:
			var node := Node3D.new()
			node.add_child(_random_person())
			city.add_child(node)
			var a := rng.randf() * TAU
			var pw := {"node": node, "a": a, "ta": a, "wait": rng.randf() * 4.0, "speed": rng.randf_range(0.8, 1.3),
					"rx": (RXV * reach - 6) * VS, "rz": (RZV * reach - 6) * VS, "y": (LEVELS[l][1] + 0.5) * VS}
			node.position = _promenade_point(pw, a)
			node.rotation.y = -a - PI * 0.5
			promenaders.append(pw)
	_add_market_crowd()


func _update_walkers(delta: float) -> void:
	for w in walkers:
		var node: Node3D = w["node"]
		if _notice(w, node):
			continue
		if w["wait"] > 0.0:
			w["wait"] -= delta
			node.position.y = plaza_c.y + VS * 0.5
			continue
		var da := wrapf(w["ta"] - w["a"], -PI, PI)
		var dr: float = w["tr"] - w["r"]
		var r: float = w["r"]
		var step: float = w["speed"] * delta / maxf(r, 1.0)
		if absf(da) < 0.02 and absf(dr) < 0.05:
			w["wait"] = rng.randf_range(1.0, 5.0)
			var new_r := _ring_radius() if rng.randf() < 0.3 else r
			if (new_r < 5.0) != (r < 5.0):
				# Changing ring: walk round to a gap between parasols first.
				w["ta"] = _crossing_near(w["a"])
			else:
				w["ta"] = w["a"] + rng.randf_range(-1.6, 1.6)
			w["tr"] = new_r
			continue
		w["a"] += clampf(da, -step, step)
		# Only step across between the rings once at the gap, so nobody walks through the tables.
		var crossing: bool = (w["tr"] < 5.0) != (r < 5.0)
		if not crossing or absf(da) < 0.05:
			w["r"] += clampf(dr, -0.6 * delta, 0.6 * delta)
		var a: float = w["a"]
		r = w["r"]
		var pos := plaza_c + Vector3(cos(a) * r, VS * 0.5 + absf(sin(t * 9.0 + a * 5.0)) * 0.05, sin(a) * r)
		var move := Vector3(pos.x - node.position.x, 0, pos.z - node.position.z)
		node.position = pos
		# Face the way they walk (person mesh faces +x)
		if move.length_squared() > 1e-10:
			node.rotation.y = atan2(-move.z, move.x)


## Neighbours stop for a moment and turn to look at you when you walk past.
func _notice(w: Dictionary, node: Node3D) -> bool:
	if player == null:
		return false
	var d: Vector3 = player.position - node.position
	if d.x * d.x + d.z * d.z > NOTICE * NOTICE:
		return false
	w["wait"] = maxf(w["wait"], 0.8)
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-d.z, d.x), 0.2)
	return true


## A point on a promenade (just inside a terrace's edge), with a little walking bob.
func _promenade_point(pw: Dictionary, a: float) -> Vector3:
	var p := _round_rect(pw["rx"], pw["rz"], a)
	return Vector3(p.x, pw["y"] + absf(sin(t * 9.0 + a * 37.0)) * 0.05, p.y)


func _update_promenaders(delta: float) -> void:
	for pw in promenaders:
		var node: Node3D = pw["node"]
		if _notice(pw, node):
			continue
		if pw["wait"] > 0.0:
			pw["wait"] -= delta
			continue
		var a: float = pw["a"]
		var da: float = pw["ta"] - a
		if absf(da) < 0.002:
			pw["wait"] = rng.randf_range(0.5, 4.0)
			pw["ta"] = a + rng.randf_range(0.3, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0)
			continue
		# Turn walking speed into an angle step (the path is longer per radian on its long sides).
		var per_rad := (_round_rect(pw["rx"], pw["rz"], a + 0.001) - _round_rect(pw["rx"], pw["rz"], a)).length() / 0.001
		var step: float = pw["speed"] * delta / maxf(per_rad, 0.5)
		pw["a"] = a + clampf(da, -step, step)
		var pos := _promenade_point(pw, pw["a"])
		var move := pos - node.position
		node.position = pos
		if Vector2(move.x, move.z).length_squared() > 1e-10:
			node.rotation.y = atan2(-move.z, move.x)


# ---------- The market crowd ----------
# People stroll up and down the market street keeping to the right, drift across
# now and then, stop to look at a shop, and turn back at the ends. Kids run about,
# some people carry crates, little groups stand chatting, and every shop has a
# shopkeeper. They step aside when you walk into them. Lane 0 is the street's middle;
# positive lanes are on the side toward the city's middle.

enum Mk { WALK, BROWSE_IN, BROWSE, TURN }

var market_people := []
var market_idlers := []   # shopkeepers and chatting groups: they stand and fidget
var _mk_len := 0.0


func _add_market_crowd() -> void:
	if market_path.size() < 2:
		return
	_mk_len = (market_path.size() - 1) * 0.5
	var looks := []
	for i in 16:
		looks.append(_random_person().mesh)
	var crates := []
	for c in [P.WOOD, P.RED, P.AWN1, P.LEAF]:
		var m := BoxMesh.new()
		m.size = Vector3(0.4, 0.25, 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PAL[c]
		m.material = mat
		crates.append(m)
	for i in T.MARKET_WALKERS:
		var kid := rng.randf() < T.MARKET_KIDS
		var node := _mk_person(looks, kid)
		if not kid and rng.randf() < T.MARKET_CARRY:
			var crate := MeshInstance3D.new()
			crate.mesh = crates[rng.randi() % crates.size()]
			crate.position = Vector3(0.0, 1.95, 0.0)
			node.add_child(crate)
		var dir := 1 if rng.randf() < 0.5 else -1
		var lane := _mk_lane(dir)
		var s := rng.randf_range(1.0, _mk_len - 1.0)
		node.position = _mk_point(s, lane)
		market_people.append({"node": node, "s": s, "dir": dir, "lane": lane, "goal": lane,
				"speed": rng.randf_range(2.0, 2.8) if kid else rng.randf_range(0.8, 1.35),
				"state": Mk.WALK, "timer": 0.0, "kid": kid})
	for g in T.MARKET_GROUPS:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var c := _mk_point(rng.randf_range(6.0, _mk_len - 6.0), side * 2.6)
		var n := rng.randi_range(2, 4)
		for k in n:
			var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
			var node := _mk_person(looks, false)
			node.position = c + Vector3(cos(a), 0.0, sin(a)) * 0.6
			var to_c := c - node.position
			node.rotation.y = atan2(-to_c.z, to_c.x)
			market_idlers.append({"node": node, "yaw": node.rotation.y, "phase": rng.randf() * TAU})
	for sk in shopkeepers + shoppers:
		var node := _mk_person(looks, false)
		node.position = sk[0]
		var f: Vector3 = sk[1]
		node.rotation.y = atan2(-f.z, f.x)
		market_idlers.append({"node": node, "yaw": node.rotation.y, "phase": rng.randf() * TAU})
	print("market crowd: %d walking, %d standing" % [market_people.size(), market_idlers.size()])


## A resident sharing one of a few ready-made looks (kids are smaller).
func _mk_person(looks: Array, kid: bool) -> Node3D:
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = looks[rng.randi() % looks.size()]
	node.add_child(mi)
	if kid:
		node.scale = Vector3.ONE * 0.72
	city.add_child(node)
	return node


## A lane on your right-hand side of the street for the way you're walking.
func _mk_lane(dir: int) -> float:
	return -dir * rng.randf_range(0.4, 3.0)


func _mk_index(s: float) -> Vector2:
	var f := clampf(s / 0.5, 0.0, market_path.size() - 1.001)
	return Vector2(floorf(f), f - floorf(f))


## Direction along the street at s (metres from the east end).
func _mk_tangent(s: float) -> Vector3:
	var k := _mk_index(s)
	return market_dir[int(k.x)].lerp(market_dir[int(k.x) + 1], k.y).normalized()


## Sideways direction at s, toward the city's middle.
func _mk_normal(s: float) -> Vector3:
	var d := _mk_tangent(s)
	return Vector3(-d.z, 0.0, d.x)


## A point on the street, s metres along and `lane` metres across (on the city).
func _mk_point(s: float, lane: float) -> Vector3:
	var k := _mk_index(s)
	return market_path[int(k.x)].lerp(market_path[int(k.x) + 1], k.y) + _mk_normal(s) * lane


func _update_market(delta: float) -> void:
	var you := Vector2(INF, INF)
	if player != null:
		you = Vector2(player.position.x, player.position.z)
	for pp in market_people:
		var node: Node3D = pp["node"]
		var s: float = pp["s"]
		var lane: float = pp["lane"]
		var dir: int = pp["dir"]
		var st: int = pp["state"]
		var kid: bool = pp["kid"]
		var face := Vector3.ZERO
		if st == Mk.TURN or st == Mk.BROWSE:
			pp["timer"] -= delta
			if st == Mk.BROWSE:
				face = _mk_normal(s) * (1.0 if lane >= 0.0 else -1.0)
			if pp["timer"] <= 0.0:
				if st == Mk.TURN:
					dir = -dir
					pp["dir"] = dir
				pp["state"] = Mk.WALK
				pp["goal"] = _mk_lane(dir)
		else:
			var goal: float = pp["goal"]
			var spd: float = pp["speed"]
			# Step aside (and slow down) when you're in the way
			var here := _mk_point(s, lane)
			var off := Vector2(here.x - you.x, here.z - you.y)
			if off.length() < 1.0:
				var nrm := _mk_normal(s)
				spd *= 0.4
				lane += (1.0 if off.dot(Vector2(nrm.x, nrm.z)) >= 0.0 else -1.0) * 1.5 * delta
			lane = clampf(move_toward(lane, goal, (1.2 if st == Mk.BROWSE_IN else 0.5) * delta), -3.1, 3.1)
			if st == Mk.BROWSE_IN:
				s += dir * spd * 0.3 * delta
				if absf(lane - goal) < 0.05:
					pp["state"] = Mk.BROWSE
					pp["timer"] = rng.randf_range(3.0, 9.0)
			else:
				s += dir * spd * delta
				if rng.randf() < delta * (0.3 if kid else 0.05):
					pp["goal"] = _mk_lane(dir)
				elif not kid and rng.randf() < delta * 0.035:
					pp["state"] = Mk.BROWSE_IN
					pp["goal"] = 3.1 if lane >= 0.0 else -3.1
				if s < 0.5 or s > _mk_len - 0.5:
					s = clampf(s, 0.5, _mk_len - 0.5)
					pp["state"] = Mk.TURN
					pp["timer"] = rng.randf_range(0.5, 3.0)
			face = _mk_tangent(s) * dir + _mk_normal(s) * clampf(float(pp["goal"]) - lane, -1.0, 1.0) * 0.4
		pp["s"] = s
		pp["lane"] = lane
		var p := _mk_point(s, lane)
		var moving: bool = pp["state"] == Mk.WALK or pp["state"] == Mk.BROWSE_IN
		var bob := absf(sin(t * (13.0 if kid else 9.0) + s * 3.0)) * 0.05 if moving else 0.0
		node.position = Vector3(p.x, VS * 0.5 + bob, p.z)
		if face.length_squared() > 0.0001:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-face.z, face.x), minf(1.0, 8.0 * delta))
	for idl in market_idlers:
		var node: Node3D = idl["node"]
		node.rotation.y = float(idl["yaw"]) + sin(t * 0.6 + float(idl["phase"])) * 0.35


# ---------- Leg maths ----------

func solve_knee(h: Vector3, f: Vector3, side: float) -> Vector3:
	var to := f - h
	var d := clampf(to.length(), 1.0, THIGH_LEN + SHIN_LEN - 0.01)
	var dir := to.normalized()
	var a := clampf((THIGH_LEN * THIGH_LEN + d * d - SHIN_LEN * SHIN_LEN) / (2.0 * THIGH_LEN * d), -1.0, 1.0)
	var hint := Vector3.UP * 0.6 + Vector3(0, 0, side)
	var perp := (hint - dir * hint.dot(dir)).normalized()
	return h + dir * (THIGH_LEN * a) + perp * (THIGH_LEN * sqrt(1.0 - a * a))


## Points a segment (built along local -Y) from a to b.
func place_segment(node: Node3D, a: Vector3, b: Vector3) -> void:
	var y := (a - b).normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := (ref - y * ref.dot(y)).normalized()
	var z := x.cross(y)
	node.global_transform = Transform3D(Basis(x, y, z), a)


# ---------- Per frame ----------

func _process(delta: float) -> void:
	if not paused:
		t += delta
		_update_walkers(delta)
		_update_promenaders(delta)
		_update_market(delta)
	var period := 2.0 * STEP_LENGTH / CITY_SPEED
	var body_x := CITY_SPEED * t
	if body_x > 230.0:
		# Loop back a whole number of strides. The desert repeats every LOOP metres,
		# so the jump can't be seen and the walk never ends.
		t -= LOOP / CITY_SPEED
		body_x = CITY_SPEED * t
	var bob := -0.6 * T.SWAY * absf(sin(TAU * t / period))
	city.position = Vector3(body_x, CITY_HEIGHT + bob, 0)
	city.rotation.x = 0.012 * T.SWAY * sin(TAU * t / period)

	for leg in legs:
		var hip_l: Vector3 = leg["hip"]
		var side: float = leg["side"]
		var p := fposmod(t / period + float(leg["offset"]), 1.0)
		var fz := hip_l.z + side * LEG_REACH
		var fx: float
		var lift := 0.0
		if p < 0.5:
			fx = CITY_SPEED * (t - p * period) + hip_l.x + STEP_LENGTH * 0.5
		else:
			var s := (p - 0.5) / 0.5
			var from_x := CITY_SPEED * (t - (p - 0.5) * period) + hip_l.x - STEP_LENGTH * 0.5
			var to_x := CITY_SPEED * (t + (1.0 - p) * period) + hip_l.x + STEP_LENGTH * 0.5
			fx = lerpf(from_x, to_x, smoothstep(0.0, 1.0, s))
			lift = sin(PI * s) * STEP_LIFT
		var foot := Vector3(fx, ground_at(fx, fz) + lift, fz)
		var ankle := foot + Vector3(0, 2, 0)
		var hip := city.to_global(hip_l)
		var knee := solve_knee(hip, ankle, side)
		place_segment(leg["thigh"], hip, knee)
		place_segment(leg["shin"], knee, ankle)
		leg["knee"].global_position = knee
		leg["foot"].global_position = foot
		if p < leg["prev_p"]:
			var dust: CPUParticles3D = leg["dust"]
			dust.global_position = foot + Vector3(0, 1, 0)
			dust.restart()
			stomped.emit(foot)
		leg["prev_p"] = p


# ---------- The market street (north half of the outer ring) ----------
# A U-shaped shopping street: up the east side, along the north, down the west side,
# from stairs to stairs. Shops on both sides with open fronts, awnings, hanging signs
# and goods outside; lanterns and bunting strung across overhead; stalls on little
# squares. All numbers are blocks (5 per metre). The south half stays homes.

const MARKET_Z0 := 10                     # the market fills the outer ring north of this
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
			if not _mk_ground(x, z) or streets.has(Vector2i(_cell(x), _cell(z))):
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
	var floors := 2 if rng.randf() < 0.7 else 3
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
	# A hanging sign on an iron bracket at one corner, with the shop's icon
	var su := 0 if rng.randf() < 0.5 else L - 1
	for out in range(1, 6):
		svv(fp(o, a, n, su, 18, out), P.IRON)
	for out in range(2, 6):
		for y in range(13, 17):
			var icon := out in [3, 4] and y in [14, 15]
			svv(fp(o, a, n, su, y, out), (goods[(out + y) % 2]) if icon else P.WOOD_DARK)
	svv(fp(o, a, n, su, 17, 2), P.IRON)
	svv(fp(o, a, n, su, 17, 5), P.IRON)


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


## Metres on the city for a block position (the centre of the block's top).
func _m(b: Vector3i) -> Vector3:
	return Vector3(b.x * VS, (b.y + 0.5) * VS, b.z * VS)


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


# ---------- Errand sites (the first toy's one job) ----------

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


# ---------- Walk map: where people can stand ----------

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
