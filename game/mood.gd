extends Node
## MOOD: the light and colour of the world in a few plain values (sun height, warmth,
## glare, haze...). The mood panel (F5, mood_panel.gd) changes them live; "Save as
## default" writes mood.json, which the game loads at start. Presets are below.

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
	"Golden hour": {"sun_height": 28.0, "sun_turn": -30.0, "sun_warmth": 0.65, "sun_brightness": 2.0,
			"shadow_fill": 0.5, "shadow_warmth": 1.0, "sky_brightness": 1.0, "glare": 0.8, "haze": 0.001,
			"exposure": 1.0, "colour": 1.2, "contrast": 1.12, "miniature": 0.12},
	"Midday": {"sun_height": 65.0, "sun_turn": -30.0, "sun_warmth": 0.12, "sun_brightness": 1.6,
			"shadow_fill": 0.55, "shadow_warmth": 0.3, "sky_brightness": 1.0, "glare": 0.25, "haze": 0.0006,
			"exposure": 0.85, "colour": 1.1, "contrast": 1.08, "miniature": 0.1},
	"Soft morning": {"sun_height": 18.0, "sun_turn": 40.0, "sun_warmth": 0.35, "sun_brightness": 1.4,
			"shadow_fill": 0.75, "shadow_warmth": 0.5, "sky_brightness": 0.9, "glare": 0.45, "haze": 0.003,
			"exposure": 1.05, "colour": 1.05, "contrast": 1.0, "miniature": 0.12},
	"Dusk": {"sun_height": 7.0, "sun_turn": -30.0, "sun_warmth": 0.95, "sun_brightness": 1.3,
			"shadow_fill": 0.35, "shadow_warmth": 0.8, "sky_brightness": 0.55, "glare": 1.0, "haze": 0.002,
			"exposure": 1.0, "colour": 1.25, "contrast": 1.15, "miniature": 0.12},
	"Night": {"sun_height": 40.0, "sun_turn": 60.0, "sun_warmth": -0.8, "sun_brightness": 0.35,
			"shadow_fill": 0.22, "shadow_warmth": 0.0, "sky_brightness": 0.06, "glare": 1.1, "haze": 0.0015,
			"exposure": 1.1, "colour": 0.9, "contrast": 1.05, "miniature": 0.1},
}

var world: Node3D      # world.gd: its env, sun and sky_mat get changed
var camera: Camera3D   # for the miniature blur
var values := {}


func _ready() -> void:
	values = PRESETS["Golden hour"].duplicate()
	if FileAccess.file_exists(SAVED):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVED))
		if parsed is Dictionary:
			for k in parsed:
				if values.has(k):
					values[k] = float(parsed[k])
	apply()


func use_preset(name: String) -> void:
	values = PRESETS[name].duplicate()
	apply()


func save() -> void:
	var f := FileAccess.open(SAVED, FileAccess.WRITE)
	f.store_string(JSON.stringify(values, "\t", true))


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
	env.fog_density = values["haze"]
	env.fog_light_color = Color(0.96, 0.82, 0.66) * clampf(values["sky_brightness"], 0.1, 1.0)
	env.tonemap_exposure = values["exposure"]
	env.adjustment_saturation = values["colour"]
	env.adjustment_contrast = values["contrast"]
	if camera != null and camera.attributes is CameraAttributesPractical:
		camera.attributes.dof_blur_amount = values["miniature"]
