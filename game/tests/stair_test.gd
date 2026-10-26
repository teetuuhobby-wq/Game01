extends "res://main.gd"
# Stairs test (headless): walks and runs up and down the east stairs and checks you arrive (run it at a low frame rate too).
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/stair_test.tscn -- --no-record

func _ready() -> void:
	super()
	var top: int = world.LEVELS[2][1]
	var mid: int = world.LEVELS[1][1]
	var results := []
	for run in [false, true]:
		# Up: start on the middle terrace at the foot of the east stairs, facing west (up the stairs)
		player.position = Vector3(21.4, (mid + 0.5) * world.VS, -0.1)
		camera.yaw = 0.0   # camera east of you, so "forward" is west
		await _press(run, 2.0 if run else 4.0)
		var f: int = world.floor_at(player.position)
		results.append(["%s up the stairs" % ("Run" if run else "Walk"), f == top, "ended at floor %d (top is %d), x=%.1f m" % [f, top, player.position.x]])
		# Down: from the top, walk east down the same stairs
		player.position = Vector3(13.0, (top + 0.5) * world.VS, -0.1)
		camera.yaw = PI   # camera west of you, so "forward" is east
		await _press(run, 2.0 if run else 4.0)
		f = world.floor_at(player.position)
		results.append(["%s down the stairs" % ("Run" if run else "Walk"), f == mid, "ended at floor %d (middle is %d), x=%.1f m" % [f, mid, player.position.x]])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)


func _press(run: bool, seconds: float) -> void:
	for i in 3:
		await get_tree().process_frame
	if run:
		Input.action_press("run")
	Input.action_press("move_forward")
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		await get_tree().process_frame
	Input.action_release("move_forward")
	Input.action_release("run")
