class_name LakeWorld
extends Node3D
## Rakentaa järven maaston, veden, kasvillisuuden ja laiturin LakeData-ruudukosta.

const CHUNK := 64 # soluja lohkossa (lohkot nopeuttavat piirtoa näkökartioon rajaamalla)
const TREE_BAND := 350.0 # tiheä metsä näin lähellä rantaa, kauempana harvempi

var lake: LakeData
var water_material: ShaderMaterial
var season := Season.from_day(165)
var _plain_summer := true # keskikesällä maaston värejä ei tarvitse muuttaa


func build(lake_data: LakeData, season_now: Season = null) -> void:
	lake = lake_data
	if season_now:
		season = season_now
	_plain_summer = season.snow == 0.0 and season.grass_dry == 0.0
	_carve_ramps() # maasto ja pohja luiskan muotoon ennen maaston rakentamista
	_build_terrain()
	_build_water()
	_build_trees()
	_build_reeds()
	_build_rocks()
	_build_buildings()
	_build_towers()
	_build_dock()


## Solukohtainen satunnaisluku 0..1 (sulavan lumen laikut)
func _patch(c: int, r: int) -> float:
	var n := sin(c * 0.37 + r * 0.11) * 0.5 + sin(c * 0.13 - r * 0.29 + 1.7) * 0.35 + sin((c + r) * 0.9) * 0.15
	return clampf(n * 0.5 + 0.5, 0.0, 1.0)


func _ground_color(c: int, r: int, h: float) -> Color:
	var base := _summer_ground_color(c, r, h)
	if _plain_summer or lake.cell_is_water(c, r):
		return base
	var g := lake.cell_ground(c, r)
	if g != LakeData.Ground.ROCK:
		base = season.tint_grass(base)
	# Lumi jää pisimpään metsän varjoon
	return season.snowy(base, _patch(c, r), 1.0 if g == LakeData.Ground.FOREST else 0.0)


func _summer_ground_color(c: int, r: int, h: float) -> Color:
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
				if _near_dock(p, 28.0):
					continue
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
	# Talvella kuusten oksilla on lunta
	var needles := Color(0.1, 0.22, 0.1).lerp(Color(0.75, 0.8, 0.82), season.snow * 0.45)
	var top := Color(0.12, 0.26, 0.11).lerp(Color(0.85, 0.88, 0.9), season.snow * 0.55)
	_cone(st, 2.0, 8.0, 2.2, needles)
	_cone(st, 5.0, 12.0, 1.6, top)
	st.set_material(_vertex_color_material())
	return st.commit()


func _birch_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.0, 9.0, 0.18, Color(0.85, 0.85, 0.8), 5)
	# Lehvästö: koko ja väri vuodenajan mukaan (keväällä vaalea, syksyllä ruska, talvella paljas)
	var leaves := season.leaves
	if leaves > 0.05:
		var size := 0.55 + 0.45 * leaves
		_cone(st, 3.0 + (1.0 - size) * 2.0, 10.5, 2.0 * size, season.birch_leaf_color(Color(0.32, 0.5, 0.16)), 8)
		_cone(st, 7.0, 3.0 + (1.0 - size) * 2.5, 1.9 * size, season.birch_leaf_color(Color(0.28, 0.46, 0.14)), 8) # alaspäin osoittava kartio pyöristää latvuksen
	else:
		# Paljaat oksat: muutama ohut kartio
		for k in 4:
			var branch := Color(0.35, 0.3, 0.27)
			_cone(st, 4.0 + k * 1.3, 9.5, 0.9 - k * 0.15, branch, 5)
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
			if _near_dock(p, 12.0):
				continue
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
		var c_low := season.reed_color(Color(0.3, 0.36, 0.16))
		var c_high := season.reed_color(Color(0.62, 0.6, 0.32))
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
	var site := _tower_site_buildings()
	for i_b in lake.buildings.size():
		var b: Dictionary = lake.buildings[i_b]
		var pts := PackedVector2Array()
		for p in b["points"]:
			pts.append(Vector2(p[0], p[1]))
		var center := Vector2.ZERO
		for p in pts:
			center += p
		center /= pts.size()
		if _on_ramp_area(center, pts):
			continue # luiska ja kääntöpaikka tarvitsevat tilan
		if site.get(i_b) == "kota":
			_kota(st, center, pts)
			continue
		if site.get(i_b) == "vaja":
			_woodshed(st, center, pts)
			continue
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


