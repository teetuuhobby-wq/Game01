extends CanvasLayer
## THE ESC MENU (playtest 4: "I'm going to want a volume slider"): Esc pauses the game
## and opens it; Esc again, or Resume, carries on. Volume (remembered between sessions,
## in the player's own folder: user://options.cfg), quality (the same as F6) and Quit.
## The F4/F5 panels handle Esc themselves first; this only gets Esc when none is open.

const OPTIONS := "user://options.cfg"

var controls: Node     # controls.gd
var quality: Node      # quality.gd
var sfx: Node          # sfx.gd: keeps playing while paused, so you hear the volume change
var volume := 1.0      # 0..1, the whole game's loudness

var _root: Control
var _quality_btn: Button
var _vol_label: Label
var _had_mouse := false


func setup(c: Node, q: Node, s: Node) -> void:
	controls = c
	quality = q
	sfx = s
	process_mode = Node.PROCESS_MODE_ALWAYS   # it works while the game is paused
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12   # over everything, the F4/F5 panels too
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS) == OK:
		volume = clampf(float(cfg.get_value("sound", "volume", 1.0)), 0.0, 1.0)
	_set_volume(volume)
	_make_ui()


func is_open() -> bool:
	return _root.visible


func set_open(on: bool) -> void:
	if on == is_open():
		return
	_root.visible = on
	get_tree().paused = on
	controls.menu_open = on   # clicks are for the menu, not for grabbing the mouse
	if on:
		_had_mouse = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_quality_btn.text = "Quality: %s  (F6)" % quality.level.capitalize()
	elif _had_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit") and not controls.typing:
		set_open(not is_open())
		get_viewport().set_input_as_handled()


func _set_volume(v: float) -> void:
	volume = v
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.0)


func _on_volume(v: float) -> void:
	_set_volume(v / 100.0)
	_vol_label.text = "%d%%" % roundi(v)
	var cfg := ConfigFile.new()
	cfg.load(OPTIONS)
	cfg.set_value("sound", "volume", volume)
	cfg.save(OPTIONS)


func _on_quality() -> void:
	quality.set_level("high" if quality.level == "low" else "low")
	_quality_btn.text = "Quality: %s  (F6)" % quality.level.capitalize()


func _make_ui() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -128
	panel.offset_bottom = 128
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.07, 0.05, 0.92)
	bg.border_color = Color(0.85, 0.66, 0.35)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", bg)
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Strider Home"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	v.add_child(title)
	_button(v, "Resume  (Esc)", set_open.bind(false))
	var row := HBoxContainer.new()
	var vl := Label.new()
	vl.text = "Volume"
	vl.custom_minimum_size.x = 80
	row.add_child(vl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 5.0
	s.value = roundf(volume * 100.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(_on_volume)
	row.add_child(s)
	_vol_label = Label.new()
	_vol_label.text = "%d%%" % roundi(volume * 100.0)
	_vol_label.custom_minimum_size.x = 56
	_vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_vol_label)
	v.add_child(row)
	_quality_btn = _button(v, "Quality", _on_quality)
	_button(v, "Quit", get_tree().quit)


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size.y = 40
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b
