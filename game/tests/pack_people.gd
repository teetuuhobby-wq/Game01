extends RefCounted
## THE CHARACTER LOOK TEST's ready-made people: the three free packs the user downloaded
## (originals/packs/; the character files copied into tests/look_packs/), fitted to the
## town: stood upright, turned to face +x like our people, scaled to a height, feet at 0,
## textured, and playing their pack's idle animation.
##   "VV" Voxel Village (The Voxel Store; free for any game): 10 voxel townsfolk, drawn
##        without arms or legs (floating hands and feet, like Rayman)
##   "KK" KayKit Adventurers (Kay Lousberg; CC0): 6 rounded low-poly adventurers
##   "KN" Kenney Blocky Characters (Kenney; CC0): 18 blocky people

const DIR := "res://tests/look_packs/"

## Per pack: the folder, its characters, how to stand them up (turn, in degrees, applied
## to the model) and which animation to idle with ([file or "" for the model's own, name]).
const PACKS := {
	"VV": {"name": "Voxel Village", "dir": "voxel_village/", "turn": Vector3(0, 90, 0),
			"idle": ["voxel_village/Human_Idle_Anim.fbx", ""],
			"files": ["TVS_VoxelVillage_PubLandlord.fbx", "TVS_VoxelVillage_Barmaid.fbx", "TVS_VoxelVillage_YoungMan.fbx",
					"TVS_VoxelVillage_YoungWoman.fbx", "TVS_VoxelVillage_MarketWoman.fbx", "TVS_VoxelVillage_Chef.fbx",
					"TVS_VoxelVillage_Butcher.fbx", "TVS_VoxelVillage_Jeweller.fbx", "TVS_VoxelVillage_OldMan.fbx",
					"TVS_VoxelVillage_OldWoman.fbx"]},
	"KK": {"name": "KayKit Adventurers", "dir": "kaykit/", "turn": Vector3(0, 90, 0),
			"idle": ["kaykit/Rig_Medium_General.glb", "Idle_A"],
			"files": ["Barbarian.glb", "Knight.glb", "Mage.glb", "Ranger.glb", "Rogue.glb", "Rogue_Hooded.glb"]},
	"KN": {"name": "Kenney Blocky Characters", "dir": "kenney/", "turn": Vector3(0, 90, 0),
			"idle": ["", "idle"],
			"files": ["character-a.glb", "character-b.glb", "character-c.glb", "character-d.glb", "character-e.glb",
					"character-f.glb", "character-g.glb", "character-h.glb", "character-i.glb", "character-j.glb",
					"character-k.glb", "character-l.glb", "character-m.glb", "character-n.glb", "character-o.glb",
					"character-p.glb", "character-q.glb", "character-r.glb"]},
}

var _idles := {}   # pack -> Animation (loaded once)


## One character from a pack, `height` metres tall, facing +x, feet at 0, idling.
func build(pack: String, file: String, height := 1.75, animate := true) -> Node3D:
	var spec: Dictionary = PACKS[pack]
	var holder := Node3D.new()
	var res = load(DIR + spec["dir"] + file)
	var model: Node3D
	if res is Mesh:
		# A plain model with no skeleton, so it stands still
		model = MeshInstance3D.new()
		(model as MeshInstance3D).mesh = res
	else:
		model = (res as PackedScene).instantiate()
	holder.add_child(model)
	model.rotation_degrees = spec["turn"]
	if pack == "VV":
		_texture_voxel_village(model, file)
	# Size and place it from how it stands (Voxel Village's size comes from its bones:
	# its mesh data lies flat until its skeleton stands it up)
	var box := _bone_bounds(model) if pack == "VV" else _bounds(model, model.transform)
	if box.size.y > 0.0:
		var s := height / box.size.y
		model.scale = Vector3.ONE * s
		var c := box.get_center()
		model.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)
	if animate and not model is MeshInstance3D:
		_idle(pack, model)
	return holder


func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if n is MeshInstance3D:
		out = xf * (n as MeshInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var t := xf * (c as Node3D).transform if c is Node3D else xf
		var b := _bounds(c, t)
		if b.size != Vector3.ZERO:
			out = b if first else out.merge(b)
			first = false
	return out


## The space the skeleton's bones take up at rest (in the holder's space), a little taller
## than the top bone for the top of the head.
func _bone_bounds(model: Node3D) -> AABB:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return _bounds(model, model.transform)
	var sk := sks[0] as Skeleton3D
	var xf := sk.transform
	var p := sk.get_parent()
	while p != null and p != model:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	xf = model.transform * xf
	var box := AABB(xf * sk.get_bone_global_rest(0).origin, Vector3.ZERO)
	for b in sk.get_bone_count():
		box = box.expand(xf * sk.get_bone_global_rest(b).origin)
	box.size.y *= 1.08
	return box


## Voxel Village's files point at a texture that isn't in the pack; each character has its own.
func _texture_voxel_village(model: Node, file: String) -> void:
	var tex_name := file.get_basename() + "_Texture.png"
	if file.contains("Jeweller"):
		tex_name = "TVS_VoxelVillage_JewellerySalesman_Texture.png"
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(DIR + "voxel_village/" + tex_name)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for mi in meshes:
		(mi as MeshInstance3D).material_override = mat


## The pack's idle animation, looping (its own, or borrowed from the pack's animation file).
func _idle(pack: String, model: Node) -> void:
	var spec: Dictionary = PACKS[pack]
	var own := model.find_children("*", "AnimationPlayer", true, false)
	if (spec["idle"][0] as String) == "":
		if not own.is_empty():
			var ap := own[0] as AnimationPlayer
			if ap.has_animation(spec["idle"][1]):
				ap.get_animation(spec["idle"][1]).loop_mode = Animation.LOOP_LINEAR
				ap.play(spec["idle"][1])
		return
	if not _idles.has(pack):
		var src: Node = load(DIR + spec["idle"][0]).instantiate()
		var sap := src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var name: String = spec["idle"][1] if spec["idle"][1] != "" else sap.get_animation_list()[0]
		var anim := sap.get_animation(name).duplicate() as Animation
		anim.loop_mode = Animation.LOOP_LINEAR
		_idles[pack] = [anim, src.get_path_to(sap.get_node(sap.root_node))]
		src.free()
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _idles[pack][0])
	ap.add_animation_library("pack", lib)
	ap.play("pack/idle")