## Kota on lintutornin vieressä: kunkin tornin lähin rakennus
## Lintutornin vieressä on kota (tornia lähin rakennus) ja hirsinen puuvaja
## (muut lähellä olevat): {rakennuksen indeksi: "kota" tai "vaja"}
func _tower_site_buildings() -> Dictionary:
	var result := {}
	for t in lake.towers:
		var near := []
		for i in lake.buildings.size():
			var c := Vector2.ZERO
			for p in lake.buildings[i]["points"]:
				c += Vector2(p[0], p[1])
			c /= lake.buildings[i]["points"].size()
			var d := c.distance_to(Vector2(t["x"], t["z"]))
			if d < 25.0:
				near.append([d, i])
		near.sort()
		for k in near.size():
			result[near[k][1]] = "kota" if k == 0 else "vaja"
	return result


## Suunta rakennuksesta lähimmälle aloituspaikalle (ovi laiturin puolelle)
func _toward_start(center: Vector2) -> Vector2:
	var dir := Vector2.RIGHT
	var best_d := INF
	for s in lake.starts:
		var d := center.distance_to(Vector2(s["x"], s["z"]))
		if d < best_d:
			best_d = d
			dir = (Vector2(s["x"], s["z"]) - center).normalized()
	return dir


## Grillikota: kahdeksankulmainen harmaaksi maalattu lautaseinä, valkoiset
## pielet ja räystäslaudat, jyrkkä tumma paanukatto harjoineen ja peltipiippu
func _kota(st: SurfaceTool, center: Vector2, pts: PackedVector2Array) -> void:
	var area := 0.0
	for i in pts.size():
		area += pts[i].cross(pts[(i + 1) % pts.size()])
	var r := clampf(sqrt(absf(area) / 2.0 / (2.0 * sqrt(2.0))), 2.2, 3.5) # kahdeksankulmion kärkisäde
	var a0 := (pts[1] - pts[0]).angle()
	var base := lake.height_at(center.x, center.y) - 0.3
	var wall_top := base + 0.3 + 1.8
	var wall := Color(0.38, 0.4, 0.42)
	var white := Color(0.85, 0.86, 0.84)
	var glass := Color(0.12, 0.13, 0.15)
	var roof := season.snowy(Color(0.17, 0.18, 0.2), 0.6)
	var ridge := season.snowy(Color(0.3, 0.31, 0.33), 0.6)
	var door_dir := _toward_start(center)
	var corners: Array[Vector2] = []
	for i in 8:
		corners.append(center + Vector2.from_angle(a0 + TAU * i / 8.0) * r)
	var door_side := 0
	for i in 8:
		var mid_dir := ((corners[i] + corners[(i + 1) % 8]) / 2.0 - center).normalized()
		if mid_dir.dot(door_dir) > (((corners[door_side] + corners[(door_side + 1) % 8]) / 2.0 - center).normalized()).dot(door_dir):
			door_side = i
	for i in 8:
		var a := corners[i]
		var b := corners[(i + 1) % 8]
		var out2 := ((a + b) / 2.0 - center).normalized()
		var n := Vector3(out2.x, 0, out2.y)
		_quad(st, [Vector3(a.x, base, a.y), Vector3(b.x, base, b.y), Vector3(b.x, wall_top, b.y), Vector3(a.x, wall_top, a.y)], n, wall)
		# Valkoiset kulmapielet
		_beam(st, Vector3(a.x, base, a.y) + n * 0.02, Vector3(a.x, wall_top, a.y) + n * 0.02, 0.1, white)
		var mid := (a + b) / 2.0
		var along := (b - a).normalized()
		var side := Vector3(along.x, 0, along.y)
		var m3 := Vector3(mid.x, 0, mid.y)
		if i == door_side:
			var floor_y := base + 0.3
			_panel(st, m3 + Vector3(0, floor_y + 0.85, 0) + n * 0.03, side, n, 0.5, 0.85, white)
			_panel(st, m3 + Vector3(0, floor_y + 0.8, 0) + n * 0.05, side, n, 0.42, 0.8, Color(0.3, 0.33, 0.36))
		elif i % 2 == 0:
			var win_y := base + 0.3 + 1.1
			_panel(st, m3 + Vector3(0, win_y, 0) + n * 0.03, side, n, 0.42, 0.36, white)
			_panel(st, m3 + Vector3(0, win_y, 0) + n * 0.05, side, n, 0.33, 0.28, glass)
	# Katto: räystäs seinän yli, jyrkkä pyramidi
	var eave_r := r + 0.4
	var eave_y := wall_top - 0.1
	var apex := Vector3(center.x, wall_top + (r + 0.4) * 1.05, center.y)
	for i in 8:
		var a := center + Vector2.from_angle(a0 + TAU * i / 8.0) * eave_r
		var b := center + Vector2.from_angle(a0 + TAU * (i + 1) / 8.0) * eave_r
		var a3 := Vector3(a.x, eave_y, a.y)
		var b3 := Vector3(b.x, eave_y, b.y)
		var n := (b3 - a3).cross(apex - a3).normalized()
		if n.y < 0.0:
			n = -n
		for v in [a3, b3, apex]:
			st.set_color(roof)
			st.set_normal(n)
			st.add_vertex(v)
		# Räystäslauta ja kattoharja
		var down := Vector3(0, -0.2, 0)
		var out3 := Vector3((a + b).x / 2.0 - center.x, 0, (a + b).y / 2.0 - center.y).normalized()
		_quad(st, [a3 + down, b3 + down, b3, a3], out3, white)
		_beam(st, a3 + Vector3(0, 0.05, 0), apex + Vector3(0, 0.05, 0), 0.12, ridge)
	# Peltipiippu hatun kanssa
	var steel := Color(0.5, 0.51, 0.52)
	_beam(st, apex - Vector3(0, 0.4, 0), apex + Vector3(0, 0.9, 0), 0.3, steel)
	_box(st, apex + Vector3(0, 1.0, 0), Vector3(0.24, 0.08, 0.24), Color(0.15, 0.15, 0.16))


