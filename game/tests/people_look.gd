extends "res://main.gd"
# THE CHARACTER LOOK TEST (playtest 4): Dorran, Tamsin and Pip three ways, in the real
# town at 14:00:  A today's (20 cm blocks), B double detail (10 cm, today's proportions),
# C double detail, cuter (a bigger head, a shorter body). Needs a real GPU; run hidden:
#   tools/godot_offscreen.ps1 game --fixed-fps 30 res://tests/people_look.tscn '--' --no-record --hour 14 --freeze-clock
# Shots (shots/NN_look_*.png), each taken three times from exactly the same camera:
#   bar_X     across the tavern's bar, through your eyes (where playtest 4's flag came from)
#   face_<who>_X  each face up close, from talking distance
#   body_X    the three full length, 3 m away
#   street_X  among the market crowd, through your eyes (do they fit the 20 cm town?)
#   diorama_X each version from above, among the crowd
# --fps instead: no shots; the whole crowd at A, B and C, and the frames per second.

const Kit := preload("res://tests/people_hd_kit.gd")
const Town := preload("res://town_data.gd")
const IDS := ["dorran", "tamsin", "pip"]
const STYLES := ["A", "B", "C"]

var _kit: Kit
var _cam: Camera3D


func _ready() -> void:
	super()
	_kit = Kit.new(world)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 1500.0
	world.city.add_child(_cam)   # it rides along on the walking city, like everyone on it
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir()))   # (not --shots: the game's own start-up shots would move the camera)
	if "--fps" in OS.get_cmdline_user_args():
		await _fps()
	else:
		await _shots_run()
	get_tree().quit()


func _version(id: String, style: String) -> Node3D:
	return world._make_character(Town.CAST[id]) if style == "A" else _kit.build(Town.CAST[id], style)


func _shot(label: String) -> void:
	await _settle()
	_save_shot("look_" + label)


## Like _shot, but the market crowd keeps out of the way near `spot` (on the city): the
## people right in front of the lens would otherwise block the view.
func _shot_clear(label: String, spot: Vector3) -> void:
	for i in 40:
		for e in world.market_people + world.market_idlers:
			e["here"] = e["node"].position.distance_to(spot) > 3.5
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot("look_" + label)


## A point on the market street: s metres along it, `side` metres across (+ = left of travel).
func _street(s: float, side: float) -> Vector3:
	var path: PackedVector3Array = world.market_path
	var i := clampi(int(s * 2.0), 2, path.size() - 3)
	var d := (path[i + 2] - path[i - 2]).normalized()
	return path[i] + Vector3(-d.z, 0, d.x) * side


func _street_dir(s: float) -> Vector3:
	var path: PackedVector3Array = world.market_path
	var i := clampi(int(s * 2.0), 2, path.size() - 3)
	return (path[i + 2] - path[i - 2]).normalized()


## Points the staged camera (on the city) from `from` at `at`.
func _look(from: Vector3, at: Vector3) -> void:
	_cam.make_current()
	_cam.position = from
	_cam.look_at(world.city.to_global(at), world.city.global_transform.basis.y)


func _place(n: Node3D, at: Vector3, face: Vector3) -> void:
	if n.get_parent() == null:
		world.city.add_child(n)
	n.position = at
	n.rotation.y = atan2(-face.z, face.x)


