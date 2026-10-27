extends Node3D
## TOY A: ACTION. You against the dune beetle, in real time, at night.
## Watch it wind up (it rears, its eyes flare and a red warning shows on the sand),
## roll out of the way, then hit it while it's stuck. Below half health it gets
## angry: faster, and it starts burrowing to burst up under you.
## All the numbers are in tuning.gd.

signal back_to_menu
signal restart

const T := preload("res://tuning.gd")
const Fx := preload("res://fx.gd")
const Arena := preload("res://arena.gd")
const Person := preload("res://person.gd")
const Beetle := preload("res://beetle.gd")
const Sfx := preload("res://toy_sfx.gd")

# The beetle's shape (metres): a round body, and a round head in front of it
const BODY_R := 1.45
const HEAD_AHEAD := 2.3          # how far in front of its middle the head is
const HEAD_R := 0.95
const SNAP_FROM := 1.6           # the bite fan starts this far in front of its middle

var arena: Node3D
var sfx: Node
var cam: Camera3D
var hero_root: Node3D
var roll: Node3D
var hero: Node3D
var beetle: Node3D

# You
var p_pos := Vector3(0, 0, 9)
var p_face := Vector3(0, 0, -1)
var knock := Vector3.ZERO
var hearts := T.A_PLAYER_HEARTS
var safe_t := 0.0         # can't be hurt while this is above 0
var dodge_t := 0.0        # time left in a roll
var dodge_dir := Vector3.ZERO
var dodge_cd := 0.0
var stagger_t := 0.0
var swing_t := -1.0       # time into the current swing (-1 = not swinging)
var combo := 0
var queued := false
var combo_window := 0.0
var swing_landed := false
var step_t := 0.0

# The beetle
var b_pos := Vector3(0, 0, -6)
var b_yaw := 0.0
var b_hp := T.A_BEETLE_HEALTH
var b_state := "approach"
var b_t := 1.0
var b_dir := Vector3.FORWARD
var b_snap_cd := 0.0
var b_lunge_cd := 1.5
var b_burrow_cd := 0.0
var b_target := Vector3.ZERO      # where it will burst out of the sand
var b_dig := Vector3.ZERO          # where it is under the sand
var b_lunge_left := 0.0            # metres of the charge still to go
var b_step_t := 0.0
var enraged := false

var over := false
var won := false
var freeze := 0.0
var shake := 0.0
var cam_yaw := 0.0
var fight_time := 0.0
var hits_landed := 0
var hits_taken := 0
var dodges := 0
var dodged_t := 0.0       # just rolled through an attack (so it's only counted once)

var _prev_attack := false
var _prev_dodge := false
var _attack_buf := 0.0    # a click waiting to be used (seconds left to use it)
var _dodge_buf := 0.0     # a roll waiting to be used
var _strip: MeshInstance3D
var _cone: MeshInstance3D
var _circle: MeshInstance3D
var _trail: CPUParticles3D
var _danger_mat: StandardMaterial3D
var _hud: CanvasLayer
var _heart_boxes: Array[ColorRect] = []
var _bar_fill: ColorRect
var _bar_label: Label
var _result: Control
var _result_label: Label
var _hurt_overlay: ColorRect


func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	sfx = Sfx.new()
	add_child(sfx)
	hero_root = Node3D.new()
	add_child(hero_root)
	roll = Node3D.new()
	roll.position = Vector3(0, 0.9, 0)
	hero_root.add_child(roll)
	hero = Person.new()
	hero.build(Color(0.16, 0.55, 0.58), Color(0.30, 0.24, 0.20), Color(0.20, 0.13, 0.08), Color(0.92, 0.75, 0.62), "sword", true)
	hero.position = Vector3(0, -0.9, 0)
	roll.add_child(hero)
	beetle = Beetle.new()
	add_child(beetle)
	b_yaw = _yaw_of(p_pos - b_pos)
	cam = Camera3D.new()
	cam.fov = 62
	cam.far = 900
	add_child(cam)
	cam_yaw = _yaw_of(p_pos - b_pos) + PI
	_make_danger_marks()
	_make_hud()
	_sync_visuals(0.0)
	_update_camera(1.0)


