extends Node3D
## LOOK TEST HD: the walking city at roughly Town to City block size.
## One block = 20 cm (5 per metre); a resident is 9 blocks tall.
## Everything is built from code. Throwaway prototype for judging the art style.
## Keys: 1-6 change camera (6 = diorama), Space pauses, Esc quits.
## Run with "-- --shots" to save screenshots to shots/ and quit.

# --- Tuning (safe to tweak) ---
const CITY_SPEED := 4.0      # how fast the city walks
const STEP_LENGTH := 14.0    # how far each foot moves per step
const STEP_LIFT := 5.0       # how high feet lift
const CITY_HEIGHT := 24.0    # deck height above the ground
const THIGH_LEN := 13.0
const SHIN_LEN := 30.0
const LEG_REACH := 24.0      # how far out to the side the feet land
const WALKERS := 18          # residents strolling round the plaza
const SEED := 7

# --- Block grid for the city (all in blocks, 5 per metre) ---
const RES := 5
const VS := 1.0 / RES
const RXV := 140             # deck half-length (28 m)
const RZV := 95              # deck half-width (19 m)
const GX0 := -150
const GZ0 := -105
const GY0 := -50
const NX := 301
const NZ := 211
const NY := 185

enum P { EMPTY, PAVE, PAVE2, PLAZA, MORTAR, STONE, STONE2, HULL, HULL2, BRASS, WOOD, WOOD_DARK,
		TERRA, TERRA2, TERRA3, WALL0, WALL1, WALL2, WALL3, WALL4, SHUTTER0, SHUTTER1, GLASS,
		LEAF, LEAF2, CYPRESS, TRUNK, WATER, RED, PINK, PURPLE, AWN0, AWN1, AWN2, WHITE,
		IVY, GOLD, FLAG, IRON, CLOTH0, CLOTH1, CLOTH2, GLOW, WIN_GLOW }

const C_GLOW := Color(1.0, 0.66, 0.36)

var PAL := []
var grid := PackedByteArray()
var filled := PackedInt32Array()
var occ := {}               # metre cells already used on the deck

var mat_voxel: StandardMaterial3D
var mat_glow: StandardMaterial3D
var box: BoxMesh
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()

var city: Node3D
var camera: Camera3D
var resident: Node3D
var walkers := []
var legs := []
var chimneys := []
var t := 2.0
var paused := false
var view := 5
var help: Label


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
	if "--shots" in OS.get_cmdline_user_args():
		help.visible = false
		_run_shots()


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
	box = BoxMesh.new()
	box.size = Vector3.ONE
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

	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 600.0
	var cam_attr := CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 140.0
	cam_attr.dof_blur_far_transition = 80.0
	cam_attr.dof_blur_near_enabled = true
	cam_attr.dof_blur_near_distance = 30.0
	cam_attr.dof_blur_near_transition = 20.0
	cam_attr.dof_blur_amount = 0.12
	camera.attributes = cam_attr
	add_child(camera)

	var layer := CanvasLayer.new()
	help = Label.new()
	help.text = "1-6: camera   Space: pause   Esc: quit"
	help.position = Vector2(16, 12)
	help.add_theme_font_size_override("font_size", 18)
	layer.add_child(help)
	add_child(layer)


# ---------- MultiMesh helpers ----------

func jitter(c: Color, amt := 0.04) -> Color:
	var j := rng.randf_range(-amt, amt)
	return Color(clampf(c.r + j, 0, 1), clampf(c.g + j, 0, 1), clampf(c.b + j, 0, 1))


## Cheap repeatable 0..1 noise per block, so colours vary without randomness drift.
func _h(x: int, y: int, z: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 1023) / 1023.0


## Writes one instance (row-major 3x4 transform, then colour) into a MultiMesh buffer.
func _put(buf: PackedFloat32Array, i: int, b: Basis, o: Vector3, c: Color) -> void:
	var k := i * 16
	buf[k] = b.x.x
	buf[k + 1] = b.y.x
	buf[k + 2] = b.z.x
	buf[k + 3] = o.x
	buf[k + 4] = b.x.y
	buf[k + 5] = b.y.y
	buf[k + 6] = b.z.y
	buf[k + 7] = o.y
	buf[k + 8] = b.x.z
	buf[k + 9] = b.y.z
	buf[k + 10] = b.z.z
	buf[k + 11] = o.z
	buf[k + 12] = c.r
	buf[k + 13] = c.g
	buf[k + 14] = c.b
	buf[k + 15] = 1.0


