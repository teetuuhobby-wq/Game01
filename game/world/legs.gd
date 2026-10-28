extends "res://world/market.gd"
## THE WORLD, layer 10 of 13: the six giant legs.
## Their meshes, the dust when a foot lands, and the walk itself: each foot is planted
## or swinging, and the knee bends to fit (a two-bone reach).


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


## Moves every leg for this moment of the walk: plant, swing, bend the knee, kick up dust.
func _update_legs(period: float) -> void:
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
			lift = sin(PI * s) * STEP_LIFT * (1.0 - maxf(kneel, 1.0 - walk_rate))   # feet settle as it stops
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
