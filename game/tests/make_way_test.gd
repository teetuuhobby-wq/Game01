extends "res://main.gd"
# A walking resident (headless) slows for you each time you
# step in front of them, not only for the first 3 seconds of their whole trip.
# Run: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/make_way_test.tscn -- --no-record --hour 14 --freeze-clock

var _id := "pip"
var _frame := 0
var _log := []


func _ready() -> void:
	super()
	day_view.day.frozen = true


func _speed_now() -> float:
	var L: Dictionary = world.life[_id]
	var before: Vector3 = L["at"]
	world._walk(world._cast_by_id[_id], L, 0.1)
	return Vector2(L["at"].x - before.x, L["at"].z - before.z).length() / 0.1


func _process(_delta: float) -> void:
	_frame += 1
	if _frame != 5:
		return
	var L: Dictionary = world.life[_id]
	var c: Dictionary = world._cast_by_id[_id]
	var start: Vector3 = c["node"].position
	# A long straight walk (the probe moves them by hand, so walls don't matter)
	L["path"] = PackedVector3Array([start + Vector3(30, 0, 0)])
	L["k"] = 0
	L["at"] = start
	L["wait"] = 0.0
	L["state"] = "walk"
	var in_front := func() -> void: player.position = L["at"] + Vector3(0.5, 0, 0)
	in_front.call()
	var first := _speed_now()
	for i in 35:   # 3.5 s blocked: they squeeze past
		in_front.call()
		_speed_now()
	in_front.call()
	var after_wait := _speed_now()
	player.position = L["at"] + Vector3(0, 0, 5)   # step aside
	_speed_now()
	in_front.call()
	var again := _speed_now()
	var pace: float = L["pace"]
	_log.append(["slows when you step in front", first < pace * 0.3, "%.2f of %.2f m/s" % [first, pace]])
	_log.append(["squeezes past after 3 s", after_wait > pace * 0.9, "%.2f m/s" % after_wait])
	_log.append(["slows again next time you step in front", again < pace * 0.3, "%.2f m/s" % again])
	var ok := true
	for r in _log:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
