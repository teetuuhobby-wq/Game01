extends Node
## USING THINGS with E: talk to people, read boards, sit down, look at things.
## Finds the nearest thing in reach (the named residents in world.cast_nodes, and the
## boards, seats and so on in world.interact_spots), shows "E: ..." and does it.
## Mira's errand comes first: when its valve or rain-catcher is in reach, E is the errand's.
## What people say lives in town_data.gd; which line comes next, in dialogue.gd.

const Town := preload("res://town_data.gd")
const Dialogue := preload("res://dialogue.gd")
const TALK_REACH := 2.4     # metres from a person you can talk to them
const THING_REACH := 1.7    # metres from a board, seat or the like
const SHOW_TIME := 9.0      # seconds a line stays up

var world: Node3D       # world.gd
var player: Node3D      # player.gd
var controls: Node      # controls.gd
var errand: Node        # errand.gd
var sfx: Node           # sfx.gd
var talk := Dialogue.new()
var target := {}        # what E would use right now ({} = nothing in reach)
var showing := ""       # id of what the panel shows ("" = closed)
var last_text := ""     # the last thing shown (tests read it)

var _panel: PanelContainer
var _who: Label
var _text: Label
var _prompt: Label
var _show_time := 0.0
var _show_at := Vector3.ZERO


func setup(w: Node3D, p: Node3D, c: Node, e: Node, s: Node) -> void:
	world = w
	player = p
	controls = c
	errand = e
	sfx = s
	_make_ui()


func _process(delta: float) -> void:
	if player.seated:
		target = {}
		_prompt.text = "E or walk: stand up"
		if controls.use_pressed or controls.move != Vector2.ZERO or player.bot_input != Vector2.ZERO:
			player.stand_up()
		_update_panel(delta)
		return
	target = {} if errand.busy_here() else find_target()
	_prompt.text = ("E: " + target["label"]) if not target.is_empty() else ""
	if not target.is_empty() and controls.use_pressed:
		use(target)
	_update_panel(delta)


## The best thing to use from where you stand: the nearest in reach, preferring what
## you're facing.
func find_target() -> Dictionary:
	var best := {}
	var best_score := INF
	var here: Vector3 = player.position
	var face: Vector3 = player.facing
	for id in world.cast_nodes:
		var node: Node3D = world.cast_nodes[id]
		var c: Dictionary = Town.CAST[id]
		var s := _score(here, face, node.position, TALK_REACH, 3.0) - 0.8   # people first: you came to the bar to talk
		if s < best_score:
			best_score = s
			best = {"kind": "talk", "id": id, "label": "talk to %s (%s)" % [c["name"], c["role"]], "pos": node.position}
	for spot in world.interact_spots:
		var s := _score(here, face, spot["pos"], spot.get("reach", THING_REACH), 2.0)
		if spot["kind"] == "sit":
			s += 0.3   # and a seat only when it's clearly the one you mean
		if s < best_score:
			best_score = s
			best = spot
	return best


func _score(here: Vector3, face: Vector3, at: Vector3, reach: float, max_dy: float) -> float:
	var d := at - here
	if absf(d.y) > max_dy:
		return INF
	d.y = 0.0
	var dist := d.length()
	if dist > reach:
		return INF
	var facing := face.dot(d.normalized()) if dist > 0.05 else 1.0
	return dist - 0.6 * facing


## Does it: says a line, opens a board, sits you down, or describes something.
func use(t: Dictionary) -> void:
	match t["kind"]:
		"talk":
			var c: Dictionary = Town.CAST[t["id"]]
			_show(t["id"], "%s, %s" % [c["name"], c["role"]], talk.next_line(t["id"], errand.step == errand.Step.DONE), t["pos"])
			sfx.play("tick", -6.0)
		"read":
			if showing == t["id"]:
				_close()
				return
			var b: Dictionary = Town.PLACES[t["id"]]
			_show(t["id"], b["title"], "\n".join(b["lines"]), t["pos"], 60.0)
			sfx.play("crate", -14.0)
		"look":
			_show(t["id"], "", Town.PLACES[t["id"]]["text"], t["pos"])
		"sit":
			# You get up again where you were standing, which you know is clear
			var stand: Vector3 = player.position
			var seat := Vector3(t["pos"].x, stand.y, t["pos"].z)
			player.sit(seat, t["face"], stand, -0.36 if t.get("soak", false) else 0.0)
			sfx.play("crate", -12.0)


func _show(id: String, who: String, text: String, at: Vector3, seconds := SHOW_TIME) -> void:
	showing = id
	last_text = text
	_who.text = who
	_who.visible = who != ""
	_text.text = text
	_panel.visible = true
	_show_time = seconds
	_show_at = at


func _close() -> void:
	showing = ""
	_panel.visible = false


func _update_panel(delta: float) -> void:
	if not _panel.visible:
		return
	_show_time -= delta
	var d: Vector3 = player.position - _show_at
	if _show_time <= 0.0 or Vector2(d.x, d.z).length() > 4.0:
		_close()


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_prompt.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.64
	_prompt.anchor_bottom = 0.64
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_prompt)
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.07, 0.05, 0.82)
	box.border_color = Color(0.85, 0.66, 0.35)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", box)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -430
	_panel.offset_right = 430
	_panel.offset_top = -250
	_panel.offset_bottom = -60
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	layer.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 20)
	_who.add_theme_color_override("font_color", Color(1.0, 0.80, 0.45))
	v.add_child(_who)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 21)
	_text.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(820, 0)
	v.add_child(_text)
