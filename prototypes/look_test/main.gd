extends Node3D
## LOOK TEST: a voxel walking city crossing a wasteland.
## Everything is built from code, with no image or model files.
## Throwaway prototype, only here to judge the art style.
## Keys: 1-6 change camera, Space pauses, Esc quits.
## Run with "-- --shots" to save screenshots to shots/ and quit.

# --- Tuning (safe to tweak) ---
const CITY_SPEED := 4.0      # how fast the city walks
const STEP_LENGTH := 14.0    # how far each foot moves per step
const STEP_LIFT := 5.0       # how high feet lift
const CITY_HEIGHT := 24.0    # deck height above the ground
const THIGH_LEN := 13.0
const SHIN_LEN := 30.0
const LEG_REACH := 24.0      # how far out to the side the feet land
const SEED := 7

# City shape (an oval deck)
const RX := 28.0
const RZ := 19.0

const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

# Palette
const C_PAVING := Color(0.78, 0.74, 0.66)
const C_STONE := Color(0.70, 0.62, 0.52)
const C_HULL := Color(0.30, 0.26, 0.24)
const C_BRASS := Color(0.78, 0.60, 0.28)
const C_TERRACOTTA := Color(0.76, 0.36, 0.22)
const C_WOOD := Color(0.45, 0.28, 0.16)
const C_GLOW := Color(1.0, 0.62, 0.30)
const WALLS := [Color(0.94, 0.90, 0.81), Color(0.95, 0.94, 0.90), Color(0.93, 0.81, 0.60),
		Color(0.92, 0.77, 0.70), Color(0.76, 0.84, 0.90)]
const SHUTTERS := [Color(0.20, 0.42, 0.68), Color(0.16, 0.55, 0.58)]

var mat_voxel: StandardMaterial3D
var mat_glow: StandardMaterial3D
var box: BoxMesh
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()

var city: Node3D
var resident: Node3D
var camera: Camera3D
var legs := []
var chimneys := []
var t := 2.0
var paused := false
var view := 0
var help: Label


func _ready() -> void:
	rng.seed = SEED
	noise.seed = SEED
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	_make_materials()
	_make_world()
	_build_ground()
	_build_city()
	_build_legs()
	_add_smoke()
	_add_resident()
	if "--shots" in OS.get_cmdline_user_args():
		help.visible = false
		_run_shots()


# ---------- Setup ----------

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
	mat_glow.emission_energy_multiplier = 1.0


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
	env.ambient_light_color = Color(0.55, 0.66, 0.82)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.96, 0.82, 0.66)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Low golden-hour sun from the camera's left, for long shadows.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -30, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
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
	cam_attr.dof_blur_amount = 0.08
	camera.attributes = cam_attr
	add_child(camera)

	var layer := CanvasLayer.new()
	help = Label.new()
	help.text = "1-6: camera   Space: pause   Esc: quit"
	help.position = Vector2(16, 12)
	help.add_theme_font_size_override("font_size", 18)
	layer.add_child(help)
	add_child(layer)


# ---------- Voxel helpers ----------

func jitter(c: Color, amt := 0.04) -> Color:
	var j := rng.randf_range(-amt, amt)
	return Color(clampf(c.r + j, 0, 1), clampf(c.g + j, 0, 1), clampf(c.b + j, 0, 1))


func _buried(p: Vector3i, solid: Dictionary) -> bool:
	for d in DIRS:
		if not solid.has(p + d):
			return false
	return true


func _mm(points: Array, colors: Array, transforms := []) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = points.size()
	for i in points.size():
		var xf: Transform3D = transforms[i] if transforms.size() > 0 else Transform3D(Basis(), points[i])
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, colors[i])
	return mm


