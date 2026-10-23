class_name GillNet
extends Node3D
## Järveen laskettu verkko: merkkipyykit päissä. Lasketessa verkko valuu
## löysänä nippuna oikean laidan yli perän läheltä veteen ja purkautuu veneen
## reitille (piste metrin välein); pohjassa se ei näy humusvedessä. Nostettaessa
## verkko nousee samalla tavalla löysänä vedestä laidan yli veneen pohjalle
## kasaan, ja kalat tulevat näkyviin verkossa roikkumassa, kun niiden kohta
## nousee pinnasta. Verkon tiedot ovat Nets-muotoisessa sanakirjassa (data).

signal fish_up(index: int) # nostettava kala tuli veneeseen (haul_fish[index])
signal hauled

enum State { LAYING, SET, HAULING }

const HAUL_SPEED := 0.5 # m/s: verkkoa vedetään vuorokäsin
const SIDE_RAIL := Vector3(0.7, 0.52, 1.6) # verkko kulkee oikean laidan yli perän läheltä (rungon koordinaatit)
const PILE := Vector3(0.3, -0.1, 0.85) # verkkokasa veneen pohjalla nostajan edessä
const LOOSE_OUT := 0.45 # m: verkko painuu veteen näin kaukana laidasta
const LOOSE_BACK := 0.9 # m: ja näin paljon laitakohdan takana
const LOOSE_STRANDS := 9 # löysän verkkonipun lankoja
const LOOSE_SEGMENTS := 14
const NET_COLOR := Color(0.72, 0.64, 0.46) # vaalea nailonverkko
const SHOW_AHEAD := 1.6 # m: kala tulee pinnasta näkyviin tämän matkan ennen laitaa

var boat: Boat
var lake: LakeData
var data: Dictionary = {}
var state := State.SET
var laid_length := 0.0
## Nosto: verkon linja nostopäästä alkaen ja kalat {entry, at_m} nostojärjestyksessä
var haul_s := 0.0
var haul_fish: Array = []
var _haul_pts := PackedVector2Array()
var _haul_length := 0.0
var _next_fish := 0
var _buoys: Array[Node3D] = []
var _loose: MeshInstance3D # laskettava tai nostettava verkko laidan yli ja kasa veneessä
var _loose_mesh: ImmediateMesh
var _fish_nodes: Array[MeshInstance3D] = []
var _time := 0.0


func setup(boat_node: Boat, lake_data: LakeData, net_data: Dictionary, laying: bool) -> void:
	boat = boat_node
	lake = lake_data
	data = net_data
	top_level = true
	state = State.LAYING if laying else State.SET
	laid_length = Nets.length_of(data)
	for i in 2:
		var b := _build_buoy()
		add_child(b)
		_buoys.append(b)
	_loose_mesh = ImmediateMesh.new()
	_loose = MeshInstance3D.new()
	_loose.mesh = _loose_mesh
	var thread := StandardMaterial3D.new()
	thread.albedo_color = NET_COLOR
	thread.roughness = 1.0
	thread.cull_mode = BaseMaterial3D.CULL_DISABLED
	_loose.material_override = thread
	_loose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_loose)
	_place()


## Verkon vesikohta laskiessa ja nostaessa: laidan vieressä hieman laitakohdan takana
static func lay_entry(b: Boat) -> Vector2:
	var rail := b.hull.global_transform * SIDE_RAIL
	return Vector2(rail.x, rail.z) + b.right() * LOOSE_OUT - b.forward() * LOOSE_BACK


func points() -> PackedVector2Array:
	return Nets.points(data)


## Pyykkien paikat: laskun alku ja loppu
func ends() -> Array:
	var pts := points()
	if pts.is_empty():
		return []
	return [pts[0], pts[pts.size() - 1]]


## Lähempi pää veneen perästä ja sen etäisyys: [indeksi 0/1, metriä]
func nearest_end(p: Vector2) -> Array:
	var e := ends()
	if e.is_empty():
		return [0, INF]
	var d0: float = p.distance_to(e[0])
	var d1: float = p.distance_to(e[1])
	return [0, d0] if d0 <= d1 else [1, d1]


