extends "res://main.gd"
# Quality switch (headless): low quality turns the costly things off, F6 switches, and
# switching back to high restores every setting exactly, including the look you set
# with the mood panel (F5). In low, the haze never drops below low's floor (even when
# you turn it down with F5), and people of every kind far from the camera are hidden
# (never you).
# (Starts at 14:00 with the clock stopped: the whole market crowd is out then, so "everyone
# far away shows again" in high means everyone. At other hours some are home.)
# Run: <godot_console.exe> --headless --path game res://tests/quality_test.tscn -- --no-record --hour 14 --freeze-clock

const TQ := preload("res://tuning.gd")

var q: Node            # quality.gd
var mood_panel: Node   # mood_panel.gd (F5)


func _ready() -> void:
	super()
	for c in get_children():
		if c.get_script() == preload("res://quality.gd"):
			q = c
	for p in get_tree().get_nodes_in_group("game_panels"):
		if p.toggle_action == "mood":
			mood_panel = p
	var results := []
	results.append(["it starts in high quality, with the mood panel there", q != null and q.level == "high"
			and mood_panel != null, ""])
	if q == null or mood_panel == null:
		_finish(results)
		return

	# Your own look first: some haze and miniature blur set with the mood panel (F5)
	mood_panel._change(0.0025, "haze")
	mood_panel._change(0.2, "miniature")
	var high := _settings()
	_press_f6()
	await _frames(3)
	var vp := get_viewport()
	results.append(["F6 switches to low: lower resolution (FSR), no SSAO, glow, blur or edge smoothing",
			q.level == "low" and is_equal_approx(vp.scaling_3d_scale, TQ.LOW_RENDER_SCALE)
			and vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR and vp.msaa_3d == Viewport.MSAA_DISABLED
			and not world.env.ssao_enabled and not world.env.glow_enabled and camera.attributes == null,
			"scale %.2f" % vp.scaling_3d_scale])
	results.append(["low: shorter view and shadows, hard 2-split shadows, more haze, people hidden past 45 m",
			camera.far == TQ.LOW_VIEW_DISTANCE and world.sun.directional_shadow_max_distance == TQ.LOW_SHADOW_DISTANCE
			and world.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			and world.env.fog_density >= TQ.LOW_HAZE - 0.00001 and world.people_view == TQ.LOW_PEOPLE_VIEW,
			"view %.0f m, haze %.4f" % [camera.far, world.env.fog_density]])
	_press_f6()
	await _frames(3)
	results.append(["F6 back to high restores every setting, and your mood haze and blur",
			q.level == "high" and _changed(high).is_empty(), "changed: %s" % ", ".join(_changed(high))])

	# Changing the mood (F5) while in low
	_press_f6()
	await _frames(3)
	mood_panel._change(0.001, "haze")
	results.append(["in low, turning the mood haze below low's floor still leaves at least the floor",
			world.env.fog_density >= TQ.LOW_HAZE - 0.00001, "haze %.4f" % world.env.fog_density])
	mood_panel._change(0.002, "haze")
	mood_panel._change(0.25, "miniature")
	_press_f6()
	await _frames(3)
	var blur: float = camera.attributes.dof_blur_amount if camera.attributes is CameraAttributesPractical else -1.0
	results.append(["haze and blur changed in low show after switching back to high",
			is_equal_approx(world.env.fog_density, 0.002) and is_equal_approx(blur, 0.25),
			"haze %.4f, blur %.3f" % [world.env.fog_density, blur]])

	# People: zoomed right out (the whole-town view), most people are far from the camera
	_press_f6()
	camera.snap_zoom(1.0)
	await get_tree().create_timer(3.0).timeout
	var low_far := _far_people()
	var shown := []
	var none_far := []
	for kind in low_far:
		if low_far[kind][0] == 0:
			none_far.append(kind)
		if low_far[kind][1] > 0:
			shown.append("%s %d of %d" % [kind, low_far[kind][1], low_far[kind][0]])
	results.append(["in low, people of every kind further than 45 m from the camera are hidden (but not you)",
			none_far.is_empty() and shown.is_empty() and player.visible and player.body.visible,
			"still shown: %s; nobody far: %s" % [", ".join(shown), ", ".join(none_far)]])
	_press_f6()
	await _frames(3)
	var high_far := _far_people()
	var hidden := 0
	for kind in high_far:
		hidden += high_far[kind][0] - high_far[kind][1]
	results.append(["back in high, everyone far away shows again", hidden == 0, "%d hidden" % hidden])
	_finish(results)


## Presses F6 (headless runs don't pass key presses on, so this calls the handler directly).
func _press_f6() -> void:
	var ev := InputEventAction.new()
	ev.action = "quality"
	ev.pressed = true
	q._unhandled_input(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Every setting quality.gd touches (and the mood's haze and blur that it must not undo).
func _settings() -> Dictionary:
	var vp := get_viewport()
	var attrs := camera.attributes
	return {"scale": vp.scaling_3d_scale, "scaling mode": vp.scaling_3d_mode, "msaa": vp.msaa_3d,
			"ssao": world.env.ssao_enabled, "glow": world.env.glow_enabled, "haze": world.env.fog_density,
			"view distance": camera.far, "shadow distance": world.sun.directional_shadow_max_distance,
			"shadow splits": world.sun.directional_shadow_mode, "camera attributes": attrs,
			"blur": attrs.dof_blur_amount if attrs is CameraAttributesPractical else -1.0,
			"people view": world.people_view}


## The names of the settings that differ from `before`.
func _changed(before: Dictionary) -> Array:
	var now := _settings()
	var out := []
	for k in before:
		if now[k] != before[k]:
			out.append(k)
	return out


## For each kind of townsperson: [how many are more than 47 m from the camera, how many of those show].
func _far_people() -> Dictionary:
	var cam: Vector3 = world.city.to_local(camera.global_position)
	var kinds := {"plaza walkers": world.walkers, "terrace walkers": world.promenaders,
			"market walkers": world.market_people, "market standers": world.market_idlers}
	var out := {}
	for kind in kinds:
		var far := 0
		var seen := 0
		for p in kinds[kind]:
			var node: Node3D = p["node"]
			if node.position.distance_to(cam) > TQ.LOW_PEOPLE_VIEW + 2.0:
				far += 1
				if node.visible:
					seen += 1
		out[kind] = [far, seen]
	return out


func _finish(results: Array) -> void:
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
