extends Node3D
## YOU: a resident walking the city's streets.
## You move in the city's own coordinates, as if the deck stood still; the city's
## walking and swaying carry you along (you're a child of the city node).
## Collision comes from the world's walk map: you can't walk through anything
## between your feet and your head, or step up or down more than 40 cm at once.

signal stepped  ## a footstep, for the footstep sound

const T := preload("res://tuning.gd")
const RADIUS := 0.25   # half your width, metres

var world: Node3D           # world.gd
var bot_input := Vector2.ZERO   # used instead of the keyboard when the test bot plays
var bot_mode := false
var moving := false
var facing := Vector3(1, 0, 0)   # on the city
var body: Node3D
var hand: Node3D                 # carried things go here
var _step_timer := 0.0
var _walk_phase := 0.0
var _ring: MeshInstance3D


func _ready() -> void:
	body = world._make_person(Color(0.16, 0.55, 0.58), Color(0.30, 0.24, 0.20),
			Color(0.20, 0.13, 0.08), Color(0.92, 0.75, 0.62))
	add_child(body)
	body.rotation.y = world.you_yaw
	facing = Vector3(cos(world.you_yaw), 0, -sin(world.you_yaw))   # the way the body mesh faces
	hand = Node3D.new()
	body.add_child(hand)
	hand.position = Vector3(0.3, 1.0, 0.0)
	body.add_child(_hat())
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.46
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.35)
	torus.material = mat
	_ring.mesh = torus
	_ring.position.y = 0.06
	add_child(_ring)


## A mustard-yellow hat, so you're easy to spot among the neighbours.
func _hat() -> MeshInstance3D:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	var vs: float = world.VS
	for x in range(-1, 3):
		for z in range(-2, 3):
			pts.append(Vector3((x - 0.5) * vs, 9.5 * vs, z * vs))
			cols.append(Color(0.94, 0.72, 0.22))
	for x in 2:
		for z in range(-1, 2):
			pts.append(Vector3((x - 0.5) * vs, 10.5 * vs, z * vs))
			cols.append(Color(0.84, 0.60, 0.16))
	return world._mi(world._cubes(pts, cols, vs, true))


## Your ring grows when the camera is far away, so you can always find yourself.
func set_ring_scale(s: float) -> void:
	_ring.scale = Vector3(s, 1.0, s)


func _process(delta: float) -> void:
	var dir := _input_dir()
	moving = dir.length() > 0.1
	if moving:
		var running := Input.is_action_pressed("run") and not bot_mode
		var speed := T.RUN_SPEED if running else T.WALK_SPEED
		_move(dir * speed * delta)
		facing = dir.normalized()
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-facing.z, facing.x), minf(1.0, 12.0 * delta))
		_walk_phase += delta * speed * 3.2
		_step_timer -= delta * speed / T.WALK_SPEED
		if _step_timer <= 0.0:
			_step_timer = 0.42
			stepped.emit()
	body.position.y = absf(sin(_walk_phase)) * 0.05 if moving else 0.0
	# Glide up and down stairs instead of snapping, fast enough to keep up when running
	var f: int = world.floor_at(position)
	if f >= 0:
		position.y = move_toward(position.y, (f + 0.5) * world.VS, 9.0 * delta)


## Which way to walk, on the city, from the keys (relative to the camera) or the bot.
func _input_dir() -> Vector3:
	if bot_mode:
		return Vector3(bot_input.x, 0, bot_input.y).limit_length(1.0)
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if v == Vector2.ZERO:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	fwd.y = 0.0
	right.y = 0.0
	var g := right.normalized() * v.x - fwd.normalized() * v.y
	# Into the city's own coordinates (it only tilts a little as it sways)
	var l: Vector3 = world.city.global_transform.basis.inverse() * g
	l.y = 0.0
	return l.limit_length(1.0)


## Moves by step if there's room; slides along walls by trying each axis on its own.
## Long steps (running, or a low frame rate) are cut into small slices, so stairs
## behave the same at any speed.
func _move(step: Vector3) -> void:
	var slices := maxi(1, ceili(step.length() / 0.08))
	var s := step / slices
	for i in slices:
		var f0: int = world.floor_at(position)
		for d in [s, Vector3(s.x, 0, 0), Vector3(0, 0, s.z)]:
			if _fits(position + d, f0):
				position.x += d.x
				position.z += d.z
				break


## True if you can stand at p: the floor there is at most 2 blocks (40 cm) above or
## below where you are now, and under each of your four corners it's at most 2
## blocks from that, so you can't hang over a drop or half into a wall.
func _fits(p: Vector3, from_floor: int) -> bool:
	var f: int = world.floor_at(p)
	if f < 0 or (from_floor >= 0 and absi(f - from_floor) > 2):
		return false
	for o in [Vector3(RADIUS, 0, RADIUS), Vector3(RADIUS, 0, -RADIUS),
			Vector3(-RADIUS, 0, RADIUS), Vector3(-RADIUS, 0, -RADIUS)]:
		var fc: int = world.floor_at(p + o)
		if fc < 0 or absi(fc - f) > 2:
			return false
	return true