## Puuvaja: harmaantuneet vaakahirret ylittyvine nurkkineen hirsijalasten päällä,
## harjakatto, harmaansininen ovi päätykolmiossa ja ilmoitustaulu kyljessä
func _woodshed(st: SurfaceTool, center: Vector2, pts: PackedVector2Array) -> void:
	var e0 := pts[1] - pts[0]
	var e1 := pts[pts.size() - 1] - pts[0]
	# Harja pidemmän sivun suuntaan, ovi laiturin puoleiseen päätyyn
	var along := e0.normalized() if e0.length() >= e1.length() else e1.normalized()
	var half_l := clampf(maxf(e0.length(), e1.length()) / 2.0 - 0.3, 1.2, 2.5)
	var half_w := clampf(minf(e0.length(), e1.length()) / 2.0 - 0.3, 1.0, 2.0)
	if along.dot(_toward_start(center)) < 0.0:
		along = -along
	var fwd := Vector3(along.x, 0, along.y)
	var side := Vector3(-along.y, 0, along.x)
	var ground := lake.height_at(center.x, center.y)
	var c3 := Vector3(center.x, ground, center.y)
	var log_a := Color(0.46, 0.42, 0.36)
	var log_b := Color(0.4, 0.36, 0.31)
	var d := 0.22 # hirren paksuus
	# Jalakset maassa
	for s in [-1.0, -0.2, 0.6, 1.0]:
		var o: Vector3 = c3 + side * half_w * s * 0.95 + Vector3(0, d * 0.4, 0)
		_log(st, o - fwd * (half_l + 0.35), o + fwd * (half_l + 0.35), d * 1.1, log_b)
	# Seinähirret vuorokerroksin, päät ylittävät nurkat
	var floor_y := ground + d
	var layers := 9
	for k in layers:
		var y := floor_y + d * (k + 0.5)
		var color := log_a if k % 2 == 0 else log_b
		var lift := Vector3(0, d * 0.5, 0) if k % 2 else Vector3.ZERO
		for s in [-1.0, 1.0]:
			var o: Vector3 = c3 + side * half_w * s
			o.y = y
			_log(st, o - fwd * (half_l + 0.25), o + fwd * (half_l + 0.25), d, color)
			var q: Vector3 = c3 + fwd * half_l * s + lift
			q.y = y + lift.y
			_log(st, q - side * (half_w + 0.25), q + side * (half_w + 0.25), d, color.darkened(0.04))
	# Päätykolmiot hirsistä, lyhenevät harjaa kohti
	var eave_y := floor_y + d * layers
	var rise := half_w * 0.6
	var gable_layers := int(rise / d)
	for k in gable_layers:
		var y := eave_y + d * (k + 0.5)
		var w := half_w * (1.0 - (k + 0.5) / gable_layers)
		for s in [-1.0, 1.0]:
			var q: Vector3 = c3 + fwd * half_l * s
			q.y = y
			_log(st, q - side * w, q + side * w, d, log_a if k % 2 == 0 else log_b)
	# Harjakatto räystäineen ja vaaleat otsalaudat
	var roof := season.snowy(Color(0.36, 0.38, 0.35), 0.6)
	var trim := Color(0.72, 0.72, 0.68)
	var ridge := c3 + Vector3(0, eave_y + rise + 0.15 - ground, 0)
	for s in [-1.0, 1.0]:
		var eave: Vector3 = c3 + side * (half_w + 0.5) * s + Vector3(0, eave_y - 0.15 - ground, 0)
		var front: Vector3 = fwd * (half_l + 0.45)
		var n: Vector3 = (eave - ridge).cross(front).normalized()
		if n.y < 0.0:
			n = -n
		_quad(st, [eave - front, eave + front, ridge + front, ridge - front], n, roof)
		for f in [-1.0, 1.0]:
			_beam(st, eave + front * f, ridge + front * f, 0.12, trim)
	# Ovi päädyssä ja ilmoitustaulu kyljessä
	var door_c := c3 + fwd * (half_l + d * 0.6) + Vector3(0, floor_y - ground + 0.95, 0)
	_panel(st, door_c, side, fwd, 0.45, 0.98, Color(0.62, 0.6, 0.55))
	_panel(st, door_c + fwd * 0.03, side, fwd, 0.38, 0.92, Color(0.4, 0.5, 0.6))
	var board_c := c3 - side * (half_w + d * 0.6) + Vector3(0, floor_y - ground + 1.2, 0) - fwd * half_l * 0.35
	_panel(st, board_c, fwd, -side, 0.5, 0.55, Color(0.62, 0.48, 0.32))
	_panel(st, board_c - side * 0.03, fwd, -side, 0.42, 0.47, Color(0.72, 0.75, 0.76))


