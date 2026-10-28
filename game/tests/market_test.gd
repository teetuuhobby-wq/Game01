extends "res://main.gd"
# Market test (headless): the market street is open to walk along its whole length,
# end to end, it's busy (enough shops and people), and its people don't jump when the
# city's walk loops round.
# The crowd follows the time of day now (thin in the morning, gone at night: day_test.gd
# checks that), so this starts at 14:00, when the whole crowd is out, with the clock stopped.
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/market_test.tscn -- --no-record --hour 14 --freeze-clock

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
	var people := 0
	for pp in world.market_people + world.market_idlers:
		if pp["here"]:
			people += 1   # out at this time of day (all of them at 14:00)
	results.append(["it's busy at 14:00: at least 150 people out in the market", people >= 150, "%d people" % people])
	var covered := 0
	var unwalkable := 0
	for c in world.stair_top:
		if world._mk_taken.has(c):
			covered += 1
		if world.floor_at(Vector3(c.x, 0, c.y) * world.VS) < 0:
			unwalkable += 1
	results.append(["no shop stands on the stairs, and every stair step can be walked on (session 03 bug)",
			covered == 0 and unwalkable == 0, "%d under shops, %d blocked" % [covered, unwalkable]])
	results.append(["at least 30 shops and stalls", world.shopkeepers.size() >= 30, "%d" % world.shopkeepers.size()])
	# After 10 s of walking, nobody has wandered off the street
	for i in 200:
		await get_tree().process_frame
	var off := 0
	for pp in world.market_people:
		if world.floor_at(pp["node"].position) != 0:
			off += 1
	results.append(["after 10 s, every walker is still on walkable street", off == 0, "%d off the street" % off])
	# The city's clock jumps back about 54 s each time its walk loops round. The people's
	# fidgeting mustn't jump with it (shopkeepers and groups used to snap round).
	world.t = 230.0 / world.CITY_SPEED - 0.12   # a few frames before the loop
	await get_tree().process_frame
	var t0: float = world.t
	var biggest := 0.0
	for i in 6:
		var yaws := []
		for idl in world.market_idlers:
			yaws.append(idl["node"].rotation.y)
		await get_tree().process_frame
		for k in yaws.size():
			biggest = maxf(biggest, absf(angle_difference(yaws[k], world.market_idlers[k]["node"].rotation.y)))
	results.append(["when the city's walk loops round, the market's standing people don't snap round",
			world.t < t0 and biggest < 0.05, "biggest turn in one frame %.0f°" % rad_to_deg(biggest)])
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
