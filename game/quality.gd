extends Node
## QUALITY: "high" (the home PC) or "low" (a weaker laptop). Low draws the 3D at a
## lower resolution and scales it up, turns off the soft shadows in corners (SSAO), the
## miniature blur and edge smoothing, keeps sun shadows to the nearby streets, sees less
## far, and hides people more than 45 m away. F6 switches while you play; start in low
## with run_low.bat (or "-- --quality low"), or set QUALITY in tuning.gd.

const T := preload("res://tuning.gd")
const LOW_RENDER_SCALE := 0.7     # share of the screen's resolution the 3D is drawn at
const LOW_PEOPLE_VIEW := 45.0     # metres: people further away are hidden in low
const LOW_VIEW_DISTANCE := 450.0  # metres the camera can see in low (high: 1000)

var world: Node3D
var camera: Camera3D
var level := "high"
var _saved := {}


func setup(w: Node3D, cam: Camera3D) -> void:
	world = w
	camera = cam
	var vp := get_viewport()
	_saved = {"scale": vp.scaling_3d_scale, "msaa": vp.msaa_3d, "ssao": world.env.ssao_enabled,
			"shadow": world.sun.directional_shadow_max_distance, "attributes": camera.attributes,
			"far": camera.far}
	var start: String = T.QUALITY
	var args := OS.get_cmdline_user_args()
	var qi := args.find("--quality")
	if qi >= 0 and qi + 1 < args.size():
		start = args[qi + 1]
	set_level(start)


func set_level(l: String) -> void:
	level = "low" if l == "low" else "high"
	var low := level == "low"
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = LOW_RENDER_SCALE if low else _saved["scale"]
	vp.msaa_3d = Viewport.MSAA_DISABLED if low else _saved["msaa"]
	world.env.ssao_enabled = false if low else _saved["ssao"]
	world.sun.directional_shadow_max_distance = 80.0 if low else _saved["shadow"]
	camera.attributes = null if low else _saved["attributes"]
	camera.far = LOW_VIEW_DISTANCE if low else _saved["far"]
	world.people_view = LOW_PEOPLE_VIEW if low else INF
	print("quality: ", level)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quality"):
		set_level("high" if level == "low" else "low")
