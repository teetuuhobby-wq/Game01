extends "res://main.gd"
# Keyboard test (headless): presses the real keys and checks walking, running, zoom, turning, and that the fountain blocks you.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/key_test.tscn -- --no-record

func _ready() -> void:
	super()
	var start: Vector3 = player.position
	var checks := []
	Input.action_press("move_forward")
	for i in 45:
		await get_tree().process_frame
	Input.action_release("move_forward")
	var walked: float = Vector2(player.position.x - start.x, player.position.z - start.z).length()
	checks.append(["W walks you forward", walked > 1.0, "%.2f m" % walked])
	# Walk, then run, for the same time along the same open street (middle terrace, east)
	var street := Vector3(22.3, (world.LEVELS[1][1] + 0.5) * world.VS, 0.0)
	var dist := []
	for running in [false, true]:
		player.position = street
		camera.yaw = 0.0        # camera east of you: W walks west along the street, toward the stairs up
		for i in 3:
			await get_tree().process_frame
		if running:
			Input.action_press("run")
		Input.action_press("move_forward")
		for i in 15:
			await get_tree().process_frame
		Input.action_release("move_forward")
		Input.action_release("run")
		dist.append(Vector2(player.position.x - street.x, player.position.z - street.z).length())
	checks.append(["Shift runs you faster than walking", dist[1] > dist[0] * 1.5, "walk %.2f m, run %.2f m in the same time" % [dist[0], dist[1]]])
	var z0: float = camera.zoom_goal
	Input.action_press("zoom_out")
	for i in 20:
		await get_tree().process_frame
	Input.action_release("zoom_out")
	checks.append(["- zooms out", camera.zoom_goal > z0, "%.2f -> %.2f" % [z0, camera.zoom_goal]])
	var y0: float = camera.yaw
	Input.action_press("turn_left")
	for i in 20:
		await get_tree().process_frame
	Input.action_release("turn_left")
	checks.append(["Z turns the camera", absf(camera.yaw - y0) > 0.1, "%.2f rad" % (camera.yaw - y0)])
	# Walk into the fountain: you should be stopped by it, not pass through
	player.position = world.plaza_c + Vector3(3.2, world.VS * 0.5, 0)
	var dir_to_fountain: Vector3 = world.plaza_c - player.position
	var cam_fwd := -camera.global_transform.basis.z
	camera.yaw = atan2(-dir_to_fountain.z, -dir_to_fountain.x)   # camera behind you, facing the fountain
	await get_tree().process_frame
	Input.action_press("move_forward")
	for i in 90:
		await get_tree().process_frame
	Input.action_release("move_forward")
	var d_centre: float = Vector2(player.position.x - world.plaza_c.x, player.position.z - world.plaza_c.z).length()
	checks.append(["the fountain blocks you", d_centre > 2.6, "%.2f m from its centre (rim at 2.6 m)" % d_centre])
	var ok := true
	for c in checks:
		print("%s  %s  (%s)" % ["PASS" if c[1] else "FAIL", c[0], c[2]])
		ok = ok and c[1]
	get_tree().quit(0 if ok else 1)
