extends RefCounted
## THE CHARACTER LOOK TEST's people (playtest 4: "increase the resolution of the
## characters"): the same residents as world/people.gd builds, from the same data
## (town_data.gd CAST: colours, look, items), but from 10 cm blocks instead of 20 cm.
## Two body shapes:
##   "B" double detail: today's proportions (legs, body and head a third each)
##   "C" double detail, cuter: shorter body and a bigger head, like Town to City's people
## A look test only (tests/people_look.gd): if the user picks one, it moves into people.gd.
## A person faces +x, feet at 0, like world/people.gd. Right hand is +z.

const U := 0.1   # block size, metres (today's people: 0.2)

var world: Node3D   # world.gd, for its cube mesher
var _cells := {}    # Vector3i -> Color: later colours paint over earlier ones


func _init(w: Node3D) -> void:
	world = w


## Proportions per shape (in 10 cm blocks). Head: h tall, w wide (z), d deep (x).
func _shape(style: String, look: Dictionary) -> Dictionary:
	if style == "C":
		return {"legs": 3 if look.get("legs", 3) == 2 else 4, "torso": 6 if look.get("torso", 3) == 4 else 5,
				"body_w": 6, "body_d": 4, "head_h": 8, "head_w": 8, "head_d": 6, "arm_w": 2}
	return {"legs": 4 if look.get("legs", 3) == 2 else 6, "torso": 8 if look.get("torso", 3) == 4 else 6,
			"body_w": 6, "body_d": 4, "head_h": 6, "head_w": 6, "head_d": 4, "arm_w": 2}


func _box(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, c: Color) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				_cells[Vector3i(x, y, z)] = c


func _cell(x: int, y: int, z: int, c: Color) -> void:
	_cells[Vector3i(x, y, z)] = c


## A resident (a CAST entry) in shape "B" or "C": body, clothes, face, hair and props.
func build(c: Dictionary, style: String) -> Node3D:
	_cells = {}
	var look: Dictionary = c.get("look", {})
	var s := _shape(style, look)
	var shirt: Color = c["shirt"]
	var pants: Color = c["bottom"]
	var hair: Color = c["hair"]
	var skin: Color = c["skin"]
	var legs: int = s["legs"]
	var torso: int = s["torso"]
	var neck := legs + torso
	var bw: int = s["body_w"]
	var bd: int = s["body_d"]
	var bz0 := -bw / 2
	var bz1 := bw / 2
	var bx0 := -bd / 2
	var bx1 := bd / 2
	var white := Color(0.95, 0.94, 0.88)
	# Legs and shoes (a skirt for a dress)
	if look.get("dress", false):
		_box(bx0, bx1, 1, legs, bz0, bz1, pants)
		_box(bx0, bx1, 1, 2, bz0, bz1, pants.darkened(0.18))             # a darker hem (no flare: it read as a lampshade)
		for z in [bz0 + 1, bz1 - 2]:
			_box(bx0 + 1, bx1 + 1, 0, 1, z, z + 1, pants.darkened(0.5))  # shoes peeking out
	else:
		for z0 in [bz0, bz1 - 2]:
			_box(bx0, bx1, 1, legs, z0, z0 + 2, pants)
			_box(bx0, bx1 + 1, 0, 1, z0, z0 + 2, pants.darkened(0.45))   # shoes, toes forward
	# Body: shirt, belt (or sash) with a buckle, a collar, a button placket
	_box(bx0, bx1, legs, neck, bz0, bz1, shirt)
	var belt: Color = look.get("sash", shirt.darkened(0.35))
	_box(bx0, bx1, legs, legs + 1, bz0, bz1, belt)
	if not look.has("sash"):
		_box(bx1 - 1, bx1, legs, legs + 1, -1, 1, Color(0.80, 0.65, 0.30))
	for y in range(legs + 1, neck - 1):
		_cell(bx1 - 1, y, 0, shirt.lightened(0.10) if (y - legs) % 2 == 1 else shirt.darkened(0.25))
	_box(bx1 - 1, bx1, neck - 1, neck, -1, 1, skin)                      # V of the neck
	_cell(bx1 - 1, neck - 1, -2, shirt.lightened(0.18))                    # collar
	_cell(bx1 - 1, neck - 1, 1, shirt.lightened(0.18))
	if look.get("belly", false):
		_box(bx1, bx1 + 1, legs + 1, neck - 2, bz0 + 1, bz1 - 1, shirt)
	# Arms: sleeves, a lighter cuff, hands at the hips
	for z0 in [bz0 - s["arm_w"], bz1]:
		_box(-1, 1, legs + 1, neck, z0, z0 + s["arm_w"], shirt.darkened(0.06))
		_box(-1, 1, legs + 1, legs + 2, z0, z0 + s["arm_w"], shirt.lightened(0.12))
		_box(-1, 1, legs - 1, legs + 1, z0, z0 + s["arm_w"], skin)
	# Apron: a bib lying on the front (over the belly where there is one), centred, its
	# hem below the belt, and straps over the shoulders
	if look.get("apron", false):
		var belly: bool = look.get("belly", false)
		for y in range(legs - 3, neck - 1):
			var ax := bx1 + (1 if belly and y > legs and y < neck - 2 else 0)
			_box(ax, ax + 1, y, y + 1, bz0 + 1, bz1 - 1, white)
		for z in [bz0 + 1, bz1 - 2]:
			_box(bx0, bx1 + 1, neck - 1, neck, z, z + 1, white)
	_head(s, neck, look, skin, hair)
	var node := Node3D.new()
	node.add_child(_mesh())
	_props(node, c, s, neck)
	if c.get("kid", false):
		node.scale = Vector3.ONE * 0.72
	return node


