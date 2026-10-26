extends Camera3D
## THE CAMERA: follows you. The mouse wheel (or + and -) zooms from close behind you
## out to the whole-town diorama view. Turn it by dragging with the right mouse
## button, or with Z and X. Fully zoomed in, it swings round behind you as you walk.
## When a wall or roof gets between it and you, it slides in closer.

const T := preload("res://tuning.gd")

var target: Node3D          # the player
var world: Node3D           # world.gd, to see what blocks the view
var zoom := T.CAMERA_ZOOM_START
var zoom_goal := T.CAMERA_ZOOM_START
var yaw := deg_to_rad(45.0)
var _focus := Vector3.ZERO
var _shake := 0.0
var _pull := 1.0            # 1 = full distance; less when something is in the way
var _dof: CameraAttributesPractical


func _ready() -> void:
	far = 1000.0
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_amount = 0.12
	attributes = _dof
	_focus = target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_goal = clampf(zoom_goal - 0.07, 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_goal = clampf(zoom_goal + 0.07, 0.0, 1.0)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		yaw += event.relative.x * 0.006


## Jump straight to a zoom level (used for screenshots).
func snap_zoom(z: float) -> void:
	zoom = z
	zoom_goal = z


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if Input.is_action_pressed("zoom_in"):
		zoom_goal = clampf(zoom_goal - delta * 0.6, 0.0, 1.0)
	if Input.is_action_pressed("zoom_out"):
		zoom_goal = clampf(zoom_goal + delta * 0.6, 0.0, 1.0)
	yaw += (Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")) * T.CAMERA_TURN_SPEED * delta
	zoom = lerpf(zoom, zoom_goal, 1.0 - exp(-8.0 * delta))

	var goal := target.global_position + Vector3(0, 1.2, 0)
	if _focus.distance_to(goal) > 40.0:
		_focus = goal   # the city looped back: jump with it instead of flying across
	_focus = _focus.lerp(goal, 1.0 - exp(-10.0 * delta))

	# Close in, swing round behind you as you walk
	if zoom < 0.3 and target.moving:
		var d: Vector3 = target.get_parent().global_transform.basis * target.facing
		yaw = lerp_angle(yaw, atan2(-d.z, -d.x), 1.0 - exp(-2.0 * delta))

	var dist := T.CAMERA_NEAR_DISTANCE * pow(T.CAMERA_FAR_DISTANCE / T.CAMERA_NEAR_DISTANCE, zoom)
	var pitch := deg_to_rad(lerpf(12.0, 43.0, zoom))
	var offset := Vector3(cos(pitch) * cos(yaw), sin(pitch), cos(pitch) * sin(yaw)) * dist
	# Slide in when something blocks the view (snap in fast, ease back out)
	var clear := 1.0
	if zoom < 0.6:
		clear = world.first_hit(world.city.to_local(_focus), world.city.to_local(_focus + offset))
	_pull = clear if clear < _pull else lerpf(_pull, clear, 1.0 - exp(-3.0 * delta))
	_shake = maxf(0.0, _shake - delta * 0.8)
	var wobble := Vector3(sin(Time.get_ticks_msec() * 0.031), sin(Time.get_ticks_msec() * 0.027), 0) * _shake
	global_position = _focus + offset * maxf(_pull, 0.08) + wobble
	look_at(_focus)
	fov = lerpf(62.0, 28.0, zoom)
	target.set_ring_scale(maxf(1.0, dist / 20.0))

	# Tilt-shift blur when zoomed out (the miniature look); none when close
	_dof.dof_blur_near_enabled = zoom > 0.55
	_dof.dof_blur_near_distance = dist * 0.68
	_dof.dof_blur_near_transition = dist * 0.2
	_dof.dof_blur_far_enabled = true
	_dof.dof_blur_far_distance = dist * 1.25 + 10.0
	_dof.dof_blur_far_transition = dist * 0.8 + 20.0
