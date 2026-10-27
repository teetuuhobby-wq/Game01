extends Node3D
## A PERSON made of blocks, like the residents in the game, but with joints so they
## can walk, swing and get knocked about. Faces -z. Origin at the feet.
## Holds a weapon in the right hand ("sword" or "wrench") and, optionally, a lantern.

const Vox := preload("res://vox.gd")

var move_speed := 0.0      # set each frame by whoever moves this person (m/s); drives the walk
var mat: StandardMaterial3D
var chest: Node3D          # turns for swings; holds the torso, head and arms
var arm_r: Node3D
var arm_l: Node3D
var leg_r: Node3D
var leg_l: Node3D
var weapon: Node3D
var lantern_light: OmniLight3D
var _walk := 0.0
var _swinging := false
var _tw: Tween


func build(shirt: Color, pants: Color, hair: Color, skin: Color, held := "sword", lantern := false, beard := false) -> void:
	mat = Vox.material()
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.0
	leg_r = _limb(Vector3(0.1, 0.6, 0), [pants, pants, Color(0.22, 0.16, 0.12)], true)
	leg_l = _limb(Vector3(-0.1, 0.6, 0), [pants, pants, Color(0.22, 0.16, 0.12)], true)
	add_child(leg_r)
	add_child(leg_l)
	chest = Node3D.new()
	chest.position = Vector3(0, 0.6, 0)
	add_child(chest)
	var torso := {}
	Vox.box(torso, Vector3i(-1, 0, -1), Vector3i(1, 2, 0), shirt)
	for x in range(-1, 2):
		torso[Vector3i(x, 0, -1)] = pants.darkened(0.2)   # belt
		torso[Vector3i(x, 0, 0)] = pants.darkened(0.2)
	chest.add_child(Vox.node(torso, mat, Vector3(0, 0.1, 0.1)))
	var head := {}
	Vox.box(head, Vector3i(-1, 0, -1), Vector3i(1, 2, 0), skin)
	for x in range(-1, 2):
		head[Vector3i(x, 2, -1)] = hair
		head[Vector3i(x, 2, 0)] = hair
		head[Vector3i(x, 1, 0)] = hair
	head[Vector3i(-1, 1, -1)] = Color(0.12, 0.10, 0.09)   # eyes
	head[Vector3i(1, 1, -1)] = Color(0.12, 0.10, 0.09)
	if beard:
		for x in range(-1, 2):
			head[Vector3i(x, 0, -1)] = hair
	chest.add_child(Vox.node(head, mat, Vector3(0, 0.7, 0.1)))
	arm_r = _limb(Vector3(0.4, 0.55, 0), [shirt, shirt, skin], false)
	arm_l = _limb(Vector3(-0.4, 0.55, 0), [shirt, shirt, skin], false)
	chest.add_child(arm_r)
	chest.add_child(arm_l)
	weapon = _make_weapon(held)
	weapon.position = Vector3(0, -0.55, 0)
	weapon.rotation.x = deg_to_rad(60)   # held pointing forward, not down into the ground
	arm_r.add_child(weapon)
	if lantern:
		var l := {}
		var brass := Color(0.80, 0.62, 0.30)
		Vox.box(l, Vector3i(-1, -4, -1), Vector3i(1, -4, 1), brass)
		Vox.box(l, Vector3i(-1, 0, -1), Vector3i(1, 0, 1), brass)
		l[Vector3i(0, 1, 0)] = brass
		var lamp := Node3D.new()
		lamp.position = Vector3(0, -0.6, -0.05)
		lamp.add_child(Vox.node(l, mat, Vector3.ZERO, 0.08))
		var g := {}
		Vox.box(g, Vector3i(-1, -3, -1), Vector3i(1, -1, 1), Color(1.0, 0.75, 0.4))
		lamp.add_child(Vox.node(g, Vox.glow_material(3.0), Vector3.ZERO, 0.08))
		lantern_light = OmniLight3D.new()
		lantern_light.light_color = Color(1.0, 0.72, 0.42)
		lantern_light.light_energy = 2.2
		lantern_light.omni_range = 9.0
		lantern_light.omni_attenuation = 1.2
		lantern_light.shadow_enabled = true
		lantern_light.position = Vector3(0, -0.16, 0)
		lamp.add_child(lantern_light)
		arm_l.add_child(lamp)
	arm_r.rotation.x = deg_to_rad(25)


