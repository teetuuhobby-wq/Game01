extends Node
## PLAYTEST RECORDER: while you play, quietly writes what happens to a new folder in
## game/playtests/ (named by date and time) so Claude can study the session afterwards:
##   inputs.csv   every frame's keys and mouse, so Claude can replay the session exactly
##   log.csv      ten times a second: where you are, the camera, frame rate, errand step
##   events.csv   moments worth a look: your F2 flags (with your note and a screenshot),
##                and automatic ones: stuck, camera jumping in, low frame rate, errand steps
##   session.txt  which computer, and the tuning numbers used
## F2 = "that felt off": saves a screenshot, and you can type a short note.
## F3 = debug info on screen. Nothing is uploaded; playtests/ is kept out of git.

const T := preload("res://tuning.gd")
const Day := preload("res://day.gd")

var world: Node3D
var player: Node3D
var camera: Camera3D
var controls: Node
var errand: Node
var welcome: Node = null   # the morning round (welcome.gd): its stops go in events.csv too
var day_view: Node    # day_view.gd: the clock (its start time is saved, so a replay starts then too)

var folder := ""
var _inputs: FileAccess
var _log: FileAccess
var _events: FileAccess
var _frame := 0
var _time := 0.0
var _since_log := 0.0
var _since_flush := 0.0
var _flags := 0
var _last_pos := Vector3.ZERO
var _stuck_time := 0.0
var _stuck_noted := false
var _cam_history: Array = []    # [time, distance] for the last half second
var _last_cam_event := -10.0
var _slow_time := 0.0
var _last_slow_event := -30.0

var _note_box: LineEdit
var _note_hint: Label
var _pending_flag := {}
var _overlay: Label