func _shots_run() -> void:
	for i in 60:
		await get_tree().process_frame
	# 1. Across the bar, through your eyes: Dorran himself, dressed three ways
	var dorran: Node3D = world.cast_nodes["dorran"]
	var own := dorran.get_children()
	var stand: Vector3 = world.cast_spots["dorran"]["talk_from"]
	player.position = stand
	player.face(dorran.position - stand)
	camera.snap_zoom(camera.FP_ZOOM)
	camera.yaw = atan2(-(stand - dorran.position).z, -(stand - dorran.position).x) + PI
	camera._pitch_offset = deg_to_rad(-10.0)
	camera.make_current()
	for style in STYLES:
		var extra: Node3D = null
		for c in own:
			c.visible = style == "A"
		if style != "A":
			extra = _kit.build(Town.CAST["dorran"], style)
			dorran.add_child(extra)
		await _shot("bar_" + style)
		if extra != null:
			extra.queue_free()
	for c in own:
		c.visible = true
	# The line-ups: no on-screen text, no speech bubble, and the market crowd steps away
	# (the crowd comes back for the street shots, the text for nothing: only the bar shot keeps it)
	for l in find_children("*", "CanvasLayer", true, false):
		l.visible = false
	errand._bubble_until = 0.0
	world._crowd.clear()
	for e in world.market_people + world.market_idlers:
		e["here"] = false
	var s0 := 30.0
	var across := Vector3(-_street_dir(s0).z, 0, _street_dir(s0).x)
	var along := _street_dir(s0)
	var line := {}
	for style in STYLES:
		var row := []
		for k in IDS.size():
			var n := _version(IDS[k], style)
			_place(n, _street(s0, 1.2) + along * (k - 1) * 1.1, -across)   # a straight line, 1.1 m apart
			row.append(n)
		line[style] = row
		for st in line:
			for n in line[st]:
				n.visible = st == style
		var mid := _street(s0, 1.2)
		# 2. Each face up close, from talking distance (1.3 m), at their eye height
		for k in IDS.size():
			var n: Node3D = row[k]
			var eye := (1.55 if style != "C" else 1.5) * n.scale.y
			_look(n.position - across * 1.8 + Vector3(0, eye, 0), n.position + Vector3(0, eye - 0.12, 0))
			_cam.fov = 40.0
			await _shot("face_%s_%s" % [IDS[k], style])
		# 3. Full length, 3 m away
		_look(mid - across * 3.6 + Vector3(0, 1.2, 0), mid + Vector3(0, 0.85, 0))
		_cam.fov = 50.0
		await _shot("body_" + style)
	# 4. Among the crowd, through your eyes (how the user plays): the three walking toward you
	for e in world.market_people + world.market_idlers:
		e["here"] = true
	var ps := 50.0
	var fwd := _street_dir(ps)
	var you := _street(ps, -0.6)
	for style in STYLES:
		var trio := []
		for k in IDS.size():
			var n := _version(IDS[k], style)
			_place(n, you + fwd * (2.6 + k * 1.0) + Vector3(-fwd.z, 0, fwd.x) * (0.9 - k * 0.9), -fwd)
			trio.append(n)
		_look(you + Vector3(0, 1.6, 0), you + fwd * 4.0 + Vector3(0, 1.2, 0))
		_cam.fov = 70.0
		await _shot_clear("street_" + style, you)
		for n in trio:
			n.queue_free()
	# 5. From above (the town's diorama view), each version among the crowd
	camera.make_current()
	player.position = _street(s0, -0.4)
	camera.snap_zoom(0.3)
	camera.yaw = atan2(-across.z, -across.x)   # from behind you, across the street to them
	for style in STYLES:
		for st in line:
			for n in line[st]:
				n.visible = st == style
		await _shot_clear("diorama_" + style, _street(s0, 1.2))


## Everyone in town at A, B and C: frames per second at busy spots, frame cap off.
func _fps() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Every person's mesh, so each version can be swapped in for all of them
	var people := []   # [MeshInstance3D, its today's mesh]
	for e in world.market_people + world.market_idlers + world.walkers + world.promenaders + world._extra_nodes:
		var mi := e["node"].get_child(0) as MeshInstance3D
		if mi != null:
			people.append([mi, mi.mesh])
	# Random looks for the crowd in B and C (the same variety as today's)
	var hd := {"B": [], "C": []}
	for i in 32:
		var p: MeshInstance3D = world._random_person()
		var c := {"shirt": p.get_meta("shirt"), "bottom": p.get_meta("bottom"), "hair": p.get_meta("hair"),
				"skin": p.get_meta("skin"), "look": p.get_meta("look", {})}
		p.free()
		for st in ["B", "C"]:
			var n := _kit.build(c, st)
			var m := (n.get_child(0) as MeshInstance3D).mesh
			n.free()
			hd[st].append(m)
	var spots := {
		"market street": [_street(50.0, -0.6), _street_dir(50.0)],
		"plaza": [world.you_spot, Vector3(1, 0, 0)],
	}
	camera.make_current()
	for style in STYLES:
		var faces := 0
		for k in people.size():
			var mi: MeshInstance3D = people[k][0]
			mi.mesh = people[k][1] if style == "A" else hd[style][k % 32]
			faces += mi.mesh.surface_get_array_len(0) / 4 if mi.mesh.get_surface_count() > 0 else 0
		for n in spots:
			for zoom in [-0.1, 0.35, 0.7]:
				player.position = spots[n][0]
				var look: Vector3 = spots[n][1]
				player.face(look)
				camera.yaw = atan2(-look.z, -look.x)
				camera.snap_zoom(zoom)
				for i in 60:
					await get_tree().process_frame
				var frames := 0
				var t0 := Time.get_ticks_usec()
				while Time.get_ticks_usec() - t0 < 4000000:
					await get_tree().process_frame
					frames += 1
				var fps := frames / ((Time.get_ticks_usec() - t0) / 1000000.0)
				var view := "first person" if zoom < 0 else ("behind you" if zoom < 0.5 else "zoomed out")
				print("FPS  %s  %-14s %-13s %4.0f   (%d people, %d block faces)" % [style, n, view, fps, people.size(), faces])
