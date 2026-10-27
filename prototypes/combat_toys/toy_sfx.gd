extends Node
## SOUNDS for both fights: recorded CC0 sounds from Kenney's packs (see audio/CREDITS.md),
## each played with a little random pitch so repeats don't sound identical.

## name: [files in audio/, volume (dB), pitch from, pitch to]
const SOUNDS := {
	"swing": [["knifeSlice.ogg", "knifeSlice2.ogg", "drawKnife1.ogg"], -6.0, 0.85, 1.1],
	"hit": [["impactPlate_medium_000.ogg", "impactPlate_medium_001.ogg", "impactPlate_medium_002.ogg"], -2.0, 0.7, 0.9],
	"hit_big": [["impactPlate_heavy_000.ogg", "impactPlate_heavy_001.ogg"], 0.0, 0.6, 0.75],
	"hurt": [["impactPunch_heavy_000.ogg", "impactPunch_heavy_001.ogg", "impactPunch_heavy_002.ogg"], 0.0, 0.85, 1.0],
	"thud": [["impactPunch_medium_000.ogg", "impactPunch_medium_001.ogg"], -4.0, 0.8, 1.0],
	"dodge": [["cloth1.ogg", "cloth2.ogg", "cloth3.ogg"], -3.0, 0.9, 1.15],
	"step": [["footstep_snow_000.ogg", "footstep_snow_001.ogg", "footstep_snow_002.ogg", "footstep_snow_003.ogg"], -14.0, 0.9, 1.1],
	"beetle_step": [["impactSoft_heavy_000.ogg", "impactSoft_heavy_001.ogg", "impactSoft_heavy_002.ogg"], -12.0, 0.5, 0.65],
	"screech": [["creak1.ogg", "creak2.ogg", "creak3.ogg"], 0.0, 0.55, 0.7],
	"burrow": [["impactMining_000.ogg", "impactMining_001.ogg"], -2.0, 0.5, 0.6],
	"win": [["impactBell_heavy_000.ogg"], -2.0, 0.6, 0.6],
	"card": [["bookFlip1.ogg", "bookFlip2.ogg", "bookFlip3.ogg"], -6.0, 1.0, 1.2],
	"card_play": [["bookPlace1.ogg", "bookPlace2.ogg"], -4.0, 0.95, 1.1],
	"block": [["impactMetal_light_000.ogg", "impactMetal_light_001.ogg"], -4.0, 0.8, 0.95],
	"wrench": [["impactWood_heavy_000.ogg", "impactWood_heavy_001.ogg"], 0.0, 0.7, 0.8],
}

var _cache := {}
var _rng := RandomNumberGenerator.new()
var _wind: AudioStreamPlayer


func _ready() -> void:
	_rng.randomize()
	var w := AudioStreamWAV.load_from_file("res://audio/wind_loop.wav")
	if w != null:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
		_wind = AudioStreamPlayer.new()
		_wind.stream = w
		_wind.volume_db = -14.0
		add_child(_wind)
		_wind.play()


func _load(file: String) -> AudioStream:
	if not _cache.has(file):
		_cache[file] = AudioStreamOggVorbis.load_from_file("res://audio/" + file)
	return _cache[file]


func play(n: String, extra_db := 0.0, pitch := 1.0) -> void:
	var s: Array = SOUNDS[n]
	var files: Array = s[0]
	var stream := _load(files[_rng.randi() % files.size()])
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = float(s[1]) + extra_db
	p.pitch_scale = _rng.randf_range(s[2], s[3]) * pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