func _mm_buf(buf: PackedFloat32Array) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = buf.size() / 16
	if buf.size() > 0:
		mm.buffer = buf
	return mm


func _mm_lists(pts: PackedVector3Array, cols: PackedColorArray, size: float) -> MultiMesh:
	var buf := PackedFloat32Array()
	buf.resize(pts.size() * 16)
	var b := Basis().scaled(Vector3.ONE * size)
	for i in pts.size():
		_put(buf, i, b, pts[i], cols[i])
	return _mm_buf(buf)


func _mmi(mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


# ---------- Block grid ----------

func sv(x: int, y: int, z: int, p: int) -> void:
	if x < GX0 or x >= GX0 + NX or z < GZ0 or z >= GZ0 + NZ or y < GY0 or y >= GY0 + NY:
		return
	var i := ((y - GY0) * NZ + (z - GZ0)) * NX + (x - GX0)
	if grid[i] == 0:
		filled.append(i)
	grid[i] = p


func gv(x: int, y: int, z: int) -> int:
	if x < GX0 or x >= GX0 + NX or z < GZ0 or z >= GZ0 + NZ or y < GY0 or y >= GY0 + NY:
		return 0
	return grid[((y - GY0) * NZ + (z - GZ0)) * NX + (x - GX0)]


func box3(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, p: int) -> void:
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				sv(x, y, z, p)


func svv(v: Vector3i, p: int) -> void:
	sv(v.x, v.y, v.z, p)


func clv(v: Vector3i) -> void:
	if gv(v.x, v.y, v.z) != 0:
		grid[((v.y - GY0) * NZ + (v.z - GZ0)) * NX + (v.x - GX0)] = 0


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


## Turns the grid into two MultiMeshes (normal + glowing), skipping hidden blocks.
func _emit_grid() -> void:
	var buf := PackedFloat32Array()
	buf.resize(filled.size() * 16)
	var gbuf := PackedFloat32Array()
	var b := Basis().scaled(Vector3.ONE * VS)
	var sz := NX
	var sy := NX * NZ
	var n := 0
	var g := 0
	for i in filled:
		var p: int = grid[i]
		if p == 0:
			continue
		var x := i % NX
		var r := i / NX
		var z := r % NZ
		var y := r / NZ
		if x > 0 and x < NX - 1 and z > 0 and z < NZ - 1 and y > 0 and y < NY - 1:
			if grid[i + 1] != 0 and grid[i - 1] != 0 and grid[i + sz] != 0 and grid[i - sz] != 0 \
					and grid[i + sy] != 0 and grid[i - sy] != 0:
				continue
		var bx := x + GX0
		var by := y + GY0
		var bz := z + GZ0
		var c: Color = PAL[p]
		var s := 0.93 + 0.12 * _h(bx, by, bz)
		c = Color(c.r * s, c.g * s, c.b * s)
		var o := Vector3(bx * VS, by * VS, bz * VS)
		if p >= P.GLOW:
			gbuf.resize((g + 1) * 16)
			_put(gbuf, g, b, o, c)
			g += 1
		else:
			_put(buf, n, b, o, c)
			n += 1
	buf.resize(n * 16)
	city.add_child(_mmi(_mm_buf(buf), mat_voxel))
	city.add_child(_mmi(_mm_buf(gbuf), mat_glow))
	print("city blocks drawn: ", n + g, " (of ", filled.size(), " placed)")


# ---------- Ground ----------

func ground_hf(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var h := 2.0 + n * 1.5
	var az := absf(z)
	if az > 45.0:
		var m := smoothstep(45.0, 85.0, az)
		h += m * (6.0 + 12.0 * maxf(0.0, noise.get_noise_2d(x * 0.5 + 300.0, z * 0.5)))
	return maxf(0.5, h)


## Ground surface height, matching how the half-metre ground blocks are built.
func ground_at(x: float, z: float) -> float:
	return maxf(0.5, roundf(ground_hf(roundf(x * 2.0) / 2.0, roundf(z * 2.0) / 2.0) * 2.0) / 2.0)


func _ground_color(h: float) -> Color:
	if h <= 2.0:
		return Color(0.82, 0.70, 0.52)
	elif h <= 4.0:
		return Color(0.75, 0.60, 0.42)
	elif h <= 10.0:
		return Color(0.66, 0.47, 0.33) if int(h) % 2 == 0 else Color(0.71, 0.53, 0.37)
	return Color(0.48, 0.40, 0.34)


func _build_ground() -> void:
	var cols := []
	# Half-metre blocks near the city's path, whole-metre blocks further out.
	var x := -80.0
	while x <= 300.0:
		var z := -50.0
		while z <= 50.0:
			cols.append(Vector3(x, z, 0.5))
			z += 0.5
		x += 0.5
	for xi in range(-80, 301):
		for zi in range(-150, 151):
			if absi(zi) > 50:
				cols.append(Vector3(xi, zi, 1.0))
	var buf := PackedFloat32Array()
	buf.resize(cols.size() * 16)
	var deco_p := PackedVector3Array()
	var deco_c := PackedColorArray()
	for i in cols.size():
		var cv: Vector3 = cols[i]
		var s := cv.z
		var h := maxf(s, roundf(ground_hf(cv.x, cv.y) / s) * s)
		var c := _ground_color(h)
		var tint := noise.get_noise_2d(cv.x * 2.0 + 900.0, cv.y * 2.0) * 0.05
		var k := 0.96 + 0.08 * _h(int(cv.x * 2.0), 0, int(cv.y * 2.0))
		c = Color((c.r + tint) * k, (c.g + tint) * k, (c.b + tint) * k)
		_put(buf, i, Basis().scaled(Vector3(s, h, s)), Vector3(cv.x, h * 0.5, cv.y), c)
		if s < 1.0 and rng.randf() < 0.02:
			deco_p.append(Vector3(cv.x, h + 0.2, cv.y))
			deco_c.append(jitter(Color(0.55, 0.62, 0.45), 0.05) if rng.randf() < 0.7 else jitter(Color(0.36, 0.31, 0.28), 0.03))
	add_child(_mmi(_mm_buf(buf), mat_voxel))
	add_child(_mmi(_mm_lists(deco_p, deco_c, 0.4), mat_voxel))

	# Story props: a giant ribcage and a dead walker's leg, hinting at danger.
	var pp := PackedVector3Array()
	var pc := PackedColorArray()
	var bone := Color(0.90, 0.87, 0.78)
	var bx := 60.0
	var bz := -44.0
	var by := ground_at(bx, bz)
	for i in 44:
		pp.append(Vector3(bx - 4.0 + i * 0.5, by + 0.75, bz))
		pc.append(jitter(bone, 0.03))
	for rib in 6:
		var rad := 7.0 - rib * 0.6
		for a in 40:
			var ang := PI * a / 39.0
			pp.append(Vector3(bx + rib * 3.0, by + rad * sin(ang), bz + rad * cos(ang)))
			pc.append(jitter(bone, 0.03))
	var a0 := Vector3(120, ground_at(120, 46) + 1, 46)
	var a1 := Vector3(142, ground_at(120, 46) + 9, 56)
	for s in 80:
		var c := a0.lerp(a1, s / 79.0)
		for ox in range(-2, 3):
			for oz in range(-2, 3):
				pp.append(c + Vector3(ox * 0.5, 0, oz * 0.5))
				pc.append(jitter(Color(0.45, 0.25, 0.15), 0.05))
	add_child(_mmi(_mm_lists(pp, pc, 0.5), mat_voxel))


# ---------- City ----------

func _e(x: float, z: float) -> float:
	return pow(x / RXV, 2) + pow(z / RZV, 2)


func _hull_bottom(x: int, z: int) -> int:
	var e := _e(x, z)
	if e > 1.0:
		return 1
	return -6 - int(16.0 * sqrt(1.0 - e))


func _stone(x: int, y: int, z: int) -> int:
	if posmod(y, 3) == 0:
		return P.MORTAR
	return P.STONE if _h(floori(x / 5.0), floori(y / 3.0), floori(z / 5.0)) < 0.55 else P.STONE2


func _paving(x: int, z: int) -> int:
	var d := sqrt(float(x * x + z * z))
	if d < 40.0:
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
	_build_deck()
	_build_wall_ring()
	_build_plaza()
	_build_tower(-118, -15)
	_place_houses()
	_place_trees()
	_build_underside()
	for hip in _hip_positions():
		var hb := Vector3i(hip * RES)
		_sphere(hb.x, hb.y, hb.z, 9.0, P.HULL, P.BRASS)
	_emit_grid()


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
			var seg := int((atan2(float(z), float(x) * RZV / RXV) + PI) / TAU * 160.0)
			if seg % 2 == 0:
				for y in range(8, 11):
					sv(x, y, z, _stone(x, y, z))
	# Lamps along the inside of the wall
	for i in 22:
		var a := TAU * i / 22.0
		var lx := int(cos(a) * RXV * 0.88)
		var lz := int(sin(a) * RZV * 0.88)
		box3(lx, 1, lz, lx, 12, lz, P.IRON)
		box3(lx - 1, 13, lz - 1, lx + 1, 13, lz + 1, P.IRON)
		box3(lx, 14, lz, lx, 15, lz, P.GLOW)
		box3(lx - 1, 16, lz - 1, lx + 1, 16, lz + 1, P.IRON)
		occ[Vector2i(lx / RES, lz / RES)] = true


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
		var a := TAU * i / 6.0 + 0.3
		_parasol(int(cos(a) * 27.0), int(sin(a) * 27.0), cols[i % 3])
	# Flower beds round the plaza edge
	for i in 90:
		var a := TAU * i / 90.0
		if posmod(i, 15) < 3:
			continue
		var fx := int(cos(a) * 39.0)
		var fz := int(sin(a) * 39.0)
		sv(fx, 1, fz, P.LEAF2)
		sv(fx, 2, fz, [P.PURPLE, P.PINK, P.RED, P.PURPLE][i % 4] if _h(fx, 2, fz) < 0.6 else P.LEAF)


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
	var h := 80
	var x1 := x0 + s - 1
	var z1 := z0 + s - 1
	for x in range(x0 / RES - 2, x1 / RES + 2):
		for z in range(z0 / RES - 2, z1 / RES + 2):
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
	for yb in [40, 62, h]:
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
			for y in range(65, 77):
				if y >= 75 and (u == uc - 5 or u == uc + 4):
					continue
				clv(fp(o, a, n, u, y, 0))
		# Narrow lit windows lower down
		for yy in [14, 28, 48]:
			for u in range(uc - 1, uc + 1):
				for y in range(yy, yy + 7):
					clv(fp(o, a, n, u, y, 0))
					svv(fp(o, a, n, u, y, -1), P.WIN_GLOW)
	box3(x0 + 1, 64, z0 + 1, x1 - 1, 64, z1 - 1, P.WOOD_DARK)
	var bcx := (x0 + x1) / 2
	var bcz := (z0 + z1) / 2
	for y in range(66, 74):
		var r := 2.0 + (73 - y) * 0.45
		for dx in range(-6, 7):
			for dz in range(-6, 7):
				var d := sqrt(float(dx * dx + dz * dz))
				if d <= r and d > r - 1.5:
					sv(bcx + dx, y, bcz + dz, P.GOLD)
	box3(bcx, 74, bcz, bcx, 76, bcz, P.IRON)
	# Clock face on the front
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var d := sqrt(float(dx * dx + dy * dy))
			if d <= 6.0:
				sv(bcx + dx, 54 + dy, z0 - 1, P.GOLD if d > 5.0 else P.WHITE)
	for i in 5:
		sv(bcx, 54 + i, z0 - 2, P.IRON)
	for i in 4:
		sv(bcx + i, 54, z0 - 2, P.IRON)
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
	# Keep two main streets clear (along x and along z), then pack houses
	# tightly; neighbours may share walls like an old Mediterranean town.
	var streets := {}
	for i in range(-30, 31):
		for k in range(-1, 2):
			streets[Vector2i(i, k)] = true
			streets[Vector2i(k, i)] = true
	var placed := 0
	for attempt in 6000:
		if placed >= 90:
			break
		var w := rng.randi_range(3, 6)
		var d := rng.randi_range(3, 5)
		var x0 := rng.randi_range(-27, 24)
		var z0 := rng.randi_range(-18, 15)
		var ok := true
		for x in range(x0, x0 + w):
			for z in range(z0, z0 + d):
				if _e(x * RES, z * RES) > 0.82 or occ.has(Vector2i(x, z)) or streets.has(Vector2i(x, z)):
					ok = false
		if not ok:
			continue
		for x in range(x0, x0 + w):
			for z in range(z0, z0 + d):
				occ[Vector2i(x, z)] = true
		var floors := 1
		if rng.randf() < 0.55:
			floors += 1
		if rng.randf() < 0.12:
			floors += 1
		_add_house(x0 * RES, z0 * RES, w * RES, d * RES, floors)
		placed += 1
	print("houses: ", placed)


func _add_house(x0: int, z0: int, w: int, d: int, floors: int) -> void:
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
	var door_side := 0
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


func _door(o: Vector3i, a: Vector3i, n: Vector3i, uc: int) -> void:
	for u in range(uc - 2, uc + 2):
		for y in range(1, 10):
			if y == 9 and (u == uc - 2 or u == uc + 1):
				continue
			clv(fp(o, a, n, u, y, 0))
			svv(fp(o, a, n, u, y, -1), P.WOOD)
	for y in range(1, 11):
		svv(fp(o, a, n, uc - 3, y, 0), P.STONE)
		svv(fp(o, a, n, uc + 2, y, 0), P.STONE)
	for u in range(uc - 3, uc + 3):
		svv(fp(o, a, n, u, 10, 0), P.STONE)
		svv(fp(o, a, n, u, 1, 1), P.STONE2)
	svv(fp(o, a, n, uc, 12, 1), P.GLOW)
	svv(fp(o, a, n, uc, 13, 1), P.IRON)


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
	chimneys.append(Vector3((x + 1) * VS, (ch + 2) * VS, (z + 1) * VS))


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
	for attempt in 600:
		if n >= 26:
			break
		var x := rng.randi_range(-26, 26)
		var z := rng.randi_range(-17, 17)
		if _e(x * RES, z * RES) > 0.82 or x * x + z * z < 81:
			continue
		var free := true
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				if occ.has(Vector2i(x + ox, z + oz)):
					free = false
		if not free:
			continue
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				occ[Vector2i(x + ox, z + oz)] = true
		if rng.randf() < 0.35:
			_cypress(x * RES, z * RES)
		else:
			_olive(x * RES, z * RES)
		n += 1
	# Bushes and flowers along the inside of the wall
	for i in 70:
		var a := rng.randf() * TAU
		var bx := int(cos(a) * RXV * 0.85)
		var bz := int(sin(a) * RZV * 0.85)
		if occ.has(Vector2i(bx / RES, bz / RES)):
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
	var x0 := -30
	var x1 := 30
	var z0 := -20
	var z1 := 20
	var y0 := -45
	var y1 := -14
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				var face_x := x == x0 or x == x1
				var face_z := z == z0 or z == z1
				if not (face_x or face_z or y == y0):
					continue
				var p := P.HULL2 if posmod(y, 8) == 0 else P.HULL
				if (face_x or face_z) and y >= -32 and y <= -30 and posmod(x + z, 6) < 2:
					p = P.GLOW
				sv(x, y, z, p)
	# Lanterns hanging under the hull
	for i in 12:
		var a := TAU * i / 12.0
		var lx := int(cos(a) * RXV * 0.6)
		var lz := int(sin(a) * RZV * 0.6)
		var b := _hull_bottom(lx, lz)
		box3(lx, b - 6, lz, lx, b - 1, lz, P.IRON)
		box3(lx, b - 8, lz, lx, b - 7, lz, P.GLOW)


# ---------- Legs ----------

func _hip_positions() -> Array:
	return [Vector3(17, -2, 12), Vector3(0, -2, 16), Vector3(-17, -2, 12),
			Vector3(17, -2, -12), Vector3(0, -2, -16), Vector3(-17, -2, -12)]


## A hollow square leg segment built along local -Y, with brass bands and rivets.
func _segment_mm(length_m: float, thick: int, base: Color, piston: bool) -> MultiMesh:
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
	return _mm_lists(pts, cols, VS)


func _build_legs() -> void:
	var thigh_mm := _segment_mm(THIGH_LEN, 16, Color(0.28, 0.25, 0.24), false)
	var shin_mm := _segment_mm(SHIN_LEN, 12, Color(0.24, 0.22, 0.21), true)
	var jp := PackedVector3Array()
	var jc := PackedColorArray()
	for dx in range(-13, 14):
		for dy in range(-13, 14):
			for dz in range(-13, 14):
				var d := sqrt(float(dx * dx + dy * dy + dz * dz))
				if d <= 13.0 and d > 11.0:
					jp.append(Vector3(dx, dy, dz) * VS)
					jc.append(jitter(PAL[P.BRASS] if absi(dy) <= 1 else PAL[P.HULL], 0.02))
	var joint_mm := _mm_lists(jp, jc, VS)
	var fp_ := PackedVector3Array()
	var fc := PackedColorArray()
	for dx in range(-15, 16):
		for dz in range(-15, 16):
			var r := sqrt(float(dx * dx + dz * dz))
			if r <= 15.0:
				for dy in 4:
					if dy == 3 or r > 13.5:
						fp_.append(Vector3(dx, dy + 0.5, dz) * VS)
						fc.append(jitter(Color(0.20, 0.18, 0.17) if dy < 3 else PAL[P.HULL], 0.02))
			if r <= 9.0:
				for dy in range(4, 10):
					if r > 7.5 or dy == 9:
						fp_.append(Vector3(dx, dy + 0.5, dz) * VS)
						fc.append(jitter(PAL[P.HULL], 0.02))
	var foot_mm := _mm_lists(fp_, fc, VS)

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
			"thigh": _mmi(thigh_mm, mat_voxel),
			"shin": _mmi(shin_mm, mat_voxel),
			"knee": _mmi(joint_mm, mat_voxel),
			"foot": _mmi(foot_mm, mat_voxel),
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


func _add_smoke() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.84, 0.82)
	mat.roughness = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.3
	mesh.material = mat
	var cu := Curve.new()
	cu.add_point(Vector2(0, 0.4))
	cu.add_point(Vector2(0.3, 1.0))
	cu.add_point(Vector2(1, 0))
	for c in chimneys:
		var p := CPUParticles3D.new()
		p.mesh = mesh
		p.amount = 8
		p.lifetime = 3.0
		p.local_coords = false
		p.direction = Vector3.UP
		p.spread = 12.0
		p.initial_velocity_min = 0.8
		p.initial_velocity_max = 1.2
		p.gravity = Vector3(0, 0.5, 0)
		p.scale_amount_curve = cu
		p.position = c
		city.add_child(p)


# ---------- Residents ----------

func _make_person(shirt: Color, pants: Color, hair: Color, skin: Color) -> MultiMeshInstance3D:
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
	return _mmi(_mm_lists(PackedVector3Array(pts), PackedColorArray(cols), VS), mat_voxel)


func _random_person() -> MultiMeshInstance3D:
	var shirts := [Color(0.16, 0.55, 0.58), Color(0.82, 0.30, 0.26), Color(0.94, 0.80, 0.40),
			Color(0.96, 0.95, 0.90), Color(0.40, 0.52, 0.78), Color(0.55, 0.70, 0.40)]
	var pants := [Color(0.30, 0.24, 0.20), Color(0.24, 0.28, 0.38), Color(0.55, 0.48, 0.38)]
	var hairs := [Color(0.20, 0.13, 0.08), Color(0.45, 0.30, 0.15), Color(0.10, 0.09, 0.08), Color(0.80, 0.70, 0.45)]
	var skins := [Color(0.92, 0.75, 0.62), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.26)]
	return _make_person(shirts[rng.randi() % shirts.size()], pants[rng.randi() % pants.size()],
			hairs[rng.randi() % hairs.size()], skins[rng.randi() % skins.size()])


