extends Node
## THE ERRAND, the first toy's one job: Mira asks you to fix the rain-catcher.
## Fetch the spare valve from Bram's workshop (middle terrace, east), then fit it
## on the rain-catcher (outer ring, far west). A glowing marker shows where to go.

signal step_changed(what: String)  ## for test screenshots

const T := preload("res://tuning.gd")

enum Step { GET_VALVE, FIT_VALVE, DONE }

var step := Step.GET_VALVE
var world: Node3D      # world.gd
var player: Node3D     # player.gd
var sfx: Node          # sfx.gd
var camera: Camera3D
var controls: Node     # controls.gd
var bot_use := false   # the test bot "holds E"

var _goal: Label
var _prompt: Label
var _say: Label
var _say_time := 0.0
var _bar: ProgressBar
var _marker: MeshInstance3D
var _arrow: Polygon2D       # points to the goal when the marker is off-screen
var _mira: Node3D
var _bubble: Label3D
var _fix := 0.0
var _tick_time := 0.0
var _t := 0.0
var _used_frame := -1   # the frame E last did something for the errand


func setup(w: Node3D, p: Node3D, s: Node, cam: Camera3D, c: Node) -> void:
	controls = c
	world = w
	player = p
	sfx = s
	camera = cam
	_make_hud()
	_make_mira()
	_make_marker()
	_speak("Mira", "The rain-catcher's jammed again! Bram left a spare valve at his workshop, one terrace down on the east side. Could you fit it for us?", 12.0)


func _process(delta: float) -> void:
	_t += delta
	var using: bool = controls.use_held or bot_use
	var near := _near()
	match step:
		Step.GET_VALVE:
			_goal.text = "Fetch the spare valve from Bram's workshop  (%s)" % _where(world.workshop_use)
			_prompt.text = "Press E to pick up the valve" if near else ""
			if near and (controls.use_pressed or bot_use):
				_used_frame = Engine.get_process_frames()
				_pick_up()
		Step.FIT_VALVE:
			_goal.text = "Fit the valve on the rain-catcher  (%s)" % _where(world.catcher_use)
			_prompt.text = "Hold E to fit the valve" if near else ""
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
			_goal.text = "Done! The rain-catcher works again. Keep exploring as long as you like."
			_prompt.text = ""
	_bar.visible = step == Step.FIT_VALVE and _fix > 0.0
	_bar.value = _fix / T.FIX_TIME
	_say_time -= delta
	_say.visible = _say_time > 0.0
	_bubble.visible = _t < 12.0 and camera.zoom < 0.6
	_update_marker()


## True when E belongs to the errand right now, or was just used by it this frame
## (interact.gd asks before using E, so one press never does two things).
func busy_here() -> bool:
	return _near() or _used_frame == Engine.get_process_frames()


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
	_speak("You", "Got it. Now the rain-catcher: it's on the outer ring, at the far west end.", 6.0)


func _fit() -> void:
	world.valve.reparent(world.city, false)
	world.valve.scale = Vector3.ONE
	world.valve.position = world.catcher_use
	world.catcher_water.visible = true
	_splash()
	sfx.clunk()
	sfx.bell()
	step = Step.DONE
	step_changed.emit("valve_fitted")
	_speak("Mira (calling from the plaza)", "You did it! I can hear the water running from up here. Thank you, neighbour!", 10.0)


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


## Roughly where something is from you: distance, compass direction and which level.
func _where(target: Vector3) -> String:
	var d: Vector3 = target - player.position
	var dist := Vector2(d.x, d.z).length()
	if dist < 4.0:
		return "right here"
	var dirs := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var i := posmod(roundi(atan2(d.z, d.x) / (TAU / 8.0)), 8)
	var s := "%d m %s" % [roundi(dist), dirs[i]]
	if d.y > 2.0:
		s += ", up the stairs"
	elif d.y < -2.0:
		s += ", down the stairs"
	return s


func _speak(who: String, text: String, seconds: float) -> void:
	_say.text = "%s:  \"%s\"" % [who, text]
	_say_time = seconds


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_goal = _label(layer, Vector2(20, 16), 22)
	_say = _label(layer, Vector2(20, 54), 19)
	_say.size = Vector2(900, 80)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt = _label(layer, Vector2(0, 0), 24)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.7
	_prompt.anchor_bottom = 0.7
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keys := _label(layer, Vector2(20, 0), 15)
	keys.anchor_top = 1.0
	keys.anchor_bottom = 1.0
	keys.offset_top = -34
	keys.text = "Click, then mouse: look    WASD / arrows: walk    Shift: run    E: use    Wheel or + -: zoom (all the way in = your eyes)    Z X: turn    T: an hour later    F2: something felt off    F3: info    F4: sounds    F5: mood    F6: quality    Esc: free mouse / quit"
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 0.75
	_bar.anchor_bottom = 0.75
	_bar.offset_left = -150
	_bar.offset_right = 150
	_bar.offset_bottom = 16
	layer.add_child(_bar)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(22, 0), Vector2(-14, -15), Vector2(-6, 0), Vector2(-14, 15)])
	_arrow.color = Color(1.0, 0.8, 0.3)
	layer.add_child(_arrow)


func _label(layer: CanvasLayer, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
	l.add_theme_constant_override("outline_size", 6)
	layer.add_child(l)
	return l


## Mira: a neighbour beside you in the plaza, with a speech bubble at the start.
func _make_mira() -> void:
	_mira = world._make_character(preload("res://town_data.gd").CAST["mira"])
	world.city.add_child(_mira)
	world.cast_nodes["mira"] = _mira
	_mira.position = world.mira_spot
	var d: Vector3 = player.position - world.mira_spot
	_mira.rotation.y = atan2(-d.z, d.x)
	_bubble = Label3D.new()
	_bubble.text = "Could you fix the\nrain-catcher for us?"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 2.4, 0)
	_bubble.font_size = 30
	_bubble.fixed_size = true
	_bubble.pixel_size = 0.0011
	_bubble.outline_size = 10
	_bubble.no_depth_test = true
	_mira.add_child(_bubble)


## A glowing gold diamond floating over where to go next, bigger when zoomed out.
func _make_marker() -> void:
	_marker = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.45
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	_marker.mesh = m
	world.city.add_child(_marker)


func _update_marker() -> void:
	_marker.visible = step != Step.DONE
	_arrow.visible = false
	if not _marker.visible:
		return
	var target: Vector3 = world.workshop_use if step == Step.GET_VALVE else world.catcher_use
	_marker.position = target + Vector3(0, 2.2 + sin(_t * 2.5) * 0.15, 0)
	_marker.rotation = Vector3(PI / 4.0, _t * 1.5, PI / 4.0)
	var dist := camera.global_position.distance_to(_marker.global_position)
	_marker.scale = Vector3.ONE * maxf(1.0, dist / 18.0)
	# Off-screen? Show a gold arrow at the screen edge pointing the way.
	var size := get_viewport().get_visible_rect().size
	if size.x < 200.0 or size.y < 200.0:
		return
	var behind := camera.is_position_behind(_marker.global_position)
	var sp := camera.unproject_position(_marker.global_position)
	if behind or not Rect2(Vector2.ZERO, size).grow(-40.0).has_point(sp):
		var centre := size * 0.5
		var ang := ((sp - centre) * (-1.0 if behind else 1.0)).angle()
		_arrow.position = centre + Vector2(cos(ang) * (centre.x - 60.0), sin(ang) * (centre.y - 60.0))
		_arrow.rotation = ang
		_arrow.visible = true
