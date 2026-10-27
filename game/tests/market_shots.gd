extends "res://main.gd"
# Market screenshots (needs a real GPU; run hidden):
#   tools/godot_offscreen.ps1 game --fixed-fps 30 res://tests/market_shots.tscn -- --no-record
# Saves views of the market street to shots/: first person, over the shoulder and the diorama.

func _ready() -> void:
	super()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var y: float = world.VS * 0.5
	# [name, where you stand (metres, on the city), camera yaw (you look the opposite way), zoom (-0.1 = first person)]
	var spots := [
		["market_fp_north_street", Vector3(12.0, y, 32.9), 0.0, -0.1],
		["market_fp_square_stalls", Vector3(0.0, y, 33.5), -PI / 2, -0.1],
		["market_fp_east_street", Vector3(40.7, y, 6.0), -PI / 2, -0.1],
		["market_shoulder_corner", Vector3(34.0, y, 31.0), PI * 0.15, 0.12],
		["market_above_street", Vector3(-8.0, y, 32.9), PI * 0.3, 0.45],
		["market_diorama", Vector3(0.0, y, 28.0), PI * 0.5, 1.0],
	]
	for sp in spots:
		player.position = sp[1]
		camera.yaw = sp[2]
		camera.snap_zoom(sp[3])
		await _settle()
		_save_shot(sp[0])
	get_tree().quit()
