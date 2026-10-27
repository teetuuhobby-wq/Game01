extends RefCounted
## BLOCKS: builds blocky meshes from a list of blocks, in the same style as the game
## (20 cm blocks, coloured per block, lit normally). Only faces you can see are kept.
## cells is a Dictionary: Vector3i block position -> Color.

const VS := 0.2

## Face directions: +x, -x, +y, -y, +z, -z.
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

static var _corners: Array[PackedVector3Array] = _make_corners()


static func _make_corners() -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	for n in DIRS:
		var nv := Vector3(n)
		var u := Vector3(0, 1, 0) if n.x != 0 else Vector3(1, 0, 0)
		var v := Vector3(0, 1, 0) if n.z != 0 else Vector3(0, 0, 1)
		var q := PackedVector3Array([(nv - u - v) * 0.5, (nv - u + v) * 0.5, (nv + u + v) * 0.5, (nv + u - v) * 0.5])
		if (q[1] - q[0]).cross(q[2] - q[0]).dot(nv) > 0.0:
			q.reverse()  # Godot draws the clockwise side
		out.append(q)
	return out


## The plain material: block colours, a little rough.
static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	return m


## A material that glows in its block colours (eyes, lanterns, windows).
static func glow_material(energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(energy, energy, energy)
	return m


## A mesh from blocks. The block at (0,0,0) is centred on `offset`; `size` is one block's size.
static func mesh(cells: Dictionary, mat: Material, offset := Vector3.ZERO, size := VS) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for c in cells:
		var centre: Vector3 = offset + Vector3(c) * size
		var col: Color = cells[c]
		for d in 6:
			if cells.has(c + DIRS[d]):
				continue
			var q := _corners[d]
			for k in [0, 1, 2, 0, 2, 3]:
				verts.append(centre + q[k] * size)
				norms.append(Vector3(DIRS[d]))
				cols.append(col)
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, mat)
	return m


static func node(cells: Dictionary, mat: Material, offset := Vector3.ZERO, size := VS) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(cells, mat, offset, size)
	return mi


## Fills a box of blocks (both corners included).
static func box(cells: Dictionary, a: Vector3i, b: Vector3i, col: Color) -> void:
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				cells[Vector3i(x, y, z)] = col


## A colour a little lighter or darker at random, so surfaces don't look flat.
static func vary(c: Color, rng: RandomNumberGenerator, amt := 0.04) -> Color:
	var j := rng.randf_range(-amt, amt)
	return Color(clampf(c.r + j, 0, 1), clampf(c.g + j, 0, 1), clampf(c.b + j, 0, 1))
