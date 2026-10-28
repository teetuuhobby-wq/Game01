extends "res://main.gd"
# Frame rate at a few busy spots, with the frame cap off (needs a real GPU; run hidden):
#   tools/godot_offscreen.ps1 game res://tests/fps_check.tscn -- --no-record
# Prints the average frames per second over 4 s at each spot, in first person and from
# behind you. Not pass/fail: compare the numbers before and after a change.

func _ready() -> void:
	super()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var spots := {
		"start (plaza)": [world.you_spot, Vector3(1, 0, 0)],
		"market street": [Vector3(12.0, world.VS * 0.5, 32.9), Vector3(-1, 0, 0)],
		"guild row": [Vector3(0.4, world.VS * 0.5, -36.0), Vector3(0, 0, 1)],
	}
	if world.get("facilities") != null and not world.facilities.is_empty():
		spots["inside the tavern"] = [world.facilities["tavern"]["inside"], Vector3(1, 0, 0)]
		spots["inside the bathhouse"] = [world.facilities["bath"]["inside"], Vector3(0, 0, -1)]
	for n in spots:
		for zoom in [-0.1, 0.35]:
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
			print("FPS  %-22s %-14s %4.0f" % [n, "first person" if zoom < 0 else "behind you", fps])
	get_tree().quit()
