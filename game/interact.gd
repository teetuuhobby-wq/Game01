extends Node
## USING THINGS with E: talk to people, read boards, sit down, look at things.
## Finds the nearest thing in reach (the named residents in world.cast_nodes, and the
## boards, seats and so on in world.interact_spots), shows "E: ..." and does it.
## Mira's errand comes first: when its valve or rain-catcher is in reach, E is the errand's.
## The morning round (welcome.gd) hears everything you use, to know when a stop is done.
## What people say lives in town_data.gd; which line comes next, in dialogue.gd.
## At a place that's closed (day.gd), its people and its boards just say when it opens.

const Town := preload("res://town_data.gd")
const Dialogue := preload("res://dialogue.gd")
const Day := preload("res://day.gd")
const T := preload("res://tuning.gd")
const TALK_REACH: float = T.TALK_REACH     # metres from a person you can talk to them
const THING_REACH: float = T.THING_REACH   # metres from a board, seat or the like
const CLOSE_DISTANCE := 4.0                # walk this far from what you're reading and it closes

var world: Node3D       # world.gd
var player: Node3D      # player.gd
var controls: Node      # controls.gd
var errand: Node        # errand.gd
var sfx: Node           # sfx.gd
var welcome: Node = null   # welcome.gd, the morning round (null when it's off): it hears what you use
var talk := Dialogue.new()
var target := {}        # what E would use right now ({} = nothing in reach)
var showing := ""       # id of what the panel shows ("" = closed)
var last_text := ""     # the last thing shown (tests read it)

var _panel: PanelContainer
var _who: Label
var _text: Label
var _hint: Label         # "E: next" / "E: close", inside the panel
var _prompt: Label
var _marker: MeshInstance3D   # a small diamond over what E would use
var _last_id := ""            # last frame's target, kept unless something is clearly better
var _t := 0.0
var _wait_release := false    # just sat down holding a walk key: don't stand until it's let go
var _show_time := 0.0
var _show_at := Vector3.ZERO


func setup(w: Node3D, p: Node3D, c: Node, e: Node, s: Node) -> void:
	world = w
	player = p
	controls = c
	errand = e
	sfx = s
	_make_ui()
	_make_marker()


func _process(delta: float) -> void:
	_t += delta
	if player.seated:
		target = {}
		_prompt.text = "E or walk: stand up"
		var walking: bool = controls.move != Vector2.ZERO or player.bot_input != Vector2.ZERO
		if not walking:
			_wait_release = false
		if controls.use_pressed or (walking and not _wait_release):
			player.stand_up()
			sfx.play("crate", -16.0)
		_update_panel(delta)
		_update_marker()
		return
	target = {} if errand.busy_here() else find_target()
	_last_id = target.get("id", "")
	# While a panel is open the hint inside it says what E does; no second prompt on top
	_prompt.text = ("E: " + target["label"]) if not target.is_empty() and not _panel.visible else ""
	if _panel.visible:
		var same: bool = target.get("id", "") == showing
		_hint.text = ("E: keep talking" if target.get("kind", "") == "talk" else "E: close") if same else ""
	if not target.is_empty() and controls.use_pressed:
		use(target)
	_update_panel(delta)
	_update_marker()


## The best thing to use from where you stand: the nearest in reach, preferring what
## you're facing.
func find_target() -> Dictionary:
	var best := {}
	var best_score := INF
	var here: Vector3 = player.position
	var face: Vector3 = player.facing
	var inside: String = world.facility_at(here)
	for id in world.cast_nodes:
		if world.cast_away.has(id):
			continue   # at home, indoors
		var node: Node3D = world.cast_nodes[id]
		var c: Dictionary = Town.CAST[id]
		var s := _score(here, face, node.position, TALK_REACH, 3.0, id) - 0.5   # people first: you came to the bar to talk
		if s < best_score and _same_room(node.position, inside):   # never through a wall
			best_score = s
			best = {"kind": "talk", "id": id, "label": "talk to %s (%s)" % [c["name"], c["role"]], "pos": node.position,
					"height": 2.3 * node.scale.y}
	for spot in world.interact_spots:
		if spot["where"] != inside:
			continue   # boards and seats work from the same room only, never through a wall
		var s := _score(here, face, spot["pos"], spot.get("reach", THING_REACH), 2.0, spot["id"])
		if spot["kind"] == "sit":
			s += 0.3   # and a seat only when it's clearly the one you mean
		if s < best_score:
			best_score = s
			best = spot
	return best


## People you can talk to: in the same room as you (or both outside), never through a
## wall. A place with an open front (Bram's workshop) counts as outside for this, so
## you can talk to Bram from the street in front of it.
func _same_room(at: Vector3, inside: String) -> bool:
	var there: String = world.facility_at(at)
	return there == inside or _open_front(there) or _open_front(inside)


func _open_front(kind: String) -> bool:
	return world.facilities.get(kind, {}).get("open", false)


func _score(here: Vector3, face: Vector3, at: Vector3, reach: float, max_dy: float, id := "") -> float:
	var d := at - here
	if absf(d.y) > max_dy:
		return INF
	d.y = 0.0
	var dist := d.length()
	if dist > reach:
		return INF
	var facing := face.dot(d.normalized()) if dist > 0.05 else 1.0
	return dist - 0.6 * facing - (0.25 if id != "" and id == _last_id else 0.0)


