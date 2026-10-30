extends Node
## MOOD: the light and colour of the world in a few plain values (sun height, warmth,
## glare, haze...). The mood panel (F5, mood_panel.gd) changes them live; "Save as
## default" writes mood.json, which the game loads at start. Presets are below.
## The light follows the time of day (DAY_LOOKS below, blended by day_view.gd) until
## you touch the mood panel; its "Follow the day" button hands the light back to the clock.

const SAVED := "res://mood.json"

## key: [label, lowest, highest, step, shown as]
const SLIDERS := {
	"sun_height": ["Sun height", -10.0, 85.0, 1.0, "%.0f°"],
	"sun_turn": ["Sun direction", -180.0, 180.0, 1.0, "%.0f°"],
	"sun_warmth": ["Sun warmth", -1.0, 1.0, 0.01, "%+.2f"],
	"sun_brightness": ["Sun brightness", 0.0, 4.0, 0.05, "%.2f"],
	"shadow_fill": ["Shadow fill", 0.0, 1.5, 0.01, "%.2f"],
	"shadow_warmth": ["Shadow warmth", 0.0, 1.0, 0.01, "%.2f"],
	"sky_brightness": ["Sky brightness", 0.02, 1.5, 0.01, "%.2f"],
	"glare": ["Glare (glow)", 0.0, 2.0, 0.02, "%.2f"],
	"haze": ["Haze", 0.0, 0.01, 0.0001, "%.4f"],
	"exposure": ["Exposure", 0.3, 2.0, 0.01, "%.2f"],
	"colour": ["Colour strength", 0.0, 2.0, 0.01, "%.2f"],
	"contrast": ["Contrast", 0.5, 1.6, 0.01, "%.2f"],
	"miniature": ["Miniature blur", 0.0, 0.3, 0.005, "%.3f"],
}

const PRESETS := {
	# Softer than before (polish pass): less glare and burned-out highlights on sunny walls
	"Golden hour": {"sun_height": 28.0, "sun_turn": -30.0, "sun_warmth": 0.6, "sun_brightness": 1.65,
			"shadow_fill": 0.6, "shadow_warmth": 1.0, "sky_brightness": 0.95, "glare": 0.4, "haze": 0.0006,
			"exposure": 0.95, "colour": 1.12, "contrast": 1.06, "miniature": 0.1},
	# The original golden hour, kept to compare
	"Golden hour (strong)": {"sun_height": 28.0, "sun_turn": -30.0, "sun_warmth": 0.65, "sun_brightness": 2.0,
			"shadow_fill": 0.5, "shadow_warmth": 1.0, "sky_brightness": 1.0, "glare": 0.8, "haze": 0.001,
			"exposure": 1.0, "colour": 1.2, "contrast": 1.12, "miniature": 0.12},
	"Midday": {"sun_height": 65.0, "sun_turn": -30.0, "sun_warmth": 0.12, "sun_brightness": 1.6,
			"shadow_fill": 0.55, "shadow_warmth": 0.3, "sky_brightness": 1.0, "glare": 0.25, "haze": 0.0006,
			"exposure": 0.85, "colour": 1.1, "contrast": 1.08, "miniature": 0.1},
	# The first light of the day (7:00): a low, pale sun, cool blue shadows, a little dimmer
	"Dawn": {"sun_height": 8.0, "sun_turn": 55.0, "sun_warmth": 0.3, "sun_brightness": 1.1,
			"shadow_fill": 0.5, "shadow_warmth": 0.0, "sky_brightness": 0.7, "glare": 0.5, "haze": 0.0018,
			"exposure": 0.9, "colour": 0.95, "contrast": 1.02, "miniature": 0.12},
	"Soft morning": {"sun_height": 18.0, "sun_turn": 40.0, "sun_warmth": 0.35, "sun_brightness": 1.4,
			"shadow_fill": 0.75, "shadow_warmth": 0.5, "sky_brightness": 0.9, "glare": 0.45, "haze": 0.003,
			"exposure": 1.05, "colour": 1.05, "contrast": 1.0, "miniature": 0.12},
	"Dusk": {"sun_height": 7.0, "sun_turn": -30.0, "sun_warmth": 0.95, "sun_brightness": 1.3,
			"shadow_fill": 0.35, "shadow_warmth": 0.8, "sky_brightness": 0.55, "glare": 1.0, "haze": 0.002,
			"exposure": 1.0, "colour": 1.25, "contrast": 1.15, "miniature": 0.12},
	# The end of the day, as night falls: cool blue, warm windows (the dusk test's Blue hour,
	# part way from its sunset to its night)
	# (exposure kept near 1: higher made the lamp-lit doorways brighter than at dusk)
	"Nightfall": {"sun_height": -3.0, "sun_turn": -40.0, "sun_warmth": -0.5, "sun_brightness": 0.28,
			"shadow_fill": 0.26, "shadow_warmth": 0.0, "sky_brightness": 0.16, "glare": 1.1, "haze": 0.0022,
			"exposure": 1.05, "colour": 0.98, "contrast": 1.05, "miniature": 0.1},
	"Night": {"sun_height": 40.0, "sun_turn": 60.0, "sun_warmth": -0.8, "sun_brightness": 0.35,
			"shadow_fill": 0.22, "shadow_warmth": 0.0, "sky_brightness": 0.06, "glare": 1.1, "haze": 0.0015,
			"exposure": 1.1, "colour": 0.9, "contrast": 1.05, "miniature": 0.1},
}