# ---------------------------------------------------------------- input

## What the player is asking for this frame. Tests replace this with a bot.
## move: x = right, y = forward (relative to the camera).
func read_input() -> Dictionary:
	var mv := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.y += 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.y -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1
	var atk := Input.is_physical_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var dge := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_K) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var out := {"move": mv.limit_length(1.0), "attack": atk and not _prev_attack, "dodge": dge and not _prev_dodge}
	_prev_attack = atk
	_prev_dodge = dge
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			back_to_menu.emit()
		elif event.physical_keycode == KEY_R and over:
			restart.emit()


# ---------------------------------------------------------------- the fight

func _physics_process(delta: float) -> void:
	var inp := read_input()
	# Remember presses for a moment, so a click or roll pressed during the hit-freeze,
	# a stagger or the end of a swing isn't thrown away (used in _update_player).
	if inp["attack"]:
		_attack_buf = T.A_INPUT_BUFFER
	if inp["dodge"]:
		_dodge_buf = T.A_INPUT_BUFFER
	if freeze > 0.0:
		freeze -= delta
		_sync_visuals(delta)
		_update_camera(delta)
		return
	if not over:
		fight_time += delta
		_update_player(delta, inp)
		_update_beetle(delta)
	else:
		knock = knock.move_toward(Vector3.ZERO, 20.0 * delta)
	_sync_visuals(delta)
	_update_camera(delta)


func _update_player(delta: float, inp: Dictionary) -> void:
	safe_t -= delta
	dodged_t -= delta
	dodge_cd -= delta
	stagger_t -= delta
	combo_window -= delta
	var fwd := -cam.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := cam.global_basis.x
	right.y = 0
	right = right.normalized()
	var want: Vector3 = right * inp["move"].x + fwd * inp["move"].y
	var vel := Vector3.ZERO
	var attack := _attack_buf > 0.0
	var dodge := _dodge_buf > 0.0
	# A swing in progress
	if swing_t >= 0.0:
		swing_t += delta
		if attack:
			queued = true
			_attack_buf = 0.0
		if not swing_landed and swing_t >= T.A_SWING_TIME * 0.4:
			swing_landed = true
			_sword_hits()
		if swing_t >= T.A_SWING_TIME:
			swing_t = -1.0
			combo_window = 0.25
			if queued and combo < 2:
				_start_swing(combo + 1)
		vel = p_face * 1.5 * (1.0 - swing_t / T.A_SWING_TIME) if swing_t >= 0.0 else Vector3.ZERO
	if dodge_t > 0.0:
		dodge_t -= delta
		vel = dodge_dir * T.A_DODGE_SPEED
	elif stagger_t <= 0.0:
		var can_act := swing_t < 0.0 or swing_landed
		if dodge and dodge_cd <= 0.0 and can_act:
			_dodge_buf = 0.0
			swing_t = -1.0
			queued = false
			dodge_dir = want.normalized() if want.length() > 0.2 else -p_face
			dodge_t = T.A_DODGE_TIME
			dodge_cd = T.A_DODGE_TIME + T.A_DODGE_COOLDOWN
			p_face = dodge_dir
			sfx.play("dodge")
			Fx.dust(self, p_pos + Vector3(0, 0.2, 0), 8, 1.5)
		elif attack and swing_t < 0.0:
			_attack_buf = 0.0
			_start_swing(combo + 1 if combo_window > 0.0 and combo < 2 else 0)
		elif swing_t < 0.0:
			vel = want * T.A_PLAYER_SPEED
			if want.length() > 0.1:
				p_face = p_face.slerp(want.normalized(), 1.0 - exp(-14.0 * delta)).normalized()
				step_t -= delta * want.length()
				if step_t <= 0.0:
					step_t = 0.34
					sfx.play("step")
	# Waiting presses fade, but not while you're staggered (or frozen: this doesn't run then)
	if stagger_t <= 0.0:
		_attack_buf -= delta
		_dodge_buf -= delta
	knock = knock.move_toward(Vector3.ZERO, 22.0 * delta)
	p_pos += (vel + knock) * delta
	_keep_apart()
	var r := Vector2(p_pos.x, p_pos.z)
	if r.length() > Arena.RADIUS:
		r = r.normalized() * Arena.RADIUS
		p_pos = Vector3(r.x, 0, r.y)


