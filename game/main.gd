extends Node3D
## STRIDER HOME, first playable toy: walk your town while it walks.
## Double-click run.bat to play. Tuning numbers are in tuning.gd.
## Every normal play session is recorded to playtests/ (see recorder.gd): F2 flags a
## moment, F3 shows debug info.
## Test options (after "--"): --autoplay lets a bot play the errand and quits when
## it's done; --shots saves screenshots to shots/ along the way;
## --replay <playtests/folder> plays a recorded session back (see replay.gd);
## --hour 14.5 starts at that time of day, --freeze-clock stops the clock (day_view.gd);
## --no-round skips the morning round (welcome.gd) and starts with Mira's errand.

var controls: Node
var world: Node3D
var player: Node3D
var camera: Camera3D
var sfx: Node
var errand: Node
var welcome: Node     # the morning round (welcome.gd), null when it's off
var hud: Node         # the guide on screen (quest_hud.gd): goal line, speech, gold marker
var interact: Node    # E: talk, read, sit, look (interact.gd)
var menu: CanvasLayer # the Esc menu (game_menu.gd)
var recorder: Node
var day_view: Node    # the time of day (day_view.gd; the clock itself is day.gd)
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
	var mood := preload("res://mood.gd").new()
	mood.world = world
	mood.camera = camera
	add_child(mood)
	var quality := preload("res://quality.gd").new()
	add_child(quality)
	quality.setup(world, camera, mood)
	var mood_panel := preload("res://mood_panel.gd").new()
	mood_panel.mood = mood
	mood_panel.controls = controls
	add_child(mood_panel)

	sfx = preload("res://sfx.gd").new()
	sfx.world = world
	sfx.player = player
	add_child(sfx)
	player.stepped.connect(sfx.footstep)
	var board := preload("res://sound_board.gd").new()
	board.sfx = sfx
	board.controls = controls
	add_child(board)
	menu = preload("res://game_menu.gd").new()   # Esc: pause, volume, quality, quit
	add_child(menu)
	menu.setup(controls, quality, sfx)
	world.stomped.connect(_on_stomp)
	day_view = preload("res://day_view.gd").new()
	add_child(day_view)
	day_view.setup(world, mood, sfx, controls)

	var args := OS.get_cmdline_user_args()
	hud = preload("res://quest_hud.gd").new()
	add_child(hud)
	hud.setup(world, camera)
	# The morning round comes first in normal play (and its replays); the tests, the
	# test bot (--autoplay) and --no-round start straight with Mira's errand.
	var round_on: bool = preload("res://tuning.gd").WELCOME_ROUND and scene_file_path == "res://main.tscn" \
			and not "--autoplay" in args and not "--no-round" in args
	errand = preload("res://errand.gd").new()
	add_child(errand)
	errand.setup(world, player, sfx, camera, controls, hud, not round_on)
	interact = preload("res://interact.gd").new()
	add_child(interact)
	interact.setup(world, player, controls, errand, sfx)
	if round_on:
		start_round()

	_shots = "--shots" in args
	var replay_at := args.find("--replay")
	if replay_at >= 0 and replay_at + 1 < args.size():
		var rp := preload("res://replay.gd").new()
		rp.controls = controls
		rp.player = player
		rp.folder = args[replay_at + 1] if args[replay_at + 1].begins_with("res://") else "res://" + args[replay_at + 1]
		rp.shots = _shots
		rp.day_view = day_view
		rp.finished.connect(func() -> void: get_tree().quit())   # before add_child: it may finish straight away
		add_child(rp)
		return
	# A shared build (exported, for friends) doesn't record: it starts with a tip about F6 instead
	var shared := OS.has_feature("template")
	if shared:
		hud.tip("Running slowly? Press F6 for low quality.", 25.0)
	if not "--autoplay" in args and not "--no-record" in args and not shared:   # tests pass --no-record
		recorder = preload("res://recorder.gd").new()
		recorder.world = world
		recorder.player = player
		recorder.camera = camera
		recorder.controls = controls
		recorder.errand = errand
		recorder.welcome = welcome
		recorder.day_view = day_view
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
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir()))
		if bot:
			bot.set_process(false)   # stand still for the opening shots
		await _start_shots()
		if bot:
			bot.set_process(true)


## The morning round (welcome.gd): Mira's errand waits until its last stop. (The round
## test calls this too, since tests start without the round.)
func start_round() -> void:
	welcome = preload("res://welcome.gd").new()
	add_child(welcome)
	welcome.setup(world, player, hud, errand, day_view)
	interact.welcome = welcome


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
		"sound_board": [KEY_F4], "mood": [KEY_F5], "quality": [KEY_F6],
		"skip_hour": [KEY_T],
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
	img.save_png(shot_dir().path_join("%02d_%s.png" % [_shot_n, label]))
	print("shot: ", label)


func _on_bot_finished(code: int) -> void:
	if _shots and code == 0:
		for z in [0.15, 1.0]:
			camera.snap_zoom(z)
			await _settle()
			_save_shot("done_zoom%d" % int(z * 10))
	get_tree().quit(code)


## Where --shots saves pictures: shots/ in the project, or the player's own folder in a
## shared build (it can't write next to its own files).
func shot_dir() -> String:
	return "user://shots" if OS.has_feature("template") else "res://shots"
