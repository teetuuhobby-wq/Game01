extends "res://main.gd"
# Screenshots of the town over a day (needs a real GPU; run hidden):
#   tools/godot_offscreen.ps1 game --fixed-fps 30 res://tests/day_shots.tscn -- --no-record
# At 7:07 (the city standing up), 9:00, 12:00, 16:00, 18:20 (lamps lit, slowing) and
# 18:58 (knelt), four views each: the tavern's door and the guild's door with their
# OPEN / CLOSED plaques (they face each other across the street at the foot of the
# stairs to the plaza), the market street over your shoulder, and the city's side from
# outside the deck (how high it stands over the sand). The clock stays stopped at each
# time. Saved to shots/day_<time>_<view>.png.

const HOURS := [7.12, 9.0, 12.0, 16.0, 18.33, 18.97]


func _ready() -> void:
	super()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	day_view.day.frozen = true
	var y: float = world.VS * 0.5
	# [view, where you stand (metres, on the city), camera yaw (you look the opposite way), zoom]
	# [view, where you stand (metres, on the city), camera yaw (you look the opposite way), zoom, tilt]
	var views := [
		["tavern", Vector3(0.0, y, -28.9), PI, 0.12, 0.0],
		["guild", Vector3(1.0, y, -27.3), 0.0, 0.12, 0.0],
		["market", Vector3(12.0, y, 32.9), PI * 0.12, 0.14, 0.0],
		["city", Vector3(-6.0, y, -38.0), -PI * 0.42, 0.7, -0.2],
	]
	for h in HOURS:
		day_view.jump_to(h)
		for v in views:
			player.position = v[1]
			camera.yaw = v[2]
			camera.snap_zoom(v[3])
			camera._pitch_offset = v[4]
			await _settle()
			_save_named("day_%02d%02d_%s" % [floori(h), roundi(fposmod(h, 1.0) * 60.0), v[0]])
	get_tree().quit()


func _save_named(label: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % label)
	print("shot: ", label)