## The light over the day: [hour, preset]. In between, the light changes gradually
## from one to the next. If you saved your own look (F5, "Save as default"), it takes
## the place of Golden hour.
const DAY_LOOKS := [[7.0, "Dawn"], [8.5, "Soft morning"], [12.0, "Midday"], [16.0, "Golden hour"], [18.5, "Dusk"], [19.0, "Nightfall"]]

var world: Node3D      # world.gd: its env, sun and sky_mat get changed
var camera: Camera3D   # for the miniature blur
var values := {}
var saved := {}        # your saved look (mood.json), or empty
var follow_day := true # the light follows the clock; false once you change it in the mood panel
var day_hour := -1.0   # the hour the light was last set for (day_view.gd)
var least_haze := 0.0  # low quality (quality.gd) needs at least this much haze
var _blur: CameraAttributesPractical   # the camera's blur settings, kept even while low quality takes them off it


func _ready() -> void:
	values = PRESETS["Golden hour"].duplicate()
	saved = {}
	var from := save_spot() if FileAccess.file_exists(save_spot()) else SAVED   # a shared build's own save first
	if FileAccess.file_exists(from):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(from))
		if parsed is Dictionary:
			for k in parsed:
				if values.has(k):
					values[k] = float(parsed[k])
			saved = values.duplicate()
	apply()


## The look for an hour of the day: the two DAY_LOOKS either side of it, blended.
func day_look(h: float) -> Dictionary:
	var keys := DAY_LOOKS
	if h <= keys[0][0]:
		return _look(keys[0][1]).duplicate()
	for i in range(1, keys.size()):
		if h < keys[i][0]:
			var f := smoothstep(keys[i - 1][0], keys[i][0], h)
			var a := _look(keys[i - 1][1])
			if f <= 0.0:
				return a.duplicate()
			var b := _look(keys[i][1])
			var out := {}
			for k in a:
				out[k] = lerpf(a[k], b[k], f)
			return out
	return _look(keys[keys.size() - 1][1]).duplicate()


func _look(name: String) -> Dictionary:
	if name == "Golden hour" and not saved.is_empty():
		return saved
	return PRESETS[name]


## The clock moved on (day_view.gd): while the light follows the day, it changes with it.
func show_hour(h: float, force := false) -> void:
	if not follow_day:
		day_hour = h   # remembered, so "Follow the day" picks up the right hour
		return
	if not force and absf(h - day_hour) < 0.0004:
		return
	day_hour = h
	values = day_look(h)
	apply()


## "Follow the day" (mood panel): the light goes back to the clock's.
func follow() -> void:
	follow_day = true
	if day_hour >= 0.0:
		show_hour(day_hour, true)


func use_preset(name: String) -> void:
	values = PRESETS[name].duplicate()
	apply()


func save() -> void:
	var f := FileAccess.open(save_spot(), FileAccess.WRITE)
	f.store_string(JSON.stringify(values, "\t", true))


## Where "Save as default" writes: next to the game's files while we work on it (so it
## goes in git), or the player's own folder (user://) in a shared build, which can't
## change its own files.
func save_spot() -> String:
	return "user://" + SAVED.get_file() if OS.has_feature("template") else SAVED


## The sun's colour: white at 0, golden toward +1, moonlight blue toward -1.
func _sun_colour(w: float) -> Color:
	if w >= 0.0:
		return Color(1, 1, 1).lerp(Color(1.0, 0.62, 0.36), w)
	return Color(1, 1, 1).lerp(Color(0.55, 0.68, 1.0), -w)


func apply() -> void:
	var env: Environment = world.env
	var sun: DirectionalLight3D = world.sun
	sun.rotation_degrees = Vector3(-values["sun_height"], values["sun_turn"], 0.0)
	sun.light_color = _sun_colour(values["sun_warmth"])
	sun.light_energy = values["sun_brightness"]
	env.ambient_light_energy = values["shadow_fill"]
	env.ambient_light_color = Color(0.55, 0.66, 0.82).lerp(Color(0.62, 0.48, 0.40), values["shadow_warmth"])
	world.sky_mat.energy_multiplier = values["sky_brightness"]
	env.glow_intensity = values["glare"]
	env.fog_density = maxf(values["haze"], least_haze)
	env.fog_light_color = Color(0.96, 0.82, 0.66) * clampf(values["sky_brightness"], 0.1, 1.0)
	env.tonemap_exposure = values["exposure"]
	env.adjustment_saturation = values["colour"]
	env.adjustment_contrast = values["contrast"]
	# Low quality takes the blur settings off the camera, so hold on to them the first
	# time and keep setting them: switching back to high then shows the latest blur.
	if _blur == null and camera != null and camera.attributes is CameraAttributesPractical:
		_blur = camera.attributes
	if _blur != null:
		_blur.dof_blur_amount = values["miniature"]
