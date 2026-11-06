class_name Wake
extends MeshInstance3D
## Veneen vana: perän takana vaahtoava kulku-uoma ja sivuille leviävät
## V-muotoiset aallot (Kelvinin aallot, puolikulma n. 19,5°), keulasta kylkiä
## pitkin kulkevat vaahtoviikset matalan läpikuultavan vesiharjanteen päällä
## (keula-aalto) ja kovassa vauhdissa keularoiske. Vanan voimakkuus riippuu
## nopeudesta, keula-aallon voimakkuus nopeudesta eteenpäin. Lisäksi airojen
## vedoista jää pieniä pyörteitä.
##
## Vaahtonauhojen kärjet: VERTEX.y = korkeus pinnan yläpuolella (harjanne),
## UV.x = poikittainen paikka −1 … 1, UV.y = etäisyys peräpeilistä (kulku-uoma),
## UV2.x = nauhan tyyppi (TYPE_*); varjostin pehmentää reunat UV:n mukaan.

const SAMPLE_DISTANCE := 0.7 # m
const LIFETIME := 14.0 # s
const SWIRL_LIFETIME := 5.0
const KELVIN_SPREAD := 0.354 # tan(19,5°)

const TYPE_CHANNEL := 0.0 # kulku-uoma
const TYPE_KELVIN := 1.0 # Kelvinin sivuaalto
const TYPE_WHISKER := 2.0 # keula-aallon vaahtoviiksi
const TYPE_SWIRL := 3.0 # airon pyörre

# Peräaalto
const CHANNEL_WIDTH := 0.5 # kulku-uoman puolileveys perässä (m)
const START_FADE := 1.2 # kulku-uoman alfa 0 → täysi tällä matkalla perästä (m)
const KELVIN_OFFSET := 0.82 # sivuaallon alkukohta perässä sivulle (m)
const KELVIN_WIDTH := 0.3 # sivuaallon puolileveys alussa (m)

# Keula-aalto: voimakkuus k = 0 → 1 nopeudella eteenpäin BOW_MIN → BOW_FULL
const BOW_MIN := 1.2 # m/s
const BOW_FULL := 6.5 # m/s
const WHISKER_ALPHA := 0.85 # PÄÄTÖS 8
const RIDGE_HEIGHT := 0.10 # harjanteen korkeus täydessä vauhdissa (m)
const RIDGE_ALPHA := 0.6
const RIDGE_SEGMENTS := 10
# Keularoiske: nopeudella eteenpäin SPRAY_MIN → SPRAY_FULL 0 → SPRAY_AMOUNT pisaraa/kylki
const SPRAY_MIN := 5.0 # m/s
const SPRAY_FULL := 7.8 # m/s
const SPRAY_AMOUNT := 40

var _samples: Array[Dictionary] = [] # {p, right, speed, t}
var _swirls: Array[Dictionary] = [] # {p, t, size}
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _indices := PackedInt32Array()
var _time := 0.0
var material: ShaderMaterial
## Keula-aallon vaahtoviikset: oma mesh veneen koordinaatistossa (sama materiaali),
## rakennetaan uudelleen vain voimakkuuden muuttuessa
var bow: MeshInstance3D
var _bow_mesh := ArrayMesh.new()
var _bow_verts := PackedVector3Array()
var _bow_colors := PackedColorArray()
var _bow_uvs := PackedVector2Array()
var _bow_uv2s := PackedVector2Array()
var _bow_k := -1.0 # voimakkuus, jolla viikset ja harjanne on rakennettu
## Keulan vesiharjanne: oma mesh veneen koordinaatistossa ja valaistu materiaali (bow_ridge.gdshader)
var ridge: MeshInstance3D
var ridge_material: ShaderMaterial
var _ridge_mesh := ArrayMesh.new()
var _ridge_verts := PackedVector3Array()
var _ridge_normals := PackedVector3Array()
var _ridge_colors := PackedColorArray()
## Keularoiske kummallekin kyljelle: [vasen, oikea]
var spray: Array[CPUParticles3D] = []
## Veneen nykyinen asento (set_hull): keskipiste, keulan suunta, nopeus eteenpäin
var _hull_center := Vector2.ZERO
var _hull_fwd := Vector2.UP
var _hull_speed := 0.0
var _hull_t := -1.0
## Perän nykyinen kohta (track): kulku-uoma jatkuu uusimmasta näytteestä tähän
var _live := {}

