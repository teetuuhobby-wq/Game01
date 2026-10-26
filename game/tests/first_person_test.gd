extends "res://main.gd"
# First-person test (headless): scroll in, camera at your eyes, W walks where you look, camera never inside a block, scroll out.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/first_person_test.tscn -- --no-record

func _ready() -> void:
	process_priority = -200   # press keys before the controls read them
	super()
	var results := []
	camera.snap_zoom(0.0)
	await _frames(10)
	_wheel(-1)   # one notch in
	await _frames(40)
	var eye: Vector3 = player.global_position + Vector3(0, 1.55, 0)
	var d := camera.global_position.distance_to(eye)
	results.append(["one notch in from the closest view = first person", camera.first_person > 0.95 and d < 0.15,
			"first_person %.2f, camera %.2f m from your eyes" % [camera.first_person, d]])
	results.append(["your body is hidden in first person", not player.body.visible, ""])
	# On an open street (middle terrace, east), look a little left with the mouse, then
	# walk forward: you should go where you look
	player.position = Vector3(23.0, (world.LEVELS[1][1] + 0.5) * world.VS, 0.0)
	camera.yaw = PI
	await _frames(20)
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(-30, 0)
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
	controls._input(ev)
	await _frames(5)
	var look := -camera.global_transform.basis.z
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _frames(25)
	Input.action_release("move_forward")
	var moved: Vector3 = player.global_position - start
	var along := Vector2(moved.x, moved.z).normalized().dot(Vector2(look.x, look.z).normalized())
	results.append(["W walks where you look", along > 0.95, "direction match %.2f" % along])
	# Wander: walk and turn for 25 s; the camera must never be inside a block
	var inside := 0
	var frames := 0
	var t := 0.0
	Input.action_press("move_forward")
	while t < 25.0:
		var m := InputEventMouseMotion.new()
		m.relative = Vector2(7.0 * sin(t * 0.7), 2.0 * sin(t * 1.3))
		m.button_mask = MOUSE_BUTTON_MASK_RIGHT
		controls._input(m)
		await get_tree().process_frame
		t += get_process_delta_time()
		frames += 1
		var c: Vector3 = world.city.to_local(camera.global_position)
		if world.gv(roundi(c.x / world.VS), roundi(c.y / world.VS), roundi(c.z / world.VS)) != 0:
			inside += 1
	Input.action_release("move_forward")
	results.append(["walking around in first person, the camera is never inside a block", inside == 0, "%d of %d frames inside" % [inside, frames]])
	_wheel(1)   # one notch out
	await _frames(40)
	results.append(["one notch out = back over your shoulder", camera.first_person < 0.05 and player.body.visible, "first_person %.2f" % camera.first_person])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wheel(dir: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if dir > 0 else MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	controls._input(ev)