func _ring_radius() -> float:
	# Two walking rings in the plaza (metres): inside the parasols, or outside them.
	return rng.randf_range(3.1, 3.7) if rng.randf() < 0.5 else rng.randf_range(6.6, 7.4)


func _add_residents() -> void:
	# You: standing in the plaza (used by the close camera)
	resident = Node3D.new()
	# Between two parasols, facing out from the fountain toward the houses
	var ra := 5.01
	resident.position = Vector3(cos(ra) * 5.0, VS * 0.5, sin(ra) * 5.0)
	resident.rotation.y = -ra
	resident.add_child(_make_person(Color(0.16, 0.55, 0.58), Color(0.30, 0.24, 0.20),
			Color(0.20, 0.13, 0.08), Color(0.92, 0.75, 0.62)))
	city.add_child(resident)
	for i in WALKERS:
		var node := Node3D.new()
		node.add_child(_random_person())
		city.add_child(node)
		var r := _ring_radius()
		walkers.append({"node": node, "a": rng.randf() * TAU, "r": r, "ta": rng.randf() * TAU,
				"tr": r, "wait": rng.randf() * 3.0, "speed": rng.randf_range(0.9, 1.4)})


func _update_walkers(delta: float) -> void:
	for w in walkers:
		var node: Node3D = w["node"]
		if w["wait"] > 0.0:
			w["wait"] -= delta
			node.position.y = VS * 0.5
			continue
		var da := wrapf(w["ta"] - w["a"], -PI, PI)
		var dr: float = w["tr"] - w["r"]
		var r: float = w["r"]
		var step: float = w["speed"] * delta / maxf(r, 1.0)
		if absf(da) < 0.02 and absf(dr) < 0.05:
			w["wait"] = rng.randf_range(1.0, 5.0)
			w["ta"] = w["a"] + rng.randf_range(-1.6, 1.6)
			w["tr"] = _ring_radius() if rng.randf() < 0.3 else r
			continue
		var dir := signf(da)
		w["a"] += clampf(da, -step, step)
		w["r"] += clampf(dr, -0.6 * delta, 0.6 * delta)
		var a: float = w["a"]
		r = w["r"]
		node.position = Vector3(cos(a) * r, VS * 0.5 + absf(sin(t * 9.0 + a * 5.0)) * 0.05, sin(a) * r)
		# Face the way they walk (person mesh faces +x)
		var tangent := Vector3(-sin(a), 0, cos(a)) * dir + Vector3(cos(a), 0, sin(a)) * signf(dr) * 0.3
		node.rotation.y = atan2(-tangent.z, tangent.x)


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
	var body_x := CITY_SPEED * t
	if body_x > 230.0:
		t -= 220.0 / CITY_SPEED
		body_x = CITY_SPEED * t
	var period := 2.0 * STEP_LENGTH / CITY_SPEED
	var bob := -0.6 * absf(sin(TAU * t / period))
	city.position = Vector3(body_x, CITY_HEIGHT + bob, 0)
	city.rotation.x = 0.012 * sin(TAU * t / period)

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
		leg["prev_p"] = p

	_update_camera()


