class_name Birds
extends Node3D
## Linnut taivaalla: varis, korppi, sorsa, hanhi, lokki ja (harvinaisempi) merikotka.
## Parvi tai yksittäinen lintu ilmestyy kauas, lentää järven yli tai kaartelee
## hetken veneen lähistöllä ja katoaa taas. Linnut ääntelevät lähellä ollessaan
## (sound_event), ja kalastaja huudahtaa nähdessään kotkan (eagle_seen).
## Muuttolinnut (sorsa, hanhi, lokki) ovat poissa talvella, ja yöllä ei lennetä.
## Mallit tehdään koodissa: ruumis on kartiomainen putki ja siivet litteät
## monikulmiot, joita bird.gdshader taivuttaa.

signal sound_event(sound: String, at: Vector3)
signal eagle_seen

## Lajit:
## span, length    siipien kärkiväli ja ruumiin pituus (m)
## chord           siiven leveys tyvestä ja kärjestä (m), sweep = kärjen taaksepäin kallistus (m)
## neck            kaulan ja pään pituus ruumiin edessä (m)
## colors          ruumis, pää, siipi, siiven kärki, pyrstö
## flap            räpyttelytaajuus (Hz) ja siiven liikelaajuus (rad)
## glide           osuus ajasta liidossa (0 = räpyttelee koko ajan)
## dihedral        siipien yläkulma liidossa (rad)
## speed           lentonopeus (m/s), altitude = lentokorkeus (m)
## flock           parven koko [min, max], formation: line, v, loose
## circle          todennäköisyys kaarrella veneen lähistöllä läpilennon sijaan
## weight          yleisyys (kotka harvinainen), winter = viihtyy talvellakin
## call            äänen väli sekunteina [min, max]
const SPECIES := {
	"varis": {
		"name": "Varis", "span": 0.95, "length": 0.47, "chord": [0.2, 0.1], "sweep": 0.06, "neck": 0.1,
		"colors": [Color(0.5, 0.5, 0.5), Color(0.05, 0.05, 0.06), Color(0.06, 0.06, 0.07), Color(0.04, 0.04, 0.05), Color(0.05, 0.05, 0.06)],
		"flap": [3.6, 0.55], "glide": 0.25, "dihedral": 0.06, "speed": 11.0, "altitude": [14.0, 45.0],
		"flock": [1, 3], "formation": "loose", "circle": 0.25, "weight": 3.0, "winter": true, "call": [4.0, 12.0],
	},
	"korppi": {
		"name": "Korppi", "span": 1.25, "length": 0.62, "chord": [0.24, 0.12], "sweep": 0.1, "neck": 0.13,
		"colors": [Color(0.04, 0.04, 0.05), Color(0.03, 0.03, 0.04), Color(0.04, 0.04, 0.05), Color(0.03, 0.03, 0.04), Color(0.03, 0.03, 0.04)],
		"flap": [3.0, 0.5], "glide": 0.45, "dihedral": 0.08, "speed": 12.0, "altitude": [25.0, 70.0],
		"flock": [1, 2], "formation": "loose", "circle": 0.5, "weight": 1.5, "winter": true, "call": [5.0, 14.0],
	},
	"sorsa": {
		"name": "Sorsa", "span": 0.9, "length": 0.58, "chord": [0.16, 0.08], "sweep": 0.12, "neck": 0.18,
		"colors": [Color(0.48, 0.43, 0.36), Color(0.06, 0.3, 0.14), Color(0.42, 0.38, 0.32), Color(0.3, 0.27, 0.23), Color(0.15, 0.14, 0.13)],
		"flap": [6.5, 0.6], "glide": 0.0, "dihedral": 0.0, "speed": 17.0, "altitude": [8.0, 30.0],
		"flock": [2, 6], "formation": "line", "circle": 0.0, "weight": 2.0, "winter": false, "call": [3.0, 9.0],
	},
	"hanhi": {
		"name": "Hanhi", "span": 1.6, "length": 0.82, "chord": [0.26, 0.12], "sweep": 0.14, "neck": 0.32,
		"colors": [Color(0.52, 0.49, 0.44), Color(0.48, 0.45, 0.4), Color(0.5, 0.49, 0.47), Color(0.25, 0.24, 0.23), Color(0.85, 0.84, 0.8)],
		"flap": [3.4, 0.5], "glide": 0.05, "dihedral": 0.0, "speed": 16.0, "altitude": [40.0, 110.0],
		"flock": [5, 13], "formation": "v", "circle": 0.0, "weight": 1.2, "winter": false, "call": [1.5, 4.0],
	},
	"lokki": {
		"name": "Lokki", "span": 1.15, "length": 0.44, "chord": [0.18, 0.07], "sweep": 0.16, "neck": 0.08,
		"colors": [Color(0.94, 0.94, 0.93), Color(0.95, 0.95, 0.94), Color(0.7, 0.73, 0.77), Color(0.06, 0.06, 0.06), Color(0.95, 0.95, 0.94)],
		"flap": [2.8, 0.5], "glide": 0.5, "dihedral": 0.1, "speed": 10.0, "altitude": [10.0, 35.0],
		"flock": [1, 4], "formation": "loose", "circle": 0.6, "weight": 3.0, "winter": false, "call": [3.0, 10.0],
	},
	"kotka": {
		"name": "Merikotka", "span": 2.2, "length": 0.85, "chord": [0.42, 0.3], "sweep": 0.04, "neck": 0.2,
		"colors": [Color(0.3, 0.22, 0.14), Color(0.62, 0.55, 0.42), Color(0.24, 0.17, 0.11), Color(0.08, 0.06, 0.05), Color(0.95, 0.94, 0.9)],
		"flap": [1.8, 0.45], "glide": 0.85, "dihedral": 0.07, "speed": 11.0, "altitude": [45.0, 120.0],
		"flock": [1, 1], "formation": "loose", "circle": 0.8, "weight": 0.35, "winter": true, "call": [8.0, 20.0],
	},
}
const MAX_FLOCKS := 4
const SPAWN_DISTANCE := 420.0 # m veneestä, läpilennon alku
const DESPAWN_DISTANCE := 560.0
const CALL_DISTANCE := 320.0 # m: kauempaa ääntelyä ei kuulu
const EAGLE_SEEN_DISTANCE := 260.0

