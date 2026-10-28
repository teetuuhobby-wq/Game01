extends Node
## THE DAY ON SCREEN: runs the day clock (day.gd) and shows it. The light follows the
## hour (mood.gd's DAY_LOOKS), lanterns and lit windows glow brighter from about half
## past five, the evening bell rings at six, the city slows to a stop and kneels for the
## night, and at seven the screen fades to dark: "Day 1 done", then the morning bell,
## and the city stands up and walks on. T jumps an hour ahead. A small clock sits in the
## top corner. The town's people follow the same clock (world/town_life.gd).
## Test options (after "--"): --hour 14.5 starts at that time; --freeze-clock stops the
## clock (T still works).
## The dusk look test (dusk.tscn) drives the light and the city itself, so there this
## stands aside (stand_aside()).

signal happened(what: String)   ## each of the clock's moments (see day.gd advance), for tests

const Day := preload("res://day.gd")
const T := preload("res://tuning.gd")

## How quickly the city may change pace and height when the clock jumps (T), per second,
## so it eases into the new time instead of snapping. The normal day is much slower.
const WALK_EASE := 0.3
const KNEEL_EASE := 0.12

var day := Day.new()
var world: Node3D      # world.gd
var mood: Node         # mood.gd
var sfx: Node          # sfx.gd
var controls: Node     # controls.gd
var active := true     # false: something else (the dusk test) drives the light and the city

var _layer: CanvasLayer
var _clock: Label
var _fade: ColorRect
var _card: Label
var _card_sub: Label
var _base_glow := 1.2  # how brightly the lamps glow by day (from the world's glow material)
var _veil := 0.0       # an extra fade to dark (fade_to), on top of the end of the day's


func setup(w: Node3D, m: Node, s: Node, c: Node) -> void:
	world = w
	mood = m
	sfx = s
	controls = c
	process_priority = -50   # after the controls, before the world moves
	_base_glow = world.mat_glow.emission_energy_multiplier
	var h := T.DAY_START_HOUR
	var args := OS.get_cmdline_user_args()
	var hi := args.find("--hour")
	if hi >= 0 and hi + 1 < args.size():
		h = args[hi + 1].to_float()
	day.frozen = "--freeze-clock" in args
	_make_ui()
	jump_to(h)


## Sets the clock to an hour straight away, with everything in place for it: the light,
## the city's pace and height, and every resident and market-goer where they'd be.
## (Starting the game, --hour, a replay's start, tests and screenshots.)
## snap false: only the clock jumps, and the town catches up as if T had been pressed.
func jump_to(h: float, d := -1, snap := true) -> void:
	day.set_time(h, d)
	_show(snap)


## Fades to dark, jumps the clock to an hour (everyone where they'd be then, nobody
## seen moving), and fades back in. run: the clock runs from there (else it stays as it was).
func fade_to(h: float, run := true) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_veil", 1.0, Day.FADE_SECONDS)
	tw.tween_callback(_jump_behind_veil.bind(h, run))
	tw.tween_property(self, "_veil", 0.0, Day.FADE_SECONDS)


func _jump_behind_veil(h: float, run: bool) -> void:
	jump_to(h)
	if run:
		day.frozen = false


## The dusk look test drives the light and the city itself.
func stand_aside() -> void:
	active = false
	_layer.visible = false


func _process(delta: float) -> void:
	if not active:
		return
	var events := []
	if controls.skip_hour:
		events.append_array(day.skip_hour())
	events.append_array(day.advance(delta))
	var snap := false
	for e in events:
		happened.emit(e)
		match e:
			"evening_bell":
				sfx.bell()
			"day_over":
				_card.text = "Day %d done" % day.day
			"new_day":
				snap = true          # the screen is dark: everyone and everything to the morning
				sfx.bell()           # the morning bell, as the picture fades in
	_show(snap)


## Puts the clock's time on the world. snap: straight away (nobody can see it happen);
## otherwise the city eases to its new pace and height.
func _show(snap: bool) -> void:
	var h := day.hour
	world.set_town_hour(h, snap)
	var walk := Day.walk_rate_at(h)
	var kneel := Day.kneel_at(h)
	if snap:
		world.walk_rate = walk
		world.kneel = kneel
	else:
		var dt := get_process_delta_time()
		world.walk_rate = move_toward(world.walk_rate, walk, WALK_EASE * dt)
		world.kneel = move_toward(world.kneel, kneel, KNEEL_EASE * dt)
	var evening := Day.evening_at(h)
	var glow := lerpf(_base_glow, T.EVENING_GLOW, evening)
	if absf(world.mat_glow.emission_energy_multiplier - glow) > 0.002:
		world.mat_glow.emission_energy_multiplier = glow   # only when it changes: the material is shared by every lamp
	world.set_evening_lamps(evening)
	mood.show_hour(h, snap)
	_clock.text = "Day %d  ·  %s" % [day.day, Day.clock_text(h)]
	var dark := maxf(day.darkness(), _veil)
	_fade.visible = dark > 0.0
	_fade.color.a = dark
	_card.visible = day.phase == Day.Phase.CARD or (day.phase == Day.Phase.FADE_OUT and dark > 0.6)
	_card_sub.visible = _card.visible


## The clock in the top corner, the black fade and the end-of-day card.
func _make_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 8   # over the game's text, under the F4 and F5 panels
	add_child(_layer)
	_clock = Label.new()
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -260
	_clock.offset_right = -20
	_clock.offset_top = 14
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.add_theme_font_size_override("font_size", 20)
	_clock.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 0.9))
	_clock.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
	_clock.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_clock)
	_fade = ColorRect.new()
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.color = Color(0.02, 0.02, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	_layer.add_child(_fade)
	_card = _centred_label(52, Color(1.0, 0.86, 0.55), -40)
	_card_sub = _centred_label(22, Color(0.85, 0.82, 0.78), 30)
	_card_sub.text = "The city kneels for the night. Morning comes."


func _centred_label(size: int, colour: Color, y: int) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.visible = false
	_layer.add_child(l)
	return l
