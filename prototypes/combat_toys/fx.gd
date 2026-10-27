extends RefCounted
## LITTLE EFFECTS both fights use: floating numbers, sparks and puffs of sand.


## A number (or word) that pops up and floats away.
static func popup(parent: Node, at: Vector3, text: String, color := Color(1, 0.9, 0.6), size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.08, 0.05, 0.04)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.006
	l.position = at
	parent.add_child(l)
	l.scale = Vector3.ONE * 0.4
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector3.ONE * 1.15, 0.08)
	t.tween_property(l, "scale", Vector3.ONE, 0.08)
	t.parallel().tween_property(l, "position:y", at.y + 1.2, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(l, "modulate:a", 0.0, 0.25)
	t.tween_callback(l.queue_free)


## A burst of small bits flying out (sparks off the shell, or sand).
static func burst(parent: Node, at: Vector3, color: Color, amount := 18, speed := 5.0, size := 0.08, glow := true) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color * 2.0
	box.material = m
	p.mesh = box
	p.position = at
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A puff of sand kicked up from the ground.
static func dust(parent: Node, at: Vector3, amount := 14, speed := 2.5) -> void:
	burst(parent, at, Color(0.66, 0.58, 0.46), amount, speed, 0.14, false)
