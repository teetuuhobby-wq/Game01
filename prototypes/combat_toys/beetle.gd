extends Node3D
## THE DUNE BEETLE, made of blocks: a dark shell with a dusty sheen, a curved horn,
## two hooked jaws, glowing amber eyes and six legs that walk in a tripod gait.
## Faces -z. Origin on the ground under its middle. Only looks: the toys decide what it does.

const Vox := preload("res://vox.gd")

var walk_speed := 0.0     # m/s, drives the legs
var mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var body: Node3D          # pitches up when it rears
var head: Node3D
var jaw_l: Node3D
var jaw_r: Node3D
var legs: Array[Node3D] = []
var _phase := 0.0
var _rear := 0.0
var _rear_target := 0.0
var _jaw := 0.0
var _jaw_target := 0.0
var _eye := 1.0
var _eye_target := 1.0
var _dead := false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	mat = Vox.material()
	mat.roughness = 0.45     # a bit shiny, like a shell
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.0
	eye_mat = Vox.glow_material(2.5)
	body = Node3D.new()
	body.position = Vector3(0, 0.55, 1.2)    # the joint it rears up on, near the back legs
	add_child(body)
	# The shell: the top part of a long egg shape, with the split down its back
	var shell := {}
	var base := Color(0.30, 0.24, 0.19)
	for x in range(-6, 7):
		for y in range(-2, 5):
			for z in range(-8, 9):
				var e := pow(x / 6.4, 2) + pow(y / 4.4, 2) + pow(z / 8.4, 2)
				if e > 1.0:
					continue
				var c := base
				if y >= 3:
					c = Color(0.33, 0.35, 0.40)            # moonlit sheen on top
				if absi(x) == 3 and y >= 1:
					c = c.lightened(0.12)                   # ridges along the wing cases
				if x == 0 and z > -4 and y >= 0:
					c = Color(0.07, 0.06, 0.06)            # the split between the wing cases
				if z == -4:
					c = Color(0.10, 0.08, 0.07)            # the groove behind the neck
				if y <= -1:
					c = Color(0.36, 0.27, 0.19)            # belly
				if y == -2:
					c = Color(0.62, 0.52, 0.38)            # sand-dusted rim along the bottom
				elif e > 0.75 and rng.randf() < 0.25:
					c = Color(0.55, 0.46, 0.33)            # sand caught in the edges
				shell[Vector3i(x, y, z)] = Vox.vary(c, rng, 0.02)
	body.add_child(Vox.node(shell, mat, Vector3(0, 0.35, -1.2)))
	head = Node3D.new()
	head.position = Vector3(0, 0.3, -3.5)
	body.add_child(head)
	var h := {}
	for x in range(-3, 4):
		for y in range(-2, 3):
			for z in range(-2, 3):
				if pow(x / 3.5, 2) + pow(y / 2.6, 2) + pow(z / 2.8, 2) <= 1.0:
					h[Vector3i(x, y, z)] = Vox.vary(Color(0.22, 0.18, 0.15), rng, 0.02)
	# The horn: up from the forehead and curving forward
	for i in 6:
		var p := Vector3i(0, 2 + i, -1 - i / 2)    # each block touches the one below
		var col := Color(0.28, 0.22, 0.17).lerp(Color(0.80, 0.72, 0.56), i / 6.0)
		h[p] = col
		h[p + Vector3i(0, -1, 0)] = col
		if i < 3:
			h[p + Vector3i(0, 0, 1)] = Color(0.26, 0.20, 0.16)
	head.add_child(Vox.node(h, mat))
	var eyes := {}
	for sx in [-1, 1]:
		eyes[Vector3i(sx * 3, 0, -1)] = Color(1.0, 0.62, 0.18)
		eyes[Vector3i(sx * 3, 1, -1)] = Color(1.0, 0.80, 0.35)
	var eye_node := Vox.node(eyes, eye_mat, Vector3.ZERO, 0.21)
	head.add_child(eye_node)
	jaw_l = _jaw_part(-1)
	jaw_r = _jaw_part(1)
	head.add_child(jaw_l)
	head.add_child(jaw_r)
	# Six legs: front, middle, back on each side
	for i in 6:
		var side := -1 if i % 2 == 0 else 1
		var row := i / 2
		var leg := _leg(side)
		leg.position = Vector3(side * 1.0, -0.1, [-2.4, -1.2, 0.0][row])
		leg.rotation.y = side * [-0.45, 0.0, 0.45][row]
		leg.set_meta("base_y", leg.rotation.y)
		leg.set_meta("side", side)
		leg.set_meta("phase", 0.0 if (row + (1 if side > 0 else 0)) % 2 == 0 else PI)
		body.add_child(leg)
		legs.append(leg)


