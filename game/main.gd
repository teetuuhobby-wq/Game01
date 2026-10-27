extends Node3D
## STRIDER HOME, first playable toy: walk your town while it walks.
## Double-click run.bat to play. Tuning numbers are in tuning.gd.
## Every normal play session is recorded to playtests/ (see recorder.gd): F2 flags a
## moment, F3 shows debug info.
## Test options (after "--"): --autoplay lets a bot play the errand and quits when
## it's done; --shots saves screenshots to shots/ along the way;
## --replay <playtests/folder> plays a recorded session back (see replay.gd).

var controls: Node
var world: Node3D
var player: Node3D
var camera: Camera3D
var sfx: Node
var errand: Node
var recorder: Node
var _shots := false
var _shot_n := 0


func _ready() -> void:
	_setup_input()
	controls = preload("res://controls.gd").new()
	add_child(controls)
	world = preload("res://world.gd").new()
	add_child(world)

	player = preload("res://player.gd").new()
	player.world = world
	player.controls = controls
	player.position = world.you_spot
	world.city.add_child(player)
	world.player = player

	camera = preload("res://camera_rig.gd").new()
	camera.target = player
	camera.world = world
	camera.controls = controls
	camera.yaw = atan2(-player.facing.z, -player.facing.x)   # start behind you
	add_child(camera)
	camera.make_current()
	world.camera = camera

	sfx = preload("res://sfx.gd").new()
	sfx.world = world
	sfx.player = player
	add_child(sfx)
	player.stepped.connect(sfx.footstep)
	world.stomped.connect(_on_stomp)

	errand = preload("res://errand.gd").new()
	add_child(errand)
	errand.setup(world, player, sfx, camera, controls)

	var args := OS.get_cmdline_user_args()
	_shots = "--shots" in args
	var replay_at := args.find("--replay")
	if replay_at >= 0 and replay_at + 1 < args.size():
		var rp := preload("res://replay.gd").new()
		rp.controls = controls
		rp.player = player
		rp.folder = args[replay_at + 1] if args[replay_at + 1].begins_with("res://") else "res://" + args[replay_at + 1]
		rp.shots = _shots
		rp.finished.connect(func() -> void: get_tree().quit())   # before add_child: it may finish straight away
		add_child(rp)
		return
	if not "--autoplay" in args and not "--no-record" in args:   # tests pass --no-record
		recorder = preload("res://recorder.gd").new()
		recorder.world = world
		recorder.player = player
		recorder.camera = camera
		recorder.controls = controls
		recorder.errand = errand
		add_child(recorder)
		recorder.start()
	var bot: Node = null
	if "--autoplay" in args:
		bot = preload("res://bot.gd").new()
		bot.world = world
		bot.player = player
		bot.errand = errand
		player.bot_mode = true
		add_child(bot)
		bot.finished.connect(_on_bot_finished)
	if _shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
		if bot:
			bot.set_process(false)   # stand still for the opening shots
		await _start_shots()
		if bot:
			bot.set_process(true)


## Esc frees the mouse; Esc again (with the mouse free) quits.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()


func _on_stomp(at: Vector3) -> void:
	sfx.stomp()
	camera.add_shake(preload("res://tuning.gd").STOMP_SHAKE)


## Keys, set up here so they're easy to find and change.
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "interact": [KEY_E, KEY_ENTER],
		"turn_left": [KEY_Z], "turn_right": [KEY_X],
		"zoom_in": [KEY_EQUAL, KEY_KP_ADD, KEY_PAGEUP], "zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN],
		"quit": [KEY_ESCAPE], "flag": [KEY_F2], "debug": [KEY_F3],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ---------- Screenshots for testing ----------

func _start_shots() -> void:
	for z in [0.0, 0.4, 1.0]:
		camera.snap_zoom(z)
		await _settle()
		_save_shot("start_zoom%d" % int(z * 10))
	camera.snap_zoom(0.4)
	errand.step_changed.connect(_save_step_shot)


func _save_step_shot(label: String) -> void:
	await _settle()
	_save_shot(label)


func _settle() -> void:
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save_shot(label: String) -> void:
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/%02d_%s.png" % [_shot_n, label])
	print("shot: ", label)


func _on_bot_finished(code: int) -> void:
	if _shots and code == 0:
		for z in [0.15, 1.0]:
			camera.snap_zoom(z)
			await _settle()
			_save_shot("done_zoom%d" % int(z * 10))
	get_tree().quit(code)
