extends Node
## QUALITY: "high" (the home PC) or "low" (a weaker laptop). Low draws the 3D at a
## lower resolution and scales it up (FSR), turns off the soft shadows in corners (SSAO),
## glow, the miniature blur and edge smoothing, uses hard sun shadows on nearby streets
## only, sees less far (with a little more haze), and hides people more than 45 m away.
## F6 switches while you play; start in low with run_low.bat (or "-- --quality low"),
## or set QUALITY in tuning.gd.

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
			"far": camera.far, "glow": world.env.glow_enabled, "split": world.sun.directional_shadow_mode,
			"fog": world.env.fog_density}
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
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if low else Viewport.SCALING_3D_MODE_BILINEAR   # FSR keeps edges sharper
	vp.scaling_3d_scale = LOW_RENDER_SCALE if low else _saved["scale"]
	vp.msaa_3d = Viewport.MSAA_DISABLED if low else _saved["msaa"]
	world.env.ssao_enabled = false if low else _saved["ssao"]
	world.sun.directional_shadow_max_distance = 80.0 if low else _saved["shadow"]
	camera.attributes = null if low else _saved["attributes"]
	camera.far = LOW_VIEW_DISTANCE if low else _saved["far"]
	world.people_view = LOW_PEOPLE_VIEW if low else INF
	# Glow is several full-screen blurs: costly on a laptop's graphics chip
	world.env.glow_enabled = false if low else _saved["glow"]
	# Hard, simpler sun shadows (they suit blocks anyway)
	world.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if low else _saved["split"]
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_HARD if low else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	# A little more haze, so the shorter view doesn't end in a visible edge
	world.env.fog_density = maxf(_saved["fog"], 0.004) if low else _saved["fog"]
	print("quality: ", level)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quality"):
		set_level("high" if level == "low" else "low")
