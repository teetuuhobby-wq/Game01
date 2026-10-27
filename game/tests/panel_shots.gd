extends "res://main.gd"
# Panel and preset screenshots (needs a real GPU; run hidden):
#   tools/godot_offscreen.ps1 game --fixed-fps 30 res://tests/panel_shots.tscn -- --no-record
# Saves the sound board, the mood panel, and the market street under each mood preset to shots/.

func _ready() -> void:
	super()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var mood: Node = null
	var panels := {}
	for c in get_children():
		if c.get_script() == preload("res://mood.gd"):
			mood = c
	for p in get_tree().get_nodes_in_group("game_panels"):
		panels[p.toggle_action] = p
	player.position = Vector3(12.0, world.VS * 0.5, 32.9)   # on the market street
	camera.yaw = PI * 0.3
	camera.snap_zoom(0.3)
	panels["sound_board"].set_open(true)
	await _settle()
	_save_shot("panel_sound_board")
	panels["sound_board"].set_open(false)
	panels["mood"].set_open(true)
	await _settle()
	_save_shot("panel_mood")
	panels["mood"].set_open(false)
	for name in mood.PRESETS:
		mood.use_preset(name)
		await _settle()
		_save_shot("mood_" + name.to_lower().replace(" ", "_"))
	get_tree().quit()