## Lasku: perä kulkee, ja verkkoa purkautuu reitille metrin välein
func lay_step(stern: Vector2) -> void:
	var flat: Array = data["points"]
	var last := Vector2(flat[flat.size() - 2], flat[flat.size() - 1])
	var d := stern.distance_to(last)
	if d >= 1.0:
		var room := Nets.LENGTH - laid_length
		var p := last + (stern - last) * minf(1.0, room / d)
		flat.append(p.x)
		flat.append(p.y)
		laid_length += minf(d, room)


func finish_laying() -> void:
	state = State.SET
	laid_length = Nets.length_of(data)
	_place()


## Nosto alkaa pyykin päästä end (0/1); fish = [{entry, at}] (at 0..1 laskusuunnassa)
func start_haul(end: int, fish: Array) -> void:
	state = State.HAULING
	_haul_pts = points()
	if end == 1:
		_haul_pts.reverse()
	_haul_length = Nets.length_of(data)
	haul_s = 0.0
	_next_fish = 0
	haul_fish = []
	for f in fish:
		var at: float = f["at"] if end == 0 else 1.0 - f["at"]
		haul_fish.append({"entry": f["entry"], "at_m": at * _haul_length})
	haul_fish.sort_custom(func(a, b): return a["at_m"] < b["at_m"])
	for f in haul_fish:
		var mi := MeshInstance3D.new()
		var sp: String = f["entry"]["species"]
		if FishModels.PROFILES.has(sp):
			mi.mesh = FishModels.mesh(sp)
			var mat: ShaderMaterial = FishModels.material(sp).duplicate()
			mat.set_shader_parameter("swim_rate", 1.4) # kala rimpuilee verkossa
			mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_fish_nodes.append(mi)


## Piste nostettavalla linjalla s metrin päässä nostopäästä
func haul_point(s: float) -> Vector2:
	if _haul_length <= 0.0:
		return _haul_pts[0] if not _haul_pts.is_empty() else Vector2.ZERO
	return Nets.point_at(_haul_pts, s / _haul_length)


## Nosto etenee; palauttaa true, kun verkko on veneessä
func haul_step(dt: float) -> bool:
	haul_s = minf(haul_s + HAUL_SPEED * dt, _haul_length)
	while _next_fish < haul_fish.size() and haul_fish[_next_fish]["at_m"] <= haul_s:
		_fish_nodes[_next_fish].visible = false
		fish_up.emit(_next_fish)
		_next_fish += 1
	if haul_s >= _haul_length - 0.01:
		while _next_fish < haul_fish.size():
			fish_up.emit(_next_fish)
			_next_fish += 1
		hauled.emit()
		return true
	return false


## Kalastajan kädet verkolla laidan yllä: vuorokäsin vedettäessä toinen käsi
## ojentuu laidan yli verkkoon ja toinen vetää sitä veneeseen
func hand_points() -> Array:
	var rail := boat.hull.global_transform * SIDE_RAIL
	var b := boat.hull.global_basis
	var f := fmod(_time * 0.8, 1.0)
	var reach := sin(f * TAU) * 0.5 + 0.5
	var base := rail - b.x * 0.2 + b.y * 0.1
	return [base + b.x * 0.15 * reach + b.z * 0.08 + b.y * 0.08 * reach, base + b.x * 0.15 * (1.0 - reach) - b.z * 0.08 + b.y * 0.08 * (1.0 - reach)]


func _process(delta: float) -> void:
	_time += delta
	_place()


func _place() -> void:
	if boat == null or boat.hull == null:
		return
	var e := ends()
	for i in 2:
		var b := _buoys[i]
		var shown := not e.is_empty()
		if state == State.LAYING:
			shown = shown and i == 0 # toinen pyykki on vielä veneessä
		elif state == State.HAULING:
			shown = shown and i != _haul_start_index() # nostopään pyykki otettiin veneeseen
		b.visible = shown
		if shown:
			var p: Vector2 = e[i]
			var tilt := sin(_time * 1.3 + i * 2.0) * 0.08
			b.global_transform = Transform3D(Basis(Vector3.RIGHT, tilt) * Basis(Vector3.FORWARD, tilt * 0.6), Vector3(p.x, Waves.swell_height(p), p.y))
	_loose.visible = state != State.SET
	if state == State.LAYING:
		_draw_loose(1.0 - laid_length / Nets.LENGTH) # kasa pienenee
	elif state == State.HAULING:
		_draw_loose(haul_s / maxf(_haul_length, 0.1)) # kasa kasvaa
		_place_fish()