func start() -> void:
	process_priority = -99   # right after the controls, before anything moves
	var base := "user://playtests" if OS.has_feature("template") else "res://playtests"   # exported builds can't write next to the game
	folder = base.path_join(Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_inputs = FileAccess.open(folder.path_join("inputs.csv"), FileAccess.WRITE)
	_inputs.store_line(controls.HEADER)
	_log = FileAccess.open(folder.path_join("log.csv"), FileAccess.WRITE)
	_log.store_line("frame,time,x,y,z,floor,moving,facing_deg,cam_zoom,cam_distance,cam_lift_deg,cam_pull,cam_yaw_deg,fps,errand_step")
	_events = FileAccess.open(folder.path_join("events.csv"), FileAccess.WRITE)
	_events.store_line("frame,time,kind,details,screenshot")
	var info := FileAccess.open(folder.path_join("session.txt"), FileAccess.WRITE)
	info.store_line("Playtest recorded %s" % Time.get_datetime_string_from_system(false, true))
	info.store_line("Graphics: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	info.store_line("Window: %s" % str(get_viewport().get_visible_rect().size))
	info.store_line("Godot: %s" % Engine.get_version_info()["string"])
	info.store_line("Game version (git commit): %s" % _git_commit())
	if day_view != null:
		info.store_line("Start time: day %d, hour %.6f" % [day_view.day.day, day_view.day.hour])
	info.store_line("Tuning:")
	var tuning: Script = T
	var consts: Dictionary = tuning.get_script_constant_map()
	for c in consts:
		info.store_line("  %s = %s" % [c, str(consts[c])])
	info.close()
	errand.step_changed.connect(func(what: String) -> void: _event("errand", what))
	if welcome != null:
		welcome.step_changed.connect(func(what: String) -> void: _event("round", what))
	_last_pos = player.position
	_make_ui()
	_event("start", "session started")


func _process(delta: float) -> void:
	if _inputs == null:
		return
	_time += delta
	_inputs.store_line(controls.to_row(_frame, delta))
	_since_log += delta
	if _since_log >= 0.1:
		_since_log = 0.0
		_write_log(delta)
	_auto_flags(delta)
	if controls.flag_pressed and _pending_flag.is_empty():
		_start_flag()
	if Input.is_action_just_pressed("debug"):
		_overlay.visible = not _overlay.visible
	if _overlay.visible:
		_update_overlay(delta)
	_since_flush += delta
	if _since_flush > 1.0:
		_since_flush = 0.0
		_inputs.flush()
		_log.flush()
		_events.flush()
	_frame += 1


func _exit_tree() -> void:
	if _inputs:
		_event("end", "session ended after %.0f s" % _time)
		for f in [_inputs, _log, _events]:
			f.close()


func _write_log(delta: float) -> void:
	var p: Vector3 = player.position
	var f: Vector3 = player.facing
	_log.store_line("%d,%.2f,%.3f,%.3f,%.3f,%d,%d,%.0f,%.3f,%.2f,%.1f,%.3f,%.0f,%.0f,%d" % [_frame, _time, p.x, p.y, p.z,
			world.floor_at(p), int(player.moving), rad_to_deg(atan2(-f.z, f.x)), camera.zoom, camera.distance,
			rad_to_deg(camera.lift), camera.pull, rad_to_deg(camera.yaw), Engine.get_frames_per_second(), errand.step])


func _event(kind: String, details: String, shot := "") -> void:
	_events.store_line("%d,%.2f,%s,\"%s\",%s" % [_frame, _time, kind, details.replace("\"", "'"), shot])
	_events.flush()


## Moments worth a look that you didn't flag: getting stuck, the camera jumping in,
## and the frame rate dropping low.
func _auto_flags(delta: float) -> void:
	var p: Vector3 = player.position
	var moved := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	# (Not while you sit: then a walk key you're still holding is meant to do nothing)
	if controls.move.length() > 0.5 and moved < 0.2 * delta and not player.seated:
		_stuck_time += delta
		if _stuck_time > 0.8 and not _stuck_noted:
			_stuck_noted = true
			_event("stuck", "holding a direction but not moving, at %s floor %d" % [str(p.snapped(Vector3.ONE * 0.1)), world.floor_at(p)])
	else:
		_stuck_time = 0.0
		_stuck_noted = false
	_cam_history.append([_time, camera.distance])
	while _cam_history.size() > 1 and _cam_history[0][0] < _time - 0.5:
		_cam_history.pop_front()
	var longest := 0.0
	for h in _cam_history:
		longest = maxf(longest, h[1])
	if _time > 2.0 and camera.distance < longest * 0.65 and _time - _last_cam_event > 1.5:
		_last_cam_event = _time
		_event("camera_jump", "camera moved in from %.1f m to %.1f m within half a second (lift %.0f deg)" % [longest, camera.distance, rad_to_deg(camera.lift)])
	if delta > 1.0 / 15.0:
		_slow_time += delta
		if _slow_time > 2.0 and _time - _last_slow_event > 30.0:
			_last_slow_event = _time
			_event("low_fps", "under 15 FPS for 2 s")
	else:
		_slow_time = 0.0


## The git commit the game is running from, so a replay can use the same version.
func _git_commit() -> String:
	var git := ProjectSettings.globalize_path("res://").path_join("../.git")
	var head := FileAccess.get_file_as_string(git.path_join("HEAD")).strip_edges()
	if head.begins_with("ref: "):
		var ref := FileAccess.get_file_as_string(git.path_join(head.substr(5))).strip_edges()
		return ref if ref != "" else head.substr(5)
	return head if head != "" else "unknown"


# ---------- F2: "that felt off" ----------

func _start_flag() -> void:
	_flags += 1
	var shot := "flag_%02d.png" % _flags
	get_viewport().get_texture().get_image().save_png(folder.path_join(shot))
	_pending_flag = {"frame": _frame, "time": _time, "shot": shot}
	controls.typing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_note_box.text = ""
	_note_box.visible = true
	_note_hint.visible = true
	_note_box.grab_focus()


func _finish_flag(note: String) -> void:
	_events.store_line("%d,%.2f,flag,\"%s\",%s" % [_pending_flag["frame"], _pending_flag["time"],
			(note if note != "" else "(no note)").replace("\"", "'"), _pending_flag["shot"]])
	_events.flush()
	_pending_flag = {}
	_note_box.visible = false
	_note_hint.visible = false
	_note_box.release_focus()
	controls.typing = false


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_note_box = LineEdit.new()
	_note_box.placeholder_text = "What felt off? (Enter saves, Esc skips)"
	_note_box.anchor_left = 0.5
	_note_box.anchor_right = 0.5
	_note_box.anchor_top = 0.45
	_note_box.anchor_bottom = 0.45
	_note_box.offset_left = -330
	_note_box.offset_right = 330
	_note_box.add_theme_font_size_override("font_size", 22)
	_note_box.visible = false
	_note_box.text_submitted.connect(_finish_flag)
	_note_box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_note_box.accept_event()
			_finish_flag(""))
	layer.add_child(_note_box)
	_note_hint = Label.new()
	_note_hint.text = "Screenshot saved. Type a short note about what felt off (optional)."
	_note_hint.anchor_left = 0.5
	_note_hint.anchor_right = 0.5
	_note_hint.anchor_top = 0.45
	_note_hint.anchor_bottom = 0.45
	_note_hint.offset_left = -330
	_note_hint.offset_top = -36
	_note_hint.add_theme_font_size_override("font_size", 18)
	_note_hint.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
	_note_hint.add_theme_constant_override("outline_size", 6)
	_note_hint.visible = false
	layer.add_child(_note_hint)
	_overlay = Label.new()
	_overlay.position = Vector2(20, 120)
	_overlay.add_theme_font_size_override("font_size", 16)
	_overlay.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_overlay.add_theme_constant_override("outline_size", 5)
	_overlay.visible = false
	layer.add_child(_overlay)


# ---------- F3: debug info ----------

func _update_overlay(_delta: float) -> void:
	var p: Vector3 = player.position
	var f: int = world.floor_at(p)
	var names := ["deck (outer ring)", "middle terrace", "top terrace"]
	var level := "?"
	for i in range(world.LEVELS.size() - 1, -1, -1):
		if f >= world.LEVELS[i][1]:
			level = names[i]
			break
	_overlay.text = "\n".join([
		"FPS %d" % Engine.get_frames_per_second(),
		"You: %.1f, %.1f m   floor %d (%s)%s" % [p.x, p.z, f, level, "   STUCK?" if _stuck_noted else ""],
		("Camera: FIRST PERSON" if camera.first_person > 0.5 else "Camera: zoom %.2f   %.1f m away   lift %.0f deg   pulled in to %d%%" % [camera.zoom, camera.distance, rad_to_deg(camera.lift), roundi(camera.pull * 100)]),
		"Errand step %d   F2 flags %d" % [errand.step, _flags],
		("Clock: day %d, %s (hour %.2f)   T: an hour later" % [day_view.day.day, Day.clock_text(day_view.day.hour), day_view.day.hour]) if day_view != null else "",
		"Recording to %s" % folder.get_file(),
	])
