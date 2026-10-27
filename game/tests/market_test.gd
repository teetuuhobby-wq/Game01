extends "res://main.gd"
# Market test (headless): the market street is open to walk along its whole length,
# end to end, and it's busy (enough shops and people).
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/market_test.tscn -- --no-record

func _ready() -> void:
	super()
	var results := []
	var path: PackedVector3Array = world.market_path
	var len_m: float = (path.size() - 1) * 0.5
	var blocked := 0
	var s := 0.0
	while s <= len_m:
		for lane in [-3.0, 0.0, 3.0]:
			if world.floor_at(world._mk_point(s, lane)) != 0:
				blocked += 1
		s += 1.0
	results.append(["the market street is walkable everywhere people walk (3 lanes, every metre)", blocked == 0, "%d blocked spots on %.0f m" % [blocked, len_m]])
	var route: PackedVector3Array = world.find_path(path[0], path[path.size() - 1])
	results.append(["a route runs from one end of the street to the other", route.size() > 0, "%.0f m" % (route.size() * 0.2)])
	var people: int = world.market_people.size() + world.market_idlers.size()
	results.append(["it's busy: at least 150 people in the market", people >= 150, "%d people" % people])
	results.append(["at least 30 shops and stalls", world.shopkeepers.size() >= 30, "%d" % world.shopkeepers.size()])
	# After 10 s of walking, nobody has wandered off the street
	for i in 200:
		await get_tree().process_frame
	var off := 0
	for pp in world.market_people:
		if world.floor_at(pp["node"].position) != 0:
			off += 1
	results.append(["after 10 s, every walker is still on walkable street", off == 0, "%d off the street" % off])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