## Hirsi: neliöpalkki kierrettynä särmälleen, jolloin varjostus pyöristyy
func _log(st: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP).normalized().rotated(y, PI / 4.0)
	_box(st, (a + b) / 2.0, Vector3(width / 2.0, a.distance_to(b) / 2.0, width / 2.0), color, Basis(x, y, x.cross(y)))


## Lintutorni (Haapajärven mallin mukaan): katoton näköalatasanne neljän
## tolpan varassa, edessä alempi välitasanne ja kaksi porrassyöksyä, laidoilla
## pystyrimakaiteet
func _build_towers() -> void:
	var wood := Color(0.47, 0.42, 0.35)
	var dark := Color(0.36, 0.32, 0.27)
	var deck_color := season.snowy(Color(0.5, 0.45, 0.37), 0.6)
	for t in lake.towers:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top_y := 5.0
		var mid_y := 2.4
		for c in [Vector2(-1.6, -1.4), Vector2(1.6, -1.4), Vector2(-1.6, 2.6), Vector2(1.6, 2.6)]:
			_beam(st, Vector3(c.x, -1.0, c.y), Vector3(c.x, top_y, c.y), 0.24, wood)
		# Pitkät vinotuet tolpista tasanteen alle
		_beam(st, Vector3(-1.6, 0.8, 2.75), Vector3(1.6, top_y - 0.3, 2.75), 0.16, wood)
		_beam(st, Vector3(1.6, 0.8, -1.55), Vector3(-1.6, top_y - 0.3, -1.55), 0.16, wood)
		_beam(st, Vector3(-1.75, 0.8, -1.4), Vector3(-1.75, top_y - 0.3, 2.6), 0.16, wood)
		# Näköalatasanne kantavine palkkeineen ja kaiteineen
		_box(st, Vector3(0, top_y, 0.6), Vector3(2.2, 0.06, 2.4), deck_color)
		for z in [-1.4, 2.6]:
			_box(st, Vector3(0, top_y - 0.2, z), Vector3(2.2, 0.14, 0.1), dark)
		var deck := [Vector3(-2.2, top_y, -1.8), Vector3(2.2, top_y, -1.8), Vector3(2.2, top_y, 3.0), Vector3(-2.2, top_y, 3.0)]
		for i in 4:
			_railing(st, deck[i], deck[(i + 1) % 4], wood)
		# Välitasanne tornin edessä; ensimmäinen syöksy tulee sen itäpäähän
		_box(st, Vector3(0.4, mid_y, 2.2), Vector3(2.4, 0.06, 0.8), deck_color)
		_beam(st, Vector3(2.8, -1.0, 3.0), Vector3(2.8, mid_y, 3.0), 0.18, wood)
		_beam(st, Vector3(-2.0, -1.0, 3.0), Vector3(-2.0, mid_y, 3.0), 0.18, wood)
		_railing(st, Vector3(-2.0, mid_y, 3.0), Vector3(1.9, mid_y, 3.0), wood)
		_railing(st, Vector3(-2.0, mid_y, 1.4), Vector3(-2.0, mid_y, 3.0), wood)
		_stairs(st, Vector3(2.4, 0.0, 5.8), Vector3(2.4, mid_y, 3.0), dark, wood)
		_stairs(st, Vector3(1.4, mid_y, 1.9), Vector3(-1.9, top_y, 1.9), dark, wood)
		st.set_material(_vertex_color_material(true))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.position = Vector3(t["x"], lake.height_at(t["x"], t["z"]), t["z"])
		mi.rotation.y = _tower_yaw(t)
		add_child(mi)