func _start_swing(n: int) -> void:
	combo = n
	swing_t = 0.0
	swing_landed = false
	queued = false
	# Turn toward the beetle if it's close, so swings don't miss by a hair
	var to_b := _nearest_beetle_point() - p_pos
	to_b.y = 0
	if to_b.length() < 5.0 and b_state != "burrowed" and b_state != "burrow_down":
		p_face = to_b.normalized()
	hero.swing([0, 1, 2][n], T.A_SWING_TIME)
	sfx.play("swing", 0.0, [1.0, 1.08, 0.85][n])


func _sword_hits() -> void:
	if b_state in ["burrowed", "burrow_down", "erupt_warn", "dead"]:
		return
	for c in _beetle_circles():
		var v: Vector3 = c[0] - p_pos
		v.y = 0
		var gap: float = v.length() - c[1]
		if gap < T.A_REACH and (gap < 0.3 or p_face.angle_to(v.normalized()) < deg_to_rad(75)):
			_hurt_beetle(T.A_COMBO_DAMAGE[combo], c[0])
			return


func _hurt_beetle(dmg: int, at: Vector3) -> void:
	var stuck := b_state == "stuck"
	if stuck:
		dmg *= T.A_STUCK_MULTIPLIER
	b_hp -= dmg
	hits_landed += 1
	beetle.flash(Color(1.0, 0.8, 0.55), 0.22 if stuck else 0.15)
	var hit_at := at.lerp(p_pos, 0.45) + Vector3(0, 1.1, 0)
	Fx.burst(self, hit_at, Color(1.0, 0.75, 0.35), 22 if stuck else 12, 6.0)
	Fx.popup(self, hit_at + Vector3(0, 0.4, 0), str(dmg), Color(1.0, 0.85, 0.4) if not stuck else Color(1.0, 0.5, 0.25), 72 if stuck else 56)
	sfx.play("hit_big" if (stuck or combo == 2) else "hit")
	freeze = 0.09 if (stuck or combo == 2) else 0.055
	shake = maxf(shake, 0.25 if stuck else 0.12)
	b_pos += (b_pos - p_pos).normalized() * (0.0 if stuck else 0.12)
	if b_hp <= 0:
		_win()
	elif not enraged and b_hp <= T.A_BEETLE_HEALTH * T.A_ENRAGE_AT:
		enraged = true
		b_burrow_cd = 3.0
		Fx.popup(self, b_pos + Vector3(0, 3.2, 0), "ENRAGED!", Color(1.0, 0.35, 0.25), 90)
		sfx.play("screech", 4.0, 0.8)
		_bar_label.text = "DUNE BEETLE  —  ENRAGED"


func _hurt_player(push: Vector3) -> void:
	if safe_t > 0.0 or dodged_t > 0.0 or over:
		return
	if dodge_t > T.A_DODGE_TIME - T.A_DODGE_SAFE:
		dodges += 1
		dodged_t = 0.4
		Fx.popup(self, p_pos + Vector3(0, 2.2, 0), "dodged!", Color(0.6, 0.9, 1.0), 44)
		return
	hearts -= 1
	hits_taken += 1
	safe_t = T.A_HURT_SAFE
	stagger_t = 0.3
	swing_t = -1.0
	knock = push.normalized() * 9.0
	hero.flash(Color(1, 0.3, 0.2), 1.5)
	sfx.play("hurt")
	shake = 0.35
	freeze = 0.08
	Fx.burst(self, p_pos + Vector3(0, 1.2, 0), Color(1.0, 0.3, 0.2), 10, 4.0)
	_hurt_overlay.color.a = 0.35
	_update_hearts()
	if hearts <= 0:
		_lose()


