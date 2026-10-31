extends RefCounted
## THE CHARACTER LOOK TEST's people (playtest 4: "increase the resolution of the
## characters"): the same residents as world/people.gd builds, from the same data
## (town_data.gd CAST: colours, look, items), at finer resolutions.
## A style is a body shape, then (optionally) a way of adding detail:
##   shapes (10 cm blocks):
##     "B" today's proportions (legs, body and head a third each)
##     "C" cute: a short body and a big head (8 x 8), like Town to City's people
##     "D" C's face on a smaller head (7 x 7) and a longer body ("the head is too big")
##     "E" the same 7 x 7 head on a longer body again
##   detail ("C5", "D5h", "Dp"...):
##     ""   10 cm blocks
##     "5"  5 cm blocks everywhere: rounded heads and bodies, eyes with an iris and two
##          highlights, thin brows with a gap above the eyes, a curved smile, a tiny nose,
##          a fringe with a ragged edge and strands
##     "5h" the same 5 cm head on the 10 cm body (detail where you look)
##     "p"  the 10 cm head with the face painted on as a small sharp picture (8 pixels a block)
## C, D and E have the cute face: big eyes with a sparkle, blush, a little smile.
## Odd widths (7) have a true centre block; their meshes shift half a block so the
## person stays centred.
## A look test only (tests/people_look.gd): if the user picks one, it moves into people.gd.
## A person faces +x, feet at 0, like world/people.gd. Right hand is +z (the viewer's left).

const U := 0.1   # block size, metres (today's people: 0.2)
const PX := 8    # pixels per block on a painted face

var world: Node3D   # world.gd, for its cube mesher
var _cells := {}    # Vector3i -> Color: later colours paint over earlier ones
var _a := {}        # where things are on the last person built (in blocks): head, face, eyes...


func _init(w: Node3D) -> void:
	world = w


## Proportions per shape (in 10 cm blocks). Head: h tall, w wide (z), d deep (x).
## scale: the whole person (E is a little taller than the others, so shrinks to fit).
func _shape(shape: String, look: Dictionary) -> Dictionary:
	var short_legs: bool = look.get("legs", 3) == 2
	var tall: bool = look.get("torso", 3) == 4
	match shape:
		"C":
			return {"legs": 3 if short_legs else 4, "torso": 6 if tall else 5,
					"body_w": 6, "body_d": 4, "head_h": 8, "head_w": 8, "head_d": 6, "arm_w": 2, "scale": 1.0}
		"D":
			return {"legs": 4 if short_legs else 5, "torso": 7 if tall else 6,
					"body_w": 7, "body_d": 4, "head_h": 7, "head_w": 7, "head_d": 6, "arm_w": 2, "scale": 1.0}
		"E":
			return {"legs": 5 if short_legs else 6, "torso": 8 if tall else 7,
					"body_w": 7, "body_d": 4, "head_h": 7, "head_w": 7, "head_d": 6, "arm_w": 2, "scale": 0.92}
	return {"legs": 4 if short_legs else 6, "torso": 8 if tall else 6,
			"body_w": 6, "body_d": 4, "head_h": 6, "head_w": 6, "head_d": 4, "arm_w": 2, "scale": 1.0}


func _box(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, c: Color) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				_cells[Vector3i(x, y, z)] = c


func _cell(x: int, y: int, z: int, c: Color) -> void:
	_cells[Vector3i(x, y, z)] = c


## The middle of a row `w` blocks wide, n blocks of it ([start, end)), centred: an odd
## width centres an odd number of blocks, an even width an even number.
func _mid(w: int, n: int) -> Array:
	if w % 2 == 1 and n % 2 == 0:
		n += 1
	elif w % 2 == 0 and n % 2 == 1:
		n += 1
	var start := -(w / 2) + (w - n) / 2
	return [start, start + n]