## Turns a {Vector3i: Color} dictionary into a MultiMesh node, skipping hidden voxels.
func _mmi_from_cells(cells: Dictionary, mat: Material, solid: Dictionary) -> MultiMeshInstance3D:
	var pts := []
	var cols := []
	for p in cells:
		if _buried(p, solid):
			continue
		pts.append(Vector3(p))
		cols.append(cells[p])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm(pts, cols)
	mmi.material_override = mat
	return mmi


func _mmi(mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


# ---------- Ground ----------

func ground_h(x: float, z: float) -> int:
	var n := noise.get_noise_2d(x, z)
	var h := 2.0 + n * 1.5
	var az := absf(z)
	if az > 45.0:
		var m := smoothstep(45.0, 85.0, az)
		h += m * (6.0 + 12.0 * maxf(0.0, noise.get_noise_2d(x * 0.5 + 300.0, z * 0.5)))
	return maxi(1, int(round(h)))


func _build_ground() -> void:
	var pts := []
	var cols := []
	var xfs := []
	var deco_p := []
	var deco_c := []
	for x in range(-80, 301):
		for z in range(-150, 151):
			var h := ground_h(x, z)
			var c: Color
			if h <= 2:
				c = Color(0.82, 0.70, 0.52)
			elif h <= 4:
				c = Color(0.75, 0.60, 0.42)
			elif h <= 10:
				c = Color(0.66, 0.47, 0.33) if h % 2 == 0 else Color(0.71, 0.53, 0.37)
			else:
				c = Color(0.48, 0.40, 0.34)
			var r := rng.randf()
			if r < 0.012:
				deco_p.append(Vector3(x, h + 0.5, z))
				deco_c.append(jitter(Color(0.55, 0.62, 0.45), 0.05))
			elif r < 0.018:
				deco_p.append(Vector3(x, h + 0.5, z))
				deco_c.append(jitter(Color(0.36, 0.31, 0.28), 0.03))
			var tint := noise.get_noise_2d(x * 2.0 + 900.0, z * 2.0) * 0.05
			c = jitter(Color(c.r + tint, c.g + tint, c.b + tint), 0.025)
			pts.append(Vector3(x, h * 0.5, z))
			cols.append(c)
			xfs.append(Transform3D(Basis().scaled(Vector3(1, h, 1)), Vector3(x, h * 0.5, z)))
	add_child(_mmi(_mm(pts, cols, xfs), mat_voxel))
	add_child(_mmi(_mm(deco_p, deco_c), mat_voxel))

	# Story props: a giant ribcage and a dead walker's leg, hinting at danger.
	var props := {}
	var bx := 60
	var bz := -44
	var by := ground_h(bx, bz)
	for i in range(0, 22):
		props[Vector3i(bx + i - 4, by + 1, bz)] = jitter(Color(0.90, 0.87, 0.78), 0.03)
	for r in 6:
		var rx := bx + r * 3
		for a in range(0, 19):
			var ang := PI * a / 18.0
			var rad := 7.0 - r * 0.6
			var p := Vector3i(rx, by + int(rad * sin(ang)), bz + int(rad * cos(ang)))
			props[p] = jitter(Color(0.90, 0.87, 0.78), 0.03)
	var a0 := Vector3(120, ground_h(120, 46) + 1, 46)
	var a1 := Vector3(142, ground_h(120, 46) + 9, 56)
	for s in 40:
		var c := a0.lerp(a1, s / 39.0)
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				props[Vector3i(c) + Vector3i(ox, 0, oz)] = jitter(Color(0.45, 0.25, 0.15), 0.05)
	add_child(_mmi_from_cells(props, mat_voxel, props))


# ---------- City ----------

func _deck_e(x: float, z: float, shrink := 1.0) -> float:
	return pow(x / (RX * shrink), 2) + pow(z / (RZ * shrink), 2)


func _build_city() -> void:
	city = Node3D.new()
	add_child(city)
	var cv := {}
	var cg := {}
	var shrinks := [0.74, 0.84, 0.92, 0.97, 1.0]

	# Hull and deck
	for y in range(-4, 1):
		var shrink: float = shrinks[y + 4]
		for x in range(-30, 31):
			for z in range(-21, 22):
				var e := _deck_e(x, z, shrink)
				if e > 1.0:
					continue
				var c: Color
				if y == 0:
					c = jitter(C_PAVING, 0.05)
					if Vector2(x, z).length() < 6.5:
						c = jitter(Color(0.86, 0.80, 0.68), 0.03) if (x + z) % 2 == 0 else jitter(Color(0.80, 0.72, 0.60), 0.03)
				elif y == -1:
					c = jitter(Color(0.42, 0.29, 0.19), 0.015)
				else:
					var plate := (floori(x / 4.0) + floori(z / 4.0)) % 2 == 0
					c = Color(0.27, 0.24, 0.22) if plate else Color(0.32, 0.28, 0.25)
					if y == -2 and e > 0.9 and (x + z) % 3 == 0:
						c = C_BRASS
				cv[Vector3i(x, y, z)] = c

	# Edge wall with battlements, and lamps
	for x in range(-30, 31):
		for z in range(-21, 22):
			var e := _deck_e(x, z)
			if e > 1.0 or e < 0.88:
				continue
			cv[Vector3i(x, 1, z)] = jitter(C_STONE, 0.04)
			cv[Vector3i(x, 2, z)] = jitter(C_STONE, 0.04)
			if (x + z) % 2 == 0:
				cv[Vector3i(x, 3, z)] = jitter(C_STONE, 0.04)
	for i in 18:
		var ang := TAU * i / 18.0
		var lx := int(round(cos(ang) * RX * 0.88))
		var lz := int(round(sin(ang) * RZ * 0.88))
		for y in range(1, 5):
			cv[Vector3i(lx, y, lz)] = jitter(Color(0.2, 0.18, 0.17), 0.02)
		cg[Vector3i(lx, 5, lz)] = C_GLOW

	var occ := {}
	# Bell tower at the back
	_add_tower(cv, cg, -18, -3)
	for x in range(-20, -12):
		for z in range(-5, 3):
			occ[Vector2i(x, z)] = true

	# Plaza: fountain + market stalls
	for x in range(-4, 5):
		for z in range(-4, 5):
			var d := Vector2(x, z).length()
			if d >= 2.5 and d < 3.5:
				cv[Vector3i(x, 1, z)] = jitter(C_STONE, 0.03)
			elif d < 2.5:
				cv[Vector3i(x, 1, z)] = jitter(Color(0.38, 0.62, 0.78), 0.03)
	for y in range(1, 4):
		cv[Vector3i(0, y, 0)] = jitter(C_STONE, 0.03)
	cg[Vector3i(0, 4, 0)] = C_GLOW
	var stalls := [Vector2i(4, -6), Vector2i(-6, 3), Vector2i(3, 4), Vector2i(-5, -6)]
	var awnings := [Color(0.75, 0.25, 0.20), Color(0.90, 0.70, 0.25), Color(0.30, 0.50, 0.70), Color(0.75, 0.25, 0.20)]
	for s in stalls.size():
		var p: Vector2i = stalls[s]
		for cx in [0, 2]:
			for cz in [0, 1]:
				for y in range(1, 3):
					cv[Vector3i(p.x + cx, y, p.y + cz)] = C_WOOD
		for x in range(-1, 4):
			for z in range(-1, 3):
				cv[Vector3i(p.x + x, 3, p.y + z)] = awnings[s] if (x % 2 == 0) else Color(0.95, 0.92, 0.85)
		cv[Vector3i(p.x + 1, 1, p.y)] = jitter(Color(0.55, 0.36, 0.20), 0.05)

	# Houses
	var placed := 0
	for attempt in 2500:
		if placed >= 70:
			break
		var w := rng.randi_range(3, 5)
		var d := rng.randi_range(3, 5)
		var x0 := rng.randi_range(-26, 24)
		var z0 := rng.randi_range(-18, 16)
		var ok := true
		for x in range(x0 - 1, x0 + w + 1):
			for z in range(z0 - 1, z0 + d + 1):
				if _deck_e(x, z) > 0.8 or Vector2(x, z).length() < 8.0 or occ.has(Vector2i(x, z)):
					ok = false
		if not ok:
			continue
		for x in range(x0, x0 + w):
			for z in range(z0, z0 + d):
				occ[Vector2i(x, z)] = true
		_add_house(cv, cg, x0, z0, w, d, rng.randi_range(3, 6))
		placed += 1

	# Trees in the gaps
	var trees := 0
	for attempt in 300:
		if trees >= 14:
			break
		var x := rng.randi_range(-26, 26)
		var z := rng.randi_range(-17, 17)
		if _deck_e(x, z) > 0.8 or Vector2(x, z).length() < 7.0:
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
		if rng.randf() < 0.3:
			_add_cypress(cv, x, z)
		else:
			_add_olive(cv, x, z)
		trees += 1

	# Underside: boiler with glowing vents, and brass leg mounts
	for x in range(-6, 6):
		for z in range(-4, 4):
			for y in range(-8, -4):
				var edge := x == -6 or x == 5 or z == -4 or z == 3
				if edge and y == -6 and (x + z) % 2 == 0:
					cg[Vector3i(x, y, z)] = C_GLOW
				else:
					cv[Vector3i(x, y, z)] = jitter(Color(0.24, 0.21, 0.20), 0.03)
	for hip in _hip_positions():
		var hp := Vector3i(hip)
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				for oz in range(-1, 2):
					cv[hp + Vector3i(ox, oy, oz)] = jitter(C_BRASS, 0.04)

	var solid := cv.duplicate()
	solid.merge(cg)
	city.add_child(_mmi_from_cells(cv, mat_voxel, solid))
	city.add_child(_mmi_from_cells(cg, mat_glow, {}))


func _add_house(cv: Dictionary, cg: Dictionary, x0: int, z0: int, w: int, d: int, h: int) -> void:
	var r := rng.randf()
	var wall: Color = WALLS[0 if r < 0.35 else 1 if r < 0.6 else 2 if r < 0.8 else 3 if r < 0.92 else 4]
	var shutter: Color = SHUTTERS[rng.randi_range(0, 1)]
	var x1 := x0 + w - 1
	var z1 := z0 + d - 1
	for y in range(1, h + 1):
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				var on_x := x == x0 or x == x1
				var on_z := z == z0 or z == z1
				if not (on_x or on_z):
					continue
				var p := Vector3i(x, y, z)
				if not (on_x and on_z) and y >= 2 and y < h and y % 2 == 0 and (x + z) % 2 == 0:
					if rng.randf() < 0.4:
						cg[p] = C_GLOW
					else:
						cv[p] = jitter(shutter, 0.03)
					continue
				cv[p] = jitter(wall, 0.015)
	# Door on the front
	var dx := x0 + w / 2
	cv[Vector3i(dx, 1, z0)] = C_WOOD
	cv[Vector3i(dx, 2, z0)] = C_WOOD

	if rng.randf() < 0.35:
		# Flat roof terrace with a parapet and a potted plant
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				cv[Vector3i(x, h + 1, z)] = jitter(wall, 0.02)
				if x == x0 or x == x1 or z == z0 or z == z1:
					if (x + z) % 2 == 0:
						cv[Vector3i(x, h + 2, z)] = jitter(wall, 0.02)
		cv[Vector3i(x0 + 1, h + 2, z0 + 1)] = jitter(C_TERRACOTTA, 0.03)
		cv[Vector3i(x0 + 1, h + 3, z0 + 1)] = jitter(Color(0.35, 0.55, 0.28), 0.05)
	else:
		# Stepped tile roof with overhang
		var rx0 := x0 - 1
		var rx1 := x1 + 1
		var rz0 := z0 - 1
		var rz1 := z1 + 1
		var layer := 0
		while rx0 <= rx1 and rz0 <= rz1:
			for x in range(rx0, rx1 + 1):
				for z in range(rz0, rz1 + 1):
					cv[Vector3i(x, h + 1 + layer, z)] = jitter(C_TERRACOTTA, 0.05)
			rx0 += 1
			rx1 -= 1
			rz0 += 1
			rz1 -= 1
			layer += 1
		if rng.randf() < 0.5:
			var top := h + layer + 1
			for y in range(h + 1, top + 1):
				cv[Vector3i(x1, y, z1)] = jitter(C_STONE, 0.03)
			chimneys.append(Vector3(x1, top + 1, z1))


func _add_tower(cv: Dictionary, cg: Dictionary, x0: int, z0: int) -> void:
	var top := 13
	for y in range(1, top + 1):
		for x in range(x0, x0 + 4):
			for z in range(z0, z0 + 4):
				var on_x := x == x0 or x == x0 + 3
				var on_z := z == z0 or z == z0 + 3
				if not (on_x or on_z):
					continue
				var p := Vector3i(x, y, z)
				if (y == 10 or y == 11) and not (on_x and on_z):
					cg[p] = C_GLOW
				else:
					cv[p] = jitter(WALLS[0], 0.015)
	var layer := 0
	var lo := -1
	var hi := 4
	while lo <= hi:
		for x in range(x0 + lo, x0 + hi + 1):
			for z in range(z0 + lo, z0 + hi + 1):
				cv[Vector3i(x, top + 1 + layer, z)] = jitter(C_TERRACOTTA, 0.05)
		lo += 1
		hi -= 1
		layer += 1
	var sx := x0 + 1
	var sz := z0 + 1
	var sy := top + 1 + layer
	for y in range(sy, sy + 3):
		cv[Vector3i(sx, y, sz)] = Color(0.95, 0.78, 0.30)
	for fx in range(1, 4):
		for fy in range(0, 2):
			cv[Vector3i(sx + fx, sy + 2 - fy, sz)] = Color(0.80, 0.18, 0.15)


func _add_cypress(cv: Dictionary, x: int, z: int) -> void:
	var h := rng.randi_range(5, 7)
	cv[Vector3i(x, 1, z)] = C_WOOD
	for y in range(2, h + 1):
		cv[Vector3i(x, y, z)] = jitter(Color(0.20, 0.36, 0.22), 0.04)
		if y > 2 and y < h - 1:
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				cv[Vector3i(x, y, z) + d] = jitter(Color(0.22, 0.40, 0.23), 0.04)


func _add_olive(cv: Dictionary, x: int, z: int) -> void:
	for y in range(1, 4):
		cv[Vector3i(x, y, z)] = C_WOOD
	for ox in range(-2, 3):
		for oy in range(-1, 2):
			for oz in range(-2, 3):
				if Vector3(ox, oy * 1.4, oz).length() <= 2.3 and rng.randf() < 0.9:
					cv[Vector3i(x + ox, 5 + oy, z + oz)] = jitter(Color(0.47, 0.57, 0.30), 0.05)


# ---------- Legs ----------

func _hip_positions() -> Array:
	return [Vector3(17, -2, 12), Vector3(0, -2, 16), Vector3(-17, -2, 12),
			Vector3(17, -2, -12), Vector3(0, -2, -16), Vector3(-17, -2, -12)]


func _segment_mm(length: int, thick: int, base: Color) -> MultiMesh:
	var pts := []
	var cols := []
	var offs := []
	for k in thick:
		offs.append(k - (thick - 1) * 0.5)
	for i in length:
		for ox in offs:
			for oz in offs:
				pts.append(Vector3(ox, -i - 0.5, oz))
				cols.append(C_BRASS if i == 1 or i == length - 2 else jitter(base, 0.03))
	return _mm(pts, cols)


func _build_legs() -> void:
	var thigh_mm := _segment_mm(int(THIGH_LEN), 4, Color(0.28, 0.25, 0.24))
	var shin_mm := _segment_mm(int(SHIN_LEN), 3, Color(0.24, 0.22, 0.21))
	var jp := []
	var jc := []
	for ox in range(4):
		for oy in range(4):
			for oz in range(4):
				jp.append(Vector3(ox - 1.5, oy - 1.5, oz - 1.5))
				jc.append(jitter(C_BRASS, 0.04) if oy == 1 else jitter(C_HULL, 0.02))
	var joint_mm := _mm(jp, jc)
	var fp := []
	var fc := []
	for ox in range(-2, 3):
		for oz in range(-2, 3):
			fp.append(Vector3(ox, 0.5, oz))
			fc.append(jitter(Color(0.20, 0.18, 0.17), 0.03))
	for ox in range(-1, 2):
		for oz in range(-1, 2):
			fp.append(Vector3(ox, 1.5, oz))
			fc.append(jitter(C_HULL, 0.03))
	var foot_mm := _mm(fp, fc)

	var dust_mat := StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.80, 0.68, 0.52)
	dust_mat.roughness = 1.0
	var dust_mesh := BoxMesh.new()
	dust_mesh.size = Vector3.ONE * 0.8
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
	p.amount = 28
	p.lifetime = 1.8
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -1.5, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
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
	mesh.size = Vector3.ONE * 0.5
	mesh.material = mat
	var cu := Curve.new()
	cu.add_point(Vector2(0, 0.4))
	cu.add_point(Vector2(0.3, 1.0))
	cu.add_point(Vector2(1, 0))
	for c in chimneys:
		var p := CPUParticles3D.new()
		p.mesh = mesh
		p.amount = 6
		p.lifetime = 3.0
		p.local_coords = false
		p.direction = Vector3.UP
		p.spread = 12.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 1.6
		p.gravity = Vector3(0, 0.6, 0)
		p.scale_amount_curve = cu
		p.position = c
		city.add_child(p)


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
		var ground := float(ground_h(round(fx), round(fz)))
		var foot := Vector3(fx, ground + lift, fz)
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
			pos = r + Vector3(3.0, 1.9, 0.9)
			look = r + Vector3(-6, 1.0, -0.4)
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