## The head: a face on the front (+x), ears, hair.
func _head(s: Dictionary, base: int, look: Dictionary, skin: Color, hair: Color) -> void:
	var hh: int = s["head_h"]
	var hw: int = s["head_w"]
	var hd: int = s["head_d"]
	var z0 := -hw / 2
	var z1 := hw / 2
	var x0 := -hd / 2
	var x1 := hd / 2
	var fx := x1 - 1          # the face's column
	var top := base + hh - 1  # the head's top row
	var cute := hh >= 8
	_box(x0, x1, base, base + hh, z0, z1, skin.darkened(0.07))   # sides a touch darker than the face
	_box(fx, x1, base, base + hh, z0, z1, skin)
	# Eyes: 2 x 2, dark brown (not black, so they don't merge with dark hair), each with
	# a sparkle on the same side (mirrored sparkles looked cross-eyed); brows lighter than
	# the hair; a closed mouth, low on the face (higher up it read as a moustache)
	var pupil := Color(0.20, 0.13, 0.10)
	var sparkle := Color(0.95, 0.96, 1.0)
	var mouth := Color(0.50, 0.24, 0.22)
	var brow := hair.lerp(skin, 0.45) if look.get("hair", "short") != "bald" else skin.darkened(0.25)
	var eye_y := base + (3 if cute else 2)
	for ez in [-3, 1]:
		_box(fx, x1, eye_y, eye_y + 2, ez, ez + 2, pupil)
		_cell(fx, eye_y + 1, ez + 1, sparkle)
		_box(fx, x1, eye_y + 2, eye_y + 3, ez, ez + 2, brow)
	var mouth_y := base + (1 if cute else 0)
	_box(fx, x1, mouth_y, mouth_y + 1, -1, 1, mouth)
	if cute:
		_cell(fx, base + 2, -4, skin.lerp(Color(0.95, 0.45, 0.45), 0.35))   # blush
		_cell(fx, base + 2, 3, skin.lerp(Color(0.95, 0.45, 0.45), 0.35))
	else:
		_box(x1, x1 + 1, base + 1, base + 2, -1, 1, skin.darkened(0.04))     # a nose that sticks out
	# Ears (small)
	for ez in [z0 - 1, z1]:
		_box(-1, 0, base + 2, base + 3, ez, ez + 1, skin.darkened(0.12))
	# Beard: filled in round the jaw and chin, the closed mouth showing through it
	if look.get("beard", false):
		var beard_top := base + (2 if cute else 1)
		_box(fx - 1, x1, base, beard_top, z0, z1, hair)
		for z in [z0, z1 - 1]:
			_box(x0 + 1, x1, base, beard_top + 1, z, z + 1, hair)
		_box(fx, x1, mouth_y, mouth_y + 1, -1, 1, mouth)
		if not cute:
			_cell(fx, base + 1, -2, hair.darkened(0.1))                       # a moustache either side of the nose
			_cell(fx, base + 1, 1, hair.darkened(0.1))
	# Hair
	var style: String = look.get("hair", "short")
	var hc: Color = look.get("scarf_colour", Color(0.85, 0.30, 0.25)) if style == "scarf" else hair
	match style:
		"bald":
			_box(x0, x0 + 1, base + 1, base + 4, z0, z1, hair)                 # a ring round the back
			for z in [z0, z1 - 1]:
				_box(x0, 0, base + 2, base + 4, z, z + 1, hair)
		_:
			_box(x0, x1, top, top + 1, z0, z1, hc)                               # the top
			_box(x0, x0 + 1, base + 1, top, z0, z1, hc)                          # the back
			for z in [z0, z1 - 1]:
				_box(x0, x1 - 1, base + 2, top, z, z + 1, hc)                     # the sides
			_box(fx, x1, top, top + 1, z0, z1, hc)                               # a fringe
			if cute:
				_box(fx, x1, top - 1, top, z0, 1, hc)                              # swept to one side
			if style == "long":
				_box(x0, x0 + 1, base - 5, base + 1, z0 + 1, z1 - 1, hc)         # down the back
			elif style == "bun":
				_box(x0, x0 + 2, top + 1, top + 3, -1, 1, hc)
			elif style == "scarf":
				for z in [z0, z1 - 1]:
					_box(fx, x1, base + 1, top, z, z + 1, hc)                     # framing the face