## A resident (a CAST entry) in a style like "D", "D5", "D5h" or "Dp" (see the top).
func build(c: Dictionary, style: String) -> Node3D:
	var shape := style.substr(0, 1)
	var detail := style.substr(1)
	_cells = {}
	var look: Dictionary = c.get("look", {})
	var s := _shape(shape, look)
	var shirt: Color = c["shirt"]
	var pants: Color = c["bottom"]
	var hair: Color = c["hair"]
	var skin: Color = c["skin"]
	var legs: int = s["legs"]
	var torso: int = s["torso"]
	var neck := legs + torso
	var bw: int = s["body_w"]
	var bd: int = s["body_d"]
	var bz0 := -(bw / 2)
	var bz1 := bz0 + bw
	var bx0 := -bd / 2
	var bx1 := bd / 2
	var white := Color(0.95, 0.94, 0.88)
	var mid1: Array = _mid(bw, 1)   # the body's centre: one block (odd) or two (even)
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
		_box(bx1 - 1, bx1, legs, legs + 1, mid1[0], mid1[1], Color(0.80, 0.65, 0.30))
	for y in range(legs + 1, neck - 1):
		_cell(bx1 - 1, y, mid1[1] - 1, shirt.lightened(0.10) if (y - legs) % 2 == 1 else shirt.darkened(0.25))
	_box(bx1 - 1, bx1, neck - 1, neck, mid1[0], mid1[1], skin)            # V of the neck
	_cell(bx1 - 1, neck - 1, mid1[0] - 1, shirt.lightened(0.18))           # collar
	_cell(bx1 - 1, neck - 1, mid1[1], shirt.lightened(0.18))
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
	_a = {"torso": [bx0, bx1, legs, neck, bz0, bz1], "skin": skin, "hair": hair}
	var body := _cells
	_cells = {}
	_head(s, neck, look, skin, hair, detail == "")   # the finer styles draw the face themselves
	var head := _cells
	var node := Node3D.new()
	var shift := -U * 0.5 if bw % 2 == 1 else 0.0   # odd widths: back to the middle
	match detail:
		"5":
			node.add_child(_mesh_from(_refine(_upscale(body.merged(head, true)), true), U * 0.5, shift))
		"5h":
			node.add_child(_mesh_from(body, U, shift))
			node.add_child(_mesh_from(_refine(_upscale(head), false), U * 0.5, shift))
		_:
			node.add_child(_mesh_from(body.merged(head, true), U, shift))
			if detail == "p":
				node.add_child(_painted_face(shift))
	_props(node, c, s, neck, shift)
	node.scale = Vector3.ONE * float(s["scale"]) * (0.72 if c.get("kid", false) else 1.0)
	return node


