extends "res://main.gd"
# The day (headless):
#   - the clock runs at the tuned rate, shows "Day 1 · 9:00", and T (through the controls,
#     so it's recorded) jumps an hour; recordings without the T column still replay
#   - the light at each hour is the blend of the day's looks; touching the mood panel (F5)
#     pins it, "Follow the day" hands it back, and low quality's least haze still holds
#   - places open and close on time (the OPEN / CLOSED plaques, the regulars, more when
#     busy), and their people say when they open
#   - the market's crowd follows the hour
#   - every resident walks to each place in their routine in good time, on walkable
#     ground all the way (never through a wall), and nobody gets stuck
#   - the end of the day: the evening bell, the city slows to a stop and kneels, "Day 1
#     done", the morning bell, Day 2 at 7:00, the city stands up and walks on; through it
#     all you stay on the deck (never in a block, never falling), the keys still walk you,
#     and first person works
#   - nobody appears or vanishes within 15 m of the camera while it can see them
# The game runs 4x faster for the long stretches (Engine.time_scale).
# Run all tests with tools/run_tests.ps1, or one: <godot_console.exe> --headless --fixed-fps 20 --path game res://tests/day_test.tscn -- --no-record

const Day := preload("res://day.gd")
const Town := preload("res://town_data.gd")
const TQ := preload("res://tuning.gd")

const SPEED := 4.0      # how much faster the game runs for the long stretches
const IN_VIEW := 15.0   # metres: nobody may come or go this close to the camera while it can see them

var results := []
var mood: Node
var panel: Node
var quality: Node
var _interact: Node
var _events := []       # [what, hour, day] from the clock
# Watching for people popping in or out (see _watch_pops)
var _flags := []
var _planes := []
var _cam_local := Vector3.ZERO
var _city_xf := Transform3D.IDENTITY
var _dark := 1.0
var _pops := 0
var _pops_bad := []


func _ready() -> void:
	super()
	process_priority = -200
	for c in get_children():
		if c.get_script() == preload("res://mood.gd"):
			mood = c
		elif c.get_script() == preload("res://quality.gd"):
			quality = c
		elif c.get_script() == preload("res://interact.gd"):
			_interact = c
	for p in get_tree().get_nodes_in_group("game_panels"):
		if p.toggle_action == "mood":
			panel = p
	day_view.happened.connect(func(e: String) -> void: _events.append([e, day_view.day.hour, day_view.day.day]))
	_run()


func _run() -> void:
	await _frames(2)
	await _check_clock()
	_check_light()
	_check_pin_and_follow()
	_check_places()
	_check_market()
	await _check_routines()
	await _check_end_of_day()
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _add(what: String, ok: bool, details := "") -> void:
	results.append([what, ok, details])


# ---------------------------------------------------------------- the clock and T

func _check_clock() -> void:
	day_view.jump_to(9.0)
	_add("the clock shows the day and the time", day_view._clock.text == "Day 1  ·  9:00"
			and Day.clock_text(13.55) == "13:30" and Day.clock_text(7.0) == "7:00" and Day.clock_text(18.999) == "18:50",
			day_view._clock.text)
	day_view.day.frozen = false
	var h0: float = day_view.day.hour
	await _frames(200)
	var ran: float = day_view.day.hour - h0
	var want := 200 * (1.0 / 20.0) * Day.hours_per_second()
	_add("the clock runs at the tuned rate (%.0f real minutes for 7:00 to 19:00)" % TQ.DAY_MINUTES,
			absf(ran - want) < 0.0006, "%.4f h in 10 s, want %.4f" % [ran, want])
	day_view.day.frozen = true
	h0 = day_view.day.hour
	Input.action_press("skip_hour")
	await _frames(1)
	Input.action_release("skip_hour")
	await _frames(2)
	_add("T (read by the controls, so it's recorded) jumps an hour ahead", absf(day_view.day.hour - h0 - 1.0) < 0.0001,
			"%.3f -> %.3f" % [h0, day_view.day.hour])
	var cols: PackedStringArray = controls.HEADER.split(",")
	var new_row: PackedStringArray = controls.to_row(1, 0.05).split(",")
	var t_row := "5,0.05,0,0,0,0,0,0,0,0,0,0,1".split(",")
	var old_row := "5,0.05,0,0,0,0,0,0,0,0,0,0".split(",")
	controls.from_row(t_row)
	var t_read: bool = controls.skip_hour
	controls.from_row(old_row)
	_add("T is a column of inputs.csv, and recordings from before it still replay (no T)",
			cols[cols.size() - 1] == "skip_hour" and new_row.size() == cols.size() and t_read and not controls.skip_hour, "")
	controls.skip_hour = false