## Verkossa roikkuvat kalat: kala nousee pinnasta (ahead = SHOW_AHEAD) laidalle
## (ahead = 0) verkon mukana, kidukset silmässä ja pyrstö roikkuen
func _place_fish() -> void:
	var a := boat.hull.global_transform * SIDE_RAIL
	var w := _water_point()
	var out := Vector3(boat.right().x, 0.0, boat.right().y)
	for i in haul_fish.size():
		var node := _fish_nodes[i]
		var ahead: float = haul_fish[i]["at_m"] - haul_s
		node.visible = i >= _next_fish and ahead <= SHOW_AHEAD and node.mesh != null
		if not node.visible:
			continue
		var t := clampf(ahead / SHOW_AHEAD, 0.0, 1.0)
		var len_m: float = haul_fish[i]["entry"]["length"] / 100.0
		var at := _loose_point(a, w, t, (float(i % 3) - 1.0) * 0.25, i)
		# Pää verkkoon päin (veneeseen ja ylös), pyrstö roikkuu laidan ulkopuolella
		var head := (Vector3.UP * 0.75 - out * 0.65).normalized()
		var swing := sin(_time * 6.0 + i * 1.3) * 0.25 # rimpuilee
		var basis := Basis.looking_at(head, out) * Basis(Vector3.FORWARD, swing)
		var body := at + out * 0.04 - head * len_m * 0.5
		body.y = maxf(body.y, Waves.swell_height(Vector2(body.x, body.z)) - len_m * 0.3)
		node.global_transform = Transform3D(basis.scaled(Vector3.ONE * len_m), body)


func _haul_start_index() -> int:
	if _haul_pts.is_empty():
		return 0
	return 0 if _haul_pts[0].is_equal_approx(ends()[0]) else 1


func _water_point() -> Vector3:
	var w2 := lay_entry(boat)
	return Vector3(w2.x, Waves.swell_height(w2), w2.y)


## Löysän verkon piste: t = 0 laidalla, 1 vedessä; off = kohta nipun leveydellä (-0,5..0,5)
func _loose_point(a: Vector3, w: Vector3, t: float, off: float, k: int) -> Vector3:
	var out := Vector3(boat.right().x, 0.0, boat.right().y)
	var flat := Vector3(w.x - a.x, 0.0, w.z - a.z)
	var across := flat.normalized().cross(Vector3.UP).normalized() if flat.length() > 0.01 else boat.hull.global_basis.z
	var p := a.lerp(w, t)
	p += Vector3.DOWN * 0.22 * 4.0 * t * (1.0 - t) + out * 0.08 * sin(PI * t) # löysä kaari
	p += across * off * lerpf(0.05, 0.55, t) # nippu levenee vettä kohti
	p += (across * 0.03 + Vector3.UP * 0.02) * sin(t * 9.0 + k * 1.7 + _time * 1.6) * t
	p.y = maxf(p.y, Waves.swell_height(Vector2(p.x, p.z)) - 0.02)
	return p