## The head: a face on the front (+x), ears, hair. draw_face false: no eyes, brows,
## mouth or blush (a finer style adds its own).
func _head(s: Dictionary, base: int, look: Dictionary, skin: Color, hair: Color, draw_face: bool) -> void:
	var hh: int = s["head_h"]
	var hw: int = s["head_w"]
	var hd: int = s["head_d"]
	var z0 := -(hw / 2)
	var z1 := z0 + hw
	var x0 := -hd / 2
	var x1 := hd / 2
	var fx := x1 - 1          # the face's column
	var top := base + hh - 1  # the head's top row
	var cute := hh >= 7
	_box(x0, x1, base, base + hh, z0, z1, skin.darkened(0.07))   # sides a touch darker than the face
	_box(fx, x1, base, base + hh, z0, z1, skin)
	# Eyes: 2 x 2, dark brown (not black, so they don't merge with dark hair), each with
	# a sparkle on the same side (mirrored sparkles looked cross-eyed); brows lighter than
	# the hair
	var pupil := Color(0.20, 0.13, 0.10)
	var sparkle := Color(0.95, 0.96, 1.0)
	var mouth := skin.lerp(Color(0.40, 0.16, 0.14), 0.6)   # a darker lip tone (bright red read as a startled "oh!")
	var brow := hair.lerp(skin, 0.45) if look.get("hair", "short") != "bald" else skin.darkened(0.25)
	var eye_y := base + (3 if cute else 2)
	var eyes := [-2, 1] if hw % 2 == 1 else [-3, 1]   # odd: one block of nose between them
	var mouth_y := base + (1 if cute else 0)
	var m: Array = _mid(hw, 1)
	var hc: Color = look.get("scarf_colour", Color(0.85, 0.30, 0.25)) if look.get("hair", "short") == "scarf" else hair
	_a.merge({"x0": x0, "x1": x1, "fx": fx, "z0": z0, "z1": z1, "base": base, "top": top, "hw": hw, "hh": hh,
			"eyes": eyes, "eye_y": eye_y, "mouth_y": mouth_y, "m": m, "brow": brow, "mouth": mouth,
			"hair_colour": hc, "bald": look.get("hair", "short") == "bald"}, true)
	if draw_face:
		for ez in eyes:
			_box(fx, x1, eye_y, eye_y + 2, ez, ez + 2, pupil)
			_cell(fx, eye_y + 1, ez + 1, sparkle)
			_box(fx, x1, eye_y + 2, eye_y + 3, ez, ez + 2, brow)
		# The mouth: a little smile (the middle, its two ends a row up), or a closed line on B
		if cute:
			_box(fx, x1, mouth_y, mouth_y + 1, m[0], m[1], mouth)
			_cell(fx, mouth_y + 1, m[0] - 1, mouth)
			_cell(fx, mouth_y + 1, m[1], mouth)
			_cell(fx, base + 2, z0, skin.lerp(Color(0.95, 0.45, 0.45), 0.35))   # blush
			_cell(fx, base + 2, z1 - 1, skin.lerp(Color(0.95, 0.45, 0.45), 0.35))
		else:
			_box(fx, x1, mouth_y, mouth_y + 1, -1, 1, mouth)
	if not cute:
		_box(x1, x1 + 1, base + 1, base + 2, -1, 1, skin.darkened(0.04))     # a nose that sticks out
	# Ears (small)
	for ez in [z0 - 1, z1]:
		_box(-1, 0, base + 2, base + 3, ez, ez + 1, skin.darkened(0.12))
	# Beard: filled in round the jaw and chin, the mouth showing through it
	if look.get("beard", false):
		var beard_top := base + (2 if cute else 1)
		_box(fx - 1, x1, base, beard_top, z0, z1, hair)
		for z in [z0, z1 - 1]:
			_box(x0 + 1, x1, base, beard_top + 1, z, z + 1, hair)
		if draw_face and cute:
			_box(fx, x1, mouth_y, mouth_y + 1, m[0], m[1], mouth)
			_cell(fx, mouth_y + 1, m[0] - 1, mouth)
			_cell(fx, mouth_y + 1, m[1], mouth)
		elif draw_face:
			_box(fx, x1, mouth_y, mouth_y + 1, -1, 1, mouth)
			_cell(fx, base + 1, -2, hair.darkened(0.1))                       # a moustache either side of the nose
			_cell(fx, base + 1, 1, hair.darkened(0.1))
	# Hair
	var style: String = look.get("hair", "short")
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
				_box(fx, x1, top - 1, top, z0, z0 + hw / 2, hc)                    # swept to one side
			if style == "long":
				_box(x0, x0 + 1, base - 5, base + 1, z0 + 1, z1 - 1, hc)         # down the back
			elif style == "bun":
				var b: Array = _mid(hw, 2)
				_box(x0, x0 + 2, top + 1, top + 3, b[0], b[1], hc)
			elif style == "scarf":
				for z in [z0, z1 - 1]:
					_box(fx, x1, base + 1, top, z, z + 1, hc)                     # framing the face


# ---------------------------------------------------------------- 5 cm detail