# ---------------------------------------------------------------- the beetle's mind

func _update_beetle(delta: float) -> void:
	b_t -= delta
	b_snap_cd -= delta
	b_lunge_cd -= delta
	if enraged:
		b_burrow_cd -= delta
	var to_p := p_pos - b_pos
	to_p.y = 0
	var dist := to_p.length()
	var speed_mul := 1.2 if enraged else 1.0
	var windup_mul := 0.8 if enraged else 1.0
	var walk := 0.0
	match b_state:
		"approach":
			beetle.set_pose(0.0, 0.15, 1.0)
			_turn_toward(to_p, 2.8 * speed_mul, delta)
			if dist > 3.0:
				b_pos += _b_fwd() * T.A_BEETLE_SPEED * speed_mul * delta
				walk = T.A_BEETLE_SPEED * speed_mul
			if b_t <= 0.0:
				if enraged and b_burrow_cd <= 0.0:
					_set_state("burrow_down", 0.8)
					sfx.play("burrow")
				elif dist < T.A_SNAP_RANGE + 0.6 and b_snap_cd <= 0.0:
					_set_state("snap_windup", T.A_SNAP_WINDUP * windup_mul)
					sfx.play("screech", -3.0, 1.35)
				elif dist > 5.0 and b_lunge_cd <= 0.0:
					_set_state("lunge_windup", T.A_LUNGE_WINDUP * windup_mul)
					sfx.play("screech")
		"lunge_windup":
			var total := T.A_LUNGE_WINDUP * windup_mul
			var k := 1.0 - b_t / total
			if k < 0.65:
				_turn_toward(to_p, 4.0, delta)
				b_dir = _b_fwd()
			beetle.set_pose(0.6, 0.8, 1.0 + 2.2 * k)
			b_lunge_left = T.A_LUNGE_SPEED * T.A_LUNGE_TIME
			_show_strip(k)
			if b_t <= 0.0:
				_set_state("lunge", T.A_LUNGE_TIME)
				_show_strip(1.0)
				sfx.play("beetle_step", 8.0)
				Fx.dust(self, b_pos, 20, 4.0)
		"lunge":
			beetle.set_pose(-0.15, 0.9, 3.0)
			# It charges exactly the length of the strip it showed (no more, no less)
			var step := minf(T.A_LUNGE_SPEED * delta, b_lunge_left)
			b_pos += b_dir * step
			b_lunge_left -= step
			walk = 9.0
			_show_strip(1.0)     # the strip stays on, showing what's still ahead of it
			# Hit if you're on the red, between its middle and the tip of its head
			if _on_strip(p_pos, HEAD_AHEAD + HEAD_R):
				var rel := p_pos - b_pos
				rel.y = 0
				var side := rel - b_dir * rel.dot(b_dir)
				_hurt_player(side.normalized() * 0.6 + b_dir)
				if over:
					return    # that knocked you out: the fight is over, leave the beetle as it is
			if Vector2(b_pos.x, b_pos.z).length() > Arena.RADIUS + 0.5:
				# Slammed into the rocks: stuck for longer
				var r := Vector2(b_pos.x, b_pos.z).normalized() * (Arena.RADIUS + 0.5)
				b_pos = Vector3(r.x, 0, r.y)
				shake = 0.4
				sfx.play("hit_big", 2.0, 0.6)
				Fx.dust(self, b_pos + _b_fwd() * 2.5, 30, 5.0)
				_set_state("stuck", T.A_STUCK_TIME * 1.5)
				_on_stuck()
			elif b_lunge_left <= 0.0:
				_set_state("stuck", T.A_STUCK_TIME)
				_on_stuck()
		"stuck":
			beetle.set_pose(-0.35, 0.3, 0.4)
			if b_t <= 0.0:
				b_lunge_cd = 2.5
				_set_state("approach", 0.3)
		"snap_windup":
			var total := T.A_SNAP_WINDUP * windup_mul
			var k := 1.0 - b_t / total
			_turn_toward(to_p, 3.0, delta)
			beetle.set_pose(0.3, 1.0, 1.0 + 2.0 * k)
			_show_cone(k)
			if b_t <= 0.0:
				_cone.visible = false
				beetle.set_pose(-0.1, 0.0, 2.0)
				sfx.play("hit_big", 0.0, 1.3)
				if _in_snap_fan(p_pos):
					var v := p_pos - b_pos
					v.y = 0
					_hurt_player(v.normalized() + _b_fwd())
					if over:
						return
				b_snap_cd = 1.4
				_set_state("recover", 0.6)
		"recover":
			beetle.set_pose(0.0, 0.1, 1.0)
			if b_t <= 0.0:
				_set_state("approach", 0.4)
		"burrow_down":
			var k := 1.0 - b_t / 0.8
			beetle.position.y = -2.2 * k
			if fmod(b_t, 0.2) < delta:
				Fx.dust(self, b_pos + Vector3(0, 0.2, 0), 14, 3.0)
			if b_t <= 0.0:
				b_dig = b_pos
				beetle.visible = false
				_trail.emitting = true
				_set_state("burrowed", 2.5)
		"burrowed":
			var to := p_pos - b_dig
			to.y = 0
			b_dig += to.limit_length(7.5 * speed_mul * delta)
			_trail.position = b_dig + Vector3(0, 0.1, 0)
			b_step_t -= delta
			if b_step_t <= 0.0:
				b_step_t = 0.3
				sfx.play("beetle_step", -2.0, 0.7)
			if to.length() < 1.0 or b_t <= 0.0:
				b_target = p_pos
				_set_state("erupt_warn", T.A_ERUPT_WARNING * windup_mul)
				sfx.play("screech", 0.0, 0.6)
		"erupt_warn":
			var k := 1.0 - b_t / (T.A_ERUPT_WARNING * windup_mul)
			_show_circle(k)
			_trail.position = b_target + Vector3(0, 0.1, 0)
			if b_t <= 0.0:
				_circle.visible = false
				_trail.emitting = false
				b_pos = b_target
				beetle.visible = true
				beetle.position.y = -2.0
				var t := beetle.create_tween()
				t.tween_property(beetle, "position:y", 0.9, 0.15).set_ease(Tween.EASE_OUT)
				t.tween_property(beetle, "position:y", 0.0, 0.25).set_ease(Tween.EASE_IN)
				Fx.dust(self, b_pos + Vector3(0, 0.3, 0), 40, 7.0)
				sfx.play("burrow", 4.0, 0.8)
				shake = 0.5
				var v := p_pos - b_target
				v.y = 0
				if v.length() <= T.A_ERUPT_RADIUS:
					_hurt_player(v if v.length() > 0.1 else Vector3.BACK)
					if over:
						return    # knocked out: don't call it "stuck" over the end screen
				b_burrow_cd = T.A_BURROW_EVERY
				_set_state("stuck", T.A_STUCK_TIME * 1.3)
				_on_stuck()
	if b_state != "burrowed" and b_state != "burrow_down" and b_state != "erupt_warn":
		var r := Vector2(b_pos.x, b_pos.z)
		if r.length() > Arena.RADIUS + 0.5:
			r = r.normalized() * (Arena.RADIUS + 0.5)
			b_pos = Vector3(r.x, 0, r.y)
	beetle.walk_speed = walk
	if walk > 0.5:
		b_step_t -= delta * walk
		if b_step_t <= 0.0:
			b_step_t = 2.2
			sfx.play("beetle_step", -6.0 if walk < 5 else 0.0)


