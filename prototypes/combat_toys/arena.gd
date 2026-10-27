extends Node3D
## THE NIGHT DESERT both fights happen in: a flat patch of rippled sand ringed by rocks,
## dunes beyond, an old rib-bone arch, a wrecked cart, the walking city kneeling in the
## distance with its windows lit, and a moonlit, starry sky. Only looks.

const Vox := preload("res://vox.gd")
const RADIUS := 18.0      # the open fighting ground (metres from the centre)
const GB := 0.4           # ground block size
const HALF := 60.0        # the ground reaches this far from the centre

var env: Environment
var moon: DirectionalLight3D
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _mat: StandardMaterial3D
var _glow: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 2026
	_noise.seed = 5
	_noise.frequency = 0.035
	_mat = Vox.material()
	_glow = Vox.glow_material(2.2)
	_sky()
	_ground()
	_rocks()
	_ribs(Vector3(-24, 0, 14), 0.6)
	_cart(Vector3(16.5, 0, 12.0))
	_city(Vector3(10, 0, -120))
	_drifting_sand()


## Height of the sand (metres). Flat inside the fighting ring, dunes beyond it.
func height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var dune := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 6.0 + sin(x * 0.07 + z * 0.03) * 1.2
	return maxf(0.0, dune) * smoothstep(RADIUS + 2.0, RADIUS + 16.0, d)


func _sky() -> void:
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.015, 0.025, 0.07)
	psm.sky_horizon_color = Color(0.09, 0.11, 0.20)
	psm.ground_horizon_color = Color(0.07, 0.08, 0.13)
	psm.ground_bottom_color = Color(0.02, 0.02, 0.04)
	psm.sun_angle_max = 1.0
	var sky := Sky.new()
	sky.sky_material = psm
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.55)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.12, 0.22)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation_degrees = Vector3(-38, 150, 0)
	add_child(moon)
	# The moon itself, far off in the direction its light comes from
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 9.0
	sm.height = 18.0
	disc.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.6, 1.6, 1.45)
	mm.disable_fog = true
	disc.material_override = mm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # or it shades the whole arena
	disc.position = moon.global_transform.basis.z * 380.0
	add_child(disc)
	# Stars
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.billboard_keep_scale = true
	star_mat.vertex_color_use_as_albedo = true
	star_mat.disable_fog = true
	q.material = star_mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = q
	multi.instance_count = 900
	for i in multi.instance_count:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.04, 1.0), _rng.randf_range(-1, 1)).normalized()
		var s := _rng.randf_range(0.4, 1.4) * (1.6 if _rng.randf() < 0.05 else 1.0)
		multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), dir * 420.0))
		var b := _rng.randf_range(0.5, 1.6)
		multi.set_instance_color(i, Color(b, b, b * _rng.randf_range(0.9, 1.2)))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = multi
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)


## The sand: columns of blocks, only the faces you can see, with wind ripples on the flat.
func _ground() -> void:
	var n := int(HALF * 2.0 / GB)
	var h := PackedInt32Array()
	h.resize(n * n)
	for i in n:
		for j in n:
			h[i * n + j] = int(round(height(-HALF + (i + 0.5) * GB, -HALF + (j + 0.5) * GB) / GB))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var sand := Color(0.66, 0.55, 0.42)
	for i in n:
		for j in n:
			var x := -HALF + i * GB
			var z := -HALF + j * GB
			var top := h[i * n + j]
			var y := top * GB
			var ripple := sin((x * 0.9 + z * 0.35) * 2.6 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 3.0)
			var c := sand.darkened(0.06 * (ripple * 0.5 + 0.5)).lightened(0.05 * _noise.get_noise_2d(z * 2.0, x * 2.0))
			if _rng.randf() < 0.02:
				c = c.darkened(0.2)    # a pebble
			_quad(verts, norms, cols, Vector3(x, y, z), Vector3(GB, 0, 0), Vector3(0, 0, GB), Vector3.UP, c)
			# Sides down to lower neighbours
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var ni: int = i + d[0]
				var nj: int = j + d[1]
				if ni < 0 or nj < 0 or ni >= n or nj >= n:
					continue
				var low := h[ni * n + nj]
				if low >= top:
					continue
				var sc := c.darkened(0.12)
				for k in range(low, top):
					var yy := k * GB
					if d[0] == 1:
						_quad(verts, norms, cols, Vector3(x + GB, yy, z), Vector3(0, GB, 0), Vector3(0, 0, GB), Vector3.RIGHT, sc)
					elif d[0] == -1:
						_quad(verts, norms, cols, Vector3(x, yy, z), Vector3(0, 0, GB), Vector3(0, GB, 0), Vector3.LEFT, sc)
					elif d[1] == 1:
						_quad(verts, norms, cols, Vector3(x, yy, z + GB), Vector3(GB, 0, 0), Vector3(0, GB, 0), Vector3.BACK, sc)
					else:
						_quad(verts, norms, cols, Vector3(x, yy, z), Vector3(0, GB, 0), Vector3(GB, 0, 0), Vector3.FORWARD, sc)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, _mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add_child(mi)


