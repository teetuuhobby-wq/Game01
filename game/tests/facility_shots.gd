extends "res://main.gd"
# Screenshots of the town's buildings and people (needs a real GPU; run hidden):
#   tools/godot_offscreen.ps1 game --fixed-fps 30 res://tests/facility_shots.tscn -- --no-record
# For each building: outside from across the street, the doorway in first person, the
# room from inside (first person and from higher up). Then each resident up close,
# and the whole cast in a line-up. Saved to shots/fac_*.png.

func _ready() -> void:
	super()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await _settle()
	for k in ["guild", "tavern", "store", "bath", "workshop"]:
		var f: Dictionary = world.facilities[k]
		var door_out: Vector3 = f["door_out"]
		var door_in: Vector3 = f["door_in"]
		var inward := (door_in - door_out)
		inward.y = 0.0
		inward = inward.normalized()
		# Outside, from across the way
		await _shot("fac_%s_outside" % k, door_out - inward * 2.6, inward, -0.1)
		await _shot("fac_%s_above" % k, door_out - inward * 1.0, inward, 0.7)
		# First person at the doorway, looking in
		await _shot("fac_%s_door_fp" % k, door_out + inward * 0.6, inward, -0.1)
		# Inside, first person from just inside the door, and from higher up
		await _shot("fac_%s_inside_fp" % k, door_in, inward, -0.1)
		await _shot("fac_%s_inside_high" % k, door_in, inward, 0.35)
	# Each resident, from 1.8 m away, in first person
	for id in world.cast_nodes:
		var n: Node3D = world.cast_nodes[id]
		var fwd := Vector3(cos(n.rotation.y), 0, -sin(n.rotation.y))
		var at: Vector3 = n.position + fwd * 1.8
		var spot: Dictionary = world.cast_spots.get(id, {})
		if spot.has("talk_from"):
			at = spot["talk_from"]
		if world.floor_at(at) < 0:
			at = n.position + fwd * 2.4
		var look: Vector3 = n.position - at
		look.y = 0.0
		await _shot("fac_person_%s" % id, at, look.normalized(), 0.3 if id == "wendel" else -0.1)
	# The cast in a row on the top terrace
	var Town := preload("res://town_data.gd")
	var row := Node3D.new()
	world.city.add_child(row)
	var base := Vector3(-13.0, 12.1, 6.0)   # on the top terrace, beside the bell tower
	var i := 0
	for id in Town.CAST:
		var c: Node3D = world._make_character(Town.CAST[id])
		c.position = base + Vector3(i * 1.1, 0, 0)
		c.rotation.y = -PI / 2   # facing +z, toward the camera
		var tag := Label3D.new()
		tag.text = Town.CAST[id]["name"]
		tag.font_size = 56
		tag.pixel_size = 0.005
		tag.outline_size = 8
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 2.3, 0)
		c.add_child(tag)
		row.add_child(c)
		i += 1
	await _shot("fac_cast_lineup", base + Vector3(3.9, 0, 4.4), Vector3(0, 0, -1), -0.1)
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3, zoom: float) -> void:
	player.position = at
	player.face(look)
	camera.yaw = atan2(-look.z, -look.x)
	camera.snap_zoom(zoom)
	await _settle()
	_save_shot(label)