## Each 10 cm block as eight 5 cm ones.
func _upscale(cells: Dictionary) -> Dictionary:
	var fine := {}
	for k: Vector3i in cells:
		for d in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
				Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]:
			fine[k * 2 + d] = cells[k]
	return fine


## The 5 cm finish (in 5 cm blocks): rounded edges on the head (and the body), a finer
## face, and texture in the hair.
func _refine(f: Dictionary, body_too: bool) -> Dictionary:
	var a := _a
	var skin: Color = a["skin"]
	# Rounded head: the four upright edges and the rim of the top come off
	var hx0: int = a["x0"] * 2
	var hx1: int = a["x1"] * 2 - 1
	var hz0: int = a["z0"] * 2
	var hz1: int = a["z1"] * 2 - 1
	var hy0: int = a["base"] * 2
	var hy1: int = a["top"] * 2 + 1
	for y in range(hy0, hy1 + 1):
		for x in [hx0, hx1]:
			for z in [hz0, hz1]:
				f.erase(Vector3i(x, y, z))
	for x in range(hx0, hx1 + 1):
		for z in range(hz0, hz1 + 1):
			if x == hx0 or x == hx1 or z == hz0 or z == hz1:
				f.erase(Vector3i(x, hy1, z))
	if body_too:
		var t: Array = a["torso"]   # [bx0, bx1, legs, neck, bz0, bz1]
		for y in range(t[2] * 2, t[3] * 2):
			for x in [t[0] * 2, t[1] * 2 - 1]:
				for z in [t[4] * 2, t[5] * 2 - 1]:
					f.erase(Vector3i(x, y, z))
	# Texture in the hair: every third block a shade darker
	var hc: Color = a["hair_colour"]
	for k: Vector3i in f.keys():
		if f[k] == hc and (k.x + k.y + k.z) % 3 == 0:
			f[k] = hc.darkened(0.12)
	# The face, on its front layer
	var F: int = a["fx"] * 2 + 1
	var dark := Color(0.12, 0.08, 0.07)
	var iris := Color(0.42, 0.26, 0.16)
	var iris_lit := Color(0.62, 0.42, 0.26)
	var white := Color(0.97, 0.97, 1.0)
	var ey: int = a["eye_y"] * 2
	for ez: int in a["eyes"]:
		var z0 := ez * 2
		# rows bottom to top; columns from -z to +z (the sparkle on +z, the viewer's left)
		var rows := [[null, dark, dark, null],
				[dark, iris_lit, iris, dark],
				[dark, iris, white, dark],
				[dark, dark, dark, dark]]
		for r in 4:
			for cc in 4:
				if rows[r][cc] != null:
					f[Vector3i(F, ey + r, z0 + cc)] = rows[r][cc]
				else:
					f[Vector3i(F, ey + r, z0 + cc)] = skin
		# A thin brow with a gap of skin above the eye (not where the fringe sweeps over)
		for cc in 4:
			var bk := Vector3i(F, ey + 5, z0 + cc)
			if a["bald"] or _is_skin(f, bk, skin):
				f[bk] = a["brow"]
	# A curved smile: the middle, and its two ends a step up
	var m: Array = a["m"]
	var my: int = a["mouth_y"] * 2 + 1
	for z in range(m[0] * 2, m[1] * 2):
		f[Vector3i(F, my, z)] = a["mouth"]
	f[Vector3i(F, my + 1, m[0] * 2 - 1)] = a["mouth"]
	f[Vector3i(F, my + 1, m[1] * 2)] = a["mouth"]
	# A tiny nose, sticking out above the smile
	var nz: int = m[0] * 2 + (m[1] - m[0]) - 1
	for z in range(nz, nz + 2):
		f[Vector3i(F + 1, my + 2, z)] = skin.darkened(0.05)
	# Blush either side
	var pink := skin.lerp(Color(0.95, 0.45, 0.45), 0.35)
	for z in [hz0 + 1, hz0 + 2, hz1 - 2, hz1 - 1]:
		f[Vector3i(F, my + 2, z)] = pink
	# A ragged fringe edge: every other block of its lowest row shows skin
	for z in range(hz0, hz1 + 1):
		for y in range(hy0, hy1):
			var k := Vector3i(F, y, z)
			if f.get(k, null) is Color and _is_hair(f[k], hc) and _is_skin(f, Vector3i(F, y - 1, z), skin) and z % 2 == 0:
				f[k] = skin
	return f


