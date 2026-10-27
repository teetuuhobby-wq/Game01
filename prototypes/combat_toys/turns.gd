extends Node3D
## TOY B: TURN-BASED. You and Bram against the dune beetle, with one shared hand of cards.
## The beetle's plan floats over its head: what, at whom, and when (at the end of your
## turn, or right after your Nth card). Play cards in the right order to stay alive.
## The rules are in turns_rules.gd; this file only shows them and takes your clicks.

signal back_to_menu
signal restart

const T := preload("res://tuning.gd")
const R := preload("res://turns_rules.gd")
const Fx := preload("res://fx.gd")
const Arena := preload("res://arena.gd")
const Person := preload("res://person.gd")
const Beetle := preload("res://beetle.gd")
const Sfx := preload("res://toy_sfx.gd")

const HOME := [Vector3(-2.3, 0, 1.9), Vector3(-5.0, 0, -0.3), Vector3(3.8, 0, 0)]
const OWNER_COLOURS := [Color(0.13, 0.42, 0.46), Color(0.62, 0.33, 0.14)]

var rules := R.new()
var arena: Node3D
var sfx: Node
var cam: Camera3D
var units: Array = []          # You, Bram (person.gd), the beetle (beetle.gd)
var busy := false
var aiming := -1               # hand index of a card waiting for you to pick who it's for
var hover := -1
var seed_value := 0

var _ui: CanvasLayer
var _cards: Array[Button] = []
var _plates: Array[PanelContainer] = []
var _plate_bars: Array[ColorRect] = []
var _plate_text: Array[Label] = []
var _plate_status: Array[Label] = []
var _intent_box: PanelContainer
var _intent_label: Label
var _intent_when: Label
var _energy_label: Label
var _pile_label: Label
var _log: Label
var _end_button: Button
var _prompt: Label
var _help: Label
var _result: Control
var _result_label: Label
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _shake := 0.0


func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	sfx = Sfx.new()
	add_child(sfx)
	var you := Person.new()
	you.build(Color(0.16, 0.55, 0.58), Color(0.30, 0.24, 0.20), Color(0.20, 0.13, 0.08), Color(0.92, 0.75, 0.62), "sword", true)
	var bram := Person.new()
	bram.build(Color(0.80, 0.42, 0.20), Color(0.34, 0.26, 0.20), Color(0.42, 0.36, 0.32), Color(0.80, 0.60, 0.45), "wrench", false, true)
	var beetle := Beetle.new()
	units = [you, bram, beetle]
	for i in 3:
		add_child(units[i])
		units[i].position = HOME[i]
		units[i].rotation.y = PI / 2 if i == 2 else -PI / 2
	cam = Camera3D.new()
	cam.fov = 44
	cam.far = 900
	cam.position = Vector3(0.0, 4.4, 10.0)
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.5, -0.6))
	for i in 2:
		var tag := Label3D.new()
		tag.text = ["YOU", "BRAM"][i]
		tag.font_size = 40
		tag.outline_size = 10
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color(1, 1, 1, 0.8)
		tag.position = Vector3(0, 2.25, 0)
		units[i].add_child(tag)
	_make_ring()
	_make_ui()
	seed_value = int(Time.get_unix_time_from_system()) % 100000
	var args := OS.get_cmdline_user_args()
	var si := args.find("--seed")
	if si >= 0 and si + 1 < args.size():
		seed_value = int(args[si + 1])
	_play_events(rules.start(seed_value))


# ---------------------------------------------------------------- your moves

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_ESCAPE:
			if aiming >= 0:
				_cancel_aim()
			else:
				back_to_menu.emit()
		elif k == KEY_R and rules.result != "":
			restart.emit()
		elif k >= KEY_1 and k <= KEY_9:
			_click_card(k - KEY_1)
		elif k == KEY_SPACE or k == KEY_E or k == KEY_ENTER:
			_end_turn()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and aiming >= 0:
		_cancel_aim()