## Löysä verkkonippu laidan yli veteen ja verkkokasa veneen pohjalla (pile 0..1).
## Langat kaartuvat löysänä alaspäin, nippu levenee vettä kohti, ja poikittaiset
## langat antavat silmäkuvion; laidan molemmin puolin roikkuu lyhyitä lankoja.
func _draw_loose(pile: float) -> void:
	var m := _loose_mesh
	m.clear_surfaces()
	var a := boat.hull.global_transform * SIDE_RAIL
	var w := _water_point()
	var out := Vector3(boat.right().x, 0.0, boat.right().y)
	var strands: Array[PackedVector3Array] = []
	for k in LOOSE_STRANDS:
		var off := float(k) / (LOOSE_STRANDS - 1) - 0.5
		var pts := PackedVector3Array()
		for i in LOOSE_SEGMENTS + 1:
			pts.append(_loose_point(a, w, float(i) / LOOSE_SEGMENTS, off, k))
		strands.append(pts)
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for pts in strands:
		_ribbons(m, pts, 0.006)
	# Laidalta kasaan veneen sisään
	var hull := boat.hull.global_transform
	var pile_top := hull * (PILE + Vector3.UP * 0.1 * pile)
	for k in 4:
		var side := hull.basis.z * (k - 1.5) * 0.06
		_ribbons(m, PackedVector3Array([a + side, a.lerp(pile_top, 0.5) + side * 1.5 + Vector3.UP * 0.05, pile_top + side * 2.0]), 0.006)
	# Verkkokasa: lenkkejä päällekkäin sitä enemmän, mitä enemmän verkkoa on veneessä
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for k in int(4 + 14 * pile):
		var c := hull * (PILE + Vector3(rng.randf_range(-0.15, 0.15), 0.1 * pile * rng.randf(), rng.randf_range(-0.2, 0.2)))
		var r := rng.randf_range(0.07, 0.16)
		var loop := PackedVector3Array()
		var phase := rng.randf() * TAU
		for i in 13:
			var ang := phase + i * TAU / 12.0
			var rr := r * (0.75 + 0.5 * absf(sin(ang * 1.7 + phase * 3.0))) # lenkit ovat mutkaisia
			loop.append(c + hull.basis.x * cos(ang) * rr + hull.basis.z * sin(ang) * rr * 1.3 + hull.basis.y * sin(ang * 2.0 + phase) * 0.02)
		_ribbons(m, loop, 0.005)
	# Laidan ulkopuolella roikkuvia lyhyitä lankoja
	for k in 5:
		var top := a + boat.hull.global_basis.z * (k - 2) * 0.05
		var sway := sin(_time * 1.3 + k) * 0.03
		var hang := PackedVector3Array([top, top + out * 0.06 + Vector3.DOWN * 0.12, top + out * (0.08 + sway) + Vector3.DOWN * (0.22 + 0.04 * (k % 2))])
		_ribbons(m, hang, 0.005)
	m.surface_end()
	# Silmäkuvio: vinot langat vierekkäisten lankojen välillä
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in LOOSE_STRANDS - 1:
		for i in range(1, LOOSE_SEGMENTS):
			var j := i + (1 if (i + k) % 2 == 0 else -1)
			m.surface_add_vertex(strands[k][i])
			m.surface_add_vertex(strands[k + 1][j])
	m.surface_end()


## Ohut lanka kahtena ristikkäisenä nauhana, jotta se näkyy joka suunnasta
func _ribbons(m: ImmediateMesh, pts: PackedVector3Array, width: float) -> void:
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var d := (p1 - p0).normalized()
		var s1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized() * width
		var s2 := d.cross(s1).normalized() * width
		for s in [s1, s2]:
			m.surface_add_vertex(p0 - s)
			m.surface_add_vertex(p1 - s)
			m.surface_add_vertex(p1 + s)
			m.surface_add_vertex(p0 - s)
			m.surface_add_vertex(p1 + s)
			m.surface_add_vertex(p0 + s)


## Merkkipyykki: kelluva koho, keppi ja oranssi lippu
func _build_buoy() -> Node3D:
	var root := Node3D.new()
	var float_mat := StandardMaterial3D.new()
	float_mat.albedo_color = Color(0.95, 0.4, 0.08)
	float_mat.roughness = 0.6
	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = Color(0.25, 0.2, 0.14)
	stick_mat.roughness = 0.9
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.95, 0.35, 0.05)
	flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := CylinderMesh.new()
	body.top_radius = 0.09
	body.bottom_radius = 0.09
	body.height = 0.16
	body.radial_segments = 10
	_part(root, body, Vector3(0, 0.03, 0), float_mat)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.012
	stick.bottom_radius = 0.016
	stick.height = 1.3
	stick.radial_segments = 6
	_part(root, stick, Vector3(0, 0.6, 0), stick_mat)
	var flag := QuadMesh.new()
	flag.size = Vector2(0.28, 0.2)
	_part(root, flag, Vector3(0.15, 1.12, 0), flag_mat)
	return root


func _part(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)