# ---------------------------------------------------------------- the light

func _check_light() -> void:
	var golden: Dictionary = mood.saved if not mood.saved.is_empty() else mood.PRESETS["Golden hour"]
	var keys := [[7.0, mood.PRESETS["Dawn"]], [8.5, mood.PRESETS["Soft morning"]], [12.0, mood.PRESETS["Midday"]],
			[16.0, golden], [18.5, mood.PRESETS["Dusk"]]]
	var bad := []
	for k in keys:
		day_view.jump_to(k[0])
		if mood.values != k[1]:
			bad.append(k[0])
	_add("at 7:00, 8:30, 12:00, 16:00 and 18:30 the light is exactly that hour's look (golden hour = your saved look, if any)",
			bad.is_empty(), str(bad))
	day_view.jump_to(14.0)
	var mid: Dictionary = mood.PRESETS["Midday"]
	var f := smoothstep(12.0, 16.0, 14.0)
	var off := 0.0
	for key in mid:
		off = maxf(off, absf(mood.values[key] - lerpf(mid[key], golden[key], f)))
	_add("at 14:00 it's half way between midday and golden hour, and it's on the world", off < 0.0001
			and is_equal_approx(world.sun.light_energy, mood.values["sun_brightness"]),
			"sun height %.1f (midday %.0f, golden %.0f)" % [mood.values["sun_height"], mid["sun_height"], golden["sun_height"]])
	day_view.jump_to(18.999)
	var night: Dictionary = mood.PRESETS["Nightfall"]
	_add("at 19:00 night falls (the Nightfall look)", absf(mood.values["sun_brightness"] - night["sun_brightness"]) < 0.01
			and absf(mood.values["sky_brightness"] - night["sky_brightness"]) < 0.01, "sky %.2f" % mood.values["sky_brightness"])
	day_view.jump_to(12.0)
	var day_glow: float = world.mat_glow.emission_energy_multiplier
	day_view.jump_to(18.6)
	var eve_glow: float = world.mat_glow.emission_energy_multiplier
	# The lamps outside the doors turn up; the lights inside stay as they are (they reach
	# through the walls, so turning them up would light the street too).
	var door_lamps := 0
	var lamps_wrong := 0
	for l in world._lamps:
		door_lamps += 1 if l[2] else 0
		var want: float = l[1] * (TQ.EVENING_LAMPS if l[2] else 1.0)
		lamps_wrong += 0 if is_equal_approx(l[0].light_energy, want) else 1
	_add("lanterns, lit windows and door lamps glow brighter in the evening, lights inside don't (no new lights)",
			eve_glow > day_glow * 2.0 and TQ.EVENING_LAMPS > 1.2 and door_lamps >= 4 and lamps_wrong == 0,
			"glow %.1f -> %.1f, %d door lamps of %d, %d wrong" % [day_glow, eve_glow, door_lamps, world._lamps.size(), lamps_wrong])


func _check_pin_and_follow() -> void:
	day_view.jump_to(12.0)
	panel._change(0.005, "haze")
	var pinned: bool = not mood.follow_day
	day_view.jump_to(9.0)
	_add("touching a slider in the mood panel (F5) pins the look: the clock leaves it alone",
			pinned and is_equal_approx(mood.values["haze"], 0.005) and is_equal_approx(world.env.fog_density, 0.005),
			"haze %.4f" % world.env.fog_density)
	panel._preset("Night")
	day_view.jump_to(15.0)
	_add("so does a preset", not mood.follow_day and world.sun.light_energy < 0.5, "sun %.2f" % world.sun.light_energy)
	panel._follow()
	_add("Follow the day hands the light back to the clock", mood.follow_day and mood.values == mood.day_look(15.0), "")
	panel.set_open(true)
	var shown: float = panel._sliders["sun_height"].value
	panel.set_open(false)
	var step: float = mood.SLIDERS["sun_height"][3]   # the slider moves in steps of this
	_add("opening the panel shows the day's light on the sliders, and doesn't pin it",
			absf(shown - mood.values["sun_height"]) <= step * 0.5 + 0.0001 and mood.follow_day,
			"slider %.1f, light %.2f" % [shown, mood.values["sun_height"]])
	quality.set_level("low")
	day_view.jump_to(12.0)
	var low_haze: float = world.env.fog_density
	quality.set_level("high")
	day_view.jump_to(12.0)
	_add("low quality's least haze holds while the light follows the day", low_haze >= TQ.LOW_HAZE
			and is_equal_approx(world.env.fog_density, mood.PRESETS["Midday"]["haze"]), "low %.4f, high %.4f" % [low_haze, world.env.fog_density])