## Portaat (tornin +z) kohti korkeinta maata, ettei ensimmäinen syöksy laskeudu rantaveteen
func _tower_yaw(t: Dictionary) -> float:
	var best := 0.0
	var best_h := -INF
	for i in 16:
		var a := TAU * i / 16.0
		var p := Vector2(t["x"], t["z"]) + Vector2(sin(a), cos(a)) * 7.0
		var h := lake.height_at(p.x, p.y)
		if h > best_h:
			best_h = h
			best = a
	return best


## Kaide pisteestä toiseen: ylä- ja alajuoksu sekä tiheät pystyrimat
func _railing(st: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	_beam(st, a + Vector3(0, 1.1, 0), b + Vector3(0, 1.1, 0), 0.1, color)
	_beam(st, a + Vector3(0, 0.15, 0), b + Vector3(0, 0.15, 0), 0.07, color)
	var count := int(a.distance_to(b) / 0.14)
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		_beam(st, p + Vector3(0, 0.08, 0), p + Vector3(0, 1.1, 0), 0.05 if i % count else 0.12, color)


## Porrassyöksy kahden pisteen välillä: sivupalkit ja askelmat
func _stairs(st: SurfaceTool, from: Vector3, to: Vector3, beam_color: Color, step_color: Color) -> void:
	var run := Vector3(to.x - from.x, 0, to.z - from.z)
	var across := run.normalized().cross(Vector3.UP) * 0.4
	for s in [-1.0, 1.0]:
		_beam(st, from + across * s, to + across * s, 0.1, beam_color)
		# Käsijohde tolppineen
		var up := Vector3(0, 0.95, 0)
		_beam(st, from + across * s + up, to + across * s + up, 0.07, step_color)
		for f in [0.0, 0.5]:
			var q: Vector3 = from.lerp(to, f) + across * s
			_beam(st, q, q + up, 0.07, step_color)
	var steps := int(ceil((to.y - from.y) / 0.25))
	var basis := Basis(across.normalized(), Vector3.UP, run.normalized())
	for i in steps:
		var p := from.lerp(to, (i + 0.5) / steps) + Vector3(0, 0.05, 0)
		_box(st, p, Vector3(0.4, 0.025, 0.13), step_color, basis)


## Pystysuora levy (ikkuna, ovi, lautalaita): keskipiste, vaakasuunta, normaali ja puolikoot
func _panel(st: SurfaceTool, center: Vector3, side: Vector3, n: Vector3, half_w: float, half_h: float, color: Color) -> void:
	var u := side * half_w
	var v := Vector3(0, half_h, 0)
	_quad(st, [center - u - v, center + u - v, center + u + v, center - u + v], n, color)


func _quad(st: SurfaceTool, quad: Array, n: Vector3, color: Color) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(quad[idx])


## Laatikko: keskipiste, puolikoot ja kierto
func _box(st: SurfaceTool, center: Vector3, half: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var ax := [basis.x * half.x, basis.y * half.y, basis.z * half.z]
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var face: Vector3 = ax[axis] * sgn
			var u: Vector3 = ax[(axis + 1) % 3]
			var v: Vector3 = ax[(axis + 2) % 3]
			var c := center + face
			_quad(st, [c - u - v, c + u - v, c + u + v, c - u + v], face.normalized(), color)


## Palkki pisteestä toiseen, neliön muotoinen poikkileikkaus
func _beam(st: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD) if absf(y.dot(Vector3.FORWARD)) < 0.9 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	_box(st, (a + b) / 2.0, Vector3(width / 2.0, a.distance_to(b) / 2.0, width / 2.0), color, Basis(x, y, x.cross(y)))


## Laiturin ja aloituspaikan ympärille jätetään avoin ranta (puut eivät
## peitä näkymää eikä kamera osu niihin)
func _near_dock(p: Vector2, radius: float) -> bool:
	for s in lake.starts:
		var boat := Vector2(s["x"], s["z"])
		var yaw := _dock_yaw(s)
		var to_shore := Vector2(sin(yaw), cos(yaw))
		var shore_end: Vector2 = boat + to_shore * float(s.get("dock_length", 10.0))
		if Geometry2D.get_closest_point_to_segment(p, boat, shore_end).distance_to(p) < radius:
			return true
	return false


## Laiturit kaikkiin aloituspaikkoihin, veneen kohdalta rantaan päin
func _build_dock() -> void:
	for s in lake.starts:
		var dock := _dock(Vector3(s["x"], 0.0, s["z"]), _dock_yaw(s), s.get("dock_length", 10.0), s.get("dock_width", 1.8))
		if s.get("parking", false):
			_parking(dock, s.get("dock_length", 10.0), s.get("dock_width", 1.8))
		if s.get("ramp", false):
			_build_ramp(dock, s)


func _dock_yaw(s: Dictionary) -> float:
	return LakeData.dock_yaw(s)


## Laituri: kansi paaluilla. Leveä laituri saa tiheämmät paalut ja kaiteet.
func _dock(at: Vector3, yaw: float, length: float, width := 1.8) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.36, 0.25)
	mat.roughness = 0.9
	var dock := Node3D.new()
	dock.position = at
	dock.rotation.y = yaw
	add_child(dock)
	var deck := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.12, length)
	box.material = mat
	deck.mesh = box
	# Vene on laiturin vieressä, laituri jatkuu taaksepäin rantaan
	var side_x := LakeData.dock_side_x(width) # laituri veneen vasemmalla kyljellä; törmäyslaatikko: LakeData.docks
	deck.position = Vector3(side_x, 0.55, length / 2.0 - 2.0)
	dock.add_child(deck)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.09
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 3.0
	post_mesh.material = mat
	var post_xs := [side_x - width / 2.0 + 0.1, side_x + width / 2.0 - 0.1]
	if width > 2.5:
		post_xs.append(side_x) # leveä laituri: keskipaalurivi
	for z in range(-2, int(length) - 2, 2 if width > 2.5 else 3):
		for x in post_xs:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = Vector3(x, -0.9, z)
			dock.add_child(post)
	if width > 2.5:
		# Tukeva uimalaituri: kaiteet rannan puoleiseen päähän ja uimatikkaat kärkeen
		for x in [side_x - width / 2.0 + 0.05, side_x + width / 2.0 - 0.05]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.08, 0.08, length * 0.4)
			rail_mesh.material = mat
			rail.mesh = rail_mesh
			rail.position = Vector3(x, 1.5, length * 0.8 - 2.0)
			dock.add_child(rail)
			for z in [length * 0.6 - 2.0, length - 2.2]:
				var stand := MeshInstance3D.new()
				var stand_mesh := BoxMesh.new()
				stand_mesh.size = Vector3(0.08, 0.95, 0.08)
				stand_mesh.material = mat
				stand.mesh = stand_mesh
				stand.position = Vector3(x, 1.05, z)
				dock.add_child(stand)
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.75, 0.77, 0.8)
		steel.metallic = 0.8
		steel.roughness = 0.3
		for x in [side_x - 0.25, side_x + 0.25]:
			var bar := MeshInstance3D.new()
			var bar_mesh := CylinderMesh.new()
			bar_mesh.top_radius = 0.025
			bar_mesh.bottom_radius = 0.025
			bar_mesh.height = 1.6
			bar_mesh.material = steel
			bar.mesh = bar_mesh
			bar.position = Vector3(x, 0.15, -2.05)
			dock.add_child(bar)
	dock.set_meta("side_x", side_x)
	return dock