func _is_skin(f: Dictionary, k: Vector3i, skin: Color) -> bool:
	return f.get(k, null) is Color and (f[k] as Color).is_equal_approx(skin)


func _is_hair(c: Color, hc: Color) -> bool:
	return c.is_equal_approx(hc) or c.is_equal_approx(hc.darkened(0.12))


# ---------------------------------------------------------------- the painted face

## The face drawn as a small picture (PX pixels a block) on a card just in front of the
## 10 cm head: eyes with an iris, a pupil and two highlights, arched brows, a curved
## smile, blush. Where nothing is drawn the card is see-through (the blocks show).
func _painted_face(shift: float) -> MeshInstance3D:
	var a := _a
	var w: int = a["hw"] * PX
	var h: int = a["hh"] * PX
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = a["skin"]
	# Picture x from the viewer's left (+z), y from the top
	var px_x := func(z: float) -> int: return int(round((a["z1"] - z) * PX))
	var px_y := func(y: float) -> int: return int(round((a["top"] + 1 - y) * PX))
	var dark := Color(0.12, 0.08, 0.07)
	for ez: int in a["eyes"]:
		var ex: int = px_x.call(ez + 2.0)   # the eye's left edge, as seen
		var ety: int = px_y.call(a["eye_y"] + 2.0)
		var cx := ex + 8.0
		var cy := ety + 8.5
		for py in range(ety, ety + 16):
			for px in range(ex, ex + 16):
				var dx := (px + 0.5 - cx)
				var dy := (py + 0.5 - cy)
				var outer := (dx * dx) / (6.5 * 6.5) + (dy * dy) / (7.5 * 7.5)
				if outer > 1.0:
					continue
				var c := dark
				var inner := (dx * dx) / (4.8 * 4.8) + (dy * dy) / (5.8 * 5.8)
				if inner <= 1.0:
					c = Color(0.30, 0.18, 0.11).lerp(Color(0.66, 0.46, 0.28), clampf((dy + 5.0) / 10.0, 0.0, 1.0))
				var pupil := (dx * dx) / (2.2 * 2.2) + (dy * dy) / (2.8 * 2.8)
				if pupil <= 1.0:
					c = dark
				img.set_pixel(px, py, c)
		# Two highlights, on the viewer's left
		for d in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5)]:
			img.set_pixel(ex + d.x, ety + d.y, Color(1, 1, 1))
		for d in [Vector2i(10, 11), Vector2i(11, 11), Vector2i(10, 12)]:
			img.set_pixel(ex + d.x, ety + d.y, Color(0.95, 0.95, 1.0))
		# An arched brow above, with a gap of skin
		for i in 12:
			var bx := ex + 2 + i
			var arch := int(round(2.0 - absf(i - 5.5) * 0.35))
			for t in 2:
				var by := ety - 4 - arch + t
				if by >= 0:
					img.set_pixel(bx, by, a["brow"])
	# A curved smile
	var m: Array = a["m"]
	var mcx: float = px_x.call((m[0] + m[1]) / 2.0)
	var mcy: int = px_y.call(a["mouth_y"] + 0.5)
	for i in range(-7, 8):
		var y := mcy - int(round(i * i * 0.07))
		for t in 2:
			img.set_pixel(int(mcx) + i, y + t, a["mouth"])
	# Blush, solid (the card only shows or hides each pixel)
	var pink := skin.lerp(Color(0.95, 0.45, 0.45), 0.35)
	for side in [a["z0"] + 0.5, a["z1"] - 0.5]:
		var bx: int = px_x.call(side)
		for py in range(mcy - 6, mcy - 2):
			for px in range(bx - 5, bx + 5):
				if px >= 0 and px < w:
					img.set_pixel(px, py, pink)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var q := QuadMesh.new()
	q.size = Vector2(a["hw"] * U, a["hh"] * U)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.rotation.y = PI / 2.0   # facing +x, the picture's left on +z
	mi.position = Vector3(a["x1"] * U + 0.003, (a["base"] + a["hh"] / 2.0) * U, (a["z0"] + a["hw"] / 2.0) * U + shift)
	return mi


