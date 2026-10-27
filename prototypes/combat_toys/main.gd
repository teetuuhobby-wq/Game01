extends Node
## THE MENU: pick which way to fight the dune beetle. Esc in a toy comes back here.
## Start a toy straight away with:  -- --toy action   or   -- --toy turns

const Arena := preload("res://arena.gd")
const Beetle := preload("res://beetle.gd")
const TOYS := {"action": "res://action.gd", "turns": "res://turns.gd"}

var current: Node
var _menu: Node3D
var _menu_cam: Camera3D
var _t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--toy")
	if i >= 0 and i + 1 < args.size() and TOYS.has(args[i + 1]):
		start(args[i + 1])
	else:
		show_menu()


func show_menu() -> void:
	_clear()
	_menu = Node3D.new()
	add_child(_menu)
	current = _menu
	_menu.add_child(Arena.new())
	var b := Beetle.new()
	b.position = Vector3(0, 0, 0)
	b.rotation.y = 0.6
	_menu.add_child(b)
	_menu_cam = Camera3D.new()
	_menu_cam.fov = 55
	_menu_cam.far = 900
	_menu.add_child(_menu_cam)
	var ui := CanvasLayer.new()
	_menu.add_child(ui)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(90, -230)
	box.add_theme_constant_override("separation", 18)
	ui.add_child(box)
	var title := Label.new()
	title.text = "ONE NIGHT, ONE BEETLE"
	title.add_theme_font_size_override("font_size", 54)
	_outline(title)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Two quick ways to fight the same desert creature.\nPlay both, then say which one you'd want more of."
	sub.add_theme_font_size_override("font_size", 22)
	_outline(sub)
	box.add_child(sub)
	box.add_child(_button("1   ACTION", "Real time. Read its wind-up, roll away, strike while it's stuck.", "action"))
	box.add_child(_button("2   TURN-BASED", "Cards, you and Bram. See what it will do next, and plan around it.", "turns"))
	var hint := Label.new()
	hint.text = "Esc in a fight comes back here.  Esc here quits."
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.7)
	_outline(hint)
	box.add_child(hint)


func _button(text: String, detail: String, toy: String) -> Button:
	var b := Button.new()
	b.text = text + "\n" + detail
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(640, 92)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(start.bind(toy))
	return b


func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)


func start(toy: String) -> void:
	_clear()
	current = load(TOYS[toy]).new()
	current.back_to_menu.connect(func() -> void: show_menu.call_deferred())
	current.restart.connect(func() -> void: start.call_deferred(toy))
	add_child(current)


func _clear() -> void:
	if current != null:
		current.queue_free()
		remove_child(current)
	current = null
	_menu = null


func _process(delta: float) -> void:
	if _menu != null and is_instance_valid(_menu_cam):
		_t += delta * 0.12
		_menu_cam.position = Vector3(sin(_t) * 9.0, 2.6, cos(_t) * 9.0)
		_menu_cam.look_at(Vector3(0, 1.0, -0.5))


func _unhandled_input(event: InputEvent) -> void:
	if _menu == null or not (event is InputEventKey) or not event.pressed:
		return
	match event.physical_keycode:
		KEY_1:
			start("action")
		KEY_2:
			start("turns")
		KEY_ESCAPE:
			get_tree().quit()