# --- Veneenlaskuluiska ---------------------------------------------------------
# Luiska on laiturin vieressä veneen toisella puolella. Paikallisissa
# koordinaateissa (laiturin solmu): x sivulle, z rantaa kohti; rantaviiva on
# kohdassa z = laiturin pituus - 6 m (laituri alkaa 6 m ennen rantaa).

const RAMP_X := 3.8 # luiskan keskilinja veneestä sivulle
const RAMP_WIDTH := 4.0
const RAMP_UNDERWATER := 10.0 # m rantaviivasta veteen päin
const RAMP_ON_LAND := 9.0 # m rantaviivasta maalle
const RAMP_BOTTOM := -1.3 # alapään korkeus vedenpinnasta


func _ramp_transform(s: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _dock_yaw(s)), Vector3(s["x"], 0.0, s["z"]))


## Luiskan pinnan korkeus paikallisessa z:ssa (suora kaltevuus ala- ja yläpään välillä)
func _ramp_profile(s: Dictionary, z: float) -> float:
	var shore_z: float = s.get("dock_length", 10.0) - 6.0
	var z0 := shore_z - RAMP_UNDERWATER
	var z1 := shore_z + RAMP_ON_LAND
	var top: float = s.get("_ramp_top", 0.4)
	return lerpf(RAMP_BOTTOM, top, clampf((z - z0) / (z1 - z0), 0.0, 1.0))


