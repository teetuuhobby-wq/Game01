extends Node
## CONTROLS: reads your keys and mouse once per frame into one simple snapshot that
## the player, camera and errand all use. Playtests record these snapshots, and a
## replay feeds them back in, so Claude can watch a session again exactly.
## Mouse look starts when you click in the window; Esc frees the mouse again.

const T := preload("res://tuning.gd")

# This frame's snapshot
var move := Vector2.ZERO      # WASD / arrows: x = right, y = back
var run := false
var use_held := false
var use_pressed := false      # E pressed this very frame
var look := Vector2.ZERO      # mouse movement this frame, in pixels
var zoom_steps := 0.0         # mouse wheel and + / - (positive = zoom out)
var turn := 0.0               # Z / X keys, -1 to 1
var flag_pressed := false     # F2 pressed this frame

var typing := false           # the F2 note box is open: game keys are ignored
var menu_open := false        # a panel (sound board, mood) is open: clicks and the wheel are for it
var replaying := false        # a replay is setting the snapshot instead of the keyboard

var _mouse := Vector2.ZERO
var _wheel := 0.0


func _ready() -> void:
	process_priority = -100   # before everything that reads the snapshot


func _input(event: InputEvent) -> void:
	if replaying:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_mouse += event.relative
	elif event is InputEventMouseButton and event.pressed and not menu_open:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel -= 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel += 1.0
		elif event.button_index == MOUSE_BUTTON_LEFT and T.MOUSE_LOOK and not typing:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if replaying:
		return
	clear()
	if typing:
		_mouse = Vector2.ZERO
		_wheel = 0.0
		return
	move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	run = Input.is_action_pressed("run")
	use_held = Input.is_action_pressed("interact")
	use_pressed = Input.is_action_just_pressed("interact")
	look = _mouse
	zoom_steps = _wheel + (Input.get_action_strength("zoom_out") - Input.get_action_strength("zoom_in")) * delta * 8.6
	turn = Input.get_action_strength("turn_right") - Input.get_action_strength("turn_left")
	flag_pressed = Input.is_action_just_pressed("flag")
	_mouse = Vector2.ZERO
	_wheel = 0.0


func clear() -> void:
	move = Vector2.ZERO
	run = false
	use_held = false
	use_pressed = false
	look = Vector2.ZERO
	zoom_steps = 0.0
	turn = 0.0
	flag_pressed = false


# ---------- Recording and replaying (one line of inputs.csv per frame) ----------

const HEADER := "frame,delta,move_x,move_y,run,use_held,use_pressed,look_x,look_y,zoom,turn,flag"


func to_row(frame: int, delta: float) -> String:
	return "%d,%.10f,%.4f,%.4f,%d,%d,%d,%.3f,%.3f,%.5f,%.4f,%d" % [frame, delta, move.x, move.y,
			int(run), int(use_held), int(use_pressed), look.x, look.y, zoom_steps, turn, int(flag_pressed)]


## Sets the snapshot from a recorded line. Returns that frame's delta.
func from_row(cols: PackedStringArray) -> float:
	move = Vector2(cols[2].to_float(), cols[3].to_float())
	run = cols[4] == "1"
	use_held = cols[5] == "1"
	use_pressed = cols[6] == "1"
	look = Vector2(cols[7].to_float(), cols[8].to_float())
	zoom_steps = cols[9].to_float()
	turn = cols[10].to_float()
	flag_pressed = false   # a replay never opens the note box
	return cols[1].to_float()
