extends Camera3D
## THE CAMERA: follows you. Move the mouse to look around (click in the window first),
## or turn with Z and X. The mouse wheel (or + and -) zooms from close behind you out
## to the whole-town diorama view; scroll all the way in and it glides into your
## own eyes (first person), scroll out again to come back. It only turns when you turn it.
## When a wall or roof gets in the way, it first rises to look over it, and only moves
## in closer if that doesn't help. Every change is smoothed, so it never jumps.

const T := preload("res://tuning.gd")
const FP_ZOOM := -0.1       # zoom below 0 means first person

var target: Node3D          # the player
var world: Node3D           # world.gd, to see what blocks the view
var controls: Node          # controls.gd
var zoom := T.CAMERA_ZOOM_START
var zoom_goal := T.CAMERA_ZOOM_START
var yaw := deg_to_rad(45.0)
var distance := 0.0         # how far the camera actually is from what it looks at
var lift := 0.0             # extra tilt (radians) to see over something in the way
var pull := 1.0             # 1 = full distance; less when it had to move in closer
var first_person := 0.0     # 0 = behind you, 1 = through your eyes (in between while gliding)
var _pitch_offset := 0.0    # from the mouse moving up and down
var _focus := Vector3.ZERO
var _shake := 0.0
var _time := 0.0
var _first := true
var _dof: CameraAttributesPractical


func _ready() -> void:
	far = 1000.0
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_amount = 0.12
	attributes = _dof
	_focus = target.global_position + Vector3(0, 1.2, 0)


## Jump straight to a zoom level (used for screenshots).
func snap_zoom(z: float) -> void:
	zoom = z
	zoom_goal = z


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_time += delta
	var sens := T.MOUSE_SENSITIVITY
	yaw += controls.look.x * sens + controls.turn * T.CAMERA_TURN_SPEED * delta
	# Looking up and down: a little behind you, much more through your own eyes
	var fp_goal := zoom_goal < 0.0
	_pitch_offset = clampf(_pitch_offset + controls.look.y * sens * (-1.0 if T.MOUSE_INVERT_Y else 1.0),
			deg_to_rad(-72.0 if fp_goal else -12.0), deg_to_rad(58.0 if fp_goal else 30.0))
	var steps: float = controls.zoom_steps
	if steps < 0.0 and zoom_goal <= 0.001:
		zoom_goal = FP_ZOOM            # scrolled all the way in: into your own eyes
	elif steps > 0.0 and zoom_goal < 0.0:
		zoom_goal = 0.0                # and back out over your shoulder
		_pitch_offset = clampf(_pitch_offset, deg_to_rad(-12.0), deg_to_rad(30.0))
	elif zoom_goal >= 0.0:
		zoom_goal = clampf(zoom_goal + steps * 0.07, 0.0, 1.0)
	zoom = lerpf(zoom, zoom_goal, 1.0 - exp(-8.0 * delta))
	first_person = clampf(zoom / FP_ZOOM, 0.0, 1.0)
	var tz := maxf(zoom, 0.0)

	var goal := target.global_position + Vector3(0, 1.2, 0)
	if _focus.distance_to(goal) > 40.0:
		_focus = goal   # the city looped back: jump with it instead of flying across
	_focus = _focus.lerp(goal, 1.0 - exp(-10.0 * delta))

	var dist := T.CAMERA_NEAR_DISTANCE * pow(T.CAMERA_FAR_DISTANCE / T.CAMERA_NEAR_DISTANCE, tz)
	var view_pitch := deg_to_rad(lerpf(12.0, 43.0, tz)) + _pitch_offset   # how far down you look
	var pitch := clampf(view_pitch, deg_to_rad(4.0), deg_to_rad(80.0))

	# Something in the way? Try looking from a bit higher or lower first (over a wall,
	# under a parasol); if no angle clears the view, use whichever sees furthest and
	# slide in to there. Changes are gentle, so the camera never jumps.
	var want_lift := 0.0
	var clear := 1.0
	if tz < 0.6 and first_person < 0.5:
		clear = _clear_line(pitch, dist)
		if clear < 0.97:
			var best := clear
			var best_lift := 0.0
			for deg in [10.0, -8.0, 20.0, 30.0, 40.0, 50.0]:
				var l := clampf(deg_to_rad(deg), deg_to_rad(4.0) - pitch, deg_to_rad(80.0) - pitch)
				var c := _clear_line(pitch + l, dist)
				if c > best + 0.02:
					best = c
					best_lift = l
				if c >= 0.97:
					break
			want_lift = best_lift
			clear = best
	if _first:
		lift = want_lift
		pull = clear
		_first = false
	lift = lerpf(lift, want_lift, 1.0 - exp(-4.0 * delta))
	pull = lerpf(pull, clear, 1.0 - exp(-(5.0 if clear < pull else 2.5) * delta))

	var p := pitch + lift
	var dir := Vector3(cos(p) * cos(yaw), sin(p), cos(p) * sin(yaw))
	var reach := dist * maxf(pull, 0.08)
	# Never sit inside a wall: if the spot itself is too close to blocks, move in until it isn't
	while reach > 0.6 and not _room_at(world.city.to_local(_focus + dir * reach)):
		reach -= 0.2
	var offset := dir * reach
	distance = offset.length()
	_shake = maxf(0.0, _shake - delta * 0.8)
	var wobble := Vector3(sin(_time * 31.0), sin(_time * 27.0), 0) * _shake
	var behind := _focus + offset + wobble
	if first_person <= 0.0:
		global_position = behind
		look_at(_focus)
	else:
		# Glide between over-the-shoulder and your eyes, looking where the mouse points
		var fp := smoothstep(0.0, 1.0, first_person)
		var eye: Vector3 = target.global_position + Vector3(0, target.eye_height(), 0) + wobble * 0.5
		var cp := clampf(view_pitch, deg_to_rad(-60.0), deg_to_rad(70.0))
		var look_dir := -Vector3(cos(cp) * cos(yaw), sin(cp), cos(cp) * sin(yaw))
		global_position = behind.lerp(eye, fp)
		look_at(_focus.lerp(eye + look_dir * 10.0, fp))
		if first_person > 0.5 and not target.moving:
			target.face(target.get_parent().global_transform.basis.inverse() * look_dir)
	target.set_first_person(first_person > 0.5)
	fov = lerpf(lerpf(62.0, 28.0, tz), T.FIRST_PERSON_FOV, first_person)
	target.set_ring_scale(maxf(1.0, dist / 20.0))

	# Tilt-shift blur when zoomed out (the miniature look); none when close or in first person
	_dof.dof_blur_near_enabled = tz > 0.55
	_dof.dof_blur_near_distance = dist * 0.68
	_dof.dof_blur_near_transition = dist * 0.2
	_dof.dof_blur_far_enabled = true
	# Close behind you, keep the street sharp for 40 m (it used to blur from ~16 m and smeared the view)
	_dof.dof_blur_far_distance = lerpf(maxf(dist * 1.25 + 10.0, 40.0), 150.0, first_person)
	_dof.dof_blur_far_transition = dist * 0.8 + 20.0