## Rungon ääriviivan oikea puoli (Boat.OUTLINE) tiheänä taulukkona:
## {z, x, n (ulospäin, paikallinen x/z), arc (kaarenpituus keulapiikistä)}
static var _side_table: Array[Dictionary] = []


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 1.0
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/wake.gdshader")
	material.render_priority = 2 # vesi → harjanne → vaahto
	material_override = material
	ridge = MeshInstance3D.new()
	ridge.top_level = true
	ridge.mesh = _ridge_mesh
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ridge.extra_cull_margin = 1.0
	ridge_material = ShaderMaterial.new()
	ridge_material.shader = load("res://shaders/bow_ridge.gdshader")
	ridge_material.render_priority = 1
	ridge.material_override = ridge_material
	add_child(ridge)
	bow = MeshInstance3D.new()
	bow.top_level = true
	bow.mesh = _bow_mesh
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bow.extra_cull_margin = 1.0
	bow.material_override = material
	add_child(bow)
	for side in [-1.0, 1.0]:
		spray.append(_make_spray(side))


## Kutsutaan joka fysiikkaruudulla: perän sijainti, veneen sivusuunta ja nopeus
func track(stern: Vector2, right: Vector2, speed: float) -> void:
	_live = {"p": stern, "right": right, "speed": speed, "t": _time}
	if speed < 0.15:
		return
	if _samples.is_empty() or _samples[-1]["p"].distance_to(stern) >= SAMPLE_DISTANCE:
		_samples.append({"p": stern, "right": right, "speed": speed, "t": _time})


## Kutsutaan joka fysiikkaruudulla: veneen keskipiste, keulan suunta ja
## nopeus eteenpäin (peruutuksessa negatiivinen). Keula-aalto piirretään
## veneen nykyisestä asennosta.
func set_hull(center: Vector2, fwd: Vector2, forward_speed: float) -> void:
	_hull_center = center
	_hull_fwd = fwd
	_hull_speed = forward_speed
	_hull_t = _time


func add_swirl(p: Vector2, size := 1.0) -> void:
	_swirls.append({"p": p, "t": _time, "size": size})


## Keula-aallon voimakkuus 0–1 (0 peruutuksessa, paikallaan ja hitaasti)
func bow_strength() -> float:
	if _hull_t < 0.0 or _time - _hull_t > 0.5:
		return 0.0
	return clampf((_hull_speed - BOW_MIN) / (BOW_FULL - BOW_MIN), 0.0, 1.0)


