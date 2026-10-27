extends "res://main.gd"
# Quality switch (headless): low quality turns the costly things off, F6 switches, and
# switching back to high restores everything exactly.
# Run: <godot_console.exe> --headless --path game res://tests/quality_test.tscn -- --no-record

func _ready() -> void:
	super()
	var q: Node = null
	for c in get_children():
		if c.get_script() == preload("res://quality.gd"):
			q = c
	var results := []
	results.append(["it starts in high quality", q != null and q.level == "high", ""])
	var high_scale: float = get_viewport().scaling_3d_scale
	var high_ssao: bool = world.env.ssao_enabled
	var ev := InputEventAction.new()
	ev.action = "quality"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 3:
		await get_tree().process_frame
	results.append(["F6 switches to low: lower resolution, no SSAO or blur, people hidden past 45 m",
			q.level == "low" and get_viewport().scaling_3d_scale < 0.8 and not world.env.ssao_enabled
			and camera.attributes == null and world.people_view < 50.0, "scale %.2f" % get_viewport().scaling_3d_scale])
	q.set_level("high")
	results.append(["switching back to high restores everything", get_viewport().scaling_3d_scale == high_scale
			and world.env.ssao_enabled == high_ssao and camera.attributes != null and world.people_view == INF, ""])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
