extends "res://action.gd"
## ACTION TOY TEST: a bot plays the fight with simulated input.
##   -- --bot smart   plays like a careful person: steps just off the red charge strip (not a
##                    mile away), rolls through bites at the last moment, clicks about 6 times a
##                    second while it's stuck. Must WIN, and must have rolled through at least one attack.
##   -- --bot idle    stands still: must LOSE (so the beetle is a real challenge)
## Add --shots to save screenshots of key moments to shots/ (run it with tools/godot_offscreen.ps1).
## Run:  <godot_console.exe> --headless --path prototypes/combat_toys res://tests/action_test.tscn -- --bot smart

var bot := "smart"
var shots := false
var _seen := {}
var _limit := 240.0
var _done := false
var _click_wait := 0      # frames until the bot clicks again
var _states := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--bot")
	if i >= 0 and i + 1 < args.size():
		bot = args[i + 1]
	shots = args.has("--shots")
	super()


func read_input() -> Dictionary:
	var none := {"move": Vector2.ZERO, "attack": false, "dodge": false}
	if bot == "idle" or over:
		return none
	var want := Vector3.ZERO
	var attack := false
	var dodge := false
	var to_b := b_pos - p_pos
	to_b.y = 0
	var dist := to_b.length()
	match b_state:
		"lunge_windup", "lunge":
			# Once the strip stops turning, step just off the red (a little past its edge, the
			# way a person who trusts the warning would). Roll only if there's no time to walk.
			var rel := p_pos - b_pos
			rel.y = 0
			var along := rel.dot(b_dir)
			var side := rel - b_dir * along
			var out_dir := side.normalized() if side.length() > 0.1 else b_dir.cross(Vector3.UP)
			var locked := b_state == "lunge" or b_t < T.A_LUNGE_WINDUP * (0.8 if enraged else 1.0) * 0.35
			if locked and along > -1.0 and side.length() < T.A_LUNGE_HALF_WIDTH + 0.3:
				want = out_dir
				if (b_state == "lunge" or b_t < 0.08) and side.length() < T.A_LUNGE_HALF_WIDTH + 0.05:
					dodge = true
		"snap_windup":
			# Stand your ground and roll sideways through the bite at the last moment
			# (the roll's safe frames carry you through it)
			if b_t < 0.1 and _in_snap_fan(p_pos):
				want = to_b.normalized().cross(Vector3.UP)
				dodge = true
		"erupt_warn":
			var away := p_pos - b_target
			away.y = 0
			want = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
			if away.length() < 3.0 and b_t < 0.5:
				dodge = true
		"burrowed", "burrow_down":
			want = (p_pos - _trail.position).normalized()
		"stuck":
			var target := _nearest_beetle_point()
			var v := target - p_pos
			v.y = 0
			if v.length() > 2.6:
				want = v.normalized()
			else:
				# Click about 6 times a second, like a person (some clicks land during the hit-freeze)
				_click_wait -= 1
				if _click_wait <= 0:
					_click_wait = 10
					attack = true
		_:
			# Keep a safe distance and circle it, poking it if it walks into reach
			if dist < 5.5:
				want = -to_b.normalized() + to_b.normalized().cross(Vector3.UP) * 0.5
			elif dist > 8.0:
				want = to_b.normalized()
			else:
				want = to_b.normalized().cross(Vector3.UP)
			if Vector2(p_pos.x, p_pos.z).length() > Arena.RADIUS - 3.0:
				want += -p_pos.normalized()
	var fwd := -cam.global_basis.z
	fwd.y = 0
	var right := cam.global_basis.x
	right.y = 0
	want = want.normalized()
	return {"move": Vector2(want.dot(right.normalized()), want.dot(fwd.normalized())), "attack": attack, "dodge": dodge}


func _physics_process(delta: float) -> void:
	super(delta)
	_states[b_state] = _states.get(b_state, 0) + 1
	if shots:
		_shot_moments()
	if _done:
		return
	if over or fight_time > _limit:
		_done = true
		var t := get_tree().create_timer(2.5 if shots else 0.1)
		t.timeout.connect(_report)


func _shot_moments() -> void:
	var moments := {"lunge_windup": 0.75, "stuck": 0.3, "snap_windup": 0.4, "erupt_warn": 0.5}
	if moments.has(b_state) and not _seen.has(b_state + str(enraged)):
		var total := b_t
		if b_t <= moments[b_state] * 1.2:
			_seen[b_state + str(enraged)] = true
			_save("%s%s" % [b_state, "_enraged" if enraged else ""])
	if hits_landed == 3 and not _seen.has("hit"):
		_seen["hit"] = true
		_save("hit")
	if over and not _seen.has("end") and get_tree().get_frame() % 1 == 0:
		_seen["end"] = true
		get_tree().create_timer(2.0).timeout.connect(_save.bind("end"))


func _save(n: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/action_%s.png" % n)


func _report() -> void:
	print("beetle states (frames): ", _states)
	var ok := false
	if bot == "smart":
		ok = won and dodges > 0
		print("%s  the smart bot beats the beetle, rolling through at least one attack  (%s after %d s: %d hits, hurt %d times, %d dodges, beetle health %d)" % [
				"PASS" if ok else "FAIL", "won" if won else "lost", int(fight_time), hits_landed, hits_taken, dodges, b_hp])
	else:
		ok = over and not won
		print("%s  standing still loses  (%s after %d s)" % ["PASS" if ok else "FAIL", "lost" if ok else "didn't lose", int(fight_time)])
	get_tree().quit(0 if ok else 1)