# ---------------------------------------------------------------- places, regulars, the market

func _check_places() -> void:
	var cases := [["store", 7.5, false], ["store", 8.5, true], ["store", 17.5, false], ["guild", 8.0, true],
			["guild", 17.0, false], ["tavern", 10.5, false], ["tavern", 11.5, true], ["tavern", 18.9, true],
			["bath", 8.5, false], ["bath", 9.5, true], ["workshop", 7.0, true], ["workshop", 18.5, false]]
	var bad := []
	for c in cases:
		day_view.jump_to(c[1])
		var sign: String = world._signs[c[0]][0].text
		if Day.is_open(c[0], c[1]) != c[2] or not sign.begins_with("OPEN" if c[2] else "CLOSED"):
			bad.append("%s at %s: %s" % [c[0], Day.clock_text(c[1]), sign.replace("\n", " ")])
	_add("places open and close on time, and their plaques say so (%d checks)" % cases.size(), bad.is_empty(), str(bad))
	var regulars := [["tavern", 10.5, 0], ["tavern", 12.0, 2], ["tavern", 17.5, 4], ["bath", 8.5, 0], ["bath", 12.0, 1],
			["bath", 17.0, 2], ["guild", 12.0, 4], ["guild", 17.5, 0]]
	bad = []
	for r in regulars:
		day_view.jump_to(r[1])
		var n := 0
		for e in world._extra_nodes:
			if e["where"] == r[0] and e["here"]:
				n += 1
		if n != r[2]:
			bad.append("%s at %s: %d, want %d" % [r[0], Day.clock_text(r[1]), n, r[2]])
	_add("the regulars are only in while it's open, and more come when it's busy", bad.is_empty(), str(bad))
	# Sabeth is at the guild before it opens: she says when it opens
	day_view.jump_to(7.6)
	var sabeth: Node3D = world.cast_nodes["sabeth"]
	_interact.use({"kind": "talk", "id": "sabeth", "pos": sabeth.position})
	var early: String = _interact.last_text
	_interact._close()   # hours later: that conversation is long over (another E right away would say goodbye)
	day_view.jump_to(12.0)
	_interact.use({"kind": "talk", "id": "sabeth", "pos": sabeth.position})
	var later: String = _interact.last_text
	_add("at a place that's closed, its people say when it opens", early == Day.closed_line("guild", 7.6) and "8:00" in early
			and later in Town.CAST["sabeth"]["lines"], "'%s' then '%s'" % [early, later])
	var board := {}
	for s in world.interact_spots:
		if s["id"] == "guild_board":
			board = s
	_interact._close()
	day_view.jump_to(18.0)
	_interact.use(board)
	var shut: String = _interact.last_text
	_interact._close()
	day_view.jump_to(12.0)
	_interact.use(board)
	_add("and so does its board", shut == Day.closed_line("guild", 18.0) and Town.PLACES["guild_board"]["lines"][0] in _interact.last_text,
			"'%s'" % shut)
	_interact._close()
	# At home nobody can be talked to
	day_view.jump_to(7.2)
	var keep: Vector3 = player.position
	player.position = world.home_doors["sabeth"]["pos"]
	var got: String = _interact.find_target().get("id", "")
	player.position = keep
	_add("someone at home (indoors) can't be talked to", world.cast_away.has("sabeth") and got != "sabeth", got)


func _check_market() -> void:
	var bad := []
	var shown := []
	var n: int = world.market_people.size()
	for h in [7.0, 8.0, 9.0, 12.0, 14.0, 17.5, 18.5, 18.9]:
		day_view.jump_to(h)
		var walkers := 0
		for pp in world.market_people:
			if pp["here"]:
				walkers += 1
		var standing := 0
		for idl in world.market_idlers:
			if idl["here"]:
				standing += 1
		shown.append("%s %d+%d" % [Day.clock_text(h), walkers, standing])
		if absf(walkers - Day.crowd_share(h) * n) > 1.0 or not is_equal_approx(world.market_share, float(walkers) / n):
			bad.append(Day.clock_text(h))
		if (h == 9.0 or h == 14.0) and standing != world.market_idlers.size():
			bad.append("%s standing" % Day.clock_text(h))
		if h >= 18.9 and standing != 0:
			bad.append("%s standing" % Day.clock_text(h))
	_add("the market's crowd follows the hour: thin at 8, full at noon, gone by 19:00 (walking + standing)",
			bad.is_empty() and Day.crowd_share(8.0) < 0.3 and Day.crowd_share(12.0) == 1.0 and Day.crowd_share(18.5) < 0.2,
			", ".join(shown) + " " + str(bad))