## One square (two triangles) from corner o along a and b, facing `nrm`.
func _quad(v: PackedVector3Array, nr: PackedVector3Array, c: PackedColorArray, o: Vector3, a: Vector3, b: Vector3, nrm: Vector3, col: Color) -> void:
	var p := [o, o + a, o + a + b, o + b]
	var order := [0, 1, 2, 0, 2, 3]
	if (a.cross(b)).dot(nrm) > 0.0:
		order = [0, 2, 1, 0, 3, 2]   # Godot draws the clockwise side
	for k in order:
		v.append(p[k])
		nr.append(nrm)
		c.append(col)


## Boulders round the edge of the fighting ground.
func _rocks() -> void:
	var cells := {}
	var count := 34
	for r in count:
		var a := TAU * r / count + _rng.randf_range(-0.06, 0.06)
		var dist := RADIUS + _rng.randf_range(1.5, 4.0)
		var cx := int(round(cos(a) * dist / GB))
		var cz := int(round(sin(a) * dist / GB))
		var size := _rng.randf_range(2.0, 5.5)
		var base := Color(0.42, 0.36, 0.31).lerp(Color(0.55, 0.47, 0.38), _rng.randf())
		var rs := int(ceil(size))
		for x in range(-rs, rs + 1):
			for z in range(-rs, rs + 1):
				for y in range(0, rs * 2):
					var e := pow(x / size, 2) + pow((y - 1) / (size * 1.1), 2) + pow(z / size, 2)
					if e <= 1.0 + _noise.get_noise_3d(x * 9.0 + cx, y * 9.0, z * 9.0) * 0.35:
						var c := base.darkened(0.15) if y < 2 else base
						if y > size * 0.9:
							c = c.lightened(0.08)
						cells[Vector3i(cx + x, y, cz + z)] = Vox.vary(c, _rng, 0.03)
	add_child(Vox.node(cells, _mat, Vector3(0, GB * 0.5, 0), GB))


## Giant rib bones arching out of the sand: something huge died here long ago.
func _ribs(at: Vector3, turn: float) -> void:
	var cells := {}
	var bone := Color(0.86, 0.80, 0.68)
	for k in 5:
		var off := (k - 2) * 2.6
		var span := 7.0 - absf(k - 2) * 1.2
		for i in 60:
			var t := i / 59.0
			var p := Vector3(cos(PI * t) * span, sin(PI * t) * span * 1.3, off)
			var thick := 1 if t > 0.2 and t < 0.8 else 2
			for dx in range(-thick + 1, thick):
				for dy in range(-thick + 1, thick):
					cells[Vector3i(int(round(p.x / GB)) + dx, int(round(p.y / GB)) + dy, int(round(p.z / GB)))] = bone.darkened(0.1 * absf(sin(i * 0.7)))
	var spine := Color(0.78, 0.72, 0.60)
	for z in range(int(-6.0 / GB), int(6.0 / GB)):
		cells[Vector3i(0, int(9.0 / GB), z)] = spine
	var n := Vox.node(cells, _mat, Vector3.ZERO, GB)
	n.position = at + Vector3(0, -0.6, 0)
	n.rotation.y = turn
	add_child(n)


