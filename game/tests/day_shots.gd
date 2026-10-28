extends "res://main.gd"
# Screenshots of the town over a day (needs a real GPU; run hidden):
#   tools/godot_offscreen.ps1 game --fixed-fps 30 res://tests/day_shots.tscn -- --no-record
# At 7:07 (the city standing up), 9:00, 12:00, 16:00, 18:20 (lamps lit, slowing) and
# 18:58 (knelt), four views each: the tavern's door and the guild's door with their
# OPEN / CLOSED plaques (first person, from across the street they share at the foot of
# the stairs to the plaza), the market street over your shoulder, and the city from out
# on the sand (how high it stands). The clock stays stopped at each time.
# Saved to shots/day_<time>_<view>.png.

const HOURS := [7.12, 9.0, 12.0, 16.0, 18.33, 18.97]

var _sand_cam: Camera3D   # out on the desert, for the city's side view


func _ready() -> void:
	super()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	day_view.day.frozen = true
	_sand_cam = Camera3D.new()
	_sand_cam.fov = 50.0
	_sand_cam.far = 2000.0
	add_child(_sand_cam)
	var y: float = world.VS * 0.5
	var tavern: Dictionary = world.facilities["tavern"]
	var guild: Dictionary = world.facilities["guild"]
	for h in HOURS:
		day_view.jump_to(h)
		var stamp := "day_%02d%02d_" % [floori(h), roundi(fposmod(h, 1.0) * 60.0)]
		await _door_shot(stamp + "tavern", tavern)
		await _door_shot(stamp + "guild", guild)
		player.position = Vector3(12.0, y, 32.9)
		camera.yaw = PI * 0.12
		camera.snap_zoom(0.14)
		await _settle()
		_save_named(stamp + "market")
		await _city_shot(stamp + "city")
	get_tree().quit()


## First person, from across the street, looking at a place's door and its plaque.
func _door_shot(label: String, f: Dictionary) -> void:
	var inward: Vector3 = f["door_in"] - f["door_out"]
	inward.y = 0.0
	inward = inward.normalized()
	player.position = f["door_out"] - inward * 2.4
	camera.yaw = atan2(-inward.z, -inward.x)
	camera.snap_zoom(-0.1)
	await _settle()
	_save_named(label)


## The city's side from out on the sand, about 110 m away and 12 m up.
func _city_shot(label: String) -> void:
	var c: Vector3 = world.city.global_position
	var at := c + Vector3(cos(-1.25), 0, sin(-1.25)) * 110.0
	at.y = world.ground_at(at.x, at.z) + 12.0
	_sand_cam.global_position = at
	_sand_cam.look_at(c + Vector3(0, -6, 0), Vector3.UP)
	_sand_cam.make_current()
	await _settle()
	_save_named(label)
	camera.make_current()


func _save_named(label: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % label)
	print("shot: ", label)