# ---------------------------------------------------------------- props and meshes

## What they carry or wear, from their items (only the ones the look test needs).
func _props(node: Node3D, c: Dictionary, s: Dictionary, neck: int, shift: float) -> void:
	_cells = {}
	var legs: int = s["legs"]
	var top: int = neck + s["head_h"]
	var hw: int = s["head_w"]
	var hd: int = s["head_d"]
	var hz0 := -(hw / 2)
	var bz0 := -(int(s["body_w"]) / 2)
	var rz: int = bz0 + int(s["body_w"])   # the right arm starts here
	for item in c.get("items", []):
		match item:
			"mug":   # a frothy mug in the right hand
				_box(1, 3, legs - 1, legs + 2, rz, rz + 2, Color(0.62, 0.42, 0.22))
				_box(1, 3, legs + 2, legs + 3, rz, rz + 2, Color(0.98, 0.95, 0.85))
				_cell(3, legs, rz + 1, Color(0.55, 0.36, 0.18))
			"cap":   # a red cap with a brim
				_box(-hd / 2, hd / 2, top, top + 2, hz0, hz0 + hw, Color(0.80, 0.18, 0.16))
				_box(hd / 2, hd / 2 + 2, top, top + 1, hz0 + 1, hz0 + hw - 1, Color(0.70, 0.14, 0.12))
			"satchel":   # an orange bag on the left hip, the strap across the chest
				_box(-2, 1, legs - 1, legs + 2, bz0 - 3, bz0 - 2, Color(0.90, 0.48, 0.12))
				var n: int = neck - legs
				for i in n:
					var z := int(round(lerpf(rz - 1, bz0, float(i) / maxf(1.0, n - 1))))
					_cell(s["body_d"] / 2, neck - 1 - i, z, Color(0.45, 0.28, 0.14))
			"head_towel":   # a towel wrapped on top of the head
				_box(-hd / 2, hd / 2, top, top + 2, hz0, hz0 + hw, Color(0.97, 0.97, 0.95))
				_box(-hd / 2 + 1, hd / 2 - 1, top + 2, top + 3, hz0 + 1, hz0 + hw - 1, Color(0.92, 0.92, 0.90))
			"towels":   # a stack of folded towels held in front
				var t: Array = _mid(int(s["body_w"]), 4)
				for i in 3:
					_box(s["body_d"] / 2, s["body_d"] / 2 + 2, legs + 1 + i, legs + 2 + i, t[0], t[1],
							Color(0.97, 0.97, 0.95) if i % 2 == 0 else Color(0.62, 0.86, 0.90))
	if not _cells.is_empty():
		node.add_child(_mesh_from(_cells, U, shift))


## Blocks (size metres) as one mesh; shift (metres, along z) puts an odd width back in the middle.
func _mesh_from(cells: Dictionary, size: float, shift := 0.0) -> MeshInstance3D:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for k: Vector3i in cells:
		pts.append((Vector3(k) + Vector3(0.5, 0.5, 0.5)) * size)
		cols.append(cells[k])
	var mi: MeshInstance3D = world._mi(world._cubes(pts, cols, size, true))
	mi.position.z = shift
	return mi
