extends "res://main.gd"
## DUSK, a look test to watch (not play): the walking city slows at sunset, kneels for
## the night, lowers its cargo lift to the sand and lights its lanterns, while the
## desert goes dark and something out there opens its eyes.
## Three lighting versions to compare: 1 = Ember (warm orange into purple), 2 = Blue
## hour (cool blue with warm windows), 3 = Dust (a red, hazy dusk). R plays it again,
## Esc quits. Run with dusk.bat, or: godot --path game res://dusk.tscn -- --variant 2
## With --shots it saves four pictures per version to shots/ and quits.

const LENGTH := 48.0     # seconds for the whole scene

## Each version: the light at the start, as night falls, and at full night (mood.gd values),
## plus the haze colour and the lamps' glow at night.
const VARIANTS := {
	"1": {"name": "Ember", "fog": Color(0.55, 0.32, 0.30), "night_fog": Color(0.12, 0.08, 0.16), "glow": 4.0,
		"keys": [
			{"sun_height": 14.0, "sun_turn": -40.0, "sun_warmth": 0.85, "sun_brightness": 1.6, "shadow_fill": 0.45, "shadow_warmth": 0.9, "sky_brightness": 0.8, "glare": 0.6, "haze": 0.0012, "exposure": 1.0, "colour": 1.2, "contrast": 1.1, "miniature": 0.0},
			{"sun_height": 2.0, "sun_turn": -40.0, "sun_warmth": 1.0, "sun_brightness": 0.9, "shadow_fill": 0.35, "shadow_warmth": 0.6, "sky_brightness": 0.35, "glare": 0.9, "haze": 0.002, "exposure": 1.05, "colour": 1.25, "contrast": 1.12, "miniature": 0.0},
			{"sun_height": 35.0, "sun_turn": 70.0, "sun_warmth": -0.6, "sun_brightness": 0.05, "shadow_fill": 0.05, "shadow_warmth": 0.1, "sky_brightness": 0.04, "glare": 1.3, "haze": 0.004, "exposure": 1.3, "colour": 1.0, "contrast": 1.08, "miniature": 0.0},
		]},
	"2": {"name": "Blue hour", "fog": Color(0.45, 0.50, 0.62), "night_fog": Color(0.06, 0.09, 0.18), "glow": 4.5,
		"keys": [
			{"sun_height": 10.0, "sun_turn": -40.0, "sun_warmth": 0.5, "sun_brightness": 1.3, "shadow_fill": 0.55, "shadow_warmth": 0.3, "sky_brightness": 0.8, "glare": 0.4, "haze": 0.001, "exposure": 1.0, "colour": 1.05, "contrast": 1.05, "miniature": 0.0},
			{"sun_height": -2.0, "sun_turn": -40.0, "sun_warmth": -0.3, "sun_brightness": 0.5, "shadow_fill": 0.4, "shadow_warmth": 0.0, "sky_brightness": 0.3, "glare": 0.9, "haze": 0.0018, "exposure": 1.1, "colour": 1.0, "contrast": 1.05, "miniature": 0.0},
			{"sun_height": 40.0, "sun_turn": 60.0, "sun_warmth": -0.9, "sun_brightness": 0.06, "shadow_fill": 0.06, "shadow_warmth": 0.0, "sky_brightness": 0.06, "glare": 1.3, "haze": 0.0035, "exposure": 1.35, "colour": 0.95, "contrast": 1.05, "miniature": 0.0},
		]},
	"3": {"name": "Dust", "fog": Color(0.70, 0.40, 0.25), "night_fog": Color(0.20, 0.10, 0.08), "glow": 3.5,
		"keys": [
			{"sun_height": 12.0, "sun_turn": -40.0, "sun_warmth": 0.9, "sun_brightness": 1.2, "shadow_fill": 0.55, "shadow_warmth": 1.0, "sky_brightness": 0.7, "glare": 0.7, "haze": 0.005, "exposure": 0.95, "colour": 1.1, "contrast": 1.0, "miniature": 0.0},
			{"sun_height": 3.0, "sun_turn": -40.0, "sun_warmth": 1.0, "sun_brightness": 0.7, "shadow_fill": 0.4, "shadow_warmth": 1.0, "sky_brightness": 0.3, "glare": 1.0, "haze": 0.007, "exposure": 1.0, "colour": 1.15, "contrast": 1.0, "miniature": 0.0},
			{"sun_height": 30.0, "sun_turn": 70.0, "sun_warmth": -0.3, "sun_brightness": 0.04, "shadow_fill": 0.05, "shadow_warmth": 0.4, "sky_brightness": 0.03, "glare": 1.4, "haze": 0.006, "exposure": 1.3, "colour": 0.95, "contrast": 1.05, "miniature": 0.0},
		]},
}