func _on_stuck() -> void:
	Fx.popup(self, b_pos + Vector3(0, 2.8, 0), "STUCK!", Color(0.6, 1.0, 0.5), 64)
	Fx.dust(self, b_pos + _b_fwd() * 2.6, 24, 3.0)


func _set_state(s: String, t: float) -> void:
	b_state = s
	b_t = t
	_strip.visible = false
	_cone.visible = false


func _b_fwd() -> Vector3:
	return Vector3(-sin(b_yaw), 0, -cos(b_yaw))


func _yaw_of(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _turn_toward(d: Vector3, rate: float, delta: float) -> void:
	if d.length() < 0.01:
		return
	var want := _yaw_of(d)
	b_yaw += clampf(wrapf(want - b_yaw, -PI, PI), -rate * delta, rate * delta)


## The beetle's shape for hits and pushing: [centre, radius] for its body and its head.
func _beetle_circles() -> Array:
	return [[b_pos, BODY_R], [b_pos + _b_fwd() * HEAD_AHEAD, HEAD_R]]


## Is the point on the charge's red strip, between the beetle's middle and `ahead` metres in front?
## The strip on the sand is drawn from the same numbers (see _show_strip).
func _on_strip(p: Vector3, ahead: float) -> bool:
	var rel := p - b_pos
	rel.y = 0
	var along := rel.dot(b_dir)
	var side := (rel - b_dir * along).length()
	return side <= T.A_LUNGE_HALF_WIDTH and along >= 0.0 and along <= ahead


## Is the point inside the red bite fan? (Drawn from the same numbers in _show_cone.)
func _in_snap_fan(p: Vector3) -> bool:
	var v := p - (b_pos + _b_fwd() * SNAP_FROM)
	v.y = 0
	return v.length() <= T.A_SNAP_RANGE and _b_fwd().angle_to(v) <= deg_to_rad(T.A_SNAP_ANGLE)


func _nearest_beetle_point() -> Vector3:
	var best := b_pos
	var bd := INF
	for c in _beetle_circles():
		var d: float = (c[0] - p_pos).length() - c[1]
		if d < bd:
			bd = d
			best = c[0]
	return best


## You can't walk through the beetle (unless it's under the sand).
func _keep_apart() -> void:
	if b_state in ["burrowed", "burrow_down", "erupt_warn"] or b_state == "lunge":
		return
	for c in _beetle_circles():
		var v: Vector3 = p_pos - c[0]
		v.y = 0
		var min_d: float = c[1] + 0.4
		if v.length() < min_d:
			p_pos = c[0] + (v.normalized() if v.length() > 0.01 else Vector3.BACK) * min_d
			p_pos.y = 0


func _win() -> void:
	over = true
	won = true
	b_state = "dead"
	_strip.visible = false
	_cone.visible = false
	_circle.visible = false
	beetle.die()
	hero.cheer()
	freeze = 0.25
	shake = 0.6
	sfx.play("hit_big", 4.0, 0.5)
	create_tween().tween_callback(sfx.play.bind("win")).set_delay(0.5)   # a tween ends with the toy; a timer could fire after you left
	Fx.dust(self, b_pos, 40, 6.0)
	_show_result("THE BEETLE IS BEATEN!", "%d s · %d hits · hurt %d times" % [int(fight_time), hits_landed, hits_taken])


func _lose() -> void:
	over = true
	hero.fall()
	_set_state("recover", 99.0)
	beetle.set_pose(0.5, 1.0, 3.0)
	_show_result("KNOCKED OUT", "The beetle had %d of %d health left" % [maxi(b_hp, 0), T.A_BEETLE_HEALTH])


# ---------------------------------------------------------------- looks

func _sync_visuals(delta: float) -> void:
	hero_root.position = p_pos
	hero_root.rotation.y = _yaw_of(p_face)
	hero.move_speed = 0.0 if (swing_t >= 0.0 or over) else (p_pos - hero_root.get_meta("last", p_pos)).length() / maxf(delta, 0.001)
	hero_root.set_meta("last", p_pos)
	if dodge_t > 0.0:
		roll.rotation.x = -TAU * (1.0 - dodge_t / T.A_DODGE_TIME)
	else:
		roll.rotation.x = 0.0
	# Blink while you can't be hurt after a hit
	hero.visible = not (safe_t > 0.0 and not over and fmod(safe_t, 0.16) < 0.05)
	if b_state != "burrowed":
		beetle.position.x = b_pos.x
		beetle.position.z = b_pos.z
	beetle.rotation.y = b_yaw
	_hurt_overlay.color.a = maxf(0.0, _hurt_overlay.color.a - delta * 1.2)
	_bar_fill.size.x = 560.0 * clampf(float(b_hp) / T.A_BEETLE_HEALTH, 0.0, 1.0)


func _update_camera(delta: float) -> void:
	var focus := b_pos
	if b_state == "burrowed" or b_state == "erupt_warn":
		focus = _trail.position
	var away := p_pos - focus
	away.y = 0
	if away.length() > 2.5 and not over:
		cam_yaw = lerp_angle(cam_yaw, atan2(away.x, away.z), 1.0 - exp(-2.2 * delta))
	elif over:
		cam_yaw += delta * 0.25
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var look := p_pos.lerp(focus, 0.45) + Vector3(0, 0.9, 0)
	var side := back.cross(Vector3.UP)    # a little over your right shoulder, so you don't hide the beetle
	var want := p_pos + back * 9.0 - side * 1.6 + Vector3(0, 5.8, 0)
	if over:
		# Look at the beetle from the open middle of the arena
		var inward := -Vector3(b_pos.x, 0, b_pos.z).normalized() if b_pos.length() > 3.0 else back
		want = b_pos + inward.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.0002) * 0.6) * 7.0 + Vector3(0, 6.0, 0)
		look = b_pos + Vector3(0, 0.5, 0)
	# Stay inside the ring of rocks: if you're at the edge, look down from higher up instead
	var flat := Vector2(want.x, want.z)
	if flat.length() > Arena.RADIUS - 0.5:
		var extra := flat.length() - (Arena.RADIUS - 0.5)
		flat = flat.normalized() * (Arena.RADIUS - 0.5)
		want = Vector3(flat.x, want.y + extra * 0.6, flat.y)
	cam.position = cam.position.lerp(want, 1.0 - exp(-12.0 * delta)) if cam.position != Vector3.ZERO else want
	if (cam.position - look).length() > 0.1:
		cam.look_at(look, Vector3.UP)
	shake = maxf(0.0, shake - delta * 1.8)
	if shake > 0.0:
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.3