## How much of the view line at this tilt is clear (0..1), keeping the camera 45 cm
## back from whatever it would hit. Three lines side by side and the middle result
## counts: a thin post blocks only one line (ignored), but a wall or a building's
## corner blocks two (not ignored; playtest 2: "my camera clips through the buildings").
func _clear_line(p: float, dist: float) -> float:
	var off := Vector3(cos(p) * cos(yaw), sin(p), cos(p) * sin(yaw)) * dist
	var a: Vector3 = world.city.to_local(_focus)
	var b: Vector3 = world.city.to_local(_focus + off)
	var side := Vector3(-off.z, 0, off.x).normalized() * 0.35
	var hits := [world.first_hit(a, b), world.first_hit(a + side, b + side), world.first_hit(a - side, b - side)]
	hits.sort()
	var h: float = hits[1]
	return 1.0 if h >= 1.0 else clampf((h * dist - 0.45) / dist, 0.0, 1.0)


## True if the camera at this spot (on the city) has no block within 30 cm of it.
func _room_at(p: Vector3) -> bool:
	for o in [Vector3.ZERO, Vector3(0.3, 0, 0), Vector3(-0.3, 0, 0), Vector3(0, 0.3, 0),
			Vector3(0, -0.3, 0), Vector3(0, 0, 0.3), Vector3(0, 0, -0.3)]:
		var q: Vector3 = p + o
		if world.gv(roundi(q.x / world.VS), roundi(q.y / world.VS), roundi(q.z / world.VS)) != 0:
			return false
	return true
