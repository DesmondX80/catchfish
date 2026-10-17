class_name LakeWorld
extends Node3D
## Rakentaa järven maaston, veden, kasvillisuuden ja laiturin LakeData-ruudukosta.

const CHUNK := 64 # soluja lohkossa (lohkot nopeuttavat piirtoa näkökartioon rajaamalla)
const TREE_BAND := 350.0 # tiheä metsä näin lähellä rantaa, kauempana harvempi

var lake: LakeData
var water_material: ShaderMaterial


func build(lake_data: LakeData) -> void:
	lake = lake_data
	_build_terrain()
	_build_water()
	_build_trees()
	_build_reeds()
	_build_rocks()
	_build_buildings()
	_build_towers()
	_build_dock()


func _ground_color(c: int, r: int, h: float) -> Color:
	if lake.cell_is_water(c, r):
		var depth := -h
		return Color(0.32, 0.27, 0.17).lerp(Color(0.12, 0.1, 0.06), clampf(depth / 3.0, 0.0, 1.0))
	if h < 0.6 and lake.cell_shore_distance(c, r) <= 6.0:
		return Color(0.45, 0.4, 0.26) # rantahiekka/muta
	match lake.cell_ground(c, r):
		LakeData.Ground.FIELD:
			return Color(0.5, 0.52, 0.25)
		LakeData.Ground.BOG:
			return Color(0.42, 0.38, 0.22)
		LakeData.Ground.OPEN:
			return Color(0.38, 0.48, 0.22)
		LakeData.Ground.ROCK:
			return Color(0.45, 0.44, 0.42)
		LakeData.Ground.REEDS:
			return Color(0.36, 0.4, 0.2)
	return Color(0.2, 0.28, 0.12) # metsänpohja


func _build_terrain() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var cs := lake.cell_size
	for r0 in range(0, lake.rows - 1, CHUNK):
		for c0 in range(0, lake.cols - 1, CHUNK):
			var c1 := mini(c0 + CHUNK, lake.cols - 1)
			var r1 := mini(r0 + CHUNK, lake.rows - 1)
			var w := c1 - c0 + 1
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			var indices := PackedInt32Array()
			for r in range(r0, r1 + 1):
				for c in range(c0, c1 + 1):
					var h := lake.cell_height(c, r)
					verts.append(Vector3(lake.origin_x + c * cs, h, lake.origin_z + r * cs))
					var dx := lake.cell_height(c + 1, r) - lake.cell_height(c - 1, r)
					var dz := lake.cell_height(c, r + 1) - lake.cell_height(c, r - 1)
					normals.append(Vector3(-dx, 2.0 * cs, -dz).normalized())
					colors.append(_ground_color(c, r, h))
			for r in range(r1 - r0):
				for c in range(w - 1):
					var i := r * w + c
					indices.append_array([i, i + 1, i + w, i + 1, i + w + 1, i + w])
			_add_mesh(verts, normals, colors, indices, mat)