## A small wrecked cart, half sunk, with a broken wheel.
func _cart(at: Vector3) -> void:
	var cells := {}
	var wood := Color(0.40, 0.28, 0.18)
	Vox.box(cells, Vector3i(-6, 2, -3), Vector3i(6, 2, 3), wood)
	Vox.box(cells, Vector3i(-6, 3, -3), Vector3i(6, 4, -3), wood.darkened(0.15))
	Vox.box(cells, Vector3i(-6, 3, 3), Vector3i(-1, 4, 3), wood.darkened(0.15))
	Vox.box(cells, Vector3i(6, 3, -3), Vector3i(6, 5, 3), wood.darkened(0.1))
	for a in 16:
		var p := Vector2(cos(TAU * a / 16.0), sin(TAU * a / 16.0)) * 3.0
		if a < 11:
			cells[Vector3i(int(round(p.x)) - 3, int(round(p.y)) + 2, 4)] = Color(0.30, 0.21, 0.14)
	var n := Vox.node(cells, _mat, Vector3.ZERO, 0.25)
	n.position = at + Vector3(0, -0.2, 0)
	n.rotation = Vector3(0.12, 0.7, 0.18)
	add_child(n)


## The walking city, far off, kneeling for the night: a dark hull on folded legs,
## terraces of pale houses with warm windows, and the tower in the middle.
func _city(at: Vector3) -> void:
	var b := 1.5
	var hull := {}
	var lit := {}
	var hull_c := Color(0.20, 0.18, 0.17)
	for x in range(-22, 23):
		for z in range(-15, 16):
			var q := pow(absf(x) / 22.0, 3) + pow(absf(z) / 15.0, 3)
			if q > 1.0:
				continue
			var depth := int(4.0 * (1.0 - q * q))
			for y in range(-depth, 1):
				hull[Vector3i(x, y + 6, z)] = hull_c.lerp(Color(0.30, 0.26, 0.23), _rng.randf() * 0.3)
			# Houses on terraces: higher toward the middle
			var tier := 1 + int(3.0 * (1.0 - q))
			if _rng.randf() < 0.55:
				var top := 6 + tier + _rng.randi_range(0, 1)
				for y in range(7, top + 1):
					var wall := Color(0.62, 0.62, 0.66)
					if y == top:
						wall = Color(0.45, 0.24, 0.17)
					hull[Vector3i(x, y, z)] = Vox.vary(wall, _rng, 0.04)
					if y < top and _rng.randf() < 0.16:
						lit[Vector3i(x, y, z)] = Color(1.0, 0.70, 0.36) if _rng.randf() < 0.8 else Color(1.0, 0.85, 0.6)
	Vox.box(hull, Vector3i(-2, 7, -2), Vector3i(2, 17, 2), Color(0.58, 0.56, 0.58))
	lit[Vector3i(0, 18, 0)] = Color(1.0, 0.75, 0.45)
	for y in range(9, 17, 2):
		lit[Vector3i(2, y, 0)] = Color(1.0, 0.72, 0.4)
		lit[Vector3i(-2, y, 1)] = Color(1.0, 0.72, 0.4)
	# Folded legs: up to a high knee, then down into the sand
	for leg in [[-14, -16], [0, -17], [14, -16], [-14, 16], [0, 17], [14, 16]]:
		var lx: int = leg[0]
		var lz: int = leg[1]
		var side := signi(lz)
		for i in 9:
			hull[Vector3i(lx, 5 + i, lz + side * (i / 3))] = Color(0.26, 0.23, 0.21)
		for i in 15:
			hull[Vector3i(lx, 13 - i, lz + side * (3 + i / 3))] = Color(0.24, 0.21, 0.19)
	var n := Vox.node(hull, _mat, Vector3.ZERO, b)
	n.position = at
	add_child(n)
	var w := Vox.node(lit, _glow, Vector3.ZERO, b * 1.02)
	w.position = at
	add_child(w)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.65, 0.35)
	glow.light_energy = 3.0
	glow.omni_range = 60.0
	glow.position = at + Vector3(0, 20, 0)
	add_child(glow)


## Fine sand blowing low across the ground.
func _drifting_sand() -> void:
	var p := CPUParticles3D.new()
	p.amount = 160
	p.lifetime = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(RADIUS, 0.3, RADIUS)
	p.position = Vector3(0, 0.4, 0)
	p.direction = Vector3(1, 0.05, 0.3)
	p.spread = 12.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.05)    # tiny grains (sized here, not scaled)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.62, 0.58, 0.52)
	box.material = m
	p.mesh = box
	p.preprocess = 6.0
	add_child(p)
