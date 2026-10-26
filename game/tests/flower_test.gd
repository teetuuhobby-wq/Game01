extends "res://main.gd"
# Flower test (headless): from where playtest 3 got stuck in the plaza's flower ring, try 36 directions; none may be blocked.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/flower_test.tscn -- --no-record

func _ready() -> void:
	process_priority = -200
	super()
	camera.snap_zoom(camera.FP_ZOOM)
	var start := Vector3(-1.30, (world.LEVELS[2][1] + 0.5) * world.VS, -5.53)
	var blocked := []
	for k in 36:
		player.position = start
		var a := deg_to_rad(k * 10.0)
		camera.yaw = a + PI   # look (and so walk) along angle a
		for i in 3:
			await get_tree().process_frame
		Input.action_press("move_forward")
		for i in 30:
			await get_tree().process_frame
		Input.action_release("move_forward")
		var moved := Vector2(player.position.x - start.x, player.position.z - start.z).length()
		if moved < 0.5:
			blocked.append(k * 10)
	print("%s  from where playtest 3 got stuck, every direction is walkable  (%d of 36 blocked %s)" % ["PASS" if blocked.is_empty() else "FAIL", blocked.size(), str(blocked)])
	get_tree().quit(0 if blocked.is_empty() else 1)