var variant := "1"
var shots := false
var _mood: Node
var _cam: Camera3D
var _t := 0.0
var _lift: Node3D
var _chains: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _eyes: Array[MeshInstance3D] = []
var _eyes_placed := false
var _caption: Label
var _stars: MultiMeshInstance3D
var _ground_lights: Array[OmniLight3D] = []
var _shot_i := 0
var _start_x := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var vi := args.find("--variant")
	if vi >= 0 and vi + 1 < args.size() and VARIANTS.has(args[vi + 1]):
		variant = args[vi + 1]
	shots = args.has("--shots")
	super()
	for c in get_children():
		if c.get_script() == preload("res://mood.gd"):
			_mood = c
	_hide_game_ui(self)
	player.visible = false
	player.position = Vector3(0, -50, 0)   # out of the way, under the deck
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 2000.0
	add_child(_cam)
	_cam.make_current()
	_make_lift()
	_make_lights()
	_make_eyes()
	_make_stars()
	_make_ground_glow()
	_make_caption()
	_restart()


## The errand's text, the key hints and the panels: hidden, so it plays like a film.
func _hide_game_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			c.visible = false
		_hide_game_ui(c)


func _restart() -> void:
	_t = 0.0
	_shot_i = 0
	_eyes_placed = false
	world.walk_rate = 1.0
	world.kneel = 0.0
	_start_x = world.city.position.x
	_caption.text = "Dusk test, version %s: %s     (1 / 2 / 3 switch, R replay, Esc quit)" % [variant, VARIANTS[variant]["name"]]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				variant = str(event.physical_keycode - KEY_0)
				_restart()
			KEY_R:
				_restart()
			KEY_ESCAPE:
				get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / LENGTH, 0.0, 1.0)
	var v: Dictionary = VARIANTS[variant]
	# The light: day -> sunset over the first half, sunset -> night over the second
	var keys: Array = v["keys"]
	var a: Dictionary = keys[0] if k < 0.45 else keys[1]
	var b: Dictionary = keys[1] if k < 0.45 else keys[2]
	var f := smoothstep(0.0, 1.0, k / 0.45 if k < 0.45 else (k - 0.45) / 0.55)
	for key in a:
		_mood.values[key] = lerpf(a[key], b[key], f)
	if k >= 0.45:
		# The sun goes quickly once it's down: no hard daylight after sunset
		var quick := smoothstep(0.45, 0.6, k)
		for key in ["sun_brightness", "shadow_fill"]:
			_mood.values[key] = lerpf(a[key], b[key], quick)
	_mood.apply()
	# The sky: a deep blue dome with a last ember band low on the horizon, and stars
	var night_sky := smoothstep(0.4, 0.85, k)
	world.sky_mat.sky_top_color = Color(0.45, 0.66, 0.74).lerp(Color(0.03, 0.06, 0.18), night_sky)
	world.sky_mat.sky_horizon_color = Color(0.98, 0.80, 0.62).lerp(v["fog"], smoothstep(0.1, 0.45, k)).lerp(Color(0.35, 0.14, 0.08), night_sky)
	_stars.visible = night_sky > 0.3
	(_stars.multimesh.mesh.material as StandardMaterial3D).albedo_color.a = night_sky
	for g in _ground_lights:
		g.light_energy = smoothstep(0.55, 0.85, k) * 6.0
	var night := smoothstep(0.35, 0.8, k)
	world.env.fog_light_color = (v["fog"] as Color).lerp(v["night_fog"], night)
	world.mat_glow.emission_energy_multiplier = lerpf(1.2, v["glow"], night)
	for l in _lights:
		l.light_energy = night * 1.6
	# The city slows and stops, then kneels, then lowers the lift
	world.walk_rate = 1.0 - smoothstep(0.15, 0.42, k)
	world.kneel = smoothstep(0.42, 0.62, k)
	var lower := smoothstep(0.62, 0.8, k)
	var deck_bottom := -11.5
	var ground_local: float = world.ground_at(world.city.position.x, 0.0) - world.city.position.y + 0.3
	_lift.position.y = lerpf(deck_bottom, ground_local, lower)
	for ch in _chains:
		var top_y := deck_bottom + 0.3
		var len := maxf(top_y - _lift.position.y, 0.05)
		ch.scale = Vector3(1, len, 1)
		ch.position.y = _lift.position.y + len * 0.5
	# Eyes in the dark, once night has fallen: they blink and drift
	var eyes_on := smoothstep(0.78, 0.9, k)
	if eyes_on > 0.0 and not _eyes_placed:
		_place_eyes()
	for i in _eyes.size():
		var e := _eyes[i]
		e.visible = eyes_on > 0.05 and fmod(_t * (0.6 + (i / 2) * 0.07) + (i / 2) * 1.3, 4.0) > 0.35
		if (i / 2) % 3 == 1:
			e.position.x += sin(_t * 0.3 + i) * 0.02   # a few creep slowly
		(e.material_override as StandardMaterial3D).albedo_color.a = eyes_on
	_move_camera(k)
	if shots:
		for i in 4:
			var at := [0.12, 0.45, 0.68, 0.95][i] as float
			if _shot_i == i and k >= at:
				_shot_i += 1
				_save_dusk_shot(i)
		if k >= 1.0 and _shot_i >= 4:
			get_tree().create_timer(0.5).timeout.connect(get_tree().quit)
			shots = false
	if k >= 1.0 and not shots and OS.get_cmdline_user_args().has("--loop"):
		_restart()


