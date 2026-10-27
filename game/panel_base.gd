extends CanvasLayer
## A panel of buttons and sliders over the game (the sound board and the mood panel).
## Its key opens and closes it. While it's open the mouse is free for clicking (you
## can still walk with the keys, and the mouse wheel scrolls the panel instead of
## zooming), and Esc closes it.

var controls: Node          # controls.gd
var toggle_action := ""     # the key's action name, set by each panel
var title := ""

var _root: PanelContainer
var _box: VBoxContainer     # rows go in here
var _footer: HBoxContainer  # buttons along the bottom
var _note: Label            # a short message, e.g. "Saved"


func _ready() -> void:
	layer = 10
	add_to_group("game_panels")
	_root = PanelContainer.new()
	_root.anchor_left = 1.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = -480
	_root.offset_right = -12
	_root.offset_top = 12
	_root.offset_bottom = -48
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.07, 0.05, 0.88)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(12)
	_root.add_theme_stylebox_override("panel", bg)
	add_child(_root)
	var v := VBoxContainer.new()
	_root.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	v.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	_note = Label.new()
	_note.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	v.add_child(_note)
	_footer = HBoxContainer.new()
	v.add_child(_footer)
	_root.visible = false
	_build()


## Filled in by each panel: add its rows and buttons.
func _build() -> void:
	pass


## Called when the panel opens or closes.
func _on_open(_on: bool) -> void:
	pass


func is_open() -> bool:
	return _root.visible


func set_open(on: bool) -> void:
	_root.visible = on
	var any := false
	for p in get_tree().get_nodes_in_group("game_panels"):
		any = any or p.is_open()
	controls.menu_open = any
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_note.text = ""
	_on_open(on)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		set_open(not is_open())
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("quit"):
		set_open(false)
		get_viewport().set_input_as_handled()


func clear_rows() -> void:
	for c in _box.get_children():
		c.queue_free()
	for c in _footer.get_children():
		c.queue_free()


func note(text: String) -> void:
	_note.text = text


# ---------- Building blocks for rows ----------

func header(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	_box.add_child(l)


## A row: a label on the left (it stretches), then whatever is added to the returned row.
func row(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 110
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	_box.add_child(h)
	return h


## A slider with its value shown next to it; on_change(value) runs as you drag.
func slider(text: String, lo: float, hi: float, step: float, value: float, on_change: Callable, fmt := "%.2f") -> HSlider:
	var h := row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size.x = 220
	s.focus_mode = Control.FOCUS_NONE
	var shown := Label.new()
	shown.custom_minimum_size.x = 70
	shown.text = fmt % value
	s.value_changed.connect(func(v: float) -> void:
		shown.text = fmt % v
		on_change.call(v))
	h.add_child(s)
	h.add_child(shown)
	return s


## A drop-down list; on_change(item) runs when you pick one.
func option(h: HBoxContainer, items: Array, selected: String, on_change: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size.x = 200
	o.clip_text = true
	for i in items.size():
		o.add_item(str(items[i]))
		if str(items[i]) == selected:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: on_change.call(items[i]))
	h.add_child(o)
	return o


func button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b
