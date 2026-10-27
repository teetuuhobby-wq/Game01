extends "res://dusk.gd"
# Dusk test (headless): the dusk scene plays its whole 48 s without errors and the city
# kneels at the end; then it plays again (--loop) and again (the R key), and each replay
# starts exactly like the first run: the city in the same place at the same moment of the
# scene, and no extra giant steps at the cut.
# (Godot's very first frame is a little shorter than the rest, so the first run's frames
# fall at slightly different moments: the replays are compared with the first run part
# way between its frames, which is good to a few millimetres. A replay starting on the
# wrong stretch of desert would be metres off; even one frame out is 20 cm.)
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/dusk_test.tscn -- --no-record --loop

const COMPARE_FRAMES := 200   # frames of each replay checked against the first run (10 s at 20 FPS)

var _run := 1                # 1 = first run, 2 = after --loop, 3 = after pressing R
var _last_frame := 0
var _first_t := PackedFloat64Array()     # the first run: each frame's moment of the scene...
var _first_pos := PackedVector3Array()   # ...and where the city was then
var _j := 0                  # where we are in the first run, when comparing
var _worst := [0.0, 0.0, 0.0, 0.0]   # biggest gap from the first run, per run
var _clock0 := [0.0, 0.0, 0.0, 0.0]  # the city's walk clock when each run began
var _stomps := [[], [], [], []]      # frames with a giant step, per run
var _knelt := 0.0
var _results := []


func _ready() -> void:
	super()
	world.stomped.connect(func(_at: Vector3) -> void:
		_stomps[_run].append(_last_frame))


func _process(delta: float) -> void:
	# Before the scene moves on: where the city ended up last frame, and which frame that was
	var frame := roundi(_t / delta)
	if frame < _last_frame:
		_run += 1    # the scene went back to the start
	_last_frame = frame
	var pos: Vector3 = world.city.position
	if frame == 1:
		_clock0[_run] = world.t - _t   # the city walks at full speed at first: its clock ran as long as the scene's
	if frame >= 1:
		if _run == 1:
			_first_t.append(_t)
			_first_pos.append(pos)
			_knelt = world.kneel
		elif frame <= COMPARE_FRAMES:
			_worst[_run] = maxf(_worst[_run], pos.distance_to(_first_run_at(_t)))
	if _run == 2 and frame == COMPARE_FRAMES:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_R
		ev.pressed = true
		Input.parse_input_event(ev)
	if _run == 3 and frame == COMPARE_FRAMES:
		_finish()
		return
	super(delta)


## Where the city was in the first run at moment t of the scene (between two frames,
## part way from one to the other).
func _first_run_at(t: float) -> Vector3:
	if _j > 0 and _first_t[_j] > t:
		_j = 0      # a new replay: search from the start again
	while _j + 2 < _first_t.size() and _first_t[_j + 1] < t:
		_j += 1
	var a := _first_t[_j]
	var b := _first_t[_j + 1]
	return _first_pos[_j].lerp(_first_pos[_j + 1], clampf((t - a) / (b - a), 0.0, 1.0))


func _finish() -> void:
	set_process(false)
	var early: Array = _stomps[1].filter(func(f: int) -> bool: return f <= COMPARE_FRAMES)
	_results.append(["the whole scene plays and the city kneels for the night", _first_t[_first_t.size() - 1] >= LENGTH and _knelt > 0.99,
			"%d frames, %.1f s, kneel %.2f" % [_first_t.size(), _first_t[_first_t.size() - 1], _knelt]])
	_results.append(["each replay starts the city's walk clock where the first run did",
			absf(_clock0[2] - _clock0[1]) < 0.0001 and absf(_clock0[3] - _clock0[1]) < 0.0001,
			"first run %.4f, loop %.4f, R %.4f" % [_clock0[1], _clock0[2], _clock0[3]]])
	_results.append(["--loop replays from the same spot: the city is where it was in the first run", _worst[2] < 0.02,
			"furthest off %.4f m over %d frames" % [_worst[2], COMPARE_FRAMES]])
	_results.append(["R replays from the same spot too", _worst[3] < 0.02,
			"furthest off %.4f m over %d frames" % [_worst[3], COMPARE_FRAMES]])
	_results.append(["no extra giant steps at the cut: the same steps as the first run", _stomps[2] == early and _stomps[3] == early,
			"first run %s, loop %s, R %s" % [early, _stomps[2], _stomps[3]]])
	var ok := true
	for r in _results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