## A slow drifting shot: out in the desert ahead of the city, swinging round toward
## its side as it stops, then easing in to the lit deck and the lift at night.
func _move_camera(k: float) -> void:
	var from := _cam_pose(k)
	_cam.position = from
	if _stars != null:
		_stars.global_position = from
	var c: Vector3 = world.city.position
	var look := c + Vector3(0, lerpf(4.0, -11.0, smoothstep(0.5, 1.0, k)), 0)
	_cam.look_at(look, Vector3.UP)


## Where the camera is at moment k (0..1) of the scene.
func _cam_pose(k: float) -> Vector3:
	var c: Vector3 = world.city.position
	var ang := lerpf(-0.35, 0.5, smoothstep(0.0, 1.0, k))
	var dist := lerpf(115.0, 100.0, smoothstep(0.3, 0.7, k)) + 45.0 * smoothstep(0.72, 1.0, k)
	var h := lerpf(24.0, 9.0, smoothstep(0.2, 0.7, k)) - 5.0 * smoothstep(0.72, 1.0, k)
	var from := c + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
	from.y = world.ground_at(from.x, from.z) + h
	return from


## The cargo lift: a timber platform with rails, crates and a lantern, on four chains
## from the underside of the deck.
func _make_lift() -> void:
	_lift = Node3D.new()
	world.city.add_child(_lift)
	var pts := []
	var cols := []
	var vs: float = world.VS
	for x in range(-20, 21):
		for z in range(-15, 16):
			pts.append(Vector3(x, 0, z) * vs)
			cols.append(world.PAL[world.P.WOOD] if posmod(x, 4) != 0 else world.PAL[world.P.WOOD_DARK])
			if absi(x) == 20 or absi(z) == 15:
				for y in range(1, 5):
					if y == 4 or posmod(x + z, 4) == 0:
						pts.append(Vector3(x, y, z) * vs)
						cols.append(world.PAL[world.P.IRON])
	for c in [Vector3i(-12, 0, -8), Vector3i(-8, 0, -8), Vector3i(-12, 0, 6), Vector3i(10, 0, 4)]:
		for x in range(0, 3):
			for y in range(1, 4):
				for z in range(0, 3):
					pts.append(Vector3(c.x + x, y, c.z + z) * vs)
					cols.append(world.PAL[world.P.WOOD_DARK] if y == 2 else world.PAL[world.P.WOOD])
	var mesh: ArrayMesh = world._cubes(PackedVector3Array(pts), PackedColorArray(cols), vs, true)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_lift.add_child(mi)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 4.0
	lamp.omni_range = 16.0
	lamp.position = Vector3(0, 1.4, 0)
	_lift.add_child(lamp)
	var glow := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.3, 0.4, 0.3)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(2.0, 1.4, 0.8)
	gb.material = gm
	glow.mesh = gb
	glow.position = Vector3(0, 1.2, 0)
	_lift.add_child(glow)
	for corner in [Vector2(-3.8, -2.8), Vector2(3.8, -2.8), Vector2(-3.8, 2.8), Vector2(3.8, 2.8)]:
		var torch := MeshInstance3D.new()
		torch.mesh = gb
		torch.position = Vector3(corner.x, 1.1, corner.y)
		_lift.add_child(torch)
	for corner in [Vector2(-3.9, -2.9), Vector2(3.9, -2.9), Vector2(-3.9, 2.9), Vector2(3.9, 2.9)]:
		var ch := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.12, 1.0, 0.12)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.22, 0.2, 0.18)
		b.material = m
		ch.mesh = b
		ch.position = Vector3(corner.x, 0, corner.y)
		world.city.add_child(ch)
		_chains.append(ch)