func _click_card(i: int) -> void:
	if busy or i < 0 or i >= rules.hand.size() or (aiming >= 0 and i != aiming):
		return
	var why := rules.cant_play(i)
	if why != "":
		_say("Can't play that: " + why)
		sfx.play("thud", -8.0)
		return
	if R.CARDS[rules.hand[i]]["aim"] == "ally":
		aiming = i
		_prompt.text = "Who for? Click You or Bram  (right click to cancel)"
		_prompt.visible = true
		_refresh()
		return
	_play_card(i, -1)


func _pick_target(who: int) -> void:
	if aiming < 0 or busy:
		return
	if not rules.alive(who):
		_say("%s is down" % R.NAMES[who])
		return
	var i := aiming
	_cancel_aim()
	_play_card(i, who)


func _cancel_aim() -> void:
	aiming = -1
	_prompt.visible = false
	_refresh()


func _play_card(i: int, target: int) -> void:
	sfx.play("card_play")
	_play_events(rules.play(i, target))


func _end_turn() -> void:
	if busy or rules.result != "":
		return
	_cancel_aim()
	_say("End of your turn")
	_play_events(rules.end_turn())


# ---------------------------------------------------------------- showing what happened

func _play_events(ev: Array) -> void:
	busy = true
	_refresh()
	var stepped := -1        # who stepped forward to attack (goes home afterwards)
	for e in ev:
		if not _still_here():
			return
		match e["t"]:
			"card":
				stepped = await _show_card(e)
			"hit":
				await _show_hit(e)
			"block":
				Fx.popup(self, units[e["who"]].position + Vector3(0, 1.5, 0.8), "+%d Block" % e["amount"], Color(0.55, 0.8, 1.0), 52)
				sfx.play("block")
				await _wait(0.35)
			"heal":
				Fx.popup(self, units[e["who"]].position + Vector3(0, 1.5, 0.8), "+%d" % e["amount"], Color(0.5, 1.0, 0.5), 60)
				Fx.burst(self, units[e["who"]].position + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.5), 14, 2.5)
				sfx.play("block", -4.0, 1.4)
				_say("Bram patches up " + ("you" if e["who"] == R.YOU else "himself"))
				await _wait(0.4)
			"cover":
				var t := create_tween()
				t.tween_property(units[R.BRAM], "position", HOME[R.YOU] + Vector3(1.1, 0, -0.2), 0.25)
				_say("Bram stands in front of you")
				await _wait(0.3)
			"dazzle":
				await _show_dazzle()
			"dazzle_gone":
				pass
			"beetle":
				if stepped >= 0:
					await _go_home(stepped)
					stepped = -1
				await _show_beetle(e)
			"covered":
				Fx.popup(self, units[R.BRAM].position + Vector3(0, 2.8, 0), "covered!", Color(1.0, 0.8, 0.5), 44)
			"shell":
				Fx.popup(self, units[R.BEETLE].position + Vector3(0, 2.8, 0), "+%d Shell" % e["amount"], Color(0.85, 0.65, 0.4), 56)
				units[R.BEETLE].flash(Color(0.9, 0.6, 0.3), 0.3)
				sfx.play("block", 0.0, 0.6)
				await _wait(0.4)
			"burrow":
				var b: Node3D = units[R.BEETLE]
				sfx.play("burrow")
				for k in 3:
					Fx.dust(self, b.position + Vector3(0, 0.3, 0), 16, 3.0)
				var t := create_tween()
				t.tween_property(b, "position:y", -2.4, 0.6)
				await t.finished
				b.visible = false
			"down":
				units[e["who"]].fall()
				_say("%s is down!" % R.NAMES[e["who"]])
				await _wait(0.6)
			"intent":
				pass
			"enrage":
				Fx.popup(self, units[R.BEETLE].position + Vector3(-1.8, 1.0, 1.6), "ENRAGED!", Color(1.0, 0.35, 0.25), 80)
				sfx.play("screech", 4.0, 0.8)
				_say("The beetle is enraged: its attacks hit harder")
				await _wait(0.6)
			"turn":
				if stepped >= 0:
					await _go_home(stepped)
					stepped = -1
				if units[R.BRAM].position != HOME[R.BRAM] and rules.alive(R.BRAM):
					create_tween().tween_property(units[R.BRAM], "position", HOME[R.BRAM], 0.3)
				_say("Turn %d: you have %d energy" % [e["turn"], T.B_ENERGY])
				for k in rules.hand.size():
					sfx.play("card", -2.0)
			"win":
				_end_screen(true)
			"lose":
				_end_screen(false)
	if stepped >= 0 and _still_here():
		await _go_home(stepped)
	if not _still_here():
		return
	busy = false
	_refresh()


