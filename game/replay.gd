extends Node
## REPLAY: plays a recorded playtest back exactly (the same keys, mouse and frame
## timings), so Claude can see what you saw. Run it hidden, always at 60 FPS:
##   tools/godot_offscreen.ps1 game --fixed-fps 60 -- --replay playtests/<session folder> [--shots]
## With --shots it saves the camera's view at every event in events.csv (your F8 flags,
## getting stuck, the camera jumping in, errand steps): one shot a third of a second
## before, one at the moment. They go in the session's replay/ folder.
## At the end it prints how closely the replay matched the recording.

signal finished

const FPS := 60.0   # must match --fixed-fps

var controls: Node
var player: Node3D
var folder := ""
var shots := false

var _rows: Array[PackedStringArray] = []
var _k := 0
var _logged := {}       # frame -> recorded position, to check the replay stays on track
var _worst := 0.0
var _worst_frame := 0
var _shots_at := {}     # frame -> [name, ...]
var _saved := 0
var _done := false


func _ready() -> void:
	process_priority = -101   # before the controls
	controls.replaying = true
	var f := FileAccess.open(folder.path_join("inputs.csv"), FileAccess.READ)
	if f == null:
		push_error("REPLAY: can't open %s" % folder.path_join("inputs.csv"))
		_finish()
		return
	f.get_line()
	while not f.eof_reached():
		var line := f.get_line()
		if line != "":
			_rows.append(line.split(","))
	var lg := FileAccess.open(folder.path_join("log.csv"), FileAccess.READ)
	if lg:
		lg.get_line()
		while not lg.eof_reached():
			var c := lg.get_line().split(",")
			if c.size() > 4:
				_logged[c[0].to_int()] = Vector3(c[2].to_float(), c[3].to_float(), c[4].to_float())
	if shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder.path_join("replay")))
		var ev := FileAccess.open(folder.path_join("events.csv"), FileAccess.READ)
		if ev:
			ev.get_line()
			while not ev.eof_reached():
				var c := ev.get_line().split(",")
				if c.size() < 3 or c[2] == "start" or c[2] == "end":
					continue
				var fr := c[0].to_int()
				_add_shot(maxi(0, fr - 20), "%05d_%s_before" % [fr, c[2]])
				_add_shot(fr, "%05d_%s" % [fr, c[2]])
	print("REPLAY: %d frames (%.0f s), %d shots planned" % [_rows.size(), _total_time(), _saved_planned()])
	if not _rows.is_empty():
		Engine.time_scale = _rows[0][1].to_float() * FPS   # so the first frame gets the recorded time step


func _process(_delta: float) -> void:
	if _done:
		return
	if _k >= _rows.size():
		_finish()
		return
	if _logged.has(_k):
		var d: float = player.position.distance_to(_logged[_k])
		if d > _worst:
			_worst = d
			_worst_frame = _k
	controls.from_row(_rows[_k])
	if _k + 1 < _rows.size():
		Engine.time_scale = _rows[_k + 1][1].to_float() * FPS
	if _shots_at.has(_k):
		_take(_shots_at[_k])
	_k += 1


func _add_shot(frame: int, name: String) -> void:
	if not _shots_at.has(frame):
		_shots_at[frame] = []
	_shots_at[frame].append(name)


func _saved_planned() -> int:
	var n := 0
	for k in _shots_at:
		n += _shots_at[k].size()
	return n


func _total_time() -> float:
	var s := 0.0
	for r in _rows:
		s += r[1].to_float()
	return s


func _take(names: Array) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	for n in names:
		img.save_png(folder.path_join("replay").path_join(n + ".png"))
		_saved += 1


func _finish() -> void:
	_done = true
	Engine.time_scale = 1.0
	controls.replaying = false
	print("REPLAY: done. Furthest the replay drifted from the recording: %.4f m (frame %d). Shots saved: %d" % [_worst, _worst_frame, _saved])
	finished.emit()