## What they carry or wear, from their items (only the ones the look test needs).
func _props(node: Node3D, c: Dictionary, s: Dictionary, neck: int) -> void:
	_cells = {}
	var legs: int = s["legs"]
	var top: int = neck + s["head_h"]
	var hw: int = s["head_w"]
	var hd: int = s["head_d"]
	var rz: int = s["body_w"] / 2   # the right arm starts here
	for item in c.get("items", []):
		match item:
			"mug":   # a frothy mug in the right hand
				_box(1, 3, legs - 1, legs + 2, rz, rz + 2, Color(0.62, 0.42, 0.22))
				_box(1, 3, legs + 2, legs + 3, rz, rz + 2, Color(0.98, 0.95, 0.85))
				_cell(3, legs, rz + 1, Color(0.55, 0.36, 0.18))
			"cap":   # a red cap with a brim
				_box(-hd / 2, hd / 2, top, top + 2, -hw / 2, hw / 2, Color(0.80, 0.18, 0.16))
				_box(hd / 2, hd / 2 + 2, top, top + 1, -hw / 2 + 1, hw / 2 - 1, Color(0.70, 0.14, 0.12))
			"satchel":   # an orange bag on the left hip, the strap across the chest
				_box(-2, 1, legs - 1, legs + 2, -s["body_w"] / 2 - 3, -s["body_w"] / 2 - 2, Color(0.90, 0.48, 0.12))
				var n: int = neck - legs
				for i in n:
					var z := int(round(lerpf(rz - 1, -rz, float(i) / maxf(1.0, n - 1))))
					_cell(s["body_d"] / 2, neck - 1 - i, z, Color(0.45, 0.28, 0.14))
			"head_towel":   # a towel wrapped on top of the head
				_box(-hd / 2, hd / 2, top, top + 2, -hw / 2, hw / 2, Color(0.97, 0.97, 0.95))
				_box(-hd / 2 + 1, hd / 2 - 1, top + 2, top + 3, -hw / 2 + 1, hw / 2 - 1, Color(0.92, 0.92, 0.90))
			"towels":   # a stack of folded towels held in front
				for i in 3:
					_box(s["body_d"] / 2, s["body_d"] / 2 + 2, legs + 1 + i, legs + 2 + i, -2, 2,
							Color(0.97, 0.97, 0.95) if i % 2 == 0 else Color(0.62, 0.86, 0.90))
	if not _cells.is_empty():
		node.add_child(_mesh())


func _mesh() -> MeshInstance3D:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for k: Vector3i in _cells:
		pts.append((Vector3(k) + Vector3(0.5, 0.5, 0.5)) * U)
		cols.append(_cells[k])
	return world._mi(world._cubes(pts, cols, U, true))
