extends "res://panel_base.gd"
## THE MOOD PANEL (F5): the world's light and colour on sliders, with presets
## (golden hour, midday, soft morning, dusk, night). Everything changes live.
## "Save as default" makes the game start with this look (mood.json).

var mood: Node   # mood.gd
var _sliders := {}


func _init() -> void:
	title = "Mood and lighting   (F5 to close)"
	toggle_action = "mood"


func _build() -> void:
	header("Presets")
	var names: Array = mood.PRESETS.keys()
	var h1 := HBoxContainer.new()
	var h2 := HBoxContainer.new()
	_box.add_child(h1)
	_box.add_child(h2)
	for i in names.size():
		button(h1 if i < 3 else h2, names[i], _preset.bind(names[i]))
	header("Light")
	for k in mood.SLIDERS:
		var s: Array = mood.SLIDERS[k]
		_sliders[k] = slider(s[0], s[1], s[2], s[3], mood.values[k], _change.bind(k), s[4])
	button(_footer, "Save as default", _save)
	button(_footer, "Back to saved", _reload)
	button(_footer, "Close", set_open.bind(false))


func _change(v: float, k: String) -> void:
	mood.values[k] = v
	mood.apply()


## Moves the sliders (and the numbers beside them) to the current values.
func _sync() -> void:
	for k in _sliders:
		_sliders[k].set_value_no_signal(mood.values[k])
		_sliders[k].value_changed.emit(mood.values[k])


func _preset(name: String) -> void:
	mood.use_preset(name)
	_sync()
	note("%s. Save as default to keep it." % name)


func _save() -> void:
	mood.save()
	note("Saved. The game starts with this look next time.")


func _reload() -> void:
	mood._ready()
	_sync()
	note("Back to the saved look.")