## Muotoilee maaston ja pohjan luiskan kohdalta hieman luiskan pinnan alle
func _carve_ramps() -> void:
	for s in lake.starts:
		if not s.get("ramp", false):
			continue
		var t := _ramp_transform(s)
		var shore_z: float = s.get("dock_length", 10.0) - 6.0
		var top_world := t * Vector3(RAMP_X, 0.0, shore_z + RAMP_ON_LAND)
		s["_ramp_top"] = maxf(lake.height_at(top_world.x, top_world.z), 0.3) + 0.05
		var inv := t.affine_inverse()
		var reach := RAMP_ON_LAND + RAMP_UNDERWATER + 20.0
		var c0 := floori((s["x"] - reach - lake.origin_x) / lake.cell_size)
		var r0 := floori((s["z"] - reach - lake.origin_z) / lake.cell_size)
		var n := ceili(reach * 2.0 / lake.cell_size)
		for r in range(r0, r0 + n):
			for c in range(c0, c0 + n):
				if c < 0 or r < 0 or c >= lake.cols or r >= lake.rows:
					continue
				var p := Vector3(lake.origin_x + c * lake.cell_size, 0.0, lake.origin_z + r * lake.cell_size)
				var local := inv * p
				var dx := absf(local.x - RAMP_X)
				var z0 := shore_z - RAMP_UNDERWATER - 2.0
				var z1 := shore_z + RAMP_ON_LAND + 2.0
				if dx > RAMP_WIDTH / 2.0 + 3.0 or local.z < z0 or local.z > z1:
					continue
				var target := _ramp_profile(s, local.z) - 0.12
				var i := r * lake.cols + c
				# Luiskan kohdalla tarkasti, reunoilla liukuva siirtymä ympäröivään maastoon
				var blend := clampf(1.0 - (dx - RAMP_WIDTH / 2.0) / 3.0, 0.0, 1.0)
				lake.heights[i] = lerpf(lake.heights[i], minf(lake.heights[i], target) if dx > RAMP_WIDTH / 2.0 else target, blend)


## Osuuko rakennus luiskan tai sen kääntöpaikan alueelle
func _on_ramp_area(center: Vector2, pts: PackedVector2Array) -> bool:
	for s in lake.starts:
		if not s.get("ramp", false):
			continue
		var inv := _ramp_transform(s).affine_inverse()
		var shore_z: float = s.get("dock_length", 10.0) - 6.0
		for p in [center] + Array(pts):
			var local := inv * Vector3(p.x, 0.0, p.y)
			if absf(local.x - RAMP_X) < 9.0 and local.z > shore_z - 2.0 and local.z < shore_z + RAMP_ON_LAND + 14.0:
				return true
	return false