## An arm or a leg: three blocks hanging down from a joint at `at`.
func _limb(at: Vector3, colours: Array, leg: bool) -> Node3D:
	var j := Node3D.new()
	j.position = at
	var c := {}
	for i in 3:
		c[Vector3i(0, -i, 0)] = colours[i]
		if leg:
			c[Vector3i(0, -i, -1)] = colours[i]
	j.add_child(Vox.node(c, mat, Vector3(0, -0.1, 0.1 if leg else 0.0)))
	return j


func _make_weapon(kind: String) -> Node3D:
	var w := Node3D.new()
	var c := {}
	if kind == "sword":
		var steel := Color(0.82, 0.84, 0.86)
		Vox.box(c, Vector3i(0, 0, 0), Vector3i(0, 1, 0), Color(0.36, 0.24, 0.15))   # grip
		Vox.box(c, Vector3i(-2, -1, 0), Vector3i(2, -1, 0), Color(0.80, 0.62, 0.30))   # guard
		Vox.box(c, Vector3i(0, -11, 0), Vector3i(0, -2, 0), steel)
		Vox.box(c, Vector3i(-1, -10, 0), Vector3i(-1, -2, 0), steel.darkened(0.15))
		c[Vector3i(0, -12, 0)] = steel.lightened(0.2)
	elif kind == "wrench":
		var iron := Color(0.42, 0.42, 0.44)
		Vox.box(c, Vector3i(0, 1, 0), Vector3i(0, -8, 0), iron)
		Vox.box(c, Vector3i(-2, -9, -1), Vector3i(2, -11, 1), iron.darkened(0.2))
		Vox.box(c, Vector3i(-1, -12, -1), Vector3i(-1, -13, 1), iron.darkened(0.2))
		Vox.box(c, Vector3i(1, -12, -1), Vector3i(1, -13, 1), iron.darkened(0.2))
		Vox.box(c, Vector3i(0, -2, 0), Vector3i(0, 0, 0), Color(0.55, 0.28, 0.18))
	w.add_child(Vox.node(c, mat, Vector3.ZERO, 0.1))
	return w


func _process(delta: float) -> void:
	_walk += delta * clampf(move_speed, 0.0, 8.0) * 2.2
	var amp := clampf(move_speed / 5.0, 0.0, 1.0) * 0.7
	leg_r.rotation.x = sin(_walk) * amp
	leg_l.rotation.x = -sin(_walk) * amp
	arm_l.rotation.x = sin(_walk) * amp * 0.6
	if not _swinging:
		arm_r.rotation.x = lerpf(arm_r.rotation.x, deg_to_rad(25) - sin(_walk) * amp * 0.4, 1.0 - exp(-10 * delta))
		chest.rotation.y = lerpf(chest.rotation.y, 0.0, 1.0 - exp(-10 * delta))
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.0, 1.0 - exp(-10 * delta))
	if move_speed < 0.2:
		chest.position.y = 0.6 + sin(Time.get_ticks_msec() * 0.003) * 0.01


## Swings the weapon. kind: 0 = slash right to left, 1 = left to right, 2 = overhead chop.
## `time` is the whole swing; the hit lands about 40% of the way in.
func swing(kind: int, time := 0.32) -> void:
	_swinging = true
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	if kind == 2:
		arm_r.rotation = Vector3(deg_to_rad(170), 0, 0)
		chest.rotation.y = 0
		_tw.tween_property(arm_r, "rotation:x", deg_to_rad(20), time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		var from := deg_to_rad(70) if kind == 0 else deg_to_rad(-60)
		arm_r.rotation = Vector3(deg_to_rad(30), 0, 0)
		chest.rotation.y = from
		_tw.tween_property(chest, "rotation:y", -from, time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_interval(time * 0.5)
	_tw.chain().tween_callback(func() -> void: _swinging = false)


## A quick white flash (got hit).
func flash(color := Color.WHITE, strength := 1.5) -> void:
	mat.emission = color
	var t := create_tween()
	t.tween_property(mat, "emission_energy_multiplier", strength, 0.03)
	t.tween_property(mat, "emission_energy_multiplier", 0.0, 0.2)


## Falls over backwards (lost).
func fall() -> void:
	var t := create_tween()
	t.tween_property(self, "rotation:x", deg_to_rad(80), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Arms up (won).
func cheer() -> void:
	_swinging = true
	var t := create_tween().set_parallel(true)
	t.tween_property(arm_r, "rotation:x", deg_to_rad(170), 0.3)
	t.tween_property(arm_l, "rotation:x", deg_to_rad(150), 0.3)
	t.tween_property(chest, "rotation:y", 0.0, 0.3)