# ---------------------------------------------------------------- the residents' routines

func _check_routines() -> void:
	Engine.time_scale = SPEED
	day_view.day.frozen = false
	var trips := []
	trips.append_array(await _follow_residents(7.0, 8.9, true))     # out of their homes to work
	trips.append_array(await _follow_residents(10.3, 10.95, false)) # Dorran to his bar
	trips.append_array(await _follow_residents(16.95, 18.4, false)) # home, and Pell to the tavern
	Engine.time_scale = 1.0
	day_view.day.frozen = true
	var want := {}
	for id in Town.ROUTINES:
		if not world.life.has(id):
			continue   # Mira stays in the plaza (the errand's)
		var r: Array = Town.ROUTINES[id]
		for i in range(1, r.size()):
			want["%s to %s" % [id, r[i][1]]] = true
	var bad := []
	var slow := []
	var fake := []
	var off := []
	var lines := []
	for t in trips:
		var key := "%s to %s" % [t["id"], t["to"]]
		want.erase(key)
		lines.append("%s %.2f h" % [key, t["end"] - t["start"]] if t["end"] > 0.0 else key + " never")
		if t["end"] < 0.0:
			bad.append(key)
		elif t["end"] - t["start"] > 0.6:
			slow.append(key)
		if t["fake"]:
			fake.append(key)
		if t["off"] > 0:
			off.append("%s (%d frames, e.g. at %s)" % [key, t["off"], str(t["where"])])
	_add("every resident gets to each place in their routine within 36 minutes of game time (%d trips)" % trips.size(),
			bad.is_empty() and slow.is_empty() and want.is_empty() and trips.size() >= 8,
			"; ".join(lines) + "  missing: %s, slow: %s" % [str(want.keys() + bad), str(slow)])
	_add("they walk all the way (a route was found for every trip, no disappearing trick)", fake.is_empty(), str(fake))
	_add("they walk on walkable ground the whole way: never through a wall or off the floor", off.is_empty(), str(off))


## Runs the clock from one time to another and follows every resident's trips:
## [{"id", "to", "start", "end" (-1 = never got there), "fake", "off", "where"}].
func _follow_residents(from: float, to: float, snap: bool) -> Array:
	day_view.jump_to(from, -1, snap)
	var trips := []
	var open := {}     # id -> the trip they're on
	var last := {}
	for id in world.life:
		last[id] = world.life[id]["place"]
	while day_view.day.hour < to:
		await get_tree().process_frame
		for id in world.life:
			var L: Dictionary = world.life[id]
			if L["place"] != last[id]:
				last[id] = L["place"]
				open[id] = {"id": id, "to": L["place"], "start": day_view.day.hour, "end": -1.0, "fake": false, "off": 0, "where": null}
				trips.append(open[id])
			if not open.has(id):
				continue
			var t: Dictionary = open[id]
			if L["state"] == "vanish" or L["state"] == "appear":
				t["fake"] = true
			if L["state"] == "walk" and not world.cast_away.has(id):
				var p: Vector3 = world.cast_nodes[id].position
				var f: int = world.floor_at(p)
				if f < 0 or absf(p.y - (f + 0.5) * world.VS) > 0.5:
					t["off"] += 1
					t["where"] = p.snapped(Vector3.ONE * 0.1)
			var home: bool = L["place"] == "home"
			var there: bool = (L["state"] == "in" or world.cast_away.has(id)) if home else L["state"] == "at"
			if there and t["end"] < 0.0:
				var d: Vector3 = world.cast_nodes[id].position - L["dest"]["pos"]
				if Vector2(d.x, d.z).length() < 0.6 or world.cast_away.has(id):
					t["end"] = day_view.day.hour
				open.erase(id)
	return trips


# ---------------------------------------------------------------- the end of the day