var boat: Boat
var camera: Camera3D
var sky: SkyTime
var weather: Weather
var lake: LakeData
var winter := false
var day := 180
## Testit: ei satunnaisia uusia parvia
var auto_spawn := true
var flocks: Array = [] # {species, birds: [{node, offset, phase, glide_timer, gliding}], pos, dir, ...}

static var _meshes := {}
static var _material: ShaderMaterial
var _spawn_timer := 6.0
var _rng := RandomNumberGenerator.new()


func setup(boat_node: Boat, camera_node: Camera3D, sky_time: SkyTime, weather_node: Weather, lake_data: LakeData, is_winter: bool) -> void:
	boat = boat_node
	camera = camera_node
	sky = sky_time
	weather = weather_node
	lake = lake_data
	winter = is_winter
	day = sky.day_of_year
	_rng.randomize()


## Lajin yleisyys nyt: muuttolinnut talvella poissa, hanhia eniten muuttoaikaan
func species_weight(sp: String) -> float:
	var d: Dictionary = SPECIES[sp]
	if winter and not d["winter"]:
		return 0.0
	var w: float = d["weight"]
	if sp == "hanhi" and ((day >= 100 and day < 140) or (day >= 250 and day < 290)):
		w *= 3.0
	return w


func _pick_species() -> String:
	var total := 0.0
	for sp in SPECIES:
		total += species_weight(sp)
	var r := _rng.randf() * total
	for sp in SPECIES:
		r -= species_weight(sp)
		if r <= 0.0 and species_weight(sp) > 0.0:
			return sp
	return "varis"


