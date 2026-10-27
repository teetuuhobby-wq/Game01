extends "res://world/blocks.gd"
## THE WORLD, layer 2 of 10: the sky, the sun and the desert.
## The light settings (changed live by mood.gd), the desert floor that repeats so the
## walk never ends, and the bones and wrecks lying in it.


func _make_world() -> void:
	var psm := ProceduralSkyMaterial.new()
	sky_mat = psm
	psm.sky_top_color = Color(0.45, 0.66, 0.74)
	psm.sky_horizon_color = Color(0.98, 0.80, 0.62)
	psm.ground_horizon_color = Color(0.85, 0.64, 0.46)
	psm.ground_bottom_color = Color(0.40, 0.30, 0.25)
	var sky := Sky.new()
	sky.sky_material = psm

	env = Environment.new()
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
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -30, 0)
	sun.light_color = Color(1.0, 0.77, 0.54)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)


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