## Real lights at the city's lamps, so the streets glow at night (found from the
## glowing blocks, at most one every 9 m).
func _make_lights() -> void:
	var taken := {}
	var glow_id: int = world.P.GLOW
	for i in world.filled:
		if world.grid[i] != glow_id:
			continue
		var x: int = i % world.NX + world.GX0
		var rest: int = i / world.NX
		var z: int = rest % world.NZ + world.GZ0
		var y: int = rest / world.NZ + world.GY0
		var cell := Vector3i(floori(x / 45.0), floori(y / 45.0), floori(z / 45.0))
		if taken.has(cell) or y < 0:
			continue
		taken[cell] = true
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.42)
		l.omni_range = 9.0
		l.omni_attenuation = 1.3
		l.light_energy = 0.0
		l.position = Vector3(x, y, z) * world.VS
		world.city.add_child(l)
		_lights.append(l)
	print("dusk: %d street lights" % _lights.size())


## Puts the pairs of eyes out in the dark, in view: 25-55 m from the camera, off to
## the sides of the city, low over the sand.
func _place_eyes() -> void:
	_eyes_placed = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var end := _cam_pose(1.0)                 # where the camera will end up
	var fwd: Vector3 = world.city.position - end
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	for i in range(0, _eyes.size(), 2):
		var side := -1.0 if (i / 2) % 2 == 0 else 1.0
		var d := rng.randf_range(18.0, 45.0)
		var off := rng.randf_range(0.25, 0.6) * d * side
		var c := end + fwd * d + right * off
		c.y = world.ground_at(c.x, c.z) + rng.randf_range(0.5, 1.1)
		_eyes[i].global_position = c - right * 0.35
		_eyes[i + 1].global_position = c + right * 0.35


## Stars, faded in as night falls.
func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.albedo_color = Color(1, 1, 1, 0)
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = 700
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.08, 1.0), rng.randf_range(-1, 1)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.6, 1.8)), dir * 900.0))
		var b := rng.randf_range(0.6, 1.4)
		mm.set_instance_color(i, Color(b, b, b * 1.1))
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars.visible = false
	_cam.add_child(_stars)     # the sky moves with the camera, so it's always far away
	_stars.top_level = true


## A warm pool of light spilling onto the sand around the knelt city.
func _make_ground_glow() -> void:
	for p in [Vector3(-30, -8, -18), Vector3(30, -8, -18), Vector3(-30, -8, 18), Vector3(30, -8, 18), Vector3(0, -8, 0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.32)
		l.omni_range = 34.0
		l.omni_attenuation = 1.6
		l.light_energy = 0.0
		l.position = p
		world.city.add_child(l)
		_ground_lights.append(l)


## Pairs of glowing eyes out in the dark desert (placed when night falls).
func _make_eyes() -> void:
	for i in 6:
		for side in 2:
			var e := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.28, 0.18, 0.28)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1.8, 0.75, 0.25, 0.0) if i % 3 != 0 else Color(1.8, 0.3, 0.15, 0.0)
			e.material_override = m
			e.mesh = b
			add_child(e)
			_eyes.append(e)


func _make_caption() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = 20
	_caption.offset_top = -34
	layer.add_child(_caption)


func _save_dusk_shot(i: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/dusk_v%s_%d.png" % [variant, i + 1])
	print("shot: dusk v%s %d" % [variant, i + 1])