## Keularoiskeen voimakkuus 0–1 (0 alle SPRAY_MIN)
func spray_strength() -> float:
	if _hull_t < 0.0 or _time - _hull_t > 0.5 or _hull_speed < SPRAY_MIN:
		return 0.0
	return clampf((_hull_speed - SPRAY_MIN) / (SPRAY_FULL - SPRAY_MIN), 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	while not _samples.is_empty() and _time - _samples[0]["t"] > LIFETIME:
		_samples.pop_front()
	while not _swirls.is_empty() and _time - _swirls[0]["t"] > SWIRL_LIFETIME:
		_swirls.pop_front()
	_rebuild()
	_update_spray()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	_verts.clear()
	_colors.clear()
	_uvs.clear()
	_uv2s.clear()
	_indices.clear()
	_trail()
	for swirl in _swirls:
		_ring(swirl)
	_rebuild_bow(bow_strength())
	if _indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Peräaalto: kulku-uoma ja sivuaallot näytteistä ja elävästä peräpisteestä.
## Jokaisessa kohdassa 6 kärkeä (kolmen nauhan reunat), nauhat yhdistetään
## indekseillä. Perän lähellä välit jaetaan 0,2 m:n paloiksi, jotta kulku-uoman
## alku häivyttyy tasaisesti.
func _trail() -> void:
	if _samples.is_empty():
		return
	var pts := _samples
	# Elävä nauha uusimmasta näytteestä nykyiseen peräpeiliin: ei rakoa perässä
	if not _live.is_empty() and _samples[-1]["p"].distance_to(_live["p"]) > 0.02:
		pts = _samples.duplicate()
		pts.append(_live)
	var stern: Vector2 = _live["p"] if not _live.is_empty() else pts[-1]["p"]
	var a: Dictionary = pts[0]
	# run = matka vanan vanhimmasta päästä tai aukon jälkeisestä alusta (häivytys, PÄÄTÖS 10)
	var run := 0.0
	var prev := _trail_point(a["p"], a["right"], a["speed"], _time - a["t"], a["p"].distance_to(stern), run)
	for i in range(1, pts.size()):
		var b: Dictionary = pts[i]
		var pa: Vector2 = a["p"]
		var pb: Vector2 = b["p"]
		var gap := pa.distance_to(pb)
		var db := pb.distance_to(stern)
		if gap > SAMPLE_DISTANCE * 4.0:
			# aukko vanassa (vene pysähtyi välillä): uusi alku
			run = 0.0
			prev = _trail_point(pb, b["right"], b["speed"], _time - b["t"], db, run)
			a = b
			continue
		var n := 1
		if minf(pa.distance_to(stern), db) < START_FADE + 0.5 or run < START_FADE + 0.5:
			n = maxi(1, ceili(gap / 0.2))
		for j in range(1, n + 1):
			var f := float(j) / n
			var cur: int
			if j == n:
				cur = _trail_point(pb, b["right"], b["speed"], _time - b["t"], db, run + gap)
			else:
				var p := pa.lerp(pb, f)
				cur = _trail_point(p, (a["right"] as Vector2).lerp(b["right"], f).normalized(),
					lerpf(a["speed"], b["speed"], f), _time - lerpf(a["t"], b["t"], f), p.distance_to(stern), run + gap * f)
			_trail_link(prev, cur)
			prev = cur
		run += gap
		a = b


## Kohdan kärjet: kulku-uoma (vasen, oikea), vasen ja oikea sivuaalto.
## Palauttaa ensimmäisen kärjen indeksin.
func _trail_point(p: Vector2, right: Vector2, speed: float, age: float, d: float, run: float) -> int:
	var base := _verts.size()
	var tail := smoothstep(0.0, START_FADE, run) # vanhin pää ja aukon jälkeinen alku
	# Kulku-uoma perän takana: alkaa peräpeilin levyisenä, levenee ja haalenee
	var w := CHANNEL_WIDTH + age * (0.1 + 0.02 * speed)
	var alpha := clampf((speed - 0.8) / 4.0, 0.0, 0.75) * exp(-age / 4.0) * smoothstep(0.0, START_FADE, d) * tail
	_edge(p - right * w, alpha, -1.0, d, TYPE_CHANNEL)
	_edge(p + right * w, alpha, 1.0, d, TYPE_CHANNEL)
	# Kelvinin aallot molemmille sivuille: leviävät iän ja nopeuden mukaan
	var off := KELVIN_OFFSET + age * speed * KELVIN_SPREAD
	var wk := KELVIN_WIDTH + age * 0.04
	var ak := clampf((speed - 0.6) / 3.5, 0.0, 0.55) * exp(-age / 5.0) * tail
	for side in [-1.0, 1.0]:
		var c: Vector2 = p + right * (side * off)
		_edge(c - right * wk, ak, -1.0, d, TYPE_KELVIN)
		_edge(c + right * wk, ak, 1.0, d, TYPE_KELVIN)
	return base


func _edge(p: Vector2, alpha: float, u: float, d: float, type: float) -> void:
	_verts.append(Vector3(p.x, 0.0, p.y))
	_colors.append(Color(1, 1, 1, alpha))
	_uvs.append(Vector2(u, d))
	_uv2s.append(Vector2(type, 0.0))


## Kahden kohdan väliset nauhat (näkymättömät jätetään pois)
func _trail_link(a: int, b: int) -> void:
	for band in 3:
		var a0 := a + band * 2
		var b0 := b + band * 2
		if _colors[a0].a < 0.01 and _colors[b0].a < 0.01:
			continue
		_indices.append_array([a0, a0 + 1, b0 + 1, a0, b0 + 1, b0])


## Airon pyörre: laajeneva, haalistuva rengas
func _ring(swirl: Dictionary) -> void:
	var age: float = _time - swirl["t"]
	var r: float = (0.12 + age * 0.12) * swirl["size"]
	var w := 0.04 + age * 0.02
	var alpha := 0.35 * exp(-age / 1.4)
	var c: Vector2 = swirl["p"]
	var segments := 14
	var base := _verts.size()
	for i in segments:
		var d := Vector2.from_angle(TAU * i / segments)
		_edge(c + d * (r - w), alpha, 0.0, 0.0, TYPE_SWIRL)
		_edge(c + d * (r + w), alpha, 0.0, 0.0, TYPE_SWIRL)
	for i in segments:
		var a0 := base + i * 2
		var b0 := base + ((i + 1) % segments) * 2
		_indices.append_array([a0, a0 + 1, b0 + 1, a0, b0 + 1, b0])


# --- Keula-aalto ---------------------------------------------------------------

## Ääriviivan oikea puoli keulapiikistä peräpeiliin 0,1 m:n z-välein
static func _outline_table() -> Array[Dictionary]:
	if not _side_table.is_empty():
		return _side_table
	var side: Array[Vector2] = []
	for o in Boat.OUTLINE:
		if o.x >= 0.0 and (side.is_empty() or o.y > side[-1].y):
			side.append(o)
	var arc := 0.0
	var prev := Vector2.ZERO
	var steps := roundi((side[-1].y - side[0].y) / 0.1)
	for i in steps + 1:
		var z := side[0].y + (side[-1].y - side[0].y) * i / steps
		var p := Vector2(_outline_x(side, z), z)
		if i > 0:
			arc += p.distance_to(prev)
		prev = p
		# Ulospäin osoittava normaali tasoitettuna ±0,15 m:n matkalta
		var t := Vector2(_outline_x(side, z + 0.15) - _outline_x(side, z - 0.15), 0.3).normalized()
		_side_table.append({"z": z, "x": p.x, "n": Vector2(t.y, -t.x), "arc": arc})
	return _side_table


static func _outline_x(side: Array[Vector2], z: float) -> float:
	z = clampf(z, side[0].y, side[-1].y)
	for i in range(side.size() - 1):
		if z <= side[i + 1].y:
			return lerpf(side[i].x, side[i + 1].x, (z - side[i].y) / (side[i + 1].y - side[i].y))
	return side[-1].x


## Oikean puolen ääriviivan kohta kaarenpituudella arc: {p (paikallinen x/z), n}
static func outline_at(arc: float) -> Dictionary:
	var tab := _outline_table()
	arc = clampf(arc, 0.0, tab[-1]["arc"])
	for i in range(tab.size() - 1):
		var a: Dictionary = tab[i]
		var b: Dictionary = tab[i + 1]
		if arc <= b["arc"]:
			var f: float = (arc - a["arc"]) / maxf(b["arc"] - a["arc"], 1e-6)
			return {"p": Vector2(lerpf(a["x"], b["x"], f), lerpf(a["z"], b["z"], f)),
				"n": a["n"].lerp(b["n"], f).normalized()}
	return {"p": Vector2(tab[-1]["x"], tab[-1]["z"]), "n": tab[-1]["n"]}


## Kaarenpituus keulapiikistä kohtaan z (oikea puoli)
static func _arc_at_z(z: float) -> float:
	var tab := _outline_table()
	for i in range(tab.size() - 1):
		if z <= tab[i + 1]["z"]:
			var a: Dictionary = tab[i]
			var b: Dictionary = tab[i + 1]
			return lerpf(a["arc"], b["arc"], (z - a["z"]) / (b["z"] - a["z"]))
	return tab[-1]["arc"]


## Keula-aallon alkupiste: (kaarenpituus keulapiikistä, kyljen pituus siitä peräpeiliin).
## Hitaasti z = −1,9, täydessä vauhdissa z = −1,5.
static func bow_start(k: float) -> Vector2:
	var arc0 := _arc_at_z(lerpf(-1.9, -1.5, k))
	return Vector2(arc0, _outline_table()[-1]["arc"] - arc0)


## Paikallinen kohta (x oikealle, z perään) maailmaan
func _to_world(local: Vector2) -> Vector2:
	var right := Vector2(-_hull_fwd.y, _hull_fwd.x)
	return _hull_center + right * local.x - _hull_fwd * local.y


## Harjanteen pituussuuntainen muoto e(s): 0 → 1 (s = 0 … 0,3), 1 → 0 (0,3 … 1)
static func _ridge_envelope(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return smoothstep(0.0, 0.3, u) if u < 0.3 else 1.0 - smoothstep(0.3, 1.0, u)


## Harjanteen poikkiprofiili 0–1 etäisyydellä o ääriviivasta (sisäreuna 0,4)
static func _ridge_profile(k: float, o: float) -> float:
	var wk := 0.5 + 0.5 * k
	var crest := 0.12 * wk
	if o < 0.0:
		return 0.0
	if o <= crest:
		return lerpf(0.4, 1.0, o / crest)
	var x := (o - crest) / (0.5 * wk)
	return 0.0 if x >= 1.0 else 0.5 * (1.0 + cos(PI * x))


## Harjanteen korkeus pinnan yläpuolella: s = kaarenpituus keula-aallon
## alkupisteestä, o = etäisyys ääriviivasta ulospäin
static func ridge_height(k: float, s: float, o: float) -> float:
	if k <= 0.0:
		return 0.0
	return RIDGE_HEIGHT * k * _ridge_envelope(s / (0.6 + 1.6 * k)) * _ridge_profile(k, o)


## Harjanteen alfa: 0 sisä- ja ulkoreunalla ja päissä; hitaasti himmeämpi (PÄÄTÖS 6)
static func ridge_alpha(k: float, s: float, o: float) -> float:
	if k <= 0.0 or o <= 0.0:
		return 0.0
	var crest := 0.12 * (0.5 + 0.5 * k)
	var across := o / crest if o <= crest else _ridge_profile(k, o)
	return RIDGE_ALPHA * minf(1.0, k / 0.3) * _ridge_envelope(s / (0.6 + 1.6 * k)) * across


## Viikset ja harjanne veneen koordinaatistossa (x oikealle, z perään):
## rakennetaan uudelleen, kun voimakkuus muuttuu, ja siirretään joka ruutu veneen mukana
func _rebuild_bow(k: float) -> void:
	# Alaspäin pyöristys: hidas soutu ei kirkastu pyöristyksen takia
	var kq := floorf(k * 100.0) / 100.0
	if k > 0.0 and kq <= 0.0:
		kq = 0.01
	bow.visible = kq > 0.0
	ridge.visible = kq > 0.0
	if kq > 0.0:
		var yaw := atan2(-_hull_fwd.x, -_hull_fwd.y)
		var t := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(_hull_center.x, 0.0, _hull_center.y))
		bow.global_transform = t
		ridge.global_transform = t
	if kq == _bow_k:
		return
	_bow_k = kq
	_rebuild_ridge(kq)
	_bow_mesh.clear_surfaces()
	_bow_verts.clear()
	_bow_colors.clear()
	_bow_uvs.clear()
	_bow_uv2s.clear()
	if kq <= 0.0:
		return
	for side in [-1.0, 1.0]:
		_whisker(side, kq)
	if _bow_verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _bow_verts
	arrays[Mesh.ARRAY_COLOR] = _bow_colors
	arrays[Mesh.ARRAY_TEX_UV] = _bow_uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _bow_uv2s
	_bow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _rebuild_ridge(k: float) -> void:
	_ridge_mesh.clear_surfaces()
	_ridge_verts.clear()
	_ridge_normals.clear()
	_ridge_colors.clear()
	if k <= 0.0:
		return
	var start := bow_start(k)
	var length := 0.6 + 1.6 * k
	var wk := 0.5 + 0.5 * k
	var offsets := [0.0, 0.12 * wk]
	for x in [0.25, 0.5, 0.75, 1.0]:
		offsets.append(0.12 * wk + 0.5 * wk * x)
	for side in [-1.0, 1.0]:
		var grid := [] # [rivi][sarake] = [kohta, normaali, alfa]
		for i in RIDGE_SEGMENTS + 1:
			var s := length * i / RIDGE_SEGMENTS
			var ol := outline_at(start.x + s)
			var row := []
			for o in offsets:
				row.append(_ridge_vertex(k, side, s, o, ol))
			grid.append(row)
		for i in RIDGE_SEGMENTS:
			for j in offsets.size() - 1:
				var quad := [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
				for idx in [0, 1, 2, 0, 2, 3]:
					_ridge_verts.append(quad[idx][0])
					_ridge_normals.append(quad[idx][1])
					_ridge_colors.append(Color(1, 1, 1, quad[idx][2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _ridge_verts
	arrays[Mesh.ARRAY_NORMAL] = _ridge_normals
	arrays[Mesh.ARRAY_COLOR] = _ridge_colors
	_ridge_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Harjanteen kärki veneen koordinaatistossa: [kohta (y = korkeus pinnan
## yläpuolella), normaali, alfa]
static func _ridge_vertex(k: float, side: float, s: float, o: float, ol: Dictionary) -> Array:
	var n: Vector2 = ol["n"]
	var t := Vector2(-n.y, n.x) # ääriviivan suunta perään päin
	var local: Vector2 = ol["p"] + n * o
	local.x *= side
	var nl := Vector2(n.x * side, n.y)
	var tl := Vector2(t.x * side, t.y)
	# Normaali profiilin kaltevuudesta: poikittain (ulospäin) ja pituussuunnassa
	var e := 0.02
	var o0 := maxf(o - e, 0.0)
	var s0 := maxf(s - e, 0.0)
	var dh_o := (ridge_height(k, s, o + e) - ridge_height(k, s, o0)) / (o + e - o0)
	var dh_s := (ridge_height(k, s + e, o) - ridge_height(k, s0, o)) / (s + e - s0)
	var grad := nl * dh_o + tl * dh_s
	var normal := Vector3(-grad.x, 1.0, -grad.y).normalized()
	return [Vector3(local.x, ridge_height(k, s, o), local.y), normal, ridge_alpha(k, s, o)]


## Vaahtoviiksi kyljellä side (−1 vasen, 1 oikea): keulan alkupisteestä
## kylkeä pitkin, aukeaa ulospäin ja kulkee harjanteen harjalla
func _whisker(side: float, k: float) -> void:
	var start := bow_start(k)
	var side_len := start.y
	var nominal := 0.8 + k * side_len
	var length := minf(nominal, side_len)
	var hw := 0.06 + 0.16 * k
	var steps := maxi(4, ceili(length / 0.3))
	var rows := []
	for i in steps + 1:
		var s := length * i / steps
		var ol := outline_at(start.x + s)
		var n: Vector2 = ol["n"]
		var dc := lerpf(0.10, 0.2, s / side_len) # nauhan keskiviiva ääriviivasta (PÄÄTÖS 8)
		var o_in := maxf(dc - hw, 0.0)
		var o_out := dc + hw
		# Kärki pyöristetään 0,3 m:n matkalla. Ennen peräpeiliä loppuva viiksi
		# häivytetään myös lopusta; peräpeiliin ylettyvä jatkuu sivuaaltoon (PÄÄTÖS 7).
		var a := WHISKER_ALPHA * k * smoothstep(0.0, 0.3, s) * smoothstep(0.0, 0.3, nominal - s)
		var row := []
		for f in [0.0, 0.35, 0.65, 1.0]:
			var o: float = lerpf(o_in, o_out, f)
			var local: Vector2 = ol["p"] + n * o
			local.x *= side
			var alpha := 0.0 if f == 0.0 or f == 1.0 else a
			row.append([Vector3(local.x, ridge_height(k, s, o), local.y), alpha, (o - dc) / hw, f, s])
		rows.append(row)
	for i in steps:
		for j in 3:
			var quad := [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
			if quad[0][1] < 0.005 and quad[1][1] < 0.005 and quad[2][1] < 0.005 and quad[3][1] < 0.005:
				continue
			for idx in [0, 1, 2, 0, 2, 3]:
				# UV.y = sarake 0–1 (sisä- ja ulkoreuna), UV2.y = matka alkupisteestä (testiä varten)
				var v: Array = quad[idx]
				_bow_verts.append(v[0])
				_bow_colors.append(Color(1, 1, 1, v[1]))
				_bow_uvs.append(Vector2(v[2], v[3]))
				_bow_uv2s.append(Vector2(TYPE_WHISKER, v[4]))


## Testejä varten: viiksien kärjet maailmassa ({verts, colors, uvs, uv2s})
func whisker_world() -> Dictionary:
	var out := PackedVector3Array()
	var t := bow.global_transform
	for v in _bow_verts:
		out.append(t * v)
	return {"verts": out, "colors": _bow_colors, "uvs": _bow_uvs, "uv2s": _bow_uv2s} if bow.visible else {"verts": PackedVector3Array(), "colors": PackedColorArray(), "uvs": PackedVector2Array(), "uv2s": PackedVector2Array()}


## Testejä varten: harjanteen kärjet maailmassa (tyhjä, kun harjannetta ei ole)
func ridge_world() -> PackedVector3Array:
	var out := PackedVector3Array()
	if not ridge.visible:
		return out
	var t := ridge.global_transform
	for v in _ridge_verts:
		out.append(t * v)
	return out


# --- Keularoiske ---------------------------------------------------------------

func _make_spray(side: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.local_coords = true # pisarat seuraavat keulaa: lentävät ulos ja vähän taakse
	p.emitting = false
	p.amount = SPRAY_AMOUNT # aina sama: määrän muutos nollaisi pisarat (PÄÄTÖS 9)
	p.lifetime = 0.3 # pisara häipyy ennen kuin putoaa veteen (PÄÄTÖS 10)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.04
	# Paikallisesti x oikealle, y ylös, z perään: ulos, ylös ja vähän taakse
	p.direction = Vector3(side * 1.3, 1.1, 0.3).normalized()
	p.spread = 15.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	# Alfa täysi 35 %:iin elinajasta, poissa 65 %:ssa (0,195 s)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.set_offset(1, 0.65)
	fade.add_point(0.35, Color(1, 1, 1, 1))
	p.color_ramp = fade
	var drop := SphereMesh.new()
	drop.radius = 0.01
	drop.height = 0.02
	drop.radial_segments = 6
	drop.rings = 3
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.72, 0.82, 0.86, 0.55)
	water.vertex_color_use_as_albedo = true
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	drop.material = water
	p.mesh = drop
	add_child(p)
	return p


## Roiske keula-aallon alkupisteestä kummaltakin keulaolkapäältä. Määrä pysyy
## samana; voimakkuus tulee pisaroiden alfasta ja koosta (PÄÄTÖS 9).
func _update_spray() -> void:
	var r := spray_strength()
	var on := r > 0.0
	var ol := outline_at(bow_start(bow_strength()).x)
	var yaw := atan2(-_hull_fwd.x, -_hull_fwd.y)
	for i in spray.size():
		var p := spray[i]
		if p.emitting != on:
			p.emitting = on
		if not on:
			continue
		var mat: StandardMaterial3D = p.mesh.material
		mat.albedo_color.a = 0.55 * (0.3 + 0.7 * r)
		p.scale_amount_max = 1.3 * (0.6 + 0.4 * r)
		var local: Vector2 = ol["p"] + ol["n"] * 0.08
		local.x *= -1.0 if i == 0 else 1.0
		var w := _to_world(local)
		p.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(w.x, Waves.swell_height(w) + 0.08, w.y))