func _show_card(e: Dictionary) -> int:
	var c: Dictionary = R.CARDS[e["id"]]
	var who: int = e["who"]
	var p: Node3D = units[who]
	_say("%s: %s" % ["You" if who == R.YOU else "Bram", c["name"]])
	if c["aim"] == "enemy" and e["id"] != "flash":
		var t := create_tween()
		t.tween_property(p, "position", HOME[R.BEETLE] + Vector3(-2.6, 0, 0.3 if who == R.YOU else -0.3), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p.move_speed = 6.0
		await t.finished
		p.move_speed = 0.0
		p.swing(2 if e["id"] == "smash" else 0, 0.3)
		sfx.play("swing")
		await _wait(0.12)
		return who
	if c["aim"] != "self":
		p.swing(1, 0.3)
	await _wait(0.15)
	return -1


func _go_home(who: int) -> void:
	var p: Node3D = units[who]
	var t := create_tween()
	t.tween_property(p, "position", HOME[who] if not (who == R.BRAM and rules.covered) else HOME[R.YOU] + Vector3(1.1, 0, -0.2), 0.25)
	await t.finished


func _show_hit(e: Dictionary) -> void:
	var who: int = e["who"]
	var u: Node3D = units[who]
	var top := u.position + Vector3(0, 2.0 if who == R.BEETLE else 1.7, 0.8)
	if who == R.BEETLE:
		if e.get("cracked", 0) > 0:
			Fx.popup(self, top + Vector3(0.6, 0.5, 0), "-%d Shell" % e["cracked"], Color(0.85, 0.65, 0.4), 44)
			Fx.burst(self, u.position + Vector3(-1.0, 1.4, 0), Color(0.4, 0.3, 0.2), 16, 5.0, 0.12, false)
			sfx.play("wrench")
		if e["dmg"] > 0:
			u.flash(Color(1.0, 0.8, 0.55), 0.2)
			_recoil(u, Vector3(0.5, 0, 0))
			Fx.burst(self, u.position + Vector3(-1.2, 1.3, 0), Color(1.0, 0.75, 0.35), 14, 5.0)
			Fx.popup(self, top, str(e["dmg"]), Color(1.0, 0.85, 0.4), 72)
			sfx.play("hit_big" if e["dmg"] >= 8 else "hit")
			_shake = 0.12
		if e["blocked"] > 0:
			Fx.popup(self, top + Vector3(-0.6, -0.4, 0), "shell soaks %d" % e["blocked"], Color(0.85, 0.65, 0.4), 36)
			if e["dmg"] == 0:
				sfx.play("block", 0.0, 0.7)
	else:
		if e["dmg"] > 0:
			u.flash(Color(1.0, 0.3, 0.2), 1.2)
			_recoil(u, Vector3(-0.6, 0, 0))
			Fx.popup(self, top, str(e["dmg"]), Color(1.0, 0.4, 0.3), 72)
			Fx.burst(self, u.position + Vector3(0, 1.2, 0), Color(1.0, 0.3, 0.2), 10, 4.0)
			sfx.play("hurt")
			_shake = 0.2
		if e["blocked"] > 0:
			Fx.popup(self, top + Vector3(0, 0.5, 0), "blocked %d" % e["blocked"], Color(0.55, 0.8, 1.0), 40)
			sfx.play("block")
	_refresh()
	await _wait(0.4)


func _show_dazzle() -> void:
	var you: Node3D = units[R.YOU]
	var l: OmniLight3D = you.lantern_light
	var t := create_tween()
	t.tween_property(l, "light_energy", 14.0, 0.08)
	t.tween_property(l, "light_energy", 2.2, 0.5)
	Fx.burst(self, you.position + Vector3(0.5, 1.0, 0), Color(1.0, 0.9, 0.6), 30, 7.0)
	sfx.play("swing", 0.0, 0.6)
	units[R.BEETLE].set_pose(0.2, 0.0, 0.3)
	Fx.popup(self, units[R.BEETLE].position + Vector3(0, 2.8, 0), "DAZZLED", Color(1.0, 0.95, 0.6), 56)
	_say("The lantern flash dazzles it: its next attack does half damage")
	await _wait(0.6)
	units[R.BEETLE].set_pose(0.0, 0.15, 1.0)


func _show_beetle(e: Dictionary) -> void:
	var b: Node3D = units[R.BEETLE]
	var id: String = e["id"]
	var target: int = e["target"]
	_say("The beetle: " + R.INTENTS[id]["name"])
	sfx.play("screech", 0.0, 1.2 if id == "snap" else 1.0)
	match id:
		"lunge", "snap":
			b.set_pose(0.6, 1.0, 3.0)
			await _wait(0.45)
			var aim: Vector3 = units[target].position if not (target == R.YOU and rules.covered) else units[R.BRAM].position
			var t := create_tween()
			t.tween_property(b, "position", aim + Vector3(2.6, 0, 0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			b.walk_speed = 9.0
			await t.finished
			sfx.play("beetle_step", 6.0)
			b.set_pose(-0.1, 0.0, 2.0)
			_shake = 0.2
			_slide_back_later(b)
		"sweep":
			b.set_pose(0.3, 1.0, 2.5)
			var t := create_tween()
			t.tween_property(b, "rotation:y", b.rotation.y + TAU, 0.5)
			for k in 4:
				Fx.dust(self, b.position + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)), 18, 5.0)
			sfx.play("burrow", 0.0, 1.3)
			await t.finished
			b.set_pose(0.0, 0.15, 1.0)
		"harden":
			b.set_pose(-0.2, 0.0, 1.5)
			await _wait(0.3)
			b.set_pose(0.0, 0.15, 1.0)
		"erupt":
			var aim: Vector3 = units[target].position if not (target == R.YOU and rules.covered) else units[R.BRAM].position
			b.position = aim + Vector3(1.6, -2.2, 0)
			b.visible = true
			var t := create_tween()
			t.tween_property(b, "position:y", 0.8, 0.15).set_ease(Tween.EASE_OUT)
			t.tween_property(b, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
			Fx.dust(self, aim + Vector3(1.0, 0.3, 0), 40, 7.0)
			sfx.play("burrow", 4.0, 0.8)
			_shake = 0.4
			await t.finished
			_slide_back_later(b)
		"burrow":
			b.set_pose(-0.3, 0.4, 1.5)
			await _wait(0.2)


## Knocked back a little by a hit, then back in place.
func _recoil(u: Node3D, push: Vector3) -> void:
	if busy and u == units[R.BEETLE] and u.position.distance_to(HOME[R.BEETLE]) > 0.3:
		return    # mid-attack: don't fight its own movement
	var home: Vector3 = u.position
	var t := create_tween()
	t.tween_property(u, "position", home + push, 0.06)
	t.tween_property(u, "position", home, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _left(i: int) -> String:
	return "%d/%d" % [rules.hp[i], rules.max_hp[i]] if rules.alive(i) else "went down"


## After an attack the beetle scuttles back to its spot (while the damage shows).
func _slide_back_later(b: Node3D) -> void:
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_property(b, "position", HOME[R.BEETLE], 0.5)
	t.tween_callback(func() -> void:
		b.walk_speed = 0.0
		b.set_pose(0.0, 0.15, 1.0))


## Waits s seconds. Uses a tween that belongs to this toy (not a scene-wide timer), so if you
## press Esc or R mid-animation and the toy is thrown away, the wait goes with it.
func _wait(s: float) -> void:
	if not _still_here():
		return
	var t := create_tween()
	t.tween_interval(s)
	await t.finished


## False once the toy has been closed (Esc or R) while an animation was still running.
func _still_here() -> bool:
	return is_instance_valid(self) and is_inside_tree()


func _say(text: String) -> void:
	_log.text = text


func _end_screen(won: bool) -> void:
	for i in 2:
		for c in units[i].get_children():
			if c is Label3D:
				c.visible = false
	for n in [_energy_label, _pile_label, _end_button, _help]:
		n.visible = false
	if won:
		var b: Node3D = units[R.BEETLE]
		b.visible = true          # always show it fall (it can't be beaten underground, but just in case)
		b.position.y = 0.0
		b.die()
		for i in [R.YOU, R.BRAM]:
			if rules.alive(i):
				units[i].cheer()
		create_tween().tween_callback(sfx.play.bind("win")).set_delay(0.6)
		_result_label.text = "THE BEETLE IS BEATEN!\nIn %d turns · You %s, Bram %s\n\nR: fight again    ·    Esc: back to the menu" % [
				rules.turn, _left(0), _left(1)]
	else:
		_result_label.text = "YOU BOTH WENT DOWN\nThe beetle had %d of %d health left\n\nR: fight again    ·    Esc: back to the menu" % [rules.hp[2], rules.max_hp[2]]
	_result.modulate.a = 0.0
	_result.visible = true
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_property(_result, "modulate:a", 1.0, 0.4)


# ---------------------------------------------------------------- screen

func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	cam.h_offset = randf_range(-1, 1) * _shake * 0.3
	cam.v_offset = randf_range(-1, 1) * _shake * 0.3
	# Plates sit at the top: you two on the left, the beetle and its plan on the right
	var w := get_viewport().get_visible_rect().size.x
	_plates[0].position = Vector2(30, 80)
	_plates[1].position = Vector2(30 + _plates[0].size.x + 14, 80)
	_plates[2].position = Vector2(w - 30 - _plates[2].size.x, 80)
	_intent_box.position = Vector2(w - 30 - _intent_box.size.x, 80 + _plates[2].size.y + 10)
	# The red ring under whoever the beetle is aiming at
	var tg: int = rules.intent.get("target", -1)
	_ring.visible = rules.result == "" and not rules.acted and tg >= 0 and not busy
	if _ring.visible:
		var who := tg
		if tg == R.YOU and rules.covered and rules.alive(R.BRAM):
			who = R.BRAM
		_ring.position = units[who].position + Vector3(0, 0.06, 0)
		_ring_mat.albedo_color.a = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	# Cards lift when the mouse is over them
	for i in _cards.size():
		var c := _cards[i]
		var lift := 26.0 if (i == hover or i == aiming) and not c.disabled else 0.0
		c.position.y = lerpf(c.position.y, _card_y() - lift, 1.0 - exp(-16.0 * delta))


func _card_y() -> float:
	return get_viewport().get_visible_rect().size.y - 262.0


func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.2
	tm.rings = 32
	_ring.mesh = tm
	_ring.scale = Vector3(1, 0.05, 1)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1.0, 0.15, 0.08, 0.5)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _text(parent: Node, s: String, size: int, colour := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _make_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_log = _text(_ui, "", 26)
	_log.anchor_right = 1.0
	_log.offset_top = 22
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 3:
		var pl := PanelContainer.new()
		pl.add_theme_stylebox_override("panel", _box(Color(0.05, 0.05, 0.07, 0.78), Color(0.3, 0.3, 0.35)))
		pl.custom_minimum_size = Vector2(250, 0)
		pl.mouse_filter = Control.MOUSE_FILTER_STOP if i < 2 else Control.MOUSE_FILTER_IGNORE
		if i < 2:
			pl.gui_input.connect(_plate_input.bind(i))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		pl.add_child(v)
		_text(v, ["YOU", "BRAM", "DUNE BEETLE"][i], 18)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0.2, 0.2, 0.22)
		bar_bg.custom_minimum_size = Vector2(230, 12)
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar_bg)
		var bar := ColorRect.new()
		bar.color = Color(0.85, 0.3, 0.18) if i == 2 else Color(0.35, 0.8, 0.4)
		bar.size = Vector2(230, 12)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.add_child(bar)
		_plate_bars.append(bar)
		_plate_text.append(_text(v, "", 18))
		_plate_status.append(_text(v, "", 16, Color(0.75, 0.85, 1.0)))
		_ui.add_child(pl)
		_plates.append(pl)
	_intent_box = PanelContainer.new()
	_intent_box.add_theme_stylebox_override("panel", _box(Color(0.25, 0.04, 0.03, 0.88), Color(0.9, 0.3, 0.2)))
	_intent_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var iv := VBoxContainer.new()
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_box.add_child(iv)
	_text(iv, "IT WILL:", 15, Color(1.0, 0.7, 0.6))
	_intent_label = _text(iv, "", 22)
	_intent_when = _text(iv, "", 17, Color(1.0, 0.85, 0.5))
	_ui.add_child(_intent_box)
	_energy_label = _text(_ui, "", 30, Color(1.0, 0.85, 0.4))
	_energy_label.anchor_top = 1.0
	_energy_label.anchor_bottom = 1.0
	_energy_label.offset_left = 40
	_energy_label.offset_top = -170
	_pile_label = _text(_ui, "", 16, Color(1, 1, 1, 0.7))
	_pile_label.anchor_top = 1.0
	_pile_label.anchor_bottom = 1.0
	_pile_label.offset_left = 40
	_pile_label.offset_top = -120
	_help = _text(_ui, "Click a card (or 1-5) to play it\nSpace: end turn   ·   Esc: menu", 16, Color(1, 1, 1, 0.6))
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 40
	_help.offset_top = -80
	_end_button = Button.new()
	_end_button.text = "END TURN"
	_end_button.add_theme_font_size_override("font_size", 26)
	_end_button.add_theme_stylebox_override("normal", _box(Color(0.35, 0.12, 0.08), Color(0.9, 0.5, 0.3)))
	_end_button.add_theme_stylebox_override("hover", _box(Color(0.5, 0.16, 0.10), Color(1.0, 0.7, 0.4)))
	_end_button.add_theme_stylebox_override("disabled", _box(Color(0.15, 0.12, 0.12), Color(0.3, 0.3, 0.3)))
	_end_button.anchor_left = 1.0
	_end_button.anchor_right = 1.0
	_end_button.anchor_top = 1.0
	_end_button.anchor_bottom = 1.0
	_end_button.offset_left = -230
	_end_button.offset_right = -40
	_end_button.offset_top = -150
	_end_button.offset_bottom = -80
	_end_button.pressed.connect(_end_turn)
	_ui.add_child(_end_button)
	_prompt = _text(_ui, "", 26, Color(0.6, 1.0, 0.6))
	_prompt.anchor_right = 1.0
	_prompt.offset_top = 62
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.visible = false
	_ui.add_child(_result)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.anchor_top = 0.3
	shade.anchor_bottom = 0.62
	shade.anchor_right = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(shade)
	_result_label = _text(_result, "", 46)
	_result_label.anchor_left = 0.0
	_result_label.anchor_right = 1.0
	_result_label.anchor_top = 0.3
	_result_label.anchor_bottom = 0.62
	_result_label.offset_left = 0
	_result_label.offset_right = 0
	_result_label.offset_top = 0
	_result_label.offset_bottom = 0
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _plate_input(event: InputEvent, who: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_target(who)


## Makes a card button for hand slot i.
func _make_card(i: int) -> Button:
	var id: String = rules.hand[i]
	var c: Dictionary = R.CARDS[id]
	var col: Color = OWNER_COLOURS[c["who"]]
	var b := Button.new()
	b.custom_minimum_size = Vector2(176, 244)
	b.size = b.custom_minimum_size
	b.add_theme_stylebox_override("normal", _box(col.darkened(0.35), col.lightened(0.25)))
	b.add_theme_stylebox_override("hover", _box(col.darkened(0.15), Color(1.0, 0.9, 0.6)))
	b.add_theme_stylebox_override("pressed", _box(col, Color(1.0, 0.9, 0.6)))
	b.add_theme_stylebox_override("disabled", _box(Color(0.12, 0.12, 0.13), Color(0.3, 0.3, 0.32)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 8
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	_text(top, str(c["cost"]), 34, Color(1.0, 0.85, 0.4))
	var owner_l := _text(top, "  " + ("YOU" if c["who"] == R.YOU else "BRAM"), 16, Color(1, 1, 1, 0.75))
	owner_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text(v, c["name"], 22)
	var body := _text(v, c["text"], 17, Color(0.92, 0.92, 0.9))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(150, 0)
	var key := _text(v, "[%d]" % (i + 1), 14, Color(1, 1, 1, 0.45))
	key.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	b.pressed.connect(_click_card.bind(i))
	b.mouse_entered.connect(func() -> void: hover = i)
	b.mouse_exited.connect(func() -> void:
		if hover == i:
			hover = -1)
	return b


## Brings everything on screen up to date with the rules.
func _refresh() -> void:
	# The hand
	if true:   # simplest: rebuild the hand every time
		for c in _cards:
			c.queue_free()
		_cards.clear()
		var w := get_viewport().get_visible_rect().size.x
		var gap := 14.0
		var total := rules.hand.size() * 176.0 + maxf(rules.hand.size() - 1, 0) * gap
		for i in rules.hand.size():
			var b := _make_card(i)
			b.position = Vector2(w * 0.5 - total * 0.5 + i * (176.0 + gap), _card_y())
			_ui.add_child(b)
			_cards.append(b)
	for i in _cards.size():
		_cards[i].disabled = rules.cant_play(i) != "" or (aiming >= 0 and i != aiming)
		_cards[i].mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
	_end_button.disabled = busy or rules.result != ""
	for c in _cards:
		c.visible = rules.result == ""
	_energy_label.text = "ENERGY  %d / %d" % [rules.energy, T.B_ENERGY]
	_pile_label.text = "draw pile %d   ·   used %d" % [rules.draw_pile.size(), rules.discard.size()]
	# The plates
	for i in 3:
		_plate_bars[i].size.x = 230.0 * rules.hp[i] / float(rules.max_hp[i])
		var line := "%d / %d" % [rules.hp[i], rules.max_hp[i]]
		if i < 2 and rules.block[i] > 0:
			line += "    Block %d" % rules.block[i]
		if i == 2 and rules.shell > 0:
			line += "    Shell %d" % rules.shell
		_plate_text[i].text = line
		var st := ""
		if i < 2 and not rules.alive(i):
			st = "DOWN"
		elif i == R.YOU and rules.covered:
			st = "Bram is covering you"
		elif i == 2 and rules.burrowed:
			st = "Underground: out of reach"
		elif i == 2 and rules.dazzled:
			st = "Dazzled: next attack halved"
		elif i == 2 and rules.enraged:
			st = "Enraged: +%d per hit" % R.ENRAGED_BONUS
		_plate_status[i].text = st
		_plates[i].add_theme_stylebox_override("panel", _box(Color(0.05, 0.05, 0.07, 0.78),
				Color(0.5, 1.0, 0.5) if (aiming >= 0 and i < 2) else Color(0.3, 0.3, 0.35)))
	# What the beetle will do
	if rules.intent.has("id"):
		_intent_label.text = rules.intent_text()
		var n := rules.cards_until_act()
		if rules.result != "":
			_intent_when.text = ""
		elif n == -1:
			_intent_when.text = "on your next turn (it already acted)"
		elif n == 0:
			_intent_when.text = "at the end of your turn"
		else:
			_intent_when.text = "after %d more card%s!" % [n, "" if n == 1 else "s"]
	_intent_box.visible = rules.result == ""
	_intent_box.reset_size()