func _build_ramp(dock: Node3D, s: Dictionary) -> void:
	var shore_z: float = s.get("dock_length", 10.0) - 6.0
	var z0 := shore_z - RAMP_UNDERWATER
	var z1 := shore_z + RAMP_ON_LAND
	var y0 := _ramp_profile(s, z0)
	var y1 := _ramp_profile(s, z1)
	var length := Vector2(z1 - z0, y1 - y0).length()
	var slope := atan2(y1 - y0, z1 - z0)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.5, 0.5, 0.48)
	concrete.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.45, 0.45, 0.44)
	dark.roughness = 1.0
	var ramp := Node3D.new()
	# Luiskan solmu kallistetaan kaltevuuden mukaan: paikallinen z kulkee pintaa pitkin
	ramp.position = Vector3(RAMP_X, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	ramp.rotation.x = -slope
	dock.add_child(ramp)
	# Veden alla oleva osa on levän ja liejun tummentama, kuiva osa vaaleaa betonia
	var algae := StandardMaterial3D.new()
	algae.albedo_color = Color(0.2, 0.22, 0.14)
	algae.roughness = 1.0
	var wet_len := clampf((0.05 - y0) / (y1 - y0), 0.0, 1.0) * length # vesirajaan asti
	var dry_len := length - wet_len
	_slab(ramp, Vector3(RAMP_WIDTH, 0.35, wet_len), Vector3(0, -0.175, -length / 2.0 + wet_len / 2.0), algae)
	_slab(ramp, Vector3(RAMP_WIDTH, 0.35, dry_len), Vector3(0, -0.175, length / 2.0 - dry_len / 2.0), concrete)
	# Matalat liukuesteurat kuivassa osassa, reunakivet sivuilla
	var rib := -length / 2.0 + wet_len + 0.3
	while rib < length / 2.0 - 0.2:
		_slab(ramp, Vector3(RAMP_WIDTH - 0.4, 0.012, 0.05), Vector3(0, 0.006, rib), dark)
		rib += 0.35
	for side in [-1.0, 1.0]:
		_slab(ramp, Vector3(0.22, 0.18, wet_len), Vector3(side * (RAMP_WIDTH / 2.0 + 0.11), 0.0, -length / 2.0 + wet_len / 2.0), algae)
		_slab(ramp, Vector3(0.22, 0.18, dry_len), Vector3(side * (RAMP_WIDTH / 2.0 + 0.11), 0.0, length / 2.0 - dry_len / 2.0), dark)
	# Kääntöpaikka yläpäähän: soraa, auto ja tyhjä venetraileri
	var apron_z := z1 + 6.0
	var apron_world := dock.global_transform * Vector3(RAMP_X, 0.0, apron_z)
	var apron_y: float = maxf(lake.height_at(apron_world.x, apron_world.z), y1 - 0.05)
	var gravel := StandardMaterial3D.new()
	gravel.albedo_color = Color(0.42, 0.4, 0.35)
	gravel.roughness = 1.0
	_slab(dock, Vector3(12.0, 1.2, 12.0), Vector3(RAMP_X, apron_y - 0.55, apron_z), gravel)
	var trailer := _trailer()
	trailer.position = Vector3(RAMP_X, apron_y + 0.05, apron_z - 2.2)
	dock.add_child(trailer)
	var car := _car(Color(0.15, 0.3, 0.2))
	car.position = Vector3(RAMP_X, apron_y + 0.05, apron_z + 3.3)
	dock.add_child(car)


func _slab(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = at
	parent.add_child(mi)
	return mi


## Tyhjä venetraileri: runko, kölitelat, pyörät ja aisa autoon päin (+z)
func _trailer() -> Node3D:
	var t := Node3D.new()
	var galv := StandardMaterial3D.new()
	galv.albedo_color = Color(0.7, 0.72, 0.74)
	galv.metallic = 0.7
	galv.roughness = 0.4
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.06, 0.06)
	for x in [-0.6, 0.6]:
		_slab(t, Vector3(0.08, 0.1, 4.2), Vector3(x, 0.55, 0), galv)
	for z in [-1.6, -0.4, 0.8, 1.9]:
		_slab(t, Vector3(1.3, 0.08, 0.08), Vector3(0, 0.55, z), galv)
	_slab(t, Vector3(0.1, 0.1, 1.6), Vector3(0, 0.5, 2.9), galv) # aisa
	for z in [-1.2, 0.0, 1.2]:
		_slab(t, Vector3(0.12, 0.12, 0.3), Vector3(0, 0.68, z), rubber) # kölitelat
	for x in [-0.85, 0.85]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 0.18
		cyl.material = rubber
		wheel.mesh = cyl
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(x, 0.3, 0.1)
		t.add_child(wheel)
	return t


## Parkkipaikka laiturin rannanpuoleisen pään taakse: sorakenttä ja pari autoa
func _parking(dock: Node3D, length: float, width: float) -> void:
	var side_x: float = dock.get_meta("side_x")
	var center_local := Vector3(side_x, 0.0, length + 10.0)
	var center := dock.global_transform * center_local
	var ground_y := lake.height_at(center.x, center.z)
	var lot := MeshInstance3D.new()
	var lot_mesh := BoxMesh.new()
	lot_mesh.size = Vector3(18.0, 1.2, 12.0) # paksu laatta upotetaan rinteeseen
	var gravel := StandardMaterial3D.new()
	gravel.albedo_color = Color(0.42, 0.4, 0.35)
	gravel.roughness = 1.0
	lot_mesh.material = gravel
	lot.mesh = lot_mesh
	lot.position = Vector3(center_local.x, ground_y - 0.55, center_local.z)
	dock.add_child(lot)
	var colors := [Color(0.62, 0.08, 0.06), Color(0.2, 0.25, 0.32), Color(0.85, 0.85, 0.82)]
	for i in colors.size():
		var car := _car(colors[i])
		car.position = Vector3(center_local.x - 5.5 + i * 3.4, ground_y + 0.1, center_local.z + 2.0)
		dock.add_child(car)


## Yksinkertainen henkilöauto: kori, ohjaamo ja renkaat
func _car(color: Color) -> Node3D:
	var car := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.4
	paint.roughness = 0.35
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.12, 0.15, 0.18)
	glass.metallic = 0.6
	glass.roughness = 0.15
	var tire := StandardMaterial3D.new()
	tire.albedo_color = Color(0.06, 0.06, 0.06)
	for part in [[Vector3(1.75, 0.6, 4.3), Vector3(0, 0.6, 0), paint], [Vector3(1.6, 0.55, 2.2), Vector3(0, 1.17, 0.3), glass]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = part[2]
		mi.mesh = box
		mi.position = part[1]
		car.add_child(mi)
	for x in [-0.82, 0.82]:
		for z in [-1.35, 1.35]:
			var wheel := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.32
			cyl.bottom_radius = 0.32
			cyl.height = 0.22
			cyl.material = tire
			wheel.mesh = cyl
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(x, 0.32, z)
			car.add_child(wheel)
	return car