## A hooked jaw, opening sideways from its root.
func _jaw_part(side: int) -> Node3D:
	var j := Node3D.new()
	j.position = Vector3(side * 0.3, -0.25, -0.45)
	var c := {}
	var bone := Color(0.84, 0.76, 0.60)
	var pts := [Vector3i(0, 0, 0), Vector3i(0, 0, -1), Vector3i(0, 0, -2), Vector3i(0, 0, -3),
			Vector3i(-side, 0, -4), Vector3i(-side * 2, 0, -4)]
	for i in pts.size():
		c[pts[i]] = Color(0.25, 0.19, 0.15).lerp(bone, float(i) / pts.size())
	j.add_child(Vox.node(c, mat, Vector3.ZERO, 0.14))
	return j


## A leg: out and up from the body, then a knee, then down to the sand.
func _leg(side: int) -> Node3D:
	var hip := Node3D.new()
	var up := {}
	for i in 5:
		up[Vector3i(side * i, i / 2, 0)] = Color(0.24, 0.19, 0.15)
	hip.add_child(Vox.node(up, mat, Vector3.ZERO, 0.16))
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position = Vector3(side * 0.72, 0.32, 0)
	hip.add_child(knee)
	var down := {}
	for i in 5:
		down[Vector3i(side * (i / 3), -i, 0)] = Color(0.24, 0.19, 0.15).lerp(Color(0.45, 0.37, 0.27), i / 5.0)
	knee.add_child(Vox.node(down, mat, Vector3.ZERO, 0.16))
	return hip


## How far it rears up (0 = flat, 1 = front lifted high), how wide its jaws open,
## and how bright its eyes are (1 = calm, 3 = about to strike). They ease toward these.
func set_pose(rear: float, jaws: float, eyes := 1.0) -> void:
	_rear_target = rear
	_jaw_target = jaws
	_eye_target = eyes


func flash(color := Color(1.0, 0.8, 0.55), strength := 0.18) -> void:
	mat.emission = color
	var t := create_tween()
	t.tween_property(mat, "emission_energy_multiplier", strength, 0.02)
	t.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)


## Beaten: flips onto its back with its legs in the air.
func die() -> void:
	_dead = true
	set_pose(0.0, 0.2, 0.0)
	var t := create_tween()
	t.tween_property(self, "position:y", position.y + 1.6, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(self, "rotation:z", PI, 0.6)
	t.tween_property(self, "position:y", position.y + 1.25, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	_rear = lerpf(_rear, _rear_target, k)
	_jaw = lerpf(_jaw, _jaw_target, 1.0 - exp(-14.0 * delta))
	_eye = lerpf(_eye, _eye_target, k)
	body.rotation.x = _rear * 0.45
	head.rotation.x = _rear * 0.2
	jaw_l.rotation.y = -_jaw * 0.7
	jaw_r.rotation.y = _jaw * 0.7
	eye_mat.albedo_color = Color(_eye * 1.3, _eye * (1.0 - 0.15 * (_eye - 1.0)), _eye * 0.8)
	var t := Time.get_ticks_msec() * 0.001
	if _dead:
		for leg in legs:
			leg.rotation.z = sin(t * 9.0 + leg.position.z * 3.0) * 0.25
		return
	_phase += delta * (2.0 + walk_speed * 2.2)
	var amp := clampf(walk_speed / 4.0, 0.0, 1.0)
	for leg in legs:
		var ph: float = _phase + float(leg.get_meta("phase"))
		var side: float = leg.get_meta("side")
		leg.rotation.y = float(leg.get_meta("base_y")) + sin(ph) * 0.35 * amp
		leg.rotation.z = side * maxf(0.0, cos(ph)) * 0.35 * amp
		var knee: Node3D = leg.get_node("Knee")
		knee.rotation.z = side * (0.05 + sin(t * 1.3 + ph) * 0.03)
	body.position.y = 0.55 + sin(_phase * 2.0) * 0.03 * amp + sin(t * 1.7) * 0.015