func _check_end_of_day() -> void:
	# You on the market street, the camera close behind you, turning slowly round
	player.position = Vector3(12.0, world.VS * 0.5, 32.9)
	camera.snap_zoom(0.15)
	camera.yaw = 0.0
	day_view.jump_to(17.3)
	_events.clear()
	await _frames(3)
	Engine.time_scale = SPEED
	day_view.day.frozen = false
	var seen := {}           # checkpoints: what -> [ok, details]
	var unsafe := []
	var last_y := player.global_position.y
	var walked := -1.0
	var walk_from := Vector3.ZERO
	var walk_frames := 0
	var fp_ok := -1.0
	var lowest_deck := INF
	var card_ok := false
	var max_kneel := 0.0
	_flags = []
	while not (day_view.day.day == 2 and day_view.day.hour >= 7.6):
		await get_tree().process_frame
		_watch_pops()
		camera.yaw += 0.6 * get_process_delta_time()
		var h: float = day_view.day.hour
		var d: int = day_view.day.day
		var ph: int = day_view.day.phase
		max_kneel = maxf(max_kneel, world.kneel)
		lowest_deck = minf(lowest_deck, world.city.position.y)
		if d == 1 and h >= 17.95 and not seen.has("walking at 18"):
			seen["walking at 18"] = [world.walk_rate > 0.99 and world.kneel < 0.01, "walk %.2f" % world.walk_rate]
		if d == 1 and h >= 18.4 and not seen.has("slowing"):
			seen["slowing"] = [world.walk_rate > 0.05 and world.walk_rate < 0.95, "walk %.2f" % world.walk_rate]
		if d == 1 and h >= 18.75 and not seen.has("stopped"):
			seen["stopped"] = [world.walk_rate < 0.01 and world.kneel < 0.02, "walk %.3f, kneel %.3f" % [world.walk_rate, world.kneel]]
		if d == 1 and h >= 18.88 and not seen.has("kneeling"):
			seen["kneeling"] = [world.kneel > 0.2 and world.kneel < 0.95, "kneel %.2f" % world.kneel]
		if d == 1 and ph == Day.Phase.CARD and not seen.has("card"):
			seen["card"] = [world.kneel > 0.99 and day_view._card.visible and day_view._card.text == "Day 1 done"
					and day_view.day.darkness() == 1.0, "'%s', kneel %.2f" % [day_view._card.text, world.kneel]]
		if d == 2 and not seen.has("morning"):
			seen["morning"] = [absf(h - 7.0) < 0.01 and world.kneel > 0.99 and world.walk_rate < 0.01
					and mood.values == mood.day_look(h), "%s, kneel %.2f" % [Day.clock_text(h), world.kneel]]
		if d == 2 and h >= 7.26 and not seen.has("stood up"):
			seen["stood up"] = [world.kneel < 0.01, "kneel %.3f" % world.kneel]
		if d == 2 and h >= 7.5 and not seen.has("walking again"):
			seen["walking again"] = [world.walk_rate > 0.99, "walk %.2f" % world.walk_rate]
		# You, all the while: on a floor you can stand on, never inside a block, never dropping
		var f: int = world.floor_at(player.position)
		var y: float = player.global_position.y
		var bx := roundi(player.position.x / world.VS)
		var bz := roundi(player.position.z / world.VS)
		var in_block := false
		if f >= 0:
			for by in range(f + 1, f + 10):
				in_block = in_block or world.gv(bx, by, bz) != 0
		if f < 0 or in_block or absf(player.position.y - (f + 0.5) * world.VS) > 0.06 or absf(y - last_y) > 0.5:
			unsafe.append("%s at %s (floor %d, dropped %.2f m)" % [Day.clock_text(h), str(player.position.snapped(Vector3.ONE * 0.1)), f, last_y - y])
		last_y = y
		# The keys still walk you while the city kneels (the bot's input stands in for them)
		if d == 1 and h >= 18.8 and walked < 0.0 and walk_frames == 0:
			player.bot_mode = true
			player.bot_input = Vector2(-1, 0)
			walk_from = player.position
			walk_frames = 1
		elif walk_frames > 0 and walked < 0.0:
			walk_frames += 1
			if walk_frames > 5:
				walked = Vector2(player.position.x - walk_from.x, player.position.z - walk_from.z).length()
				player.bot_input = Vector2.ZERO
				player.bot_mode = false
		# First person through the kneel
		if d == 1 and h >= 18.86 and fp_ok < 0.0 and camera.zoom_goal >= 0.0:
			camera.zoom_goal = camera.FP_ZOOM
		if d == 1 and h >= 18.96 and fp_ok < 0.0:
			var eye: Vector3 = player.global_position + Vector3(0, player.eye_height(), 0)
			fp_ok = camera.global_position.distance_to(eye)
			fp_ok = fp_ok if camera.first_person > 0.95 else 99.0
			camera.snap_zoom(0.15)
	Engine.time_scale = 1.0
	day_view.day.frozen = true
	for k in ["walking at 18", "slowing", "stopped", "kneeling", "card", "morning", "stood up", "walking again"]:
		if not seen.has(k):
			seen[k] = [false, "never got there"]
	var order := []
	for e in _events:
		order.append(e[0])
	var bell_at := -1.0
	for e in _events:
		if e[0] == "evening_bell":
			bell_at = e[1]
	_add("the evening bell rings at 18:00, the day ends at 19:00, Day 2 starts (with the morning bell) and fades in",
			order == ["evening_bell", "day_over", "new_day", "awake"] and absf(bell_at - 18.0) < 0.01, str(order))
	_add("18:00 the city still walks; it slows to a stop by 18:45", seen["walking at 18"][0] and seen["slowing"][0] and seen["stopped"][0],
			"%s; %s; %s" % [seen["walking at 18"][1], seen["slowing"][1], seen["stopped"][1]])
	_add("from 18:45 it kneels, fully knelt at 19:00 (%.0f m lower)" % (world.CITY_HEIGHT * world.KNEEL_DROP),
			seen["kneeling"][0] and max_kneel > 0.99 and lowest_deck < world.CITY_HEIGHT * (1.0 - world.KNEEL_DROP) + 0.5,
			"%s; deck down to %.1f m" % [seen["kneeling"][1], lowest_deck])
	_add("at 19:00 the screen fades to dark: 'Day 1 done'", seen["card"][0], seen["card"][1])
	_add("Day 2 fades in at 7:00, still knelt, in the morning light", seen["morning"][0], seen["morning"][1])
	_add("the city stands up by 7:15 and walks again by 7:30", seen["stood up"][0] and seen["walking again"][0],
			"%s; %s" % [seen["stood up"][1], seen["walking again"][1]])
	_add("you stay safe on the deck the whole time: on a floor, never in a block, never dropping", unsafe.is_empty(),
			str(unsafe.slice(0, 5)))
	_add("the keys still walk you while the city kneels", walked > 1.0, "%.1f m" % walked)
	_add("first person works while it kneels (the camera at your eyes)", fp_ok >= 0.0 and fp_ok < 0.4, "%.2f m from your eyes" % fp_ok)
	_add("nobody appears or vanishes within %.0f m of the camera while it can see them (%d came or went)" % [IN_VIEW, _pops],
			_pops_bad.is_empty() and _pops > 20, str(_pops_bad.slice(0, 5)))