## A tiny voxel resident standing in the plaza, for judging camera views.
func _add_resident() -> void:
	resident = Node3D.new()
	resident.position = Vector3(4.5, 0.5, -1.5)
	city.add_child(resident)
	var parts := [
		[Vector3(0.18, 0.6, 0.18), Vector3(0, 0.3, -0.12), Color(0.30, 0.24, 0.20)],
		[Vector3(0.18, 0.6, 0.18), Vector3(0, 0.3, 0.12), Color(0.30, 0.24, 0.20)],
		[Vector3(0.30, 0.6, 0.48), Vector3(0, 0.9, 0), Color(0.16, 0.55, 0.58)],
		[Vector3(0.14, 0.5, 0.14), Vector3(0, 0.95, -0.32), Color(0.16, 0.55, 0.58)],
		[Vector3(0.14, 0.5, 0.14), Vector3(0, 0.95, 0.32), Color(0.16, 0.55, 0.58)],
		[Vector3(0.36, 0.36, 0.36), Vector3(0, 1.42, 0), Color(0.88, 0.70, 0.55)],
		[Vector3(0.40, 0.14, 0.40), Vector3(0.02, 1.64, 0), Color(0.25, 0.16, 0.10)],
		[Vector3(0.26, 0.36, 0.40), Vector3(0.22, 0.95, 0), Color(0.55, 0.36, 0.20)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		var m := StandardMaterial3D.new()
		m.albedo_color = p[2]
		m.roughness = 0.9
		bm.material = m
		mi.mesh = bm
		mi.position = p[1]
		resident.add_child(mi)


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