func _make_danger_marks() -> void:
	_danger_mat = StandardMaterial3D.new()
	_danger_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_danger_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_danger_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_danger_mat.albedo_color = Color(1.0, 0.15, 0.08, 0.4)
	_strip = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(T.A_LUNGE_HALF_WIDTH * 2.0, 1.0)    # 1 m long: stretched to length in _show_strip
	_strip.mesh = pm
	_strip.material_override = _danger_mat
	add_child(_strip)
	_cone = MeshInstance3D.new()
	_cone.mesh = _fan(T.A_SNAP_RANGE, deg_to_rad(T.A_SNAP_ANGLE))
	_cone.material_override = _danger_mat
	add_child(_cone)
	_circle = MeshInstance3D.new()
	_circle.mesh = _fan(T.A_ERUPT_RADIUS, PI, 64)
	_circle.material_override = _danger_mat
	add_child(_circle)
	for m in [_strip, _cone, _circle]:
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail = CPUParticles3D.new()
	_trail.amount = 60
	_trail.lifetime = 0.8
	_trail.emitting = false
	_trail.direction = Vector3.UP
	_trail.spread = 50.0
	_trail.initial_velocity_min = 1.5
	_trail.initial_velocity_max = 3.5
	_trail.gravity = Vector3(0, -6, 0)
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 0.8
	_trail.scale_amount_min = 0.1
	_trail.scale_amount_max = 0.2
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.66, 0.58, 0.46)
	box.material = dm
	_trail.mesh = box
	add_child(_trail)