func _add_mesh(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, mat: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if colors.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	return mi


## Vesipinta vain järven kohdalle (padon takana oleva matala maa ei saa jäädä veden alle)
func _build_water() -> void:
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	var cs := lake.cell_size
	for r0 in range(0, lake.rows, CHUNK):
		for c0 in range(0, lake.cols, CHUNK):
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var indices := PackedInt32Array()
			var vertex_index := {}
			for r in range(r0, mini(r0 + CHUNK, lake.rows)):
				for c in range(c0, mini(c0 + CHUNK, lake.cols)):
					if not _water_or_next_to_water(c, r):
						continue
					var corners := [Vector2i(c, r), Vector2i(c + 1, r), Vector2i(c, r + 1), Vector2i(c + 1, r + 1)]
					var ids := []
					for corner in corners:
						if not vertex_index.has(corner):
							vertex_index[corner] = verts.size()
							verts.append(Vector3(lake.origin_x + corner.x * cs, 0.0, lake.origin_z + corner.y * cs))
							normals.append(Vector3.UP)
						ids.append(vertex_index[corner])
					indices.append_array([ids[0], ids[1], ids[2], ids[1], ids[3], ids[2]])
			if indices.size() > 0:
				var mi := _add_mesh(verts, normals, PackedColorArray(), indices, water_material)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _water_or_next_to_water(c: int, r: int) -> bool:
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if lake.cell_is_water(c + dc, r + dr):
				return true
	return false


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pine := []
	var birch := []
	for r in range(0, lake.rows, 2):
		for c in range(0, lake.cols, 2):
			if lake.cell_is_water(c, r):
				continue
			var ground := lake.cell_ground(c, r)
			var h := lake.cell_height(c, r)
			if h < 0.4 or ground == LakeData.Ground.FIELD or ground == LakeData.Ground.OPEN or ground == LakeData.Ground.REEDS:
				continue
			var near := lake.cell_shore_distance(c, r) <= TREE_BAND
			var chance := 0.55 if near else 0.12
			if ground == LakeData.Ground.BOG:
				chance *= 0.35
			for k in 2:
				if rng.randf() > chance:
					continue
				var p := lake.cell_center(c, r) + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-3.5, 3.5))
				var y := lake.height_at(p.x, p.y)
				var size := rng.randf_range(0.7, 1.3) * (0.6 if ground == LakeData.Ground.BOG else 1.0)
				var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, y, p.y))
				if rng.randf() < 0.7:
					pine.append(t)
				else:
					birch.append(t)
	_multimesh(_pine_mesh(), pine)
	_multimesh(_birch_mesh(), birch)


func _multimesh(mesh: Mesh, transforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _vertex_color_material(cull_disabled := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	if cull_disabled:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Kartio ja runko yhtenä verkkona, värit verteksiväreinä
func _cone(st: SurfaceTool, base_y: float, top_y: float, radius: float, color: Color, segments := 7) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0) * radius, base_y, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, base_y, sin(a1) * radius)
		var top := Vector3(0, top_y, 0)
		var n := (p1 - p0).cross(top - p0).normalized() * -1.0
		for v in [p0, top, p1]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)


func _pine_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.0, 9.0, 0.25, Color(0.3, 0.2, 0.12), 5)
	_cone(st, 2.0, 8.0, 2.2, Color(0.1, 0.22, 0.1))
	_cone(st, 5.0, 12.0, 1.6, Color(0.12, 0.26, 0.11))
	st.set_material(_vertex_color_material())
	return st.commit()


func _birch_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.0, 9.0, 0.18, Color(0.85, 0.85, 0.8), 5)
	_cone(st, 3.0, 10.5, 2.0, Color(0.32, 0.5, 0.16), 8)
	_cone(st, 7.0, 3.0, 1.9, Color(0.28, 0.46, 0.14), 8) # alaspäin osoittava kartio pyöristää latvuksen
	st.set_material(_vertex_color_material())
	return st.commit()


## Kaislikot rannan matalikoille ja vesirajaan
func _build_reeds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var transforms := []
	for r in lake.rows:
		for c in lake.cols:
			var h := lake.cell_height(c, r)
			var reed_land := lake.cell_ground(c, r) == LakeData.Ground.REEDS
			var shallow_water := lake.cell_is_water(c, r) and h > -0.7 and lake.cell_shore_distance(c, r) < 14.0 and _near_reed_land(c, r)
			if not (reed_land or shallow_water) or rng.randf() > 0.6:
				continue
			var p := lake.cell_center(c, r) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
			var y := minf(lake.height_at(p.x, p.y), 0.0) if shallow_water else lake.height_at(p.x, p.y)
			var s := rng.randf_range(0.8, 1.3)
			transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(p.x, y, p.y)))
	_multimesh(_reed_mesh(), transforms)


func _near_reed_land(c: int, r: int) -> bool:
	for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(1, 1), Vector2i(-1, -1)]:
		if lake.cell_ground(c + d.x, r + d.y) == LakeData.Ground.REEDS and not lake.cell_is_water(c + d.x, r + d.y):
			return true
	return false