## Uusi parvi. circle = kaartelee veneen lähistöllä, muuten lentää järven yli.
## at/heading voi antaa (testit), muuten valitaan satunnaisesti.
func spawn(sp: String, circle := false, at := Vector3.INF, heading := Vector2.ZERO) -> Dictionary:
	var d: Dictionary = SPECIES[sp]
	var alt := _rng.randf_range(d["altitude"][0], d["altitude"][1])
	var f := {"species": sp, "circle": circle, "birds": [], "age": 0.0, "call_timer": _rng.randf_range(1.0, d["call"][1]), "seen": false}
	if circle:
		var c := boat.pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60.0, 220.0) if at == Vector3.INF else Vector2(at.x, at.z)
		f["center"] = c
		f["radius"] = _rng.randf_range(40.0, 90.0) * (1.4 if sp == "kotka" else 1.0)
		f["angle"] = _rng.randf() * TAU
		f["turn"] = 1.0 if _rng.randf() < 0.5 else -1.0
		f["duration"] = _rng.randf_range(50.0, 110.0)
		f["alt"] = alt if at == Vector3.INF else at.y
		f["pos"] = Vector3(c.x + cos(f["angle"]) * f["radius"], f["alt"], c.y + sin(f["angle"]) * f["radius"])
		f["dir"] = Vector2(-sin(f["angle"]), cos(f["angle"])) * f["turn"]
	else:
		var dir := heading if heading != Vector2.ZERO else Vector2.from_angle(_rng.randf() * TAU)
		var start := Vector3.ZERO
		if at == Vector3.INF:
			var side := Vector2(-dir.y, dir.x) * _rng.randf_range(-160.0, 160.0)
			var p := boat.pos - dir * SPAWN_DISTANCE + side
			start = Vector3(p.x, alt, p.y)
		else:
			start = at
		f["pos"] = start
		f["dir"] = dir.normalized()
		f["alt"] = start.y
	var n := _rng.randi_range(d["flock"][0], d["flock"][1])
	for i in n:
		var node := MeshInstance3D.new()
		node.mesh = mesh(sp)
		node.material_override = material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.scale = Vector3.ONE * _rng.randf_range(0.92, 1.08)
		add_child(node)
		f["birds"].append({"node": node, "offset": _formation_offset(d["formation"], i, d["span"]), "phase": _rng.randf() * TAU,
			"glide": 0.0, "gliding": false, "bob": _rng.randf() * TAU})
	flocks.append(f)
	_update_flock(f, 0.0)
	return f


## Paikka parvessa (x sivulle, z taakse) johtajaan nähden
func _formation_offset(formation: String, i: int, span: float) -> Vector3:
	if i == 0:
		return Vector3.ZERO
	match formation:
		"v":
			var k := (i + 1) / 2
			var side := 1.0 if i % 2 == 1 else -1.0
			return Vector3(side * k * span * 0.9, _rng.randf_range(-0.3, 0.3), k * span * 0.75)
		"line":
			return Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.4, 0.4), i * span * 1.3)
		_:
			return Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(2.0, 10.0) * i)


func _process(delta: float) -> void:
	if boat == null:
		return
	if auto_spawn:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _rng.randf_range(12.0, 40.0)
			# Yöllä ei lennetä, sateella ja kovassa tuulessa vähemmän
			var odds := smoothstep(0.15, 0.5, sky.daylight()) * (1.0 - 0.6 * weather.rain) * (1.0 - smoothstep(8.0, 14.0, weather.speed()))
			if flocks.size() < MAX_FLOCKS and _rng.randf() < odds:
				var sp := _pick_species()
				spawn(sp, _rng.randf() < SPECIES[sp]["circle"])
	for f in flocks.duplicate():
		_update_flock(f, delta)


func _update_flock(f: Dictionary, delta: float) -> void:
	var d: Dictionary = SPECIES[f["species"]]
	f["age"] += delta
	var speed: float = d["speed"]
	if f["circle"] and f["age"] < f["duration"]:
		# Kaartelu: kulmanopeus lentonopeudesta ja säteestä, korkeus aaltoilee hitaasti
		f["angle"] += f["turn"] * speed / f["radius"] * delta
		var c: Vector2 = f["center"]
		var p := Vector3(c.x + cos(f["angle"]) * f["radius"], f["alt"] + sin(f["age"] * 0.2) * 4.0, c.y + sin(f["angle"]) * f["radius"])
		f["dir"] = Vector2(-sin(f["angle"]), cos(f["angle"])) * f["turn"]
		f["bank"] = -f["turn"] * 0.35
		f["pos"] = p
	else:
		var dir: Vector2 = f["dir"]
		f["pos"] += Vector3(dir.x, 0.0, dir.y) * speed * delta
		f["bank"] = 0.0
		var away := Vector2(f["pos"].x - boat.pos.x, f["pos"].z - boat.pos.y)
		if f["age"] > 5.0 and away.length() > DESPAWN_DISTANCE and away.dot(dir) > 0.0:
			_remove(f)
			return
	var heading: Vector2 = f["dir"]
	var basis := Basis.looking_at(Vector3(heading.x, 0.0, heading.y), Vector3.UP)
	for b in f["birds"]:
		var node: MeshInstance3D = b["node"]
		b["bob"] += delta
		var off: Vector3 = b["offset"]
		node.position = f["pos"] + basis * off + Vector3(0, sin(b["bob"] * 0.7) * 0.4, 0)
		node.basis = basis * Basis(Vector3.BACK, f["bank"]) * Basis.from_scale(node.scale)
		node.set_instance_shader_parameter("flap", _wing(b, d, delta))
	_calls(f, d, delta)
	_check_eagle(f)