## Who's here, frame by frame: anyone who came or went last frame must have been out of
## the camera's sight then (out of view, more than 15 m away, or behind a wall). Uses the
## camera as it was when the world decided (the start of last frame), and ignores the
## moment the screen is dark between days.
func _watch_pops() -> void:
	var now := []
	for e in world._crowd:
		now.append([e["d"]["here"], e["d"]["node"].position, "market or regular"])
	for id in world.life:
		now.append([not world.cast_away.has(id), world.cast_nodes[id].position, id])
	if _flags.size() == now.size() and _dark < 0.99:
		for i in now.size():
			if now[i][0] != _flags[i]:
				_pops += 1
				if _was_in_view(now[i][1]):
					_pops_bad.append("%s %s at %s" % [now[i][2], "came" if now[i][0] else "went", str(now[i][1].snapped(Vector3.ONE * 0.1))])
	_flags = []
	for p in now:
		_flags.append(p[0])
	_planes = camera.get_frustum()
	_cam_local = world.city.to_local(camera.global_position)
	_city_xf = world.city.global_transform
	_dark = day_view.day.darkness()


func _was_in_view(p: Vector3) -> bool:
	var head := p + Vector3(0, 1.5, 0)
	if head.distance_to(_cam_local) > IN_VIEW:
		return false
	var g := _city_xf * head
	for pl: Plane in _planes:
		if pl.distance_to(g) > 0.0:
			return false
	return world.first_hit(_cam_local, head) >= 0.97


func _finish() -> void:
	var ok := true
	for r in results:
		print("%s  %s  (%s)" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		ok = ok and r[1]
	get_tree().quit(0 if ok else 1)