func _update_camera() -> void:
	var c := city.global_position
	var pos: Vector3
	var look: Vector3
	match view:
		0:
			var ang := 0.75 + (t * 0.03 if not paused else 0.0)
			pos = c + Vector3(cos(ang) * 82.0, 26.0, sin(ang) * 82.0)
			look = c + Vector3(0, -8, 0)
		1:
			pos = c + Vector3(38, -20, 44)
			look = c + Vector3(0, -2, 0)
		2:
			pos = c + Vector3(-70, 70, 90)
			look = c + Vector3(25, -18, 0)
		3:
			pos = c + Vector3(26, 14, 26)
			look = c + Vector3(-4, 1, 0)
		4:
			# Close third-person: just behind the resident's shoulder
			var r := resident.global_position
			var out := (r - c) * Vector3(1, 0, 1)
			out = out.normalized()
			pos = r - out * 2.4 + Vector3(0, 2.3, 0)
			look = r + out * 8.0 + Vector3(0, 1.0, 0)
		_:
			# Zoomed-out diorama: the whole town from above, like a model
			pos = c + Vector3(30, 42, 30)
			look = c
	var attr: CameraAttributesPractical = camera.attributes
	attr.dof_blur_near_enabled = view != 4
	attr.dof_blur_far_distance = 75.0 if view == 5 else 140.0
	attr.dof_blur_near_distance = 40.0 if view == 5 else 30.0
	camera.fov = 28.0 if view == 5 else (65.0 if view == 4 else 50.0)
	camera.global_position = pos
	camera.look_at(look)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: view = 0
			KEY_2: view = 1
			KEY_3: view = 2
			KEY_4: view = 3
			KEY_5: view = 4
			KEY_6: view = 5
			KEY_SPACE: paused = not paused
			KEY_ESCAPE: get_tree().quit()


func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	for v in 6:
		view = v
		for i in 50:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://shots/view_%d.png" % v)
	get_tree().quit()