## Siiven asento: räpyttely tai liito (liidossa siivet hieman yläviistoon)
func _wing(b: Dictionary, d: Dictionary, delta: float) -> float:
	b["glide"] -= delta
	if b["glide"] <= 0.0:
		var gliding: bool = _rng.randf() < d["glide"]
		b["gliding"] = gliding
		b["glide"] = _rng.randf_range(2.0, 6.0) if gliding else _rng.randf_range(1.0, 3.0)
	var target := 0.0
	if b["gliding"]:
		target = d["dihedral"]
		b["phase"] = lerpf(b["phase"], ceilf(b["phase"] / TAU) * TAU, minf(1.0, delta * 3.0))
		# liidossa siivet joustavat hieman ilmavirrassa
		return target + sin(b["phase"]) * d["flap"][1] * 0.2 + sin(b["bob"] * 1.7) * 0.05
	b["phase"] += TAU * d["flap"][0] * delta
	return 0.1 + sin(b["phase"]) * d["flap"][1]


func _calls(f: Dictionary, d: Dictionary, delta: float) -> void:
	f["call_timer"] -= delta
	if f["call_timer"] > 0.0:
		return
	f["call_timer"] = _rng.randf_range(d["call"][0], d["call"][1])
	var p: Vector3 = f["pos"]
	if Vector2(p.x - boat.pos.x, p.z - boat.pos.y).length() < CALL_DISTANCE:
		sound_event.emit("bird_" + f["species"], p)


## Kotka näkyvissä: kameran kuvassa ja tarpeeksi lähellä, päivällä
func _check_eagle(f: Dictionary) -> void:
	if f["species"] != "kotka" or f["seen"] or camera == null:
		return
	var p: Vector3 = f["pos"]
	if camera.global_position.distance_to(p) < EAGLE_SEEN_DISTANCE and camera.is_position_in_frustum(p) and sky.daylight() > 0.3:
		f["seen"] = true
		eagle_seen.emit()


func _remove(f: Dictionary) -> void:
	for b in f["birds"]:
		b["node"].queue_free()
	flocks.erase(f)


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/bird.gdshader")
	return _material


static func mesh(sp: String) -> Mesh:
	if not _meshes.has(sp):
		_meshes[sp] = _build(SPECIES[sp])
	return _meshes[sp]


## Ruumiin poikkileikkauksen puolikorkeus pituuden kohdassa t (0 nokka .. 1 pyrstön tyvi)
static func _body_radius(t: float, length: float) -> float:
	return length * 0.13 * pow(sin(clampf(t, 0.0, 1.0) * PI * 0.92 + 0.12), 0.7)


## Pään ja kaulan säde kohdassa k (0 nokan tyvi .. 1 rinta): pyöreä pää, kaula
## kapenee pitkäkaulaisilla (sorsa, hanhi), ja rinta levenee ruumiiksi
static func _neck_radius(k: float, length: float, neck: float) -> float:
	var head := length * 0.075
	var thin := length * (0.045 if neck > length * 0.25 else 0.065)
	var body := _body_radius(0.0, length)
	var pts := [[0.0, head * 0.5], [0.12, head], [0.35, head * 0.9], [0.6, thin], [1.0, body]]
	for i in pts.size() - 1:
		if k <= pts[i + 1][0]:
			return lerpf(pts[i][1], pts[i + 1][1], smoothstep(pts[i][0], pts[i + 1][0], k))
	return body


