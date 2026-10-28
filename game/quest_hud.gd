extends Node
## THE GUIDE ON SCREEN for whatever you're doing (the morning round, Mira's errand):
## the goal line at the top, what someone just said under it, a prompt in the middle,
## a progress bar, the key hints at the bottom, and a glowing gold diamond over where
## to go next (with an arrow at the screen's edge when it's out of sight).
## One at a time: whoever is guiding you sets it each frame.

var world: Node3D      # world.gd
var camera: Camera3D

var _goal: Label
var _say: Label
var _say_time := 0.0
var _prompt: Label
var _bar: ProgressBar
var _marker: MeshInstance3D
var _arrow: Polygon2D       # points to the goal when the marker is off-screen
var _target: Variant = null # where the marker floats (a point on the city), or null
var _t := 0.0


func setup(w: Node3D, cam: Camera3D) -> void:
	world = w
	camera = cam
	_make_ui()
	_make_marker()


func goal(text: String) -> void:
	_goal.text = text


func prompt(text: String) -> void:
	_prompt.text = text


## Shows what someone said, under the goal, for a few seconds.
func speak(who: String, text: String, seconds: float) -> void:
	_say.text = "%s:  \"%s\"" % [who, text]
	_say_time = seconds


func bar(shown: bool, value: float) -> void:
	_bar.visible = shown
	_bar.value = value


## The gold diamond floats over this point on the city (null: no marker).
func point_at(at: Variant) -> void:
	_target = at


## Roughly where something is from you: distance, compass direction and which level.
func where(from: Vector3, target: Vector3) -> String:
	var d: Vector3 = target - from
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


func _process(delta: float) -> void:
	_t += delta
	_say_time -= delta
	_say.visible = _say_time > 0.0
	_update_marker()


func _make_ui() -> void:
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
	_bar.visible = false
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
	_marker.visible = _target != null
	_arrow.visible = false
	if not _marker.visible:
		return
	_marker.position = (_target as Vector3) + Vector3(0, 2.2 + sin(_t * 2.5) * 0.15, 0)
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