func _reed_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 14:
		var base := Vector3(rng.randf_range(-1.2, 1.2), -0.6, rng.randf_range(-1.2, 1.2))
		var height := rng.randf_range(1.6, 2.6)
		var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var side := Vector3(0.05, 0, 0).rotated(Vector3.UP, rng.randf() * PI)
		var top := base + Vector3(0, height, 0) + lean
		var c_low := Color(0.3, 0.36, 0.16)
		var c_high := Color(0.62, 0.6, 0.32)
		for v in [[base - side, c_low], [base + side, c_low], [top, c_high]]:
			st.set_color(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	st.set_material(_vertex_color_material(true))
	return st.commit()


func _build_rocks() -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.41, 0.38)
	mat.roughness = 1.0
	mesh.material = mat
	var transforms := []
	for rock in lake.rocks:
		var s: float = rock["size"]
		var y := lake.height_at(rock["x"], rock["z"])
		transforms.append(Transform3D(Basis.from_euler(Vector3(0.2, rock["x"], 0.1)).scaled(Vector3(s, s * 0.6, s * 0.8)), Vector3(rock["x"], y, rock["z"])))
	_multimesh(mesh, transforms)


## Rakennukset maastotietokannan pohjapiirroksista: seinät ja harjakatto-tyyppinen tasakatto
func _build_buildings() -> void:
	if lake.buildings.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := Color(0.55, 0.2, 0.15) # punamulta
	var roof := Color(0.22, 0.22, 0.24)
	for b in lake.buildings:
		var pts := PackedVector2Array()
		for p in b["points"]:
			pts.append(Vector2(p[0], p[1]))
		var center := Vector2.ZERO
		for p in pts:
			center += p
		center /= pts.size()
		var base := lake.height_at(center.x, center.y) - 0.3
		var top: float = base + 0.3 + b["height"]
		for i in pts.size():
			var a := pts[i]
			var c := pts[(i + 1) % pts.size()]
			var quad := [Vector3(a.x, base, a.y), Vector3(c.x, base, c.y), Vector3(c.x, top, c.y), Vector3(a.x, top, a.y)]
			var n: Vector3 = (quad[1] - quad[0]).cross(quad[3] - quad[0]).normalized()
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(wall)
				st.set_normal(n)
				st.add_vertex(quad[idx])
		var tris := Geometry2D.triangulate_polygon(pts)
		for i in tris.size():
			var p := pts[tris[i]]
			st.set_color(roof)
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, top, p.y))
	st.set_material(_vertex_color_material(true))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	add_child(mi)


func _build_towers() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.32, 0.22)
	for t in lake.towers:
		var y := lake.height_at(t["x"], t["z"])
		var tower := Node3D.new()
		tower.position = Vector3(t["x"], y, t["z"])
		add_child(tower)
		for corner in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
			var leg := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.25, 12.0, 0.25)
			box.material = mat
			leg.mesh = box
			leg.position = Vector3(corner.x, 6.0, corner.y)
			tower.add_child(leg)
		var deck := MeshInstance3D.new()
		var deck_box := BoxMesh.new()
		deck_box.size = Vector3(4.0, 1.2, 4.0)
		deck_box.material = mat
		deck.mesh = deck_box
		deck.position = Vector3(0, 12.4, 0)
		tower.add_child(deck)


## Laituri aloituspaikasta rantaan päin
func _build_dock() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.36, 0.25)
	mat.roughness = 0.9
	var dock := Node3D.new()
	dock.position = lake.start_position
	dock.rotation.y = lake.start_yaw
	add_child(dock)
	var length := lake.dock_length
	var deck := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 0.12, length)
	box.material = mat
	deck.mesh = box
	# Vene on laiturin vieressä, laituri jatkuu taaksepäin rantaan
	deck.position = Vector3(-2.0, 0.55, length / 2.0 - 2.0)
	dock.add_child(deck)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.09
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 3.0
	post_mesh.material = mat
	for z in range(-2, int(length) - 2, 3):
		for x in [-2.8, -1.2]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = Vector3(x, -0.9, z)
			dock.add_child(post)