## Malli osoittaa -Z:aan (nokka edessä), siivet X-akselilla
static func _build(d: Dictionary) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: Array = d["colors"]
	var length: float = d["length"]
	var neck: float = d["neck"]
	# Ruumis ja kaula: putki nokasta pyrstön tyveen
	const RINGS := 16
	const SEG := 8
	var z0 := -length * 0.5 - neck
	var z1 := length * 0.5
	var rings: Array = []
	for i in RINGS + 1:
		var u := float(i) / RINGS
		var z := lerpf(z0, z1, u)
		var r := 0.0
		var color: Color = cols[0]
		if z < -length * 0.5:
			var k := (z - z0) / maxf(neck, 0.01)
			r = _neck_radius(k, length, neck)
			color = cols[1] if k < 0.55 else cols[0]
		else:
			r = _body_radius((z + length * 0.5) / length, length)
			r = maxf(r, length * 0.02)
		var ring: Array = []
		for s in SEG:
			var a := TAU * s / SEG
			ring.append([Vector3(cos(a) * r, sin(a) * r * 0.85, z), color.darkened(0.25) if sin(a) > 0.3 else color])
		rings.append(ring)
	for i in RINGS:
		for s in SEG:
			var a: Array = rings[i][s]
			var b: Array = rings[i][(s + 1) % SEG]
			var c: Array = rings[i + 1][(s + 1) % SEG]
			var e: Array = rings[i + 1][s]
			for v in [a, b, c, a, c, e]:
				_vert(st, v[0], v[1], 0.0)
	# Nokka
	var beak_color := Color(0.85, 0.65, 0.15) if d["name"] in ["Lokki", "Merikotka"] else Color(0.1, 0.1, 0.1)
	if d["name"] in ["Sorsa", "Hanhi"]:
		beak_color = Color(0.85, 0.55, 0.2)
	var tip := Vector3(0, -length * 0.01, z0 - length * 0.12)
	var br := length * 0.03
	for s in 4:
		var a1 := TAU * s / 4.0
		var a2 := TAU * (s + 1) / 4.0
		_vert(st, Vector3(cos(a1) * br, sin(a1) * br, z0 + 0.01), beak_color, 0.0)
		_vert(st, Vector3(cos(a2) * br, sin(a2) * br, z0 + 0.01), beak_color, 0.0)
		_vert(st, tip, beak_color, 0.0)
	# Pyrstö: viuhka ruumiin perässä
	var tw := length * (0.16 if d["name"] in ["Merikotka", "Korppi"] else 0.11)
	var tl := length * 0.3
	var tz := z1 - length * 0.06
	for tri in [[Vector3(-tw * 0.4, 0, tz), Vector3(tw * 0.4, 0, tz), Vector3(tw, 0, tz + tl)],
			[Vector3(-tw * 0.4, 0, tz), Vector3(tw, 0, tz + tl), Vector3(-tw, 0, tz + tl)]]:
		for v in tri:
			_vert(st, v, cols[4], 0.0)
	# Siivet: tyvi ruumiin kyljessä, kyynärtaive ja kärki; jaettu osiin taipumista varten
	var half: float = d["span"] * 0.5
	var root := length * 0.08
	var elbow := (half - root) * 0.45
	var c_root: float = d["chord"][0]
	var c_tip: float = d["chord"][1]
	var sweep: float = d["sweep"]
	var wz := -length * 0.12 # siiven etureunan paikka ruumiissa
	const PARTS := 6
	for side in [-1.0, 1.0]:
		for i in PARTS:
			var u0 := float(i) / PARTS
			var u1 := float(i + 1) / PARTS
			var quad: Array = []
			for u in [u0, u1]:
				var x: float = root + (half - root) * u
				# siiven etureuna kaartuu taakse kärkeä kohti, kärki pyöristyy
				var lead: float = wz + sweep * u * u
				var chord: float = lerpf(c_root, c_tip, u) * (1.0 - 0.6 * pow(u, 6.0))
				quad.append([Vector3(side * x, length * 0.04, lead), Vector3(side * x, length * 0.04, lead + chord), u])
			var col0: Color = cols[3] if u0 >= 0.66 else cols[2]
			var v00: Array = quad[0]
			var v11: Array = quad[1]
			for v in [[v00[0], v00[2]], [v11[0], v11[2]], [v11[1], v11[2]], [v00[0], v00[2]], [v11[1], v11[2]], [v00[1], v00[2]]]:
				st.set_color(col0)
				st.set_uv(Vector2(maxf(v[1], 0.001), 0.0))
				st.set_uv2(Vector2(root, elbow))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()


static func _vert(st: SurfaceTool, v: Vector3, c: Color, wing: float) -> void:
	st.set_color(c)
	st.set_uv(Vector2(wing, 0.0))
	st.set_uv2(Vector2.ZERO)
	st.set_normal(Vector3(v.x, v.y, 0.0).normalized() if Vector2(v.x, v.y).length() > 0.0001 else Vector3.UP)
	st.add_vertex(v)