## Does it: says a line, opens a board, sits you down, or describes something.
## The morning round hears about it afterwards (and may give a resident a line of its own).
func use(t: Dictionary) -> void:
	_do(t)
	if welcome != null:
		welcome.used(t)


func _do(t: Dictionary) -> void:
	match t["kind"]:
		"talk":
			var c: Dictionary = Town.CAST[t["id"]]
			var round_line: String = welcome.talk_line(t["id"]) if welcome != null else ""
			if round_line != "":
				_show(t["id"], "%s, %s" % [c["name"], c["role"]], round_line, t["pos"])
				sfx.play("tick", -6.0)
				return
			var shut := _closed_line(world.resident_place(t["id"]), c["where"])
			if shut != "":
				_show(t["id"], "%s, %s" % [c["name"], c["role"]], shut, t["pos"])
				sfx.play("tick", -6.0)
				return
			var done: bool = errand.step == errand.Step.DONE
			var on: bool = welcome == null or not welcome.before_errand()   # no valve talk before the errand starts
			var line := talk.next_line(t["id"], done, on)
			var n: int = talk.lines_for(t["id"], done, on).size()
			var k: int = talk.said_count(t["id"], n)
			_show(t["id"], "%s, %s   (%d/%d)" % [c["name"], c["role"], k, n], line, t["pos"])
			sfx.play("tick", -6.0)
		"read":
			if showing == t["id"]:
				_close()
				return
			var b: Dictionary = Town.PLACES[t["id"]]
			var shut := _closed_line(t["where"], t["where"])
			if shut != "":
				_show(t["id"], b["title"], shut, t["pos"])
			else:
				_show(t["id"], b["title"], "\n".join(b["lines"]), t["pos"], 60.0)
			sfx.play("crate", -14.0)
		"look":
			if showing == t["id"]:
				_close()
				return
			_show(t["id"], "", Town.PLACES[t["id"]]["text"], t["pos"])
			sfx.play("chime", -16.0)
		"sit":
			# You get up again where you were standing, which you know is clear
			var stand: Vector3 = player.position
			var seat := Vector3(t["pos"].x, stand.y, t["pos"].z)
			player.sit(seat, t["face"], stand, -0.36 if t.get("soak", false) else 0.0)
			_wait_release = controls.move != Vector2.ZERO or player.bot_input != Vector2.ZERO
			sfx.play("crate", -12.0)


## When someone is at their own place (or you read a board there) and it's closed:
## the line saying when it opens. Otherwise "".
func _closed_line(here: String, own: String) -> String:
	if here == "" or here != own or not Day.has_hours(here) or Day.is_open(here, world.town_hour):
		return ""
	return Day.closed_line(here, world.town_hour)


func _show(id: String, who: String, text: String, at: Vector3, seconds := -1.0) -> void:
	showing = id
	last_text = text
	_who.text = who
	_who.visible = who != ""
	_text.text = text
	_hint.text = ""
	_panel.visible = true
	_show_time = seconds if seconds > 0.0 else T.TEXT_SECONDS + T.TEXT_SECONDS_PER_LETTER * text.length()   # long lines stay longer
	_show_at = at
	_fit_panel()


## The panel hugs its text, sitting just above the key hints at the bottom.
func _fit_panel() -> void:
	_panel.reset_size()
	var h := _panel.get_combined_minimum_size().y
	_panel.offset_top = -60.0 - h
	_panel.offset_bottom = -60.0


func _close() -> void:
	showing = ""
	_panel.visible = false


func _update_panel(delta: float) -> void:
	if not _panel.visible:
		return
	_show_time -= delta
	var d: Vector3 = player.position - _show_at
	if _show_time <= 0.0 or Vector2(d.x, d.z).length() > CLOSE_DISTANCE:
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
	_panel.offset_top = -160
	_panel.offset_bottom = -60
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
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 0.8))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)


## A small gold diamond that bobs over whatever E would use right now.
func _make_marker() -> void:
	_marker = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.14
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.no_depth_test = true
	m.material = mat
	_marker.mesh = m
	_marker.visible = false
	world.city.add_child(_marker)


func _update_marker() -> void:
	_marker.visible = not target.is_empty() and not _panel.visible
	if not _marker.visible:
		return
	var up: float = target.get("height", 1.0 if target.get("kind", "") != "sit" else 0.9)
	var at: Vector3 = target["pos"]
	if target.get("kind", "") == "talk":
		at = world.cast_nodes[target["id"]].position
	# Up close it sits at chest height and smaller, so it stays in view
	var d := Vector2(at.x - player.position.x, at.z - player.position.z).length()
	if d < 1.5:
		up = minf(up, 1.2)
	_marker.scale = Vector3.ONE * clampf(d / 1.5, 0.5, 1.0)
	_marker.position = at + Vector3(0, up + sin(_t * 3.0) * 0.06, 0)
	_marker.rotation = Vector3(PI / 4.0, _t * 2.0, PI / 4.0)
