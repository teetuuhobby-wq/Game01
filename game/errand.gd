extends Node
## THE ERRAND, the first toy's one job: Mira asks you to fix the rain-catcher.
## Fetch the spare valve from Bram's workshop (middle terrace, east), then fit it
## on the rain-catcher (outer ring, far west). The guide (quest_hud.gd) shows where to go.
## With the morning round on (welcome.gd), the errand waits until the round's last
## stop, at Bram's, hands it over (begin()).

signal step_changed(what: String)  ## for test screenshots

const T := preload("res://tuning.gd")

enum Step { GET_VALVE, FIT_VALVE, DONE }

var step := Step.GET_VALVE
var active := false    # false: waiting for the morning round, or finished and the round has the guide back
var world: Node3D      # world.gd
var player: Node3D     # player.gd
var sfx: Node          # sfx.gd
var camera: Camera3D
var controls: Node     # controls.gd
var hud: Node          # quest_hud.gd: the goal line, speech and gold marker
var bot_use := false   # the test bot "holds E"

var _mira: Node3D
var _bubble: Label3D
var _bubble_until := 0.0   # Mira's speech bubble shows until then (seconds since the start)
var _fix := 0.0
var _tick_time := 0.0
var _t := 0.0
var _used_frame := -1   # the frame E last did something for the errand


## start_now false: the morning round goes first and calls begin() at Bram's.
func setup(w: Node3D, p: Node3D, s: Node, cam: Camera3D, c: Node, h: Node, start_now := true) -> void:
	controls = c
	world = w
	player = p
	sfx = s
	camera = cam
	hud = h
	_make_mira()
	if start_now:
		set_bubble("Could you fix the\nrain-catcher for us?", 12.0)
		begin("Mira", "The rain-catcher's jammed again! Bram left a spare valve at his workshop, one terrace down on the east side. Could you fit it for us?", 12.0)


## The errand takes over the guide (who and text: what's said as it starts, if anything).
func begin(who := "", text := "", seconds := 0.0) -> void:
	active = true
	if text != "":
		hud.speak(who, text, seconds)


## Mira's speech bubble over her head, for a few seconds.
func set_bubble(text: String, seconds: float) -> void:
	_bubble.text = text
	_bubble_until = _t + seconds


func _process(delta: float) -> void:
	_t += delta
	_bubble.visible = _t < _bubble_until and camera.zoom < 0.6
	if not active:
		return
	var using: bool = controls.use_held or bot_use
	var near := _near()
	match step:
		Step.GET_VALVE:
			hud.goal("Fetch the spare valve from Bram's workshop  (%s)" % hud.where(player.position, world.workshop_use))
			hud.prompt("Press E to pick up the valve" if near else "")
			if near and (controls.use_pressed or bot_use):
				_used_frame = Engine.get_process_frames()
				_pick_up()
		Step.FIT_VALVE:
			hud.goal("Fit the valve on the rain-catcher  (%s)" % hud.where(player.position, world.catcher_use))
			hud.prompt("Hold E to fit the valve" if near else "")
			if near and using:
				_fix += delta
				_tick_time -= delta
				if _tick_time <= 0.0:
					_tick_time = 0.15
					sfx.tick()
				if _fix >= T.FIX_TIME:
					_used_frame = Engine.get_process_frames()
					_fit()
			else:
				_fix = maxf(0.0, _fix - delta * 2.0)
		Step.DONE:
			hud.goal("Done! The rain-catcher works again. Keep exploring as long as you like.")
			hud.prompt("")
	if not active:
		return   # the round took the guide back as the valve went on (it listens to step_changed)
	hud.bar(step == Step.FIT_VALVE and _fix > 0.0, _fix / T.FIX_TIME)
	match step:
		Step.GET_VALVE:
			hud.point_at(world.workshop_use)
		Step.FIT_VALVE:
			hud.point_at(world.catcher_use)
		_:
			hud.point_at(null)


## True when E belongs to the errand right now, or was just used by it this frame
## (interact.gd asks before using E, so one press never does two things).
func busy_here() -> bool:
	return active and (_near() or _used_frame == Engine.get_process_frames())


## True when you're close enough to use the current target.
func _near() -> bool:
	var target: Vector3 = world.workshop_use if step == Step.GET_VALVE else world.catcher_use
	var d: Vector3 = target - player.position
	return step != Step.DONE and Vector2(d.x, d.z).length() < T.USE_DISTANCE and absf(d.y) < 2.5


func _pick_up() -> void:
	world.valve.reparent(player.hand, false)
	world.valve.position = Vector3.ZERO
	world.valve.scale = Vector3.ONE * 0.6
	sfx.chime()
	step = Step.FIT_VALVE
	step_changed.emit("valve_picked_up")
	hud.speak("You", "Got it. Now the rain-catcher: it's on the outer ring, at the far west end.", 6.0)


func _fit() -> void:
	world.valve.reparent(world.city, false)
	world.valve.scale = Vector3.ONE
	world.valve.position = world.catcher_use
	world.catcher_water.visible = true
	_splash()
	sfx.clunk()
	sfx.bell()
	step = Step.DONE
	hud.speak("Mira (calling from the plaza)", "You did it! I can hear the water running from up here. Thank you, neighbour!", 10.0)
	hud.bar(false, 0.0)
	step_changed.emit("valve_fitted")


## Water splashing into the rain barrel: the rain-catcher works again.
func _splash() -> void:
	var p := CPUParticles3D.new()
	var drop := BoxMesh.new()
	drop.size = Vector3.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.72, 0.9)
	drop.material = mat
	p.mesh = drop
	p.amount = 40
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -9.8, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.position = world.catcher_splash
	world.city.add_child(p)


## Mira: a neighbour beside you in the plaza, with a speech bubble at the start.
func _make_mira() -> void:
	_mira = world._make_character(preload("res://town_data.gd").CAST["mira"])
	world.city.add_child(_mira)
	world.cast_nodes["mira"] = _mira
	_mira.position = world.mira_spot
	var d: Vector3 = player.position - world.mira_spot
	_mira.rotation.y = atan2(-d.z, d.x)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 2.4, 0)
	_bubble.font_size = 30
	_bubble.fixed_size = true
	_bubble.pixel_size = 0.0011
	_bubble.outline_size = 10
	_bubble.no_depth_test = true
	_bubble.visible = false
	_mira.add_child(_bubble)