## A flat fan on the ground (a slice of a circle), pointing along -z.
func _fan(radius: float, half_angle: float, steps := 28) -> ArrayMesh:
	var v := PackedVector3Array()
	for i in steps:
		var a0 := -half_angle + 2.0 * half_angle * i / steps
		var a1 := -half_angle + 2.0 * half_angle * (i + 1) / steps
		v.append(Vector3.ZERO)
		v.append(Vector3(sin(a0), 0, -cos(a0)) * radius)
		v.append(Vector3(sin(a1), 0, -cos(a1)) * radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Warning marks get stronger as the attack gets closer, and flicker at the end.
func _danger_alpha(k: float) -> float:
	var a := lerpf(0.12, 0.5, k)
	if k > 0.8 and fmod(Time.get_ticks_msec(), 120) < 60:
		a = 0.75
	return a


## The charge's red strip: from the beetle's middle to where the tip of its head will end up
## (the charge still to go, plus its head). The same box _on_strip() hits you in.
func _show_strip(k: float) -> void:
	var len := b_lunge_left + HEAD_AHEAD + HEAD_R
	_strip.visible = true
	_strip.position = b_pos + b_dir * (len * 0.5) + Vector3(0, 0.05, 0)
	_strip.rotation.y = _yaw_of(b_dir)
	_strip.scale = Vector3(1, 1, len)
	_danger_mat.albedo_color.a = _danger_alpha(k)


func _show_cone(k: float) -> void:
	_cone.visible = true
	_cone.position = b_pos + _b_fwd() * SNAP_FROM + Vector3(0, 0.05, 0)
	_cone.rotation.y = b_yaw
	_danger_mat.albedo_color.a = _danger_alpha(k)


func _show_circle(k: float) -> void:
	_circle.visible = true
	_circle.position = b_target + Vector3(0, 0.05, 0)
	_danger_mat.albedo_color.a = _danger_alpha(k)


# ---------------------------------------------------------------- screen

func _make_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	_hurt_overlay = ColorRect.new()
	_hurt_overlay.color = Color(0.8, 0.05, 0.02, 0.0)
	_hurt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hurt_overlay)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.45)
	back.position = Vector2(18, 18)
	back.size = Vector2(T.A_PLAYER_HEARTS * 40 + 14, 76)
	_hud.add_child(back)
	for i in T.A_PLAYER_HEARTS:
		var h := ColorRect.new()
		h.size = Vector2(30, 30)
		h.position = Vector2(30 + i * 40, 30)
		_hud.add_child(h)
		_heart_boxes.append(h)
	_update_hearts()
	var you := _label("YOU", 18, Vector2(30, 66))
	you.modulate = Color(1, 1, 1, 0.7)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.offset_left = -284
	bg.offset_right = 284
	bg.offset_top = 56
	bg.offset_bottom = 78
	_hud.add_child(bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.85, 0.30, 0.18)
	_bar_fill.size = Vector2(560, 14)
	_bar_fill.position = Vector2(4, 4)
	bg.add_child(_bar_fill)
	_bar_label = _label("DUNE BEETLE", 22, Vector2(0, -32))
	_bar_label.reparent(bg, false)
	_bar_label.size = Vector2(568, 30)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label("WASD move   ·   Space or right click: roll   ·   Left click or J: strike (click again for a combo)   ·   Esc: menu", 18, Vector2.ZERO)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.position = Vector2(0, -40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.75)
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.visible = false
	_hud.add_child(_result)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.anchor_top = 0.14
	shade.anchor_bottom = 0.40
	shade.anchor_right = 1.0
	_result.add_child(shade)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 52)
	_result_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_result_label.add_theme_constant_override("outline_size", 10)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.anchor_right = 1.0
	_result_label.anchor_top = 0.14
	_result_label.anchor_bottom = 0.40
	_result.add_child(_result_label)


func _label(text: String, size: int, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.position = at
	_hud.add_child(l)
	return l


func _update_hearts() -> void:
	for i in _heart_boxes.size():
		_heart_boxes[i].color = Color(0.92, 0.22, 0.20) if i < hearts else Color(0.2, 0.2, 0.22, 0.6)


func _show_result(title: String, detail: String) -> void:
	_result_label.text = "%s\n%s\n\nR: fight again    ·    Esc: back to the menu" % [title, detail]
	var t := create_tween()
	_result.modulate.a = 0.0
	_result.visible = true
	t.tween_interval(1.0)
	t.tween_property(_result, "modulate:a", 1.0, 0.4)
